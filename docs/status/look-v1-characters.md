# Look v1, Stage 6 — characters at a finer voxel

Run status for Stage 6 of `docs/plans/look-v1.md`, 2026-08-25, on Marcel's
Windows box (Forward+, RTX 5080 — for once the renderer the sheets are
judged on). To be folded into `docs/status/look-v1.md`.

---

## What shipped

- **One model voxel is 1/16 of a block, 3.125 cm.** `VoxelModel.VOXEL_M`
  halved; a human is 64 voxels = 2.00 m. Plants stay at 1/8.
- **Every race is stocky.** `Races.HAS_LEAN` is all false,
  `parts_human_lean.gd` is deleted. The `build` byte stays on the wire and
  in the save file and clamps to stocky; `WIRE_VERSION` is still 1.
- **Every part re-authored** in the plan's Stage 6 proportions and forms:
  chamfered octagonal heads with stepped jaw and crown, stepped shoulders,
  hands and boots a voxel proud of the limb, 4 x 4 eyes with a 2 x 2 iris
  low and inboard, a brow row, a 2 x 3 x 1 nose, an 8-wide mouth. Hair as
  stepped Deco masses: a cap wrapping the crown, a hard-lined fringe, a
  flat-bottomed bob, notched braids, a sunburst crest.
- **A generator writes the ASCII.** `tools/parts_author/` (Python 3, no
  dependencies): `voxlib.py` is the kit, one module per race plus
  `hair.py`, `gear.py`, `critter.py`; `python -m tools.parts_author` writes
  the seven `parts_*.gd` files complete with their docstrings. The runtime
  never sees Python. Both generator and output are committed and every
  generated file names its generator in its header.
- **The self-test suite passes**: 28 tests, all passed, at `HEAD`.
- **51 gallery sheets** in `build/character/look-6-characters/`.

## Judgement calls, and why

1. **The crests are the v1 size in metres, not the plan's "8 tall".** The
   plan's table doubled every v1 number for the new voxel except the
   crest's, which it halved by writing "8" where the v1 crest was 7 at the
   old scale (14 at the new). The first sheets showed a crest a quarter the
   area it had been, and the human/lizardfolk mask went from v1's 0.868 to
   0.941. Restored: the low fin is 6 x 14, the tall one a 22-tall sunburst
   widening from 6 to 16, the frill 24 x 18 x 4. The number came back to
   0.913 (see below).
2. **The tabard is one voxel proud, not the plan's two.** The dwarf's
   default beard hangs over its chest; at two voxels the placeholder put 128
   voxels inside it. Every dwarf beard now hangs between the face plane
   (z = -8) and the pendant (z = -11), and the tabard sits at the torso's
   front face plus one - which is exactly where v1 had it.
3. **The pendant hangs eleven voxels in front of the neck.** It has to clear
   the dwarf's torso (7 deep) AND its beards; it therefore floats a long
   way proud of a human or elf chest. The gear file says so. Zero
   intersection on all four races is the placeholder's whole job.
4. **The human's short beard stays in front of the chest.** First draft
   reached back under the chin to z = -2, which is inside the torso's top.
   Every beard now ends at z = -6 or further forward.
5. **The height test measures the rig stood upright.** The lizardfolk's 8
   degree lean tilts its head's bounding box two voxels higher at the back
   than the crown, which is inside v1's one-voxel tolerance at 6.25 cm and
   outside it at 3.125 cm. The table's number is the crown height standing
   straight, so the test zeroes the hips pitch, measures, and puts it back.
   Not a weakening: it measures what the table claims.
6. **The tail's first link sits two voxels above the hip pivot**, was one:
   the same metres.
7. **`CharacterConfig.USER_PATH` moved to `character_tuning_v2.tres`.** Every
   `_vox` knob (bob, land squash, breath, sit lift, downed lift) doubled so
   its metres did not change, and the F8 panel's ranges doubled with them. A
   v1 tuning file loaded into v2 would move everything half as far, so it
   is not read.
8. **The triangle budget is one constant, `CharacterConfig.TRIANGLE_BUDGET
   = 24000`**, read by the height self-test and the gallery's budget sheet.
   6000 x 4 for the surface, plus the chamfers and the hands.
9. **The gallery's lineup and study sheets lost the lean human**, and the
   study's 4 m pair is now the human and the dwarf. The creation screen
   hides the build row when no race has a second scheme.
