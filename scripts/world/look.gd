class_name Look

## The poster. One lighting ramp for everything drawn, and the materials that
## carry it.
##
## The art direction is decided in docs/plans/look-v1.md: an Art Deco Alpine
## travel poster. Flat colour fields, three tones of light, shade that is a
## COLOUR rather than a darkness, and distance that steps in bands rather than
## fading in haze. This file is the whole of that direction as far as the
## renderer is concerned - terrain, far field, far trees, characters, plants
## and water all draw through the shader built here, so the ramp lives in
## exactly one place and a change to it changes the world.
##
## WHY ONE STRING AND NOT `#include`. The plant shader is built from code at
## runtime and so are these, and the tour runs on the Compatibility renderer
## on a box with no display. A shader include file is one more resource to
## import, one more thing that can differ between the two renderers, and it
## buys nothing over concatenating a constant. So the ramp is RAMP below, and
## every shader here is HEADER + its own vertex/fragment + RAMP.
##
## THE GLOBALS. Everything the ramp needs that changes with the time of day is
## a global shader parameter, declared in project.godot and written once per
## frame by SkyCycle.apply() - the sun's elevation is what defines the shade
## colour and the fog, and SkyCycle is the only thing that knows where the sun
## is. The defaults in project.godot are a clear day, so a scene without a
## SkyCycle (a self-test, a stray tool) draws sensibly rather than black.
##
##   kubik_shade      vec4  the colour of shade, LINEAR
##   kubik_fog_color  vec4  the colour of distance, LINEAR - the sky's horizon
##   kubik_fog_start  float metres at which the first band begins
##   kubik_fog_end    float metres at which the last band is total
##   kubik_fog_bands  float how many flat steps between the two
##   kubik_night      float 0 by day, 1 at night (foliage v1)
##
## LINEAR, NOT source_color. The palettes in Block, FloraModels and Races are
## all stored linear and converted once at load, for a reason those files
## record: the Compatibility renderer ignores colour-space hints. The globals
## follow the same rule - SkyCycle converts before it publishes - so there is
## one convention and no hint for a renderer to ignore.
##
## ... AND sRGB ON THE WIRE. The one exception, added in look v2 Stage 0: a
## vertex colour is converted back to sRGB by Look.to_wire() at the moment it is
## pushed into a mesh, because the renderer decodes an 8-bit vertex colour on
## the way to ALBEDO. Everything upstream of that push is still linear and all
## the colour arithmetic still happens there. What is authored is what is on
## screen, and the swatch sheet proves it every stage.


# --- The ramp ----------------------------------------------------------------

## Uniform declarations, shared by every shader below.
const HEADER := """
global uniform vec4 kubik_shade;
global uniform vec4 kubik_fog_color;
global uniform float kubik_fog_start;
global uniform float kubik_fog_end;
global uniform float kubik_fog_bands;
global uniform float kubik_night;
global uniform float kubik_shade_desat;
global uniform vec4 kubik_fog_dark;
global uniform vec4 kubik_water;

// THE ALBEDO, LINEAR, set by every fragment() and read by light().
//
// It does not travel in ALBEDO, and that is deliberate: the renderer multiplies
// whatever light() writes by ALBEDO, so a light function that needs the albedo
// in a form OTHER than a plain scale - and the ink formula does, it desaturates
// it - cannot put it there without it being applied a second time. Every
// fragment() therefore sets ALBEDO to white, hands the real colour over here,
// and light() owns the whole expression. That is correct whether or not the
// renderer re-applies ALBEDO, which is the one thing the two renderers were
// found to disagree about.
varying vec3 v_albedo;

// The inverse of the push conversion (see Look.to_wire). Vertex colours travel
// sRGB on the wire and the engine decodes ALBEDO for us; anything that is NOT
// ALBEDO - EMISSION, most of all - has to decode for itself or it glows at its
// sRGB value, which is far too bright.
vec3 kubik_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
"""

## THREE TONES. A face is lit, half-lit, or in shade, and nothing in between.
##
## The thresholds are on n.l scaled by the light's own attenuation, which for
## the sun carries the shadow map - so a face in shadow is in the shade band
## whichever way it points, and the shadow's edge is the band's edge: hard, and
## the shade colour, exactly as a poster prints it. The smoothsteps are three
## hundredths wide, which is invisible on a voxel face (there are only six
## normals in the world and none of them sits on a threshold) and just enough
## to keep the far field's facets from shimmering where a triangle's normal
## grazes one.
##
## THE DIRECTIONAL LIGHT IS THE ONLY LIGHT THAT PAINTS SHADE. Its contribution
## runs from the shade colour up to its own colour - so the dark side of the
## world is blue-violet, never black. Any other light (a campfire, later) adds
## banded light where it reaches and nothing where it does not, which is what
## makes a fire the one warm thing in a cool night rather than a second sun.
const RAMP := """
const float BAND_LIT = 0.50;
const float BAND_HALF = 0.22;
const float BAND_HALF_LEVEL = 0.55;
const float BAND_EDGE = 0.03;
// The lit band pushed toward white. 0 turns it off. Mirrored by Look.LIT_BLEACH
// for Look.predict(); change one, change both.
//
// TUNED TO 0 IN STAGE 4, from the plan's starting 0.10 and inside its 0-0.15
// range. The mix is toward white in LINEAR, so it lifts a dark colour far
// harder than a light one: at 0.10 it raised the lake's red channel from 0.068
// to 0.162 and took the water from H 197 S 36 to H 187 S 13 - a grey-teal
// sheet where the plan asks for a dark tarn. Every dark colour in the game
// paid the same: the spruce, the heath, the deep leaf.
//
// At 0 the lit branch is exactly albedo * sun * energy, which is also the
// plainest possible statement of "what is authored is what is on screen".
const float LIT_BLEACH = 0.0;

float poster_band(float ndl) {
	float lit = smoothstep(BAND_LIT - BAND_EDGE, BAND_LIT + BAND_EDGE, ndl);
	float half_lit = smoothstep(BAND_HALF - BAND_EDGE, BAND_HALF + BAND_EDGE, ndl);
	return max(lit, half_lit * BAND_HALF_LEVEL);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = poster_band(ndl);
	// LIGHT_COLOR is the light's colour times its energy times PI. The PI is
	// the Lambert normalisation, and a poster does not want it: it made every
	// lit surface 3.14x its authored value and every constant downstream was
	// chosen to cancel it. Divide it out here, once, and an authored colour
	// lit at noon lands at authored * sun * energy.
	vec3 L = LIGHT_COLOR / PI;
	// SHADE IS AN INK. The shade side keeps the surface's LUMINANCE and takes
	// the ink's HUE - which is what a printed shadow does and what a multiply
	// cannot do. Desaturate toward the surface's own luminance, then colour
	// the result with the ink. The lit side is pushed a little toward white,
	// the way a poster's lit face is paper showing through.
	//
	// v_albedo, not ALBEDO: see the note in HEADER. ALBEDO is white and this
	// function owns the whole expression, so nothing is applied twice.
	if (LIGHT_IS_DIRECTIONAL) {
		float lum = dot(v_albedo, vec3(0.2126, 0.7152, 0.0722));
		vec3 shade_alb = mix(v_albedo, vec3(lum), kubik_shade_desat);
		vec3 lit_alb = mix(v_albedo, vec3(1.0), LIT_BLEACH);
		DIFFUSE_LIGHT += mix(shade_alb * kubik_shade.rgb, lit_alb * L, band);
	} else {
		DIFFUSE_LIGHT += v_albedo * L * band;
	}
}
"""

