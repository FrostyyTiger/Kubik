# Status

**Running now:** nothing. **Next: upload v1** (phase 1d, D85, decided
2026-09-05) - the chunk and flora upload off the frame thread, alone, plan
`docs/plans/upload-v1.md` not yet written. **Then the world-truth break** -
real relief (D45), rings measured from the capital (D44), lakes and zones per
tile, the generator's truth in C++ (D56, timing amended by D84 and D85). Then
people and fire, buildings, the round 3 scene.

**Open for Marcel:** `far_ring_div`, 2 or 4. Horizon v1 set it to 2 for the
vertex budget at 32 km (1.8 M against 6.5 M); at 2 the twenty highest summits
lose up to 23 blocks, at 4 they lose 1.3. One F4 spinbox, redraws in place.
`docs/status/horizon-v1.md` § For Marcel, items 6 and 8.

**Merged 2026-09-05: horizon v1**, three nights in one 15.5-hour session,
unattended on ganymede, on `feat/horizon-v1`, self-merged per Marcel's
amendment: `docs/status/horizon-v1.md`.
**The world is as big as the view, and the view reaches 32 km.**

The tile store (origin-anchored height tiles at every level, the region
reduced to bookkeeping), voxels anywhere, the far field to 32 km in persistent
per-ring and per-sector pieces with only what moved rebuilt, one material
source for every level with the far paint a lookup, the fog as a ramp on the
draw distance, the floating origin, and the sprint probe - the instrument the
north star's frame gate is measured by. **The median half of that gate is met:
16.67 ms at Ultra with the view at 32 km, three runs, spread 0.00%, against
41.67 ms at 3.2 km on `main` the morning before.** The view presets are the
reach now: Low 8 km, Medium 16, High and Ultra 32.

**The hitch half is not met, and it is D85's reason.** 171 to 233 frames of
about 3,340 over 25 ms on the sprint line, and every rung of the plan's shrink
list made both numbers worse - a smaller upload slice lengthens the queue. With
the C++ chunk mesher merged the same sprint streams 12,870 chunks instead of
5,900 and the median rises to 22.1 ms: generation and meshing are off the main
thread, so what is left on it, `add_surface_from_arrays` plus a collision
shape per column at 214 columns a second, is the whole hitch column. That is
upload v1.

The canonical world line did not move: heightmap `4782edac`, spawn
`(-44, -124)`, 53 lakes, 15,218 trees, config `1d7c18c7`, two lanes and one
world. `far_ring_div` went 4 to 2 (above). Nine silences for the world-truth
break and three merge requests are listed at the end of the status doc.

**Marcel's Mac, 2026-09-05 - the macOS gate.** CI runs the self-test on Linux
only, so the Mac is the project's only macOS gate, and on the merged tree it
crashed: `World.setup` queues the far field's tile prepare on the worker pool,
every self-test World is `World.new()` plus `free()` without entering the tree,
so the exit-from-tree drain never ran and the job executed on a freed
`FarField`. Fixed by draining on pre-delete as well (`far_field.gd`); Linux
had passed by timing alone. With the crash gone, two parity gates failed on
macOS by the last bit - the pyramid functions by 2.8e-14 blocks, the far
colour by 6e-8 on about 740 of 89,000 quads, positions, normals and indices
exact - where gcc and CI are exact to zero. Marcel's ruling: a tolerance,
1e-9 on heights and slopes and 1e-6 on a colour channel, the max diff still
printed on every run (`selftest.gd`, `PARITY_HEIGHT_TOL`, `PARITY_COLOUR_TOL`).
The suite passes on macOS with both.

**Merged 2026-09-04: mesher v1** (phase 1b, D56), the lane that ran in
parallel with horizon v1 on `feat/mesher-v1`. The chunk mesher is a third
class in the GDExtension, `KubikChunkMesher`: **0.061 ms a chunk against the
GDScript twin's 6.443, 106x, over the 1,910 chunks of the seed-42 spawn
disc**, and the world at spawn loads in **12.4 s against 30.9 s**. It is
look-only in the strongest sense this project has - the mesher decides how a
chunk looks and never what it is - and the gate is exact all the same: `chunk
parity` compares every vertex, normal, index and colour component to the bit,
at both AO settings, and it is exact zero on MSVC as well. `--mesher gdscript`
forces the twin for an A/B; the GDScript implementation stays in the tree as
the reference until it is deliberately retired. `docs/status/mesher-v1.md`.

