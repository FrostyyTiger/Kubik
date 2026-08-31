# Status

The latest run is **UI v1**, one night, on `feat/ui-v1`: `docs/status/ui-v1.md`.
**The screen stays clean so the world reads huge** - the game's first real UI,
built to the design in `docs/plans/ui-v1.md` and the procedure in
`docs/plans/ui-v1-tech.md`.

The load-bearing idea is the **fade**: one furniture cluster at the bottom
centre, one thin compass strip at the top, four empty corners - and when all
four safety conditions hold at once (stats full, nothing changed a stat
recently, daylight, low danger) it eases to **literally zero**. Cozy does not
look like a warm-coloured HUD; it looks like a clean screen with a huge world
behind it, and danger looks like instruments appearing. `safe-noon.png` is the
acceptance test and it passes on a count: **zero HUD ink in any sampled bar
region**.

What else is in it: `canvas_items` stretch, so every Control finally scales;
the host-authoritative stats table (hp/sp/mp) riding the existing 20 Hz packet
as three more row keys; a five-slot hotbar with a stand-in slab tool that
proves select-and-use end to end through the one mutation path; the compass
strip, which declares **north is -Z** for the first time anywhere in this
repo; party icons carrying the peer hue; the character sheet with its six
armour sockets and five read-only skills; and **the floating `Label3D` nametag
is gone**.

Five things worth reading even if you read nothing else:

- **Block edits are journalled now.** They were `CLAUDE.md`'s own first example
  of habit 2 and were the one event still not being recorded. Two appends to
  `world.gd` - `+25 lines, -0`, not one existing line touched.
- **The shot harness found the bug the numbers could not.** The HUD cluster was
  placed with `Control.position`, which is measured from the parent rect's
  origin and not from the anchor, so it sat at `(-110, -57)` - off screen while
  every fade number read correctly and the layer reported visible at full
  opacity. It was built first for exactly this reason.
- **The plan's 2x stretch gate was not measurable and is replaced.** The
  capture reads the logical canvas *before* the stretch transform scales it, so
  there is no 2x row to sample. What ran instead measures the thing that
  matters: the logical canvas at 1280x720, 1280x1000 and 1900x720, never below
  the design size in either dimension, with the title band tracking the type.
- **Hard rule 10 is an assertion, not a paragraph.** The driver sends Escape
  with the character sheet open and checks that the sheet closed *and* that we
  are still in the game scene. One missed consume is the difference between
  closing your inventory and being dropped out of your friend's world.
- **Nineteen values were chosen by eye from screenshots on a box with no
  monitor.** Every one is on the new **F9** panel and listed in the status doc
  with its starting value. Five taste calls are left explicitly open for
  Marcel, and `dusk-poster.png` is framed and left for him to disagree with.

**Nothing about the world moved.** Heightmap `76cccdb6` and spawn `(-44, -124)`
at every one of the eight stages; no file under `scripts/world/` was written
except the two journal appends above, and `worldgen_config.gd` was never
opened.

---

# Previous: trees v1

**No two alike, and the ziggurat arrives** - all
seven tree species re-authored against `docs/research/art-direction.md` §2.5
"Forest", which look v2 wrote and parked. Marcel's ask was "no variation,
they're all symmetrical, a bit boring - let's sort of nail this so we won't
have to think about it for a while", and Stage 0's instruments found it was
worse than the complaint: **TWINS 1.00 on spruce and beech**, meaning two trees
hashed from two different cells were the SAME TREE down to the pixel, from
every azimuth.

Now: the §2.5 spire, whose tiers are whorl ARMS of unequal length around a
solid core, each yawed a golden-angle step from the one below; the larch as a
**ziggurat**, four to six shelves with real air between them, so its sky shows
through the GAPS and not through the crown volume; the beech as a lobed oblate
scallop, bitten from outside, that has stopped being a solid of revolution; a
birch that bows rather than tilts and never closes its foliage over its own
pale bark; a wind-flagged krummholz cushion, and every one in a world combs the
same way off a wind direction hashed once from the seed; three snags; and a
hero that is no longer its parent scaled. Then a second colour: **authored
slivers under the whorls**, where a shelf stands proud of the one below.