## DISTANCE IS BANDS. Depth fog quantised to kubik_fog_bands flat steps between
## start and end, toward the sky's horizon colour. Written into FOG, which
## replaces the environment's own fog for this material; the environment fog
## stays switched on for the sky, which is not drawn through this.
##
## The last band is exactly the fog colour, and SkyCycle sets the sky's horizon
## to the same value, so the far mesh's edge is never a line against the sky.
const FOG_FN := """
// 0 for terrain, 1 for anything that stands ON it. Set per material, not per
// vertex: the vertex colour's alpha is already the flora's emissive flag.
uniform float fog_dark_mix = 0.0;

// WHERE THE AIR BEGINS, as a fraction of the FAR RADIUS rather than as a
// number of metres. Distance v3 Stage 5, and DH's `farFogStart 0.4`.
//
// The fog wall is not a fog property; it is a fog-over-thirty-metres property.
// Vanilla Minecraft ramps its fog over the last two chunks of a 200-block
// radius and gets a wall; DH ramps over 60% of a 4 km radius and gets aerial
// perspective. Ours ramped from 320 m to 800 m, which is the vanilla shape.
//
// A FRACTION, NEVER A METRE VALUE, because the world is unbounded by design and
// nothing may bake in a reach (CLAUDE.md, 2026-08-31). At 0 this falls back to
// kubik_fog_start, so fog_start_m still does something and is still on F4.
uniform float far_fog_start_frac = 0.4;

// DH's EXPONENTIAL_SQUARED density, and its default. The curve is
// 1 - exp(-(density * t)^2) over the normalised span, divided by its own value
// at t = 1 so the last band is exactly the fog colour and the far mesh's own
// edge is never the thing you notice first.
const float FOG_DENSITY = 2.5;

// The fog factor at one distance, before the bands. Split out of poster_fog so
// the curve is in one place and the DISTANCE is the caller's business - which
// it has to be, because it is cylindrical for the world and spherical for
// anything that has no world position to hand.
float poster_fog_curve(float dist) {
	float start = far_fog_start_frac > 0.0
		? kubik_fog_end * far_fog_start_frac : kubik_fog_start;
	float t = clamp((dist - start) / max(kubik_fog_end - start, 1.0), 0.0, 1.0);
	float k = FOG_DENSITY * t;
	return (1.0 - exp(-k * k)) / (1.0 - exp(-FOG_DENSITY * FOG_DENSITY));
}

// THE FOG AT A DISTANCE THE CALLER CHOOSES. Distance v3 Stage 5.
//
// CYLINDRICAL, WHEN THE CALLER CAN BE. Spherical distance fogs a peak by how
// far away it is THROUGH THE AIR, so standing under a mountain and looking up
// hazes its summit as hard as ground at the same range - and the sky behind it
// is not hazed at all, because the sky is not drawn through this. The result is
// a bright sky behind a grey peak, which is the one thing a travel poster never
// does. DH's fog is cylindrical by default for exactly this reason.
vec4 poster_fog_at(vec3 view_vertex, vec3 albedo, float dist) {
	float f = poster_fog_curve(dist);
	f = floor(f * kubik_fog_bands + 0.5) / kubik_fog_bands;
	// HUE IS HELD ACROSS THE BANDS. Fading everything to one fog colour turns
	// a green range and a grey range into the same grey at the same distance;
	// a poster keeps the hue and drains the saturation. So the target is the
	// fragment's OWN colour, desaturated and lifted, and only then mixed
	// toward the fog - which is why a far hillside still reads as a hillside.
	float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
	vec3 self = mix(albedo, vec3(lum), 0.5) * 1.25;
	vec3 target = mix(self, kubik_fog_color.rgb, 0.6);
	// A FIGURE FOGS DARKER THAN THE GROUND BEHIND IT, or it dissolves into it
	// at exactly the distance you most need to see it.
	return vec4(mix(target, kubik_fog_dark.rgb, fog_dark_mix), f);
}

// The spherical form, kept so callers that have no world position keep working
// unchanged - FloraModels is one, and it is another lane's file. Nothing grows
// past 128 m and the fog does not start until 0.4 of the far radius, so the
// flora has never reached a non-zero fog factor and still does not.
vec4 poster_fog(vec3 view_vertex, vec3 albedo) {
	return poster_fog_at(view_vertex, albedo, length(view_vertex));
}
"""


# --- The shaders --------------------------------------------------------------

