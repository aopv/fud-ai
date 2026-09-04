#!/usr/bin/env python3
"""Compare existing shoe artwork using uniform-scale/translation registration.

Writes review candidates only. No generative tools and no canonical writes.
Registration scores are diagnostic, not automatic promotion criteria.
"""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageStat

ROOT = Path(__file__).resolve().parent
SOURCE = Path('/Users/apoorvdarshan/.codex/generated_images/01a05d35-f69e-7912-bd85-0163e1e7586d')
NAMES = {
    0: 'exec-4b61de22-80a0-4f5e-a8c4-579d4167effd.png',
    1: 'exec-7234b0df-0293-42cf-a9bb-a8becd2fd2ab.png',
    2: 'exec-51b585e8-3b8d-4fc9-b90d-31ff7cccbdd4.png',
    3: 'exec-598b751f-09a3-46f7-b58f-fabaf978a83b.png',
}
ROI = (1100, 680, 1448, 1020)
PATCH = (37, 25, 87, 62)  # quarter-resolution surviving toe/lace/side panel area


def main() -> None:
    originals = {i: Image.open(SOURCE / name).convert('RGB') for i, name in NAMES.items()}
    crops = {i: image.crop(ROI) for i, image in originals.items()}
    small = {i: crop.resize((87, 85), Image.Resampling.LANCZOS) for i, crop in crops.items()}
    target = small[3].crop(PATCH)
    mask = Image.new('L', target.size)
    mask.putdata([255 if min(rgb) < 165 and max(rgb) - min(rgb) < 75 else 0 for rgb in target.getdata()])
    results = []
    comparison = Image.new('RGB', (4 * 440, 450), '#dddddd')
    draw = ImageDraw.Draw(comparison)
    comparison.paste(crops[3], (0, 40))
    draw.text((5, 8), 'Original female3 (target, clipped at right)', fill='black')
    for donor in range(3):
        best = (float('inf'), 0.0, 0, 0)
        for step in range(11):
            scale = 0.90 + step * 0.025
            for dx in range(-25, 26, 2):
                for dy in range(-40, 41, 2):
                    sample = small[donor].transform(target.size, Image.Transform.AFFINE,
                        (1 / scale, 0, (PATCH[0] - dx) / scale,
                         0, 1 / scale, (PATCH[1] - dy) / scale),
                        Image.Resampling.BILINEAR, fillcolor='white')
                    rms = ImageStat.Stat(ImageChops.difference(sample, target), mask).rms
                    score = sum(v * v for v in rms) / 3
                    if score < best[0]:
                        best = (score, scale, dx, dy)
        score, scale, coarse_dx, coarse_dy = best
        # Refine translations/scales around the best coarse result.
        refined = best
        for ss in range(-4, 5):
            s = scale + ss * 0.005
            for dx in range(coarse_dx - 2, coarse_dx + 3):
                for dy in range(coarse_dy - 2, coarse_dy + 3):
                    sample = small[donor].transform(target.size, Image.Transform.AFFINE,
                        (1 / s, 0, (PATCH[0] - dx) / s, 0, 1 / s, (PATCH[1] - dy) / s),
                        Image.Resampling.BILINEAR, fillcolor='white')
                    rms = ImageStat.Stat(ImageChops.difference(sample, target), mask).rms
                    score = sum(v * v for v in rms) / 3
                    if score < refined[0]:
                        refined = (score, s, dx, dy)
        score, scale, dx, dy = refined
        aligned = originals[donor].transform((440, 340), Image.Transform.AFFINE,
            (1 / scale, 0, ROI[0] - (dx * 4) / scale,
             0, 1 / scale, ROI[1] - (dy * 4) / scale),
            Image.Resampling.BICUBIC, fillcolor='white')
        path = ROOT / f'skull-crusher-shoe-donor-{donor}-registered.png'
        aligned.save(path)
        comparison.paste(aligned, ((donor + 1) * 440, 40))
        draw.text(((donor + 1) * 440 + 4, 8), f'donor {donor}: scale {scale:.3f}, offset {dx*4},{dy*4}, RMSE {score**0.5:.2f}', fill='black')
        results.append({'donor_frame': donor, 'donor_source': str(SOURCE / NAMES[donor]),
                        'target_source': str(SOURCE / NAMES[3]), 'roi_origin': ROI[:2],
                        'uniform_scale': scale, 'translation_relative_roi_pixels': [dx * 4, dy * 4],
                        'masked_rgb_rmse': score ** 0.5, 'registered_roi_image': str(path),
                        'canonical_modified': False})
    comparison.save(ROOT / 'skull-crusher-shoe-registration-contact.png')
    (ROOT / 'skull-crusher-shoe-registration.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
