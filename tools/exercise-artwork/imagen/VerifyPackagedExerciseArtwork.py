#!/usr/bin/env python3
"""Read-only build gate for committed, QA-accepted exercise artwork WebPs."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from SequenceArtworkSchema import (
    DEFAULT_FRAME_DURATION_MS, ENDPOINTS_ONLY_FRAME_DURATION_MS,
    PLAYBACK_MODE,
    RUNTIME_SEQUENCE_VERSION,
    runtime_selection,
    validate_job_sequences,
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def accepted(item: dict) -> bool:
    return item.get("status") == "complete" and item.get("qaStatus") == "accepted"


def webp_metadata(path: Path) -> tuple[int, int, bool]:
    data = path.read_bytes()
    if len(data) < 30 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise SystemExit(f"Not a WebP RIFF file: {path}")
    offset = 12
    width = height = None
    has_alpha = False
    while offset + 8 <= len(data):
        tag = data[offset:offset + 4]
        length = int.from_bytes(data[offset + 4:offset + 8], "little")
        payload = data[offset + 8:offset + 8 + length]
        if len(payload) != length:
            raise SystemExit(f"Truncated WebP chunk: {path}")
        if tag == b"VP8X":
            if length != 10:
                raise SystemExit(f"Invalid VP8X chunk: {path}")
            has_alpha = bool(payload[0] & 0x10)
            width = 1 + int.from_bytes(payload[4:7], "little")
            height = 1 + int.from_bytes(payload[7:10], "little")
        elif tag == b"ALPH":
            has_alpha = True
        offset += 8 + length + (length & 1)
    if width is None or height is None:
        raise SystemExit(f"Packaged WebP has no VP8X dimensions: {path}")
    return width, height, has_alpha


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    package_root = repo / "shared/exercise-artwork/fud-flat-raster-v1/packaged-768"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path, default=Path(__file__).with_name("jobs-v1.jsonl"))
    parser.add_argument("--state", type=Path, default=Path(__file__).with_name("state-v1.json"))
    parser.add_argument("--package-root", type=Path, default=package_root)
    parser.add_argument("--index", type=Path, default=package_root / "index.json")
    args = parser.parse_args()

    job_list = [
        job
        for line in args.jobs.read_text().splitlines()
        if line.strip()
        for job in [json.loads(line)]
    ]
    try:
        manifest = validate_job_sequences(job_list)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    jobs = {job["jobID"]: job for job in job_list}
    state = json.loads(args.state.read_text()).get("jobs", {})
    index = json.loads(args.index.read_text())
    if index.get("schemaVersion") not in (1, 2) or (index.get("size"), index.get("format")) != (768, "webp"):
        raise SystemExit("Unsupported packaged artwork index")
    if index["schemaVersion"] != manifest["schemaVersion"]:
        raise SystemExit("Package/manifest schema version mismatch")

    indexed_pairs: set[tuple[str, str]] = set()
    indexed_files: set[Path] = set()
    for entry in index.get("entries", []):
        gender, exercise_id = entry["gender"], entry["exerciseID"]
        pair = (gender, exercise_id)
        if pair in indexed_pairs:
            raise SystemExit(f"Duplicate packaged pair: {gender}/{exercise_id}")
        indexed_pairs.add(pair)
        frames = sorted(entry.get("frames", []), key=lambda frame: frame["frameIndex"])
        sequence_jobs = sorted(
            (job for job in job_list if (job["gender"], job["exerciseID"]) == pair),
            key=lambda job: job["frameIndex"],
        )
        selection = runtime_selection(sequence_jobs, state)
        if selection is None:
            raise SystemExit(f"Indexed sequence is not shippable: {gender}/{exercise_id}")
        expected_indices = list(range(len(selection["jobs"])))
        if [frame.get("frameIndex") for frame in frames] != expected_indices:
            raise SystemExit(f"Invalid packaged frame sequence: {gender}/{exercise_id}")
        if len(sequence_jobs) == 6:
            expected_mode = selection["mode"]
            expected_contract = {
                "frameCount": len(expected_indices),
                "frameDurationMs": (DEFAULT_FRAME_DURATION_MS if expected_mode == "completeSequence"
                                    else ENDPOINTS_ONLY_FRAME_DURATION_MS),
                "playback": PLAYBACK_MODE,
                "sequenceVersion": RUNTIME_SEQUENCE_VERSION,
                "sequenceMode": expected_mode,
            }
            if any(entry.get(key) != value for key, value in expected_contract.items()):
                raise SystemExit(f"Invalid runtime sequence metadata: {gender}/{exercise_id}")
        for frame, (_, selected_job) in zip(frames, selection["jobs"]):
            job_id = frame["jobID"]
            job = jobs.get(job_id)
            if not job or (job["gender"], job["exerciseID"]) != pair:
                raise SystemExit(f"Packaged job mismatch: {job_id}")
            if job_id != selected_job["jobID"]:
                raise SystemExit(f"Packaged runtime/source frame mapping mismatch: {job_id}")
            if len(sequence_jobs) == 6 and frame.get("sourceFrameIndex") != job["frameIndex"]:
                raise SystemExit(f"Packaged sourceFrameIndex mismatch: {job_id}")
            if not accepted(state.get(job_id, {})):
                raise SystemExit(f"Packaged frame is no longer accepted: {job_id}")
            master = (repo / job["outputPath"]).resolve()
            if not master.is_file() or sha256(master) != state[job_id].get("outputSHA256"):
                raise SystemExit(f"Accepted master missing or hash-drifted: {job_id}")
            source = (repo / frame["path"]).resolve()
            if args.package_root.resolve() not in source.parents:
                raise SystemExit(f"Packaged path escapes root: {source}")
            expected = (
                args.package_root.resolve() / "frames" / gender / exercise_id
                / f"{frame['frameIndex']}.webp"
            )
            if source != expected:
                raise SystemExit(f"Noncanonical packaged frame path: {job_id}")
            if not source.is_file() or sha256(source) != frame["sha256"]:
                raise SystemExit(f"Packaged frame missing or hash-drifted: {job_id}")
            if webp_metadata(source) != (768, 768, True):
                raise SystemExit(f"Packaged frame has wrong size or no alpha: {job_id}")
            if selection["mode"] == "completeSequence":
                state_qa = state[job_id].get("sequenceQA")
                if (not state_qa or state_qa.get("passed") is not True
                        or state_qa.get("sequenceComplete") is not True
                        or state_qa.get("alignment") is None
                        or (frame["frameIndex"] > 0
                            and state_qa.get("driftFromPrevious", {}).get("passed") is not True)):
                    raise SystemExit(f"Accepted v2 frame lacks passing sequence QA: {job_id}")
                if frame.get("sequenceQA") != state_qa:
                    raise SystemExit(f"Packaged sequence QA metadata drift: {job_id}")
            indexed_files.add(source)

    groups = {}
    for job in job_list:
        groups.setdefault((job["gender"], job["exerciseID"]), []).append(job)
    complete_accepted_pairs = {
        pair for pair, sequence_jobs in groups.items() if runtime_selection(sequence_jobs, state)
    }
    if indexed_pairs != complete_accepted_pairs:
        raise SystemExit(
            "Packaged index pair parity failure; "
            f"missing={sorted(complete_accepted_pairs - indexed_pairs)}, "
            f"stale={sorted(indexed_pairs - complete_accepted_pairs)}"
        )
    disk_files = {path.resolve() for path in (args.package_root / "frames").rglob("*.webp")}
    if disk_files != indexed_files:
        raise SystemExit(
            f"Unindexed or missing packaged WebP; extra={sorted(disk_files - indexed_files)}, "
            f"missing={sorted(indexed_files - disk_files)}"
        )
    if index.get("pairCount") != len(indexed_pairs):
        raise SystemExit("Packaged index pairCount mismatch")
    if index.get("schemaVersion") == 2 and index.get("sequenceCount") != len(indexed_pairs):
        raise SystemExit("Packaged index sequenceCount mismatch")
    print(f"Verified {len(indexed_pairs)} committed, complete, QA-accepted artwork pairs")


if __name__ == "__main__":
    main()
