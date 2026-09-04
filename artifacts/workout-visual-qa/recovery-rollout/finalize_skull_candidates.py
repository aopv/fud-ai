#!/usr/bin/env python3
"""Build non-generative, noncanonical final Skull Crusher QA candidates.

Register the already-reviewed existing-pixel toe extension to the cleaned
female3 frame, preserve all existing visible artwork/alpha, apply only tiny
whole-frame bench-center translations, then ONE shared scale per gender.
"""
from __future__ import annotations

import json
import statistics
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat

ROOT = Path(__file__).resolve().parent
QA = ROOT.parent
INPUTS = QA / 'background-pilot' / 'images'
OUTPUTS = QA / 'skull-final-candidates'
EXERCISE = 'Band_Skull_Crusher'
TARGET_SIZE = (1024, 768)


def register_original_to_cleaned(raw: Image.Image, cleaned: Image.Image) -> dict:
    # Compare only the surviving shoe colors at fully visible cleaned pixels.
    box = (850, 620, 1011, 738)
    target = cleaned.convert('RGB').crop(box)
    alpha = cleaned.getchannel('A').crop(box)
    mask = alpha.point(lambda value: 255 if value > 250 else 0)
    source = raw.convert('RGB')
    best = (float('inf'), 0.71, -16, 76)
    for ss in range(21):
        scale = 0.700 + ss * 0.001
        for tx in range(-22, -9):
            for ty in range(68, 87):
                sample = source.transform(target.size, Image.Transform.AFFINE,
                    (1 / scale, 0, (box[0] - tx) / scale,
                     0, 1 / scale, (box[1] - ty) / scale),
                    Image.Resampling.BICUBIC, fillcolor='white')
                score = sum(v*v for v in ImageStat.Stat(ImageChops.difference(sample, target), mask).rms) / 3
                if score < best[0]:
                    best = (score, scale, tx, ty)
    score, scale, tx, ty = best
    for ss in range(-4, 5):
        refined_scale = scale + ss * 0.00025
        for xx in range(-4, 5):
            refined_tx = tx + xx * 0.25
            for yy in range(-4, 5):
                refined_ty = ty + yy * 0.25
                sample = source.transform(target.size, Image.Transform.AFFINE,
                    (1 / refined_scale, 0, (box[0] - refined_tx) / refined_scale,
                     0, 1 / refined_scale, (box[1] - refined_ty) / refined_scale),
                    Image.Resampling.BICUBIC, fillcolor='white')
                refined_score = sum(v*v for v in ImageStat.Stat(ImageChops.difference(sample, target), mask).rms) / 3
                if refined_score < best[0]:
                    best = (refined_score, refined_scale, refined_tx, refined_ty)
    score, scale, tx, ty = best
    return {'scale': scale, 'translation': [tx, ty], 'rgb_rmse': score ** 0.5,
            'comparison_box': box, 'method': 'uniform scale and translation only'}


def toe_only_layer(raw_candidate: Image.Image) -> Image.Image:
    # Isolate the entire outlined shoe pair first so enclosed white soles remain.
    # Only its newly recovered x>=1448 pixels are actually copied to the layer.
    box = (1210, 740, 1472, 940)
    region = raw_candidate.crop(box).convert('RGBA')
    width, height = region.size
    pixels = list(region.getdata())
    ink = bytearray(255 if rgba[3] > 0 and min(rgba[:3]) < 210 else 0 for rgba in pixels)
    outside = bytearray(width * height)
    queue = deque()
    for y in range(height):
        for x in (0, width - 1):
            p = y * width + x
            if not ink[p] and not outside[p]: outside[p] = 1; queue.append(p)
    for x in range(width):
        for y in (0, height - 1):
            p = y * width + x
            if not ink[p] and not outside[p]: outside[p] = 1; queue.append(p)
    while queue:
        p = queue.popleft()
        for neighbor in (p-1, p+1, p-width, p+width):
            if (0 <= neighbor < width*height and not ink[neighbor] and not outside[neighbor]
                    and abs(neighbor % width - p % width) <= 1):
                outside[neighbor] = 1; queue.append(neighbor)
    alpha = Image.new('L', region.size)
    alpha.putdata([255 if not outside[p] and (p % width + box[0]) >= 1448 else 0
                   for p in range(width * height)])
    region.putalpha(alpha)
    layer = Image.new('RGBA', raw_candidate.size)
    layer.paste(region, box[:2])
    return layer


def bench_foot(image: Image.Image, xmin: int, xmax: int) -> tuple[float, float]:
    rgba = image.load()
    pixels = [(x, y) for y in range(720, 768) for x in range(xmin, xmax)
              if rgba[x, y][3] > 160 and max(rgba[x, y][:3]) < 160]
    bottom = max(y for x, y in pixels)
    points = [x for x, y in pixels if y >= bottom - 5]
    return sum(points) / len(points), float(bottom)


