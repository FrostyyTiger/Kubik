# Kubik: world, terrain and rendering — audit against the bible

Scope: `scripts/world/*.gd` (excluding `flora/`), `gdext/src/*`, `gdext/SConstruct`,
`scenes/game.tscn`, `project.godot`, `assets/textures/`, and the four probe tools.
Evidence from `docs/plans` and `docs/status` for distance-v1..v5, terrain-v1..v2,
world-feel-v1, look-v1, look-v2, look-v2-tech, and `docs/research/distant-horizons.md`
and `terrain-tectonic.md`.

Bible read first: `00-TONE.md`, `style-bible/00-pillars.md`, `10-color-and-light.md`,
`20-world-and-terrain.md`, `30-architecture.md`, `70-scale-metrics.md`, `80-do-dont.md`,
`03-DECISIONS.md` (D1, D5–D8, D12, D15, D16, D18, D21, D26, D35, D40, D41),
`lore/10-geography.md`, `ROUND-3-BRIEF.md`, `ASSETS-PLAN.md`.

Test applied to every item: **would you build it this way today, for the bible?**

Note: `docs/status/terrain-v1.md` and `terrain-v2.md` do not exist — those two epics
wrote their status into repo-root `STATUS.md`, which has since been overwritten
(`docs/plans/terrain-v1.md:5`, `docs/plans/terrain-v2.md:511`). Their numbers survive
only in the plans and in `docs/research/terrain-tectonic.md`.

---

## 0. The four conflicts that decide everything else

Named, not softened. Everything in section 2 follows from these.

### C1. The lighting model is a toon poster. The bible asks for real light.

Pillar 2 (`style-bible/00-pillars.md:9`): *"lit like a photoreal shader: a real sun,
soft shadows tinted by the sky, volumetric fog, a real sky, clear water that
reflects."* D5 is Marcel's own wording (`03-DECISIONS.md:56`): *"Real light, flat
voxels. Shader-style lighting (real sun, soft shadows, volumetric fog, real sky, clear
reflective water)."*

| Bible asks | Engine has | Evidence |
|---|---|---|
| real sun, soft sky-tinted shadows | a **3-band toon quantiser**: `BAND_LIT 0.50`, `BAND_HALF 0.22`, `BAND_HALF_LEVEL 0.55`, `BAND_EDGE 0.03`. The shadow map is fed straight into the band, so the shadow's edge *is* the band's edge | `look.gd:101-104`, `look.gd:119-123`, `look.gd:126-149`; the note at `look.gd:88-93` |
| soft shadows | `shadow_blur = 0.25`, with the comment that blur "would only soften the one line the look is built on" | `sky_cycle.gd:154-159` |
| sky-tinted ambient | **ambient disabled entirely** — `ambient_light_disabled` in the render mode, `ambient_light_energy = 0.0` every frame. Ruled deliberately: *"sky ambient on top of it is exactly the 'grey everywhere' the poster is not"* | `look.gd:236`, `sky_cycle.gd:319-325` |
| volumetric fog | **depth fog quantised into 4 flat bands**, written per-material into `FOG`, with `fog_sky_affect = 0.0` and `fog_aerial_perspective = 0.0`. There is no `volumetric_fog_*` anywhere in the project | `look.gd:204-218` (quantise at `:206`), `sky_cycle.gd:374-390`, `worldgen_config.gd:940` |
| a physical sky | a hand-written **poster sky shader**: gradient quantised to 5 bands, alternating tapered Deco sun *wedges*, hard-threshold 2D noise clouds, a gold moon disc | `look.gd:354-550`; bands at `:472`; `poster_wedges()` at `:445-461`; `worldgen_config.gd:944` |
| clear water that reflects | `ROUGHNESS = 1.0; SPECULAR = 0.0`, alpha 0.92, three flat rings darkened 1.0/0.915/0.847. Non-reflection is an explicit ruling: *"No waves, no mirror reflection — the posters never do it"* | `look.gd:330-332,343-344`, `lakes.gd:390-429`, `docs/research/art-direction.md:405-407`, `docs/plans/look-v1.md:148-150` |
| glowing cubes: windows, fire, lamps, crystals (D15, `10-color-and-light.md:73-81`) | **no emissive world blocks and no point light has ever existed.** The ramp has a `!LIGHT_IS_DIRECTIONAL` branch, and *"nothing has exercised it"*; the campfire is still a plan. The world material forces `figure_emissive = 0.0` because an unconditional EMISSION line *"would set the entire world glowing"* | `look.gd:250-261`, `docs/status/look-v1.md:172-174`, `docs/plans/look-v2.md:478-480`, `docs/research/art-direction.md:532-536` |
| D40's film lens: grain, halation on emissives, soft roll-off, muted midtones, LUT | **no post-process stack at all.** No glow, no bloom, no vignette, no LUT, no colour adjustment, no SSAO/SSR. `tonemap_mode` is forced to `TONE_MAPPER_LINEAR`, exposure 1.0 — the one choice that makes "no clipped whites" impossible. The stated reason (*"a tonemapper that reshapes it is reshaping the art"*, measured: Filmic turned `#86B04A` into `#68D62F`) was right for a flat poster and is backwards for D40 | `sky_cycle.gd:362-372`, `scenes/game.tscn:19-24`; grep for `glow_*`/`adjustment_*`/`screen_space_*` returns zero |

The bible's forbiddens are all present as deliberate features:

- **Painting instead of lighting.** Five separate paint operations run before a vertex
  reaches the renderer: baked corner AO (`chunk_mesher.gd:37-60`), slope tint and
  aspect tint (`block.gd:229-249`), a hash jitter (`block.gd:200-213`), a canopy shade
  ink (`chunk_mesher.gd:106-116`), and on the far field an **altitude band** tint
  (`far_band_m := 60.0`, `far_band_step := 0.03`, `worldgen_config.gd:954-955`).
  Bible: mood *"comes from light, fog, the hour and the lens, never from repainting a
  thing"* (`00-pillars.md:9`).
- **Dithering.** A 4×4 Bayer screen-space dissolve spliced into the far material
  (`look.gd:898-919, 933-942`), plus zone dithering in worldgen.
- **"The poster register."** `docs/DESIGN.md:24-32` retired the poster as a *rendering*
  register on 2026-09-01 — *"the flat sheet is gone everywhere, near and far"* — but
  the code did not follow. `look.gd:3` still opens `## The poster.`, and
  `poster_band`, `poster_fog_at`, `poster_wedges`, `LIT_BLEACH` and `SKY_SHADER` are
  still what draws every pixel. `docs/DESIGN.md:112-118` leaves exactly one question
  open for look v3: *"whether the fog's step stays banded or softens."* The bible
  answers it: volumetric, not banded.
