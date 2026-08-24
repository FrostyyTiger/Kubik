# Terrain v1 — run status

Unattended run of `docs/plans/terrain-v1.md`, 2026-08-23. All twelve stages
completed, committed one per stage on `feat/terrain-v1`, and **merged to `main`
on 2026-08-24**.

The merge also brought in `af2a6fe` (the character identity model), which landed
on `main` while this run was in progress. Nothing in it conflicts with terrain
v1 — see "Where this run meets the new design" below.

---

## Read this first

**The plan is done.** Launch it and walk out of spawn:

```
git checkout main && git pull
godot --path . -- --host
```

There are six screenshots waiting in `build/tour/` (regenerate with
`godot --path . -- --tour --seed 42`). `6-postcard.png` is the acceptance test —
a mountain, its forested slopes and a lake in one frame.

**One caveat on those screenshots, and it matters.** This box has no display, so
they were rendered under Xvfb, which has no Vulkan — Godot fell back to the
**OpenGL Compatibility renderer on Mesa llvmpipe (software)**. You run
**Forward+** on a real GPU. Lighting, tonemapping and colour will not be
identical. Everything I tuned by eye was tuned against the wrong renderer, so
**check the palette and the light levels yourself before trusting them.** The
things most likely to need a nudge are `SkyCycle.sun_energy` and
`ambient_energy`.

Three things want your judgement, in order:

1. Does the postcard test actually pass when you walk it, not just in a
   screenshot chosen to pass it?
2. Is the world too green? Meadow is 59% of the map by area. That is a
   consequence of the fallback terrain shape, and the two unimplemented
   exercises below are exactly what changes it.
3. Is a ~8 s world load acceptable? If not, the fix is known and costed below.

---

## Where this run meets the new design

`docs/DESIGN.md` gained a character identity model during the run. Checked
against what was built, and it lines up:

- **"at 4 terrain blocks (2 m) tall"** — the player capsule is exactly that,
  2.0 m with a 0.4 m radius.
- **"the chunk mesher is not the character mesher. Two systems, not one."** —
  agreed and untouched. Terrain v1 built only the chunk mesher.
- **Camera** — third person, orbit, collides with terrain, noclip behind a debug
  key. Built as specified.

The one gap to be explicit about: **the player is still a plain capsule.** The
modular voxel character, races as part sets, and visible gear are all
unimplemented, and were never in this plan's scope. That section also carries
its own warning that the 24–32 voxel target is unconfirmed, so nothing here has
been built on it.

---

## What got done

All twelve stages, each committed separately with its reasoning.

| Stage | What |
| --- | --- |
| 1 | `WorldgenConfig`, hot-reloadable from `user://worldgen.tres`, debug readout, tuning panel, reroll |
| 2 | Layered heightmap worldgen, global coarse heightmap, determinism hash |
| 3 | Voxels from the heightmap, flat vertex colour, radius-based chunk selection |
| 4 | Third-person `CharacterBody3D`, orbit camera, collision, noclip |
| 5 | Elevation zones with jitter and dithered boundaries, the plan's palette |
| 6 | Greedy meshing, uniform-chunk skipping, worker-thread mesh pool |
| 7 | Far-field heightmap mesh |
| 8 | Lakes by priority flood over the coarse heightmap |
| 9 | Trees, stamped identically from every chunk they touch |
| 10 | Day/night cycle and fog |
| 11 | Config in the join handshake, host-only reroll, read-only client panel |
| 12 | Screenshot tour and this file |

Beyond the plan, there is now a headless test suite —
`scripts/tools/selftest.gd` — covering mesher winding, the tree chunk-border
bug, chunk determinism, the day cycle, and the config half of the handshake.
It found two real bugs during the run (see below). It exits non-zero, so it can
go in CI whenever you want it there.

---

## Every measured number

Linux, i5-8400, 6 cores. Your Windows box measured ~1.4x faster on the
pre-existing baseline (75 chunks in 960 ms there, 1333 ms here), so scale down.

### Chunk build cost

The world here is **~1030–1330 chunks** — a disc of radius 8 chunks, surface
plus 3 chunks of depth, plus the sky a tree canopy can reach into. (The upper
end is after trees were doubled in size in stage 12: taller canopies mean more
sky above the terrain has to be built. Wall clock went 7.9 s → 8.8 s with it.) The old
figure of 75 chunks was a fixed 5x5x3 box, so it is not comparable; this is
roughly 14x the world.

| Stage | ms/chunk | generate | mesh | wall clock |
| --- | --- | --- | --- | --- |
| 3 — naive mesher, main thread | 18.6 | 1.9 | 16.7 | 19.5 s |
| 6a — greedy meshing | 13.9 | 2.4 | 11.4 | 14.6 s |
| 6b — + skip uniform chunks | 9.4 | 2.5 | 6.9 | 9.8 s |
| 6c — + worker threads | — | 3.4 | **0.20** (upload) | **7.9 s** |
| final, with full-size trees | — | 3.6 | 0.18 | 8.8 s |

