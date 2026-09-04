# Horizon v1 - the view to the horizon, and a world with no edge

The work order for the lane Marcel pulled to the front of the queue on
2026-09-04, written in the shape of `docs/plans/light-v1-tech.md` so that one
agent can execute it unattended: exact edits, exact checks, exact numbers,
what the agent may decide alone, what it may not, what to do when a check
fails, and what Marcel finds in the morning.

The direction is the bible: pillar 3 (`style-bible/00-pillars.md`, "monumental
against tiny, in a real-sized Alps, with the view to the horizon"), D41 (view
distance, an engine requirement), D44 (unbounded terrain, ringed content),
D45 (real relief - NOT this lane, the next one), D56 as amended by D84 (the
world-truth break moves to right after this lane), `style-bible/70-scale-metrics.md`
§ The horizon test, and `docs/research/distant-horizons.md` (the engine
research behind D41). The audit that names the fault is
`docs/reconciliation/02-world-render.md` § C2. Read those before this file.

**The north star, in Marcel's words (2026-09-04).** "I want the world big
enough. I want to see as far away as possible. I want a good amount of FPS,
and I would like to see mountains as much as possible in full." Three
things, and every number below serves one of them:

1. **The world is as big as the view.** No edge, no region, nothing that
   stops loading. Terrain exists wherever the player or the camera asks.
2. **The view reaches the horizon.** 32 km on a clear day, ranges beyond
   ranges, and the sight ends in aerial perspective, never in a wall.
3. **The frame holds.** 60 FPS at max settings on mid hardware, measured
   while sprinting through forest, and ganymede's RTX 3070 Ti is that card.

