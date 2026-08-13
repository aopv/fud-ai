# Imagen exercise artwork pipeline

This directory turns the canonical 875-record FreeExerciseDB library into 3,500 independent,
resumable Imagen jobs: two endpoint frames for each exercise, for both male and female characters.
Each job produces exactly one image. The approved character sheet is supplied first and the exact
legacy endpoint photo second as two separate references to that one generation call.

Schema v2 optionally expands each gender/exercise into six ordered frames. Frame `0` and frame `5`
are the exact immutable legacy endpoints; frames `1`-`4` are separately generated in-betweens at
`t=0.2, 0.4, 0.6, 0.8`. The default builder remains the two-frame v1 mode. A v2 manifest is created
only with `--sequence-frames 6`, and it must be activated through the explicit endpoint migration
described below—never by overwriting the current queue directly.

## Canonical assets and schema

- Character sheets: `shared/exercise-artwork/fud-flat-raster-v1/references/{male|female}.png`
- Accepted normalized PNG masters: `shared/exercise-artwork/fud-flat-raster-v1/frames/<gender>/<exerciseID>/<0|1>.png`
- Accepted app derivatives: `shared/exercise-artwork/fud-flat-raster-v1/packaged-768/frames/<gender>/<exerciseID>/<0|1>.webp`
- Jobs: `tools/exercise-artwork/imagen/jobs-v1.jsonl`
- Mutable queue state: `tools/exercise-artwork/imagen/state-v1.json`
- Manual review ledger: `tools/exercise-artwork/imagen/manual-reviews-v1.json`
- Current visual QA sheet: `tools/exercise-artwork/previews/imagen-pilot-contact-sheet.png`

Every JSONL record has this stable shape:

```json
{
  "schemaVersion": 1,
  "style": "fud-flat-raster-v1",
  "jobID": "<exerciseID>__f<0|1>__<male|female>",
  "exerciseID": "canonical FreeExerciseDB ID",
  "exerciseName": "display name",
  "equipment": "source equipment value",
  "frameIndex": 0,
  "gender": "female",
  "width": 1024,
  "height": 1024,
  "sourceImagePath": "exact legacy JPG",
  "sourceImageSHA256": "...",
  "characterReferencePath": "approved character PNG",
  "characterReferenceSHA256": "...",
  "outputPath": "canonical normalized PNG",
  "prompt": "deterministic one-output prompt",
  "pilot": false,
  "sourceReferenceQA": {"status": "ready", "reason": null},
  "jobFingerprint": "..."
}
```

Six-frame jobs use `schemaVersion: 2` and add a self-describing `sequence` object with
`frameCount: 6`, contiguous `frameIndex: 0...5`, role `endpoint` or `inbetween`, interpolation `t`,
and endpoint indices `[0, 5]`. `sourceEndpointReferences` contains both exact immutable endpoint
paths and hashes. Endpoint jobs retain `sourceImagePath` for compatibility. In-between worker
payloads contain three ordered inputs: locked character, exact endpoint 0, exact endpoint 5. Every
call still produces exactly one output.

IDs are already filesystem-safe (`[A-Za-z0-9_-]+`) and are never renamed or sanitized. Jobs are
sorted by `jobID`; the builder emits exact input hashes and preserves state only while a job's
fingerprint is unchanged.

## Commands

```sh
python3 tools/exercise-artwork/imagen/BuildImagenExerciseJobs.py
python3 tools/exercise-artwork/imagen/ExerciseArtworkQueue.py status
python3 tools/exercise-artwork/imagen/ExerciseArtworkQueue.py migrate-provenance
python3 tools/exercise-artwork/imagen/ExerciseArtworkQueue.py claim \
  --worker <worker-id> --gender female --pilot-only

# Or claim one exact assigned job:
python3 tools/exercise-artwork/imagen/ExerciseArtworkQueue.py claim \
  --worker <worker-id> --job-id '<exerciseID>__f0__male'
```

Inspect the whole-library endpoint migration without changing canonical files:

```sh
python3 tools/exercise-artwork/imagen/MigrateEndpointQueueToSequences.py
```

The default dry-run builds v2 entirely in a temporary directory and reports the plan. After review,
`--apply` remaps legacy `f0` to v2 `f0`, legacy `f1` to v2 `f5`, and moves canonical raw/master
`1.png` evidence to `5.png` with unchanged hashes. It recursively updates embedded job IDs in state,
manual review, and QA report payloads. Frames `1`-`4` start pending. Accepted, rejected, pending,
orphaned, and blocked endpoint evidence is retained; no endpoint decision is inherited by an
intermediate. The new manifest/state/review/report becomes visible only after frame-5 evidence is
materialized and verified.

The claim command prints the complete job JSON. Call Imagen once with `characterReferencePath`
first and `sourceImagePath` second, and request one output only. Do not merge the two references
into a collage. The requested background is uniform `#00FF00`, with no shadow, gradient, texture,
floor, or reflection. Save the untouched result outside the canonical frame tree, then run:

