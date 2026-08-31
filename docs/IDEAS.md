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

   **Look v1 - the poster** put the art direction on screen, and **look v2 -
   the poster, refined** ran on 2026-08-25 on `feat/look-v2`, all eight stages.
   [plans/look-v2.md](plans/look-v2.md). Its first stage is the one that
   matters most: the colour transfer was measured rather than assumed, and it
   was two bugs - the albedo applied twice, and Lambert's PI in the lit band -
   so every constant look v1 tuned had been chosen to cancel an error nobody
   had written down. An authored hex now lands on screen at `authored * sun *
   energy`, proved by a swatch sheet that runs as a gate every stage. On top of
   that: the time-of-day sets as a table with dawn and a dusk that is actually
   reached, shade as an ink, fog that holds hue, monotonic far-field bands,
   grain instead of jitter, the re-authored palette, solid eyes and hair that
   breaks the head box, and a UI with a title band. `docs/status/look-v2.md`
   has every number, every check that failed and why, and one BLOCKING finding
   for the Windows box.

   **Character v2 - the people** ran on 2026-08-28/29 on `feat/character-v2`,
   all fourteen stages. [plans/character-v2.md](plans/character-v2.md) is the
   design and [plans/character-v2-tech.md](plans/character-v2-tech.md) the build
   plan. The model grid went from 64 voxels to 96 at 1/24 of a block - for a
   knee, not for detail, since a 16-voxel leg split in two has segments half the
   thickness of their own joint. A fixed dark LINER slot between skin and cloth
   retired look v2's tunic rule, which had exactly one solution and it was that
   all four races wore black. The lizardfolk was rebuilt rather than adjusted
   and the human/lizardfolk silhouette went 0.913 to 0.664, so **no race pair
   overlaps by more than 0.70 for the first time**. Six armour slots on a bumped
   wire format, a tier ladder counted rather than judged, and a walk with a
   contact pose in it. `docs/status/character-v2.md` has every number, the four
   `TODO(marcel)` exercises, and the three places the run did not meet its own
   gate.

   **World feel v1 - the ground keeps up, the forest closes over** ran on
   2026-08-26 on `feat/world-feel-v1`; night 1 (Stages 0-8) is done and night 2
   (physics) has not started. [plans/world-feel-v1.md](plans/world-feel-v1.md).
   The column became the unit of work, which stamps a column's trees once
   instead of once per chunk and stops building the sky at all - initial load
   28.9 s -> 24.8 s and chunks at spawn 3,742 -> 2,370 with the trees three
   times the size. The far mesh and the impostor ring now follow the LOADED
   frontier rather than the nominal radius, which took holes from 126 of 144
   sprint samples to zero and made "never a hole, at any speed" a hard rule
   rather than a hope. Trees are drawn at 1:2 against the player with a third
   of groves at 1:1.33 old growth, and the ground under a closed canopy takes
   the shade ink. `docs/status/world-feel-v1.md` has every number, three bugs
   worth reading about, and three open items in `STATUS.md`.

   **Distance v1 - the far country holds still, and the forest recedes** ran
   over two nights, 2026-08-27/28, on `feat/distance-v1`, all ten stages.
   [plans/distance-v1.md](plans/distance-v1.md). Night 1 is the ground: a
   filtered heightmap mip pyramid, a mip level chosen continuously from
   distance rather than per LOD ring, a max-pyramid dilation that gives the
   summits their height back, and the end of the far field's zone dither.
   Night 2 is what grows on it: the impostor forest stopped being drawn with
   the CHARACTER material (a one-line bug that forbade the far forest from
   receding), each impostor now converges towards the hillside it stands on,
   and the ring runs to the fog at every preset instead of half way - 34% more
   trees over four times the ground, and streaming got FASTER doing it.
   ROUGHNESS -44%, the worst re-cut at a ring boundary -35%, and the drawn
   summit is higher than it was before the epic. Same heightmap hash, same
   spawn, same 28,383 trees, every stage: this epic changed how the far country
   is DRAWN and never what it IS. `docs/status/distance-v1.md` has every number
   with a provenance column, three gates that could not be met as written and
   what was run instead, and a **"Carried forward"** section at the end.

   **What it leaves for the next plan**, in one line each - the detail is in
   that section:
   - The **meadow tufts still read as gravel**, and it is not a colour
     constant: the ground is drawn lit and a grass blade's faces are drawn
     shaded, which no albedo change crosses. Wants a **decoration LOD** (a
     distant tuft becomes one flat lit patch) or a tuft model with more
     upward-facing surface. A look pass, not a distance pass.
   - The **400 m far-mesh ring boundary** is reduced, not removed. Removing it
     is a **geomorph** - blend the two rings across the boundary rather than
     switching - and that is a plan, not a knob.
   - **`--strict` fails on exactly one long frame** in about half of all runs.
     The measurement is settled; the STANDARD is not, and that is Marcel's
     call.
   - A **continuous flora density ramp** belongs in
     `World._flora_fraction_for()`, which no lane owned this run.

   **Distance v2 - the far country is made of blocks too** ran over two nights,
   2026-08-28, on `feat/distance-v2`, all eleven stages.
   [plans/distance-v2.md](plans/distance-v2.md). Distance v1 fixed what the far
   country is COLOURED; this one fixes what it is MADE OF. Marcel's complaint
   was that the background "feels like a different game - one is a cube based
   game, and the other one is just sort of an edge based vector game", and the
   code agreed: near terrain is cubes and near trees are staircases of leaf
   voxels, while the far field was a smooth surface with six-sided cones on it,
   built to match the near field's SILHOUETTE and never its SURFACE.

   Now every far cell has one height, quantised to that ring's own cell width -
   4 m at the seam, 8 m at 200 m, 16 m to the fog - and the difference to each
   lower neighbour is a vertical riser, lit as a voxel's side face is. The
   impostor forest is stepped pyramids standing on the shelves. **PEAK LOSS at
   600 m fell from +55.28 blocks to +13.40**, so a summit is drawn 27 m short at
   the real scale against 110 m before the epic; past 500 m the far country now
   holds perfectly still, FIZZ exactly 0.00 against 2.11-3.27. Same heightmap
   hash, same spawn, same 28,383 trees, same 580 impostors: this epic changed
   how the far country is DRAWN and never what it IS.

   **It ships OFF, on one knob.** `far_terrace` is on F4 at 0.0, 0.0 is
   `f23c3f0` byte for byte at every stage, and moving it rebuilds the far mesh
   and the impostor ring in place - no reroll, no voxel chunk, the player
   standing still. `docs/status/distance-v2.md` has every number with a
   provenance column, four gates that could not be met as written, and a
   **"Carried forward"** section at the end.

   **What it leaves for the next plan**, in one line each:
   - The **400 m ring boundary is 3.7x LOUDER** with the terrace on, and Stage 9
     found out why: not the step ladder, which changes nothing, but the two
     rings **sampling the cell height 8 blocks apart**. A geomorph of the sample
     POSITION removes it entirely - measured at 16.00 against the pre-epic
     21.57 - and is a much smaller thing than blending two surfaces.
   - **PEAK LOSS's residue is bimodal at exactly one ring-2 step**: eleven
     summits land within 10 blocks, nine fall a whole shelf short because the
     96-block ridge test did not fire. A narrower or two-tier test would move
     it.
   - **The far mesh is 2.47x the vertices** and its upload is on the main
     thread. Single-sided risers halve the cost and tear a see-through gash down
     every steep face; getting both needs a watertight shell.
   - **`--rendering-driver` after the `--` selects nothing, silently**, so the
     Compatibility half of every check in this project may have been Forward+.
     README fixed; no earlier epic's `-gl` set has been checked.

   **Trees v1 - no two alike, and the ziggurat arrives** ran in one night,
   2026-08-29/30, on `feat/trees-v1`, all seven stages.
   [plans/trees-v1.md](plans/trees-v1.md), with the taste in
   `docs/research/art-direction.md` §2.5 and the machinery in
   [research/trees.md](research/trees.md). Marcel's ask: "no variation, they're
   all symmetrical, a bit boring - let's sort of nail this so we won't have to
   think about it for a while." Stage 0 measured exactly that and it was worse
   than the complaint: **TWINS 1.00 on spruce and beech**, two trees hashed
   from two different cells were the SAME TREE down to the pixel. Every species
   is re-authored - the §2.5 spire with whorl arms, the larch as a ziggurat
   whose sky is in the gaps rather than in the crown, the beech as a lobed
   scallop that stops being a solid of revolution, a bowed birch, a
   wind-flagged krummholz cushion, three snags, a hero that is no longer its
   parent scaled - and a second colour as authored slivers under the whorls.
   TWINS is now 0.72 or better on all seven, no species pair is over 0.56, the
   sparse species are 24-65% CHEAPER in quads (per-block holes are the worst
   input greedy meshing can be handed, and they are all gone), and there is not
   one floating block left in the forest. Same heightmap hash, same 28,383
   trees, same spawn, same mix, every stage: this epic changed what a tree
   LOOKS like and never where one stands. `DESIGN.md` rule 4 stops saying "not
   yet". `docs/status/trees-v1.md` has every number with a provenance tag, the
   judge rounds, and **one failed gate**: canopy closure fell where the design
   said fuller (old growth 0.694 -> 0.648, grove 0.523 -> 0.481), because
   §2.5's spire proportion narrowed old-growth crowns by ~30% of disc area and
   §2.5 outranks the number. The reconciliation is stem DENSITY, which is
   placement - the open `TODO(marcel)` at `WorldgenConfig.grove_floor`, now
   with a second measurement feeding it.

   **Look v3 - the painted world (direction settled 2026-08-31)** is the
   next look epic, and it is a register change recorded in `DESIGN.md` § Art
   direction: up close the world becomes a painting - sculpted forms,
   family-toned paint, dense dressing, soft light - and the poster survives
   at distance, where the comparison run showed it already holds. Scope now:
   characters, gear, weapons, creatures, trees, flora, terrain dressing,
   lighting. Structures excluded - nothing is built yet, so Sites v1 arrives
   at this fidelity rather than being converted to it. The bar is Marcel's
   nine-render reference set (kept off-repo; DESIGN.md carries the
   description) and the gates are the KNIGHT TEST and the BELONGING TEST. A
   demo at the bar, `kubik-knight-demo.bbmodel`, went to his desktop the day
   of the ruling; Blockbench becomes the character authoring surface and the
   plan owes the import half of the round trip. Concept then tech plan to be
   written after the three in-flight runs (creatures v1 night 2, ui v1,
   distance v3) land, so the trio is modelled once, in the new register.

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
squares, and that was content work parked behind items 2 and 3 - until trees v1
jumped them on 2026-08-29, on the same argument look v1 made for itself.

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

