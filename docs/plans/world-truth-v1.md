# World truth v1 - the break: real relief, rings from the capital, one world everywhere

The work order for phase 2 of `RECONCILIATION.md` section 9 - **the world-truth
break** - written in the shape of `docs/plans/light-v1-tech.md` and
`docs/plans/horizon-v1.md` so that one agent can execute it unattended: exact
edits, exact checks, exact numbers, what the agent may decide alone, what it
may not, what to do when a check fails, and what Marcel finds in the morning.

The direction is the bible: **D45** (real relief, 1,400 to 2,500 m from valley
floor to peak, and the vista rule), **D44** (unbounded terrain, content ringed
and measured from the Engineers' capital), **D56** (everything that changes
what a seed produces lands in ONE break, before any content is authored on a
seed), **D84** and **D85** (the north star, and the order: this lane starts
the day upload v1 lands, which itself follows horizon v1), with **D1** (the four grains; the world cube stays 0.5 m), **D21**
(trees are real size and already are), **D47** (heightmap terrain, placed
volumes), **D52**, **D55**, **D57** (the camera the vista rule is measured
through), **D63** (magic is distance, not altitude), **D73** and **D81** (the
airships have a range) as the fences. The lore is
`../Kubik-bible/lore/10-geography.md` (the ring table); the art is
`../Kubik-bible/style-bible/20-world-and-terrain.md` (the zones bottom to top,
the snow rule, the sightline rule) and `70-scale-metrics.md` (the relief row,
the horizon test, the vista rule, the camera). The audit that names the fault
is `docs/reconciliation/02-world-render.md` § C2 and § C4. Read those before
this file.

**What this lane is.** Today a seed produces a **quarter-scale** world:
`world_scale := 4.0` derives 350 m of relief from a real 1,400 m
(`worldgen_config.gd:50, 72, 1818`), so the world is mixed-scale - trees are at
1:1 (D21) and the mountains they stand on are at 1:4, which the repo's own
one-ratio rule calls a broken world. Wildness is Chebyshev distance from the
**map centre** normalised by **half the world width**
(`terrain_generator.gd:690`), a bounded-world assumption that D44 replaces with
distance from the capital. The seven elevation zones are **percentiles of a
histogram of the home 3 km** (`terrain_generator.gd:335`), so a tile at 30 km is
coloured against a sample it is not in. Lakes are a priority flood seeded from
**the border of a 3 km array** (`lakes.gd:174`) and capped at **2 blocks, one
metre** deep, which is why light v1's finding B7 says a lake can never show its
deep colour. Spawn is a scan of the same array. All of it is GDScript, all of
it is world truth, and all of it is single-threaded (`§ C3`).

This plan changes every one of those, **once**, in one branch, and then the
world is the world: real relief at one ratio, rings measured from the capital,
zones that mean the same thing at 3 km and at 30, lakes found per region on any
box, spawn chosen by the vista rule, and the generator's truth in C++ beside
`KubikHeightTiles`.

**What this lane is not.** No campfire, no characters, no buildings, no
creatures, no weather system, no rivers, no caves or overhangs (D47 stands), no
director, no vehicles - **traversal at real relief is flagged and measured in
this plan and designed in another one** (grill Q10). No new far-field ring, no
new fog mechanism, no lens work: horizon v1 owns all of that and has landed
before this lane starts. No content: rings are a FIELD in this lane, never a
place. Nothing is authored on the seed until this lane's canonical line is
green on two boxes.

**The one thing this lane does that no other lane may.** It retires the
heightmap hash `4782edac`, spawn `(-44, -124)`, 53 lakes and 15,218 trees. Every
epic since terrain v2 has held those four numbers as a hard gate. **This is the
break they exist to survive, and it happens exactly once** (D56). Section 3
defines the line that replaces them and Stage 0 builds the instrument that
prints it before anything moves.

The three habits apply: the ring radii, the zone bands and the relief constants
are **tables** (habit 1); nothing here touches the journal or the mutation path.

---

## 0. The contract

**Who and where.** One agent, Opus, on ganymede, **Forward+ only**, in tmux
session `world-truth`, worktree `~/Kubik-world-truth`, branch
`feat/world-truth-v1` cut from `main` **after horizon v1 and upload v1 have
both been merged into it** (D85). Ganymede: Ubuntu 24.04, RTX 3070 Ti 8 GB, driver 595, `~/bin/godot`
4.7.2, `~/godot-cpp` (pinned `26fb7ab`, API dumped), `~/bin/scons` (venv
`~/.venvs/scons`), `~/.venvs/kubik/bin/python` for PIL; windowed commands under
`xvfb-run -a -s "-screen 0 1280x720x24"` with `XDG_RUNTIME_DIR` exported to a
writable directory. The first console line of the first tour must read
`Vulkan 1.4 - Forward+ - Using Device #0: NVIDIA GeForce RTX 3070 Ti`; anything
else is a stop-and-record before the first stage. The ALSA errors under it are
the missing sound card and mean nothing.

**THE HARD DEPENDENCY, and it is the first gate of setup.** This lane may not
start until `origin/main` contains horizon v1's Stage 8 - the tile store, voxels
anywhere, the rings to 38.4 km, one material source, the fog ramp and the
floating origin. Section 2's first command checks it and stops if it is absent.
The reason is not tidiness: this lane deletes the home region, and every one of
the six silences horizon v1 recorded under "For the world-truth break"
(`docs/status/horizon-v1.md`) is an item in a stage below. Rebasing this lane
onto a half-landed horizon means resolving a conflict in
`terrain_generator.gd`, `heightmap.gd` and `far_world.h` at once, which is
three worlds' worth of merge on the one file set where a merge cannot be
eyeballed.