```sh
python3 tools/exercise-artwork/imagen/ExerciseArtworkQueue.py complete \
  --job-id '<jobID>' --input '/absolute/path/to/raw-result.png'
```

`complete` performs deterministic chroma removal and green despill, crops the foreground, fits it
inside a transparent 1024x1024 canvas, writes the canonical PNG atomically, and advances the job to
`completed_pending_qa`. Use `fail` to record an error and `release` to return a failed/claimed job
to the queue. Queue mutations use an advisory lock and atomic state replacement, so male and female
workers can run concurrently without clobbering progress.

Untouched generation results are working files, not repository assets. Keep them under
`shared/exercise-artwork/fud-flat-raster-v1/raw/` (or another external absolute path); the canonical
raw directory and common temporary-result suffixes are ignored by Git. Queue state records each
`generatedInputPath` as a repository-relative canonical raw path, plus attempt history,
normalized-output hash, and QA result. `complete` and `record-rejected` copy external Imagen results
into that canonical raw tree before updating state, so committed provenance never exposes a local
home directory. The builder resolves these relative paths from the repository root when deciding
whether a prompt-only change can be revalidated. After review, retain a
PNG in the canonical `frames/` tree only when that individual job is `complete` and `accepted`.
Rejected or still-pending normalized pilots should be removed from commit scope; their raw input,
queue history, QA report, and contact sheet preserve the evidence needed to regenerate or audit them.

## QA and acceptance

Structural and pose QA uses Pillow plus MediaPipe Pose Landmarker Heavy. The model is supplied at
runtime and is not committed. The existing reproducible environment is `/tmp/fud-pose-venv`; the
model used during development is `/tmp/pose_landmarker_heavy.task`.

```sh
/tmp/fud-pose-venv/bin/python \
  tools/exercise-artwork/imagen/ValidateImagenExerciseArtwork.py \
  --model /tmp/pose_landmarker_heavy.task --allow-missing

python3 tools/exercise-artwork/imagen/RenderImagenExerciseContactSheet.py --pilot-only
python3 tools/exercise-artwork/imagen/RenderImagenExerciseContactSheet.py --accepted-only
```

Automatic checks require a valid 1024px transparent PNG, sensible foreground occupancy and edge
clearance, an output pose confidence of at least 0.55, bounded normalized pose error, bounded torso
and limb-angle errors, and no left/right swap. Edge-layout similarity is reported as a warning-only
diagnostic because the source is photography and the output is flat artwork.

For schema v2, endpoints keep every exact-source threshold unchanged. An intermediate is compared
with those same pose thresholds against deterministic linear interpolation of normalized exact
endpoint landmarks. Manual review additionally requires `intermediatePoseApproved` for temporal,
equipment, and contact plausibility. Each frame records a pelvis anchor, torso anchor, and
shoulder-to-pelvis subject scale. Consecutive gates require pelvis drift `<= 0.08`, torso drift
`<= 0.08`, and relative scale drift `<= 0.12`; these are additive gates, not threshold weakening.

The chroma-fringe check treats green-dominant contamination at any visible alpha as spill. Its
separate cyan heuristic applies only to non-opaque antialiased edge pixels (`alpha < 240`), so
legitimate fully opaque navy/blue mats and equipment are not misclassified as key-color fringe.

Normalization uses an 896px maximum content extent by default. If an otherwise accepted image
fails **only** the fixed foreground-occupancy gate, the identical preserved raw may be released and
completed again with `--content-size` between 896 and 944. This deterministic refit must be recorded
as a new attempt and pass every unchanged automated and manual gate; it is not permission to crop
the subject, redraw the pose, or weaken the 0.08 occupancy minimum.

Automation cannot reliably prove equipment correctness, character consistency, anatomy, or the
absence of small visual artifacts. A reviewer must set all four booleans for a job in
`manual-reviews-v1.json`: `characterApproved`, `poseEquipmentApproved`, `anatomyApproved`, and
`artifactFree`. Then rerun validation with `--apply-state`. Only jobs with `status: complete` and
`qaStatus: accepted` may be packaged. V1 continues to package complete two-frame pairs; v2 packages
only complete accepted contiguous `0...5` sequences whose stored sequence-QA result passes.
`PackageAcceptedExerciseArtwork.py` verifies accepted PNG master hashes and derives transparent
768×768 WebPs. Android's `StageAcceptedAndroidFrames.py` then verifies that package index, WebP
hashes, dimensions, alpha, accepted state, and complete-pair parity before copying it into a
disposable Gradle build directory. The canonical shared packager may also be run directly:

```sh
python3 tools/exercise-artwork/imagen/PackageAcceptedExerciseArtwork.py
```

