#!/usr/bin/env python3
"""Atomically activate a six-frame queue while preserving legacy endpoint evidence.

Dry-run is the default. Apply first materializes legacy frame 1 as frame 5 (master and canonical
raw when present), then atomically activates the new jobs/state/review/report files, and finally
removes the now-stale frame-1 endpoint files. Frames 1-4 start pending and never inherit endpoint QA.
"""

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
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        stream.write(data); stream.flush(); os.fsync(stream.fileno())
        temporary = Path(stream.name)
    os.replace(temporary, path)


def rewrite_frame_path(value: str | None, old_index: int, new_index: int) -> str | None:
    if not value:
        return value
    path = Path(value)
    if path.name == f"{old_index}.png":
        return str(path.with_name(f"{new_index}.png"))
    return value


def rewrite_embedded(value: object, old_job_id: str, new_job_id: str) -> object:
    """Rewrite embedded self-identifiers and canonical PNG endpoint paths, never legacy JPGs."""
    if isinstance(value, dict):
        return {key: rewrite_embedded(item, old_job_id, new_job_id) for key, item in value.items()}
    if isinstance(value, list):
        return [rewrite_embedded(item, old_job_id, new_job_id) for item in value]
    if isinstance(value, str):
        rewritten = value.replace(old_job_id, new_job_id)
        if rewritten.endswith("/1.png"):
            rewritten = rewritten[:-5] + "/5.png"
        return rewritten
    return value


