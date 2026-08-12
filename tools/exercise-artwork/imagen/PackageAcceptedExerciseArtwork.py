#!/usr/bin/env python3
"""Create 768px alpha-WebP derivatives for complete, QA-accepted frame pairs."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import tempfile
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def accepted(item: dict) -> bool:
    return item.get("status") == "complete" and item.get("qaStatus") == "accepted"


def rgba_rmse(reference: Image.Image, derivative: Image.Image) -> float:
    resized = derivative.resize(reference.size, Image.Resampling.LANCZOS).convert("RGBA")
    difference = ImageChops.difference(reference.convert("RGBA"), resized)
    squared = 0.0
    count = reference.width * reference.height * 4
    for mean, stddev in zip(ImageStat.Stat(difference).mean, ImageStat.Stat(difference).stddev):
        squared += (stddev * stddev + mean * mean) * reference.width * reference.height
    return math.sqrt(squared / count)


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path, default=Path(__file__).with_name("jobs-v1.jsonl"))
    parser.add_argument("--state", type=Path, default=Path(__file__).with_name("state-v1.json"))
    parser.add_argument("--output-root", type=Path,
                        default=repo / "shared/exercise-artwork/fud-flat-raster-v1/packaged-768")
    parser.add_argument("--index", type=Path,
                        default=repo / "shared/exercise-artwork/fud-flat-raster-v1/packaged-768/index.json")
    parser.add_argument("--quality", type=int, default=82)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    jobs = [json.loads(line) for line in args.jobs.read_text().splitlines() if line.strip()]
    state = json.loads(args.state.read_text())["jobs"]
    grouped = defaultdict(list)
    for job in jobs:
        grouped[(job["gender"], job["exerciseID"])].append(job)
    accepted_pairs = []
    for key, pair in sorted(grouped.items()):
        pair.sort(key=lambda item: item["frameIndex"])
        if len(pair) == 2 and all(accepted(state[job["jobID"]]) for job in pair):
            accepted_pairs.append((key, pair))
    if args.dry_run:
        print(f"Would package {len(accepted_pairs)} accepted two-frame pairs")
        return

    entries = []
    for (gender, exercise_id), pair in accepted_pairs:
        frames = []
        for job in pair:
            master = repo / job["outputPath"]
            if not master.is_file() or sha256(master) != state[job["jobID"]]["outputSHA256"]:
                raise SystemExit(f"Accepted master missing or changed: {job['jobID']}")
            with Image.open(master) as loaded:
                source = loaded.convert("RGBA")
            derivative = source.resize((768, 768), Image.Resampling.LANCZOS)
            destination = (args.output_root / "frames" / gender / exercise_id
                           / f"{job['frameIndex']}.webp")
            destination.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=destination.parent, suffix=".webp", delete=False) as temp:
                temporary = Path(temp.name)
            try:
                derivative.save(temporary, "WEBP", quality=args.quality, method=6, exact=True)
                with Image.open(temporary) as check:
                    decoded = check.convert("RGBA")
                if decoded.size != (768, 768) or decoded.getchannel("A").getextrema()[0] != 0:
                    raise SystemExit(f"WebP alpha/dimension gate failed: {job['jobID']}")
                rmse = rgba_rmse(source, decoded)
                if rmse > 18.0:
                    raise SystemExit(f"WebP visual RMSE {rmse:.2f} too high: {job['jobID']}")
                if temporary.stat().st_size >= master.stat().st_size:
                    raise SystemExit(f"WebP is not smaller than PNG master: {job['jobID']}")
                os.replace(temporary, destination)
                os.chmod(destination, 0o644)
            finally:
                temporary.unlink(missing_ok=True)
            frames.append({
                "frameIndex": job["frameIndex"], "jobID": job["jobID"],
                "path": str(destination.relative_to(repo)), "sha256": sha256(destination),
                "bytes": destination.stat().st_size, "masterBytes": master.stat().st_size,
                "rgbaRMSE": round(rmse, 4),
            })
        entries.append({"gender": gender, "exerciseID": exercise_id, "frames": frames})
    index = {"schemaVersion": 1, "style": "fud-flat-raster-v1", "size": 768,
             "format": "webp", "quality": args.quality, "pairCount": len(entries),
             "entries": entries}
    args.index.parent.mkdir(parents=True, exist_ok=True)
    args.index.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n")
    os.chmod(args.index, 0o644)
    total_bytes = sum(frame["bytes"] for entry in entries for frame in entry["frames"])
    master_bytes = sum(frame["masterBytes"] for entry in entries for frame in entry["frames"])
    print(f"Packaged {len(entries)} pairs: {total_bytes} bytes (masters {master_bytes} bytes)")


if __name__ == "__main__":
    main()
