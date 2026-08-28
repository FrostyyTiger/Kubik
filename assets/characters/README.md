# Character art drop-ins

**This directory ships empty on purpose.** A `.vox` committed here would
silently override an ASCII part for everyone, which is exactly the surprise the
drop-in rule exists to make convenient rather than to inflict.

## The rule

If `assets/characters/<race>/<part>.vox` exists, it replaces the ASCII part of
that name at load. No code change to swap art.

    assets/characters/human/head.vox        replaces PartsHuman.HEAD
    assets/characters/dwarf/beard.vox       replaces the dwarf's chosen beard
    assets/characters/lizardfolk/tail_2.vox replaces the middle tail segment

Part names are the keys of the race's part set: `head`, `torso`, `pelvis`,
`leg`, `arm`, `hair`, `beard`, and `tail_1..3` for the lizardfolk. `leg` and
`arm` are authored once and mirrored, so replacing one replaces both.

## Authoring rules

**Palette indices 1 to 19 are the nineteen slots**, in the order
`VoxelModel`'s enum declares them:

    1 skin        2 skin shaded   3 hair/crest   4 iris        5 eye white
    6 mouth       7 cloth         8 cloth dark   9 leather    10 belt
   11 tooth/claw 12 metal        13 wood        14 liner      15 skin ventral
   16 trim bright 17 metal dark   18 scale A     19 scale B

A drop-in is loaded WITH that convention, so it takes skin and hair swaps
exactly as an ASCII part does. A `.vox` authored in arbitrary colours will
still load - every index outside 1..19 becomes skin - but it will not respond
to the creation screen's palette pickers, so build the model against a palette
whose first nineteen entries are the legend above.

**It was 13 until character v2 Stage 1**, and the six new ones are appended
rather than inserted precisely so that a model authored against the old legend
still reads correctly for indices 1 to 13. Slot indices are a contract with
every `.vox` anyone has ever exported and they are never renumbered.

The last six, and what each is for:

- **14 liner** — a fixed near-black, `#14100C`, at every boundary where skin
  meets cloth: collar, cuff, waist, boot top. It is what carries the contrast
  in this palette, so the cloth does not have to. Never a player pick, never
  any other value. One or two voxels is enough.
- **15 skin ventral** — countershading. The belly, throat and underside of a
  tail, derived from the wearer's own skin lightened, so it tracks a skin
  swap. Dark above and light below is the single strongest signal that a thing
  is an animal rather than a person in a costume.
- **16 trim bright / 17 metal dark** — a bright rim voxel sitting on a dark
  body, one voxel of relief between them. That pair, across a real geometric
  edge the mesher's AO darkens, is the whole of how metal reads here. Do not
  paint highlights: the mesher bakes its own corner AO, and hand shading on
  top of it double-darkens every concave corner.
- **18 scale A / 19 scale B** — two adjacent values for a one-voxel checker,
  for mail and for chitin. At 5 m you see individual scales; at 15 m the
  checker averages to one flat mid-tone, which is what mail looks like from
  across a field. Free LOD, and the one place a value pattern is right.

**Orientation.** MagicaVoxel is Z-up and its Y runs into the screen; this game
is Y-up and faces `-Z`. The loader maps `x -> x`, `z -> y`, `y -> z`, so the
face of your model should be at MINIMUM Y - the side you look at in
MagicaVoxel's default view. If your models come out back to front,
`VoxLoader.FLIP_DEPTH` is the one line to change.

**Scale.** One model voxel is **2.083 cm, twenty-four to a block**. A human is
**96 voxels** tall; see `Races.TABLE` for every race's dimensions.

> **This changed in character v2 and it is a break.** It was 3.125 cm and 64
> voxels, sixteen to a block. A `.vox` authored against the old grid loads at
> **two thirds** of its intended size, silently, because the format carries no
> scale and there is nothing to compare it against but the part it replaces.
>
> There is no compatibility path and deliberately none: MagicaVoxel writes no
> scale metadata, so a sidecar file declaring one would be a format nobody has
> ever written a file for. This directory ships empty, so the break costs
> exactly nothing today - which is why the grid moved now rather than after the
> first model landed.
>
> What the loader does do: it compares a replacement's bounding box against the
> ASCII part it stands in for and warns when they differ by more than about a
> third, naming the old grid as the likely cause. It warns rather than
> rejecting, because art being a different shape is the entire point of a
> drop-in.

**The pivot** is inherited from the ASCII part being replaced, because a `.vox`
file carries no anchor and inventing one from the bounding box would put a
replacement head's pivot somewhere the bone table does not expect. Model your
replacement in the same box as the original.
