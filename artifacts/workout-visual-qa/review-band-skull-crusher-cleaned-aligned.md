# Band Skull Crusher — reviewed background and framing repair

Acceptance: `background_and_framing` for all eight exact existing asset names, male/female frames 0–3. Reviewed by the Codex QA subagent on 2026-09-04. This is an agent visual review, not a claim of separate user sign-off. Canonical assets have not been changed by this work.

## Sources and operations

- Base: root-cleaned `background-pilot/images/Band_Skull_Crusher_*_v2_*.png`, including the three explicitly reviewed interior-gap overrides (male1, female0, female2).
- Female3's two shoe tips were intrinsically clipped in its original 1448×1086 generated source. The corresponding intact female2 shoe geometry matched under a uniform scale/translation. Only the missing source columns were recovered from those existing pixels; no generation, redrawing, or geometry warp was used. Evidence and native source mapping: `recovery-rollout/skull-crusher-shoe-donor-review.md`, `skull-crusher-shoe-registration.json`, and `skull-crusher-female3-recovery.md`.
- The toe-only recovery was registered against the surviving cleaned female3 shoe artwork at scale 0.70975, translation (-15.75, 75.25). Its new alpha occupies source-canvas box (1011,655,1024,718). Existing visible cleaned RGBA pixels were asserted byte-identical before the final fit. An enlarged temporary canvas prevented any right-edge truncation; no raw white/checkerboard backdrop was imported.
- Bench-foot centers were stabilized using whole-frame translations only: at most 4.53 pixels for the male sequence and 5.80 pixels for the female sequence. One shared uniform scale was then applied to each entire four-frame gender sequence: male 0.9359558700; female 0.9328063241. No independent frame size fitting or body/equipment warp was used.
- Optional root edge refinement was applied to the staged results, with `[785,605,1024,750]` protected to preserve the complete shoes. The protected rectangle's RGBA values and the eroded artwork interior are exactly equal to the pre-refinement candidates in all eight frames. Only thin neutral matte rims and tiny detached neutral crumbs were changed.

## Visual acceptance

All eight final frames were inspected in full-sequence light and dark contacts and in native-resolution shoe-detail contacts. Athlete, hands, hair, band, bench, all bench feet, and both shoes are fully visible. The recovered female3 shoe tips have closed matching outlines and preserve their white sole/stripe details. Bench holes, under-bench background, under-arm gaps and band gaps reveal the chosen background; no opaque white/checkerboard fill or neighboring sprite fragments remain in the reviewed regions. The equipment scale and groundline remain stable across the sequence after the small rigid translations.

The original illustrations are independently drawn poses. Minor intrinsic body/bench/foot drawing differences remain; this repair does not claim perfect skeletal animation or replace the original pose geometry. Deliberately protected shoe highlights and some subpixel pale shoe-edge pixels remain instead of risking loss of genuine white sole artwork.

Reviewed final outputs: `skull-final-refined/Band_Skull_Crusher_{male,female}_v2_{0,1,2,3}.png`.

Reviewed visual evidence:

- `skull-final-refined/contact-dark.png`
- `skull-final-refined/contact-light.png`
- `skull-final-refined/shoes-dark.png`
- `skull-final-refined/shoes-light.png`

## Automated verification

All eight are single-frame RGBA PNGs, exactly 1024×768, alpha extrema 0–255. Interior and protected-shoe equality assertions pass. The complete candidates have safe margins and no alpha touches a canvas border.

| Asset suffix | Visible alpha bounds (left, top, right, bottom) | Rim pixels refined | Detached crumbs removed |
| --- | --- | ---: | ---: |
| male_v2_0 | 48,225,985,737 | 450 | 7 |
| male_v2_1 | 43,119,981,736 | 545 | 13 |
| male_v2_2 | 43,81,980,736 | 450 | 13 |
| male_v2_3 | 39,242,977,736 | 385 | 7 |
| female_v2_0 | 46,283,981,737 | 521 | 7 |
| female_v2_1 | 44,235,979,736 | 614 | 12 |
| female_v2_2 | 45,141,980,737 | 672 | 13 |
| female_v2_3 | 39,294,984,737 | 454 | 10 |

Exact per-frame candidate SHA-256 and original shared asset SHA-256 values are recorded in `skull-final-refined/verification.json` and the promotion manifest. The promotion manifest also locks this review record by SHA-256 and covers exactly eight existing names. Source transformation details are in `skull-final-candidates/report.json`. No canonical copy, build, installation, commit, or push was performed by this QA subagent.
