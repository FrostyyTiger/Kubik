class_name Compass
extends Control

## THE NAVIGATION UI, AND IT IS A STRIP. There is no minimap in this game and
## there is no setting that turns one on (ui-v1.md, decision 1, which resolves
## the recorded pushback harder than it was recorded: the "off by default
## toggle" escape hatch is not wanted either).
##
## A thin band across the top centre, carrying the cardinals and a bearing to
## each party member. Placed markers and site names join it when those systems
## exist (Campfire v1, Navigation v1). The map SCREEN - fog of exploration,
## ranging IS the progression - stays in Navigation v1 and is untouched here.
##
## Why a strip and not a map: a map tells you where everything is, and this
## game's whole progression is that you do not know yet. A compass tells you
## which way you are facing, which is the one navigational fact that is never
## a spoiler.

## NORTH IS -Z. DECLARED ONCE, HERE, BECAUSE NOTHING IN THE REPO HAD SAID IT.
##
## No cardinal convention existed anywhere in this codebase before this line -
## the world had a +X and a -Z and no opinion about which was north. This is
## the choice, and the reason it is this one rather than the other three:
##
## SkyCycle.sun_position() puts the sun on +X at t = 0.25, which is sunrise.
## With north at -Z, +X is east - and the sun rises in the east, which is the
## only reading of this world that is not actively embarrassing. Every other
## assignment makes the sun rise in the north, the south, or the west.
##
## It follows that the camera's yaw maps to a heading as
## `wrapf(rad_to_deg(-camera_yaw()), 0.0, 360.0)`: a Godot yaw of 0 faces -Z,
## which is north, and yaw increases anticlockwise seen from above while
## compass bearings increase clockwise, hence the negation.
const NORTH_IS_MINUS_Z := true

## Cardinal, and the bearing in degrees. A table rather than four branches, so
## the intercardinals are one row each the day somebody wants them.
const CARDINALS := [
	["N", 0.0], ["E", 90.0], ["S", 180.0], ["W", 270.0],
]

## Degrees between minor ticks. Small enough that a slow turn visibly moves the
## strip - a compass that only changes every 45 degrees reads as broken.
const TICK_DEG := 15.0

var config: HudConfig = null

## Set by the HUD each frame: our heading, and every party member's bearing.
var heading_deg := 0.0

## Array of {bearing: float, color: Color}. Empty solo, which is the whole of
## what "no code path assumes a second peer" means here.
var marks: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A camera yaw in radians -> a compass heading in degrees. See NORTH_IS_MINUS_Z.
static func heading_from_yaw(yaw_rad: float) -> float:
	return wrapf(rad_to_deg(-yaw_rad), 0.0, 360.0)


## Where something at world position `to` lies from world position `from`, as a
## compass bearing. Same convention, derived once so the strip and anything
## later cannot drift apart.
static func bearing_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	if is_zero_approx(d.x) and is_zero_approx(d.z):
		return 0.0
	# atan2(east, north) with north = -Z and east = +X.
	return wrapf(rad_to_deg(atan2(d.x, -d.z)), 0.0, 360.0)


## Where a bearing falls across the strip, in local pixels, or NAN if it is off
## the ends. `pin` clamps to the nearest edge instead of dropping it.
func _x_of(bearing: float, pin := false) -> float:
	var span: float = config.strip_span_deg if config != null else 150.0
	# The SHORT way round. Without wrapping to [-180, 180] a heading of 350
	# against a bearing of 10 reads as 340 degrees away rather than 20, and the
	# mark jumps across the whole strip once per revolution.
	var delta := wrapf(bearing - heading_deg, -180.0, 180.0)
	var half := span * 0.5
	if absf(delta) > half:
		if not pin:
			return NAN
		# PINNED TO THE EDGE, WHICH IS WHAT A COMPASS DOES.
		#
		# A tick or a cardinal that has scrolled off the end is simply not on
		# the strip and drawing it clamped would be a lie about a direction. A
		# PARTY MEMBER is the opposite case: "your friend is somewhere off to
		# the right" is exactly the thing you want to know, and it is the half
		# of the answer a strip can still give. Dropping them meant a friend
		# vanished from the UI whenever they were more than strip_span_deg/2
		# away - which at the shipped 150 degree span is most of the time, and
		# is how the first party shot came to have an icon and no chevron.
		delta = half * signf(delta)
	return size.x * 0.5 + (delta / span) * size.x


func _draw() -> void:
	if config == null or size.x <= 0.0:
		return
	var h := size.y
	# The rule the strip hangs from: one hairline, edge to edge, ink. The band
	# itself has no ground - the world reads straight through it, which is what
	# keeps it from being a bar across the top of the screen.
	draw_line(Vector2(0.0, h - 1.0), Vector2(size.x, h - 1.0),
		Color(Deco.INK, 0.55), 1.0)

	# Minor ticks, quiet.
	var span: float = config.strip_span_deg
	var first := floorf((heading_deg - span * 0.5) / TICK_DEG) * TICK_DEG
	var last := heading_deg + span * 0.5
	var deg := first
	while deg <= last:
		var x := _x_of(deg)
		if not is_nan(x):
			draw_line(Vector2(x, h - 6.0), Vector2(x, h - 1.0),
				Color(Deco.INK, 0.4), 1.0)
		deg += TICK_DEG

	# The cardinals, set in the poster's face.
	var font := Deco.font_of(&"SectionLabel")
	var px := int(h * 0.62)
	for entry in CARDINALS:
		var x := _x_of(entry[1])
		if is_nan(x):
			continue
		var text: String = entry[0]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_line(Vector2(x, h - 9.0), Vector2(x, h - 1.0), Deco.INK, 1.5)
		draw_string(font, Vector2(x - w * 0.5, float(px) * 0.92), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Deco.INK)

	# THE PARTY, AS CHEVRONS. Each in its peer's own hue - the same
	# golden-ratio colour the party icon uses, which is the hue's new home now
	# that the floating nametag is gone.
	for mark in marks:
		var x := _x_of(float(mark["bearing"]), true)
		if is_nan(x):
			continue
		# ABOVE THE CARDINALS, not across them. A friend due north puts their
		# chevron exactly where the N is - which is correct, and unreadable if
		# the two are drawn at the same height.
		_draw_chevron(x, 4.0, mark["color"])


## One small chevron pointing down at the strip, in the Deco ornament's
## geometry: half-width 5 against amplitude 5, drawn rather than textured.
func _draw_chevron(x: float, y: float, tint: Color) -> void:
	var half := 5.0
	var amp := 5.0
	draw_line(Vector2(x - half, y - amp * 0.5), Vector2(x, y + amp * 0.5), tint, 2.5)
	draw_line(Vector2(x, y + amp * 0.5), Vector2(x + half, y - amp * 0.5), tint, 2.5)
