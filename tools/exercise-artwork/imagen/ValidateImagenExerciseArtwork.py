#!/usr/bin/env python3
"""Validate generated exercise frames against their exact legacy pose references."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import math
import os
import tempfile
from collections import Counter
from pathlib import Path

from PIL import Image, ImageFilter, ImageStat

from SequenceArtworkSchema import (
    ALIGNMENT_THRESHOLDS,
    alignment_drift,
    alignment_metadata,
    descriptor,
    normalized_pose_interpolation,
    source_references,
    validate_job_sequences,
)


BASE_JOINTS = {
    "nose": 0,
    "leftShoulder": 11, "rightShoulder": 12,
    "leftElbow": 13, "rightElbow": 14,
    "leftWrist": 15, "rightWrist": 16,
    "leftHip": 23, "rightHip": 24,
    "leftKnee": 25, "rightKnee": 26,
    "leftAnkle": 27, "rightAnkle": 28,
}
SWAP = {
    name: (name.replace("left", "right", 1) if name.startswith("left")
           else name.replace("right", "left", 1) if name.startswith("right") else name)
    for name in BASE_JOINTS
}
SEGMENTS = (
    ("leftShoulder", "leftElbow"), ("leftElbow", "leftWrist"),
    ("rightShoulder", "rightElbow"), ("rightElbow", "rightWrist"),
    ("leftHip", "leftKnee"), ("leftKnee", "leftAnkle"),
    ("rightHip", "rightKnee"), ("rightKnee", "rightAnkle"),
)
MANUAL_FIELDS = ("characterApproved", "poseEquipmentApproved", "anatomyApproved", "artifactFree")


def load_jobs(path: Path, repo: Path) -> tuple[list[dict], dict]:
    jobs = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    try:
        sequence_manifest = validate_job_sequences(jobs)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    outputs = [job["outputPath"] for job in jobs]
    if len(set(outputs)) != len(jobs):
        raise SystemExit("Output paths must be unique")
    hash_cache = {}
    for job in jobs:
        if job.get("schemaVersion") not in (1, 2) or job.get("style") != "fud-flat-raster-v1":
            raise SystemExit(f"Unsupported schema/style: {job['jobID']}")
        expected_id = f"{job['exerciseID']}__f{job['frameIndex']}__{job['gender']}"
        if job["jobID"] != expected_id:
            raise SystemExit(f"Noncanonical job ID: {job['jobID']}")
        expected_output = (f"shared/exercise-artwork/fud-flat-raster-v1/frames/"
                           f"{job['gender']}/{job['exerciseID']}/{job['frameIndex']}.png")
        if job["outputPath"] != expected_output:
            raise SystemExit(f"Noncanonical output path: {job['jobID']}")
        inputs = [(job["characterReferencePath"], job["characterReferenceSHA256"], "characterReferencePath")]
        inputs.extend((item["path"], item["sha256"], "sourceEndpointReferences")
                      for item in source_references(job))
        for input_path, expected_hash, path_key in inputs:
            candidate = repo / input_path
            if not candidate.is_file():
                raise SystemExit(f"Missing referenced input: {candidate}")
            cache_key = str(candidate)
            if cache_key not in hash_cache:
                hash_cache[cache_key] = sha256(candidate)
            actual = hash_cache[cache_key]
            if actual != expected_hash:
                raise SystemExit(f"Referenced input hash drift: {job['jobID']} / {path_key}")
        if "exactly ONE" not in job["prompt"] or "do not combine frames" not in job["prompt"]:
            raise SystemExit(f"One-output prompt contract missing: {job['jobID']}")
    manifest = {**sequence_manifest,
                "exerciseCount": len({job["exerciseID"] for job in jobs}),
                "maleJobs": sum(job["gender"] == "male" for job in jobs),
                "femaleJobs": sum(job["gender"] == "female" for job in jobs),
                "uniqueOutputPaths": len(outputs), "inputHashesVerified": len(hash_cache)}
    return jobs, manifest


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def image_integrity(path: Path) -> dict:
    with Image.open(path) as loaded:
        loaded.verify()
    with Image.open(path) as loaded:
        image = loaded.convert("RGBA")
    alpha = image.getchannel("A")
    histogram = alpha.histogram()
    occupancy = sum(histogram[10:]) / (image.width * image.height)
    edge = ImageStat.Stat(alpha.crop((0, 0, image.width, 8))).mean[0]
    edge += ImageStat.Stat(alpha.crop((0, image.height - 8, image.width, image.height))).mean[0]
    edge += ImageStat.Stat(alpha.crop((0, 0, 8, image.height))).mean[0]
    edge += ImageStat.Stat(alpha.crop((image.width - 8, 0, image.width, image.height))).mean[0]
    edge /= 4 * 255
    chroma_pixels = 0
    opaque_or_edge_pixels = 0
    for red, green, blue, alpha_value in image.get_flattened_data():
        if alpha_value < 24:
            continue
        opaque_or_edge_pixels += 1
        green_spill = green > 100 and green > red * 1.3 and green > blue * 1.15
        # Cyan contamination is an antialiased matte-edge artifact. Fully opaque navy/blue
        # equipment (for example an exercise mat) is valid subject content, not chroma spill.
        cyan_spill = (
            alpha_value < 240
            and green > 80
            and blue > 80
            and red < min(green, blue) * 0.55
        )
        if green_spill or cyan_spill:
            chroma_pixels += 1
    chroma_fraction = chroma_pixels / max(opaque_or_edge_pixels, 1)
    checks = {
        "png": path.suffix.lower() == ".png",
        "dimensions": image.size == (1024, 1024),
        "hasTransparency": histogram[0] > 0,
        "occupancy": 0.08 <= occupancy <= 0.82,
        "edgeClearance": edge <= 0.025,
        "chromaFringe": chroma_fraction <= 0.001,
    }
    return {
        "size": list(image.size),
        "foregroundOccupancy": round(occupancy, 6),
        "edgeAlphaFraction": round(edge, 6),
        "chromaFringeFraction": round(chroma_fraction, 8),
        "checks": checks,
        "passed": all(checks.values()),
        "sha256": sha256(path),
    }


def edge_signature(path: Path) -> list[float]:
    with Image.open(path) as loaded:
        image = loaded.convert("RGB").resize((256, 256), Image.Resampling.LANCZOS)
    edges = image.convert("L").filter(ImageFilter.FIND_EDGES).resize((8, 8), Image.Resampling.BOX)
    values = [value / 255 for value in edges.get_flattened_data()]
    norm = math.sqrt(sum(value * value for value in values)) or 1
    return [value / norm for value in values]


def cosine(first: list[float], second: list[float]) -> float:
    return sum(a * b for a, b in zip(first, second))


def extract_pose(landmarker, mp, np, path: Path) -> dict | None:
    with Image.open(path) as loaded:
        rgba = loaded.convert("RGBA")
    white = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
    white.alpha_composite(rgba)
    pixels = np.ascontiguousarray(white.convert("RGB"), dtype=np.uint8)
    image = mp.Image(image_format=mp.ImageFormat.SRGB, data=pixels)
    result = landmarker.detect(image)
    if not result.pose_landmarks:
        return None
    landmarks = result.pose_landmarks[0]
    joints = {
        name: [float(landmarks[index].x), float(landmarks[index].y)]
        for name, index in BASE_JOINTS.items()
    }
    confidence = sum(
        min(float(landmarks[index].visibility), float(landmarks[index].presence))
        for index in BASE_JOINTS.values()
    ) / len(BASE_JOINTS)
    return {"joints": joints, "confidence": confidence}


def midpoint(a: list[float], b: list[float]) -> list[float]:
    return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]


def normalize_pose(pose: dict) -> dict[str, list[float]]:
    joints = pose["joints"]
    neck = midpoint(joints["leftShoulder"], joints["rightShoulder"])
    root = midpoint(joints["leftHip"], joints["rightHip"])
    scale = math.dist(neck, root)
    if scale < 0.02:
        scale = max(
            max(point[0] for point in joints.values()) - min(point[0] for point in joints.values()),
            max(point[1] for point in joints.values()) - min(point[1] for point in joints.values()),
            0.1,
        )
    return {name: [(point[0] - root[0]) / scale, (point[1] - root[1]) / scale]
            for name, point in joints.items()}


def rmse(first: dict, second: dict, swapped: bool = False) -> float:
    total = 0.0
    for name in BASE_JOINTS:
        other = SWAP[name] if swapped else name
        total += math.dist(first[name], second[other]) ** 2
    return math.sqrt(total / len(BASE_JOINTS))


def angle(a: list[float], b: list[float]) -> float:
    return math.atan2(b[1] - a[1], b[0] - a[0])


def angle_delta(first: float, second: float) -> float:
    return abs((first - second + math.pi) % (2 * math.pi) - math.pi)


def compare_poses(source: dict | None, output: dict | None) -> dict:
    if source is None or output is None:
        return {"passed": False, "reason": "pose_not_detected",
                "sourceDetected": source is not None, "outputDetected": output is not None}
    first, second = normalize_pose(source), normalize_pose(output)
    direct = rmse(first, second)
    swapped = rmse(first, second, swapped=True)
    segment_diagnostics = []
    for start, end in SEGMENTS:
        source_angle = math.degrees(angle(first[start], first[end]))
        output_angle = math.degrees(angle(second[start], second[end]))
        delta = math.degrees(angle_delta(math.radians(source_angle), math.radians(output_angle)))
        segment_diagnostics.append({
            "segment": f"{start}->{end}",
            "sourceAngleDegrees": round(source_angle, 3),
            "outputAngleDegrees": round(output_angle, 3),
            "deltaDegrees": round(delta, 3),
            "sourceStart": [round(value, 6) for value in first[start]],
            "sourceEnd": [round(value, 6) for value in first[end]],
            "outputStart": [round(value, 6) for value in second[start]],
            "outputEnd": [round(value, 6) for value in second[end]],
        })
    deltas = sorted(item["deltaDegrees"] for item in segment_diagnostics)
    median_angle = (deltas[3] + deltas[4]) / 2
    p90_angle = deltas[7]
    source_neck = midpoint(first["leftShoulder"], first["rightShoulder"])
    output_neck = midpoint(second["leftShoulder"], second["rightShoulder"])
    torso_angle = math.degrees(angle_delta(angle([0, 0], source_neck), angle([0, 0], output_neck)))
    checks = {
        "outputConfidence": output["confidence"] >= 0.55,
        "normalizedRMSE": direct <= 0.85,
        "medianLimbAngle": median_angle <= 38,
        "p90LimbAngle": p90_angle <= 72,
        "torsoAngle": torso_angle <= 32,
        "leftRight": direct <= swapped + 0.08,
    }
    return {
        "sourceDetected": True, "outputDetected": True,
        "sourceConfidence": round(source["confidence"], 6),
        "outputConfidence": round(output["confidence"], 6),
        "normalizedRMSE": round(direct, 6),
        "swappedRMSE": round(swapped, 6),
        "medianLimbAngleDegrees": round(median_angle, 3),
        "p90LimbAngleDegrees": round(p90_angle, 3),
        "torsoAngleDegrees": round(torso_angle, 3),
        "segmentDiagnostics": sorted(segment_diagnostics,
                                     key=lambda item: item["deltaDegrees"], reverse=True),
        "checks": checks,
        "passed": all(checks.values()),
    }


def atomic_json(path: Path, value: object) -> None:
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as temporary:
        json.dump(value, temporary, indent=2, sort_keys=True)
        temporary.write("\n")
        temporary.flush(); os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, path)


def merged_report_results(report_path: Path, current: dict, partial: bool) -> dict:
    """Keep non-selected QA evidence when a deliberately partial validation runs."""
    if not partial or not report_path.is_file():
        return dict(current)
    try:
        existing = json.loads(report_path.read_text()).get("results", {})
    except (json.JSONDecodeError, OSError):
        existing = {}
    merged = dict(existing)
    merged.update(current)
    return merged


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path, default=Path(__file__).with_name("jobs-v1.jsonl"))
    parser.add_argument("--state", type=Path, default=Path(__file__).with_name("state-v1.json"))
    parser.add_argument("--manual-reviews", type=Path,
                        default=Path(__file__).with_name("manual-reviews-v1.json"))
    parser.add_argument("--report", type=Path,
                        default=Path(__file__).with_name("qa-report-v1.json"))
    parser.add_argument("--model", type=Path, default=Path("/tmp/pose_landmarker_heavy.task"))
    parser.add_argument("--pilot-only", action="store_true")
    parser.add_argument("--apply-state", action="store_true")
    parser.add_argument("--allow-missing", action="store_true")
    args = parser.parse_args()
    jobs, manifest_qa = load_jobs(args.jobs, repo)
    if args.pilot_only:
        jobs = [job for job in jobs if job["pilot"]]
    manual = (json.loads(args.manual_reviews.read_text())
              if args.manual_reviews.is_file() else {"schemaVersion": 1, "jobs": {}})
    queue_state = json.loads(args.state.read_text()).get("jobs", {})

    available = [job for job in jobs if (repo / job["outputPath"]).is_file()]
    missing = [job["jobID"] for job in jobs if not (repo / job["outputPath"]).is_file()]
    if missing and not args.allow_missing:
        raise SystemExit(f"Missing {len(missing)} generated outputs (use --allow-missing for partial QA)")

    landmarker = mp = np = None
    if available:
        if not args.model.is_file():
            raise SystemExit(f"Pose model not found: {args.model}")
        import mediapipe as imported_mp
        import numpy as imported_np
        mp = imported_mp
        np = imported_np
        options = mp.tasks.vision.PoseLandmarkerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_path=str(args.model)),
            running_mode=mp.tasks.vision.RunningMode.IMAGE,
            num_poses=1,
            min_pose_detection_confidence=0.25,
            min_pose_presence_confidence=0.25,
        )
        landmarker = mp.tasks.vision.PoseLandmarker.create_from_options(options)

    results = {}
    try:
        output_poses = {
            job["jobID"]: extract_pose(landmarker, mp, np, repo / job["outputPath"])
            for job in available
        }
        source_pose_cache = {}
        for job in available:
            for reference in source_references(job):
                path = repo / reference["path"]
                source_pose_cache.setdefault(
                    reference["sha256"], extract_pose(landmarker, mp, np, path)
                )
        available_by_key = {
            (job["gender"], job["exerciseID"], job["frameIndex"]): job
            for job in available
        }
        for job in available:
            output = repo / job["outputPath"]
            integrity = image_integrity(output)
            sequence = descriptor(job)
            references = source_references(job)
            comparison_references = (
                references if sequence["frameRole"] == "inbetween"
                else [next((item for item in references if item["frameIndex"] == job["frameIndex"]),
                           references[0])]
            )
            reference_poses = [source_pose_cache[item["sha256"]] for item in references]
            expected_pose = None
            expected_pose_metadata = None
            if sequence["frameRole"] == "inbetween" and all(reference_poses):
                expected_joints = normalized_pose_interpolation(
                    normalize_pose(reference_poses[0]), normalize_pose(reference_poses[1]),
                    float(sequence["interpolationT"]),
                )
                expected_pose = {
                    "joints": expected_joints,
                    "confidence": min(item["confidence"] for item in reference_poses),
                }
                expected_pose_metadata = {
                    "method": "linear-normalized-landmarks-v1",
                    "interpolationT": sequence["interpolationT"],
                    "endpointReferenceSHA256": [item["sha256"] for item in references],
                }
            else:
                expected_pose = source_pose_cache[comparison_references[0]["sha256"]]
            pose = compare_poses(expected_pose, output_poses[job["jobID"]])
            edge_similarity = max(
                cosine(edge_signature(repo / reference["path"]), edge_signature(output))
                for reference in comparison_references
            )
            alignment = (alignment_metadata(output_poses[job["jobID"]])
                         if output_poses[job["jobID"]] else None)
            drift = None
            sequence_complete = all(
                (job["gender"], job["exerciseID"], index) in available_by_key
                for index in range(sequence["frameCount"])
            )
            if sequence["frameCount"] == 6 and job["frameIndex"] > 0:
                previous = available_by_key.get((job["gender"], job["exerciseID"], job["frameIndex"] - 1))
                previous_pose = output_poses.get(previous["jobID"]) if previous else None
                drift = (alignment_drift(alignment_metadata(previous_pose), alignment)
                         if previous_pose and alignment else
                         {"passed": False, "reason": "previous_frame_not_available"})
            drift_pass = (drift is None or drift.get("reason") == "previous_frame_not_available"
                          or drift.get("passed") is True)
            sequence_qa_pass = pose["passed"] and alignment is not None and drift_pass
            sequence_qa = {
                "passed": sequence_qa_pass,
                "sequenceComplete": sequence_complete,
                "sequence": sequence,
                "alignment": alignment,
                "driftFromPrevious": drift,
                "expectedPose": expected_pose_metadata,
            }
            review = manual.get("jobs", {}).get(job["jobID"], {})
            manual_fields = list(MANUAL_FIELDS)
            if sequence["frameRole"] == "inbetween":
                manual_fields.append("intermediatePoseApproved")
            manual_pass = all(review.get(field) is True for field in manual_fields)
            state_item = queue_state.get(job["jobID"], {})
            generation_state_valid = (
                state_item.get("status") in {"completed_pending_qa", "qa_failed", "complete"}
                and state_item.get("outputSHA256") == integrity["sha256"]
            )
            auto_pass = (integrity["passed"] and pose["passed"] and generation_state_valid
                         and (sequence["frameCount"] == 2 or sequence_qa_pass))
            status = "accepted" if auto_pass and manual_pass else (
                "auto_failed" if not auto_pass else "manual_pending")
            results[job["jobID"]] = {
                "status": status,
                "integrity": integrity,
                "pose": pose,
                "edgeLayoutCosine": round(edge_similarity, 6),
                "edgeLayoutWarning": edge_similarity < 0.18,
                "manualRequiredFields": manual_fields,
                "manualReview": review,
                "generationStateValid": generation_state_valid,
                "sequenceQA": sequence_qa,
            }
    finally:
        if landmarker is not None:
            landmarker.close()

    stored_results = merged_report_results(args.report, results, args.pilot_only)
    counts = Counter(result["status"] for result in stored_results.values())
    report = {
        "schemaVersion": 2 if any(descriptor(job)["frameCount"] == 6 for job in jobs) else 1,
        "manifestQA": manifest_qa,
        "evaluated": len(results),
        "storedEvaluated": len(stored_results),
        "partialRun": args.pilot_only,
        "missing": len(missing),
        "statuses": dict(sorted(counts.items())),
        "thresholds": {
            "outputPoseConfidenceMinimum": 0.55,
            "normalizedPoseRMSEMaximum": 0.85,
            "medianLimbAngleDegreesMaximum": 38,
            "p90LimbAngleDegreesMaximum": 72,
            "torsoAngleDegreesMaximum": 32,
            "foregroundOccupancy": [0.08, 0.82],
            "edgeAlphaFractionMaximum": 0.025,
            "alignment": ALIGNMENT_THRESHOLDS,
        },
        "results": dict(sorted(stored_results.items())),
    }
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    if args.apply_state:
        lock_path = args.state.with_suffix(args.state.suffix + ".lock")
        with lock_path.open("a+") as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            state = json.loads(args.state.read_text())
            for job_id, result in results.items():
                item = state["jobs"][job_id]
                if result["status"] == "accepted":
                    item.update({"status": "complete", "qaStatus": "accepted"})
                elif result["status"] == "auto_failed":
                    item.update({"status": "qa_failed", "qaStatus": "rejected"})
                else:
                    item.update({"status": "completed_pending_qa", "qaStatus": "manual_pending"})
                item["sequenceQA"] = result["sequenceQA"]
            atomic_json(args.state, state)
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
    print(json.dumps({"evaluated": len(results), "missing": len(missing),
                      "statuses": dict(sorted(counts.items())), "report": str(args.report)},
                     sort_keys=True))


if __name__ == "__main__":
    main()
