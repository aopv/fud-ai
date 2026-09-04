# Workout artwork audit

Read-only numerical audit of 8 images for 1 exercises.

No source images were changed. This numerical queue does not track visual acceptance; candidates are not confirmed defects.

Visual findings are recorded separately in [Band Skull Crusher observations](audit-visual-observations.json) and [initial exercise review](review-initial-exercises.md). Pending machine-queue statuses do not override those ledgers.

## Summary

- images_audited: 8
- exercises_audited: 1
- images_with_candidate_flags: 8
- exercises_with_candidate_flags: 1

## Image candidate counts

- large_opaque_pale_region: 4
- possible_precropped_flat_boundary: 7
- suspected_baked_checkerboard: 8

## Interpretation limits

- This is read-only numerical triage, not a visual pass or a repair.
- Pale regions may be legitimate shoes, teeth, equipment highlights, or clothing; inspect before editing.
- Bounding-box and alpha-area changes can represent correct exercise movement, not inconsistent person scale.
- Flat artwork boundaries can be normal equipment geometry; they only flag possible pre-cropped content.
- Duplicate return poses and static stretch frames can be intentional; review before treating as defects.
- Small enclosed remnants and subtle limb or identity discontinuities can evade these heuristics.
- Machine-queue review states remain pending; actual visual findings and repair acceptance are tracked in the separate linked ledgers.

## First 30 review candidates

| Rank | Exercise | Score | Flags |
| --- | --- | ---: | --- |
| 1 | Band_Skull_Crusher | 204.13208 | large_opaque_pale_region, near_duplicate_frames, possible_precropped_flat_boundary, suspected_baked_checkerboard |