**Merged 2026-09-04: light v1**, two nights, unattended on ganymede, on
`feat/light-v1`: `docs/status/light-v1.md`.
**The engine lights the world, and the poster is gone.**

This is phase 1 of `RECONCILIATION.md` - the first translation of the bible
into the game, and the largest single deletion the renderer has had. The plan
it ran is `docs/plans/light-v1-tech.md`, whose twenty-eight bound answers are
the argument for every choice below.

**The toon poster is out, whole.** A three-band quantiser of `n·l`, ambient
disabled outright, depth fog quantised into four flat steps and written per
material, a hand-written sky shader with Deco sun wedges and threshold clouds,
a 4x4 Bayer dissolve on the far field, flat non-reflective water and a linear
tonemapper. `look.gd` fell from **1,128 lines to about 600**, and eight of its
nine shader globals went with it. Bible pillar 2 asks for the opposite of every
one of them.

**What replaced it is the engine's own light**: a real sun with a one-degree
angular size so a penumbra widens with distance from its caster, soft shadows
tinted by full sky ambient off a `PhysicalSkyMaterial`, SSAO, volumetric fog,
SSR and an AgX tonemap. Measured, because D8 is a measurable claim: a tree's
cast shadow on open ground reads **V 17.6 at hue 206.5 against a sky at hue
214.0** - never black, and eight degrees off the sky's own colour.

**The hours are the bible's four plus a weather.** Day, evening (pink), dusk
(violet) and night (slate), with eerie as a dictionary of overrides applied on
top rather than a fifth hour. A day is **forty minutes** (D52) and the sun
**slows threefold across the evening**, because at a uniform speed even a
2,400-second day gives the passage from +8 to -12 degrees about 133 seconds and
two minutes is not an evening. Measured: **360 s**, asserted by the self-test.

**Fog does its three jobs.** Aerial perspective to the sky for distance - the
farthest range sits **1.7 V** from the sky directly above it - `FogVolume`
bands that lie in the valley and move with the tracked floor rather than with
the camera, and an eerie lid that puts the summit **within 3.5 V** of the sky
beside it. Under eerie there are **zero** orange pixels where the same vantage
by day has 3,700, and the mushrooms go from 2,368 warm pixels to none.

**The bible's palette, and five paint operations deleted from both legs of the
far field in one commit** - baked AO, a slope tint, an aspect tint against a
fixed compass direction, a per-vertex hash jitter and an altitude band. They
existed because the ramp faceted. The C++ and its GDScript twin lost them
together, so the parity harness never saw them disagree, and it now reports
**10,000 samples x 3 functions, all identical**.

**The film lens** (D40): halation gated to emissives by an HDR threshold, a
muted grade, and grain and a vignette after the tonemap. Its three fences hold
- a one-cube gold line still reads at 100 m at **+23.6 saturation over the
meadow and 4 px wide**, there is **not one clipped white pixel** in any hour
shot, and every mid-frame surface is **within 1 V** of its lens-off twin.

**Water is clear and reflects**: tinted by how much water the eye looks
through, read from the depth buffer, with a Fresnel term driving alpha and SSR
for the ranges. No rings, no waves.

**The cost line comes from the tour now**, because the streaming probe does not
exit - four attempts across two nights, 45 to 68 minutes on an idle box, no
output. Twenty frames at each settled vantage: the **worst per-shot frame is
17.2 ms** across the five hour shots and `5-lake`, with SSR on, against rule
6's 45 ms. The lens is inside the measurement noise.

**The world did not move.** Every stage reprinted heightmap `4782edac`, spawn
`(-44, -124)`, 53 lakes and 15,218 trees. The config hash moved exactly once,
when D52 took `day_seconds` from 480 to 2,400, and that knob is hashed on
purpose: two machines on different clocks would disagree about the hour, and
the hour is what every light in the world is a function of.

**Seven findings went back to the bible** rather than being fixed here - a
physical sky cannot be made violet at dusk; the bible names no dawn; eerie's
"base of things" cannot be done without repainting a material; a circular sun
arc makes the night half the day; a closed spruce interior at real tree size
may simply be a dark place; seven palette rows are silences; and there is no
deep water in this world, so a lake cannot show both of its two colours.

The previous run, **trees v3**, is `docs/status/trees-v3.md`.
