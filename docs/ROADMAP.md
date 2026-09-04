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
| damage, health bar, stamina / mana, stats | **D. Combat v1** | Stats v1 is the first stage of combat. The stats table + HUD bars were pulled forward into UI v1 (2026-08-31, `docs/plans/ui-v1.md`); D keeps damage and everything that moves them. |
| character animations | **D. Combat v1** | Attack, hit, downed poses on the character v1 procedural animator. Creature poses live in C. |
| physics - stuff falling | **D / G, small** | Dropped items and corpses fall and settle. Falling TERRAIN is "breaking terrain", unsettled - not here. |
| water, rivers | **B. Water v1** | Plan B's unwritten second half. Hooks left by foliage v1. |
| lakes | **B. Water v1** + look v2 | Lakes exist since terrain v1. Look v2 Stage 4 restyles the surface; Water v1 does shores, inflow / outflow, wading. |
| oceans | **Second Age** | Post-1.0 expansion arc, `IDEAS.md`. Only obligation now: never hardcode far-away = mountains (the coast is a direction; the world is unbounded since 2026-08-31). |
| save world, reload, settings | **F. Session v1** | `DESIGN.md`: one host save file, world edits + every character. Settings and pause menus. |
| UI | cross-cutting + **UI v1** | The frame is one pass (UI v1, an explicit queue jump by Marcel 2026-08-31: HUD framework, scaling, compass strip, hotbar shell, stats table, sheet, party icons - `docs/plans/ui-v1.md`); each epic still fills its slice into that frame: menus (F), map screen (I), toast (J), inventory (G). |
| mini map | resolved, **none** | Settled 2026-08-31: no minimap, not even a toggle. The compass strip (UI v1) + the fog-of-exploration map screen (I) are the whole answer. |
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

### A4. Character v2 - the people  *(done, 2026-08-29)*

Ran before Wave 1 rather than after it, and the reason is a dependency rather
than a preference: **creatures v1 builds a quadruped on `Animator.RIG_SHAPES`
and combat v1 builds hit, stagger and death poses on `pose_for()`.** Both are
cheaper against a rig that already has a knee than against one that grows one
underneath them, and every combat pose written against single-segment limbs
would have been rewritten.

What it leaves for those two: `RIG_SHAPES` takes an optional `lower` key per
limb, so a quadruped can have knees or not without anything branching on
species; `LocomotionState` is still the seam, and an enemy driven by AI fills
the same struct a player fills from input; and the critter is at the new grid,
16,380 triangles, ready to be something.

`docs/plans/character-v2.md` is the design, `docs/plans/character-v2-tech.md`
the build plan, `docs/status/character-v2.md` what actually happened - including
the three places the run did not meet its own gate.

### A6. Look v3 - the painted world  *(direction settled 2026-08-31, re-cut 2026-09-01, plan not written)*

The register change: `DESIGN.md` § Art direction, re-cut twice. 2026-08-31:
up close the world becomes a painting - sculpted forms, family-toned paint,
dense dressing, soft light. 2026-09-01: the poster is retired at distance
too - trees v3 makes near and far one geometry family, so one surface
language runs to the fog - and the direction is named **ART DECO FANTASY**:
Deco as the grammar of the built world only (monuments, gates, gear
ornament, UI), nature as sculpted-vox naturalism, the poster era kept as
colour discipline. Two lanes when it runs: **characters** (parts library
re-authored to the knight/barbarian bar, gear and weapons with it,
Blockbench round trip as the authoring surface) and **world** (painted
terrain tones and strata through the mesher, flora density, the lighting
pass; the forest half is trees v3's sculpted library, not the trees v1
silhouettes). Structures excluded by scope - Sites v1 is born at this
fidelity instead, carrying the Deco grammar from its first stone. Gates:
the KNIGHT TEST and the BELONGING TEST, both in DESIGN.md. Sequenced after
distance v5 and trees v3 so the trio is modelled once. Territory when
planned: character parts data + `tools/parts_author/` + `scripts/tools/`
(characters lane); `scripts/world/` mesher colour path + `look.gd` + flora
(world lane). 2+ nights, likely two separate plans.

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

