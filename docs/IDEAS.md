# Ideas

Rewritten 2026-09-04 against the bible as of D84; where an older document
disagrees, the bible wins.

## Next 3

**The queue is the reconciliation's phases now** (`../RECONCILIATION.md` § 9,
`../CLAUDE.md` § Working order), reordered by Marcel on 2026-09-04 for the
north star (D84) and on 2026-09-05 for the frame (D85). This list stopped being seeded from the pillars and started
being the translation of the bible into the game; from here on it is filled by
what a phase report and a playtest teach us.

1. **Upload v1 - the frame thread stops touching the mesh** (phase 1d;
   D85). Horizon v1 landed on 2026-09-05 ([status/horizon-v1.md](status/horizon-v1.md))
   with the median half of the frame gate met - 16.67 ms at Ultra with the
   view at 32 km - and the hitch half open: 171 to 233 frames of about 3,340
   over 25 ms while sprinting, and every rung of the shrink list made it
   worse. Generation and meshing are off the main thread now; what is left on
   it is `add_surface_from_arrays` plus a collision shape per column, 214
   columns a second. Fewer, larger surfaces per column, or a mesh handed to
   the rendering server without the frame thread touching it. **Changes
   nothing a seed produces.** Launched 2026-09-05 on ganymede,
   [plans/upload-v1.md](plans/upload-v1.md).
   *Answers:* does the frame hold at 60 FPS on an RTX 3070 Ti with no frame
   over 25 ms, sprinting through forest, with the view at 32 km?

2. **The world-truth break** (phase 2; D45, D44, D56 as amended by D84 and D85).
   Starts the day upload v1 lands (D85), before people and fire, before any content
   is authored on a seed: **real relief** (1,400 to 2,500 m, D45), **rings
   measured from the capital** rather than from the map centre (D44), the
   tiled heightmap store, lakes and zones per tile, and the generator's truth
   in C++. Every one of these changes what a seed produces, so they happen
   once and together. Plan not yet written.
   *Answers:* does a real-sized Alps hold the vista rule - a whole mountain
   and the next landmark in frame from every campfire, village and pass?

3. **People and fire** (phase 3). Promote `../scripts/character/purchased_view.gd`
   to the character path, load two bought templates (D1), drive the sit pose
   from the packs' own clips, and build the campfire prop with an emissive core
   and a point light. Rip the four races and the parts kit behind a flag first
   (D37, D51, D70), delete after the round 3 scene passes.
   *Answers:* is reaching the fire a relief, is warm light rare enough to
   mean something, and do two people at a fire read as the tone's second song?

Behind those: **buildings** (phase 4), **the round 3 scene and its report**
(phase 5, `../../Kubik-bible/ROUND-3-BRIEF.md`), and then **the journal with
typed facts and IDs, the nouveau UI, creatures, combat and death** (phase 6).

**Look v3, "the painted world", is OUT.** It was the next look epic here and
in `../docs/ROADMAP.md`, a register change named Art Deco fantasy with the
KNIGHT TEST and the BELONGING TEST as its gates. The bible replaces it
outright: pillar 2 is real light on flat cubes through a film lens with no
textures on anything ever, pillar 5 puts deco on the built and never on
nature, and Art Nouveau is on paper only (D2). Light v1 built pillar 2, and
what look v3 was going to prove is proved instead by **the round 3 test
scene** (`../RECONCILIATION.md` § 8 and § 9 phase 5). The number is kept so
it is not reused.

**Sites v1 is not a landmark table any more; it is the bible's built world.**
When it comes it inherits the four building families
(`../../Kubik-bible/style-bible/30-architecture.md`), the rings (D44, D26) and
the building pipeline: generated at the tree grain and baked with three
level-of-detail rungs (D43, D48), placed as models against terrain with a pass
that owns roads, footprints and flattening, and gates and dungeons as **placed
volumes** with a separate interior stitched in behind the door (D47).

**Fog, the film lens and the far view are engine items, not ideas.** They were
queued here as look work; they are the renderer and the horizon lane. Fog does
three jobs and needs a volume (built in light v1); the lens is D40 (built in
light v1); the far view is D41 as raised by D84 and is horizon v1.

