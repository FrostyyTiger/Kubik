# TODO

Rewritten 2026-09-04 against the bible as of D84; where an older document
disagrees, the bible wins.

The queue, as a checklist. Why it is in this order, what each epic contains,
and the pushbacks are in `docs/ROADMAP.md`. `docs/IDEAS.md` Next 3 stays the
authority for what runs next. Tick things here; rewrite the reasoning there.

Lanes marked `||` run in parallel with zero-overlap file lists. `game.gd`
has one owner per wave; everyone else adds a file plus a one-line hook.

## Wave 0 - now

*2026-09-04: the reconciliation's order (`RECONCILIATION.md` § 9, `CLAUDE.md` § Working order) is the queue now, reordered by Marcel for the north star (D84). Everything below A9 is the queue behind it, and the lettered waves are what fills phases 3 to 6.*

- [ ] **A7. Horizon v1 - the view to the horizon, and a world with no edge** (3 nights, `docs/plans/horizon-v1.md`) - **LAUNCHED 2026-09-04** on `feat/horizon-v1`, ganymede tmux `horizon-v1`. The north star: the world as big as the view, the view to 32 km, 60 FPS at max settings on mid hardware. Origin-anchored height tiles at every level, voxels anywhere, persistent per-ring/per-sector far meshes, one material source, a fog ramp on the draw distance, a floating origin, the sprint probe. Changes nothing a seed produces. `||` with A8.
- [x] **A8. Mesher v1 - the chunk mesher in C++** (`docs/plans/mesher-v1.md`, phase 1b, D56) - **DONE**, merged 2026-09-04 from `feat/mesher-v1`. `docs/status/mesher-v1.md`. Ran `||` with A7 on zero-overlap file lists. The mesher decides how a chunk looks, never what it is, so it could not break a world - and the parity gate compared every vertex, normal, index and colour component to the bit anyway.
- [ ] **A9. The world-truth break** (weeks, plan not yet written; D56 as amended by D84) - real relief (D45), rings from the capital (D44), lakes and zones per tile, the generator's truth in C++. Starts the day A7 lands. Then people and fire, buildings, the round 3 scene (`RECONCILIATION.md` § 9 phases 3 to 5).
- [x] **Light v1 - real light** (2 nights, `docs/plans/light-v1-tech.md`) - **DONE** on `feat/light-v1`, merged 2026-09-04 (`f8ef45c`). `docs/status/light-v1.md`.

