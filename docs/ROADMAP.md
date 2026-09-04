# Roadmap - the long queue, batched

Rewritten 2026-09-04 against the bible as of D84; where an older document
disagrees, the bible wins.

Recorded 2026-08-25 from Marcel's brain-dump and ranked against the pillars.
**The top of the queue is no longer this file's to decide.** Since the
reconciliation (2026-09-03) the order is `../RECONCILIATION.md` § 9 and
`../CLAUDE.md` § Working order, reordered by Marcel on 2026-09-04 for the
north star (D84). `IDEAS.md` Next 3 says what runs next; this is the queue
behind it, grouped into the bigger things each item belongs to, and the order
and parallelism they can run in.

## 1. The phases

The spine. Nothing from a later phase is pulled forward except where
`../RECONCILIATION.md` § 9 says so.

| Phase | Work | State |
| --- | --- | --- |
| 0 | Housekeeping: the house generator and its outputs into `Kubik-assets`, the seller fields in the licence records, the asset mount synced | in progress |
| 1 | **Real light** - the engine's sun, soft sky-tinted shadows, sky ambient, filmic tonemap, four hours plus eerie, volumetric fog's three jobs, the bible palette, the film lens (D40), reflective water | **done**, merged 2026-09-04 |
| 1b | **The chunk mesher in C++** (D56) - voxels in, arrays out, one flat colour per material plus per-cube noise, no baked corner shading | **done**, merged 2026-09-04 |
| 1c | **Horizon v1** (D41, D44, D84) - the tile store, voxels anywhere, the far field to 32 km in persistent per-ring and per-sector pieces, one material source for every level, the fog ramp, a floating origin, the sprint probe | running from 2026-09-04 |
| 2 | **The world-truth break** (D56, timing amended by D84) - real relief (D45), rings measured from the capital (D44), the tiled heightmap store, lakes and zones per tile, the generator's truth in C++ | next, the day 1c lands |
| 3 | **People and fire** - the bought templates as the character path (D1), two players at a campfire, the campfire as the first warm light | queued |
| 4 | **Buildings** - the `BuildingModels` loader, placement, the landmark gate (D43, D47, D48) | queued |
| 5 | **The round 3 scene and its report** (`../../Kubik-bible/ROUND-3-BRIEF.md`) | queued |
| 6 | The journal with typed facts and IDs, the nouveau UI, creatures, combat and death | months |

**Why the order changed on 2026-09-04.** D56 had scheduled every world-truth
change after the round 3 scene. Marcel, playing light v1, found the day read
as a low view distance and the far country ended in fog at 3 km. D84 makes the
horizon the north star and moves the world-truth break to right after it,
before people and fire, because both of them are cheapest to change before any
content is authored on a seed. The scene slips by about a month; Marcel's
call.

## 2. The list as given, and where each item lands