**Nothing about where a tree stands moved, at any stage** - heightmap
`76cccdb6`, 28,383 trees, the species mix to the decimal, spawn `(-44, -124)`.
`tree_placement.gd` was never opened and neither were the `far_*` files.

Five things worth reading even if you read nothing else:

- **TWINS is 0.72 or better on all seven species and no species pair is over
  0.56.** SYMMETRY is met on five of seven; the spruce misses at 0.86 against a
  0.80 target and was **priced deliberately** - §2.5 says a conifer is a dark
  cut-out with a jagged edge and a SOLID body, and a solid body is a
  symmetrical one.
- **The sparse species are 24-65% CHEAPER in quads than they began**, and the
  whole gallery sheet fell 21,582 quads to 15,608 with the second colour on.
  Per-block holes are the worst input greedy meshing can be handed; the
  openness moved into the shape, where the mesher charges nothing for it.
- **There is not one floating block left in the forest.**
  `scripts/tools/loose_check.gd` is a committed tool now and reports 0 on all
  seven species over 1,673 specimens each. It found 3,002 on spruce, 18,548 on
  larch, 9,813 on birch and 1,076 on krummholz on the way there. The mechanism
  is a flood from the tree's own axis - build the set, flood it, write only
  what the flood reached.
- **An authored dark colour does not land where it was authored.** The sliver's
  first hex was `#2A2F3E` (H225 S32) and it photographed at H270 S6 - a neutral
  black band. This world's noon sun lands on the channels at ~(0.72, 0.54,
  0.38), so blue arrives at 53% of red. `#1F2A46` is that transform run
  backwards, and the finding is in `block.gd` beside the entry because the next
  authored dark colour will hit it too.
- **Streaming did not move**: ABAB, three runs each against pre-epic
  `93b32bd`, on ganymede, both medians inside the other side's range on both
  legs, holes 0 in all six runs. The only frame over 33 ms was on the pre-epic
  side.

**The one failed gate is canopy closure, and it is item 2 below with new
numbers.** Old growth **0.694 -> 0.648**, grove **0.523 -> 0.481**, between
groves 0.373 -> 0.354. The plan's self-fail clause says closure must not get
WORSE where the design said fuller, and it did. It ships anyway: §2.5's spire
proportion - max width one third of height - narrowed old-growth spruce crowns
by about 30% of disc area, §2.5 is the taste authority, and the visual
acceptance frames improved from the same change (the forest interior reads as
trees rather than columns; `15-under-canopy` shows a closed roof).
**The reconciliation is stem DENSITY, not fatter trees** - more trunks at the
same proportion closes a canopy without contradicting §2.5 - and density is
placement, which this epic's rules forbade it to touch. It is exactly the open
`TODO(marcel)` at `WorldgenConfig.grove_floor` (with `old_growth_keep` as its
other half), which now has a second measurement feeding it. **Marcel decides.**

The run before it is **distance v2, both nights**, on `feat/distance-v2`:
`docs/status/distance-v2.md`. **The far country is made of blocks too** - one
height per far-field cell, quantised to that ring's own cell width, with the
difference to each lower neighbour drawn as a vertical riser. 4 m steps at the
seam, 8 m at 200 m, 16 m to the fog, lit tops and shaded risers in the near
field's own lighting language, and the impostor forest is stepped pyramids
standing on the shelves instead of six-sided cones floating over them.

**It ships OFF.** `far_terrace` is on F4 at 0.0, and 0.0 is `f23c3f0` byte for
byte - checked by the far probe at seven stages and pixel-for-pixel in the tour.
Turning it up rebuilds the far mesh and the impostor ring **in place**, without
a reroll, without rebuilding a voxel chunk and without the player moving, which
is how the whole epic is meant to be judged.

Five things in it are worth reading even if you read nothing else:

- **PEAK LOSS at 600 m went from +55.28 blocks to +13.40.** The far field draws
  a summit 27 m short at the real scale, against 110 m before this epic and
  120 m before distance v1. Carried item 4 has never had a better number.
- **Past 500 m the far country now holds perfectly still** - FIZZ exactly `0.00`
  in every band at every vantage, against 2.11-3.27 before.
