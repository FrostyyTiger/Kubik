# Status

The latest run is **distance v1, night 1**, on `feat/distance-v1`:
`docs/status/distance-v1.md`. The far country's geometry and colour - a
filtered heightmap pyramid, a mip level continuous in distance, a peak-gain
dilation, and the end of the far field's zone dither. **Night 2 is not started**
(the impostor material, the ring reaching the fog, the meadow).

It is the first status doc in this project with **no "Tuned blind" section**:
ganymede's GPU works now, so every tone was judged against a picture taken on
the same box. A **provenance column** replaces it - which box each number came
from and whether it is a single run or an interleaved median.

Three things in it are worth reading even if you do not read the rest:

- The far field already lost **60 blocks of summit at 600 m before this epic
  touched it**, so two of the plan's gates were written against a baseline
  nobody had measured. Both are recorded as not met, with what was run instead.
- The new far probe **was aliased against the mesh it measures** on its first
  version, and reported a ring boundary as perfect that is plainly visible in
  play. Caught before any baseline was recorded.
- The plan's "fade the grain with distance" was **already done** in look v2 and
  the plan's premise for it was wrong.

The previous run is **world feel v1**, finished 2026-08-27 on
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

**5. Hard rule 7 is ANSWERABLE and provisionally not met.** Two runs on
ganymede with its GPU finally working (`--view High --strict`, seed 42) give
**holes 0** — hard rule 6 green — and **20 and 24 frames over 33 ms**, worst
frame 35.8–40.4 ms. Both FAIL, with a tight spread. That does not settle it,
but it means the gate has stopped being undecidable: two dedicated-box runs
suggest **the game does not hold 33 ms at High during a sprint on a 3070 Ti**,
and the next step is an interleaved ABAB run against the pre-Stage-11 commit.

**And ganymede is the right box for it, which was the surprise.** Two runs of
identical code there vary ~9% on chunks/s (78.1–85.2); three runs on the RTX
5080 desktop vary ~60% (93.3–150.7), because that machine has a desktop, a
compositor and another game competing for the card. The faster box is the less
trustworthy instrument. The `TODO(marcel)` on `stream_probe.gd` is amended to
say so and to name ganymede as where comparative runs belong.

The rest of this item is the history of why that took so long, and it stands as
a lesson about single runs even though the hardware premise has changed:

On Forward+ (RTX 5080, `--view High --strict`, seed 42) the same commit does
not agree with itself:

| `8500d3e`, identical code, three runs | >33 ms | built/s | |
| --- | --- | --- | --- |
| run 1 | 0 | 150.7 / 143.3 | PASS |
| run 2 | 0 | 122.0 / 144.1 | PASS |
| run 3 | 12 | 93.3 / 108.3 | **FAIL** |

`add4b2e` twice, identical code: 29 long frames, then 14. Across ten runs the
spread is **0-40 long frames and 61-151 chunks/s**, and the commits do not
order monotonically inside it. The confound is run order — the box drifts
downward across a session, and the first run of the day was the fastest thing
measured while the last run of the same commit was among the slowest.

So **"Stage 11-12 regresses hard rule 7" is retracted** — it rested on
comparing single runs taken at different times — and so is any claim that
`8500d3e` passes it. The zone-friction A/B (13 against 10 long frames) is
inside the noise band and decides nothing either way.

This is night 1's *"a number from a different day is not a baseline"* one level
finer: **a number from a different run is not a baseline either.** Every
night-2 performance number in this project so far has been a single-run
comparison.

**To actually answer it** the method has to change — interleave the commits
ABABAB, five runs each, report the median of chunks/s with its spread rather
than a long-frame count (a threshold turns a drifting continuous quantity into
a coin flip), and record run order. There is a `TODO(marcel)` on
`stream_probe.gd` saying plainly that **this probe cannot currently compare two
commits**.

**What is solid:** holes 0 on every commit, every run, both legs — hard rule 6
is green and Stage 12 does not reintroduce a hole. And `bodies 0 built` on this
route, confirmed on both boxes: the probe sprints at spawn, spawn is a meadow,
and boulders grow in rock and above, so whatever stages 11-12 cost here it is
not body churn.

**Two fixes were made and stand on their own evidence, not on the deltas:**
bodies were being freed and rebuilt on the flora *cache* boundary — the
churniest boundary there is, and the plan says frozen, not freed — and
promotion was an extra pass per column, measured on the worker at 8.40 → 7.77
ms per column over 797 columns, which is not subject to this confound.

**6. ~~This box is about five times slower than it was.~~ SOLVED — the GPU was
never being used.** ganymede has an RTX 3070 Ti and shipped with
`nvidia-headless-595-open`, the **compute-only** driver: `nvidia-smi`, CUDA and
the kernel modules all work and look healthy, which is why nobody suspected it,
but it installs no graphics userspace and no
`/usr/share/vulkan/icd.d/nvidia_icd.json`. The Vulkan loader found no ICD and
Mesa fell back to llvmpipe, so **every frame in world feel v1 was drawn on the
CPU** while the GPU sat at 39 °C with 1 MiB used.

Fixed 2026-08-27 with one package against the already-loaded kernel driver, no
reboot: `libnvidia-gl-595` + `vulkan-tools`. Godot now reports `Vulkan 1.4.329
— Forward+ — NVIDIA GeForce RTX 3070 Ti`, through the existing `xvfb-run` line
unchanged — Xvfb satisfies the windowing call and Vulkan renders on the card.

"It is starvation, not work" was **right about the mechanism and wrong about
the cause**: the starver was the software rasteriser competing with the chunk
workers for the same cores. That is why per-chunk cost held at 8.3 ms while
wall-clock load went 24.8 s → 123 s — the work per chunk never changed, the
number of chunks getting worked on did. **The 5x was never a property of the
box**, and it was not thermal drift either.

Same probe, same seed, same machine, now on the GPU: **holes 0, 20–24 frames
over 33 ms, worst frame 35.8–40.4 ms** against 595–709 ms. Roughly 15x on the
worst frame.

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
