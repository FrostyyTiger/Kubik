# Creatures v1 - status, night 1

The run doc for `docs/plans/creatures-v1-tech.md`, night 1 (Stages 0-8) on
`feat/creatures-v1`, branched from `main` at `85e2b19`. Written stage by
stage as the night goes; numbers carry their provenance
(**deterministic** / **probe median of N** / **single run** / **eye**), and
anything chosen by eye is an F10 row.

Two other lanes - `feat/distance-v3` and `feat/ui-v1` - ran on this box the
same night. Nothing under `scripts/world/` was written; `game.gd` takes the
one `elif` and the one banner block and nothing else.

---

## The baseline (Stage 0, deterministic)

Re-measured on ganymede, Godot **4.7.2.stable.official.ed1daf0bf** at
`~/bin/godot`, and this is what hard rule 1 holds every later stage against:

| what | value |
| --- | --- |
| worldgen probe seed | 42 |
| config hash | `3d45b8fc` |
| heightmap hash | `76cccdb6` |
| spawn | `(-44, -124)` = (-22 m, -62 m), altitude 28 m, slope 0.1 deg |
| danger at spawn / far corner | 0.00 / 1.00 |
| nearest tree to spawn | 59.4 m, 0 inside the 24 m clearing |

The three gates, all green at Stage 0:

```
$G --headless --path . scenes/selftest.tscn              -> all passed
$G --headless --path . scenes/character/selftest_character.tscn -> 36 tests, all passed
$G --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
```

The heightmap hash and spawn agree with `STATUS.md`'s trees v1 record, so
this branch starts on the same world every other lane is standing in.

---

## Stage 0 - the library ladder came down on rung (b): Beehave 2.9.3

**The rung taken: (b), Beehave 2.9.3, vendored at `addons/beehave/`, MIT,
pure GDScript, 676 KB, 45 `.gd` files, no binaries.** Upstream
`bitbrain/beehave` tag `v2.9.3` (2026-08-18), copied unmodified.

### Why not rung (a), which is what the plan wanted

Rung (a) was tried first and properly. What was found:

- **There is no LimboAI GDExtension built for Godot 4.7.** The current
  release, **v1.8.1** (2026-08-20), ships thirteen assets; the only
  GDExtension one is `limboai+v1.8.1.gdextension-4.6.zip`, built against
  4.6. Every `godot-4.7.2.*` asset in that release is a **custom Godot
  editor build** - LimboAI compiled in as an engine module - which is a
  different and much larger proposition than vendoring an addon, and is not
  what the plan authorised.
- **Its `compatibility_minimum` is `4.2`, and it does load on 4.7.2.** The
  class probe is clean: `BTPlayer`, `BehaviorTree`, `BTTask`, `Blackboard`,
  `BTSequence`, `BTSelector`, `BTAction`, `BTCondition` all report
  `ClassDB.class_exists() == true`, and a `--script` run exits 0.
- **But it aborts the editor on a cold import.** With the addon present and
  `.godot/` absent, `$G --headless --path . --import` runs the whole import
  to completion and then dies at shutdown: **SIGABRT, core dumped, exit 134,
  and no message on stdout or stderr at all.** Warm imports afterwards are
  clean, which is what makes it easy to miss.
- **Reproducible, and it is LimboAI's.** Cold-cache runs abort every time; a
  project with the same `project.godot` and no addon exits 0; and
  **v1.6.0** (the older `gdextension-4.4` line) aborts identically. Two
  release lines, same failure.

Stage 0's stated proof for rung (a) is "`--import` clean plus a one-line
class probe". Half of it passed and half of it did not, so the ladder moved
on - which is the ladder working, not the ladder failing. The judgement
call, recorded because the plan did not spell this case out: a load that
succeeds at runtime but core-dumps the setup command this project documents
is a **fail**. This branch is not the place to hand Marcel the repo's first
GDExtension as a thing that crashes on checkout, on a night nobody can ask
him about it.

### What rung (b) cost, and what it did not

- **Nothing downstream changes.** The plan already says "the wolf's tree
  logic is the same shape on any rung", and it is: Beehave's composites are
  plain `Node`s, so the wolf's states are built with `add_child`.
- Cold import of the real repo with Beehave vendored: **exit 0**. All three
  gates green, `heightmap# 76cccdb6`, spawn `(-44, -124)` - baseline held.
- Tick statuses, asserted rather than assumed:
  `SUCCESS = 0, FAILURE = 1, RUNNING = 2`.
- **No `class_name` collisions.** Beehave declares 33 global classes against
  Kubik's 65; the intersection is empty. The generic ones to know about are
  `Blackboard`, `Composite`, `Leaf`, `Decorator` and `TreeNode` - this lane's
  own shared board is `PackBoard`, deliberately not `Blackboard`.
- **`project.godot` is untouched.** Beehave ships an editor plugin
  (`plugin.cfg`), and enabling it is an editor convenience for the visual
  tree inspector. The runtime classes resolve without it, which was verified
  before vendoring: a `--script` run instances `BeehaveTree` and
  `SequenceComposite` with the plugin disabled.
- The load proof lives in `scripts/tools/selftest.gd` as
  **`behaviour library`**, under the `# CREATURES V1` banner. It reads the
  version out of `plugin.cfg` rather than restating it, so the pin cannot go
  stale silently.

### For Marcel to rule on

- **LimboAI is not closed, it is deferred.** If the visual behaviour-tree
  editor is worth wanting, the honest routes are (1) wait for an upstream
  GDExtension built for 4.7, or (2) file the cold-import abort upstream with
  the repro above. Beehave is a real behaviour-tree library and not a
  stopgap, so there is no deadline on this.

---

## Stage 1 - the species table and the event schema

`scripts/creatures/species.gd`, `class_name Species`: the `Races` doctrine
applied to animals. Three rows indexed by `WOLF / MARMOT / EAGLE`, seventeen
required columns each, static accessors, prose `silhouette`, and the
warn-once-and-fall-back contract copied from `Races._warn_once`.

**Every number below was chosen on a headless box and none of it was chosen
by watching a wolf.** All of it is an F10 row in Stage 8 (provenance: **eye**,
except where a column is a design decision rather than a feel).

