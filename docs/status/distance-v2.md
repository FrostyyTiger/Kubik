# Distance v2 - status

The run of `docs/plans/distance-v2.md`, on `feat/distance-v2` from `main` at
`b163ab5` (`f23c3f0` plus the plan itself - distance v1, both nights, merged).
Night 1 is everything visible: the far terrain and the far forest both stop
being smooth. Night 2 is the seams, the bands and the boundary.

**The complaint this answers**, Marcel on 2026-08-28, looking at a night shot
from the valley floor:

> I love the fact that you can see the mountains, you can see the snow, but it
> feels still like it's a different game. [...] It feels like it's two separate,
> same art style game, but one is a cube based game, and the other one is just
> sort of an edge based vector game.

The far field was built to match the near field's **silhouette** and never its
**surface**. This epic gives it a surface made of blocks - bigger blocks the
further away you go, one per far-field cell, 4 m at the seam and 16 m at the
fog.

**The one number to lead with is not FIZZ.** It is `far_terrace`: one knob on
F4, 0 is the game Marcel photographed and 1 is the far country made of blocks,
and moving it redraws the background **without a reroll and without the player
moving**. That is how the whole epic is judged, and Stage 0 is where it was
built rather than where it was promised.

---

## Provenance

Distance v1 introduced this column and it is kept, unchanged, for the same
reason: `e63554f` is the bill for conflating "a number" with "a number worth
comparing".

| provenance | means |
| --- | --- |
| `ganymede, deterministic` | the far probe or the worldgen probe. Pure geometry from a seeded generator: same number on any box, every run, and the probe asserts it by running its whole table twice. |
| `ganymede, single run` | one wall-clock measurement. A smoke alarm, not evidence of a delta. |
| `ganymede, ABAB median` | interleaved, three runs each, median with spread, run order recorded. The only kind of number this epic compares two commits with. |
| `ganymede, eye` | a judgement made by looking at a tour shot taken here, on the RTX 3070 Ti, under the renderer named in the shot's directory. |

ganymede varies about 9% run to run on wall clock; Marcel's desktop varies 60%.
Every comparative number below was taken here.

---

*(this document is written as the run proceeds; sections appear in stage order)*

## Stage 0 - Measure first, and the switch

**Shipped.**

- `far_terrace` on F4 as `distance: far terrace`, 0.0 to 1.0, in
  `LOCAL_PROPERTIES` beside `far_filter_bias` and `far_peak_gain`. Nothing read
  it at this stage. `far_riser_shade` went in beside it, for Stage 3.
- **The knob does not need F7.** `FarField.apply_far_knobs()` keeps a snapshot of
  every LOCAL knob that changes only the far mesh or the impostor ring; when one
  of them moves it rebuilds both in place and returns the message to show.
  `game.gd` spends exactly the one line this epic allows it, `debug_hud.gd`
  gained two appended rows, and neither file was restructured.
- `FarField.rebuild_in_place()` re-requests at the centre and frontier the last
  request used - not "around the player", which would mean re-deriving World's
  chunk snapping in a second place. `FarTrees.force_rebuild()` forgets where the
  last ring was built so the next `update()` rebuilds it standing still.
- The far probe gained the `far_terrace` header, a **ring boundary** row (max
  and rms over a 50 m window straddling each boundary, because the 100 m bins
  put the 400 m boundary in whichever bin the worst sample fell in), a
  **terrace compliance** row, and - added during Stage 1 - a **shelf stability**
  row over a 200 m walk.
- `--strict` now fails on more than **one** frame over 33 ms. Decision 11.

### Why the knob mattered enough to be Stage 0

F7 is `_on_reroll_requested(same seed)`: the same world, rebuilt chunk by chunk.
3,276 chunks in 39,023 ms on Marcel's box. Forty seconds per flip, with the
world streaming back in around you, is not an A/B a person can judge by eye -
and this epic has exactly one acceptance test, which is a person flipping that
knob and saying whether they still see two games.

### The knob, as a self-test rather than as a promise

