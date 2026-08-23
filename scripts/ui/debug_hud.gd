class_name DebugHUD
extends CanvasLayer

## The instruments. Built before the thing being measured, on purpose.
##
## Terrain tuning is a loop: change a number, look at the skyline, change it
## again. Everything here exists to make that loop short - live numbers on the
## left, the knobs that move them on the right, and a reroll key so you can see
## twenty worlds in a minute instead of one.
##
## THE TIMING NUMBERS ARE NOT DECORATION. Chunk generate and mesh milliseconds
## are the budget this whole plan is spent against; without them on screen you
## are tuning terrain blind and will not notice you made it four times slower.
##
## The whole UI is built in code rather than in the .tscn. A debug panel is a
## list of (property, label, range) rows - as data that is twenty lines, as
## scene nodes it is four hundred, and every new knob means opening the editor.

signal reroll_requested(new_seed: int)
signal config_changed()
signal config_reload_requested()

## True while a panel wants the mouse pointer.
##
## The camera grabs the cursor on any click, which would make the tuning panel
## unusable - you would click a spinbox and the mouse would vanish. Cameras
## check this flag before capturing. It is static because the camera has no
## reference to the HUD and threading one through for a debug tool is not worth
## it.
static var ui_has_mouse := false

## property name, label, min, max, step. Wavelengths are shown as FREQUENCIES
## because that is what FastNoiseLite takes, but the label carries the
## wavelength in blocks, which is the number you can picture.
const TUNING_ROWS := [
	["continent_freq", "continent freq (1200 blk)", 0.0001, 0.01, 0.00001],
	["mountain_freq", "mountain freq (300 blk)", 0.0005, 0.02, 0.00001],
	["mountain_amp", "mountain height (blk)", 0.0, 300.0, 1.0],
	["hills_freq", "hills freq (60 blk)", 0.002, 0.1, 0.0001],
	["hills_amp", "hills height (blk)", 0.0, 60.0, 1.0],
	["detail_freq", "detail freq (12 blk)", 0.01, 0.5, 0.001],
	["detail_amp", "detail height (blk)", 0.0, 12.0, 0.5],
	["forest_max", "treeline altitude (blk)", 0.0, 320.0, 1.0],
	["tree_probability", "tree density", 0.0, 1.0, 0.01],
	["lake_level_offset", "lake level offset (blk)", 0.0, 10.0, 0.5],
	["fog_start_m", "fog start (m)", 0.0, 400.0, 5.0],
	["fog_end_m", "fog end (m)", 0.0, 600.0, 5.0],
	["day_seconds", "day length (s)", 10.0, 3600.0, 10.0],
]

var config: WorldgenConfig = null

## Filled in by Game. The HUD asks these for numbers; it never tells them
## anything, which is what keeps a debug tool from quietly becoming a system.
var world: Node = null
var player: Node3D = null

## Set false on clients in Stage 11 - a client that retunes its own terrain has
## silently left the host's world.
var tuning_editable := true

var _readout: Label
var _panel: PanelContainer
var _seed_edit: LineEdit
var _spins := {}          # property name -> SpinBox
var _suppress := false    # guards against our own set_value() re-emitting


func _ready() -> void:
	layer = 10
	_build_readout()
	_build_panel()
	set_process(true)


func setup(p_config: WorldgenConfig, p_world: Node, p_player: Node3D) -> void:
	config = p_config
	world = p_world
	player = p_player
	_refresh_panel()


func set_player(p_player: Node3D) -> void:
	player = p_player


# --- Live readout -----------------------------------------------------------

func _process(_delta: float) -> void:
	if not _readout.visible:
		return
	_readout.text = _compose_readout()


func _compose_readout() -> String:
	var lines := PackedStringArray()

	var seed_value := 0
	if world != null and "world_seed" in world:
		seed_value = world.world_seed
	lines.append("seed      %d" % seed_value)
	if config != null:
		lines.append("config    %s" % config.hash_key())

	if player != null:
		var p := player.global_position
		var bs: float = config.block_size if config != null else 1.0
		var alt_blocks := p.y / bs
		lines.append("pos       %.1f %.1f %.1f m" % [p.x, p.y, p.z])
		lines.append("altitude  %.0f blk / %.1f m" % [alt_blocks, p.y])
		lines.append("zone      %s" % _zone_name(alt_blocks))

	lines.append("fps       %d" % Engine.get_frames_per_second())

	if world != null:
		if world.has_method("loaded_chunk_count"):
			lines.append("chunks    %d loaded, %d queued" % [
				world.loaded_chunk_count(), world.queued_chunk_count()])
		if world.has_method("last_timings"):
			var t: Dictionary = world.last_timings()
			# The budget line. Watch this one.
			lines.append("gen/mesh  %.2f / %.2f ms per chunk" % [
				t.get("gen_ms", 0.0), t.get("mesh_ms", 0.0)])
			lines.append("worldgen  %d ms heightmap" % t.get("heightmap_ms", 0))

	lines.append("")
	lines.append("[F3] readout  [F4] tuning  [F5] reload cfg  [F7] reroll")
	return String("\n").join(lines)


