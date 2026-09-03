# Kubik

## Read this first (2026-09-03)

The game's direction is the bible, the sibling repo `../Kubik-bible`. Where this file, `README.md` or `docs/` disagree with the bible, the bible wins and the text here is stale until the reconciliation rewrites it. The audit of this repo against the bible is `RECONCILIATION.md` (verdicts per system, the decisions D44-D56, and the order of work in section 9). The four detailed audits are in `docs/reconciliation/`.

Working order: phase 0 housekeeping, phase 1 real light, phase 1b the chunk mesher in C++, phase 2 people and fire, phase 3 buildings, phase 4 the round 3 scene and its report (`../Kubik-bible/ROUND-3-BRIEF.md`), phase 5 the world-truth break, phase 6 the rest. When Marcel says "do phase N", start from `RECONCILIATION.md` section 9 and the bible files it names, write the plan in `docs/plans/` in the shape of `docs/plans/look-v2-tech.md`, and run it.

Rules that changed under the bible and are not yet rewritten below: the world is unbounded terrain with ringed content (D44); relief is real size (D45); hard rule one (the game must run without the compiled library) is retired (D49); the public checkout is source, not a runnable game (D50). Purchased assets stay in the private `Kubik-assets` repo, mounted by `scripts/tools/sync_assets.py`, never committed here.

## Design pillars

Four. Every feature must serve at least one, and contradict none.

- **BETTER TOGETHER.** Built for pairs, room for four. Encounters assume two
  bodies; 3-4 players handled by simple scaling. Cap constant: 4. Solo is a
  dev convenience, never a balanced mode.
- **TENSE OUT, COZY IN THE LIGHT.** Danger scales with distance, altitude, and
  darkness. Firelight and daylight are the warm register: light, regen,
  respawn point. Death costs time, not progress. No base building: you place
  objects, never terrain.
- **THE WORLD IS THE CONTENT.** Progression is ranging further. Distance is
  the difficulty, strangeness, and content axis - not menus or crafting trees.
  The scale register is monumental (2026-08-31): the world must feel huge -
  continents, massive factions, built things that dwarf the player - and the
  player small against it. See `docs/DESIGN.md` § World, "The north star:
  monumental".
- **THE WORLD ANSWERS.** Authored truth, generative direction. The world's
  facts are data the game owns; a director reads what the journey MEANS and
  responds through opportunity, never railroading, and never invents
  world-truth. The tech is invisible; the game is complete without it.
  Doctrine: `docs/DIRECTOR.md`.

## The three habits

Cheap now, and what the fourth pillar asks of every plan from here on:

1. **Facts as data, not prose in code.** Creature goals, what a place is, lore
   fragments, a quest's allowed outcomes: tables, like `Races` already is. A
   director can only steer what it can read.
2. **Keep the journal.** The host sees every event - edit, death, campfire,
   kill, first sight of a lake. Log them as structured events. That journal is
   the "what the journey means" input later, and it costs nothing today.
3. **Everything through the one mutation path.** A director proposes; the host
   validates against the allowed list and applies - exactly how a client's
   block edit is treated. Nothing generative ever touches state directly.

## Rule

When Marcel proposes a feature, check it against the pillars and the current
Next 3 list in `docs/IDEAS.md`, and push back if it contradicts them or jumps
the queue.

- The director acts only through the `docs/DIRECTOR.md` verb list. Features
  requiring the model to invent world-truth: reject and flag.
- Base-game milestones precede director milestones. If a session proposal
  skips stage-building for director work before v0's prerequisites exist
  (the wolf / marmot / eagle playtest, the journal, the campfire), push back.

## Worldgen guidance

- **The world is unbounded by design** (Marcel, 2026-08-31, overturning
  "bounded, not infinite" - see `docs/DESIGN.md` § World). Today's build
  generates one 3 x 3 km region; that is a stage, not the world. No new
  system may bake in a world edge, a global heightmap, or any global-extent
  assumption - heightmaps and lakes go regional (tiled) as the world opens.
- Where the current region's edges still exist, they are not symmetric. Most
  read as impassable peaks, but the coast (Second Age, see `docs/IDEAS.md`)
  is a compass DIRECTION the land descends toward, not an edge. Do not
  hardcode "far away = mountains" into worldgen, pathing, or fog logic; edge
  and direction treatment must be configurable.

## Where things live

- `README.md` - what the game is, and the architecture contract
- `docs/DESIGN.md` - settled design details (the authored truth)
- `docs/DIRECTOR.md` - the director's doctrine: two layers, the verb list,
  cadence, degradation, the quest model, the roadmap
- `docs/IDEAS.md` - Next 3, Someday, the Director ladder
- `TODO.md` - the queue as a checklist, in waves and parallel lanes
- `docs/ROADMAP.md` - why the queue is in that order: epics, territories, pushbacks
