#!/usr/bin/env python3
"""Uniformly align a complete six-frame RGBA sequence using detected pelvis and torso scale.

The default mode writes a separate aligned tree and never changes canonical masters. `--apply`
requires an empty backup directory, preserves every original byte-for-byte, stages and validates all
six transformed files, then atomically replaces the canonical masters.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import math
import os
import shutil
import tempfile
from pathlib import Path

from PIL import Image

from SequenceArtworkSchema import (
    alignment_drift, alignment_metadata, descriptor, normalized_pose_interpolation,
    source_references, validate_job_sequences,
)
from ValidateImagenExerciseArtwork import (
    compare_poses, extract_pose, image_integrity, normalize_pose,
)


CANVAS_SIZE = 1024
MIN_ALPHA_MARGIN = 8


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_target(alignments: list[dict]) -> dict:
    """Derive target only from immutable endpoint frames 0 and 5."""
    endpoints = (alignments[0], alignments[5])
    return {
        "pelvisAnchor": [sum(item["pelvisAnchor"][axis] for item in endpoints) / 2
                         for axis in (0, 1)],
        "torsoAnchor": [sum(item["torsoAnchor"][axis] for item in endpoints) / 2
                        for axis in (0, 1)],
        "subjectScale": math.sqrt(endpoints[0]["subjectScale"] * endpoints[1]["subjectScale"]),
        "derivation": "endpoint-pelvis-mean-geometric-torso-scale-v1",
    }


def transform_plan(alignment: dict, target: dict) -> dict:
    factor = target["subjectScale"] / max(alignment["subjectScale"], 1e-9)
    translation = [target["pelvisAnchor"][axis] - factor * alignment["pelvisAnchor"][axis]
                   for axis in (0, 1)]
    return {"uniformScale": factor, "translation": translation}


def transform_rgba(image: Image.Image, plan: dict) -> Image.Image:
    scale = plan["uniformScale"]
    translate_x, translate_y = (value * CANVAS_SIZE for value in plan["translation"])
    inverse = (1 / scale, 0, -translate_x / scale, 0, 1 / scale, -translate_y / scale)
    return image.convert("RGBA").transform(
        (CANVAS_SIZE, CANVAS_SIZE), Image.Transform.AFFINE, inverse,
        resample=Image.Resampling.BICUBIC, fillcolor=(0, 0, 0, 0),
    )


def alpha_geometry(image: Image.Image) -> dict:
    alpha = image.convert("RGBA").getchannel("A")
    bbox = alpha.point(lambda value: 255 if value >= 10 else 0).getbbox()
    if bbox is None:
        return {"passed": False, "reason": "empty_alpha"}
    left, top, right, bottom = bbox
    margins = [left, top, CANVAS_SIZE - right, CANVAS_SIZE - bottom]
    visible_pixels = sum(alpha.histogram()[10:])
    return {
        "alphaBoundingBox": list(bbox),
        "margins": margins,
        "minimumMargin": min(margins),
        "visibleAlphaPixels": visible_pixels,
        "passed": min(margins) >= MIN_ALPHA_MARGIN,
    }


def atomic_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as stream:
        temporary = Path(stream.name)
    shutil.copyfile(source, temporary)
    if sha256(source) != sha256(temporary):
        raise SystemExit(f"Copy hash mismatch: {source}")
    os.replace(temporary, destination)


def atomic_json(path: Path, value: object) -> None:
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n"); stream.flush(); os.fsync(stream.fileno())
        temporary = Path(stream.name)
    os.replace(temporary, path)


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path, default=Path(__file__).with_name("jobs-v1.jsonl"))
    parser.add_argument("--state", type=Path, default=Path(__file__).with_name("state-v1.json"))
    parser.add_argument("--exercise-id", required=True)
    parser.add_argument("--gender", choices=("male", "female"), required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output-root", type=Path,
                        help="Separate aligned output root; required unless --apply is used.")
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--backup-root", type=Path,
                        help="Required empty preservation root for explicit canonical replacement.")
    args = parser.parse_args()
    if args.apply and args.output_root:
        parser.error("--apply and --output-root are mutually exclusive")
    if args.apply and not args.backup_root:
        parser.error("--apply requires --backup-root")
    if not args.apply and not args.output_root:
        parser.error("dry-run alignment requires --output-root")
    if args.apply and args.backup_root.exists() and any(args.backup_root.iterdir()):
        raise SystemExit("Backup root must not exist or must be empty")

    all_jobs = [json.loads(line) for line in args.jobs.read_text().splitlines() if line.strip()]
    validate_job_sequences(all_jobs)
    jobs = sorted((job for job in all_jobs if job["exerciseID"] == args.exercise_id
                   and job["gender"] == args.gender), key=lambda job: job["frameIndex"])
    if len(jobs) != 6 or [job["frameIndex"] for job in jobs] != list(range(6)):
        raise SystemExit("Alignment requires exactly one complete schema-v2 six-frame sequence")
    if any(descriptor(job)["frameCount"] != 6 for job in jobs):
        raise SystemExit("Alignment is available only for schema-v2 sequences")
    inputs = [repo / job["outputPath"] for job in jobs]
    if any(not path.is_file() for path in inputs):
        raise SystemExit("All six normalized PNG inputs must exist")

    import mediapipe as mp
    import numpy as np
    options = mp.tasks.vision.PoseLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(args.model)),
        running_mode=mp.tasks.vision.RunningMode.IMAGE, num_poses=1,
        min_pose_detection_confidence=0.25, min_pose_presence_confidence=0.25,
    )
    landmarker = mp.tasks.vision.PoseLandmarker.create_from_options(options)
    try:
        poses_before = [extract_pose(landmarker, mp, np, path) for path in inputs]
        if any(pose is None for pose in poses_before):
            raise SystemExit("Pose detection must succeed for all six inputs")
        alignments_before = [alignment_metadata(pose) for pose in poses_before]
        target = canonical_target(alignments_before)

        staging = Path(tempfile.mkdtemp(prefix="fud-sequence-aligned-"))
        records = []
        staged_paths = []
        for job, source, alignment in zip(jobs, inputs, alignments_before):
            plan = transform_plan(alignment, target)
            with Image.open(source) as loaded:
                geometry_before = alpha_geometry(loaded)
                transformed = transform_rgba(loaded, plan)
            staged = staging / f"{job['frameIndex']}.png"
            transformed.save(staged, "PNG", optimize=False, compress_level=9)
            geometry = alpha_geometry(transformed)
            expected_alpha_area = geometry_before["visibleAlphaPixels"] * plan["uniformScale"] ** 2
            alpha_area_error = abs(geometry["visibleAlphaPixels"] - expected_alpha_area) / max(expected_alpha_area, 1)
            alpha_preserved = alpha_area_error <= 0.05
            integrity = image_integrity(staged)
            if not geometry["passed"] or not integrity["passed"] or not alpha_preserved:
                raise SystemExit(f"Aligned integrity/margin gate failed: {job['jobID']}")
            staged_paths.append(staged)
            records.append({
                "jobID": job["jobID"], "frameIndex": job["frameIndex"],
                "inputPath": str(source), "inputSHA256": sha256(source),
                "alignmentBefore": alignment, "transform": {
                    "uniformScale": round(plan["uniformScale"], 9),
                    "translation": [round(value, 9) for value in plan["translation"]],
                    "method": "uniform-scale-translate-whole-rgba-v1",
                },
                "alphaGeometryBefore": geometry_before, "alphaGeometry": geometry,
                "alphaAreaRelativeError": round(alpha_area_error, 8),
                "alphaAreaPreserved": alpha_preserved, "integrityAfter": integrity,
                "alignedSHA256": sha256(staged),
            })

        poses_after = [extract_pose(landmarker, mp, np, path) for path in staged_paths]
        if any(pose is None for pose in poses_after):
            raise SystemExit("Pose detection failed after transform")
        alignments_after = [alignment_metadata(pose) for pose in poses_after]
        references = source_references(jobs[0])
        reference_poses = [extract_pose(landmarker, mp, np, repo / ref["path"]) for ref in references]
        ordinary_pass = True
        for index, (job, pose) in enumerate(zip(jobs, poses_after)):
            if index in (0, 5):
                expected = reference_poses[0 if index == 0 else 1]
            else:
                expected = {
                    "joints": normalized_pose_interpolation(
                        normalize_pose(reference_poses[0]), normalize_pose(reference_poses[1]), index / 5),
                    "confidence": min(item["confidence"] for item in reference_poses),
                }
            comparison = compare_poses(expected, pose)
            drift = None if index == 0 else alignment_drift(alignments_after[index - 1], alignments_after[index])
            records[index].update({"alignmentAfter": alignments_after[index],
                                   "poseAfter": comparison, "driftAfter": drift})
            ordinary_pass = ordinary_pass and comparison["passed"] and (drift is None or drift["passed"])

        report = {
            "schemaVersion": 1, "exerciseID": args.exercise_id, "gender": args.gender,
            "target": target, "minimumAlphaMargin": MIN_ALPHA_MARGIN,
            "ordinaryPoseIntegrityDriftPassed": ordinary_pass,
            "apply": args.apply, "frames": records,
        }
        if not args.apply:
            for job, staged in zip(jobs, staged_paths):
                destination = args.output_root / args.gender / args.exercise_id / f"{job['frameIndex']}.png"
                atomic_copy(staged, destination)
                records[job["frameIndex"]]["outputPath"] = str(destination)
        if not ordinary_pass:
            # Still emit isolated evidence for anatomy-targeted retries, but never apply a failed set.
            args.metadata.parent.mkdir(parents=True, exist_ok=True)
            args.metadata.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
            raise SystemExit("Aligned outputs failed ordinary pose/drift gates; metadata retained")

        if args.apply:
            lock_path = args.state.with_suffix(args.state.suffix + ".lock")
            with lock_path.open("a+") as lock:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
                state_document = json.loads(args.state.read_text())
                for job, source in zip(jobs, inputs):
                    recorded = state_document["jobs"][job["jobID"]].get("outputSHA256")
                    if recorded != sha256(source):
                        raise SystemExit(f"State/master hash mismatch before alignment: {job['jobID']}")
                args.backup_root.mkdir(parents=True, exist_ok=True)
                for job, source in zip(jobs, inputs):
                    backup = args.backup_root / args.gender / args.exercise_id / f"{job['frameIndex']}.png"
                    atomic_copy(source, backup)
                for source, staged in zip(inputs, staged_paths):
                    atomic_copy(staged, source)
                for job, record in zip(jobs, records):
                    item = state_document["jobs"][job["jobID"]]
                    item.update({
                        "preAlignmentOutputSHA256": record["inputSHA256"],
                        "outputSHA256": record["alignedSHA256"],
                        "alignmentTransform": {
                            "target": target, "transform": record["transform"],
                            "metadataPath": str(args.metadata),
                        },
                        "status": "completed_pending_qa", "qaStatus": "pending",
                        "sequenceQA": None, "error": None,
                    })
                atomic_json(args.state, state_document)
                fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        args.metadata.parent.mkdir(parents=True, exist_ok=True)
        args.metadata.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({"passed": True, "metadata": str(args.metadata), "apply": args.apply}, sort_keys=True))
    finally:
        landmarker.close()


if __name__ == "__main__":
    main()
