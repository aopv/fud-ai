"""Read-only source-native component diagrams for manual shadow review."""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
QA = ROOT.parent
INPUT = QA / "recovered-kneeling-cleanup" / "images"
OUTPUT = ROOT / "shadow-diagnostics"
OUTPUT.mkdir(exist_ok=True)

reports = []
for path in sorted(INPUT.glob("*.png")):
    rgba = np.array(Image.open(path).convert("RGBA"))
    rgb = rgba[:, :, :3].astype(np.int16)
    eligible = (rgba[:, :, 3] >= 16) & (rgb.min(axis=2) >= 100) & (np.ptp(rgb, axis=2) <= 20)
    count, labels, stats, centers = cv2.connectedComponentsWithStats(eligible.astype(np.uint8), 8)
    preview = Image.new("RGBA", (rgba.shape[1], rgba.shape[0]), (9, 9, 9, 255))
    preview.alpha_composite(Image.fromarray(rgba))
    preview = preview.convert("RGB").resize((rgba.shape[1]*3, rgba.shape[0]*3))
    draw = ImageDraw.Draw(preview)
    for x in range(0, rgba.shape[1], 20):
        draw.text((x*3, 0), str(x), fill=(0, 255, 255), stroke_width=1, stroke_fill=(0, 0, 0))
    for y in range(20, rgba.shape[0], 20):
        draw.text((0, y*3), str(y), fill=(0, 255, 255), stroke_width=1, stroke_fill=(0, 0, 0))
    records = []
    for label in range(1, count):
        x, y, w, h, area = map(int, stats[label])
        if area < 8:
            continue
        cx, cy = centers[label]
        record = {"label": label, "area": area, "bbox": [x,y,x+w,y+h],
                  "center": [round(cx,1),round(cy,1)]}
        records.append(record)
        draw.text((cx*3, cy*3), str(label), fill=(255,50,120), stroke_width=2, stroke_fill=(0,0,0))
    preview.save(OUTPUT/(path.stem+"-components.png"))
    reports.append({"file": path.name, "regions": records})
(OUTPUT/"components.json").write_text(json.dumps(reports, indent=2)+"\n")
print(json.dumps({"frames": len(reports), "output": str(OUTPUT)}))
