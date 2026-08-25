# TODO

The queue, as a checklist. Why it is in this order, what each epic contains,
and the pushbacks are in `docs/ROADMAP.md`. `docs/IDEAS.md` Next 3 stays the
authority for what runs next. Tick things here; rewrite the reasoning there.

Lanes marked `||` run in parallel with zero-overlap file lists. `game.gd`
has one owner per wave; everyone else adds a file plus a one-line hook.

## Wave 0 - now

- [x] `feat/flora-streaming` lands on main (merged 2026-08-25)
- [x] **A. Look v2** - ran 2026-08-25, merged (`docs/plans/look-v2.md`)
- [ ] **A2. World feel v1** (2 nights, `docs/plans/world-feel-v1.md`) - night 1: chunk streaming keeps up with sprint, never a hole, trees at 1:2 with old-growth groves and a closed canopy, fog to 800 m; night 2: Jolt, host-authoritative input (D1 pulled forward), boulders and logs as co-op bodies, slope momentum

## Wave 1 - after flora lands  `C || D || B`

- [ ] **C. Creatures v1 - the trio** (2 nights) - wolf, marmot, eagle; LimboAI, A* over the heightmap, senses, pack, burrows; quadruped rig; species table
- [ ] **D. Combat v1** (2 nights)
  - [ ] D1 host-authoritative player input (the carried ticket) - **pulled into A2 night 2**
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
