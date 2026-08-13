#!/usr/bin/env python3
"""Stage accepted 768px alpha-WebP pairs as collision-safe iOS resources."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from SequenceArtworkSchema import (
    DEFAULT_FRAME_DURATION_MS, PLAYBACK_MODE, RUNTIME_SEQUENCE_VERSION,
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
    accepted_pairs = []
    for entry in package.get("entries", []):
        if args.gender != "all" and entry["gender"] != args.gender:
            continue
        frames = sorted(entry["frames"], key=lambda frame: frame["frameIndex"])
        indices = [frame["frameIndex"] for frame in frames]
        if indices not in ([0, 1], list(range(6))):
            raise SystemExit(f"Unexpected package frame set: {entry['gender']}/{entry['exerciseID']}")
        if indices == list(range(6)) and any((
            entry.get("frameCount") != 6,
            entry.get("frameDurationMs") != DEFAULT_FRAME_DURATION_MS,
            entry.get("playback") != PLAYBACK_MODE,
            entry.get("sequenceVersion") != RUNTIME_SEQUENCE_VERSION,
        )):
            raise SystemExit(f"Invalid sequence playback metadata: {entry['exerciseID']}")
        if not all(is_accepted(state.get(frame["jobID"], {})) for frame in frames):
            raise SystemExit(f"Package index contains a non-accepted job: {entry['exerciseID']}")
        accepted_pairs.append((entry, frames))

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
        for key in ("frameCount", "frameDurationMs", "playback", "sequenceVersion"):
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
