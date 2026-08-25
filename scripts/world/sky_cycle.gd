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

## Colours the sun light passes through, low to high. sRGB, as a Light's
## colour is. Look v1: a gold-white noon and an orange dusk, off the poster;
## the night colour is the MOON, which is the same light flipped to the other
## side of the sky - see apply().
const SUN_NIGHT := Color(0.43, 0.50, 0.72)
const SUN_DUSK := Color(1.00, 0.60, 0.29)
const SUN_NOON := Color(1.00, 0.95, 0.82)

## THE COLOUR OF SHADE. Look v1's first rule: shade is a colour, not a
## darkness. Everything the sun does not reach - the far side of a hill, the
## inside of a forest, a shadow - is this, times the surface's own colour.
## Blue-violet by day, deeper violet at dusk, near-black blue at night. sRGB
## here, converted to linear before it is published, like every palette.
const SHADE_NIGHT := Color(0.18, 0.22, 0.38)
const SHADE_DUSK := Color(0.44, 0.37, 0.66)
const SHADE_DAY := Color(0.60, 0.62, 0.86)

## Fog, and the sky it has to agree with. Fog that does not match the sky at the
## horizon reads as a grey wall standing in front of the view.
const FOG_NIGHT := Color(0.07, 0.09, 0.17)
const FOG_DUSK := Color(0.86, 0.60, 0.45)
const FOG_DAY := Color(0.71, 0.80, 0.89)

## Where the light comes from during twilight, while it is neither the sun's
## nor the moon's: low in the south. The sun and the moon are antipodes, so a
## straight lerp between them passes through zero; going via this direction
## does not, and it is where dusk light actually comes from.
const TWILIGHT_DIR := Vector3(0.0, 0.35, -1.0)

## Elevation, either side of the horizon, over which the light hands over from
## the sun to the moon.
const HANDOVER := 0.08

const SKY_TOP_NIGHT := Color(0.03, 0.05, 0.12)
const SKY_TOP_DAY := Color(0.30, 0.50, 0.83)

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


static func sun_color(elevation: float) -> Color:
	var c := SUN_NIGHT.lerp(SUN_NOON, day_amount(elevation))
	return c.lerp(SUN_DUSK, dusk_amount(elevation) * 0.85)


static func fog_color(elevation: float) -> Color:
	var c := FOG_NIGHT.lerp(FOG_DAY, day_amount(elevation))
	return c.lerp(FOG_DUSK, dusk_amount(elevation) * 0.75)


## The colour of shade at this elevation. Same shape as fog_color(): night to
## day by how light it is, pulled toward the dusk colour around the horizon.
static func shade_color(elevation: float) -> Color:
	var c := SHADE_NIGHT.lerp(SHADE_DAY, day_amount(elevation))
	return c.lerp(SHADE_DUSK, dusk_amount(elevation) * 0.75)


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
## 0.85 was the day value with sky ambient underneath it, and the first poster
## tour showed why it cannot stay: with the ramp painting the lit band at the
## sun's full colour and nothing blue mixed in, #86B04A meadow arrived on
## screen as neon. The palette was authored for a lit surface landing near 1.0
## in total; the ramp puts all of that in one term now.
static func sun_energy(elevation: float) -> float:
	return lerpf(0.32, 0.70, day_amount(elevation))


# --- Applying it ------------------------------------------------------------

func apply() -> void:
	var sun_pos := sun_position(time_of_day)
	var elevation := sun_pos.y

	# NIGHT, PUBLISHED TO EVERY SHADER AT ONCE. Written here rather than by
	# anything that draws, because the sun's elevation is what defines it and
	# this is the only thing that knows where the sun is.
	RenderingServer.global_shader_parameter_set(
		&"kubik_night", night_amount(elevation))

	# THE POSTER'S GLOBALS, published before anything draws with them. Linear,
	# because every palette in the game is - see Look.
	Look.publish(shade_color(elevation).srgb_to_linear(),
		fog_color(elevation).srgb_to_linear(),
		config.fog_start_m, config.fog_end_m, config.fog_bands)

	if _sun != null:
		# The light travels FROM the sun (or the moon), so it points the other
		# way. Built as a basis rather than look_at() because look_at() is
		# degenerate when the direction is parallel to up - which is exactly
		# noon.
		_sun.global_transform.basis = Basis.looking_at(-light_direction(time_of_day), Vector3.UP)
		_sun.light_color = sun_color(elevation)
		_sun.light_energy = sun_energy(elevation)
		# Never hidden. See light_direction(): a night without the light is a
		# night without shade, which is black.
		_sun.visible = true

	if _env != null:
		var fog := fog_color(elevation)
		_env.fog_light_color = fog
		# NO AMBIENT. The ramp in Look owns the shade colour, and sky ambient
		# on top of it is exactly the "grey everywhere" the poster is not. The
		# environment's ambient is left in the scene for the handful of things
		# that are not poster materials, at nothing.
		_env.ambient_light_energy = 0.0

	if _sky != null:
		var day := day_amount(elevation)
		var dusk := dusk_amount(elevation)
		var night := night_amount(elevation)
		_sky.set_shader_parameter("sky_top",
			SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, day).srgb_to_linear())
		# The horizon is the fog colour by construction, and so is everything
		# below it. Anything else and the fog reads as a wall in front of the
		# sky rather than as distance - and the far mesh's last fog band, which
		# is exactly kubik_fog_color, would be a line against the sky.
		_sky.set_shader_parameter("sky_horizon", fog_color(elevation).srgb_to_linear())
		_sky.set_shader_parameter("sun_dir", sun_pos)
		_sky.set_shader_parameter("moon_dir", -sun_pos)
		_sky.set_shader_parameter("sun_color", sun_color(elevation).srgb_to_linear())
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
	# Let the fog tint the sky too, so the horizon and the distance agree.
	_env.fog_sky_affect = 0.6
	_env.fog_aerial_perspective = 0.25


## Called after the tuning panel or a config reload changes the numbers.
func rebind(p_config: WorldgenConfig) -> void:
	config = p_config
	_apply_fog_distances()
	apply()
