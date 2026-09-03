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

## THE FOUR HOURS, AS DATA (light v1 Stage 1).
##
## Habit 1 (CLAUDE.md): facts as a table, not as twelve constants scattered
## down a file. A director, a debug panel or a later biome can read this.
##
## THE HOURS ARE THE BIBLE'S NOW, and there are four of them plus a weather.
## `10-color-and-light.md` names day, evening (pink), dusk (violet) and night
## (slate), and D6 is Marcel's own wording for why evening and dusk are two
## hours of ONE evening rather than one hour called sunset: "pink first, violet
## after". The table this replaced was dawn / noon / dusk / night, where "dusk"
## carried the whole of the evening as a single orange row - so the pink was
## never a colour the world passed through, and the violet was a tint on it.
##
## EERIE IS NOT AN HOUR (D7, Q13). It is a weather that sits on top of whichever
## hour it is: "night or day with the life taken out - saturation down, thick
## fog that hides the tops of tall things, and every warm light off". So it is
## one Dictionary of overrides applied after the blend, and never a fifth row.
##
## EVERY HEX IS A STARTING POINT, in the bible's own words at the top of
## `10-color-and-light.md`: "with real light the sky does most of this by itself
## and the grading only nudges it toward the reference". The `sky_*` rows below
## grade a PhysicalSkyMaterial, which computes its own scattering; what actually
## lands on screen is measured and recorded in `docs/status/light-v1.md`, and a
## delta there is a finding rather than a failure.
##
## sRGB IN THE FILE, LINEAR OUT OF keyframe_at(). The conversion happens once,
## on first use, and everything downstream is linear.
##
## THE ROWS.
##
##   sun / energy        the directional light. At night it is the moon.
##   ambient_energy      how much of the sky's own light reaches the shade.
##   shade               NOT PUBLISHED. The bible's shadow colour for this hour,
##                       kept so the status doc can print measured against
##                       authored. Real light makes the shadow now.
##   sky_horizon         }  NOT PUBLISHED either, and for the same reason: the
##   sky_high            }  bible's sky, against which the physical sky's own
##                          answer is recorded.
##   sky_rayleigh        the physical sky's Rayleigh tint - the sky's own colour
##   sky_mie             its Mie tint - the haze around the sun
##   sky_turbidity       how much haze. High turbidity is a thick evening.
##   sky_energy          the sky's brightness multiplier
##   sky_ground          what the sky sees below its horizon
##   fog                 the far fog's colour
##   fog_density         the exponential far term
##   fog_height_offset   metres above the valley floor the height fog sits
##   fog_height_density  the valley-bottom term (Stage 2)
##   vol_density         the volumetric field's density (Stage 2)
##   band_scale          the valley bands ALONE, against the field they sit in
##                       (Q25). Day and evening are notched to 0.6 because the
##                       lakeside postcard was still hazy at those two hours
##                       after the fog pass, and the bible's day fog is "thin,
##                       valley bottoms only". Dusk and night keep 1.0: those
##                       are the hours the bands are FOR.
##   warm                1 where warm light exists, 0 where it does not
##   saturation          the grade's saturation. 1.0 everywhere but eerie.
const KEYFRAMES := {
	# THE NEUTRAL ALPINE DAY (D5). Pale pink-grey at the horizon, colder and
	# bluer higher up, a warm white sun and a navy shadow. Warm lights are OFF
	# by day: a lit window means life, and at noon it means nothing.
	"day": {
		"sun": "#FFF4E0", "energy": 1.00,
		"ambient_energy": 1.00,
		"shade": "#22294D",
		"sky_horizon": "#D3C2BB", "sky_high": "#B3E4EF",
		"sky_rayleigh": "#B3E4EF", "sky_mie": "#D3C2BB",
		"sky_turbidity": 10.0, "sky_energy": 1.00, "sky_ground": "#6B6659",
		"fog_sky_affect": 0.30,
		"fog": "#C6C6C4", "fog_density": 0.0003,
		# THIN, AND IN THE VALLEY BOTTOMS ONLY. The bible's day fog is the one
		# hour that is explicitly not a fog bank: "thin, valley bottoms only,
		# mornings". Half the height term and half the volumetric of the plan's
		# starting row, both inside the tunable table's x0.5, because at the
		# plan's numbers a midday postcard came back as haze with no lake in it.
		"fog_height_offset": 40.0, "fog_height_density": 0.0005,
		"vol_density": 0.005, "band_scale": 0.6,
		"warm": 0.0, "saturation": 1.0,
	},
	# EVENING, THE PINK HALF (D6). The whole world is tinted, and the shadow
	# goes magenta with the sky rather than staying navy - which is the half of
	# D8 a fixed shadow colour can never do.
	"evening": {
		"sun": "#F9C5A5", "energy": 0.70,
		"ambient_energy": 0.80,
		"shade": "#813263",
		"sky_horizon": "#F0D2EC", "sky_high": "#CCA8EB",
		"sky_rayleigh": "#CCA8EB", "sky_mie": "#F0D2EC",
		"sky_turbidity": 14.0, "sky_energy": 1.00, "sky_ground": "#5A4650",
		"fog_sky_affect": 0.60,
		"fog": "#E8AFC9", "fog_density": 0.00045,
		"fog_height_offset": 40.0, "fog_height_density": 0.001,
		"vol_density": 0.005, "band_scale": 0.6,
		"warm": 1.0, "saturation": 1.0,
	},
	# DUSK, THE VIOLET HALF. The bible's table says of the sun here: "none; fire
	# takes over #f5c05e". Taken as a very low energy rather than as zero - the
	# day-cycle self-test asserts the light never goes out, and a directional
	# light at zero is a different frame from one at 0.18, not a darker one.
	# What "the sun is gone" reads as is the sky doing the lighting, which at
	# ambient 0.5 against sun 0.18 is what this row is.
	"dusk": {
		"sun": "#8F86B5", "energy": 0.18,
		"ambient_energy": 0.50,
		"shade": "#0B1123",
		"sky_horizon": "#A281C3", "sky_high": "#63559E",
		"sky_rayleigh": "#63559E", "sky_mie": "#A281C3",
		"sky_turbidity": 26.0, "sky_energy": 0.45, "sky_ground": "#2A2438",
		"fog_sky_affect": 0.60,
		"fog": "#736EB7", "fog_density": 0.0006,
		"fog_height_offset": 40.0, "fog_height_density": 0.0015,
		"vol_density": 0.006, "band_scale": 1.0,
		"warm": 1.0, "saturation": 1.0,
	},
	# NIGHT IS SLATE, NOT COBALT (D7). Cobalt is the desert's night (D26) and
	# does not belong here. The moon is the sun's antipode at #b9c2cf and 0.12
	# (Q16); with sky ambient on at a quarter, a moonlit hillside is still a
	# hillside.
	"night": {
		"sun": "#B9C2CF", "energy": 0.12,
		"ambient_energy": 0.25,
		"shade": "#1A2534",
		"sky_horizon": "#213147", "sky_high": "#0C1722",
		"sky_rayleigh": "#213147", "sky_mie": "#0C1722",
		"sky_turbidity": 6.0, "sky_energy": 0.35, "sky_ground": "#121A24",
		"fog_sky_affect": 0.50,
		"fog": "#466477", "fog_density": 0.00045,
		# MEASURED, AND THE OBVIOUS LEVER RUNS BACKWARDS AT THIS HOUR. Fog's
		# second job is pooling that is VISIBLE against dark ground, so the
		# first instinct is more of it. Three values were shot: at the plan's
		# 0.020 the night frame lost its ranges entirely; at 0.014 the lake
		# shore measured V 15.4; at 0.009 it measured V 17.1. Denser fog makes
		# the night DARKER, not milkier, because at a 0.12 moon and a 0.25
		# ambient there is almost no light in the air to scatter - so extra
		# density only extinguishes the brighter background behind it.
		#
		# Lighting the fog rather than thickening it is the lever this wants,
		# and it is night two's: ambient energy and the ambient inject both
		# move the fog and the ground together. Recorded in the status doc.
		"fog_height_offset": 40.0, "fog_height_density": 0.002,
		"vol_density": 0.006, "band_scale": 1.0,
		"warm": 1.0, "saturation": 1.0,
	},
}

