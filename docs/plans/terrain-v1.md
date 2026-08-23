# Terrain v1 - overnight implementation plan

**Status: done.** Written 2026-08-23 for an unattended single-pass run, and
executed the same night on branch `feat/terrain-v1`. All twelve stages
completed. What was built, what was measured, and where the result departs from
this document is in `STATUS.md` at the repo root — read that, not this.

Goal: Marcel launches the game in the morning and walks a readable Swiss
pre-Alpine landscape in third person - meadow valleys, forested slopes, bare
rock, snow peaks, lakes sitting in real depressions, fog and a day/night cycle.

---

## How to use this document

Execute it in one pass, top to bottom. **Do not stop to ask questions.** Every
number below is already decided; where a judgement call remains, the rule for
making it is stated. If something is genuinely ambiguous, pick the option that
keeps the game running and record the choice in `STATUS.md`.

Before starting, read `CLAUDE.md`, `README.md`, `docs/DESIGN.md` and
`docs/IDEAS.md`. The design pillars there outrank anything in this file.

Godot 4.7.2, invoked by full path (it is not on PATH):

```
C:\Users\tiger\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
```

Confirm the baseline before touching anything:

```
<godot> --headless --editor --quit --path .
<godot> --headless --path . res://scenes/game.tscn --quit-after 600
```

Expect zero script errors and a "75 chunks generated and meshed" line.

---

## Hard rules

1. **Determinism is sacred.** Every generated detail derives from
   `(seed, coordinates, config)`. No `randf()`, no `randi()`, no unseeded RNG
   anywhere in worldgen. No dependence on `Dictionary` iteration order. Same
   seed plus same config must always produce an identical world.
2. **Do not break multiplayer.** The host-authoritative edit path and the
   two-peer handshake already work and are tested. They must still work at the
   end of every stage.
3. **GDScript only.** No plugins, no GDExtension. `FastNoiseLite` for all noise.
4. **Commit after every stage.** Never leave the tree dirty between stages.
   Messages in the existing style: what changed, and why.
5. **Verify after every stage** with the command given. On failure: up to three
   fix attempts, then commit whatever works, write the failure into `STATUS.md`,
   and continue to the next stage that does not depend on the failed one.
6. **Leave the `TODO(marcel)` exercises exactly where specified**, each with a
   plain working fallback so the game runs without them.
7. **Third person only.** No first-person camera mode, ever.

---

## Fixed numbers

These are the spec. Put every one of them in the tuning config (Stage 1) rather
than scattering literals through the code.

### Scale

| Quantity | Value |
| --- | --- |
| Block size | 0.5 m (2 blocks per metre) |
| Player height | 4 blocks (2.0 m), capsule radius 0.8 blocks |
| Chunk | 16^3 blocks = 8 m cube (unchanged) |
| World footprint | 1.5 x 1.5 km = 3000 x 3000 blocks = 188 x 188 chunk columns |
| World origin | centred, so x and z run -1500 to +1499 blocks |
| World vertical | 0 to 320 blocks (0 to 160 m) |
| Coarse heightmap | 1 sample per 4 blocks (2 m) -> 750 x 750 cells |
| Far-field mesh | 1 vertex per 8 blocks (4 m) -> 375 x 375 |
| Voxel radius | 8 chunks (64 m) around the player, config-tunable |
| Fog | starts 120 m, fully opaque 200 m |

### Terrain shape

| Layer | Wavelength | FastNoiseLite frequency | Purpose |
| --- | --- | --- | --- |
| `continent` | 1200 blocks (600 m) | 0.00083 | broad elevation trend |
| `mountain` | 300 blocks (150 m) | 0.00333 | the main feature - ridged |
| `hills` | 60 blocks (30 m) | 0.01667 | slope detail |
| `detail` | 12 blocks (6 m) | 0.08333 | per-block roughness |
| `zone_jitter` | 400 blocks (200 m) | 0.0025 | wobbles zone thresholds |

Valley floors land around 30-50 blocks altitude, peaks up to ~240 blocks.
Mountain footprints come out 100-200 m wide, which is the readability target.

### Elevation zones

Altitudes in blocks. Each threshold is offset by `zone_jitter * 12` so the
lines are not ruler-straight.

| Zone | Altitude | Colour |
| --- | --- | --- |
| Meadow | below 100 | `#86B04A` |
| Forest floor | 100 to 165 | `#5A8C3C` |
| Bare rock | 165 to 215 | `#9A8F80` |
| Snow | above 215 | `#F2F0E8` |
| Soil (under any surface) | - | `#8B6F47` |
| Tree foliage / trunk | - | `#4E7A32` / `#6B4F2A` |
| Water | - | `#4A90A4`, alpha 0.65 |

Warm and slightly saturated on purpose. Flat vertex colours, no textures.

