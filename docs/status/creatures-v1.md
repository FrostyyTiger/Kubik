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

## Deferred, night 1

- LimboAI, per Stage 0.
- **Senses honesty**: occlusion, scent + wind, darkness. Stage 3, named above.

## What night 2 inherits

- The merge (`git merge origin/main` first, before any new work), and the
  banner blocks in `game.gd` and `selftest.gd` to re-resolve.
