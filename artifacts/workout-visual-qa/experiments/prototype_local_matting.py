#!/usr/bin/env python3
"""Local-only candidate masks; never overwrite source images or app resources.

Explicitly selects MIT BiRefNet weights, not rembg's BRIA or cloud defaults.
The model changes only candidate alpha; original RGB values are retained.
Outputs are experiments and require visual review before production use.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import time
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort
from PIL import Image, ImageDraw
from rembg import new_session

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "shared" / "workout-vectors"
HERE = Path(__file__).resolve().parent
SAMPLES = [
    "Band_Skull_Crusher_male_v2_2.png",
    "Barbell_Ab_Rollout_male_v2_2.png",
    "Kipping_Muscle_Up_female_v2_2.png",
]


def composite(array: np.ndarray, color: tuple[int, int, int]) -> Image.Image:
    foreground = Image.fromarray(array)
    background = Image.new("RGBA", foreground.size, color + (255,))
    return Image.alpha_composite(background, foreground).convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="birefnet-general-lite", choices=["birefnet-general-lite", "birefnet-general", "isnet-general-use"])
    parser.add_argument("--provider", default="CPUExecutionProvider", choices=["CPUExecutionProvider", "CoreMLExecutionProvider"])
    parser.add_argument("--sample", action="append")
    parser.add_argument("--tag", default="")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--coreml-gpu", action="store_true")
    args = parser.parse_args()
    samples = args.sample or SAMPLES
    options = ort.SessionOptions()
    options.intra_op_num_threads = args.threads
    options.inter_op_num_threads = 1
    start = time.perf_counter()
    print(f"Loading local {args.model} with {args.provider}", flush=True)
    providers = [args.provider, "CPUExecutionProvider"] if args.provider != "CPUExecutionProvider" else [args.provider]
    if args.coreml_gpu:
        providers = [("CoreMLExecutionProvider", {
            "ModelFormat": "MLProgram", "MLComputeUnits": "CPUAndGPU",
            "RequireStaticInputShapes": "1",
            "ModelCacheDirectory": "/tmp/fudai-workout-matting.FCLmtL/coreml-gpu-cache",
        }), "CPUExecutionProvider"]
    session = new_session(args.model, providers=providers, sess_opts=options)
    load_seconds = time.perf_counter() - start
    print(f"Model loaded in {load_seconds:.2f}s", flush=True)
    records = []
    for filename in samples:
        source_path = SOURCE / filename
        source_bytes = source_path.read_bytes()
        before_hash = hashlib.sha256(source_bytes).hexdigest()
        rgba = np.asarray(Image.open(source_path).convert("RGBA"))
        # Present a uniform matte to the segmenter, instead of arbitrary hidden
        # RGB values from already-transparent source pixels.
        input_rgb = composite(rgba, (255, 255, 255))
        start = time.perf_counter()
        mask_image = session.predict(input_rgb)[0]
        inference_seconds = time.perf_counter() - start
        probability = np.asarray(mask_image)
        full = rgba.copy()
        full[:, :, 3] = np.minimum(rgba[:, :, 3], probability)

        rgb = rgba[:, :, :3]
        pale = ((rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2)) <= 18) & (rgb.min(axis=2) >= 185) & (rgba[:, :, 3] >= 16)
        count, labels, stats, _ = cv2.connectedComponentsWithStats(pale.astype(np.uint8), connectivity=8)
        removal = np.zeros(pale.shape, dtype=bool)
        component_decisions = []
        for label in range(1, count):
            area = int(stats[label, cv2.CC_STAT_AREA])
            if area < 16:
                continue
            component = labels == label
            fraction_low = float((probability[component] < 64).mean())
            fraction_high = float((probability[component] >= 192).mean())
            approved_candidate = fraction_low >= 0.80
            if approved_candidate:
                removal |= component
            component_decisions.append({
                "area": area, "neural_background_fraction": round(fraction_low, 4),
                "neural_foreground_fraction": round(fraction_high, 4),
                "candidate_for_removal": approved_candidate,
                "bbox": [int(stats[label, column]) for column in range(4)],
            })
        hybrid = rgba.copy()
        hybrid[removal, 3] = 0
        guarded = rgba.copy()
        guarded_removal = removal & (probability < 128)
        guarded[guarded_removal, 3] = 0
        prefix = HERE / f"{source_path.stem}-{args.model}{args.tag}"
        mask_image.save(str(prefix) + "-mask.png")
        Image.fromarray(full).save(str(prefix) + "-fullmask-candidate.png")
        Image.fromarray(hybrid).save(str(prefix) + "-hybrid-candidate.png")
        Image.fromarray(guarded).save(str(prefix) + "-guarded-candidate.png")
        composite(hybrid, (8, 8, 8)).save(str(prefix) + "-hybrid-dark.png")
        composite(guarded, (8, 8, 8)).save(str(prefix) + "-guarded-dark.png")
        preview = Image.new("RGB", (1024 * 3, 768 + 44), "#222222")
        draw = ImageDraw.Draw(preview)
        for index, (array, label) in enumerate([(rgba, "Original on dark"), (full, "Full neural mask candidate"), (hybrid, "Pale components + neural vote candidate")]):
            preview.paste(composite(array, (8, 8, 8)), (index * 1024, 44))
            draw.text((index * 1024 + 16, 12), label, fill="white")
        preview.save(str(prefix) + "-comparison.png")
        records.append({
            "file": filename, "source_sha256": before_hash,
            "source_unchanged": hashlib.sha256(source_path.read_bytes()).hexdigest() == before_hash,
            "inference_seconds": round(inference_seconds, 3),
            "model_removed_nonpale_pixels": int(((rgba[:, :, 3] >= 224) & ~pale & (probability < 64)).sum()),
            "hybrid_removed_pixels": int(removal.sum()),
            "guarded_removed_pixels": int(guarded_removal.sum()),
            "rgb_changed_pixels": int((hybrid[:, :, :3] != rgba[:, :, :3]).any(axis=2).sum()),
            "components": sorted(component_decisions, key=lambda item: item["area"], reverse=True),
            "review_status": "pending",
        })
        print(f"{filename}: {inference_seconds:.3f}s; hybrid removed {removal.sum()} pixels; source unchanged", flush=True)
    report = {"model": args.model, "providers": session.inner_session.get_providers(), "threads": args.threads, "input_shapes": [value.shape for value in session.inner_session.get_inputs()], "model_load_seconds": round(load_seconds, 3), "records": records}
    (HERE / f"local-matting-{args.model}{args.tag}.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
