# Distance v5 - the far country gets real data, and stops costing frames

Written 2026-09-01, mid-morning on gemini, the day after distance v4 merged.
Target: **ganymede, one night, unattended, branch `feat/distance-v5`**. The
agent executing this plan reads **How to use this document** before its first
edit.

**What this night is for, in one line:** v4 made building the far country
nearly free and turned its detail up 4x - and that surfaced the three things
now between the game and the far country Marcel envisioned: a 224 ms
main-thread freeze every time the walk triggers a rebuild, terrain drawn from
a height map with less information than the mesh asking for it, and ring
boundaries that shimmer. Tonight the uploads get a budget, the height map
gets real resolution in tiles, and the boundaries go quiet.

**Scope ruling (Marcel, 2026-09-01, this morning's session):** TREES ARE OUT.
A parallel lane owns trees v2 (`docs/plans/trees-v2.md`). The only permitted
`FarTrees` edits are Stage 2's debounce and feeding its existing uploads
through Stage 1's budget - minimal diffs, no reshaping, so the trees lane
inherits a fixed bug and a budget hook, not a merge conflict. Marcel also
ruled: skip the judge-against-the-poster step this cycle - the gates below
replace eyeballing - and the same-seed world change from Stage 5 is
**accepted in advance** (lakes and spawn shift; it is recorded, not asked
again).

**Where this sits in the C++ ladder** (v4's ordering, updated): rung 1 (far
mesher) landed. Tonight takes a deliberate half-step onto rung 3 - the
HEIGHT MAP only, not the chunk generator - because the far country's detail
ceiling is the height map's data, not the mesh. The chunk mesher (rung 2)
stays untouched and out of scope.

---

## Decisions this plan makes

1. **The uploader is a mechanism, not a patch.** One small main-thread
   budgeted uploader, owned by `World` or `FarField` (executor's choice,
   recorded), through which every far-system mesh handover flows: the far
   field's `arrays_to_mesh` and `FarTrees`' multimesh commits. Budget
   `far_upload_budget_ms` (F4, default 4.0) per frame; work is sliced and
   queued, and a slice never splits below one sector. The far field's mesh
   becomes per-sector (or per-ring - whichever slices cleaner, recorded)
   RenderingServer meshes swapped atomically only when every slice of a
   build has landed - a rebuild in progress shows the OLD complete far
   country, never a mixed one.
2. **Parity doctrine is unchanged, and it now has three subjects.** Any
   change to far-mesh output lands in BOTH meshers in the same commit or in
   neither (v4 decision 6's rule, now general). The slicing of decision 1
   must not change the union: the parity harness compares the concatenation
   of slices in a defined sector order against the reference whole-mesh
   build, arrays exact per v4 decision 3. The geomorph (Stage 3) and the
   detail layer (Stage 6) are mesh-output changes and carry the full gate.
3. **The height map crossing is guarded by quantisation, because of hard
   rule zero.** "Both machines generate identical terrain" outranks speed.
   This morning proved gcc and MSVC round the same expressions one ULP
   apart (see `docs/status/distance-v4.md`, the Windows addendum) - and the
   height map, unlike the far mesh, IS world truth: spawn and lakes are
   computed from it. So: the C++ tile builder QUANTISES every output height
   to 1/1024 block as the last step, the GDScript reference does the same
   (one edit, same commit), and the micro-gate is hash-EQUAL - not close -
   between C++ and GDScript on ganymede. The cross-box half (ganymede hash
   == gemini hash, gcc vs MSVC) cannot run tonight; the selftest gains the
   canonical-seed hash test, THIS MORNING'S SESSION runs it on gemini after
   the merge, and until that proof no co-op session mixes the two builds.
   If quantisation at 1/1024 cannot make ganymede's C++ equal ganymede's
   GDScript, the ladder falls to: world truth (spawn, lakes) reads the
   GDScript tiles; the C++ tiles feed only the far-field pyramid
   (look-only, v4 doctrine). Record the rung taken.
4. **Tiles, because the world is unbounded.** The height map becomes
   regional tiles (edge length in blocks, config knob, default sized so
   today's region is a small grid of tiles - executor picks the size that
   keeps a tile build under ~100 ms and records it). No new code may assume
   a global extent, a world edge, or one array covering everything
   (`CLAUDE.md` § Worldgen guidance). Today's 3 x 3 km region simply
   becomes "these tiles exist"; the pyramid builds per tile with a
   one-tile-ring apron so filtering does not see seams. Lakes and spawn
   read through the same accessors they read today - the tiling is invisible
   above `heightmap.gd`'s API or it is wrong.
5. **Resolution doubles tonight, and the next doubling is a knob.** Base
   cell 2 blocks -> 1 block (4x the data). With tiles and C++ this is the
   conservative step that must land well; the tile framework makes a
   further step config, not code. Startup gate in Stage 5 holds it honest.
   The far mesher's detail layer (Stage 6) covers what is finer than 1
   block, so chasing 0.5 m data tonight buys little and risks the night.
6. **The detail layer is look-only and world-space.** Analytic noise added
   by the mesher (both meshers, decision 2) beyond the pyramid's information
   limit, in the far rings only, sampled in WORLD space so a cell's detail
   does not change when its ring does - the geomorph fix and this layer must
   not reintroduce each other's artefact. It never touches the pyramid, the
   voxel terrain, spawn or lakes: if the ground at your feet is asked, the
   answer comes from the same functions as yesterday.
7. **Branch posture and the merge.** `feat/distance-v5` from tonight's
   `main`. One commit per stage minimum, push after every stage. Marcel has
   asked for this branch MERGED to main by morning so he can test on
   gemini - so the merge is the goal, and it happens ONLY with every gate
   green including the full self-test both ways, stream probes at div 2
   and 4 with holes 0, and CI's selftest workflow green on the branch's
   final push. Gates red = branch pushed + status doc saying plainly what
   is red; do not merge a red night because the plan said "merge".
8. **Nothing in C++ decides world truth beyond decision 3's quantised
   tiles.** The far mesher stays look-only. The chunk generator, flora,
   lakes' algorithm, spawn's criteria: untouched tonight.

## Hard rules

1. The game runs, plays, and passes every self-test on a checkout with no
   compiled library - GDScript height map tiles and GDScript mesher, one
   load warning, F3 says `gdscript`. (The tiled GDScript height map build
   may be slower than C++; it may not be slower than today's.)
2. Self-test green at every stage boundary, headless, exit non-zero on
   failure; the CI selftest workflow must be green on the branch before any
   merge (push the branch and let it run; it builds the library itself).
3. Stream probe holes 0, both legs, div 2 and div 4, before merge.
4. Hard rule zero: same seed, same config -> same spawn, same lakes, same
   heightmap hash, on both legs (C++/GDScript) - proven on ganymede
   tonight, cross-box the next morning per decision 3.
5. `FarTrees` diffs limited to Stage 2's stated edits. The trees lane owns
   that file's future.
6. No frame-thread work without a budget: any new main-thread cost this
   night adds must flow through the Stage 1 uploader or be measured under
   1 ms and recorded.
7. Every number in the status doc says which box, which target, single-run
   or interleaved (STATUS.md item 5's lesson).

---

## How to use this document

**Environment.** Ganymede, headless, `~/bin/godot` (4.7.2),
`~/godot-cpp` at `26fb7ab` already built (v4's Stage 0), scons in
`~/.venvs/scons` symlinked at `~/bin/scons`. After pull:

```bash
G=~/bin/godot
git fetch && git checkout main && git pull
git checkout -b feat/distance-v5
$G --headless --path . --import
cd gdext && ~/bin/scons platform=linux target=editor \
  custom_api_file=$HOME/godot-cpp/extension_api.json -j$(nproc) && cd ..
$G --headless --path . -s gdext/check.gd   # class exists: true, or stop
```

Tours (Stage 7's A/B shots) via `xvfb-run -a`; outputs under `build/`.

**Reading order before the first edit:** this file whole; `CLAUDE.md`;
`docs/status/distance-v4.md` WHOLE including the Windows addendum and "For
Marcel to rule on" (items 1-3 are tonight's subjects; item 5's ULP finding
is why decision 3 quantises); `scripts/world/far_field.gd` (the dispatch and
`arrays_to_mesh` call sites); `scripts/world/far_mesher.gd` header (the
seam's contract); `gdext/src/far_world.h` and `far_build.cpp` (the C++ side
being extended); `scripts/world/heightmap.gd` TOP TO BOTTOM (the thing being
tiled); `world.gd` `_build_lakes` and spawn; `scripts/world/far_field_job.gd`
ring walk and seam band (the reference the geomorph edits);
`scripts/tools/far_probe.gd` and the fizz table it prints; `STATUS.md`
items 9, 11, 17, 18; `scripts/tools/selftest.gd` far tests (the harness
every stage extends).

**Stage discipline:** a stage is a commit (or several), every stage ends
with the self-test green and a push, and a stage that cannot meet its gate
STOPS THE LANE - status doc up to that point, no improvising past red.

---

## The stages

**Stage 0 - the instruments, before.** Bring-up above. Capture on ganymede,
editor target: sprint frame profile at div 4 (worst frame, count over 33 ms,
`--stream-probe` or the tour harness - whichever exists, recorded);
`[FarField]`/`[FarTrees]` rebuild wall+main-thread numbers; standing-still
60 s impostor rebuild count (the thrash's before-number, expect 70-120);
startup coarse-heightmap ms; far probe fizz table (expect 80/128/256 blocks
at the three boundaries). Gate: self-test green untouched, numbers in the
status doc. These are the night's before-pictures; nothing merges without
its after.

**Stage 1 - the uploader.** Decision 1. Far field first: sector-sliced
meshes, budget knob, atomic swap. Parity gate per decision 2 (concatenated
slices == reference build, exact); stream probe div 4 holes 0; sprint
profile: no far-upload frame over 33 ms and the 224 ms class gone.

**Stage 2 - the impostors calm down.** The debounce: `FarTrees` rebuilds
only when the centre moves past a hysteresis distance (knob, default from
measurement) or the loaded frontier actually changes its cell set - not on
every stream tick. Its multimesh commits join the uploader. Gates: standing
60 s -> 0 rebuilds; a full sprint -> rebuild count bounded and recorded; no
visual regression in impostor coverage (tour shot pair, same counts +-2%).
Diff kept minimal per hard rule 5.

**Stage 3 - the geomorph, both meshers.** STATUS items 9/18's carried fix:
blend the SAMPLE POSITION from the fine ring's cell centre to the coarse
ring's across the last two cells before each boundary - in
`far_field_job.gd` and `far_build.cpp`, same commit. Gates: parity exact;
far probe fizz table after - target max fizz under 16 blocks at 400 m (from
80.00), proportionate at the outer boundaries, and the real gate is the
table PRINTED next to Stage 0's; far-band A/B tour pixel-diff zero between
meshers. v4 Stage 9 carried the arithmetic; measuring is 11x cheaper with
`--far-probe --cpp`.

**Stage 4 - the height map crosses, tiled, exact.** Decisions 3 and 4, at
TODAY'S resolution: tile framework in `heightmap.gd` (API unchanged above
it), C++ tile builder in the extension, quantisation to 1/1024 block on
both legs, pyramid per tile with apron. Gates: heightmap hash equal -
GDScript-tiled vs today's main (the tiling changed nothing), then C++ vs
GDScript-tiled (the crossing changed nothing); spawn and lakes byte-equal
to main's on the canonical seed; startup coarse-map time recorded (expect
C++ well under today's 10.3 s / gemini's number; gate at under half);
self-test gains the canonical-seed hash test for the morning's cross-box
run.

**Stage 5 - the resolution.** Decision 5: base cell 2 -> 1 block through
the tile knob. The world changes on the same seed - ACCEPTED (see scope
ruling): record new spawn, lake count/area, heightmap hash; bump the
config hash so a stale client cannot co-op across it. Gates: startup
coarse-map wall ON GANYMEDE no worse than Stage 0's baseline despite 4x
data (C++ pays for the resolution, or the resolution waits); static memory
delta recorded and under +120 MB at ship config; far probe ROUGHNESS
before/after printed (the far country should measurably sharpen); stream
probes both divs holes 0.

**Stage 6 - the detail layer.** Decision 6: world-space analytic detail in
the far rings, both meshers, same commit, knob `far_detail` (F4, default
on, 0 restores tonight-minus-this). Gates: parity exact; fizz table NOT
worse than Stage 3's (the layer must be boundary-stable); far-band A/B
pixel-diff zero between meshers; a labelled tour pair far_detail 0/1 for
the morning's eyes - Marcel skipped the poster judging, so the shots are
evidence, not a gate.

**Stage 7 - the numbers and the probes, after.** Interleaved ABAB three
runs each where compared: sprint profile at div 4 (the night's headline:
worst frame before vs after), rebuild walls, startup, standing-still
impostor count, fizz table, memory. Stream probes div 2 and 4 both legs
holes 0 (hard rule 3). The far probe geometry rows C++ vs GDScript
identical. Full self-test both ways (library present; library moved aside).

**Stage 8 - the landing.** `docs/status/distance-v5.md` in the repo's
voice: what shipped, the before/after table, what got worse, the rung
decision 3 landed on, what the morning must run on gemini (the cross-box
hash command, verbatim); STATUS.md entry at top; TODO.md distance lane
updated (items 9/11/17/18 closed or moved); CI selftest green on the
branch; merge to main per decision 7 and push. Red gates = no merge, per
decision 7's last sentence.

## What the morning should find

`main` (or, failing gates, `feat/distance-v5` and an honest status doc)
with: no far-system frame over 33 ms in a sprint; the impostor ring quiet
when the player is; ring boundaries an eighth as loud; the far country
drawn from twice the data plus a stable detail grain; the world changed
once, on purpose, with its new numbers recorded; hard rule zero proven on
one box and one command away from proven on two; and the trees lane's
files exactly as its owner expects them.
