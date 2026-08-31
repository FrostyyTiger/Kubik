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
	["share_shore", "zone share: shore", 0.0, 1.0, 0.01],
	["share_meadow", "zone share: meadow", 0.0, 1.0, 0.01],
	["share_forest", "zone share: forest", 0.0, 1.0, 0.01],
	["share_alpine", "zone share: alpine", 0.0, 1.0, 0.01],
	["share_heath", "zone share: heath", 0.0, 1.0, 0.01],
	["share_rock", "zone share: rock", 0.0, 1.0, 0.01],
	["share_snow", "zone share: snow", 0.0, 1.0, 0.01],
	["tree_density_scale", "tree density x", 0.0, 3.0, 0.05],
	["tree_base_forest", "forest peak p", 0.0, 1.0, 0.01],
	["grove_share", "grove share", 0.0, 1.0, 0.01],
	["glade_share", "glade share", 0.0, 0.5, 0.01],
	["tree_max_slope_deg", "tree max slope", 0.0, 90.0, 1.0],
	["tree_size_scale", "tree size x", 0.1, 3.0, 0.05],
	["lake_level_offset", "lake level offset (blk)", 0.0, 10.0, 0.5],
	["lake_max_depth", "lake max depth (blk)", 0.0, 60.0, 1.0],
	["day_seconds", "day length (s)", 10.0, 3600.0, 10.0],
]

## The same, for knobs that are LOCAL to this machine - see
## WorldgenConfig.LOCAL_PROPERTIES. Kept as a second list rather than merged in
## because the two halves obey different rules: the shape knobs above are
## read-only on a client, and these are not.
##
## fog_start_m and fog_end_m are deliberately absent now. They are owned by the
## view_distance preset, and a spinbox that silently loses its value on the
## next load is worse than no spinbox. Set view distance to -1 to hand-tune
## them in the .tres.
const LOCAL_TUNING_ROWS := [
	["view_distance", "view distance (-1..3)", -1.0, 3.0, 1.0],
	["ao_strength", "baked AO strength", 0.0, 1.0, 0.05],
	["msaa_level", "MSAA (0 off, 3 = 8x)", 0.0, 3.0, 1.0],
	["color_jitter_value", "tint: brightness", 0.0, 0.3, 0.01],
	["color_jitter_hue", "tint: hue", 0.0, 0.2, 0.005],
	["color_jitter_blocks", "tint: cell (blk)", 1.0, 64.0, 1.0],
	["slope_tint", "tint: steep faces", 0.0, 0.5, 0.01],
	["aspect_tint", "tint: sun aspect", 0.0, 0.3, 0.01],
	["grain_amount", "poster: grain", 0.0, 0.15, 0.005],
	["grain_hue", "poster: grain hue", 0.0, 0.08, 0.005],
	["grain_sparse", "poster: grain sparse", 0.0, 0.5, 0.05],
	["contact_band", "poster: contact band", 0.5, 1.0, 0.01],
	["fog_bands", "poster: fog bands", 1.0, 64.0, 1.0],
	["sky_bands", "poster: sky bands", 1.0, 16.0, 1.0],
	["cloud_cover", "poster: cloud cover", 0.0, 1.0, 0.05],
	["far_band_m", "poster: far band (m)", 5.0, 200.0, 5.0],
	["far_band_step", "poster: far band step", 0.0, 0.3, 0.01],
	["far_normal_m", "poster: far normal (m)", 4.0, 256.0, 8.0],
	["far_zone_cell_m", "poster: far zone cell (m)", 0.0, 128.0, 4.0],
	["flora_radius_m", "flora radius (m)", 0.0, 160.0, 8.0],
	["flora_far_m", "flora far ring (m)", 0.0, 320.0, 8.0],
	["flora_far_fraction", "flora far density", 0.0, 1.0, 0.05],
	["flora_draw_fraction", "flora drawn", 0.0, 1.0, 0.05],
	["far_tree_m", "far trees (m)", 0.0, 600.0, 20.0],
	["wind_strength", "wind", 0.0, 3.0, 0.1],
	["night_life", "night life", 0.0, 2.0, 0.1],
	# DISTANCE V1, appended at the end of the table. Hard rule 12: every
	# starting value in the plan is reachable from F4.
	["far_level_ref_m", "distance: level ref (m)", 25.0, 400.0, 5.0],
	["far_filter_bias", "distance: filter bias", 0.0, 3.0, 0.1],
	["far_peak_gain", "distance: peak gain", 0.0, 1.0, 0.05],
	["far_zone_cell_ratio", "distance: zone cell x d", 0.0, 0.2, 0.01],
	["far_tree_tint", "distance: far tree tint", 0.0, 1.0, 0.05],
	# DISTANCE V2, appended after distance v1's block. `far terrace` is the one
	# this epic is judged by: 0 is the smooth far mesh f23c3f0 drew, 1 is the
	# far country made of blocks. It redraws the far mesh and the impostor ring
	# WITHOUT a reroll - see FarField.apply_far_knobs(), which is what the one
	# appended line in game.gd calls.
	["far_terrace", "distance: far terrace", 0.0, 1.0, 0.05],
	# The top of this range is 1.5, not 1.0, because the useful direction may be
	# UP: a riser above 1.0 LIFTS an away-facing slope off the shade band, which
	# is what the black crush in the treeline band wants. See the status doc.
	["far_riser_shade", "distance: riser shade", 0.0, 1.5, 0.05],
	["far_riser_lift", "distance: riser lift (away)", 1.0, 2.5, 0.05],
	# DISTANCE V3, appended after distance v2's block. Every row here redraws
	# the far country in place - no reroll, no chunk rebuilt, the player
	# standing still - which is the property the whole epic is judged by.
	["far_vote", "distance: far vote (0/1)", 0.0, 1.0, 1.0],
	["far_grain", "distance: far grain", 0.0, 0.2, 0.005],
]