## What has landed, and what the old queue said

Kept as the record. Every run has a status doc with the numbers; these are the
one-paragraph versions and the findings worth not rediscovering.

**Trees v3 - the forest becomes models, the whole way out** ran in one night,
2026-09-01/02, on `feat/trees-v3`, all eleven stages.
[plans/trees-v3.md](plans/trees-v3.md), [status/trees-v3.md](status/trees-v3.md).

Trees were the last living thing in this game built out of terrain, and they
stopped being. The purchased pack's **55 MagicaVoxel sources** - not its
chamfered meshes, which stay rejected - bake into **38 geometries at three LOD
rungs** through Kubik's own greedy mesher and palette, and `TreeField`
instances them from the player's boots to the fog. There are no impostor cards
anywhere: the far register is the SAME GRID downsampled, so the seam a walking
eye used to find became a resolution boundary rather than a kind boundary.

**The block-tree system is deleted** - 2,851 lines of shape code, both chunk
writers, and the sky reserve. The whole column job runs **6.2x faster**, and
`column_job.gd`'s five-week-old claim that tree stamping was half the cost
turned out to be half of a job that also lost the mesher's worst input.

*Three things it found that nobody was looking for:* `vox_parse.py` had been
silently dropping MagicaVoxel's ROTATIONS since character v2 (Tree 09 is a
coconut palm and came out as a stick with a plate on it); `StringName.sort()`
compares pointers rather than text; and a colourway twin was reading its
owner's palette indices, which rendered four hero variants as one flat brown
and was found by a swatch gate reporting "13 of 16 families reachable".

1. ~~**Terrain v1 - the world itself.**~~ **DONE**, merged to `main`
   2026-08-24. Swiss pre-Alpine landscape: meadow valleys, forested slopes,
   bare rock, snow peaks, lakes in real depressions, fog and a day/night cycle.
   [plans/terrain-v1.md](plans/terrain-v1.md).

   **Terrain v2 - the shape of the land** followed it on `feat/terrain-v2`:
   3 x 3 km at one coherent land scale - a quarter of real, which D45 has
   since retired - seven elevation zones resolved as shares
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
   `status/foliage-v1.md` has every number and the list of things tuned
   on the wrong renderer.

   **Water and rivers** is the other half and is still not written. What
   foliage v1 leaves ready for it is at the end of `status/foliage-v1.md`:
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
   breaks the head box, and a UI with a title band. `status/look-v2.md`
   has every number, every check that failed and why, and one BLOCKING finding
   for the Windows box.

   **Character v2 - the people** ran on 2026-08-28/29 on `feat/character-v2`,
   all fourteen stages. [plans/character-v2.md](plans/character-v2.md) is the
   design and [plans/character-v2-tech.md](plans/character-v2-tech.md) the build
   plan. The model grid went from 64 voxels to 96 at 1/24 of a block - for a
   knee, not for detail, since a 16-voxel leg split in two has segments half the
   thickness of their own joint. A fixed dark LINER slot between skin and cloth
   retired look v2's tunic rule, which had exactly one solution and it was that
   all four races wore black. The reptilian fourth race was rebuilt rather
   than adjusted and its silhouette against the human went 0.913 to 0.664, so
   **no race pair overlapped by more than 0.70 for the first time** - a gate
   about four races that D37 and D70 have since removed, and whose original
   words [status/character-v2.md](status/character-v2.md) keeps. Six armour slots on a bumped
   wire format, a tier ladder counted rather than judged, and a walk with a
   contact pose in it. `status/character-v2.md` has every number, the four
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
   the shade ink. `status/world-feel-v1.md` has every number, three bugs
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
   is DRAWN and never what it IS. `status/distance-v1.md` has every number
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
   standing still. `status/distance-v2.md` has every number with a
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
   `research/art-direction.md` §2.5 and the machinery in
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
   yet". `status/trees-v1.md` has every number with a provenance tag, the
   judge rounds, and **one failed gate**: canopy closure fell where the design
   said fuller (old growth 0.694 -> 0.648, grove 0.523 -> 0.481), because
   §2.5's spire proportion narrowed old-growth crowns by ~30% of disc area and
   §2.5 outranks the number. The reconciliation is stem DENSITY, which is
   placement - the open `TODO(marcel)` at `WorldgenConfig.grove_floor`, now
   with a second measurement feeding it.


