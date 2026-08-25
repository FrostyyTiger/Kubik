class_name SkyCycle
extends Node

## Moves the sun, tints the sky, and sets the fog.
##
## Visual only. Pillar 2 wants darkness to MEAN something - danger scaling with
## the dark - but that needs an enemy to be dangerous first, so this deliberately
## has no gameplay effect yet. See docs/IDEAS.md.
##
## Fog is not decoration either. It is what makes a 200 m view distance
## possible: past fog_end nothing is visible at all, so the far-field mesh only
## has to exist out to there, and its outer edge is never something you can see.
## Turn the fog off and you see the world end.
##
## The colour work is in pure functions of the sun's elevation, so it can be
## tested without a window - which matters here, because a full day is eight
## minutes of real time and nobody is watching a headless run for eight minutes.

## THE TIME-OF-DAY SETS, AS DATA.
##
## Habit 1 (CLAUDE.md): facts as a table, not as twelve constants scattered
## down a file. Four keyframes - dawn, noon, dusk, night - each a full set of
## every colour the hour decides, and one function blends between them. A
## director, a debug panel or a later biome can read this; twelve constants
## could only be read by the code that named them.
##
## sRGB IN THE FILE, LINEAR OUT OF keyframe_at(). The hex is what was authored
## and what `docs/research/art-direction.md` section 2.11 records; the
## conversion happens once, on first use, and everything downstream is linear.
##
## `fog_dark` is not authored - it is derived, the fog colour one band darker,
## because rule 2 says a far range is a cut-out against the sky and never glass
## over it.
const KEYFRAMES := {
	"dawn": {
		"sun": "#FFC7A0", "energy": 0.85, "shade": "#9A97BE", "shade_desat": 0.55,
		"fog": "#E4CDB8", "horizon": "#F3C79E", "sky_mid": "#E4C9C2",
		"sky_top": "#BBD5DC", "water": "#B6BCCE", "cloud_lit": "#FFE2C8",
		"accent": "#F2A80D",
	},
	"noon": {
		"sun": "#FFF2D1", "energy": 1.00, "shade": "#7A7396", "shade_desat": 0.55,
		"fog": "#C9C3C4", "horizon": "#EBDFC8", "sky_mid": "#B4C1D6",
		"sky_top": "#89A1CB", "water": "#4A6A8A", "cloud_lit": "#F2E8D0",
		"accent": "#C9A24A",
	},
	"dusk": {
		"sun": "#FCA55A", "energy": 0.90, "shade": "#4A6FB4", "shade_desat": 0.65,
		"fog": "#D9C4B0", "horizon": "#F4CBA0", "sky_mid": "#9A8CC0",
		"sky_top": "#6C68A4", "water": "#6E7396", "cloud_lit": "#F2C489",
		"accent": "#E8A02E",
	},
	"night": {
		"sun": "#9AAAD0", "energy": 0.75, "shade": "#39456E", "shade_desat": 0.75,
		"fog": "#223A5E", "horizon": "#25406E", "sky_mid": "#1D3764",
		"sky_top": "#152A55", "water": "#2C3E63", "cloud_lit": "#6F7C9E",
		"accent": "#E8892E",
	},
}

## How much darker `fog_dark` is than the fog. One band, in linear.
const FOG_DARK_MIX := 0.18

static var _keyframes_linear := {}


## One keyframe, every colour linear, built once.
static func keyframe(name: String) -> Dictionary:
	if _keyframes_linear.is_empty():
		for key in KEYFRAMES:
			var row := {}
			for field in KEYFRAMES[key]:
				var v = KEYFRAMES[key][field]
				if typeof(v) == TYPE_STRING:
					row[field] = Color.html(v).srgb_to_linear()
				else:
					row[field] = float(v)
			row["fog_dark"] = (row["fog"] as Color).lerp(Color(0.0, 0.0, 0.0), FOG_DARK_MIX)
			_keyframes_linear[key] = row
	return _keyframes_linear[name]


## The set for this sun elevation, every colour LINEAR, ready to publish.
##
## Night to noon by how light it is, then pulled toward the horizon keyframe -
## dusk in the afternoon, dawn in the morning - by how near the sun is to the
## horizon. AT WEIGHT 1.0, which is the whole of look v2's "dusk exists": look
## v1 blended at 0.85 and 0.75, so the dusk set was never actually reached and
## the sky at sunset was a washed-out noon rather than the poster's orange.
##
## Pure, like everything in this section, so the day-cycle self-test can walk a
## whole day through it without a window.
static func keyframe_at(elevation: float, morning := false) -> Dictionary:
	var night := keyframe("night")
	var noon := keyframe("noon")
	var edge := keyframe("dawn") if morning else keyframe("dusk")
	var d := day_amount(elevation)
	var k := dusk_amount(elevation)
	var out := {}
	for field in noon:
		if typeof(noon[field]) == TYPE_COLOR:
			out[field] = (night[field] as Color).lerp(noon[field], d).lerp(edge[field], k)
		else:
			out[field] = lerpf(lerpf(night[field], noon[field], d), edge[field], k)
	return out