| | wolf | marmot | eagle |
| --- | --- | --- | --- |
| archetype | rusher | ambient | sky |
| walk / run (m/s) | 2.0 / 7.5 | 1.0 / 4.5 | 0.8 / 18.0 |
| sight | 40 m / 110 deg | 30 m / 240 deg | 120 m / 90 deg |
| hearing | 30 m | 45 m | 0 m |
| slope cost up / down / cliff | 2.6 / 0.8 / 42 deg | 1.4 / 1.0 / 38 deg | 1.0 / 1.0 / 90 deg |
| territory | 150 m | 40 m | 400 m |
| home | den | burrow | crag |
| pack | 2 | 4 | 1 |
| flank offset band | 90-140 deg | - | - |
| huntable | **true** | **false** | false |
| bite | 15 dmg, 2.2 m, 1.6 s | - | - |

Three of those are decisions rather than feel, and are not Marcel's to
re-tune casually:

- **`huntable: false` on the marmot IS the cozy-honest rule** (DESIGN.md:
  "they simply cannot be targeted"). It is a column, not a rule somebody has
  to remember, and the selftest asserts it in both directions.
- **The wolf's run (7.5 m/s) sits above the player's 4.4 m/s walk and below
  their sprint.** You cannot stroll away from a wolf and you can outrun one
  if you commit - and committing is how you end up somewhere worse, which is
  pillar 3 doing its job.
- **The marmot hears further (45 m) than it sees (30 m), and sees very wide
  (240 deg).** That is what makes the whistle arrive before you have seen the
  marmot, i.e. what makes it an information layer rather than scenery.
- **The eagle's hearing is 0 m on purpose.** An eagle at 80 m does not react
  to a footstep; a hearing radius would have it notice things it has no
  business noticing.

**`dims` is critter-DIMS-shaped per species, and the wolf's is the critter's
exactly** - written out rather than referenced, so night 2's wolf model
changes these numbers and nothing else. The marmot's and eagle's already
differ; neither is spawned tonight, so neither can disagree with the critter
geometry that would be on screen.

**Shared numbers that are not per-species** live here too, because a second
numbers file is how two numbers files start disagreeing: `NOISE`
(sprint 1.5 / move 1.0 / **still 0.3 - not zero**, so stealth is a skill and
not a switch), `BRAIN_HZ 10`, `MAX_LIVE 16`, `SYNC_HZ 20`,
`REPLICATE_RANGE_M 128`, `ROWS_PER_PACKET 16`.

**The event schema (decision 8) is a block comment in the same file, and it
is THE schema** - the probe's evidence, Stage 6's gates and the director's
future stream are the same rows. Every creature event carries
`{species, id, pos}` on top of `Journal`'s own `kind` and `t`. Night 1's
eight kinds: `den_placed`, `spotted`, `lost`, `howl`, `converge`, `engage`,
`bite`, `leash_turn`. Reserved for night 2 and named now so the schema is one
document: `whistle`, `dive`, `emerge`, `cry`, `perch`.

**Gates:** all three green. `heightmap# 76cccdb6`, spawn `(-44, -124)` -
baseline held. New selftest `species table` (registered under the banner):
every row carries every required key including the nested `slope_cost` and
`bite` keys, `dims.gait` is a gait `Animator.RIG_SHAPES` actually knows,
names round-trip through `from_name`, the marmot is not huntable and the wolf
is, the bite proposes real damage (it ships disarmed, not unbuilt), an
unknown species warns once and falls back to the wolf through every accessor,
and loudness is ordered still < moving < sprinting with a stationary
sprinter reading as still.

One thing worth knowing for the other lanes: **a GDScript parse error in
`selftest.tscn`'s script does not fail the run, it HANGS it** - the scene
never loads, nothing calls `quit()`, and the process sits there until the
timeout. `var row := Species.TABLE[species]` on an untyped `const` Array did
exactly that here. If a gate ever appears to run forever, read the first ten
lines of its output, not the last.

---

## Stage 2 - the scenario harness

`scripts/tools/creature_probe.gd`, `class_name CreatureProbe extends Node`.
Built second and before any creature exists, per the plan, because every
later stage's evidence comes out of it.

```
godot --headless --path . -- --host --seed 42 --creature-probe \
    --scenario walk --runs 5 --view low
```

**A scenario is a Callable that returns a Dictionary.** Two keys are the
harness's - `ok` and `why` - and **every other numeric key it returns is
medianed across runs automatically** and printed in the summary table. So a
scenario adds a measurement by returning it and nothing else has to be told;
Stage 6's three scenarios cost no reporting code at all.

**Multi-run rerolls through the game's own F5 path.** `--runs 5` repeats with
`seed + i`, and the world rebuild between runs is `DebugHUD.reroll_requested`
**emitted, not reimplemented** - `game.gd` already connects that signal to a
host-only handler that resets the world, sets it up on the new seed and
respawns the player. Emitting it is a read-side use of a file this lane may
not write, and it means the between-run rebuild is the same rebuild a human
gets by pressing a key.

**The journal is marked at the start of every run.** The host's `Journal` is
never reset - a reroll rebuilds the world, not the record of the session - so
without a mark run 5 would be judged on the events of runs 1 through 5 and
every count in the table would climb for a reason that has nothing to do with
the seed. Every count this branch ever quotes is a per-run slice.

**Decision 10, in numbers.** `walk` runs at `Engine.time_scale 4.0` with
`physics_ticks_per_second` scaled to match at **240 Hz**, and both are
recorded per run in the summary table. Scaling the tick rate with the scale
is the load-bearing half: `time_scale` alone stretches the delta each tick
reports without changing how many ticks happen, so a character integrating
gravity at 4x delta jumps differently and the sim stops being the sim.
`--time-scale N` overrides it, so a scenario that misbehaves at 4x can be
re-run honestly at 1x without an edit.

### `walk`, the null scenario - 5/5 (probe, 5 runs, seeds 42-46)