## EERIE (D7, Q13). Applied on top of whichever hour it is, never instead of it.
##
## "The difference between night and eerie is only the fog and the lights."
## Sky flat, fog thick, saturation down, every warm light off. The height
## density goes NEGATIVE, which is what makes the fog thicken UPWARD and hide
## the tops of tall things instead of pooling at their feet.
##
## `10-color-and-light.md` also asks for "the base of things #101f26", which is
## a per-material floor rather than a light, and is NOT reproduced in phase 1.
## Recorded as a silence in docs/status/light-v1.md.
const EERIE := {
	"sky_horizon": "#E1F2F8", "sky_high": "#C3DCE8",
	"sky_rayleigh": "#C3DCE8", "sky_mie": "#E1F2F8",
	"sky_turbidity": 24.0, "sky_ground": "#8E9CA4",
	"fog": "#97B4C7", "fog_sky_affect": 1.0,
	# EERIE KEEPS ITS BANDS AT FULL. Q25's notch is for the two clear hours
	# whose colour the fog was burying; eerie is the one hour whose whole point
	# is that the fog wins, and Marcel's night-one review said it reads right.
	"band_scale": 1.0,
	"warm": 0.0, "saturation": 0.55,
	"fog_density_scale": 4.0, "vol_density_scale": 4.0,
	"fog_height_density": -0.004,
}