## Everything opaque that is its own colour: terrain, far field, far trees,
## characters. No texture, no specular, no ambient - the ramp owns the shade.
const OPAQUE_SHADER := """
shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;
""" + HEADER + FOG_FN + """
// GRAIN, AND IT IS NOT A TEXTURE. Hard rule 3: no new textures, ever. This is
// a hash of the world-space half-metre cell the fragment falls in, which gives
// every block face its own small offset in value and a smaller one in hue -
// the tooth of the paper a poster is printed on. Off on figures.
uniform float grain_amount = 0.065;
uniform float grain_hue = 0.03;
// Optional: gate the grain to the top `grain_sparse` share of cells at a fixed
// step, for materials so flat that an even grain reads as noise. 0 is off.
uniform float grain_sparse = 0.0;
// How dark the bottom half-metre of a vertical face goes. A printed block has
// a line where it meets the ground; this is that line, and it is arithmetic.
uniform float contact_band = 0.72;
// EMISSIVE, FOR FIGURES ONLY, and it is off by default for a reason.
//
// Character v2 Stage 10 gave characters an emissive channel in the vertex
// colour's ALPHA, exactly where flora's has always been. Terrain, the far field
// and the impostor ring share this shader's SOURCE and write alpha 1, so an
// unconditional EMISSION line here would set the entire world glowing. The
// uniform is per-material, defaults to 0, and only figure_material() sets it.
//
// This was only safe to do at all because distance v1 Stage 6 gave the
// impostor forest its own material. Before that, figure_material() had two
// callers and this line would have lit two thousand cones on every hillside.
uniform float figure_emissive = 0.0;

varying vec3 world_pos;
// THE NORMAL IN WORLD SPACE. fragment()'s NORMAL is in VIEW space, so
// abs(NORMAL.y) there is "how much the face points at the top of the screen",
// not "how much it points up" - which quietly put a contact band on flat
// ground whenever the camera was pitched, and cost this stage a swatch gate.
varying vec3 world_normal;

float hash3(vec3 c) {
	return fract(sin(dot(c, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// The vertex colour IS the albedo. There are no textures in this world.
	// It arrives sRGB on the wire (Look.to_wire) and is decoded here, once.
	v_albedo = kubik_to_linear(COLOR.rgb);

	// THE GRAIN. mod() before the hash keeps the argument small: at +-1500
	// blocks a raw world coordinate loses enough mantissa on a highp float
	// that the hash starts banding into stripes.
	vec3 cell = mod(floor(world_pos / 0.5), 1024.0);
	float h = hash3(cell);
	float amount = grain_amount;
	if (grain_sparse > 0.0) {
		amount = h > 1.0 - grain_sparse ? 0.12 : 0.0;
	}
	float g = (h * 2.0 - 1.0) * amount;
	float t = (hash3(cell + vec3(17.0)) * 2.0 - 1.0) * grain_hue;
	vec3 grained = v_albedo * (1.0 + g) * vec3(1.0 + t, 1.0, 1.0 - t);
	// GONE BY 45 m, whatever the fog is doing. Cube World's grain is invisible
	// by 30 m; past that it stops being a surface and becomes a shimmer, and
	// the far field - which shares this material - must never show it.
	float near = 1.0 - smoothstep(20.0, 45.0, length(VERTEX));
	v_albedo = mix(v_albedo, grained, near);

	// THE CONTACT BAND. Only on vertical faces, and only the bottom half of a
	// half-metre cell - so a terrace riser has a line under it and a flat
	// field does not.
	float up = abs(world_normal.y);
	float fy = fract(world_pos.y / 0.5);
	v_albedo *= mix(1.0, mix(contact_band, 1.0, step(0.25, fy)), 1.0 - up);

	// The rune band on a named piece. Present by day and strong at night: a
	// floor of 0.25 rather than zero, because pillar 2's register is that the
	// dark is where the warm things show, not that they only exist there.
	EMISSION = kubik_to_linear(COLOR.rgb) * COLOR.a * figure_emissive
		* mix(0.25, 1.0, kubik_night);

	ALBEDO = vec3(1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// CYLINDRICAL DISTANCE, distance v3 Stage 5. world_pos is already a
	// varying here; the camera's own world position is the translation column
	// of the inverse view matrix.
	FOG = poster_fog_at(VERTEX, v_albedo,
		length(world_pos.xz - INV_VIEW_MATRIX[3].xz));
}
""" + RAMP

## Water. The same ramp, drawn from both sides and through.
##
## Double-sided because the surface is a single plane with nothing underneath
## it: standing in a lake and looking up at a one-sided surface shows you
## nothing at all, which reads as a bug rather than as water. Not shiny -
## terrain v1 gave it roughness 0.15 and a specular highlight sliding across a
## lake as you walk is rule 2's exact failure. A poster lake is a flat blue.
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, ambient_light_disabled, specular_disabled;
""" + HEADER + FOG_FN + """
void fragment() {
	// The vertex colour is a DARKENING FACTOR per ring, not a colour; the
	// colour is the hour's, published as kubik_water. See lakes.gd.
	v_albedo = kubik_to_linear(COLOR.rgb) * kubik_water.rgb;
	ALBEDO = vec3(1.0);
	ALPHA = COLOR.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Cylindrical, like the terrain. No world_pos varying here, so it is
	// recovered from the view-space vertex.
	vec3 w_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	FOG = poster_fog_at(VERTEX, v_albedo,
		length(w_pos.xz - INV_VIEW_MATRIX[3].xz));
}
""" + RAMP


## THE SKY. A poster sky: a gradient in flat bands, a sun that is a disc with
## RAYS, clouds that are shapes, and at night a moon and stars.
##
## Everything here is a function of the view direction and a handful of
## uniforms SkyCycle sets from the time of day. Colours arrive LINEAR, like the
## globals. Nothing moves except the sun: the clouds are fixed to the sky, and
## a static cloud is a shape while a drifting one is weather.
##
## THE RAYS are the single most Deco thing in the sky and the plan says not to
## make them subtle. Alternating wedges around the sun, fading with angular
## distance, strongest at dawn and dusk when the sun is on the horizon and the
## wedges fan across the whole sky. Painted one band lighter than the sky they
## cross, never white.
##
## THE CLOUDS are two octaves of value noise on the direction, cut at a hard
## threshold - so the edge is a line, not a fade - one tone lighter than the
## band they sit in, with a darker underside along their bottom edge, which is
## the whole of how a poster cloud is drawn.
const SKY_SHADER := """
shader_type sky;

global uniform vec4 kubik_fog_color;

uniform vec4 sky_top = vec4(0.07, 0.21, 0.66, 1.0);
uniform vec4 sky_mid = vec4(0.24, 0.36, 0.60, 1.0);
uniform vec4 sky_horizon = vec4(0.46, 0.60, 0.77, 1.0);
uniform vec4 cloud_lit = vec4(0.88, 0.83, 0.66, 1.0);
uniform vec4 moon_color = vec4(0.79, 0.24, 0.03, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec4 sun_color = vec4(1.0, 0.89, 0.64, 1.0);
uniform float day = 1.0;
uniform float dusk = 0.0;
uniform float night = 0.0;
uniform float sky_bands = 5.0;
uniform float ray_count = 24.0;
uniform float ray_strength = 0.4;
uniform float ray_extent = 0.9;
uniform float ray_extent_short = 0.45;
uniform float sun_size = 0.035;
uniform float cloud_cover = 0.35;

const float TAU_ = 6.28318530718;
// How far down the sky the underside is sampled, in polar units. See the note
// where it is used.
const float CLOUD_LIP = 0.08;

// sRGB ON THE WIRE, FOR THE SKY TOO.
//
// A sky shader's COLOR goes to the framebuffer WITHOUT the linear-to-sRGB
// conversion every other surface gets - measured, look v2 Stage 2: a noon sky
// whose bands mix to a linear (0.428, 0.514, 0.663) came back as #6A7FA8, and
// #6A7FA8 is that linear triple written out as bytes, not its sRGB encoding
// (#B0BFDA). So the sky has been displaying every authored colour as its RAW
// LINEAR value since look v1 - which is why SKY_TOP_DAY had to be a #4D80D4
// that looks nothing like the poster to arrive as something that did.
//
// Every uniform here stays linear, like every other palette in the game, and
// the conversion happens once, on the way out.
vec3 kubik_to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055,
		step(vec3(0.0031308), c));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float clouds(vec2 uv) {
	return vnoise(uv) * 0.65 + vnoise(uv * 2.3 + vec2(7.1, 3.3)) * 0.35;
}