| | median | runs |
| --- | --- | --- |
| walked | **197.02 m** of 200 | 197.01, 197.02, 197.02, 197.02, 197.06 |
| sim time | 10.20 s | 10.11 - 10.35 |
| wall time | 29.63 s | 22.75 - 32.38 |
| waited for chunks | 18.49 s | 12.63 - 20.37 |
| rescues from inside terrain | 0 | all runs |
| creature events | 0 | (correct - nothing is spawned yet) |
| schema violations | 0 | all runs |

**It walks an open heading, not due east, and the first version's failure is
worth keeping.** A fixed `+X` heading passed on seeds 42 and 43 and then
stopped dead at 45 m, 78 m and 106 m on seeds 44, 45 and 46 - against a
mountainside. That is a true fact about those worlds and says nothing about
the harness this scenario exists to test. So the walk now scores sixteen
compass headings by the **worst** slope along a 200 m corridor, disqualifies
any corridor that crosses a lake, and takes the best - deterministically,
reading the heightmap and the lakes and rolling nothing. Worst rather than
mean: a corridor that is flat for 190 m and vertical for 10 is not a walk,
and a mean hides exactly that.

**Evidence lands on disk.** `build/creatures/<scenario>/events-run<i>.json`
per run, and `events.json` = run 0, the seed the caller actually asked for.
`build/` is gitignored, so this is output and not a commit. Every dumped
event is validated against the schema first: `{species, id, pos}` present and
correctly typed, and **`applied == 0.0` on every bite** - hard rule 6 asserted
on the evidence rather than on the code, however it got there.

### `game.gd`: the whole diff, landed complete, never grown again

**22 lines, two banner regions, nothing else changed** (hard rule 3):

1. **The block**, immediately after the BodyField block - `CreatureServer`
   built, named `Creatures`, `setup(...)`, then `CreatureDebug`. After
   BodyField for BodyField's own stated reason: the server decides
   host-or-client exactly once, there, from `Net.is_host()`.
2. **The elif**, at the end of the cmdline chain, calling
   `creatures.start_probe`.

**Two things the plan asked for turned out to be unnecessary, and this is the
recorded deviation.** The plan's block was to contain four things, two of
them new functions on `game.gd` - a public `sim_centres_m()` and a
`_start_creature_probe()`. Neither was added:

- **The centres go over as a bound `Callable`** (`_sim_centres_m`) handed to
  `setup()` in the block itself. That achieves what the public accessor was
  for - this lane never naming a private member of a file another lane owns
  tonight - and does it better: `game.gd` chooses what it exposes, in the one
  block it already gave us, and gains a block rather than an API.
- **The probe launch lives in `creature_server.gd`**, so the elif calls into
  this lane's own territory. The HUD-hiding that every other probe does from
  `game.gd` is done by the probe itself for the same reason.

The plan also describes the block as "one contiguous appended block", which
cannot be literally true of a thing containing both statements inside `_ready`
and function definitions at file scope. Two regions is the smallest honest
reading of "the one elif and the one banner block", and it is what landed.

**Gates:** all three green, `heightmap# 76cccdb6`, spawn `(-44, -124)`.

---

## Stage 3 - senses and signals

Two files, and between them the entire perceptual and communicative surface of
every animal in the game.

### `senses.gd` - `class_name SensesBus`, host only

**The interface is honest and the implementation is not**, which is design
decision 3 and is the whole reason this exists before any creature does. What
ships is a flat sight cone and a hearing radius; what does NOT ship is any
tree that knows that, because hard rule 4 forbids a raw distance check inside
one. "Make it honest later" therefore means replacing the inside of two
functions.

**Named deferrals, so nobody has to guess what "simplified" meant:**

- **Occlusion.** A wolf currently sees you through a ridge. The fix is a
  heightmap ray-march between two points - the heightmap is already the right
  structure and it is cheap, so this is a stage, not a project. Deferred
  because it moves the very numbers Stage 6 is tuning against, and doing both
  at once leaves neither measurable.
- **Scent, carried downhill on the wind** - DESIGN.md rule 1's "a wolf that
  only notices you upwind is a wolf players learn".
- **Darkness.** Sight range by time of day belongs with DESIGN.md § Night's
  mild v1 boldness dial.

**Loudness and hearing are calibrated against each other, and that took a
constant.** A noise states its carry in metres (`emit_noise(pos, loudness_m,
kind, source)`); a listener states its `hear_m`. Reconciling the two needs a
reference, so `Species.NOISE["reference_m"] = 30.0` is defined as *the carry
of a walking player*, and audibility is
`distance <= hear_m * (loudness_m / reference_m)`.

The alternative, `min(loudness_m, hear_m)`, was rejected: it makes a sprint
and a walk **identical** to any listener whose hearing is the shorter of the
two, which is every listener that matters. With the reference:

| | wolf, `hear_m` 30 | marmot, `hear_m` 45 |
| --- | --- | --- |
| still player (0.3x, carries 9 m) | 9 m | 13.5 m |
| walking (1.0x, 30 m) | 30 m | 45 m |
| sprinting (1.5x, 45 m) | 45 m | 67.5 m |

**A player is one standing noise, not an event stream.** Emitting a fresh
transient twenty times a second would make the bus a landfill; standing noises
are keyed by source and rewritten each server tick, so re-emitting replaces.
A peer who disconnects has their entry dropped - otherwise a departed player
is an eternal sound at the place they vanished and the pack investigates it
forever. Transients (a howl) expire after `TRANSIENT_MS = 250`, two brain
ticks: long enough that a creature whose turn comes just after the sound still
hears it, short enough that nothing chases an echo.

`hear_events_for` returns rows **loudest first**, each carrying `range_m` and
`margin` - so an investigate can be about the sound rather than about a second
distance check, which would be hard rule 4 in through the window.

**Player state is read through `game.peer_row()`, which is public.** The
host's authoritative table already carries position, velocity and the state
byte; `CreatureServer.players()` reads it there rather than inventing a second,
worse description of what a player is doing. The bound `centres` Callable is
the fallback for the moment before the first sync tick, and it reports a still
player - the quietest honest guess.

### `pack_board.gd` - `class_name PackBoard`, host only

