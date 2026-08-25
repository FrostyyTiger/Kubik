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

**Palette indices 1 to 13 are the thirteen slots**, in the order
`VoxelModel`'s enum declares them:

    1 skin        2 skin shaded   3 hair/crest   4 iris        5 eye white
    6 mouth       7 cloth         8 cloth dark   9 leather    10 belt
   11 tooth/claw 12 metal        13 wood

A drop-in is loaded WITH that convention, so it takes skin and hair swaps
exactly as an ASCII part does. A `.vox` authored in arbitrary colours will
still load - every index outside 1..13 becomes skin - but it will not respond
to the creation screen's palette pickers, so build the model against a palette
whose first thirteen entries are the legend above.

**Orientation.** MagicaVoxel is Z-up and its Y runs into the screen; this game
is Y-up and faces `-Z`. The loader maps `x -> x`, `z -> y`, `y -> z`, so the
face of your model should be at MINIMUM Y - the side you look at in
MagicaVoxel's default view. If your models come out back to front,
`VoxLoader.FLIP_DEPTH` is the one line to change.

**Scale.** One model voxel is 3.125 cm, sixteen to a block. A human is 64 voxels
tall; see `Races.TABLE` for every race's dimensions.

**The pivot** is inherited from the ASCII part being replaced, because a `.vox`
file carries no anchor and inventing one from the bounding box would put a
replacement head's pivot somewhere the bone table does not expect. Model your
replacement in the same box as the original.