`selftest.gd` gained `far terrace knob`. It builds a real `World`, pumps
`FarField._process` by hand (the World is not in the scene tree, so a finished
mesh would never be applied), and asserts four things:

| check | result |
| --- | --- |
| a call with no far knob moved returns the caller's own "press F7" message | pass |
| moving `far_terrace` returns the far-field message and starts a rebuild | pass |
| **not one chunk is queued, built or freed by it** | pass |
| **0.0 -> 1.0 -> 0.0 returns EXACTLY the original vertex count** | pass |

The last row is hard rule 1 as a gate. It runs at every stage from here on.

### The baseline, and the numbers this epic is read against

Seed 42, `--view high`, fog_end 800 m, far_step 8 blocks, heightmap `76cccdb6`,
spawn `(-44, -124)`. All heights in **blocks** (1 block = 0.5 m game, 2 m real).
`ganymede, deterministic`.

| | `f23c3f0` |
| --- | --- |
| FIZZ rms / max | 0.607 / 21.570 |
| ROUGHNESS | 2.5648 |
| PEAK LOSS at 600 m | +55.28 mean, +81.14 worst |
| VALLEY GAIN | +0.53 mean |
| ring boundary 200 m | max 4.60, rms 0.462 |
| ring boundary 400 m | max 21.57, rms 1.611 |
| shelf move over a 200 m walk | rms 5.74 / 5.25 / 8.34, max 50.2 / 43.6 / 62.5 |
| far mesh in game | 103,608 vertices |

### Gate

| gate | result |
| --- | --- |
| far probe at `far_terrace 0.0` identical to `f23c3f0` | **MET** - every geometry row character-for-character identical; only the wall-clock lines differ (1,654 -> 1,650 ms per mesh) |
| far mesh vertex count | **103,608, unchanged** |
| `--strict` passes twice running | **MET** - 1 long frame then 0, holes 0 on both, PASS both. Under the OLD standard the first run would have exited 1, which is decision 11's whole point |
| the knob redraws the far country without a reroll | **MET** - see the self-test above; the wall-clock half is in Stage 2 |

---

## Stage 1 - The height grid

**Shipped**, and it took two attempts. The second one is the interesting part.

`hq = round(h / step) * step`, in **blocks**, where `step` is the ring's own cell
width - 8, 16 and 32 blocks, which are 4, 8 and 16 m. Quantising in blocks
rather than in metres is decision 4's cubic lock written directly: the ring's
step IS its cell width, so step height equals cell width by construction and the
three are powers of two of each other without any arithmetic that could round.

The corners blend: `h = lerp(h_true, hq, far_terrace)`, per corner, from the four
bilinear samples the quad already took. At 1.0 all four are the same number and
the top quad is flat. At 0.0 it is the old quad, unchanged, and not one extra
pyramid read is taken.

### The player term was not in the expression. It was in the input.

The first implementation quantised `_filtered()` - the height the smooth mesh
draws. That expression contains no player term, which is what hard rule 2 asks
for on its face. Its **input** does: `_level_at()` is `log2(distance from the
player)`, so the height being quantised breathes as the player walks, and
quantising a breathing number turns a half-block breath into a **whole step
jump**.

`ganymede, deterministic`, seed 42, `far_terrace 1.0`:

| | smooth (`f23c3f0`) | quantising `_filtered()` |
| --- | --- | --- |
| shelf move over a 200 m walk, rms | 5.74 / 5.25 / 8.34 | **9.76 / 10.10 / 13.56** |
| worst | 50.2 / 43.6 / 62.5 | **80 / 86 / 96** |
| FIZZ rms | 0.607 | 3.409 |

The terraces swam, exactly as hard rule 2 warns, with the rule's letter
satisfied throughout. **This is the finding of Stage 1** and it is why the rule
is worth restating as: nothing the quantisation READS may depend on where the
player is standing either.

### One level, not one per ring