| Marcel's item | Belongs to | Note |
| --- | --- | --- |
| creatures | **C. Creatures v1** | Phase 6. The trio: wolf / marmot / eagle. The fantastic tier is the bible's, not a folklore grab-bag: beasts that were once ordinary, and the animal warriors as creatures of the outer rings (D71). |
| animals | **C. Creatures v1** | Marmot and eagle ARE the animals. The purchased forest pack has its own grain, about 1.9 cm per voxel (D53). |
| AI animal behaviour | **C. Creatures v1** | Stance settled in `DESIGN.md`: LimboAI, `AStarGrid2D` over the heightmap, boids, utility AI, the five rules. Unchanged by the bible. |
| combat | **D. Combat v1** | Light attack, dodge / block. Restrained: no blood, no gore, no cruelty as spectacle (D39). |
| combat, how it works | **D. Combat v1** | Sword, staff, spear, then bow - the build order by asset cost (D64). No gunpowder anywhere in the world (D62). |
| damage, health bar, stamina / mana, stats | **D. Combat v1** | The stats table and HUD bars were pulled forward into UI v1 (2026-08-31, `plans/ui-v1.md`); D keeps damage and everything that moves it. `mp` stays with the runes (D54, D65). |
| character animations | **D. Combat v1** | Attack, hit and downed poses - on the packs' own clips now, not the procedural animator, since the characters are the bought templates (D1). |
| physics - stuff falling | **D / G, small** | Dropped items and corpses fall and settle. Falling TERRAIN is "breaking terrain": settled as no, in v1. |
| water, rivers | **B. Water v1** | Rivers into the basin lakes, shores, wading. Hooks left by foliage v1. |
| lakes | **B. Water v1** | Lakes exist since terrain v1; light v1 made the surface clear and reflective (D5). Water v1 does shores, inflow / outflow and wading. |
| oceans | **B, later, and the world's own rings** | Not a separate age. The sea is rings 2 to 4 of the one world (D26, D44) and the Builders' city at the farthest point is the last authored place, not a wall. Only obligation now: never hardcode far-away = mountains; direction and edge treatment stay configurable. |
| save world, reload, settings | **F. Session v1** | `DESIGN.md`: one host save file, world edits plus every character. Settings and pause menus. |
| UI | cross-cutting + **UI v1** | The frame is one pass (UI v1, a queue jump by Marcel 2026-08-31, `plans/ui-v1.md`); each epic fills its slice. **The ornament layer is a redo**: deco geometry on paper is the exact don't in the style bible, and under D2 the paper layer is Art Nouveau. The behaviour underneath stays. |
| mini map | resolved, **none** | Settled 2026-08-31: no minimap, not even a toggle. The compass strip plus the fog-of-exploration map screen are the whole answer, and the tone forbids a screen full of markers. |
| castles and structures | **H. Sites v1**, phase 4 | Promoted because quests need places to point at - and because the bible has four building families and a landmark gate. |
| random map, fixed locations always generate | **H. Sites v1** | Spawn already does this by construction. Extend it to a landmark table with a `site_type` on every entry. |
| place names | **H. Sites v1** | Names on the landmark table. Facts as data - the director reads them by ID (D34 rule 1). |
| biomes | **the rings, not a table** | Terrain v2's seven elevation zones stay as a rendering and placement fact. What "biome" means in this world is the ring: distance from the capital drives biome, wildness, ruin size, weather severity, lit windows and how strong the magic is (D44, D26, D63). That is an adapt of `wildness_at` and it lands in phase 2. |
| items | **G. Items v1** | Pickup / drop, inventory, visible gear slots, the gathering RPC foliage v1 left waiting. |
| skill tree | **J. Skills v1** | Pillar conflict - see pushbacks. Five skills, XP by doing, a READ-ONLY sheet. The knowledge layer (D74, D80) is a different thing and is capped at one page and five steps; it is never a tree either. |
| procedural quests, fixed direction, infinite | **K. Director v1** | "The world beckons" in the bible's `../../Kubik-bible/director/30-roadmap.md`: authored beat spines, directed connective tissue. Gated on C, D, E, H and v0. |

Two things Marcel did not list but the queue needs:

- **E. Campfire v1** - phase 3, and the most load-bearing object in the game.
  Respawn anchor for death (D), the rest for the director (K), the place
  saving happens (F), the origin of pacing and threat (D35), and the warm
  register the tone is built on. Nothing after it works without it.
- **The journal** - habit 2 in `../CLAUDE.md`. Structured host events. It
  exists as forty-seven lines of untyped dictionaries in memory; the bible
  asks for typed facts with IDs, a chronicler, salience and persistence
  (D34 rule 1), which is a redo and lives in F.

## 3. The epics that fill phases 3 to 6

Size is in overnight runs (one plan = one night on the Linux box). Territory
is the file set, for the zero-overlap rule when lanes run in parallel.

### B. Water v1 - rivers and shores

Rivers from the heightmap flow field into the basin lakes, shorelines, reeds
and water plants on the decoration layer, wading (slow, no swimming). Hooks:
`Lakes.shore_level_at_cell()`, the placement product's spare `base` case, the
last section of `status/foliage-v1.md`. Territory: `../scripts/world/` worldgen
and lakes, `worldgen_config.gd`, a new `../scripts/world/water/`. **Waits for the
world-truth break**, which moves every lake. 1-2 nights.

### C. Creatures v1 - the trio

