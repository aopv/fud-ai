#!/usr/bin/env bash
# One-shot local setup for workout audit batch review (Mac / local Cursor).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BATCH="${BATCH:-1}"
BATCH_SIZE="${BATCH_SIZE:-50}"
AUDIT_JSON="${1:-$HOME/Documents/Codex/2026-09-05/workout-audit-only-875/reports/audit-report.json}"

echo "==> Repo: $ROOT"
echo "==> Batch: $BATCH ($BATCH_SIZE exercises)"

if [[ -f "$AUDIT_JSON" ]]; then
  echo "==> Using audit JSON: $AUDIT_JSON"
  python3 scripts/build_workout_review_batch.py \
    --batch "$BATCH" \
    --batch-size "$BATCH_SIZE" \
    --audit-json "$AUDIT_JSON"
else
  echo "==> Audit JSON not found; using bundled excerpt in artifacts/workout-visual-qa/review-batches/audit-source/"
  python3 scripts/build_workout_review_batch.py \
    --batch "$BATCH" \
    --batch-size "$BATCH_SIZE"
fi

echo "==> Rendering preview contact sheets (gitignored, ~150MB for batch 1)..."
python3 scripts/render_batch_previews.py --batch "$BATCH"

echo "==> Generating and installing review canvas..."
python3 scripts/generate_workout_review_canvas.py --batch "$BATCH" --install-canvas

CANVAS_NAME="workout-audit-batch-$(printf '%02d' "$BATCH").canvas.tsx"
echo ""
echo "Ready. In local Cursor:"
echo "  1. Open $ROOT"
echo "  2. Open canvas: workout-audit-batch-$(printf '%02d' "$BATCH").canvas.tsx (beside chat)"
echo "  3. Review all exercises — mark accept_as_is | script_fix | redraw | defer"
echo "  4. Tell the agent when review is done (no repairs run until you approve script_fix items)"
echo ""
echo "Checklist: artifacts/workout-visual-qa/review-batches/batch-$(printf '%02d' "$BATCH")/batch-$(printf '%02d' "$BATCH").md"
