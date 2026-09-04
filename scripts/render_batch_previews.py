#!/usr/bin/env python3
"""Render dark/light contact sheets for a review batch."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", type=int, default=1)
    parser.add_argument(
        "--batch-json",
        type=Path,
        help="Override batch JSON path (default derives from --batch)",
    )
    args = parser.parse_args()

    batch_json = args.batch_json or (
        ROOT / f"artifacts/workout-visual-qa/review-batches/batch-{args.batch:02d}/batch-{args.batch:02d}.json"
    )
    if not batch_json.is_file():
        raise SystemExit(f"Batch JSON not found: {batch_json}")

    batch = json.loads(batch_json.read_text(encoding="utf-8"))
    if batch.get("batchNumber") != args.batch:
        parser.error(f"batch JSON batchNumber={batch.get('batchNumber')} != --batch {args.batch}")

    failed: list[tuple[str, str]] = []
    for item in batch["exercises"]:
        exercise = item["exerciseId"]
        output = ROOT / "artifacts/workout-visual-qa/review-batches" / f"batch-{args.batch:02d}" / "previews" / exercise
        cmd = [
            sys.executable,
            str(ROOT / "scripts/render_workout_review.py"),
            "--input",
            str(ROOT / "shared/workout-vectors"),
            "--exercise",
            exercise,
            "--output",
            str(output),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            failed.append((exercise, result.stderr.strip() or result.stdout.strip()))
            print(f"FAIL {exercise}", file=sys.stderr)
        else:
            print(f"OK {exercise}")

    if failed:
        for exercise, err in failed[:5]:
            print(f"{exercise}: {err[:200]}", file=sys.stderr)
        raise SystemExit(f"{len(failed)} of {len(batch['exercises'])} renders failed")

    print(f"Rendered {len(batch['exercises'])} exercises to batch-{args.batch:02d}/previews/")


if __name__ == "__main__":
    main()
