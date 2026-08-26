# Status

The latest run is **world feel v1**, 2026-08-26, on `feat/world-feel-v1`:
`docs/status/world-feel-v1.md`. Night 1 (streaming and the forest) and night 2
stages 9-10 (Jolt, and the carried ticket) are done; stages 11-13 are not.

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

**3. The pair probe's prediction error needs a machine that holds 60 fps.**
Stage 10 closed the carried ticket — clients send input, the host simulates —
and `--pair-probe` runs the whole thing end to end: 100 m out and back under
host authority, 66 chunks of collision ring built for the peer, never below the
surface. What it *cannot* decide here is prediction error: median 3.90 m
against a 0.50 m line, which at sprint is exactly 300 ms of lag against a host
whose own frames averaged **595 ms** with two engines on one box. The probe
prints that arithmetic and returns INCONCLUSIVE rather than FAIL. One command
on the Windows box settles it: `godot --path . -- --host --seed 42
--pair-probe`. The limits in the probe are the plan's and are untouched.

**4. This box is about five times slower than it was on 2026-08-26.** The
stream probe reads 123 s of initial load and 103 frames over 33 ms where night
1 recorded 24.8 s and 1. Stage 9's own commit, re-run in a worktree within the
hour, gives 123.4 s and 104 — so nothing regressed, and per-chunk worker cost
is unchanged at 8.3 ms. It is starvation, not work. Worth knowing before
anybody reads a night-2 number against a night-1 one: **a number from a
different day is not a baseline.**

**5. The velocity-biased queue is switched off.** At `STREAM_HEADING_BIAS = 6`
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
