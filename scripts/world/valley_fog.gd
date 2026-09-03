class_name ValleyFog
extends Node3D

## Fog that lies IN a place, not around the camera.
##
## Light v1 Stage 2, and it is the third of fog's three jobs
## (`../Kubik-bible/style-bible/10-color-and-light.md`):
##
##   1. Morning and evening: bands lying in the valley bottoms, three or four
##      layers, each layer lighter.
##   2. Night: pooling at the feet of castles and drifting up.
##   3. Eerie weather: thick, hiding the tops of tall things.
##
## The environment's own fog cannot do any of them. Exponential distance fog and
## even height fog are functions of the CAMERA - move and they move with you -
## so a "valley band" made of them is a band around your head that follows you
## up the mountain. What the bible describes is a thing that stays where the
## valley is while you climb out of it and look back down at it. That needs a
## density field with a position, which is what a `FogVolume` is.
##
## THE VOLUMES MOVE WITH THE TRACKED FLOOR AND NEVER WITH THE PLAYER. This is
## the whole design and the easy thing to get wrong: parenting them to the
## camera is a two-line implementation that produces exactly the artefact the
## feature exists to avoid.
##
## WHAT DECIDES WHERE THE FLOOR IS: `World.fog_floor_m`, the altitude of the
## nearest lake within 600 m or, with no lake, the lowest ground in a 300 m
## disc. Recomputed once a second on a strided scan of the coarse heightmap, so
## walking down into a valley brings the bands up to meet you rather than
## dragging them along.

## Metres across, per band. Wide enough that a valley floor is covered from any
## vantage inside it and the box's own edge is never the thing you notice;
## `edge_fade` softens what is left.
const BAND_SIZE_M := 600.0
## Metres tall, per band. Three of them stack to 36 m, which is about a tenth of
## this world's relief - a layer in the bottom, not a lid over the valley.
const BAND_HEIGHT_M := 12.0

## The three bands' densities at the day hour, lightest on top, in the plan's
## own 8 : 5 : 3 ratio. The hour scales all three together: at night the stack
## is twice this and under eerie four times, which is `vol_density` doing the
## scaling rather than a second table.
##
## THE PLAN'S NUMBERS WERE 0.08 / 0.05 / 0.03 AND THEY ARE OPAQUE. A FogMaterial
## density is extinction per unit length, and a band is BAND_SIZE_M across - so
## 0.08 over 600 m is an optical depth of about fifty, which is not a layer of
## mist lying in a valley, it is a wall. Measured on the first Stage 2 tour:
## `20-hour-day` came back as a featureless brown haze with the lake and every
## range gone, and `4-valley-floor` lost its whole background inside 100 m.
##
## These are the same ratio scaled so the BOTTOM band has an optical depth near
## 1.2 across its own width - thick enough to read as a bank you cannot see
## through lengthwise, thin enough to stand in and still see the valley wall.
## Recorded in docs/status/light-v1.md as a plan number that did not survive
## measurement; the ratio between the three is the plan's and is untouched.
const BAND_DENSITY := [0.0020, 0.00125, 0.00075]

## The day hour's `vol_density`, which the band densities above are quoted
## against. Everything else is a ratio to it.
const VOL_DENSITY_BASE := 0.010

## How far the density falls off at a box's edge, 0 to 1.
const EDGE_FADE := 0.4

## At night the stack drops, so the fog is lower and denser: pooling at the feet
## of things rather than lying in layers above them.
const NIGHT_DROP_M := 6.0

## THE EERIE LID. A fourth volume, tall rather than layered, sitting well above
## the floor - which is what "thick fog that hides the tops of tall things" is.
## The bands below stay; this is what takes the summit.
const EERIE_LID_BASE_M := 60.0
const EERIE_LID_HEIGHT_M := 200.0
## The eerie lid, on the same scale as the bands above and for the same reason.
## The plan's 0.06 over a 200 m box is an optical depth of twelve; this is about
## 1.4, which hides a summit without turning the frame into a grey card.
const EERIE_LID_DENSITY := 0.007

var _bands: Array[FogVolume] = []
var _lid: FogVolume = null

var _last_floor := INF
var _last_x := INF
var _last_z := INF
var _last_density := -1.0
var _last_albedo := Color(0, 0, 0)
var _last_eerie := false


func _ready() -> void:
	for i in BAND_DENSITY.size():
		var v := FogVolume.new()
		v.name = "Band%d" % i
		v.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		v.size = Vector3(BAND_SIZE_M, BAND_HEIGHT_M, BAND_SIZE_M)
		var m := FogMaterial.new()
		m.edge_fade = EDGE_FADE
		v.material = m
		v.visible = false
		add_child(v)
		_bands.append(v)

	_lid = FogVolume.new()
	_lid.name = "EerieLid"
	_lid.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_lid.size = Vector3(BAND_SIZE_M, EERIE_LID_HEIGHT_M, BAND_SIZE_M)
	var lm := FogMaterial.new()
	lm.edge_fade = EDGE_FADE
	lm.density = EERIE_LID_DENSITY
	_lid.material = lm
	_lid.visible = false
	add_child(_lid)


## Put the stack on a floor. Called by `World` when the tracked floor moves and
## by `SkyCycle` when the hour does; both are cheap and neither is per frame.
##
## `floor_m` is the altitude of the valley bottom in METRES, `at` is where on
## the map it is, `density_scale` is this hour's `vol_density` against the day's,
## and `albedo` is the hour's fog colour so a band is the same colour as the
## distance it lies in.
func place(floor_m: float, at: Vector3, density_scale: float, albedo: Color,
		night: float, eerie: bool) -> void:
	# NOTHING MOVES UNLESS SOMETHING CHANGED. A FogVolume's transform is cheap
	# but its material is not - writing a density every frame re-uploads the
	# froxel field - and the floor only changes once a second at most.
	if (is_equal_approx(floor_m, _last_floor) and is_equal_approx(at.x, _last_x)
			and is_equal_approx(at.z, _last_z)
			and is_equal_approx(density_scale, _last_density)
			and albedo.is_equal_approx(_last_albedo) and eerie == _last_eerie):
		return
	_last_floor = floor_m
	_last_x = at.x
	_last_z = at.z
	_last_density = density_scale
	_last_albedo = albedo
	_last_eerie = eerie

	if not is_finite(floor_m):
		for v in _bands:
			v.visible = false
		_lid.visible = false
		return

	# THE STACK DROPS AT NIGHT. `night` is 0 by day and 1 after dark, so this
	# slides rather than snapping - the same smoothstep every other night
	# behaviour in the game keys off.
	var base := floor_m - NIGHT_DROP_M * night
	for i in _bands.size():
		var v := _bands[i]
		# Each band sits on top of the one below it, centred on its own half.
		v.global_position = Vector3(at.x, base + BAND_HEIGHT_M * (float(i) + 0.5), at.z)
		var m := v.material as FogMaterial
		m.density = BAND_DENSITY[i] * density_scale
		m.albedo = albedo
		v.visible = true

	# EERIE PUTS A LID ON. Above the bands, tall, so what vanishes is the top of
	# the mountain and not the ground you are standing on - D7's "thick fog that
	# hides the tops of tall things".
	_lid.visible = eerie
	if eerie:
		_lid.global_position = Vector3(
			at.x, floor_m + EERIE_LID_BASE_M + EERIE_LID_HEIGHT_M * 0.5, at.z)
		var lm := _lid.material as FogMaterial
		lm.density = EERIE_LID_DENSITY * density_scale
		lm.albedo = albedo