var config: WorldgenConfig = null

## Filled in by Game. The HUD asks these for numbers; it never tells them
## anything, which is what keeps a debug tool from quietly becoming a system.
var world: Node = null

## Set by Game. Bodies are not World's - see body_field.gd - so the readout has
## to be handed them separately.
var body_field: Node = null
var player: Node3D = null
var sky: SkyCycle = null

## The impostor ring. A sibling of World in the game scene, so it is handed in
## separately rather than reached for through it.
var far_trees: Node = null

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


func set_far_trees(p_far_trees: Node) -> void:
	far_trees = p_far_trees


func setup(p_config: WorldgenConfig, p_world: Node, p_player: Node3D,
		p_sky: SkyCycle = null) -> void:
	config = p_config
	world = p_world
	player = p_player
	sky = p_sky
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
	if sky != null:
		# Shown as a clock because "0.63" tells you nothing about whether the
		# sun should be up.
		var minutes := int(sky.time_of_day * 24.0 * 60.0)
		lines.append("time      %02d:%02d" % [minutes / 60, minutes % 60])

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
			# WORLD FEEL V1 STAGE 0. The live half: what is out at the pool
			# right now, what the last crossing cost, and the worst frame in
			# the last two seconds. The averages above say whether the world
			# arrived; these say whether it is keeping up.
			lines.append("stream    %d columns in flight, %d chunks built" % [
				t.get("columns_in_flight", 0), t.get("built", 0)])
			lines.append("columns   %d built, %.2f ms each on workers, %.1f chunks each" % [
				t.get("columns_built", 0), t.get("ms_per_column", 0.0),
				t.get("chunks_per_column", 0.0)])
			lines.append("crossing  %d freed, %.1f ms refresh, worst frame %.1f ms" % [
				t.get("freed_last_crossing", 0), t.get("refresh_ms", 0.0),
				t.get("max_frame_ms", 0.0)])
			if world.has_method("loaded_frontier"):
				var f: PackedInt32Array = world.loaded_frontier()
				if not f.is_empty():
					var lo := f[0]
					var hi := f[0]
					for v in f:
						lo = mini(lo, v)
						hi = maxi(hi, v)
					lines.append("frontier  %d-%d chunks over 16 sectors" % [lo, hi])
			if t.get("cached_chunks", 0) > 0:
				lines.append("cache     %d chunks" % t.get("cached_chunks", 0))
		if world.has_method("far_field_vertices"):
			lines.append("far field %d verts" % world.far_field_vertices())
		if world.has_method("flora_stats"):
			var f: Dictionary = world.flora_stats()
			lines.append("flora     %d inst, %.2f M tris, %d cols, %d pending, %d cached" % [
				f["instances"], f["triangles"], f["columns"], f["pending"], f.get("cached", 0)])
			lines.append("flora     %.2f ms per column on workers, %d built" % [
				f.get("ms_per_column", 0.0), f.get("built", 0)])
	if far_trees != null and far_trees.has_method("stats"):
		var t: Dictionary = far_trees.stats()
		lines.append("far trees %d impostors, %d ms rebuild" % [
			t.get("impostors", 0), t.get("rebuild_ms", 0)])
		if world.has_method("lake_count"):
			lines.append("lakes     %d" % world.lake_count())

	# PHYSICS, world feel v1 Stage 9 - AND THESE READ ZERO UNDER JOLT.
	#
	# Stage 9 added them to answer whether a disabled collider leaves the
	# broadphase, and deferred the answer to Stage 11 on the grounds that
	# get_process_info() counts only DYNAMIC objects and there were none.
	# There are now, and it still reads 0, 0, 0 - with five bodies loaded, with
	# one of them rolling 95 m down a mountain, and with the world's static
	# colliders in every state. Jolt does not implement these counters; they
	# are a Godot Physics readout that the engine switch silently emptied.
	#
	# Left in place and labelled rather than removed, because they are correct
	# on the other engine and because a blank line here would invite somebody
	# to add them back. The number to watch under Jolt is the `bodies` line
	# below. The broadphase question is answered there instead: a parked
	# column's bodies are FREED, not disabled, so there is nothing left in the
	# broadphase to ask about.
	lines.append("physics   %d active, %d pairs, %d islands  (Jolt: always 0)" % [
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS),
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS),
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ISLAND_COUNT)])
	# BODIES, world feel v1 Stage 11. `awake` is the one to watch: a loaded
	# world is nearly all sleeping rocks, which cost a broadphase entry and no
	# solver time at all, and `moved` is the only part of them that is world
	# state rather than a function of the seed.
	if body_field != null:
		lines.append("bodies    %d loaded, %d awake, %d rocking, %d ever moved" % [
			body_field.count(), body_field.awake_count(),
			body_field.rocking_count(), body_field.moved_count()])
		# THE STAGE 12 CONSTANTS, all of them, all starting values (hard rule
		# 11). push/hold is the co-op rule stated as a ratio: 600 moves a 400
		# and not a 1000, and two of them move anything here.
		lines.append("push      %.0f N each, holds %.0f / %.0f, accel %.0f, decel %.0f, air %.2f" % [
			Locomotion.PUSH_FORCE_N,
			BodyTable.hold_of(BodyTable.BOULDER_M),
			BodyTable.hold_of(BodyTable.BOULDER_L),
			Locomotion.ACCEL, Locomotion.DECEL, Locomotion.AIR_CONTROL])
		lines.append("slide     over %.0f deg on loose ground, factor %.2f, max %.0f m/s" % [
			Locomotion.SLIDE_ANGLE_DEG, Locomotion.SLIDE_FACTOR,
			Locomotion.SLIDE_MAX])

	# THE FAR MESH'S OWN COST, distance v1 Stage 0, APPENDED rather than folded
	# into the "far field %d verts" line above - this epic shares three files
	# with a character redesign running in parallel and its rule for all three
	# is append-only. Reached through the node rather than through a World
	# accessor for the same reason: World is not on this lane's file list.
	#
	# build is the job's own time; wall includes waiting for a pool that runs
	# one GDScript task at a time. Stages 1-4 move the first; only the second
	# is what the player feels.
	var far_field: Node = world.get_node_or_null("FarField") if world != null else null
	if far_field != null and far_field.has_method("stats"):
		var ff: Dictionary = far_field.stats()
		lines.append("far mesh  %d verts, %d ms build, %d ms wall, %d rebuilds" % [
			ff.get("vertices", 0), ff.get("build_ms", 0),
			ff.get("wall_ms", 0), ff.get("rebuilds", 0)])

	lines.append("")
	lines.append("[F3] readout  [F4] tuning  [F5] reload cfg  [F7] reroll")
	return String("\n").join(lines)