**What the old items 2 and 3 were, and where they went.** Both are still
wanted and both moved down the queue: the first enemy is phase 6, behind the
world-truth break, people and fire, buildings and the scene; the campfire is
phase 3, and it grew - under D35 it is the pacing origin of the whole world,
under the tone it is where every dread beat ends, and under the director it is
the cadence.

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

**Terrain came first because items 2 and 3 both needed somewhere to happen** -
readable geography with flat valley floors to fight and camp on. A
prerequisite, not a detour. The same argument now puts horizon v1 and the
world-truth break in front of both: a real-sized world with no edge is the
ground everything after it stands on, and it is cheapest to change before any
content is authored on a seed (D56).

**Character v1 and look v1 both jumped the queue**, on the same argument: an
art direction and an art pipeline are not features, they are the kind of
decision that is cheap now and dearer with every part, plant and screen
authored under the old one. Both were right to jump and both have been
overtaken. Character v1's four races, its creation screen's race row and the
generated-parts kit are on the rip list (D1, D37, D51, D70); look v1's Art
Deco Alpine poster is retired by pillar 2 and by light v1. What survives of
them is the mechanism and not the content: parts as data, the `.vox` drop-in
rule, the swatch and transfer gates, and the animator.
See `plans/character-v1.md`, `status/character-v1.md`, `plans/look-v1.md`.

**The playtest trio still stands** (from the creature design of 2026-08-25):
one creature per layer of the world - the **wolf** (the rusher archetype: the
threat), the **marmot** (whistle-and-burrow: ground texture and the
information layer), and the **eagle** (a slow orbit on the ridgelines and one
cry: sky texture). The marmot and the eagle are the creature pipeline tested
in the quiet register; the wolf is that pipeline plus a bite. Nothing in it is
cute (D38). `../docs/DESIGN.md`, Creatures.

Deliberately not on the list:

- **Gathering.** Foliage v1 built the identity and the removal path for it and
  stopped short of the RPC, deliberately - the comment at
  `World.remove_flora_local()` writes out the call it is waiting for. Gathering
  is a launch skill in `../docs/DESIGN.md`, but it is a SKILL, and skills are
  not on this list until something is worth gathering for.
- **Day/night as a danger axis.** The cycle shipped in terrain v1 and light v1
  made it a real forty-minute day (D52) with four hours plus eerie. Pillar 2
  wants darkness to mean something; that needs the enemy first. Foliage v1
  added the first things that exist only after dark - fireflies and glowing
  mushrooms - and they are deliberately on the warm side of the register, not
  the tense one.
- **Breaking terrain.** Settled in `../docs/DESIGN.md`: no, in v1. It stays
  settled.

## Someday

Not rejected, not queued. Nothing moves up from here without a playtest or a
phase report saying it should.

- **The shore's width.** `SHORE` is one block of grey gravel round every lake,
  and the *width* is the real problem: a one-block rim reads as a drawn line at
  20 m and as nothing at 60 m. A shore that widened with the lake's size would
  give the postcard shot a foreground. Worldgen, so it waits for the
  world-truth break.

- **Meadow patches.** The close-up is busy with an even scatter - the
  "confetti" look v1 named. The interesting version is not a density number at
  all: drifts, the way `_meadow()` already clusters flowers, so a meadow is
  patches of tall grass in a shorter field rather than an even scatter at any
  density.

- **Explosions that destroy terrain.** Wanted, but it drags two roadmap items
  forward with it: the edit log grows without bound and is sent in full to
  every joining player, and remeshing eight chunks is a visible hitch.
  Edit-log compaction is still needed. It also has to answer "breaking terrain
  is decided: no, in v1" first.

- **Found warm places** - villages, hot springs. Under the tone these are rare
  on purpose: a lit window in a valley at dusk should land like the song's
  swell, and never a carpet of lit villages.

