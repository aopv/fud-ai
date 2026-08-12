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
    if len(jobs) != 3500 or len({job["jobID"] for job in jobs}) != 3500:
        raise SystemExit("Expected 3,500 unique canonical jobs")
    combinations = Counter((job["exerciseID"], job["frameIndex"], job["gender"]) for job in jobs)
    exercise_ids = {job["exerciseID"] for job in jobs}
    expected = {(exercise_id, frame, gender)
                for exercise_id in exercise_ids for frame in (0, 1) for gender in ("male", "female")}
    if len(exercise_ids) != 875 or set(combinations) != expected or any(value != 1 for value in combinations.values()):
        raise SystemExit("Manifest must contain every 875 x 2 x 2 source/frame/gender combination once")
    outputs = [job["outputPath"] for job in jobs]
    if len(set(outputs)) != 3500:
        raise SystemExit("Output paths must be unique")
    hash_cache = {}
    for job in jobs:
        if job.get("schemaVersion") != 1 or job.get("style") != "fud-flat-raster-v1":
            raise SystemExit(f"Unsupported schema/style: {job['jobID']}")
        expected_id = f"{job['exerciseID']}__f{job['frameIndex']}__{job['gender']}"
        if job["jobID"] != expected_id:
            raise SystemExit(f"Noncanonical job ID: {job['jobID']}")
        expected_output = (f"shared/exercise-artwork/fud-flat-raster-v1/frames/"
                           f"{job['gender']}/{job['exerciseID']}/{job['frameIndex']}.png")
        if job["outputPath"] != expected_output:
            raise SystemExit(f"Noncanonical output path: {job['jobID']}")
        for path_key, hash_key in (("sourceImagePath", "sourceImageSHA256"),
                                   ("characterReferencePath", "characterReferenceSHA256")):
            candidate = repo / job[path_key]
            if not candidate.is_file():
                raise SystemExit(f"Missing referenced input: {candidate}")
            cache_key = str(candidate)
            if cache_key not in hash_cache:
                hash_cache[cache_key] = sha256(candidate)
            actual = hash_cache[cache_key]
            if actual != job[hash_key]:
                raise SystemExit(f"Referenced input hash drift: {job['jobID']} / {path_key}")
        if "exactly ONE" not in job["prompt"] or "do not combine frames" not in job["prompt"]:
            raise SystemExit(f"One-output prompt contract missing: {job['jobID']}")
    manifest = {"jobCount": 3500, "exerciseCount": 875,
                "maleJobs": 1750, "femaleJobs": 1750,
                "uniqueOutputPaths": 3500, "inputHashesVerified": len(hash_cache)}
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
        cyan_spill = green > 80 and blue > 80 and red < min(green, blue) * 0.55
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
    deltas = sorted(math.degrees(angle_delta(angle(first[a], first[b]), angle(second[a], second[b])))
                    for a, b in SEGMENTS)
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
        for job in available:
            source = repo / job["sourceImagePath"]
            output = repo / job["outputPath"]
            integrity = image_integrity(output)
            pose = compare_poses(extract_pose(landmarker, mp, np, source),
                                 extract_pose(landmarker, mp, np, output))
            edge_similarity = cosine(edge_signature(source), edge_signature(output))
            review = manual.get("jobs", {}).get(job["jobID"], {})
            manual_pass = all(review.get(field) is True for field in MANUAL_FIELDS)
            state_item = queue_state.get(job["jobID"], {})
            generation_state_valid = (
                state_item.get("status") in {"completed_pending_qa", "qa_failed", "complete"}
                and state_item.get("outputSHA256") == integrity["sha256"]
            )
            auto_pass = integrity["passed"] and pose["passed"] and generation_state_valid
            status = "accepted" if auto_pass and manual_pass else (
                "auto_failed" if not auto_pass else "manual_pending")
            results[job["jobID"]] = {
                "status": status,
                "integrity": integrity,
                "pose": pose,
                "edgeLayoutCosine": round(edge_similarity, 6),
                "edgeLayoutWarning": edge_similarity < 0.18,
                "manualRequiredFields": list(MANUAL_FIELDS),
                "manualReview": review,
                "generationStateValid": generation_state_valid,
            }
    finally:
        if landmarker is not None:
            landmarker.close()

    counts = Counter(result["status"] for result in results.values())
    report = {
        "schemaVersion": 1,
        "manifestQA": manifest_qa,
        "evaluated": len(results),
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
        },
        "results": dict(sorted(results.items())),
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
            atomic_json(args.state, state)
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
    print(json.dumps({"evaluated": len(results), "missing": len(missing),
                      "statuses": dict(sorted(counts.items())), "report": str(args.report)},
                     sort_keys=True))


if __name__ == "__main__":
    main()