Wolf (rusher), marmot (whistle and burrow), eagle (ridge orbit and cry). The
creature pipeline: LimboAI addon, `AStarGrid2D` built from the coarse
heightmap with per-species slope costs, boids for the eagle, utility AI for the
marmot, senses (sight cone, noise, scent downhill), pack convergence, memory on
the blackboard, burrows as smart objects placed at generation. Host-only
decisions, position and a state byte to clients. Consumes the wildness dial for
wolf density - **measured from the capital after phase 2** (D44), not from the
map centre. Facts as data: a species table. Territory: new
`../scripts/creature/`, `../scenes/creature/`, `../addons/limboai/`; one additive
spawn-sync hook in `game.gd`; a read-only heightmap accessor in `world.gd`.
2 nights.

### D. Combat v1 - stats, the light attack, the HUD

**D1 is DONE**, pulled forward into world feel v1 night 2 (2026-08-27):
clients send input, the host simulates every body, the host broadcasts.
Nothing about damage was trustworthy before that.

Also delivered there, as physics rather than combat: **ragdoll's
prerequisite**. Bodies exist, they are host-simulated, and they replicate. The
spec, not built: *the downed pose becomes a body for 2 s* - on entering
POSE_DOWNED the host promotes the character capsule to a `WorldBody`-like
rigid body with the character's mass, lets knockback impulses land on it, and
hands control back when it settles or the timer expires.

Then: stats (health, stamina, mana as one table), damage events through the
one mutation path, light attack / dodge / block, sword and staff and spear and
bow feel (D64), **the fire rune and the frost rune** (D65, amending D54 - the
bolts became runes; same mechanics, a spark and a chill, never a storm), hit
and downed poses, revive, HUD bars, dropped things fall and settle. Tuned for
two bodies (D46). **Death is quiet and remembered** (D39): the death event is a
journal entry before it is anything else. Territory: `../scripts/player/`,
`../scripts/character/` poses, `../scripts/ui/hud*`, the input path in `game.gd`.
2 nights.

### E. Campfire v1 - the first placeable

Placeable palette (campfire, torch, marker) at the world grain, light, regen,
respawn anchor, sit pose at the fire, the fire as the rest where the world will
later speak. Death rules from `DESIGN.md`: downed, revive, respawn at the last
fire. **Threat and pacing scale with distance from THIS fire** (D35), which is
a different dial from the wildness measured from the capital, and both exist.
Territory: new `../scripts/placeable/`, a placeable case in the edit path.
1 night.

### F. Session v1 - save, reload, settings, pause, journal

One host save file: world edit log plus every character plus placeables. Load
on the host, join handshake unchanged. Pause and settings menus (video, audio,
controls). The journal: a structured event log on the host - edit, death,
campfire, kill, first sight of a lake - written into the save, and **typed
facts with IDs** rather than untyped dictionaries (D34 rule 1), because the
director reads facts by ID and nothing else. Edit-log compaction probably comes
with it. Territory: `../scripts/game/` save and journal, `../scripts/ui/menu*`.
1 night.

### G. Items v1 - pickup, inventory, visible gear, gathering

**Character v2 built the visible half** and it survives the character rip: six
armour slots exist on the wire, four with geometry; `CharacterView` draws
whatever a def says is worn, on every peer. The two empty slots - `legs` and
`hands` - reserve their bytes, so filling them is art rather than another wire
version.

What Items v1 adds is everything about WHERE gear comes from: the item table
(facts as data), pickup and drop as mutations, a small inventory, creature
drops, the gathering RPC at `World.remove_flora_local()`, and the first
gatherable plants. **The tier ladder is not part of it**: armour is a tech
level, not a ladder to plate (D27). What it does own is the **rune stone as a
durability number** (D76) - carved once, thrown and fetched back like a spear,
dimming with use and recharged at a magic site, the same rule as the Engineers'
crystals. 1 night.

**Felled trees**, specified and not built. World feel v1 left the `log` row in
`BodyTable`: a gathered tree becomes a `log` body spawned lying at the stump,
and its trunk is removed through the EDIT path - the same path a broken block
takes, so it survives streaming and replays on reload. Trees v3 makes chopping
fell-as-a-unit rather than block-by-block.