## Where the light comes from during twilight, while it is neither the sun's
## nor the moon's: low in the south. The sun and the moon are antipodes, so a
## straight lerp between them passes through zero; going via this direction
## does not, and it is where dusk light actually comes from.
const TWILIGHT_DIR := Vector3(0.0, 0.35, -1.0)

## Elevation, either side of the horizon, over which the light hands over from
## the sun to the moon.
const HANDOVER := 0.08

## How far south the sun's arc is tilted. Exactly overhead at noon gives flat,
## shadowless terrain for the part of the day you spend most of; a tilt keeps
## some relief in the hillsides all day. It also keeps the light direction from
## ever being parallel to world up, which would make the camera basis
## degenerate.
const ARC_TILT := 0.35

var config: WorldgenConfig = null

## 0 is midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset.
var time_of_day := 0.3

## Stop the clock. Set by the screenshot tour and by nothing else.
##
## A full day is eight minutes and the tour takes about five on a software
## renderer, so without this the sun sets somewhere around the fourth
## photograph - which is how the v1 tour came to have three usable shots and
## three black rectangles. Nobody noticed, because on a real GPU the tour
## finishes before the light has moved.
##
## It matters beyond the black frames: two tours of the same seed have to
## differ ONLY where the terrain differs, and a comparison harness whose
## lighting depends on how long rendering took compares the wrong thing.
var frozen := false

var _sun: DirectionalLight3D = null
var _env: Environment = null
var _sky: ShaderMaterial = null


func setup(p_config: WorldgenConfig, sun: DirectionalLight3D,
		world_environment: WorldEnvironment) -> void:
	config = p_config
	_sun = sun
	if _sun != null:
		# HARD SHADOWS, AND NO HIGHLIGHT. A poster's shadow is a shape with an
		# edge, and the ramp in Look turns the shadow map straight into the
		# shade band, so blur here would only soften the one line the look is
		# built on. Specular is disabled in every poster material already; this
		# is for anything that is not one.
		_sun.shadow_blur = 0.25
		_sun.light_specular = 0.0
	_env = world_environment.environment
	if _env != null and _env.sky != null:
		# THE POSTER SKY replaces whatever the scene had, which is a
		# ProceduralSkyMaterial in every scene that has a sky - kept in the
		# .tscn files as the thing to fall back to if Look is ever unwired.
		_sky = Look.sky_material()
		_env.sky.sky_material = _sky
	time_of_day = config.day_start
	_apply_fog_distances()
	apply()


func _process(delta: float) -> void:
	if config == null or frozen:
		return
	if config.day_seconds > 0.0:
		time_of_day = fposmod(time_of_day + delta / config.day_seconds, 1.0)
	apply()


# --- Pure functions of time, so they can be tested without a window ---------

## Unit vector pointing at the sun. y > 0 means daytime.
static func sun_position(t: float) -> Vector3:
	# t = 0.25 puts the sun on the eastern horizon, 0.5 overhead, 0.75 west.
	var angle := (t - 0.25) * TAU
	return Vector3(cos(angle), sin(angle), -ARC_TILT).normalized()


## How much of "full daylight" this elevation is. Reaches 1 while the sun is
## still low, so the world is properly lit for most of the day rather than only
## around noon.
static func day_amount(elevation: float) -> float:
	return clampf(elevation * 3.0, 0.0, 1.0)


## How much of "sunrise or sunset" this is - peaks with the sun on the horizon
## and falls away on both sides. Deliberately still non-zero just BELOW the
## horizon, which is where the warmest part of a real dusk happens.
static func dusk_amount(elevation: float) -> float:
	return clampf(1.0 - absf(elevation) * 4.5, 0.0, 1.0)


# THIN WRAPPERS OVER THE TABLE. They exist so the day-cycle self-test and the
# gallery keep the shape they had, and they hand back sRGB because that is what
# a Light3D's colour is and what a hex in a status doc is. Anything publishing
# to a shader wants keyframe_at() directly, which is already linear.