## THE HOUR ANCHORS, as sun elevations. The tour and the gallery ask for an hour
## by NAME and `time_for_elevation()` answers with a time, so a shot called
## "evening" and the keyframe called "evening" cannot drift apart.
const HOURS := {
	"day": 0.60,
	"evening": 0.09,
	"dusk": -0.15,
	"night": -0.85,
}

## Where the evening and dusk sets peak, and how wide their shoulders are.
## Evening peaks with the sun just above the horizon and dusk just below it,
## which is what makes them two halves of one evening rather than two hours.
const EVENING_PEAK := 0.09
const EVENING_WIDTH := 0.26
const DUSK_PEAK := -0.15
const DUSK_WIDTH := 0.30

## Dawn is the evening set with the colour taken down. The bible gives dawn no
## hour of its own - its table has four rows and none of them is sunrise - so
## this is a silence filled rather than a rule followed, and it is recorded as
## one. A morning is a cooler, paler evening; it is not a sunset played
## backwards, which is what one shared horizon row would make it.
const DAWN_SATURATION := 0.70


static var _keyframes_linear := {}
static var _dawn_linear := {}
static var _eerie_linear := {}


## One keyframe, every colour linear, built once.
static func keyframe(name: String) -> Dictionary:
	_build_keyframes()
	return _keyframes_linear[name]


static func _build_keyframes() -> void:
	if not _keyframes_linear.is_empty():
		return
	for key in KEYFRAMES:
		_keyframes_linear[key] = _to_linear(KEYFRAMES[key])
	_eerie_linear = _to_linear(EERIE)
	# DAWN IS THE EVENING SET WITH THE COLOUR TAKEN DOWN. Desaturated toward
	# each colour's own luminance, so the hue is the evening's and only the
	# strength differs - a pale pink morning rather than a second palette to
	# keep in step with the first.
	_dawn_linear = {}
	for field in _keyframes_linear["evening"]:
		var v = _keyframes_linear["evening"][field]
		if typeof(v) == TYPE_COLOR:
			var l := Look.luma(v)
			_dawn_linear[field] = (v as Color).lerp(Color(l, l, l), 1.0 - DAWN_SATURATION)
		else:
			_dawn_linear[field] = v


static func _to_linear(row: Dictionary) -> Dictionary:
	var out := {}
	for field in row:
		var v = row[field]
		if typeof(v) == TYPE_STRING:
			out[field] = Color.html(v).srgb_to_linear()
		else:
			out[field] = float(v)
	return out


