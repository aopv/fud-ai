#!/usr/bin/env python3
"""Conservative, non-generative registration of four-frame workout sequences.

Requires Pillow, NumPy and OpenCV. The default is an analysis-only JSON report.
Only an explicitly reviewed stationary-anchor profile can authorize output; a
feature match cannot establish whether a foot, torso, or bar should be moving.
Unknown exercises receive diagnostic lower-frame matches, never auto-alignment.

All accepted operations are one uniform scale plus translation per complete
frame. No rotations, perspective transforms, limb warps, per-pose bbox fitting,
inpainting, or synthetic pixels are used. A final common transform fits the
UNION of all four registered poses, preserving real motion and its relative
scale. Suspicious clipping or contradictory anchor geometry blocks the entire
sequence. Output is restricted to an experiment directory, not either canonical
asset location. Background cleanup must be reviewed separately.

Example:
  python scripts/workout_frame_alignment.py --exercise Band_Pull_Apart \
    --use-reviewed-initial-anchors --output /tmp/workout-alignment-experiment

Custom --anchors JSON:
  {"Exercise_ID:male": {"reviewed": true, "reason": "Both feet stay planted",
    "regions": [{"name": "left_foot", "box": [0.3, 0.8, 0.5, 1.0]},
                {"name": "right_foot", "box": [0.5, 0.8, 0.7, 1.0]}]}}
Boxes are normalized coordinates in reference frame 0. They must contain only
semantically stationary anatomy/equipment, not merely visually similar pixels.
Use an explicit "blocked_reason" for intrinsic perspective/crop defects.
"""

from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import sys

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / "shared/workout-vectors"
IOS_ASSETS = ROOT / "ios/calorietracker/Assets.xcassets"
ANALYSIS_EDGE = 640
MIN_MATCHES = 12
MAX_RESIDUAL = 5.0  # Original canvas pixels, not analysis pixels.


@dataclass(frozen=True)
class UniformTransform:
    scale: float = 1.0
    tx: float = 0.0
    ty: float = 0.0

    def apply(self, points: np.ndarray) -> np.ndarray:
        return np.asarray(points) * self.scale + np.array([self.tx, self.ty])

    def then(self, outer: "UniformTransform") -> "UniformTransform":
        return UniformTransform(self.scale * outer.scale,
                                self.tx * outer.scale + outer.tx,
                                self.ty * outer.scale + outer.ty)

    def as_dict(self) -> dict:
        return {"scale": round(self.scale, 7), "tx": round(self.tx, 5), "ty": round(self.ty, 5)}


def region(name: str, box: tuple[float, float, float, float]) -> dict:
    return {"name": name, "box": box}


def reviewed_initial_profile(exercise: str, gender: str) -> dict | None:
    """Anchors reviewed against all eight original images on 2026-09-04."""
    if exercise == "Band_Pull_Apart":
        return {"reviewed": True, "reason": "Both feet and head remain stationary throughout the band pull; only arms/band move.",
                "regions": [region("left_foot", (.36, .86, .48, .99)),
                            region("right_foot", (.53, .86, .63, .99)),
                            region("head", (.44, .01, .56, .18))]}
    if exercise == "Barbell_Full_Squat":
        return {"reviewed": True, "reason": "Feet remain planted; head, torso and bar must move vertically.",
                "regions": [region("left_foot", (.36, .88, .51, .99)),
                            region("right_foot", (.54, .87, .67, .99))]}
    if exercise == "Band_Skull_Crusher":
        if gender == "female":
            return {"reviewed": True, "blocked_reason": "Frame 3 visibly clips the right shoe; registration cannot reconstruct it.",
                    "regions": []}
        boxes = ((.01, .79, .24, .99), (.66, .77, .78, .99))
        return {"reviewed": True, "reason": "The two ends of the fixed bench support are stationary.",
                "allow_flat_boundary_reason": "All four male frames reviewed: square left bench fixture face is intentional, not clipping.",
                "regions": [region("bench_left", boxes[0]), region("bench_right", boxes[1])]}
    if exercise in {"Barbell_Ab_Rollout", "Barbell_Ab_Rollout_-_On_Knees"}:
        reason = ("Visual review confirms inconsistent equipment size/camera perspective and moving foot anchors."
                  if exercise == "Barbell_Ab_Rollout" else
                  "Visual review confirms clipped anatomy/equipment and neighboring sprite fragments.")
        return {"reviewed": True, "blocked_reason": reason, "regions": []}
    return None


