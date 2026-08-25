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


# --- The ramp ----------------------------------------------------------------

## Uniform declarations, shared by every shader below.
const HEADER := """
global uniform vec4 kubik_shade;
global uniform vec4 kubik_fog_color;
global uniform float kubik_fog_start;
global uniform float kubik_fog_end;
global uniform float kubik_fog_bands;
global uniform float kubik_night;
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
const float BAND_HALF = 0.12;
const float BAND_HALF_LEVEL = 0.55;
const float BAND_EDGE = 0.03;

float poster_band(float ndl) {
	float lit = smoothstep(BAND_LIT - BAND_EDGE, BAND_LIT + BAND_EDGE, ndl);
	float half_lit = smoothstep(BAND_HALF - BAND_EDGE, BAND_HALF + BAND_EDGE, ndl);
	return max(lit, half_lit * BAND_HALF_LEVEL);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = poster_band(ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += ALBEDO * mix(kubik_shade.rgb, LIGHT_COLOR, band);
	} else {
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band;
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
	ALBEDO = COLOR.rgb;
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
	ALBEDO = COLOR.rgb;
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
	vec3 cell = floor(dir * 220.0);
	float star = step(0.996, hash2(cell.xy + cell.z * 17.0)) * night * smoothstep(0.05, 0.2, dir.y);
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


# --- Publishing ---------------------------------------------------------------

## Write the time-of-day globals. Called by SkyCycle.apply() every frame with
## colours that are ALREADY LINEAR - see the note at the top.
static func publish(shade_linear: Color, fog_linear: Color,
		fog_start_m: float, fog_end_m: float, fog_bands: int) -> void:
	RenderingServer.global_shader_parameter_set(&"kubik_shade",
		Vector4(shade_linear.r, shade_linear.g, shade_linear.b, 1.0))
	RenderingServer.global_shader_parameter_set(&"kubik_fog_color",
		Vector4(fog_linear.r, fog_linear.g, fog_linear.b, 1.0))
	RenderingServer.global_shader_parameter_set(&"kubik_fog_start", fog_start_m)
	RenderingServer.global_shader_parameter_set(&"kubik_fog_end", fog_end_m)
	RenderingServer.global_shader_parameter_set(&"kubik_fog_bands", float(maxi(fog_bands, 1)))
