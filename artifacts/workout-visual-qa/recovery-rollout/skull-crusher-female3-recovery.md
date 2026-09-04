# Band Skull Crusher female frame3 source check

**The shoe clipping is intrinsic to the original generated image, not introduced by normalization.** A larger/repositioned crop cannot recover pixels that are absent from the original canvas.

## Provenance

- Wave registry exercise: `Band_Skull_Crusher`, slot26.
- Original generation task: `01a05d35-f69e-7912-bd85-0163e1e7586d`.
- Completed staging directory: `/Users/apoorvdarshan/workout-art-waves/wave-001/exercise-026-Band_Skull_Crusher/`.
- Exact original matching current female frame3: `/Users/apoorvdarshan/.codex/generated_images/01a05d35-f69e-7912-bd85-0163e1e7586d/exec-598b751f-09a3-46f7-b58f-fabaf978a83b.png`.
- Original dimensions: **1448×1086**.

## Evidence

All ten original task outputs were reviewed in `skull-crusher-originals-contact.png`. The matching female3 source was also inspected individually at full size. The two shoes run directly into the right canvas boundary; their toe outlines do not close inside the image.

A read-only right-edge pixel scan finds **64 pixels with max(R,G,B)<160 at x1447**, in y819–904, corresponding to the cut shoe tips. Samples include `(1447,850)=(13,12,12)`, `(1447,880)=(33,33,32)`, and `(1447,900)=(36,34,34)`.

The source also contains baked checkerboard background. Non-generative cleanup can remove that background and improve placement, but cannot reconstruct the missing tips solely from this original. Copying matching shoe pixels from a different existing frame would be a separate explicit compositing decision, not original-source recovery, and was not attempted here.

No canonical asset was changed.