static func sun_color(elevation: float, morning := false) -> Color:
	return (keyframe_at(elevation, morning)["sun"] as Color).linear_to_srgb()


static func fog_color(elevation: float, morning := false) -> Color:
	return (keyframe_at(elevation, morning)["fog"] as Color).linear_to_srgb()


## The colour of shade at this elevation - rule 1's ink.
static func shade_color(elevation: float, morning := false) -> Color:
	return (keyframe_at(elevation, morning)["shade"] as Color).linear_to_srgb()


## Where the light comes FROM, as a unit vector: the sun by day, the moon by
## night, and a hand-over through the twilight direction between them.
##
## THE SUN NEVER GOES OUT. Look's ramp paints the shade colour from the
## directional light's own pass, so a night with no directional light would
## not be dark, it would be BLACK - no light() call, no shade. The moon is the
## same light on the far side of the sky: the sun's antipode, which is above
## the horizon exactly when the sun is below it.
static func light_direction(t: float) -> Vector3:
	var sun := sun_position(t)
	var e := sun.y
	if e >= HANDOVER:
		return sun
	var moon := -sun
	if e <= -HANDOVER:
		return moon
	# Twilight. Two lerps via TWILIGHT_DIR rather than one between antipodes,
	# which would pass through the zero vector at the horizon.
	var k := (HANDOVER - e) / (2.0 * HANDOVER)
	var via := TWILIGHT_DIR.normalized()
	if k < 0.5:
		return sun.lerp(via, k * 2.0).normalized()
	return via.lerp(moon, (k - 0.5) * 2.0).normalized()


## Never quite zero. A pitch-black night is not atmospheric, it is a black
## screen with a HUD on it, and there is no torch yet to fix it with.
##
## These two were halved after looking at the first screenshot tour. Sun 1.15
## plus a full-strength sky ambient blew the palette out completely - #86B04A
## meadow arrived on screen as near-white, and every zone looked like every
## other zone. Flat-shaded terrain has no texture detail to survive
## over-exposure with, so it goes to paste sooner than a textured world would.
## How dark it is: 0 in daylight, 1 at night.
##
## THE TRANSITION IS CIVIL TWILIGHT, not sunset. Real dusk is long - the sun
## goes down and the light keeps failing for another half hour - and a night
## factor that reached 1 at the moment the sun touched the horizon would switch
## the fireflies on while the sky was still orange.
##
## smoothstep rather than a linear ramp for the same reason day_amount() is
## curved: the two ends are the states worth being in, and the changeover
## should be quick without being a step.
##
## Pure, like everything else in this section, so the day cycle self-test can
## walk a whole day through it without a window.
static func night_amount(elevation: float) -> float:
	return 1.0 - smoothstep(-0.10, 0.06, elevation)


## The night value is the MOON's energy, and it is what lights the lit side of
## everything after dark - there is no ambient any more, see apply(). 0.04 was
## the figure when sky ambient did most of the night's work; the moon has to do
## it alone now, and a moonlit hillside should still be a hillside.
##
## LOOK V2 STAGE 0 PUT THESE BACK UP. 0.70 / 0.32 were chosen to cancel a bug:
## the ramp applied the albedo twice and carried Lambert's PI, so a lit surface
## arrived squared and 3.14x too bright, and halving the energy was the only
## lever anyone had. Both errors are fixed in Look.RAMP now, so the energy is
## the energy again: 1.0 at noon puts a lit #86B04A on screen at #86A73B -
## authored, warmed by the sun, and nothing else.
static func sun_energy(elevation: float, morning := false) -> float:
	return keyframe_at(elevation, morning)["energy"]


# --- Applying it ------------------------------------------------------------