- **A GDExtension for chunk generation and meshing.** World feel v1 measured
  what everything else is bounded by: GDScript is serialised across the worker
  pool, so 3,742 chunks x 7.6 ms of work took 29.5 s of wall clock on about one
  effective thread. Every streaming improvement in that plan came from doing
  less work, because doing it in parallel is not available. Moving the two hot
  loops to a GDExtension is the only lever left that changes the shape of the
  curve, and it would pay for the second that "never a hole" costs several
  times over.

- **The shore's width.** `SHORE` is one block of grey gravel round every lake,
  and look v2 made it a colour that reads (`#91948E`) rather than a sandy tan -
  which showed that the *width* is the real problem: a one-block rim reads as a
  drawn line at 20 m and as nothing at 60 m. A shore that widened with the
  lake's size would give the postcard shot a foreground. Worldgen, so not look
  v2's to touch.

- **Meadow patches.** Look v2 put the meadow tuft density back to 0.50 and the
  close-up is busy with it - the "confetti" look v1 named. The interesting
  version is not a density number at all: drifts, the way `_meadow()` already
  clusters flowers, so a meadow is patches of tall grass in a shorter field
  rather than an even scatter at any density.

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

The launch world is Alpine. Long-term, the land in one compass direction
descends past the far ranges to a COAST, and the game's second act opens: the
sea.