- **Hard rule 2 needed restating and the measurement found out why.** "No player
  term in the height quantisation" was satisfied to the letter by the first
  implementation, which quantised a height whose INPUT was a mip level chosen
  from the distance to the player. The terraces swam - rms 9.8-13.6 blocks over
  a 200 m walk. Nothing the quantisation reads may depend on the player either.
- **The knob was wired end to end and reached nothing.** `World.setup()` keeps a
  deliberate CLONE of the config, so the F4 panel and the far-field jobs were
  reading different objects. It compiled, logged a rebuild every time and
  changed nothing on screen. What caught it was a self-test printing the vertex
  count at 0.0 and at 1.0 and getting the same number twice.
- **`--rendering-driver` after the `--` selects nothing**, so the "both
  renderers" half of every check in this project may have been taken twice on
  Forward+. Fixed in the README; no earlier epic's `-gl` set has been checked.

**The acceptance test, for Marcel:** stand in the valley where
`Screenshot 2026-08-28 161152.png` was taken, open F4, and move
`distance: far terrace` from 0 to 1. The far country should redraw in under two
seconds without the world streaming back in around you, and the mountains should
stop being a different game.
`build/tour/final-t1/6-postcard.png` against `build/tour/n1-t0/6-postcard.png`
is that comparison on ganymede, and `final-t1-gl` / `n1-t0-gl` is the same pair
on Compatibility.

**Two agents were then given the postcards and none of the reasoning.** They
confirmed both shipped taste calls, overruled one of them upward, and found
three things the measurements had missed - a **zone bug** (the far terrain was
choosing meadow-or-rock from the SNAPPED shelf altitude instead of the true one,
so the treeline could move 4 m; fixed), the **black crush** (terracing more than
doubles the dead-black area of the far band, 7.08% -> 15.63%, because a slope
facing away from the sun becomes a wall of risers that all land on the shade
rung), and **summits that read as a city skyline** rather than as peaks. Only
the first is fixed; the other two are items 14 and 15 below.

**What it did not fix, measured:** the 400 m ring boundary is 3.7x LOUDER with
the terrace on - 80.00 blocks against 21.57 - and Stage 9 found out why, which
is not what the plan assumed. See item 9 below.

**Distance v2 and character v2 landed on the same day, from lanes that shared
three files and never collided.** `scripts/character/` and `scripts/world/world.gd`
do not appear in distance v2's diff at all, `scripts/world/look.gd` was never
opened by it, and the two `game.gd` / `debug_hud.gd` edits it did make were pure
appends. The merge conflicted in one paragraph of this file and nowhere else.

The run before that is **character v2**, on `feat/character-v2`:
`docs/status/character-v2.md`. Fourteen stages over two nights - the model grid
from 64 to 96 voxels, a liner slot that ended four black shirts, a knee and an
elbow, the lizardfolk rebuilt until **no two races' silhouettes overlap by more
than 0.70 for the first time in this project**, six armour slots on a bumped
wire format, and a walk with a contact pose in it. It is also the run that found
the gallery's own sheets are not bit-reproducible on this GPU, which changes
what counts as evidence for everything after it.

The run before that is **distance v1, both nights**, on `feat/distance-v1`:
`docs/status/distance-v1.md`. Night 1 is the far country's geometry and colour -
a filtered heightmap pyramid, a mip level continuous in distance, a peak-gain
dilation, and the end of the far field's zone dither. Night 2 is what grows on
it: the impostor forest stops being drawn as a CHARACTER, converges towards the
hillside it stands on, and runs to the fog instead of half way. **The meadow is
still gravel and its Stage 8 says why** - see item 8 below.

The run before that is **world feel v1**, finished 2026-08-27 on
`feat/world-feel-v1`: `docs/status/world-feel-v1.md`.

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