- **Textures instead of light** — this one the repo gets **right**.
  `assets/textures/block_placeholder.png` is the only texture in scope and **nothing
  references it** (grep: zero users; said in a comment at `chunk_mesher.gd:10-13`).
  Hard rule: *"No new textures. None."* (`docs/plans/look-v2.md:462-463`). Pillar 2's
  "no photo textures, on anything, ever" is already true and should stay true.

One piece matches the bible by accident and should be kept: the **per-cube grain** at
`look.gd:238-300` is a hash of the 0.5 m world cell perturbing value and hue — exactly
the bible's *"a little per-cube noise (one step up or down on random cubes)"*
(`10-color-and-light.md:57`). It was measured under-strength: V sd **0.89** against a
plan target of 3–9, and reaching sd 3 needs `grain_amount ≈ 0.15` against a slider
range of 0.04–0.08 (`docs/status/look-v2.md:470-491`). Keep the mechanism, raise the
range.

### C2. The world is 1:4 against reality and 3 km wide. The bible wants a real-sized Alps and 10 km of sight.

`docs/DESIGN.md:522` — *"Scale: the world is 1:4 against reality."* Mountain relief
**~350 m** in game for a real 1,400 m (`DESIGN.md:534`); largest lake **~116 m**
(`:533`). `worldgen_config.gd:50` `world_scale := 4.0`; `:72`
`REAL_MOUNTAIN_RELIEF_M := 1400.0`; `:1940-1951` derives `base_altitude 183.5` /
`max_altitude 833.7` blocks (91.75 m / 416.85 m) from it — and that ceiling is a
**hard clamp, not a ramp, so a summit that reaches it goes flat**
(`docs/research/terrain-tectonic.md:582-583`).

Bible: pillar 3 is *"Monumental against tiny, in a real-sized Alps"*
(`00-pillars.md:12`). D41 (`03-DECISIONS.md:263`) makes 10 km an **engine requirement,
not a style choice**, and `70-scale-metrics.md:60` sets it: *"Far world drawn on a
clear day — at least 10 km."*

Today: `world_blocks_xz := 6000` = **3 × 3 km, bounded**, diagonal 4,243 m
(`worldgen_config.gd:106-113`). Far reach at High/Ultra is `fog_end 3,200 m` → far
radius 3,840 m → camera far plane 4,000 m (`worldgen_config.gd:188-191`;
`docs/status/distance-v3.md:676-678`). **You cannot see 10 km because there is no
10 km of world**, not because the far field cannot draw it.

The rendering half is already answered, twice over, in the repo's own numbers:
- `docs/plans/terrain-v2.md:168-173`: *"Rendering was never the constraint; **LOD rings
  make a 10 km view cost about 356k vertices**, less than 600 m costs uniformly today.
  **Traversal was the constraint.**"*
- `docs/status/distance-v3.md:682-683`: *"**A preset reaching ten kilometres would want
  a sixth row in the table and nothing else.**"*
- Measured: reach 960 m → 3,840 m is **16× the visible area for +22.3% vertices**
  (262,312 → 320,764) — `docs/status/distance-v3.md:705, 714-716`.

The traversal argument that killed full scale (`DESIGN.md:641-650`,
`terrain-v2.md:168-173`: a 15 km world has a 21 km diagonal, ~35 minutes' sprint
corner to corner, the failure that damaged Cube World 2019) assumed **a bounded world
you must cross on foot**. The bible's world is unbounded and its traversal answer is
airships, cog rails, cable cars and a ferry (`lore/10-geography.md:38-42`). The sunk
argument does not survive the bible.

Caveat to be honest about: `docs/status/distance-v3.md:717-727` warns that ring 4 is
nearly free *only on this region* — most of it falls outside `heightmap.in_bounds` and
emits nothing. *"On an unbounded world it would cost what ring 3 costs. Said here so
nobody reads +22% as a general law."* So 10 km is affordable, not free.

Two internal inconsistencies the bible resolves:
- **Trees are already 1:1**, authored at world size 21–28 m; the 1:2 row was retired by
  trees v3 (`DESIGN.md:551-578`). Bible forest tree is 9–28 m
  (`70-scale-metrics.md:18`). **Trees match the bible; terrain does not.** The world is
  currently mixed-scale in exactly the way `DESIGN.md:526` warns against.