## The set for this sun elevation, every colour LINEAR, ready to publish.
##
## NIGHT TO DAY BY HOW LIGHT IT IS, then pulled toward the evening set and then
## the dusk set by two windows either side of the horizon. The windows are what
## make the evening a place the world passes THROUGH rather than a tint applied
## to noon: evening peaks with the sun at +0.09 and dusk at -0.15, so a full
## descent runs day -> pink -> violet -> slate in that order and never skips
## one.
##
## ON THE MORNING SIDE the evening set is replaced by the dawn set. Dusk's
## violet is kept as it is, because the violet before sunrise is the same
## violet as the violet after sunset - it is the sky doing the same thing with
## the sun on the other side.
##
## Pure, like everything in this section, so the day-cycle self-test can walk a
## whole day through it without a window.
static func keyframe_at(elevation: float, morning := false, weather := "clear") -> Dictionary:
	_build_keyframes()
	var night: Dictionary = _keyframes_linear["night"]
	var day: Dictionary = _keyframes_linear["day"]
	var edge: Dictionary = _dawn_linear if morning else _keyframes_linear["evening"]
	var dusk: Dictionary = _keyframes_linear["dusk"]

	var d := day_amount(elevation)
	var e_w := _shoulder(elevation, EVENING_PEAK, EVENING_WIDTH)
	var k_w := _shoulder(elevation, DUSK_PEAK, DUSK_WIDTH)

	var out := {}
	for field in day:
		if typeof(day[field]) == TYPE_COLOR:
			var c: Color = (night[field] as Color).lerp(day[field], d)
			c = c.lerp(edge[field], e_w)
			out[field] = c.lerp(dusk[field], k_w)
		else:
			var f := lerpf(night[field], day[field], d)
			f = lerpf(f, edge[field], e_w)
			out[field] = lerpf(f, dusk[field], k_w)

	if weather == "eerie":
		_apply_eerie(out)
	return out


## The eerie overrides, on top of the blended hour.
##
## The two `_scale` entries multiply rather than replace, because "thick fog"
## has to mean four times whatever this hour's fog already was - a flat density
## would make an eerie noon and an eerie night the same weather, and D7 says
## eerie is "night OR day with the life taken out".
static func _apply_eerie(out: Dictionary) -> void:
	for field in _eerie_linear:
		if field.ends_with("_scale"):
			continue
		out[field] = _eerie_linear[field]
	out["fog_density"] = out["fog_density"] * _eerie_linear["fog_density_scale"]
	out["vol_density"] = out["vol_density"] * _eerie_linear["vol_density_scale"]


## A window that peaks at `peak` and falls to nothing `width` either side of it,
## with the corners taken off so an hour arrives and leaves rather than
## switching on.
static func _shoulder(elevation: float, peak: float, width: float) -> float:
	var t := clampf(1.0 - absf(elevation - peak) / width, 0.0, 1.0)
	return smoothstep(0.0, 1.0, t)


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

## The world, for the one thing the sky needs from it: where the valley floor
## is, so the height fog and the fog bands have somewhere to sit (Stage 2).
## Null in the gallery and in the self-tests, and the fog terms switch off when
## it is - a swatch pad has no valley.
var world: World = null

## The bands that lie in the valley bottom. Owned by `World`, driven from here
## because the hour decides how thick they are and what colour they take.
var valley_fog: ValleyFog = null

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
var _sky: PhysicalSkyMaterial = null


func setup(p_config: WorldgenConfig, sun: DirectionalLight3D,
		world_environment: WorldEnvironment) -> void:
	config = p_config
	_sun = sun
	_env = world_environment.environment
	# ONE DECISION LIGHTS THE GAME AND THE SHEETS. The environment, the sky
	# material, the tonemap, SSAO and the sun's shadow all come from Look, so
	# the gallery's swatch sheets are lit by the same call the world is.
	Look.configure_environment(_env, _sun)
	if _env != null and _env.sky != null:
		_sky = _env.sky.sky_material as PhysicalSkyMaterial
		if _sky != null and _sky.night_sky == null:
			# Once, at setup: the material keeps it and apply() never touches it.
			_sky.night_sky = make_night_panorama()
	time_of_day = config.day_start
	apply()


func _process(delta: float) -> void:
	if config == null or frozen:
		return
	if config.day_seconds > 0.0:
		time_of_day = fposmod(time_of_day + delta / config.day_seconds, 1.0)
	apply()


# --- Pure functions of time, so they can be tested without a window ---------

## Unit vector pointing at the sun. y > 0 means daytime.
##
## The angle comes from `arc_angle()` rather than straight from `t`, because
## the sun does not move at one speed - see the warp below.
static func sun_position(t: float) -> Vector3:
	# arc_angle(0.25) is 0, which puts the sun on the eastern horizon; PI/2 is
	# overhead and PI is west.
	var angle := arc_angle(t)
	return Vector3(cos(angle), sin(angle), -ARC_TILT).normalized()


