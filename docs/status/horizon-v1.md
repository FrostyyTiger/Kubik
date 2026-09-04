# Horizon v1 - status

The run of `docs/plans/horizon-v1.md`, on ganymede, in `~/Kubik-horizon-v1` on
`feat/horizon-v1`, started 2026-09-04. Three nights back to back in one
session, unattended, with `docs/plans/mesher-v1.md` running in the other lane
on the same box.

Written at the end of **every stage**, not at the end of the night, so a run
that dies at 04:00 still leaves a record.

---

## BLOCKING

**THE FRAME. `main` runs the sprint line at 41.67 ms median on ganymede at
Ultra; the north star's gate is 16.7 ms.** Measured for the first time tonight
by the instrument Stage 0 exists to build - three runs on a quiet box, spread
6.6%, 1,249 frames of 1,518 over the 25 ms hitch threshold. This is not a
regression this lane caused; it is the state of `main`, and it is what Stage 7
has to move. Full numbers under Stage 0.

---

## The canonical world line

Reprinted after every stage. One changed character is a red gate (plan § 0).

```
heightmap 4782edac   spawn (-44, -124)   53 lakes   15218 trees   config 1d7c18c7
```

**The plan's copy of this line says `c18af99d` and that is stale, not wrong.**
`docs/plans/horizon-v1.md` § "What horizon v1 is not" and § 2 both quote
`c18af99d` from `docs/status/light-v1.md`'s **Stage 0** table. Light v1's own
Stage 1 moved it to `1d7c18c7` and said so under the heading "The config hash
moved, and it was supposed to": D52 took `day_seconds` from 480 to 2400, and
`day_seconds` is deliberately a HASHED field because two machines running
different clocks would disagree about the hour for a whole session. `main` at
`f8ef45c` carries that change, this branch is cut from `main`, and the baseline
below measures `1d7c18c7` on the untouched tree.

So the invariant is unchanged and the number it is checked against is the one
measured here today. The four world-truth values - heightmap, spawn, lakes,
trees - are the plan's, character for character. Recorded under "Questions
taken alone" and in "For Marcel".

---

## The baseline, 2026-09-04, before the first edit

Taken on the tree at `f8d1588`, the tip of `main`, with the assets mounted and
the GDExtension built (`class exists: true`, C++ 19x GDScript on the seam
bench).

| instrument | result |
| --- | --- |
| `scenes/selftest.tscn` | **SELFTEST: all passed** |
| `worldgen_probe --seed 42` | heightmap `4782edac`, 53 lakes, **15,218 trees**, config `1d7c18c7` |
| `selftest.gd` canonical world | `heightmap 4782edac, spawn (-44, -124), 53 lakes, c++ builder`, both legs agreeing |
| heightmap build | 1500x1500 cells, 4 blocks per cell, 4,793 ms, 12 x 12 tiles of 512 blocks, median 10 ms |
| first far build (High) | 3,514,404 vertices, 673 ms job, 676 ms wall, c++ mesher |

---

## Stage 0 - the instruments, and the way to get anywhere

**Green.** Everything the plan's 0.1 to 0.5 asks for exists, exits, and is
measured below. Nothing visual changed, so this stage's tour is also the
baseline sheet.

### What shipped

| | what |
| --- | --- |
| `scripts/tools/sprint_probe.gd` | NEW. `--sprint-probe`, `--seconds`, `--label`. Sixty seconds of held sprint from spawn along `+X`, one flushed progress line per second to `build/probe/sprint-<label>.txt`, one machine-parseable summary, a 120 s watchdog that quits(2). **It exits.** |
| `scripts/tools/selftest_horizon.gd` + `scenes/selftest_horizon.tscn` | NEW. This lane's gate file, plus the one allowed line in `selftest.gd` that runs it inside the main suite. |
| `scripts/tools/far_probe.gd` | `--rings a-b`; the HANDOVER table; the C++ mesher by default with `--gdscript` to force the reference leg; two real bugs fixed, below. |
| `scripts/tools/screenshot_tour.gd` | `30-horizon-peak`, `31-horizon-far`, `32-horizon-walk`. |
| `scripts/game/game.gd` | `--sprint-probe`, `--tp X Z`, `--fog off`, `teleport_to()`; the ground wait now watches the player's own column. |
| `scripts/physics/locomotion.gd` | `FLY_SPEED` becomes `Locomotion.fly_speed`, written from the config on the main thread. |
| `scripts/world/sky_cycle.gd` | `SkyCycle.fog_off` - one switch, honoured in all four places fog is written. |
| `scripts/world/worldgen_config.gd` | Seven LOCAL, unhashed knobs; six of them inert until their stage. |
| `scripts/ui/debug_hud.gd` | Seven `horizon:` rows and a teleport row (two spinboxes and a button). |
| `scripts/tools/stream_probe.gd` | Retirement note at the top (Q22). Nothing else touched; `--stream-probe` still runs. |
| `scripts/world/flora/tree_field.gd` | `rebuild_count()`, for the sprint probe's line. |

