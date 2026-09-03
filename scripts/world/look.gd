class_name Look

## Materials over the engine's light. One shader string for every opaque
## vertex-coloured mesh, the engine's own `light()`, sRGB on the wire.
##
## LIGHT V1 STAGE 0 REPLACED THE POSTER. What stood here until 2026-09-03 was a
## toon ramp: three hard bands of n.l, ambient disabled, depth fog quantised
## into four steps and written per material, a hand-drawn sky with Deco wedges,
## flat water, a Bayer dissolve on the far field, and a linear tonemapper.
## Pillar 2 of the bible (`../Kubik-bible/style-bible/00-pillars.md`) asks for
## the opposite of every one of those: "lit like a photoreal shader: a real
## sun, soft shadows tinted by the sky, volumetric fog, a real sky, clear water
## that reflects", on surfaces that stay flat-coloured cubes. D5 is Marcel's
## own wording and D8 names hard outdoor shadows as the thing not to do.
##
## So there is no `light()` here any more. The engine lights the world, and
## this file is only what a surface IS: its albedo, its roughness, its one
## material-noise step. Everything that used to be painted on a vertex -
## the shade ink, the fog band, the contact line, the AO multiply, the aspect
## tint - is either the renderer's job now or is gone.
##
## THE MATERIAL RULE (`10-color-and-light.md`, "Materials: body plus trim,
## three shades"). Every material is one body colour in three shades - base,
## shade, light - "plus a little per-cube noise (one step up or down on random
## cubes) so big walls do not look flat". Read literally, and that is the
## reading grill Q5 bound: the block carries the BASE hex, the noise is a
## SPARSE STEP toward the shade or the light value on about a third of cubes,
## and the THIRD SHADE COMES FROM LIGHT. That is why `grain_sparse` and
## `grain_step` are the only two knobs left in the fragment: they are the
## bible's sentence, not an effect.
##
## THE GLOBALS. Two now, down from nine. Everything else the shaders used to
## read per frame was the poster's.
##
##   kubik_night  float  0 by day, 1 at night - the flora's glow and the
##                       fireflies' existence still key off it
##   kubik_warm   float  1 where warm light lives, 0 under eerie weather
##                       (D7: "eerie is night or day with the life taken out
##                       ... every warm light off"). Published by SkyCycle.
##
## LINEAR, NOT source_color. Every palette in the game - Block, FloraModels,
## Races, TreePalette - is stored linear and converted once at load. The
## globals follow the same rule, so there is one convention and no hint for a
## renderer to ignore.
##
## ... AND sRGB ON THE WIRE. The one exception, and it survives the rewrite
## unchanged: a vertex colour is converted back to sRGB by `to_wire()` at the
## moment it is pushed into a mesh, because the renderer decodes an 8-bit
## vertex colour on the way to ALBEDO. Everything upstream of that push is
## linear. The transfer sheet proves it every stage, to within 6 units per
## channel, and that gate was not widened for this rewrite.


# --- The environment ----------------------------------------------------------

