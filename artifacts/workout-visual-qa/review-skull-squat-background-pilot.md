# Skull Crusher and Squat: staged background review

2026-09-04, all four male and all four female frames of each exercise reviewed
on real dark/light alpha composites. This records background progress, not
acceptance of all eight frames for production.

## Band Skull Crusher (eight frames)

The guarded neural/component cleanup preserves skin, black clothing, red bands,
bench supports, bolt/highlight detail and white shoe soles. It clears bench holes,
leg gaps and most band/arm openings. The first pass missed the male frame-1 arm
triangle, female frame-0 narrow gaps between the red strands, and female frame-2
arm triangle. Those exact pale components were visually confirmed and rerun with
`background-reviewed-overrides.json`; the overrides preserve their RGB and clear
only their alpha.

Some fine edge matte remains. Female frame 3 originally clips the forward shoes;
the recovery task has created a non-generative donor-pixel extension and is
testing its final framing. Bench-anchor matching did not automatically accept
the original sequences, so background cleanup alone is not a completed exercise.
Use the final eight-frame Skull review, if present, for any promotion decision.

## Barbell Full Squat (eight frames)

All eight first-pass composites show the large opaque floor island removed and
both white shoe soles and metal highlights preserved. Their RGB arrays match
the originals before optional matte-edge processing. Thin pale silhouette
fringes and detached ground specks remain visibly present in the first pass.

An optional edge-matte trial on male frame 0 visibly reduces the white silhouette
fringe and removes detached floor specks, while leaving the white soles visible.
It changes only narrow rim colors/alpha and small detached neutral components;
it is not a new drawing. The expanded eight-frame edge trial requires its own
review before acceptance.

The source feet change spacing/shape between standing and squat poses. The
registration safety gates rejected a global zoom because independently matched
feet disagree. Do not treat bounding-box shrinkage from the squat motion as a
camera-scale change. Background improvement alone does not solve these remaining
source/framing differences.
