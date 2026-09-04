# Sixteen-pose framing review

This is a source-based visual review, not a claim of biomechanically validated instructional animation. All sixteen original poses were inspected using the original-sheet and original-frame contacts, with individual frame inspection for geometry/landmarks. No canonical assets were edited.

## Summary

The kneeling set's severe truncation and neighboring fragments are **export/crop mistakes**: the intact source sheet recovers them completely. The standing set's frame-to-frame scale/viewpoint differences are **partly intrinsic to independently generated artwork**, not just canvas padding. Non-generative cleanup and whole-frame transforms can improve both sets, but cannot make their separately drawn anatomy and hardware literally identical.

## Kneeling rollout: all eight poses

| Pose | What the intact source contains | Export issue versus intrinsic issue |
|---|---|---|
| Male0 | Upright kneeling start, complete both plates/bar sleeves, knees, and rear shoe. | Neighbor plate fragment in old export is a strip-boundary mistake. Original silhouette is complete. |
| Male1 | Forward transition; complete reaching arms, barbell, and lifted rear shoes. | Current strip crop loses/reassigns edge material because this sprite crosses x=543/1086 boundaries. Manual polygon crop recovers it. Knees/hips move slightly in image projection; use a knee anchor rather than frame center. |
| Male2 | Long extended pose with complete barbell and feet. | Missing left plate/neighbor foot in old export is recoverable crop damage. Intrinsic caveat: knee bend is much less explicit and legs appear straighter than in the other kneeling frames; recropping cannot change that shape. |
| Male3 | Returned start-like kneel; equipment and rear shoe complete. | Export clipping is recoverable. This is a separate start-like drawing, not an exact duplicate of frame0; small head/arm/wheel changes remain at the loop seam. |
| Female0 | Upright kneel, both knees folded, shoes and hardware complete. | Old neighbor fragment/cropped edge is export-related. Original pose can be retained intact. |
| Female1 | Leaning transition with grounded bent knees, complete shoes and hardware. | Sprite bounds overlap the next sprite in x but not occupied pixels. Polygon separation, not equal-width slicing, is required. |
| Female2 | Fully reached torso with knees still visibly bent, complete plates and lifted shoes. | Truncated plate/adjacent shoe are export mistakes. The original full sprite recovers both without redrawing. |
| Female3 | Returned upright kneel with complete equipment. | Boundary/crop problems are recoverable. It is independently drawn relative to frame0; slight silhouette/plate changes at the seam are intrinsic. |

Approximate near-plate heights in **native recovered crop pixels** are male `[107, 113, 120, 102]`, female `[108, 108, 110, 105]`. These are manually measured visible feature boxes, not exact fitted ellipses. The modest increase at extension can be consistent with rollout toward a three-quarter camera; don't normalize it away reflexively. The source sheet is already a much better common-scale reference than the independently trimmed 1024×768 exports.

### Kneeling framing recommendation

1. Use the eight `recovered-raw/` files, preserving their input alpha.
2. Remove white/gray backdrop and floor shadows while preserving subject highlights. Do not reintroduce alpha-zero neighboring RGB.
3. Use **one uniform native-source scale**, with no per-frame width fitting. The fully reached pose is wider because of motion.
4. Align the same grounded knee/contact location horizontally and vertically. Do not anchor moving hands/barbell or the lowest alpha pixel (usually a moving front plate).
5. Fit the union of all transformed visible silhouettes once to a 1024×768 canvas with padding. Retain that common scale and anchor for all four poses. A starting preview is scale1.42 and knee anchor(750,510); approximate source/crop landmarks are in `framing-support.json`. The male2 knee anchor is low-confidence and needs animation preview before finalization.
6. Review a 0→1→2→3→0 animated loop and a static alpha-composited overlay. Small perspective changes are expected; abrupt zoom or foot/knee sliding is not.

## Standing rollout: all eight poses

| Pose | Original-frame finding | Remaining intrinsic mismatch |
|---|---|---|
| Male0 | Full high-hip standing/folded start; complete two plate stacks, bar, and shoes. | Plate stacks/subject are more prominent than later frames, indicating a different composition/scale. Not clipped in the original. |
| Male1 | Extended diagonal transition, complete hands/feet and hardware. | Plates are smaller than frame0; support posture changes toward forefeet. Whole-frame positioning alone cannot equalize equipment scale. |
| Male2 | Near-horizontal full reach with complete shoes/plates. | Similar hardware scale to frame1; hand/head/body proportions still differ slightly because it was independently drawn. A tiny dark corner speck is unrelated background debris, not missing anatomy. |
| Male3 | Partial return, higher hips, complete equipment and shoes. | Near plate is smaller again and body proportions differ from frame0. It is the selected replacement return phase, not the unused earlier start-like candidate. |
| Female0 | Full folded start with ponytail, both shoes, and complete plate stacks. | Largest plate/subject composition in the female set, different from extension frames. |
| Female1 | Diagonal extension, complete shoes/plates. | Hardware smaller than frame0; forefoot support and foot angle change. Those foot changes should not be "fixed" by pinning the farthest-right pixel. |
| Female2 | Long near-horizontal reach with complete silhouette/hardware. | Perspective/body proportions differ slightly from frame1; backdrop/checkerboard is baked, not an alpha issue solved by cropping. |
| Female3 | Partial return, raised hips and complete shoes/plates. | Intermediate plate scale and different foot placement; a subtle floor shadow under feet remains in the original. |

Approximate near-plate heights in the **1448×1086 original frames** are male `[263, 219, 221, 204]`, female `[267, 213, 219, 235]`. Relative to frame0, later plates are approximately **16–22% smaller for male** and **12–20% smaller for female**. These differences already exist in the source originals; cropping alone cannot remove them.

### Standing framing recommendation

1. Use `standing-source-map.json`, not the stale batch003 keyframes. The mapped files are the selected wave001 originals.
2. Clean the actual original resolution, then estimate an overall scale per frame from multiple stable features (plate diameter, head/upper-arm size), not subject bounding-box width.
3. Choose conservative **uniform** per-frame calibration only where equipment and body cues agree. Never stretch width and height independently, and don't independently distort or reposition the barbell relative to hands.
4. Use the supporting near forefoot/toe contact as the fixed anchor, not the barbell. Barbell motion relative to anchored feet is the exercise. Heel lift can legitimately change lowest-outline pixels.
5. After that calibration, fit the full four-frame union once using one common final canvas scale, preserving room for the longest reach and the taller frame0.
6. Review both equipment scale and athlete head/body scale in the animated preview. If normalizing the wheel makes the athlete visibly grow/shrink, record the residual source mismatch rather than claiming a perfect coherent loop. Those coupled discrepancies cannot all be solved with only global scale/translation.

## Source integration safeguards

- `recovery-manifest.json`: exact source-sheet rectangles and ownership polygons for kneeling.
- `standing-source-map.json`: exact current-frame→original-file mapping for standing.
- `framing-support.json`: approximate feature boxes/contact anchors and transform formula; guidance only, no automatic edits applied.
- Recovered crop hidden RGB outside the polygon still contains neighboring objects, but alpha is0. Always multiply/retain input alpha during later cleanup. The composited `recovered-contact.png` is authoritative for visibility; a viewer that exposes hidden RGB can misleadingly show removed neighbors.
- Do not report the entire sequence as geometrically verified solely because alpha, count, dimensions, or crop checks pass.
