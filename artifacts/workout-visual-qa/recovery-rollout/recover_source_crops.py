#!/usr/bin/env python3
"""Recover intact kneeling rollout sprites from the original contact sheets.

Non-generative only: explicit manual sheet-space crop rectangles and polygon
ownership masks. Source RGB is copied unchanged; no painting, inpainting,
background removal, contrast change, or resizing is done to recovered crops.
All output remains inside this recovery directory, never canonical assets.
"""

from __future__ import annotations

import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
SOURCE = Path('/Users/apoorvdarshan/workout-art-batches/batch-004/source-sheets')
EXERCISE = 'Barbell_Ab_Rollout_-_On_Knees'

# Rectangles use Pillow's half-open [left, top, right, bottom] coordinates.
# Polygons are in original 2172x724 sheet coordinates. The irregular boundaries
# separate frames 1 and 2, whose bounding boxes overlap but whose artwork does not.
PLAN = {
    'male': [
        {'box': [16, 160, 493, 535]},
        {'box': [495, 225, 1085, 570],
         'polygon': [[495, 225], [1085, 225], [1085, 400], [1080, 410],
                     [1068, 425], [1028, 444], [1028, 570], [495, 570]]},
        {'box': [1030, 315, 1655, 610],
         'polygon': [[1085, 315], [1655, 315], [1655, 610], [1030, 610],
                     [1030, 444], [1068, 425], [1080, 410], [1085, 400]]},
        {'box': [1660, 180, 2118, 548]},
    ],
    'female': [
        {'box': [22, 120, 513, 545]},
        {'box': [514, 190, 1063, 557],
         'polygon': [[514, 190], [1063, 190], [1063, 425], [1056, 439],
                     [1020, 446], [1020, 557], [514, 557]]},
        {'box': [1030, 303, 1625, 590],
         'polygon': [[1063, 303], [1625, 303], [1625, 590], [1030, 590],
                     [1030, 446], [1056, 439], [1063, 425]]},
        {'box': [1640, 130, 2134, 549]},
    ],
}


def major_ink_components(image: Image.Image) -> list[list[int]]:
    """Read-only verification against each large connected line-art component."""
    gray = image.convert('L')
    width, height = image.size
    raw = gray.tobytes()
    seen = bytearray(width * height)
    groups = []
    for start, value in enumerate(raw):
        if value >= 179 or seen[start]:
            continue
        seen[start] = 1
        queue = deque([start])
        points = []
        while queue:
            point = queue.popleft()
            points.append(point)
            for neighbor in (point - 1, point + 1, point - width, point + width):
                if (0 <= neighbor < width * height and not seen[neighbor]
                        and raw[neighbor] < 179
                        and abs(neighbor % width - point % width) <= 1):
                    seen[neighbor] = 1
                    queue.append(neighbor)
        if len(points) > 15000:
            groups.append(points)
    groups.sort(key=lambda points: min(point % width for point in points))
    assert len(groups) == 4, f'Expected 4 isolated sprites, found {len(groups)}'
    return groups


def main() -> None:
    output = ROOT / 'recovered-raw'
    output.mkdir(parents=True, exist_ok=True)
    report = []
    contact = Image.new('RGB', (2600, 1020), '#cccccc')
    draw = ImageDraw.Draw(contact)
    for row, gender in enumerate(('male', 'female')):
        source_path = SOURCE / f'{EXERCISE}_{gender}.png'
        source = Image.open(source_path).convert('RGBA')
        assert source.size == (2172, 724)
        components = major_ink_components(source)
        for frame, spec in enumerate(PLAN[gender]):
            box = spec['box']
            mask = Image.new('L', source.size, 0)
            painter = ImageDraw.Draw(mask)
            if 'polygon' in spec:
                painter.polygon(spec['polygon'], fill=255)
            else:
                painter.rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=255)
            mask_bytes = mask.tobytes()
            lost = sum(mask_bytes[p] == 0 for p in components[frame])
            foreign = sum(mask_bytes[p] > 0 for other, points in enumerate(components)
                          if other != frame for p in points)
            assert lost == 0, f'{gender} {frame}: {lost} subject ink pixels cut'
            assert foreign == 0, f'{gender} {frame}: {foreign} foreign ink pixels retained'
            recovered = source.copy()
            recovered.putalpha(mask)
            recovered = recovered.crop(box)
            path = output / f'{EXERCISE}_{gender}_v2_{frame}.png'
            recovered.save(path)
            contact.paste(recovered, (frame * 650 + 10, row * 510 + 40), recovered)
            draw.text((frame * 650 + 10, row * 510 + 10), f'{gender} frame {frame}; {recovered.size}', fill='black')
            report.append({'gender': gender, 'frame': frame, 'source': str(source_path),
                           'source_size': source.size, 'crop_box': box,
                           'ownership_polygon': spec.get('polygon'),
                           'output': str(path), 'output_size': recovered.size,
                           'lost_subject_ink_pixels': lost, 'retained_neighbor_ink_pixels': foreign,
                           'background_cleanup_applied': False, 'resized': False})
    contact.save(ROOT / 'recovered-contact.png')
    (ROOT / 'recovery-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
