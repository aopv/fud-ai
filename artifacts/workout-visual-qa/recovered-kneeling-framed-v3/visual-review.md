# Recovered kneeling rollout candidate review

Scope: all eight frames of `Barbell_Ab_Rollout_-_On_Knees`, male/female 0–3.
Reviewed the eight source-native component diagrams, both contact sheets, and
all eight full 2048×768 dark/light previews of this final candidate stage.

## Outcome

All 8/8 candidates now have true RGBA transparency, complete visible barbells,
uncropped bodies/shoes, no observed neighboring exercise fragments, and coherent
shared framing. No broad opaque white/checkerboard/gray floor region remains.
No observed new body, shoe, plate, shaft, or collar deletion.

They are **not unconditionally accepted** for the requested polished dark-mode
result: a thin dotted gray rim still follows portions of the silhouettes, and
some tiny dark contact-edge marks remain. This is a much smaller defect than
the original floor patches but should not be silently counted as fully fixed.
Candidate assets only; no canonical or packaged images have been promoted.

## Processing and integrity

- Recovered source crops and source alpha are preserved. Invisible RGB containing
  neighboring sprites never becomes visible: premultiplied resampling uses
  the input alpha, not RGB-derived new alpha.
- The first local neural-assisted cleanup is root's
  `recovered-kneeling-cleanup/images` stage.
- Explicitly reviewed neutral shadow components removed another **8,544 native
  pixels**, alpha only. The recipe uses minRGB ≥100 and chroma ≤20 solely to
  identify selected connected components; it does not remove all gray pixels.
  Source hashes are hard-coded in the helper so component IDs cannot silently
  be reused on changed artwork.
- Exact native-coordinate removal/protection seeds, component bounds, and raw
  source provenance are in
  `../recovered-kneeling-shadow-cleanup/reviewed-shadow-seeds.json`.
  These are **not compatible with** the default minRGB ≥185 cleanup recipe.
- Every frame uses identical uniform scale **1.42** and fixed knee anchor
  **(750, 510)** on a **1024×768** canvas. There is no per-frame fit-to-bbox.
  Each four-frame knee-relative visible-alpha union fits within the padding;
  no frame has visible pixels on the canvas edges.
- RGB remains byte-for-byte unchanged during shadow cleanup. The framing stage
  changes RGB only by premultiplied-alpha bilinear resampling.
- The optional root ≤3px neutral-pale edge unmix then changed **1,091 edge pixels**
  across the eight frames. This stage intentionally changes edge RGB and alpha,
  not interior artwork. Explicit shoe-protection rectangles were unchanged
  byte-for-byte in every frame. Some darker-than-180 gray rim pixels remain.
- Source hashes were checked before and after each stage; no input changed.

## Per-frame visual ledger

All rows: complete equipment/body preserved; no neighboring sprite observed;
no broad floor patch; adequate common-canvas padding; no new crop.

| Frame | Remaining issue at full-size review | Decision |
| --- | --- | --- |
| Male 0 | Thin dotted gray rim around hair/back/arms; tiny dark contact-edge residue beneath knee/bar gap and shoe. | Hold for edge polish |
| Male 1 | Thin rim around hair/back/arms and portions of plate contour; small dark contacts under knees. | Hold for edge polish |
| Male 2 | Broad belly shadow successfully cleared. Thin gray rim along back, arms and undershirt edge. Source anatomy has straighter legs than the other kneeling frames. | Hold for edge polish; preserve anatomy caveat |
| Male 3 | Thin rim around hair/back/arms; a tiny light floor mark immediately below the shoe appears retained near the protected shoe edge. | Hold for localized shoe-adjacent review |
| Female 0 | Thin gray rim around ponytail/back/arms; plate and shoe details intact. | Hold for edge polish |
| Female 1 | Thin gray rim; small dark stub below the forward knee at approximately canvas (724, 515). | Hold for localized contact-edge review |
| Female 2 | Broad knee shadow successfully cleared. Thin gray rim; two small dark knee-contact marks near canvas (672, 513) and (721, 522). | Hold for localized contact-edge review |
| Female 3 | Thin gray rim around ponytail/back/arms; very small residual contact marks near bar/plate. | Hold for edge polish |

## Boundaries and next step

Do not lower the gray threshold globally: white shoes, metallic highlights and
real gray clothing details need protection. The remaining body-edge issue could
be evaluated with a body-only neutral-matte pass using a lower brightness floor,
while protecting all equipment and footwear. Tiny knee contacts need local
source-native decisions, not whole-image erosion. Do not reinterpret male
frame 2 anatomy or redraw the figures as part of background cleanup.

Source start-like frames 0 and 3 are separately drawn and remain nonidentical.
The fixed knee landmarks are approximate, particularly male frame 2. This is
not a device animation QA result or a claim that intrinsic pose/proportion
variation has been eliminated.