- [x] `feat/flora-streaming` lands on main (merged 2026-08-25)
- [x] **A. Look v2** - ran 2026-08-25, merged (`docs/plans/look-v2.md`)
- [x] **A2. World feel v1** (2 nights, `docs/plans/world-feel-v1.md`) - **DONE** on `feat/world-feel-v1`, 2026-08-27. Night 1: one job per column, the frontier (holes 126 -> 0), a chunk cache, trees at 1:2, old-growth groves, the understorey, fog to 800 m. Night 2: Jolt, host-authoritative input (D1 pulled forward, PASS on Forward+ at 0.217 m median), boulders as co-op bodies, the push and the rock, momentum and the scree slide. `docs/status/world-feel-v1.md`
- [x] **A3. Distance v1 - the far country holds still** (2 nights, `docs/plans/distance-v1.md`) - **DONE** on `feat/distance-v1`, merged 2026-08-27/28. Night 1 the ground: a filtered heightmap mip pyramid, a mip level continuous in distance rather than per LOD ring, a max-pyramid dilation that gives the summits their height back, and the end of the far field's zone dither. Night 2 the forest and the meadow: the impostor ring stopped being drawn with the CHARACTER material, each impostor converges towards the hillside it stands on, and the ring runs to the fog instead of half way - 34% more trees over four times the ground, and streaming got faster doing it. The meadow is still gravel and Stage 8 says why. `docs/status/distance-v1.md`, which is the first doc in this project with a provenance column on every number.
- [x] **A3b. Distance v2 - the far country is made of blocks too** (2 nights, `docs/plans/distance-v2.md`) - **DONE** on `feat/distance-v2`, merged 2026-08-29. Every far cell has one height quantised to its own ring's cell width, with the drop to each lower neighbour drawn as a lit riser, and the impostors are stepped pyramids standing on the shelves. **PEAK LOSS at 600 m +55.28 blocks -> +13.40**, and past 500 m the far country holds perfectly still. **It ships OFF** on `far_terrace`, and 0.0 is `f23c3f0` byte for byte. `docs/status/distance-v2.md`.
- [x] **A4. Character v2 - the people** (2 nights, `docs/plans/character-v2.md`, `docs/plans/character-v2-tech.md`) - **DONE** on `feat/character-v2`, 2026-08-29. The grid to 96 voxels at 1/24 of a block; a fixed dark LINER slot, which retires look v2's tunic rule and is what let the cast stop wearing four black shirts; two-segment limbs and a three-segment digitigrade one; the reptilian fourth race rebuilt from 0.913 IoU to 0.664, and **zero race pairs over 0.70 for the first time** (a gate about four races that D37 and D70 have since removed; `docs/status/character-v2.md` keeps the original wording); six armour slots on a bumped wire format; an outline-event ladder the harness counts; the contact pose. `docs/status/character-v2.md`. **Placed before Wave 1 deliberately**: creatures v1 builds a quadruped on `Animator.RIG_SHAPES` and combat v1 builds hit and death poses on `pose_for()`, and both are cheaper against a rig that already has a knee than against one that grows one afterwards.
- [x] **A5. Trees v1 - no two alike, and the ziggurat arrives** (1 night, `docs/plans/trees-v1.md`) - **DONE** on `feat/trees-v1`, 2026-08-30. All seven species re-authored against `docs/research/art-direction.md` §2.5: the notched spire with whorl arms, the larch ziggurat whose sky is in the gaps, the lobed scallop beech, the bowed birch, the wind-flagged krummholz cushion, three snags, a re-proportioned hero, and a second colour as authored slivers under the whorls. **TWINS 1.00 -> 0.72 or better on all seven**, no pair over 0.56, the sparse species 24-65% cheaper in quads, and no floating block left in the forest. Same heightmap hash, same 28,383 trees, same spawn, every stage. `DESIGN.md` rule 4 stops saying "not yet". One failed gate - canopy closure fell where the design said fuller, which §2.5 outranks and `WorldgenConfig.grove_floor` inherits. `docs/status/trees-v1.md`.
- [x] **A3d. Distance v4 - the far mesher crosses to C++** (1 night, `docs/plans/distance-v4.md`) - **DONE** on `feat/distance-v4`, merged 2026-09-01. The far mesher is a GDExtension: **6,430 ms -> 158 ms a rebuild at `far_ring_div` 2 and 24,722 -> 661 at 4**, a measured **37-43x** interleaved ABAB on ganymede, so **`far_ring_div` now defaults to 4** and the 1 m far cell stops being a screenshot mode. The GDScript job stays in-tree as the reference implementation and the fallback - `far_field_job.gd` is not in the diff - and the two emit **byte-identical arrays** across five configurations, **72 identical far-probe geometry rows**, and **zero differing pixels** on every far-band tour shot. Holes 0 at both divisors. **What it did not fix and now dominates: `arrays_to_mesh` is on the main thread at 224 ms per rebuild at div 4** (STATUS items 11/17/20). First rung of the C++ ladder; the chunk mesher is next, and on tonight's numbers the upload may be worth more. `docs/status/distance-v4.md`.

- [x] **A3e. Distance v5 - real data for the far country, and a budget for every upload** (1 night, `docs/plans/distance-v5.md`) - **DONE** on `feat/distance-v5`, 2026-09-01. Distance v4 made the far mesh 40x cheaper to build and turned its detail up 4x; this closes the three things that surfaced. **The upload gets a budget**: both meshers emit one set of arrays per frontier sector, `FarUpload` hands them over at `far_upload_budget_ms` (4.0) a frame and swaps the finished mesh in one assignment, so a sprint's worst frame goes **244.4 ms -> 39.6 ms** and frames over 33 ms **60 -> 4**, interleaved ABAB on the same commit - **zero over 33 ms** in the shipped configuration. **The ring boundaries go quiet**: the cell-height SAMPLE POSITION slides onto the coarse ring's lattice before a boundary, so the worst boundary's max fizz goes **147.00 -> 39.00 blocks** and roughness goes UP, closing STATUS items 9 and 18. **The height map crosses to C++**, tiled and anchored to the origin, **16.7 s -> 4.8 s**, quantised to 1/1024 block on BOTH legs so a library-less checkout makes the same world - hard rule zero, asserted every self-test run. **The impostor ring stops following the player down** (615 rebuilds over a tour -> 18, STATUS item 21). Plus an analytic detail layer where the pyramid has no data. **One thing measured and not taken**: 1 m base cells genuinely sharpen the far country and cost a startup gate, 17.5 s of lake finding and the sprint's front min; the next C++ rung is `Lakes.compute` and `_resolve_zone_thresholds`, not the chunk mesher. The world changed once, in its fingerprint only - `76cccdb6 -> 4782edac`, same spawn, same 53 lakes. `docs/status/distance-v5.md`.

