#!/usr/bin/env python3
"""Append a compatible existing shoe-tip fragment outside the original canvas.

Every original female3 pixel remains unchanged. No painting, synthesis,
inpainting, warping, cleanup, or canonical replacement is performed.
"""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent
original_path = Path('/Users/apoorvdarshan/.codex/generated_images/01a05d35-f69e-7912-bd85-0163e1e7586d/exec-598b751f-09a3-46f7-b58f-fabaf978a83b.png')
original = Image.open(original_path).convert('RGBA')
registered = Image.open(root / 'skull-crusher-shoe-donor-2-registered.png').convert('RGBA')
result = Image.new('RGBA', (1472, 1086))
result.paste(original, (0, 0))
# Registered donor is in target-local coordinates with origin (1100,680).
# Copy only x1448..1471 and y760..939, outside the entire original canvas.
extension = registered.crop((348, 80, 372, 260))
result.paste(extension, (1448, 760))
assert result.crop((0, 0, 1448, 1086)).tobytes() == original.tobytes()
path = root / 'Band_Skull_Crusher_female_v2_3-toe-extension-candidate.png'
result.save(path)
# Inspection view only: show the join at 4x with the boundary marked above/below.
review = result.crop((1370, 795, 1472, 940)).resize((408, 580), Image.Resampling.NEAREST)
canvas = Image.new('RGBA', (408, 620), '#cccccc')
canvas.alpha_composite(review, (0, 20))
draw = ImageDraw.Draw(canvas)
boundary = (1448 - 1370) * 4
draw.line((boundary, 0, boundary, 19), fill='red', width=2)
draw.line((boundary, 600, boundary, 619), fill='red', width=2)
canvas.convert('RGB').save(root / 'skull-crusher-toe-extension-seam-review.png')
print(path)
print('PASS: all original 1448x1086 RGBA pixels preserved exactly; only added 24px canvas strip.')