The obvious repair is a pyramid level fixed per ring. It works - within a ring
`hq` becomes a pure function of world position and the FIZZ past 500 m falls to
**exactly zero** - and it breaks the property the whole plan leans on:

> every 16 m shelf is also an 8 m shelf, so crossing 400 m makes a mountain's
> shelves SUBDIVIDE rather than move

which is only true if the two rings quantise **the same height function**. With
a level per ring they do not, and the 400 m boundary measured **144 blocks**
against `f23c3f0`'s 21.6.

So: one level for the whole job, `log2(ring step / heightmap step) +
far_filter_bias`, with which ring's step chosen by `TERRACE_LEVEL_RING`.

### The sweep that chose it

All three run through the far probe at `far_terrace 1.0`, seed 42.
`ganymede, deterministic`.

| `TERRACE_LEVEL_RING` | 0 (level 2) | 1 (level 3) | 2 (level 4) | per-ring |
| --- | --- | --- | --- | --- |
| FIZZ rms | 1.279 | 1.284 | 1.589 | 2.246 |
| FIZZ max | 80.0 | 64.0 | 98.2 | 144.0 |
| ROUGHNESS | 15.46 | 14.42 | 12.54 | 13.20 |
| 200 m boundary, max | 32.0 | 24.0 | 24.0 | 40.0 |
| 400 m boundary, max | **80.0** | 64.0 | 64.0 | 144.0 |
| **PEAK LOSS at 600 m** | **+29.40** | +35.80 | +56.60 | +56.60 |
| seam fizz, summit vantage, 0-100 m | **19.36** | 45.63 | 98.19 | - |
| shelf move, rms | 4.58 / 6.63 / 5.20 | 4.26 / 6.19 / 4.92 | 4.01 / 6.73 / 4.76 | 6.26 / 10.10 / 8.68 |

**Shipped at 0 - the finest ring's 4 m cell, level 2** - on the two things that
can be seen:

- **PEAK LOSS.** +29.40 blocks against `f23c3f0`'s +55.28, a 47% improvement and
  the best number carried item 4 has ever had. Level 4 draws +56.60, which fails
  Stage 4's gate before Stage 4 starts: a terrace cut from a heavily filtered
  surface is a terrace cut from a mountain that is already too short.
- **The seam.** The terrace fades in over four cells at the voxel boundary and
  what it fades *towards* is this level, so the further that is from the surface
  the voxels actually have, the deeper the dip in the middle of the fade.
  Standing on the world's highest summit the 0-100 m band measures 19.4 blocks
  at level 2 against 98.2 at level 4.

What it costs is the 400 m boundary: 80 blocks against 64 at the two coarser
levels. That boundary is Stage 9's subject and is measured there.

### Gate

| gate | result |
| --- | --- |
| at 1.0, every corner height is an exact multiple of its ring's step | **MET, 100.0%** - 5,536 / 5,892 / 9,345 quads at spawn on the 8, 16 and 32 block grids, worst deviation **0.000** blocks; same at the summit and lake vantages. Read off the emitted vertices, not re-derived. Quads inside the seam band are excluded by construction - there the far mesh computes the VOXEL surface on purpose |
| walk 200 m and back; a named shelf does not change height | **NOT MET AS WRITTEN, and the honest comparison is better than it sounds.** A named shelf DOES move at a ring boundary. Over a 200 m walk the terraced far field moves rms **4.58 / 6.63 / 5.20** blocks against the smooth mesh's own **5.74 / 5.25 / 8.34** - so on average it moves LESS than the game already did. Worst sample is worse: 80/96/96 against 50/44/62. **Inside a ring it does not move at all**: FIZZ past 500 m is exactly `0.00` in every band and at every vantage, against 2.11-3.27 for the smooth mesh. Every block of the residue is at the two ring boundaries |
| hard rule 1 | **MET** - far probe at 0.0 identical to `f23c3f0` on every geometry row, far mesh 103,608 vertices at both 0.0 and 1.0 |
| self-tests | green |
| far probe determinism | **PASS**, tables IDENTICAL over two runs, at both knob settings |
