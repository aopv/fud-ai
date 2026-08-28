#!/usr/bin/env python3
"""Shared, deterministic schema helpers for exercise artwork frame sequences."""

from __future__ import annotations

import math
from collections import defaultdict


SUPPORTED_FRAME_COUNTS = (2, 6)
SEQUENCE_SCHEMA_VERSION = 2
RUNTIME_SEQUENCE_VERSION = 1
DEFAULT_FRAME_DURATION_MS = 120
ENDPOINTS_ONLY_FRAME_DURATION_MS = 700
PLAYBACK_MODE = "pingPong"
ALIGNMENT_THRESHOLDS = {
    "pelvisAnchorDriftMaximum": 0.08,
    "torsoAnchorDriftMaximum": 0.08,
    "subjectScaleRelativeDriftMaximum": 0.12,
}


def descriptor(job: dict) -> dict:
    """Return a normalized sequence descriptor, including implicit legacy v1 jobs."""
    if "sequence" not in job:
        frame = int(job["frameIndex"])
        return {
            "schemaVersion": 1,
            "frameCount": 2,
            "frameIndex": frame,
            "frameRole": "endpoint",
            "interpolationT": float(frame),
            "endpointFrameIndices": [0, 1],
        }
    value = dict(job["sequence"])
    value.setdefault("frameIndex", job["frameIndex"])
    return value


def required_indices(job: dict) -> list[int]:
    return list(range(int(descriptor(job)["frameCount"])))


def source_references(job: dict) -> list[dict]:
    """Return exact immutable legacy references in temporal endpoint order."""
    if "sourceEndpointReferences" in job:
        return sorted(job["sourceEndpointReferences"], key=lambda item: item["frameIndex"])
    return [{
        "frameIndex": int(job["frameIndex"]),
        "path": job["sourceImagePath"],
        "sha256": job["sourceImageSHA256"],
    }]


def validate_job_sequences(jobs: list[dict]) -> dict:
    """Validate v1/v2 manifest shape and return deterministic aggregate metadata."""
    if not jobs or len({job["jobID"] for job in jobs}) != len(jobs):
        raise ValueError("Manifest must contain nonempty, unique job IDs")
    grouped: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for job in jobs:
        grouped[(job["gender"], job["exerciseID"])].append(job)
    frame_counts = set()
    for key, sequence_jobs in grouped.items():
        descriptors = [descriptor(job) for job in sequence_jobs]
        counts = {int(value["frameCount"]) for value in descriptors}
        if len(counts) != 1 or next(iter(counts)) not in SUPPORTED_FRAME_COUNTS:
            raise ValueError(f"Unsupported or inconsistent frame count: {key}")
        count = next(iter(counts))
        frame_counts.add(count)
        indices = sorted(int(job["frameIndex"]) for job in sequence_jobs)
        if indices != list(range(count)):
            raise ValueError(f"Incomplete or duplicate frame sequence: {key} / {indices}")
        endpoints = [0, count - 1]
        for job, value in zip(sequence_jobs, descriptors):
            index = int(job["frameIndex"])
            if int(value["frameIndex"]) != index:
                raise ValueError(f"Sequence/job frame mismatch: {job['jobID']}")
            expected_role = "endpoint" if index in endpoints else "inbetween"
            if value.get("frameRole") != expected_role:
                raise ValueError(f"Invalid frame role: {job['jobID']}")
            if list(value.get("endpointFrameIndices", [])) != endpoints:
                raise ValueError(f"Invalid endpoint indices: {job['jobID']}")
            expected_t = index / (count - 1)
            if not math.isclose(float(value.get("interpolationT", -1)), expected_t, abs_tol=1e-9):
                raise ValueError(f"Invalid interpolation position: {job['jobID']}")
            refs = source_references(job)
            if count == 6 and [item["frameIndex"] for item in refs] != endpoints:
                raise ValueError(f"Six-frame jobs require both endpoint references: {job['jobID']}")
    return {
        "jobCount": len(jobs),
        "sequenceCount": len(grouped),
        "frameCounts": sorted(frame_counts),
        "schemaVersion": 2 if 6 in frame_counts else 1,
    }


