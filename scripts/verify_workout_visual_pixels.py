#!/usr/bin/env python3
"""Decode every workout PNG and reject empty, opaque, or solid-color exports.

Requires Pillow. Structural inventory and platform-copy checks remain in
sync_workout_visual_assets.py; this adds pixel-level checks that PNG headers
alone cannot provide.
"""

from __future__ import annotations

import sys

from PIL import Image, ImageStat

from sync_workout_visual_assets import (
    FRAME_INDICES,
    GENDERS,
    discover_sequences,
    expected_exercise_ids,
    validate_sequence_inventory,
)


def main() -> int:
    checked = 0
    try:
        sequences = discover_sequences()
        validate_sequence_inventory(sequences, expected_exercise_ids())
        for exercise_id in sorted(sequences):
            for gender in GENDERS:
                for frame in FRAME_INDICES:
                    path = sequences[exercise_id][gender][frame]
                    with Image.open(path) as source:
                        source.verify()
                    with Image.open(path) as source:
                        if source.size != (1024, 768):
                            raise ValueError(f"{path.name}: incorrect canvas size")
                        rgba = source.convert("RGBA")
                    alpha = rgba.getchannel("A")
                    minimum_alpha, maximum_alpha = alpha.getextrema()
                    if minimum_alpha != 0 or maximum_alpha < 16:
                        raise ValueError(
                            f"{path.name}: requires visible artwork and actual transparency"
                        )
                    visible = alpha.point(lambda value: 255 if value >= 16 else 0)
                    extrema = ImageStat.Stat(rgba.convert("RGB"), visible).extrema
                    if max(high - low for low, high in extrema) < 3:
                        raise ValueError(f"{path.name}: artwork is a solid-color silhouette")
                    checked += 1
    except (OSError, ValueError, KeyError) as error:
        print(f"error after {checked} images: {error}", file=sys.stderr)
        return 1

    print(f"verified {checked} PNGs: decodable, transparent, nonempty, and not solid-color masks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
