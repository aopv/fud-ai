# Accepted recovered kneeling-rollout background and framing

Exercise: `Barbell_Ab_Rollout_-_On_Knees`.
Acceptance: **background_and_framing**, all eight exact final v5 frames.
This record accepts only `recovered-kneeling-framed-v5/images/`, pinned by the
associated promotion manifest. It does not accept earlier v1–v4 candidates.
Reviewed on 2026-09-04 by the workout-asset audit subagent.

## Visual evidence and decision

Directly inspected every final frame at full 1024×768 against both dark and
light backgrounds (each preview is 2048×768). Also inspected the full sequence
contact sheets and magnified source-native grids around the three previously
unresolved contact marks. All eight final frames meet this background/framing
acceptance:

- Real transparency in the exterior and relevant interior body/bar openings.
  No baked checkerboard, broad pale floor patch, or unrelated neighboring sprite
  remains visible. Narrow neutral matte contamination is no longer conspicuous
  at the intended detail-view size. Natural antialiasing and legitimate metal,
  hair, shoe and illustration-edge highlights are retained, not blanket-erased.
- Complete visible head/body, feet/shoes, both barbell plates, shaft ends and
  collar details. No new foreground hole, severed equipment or edge clipping
  was observed in the final dark/light comparisons.
- Common 1024×768 canvas, scale 1.42 for every frame, stationary knee anchor
  (750,510), and no independent per-frame fit-to-bounding-box. The four-frame
  visible-alpha union fits within the intended padding for each gender.
- The source-native 0→1→2→3 sequence and original drawing proportions are
  retained. The moving bar travels through the rollout rather than being used
  as a fixed anchor. No frame receives pose warping or independent body scaling.

| Final frame | Background/openings | Foreground/equipment | Shared framing |
| --- | --- | --- | --- |
| male 0 | Pass | Pass | Pass |
| male 1 | Pass | Pass | Pass |
| male 2 | Pass | Pass | Pass, source pose caveat below |
| male 3 | Pass, localized shoe-adjacent remnant cleared | Pass, actual white sole retained | Pass |
| female 0 | Pass | Pass | Pass |
| female 1 | Pass, localized knee remnant cleared | Pass | Pass |
| female 2 | Pass, localized knee remnants cleared | Pass | Pass |
| female 3 | Pass | Pass | Pass |

## Preservation and processing provenance

1. All eight source-native crops were recovered from coherent original male and
   female sprite sheets. Existing alpha separates neighboring source sprites.
   `../recovery-rollout/recovery-manifest.json` and `framing-support.json` record
   that evidence and the source-coordinate anchors.
2. Root's local neural-assisted cleanup produced
   `../recovered-kneeling-cleanup/images`. It preserved source RGB and alpha
   support instead of accepting a destructive whole-model cutout.
3. `../recovered-kneeling-shadow-cleanup/reviewed-shadow-seeds.json` records
   explicit native-coordinate removal/protection seeds and hashes. The manually
   reviewed components removed 8,544 gray floor pixels by changing alpha only.
   The helper refuses changed source hashes; this is not global gray deletion.
4. `../recovered-kneeling-contact-cleanup/contact-report.json` records another
   **91** removed source-native background pixels in the three demonstrated
   contact neighborhoods. Tight polygons plus neutral/darkness guards preserved
   skin, dark outline ink and white sole pixels. Tiny detached background crumbs
   were removed only inside those reviewed neighborhoods. RGB stayed identical.
5. `../recovered-kneeling-framed-v5-base/framing-report.json` pins the common
   transform and every source hash. Resampling is premultiplied-alpha bilinear;
   hidden RGB outside the recovered source alpha cannot resurrect neighboring
   sprites. No geometry-changing postprocess occurs after this stage.
6. The root neutral-pale rim unmix touched 1,091 edge pixels, then the bounded
   darker neutral-rim unmix touched 26,766 pixels across all eight frames.
   Both passes are limited to the exterior ≤3px rim and reduce opacity while
   estimating edge color from the dark interior. They do not redraw or alter
   interior anatomy. The protected shoe rectangles remain byte-identical
   through both edge passes. Exact stage hashes are in `polish-report.json`
   and `../recovered-kneeling-framed-v5-edge/edge-refinement-report.json`.

## Explicit limitations that are not hidden by acceptance

Male frame 2's original knees/legs are much straighter than the other kneeling
poses. That source drawing is preserved, not represented as anatomically
corrected. Frames 0 and 3 are separately drawn start-like poses, not exact loop
duplicates. The manually estimated knee anchor, especially male frame 2, is
approximate. Mild natural source perspective changes in plate size are retained.
These are original-art/pose caveats, not leftover backgrounds, missing pixels,
or per-frame resize artifacts introduced by this repair.

This is visual acceptance of the exact background/framing repair, not a claim
of phone installation, workout-mechanics validation, perfect temporal animation
interpolation, or completed repair of the full 875-exercise library. No canonical
asset is modified by this subagent; the parent performs any authorized promotion.
