class_name HudTuner
extends CanvasLayer

## The F9 panel: every number the field register was chosen by eye.
##
## HARD RULE 5 IS WHY THIS FILE EXISTS. This run chose a bar height, a strip
## span, a fade grace and fifteen other numbers on a box with no monitor, from
## screenshots. Every one of them is a guess, and a guess baked into a _draw()
## is a guess nobody can correct without a code change. So: they live in
## HudConfig, they are all reachable from here, and the status doc lists every
## one with its starting value.
##
## F9, and not F4. Decision 2: F4's rows write worldgen properties and its F5
## reload is a full world reroll, which is the wrong loop entirely for judging
## whether a bar is the right height - you want to move a number and see the
## same frame change, not regenerate the world. And worldgen_config.gd is the
## concurrently-running distance lane's highest-traffic file.
##
## LAYER 12, above DebugHUD's 10 and CharacterDebug's 11, so three open panels
## stack in a predictable order.
##
## _spin_row IS COPIED from character_debug.gd, which copied it from
## debug_hud.gd, and the reason is the same one written there: reaching into
## another panel for a private helper couples two files that different lanes
## edit. Three copies of twenty lines is cheaper than that coupling, and each
## copy is free to differ - this one has no int-typed properties to round.

const TOGGLE_KEY := KEY_F9

## Set by Game. The panel writes to this and calls back so the HUD relays out
## the same frame.
var hud: Hud = null

var _panel: PanelContainer
var _spins := {}
var _suppress := false


func _ready() -> void:
	layer = 12
	_build_panel()


func setup(p_hud: Hud) -> void:
	hud = p_hud
	_refresh_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == TOGGLE_KEY:
		_set_panel_visible(not _panel.visible)
		get_viewport().set_input_as_handled()


func _set_panel_visible(on: bool) -> void:
	_panel.visible = on
	# The owner set, not a boolean (Stage 2). This is the third panel that
	# wants the cursor and the exact case that made a set necessary.
	if on:
		UiMouse.claim(self)
		_refresh_panel()
	else:
		UiMouse.release(self)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	# Anchored rather than sized, for the reason Stage 1 gave the F8 panel: the
	# logical canvas is at least 1280x720 and may be taller, and a fixed height
	# is a dead strip at the bottom of one window and a clipped panel in
	# another. Right edge, inset from F4's so the two do not sit on top of each
	# other when both are open.
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -360
	_panel.offset_right = -16
	_panel.offset_top = 16
	_panel.offset_bottom = -16
	_panel.visible = false
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "hud tuning  [F9]"
	title.add_theme_font_override("font", Deco.font_of(&"TitleLabel"))
	title.add_theme_font_size_override("font_size", 20)
	title.uppercase = true
	box.add_child(title)

	var note := Label.new()
	note.text = "every value the field register chose by eye. changes apply at once."
	note.add_theme_font_size_override("font_size", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	box.add_child(HSeparator.new())

	for row in HudConfig.TUNING_ROWS:
		box.add_child(_spin_row(row[0], row[1], row[2], row[3], row[4]))

	box.add_child(HSeparator.new())
	var save := Button.new()
	save.text = "save to user://ui.tres"
	save.pressed.connect(_on_save_pressed)
	box.add_child(save)


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


func _refresh_panel() -> void:
	if hud == null or hud.config == null:
		return
	_suppress = true
	for prop in _spins:
		(_spins[prop] as SpinBox).value = float(hud.config.get(prop))
	_suppress = false


func _on_spin_changed(value: float, prop: String) -> void:
	if _suppress or hud == null or hud.config == null:
		return
	hud.config.set(prop, value)
	# THE SAME FRAME. A tuning panel whose changes need a reload is a list of
	# numbers, not a loop - and the whole reason this is not on F4 is that F4's
	# reload is a world reroll.
	hud.apply_config()


func _on_save_pressed() -> void:
	if hud != null and hud.config != null:
		hud.config.save_to_user()
