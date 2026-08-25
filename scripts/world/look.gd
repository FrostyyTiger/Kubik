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

vec4 poster_fog(vec3 view_vertex, vec3 albedo) {
	float depth = length(view_vertex);
	float f = smoothstep(kubik_fog_start, kubik_fog_end, depth);
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

	ALBEDO = vec3(1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = poster_fog(VERTEX, v_albedo);
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
	FOG = poster_fog(VERTEX, v_albedo);
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
