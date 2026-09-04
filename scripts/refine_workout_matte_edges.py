#!/usr/bin/env python3
"""Staged, non-generative removal of thin bright matte fringes.

This optional QA tool never promotes assets. It estimates edge color from the
nearest two-pixel interior and unmixes a white matte, only on neutral pale edge
pixels. Interior artwork, colors away from the outer rim, and broad real white
details remain unchanged. Review on light/dark before use: a very thin legitimate
white edge can be ambiguous, so reviewed rectangle protections are supported.
"""
import argparse
import hashlib
import json
from pathlib import Path
import cv2
import numpy as np
from scipy.ndimage import distance_transform_edt
from PIL import Image
from repair_workout_visual_backgrounds import ensure_staging, preview


def refine(rgba, protections=()):
    alpha = rgba[..., 3].astype(np.float32)/255
    visible = alpha > 0.03
    interior = cv2.erode(visible.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    if not interior.any():
        raise ValueError("no reliable interior")
    distance, indices = distance_transform_edt(~interior, return_indices=True)
    rgb = rgba[..., :3].astype(np.float32)
    foreground = rgb[indices[0], indices[1]]
    neutral = (rgb.min(axis=2) >= 180) & (np.ptp(rgb, axis=2) <= 24)
    edge = visible & ~interior & (distance <= 3) & neutral
    for left, top, right, bottom in protections:
        edge[top:bottom, left:right] = False
    difference = 255-foreground
    weights = np.maximum(difference-25, 0)
    estimated_alpha = np.sum((255-rgb)*weights, axis=2)/np.maximum(np.sum(difference*weights, axis=2), 1)
    estimated_alpha = np.clip(estimated_alpha, 0, 1)
    # Do not recolor pixels consistent with an already-opaque real light detail.
    accepted = edge & (estimated_alpha < .85) & (foreground.min(axis=2) < 170)
    output = rgba.copy()
    output[accepted, :3] = np.round(foreground[accepted]).astype(np.uint8)
    output[accepted, 3] = np.round(alpha[accepted]*estimated_alpha[accepted]*255).astype(np.uint8)
    # Remove only tiny detached neutral crumbs. Main athlete/equipment are large
    # connected regions; shoes and metal highlights inside them are not islands.
    count, labels, stats, _ = cv2.connectedComponentsWithStats((output[..., 3] > 2).astype(np.uint8), connectivity=8)
    specks = np.zeros(visible.shape, dtype=bool)
    for label in range(1, count):
        x, y, w, h, area = map(int, stats[label])
        if area > 64:
            continue
        region = labels[y:y+h, x:x+w] == label
        colors = output[y:y+h, x:x+w, :3][region].astype(np.int16)
        if np.all(np.ptp(colors, axis=1) <= 25) and np.all(colors.min(axis=1) >= 130):
            specks[y:y+h, x:x+w] |= region
    output[specks, 3] = 0
    return output, {"edge_pixels_unmatted": int(accepted.sum()), "speck_pixels_removed": int(specks.sum()),
                    "acceptance": "pending_visual_review", "regions": []}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--exercise", action="append", help="Exact exercise ID when input is a directory")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--protect", type=Path, help="JSON list of [left,top,right,bottom] edge-protection boxes")
    args = parser.parse_args()
    ensure_staging(args.output, args.input if args.input.is_dir() else args.input.parent)
    protections = json.loads(args.protect.read_text()) if args.protect else []
    args.output.mkdir(parents=True, exist_ok=True)
    paths = sorted(args.input.glob("*_v2_*.png")) if args.input.is_dir() else [args.input]
    if args.exercise:
        wanted = {f"{exercise}_{gender}_v2_{index}.png" for exercise in args.exercise for gender in ("male", "female") for index in range(4)}
        paths = [path for path in paths if path.name in wanted]
        if {path.name for path in paths} != wanted:
            parser.error("missing selected frames")
    for path in paths:
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        rgba = np.array(Image.open(path).convert("RGBA"))
        result, report = refine(rgba, protections)
        destination = args.output/path.name
        Image.fromarray(result).save(destination)
        preview(result, report, args.output/(path.stem+"-preview.png"))
        report.update({"source": str(path.resolve()), "source_sha256": before,
                       "candidate_sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
        if hashlib.sha256(path.read_bytes()).hexdigest() != before:
            raise RuntimeError(f"source changed: {path}")
        (args.output/(path.stem+"-report.json")).write_text(json.dumps(report, indent=2)+"\n")
        print(path.name, report, flush=True)


if __name__ == "__main__":
    main()
