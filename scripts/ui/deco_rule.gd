class_name DecoRule
extends Control

## The double rule: a heavy gold line over a gold hairline, with a square
## terminal at each end. The one ornament the poster allows itself, and it goes
## above and below a title and nowhere else.
##
## LOOK V2 STAGE 6 gave it an inset and terminals. A rule that runs edge to edge
## is a divider; a rule that stops short of the edge and ends in a square is a
## printed rule, and the square is what makes it read as deliberate rather than
## as the boundary of a container.

## How far each end stops short of the Control's edge.
const INSET := 8.0
## The square at each end: 5 x 5, centred on the heavy line.
const TERMINAL := 5.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.y < 9.0:
		custom_minimum_size.y = 9.0
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	if w <= INSET * 2.0 + TERMINAL * 2.0:
		# Too narrow for terminals; draw the plain rule rather than nothing.
		draw_rect(Rect2(0.0, 1.0, w, 3.0), Deco.GOLD)
		draw_rect(Rect2(0.0, 7.0, w, 1.0), Deco.GOLD)
		return
	var x0 := INSET
	var x1 := w - INSET
	draw_rect(Rect2(x0, 1.0, x1 - x0, 3.0), Deco.GOLD)
	draw_rect(Rect2(x0, 7.0, x1 - x0, 1.0), Deco.GOLD)
	# The terminals, centred on the heavy line at y = 2.5.
	var half := TERMINAL * 0.5
	draw_rect(Rect2(x0 - half, 2.5 - half, TERMINAL, TERMINAL), Deco.GOLD)
	draw_rect(Rect2(x1 - half, 2.5 - half, TERMINAL, TERMINAL), Deco.GOLD)
