#!/usr/bin/env python3
"""Inspection-only crop comparison of existing female skull-crusher shoes."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent
source = Path('/Users/apoorvdarshan/.codex/generated_images/01a05d35-f69e-7912-bd85-0163e1e7586d')
frames = {
    0: 'exec-4b61de22-80a0-4f5e-a8c4-579d4167effd.png',
    1: 'exec-7234b0df-0293-42cf-a9bb-a8becd2fd2ab.png',
    2: 'exec-51b585e8-3b8d-4fc9-b90d-31ff7cccbdd4.png',
    3: 'exec-598b751f-09a3-46f7-b58f-fabaf978a83b.png',
}
sheet = Image.new('RGB', (1600, 450), '#dddddd')
draw = ImageDraw.Draw(sheet)
for frame, name in frames.items():
    original = Image.open(source / name).convert('RGB')
    crop = original.crop((1050, 680, 1448, 1060))
    sheet.paste(crop, (frame * 400, 35))
    draw.text((frame * 400 + 4, 8), f'female {frame}: raw crop x1050..1448,y680..1060', fill='black')
sheet.save(root / 'skull-crusher-shoes-native-contact.png')