## The real zone, jitter and all, at the player's own position - so the readout
## agrees with the ground they are standing on rather than with a global
## threshold the ground does not obey.
func _zone_name(_alt_blocks: float) -> String:
	if config == null or world == null or player == null:
		return "?"
	if world.generator == null:
		return "?"
	var p := player.global_position
	return world.generator.zone_name_at_m(p.x, p.z, p.y)


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
	# Anchored to the whole right edge rather than sized to content: the row
	# list outgrew the screen somewhere around distance v1, so the panel takes
	# the viewport's height and the rows scroll inside it.
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
	title.text = "worldgen tuning"
	# The one line of the tool that is typeset like the game. The readout and
	# the rows below stay in the plain face: a tuning panel is a tool, and a
	# display face on forty numbers would make them harder to read.
	title.add_theme_font_override("font", Deco.font_of(&"TitleLabel"))
	title.add_theme_font_size_override("font_size", 20)
	title.uppercase = true
	box.add_child(title)

	box.add_child(_seed_row())
	box.add_child(HSeparator.new())

	for row in TUNING_ROWS:
		box.add_child(_spin_row(row[0], row[1], row[2], row[3], row[4]))

	box.add_child(HSeparator.new())
	var local_title := Label.new()
	local_title.text = "this machine only - not sent to the host"
	box.add_child(local_title)
	for row in LOCAL_TUNING_ROWS:
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
		# Shape knobs are read-only on a client, because a client that retunes
		# its own terrain has silently left the host's world. Local knobs are
		# not: view distance and AO belong to whoever is looking at the screen,
		# and locking them to the host would be the bug rather than the guard.
		spin.editable = tuning_editable or WorldgenConfig.LOCAL_PROPERTIES.has(prop)
	_suppress = false
	if _seed_edit != null and world != null and "world_seed" in world:
		_seed_edit.text = str(world.world_seed)


func _on_spin_changed(value: float, prop: String) -> void:
	if _suppress or config == null:
		return
	var is_local := WorldgenConfig.LOCAL_PROPERTIES.has(prop)
	if not tuning_editable and not is_local:
		return
	# int-typed properties: a SpinBox only ever hands out floats, and assigning
	# 2.0 to an int export works but assigning 2.5 to one silently truncates in
	# a different place than the user is looking at.
	if typeof(config.get(prop)) == TYPE_INT:
		config.set(prop, int(round(value)))
	else:
		config.set(prop, value)

	# The preset owns voxel_radius_chunks and the fog, so moving it has to
	# resolve them immediately - otherwise the panel would show the new preset
	# beside the old radius until something else happened to reload the config.
	if prop == "view_distance":
		config.apply_view_preset()
		_refresh_panel()

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
