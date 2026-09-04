# Status

**Running now (launched 2026-09-04):** horizon v1 (`feat/horizon-v1`,
`docs/plans/horizon-v1.md`) and mesher v1 (`feat/mesher-v1`,
`docs/plans/mesher-v1.md`), in parallel on ganymede in tmux `horizon-v1` and
`mesher-v1`; their status docs are `docs/status/horizon-v1.md` and
`docs/status/mesher-v1.md` once each lane's Stage 0 lands. Marcel's north star
for them (D84): the world as big as the view, the view to 32 km, 60 FPS at max
settings on mid hardware. Next after them: the world-truth break.

The latest run is **light v1**, two nights, unattended on ganymede, on
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