**File ownership.** Mesher v1 is merged (`2b93471`); horizon v1 is merged
before this lane starts. **This lane runs alone and owns every file it
touches** - which is the reason it can move world truth at all. If Marcel
starts a second lane the same nights, it may not touch: `worldgen_config.gd`,
`terrain_generator.gd`, `heightmap.gd`, `lakes.gd`, `world.gd`,
`far_field_job.gd`, `flora/tree_placement.gd`, `flora/flora_placement.gd`,
`scripts/tools/worldgen_probe.gd`, `selftest.gd`, `gdext/src/height_tiles.*`,
`gdext/src/world_truth.*`, `gdext/src/far_world.h`,
`gdext/src/register_types.cpp`. Everything under `scripts/character/`,
`scripts/ui/` (except `hud.gd`'s two danger lines) and `Kubik-assets` is free.

**Branch.** `feat/world-truth-v1`. One commit per stage minimum, pushed to
`origin` after every stage. **The agent never force-pushes, never rewrites
history, never reverts anyone else's commit, never edits `../Kubik-bible` or
`../Kubik-assets`.** Findings for the bible go in the status doc under "For the
bible" and become D85 onward from that side. Check the bible's "Next number"
line before proposing one; two sessions share that repo.

**Delivered by morning.** `feat/world-truth-v1`, pushed;
`docs/status/world-truth-v1.md` updated at the end of **every stage** (a run
that dies at 04:00 still leaves a record); a tour per stage; the truth probe's
line per stage; the vista probe's table from Stage 7; the sprint line from
Stage 8; a final message in the shape of section 6.

**Never.**

- **No content on the seed.** No village, no landmark, no site, no place. Rings
  are a scalar field in this lane. A ring that decides *where a thing is* is
  phase 4.
- **No second break.** Every change to what a seed produces lands in THIS
  branch. If a stage is wrapped early, what it did not do is written down and
  carried, never deferred to "a small follow-up" - a small follow-up is a
  second break and D56 exists to forbid it.
- **No overhang, no cave, no density field.** D47 stands: the generator is a
  heightmap.
- **No global pass.** Nothing this lane adds may require reading the whole world
  before answering a question about one column. Every world-truth function is a
  pure function of `(position, seed, config)` plus, at most, one region-local
  pass that is itself a pure function of `(region index, seed, config)`.
- **No un-quantised height.** Every height crossing the seam is rounded to
  1/1024 block on both legs, as `height_tiles.h` says and for the reason it
  gives.
- **No `TODO(marcel)` touched** (the domain-warp and valley-curve exercises in
  `terrain_generator.gd`).
- No question left unrecorded.

**Reading order, before the first edit.** `CLAUDE.md` (World rules, Engine
rules, Where work runs), `RECONCILIATION.md` § 3 A and B and § 9,
`docs/reconciliation/02-world-render.md` § C2, § C4 and § 4 (the silent
decisions D44 to D46 and D50 in its own numbering); the bible: `03-DECISIONS.md`
D1, D21, D41, D44, D45, D47, D52, D55, D56, D57, D63, D73, D81, D84,
`lore/10-geography.md`, `style-bible/20-world-and-terrain.md`,
`style-bible/70-scale-metrics.md`; `docs/research/terrain-tectonic.md` §§ 5-11
of its findings list (percentile zoning does not survive an unbounded world;
the `max_altitude` clamp is a clamp and not a ramp; lakes have no equivalent to
copy); `docs/research/distant-horizons.md` § 1 and § 2;
**`docs/status/horizon-v1.md` in full, and its "For the world-truth break"
section twice** - those six silences are this lane's inbox;
`docs/status/distance-v5.md` § "For Marcel to rule on" item 3 (the three
GDScript world-truth passes and their measured costs);
`docs/status/trees-v3.md` (tree sizes, and that the tree line is
`zone_band(ZONE_FOREST)`); `docs/status/light-v1.md` findings B4 and B7 and the
fog floor; `docs/plans/horizon-v1.md` (shape, and the ring table this lane
costs against); this file. Then the code, top to bottom:
`worldgen_config.gd` **all 2,018 lines** (the derivation in
`apply_world_scale()` is what this lane rewrites, and `PROPERTIES` versus
`LOCAL_PROPERTIES` is what decides whether a knob may move), `terrain_generator.gd`
**all 1,346** (`build_heightmap`, `_build_tile`, `_resolve_zone_thresholds`,
`_thresholds_from`, `_measure_zone_shares`, `height_at_block`, `detail_at`,
`_cell_index`, `wildness_at`, `zone_at`, `zone_band`, `surface_zone_at`,
`_slope_zone`, `column_surface_range`, `find_spawn`, `danger_at`),
`heightmap.gd` (the tile store as horizon v1 left it), `lakes.gd` **all 430**,
`gdext/src/height_tiles.{h,cpp}`, `gdext/src/far_world.h`,
`gdext/src/register_types.cpp`, `world.gd` (`setup`, the lakes and spawn calls
at `:852`, `_update_fog_floor`, `_world_chunk_min/max`),
`flora/tree_placement.gd` (`zone_band` at `:609, 631, 918`),
`scripts/tools/worldgen_probe.gd`, `selftest.gd` (`_test_canonical_world` at
`:2946`, the sky-reserve gate, the height tile parity), `traversal_probe.gd`
(it measures the map diagonal, which is about to stop existing),
`screenshot_tour.gd`, `scripts/ui/hud.gd` (`_danger_at_m`).

**Time budget** (wall clock, guidance): setup 1 h; Stage 0 3 h; Stage 1 4 h;
Stage 2 4 h; Stage 3 3 h; Stage 4 6 h; Stage 5 3 h; Stage 6 8 h; Stage 7 3 h;
Stage 8 3 h; Stage 9 2 h. **About forty hours: four nights, run back to back in
one session.** Night one is setup and Stages 0 to 2 (the world moves on night
one and the new line is recorded); night two is Stages 3 and 4; night three is
Stages 5 and 6; night four is Stages 7 to 9. The run does not wait for a review
between nights; Marcel reads whichever morning he is at and can stop or redirect
the session then. A stage that runs past 1.5x its budget is wrapped at its last
green commit and the next stage starts; what was left undone goes in the status
doc **and in the morning message's first three lines**, because in this lane
undone work is an unfinished break. **Stage 0 is the exception**: it is never
wrapped early, and if it cannot be made green the run stops there (section 5).

---

## 1. The grill - questions asked before the run

STATUS: **UNBOUND on the DESIGN rows, 2026-09-04.** Written by the planning
session on ganymede overnight. Nobody answered anything tonight.

**Two kinds of row, and the difference matters.**

- **DESIGN** rows are Marcel's and only Marcel's. Each has two to four options,
  a recommendation, and one line of what each option costs. **They are the
  point of this document.** Fable binds them in the morning on Marcel's
  answers and launches the run.
- **TECHNICAL** rows are answered here from the code and the bible, with the
  reasoning. **An answer in a TECHNICAL row is binding** unless Marcel
  overrules it.

A DESIGN row left unanswered at launch time is **not** taken by the agent alone.
The run stops at the first stage that needs it and says so; that is failure
protocol item 8 and it is deliberate, because a relief number guessed by an
agent is a world nobody chose.

### The DESIGN rows - Marcel's, unbound

| # | kind | question | options, and what each costs | recommendation |
| --- | --- | --- | --- | --- |
| **Q1** | **DESIGN** | **How much relief exactly, inside D45's 1,400 to 2,500 m, and what altitude is the valley floor?** The derivation is one constant: `relief_m` sets `k = (relief_m / 0.5) / 267`, and `k` scales the continent and mountain amplitudes AND their wavelengths together, so the characteristic slope is preserved at every size (`worldgen_config.gd:1818`, and the note above it about the version that scaled only the vertical and turned a third of the map into cliffs). Section 3 has the full derived table. | **A. 1,400 m** - floor 367 m, peaks 1,667 m, span 1,300 m, massif base 1,575 m, ceiling 210 chunks. The bottom of D45's band; the smallest change; but a 1.6 km massif base is not D45's "several kilometres across", and a 1,667 m peak cannot carry a real snow line. **B. 2,000 m** - floor 524 m, peaks 2,382 m, span 1,858 m, massif base 2,249 m, ceiling 299 chunks. Middle of the band; a real tree line fits, a real snow line barely. **C. 2,500 m** - floor 655 m, peaks 2,978 m, span 2,322 m, massif base 2,812 m, ceiling 374 chunks. The top of D45's band; a 1,900 m tree line and a 2,700 m snow line both sit inside it with room; a 25 m spruce is 1/100 of the mountain behind it, which is the Alps; costs the deepest chunk column and the longest climb. | **C, 2,500 m.** It is the only one of the three where the bible's own zone table (`20-world-and-terrain.md`, valley floor to peaks) can be written in real altitudes, and pillar 3 asks for the top of the band, not the bottom. The floor altitude follows the constant and is not a second knob: **655 m**, which is Interlaken. |
| **Q2** | **DESIGN** | **What do `world_scale` and the block grain do after this?** `block_size` stays 0.5 m and the player stays 4 blocks (D1) - that is not in question. What is: does `world_scale` survive as a knob? | **A. `world_scale = 1.0`, the derivation kept.** One number moves; `apply_world_scale()` still derives amplitudes, wavelengths, altitudes and the ceiling from `REAL_MOUNTAIN_RELIEF_M`. Q1's answer becomes `REAL_MOUNTAIN_RELIEF_M`. Cheapest, and keeps the "one ratio, derived once" property that stopped the 2026-08 drift. **B. Delete `world_scale`** and author the eight terrain constants directly. Honest about there being no ratio any more; loses the guard that made them move together; every future retune is eight numbers. **C. Keep it as a debug scale** (0 or less already means hand-tune). Same as A plus a knob nobody uses. | **A.** `world_scale` becomes 1.0 and stays, renamed in its comment from "metres of real world per metre of game world" to "the ratio the world is drawn at, and it is 1". **What does NOT change: `block_size` 0.5, the player at 4 blocks, `coarse_step` 4 blocks (2 m cells), the tree voxel 0.125 m, the character voxel 3.3 cm, the animal voxel 1.9 cm, and anything a player places.** Only the land grows. |
| **Q3** | **DESIGN** | **Where does the Engineers' capital sit on a seed, and how are rings 0 to 4 measured from it?** `lore/10-geography.md` makes wildness distance from the capital and gives five rings; nothing in the repo knows the word. | **A. The capital is the world origin, `(0, 0)` blocks, on every seed.** `ring_at` and `wildness_at` become pure functions of position - callable from a worker building a tile 30 km out with no global state and no search. Costs: the capital's site is whatever terrain the seed puts at the origin, so phase 4 must flatten for it (which it does for every village anyway). **B. A seeded point** inside the first 4 km, `hash(seed)`. Same purity, a little variety, and one more number in the truth line. **C. Searched** - the widest flat valley within N km, the way `find_spawn` works today. Costs a global pass before any height can be zoned, which is exactly the property this lane exists to remove. | **A, the origin.** The purity argument is not a convenience: under D44 the ring field is read by every column job on every box, and anything that has to be *found* before it can be *read* re-introduces the global pass. Variety belongs in the terrain, not in where the middle is. |
| **Q4** | **DESIGN** | **What are the ring radii?** D44/D63 put ring 1 as the alpine heartland (all of v1's content), ring 3 as the end of the airships' range (D73), ring 4 as the Builders' city and the end of the authored map. The view reaches 32 km (D84). | **A. Tight: 0-3 / 3-24 / 24-60 / 60-120 / 120-240 km.** Ring 1 is 24 km across, so from a peak in the capital valley you see the whole heartland at the D84 view distance. 24 km is 31 minutes at sprint. **B. Middle: 0-6 / 6-60 / 60-200 / 200-400 / 400-800 km.** Ring 1 is a country; the frontier (D77) has somewhere to advance for years; nothing is visible from anywhere else. **C. Wide: 0-10 / 10-150 / 150-500 / 500-1,200 / 1,200-2,500 km.** A continent in the lore's sense; unreachable without D81's engine. | **A, tight.** The one number the north star fixes is 32 km of sight, and the heartland should be the thing that FITS in it: the capital visible from its passes and the frontier visible from the capital is D41's own test, and it only holds if ring 1's outer edge is about one view distance. Rings 2 to 4 are a table with nothing in them until phase 4 and can be widened later without touching a seed, because **only ring 1's outer radius enters world truth** (it is what `wildness_at` normalises by). |
| **Q5** | **DESIGN** | **What replaces `wildness_at` and `danger_at`?** Today: `wildness_at` is Chebyshev distance from the map centre over half the world width (`terrain_generator.gd:690`) and drives exactly two things - `wildness_relief` 0.35 and `wildness_rock_deg` 12.0; `danger_at` is Euclidean distance from spawn over the distance to the map corner (`:1135`) and drives the HUD fade and nothing else. | **A. `wildness_at` = Euclidean distance from the capital normalised by ring 1's outer radius, clamped at 1; `danger_at` retired from the generator** and its one consumer (`hud.gd:_danger_at_m`) reads `ring_at` normalised until the campfire exists (D35 makes threat a function of the current fire, which is phase 3). **B. Both from the capital**, `danger_at` on a longer normaliser. Keeps a second field that means nothing yet. **C. Keep `danger_at` from spawn.** Spawn is near the capital by construction, so it is the same field with a worse name and a bounded-world normaliser. | **A.** One field, one origin, one meaning. It also fixes something quietly: over 1.5 km the wildness ramp saturated inside the home region, so **everything past 3 km has been at wildness 1.0 - maximum relief boost, minimum rock threshold - since the world became unbounded** (horizon v1 silence 1). Over 24 km it is the slow ramp it was always meant to be. |
| **Q6** | **DESIGN** | **Do the seven zones keep their share-of-map definition, or become altitude bands?** Today they are percentiles of a histogram of the home 3 km, re-measured with up to three correction rounds (`terrain_generator.gd:335-404`). `docs/research/terrain-tectonic.md` finding 6: *"percentile zoning does not survive an unbounded world"* - the correctness argument is a statement about a finite sample. | **A. Authored altitude bands**, six threshold altitudes in the config as a table, jitter and dither unchanged, calibrated once against Q1's relief. Real: shore below 660 m, meadow to 1,100, forest to 1,900 (the tree line), alpine to 2,300, heath to 2,550, rock to 2,700 (the snow line), snow above. Costs the decoupling terrain v2 Stage 7 bought - retuning relief re-zones the world - which is acceptable **only because relief now changes once** (D56). Gains: a tile at 30 km is zoned by the same rule as a tile at 300 m; no pass; the bible's own table becomes the code. **B. Keep shares, per region** - a histogram per 4 km region. A tile in flat country grows snow at 800 m. **C. Keep shares, one global histogram from a fixed seeded sample** of the whole 32 km disc. Deterministic, one pass at load, and still a lie at 200 km. | **A, altitude bands.** It is the only option that survives an unbounded world, it is what the bible's zone table already reads like (bottom to top), and it is habit 1: a table a director could read. The shares stop being a target and become a **measurement**, reported by the probe on the home disc so Marcel can see what the bands actually produced. |
| **Q7** | **DESIGN** | **Where are the tree line and the snow line at real relief?** They are not free numbers: today the tree line IS `zone_band(ZONE_FOREST)` (`tree_placement.gd:609, 918`) and the snow dust on a crown is read off the same band (`tree_field_job.gd:402`), so moving the zones moves the forest. Trees are 21 to 28 m (trees v3; `DESIGN.md` § north star). | **A. Real Alpine: tree line 1,900 m, snow line 2,700 m** against Q1-C's 655 m floor and 2,978 m peaks. Forest occupies 1,100 to 1,900 m - 800 m of climb, about a third of the relief - and the top 280 m is snow. A 25 m spruce is 1/32 of the forest belt's own height. **B. Compressed: tree line 1,500 m, snow line 2,200 m.** More snow visible from the valley, a shorter climb to the alpine, less forest. **C. Proportional to Q1** - the lines as fractions of the span (0.55 and 0.88), so they follow whatever relief is chosen. Costs a number nobody can picture. | **A, with the caveat that it is bound to Q1-C.** If Q1 comes back B (2,000 m) the pair becomes 1,600 / 2,150; if A (1,400 m), 1,150 / 1,450 and the snow line is 200 m below the peaks, which is not a snow line. **The tree line is the number to look at when judging Q1**: a mountain reads as a mountain when the forest stops well below the top, and at 1,400 m of relief it barely does. |
| **Q8** | **DESIGN** | **Lakes at real relief: how deep, and how big?** `lake_max_depth` is **2 blocks - one metre** (`worldgen_config.gd:890`), deliberately not derived from `world_scale`, and light v1's finding **B7** says the consequence out loud: the bible gives Lake two hexes (`#42c1c9` shallow, `#265f6e` deep) and **the deep one is unreachable at any permitted setting**, because there is no deep water in this world. At real relief the same cap over 4x deeper basins is a puddle in a glacial trough. | **A. `lake_max_depth` 40 blocks (20 m), `REAL_LAKE_MIN_M2` unchanged, lakes up to about 1 km across.** B7 closes: the deep teal is reachable, the water is over a player's head, and 20 m is a twentieth of a real Alpine lake, so still conservative. Costs: more of the map under water (measured in Stage 4) and a swimming question the game has not answered. **B. 12 blocks (6 m).** Deep enough for the tint, shallow enough to wade out of; B7 half closes. **C. Leave it at 2 blocks** and answer B7 in the bible instead ("the deep colour is for water you cannot stand in, and there is none in the Alps ring"). Free, and leaves a 2,500 m world with 1 m lakes in it. | **A, 40 blocks, and yes - `lake_max_depth` is part of this break.** It is in `PROPERTIES` (hashed, `worldgen_config.gd:1609`); it changes what a seed produces; there is no second break to move it in. **Tarns versus valley lakes** is the second half of the answer and is a consequence, not a knob: with the cap at 40 blocks a high closed basin fills to a small deep tarn and a valley trough fills to a long shallow lake, which is the two kinds the bible draws. Stage 4 photographs both and reports the count of each. |
| **Q9** | **DESIGN** | **Does spawn stay "a meadow that passes the postcard test", and what IS the postcard test at real relief?** Today: flat ground (<= 8 deg) with water within 600 m and a mountain within 600 m, inside 25% of the half width (`find_spawn`, `terrain_generator.gd:1008`). At 2,500 m of relief, "a mountain within 600 m" is a 76-degree wall filling the frame. | **A. Keep the postcard, restate it as the vista rule.** Spawn is searched over a bounded disc around the capital; the score requires water within 600 m and **a summit whose elevation angle from the eye is between 8 and 30 degrees**, which at 2,500 m of relief means the mountain is between 4.3 and 17.8 km away. Costs a search over a disc rather than an array, and one new instrument. **B. Fixed spawn** at the capital's own valley floor, no search. Free, deterministic, and gives up the one guarantee the first frame of the game has. **C. Keep today's numbers.** Spawn ends up at the foot of a cliff. | **A.** The postcard test IS the vista rule (Q10) evaluated at one place, and saying so once means one instrument measures both. **8 degrees** is the floor because below it a mountain reads as a hill; **30 degrees** is the ceiling because the D57 camera at a 15-degree default pitch and a 75-degree vertical field of view holds a summit at 30 degrees with about 7 degrees of headroom. |
| **Q10** | **DESIGN** | **The vista rule as a worldgen gate: how is it measured?** D45: *"from every campfire, village and pass, at least one whole mountain and the next landmark fit in frame at the default field of view and camera arm (D57)."* There are no campfires, villages or landmarks yet. | **A. Measure the mountain half now, defer the landmark half.** A `vista_probe` samples N seeded vantages (the spawn, the largest lake's shore, the lowest saddle between two summits - a pass - and 30 random meadow cells inside ring 1), and for each computes the elevation angle to every summit within 20 km along 64 bearings. **PASS = at least one summit between 8 and 30 degrees.** Report the share of vantages that pass; gate at 80%. The landmark half is written into the status doc as phase 4's inbox. **B. Measure it as a percentage of the frame** a mountain occupies. Same arithmetic, harder to read. **C. Defer the whole rule** to phase 4 when there are campfires. Costs: real relief would land with nobody having checked that D45's own rule holds on it. | **A.** The rule is a **sightline rule on the terrain** (`20-world-and-terrain.md`: *"sightlines are a worldgen rule: meadows, lake shores, the tree line and passes are where the mountain is seen; inside the forest it is not"*), so a terrain-only measurement is the right one and a forest interior is correctly excluded. 80% rather than 100% because the rule names the places a fire goes, not every square metre. |
| **Q11** | **DESIGN** | **Traversal at real relief - the consequence, flagged, not designed.** Sprint is 13 m/s (D55, logged as is and to be revisited *"once real relief and rails and airships carry the long distances"* - this is that moment). At Q1-C, a valley-floor to summit climb is 2,300 m of ascent over 4 to 6 km of ground: about **12 minutes at sprint on the flat, and far more up a 30-degree flank**, against 90 seconds today. Ring 1 is 24 km across (Q4-A): 31 minutes corner to corner. D73 gives the airships a range; D81 makes the engine that passes it the endgame's horizon; D24's cog rails and cable cars cover the heartland. **None of them exist.** | **A. Change nothing in this lane; measure and report.** Stage 8's sprint line and a new `traversal_probe` run report valley-to-summit time, ring-1 crossing time and the share of ground over the 55-degree floor angle. The numbers go to Marcel and become the input to the traversal decision. **B. Raise sprint** to keep the old climb time. Costs the tone (D38's slowness) and pre-empts the rails. **C. Add a climb assist / stamina now.** Out of scope, out of order. | **A, measure and flag.** The plan does not design a vehicle and must not. **The one thing Stage 8 must catch is the failure mode, not the slowness**: the traversal probe wedging against a flank it cannot climb, and the share of the world past 55 degrees. Slope is preserved by the derivation (section 3), so it should be unchanged - if it is not, the derivation is wrong and that IS this lane's problem. |
| **Q12** | **DESIGN** | **What happens to worlds and saves made on the old truth?** Every existing `.tres`, every saved edit and every screenshot in `build/tour/` is of a world that will not exist after Stage 1. | **A. Discarded, loudly.** The config hash moves, the join handshake refuses a mismatched peer as it already does, and a saved edit set from before the break is not loaded (a one-line version stamp). This is what "world truth changes once" means. **B. Migrate edits** by re-projecting block coordinates onto the new surface. Weeks of work for a world nobody has played. **C. Silently load them** onto the new terrain and let floating houses happen. | **A, discarded.** Nothing has been authored on a seed - that is precisely why D56 put this break before content. The status doc records the last old-truth tour label so the before/after strips still exist. |
| **Q13** | **DESIGN** | **How many nights, and does the run merge itself to `main`?** Section 0 budgets four nights. | **A. Four nights back to back in one session, and the agent merges to `main` itself when the last stage is green**, as horizon v1 and mesher v1 did under Marcel's 2026-09-04 amendment. **B. Four nights, Marcel merges** after reading. **C. Two lanes** (relief and rings in one, lakes and C++ in another) - forbidden by D56, since both change a seed. | **A**, with one condition this lane adds: **the merge is allowed only if the two-box parity of Stage 9 is green.** A world-truth break merged to `main` after being proved on one box is a break nobody can reproduce. |

### The TECHNICAL rows - bound here, with the reasoning

| # | kind | question | answer, and why | binds |
| --- | --- | --- | --- | --- |
| **Q14** | TECHNICAL | Branch point, and what must be true of `main` first. | **`feat/world-truth-v1` from `main` after horizon v1 is merged.** Mesher v1 is already in (`2b93471`). The check is mechanical: `git log origin/main --oneline \| grep -q "stage 8"` on the horizon commits, and `scripts/tools/sprint_probe.gd` and `gdext/src/world_truth.h`'s absence both present. If horizon v1 is not in `main`, **stop and record**; this lane's Stage 1 edits three of the four files horizon v1 restructures. | section 0, section 2 |
| **Q15** | TECHNICAL | Does the far mesh get more expensive at real relief? | **No, and the arithmetic says why.** The far field is a planar grid in XZ: quads per ring are `annulus area / cell^2`, which is 13,254 per ring by construction and about **124,000 quads over the nine rings** at the horizon v1 table - independent of altitude. The one term that could scale is the **riser** count under the cubic lock (step height equals cell width), which is `dh / step_y` per cell; `dh` is `slope x cell width` and `step_y` is `cell width`, so the ratio is **slope**, and the derivation preserves slope exactly (section 3). **Expected: far vertices per ring within 5% of horizon v1's Stage 3 table.** Measured in Stage 8; a rise over 20% means the derivation moved the slope and the stage is red. | Stage 8 |
| **Q16** | TECHNICAL | Do chunk counts change? | **No, for the same reason, and the ceiling is a red herring.** A column builds only the chunks the terrain passes through (`ColumnJob` reads `column_surface_range`), and that span is `slope x 16 blocks + 2 x detail_amp` - slope-preserved, so the span is unchanged. What DOES change is `world_height_blocks`, from **864 blocks (54 chunks) to 5,984 (374 chunks)** at Q1-C: a taller world costs nothing but a higher ceiling, exactly as the comment at `worldgen_config.gd:1878` says. **Two things must be checked rather than assumed**: `voxel_depth_chunks` 3 (48 blocks below the surface) is a depth, not an altitude, so it is unaffected; and any array sized from `world_height_blocks` would grow 7x - Stage 1 greps for one and there is none today. | Stage 1, Stage 8 |
| **Q17** | TECHNICAL | The shadow distance, the fog floor and the valley bands. | **`directional_shadow_max_distance` stays 250 m** - it is a screen-space budget and knows nothing about relief. **The fog floor and the valley bands do not.** `World._update_fog_floor` tracks the lowest ground near the player and `ValleyFog` places three bands above it (light v1 Stage 2); over 2,300 m of span, three bands sized for 325 m will sit in the wrong tenth of the valley. **Bound: the band altitudes become fractions of the local relief rather than absolute offsets**, measured on `6-postcard` and `4-valley-floor` in Stage 8, and the numbers recorded. This is a look change forced by a truth change and it belongs here rather than in a later lane. | Stage 8 |
| **Q18** | TECHNICAL | Does the `max_altitude` clamp stay a clamp? | **No - it becomes a soft ramp, and this is a real bug being fixed under cover of the break.** `height_at_block` ends in `clampf(h, min_altitude, max_altitude)` and `docs/research/terrain-tectonic.md` finding 9 names the consequence: *"a summit that reaches it goes flat"*. At 350 m of relief almost nothing reached it. At 2,500 m the mountain amplitude is 3,333 blocks against a 5,955-block ceiling and the peaks WILL reach it. Bound: the top 10% of the range compresses through `h' = hi - (hi - lo_soft) * exp(-(h - lo_soft)/(hi - lo_soft))` with `lo_soft = max_altitude - 0.1 * (max_altitude - min_altitude)`, so nothing is ever flat-topped and nothing exceeds the ceiling. Quantised as the last step, as always. **This changes what a seed produces and can only be done here.** | Stage 1 |
| **Q19** | TECHNICAL | The tree knobs, which `apply_world_scale` also derives. | **`apply_world_scale` stops touching them.** At `world_scale` 1.0 the existing line `tree_size_scale = ((42/ws)/0.5)/42` returns **2.0**, four times today's 0.5, which would double `TreeSpecies.max_reach()` and `max_height()` and therefore every placement margin and the `stamp_chunk` guard - for trees whose drawn size has come from the model sidecar's `voxel_m` 0.125 since trees v3 and is fixed by D21 regardless of relief. Bound: `tree_size_scale` and `tree_read_scale` become **authored constants at their current 0.5 and 2.0**, the derivation line is deleted with a comment saying why, and the `sky reserve` self-test is re-pointed. `lake_min_cells` **keeps** its derivation (it is a real-world area over a cell area and is correct at any scale: 40 cells today, **640** at 1:1, which is the 2,560 m2 the constant asks for). | Stage 1 |
| **Q20** | TECHNICAL | Where does the ring field live, and what may read it? | **A pure function on the generator and its C++ twin**: `ring_at(bx, bz) -> int` and `wildness_at(bx, bz) -> float`, both `O(1)`, both reading only `capital_block`, the ring radius table and the position. **No caller may cache a ring per region**, because a region is bookkeeping and this lane is deleting the last of it. The radii live in `WorldgenConfig` as a `PackedFloat32Array` in `PROPERTIES` (they shape the world through `wildness_at`). | Stage 3 |
| **Q21** | TECHNICAL | One new C++ class or four more methods? | **One new class, `KubikWorldTruth`, registered in `register_types.cpp`** (free now that mesher v1 has landed), beside `KubikHeightTiles` rather than inside it. The reason is the one `height_tiles.h` gives for its own existence: it owns **raw height** and nothing else, and its quantisation argument is about that one number. `KubikWorldTruth` owns **zones, rings, the column range and the lake flood** - four things that read height and never produce it. Same seam discipline: data in, arrays out, marshalled once per world, engine noise refs sampled natively, every height quantised to 1/1024 on both sides. **`KubikHeightTiles` is not edited in this lane** except to expose `column_range`. | Stage 6 |
| **Q22** | TECHNICAL | Are the GDScript twins kept? | **No.** D49 retired hard rule 1 and `CLAUDE.md` says *"delete each GDScript twin as its C++ path lands"*. Bound: each of the four paths keeps its GDScript reference implementation **through its own stage's parity gate and is deleted in Stage 6**, in the same commit that proves the parity. What survives is the **parity harness itself** (`selftest.gd`'s `height tile parity` and the new `truth parity`), run against a recorded reference vector rather than against a live twin. | Stage 6 |
| **Q23** | TECHNICAL | The canonical line, and how a break is proved rather than merely committed. | The old line hashed `Heightmap.cells`, one 1500x1500 array. There is no such array after horizon v1. **Bound: the new line hashes a FIXED LATTICE, not a store.** `worldgen_probe --truth` samples 4,096 positions on a fixed origin-anchored lattice out to 32 km and hashes, per position, the quantised `surface_at`, the zone id, the ring id and the water level. Section 3 gives the format. The lattice is a constant in `selftest.gd`, never derived from `world_blocks_xz`, and it is identical whatever tiles happen to be resident - which is the property `4782edac` had and a tile store cannot have. **The 1/1024 quantisation and `height tile parity` stay exactly as they are.** | Stage 0, section 3 |
| **Q24** | TECHNICAL | What happens to the tour, the gallery and the character self-tests. | **The tour follows the world by construction and needs no edit**: `1-spawn`, `2-summit`, `3-forest-slope`, `4-valley-floor`, `5-lake` and `6-postcard` all resolve their vantage from the finished heightmap at run time (`screenshot_tour.gd:275-340`). Two do not: **`17-rim`** hard-codes 3 km out and 120 m down, which at 2,500 m of relief points at a cliff, and horizon v1's **`31-horizon-far`** teleports to `(20000, 0)`. Both are re-aimed in Stage 7, in metres of the new world, and the reason is recorded. **The character self-tests build no terrain** (`selftest_character.gd` touches no `TerrainGenerator`, `Heightmap` or `WorldgenConfig`) and are unaffected - they are run every stage anyway. **The gallery** is swatch sheets on unshaded quads and is unaffected. **`traversal_probe.gd` IS affected**: it measures corner to corner on the map diagonal, which stops existing; re-pointed in Stage 8 to a fixed 24 km line through ring 1. | Stages 7, 8 |
| **Q25** | TECHNICAL | The config hash and `LOCAL_PROPERTIES`. | **The config hash moves, once, in Stage 1, and that is the whole point.** Every knob this lane adds that shapes the world goes in `PROPERTIES`, in the fixed order the comment at `:1561` requires, appended at the end: `capital_block_x`, `capital_block_z`, `ring_radii_m`, `zone_band_altitudes`, `relief_soft_knee`, `lake_apron_tiles`, `lake_region_tiles`. Every knob that decides only how much of it this machine draws goes in `LOCAL_PROPERTIES` with the one-line reason the section demands. **The three fields that were missing from `PROPERTIES` until terrain v2 Stage 1 are the precedent**: a shape knob outside the list is two machines in different worlds with a handshake reporting a match. Stage 9 audits the `@export` block against both lists, line by line, and records the audit. | Stage 1, Stage 9 |
| **Q26** | TECHNICAL | The export and CI. | **Not this lane's, and it stays not this lane's.** `build.yml` has been red since distance v4 (missing `libkubik.linux.editor.x86_64.so` at `savepack`); `selftest.yml` is green and covers `feat/**`. Bound: this lane **rebuilds the Linux library inside the run** and states in the morning message that **the Windows library must be rebuilt by Fable before anything is judged on the 5080** - which for this lane is not cosmetic, because a stale Windows library is a stale `KubikWorldTruth` and therefore a different world. The two-box parity of Stage 9 is what catches it. | Stage 9, section 6 |
| **Q27** | TECHNICAL | Commit hygiene. | `feat(world-truth):`, `fix(world-truth):`, `docs(world-truth):`; the body says what changed and which shot or probe judged it; trailers naming **the session that actually did the work**, not the session that wrote this plan (horizon v1's "Questions taken alone" item 2 settled this and it is right). | every commit |

---

## 2. Setup and the gates

```
cd ~/Kubik && git fetch && git checkout main && git pull --ff-only
git log --oneline -20                       # horizon v1's stage 8 MUST be here, else STOP (Q14)
git worktree add -b feat/world-truth-v1 ~/Kubik-world-truth main
cd ~/Kubik-world-truth && git reset --hard origin/main    # worktree add has resolved a stale main before
<godot> --headless --path . --import
python scripts/tools/sync_assets.py                       # the tree library must be mounted
cd gdext && scons platform=linux target=editor custom_api_file=../../godot-cpp/extension_api.json -j$(nproc) && cd ..
<godot> --headless --path . -s gdext/check.gd             # "class exists: true"
```

**Baselines, same day, before the first edit** - and they are the LAST reading
of the old world, so they are copied into the status doc in full:

```
<godot> --headless --path . scenes/selftest.tscn                                   # SELFTEST: all passed
<godot> --headless --path . scenes/selftest_horizon.tscn                           # horizon v1's own suite
<godot> --headless --path . scenes/character/selftest_character.tscn               # 36 tests
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
<godot> --headless --path . -- --host --seed 42 --port 24566 --far-probe
<godot> --headless --path . -- --host --seed 42 --port 24566 --sprint-probe --label wt-base
<godot> --path . -- --tour --seed 42 --label wt-base-old-truth
```

The probe's numbers are copied in as **the old baseline** and must match
`main`: heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, 15,218 trees,
config `1d7c18c7` **plus whatever horizon v1 moved it to** - horizon v1's own
gate was that it moved it to nothing, so `1d7c18c7` is expected and a different
value is recorded, not treated as red. `wt-base-old-truth` is the last tour of
the quarter-scale world and its label is written in the status doc so the
before/after strips outlive the break.

**The gates, run at the end of every stage, in this order:**

```
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . scenes/selftest_horizon.tscn
<godot> --headless --path . scenes/selftest_world_truth.tscn                       # this lane's own, from Stage 0
<godot> --headless --path . scenes/character/selftest_character.tscn
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42 --truth
   # the NEW canonical line, section 3. Run twice: identical or red.
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 7 --truth
   # a second seed, every stage, because a break that only works on 42 is not a break
<godot> --headless --path . -- --host --seed 42 --port 24566 --far-probe
<godot> --headless --path . -- --host --seed 42 --port 24566 --sprint-probe --label wt-<n>
<godot> --path . -- --tour --seed 42 --label wt-<n> --lens off --set tree_sway=0
python tools/compare_sheets.py wt-1 wt-<n-1> wt-<n>
```

then the stage's sampled checks and eye checks, then the status doc, then the
commit and the push.

**`--lens off --set tree_sway=0` on every tour in this lane, and that is
horizon v1's finding taken as a rule.** Its Stage 1 measured that a per-pixel
diff between two ordinary tour runs has a noise floor of about **2.7 mean |dL|**
because the film grain re-seeds from `TIME` every frame and the wind phase is
`TIME`; with both off, two runs of the same code differ by **0.0237** over 3,484
pixels of 921,600. This lane changes the ground under every shot, so it needs
the exact instrument, not the approximate one. One tour per stage is ALSO taken
with the lens on, for the eye.

**Sampled check method.** `~/.venvs/kubik/bin/python` + PIL, 9 x 9 mean of a
region the agent chooses on the named shot, HSV (H in degrees, S and V in
percent), pixel coordinates in the status doc. A window is a **GATE** (must
hold, section 5 on failure) or a **RECORD** (written down with the delta, never
a failure). **A 9 x 9 window is an instrument only where it sits on ground that
does not sway** - rock, snow, meadow, a lake's far shore.

**Magenta is a red gate.** A missing far sector, a sky-coloured hole, a crack
you can see the sky through, a flat-topped summit or a column of air where
ground should be: red.

---

## 3. The numbers

**Fixed, unless a grill row moved them. Everything not here is a tunable
(section 4) or is not the agent's.**

### The relief, derived (Q1)

`apply_world_scale()` keeps its shape and its argument - **one ratio, applied
to amplitude AND wavelength together, so the characteristic slope is
preserved** - and takes `REAL_MOUNTAIN_RELIEF_M` from Q1 with `world_scale`
1.0. At Q1's recommendation (2,500 m):

| | today (1:4) | after (1:1, 2,500 m) |
| --- | --- | --- |
| `k` | 2.6217 | **18.7266** |
| valley floor (`base_altitude`) | 183.5 blk / 91.8 m | **1,310.9 blk / 655.4 m** |
| ceiling of the shaping (`max_altitude`) | 833.7 blk / 416.9 m | **5,955.0 blk / 2,977.5 m** |
| span, floor to peak | 325 m | **2,322 m** |
| `mountain_amp` | 466.7 blk | **3,333 blk** |
| `continent_amp` | 125.8 blk | **899 blk** |
| massif wavelength | 394 m | **2,812 m** |
| continent wavelength | 1,579 m | **11,281 m** |
| `zone_jitter_blocks` | 31.5 blk / 15.7 m | **224.7 blk / 112.4 m** |
| `world_height_blocks` | 864 (54 chunks) | **5,984 (374 chunks)** |
| `lake_min_cells` | 40 | **640** |
| characteristic mountain slope | 67.1 deg | **67.1 deg, unchanged - this is the gate** |

**The slope row is the load-bearing one.** It is preserved by construction and
it is what makes Q15 and Q16 true, so Stage 1 measures it rather than trusting
it: the share of the map past 55 degrees (the character's floor angle) and past
60, before and after, on seeds 42 and 7. **A change over 2 percentage points is
a red gate**, because it means the derivation moved the shape and not only the
size - the exact failure the comment at `worldgen_config.gd:1790` records from
the first attempt at this in terrain v2.

### The zones, as altitudes (Q6, Q7)

Six thresholds, authored, in metres of altitude, jittered by
`zone_jitter_blocks` and dithered over `zone_blend_blocks` exactly as today:

| boundary | altitude | what it is |
| --- | --- | --- |
| shore / meadow | 690 m | 35 m above the valley floor |
| meadow / forest | 1,100 m | where the wood starts |
| forest / alpine | **1,900 m** | **the tree line** |
| alpine / heath | 2,300 m | |
| heath / rock | 2,550 m | |
| rock / snow | **2,700 m** | **the snow line** |

`zone_blend_blocks` stays **6.0 blocks (3 m)** - it is a distance in altitude
and does not scale, for the reason `worldgen_config.gd:559` gives. The seven
**shares** stop being inputs and become outputs: the probe reports what the
bands produced on the home disc, and the status doc carries the table.

### The rings (Q3, Q4, Q5)

Capital at block `(0, 0)`. `ring_at` is Euclidean distance from it against:

| ring | outer radius | what the lore puts there |
| --- | --- | --- |
| 0 | 3 km | the capital valley |
| 1 | 24 km | the alpine heartland - all of v1 |
| 2 | 60 km | the continent's edges |
| 3 | 120 km | the near islands, the end of the airships' range (D73) |
| 4 | 240 km | the far islands, the Builders' city, the end of the authored map |

`wildness_at(bx, bz) = clamp(dist_m / 24,000, 0, 1)`. `danger_at` is deleted
from `TerrainGenerator`; `hud.gd:_danger_at_m` reads `ring_at / 4.0`.

### The lakes (Q8)

`lake_max_depth` **40 blocks (20 m)**; `lake_min_cells` 640 (derived);
`lake_level_offset`, `lake_min_depth`, `shore_flat_blocks` and
`shore_flat_cells` unchanged. **A lake region is 16 x 16 level-0 tiles
(4,096 m) anchored to the origin, with an apron of 4 tiles (1,024 m) on every
side.** The flood is seeded from the apron's outer border, exactly as today's
is seeded from the map border and for the same reason; a basin whose water
still touches the apron's outer edge is treated as draining and discarded.
Cells read the answer from the region that owns them. **Consequence, stated
rather than discovered: a lake wider than about 1 km can be cut at a region
border.** Stage 4 measures the largest lake on seeds 42 and 7 and reports
whether any lake reaches the apron; if one does, `lake_apron_tiles` is the
tunable that answers it.

### The vista rule (Q9, Q10)

The elevation angle from an eye at 1.6 m to a summit of height `H` above the
eye at horizontal distance `D` is `atan(H / D)`. At 2,322 m of span:

| `H` | 2 km | 4 km | 6 km | 8 km | 12 km |
| --- | --- | --- | --- | --- | --- |
| 350 m (today) | 9.9 deg | 5.0 | 3.3 | 2.5 | 1.7 |
| 2,300 m | 49.0 deg | 29.9 | 21.0 | 16.0 | 10.9 |

**PASS at a vantage = at least one summit whose elevation angle is between 8.0
and 30.0 degrees.** So a full-height mountain must stand between about **4 km
and 16 km** away - which is the sentence D45 is really making, and it is a
sightline rule on the terrain (`20-world-and-terrain.md`). Gate: **>= 80% of
sampled vantages pass**, and **spawn passes** (Q9). Sixty-four bearings, summits
within 20 km, sampled off the level-3 height tiles so the probe is cheap.

### The new canonical line (Q23)

One line, printed by `worldgen_probe --truth` and by `selftest.gd`, after every
stage, on two seeds:

```
truth <8 hex>  capital (0, 0)  spawn (x, z)  relief <peak - floor> m  tree line <m>  snow line <m>
lakes <n> in 24 km  deepest <m>  trees <n> in 3 km  zones <7 shares>  config <8 hex>
```

`truth` hashes, over a **fixed origin-anchored lattice of 4,096 positions on a
64 x 64 grid at 500 m spacing** (a 32 km square, centred on the capital), the
tuple `(quantise(surface_at), zone_at, ring_at, quantise(water_level))` per
position, in lattice order, through `world_hash.gd`'s own mixer. The lattice is
a constant; it is not derived from any config field; it does not care which
tiles are resident. **This is what replaces `4782edac`, and it is strictly
stronger**: the old hash covered heights over 3 km and nothing else, this
covers height, zone, ring and water over 32 km.

**How it is proved on two boxes.** The same command on ganymede (gcc) and on
Marcel's Windows box (MSVC) must print **the identical `truth` string** for
seeds 42 and 7. That is Stage 9's gate and Q13's merge condition. The two
existing guards stay untouched and are what make it possible: **every height
quantised to 1/1024 block on both legs** (`height_tiles.h`: half a quantum is
0.24 mm of world against a double ULP of 0.00005 mm, a 20,000x margin) and
**`height tile parity`** in `selftest.gd`.

### The cost, expected (Q15, Q16)

| | horizon v1's number | expected after | why |
| --- | --- | --- | --- |
| far quads, rings 0-8 | ~124,000 | **within 5%** | planar grid; riser ratio is slope, and slope is preserved |
| far vertices at Ultra | Stage 3's table, <= 2.0 M | **within 5%** | same |
| chunks in a 60 s sprint | Stage 0's ~7,700 | **within 10%** | column span is slope x 16 blocks |
| `world_height_blocks` | 864 | **5,984** | a ceiling, not a cost |
| sprint median | horizon v1 Stage 7's number | **within 10%** | GATE: a regression over 10% is Stage 8's to explain |
| height tile memory at 20 km | 9 MB | **within 20%** | tiles are floats per cell, not per metre of altitude |

**Everything in this table is measured in Stage 8 and recorded in the status
doc.** None of it is asserted here as a result.

---

## 4. Tunables

The only numbers the agent may change on its own judgement. Everything else in
this file is fixed, and **no DESIGN row's answer is ever a tunable.** Each
change: the shot or probe that decided it, before and after, in the status doc.

| knob | where | start | range | judged on |
| --- | --- | --- | --- | --- |
| `relief_soft_knee` | the Q18 ramp | 0.10 | 0.05-0.20 | `2-summit`, flat-top check |
| `zone_jitter_blocks` | derived | 224.7 | x0.5-x1.0 of derived | `9-treeline` - a 112 m wobble may be too loud |
| `zone_blend_blocks` | config | 6.0 | 4-12 | `9-treeline`, confetti check |
| `zone_dither_blocks` | config | 4 | 4-16 | the same |
| `lake_apron_tiles` | lakes | 4 | 2-8 | largest-lake reach, Stage 4 |
| `lake_region_tiles` | lakes | 16 | 8-32 | flood time per region, memory |
| `shore_flat_cells` | config | 3 | 3-8 | `10-shore` island check at 20 m depth |
| valley-fog band fractions | `ValleyFog` | today's | fractions of local relief | `4-valley-floor`, `6-postcard` |
| spawn search radius | `find_spawn` | 4 km | 2-12 km | spawn passes the vista gate |
| vista vantage count | `vista_probe` | 33 | 20-100 | the pass share's stability across two runs |
| lake flood bucket resolution | `lakes` | 8/blk | 4-16 | flood time, spill-point error at 20 m |
| `far_supersample` | tiles | horizon v1's | 2, 4 | far probe FIZZ at rings 6-8 |

---

## 5. Failure protocol

1. **A self-test or a probe goes red:** fix it within the stage; if the fix is
   not obvious in 20 minutes, revert to the stage's last green commit, record,
   and continue with the next stage only if it does not build on the reverted
   work. Dependencies: 1 on 0; 2 on 1; 3 on 1; 4 on 1 and 2; 5 on 2, 3 and 4;
   6 on everything before it; 7 on 1, 2 and 5; 8 on everything; 9 on nothing.
2. **The truth line changes when a stage did not mean to move it:** the stage
   is not done, whatever else passed. Find the write. **In this lane the line
   is EXPECTED to move in Stages 1, 2, 3, 4 and 5 and to be FROZEN from Stage
   6 on** - Stage 6 is a port and a port that changes the world is a bug. From
   Stage 6, one changed character is a red gate with no tolerance.
3. **Two runs of `--truth` disagree with each other:** something is reading a
   store instead of a function, or a worker wrote into a shared tile. Fix
   before anything else in the stage; determinism is the instrument.
4. **Seed 7 disagrees with seed 42 about a structural fact** (no lakes, no
   spawn, zones all one band): the change is fitted to one seed. Record and
   fix; a break proved on one seed is not proved.
5. **The slope share past 55 degrees moves more than 2 points (Stage 1):** the
   derivation changed shape as well as size. Stop, do not proceed to Stage 2,
   and re-read the note above `apply_world_scale()` - this exact failure is
   recorded there from terrain v2.
6. **A summit comes out flat-topped:** the Q18 ramp is wrong or was not
   applied. Red gate; `2-summit` is the shot.
7. **The vista gate fails below 80% (Stage 7):** do NOT retune relief to pass
   it. Record the share, the failing vantage types and the histogram of best
   elevation angles, and continue. The vista rule may be telling Marcel
   something about Q1 or about where fires go, and that is his to read.
8. **A DESIGN row was left unbound and a stage needs it:** stop at that stage,
   push what is green, write the question at the top of the status doc, and
   continue with any later stage that does not need it. Do not guess a world.
9. **The sprint line regresses more than 10% (Stage 8):** record it as BLOCKING
   with the full three-run table and continue to Stage 9. Do not start
   optimising; horizon v1 owns the frame and this lane owns the truth.
10. **The two-box parity fails (Stage 9):** BLOCKING, at the top of the status
    doc, and **the merge to `main` does not happen** (Q13). Print the first
    lattice position where the two differ and the two values; that is what the
    lattice is for.
11. **An eye check fails while every window passes:** record it with the shot
    name and your sentence; do not revert.
12. **A question this file does not answer:** take the conservative reading -
    smaller change, nearer today's value, fewer files - write the question and
    the reading under "Questions taken alone", continue.
13. **Stage 0 cannot be made green:** push what exists, write the findings, stop
    the run. Nothing after Stage 0 is judgeable, because after Stage 1 the old
    line is gone and the new one is the only evidence there is.
14. **Godot hangs or a tour crashes:** kill it, re-run once; if it repeats,
    record the command and the last console lines, continue without that
    evidence, saying so.
15. **`origin/feat/world-truth-v1` has moved:** it should not. `git pull
    --rebase`; a conflict is a stop-and-record.
16. **Memory for the game process passes 12 GB:** the lake regions or the tile
    store are not evicting. Fix before continuing.

---

## Stage 0 - The instrument that survives the break

**Budget 3 h. Never wrapped early.** After Stage 1 the old canonical line is
gone forever, so the new one has to exist, be trusted, and have been run on the
old world first - otherwise the break is a change nobody can compare against
anything.

### 0.1 The truth probe

`scripts/tools/worldgen_probe.gd` gains `--truth`: build the world, then print
the section 3 line. The lattice, the hash and the format live in one place
(`scripts/world/world_hash.gd` gains `truth_hash(samples)`) so the probe and
`selftest.gd` cannot drift. **The probe must exit**, and it must not need a
window or a host.

`selftest.gd`'s `_test_canonical_world` is rewritten in the same commit:
`CANONICAL_HEIGHTMAP`, `CANONICAL_SPAWN` and `CANONICAL_LAKES` are replaced by
`CANONICAL_TRUTH`, `CANONICAL_SPAWN` and `CANONICAL_LAKES_24KM`, **both legs
still run**, and the old constants are kept in a comment block above with the
date they were retired and the D-number that retired them (D56). A number
deleted is a number somebody re-derives.

### 0.2 The vista probe

`scripts/tools/vista_probe.gd`, new, `--vista`: resolve the vantages of section
3, compute the best elevation angle at each over 64 bearings and summits within
20 km read off the level-3 tiles, print one line per vantage and a summary:

```
VISTA seed=<s> vantages=<n> pass=<k> share=<p>% best_deg median=<m> spawn=<deg> worst=<name>@<deg>
```

Bounded by construction, no window, exits with 0 on pass and 1 on a share below
the gate, so a script can read it.

### 0.3 The slope probe, and the traversal re-point

The share of the map past 40, 55 and 60 degrees, on a fixed lattice, printed by
`--truth` as a second line. It is three numbers and it is the gate for failure
protocol item 5. `traversal_probe.gd`'s corner-to-corner target is replaced by
a fixed 24 km line from the capital along `+X` (Q24), and its header records
why.

### 0.4 The world-truth self-test

`scripts/tools/selftest_world_truth.gd` + `scenes/selftest_world_truth.tscn`,
this lane's own gate file, plus the one allowed line in `selftest.gd` that runs
it inside the main suite. Stage 0 seeds it with: the lattice is 4,096 positions
and its first and last are the expected ones; `truth_hash` of a fixed synthetic
sample vector equals a recorded constant (so the hash function itself is pinned
independently of the world); the probe's line parses. Later stages append.

### 0.5 Checks

- `--truth` on the **unmodified** tree, seeds 42 and 7, twice each: identical.
  **Record both lines: they are the last reading of the quarter-scale world.**
- `--vista` on the unmodified tree: **record the pass share at 350 m of
  relief.** It will be low, and that number is half the argument for D45.
- The slope line on the unmodified tree: record.
- The world-truth self-test passes; the main suite, the horizon suite and the
  character suite still pass.
- Commit `feat(world-truth): stage 0 - the truth line, the vista probe, and the last reading of the quarter-scale world`.

---

## Stage 1 - Real relief

**Budget 4 h. The world moves here.**

### 1.1 The derivation

`worldgen_config.gd`: `world_scale` to **1.0** with its comment rewritten (Q2);
`REAL_MOUNTAIN_RELIEF_M` to Q1's answer. In `apply_world_scale()`:

- the amplitude, frequency, altitude, jitter and ceiling block is **unchanged**
  - it is correct at any `k` and that is the point of it;
- the **tree block is deleted** (Q19), `tree_size_scale` and `tree_read_scale`
  become authored `@export`s at 0.5 and 2.0, and the comment records that trees
  are models at `voxel_m` 0.125 since trees v3 and are fixed by D21;
- the lake block is **unchanged** (`lake_min_cells` derives correctly);
- `REFERENCE_RELIEF_BLOCKS` and the seven `REF_` constants are unchanged - they
  are the shape and the shape is not what this lane changes.

`selftest.gd`'s `sky reserve` gate is re-pointed at the new `world_height_blocks`
derivation.

### 1.2 The clamp becomes a ramp

`terrain_generator.gd:height_at_block` and `gdext/src/height_tiles.cpp`'s
`raw_height`, **in the same commit and transcribed line for line**: the final
`clampf(h, min_altitude, max_altitude)` becomes the soft knee of Q18, quantised
to 1/1024 as the last step on both legs. `height tile parity` is the gate and
it runs before anything else in 1.3.

### 1.3 Checks

- `height tile parity`: 10,000 samples, **0 differing**, both legs. This is
  checked FIRST; a divergence here makes every number after it meaningless.
- The truth line, seeds 42 and 7, twice each: identical within a seed. **It has
  moved from Stage 0's and that is the stage.** Both lines in the status doc.
- **The slope share**: past 55 deg and past 60 deg, before and after, seeds 42
  and 7. **Within 2 points, or failure protocol item 5.**
- No summit is flat: the highest 200 cells on each seed, the count whose eight
  neighbours are all within 0.01 blocks. **Zero**, or item 6.
- `grep -rn "world_height_blocks" scripts/ gdext/` - nothing allocates from it
  (Q16). Recorded either way.
- Relief measured: `max(surface) - min(surface)` over the 24 km disc, against
  Q1's target. RECORD.
- Tour `wt-1`: `2-summit`, `6-postcard`, `17-rim`, `30-horizon-peak`. **The eye
  check is the whole stage: is this a real-sized Alps?** One sentence.
- The sprint probe: RECORD against the baseline. Not a gate yet - Stage 8 is.
- Commit `feat(world-truth): stage 1 - real relief, one ratio, and a summit that does not go flat`.

---

## Stage 2 - Zones that mean the same thing everywhere

**Budget 4 h.**

### 2.1 The bands

`worldgen_config.gd` gains `zone_band_altitudes: PackedFloat32Array` (six
values, metres, in `PROPERTIES`) with the section 3 table as its default and a
comment carrying the bible's own zone table beside it.
`terrain_generator.gd`: `_resolve_zone_thresholds`, `_thresholds_from` and
`_measure_zone_shares` are **deleted**; `zone_thresholds` is filled from the
config in blocks at construction. `zone_at`, `zone_band`, `surface_zone_at`,
`_slope_zone`, the jitter and the dither are **unchanged** - only where the six
numbers come from changes. `ZONE_HISTOGRAM_BUCKETS`, `ZONE_SAMPLE_STRIDE`,
`ZONE_CORRECT_ROUNDS` and `ZONE_CORRECT_STRIDE` go with them.

`_measure_zone_shares` is **not** deleted outright - it is moved to
`worldgen_probe.gd` as a **measurement**, because "what did the bands actually
produce" is exactly the question the shares used to answer by construction and
now have to answer by being read.

`build_heightmap()` loses its `_resolve_zone_thresholds()` call and about 13
seconds of load (distance v5's measurement), which is recorded.

### 2.2 The consumers

Everything that reads `zone_band` keeps working by construction, and the list is
finite: `tree_placement.gd:609, 631, 918` (the forest band and the krummholz
band - **the tree line**), `tree_field_job.gd:402` (the snow dust on a crown),
`flora_placement.gd`'s per-zone tables, `find_spawn`'s rock altitude,
`far_field_job.gd`'s colour convergence and its C++ twin. **Each is opened and
read, not assumed**, and any that scaled a hard-coded altitude is fixed here.

### 2.3 Checks

- The truth line, both seeds: moved, identical within a seed.
- The measured shares on the 24 km disc, both seeds, against the old
  4/30/26/14/10/11/5. **RECORD, never a gate** - the shares are an outcome now.
- The tree line's altitude read back out of `zone_band(ZONE_FOREST)`: within
  1 m of the authored 1,900. GATE.
- **Zone stability across distance, which is the whole reason for the stage**:
  the zone id at 200 fixed positions, sampled at 1 km, 10 km and 30 km from the
  capital, is a pure function of altitude and jitter - assert that two positions
  at the same altitude and jitter in different rings get the same zone. GATE.
- `9-treeline`, `6-postcard`, `2-summit` at `--lens off --set tree_sway=0`
  against `wt-1`: the tree line has moved and the forest belt is thicker. Eye
  check, one sentence. Confetti check on the flats (`4-valley-floor`): the
  dither must not read as salt and pepper at the new blend band.
- Commit `feat(world-truth): stage 2 - the zones are altitudes, and the tree line is a number`.

---

## Stage 3 - Rings from the capital

**Budget 3 h.**

### 3.1 The field

`worldgen_config.gd`: `capital_block_x`, `capital_block_z` (both 0),
`ring_radii_m` (five values, `PROPERTIES`).
`terrain_generator.gd`: `wildness_at` is rewritten to Q5-A, its long comment
about the ordering problem with spawn **replaced** by the new reason (a ring
field must be readable by a worker on a tile 30 km out, so it cannot be found);
`ring_at(bx, bz) -> int` is added beside it; `danger_at` is deleted.
`gdext/src/height_tiles.cpp`'s own `wildness_at` is changed in the same commit -
it is one of the eight fields `raw_height` reaches for and a divergence here is
two different mountains.

`scripts/ui/hud.gd`: `_danger_at_m` reads `ring_at / 4.0`, with a comment saying
D35 makes threat a function of the current campfire and that this is the stand-in
until phase 3.

`worldgen_probe.gd` prints the ring at spawn, at the capital and at 5, 15 and
30 km.

### 3.2 Checks

- `height tile parity` **first**: 0 differing. The two `wildness_at`
  implementations must agree or the world has two shapes.
- The truth line, both seeds: moved, identical within a seed.
- `wildness_at` at the capital is 0.0, at 24 km is 1.0, monotonic along 8
  bearings at 100 m steps. GATE.
- `ring_at` boundaries land exactly on the radii, both legs. GATE.
- **The wildness ramp is visible and it was not before**: `mountain_amp`'s
  `wildness_relief` boost and `rock_slope_deg - wildness_rock_deg` sampled at
  1, 6, 12 and 24 km. RECORD the four values - horizon v1's silence 1 says
  everything past 3 km has been at 1.0, so this is the first time the ramp has
  had anywhere to ramp.
- `31-horizon-far` and `30-horizon-peak`: more bare stone with distance from the
  capital, and it is a gradient rather than a step. Eye check.
- Commit `feat(world-truth): stage 3 - wildness is distance from the capital, and danger waits for the fire`.

---

## Stage 4 - Lakes anywhere, found once per region

**Budget 6 h. The hardest stage.**

### 4.1 The region

`lakes.gd` stops taking a `Heightmap` and taking its `cells`. It takes a
**region key** `(rx, rz)` and the tile store, floods `lake_region_tiles + 2 *
lake_apron_tiles` squared tiles of level-0 cells built on demand, seeds from the
apron's outer border exactly as `_seed_border` seeds from the map border today,
and publishes `water`, `lake_id`, `shore_level` and `shore_near` **for the
interior only**. The bucket queue, the fixed neighbour order, the LIFO within a
bucket and the "nothing iterates a Dictionary" rule are carried over verbatim -
that block of `lakes.gd`'s header is the determinism argument and it does not
change because the extent did.

`LakeStore` (new, in `lakes.gd`) holds computed regions keyed `(rx, rz)`, built
on demand under a mutex, evicted beyond twice the voxel radius, exactly as
horizon v1's tile store is. `TerrainGenerator._cell_index` - which returns -1
outside the region and whose callers already read that as "no shore here" - is
replaced by a lake-store lookup that answers everywhere.

`lake_max_depth` to Q8's answer.

### 4.2 The consumers

`detail_at`'s shore fade, `flora_placement` and `tree_placement`'s shore rules,
`World._update_fog_floor`'s LAKE branch (horizon v1 left its region index guard
in place as silence 4 - **it is removed here**), `find_spawn`'s water tiles,
`Lakes.build_water_arrays` and the water mesh. Each is opened and re-pointed.

### 4.3 Checks

- The truth line, both seeds: moved, identical within a seed. **The water level
  is in the hash, so this stage's correctness is inside the line.**
- **Determinism across region order**: compute region `(0,0)` first, then
  `(1,0)`, then in the reverse order in a fresh process; the water level at
  10,000 cells in each is byte-identical. GATE, and it is the stage's real gate.
- **Determinism across threads**: one region built by four workers at once
  equals one built on the main thread. GATE.
- **The border**: 1,000 cells straddling a region boundary - the water level
  from the region on each side agrees to 0.0 for every cell that is not inside a
  lake that reaches the apron. GATE. The count of lakes that DO reach the apron:
  RECORD, and if it is not zero on either seed, `lake_apron_tiles` is the
  tunable.
- Lakes counted in the 24 km disc, both seeds; the deepest lake in metres; the
  count of **tarns** (a lake above the tree line) and **valley lakes** (below
  the meadow/forest line). RECORD - this is Q8's second half answered with
  numbers.
- **B7 closes or it does not**: `5-lake` and `6-postcard`, a 9 x 9 window in the
  deepest part of the largest lake, against the bible's deep `#265f6e`. GATE at
  |dH| <= 10, |dV| <= 12; if it fails at 40 blocks, record the measured depth
  and the reached colour and say so - that is the answer B7 asked for either way.
- `10-shore`: no shoreline broken into islands at the new depth. Eye check.
- Region flood time and memory, per region, median and worst. RECORD.
- Commit `feat(world-truth): stage 4 - lakes are found per region, on any box, and there is deep water`.

---

## Stage 5 - Spawn by the vista rule

**Budget 3 h.**

### 5.1 The search

`find_spawn` stops scanning `heightmap.cells` and scans a **disc of radius
`spawn_search_m` around the capital** on the level-0 tiles, on the same every-
fourth-cell stride. The slope, water and zone criteria are unchanged;
`spawn_mountain_m` is **replaced** by the vista test of section 3 (a summit
between 8 and 30 degrees), evaluated with the same code path as `vista_probe`
so the two cannot disagree. `spawn_center_fraction` is deleted - it existed only
because wildness was measured from the map centre, and Q5 fixed that.

The summed-area tables over `mountain_tiles` and `water_tiles` are kept and
built over the disc rather than the region.

### 5.2 `column_surface_range`

Moved to a candidate for C++ in Stage 6 and left in GDScript here, but its five-
by-five sample loop is checked against the new relief: at 2,300 m of span a
chunk's 16-block footprint can hold far more altitude than before, and
`detail_amp` as the margin is unchanged. **Measured: the count of columns where
the true min or max falls outside the returned range**, over 10,000 columns.
Zero, or the sample stride is wrong at this relief and that is a finding.

### 5.3 Checks

- The truth line, both seeds: moved (spawn is in it), identical within a seed.
- Spawn passes the vista gate on both seeds. GATE.
- Spawn slope <= 8 deg, water within 600 m, not inside a lake. GATE.
- `find_spawn` twice in one process and once in a fresh one: same block. GATE.
- `column_surface_range` containment: 0 of 10,000. GATE.
- `1-spawn` and `16-spawn-postcard`: **this is the first frame of the game at
  real relief.** Eye check, one sentence, and it is the sentence Marcel reads
  first in the morning.
- Commit `feat(world-truth): stage 5 - spawn is chosen by the vista rule, not by the map centre`.

---

## Stage 6 - The generator's truth in C++

**Budget 8 h. A port. It may not change the world.**

### 6.1 `KubikWorldTruth`

`gdext/src/world_truth.{h,cpp}`, new, registered in `register_types.cpp`.
`setup(Dictionary)` takes the config, the jitter noise ref and the capital and
ring table once per world, exactly as `KubikHeightTiles::setup` does. Methods,
each transcribed from its GDScript original line for line, with the same
`double` discipline and the same quantisation:

- `zone_at`, `zone_band`, `surface_zone_at`, `_slope_zone`, `zone_jitter_at`;
- `ring_at`, `wildness_at`;
- `column_range(chunk_x, chunk_z)` - the 5 x 5 sample of Stage 5;
- `flood_region(rx, rz)` - the priority flood, returning `water`, `lake_id` and
  the lake table as arrays. **The bucket queue is transcribed, not improved**:
  the LIFO within a bucket and the fixed neighbour order are the determinism
  contract, and a `std::priority_queue` would be a different world.

`KubikHeightTiles` gains nothing but a `column_range` accessor.

### 6.2 The twins

Each GDScript original is kept for the duration of its own parity test and
**deleted in this stage's final commit** (Q22, D49), replaced by the recorded
reference vectors the parity harness now compares against.

### 6.3 Checks

- **`truth` is byte-identical to Stage 5's**, both seeds. This is the gate and
  there is no tolerance: a port that changes the world is a bug, and from here
  failure protocol item 2 has no exceptions.
- `truth parity` (new, in the world-truth self-test): 10,000 samples x 6
  functions, 0 differing, C++ against the recorded GDScript reference vectors.
- Lake parity: one region, both legs, `water` and `lake_id` byte-identical over
  every cell.
- Load time before and after: `build_heightmap` plus the first four lake regions
  plus spawn. RECORD - distance v5 measured 17.5 s of lakes, ~13 s of zone
  thresholds and `column_surface_range` as the three that stood between this
  project and finer cells, and this is the stage that answers all three.
- The far probe, twice, identical. The sprint probe: RECORD.
- Commit `feat(world-truth): stage 6 - zones, rings, lakes and the column range in C++, and the twins are gone`.

---

## Stage 7 - The vista rule, measured

**Budget 3 h.**

- `vista_probe` over the section 3 vantages, seeds 42 and 7, twice each. The
  pass share, the median best angle, the worst vantage by name, and the
  histogram of best angles in 5-degree buckets. **GATE at 80%**; failure
  protocol item 7 says what a failure means and what it does not.
- The landmark half of D45 is written into the status doc as phase 4's inbox,
  in one paragraph, with the arithmetic a landmark needs to satisfy it (a
  landmark 90 to 180 m tall must read as a silhouette from 2 km, which is
  2.6 to 5.2 degrees of frame).
- `17-rim` is re-aimed: from the summit, 3 km out and **`0.5 x local relief`
  down** rather than 120 m. `31-horizon-far` is re-aimed to a point at Q4's
  ring-1 outer radius rather than a fixed 20 km, and the reason is recorded.
- The three shots that carry the stage: `6-postcard`, `17-rim`, `2-summit`, at
  day, lens on. **The eye check is D45's own sentence**: does a whole mountain
  fit in frame from the places a fire goes?
- Commit `docs(world-truth): stage 7 - the vista rule measured, and the landmark half handed to phase 4`.

---

## Stage 8 - What it costs

**Budget 3 h.**

- The sprint probe, three runs, Ultra, quiet box, against horizon v1's Stage 7
  line. Median, p99, worst, over-25 count, chunks, far rebuilds, tree rebuilds,
  tiles, memory. **GATE at within 10% of horizon v1's median**; failure protocol
  item 9.
- The far probe: vertices per ring at Ultra against horizon v1's Stage 3 table.
  **GATE at within 5%** (Q15). If it is not, the derivation moved the slope and
  Stage 1's gate missed it - say so.
- Chunks per column and chunks in a 60 s sprint, against the baseline. **Within
  10%** (Q16).
- Height-tile and lake-region memory at spawn and at `--tp 20000 0`.
- **The traversal numbers Q11 asks for**: valley floor to the nearest summit in
  seconds at sprint; the 24 km ring-1 crossing in minutes; the share of ground
  past 40, 55 and 60 degrees; and whether `traversal_probe` wedges. RECORD, all
  of it, and it goes in the morning message as its own block.
- The valley-fog bands and the fog floor re-based on local relief (Q17), judged
  on `4-valley-floor` and `6-postcard`, before and after, with the numbers.
- `directional_shadow_max_distance` confirmed unchanged at 250 m and recorded as
  a known limitation at this relief (a mountain's shadow is kilometres long and
  the game draws 250 m of it) - **a finding for a later lane, not a fix here**.
- Commit `docs(world-truth): stage 8 - the cost of a real-sized Alps`.

---

## Stage 9 - Two boxes, the docs, and the merge

**Budget 2 h.**

- **The two-box parity.** `--truth` for seeds 42 and 7 on ganymede and, by
  Fable, on Marcel's Windows box after rebuilding the Windows library.
  **Identical strings, or failure protocol item 10 and no merge.** The result is
  the first line of the morning message.
- The `@export` audit against `PROPERTIES` and `LOCAL_PROPERTIES`, line by line
  (Q25). Recorded in full, whatever it finds.
- `README.md` § 5 and § Running it: the truth probe, the vista probe, the lake
  regions, the new canonical line, and the deletion of the home region as a
  concept. `worldgen_config.gd`'s comments that still say "the map", "the
  region", "1:4", "quarter-scale": rewritten to what is true.
  `docs/DESIGN.md` § Scale, § the resolution ladder and § Traversal: the 1:4
  paragraphs are the largest stale block in the repo and this lane is what makes
  them false - **rewritten here**, since D56 means nobody else will.
- `docs/status/world-truth-v1.md` complete, with "For Marcel", "Questions taken
  alone", "For phase 3 and 4" (the landmark half of the vista rule, the campfire
  `danger_at`, the shadow distance, traversal) and "For the bible".
- `STATUS.md`, `TODO.md`, `RECONCILIATION.md` § 9 and `CLAUDE.md` § Working
  order: updated, because this lane is the last one whose landing changes what
  the project's own documents say the world is.
- Commit `docs(world-truth): status, the two-box proof, and the documents that said 1:4`.
- Then Q13's merge, if and only if the two-box parity is green.

---

## 6. The status doc and the morning message

`docs/status/world-truth-v1.md`, in the shape of `light-v1.md` and
`horizon-v1.md`, updated at the end of **every stage** with, per stage: what
shipped; **the truth line for both seeds**; the slope line; the far probe's
table; the sprint probe's summary; every tunable changed (was / now / shot or
probe); the sampled checks with region coordinates and measured values, GATE or
RECORD; eye checks passed or failed with the sentence; "Questions taken alone";
"For Marcel"; "For phase 3 and 4"; "For the bible". At the top, before anything:
any BLOCKING finding, and **the unbound DESIGN rows if any were left unbound**.

The final message to Marcel, in this order and nothing else first:

1. **The two-box parity**: PASS or BLOCKING, with both truth strings. Then
   `feat/world-truth-v1`'s last commit; which stages are green, which were
   wrapped early, which reverted. **The Windows library must be rebuilt by
   Fable before anything is judged on the 5080, and in this lane that is not
   cosmetic: a stale library is a different world.**
2. **The new canonical line**, seeds 42 and 7, beside the old one, with the
   sentence: this is the break, and it does not happen again.
3. **The relief, as measured**: valley floor, peaks, span, massif width, the
   slope shares before and after, and whether a summit ever goes flat.
4. **The vista share** and the worst vantage. Then the three shots to open
   first: `6-postcard`, `2-summit`, `1-spawn`, day, lens on, and the `17-rim`
   pair before and after.
5. **B7**: closed or not, with the measured depth and the measured colour.
6. **Traversal at real relief**, the block of numbers from Stage 8, flagged as
   a decision Marcel owns and this lane did not take.
7. The cost line: the sprint median against horizon v1's, far vertices, chunks,
   memory. PASS or BLOCKING.
8. Every "For Marcel" item, one line each.
9. Every item handed to phase 3 and phase 4, one line each.
10. Every tunable moved off its start, one line each.
11. What is left.
