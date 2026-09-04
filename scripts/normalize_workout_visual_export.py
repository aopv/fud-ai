#!/usr/bin/env python3
"""Normalize a generated workout cutout to the shared 1024x768 PNG contract.

This utility is intentionally narrow: it removes a connected chroma-green or
light neutral export background, preserves the isolated illustration, and
places it on a transparent 1024x768 canvas.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


CANVAS_SIZE = (1024, 768)
CONTENT_SIZE = (1000, 744)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--background",
        choices=("green", "light-neutral"),
        required=True,
        help="Connected export background to remove.",
    )
    return parser.parse_args()


def is_background(pixel: tuple[int, int, int], mode: str) -> bool:
    red, green, blue = pixel
    if mode == "green":
        return green >= 105 and green - red >= 42 and green - blue >= 42

    lightest = max(pixel)
    darkest = min(pixel)
    return darkest >= 195 and lightest - darkest <= 32


def connected_background_mask(image: Image.Image, mode: str) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()

    if mode == "green":
        # Chroma-key exports can contain isolated background islands inside
        # equipment frames, so a border flood fill is not sufficient.
        foreground = Image.new("L", (width, height), 255)
        foreground.putdata(
            [
                0
                if green >= 80
                and green - red >= 25
                and green - blue >= 25
                else 255
                for red, green, blue in rgb.get_flattened_data()
            ]
        )
        return foreground.filter(ImageFilter.GaussianBlur(radius=0.55))

    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        offset = y * width + x
        if visited[offset] or not is_background(pixels[x, y], mode):
            return
        visited[offset] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    foreground = Image.new("L", (width, height), 255)
    foreground.putdata([0 if value else 255 for value in visited])
    return foreground.filter(ImageFilter.GaussianBlur(radius=0.55))


def normalize(input_path: Path, output_path: Path, mode: str) -> None:
    with Image.open(input_path) as source:
        rgba = source.convert("RGBA")
    rgba.putalpha(connected_background_mask(rgba, mode))

    alpha = rgba.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value >= 8 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"background removal erased the complete image: {input_path}")

    cutout = rgba.crop(bounds)
    cutout.thumbnail(CONTENT_SIZE, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    x = (CANVAS_SIZE[0] - cutout.width) // 2
    y = (CANVAS_SIZE[1] - cutout.height) // 2
    canvas.alpha_composite(cutout, (x, y))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path, format="PNG", optimize=True)


def main() -> int:
    arguments = parse_arguments()
    normalize(arguments.input, arguments.output, arguments.background)
    print(f"normalized {arguments.input} -> {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
