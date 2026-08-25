class_name DecoPanel

## The stepped corner: three nested boxes, ink then gold then paper, each inset
## from the last and each with a smaller radius.
##
## Look v2 Stage 6. A poster's panel does not have one rounded corner - it steps
## in, the way the crown of a building steps in, and the step is the ornament.
## Three StyleBoxFlats rather than a drawn Control so it works anywhere a theme
## takes a panel: a PanelContainer, a Button, a popup.
##
## The numbers are the plan's: ink r14, gold r10 inset 5, paper r6 inset 10.
## They are radii and insets in pixels and they do not scale with the panel,
## which is correct - a printed border is a printed border whatever it frames.

const INK_RADIUS := 14
const GOLD_RADIUS := 10
const GOLD_INSET := 5
const PAPER_RADIUS := 6
const PAPER_INSET := 10


## The three boxes as one StyleBox, for `add_theme_stylebox_override("panel", ...)`.
##
## Godot has no "stack of boxes" StyleBox, so the nesting is done with the
## outer box's border: an ink box with a gold border and a paper fill reads as
## three steps as long as the radii differ, which is what the insets buy.
static func stepped() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Deco.PAPER
	box.set_corner_radius_all(PAPER_RADIUS)
	box.border_color = Deco.GOLD
	box.set_border_width_all(GOLD_INSET)
	box.set_expand_margin_all(0.0)
	box.set_content_margin_all(float(PAPER_INSET))
	# The ink step, drawn as a shadow with no offset: a hard ring outside the
	# gold one, at the larger radius.
	box.shadow_color = Deco.INK
	box.shadow_size = PAPER_INSET - GOLD_INSET
	box.shadow_offset = Vector2.ZERO
	return box


## The same three steps drawn by hand, for a Control that is not a panel.
##
## `at` is the outer rectangle. Used by the creation screen, where the stepped
## corner has to sit behind a grid that is not in a PanelContainer.
static func draw_stepped(on: CanvasItem, at: Rect2) -> void:
	on.draw_rect(at, Deco.INK)
	on.draw_rect(at.grow(-float(GOLD_INSET)), Deco.GOLD)
	on.draw_rect(at.grow(-float(PAPER_INSET)), Deco.PAPER)