Rule 2 (communication) and rule 3 (memory) in one object. **The whistle and
the howl are the same mechanism** - design decision 2 - so this is a board,
not a wolf thing, and night 2's marmot gets it for free.

`broadcast(kind, data)` **writes the board and then journals**, in that order,
because a reader woken by the journal must not be able to see an event about a
board that has not been updated yet. `data` must carry `id` and `pos` -
required, not defaulted: an event with no position is one a director cannot
place, and silently writing a zero makes that failure invisible. Such a
broadcast is dropped with a warning.

**`lost` and `leash_turn` are journal-only on purpose.** They are things that
happened and they deliberately do not erase `target_pos` / `last_seen_ms` -
DESIGN.md rule 3, a pack keeps going to where you were. Only `forget_target()`,
called when a pack leashes home, clears it.

It is called `PackBoard` and not `Blackboard` because the vendored Beehave
already declares a global class by that name.

**Gates:** all three green, `heightmap# 76cccdb6`, spawn `(-44, -124)`,
`walk` still passes. Two new selftests:

- **`senses bus`** - nine cone cases including the off-by-two pair (50 degrees
  off the nose is inside a 110-degree cone and outside a 90-degree one, which
  is the test a half-angle bug passes then fails), a creature with no facing
  seeing nothing, the walking-player audibility boundary at 29 m / 31 m
  against 30 m of hearing, the pair the whole `senses-honest` scenario rests
  on (at 40 m against 30 m hearing: walking heard 0, sprinting heard 1), a
  still player at 8 m still audible, the marmot's better ears, the eagle
  hearing nothing at 1 m, a departed peer going silent, and a transient
  expiring.
- **`pack board`** - a broadcast reaching a second reader, the howl's bearing
  arriving, memory surviving `lost`, `forget_target` clearing it, and a
  broadcast with no `id`/`pos` being dropped rather than written as the origin.

---

## Stage 4 - paths over the land the animals already know

`creature_nav.gd` (`class_name CreatureNav`) and `creature.gd`
(`class_name Creature extends Node3D`).

**One `AStarGrid2D` per pack territory, not per world.** A 3 km world is 1500
cells a side and 2.25 million points; a wolf territory is **151 x 151 = 22,801
points and builds in 153 ms** (ganymede, single run), and is thrown away with
the pack. Cell size and offset are set in METRES so `get_point_path` hands back
world XZ directly and no coordinate system is converted twice. Diagonals are
`ONLY_IF_NO_OBSTACLES` - the strict policy - so an animal cannot cut the corner
between two solid cells, which is the move that sends a wolf clipping through
the nose of a ridge. Y on a waypoint comes from `surface_height_m`, not the
coarse cell: the difference is the detail layer, and a creature walking the
coarse height floats and sinks by a metre at a time.

### The one place this file argues with its plan

**A per-point weight cannot express a per-edge asymmetry.** `AStarGrid2D`
weights a POINT, not the move into it, so "uphill dearer than downhill" - a
fact about a *direction of travel* - has no direct expression. Getting it would
mean a directed graph, which means giving up the grid, which is the thing that
makes this cheap enough to have one per pack. So the table's two numbers are
spent on two things a point *can* know:

- **Steepness, direction-free** - `1 + uphill * (slope_deg / cliff_deg)`. This
  is what makes a wolf take the contour rather than the crest.
- **Rise above the den** - a direction, just a fixed one. A territory is a
  thing centred on a home, so above-home costs `uphill` and below-home costs
  `downhill` (2.6 against 0.8 for a wolf), saturating at
  `RISE_REFERENCE_M = 40`. An ibex's row inverts it and its territory tilts
  uphill instead, which is the design intent in the only place a grid can
  hold it.

### Two real findings, both changing numbers Stage 1 proposed

**1. The wolf's `cliff_deg` moved from 42 to 55, and it is now a decision
rather than a feel.** `Locomotion.FLOOR_MAX_ANGLE_DEG` is **55** - the player
walks up to 55 degrees. A wolf that gave up at 42 was **less mobile than the
thing it is chasing**, which quietly deletes the encounter: you escape by
walking up a hill you can walk up and it cannot. It mattered more than it
looked, because this world is steep - **mean slope 30.7 degrees, a third of it
over 45** (worldgen probe, seed 42) - so 42 marked **67% of a real territory
solid** and the pack had nowhere to go. At 55 the same territory is **5.4%
solid**. The marmot moved 38 -> 45 for a stated reason (a small animal on a
bench gives up sooner than a person); the eagle stays at 90 and does not walk.

**2. Partial paths are allowed, and that is a behaviour decision.** A real
territory can be cut in two by a cliff band or a lake: on seed 42, one
in-territory pair in twenty is **genuinely unreachable** from the other, and
the first run of the gate found it as 19/20. The choice is between a creature
that stands still because the answer came back empty and one that goes as far
towards you as the land allows and then gives up. The second is the better
animal and the one Stage 6's leash already knows how to end.

### `creature.gd` - what a creature's body is

Height-snapped kinematics per decision 1: a `Node3D` on `surface_height_m`,
walked by the server, **no `CharacterBody3D`, no collision shape, no Jolt
cost**, so the cap of 16 is a policy and not a budget. Slope drag is measured
**along the way it is actually going**, not from the cell's own steepness - an
animal running along a contour on a 30-degree hillside is on steep ground and
is not climbing. It re-snaps to the ground every frame rather than at each
waypoint, or a creature crossing into terrain whose detail layer differs from
the coarse cell walks with its ankles in the rock. The brain is not in this
file: `wolf.gd` decides where, and the marmot's utility scores and the eagle's
boids will drive the same body.

**Deferred and recorded:** a creature does not collide with a `BodyField`
boulder, cannot be pushed by one, and will walk through a pushed body's new
position. Making bodies solid to animals is a Combat-v1-era question.

### The `creature paths` selftest, and the test that wasn't one

Two parts, the `_test_body_promotion` shape. **Part one's first version
measured a wall.** It built a 15 m ridge two cells wide, which `slope_deg_at`
reads as a cliff, so every cell of it was *solid*: the path went round, the
assertion passed, and it had tested the solid mask rather than the weight
table. **A test a broken weight table passes is not a test.**

