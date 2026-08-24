class_name CharacterDebug
extends CanvasLayer

## The F8 panel: every character knob, and a way to cycle through every
## character, without leaving the world.
##
## THIS PANEL IS THE OTHER HALF OF A DEAL. This box has no display - Godot
## falls back to OpenGL Compatibility on llvmpipe under Xvfb, and Marcel runs
## Forward+ on an RTX 5080 - so every amplitude and every colour in this run
## was chosen on the wrong renderer. The plan clears that, on condition that
## nothing chosen by eye is ever hardcoded. So every value in CharacterConfig
## is reachable from here, and the status doc lists all of them under "Tuned
## blind - re-check these first".
##
## Built in code rather than in the .tscn for the same reason DebugHUD is: a
## panel is a list of (property, label, range) rows, which is twenty lines as
## data and four hundred as scene nodes, and every new knob would otherwise
## mean opening an editor this machine does not have.
##
## SEPARATE FROM DebugHUD, and its `_spin_row` is COPIED rather than imported.
## debug_hud.gd is on this branch's never-touch list; reaching into it for a
## private helper would couple this file to a file the branch may not edit,
## which is exactly the coupling that makes two parallel runs collide on merge.

## F4 is the worldgen panel and F8 is this one. Deliberately not adjacent: they
## are two different jobs and hitting the wrong one mid-tune is annoying.
const TOGGLE_KEY := KEY_F8

var config: CharacterConfig = null

## The local player's view, found rather than injected - game.gd belongs to
## Stage 6 and may not be edited for a debug panel.
var view: CharacterView = null

var _panel: PanelContainer
var _spins := {}
var _suppress := false
var _summary: Label


func _ready() -> void:
	layer = 11  # above DebugHUD's 10, so the two panels do not fight
	config = CharacterConfig.load_or_default()
	_build_panel()
	_find_view.call_deferred()


## The local player's CharacterView, wherever it is.
##
## Deferred and re-tried, because this layer's _ready runs before the player
## has necessarily built its view, and a panel that silently controls nothing
## is worse than one that says so.
func _find_view() -> void:
	var player := _find_player(get_tree().root)
	if player == null:
		_summary.text = "no local player found - the panel controls nothing"
		return
	view = player.get_node_or_null("View") as CharacterView
	if view == null:
		_summary.text = "the local player has no View node"
		return
	_refresh_summary()


func _find_player(node: Node) -> Node:
	if node is Player:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == TOGGLE_KEY:
		_set_panel_visible(not _panel.visible)
		get_viewport().set_input_as_handled()


func _set_panel_visible(on: bool) -> void:
	_panel.visible = on
	# WITHOUT THIS THE FIRST CLICK RECAPTURES THE MOUSE and the panel is
	# unusable. Player._unhandled_input checks this flag before grabbing the
	# cursor back; the F4 panel does exactly the same thing.
	DebugHUD.ui_has_mouse = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		_refresh_panel()
		_refresh_summary()


# --- Construction -------------------------------------------------------------

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(360, 0)
	_panel.visible = false
	add_child(_panel)

	var scroll := ScrollContainer.new()
	# Twenty-seven knobs plus the cycling buttons is taller than a 720 line
	# window, and a panel whose bottom half is off screen is a panel whose
	# bottom half does not exist.
	scroll.custom_minimum_size = Vector2(352, 640)
	_panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var title := Label.new()
	title.text = "character tuning  [F8]"
	box.add_child(title)

	_summary = Label.new()
	_summary.text = "..."
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)

	box.add_child(HSeparator.new())
	var who := Label.new()
	who.text = "cycle the local character"
	who.add_theme_font_size_override("font_size", 11)
	box.add_child(who)
	for row in CYCLE_BUTTONS:
		box.add_child(_cycle_row(row[0], row[1]))

	box.add_child(HSeparator.new())
	for row in CharacterConfig.TUNING_ROWS:
		box.add_child(_spin_row(row[0], row[1], row[2], row[3], row[4]))

	box.add_child(HSeparator.new())
	var save := Button.new()
	save.text = "save to user://character_tuning.tres"
	save.pressed.connect(_on_save_pressed)
	box.add_child(save)

	var note := Label.new()
	note.text = "animation knobs apply at once; AO applies on the next rebuild"
	note.add_theme_font_size_override("font_size", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)