func apply() -> void:
	var sun_pos := sun_position(time_of_day)
	var elevation := sun_pos.y
	# MORNING OR AFTERNOON. The horizon keyframe is dawn before noon and dusk
	# after it; without this the sky is the same orange at both ends of the day
	# and sunrise is a sunset played backwards.
	var morning := time_of_day < 0.5
	var kf := keyframe_at(elevation, morning)

	# NIGHT, PUBLISHED TO EVERY SHADER AT ONCE. Written here rather than by
	# anything that draws, because the sun's elevation is what defines it and
	# this is the only thing that knows where the sun is.
	RenderingServer.global_shader_parameter_set(
		&"kubik_night", night_amount(elevation))

	# THE POSTER'S GLOBALS, published before anything draws with them. Linear,
	# because every palette in the game is - see Look.
	Look.publish(kf, config.fog_start_m, config.fog_end_m, config.fog_bands)

	if _sun != null:
		# The light travels FROM the sun (or the moon), so it points the other
		# way. Built as a basis rather than look_at() because look_at() is
		# degenerate when the direction is parallel to up - which is exactly
		# noon.
		_sun.global_transform.basis = Basis.looking_at(-light_direction(time_of_day), Vector3.UP)
		_sun.light_color = (kf["sun"] as Color).linear_to_srgb()
		_sun.light_energy = kf["energy"]
		# Never hidden. See light_direction(): a night without the light is a
		# night without shade, which is black.
		_sun.visible = true

	if _env != null:
		_env.fog_light_color = (kf["fog"] as Color).linear_to_srgb()
		# NO AMBIENT. The ramp in Look owns the shade colour, and sky ambient
		# on top of it is exactly the "grey everywhere" the poster is not. The
		# environment's ambient is left in the scene for the handful of things
		# that are not poster materials, at nothing.
		_env.ambient_light_energy = 0.0

	if _sky != null:
		var day := day_amount(elevation)
		var dusk := dusk_amount(elevation)
		var night := night_amount(elevation)
		_sky.set_shader_parameter("sky_top", kf["sky_top"])
		_sky.set_shader_parameter("sky_mid", kf["sky_mid"])
		# THE HORIZON IS NOT THE FOG. Look v1 made them the same value so the
		# far mesh's last band could never be a line against the sky; look v2
		# gives the sky its own horizon row and puts the fog a step DARKER, so
		# a far range is a cut-out against the sky rather than glass over it.
		# The sky shader reads kubik_fog_color itself for everything below the
		# horizon, which is what keeps the two in agreement.
		_sky.set_shader_parameter("sky_horizon", kf["horizon"])
		_sky.set_shader_parameter("cloud_lit", kf["cloud_lit"])
		# The gold moon, Marcel's sixteenth refinement. The night keyframe's
		# accent; the moon's LIGHT stays the cold blue in kf["sun"].
		_sky.set_shader_parameter("moon_color", keyframe("night")["accent"])
		_sky.set_shader_parameter("sun_dir", sun_pos)
		_sky.set_shader_parameter("moon_dir", -sun_pos)
		_sky.set_shader_parameter("sun_color", kf["sun"])
		_sky.set_shader_parameter("day", day)
		_sky.set_shader_parameter("dusk", dusk)
		_sky.set_shader_parameter("night", night)
		# The rays fan out at dawn and dusk and are a faint fact by noon.
		_sky.set_shader_parameter("ray_strength", lerpf(0.22, 0.6, dusk))
		_sky.set_shader_parameter("ray_extent", lerpf(0.7, 1.6, dusk))
		_sky.set_shader_parameter("sky_bands", float(config.sky_bands))
		_sky.set_shader_parameter("cloud_cover", config.cloud_cover)


## Fog distances come from the config and only change when it does.
func _apply_fog_distances() -> void:
	if _env == null or config == null:
		return

	# LINEAR tonemapping, not Filmic.
	#
	# There are no textures here - a block is exactly its colour - so the
	# palette IS the art direction, and a tonemapper that reshapes it is
	# reshaping the art. Measured off the first tour: Filmic turned #86B04A
	# meadow into #68D62F on screen, brighter AND hue-shifted toward green,
	# because it curves each channel separately. Linear reproduces what was
	# authored, and the light energies below are set so a fully lit flat
	# surface lands at about 1.0 and nothing clips.
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.tonemap_exposure = 1.0

	_env.fog_enabled = true
	# Depth fog rather than exponential: the config says "clear until 120 m,
	# gone by 200 m", and depth fog takes exactly those two numbers. Matching
	# an exponential curve to them would be a fudge factor nobody could tune.
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_begin = config.fog_start_m
	_env.fog_depth_end = config.fog_end_m
	_env.fog_depth_curve = 1.0
	_env.fog_density = 1.0
	# THE POSTER SKY OWNS ITS HORIZON. The environment's fog used to tint the
	# sky (0.6) and bleed depth into it (0.25), which put a second, un-banded
	# gradient over the one the sky shader draws - so the horizon was neither
	# the sky's colour nor the fog's, and no swatch through it could be
	# predicted. Both off; the sky shader and Look's banded fog agree by
	# construction instead.
	_env.fog_sky_affect = 0.0
	_env.fog_aerial_perspective = 0.0


## Called after the tuning panel or a config reload changes the numbers.
func rebind(p_config: WorldgenConfig) -> void:
	config = p_config
	_apply_fog_distances()
	apply()
