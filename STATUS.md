# Status

The latest run is **world feel v1**, finished 2026-08-27 on
`feat/world-feel-v1`: `docs/status/world-feel-v1.md`. Both nights are done -
streaming and the forest, then Jolt, host-authoritative input, bodies, the push
and the slide.

## Open items for Marcel

**1. The traversal probe cannot cross this world, and it is not the trees —
and since Stage 9 it is not the physics either.** `--traverse` goes STUCK about
a quarter of the way to the far corner, at every stage tested — including a
worktree at the commit *before* any tree changed, with the old 73,675 small
trees, which stalls even earlier (606 m against 1,003). It reports `0 rescues
from inside terrain` and 13-14 detours, so it is not falling through the
ground: it is failing to **route**. Its detour logic walks a straight line and
side-steps obstacles, which a lake, a cliff band or a box canyon defeats
whatever the forest does.

Stage 9 settled the remaining doubt. Under Jolt the character walks **2,833 m**
and detours **58** times, against ~1,000 m and 14 under Godot Physics, and
still converts about 1,000 m of it into progress. It is not wedged — it moves
freely over the same terrain and goes in circles.

Either the world has a place a player genuinely cannot get past, or the probe
needs real pathing. **That has to be answered before "spawn to the four
corners" can gate anything**, and it is outside world feel v1's scope — the
plan named it as Stage 5's walkability gate and the gate turned out to be
measuring the probe rather than the forest.

**2. Canopy closure misses all three targets** — old growth 0.69 against 0.85,
grove 0.52 against 0.60, between groves 0.37 against 0.20. The ordering is
right, so the mechanism works and the magnitudes do not. The third is the one
that matters: the wood between groves no longer opens, because the same 35% of
candidates now grow trees three times the volume. `TODO(marcel)` at
`WorldgenConfig.grove_floor` has the argument and the command to re-measure.

**3. ~~The pair probe's prediction error needs a machine that holds 60 fps.~~
SETTLED on Forward+, PASS.** Stage 10 closed the carried ticket — clients send
input, the host simulates. On Marcel's Windows box (RTX 5080, Forward+), seed
42, commit `322a10d`: **median error 0.217 m against the plan's 0.50 m line,
p95 0.651 m, worst 1.300 m against a 2.00 m limit**, host frames 4 ms, 46
chunks of collision ring, never below the surface. The 3.90 m INCONCLUSIVE on
ganymede was measuring how fast two engines run on one box: at 4 ms frames the
implied lag is 17 ms rather than 300, and the error collapses by a factor of
eighteen. Limits untouched. Nothing outstanding.

`sim_radius_chunks` was measured on the same box at 3 and 4 — both PASS, 38
ring chunks against 46 — and **deliberately left at 4**: the probe turns round
at 100 m, so neither value was under real pressure, and Stages 11-12 put bodies
on exactly this ring. The `TODO(marcel)` carries both numbers and the
experiment that would find the edge.

**4. The two-player push needs two real machines.** Stage 12's co-op rule is
proved as arithmetic (a self-test asserts one player moves a boulder_m, one
does not move a boulder_l, two do) and as a real contact with one player: a
boulder_l took **126 push contacts, rocked on all 126 ticks and moved
0.000 m**, while a boulder_m gave way at 0.469 m. What has *not* been run is
the pair-probe choreography with a second engine, because on this box two
engines manage about one frame a second and it would measure the machine
again. **This is the night-2 acceptance test**: find a big boulder, push it
alone, then push it together.

**5. Hard rule 7 is RED: Stage 11-12 cost 37% of chunk throughput.** Measured
by Marcel on Forward+ (RTX 5080, `--view High --strict`, seed 42), three runs
in one hour:

| commit | | holes | >33 ms | worst | built/s | |
| --- | --- | --- | --- | --- | --- | --- |
| `322a10d` | before shade_ink, before bodies | 0 | 32 | 63.0 ms | 91.5 | FAIL |
| `8500d3e` | + shade_ink cache, no bodies | 0 | **0** | **28.2 ms** | **150.7** | **PASS** |
| `2c04969` | + Stage 11 bodies + Stage 12 push | 0 | 27 | 44.8 ms | 95.2 | FAIL |

**Hard rule 6 is green** — holes 0 on every commit and both legs, so Stage 12
does not reintroduce a hole and ganymede's "holes 3" was the box.

**Hard rule 7 is red against the correct baseline** (`8500d3e`, the commit
right before Stage 11a): 0 long frames to 27, worst 28.2 to 44.8 ms, throughput
down 37%. The signature is throughput, not rendering. By hard rule 12 this
stops the run at Stage 12.

Two per-column costs were found by reading and fixed — bodies were freed and
rebuilt on the flora **cache** boundary, which is the boundary that churns most
during a sprint (the plan says frozen, not freed, and it was implemented as the
opposite); and promotion was a whole extra pass rebuilding the instance array
per column. **Neither is confirmed as the fix**, and a churn counter added
to the probe redirects the search: at **High**, seed 42, the whole crossing
reports `bodies 0 loaded, 0 built and 0 freed`. The probe sprints at spawn,
spawn is a meadow, and boulders grow in rock and above — so no body is created
on that route at all. Marcel's runs are the same seed and spawn, so if his also
built zero bodies then **body churn cannot be the 37%**, and the likeliest
remaining cost is Stage 12's **zone friction**: every chunk's `StaticBody3D`
now takes a `physics_material_override`, an extra physics-server call per chunk
built — invisible at ganymede's 48 chunks/s, squarely on the critical path at
150. **Re-run on the Windows box against `8500d3e`**: check whether it reports
`bodies 0 built`, then A/B that one line in `ChunkNode.setup()`.

**And the finding worth keeping regardless:** the shade_ink cache — one
rendering-server readback taken off the column submit path as a one-line
tidy-up nobody had on a list — moved the gate from FAIL to PASS by itself: 32
long frames to 0, worst 63.0 to 28.2 ms, throughput +65%. Best evidence in the
run for measuring before tuning.

**6. This box is about five times slower than it was on 2026-08-26.** The
stream probe reads 123 s of initial load and 103 frames over 33 ms where night
1 recorded 24.8 s and 1. Stage 9's own commit, re-run in a worktree within the
hour, gives 123.4 s and 104 — so nothing regressed, and per-chunk worker cost
is unchanged at 8.3 ms. It is starvation, not work. Worth knowing before
anybody reads a night-2 number against a night-1 one: **a number from a
different day is not a baseline.**

**7. The velocity-biased queue is switched off.** At `STREAM_HEADING_BIAS = 6`
the ground ahead of a sprinting player is loaded to the full 96 m radius,
against 40 m without it — and it reintroduces holes, which is a hard rule. The
mechanism is in and one constant turns it on; the status doc says what would
have to change first.

Earlier runs, newest first:

- `docs/status/look-v2.md` — look v2, the poster refined, 2026-08-25, merged to
  `main`; its blocking finding was resolved on Forward+ the same evening
- `docs/status/flora-streaming.md` — the grass keeps up, 2026-08-25
- `docs/status/look-v1.md` — look v1, the poster, 2026-08-25, with the
  character half in `docs/status/look-v1-characters.md` and the UI half in
  `docs/status/look-v1-ui.md`
- `docs/status/foliage-v1.md` — foliage v1, 2026-08-24/25
- `docs/status/character-v1.md` — character v1, 2026-08-24/25
- `docs/plans/terrain-v2.md`, `docs/plans/terrain-v1.md` — terrain, whose
  status sections live in the plans
