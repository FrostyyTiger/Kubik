# Roadmap - the long queue, batched

Recorded 2026-08-25 from Marcel's brain-dump, then ranked against the four
pillars, the Next 3 in `IDEAS.md`, and what `DESIGN.md` has already settled.
`IDEAS.md` Next 3 stays the authority for what runs next; this is the queue
behind it, grouped into the bigger things each item belongs to, and the order
and parallelism they can run in.

## 1. The list as given, and where each item lands

| Marcel's item | Belongs to | Note |
| --- | --- | --- |
| creatures | **C. Creatures v1** | Next 3 #2. The trio: wolf / marmot / eagle. |
| animals | **C. Creatures v1** | Marmot and eagle ARE the animals. Herds and deer later, same pipeline. |
| AI animal behaviour | **C. Creatures v1** | Stance settled in `DESIGN.md`: LimboAI, `AStarGrid2D` over the heightmap, boids, utility AI, the five rules. |
| combat | **D. Combat v1** | Next 3 #2, the other half. Light attack, dodge / block. |
| combat, how it works | **D. Combat v1** | The design section of the combat plan. Sword / bow / staff. |
| damage, health bar, stamina / mana, stats | **D. Combat v1** | Stats v1 is the first stage of combat. HUD bars are its UI slice. |
| character animations | **D. Combat v1** | Attack, hit, downed poses on the character v1 procedural animator. Creature poses live in C. |
| physics - stuff falling | **D / G, small** | Dropped items and corpses fall and settle. Falling TERRAIN is "breaking terrain", unsettled - not here. |
| water, rivers | **B. Water v1** | Plan B's unwritten second half. Hooks left by foliage v1. |
| lakes | **B. Water v1** + look v2 | Lakes exist since terrain v1. Look v2 Stage 4 restyles the surface; Water v1 does shores, inflow / outflow, wading. |
| oceans | **Second Age** | Post-1.0 expansion arc, `IDEAS.md`. Only obligation now: never hardcode edge = mountains. |
| save world, reload, settings | **F. Session v1** | `DESIGN.md`: one host save file, world edits + every character. Settings and pause menus. |
| UI | cross-cutting | Not one item. Theme = look v2 Stage 6. Each epic owns one UI slice: HUD (D), menus (F), map (I), sheet (J). |
| mini map | **I. Navigation v1** | Pillar 3 tension - see pushbacks. Compass + a map that fills as you range. |
| castles and structures | **H. Sites v1** | "Found places" in Someday; promoted because quests need places to point at. |
| random map, fixed locations always generate | **H. Sites v1** | Spawn already does this by construction (terrain v2). Extend it to a landmark table. |
| place names | **H. Sites v1** | Names on the landmark table. Facts as data - the director reads them. |
| biomes | **H. Sites v1** (regions) | Terrain v2 already has seven elevation zones. "Biomes" = named regions anchored on sites, not a worldgen rewrite. |
| items | **G. Items v1** | Pickup / drop, inventory, three visible gear slots, the gathering RPC foliage v1 left waiting. |
| skill tree | **J. Skills v1** | Pillar conflict - see pushbacks. Five skills, XP by doing, a READ-ONLY sheet. |
| procedural quests, fixed direction, infinite | **K. Director v1** | This is "the world beckons" in `DIRECTOR.md`: authored beat spines, directed connective tissue. Gated on C, D, E, H and v0. |

Two things Marcel did not list but the queue needs:

- **E. Campfire v1** - Next 3 #3. Respawn anchor for death (D), the rest for
  the director (K), the place saving happens (F). Nothing in wave 2 works
  without it.
- **The journal** - habit 2 in `CLAUDE.md`. Structured host events. Costs
  nothing, must exist before the campfire says anything. Lives in F.

## 2. The epics

Size is in overnight runs (one plan = one night on the Linux box). Territory
is the file set, for the zero-overlap rule when lanes run in parallel.

### A. Look v2 - the poster, refined  *(planned, next night)*

`docs/plans/look-v2.md` + `look-v2-tech.md`. Already written. Includes the UI
theme (Stage 6) and the water surface (Stage 4). 1 night.

### B. Water v1 - rivers and shores

