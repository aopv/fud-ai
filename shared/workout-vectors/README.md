# Workout vector assets

This directory is the canonical source for gender-aware exercise animation frames.
The assets are original Fud AI artwork and contain vector primitives only.

## Naming contract

Each complete exercise set uses:

```text
<exercise-id>_male_<frame>.svg
<exercise-id>_female_<frame>.svg
```

Frame numbering starts at `0`, remains contiguous, contains 3–5 frames, and must
match between the male and female variants. The apps select a vector animation only
when both variants are complete; otherwise they retain the exercise database's
existing JPEG sequence. `exercise-visual-manifest.json` is the runtime source of
truth for frame names, frame count, and the representative static frame. The current
production pilot uses four frames:

1. standing start
2. controlled descent
3. bottom position
4. ascent

Personal Info selects the male or female set. The existing `Other` convention uses
the male artwork until a dedicated inclusive visual set is designed.

## Platform packaging

- Android merges this directory into the app's flat asset root and renders the SVGs
  directly with Coil's SVG decoder. It validates the packaged SVG filenames against
  the shared manifest before exposing a vector set.
- iOS compiles byte-identical copies into vector-preserving image sets under
  `calorietracker/Assets.xcassets` and packages a byte-identical manifest as the
  `ExerciseVisualManifest.dataset`; raw masters stay outside the iOS target to avoid
  bundling every frame twice.

Run the exercise generator with `--check` before committing to validate XML,
transparency, view boxes, frame registration, prohibited raster/external content,
and iOS catalog parity.

```sh
python3 scripts/generate_barbell_full_squat_svg_pilot.py --check
```