**Meshing was the bottleneck and is now effectively free on the main thread**:
16.7 ms/chunk to 0.20 ms. Three wins, largest first:

1. **Skipping uniform chunks** — not in the plan, and the biggest. Greedy
   meshing sweeps 51 planes per chunk whether or not anything is in them, so it
   was *slower* than naive on the empty sky and solid rock that most of a
   heightmap world consists of.
2. **Worker threads** — moved what remained off the frame.
3. **Greedy meshing** — a flat 16x16 chunk face goes from 256 quads to 1.

### Worldgen

| Thing | Value |
| --- | --- |
| Coarse heightmap | 750x750 cells, 2 m each, **~920 ms**, 2.25 MB |
| Lakes (priority flood) | **~1.0 s** |
| Far-field mesh | **42,684 vertices** (plan's budget: under ~300k) |
| Altitude range | min 24.7, max 254.1, mean 99.8 blocks |
| Zone shares | meadow 59.5%, forest 29.2%, rock 10.4%, snow 0.87% |
| Lakes (seed 42) | 328 lakes, 39,237 cells, 156,948 m², 7.0% of the map |
| Largest lake | 1,716 cells / 6,864 m², about 93 m across |
| Trees (seed 42) | 9,494 in the whole world |

### Determinism

- Two runs of seed 42: identical heightmap hash, identical lakes, identical
  tree count.
- **Two-peer test**: host and client independently produced seed 682329431,
  config `9f321085`, heightmap `a6cab886`, 254 lakes / 121,204 m², 1,143 chunks,
  42,684 far-field vertices. Every number matched.
- Self-tests: 24,600 triangles winding-checked (0 wrong), 250 chunks
  border-checked (0 differed), chunk determinism identical, day cycle clean.

---

## Judgement calls, and departures from the plan

Every one of these was a place the plan and the world disagreed. They are all
config knobs, so all of them are reversible.

**1. The continent layer gates the mountain layer.** *(biggest one)*
Straight summed noise, measured across six amplitude sweeps, gives uniform
bumpiness — relief in every direction, no lowlands, and nowhere flat and
enclosed enough to hold a lake. Gating the mountain layer on the continent
layer gives broad low country with mountain country concentrated into massifs.
Knobs: `mountain_mask_lo` / `mountain_mask_hi`.

**2. `lake_max_depth`, a new setting.** Filling every basin to its spill point
puts **24.9% of the map under water** — and not shallow swamp either, but
genuinely 28 m deep basins. Real terrain has few closed basins because rivers
carve outlets; we do not model erosion, so noise terrain has thousands. Capping
the fill depth at 10 blocks puts water in the *bottom* of a valley and gives 7%
coverage. Set it to 20 to see the drowned version.

**3. Trees are twice the size the plan specifies.** The plan says a 3–5 block
trunk and 2–3 block canopy. At 0.5 m per block — which the same plan
specifies — that is a 2 m tree with a 1.5 m crown, the same height as the
player. On screen it read as a shrub, and a "forested slope" of them read as a
lawn. Now 8–14 and 4–6, so a tree is 5–10 m.

**4. The far field is a disc around the player, not one mesh over the map.**
Flat-shaded, a whole-world mesh is ~559k vertices — past the plan's own ~300k
budget — and would need rebuilding every time the voxel hole moved. Fog is
opaque at 200 m, so terrain past that is not cheap to draw, it is invisible.

**5. Soil sits under meadow and forest only**, not under any surface. A cliff in
the bare-rock zone otherwise shows a brown stripe three blocks below its top.

**6. The surface layer is two blocks thick, not one.** The detail layer puts a
one-block step every few blocks, and a single-block skin exposed soil on every
one of them — a haze of dark flecks over every hillside, clearly visible in the
first screenshot tour. Confirmed as soil rather than tree trunks by re-shooting
the same seed with trees disabled.

**7. The ridge-transform fallback is the raw fbm value rescaled to 0..1**, not
literally raw. Raw fbm is centred on zero, so the mountain layer would be
centred on `base_altitude` and half the world would clamp at the floor. The
rescale keeps the fallback world playable *and* keeps the jump small when you
implement the real thing — real ridged noise averages ~0.64 against this 0.5,
where raw would have been a 105-block shift needing a full retune.

**8. Linear tonemapping, not Filmic.** There are no textures — a block is
exactly its colour — so the palette *is* the art direction, and a tonemapper
that reshapes it is reshaping the art. Measured: Filmic turned `#86B04A` meadow
into `#68D62F` on screen, brighter *and* hue-shifted.

**9. `day_start` moved from 0.3 to 0.38.** At 0.3 the sun is only 18° up, so
level ground receives under a third of the sunlight and the whole palette
renders dark. Measured, not guessed.

**10. The plan named `Game._srv_send_world_state`.** The actual functions are
`_srv_request_join_state` / `_cl_receive_join_state`. Same place, same change.
The plan also refers to `plans/terrain-v1.md`; it lives at
`docs/plans/terrain-v1.md`, and `docs/DESIGN.md` and `docs/IDEAS.md` both point
at the wrong path.

---

## Two real bugs the tests caught

- **A fresh `Chunk` defaulted `has_air` to false**, so the mesher treated a
  hand-built chunk as solid throughout and skipped every interior face.
  Generation set the flags explicitly, so the game never showed it — it would
  have detonated the first time anything built a chunk by hand.
- **The palette was being fed to the renderer as sRGB where it wanted linear.**
  Every colour drew far brighter and far less saturated than authored: `#86B04A`
  meadow arrived as pale lime and every zone washed into every other zone. All
  the numbers had looked fine for ten stages; the first screenshot tour is what
  caught it. The palette in `Block.COLORS` is now stored linear, with the
  authored hex beside each value.

The second one is the argument for having built the tour at all.

---

## What did NOT get done

**Chunk generation is still on the main thread.** This is the single biggest
remaining performance win. The main thread now spends its 8 ms/frame budget
almost entirely generating voxels (3.4 ms/chunk); threading it would cut a full
load from ~7.9 s to roughly 1 s. It was left because moving generation to a
worker means chunk data no longer exists at submit time, which changes how edits
are replayed — a real change to the one mutation path, and not something to do
unsupervised at 3 a.m.

**The far field and the voxels meet in a visible seam.** The far mesh is the
coarse heightmap; the voxels are that plus per-block detail, so they differ by
up to 3 blocks at the boundary. It is mitigated (the far mesh sits half the
detail amplitude lower and overlaps by two cells) but not solved. Real fixes:
a skirt, a blend band, or sampling detail into the far mesh.

**Host-authoritative player input.** Explicitly a carried ticket in the plan,
and still carried. The player is a physics body but simulates locally and sends
its position. `Game._srv_report_state` is the function to replace.

**Nothing was verified on Forward+.** See the caveat at the top.

---

## The three exercises waiting for you

All in `scripts/world/terrain_generator.gd`, each with a working fallback, each
with the hint the plan asked for. They are the difference between the world you
will see in the morning and the world the plan describes — the fallback world is
deliberately the "before" picture.

1. **`_ridge()`** — ridged noise, `1.0 - abs(n)` then squared. This is the one
   that changes the skyline most, and the one that will move the zone shares
   away from 59% meadow.
2. **`_domain_warp()`** — stops everything looking grid-aligned.
3. **`_flatten_valleys()`** — makes valley floors walkable and campfire-sized.

A fourth, moved rather than written: `Player._speed_multiplier()`, which came
across from the old fly camera when it was replaced, and now applies to walking
as well as flight.

Expect to retune `mountain_amp` after the first one — the fallback and the real
ridge transform do not average to the same height.

---

## The exact next step

**Walk the world and judge the postcard test.** Everything else is downstream of
whether the landscape actually reads.

Then, whichever you feel first:

- *"It looks wrong"* → do exercise 1, reroll (`F7`), and retune `mountain_amp`
  in the panel (`F4`). That loop is about ten seconds long now.
- *"It loads too slowly"* → thread chunk generation, or turn
  `voxel_radius_chunks` down from 8 (quadratic: 8 → 6 is about half the chunks).
- *"It's fine, what's next"* → `docs/IDEAS.md` item 2, the first enemy. I have
  deliberately **not** re-ordered the Next 3 — that list is meant to be filled by
  what a playtest teaches you, and you have not played this yet.

`docs/IDEAS.md` still lists terrain v1 as Next 3 item 1, and both it and
`docs/DESIGN.md` point at `plans/terrain-v1.md` when the file is at
`docs/plans/terrain-v1.md`. Worth a tidy once you have decided whether the
result stands — I left the Next 3 alone deliberately, since that list is meant
to be reordered by what a playtest teaches you.

---

## Environment notes for this box

- Godot 4.7.2 was not installed here. It is now at `~/bin/godot` (official Linux
  x86_64 build, user-space, nothing system-wide).
- Vulkan is unavailable under Xvfb, so the screenshot tour runs on the OpenGL
  Compatibility renderer via Mesa llvmpipe. Installing a Vulkan ICD would need
  `sudo` and a driver package, which I did not do unattended.