// ALTERNATING LONG AND SHORT WEDGES THAT TAPER, around any axis.
//
// ray_count is the number of PAIRS, so there are twice that many wedges and
// every other one reaches only `short_mul` as far. Each wedge narrows to 0.15
// of its base width by the time it reaches its own extent, which is what makes
// it a 4-gon pointing away from the disc rather than a stripe of constant
// width - the single most Deco thing in the sky, and the plan says not to make
// it subtle.
float poster_wedges(vec3 dir, vec3 axis, float extent, float short_mul) {
	float cs = dot(dir, axis);
	float ang = acos(clamp(cs, -1.0, 1.0));
	vec3 t1 = normalize(cross(axis, vec3(0.0, 1.0, 0.0)));
	vec3 t2 = cross(axis, t1);
	vec3 perp = dir - axis * cs;
	float phi = atan(dot(perp, t2), dot(perp, t1));

	float pair = fract(phi * ray_count / TAU_);
	float is_short = step(0.5, pair);
	float local = fract(pair * 2.0);
	float reach = mix(extent, extent * short_mul, is_short);
	float taper = mix(0.25, 0.25 * 0.15, clamp(ang / max(reach, 0.001), 0.0, 1.0));
	float wedge = step(abs(local - 0.5), taper);
	float fade = 1.0 - smoothstep(0.0, reach, ang);
	return wedge * fade;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, 0.0, 1.0);

	// THE BANDS, IN THREE STOPS. Horizon to mid over the lower half, mid to
	// top over the upper - so a poster sky has a warm band near the ground, a
	// cool one overhead and a transition that is a stated colour rather than
	// whatever a two-stop lerp passes through. Denser near the horizon, where
	// a poster stacks them.
	float band = floor(pow(up, 0.6) * sky_bands) / sky_bands;
	vec3 col = band < 0.5
		? mix(sky_horizon.rgb, sky_mid.rgb, band * 2.0)
		: mix(sky_mid.rgb, sky_top.rgb, (band - 0.5) * 2.0);
	// Below the horizon is the FOG colour - a step darker than the sky's
	// lowest band - so the far mesh's last band and the ground of the sky are
	// the same value and a far range is a cut-out against the sky, never glass
	// over it. Rule 2, sharpened.
	if (dir.y < 0.0) {
		col = kubik_fog_color.rgb;
	}

	// THE SUN, ITS RAYS AND ITS HALO.
	float cs = dot(dir, sun_dir);
	float sun_up = smoothstep(-0.05, 0.05, sun_dir.y);
	float rays = poster_wedges(dir, sun_dir, ray_extent, ray_extent_short)
		* ray_strength * sun_up * step(0.0, dir.y);
	// One band lighter than the sky it crosses by day, and only at dusk does
	// it take the sun's own colour - a white-hot fan at noon reads as a bug.
	vec3 halo = mix(col, vec3(1.0), 0.08);
	halo = mix(halo, sun_color.rgb, dusk);
	col = mix(col, halo, rays);
	float disc = step(cos(sun_size), cs) * sun_up;
	col = mix(col, sun_color.rgb, disc);

	// THE MOON: a gold disc with a short faint fan, after dark. It bends rule
	// 5 by one object and Marcel approved it knowing that; it is one uniform
	// to turn off. The moon's LIGHT stays the cold blue the ramp uses.
	float moon_rays = poster_wedges(dir, moon_dir, 0.5, ray_extent_short)
		* 0.10 * night * step(0.0, dir.y);
	col = mix(col, mix(col, moon_color.rgb, 0.5), moon_rays);
	float cm = dot(dir, moon_dir);
	float moon = step(cos(0.018), cm) * night;
	col = mix(col, moon_color.rgb, moon);

	// THE CLOUDS, SAMPLED IN POLAR COORDINATES of the plane projection, so a
	// cloud is a LOZENGE lying along the horizon rather than a blob that
	// happens to be foreshortened. Cut at a hard threshold - the edge is a
	// line, not a fade - and given one fixed-width shade lip on the underside
	// by sampling the same field one constant step further out, which in polar
	// is one constant step DOWN the sky.
	if (dir.y > 0.02) {
		vec2 uv = dir.xz / (dir.y + 0.35) * 1.6;
		vec2 puv = vec2(atan(uv.y, uv.x) * 7.0, length(uv) * 2.2);
		float thr = 1.0 - cloud_cover * 0.75;
		float here = step(thr, clouds(puv));
		// ONE FIXED-WIDTH LIP, and the width is the whole of it. The plan says
		// 0.35 of a polar unit; measured, a cloud in this field is about half a
		// unit across radially, so 0.35 swallowed the entire shape and every
		// cloud drew as its own underside - dark brown blobs instead of lit
		// lozenges. 0.08 is a lip.
		float below = step(thr, clouds(puv + vec2(0.0, CLOUD_LIP)));
		float underside = here * (1.0 - below);
		float near_horizon = smoothstep(0.02, 0.12, dir.y);
		float cloud = here * near_horizon;
		vec3 lit = cloud_lit.rgb;
		vec3 shade = mix(col, sky_horizon.rgb, 0.35) * 0.86;
		vec3 cloud_col = mix(lit, shade, underside);
		// NO SECOND NIGHT TERM. Look v1 derived the cloud's lit colour from
		// the sky band and then darkened the result by up to 0.35 after dark.
		// cloud_lit is an authored keyframe row now - #FFE2C8 at dawn, #6F7C9E
		// at night - so how dark a cloud is at this hour is already in it, and
		// multiplying again turned a warm dawn cloud into a taupe smudge.
		col = mix(col, cloud_col, cloud);
	}

	// THE STARS, after dark.
	//
	// A 3D cell hashed in two stages: hashing x + 17 z directly collapses
	// whole rows of cells onto one value and the first night tour had every
	// star in one patch of sky.
	vec3 cell = floor(dir * 220.0);
	float star_seed = hash2(cell.xz + vec2(hash2(cell.xy) * 61.0, cell.y * 3.7));
	float star = step(0.994, star_seed) * night * smoothstep(0.05, 0.2, dir.y);
	col += vec3(0.7, 0.75, 0.9) * star;

	COLOR = kubik_to_srgb(col);
}
"""


# --- The materials ------------------------------------------------------------

static var _opaque: ShaderMaterial = null
static var _water: ShaderMaterial = null
static var _figure: ShaderMaterial = null
static var _sky: ShaderMaterial = null
static var _far_field: ShaderMaterial = null
static var _mutex := Mutex.new()


## The sky material. Main thread only - the environment is not a worker's.
static func sky_material() -> ShaderMaterial:
	if _sky == null:
		_sky = _make(SKY_SHADER)
	return _sky


## One material for every opaque vertex-coloured mesh in the game.
##
## Shared on purpose: the renderer batches meshes that share a material, and
## a character made of the same stuff as the ground it stands on is the whole
## point of the character pipeline. Built under a mutex because chunk meshing
## asks for it from worker threads.
static func opaque_material() -> ShaderMaterial:
	if _opaque != null:
		return _opaque
	_mutex.lock()
	if _opaque == null:
		_opaque = _make(OPAQUE_SHADER)
	_mutex.unlock()
	return _opaque


## THE SAME SHADER, FOR THINGS THAT STAND ON THE GROUND RATHER THAN BEING IT.
##
## One shader string, two materials: the figures fog toward the darker colour
## and (from Stage 3) take no grain. Two materials means one extra draw group,
## which is the whole cost - and it is what keeps a character from fogging into
## the hillside behind it.
static func figure_material() -> ShaderMaterial:
	if _figure != null:
		return _figure
	_mutex.lock()
	if _figure == null:
		_figure = _make(OPAQUE_SHADER)
		_figure.set_shader_parameter("fog_dark_mix", 1.0)
		# No grain and no contact band on a figure: a character is printed
		# flat, and a line under its feet would follow it around.
		_figure.set_shader_parameter("grain_amount", 0.0)
		_figure.set_shader_parameter("contact_band", 1.0)
		# The only material in the game that reads the vertex alpha as emissive.
		# See the uniform's note in OPAQUE_SHADER.
		_figure.set_shader_parameter("figure_emissive", 1.0)
	_mutex.unlock()
	return _figure


static func water_material() -> ShaderMaterial:
	if _water != null:
		return _water
	_mutex.lock()
	if _water == null:
		_water = _make(WATER_SHADER)
	_mutex.unlock()
	return _water


static func _make(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


## THE HOUR'S GOLD, in sRGB, for anything that is drawn rather than lit.
##
## The sun disc, a nametag's rule, and later the campfire: things that are the
## poster's ACCENT rather than a surface the ramp lights. It reads the same
## keyframe table SkyCycle publishes from, so the UI's gold and the world's
## gold are the same decision - dawn #F2A80D, noon #C9A24A, dusk #E8A02E,
## night #E8892E.
##
## sRGB out, because its callers are Controls and Label3Ds, which take sRGB.
static func accent_color(elevation: float, morning := false) -> Color:
	return (SkyCycle.keyframe_at(elevation, morning)["accent"] as Color).linear_to_srgb()


## The value `shade_ink()` answers with before SkyCycle has published anything -
## a scene opened on its own, or a column submitted on the first frame.
const SHADE_INK_DEFAULT := Color(0.25, 0.29, 0.55, 1.0)

## The last shade ink published, cached on the way OUT rather than read back in.
##
## READ BACK, THIS WAS A STALL ON THE COLUMN HOT PATH. Stage 6 wrote
## `shade_ink()` as a `RenderingServer.global_shader_parameter_get()`, which
## Godot answers with "ERROR: This function should never be used outside the
## editor, it can severely damage performance" - and meant it. World submits one
## column per job and read it once per submission: 346 of those readbacks during
## world generation alone on Marcel's box, each one a synchronous round trip to
## the rendering server, sitting inside the frame times night 2 is measured
## against.
##
## Nothing needed reading back. `publish()` is the only writer and it runs every
## frame; the value is simply kept here on the way past. Identical behaviour,
## no round trip.
static var _shade_ink := SHADE_INK_DEFAULT


## The shade ink SkyCycle last published, linear. For anything that authors a
## colour rather than lighting one - the understorey, world feel v1 Stage 6.
##
## Safe from a worker thread, which the readback never was: see
## ColumnJob.shade_ink, which exists only because this had to be captured on the
## main thread at submit time.
static func shade_ink() -> Color:
	return _shade_ink


# --- The wire ------------------------------------------------------------------

## THE ONE CONVERSION, and the only one in the whole colour path.
##
## Every palette in the game is stored LINEAR and every multiplier that acts on
## a colour - baked AO, the far field's skirt and band, aspect tint, jitter - is
## a linear multiplication, exactly as it was. This is the last thing that
## happens to a vertex colour before push_back, and it exists because the
## renderer treats an 8-bit vertex colour as sRGB and decodes it on the way to
## ALBEDO. Push linear and it is decoded a second time; push sRGB and what
## arrives at ALBEDO is what was authored.
##
## LINEAR MATHS, sRGB ON THE WIRE. If you find yourself converting anywhere
## else, something is wrong: there is one conversion and this is it.
static func to_wire(c: Color) -> Color:
	return c.linear_to_srgb()


# --- Publishing ---------------------------------------------------------------

## Write the time-of-day globals. Called by SkyCycle.apply() every frame with
## colours that are ALREADY LINEAR - see the note at the top.
static func publish(kf: Dictionary,
		fog_start_m: float, fog_end_m: float, fog_bands: int) -> void:
	_set_color(&"kubik_shade", kf["shade"])
	# Kept on the way past, so nothing ever has to ask the rendering server for
	# it again. See _shade_ink.
	_shade_ink = kf["shade"]
	_set_color(&"kubik_fog_color", kf["fog"])
	_set_color(&"kubik_fog_dark", kf["fog_dark"])
	# THE RIM'S COLOUR, not the body's. The lake mesh carries a darkening factor
	# per ring (1.0 / 0.915 / 0.847) and the lightest of the three is the rim,
	# so the published colour is the row lifted by 18% - which lands the BODY
	# on the authored row and keeps every factor at or below 1.0 in eight bits.
	_set_color(&"kubik_water", (kf["water"] as Color) * 1.18)
	RenderingServer.global_shader_parameter_set(&"kubik_shade_desat", kf["shade_desat"])
	RenderingServer.global_shader_parameter_set(&"kubik_fog_start", fog_start_m)
	RenderingServer.global_shader_parameter_set(&"kubik_fog_end", fog_end_m)
	RenderingServer.global_shader_parameter_set(&"kubik_fog_bands", float(maxi(fog_bands, 1)))


## Push the terrain's local knobs into its material. Called from the main thread
## at startup and whenever the F4 panel moves, exactly as
## FloraModels.apply_local_knobs() is.
##
## The FIGURE material deliberately does not take them: its grain is off and
## its contact band is 1.0 by construction, and an F4 slider that quietly put
## grain back on the characters would be a bug nobody would look for.
static func apply_local_knobs(config: WorldgenConfig) -> void:
	var m := opaque_material()
	m.set_shader_parameter("grain_amount", config.grain_amount)
	m.set_shader_parameter("grain_hue", config.grain_hue)
	m.set_shader_parameter("grain_sparse", config.grain_sparse)
	m.set_shader_parameter("contact_band", config.contact_band)
	# DISTANCE V3, appended. The far field's own material takes the terrain's
	# knobs too - it is the same shader - plus the ones only it has. Pushed here
	# rather than at FarField.setup() so a move on F4 lands without a reroll,
	# which is what every knob in this epic has to do.
	var f := far_field_material()
	f.set_shader_parameter("grain_amount", config.grain_amount)
	f.set_shader_parameter("grain_hue", config.grain_hue)
	f.set_shader_parameter("grain_sparse", config.grain_sparse)
	f.set_shader_parameter("contact_band", config.contact_band)
	f.set_shader_parameter("far_grain", config.far_grain)
	f.set_shader_parameter("far_dither_m", config.far_dither_m)
	# THE FOG CURVE IS EVERY MATERIAL'S, distance v3 Stage 5, so it is pushed to
	# all four of them rather than to the terrain's alone. FloraModels builds
	# its own materials from Look.FOG_FN and is another lane's file, so its
	# copy keeps the shader's default 0.4 - which is correct and inert: nothing
	# grows past 128 m and the fog does not start until 1,280 m.
	for mat in [m, f, figure_material(), water_material()]:
		mat.set_shader_parameter("far_fog_start_frac", config.far_fog_start_frac)


static func _set_color(name: StringName, c: Color) -> void:
	RenderingServer.global_shader_parameter_set(name, Vector4(c.r, c.g, c.b, 1.0))


## Mirrors RAMP's LIT_BLEACH. Change one, change both - Look.predict() reads
## this and the shader reads the constant in RAMP, and the swatch sheet is what
## catches them drifting apart.
const LIT_BLEACH := 0.0


# --- The prediction -----------------------------------------------------------

## Luminance, Rec. 709, on a LINEAR colour. The shade mix keeps this and takes
## the ink's hue - see RAMP.
static func luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


## What RAMP puts on screen for a linear albedo, in sRGB, for a given sun state.
##
## MIRRORS RAMP LINE FOR LINE: change one, change both. This exists so the
## swatch sheet and the shader cannot drift - the sheet calls this, the shader
## IS this, and Stage 0's whole claim ("what is authored is what is on screen")
## is the two agreeing to within 6 units per channel on both renderers.
##
## `lit` is the band the surface is in: true for band 1.0 (n.l over BAND_LIT),
## false for band 0.0 (the shade band). The half-lit band is deliberately not
## predicted - the sheet only shoots the two ends, because the middle is a mix
## of them and proves nothing the ends do not.
static func predict(albedo_linear: Color, lit: bool,
		sun_linear: Color, energy: float, shade_linear: Color,
		shade_desat: float, lit_bleach: float) -> Color:
	var out: Color
	if lit:
		var bleached := albedo_linear.lerp(Color(1.0, 1.0, 1.0), lit_bleach)
		out = Color(bleached.r * sun_linear.r * energy,
			bleached.g * sun_linear.g * energy,
			bleached.b * sun_linear.b * energy)
	else:
		var l := luma(albedo_linear)
		var desat := albedo_linear.lerp(Color(l, l, l), shade_desat)
		out = Color(desat.r * shade_linear.r,
			desat.g * shade_linear.g,
			desat.b * shade_linear.b)
	return Color(clampf(out.r, 0.0, 1.0), clampf(out.g, 0.0, 1.0),
		clampf(out.b, 0.0, 1.0)).linear_to_srgb()


# --- The far trees ------------------------------------------------------------
#
# Distance v1 Stage 6. Appended here rather than beside figure_material()
# because a character redesign is editing that function in a parallel lane, and
# the whole point of this stage is that the two do not collide: the behaviour
# change lives at the CALL SITE, in FarTreeMeshes.material(), and look.gd gains
# one function and the static var it needs.

static var _far_tree: ShaderMaterial = null


## A TREE IS SCENERY. A PERSON IS NOT. Do not change this back.
##
## Until distance v1 Stage 6 the impostor ring was drawn with
## figure_material(), which is the treatment that stops a CHARACTER dissolving
## into the hillside behind it: fog_dark_mix 1.0, so a figure fogs toward the
## dark colour rather than toward the hillside's own. Applied to two thousand
## cones on a mountainside it does the exact opposite of what the far field is
## for - it forbids the forest from receding, so a wooded ridge at 500 m reads
## as a stand of green triangles pasted onto the picture instead of as part of
## the mountain.
##
## Grep found only two callers of figure_material(): voxel_model.gd, which is
## characters, and FarTreeMeshes, which is not. So the impostor ring was the
## one piece of SCENERY in the game drawn as a figure, and it sat precisely
## where the eye compares it against the terrain it is supposed to belong to.
##
## So: the terrain's fog (fog_dark_mix 0.0) and the terrain's grain, and NO
## CONTACT BAND. The contact band draws a dark line along the bottom half of
## every half-metre cell of a vertical face; on a six-triangle cone at 200 m
## that is not a line where a block meets the ground, it is horizontal stripes
## across the whole tree.
##
## The grain is left at the shader's own default rather than wired to
## apply_local_knobs(), and that is deliberate rather than an oversight: the
## grain is faded out entirely by 45 m (see OPAQUE_SHADER) and the nearest
## impostor in the game stands at the voxel radius, 96 m at High. It can never
## be visible on one. Setting it to the terrain's value is a statement about
## which family this material belongs to, not an effect.
## THE FAR FIELD'S OWN MATERIAL, distance v3 Stage 2.
##
## THE SAME SHADER SOURCE AS THE CHUNKS, WITH TWO BLOCKS SPLICED IN, and the
## splice is the whole design rather than a shortcut.
##
## The compensating rule for opening look.gd in this epic is absolute: the near
## field must be byte-identical at default knobs, checked by `swatches.png` and
## `swatch-ramp.png`, after EVERY shader-touching stage. The obvious
## implementation - one shader string with a `far_grain` uniform defaulting to
## zero and an untaken branch - leaves that gate resting on a shader compiler
## being indifferent to a branch it never enters. Probably true. Not provable
## from here, and a gate that rests on "probably" is not a gate.
##
## So OPAQUE_SHADER is not edited at all. The far field's code is built from it
## at runtime by inserting two blocks at two anchors, which means the string the
## chunks compile is the string `main` compiled, character for character, and
## the swatch gate holds by construction rather than by measurement.
##
## It also buys what Stage 7 needs anyway: a material seam. The far field stops
## batching with the chunks - one extra draw group for one mesh, the same price
## figure_material() and far_tree_material() already pay - and gains somewhere
## for the Bayer dissolve to live.
##
## THE ANCHORS ARE ASSERTED. If somebody renames a line in OPAQUE_SHADER, this
## fails loudly at startup rather than quietly drawing a far field with no
## grain, which is a bug that would be found by eye a week later.
const FAR_DECL_ANCHOR := "varying vec3 world_pos;"
const FAR_CODE_ANCHOR := "\tALBEDO = vec3(1.0);"

## THE GRAIN, ON A WORLD-SPACE BLOCK LATTICE. Distance v3 Stage 2, and it is
## Distant Horizons' noise recipe (`docs/research/distant-horizons.md` §4) with
## one change, which is the interesting part.
##
## DH's recipe, verbatim in mechanism: hash a world-space QUANTISED position, so
## the fleck is stable under camera motion and does not swim; weight the
## amplitude by a parabola in luminance peaking at mid-grey, so nothing happens
## on blacks or whites; and brighten toward white - `c + (1 - c) * r` - rather
## than perturbing RGB symmetrically, so it never muddies a hue. That last form
## is also what makes it safe: r is zero-mean, so the EXPECTED colour is
## unchanged and the far country gains variance without gaining a tint. Hard
## rule 6, satisfied by the arithmetic rather than by a measurement - and
## measured anyway, in Stage 2's gate 1.
##
## THE CHANGE: DH FADES ITS NOISE OUT PAST 1024 BLOCKS AND THIS GROWS ITS
## LATTICE INSTEAD. DH's reason for the dropoff is that a quarter-block lattice
## past a kilometre is sub-pixel and aliases. That is a statement about ANGULAR
## size, and the fix that follows from it is to keep the angular size constant:
## the lattice starts at one block - the near field's own grain cell, so the
## seam has nothing to give it away - and grows with view distance at about two
## screen pixels per cell. A far hillside at 3 km is then flecked in ten-metre
## cells, which is a couple of pixels, rather than in half-metre cells nobody
## can resolve. This is also what the block-atlas idea says: per-block detail
## painted on geometry far coarser than a block, off a fract() of world
## position, tiling once per lattice cell across a quad of any size.
##
## THE LATTICE BLENDS BETWEEN TWO LEVELS rather than jumping, the way a mip
## chain does - two hashes and a mix on the fractional level. A hard jump in
## lattice size is a visible ring on the ground at a fixed distance from the
## player, which is the artefact distance v1 spent a stage removing from the
## geometry and would be absurd to reintroduce in the paint.
const FAR_GRAIN_DECL := """
// DISTANCE V3 STAGE 2. Spliced into the far field's copy of this shader only;
// the chunks compile the string above without these lines in it at all.
uniform float far_grain = 0.0;

