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
const float LIT_BLEACH = 0.10;

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
vec4 poster_fog(vec3 view_vertex) {
	float depth = length(view_vertex);
	float f = smoothstep(kubik_fog_start, kubik_fog_end, depth);
	f = floor(f * kubik_fog_bands + 0.5) / kubik_fog_bands;
	return vec4(kubik_fog_color.rgb, f);
}
"""


# --- The shaders --------------------------------------------------------------

## Everything opaque that is its own colour: terrain, far field, far trees,
## characters. No texture, no specular, no ambient - the ramp owns the shade.
const OPAQUE_SHADER := """
shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;
""" + HEADER + FOG_FN + """
void fragment() {
	// The vertex colour IS the albedo. There are no textures in this world.
	// It arrives sRGB on the wire (Look.to_wire) and is decoded here, once.
	v_albedo = kubik_to_linear(COLOR.rgb);
	ALBEDO = vec3(1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = poster_fog(VERTEX);
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
	v_albedo = kubik_to_linear(COLOR.rgb);
	ALBEDO = vec3(1.0);
	ALPHA = COLOR.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = poster_fog(VERTEX);
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

uniform vec4 sky_top = vec4(0.07, 0.21, 0.66, 1.0);
uniform vec4 sky_horizon = vec4(0.46, 0.60, 0.77, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec4 sun_color = vec4(1.0, 0.89, 0.64, 1.0);
uniform float day = 1.0;
uniform float dusk = 0.0;
uniform float night = 0.0;
uniform float sky_bands = 5.0;
uniform float ray_count = 16.0;
uniform float ray_strength = 0.4;
uniform float ray_extent = 0.9;
uniform float sun_size = 0.035;
uniform float cloud_cover = 0.35;

const float TAU_ = 6.28318530718;

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

void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, 0.0, 1.0);

	// THE BANDS. Denser near the horizon, where a poster stacks them.
	float band = floor(pow(up, 0.6) * sky_bands) / sky_bands;
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, band);
	// Below the horizon is the fog colour, which is what the far field fades
	// to - so the sky's ground and the world's edge are the same colour.
	if (dir.y < 0.0) {
		col = sky_horizon.rgb;
	}

	// THE SUN AND ITS RAYS.
	float cs = dot(dir, sun_dir);
	float ang = acos(clamp(cs, -1.0, 1.0));
	vec3 t1 = normalize(cross(sun_dir, vec3(0.0, 1.0, 0.0)));
	vec3 t2 = cross(sun_dir, t1);
	vec3 perp = dir - sun_dir * cs;
	float phi = atan(dot(perp, t2), dot(perp, t1));
	float wedge = step(0.5, fract(phi * ray_count / TAU_));
	float fade = 1.0 - smoothstep(0.0, ray_extent, ang);
	float sun_up = smoothstep(-0.05, 0.05, sun_dir.y);
	float rays = wedge * fade * ray_strength * sun_up * step(0.0, dir.y);
	vec3 ray_col = mix(col, sun_color.rgb, 0.45);
	col = mix(col, ray_col, rays);
	float disc = step(cos(sun_size), cs) * sun_up;
	col = mix(col, sun_color.rgb, disc);

	// THE CLOUDS. Projected onto a plane above the viewer so they foreshorten
	// toward the horizon the way real ones do, then cut hard.
	if (dir.y > 0.02) {
		vec2 uv = dir.xz / (dir.y + 0.35) * 1.6;
		float thr = 1.0 - cloud_cover * 0.75;
		float n = clouds(uv);
		float here = step(thr, n);
		float below = step(thr, clouds(uv + vec2(0.0, 0.05)));
		float underside = here * (1.0 - below);
		float near_horizon = smoothstep(0.02, 0.12, dir.y);
		float cloud = here * near_horizon;
		vec3 lit = mix(col, vec3(1.0), 0.55 * max(day, 0.25)) * mix(vec3(1.0), sun_color.rgb, dusk * 0.6);
		vec3 shade = mix(col, sky_horizon.rgb, 0.5) * mix(1.0, 0.75, day);
		vec3 cloud_col = mix(lit, shade, underside);
		col = mix(col, cloud_col * mix(1.0, 0.35, night), cloud);
	}

	// THE MOON AND THE STARS, after dark.
	float cm = dot(dir, moon_dir);
	float moon = step(cos(0.018), cm) * night;
	col = mix(col, vec3(0.85, 0.88, 1.0), moon);
	// A 3D cell hashed in two stages: hashing x + 17 z directly collapses
	// whole rows of cells onto one value and the first night tour had every
	// star in one patch of sky.
	vec3 cell = floor(dir * 220.0);
	float star_seed = hash2(cell.xz + vec2(hash2(cell.xy) * 61.0, cell.y * 3.7));
	float star = step(0.994, star_seed) * night * smoothstep(0.05, 0.2, dir.y);
	col += vec3(0.7, 0.75, 0.9) * star;

	COLOR = col;
}
"""


# --- The materials ------------------------------------------------------------

static var _opaque: ShaderMaterial = null
static var _water: ShaderMaterial = null
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
	_set_color(&"kubik_water", kf["water"])
	RenderingServer.global_shader_parameter_set(&"kubik_shade_desat", kf["shade_desat"])
	RenderingServer.global_shader_parameter_set(&"kubik_fog_start", fog_start_m)
	RenderingServer.global_shader_parameter_set(&"kubik_fog_end", fog_end_m)
	RenderingServer.global_shader_parameter_set(&"kubik_fog_bands", float(maxi(fog_bands, 1)))


static func _set_color(name: StringName, c: Color) -> void:
	RenderingServer.global_shader_parameter_set(name, Vector4(c.r, c.g, c.b, 1.0))


## Mirrors RAMP's LIT_BLEACH. Change one, change both - Look.predict() reads
## this and the shader reads the constant in RAMP, and the swatch sheet is what
## catches them drifting apart.
const LIT_BLEACH := 0.10


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
