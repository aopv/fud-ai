# Workout illustration assets

This directory is the canonical source for gender-aware exercise animation frames.
The runtime manifest supports authored SVG and transparent PNG frame sets.

## Naming contract

Each complete exercise set uses:

```text
<exercise-id>_male_<version>_<frame>.<format>
<exercise-id>_female_<version>_<frame>.<format>
```

Each manifest entry contains 3–5 ordered frames with matching male and female sets.
The apps select an authored animation only when both variants and every packaged file
are complete; otherwise they retain the exercise database's existing JPEG sequence.
`exercise-visual-manifest.json` is the runtime source of truth for format, frame names,
frame count, and the representative static frame. The current production v2 PNG sets
use four frames, with the exact motion adapted to each exercise:

1. setup or neutral start
2. first action phase
3. transition, return, or maximum-range phase
4. mirrored action or controlled return phase

All v2 PNG sequences use the Barbell Full Squat visual language: realistic hand-drawn
dark ink contours, natural anatomy and cel/painterly shading, charcoal-black training
kit, restrained muted-red accents, transparent cutouts, and consistent framing weight.

Personal Info selects the male or female set. The existing `Other` convention uses
the male artwork until a dedicated inclusive visual set is designed.

## Platform packaging

- Android merges this directory into the app's flat asset root and renders authored
  SVG or PNG frames in full color. It validates all packaged filenames against the
  shared manifest before exposing a set.
- iOS compiles byte-identical copies into image sets under
  `calorietracker/Assets.xcassets` and packages a byte-identical manifest as the
  `ExerciseVisualManifest.dataset`; raw masters stay outside the iOS target to avoid
  bundling every frame twice.

The original SVG pilot is retained for comparison but is no longer referenced by the
runtime manifest. Its deterministic generator validates only those legacy SVG files
and cannot overwrite the production manifest:

```sh
python3 scripts/generate_barbell_full_squat_svg_pilot.py --check
```

After adding a complete v2 male/female PNG set, sync the iOS catalog copies and both
runtime manifests, then run the same command in validation-only mode:

```sh
python3 scripts/sync_workout_visual_assets.py
python3 scripts/sync_workout_visual_assets.py --check
```