**Trees v1 re-measured it under the new tree shapes and all three numbers went
DOWN: 0.648 / 0.481 / 0.354.** That is the epic's one failed gate - closure got
worse where the design said fuller - and it ships, because §2.5's spire
proportion (max width one third of height) narrowed old-growth spruce crowns by
~30% of disc area and §2.5 outranks the number, while the visual acceptance
frames improved from the same change. **So this item now has two measurements
under two different trees, and the lever it wants has not changed: stem
DENSITY.** More trunks at the same proportion closes a canopy without
contradicting the art direction; wider crowns contradict it. `grove_floor` and
`old_growth_keep` are that lever, and the decision is still Marcel's.

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

**5. Hard rule 7: the frame budget is much closer to met than the last entry
said, and distance v1 did not move it.** The previous entry, written from two
runs, reported **20 and 24 frames over 33 ms** and called the rule provisionally
not met. Distance v1's night 2 ran the interleaved comparison that entry asked
for - twelve `--view High --strict` runs on ganymede across three ABAB batches,
seed 42 - and the long-frame count on **every one of them is 0 or 1**, worst
frame 22.6–46.4 ms.

The 20-24 was not wrong, it was a single pair of runs on a box that this epic
has now caught drifting 17% between sessions on an identical commit. The
threshold count is the worst possible instrument for that, which
`stream_probe.gd`'s own note says: it turns a drifting continuous quantity into
a coin flip. `--strict` still exits 1 on about half the runs, on exactly one
long frame.

**Distance v1, night 2 HEAD against the pre-epic commit, ABAB, three runs each,
run order recorded:**

| | Stage 0 (pre-epic) | night 2 HEAD |
| --- | --- | --- |
| built/s, out | 77.8 (75.8–80.2) | 76.2 (75.6–85.2) |
| built/s, back | 83.7 (82.8–87.7) | 84.2 (81.0–94.7) |
| frames over 33 ms | 0 (0–1) | 0 (0–1) |
| holes | **0** | **0** |

**Every row overlaps. Hard rule 6 of that epic — "do not make a failing rule
fail harder" — is MET, and the honest reading is "no measurable difference"**,
across two nights that added a second heightmap pyramid, two pyramid lookups
per far vertex, a colour pass through it and an impostor ring covering four
times the ground.

What is still open here is the *standard*, not the measurement: one long frame
per run is not zero, and `--strict` is written to fail on it.

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

**8. The meadow tufts read as gravel, and it is not a colour constant.** From
`16-spawn-postcard`: the ground cover reads as grey rubble scattered over green
grass. Distance v1 Stage 8 was scoped to fix it if it was a constant and to
stop if it was not, and it is not.

The reason, from `Look`'s own ramp at noon: **the meadow presents its TOP face
and is drawn LIT at `#809137`; a grass blade is a one-voxel column whose
visible faces are VERTICAL, so the ones facing away from the sun are drawn
SHADED at `#272B2D`.** The shade band is `mix(albedo, luma, 0.55) *
grey-violet`, so it throws away most of the hue before multiplying. Tripling
the blade's albedo — which overshoots the ground on the lit face and is
therefore already wrong — only reaches `#464C4F`. **It is a lighting-band gap,
not a colour gap, and no albedo constant crosses it.** Photographed at x1.40,
x1.75 and with the tuft's own base/tip spread narrowed: all three are
indistinguishable from HEAD.

Range-thinning through the knobs that exist (`flora_radius_m` 64 -> 32,
`flora_far_fraction` 0.25 -> 0.15) barely moves it either, because the speckle
is dominated by the band already inside the full-density circle. A fraction
that falls continuously with range lives in `World._flora_fraction_for()`.

**What does work, and is deliberately not shipped:** `flora_draw_fraction`
1.0 -> 0.55 (`build/tour/dist-8-draw55`). It is the per-machine QUALITY dial,
and it thins the grass at your feet as hard as the grass at 100 m. It is on F4
as `flora drawn` if you want the postcard now.

**Three fixes are named and all three are a look pass:** a decoration LOD that
turns a distant tuft into one flat lit patch (which would also take triangles
off the near field), a tuft model with more upward-facing surface, or a
look-pass decision about `shade_desat` — 0.55 at noon is what makes every
shaded surface in the game a variant of one grey-violet, and the meadow speckle
is downstream of it.

