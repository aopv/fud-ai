#!/usr/bin/env python3
"""Validate and package generated v2 workout illustration sequences."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import struct
import sys
from collections import defaultdict
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SHARED_DIRECTORY = REPOSITORY_ROOT / "shared" / "workout-vectors"
IOS_CATALOG = REPOSITORY_ROOT / "ios" / "calorietracker" / "Assets.xcassets"
SHARED_MANIFEST = SHARED_DIRECTORY / "exercise-visual-manifest.json"
IOS_MANIFEST = (
    IOS_CATALOG
    / "ExerciseVisualManifest.dataset"
    / "exercise-visual-manifest.json"
)
FRAME_COUNT = 4
FRAME_INDICES = tuple(range(FRAME_COUNT))
GENDERS = ("male", "female")
ASSET_PATTERN = re.compile(
    r"^(?P<exercise_id>.+)_(?P<gender>male|female)_v2_(?P<frame>[0-9]+)\.png$"
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate packaging and manifests without writing files.",
    )
    return parser.parse_args()


def png_metadata(asset: Path) -> tuple[int, int, bool]:
    data = asset.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"not a PNG: {asset.relative_to(REPOSITORY_ROOT)}")

    offset = len(PNG_SIGNATURE)
    width = height = color_type = None
    has_transparency_chunk = False
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk_data = data[offset + 8 : offset + 8 + length]
        if len(chunk_data) != length:
            raise ValueError(f"truncated PNG: {asset.relative_to(REPOSITORY_ROOT)}")
        if chunk_type == b"IHDR":
            width, height, _, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk_data)
        elif chunk_type == b"tRNS":
            has_transparency_chunk = True
        elif chunk_type == b"IEND":
            break
        offset += 12 + length

    if width is None or height is None or color_type is None:
        raise ValueError(f"missing PNG header: {asset.relative_to(REPOSITORY_ROOT)}")
    has_alpha = color_type in (4, 6) or has_transparency_chunk
    return width, height, has_alpha


def imageset_contents(filename: str) -> dict[str, object]:
    return {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }


def serialized_json(document: object, *, compact: bool = False) -> str:
    if compact:
        return json.dumps(document, separators=(",", ":")) + "\n"
    return json.dumps(document, indent=2) + "\n"


def discover_sequences() -> dict[str, dict[str, dict[int, Path]]]:
    sequences: dict[str, dict[str, dict[int, Path]]] = defaultdict(
        lambda: defaultdict(dict)
    )
    for asset in sorted(SHARED_DIRECTORY.glob("*_v2_*.png")):
        match = ASSET_PATTERN.fullmatch(asset.name)
        if match is None:
            raise ValueError(f"invalid v2 asset name: {asset.name}")
        frame = int(match.group("frame"))
        exercise_id = match.group("exercise_id")
        gender = match.group("gender")
        if frame in sequences[exercise_id][gender]:
            raise ValueError(f"duplicate frame: {asset.name}")
        sequences[exercise_id][gender][frame] = asset
    if not sequences:
        raise ValueError("no v2 workout illustration sequences found")
    return sequences


def validate_sequence(
    exercise_id: str,
    by_gender: dict[str, dict[int, Path]],
) -> None:
    if set(by_gender) != set(GENDERS):
        raise ValueError(f"{exercise_id}: male and female sets must both be present")
    for gender in GENDERS:
        frames = by_gender[gender]
        if set(frames) != set(FRAME_INDICES):
            raise ValueError(
                f"{exercise_id} {gender}: expected frames {FRAME_INDICES}, "
                f"found {tuple(sorted(frames))}"
            )
        for frame in FRAME_INDICES:
            asset = frames[frame]
            width, height, has_alpha = png_metadata(asset)
            if (width, height) != (1024, 768):
                raise ValueError(
                    f"{asset.name}: expected 1024x768, found {width}x{height}"
                )
            if not has_alpha:
                raise ValueError(f"{asset.name}: PNG has no alpha channel")


def sync_ios_asset(asset: Path, *, check: bool) -> None:
    imageset = IOS_CATALOG / f"{asset.stem}.imageset"
    ios_asset = imageset / asset.name
    contents_path = imageset / "Contents.json"
    expected_contents = serialized_json(imageset_contents(asset.name), compact=True)

    if check:
        if not ios_asset.is_file() or ios_asset.read_bytes() != asset.read_bytes():
            raise ValueError(f"iOS asset differs or is missing: {ios_asset.name}")
        if not contents_path.is_file() or contents_path.read_text() != expected_contents:
            raise ValueError(
                f"iOS Contents.json differs or is missing: "
                f"{contents_path.relative_to(REPOSITORY_ROOT)}"
            )
        return

    imageset.mkdir(parents=True, exist_ok=True)
    if not ios_asset.is_file() or ios_asset.read_bytes() != asset.read_bytes():
        shutil.copyfile(asset, ios_asset)
    if not contents_path.is_file() or contents_path.read_text() != expected_contents:
        contents_path.write_text(expected_contents)


def manifest_document(
    sequences: dict[str, dict[str, dict[int, Path]]],
) -> dict[str, object]:
    entries: list[dict[str, object]] = []
    for exercise_id in sorted(sequences):
        entries.append(
            {
                "exerciseId": exercise_id,
                "format": "png",
                "femaleFrames": [
                    sequences[exercise_id]["female"][frame].stem
                    for frame in FRAME_INDICES
                ],
                "frameCount": FRAME_COUNT,
                "maleFrames": [
                    sequences[exercise_id]["male"][frame].stem
                    for frame in FRAME_INDICES
                ],
                "representativeFrameIndex": 2,
            }
        )
    return {"exercises": entries, "schemaVersion": 1}


def sync_manifest(document: dict[str, object], *, check: bool) -> None:
    expected = serialized_json(document)
    for manifest in (SHARED_MANIFEST, IOS_MANIFEST):
        if check:
            if not manifest.is_file() or manifest.read_text() != expected:
                raise ValueError(
                    f"manifest is out of date: {manifest.relative_to(REPOSITORY_ROOT)}"
                )
        elif not manifest.is_file() or manifest.read_text() != expected:
            manifest.write_text(expected)


def main() -> int:
    arguments = parse_arguments()
    try:
        sequences = discover_sequences()
        for exercise_id, by_gender in sequences.items():
            validate_sequence(exercise_id, by_gender)
            for gender in GENDERS:
                for frame in FRAME_INDICES:
                    sync_ios_asset(by_gender[gender][frame], check=arguments.check)
        sync_manifest(manifest_document(sequences), check=arguments.check)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    mode = "validated" if arguments.check else "synced"
    print(
        f"{mode} {len(sequences)} exercise sequences, "
        f"{len(sequences) * len(GENDERS) * FRAME_COUNT} PNG assets"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
