# Art direction research - the poster, refined

Research pass of 2026-08-25, run after look v1 merged, to refine the decided
direction into look v2. The direction is not reopened here: the Art Deco
Alpine travel poster, the travel-poster strand (Broders' PLM series, the Swiss
lithographs of the 1920s-30s), never the Manhattan strand. This document is
what the posters, the games and the real place say about its *details*, with
the contradictions between sources resolved and every rule carrying its
numbers.

> **How to read this document after 2026-09-04. It is EVIDENCE, not
> authority.** The direction is `../../../Kubik-bible/` and nothing else: art
> pillar 2 (real light on flat cubes through a film lens; no textures, on
> anything, ever; one body colour per material in three shades plus per-cube
> noise; mood from light, fog, the hour and the lens, never from repainting),
> pillar 5 (deco on the built, never on nature; Art Nouveau on paper only,
> D2), the palette in `../../../Kubik-bible/style-bible/10-color-and-light.md`, and the hours in
> D5 to D8. The re-cut this note used to describe - "Art Deco fantasy", the
> poster retired as a rendering register, one painted-voxel surface language
> - was this repo's own ruling and it is superseded with the rest of the old
> art direction; `../DESIGN.md` no longer has an Art direction section to
> point at.
>
> **What still stands, and it is the valuable half:**
>
> - **The method.** Six lenses, references downloaded and looked at, colours
>   sampled from the pixels with PIL, never from memory, with the
>   contradictions between sources resolved and every rule carrying its
>   numbers. That is how the style bible was measured too, and it is how the
>   next colour question should be answered.
> - **The colour-transfer finding**, which is the single most load-bearing
>   thing in this document: what is authored has to be what is on screen, and
>   it was not - the albedo was applied twice and Lambert's PI sat in the lit
>   band, so every constant tuned before it had been chosen to cancel an error
>   nobody had written down. The gate that came out of it (`--sheet transfer
>   --strict`, eight authored colours within 6 units per sRGB channel) still
>   runs every stage and still passes at a worst delta of 1 to 2 of 6.
> - **The sampled numbers** - poster palettes, the time-of-day sets, the fog
>   and sky measurements, the real-place photographs against `Block.COLORS` -
>   as EVIDENCE a bible hex can be checked against. Where a number here and a
>   bible hex disagree, the bible wins and the disagreement is a finding
>   worth logging; light v1 sent seven such findings back that way
>   (`../status/light-v1.md`).
>
> **What does not stand:** any line that prescribes flatness, a lighting
> ramp, shade as an ink, banded fog, a painted sky or one flat colour per lit
> surface. Light v1 deleted all of it (`../plans/light-v1-tech.md`). §1's
> two-register frame is gone with the poster. §2.5's form language yielded to
> trees v3's sculpted library. §6's Deco vocabulary keeps standing only for
> the BUILT world, and only under pillar 5.

Six research lenses ran in parallel, each downloading and looking at its
references and sampling colours from the pixels with PIL (never from memory):

1. **The posters** - 24 Broders and Cardinaux sheets sampled per element.
2. **Flat-look 3D games** - Firewatch, Sable, Journey, Tunic, A Short Hike,
   RiME, The Pathless, Röki, Cocoon, Season; the mechanism behind each.
3. **Voxel craft** - Cube World, Teardown, Crossy Road, Staxel, Trove, Lay of
   the Land; grain, faces, chibi proportion, measured.
4. **Light by time of day** - 24 posters across noon, alpenglow, winter,
   twilight and night; complete palette sets per hour.
5. **The real place** - 24 photographs of the Alpstein, Engadin and Bernese
   pre-Alps against `Block.COLORS` and `FloraModels.COLORS`, then poster-ised.
6. **Deco vocabulary beyond the sky** - trees, rock, water, clouds, smoke,
   signage, frames; 23 posters and ornament plates.

The six raw reports, the downloaded references and the sampling scripts are
in the session scratchpad, not the repo. Sources are listed at the end.

Every hex in this document is **sRGB** unless it says linear. The code stores
palettes linear with the sRGB hex beside each; the plan gives both.

---

## 0. First finding: the screen is not showing the authored colours