**9. The 400 m far-mesh ring boundary is 3.7x louder with `far_terrace` on, and
distance v2 found out why.** 80.00 blocks of worst-case FIZZ against
`f23c3f0`'s 21.57. It is the largest single regression in that epic and it is
the one thing in it that is worse rather than better.

**It is not the step ladder**, which is what the plan assumed. Two experiments,
each five lines, each run through the whole far probe:

| | 400 m max fizz |
| --- | --- |
| `f23c3f0`, smooth | 21.57 |
| shipped: each ring quantises its own height at its own step | **80.00** |
| every ring at the SAME STEP, each sampling its own cell centre | 96.00 - worse |
| every ring at the SAME SAMPLE POINT, each at its own step | **16.00 - gone** |

The shelves were never moving because 32 is not a multiple of 16. They move
because the two rings sample the cell height at **different world points** -
ring 1 at the centre of a 16-block cell, ring 2 at the centre of the 32-block
cell containing it, up to 8 blocks apart, which on a flank is tens of blocks of
height before anything is quantised.

**So a geomorph has a smaller job than anyone thought.** It does not have to
blend two surfaces; it has to blend the SAMPLE POSITION across the boundary -
over the last cell or two of the finer ring, move the cell-height sample from
the fine centre to the coarse one - and the power-of-two ladder does the rest.
The third row is not shipped because the point every ring would have to share is
the coarsest ring's, and the far country would then be 16 m blocks at every
range, which is the opposite of the whole idea.

**10. `--rendering-driver` after the `--` does nothing, silently.** Anything
after `--` is passed to the game, not to the engine, so the README's own
documented second tour line

    godot --path . -- --tour --seed 42 --label <name>-gl --rendering-driver opengl3

took its pictures on Forward+ as well. No error, no warning: both directories
fill up and the images differ by a frame of the day cycle. Caught in distance v2
Stage 6 because the two "renderers" produced identical measurements to three
decimal places. **The README is fixed and distance v2's own pair was re-taken.
Every earlier `-gl` set in this project was taken with the flag in the old
position and none of them has been checked.**

**11. The far mesh's vertex upload is on the main thread and terracing more than
doubles it** - 103,608 to 255,128 vertices at `far_terrace 1.0`. Interleaved
ABAB says every long-frame and chunks/s spread overlaps, so it is not a measured
regression; it is a thing that is now two and a half times bigger in front of
the tightest budget in the project. Single-sided risers would take it to 179,368
and tear a see-through gash down every steep face (photographed,
`build/probe/crop-single.png`). Getting both needs a watertight shell, which is
a mesher change.

**12. One hole sample in seven terraced runs, and it is not settled.** 0 of 11
at `far_terrace 0.0`, **1 of 7 at 1.0**, at a matched overlap; distance v1 saw 0
of 12. Hard rule S1 says never a hole, and one sample over a 480 m sprint
sampled four times a second is neither a pass nor a failure at that sample size.
The plausible mechanism is that terracing makes the far-mesh rebuild 12% slower
(1,650 -> 1,852 ms) and the hole is cut to a frontier captured a rebuild
earlier.

**The obvious remedy cannot be spent, and both ways of spending it were tried
during the merge.** Raising `FarFieldJob.FRONTIER_OVERLAP_CELLS` from 8 to 12
moves the far mesh's inner edge at **every** value of the knob, so
`far_terrace 0.0` stopped being `f23c3f0` (103,608 vertices became 104,808) -
and **the far probe cannot see that at all**, because it builds `FarFieldJob`
with an empty `frontier`, so the constant is dead code to it. Gating the extra
on `far_terrace` instead made the stream probe report **two holes that were not
there**, because `world.gd`'s `far_field_exclusion_m()` reads the same constant
to decide whether a column is covered - which is precisely what the comment
above that function already warns about, from the last time somebody did it.

It stays at 8. What would move this is more runs, or a far probe that can be
given a frontier - see item 13.

**13a. The screenshot tour is bit-reproducible in the far field and NOT in the
near one.** Two runs of code that is identical: the far band (rows 0-300) comes
back at mean |dL| 0.0000 and worst 0.0 - genuinely identical - while the near
field (rows 500-720) differs by up to 48 luma levels. The likely cause is which
flora columns have finished streaming when the shutter opens, not the scatter
hash. **So a tour A/B of a foliage shot is not evidence**, and every per-pixel
number in `docs/status/distance-v2.md` is deliberately taken over the far band
only. A capture barrier - drain the flora queue before the screenshot - would
make the whole tour comparable.

