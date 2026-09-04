# Workout illustration repair status

The user requested keeping the 875-exercise, 7,000-image illustration library,
restoring animated workout lists, and fixing backgrounds and sequence framing.
The paused rollback was undone. No workout logging, tracking, or other feature
was removed. The four iOS thumbnail animation suppressions were removed; Android
already animates its library, picker, and diary images. Reduce Motion remains respected.

## Current repair pass (2026-09-04)

The user subsequently approved non-generative background cleanup and frame
alignment. This supersedes the earlier built-in-only restriction below. Local
segmentation runs on the Mac; no workout images are uploaded and no paid image
API is used in this repair pass.

### Applied checkpoint

**2 / 875 exercises are accepted and integrated: Band Pull Apart and Band Skull
Crusher.** Sixteen exact reviewed PNGs were copied to both shared and iOS assets
(32 platform files). Post-copy SHA checks and the full 875/7,000 sync check passed.
The originals remain in Git history and in local promotion backups. No app code,
manifest, exercise IDs, instructions, logging behavior, or animation settings
were changed in this image-repair pass. No new phone build was installed.

The cleanup, matte-edge, alignment, and promotion suites currently contain
**37 passing safety tests**. Visual review is still required in addition to them.

### Full candidate pass

The remaining **6,984 frames / 873 exercises** are being staged separately at
`background-full/`. This directory is intentionally ignored by Git: unfinished
candidates must not enter app assets or repository releases. Durable progress is
in `background-full/run-state.json`, and each finished frame has a hash-keyed
record under `records/`. Confirm the recorded PID is alive before treating the
state as active; a stopped process can leave an old `running` record.

The launch on 2026-09-04 started at 12:57:32 UTC (local PID 13366). It is a local
CPU process, not a scheduled Codex task, and does not perform visual acceptance,
promotion, device installation, or unattended generation. It will pause if the
Mac sleeps. Initial full-pass samples took about 5–8 seconds per frame, so the
whole pass takes hours. This is not a promise of complete library repair when
inference finishes: source cropping, perspective, foreground protection and
frame-sequence review remain separate.

Resume the exact staging pass from the repository with the tested Python runtime
(or a new environment installed from the pinned requirements):

```sh
/tmp/fudai-workout-matting.FCLmtL/venv/bin/python scripts/repair_workout_visual_backgrounds.py \
  --exclude-exercise Band_Pull_Apart --exclude-exercise Band_Skull_Crusher \
  --output artifacts/workout-visual-qa/background-full \
  --overrides artifacts/workout-visual-qa/background-reviewed-overrides.json
```

The output-folder lock prevents duplicate workers. Existing records are reused
only when source, recipe, reviewed override, and candidate hashes match.

- The full framing scan covers **875 exercises / 1,750 gender sequences / 7,000
  frames**: `alignment-all-sequences/alignment-report.json`. It is measurement
  and triage, not 875 human visual approvals. Unknown stationary anchors cannot
  authorize automatic image changes.
- Forty existing frames have staged alpha-cleanup candidates in
  `background-pilot/`; eight recovered kneeling-rollout source crops have a
  separate cleanup/framing pass. A generated candidate is not a completed repair.
- `review-band-pull-apart-cleaned-aligned.md` accepts all eight Band Pull Apart
  frames after dark/light and motion-phase review. The corresponding one-shot
  promotion manifest pins original and candidate hashes.
- `review-band-skull-crusher-cleaned-aligned.md` accepts all eight Skull Crusher
  frames, including the recovered shoes, corrected interior gaps and conservative
  edge cleanup. Its exact reviewed set has also been applied.
- `recovery-rollout/` documents recovery of all eight complete kneeling poses,
  the standing-rollout originals, and a female Skull Crusher toe extension made
  from matching existing shoe pixels. These source repairs require cleanup and
  final framing review before promotion.
- The best eight recovered kneeling candidates are under
  `recovered-kneeling-framed-v3/`. Broad floors and bad slicing are corrected, but
  thin gray rims and tiny contact marks remain; they are **not accepted/promoted**.
- `background-reviewed-overrides.json` records manually reviewed openings that
  the semantic segmenter missed; it never identifies every white pixel as
  background. `edge-refined-pilot/` contains optional matte-edge candidates.

Only explicitly accepted full eight-frame sets may be promoted. Check each
promotion's `recovery.json` and post-copy SHA verification for actual application;
neither a review report nor an experiment directory means an app was installed.

## Scripts and safeguards

1. `scripts/repair_workout_visual_backgrounds.py` uses explicit local
   BiRefNet-general-lite votes only for existing pale components. A full model
   cutout is unsafe (it erased bench sections in trials). RGB remains identical
   and alpha may only decrease. Hash-keyed masks and per-frame records support
   restart without re-inference; outputs cannot overlap production or sources.
2. `scripts/refine_workout_matte_edges.py` optionally unmixes a white matte at
   a narrow outer rim, and removes small detached neutral specks. It can change
   rim RGB, so it needs separate visual review and supports protected regions.
3. `scripts/workout_frame_alignment.py` permits only reviewed stationary
   anchors, uniform scale/translation and one common pose-union fit. It does not
   warp limbs, force moving poses to identical boxes, or invent missing anatomy.
4. `scripts/promote_reviewed_workout_repairs.py` is read-only by default. An
   explicit apply requires a hash-linked accepted set, validates all 7,000 asset
   references/copies, backs up originals and copies identical reviewed PNG bytes
   to shared and iOS assets. Partial failures roll back this helper's own writes.

Dependencies are pinned in `scripts/requirements-workout-repair.txt`. Local test
runtime for this session: `/tmp/fudai-workout-matting.FCLmtL/venv/bin/python`.
CoreML acceleration did not work in the measured trials; CPU inference is the
verified route. Full-library inference, visual approval, and phone installation
are **not complete**.

## Initial image review

- `audit.md`, `audit.json`, and the CSVs are read-only numerical triage across the
  entire library. Candidate flags are not proof of a defect or a completed fix.
- `review-initial-exercises.md` records direct visual review of 32 frames across
  four exercises, including the squat style reference.
- `audit-visual-observations.json` records all eight Band Skull Crusher frames.
- Thus five exercises / 40 frames have a documented full visual review so far.
  Other exercises have numerical measurements, not full visual sign-off.
- None of the five original sets passed every background/framing requirement.
  New candidates and their later acceptance are tracked separately above.

## Earlier built-in-only attempts (historical)

The user explicitly chose built-in image editing only, declining scripted
background cleanup and alignment. That choice was respected.

Three built-in repair attempts (two male, one female Band Skull Crusher) returned
RGB 1448x1086 images containing painted checkerboards instead of real alpha.
They were rejected, preserved in `candidates/`, and never promoted to the app.
The full prompts and inspection results are recorded beside the candidates.

That built-in route was blocked on true alpha output. The user then authorized
the non-generative repair method described above. No scheduled background
image-generation batch is used by the new local repair scripts.

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
