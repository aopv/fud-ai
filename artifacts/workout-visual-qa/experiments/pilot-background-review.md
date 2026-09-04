# Pilot background review: Ab Rollout and Kipping Muscle Up

Scope: compare all 16 original source PNGs with the root task's guarded-cleanup candidates on dark and light backgrounds. This is background review only, not animation alignment or full-exercise acceptance. No canonical files were changed by this reviewer.

## Barbell Ab Rollout

All eight candidate previews were viewed at full 2048x768 dark/light presentation. Every candidate has zero changed RGB pixels and only reduced alpha compared with its original source. Main white/checkerboard gaps are cleared; no new body, bar, plate, or shoe-sole damage was observed. Thin pale one-pixel contour fringes remain visible on dark backgrounds and need a separate edge pass if zero matte fringe is required.

| Frame | Background result | Remaining issue | Foreground damage |
| --- | --- | --- | --- |
| Male 0 | Large arm/leg enclosed whites cleared | Thin contour fringe | None observed |
| Male 1 | Enclosed arm white cleared | Thin contour fringe | None observed |
| Male 2 | Enclosed arm white cleared | Thin contour fringe; 24 guarded uncertain pixels retained | None observed |
| Male 3 | Arm/leg whites and most floor cleared | Tiny pale floor flecks and thin contour fringe | None observed |
| Female 0 | Large arm/leg enclosed whites cleared | Thin contour fringe | None observed |
| Female 1 | Enclosed arm white cleared | Thin contour fringe | None observed |
| Female 2 | Enclosed arm/underbody white cleared | Thin contour fringe | None observed |
| Female 3 | Main enclosed white cleared | Visible detached pale floor flecks below left shoe near x850,y720; thin contour fringe | None observed |

Candidate acceptance: background improvement verified, but residual floor/edge cleanup and motion review remain. Do not mark the whole exercise fully fixed from this report.

## Kipping Muscle Up

All eight original frames and all eight candidate dark/light previews were viewed. Every candidate has zero RGB pixel changes and alpha only decreases. No new body, strap, ring-rim, or shoe-sole damage was observed. The cleanup preserves, rather than repairs, the original slicing defects below.

| Frame | Background result | Remaining issue |
| --- | --- | --- |
| Male 0 | Most floor patch removed | Both ring interiors remain opaque white (960 and 706 pixels); floor specks and contour fringes remain |
| Male 1 | Ring interiors cleared | Small ring/strap fringe remains; original lower-leg/foot crop unchanged |
| Male 2 | Small pale gaps cleared | Unrelated detached partial shoe/leg remains; thin contour fringe |
| Male 3 | Ring interior mostly cleared | Seven retained pale pixels in left ring hole; thin contour fringe |
| Female 0 | Ring interiors and strap-region checkerboard cleared | Detached shoe fragment and tiny floor flecks remain; thin contour fringe |
| Female 1 | Large checkerboard rectangle and ring holes cleared | Original forward-shoe crop unchanged; thin contour fringe |
| Female 2 | Pale strip between straps cleared | Minor contour/strap edge fringe |
| Female 3 | Pale strip and most distant floor patches cleared | Tiny detached floor specks remain far below body; contour/strap fringes |

Candidate acceptance: not accepted as a complete exercise. Male 0 visibly fails enclosed-background cleanup, and multiple frames require source recovery. No alignment acceptance is implied.

Original-source defects unrelated to the cleanup:

- Male 1: lower legs/feet cut off at approximately x657 despite a wider transparent canvas.
- Male 2: unrelated detached partial shoe/leg at approximately x375,y700.
- Female 0: detached shoe fragment at approximately x580–613,y628.
- Female 1: forward shoe cropped at the left artwork cutoff around x346; large checkerboard rectangle remains.
- Female 3: detached gray floor artifacts far below the body.

These look like sprite-sheet slicing problems and prevent full-exercise acceptance even if the pale background is cleaned. Source recovery or explicit artifact removal is required; missing limbs cannot be reconstructed by alpha cleanup or alignment.

## Reviewed enclosed-hole overrides

The separate `../background-kipping-rollout-overrides.json` supplies only reviewed pale-background seeds, using the current canonical 1024x768 coordinates. Do not reuse coordinates on recovered/resized source images without revalidation.

- Kipping male 0: `[477,144]` selects the left ring opening (960 pixels); `[540,151]` selects the right opening (706 pixels). Both centers are source RGBA `[250,250,250,255]`, and both whole components remain opaque in the pilot.
- Kipping male 3: `[463,455]` selects the 370-pixel left ring opening, including seven retained guard pixels. Source RGBA is `[249,249,249,255]`.
- Ab Rollout male 2: `[365,585]` selects the 7,409-pixel enclosed arm-gap component, including 24 retained guard pixels. Source RGBA is `[253,253,253,255]`.

These seeds do not select shoes, skin, or ring rims. They have not been applied by this reviewer.

For the residual fringe/floor pass, consider at most a one-pixel exterior neutral-alpha cleanup and removal of detached tiny neutral components. Preserve connected white soles, metal highlights, and skin; never drop colored detached fragments automatically. Every resulting candidate still needs dark/light review.
