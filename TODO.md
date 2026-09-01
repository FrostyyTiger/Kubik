# TODO

The queue, as a checklist. Why it is in this order, what each epic contains,
and the pushbacks are in `docs/ROADMAP.md`. `docs/IDEAS.md` Next 3 stays the
authority for what runs next. Tick things here; rewrite the reasoning there.

Lanes marked `||` run in parallel with zero-overlap file lists. `game.gd`
has one owner per wave; everyone else adds a file plus a one-line hook.

## Wave 0 - now

- [x] `feat/flora-streaming` lands on main (merged 2026-08-25)
- [x] **A. Look v2** - ran 2026-08-25, merged (`docs/plans/look-v2.md`)
- [x] **A2. World feel v1** (2 nights, `docs/plans/world-feel-v1.md`) - **DONE** on `feat/world-feel-v1`, 2026-08-27. Night 1: one job per column, the frontier (holes 126 -> 0), a chunk cache, trees at 1:2, old-growth groves, the understorey, fog to 800 m. Night 2: Jolt, host-authoritative input (D1 pulled forward, PASS on Forward+ at 0.217 m median), boulders as co-op bodies, the push and the rock, momentum and the scree slide. `docs/status/world-feel-v1.md`
- [x] **A3. Distance v1 - the far country holds still** (2 nights, `docs/plans/distance-v1.md`) - **DONE** on `feat/distance-v1`, merged 2026-08-27/28. Night 1 the ground: a filtered heightmap mip pyramid, a mip level continuous in distance rather than per LOD ring, a max-pyramid dilation that gives the summits their height back, and the end of the far field's zone dither. Night 2 the forest and the meadow: the impostor ring stopped being drawn with the CHARACTER material, each impostor converges towards the hillside it stands on, and the ring runs to the fog instead of half way - 34% more trees over four times the ground, and streaming got faster doing it. The meadow is still gravel and Stage 8 says why. `docs/status/distance-v1.md`, which is the first doc in this project with a provenance column on every number.
- [x] **A3b. Distance v2 - the far country is made of blocks too** (2 nights, `docs/plans/distance-v2.md`) - **DONE** on `feat/distance-v2`, merged 2026-08-29. Every far cell has one height quantised to its own ring's cell width, with the drop to each lower neighbour drawn as a lit riser, and the impostors are stepped pyramids standing on the shelves. **PEAK LOSS at 600 m +55.28 blocks -> +13.40**, and past 500 m the far country holds perfectly still. **It ships OFF** on `far_terrace`, and 0.0 is `f23c3f0` byte for byte. `docs/status/distance-v2.md`.
- [x] **A4. Character v2 - the people** (2 nights, `docs/plans/character-v2.md`, `docs/plans/character-v2-tech.md`) - **DONE** on `feat/character-v2`, 2026-08-29. The grid to 96 voxels at 1/24 of a block; a fixed dark LINER slot, which retires look v2's tunic rule and is what let the cast stop wearing four black shirts; two-segment limbs and a three-segment digitigrade one; the lizardfolk rebuilt from 0.913 IoU to 0.664, and **zero race pairs over 0.70 for the first time**; six armour slots on a bumped wire format; an outline-event ladder the harness counts; the contact pose. `docs/status/character-v2.md`. **Placed before Wave 1 deliberately**: creatures v1 builds a quadruped on `Animator.RIG_SHAPES` and combat v1 builds hit and death poses on `pose_for()`, and both are cheaper against a rig that already has a knee than against one that grows one afterwards.
- [x] **A5. Trees v1 - no two alike, and the ziggurat arrives** (1 night, `docs/plans/trees-v1.md`) - **DONE** on `feat/trees-v1`, 2026-08-30. All seven species re-authored against `docs/research/art-direction.md` §2.5: the notched spire with whorl arms, the larch ziggurat whose sky is in the gaps, the lobed scallop beech, the bowed birch, the wind-flagged krummholz cushion, three snags, a re-proportioned hero, and a second colour as authored slivers under the whorls. **TWINS 1.00 -> 0.72 or better on all seven**, no pair over 0.56, the sparse species 24-65% cheaper in quads, and no floating block left in the forest. Same heightmap hash, same 28,383 trees, same spawn, every stage. `DESIGN.md` rule 4 stops saying "not yet". One failed gate - canopy closure fell where the design said fuller, which §2.5 outranks and `WorldgenConfig.grove_floor` inherits. `docs/status/trees-v1.md`.
- [x] **A3d. Distance v4 - the far mesher crosses to C++** (1 night, `docs/plans/distance-v4.md`) - **DONE** on `feat/distance-v4`, merged 2026-09-01. The far mesher is a GDExtension: **6,430 ms -> 158 ms a rebuild at `far_ring_div` 2 and 24,722 -> 661 at 4**, a measured **37-43x** interleaved ABAB on ganymede, so **`far_ring_div` now defaults to 4** and the 1 m far cell stops being a screenshot mode. The GDScript job stays in-tree as the reference implementation and the fallback - `far_field_job.gd` is not in the diff - and the two emit **byte-identical arrays** across five configurations, **72 identical far-probe geometry rows**, and **zero differing pixels** on every far-band tour shot. Holes 0 at both divisors. **What it did not fix and now dominates: `arrays_to_mesh` is on the main thread at 224 ms per rebuild at div 4** (STATUS items 11/17/20). First rung of the C++ ladder; the chunk mesher is next, and on tonight's numbers the upload may be worth more. `docs/status/distance-v4.md`.

