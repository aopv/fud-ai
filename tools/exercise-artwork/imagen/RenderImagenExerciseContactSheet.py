#!/usr/bin/env python3
"""Render source/reference/output columns for visual QA or accepted-pair evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tile(path: Path, label: str, size: tuple[int, int]) -> Image.Image:
    result = Image.new("RGB", size, (242, 244, 247))
    draw = ImageDraw.Draw(result)
    if path.is_file():
        with Image.open(path) as loaded:
            image = loaded.convert("RGBA")
        backing = Image.new("RGBA", image.size, (255, 255, 255, 255))
        backing.alpha_composite(image)
        backing.thumbnail((size[0] - 12, size[1] - 34), Image.Resampling.LANCZOS)
        result.paste(backing.convert("RGB"), ((size[0] - backing.width) // 2, 24))
    else:
        draw.rectangle((8, 28, size[0] - 8, size[1] - 8), outline=(190, 194, 202), width=2)
        draw.text((size[0] // 2 - 24, size[1] // 2), "PENDING", fill=(120, 124, 132))
    draw.rectangle((0, 0, size[0], 23), fill=(30, 32, 38))
    draw.text((6, 5), label, fill="white", font=ImageFont.load_default())
    return result


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path, default=Path(__file__).with_name("jobs-v1.jsonl"))
    parser.add_argument("--state", type=Path, default=Path(__file__).with_name("state-v1.json"))
    parser.add_argument(
        "--package-index",
        type=Path,
        default=repo / "shared/exercise-artwork/fud-flat-raster-v1/packaged-768/index.json",
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--pilot-only", action="store_true")
    parser.add_argument(
        "--accepted-only",
        action="store_true",
        help="Render only complete, accepted two-frame gender pairs in a compact four-column sheet.",
    )
    parser.add_argument("--limit", type=int, default=24)
    args = parser.parse_args()
    if args.pilot_only and args.accepted_only:
        parser.error("--pilot-only and --accepted-only are mutually exclusive")
    if args.output is None:
        filename = (
            "imagen-accepted-comparison-sheet.png"
            if args.accepted_only
            else "imagen-pilot-contact-sheet.png"
        )
        args.output = repo / "tools/exercise-artwork/previews" / filename
    jobs = [json.loads(line) for line in args.jobs.read_text().splitlines() if line.strip()]
    by_key = {(job["exerciseID"], job["frameIndex"], job["gender"]): job for job in jobs}
    if args.accepted_only:
        states = json.loads(args.state.read_text())["jobs"]
        package_entries = json.loads(args.package_index.read_text())["entries"]
        pairs = []
        for entry in sorted(package_entries, key=lambda item: (item["exerciseID"], item["gender"])):
            exercise_id, gender = entry["exerciseID"], entry["gender"]
            package_frames = sorted(entry["frames"], key=lambda item: item["frameIndex"])
            if [frame["frameIndex"] for frame in package_frames] != [0, 1]:
                raise SystemExit(f"Packaged entry is not a two-frame pair: {exercise_id}/{gender}")
            for package_frame in package_frames:
                frame_index = package_frame["frameIndex"]
                job = by_key[(exercise_id, frame_index, gender)]
                state = states[job["jobID"]]
                source = repo / job["sourceImagePath"]
                master = repo / job["outputPath"]
                packaged = repo / package_frame["path"]
                checks = (
                    state.get("status") == "complete",
                    state.get("qaStatus") == "accepted",
                    source.is_file() and sha256(source) == job["sourceImageSHA256"],
                    master.is_file() and sha256(master) == state.get("outputSHA256"),
                    packaged.is_file() and sha256(packaged) == package_frame["sha256"],
                )
                if not all(checks):
                    raise SystemExit(f"Accepted-sheet provenance failed: {job['jobID']}")
            pairs.append((exercise_id, gender, package_frames))
        pairs = pairs[:args.limit]
        width, row_height, label_width, tile_width = 1010, 210, 190, 205
        sheet = Image.new("RGB", (width, 46 + len(pairs) * row_height), (18, 19, 22))
        draw = ImageDraw.Draw(sheet)
        headers = ("Exact source 0", "Exact source 1", "Accepted 0", "Accepted 1")
        draw.text((10, 14), "Exercise / gender", fill="white")
        for index, header in enumerate(headers):
            draw.text((label_width + index * tile_width + 8, 14), header, fill="white")
        for row, (exercise_id, gender, package_frames) in enumerate(pairs):
            y = 46 + row * row_height
            draw.text((8, y + 16), exercise_id[:27], fill=(235, 237, 242))
            draw.text((8, y + 34), gender, fill=(255, 104, 132))
            frame0 = by_key[(exercise_id, 0, gender)]
            frame1 = by_key[(exercise_id, 1, gender)]
            entries = [
                (repo / frame0["sourceImagePath"], "legacy endpoint 0"),
                (repo / frame1["sourceImagePath"], "legacy endpoint 1"),
                (repo / package_frames[0]["path"], f"shipped {gender} / 0"),
                (repo / package_frames[1]["path"], f"shipped {gender} / 1"),
            ]
            for column, (path, label) in enumerate(entries):
                sheet.paste(tile(path, label, (195, 195)), (label_width + column * tile_width, y + 5))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(args.output, optimize=False, compress_level=9)
        print(f"Wrote {len(pairs)} accepted gender-pair rows to {args.output}")
        return

    ids = sorted({job["exerciseID"] for job in jobs
                  if (job["pilot"] if args.pilot_only else True)})[:args.limit]
    width, row_height, label_width, tile_width = 1470, 210, 190, 205
    sheet = Image.new("RGB", (width, 46 + len(ids) * row_height), (18, 19, 22))
    draw = ImageDraw.Draw(sheet)
    headers = ("Source 0", "Source 1", "Male 0", "Male 1", "Female 0", "Female 1")
    draw.text((10, 14), "Exercise", fill="white")
    for index, header in enumerate(headers):
        draw.text((label_width + index * tile_width + 8, 14), header, fill="white")
    for row, exercise_id in enumerate(ids):
        y = 46 + row * row_height
        draw.text((8, y + 16), exercise_id[:28], fill=(235, 237, 242))
        source0 = by_key[(exercise_id, 0, "male")]
        source1 = by_key[(exercise_id, 1, "male")]
        entries = [
            (repo / source0["sourceImagePath"], "legacy endpoint 0"),
            (repo / source1["sourceImagePath"], "legacy endpoint 1"),
            (repo / by_key[(exercise_id, 0, "male")]["outputPath"], "male / 0"),
            (repo / by_key[(exercise_id, 1, "male")]["outputPath"], "male / 1"),
            (repo / by_key[(exercise_id, 0, "female")]["outputPath"], "female / 0"),
            (repo / by_key[(exercise_id, 1, "female")]["outputPath"], "female / 1"),
        ]
        for column, (path, label) in enumerate(entries):
            sheet.paste(tile(path, label, (195, 195)), (label_width + column * tile_width, y + 5))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, optimize=False, compress_level=9)
    print(f"Wrote {len(ids)} exercise rows to {args.output}")


if __name__ == "__main__":
    main()