- **Block and player match the bible exactly.** `block_size := 0.5`
  (`worldgen_config.gd:36`), player capsule 2.0 m = 4 blocks (`DESIGN.md:380`). D1
  satisfied. The character *voxel* does not (24/block = 2.08 cm, `DESIGN.md:352`, vs
  the bible's ~15/block = 3.3 cm from the bought templates, `03-DECISIONS.md:17`) —
  the character audit's problem, but a real conflict.

### C3. GDScript worker threads are serialised. This is the fact that decides the C++ question.

Measured, twice, in two epics:

- `docs/status/world-feel-v1.md:143-147`: *"3,742 chunks × 7.6 ms of worker time =
  28.4 s of work, in 29.5 s of wall clock. **That is ~1.0 effective worker threads.**
  GDScript is serialised across the pool in this build."*
- `docs/research/terrain-tectonic.md:612-615`: *"GDScript worker threads are serialised
  in this build — **two workers took exactly as long as one, sixteen took 4× longer.**"*
- `docs/plans/world-feel-v1.md:47-49`: measured, **6 jobs slower than 4**.
- `docs/IDEAS.md:311-317`: *"Every streaming improvement in that plan came from doing
  less work, **because doing it in parallel is not available**."*

`project.godot:145-157` raises `worker_pool/low_priority_thread_ratio` to 0.75 to give
the world build most of the machine — and it buys nothing while the language holds one
lock. **Every GDScript hot path in this project is running single-threaded on a
multi-core box.** That is the whole argument, and it is already in the repo.

### C4. Rings, regions and weather do not exist.

`lore/10-geography.md:12-22` makes wildness distance from the **Engineers' capital**,
driving biome, wildness, ruin size, weather severity and lit-window density; D35
(`03-DECISIONS.md:233`) confirms *"generation by distance from the capital."*

The repo has a proto-version: `TerrainGenerator.wildness_at()`
(`terrain_generator.gd:690-694`) is Chebyshev distance from the **world origin**
normalised by **half the world width** — a bounded-world assumption — driving exactly
two things: mountain relief (`wildness_relief := 0.35`, `worldgen_config.gd:922`) and
the rock-zone slope threshold (`wildness_rock_deg := 12.0`, `:927`).

No regions (autumn is one *global* `season` knob for tree palettes,
`worldgen_config.gd:1358-1363`; no wild-colour region, no winter region). **No weather
at all** — grep for rain / snowfall / eerie across `scripts/world/` returns nothing.
D16 and the eerie state (`10-color-and-light.md:42-44`, ROUND-3-BRIEF items 5–6) are
unbuilt.

---

## 1. Inventory

| # | System | Files | Lines | Lang | What it does | Measured cost |
|---|---|---|---|---|---|---|
| 1 | **Block table & palette** | `block.gd` | 279 | GDScript | 24 block ids (the wire format for edits), one flat linear colour each; plus `jitter()`, `aspect_shade()`, `aspect_curve()` — per-vertex tint machinery that fakes variation without splitting greedy quads. | — |
| 2 | **Chunk store** | `chunk.gd` | 119 | GDScript | 16³ (8 m cube) `PackedByteArray` with `has_air`/`has_solid`; floor-div coordinates. | 4,096 B/chunk; cache 3,000 chunks ≈ **128 MB** (42.8 MB per 999 chunks, `docs/status/world-feel-v1.md:367-372`) |
| 3 | **Chunk mesher** | `chunk_mesher.gd` | 521 | **GDScript** | Greedy meshing per axis with 4-corner baked AO folded into the merge key; emits vertex colours through jitter → aspect → AO → canopy ink → `to_wire`. | naive 16.7 ms/chunk vs 1.9 ms to generate (`chunk_mesher.gd:19-21`); today **29.63 ms/column = 76% of the 39.03 ms column job** (`docs/status/trees-v3.md:984-985`) |
| 4 | **Chunk node** | `chunk_node.gd` | 180 | GDScript | `MeshInstance3D` + `StaticBody3D`/`ConcavePolygonShape3D`; per-zone friction; park/unpark. | main-thread upload **0.14 ms/chunk** (`trees-v3.md:1005`) |
| 5 | **Column job** | `column_job.gd` | 172 | GDScript | One worker task per column: voxels for every chunk to the ceiling, tree-cover scan, mesh, collision faces. | **39.03 ms/column** (was 242.5): gen 5.81, tree scan 3.59, mesh 29.63 (`trees-v3.md:982-985`) |
| 6 | **World streamer + mutation path** | `world.gd` | 2001 | GDScript | Owns every chunk; a disc of columns of radius `voxel_radius_chunks`, nearest-first queue, 3,000-chunk park cache, per-peer collision rings, 16-sector loaded frontier; and the one host-authoritative block-edit path. | load to playable **19,322 ms / 2,222 chunks** (`trees-v3.md:1002-1003`); gen 4.07 ms/chunk on workers; supply **60–150 chunks/s** vs a sprint's demand of **~275/s** (`docs/plans/world-feel-v1.md:39-43`) |
| 7 | **Terrain generator** | `terrain_generator.gd` | 1346 | GDScript (+C++ tiles) | 4 summed noise layers (continent 1,577 m / mountain 394 m / hills 180 m / detail 6 m) with masks, warp, terraces, benches, plateaus, valley flattening; 7 zones by **area share** with slope overrides. | `_resolve_zone_thresholds` **~3.3 s** at 2 m cells, ~13 s at 1 m (`STATUS.md:129`, `docs/status/distance-v5.md:721-723`); heights quantised to 1/1024 block (`terrain_generator.gd:499`) |
| 8 | **Heightmap + pyramid + tiles** | `heightmap.gd` 488, `height_tiles.gd` 115, `gdext/src/height_tiles.{cpp,h}` 343 | 946 | GDScript **and** C++ | One region-wide float array at 4 blocks (2 m)/cell — 1500×1500 = 2.25 M cells — plus a 6-level min/max mip pyramid; built in 512-block tiles, in C++ when the library is present. | **16,713 ms → 4,753 ms (3.5×)** (`docs/status/distance-v5.md:550-551`); per tile **116 ms → 10 ms** (`:633-637`); pyramid +2.9 MB, 214 ms (`docs/status/distance-v1.md:266-268`) |
| 9 | **Lakes** | `lakes.gd` | 456 | GDScript | Priority flood over the whole heightmap **seeded from the map border**; flat 3-ring water mesh with per-ring darkening. | **~1.5 s** at 2 m cells; **17,491 ms at 1 m — 11.7× for 4× the data**, "the biggest single number in a world load" (`STATUS.md:127-128`, `docs/status/distance-v5.md:711-717`); 53 lakes at seed 42 |
| 10 | **Far field (build)** | `far_field_job.gd` 1951, `far_mesher.gd` 309, `gdext/src/far_build.cpp` 937 + `far_world.h` 374 + `far_mesher.{cpp,h}` 208 | 3779 | GDScript **and** C++, bit-identical twins | Disc of 6 LOD rings (2/4/8/16/32/64 m cells at `far_ring_div 4`, boundaries 150/300/600/1200/2400 m) from the heightmap pyramid, with skirts, a detail seam band, terracing, geomorphing, majority-vote zone colour, altitude bands, flank-averaged normals. | at div 4: **3,266,076 verts**; rebuild **C++ 661 ms vs GDScript 24,722 ms — 37.4×** (`docs/status/distance-v4.md:311-314`); at div 2 **158 ms vs 6,430 ms — 40.7×**; whole far probe **313,455 → 27,236 ms** (`:352-354`) |
| 11 | **Far field (node + upload)** | `far_field.gd` 570, `far_upload.gd` 192 | 762 | GDScript | Dispatches C++ or GDScript on a worker, then hands 16 frontier-sector slices to the renderer on a per-frame budget and swaps the finished mesh atomically. | whole-mesh `arrays_to_mesh` **224.16 ms main-thread** at div 4, 56.17 at div 2 (`docs/status/distance-v4.md:329-330`); sliced: worst slice **15.90 ms**, ~16 frames a rebuild at a 4 ms budget; sprint worst frame **244.4 → 39.6 ms**, frames > 33 ms **60 → 4** (`docs/status/distance-v5.md:870-879`); ~**120 MB** per handover, static memory 326.2 → 449.9 MB at div 4 (`:218-225`, `docs/status/distance-v4.md:537`) |
| 12 | **Look (all shaders & materials)** | `look.gd` | 1128 | GDScript (GLSL strings) | The whole renderer: 3-band toon `light()`, banded cylindrical fog, per-cube grain, contact band, the poster sky, water, the far-grain/Bayer splice, tree-sway splice, `to_wire()`, `predict()`. | swatch gate: worst channel delta **2** against a tolerance of 6, both renderers (`docs/status/look-v2.md:861-877`) |
| 13 | **Sky cycle** | `sky_cycle.gd` | 397 | GDScript | 4 keyframes × 11 rows (dawn/noon/dusk/night) blended by sun elevation; drives the sun basis, the shader globals, the sky uniforms, environment fog, tonemap. | full day **480 s** (`worldgen_config.gd:1570`); sun energy 0.85/1.00/0.90/0.75 |
| 14 | **Worldgen config** | `worldgen_config.gd` | 2134 | GDScript | ~200 exported knobs, 4 view presets, world-hash vs local split, `apply_world_scale()`, `apply_view_preset()`, F4 live tuning. | presets: low 6/400 m, medium 8/500 m, **high 12 chunks (96 m voxels) / 3,200 m fog**, ultra 16/3,200 m (`:188-191`); voxel radius is quadratic — **1,201 chunks at 8, 2,653 at 12, 4,829 at 16** (`docs/plans/terrain-v2.md:86-90`) |
| 15 | **World hash** | `world_hash.gd` | 53 | GDScript | Deterministic coordinate hash with salts. | — |
| 16 | **Scene & environment** | `scenes/game.tscn`, `project.godot` | 69 + 157 | — | `WorldEnvironment` with a placeholder `ProceduralSkyMaterial`, one `DirectionalLight3D` with shadows, `tonemap_mode = 2`; 8 global shader params for the hour; Jolt; low-priority thread ratio 0.75. | — |
| 17 | **Textures** | `assets/textures/block_placeholder.png` | — | — | **Unused.** Zero references. | — |
| 18 | **Probes** | `far_probe.gd` 1325, `stream_probe.gd` 408, `worldgen_probe.gd` 721, `screenshot_tour.gd` 1240 | 3694 | GDScript | Far probe: deterministic fizz/roughness/peak-loss tables run twice per session, exits non-zero on a one-character drift. Stream probe: holes and long-frame gate on a sprint. Worldgen probe: slope histogram, altitude percentiles, zone shares, object-scale-vs-reality. Tour: 12 world-derived vantages, labelled A/B runs. | far probe is deterministic and machine-independent (`far_probe.gd:14-25`). **Stream probe is a gate, not an instrument** — same commit gave PASS PASS FAIL; spread 0–40 long frames and 61–151 chunks/s across ten runs (`stream_probe.gd:12-23`, `docs/status/world-feel-v1.md:1268-1278`) |

Total in scope ≈ **14,700 lines**, of which **1,922 are C++** — and every C++ line is a
**transcription of a GDScript original still in the tree** (`far_mesher.gd:6-12`,
`far_world.h:10-13`, `height_tiles.gd:31-36`).

---

## 2. Verdict per system

Effort: **S** under a day, **M** days, **L** a week or more.

### KEEP

| System | Why (bible rule) |
|---|---|
| **Chunk store** (`chunk.gd`) | 16³ flat byte array, floor-div coords, has_air/has_solid. Nothing in the bible touches it; you would write it the same way today. |
| **World hash** (`world_hash.gd`) | Determinism by coordinate hashing is what lets an unbounded seeded world exist (`lore/10-geography.md:14`). Exactly right. |
| **The single host mutation path** (`world.gd:1668-1802`) | This *is* the bible's habit 3 / D34: request → host validates → applies → broadcasts; clients never write; edits arriving for in-flight chunks are recorded and replayed at collection; every accepted edit is journalled past the validate and no-op gates (`world.gd:1782-1784`). Built and correct. |
| **The streamer's shape** (disc of columns, nearest-first, hysteresis, 3,000-chunk park cache, 16-sector frontier, per-peer collision rings) | An unbounded world (D41, `CLAUDE.md:54`) needs exactly this. The frontier is the machinery that makes "never pops in" enforceable — `FRONTIER_OVERLAP_CELLS := 8` took hole samples from 126-of-144 to **zero** (`docs/status/world-feel-v1.md:249-274`). |
| **Per-cube grain** (`look.gd:238-300`) | Literally the bible's material rule (`10-color-and-light.md:57`). Hashed on the 0.5 m cell, faded by 45 m. Keep the mechanism; raise the range (measured sd 0.89 vs a 3–9 target). |
| **The far-field LOD ring ladder** (`far_field_job.gd:60-128`) | The one system here that already answers a bible decision. **16× the visible area for +22.3% vertices** (`docs/status/distance-v3.md:705,714-716`), and the code says the rest out loud at `far_field_job.gd:98-102`: *"NOTHING HERE READS THE WORLD'S SIZE … a preset that reached ten kilometres would want a sixth entry and nothing else."* |
| **`FarUpload`** (`far_upload.gd`) | Main-thread `add_surface_from_arrays` is unavoidable; this pays it on a budget with an atomic swap and drops superseded jobs. Sprint worst frame 244.4 → 39.6 ms. Any 10 km far field needs this or its twin. |
| **The seam discipline** (`far_mesher.gd:14-29`, `height_tiles.gd:20-36`) | Data in, arrays out, marshalled once per world; engine `FastNoiseLite` refs sampled natively so noise is bit-identical by construction; **every height quantised to 1/1024 block on both legs** so gcc and MSVC cannot produce two worlds. This is the engineering that makes world-truth in C++ safe, and it must survive any rewrite. |
| **The probes** | ROUND-3-BRIEF asks for measured answers on the distance test, colour sampling, fog, view distance and cost. `screenshot_tour.gd` already drives 12 world-derived vantages with labelled A/B runs; `worldgen_probe.gd` prints an object-scale-vs-reality table; `far_probe.gd` is deterministic. These are the instruments round 3 is graded with. Do not throw them away. |
| **`assets/textures/`** | Unused; pillar 2's "no photo textures, ever" is already satisfied. |

### ADAPT

| System | Conflict | Change | Effort |
|---|---|---|---|
| **Block palette** (`block.gd:104-141`) | Bible materials are **one body colour in three shades** plus per-cube noise, with named hexes (rock `#3e3734/#5e524b/#8b8a83`, snow `#cfd6dc/#e6dad1/#f4f1ee`, conifer `#575d54/#7e8986/#9b9f81`, lake `#265f6e/#42c1c9`, `10-color-and-light.md:55-72`). Repo has **one flat colour per id** (stone `#ADA9A1`, grass `#809945`, snow `#F2F0E8`) with shading synthesised by the toon ramp. | Re-author to the bible's hexes. Under pillar 2 the three shades should come from *light* (sun / sky-tinted shadow / half-lit), not from three authored entries — which makes this a data edit. | S |
| **Snow rule** (`worldgen_config.gd:455-471, 555`) | Bible: *"Any upward-facing cube above the snow line is snow"* — an altitude line (`20-world-and-terrain.md:23`). Repo: snow is **5% of map area** by histogram, gated by a 72° slope cutoff. There is no snow line. | Make an explicit snow-line altitude the primary rule; keep the slope cutoff as the modifier (it is good: *"snow does not sit on a cliff, it slides off"*, `docs/plans/terrain-v2.md:436-439`). "Below the line in winter regions or during snowfall" needs regions and weather first. | M |
| **Zones** (`terrain_generator.gd:78-90`) | Repo: shore/meadow/forest/alpine/heath/rock/snow by percentile (4/30/26/14/10/11/5%). Bible: valley floor / forest belt / tree line / alpine rock / peaks (`20-world-and-terrain.md:11-17`), tied to what stands in them (castles at the tree line, landmarks on knolls). **And percentile zoning does not survive an unbounded world** (`docs/research/terrain-tectonic.md:554-561`). | Remap to the bible's bands, expose the tree line as a queryable altitude for site placement, and replace percentiles with something regional. The histogram machinery is reusable inside a region. | M |
| **`wildness_at`** (`terrain_generator.gd:690-694`) | Right idea, wrong origin, wrong consumers, bounded normalisation. | Rebase on distance from the capital's world position in **metres**, and make it drive the ring table in `lore/10-geography.md:16-22`: biome, weather severity, ruin size, lit-window density. **The single highest-leverage adapt in the area** — it is how the bible's world is shaped. | M |
| **`WorldgenConfig`** | The right pattern (facts as data, live F4 tuning, hashed-vs-local split for determinism), but roughly a third of its knobs exist to tune the poster: `fog_bands`, `sky_bands`, `far_band_m`, `far_band_step`, `far_riser_shade`, `far_riser_lift`, `far_dither_m`, `far_grain`, `contact_band`, `grain_sparse`, `far_terrace`, `far_step_y_blocks`. | Strip look knobs as their systems are cut. Keep terrain, streaming, presets. Add `snow_line_m`, `capital_position`, `ring`, weather. The four `VIEW_PRESETS` need a 10 km row. | M |
| **`SkyCycle` structure** (`sky_cycle.gd:34-59`) | Four keyframes × eleven rows blended by sun elevation, pure and headlessly testable — the right *machine* for the bible's hours. Wrong contents and wrong count: the bible wants **day / evening (pink) / dusk (violet) / night (slate)** as four hours plus **eerie** as weather-on-top (D6, D7, `10-color-and-light.md:29-44`). | Re-author the table to the bible's hexes; split evening from dusk; add an eerie modifier that desaturates, thickens fog and kills warm lights. Keep `keyframe_at`, `light_direction`, `night_amount`, the frozen-clock hook the tour needs. Drop the `accent` column — repo rule 5's "one gold accent with an hour" (`look.gd:628-638`) has no bible counterpart, and the bible's gold is a *material* (`10-color-and-light.md:71`). | M |
| **Heightmap tiles** | The tile builder is right and already in C++ — but the store is not. `heightmap.gd:56-62` states it: *"the tiles still write into ONE region array … the global-extent assumption has moved out of the BUILDER and not yet out of the STORE."* Also `height_at()` **clamps and returns the edge value** outside bounds (`docs/research/terrain-tectonic.md:469-477`), `world_blocks_xz` is in the determinism hash and the join handshake, and lakes seed on the map border. | Give each tile its own array, add the apron, move lakes / spawn / zone thresholds / far-marshal onto a tile-addressed API. Called *"a change across eight files whose acceptance gate is a byte-identical world"* (`STATUS.md:139-148`). `terrain-tectonic.md:479-484` notes this is *"a live contradiction with the design … and there is no roadmap epic, plan or TODO item for it."* | L |
| **Far ring table** (`far_field_job.gd:103-108`) | Reaches 3,840 m; D41 wants ≥10 km, costed by the repo at **~356k vertices** (`docs/plans/terrain-v2.md:171`). | Add ring 6 (128 m cells) and a fifth preset. **Buys nothing until the world is bigger than 3 km.** | S (after C2) |

### RIP

| System | Bible rule violated | Effort |
|---|---|---|
| **The toon light ramp** — `look.gd:100-151` (`poster_band`, the three bands, shade-as-ink, `LIT_BLEACH`) | Pillar 2 and D5 want a real sun with soft sky-tinted shadows; D8 (`03-DECISIONS.md:80`) names hard shadows as the thing not to do outdoors. A hard quantiser of `n·l × ATTENUATION` with ambient off is the opposite. Let Godot's own PBR light the flat cubes, with sky-coloured ambient for the tinted shade. | M |
| **`shadow_blur 0.25` + `light_specular 0.0` + `ambient_light_energy 0.0`** (`sky_cycle.gd:157-159, 325`) | Direct contradictions of D8 and pillar 2. They exist only to serve the ramp. | S |
| **Banded fog** (`look.gd:206`, `worldgen_config.gd:940`) | Bible fog does **three jobs** — valley bands, pooling at feet, hiding tops (`10-color-and-light.md:83-89`) — and lowers saturation as well as contrast. A depth fog quantised into 4 steps and written per-material into `FOG` does none of the three and *cannot*: valley bands and pooling are **height fog**, which needs a volumetric density field. Carry over the exp² curve and the cylindrical distance (`look.gd:188-226`) as tuning; the band quantiser and the per-material `FOG` write go. Also note the bands are already stretched past their tuning: `fog_bands 4` was tuned against a 480 m span and now covers 1,920 m, moving the first band boundary from 400 m to **1,558 m** (`docs/status/distance-v3.md:41, 977`). | M |
| **The poster sky shader** (`look.gd:354-550`) | D18 says **cubic clouds** and `20-world-and-terrain.md:27` says *"the world is cubes all the way up."* The shader draws hard-threshold 2D-noise lozenges on a 5-band gradient with alternating Deco sun wedges. D5 restricts teal-gold rays to the capital and moments of triumph; here they run at **every** hour (`sky_cycle.gd:351-352`). Pillar 2: *"Real sky … no painted skies."* Replace with a physical sky plus real cube-voxel cloud volumes. | L |
| **The far field's altitude bands, flank-averaged normals, riser shading** (`worldgen_config.gd:954-959`, `far_field_job.gd:1382-1407`) | These exist *because* the toon ramp facets — `far_field_job.gd:1390-1396` says so: *"The poster ramp in Look paints three flat tones, and on a facet normal that means every triangle of a mountain picks its own tone."* Under real light with soft shadows the problem does not exist and the fix is dead weight painting colour where the bible wants light. | M |
| **The Bayer dither dissolve** (`look.gd:898-919, 933-942`) | D41: *"Popping — none; far things arrive out of fog, never at a boundary."* An ordered screen-space dither *is* a boundary artefact. The bible's answer is fog. Keep the ring geomorph instead — it took worst ring-boundary fizz from **147.00 to 39.00 blocks** with roughness going *up* (`docs/status/distance-v5.md:455-458, 924`). | S |
| **Flat non-reflective water** (`look.gd:326-351`, `lakes.gd:390-429`) | D5 and pillar 2 name *"clear reflective water"*; `20-world-and-terrain.md:26`: *"Water is clear and reflects."* The repo ruled the opposite in writing (`docs/research/art-direction.md:405-407`). Rebuild on a real water material with screen-space or planar reflection. | M |
| **The `Environment` and the linear tonemap** (`scenes/game.tscn:19-24`, `sky_cycle.gd:362-372`) | D40 wants *"soft highlight roll-off; no clipped whites except the sun's disc"* and *"muted midtones"*. `TONE_MAPPER_LINEAR` at exposure 1.0 is the one choice that makes that impossible. No glow means no halation; no volumetric fog means no fog jobs; no adjustment/LUT means no grade. Rebuild the environment. | S |
| **`world_scale := 4.0`** (`worldgen_config.gd:50`, `DESIGN.md:522-540`) | Pillar 3's real-sized Alps, D21 (already honoured by trees), D41's 10 km. The written rejection of full scale (`DESIGN.md:641-650`) rests on a bounded-world traversal argument the bible replaces with airships, rails and ferries. Note the shape problem too: the macro:feature wavelength ratio is **4:1** (3,155 blk continent against 787 blk mountain) where a real range is ~52:1, so *"a 'massif' is three or four mountain wavelengths wide, which is a cluster, not a range"* (`docs/research/terrain-tectonic.md:495-496, 524-530`) — against a bible that asks for *"a long continent with the Alps as its spine"* and *"peaks several ridges deep"*. | M (one knob; re-tuning and re-judging is the work) |
| **`world_blocks_xz := 6000` and every reader needing a map edge** — the lakes' border-seeded priority flood (`lakes.gd:16-17, 228`), `wildness_at`'s half-width, `height_at()`'s clamp, percentile zoning | D41 and `CLAUDE.md:54-58`. A bounded 3 × 3 km world cannot hold rings 0–4 (capital valley → alpine heartland → coasts and desert → near islands → far islands), let alone a 10 km sightline. | L |

### REDO

| System | Why a redo rather than an adapt | Effort |
|---|---|---|
| **`look.gd` as a whole** (1,128 lines) | Everything load-bearing is on the RIP list: the band ramp, the banded fog, the poster sky, flat water, altitude bands, the dither. What survives is the per-cube grain (~60 lines), the sRGB-on-the-wire discipline (~10 lines), the material caching and the shader-splice trick. You would not start from this file to build "real light on flat cubes through a film lens". **Redo as a thin materials module over standard Godot PBR**, plus a `CompositorEffect` post chain for D40 (grain, halation on emissives only, soft roll-off, LUT, gentle vignette). Carry `to_wire()`, the grain, and `predict()`'s discipline — the swatch gate (worst channel delta 2 against a tolerance of 6, `docs/status/look-v2.md:861-877`) is exactly what ROUND-3-BRIEF's colour-sampling test needs. | L |
| **The chunk mesher's colour path** (`chunk_mesher.gd:326-360`, `block.gd:172-279`) | Baked AO + slope tint + aspect tint + hash jitter + canopy ink are five paint operations doing what light should do. The greedy *geometry* is correct and worth keeping; the colour path is not. Emit one flat albedo per material plus the bible's per-cube noise; let real light and SSAO/SSIL do the rest. This also removes the AO-vs-merge constraint at `chunk_mesher.gd:46-60`, which makes merged quads bigger and the mesher faster — a saving, not a cost. | M |
| **Fog, as a system** | Nothing to adapt: the bible's three jobs need a **volumetric fog volume with a height/density field**; the repo has a per-material depth-fog band quantiser. Different mechanism. Rebuild on `Environment.volumetric_fog_*` plus `FogVolume` nodes for the valley bands and the pooling, carrying the exp²/cylindrical curve as the far-distance term. | M |
| **Warm light** — glowing windows, fire, lamps, crystals (D15, `10-color-and-light.md:73-81`, tone's *"rare warm light"*) | Does not exist. No emissive world block; the ramp's point-light branch has **never been exercised** (`docs/status/look-v1.md:172-174`); there is no campfire, no window, no lamp, no crystal, and no cost measurement for any of it because nothing has been built to measure. The tone pillar's most-named image — *"a lit window in a valley at dusk should land like the song's swell"* (`00-TONE.md:35`) — is the single biggest unbuilt thing in this area. | M |
| **Weather + eerie** | Does not exist. D16, and ROUND-3-BRIEF items 5–6. | M |
| **Regions** | Does not exist beyond a global autumn `season` flag. D12/D26 need alpine / autumn / wild-colour / winter, each recognisable *from a distance by tree colour alone* (`20-world-and-terrain.md:40`) — so the region must reach the far field's zone-colour vote too. | M |
| **The C++/GDScript twin arrangement** | See section 3. | L |

---

## 3. GDScript versus C++

### Where the time goes — measured

| Work | Where | Cost | Source |
|---|---|---|---|
| Chunk meshing | **GDScript**, worker | **29.63 ms/column = 76% of the column job** | `trees-v3.md:984-985` |
| Voxel generation | GDScript, worker | 5.81 ms/column (4.07 ms/chunk) | `trees-v3.md:982, 1004` |
| Coarse heightmap | **C++** (GDScript fallback) | **16,713 → 4,753 ms (3.5×)**; per tile **116 → 10 ms (11.6×)** | `distance-v5.md:550-551, 633-637` |
| Zone thresholds | GDScript, load | **~3.3 s**; ~13 s at 1 m cells | `STATUS.md:129`, `distance-v5.md:721-723` |
| Lakes priority flood | GDScript, load | **~1.5 s**; **17,491 ms at 1 m (11.7× for 4× data)** | `STATUS.md:127`, `distance-v5.md:711` |
| Far mesh build | **C++** (GDScript fallback) | **661 ms vs 24,722 ms at div 4 (37.4×)**; 158 vs 6,430 ms at div 2 (40.7×); 46× on MSVC | `distance-v4.md:311-314, 651` |
| Far mesh upload | **GDScript, main thread** | 224.16 ms whole; worst slice 15.90 ms on a 4 ms budget | `distance-v4.md:329-330`, `distance-v5.md:917` |
| Chunk mesh upload | GDScript, main thread | 0.14 ms/chunk | `trees-v3.md:1005` |
| **Load to playable** | | **19,322 ms, 2,222 chunks, 96 m of voxels, in a 3 km world** | `trees-v3.md:1003` |

And the fact that outranks all of them: **GDScript worker threads are serialised in
this build.** 3,742 chunks × 7.6 ms = 28.4 s of work took 29.5 s of wall — *"~1.0
effective worker threads"* (`docs/status/world-feel-v1.md:143-147`). Two workers took
exactly as long as one; sixteen took **4× longer**
(`docs/research/terrain-tectonic.md:612-615`). Six jobs measured slower than four
(`docs/plans/world-feel-v1.md:47-49`). Every streaming win in world-feel-v1 came from
*doing less work, because doing it in parallel is not available*
(`docs/IDEAS.md:311-317`).

That is the whole case. A solo developer's box has 6–16 cores and the world build is
using one of them.

### What must be in C++ for the bible

Marcel already approved the ladder (`docs/plans/distance-v4.md:16-27`): 1. far mesher;
2. chunk mesher; 3. worldgen (generator, heightmap, lakes); 4. flora. Rung 1 landed;
rung 3's heightmap half landed. The current STATUS says the chunk mesher is *not*
next (`STATUS.md:135-137`) — but that was written when tree stamping dominated
(125.4 ms of a 242.5 ms column). Trees v3 deleted it, and **the mesher is now 76% of
the column job**. That conclusion is one epic stale.

Order for the bible:

1. **Chunk mesher.** 76% of the column job, single-threaded GDScript, and it gets
   *worse*: the bible's built world (landmarks 120–240 cubes, castles 80–160, houses
   18–30, `70-scale-metrics.md:14-26`) puts far more solid geometry in a column than a
   heightmap does, and greedy-meshing a fluted stepped gold-lined landmark is many
   times the work of meshing a hillside.
2. **Voxel generation / `column_surface_range`.** Named as a rung (`STATUS.md:131-133`)
   and the reason the sprint's collidable front collapses 56 m → 8 m at finer cells.
3. **Lakes and the zone histogram.** ~4.8 s of a 19.3 s load between them; both are
   single passes over a large float array; both scale 11.7× and 4× badly.
4. **Far mesh.** Already done, 37–46×. Do not touch the C++.

Fine in GDScript: `world.gd`'s streaming *policy* (scheduling, not arithmetic),
`sky_cycle.gd`, the config, the probes, `chunk_node.gd`, `far_upload.gd`, material
setup.

### Is the current architecture a foundation?

**The seam is right. The twin-implementation rule is not.**

Right, and worth carrying forward verbatim:
- **Data in, arrays out, marshalled once per world** (`far_mesher.gd:14-20`): *"A
  cross-language call per cell is how a 30× speedup becomes 1.5×, and forbidding it at
  the seam is cheaper than measuring it out later."*
- **Engine `FastNoiseLite` refs sampled natively** (`far_mesher.gd:22-29`,
  `height_tiles.gd:54-59`) — bit-identical by construction, not by reimplementation.
- **Quantisation at the seam** (`terrain_generator.gd:499`, `height_tiles.gd:20-29`):
  every height rounded to 1/1024 block on both legs. Half a quantum is 0.24 mm of
  world against a double ULP of ~0.00005 mm — a **20,000× margin**
  (`docs/status/distance-v5.md:571-579`), and the quantum probe shows the same world
  (`4782edac`, spawn (-44,-124), 53 lakes) at every quantum from 1/1024 to 1/16 M
  (`:587-592`). This is what makes world-truth in C++ safe.
- **`FarUpload`'s budget and atomic swap.**
- **The SConstruct**: 36 lines, three platforms, godot-cpp outside the repo.

Wrong, and the reason this is not yet a foundation:

- **Hard rule 1 — "the game must run with no compiled library" — forces a complete
  GDScript twin for every C++ path.** `far_field_job.gd` is 1,951 lines;
  `far_build.cpp` is 937 transcribing it; a parity self-test asserts byte-identical
  arrays. Defensible for one *look-only* mesh (`height_tiles.gd:20` draws the line
  itself: *"THE FAR MESH IS LOOK-ONLY AND THIS IS NOT"*). Not defensible across the
  mesher, the generator, the lakes and the zone pass as well — that is two of
  everything, forever, for one person.
- **The C++ is written to be a transcription, not to be fast.** `far_world.h:14-23`
  requires every intermediate to be `double` because GDScript's float is a double, and
  every colour multiply to truncate to float32 where a `Color` would — *"each
  expression below is the GDScript one transcribed rather than the same thing said
  better."* It still measures 37–46×, which shows how much is left on the table, and
  it cannot be improved without breaking parity.
- **The shipping build has no C++.** `STATUS.md:172-179`: `gdext/bin/` is gitignored,
  `build.yml` is red (exit 1, 50 seconds in), and **the Windows artifact ships without
  the library** and falls back to a **45 s far rebuild**, with three engine `ERROR`
  lines at startup. A "Godot with hot paths in C++" project whose release build has no
  C++ is not the decided architecture.
- **Cross-compiler determinism is unproven.** `STATUS.md:161-166` / item 27: the
  gcc/MSVC world-identity check has only ever run on one box, so *"no co-op session
  mixes a gcc build and an MSVC one."* Windows self-test reports 7–15 last-bit
  failures, all 1–2 float ULPs, ~33,000× below one 8-bit colour step
  (`docs/status/distance-v4.md:652-660`, `distance-v5.md:1167-1175`) — harmless for the
  look-only far mesh, and exactly the hazard the quantisation exists to kill for world
  truth.
- **The terrain epics forbade C++ outright** (`docs/plans/terrain-v1.md:50`,
  `terrain-v2.md:123`, `world-feel-v1.md:731-732`: *"GDScript only. No GDExtension is
  built."*). That is a repo rule from before the engine decision, and it is why the
  hottest code in the project is in the slowest language.

### Recommendation

**Keep the seam discipline. Drop the twin-implementation rule. Write the hot paths in
C++ from the start, with GDScript as orchestrator only.**

1. **Retire hard rule 1.** It is a repo rule, not a bible rule, and it contradicts the
   fixed engine decision. Make the GDExtension a build requirement, fix `build.yml`,
   and delete each GDScript twin as its C++ path lands — starting with
   `far_field_job.gd`'s 1,951 lines and the parity harness.
2. **Keep the quantisation rule** after the twins go: the gcc/MSVC hazard is real
   regardless of how many implementations exist, and it is still unproven across boxes.
3. **Write the new chunk mesher in C++ directly.** Greedy meshing over a byte volume is
   the most C++-shaped work in the project, and the bible's colour rule (one flat
   albedo + per-cube noise, no baked AO, no tints) makes it *simpler* than the one that
   exists — the AO-vs-merge constraint disappears.
4. **Move lakes and the zone histogram across on the `KubikHeightTiles` pattern.**

**Cost.** Rewriting the four hot paths in C++ against a bible-shaped (simpler) colour
model: mesher ~1 week; generator + column ~1 week; lakes + zone pass ~3 days; far mesh
already done. **L, 2.5–3 weeks.**

Adapting instead — keeping the GDScript meshers, keeping the twins, bolting C++ on path
by path under hard rule 1 — is cheaper per path and **more expensive in total**: every
path costs a transcription plus a parity gate plus permanent double maintenance, and
the numbers say the GDScript leg becomes unshippable anyway (45 s vs 661 ms). Sunk cost
is not an argument, and neither is "the twin already exists".

**One caveat.** The far field's C++ is worth keeping exactly as it is: measured, gated,
deterministic, and the only system in this area that already answers a bible decision.
Delete its GDScript twin; leave the C++ alone.

---

## 4. Where the code decided something the bible is silent on

Candidates for D42 onward — real choices already made in the engine that no bible file
covers.

| # | The choice | Where | Why it needs a decision |
|---|---|---|---|
| D42 | **Chunk size is 16³ (8 m), and a chunk is the network/edit/remesh unit.** | `chunk.gd:15`, `docs/plans/terrain-v1.md:73` | Fixes the granularity of every edit, remesh and save. |
| D43 | **Terrain is a heightmap, not a density field — so no overhangs, no caves, no arches, ever.** | `terrain_generator.gd:16-21` | The bible has mountain gates *cut into cliff faces* and dungeons (`30-architecture.md:26-30`). A heightmap cannot make an overhang. Either dungeons are separate volumes stitched in, or the terrain model changes. **The largest silent decision in this area.** |
| D44 | **Coarse heightmap resolution is 4 blocks (2 m)/cell**, and per-block detail is added later so it can never move a lake. | `terrain_generator.gd:38-48`, `worldgen_config.gd:121-122` | Sets the finest terrain feature the far field can ever show, therefore what "reads as a silhouette from 2 km" (`70-scale-metrics.md:61`) can be made of. Measured: 1 m cells cost 17.5 s of lake finding and 13 s of zone thresholds and were rejected (`docs/status/distance-v5.md:711-724`). |
| D45 | **Zones are resolved by area share, not by altitude** (4/30/26/14/10/11/5%). | `worldgen_config.gd:549-555`, `terrain_generator.gd:335-404` | The bible describes zones as bands bottom-to-top, which reads as altitude. Shares vs lines give different silhouettes — and shares do not survive an unbounded world (`terrain-tectonic.md:554-561`). |
| D46 | **Lakes are found by priority flood from the map border and capped at 2 blocks deep** (because noise terrain has thousands of closed basins and we do not model erosion). | `lakes.gd:14-35`, `terrain-tectonic.md:459-463` | The bible says lakes are still and reflective and nothing about depth, rivers or how they are found. Border-seeding is a bounded-world assumption D41 breaks. |
| D47 | **A full day is 480 seconds (8 minutes).** | `worldgen_config.gd:1570` | The bible's evening should land like the song's swell (`00-TONE.md:29`). Eight minutes puts the whole pink-then-violet evening under a minute. |
| D48 | **The sun's arc is tilted 0.35 south and the moon is its exact antipode**, so a directional light is always up (a night with no light would be black, not dark). | `sky_cycle.gd:112-123, 222-243` | Decides whether night has directional shadows at all. D7 says slate with warm windows and gives no moonlight rule. |
| D49 | **View distance is four presets binding voxel radius, fog end and far-tree reach together**, and voxels only reach **96 m** at High / 128 m at Ultra. | `worldgen_config.gd:159-192, 206-211` | D41 gives a distance target and no quality model. "How much of the world is editable voxels vs far mesh" is a fact players feel — you cannot dig at 200 m. |
| D50 | **The far field is a disc, not a square, and it is drawn *under* the voxel disc with overdraw** rather than meeting it at a seam. | `far_field_job.gd:50-58`, `far_field.gd:310-330` | The commitment that makes "never pops in" (D41) achievable. The bible does not name it. |
| D51 | **Terrain is never networked**; both machines regenerate it from a seed and only edits travel. | `terrain_generator.gd:6-12` | The bible is silent on world sync. This is why the compiler-parity hazard matters, and it constrains everything a director may generate. |
| D52 | **Nothing in the repo can build a building.** There is no site/structure system at all. | grep: nothing under `scripts/world/` constructs anything; `ASSETS-PLAN.md:58-66` says generate from Python in `Kubik-assets` | ROUND-3-BRIEF items 1 and 2 need a landmark gate and five houses. Whether they are generated in-engine from bible rules or imported as `.vox` is undecided in **both** repos. **This is the brief's long pole.** |
| D53 | **Snow is a surface-block colour, not a deposit** — nothing built gets snow, and there is no accumulation. | `terrain_generator.gd:93-104` | The bible's rule says *any* upward-facing cube, which includes roofs and landmark crowns (`20-world-and-terrain.md:23`). |
| D54 | **Grain is a world-space cell hash faded out by 45 m** — a *surface* grain, not a *lens* grain. | `look.gd:296-300` | D40's grain is screen-space and does not fade with distance. The two can coexist, but the fence *"a 1-cube gold line still reads at 100 m"* (`10-color-and-light.md:19`) applies to the lens one, and the surface one is currently at a third of its own target strength. |
| D55 | **The gold accent has an hour** (`#F2A80D` dawn → `#C9A24A` noon → `#E8892E` night). | `look.gd:628-638`, `sky_cycle.gd:39,45,51,57` | The bible says *"the same gold everywhere; never a second gold"* (`10-color-and-light.md:71`) — one fixed hex, tinted by real light for free. Repo rule 5 has no bible counterpart. |
| D56 | **Trees are a separate grain and a separate renderer**, models on a placement lattice, never voxels in the volume — so "is there a tree here" asks placement, not the world, and chopping is fell-as-a-unit. | `DESIGN.md:619-631`, `column_job.gd:17-22` | Matches the bible's three-grain model (D1) by luck, but makes terrain edits unable to touch a tree — an unstated gameplay decision. |
| D57 | **Determinism is a hard contract enforced by hashes** (`Heightmap.hash_key()`, the config hash in the join handshake, the far probe run twice per session). | `terrain_generator.gd:6-12`, `heightmap.gd:462` | The bible never says the world must be bit-identical across machines. It is the reason for the quantisation, the parity harness and half the C++ design. Worth ratifying explicitly. |

---

## 5. Recommendation (under 200 words)

**Foundation for the world. Redo for the render.**

Keep the streaming world: chunk store, column jobs, the disc, the park cache, the
frontier, the single host mutation path, the seeded-determinism contract, the seam
discipline, the probes. Keep the far field's LOD ring ladder and its C++ mesher — the
only system here that already answers a bible decision (16× the area for +22% vertices;
661 ms against 24,722).

Rip the render. `look.gd` is a toon poster: three hard light bands, ambient off, fog
quantised into four steps, a painted sky with Deco rays, non-reflective water, no glow,
no volumetric fog, no post chain, and a linear tonemapper that makes D40's roll-off
impossible. Pillar 2 asks for the opposite of every one. Rebuilding on Godot's PBR plus
a lens pass is smaller than arguing with 1,128 lines.

Order to ROUND-3-BRIEF:
1. Environment and real light (S) — rip the ramp.
2. The four hours plus eerie in `SkyCycle` (M).
3. Volumetric fog's three jobs (M).
4. Bible palette (S); strip the mesher's paint path (M).
5. D40 lens pass (M).
6. A landmark and five houses — **nothing can build either** (D52). That is the long
   pole, not rendering.
7. Scale and 10 km last: one valley does not need it.

Then the C++ rewrite of the mesher and generator, because GDScript workers are
serialised at ~1.0 effective thread.
