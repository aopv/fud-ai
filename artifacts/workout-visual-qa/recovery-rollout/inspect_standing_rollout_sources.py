#!/usr/bin/env python3
"""Make an inspection-only contact sheet of the exact wave task originals."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

root = Path(__file__).resolve().parent
source = Path('/Users/apoorvdarshan/.codex/generated_images/01a05d36-07db-7eb1-90c0-3efcde752796')
paths = sorted(source.glob('*.png'))
sheet = Image.new('RGB', (1500, 1350), '#eeeeee')
draw = ImageDraw.Draw(sheet)
for index, path in enumerate(paths):
    image = Image.open(path).convert('RGBA')
    preview = ImageOps.contain(image, (490, 390))
    x, y = (index % 3) * 500, (index // 3) * 450
    sheet.paste(preview, (x, y + 40), preview)
    draw.text((x + 4, y + 4), f'{index}: {path.name[:18]} {image.size}', fill='black')
sheet.save(root / 'barbell-ab-rollout-originals-contact.png')
print('\n'.join(f'{index}: {path}' for index, path in enumerate(paths)))
current_root = root.parents[2] / 'shared' / 'workout-vectors'
current = Image.new('RGB', (2000, 900), '#eeeeee')
draw = ImageDraw.Draw(current)
for row, gender in enumerate(('male', 'female')):
    for frame in range(4):
        path = current_root / f'Barbell_Ab_Rollout_{gender}_v2_{frame}.png'
        image = Image.open(path).convert('RGBA')
        preview = ImageOps.contain(image, (490, 390))
        current.paste(preview, (frame * 500, row * 450 + 40), preview)
        draw.text((frame * 500 + 4, row * 450 + 4), f'{gender} {frame}', fill='black')
current.save(root / 'barbell-ab-rollout-current-contact.png')
