#!/usr/bin/env python3
"""Normalize one generated exercise frame to a deterministic transparent 1024px PNG."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat


CANVAS_SIZE = 1024
CONTENT_SIZE = 896


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def border_median(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    border = Image.new("RGB", (2 * width + 2 * height, 1))
    pixels = []
    pixels.extend(rgb.crop((0, 0, width, 1)).get_flattened_data())
    pixels.extend(rgb.crop((0, height - 1, width, height)).get_flattened_data())
    pixels.extend(rgb.crop((0, 0, 1, height)).get_flattened_data())
    pixels.extend(rgb.crop((width - 1, 0, width, height)).get_flattened_data())
    border.putdata(pixels)
    median = ImageStat.Stat(border).median
    return tuple(int(value) for value in median[:3])


def chroma_key(image: Image.Image, background: tuple[int, int, int]) -> tuple[Image.Image, Image.Image] | None:
    bg_red, bg_green, bg_blue = background
    bg_chroma = bg_green - max(bg_red, bg_blue)
    if bg_green < 160 or bg_chroma < 80:
        return None
    output = bytearray(image.width * image.height * 4)
    for index, (red, green, blue, original_alpha) in enumerate(
        image.convert("RGBA").get_flattened_data()
    ):
        chroma = max(0, green - max(red, blue))
        alpha_fraction = max(0.0, min(1.0, (bg_chroma - chroma) / max(bg_chroma - 10, 1)))
        alpha_fraction *= original_alpha / 255
        alpha = round(alpha_fraction * 255)
        if alpha_fraction > 0.015:
            inverse = 1 - alpha_fraction
            recovered = (
                round((red - inverse * bg_red) / alpha_fraction),
                round((green - inverse * bg_green) / alpha_fraction),
                round((blue - inverse * bg_blue) / alpha_fraction),
            )
            recovered = tuple(max(0, min(255, value)) for value in recovered)
            # Final despill protects partially transparent outline pixels from a green fringe.
            spill = max(0, recovered[1] - max(recovered[0], recovered[2]))
            recovered = (recovered[0], max(0, recovered[1] - spill), recovered[2])
        else:
            recovered = (0, 0, 0)
            alpha = 0
        offset = index * 4
        output[offset:offset + 4] = bytes((*recovered, alpha))
    rgba = Image.frombytes("RGBA", image.size, bytes(output))
    alpha = rgba.getchannel("A")
    # Remove isolated low-alpha compression speckles while retaining the antialiased subject edge.
    core = alpha.point(lambda value: 255 if value >= 24 else 0)
    expanded_core = core.filter(ImageFilter.MaxFilter(size=9))
    cleaned_alpha = Image.new("L", alpha.size)
    cleaned_alpha.putdata([
        value if nearby else 0
        for value, nearby in zip(alpha.get_flattened_data(), expanded_core.get_flattened_data())
    ])
    rgba.putalpha(cleaned_alpha)
    return rgba, cleaned_alpha


def derive_alpha(image: Image.Image, threshold: int) -> tuple[Image.Image, Image.Image, str]:
    existing = image.getchannel("A") if "A" in image.getbands() else None
    if existing is not None and existing.getextrema()[0] < 250:
        return image.convert("RGBA"), existing, "existing-alpha"

    rgb = image.convert("RGB")
    background = border_median(rgb)
    chroma = chroma_key(image, background)
    if chroma is not None:
        keyed, alpha = chroma
        return keyed, alpha, "chroma-green-despill"
    padded = Image.new("RGB", (rgb.width + 2, rgb.height + 2), background)
    padded.paste(rgb, (1, 1))
    sentinel = (1, 2, 3) if background != (1, 2, 3) else (253, 2, 251)
    ImageDraw.floodfill(padded, (0, 0), sentinel, thresh=threshold)
    difference = ImageChops.difference(
        padded,
        Image.new("RGB", padded.size, sentinel),
    ).convert("L")
    mask = difference.point(lambda value: 0 if value == 0 else 255)
    mask = mask.crop((1, 1, rgb.width + 1, rgb.height + 1))
    alpha = mask.filter(ImageFilter.GaussianBlur(radius=0.65))
    rgba = image.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba, alpha, "edge-connected-background"


def normalize(input_path: Path, output_path: Path, threshold: int = 42) -> dict:
    with Image.open(input_path) as loaded:
        loaded.load()
        original_mode = loaded.mode
        image = loaded.convert("RGBA")
    image, alpha, method = derive_alpha(image, threshold)
    bbox = alpha.point(lambda value: 255 if value >= 10 else 0).getbbox()
    if bbox is None:
        raise ValueError("No foreground remained after background removal")

    foreground_pixels = sum(alpha.histogram()[10:])
    occupancy = foreground_pixels / (image.width * image.height)
    if occupancy < 0.025:
        raise ValueError(f"Foreground occupancy is implausibly small: {occupancy:.4f}")
    if occupancy > 0.96:
        raise ValueError(f"Foreground occupancy is implausibly large: {occupancy:.4f}")

    left, top, right, bottom = bbox
    pad = max(4, round(max(right - left, bottom - top) * 0.025))
    crop_box = (
        max(0, left - pad),
        max(0, top - pad),
        min(image.width, right + pad),
        min(image.height, bottom + pad),
    )
    cropped = image.crop(crop_box)
    scale = min(CONTENT_SIZE / cropped.width, CONTENT_SIZE / cropped.height)
    resized_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    resized = cropped.resize(resized_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (255, 255, 255, 0))
    offset = ((CANVAS_SIZE - resized.width) // 2, (CANVAS_SIZE - resized.height) // 2)
    canvas.alpha_composite(resized, offset)

    # Transparent pixels must carry zero RGB to avoid colored fringe during interpolation/encoding.
    cleaned = bytearray()
    for red, green, blue, alpha_value in canvas.get_flattened_data():
        if alpha_value < 24 and green > 80 and blue > 80 and red < min(green, blue) * 0.55:
            cleaned.extend((0, 0, 0, 0))
        else:
            cleaned.extend((red, green, blue, alpha_value) if alpha_value else (0, 0, 0, 0))
    canvas = Image.frombytes("RGBA", canvas.size, bytes(cleaned))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=output_path.parent, suffix=".png", delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
    try:
        canvas.save(temporary_path, format="PNG", optimize=False, compress_level=9)
        os.replace(temporary_path, output_path)
        os.chmod(output_path, 0o644)
    finally:
        temporary_path.unlink(missing_ok=True)

    final_alpha = canvas.getchannel("A")
    output_path.with_name(f"{output_path.stem}.pilot{output_path.suffix}").unlink(missing_ok=True)
    final_occupancy = sum(final_alpha.histogram()[10:]) / (CANVAS_SIZE * CANVAS_SIZE)
    return {
        "input": str(input_path),
        "inputMode": original_mode,
        "inputSize": list(image.size),
        "backgroundRemoval": method,
        "cropBox": list(crop_box),
        "output": str(output_path),
        "outputSize": [CANVAS_SIZE, CANVAS_SIZE],
        "foregroundOccupancy": round(final_occupancy, 6),
        "sha256": sha256(output_path),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--threshold", type=int, default=42)
    parser.add_argument("--metadata", type=Path)
    args = parser.parse_args()
    result = normalize(args.input, args.output, args.threshold)
    if args.metadata:
        args.metadata.parent.mkdir(parents=True, exist_ok=True)
        args.metadata.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