def main() -> None:
    OUTPUTS.mkdir(parents=True, exist_ok=True)
    inputs = {f'{gender}_{frame}': Image.open(INPUTS / f'{EXERCISE}_{gender}_v2_{frame}.png').convert('RGBA')
              for gender in ('male', 'female') for frame in range(4)}
    raw = Image.open(ROOT / f'{EXERCISE}_female_v2_3-toe-extension-candidate.png').convert('RGBA')
    registration = register_original_to_cleaned(raw, inputs['female_3'])
    scale, (tx, ty) = registration['scale'], registration['translation']
    layer = toe_only_layer(raw).transform((1072, 768), Image.Transform.AFFINE,
        (1/scale, 0, -tx/scale, 0, 1/scale, -ty/scale), Image.Resampling.BICUBIC)
    extended = Image.new('RGBA', (1072, 768))
    original = inputs['female_3']
    extended.paste(original, (0, 0))
    existing_alpha = extended.getchannel('A')
    permission = existing_alpha.point(lambda value: 255 if value == 0 else 0)
    layer.putalpha(ImageChops.multiply(layer.getchannel('A'), permission))
    extended = Image.alpha_composite(extended, layer)
    before, after = list(original.getdata()), list(extended.crop((0, 0, 1024, 768)).getdata())
    assert all(a == b for a, b in zip(before, after) if a[3] > 0)
    changed = [i for i, (a, b) in enumerate(zip(before, after)) if a != b]
    assert all(i % 1024 >= 1010 and 620 <= i // 1024 < 740 for i in changed)
    extended.save(OUTPUTS / 'female3-pre-fit-extended.png')
    layer.save(OUTPUTS / 'female3-added-toe-layer.png')
    inputs['female_3'] = extended

    report = {'toe_registration': registration, 'toe_added_bbox': layer.getchannel('A').getbbox(),
              'visible_input_pixels_preserved_before_fit': True, 'frames': [], 'groups': []}
    outputs = {}
    for gender in ('male', 'female'):
        group = [inputs[f'{gender}_{frame}'] for frame in range(4)]
        feet = [(bench_foot(im, 80, 400), bench_foot(im, 600, 840)) for im in group]
        centers = [((left[0]+right[0])/2, (left[1]+right[1])/2) for left, right in feet]
        anchor = (statistics.median(p[0] for p in centers), statistics.median(p[1] for p in centers))
        shifts = [(anchor[0]-p[0], anchor[1]-p[1]) for p in centers]
        assert max(abs(v) for shift in shifts for v in shift) <= 7
        shifted_bounds = []
        for im, (dx, dy) in zip(group, shifts):
            x0, y0, x1, y1 = im.getchannel('A').getbbox()
            shifted_bounds.append((x0+dx, y0+dy, x1+dx, y1+dy))
        union = (min(b[0] for b in shifted_bounds), min(b[1] for b in shifted_bounds),
                 max(b[2] for b in shifted_bounds), max(b[3] for b in shifted_bounds))
        shared_scale = min(944/(union[2]-union[0]), 704/(union[3]-union[1]), 1)
        origin_x = (1024-(union[2]-union[0])*shared_scale)/2-union[0]*shared_scale
        origin_y = 736-union[3]*shared_scale
        report['groups'].append({'gender': gender, 'shared_scale': shared_scale,
            'union_before_fit': union, 'common_translation': [origin_x, origin_y],
            'bench_anchor': anchor, 'max_manual_or_measured_shift_px': max(abs(v) for shift in shifts for v in shift)})
        for frame, (im, shift, foot) in enumerate(zip(group, shifts, feet)):
            dx, dy = shift
            offset_x, offset_y = origin_x+shared_scale*dx, origin_y+shared_scale*dy
            result = im.transform(TARGET_SIZE, Image.Transform.AFFINE,
                (1/shared_scale, 0, -offset_x/shared_scale, 0, 1/shared_scale, -offset_y/shared_scale),
                Image.Resampling.BICUBIC)
            path = OUTPUTS / f'{EXERCISE}_{gender}_v2_{frame}.png'
            result.save(path)
            bbox = result.getchannel('A').getbbox()
            assert bbox[0] >= 38 and bbox[2] <= 986 and bbox[1] >= 30 and bbox[3] <= 738
            report['frames'].append({'gender': gender, 'frame': frame, 'input': str(INPUTS / path.name),
                'output': str(path), 'input_alpha_bbox': im.getchannel('A').getbbox(), 'output_alpha_bbox': bbox,
                'bench_feet_before': foot, 'bench_translation_only': shift, 'scale': shared_scale,
                'canvas': TARGET_SIZE, 'alpha_extrema': result.getchannel('A').getextrema()})
            outputs[f'{gender}_{frame}'] = result

    for bg_name, color in [('dark', '#141414'), ('light', '#f7f7f5')]:
        contact = Image.new('RGB', (2048, 828), color)
        draw = ImageDraw.Draw(contact)
        for row, gender in enumerate(('male', 'female')):
            frames = []
            for frame in range(4):
                result = outputs[f'{gender}_{frame}']
                small = result.resize((512, 384), Image.Resampling.LANCZOS)
                contact.paste(small, (frame*512, row*414+30), small)
                draw.text((frame*512+12, row*414+10), f'{gender} {frame}', fill='white' if bg_name=='dark' else 'black')
                rendered = Image.new('RGB', result.size, color)
                rendered.paste(result, (0,0), result)
                frames.append(rendered)
            frames[0].save(OUTPUTS / f'{gender}-{bg_name}-loop.gif', save_all=True,
                          append_images=frames[1:], duration=850, loop=0)
        contact.save(OUTPUTS / f'contact-{bg_name}.png')
    (OUTPUTS / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