// THE DITHERED DISSOLVE, distance v3 Stage 7. DH's, verbatim in mechanism
// (`docs/research/distant-horizons.md` §5b): a 4x4 Bayer matrix keyed on SCREEN
// coordinates - "the fragCoord is used since it is stable and small so the
// dithering is cleaner" - smoothstepped over [clip, 1.5 * clip], discard below.
// Dither rather than alpha because it works identically for opaque and
// transparent passes and needs no sorting.
//
// The clip distance is in METRES and 0 turns it off. See far_dither_m.
uniform float far_dither_m = 0.0;

float bayer4x4(vec2 c) {
	int x = int(mod(c.x, 4.0));
	int y = int(mod(c.y, 4.0));
	int i = x + y * 4;
	// The 4x4 ordered dither, over 16.
	float m[16] = float[16](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0);
	return m[i] / 16.0;
}
// The lattice at the seam, in metres: one block, which is the near field's own
// grain cell, so the two grains are the same grain.
const float FAR_GRAIN_NEAR_M = 0.5;
// Metres of lattice per metre of view distance - about two screen pixels at
// 1280x720 and a 68 degree camera. This is DH's noise dropoff turned inside
// out: keep the fleck at a constant angular size instead of switching it off.
const float FAR_GRAIN_PX = 0.003;
// 0.5 m * 2^7 = 64 m, which is the outermost ring's own cell.
const float FAR_GRAIN_MAX_LEVEL = 7.0;

