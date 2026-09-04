#!/usr/bin/env python3
"""Conservative Squat-only staged edge cleanup; no geometric transformation."""
from pathlib import Path
import hashlib
import json
import sys
import cv2
import numpy as np
from scipy.ndimage import distance_transform_edt
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
QA = OUT.parent
sys.path.insert(0, str(REPO / 'scripts'))
from refine_workout_matte_edges import refine

EXERCISE = 'Barbell_Full_Squat'
SHOES = (350, 665, 695, 768)
SHAFTS = {'male': [(148,150,880,193), (145,248,880,296), (148,348,880,387), (145,190,880,231)],
          'female': [(148,150,880,193), (145,246,880,295), (148,342,880,386), (145,186,880,230)]}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clear_remaining_neutral_rim(rgba, protections):
    # Narrow pale remnants can themselves become the helper's nearest interior.
    # Instead use a nearby dark outline only within 3.5px, and only within 2.25px
    # of known transparency. This never reaches the broad body/plate interior.
    rgb = rgba[..., :3].astype(np.float32)
    alpha = rgba[..., 3].astype(np.float32) / 255
    seed = (alpha > .78) & (rgb.max(axis=2) < 180)
    distance, indices = distance_transform_edt(~seed, return_indices=True)
    edge_distance = distance_transform_edt(alpha > .03)
    foreground = rgb[indices[0], indices[1]]
    pale = (rgb.min(axis=2) >= 185) & (np.ptp(rgb, axis=2) <= 25)
    mask = (alpha > 0) & pale & (distance <= 3.5) & (edge_distance <= 2.25)
    for left, top, right, bottom in protections:
        mask[top:bottom, left:right] = False
    difference = 255 - foreground
    weights = np.maximum(difference - 25, 0)
    estimate = np.clip(np.sum((255-rgb)*weights, axis=2) / np.maximum(np.sum(difference*weights, axis=2), 1), 0, 1)
    mask &= estimate < .75
    out = rgba.copy()
    out[mask, :3] = np.round(foreground[mask]).astype(np.uint8)
    out[mask, 3] = np.round(alpha[mask]*estimate[mask]*255).astype(np.uint8)
    return out, int(mask.sum())


def main():
    rows, outputs = [], {}
    for gender in ('male', 'female'):
        for frame in range(4):
            stem = f'{EXERCISE}_{gender}_v2_{frame}'
            original = REPO / 'shared/workout-vectors' / (stem + '.png')
            source = QA / 'background-pilot/images' / (stem + '.png')
            image = Image.open(source).convert('RGBA')
            rgba = np.array(image)
            protections = [SHOES, SHAFTS[gender][frame]]
            result, edge_report = refine(rgba, protections)
            result, extra = clear_remaining_neutral_rim(result, protections)
            _, components, component_stats, _ = cv2.connectedComponentsWithStats((rgba[...,3]>7).astype(np.uint8),connectivity=8)
            main = components == (1 + np.argmax(component_stats[1:,cv2.CC_STAT_AREA]))
            protected_main = np.zeros(main.shape,dtype=bool)
            for left,top,right,bottom in protections:
                protected_main[top:bottom,left:right] = main[top:bottom,left:right]
            assert np.array_equal(rgba[protected_main],result[protected_main])
            interior = cv2.erode((rgba[...,3] > 7).astype(np.uint8), np.ones((9,9), np.uint8)) > 0
            assert np.array_equal(rgba[interior], result[interior])
            assert np.all(result[...,3] <= rgba[...,3])
            candidate = Image.fromarray(result)
            destination = OUT / (stem + '.png')
            candidate.save(destination)
            bounds = candidate.getchannel('A').getbbox()
            assert bounds[0] > 0 and bounds[1] > 0 and bounds[2] < 1024 and bounds[3] < 768
            assert candidate.size == (1024,768) and candidate.getchannel('A').getextrema() == (0,255)
            row = {'asset_name':stem, 'candidate_path':str(destination.relative_to(REPO)),
                   'candidate_sha256':sha(destination), 'original_shared_sha256':sha(original),
                   'background_source_sha256':sha(source), 'alpha_bbox':bounds,
                   'shared_transform':{'scale':1,'translation':[0,0]},
                   'protected_rectangles':protections, 'protected_main_foreground_rgba_identical':True,
                   'interior_rgba_identical':True, 'extra_thin_rim_pixels_unmatted':extra,
                   'edge_refinement':edge_report}
            rows.append(row)
            outputs[(gender,frame)] = candidate
            full_review = Image.new('RGB',(2048,768))
            for bg,color in [('dark','#101010'),('light','#f7f7f5')]:
                composite = Image.new('RGB', candidate.size, color)
                composite.paste(candidate,(0,0),candidate)
                composite.save(OUT / f'{stem}-{bg}.png')
                full_review.paste(composite,(0 if bg=='dark' else 1024,0))
            full_review.save(OUT / f'{stem}-full-review.png')
    for bg,color in [('dark','#101010'),('light','#f7f7f5')]:
        contact = Image.new('RGB',(2048,828),color)
        draw = ImageDraw.Draw(contact)
        for row,gender in enumerate(('male','female')):
            for frame in range(4):
                small = outputs[(gender,frame)].resize((512,384),Image.Resampling.LANCZOS)
                contact.paste(small,(frame*512,row*414+30),small)
                draw.text((frame*512+12,row*414+10),f'{gender} {frame}',fill='white' if bg=='dark' else 'black')
        contact.save(OUT / f'contact-{bg}.png')
    original_contact = Image.new('RGB',(2048,828),'#101010')
    original_draw = ImageDraw.Draw(original_contact)
    for row,gender in enumerate(('male','female')):
        for frame in range(4):
            path = REPO / 'shared/workout-vectors' / f'{EXERCISE}_{gender}_v2_{frame}.png'
            original_image = Image.open(path).convert('RGBA').resize((512,384),Image.Resampling.LANCZOS)
            original_contact.paste(original_image,(frame*512,row*414+30),original_image)
            original_draw.text((frame*512+12,row*414+10),f'original {gender} {frame}',fill='white')
    original_contact.save(OUT / 'original-contact-dark.png')
    shoe_compare = Image.new('RGB',(1050,704),'#101010')
    for row,gender in enumerate(('male','female')):
        for frame in range(4):
            for col,folder in enumerate((REPO/'shared/workout-vectors', QA/'background-pilot/images', OUT)):
                source_image = Image.open(folder/f'{EXERCISE}_{gender}_v2_{frame}.png').convert('RGBA')
                crop = source_image.crop((350,670,700,758))
                shoe_compare.paste(crop,(col*350,(row*4+frame)*88),crop)
    shoe_compare.save(OUT/'shoe-original-pilot-final-comparison.png')
    (OUT / 'verification.json').write_text(json.dumps({'frames':rows},indent=2)+'\n')
    print(json.dumps(rows,indent=2))


if __name__ == '__main__':
    main()