# --- The warped arc (D52, Q7) -------------------------------------------------
#
# A FULL DAY IS ABOUT FORTY MINUTES AND THE EVENING IS SIX TO EIGHT OF THEM.
# That is D52, and `day_seconds` 2400 gives the first half of it. The second
# half is this: at a uniform angular speed, 2400 seconds of day puts the sun's
# passage from +8 to -12 degrees - the whole pink-then-violet evening - at
# about 133 seconds. Two minutes is not an evening, and no amount of widening
# the pink window fixes it, because a pink sky under a sun at 40 degrees is not
# an evening either. It is a filter.
#
# So the sun SLOWS DOWN where the light is worth watching. Its angular speed
# drops by a factor of three across the evening window and by two across the
# dawn window, and runs uniform everywhere else, normalised so the circle still
# closes in `day_seconds`. The evening then takes about six and a half minutes
# of a forty-minute day, which is what the bible asks for, and the sun is
# genuinely low while it happens.
#
# ONE FUNCTION OWNS IT so the compass, the tour, the gallery and the day-cycle
# self-test cannot disagree about where the sun is. Everything that wants an
# angle asks `arc_angle(t)`; everything that wants a time for a given elevation
# asks `time_for_elevation()`, which inverts it.

## The evening window's edges, in degrees of elevation: +8 descending to -12.
const WARP_HIGH_DEG := 8.0
const WARP_LOW_DEG := -12.0
## How much the sun is slowed inside each window.
const WARP_EVENING := 3.0
const WARP_DAWN := 2.0

## The arc angles the window edges sit at. `sun_position` divides sin(angle) by
## the arc's own length, so an elevation of `e` degrees is at
## asin(sin(e) * |(1, 0, -ARC_TILT)|).
static func _angle_of_elevation(deg: float) -> float:
	var tilt := sqrt(1.0 + ARC_TILT * ARC_TILT)
	return asin(clampf(sin(deg_to_rad(deg)) * tilt, -1.0, 1.0))


## The arc in segments: each entry is [angle at the end of the segment, how many
## seconds of day one radian of it costs]. Built once, walked in both
## directions.
static var _segments: Array = []
static var _segments_total := 0.0


static func _build_arc() -> void:
	if not _segments.is_empty():
		return
	var hi := _angle_of_elevation(WARP_HIGH_DEG)   # + , just above the horizon
	var lo := _angle_of_elevation(WARP_LOW_DEG)    # - , just below it
	# Walking from angle 0 (sunrise, on the eastern horizon) all the way round.
	# The dawn window straddles 0, so it is split: its second half runs from 0
	# up to +8 degrees, and its first half is the last segment before the wrap.
	_segments = [
		[hi, WARP_DAWN],               # 0 .. +8 deg, still dawn
		[PI - hi, 1.0],                # the day
		[PI - lo, WARP_EVENING],       # +8 .. -12 deg on the way down: the evening
		[TAU + lo, 1.0],               # the night
		[TAU, WARP_DAWN],              # -12 .. 0 deg on the way up: dawn again
	]
	_segments_total = 0.0
	var prev := 0.0
	for seg in _segments:
		_segments_total += (seg[0] - prev) * seg[1]
		prev = seg[0]


## The sun's arc angle at time `t`. Monotonic, and it closes the circle at
## t + 1.
static func arc_angle(t: float) -> float:
	_build_arc()
	var u := fposmod(t - 0.25, 1.0) * _segments_total
	var prev := 0.0
	for seg in _segments:
		var span: float = (seg[0] - prev) * seg[1]
		if u <= span:
			return prev + u / seg[1]
		u -= span
		prev = seg[0]
	return prev


## The inverse: the time of day at which the sun stands at arc angle `angle`.
static func arc_time(angle: float) -> float:
	_build_arc()
	var a := fposmod(angle, TAU)
	var acc := 0.0
	var prev := 0.0
	for seg in _segments:
		if a <= seg[0]:
			acc += (a - prev) * seg[1]
			break
		acc += (seg[0] - prev) * seg[1]
		prev = seg[0]
	return fposmod(0.25 + acc / _segments_total, 1.0)


