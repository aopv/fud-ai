# Imagen exercise artwork pipeline

This directory turns the canonical 875-record FreeExerciseDB library into 3,500 independent,
resumable Imagen jobs: two endpoint frames for each exercise, for both male and female characters.
Each job produces exactly one image. The approved character sheet is supplied first and the exact
legacy endpoint photo second as two separate references to that one generation call.

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

Automation cannot reliably prove equipment correctness, character consistency, anatomy, or the
absence of small visual artifacts. A reviewer must set all four booleans for a job in
`manual-reviews-v1.json`: `characterApproved`, `poseEquipmentApproved`, `anatomyApproved`, and
`artifactFree`. Then rerun validation with `--apply-state`. Only jobs with `status: complete` and
`qaStatus: accepted` may be packaged, and platform staging must copy complete two-frame pairs only.
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