"""

const FAR_GRAIN_CODE := """
	// THE DISSOLVE, FIRST, so a discarded fragment costs nothing else.
	if (far_dither_m > 0.0) {
		float fd_step = smoothstep(far_dither_m, far_dither_m * 1.5,
			length(VERTEX));
		// DH's "minor fudge factor to make sure all pixels fade out - if not
		// included 1 in 16 pixels would never fade away".
		if (fd_step <= bayer4x4(FRAGCOORD.xy) + 0.001) {
			discard;
		}
	}

	// THE FAR GRAIN. See Look.FAR_GRAIN_DECL for the whole argument.
	if (far_grain > 0.0) {
		float fg_d = length(VERTEX);
		float fg_lvl = clamp(log2(max(fg_d * FAR_GRAIN_PX, FAR_GRAIN_NEAR_M)
			/ FAR_GRAIN_NEAR_M), 0.0, FAR_GRAIN_MAX_LEVEL);
		float fg_lo = floor(fg_lvl);
		float fg_cell = FAR_GRAIN_NEAR_M * exp2(fg_lo);
		// mod() before the hash for the reason the near grain does it: a raw
		// world coordinate at the rim loses enough mantissa that the hash bands
		// into stripes.
		float fg_h = mix(
			hash3(mod(floor(world_pos / fg_cell), 1024.0)),
			hash3(mod(floor(world_pos / (fg_cell * 2.0)), 1024.0)),
			fg_lvl - fg_lo);
		float fg_lum = (v_albedo.r + v_albedo.g + v_albedo.b) / 3.0;
		// The parabola, written as x*x rather than pow(x, 2.0): pow() with a
		// negative base is undefined in GLSL and this base is negative for
		// every colour darker than mid-grey, which is most of this world.
		float fg_x = fg_lum * 2.0 - 1.0;
		float fg_amp = (1.0 - fg_x * fg_x) * far_grain;
		float fg_r = fg_h * 2.0 * fg_amp - fg_amp;
		v_albedo = v_albedo + (1.0 - v_albedo) * fg_r;
	}