*Amended 2026-08-31 with the unbounded-world ruling (`DESIGN.md` § World):
this section used to say "bounded" and "one world edge". An unbounded world
has no edges, so the coast becomes macro-structure instead - a direction the
land falls toward - which is, if anything, truer to the fantasy: you range
toward the sea, you don't bump into it.*

- **Coast in ONE compass direction.** The macro-terrain is asymmetric: ranges
  rise in most directions, the land descends to water in one.
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
not hardcode "far away = mountains" anywhere - direction treatment stays
configurable.

## The Director (the fourth pillar, arriving late)

Noted 2026-08-25 from a conversation Marcel had about where LLMs actually
belong in games, and promoted the same day to the fourth pillar - THE WORLD
ANSWERS, in `README.md` and `CLAUDE.md`. The doctrine - two layers, the verb
list, the cadence, graceful degradation, the quest model - is `DIRECTOR.md`;
architecture decision 6 in the README is what the code does about it now.
What follows is the argument that got it there, kept because the reasoning
is worth more than the summary. It has its own section in the Second Age's
shape because it is a direction and not an item, and with the same scope
honesty: the director is built on top of a game that is complete without
it, and the base game's milestones always come first.

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
the director acting only through the verb list, via the one mutation path.
Nothing to build now; nothing to hardcode against later.

### Director ladder

The rungs, in order. Each is gated on the base game beneath it; none is on
the Next 3 until its prerequisites exist.

- **Prerequisites (base game):** the wolf / marmot / eagle playtest working,
  the host's event journal, the campfire as a rest. Facts as data from the
  creature plan onward.
- **v0 - "the world remembers."** At the campfire, fragments and rumours
  generated from the true event log. Read-only reflection, no quest logic.
  Verbs: `place_fragment`, `spawn_rumor`.
- **v1 - "the world beckons."** Rumour-driven quest routing on authored beat
  spines. Verbs: `mark_site`, `advance_beat`, `reroute_beat`.
- **v2 - "the stranger speaks."** One NPC - the storm-scholar, the
  *garabonciás* archetype - with fixed goals, knowledge bounds and generative
  speech. Uncanny is lore-correct for him.
- **Someday rungs**, in no order:
  - The semantic director reading long-horizon patterns - sessions, not
    minutes: what this party keeps doing, what it avoids, what it has never
    seen.
  - Director-aware fragments in worldgen: sites placed at generation that
    the director may later fill (a `site_type` the verbs can address).
  - Companions with real memory; NPCs with fixed goals and adaptive tactics.

Marketed as the experience, never the technology, at every rung.