**D1 is DONE**, pulled forward into world feel v1 night 2 (2026-08-27):
clients send input, the host simulates every body, the host broadcasts. Nothing
about damage was trustworthy before that and now the path exists. What was
pulled forward is the AUTHORITY only - no stats table, no attack, no HUD bar.

Also delivered there, as physics rather than combat: **ragdoll's prerequisite**.
Bodies exist, they are host-simulated, and they replicate. The spec, not built:
*the downed pose becomes a body for 2 s* - on entering POSE_DOWNED the host
promotes the character capsule to a `WorldBody`-like rigid body with the
character's mass, lets knockback impulses land on it, and hands control back
when it settles or the timer expires. The table row and the replication path
are already there; what is missing is a body whose shape is a capsule rather
than a convex hull, and a rule for what the animator does while it is one.

Then: stats (health, stamina, mana as one table), damage events through
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

**Character v2 already built the visible half.** Six armour slots exist on the
wire, four of them with geometry; `Armour` is the table of pieces and tiers;
`CharacterView` draws whatever a def says is worn, on every peer. What Items v1
adds is everything about WHERE gear comes from - the item table, pickup, drop,
the inventory, and the rule about what grants a tier - and one deletion: the
debug key that cycles a character's tier says in the code that it is
scaffolding, exactly as character v1's `X` key did for `sit`.

The two empty slots are the point of having declared them. `legs` and `hands`
carry no geometry and reserve their bytes, so filling them is art rather than
another wire version.

Item table (facts as data), pickup / drop as mutations, a small inventory,
wolf drops, the gathering
RPC at `World.remove_flora_local()`, the first gatherable plants. Gathering
was parked until something was worth gathering FOR - a campfire that wants
wood and a bolt that wants a reagent is that. 1 night.

**Felled trees**, specified here and not built. World feel v1 left the `log`
row in `BodyTable` for it: a gathered tree becomes a `log` body spawned lying
at the stump, and its trunk is removed from the column through the EDIT path -
the same path a broken block already takes, so it survives streaming and
replays on reload like any other edit.

The reason it was not built with the other bodies is worth keeping: a snag is
not a decoration, it is a tree SPECIES stamped into the chunk as voxels, so
promoting one at generation time changes what the world contains - and world
feel v1's hard rule 1 froze the heightmap, the config hash and the tree count
outside two named stages. Doing it as a gathering EDIT instead sidesteps that
entirely: the world still generates the tree, and the player removes it.

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

*2026-09-04 (D84): the reconciliation's order is the queue now, and Marcel pulled the horizon to the front. Running: horizon v1 `||` mesher v1 (`docs/plans/horizon-v1.md`, `docs/plans/mesher-v1.md`). Next: the world-truth break (real relief D45, rings from the capital D44, lakes and zones per tile, the generator's truth in C++), then people and fire, buildings, the round 3 scene. The waves below are the queue behind those and their internal order still holds.*

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

Critical path: **flora lands -> ~~D (input path)~~ -> playtest 1 -> E -> F ->
K v0 -> K v1.** Everything else hangs off it in parallel.

D's first stage - the host-authoritative input path - was the single most
unblocking piece of work, and it **landed in world feel v1 night 2**. Combat,
death, saves and the journal were all sitting on it; the next thing on the
path is playtest 1.

## 4. Pushbacks, per the `CLAUDE.md` rule

- **Mini map.** A live top-down minimap fights pillar 3 and the camera
  decision ("sold on reading landscape at a glance"). What the game wants is
  a compass and a map that fills in as you range - exploration as
  progression, which is the pillar. *Resolved 2026-08-31: Marcel agreed, and
  dropped the off-by-default-toggle escape hatch too. No minimap, ever.*
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
