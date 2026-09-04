#!/usr/bin/env python3
"""Candidate-only common-anchor framing of recovered kneeling rollout images.

No source asset is overwritten.  All frames of a gender receive one identical
uniform scale, fitted to the union of their knee-relative visible-alpha bounds.
RGB changes are solely from premultiplied-alpha bilinear resampling.
"""

from __future__ import annotations

import hashlib
import json
import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


QA = Path(__file__).resolve().parents[1]
INPUT = QA / "recovered-kneeling-cleanup" / "images"
OUTPUT = Path(__file__).resolve().parent
EXERCISE = "Barbell_Ab_Rollout_-_On_Knees"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bbox(alpha: np.ndarray, threshold: int = 1) -> list[int] | None:
    yy, xx = np.nonzero(alpha >= threshold)
    return [int(xx.min()), int(yy.min()), int(xx.max()) + 1,
            int(yy.max()) + 1] if len(xx) else None


def composite(rgba: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    result = Image.new("RGBA", rgba.size, (*color, 255))
    result.alpha_composite(rgba)
    return result.convert("RGB")


def main() -> None:
    global INPUT, OUTPUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=INPUT)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    INPUT, OUTPUT = args.input.resolve(), args.output.resolve()
    if not OUTPUT.is_relative_to(QA) or OUTPUT == INPUT or OUTPUT.is_relative_to(INPUT):
        raise ValueError("output must be a separate visual-QA staging directory")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    support = json.loads((QA / "recovery-rollout" / "framing-support.json").read_text())
    config = support["kneeling"]
    initial = config["preview_starting_point_only"]
    width, height = initial["canvas"]
    output_anchor = np.array(initial["knee_anchor_on_canvas"], dtype=np.float64)
    # Three extra pixels cover bilinear support and coordinate rounding.
    padding_x, padding_y, resample_margin = 40, 24, 3
    output_images = OUTPUT / "images"
    output_images.mkdir(parents=True, exist_ok=True)
    report = {
        "status": "candidate only; visual review recorded separately",
        "exercise_id": EXERCISE,
        "method": "common per-gender uniform scale; fixed knee anchor; premultiplied-alpha bilinear affine resampling",
        "canvas": [width, height],
        "common_canvas_anchor": output_anchor.tolist(),
        "padding": {"horizontal": padding_x, "vertical": padding_y, "resampling_margin": resample_margin},
        "per_frame_independent_resizing": False,
        "source_alpha_support_threshold": 1,
        "source_rgb_reconstruction": "Never infer alpha from RGB; invisible neighboring RGB is multiplied by zero before resampling.",
        "intrinsic_caveats": config["intrinsic_caveats"],
        "genders": {},
        "frames": [],
    }
    for gender in ("male", "female"):
        sources = []
        relative_boxes = []
        for frame in range(4):
            key = f"{gender}_{frame}"
            name = f"{EXERCISE}_{gender}_v2_{frame}.png"
            path = INPUT / name
            array = np.array(Image.open(path).convert("RGBA"))
            anchor = np.array(config["recovered_crop_coordinates"][key]["knee_anchor"], dtype=np.float64)
            source_box = bbox(array[:, :, 3])
            if source_box is None:
                raise ValueError(f"Empty source: {path}")
            relative_box = np.array(source_box, dtype=np.float64) - np.tile(anchor, 2)
            relative_boxes.append(relative_box)
            sources.append((key, name, path, array, anchor, source_box, sha256(path)))

        boxes = np.array(relative_boxes)
        union = np.array([boxes[:, 0].min(), boxes[:, 1].min(),
                          boxes[:, 2].max(), boxes[:, 3].max()])
        limits = [float(initial["uniform_scale"])]
        margins = np.array([padding_x, padding_y]) + resample_margin
        canvas = np.array([width, height], dtype=np.float64)
        for axis in (0, 1):
            if union[axis] < 0:
                limits.append(float((output_anchor[axis] - margins[axis]) / -union[axis]))
            if union[axis + 2] > 0:
                limits.append(float((canvas[axis] - margins[axis] - output_anchor[axis]) / union[axis + 2]))
        scale = min(limits)
        report["genders"][gender] = {
            "shared_uniform_scale": scale,
            "requested_initial_scale": initial["uniform_scale"],
            "source_knee_relative_union_xyxy": union.tolist(),
            "transformed_union_xyxy": (union * scale + np.tile(output_anchor, 2)).tolist(),
            "scale_limits": limits,
        }
        contact = Image.new("RGB", (width * 2, height * 2), (18, 18, 20))
        for frame, (key, name, path, array, anchor, source_box, before_hash) in enumerate(sources):
            matrix = np.array([[scale, 0., output_anchor[0] - scale * anchor[0]],
                               [0., scale, output_anchor[1] - scale * anchor[1]]])
            normalized = array.astype(np.float32) / 255.
            premultiplied = np.concatenate((normalized[:, :, :3] * normalized[:, :, 3:4],
                                            normalized[:, :, 3:4]), axis=2)
            warped = cv2.warpAffine(premultiplied, matrix, (width, height),
                                    flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT,
                                    borderValue=(0, 0, 0, 0))
            alpha = np.clip(warped[:, :, 3:4], 0., 1.)
            rgb = np.divide(np.clip(warped[:, :, :3], 0., alpha), alpha,
                            out=np.zeros_like(warped[:, :, :3]), where=alpha > 1e-8)
            result = np.rint(np.concatenate((rgb, alpha), axis=2) * 255.).astype(np.uint8)
            result[result[:, :, 3] == 0, :3] = 0
            image = Image.fromarray(result)
            destination = output_images / name
            image.save(destination)
            preview = Image.new("RGB", (width * 2, height))
            dark = composite(image, (12, 12, 14))
            light = composite(image, (245, 245, 247))
            preview.paste(dark, (0, 0))
            preview.paste(light, (width, 0))
            preview.save(OUTPUT / f"{name[:-4]}-preview.png")
            contact.paste(dark, ((frame % 2) * width, (frame // 2) * height))
            ImageDraw.Draw(contact).text(((frame % 2) * width + 12, (frame // 2) * height + 12),
                                        f"{gender} frame {frame}", fill=(240, 240, 240))
            out_box = bbox(result[:, :, 3])
            visible = result[:, :, 3] > 0
            edge_pixels = int(visible[0].sum() + visible[-1].sum() + visible[:, 0].sum() + visible[:, -1].sum())
            entry = {
                "key": key, "source": str(path), "output": str(destination),
                "source_size": [array.shape[1], array.shape[0]],
                "source_bbox_alpha_ge1": source_box, "output_bbox_alpha_ge1": out_box,
                "source_anchor": anchor.tolist(), "affine_matrix": matrix.tolist(),
                "transformed_anchor": (matrix[:, :2] @ anchor + matrix[:, 2]).tolist(),
                "source_sha256_before": before_hash,
                "source_sha256_after": sha256(path),
                "output_sha256": sha256(destination),
                "output_edge_visible_pixels": edge_pixels,
                "output_fully_transparent_fraction": round(float((result[:, :, 3] == 0).mean()), 6),
                "visual_review_status": "pending",
            }
            assert entry["source_sha256_before"] == entry["source_sha256_after"]
            assert edge_pixels == 0, name
            report["frames"].append(entry)
        contact.resize((1024, 768), Image.Resampling.LANCZOS).save(OUTPUT / f"{gender}-contact.png")
    report["source_integrity"] = "All eight input hashes unchanged. No canonical or packaged asset modified."
    (OUTPUT / "framing-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"output": str(OUTPUT), "frames": len(report["frames"]),
                      "genders": report["genders"], "source_integrity": report["source_integrity"]}, indent=2))


if __name__ == "__main__":
    main()