### H. Sites v1 - the built world, its places and their names

Phase 4 in the reconciliation, and it is bigger than a landmark table now. A
`BuildingModels` loader as a sibling of `TreeModels`; buildings generated in
`Kubik-assets` at the tree grain and baked with three level-of-detail rungs
(D43, D48); a placement pass that owns roads, footprints and flattening; the
landmark generator with setbacks, flutes, sunburst and crown, baked straight
to `.ktree`. **Gates and dungeons are placed volumes** - a model against a
cliff with a separate interior stitched in behind the door (D47) - because the
terrain is a heightmap and makes no overhangs. Village houses are **enterable**
(D59): an open doorway, a stair against the back wall, a ceiling under the
roof, and about a third of a house's windows dark at night, chosen per window.

Plus: a fixed subset that always generates on every seed, place names for
sites, lakes, peaks and rings, lore fragments as data, and a `site_type` on
every site so `mark_site` has an address. Territory:
`../scripts/world/sites/`, a placement pass in the column path, `DESIGN.md`
World. 1-2 nights for the loader and placement; the generators are
`Kubik-assets`'s.

### I. Navigation v1 - compass, map, markers

A compass strip with placed markers and party members, a map screen that
reveals as you range (fog of exploration - ranging IS the progression), site
and place names from H drawn on it. **No live top-down minimap, ever.** The
map is the Engineers' map (`../../Kubik-bible/lore/10-geography.md`): accurate
for the continent, sketchy for the near islands, blank beyond, and the fog of
war is literal fog. Territory: `../scripts/ui/map*`, reads H and the marker
placeable from E. 1 night.

### J. Skills v1 - five skills, a read-only sheet

Blades, Bows, Magic, Mobility, Gathering. XP from doing, diminishing, never
decays, about +25% by level 10, a chunky unlock every five levels, a level-up
toast, a read-only character sheet. Needs D and G to have anything to award.
1 night.

**Not the same thing as the knowledge layer.** D74's five steps are recipes
and unlocked verbs found or taught, capped at one page (D80), gated on the
party's trust (D82) and never levelled. Skills measure what you have done;
knowledge is what you have been shown. Do not merge them into one system.

### K. Director v0 then v1 - the world remembers, the world beckons

v0: at the campfire, fragments and rumours from the journal via the sidecar,
verbs `place_fragment` and `spawn_rumor`, **the template path first** (D34
rule 5). v1: quest routing on authored beat spines - Marcel's "procedural
quests with a fixed direction and infinite generation" - verbs `mark_site`,
`advance_beat`, `reroute_beat`, and the knowledge ladder's Builder fragments
(D74). Gated by the `../CLAUDE.md` rule: not before the trio playtest, the
typed journal and the campfire exist. v0 1 night; v1 2+ nights and research.

The doctrine is `../../Kubik-bible/director/`; `DIRECTOR.md` is the pointer.

### Retired epics

- **A. Look v2 - the poster, refined.** Ran 2026-08-25 and is history. Light
  v1 deleted most of what it built - the shade ink, the banded fog, the poster
  sky, the linear tonemapper - and kept what it got right: the measured colour
  transfer, the time-of-day table, and the swatch and transfer gates.
- **A6. Look v3 - the painted world.** **OUT** (2026-09-03). Its register
  argument is settled by the bible's pillar 2 and pillar 5 and by D2, it was
  built by light v1, and what it was going to prove is proved by the round 3
  test scene instead. The KNIGHT TEST and the BELONGING TEST go with it. The
  number is retired, not reused.

### Parked

- **Breaking / falling terrain.** Settled in `DESIGN.md`: no, in v1.
  Re-settle in writing before any physics touches voxels.
- **A biome overhaul as a worldgen rewrite.** The rings are the answer (D44,
  D26) and they land in phase 2. Nothing else.
- **Swimming and sailing.** Not before wading, and not before the world is
  real-sized. Foreshadow with lore fragments in H; build nothing.

## 4. Sequence and parallelism

Rule for parallel lanes: zero-overlap file lists, and `game.gd` has ONE owner
per wave - the other lanes add a new file plus a one-line hook that Marcel
merges by hand.