## ONE DECISION LIGHTS THE GAME AND THE SHEETS.
##
## Called by `SkyCycle.setup()` and by the gallery's own setup, so a colour
## judged on a swatch sheet means what it means in the world. Before this the
## gallery built its own environment and the two drifted; a sheet lit
## differently from the game is a sheet that measures nothing.
##
## `scenes/game.tscn`'s Environment sub-resource keeps only `background_mode`
## and `sky`, so this function is the truth about every other field.
##
## WHAT STAGE 0 SETS AND WHAT LATER STAGES SET. Stage 0 is the real light: the
## sky, the ambient, the tonemap, SSAO, the far fog term and the sun's shadow.
## The hours grade the sky (Stage 1), fog gets its volumes (Stage 2), the lens
## turns on glow and the adjustments (Stage 4) and water gets SSR (Stage 5).
## Each of those is switched off here rather than left at an engine default, so
## the frame Stage 0 is judged on is exactly the frame this function describes.
static func configure_environment(env: Environment, sun: DirectionalLight3D) -> void:
	if env != null:
		# THE SKY IS THE ENGINE'S OWN RADIANCE, not a painted gradient. This is
		# what makes the sky ambient, the sky-tinted shadow and (Stage 5) the
		# water's reflection agree by construction rather than by three tables
		# being tuned to match: they are all the same radiance cubemap.
		if env.sky == null:
			env.sky = Sky.new()
		if not (env.sky.sky_material is PhysicalSkyMaterial):
			env.sky.sky_material = PhysicalSkyMaterial.new()
		env.background_mode = Environment.BG_SKY

		# AMBIENT FROM THE SKY, AT FULL CONTRIBUTION. The poster disabled
		# ambient entirely and ruled it "exactly the grey everywhere the poster
		# is not". Under real light it is the opposite: the sky's light in the
		# shadow is what makes a shadow navy by day and magenta in the evening
		# instead of black, which is the whole of D8.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 1.0
		env.ambient_light_energy = 1.0
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

		# AgX, NOT LINEAR. D40 asks for "soft highlight roll-off; no clipped
		# whites except the sun's disc", and a linear tonemapper at exposure 1
		# is the one choice that makes that impossible. The old ruling against
		# a tonemapper ("a tonemapper that reshapes it is reshaping the art",
		# measured: Filmic turned #86B04A into #68D62F) was right for a flat
		# poster and is backwards for a lit world: AgX reshapes the HIGHLIGHT,
		# and the transfer sheet still forces LINEAR for its own measurement so
		# the authored-equals-screen claim is still proved on a raw path.
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.tonemap_exposure = TONEMAP_EXPOSURE
		env.tonemap_white = 1.0

		# SSAO, AND THE BAKED AO GOES (Q9). Corner AO is what made a greedy
		# hillside read as cubes, and it fought the merge: a run only joined
		# while the four corner codes repeated. Screen-space AO does the same
		# job downstream of the mesh, so `ao_strength` can go to 0 and the
		# mesher stops sampling corners entirely - bigger quads, cheaper
		# columns. That saving is measured in Stage 3.
		env.ssao_enabled = true
		env.ssao_radius = 1.0
		env.ssao_intensity = 2.0
		env.ssao_power = 1.5
		# On the tunable table, off by default: it is the expensive one and
		# SSAO already carries the contact darkening the cubes need.
		env.ssil_enabled = false

		# LATER STAGES. Named and switched off rather than left to the engine,
		# so Stage 0's frame is this function and nothing else.
		env.glow_enabled = false          # Stage 4, the lens
		env.adjustment_enabled = false    # Stage 4, the grade
		env.volumetric_fog_enabled = false  # Stage 2, fog's three jobs
		env.ssr_enabled = false           # Stage 5, water

		# THE FAR TERM. Exponential rather than the poster's depth fog, with
		# aerial perspective on so distance fades toward the SKY in that
		# direction - the bible's "fog always fades to the current sky colour".
		# The per-material FOG write and its band quantiser are gone; there is
		# one fog in the world now and the environment owns it.
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = FOG_DENSITY_DAY
		env.fog_aerial_perspective = FOG_AERIAL_PERSPECTIVE
		env.fog_sky_affect = FOG_SKY_AFFECT
		# Height fog is Stage 2's valley-bottom term; inert until it has a
		# floor to sit on.
		env.fog_height_density = 0.0

	if sun != null:
		# SOFT, AND TINTED BY THE SKY (D8). `light_angular_distance` is the
		# sun's angular size in degrees - the real sun is about half of one -
		# and it is what makes a penumbra widen with distance from the caster
		# instead of every shadow having one blur radius. The poster set
		# `shadow_blur` to 0.25 and said blur "would only soften the one line
		# the look is built on"; that line is what this stage deletes.
		sun.light_angular_distance = SUN_ANGULAR_DISTANCE
		sun.shadow_blur = 1.0
		sun.shadow_enabled = true
		# Four splits, because a voxel world's shadow detail is wanted close
		# and the far field only needs the mountain's own shape.
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = SHADOW_MAX_DISTANCE
		sun.directional_shadow_fade_start = 0.8
		# A VOXEL WORLD ACNES ON FLAT FACES FIRST: every surface is exactly
		# perpendicular to a shadow-map texel's gradient somewhere. Normal bias
		# is the one that fixes it and peter-panning is the cost; the two are
		# tuned together on `8-meadow-closeup`.
		sun.shadow_normal_bias = SHADOW_NORMAL_BIAS
		sun.shadow_bias = SHADOW_BIAS
		# The poster disabled the specular contribution because nothing in it
		# had a highlight. Water does (Stage 5), and so does anything wet.
		sun.light_specular = 1.0


# --- The numbers the environment is built from --------------------------------
#
# TUNABLE, in the sense of the plan's section 4: the agent may move these on
# its own judgement inside the stated range and must record the shot that
# decided it. Everything else in this file is fixed.

## Exposure. Range 0.7-1.4, judged on the transfer and light sheets and on
## shots 1 and 6.
const TONEMAP_EXPOSURE := 1.0

## The sun's angular size in degrees, which is the width of every penumbra.
## Range 0.5-2.5, judged on shots 3 and 8.
const SUN_ANGULAR_DISTANCE := 1.0