- [x] **A5b. Trees v3 - the forest becomes models, the whole way out** (1 night, `docs/plans/trees-v3.md`) - **DONE** on `feat/trees-v3`, 2026-09-01/02. Trees stop being terrain, stop being generated, and stop being two different creatures near and far. **The purchased pack's 55 `.vox` sources become the library** through Kubik's own greedy mesher and palette - the chamfered meshes are still rejected, which is what trees v2 decision 5 was actually right about - baked offline into **38 geometries at three LOD rungs** by `../Kubik-assets/tools/trees_convert.py`. **`FarTrees` becomes `TreeField`, the only tree renderer in the game**, walking the placement lattice from the player's boots to the fog: LOD0 to 154 m, LOD1 to 400, LOD2 beyond. **No cards anywhere** - the far register is the same grid downsampled, so the near/far seam is a RESOLUTION boundary rather than a kind boundary, and looking down from a summit works. **The block-tree system is deleted**: `tree_species.gd` 3,383 lines -> 532, and the sky reserve with it. **The whole column job runs 6.2x faster** (242.5 -> 39.0 ms; `column_job.gd:11` said "half" and it was half of a job that also got a mesher win), chunks at spawn 2,369 -> 2,222, load wall 24.9 -> 19.3 s, and the streamer got 8 m further ahead of a sprinting player. Trunk colliders inside the sim radius; `removed_trees` threaded for fell-as-a-unit and unwritten. Season and snow-dust are **weights on which colourway a cell grows**, not tints - zero new meshes. **The public build ships treeless and CI proves it every push.** Placement never moved: 28,383 trees, same mix, spawn (-44, -124). `docs/status/trees-v3.md`.

- [ ] ~~**A6. Look v3 - the painted world**~~ - **OUT** (2026-09-03, `RECONCILIATION.md` § 8: replaced by the round 3 test scene; kept here so the number is not reused). Was: (2+ nights, plan not yet written) - direction settled 2026-08-31, re-cut 2026-09-01, recorded in `DESIGN.md` § Art direction: **ART DECO FANTASY**. One surface language at every distance - sculpted painted voxels, coarser with distance (the poster register retired; trees v3 makes near and far one geometry family); Deco as the grammar of the built world only, nature as sculpted-vox naturalism; the poster era kept as colour discipline. Characters + gear + weapons + creatures + flora + terrain dressing + lighting + the far field; structures arrive at this fidelity with Sites v1 rather than being converted. **TREES ARE DISCHARGED** (trees v3, 2026-09-01/02): they are already sculpted voxels through this game's mesher and palette, already one geometry family from boots to fog, and their colour is a table in the repo. What is LEFT of look v3's tree scope is not modelling - it is (a) judging the purchased library against the Deco direction once the knight lands, and (b) the krummholz, which is the one shape the epic lost outright and which needs new art rather than a table edit. Gates: the KNIGHT TEST and the BELONGING TEST. Queued behind distance v5 and trees v3 so the trio is modelled once, in the new register. Demo: `kubik-knight-demo.bbmodel` on Marcel's desktop.

## The phases behind wave 0

Set by `RECONCILIATION.md` § 9 as reordered by D84. Nothing lettered below
starts before phase 5.

- [ ] **P3. People and fire** (about one week) - promote `scripts/character/purchased_view.gd` to the character path, load two bought templates (D1), drive the sit pose from the packs' own clips, build the campfire prop with an emissive core and a point light. Rip `scripts/character/races.gd`, the creation screen's race row and the parts kit behind a flag first (D37, D51, D70); delete after the scene passes.
- [ ] **P4. Buildings** (one to two weeks) - the `BuildingModels` loader as a sibling of `TreeModels`, five houses placed at the tree line with flattened footprints, the landmark generator baked straight to `.ktree`, gates as placed volumes (D43, D47, D48, D59).
- [ ] **P5. The round 3 scene and its report** (days) - the brief's shots and measurements into `../Kubik-bible/discussions/11-ROUND-3-REPORT.md` (`../Kubik-bible/ROUND-3-BRIEF.md`).
- [ ] **P6. After that** (months) - the journal with typed facts and IDs (D34 rule 1), the nouveau UI (D2), creatures, combat and death. The waves below are its contents.

## Wave 1 - after the scene  `C || D || B`

