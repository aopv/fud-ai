#!/usr/bin/env python3
"""Stage only indexed, QA-accepted 768px WebP pairs as Android assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

from SequenceArtworkSchema import (
    PLAYBACK_MODE, RUNTIME_SEQUENCE_VERSION, runtime_selection, validate_job_sequences,
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def accepted(item: dict) -> bool:
    return item.get("status") == "complete" and item.get("qaStatus") == "accepted"


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    package_root = repo / "shared/exercise-artwork/fud-flat-raster-v1/packaged-768"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path, default=Path(__file__).with_name("jobs-v1.jsonl"))
    parser.add_argument("--state", type=Path, default=Path(__file__).with_name("state-v1.json"))
    parser.add_argument("--package-root", type=Path, default=package_root)
    parser.add_argument("--index", type=Path, default=package_root / "index.json")
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()

    job_list = [
        job
        for line in args.jobs.read_text().splitlines()
        if line.strip()
        for job in [json.loads(line)]
    ]
    try:
        validate_job_sequences(job_list)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    jobs = {job["jobID"]: job for job in job_list}
    state = json.loads(args.state.read_text()).get("jobs", {})
    index = json.loads(args.index.read_text())
    if index.get("schemaVersion") not in (1, 2) or (index.get("size"), index.get("format")) != (768, "webp"):
        raise SystemExit("Unsupported packaged artwork index")

    if args.destination.exists():
        shutil.rmtree(args.destination)
    args.destination.mkdir(parents=True)

    staged = 0
    indexed_pairs: set[tuple[str, str]] = set()
    for entry in index.get("entries", []):
        gender, exercise_id = entry["gender"], entry["exerciseID"]
        pair_key = (gender, exercise_id)
        if pair_key in indexed_pairs:
            raise SystemExit(f"Duplicate packaged pair: {gender}/{exercise_id}")
        indexed_pairs.add(pair_key)
        frames = sorted(entry.get("frames", []), key=lambda frame: frame["frameIndex"])
        sequence_jobs = [job for job in job_list if
                         (job["gender"], job["exerciseID"]) == pair_key]
        selection = runtime_selection(sequence_jobs, state) if sequence_jobs else None
        if selection is None or [frame.get("frameIndex") for frame in frames] != list(range(len(selection["jobs"]))):
            raise SystemExit(f"Invalid packaged frame sequence: {gender}/{exercise_id}")
        if len(sequence_jobs) == 6 and any((
            entry.get("sequenceMode") != selection["mode"],
            entry.get("frameCount") != len(selection["jobs"]),
            entry.get("frameDurationMs") != selection["frameDurationMs"],
            entry.get("playback") != PLAYBACK_MODE,
            entry.get("sequenceVersion") != RUNTIME_SEQUENCE_VERSION,
        )):
            raise SystemExit(f"Invalid packaged sequence metadata: {gender}/{exercise_id}")
        for frame, (_, selected_job) in zip(frames, selection["jobs"]):
            job_id = frame["jobID"]
            job = jobs.get(job_id)
            if not job or job["gender"] != gender or job["exerciseID"] != exercise_id:
                raise SystemExit(f"Packaged job mismatch: {job_id}")
            if job_id != selected_job["jobID"]:
                raise SystemExit(f"Packaged runtime/source mapping mismatch: {job_id}")
            if len(sequence_jobs) == 6 and frame.get("sourceFrameIndex") != job["frameIndex"]:
                raise SystemExit(f"Packaged sourceFrameIndex mismatch: {job_id}")
            if not accepted(state.get(job_id, {})):
                raise SystemExit(f"Packaged frame is no longer accepted: {job_id}")
            source = (repo / frame["path"]).resolve()
            if args.package_root.resolve() not in source.parents:
                raise SystemExit(f"Packaged path escapes root: {source}")
            if not source.is_file() or sha256(source) != frame["sha256"]:
                raise SystemExit(f"Packaged frame missing or hash-drifted: {job_id}")
            with Image.open(source) as image:
                if image.size != (768, 768) or image.format != "WEBP":
                    raise SystemExit(f"Packaged frame has wrong format or size: {job_id}")
                alpha = image.convert("RGBA").getchannel("A").getextrema()
                if alpha[0] != 0:
                    raise SystemExit(f"Packaged frame lost transparency: {job_id}")
            destination = (
                args.destination / "frames" / gender / exercise_id
                / f"{frame['frameIndex']}.webp"
            )
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        staged += 1

    groups = {}
    for job in job_list:
        groups.setdefault((job["gender"], job["exerciseID"]), []).append(job)
    complete_accepted_pairs = {
        pair for pair, sequence_jobs in groups.items() if runtime_selection(sequence_jobs, state)
    }
    if indexed_pairs != complete_accepted_pairs:
        missing = sorted(complete_accepted_pairs - indexed_pairs)
        stale = sorted(indexed_pairs - complete_accepted_pairs)
        raise SystemExit(f"Packaged index parity failure; missing={missing}, stale={stale}")
    print(f"Staged {staged} indexed, QA-accepted Android exercise pairs")


if __name__ == "__main__":
    main()
