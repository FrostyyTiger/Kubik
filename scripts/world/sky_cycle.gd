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

## Colours the sun light passes through, low to high.
const SUN_NIGHT := Color(0.28, 0.36, 0.60)
const SUN_DUSK := Color(1.00, 0.58, 0.32)
const SUN_NOON := Color(1.00, 0.97, 0.92)

## Fog, and the sky it has to agree with. Fog that does not match the sky at the
## horizon reads as a grey wall standing in front of the view.
const FOG_NIGHT := Color(0.07, 0.09, 0.17)
const FOG_DUSK := Color(0.86, 0.60, 0.45)
const FOG_DAY := Color(0.71, 0.80, 0.89)

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

var _sun: DirectionalLight3D = null
var _env: Environment = null
var _sky: ProceduralSkyMaterial = null


func setup(p_config: WorldgenConfig, sun: DirectionalLight3D,
		world_environment: WorldEnvironment) -> void:
	config = p_config
	_sun = sun
	_env = world_environment.environment
	if _env != null and _env.sky != null:
		var mat := _env.sky.sky_material
		if mat is ProceduralSkyMaterial:
			_sky = mat
	time_of_day = config.day_start
	_apply_fog_distances()
	apply()


func _process(delta: float) -> void:
	if config == null:
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


## Never quite zero. A pitch-black night is not atmospheric, it is a black
## screen with a HUD on it, and there is no torch yet to fix it with.
static func sun_energy(elevation: float) -> float:
	return lerpf(0.06, 1.15, day_amount(elevation))


static func ambient_energy(elevation: float) -> float:
	return lerpf(0.25, 1.0, day_amount(elevation))


# --- Applying it ------------------------------------------------------------

func apply() -> void:
	var sun_pos := sun_position(time_of_day)
	var elevation := sun_pos.y

	if _sun != null:
		# The light travels FROM the sun, so it points the other way. Built as
		# a basis rather than look_at() because look_at() is degenerate when
		# the direction is parallel to up - which is exactly noon.
		_sun.global_transform.basis = Basis.looking_at(-sun_pos, Vector3.UP)
		_sun.light_color = sun_color(elevation)
		_sun.light_energy = sun_energy(elevation)
		# Below the horizon the sun would light the terrain from underneath.
		_sun.visible = elevation > -0.05

	if _env != null:
		var fog := fog_color(elevation)
		_env.fog_light_color = fog
		_env.ambient_light_energy = ambient_energy(elevation)

	if _sky != null:
		var day := day_amount(elevation)
		var dusk := dusk_amount(elevation)
		_sky.sky_top_color = SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, day)
		# The horizon is the fog colour by construction. Anything else and the
		# fog reads as a wall in front of the sky rather than as distance.
		_sky.sky_horizon_color = fog_color(elevation)
		_sky.ground_horizon_color = fog_color(elevation)
		_sky.ground_bottom_color = FOG_NIGHT.lerp(Color(0.22, 0.24, 0.22), day)
		_sky.sun_angle_max = lerpf(2.0, 12.0, dusk)


## Fog distances come from the config and only change when it does.
func _apply_fog_distances() -> void:
	if _env == null or config == null:
		return
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