### Content

- **Trees:** candidate cell every 4 blocks. Placement probability 0.12 in the
  middle of the forest band, tapering linearly to 0 at both zone edges. Simple
  voxel cone: trunk 3-5 blocks, canopy radius 2-3 blocks.
- **Lakes:** flood-fill basins in the coarse heightmap. A basin needs at least
  40 coarse cells (~160 m2) to become a lake - smaller ones are puddles and are
  discarded. Water is a flat translucent surface, non-interactive. No rivers.
- **Day/night:** 8 real minutes per in-game day by default. Sun angle only,
  plus fog and ambient tint. Visual, no gameplay effect yet.

---

## Architecture

Two decisions drive everything.

**1. Coarse global heightmap, fine local detail.**

Generate the whole world's heightmap once at 2 m resolution (750 x 750 = 562k
cells) at startup. It is cheap - it is just noise - and it makes three things
possible that per-chunk generation cannot: real basin detection for lakes, a
far-field mesh, and a minimap later. Per-block detail noise is added on top when
voxels are built, *after* lake levels are decided, so a bump cannot invent or
destroy a basin.

**2. Voxels near, heightmap mesh far.**

Real voxel chunks exist only within the voxel radius of the player - editable,
collidable, the actual game world. Everything beyond is one low-poly mesh built
straight from the coarse heightmap with the same flat vertex colours. This is
what makes a 200 m view distance reachable at all; 200 m of voxels would be
roughly 30,000 chunks.

The far mesh excludes the region covered by voxels, and is rebuilt when the
player crosses a chunk boundary.

---

## Stages

Ordered so that an incomplete run still leaves a playable world. Commit after
each.

### Stage 1 - tuning config and debug scaffolding

Build the instruments before the thing being measured.

- `scripts/world/worldgen_config.gd` - a `Resource` holding every number from
  the tables above. Give it `to_dict()` and `from_dict()`. **This matters for
  multiplayer:** the config is part of the determinism contract alongside the
  seed, and Stage 11 sends it in the join handshake. Build it serialisable now
  so that is a two-line change later.
- Hot-reloadable: load from `user://worldgen.tres` if present, else defaults,
  and re-read on a key press.
- On-screen debug readout: seed, position, altitude in blocks and metres,
  current elevation zone, FPS, loaded chunk count, and last generate/mesh
  milliseconds. **Include the timing numbers** - Marcel will be tuning against
  a performance budget and needs to see it.
- Seed input field plus a reroll key that regenerates in place.
- A tuning panel exposing: feature wavelengths, mountain height, treeline
  altitude, lake level offset, tree density, fog distances, day/night speed.

*Verify:* `--headless --editor --quit --path .` parses clean.

### Stage 2 - worldgen core: the layered heightmap

`scripts/world/terrain_generator.gd` - rewrite around the layer table.

This file is Marcel's learning material. Comment every layer with what it does
and why that wavelength. Keep the layers cleanly separated - no single fused
noise expression.

Order: `continent` -> `mountain` (ridged) -> `hills` -> valley flattening.

**Leave these three as `TODO(marcel)`, each with a working plain fallback so the
game runs regardless:**

1. **Ridge transform.** Fallback: use the raw fbm value. Hint: ridged noise is
   `1.0 - abs(n)`, then squared to sharpen the peaks and widen the valleys. Try
   it with and without the square and watch what happens to the skyline.
2. **Domain warp.** Fallback: sample at the plain coordinates. Hint: offset the
   sample position by a second low-frequency noise field before sampling the
   first - `sample(x + warp(x,z) * k, z + warp(z,x) * k)`. It is what stops
   everything looking grid-aligned. `k` around 40 blocks is a sensible start.
3. **Valley flattening curve.** Fallback: linear height. Hint: you want low
   altitudes compressed toward flat and high ones left alone, so valley floors
   are walkable and campfire-sized. A `pow(h, k)` remap with `k` near 1.6, or a
   `smoothstep`, both work - they feel different, and that difference is the
   exercise.

Also add a determinism self-check: a debug mode that generates the heightmap and
prints a hash of it. Two runs with the same seed and config must print the same
hash. This is the automated guard on the rule that matters most.

*Verify:* run the hash mode twice, confirm identical output.

### Stage 3 - voxels from the heightmap, with vertex colours

- Build chunk voxel data by sampling the coarse heightmap (bilinear) and adding
  the `detail` layer per block.
- Convert the existing mesher from textured to **flat vertex colours**. Keep the
  air-face culling. The block texture and its committed `.import` settings
  become unused - note that in the README rather than deleting the asset.
- Only build chunks within the voxel radius of the player, and only those that
  actually intersect terrain (surface plus a few chunks of depth), not the full
  vertical column.