## Stage 5 replaces this with the real jittered zone lookup. Until then it is
## the plain threshold, which is right everywhere except within a few blocks of
## a boundary.
func _zone_name(alt_blocks: float) -> String:
	if config == null:
		return "?"
	if alt_blocks < config.meadow_max:
		return "meadow"
	if alt_blocks < config.forest_max:
		return "forest"
	if alt_blocks < config.rock_max:
		return "rock"
	return "snow"


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F3:
			_readout.visible = not _readout.visible
			get_viewport().set_input_as_handled()
		KEY_F4:
			_set_panel_visible(not _panel.visible)
			get_viewport().set_input_as_handled()
		KEY_F5:
			config_reload_requested.emit()
			get_viewport().set_input_as_handled()
		KEY_F7:
			_do_reroll()
			get_viewport().set_input_as_handled()


func _set_panel_visible(on: bool) -> void:
	_panel.visible = on
	ui_has_mouse = on
	# A panel you cannot click is not a panel. Release the cursor while it is
	# open and hand it back to the camera when it closes.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _do_reroll() -> void:
	var text := _seed_edit.text.strip_edges()
	var new_seed: int
	if text.is_valid_int():
		# An explicitly typed seed is an instruction, not a suggestion - this
		# is how you go back to a world you liked.
		new_seed = text.to_int()
	else:
		new_seed = randi()
		_seed_edit.text = str(new_seed)
	reroll_requested.emit(new_seed)


# --- Construction -----------------------------------------------------------

func _build_readout() -> void:
	_readout = Label.new()
	_readout.position = Vector2(16, 44)
	# Monospace, so the numbers do not dance sideways as they change. A
	# proportional font makes a live readout genuinely harder to read.
	_readout.add_theme_font_override("font", ThemeDB.fallback_font)
	_readout.add_theme_font_size_override("font_size", 14)
	_readout.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_readout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_readout.add_theme_constant_override("outline_size", 4)
	add_child(_readout)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-360, 16)
	_panel.custom_minimum_size = Vector2(344, 0)
	_panel.visible = false
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "worldgen tuning"
	box.add_child(title)

	box.add_child(_seed_row())
	box.add_child(HSeparator.new())

	for row in TUNING_ROWS:
		box.add_child(_spin_row(row[0], row[1], row[2], row[3], row[4]))

	box.add_child(HSeparator.new())
	var save := Button.new()
	save.text = "save to user://worldgen.tres"
	save.pressed.connect(_on_save_pressed)
	box.add_child(save)

	var note := Label.new()
	note.text = "changes apply on reroll [F7]"
	note.add_theme_font_size_override("font_size", 11)
	box.add_child(note)


func _seed_row() -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "seed"
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)

	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "blank = random"
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Enter in the field does the same thing as the reroll key, because that is
	# what everyone tries first.
	_seed_edit.text_submitted.connect(func(_t): _do_reroll())
	row.add_child(_seed_edit)
	return row


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
	# Frequencies are five-decimal numbers; two decimals would round every one
	# of them to 0.00 and the panel would look broken.
	spin.custom_arrow_step = step
	if step < 0.01:
		spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_spin_changed.bind(prop))
	row.add_child(spin)

	_spins[prop] = spin
	return row


func _refresh_panel() -> void:
	if config == null:
		return
	_suppress = true
	for prop in _spins:
		var spin: SpinBox = _spins[prop]
		spin.value = float(config.get(prop))
		spin.editable = tuning_editable
	_suppress = false
	if _seed_edit != null and world != null and "world_seed" in world:
		_seed_edit.text = str(world.world_seed)


func _on_spin_changed(value: float, prop: String) -> void:
	if _suppress or config == null or not tuning_editable:
		return
	config.set(prop, value)
	config_changed.emit()


func _on_save_pressed() -> void:
	if config != null:
		config.save_to_user()


## Called after the config is reloaded or replaced underneath us.
func rebind(p_config: WorldgenConfig) -> void:
	config = p_config
	_refresh_panel()


## Stage 11: a live client must not retune its own terrain.
func set_tuning_editable(on: bool) -> void:
	tuning_editable = on
	_refresh_panel()