def parse_args() -> argparse.Namespace:
    repo = Path(__file__).resolve().parents[3]
    tool = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path,
                        default=repo / "ios/calorietracker/Resources/FreeExerciseDB/dist/exercises.json")
    parser.add_argument("--images", type=Path,
                        default=repo / "ios/calorietracker/Resources/FreeExerciseDB/images")
    parser.add_argument("--asset-root", type=Path,
                        default=repo / "shared/exercise-artwork/fud-flat-raster-v1")
    parser.add_argument("--jobs", type=Path, default=tool / "jobs-v1.jsonl")
    parser.add_argument("--metadata", type=Path, default=tool / "jobs-v1.meta.json")
    parser.add_argument("--state", type=Path, default=tool / "state-v1.json")
    parser.add_argument("--manual-reviews", type=Path, default=tool / "manual-reviews-v1.json")
    parser.add_argument("--report", type=Path, default=tool / "qa-report-v1.json")
    parser.add_argument("--expected-exercise-count", type=int, default=875)
    parser.add_argument("--apply", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    repo = Path(__file__).resolve().parents[3]
    builder = Path(__file__).with_name("BuildImagenExerciseJobs.py")
    old_jobs = {item["jobID"]: item for line in args.jobs.read_text().splitlines()
                if line.strip() for item in (json.loads(line),)}
    old_state_document = json.loads(args.state.read_text())
    old_state = old_state_document["jobs"]
    old_manual = json.loads(args.manual_reviews.read_text()) if args.manual_reviews.is_file() else {"jobs": {}}
    old_report = json.loads(args.report.read_text()) if args.report.is_file() else {"results": {}}

    with tempfile.TemporaryDirectory(prefix="fud-sequence-migration-") as directory:
        temporary = Path(directory)
        new_jobs_path = temporary / "jobs.jsonl"
        new_meta_path = temporary / "meta.json"
        new_state_path = temporary / "state.json"
        build = subprocess.run([
            sys.executable, str(builder), "--dataset", str(args.dataset), "--images", str(args.images),
            "--asset-root", str(args.asset_root), "--jobs", str(new_jobs_path),
            "--metadata", str(new_meta_path), "--state", str(new_state_path),
            "--sequence-frames", "6", "--expected-exercise-count", str(args.expected_exercise_count),
        ], capture_output=True, text=True)
        if build.returncode:
            raise SystemExit(build.stderr or build.stdout)
        new_jobs = [json.loads(line) for line in new_jobs_path.read_text().splitlines() if line.strip()]
        generated_state = json.loads(new_state_path.read_text())

        migrated_state = generated_state["jobs"]
        migrated_manual = {**old_manual, "schemaVersion": 2, "jobs": {}}
        migrated_report = {**old_report, "schemaVersion": 2, "results": {}}
        file_moves = []
        state_counts = {"preservedEndpoints": 0, "newPendingIntermediates": 0}
        for job in new_jobs:
            index = job["frameIndex"]
            old_index = 0 if index == 0 else 1 if index == 5 else None
            if old_index is None:
                endpoint_states = [
                    old_state[f"{job['exerciseID']}__f{endpoint}__{job['gender']}"]["status"]
                    for endpoint in (0, 1)
                ]
                blocked = next((status for status in endpoint_states
                                if status in {"blocked_source", "blocked_reference"}), None)
                if blocked:
                    migrated_state[job["jobID"]]["status"] = blocked
                state_counts["newPendingIntermediates"] += 1
                continue
            old_id = f"{job['exerciseID']}__f{old_index}__{job['gender']}"
            old_item = old_state.get(old_id)
            if old_item is None:
                raise SystemExit(f"Legacy endpoint missing from state: {old_id}")
            preserved = rewrite_embedded(dict(old_item), old_id, job["jobID"])
            preserved.update({"jobFingerprint": job["jobFingerprint"], "sequence": job["sequence"]})
            if index == 5:
                preserved["generatedInputPath"] = rewrite_frame_path(
                    preserved.get("generatedInputPath"), 1, 5)
            migrated_state[job["jobID"]] = preserved
            if old_id in old_manual.get("jobs", {}):
                migrated_manual["jobs"][job["jobID"]] = rewrite_embedded(
                    old_manual["jobs"][old_id], old_id, job["jobID"])
            if old_id in old_report.get("results", {}):
                migrated_report["results"][job["jobID"]] = rewrite_embedded(
                    old_report["results"][old_id], old_id, job["jobID"])
            state_counts["preservedEndpoints"] += 1
            if index == 5:
                for root_name in ("frames", "raw"):
                    source = args.asset_root / root_name / job["gender"] / job["exerciseID"] / "1.png"
                    destination = source.with_name("5.png")
                    if source.is_file():
                        if root_name == "frames" and old_item.get("outputSHA256") not in (None, sha256(source)):
                            raise SystemExit(f"Legacy endpoint state/master hash mismatch: {old_id}")
                        file_moves.append((source, destination, sha256(source)))

        generated_state["jobs"] = migrated_state
        generated_state["migration"] = {
            "tool": Path(__file__).name,
            "fromFrames": 2,
            "toFrames": 6,
            "endpointRemap": {"0": 0, "1": 5},
        }
        plan = {
            **state_counts,
            "manifestJobs": len(new_jobs),
            "fileMoves": [{"source": str(a), "destination": str(b), "sha256": digest}
                          for a, b, digest in file_moves],
            "apply": args.apply,
        }
        if not args.apply:
            print(json.dumps(plan, indent=2, sort_keys=True))
            return

        lock_path = args.state.with_suffix(args.state.suffix + ".lock")
        with lock_path.open("a+") as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            # Materialize finish endpoints before the new manifest becomes visible. State is the
            # activation record and is replaced last while queue writers are excluded by this lock.
            for source, destination, digest in file_moves:
                destination.parent.mkdir(parents=True, exist_ok=True)
                with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as stream:
                    staged = Path(stream.name)
                shutil.copyfile(source, staged)
                if sha256(staged) != digest:
                    raise SystemExit(f"Endpoint migration hash mismatch: {source}")
                os.replace(staged, destination)
            atomic_bytes(args.jobs, new_jobs_path.read_bytes())
            atomic_bytes(args.metadata, new_meta_path.read_bytes())
            atomic_bytes(args.manual_reviews, (json.dumps(migrated_manual, indent=2, sort_keys=True) + "\n").encode())
            atomic_bytes(args.report, (json.dumps(migrated_report, indent=2, sort_keys=True) + "\n").encode())
            atomic_bytes(args.state, (json.dumps(generated_state, indent=2, sort_keys=True) + "\n").encode())
            for source, destination, digest in file_moves:
                if destination.is_file() and sha256(destination) == digest:
                    source.unlink()
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        print(json.dumps(plan, sort_keys=True))


if __name__ == "__main__":
    main()
