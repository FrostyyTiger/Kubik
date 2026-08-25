# Kubik

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

- World edges are not symmetric by design. Most edges = impassable peaks, but
  one edge will eventually descend to a coast (Second Age expansion, see
  `docs/IDEAS.md`). Do not hardcode "world edge = mountains" into worldgen,
  pathing, or fog logic. Edge treatment must be per-edge configurable.

## Where things live

- `README.md` - what the game is, and the architecture contract
- `docs/DESIGN.md` - settled design details (the authored truth)
- `docs/DIRECTOR.md` - the director's doctrine: two layers, the verb list,
  cadence, degradation, the quest model, the roadmap
- `docs/IDEAS.md` - Next 3, Someday, the Director ladder
- `TODO.md` - the queue as a checklist, in waves and parallel lanes
- `docs/ROADMAP.md` - why the queue is in that order: epics, territories, pushbacks
