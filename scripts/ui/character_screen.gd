class_name CharacterScreen
extends CanvasLayer

## THE SHEET: A PAPER-DOLL YOU READ, NOT A FORM YOU FILL.
##
## One screen, one key (C). The live turntable on the left, the six armour
## sockets and the five skills on the right. NOTHING ON IT IS CLICKABLE EXCEPT
## CLOSE, and that is a design rule rather than an unfinished feature
## (ui-v1.md, decision 6): the moment a sheet lets you spend something, it has
## become the skill tree this design rejected. Hard rule 9.
##
## THE POSTER REGISTER, not the field register. The HUD is an instrument panel
## and disappears when you are safe; this is a printed thing you visit, so it
## gets the full Deco kit - the stepped frame, the display face, an ink ground.
##
## LAYER 5: above the game, UNDER both debug panels (10, 11) and the F9 tuner
## (12). A debug panel you cannot see because the sheet is over it would be a
## tool made useless by a screen, and the tools win.
##
## ESC CLOSES THE SHEET AND MUST NEVER REACH THE LEAVE-SESSION HANDLER.
## Hard rule 10, and the reason it is a rule: `ui_cancel` unconsumed walks up
## to Game._unhandled_input, which calls Net.leave() and changes scene. One
## missed consume between a player pressing Escape on their inventory and being
## dropped out of their friend's world. This file consumes it in _input(),
## which runs before _unhandled_input anywhere, and only while open.

const TOGGLE_KEY := KEY_C

var _root: Control = null
var _preview: CharacterPreview = null
var _name_label: Label = null
var _race_label: Label = null

## The player whose sheet this is. Injected by the HUD, because this layer has
## no business searching the tree for a body.
var _player: Node3D = null

## The field register, told to stand down while this screen is open. See
## Hud.set_suppressed.
var _hud: Node = null

## Every label the sheet writes, so the shot driver can print what it renders
## and the acceptance test can COUNT six sockets and five skills rather than
## trying to read them out of a PNG. OCR is not available on this box, and
## "verify by construction" is the plan's own answer to that.
var _socket_labels := []
var _skill_labels := []


func _ready() -> void:
	layer = 5
	_build()
	visible = false


func setup(player: Node3D, hud: Node = null) -> void:
	_player = player
	_hud = hud


func is_open() -> bool:
	return visible


func toggle() -> void:
	set_open(not visible)


func set_open(on: bool) -> void:
	if on == visible:
		return
	visible = on
	if _hud != null and _hud.has_method("set_suppressed"):
		_hud.set_suppressed(on)
	if on:
		UiMouse.claim(self)
		_refresh()
	else:
		UiMouse.release(self)


# --- Input --------------------------------------------------------------------

## _input, not _unhandled_input, and ONLY while open.
##
## See the class docstring: an unconsumed ui_cancel leaves the session. Running
## before every _unhandled_input in the tree is the only placement where that
## cannot happen by accident, and the `visible` guard is what keeps this layer
## from eating Escape for the rest of the game.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == TOGGLE_KEY:
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible and _preview != null:
		_preview.spin(delta)


# --- Construction -------------------------------------------------------------

func _build() -> void:
	set_process(true)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# THE INK GROUND. A poster screen sits on paper; this one sits on ink,
	# because it is opened OVER a lit world and a paper ground would be a white
	# flash every time somebody checked their gear.
	var ground := ColorRect.new()
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.color = Color(Deco.INK, 0.94)
	_root.add_child(ground)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_root.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	margin.add_child(columns)

	# The preview, mounted like a print: the stepped corner behind it.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", DecoPanel.stepped())
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview = CharacterPreview.new()
	frame.add_child(_preview)
	columns.add_child(frame)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)

	right.add_child(Deco.rule())
	_name_label = Deco.label("", &"AccentLabel", true)
	_name_label.add_theme_font_size_override("font_size", 38)
	right.add_child(_name_label)
	_race_label = Deco.label("", &"SectionLabel")
	right.add_child(_race_label)
	right.add_child(Deco.rule())

	right.add_child(_heading("Worn"))
	right.add_child(_sockets())
	right.add_child(_heading("Skills"))
	right.add_child(_skills())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	# THE ONLY INTERACTIVE THING ON THE SCREEN. Hard rule 9.
	var close := Button.new()
	close.text = "CLOSE  [C]"
	close.custom_minimum_size = Vector2(180, 44)
	# SHRINK, not fill. A button that spans the whole column reads as the most
	# important thing on the page, and the most important thing on this page is
	# the character.
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): set_open(false))
	right.add_child(close)