```
NOW  (2026-09-04)
  1c. Horizon v1 -------- 3 nights   feat/horizon-v1, ganymede tmux horizon-v1
  (1b. Mesher v1 merged 2026-09-04; 1. Light v1 merged 2026-09-04)

NEXT - one epic, alone, because it changes what a seed produces
  2.  The world-truth break --- weeks   real relief (D45), rings from the
                                        capital (D44), lakes and zones per
                                        tile, the generator's truth in C++

THEN
  3.  People and fire ------- ~1 week   purchased_view.gd promoted, two
                                        templates, the campfire
  4.  Buildings ------------- 1-2 weeks BuildingModels, placement, the
                                        landmark gate
  5.  The round 3 scene ----- days      the brief's shots, the report into
                                        the bible

AFTER THE SCENE - three lanes, zero overlap
  C. Creatures v1 ---------- 2 nights   scripts/creature/, addons/
  D. Combat v1 ------------- 2 nights   scripts/player/, ui/hud, game.gd (owner)
  B. Water v1 -------------- 1-2 nights scripts/world/
        |
        v
  PLAYTEST 1: wolf / marmot / eagle plus the light attack, two players.

  E. Campfire v1 ----------- 1 night    scripts/placeable/, edit path (owner)
  F. Session v1 + journal -- 1 night    scripts/game/ save, ui/menu
  H. Sites v1 -------------- 1-2 nights scripts/world/sites/
        |
        v
  PLAYTEST 2: die, respawn at the fire, save, quit, reload, find the ruin
  you saw yesterday.

  G. Items v1 -------------- 1 night    scripts/items/, character gear
  I. Navigation v1 --------- 1 night    ui/map, reads H + E
  K. Director v0 ----------- 1 night    sidecar; reads the journal (F),
                                        speaks at the fire (E)

  J. Skills v1 ------------- 1 night    needs G + D
  K. Director v1 (quests) -- 2+ nights  needs H (sites) and v0
```

**Critical path: horizon v1 -> the world-truth break -> people and fire ->
buildings -> the scene.** Everything lettered hangs off the far end of it. The
campfire (E) is the single most unblocking piece after the scene: death, the
journal's most interesting events and the director's whole cadence sit on it.

## 5. Pushbacks, per the `../CLAUDE.md` rule

- **Mini map.** A live top-down minimap fights pillar 3 and the camera
  decision, and the tone forbids "a screen full of markers". What the game
  wants is a compass and a map that fills in as you range - exploration as
  progression. *Resolved 2026-08-31: Marcel agreed and dropped the
  off-by-default toggle too. No minimap, ever.*
- **Skill tree.** `DESIGN.md` Skills says the sheet is read-only on purpose.
  Five skills that level by doing gives most of the feeling. Building a tree
  means amending pillar 3 in writing first - and the knowledge layer is not a
  loophole: D80 caps it at recipes plus a handful of verbs and forbids a tree
  in the same sentence.
- **Oceans as a second game.** Not a second act and not an expansion. The sea
  is rings 2 to 4 of the one world (D26, D44), reached by walking, ferry and
  airship, and the airships have a range (D73). It arrives when the rings do,
  not as a sequel.
- **Procedural quests.** Wanted, and it is the fourth pillar's v1 - but the
  rule is base game first: no director work before the trio, the typed journal
  and the campfire. The infinite part is the director; the fixed direction is
  the authored beat spine.
- **Physics on terrain.** Only items and bodies fall. Voxels do not.
- **Biomes as a worldgen rewrite.** The seven elevation zones exist and are
  cheap; what the world actually needs is the ring table (D44, D26, D63), and
  that is one adapt of `wildness_at` inside phase 2, not a rewrite.
- **More races.** Asked for in the old Someday list. There is one people and
  nobody changes (D37, D70). Body type is square, lean or stocky, carries no
  perk (D51), and the starting people is soft and never a lock (D66). This one
  is not a pushback any more; it is decided.
- **A texture atlas.** Parked in the mesher since terrain v1. It is now
  forbidden: no textures, on anything, ever (pillar 2).
