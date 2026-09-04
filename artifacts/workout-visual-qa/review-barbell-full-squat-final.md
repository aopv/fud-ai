# Barbell Full Squat — final staged review

Date: 2026-09-04. Reviewer: Codex visual-QA subagent. Acceptance: `background_and_framing` for all eight existing male/female frames 0–3, as a conservative background repair preserving the original motion drawings. This is agent review, not an assertion of independent user sign-off. No canonical asset has been modified by this task.

## Scope and source preservation

The exact shared originals, existing background-pilot images, all eight edge-refined-pilot previews, and final staged candidates were inspected. All eight final candidates were reviewed at native 1024×768 on both dark and light backgrounds using their `*-full-review.png` side-by-side composites. The original, pilot and final shoes were additionally inspected together at native resolution in `squat-reviewed-final/shoe-original-pilot-final-comparison.png`.

The final candidates are `squat-reviewed-final/Barbell_Full_Squat_{male,female}_v2_{0,1,2,3}.png`. The script in that directory uses only local, non-generative pixel operations. It preserves the existing athlete, anatomy, pose, clothing, barbell, hair, plate design and source perspective. No image generator, paid API, redraw, limb warp, new source image, resampling, or alignment fitting was used.

Base inputs are the eight root-cleaned `background-pilot/images` PNGs. Root edge-matte refinement is followed by an additional constrained white-matte pass only on neutral pale rim pixels within 2.25 pixels of existing transparency and 3.5 pixels of a reliable dark outline. Real shoe artwork and each frame's polished barbell shaft band are explicitly protected. The complete connected foreground within these protected regions remains RGBA-identical to the input. Deep artwork interiors are also asserted RGBA-identical, and alpha can only decrease. Tiny detached neutral floor specks are removed, including those falling inside the protection rectangles; they are not connected footwear or metal artwork.

An unprotected trial was rejected because it could treat narrow polished bar highlights as matte. The final files protect those exact regions; the trial files were superseded before hashing and were never promoted. The black dash patterns in the shoe soles were checked against the original illustrations and already exist there; they were not introduced by cleanup.

## Background and details

The broad opaque white floor islands have been removed in all eight frames. The space between the legs, around/under the arms and around the equipment reveals the chosen background, and no large opaque white/checkerboard patches remain. White shoe soles, stripes, bar highlights, spring collars, hands, both feet, and all plates remain visible and complete. There are no neighboring sprite fragments or cropped extremities.

Some approximately one-pixel pale antialias remnants remain at high-contrast boundaries, especially protected shoe/metal edges. These were deliberately not aggressively eroded, recolored or cut away because foreground preservation is more important than eliminating every ambiguous subpixel. The final dark-contact appearance is materially cleaner than the original and first background-only pilot. This is not a claim of mathematically perfect edge matting.

## Sequence framing decision

All eight retain the same 1024×768 canvas, source coordinates and identity transform: scale 1, translation (0,0). No frame was independently zoomed or centered, and no moving-foot anchor was forced to match.

The barbell's horizontal span remains approximately stable while its vertical position follows the shoulder motion. Frame 0 is standing, frame 1 descends, frame 2 is the deep squat, and frame 3 rises. The decreasing full-figure height in frame 2 therefore represents the pose, not camera shrinkage. The common pose union already fits inside the shared canvas with complete bar ends and feet; another union fit would add resampling without fixing a real clipping defect.

Minor stance/foot-shape and bar/plate drawing differences remain intrinsic to the separately drawn original frames. They do not justify a global zoom or anatomy warp. No material change of viewpoint requiring rejection was found in the reviewed sequence. This acceptance covers preserved source-pose presentation, not newly perfected skeletal animation.

## Integrity and handoff

`squat-reviewed-final/verification.json` records each exact candidate hash, original shared hash, source-cleanup hash, alpha bounds, protected rectangles, preservation assertions and shared identity transform. All eight are single-frame RGBA PNGs with actual alpha extrema 0–255, exactly 1024×768, and no visible pixel touches the canvas border. The hash-linked promotion manifest covers exactly the existing eight names.

The promotion helper must be run read-only with `--check` before any later application. This QA task performs no application, commit, push, build, install, or UI interaction. Existing pilots, other exercises and production assets remain untouched.