## The time of day at which the sun's ELEVATION is `e`, on the evening side of
## the arc or the morning side.
##
## By bisection on `sun_position` itself rather than by inverting the geometry,
## so it can never drift from the thing it is inverting: if the arc changes,
## this follows it for free. Twelve iterations puts it inside a thousandth of a
## day, which is under three seconds of a forty-minute one.
static func time_for_elevation(e: float, evening := true) -> float:
	# Noon and midnight bracket exactly one monotonic descent (evening) and one
	# monotonic ascent (morning).
	var lo := arc_time(PI * 0.5) if evening else arc_time(PI * 1.5)
	var hi := lo + 0.5
	for i in 40:
		var mid := (lo + hi) * 0.5
		var m := sun_position(mid).y
		# Descending on the evening side, ascending on the morning side.
		if (m > e) == evening:
			lo = mid
		else:
			hi = mid
	return fposmod((lo + hi) * 0.5, 1.0)


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


## The keyframe's own energy, which for the night row is the MOON's.
##
## LIGHT V1 STAGE 0 GAVE THE NIGHT A SECOND LIGHT. The night keyframe's energy
## used to have to carry the whole of the dark on its own, because ambient was
## disabled outright and the ramp painted shade from the directional pass. Sky
## ambient is on at full contribution now, so the moon lights the lit side and
## the sky lights everything else - which is what makes a night slate rather
## than black (D7) and a shadow sky-coloured rather than empty (D8). Stage 1
## re-authors the energies against the bible's four hours.
static func sun_energy(elevation: float, morning := false) -> float:
	return keyframe_at(elevation, morning)["energy"]


# --- Applying it ------------------------------------------------------------

func apply() -> void:
	var sun_pos := sun_position(time_of_day)
	var elevation := sun_pos.y
	# MORNING OR AFTERNOON. The horizon set is the dawn set before noon and the
	# evening set after it; without this the sky is the same pink at both ends
	# of the day and sunrise is a sunset played backwards.
	var morning := time_of_day < 0.5
	var kf := keyframe_at(elevation, morning, weather())

	# NIGHT, PUBLISHED TO EVERY SHADER AT ONCE. Written here rather than by
	# anything that draws, because the sun's elevation is what defines it and
	# this is the only thing that knows where the sun is.
	RenderingServer.global_shader_parameter_set(
		&"kubik_night", night_amount(elevation))

	# WHERE WARM LIGHT EXISTS. 0 by day, 1 from the evening on, and 0 at every
	# hour under eerie weather (D7).
	Look.publish(kf)

	if _sun != null:
		# The light travels FROM the sun (or the moon), so it points the other
		# way. Built as a basis rather than look_at() because look_at() is
		# degenerate when the direction is parallel to up - which is exactly
		# noon.
		_sun.global_transform.basis = Basis.looking_at(-light_direction(time_of_day), Vector3.UP)
		_sun.light_color = (kf["sun"] as Color).linear_to_srgb()
		_sun.light_energy = kf["energy"]
		# Never hidden. The moon is the sun's antipode and the night's only
		# directional light.
		_sun.visible = true

	if _env != null:
		# THE HOUR OWNS THE FOG - its colour and how much of it there is. The
		# height term is Stage 2's and stays at nothing until it has a valley
		# floor to sit on.
		_env.fog_light_color = (kf["fog"] as Color).linear_to_srgb()
		_env.fog_density = kf["fog_density"]
		# HOW MUCH OF THE SKY THE FOG OWNS. The bible's rule is "fog always
		# fades to the current sky colour"; this is the other half of the same
		# fact - a thick evening air tints the sky it is suspended in. It rises
		# with the hour's density and goes to 1.0 under eerie, where the sky
		# IS the fog (D7: the difference between night and eerie is only the
		# fog and the lights).
		_env.fog_sky_affect = kf["fog_sky_affect"]
		_env.ambient_light_energy = kf["ambient_energy"]
		# THE VALLEY-BOTTOM TERM (Stage 2). Height fog needs a height, and the
		# only height worth having is the local valley floor - `World` tracks it
		# once a second off the coarse heightmap. With no world to ask (a
		# gallery sheet, a self-test) there is no floor and the term stays off,
		# which is right: a swatch pad has no valley.
		var floor_m := world.fog_floor_m if world != null else INF
		if is_finite(floor_m):
			_env.fog_height = floor_m + kf["fog_height_offset"]
			# EERIE INVERTS IT. A negative height density thickens the fog
			# UPWARD, so what disappears is the top of a thing rather than its
			# feet - D7's "thick fog that hides the tops of tall things".
			_env.fog_height_density = kf["fog_height_density"]
		else:
			_env.fog_height_density = 0.0
		# The volumetric field takes the hour's colour, so a band in the valley
		# and the distance behind it are the same fog.
		_env.volumetric_fog_density = kf["vol_density"]
		_env.volumetric_fog_albedo = (kf["fog"] as Color).linear_to_srgb()
		# THE GRADE IS STAGE 4'S, with one exception that cannot wait for it:
		# eerie is defined by saturation coming down (D7), so the adjustment is
		# switched on only where this hour asks for less than full colour. At
		# every clear hour it stays off and the frame is exactly Stage 0's.
		var sat: float = kf["saturation"]
		_env.adjustment_enabled = sat < 0.999
		if _env.adjustment_enabled:
			_env.adjustment_saturation = sat

	if valley_fog != null and world != null:
		# THE BANDS LIE IN THE VALLEY, and the hour decides how thick they are.
		# `vol_density` against the day's is the scale, so night doubles the
		# stack and eerie quadruples it without a second table.
		valley_fog.place(world.fog_floor_m, world.fog_floor_at,
			kf["vol_density"] / ValleyFog.VOL_DENSITY_BASE * kf["band_scale"],
			(kf["fog"] as Color).linear_to_srgb(),
			night_amount(elevation), weather() == "eerie")

	if _sky != null:
		# THE PHYSICAL SKY, GRADED. It computes its own scattering from the
		# sun's position; these rows nudge it toward the bible's hours rather
		# than painting them, which is the whole difference between this and
		# the poster sky it replaced.
		_sky.rayleigh_color = (kf["sky_rayleigh"] as Color).linear_to_srgb()
		_sky.mie_color = (kf["sky_mie"] as Color).linear_to_srgb()
		_sky.ground_color = (kf["sky_ground"] as Color).linear_to_srgb()
		_sky.turbidity = kf["sky_turbidity"]
		_sky.energy_multiplier = kf["sky_energy"]
		# The disc stays small: Stage 4 has to keep it under the glow threshold,
		# and D40 allows clipped white only there.
		_sky.sun_disk_scale = 1.0


