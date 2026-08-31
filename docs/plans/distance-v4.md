# Distance v4 - the far mesher crosses to C++

Written 2026-09-01, just after midnight, against the evening's block-lattice
ruling (see `worldgen_config.gd` at `far_step_y_blocks` and `far_ring_div`).
Target: **ganymede, one night, unattended, branch `feat/distance-v4`**. The
agent executing this plan reads **How to use this document** before its first
edit.

**What this night is for, in one line:** the far country finally has the look
Marcel ruled for - flat cells on the block lattice, full vertical resolution,
grain on top - and it costs 20-40 seconds a rebuild in GDScript, which is the
whole game's worst number. Tonight the mesher becomes C++ and the number
becomes milliseconds, so `far_ring_div 4` (1 m far cells) can stop being a
screenshot mode.

**Where this sits in the larger C++ transformation.** Marcel has approved
moving the hot loops to a GDExtension in this order, one epic per rung:

1. **The far mesher** - tonight. Self-contained, look-only, no world truth,
   parity-checkable against a reference implementation that stays in-tree.
2. **The chunk mesher** (`chunk_mesher.gd`) - next. Same shape of problem,
   larger blast radius: it feeds gameplay collision meshes.
3. **Worldgen** (`terrain_generator.gd`, `heightmap.gd`, lakes) - after that,
   and only with the determinism harness extended first: this rung touches
   world truth, and "both machines generate identical terrain" is hard rule
   zero of the whole project.
4. Flora scatter and the impostor forest, if the instruments still say they
   are worth it.

Rungs 2-4 are OUT OF SCOPE tonight. They are named so the seams cut tonight
(where the library lives, how parity is proven, how CI builds it) are cut
where the next rungs need them.

---

## Decisions this plan makes

