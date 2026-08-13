#!/usr/bin/env python3
"""Record a human accept/reject review for one generated exercise frame."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path


FIELDS = ("characterApproved", "poseEquipmentApproved", "anatomyApproved", "artifactFree")


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as temporary:
        json.dump(value, temporary, indent=2, sort_keys=True)
        temporary.write("\n")
        temporary.flush(); os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, path)
    os.chmod(path, 0o644)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path, default=Path(__file__).with_name("jobs-v1.jsonl"))
    parser.add_argument("--reviews", type=Path,
                        default=Path(__file__).with_name("manual-reviews-v1.json"))
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--reviewer", required=True)
    parser.add_argument("--decision", choices=("accept", "reject"))
    parser.add_argument("--notes", default="")
    parser.add_argument("--character", choices=("yes", "no"))
    parser.add_argument("--pose-equipment", choices=("yes", "no"))
    parser.add_argument("--anatomy", choices=("yes", "no"))
    parser.add_argument("--artifact-free", choices=("yes", "no"))
    parser.add_argument(
        "--intermediate-pose",
        choices=("yes", "no"),
        help="Required explicit motion-order approval for schema-v2 in-between frames",
    )
    parser.add_argument("--clear", action="store_true",
                        help="Remove a stale manual decision for this job")
    args = parser.parse_args()
    jobs = {
        job["jobID"]: job
        for line in args.jobs.read_text().splitlines()
        if line.strip()
        for job in (json.loads(line),)
    }
    if args.job_id not in jobs:
        raise SystemExit(f"Unknown job ID: {args.job_id}")
    if not args.clear and args.decision is None:
        raise SystemExit("--decision is required unless --clear is used")
    values = {
        "characterApproved": args.character,
        "poseEquipmentApproved": args.pose_equipment,
        "anatomyApproved": args.anatomy,
        "artifactFree": args.artifact_free,
    }
    job = jobs[args.job_id]
    is_intermediate = job.get("sequence", {}).get("frameRole") == "inbetween"
    if is_intermediate:
        values["intermediatePoseApproved"] = args.intermediate_pose
    if args.decision == "accept" and any(value != "yes" for value in values.values()):
        raise SystemExit("Accept requires explicit --character/--pose-equipment/--anatomy/--artifact-free yes")
    lock_path = args.reviews.with_suffix(args.reviews.suffix + ".lock")
    with lock_path.open("a+") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        ledger = (json.loads(args.reviews.read_text()) if args.reviews.is_file()
                  else {"schemaVersion": 1, "jobs": {}})
        if args.clear:
            removed = ledger["jobs"].pop(args.job_id, None)
            atomic_json(args.reviews, ledger)
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            print(json.dumps({"jobID": args.job_id, "cleared": removed is not None}, sort_keys=True))
            return
        review = {
            field: values[field] == "yes" if values[field] is not None else False
            for field in values
        }
        review.update({
            "decision": args.decision,
            "reviewer": args.reviewer,
            "reviewedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "notes": args.notes[:2000],
        })
        ledger["jobs"][args.job_id] = review
        atomic_json(args.reviews, ledger)
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
    print(json.dumps({"jobID": args.job_id, **review}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
