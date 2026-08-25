# Kubik

## Design pillars

Every feature must serve at least one, and contradict none.

- **BETTER TOGETHER.** Designed for 2-4 players and tuned for 2. Encounters
  assume at least two bodies: flanking, saves, complementary roles. Party is
  hardcoded at 4 maximum. Solo is a dev convenience, never a balanced mode -
  no solo tuning, ever.
- **TENSE OUT, COZY IN THE LIGHT.** Danger scales with distance from spawn and
  with darkness. Campfires (and daylight) are the safe, warm register: light,
  regen, respawn point. Death costs time, not progress. No base building: you
  place objects, never terrain.
- **THE WORLD IS THE CONTENT.** Progression comes from ranging further outward,
  not from menus or crafting trees. Distance is the difficulty and content axis.
- **AUTHORED TRUTH, IMPROVISED PATH.** The world's facts - what exists, what
  things want, what can happen - are data the game owns. Anything generative
  (the Game Master, an LLM director arriving late - see `docs/IDEAS.md`)
  performs inside them and never invents them. The game must be complete
  without it.

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

## Worldgen guidance

- World edges are not symmetric by design. Most edges = impassable peaks, but
  one edge will eventually descend to a coast (Second Age expansion, see
  `docs/IDEAS.md`). Do not hardcode "world edge = mountains" into worldgen,
  pathing, or fog logic. Edge treatment must be per-edge configurable.

## Where things live

- `README.md` - what the game is, and the architecture contract
- `docs/DESIGN.md` - settled design details
- `docs/IDEAS.md` - Next 3, and Someday
