# Trees v2 - the last block-resident living thing leaves the grid

> **SUPERSEDED by [`trees-v3.md`](trees-v3.md)** (Marcel's rulings,
> 2026-09-01 evening). The fates of this plan's decisions: the diagnosis,
> the placement hard rule and the Stage 0 audit list stand and are carried
> forward; decision 5 (no purchased pack) is OVERTURNED - the pack's .vox
> sources, not its chamfered meshes, become the tree library through the
> game's own mesher; decision 2 and hard rule 3 (trunk stays blocks) are
> OVERTURNED for whole-tree models; decision 6's impostors are replaced by
> geometry-all-the-way (no cards); and the public build now ships treeless
> by design. Author new work against trees-v3, not this file.

Written 2026-09-01 against `main` at `2e92fef`, from Marcel's ruling of the
same evening. **NOT SCHEDULED.** This plan collides with distance v4 and the
C++ mesher port, both in flight; *Sequencing* below says when it can run and
what has to be true first. It is written now because the ruling is made and
three other sessions are authoring against the old one.

**What this epic is for, in one line:** trees are the only living thing in
Kubik still built out of terrain, and tonight they stop being.

## The ruling

Marcel, 2026-09-01, shown the purchased Voxel Viking templates and the
forest-animal pack standing in the world: the characters *"almost don't fit
the world"* - and asked which side should move, he ruled for the models.
**This character model is the level of detail and size the game is.**

The world does not get finer. `block_size` stays 0.5 m
(`worldgen_config.gd:36`) and `world_scale` stays 4; relitigating either was
already refused once in world feel v1 and the reasons have not changed.
What moves is everything that is *alive*.

## The diagnosis - one ladder, and trees are off the bottom of it

`DESIGN.md:318` has said since character v1 that a model voxel is 1/24 of a
block and a human is 96 of them: *"two systems, not one, and they meet only
in the material and the mesher."* Foliage v1 built the second system -
`FloraModels`, a decoration layer that never enters a chunk, never enters the
mesher and never enters the edit dictionary - and gave it a resolution ladder
per model (`FloraModels.voxels_per_block`):

| | voxels/block | voxel | what |
| --- | --- | --- | --- |
| Plants | 8 | 6.25 cm | grass, flowers, ferns, mushrooms, reeds |
| Shrubs | 4 | 12.5 cm | `SHRUB_A`, `SHRUB_B` |
| Boulders | 2 | 25 cm | `BOULDER_S/M/L`, scree |
| **Trees** | **1** | **50 cm** | ← world blocks. Not on the ladder at all. |

A character is 24x finer than the ground. A grass tuft is 8x. A boulder is
2x. A tree is 1x, because a tree *is* the ground - `TreeSpecies` stamps
`Block.LEAVES` and `Block.TRUNK` into the chunk volume through `ChunkWriter`.

That single row is the whole of what Marcel is looking at. It is not a tree
problem and it was never a character problem; it is one unfinished ladder.

`DESIGN.md:505` even gives trees their own row in the read-against table -
**1:2, the only object read against both the valley and the player** - which
world feel v1 added because a tree at 1:4 *"read as a shrub you happened to be
standing near."* Trees got a bespoke read-scale in August and never got a
bespoke resolution. This plan is that missing half.

## Decisions this plan makes

1. **Trees join the decoration layer at 4 voxels per block - 12.5 cm.**
   The same rung as shrubs, which is the only defensible answer: a sapling and
   a shrub are the same object at two ages and must not be built at two
   resolutions. 4x finer than today.

   *Not 8.* `FloraModels` already measured what 8 costs on a large model - a
   3 m boulder came to **35,964 triangles**, "one rock costing more than two
   hundred grass tufts" - and a tree is larger than a boulder and there are
   73,675 of them on seed 42.

