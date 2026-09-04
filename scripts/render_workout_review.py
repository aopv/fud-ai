#!/usr/bin/env python3
"""Render dark/light review sheets, without changing any exercise artwork."""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--exercise", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source, output = args.input.resolve(), args.output.resolve()
    root = Path(__file__).resolve().parents[1]
    for protected in (source, root / "shared/workout-vectors", root / "ios/calorietracker/Assets.xcassets"):
        if output == protected or output.is_relative_to(protected) or protected.is_relative_to(output):
            parser.error("review output must not overlap input or canonical artwork")
    if not args.exercise or "/" in args.exercise or "\\" in args.exercise:
        parser.error("an exact exercise ID is required")
    frames = [source / f"{args.exercise}_{gender}_v2_{i}.png"
              for gender in ("male", "female") for i in range(4)]
    if any(not path.is_file() for path in frames):
        parser.error("all eight exercise frames are required")
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for gender in ("male", "female"):
        sheet = Image.new("RGB", (2048, 816), "#202020")
        draw = ImageDraw.Draw(sheet)
        for index in range(4):
            path = source / f"{args.exercise}_{gender}_v2_{index}.png"
            before = hashlib.sha256(path.read_bytes()).hexdigest()
            with Image.open(path) as image:
                image = image.convert("RGBA")
                full = Image.new("RGB", (image.width * 2, image.height))
                for row, color in enumerate(("#090909", "#eeeeee")):
                    panel = Image.new("RGBA", image.size, color)
                    panel.alpha_composite(image)
                    full.paste(panel.convert("RGB"), (row * image.width, 0))
                    sheet.paste(panel.convert("RGB").resize((512, 384), Image.Resampling.LANCZOS),
                                (index * 512, row * 408 + 24))
                    draw.text((index * 512 + 8, row * 408 + 6), f"{gender} {index} / {color}", fill="white")
                full.save(output / (path.stem + "-preview.png"))
                records.append({"file": path.name, "source_sha256": before,
                                "size": list(image.size), "alpha_extrema": list(image.getchannel("A").getextrema())})
            if hashlib.sha256(path.read_bytes()).hexdigest() != before:
                raise RuntimeError(f"source changed during review rendering: {path}")
        sheet.save(output / f"{args.exercise}_{gender}-contact.png")
    (output / "render-record.json").write_text(json.dumps({"exercise": args.exercise, "frames": records,
        "status": "rendered_for_review_not_accepted"}, indent=2) + "\n")
    print(f"Rendered 8 full dark/light previews and 2 sequence sheets in {output}")


if __name__ == "__main__":
    main()
