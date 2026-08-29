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
- [ ] **A3. Distance v1 - the far country holds still** (2 nights, `docs/plans/distance-v1.md`) - the far mesh aliases (no mip pyramid, so ridges fizz and re-cut themselves at every ring boundary), the colour aliases on top of it, and the impostor forest is drawn with the CHARACTER material so it is forbidden from receding. Night 1 the ground, night 2 the forest and the meadow. Jumps Wave 1 on pillar 3; nothing in Wave 1 depends on the far field. First plan written for a ganymede that can actually see (`e7c5d9d`), so colour is judged overnight and comparative numbers are interleaved medians from ganymede rather than single runs from the desktop.
- [x] **A4. Character v2 - the people** (2 nights, `docs/plans/character-v2.md`, `docs/plans/character-v2-tech.md`) - **DONE** on `feat/character-v2`, 2026-08-29. The grid to 96 voxels at 1/24 of a block; a fixed dark LINER slot, which retires look v2's tunic rule and is what let the cast stop wearing four black shirts; two-segment limbs and a three-segment digitigrade one; the lizardfolk rebuilt from 0.913 IoU to 0.664, and **zero race pairs over 0.70 for the first time**; six armour slots on a bumped wire format; an outline-event ladder the harness counts; the contact pose. `docs/status/character-v2.md`. **Placed before Wave 1 deliberately**: creatures v1 builds a quadruped on `Animator.RIG_SHAPES` and combat v1 builds hit and death poses on `pose_for()`, and both are cheaper against a rig that already has a knee than against one that grows one afterwards.

## Wave 1 - after flora lands  `C || D || B`

- [ ] **C. Creatures v1 - the trio** (2 nights) - wolf, marmot, eagle; LimboAI, A* over the heightmap, senses, pack, burrows; quadruped rig; species table
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
