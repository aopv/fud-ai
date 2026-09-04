# Existing-pixel shoe-tip recovery candidate

## Outcome

**A close, compatible existing donor was found.** Female frame2 uses the same shoe design and side-facing viewpoint as the surviving female3 shoes. A uniform scale/translation registration closely matches both shoes, allowing only the missing toe tips to be copied into newly added right-hand canvas space. This is non-generative compositing of existing artwork, not recovery of nonexistent pixels from female3 itself.

Candidate: `Band_Skull_Crusher_female_v2_3-toe-extension-candidate.png`.

The original female3 image is **1448×1086**; the candidate is **1472×1086**. All original 1448×1086 pixels are preserved exactly. Only a 24-pixel-wide extension was added, and donor pixels were appended only in y760–939. No original female3 pixels, shoe panels, legs, body, pose, equipment, or framing were overwritten.

The candidate is **not a final app asset**: it retains original baked background pixels and needs the parent workflow's background cleanup and common framing. Canonical assets remain unchanged.

## Sources

Target female3:

`/Users/apoorvdarshan/.codex/generated_images/01a05d35-f69e-7912-bd85-0163e1e7586d/exec-598b751f-09a3-46f7-b58f-fabaf978a83b.png`

Selected donor female2:

`/Users/apoorvdarshan/.codex/generated_images/01a05d35-f69e-7912-bd85-0163e1e7586d/exec-51b585e8-3b8d-4fc9-b90d-31ff7cccbdd4.png`

The original female0 and female1 shoes were also compared, but female2 gave the closest whole surviving-shoe match. `skull-crusher-shoes-native-contact.png` shows the original comparisons; `skull-crusher-shoe-registration-contact.png` shows the registered alternatives.

## Registration and evidence

- Only uniform scale and translation were used; no non-uniform stretching, warping, painted pixels, or generated pixels.
- Uniform donor scale: **1.035**.
- Translation relative to source/target ROI origin `(1100,680)`: **(+48,-44)** pixels.
- Masked surviving-shoe RGB RMSE: approximately **15.11/255**, versus19.08 for female1 and20.94 for female0. This diagnostic score is not itself acceptance proof; the candidates were visually inspected.
- At original right edge x1447, the target back-shoe dark silhouette occupies y819–843; registered donor2 occupies y818–842. The target front-shoe silhouette occupies y873–904; donor2 occupies y873–905. Both joins differ by only about1pixel, with compatible upper/sole contours.
- Full candidate and a nearest-neighbor4× close-up were viewed. Both toe outlines now close within the extended canvas, with the same viewpoint/design and no duplicated sole or incompatible shoe shape.
- `skull-crusher-toe-extension-seam-review.png` marks the old canvas edge with red indicators above/below the detail. Tiny subpixel/antialias transitions remain at the join; recheck after final cleanup/downsampling rather than assuming a flawless pixel-identical original.
- `extend_skull_crusher_toes_candidate.py` asserts that every original RGBA pixel is unchanged. The assertion passed.

## Reproduction

```sh
python3 artifacts/workout-visual-qa/recovery-rollout/register_skull_crusher_shoes.py
python3 artifacts/workout-visual-qa/recovery-rollout/extend_skull_crusher_toes_candidate.py
```

All outputs stay in this recovery directory. Nothing is installed, built, or committed by these scripts.
