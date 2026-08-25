# Ideas

## Next 3

Seeded once from the pillars, then re-ordered when terrain v1 was scoped. From
here on this list is filled by what a playtest taught us.

1. ~~**Terrain v1 - the world itself.**~~ **DONE**, merged to `main`
   2026-08-24. Swiss pre-Alpine landscape: meadow valleys, forested slopes,
   bare rock, snow peaks, lakes in real depressions, fog and a day/night cycle.
   [plans/terrain-v1.md](plans/terrain-v1.md).

   **Terrain v2 - the shape of the land** followed it on `feat/terrain-v2`:
   3 x 3 km at a coherent 1:4 scale, seven elevation zones resolved as shares
   of map area, real flat ground, baked ambient occlusion, LOD rings, and a
   spawn that satisfies the postcard test by construction.
   [plans/terrain-v2.md](plans/terrain-v2.md).
   *Answers:* the postcard test - can I frame a mountain, its forest and a lake
   in one view within two minutes of walking from spawn?

   **Plan B** splits in two, and the first half is done.

   **Foliage v1 - what grows on the land** ran overnight on 2026-08-24/25 and
   landed on `feat/foliage-v1`, all eleven stages.
   [plans/foliage-v1.md](plans/foliage-v1.md). Seven tree species instead of
   one, a forest that clumps and leaves clearings, 8.7 M pieces of ground cover
   on a decoration layer that never touches a chunk, an impostor ring so the
   forest does not stop at 96 m, and fireflies and glowing mushrooms after
   dark. Trees went from 34,925 to 73,675 on seed 42 and the terrain under them
   did not move - same heightmap hash, same zone shares, same spawn.
   `docs/status/foliage-v1.md` has every number and the list of things tuned
   on the wrong renderer.

   **Water and rivers** is the other half and is still not written. What
   foliage v1 leaves ready for it is at the end of `docs/status/foliage-v1.md`:
   the placement
   product takes another `base` case and another binary gate almost for free,
   the decoration layer takes water plants without changing, and reeds already
   follow `Lakes.shore_level_at_cell()` - which is the same question a river
   would have to answer.

2. **First enemy and the light attack.** One enemy type, one attack, shaped so
   two bodies beat it and one struggles.
   *Answers:* does fighting it together actually produce flanking and saves, or
   do we both just mash forward?

   Terrain v2 left the hook: worldgen exposes a normalised
   `TerrainGenerator.danger_at()`, 0 at spawn and 1 at the furthest corner, and
   the terrain itself already grows wilder with it. Nothing consumes it yet.

3. **Campfire.** The first placeable object: light, regen, respawn anchor.
   *Answers:* is reaching the fire a relief, and does dying cost time without
   costing progress?

   Terrain v2 built the alpine benches for exactly this - wide flat shelves
   partway up a slope, which is where a fire or a fight can happen on ground
   that is otherwise all gradient.

Terrain moved to the front because items 2 and 3 both need somewhere to happen -
readable geography with flat valley floors to fight and camp on. It is a
prerequisite, not a detour.

**Character v1 ran on its own branch for the same reason.** It is not on this
list and it jumped the queue, on the argument that items 2 and 3 both need it
first: the first enemy needs an animated rig pipeline that is provably not
humanoid-only, and the campfire is sold on "your character sitting at the fire
IS the progress screen", which needs a character, a sit pose and gear sockets.
All three exist now, plus four races, a creation screen and appearance sync. See
`docs/plans/character-v1.md` and `docs/status/character-v1.md`.

