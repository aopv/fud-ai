# Workout audit review batches

Human review packs for the Codex visual audit (309/875 complete as of 2026-09-04).

## Local setup (Mac / local Cursor)

Everything runs on your machine — no cloud agent needed.

```sh
cd ~/fud-ai
git fetch origin cursor/batch-1-review-pack-b6be
git checkout cursor/batch-1-review-pack-b6be

# One-shot: rebuild batch JSON with Mac paths, render previews, install canvas
./scripts/setup_local_batch_review.sh
```

Or step by step:

```sh
python3 scripts/build_workout_review_batch.py --batch 1 --batch-size 50 \
  --audit-json ~/Documents/Codex/2026-09-05/workout-audit-only-875/reports/audit-report.json

python3 scripts/render_batch_previews.py --batch 1

python3 scripts/generate_workout_review_canvas.py --batch 1 --install-canvas
```

Then open **`workout-audit-batch-01.canvas.tsx`** beside chat in Cursor (installed under `~/.cursor/projects/Users-apoorvdarshan-fud-ai/canvases/`).

Mark each exercise: `accept_as_is` | `script_fix` | `redraw` | `defer`. No repairs run until you finish review and explicitly approve `script_fix` items.

## Batch 01 (50 exercises)

- **20 critical** + **30 major** (first major block in severity order)
- Data: [`batch-01/batch-01.json`](batch-01/batch-01.json)
- Checklist: [`batch-01/batch-01.md`](batch-01/batch-01.md)
- Canvas template: [`canvas/workout-audit-batch-01.canvas.tsx`](canvas/workout-audit-batch-01.canvas.tsx) (regenerate with `generate_workout_review_canvas.py`)

### Regenerate previews

Previews are not committed (large PNG set). After cloning or switching branches:

```sh
python3 scripts/render_batch_previews.py --batch 1
```

### Full audit source (optional)

Point `--audit-json` at your local Codex collector output, e.g.
`~/Documents/Codex/2026-09-05/workout-audit-only-875/reports/audit-report.json`.
The bundled [`audit-source/audit-report-excerpt.md`](audit-source/audit-report-excerpt.md) covers batch 01 when that file is unavailable.
