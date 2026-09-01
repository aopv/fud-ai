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
frame count, and the representative static frame. The current production v2 PNG set
uses four frames:

1. standing start
2. controlled descent
3. bottom position
4. ascent

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