The version that ships builds a **knoll** - a 20-cell cone at 37 degrees, with
**nothing solid anywhere on it** (asserted) - and puts the endpoints on
opposite sides so the straight line goes over the summit. The only thing that
can push the path off that line is the weight table:

| | value |
| --- | --- |
| closest approach to the summit | **20.8 cells** (knoll radius 20 - it skirted the base entirely) |
| weight on the knoll's flank | **3.91** |
| weight on the flat | **1.00** |
| same cell, flat-costed eagle | **1.86** |

Part two is a real seed-42 territory, centred on **ground a den could actually
be on** - 300 m or more from spawn, in Stage 5's 5-25 degree slope band -
rather than an arbitrary diagonal offset from spawn, which reports a fact about
whatever the seed put there. **20 of 20 in-territory pairs find a path, 1164
waypoints, 0 standing in a cell the grid calls solid**, with a guard that fails
the test if over half the territory is solid so the assertions cannot be
vacuous.

**Gates:** all three green, `heightmap# 76cccdb6`, spawn `(-44, -124)`,
`walk` still passes.

---

## Stage 5 - the den has an address

`scripts/creatures/home_placement.gd`, `class_name HomePlacement`, in the
`TreePlacement` school: a 64-block (32 m) candidate lattice jittered by up to
24 blocks, a product of independent terms, the ceiling-first early-out, and
the hash-the-coordinates contract - **no RNG, no stream, no dependence on
which chunk asked first.** `decide(gen, cell_x, cell_z)` is ONE FUNCTION,
ASKED BY EVERYTHING.

**Salts 400-419 are claimed**, documented in the file beside the registry
pattern: 400 den present, 401 den jitter x, 402 den jitter z, 403 burrow
field, 404 burrow count, 405-419 reserved (night 2's crag takes 405-407).

**Home model numbers are 200 (den), 201 (burrow), 202 (crag, reserved)** -
well clear of `FloraModels`' 0-18, which has room to grow. Ids reuse
`FloraPlacement.identity()`'s packing so **Sites v1 inherits one id scheme
rather than two**, and the model byte is the whole of the separation between a
den and a boulder.

**There is no new noise layer, and that is a decision rather than an
omission.** The trees needed grove and glade noise because a forest's clumping
is not a property of the terrain. Everything a home asks - what zone, how
steep, how flat the bench, how far out - the terrain already answers, so
adding one would have been inventing a structure the world does not have.

### The terms

| | den | burrow field |
| --- | --- | --- |
| base | 0.022 | 0.20 |
| zone | forest, heath, rock | meadow |
| slope | 5-25 deg | <= 10 deg, **and the neighbourhood <= 14 deg** |
| danger | >= 0.25, ramped **x(1 + 1.5t)** to the far corner | any |
| spawn exclusion | 300 m | 60 m |
| count | 1 pack | 3-6 burrows, hashed |

**The danger ramp is pillar 3 in one term.** A den is 2.5x likelier at the far
corner of the world than at the near edge of its own band, so packs thicken as
you range further and nobody had to paint a zone. **Below `danger 0.25` there
are no dens at all** - the near valley is the warm register.

**The bench test is why a burrow field is a shelf and not a ledge.** One cell
can be level on a 40-degree hillside; the field requires every cell within two
coarse cells to be under 14 degrees.

### `homes` (probe, 5 runs, seeds 42-46) - 5/5

| | median | runs |
| --- | --- | --- |
| dens in the region | **38** | 44, 38, 44, 38, 30 |
| burrow fields | **465** | 413, 477, 491, 465, 462 |
| burrows (seed 42) | 1838 over 413 fields | - |
| nearest den to spawn | **582 m** | 556 - 714 |
| enumeration | 124 ms (seed 42, single run) | - |
| **drift between two enumerations** | **0** | all runs |
| dens inside the spawn exclusion | 0 | all runs |
| dens outside the slope band | 0 | all runs |
| dens below the danger floor | 0 | all runs |
| homes sharing an id | 0 | all runs |

Seed 42's nearest den: id `-4035225258590993545` at (444, 224) m, **556 m from
spawn, slope 12.3 deg, danger 0.25, zone heath** - and that is the den Stage 6
anchors its pack to.

**The determinism check compares ids and positions, not counts.** Two
enumerations of the same seed must produce *the same homes in the same order*;
a count-only check would pass a placement that had quietly become
order-dependent, which is the exact failure the hash contract exists to
prevent. The plan's floors (>= 3 dens, >= 10 burrow fields) are met by more
than an order of magnitude; 38 dens across 9 km2 is roughly one every 450 m
against a 300 m territory diameter, so territories occasionally touch and
never routinely overlap. Density is an F10 dial.

**`home identity` selftest**: 75 ids over three models at coordinates
including -2900 and 2900, all distinct and all reversible. The model numbers
set bit 63, so **every home id is a negative integer** - which is the case a
packing bug hides in, and why the test uses negative coordinates deliberately.
It also asserts no home model can collide with a flora model.

**Nothing writes terrain** (hard rule 2) and nothing spawns yet. A den is a
position and an identity; whether it ever gets a visible scree mouth is on
Marcel's list.

**Gates:** all three green, `heightmap# 76cccdb6`, spawn `(-44, -124)`.

---

## Stage 6 - the pack

The heart of the night, and the stage that spent the most of it. `wolf.gd` is
the game's first behaviour tree; `creature_server.gd` spawns, ticks and
retires the pack.

### The tree

A **reactive** priority selector on Beehave, re-checked every brain tick:

```
leash       : beyond the border, or a packmate turned  -> go home, ignore everything
engage      : at bite range AND on my own side         -> circle, lunge on cooldown
converge    : the pack has howled and I am not the howler -> come in on a flanking bearing
stalk       : I can see them                           -> howl if nobody has, then close
investigate : I heard something                        -> go and look
patrol      : otherwise                                -> the hashed beat around the den
```

Reactive rather than plain: a wolf that hears a howl halfway through a patrol
leg must abandon it on the NEXT tick, not when the leg finishes. Every leaf is
three lines and calls one method on the wolf, so what a wolf DOES is readable
in one place and what the TREE does is priority and re-checking.

**Perception happens once per brain tick, in `pre_tick()`, and nowhere else** -
which is what makes hard rule 4 checkable by reading one function instead of
auditing eleven. The only distances this file computes are against the den
(not perception) and against the board's remembered `target_pos` (perception
the board already did).