- **Taming or befriending select creatures.** The mountain folk's small ways
  include calling and calming beasts (D72), so this has a home in the fiction
  now. The *táltos*-horse pattern - the shabby nag that is secretly great - is
  the north star if a mount ever exists; the world's own traversal answer is
  rails, cable cars, ferries and airships (D24, D73, D81).

- **Megafauna encounter design** - witnessed more than fought
  (`../docs/DESIGN.md`, Creatures: Megafauna). The tone's cosmic dread at the
  edges: scale and indifference, never horror dressing.

- **Deeper mimics**: boulder, copse, hillside - the distance-escalation of
  "seeming frays" (`../docs/DESIGN.md`, Creatures: Mimics).

- **The eagle as information layer** - circling marks large creatures and
  carrion - and the eagle-luck superstition in lore fragments.

- **A ward rune** - a small safe circle for the co-op revive. Named as a
  Someday by D65; the two runes are the whole of v1.

- **Sound asset acquisition list.** The alpine raptor cry is priority #1
  (freesound / Kenney; licence-check everything for an open-source repo - CC0
  or CC-BY with attribution recorded, never NC or ND). The bible's sound line
  (`../../Kubik-bible/00-TONE.md`): slow builds, strings and synth, wordless
  choir, the alphorn, one motif that grows the further out you go.

- Full class system *(contradicts a pillar)*
- Skill trees *(contradicts a pillar)*
- Base building *(contradicts a pillar)*
- Arbitrary block placement *(contradicts a pillar)*

The tagged entries contradict a pillar as written. That is fine as a parking
space, but building one means amending the pillar first, deliberately and in
writing - not discovering halfway through a branch that the design moved.

**Struck from Someday by the bible, so nobody re-adds them:**

- **More races.** There is one people and nobody changes (D37, D70). Body
  types are not races and never carry a perk (D51).
- **A full night system: aggro nights, attacks on the fire, a hostility dial
  on a timer.** The fire is where dread ENDS (D39). A fire that gets attacked
  stops
  being the warm register, and a dial that makes the whole world hostile on a
  timer is the frantic survival the tone forbids. What night is allowed to be
  is darker, quieter and further from help.
- **A texture atlas.** No textures, on anything, ever (pillar 2).

## The sea, and everything beyond the Alps

**This is not a second act and not an expansion; it is rings 2 to 4 of the one
world (D26, D44).** The section that stood here framed the sea as a named
post-1.0 expansion arc, with island kingdoms as a new far-zone content tier
and a water-race homeland across the water explaining why that race lived in
the mountains. All of that is gone: there is one people and nobody changes
(D37, D70), so no race needs a homeland; there is no second act; and the sea
is not a sequel - it is what ring 2 becomes as you keep walking outward from
the capital.

What the bible actually has
(`../../Kubik-bible/lore/10-geography.md`): a long thin continent with the
Alps as its spine, the north side green and the south side drying into desert,
two seas - the north cold with fjords and ice islands, the south warm with
sand islands and reefs. Ring 2 is the continent's edges, desert and coasts,
with nomads and fisher folk. Ring 3 is the near islands, and the end of the
airships' range (D73). Ring 4 is the far islands: uninhabited, the worst
weather, eerie by default, made of crystal, with the Builders' city at the
farthest point - a whole black-and-gold city, intact, empty, mountain-sized.
**That is the end of the map: the last authored place, not a wall.** Beyond it
the seeded terrain goes on as sea and eerie weather with nothing in it.

What that means for the code today, and it is the only thing it means:

- **Never hardcode "far away = mountains".** Direction and edge treatment stay
  configurable. This is unchanged and it is why the rule was recorded in the
  first place.
- **Ring, not region.** Wildness is distance from the capital in metres,
  driving a ring table - biome, weather, ruin size, lit windows, how strong the
  magic is (D44, D63). That is an adapt of `wildness_at`, listed in
  `../RECONCILIATION.md` § 7 as the highest-leverage one in the world, and it
  lands in the world-truth break.
- **Interactive water is still Water v1's**, and swimming is still not v1.
  Wading, shores and rivers into the basin lakes are the near work; nothing
  about the sea is needed for them.
