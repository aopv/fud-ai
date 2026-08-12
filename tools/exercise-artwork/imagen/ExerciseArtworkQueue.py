#!/usr/bin/env python3
"""Atomically claim and finish resumable one-output Imagen artwork jobs."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_jobs(path: Path) -> tuple[list[dict], dict[str, dict]]:
    jobs = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    by_id = {job["jobID"]: job for job in jobs}
    if len(jobs) != 3500 or len(by_id) != 3500:
        raise SystemExit("Expected exactly 3,500 unique jobs")
    return jobs, by_id


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as temporary:
        json.dump(value, temporary, indent=2, sort_keys=True)
        temporary.write("\n")
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, path)
    os.chmod(path, 0o644)


@contextmanager
def locked_state(path: Path):
    lock_path = path.with_suffix(path.suffix + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        state = json.loads(path.read_text())
        yield state
        atomic_json(path, state)
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def verify_state(state: dict, jobs: dict[str, dict]) -> None:
    if set(state.get("jobs", {})) != set(jobs):
        raise SystemExit("State/job ID parity failure; rerun BuildImagenExerciseJobs.py")
    mismatched = [
        job_id for job_id, job in jobs.items()
        if state["jobs"][job_id].get("jobFingerprint") != job["jobFingerprint"]
    ]
    if mismatched:
        raise SystemExit("State has stale fingerprints; rerun BuildImagenExerciseJobs.py")


def canonical_raw_path(repo: Path, job: dict) -> Path:
    return (
        repo / "shared/exercise-artwork/fud-flat-raster-v1/raw"
        / job["gender"] / job["exerciseID"] / f"{job['frameIndex']}.png"
    )


def preserve_generated_input(repo: Path, job: dict, input_path: Path) -> str:
    """Copy an untouched result into the ignored canonical raw tree and return a portable path."""
    destination = canonical_raw_path(repo, job)
    destination.parent.mkdir(parents=True, exist_ok=True)
    source_hash = sha256(input_path)
    if destination.is_file() and sha256(destination) == source_hash:
        return destination.relative_to(repo).as_posix()
    with tempfile.NamedTemporaryFile(dir=destination.parent, suffix=".png", delete=False) as temp:
        temporary_path = Path(temp.name)
    try:
        shutil.copyfile(input_path, temporary_path)
        if sha256(temporary_path) != source_hash:
            raise SystemExit(f"Raw provenance copy hash mismatch: {job['jobID']}")
        os.replace(temporary_path, destination)
        os.chmod(destination, 0o644)
    finally:
        temporary_path.unlink(missing_ok=True)
    return destination.relative_to(repo).as_posix()


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path, default=Path(__file__).with_name("jobs-v1.jsonl"))
    parser.add_argument("--state", type=Path, default=Path(__file__).with_name("state-v1.json"))
    parser.add_argument(
        "--normalizer", type=Path,
        default=Path(__file__).with_name("NormalizeGeneratedExerciseArtwork.py"),
    )
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    commands.add_parser(
        "migrate-provenance",
        help="Copy recorded generation inputs to canonical raw paths and store repo-relative paths.",
    )
    claim = commands.add_parser("claim")
    claim.add_argument("--worker", required=True)
    claim.add_argument("--gender", choices=("male", "female"))
    claim.add_argument("--pilot-only", action="store_true")
    claim.add_argument("--job-id", help="Claim this exact pending job instead of the next job")
    complete = commands.add_parser("complete")
    complete.add_argument("--job-id", required=True)
    complete.add_argument("--input", type=Path, required=True)
    complete.add_argument("--chroma-key", action="store_true")
    complete.add_argument(
        "--content-size",
        type=int,
        help=(
            "Explicit deterministic refit size passed to the normalizer. Omit for the default; "
            "use only to repair a documented occupancy-only QA failure from preserved raw input."
        ),
    )
    complete.add_argument(
        "--chroma-remover", type=Path,
        default=Path.home() / ".codex/skills/.system/imagegen/scripts/remove_chroma_key.py",
    )
    fail = commands.add_parser("fail")
    fail.add_argument("--job-id", required=True)
    fail.add_argument("--error", required=True)
    release = commands.add_parser("release")
    release.add_argument("--job-id", required=True)
    reject = commands.add_parser("record-rejected")
    reject.add_argument("--job-id", required=True)
    reject.add_argument("--input", type=Path, required=True)
    reject.add_argument("--error", required=True)
    reject.add_argument("--chroma-key", action="store_true")
    reject.add_argument(
        "--chroma-remover", type=Path,
        default=Path.home() / ".codex/skills/.system/imagegen/scripts/remove_chroma_key.py",
    )
    args = parser.parse_args()

    ordered_jobs, jobs = load_jobs(args.jobs)
    with locked_state(args.state) as state:
        verify_state(state, jobs)
        states = state["jobs"]
        if args.command == "status":
            result = {
                "total": len(states),
                "statuses": dict(sorted(Counter(item["status"] for item in states.values()).items())),
                "qaStatuses": dict(sorted(Counter(
                    item.get("qaStatus") or "unset" for item in states.values()
                ).items())),
            }
        elif args.command == "migrate-provenance":
            migrated = []
            for job_id, item in states.items():
                recorded = item.get("generatedInputPath")
                if not recorded:
                    continue
                input_path = Path(recorded)
                if not input_path.is_absolute():
                    input_path = repo / input_path
                if not input_path.is_file():
                    raise SystemExit(f"Recorded generated input missing: {job_id} / {input_path}")
                portable = preserve_generated_input(repo, jobs[job_id], input_path)
                if item["generatedInputPath"] != portable:
                    item["generatedInputPath"] = portable
                    migrated.append(job_id)
                normalization = item.get("normalization")
                if isinstance(normalization, dict) and normalization.get("input") != portable:
                    normalization["input"] = portable
            result = {
                "provenanceEntries": sum(
                    1 for item in states.values() if item.get("generatedInputPath")
                ),
                "migrated": len(migrated),
                "jobIDs": sorted(migrated),
            }
        elif args.command == "claim":
            eligible = [
                job for job in ordered_jobs
                if states[job["jobID"]]["status"] == "pending"
                and (args.gender is None or job["gender"] == args.gender)
                and (not args.pilot_only or job["pilot"])
                and (args.job_id is None or job["jobID"] == args.job_id)
            ]
            if not eligible:
                raise SystemExit("No eligible pending job")
            job = eligible[0]
            item = states[job["jobID"]]
            item.update({
                "status": "claimed",
                "attempts": int(item.get("attempts", 0)) + 1,
                "claimedBy": args.worker,
                "claimedAt": utc_now(),
                "error": None,
            })
            result = job
        else:
            if args.job_id not in jobs:
                raise SystemExit(f"Unknown job ID: {args.job_id}")
            job = jobs[args.job_id]
            item = states[args.job_id]
            if args.command == "record-rejected":
                if item["status"] not in {"pending", "failed", "completed_pending_qa"}:
                    raise SystemExit(f"Cannot record rejection from state {item['status']}")
                input_path = args.input.resolve()
                if not input_path.is_file():
                    raise SystemExit(f"Rejected generated image missing: {input_path}")
                generated_input_path = preserve_generated_input(repo, job, input_path)
                output_path = repo / job["outputPath"]
                if output_path.exists() and not item.get("outputSHA256"):
                    raise SystemExit(f"Unowned output already exists: {output_path}")
                normalizer_input = input_path
                with tempfile.TemporaryDirectory(prefix="fud-exercise-rejected-") as temporary:
                    if args.chroma_key:
                        if not args.chroma_remover.is_file():
                            raise SystemExit(f"Chroma remover missing: {args.chroma_remover}")
                        normalizer_input = Path(temporary) / "transparent.png"
                        subprocess.run(
                            [sys.executable, str(args.chroma_remover), "--input", str(input_path),
                             "--out", str(normalizer_input), "--auto-key", "border",
                             "--soft-matte", "--transparent-threshold", "12",
                             "--opaque-threshold", "220", "--edge-contract", "1",
                             "--despill"],
                            check=True,
                        )
                    normalization = subprocess.run(
                        [sys.executable, str(args.normalizer), "--input", str(normalizer_input),
                         "--output", str(output_path)],
                        check=True, capture_output=True, text=True,
                    )
                item.update({
                    "status": "qa_failed",
                    "generatedInputPath": generated_input_path,
                    "outputSHA256": sha256(output_path),
                    "qaStatus": "rejected",
                    "error": args.error[:2000],
                })
                result = {
                    "jobID": args.job_id, "outputPath": job["outputPath"],
                    "normalization": json.loads(normalization.stdout.strip().splitlines()[-1]),
                    **item,
                }
            elif args.command == "complete":
                if item["status"] != "claimed":
                    raise SystemExit(f"Job must be claimed, not {item['status']}")
                input_path = args.input.resolve()
                if not input_path.is_file():
                    raise SystemExit(f"Generated image missing: {input_path}")
                generated_input_path = preserve_generated_input(repo, job, input_path)
                output_path = repo / job["outputPath"]
                normalizer_input = input_path
                with tempfile.TemporaryDirectory(prefix="fud-exercise-chroma-") as temporary:
                    if args.chroma_key:
                        if not args.chroma_remover.is_file():
                            raise SystemExit(f"Chroma remover missing: {args.chroma_remover}")
                        normalizer_input = Path(temporary) / "transparent.png"
                        subprocess.run(
                            [sys.executable, str(args.chroma_remover), "--input", str(input_path),
                             "--out", str(normalizer_input), "--auto-key", "border",
                             "--soft-matte", "--transparent-threshold", "12",
                             "--opaque-threshold", "220", "--edge-contract", "1",
                             "--despill"],
                            check=True,
                        )
                    normalize_command = [
                        sys.executable, str(args.normalizer), "--input", str(normalizer_input),
                        "--output", str(output_path),
                    ]
                    if args.content_size is not None:
                        normalize_command.extend(["--content-size", str(args.content_size)])
                    normalization = subprocess.run(
                        normalize_command,
                        check=True,
                        capture_output=True,
                        text=True,
                    )
                normalized = json.loads(normalization.stdout.strip().splitlines()[-1])
                item.update({
                    "status": "completed_pending_qa",
                    "completedAt": utc_now(),
                    "generatedInputPath": generated_input_path,
                    "normalization": normalized,
                    "outputSHA256": sha256(output_path),
                    "qaStatus": "pending",
                    "error": None,
                })
                result = {"jobID": args.job_id, "outputPath": job["outputPath"],
                          "normalization": normalized, **item}
            elif args.command == "fail":
                if item["status"] != "claimed":
                    raise SystemExit(f"Job must be claimed, not {item['status']}")
                item.update({
                    "status": "failed",
                    "failedAt": utc_now(),
                    "error": args.error[:2000],
                })
                result = {"jobID": args.job_id, **item}
            else:
                if item["status"] not in {
                    "claimed", "failed", "completed_pending_qa", "qa_failed"
                }:
                    raise SystemExit(f"Cannot release job in state {item['status']}")
                output_path = repo / job["outputPath"]
                if output_path.is_file() and item.get("outputSHA256"):
                    if sha256(output_path) != item["outputSHA256"]:
                        raise SystemExit(f"Refusing to release hash-drifted output: {args.job_id}")
                    output_path.unlink()
                item.update({
                    "status": "pending",
                    "claimedBy": None,
                    "claimedAt": None,
                    "generatedInputPath": None,
                    "normalization": None,
                    "outputSHA256": None,
                    "qaStatus": None,
                    "error": None,
                })
                result = {"jobID": args.job_id, **item}
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