*Verify:* `--headless --path . res://scenes/game.tscn --quit-after 600`, no
errors, chunk count sane.

### Stage 4 - third-person player

Deliberately early: from here on the world is walkable, so an unfinished run
still leaves something Marcel can play.

- Capsule 4 blocks tall, `CharacterBody3D`, gravity, collision against chunk
  meshes (`ArrayMesh` -> `create_trimesh_shape()` per chunk).
- Cube World style orbit camera: mid-distance follow, mouse orbits, collides
  with terrain so it does not clip into hillsides.
- Debug free-fly / noclip toggle on a key. Keep it - tuning terrain without it
  is miserable.
- **Third person only.** No first-person mode.
- Local physics for now. The existing provisional position-reporting stays;
  rewiring it into host-authoritative input is a later ticket, and Stage 11 does
  not change it.

*Verify:* headless run clean; the player falls and lands rather than falling
forever.

### Stage 5 - elevation zones and palette

Zone assignment from altitude plus `zone_jitter`, colours from the table.
Blend across a few blocks at each boundary so the transition is not a hard line.

*Verify:* headless run clean; log the zone distribution as a sanity check that
all four zones actually occur.

### Stage 6 - greedy meshing and threading

Now there is something to measure.

- Record the naive baseline in `STATUS.md` first (ms per chunk at the configured
  radius).
- Implement greedy meshing: merge coplanar same-colour faces into larger quads.
- Move mesh building to a worker thread; the main thread only uploads finished
  meshes, budgeted per frame.
- Record the after numbers next to the before.

*Verify:* headless run clean, and the two-peer test still passes.

### Stage 7 - far-field heightmap mesh

One `ArrayMesh` from the coarse heightmap at 4 m resolution, same zone colours,
excluding the voxel radius. Rebuild when the player crosses a chunk boundary.

*Verify:* headless run clean, mesh vertex count logged and under ~300k.

### Stage 8 - lakes

- Flood-fill the coarse heightmap to find basins. Fixed iteration order - never
  a `Dictionary` traversal - so it is deterministic.
- Discard basins under 40 cells.
- Each surviving basin gets a water level: its spill point minus a small config
  offset.
- Flat translucent water surface per lake. Non-interactive; no physics, no
  swimming.

*Verify:* headless run logs lake count and areas; two runs with the same seed
report identical lakes.

### Stage 9 - trees

Deterministic scatter hashed from `(seed, cell_x, cell_z)` - not `randf()`.
Simple voxel cones. Density per the table, tapering at forest zone edges.

**Watch the chunk-border bug:** iterate candidate cells over a region wider than
the chunk being built, so a tree whose canopy overhangs a boundary is generated
identically from both sides. This is the classic determinism failure here.

*Verify:* two runs, same seed, identical tree count; no seams at chunk borders
in the headless log.

### Stage 10 - fog and day/night

Sun angle rotates on the configured cycle. Warm dawn and dusk tints, darker blue
night, fog tinted to match. Fog distances from config. Visual only.

*Verify:* headless run clean across a simulated full cycle.

### Stage 11 - multiplayer determinism

Close the two holes this plan would otherwise open:

- Send the worldgen config alongside the seed in the join handshake
  (`Game._srv_send_world_state`). A client generating with different parameters
  is the silent-desync failure the README warns about.
- Make reroll a host-only action that clients follow. A client rerolling alone
  must be impossible.
- The tuning panel, while a session is live, either syncs from the host or is
  read-only. Read-only is acceptable and is the safer default.

*Verify:* the full two-peer test from `README.md`. Both peers must report the
same seed and the same config hash.

### Stage 12 - handoff

- **Screenshot tour:** a debug mode that places the camera at 6 fixed vantage
  points chosen to show mountain, forest, lake and a valley floor, captures a
  PNG at each, and quits. Deterministic camera positions derived from the seed.
  Write to `build/tour/`. Built last so it can never block terrain work.
- **`STATUS.md`** at the repo root: what got done, what did not, every
  measured number (chunk counts, ms per chunk before and after greedy meshing,
  lake count, tree count, frame times), every judgement call made, and the exact
  next step. Marcel reads this first in the morning.

---

## If something goes wrong

- Three fix attempts per stage, then commit what works and move on.
- Never leave the repo uncommitted or the game unable to launch.
- A stage that cannot be completed is not a failure of the run - an unfinished
  branch with no `STATUS.md` is.
- If the frame budget cannot be met at full scale, **reduce the voxel radius in
  the config rather than abandoning the stage**, and say so in `STATUS.md`. The
  config exists precisely so scale is a dial, not a rewrite.

## The acceptance test

Marcel's postcard test: within two minutes of walking from spawn, he should be
able to frame a mountain, its forested slopes, and a lake in one screenshot.

Nothing in this plan matters more than that.
