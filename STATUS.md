# Status

The latest run is **world feel v1, night 1 — the ground keeps up, the forest
closes over**, 2026-08-26, on `feat/world-feel-v1`:
`docs/status/world-feel-v1.md`. Night 2 (physics) has not started.

## Open items for Marcel

**1. The traversal probe cannot cross this world, and it is not the trees.**
`--traverse` goes STUCK about a quarter of the way to the far corner, at every
stage tested — including a worktree at the commit *before* any tree changed,
with the old 73,675 small trees, which stalls even earlier (606 m against
1,003). It reports `0 rescues from inside terrain` and 13-14 detours, so it is
not falling through the ground: it is failing to **route**. Its detour logic
walks a straight line and side-steps obstacles, which a lake, a cliff band or a
box canyon defeats whatever the forest does.

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

**3. The velocity-biased queue is switched off.** At `STREAM_HEADING_BIAS = 6`
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
