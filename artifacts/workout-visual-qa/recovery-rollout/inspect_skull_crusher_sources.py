#!/usr/bin/env python3
"""Read original task images and write only an inspection contact sheet."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

root = Path(__file__).resolve().parent
source = Path('/Users/apoorvdarshan/.codex/generated_images/01a05d35-f69e-7912-bd85-0163e1e7586d')
paths = sorted(source.glob('*.png'))
sheet = Image.new('RGB', (1500, ((len(paths) + 2) // 3) * 430), '#eeeeee')
draw = ImageDraw.Draw(sheet)
for index, path in enumerate(paths):
    image = Image.open(path).convert('RGBA')
    preview = ImageOps.contain(image, (490, 375))
    x, y = (index % 3) * 500, (index // 3) * 430
    sheet.paste(preview, (x, y + 35), preview)
    draw.text((x + 4, y + 4), f'{index}: {path.name[:18]} {image.size}', fill='black')
sheet.save(root / 'skull-crusher-originals-contact.png')
print('\n'.join(f'{index}: {path}' for index, path in enumerate(paths)))