## Metres the shadow map covers. Range 150-400, judged on shots 1 and 9 and on
## the stream probe - it is the single biggest cost knob in this stage.
const SHADOW_MAX_DISTANCE := 250.0

const SHADOW_NORMAL_BIAS := 2.0
const SHADOW_BIAS := 0.05

## The far fog term at the day hour. Stage 1 puts a density on every hour and
## `SkyCycle` writes it per frame; this is what Stage 0 draws with.
const FOG_DENSITY_DAY := 0.0006
const FOG_AERIAL_PERSPECTIVE := 0.6
const FOG_SKY_AFFECT := 0.3


# --- The shaders --------------------------------------------------------------

## Uniform declarations and the two helpers, shared by every shader below and
## by FloraModels, which builds its own vertex program on this base.
##
## WHY ONE STRING AND NOT `#include`. The plant shader is built from code at
## runtime and so are these. A shader include file is one more resource to
## import and buys nothing over concatenating a constant.
const HEADER := """
global uniform float kubik_night;
global uniform float kubik_warm;

// The inverse of the push conversion (see Look.to_wire). Vertex colours travel
// sRGB on the wire and the engine decodes ALBEDO for us; anything that is NOT
// ALBEDO - EMISSION, most of all - has to decode for itself or it glows at its
// sRGB value, which is far too bright.
vec3 kubik_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash3(vec3 c) {
	return fract(sin(dot(c, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
"""


## EVERYTHING OPAQUE THAT IS ITS OWN COLOUR: terrain, far field, far trees,
## characters. No texture, no custom light(), no fog write.
##
## `diffuse_lambert` rather than Burley: a flat-coloured cube has no
## microsurface story to tell and Lambert is what the bible's "flat cubes"
## means in a BRDF. `specular_schlick_ggx` is left on because Stage 5's water
## and anything wet needs a highlight, and at SPECULAR 0.1 on a rough surface
## it is a whisper.
##
## THE STEP GRAIN IS THE BIBLE'S SENTENCE, NOT AN EFFECT. See the material rule
## in this file's header. `grain_sparse` is the share of half-metre cells that
## take a step at all (about a third); `grain_step` is how far the step goes,
## up or down by a second hash. The old grain was a continuous +-6.5% wobble in
## value and hue on EVERY cell, faded out by 45 m; this is a step on SOME
## cells, at every distance, because a material fact does not fade with range.
const OPAQUE_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
""" + HEADER + """
uniform float grain_sparse = 0.33;
uniform float grain_step = 0.12;

// EMISSIVE, FOR FIGURES ONLY, and it is off by default for a reason. Terrain,
// the far field and the impostor ring share this shader's SOURCE and write
// alpha 1, so an unconditional EMISSION line would set the entire world
// glowing. The uniform is per material and only figure_material() sets it.
uniform float figure_emissive = 0.0;

// THE FAR COUNTRY'S OWN GRAIN, distance v3 Stage 2, kept as a knob at 0.
//
// A half-metre cell at 3 km is sub-pixel, so the far field grows its lattice
// with view distance instead of fading the noise out - DH's dropoff turned
// inside out, keeping the fleck at a constant angular size. Inert at 0, which
// is the default and what the game ships; `far_field_material()` is the copy
// of this material that may carry it.
uniform float far_grain = 0.0;

