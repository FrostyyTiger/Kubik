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

## PAIRS of rays, a long one and a short one, so the burst has a rhythm rather
## than a frequency. Look v2 Stage 6: 24, up from 14 undifferentiated wedges.
const RAY_PAIRS := 24
## How far a long ray reaches, as a multiple of the window's larger dimension,
## and the short one as a fraction of the long.
const RAY_REACH := 1.4
const RAY_SHORT := 0.45
## A ray narrows to this fraction of its base width by the time it reaches its
## tip. A wedge of constant width is a stripe; a wedge that tapers is a ray.
const RAY_TAPER := 0.15

## Where the sun sits, as a fraction of the window. Just above the title's
## band, so the title sits across the disc and the rules bracket it.
const SUN_X := 0.5
## RAISED IN LOOK V2 STAGE 6, and the reason is that the plan asks for two
## things that cannot both be true. Its sunburst note says "paper disc with a
## 4 px gold ring; the title is ink on paper inside the ring"; its title-band
## note says "a full-width ink band carrying the title in paper caps". The band
## is the more specific instruction - it carries sizes, tracking and a colour
## for the subtitle - so the band won, and the disc moved up out from behind it
## to read as a sun RISING behind the title rather than as a sliver of gold
## nobody meant.
const SUN_Y := 0.055
const SUN_RADIUS := 62.0
## The gold ring round the paper disc. The disc was solid gold through look v1
## and swallowed the middle of the title; a ring holds the same shape and lets
## the type sit on paper, which is where type belongs.
const SUN_RING := 4.0

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


## THE TITLE BAND, in pixels, set by whoever owns the title.
##
## A full-width ink band with the double rule along its top edge, for the title
## to sit on in paper caps. It is set from the real Control rect rather than
## from a fraction of the window, because a band that misses the type it is
## meant to carry is worse than no band - and the type's position is the
## VBox's business, not this file's. Zero height means no band, which is what
## the creation screen wants.
var band_top := 0.0
var band_height := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Put the band behind `rect`, with `pad` of ink above and below it.
func set_title_band(rect: Rect2, pad := 14.0) -> void:
	band_top = rect.position.y - pad
	band_height = rect.size.y + pad * 2.0
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0.0, 0.0, w, h), Deco.PAPER)

	_draw_sunburst(w, h)
	_draw_title_band(w)
	_draw_range(RANGE_BACK, w, h, Deco.ALPINE_PALE)
	_draw_range(RANGE_MID, w, h, Deco.ALPINE)
	_draw_range(RANGE_FRONT, w, h, Deco.ALPINE_DEEP)

	# The ground: a band of ink with a gold hairline on top, which is the rule
	# the buttons stand on.
	draw_rect(Rect2(0.0, h * GROUND_Y, w, h * (1.0 - GROUND_Y)), Deco.INK)
	draw_rect(Rect2(0.0, h * GROUND_Y, w, 2.0), Deco.GOLD)


## TAPERED RAYS, LONG AND SHORT ALTERNATING, and a paper disc in a gold ring.
##
## Each ray is a 4-gon, not a triangle: it has a base at the disc and a tip
## narrowed to RAY_TAPER of that base, so it reads as a printed ray rather than
## as a slice of pie. Long and short alternate, which is what stops 48 rays
## from turning into a moire.
func _draw_sunburst(w: float, h: float) -> void:
	var centre := Vector2(w * SUN_X, h * SUN_Y)
	var long_reach := maxf(w, h) * RAY_REACH
	var step := TAU / float(RAY_PAIRS * 2)
	for i in RAY_PAIRS * 2:
		# Offset by half a wedge so straight up is the MIDDLE of a ray and the
		# burst is symmetric about the title rather than split by it.
		var mid := -PI * 0.5 + (float(i) + 0.5) * step
		var reach := long_reach * (1.0 if i % 2 == 0 else RAY_SHORT)
		var half := step * 0.5
		var base := SUN_RADIUS
		var a0 := mid - half
		var a1 := mid + half
		var t0 := mid - half * RAY_TAPER
		var t1 := mid + half * RAY_TAPER
		draw_colored_polygon(PackedVector2Array([
			centre + Vector2(cos(a0), sin(a0)) * base,
			centre + Vector2(cos(t0), sin(t0)) * reach,
			centre + Vector2(cos(t1), sin(t1)) * reach,
			centre + Vector2(cos(a1), sin(a1)) * base,
		]), Deco.PAPER_SHADE)
	draw_circle(centre, SUN_RADIUS, Deco.GOLD)
	draw_circle(centre, SUN_RADIUS - SUN_RING, Deco.PAPER)


## A full-width ink band with the double rule along its top edge.
func _draw_title_band(w: float) -> void:
	if band_height <= 0.0:
		return
	draw_rect(Rect2(0.0, band_top, w, band_height), Deco.INK)
	draw_rect(Rect2(0.0, band_top + 1.0, w, 3.0), Deco.GOLD)
	draw_rect(Rect2(0.0, band_top + 7.0, w, 1.0), Deco.GOLD)


## One stepped ridge as a filled polygon from its profile down to the bottom
## of the window. The next range in front covers whatever it overlaps.
func _draw_range(profile: Array, w: float, h: float, color: Color) -> void:
	var points := PackedVector2Array()
	for p in profile:
		points.push_back(Vector2(w * p[0], h * p[1]))
	points.push_back(Vector2(w, h))
	points.push_back(Vector2(0.0, h))
	draw_colored_polygon(points, color)