**What horizon v1 is.** Today the far field is one 3.5 M-vertex mesh built
whole every time the loaded frontier moves, from a heightmap that is one
6,000-block array clamped at its edge, drawn to 1.2 x `fog_end` and hidden
there by fog on purpose (`worldgen_config.gd:932`, "beyond fog_end nothing is
visible, which is what makes the far-field mesh's edge invisible rather than
a cliff"). Colour is re-derived per ring from slope and zone at that ring's
resolution, so a mountain changes colour four or five times on the walk in.
This plan replaces the store, the mesh, the colour, the fog and the
coordinate system: origin-anchored height tiles generated on demand at every
level of detail, a far field of persistent per-ring, per-sector meshes that
re-mesh only what moved, one colour source shared by every level, a fog ramp
normalised to the draw distance, a floating origin, and the instruments
that prove all of it - including the one that measures the frame while
sprinting, which the project has never had.

**What horizon v1 is not.** No relief change, no rings-from-the-capital, no
lakes outside the home region, no zone re-derivation, no C++ chunk mesher
(that is `docs/plans/mesher-v1.md`, the parallel lane), no buildings, no
weather. The home 3 km keeps every one of its numbers: heightmap `4782edac`,
spawn `(-44, -124)`, 53 lakes, config hash `1d7c18c7` at the tip of `main`
(`f8ef45c`), reprinted after every stage. **What a seed produces inside the
home region does not move by one bit.** Everything that changes a seed's
truth is the next lane, the world-truth break, and it starts the day this
one lands.

The three habits apply: the ring table and the fog ramp are tables (habit
1); nothing here touches the journal or the mutation path.

---

## 0. The contract

**Who and where.** One agent, Opus, on ganymede, **Forward+ only**, in
tmux session `horizon-v1`, worktree `~/Kubik-horizon-v1`, branch
`feat/horizon-v1` from `main`. Ganymede: Ubuntu 24.04, RTX 3070 Ti 8 GB,
driver 595, `~/bin/godot` 4.7.2, `~/godot-cpp` (pinned `26fb7ab`, API
dumped), `~/bin/scons` (venv `~/.venvs/scons`), `~/.venvs/kubik/bin/python`
for PIL; windowed commands under `xvfb-run -a -s "-screen 0 1280x720x24"`
with `XDG_RUNTIME_DIR` exported to a writable directory. The first console
line of the first tour must read `Vulkan 1.4 - Forward+ - Using Device #0:
NVIDIA GeForce RTX 3070 Ti`; anything else is a stop-and-record. The ALSA
errors are the missing sound card.

**A second lane runs the same nights.** `docs/plans/mesher-v1.md` (phase 1b,
the chunk mesher in C++) runs in `~/Kubik-mesher-v1` on `feat/mesher-v1`.
The two lanes share a box and a GPU and nothing else. **File ownership is
the table below and it is a hard rule**: a file the other lane owns is not
edited, not even a comment; a hook that seems necessary in the other lane's
file is written as a one-line request in the status doc and worked around.
Benchmarks are taken when `pgrep -f Kubik-mesher-v1` is quiet, or repeated
until two runs agree within 10%.

| this lane OWNS | this lane may ADD ONE LINE to | this lane must NOT touch |
| --- | --- | --- |
| `scripts/world/heightmap.gd`, `terrain_generator.gd` (tile sampling only), `world.gd`, `far_field.gd`, `far_field_job.gd`, `far_upload.gd`, `flora/tree_field.gd`, `flora/tree_field_job.gd`, `flora/flora_column.gd`, `look.gd` (fog and far material), `sky_cycle.gd`, `valley_fog.gd`, `worldgen_config.gd`, `scripts/player/player.gd`, `remote_player.gd`, `scripts/game/game.gd`, `scripts/physics/locomotion.gd`, `body_field.gd`, `scripts/ui/debug_hud.gd`, `scripts/tools/far_probe.gd`, `screenshot_tour.gd`, NEW `scripts/tools/sprint_probe.gd`, NEW `scripts/tools/selftest_horizon.gd` + `scenes/selftest_horizon.tscn`, `gdext/src/far_world.{h,cpp}`, `far_build.{h,cpp}`, `far_mesher.{h,cpp}`, `height_tiles.{h,cpp}`, `docs/status/horizon-v1.md`, `README.md` § Running it (the new probes and flags) | `scripts/tools/selftest.gd` (ONE line that calls `SelftestHorizon.run()`; nothing else), `gdext/src/register_types.cpp` (nothing - no new class in this lane) | `scripts/world/chunk_mesher.gd`, `column_job.gd`, `chunk_node.gd`, `chunk.gd`, `block.gd` (read-only for both), `gdext/src/chunk_mesher.*`, `scripts/tools/mesh_bench.gd`, `docs/status/mesher-v1.md`, `STATUS.md`, `TODO.md`, `CLAUDE.md`, `RECONCILIATION.md`, `docs/DESIGN.md`, anything under `../Kubik-bible` or `../Kubik-assets` |

**No new GDExtension class in this lane.** The C++ edits here extend
`KubikHeightTiles` (coarse tiles at a level), the `World` struct in
`far_world.h` (a tile map instead of one array, the material pyramid) and
`far_build.cpp` (levels 6 to 9, per-sector output). New methods on existing
classes register through their own `_bind_methods`; `register_types.cpp`
belongs to the mesher lane.

**Branch.** `feat/horizon-v1`. One commit per stage minimum, pushed to
`origin` after every stage. Merged to `main` by Marcel (or by Fable on his
say-so) after review. **The agent never force-pushes, never rewrites
history, never reverts anyone else's commit, never touches `main` directly,
never edits `../Kubik-bible` or `../Kubik-assets`.** Findings for the bible go
in the status doc under "For the bible".

**Delivered by morning.** `feat/horizon-v1`, pushed; `docs/status/horizon-v1.md`
updated at the end of every stage (a run that dies at 04:00 still leaves a
record); tours per stage; the far probe's table per stage; the sprint
probe's line per stage from Stage 0 on; a final message in the shape of
section 6.

**Never.** No relief, zone, lake or spawn change; the canonical world line is
printed after every stage and one changed character is a red gate. No
texture. No billboard or impostor card (D21, the trees v3 ruling). No fog
that ends sight before the draw distance. No world coordinate stored in a
mesh, a MultiMesh buffer or a physics body as a large float (section 3, the
anchor rule). No new registered class. No file the mesher lane owns. No
question left unrecorded.

**Reading order, before the first edit.** `CLAUDE.md` (World rules, Engine
rules, Where work runs), `RECONCILIATION.md` § 9, `docs/reconciliation/02-world-render.md`
§ C2 and § C3, `docs/research/distant-horizons.md` § 1 (sections and the
quadtree), § 2c (majority vote), § 3 Numbers, § 4 Fog, § 5 the seam;
`docs/plans/distance-v1.md` (the pyramid and the far probe),
`docs/plans/distance-v3.md` (rings 4 and 5 and their cost table),
`docs/plans/distance-v5.md` and `docs/status/distance-v5.md` (the tiles, the
upload budget, item 25 "tiled in the builder, not in the store"),
`docs/status/light-v1.md` (fog's three jobs, Q23 the probe that never exits,
the cost table), `docs/plans/light-v1-tech.md` (shape and discipline), this
file. Then the code, top to bottom: `heightmap.gd`, `terrain_generator.gd`
(`build_heightmap`, `_build_tile`, `surface_at`, `wildness_at`,
`_resolve_zone_thresholds`), `far_field.gd`, `far_field_job.gd` (all 1,824
lines - it is the thing being restructured), `far_upload.gd`,
`gdext/src/far_world.h`, `far_build.cpp`, `height_tiles.cpp`, `world.gd`
(`_process`, `set_center_from_position`, `loaded_frontier`,
`_recompute_frontier`, `refresh_region`, `_update_fog_floor`),
`flora/tree_field.gd` and `tree_field_job.gd`, `look.gd` § fog and far
material, `sky_cycle.gd` (KEYFRAMES and the environment writes),
`valley_fog.gd`, `game.gd` (`_publish_local_state`, `_cl_sync_players`,
`_cl_receive_join_state`), `player.gd`, `locomotion.gd` (noclip),
`scripts/tools/far_probe.gd`, `stream_probe.gd` (to see why it never exits),
`screenshot_tour.gd`, `selftest.gd` (the far parity tests, `canonical world`),
`scenes/game.tscn`.

**Time budget** (wall clock, guidance): setup 0.5 h; Stage 0 3 h; Stage 1
4 h; Stage 2 3 h; Stage 3 6 h; Stage 4 3 h; Stage 5 2 h; Stage 6 5 h;
Stage 7 2 h; Stage 8 1 h. About thirty hours: **three nights, run back to
back in one session** (grill Q3). Night one is setup and Stages 0 to 2;
night two is Stages 3 and 4; night three is Stages 5 to 8. The run does not
wait for a review between nights; Marcel reads whichever morning he is at
and can stop or redirect the session then. A stage that runs past 1.5x its
budget is wrapped at its last green commit and the next stage starts; what
was left undone goes in the status doc. **Stage 0 is the exception**: it is
never wrapped early, and if it cannot be made green the run stops there
(section 5).

---

## 1. The grill - questions asked before the run, answers taken

STATUS: **BOUND, 2026-09-04.** Q1 to Q11 were answered by Marcel in
conversation, one by one. Q12 onward were bound by Fable the same evening
on Marcel's standing instruction ("I'm also up for recommendations") and he
may overrule any of them in the morning; until he does, **an answer here is
binding.**

| # | question | answer | binds |
| --- | --- | --- | --- |
| 1 | Merge `feat/light-v1` first, or stack this lane on it? | **Merged to `main` first** (`f8ef45c`, 2026-09-04, with the day fog and tree-ring tuning as its last commit). This lane branches from `main`. | the branch point |
| 2 | Real relief in this lane, or after? | **Horizon first, relief right after.** This lane changes nothing a seed produces inside the home 3 km. The world-truth break (relief D45, rings from the capital D44, lakes and zones per tile, the generator's world truth in C++) is the next lane and starts the day this one lands. | the "never" list |
| 3 | How far on a clear day? | **32 km.** Far radius 38.4 km (1.2 x), camera far plane 40 km. One more ring per doubling; section 3 has the table. | Stage 3 |
| 4 | Positions past 10 km lose millimetres in Godot's floats. Double-precision build, or floating origin? | **Floating origin.** The official 4.7.2 binary stays on every machine and in CI; render space is world space minus an origin offset that moves in whole tiles. | Stage 6 |
| 5 | Can you walk beyond the home 3 km in this lane? | **Yes, anywhere.** Voxel terrain generates wherever the player goes. Lakes exist only in the home region until the world-truth break; outside it, `wildness_at` clamps at 1.0 and zones use the home region's thresholds - both recorded as silences for the next lane, not fixed here. | Stages 1, 2 |
| 6 | What does a clear day look like at distance? | **Aerial perspective only.** Nothing veiled until 0.4 R (12.8 km), then a slow blue-grey haze that saturates at R (32 km), Distant Horizons' own shape. Mountains at 5 km stay crisp. Dusk, night and eerie keep their exponential terms; eerie's whole point is that the fog wins. | Stage 5 |
| 7 | The frame rule? | **60 FPS at max settings on mid hardware**, and ganymede's 3070 Ti is that card: median frame under 16.7 ms and no frame over 25 ms across a 60-second sprint through forest at the Ultra preset. The 5080 must land well above; Marcel reads that number himself. Graphics settings come later; the north star is that max settings on a card slower than a 5080 still hold 60. | Stage 7, section 5 |
| 8 | The C++ chunk mesher alongside? | **Parallel lane, same nights**, `feat/mesher-v1`, zero-overlap file list in section 0. This lane's Stage 7 reports the frame line with and without the mesher branch merged in locally (a throwaway merge in a scratch worktree, never pushed), so Marcel sees what each lane bought. | Stage 7 |
| 9 | Queue order? | **Horizon + mesher, then the world-truth break, then people and fire, buildings, the scene.** D84 records it; `RECONCILIATION.md` § 9 and `CLAUDE.md` § Working order were rewritten the same evening. | nothing in the run |
| 10 | Testing 32 km on foot? | **A developer teleport and a fast fly**: `--tp X Z` (world metres) at launch, an F4 row `teleport x / z / go`, and a `fly_speed_mps` local knob (18 today, range 18 to 500), host only, never in a shipped build. The tour and the probes use them. | Stage 0 |
| 11 | Launch? | **Tonight, both lanes, auto mode, babysat by Fable from Marcel's box.** | nothing in the run |
| 12 | Which heightmap levels exist where? | **Tiles per level, on demand.** A tile is 512 blocks (256 m) at level 0 and the same 128 x 128 cells at every level, so a level-L tile covers 256 x 2^L metres. Level L tiles exist only where ring L needs them plus one tile of apron; they are built by `KubikHeightTiles.build_tile` at step `4 x 2^L` blocks with a 2 x 2 supersample mean (tunable to 4 x 4 if FIZZ says so), cached by `(level, tx, tz)`, evicted beyond twice their ring's outer radius, and rebuilt from the seed when needed - determinism makes the cache a convenience, never a truth. Inside the home region, level 0 stays the region array (bit-identical to today) and levels 1 to 5 stay the pyramid built from it; the tile store starts where the array ends. | Stage 1 |
| 13 | Rings beyond 5? | **Four more**: 6 (128 m cells) to 4.8 km, 7 (256 m) to 9.6 km, 8 (512 m) to 19.2 km, 9 (1,024 m) to 38.4 km. Cubic lock holds: step height equals cell width. Powers of two, so the subset property of distance v2 still holds at every boundary. | Stage 3 |
| 14 | One mesh, or many? | **One mesh per (ring, sector)**: 10 rings x 16 sectors = 160 `MeshInstance3D`s under `FarField`, each with a world anchor. A rebuild is a set of (ring, sector) keys; rings 0 to 2 follow the loaded frontier as today; ring r >= 3 re-centres only when the player has moved more than a quarter of its inner radius since it was last built. Walking 100 m touches rings 0 and 1 and nothing else. | Stage 3 |
| 15 | What is a far cell's colour? | **The majority material of the level-0 cells under it, through `block.gd`'s palette** - Distant Horizons' rule (§ 2c of the research). A material pyramid sits beside the height pyramid: level 0 is the surface material per 2 m cell (from `surface_zone_at` at the cell, as the voxel mesher would paint it), level L is the mode of its four children, ties to the lower material id. Beyond the home region the level-L tile computes its material at its own step from the same functions. Rings never re-derive colour from slope or zone at their own resolution; the zone dither is gone; risers shade as voxel side faces (already). Forest cover beyond the tree ring is a byte per cell from `TreeFieldJob`'s placement density at the cell centre, blended into the cell colour by the species' canopy ramp - so a forest at 10 km is the same green as the forest at 500 m with fewer cells. | Stage 4 |
| 16 | Which fog mechanism carries the ramp? | **The far mesh's own material for the day and evening ramp; the engine's exponential term stays for dusk, night and eerie.** Godot has one fog mode per environment and no start offset on exponential fog. The far material (this lane owns `look.gd`'s far material) applies `fog = 1 - exp(-(max(d - 0.4R, 0) / (0.6R) x 2.5)^2)` toward the hour's fog colour, R from the preset, so the ramp is normalised to the draw distance the way DH's is. Voxels and trees inside 4 km see no engine far term at day (density 0.00003, the aerial tint only through `fog_aerial_perspective`), because at that range the ramp is zero anyway. Hour keyframes gain `far_ramp: true/false`. | Stage 5 |
| 17 | When does the origin move, and by how much? | **When the player is more than 2,048 m from the render origin**, by the whole number of tiles (256 m) that brings the player nearest to zero. One frame, in `_physics_process`, every anchor at once. The four top-level nodes (`World`, `TreeField`, `Players`, the fog volumes' parent) carry nothing; every anchor is a child node's position, and every vertex, MultiMesh row and physics body is small relative to its anchor (section 3, the anchor rule). | Stage 6 |
| 18 | What travels on the wire, and what is saved? | **World coordinates, always.** `_publish_local_state` sends `world_position()`; `_cl_sync_players` receives world and converts; join state carries nothing about origins because each machine has its own. Chunk keys and edits are already world blocks. | Stage 6 |
| 19 | The instrument for the frame? | **`--sprint-probe`**, new, and it exits by construction: bounded by frames, progress written to `build/probe/sprint-<label>.txt` and flushed every second (Godot buffers stdout under redirection, Q23 of light v1), a watchdog that quits with code 2 if the ground has not arrived in 120 s. Sixty seconds of scripted sprint from spawn along `+X` through the forest at the Ultra preset; reports median, p99, worst, frames over 25 ms, chunks built, far rebuilds and their ms, tree rebuilds. The box drifts: a comparison is three runs ABAB, medians, spread. | Stage 0, Stage 7 |
| 20 | "Nothing pops in" as a number? | **The far probe's FIZZ and PEAK LOSS extended to rings 6 to 9**, run twice per stage; and a new HANDOVER measurement: at every ring boundary and at the voxel seam, the drawn height on both sides sampled every metre along a 200 m arc, RMS difference in blocks. Gates in section 3. | Stages 3, 4 |
| 21 | Presets? | **All presets see R = 32 km**; they differ in the near. Low: voxel radius 6, far_tree 400, R 8 km. Medium: 8, 500, 16 km. High: 12, 400, 32 km. **Ultra: 16, 800, 32 km, and Ultra is "max settings"** for Q7. `far_ring_div` stays 4. | section 3 |
| 22 | The stream probe? | **Retired.** `stream_probe.gd` stays in the tree with its header amended to say it is superseded by the sprint probe and why; no time is spent on its hang. | Stage 0 |
| 23 | Commit hygiene? | `feat(horizon):`, `fix(horizon):`, `docs(horizon):`; body says what changed and what shot or probe judged it; trailers `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_012UVKGx4zoRXCDB1ZUqRZyX`. | every commit |
| 24 | If a stage's tour looks worse than before? | Stage 3 may, before Stage 4 gives it colour and Stage 5 gives it air. For any other stage: check the sampled windows first; if they pass and the eye check fails, record the sentence and do not revert. | section 5 |

---

## 2. Setup and the gates

```
cd ~/Kubik && git fetch && git checkout main && git pull --ff-only    # ganymede was at 464f6f3 on 2026-09-04
git worktree add -b feat/horizon-v1 ~/Kubik-horizon-v1 main
cd ~/Kubik-horizon-v1 && git reset --hard origin/main                   # worktree add has resolved a stale main before
<godot> --headless --path . --import
python scripts/tools/sync_assets.py                                    # the tree library must be mounted
cd gdext && scons platform=linux target=editor custom_api_file=../../godot-cpp/extension_api.json -j$(nproc) && cd ..
<godot> --headless --path . -s gdext/check.gd                          # "class exists: true"
```

**Baselines, same day, before the first edit:**

```
<godot> --headless --path . scenes/selftest.tscn                                  # SELFTEST: all passed on Linux
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
<godot> --headless --path . -- --host --seed 42 --far-probe                        # the FIZZ/ROUGHNESS/PEAK LOSS table, rings 0-5
<godot> --path . -- --tour --seed 42 --label horizon-base
```

The probe's numbers are copied into the status doc as **the baseline** and
must match `main`'s: heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes,
15,218 trees, config `1d7c18c7`. Every knob this plan adds is LOCAL and
unhashed by its own comment; a config hash that moves is a stage that went
red. There is no frame baseline until Stage 0 builds the instrument; Stage
0's first act after building it is to run it on the unmodified tree (a
throwaway `git stash`) so night one has a "before".

**The gates, run at the end of every stage, in this order:**

```
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . scenes/selftest_horizon.tscn                          # this lane's own tests, from Stage 0
<godot> --headless --path . scenes/character/selftest_character.tscn
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
   # heightmap 4782edac, spawn (-44, -124), 53 lakes, 15218 trees, config 1d7c18c7 - every character
<godot> --headless --path . -- --host --seed 42 --far-probe                        # run twice; identical or red
<godot> --headless --path . -- --host --seed 42 --sprint-probe --label horizon-<n>  # from Stage 0
<godot> --path . -- --tour --seed 42 --label horizon-<n>
python tools/compare_sheets.py horizon-base horizon-<n-1> horizon-<n>
```

then the stage's sampled checks and eye checks, then the status doc, then
the commit and the push. **Magenta is a red gate.** Any far mesh with a
missing sector, a sky-coloured hole or a crack you can see the sky through
is a red gate. The tour gains vantages in Stage 0: `30-horizon-peak` (the
highest summit of the home region, camera pitched level, looking `+X`),
`31-horizon-far` (teleported to `(20000, 0)` m, looking back at the home
region), `32-horizon-walk` (the sprint line's midpoint, looking along it).

**Sampled check method.** `~/.venvs/kubik/bin/python` + PIL, 9 x 9 mean of
a region the agent chooses on the named shot, HSV (H in degrees, S and V in
percent), pixel coordinates in the status doc. As light v1: a window is a
**GATE** (must hold, section 5 on failure) or a **RECORD** (written down
with the delta, never a failure).

---

## 3. The numbers

**The reach.** R = 32,000 m (the draw distance the fog ramp is normalised
to). Far radius = 1.2 R = 38,400 m. Camera far plane 40,000 m, near plane
unchanged. `fog_end_m` is renamed in meaning, not in name: it is R, and its
old comment about hiding the mesh's edge is deleted.

**The rings** (`FarFieldJob.RING_OUTER_M`, `RING_STEP_MULTIPLE`; cell = step
at `far_ring_div` 4):

| ring | cell | covers | pyramid level | cubic-lock step |
| --- | --- | --- | --- | --- |
| 0 | 2 m | seam to 150 m | 0 | 2 m |
| 1 | 4 m | 150 to 300 m | 1 | 4 m |
| 2 | 8 m | 300 to 600 m | 2 | 8 m |
| 3 | 16 m | 600 to 1,200 m | 3 | 16 m |
| 4 | 32 m | 1,200 to 2,400 m | 4 | 32 m |
| 5 | 64 m | 2,400 to 4,800 m | 5 | 64 m |
| 6 | 128 m | 4,800 to 9,600 m | 6 | 128 m |
| 7 | 256 m | 9,600 to 19,200 m | 7 | 256 m |
| 8 | 512 m | 19,200 to 38,400 m | 8 | 512 m |
| 9 | 1,024 m | reserve: only if `far_radius` > 38,400 m | 9 | 1,024 m |

Ring 5's outer moves from "to the fog" to 4,800 m. Quads per ring are
roughly constant by construction (area x4, cell area x4); the measured
table per ring goes in the status doc after Stage 3, and **the sum over
all rings at Ultra must not exceed 2.0 M vertices** (today: 3.5 M for six
rings, because ring 5 ran to 3,840 m at 64 m cells with skirts; the new
rings are cheap and ring 5 gets shorter).

**The tiles.** `tile_blocks` 512 (256 m) at level 0; a level-L tile is
128 x 128 cells of `4 x 2^L` blocks, so it spans `256 x 2^L` m. Tiles kept
per level: the tiles that intersect a disc of the ring's outer radius plus
one tile of apron around the player. Eviction beyond 2x that radius. A
level-L cell's height is the mean of a 2 x 2 supersample of `raw_height`
at half-cell offsets, quantised to 1/1024 block as every height is. Inside
the home region `Heightmap.cells` and the existing pyramid are untouched
and are the source for levels 0 to 5; the `World` struct in `far_world.h`
reads the same data it reads today for those, and the tile map for
everything else.

**The material pyramid.** One byte per cell per level: the material id
`block.gd` would paint on the surface at that cell (level 0: from
`surface_zone_at` and the slope rule at the cell centre, exactly as the
chunk mesher chooses a top face's material today - **the same function,
not a re-implementation**; the far probe's parity test compares 10,000
samples of the two and they must agree exactly). Level L = mode of four
children, ties to the lower id. Forest cover: one byte per cell, 0 to 255,
from the placement density of `TreeFieldJob` at the cell centre (the same
noise, the same thresholds, evaluated without the crown-spacing pass),
blended into the cell colour as `lerp(cell_colour, species_canopy_mid,
cover / 255 x 0.7)`; 0.7 is a tunable.

**The fog ramp (day, evening).** In the far material, `d` = distance from
the camera in metres, `R` = 32,000: `t = clamp((d - 0.4 R) / (0.6 R), 0,
1)`; `fog = 1 - exp(-(2.5 t)^2)`; colour = the hour's `fog` keyframe colour
after `fog_sky_affect`. So at 12.8 km nothing, at 20 km 0.22, at 26 km
0.63, at 32 km 0.998. The engine's exponential term at day and evening
drops to density 0.00003 (aerial tint only, `fog_aerial_perspective` 0.6
stays); the volumetric field stays at the light v1 values (day 0.0005, the
near haze Marcel accepted). Dusk, night and eerie: unchanged from light v1.

**The anchor rule (Stage 6).** Every position stored as a float lives in
one of two spaces. **World metres** are `Vector3` values passed between
systems, sent on the wire, saved, and used for every `_m` argument in the
code - unchanged in meaning from today. **Render space** is what the scene
tree holds: `render = world - origin_offset`, where `origin_offset` is a
`Vector3` of whole tiles (multiples of 256 m on x and z, 0 on y) owned by
`World`. A node's position is render space. A vertex, a MultiMesh row and a
physics body are always relative to an anchor node and never exceed a few
kilometres in magnitude; on rebase only anchors move, by `-delta`, in one
frame, all of them: chunk nodes, flora columns, far meshes, tree
MultiMeshInstances, fog volumes, bodies, players. The player's
`world_position()` is `global_position + origin_offset`. Rebase when
`|player.global_position.xz| > 2,048 m`; `delta` is the tile multiple
nearest the player. A round trip world → render → world is exact to 1e-4 m
at 40 km (float at 40 km has a 4 mm ULP, so the world value is the sum of
an exact tile multiple and a small float; keep `origin_offset` as integer
tile counts and multiply at the boundary).

**The frame (Stage 7).** Ultra preset, seed 42, 60 seconds of sprint from
spawn along `+X`, on ganymede, the mesher lane quiet: median under 16.7 ms,
no frame over 25 ms, frames over 25 ms = 0. Three runs, ABAB with whatever
is being compared, medians and spread. **This is the north star's third
line and it is a GATE**; section 5 says what to shrink first.

**Handover (Stage 3, 4).** Along a 200 m arc centred on each ring boundary
and on the voxel seam, at 1 m spacing, the drawn height on the inner side
and the outer side differ by RMS <= 0.5 x the inner cell's height step and
max <= 1.0 x. Colour across the same boundary, fog off (`--fog off`, a tour
flag added in Stage 0): |dH| <= 6 degrees, |dV| <= 8 points, 9 x 9 windows
either side, for rock, meadow, snow and forest.

**Config knobs added, all LOCAL and unhashed:** `far_reach_m` (R; 32,000),
`far_origin_rebase_m` (2,048), `fly_speed_mps` (18), `far_forest_blend`
(0.7), `far_supersample` (2), `far_ring_recenter_frac` (0.25),
`far_tile_apron` (1). Every one on F4 under a `horizon:` prefix, and every
one that redraws only the far mesh calls `FarField.request_rebuild()`
directly, never F7.

---

## 4. Tunables

The only numbers the agent may change on its own judgement. Everything else
in this file is fixed. Each change: the shot or probe that decided it,
before and after, in the status doc.

| knob | where | start | range | judged on |
| --- | --- | --- | --- | --- |
| `far_supersample` | tiles | 2 | 2, 4 | far probe FIZZ at rings 6-9 |
| `far_ring_recenter_frac` | FarField | 0.25 | 0.15-0.5 | sprint probe far rebuilds, handover |
| `far_upload_budget_ms` | config | 4.0 | 2-6 | sprint probe worst frame |
| slice size (quads per upload slice) | FarUpload | one sector | split by 2, 4 | sprint probe worst frame |
| `far_forest_blend` | material pyramid | 0.7 | 0.4-0.9 | 30-horizon-peak, 6-postcard |
| ramp exponent (the 2.5) | far material | 2.5 | 2.0-3.5 | 30-horizon-peak, 31-horizon-far |
| ramp start (the 0.4 R) | far material | 0.4 | 0.3-0.5 | the same two |
| day/evening engine fog density | KEYFRAMES | 0.00003 | 0-0.0001 | 6-postcard, hours |
| `directional_shadow_max_distance` | Sun | 250 | 150-250 | sprint probe (never raised) |
| tile eviction multiple | tile store | 2x | 1.5x-3x | memory line in the sprint probe |
| skirt depth per ring | far build | today's | x0.5-x2 | crack check in the tour |
| tree-ring rebuild step / radius | config | 200 / 400-800 | 100-400 / 400-1,000 | sprint probe, 32-horizon-walk |

---

## 5. Failure protocol

1. **A self-test or the probe goes red:** fix it within the stage; if the
   fix is not obvious in 20 minutes, revert to the stage's last green
   commit, record, and continue with the next stage only if it does not
   build on the reverted work (1 on 0, 2 on 1, 3 on 1, 4 on 3, 5 on 3, 6 on
   2 and 3, 7 on everything, 8 on nothing).
2. **The canonical world line changes by one character:** the stage is not
   done, whatever else passed. Find the write into the home region's
   truth. No tolerance.
3. **The far probe disagrees with itself across two runs:** a thread wrote
   into a shared tile or the cache returned a half-built tile. Fix before
   anything else in the stage; determinism is the instrument.
4. **A GATE window or handover number fails and no tunable in its range
   fixes it:** revert that stage's visual edit, record the numbers, continue.
5. **The sprint probe fails the frame gate (Stage 7):** shrink in this
   order, recording each: upload slice size, `far_ring_recenter_frac` up,
   tree-ring radius, shadow distance to 150, volumetric length to 800. If
   it still fails, record it as BLOCKING with the full line and continue to
   Stage 8; Marcel decides with the mesher lane's number beside it.
6. **An eye check fails while every window passes:** record it with the
   shot name and your sentence; do not revert.
7. **A question this file does not answer:** take the conservative reading
   (smaller change, nearer today's value, fewer files), write the question
   and the reading under "Questions taken alone", continue.
8. **Stage 0 cannot be made green:** push what exists, write the findings,
   stop the run. Nothing after Stage 0 is judgeable without its instruments.
9. **Godot hangs or a tour crashes:** kill it, re-run once; if it repeats,
   record the command and the last console lines, continue without that
   evidence, saying so.
10. **`origin/feat/horizon-v1` has moved:** it should not. `git pull
    --rebase`; a conflict is a stop-and-record.
11. **A file the mesher lane owns needs a change:** do not make it. Write the
    one-line request in the status doc under "For the merge", work around
    it, continue.
12. **Memory on the box passes 12 GB for the game process:** the tile store's
    eviction is wrong; fix before continuing.

---

## Stage 0 - The instruments, and the way to get anywhere

Nothing in this plan is judgeable without three things the project does
not have: a frame instrument that exits, a way to be 20 km away in one
second, and a far probe that knows about rings past 5.

### 0.1 The sprint probe

`scripts/tools/sprint_probe.gd`, entered from `game.gd` on `--sprint-probe`
the way `--far-probe` is. Host, seed from `--seed`, preset from
`--preset ultra` (default ultra), label from `--label`. Sequence: wait for
ground under the player (`Game._release_player_when_ground_exists`), hold
one second, then drive `Locomotion.Intent` with `wish = (1, 0)` and the
sprint bit for exactly `--seconds` (default 60) of process time, recording
every frame's `delta`. Progress: one line per second appended to
`build/probe/sprint-<label>.txt` and flushed (`FileAccess.flush()`), and
the same line to stdout. Watchdog: if ground has not arrived within 120 s
of process time, write `WATCHDOG` and `get_tree().quit(2)`. On completion
write the summary and `quit(0)`. **This probe exits; that is its first
gate.**

Summary line, one per run, machine-parseable:

```
SPRINT label=<l> seconds=60 frames=<n> median_ms=<m> p99_ms=<p> worst_ms=<w> over25=<k> chunks=<c> far_rebuilds=<r> far_ms_median=<f> tree_rebuilds=<t> mem_mb=<mem>
```

`--fog off` (tour and probes): sets every fog term to zero for the run, for
colour measurements. `--tp X Z`: teleport at launch, world metres. F4 gains
`teleport x`, `teleport z`, `go`, and `fly_speed_mps`. `FLY_SPEED` in
`locomotion.gd` becomes the knob's value; noclip (`F`) is unchanged
otherwise and stays host-honoured as its comment says.

### 0.2 The far probe, extended

`far_probe.gd` runs its table over every ring the config defines, not the
six it hard-codes; adds `--rings a-b`; adds the HANDOVER measurement of
section 3 (a 200 m arc per boundary, 1 m spacing, RMS and max of the
drawn-height difference, and with `--fog off` the H/V windows either side
in four materials). Runs the table twice and exits non-zero on any
difference, as today.

### 0.3 The horizon self-test

`scripts/tools/selftest_horizon.gd` + `scenes/selftest_horizon.tscn`, this
lane's own gate file (the mesher lane owns `selftest.gd`). Stage 0 seeds it
with: the sprint probe's summary parser round-trips; `--tp` lands within
one block of the asked position; `fly_speed_mps` is honoured. Later stages
append their tests here. One line is added to `selftest.gd` so the main
suite runs it too.

### 0.4 The tour

Three vantages added to `screenshot_tour.gd`: `30-horizon-peak`,
`31-horizon-far`, `32-horizon-walk` (section 2). `stream_probe.gd`'s header
gets the retirement note (Q22).

### 0.5 Checks

- The sprint probe run on the untouched tree (stash) exits with code 0 in
  under three minutes wall and its file has 60 progress lines. **Record the
  line: it is the frame baseline.**
- Run twice back to back: `chunks`, `far_rebuilds` and `tree_rebuilds`
  agree exactly; `median_ms` within 10%.
- `--tp 20000 0` then the far probe: exits 0, both runs identical.
- The horizon self-test passes; the main suite still passes.
- Commit `feat(horizon): stage 0 - the sprint probe that exits, teleport, fly speed, the far probe past ring 5`.

---

## Stage 1 - The tile store

The height map stops being one array with an edge. It becomes a store of
origin-anchored tiles at every level, built on demand, with the home
region's array kept inside it as the exact source it already is.

### 1.1 `Heightmap` becomes a store

`heightmap.gd`: keep `cells`, `cols`, `step`, `min_block`, `_max_block`, the
pyramid and every function that reads them - **bit-identical for any
`(bx, bz)` inside the region, and the canonical line proves it**. Add:

- `_tiles: Dictionary` keyed `Vector3i(level, tx, tz)` →
  `PackedFloat32Array` of 128 x 128 heights, plus `_tiles_mutex` (workers
  read, the main thread and one builder write; a tile is published only
  when complete).
- `tile_of(level, bx, bz) -> Vector2i`, `ensure_tile(level, tx, tz)`
  (build if absent, through `TerrainGenerator._tiles.build_tile` at step
  `4 x 2^level` with the 2 x 2 supersample mean, quantised), `evict_beyond(level, radius_blocks, centre)`.
- `height_at(bx, bz)`: inside the region as today; outside, bilinear in the
  level-0 tile (building it if absent - which a worker may do, so the
  builder is thread-safe and the C++ `KubikHeightTiles` instance is shared
  read-only).
- `height_filtered(bx, bz, level)`: inside the region as today; outside,
  from level-L tiles with trilinear across L and L+1 as today.
- `in_bounds` is kept for the lakes and the spawn only, renamed
  `in_home_region`, and every other caller is changed to a call that
  cannot fail.

`KubikHeightTiles.build_tile` gains an optional `supersample` (1, 2, 4):
each output cell is the mean of `s x s` samples of `raw_height` at
`(i + (k + 0.5) / s) x step`, then quantised. `supersample = 1` is
bit-identical to today's output (the home region is built with 1).

### 1.2 The far world marshal

`far_world.h`'s `World` struct gains `tiles` (a map keyed by level and
tile index to a float vector) and a `material_tiles` slot (empty until
Stage 4); `height_at` and `bilinear` route outside the region to the
tiles. `FarField` marshals tiles incrementally: the job receives, per
rebuild, only the tiles it is missing, keyed the same way (the marshal-once
rule becomes marshal-once-per-tile).

### 1.3 Checks

- Canonical line unchanged. `height tile parity` unchanged.
- New gate in the horizon self-test: `height_at(10000, 10000)` (blocks)
  equals `build_tile` for that cell, and no longer equals the clamped edge;
  `height_at` at 1,000 random positions in a 40 km disc is finite and
  within `[min_altitude, max_altitude]`; the same call twice returns the
  same float; a tile built on a worker and on the main thread are
  byte-identical.
- The far probe at `--tp 20000 0`: identical twice.
- Memory: the tile store at `--tp 20000 0` with only levels 0 to 5 present
  (rings 6 to 9 arrive in Stage 3) under 300 MB for tiles; printed in the
  probe's line.
- Commit `feat(horizon): stage 1 - origin-anchored height tiles at every level, the region kept inside them`.

---

## Stage 2 - Voxels anywhere

The playable world follows the player. Everything that assumed the region's
edge is found and changed; the list is in section 0's reading order and
it is finite.

### 2.1 The generator

`terrain_generator.gd`: `surface_at`, `detail_at`, `surface_zone_at`,
`column_surface_range`, `is_solid_at` and `generate_into` sample
`heightmap.height_at`, which no longer clamps. `_cell_index` and any
direct `cells[]` read are replaced by tile-aware reads. `wildness_at` and
`danger_at` keep clamping at the region's half-width: **recorded as a
silence for the world-truth break**, where D44 measures them from the
capital. `_resolve_zone_thresholds` stays over the home region: **silence
two**. `find_spawn` and `Lakes` stay over the home region: **silence
three**.

### 2.2 The world

`world.gd`: `refresh_region`, `_recompute_frontier`, the column queue, the
flora queue, `_update_fog_floor` and the chunk cache work at any centre.
Every `in_bounds` guard that dropped a column outside the region is
removed. The far field's exclusion disc and the frontier are unchanged in
shape.

### 2.3 Checks

- Canonical line unchanged.
- `--tp 5000 5000` then a 30-second sprint probe: `chunks` > 0, no
  `NO SPAWN` warning (spawn is only computed at home), no hole (the tour's
  `32-horizon-walk` shot from there shows ground under the player and to
  the horizon of the loaded disc), the self-tests pass.
- `--tp -12000 3000`: the same.
- A 60-second sprint from spawn crosses the old edge at `x = 1,500 m` and
  nothing in the probe's per-second lines spikes at the crossing (worst
  frame in the second of the crossing within 2x the run's median).
- Commit `feat(horizon): stage 2 - the voxel world follows the player, the region is bookkeeping`.

---

## Stage 3 - Thirty-two kilometres, in persistent pieces

### 3.1 Rings 6 to 8 (and 9 in reserve)

`FarFieldJob.RING_OUTER_M` becomes the section 3 table; `RING_STEP_MULTIPLE`
gains `64, 128, 256, 512`; `Heightmap.MAX_LEVEL` is per-source: 5 for the
region pyramid, 9 for tiles. The trilinear level chooser in
`far_field_job.gd` and `far_build.cpp` clamps to the level the source has.
The skirt rule is unchanged. `far_radius` = `far_reach_m x 1.2`. The camera
far plane and the `[Game] view distance` line follow.

### 3.2 One mesh per (ring, sector)

`far_field.gd` keeps 160 `MeshInstance3D` children keyed `(ring, sector)`,
each with a world anchor (`Vector2i` blocks of its build centre). A
rebuild request is a set of keys; the job builds only those, emitting one
array set per key (the slice machinery of distance v5 already emits per
sector; it now emits per ring too). `request_rebuild` computes the set:
rings 0 to 2 for every frontier move as today; ring r >= 3 when
`|player - anchor_r| > far_ring_recenter_frac x inner_r`. The upload pump's
slice is one (ring, sector) mesh, and a mesh over the slice budget is split
along its sector's radial midline (tunable).

### 3.3 The C++ side

`far_build.cpp` takes the key set and the tile map, builds only what was
asked, returns arrays per key. Its GDScript twin does the same; parity
tests compare per key.

### 3.4 Checks

- Canonical line unchanged. Far parity, slice parity, layer parity green
  per key.
- Far probe: FIZZ, ROUGHNESS, PEAK LOSS for rings 0 to 8, twice, identical;
  HANDOVER within section 3's numbers at every boundary. Where a boundary
  fails and `far_supersample` 4 fixes it, take 4 and record.
- Vertex table per ring at Ultra in the status doc; **sum <= 2.0 M**.
- Sprint probe: `far_rebuilds` for 60 s <= 12 and `far_ms_median` <= 300;
  no per-second worst frame over 25 ms attributable to a far upload
  (the probe tags each second with the number of slices uploaded).
- `30-horizon-peak`: the mesh reaches the frame's horizon in every
  direction; no edge, no hole, no crack. `31-horizon-far`: the home region
  is visible from 20 km as a range.
- Commit `feat(horizon): stage 3 - rings to 38 km, one mesh per ring and sector, only what moved is rebuilt`.

---

## Stage 4 - One colour at every distance

### 4.1 The material pyramid

Beside the height pyramid and inside every tile: one byte per cell, per
level, as section 3 defines; level 0 through the chunk mesher's own
top-face material choice (call the same function; if it lives in
`chunk_mesher.gd`, which the mesher lane owns, **do not move it** - import
it by reference and record that the mesher lane must keep its signature).
Forest cover byte from `TreeFieldJob`'s placement density at the cell
centre.

### 4.2 The far colour path

`far_build.cpp` and its twin colour a cell from the material pyramid
through `block.gd`'s palette (marshalled once as today's `zone_colors`
becomes `material_colors`) plus the forest blend; the zone dither is
deleted from both legs; riser shading stays. The tree rungs are checked,
not changed: LOD0, LOD1, LOD2 and the proxy share the species palette by
construction (trees v4); the check samples them.

### 4.3 Checks

- Canonical line unchanged. Far parity green; a new parity in the horizon
  self-test: 10,000 samples, level-0 material from the pyramid equals the
  mesher's choice, exactly.
- HANDOVER colour windows (fog off) within |dH| 6, |dV| 8 at every ring
  boundary and the voxel seam, for rock, meadow, snow and forest, on
  `32-horizon-walk` and `6-postcard`.
- `30-horizon-peak` with fog off: the same mountain flank sampled at 500 m,
  2 km and 8 km is within the same window. RECORD the forest cover's read
  at 10 km against the near forest.
- Commit `feat(horizon): stage 4 - one material source for every level, the far paint is a lookup`.

---

## Stage 5 - The air

### 5.1 The ramp

The far material gets the section 3 ramp with `far_reach_m` as R, on at
day and evening (`far_ramp` in the keyframe), off at dusk, night, eerie.
Day and evening `fog_density` to 0.00003. `fog_aerial_perspective` and
`fog_sky_affect` stay. The volumetric field stays.

### 5.2 Checks

- `30-horizon-peak` at day: a ridge at about 5 km (choose it, name the
  pixels) keeps >= 85% of its fog-off contrast (V range of a 9 x 9 window
  across its skyline, on versus off); at 32 km the far mesh's edge is
  invisible (a 9 x 9 window straddling the edge differs from the sky beside
  it by < 3 V). GATE.
- The five hours from `20-hour-day` to `24-hour-eerie`: dusk, night and
  eerie unchanged from light v1's numbers within 2 V. RECORD evening.
- Commit `feat(horizon): stage 5 - the fog is a ramp on the draw distance, and the day is clear to 13 km`.

---

## Stage 6 - The floating origin

### 6.1 The offset

`World.origin_offset_tiles: Vector2i` and `origin_offset_m()`. In
`_physics_process`, if `|player.global_position.xz| > far_origin_rebase_m`:
`delta = round(player.xz / 256) x 256`; add to the offset; subtract from
every anchor in one pass (chunk nodes, flora columns, far meshes, tree
MultiMeshInstances, fog volumes, bodies, players and remote players). The
sun and the sky have no position. The camera is under the player.

### 6.2 The anchor rule enforced

`TreeFieldJob` writes MultiMesh rows relative to the slot node's anchor
(the ring centre at build time), and the slot node's position is `anchor -
origin`. `FarFieldJob` writes vertices relative to the (ring, sector) mesh
anchor. Chunk nodes are already local. Flora columns likewise. A self-test
scans every `MeshInstance3D` and `MultiMesh` under `World` and `TreeField`
after a `--tp 30000 30000` and asserts no vertex or row position has a
magnitude over 8,192 m relative to its node.

### 6.3 The boundary

`Player.world_position()`, `Game._publish_local_state` sends it,
`_cl_sync_players` converts on receipt, `remote_player.gd` stores world and
renders local. `set_center_from_position` takes world metres. Edits and
chunk keys are already world blocks. The debug HUD's `pos` line shows
world metres and the offset in tiles.

### 6.4 Checks

- Canonical line unchanged.
- `--tp 30000 30000`: the sprint probe's per-second lines show no jitter
  metric (a new field, `jitter_mm`: the player's standing-still position
  delta per frame over 2 s, must be 0.0); the 6.2 self-test passes; the
  tour's `31-horizon-far` from there shows a stable frame (two shots 1 s
  apart differ by < 0.5% of pixels).
- The pair probe (`README.md` § The pair probe) with both instances
  teleported to `(30000, 30000)`: positions agree in world metres within
  0.01 m; a body pushed there is seen by both.
- A rebase during a sprint costs no frame over 25 ms (the probe tags the
  second a rebase happened).
- Commit `feat(horizon): stage 6 - the floating origin; anchors move, nothing else does`.

---

## Stage 7 - The sprint line

The north star's third sentence, measured.

### 7.1 The runs

At Ultra, on ganymede, the mesher lane quiet: the sprint probe three
times, then with the volumetric field off, then with tree shadows off,
then (throwaway worktree, never pushed) with `origin/feat/mesher-v1` merged
in locally if its status doc says its Stage 3 is green. Medians and
spreads in one table.

### 7.2 The gate

Median under 16.7 ms and no frame over 25 ms on the plain run. If it
fails: section 5 item 5, in order, each recorded. The result, pass or
BLOCKING, is the first line of the morning message.

- Commit `docs(horizon): stage 7 - the sprint line`.

---

## Stage 8 - Docs

`README.md` § Running it: the sprint probe, `--tp`, `--fog off`, the
horizon self-test, the presets. `README.md` § 5 "Chunks and the two-scale
world": the tile store in one paragraph. `worldgen_config.gd` comments that
said "the region", "the map", "beyond fog_end nothing is visible": rewritten
to what is true. `docs/status/horizon-v1.md` complete, with "For the
world-truth break" listing every silence (wildness, danger, zone
thresholds, lakes, spawn outside the home region) and "For the merge"
listing every request into the mesher lane's files. `STATUS.md`, `TODO.md`,
`CLAUDE.md` are not this lane's: the requests for them go in the status doc.

- Commit `docs(horizon): status, the silences, the merge requests`.

---

## 6. The status doc and the morning message

`docs/status/horizon-v1.md`, in the shape of `light-v1.md`, updated at the
end of every stage with, per stage: what shipped; the canonical line; the
far probe's table; the sprint probe's summary line (from Stage 0); every
tunable changed (was / now / shot or probe); the sampled checks with
region coordinates and measured values, GATE or RECORD; eye checks passed /
failed with the sentence; "Questions taken alone"; "For Marcel"; "For the
world-truth break" (the silences); "For the merge" (requests into the other
lane's files); "For the bible". At the top, before anything: any BLOCKING
finding.

The final message to Marcel, in this order and nothing else first:

1. `feat/horizon-v1`'s last commit; which stages are green, which were
   wrapped early, which reverted. The Windows library must be rebuilt by
   Fable before anything is judged on the 5080.
2. The sprint line: median, p99, worst, over-25 count, against the Stage 0
   baseline, with and without the mesher lane. PASS or BLOCKING.
3. The three shots to open first: `30-horizon-peak` (day), `31-horizon-far`,
   `32-horizon-walk`, and the fog-off pair of the peak.
4. Every "For Marcel" item, one line each.
5. Every silence for the world-truth break, one line each.
6. Every merge request into the mesher lane's files, one line each.
7. Every tunable moved off its start, one line each.
8. What is left.