// The lattice at the seam, in metres: one block, which is the near field's own
// grain cell, so the two grains are the same grain.
const float FAR_GRAIN_NEAR_M = 0.5;
// Metres of lattice per metre of view distance - about two screen pixels at
// 1280x720. DH's noise dropoff turned inside out.
const float FAR_GRAIN_PX = 0.003;
// 0.5 m * 2^7 = 64 m, which is the outermost ring's own cell.
const float FAR_GRAIN_MAX_LEVEL = 7.0;
// The rune band's energy. Stage 4 judges it against the glow threshold.
const float FIGURE_EMISSIVE_ENERGY = 3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The vertex colour IS the albedo. There are no textures in this world.
	// It arrives sRGB on the wire (Look.to_wire) and is decoded here, once.
	vec3 albedo = kubik_to_linear(COLOR.rgb);

	// The bible's material noise: one step up or down on random cubes.
	// mod() before the hash keeps the argument small - at +-1500 blocks a raw
	// world coordinate loses enough mantissa that the hash bands into stripes.
	vec3 cell = mod(floor(world_pos / 0.5), 1024.0);
	float h = hash3(cell);
	float stepped = step(1.0 - grain_sparse, h);
	float sign_ = step(0.5, hash3(cell + vec3(17.0))) * 2.0 - 1.0;
	albedo *= 1.0 + stepped * sign_ * grain_step;

	// THE FAR GRAIN, at a lattice that grows with distance. Skipped entirely
	// at 0, which is every material but the far field's and the far field's
	// own default.
	if (far_grain > 0.0) {
		float fg_d = length(VERTEX);
		float fg_lvl = clamp(log2(max(fg_d * FAR_GRAIN_PX, FAR_GRAIN_NEAR_M)
			/ FAR_GRAIN_NEAR_M), 0.0, FAR_GRAIN_MAX_LEVEL);
		float fg_lo = floor(fg_lvl);
		float fg_cell = FAR_GRAIN_NEAR_M * exp2(fg_lo);
		float fg_h = mix(
			hash3(mod(floor(world_pos / fg_cell), 1024.0)),
			hash3(mod(floor(world_pos / (fg_cell * 2.0)), 1024.0)),
			fg_lvl - fg_lo);
		// A parabola in luminance, so nothing happens on blacks or whites,
		// and a brighten-toward-white form so it never muddies a hue. Written
		// as x*x rather than pow(x, 2.0): pow() with a negative base is
		// undefined in GLSL and this base is negative for most of this world.
		float fg_lum = (albedo.r + albedo.g + albedo.b) / 3.0;
		float fg_x = fg_lum * 2.0 - 1.0;
		float fg_amp = (1.0 - fg_x * fg_x) * far_grain;
		float fg_r = fg_h * 2.0 * fg_amp - fg_amp;
		albedo = albedo + (1.0 - albedo) * fg_r;
	}

	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	METALLIC = 0.0;
	// The rune band on a named piece, and nothing else in the world. Off
	// entirely under eerie weather, with every other warm light (D7).
	EMISSION = kubik_to_linear(COLOR.rgb) * COLOR.a * figure_emissive
		* FIGURE_EMISSIVE_ENERGY * kubik_warm;
}
"""

## WATER, UNTIL STAGE 5. The opaque shader drawn from both sides and through,
## so a lake is flat and matte and nothing is magenta while the real water
## material is still three stages away. Stage 5 replaces this whole constant
## with the depth tint, the Fresnel term and SSR.
##
## Double-sided because the surface is a single plane with nothing underneath
## it: standing in a lake and looking up at a one-sided surface shows you
## nothing at all, which reads as a bug rather than as water.
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;
""" + HEADER + """
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = kubik_to_linear(COLOR.rgb);
	ALPHA = COLOR.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	METALLIC = 0.0;
}
"""


# --- The materials ------------------------------------------------------------

static var _opaque: ShaderMaterial = null
static var _water: ShaderMaterial = null
static var _figure: ShaderMaterial = null
static var _far_field: ShaderMaterial = null
static var _far_tree: ShaderMaterial = null
static var _tree: ShaderMaterial = null
static var _mutex := Mutex.new()


## One material for every opaque vertex-coloured mesh in the game.
##
## Shared on purpose: the renderer batches meshes that share a material, and a
## character made of the same stuff as the ground it stands on is the whole
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


## THE SAME SHADER, FOR A PERSON.
##
## Q14 took the difference out. Until light v1 a figure fogged toward a darker
## colour than the ground so a character would not dissolve into the hillside
## behind it; the bible wants ONE SURFACE LANGUAGE, and a character fogs like
## the hill it stands on. What is left is the emissive uniform, which is the
## one thing a person has that a hillside does not.
static func figure_material() -> ShaderMaterial:
	if _figure != null:
		return _figure
	_mutex.lock()
	if _figure == null:
		_figure = _make(OPAQUE_SHADER)
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


## THE FAR FIELD'S OWN MATERIAL - the opaque material's twin.
##
## Distance v3 built this by splicing two blocks into the opaque shader at
## asserted anchors, because the compensating rule for opening look.gd was that
## the near field stay byte-identical and a shared string with an untaken
## branch left that resting on a compiler being indifferent. Light v1 rewrites
## the whole file, so the rule is gone with the poster it protected, and the
## far field is simply a second material on the same source: it still stops
## batching with the chunks, which is the seam it needs, and `far_grain` is a
## uniform it may carry and the chunks may not.
static func far_field_material() -> ShaderMaterial:
	if _far_field != null:
		return _far_field
	_mutex.lock()
	if _far_field == null:
		_far_field = _make(OPAQUE_SHADER)
	_mutex.unlock()
	return _far_field


