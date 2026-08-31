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

## Deferred, night 1

- LimboAI, per above.

## What night 2 inherits

- The merge (`git merge origin/main` first, before any new work), and the
  banner blocks in `game.gd` and `selftest.gd` to re-resolve.