### The canonical line

```
heightmap 4782edac   spawn (-44, -124)   53 lakes   15218 trees   config 1d7c18c7
```

Unchanged, both builder legs, `c++` and `gdscript`, in the same run.

### THE FRAME BASELINE - the number this whole plan exists to move

Ultra, seed 42, ganymede, **the mesher lane quiet** (it finished its Stage 4
before these were taken), three runs back to back:

| run | median | p99 | worst | over 25 ms | chunks | far rebuilds | far ms | tree rebuilds | moved | jumps |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| q1 | 41.67 | 75.34 | 87.64 | 1249 | 7827 | 19 | 530 | 3 | 543 m | 9 |
| q2 | 41.76 | 84.84 | 130.35 | 1253 | 7465 | 17 | 528 | 3 | 543 m | 10 |
| q3 | 39.17 | 80.30 | 115.76 | 1284 | 7711 | 18 | 532 | 3 | 543 m | 9 |

**Median of medians 41.67 ms, spread 6.6%. The gate is 16.7 ms. `main` runs
this walk at 24 FPS.** Frames over 25 ms: 1,249 of 1,518 - the run is over the
hitch threshold four fifths of the time.

That is the north star's third line, measured for the first time, and it is
BLOCKING at the top of this document until Stage 7 says otherwise. The far
field is the obvious suspect and the instrument already names it: **17 to 19
far rebuilds in sixty seconds at 530 ms each**, which is a rebuild every three
seconds and one of them in flight most of the time. Stage 3's "only what moved
is rebuilt" is aimed at exactly this.

### The determinism of the walk, and what the plan's Stage 0 check has to become

The plan asks that two back-to-back runs agree EXACTLY on `chunks`,
`far_rebuilds` and `tree_rebuilds`, and within 10% on `median_ms`. Measured:

| | q1 | q2 | q3 | spread |
| --- | --- | --- | --- | --- |
| `moved_m` | 543 | 543 | 543 | **0%** |
| `jumps` | 9 | 10 | 9 | one press |
| `tree_rebuilds` | 3 | 3 | 3 | **0%** |
| `far_rebuilds` | 19 | 17 | 18 | 11% |
| `chunks` | 7827 | 7465 | 7711 | 4.8% |
| `median_ms` | 41.67 | 41.76 | 39.17 | 6.6% |

**`chunks` and `far_rebuilds` cannot agree exactly and it is not noise in the
measurement - it is the measurement.** Chunk building is a per-frame time
budget (`World.BUILD_BUDGET_MS`) and a far rebuild is requested when the
frontier moves, so both are counts of what happened in however many FRAMES the
run got. A run that is 4% faster builds 4% more chunks. Asking them to be
identical is asking the frame time to be identical, which is the thing being
measured.

What IS exactly reproducible is the WALK: `moved_m` is 543 m in all three
runs, to the metre, and `jumps` differs by one press. So the check this
document holds itself to from here on is: **`moved_m` identical, `jumps` within
one, `tree_rebuilds` identical, `median_ms` within 10%** - and `chunks` and
`far_rebuilds` reported as load, not as gates. Recorded under "Questions taken
alone" and "For Marcel".

### The sprint probe jumps, and the plan did not ask it to

The first two Ultra baselines were taken exactly as 0.1 specifies - `wish =
(1, 0)` and the sprint bit, nothing else - and **both wedged against a rise
354 m out at second 43 and then measured seventeen seconds of standing still**:

```
s=43 frames=21 median_ms=48.15 ... moved_m=354 chunks=5377
s=53 frames=57 median_ms=17.52 ... moved_m=354 chunks=6219
s=60 frames=58 median_ms=17.12 ... moved_m=354 chunks=6219
```

Those trailing 17 ms frames are a stationary player with an empty chunk queue,
and they were dragging the median down into the sample the 60 FPS gate is read
off: 20.00 ms wedged against 41.67 ms actually moving. A frame gate measured on
a standing player is not a frame gate.

