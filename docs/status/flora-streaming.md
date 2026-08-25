# Flora streaming — run status

A one-day pass on 2026-08-25, on `feat/flora-streaming`, from `main` at
`053b904`. Started by a playtest report, not a plan: "the grass disappears
when I walk, takes ages to come back, and only ever loads close to me."

## What was actually wrong

`--flora-probe` (new, `scripts/tools/flora_probe.gd`) jumps the player 48 m
along +X six times, waits for the world to settle after each jump, then jumps
back, and times the terrain and the grass separately. Baseline, seed 42:

| jump | terrain settles | grass, after that | columns rebuilt on return |
| --- | --- | --- | --- |
| out 1-6 | 5.5 - 8.8 s | +152 - 172 ms | — |
| back 1-6 | 4.0 - 6.9 s | +152 - 166 ms | all of them |

Three findings:

1. **The grass was queued behind the terrain.** Flora shared the worker cap
   with chunks and was submitted after them, so a moving player - whose
   terrain queue never empties - saw grass only when they stopped. Plants are
   placed from the heightmap and never needed the chunks at all.
2. **The queue was in scan order, not nearest-first.** The far corners of the
   disc could be built before the grass under the player's feet.
3. **Nothing was kept.** Every column out of range was freed; turning round
   rebuilt the meadow you had just walked through.

And the underlying one, out of this pass's scope: **a 48 m move costs the
terrain 6-9 s** on this machine (4.9 ms per chunk on serialised GDScript
workers, hundreds of chunks per move). The grass was the visible symptom;
that is the disease, and it is chunk streaming's problem.

## What shipped

- **A reserved lane.** One flora job may run over the shared cap when none
  is in flight. Ground still first; grass always.
- **Nearest-first.** The flora queue is sorted like the chunk queue.
- **A cache.** Columns leaving range are hidden and kept, 1024 of them
  (about five 48 m steps), oldest evicted. `FLORA_MARGIN_CHUNKS` of
  hysteresis so a boundary shuffle does not churn.
- **A sparse ring.** Beyond `flora_radius_m` (64 m, full) a ring to
  `flora_far_m` (128 m) draws `flora_far_fraction` (0.25) of every column.
  The circle where grass ended becomes a fade. Both knobs on F4, local.
- **Built once, shown by fraction.** `FloraJob` sorts each model's instances
  by the same hash `flora_draw_fraction` uses, so a prefix of a buffer IS
  the hashed subset; `FloraColumn.set_fraction()` is a
  `visible_instance_count`. Crossing a ring never rebuilds a column. (The
  first version rebuilt on every crossing - 372 columns per jump - and the
  probe caught it.)
- F4 readout: cached columns, columns built, ms per column.

## After

| jump | terrain settles | grass, after that | columns built |
| --- | --- | --- | --- |
| out 1-6 | 4.9 - 8.7 s | **+0 ms** | 188 each - exactly the new area |
| back 1-5 | 3.7 - 6.4 s | **+0 ms** | **0** |
| back 6 | 6.1 s | +0 ms | 63 (the oldest evictions) |

Cost: 16,901 → 27,856 instances at spawn, 1.85 → 3.13 M triangles, for the
far ring. 6.2 ms per column on workers (was 5.5; the sort). If a machine
minds, `flora_far_fraction` 0.25 → 0.1 or `flora_far_m` → 64 pays it back.

Self-test: all passed (flora determinism, removal, winding unchanged).
Heightmap hash and tree count untouched - nothing here is worldgen.

## Tuned blind

- The far ring's density (0.25) and reach (128 m) were chosen from the probe
  and one spawn screenshot, not from walking. Judge in play: the fade should
  be invisible; if it reads as a second circle, raise the fraction.
- The cache size trades render-server memory for free backtracking; 1024 is
  generous on this machine and untested on a small one.