2. **The trunk stays blocks.** `Block.TRUNK`, `TRUNK_BIRCH`, `TRUNK_DEAD` are
   untouched, and so is every trunk column the shapes draw. This is not a
   compromise; it pays for itself three times:

   - chopping, collision and occupancy keep working with no new system, and
     the volume stays authoritative for everything gameplay reads;
   - the border-safe stamp survives for the part that needs it;
   - it solves the MultiMesh tint problem foliage v1 already hit. A
     MultiMesh's one per-instance colour multiplies the *whole* model - the
     reason there are four flower models rather than one green-stemmed one.
     A canopy-only mesh means per-instance leaf colour can never discolour
     bark, and seasonal and biome tint become a free instance channel.

3. **`TreeSpecies.params_for()` survives; only the writer changes.** The
   shape intelligence - whorls, shelves, clumped fill, lean, bites, forks,
   hero scale parents - is pure by construction and stays. `ChunkWriter`
   keeps drawing trunks. A new canopy consumer reads the same params and
   selects models instead of setting blocks. **The placement half
   (`tree_placement.gd`) is not touched at all**: same heightmap hash, same
   tree count, same species mix, same spawn. Trees v1's sentence, one layer
   down.

4. **Variety moves from unique geometry to `variant library x rotation x
   tint`.** A MultiMesh needs shared meshes and today every tree is
   geometrically unique. This is the one real thing being given up, and
   `FarTreeMeshes` already proves the trade: nineteen meshes draw two
   thousand trees in seven draw calls. Free Y rotation, jitter and per-instance
   tint are three axes of variation the block grid never allowed, and they
   more than pay back the loss.

5. **No purchased tree pack.** Recorded because Marcel asked and the answer
   should not have to be re-derived: the 101-tree pack under evaluation is
   *chamfered low-poly mesh*. The characters are voxels, the plants are
   voxels, and the canopy will be voxels through the same mesher and palette.
   Buying it would put a third surface language in the game, against the
   lesson `FarTreeMeshes:20` already paid for once - the six-sided cone whose
   *"outline was right and the surface was from a different game."*
   Kubik's trees are generated, and after this epic they are generated four
   times finer.

6. **The impostors are re-derived, not retuned.** `FarTreeMeshes` pins its
   colour to `Block.COLORS` shade A precisely so near and far cannot drift.
   When the canopy stops being blocks that pin no longer points at anything,
   and the ring will draw a circle on the hillside at the voxel radius - the
   exact artefact the ring exists to remove. Stage 5 is not optional.

## What this buys

- The ladder closes. Characters go from 24x their neighbours to 3-6x.
  **Nothing about the characters changes** - they were never the thing that
  was wrong.
- Wind sway becomes available: the canopy is a mesh with its own material,
  so a vertex shader displacing by `sin(time + worldpos)` is a material
  change, not a mesher change.
- Free Y rotation and sub-cell jitter, neither of which a block tree can have.
- Seasonal and biome colour as an instance channel rather than as new
  `Block` ids.
- **Meshing should get faster.** `FloraModels:9`: *"greedy meshing and
  per-block variation do not mix."* Leaf blocks come in shade A/B pairs
  scattered per block, which is exactly the pathology ground cover was moved
  off the grid to escape, and trees v1 measured it - a max larch is 791
  blocks but 2,049 quads. Taking canopies out of the volume removes the worst
  input the mesher is handed, and it removes it just as that mesher crosses
  to C++.
- Chunk memory falls by every leaf block in the world.

## What it costs

- **Leaves stop being blocks.** No harvesting a leaf block, no building with
  one, and a canopy no longer occludes, collides or shades as voxels. Stage 0
  audits what depends on that before anything moves.
- **The impostor ring must be re-derived** (decision 6), and it is the thing
  Marcel has been tuning for three nights.
- `TreeSpecies` is 3,383 lines and roughly half of it - every shape function
  below the params - is rewritten against a model builder instead of a
  block writer.
- Canopy triangle budget is a real risk and Stage 1 is where it is measured,
  not assumed.

## Hard rules