"""


## OPAQUE_SHADER with the far field's blocks spliced in. See far_field_material.
static func far_field_code() -> String:
	var code := OPAQUE_SHADER
	if not code.contains(FAR_DECL_ANCHOR) or not code.contains(FAR_CODE_ANCHOR):
		push_error("[Look] the far-field shader anchors are gone from OPAQUE_SHADER")
		return code
	code = code.replace(FAR_DECL_ANCHOR, FAR_GRAIN_DECL + FAR_DECL_ANCHOR)
	return code.replace(FAR_CODE_ANCHOR, FAR_GRAIN_CODE + FAR_CODE_ANCHOR)


static func far_field_material() -> ShaderMaterial:
	if _far_field != null:
		return _far_field
	_mutex.lock()
	if _far_field == null:
		_far_field = _make(far_field_code())
	_mutex.unlock()
	return _far_field


static func far_tree_material() -> ShaderMaterial:
	if _far_tree != null:
		return _far_tree
	_mutex.lock()
	if _far_tree == null:
		_far_tree = _make(OPAQUE_SHADER)
		_far_tree.set_shader_parameter("fog_dark_mix", 0.0)
		_far_tree.set_shader_parameter("contact_band", 1.0)
	_mutex.unlock()
	return _far_tree


# --- Trees v3 Stage 2: the tree material ------------------------------------

static var _tree: ShaderMaterial = null


## A TREE IS SCENERY WITH SWAY.
##
## `far_tree_material()` above already settled the first half and its note is
## the argument: `fog_dark_mix` 0.0 so a wooded ridge RECEDES into the mountain
## instead of being pasted onto it, and `contact_band` 1.0 because the contact
## band draws a dark line along the bottom of every half-metre cell of a
## vertical face and a tree is not made of half-metre cells. Do not change
## either back.
##
## What that material cannot do is move a vertex, and trees v3 decision 9 is
## that trees sway. So this is the same treatment on a shader with a `vertex()`
## - the same relationship `FloraModels.material()` has to the opaque shader,
## for the same reason and at the same cost of one extra draw group.
##
## THE WEIGHT IS COLOR's ALPHA, and open question 3 is answered there rather
## than here: `TreeModels._build()` bakes each vertex's height as a fraction of
## its own model's, 0 at the roots and 1 at the top. A tree is the one model
## family in this game with no emissive parts, so the channel the mushrooms use
## for their glow is free - and using it costs no attribute, no second stream
## and no branch.
##
## SQUARED, so the crown moves and the roots do not even slightly. A linear
## weight leaves a spruce's lowest branches visibly shearing sideways, which is
## the artefact `FloraModels`' own sway note describes as "grass that slides
## sideways as a rigid block reads as a bug" - and a trunk is far more rigid
## than a blade of grass.
##
## PHASE FROM THE INSTANCE'S WORLD POSITION, exactly as the plants do, so a
## stand of trees moves in one wave rather than each shivering on its own. The
## period is longer and the amplitude smaller than grass: a 25 m tree that
## moves like a tuft is a tree made of rubber.
static func tree_material() -> ShaderMaterial:
	if _tree != null:
		return _tree
	_mutex.lock()
	if _tree == null:
		_tree = _make(tree_shader_code())
		_tree.set_shader_parameter("fog_dark_mix", 0.0)
		_tree.set_shader_parameter("contact_band", 1.0)
		# Off until Stage 8, which is where the sway is judged. The shader is
		# in from Stage 2 so that the thing Stage 8 turns on is a UNIFORM and
		# not a new material - swapping a material mid-epic would move every
		# tree's colour on the same night the sway arrives, and then neither
		# could be judged.
		_tree.set_shader_parameter("tree_sway", 0.0)
	_mutex.unlock()
	return _tree


## Push the tree knobs. Called beside `apply_local_knobs`, from the main thread.
static func apply_tree_knobs(config: WorldgenConfig) -> void:
	var m := tree_material()
	m.set_shader_parameter("tree_sway", config.tree_sway)
	m.set_shader_parameter("grain_amount", config.grain_amount)
	m.set_shader_parameter("grain_hue", config.grain_hue)
	m.set_shader_parameter("grain_sparse", config.grain_sparse)
	m.set_shader_parameter("far_fog_start_frac", config.far_fog_start_frac)


## THE OPAQUE SHADER WITH A `vertex()` SPLICED IN, and the splice is the same
## discipline distance v3 used for the far field: the fragment half, the ramp,
## the fog and the grain are the shared source, character for character, so a
## tree and the ground it stands on can never disagree about what shade looks
## like. Only the vertex program is new.
static func tree_shader_code() -> String:
	var code := OPAQUE_SHADER
	if not code.contains(TREE_DECL_ANCHOR) or not code.contains(TREE_SWAY_ANCHOR):
		push_error("[Look] the tree shader's anchors are gone from OPAQUE_SHADER")
		return code
	code = code.replace(TREE_DECL_ANCHOR, TREE_DECL + TREE_DECL_ANCHOR)
	return code.replace(TREE_SWAY_ANCHOR, TREE_SWAY + TREE_SWAY_ANCHOR)


## THE SWAY GOES INSIDE THE OPAQUE SHADER'S OWN `vertex()`, NOT BESIDE IT.
##
## The first attempt appended a second `vertex()` before `fragment()` and the
## compiler said `Redefinition of 'vertex'` - OPAQUE_SHADER has had one since
## look v2, computing `world_pos` and `world_normal` for the grain and the fog.
##
## Which turns out to be the right place anyway, and not a consolation. The
## sway has to run BEFORE `world_pos` is taken, or the grain and the banded fog
## would be sampled at the position the vertex would have had in still air -
## so a swaying crown would shimmer through the grain field as it moved. The
## anchor is that assignment, and the splice puts the displacement immediately
## above it.
##
## Both anchors are checked before the replace, the same discipline
## `far_field_code()` uses: a shader that silently failed to splice would draw
## a forest that simply never moves, which nobody would file a bug about.
const TREE_DECL_ANCHOR := "void vertex() {"
const TREE_SWAY_ANCHOR := "\tworld_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;"

const TREE_DECL := """uniform float tree_sway = 0.0;

