"""Exact integer translation of this visually reviewed stationary-body sequence.

The general SIFT scale estimator did not pass distributed-feature support. This
exercise-specific operation estimates NO scale: independent head and planted
shoe template checks support only small translations. It never alters a pixel's
RGBA values, fits individual bounding boxes, or promotes anything.
"""
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "shared/workout-vectors"
OUTPUT = Path(__file__).resolve().parent / "hammer-translated"
EXERCISE = "Alternate_Hammer_Curl"


def main():
    OUTPUT.mkdir(exist_ok=True)
    reports = []
    for gender in ("male", "female"):
        paths = [SOURCE / f"{EXERCISE}_{gender}_v2_{i}.png" for i in range(4)]
        hashes = [hashlib.sha256(path.read_bytes()).hexdigest() for path in paths]
        rgba = [np.asarray(Image.open(path).convert("RGBA")) for path in paths]
        gray = [cv2.cvtColor(image, cv2.COLOR_RGBA2GRAY) for image in rgba]
        offsets, checks = [(0, 0)], [[]]
        for index in range(1, 4):
            anchors = []
            for name, (left, top, right, bottom) in (
                    ("head", (475, 55, 550, 155)), ("planted_shoes", (420, 695, 595, 750))):
                x0, y0 = max(0, left-35), max(0, top-35)
                x1, y1 = min(1024, right+35), min(768, bottom+35)
                match = cv2.matchTemplate(gray[index][y0:y1, x0:x1], gray[0][top:bottom, left:right], cv2.TM_CCOEFF_NORMED)
                _, confidence, _, point = cv2.minMaxLoc(match)
                anchors.append({"region": name, "confidence": float(confidence),
                                "dx": point[0]+x0-left, "dy": point[1]+y0-top})
            shifts = np.array([[a["dx"], a["dy"]] for a in anchors])
            if min(a["confidence"] for a in anchors) < .89 or np.linalg.norm(shifts[0]-shifts[1]) > 6:
                raise ValueError(f"ambiguous stationary translation: {gender} {index}: {anchors}")
            shift = np.rint(-np.median(shifts, axis=0)).astype(int)
            if np.max(np.abs(shift)) > 25:
                raise ValueError("unexpected translation; requires new review")
            offsets.append(tuple(map(int, shift)))
            checks.append(anchors)
        boxes = []
        for image, (dx, dy) in zip(rgba, offsets):
            ys, xs = np.nonzero(image[..., 3])
            boxes.append([int(xs.min())+dx, int(ys.min())+dy, int(xs.max())+dx+1, int(ys.max())+dy+1])
        boxes = np.array(boxes)
        low, high = boxes[:, :2].min(axis=0), boxes[:, 2:].max(axis=0)
        common = np.rint(np.array([512, 384])-(low+high)/2).astype(int)
        if np.any(low+common < 16) or np.any(high+common > np.array([1024, 768])-16):
            raise ValueError("common translation cannot retain complete artwork with safe margins")
        for index, (image, offset, path) in enumerate(zip(rgba, offsets, paths)):
            dx, dy = np.array(offset)+common
            ys, xs = np.nonzero(image[..., 3])
            result = np.zeros_like(image)
            result[ys+dy, xs+dx] = image[ys, xs]
            if not np.array_equal(result[ys+dy, xs+dx], image[ys, xs]):
                raise AssertionError("visible RGBA data changed")
            candidate = OUTPUT / path.name
            Image.fromarray(result).save(candidate)
            if hashlib.sha256(path.read_bytes()).hexdigest() != hashes[index]:
                raise RuntimeError("source changed during candidate creation")
            reports.append({"file": path.name, "source_sha256": hashes[index],
                            "candidate_sha256": hashlib.sha256(candidate.read_bytes()).hexdigest(),
                            "translation": [int(dx), int(dy)], "scale": 1,
                            "anchor_checks": checks[index], "visible_rgba_changed": 0,
                            "visible_pixel_count": len(xs), "clipped_visible_pixels": 0})
    (OUTPUT / "integrity.json").write_text(json.dumps({"status": "pending_visual_review",
        "scope": "Exact integer translations only, independently reviewed head and planted feet",
        "frames": reports}, indent=2)+"\n")
    print(f"Staged all eight frames in {OUTPUT}; not promoted")


if __name__ == "__main__":
    main()
