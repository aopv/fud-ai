# Workout audit review batches

Human review packs for the Codex visual audit (309/875 complete as of 2026-09-04).

## Batch 01 (50 exercises)

- **20 critical** + **30 major** (first major block in severity order)
- Data: [`batch-01/batch-01.json`](batch-01/batch-01.json)
- Checklist: [`batch-01/batch-01.md`](batch-01/batch-01.md)
- Canvas: open [`workout-audit-batch-01.canvas.tsx`](/home/ubuntu/.cursor/projects/workspace/canvases/workout-audit-batch-01.canvas.tsx) beside chat in Cursor

### Regenerate previews (local)

Previews are not committed (large PNG set). After cloning, render contact sheets:

```sh
python3 scripts/build_workout_review_batch.py --batch 1 --batch-size 50

for ex in $(python3 -c "import json; b=json.load(open('artifacts/workout-visual-qa/review-batches/batch-01/batch-01.json')); print(' '.join(x['exerciseId'] for x in b['exercises']))"); do
  python3 scripts/render_workout_review.py \
    --input shared/workout-vectors \
    --exercise "$ex" \
    --output "artifacts/workout-visual-qa/review-batches/batch-01/previews/$ex"
done
```

### Full audit source (optional)

Point `--audit-json` at your local Codex collector output, e.g.
`~/Documents/Codex/2026-09-05/workout-audit-only-875/reports/audit-report.json`.
The bundled [`audit-source/audit-report-excerpt.md`](audit-source/audit-report-excerpt.md) covers batch 01 when that file is unavailable.