## The def fields that can be stepped, and the label for each. Everything the
## creation screen will offer, so the screen can be judged against something
## that already works.
const CYCLE_BUTTONS := [
	["race", "race"],
	["build", "build (human only)"],
	["skin", "skin"],
	["hair_color", "hair colour"],
	["eyes", "eyes"],
	["hair", "hair"],
	["beard", "beard"],
]


func _cycle_row(field: String, label_text: String) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(160, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var back := Button.new()
	back.text = "<"
	back.pressed.connect(_cycle.bind(field, -1))
	row.add_child(back)

	var fwd := Button.new()
	fwd.text = ">"
	fwd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fwd.pressed.connect(_cycle.bind(field, 1))
	row.add_child(fwd)
	return row


## DebugHUD's shape, copied. See the class docstring for why it is copied.
func _spin_row(prop: String, label_text: String, lo: float, hi: float, step: float) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.custom_arrow_step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_spin_changed.bind(prop))
	row.add_child(spin)

	_spins[prop] = spin
	return row


# --- Behaviour ----------------------------------------------------------------

func _refresh_panel() -> void:
	if config == null:
		return
	_suppress = true
	for prop in _spins:
		(_spins[prop] as SpinBox).value = float(config.get(prop))
	_suppress = false


func _on_spin_changed(value: float, prop: String) -> void:
	if _suppress or config == null:
		return
	config.set(prop, value)
	# The view holds its own CharacterConfig, loaded at build time. Handing it
	# this one keeps the two from drifting apart while a knob is being dragged;
	# ao_strength is baked into the mesh and so needs the rebuild the note in
	# the panel promises.
	if view != null and view.animator != null:
		view.animator.config = config


func _on_save_pressed() -> void:
	if config != null:
		config.save_to_user()


## Step one field of the local character's def and rebuild the view.
##
## THIS IS THE CREATION SCREEN, MINUS THE SCREEN. Everything Stage 12 will
## offer as swatches and arrows is here as seven rows of buttons, which means
## the whole appearance system can be exercised in the world tonight rather
## than waiting for a UI - and if the screen does not get finished, this and
## the CLI flags are the fallback the plan asks for.
func _cycle(field: String, step: int) -> void:
	if view == null or view.def == null:
		return
	var def := view.def.duplicate_def()
	var count := _option_count(def, field)
	if count <= 1:
		_summary.text = "%s has only one option for a %s" % [
			Races.name_of(def.race), field]
		return
	def.set(field, posmod(int(def.get(field)) + step, count))
	def.validate()
	view.build(def)
	_refresh_summary()


## How many values this field can take FOR THIS DEF's race. The counts are
## per-race - the dwarf has three beards and no "none", the elf has none at
## all - so this has to be asked of the def and not of a constant.
func _option_count(def: CharacterDef, field: String) -> int:
	match field:
		"race":
			return Races.RACE_COUNT
		"build":
			return Races.BUILD_COUNT if Races.has_lean(def.race) else 1
		"skin":
			return Races.skin_count(def.race)
		"hair_color":
			return Races.hair_color_count(def.race)
		"eyes":
			return Races.eye_count(def.race)
		"hair":
			return Races.hair_count(def.race)
		"beard":
			return maxi(Races.beard_count(def.race), 1)
	return 1


func _refresh_summary() -> void:
	if view == null or view.def == null:
		return
	var def := view.def
	_summary.text = "%s | skin %d hair %d eyes %d | hair %d beard %d | %d tris" % [
		def.describe(), def.skin, def.hair_color, def.eyes,
		def.hair, def.beard, view.triangle_count()]