- [ ] **C. Creatures v1 - the trio** (2 nights) - wolf, marmot, eagle; LimboAI, A* over the heightmap, senses, pack, burrows; quadruped rig; species table. **Designed 2026-08-31** in conversation (`docs/plans/creatures-v1.md`, six decisions: the pack is the point, the groundwork is the deliverable, honest-interface perception, the disarmed bite, the scenario probe, the den). **Night 1 launched 2026-08-31** on `feat/creatures-v1`, ganymede, Opus (`docs/plans/creatures-v1-tech.md`) - stages 0-8: library ladder, species table, scenario harness, senses bus + pack board, territory A*, den placement, the two-wolf flank, the wire, F10. No merge night 1; night 2 merges main first, then marmot / eagle / wolf model / armed bite.
- [ ] **D. Combat v1** (2 nights) - restrained: no blood, no gore, no cruelty as spectacle (D39)
  - [x] D1 host-authoritative player input (the carried ticket) - **done in A2 night 2**, 2026-08-27
  - [ ] D1 stats table: health, stamina, mana; damage through the one mutation path
  - [ ] D2 light attack, dodge / block; sword, staff, spear, then bow (D64); the fire rune and the frost rune (D65 amending D54 - same mechanics, a spark and a chill, never a storm); no gunpowder anywhere (D62)
  - [ ] D2 attack / hit / downed poses on the packs' clips; revive; the death event written to the journal first, because death is quiet and remembered (D39)
  - [ ] D2 HUD bars
  - [ ] dropped things fall and settle (no terrain physics)
- [ ] **B. Water v1** (1-2 nights) - rivers into the basin lakes, shores, water plants, wading. Waits for the world-truth break, which moves every lake.
- [ ] **PLAYTEST 1** - trio + light attack, two players. Re-rank below on what it teaches.

## Wave 2  `E || F || H`

- [ ] **E. Campfire v1** (1 night) - placeable palette (campfire, torch, marker) at the world grain, light, regen, respawn anchor, sit; death rules; threat and pacing measured from THIS fire, a different dial from the wildness measured from the capital (D35)
- [ ] **F. Session v1** (1 night)
  - [ ] one host save file: edit log + characters + placeables; reload
  - [ ] the journal - structured host events as typed facts with IDs (D34 rule 1), written into the save
  - [ ] pause + settings menus (video, audio, controls)
  - [ ] edit-log compaction
- [ ] **H. Sites v1** (1-2 nights) - the places, after P4 built the models
  - [ ] landmark table + placement pass (ruin, shrine, hot spring, castle on a bench)
  - [ ] a fixed subset that always generates, every seed
  - [ ] place names - sites, lakes, peaks, rings
  - [ ] lore fragments as data; `site_type` on every site so `mark_site` has an address
- [ ] **PLAYTEST 2** - die, respawn at the fire, save, quit, reload, find yesterday's ruin

## Wave 3  `G || I || K0`

- [ ] **G. Items v1** (1 night) - item table, pickup / drop, inventory, three visible gear slots, wolf drops, the gathering RPC
- [ ] **I. Navigation v1** (1 night) - compass, markers, a map that fills as you range, drawn as the Engineers' map: accurate near the capital, sketchy further out, blank beyond. **No minimap, ever** - not even a toggle (settled 2026-08-31)
- [ ] **K. Director v0 - the world remembers** (1 night) - fragments and rumours from the journal, at the fire

## Wave 4

- [ ] **J. Skills v1** (1 night) - five skills, XP by doing, read-only sheet, level toast. **Not the knowledge layer**: D74's five steps are recipes and verbs, found or taught, capped at one page (D80) and gated on the party's trust (D82). Do not merge them.
- [ ] **K. Director v1 - the world beckons** (2+ nights) - quest routing on authored beat spines = procedural quests, fixed direction, endless

## Parked - not before a playtest or a pillar amendment says so

- Swimming and sailing. Not a second act: the sea is rings 2 to 4 of the one world (D26, D44), reached by walking, ferry and airship, and the airships have a range (D73). Wading first, and not before the world is real-sized.
- Skill TREE (contradicts pillar 3 - amend in writing first). The knowledge layer is not a loophole: D80 forbids a tree in the same sentence that creates it.
- Breaking / falling terrain. Settled in `docs/DESIGN.md`: no, in v1. Re-settle in writing before any physics touches voxels.
- A biome overhaul as a worldgen rewrite. The ring table is the answer (D44, D26, D63) and it lands in the world-truth break.

## Decided, so no longer parked

- **More races.** One people, nobody changes (D37, D70). Body type is square, lean or stocky and carries no perk (D51); the starting people is soft and never a lock (D66).
- **A texture atlas.** Forbidden, not parked: no textures, on anything, ever (art pillar 2).
- **Attacks on the campfire and a night-hostility dial.** Out (D39): the fire is where every dread beat ends.