def validate_profile(profile: dict) -> None:
    if not isinstance(profile.get("reviewed", False), bool):
        raise ValueError("anchor reviewed field must be a boolean")
    names = set()
    for item in profile.get("regions", []):
        name, box = item["name"], item["box"]
        if name in names or len(box) != 4 or not (0 <= box[0] < box[2] <= 1 and 0 <= box[1] < box[3] <= 1):
            raise ValueError(f"invalid or duplicate anchor region: {item}")
        names.add(name)
    if profile.get("reviewed") and not profile.get("blocked_reason") and len(names) < 2:
        raise ValueError("reviewed alignment requires at least two independent anchor regions")


def least_squares_uniform(source: np.ndarray, target: np.ndarray) -> UniformTransform:
    source, target = np.asarray(source, dtype=np.float64), np.asarray(target, dtype=np.float64)
    sm, tm = source.mean(axis=0), target.mean(axis=0)
    centered = source - sm
    denominator = float(np.sum(centered * centered))
    if denominator < 1e-6:
        raise ValueError("degenerate anchor geometry")
    scale = float(np.sum(centered * (target - tm)) / denominator)
    translation = tm - scale * sm
    return UniformTransform(scale, *map(float, translation))


def longest_run(values: np.ndarray) -> int:
    edges = np.diff(np.concatenate(([False], values, [False])).astype(np.int8))
    starts, ends = np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)
    return int((ends - starts).max()) if len(starts) else 0


def inspect_rgba(rgba: np.ndarray) -> dict:
    alpha = rgba[..., 3]
    visible = alpha >= 32
    ys, xs = np.nonzero(visible)
    if not len(xs):
        raise ValueError("empty image")
    l, t, r, b = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    rgb = rgba[..., :3].astype(np.int16)
    pale = (rgb.min(axis=2) >= 205) & (np.ptp(rgb, axis=2) < 16)
    solid = (alpha >= 224) & ~pale
    vertical = max(longest_run(solid[t:b, l]), longest_run(solid[t:b, r - 1]))
    horizontal = max(longest_run(solid[t, l:r]), longest_run(solid[b - 1, l:r]))
    edge_pixels = int(solid[:2].sum() + solid[-2:].sum() + solid[:, :2].sum() + solid[:, -2:].sum())
    flags = []
    if edge_pixels >= 8:
        flags.append("possible_canvas_edge_clipping")
    if vertical >= 24 or horizontal >= 80:
        flags.append("possible_precropped_flat_boundary")
    if (alpha == 0).mean() < .02:
        flags.append("background_cleanup_required")
    return {"bbox": [l, t, r, b], "size": [rgba.shape[1], rgba.shape[0]],
            "opaque_pale_fraction": round(float(((alpha >= 224) & pale).mean()), 6),
            "flat_vertical_boundary": vertical, "flat_horizontal_boundary": horizontal,
            "edge_pixels": edge_pixels, "flags": flags}


def features(rgba: np.ndarray, analysis_edge: int = ANALYSIS_EDGE) -> tuple[np.ndarray, np.ndarray | None]:
    height, width = rgba.shape[:2]
    factor = min(1.0, analysis_edge / max(width, height))
    scaled = cv2.resize(rgba, (round(width * factor), round(height * factor)), interpolation=cv2.INTER_AREA)
    rgb = scaled[..., :3].astype(np.int16)
    pale = (rgb.min(axis=2) >= 195) & (np.ptp(rgb, axis=2) < 20)
    mask = ((scaled[..., 3] >= 224) & ~pale).astype(np.uint8) * 255
    mask = cv2.erode(mask, np.ones((3, 3), np.uint8))
    gray = cv2.cvtColor(scaled[..., :3], cv2.COLOR_RGB2GRAY)
    # Hidden RGB and painted checkerboard/neutral ground cannot become anchors.
    gray[scaled[..., 3] < 32] = 0
    detector = cv2.SIFT_create(nfeatures=3000 if analysis_edge > ANALYSIS_EDGE else 1800,
                               contrastThreshold=.025, edgeThreshold=12)
    keypoints, descriptors = detector.detectAndCompute(gray, mask)
    points = np.array([kp.pt for kp in keypoints], dtype=np.float32).reshape(-1, 2) / factor
    return points, descriptors