`--accepted-only` produces `tools/exercise-artwork/previews/
imagen-accepted-comparison-sheet.png`, a compact evidence sheet containing only complete accepted
gender pairs. It uses the packaged index as the row authority, verifies legacy-source, accepted-master,
and packaged-WebP hashes, then places the exact legacy endpoints beside the two shipped WebPs.
Rejected, pending, incomplete, unindexed, or hash-mismatched pairs are excluded or fail rendering.

V2 package and platform indexes add entry-level `frameCount: 6`, `frameDurationMs: 120`,
`playback: "pingPong"`, and `sequenceVersion: 1`. Existing schema-v1 two-frame entries remain valid
and may omit these fields. The verifier requires exact index/disk/master/state parity and checks the
persisted alignment/expected-pose evidence for every shipped v2 frame.

During migration, a v2 exercise whose exact `f0` and `f5` are accepted but whose intermediates are
not complete ships safely as `sequenceMode: "endpointsOnly"`: two contiguous runtime frames `0/1`
map to source jobs `f0/f5` through `sourceFrameIndex: 0/5`, use `frameDurationMs: 700`, and ping-pong.
One accepted endpoint never ships alone. Once all six jobs are accepted and complete sequence QA
passes, the next package run deterministically upgrades the entry to
`sequenceMode: "completeSequence"`, contiguous runtime frames `0...5`, and `frameDurationMs: 120`. Verifier,
contact sheet, and both stagers recompute this mode from jobs/state and reject stale mappings.

## Isolated verification

All fixtures use temporary manifests, state, masters, packages, and platform staging; they do not
write the canonical queue or artwork trees:

```sh
python3 -m unittest discover -s tools/exercise-artwork/imagen/tests -v
```

Coverage includes v1/v2 shape, interpolation/alignment pass and failure, endpoint migration across
accepted/rejected/pending/orphan/blocked states, six-frame packaging, strict verification, and both
platform stagers.

## Deterministic sequence alignment

`AlignExerciseArtworkSequence.py` aligns a complete six-frame set without deforming body parts or
equipment. MediaPipe detects each pelvis anchor and shoulder-to-pelvis scale; the canonical target
is the mean endpoint pelvis and geometric-mean endpoint scale. One affine uniform scale plus
translation is applied to the whole RGBA canvas, so the person, weights, bench, mat, and all contact
geometry move together. Every output must retain an alpha margin of at least 8 px, preserve alpha
area within 5%, and pass the ordinary integrity, pose, and consecutive drift gates.

The normal safe mode writes a separate aligned tree and metadata report:

```sh
/tmp/fud-pose-venv/bin/python \
  tools/exercise-artwork/imagen/AlignExerciseArtworkSequence.py \
  --exercise-id Dumbbell_Bicep_Curl --gender female \
  --model /tmp/pose_landmarker_heavy.task \
  --output-root /tmp/fud-aligned-pilot \
  --metadata /tmp/fud-aligned-pilot-report.json
```

The report records input/output hashes, target derivation, exact scale/translation, alpha geometry,
pose comparisons, per-segment angle diagnostics, and post-transform drift. Failed pose QA retains
the separate outputs and report for targeted generation retry evidence, but cannot update canonical
masters. Canonical replacement requires explicit `--apply --backup-root <empty-directory>`; all six
original PNGs are copied and hash-verified before any staged aligned output replaces a master. The
queue is locked, recorded master hashes must match, raw Imagen provenance remains untouched, and
all six jobs return to `completed_pending_qa` with new hashes plus their alignment transforms so the
ordinary automated and manual gates must accept them again.

Partial validation is report-safe: `ValidateImagenExerciseArtwork.py --pilot-only` merges selected
results into the existing report and recomputes stored counts instead of deleting non-pilot QA
evidence. `--apply-state` continues to touch only jobs evaluated by that invocation.

It writes quality-82 alpha WebP derivatives and an index under `shared/exercise-artwork/
fud-flat-raster-v1/packaged-768/`. Every derivative must pass alpha, dimension, RGBA visual-RMSE,
master-hash, and smaller-than-master gates. The 1024px PNG masters stay in `shared/` for QA and are
never packaged directly.

Release builds consume the committed `packaged-768/` directory directly. Gradle runs the read-only,
standard-library-only `VerifyPackagedExerciseArtwork.py` gate first; it never invokes Pillow or
rewrites assets during a build. The staging helper remains available for external packaging checks.

The former Vision/MediaPipe vector-pose manifest experiment is intentionally not part of this
pipeline. Runtime artwork comes only from manually accepted raster endpoint pairs indexed by the
packager; legacy FreeExerciseDB JPGs remain immutable pose/equipment references.

The pilot contains eight diverse exercises (32 jobs): 3/4 Sit-Up, Barbell Bench Press, Cable
Crossover, Triceps Pushdown, Leg Press, Tire Flip, Clean and Jerk, and Dumbbell Bicep Curl. The four
Bicycling jobs remain `blocked_source` because both legacy photos are unrelated helmet/cable closeups;
they require reviewed replacement pose references before generation.