Before any palette number means anything, this. Measured off the shipped tour
and gallery PNGs (Forward+, Marcel's box) against the values authored for
them, and fitted:

| surface | authored | on screen | fitted model |
| --- | --- | --- | --- |
| meadow, flat, noon (`8-meadow-closeup`) | `#86B04A` hsv(83, 58, 69) | `#5A940F` hsv(86, 90, 58) | `#5A9716` |
| shore (`5-lake`) | `#BFB48C` hsv(47, 27, 75) | `#C8A451` hsv(42, 60, 78) | `#BE9E4F` |
| test cube, lit top (`testcube`) | `#E0AC7E` hsv(28, 44, 88) | `#FF9C46` hsv(28, 73, 100) | `#FF903F` |
| test cube, shade side | `#E0AC7E` | `#754431` hsv(17, 58, 46) | `#713E2C` |
| spruce (`7-forest-interior`) | `#4E7A32` | near-black green | `#20460B` |

The model that fits all five within a few units is

    on_screen = srgb_to_linear( srgb_to_linear(authored) ) * sun * energy * PI

Two errors compound. **(a)** The vertex colour is linearised twice: the
palettes are stored linear (correctly, by the files' own comments) and
something between `ARRAY_COLOR` and `ALBEDO` linearises them again. Whether
that is Godot 4.7's handling of 8-bit vertex colours or something in our
path is for Stage 0 of the plan to find - the fit is the fact. **(b)** In a
`light()` function `LIGHT_COLOR` is the light's colour times energy **times
PI** (the Godot shader spec, present because PBR BRDFs divide by PI; our
ramp does not). So the lit band is 2.2x the sun, not 0.70x. Look v1 halved
the sun energy from 0.85 to 0.70 to fight brightness that was this.

The net effect on *value* roughly cancels for mid-tones (meadow 69 authored,
58 on screen), which is why nobody saw it. The effect on *saturation*
doubles it (58 -> 90), darks are crushed (spruce to `#20460B`), lights clip
(`FLOWER_WHITE` renders pure white). This one thing is behind most of what
every lens reported as wrong: the neon meadow, the near-black forest, the
brick heath stripe, the muddy dusk (dark colours crushed), the yellow shore.

The sky has its own version: `fog_sky_affect = 0.6` mixes the authored sky 60%
toward the fog colour, so `SKY_TOP_DAY #4D80D4` (S64) shows as `#89A1CB`
(S33). The poster sky shader should own its own horizon; the environment fog
should not tint it.

**Consequence for everything below:** every palette hex in this document is
a target for what should be ON SCREEN at noon on a lit face, under a fixed
transfer where `on_screen ~= authored * sun * energy`, with the noon sun
`#FFF2D1` at energy 1.0. The fix comes first (plan Stage 0); every number
after it is a starting value to be judged on the tour **after** the fix, not
before. Lens 5's proposals were made on this assumption explicitly; lens 1
and 4 sampled posters, which are transfer-independent.

---

## 1. The two registers

The posters split into two registers, and Kubik should know which it is
copying where (lens 1):

- **Broders (PLM, 1924-32):** mid-value grey-violet skies (S 7-20, V 56-74),
  near-black spruce silhouettes framing the foreground, mountains in 3-5
  flat tones, one hot accent (orange/red) on a lit face or an object. Snow
  is cream and *lighter than the sky*. The sky is a single flat tone plus at
  most a cream strip at the horizon.
- **Cardinaux (Zurich, 1908-21):** pale cream-to-teal skies (V 85-99),
  ultramarine or grey-green spruce, chartreuse meadows, gold alpenglow, the
  shade at golden hour a full-chroma cobalt. Sky is the lightest thing.

Mapping to the pillars: the **Cardinaux register for the cozy noon valley**
(pale sky, warm meadow, the lit world), the **Broders register for dusk,
distance and the outward ranges** (grey-violet, silhouette, the tense edge).
"Tense out, cozy in the light" is already the split between the two.

---

## 2. Rules and numbers, per element

### 2.1 Light: the ramp

**Rule - shade is an ink, not a dimmer.** In every poster the shade side of a
green thing is not dark green: Chamonix-Martigny's shaded meadow is `#0E1529`
(navy), RhB 1913's shaded forest `#555772`, Gotthard's rock shade `#3D3D50`,
Aiguille du Dru's shade of an orange rock `#172F3C` (lens 1). Tunic: lit
`#C5BFA9` (S14) / shade `#400464` (S96) on one block (lens 2). Cube World:
saturation *triples* from lit to shade and the hue swings 80 degrees (lens
3). A multiply cannot do any of that - `LEAVES x SHADE_DAY` stays green, only
darker. The shade keeps the surface's **luminance** (snow shade is lighter
than spruce shade, always) but takes the ink's **hue**.

    float lum = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
    vec3 shade_alb = mix(ALBEDO, vec3(lum), kubik_shade_desat);
    vec3 L = LIGHT_COLOR / PI;                       // undo the BRDF PI
    DIFFUSE_LIGHT += mix(shade_alb * kubik_shade.rgb, ALBEDO * L, band);

`kubik_shade_desat` is a new global published by SkyCycle: **0.55 day, 0.65
dusk, 0.75 night** (starting values). Lens 1 (hue-keep 0.35 = desat 0.65) and
lens 2 (0.55 toward pure ink) and lens 4 (0 day / 0.35 dusk / 0.65 night)
disagree on the day value; the posters replace hue by day too (lens 1's
day samples above), so day starts at 0.55, on F4.

**Shade colours** (the ink, sRGB, published linear): day `#7A7396`, dusk
`#4A6FB4`, night `#39456E`. Day from lens 1 (poster shade inks `#555772`,
`#5F5464`, `#4F5277`; snow then lands at `#726B8B` = Le Brevent's deep snow
shade `#726E8A`). Dusk: lens 1 (Broders' warm grey-violet `#7D6A80`) and lens
4 (Cardinaux cobalt `#4A6FB4`) are the two registers; lens 4's rule "pick
one, the middle is mud" plus rule 1 of the direction ("shade is a colour,
blue-violet") chooses Cardinaux. Night from lens 4. The old day value
`#999EDB` was tuned against the broken transfer.

**Bands.** `BAND_HALF_LEVEL 0.55` is confirmed by three voxel games (Cube
World 1.00 / 0.70 / 0.52, Crossy Road 1.00 / 0.87 / 0.60; lens 3). `BAND_HALF`
0.12 -> **0.22** as an experiment so that faces side-on to the sun land in the
middle tone reliably (today most of the world is either fully lit or fully
shaded). Optional lit-band bleach: `mix(ALBEDO, vec3(1.0), 0.10)` in the lit
band only (Cube World's lit faces are bleached, S .148 vs shade S .500).

**Sun energies** (after the PI fix, so they mean what they say): dawn 0.85,
noon **1.0**, dusk 0.90, moon **0.75** (starting; the posters' moonlit wall is
V77, `#C2C4C6`, so lens 4 says 0.95 - start lower and let the first enemy
argue it up or down).

**No outlines, no bevels.** Zero of the sixteen reference games use them
(lenses 2 and 3). Figure/ground separation comes from value contracts (2.3)
and the shade ink, not lines. Screen-space edge detection is not available
on Compatibility anyway.

### 2.2 Sky

**Rule - the sky is a pale, desaturated band the white mountains stand in
front of.** Saturation never over ~0.35 (the most saturated of 22 posters is
Chur-Arosa `#76B9D6`, S45); the horizon is lighter and warmer than the top;
lit snow is lighter than the sky (lens 1). With `fog_sky_affect` at 0 the
authored value is the on-screen value, so author what is on screen today:
**`SKY_TOP_DAY = #89A1CB`** (H218 S33 V80), which lens 4 and lens 3 both
judged correct.

**Rule - the horizon is not the fog.** Firewatch: sky above the horizon
`#FFFFEB` (V100), farthest ridge `#ADE0DB` (V88) - a 12-point value cliff, and
the ridges stay opaque. Journey the same (13 points). Broders: sky `#DFCFA3`
(V87) over a far range `#B1B5B5` (V70); Mont Revard sky `#F9BB97` (V97) over
`#D5C5B6` (V83). Kubik sets `sky_horizon == fog colour` by construction, and
that is exactly why the far ranges read as translucent overlapping glass
(lens 2, finding 1; lens 1 finding 4). Split them: the sky's lowest band is a
cream, the fog target is a pale grey a step darker.

**Rule - a twilight sky is three stops, not two.** Handschin's Silvaplana
runs indigo `#3540A0` -> lilac `#B1ACD6` -> cream `#FFFEF2`; the linear midpoint
of the endpoints is a pinkish grey (lens 4). Add `sky_mid` to the sky shader;
at noon and night it is the midpoint (already right), at dusk and dawn its
own stop.

**Rule - dawn is not dusk mirrored.** Dawn: high value (V85-97), low
saturation, mint / rose / salmon, with the only saturated thing a *narrow*
amber band at the horizon (Jungfrau-Bahn `#F2A80D`, one fourteenth of the
height). Dusk: lower value (V63-73), violet or neutral sky, the saturated
warm spread over the *lit faces* (lens 4). A DAWN keyframe and a
morning/evening flag on the pure colour functions.

**Rule - clouds are cut paper, elongated along the horizon.** Lit face a warm
near-white at every hour (Val d'Aosta `#EFE8DD`, H37 - crossing 170 degrees
of hue from the sky), never pure white and never lighter than lit snow (lens
1, 4); the underside is the *sky's* hue at -10 value -12 saturation, not a
darker cloud (lens 4). Shapes are lozenges 3-4:1 along the horizon with a
bumpy top, a nearly straight bottom and a constant-width shade lip
(Jungfrau-Bahn, Guebwiller; lens 6): sample the noise in polar coordinates
of the plane projection so the stretch follows the horizon at every bearing,
and offset the underside sample radially so the lip is one fixed width.

**The sun disc and its rays - recorded, not resolved.** None of the 22 posters
lens 1 sampled draws a sun disc or radial rays; the sun is felt as alpenglow
on lit faces and a warm horizon band, and when there are rays (Jungfrau-Bahn)
they are horizontal cloud streaks. The sunburst is a Deco ornament of the
title plate and the mirror (lens 6). The direction as decided says "a sun
with rays" and the v1 plan said not to make it subtle; that decision stands
here, refined: rays as **alternating long and short tapered wedges** (24 +
24, tip 0.15 of base width; lens 6), the halo the *sky lifted* two to four
value points, taking the sun's hue only when the sky is already warm (dawn,
dusk) (lens 4 - Kubik's noon rays already read this way in `2-summit`), and a
faint halo for the moon (`ray_strength` 0.10, `ray_extent` 0.5). If the disc
and rays ever read as kitsch in play, the evidence says drop them, not soften
them. Marcel's call.

**The moon.** Dagan's *Moonlight in Duneland* makes the moon `#E2A316` (S90),
the one warm object in the top of the sheet, rhymed by the campfire at the
bottom. Kubik's moon is drawn in the moon's *light* colour and reads as a grey
smudge. A gold moon disc (`#E8892E`, the night accent) with a cool light
(`#9AAAD0`) is what the poster does; it bends rule 5 ("nothing else in the
world is gold") by one object. Marcel's call; the plan carries it as an
option.

### 2.3 Distance: fog and the far ranges

**Rule - distance is 3-4 opaque planes, nearest darkest, each lighter AND
greyer; hue is held.** Firewatch's ridge ladder in (V, S): (56, 57) -> (65,
50) -> (76, 46) -> (88, 23) -> sky (100, 8), hue pinned within 5 degrees.
Journey: (49, 42) ... (85, 38) -> sky (98, 16). Broders: `#324438` -> `#939680`
-> `#D5C5B6` -> snow -> sky. Each plane is ONE tone (plus its lit/shade pair);
steps between planes are 10-25 value points; far planes lose saturation
toward a grey carrying the sky's hue at a third of its chroma (lens 1, 2,
4). So: **fog bands 6 -> 4**, starting nearer (`FOG_START_RATIO` 0.6 -> 0.4,
240 m of 600) so the second plane is already a step lighter; fog target
**`#C9C3C4`** by day (pale warm grey, V79) under a horizon of `#EBDFC8` (V92);
and fog toward a *desaturated, lifted version of the fragment's own colour*
blended with the fog colour, so a green range fogs to a grey-green and a
violet range to a grey-violet rather than both to one blue:

    vec3 self = mix(ALBEDO, vec3(lum), 0.5) * 1.25;
    vec3 target = mix(self, kubik_fog_color.rgb, 0.6);

**Rule - the far field bands by distance, never by altitude stripes.** No
poster stripes a mountain. Broders and Cardinaux stack ranges each one step
lighter than the one in front; Journey's planes have zero internal variation
(lens 2, 6). Kubik's `far_band_step` *alternates* lighter/darker every 40 m,
which is the contour-stripe read visible as the red zigzag in `9-treeline`.
Make it **monotonic**: `k = clamp(1 + step * (band - band_of_treeline), 0.85,
1.25)` with `far_band_m` 40 -> **60** and `far_band_step` 0.06 -> **0.03** -
lighter with altitude as the peak rule says (lens 6: four values, lighter with
distance and altitude), the fog bands carrying the distance separation. The
snowline and treeline stay hard colour breaks.

**Rule - figures fog toward a darker target than the ground.** Firewatch's
treeline at 100 m is a solid sawtooth at V65 in front of a ridge at V77 and
one behind at V88; trees never lighten into the ground they stand on, and
that value contract - not outlines - is what separates figure from ground to
the horizon (lens 2). Give trees, characters and boulders a fog target one
band darker than the terrain's (`#8E9AA8` by day, starting). This needs the
opaque material split in two - the same shader, a `Look.figure_material()`
with different uniform values - which the grain (2.5) needs as well.

Recorded, later: a bright hairline along the sunlit crest of a shaded ridge
(Cardinaux RhB 1913, BLS 1921) and snow as *detached flat shapes* where the
slope is shallow rather than as an altitude band (Jungfrau-Bahn) (lens 6).
Both are `far_field_job.gd` edits of ~10 lines each; both are second-pass.

### 2.4 Near terrain: colour and grain

**Rule - warmth is in the light, coolness is in the shade, and the albedo has
neither.** No poster bakes a warm cast into rock, water or shadow; the sun
does it and the shade is violet (lens 5's "what the poster-ised step actually
is"). Kubik's ramp implements this; the palette had been doing it a second
time (STONE a warm taupe, SHORE a yellow). Limestone is neutral: lit scree
`#D5D0CD` (S4), a lit Alpstein cliff `#A5A69B` (S7), the same rock under cloud
`#8F99A1` (cool), in cast shadow `#363F46` (blue).

**Rule - grain must be hard-edged and one block across.** Kubik's jitter
*amplitude* (±5% value, ±3 degrees hue) is exactly Cube World's (±8% V, ±3.5
degrees H on stone; measured, lens 3); the failure is the 6-block cell
interpolated per vertex across greedy quads, which the eye reads as a stain.
Move the grain into the fragment shader as a hash of `floor(world_pos /
0.5)`: texture-free, greedy-safe, both renderers, and the mesh never
changes. ±0.065 value, ±0.03 hue, **fading out with the fog term** so it does
not shimmer past ~40 m (grain is gone by 30 m in Cube World). Optionally gate
it to ~15% of blocks at a hard ±12% (Crossy Road's sparse accents) on the
flattest materials. Never on characters or flora (one colour per part; lens
3). Then `color_jitter_value` and `color_jitter_hue` go to 0.

**Rule - every terrace riser gets a dark contact band at its base.** Cube
World's riser runs V .77 at the top to .32 at the foot and resets per step;
that is what makes a stepped hillside read as corduroy to the horizon (lens
3). A poster prints the terrace edge as a line, so the contact is a band:
the bottom quarter of every vertical face at 0.72, hard, per block, no
matter how many blocks the greedy quad spans (`fract(world_pos.y / 0.5)` in
the same shader edit). Baked vertex AO stays.

**Rule - the aspect tint is right; keep it.** Two flat tones meeting at the
ridge is the poster hillside; `aspect_tint` 0.12 -> 0.18 is worth one look
once the shade ink lands (lens 1).

### 2.5 Forest

**Rule - the conifer is the darkest thing in the picture and a cut-out
shape.** Broders' foreground spruce is V 0-16 (`#060505`, `#130C0B`), the
lit mid-distance spruce `#214328`-`#2F4B35`; Cardinaux's is ultramarine
(`#135781`); real spruce is a near-achromatic dark blue-green (`#41524F` lit,
`#25322A` shade) (lens 1, 5). Nowhere is a conifer a mid green of V50.
`LEAVES #4E7A32` is a beech green with a conifer silhouette. **Spruce
`#2F4F3E` / `#385C48`**, and with the shade ink the dark side lands near
`#1C1F24` = Broders' near-black. Trunks maroon-to-grey-brown (`#5E4238`), not
chocolate.

**Rule - the forest floor is needle brown, not a lawn.** Under a closed
canopy the ground is the wood's darkest warm band (`#6C4D34` lit); a green
floor makes every wood a mown park, and it also breaks the three-greens-in-
a-row zone stack (meadow, floor, alpine turf) with a brown (lens 5).
**`FOREST_FLOOR #70583D`.**

**Rule - the larch is the warm accent among blue-greens; protect it.** It is
the one entry where the current palette, the photograph (`#C29A4D`) and the
posters (`#BD7E40`, `#CE9F65`) already agree (lens 5). Move it least
(`#BD994B` / `#C9A75D`) and move everything else so it stays the accent -
which also means the birch comes off chartreuse (`#84A85B`) and the reed off
gold (`#8F8859`).

**Species at 40 m** (lens 5, 6): spruce the darkest and bluest; larch the
warm one, open; beech an August true green (`#4F7A3A`), 14 value points above
spruce; krummholz warm-dark (`#3F5E35`), never teal, so it separates from the
spruce below and the olive turf beside it. Every pair that can share a frame
holds 10 value points or 15 degrees of hue apart.

**Tree shapes are frozen for look v2** (worldgen: same 73,675 trees). The Deco
tree vocabulary, for the later tree plan (lens 6, from Le Mont Revard, Le
Brevent, Guebwiller):

- **Spruce:** a notched spire, max width one third of height (`r = round(h/6 -
  0.5)`), skirt to the ground (crown base at 0.12 h, not 0.28 h), notch of one
  block on alternate layers only while the tapered radius is >= 2, a
  one-wide leader for the top 15% of the height, octagonal plan for r >= 3
  (the same chamfer the heads take), the bottom two whorls one block
  narrower than the widest so the base turns in.
- **Two colours per tree, and the second lives on the whorl underside** -
  detached blue-violet slivers where a shelf shades the one below, never
  scattered through the crown. At range one flat triangle in one colour.
- **Larch:** the same spire at 1:4.2, fill 0.5 so sky shows through, notch
  every third layer. **Beech:** an oblate scallop 1.2-1.3x wider than tall,
  widest at 40% of the crown, a sky gap under it on a pale trunk.
  **Krummholz:** a cushion 2.0-2.5x wider than tall, flat top, no spike.

### 2.6 Meadow and ground cover

**The meadow saturation question, answered three ways and resolved.** The
status doc suspected "a step toward olive". The real hay meadow *is* olive
(`#99A869`, H74 S38; lens 5). The posters are two things: Broders' near lit
lawn is a true green, darker (`#558831` H95 V53, Combloux) while his and
Cardinaux's mid and high meadows are olive-chartreuse (median of ten: H57 S56
V62; lens 1). Both agree on **darker** (10 points) and on saturation around
55; they split on hue by 40 degrees. The split is altitude: the valley meadow
holds the green, the alp turf goes olive. So `GRASS` rotates 5 degrees off
yellow and drops 9 points of value - **`#809945`** (H78 S55 V60) - and
`ALPINE_GRASS` goes properly olive-sage, **`#9C9D68`** (real alp turf is S15-34;
lens 5). The lime read was a value problem in a saturation costume, and half
of it was the transfer (section 0).

**Rule - a flat field is made alive by a dark mark, not a modulation.** Cube
World's near grass is ONE flat colour with no noise at all; the tufts do the
work, at a third of the ground's value, dense (one per 1.5 blocks), all
leaning one way (lens 3). Foliage v1 found that a sparse dark single-tone
tuft reads as a hole; the difference is density and the two tones. So the
tuft base goes to **0.62x** the ground's value (`#4E6E30`) with the tip a step
over (`#9BB65A`), and the near-field density comes back up (0.34 -> 0.50
inside ~12 m). Judged on `8-meadow-closeup`: a field with dark grain and
drifts of one flower, not confetti.

**Rule - a flower is darker or more saturated than its field, never lighter.**
Yellow carries a real alpine meadow (globeflower, buttercup, arnica), white
second, magenta third, blue-violet a minority, scarlet absent above 1000 m
(lens 5). Kubik's purple `#9B6FC4` (V77) is *lighter* than the meadow and is
the loudest thing in `1-spawn`. Purple -> `#67479E`, yellow -> `#EDC834`, red
-> alpenrose magenta `#C2487B`. Proportions are placement and out of scope; a
note that yellow should outnumber purple.

### 2.7 Water and shore

**Rule - water is the sky's ink, dark, with a drawn shore.** Three sources,
one answer with three parts. Colour: the lake is the current sky/mountain
tone a step darker and never a separate cyan (Handschin's lake is its own sky
to two value points; Annecy's lake `#6B6E87` is its ranges; lens 1, 4), and
an alpine tarn is *dark* - real bodies V31-55, Broders' Lauch Lake `#194864`
(lens 5); Kubik's `#4C8FBF` (V75) is a swimming pool. Body **`#4A6A8A`** at
noon (H205 S46 V54), published by time of day like the shade (dawn `#B6BCCE`,
dusk `#6E7396`, night `#2C3E63`), alpha 0.92. Shore: the edge is drawn, not
blended - a rim line and a shallows shelf with a value cliff at the
waterline (A Short Hike, Tunic; lens 2; Thonon, Annecy, Guebwiller; lens 6):
**rim 2 blocks (1 m) at +18% value, shallows 8 blocks (4 m) at +8%**, from the
shore field `lakes.gd` already computes. No waves, no mirror reflection -
the posters never do it; 3-5 detached pale horizontal slivers under the sun
are the whole of a reflection, and they are second-pass.

**The shore is not a beach.** A pre-Alpine tarn shore is grey gravel (`#73807F`
lit) or turf to the waterline; no poster prints a yellow strand at altitude
(lens 5). `SHORE #BFB48C` -> **`#91948E`**, `SAND #D9C785` -> `#C7C0AB` (unused,
same mistake waiting). The shore is also far too *wide* in `5-lake` and
`6-postcard`; that is worldgen and frozen - a line for `IDEAS.md`.

### 2.8 Rock, snow and boulders

**Rock:** neutral albedo, **`STONE #ADA9A1`**; the sun makes it cream and the
shade ink makes it violet-slate (`#4B4353` under the day ink - Gotthard
`#3D3D50`, Le Brevent `#5F5464`). A summit in shade is violet-slate, never
brown-black (lens 1, 5). Deco draws a cliff as parallel vertical slivers
alternating lit and shade and a peak in four values (snow-white, alpenglow,
mid violet, deep violet); the far field's flank normal over 96 m already
gives the two-sided read (lens 6).

**Snow:** cream (paper), never white; its shade a mauve-to-violet second ink
at 60-75% of the lit value (Le Brevent `#ECEDE5` -> `#CEC3C4` -> `#726E8A`).
`SNOW #F2F0E8` stays - the sun's `#FFF2D1` makes it cream and the ink makes
the shade - with the on-screen check that lit snow is lighter than the sky
and its shade lands near `#726B8B`.

**Boulders:** one body colour plus **one warm lit slice cut by a single
straight plane** through the blob at the world's sun azimuth, 30-35% of the
visible area - Guebwiller's foreground rocks, Cardinaux's seracs (lens 6).
Not per-face. `BOULDER #B2B0A8` plus a new `BOULDER_LIT #D0CCC2`.

### 2.9 Characters

Look v1's proportions hold: head about a third of the height sits inside the
25-37% range of every reference; stocky is right (lens 3). What the
references do differently, all from measured Cube World, Crossy Road, Staxel
and Trove (lens 3):

- **The face is two solid dark marks.** Cube World's eye is 1 wide x 3 tall,
  solid near-black, no white, no iris, on a 12-wide head; Staxel 2x3 solid;
  Trove a light plate with a dark pupil and a brow bar in the *hair's*
  colour. What survives distance is the AREA of the darkest mark. Kubik's 4x4
  white with a 2x2 iris averages to a light smudge at 40 m and two pale
  squares with a dot at 4 m (`study-noon-40m-front`, `study-detail-4m`). So:
  eye **2 wide x 4 tall solid iris colour**, gap 6, at most one 1x1 catchlight
  at the top-inner corner; brow one row in the hair colour or none; mouth
  4-5 wide, one value step darker than skin; keep the 2x3x1 nose (it is
  silhouette). Build the eye one voxel proud like the nose (Crossy Road) so
  the ramp gives it a lit top and a shaded underside at dusk.
- **The hair or hat is a mass that breaks the head box.** Cube World's hair
  overhangs both sides and juts past the face plane; Staxel's bob runs past
  the cheeks under a hard fringe at brow height. Beyond ~20 m the head-plus-
  hair outline is the only thing identifying a character. Kubik's hair sits
  inside the head's own footprint, which is why `masks-40` shows four
  identical lollipops (human/lizardfolk IoU 0.91). Overhang 1-3 voxels in a
  direction that differs per race: human a forward fringe 2 proud and 1
  wider; elf swept back 3 past the skull; dwarf the beard 4 below the jaw and
  2 wider than the head; lizardfolk the crest. Keep the hard fringe line.
- **One colour per part, no per-voxel noise, a value ratio <= 0.5 between
  neighbouring parts.** About ten colours per character; trim as single-voxel
  accents in a colour appearing nowhere else on the figure. The human's
  dark-brown cloth against dark-brown hair reads as one brown mass with a
  face (`closeup-front`); a palette audit in `races.gd`.
- **Figures fog toward the darker target** (2.3), and never take the terrain
  grain.

This revises look v1's face spec, which Marcel decided; it is carried as a
plan stage that runs only on his yes.

### 2.10 UI

The theme is right in its parts (paper, ink, gold, alpine blue, sun; Limelight
/ Josefin Sans) and thin in its ornament. From the posters and the Deco
sources (lens 6), all buildable from `StyleBoxFlat` and `draw_*` with no
texture:

- **The sunburst** wants alternating long and short rays that *taper* (the Deco
  mirror: ~36 rays, short 0.55 of long, tip to a point) around a disc in a
  plain ring; the title reads as ink on paper inside a gold ring, not on solid
  gold. `poster_backdrop.gd`: 24 + 24 rays as tapered 4-gons, paper disc,
  gold ring.
- **The title lives inside a full-width flat band** (12-28% of the height,
  light type on dark: coral on green, gold on wood, orange on navy), 2-4
  lines at ~0.45 / 1.00 / 0.55 / 0.35 with one tracking, secondary lines a
  lighter VALUE of the same ink (BLS 1921), never a new hue. One theme colour,
  `INK_PALE #7D7C78`.
- **The stepped corner, honestly:** three nested `StyleBoxFlat`s, each inset
  ~5 px and one step less chamfered (outer ink r14, middle gold r10, inner
  paper r6), band ratio 3 : 2 : 1 (Combloux's own frame).
- **The rule does not bleed to the edge:** inset 8 px and terminated by a
  5x5 gold square (Combloux flanks its subtitles with small filled squares);
  a square-dot divider, a chevron divider (three across, apex ~95 degrees,
  amplitude 7 px, 3 px stroke) and a roundel (paper disc in a double gold
  ring, one stroke weight, a Limelight monogram) as small `Control`s beside
  `DecoRule`.

### 2.11 Light by time of day - the complete sets

Every column chosen together, as a lithograph is (lens 4, reconciled with 1
and 2). sRGB; starting values, judged after the Stage 0 fix.

| row | DAWN | NOON | DUSK | NIGHT |
| --- | --- | --- | --- | --- |
| sun colour | `#FFC7A0` | `#FFF2D1` | `#FCA55A` | `#9AAAD0` (moon) |
| sun energy | 0.85 | 1.00 | 0.90 | 0.75 |
| shade ink | `#9A97BE` | `#7A7396` | `#4A6FB4` | `#39456E` |
| shade desat | 0.55 | 0.55 | 0.65 | 0.75 |
| fog target | `#E4CDB8` | `#C9C3C4` | `#D9C4B0` | `#223A5E` |
| sky horizon | `#F3C79E` | `#EBDFC8` | `#F4CBA0` | `#25406E` |
| sky mid | `#E4C9C2` | `#B4C1D6` | `#9A8CC0` | `#1D3764` |
| sky top | `#BBD5DC` | `#89A1CB` | `#6C68A4` | `#152A55` |
| water body | `#B6BCCE` | `#4A6A8A` | `#6E7396` | `#2C3E63` |
| cloud lit | `#FFE2C8` | `#F2E8D0` | `#F2C489` | `#6F7C9E` |
| cloud shade | `#C2A9B4` | `#A9B4C2` | `#8E86B4` | `#22314F` |
| the accent | `#F2A80D` | `#C9A24A` | `#E8A02E` | `#E8892E` |
| campfire light | `#FFA351` 0.20, 7 m | 0.06, 5 m | 0.28, 7.5 m | 0.55, 9 m |

Checks that the sets are right (rendered results, not constants): lit snow at
noon lands near `#D0C4A5`-`#E8E7DB`, its shade near `#726B8B`; at dusk lit snow
near Combloux's `#E9AA62` against a cobalt shade; at night the sky is *lighter
than the ground* (Broders' moonlit street: sky V52, shadow V25) and the lake
does not vanish into it.

Notes on the table: the dusk sky top is between lens 1's Broders mauve
(`#B9A3B4`) and lens 4's Handschin indigo (`#3B44A2`), a violet at their
shared value; dawn is lens 4's; the fog targets are the horizon colours
desaturated ~35% toward their luminance and a step darker (2.3); the water
follows the sky's hue at a step darker; the campfire is the accent hue as a
point light through the ramp's existing `!LIGHT_IS_DIRECTIONAL` branch -
with `omni_attenuation 1.0` the ramp's thresholds give a 0.50 R hot pool and a
0.88 R outer ring and nothing beyond, which is Duneland's three-step fire; no
more bands (lens 4).

**What "dusk" needs to mean.** Today the dusk keyframes are never on screen:
at elevation 0, `day_amount` is 0 so every function lerps from NIGHT and only
0.75-0.85 of the way to DUSK (`fog_color(0)` = `#A97861`, not `#DB9973`;
`sun_energy(0)` = the moon's 0.32; `sky_top` = pure night). Lens 4's arithmetic;
`11-forest-dusk` samples a V40 sky where no poster dusk lives below V63. The
weights go to 1.0, `sun_energy()` gets the dusk term the other functions have,
and a `SKY_TOP_DUSK` exists.

---

## 3. The palette, old -> new

Targets for the on-screen lit colour at noon after Stage 0; all starting
values. Reasons are one line; the evidence is in section 2 and lens 5's
sampled photographs.

### `Block.COLORS`

| entry | old | new | reason |
| --- | --- | --- | --- |
| STONE | `#9A8F80` | `#ADA9A1` | limestone is neutral; the sun owns the warmth (2.8) |
| DIRT | `#8B6F47` | `#7A5F47` | alpine soil is a dark grey-brown, not light ochre |
| GRASS | `#86B04A` | `#809945` | darker, 5 degrees off yellow; the valley keeps the green (2.6) |
| SAND | `#D9C785` | `#C7C0AB` | unused; grey-buff when it lands |
| SNOW | `#F2F0E8` | keep | the sun makes it cream, the ink makes the shade |
| FOREST_FLOOR | `#5A8C3C` | `#70583D` | needle brown, and it breaks the three-greens stack (2.5) |
| LEAVES (spruce A) | `#4E7A32` | `#2F4F3E` | the darkest thing in the picture, blue-leaning (2.5) |
| TRUNK | `#6B4F2A` | `#5E4238` | maroon-grey-brown, not chocolate |
| SHORE | `#BFB48C` | `#91948E` | grey gravel, not a beach (2.7) |
| ALPINE_GRASS | `#A7B860` | `#9C9D68` | the one green that really is olive (2.6) |
| HEATH | `#8C5F4B` | `#6B3933` | maroon, not brick; 26 degrees from the new floor |
| LEAVES_SPRUCE_B | `#557F38` | `#385C48` | follows spruce A, a few percent apart |
| LEAVES_BEECH | `#6E9C3E` | `#4F7A3A` | August beech, 14 value points above spruce |
| LEAVES_BEECH_B | `#78A448` | `#5F8A46` | follows |
| LEAVES_LARCH | `#B89B3C` | `#BD994B` | already right; five degrees warmer, protected (2.5) |
| LEAVES_LARCH_B | `#C2A649` | `#C9A75D` | follows |
| LEAVES_PINE | `#3C6B4C` | `#3F5E35` | krummholz is warm-dark, never teal |
| LEAVES_PINE_B | `#437356` | `#4D6B40` | follows |
| LEAVES_BIRCH | `#9CBF57` | `#84A85B` | the lightest crown without being a lamp |
| LEAVES_BIRCH_B | `#A6C763` | `#92B268` | follows |
| TRUNK_BIRCH | `#D5D2C4` | keep | correct; the lavender it shows is the ink working |
| TRUNK_DEAD | `#9A9186` | `#9E9990` | bone-grey; marginal |

### `FloraModels.COLORS`

| entry | old | new | reason |
| --- | --- | --- | --- |
| GRASS_BLADE | `#78A244` | `#4E6E30` | tuft base at 0.62x the meadow's value: a mark, not a modulation (2.6) |
| GRASS_BLADE_DRY | `#9BC258` | `#9BB65A` | tip one step over the new meadow |
| GRASS_ALPINE | `#9DB05A` | `#ACB276` | one step over the new alpine turf |
| STEM | `#86A845` | `#6E8C47` | on the meadow's hue at meadow value |
| FERN | `#5E9440` | `#4D7A3B` | darker than meadow, lighter than spruce; reads on the brown floor |
| MUSHROOM_STEM | `#C9BFA8` | keep | real as authored |
| MUSHROOM_CAP | `#D96A4A` | `#CC503D` | a truer red beside the maroon heath |
| SHRUB_HEATH | `#96604A` | `#805245` | a step lighter than the new heath ground |
| SHRUB_HEATH_B | `#A06B4E` | `#8F6153` | follows |
| BOULDER | `#B4AEA3` | `#B2B0A8` | neutral, value kept (lit edge-on) |
| BOULDER_LIT | - | `#D0CCC2` | NEW: the lit slice, one plane cut (2.8) |
| REED | `#9C9552` | `#8F8859` | not a second gold |
| FIREFLY | `#FFE9A0` | keep | emissive |
| FLOWER_WHITE | `#F2EFE2` | keep | the paper white |
| FLOWER_YELLOW | `#E8C64A` | `#EDC834` | buttercup, and it should carry the meadow |
| FLOWER_PURPLE | `#9B6FC4` | `#67479E` | darker than its field; gentian-ward |
| FLOWER_RED | `#C9504A` | `#C2487B` | alpenrose magenta; scarlet is a poppy |
| FLOWER_ALPINE | `#D8E4F0` | keep | edelweiss / cotton grass |

Water (`lakes.gd`): `#4C8FBF` alpha 0.85 -> published by time of day, noon
`#4A6A8A`, alpha 0.92, plus rim and shelf (2.7).

Checked as a stack (lens 5): low to high the surfaces now run grey gravel ->
green -> needle brown -> olive turf -> maroon -> pale grey rock -> cream
snow. Every neighbour differs in hue *and* value; today's first four bands
are three greens and a yellow.

---

## 4. Rejected, and specs for later content

**Rejected.**
- *Outlines* (inverted hull or screen-space). No reference game uses them;
  the value contracts do the job; Sobel is unavailable on Compatibility; an
  inverted hull on split-normal voxel meshes needs a centroid channel. Only
  if 2.3's figure fog and 2.1's ink fail to separate a character at 40 m.
- *Palette-variant block ids for grain* (Teardown's trick). Splits greedy
  quads; a flat meadow chunk goes from one quad to hundreds. The fragment
  hash does the same with zero mesh cost.
- *Okami's paper and brush.* Textures by definition.
- *Hard-edged flat colour patches for the meadow* (A Short Hike). Right in
  principle - the greedy mesher would give hard edges for free - but placing
  a second grass id from noise is a worldgen change and worldgen is frozen.
  Recorded for a later worldgen pass.

**Specs for later content** (lens 6; not built here):
- *Campfire and smoke:* fire a stepped cone of three tiers in sun `#E8863A`
  over one ember tier a value darker, logs three crossed dark-brown blocks,
  light per the table (2.11); smoke a leaning stack of five scalloped
  octagonal lobes, each +0.4 block radius and +2.5 blocks up, lean 0.6
  downwind per lobe, flat paper by day, ink-tinted at night, opaque, and a
  hard top - it stops, it does not fade (Broders' locomotive plume).
- *Way-marker:* a 5-block post (`TRUNK`) with two paper bands, a gold
  chevron-cut blade 6 x 2 x 0.5 blocks with ink caps tracked, a 2x2 paper
  altitude plate at the pivot - the marker IS the gold thing in a green
  meadow. Permanent boards invert it: wood ground, gold caps, gold double
  rule, two posts.
- *Trees:* section 2.5.
- *Far field crest rim and snow-as-shape:* section 2.3.
- *Tour camera:* the posters put the horizon ~15% from the top and the
  darkest thing (a framing spruce) nearest; the landscape shots would pitch
  10-15 degrees down and prefer a near spruce at one edge. A tour-script
  change, not a look constant.

---

## 5. The refinements, ranked

Impact first; cost in the terms look v1 used. Each is one or more plan
stages; "after 0" means it cannot be judged before the transfer fix.

| # | refinement | cost | evidence shot |
| --- | --- | --- | --- |
| 1 | **Fix the colour transfer.** Find and remove the second linearisation of vertex colour; divide `LIGHT_COLOR` by PI in the ramp; `fog_sky_affect` 0; a calibration swatch sheet in the gallery whose sampled pixels must match prediction on BOTH renderers. Sun energy 0.70 -> 1.0. | a shader edit inside look.gd, a conversion decision, a gallery sheet | `testcube`, then every shot |
| 2 | **Dusk exists.** Dusk mix weights to 1.0, `sun_energy()` gets a dusk term, `SKY_TOP_DUSK`, a `sky_mid` stop in the sky shader. | a constant change plus four one-line edits, a small shader edit | `11-forest-dusk`, a wide dusk shot |
| 3 | **Shade as ink.** Luminance-keeping shade mix with a published `kubik_shade_desat`; new shade colours day / dusk / night. | a shader edit inside look.gd, constants | `7-forest-interior`, `2-summit`, `12-meadow-night` |
| 4 | **Fog is not the horizon.** Split the fog target from the sky's lowest band; 4 bands from 240 m; fog toward the fragment's own desaturated colour. | constants, a shader edit in `FOG_FN`, one uniform | `6-postcard`, `2-summit` |
| 5 | **Far field bands monotonic**, 60 m, +0.03, capped. | a knob change plus ~10 lines in `_band_color` | `6-postcard`, `9-treeline` |
| 6 | **Night lifted.** Sky lighter than the ground, moon light `#9AAAD0`, night shade `#39456E`, desat 0.75. | constants | `12-meadow-night` |
| 7 | **The palette pass** (section 3), judged after 1-6. | a palette pass | `1-spawn`, `5-lake`, `7`, `8`, `9` |
| 8 | **Grain in the fragment shader**, contact band at every riser, jitter to 0, grain fades with fog; the opaque material split into terrain and figure materials. | a shader edit inside look.gd, two knobs to zero, a material split | `8-meadow-closeup`, `3-forest-slope` |
| 9 | **Figures fog darker** than the ground (via the figure material). | one global, in the split | `9-treeline`, `1-spawn` with a character at 40 m |
| 10 | **Water:** colour by time of day, alpha 0.92, rim 2 blocks, shelf 8 blocks. | constants plus a contained `lakes.gd` mesh edit | `5-lake`, `10-shore` |
| 11 | **Clouds** as horizon lozenges, warm paper lit, sky-hued underside. | a shader edit inside look.gd | `1-spawn`, `2-summit` |
| 12 | **Dawn keyframe** and the morning flag; rays tapered and alternating; halo as lifted sky; moon halo; (option) gold moon disc. | a new keyframe in SkyCycle, a shader edit | needs a dawn shot; `2-summit`, `12` |
| 13 | **Meadow tufts** dark base / bright tip, near density up. | a palette entry plus one knob | `8-meadow-closeup` |
| 14 | **Boulders** two-tone by one plane. | a model edit | `9-treeline` |
| 15 | **Characters:** solid dark eyes, brow in the hair colour, hair mass overhang per race, palette audit. | a generator edit and a re-author | `closeup-front`, `masks-40`, `study-noon-40m` |
| 16 | **UI:** tapered sunburst in a ring, title band, stepped-corner panel, rule terminals, `INK_PALE`. | a theme edit plus a scene edit | `build/ui/<label>/` |

Below the line: the tour camera pitch; the far-field crest rim and snow
shapes; water reflection slivers; everything in section 4.

---

## 6. Sources

Posters (Wikimedia Commons, Gallica/BnF, SBB Historic, the V&A): Broders -
Combloux 1925, Le Mont Revard 1927, Sports d'Hiver au Col de Voza, Villard de
Lans, Le Brevent, L'Aiguille du Dru 1924, Chamonix-Martigny, Lac d'Annecy,
Thonon-les-Bains, St-Gervais Mt d'Arbois, La Route des Alpes, Le Tour du Mont
Blanc 1927, St-Pierre de Chartreuse 1930, The Ballon of Guebwiller and the
Lauch Lake, A Street by Moonlight (Visit India). Cardinaux - Zermatt 1908,
Summer in the Grisons 1909, Jungfrau-Bahn 1910, RhB Schloss Tarasp 1913,
Chur-Arosa-Bahn 1915, L'Automne en Suisse 1921, Palace Hotel St. Moritz 1921,
Berne-Lotschberg-Simplon 1921, Silsersee, Sommer in der Schweiz, Gotthard,
St. Moritz, Vulpera-Tarasp. Others - Handschin Silvaplana (two), Val d'Aosta
1935, Merlet Ortisei, Landolt Luzern 1936, Dagan Moonlight in Duneland 1926,
Tanconville Lac d'Annecy; Brandt's Porte d'honneur 1925 and fire screen;
the Forum Cinema sunburst mirror; Swiss Wanderweg and RhB signposts.
Matter, Carigiet, Baumberger, Moos and Koch are in copyright and were not
obtained; the poster findings rest on Broders and Cardinaux, which is the
core of the direction.

Games (Steam store screenshots, sampled): Firewatch, Sable, Journey, Tunic, A
Short Hike, RiME, The Pathless, SEASON, COCOON, Röki, Cube World, Teardown,
Trove, Staxel, Lay of the Land; Crossy Road (App Store); Vintage Story.

Talks and posts: Campo Santo's procedural sky post; Jane Ng, "Making the
World of Firewatch" (GDC 2016); Shedworks on Sable's readability and "The
Art of Sable" (GDC 2022); Wind Waker inverted-hull breakdowns; the Alto's
making-of; Gustafsson, "The Spraycan" (blog.voxagon.se); Lysenko, "Ambient
occlusion for Minecraft-like worlds" (0fps); Sir Carma on 80.lv;
godotengine/godot#109553 and godot-proposals#3959 on Compatibility limits.

Photographs (Wikimedia Commons): Seealpsee, Alp Sigel, Churfirsten, Santis,
Samtisersee, Alp Chessel, Bachalpsee (three), Alpe Devero, Bedretto larches,
Larix decidua in autumn (two), Pinus mugo, alpenrose on the Sunniggratli, a
hay meadow in flower, Trollius on a mountain meadow, round-headed rampion,
limestone scree below the Schneid.