**The tree is built DETACHED from the scene tree.** `BeehaveTree._ready()`
registers itself with two autoloads - `BeehaveGlobalDebugger` and
`BeehaveGlobalMetrics` - that only Beehave's editor plugin installs, and
installing it means editing `project.godot`, which this lane may not touch.
Attached without them, every wolf's first frame is *"Attempt to call function
'register_tree' in base 'null instance'"*. Detached, `_ready` never runs and
`tick()` needs none of it. What is lost is the visual tree inspector, which
needs the editor plugin anyway; the wolf frees its own brain in
`NOTIFICATION_PREDELETE`.

### Seven bugs the probe found

Each is commented where it was fixed, because each is a trap the next creature
would have fallen into:

1. **The nav grid was a SQUARE and the territory a CIRCLE.** A patrol pathing
   round a cliff left the circle the leash is measured against while still
   inside the square it was pathing in - so it journalled a `leash_turn` it
   had no reason to and went home. Observed as a wolf drifting from 47 m to
   151 m out. `CreatureNav` now masks the disc; **no path a creature can
   follow leaves its territory**, and the leash means one thing.
2. **...and then the leash measured 3D distance against a 2D mask.** Same
   class of bug, same fix: `Creature.flat_distance`, one definition. A
   territory is a disc, not a sphere, and in this terrain the difference is
   tens of metres.
3. **Repathing every brain tick.** `set_path` resets the waypoint index, and
   waypoint 0 is the centre of the cell the creature is already in - at most
   1.4 m away, against 0.75 m of travel between ticks. Two full A* solves a
   second, over 23,000 cells, to stay exactly where it was. A path is now kept
   until spent or until its target has really moved.
4. **A circling wolf turned its own eyes away.** Creatures yawed toward travel;
   circling is tangential; the target then sits ~90 degrees off a 110-degree
   cone. The journal shows it as `engage`, `bite`, then `lost` **0.4 s later
   at a range of 2.6 m**. Creatures now face what they are attacking.
5. **Peer ids and creature ids are separate counters that both start at 1.**
   On an offline host `Net.local_peer_id()` is 1, so the pack's own member #1
   made the player's footsteps invisible to every wolf: **no creature could
   hear a player at all.** It surfaced as "a sprinting player at 88 m was never
   investigated in 120 s" - a sentence about hearing that was really about a
   namespace.
6. **An engaged wolf moved at 4.5 m/s against a 4.4 m/s walk** and drew away
   from its own target at ten centimetres a second until it lost it.
7. **`STATE_LUNGE` was never cleared**, so the first bite of an encounter stuck
   the state int for the creature's life - a wrong pose on every client and a
   wrong reading on every report.

### Two table numbers a scenario proved wrong

- **Wolf hearing 30 m -> 60 m.** With ears shorter than its 40 m eyes there is
  **no position in the world** where a sprinting player is heard but a still
  one is not seen: a wolf's eye reaches `patrol + sight` from home while its
  ear reaches `1.5 x hear_m` from itself. The noise channel was vestigial and
  what the player DOES never decided anything. At 60 m the ear is the wide net
  and the eye confirms.
- **Patrol beat 0.55 -> 0.30 of the territory.** 82 m at 2 m/s is most of a
  minute in one direction and put the pack's eyes most of the way to its
  border, which is the other half of why no band existed.

### `investigate` is a ninth journal kind

Added against Decision 8's list of eight, and argued in `species.gd` rather
than slipped in. The plan's own `senses-honest` gate is written as *"the same
position sprinting IS INVESTIGATED within 20 s"*, and a journal with no word
for an investigation cannot be asked. The alternative - gating on `spotted` -
waits for the wolf to hear the noise, walk 50 m to it and lay eyes on the
player, which measures the ear, the legs and the terrain between them.

### The scenarios (probe, 5 runs, seeds 42-46)

**`pack-flank` - 4/5, and the gate is the median:**

| | median | runs |
| --- | --- | --- |
| **angular separation at first simultaneous engage** | **91.99 deg** | 91.99, 65.07, 89.93, 107.56, 103.63 |
| commanded flank offset | 101.63 deg | 97.92 - 118.21 |
| howl delay after first sighting | **0.00 s** | 0.00 on every run |
| wolves reaching engage | **2** | 2 on every run |
| disarmed bites | 18 | 17 - 22 |
| time to both engaged | 6.04 s sim | 4.28 - 13.82 |

The plan's gate is **median >= 90 deg over five runs**, and it is met at
**91.99**. The plan also sets a 75-degree floor on any single run, and
**seed 43 came in at 65.07** - one run in five where the flanker was still
swinging round its arc when its packmate arrived. Recorded rather than tuned
away.

`events.json` from this run validates: **0 schema violations** across 114
events, and **all 19 bites carry `applied: 0.0`** (hard rule 6, asserted on
the evidence rather than on the code).

**`leash` - 3/5, median exactly the two turns the plan asks for:**

| | median | runs |
| --- | --- | --- |
| `leash_turn` events | **2** | 2, 2, 2, 0, 0 |
| engagements after the turn | **0** | 0 on every run |
| furthest wolf from the den after 60 s | 74.91 m | 52.69 - 74.99, all inside `0.5 x territory` = 75 m |

The two failures are **0 turns, not wrong turns**: on those seeds the probe's
player could not physically walk out of the territory, so nothing crossed a
border and the pack correctly did nothing. Every run in which a crossing
happened produced exactly two turns, zero post-turn engagements, and a pack
back inside half its territory.

**`senses-honest` - 5/5, and what it took to find a band:**

| | median | runs |
| --- | --- | --- |
| standing distance | **87.5 m**, the middle of the band | same every run |
| band | 85.0 m (`patrol + sight`) to 90.0 m (`1.5 x hear_m`) | same every run |
| **still player noticed in 90 s** | **0** | 0, 0, 0, 0, 0 |
| **sprinting player investigated** | **yes, every run** | 1, 1, 1, 1, 1 |
| time to be investigated | **0.04 s** | 0.04, 4.44, 0.03, 8.68, 0.04 |