"""

const TREE_SWAY := """	// THE SWAY. COLOR.a is the vertex's height as a fraction of its own
	// model's, baked by TreeModels - 0 at the roots, 1 at the top - and it is
	// SQUARED here so the bottom third of a trunk is effectively still. A
	// linear weight shears a spruce's lowest branches sideways, which reads as
	// the tree sliding rather than bending.
	//
	// Driven by the INSTANCE's world position rather than by the vertex's, so
	// every vertex of one tree shares a phase and the tree bends as ONE THING.
	// FloraModels drives its grass the same way for the neighbouring reason: a
	// meadow moving in waves rather than each blade shivering on its own.
	//
	// ABOVE world_pos DELIBERATELY - see the anchor's note. The grain and the
	// fog must be sampled where the vertex ACTUALLY IS, or a moving crown
	// shimmers through a grain field that thinks it is standing still.
	float tree_w = COLOR.a * COLOR.a * tree_sway;
	if (tree_w > 0.0) {
		vec3 tree_at = MODEL_MATRIX[3].xyz;
		// About half the frequency of grass and a third of its amplitude
		// relative to height. A 25 m tree that moves like a tuft is a tree
		// made of rubber.
		float tree_phase = TIME * 0.6 + tree_at.x * 0.11 + tree_at.z * 0.07;
		VERTEX.x += sin(tree_phase) * tree_w * 0.55;
		VERTEX.z += cos(tree_phase * 0.77) * tree_w * 0.38;
	}
"""