def anchor_matches(source_features: tuple, target_features: tuple, profile: dict, size: tuple[int, int]) -> tuple:
    source_points, source_descriptors = source_features
    target_points, target_descriptors = target_features
    if source_descriptors is None or target_descriptors is None or min(len(source_points), len(target_points)) < 2:
        return np.empty((0, 2)), np.empty((0, 2)), np.empty(0, dtype=int)
    matcher = cv2.BFMatcher(cv2.NORM_L2)
    forward = matcher.knnMatch(source_descriptors, target_descriptors, k=2)
    reverse = matcher.knnMatch(target_descriptors, source_descriptors, k=2)
    reverse_good = {m.queryIdx: m.trainIdx for pair in reverse if len(pair) == 2 for m, n in [pair] if m.distance < .72 * n.distance}
    source, target, labels = [], [], []
    width, height = size
    for pair in forward:
        if len(pair) != 2:
            continue
        m, n = pair
        if m.distance >= .72 * n.distance or reverse_good.get(m.trainIdx) != m.queryIdx:
            continue
        destination = target_points[m.trainIdx]
        x, y = destination / np.array([width, height])
        for label, item in enumerate(profile["regions"]):
            left, top, right, bottom = item["box"]
            if left <= x <= right and top <= y <= bottom:
                source.append(source_points[m.queryIdx])
                target.append(destination)
                labels.append(label)
                break
    return np.array(source).reshape(-1, 2), np.array(target).reshape(-1, 2), np.array(labels)


def assess_matches(source: np.ndarray, target: np.ndarray, labels: np.ndarray, size: tuple[int, int], required_regions: int = 2) -> dict:
    """A geometric gate, not a claim that the matched body part should be stationary."""
    result = {"matches": len(source), "accepted": False, "reasons": []}
    if len(source) < MIN_MATCHES:
        result["reasons"].append("insufficient_anchor_matches")
        return result
    cv2.setRNGSeed(8725)
    affine, mask = cv2.estimateAffinePartial2D(np.float32(source), np.float32(target), method=cv2.RANSAC,
                                            ransacReprojThreshold=MAX_RESIDUAL, maxIters=3000,
                                            confidence=.999, refineIters=15)
    if affine is None or mask is None:
        result["reasons"].append("anchor_fit_failed")
        return result
    inliers = mask.ravel().astype(bool)
    src, dst = source[inliers], target[inliers]
    fitted = least_squares_uniform(src, dst)
    residuals = np.linalg.norm(fitted.apply(src) - dst, axis=1)
    rotation = float(np.degrees(np.arctan2(affine[1, 0], affine[0, 0])))
    span = np.ptp(dst, axis=0)
    support = {int(label): int((labels[inliers] == label).sum()) for label in np.unique(labels)}
    result.update({"inliers": int(inliers.sum()), "inlier_ratio": round(float(inliers.mean()), 4),
                   "residual_p90_px": round(float(np.percentile(residuals, 90)), 4),
                   "rotation_degrees": round(rotation, 4), "anchor_span_px": span.round(2).tolist(),
                   "region_support": support, "diagnostic_transform": fitted.as_dict()})
    if inliers.sum() < MIN_MATCHES or inliers.mean() < .70:
        result["reasons"].append("weak_anchor_consensus")
    if sum(count >= 4 for count in support.values()) < required_regions or span[0] < size[0] * .10:
        result["reasons"].append("anchors_not_independently_distributed")
    if abs(rotation) > 1.25 or np.percentile(residuals, 90) > MAX_RESIDUAL:
        result["reasons"].append("rotation_or_nonuniform_geometry")
    if not .90 <= fitted.scale <= 1.10 or abs(fitted.tx) > size[0] * .12 or abs(fitted.ty) > size[1] * .12:
        result["reasons"].append("large_camera_or_perspective_change")
    # Require independent stationary regions to agree, rather than trusting one
    # large cluster on a shoe or moving elbow to dominate a RANSAC solution.
    local_fits = []
    for label in support:
        selected = inliers & (labels == label)
        if selected.sum() >= 6 and np.linalg.norm(np.ptp(source[selected], axis=0)) >= 20:
            local = least_squares_uniform(source[selected], target[selected])
            local_fits.append({"region": label, **local.as_dict()})
            # Do not extrapolate a noisy tiny-shoe scale estimate to the head:
            # 1px of local redraw over 20px can imply 35px over a full body.
            # Validate each region locally and require the global consensus to
            # explain all independently named regions. Scale uncertainty shrinks
            # with spatial support; gross perspective changes still fail.
            local_source = source[selected]
            anchor_error = np.linalg.norm(local.apply(local_source) - fitted.apply(local_source), axis=1)
            local_span = np.linalg.norm(np.ptp(local_source, axis=0))
            scale_tolerance = max(.025, 2.0 / local_span)
            if abs(local.scale - fitted.scale) > scale_tolerance or np.percentile(anchor_error, 90) > MAX_RESIDUAL:
                result["reasons"].append("independent_anchor_geometry_disagrees")
    result["independent_fits"] = local_fits
    full_affine, _ = cv2.estimateAffine2D(np.float32(src), np.float32(dst), method=cv2.RANSAC,
                                        ransacReprojThreshold=MAX_RESIDUAL)
    if full_affine is not None and span[1] >= 20:
        singular = np.linalg.svd(full_affine[:, :2], compute_uv=False)
        anisotropy = float(singular.max() / max(singular.min(), 1e-9))
        result["affine_anisotropy"] = round(anisotropy, 4)
        if anisotropy > 1.06:
            result["reasons"].append("possible_intrinsic_perspective_or_anatomy_change")
    result["reasons"] = sorted(set(result["reasons"]))
    result["accepted"] = not result["reasons"]
    return result


