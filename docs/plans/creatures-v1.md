# Creatures v1 - the trio, and the groundwork under every animal after it

The **design** doc for the first creatures: the wolf pack, the marmot, the
eagle - and the substrate (senses, signals, paths, homes, the species table)
that every later creature and enemy inherits. Decided in conversation,
Marcel and Claude, 2026-08-31; each decision below carries its date and its
reasoning so no later plan reopens a settled question. The build plan is
`docs/plans/creatures-v1-tech.md`, written against this document - where the
two disagree, this one wins.

What is already settled and NOT reopened here: `docs/DESIGN.md` § Creatures
(2026-08-25) - the trio (wolf / marmot / eagle), the tool table (LimboAI /
AStarGrid2D / boids / utility), the five rules that make them look smart,
host-only decisions, the cozy-honest hunting rule, no painted danger zones.
This conversation decides what v1 *builds* of that, and how an autonomous
run can prove it worked.

---

## Left to the tech plan

Settled in direction here, detailed there:

- **The species table's columns** (habit 1, the first director-readable
  table): archetype, senses ranges, slope-cost weights, goals, huntable
  flag, bite damage, home type. Follows the `Races` const-table pattern.
- **Home placement dials**: dens in the steep/dark/far (`danger_at()`),
  burrow fields on sunny benches, crags on ridgelines - deterministic per
  seed, copying the flora placement pattern; density per region; the v1
  night-boldness modifier stays MILD per DESIGN.md § Night.
- **LimboAI Stage 0 details**: wolf-only on the behaviour tree (marmot is
  utility scores, eagle is boids, per the DESIGN.md tool table); vendored
  for linux AND windows against Godot 4.7.2; Beehave, then a minimal
  hand-rolled BT node, as the written bail-outs.
- **Far-from-players ticking** of persistent packs: frozen or coarse.

## Decisions

**1. The pack is the point.** (Marcel, 2026-08-31.) v1 ships at least two
wolves that converge from different directions - pillar 1's flanking,
mirrored back at the players. A lone rusher would not answer Playtest 1's
question ("does fighting it together produce flanking and saves?"), so the
pack is not stretch scope, it IS the scope.