## A TREE IS SCENERY. A PERSON IS NOT. The impostor ring was drawn with
## `figure_material()` until distance v1 Stage 6, which forbade a wooded ridge
## from receding into the mountain it stands on. It keeps its own material now
## for the draw-group seam and for nothing else - the treatment is the
## terrain's, because under one surface language there is only one treatment.
static func far_tree_material() -> ShaderMaterial:
	if _far_tree != null:
		return _far_tree
	_mutex.lock()
	if _far_tree == null:
		_far_tree = _make(OPAQUE_SHADER)
	_mutex.unlock()
	return _far_tree


## A TREE IS SCENERY WITH SWAY. The same source with a `vertex()` splice, which
## is the one thing the shared material cannot do.
static func tree_material() -> ShaderMaterial:
	if _tree != null:
		return _tree
	_mutex.lock()
	if _tree == null:
		_tree = _make(tree_shader_code())
		_tree.set_shader_parameter("tree_sway", 0.0)
	_mutex.unlock()
	return _tree


static func _make(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


# --- The tree's vertex splice -------------------------------------------------

## THE SWAY GOES INSIDE THE OPAQUE SHADER'S OWN `vertex()`, NOT BESIDE IT.
##
## Two `vertex()` functions is `Redefinition of 'vertex'`, and the anchor is
## the right place anyway: the sway has to run BEFORE `world_pos` is taken, or
## the grain would be sampled at the position the vertex would have had in
## still air and a swaying crown would shimmer through the grain field as it
## moved.
##
## Both anchors are asserted before the replace: a shader that silently failed
## to splice would draw a forest that simply never moves, which nobody would
## file a bug about.
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


## The opaque shader with the tree's vertex splice. The fragment half, the
## grain and the emissive line are the shared source, character for character,
## so a tree and the ground it stands on can never disagree about what a
## surface is.
static func tree_shader_code() -> String:
	var code := OPAQUE_SHADER
	if not code.contains(TREE_DECL_ANCHOR) or not code.contains(TREE_SWAY_ANCHOR):
		push_error("[Look] the tree shader's anchors are gone from OPAQUE_SHADER")
		return code
	code = code.replace(TREE_DECL_ANCHOR, TREE_DECL + TREE_DECL_ANCHOR)
	return code.replace(TREE_SWAY_ANCHOR, TREE_SWAY + TREE_SWAY_ANCHOR)


# --- The wire ------------------------------------------------------------------

## THE ONE CONVERSION, and the only one in the whole colour path.
##
## Every palette in the game is stored LINEAR. This is the last thing that
## happens to a vertex colour before push_back, and it exists because the
## renderer treats an 8-bit vertex colour as sRGB and decodes it on the way to
## ALBEDO. Push linear and it is decoded a second time; push sRGB and what
## arrives at ALBEDO is what was authored.
##
## LINEAR MATHS, sRGB ON THE WIRE. If you find yourself converting anywhere
## else, something is wrong: there is one conversion and this is it.
static func to_wire(c: Color) -> Color:
	return c.linear_to_srgb()


## Luminance, Rec. 709, on a LINEAR colour.
static func luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


# --- Publishing ---------------------------------------------------------------

## Write the time-of-day globals. Called by `SkyCycle.apply()` every frame.
##
## ONE LINE, DOWN FROM EIGHT. The poster published a shade colour, a fog
## colour, a fog start, a fog end, a band count, a desaturation, a dark fog and
## a water colour, because the shaders did the lighting and the fog themselves.
## The engine does both now, and `SkyCycle` writes to the Environment and the
## Sun directly. What is left is the one fact a shader still needs and cannot
## derive: whether warm light exists at this hour and in this weather.
static func publish(kf: Dictionary) -> void:
	RenderingServer.global_shader_parameter_set(
		&"kubik_warm", float(kf.get("warm", 1.0)))


## Push the local knobs into every material that carries them. Called from the
## main thread at startup and whenever the F4 panel moves.
##
## THE FIGURE MATERIAL TAKES THEM TOO, and that is the change Q14 made: one
## surface language means a character's cubes step like a hillside's. Only the
## far field's `far_grain` is its own.
static func apply_local_knobs(config: WorldgenConfig) -> void:
	var far := far_field_material()
	for m in [opaque_material(), far, figure_material(), far_tree_material(),
			tree_material()]:
		m.set_shader_parameter("grain_sparse", config.grain_sparse)
		m.set_shader_parameter("grain_step", config.grain_step)
	far.set_shader_parameter("far_grain", config.far_grain)


## Push the tree knobs. Called beside `apply_local_knobs`, from the main thread.
static func apply_tree_knobs(config: WorldgenConfig) -> void:
	tree_material().set_shader_parameter("tree_sway", config.tree_sway)
