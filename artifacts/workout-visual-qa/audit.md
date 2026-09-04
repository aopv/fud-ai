# Workout artwork audit

Read-only numerical audit of 7,000 images for 875 exercises.

No source images were changed. This numerical queue does not track visual acceptance; candidates are not confirmed defects.

Visual findings are recorded separately in [Band Skull Crusher observations](audit-visual-observations.json) and [initial exercise review](review-initial-exercises.md). Pending machine-queue statuses do not override those ledgers.

## Summary

- images_audited: 7000
- exercises_audited: 875
- images_with_candidate_flags: 2906
- exercises_with_candidate_flags: 772

## Image candidate counts

- large_opaque_pale_region: 683
- possible_edge_clipping: 322
- possible_precropped_flat_boundary: 1360
- small_canvas_occupancy: 535
- suspected_baked_checkerboard: 1222

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
| 1 | Double_Leg_Butt_Kick | 308.424072 | large_opaque_pale_region, near_duplicate_frames, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 2 | Double_Kettlebell_Jerk | 302.966309 | large_opaque_pale_region, near_duplicate_frames, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 3 | Kipping_Muscle_Up | 290.0 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 4 | Triceps_Overhead_Extension_with_Rope | 288.049316 | large_opaque_pale_region, possible_edge_clipping, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 5 | Bench_Dips | 287.91748 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 6 | Double_Kettlebell_Push_Press | 283.979492 | large_opaque_pale_region, near_duplicate_frames, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 7 | Dumbbell_Clean | 283.161621 | large_opaque_pale_region, near_duplicate_frames, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 8 | Monster_Walk | 280.727539 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 9 | Squat_with_Bands | 269.644775 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 10 | One_Half_Locust | 268.526611 | large_opaque_pale_region, near_duplicate_frames, possible_position_variation, possible_scale_variation, suspected_baked_checkerboard |
| 11 | Tate_Press | 266.640625 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 12 | Drop_Push | 264.650879 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 13 | Double_Kettlebell_Snatch | 264.443359 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 14 | Cocoons | 264.150391 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 15 | Kettlebell_Turkish_Get-Up_Lunge_style | 263.967285 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 16 | Kettlebell_Turkish_Get-Up_Squat_style | 263.869629 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 17 | Keg_Load | 262.929688 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 18 | Bradford_Rocky_Presses | 257.697754 | large_opaque_pale_region, possible_edge_clipping, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 19 | Standing_Hamstring_and_Calf_Stretch | 256.706543 | large_opaque_pale_region, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 20 | Split_Jump | 253.513184 | large_opaque_pale_region, possible_position_variation, possible_scale_variation, suspected_baked_checkerboard |
| 21 | Bottoms_Up | 252.561035 | large_opaque_pale_region, possible_position_variation, possible_scale_variation, suspected_baked_checkerboard |
| 22 | Push-Ups_With_Feet_Elevated | 252.536621 | large_opaque_pale_region, possible_position_variation, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 23 | Barbell_Ab_Rollout | 251.456299 | large_opaque_pale_region, possible_position_variation, possible_scale_variation, suspected_baked_checkerboard |
| 24 | Side_to_Side_Box_Shuffle | 249.375 | large_opaque_pale_region, possible_position_variation, possible_scale_variation, suspected_baked_checkerboard |
| 25 | Palms-Down_Dumbbell_Wrist_Curl_Over_A_Bench | 247.860107 | large_opaque_pale_region, near_duplicate_frames, possible_edge_clipping, suspected_baked_checkerboard |
| 26 | Dumbbell_Bench_Press | 247.202148 | large_opaque_pale_region, near_duplicate_frames, possible_precropped_flat_boundary, possible_scale_variation, small_canvas_occupancy, suspected_baked_checkerboard |
| 27 | Downward_Facing_Balance | 246.324463 | large_opaque_pale_region, possible_precropped_flat_boundary, possible_scale_variation, suspected_baked_checkerboard |
| 28 | Shoulder_Press_-_With_Bands | 244.541016 | large_opaque_pale_region, near_duplicate_frames, possible_position_variation, possible_precropped_flat_boundary, suspected_baked_checkerboard |
| 29 | Bent-Arm_Barbell_Pullover | 244.345703 | large_opaque_pale_region, possible_position_variation, possible_scale_variation, suspected_baked_checkerboard |
| 30 | Backward_Medicine_Ball_Throw | 243.546143 | large_opaque_pale_region, possible_position_variation, possible_scale_variation, suspected_baked_checkerboard |
