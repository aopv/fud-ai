# Band Pull Apart: cleaned background and aligned sequence review

Reviewed on 2026-09-04. Scope: **one exercise, both genders, all 8 candidate frames**. These are experiment outputs, not a claim that the whole workout library is complete or that these files are already installed.

## Decision

**Accepted as the background-cleanup and conservative frame-alignment candidate set for `Band_Pull_Apart`.** All eight candidate frames were inspected across the four phases on actual alpha-composited dark `(9, 9, 11)` and light `(245, 245, 247)` backgrounds. No broad white/checkerboard remnants, clipped person/band, or newly erased subject details were visible in that review. The band end-loop holes now show the theme background. Head and planted-foot placement are coherent while the arms and band retain their distinct motion phases.

The image viewer can expose RGB hidden under alpha, so its raw white/gray appearance alone is not a transparency test. The review used **real alpha compositing**, not replacement of the viewer's displayed backdrop.

## Candidate provenance

- Cleaned, unaligned input: `background-pilot/images/Band_Pull_Apart_{male,female}_v2_{0,1,2,3}.png`.
- Reviewed aligned output: `alignment-cleaned-pilot/images/`.
- Machine-readable transforms, inliers, input hashes and candidate paths: [alignment report](alignment-cleaned-pilot/alignment-report.json), revision `stationary-anchors-v2`.
- Original issue report: [initial exercise review](review-initial-exercises.md).
- Alignment code: `scripts/workout_frame_alignment.py`; safety tests: `scripts/test_workout_frame_alignment.py` (13 tests pass).

The candidate hashes below identify exactly the files reviewed. If a candidate is changed or regenerated, this acceptance no longer applies to that changed file.

| Candidate frame (relative to `alignment-cleaned-pilot/images/`) | SHA-256 | Dark review | Light review |
| --- | --- | --- | --- |
| `Band_Pull_Apart_male_v2_0.png` | `26729b06443b7d3f8107bb4a899c6731d792f484c56e34d7866cf4561daf10af` | Reviewed | Reviewed |
| `Band_Pull_Apart_male_v2_1.png` | `53eab3e8e9d3caa356315814c1de100565eac4ae4a6b01ec14b11668e11c7300` | Reviewed | Reviewed |
| `Band_Pull_Apart_male_v2_2.png` | `584b8b560557d7e6a7bb2a6e2cb439b48c406cfd25f3430374c9035bfecd6fcb` | Reviewed | Reviewed |
| `Band_Pull_Apart_male_v2_3.png` | `f20262e95d5192674deefaf1c7be99a224d89056bcdac8ee98cded076a01a30a` | Reviewed | Reviewed |
| `Band_Pull_Apart_female_v2_0.png` | `b8c5f1d7ab0623763a8477fe485b7c3550410ed75b191be67bc7fbd22b418dd7` | Reviewed | Reviewed |
| `Band_Pull_Apart_female_v2_1.png` | `0b94e49125bb1081c4b17373eca8759479d5233c87e98b022989a7127e07232b` | Reviewed | Reviewed |
| `Band_Pull_Apart_female_v2_2.png` | `cc8963db9f6a9c5565b392f568a1f2711d4de5891bf6b3ea67b097808bab6666` | Reviewed | Reviewed |
| `Band_Pull_Apart_female_v2_3.png` | `3a54d3dde729a6b3a57d74e28e3196e5a0bab0863824d238168e2081e6cfccbf` | Reviewed | Reviewed |

## Background evidence

Before alignment, the original opaque male-frame-0 loop samples at `(377, 188)` and `(645, 190)` changed from alpha 255 to alpha 0 in the cleaned input, while their RGB values stayed unchanged. The sampled shoe detail at `(441, 734)` retained alpha 255. The final resampling was premultiplied-alpha aware; transparent white RGB was not blended into new edge halos. Visual inspection of all eight final candidates confirmed that the loop interiors respond correctly to both theme backgrounds.

The cleanup/alignment does not globally erase white colors: light shoe trim and other valid bright subject detail remain visible on the dark composite.

## Motion and framing evidence

The semantically stationary anchors are the head and both planted feet. Matching only the feet was deliberately rejected as an adequate strategy for this exercise: minor shoe redraw differences can otherwise induce a false full-body zoom. Each accepted fit therefore requires support from all three independently named anchor regions.

| Gender | Frame | Anchor inliers | 90th-percentile residual | Relative scale | Relative translation (x, y pixels) |
| --- | --- | --- | --- | --- | --- |
| Male | 1 | 60 | 2.3694 px | 0.9998556 | -3.66678, -0.21355 |
| Male | 2 | 56 | 1.3646 px | 0.9980924 | -2.44637, 1.49936 |
| Male | 3 | 53 | 1.7836 px | 0.9965890 | -1.96135, 2.28745 |
| Female | 1 | 82 | 1.1179 px | 0.9997682 | 8.43691, -0.48973 |
| Female | 2 | 74 | 1.2548 px | 1.0000173 | 6.80359, -0.37305 |
| Female | 3 | 50 | 1.1702 px | 0.9998840 | 2.68101, -0.51764 |

Frame 0 is each gender's reference. After those small corrections, **one common pose-union fit per gender** adds consistent canvas padding: scale 0.9726094 for male and 0.9722907 for female. The common fit is not repeated independently for individual moving poses. There is no rotation, perspective deformation, limb warping, generated anatomy, or pose replacement.

## Remaining caveats and boundaries

- Male frames 0 and 1 remain very similar original starting poses, so the original four-tick sequence includes a brief near-stationary hold. The cleanup and registration intentionally do not invent a new intermediate arm pose.
- Small original garment, facial-detail and hand-height variations remain; these are source-art differences, not camera-registration errors. The candidate review accepts the requested background/framing repair, not perfect redrawn temporal anatomy.
- The review compares every motion phase and its registered anchors. It does **not** claim that an updated app build was installed, or that list playback was tested on a device in this subtask.
- No canonical image was promoted by this subtask. The root task must copy these exact reviewed candidates, sync iOS packaging, validate the inventory, and perform app/build verification separately.