- [ ] **A6. Look v3 - the painted world** (2+ nights, plan not yet written) - direction settled and recorded in `DESIGN.md` § Art direction, 2026-08-31: up close the world becomes a painting (sculpted forms, family-toned paint, dense dressing, soft light); the poster keeps the distance. Characters + gear + weapons + creatures + trees + flora + terrain dressing + lighting; structures arrive at this fidelity with Sites v1 rather than being converted. Gates: the KNIGHT TEST and the BELONGING TEST. Queued behind the in-flight runs so the trio is modelled once, in the new register. Demo: `kubik-knight-demo.bbmodel` on Marcel's desktop.

## Wave 1 - after flora lands  `C || D || B`

- [ ] **C. Creatures v1 - the trio** (2 nights) - wolf, marmot, eagle; LimboAI, A* over the heightmap, senses, pack, burrows; quadruped rig; species table. **Designed 2026-08-31** in conversation (`docs/plans/creatures-v1.md`, six decisions: the pack is the point, the groundwork is the deliverable, honest-interface perception, the disarmed bite, the scenario probe, the den). **Night 1 launched 2026-08-31** on `feat/creatures-v1`, ganymede, Opus (`docs/plans/creatures-v1-tech.md`) - stages 0-8: library ladder, species table, scenario harness, senses bus + pack board, territory A*, den placement, the two-wolf flank, the wire, F10. No merge night 1; night 2 merges main first, then marmot / eagle / wolf model / armed bite.
- [ ] **D. Combat v1** (2 nights)
  - [x] D1 host-authoritative player input (the carried ticket) - **done in A2 night 2**, 2026-08-27
  - [ ] D1 stats table: health, stamina, mana; damage through the one mutation path
  - [ ] D2 light attack, dodge / block; sword, bow, staff; fire bolt, frost bolt
  - [ ] D2 attack / hit / downed poses; revive
  - [ ] D2 HUD bars
  - [ ] dropped things fall and settle (no terrain physics)
- [ ] **B. Water v1** (1-2 nights) - rivers into the basin lakes, shores, water plants, wading
- [ ] **PLAYTEST 1** - trio + light attack, two players. Re-rank below on what it teaches.

## Wave 2  `E || F || H`

- [ ] **E. Campfire v1** (1 night) - placeable palette (campfire, torch, marker), light, regen, respawn anchor, sit; death rules
- [ ] **F. Session v1** (1 night)
  - [ ] one host save file: edit log + characters + placeables; reload
  - [ ] the journal - structured host events, written into the save
  - [ ] pause + settings menus (video, audio, controls)
  - [ ] edit-log compaction
- [ ] **H. Sites v1** (1-2 nights)
  - [ ] landmark table + structure stamper (ruin, shrine, hot spring, castle on a bench)
  - [ ] a fixed subset that always generates, every seed
  - [ ] place names - sites, lakes, peaks, regions
  - [ ] named regions on the seven zones (= "biomes")
  - [ ] lore fragments as data; `site_type` on every site
- [ ] **PLAYTEST 2** - die, respawn at the fire, save, quit, reload, find yesterday's ruin

## Wave 3  `G || I || K0`

- [ ] **G. Items v1** (1 night) - item table, pickup / drop, inventory, three visible gear slots, wolf drops, the gathering RPC
- [ ] **I. Navigation v1** (1 night) - compass, markers, map that fills as you range; minimap only as an off-by-default toggle
- [ ] **K. Director v0 - the world remembers** (1 night) - fragments and rumours from the journal, at the fire

## Wave 4

- [ ] **J. Skills v1** (1 night) - five skills, XP by doing, read-only sheet, level toast
- [ ] **K. Director v1 - the world beckons** (2+ nights) - quest routing on authored beat spines = procedural quests, fixed direction, endless

## Parked - not before a playtest or a pillar amendment says so

- Second Age: oceans, swimming, sailing, islands (post-1.0)
- Skill TREE (contradicts pillar 3 - amend in writing first)
- Breaking / falling terrain (unsettled in `DESIGN.md`)
- Full biome overhaul (named regions first)
