#!/usr/bin/env python3
"""Read-only quality triage for every packaged workout illustration.

Requires Pillow and NumPy. Never writes, resizes, normalizes, or repairs source
images. Reduced arrays are used only for numerical analysis. The JSON/CSV/Markdown
reports are candidate queues, not proof that an exercise is correct or defective.
Use built-in image editing for any requested repair, then review the result.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import sys
from collections import Counter, deque
from concurrent.futures import ProcessPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "shared" / "workout-vectors"
OUTPUT = ROOT / "artifacts" / "workout-visual-qa"


def rounded(value: float) -> float:
    return round(float(value), 6)


def longest_run(values: np.ndarray) -> int:
    padded = np.concatenate(([False], values, [False])).astype(np.int8)
    changes = np.diff(padded)
    starts, ends = np.flatnonzero(changes == 1), np.flatnonzero(changes == -1)
    return int((ends - starts).max()) if len(starts) else 0


def components(mask: np.ndarray) -> list[dict]:
    """4-connected components on an analysis-only 256-pixel-wide array."""
    seen = np.zeros(mask.shape, dtype=bool)
    height, width = mask.shape
    found = []
    for sy, sx in zip(*np.nonzero(mask)):
        if seen[sy, sx]:
            continue
        seen[sy, sx] = True
        queue = deque([(int(sy), int(sx))])
        count = 0
        left = right = int(sx)
        top = bottom = int(sy)
        while queue:
            y, x = queue.popleft()
            count += 1
            left, right = min(left, x), max(right, x)
            top, bottom = min(top, y), max(bottom, y)
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        if count >= 8:
            found.append({"pixels": count, "bbox": [left, top, right + 1, bottom + 1]})
    return sorted(found, key=lambda value: value["pixels"], reverse=True)


def inspect(job: tuple[str, str, int, str]) -> dict:
    exercise_id, gender, frame, filename = job
    path = SOURCE / filename
    record = {
        "exercise_id": exercise_id, "gender": gender, "frame": frame,
        "file": filename, "review_status": "pending", "flags": [],
    }
    try:
        original = path.read_bytes()
        record["file_sha256"] = hashlib.sha256(original).hexdigest()
        with Image.open(io.BytesIO(original)) as source:
            rgba = np.asarray(source.convert("RGBA"))
            record["size"] = list(source.size)
        height, width = rgba.shape[:2]
        alpha = rgba[:, :, 3]
        visible = alpha >= 16
        opaque = alpha >= 224
        ys, xs = np.nonzero(visible)
        if not len(xs):
            raise ValueError("no visible artwork")
        left, right, top, bottom = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
        record["bbox"] = [left, top, right, bottom]
        record["bbox_normalized"] = [rounded(left / width), rounded(top / height), rounded(right / width), rounded(bottom / height)]
        record["bbox_width_fraction"] = rounded((right - left) / width)
        record["bbox_height_fraction"] = rounded((bottom - top) / height)
        record["bbox_longest_fraction"] = rounded(max((right - left) / width, (bottom - top) / height))
        record["visible_fraction"] = rounded(visible.mean())
        record["alpha_center"] = [rounded(xs.mean() / width), rounded(ys.mean() / height)]
        record["bottom_fraction"] = rounded(bottom / height)
        record["edge_visible_pixels"] = int(visible[:2, :].sum() + visible[-2:, :].sum() + visible[:, :2].sum() + visible[:, -2:].sum())
        record["bbox_vertical_flat_cut_pixels"] = max(longest_run(opaque[top:bottom, left]), longest_run(opaque[top:bottom, right - 1]))
        record["bbox_horizontal_flat_cut_pixels"] = max(longest_run(opaque[top, left:right]), longest_run(opaque[bottom - 1, left:right]))
        record["transparent_fraction"] = rounded((alpha == 0).mean())
        record["partially_transparent_fraction"] = rounded(((alpha > 0) & (alpha < 255)).mean())
        if record["edge_visible_pixels"] > 12:
            record["flags"].append("possible_edge_clipping")
        if record["bbox_vertical_flat_cut_pixels"] >= 24 or record["bbox_horizontal_flat_cut_pixels"] >= 80:
            record["flags"].append("possible_precropped_flat_boundary")
        if record["bbox_longest_fraction"] < 0.7:
            record["flags"].append("small_canvas_occupancy")
        if record["transparent_fraction"] < 0.02:
            record["flags"].append("little_or_no_real_transparency")
        if (width, height) != (1024, 768):
            record["flags"].append("nonstandard_canvas")

        # Ignore RGB hidden under alpha, so a PNG's invisible matte cannot be
        # mislabeled as a visible white/checkerboard defect.
        rgb = rgba[:, :, :3]
        low, high = rgb.min(axis=2), rgb.max(axis=2)
        neutral = (high.astype(np.int16) - low.astype(np.int16)) <= 12
        pale = opaque & neutral & (low >= 210)
        record["opaque_pale_fraction"] = rounded(pale.mean())
        record["opaque_pale_of_visible"] = rounded(pale.sum() / len(xs))

        step = max(1, width // 256)
        small = rgba[::step, ::step]
        small_rgb = small[:, :, :3]
        small_low, small_high = small_rgb.min(axis=2), small_rgb.max(axis=2)
        small_neutral = (small_high.astype(np.int16) - small_low.astype(np.int16)) <= 12
        small_pale = (small[:, :, 3] >= 224) & small_neutral & (small_low >= 190)
        areas = components(small_pale)
        record["pale_components"] = [{
            "fraction": rounded(area["pixels"] / small_pale.size),
            "bbox": [int(number * step) for number in area["bbox"]],
        } for area in areas[:5]]
        largest = areas[0]["pixels"] / small_pale.size if areas else 0
        record["largest_pale_component_fraction"] = rounded(largest)

        gray = small_rgb.mean(axis=2)
        horizontal_pairs = small_pale[:, 1:] & small_pale[:, :-1]
        vertical_pairs = small_pale[1:, :] & small_pale[:-1, :]
        dx = np.abs(np.diff(gray, axis=1))
        dy = np.abs(np.diff(gray, axis=0))
        # Baked checkerboards contain many orthogonal 7-55-level neutral edges.
        # Metal texture can also produce these, therefore this is only a signal.
        hx = int(((dx >= 7) & (dx <= 55) & horizontal_pairs).sum())
        vy = int(((dy >= 7) & (dy <= 55) & vertical_pairs).sum())
        record["neutral_horizontal_transitions"] = hx
        record["neutral_vertical_transitions"] = vy
        record["checker_transition_score"] = rounded(math.sqrt(hx * vy) / small_pale.size)
        if largest >= 0.0025 and hx >= 20 and vy >= 20:
            record["flags"].append("suspected_baked_checkerboard")
        if largest >= 0.008 or record["opaque_pale_fraction"] >= 0.04:
            record["flags"].append("large_opaque_pale_region")

        canonical = rgba.copy()
        canonical[alpha == 0, :3] = 0
        record["visible_pixel_sha256"] = hashlib.sha256(canonical.tobytes()).hexdigest()
        # Tiny premultiplied RGBA grid enables near-duplicate detection without
        # saving thumbnails or modifying the PNG. Both RGB and alpha matter.
        thumb = np.asarray(Image.fromarray(rgba).resize((32, 24), Image.Resampling.BOX), dtype=np.float32) / 255
        thumb[:, :, :3] *= thumb[:, :, 3:4]
        record["_fingerprint"] = thumb.flatten().tolist()
        record["score"] = rounded(
            (100 if "suspected_baked_checkerboard" in record["flags"] else 0)
            + (60 if "large_opaque_pale_region" in record["flags"] else 0)
            + (35 if "possible_edge_clipping" in record["flags"] else 0)
            + (20 if "possible_precropped_flat_boundary" in record["flags"] else 0)
            + (25 if "small_canvas_occupancy" in record["flags"] else 0)
            + min(30, largest * 300)
        )
    except (OSError, ValueError) as error:
        record["error"] = str(error)
        record["flags"].append("unreadable_or_empty")
        record["score"] = 1000
    return record


def span(records: list[dict], field: str) -> float:
    values = [record[field] for record in records]
    return rounded(max(values) - min(values))


def ratio(records: list[dict], field: str) -> float:
    values = [record[field] for record in records]
    return rounded(max(values) / max(0.000001, min(values)))


def summarize_sequence(records: list[dict]) -> dict:
    result = {"gender": records[0]["gender"], "flags": [], "review_status": "pending"}
    if any("error" in record for record in records):
        result["flags"].append("invalid_frame")
        return result
    result["visible_area_ratio"] = ratio(records, "visible_fraction")
    result["bbox_width_ratio"] = ratio(records, "bbox_width_fraction")
    result["bbox_height_ratio"] = ratio(records, "bbox_height_fraction")
    result["longest_occupancy_ratio"] = ratio(records, "bbox_longest_fraction")
    result["bottom_span"] = span(records, "bottom_fraction")
    result["alpha_center_x_span"] = rounded(max(record["alpha_center"][0] for record in records) - min(record["alpha_center"][0] for record in records))
    result["alpha_center_y_span"] = rounded(max(record["alpha_center"][1] for record in records) - min(record["alpha_center"][1] for record in records))
    if result["visible_area_ratio"] > 1.3 or result["longest_occupancy_ratio"] > 1.25:
        result["flags"].append("possible_scale_variation")
    if result["bottom_span"] > 0.07 or result["alpha_center_x_span"] > 0.10 or result["alpha_center_y_span"] > 0.10:
        result["flags"].append("possible_position_variation")
    result["exact_duplicate_pairs"] = []
    result["near_duplicate_pairs"] = []
    for left in range(len(records)):
        for right in range(left + 1, len(records)):
            a, b = records[left], records[right]
            if a["visible_pixel_sha256"] == b["visible_pixel_sha256"]:
                result["exact_duplicate_pairs"].append([a["frame"], b["frame"]])
            elif "_fingerprint" in a and "_fingerprint" in b:
                mean_error = float(np.abs(np.array(a["_fingerprint"]) - np.array(b["_fingerprint"])).mean())
                if mean_error < 0.012:
                    result["near_duplicate_pairs"].append({"frames": [a["frame"], b["frame"]], "mean_error": rounded(mean_error)})
    if result["exact_duplicate_pairs"]:
        result["flags"].append("exact_duplicate_frames")
    if result["near_duplicate_pairs"]:
        result["flags"].append("near_duplicate_frames")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--exercise", help="Audit one exact exercise ID for a quick diagnostic.")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    manifest = json.loads((SOURCE / "exercise-visual-manifest.json").read_text())
    entries = manifest["exercises"]
    if len(entries) != 875 or len({entry["exerciseId"] for entry in entries}) != 875:
        parser.error("manifest must contain exactly 875 unique exercise IDs")
    if any(len(entry[gender + "Frames"]) != 4 for entry in entries for gender in ("male", "female")):
        parser.error("each exercise must have four frames for each gender")
    if args.exercise:
        entries = [entry for entry in entries if entry["exerciseId"] == args.exercise]
        if not entries:
            parser.error("exercise is not in the manifest")
    jobs = [(entry["exerciseId"], gender, index, stem + ".png")
            for entry in entries for gender in ("male", "female")
            for index, stem in enumerate(entry[gender + "Frames"])]
    images = []
    with ProcessPoolExecutor(max_workers=args.workers) as executor:
        for count, record in enumerate(executor.map(inspect, jobs, chunksize=8), 1):
            images.append(record)
            if count % 500 == 0:
                print(f"audited {count}/{len(jobs)} images", flush=True)
    exercise_reports = []
    for entry in entries:
        records = [record for record in images if record["exercise_id"] == entry["exerciseId"]]
        sequences = [summarize_sequence([record for record in records if record["gender"] == gender]) for gender in ("male", "female")]
        flags = sorted({flag for record in records + sequences for flag in record["flags"]})
        exercise_reports.append({
            "exercise_id": entry["exerciseId"], "review_status": "pending", "candidate_flags": flags,
            "score": rounded(max(record["score"] for record in records) + sum(20 * len(sequence["flags"]) for sequence in sequences)),
            "candidate_image_count": sum(bool(record["flags"]) for record in records),
            "sequences": sequences,
        })
    for record in images:
        record.pop("_fingerprint", None)
    exercise_reports.sort(key=lambda record: (-record["score"], record["exercise_id"]))
    for rank, record in enumerate(exercise_reports, 1):
        record["review_priority_rank"] = rank
    flag_counts = Counter(flag for record in images for flag in record["flags"])
    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": str(SOURCE.relative_to(ROOT)), "images_audited": len(images),
        "exercises_audited": len(entries), "images_with_candidate_flags": sum(bool(record["flags"]) for record in images),
        "exercises_with_candidate_flags": sum(bool(record["candidate_flags"]) for record in exercise_reports),
        "visual_review_status": "not_assessed_by_numerical_audit",
        "visual_review_ledger_paths": [
            "artifacts/workout-visual-qa/audit-visual-observations.json",
            "artifacts/workout-visual-qa/review-initial-exercises.md",
        ],
        "image_flag_counts": dict(sorted(flag_counts.items())),
        "sequence_flag_counts": dict(sorted(Counter(flag for record in exercise_reports for sequence in record["sequences"] for flag in sequence["flags"]).items())),
        "limits": [
            "This is read-only numerical triage, not a visual pass or a repair.",
            "Pale regions may be legitimate shoes, teeth, equipment highlights, or clothing; inspect before editing.",
            "Bounding-box and alpha-area changes can represent correct exercise movement, not inconsistent person scale.",
            "Flat artwork boundaries can be normal equipment geometry; they only flag possible pre-cropped content.",
            "Duplicate return poses and static stretch frames can be intentional; review before treating as defects.",
            "Small enclosed remnants and subtle limb or identity discontinuities can evade these heuristics.",
            "Machine-queue review states remain pending; actual visual findings and repair acceptance are tracked in the separate linked ledgers.",
        ],
    }
    args.output.mkdir(parents=True, exist_ok=True)
    prefix = "audit" if not args.exercise else "audit-" + args.exercise
    (args.output / (prefix + ".json")).write_text(json.dumps({"summary": summary, "exercises": exercise_reports, "images": images}, indent=2) + "\n")
    with (args.output / (prefix + "-images.csv")).open("w", newline="") as handle:
        fields = ["file", "exercise_id", "gender", "frame", "review_status", "score", "flags", "bbox", "visible_fraction", "largest_pale_component_fraction", "checker_transition_score", "file_sha256"]
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(images)
    with (args.output / (prefix + "-exercises.csv")).open("w", newline="") as handle:
        fields = ["review_priority_rank", "exercise_id", "review_status", "score", "candidate_image_count", "candidate_flags"]
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(exercise_reports)
    lines = ["# Workout artwork audit", "", f"Read-only numerical audit of {len(images):,} images for {len(entries)} exercises.", "", "No source images were changed. This numerical queue does not track visual acceptance; candidates are not confirmed defects.", "", "Visual findings are recorded separately in [Band Skull Crusher observations](audit-visual-observations.json) and [initial exercise review](review-initial-exercises.md). Pending machine-queue statuses do not override those ledgers.", "", "## Summary", ""]
    lines += [f"- {key}: {value}" for key, value in summary.items() if isinstance(value, int)]
    lines += ["", "## Image candidate counts", ""] + [f"- {key}: {value}" for key, value in summary["image_flag_counts"].items()]
    lines += ["", "## Interpretation limits", ""] + [f"- {limit}" for limit in summary["limits"]]
    lines += ["", "## First 30 review candidates", "", "| Rank | Exercise | Score | Flags |", "| --- | --- | ---: | --- |"]
    lines += [f"| {record['review_priority_rank']} | {record['exercise_id']} | {record['score']} | {', '.join(record['candidate_flags'])} |" for record in exercise_reports[:30]]
    (args.output / (prefix + ".md")).write_text("\n".join(lines) + "\n")
    print(json.dumps(summary, indent=2))
    return 1 if any("error" in record for record in images) else 0


if __name__ == "__main__":
    sys.exit(main())
