#!/usr/bin/env python3
"""Import the authoritative 875 workout illustration sequences.

The importer deliberately selects only the eight canonical files for each
exercise. Existing complete repository sequences take precedence, followed by
archived wave outputs, then complete batch outputs for the remaining IDs.
Every source is validated before any destination file is changed.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from sync_workout_visual_assets import (
    EXPECTED_ASSET_COUNT,
    EXPECTED_EXERCISE_COUNT,
    FRAME_INDICES,
    GENDERS,
    SHARED_DIRECTORY,
    expected_exercise_ids,
    png_metadata,
)


DEFAULT_WAVE_REGISTRY = Path.home() / "workout-art-waves" / "wave-registry.json"
DEFAULT_BATCH_ROOT = Path.home() / "workout-art-batches"


@dataclass(frozen=True)
class SequenceSource:
    exercise_id: str
    directory: Path
    provenance: str


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--wave-registry",
        type=Path,
        default=DEFAULT_WAVE_REGISTRY,
        help=f"Archived wave registry (default: {DEFAULT_WAVE_REGISTRY})",
    )
    parser.add_argument(
        "--batch-root",
        type=Path,
        default=DEFAULT_BATCH_ROOT,
        help=f"Batch export root (default: {DEFAULT_BATCH_ROOT})",
    )
    parser.add_argument(
        "--destination",
        type=Path,
        default=SHARED_DIRECTORY,
        help=f"Canonical shared destination (default: {SHARED_DIRECTORY})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and report the complete import plan without copying.",
    )
    return parser.parse_args()


def canonical_filenames(exercise_id: str) -> tuple[str, ...]:
    return tuple(
        f"{exercise_id}_{gender}_v2_{frame}.png"
        for gender in GENDERS
        for frame in FRAME_INDICES
    )


def has_complete_sequence(directory: Path, exercise_id: str) -> bool:
    return all(
        (directory / filename).is_file()
        for filename in canonical_filenames(exercise_id)
    )


def validate_source(source: SequenceSource) -> None:
    for filename in canonical_filenames(source.exercise_id):
        asset = source.directory / filename
        if not asset.is_file():
            raise ValueError(
                f"{source.provenance} sequence is incomplete for "
                f"{source.exercise_id}: missing {asset}"
            )
        width, height, has_alpha = png_metadata(asset)
        if (width, height) != (1024, 768):
            raise ValueError(
                f"{asset}: expected 1024x768, found {width}x{height}"
            )
        if not has_alpha:
            raise ValueError(f"{asset}: PNG has no alpha channel")


def repository_sources(
    destination: Path,
    expected_ids: set[str],
) -> dict[str, SequenceSource]:
    sources: dict[str, SequenceSource] = {}
    for exercise_id in sorted(expected_ids):
        if has_complete_sequence(destination, exercise_id):
            sources[exercise_id] = SequenceSource(
                exercise_id, destination, "repository"
            )
    return sources


def archived_wave_sources(
    registry_path: Path,
    expected_ids: set[str],
) -> dict[str, SequenceSource]:
    registry = json.loads(registry_path.read_text())
    if not isinstance(registry, dict):
        raise ValueError("wave registry root must be an object")
    tasks = registry.get("archivedCompletedTasks")
    if not isinstance(tasks, list):
        raise ValueError("wave registry archivedCompletedTasks must be an array")
    sources: dict[str, SequenceSource] = {}
    for index, task in enumerate(tasks):
        if not isinstance(task, dict):
            raise ValueError(f"archived task {index} must be an object")
        exercise_id = task.get("exerciseId")
        staging_value = task.get("stagingPath")
        if not isinstance(exercise_id, str) or not exercise_id:
            raise ValueError(f"archived task {index} has no valid exerciseId")
        if exercise_id not in expected_ids:
            raise ValueError(
                f"archived task has unknown exercise id: {exercise_id}"
            )
        if exercise_id in sources:
            raise ValueError(
                f"duplicate archived task for exercise id: {exercise_id}"
            )
        if not isinstance(staging_value, str) or not staging_value:
            raise ValueError(
                f"archived task {exercise_id} has no valid stagingPath"
            )

        staging_path = Path(staging_value).expanduser()
        shared_path = staging_path / "shared"
        source_directory = (
            shared_path
            if has_complete_sequence(shared_path, exercise_id)
            else staging_path
        )
        if not has_complete_sequence(source_directory, exercise_id):
            raise ValueError(
                f"archived task sequence is incomplete for {exercise_id}: "
                f"{source_directory}"
            )
        sources[exercise_id] = SequenceSource(
            exercise_id, source_directory, "archived-wave"
        )
    return sources


def complete_batch_sources(
    batch_root: Path,
    required_ids: set[str],
) -> dict[str, SequenceSource]:
    sources: dict[str, SequenceSource] = {}
    if not required_ids:
        return sources

    batch_directories = sorted(batch_root.glob("batch-*/shared"))
    if not batch_directories:
        raise ValueError(f"no batch shared directories found under {batch_root}")

    for directory in batch_directories:
        for exercise_id in sorted(required_ids - set(sources)):
            if has_complete_sequence(directory, exercise_id):
                sources[exercise_id] = SequenceSource(
                    exercise_id, directory, "batch"
                )
        if len(sources) == len(required_ids):
            break
    return sources


def build_import_plan(
    destination: Path,
    registry_path: Path,
    batch_root: Path,
) -> dict[str, SequenceSource]:
    expected_ids = expected_exercise_ids()
    plan = repository_sources(destination, expected_ids)
    if set(plan) == expected_ids:
        # A complete checkout is self-contained; archived workstation exports
        # are only needed when reconstructing missing sequences.
        return plan

    wave_sources = archived_wave_sources(registry_path, expected_ids)
    for exercise_id in sorted(expected_ids - set(plan)):
        source = wave_sources.get(exercise_id)
        if source is not None:
            plan[exercise_id] = source

    remaining_ids = expected_ids - set(plan)
    plan.update(complete_batch_sources(batch_root, remaining_ids))
    missing_ids = expected_ids - set(plan)
    if missing_ids:
        preview = ", ".join(sorted(missing_ids)[:12])
        if len(missing_ids) > 12:
            preview += f", ... (+{len(missing_ids) - 12} more)"
        raise ValueError(
            f"no complete authoritative source for {len(missing_ids)} exercises: "
            f"{preview}"
        )
    if len(plan) != EXPECTED_EXERCISE_COUNT:
        raise ValueError(
            f"import plan must contain {EXPECTED_EXERCISE_COUNT} exercises, "
            f"found {len(plan)}"
        )
    return plan


def validate_plan(plan: dict[str, SequenceSource]) -> None:
    for exercise_id in sorted(plan):
        validate_source(plan[exercise_id])

    planned_asset_count = sum(
        len(canonical_filenames(exercise_id)) for exercise_id in plan
    )
    if planned_asset_count != EXPECTED_ASSET_COUNT:
        raise ValueError(
            f"import plan must contain {EXPECTED_ASSET_COUNT} assets, "
            f"found {planned_asset_count}"
        )


def copy_plan(plan: dict[str, SequenceSource], destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for exercise_id in sorted(plan):
        source = plan[exercise_id]
        for filename in canonical_filenames(exercise_id):
            source_path = source.directory / filename
            destination_path = destination / filename
            if source_path.resolve() == destination_path.resolve():
                continue
            if (
                destination_path.is_file()
                and destination_path.read_bytes() == source_path.read_bytes()
            ):
                continue
            shutil.copy2(source_path, destination_path)


def validate_destination(plan: dict[str, SequenceSource], destination: Path) -> None:
    expected_names = {
        filename
        for exercise_id in plan
        for filename in canonical_filenames(exercise_id)
    }
    actual_names = {asset.name for asset in destination.glob("*_v2_*.png")}
    if actual_names != expected_names:
        missing = expected_names - actual_names
        unexpected = actual_names - expected_names
        details: list[str] = []
        if missing:
            details.append(f"missing {len(missing)} canonical files")
        if unexpected:
            details.append(f"unexpected {len(unexpected)} canonical files")
        raise ValueError("destination corpus mismatch: " + "; ".join(details))
    if len(actual_names) != EXPECTED_ASSET_COUNT:
        raise ValueError(
            f"destination must contain {EXPECTED_ASSET_COUNT} canonical files, "
            f"found {len(actual_names)}"
        )


def main() -> int:
    arguments = parse_arguments()
    try:
        plan = build_import_plan(
            arguments.destination.expanduser(),
            arguments.wave_registry.expanduser(),
            arguments.batch_root.expanduser(),
        )
        validate_plan(plan)
        if not arguments.dry_run:
            copy_plan(plan, arguments.destination.expanduser())
            validate_destination(plan, arguments.destination.expanduser())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    counts = Counter(source.provenance for source in plan.values())
    mode = "validated import plan for" if arguments.dry_run else "imported"
    print(
        f"{mode} {len(plan)} exercise sequences, {EXPECTED_ASSET_COUNT} PNG assets "
        f"(repository={counts['repository']}, "
        f"archived-wave={counts['archived-wave']}, batch={counts['batch']})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