def accepted_state(item: dict) -> bool:
    return item.get("status") == "complete" and item.get("qaStatus") == "accepted"


def complete_sequence_qa(sequence_jobs: list[dict], state: dict[str, dict]) -> bool:
    qa = [state.get(job["jobID"], {}).get("sequenceQA", {}) for job in sequence_jobs]
    return (
        len(sequence_jobs) == 6
        and all(item.get("passed") is True and item.get("sequenceComplete") is True for item in qa)
        and qa[0].get("alignment") is not None
        and all(item.get("driftFromPrevious", {}).get("passed") is True for item in qa[1:])
    )


def runtime_selection(sequence_jobs: list[dict], state: dict[str, dict]) -> dict | None:
    """Choose the deterministic shippable runtime form for one manifest sequence."""
    ordered = sorted(sequence_jobs, key=lambda job: job["frameIndex"])
    count = int(descriptor(ordered[0])["frameCount"])
    if count == 2:
        if not all(accepted_state(state.get(job["jobID"], {})) for job in ordered):
            return None
        return {"mode": "legacyEndpoints", "frameDurationMs": None,
                "jobs": [(index, job) for index, job in enumerate(ordered)]}
    endpoints = [ordered[0], ordered[5]]
    if not all(accepted_state(state.get(job["jobID"], {})) for job in endpoints):
        return None
    if (all(accepted_state(state.get(job["jobID"], {})) for job in ordered)
            and complete_sequence_qa(ordered, state)):
        return {"mode": "completeSequence", "frameDurationMs": DEFAULT_FRAME_DURATION_MS,
                "jobs": [(index, job) for index, job in enumerate(ordered)]}
    return {"mode": "endpointsOnly", "frameDurationMs": ENDPOINTS_ONLY_FRAME_DURATION_MS,
            "jobs": [(0, endpoints[0]), (1, endpoints[1])]}


def normalized_pose_interpolation(first: dict, second: dict, t: float) -> dict:
    if not 0.0 <= t <= 1.0 or set(first) != set(second):
        raise ValueError("Pose interpolation requires matching joints and 0 <= t <= 1")
    return {
        name: [
            first[name][0] + (second[name][0] - first[name][0]) * t,
            first[name][1] + (second[name][1] - first[name][1]) * t,
        ]
        for name in first
    }


def alignment_metadata(pose: dict) -> dict:
    joints = pose["joints"]
    pelvis = [(joints["leftHip"][axis] + joints["rightHip"][axis]) / 2 for axis in (0, 1)]
    shoulders = [
        (joints["leftShoulder"][axis] + joints["rightShoulder"][axis]) / 2
        for axis in (0, 1)
    ]
    torso = [(pelvis[axis] + shoulders[axis]) / 2 for axis in (0, 1)]
    scale = math.dist(pelvis, shoulders)
    return {
        "pelvisAnchor": [round(value, 6) for value in pelvis],
        "torsoAnchor": [round(value, 6) for value in torso],
        "subjectScale": round(scale, 6),
        "method": "mediapipe-pelvis-torso-v1",
    }


def alignment_drift(previous: dict, current: dict) -> dict:
    pelvis = math.dist(previous["pelvisAnchor"], current["pelvisAnchor"])
    torso = math.dist(previous["torsoAnchor"], current["torsoAnchor"])
    prior_scale = max(float(previous["subjectScale"]), 1e-9)
    scale = abs(float(current["subjectScale"]) - prior_scale) / prior_scale
    checks = {
        "pelvisAnchorDrift": pelvis <= ALIGNMENT_THRESHOLDS["pelvisAnchorDriftMaximum"],
        "torsoAnchorDrift": torso <= ALIGNMENT_THRESHOLDS["torsoAnchorDriftMaximum"],
        "subjectScaleRelativeDrift": scale <= ALIGNMENT_THRESHOLDS["subjectScaleRelativeDriftMaximum"],
    }
    return {
        "pelvisAnchorDrift": round(pelvis, 6),
        "torsoAnchorDrift": round(torso, 6),
        "subjectScaleRelativeDrift": round(scale, 6),
        "checks": checks,
        "passed": all(checks.values()),
    }