1. **Placement does not move.** Same heightmap hash, same 73,675 trees on
   seed 42, same species mix, same spawn, reprinted after every stage. A
   stage that changes a tree's *position* has a bug, not a feature.
2. **Determinism is not negotiable.** Both machines still compute the same
   forest from the same cell hash. Canopy variant, rotation, jitter and tint
   are all hashed from the cell - never drawn from a stream, never stored,
   never synced.
3. **The trunk is the tree, as far as gameplay is concerned.** Anything that
   asks "is there a tree here" asks the volume. The canopy is art.
4. **Every stage runs `godot --headless --path . scenes/selftest.tscn`.**
5. **No look change ships by editing a `WorldgenConfig` default** - the F4
   panel saves `user://worldgen.tres` and it shadows defaults forever after.
   New constants or new properties only.

## Sequencing - when this can run

This plan is blocked, and on purpose:

- **Distance v4 must land first.** It is in flight, it is the far mesher, and
  Stage 5 here rewrites the far forest's colour source. Running both at once
  means two sessions editing the ring's look on the same night.
- **The C++ chunk mesher (`chunk_mesher.gd`, rung 2 of the port) should land
  either well before or well after.** This epic *removes* its worst input, so
  measuring the port against a canopy-laden mesher and then deleting the
  canopies makes the port's own numbers a lie.
- **Against the Next 3:** this jumps wave 1 (creatures, combat, water) and the
  argument is trees v1's own, verbatim - an art direction is cheap now and
  dearer with every part authored under the old one. The creature pack is
  bought and unmounted; the character templates are in. Every one of those
  will be posed in front of a forest. But the ruling is only hours old and
  nothing is authored against it yet, so the honest reading is that this is
  **cheap for another week or two, and the queue wins for now.**

## The stages

Sketch, not yet a night. Each becomes a real stage when this is scheduled.

- **Stage 0 - The instruments and the audit.** Extend the model gallery to
  photograph a canopy model beside the player capsule. Grep every consumer of
  `Block.LEAVES*` and write down what breaks. Reprint the invariants.
- **Stage 1 - The canopy builder, and the budget.** One spruce canopy as a
  voxel model at 4/block. Measure triangles. If a canopy is dearer than the
  boulder's 35,964, the ladder rung is wrong and 2/block is the answer -
  decide it here, on a number, before six more species are written.
- **Stage 2 - Spruce end to end.** Canopy off the grid, trunk still blocks,
  MultiMesh through the existing `flora_job` / `flora_column` path, variant
  chosen and rotated from the cell hash. One species in the world, in the
  gallery, and in a tour.
- **Stage 3 - The other six.** Beech, larch, krummholz, birch, snag, hero.
  The snag is nearly free - it has no canopy.
- **Stage 4 - The seam.** Chopping, collision and occupancy against a
  canopy that is no longer in the volume. Whatever Stage 0's audit found.
- **Stage 5 - The impostors, re-derived.** `FarTreeMeshes` colour re-pinned
  to the canopy palette; the near/far seam re-measured at the voxel radius.
- **Stage 6 - Sway.** The thing this whole epic makes possible, and the
  cheapest large win in it.
- **Stage 7 - The world, the docs and the merge.** `DESIGN.md`'s ladder table
  gains its fourth row; `foliage-v1.md` gets a forward pointer; STATUS.

## Open questions

1. **4 or 2 voxels per block** - Stage 1 decides it on a triangle count, not
   here.
2. **How many canopy variants per species** buys enough apparent variety.
   `FarTreeMeshes` needed one shape per species at 150 m; the near field will
   need more. 6-10 is the guess.
3. **Does the hero still work?** It scales 16-42 blocks off a parent species.
   A variant library may need its own rung for heroes rather than reusing the
   spruce's at 2x.
4. **Does anything want leaves to stay blocks** - canopy shade under a forest,
   a player on top of a crown, rain occlusion. Stage 0's audit answers it and
   may send one of these decisions back.