**13. The far probe is structurally blind to the frontier.** It never sets
`FarFieldJob.frontier`, so `_sector_exclude`, `FRONTIER_OVERLAP_CELLS` and the
whole per-sector hole are invisible to it, and a change to exactly that passed
seven stages of "identical on every geometry row". Either the probe should take
a frontier, or the far-mesh vertex count the WORLD prints at load should be a
gate in its own right. The second is nearly free and would have caught it.

**14. ~~Terracing more than doubles the dead-black area.~~ FIXED, 15.64% ->
8.90% against a 7.08% terracing-off reference.** Three explanations were tested
and died first: not the altitude bands (turning them off makes it worse), not
the impostors (removing them worse still - they were HIDING dark ground), not
the near field's own behaviour at range (a near cliff measures 0.00%). And
geometry cannot fix it: a riser is as tall as the terrain's own height
difference to its neighbour, so its area is cell width x slope and the step size
only rounds it.

The cause is a trap in the light. **Look's ramp is three flat bands, so on a
slope facing fully away from the sun the top and the riser land in the SAME
band** and nothing separates them. That is also why a symmetric lift was a weak
lever - it lifts the lit side, where the light was never the problem.

**`far_riser_lift` lifts only the risers whose azimuth faces away from the sun**,
which the mesher already knows because it is the same dot against
`Block.SUN_ASPECT` that `aspect_tint` has used since look v1. A sun-facing riser
stays at `far_riser_shade` 1.0 and is an honest voxel side face. It closes 79%
of the gap where a symmetric lift closed 15%, and keeps the step strength
(4.805 against 4.426 unlifted). Approximation, stated: SUN_ASPECT is a fixed
compass direction, so this is right around noon and drifts at dawn and dusk -
the same approximation aspect_tint has always shipped with.

**15. The far summits read as a city skyline. IMPROVED, NOT FIXED - and the next
lever is horizontal, not vertical.** Summit cells now round up onto a quarter of
their ring's step (4 m instead of 16 m at the horizon), which removes the worst
overshoot (-30.28 blocks -> -6.28) and uncovers a pointed peak the old slab was
clipping flat.

**But the silhouette's character does not move**: same edge count (60 vs 60),
same share of dead-flat columns (94.1% vs 94.1%), same riser scale. The
"skyline" reading comes from **flat-top WIDTH and sheer-sided risers**, and the
vertical grid touches neither - the centre peak's flat cap is 87 px wide after
against 84 before. **Shelf size or riser treatment at summit cells is the next
lever**; do not spend another pass on the vertical grid.

It cost PEAK LOSS +13.40 -> +24.20 mean, because Stage 4's better mean was
substantially overshoot luck. **`far_peak_gain` 0.85 buys it back to +15.00 and
improves FIZZ and VALLEY GAIN at the same time** - measured, and deliberately
not spent, because that is a distance v1 constant which also feeds the smooth
mesh and moving it would break hard rule 1. A terrace-only gain in `_cell_h()`
would get it cleanly. That is a decision, not a fix.

**16. The ridge test finds any local maximum over 96 blocks - shore berms and
lake rims, not only alpine summits.** 79% of what the finer summit grid does to
`6-postcard` lands at the SHORELINE, where the far-mesh waterline goes from a
razor-straight diagonal to a stepped one. Looked at rather than assumed: it is
arguably more right, since the sand above it is already drawn in terraces and a
banded surface with a smooth edge is internally contradictory. Named because it
arrived as a side effect of a summit argument, not because it is wrong.

Also worth keeping: **`_is_ridge` used `>=`, and on flat ground every cell is a
"ridge"** (`h >= h` in all four directions), so seed 42's meadows and its 53 lake
beds all qualified. Harmless under a round-up, ruinous under a finer grid - it
quadrupled the shelf heights across the flattest parts of the map and took the
far probe from four minutes to over forty. Now strictly `>`.

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
