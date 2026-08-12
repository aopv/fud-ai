#!/usr/bin/env python3
"""Build the deterministic 3,500-job Imagen exercise-artwork queue."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import tempfile
from pathlib import Path


STYLE = "fud-flat-raster-v1"
GENDERS = ("male", "female")
PILOT_IDS = {
    "3_4_Sit-Up",
    "Barbell_Bench_Press_-_Medium_Grip",
    "Cable_Crossover",
    "Triceps_Pushdown",
    "Leg_Press",
    "Tire_Flip",
    "Clean_and_Jerk",
    "Dumbbell_Bicep_Curl",
}
KNOWN_BAD_SOURCE_REFERENCES = {
    "Bicycling": "Both legacy frames depict unrelated helmet/cable details, not a bicycling pose.",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def atomic_write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
        temporary.write(content)
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, path)
    os.chmod(path, 0o644)


def resolve_repo_path(repo: Path, value: str | None) -> Path:
    candidate = Path(value or "")
    return candidate if candidate.is_absolute() else repo / candidate


def parse_args() -> argparse.Namespace:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dataset",
        type=Path,
        default=repo / "ios/calorietracker/Resources/FreeExerciseDB/dist/exercises.json",
    )
    parser.add_argument(
        "--images",
        type=Path,
        default=repo / "ios/calorietracker/Resources/FreeExerciseDB/images",
    )
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=repo / f"shared/exercise-artwork/{STYLE}",
    )
    parser.add_argument(
        "--jobs",
        type=Path,
        default=repo / "tools/exercise-artwork/imagen/jobs-v1.jsonl",
    )
    parser.add_argument(
        "--metadata",
        type=Path,
        default=repo / "tools/exercise-artwork/imagen/jobs-v1.meta.json",
    )
    parser.add_argument(
        "--state",
        type=Path,
        default=repo / "tools/exercise-artwork/imagen/state-v1.json",
    )
    return parser.parse_args()


def prompt_for(record: dict, frame_index: int, gender: str) -> str:
    equipment = record.get("equipment") or "body only"
    identity_lock = (
        "Keep the approved female character's ponytail, coral crop top, navy leggings, and "
        "coral trainers exactly consistent; do not change her hairstyle, outfit, colors, or face. "
        if gender == "female"
        else
        "Keep the same approved young athletic male, face, and body proportions: short swept "
        "dark-brown hair, black/charcoal sleeveless training top, matching black/charcoal "
        "above-knee shorts, and black low-top trainers with white midsoles and a tiny coral/red "
        "heel accent. Never add sleeves, leggings, a hat, jewelry, logos, or alternate colors. "
        "Do not redesign, recolor, or restyle him. "
    )
    return (
        "Create exactly ONE 1024x1024 full-body flat-vector raster exercise illustration. "
        f"Exercise: {record['name']}. Equipment: {equipment}. Gender: {gender}. "
        "REFERENCE ORDER IS STRICT: the FIRST image is CHARACTER REFERENCE; the SECOND image is "
        "POSE/EQUIPMENT REFERENCE. Use CHARACTER REFERENCE only for the exact recurring character identity, face, hair, "
        "body proportions, clothing, palette, line weight, and polished Fud AI flat-vector style. "
        + identity_lock +
        "Use POSE/EQUIPMENT REFERENCE only for the exact body pose, camera viewpoint, limb angles, "
        "hand grip, contact points, and the exact visible bench, cable, barbell, dumbbell, machine, "
        "ball, or other equipment. Preserve left/right orientation. Show one character only, with "
        "the whole body and required equipment fully inside the canvas. Use clean filled anatomy, "
        "not a skeleton or stick figure. Put the subject on a perfectly flat, solid #00FF00 chroma-key "
        "background. The background must have no shadow, floor, horizon, gradient, texture, reflection, "
        "glow, or color variation. Do not use #00FF00 or any bright green on the character or equipment. "
        "No text, captions, numbers, arrows, borders, panels, "
        f"logos, signatures, or watermark. This is endpoint frame {frame_index + 1} of 2; do not "
        "combine frames or show before/after poses."
    )


def main() -> None:
    args = parse_args()
    repo = Path(__file__).resolve().parents[3]
    records = json.loads(args.dataset.read_text())
    ids = [record["id"] for record in records]
    if len(records) != 875 or len(set(ids)) != 875:
        raise SystemExit("Expected exactly 875 unique FreeExerciseDB records")
    invalid_ids = sorted(identifier for identifier in ids if not re.fullmatch(r"[A-Za-z0-9_-]+", identifier))
    if invalid_ids:
        raise SystemExit(f"Unsafe source IDs: {invalid_ids}")
    if any(len(record.get("images", [])) != 2 for record in records):
        raise SystemExit("Every source exercise must contain exactly two frames")

    character_references = {
        gender: args.asset_root / "references" / f"{gender}.png" for gender in GENDERS
    }
    reference_hashes = {
        gender: sha256(path) if path.is_file() else None
        for gender, path in character_references.items()
    }

    jobs: list[dict] = []
    for record in sorted(records, key=lambda item: item["id"]):
        source_qa = (
            {
                "status": "blocked",
                "reason": KNOWN_BAD_SOURCE_REFERENCES[record["id"]],
            }
            if record["id"] in KNOWN_BAD_SOURCE_REFERENCES
            else {"status": "ready", "reason": None}
        )
        for frame_index, filename in enumerate(record["images"]):
            source_path = args.images / filename
            if not source_path.is_file():
                raise SystemExit(f"Missing source frame: {source_path}")
            for gender in GENDERS:
                job_id = f"{record['id']}__f{frame_index}__{gender}"
                output_path = args.asset_root / "frames" / gender / record["id"] / f"{frame_index}.png"
                job = {
                    "schemaVersion": 1,
                    "style": STYLE,
                    "jobID": job_id,
                    "exerciseID": record["id"],
                    "exerciseName": record["name"],
                    "equipment": record.get("equipment") or "none",
                    "frameIndex": frame_index,
                    "gender": gender,
                    "width": 1024,
                    "height": 1024,
                    "sourceImagePath": str(source_path.relative_to(repo)),
                    "sourceImageSHA256": sha256(source_path),
                    "characterReferencePath": str(character_references[gender].relative_to(repo)),
                    "characterReferenceSHA256": reference_hashes[gender],
                    "outputPath": str(output_path.relative_to(repo)),
                    "prompt": prompt_for(record, frame_index, gender),
                    "pilot": record["id"] in PILOT_IDS,
                    "sourceReferenceQA": source_qa,
                }
                fingerprint_fields = {
                    key: job[key]
                    for key in (
                        "style", "exerciseID", "frameIndex", "gender", "sourceImageSHA256",
                        "characterReferenceSHA256", "outputPath", "prompt", "width", "height",
                    )
                }
                job["jobFingerprint"] = hashlib.sha256(
                    canonical_json(fingerprint_fields).encode("utf-8")
                ).hexdigest()
                jobs.append(job)

    if len(jobs) != 3500 or len({job["jobID"] for job in jobs}) != 3500:
        raise SystemExit("Job expansion must produce exactly 3,500 unique jobs")
    jobs.sort(key=lambda job: job["jobID"])
    jobs_bytes = ("\n".join(canonical_json(job) for job in jobs) + "\n").encode("utf-8")
    manifest_hash = hashlib.sha256(jobs_bytes).hexdigest()

    metadata = {
        "schemaVersion": 1,
        "style": STYLE,
        "jobCount": len(jobs),
        "exerciseCount": len(records),
        "framesPerExercise": 2,
        "genders": list(GENDERS),
        "jobsSHA256": manifest_hash,
        "characterReferences": {
            gender: {
                "path": str(path.relative_to(repo)),
                "sha256": reference_hashes[gender],
                "ready": reference_hashes[gender] is not None,
            }
            for gender, path in character_references.items()
        },
        "pilotExerciseIDs": sorted(PILOT_IDS),
        "blockedSourceExerciseIDs": sorted(KNOWN_BAD_SOURCE_REFERENCES),
    }
    lock_path = args.state.with_suffix(args.state.suffix + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        old_job_map = {}
        if args.jobs.is_file():
            old_job_map = {
                item["jobID"]: item
                for line in args.jobs.read_text().splitlines() if line.strip()
                for item in (json.loads(line),)
            }
        atomic_write(args.jobs, jobs_bytes)
        atomic_write(args.metadata, (json.dumps(metadata, indent=2, sort_keys=True) + "\n").encode())
        previous = json.loads(args.state.read_text()) if args.state.is_file() else {"jobs": {}}
        previous_jobs = previous.get("jobs", {})
        state_jobs = {}
        for job in jobs:
            old = previous_jobs.get(job["jobID"], {})
            if old.get("jobFingerprint") == job["jobFingerprint"]:
                state_jobs[job["jobID"]] = old
                continue
            old_job = old_job_map.get(job["jobID"], {})
            stable_keys = (
                "style", "exerciseID", "frameIndex", "gender", "sourceImageSHA256",
                "characterReferenceSHA256", "outputPath", "width", "height",
            )
            raw_path = resolve_repo_path(repo, old.get("generatedInputPath"))
            output_path = repo / job["outputPath"]
            generated_can_revalidate = (
                old.get("status") in {"completed_pending_qa", "complete", "qa_failed"}
                and all(old_job.get(key) == job.get(key) for key in stable_keys)
                and raw_path.is_file()
                and output_path.is_file()
                and old.get("outputSHA256") == sha256(output_path)
            )
            if generated_can_revalidate:
                preserved = dict(old)
                preserved.update({
                    "jobFingerprint": job["jobFingerprint"],
                    "status": "completed_pending_qa",
                    "qaStatus": "pending",
                    "migrationNote": "Prompt-only contract change; raw/output retained for renormalization and QA.",
                })
                state_jobs[job["jobID"]] = preserved
                continue
            if job["sourceReferenceQA"]["status"] == "blocked":
                status = "blocked_source"
            elif job["characterReferenceSHA256"] is None:
                status = "blocked_reference"
            else:
                status = "pending"
            state_jobs[job["jobID"]] = {
                "jobFingerprint": job["jobFingerprint"],
                "status": status,
                "attempts": 0,
                "claimedBy": None,
                "generatedInputPath": None,
                "outputSHA256": None,
                "qaStatus": None,
                "error": None,
            }
        state = {"schemaVersion": 1, "jobsSHA256": manifest_hash, "jobs": state_jobs}
        atomic_write(args.state, (json.dumps(state, indent=2, sort_keys=True) + "\n").encode())
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
    statuses = {}
    for item in state_jobs.values():
        statuses[item["status"]] = statuses.get(item["status"], 0) + 1
    print(f"Wrote {len(jobs)} jobs to {args.jobs}")
    print(f"Jobs SHA-256: {manifest_hash}")
    print("State: " + ", ".join(f"{key}={statuses[key]}" for key in sorted(statuses)))


if __name__ == "__main__":
    main()
