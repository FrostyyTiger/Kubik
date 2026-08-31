class_name CreatureDebug
extends CanvasLayer

## The F10 panel: every creature number, tunable without leaving the world.
##
## THE OTHER HALF OF THE SAME DEAL `character_debug.gd` describes. This box has
## no display; every speed, every sense range and every flank angle in this run
## was chosen by reading a plan, not by watching an animal. So hard rule 5 of
## `docs/plans/creatures-v1-tech.md` says every one of them is reachable from
## here and listed in `docs/status/creatures-v1.md` with its starting value.
##
## THE NUMBERS THEMSELVES STAY `const`. `Species.TABLE` is the authored truth
## and this panel does not write to it - it writes to `Species._tuned`, a layer
## every accessor consults. So a slider cannot corrupt the table, "reset" is
## one call, and the numbers Marcel settles on are copied back into
## `species.gd` by hand as a decision rather than leaking in as a side effect.
##
## SEPARATE FROM DebugHUD's TUNING_ROWS, deliberately: the distance lane is
## appending there tonight. `_spin_row` is COPIED from `character_debug.gd`
## rather than imported, for the reason that file's docstring gives - reaching
## into another lane's file for a private helper is exactly the coupling that
## makes two parallel runs collide on merge.
##
## F4 is worldgen, F8 is characters, F10 is this.

const TOGGLE_KEY := KEY_F10

var _panel: PanelContainer
var _spins := {}
var _summary: Label
var _suppress := false

## Found rather than injected: `game.gd` is not this lane's to edit beyond the
## one banner block, so the panel goes looking for the server itself.
var _server: CreatureServer = null


func _ready() -> void:
	# Above DebugHUD's 10 and CharacterDebug's 11, so three panels do not fight.
	layer = 13
	_build_panel()
	_find_server.call_deferred()


func _find_server() -> void:
	_server = _find(get_tree().root)
	_refresh_summary()


func _find(node: Node) -> CreatureServer:
	if node is CreatureServer:
		return node
	for child in node.get_children():
		var found := _find(child)
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
	# unusable. The F4 and F8 panels do exactly the same thing.
	DebugHUD.ui_has_mouse = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		_refresh_panel()
		_refresh_summary()


# --- Construction -------------------------------------------------------------

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# TOP RIGHT, because F4 and F8 are both top left and a tuner you have to
	# close another tuner to read is a tuner nobody uses.
	_panel.position = Vector2(-392, 16)
	_panel.custom_minimum_size = Vector2(376, 0)
	_panel.visible = false
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(368, 620)
	_panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var title := Label.new()
	title.text = "creature tuning  [F10]"
	box.add_child(title)

	_summary = Label.new()
	_summary.text = "..."
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)

	box.add_child(HSeparator.new())
	for row in Species.TUNING_ROWS:
		box.add_child(_spin_row(row[0], row[1], row[2], row[3], row[4]))

	box.add_child(HSeparator.new())
	var reset := Button.new()
	reset.text = "reset to the table's own numbers"
	reset.pressed.connect(_on_reset_pressed)
	box.add_child(reset)

	var respawn := Button.new()
	respawn.text = "rebuild the pack at its den"
	respawn.pressed.connect(_on_respawn_pressed)
	box.add_child(respawn)

	var note := Label.new()
	note.text = "senses, speeds and flank apply on the next brain tick; territory " \
		+ "applies when the pack is rebuilt, because the A* grid is built from it."
	note.add_theme_font_size_override("font_size", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)


## DebugHUD's shape, copied. See the class docstring for why it is copied.
func _spin_row(key: String, label_text: String, lo: float, hi: float,
		step: float) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(196, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.custom_arrow_step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_spin_changed.bind(key))
	row.add_child(spin)

	_spins[key] = spin
	return row


# --- Behaviour ----------------------------------------------------------------

func _refresh_panel() -> void:
	_suppress = true
	for row in Species.TUNING_ROWS:
		var spin: SpinBox = _spins.get(row[0])
		if spin != null:
			spin.value = Species.tuned(row[0], row[5])
	_suppress = false


func _on_spin_changed(value: float, key: String) -> void:
	if _suppress:
		return
	Species.set_tuned(key, value)
	_refresh_summary()


func _on_reset_pressed() -> void:
	Species.clear_tuning()
	_refresh_panel()
	_refresh_summary()


## Territory is baked into the A* grid at build time, so changing it means
## rebuilding the pack rather than waiting for a tick. Honest about that in the
## note above rather than leaving a knob that appears to do nothing.
func _on_respawn_pressed() -> void:
	if _server == null or not _server.is_host():
		return
	_server.respawn_pack()
	_refresh_summary()


func _refresh_summary() -> void:
	if _summary == null:
		return
	if _server == null:
		_summary.text = "no creature server found - the panel controls nothing"
		return
	if not _server.is_host():
		_summary.text = "client: creatures decide on the host, so these do nothing here"
		return
	if _server.pack == null:
		_summary.text = "no pack yet"
		return
	_summary.text = "pack of %d at den %d  |  %d live, %d views  |  %d tuned" % [
		_server.pack.members.size(), _server.pack.den_id,
		_server.creatures.size(), _server.views.size(),
		Species._tuned.size()]