10. **The critter is the v1 ASCII scaled exactly x2.** It is a test rig and
    the only thing that matters about its shape is that it is unchanged.

## Every measured number

### Heights, at `HEAD`

| race | table | measured | with hair or crest |
| --- | --- | --- | --- |
| human | 2.00 m | 2.0000 | 2.06 |
| elf | 2.25 m | 2.2500 | 2.31 |
| dwarf | 1.50 m | 1.5000 | 1.56 |
| lizardfolk | 1.875 m | 1.8750 (upright) | 2.31 |

### Triangles, mesh, default hair and beard

| | character v1 (1/8) | look v1 (1/16) | x |
| --- | --- | --- | --- |
| human | 3308 | 16824 | 5.1 |
| elf | 2848 | 13824 | 4.9 |
| dwarf | 4104 | 17740 | 4.3 |
| lizardfolk | 3564 | 16544 | 4.6 |
| critter (not a budget) | 1820 | 7280 | 4.0 |

Drawn is exactly twice mesh on every row (the shadow pass), as in v1. The
dwarf is the worst at 17740 against the 24000 budget; four players with
gear are roughly 75k mesh triangles, under the far field's own 80k.

### Silhouette IoU at 40 m

Front on, the judged view. Target: every race pair under 0.70.

| pair | v1 | look v1 | |
| --- | --- | --- | --- |
| human / elf | 0.608 | 0.530 | |
| human / dwarf | 0.561 | 0.561 | |
| **human / lizardfolk** | **0.868** | **0.913** | **over** |
| elf / dwarf | 0.372 | 0.357 | |
| elf / lizardfolk | 0.580 | 0.534 | |
| dwarf / lizardfolk | 0.593 | 0.566 | |
| *human / capsule* | *0.732* | *0.702* | *reference* |
| *elf / capsule* | *0.444* | *0.492* | *reference* |
| *dwarf / capsule* | *0.661* | *0.584* | *reference* |
| *lizardfolk / capsule* | *0.725* | *0.694* | *reference* |

Three-quarter on, reported and not judged: human/elf 0.647, human/dwarf
0.566, human/lizardfolk 0.769, elf/dwarf 0.418, elf/lizardfolk 0.661,
dwarf/lizardfolk 0.502.

Across every hair and beard option, front on: 94 cross-race variant pairs,
15 over 0.70, and every one of the 15 is human-vs-lizardfolk, exactly as in
v1. Per crest against the default human: low fin 0.913, sunburst 0.841,
frill 0.917; the sunburst against the human's bob is the best pair at
0.792.

**The human/lizardfolk pair is over, as it was in v1, and for the reason v1
recorded:** the lizardfolk's body IS the human's body by design, so that
the silhouette test can tell which feature is doing the work, and two of
its three features - the tail and the snout - are profile features a
front-on mask cannot see. The crest is the only front-on lever and this run
pulled it as far as a crest goes (a 22-tall sunburst is 0.841). v1 left
three ways forward as Marcel's call, and this run does not take one either:
it is a body decision, not a resolution decision, and it is outside this
stage. Every other pair separated further at the finer voxel than it did at
the coarser one.

## Tuned blind

Nothing in this stage was tuned blind: the sheets were shot and judged on
the Forward+ renderer Marcel plays on. The v1 "Tuned blind" table still
applies to every colour and every animation amplitude, which this stage
did not touch except to double the `_vox` knobs.

Judged on the sheets, in `build/character/look-6-characters/`:
`study-detail-4m-*` (the face, the chamfer, the hands),
`closeup-front/three-quarter/profile` (the lineup, the ears, the snout
and tail), `variants-*` (every hair and beard), `gear.png`,
`anim-human-poses.png` (sit and downed with the doubled lifts),
`masks-40.png` and `silhouettes-*`.

The dusk sheets are near-black. That is the lighting, not the characters -
Stage 1 of the plan replaces it - and it was near-black in v1 too.

## Left for the main status doc and for Marcel

- `DESIGN.md`'s race table and "Art pipeline" paragraph still say 1/8 and
  32 voxels; Stage 8 of the plan owns that edit.
- The human/lizardfolk front-on silhouette, above.
- `assets/characters/README.md` says 3.125 cm now; a `.vox` drop-in
  authored at the old scale will load at half size, which is what the
  drop-in rule promises (it takes the ASCII part's anchor, not its size).
