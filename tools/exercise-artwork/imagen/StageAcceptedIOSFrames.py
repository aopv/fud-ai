#!/usr/bin/env python3
"""Stage accepted 768px alpha-WebP pairs as collision-safe iOS resources."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from SequenceArtworkSchema import (
    PLAYBACK_MODE, RUNTIME_SEQUENCE_VERSION, runtime_selection, validate_job_sequences,
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--jobs",
        type=Path,
        default=repo / "tools/exercise-artwork/imagen/jobs-v1.jsonl",
    )
    parser.add_argument(
        "--package-index",
        type=Path,
        default=repo / "shared/exercise-artwork/fud-flat-raster-v1/packaged-768/index.json",
    )
    parser.add_argument(
        "--state",
        type=Path,
        default=repo / "tools/exercise-artwork/imagen/state-v1.json",
    )
    parser.add_argument(
        "--destination",
        type=Path,
        default=repo / "ios/calorietracker/Resources/FudExerciseArtwork/frames",
    )
    parser.add_argument(
        "--index",
        type=Path,
        default=repo / "ios/calorietracker/Resources/FudExerciseArtwork/frames-index.json",
    )
    parser.add_argument("--gender", choices=("male", "female", "all"), default="all")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def is_accepted(item: dict) -> bool:
    return item.get("status") == "complete" and item.get("qaStatus") == "accepted"


def main() -> None:
    args = parse_args()
    repo = Path(__file__).resolve().parents[3]
    package = json.loads(args.package_index.read_text())
    if package.get("schemaVersion") not in (1, 2) or package.get("size") != 768 or package.get("format") != "webp":
        raise SystemExit("Expected the canonical 768px WebP package index")
    state = json.loads(args.state.read_text()).get("jobs", {})
    job_list = [json.loads(line) for line in args.jobs.read_text().splitlines() if line.strip()]
    try:
        validate_job_sequences(job_list)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    groups = {}
    for job in job_list:
        groups.setdefault((job["gender"], job["exerciseID"]), []).append(job)
    accepted_pairs = []
    indexed_pairs = set()
    for entry in package.get("entries", []):
        if args.gender != "all" and entry["gender"] != args.gender:
            continue
        frames = sorted(entry["frames"], key=lambda frame: frame["frameIndex"])
        pair = (entry["gender"], entry["exerciseID"])
        selection = runtime_selection(groups.get(pair, []), state) if pair in groups else None
        if selection is None:
            raise SystemExit(f"Package entry is not currently shippable: {pair}")
        indices = [frame["frameIndex"] for frame in frames]
        if indices != list(range(len(selection["jobs"]))):
            raise SystemExit(f"Unexpected package frame set: {entry['gender']}/{entry['exerciseID']}")
        if len(groups[pair]) == 6 and any((
            entry.get("sequenceMode") != selection["mode"],
            entry.get("frameCount") != len(selection["jobs"]),
            entry.get("frameDurationMs") != selection["frameDurationMs"],
            entry.get("playback") != PLAYBACK_MODE,
            entry.get("sequenceVersion") != RUNTIME_SEQUENCE_VERSION,
        )):
            raise SystemExit(f"Invalid sequence playback metadata: {entry['exerciseID']}")
        for frame, (_, job) in zip(frames, selection["jobs"]):
            if frame["jobID"] != job["jobID"]:
                raise SystemExit(f"Runtime/source frame mapping mismatch: {frame['jobID']}")
            if len(groups[pair]) == 6 and frame.get("sourceFrameIndex") != job["frameIndex"]:
                raise SystemExit(f"sourceFrameIndex mismatch: {frame['jobID']}")
        if not all(is_accepted(state.get(frame["jobID"], {})) for frame in frames):
            raise SystemExit(f"Package index contains a non-accepted job: {entry['exerciseID']}")
        accepted_pairs.append((entry, frames))
        indexed_pairs.add(pair)

    expected_pairs = {
        pair for pair, jobs in groups.items()
        if (args.gender == "all" or pair[0] == args.gender) and runtime_selection(jobs, state)
    }
    if indexed_pairs != expected_pairs:
        raise SystemExit(f"Package/state parity failure; missing={sorted(expected_pairs-indexed_pairs)}, "
                         f"stale={sorted(indexed_pairs-expected_pairs)}")

    if args.dry_run:
        print(f"Would stage {len(accepted_pairs)} accepted exercise pairs")
        return

    args.destination.mkdir(parents=True, exist_ok=True)
    index_entries = []
    # Replace only files managed by this staging script so a revoked QA
    # acceptance cannot leave stale generated artwork in the application.
    stale_pattern = (
        "FudExercise_*.webp"
        if args.gender == "all"
        else f"FudExercise_{args.gender}_*.webp"
    )
    for existing in args.destination.glob(stale_pattern):
        existing.unlink()

    for entry, pair in accepted_pairs:
        gender = entry["gender"]
        exercise_id = entry["exerciseID"]
        staged_frames = []
        for frame in pair:
            source = repo / frame["path"]
            if not source.is_file():
                raise SystemExit(f"Packaged output is missing: {source}")
            if sha256(source) != frame["sha256"]:
                raise SystemExit(f"Packaged output hash drift: {source}")
            filename = f"FudExercise_{gender}_{exercise_id}_{frame['frameIndex']}.webp"
            destination = args.destination / filename
            shutil.copy2(source, destination)
            staged_frames.append({
                "frameIndex": frame["frameIndex"],
                "filename": filename,
                "sha256": sha256(destination),
                "bytes": destination.stat().st_size,
                "jobID": frame["jobID"],
            })
        index_entry = {
            "exerciseID": exercise_id,
            "gender": gender,
            "frames": staged_frames,
        }
        for key in ("frameCount", "frameDurationMs", "playback", "sequenceVersion", "sequenceMode"):
            if key in entry:
                index_entry[key] = entry[key]
        index_entries.append(index_entry)

    index = {
        "schemaVersion": package["schemaVersion"],
        "format": "webp",
        "size": 768,
        "pairCount": len(index_entries),
        "entries": index_entries,
    }
    if package["schemaVersion"] == 2:
        index["sequenceCount"] = len(index_entries)
    args.index.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n")
    print(f"Staged {len(index_entries)} accepted exercise pairs into {args.destination}")


if __name__ == "__main__":
    main()