1. **The GDScript mesher is the reference, not the casualty.**
   `far_field_job.gd` stays in-tree, byte-untouched except where this plan
   names an edit, and the self-test asserts the C++ mesher reproduces its
   output. Two implementations is the price of a fallback that keeps the
   game playable on a machine with no compiler (Marcel's co-op partner, a
   fresh checkout, CI's export step before the lib exists) - and the parity
   gate is what stops the price becoming drift.
2. **The boundary is data in, arrays out.** The C++ class never holds a
   reference to `Heightmap`, `TerrainGenerator`, `WorldgenConfig` or `Look`,
   and never calls back into GDScript during a build. Setup hands it the
   heightmap pyramid (each level a `PackedFloat32Array` plus dims), the
   world constants, and whatever zone/colour tables Stage 4 decides; every
   `build()` hands it the centre, the frontier and a Dictionary of the live
   far knobs. Cross-language calls per cell are how a 30x speedup becomes
   1.5x, and forbidding them at the seam is cheaper than measuring them out
   later.
3. **Parity is exact, or it is recorded per stage with a reason.** Both
   meshers compute in doubles and store into 32-bit packed arrays. On the
   same libm the same expressions round the same way, so the default gate is
   IDENTICAL arrays - same counts, zero max component diff. Where a stage
   cannot hold that (a transcendental reassociated by the optimiser, say),
   it drops to `<= 1e-4` blocks max diff, and the status doc records which
   stage, which expression, and the measured worst diff. "Roughly equal" with
   no reason recorded is a failed gate.
4. **The zone and colour question is answered by reading, not guessing.**
   The mesher's per-cell calls out of its own file are `backdrop_zone()`,
   `band_color()` / the `Look` ramp maths, and `Block.color_of()`. Stage 4
   reads them and takes the first rung that holds: (a) if they are pure
   functions of altitude, slope-from-pyramid, hashes and config scalars -
   port them, with a 10,000-random-sample parity micro-gate per function;
   (b) if they reach into noise objects or state that cannot be handed over
   as plain arrays - precompute a per-cell zone grid in GDScript ONCE per
   world load into a `PackedByteArray` handed to `setup()`, cost measured
   and printed at load. Either rung keeps decision 2 intact. Record the rung.
5. **`far_ring_div` defaults to 4 only if the night earns it.** The flip
   ships in the last stage, gated on the measured C++ rebuild at div 4 on
   this box being under 1.5 s wall. Marcel's own machine reads his saved
   `user://worldgen.tres`, so the flip is for fresh checkouts and the
   partner; his morning knob is his own. If the gate fails, the default
   stays 2 and the number goes in the status doc.
6. **The geomorph rides along only if the port lands early.** Items 9 and 18
   (the loud 400/960/1920 m ring boundaries; two rings sampling the cell
   height at different world points) have a known fix: blend the SAMPLE
   POSITION from the fine ring's cell centre to the coarse ring's across the
   last two cells before a boundary. It is Stage 9, explicitly optional,
   implemented in BOTH meshers in the same commit or in neither - parity
   outranks the artefact.
7. **Branch posture.** `feat/distance-v4` from tonight's `main`. One commit
   per stage minimum, push after every stage. Merge to `main` at the end of
   the night ONLY with every gate green including the full self-test and a
   stream probe at div 2 and div 4 with holes 0; otherwise the branch and
   the status doc are the deliverable and the morning decides.
8. **Nothing in C++ decides world truth.** The library is look-only. It
   reads a pyramid someone else built and emits triangles. If a stage finds
   itself wanting to port a function that WRITES anything the game state
   reads, that stage is out of scope and the finding goes in the status doc.

## Hard rules

1. The game must run, play and pass every existing self-test on a checkout
   with **no compiled library** - the class-exists check falls back to the
   GDScript job, and the only trace is one load warning and an F3 line
   reading `far mesher: gdscript`.
2. The parity gate of decision 3 runs at EVERY stage that touches mesh
   output, in the self-test, headless, exit non-zero on failure.
3. Holes 0 in the stream probe, both legs, at `far_ring_div` 2 AND 4, before
   any merge to main.
4. `far_field_job.gd` is edited only where this plan says so (the class-
   exists dispatch does not live there; `far_field.gd` owns it). The far
   probe and self-test may gain code; they may not lose assertions.
5. No new global state. The C++ class is a `RefCounted` owned by `FarField`,
   one instance per world, freed with it.
6. Every number quoted in the status doc says which box, which target
   (editor/template), and single-run or interleaved. This repo has been
   burned by single-run comparisons twice; see `STATUS.md` item 5.

---

## How to use this document

**Environment.** Ganymede, headless Linux, binary at `~/bin/godot` (4.7.2).
The repo checkout is the usual one; `git fetch && git checkout main && git
pull` first, then branch. After any pull that adds a `class_name`:

```bash
G=~/bin/godot
$G --headless --path . --import
```

Everything headless; only tour shots (Stage 8's far-band A/B) render, via
`xvfb-run -a`. Outputs under `build/`.

**Toolchain bring-up is Stage 0, and it is allowed to install things:**
`clang` or `gcc` (either is fine), `scons` (apt or pip), and a sibling
checkout of godot-cpp `master` at `../godot-cpp` (relative to the repo root;
`GODOT_CPP` env var overrides the path - see `gdext/SConstruct`):

```bash
cd .. && git clone --depth 1 https://github.com/godotengine/godot-cpp.git
cd godot-cpp
~/bin/godot --headless --dump-extension-api   # writes extension_api.json for EXACTLY 4.7.2
scons platform=linux target=editor custom_api_file=extension_api.json -j$(nproc)
cd ../<repo>/gdext
scons platform=linux target=editor custom_api_file=../../godot-cpp/extension_api.json -j$(nproc)
```

The scaffold already in-tree: `gdext/` (SConstruct, `src/far_mesher.{h,cpp}`
stub with `ping()` and `bench_sum()`, `src/register_types.*`),
`kubik.gdextension` at the repo root, `gdext/check.gd` (a `-s` script that
proves load and prints the bench). **`kubik.gdextension` has macOS and
Windows entries but NO linux entries yet - adding
`linux.editor.x86_64` / `linux.template_debug.x86_64` /
`linux.template_release.x86_64` under `res://gdext/bin/` is part of Stage 0.**
Verified on Marcel's Mac tonight: class loads, `ping()` answers, the trivial
bench is 17x - treat that as a floor, not a target; the mesher's call-heavy
loops should clear 30x.

**Reading order before the first edit:** this file whole; `CLAUDE.md`;
`README.md` § Architecture and § Running it; `scripts/world/far_field_job.gd`
TOP TO BOTTOM (1,700 lines - budget the hour, it is the thing being ported
and every comment in it is a war story); `scripts/world/far_field.gd` whole;
`scripts/world/heightmap.gd` (the pyramid being marshalled);
`scripts/world/look.gd` band/ramp section; `world.gd` far-field hooks
(`request_rebuild` sites, `far_field_exclusion_m`); `scripts/tools/selftest.gd`
far-terrace test (the harness Stage 1 extends); `scripts/tools/far_probe.gd`
header comments; `STATUS.md` items 9, 11, 17, 18.

**The stage discipline is the creatures/ui plans' one:** a stage is a commit
(or several), every stage ends with the self-test green and a push, and a
stage that cannot meet its gate STOPS THE LANE - write the status doc up to
that point rather than improvising past a red gate.

---

## The stages

**Stage 0 - the toolchain proves itself.** Bring-up above; linux entries in
`kubik.gdextension`; `$G --headless --path . -s gdext/check.gd` prints
`class exists: true`, the ping and the bench. Gate: exit 0 from that script
and from the full self-test (which today knows nothing of C++ and must stay
green to prove the .gdextension load breaks nothing headless).

**Stage 1 - the parity harness exists before the port.** Extend the
self-test: build the far mesh for the self-test's small world through
`FarFieldJob` (GDScript) and through the C++ path, compare - counts equal,
max component diff printed, gate per decision 3. Tonight the C++ path is the
stub, so the harness runs with the comparison SKIPPED and prints
`far parity: c++ mesher absent/stub, 0 checks` - the point is the harness is
in and wired before any port code exists, exactly like ui-v1's shot harness,
and for the same reason: it catches the class of bug the numbers cannot.

**Stage 2 - the pyramid crosses.** `setup()` marshals the heightmap levels;
port `height_filtered` / `height_max_filtered` and the peak-gain expression.
Micro-gate: 10,000 random (x, z, level) triples, C++ vs GDScript, exact.

**Stage 3 - geometry without colour.** Port the ring walk, `_cell_h`,
`_cell`, `_is_ridge`, the terrace/step-y quantisation, seam fade, risers,
skirts, curtains, the frontier per-sector exclusion - emitting positions and
normals only, colours all white. Parity gate on vertex positions and counts
against a GDScript run with colours ignored. This is the largest stage;
commit in slices (ring walk / terrace cache / risers / skirts) if that keeps
each gate small.

**Stage 4 - zone and colour cross, by the ladder of decision 4.** Whichever
rung, the micro-gates per function, then the full parity gate goes
colour-inclusive. From here the harness's comparison is UNSKIPPED and total.

**Stage 5 - the dispatch.** `far_field.gd` builds through the C++ mesher
when the class exists, GDScript otherwise; the F3 readout gains
`far mesher: c++/gdscript`; a `far_cpp` LOCAL knob (F4, 0/1, default 1,
`FAR_ONLY_PROPERTIES` so it redraws in place) forces the fallback for A/B in
a running game. Gate: self-test green BOTH ways - once as-is, once with the
knob forcing GDScript.

**Stage 6 - the numbers.** On this box, editor target, interleaved ABAB
three runs each: full-region rebuild wall time, GDScript vs C++, at
`far_ring_div` 2 and 4; the load-time zone-grid cost if rung (b) was taken;
the main-thread `arrays_to_mesh` upload cost at div 4's vertex count,
measured separately (it is STATUS items 11/17 and tonight's port does not
fix it - get its number on the record so the morning can decide if it is
next). Also `bench_sum`-style honesty: state the speedup the port actually
achieved, not the one this plan predicted.

**Stage 7 - the probes.** Stream probe at div 2 and div 4, both legs, holes
0 (hard rule 3); far probe geometry rows identical C++ vs GDScript; the
worldgen probe untouched and identical to main (nothing about the world
moved - print the heightmap hash to prove it).

**Stage 8 - the far band photographed.** `xvfb-run -a` tour, one label per
mesher, same seed; the far band (rows 0-300, the bit-stable band per STATUS
item 13a) diffed EXACTLY between the two labels. Zero differing pixels is
the gate; it is the parity gate made visible, and it is cheap.

**Stage 9 - OPTIONAL, the geomorph.** Decision 6. Only if Stages 0-8 are
green with hours left. Both meshers, same commit; far probe's ring-boundary
fizz table before/after in the status doc; the parity and far-band gates
re-run.

**Stage 10 - the landing.** Decision 5's conditional default flip; STATUS.md
gains the distance-v4 entry at the top pointing at
`docs/status/distance-v4.md` (write it in the repo's voice: what shipped,
five things worth reading, what got worse, open items - and carry items 11/17
forward with tonight's upload numbers); TODO.md's distance lane updated;
merge to main per decision 7 and push. If the merge conditions are not met,
push the branch, write the status doc anyway, and say plainly in it what is
red and why.

## What the morning should find

`main` (or, failing gates, `feat/distance-v4`) with: the far mesher in C++
behind a live fallback; parity proven three ways (arrays, probe rows, far-band
pixels); rebuild times that make `far_ring_div 4` playable; the upload cost
measured and on the record; a status doc Marcel can read in five minutes; and
nothing about the world moved - same heightmap hash, same spawn, on every
stage.
