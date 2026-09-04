# Original-source recovery: barbell rollouts

## Outcome

**All eight `Barbell_Ab_Rollout_-_On_Knees` frames can be recovered without redrawing.** Both original contact sheets contain complete athletes, shoes, barbells, plates, and sleeves. Neighbor fragments and plate/foot clipping in current assets resulted from equal-width 4×1 slicing of unequally spaced sprites.

Recovered source-native candidates are in `recovered-raw/`. They contain the original RGB without recoloring or resampling. The only alpha edits are manually specified polygon boundaries in empty space between adjacent sprites. Background removal and final animation alignment are deliberately left to the parent cleanup workflow.

No canonical asset, app source, build, installed app, or Git history was changed by this recovery task.

## Exact original sources

- `/Users/apoorvdarshan/workout-art-batches/batch-004/source-sheets/Barbell_Ab_Rollout_-_On_Knees_male.png`
- `/Users/apoorvdarshan/workout-art-batches/batch-004/source-sheets/Barbell_Ab_Rollout_-_On_Knees_female.png`

Both originals are **2172×724**. The old `/Users/apoorvdarshan/workout-art-batches/batch-004/process-sequence.zsh` uses `-crop 4x1@`, producing four 543-pixel-wide strips. This cuts through the extended pose and includes part of neighboring barbells.

## Corrected manual crop rectangles

Coordinates are original sheet coordinates, Pillow half-open `(left, top, right, bottom)`.

| Gender | Frame | Rectangle | Native crop size |
|---|---:|---|---|
| Male | 0 | `(16, 160, 493, 535)` | 477×375 |
| Male | 1 | `(495, 225, 1085, 570)` | 590×345 |
| Male | 2 | `(1030, 315, 1655, 610)` | 625×295 |
| Male | 3 | `(1660, 180, 2118, 548)` | 458×368 |
| Female | 0 | `(22, 120, 513, 545)` | 491×425 |
| Female | 1 | `(514, 190, 1063, 557)` | 549×367 |
| Female | 2 | `(1030, 303, 1625, 590)` | 595×287 |
| Female | 3 | `(1640, 130, 2134, 549)` | 494×419 |

**Frames 1 and 2 require polygon separation as well as these rectangles.** Their bounding boxes overlap horizontally, but their artwork does not overlap. The precise sheet-space polygons are in `recover_source_crops.py` and `recovery-manifest.json`; using only these rectangular boxes would reintroduce fragments.

## Verification

- Inspected both full original sheets, representative broken canonical frames, and the reconstructed 4×2 contact.
- `recovered-contact.png` shows all eight athletes and all equipment complete, with no neighboring sprite fragments.
- Read-only connectivity QA finds the four major ink/subject components in each original sheet and checks each manual mask. All eight recovered crops retain **100% of their major subject ink** and **zero ink pixels from neighboring subjects** (grayscale threshold 179).
- This ink check is supporting evidence, not a general alpha/visual validator. Backgrounds, floor shadows, and light interior regions remain in the recovered raw crops and still need cleanup.
- No pixels were invented, inpainted, or redrawn; no generative service was called.

Reproduce only recovery artifacts with:

```sh
python3 artifacts/workout-visual-qa/recovery-rollout/recover_source_crops.py
```

For final framing, preserve a consistent scale within each sex sequence. Do not independently stretch each frame to the same subject bounding-box width: the changing reach is exercise motion, not camera zoom. Anchor the knee contact/groundline consistently after background cleanup.

## `Barbell_Ab_Rollout` original files also found

The wave registry identifies task `01a05d36-07db-7eb1-90c0-3efcde752796`. Its nine original **1448×1086** outputs are still available in:

`/Users/apoorvdarshan/.codex/generated_images/01a05d36-07db-7eb1-90c0-3efcde752796/`

`standing-source-map.json` maps the eight current frames to exact generated originals. `barbell-ab-rollout-originals-contact.png` and `barbell-ab-rollout-current-contact.png` document the visual comparison. All mapped originals contain complete figures and equipment; no clipping needs redrawing. The original output backgrounds include a baked checkerboard and need cleanup.

The batch-003 keyframe map is **not** the authoritative current source for this exercise; the importer preferred its completed wave-001 output. Use the wave task originals in the map to preserve the current artwork and motion sequence.
