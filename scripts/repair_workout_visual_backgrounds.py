#!/usr/bin/env python3
"""Conservative, non-generative alpha cleanup; writes candidates, never originals.

Requires Pillow, NumPy, OpenCV, rembg and ONNXRuntime. Explicitly uses the local
MIT BiRefNet-general-lite segmenter as a vote, NEVER as a full cutout (which can
delete benches). Only existing pale components with strong background consensus
are eligible, with a per-pixel foreground guard. Original RGB is preserved.
Ambiguous regions remain for review. This does not fix anatomy or perspective.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "shared/workout-vectors"
IOS = ROOT / "ios/calorietracker/Assets.xcassets"
MODEL = "birefnet-general-lite"
# Queue ordering and provably unchanged preflight preserve pixel results, so
# existing hash-checked candidates remain valid under the same cleanup recipe.
RECIPE = "pale-neural-guard-v2"
PRIORITY_FLAGS = frozenset(("suspected_baked_checkerboard", "large_opaque_pale_region"))


def ordered_frames(entries: list[dict], selected: set[str], audit: dict | None = None) -> tuple[list[str], dict[str, dict]]:
    """Stable whole-exercise priority, never a filter or acceptance authority.

    Audit hashes may be old (for example after a reviewed repair). They are
    checked against the live source while staging and reported, but only affect
    queue position. Every selected frame still receives the current safeguards.
    """
    groups = {}
    owners = {}
    for entry in entries:
        exercise = entry["exerciseId"]
        frames = [stem+".png" for gender in ("male", "female") for stem in entry[gender+"Frames"]]
        if exercise in groups or len(set(frames)) != len(frames) or any(name in owners for name in frames):
            raise ValueError("manifest exercise IDs and frame filenames must be unique")
        groups[exercise] = frames
        owners.update({name: exercise for name in frames})
    if selected - groups.keys():
        raise ValueError("unknown exercise selection")
    records = {}
    if audit is not None:
        if not isinstance(audit, dict) or not isinstance(audit.get("images"), list):
            raise ValueError("priority audit must contain an images array")
        for record in audit["images"]:
            name = record.get("file") if isinstance(record, dict) else None
            if not isinstance(name, str) or name not in owners or name in records:
                raise ValueError(f"unknown or duplicate priority audit filename: {name}")
            if record.get("exercise_id", owners[name]) != owners[name]:
                raise ValueError(f"priority audit exercise does not own frame: {name}")
            flags = record.get("flags", [])
            if not isinstance(flags, list) or any(not isinstance(flag, str) for flag in flags):
                raise ValueError(f"invalid priority audit flags: {name}")
            digest = record.get("file_sha256")
            if digest is not None and (not isinstance(digest, str) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest)):
                raise ValueError(f"invalid priority audit source hash: {name}")
            records[name] = {"flags": sorted(PRIORITY_FLAGS.intersection(flags)), "source_sha256": digest}
    prioritized = {owners[name] for name, record in records.items() if record["flags"]}
    exercises = sorted((exercise for exercise in groups if exercise in selected), key=lambda exercise: exercise not in prioritized)
    return [name for exercise in exercises for name in groups[exercise]], records


def audit_frame_context(records: dict[str, dict], filename: str, source_hash: str) -> dict:
    record = records.get(filename)
    return {"authority": "ordering_only_not_acceptance", "present": record is not None,
            "flags": record["flags"] if record else [],
            "source_hash_matches": record["source_sha256"] == source_hash if record and record["source_sha256"] else None,
            "note": "Missing or stale audit hashes cannot skip cleanup or authorize acceptance."}


def verified_cached_record(source: Path, image: Path, record: Path, config_hash: str, source_hash: str | None = None) -> dict | None:
    """Verify only existing pairs; missing pairs never hash uncached sources.

    Reused both before queue traversal (accurate resume count) and at the point
    of reuse (invalidate any source/candidate changes since the initial scan).
    """
    if not image.is_file() or not record.is_file():
        return None
    try:
        source_hash = source_hash or hashlib.sha256(source.read_bytes()).hexdigest()
        cached = json.loads(record.read_text())
        if not isinstance(cached, dict):
            return None
        candidate_hash = hashlib.sha256(image.read_bytes()).hexdigest()
        if (cached.get("source_sha256"), cached.get("recipe"), cached.get("override_sha256"), cached.get("candidate_sha256")) != (source_hash, RECIPE, config_hash, candidate_hash):
            return None
        # Do not count a source that changed while verifying the pair.
        if hashlib.sha256(source.read_bytes()).hexdigest() != source_hash:
            return None
        return cached
    except (OSError, ValueError):
        return None


def analyze(rgba: np.ndarray) -> tuple[np.ndarray, list[dict]]:
    rgb = rgba[:, :, :3].astype(np.int16)
    lo, hi = rgb.min(axis=2), rgb.max(axis=2)
    pale = (rgba[:, :, 3] >= 16) & (lo >= 185) & ((hi - lo) <= 18)
    count, labels, stats, centers = cv2.connectedComponentsWithStats(pale.astype(np.uint8), 8)
    adjacent_clear = cv2.dilate((rgba[:, :, 3] < 8).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    gray = rgb.mean(axis=2)
    records = []
    for label in range(1, count):
        x, y, w, h, area = map(int, stats[label])
        if area < 8:
            continue
        region = labels[y:y+h, x:x+w] == label
        patch = gray[y:y+h, x:x+w]
        dx = np.abs(np.diff(patch, axis=1))
        dy = np.abs(np.diff(patch, axis=0))
        hx = int(((dx >= 8) & (dx <= 55) & region[:, 1:] & region[:, :-1]).sum())
        vy = int(((dy >= 8) & (dy <= 55) & region[1:, :] & region[:-1, :]).sum())
        distance = cv2.distanceTransform(np.pad(region.astype(np.uint8), 1), cv2.DIST_L2, 5)
        thickness = float(distance.max())
        values = patch[region]
        checker = area >= 240 and thickness >= 3 and hx >= 20 and vy >= 20 and float(values.std()) >= 3
        touches_clear = bool(np.any(adjacent_clear[y:y+h, x:x+w] & region))
        records.append({
            "label": label, "area": area, "bbox": [x, y, x+w, y+h],
            "center": [round(float(c), 2) for c in centers[label]],
            "max_radius": round(thickness, 2), "gray_std": round(float(values.std()), 2),
            "horizontal_transitions": hx, "vertical_transitions": vy,
            "touches_transparency": touches_clear, "checker_candidate": bool(checker),
        })
    return labels, records


def validate_seeds(labels: np.ndarray, seeds: list[list[int]], protected: list[list[int]]) -> tuple[set[int], set[int]]:
    reviewed, protection = set(), set()
    height, width = labels.shape
    for x, y in seeds:
        if not (0 <= x < width and 0 <= y < height) or labels[y, x] == 0:
            raise ValueError(f"reviewed removal seed is not in a pale region: {(x, y)}")
        reviewed.add(int(labels[y, x]))
    for x, y in protected:
        if not (0 <= x < width and 0 <= y < height) or labels[y, x] == 0:
            raise ValueError(f"protection seed is not in a pale region: {(x, y)}")
        protection.add(int(labels[y, x]))
    if reviewed & protection:
        raise ValueError("a component cannot be removed and protected")
    return reviewed, protection


def unchanged_preflight(rgba: np.ndarray, analysis: tuple[np.ndarray, list[dict]], seeds: list[list[int]] = (), protected: list[list[int]] = ()) -> tuple[np.ndarray, dict] | None:
    """Avoid inference only when no model prediction can change this frame.

    Seed overrides are validated even on otherwise empty/ineligible images;
    they can intentionally remove components smaller than the automatic gate.
    No synthetic probability mask is persisted to the model cache.
    """
    labels, regions = analysis
    validate_seeds(labels, seeds, protected)
    if seeds or protected or any(region["area"] >= 16 for region in regions):
        return None
    return rgba.copy(), {"selected_regions": [], "removed_visible_pixels": 0,
                         "uncertain_pixels_retained": 0, "rgb_changed_pixels": 0, "regions": regions,
                         "inference_skipped_reason": "no_eligible_pale_components_and_no_seed_overrides"}


def cleanup(rgba: np.ndarray, probability: np.ndarray, seeds: list[list[int]] = (), protected: list[list[int]] = (), *, analysis: tuple[np.ndarray, list[dict]] | None = None) -> tuple[np.ndarray, dict]:
    if rgba.dtype != np.uint8 or probability.dtype != np.uint8 or rgba.shape[:2] != probability.shape:
        raise ValueError("expected matching uint8 RGBA and grayscale mask")
    labels, regions = analyze(rgba) if analysis is None else analysis
    reviewed, protection = validate_seeds(labels, seeds, protected)
    selected = set()
    for region in regions:
        x, y, right, bottom = region["bbox"]
        component = labels[y:bottom, x:right] == region["label"]
        votes = probability[y:bottom, x:right][component]
        low, high = float((votes < 64).mean()), float((votes >= 192).mean())
        region.update({"background_fraction": round(low, 4), "foreground_fraction": round(high, 4)})
        if region["area"] >= 16 and low >= .80:
            selected.add(region["label"])
    selected = (selected | reviewed) - protection
    eligible = np.isin(labels, list(selected))
    remove = eligible & ((probability < 128) | np.isin(labels, list(reviewed)))
    result = rgba.copy()
    result[remove, 3] = 0
    # Foreground color data must be identical; only opacity may be reduced.
    assert np.array_equal(result[:, :, :3], rgba[:, :, :3])
    assert np.all(result[:, :, 3] <= rgba[:, :, 3])
    report = {"selected_regions": sorted(selected), "removed_visible_pixels": int((remove & (rgba[:, :, 3] > 0)).sum()),
              "uncertain_pixels_retained": int((eligible & ~remove).sum()), "rgb_changed_pixels": 0, "regions": regions}
    return result, report


def ensure_staging(output: Path, source: Path) -> None:
    output = output.resolve()
    for protected in (source.resolve(), SOURCE.resolve(), IOS.resolve()):
        if output == protected or output.is_relative_to(protected) or protected.is_relative_to(output):
            raise ValueError("output must be separate from source and production asset locations")


def load_session(provider: str, threads: int):
    import onnxruntime as ort
    from rembg import new_session
    if provider not in ort.get_available_providers():
        raise ValueError(f"unavailable provider: {provider}")
    options = ort.SessionOptions()
    options.intra_op_num_threads = threads
    options.inter_op_num_threads = 1
    providers = [provider] if provider == "CPUExecutionProvider" else [provider, "CPUExecutionProvider"]
    return new_session(MODEL, providers=providers, sess_opts=options)


def preview(rgba: np.ndarray, report: dict, path: Path, labels: bool = False) -> None:
    source = Image.fromarray(rgba)
    width, height = source.size
    canvas = Image.new("RGB", (width*2, height))
    for index, background in enumerate(("#090909", "#eeeeee")):
        panel = Image.new("RGBA", source.size, background)
        panel.alpha_composite(source)
        canvas.paste(panel.convert("RGB"), (index*width, 0))
    if labels:
        draw = ImageDraw.Draw(canvas)
        for region in report["regions"]:
            if region["area"] < 15:
                continue
            x, y = region["center"]
            draw.text((x, y), str(region["label"]), fill="#ff2860", stroke_width=1, stroke_fill="black")
    canvas.save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exercise", action="append", help="Exact exercise ID; omit to stage the full manifest")
    parser.add_argument("--exclude-exercise", action="append", default=[], help="Skip an already accepted exercise")
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--manifest", type=Path, default=SOURCE/"exercise-visual-manifest.json")
    parser.add_argument("--source-map", type=Path, help="Canonical filename to recovered source path mapping")
    parser.add_argument("--priority-audit", type=Path, help="Prioritize whole exercises with checkerboard/pale flags; never omit or accept frames")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--overrides", type=Path)
    parser.add_argument("--labels", action="store_true")
    parser.add_argument("--previews", action="store_true")
    parser.add_argument("--provider", default="CPUExecutionProvider", choices=["CPUExecutionProvider", "CoreMLExecutionProvider"])
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()
    ensure_staging(args.output, args.source)
    if args.threads < 1:
        parser.error("threads must be positive")
    overrides = json.loads(args.overrides.read_text()) if args.overrides else {}
    source_map = json.loads(args.source_map.read_text()) if args.source_map else {}
    entries = json.loads(args.manifest.read_text())["exercises"]
    known = {entry["exerciseId"] for entry in entries}
    selected = set(args.exercise or known)
    if (selected | set(args.exclude_exercise)) - known:
        parser.error("unknown exercise selection")
    selected -= set(args.exclude_exercise)
    audit = json.loads(args.priority_audit.read_text()) if args.priority_audit else None
    try:
        names, audit_records = ordered_frames(entries, selected, audit)
    except ValueError as error:
        parser.error(str(error))
    priority_context = {"path": str(args.priority_audit.resolve()) if args.priority_audit else None,
                        "authority": "ordering_only_not_acceptance", "all_selected_frames_retained": True,
                        "flagged_selected_frames": sum(bool(audit_records.get(name, {}).get("flags")) for name in names),
                        "hash_policy": "Audit hashes checked per staged frame; missing/stale records change ordering only."}
    sources = {}
    for filename in names:
        path = Path(source_map.get(filename, str(args.source/filename)))
        path = path if path.is_absolute() else ROOT/path
        if path.resolve().is_relative_to(args.output.resolve()):
            parser.error("a recovered source may not be inside the output directory")
        if not path.is_file():
            parser.error(f"missing source: {path}")
        sources[filename] = path
    args.output.mkdir(parents=True, exist_ok=True)
    # Retain this handle for the process lifetime. Restart is resumable, but two
    # workers may not silently write competing records into one staging folder.
    lock = (args.output/".repair.lock").open("a")
    try:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        parser.error("another cleanup worker is using this output directory")
    completed = set()
    for filename in names:
        config_hash = hashlib.sha256(json.dumps(overrides.get(filename, {}), sort_keys=True).encode()).hexdigest()
        if verified_cached_record(sources[filename], args.output/"images"/filename,
                                  args.output/"records"/(Path(filename).stem+".json"), config_hash) is not None:
            completed.add(filename)
    initially_cached = len(completed)
    started = datetime.now(timezone.utc).isoformat()
    def progress(visited: int, state: str = "running") -> None:
        record = {"pid": os.getpid(), "state": state, "started_at": started,
                  "updated_at": datetime.now(timezone.utc).isoformat(),
                  "completed_candidate_frames": len(completed), "total_candidate_frames": len(names),
                  "queue_frames_visited": visited, "initial_valid_cached_frames": initially_cached,
                  "recipe": RECIPE, "model": MODEL, "accepted_exercises": 0,
                  "priority_audit": priority_context,
                  "note": "Staging only, not visual acceptance. Verify PID before treating a stale running state as active."}
        temporary = args.output/"run-state.json.tmp"
        temporary.write_text(json.dumps(record, indent=2)+"\n")
        temporary.replace(args.output/"run-state.json")
    progress(0)
    for folder in ("images", "masks", "records"):
        (args.output/folder).mkdir(exist_ok=True)
    reports, session = [], None
    for index, filename in enumerate(names, 1):
        path = sources[filename]
        source_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        config = overrides.get(filename, {})
        config_hash = hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest()
        image_path = args.output/"images"/filename
        record_path = args.output/"records"/(Path(filename).stem+".json")
        cached = verified_cached_record(path, image_path, record_path, config_hash, source_hash)
        if cached is not None:
            reports.append({**cached, "priority_audit": audit_frame_context(audit_records, filename, source_hash)})
            completed.add(filename)
            progress(index)
            print(f"{len(completed)}/{len(names)} completed; queue {index}/{len(names)} cached: {filename}", flush=True)
            continue
        if filename in completed:
            completed.remove(filename)
            progress(index-1)
        with Image.open(path) as image:
            rgba = np.array(image.convert("RGBA"))
        mask_path = args.output/"masks"/(source_hash+".png")
        start = time.monotonic()
        analysis = analyze(rgba)
        seeds, protected = config.get("remove_seeds", []), config.get("protect_seeds", [])
        unchanged = unchanged_preflight(rgba, analysis, seeds, protected)
        mask_hash = None
        if unchanged is not None:
            output, report = unchanged
        else:
            if mask_path.exists():
                with Image.open(mask_path) as image:
                    probability = np.array(image.convert("L"))
            else:
                if session is None:
                    session = load_session(args.provider, args.threads)
                matte = Image.new("RGBA", (rgba.shape[1], rgba.shape[0]), "white")
                matte.alpha_composite(Image.fromarray(rgba))
                mask = session.predict(matte.convert("RGB"))[0]
                probability = np.array(mask.convert("L"))
                mask.save(mask_path)
            output, report = cleanup(rgba, probability, seeds, protected, analysis=analysis)
            mask_hash = hashlib.sha256(mask_path.read_bytes()).hexdigest()
        Image.fromarray(output).save(image_path)
        if args.previews:
            preview(output, report, args.output/(Path(filename).stem+"-preview.png"), args.labels)
        if hashlib.sha256(path.read_bytes()).hexdigest() != source_hash:
            raise RuntimeError(f"source changed during cleanup: {path}")
        report.update({"file": filename, "source": str(path.resolve()), "source_sha256": source_hash,
                       "candidate_sha256": hashlib.sha256(image_path.read_bytes()).hexdigest(),
                       "size": [rgba.shape[1], rgba.shape[0]], "recipe": RECIPE, "model": MODEL,
                       "mask_sha256": mask_hash, "override_sha256": config_hash,
                       "priority_audit": audit_frame_context(audit_records, filename, source_hash),
                       "seconds": round(time.monotonic()-start, 3), "acceptance": "pending_visual_review"})
        temporary = record_path.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(report, indent=2)+"\n")
        temporary.replace(record_path)
        reports.append(report)
        completed.add(filename)
        progress(index)
        print(f"{len(completed)}/{len(names)} completed; queue {index}/{len(names)} staged {filename}: removed {report['removed_visible_pixels']}px; {report['seconds']}s; NOT accepted", flush=True)
    summary = {"recipe": RECIPE, "model": MODEL, "frames": len(reports),
               "changed_candidates": sum(r["removed_visible_pixels"] > 0 for r in reports),
               "originals_changed": 0, "accepted_exercises": 0,
               "inference_skipped_frames": sum(bool(r.get("inference_skipped_reason")) for r in reports),
               "priority_audit": priority_context,
               "scope": "Candidates only; background, clipping and motion still require visual review", "records": reports}
    (args.output/"background-report.json").write_text(json.dumps(summary, indent=2)+"\n")
    progress(len(names), "completed_staging_not_accepted")
    print(json.dumps({key: value for key, value in summary.items() if key != "records"}), flush=True)
    lock.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