## The weather this world is in: "clear" or "eerie" (Q13). Local and unhashed -
## it is a modifier on the hour, not a fact about the world.
func weather() -> String:
	return config.weather if config != null else "clear"


# --- The night sky ------------------------------------------------------------

## THE STARS, BUILT IN CODE AND NEVER SAVED (Q6).
##
## `PhysicalSkyMaterial` goes to its ground colour once the sun is below the
## horizon unless it is given a night panorama, and hard rule "no new textures"
## has exactly one exception in this plan: a code-generated night sky is not a
## texture asset. Nothing is written to `assets/`; this is an Image built at
## setup and handed straight to the material.
##
## The gradient is the night keyframe's own two hexes, so the stars sit on the
## same slate the table asks for and the sky and the fog cannot disagree. The
## stars are a two-stage hash - one to decide whether a texel is a star at all,
## a second for how bright - which is how the poster sky drew them and the one
## thing in it worth keeping.
static func make_night_panorama() -> ImageTexture:
	const W := 1024
	const H := 512
	_build_keyframes()
	var high := Color.html(KEYFRAMES["night"]["sky_high"] as String)
	var horizon_c := Color.html(KEYFRAMES["night"]["sky_horizon"] as String)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	for y in H:
		# 0 at the top of the sphere, 1 at the bottom. The gradient runs from
		# the high colour overhead to the horizon colour at the equator and
		# holds it below, because nothing looks at the bottom of the sphere.
		var v := float(y) / float(H - 1)
		var band := clampf(v * 2.0, 0.0, 1.0)
		var base := high.lerp(horizon_c, band)
		for x in W:
			var c := base
			# Deterministic, and dense enough to read at 1024 x 512 without
			# becoming a field of salt. Stars thin out toward the horizon, as
			# haze thins them in life.
			rng.seed = hash(Vector2i(x, y))
			if rng.randf() > 0.9985 - 0.0010 * (1.0 - band):
				var b := rng.randf()
				c = base.lerp(Color(0.95, 0.96, 1.0), 0.35 + 0.65 * b * b)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Called after the tuning panel or a config reload changes the numbers.
func rebind(p_config: WorldgenConfig) -> void:
	config = p_config
	apply()
