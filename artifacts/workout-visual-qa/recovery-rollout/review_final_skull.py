#!/usr/bin/env python3
"""Generate read-only comparison metrics and contact sheets for staged Skull PNGs."""
from pathlib import Path
import hashlib
import json

import cv2
import numpy as np
from PIL import Image, ImageDraw

QA = Path(__file__).resolve().parent.parent
REPO = QA.parents[1]
SOURCE = QA / 'skull-final-candidates'
FINAL = QA / 'skull-final-refined'
EXERCISE = 'Band_Skull_Crusher'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    rows = []
    images = {}
    for gender in ('male', 'female'):
        for frame in range(4):
            stem = f'{EXERCISE}_{gender}_v2_{frame}'
            source = Image.open(SOURCE / (stem + '.png'))
            candidate = Image.open(FINAL / (stem + '.png'))
            old, new = np.array(source), np.array(candidate)
            assert candidate.mode == 'RGBA' and candidate.size == (1024, 768)
            assert candidate.getchannel('A').getextrema() == (0, 255)
            assert np.array_equal(old[605:750, 785:1024], new[605:750, 785:1024])
            interior = cv2.erode((old[..., 3] > 7).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
            assert np.array_equal(old[interior], new[interior])
            changed = np.any(old != new, axis=2)
            report = json.loads((FINAL / (stem + '-report.json')).read_text())
            rows.append({
                'asset_name': stem,
                'candidate_path': str((FINAL / (stem + '.png')).relative_to(REPO)),
                'candidate_sha256': sha(FINAL / (stem + '.png')),
                'original_shared_sha256': sha(REPO / 'shared/workout-vectors' / (stem + '.png')),
                'canvas': list(candidate.size), 'mode': candidate.mode,
                'alpha_extrema': list(candidate.getchannel('A').getextrema()),
                'alpha_bbox': list(candidate.getchannel('A').getbbox()),
                'refinement_changed_pixels': int(changed.sum()),
                'interior_identical_to_unrefined': True,
                'protected_shoe_box_identical_to_unrefined': True,
                'edge_pixels_unmatted': report['edge_pixels_unmatted'],
                'speck_pixels_removed': report['speck_pixels_removed'],
            })
            images[(gender, frame)] = candidate
    for bg_name, color in [('dark', '#141414'), ('light', '#f7f7f5')]:
        contact = Image.new('RGB', (2048, 828), color)
        draw = ImageDraw.Draw(contact)
        for row, gender in enumerate(('male', 'female')):
            for frame in range(4):
                result = images[(gender, frame)]
                small = result.resize((512, 384), Image.Resampling.LANCZOS)
                contact.paste(small, (frame*512, row*414+30), small)
                draw.text((frame*512+12, row*414+10), f'{gender} {frame}', fill='white' if bg_name == 'dark' else 'black')
        contact.save(FINAL / f'contact-{bg_name}.png')
        shoes = Image.new('RGB', (960, 304), color)
        for row, gender in enumerate(('male', 'female')):
            for frame in range(4):
                crop = images[(gender, frame)].crop((784, 600, 1024, 752))
                shoes.paste(crop, (frame*240, row*152), crop)
        shoes.save(FINAL / f'shoes-{bg_name}.png')
    (FINAL / 'verification.json').write_text(json.dumps({'frames': rows}, indent=2) + '\n')
    print(json.dumps(rows, indent=2))


if __name__ == '__main__':
    main()