Rivers from the heightmap flow field into the basin lakes, shorelines, reeds
and water plants on the decoration layer, wading (slow, no swimming -
swimming is Second Age). Hooks: `Lakes.shore_level_at_cell()`, the placement
product's spare `base` case, the last section of `docs/status/foliage-v1.md`.
Territory: `scripts/world/` worldgen + lakes, `worldgen_config.gd`, a new
`scripts/world/water/`. **Collides with `feat/flora-streaming` - wait for it
to land.** 1-2 nights.

### C. Creatures v1 - the trio

Wolf (rusher), marmot (whistle + burrow), eagle (ridge orbit + cry). The
creature pipeline: LimboAI addon, `AStarGrid2D` built from the coarse
heightmap with per-species slope costs, boids for the eagle, utility AI for
the marmot, senses (sight cone, noise, scent downhill), pack convergence,
memory on the blackboard, burrows as smart objects placed at spawn. Quadruped
rig from character v1. Host-only decisions, position + state byte to clients.
Consumes `TerrainGenerator.danger_at()` for wolf density. Facts as data: a
species table like `Races`.
Territory: new `scripts/creature/`, `scenes/creature/`, `addons/limboai/`;
one additive spawn-sync hook in `game.gd`; a read-only heightmap accessor in
`world.gd`. 2 nights.

### D. Combat v1 - stats, the light attack, the HUD

Stage 1 is the carried ticket: player input onto the host-authoritative path
(currently local physics only) - nothing about damage is trustworthy before
that. Then: stats (health, stamina, mana as one table), damage events through
the one mutation path, light attack / dodge / block, sword + bow + staff
feel, fire bolt + frost bolt, hit and downed poses on the procedural
animator, revive, HUD bars, dropped things fall and settle. Tuned for two
bodies.
Territory: `scripts/player/`, `scripts/character/` poses, `scripts/ui/hud*`,
the input path in `game.gd`. 2 nights (1 for the input path + stats, 1 for
the attack + HUD).

### E. Campfire v1 - the first placeable

Placeable palette (campfire, torch, marker), light, regen, respawn anchor,
sit pose at the fire, the fire as the rest where the world will later speak.
Death rules from `DESIGN.md`: downed / revive / respawn at the last fire.
Territory: new `scripts/placeable/`, a placeable case in the edit path.
1 night.

### F. Session v1 - save, reload, settings, pause, journal

One host save file: world edit log + every character + placeables. Load on
the host, join handshake unchanged. Pause and settings menus (video, audio,
controls) under the look v2 theme. The journal: a structured event log on
the host (edit, death, campfire, kill, first sight of a lake) - written into
the save. Edit-log compaction from Someday probably comes with it.
Territory: `scripts/game/` save + journal, `scripts/ui/menu*`. 1 night.

### G. Items v1 - pickup, inventory, visible gear, gathering

Item table (facts as data), pickup / drop as mutations, a small inventory,
the three gear slots rendered on the character, wolf drops, the gathering
RPC at `World.remove_flora_local()`, the first gatherable plants. Gathering
was parked until something was worth gathering FOR - a campfire that wants
wood and a bolt that wants a reagent is that. 1 night.

### H. Sites v1 - fixed places on a random map, and their names

