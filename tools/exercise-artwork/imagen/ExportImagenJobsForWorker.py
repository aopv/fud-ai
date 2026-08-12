#!/usr/bin/env python3
"""Export immutable, one-output Imagen call payloads from the canonical queue.

This helper never mutates queue state. Workers claim through ExerciseArtworkQueue.py, make one
image call with exactly the two referenced inputs, then complete/fail through that queue owner.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--jobs",
        type=Path,
        default=repo / "tools/exercise-artwork/imagen/jobs-v1.jsonl",
    )
    parser.add_argument("--gender", choices=("male", "female"), required=True)
    parser.add_argument("--pilot-only", action="store_true")
    parser.add_argument("--job-id")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    jobs = [json.loads(line) for line in args.jobs.read_text().splitlines() if line.strip()]
    selected = [
        job
        for job in jobs
        if job["gender"] == args.gender
        and (not args.pilot_only or job["pilot"])
        and (args.job_id is None or job["jobID"] == args.job_id)
    ]
    if args.job_id and len(selected) != 1:
        raise SystemExit(f"Expected one matching job for {args.job_id}, found {len(selected)}")
    if args.gender == "male" and not args.pilot_only and not args.job_id and len(selected) != 1750:
        raise SystemExit(f"Expected exactly 1,750 male jobs, found {len(selected)}")

    payloads = []
    for job in selected:
        if not job.get("characterReferenceSHA256"):
            raise SystemExit(f"Character reference is not ready: {job['jobID']}")
        if job["sourceReferenceQA"]["status"] != "ready":
            continue
        payloads.append({
            "jobID": job["jobID"],
            "gender": job["gender"],
            "prompt": job["prompt"],
            "referencedImagePaths": [
                str((repo / job["characterReferencePath"]).resolve()),
                str((repo / job["sourceImagePath"]).resolve()),
            ],
            "expectedOutputPath": str((repo / job["outputPath"]).resolve()),
            "contract": {
                "callsPerJob": 1,
                "outputsPerCall": 1,
                "inputOrder": ["approved character identity", "exact legacy pose/equipment frame"],
                "normalization": "ExerciseArtworkQueue.py complete",
            },
        })

    content = "".join(json.dumps(payload, sort_keys=True) + "\n" for payload in payloads)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(content)
    else:
        print(content, end="")


if __name__ == "__main__":
    main()
