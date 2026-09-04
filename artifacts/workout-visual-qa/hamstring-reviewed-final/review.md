# 90_90_Hamstring: reviewed, not accepted

Reviewed 2026-09-04. This checkpoint is **0 accepted exercises / 0 promoted frames**.
The directory name identifies the review work area, not a production-ready set.

## Scope and evidence

- All eight cached candidates were inspected individually at native resolution
  on `#090909` and `#eeeeee` using `cached-review/*-preview.png`.
- Both four-frame gender contact sheets were inspected for sequence consistency.
- Original shared frames were rendered separately in `original-review/`.
  Female frames 0 and 2 and male frame 2 were compared directly at native
  resolution to confirm that the suspicious truncations predate cleanup.
- Each render directory contains `render-record.json` with the eight exact input
  SHA-256 values, dimensions and actual alpha extrema.
- The existing cleanup records report unchanged RGB for every frame. They remove
  18 pale pixels from female 0 and 24 from male 3; the other six are unchanged at
  the pixel level. No new inference, alignment, generation or production edit was
  performed during this review.

## Findings

There are no large white or checkerboard background islands in these candidates.
The background around and between the raised leg, arms and torso is transparent.
Real light shoe soles and highlights remain present. The thin dotted/light rim
along skin, black clothing and hair is still visible against dark backgrounds;
the broad neutral-region cleanup does not address this narrow matte fringe.

| Frame | Native review finding | Acceptance |
| --- | --- | --- |
| male 0 | No broad background remnants; light rim on skin/clothing. The torso and extended-leg span appear wider than frames 1/3. | Pending rim and stationary-anchor review |
| male 1 | No broad background remnants; light rim, especially black clothing and raised leg. | Pending rim and stationary-anchor review |
| male 2 | No broad background remnants; light rim. Raised shoe has a suspicious flat top at approximately y=165, also present in the shared original. It is not at the outer canvas edge. | Pending original-source crop verification |
| male 3 | No broad background remnants; light rim. Small existing alpha removal does not solve the fringe. | Pending rim and stationary-anchor review |
| female 0 | Hair ends in a conspicuous vertical cut at approximately x=923, with 134 visible pixels on that bounding-box edge. Same cut exists in shared original; not created by cleanup. Light rim elsewhere. | Rejected for source hair truncation |
| female 1 | No broad background remnants; light rim, including around hair. Hair silhouette is complete enough to be a potential non-generative donor only after registration validation. | Pending rim and sequence review |
| female 2 | Hair ends in a vertical cut at approximately x=924, with 104 visible pixels on that bounding-box edge. Same cut exists in shared original. Light rim elsewhere. | Rejected for source hair truncation |
| female 3 | No broad background remnants; light rim, including hair and clothing. | Pending rim and sequence review |

Numerical boundary counts above were checked against the existing audit; the
rejection is based on native visual inspection, not the numerical flags alone.
The male shoe remains a suspected crop rather than a claimed confirmed defect.

## Framing and safe next work

The eight frames keep their original 1024x768 canvas. The extended shoe bottoms
are consistently at y=756. The raised leg correctly changes the total pose box
between phases; fitting each box independently would create new scale pumping.
Do not normalize that natural height change or force moving-leg anchors to match.
Stationary torso/extended-leg anchors require further comparison before approving
uniform frame alignment; no anatomy should be stretched or warped.

Recover the two truncated female hair silhouettes from original unsliced artwork
if available, or a demonstrably matching neighboring frame after rigid/uniform
registration. Verify the male-2 shoe against an unsliced source. Only then apply
the optional narrow-rim cleanup with real white shoe details explicitly protected,
and repeat all-eight dark/light and motion-phase review.

Because the full set does not pass, **no promotion manifest was created**. Existing
canonical assets and all input candidate PNGs remain untouched.