A landmark table: N site types (ruin, shrine, hot spring, a castle on a
bench, the storm-scholar's tower later) with placement rules, and a fixed
subset that ALWAYS generates on every seed at a seed-independent role (as
spawn does now). Place names for sites, lakes, peaks and regions, from a name
table per region. Regions = the seven elevation zones plus distance, each
given a name and one signature - this is what "biomes" means here. Lore
fragments as data (the Second Age's shells in high ruins). A `site_type` on
every site so the director's `mark_site` has an address.
Territory: `scripts/world/sites/`, a structure stamper in the chunk path,
`docs/DESIGN.md` World. 1-2 nights.

### I. Navigation v1 - compass, map, markers

A compass strip with placed markers and party members, a map screen that
reveals as you range (fog of exploration - ranging IS the progression), site
and place names from H drawn on it. No live top-down minimap by default -
see pushbacks.
Territory: `scripts/ui/map*`, reads H and the marker placeable from E.
1 night.

### J. Skills v1 - five skills, a read-only sheet

Blades, Bows, Magic, Mobility, Gathering. XP from doing, diminishing, never
decays, +25 % by level 10, a chunky unlock every five levels, a level-up
toast, a read-only character sheet. Needs D (Blades / Bows / Magic) and G
(Gathering) to have anything to award. 1 night.

### K. Director v0 then v1 - the world remembers, the world beckons

v0: at the campfire, fragments and rumours from the journal via the sidecar,
verbs `place_fragment` and `spawn_rumor`. v1: quest routing on authored beat
spines - THIS is Marcel's "procedural quests with a fixed direction and
infinite generation" - verbs `mark_site`, `advance_beat`, `reroute_beat`.
Gated by the `CLAUDE.md` rule: not before the trio playtest, the journal and
the campfire exist. v0 1 night; v1 2+ nights and research.

### Parked

- **Second Age - oceans, swimming, sailing, islands.** Post-1.0. Foreshadow
  with lore fragments in H; build nothing.
- **Breaking / falling terrain.** Unsettled in `DESIGN.md`. Settle it in
  writing before any physics touches voxels.
- **Full biome overhaul.** Only if a playtest says the seven zones + named
  regions are not enough.

## 3. Sequence and parallelism

Rule for parallel lanes: zero-overlap file lists, and `game.gd` has ONE owner
per wave - the other lanes add a new file plus a one-line hook that Marcel
merges by hand.

```
WAVE 0  (now)
  flora-streaming lands on main          (other session, in Kubik-flora)
  A. Look v2                             (the planned night)

WAVE 1  - three lanes, zero overlap, after flora lands
  C. Creatures v1 ----------- 2 nights    scripts/creature/, addons/
  D. Combat v1 -------------- 2 nights    scripts/player/, ui/hud, game.gd (owner)
  B. Water v1 --------------- 1-2 nights  scripts/world/
        |
        v
  PLAYTEST 1: wolf / marmot / eagle + the light attack, two players.
  Answers Next 3 #2. Re-rank everything below on what it teaches.

WAVE 2  - three lanes
  E. Campfire v1 ------------ 1 night     scripts/placeable/, edit path (owner)
  F. Session v1 + journal --- 1 night     scripts/game/ save, ui/menu
  H. Sites v1 --------------- 1-2 nights  scripts/world/sites/, chunk stamper
        |
        v
  PLAYTEST 2: die, respawn at the fire, save, quit, reload, find the ruin
  you saw yesterday. Answers Next 3 #3.

WAVE 3  - three lanes
  G. Items v1 --------------- 1 night     scripts/items/, character gear
  I. Navigation v1 ---------- 1 night     ui/map, reads H + E
  K. Director v0 ------------ 1 night     sidecar; reads the journal (F), speaks at the fire (E)

WAVE 4
  J. Skills v1 -------------- 1 night     needs G + D
  K. Director v1 (quests) --- 2+ nights   needs H (sites) and v0
  Regions / biome deepening, physics polish - only if a playtest asks
```

Critical path: **flora lands -> D (input path) -> playtest 1 -> E -> F ->
K v0 -> K v1.** Everything else hangs off it in parallel. The single most
unblocking piece of work is D's first stage - the host-authoritative input
path - because combat, death, saves and the journal all sit on it.

## 4. Pushbacks, per the `CLAUDE.md` rule

- **Mini map.** A live top-down minimap fights pillar 3 and the camera
  decision ("sold on reading landscape at a glance"). What the game wants is
  a compass and a map that fills in as you range - exploration as
  progression, which is the pillar. If Marcel wants the minimap anyway, it is
  a settings toggle, off by default, and it goes in I.
- **Skill tree.** Tagged in `IDEAS.md` Someday as contradicting a pillar, and
  `DESIGN.md` Skills says the sheet is read-only on purpose. Five skills that
  level by doing is already designed and gives most of the feeling. Building
  a tree means amending pillar 3 in writing first.
- **Oceans.** Second Age. Not before the Alpine game ships.
- **Procedural quests.** Wanted, and it is the fourth pillar's v1 - but the
  rule is base game first: no director work before the trio, the journal and
  the campfire. The infinite part is the director; the fixed direction is the
  authored beat spine. Both are in `DIRECTOR.md` already.
- **Physics on terrain.** Only items and bodies fall. Voxels do not, until
  "breaking terrain" is settled.
- **Biomes.** Seven elevation zones exist; a rewrite would move the terrain
  under everything tuned since. Named regions on top (H) is the cheap
  version. Escalate only from a playtest.
