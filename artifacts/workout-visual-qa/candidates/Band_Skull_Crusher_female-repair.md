# Female Band Skull Crusher built-in repair attempt

Status: **rejected; canonical assets unchanged; frames 1–3 not attempted**.

Mode: built-in image generation/editing only. No pixel cleanup, resizing, compositing, or alignment scripts were used. The candidate was copied byte-for-byte into this folder.

## Source and output

- Edit source: `shared/workout-vectors/Band_Skull_Crusher_female_v2_0.png`
- Generated output: `/Users/apoorvdarshan/.codex/generated_images/01a06c56-ab8a-74e2-9d37-046d8cb9dd72/exec-2c9bbae7-2089-43ba-b221-88d27efae6ad.png`
- Preserved rejected candidate: `Band_Skull_Crusher_female_v2_0-rejected-rgb.png`

## Prompt

```text
Use case: background-extraction
Asset type: Fud AI exercise animation frame 0 of 4, Band Skull Crusher, female.
Input image 1: the exact edit target. Preserve its recognizable athlete, charcoal clothing, muted-red piping, ink/cel-shaded illustration style, exact exercise pose, red resistance band, black bench and equipment details.
Primary request: make a clean production cutout. Remove ALL baked white and light checkerboard background including enclosed spaces: the triangle between bent arms, face and red band; the long thin space between the two red band strands; space around ponytail and equipment; the circular holes through the bench side rail; beneath the bench and between legs/feet. Every such opening must be genuine transparent alpha, not white, not a checkerboard drawn into the bitmap.
Keep the actual pale shoe soles, shoe stripes and highlights opaque, and keep the light skin tones unchanged. Preserve fine black outlines and band strands without halos.
Composition/framing: keep the exact target framing, fixed side-on camera and identical bench position, size, ground line and athlete scale. All shoes, hands, hair and equipment fully visible. This is the alignment master for a 4-frame cycle. Do not zoom, crop, redraw the pose or alter anatomy/equipment.
Output: one PNG with genuine transparency, exact pixel dimensions 1024 wide x768 high (4:3 landscape). No text, arrows, logos, floor, shadows, background color or drawn checkerboard.
```

## Read-only QA

The returned image was displayed and inspected. Pillow read-only metadata inspection reported:

```json
{"mode":"RGB","size":[1448,1086],"bands":["R","G","B"],"alpha_extrema":null,"transparency_info":null,"corner_pixel":[254,254,254]}
```

- FAIL: requested exact 1024×768, returned 1448×1086.
- FAIL: no alpha channel or transparency metadata.
- FAIL: checkerboard is baked into the exterior background and enclosed gaps.
- Visual subject/style/pose broadly preserved, but the strict production requirements failed; no promotion is allowed.
- All four original female source frames were inspected before the edit. Original frame 3 additionally shifts the bench/athlete framing and clips the right shoe; any later repair should align to a successful frame-0 master.

The remaining three calls were paused after the first failed output to avoid creating more unusable candidates. Parent agent is testing a single targeted retry on the male sequence.