**Look v1 ran next, on `feat/look-v1`, 2026-08-25**, and it is not on this
list either. The argument: an art direction is not a feature, it is the same
kind of decision as the art pipeline - cheap to make now and dearer with every
part, plant and screen authored under the old look - and the character half
was urgent, because the first enemy and the first gear are parts, and every
part authored at the old resolution and proportions would be a part to redo.
It settled the direction (Art Deco Alpine poster, `DESIGN.md` "Art
direction"), put one lighting ramp under everything drawn, gave the sky rays
and the far field bands, re-authored every character at 1/16 of a block in
stocky proportions, and gave the UI its typography. See
`docs/plans/look-v1.md` and `docs/status/look-v1.md`. What it deliberately did
NOT do: trees. Rule 4 wants cones and ziggurats where there are stacked
squares, and that is content work parked behind items 2 and 3.

Terrain v1 delivered a walking third-person player as a side effect, and v2
added sprint, but both on **local physics only**. Rewiring it into the
host-authoritative input path is a carried ticket, not done.

**Candidate for the next playtest, from the creature design of 2026-08-25:**
item 2 becomes a TRIO rather than one enemy - one creature per layer of the
world. The **wolf** (the rusher archetype: the threat), the **marmot**
(whistle-and-burrow: ground texture and the information layer), and the
**eagle** (a slow orbit on the ridgelines and one cry: sky texture). The
marmot and the eagle are the creature pipeline tested in the cozy register;
the wolf is that pipeline plus a bite. `DESIGN.md`, Creatures.

Deliberately not here:

- **Gathering.** Foliage v1 built the identity and the removal path for it and
  stopped short of the RPC, deliberately - the comment at
  `World.remove_flora_local()` writes out the call it is waiting for. Gathering
  is a launch skill in `DESIGN.md`, but it is a SKILL, and skills are not on
  this list until something is worth gathering for.
- **Day/night as a danger axis.** The cycle shipped in terrain v1, but visual
  only. Pillar 2 wants darkness to mean something; that needs the enemy first.
  Foliage v1 added the first thing that exists only after dark - fireflies and
  glowing mushrooms - and they are deliberately on the cozy side of the
  register, not the tense one.
- **Breaking terrain.** Unsettled in DESIGN.md. Settle it before building it.

## Someday

Not rejected, not queued. Nothing moves up from here without a playtest saying
it should.

- Explosions that destroy terrain. Wanted, but it drags two roadmap items
  forward with it: the edit log grows without bound and is sent in full to
  every joining player, and remeshing eight chunks is a visible hitch. Greedy
  meshing landed in terrain v1; edit-log compaction is still needed.
- Found cozy places - villages, hot springs
- Mounts
- Taming / befriending select creatures. The design feeds the mount system:
  the *táltos*-horse pattern - the shabby nag that is secretly great - is the
  north star for mounts.
- Full night system: area-dependent night fauna, aggro nights, raids on the
  campfire - a blood-moon-style dial on the existing time/danger grammar
  (`DESIGN.md`, Creatures: Night).
- Megafauna encounter design (`DESIGN.md`, Creatures: Megafauna).
- Deeper mimics: boulder, copse, hillside - the distance-escalation of
  "seeming frays" (`DESIGN.md`, Creatures: Mimics).
- The eagle as information layer - circling marks large creatures and
  carrion - and the eagle-luck superstition in lore fragments.
- Sound asset acquisition list. The alpine raptor cry is priority #1
  (freesound / Kenney; licence-check everything for an open-source repo -
  CC0 or CC-BY with attribution recorded, never NC or ND).
- More races
- Full class system *(contradicts a pillar)*
- Skill trees *(contradicts a pillar)*
- Base building *(contradicts a pillar)*
- Arbitrary block placement *(contradicts a pillar)*

The tagged entries contradict a pillar as written. That is fine as a parking
space, but building one means amending the pillar first, deliberately and in
writing - not discovering halfway through a branch that the design moved.

## Second Age: The Sea (post-1.0 expansion arc, not before)

Bigger than a Someday item - an expansion arc, so it gets its own section.

The launch world is Alpine and bounded. Long-term, one world edge descends past
the far ranges to a COAST, and the game's second act opens: the sea.

- **Coast at ONE world edge.** World edges are asymmetric: peaks on most sides,
  descent to water on one.
- **Interactive water.** Swimming ships here, and with it the lizardfolk swim
  perk (replaces the fish-shadow placeholder in `DESIGN.md`).
- **Sailing.** Boat controller, wind matters. Valheim-school: sailing should be
  a skill and a feeling, not a fast-travel skin.
- **Ocean and island generation.** Island kingdoms as the new far-zone content
  tier.
- **The lizardfolk homeland lies across the water** - the answer to "why is a
  water-race in the mountains".
- **Trailer moment to build toward:** two players crest the last ridge and see
  open water for the first time.

Scope honesty: this is an expansion-sized arc (2.0 energy), not a feature.
Nothing here before the Alpine game is complete and shipped. BUT the sea may be
foreshadowed from day one via lore fragments, which are cheap: shells in high
ruins, lizardfolk graves facing away from the mountains, salt references.
Longing is free; water physics are not.

What it asks of the code today is one thing only, recorded in `CLAUDE.md`: do
not hardcode "world edge = mountains" anywhere.

## The Game Master: an LLM director (a core aspect, arriving late)

Noted 2026-08-25 from a conversation Marcel had about where LLMs actually
belong in games, and promoted the same day to a core aspect of Kubik: the
fourth pillar in `README.md` and `CLAUDE.md` - *authored truth, improvised
path* - is this idea stated as a rule, and architecture decision 6 in the
README is what the code does about it now. This section is the design. It
has its own section in the Second Age's shape because it is a direction and
not an item, and with the same scope honesty: the director itself is built
last, on top of a game that is complete without it.

**The opportunity.** LLMs in games are not chatbot NPCs or generated dialogue.
The unit of value is *goal-directed improvisation under constraints* - a
tabletop game master. The destination and the stakes are authored; the path
there is invented fresh in response to what the players actually do, the way
a coding agent holds the requirements and routes creatively.

**The architecture: two layers.** Authored truth underneath - what is real,
what characters know and want, which outcomes are possible. Generative
intelligence on top - how it is expressed, how the middle unfolds. The model
never invents the world's facts; it only performs within them. Applications:
NPCs with fixed goals but adaptive tactics, companions with real memory,
quests with fixed beats but emergent connective tissue, and a *semantic
director* that reads what the journey means - not the health bars - and
shapes events accordingly.

**The delivery doctrine.** Subtle and invisible, the way physics engines
became. Market the experience ("suspects who keep their secrets"), never the
technology. Steer through opportunity, never railroad - Westworld's
capability without its manipulation.

**The timing claim.** The 2023-25 AI-NPC wave failed because it was chatbots
in costumes on immature tech; the failures mark infancy, not a ceiling. The
conversational quality now exists, costs are collapsing, and the unsolved
part is game design, not capability - so the field is open for whoever ships
the first non-tacky version, probably a small game built entirely around one
constrained instance of the idea.

**Against the pillars.** It serves pillar 3 directly - a director that makes
ranging outward *mean* something is the world being the content - and it can
serve pillar 1 (a companion that remembers what the two of you did). It
touches nothing in pillar 2. What it must not become: a menu, a chat window,
or a source of facts the world did not author.

**What it asks of the code today** is the three habits in `CLAUDE.md` and
architecture decision 6 in the README: facts as data, the host's journal, and
the director as a client of the one mutation path. Nothing to build now;
nothing to hardcode against later.

**How it arrives, in order.**

1. *Now, free:* the journal and facts-as-data, obeyed by every plan from the
   creature work onward.
2. *With creatures and quests:* every system built fully authored - fixed
   goals, fixed beats, allowed outcomes as a list - so the game is complete
   with no director at all.
3. *First director:* one small, invisible use. Which fragment you find; where
   the pack waits tonight. Proposals only, validated by the host, minutes
   timescale, nothing on the combat path.
4. *Then:* companions with real memory, the semantic director reading the
   journal, NPCs with fixed goals and adaptive tactics.

Marketed as the experience, never the technology, at every step.
