# Workout illustration repair status

The user requested keeping the 875-exercise, 7,000-image illustration library,
restoring animated workout lists, and fixing backgrounds and sequence framing.
The paused rollback was undone. No workout logging, tracking, or other feature
was removed. The four iOS thumbnail animation suppressions were removed; Android
already animates its library, picker, and diary images. Reduce Motion remains respected.

## Image review

- `audit.md`, `audit.json`, and the CSVs are read-only numerical triage across the
  entire library. Candidate flags are not proof of a defect or a completed fix.
- `review-initial-exercises.md` records direct visual review of 32 frames across
  four exercises, including the squat style reference.
- `audit-visual-observations.json` records all eight Band Skull Crusher frames.
- Thus five exercises / 40 frames have a documented full visual review so far.
  Other exercises have numerical measurements, not full visual sign-off.
- None of the five visually reviewed exercises passed every background/framing
  requirement. No newly repaired exercise is accepted yet.

## Built-in-only repair constraint

The user explicitly chose built-in image editing only, declining scripted
background cleanup and alignment. That choice was respected.

Three built-in repair attempts (two male, one female Band Skull Crusher) returned
RGB 1448x1086 images containing painted checkerboards instead of real alpha.
They were rejected, preserved in `candidates/`, and never promoted to the app.
The full prompts and inspection results are recorded beside the candidates.

Image repair is blocked on obtaining a genuinely transparent, correctly framed
built-in output, or on the user authorizing a different cleanup method. No
scheduled repair jobs or background image-generation batches are running.

## Required acceptance checks for any later repair

1. Preserve the athlete, style, exercise mechanics, clothing, and equipment.
2. Verify actual alpha in every background opening, including enclosed gaps;
   a transparent outer border alone does not pass.
3. Keep real white shoe/metal highlights intact; do not blanket-remove white.
4. Inspect all four frames for shared camera, equipment scale, anchor points,
   complete uncropped anatomy, and plausible motion.
5. Inspect on both dark and light backgrounds, then verify the existing asset
   contract and byte-identical iOS copies with the sync checks.
6. Record acceptance per exercise only when all eight frames pass. Rejected
   candidates must never replace production images.