- **Foreshadowing is free and lore fragments are the vehicle**: shells in high
  ruins, salt references, a lighthouse beam on the horizon. Longing is free;
  water physics are not.

- **Trailer moment to build toward:** two players crest the last ridge and see
  open water for the first time.

## The Director

**The doctrine moved out of this repo.** It is
`../../Kubik-bible/director/` - eight principles, eight hardening rules (D34),
the five verbs with their real field shapes, and the v0/v1/v2 roadmap -
pointed at by `../docs/DIRECTOR.md`. What follows is the argument that got the
director promoted to a pillar, kept because the reasoning is worth more than
the summary.

**The opportunity.** LLMs in games are not chatbot NPCs or generated dialogue.
The unit of value is *goal-directed improvisation under constraints* - a
tabletop game master. The destination and the stakes are authored; the path
there is invented fresh in response to what the players actually do, the way a
coding agent holds the requirements and routes creatively.

**The architecture: two layers.** Authored truth underneath - what is real,
what characters know and want, which outcomes are possible. Generative
intelligence on top - how it is expressed, how the middle unfolds. The model
never invents the world's facts; it only performs within them. Applications:
NPCs with fixed goals but adaptive tactics, companions with real memory,
quests with fixed beats but emergent connective tissue, and a *semantic
director* that reads what the journey means - not the health bars - and shapes
events accordingly.

**The delivery doctrine.** Subtle and invisible, the way physics engines
became. Market the experience, never the technology. Steer through opportunity,
never railroad - Westworld's capability without its manipulation.

**The timing claim.** The 2023-25 AI-NPC wave failed because it was chatbots
in costumes on immature tech; the failures mark infancy, not a ceiling. The
conversational quality now exists, costs are collapsing, and the unsolved part
is game design, not capability - so the field is open for whoever ships the
first non-tacky version, probably a small game built entirely around one
constrained instance of the idea.

**Against the pillars.** It serves pillar 3 directly - a director that makes
ranging outward *mean* something is the world being the content - and it can
serve pillar 1 (a companion that remembers what the two of you did). It
touches nothing in pillar 2. What it must not become: a menu, a chat window,
or a source of facts the world did not author.

**What it asks of the code today** is the three habits in `../CLAUDE.md` and
architecture decision 6 in `../README.md`: facts as data read by ID, the
host's journal, and the director acting only through the verb list, via the
one mutation path. Nothing to build now; nothing to hardcode against later.

### The ladder

**The rungs are the bible's** (`../../Kubik-bible/director/30-roadmap.md`), not
this file's, and two of the old rungs were wrong. v2's stranger is not the
storm-scholar - the *garabonciás* went with the old setting, and the bible's
stranger is a masked figure whose people is open, with the Engineer expedition
(D79) as a candidate. And the pivot's knowledge ladder (D74, D80) **adds no
rung and no verb**: a Builder fragment is a `place_fragment` at an authored
site the game owns, and it enters at v1, not v0.

- **Prerequisites (base game):** the trio playtest working, the host's event
  journal as typed facts with IDs, the campfire as a rest. That is phase 6.
- **v0 - the world remembers.** Fragments and rumours from the true event log,
  at the fire, read-only. Verbs: `place_fragment`, `spawn_rumor`. The
  template path alone must produce one first (D34 rule 5).
- **v1 - the world beckons.** Rumour-driven quest routing on authored beat
  spines. Verbs: `mark_site`, `advance_beat`, `reroute_beat`. The knowledge
  ladder's Builder fragments enter here.
- **v2 - the stranger speaks.** One NPC with fixed goals, knowledge bounds by
  fact and rumour ID, speech tagging (D34 rule 8) and an "I don't know"
  default.
- **Someday rungs**, in no order: the semantic director reading long-horizon
  patterns - sessions, not minutes; director-aware sites placed at generation
  that the verbs can address by ID; companions with real memory.

**Always, at every rung:** the Engineers' frontier (D77), the small falls
(D83) and every step of the knowledge ladder (D74) run with the director OFF.
The director only points. And it is marketed as the experience, never as the
technology.