**2. The groundwork is the deliverable.** (Marcel, 2026-08-31: "we must make
sure the pathfinding and behavior of future ones are just as excellent and
modern... lay the groundwork for the best possible AI for them and later
enemies.") The trio is the first cargo, but the thing being built is the
pipeline: the senses/signal bus, the shared blackboard, AStarGrid2D with
per-species weight tables, and the species table - such that a future enemy
is a table row plus a behaviour-tree file, not new systems. Corollary,
Claude's claim, accepted into the record: "best possible" means the
substrate (perception, communication, memory, terrain use - DESIGN.md's
five rules), NOT a fancier decision library - and the marmot's
whistle-and-dive and the wolf pack's converge-on-signal are the SAME
mechanism: one broadcast-signal system, two species listening. Building it
once is what makes the excellence cheap.

**3. Perception ships simplified; the honesty comes later - but the
INTERFACE is honest from day one.** (Marcel, 2026-08-31: "make it honest
later.") v1 creatures perceive only through the senses bus - a sight event,
a noise event with a loudness - never through direct distance checks in
their trees. But v1's implementation of that bus is deliberately simple: a
sight cone and a hearing radius. Scent, wind carry, and darkness modifiers
are named deferred. The point of the split: "honest later" then means
swapping the bus internals, not rewriting every creature's behaviour tree.
The scope cut is real; the groundwork (decision 2) is not compromised.

**4. The stats table is the UI lane's; the bite ships disarmed.** (Marcel,
2026-08-31.) The D1 stats table is ALREADY being pulled forward - ui v1
Stage 3 builds `scripts/game/stats.gd` (`StatsTable`, host-authoritative,
hp/sp/mp riding the existing 20 Hz state row, `apply_delta` /
`peer_stats()`), and that plan's inheritance notes already name Combat v1 as
its heir. So creatures v1 NEVER creates or edits the stats file. The wolf's
bite is built to full shape anyway - a damage proposal through the one
mutation path, its amount a species-table column, plus the stagger/knockdown
that makes a hit READ as a hit - but the damage application is gated to zero
until `feat/ui-v1` has merged. Arming it is then a one-line hook, not a
stage. By Playtest 1 the bite must hurt.

**5. The scenario probe is a stage, and ganymede runs it headless.**
(Marcel, 2026-08-31: "good idea for a test.") A seeded, scripted encounter:
spawn the trio plus a dummy player driven along a path, log every behaviour
beat - howl, converge, engage, whistle, dive, orbit - as a structured event
with tick and position, and gate on numbers read from that log: wolves >= 90
degrees apart at engage, howl-to-converge time, whistle propagation (every
marmot on the bench diving within N seconds), the eagle holding its
ridgeline band. Verified on the box, 2026-08-31:

- Ganymede runs Godot **4.7.2.stable** from `~/bin/godot`; the selftest
  already runs truly headless (`--headless`, no xvfb, `timeout`-wrapped) -
  only rendering tours need `xvfb-run -a`. The scenario probe is
  selftest-shaped, so it needs **no GPU and no display**, and the tour
  harness is precedent for scripting the dummy player's movement.
- **Jolt is the built-in engine** (`3d/physics_engine="Jolt Physics"`, no
  `addons/` dir in the repo or on the box) - confirming LimboAI would be
  the project's FIRST GDExtension. Stage 0 of the tech plan therefore: vendor
  the LimboAI release built against Godot 4.7 (linux .so for ganymede AND
  windows .dll for Marcel's box, same bits in-repo, MIT), prove it loads in
  the headless selftest, and **bail to Beehave (pure GDScript) if no
  4.7-compatible build exists or the load fails**. Nobody has checked the
  version matrix yet; that check is the first ten minutes of the run.
- The GPU does not speed the probe up - it renders pixels, and the probe
  draws none. Headless, the sim can run FASTER than real time (crank
  `Engine.time_scale` / physics ticks; a five-minute encounter in seconds),
  and staying off the GPU means the probe can run beside another lane's
  rendering tours with zero contention. The 3070 Ti's job in this plan is
  the photograph-and-ask-Marcel shots, nothing else.
- Host-side AI is not promised deterministic (DESIGN.md), so probe gates are
  **tolerance bands over repeated seeded runs** - the repo's own measurement
  culture (medians, three-run tables) - never bit-exact asserts.
- The probe's structured events are habit 2, the journal, arriving early:
  the same stream the director reads at v0. The event schema should be
  written as the journal's schema, not as throwaway probe output.

**6. Every creature has an address: the den, not the spawner.** (Marcel,
2026-08-31: "they get a den for sure.") The pack is anchored to a den - a
real, worldgen-placed site - and by the same pattern the marmots get burrow
fields on the benches and the eagle gets crag perches on the ridgelines.
The trio's smart objects (rule 5), placed deterministically by the danger
dials: dens in the steep and the dark and the far (`danger_at()`), burrows
on the sunny benches, crags up high. What this buys:

- **Encounters have geography.** You wandered into THEIR valley; you can
  leave it. The territory edge is the honest leash - a chase ends because
  the pack turns back at its border, not because a timer despawned it.
- **The pack is data, not theatre.** Its existence, members and den survive
  the players leaving; far-from-players ticking is frozen or coarse (tech
  plan's call). No conjuring near players, ever.
- **The world gets its first addresses.** A den is a site before Sites v1
  exists - `site_type` material, a thing the director can `mark_site` at
  v1, a place a name can attach to. Habit 1 again.
- "Spawning" as a question mostly dissolves into home placement (see
  "Left to the tech plan", above).