func _heading(text: String) -> Control:
	var label := Deco.label(text, &"SectionLabel", true)
	label.add_theme_color_override("font_color", Deco.GOLD)
	return label


## THE SIX ARMOUR SOCKETS, AS LABELLED EMPTY FRAMES.
##
## They are armour and only armour - there is no weapon slot on this screen and
## there never will be one (ui-v1.md, decision 2: the hand is the active hotbar
## slot). Every tier is 0 in a real session today, because there are no items;
## the sockets render their label and an em-dash, and Items v1 (G) fills them
## on a render path - Armour.apply_armour - that already works the day it does.
func _sockets() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	for i in CharacterDef.ARMOUR_SLOTS:
		var slot := _SocketFrame.new()
		slot.slot_name = String(CharacterDef.ARMOUR_SLOT_NAMES[i]).capitalize()
		slot.custom_minimum_size = Vector2(190, 40)
		grid.add_child(slot)
		_socket_labels.append(slot.slot_name)
	return grid


## THE FIVE SKILLS, READ-ONLY, WITH A DASH WHERE A LEVEL WILL GO.
func _skills() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for name in Skills.NAMES:
		var row := HBoxContainer.new()
		var label := Deco.label(name, &"SectionLabel")
		label.custom_minimum_size = Vector2(150, 0)
		row.add_child(label)
		var level := Deco.label(Skills.NO_LEVEL, &"StatusLabel")
		level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(level)
		box.add_child(row)
		_skill_labels.append(name)
	return box


# --- Refresh ------------------------------------------------------------------

## Built from the LIVE player, not from the saved file.
##
## `Player/View.def` is the runtime truth: it is what the F8 panel has been
## cycling and what everybody else on the wire has been sent, and a sheet that
## showed the file on disk would disagree with the body standing in the world.
func _refresh() -> void:
	if _player == null:
		return
	var view := _player.get_node_or_null("View") as CharacterView
	if view == null or view.def == null:
		return
	_preview.build(view.def)
	var who := String(view.def.name_text).strip_edges()
	_name_label.text = who if not who.is_empty() else "unnamed"
	_race_label.text = "%s %s" % [
		Races.BUILD_NAMES[view.def.build], Races.name_of(view.def.race)]


## Stop the turntable at a known angle, for a comparable shot.
func pin_preview(radians: float) -> void:
	if _preview != null:
		_preview.set_spinning(false)
		_preview.set_angle(radians)


## What this screen renders, as text. The acceptance test COUNTS six sockets
## and five skills off this rather than reading a PNG - there is no OCR on this
## box, and the plan's answer to that is to verify by construction.
func label_dump() -> String:
	return "sheet: %d sockets %s | %d skills %s | name \"%s\" | race \"%s\"" % [
		_socket_labels.size(), _socket_labels,
		_skill_labels.size(), _skill_labels,
		_name_label.text, _race_label.text]


## One labelled empty socket: a chamfered frame, the slot's name, and an
## em-dash where an item's name will go. Drawn in the DecoPanel idiom, like the
## hotbar's slots - no textures anywhere on this screen either.
class _SocketFrame extends Control:
	var slot_name := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var at := Rect2(Vector2.ZERO, size)
		draw_rect(at, Color(Deco.PAPER, 0.06))
		draw_rect(at, Color(Deco.PAPER, 0.35), false, 1.0)
		var font := Deco.font_of(&"SectionLabel")
		var px := 13
		draw_string(font, Vector2(10.0, size.y * 0.5 + float(px) * 0.36),
			slot_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Deco.PAPER)
		var dash := Skills.NO_LEVEL
		var w := font.get_string_size(dash, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, px).x
		draw_string(font, Vector2(size.x - 10.0 - w,
			size.y * 0.5 + float(px) * 0.36), dash,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Deco.INK_PALE)