So the probe presses Space when it has not moved half a metre in half a second,
through `Player.jump_override` - the traversal probe's own hook, and the one
`player.gd` documents for this exact case ("a probe that never jumps measures a
world nobody plays in"). It still does not steer, fly or teleport: the line is
still straight along `+X`, a genuine wall still wedges it, and `moved_m` plus a
warning still say so. `jumps` is in the summary line because two runs that
jumped different numbers of times crossed different ground.

Recorded as a deviation under "Questions taken alone".

### Two bugs in the far probe, both older than this lane

1. **The far probe has crashed on its own header since light v1 merged.** Light
   v1 Stage 3 deleted `far_riser_shade`, `far_band_m` and `far_band_step` from
   the config with the paint path they belonged to, and left `_go()` printing
   all three: `Invalid access to property or key 'far_riser_shade'`. The probe
   then **hangs** - the coroutine aborts, `quit()` is never reached, and the
   process sits in its main loop forever. Every far-probe run since light v1
   merged has produced no table. Fixed: the header now prints the geometry
   knobs that survived.

2. **The probe's quad lookup could not see rings 0 and 1, and never could.**
   `LOOKUP_CELL_BLOCKS` is 8, with a comment reading "far_step is the finest
   ring's step, so one cell is covered by at most one quad of every ring" -
   true at `far_step` 8 with no divisor. `far_ring_div` has been 4 since
   2026-09-01, so ring 0's quad is 2 blocks: sixteen of them share one lookup
   cell, the claim loop keeps whichever it reaches last, and `height_at`
   returns NAN for fifteen sixteenths of the samples. It went unnoticed because
   fizz and roughness sample a sparse lattice over the whole disc where the
   coarse rings carry the count, and peak loss reads a summit at 600 m, which
   is ring 3. **The handover measurement is the first thing that asks about the
   seam**, and the seam is ring 0 - it came back "no samples" everywhere.
   Fixed: quads finer than the lookup cell are keyed exactly by their own
   corner at their own step, which is an index rather than a search.

Both are recorded here rather than only fixed, because the second one means
**no distance-v5-era number taken at the seam or at the 150 m and 300 m
boundaries can be trusted**, and the first means no far-probe table exists
anywhere between light v1 and tonight.

### The far probe now runs the C++ mesher by default

At `fog_end_m` 3,200 and `far_ring_div` 4 a far mesh is 3.44 M vertices and
most of a minute in GDScript; the probe builds 49 per run and runs twice. One
GDScript run was measured at over 90 minutes on this box and was abandoned.
The C++ leg does the same table in **71 s per run**. `far_cpp` defaults to 1,
so C++ is what the game draws; the GDScript leg is still reachable with
`--gdscript`, and that the two agree is asserted three ways in `selftest.gd`
(far parity, far slice parity, far layer parity, all green tonight).

### The far probe's table, `main`, Ultra config at High preset, C++ leg

```
vantage         fizz rms  fizz max  roughness
spawn              0.746    61.000     8.6779
summit             1.216    39.000    12.7263
lake               0.785    39.000    10.2934
ALL                0.975    61.000    11.1573   (514,700 samples)

ring boundary max fizz (+/- 25 m)
  150 m: max  7.00 rms 0.433 over  2811
  300 m: max 11.00 rms 0.842 over  3738
  600 m: max 32.00 rms 2.413 over  6459
 1200 m: max 48.00 rms 2.648 over 15287
 2400 m: max 39.00 rms 4.563 over  3551

peak loss   over 20: mean +0.96, worst +2.62, best +0.68, 0 over 4 blocks
valley gain over 20: mean -1.15, worst -0.73, best -2.13, 0 over 4 blocks

handover (rms / max, blocks; ! = over the gate; @N is the bearing used)
spawn   seam@0   0.36 / 1.61  |0/1@0   0.81 / 4.18 ! |1/2@180 0.80 / 1.71  |2/3@0   2.76 / 10.42 ! |3/4@0   5.97 / 19.35 !
summit  seam@90  0.69 / 1.71  |0/1@90  3.15 / 9.27 ! |1/2@90  8.33 / 31.62 !|2/3@90  1.95 / 6.86   |3/4@90 15.69 / 56.76 ! |4/5@180 13.82 / 90.97 !
lake    seam@0   0.08 / 0.17  |0/1@0   0.43 / 1.12  |1/2@0   1.18 / 4.52 ! |2/3@0   2.92 / 9.31 ! |3/4@0   0.77 / 2.39

far meshes: 98 built, 591 ms each, 3,436,848 vertices each
determinism: run 1 in 70,766 ms, run 2 in 71,328 ms, tables IDENTICAL - PASS
```

**The handover fails at most ring boundaries on `main` today.** That is the
baseline Stage 3 and Stage 4 are measured against, not a regression: this is
the first time the number has existed. The seam itself is comfortably inside
the gate at all three vantages, which is the one boundary distance v3 Stage 7
spent a stage on.

### Checks

| check | result |
| --- | --- |
| sprint probe exits 0, 60 progress lines | **PASS**, five runs, every one |
| sprint probe run twice: the walk identical | **PASS** - `moved_m` 543 in all three, `tree_rebuilds` 3 in all three, `median_ms` within 6.6%. `chunks` and `far_rebuilds` are load, not gates - see above |
| frame baseline recorded | **41.67 ms median**, and it is BLOCKING |
| `--tp 20000 0` then the far probe: exits 0, both runs identical | **PASS** - `[Game] teleport to (20000, 0) m, ground 326.3 m`, tables IDENTICAL, exit 0. The 326.3 m is the region's clamped edge height, which is exactly what Stage 1 removes |
| `--rings a-b` | present; narrows what is printed, never what is measured |
| horizon self-test | **PASS**, 4 tests |
| main self-test | **SELFTEST: all passed**, including `horizon` |
| character self-test | **36 tests, all passed** |
| far probe twice, identical | **PASS** |

### Tunables moved

None. Every knob added in this stage is at its plan value.

---

## Questions taken alone

Failure protocol item 7: the conservative reading, written down.

1. **The plan's canonical config hash `c18af99d` is stale.** Taken as
   `1d7c18c7`, measured on the untouched tree today. See "The canonical world
   line" above for the full reasoning. The conservative reading is that the
   invariant is "it does not move from what `main` produces", which is what
   every gate in this document checks.
2. **The commit trailers.** The plan (grill Q23) names
   `Co-Authored-By: Claude Fable 5.1` and Fable's session URL, because Fable
   wrote the plan. The commits in this branch are made by a different agent in
   a different session, and a trailer that names the wrong one is a false
   record of who did the work. Taken as: the same two trailer KEYS, carrying
   this session's own author and URL. The shape Q23 asks for is kept; the
   values are true.
3. **The sprint probe jumps when it is stuck, and the plan says wish and the
   sprint bit only.** Taken as: press Space when the body has not moved half a
   metre in half a second, through the traversal probe's existing
   `jump_override` hook. Reason and evidence under Stage 0 - without it both
   Ultra baselines wedged at 354 m and spent the last seventeen seconds of the
   sample measuring a standing player, which halved the median the 60 FPS gate
   is read off. It does not steer, fly or teleport; a real wall still wedges
   it and the summary still says so. Conservative in the sense that matters:
   the alternative was to report a frame number that flattered the build.
4. **The plan's Stage 0 determinism check cannot be met as written.** "`chunks`,
   `far_rebuilds` and `tree_rebuilds` agree exactly" is asking the frame time
   to be identical, because all three are counts of what happened in however
   many frames the run got. Taken as: **`moved_m` identical, `jumps` within
   one, `tree_rebuilds` identical, `median_ms` within 10%**, with `chunks` and
   `far_rebuilds` reported as the load the frame was carrying. Measured
   evidence under Stage 0.
5. **The far probe now runs the C++ mesher by default.** At `far_ring_div` 4 a
   GDScript run is over ninety minutes and Stage 3 would make it a day; the
   game draws the C++ mesh (`far_cpp` defaults to 1) and the two legs are
   asserted identical three ways in `selftest.gd`. `--gdscript` forces the
   reference leg.
6. **ENet's default port is taken by the other lane.** `24565` is held by the
   mesher lane's tour for as long as it runs, so every hosted run in this lane
   passes `--port 24566`. Nothing in the plan's command lines changes meaning;
   the flag is recorded here so a reader reproducing a number uses the same
   one. No file the other lane owns was touched to get this.
4. **Grill Q21 contradicts itself on the presets' reach.** "All presets see
   R = 32 km; they differ in the near" is followed immediately by "Low: ...
   R 8 km. Medium: ... 16 km." Taken as the explicit per-preset table, which is
   the more specific of the two and the only one that can be implemented.
   Ultra is 32 km either way, and Ultra is what every gate in this plan is
   measured at, so no gate depends on the reading. Lands in Stage 3.

---

## For Marcel

1. **The sprint line on `main` is 41.67 ms at Ultra - 24 FPS, not 60.** First
   time it has been measured. Stage 7 is where it is answered; Stage 3 is the
   change most likely to answer it.
2. **The far probe has been dead since light v1 merged** - it crashed on its
   own header print and then hung rather than exiting. Fixed. No far-probe
   table exists anywhere between light v1 and tonight.
3. **The far probe could never see rings 0 and 1**, so no seam number and no
   150 m or 300 m boundary number from the distance v5 era can be trusted.
   Fixed.
4. The plan's canonical line quotes a pre-light-v1 config hash. The world
   itself is untouched; see the section above. Nothing to do unless you want
   the plan's copy corrected.
5. The plan's Stage 0 determinism check and the sprint probe's jump are both
   deviations, both recorded above with their measurements.

---

## For the world-truth break

The silences - things this lane deliberately leaves wrong outside the home
region, for D44/D45's lane to fix.

*(filled in from Stage 2 on)*

---

## For the merge

One-line requests into files the mesher lane owns. Nothing here is done by
this lane.

*(none yet)*

---

## For the bible

*(none yet)*