Both halves, on all five seeds: a motionless player at 87.5 m is not found in
ninety seconds, and the same player at the same spot, moving, is investigated
in **well under a second on three runs of five and under nine on the other
two** - against the plan's twenty. Rule 1's honesty, as a number.

**Two departures from the plan's wording, both recorded:**

- The plan puts the player at `0.4 x hear_m` (12 m) *"behind the sight cone"*.
  At 12 m the answer depends entirely on which way a **patrolling** wolf
  happens to be facing from one second to the next, which makes the gate a
  measurement of luck. The first version of this scenario found a motionless
  player **24 times in 90 seconds** at 42 m. The distance is now DERIVED from
  the table - past `patrol + sight`, inside `1.5 x hear_m` - and the scenario
  fails loudly if that band is empty rather than quietly measuring nothing.
- The band only exists because of the hearing change above. **That the band
  did not exist at the plan's numbers is the most useful thing this scenario
  produced.**

### The pack itself

Two wolves at the nearest den (seed 42: id `-4035225258590993545`, 556 m from
spawn, heath, slope 12.3 deg, danger 0.25), spawned on world ready, brains at
10 Hz **staggered one creature per sub-tick**, movement every frame, cap 16.
A reroll changes the world's seed, which is what makes the pack rebuild -
no file has to know what a reroll is.

---

## Stage 7 - the wire and the view

**The server publishes its own rows on its own accumulator and its own rpc**
(decisions 2-3), so `game.gd`'s sync path, rates and packet shape are
untouched: `@rpc("authority", "call_remote", "unreliable_ordered")` at 20 Hz,
filtered to 128 m and 16 rows, nearest first, on `body_field.gd`'s model.
Unreliable because a dropped creature row is corrected 50 ms later by the next
one, and a resend would arrive after the correction.

**The HOST builds views from the same rows it would send.** That is the point
of the class rather than an efficiency: one code path for what a creature
looks like means a wolf cannot look different to the player hosting than to
the player who joined - the class of bug that only ever appears in somebody
else's living room. A creature that stops being sent has its view freed,
because a wolf standing forever where one used to be is worse than one that
vanishes.

**The view infers speed from row deltas rather than carrying a field.** The
animator wants a speed to pick a stride, and the difference between two
positions twenty times a second is exactly that - one fewer field on the wire
for a number the receiver can work out.

Night 1's wolf wears the critter's body per decision 4: `PartsCritter`'s bone
table, `PartsData.module("critter")`, its palette, gait `trot`. **No new art.**

**Two-engine sync (the `pair_probe.gd` school) is night 2's**, recorded and
not smuggled in.

**`creature wire` selftest:** four-field rows with the right types, the cap
keeping the nearest 16, the 128 m filter excluding, three rows making three
views and a dropped row leaving two - and a client having no senses bus and
producing no rows at all (hard rule 7).

---

## Stage 8 - the tuner, the shots

### F10, and why the table stayed `const`

`scripts/ui/creature_debug.gd`, layer 13, the `character_debug.gd` row pattern
with `_spin_row` **copied rather than imported** (the distance lane is
appending to `debug_hud.gd` tonight). Top right, because F4 and F8 are both
top left and a tuner you have to close another tuner to read is a tuner nobody
uses.

**The panel does not write to `Species.TABLE`.** The authored numbers stay
`const` and the panel writes to `Species._tuned`, a layer every accessor
consults. So a slider cannot corrupt the table, "reset" is one call, and the
numbers Marcel settles on get copied back into `species.gd` **by hand, as a
decision**, rather than leaking in as a side effect. It is deliberately not
saved to disk: these are proposals, and a proposal that silently persists is
one nobody re-examines.

**23 rows, every number Stage 6 chose by feel**, with their starting values:

| row | start | row | start |
| --- | --- | --- | --- |
| brain ticks | 10 Hz | wolf flank offset min | 90 deg |
| wolf walk | 2.0 m/s | wolf flank offset max | 140 deg |
| wolf run | 7.5 m/s | wolf bite damage (disarmed) | 15 |
| wolf sight | 40 m | wolf bite range | 2.2 m |
| wolf sight cone | 110 deg | wolf bite cooldown | 1.6 s |
| **wolf hearing** | **60 m** | **wolf patrol beat** | **0.30** |
| wolf territory | 150 m | wolf memory of a target | 20 s |
| wolf engage range / bite range | 2.0 | engaged within of bearing | 15 deg |
| marmot sight / hearing / territory | 30 m / 45 m / 40 m | eagle sight / orbit / territory | 120 m / 18 m/s / 400 m |

Territory has a **"rebuild the pack"** button beside it, because territory is
baked into the A* grid when it is built - a slider that only changed a number
would appear to do nothing.

### The shots (`xvfb-run -a`, 1280x720, `--view medium`)

`build/creatures/shots/den-noon.png`, `den-dusk.png`, `flank.png`.
`flank.png` was taken at the first frame both wolves were engaged, at a
**138 deg** separation on that run.

**The first pass framed them at 22 m and produced two very good photographs of
scree** with an animal somewhere in them. A critter is 0.69 m tall; these are
portraits of a pack, not vantages, so they are now shot from 8-9 m.

**For Marcel, and this answers one of his own open questions:** the critter
stand-in is a **brown animal on red rock**, and at this den it is nearly
camouflaged. It reads as a low four-legged shape in `den-noon.png` once you
know where to look, and it does not carry the frame. Whether that is
acceptable until night 2's authored wolf is exactly the question the plan
parked, and the honest answer from the evidence is *"only just, and only in
the noon shot"*. Hard rule "no new art tonight" was kept; this is a report,
not a change.

---

## For Marcel to rule on

Shipped at starting values, all on F10, all listed with what the night learned
about them:

