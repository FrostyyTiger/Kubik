class_name Hotbar
extends Control

## FIVE SLOTS, AND WHAT YOU HOLD IS WHICHEVER ONE IS ACTIVE.
##
## The Minecraft model, chosen on purpose (ui-v1.md, decision 2): the hand is
## the active hotbar slot - weapon, torch, campfire, tool alike - and the
## character sheet never has an "equipped weapon" box. The six sockets on the
## sheet are armour, worn, visible on the body, and nothing else.
##
## FIVE AND NOT NINE. Players never place raw voxel blocks (DESIGN.md), so this
## will never hold stacks of dirt; it holds a restricted palette of placeables
## plus tools and weapons. Five is honest for that, and a row of nine mostly
## empty squares would be screen furniture pretending to be a system.
##
## GOLD APPEARS HERE AND NOWHERE ELSE ON THE FIELD REGISTER (hard rule 4). The
## selected slot's frame is the poster's one accent; every other mark on the
## HUD is ink, paper, or a stat's own colour.

## THE SLOT TABLE. Facts as data, habit 1 - what a slot holds and whether the
## held thing can act are rows, not branches in a _draw().
##
## Items v1 (G) replaces this const with the real bag and deletes the slab.
## Until then slot 1 holds the debug slab tool, which is what makes
## select-and-use provable end to end BEFORE items exist: pressing 1 and
## clicking drives the same world.request_set_block() the G key used to, so the
## whole chain - selection, the use action, the one mutation path, the journal
## - is exercised by the thing a player would actually do.
const SLOTS := [
	{"label": "SLAB", "acts": true},
	{"label": "", "acts": false},
	{"label": "", "acts": false},
	{"label": "", "acts": false},
	{"label": "", "acts": false},
]

signal slot_used(index: int)

var config: HudConfig = null

## Which slot is in the hand. Zero-based; the keys are 1-5.
var selected := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Can the held thing do anything? The context dot asks this, and so does the
## use action - an empty hand clicks on nothing.
func active_acts() -> bool:
	return bool(SLOTS[selected].get("acts", false))


func select(index: int) -> void:
	var wrapped := posmod(index, SLOTS.size())
	if wrapped == selected:
		return
	selected = wrapped
	queue_redraw()


## Returns true if the event was ours, so the caller consumes it.
##
## THE KEYS ARE RAW PHYSICAL KEYCODES, not an InputMap action. Decision 3: the
## project has no [input] section and every binding in it is physical-key
## polling or an _unhandled_input match, so a new key follows the house style
## rather than starting a second convention for five bindings.
func handle_input(event: InputEvent, captured: bool) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var offset := int(event.physical_keycode) - int(KEY_1)
		if offset >= 0 and offset < SLOTS.size():
			select(offset)
			return true
		return false
	if event is InputEventMouseButton and event.pressed:
		# THE WHEEL ONLY WHILE CAPTURED. With the cursor free the wheel belongs
		# to whatever panel is open - a spinbox, a scroll container - and a
		# hotbar that stole it would make every panel in the game unusable.
		if not captured:
			return false
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				select(selected - 1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				select(selected + 1)
				return true
			MOUSE_BUTTON_LEFT:
				# An empty hand does nothing, and says so by having no dot.
				if not active_acts():
					return false
				slot_used.emit(selected)
				return true
	return false


func _draw() -> void:
	if config == null:
		return
	var side := config.slot_size
	var gap := config.slot_gap
	for i in SLOTS.size():
		var at := Rect2(Vector2(float(i) * (side + gap), 0.0), Vector2(side, side))
		_draw_slot(at, i == selected, SLOTS[i])


## One chamfered square, in the DecoPanel idiom: nested rectangles, ink then
## the accent then paper, each inset from the last. Drawn rather than a
## StyleBox because this is a Control that draws five of them and a
## PanelContainer each would be five nodes to say the same thing.
func _draw_slot(at: Rect2, is_selected: bool, slot: Dictionary) -> void:
	# The ground: paper at low alpha, so the world reads through an empty slot.
	draw_rect(at, Color(Deco.PAPER, 0.14))
	var edge: Color = Deco.GOLD if is_selected else Deco.INK
	var thickness := 2.0 if is_selected else 1.0
	draw_rect(at, edge, false, thickness)
	if is_selected:
		# The chamfer: a second, inset rule. Two lines apart is a printed
		# border; one line is a box.
		draw_rect(at.grow(-4.0), Color(Deco.GOLD, 0.55), false, 1.0)
	var label := String(slot.get("label", ""))
	if label.is_empty():
		return
	# A DRAWN GLYPH AND NOT A TEXTURE (hard rule 4). The label is the item's
	# name set small in the poster's face; Items v1 puts a real mark here and
	# this is the shape of the hole it goes in.
	var font := Deco.font_of(&"SectionLabel")
	var px := int(at.size.y * 0.28)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	draw_string(font, at.position + Vector2(
		(at.size.x - w) * 0.5, at.size.y * 0.5 + float(px) * 0.36),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
		Deco.PAPER if is_selected else Color(Deco.PAPER, 0.75))


## How wide five slots come out, so the HUD can centre the cluster on it.
func natural_width() -> float:
	if config == null:
		return 0.0
	return float(SLOTS.size()) * config.slot_size \
		+ float(SLOTS.size() - 1) * config.slot_gap
