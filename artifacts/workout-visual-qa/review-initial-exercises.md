# Initial workout illustration visual audit

Reviewed on 2026-09-04. This report covers **4 exercises / 32 existing frames**, not the full 875-exercise collection. Every exact frame listed below was opened with the image viewer at its original 1024 x 768 source size. No source images were edited, transformed, or regenerated during this audit.

Source directory: `shared/workout-vectors/`. Exercise IDs and expected frame lists were checked against `exercise-visual-manifest.json`.

The image viewer exposes RGB values under transparent pixels in some palette PNGs. In particular, the gray surrounding Band Pull Apart is **not** proof of an opaque background: its sampled corner has alpha 0. Suspected interior gaps were checked with read-only RGBA pixel inspection. White shoe soles, equipment highlights, skin, and garment detailing are legitimate subject pixels and must not be indiscriminately erased.

## Summary and repair priority

| Priority | Exercise | Frames visually reviewed | Outcome |
| --- | --- | --- | --- |
| High | `Barbell_Ab_Rollout_-_On_Knees` | All 8 | Confirmed bad crop boundaries, neighboring sprite fragments, opaque floor remnants, and unstable framing. Needs built-in editing of the entire coherent sequence, not merely outer-background removal. |
| High | `Barbell_Ab_Rollout` | All 8 | Confirmed enclosed white/checkerboard gaps and light edge halos. Bar/plate size and foot anchors change substantially across poses. |
| Medium | `Barbell_Full_Squat` | All 8 | Useful artwork/style reference, but not a clean transparency reference: every frame retains a pale opaque floor island and visible light edge specks/halos. Pose progression is comparatively consistent. |
| Medium | `Band_Pull_Apart` | All 8 | Both red band end-loop holes retain opaque light fills in all frames. Overall body scale is comparatively steady. |

**No exercise in this group is marked passed.** The following are pre-repair findings only. Each repaired frame must be re-reviewed on light and dark backgrounds, and each four-frame gender sequence checked in motion before it is accepted.

## Band Pull Apart

Exact ID: `Band_Pull_Apart`.

| Exact frame viewed | Confirmed finding |
| --- | --- |
| `Band_Pull_Apart_male_v2_0.png` | Both band end-loop interiors are pale opaque fills; no broad outer white background. |
| `Band_Pull_Apart_male_v2_1.png` | Both loop interiors remain opaque. Pose is very similar to frame 0, so playback will spend two ticks near the starting position. |
| `Band_Pull_Apart_male_v2_2.png` | Both loop interiors remain opaque in the widened position. |
| `Band_Pull_Apart_male_v2_3.png` | Both loop interiors remain opaque in the return position. |
| `Band_Pull_Apart_female_v2_0.png` | Both loop interiors remain opaque. |
| `Band_Pull_Apart_female_v2_1.png` | Both loop interiors remain opaque. |
| `Band_Pull_Apart_female_v2_2.png` | Both loop interiors remain opaque. |
| `Band_Pull_Apart_female_v2_3.png` | Both loop interiors remain opaque. The hands/band sit somewhat lower on return than in frame 0. |

Read-only pixel evidence: male frame 0 at `(377, 188)` is RGBA `(249, 248, 248, 255)` and at `(645, 190)` is `(231, 232, 231, 255)`. Male frame 2 at `(261, 165)` is `(245, 246, 246, 255)`. Female frame 0 at `(387, 184)` is `(249, 249, 249, 255)`. Both loop interiors in all eight frames were sampled and each had alpha 255. By contrast, every sampled canvas corner had alpha 0.

Framing: head height, foot baseline, and overall person scale remain quite consistent. The arms moving outward is legitimate exercise motion, not a reason to resize each frame independently. Small lateral shifts and garment/face-detail changes are visible, but they are far less severe than in the rollout sequences. Use the existing fixed body scale as the alignment reference; preserve white shoe detailing while clearing only the band-loop negative space.

## Barbell Ab Rollout

Exact ID: `Barbell_Ab_Rollout`.

| Exact frame viewed | Confirmed finding |
| --- | --- |
| `Barbell_Ab_Rollout_male_v2_0.png` | Large white/checkerboard islands enclosed between arms, body, legs, and bar; light perimeter halo. |
| `Barbell_Ab_Rollout_male_v2_1.png` | Large white/checkerboard gap between arms and bar; light perimeter halo. Bar/plates have become substantially smaller than frame 0. |
| `Barbell_Ab_Rollout_male_v2_2.png` | White triangular gap between arms and bar; light perimeter halo. Most of the image content is now low in the canvas. |
| `Barbell_Ab_Rollout_male_v2_3.png` | White gap between arms and bar, white gap between lower legs, and pale scraps around plate/feet contact points. |
| `Barbell_Ab_Rollout_female_v2_0.png` | Large white islands beneath torso, between arms and between legs; light perimeter halo. |
| `Barbell_Ab_Rollout_female_v2_1.png` | Large white triangular gap between arms and bar; light perimeter halo. Bar/plates are substantially smaller than frame 0. |
| `Barbell_Ab_Rollout_female_v2_2.png` | White wedge under arms/torso extending toward the near plate; light perimeter halo. Extended pose sits extremely low in the canvas. |
| `Barbell_Ab_Rollout_female_v2_3.png` | Large white enclosed gap between arms/bar and pale scraps beneath feet; obvious frame-to-frame framing shift. |

