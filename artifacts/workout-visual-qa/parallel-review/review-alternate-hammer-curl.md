# Alternate Hammer Curl: reviewed presentation repair

Date: 2026-09-04. Acceptance: `background_and_framing` for all eight male/female frames. Reviewed by the root Codex agent, not user sign-off.

All eight complete 1024x768 final frames were inspected at native size on dark and light backgrounds in `hammer-final-review/*-preview.png`, after inspection of both original sequence sheets. The artwork already has genuine transparent background openings: no broad white floors, painted checkerboards, enclosed pale gaps or neighboring sprite fragments were found. The background model's candidate records remove zero pixels in all eight, so the exact canonical originals are used for this framing-only repair. White shoe soles, small original sole markings and metal/skin highlights are retained.

The source sequence has a small horizontal camera-position drift when alternating curls. Both feet remain planted and the head remains upright while the forearms/dumbbells move. The general SIFT scale estimator did not pass its independently distributed feature criteria; its scale transforms were not used. An exercise-specific translation-only check independently compares the unchanged head and planted-shoe regions against frame 0. Template confidence is at least 0.898; head and foot shift estimates differ by at most 5.84 source pixels. This supports small translations but does not justify any scale or perspective change.

`prepare_hammer_translation.py` therefore applies integer translation only, followed by one common centering translation for each four-pose union. Every visible source pixel keeps exactly its original RGBA values. No resampling, zoom, color edit, alpha removal, rotation, redraw, pose fitting or anatomy change occurs. All visible pixels are preserved, none are clipped, and a minimum 16-pixel outer margin is checked. Existing drawing differences, fine edge dithering and the duplicate neutral phase remain; these are not misreported as newly synthesized smooth motion.

Full final dark/light review confirms complete dumbbells, hands, heads, shoes and ponytail, stable presentation scale, and preserved alternating curl phases. The remaining tiny original edge/sole marks do not form white background gaps and were not erased to inflate cleanup counts. The display changes are entirely image-coordinate changes; frame order, timing, list animations, exercise instructions and logging remain untouched.

`hammer-translated/integrity.json` records source and candidate SHA256 values, exact translations and per-anchor evidence. The hash-linked manifest is for these eight exact reviewed candidates only; production promotion and installation are separate operations.

Other inspected sequences are NOT accepted: Alternate Heel Touchers has dark rectangular remnants under the shoes; 3/4 Sit-Up has source framing drift and a possible flat hair boundary. Their preview artifacts are triage only.
