class_name DecoRule
extends Control

## The double rule: a heavy gold line over a gold hairline. The one ornament
## the poster allows itself, and it goes above and below a title and nowhere
## else. Nine pixels tall; takes whatever width its container gives it.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.y < 9.0:
		custom_minimum_size.y = 9.0
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0.0, 1.0, w, 3.0), Deco.GOLD)
	draw_rect(Rect2(0.0, 7.0, w, 1.0), Deco.GOLD)