Read-only pixel evidence: male frame 0 at `(425, 450)` is RGBA `(252, 252, 252, 255)` and at `(607, 500)` is `(247, 248, 248, 255)`, while the corner is `(0, 0, 0, 0)`.

Framing: changing torso angle and bar position is legitimate rollout motion. Changing the physical bar length/plate size and moving the fixed foot anchor across a large portion of the canvas is not a coherent fixed-camera sequence. Frame 0 has a nearly full-width bar, while later frames have a much shorter bar; the feet move from near the center-right to the far right. Frame 3 does not restore the same camera/framing as frame 0. These inconsistencies will look like zooming/jumping when animation is restored. Edit with one camera, one equipment scale, and a stable toe-contact anchor per gender; do not simply scale every pose to fill its own bounding box.

## Barbell Ab Rollout - On Knees

Exact manifest ID: `Barbell_Ab_Rollout_-_On_Knees`.

| Exact frame viewed | Confirmed finding |
| --- | --- |
| `Barbell_Ab_Rollout_-_On_Knees_male_v2_0.png` | Opaque pale floor strips beneath figure and bar; isolated fragment of a neighboring bar/plate at the far right; light edge halo. |
| `Barbell_Ab_Rollout_-_On_Knees_male_v2_1.png` | Pale floor strips; far-right neighboring bar/plate fragment; left primary plate visibly cut at a straight crop boundary. |
| `Barbell_Ab_Rollout_-_On_Knees_male_v2_2.png` | Large pale ground strip beneath extended body; left primary plate and far-right shoe abruptly cut at crop boundaries. |
| `Barbell_Ab_Rollout_-_On_Knees_male_v2_3.png` | Pale ground strips and a stray partial shoe from a neighboring sprite at the far left; light edge halo. |
| `Barbell_Ab_Rollout_-_On_Knees_female_v2_0.png` | Pale ground strips; isolated neighboring bar-end fragment at the far right; light edge halo. |
| `Barbell_Ab_Rollout_-_On_Knees_female_v2_1.png` | Pale ground strips and an extra neighboring plate/bar fragment at the far right. |
| `Barbell_Ab_Rollout_-_On_Knees_female_v2_2.png` | Large pale floor remnant under body/bar and an abruptly cropped left primary plate. |
| `Barbell_Ab_Rollout_-_On_Knees_female_v2_3.png` | Pale floor strips remain; foreground plate is pressed into the bottom crop boundary, with insufficient padding. |

Read-only pixel evidence: male frame 0 at `(425, 647)` is RGBA `(230, 230, 230, 255)`, confirming an opaque pale floor remnant, while the canvas corner has alpha 0.

Framing: knee/hip extension and forward bar movement are legitimate, but neighboring sprite pieces, clipped main equipment, and different crop origins are not. Frame 2 especially needs complete intended equipment/foot reconstruction and consistent padding, not just a transparent crop. Use a common knee-contact anchor, camera angle, bar/plate scale, and canvas framing across the four poses. Remove unrelated adjacent-sprite fragments without deleting the main exercise equipment.

## Barbell Full Squat style baseline

Exact ID: `Barbell_Full_Squat`.

| Exact frame viewed | Confirmed finding |
| --- | --- |
| `Barbell_Full_Squat_male_v2_0.png` | Pale opaque floor island under/between feet and visible light edge halo/specks. |
| `Barbell_Full_Squat_male_v2_1.png` | Pale floor island and light edge halo/specks. |
| `Barbell_Full_Squat_male_v2_2.png` | Pale floor island and light edge halo/specks. |
| `Barbell_Full_Squat_male_v2_3.png` | Pale floor island and light edge halo/specks. |
| `Barbell_Full_Squat_female_v2_0.png` | Pale opaque floor island and light edge halo/specks around person/equipment. |
| `Barbell_Full_Squat_female_v2_1.png` | Pale floor island and light edge halo/specks. |
| `Barbell_Full_Squat_female_v2_2.png` | Pale floor island and light edge halo/specks. |
| `Barbell_Full_Squat_female_v2_3.png` | Pale floor island and light edge halo/specks. |

Read-only pixel evidence: male frame 0 at `(545, 731)` is RGBA `(212, 211, 211, 255)` in the floor island; the canvas corner is transparent. This pale area is not a dark-mode-safe transparent shadow.

Framing: the bar/plates retain relatively consistent size and horizontal placement, and feet remain near the same baseline. The head/bar moving down during knee/hip flexion is correct exercise motion. Modest foot-position drift is visible, particularly frame 0 versus subsequent frames, but there is no rollout-sized camera-scale jump. Preserve the squat's drawing style and mechanically valid vertical motion; clean its background/edges rather than treating this baseline as already transparency-perfect.

## Acceptance checks for the built-in repairs

1. Real transparency in the exterior and every enclosed negative-space region; no painted checkerboard, white/gray floor island, or pale background fringe.
2. Keep legitimate bright subject details such as shoe soles and metallic bar highlights.
3. Complete intended person/equipment only: no adjacent-sprite fragments, no clipped main plate, foot, or band.
4. One consistent camera, person/equipment scale, anchor, and canvas padding per gender sequence. Do not normalize the bounding box of each moving pose independently.
5. Preserve artwork identity, equipment, action, and the four distinct motion phases.
6. Reinspect all eight repaired originals and play both gender sequences on light and dark backgrounds; structural alpha checks alone are insufficient.