1. **A sprinting player cannot be caught, ever.** The player sprints at 13 m/s;
   the wolf runs at 7.5. A player who commits to running is not chased out of a
   territory, they are simply gone - the pack loses them well inside its own
   ground and there is no crossing for anybody to turn at. This is why the
   `leash` scenario walks the player out rather than sprinting them. It makes
   "you cannot stroll away from a wolf" true and "you cannot outrun one" false,
   and whether that is the intended shape of the encounter is a design call,
   not a tuning one. The lever is `wolf.run_mps`.
2. **The flank band, 90-140 deg.** Achieved separation runs a little under the
   commanded offset (median 92 achieved against 102 commanded) because a wolf
   engages when it is within 15 degrees of its bearing rather than exactly on
   it. Tightening `engaged within (deg of bearing)` raises the achieved angle
   and slows the pack down getting there.
3. **Pack size 2 and territory 150 m.** Untouched from the plan. 38 dens across
   a 3 km region is roughly one every 450 m against a 300 m territory diameter,
   so territories occasionally touch and never routinely overlap.
4. **Wolf hearing is now 60 m against 40 m of sight**, changed by evidence
   rather than by taste - see Stage 6. If the ear should not out-range the eye,
   the thing that has to give is the patrol beat or the sight cone, because at
   the old numbers hearing did nothing at all.
5. **Bite damage 15, disarmed.** No stat is written, no player node is touched,
   no knockback. Arming it is one line in night 2, after `feat/ui-v1`'s
   `StatsTable` lands.
6. **The critter stand-in is brown on red rock.** See Stage 8: it reads as a
   low four-legged shape once you know where to look and it does not carry the
   frame. Night 2's authored wolf is the answer; the question is whether it can
   wait.
7. **The den is an address and nothing is placed visually.** No scree mouth, no
   marker. A player walks into a valley and is met; they never see a "den".

## Deferred, night 1

- **LimboAI**, per Stage 0 - not closed, deferred, with a repro.
- **Senses honesty**: occlusion, scent + wind, darkness. Stage 3, named there.
- **Creatures do not collide with boulders** (`BodyField`). Stage 4, decision 1.
- **Uphill/downhill as a true per-edge cost.** Stage 4 spends the two numbers
  on steepness and rise-above-the-den instead; a directed graph is the only way
  to have the real thing, and it costs the per-pack grid.
- **Two-engine sync** (the `pair_probe.gd` school) - Stage 7, night 2's.
- **A lunge pose.** `STATE_LUNGE` reads as a hard run; the pose arrives with
  the wolf's own parts.
- **Far-from-players ticking.** Packs currently tick whenever they exist. The
  design doc leaves "frozen or coarse" to the tech plan and night 1 did
  neither; with one pack and a 16-creature cap it costs nothing yet, and it is
  the first thing a second pack will need.
- **`Wolf`'s own feel constants** are on F10 through the tuning layer, but the
  smaller ones - `TURN_RATE`, `SLOPE_DRAG`, `WAYPOINT_M`, `LEASH_COOLOFF_MS`,
  `BORDER_MARGIN_M`, `SPOT_REPEAT_MS` - are not. They were chosen from probe
  evidence rather than by eye, and each is commented where it lives.

## What night 2 inherits

**Opening move, before any new work** (Decision 9): `git merge origin/main` -
`feat/ui-v1` and `feat/distance-v3` will have landed - resolve the banner
appends in `game.gd` and `selftest.gd`, get all three gates green, and **re-run
all three Stage 6 scenarios** before touching anything.

Then, in the plan's order: the marmot (utility scores, the whistle through the
same `PackBoard.broadcast`, dive/emerge at the burrow fields Stage 5 already
places, the untargetable flag honoured end to end); the eagle (crag placement
on salts 405-407, orbit steering, the cry, perch); the wolf's authored model
and its howl/lunge poses; **arming the bite** through `StatsTable.apply_delta`,
after which `pack-flank` should assert hp actually fell; the two-engine sync
check; the mild night-boldness dial; acceptance.

Three things night 1 leaves in better shape than it found them: the event
schema is real and validated on every probe run, the tuning layer means a
number can be moved without touching a `const`, and every scenario in
`creature_probe.gd` is a Callable that returns a dictionary the harness
medians for free - so the marmot's and the eagle's gates cost no reporting
code at all.

## Acceptance, night 1 - against the plan's own list

| the plan's criterion | result |
| --- | --- |
| three gates green on the final commit | **yes** |
| probe hash and spawn = Stage 0's baseline | **yes** - `76cccdb6`, `(-44, -124)`, at every stage |
| `homes` twice-identical, dens in their bands | **yes** - 0 drift, 0 out of band, 5/5 |
| `pack-flank` median >= 90 deg over 5 runs | **yes - 91.99 deg**; one run of five under the 75 deg single-run floor, at 65.07 |
| howl precedes every converge in the log | **yes** - and at a 0.00 s median delay |
| `senses-honest` passes both halves | **yes - 5/5**; still noticed 0 times on every seed, sprinting investigated on every seed, median 0.04 s |
| `leash`: exactly two turns, zero post-turn engages | **median 2 turns, 0 post-turn engages**; 3/5 runs, the other two produced 0 turns because the probe's player could not leave the territory on that terrain |
| `events.json` validates against the schema | **yes** - 0 violations, every bite `applied: 0.0` |
| the three shots exist | **yes**; `flank.png` at 138 deg separation, but see Stage 8 on how well a brown animal reads on red rock |
| `game.gd` diff is the elif plus one banner block | **yes - 22 insertions, 0 deletions**, nothing else |
| no write under `scripts/world/` | **yes** - not one |

**Two criteria are met at the median and not on every run** (`pack-flank`'s
75-degree floor, `leash`'s two turns). Both are recorded above with what
failed and why, and neither was tuned into passing.

## Time, and what the wrap rule cost

Stages 0-5, 7 and 8 came in around their share. **Stage 6 ran far over its two
hours** - most of it spent on the seven bugs listed there, each of which was
invisible until a scenario asked for a number. The stage was not wrapped
because `pack-flank`, the decision-1 deliverable, was passing throughout the
overrun and each fix was making a real behaviour correct rather than making a
gate green. What that cost is depth on the two scenarios that pass at the
median rather than on every run.
