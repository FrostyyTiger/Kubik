class_name PosterBackdrop
extends Control

## The back of the poster: paper, a sunburst, stepped mountains.
##
## DRAWN, NOT TEXTURED. Rule 2 of the direction says no textures, and a menu
## background is the one place it would have been easiest to cheat. Everything
## here is draw_polygon and draw_rect, which also means it fills any window
## size without stretching.
##
## THREE THINGS AND NO MORE. A sunburst behind the title, because the rayed
## sun is the single most Deco thing there is. A range of stepped mountains
## along the bottom in three values of one blue, because the game is the Alps.
## A ground band, so the buttons stand on something. A fourth element would be
## decoration; these three are the setting.

## Rays either side of straight up, so the burst is symmetric about the title.
const RAY_COUNT := 14

## Where the sun sits, as a fraction of the window. Just above the title's
## band, so the title sits across the disc and the rules bracket it.
const SUN_X := 0.5
const SUN_Y := 0.21
const SUN_RADIUS := 78.0

## Mountain profile: (x fraction, height fraction of the window) per vertex,
## ridge by ridge, back to front. Stepped on purpose - a Deco mountain is a
## ziggurat, not a cone - so every rise is a flat then a vertical.
const RANGE_BACK := [
	[0.00, 0.62], [0.06, 0.62], [0.06, 0.56], [0.13, 0.56], [0.13, 0.50],
	[0.20, 0.50], [0.20, 0.56], [0.27, 0.56], [0.27, 0.60], [0.36, 0.60],
	[0.36, 0.53], [0.44, 0.53], [0.44, 0.47], [0.50, 0.47], [0.50, 0.53],
	[0.58, 0.53], [0.58, 0.58], [0.66, 0.58], [0.66, 0.52], [0.74, 0.52],
	[0.74, 0.46], [0.80, 0.46], [0.80, 0.52], [0.87, 0.52], [0.87, 0.58],
	[0.94, 0.58], [0.94, 0.63], [1.00, 0.63],
]
const RANGE_MID := [
	[0.00, 0.72], [0.09, 0.72], [0.09, 0.66], [0.17, 0.66], [0.17, 0.61],
	[0.25, 0.61], [0.25, 0.67], [0.34, 0.67], [0.34, 0.72], [0.45, 0.72],
	[0.45, 0.65], [0.55, 0.65], [0.55, 0.70], [0.64, 0.70], [0.64, 0.63],
	[0.72, 0.63], [0.72, 0.68], [0.83, 0.68], [0.83, 0.73], [0.92, 0.73],
	[0.92, 0.69], [1.00, 0.69],
]
const RANGE_FRONT := [
	[0.00, 0.80], [0.12, 0.80], [0.12, 0.76], [0.22, 0.76], [0.22, 0.81],
	[0.38, 0.81], [0.38, 0.77], [0.50, 0.77], [0.50, 0.82], [0.63, 0.82],
	[0.63, 0.78], [0.77, 0.78], [0.77, 0.82], [0.90, 0.82], [0.90, 0.79],
	[1.00, 0.79],
]

## Where the ground band starts, as a fraction of the window height.
const GROUND_Y := 0.86


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0.0, 0.0, w, h), Deco.PAPER)

	_draw_sunburst(w, h)
	_draw_range(RANGE_BACK, w, h, Deco.ALPINE_PALE)
	_draw_range(RANGE_MID, w, h, Deco.ALPINE)
	_draw_range(RANGE_FRONT, w, h, Deco.ALPINE_DEEP)

	# The ground: a band of ink with a gold hairline on top, which is the rule
	# the buttons stand on.
	draw_rect(Rect2(0.0, h * GROUND_Y, w, h * (1.0 - GROUND_Y)), Deco.INK)
	draw_rect(Rect2(0.0, h * GROUND_Y, w, 2.0), Deco.GOLD)


## Alternating wedges of paper and shaded paper radiating from the sun, and
## the disc itself in gold. Wedges run to well past the window edge so no
## corner shows their end.
func _draw_sunburst(w: float, h: float) -> void:
	var centre := Vector2(w * SUN_X, h * SUN_Y)
	var reach := maxf(w, h) * 1.5
	var step := PI / float(RAY_COUNT)
	for i in RAY_COUNT * 2:
		if i % 2 == 1:
			continue
		# Offset by half a wedge so straight up is the MIDDLE of a wedge and
		# the burst is symmetric about the title rather than split by it.
		var a0 := -PI + (float(i) + 0.5) * step
		var a1 := a0 + step
		var points := PackedVector2Array([
			centre,
			centre + Vector2(cos(a0), sin(a0)) * reach,
			centre + Vector2(cos(a1), sin(a1)) * reach,
		])
		draw_colored_polygon(points, Deco.PAPER_SHADE)
	draw_circle(centre, SUN_RADIUS, Deco.GOLD)


## One stepped ridge as a filled polygon from its profile down to the bottom
## of the window. The next range in front covers whatever it overlaps.
func _draw_range(profile: Array, w: float, h: float, color: Color) -> void:
	var points := PackedVector2Array()
	for p in profile:
		points.push_back(Vector2(w * p[0], h * p[1]))
	points.push_back(Vector2(w, h))
	points.push_back(Vector2(0.0, h))
	draw_colored_polygon(points, color)