def sequence_fit(bboxes: list[list[int]], transforms: list[UniformTransform], size: tuple[int, int], padding: int) -> UniformTransform:
    """One common fit of the pose union; never fit individual frame bboxes."""
    corners = []
    for (left, top, right, bottom), transform in zip(bboxes, transforms):
        corners.extend(transform.apply(np.array([[left, top], [right, bottom]])))
    all_points = np.array(corners)
    low, high = all_points.min(axis=0), all_points.max(axis=0)
    width, height = size
    available = np.array([width, height]) - 2 * padding
    if np.any(available <= 0):
        raise ValueError("padding leaves no usable canvas")
    scale = min(1.0, float(np.min(available / (high - low))))
    center = (low + high) / 2
    translation = np.array([width, height]) / 2 - scale * center
    return UniformTransform(scale, *map(float, translation))


def render_uniform(rgba: np.ndarray, transform: UniformTransform, size: tuple[int, int]) -> np.ndarray:
    """Resample premultiplied RGBA, preventing hidden white RGB from making halos."""
    premultiplied = rgba.astype(np.float32) / 255
    premultiplied[..., :3] *= premultiplied[..., 3:4]
    matrix = np.array([[transform.scale, 0, transform.tx], [0, transform.scale, transform.ty]], dtype=np.float32)
    warped = cv2.warpAffine(premultiplied, matrix, size, flags=cv2.INTER_LANCZOS4,
                            borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
    alpha = np.clip(warped[..., 3:4], 0, 1)
    rgb = np.clip(warped[..., :3], 0, alpha)
    np.divide(rgb, alpha, out=rgb, where=alpha > 1e-6)
    rgb[alpha[..., 0] <= 1e-6] = 0
    return np.round(np.concatenate((rgb, alpha), axis=2) * 255).astype(np.uint8)


def ensure_experiment_output(output: Path, source: Path) -> None:
    output, source = output.resolve(), source.resolve()
    for protected in (CANONICAL.resolve(), IOS_ASSETS.resolve(), source):
        if output == protected or output.is_relative_to(protected) or protected.is_relative_to(output):
            raise ValueError(f"output must be a separate experiment directory, not {output}")


def analyze_job(job: dict) -> dict:
    cv2.setNumThreads(1)
    if job["write_images"]:
        ensure_experiment_output(Path(job["output"]), Path(job["paths"][0]).parent)
    exercise, gender = job["exercise"], job["gender"]
    profile = job["profile"]
    if profile is None:
        profile = {"reviewed": False, "reason": "Diagnostic lower-frame candidates only; stationary meaning is unverified.",
                   "regions": [region("lower_left", (0, .70, .5, 1)), region("lower_right", (.5, .70, 1, 1))]}
    validate_profile(profile)
    result = {"exercise_id": exercise, "gender": gender, "profile": profile,
              "status": "needs_review", "flags": [], "frames": []}
    if profile.get("blocked_reason"):
        result["flags"].append("visually_confirmed_nonregistrable_sequence")
    images, extracted = [], []
    for path_string in job["paths"]:
        path = Path(path_string)
        with Image.open(path) as image:
            rgba = np.asarray(image.convert("RGBA"))
        metadata = inspect_rgba(rgba)
        metadata.update({"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        result["frames"].append(metadata)
        result["flags"].extend(flag for flag in metadata["flags"]
                               if flag != "possible_precropped_flat_boundary" or not profile.get("allow_flat_boundary_reason"))
        images.append(rgba)
    if len(images) != 4 or len({image.shape for image in images}) != 1:
        result["flags"].append("requires_four_equal_canvas_frames")
        return result
    height, width = images[0].shape[:2]
    result["size"] = [width, height]
    bboxes = np.array([frame["bbox"] for frame in result["frames"]])
    result["diagnostic_bbox_range_px"] = np.ptp(bboxes, axis=0).tolist()
    result["bbox_warning"] = "BBox variation includes legitimate motion and is never used as a per-frame scale estimate."
    if profile.get("blocked_reason"):
        result["status"] = "unsupported_intrinsic_or_crop_defect"
        result["flags"] = sorted(set(result["flags"]))
        return result
    for rgba in images:
        extracted.append(features(rgba, analysis_edge=1024 if profile.get("reviewed") else ANALYSIS_EDGE))
    transforms = [UniformTransform()]
    result["frames"][0]["registration"] = {"accepted": True, "reference": True}
    for index in range(1, 4):
        source, target, labels = anchor_matches(extracted[index], extracted[0], profile, (width, height))
        assessment = assess_matches(source, target, labels, (width, height), required_regions=len(profile["regions"]))
        result["frames"][index]["registration"] = assessment
        result["flags"].extend(assessment["reasons"])
        values = assessment.get("diagnostic_transform", {"scale": 1, "tx": 0, "ty": 0})
        transforms.append(UniformTransform(**values))
    if not profile.get("reviewed"):
        result["flags"].append("stationary_anchor_semantics_not_reviewed")
    result["flags"] = sorted(set(result["flags"]))
    if not result["flags"]:
        common = sequence_fit(bboxes.tolist(), transforms, (width, height), job["padding"])
        result["status"] = "high_confidence_anchor_alignment"
        result["common_union_transform"] = common.as_dict()
        for index, transform in enumerate(transforms):
            final = transform.then(common)
            result["frames"][index]["approved_transform"] = final.as_dict()
            if job["write_images"]:
                destination = Path(job["output"]) / "images" / Path(job["paths"][index]).name
                destination.parent.mkdir(parents=True, exist_ok=True)
                Image.fromarray(render_uniform(images[index], final, (width, height))).save(destination)
                result["frames"][index]["experiment_output"] = str(destination)
    return result


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", type=Path, default=CANONICAL)
    parser.add_argument("--manifest", type=Path, default=CANONICAL / "exercise-visual-manifest.json")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--exercise", action="append", help="Repeat to select exact manifest exercise IDs; otherwise audit all.")
    parser.add_argument("--anchors", type=Path, help="Reviewed stationary region JSON keyed by Exercise_ID:gender.")
    parser.add_argument("--use-reviewed-initial-anchors", action="store_true")
    parser.add_argument("--apply-high-confidence", action="store_true", help="Write accepted complete sequences to output/images only.")
    parser.add_argument("--padding", type=int, default=24)
    parser.add_argument("--workers", type=int, default=2)
    return parser.parse_args()


def main() -> int:
    args = parse_arguments()
    ensure_experiment_output(args.output, args.source)
    if args.workers < 1 or args.padding < 0:
        raise ValueError("workers must be positive and padding nonnegative")
    manifest = json.loads(args.manifest.read_text())
    custom = json.loads(args.anchors.read_text()) if args.anchors else {}
    selected = set(args.exercise or [])
    known = {entry["exerciseId"] for entry in manifest["exercises"]}
    if selected - known:
        raise ValueError(f"unknown exercise IDs: {sorted(selected - known)}")
    jobs = []
    for entry in manifest["exercises"]:
        exercise = entry["exerciseId"]
        if selected and exercise not in selected:
            continue
        for gender in ("male", "female"):
            profile = custom.get(f"{exercise}:{gender}")
            if profile is None and args.use_reviewed_initial_anchors:
                profile = reviewed_initial_profile(exercise, gender)
            paths = [args.source / (name + ".png") for name in entry[gender + "Frames"]]
            if any(not path.is_file() for path in paths):
                raise ValueError(f"missing frame in {exercise}:{gender}")
            jobs.append({"exercise": exercise, "gender": gender, "paths": list(map(str, paths)),
                         "profile": profile, "padding": args.padding, "output": str(args.output.resolve()),
                         "write_images": args.apply_high_confidence})
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    with ProcessPoolExecutor(max_workers=args.workers) as executor:
        for index, result in enumerate(executor.map(analyze_job, jobs), 1):
            results.append(result)
            if index % 100 == 0 or index == len(jobs):
                print(f"analyzed {index}/{len(jobs)} sequences", flush=True)
    report = {"schema_version": 1, "algorithm_revision": "stationary-anchors-v2", "source": str(args.source.resolve()),
              "algorithm": "Reviewed stationary anchors; mutual SIFT + robust uniform scale/translation; shared pose-union fit.",
              "scope": "Geometric triage only; no image-quality or exercise-technique pass is implied.",
              "counts": dict(Counter(record["status"] for record in results)), "sequence_count": len(results),
              "frame_count": sum(len(record["frames"]) for record in results), "sequences": results}
    report_path = args.output / "alignment-report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(report_path), "counts": report["counts"]}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
