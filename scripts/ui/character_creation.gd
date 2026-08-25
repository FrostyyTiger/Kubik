extends Control

## One screen: race, palette swaps, hair and beard picks, a name.
##
## NO SLIDERS. NO STATS. Hard rules 11 and 3. Every control here changes what
## a character LOOKS like and nothing else, because race is never a stat and a
## slider is how a game ends up with forty numbers nobody can tell apart.
##
## EVERY CHANGE REBUILDS THE PREVIEW, which is why `CharacterView.build()` had
## to be idempotent and cheap from the start. Clicking a swatch tears the rig
## down and puts it back up - seven meshes, a few hundred quads each - and that
## is fast enough to do on every click precisely because parts are authored in
## slots and a palette swap is one array of colours.
##
## Built in code rather than in the .tscn, like both debug panels: the swatch
## rows are a loop over a table, which is twenty lines as code and several
## hundred as scene nodes, and this machine has no editor to make them in.

## The preview viewport. Alive only while this screen is open - it is a second
## 3D scene and there is no reason to pay for it from the main menu.
const PREVIEW_SIZE := Vector2i(512, 640)

## Radians per second. Slow enough to read the face, fast enough that you do
## not wait to see the back.
const TURNTABLE_SPEED := 0.5

var def: CharacterDef = null

var _view: CharacterView = null
var _turntable: Node3D = null
var _viewport: SubViewport = null
var _name_edit: LineEdit = null
var _rows := {}          # field name -> the Control holding that row
var _labels := {}        # field name -> the Label showing the current option
var _swatches := {}      # field name -> Array[Button]
var _build_buttons := []
var _race_buttons := []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	def = CharacterDef.load_or_default()
	_build_ui()
	_rebuild()
	if UiShot.wanted():
		_shoot_ui()


## `--shot-ui <label>`: the main menu has already photographed itself and
## pressed Character; this screen saves build/ui/<label>/character-creation.png
## and ends the process. See UiShot.
func _shoot_ui() -> void:
	await UiShot.capture(get_tree(), "character-creation")
	get_tree().quit()


func _process(delta: float) -> void:
	if _turntable != null:
		_turntable.rotation.y += TURNTABLE_SPEED * delta


# --- The preview --------------------------------------------------------------

## A 3D scene in a box, with its own light and its own camera.
##
## ITS OWN LIGHT, not the world's: the creation screen has no world, and a
## character lit by whatever the menu happens to have would be judged under
## lighting the game never uses. This is a key light and a fill, aimed to show
## a face and still separate the silhouette from the background.
func _build_preview() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)

	_viewport = SubViewport.new()
	_viewport.size = PREVIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	var world := Node3D.new()
	_viewport.add_child(world)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	# Ink. The preview is a print mounted on the paper of the screen, and a
	# character reads best against the darkest of the five colours.
	environment.background_color = Deco.INK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.60, 0.70)
	environment.ambient_light_energy = 0.35
	# LINEAR, for the same reason SkyCycle uses it: there are no textures here,
	# the palette IS the art direction, and a tonemapper that reshapes it is
	# reshaping the art. A skin swatch that does not match the model it paints
	# would make this screen actively misleading.
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = environment
	world.add_child(env)

	var key := DirectionalLight3D.new()
	key.light_energy = 0.9
	key.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(30.0), 0.0)
	world.add_child(key)

	_turntable = Node3D.new()
	# FACING THE CAMERA TO START WITH. A character faces -Z and the camera
	# stands at +Z, so a turntable left at zero opens this screen on the back
	# of your own head - which is the same mistake the gallery's first "front"
	# sheet made, and is worth a named half-turn in both places.
	_turntable.rotation.y = PI
	world.add_child(_turntable)

	_view = CharacterView.new()
	_turntable.add_child(_view)

	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.current = true
	world.add_child(camera)
	_preview_camera = camera
	return container


var _preview_camera: Camera3D = null


## Frame whatever is standing on the turntable.
##
## Derived from the character's own height rather than fixed, because a 1.5 m
## dwarf and a 2.25 m elf in the same box need different framing and a screen
## that cut the elf's ears off would be hiding the one feature that makes it an
## elf.
func _frame_preview() -> void:
	if _preview_camera == null or _view == null:
		return
	var height := maxf(_view.height_m(true), 1.0)
	var centre := height * 0.55
	# 2.2 rather than 1.9: at 40 degrees the vertical frame is 1.6 times the
	# character's height at this distance, which leaves a margin an elf's ears
	# and a lizardfolk's crest both fit inside.
	var distance := height * 2.2
	_preview_camera.global_position = Vector3(0.0, centre + height * 0.12, distance)
	_preview_camera.look_at(Vector3(0.0, centre, 0.0), Vector3.UP)


# --- The controls -------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Deco.PAPER
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	margin.add_child(columns)

	# The preview sits in a PanelContainer, so the theme's ink border and paper
	# margin frame it like a mounted print.
	var frame := PanelContainer.new()
	# THE STEPPED CORNER (look v2 Stage 6). Ink, then gold inset 5, then paper
	# inset 10, each at a smaller radius - a printed mount steps in, it does
	# not have one rounded edge.
	frame.add_theme_stylebox_override("panel", DecoPanel.stepped())
	frame.add_child(_build_preview())
	columns.add_child(frame)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)

	right.add_child(Deco.rule())
	var title := Deco.label("Your character", &"TitleLabel", true)
	title.add_theme_font_size_override("font_size", 44)
	right.add_child(title)
	right.add_child(Deco.rule())

	right.add_child(_race_row())
	right.add_child(_build_row())
	right.add_child(HSeparator.new())
	right.add_child(_swatch_row("skin", "Skin"))
	right.add_child(_swatch_row("hair_color", "Hair"))
	right.add_child(_swatch_row("eyes", "Eyes"))
	right.add_child(HSeparator.new())
	right.add_child(_picker_row("hair", "Style"))
	right.add_child(_picker_row("beard", "Beard"))
	right.add_child(HSeparator.new())
	right.add_child(_name_row())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)

	var randomise := Button.new()
	randomise.text = "RANDOMISE"
	randomise.custom_minimum_size = Vector2(140, 44)
	randomise.pressed.connect(_on_randomise)
	buttons.add_child(randomise)

	var done := Button.new()
	done.text = "DONE"
	done.custom_minimum_size = Vector2(140, 44)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(_on_done)
	buttons.add_child(done)


## The label that starts every row: a section heading, small capitals in
## alpine blue, on a fixed width so the controls line up down the screen.
func _row_label(text: String) -> Label:
	var label := Deco.label(text, &"SectionLabel", true)
	label.custom_minimum_size = Vector2(88, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _race_row() -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label("Race"))
	for race in Races.RACE_COUNT:
		var button := Button.new()
		button.text = Races.RACE_NAMES[race].to_upper()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_race_pressed.bind(race))
		row.add_child(button)
		_race_buttons.append(button)
	return row


## Stocky or lean, and DISABLED for a race that has no lean part set.
##
## Disabled rather than hidden, because the toggle disappearing when you click
## "Dwarf" reads as the screen breaking. Greyed out reads as "not for this
## race", which is what it is - and one line in Races.HAS_LEAN decides it.
##
## THE WHOLE ROW IS HIDDEN WHEN NO RACE HAS A LEAN SET, which is every race
## since look v1. A row of two greyed-out buttons on every race is not a
## choice, it is furniture.
func _build_row() -> Control:
	var row := HBoxContainer.new()
	row.visible = Races.HAS_LEAN.has(true)
	row.add_child(_row_label("Build"))
	for build in Races.BUILD_COUNT:
		var button := Button.new()
		button.text = Races.BUILD_NAMES[build].to_upper()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_build_pressed.bind(build))
		row.add_child(button)
		_build_buttons.append(button)
	_rows["build"] = row
	return row


## A row of colour swatches, one per option in this race's palette.
##
## THE SWATCHES SHOW THE AUTHORED sRGB HEX, not the linear value the mesher
## uses. Races stores both - the hex in the table and the linear conversion at
## resolve time - and a UI colour in Godot is sRGB, so painting a swatch with
## the linear value would draw every skin tone far darker than the model it
## claims to describe. That mismatch would make this screen worse than no
## screen, because it would be confidently wrong.
func _swatch_row(field: String, label_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(label_text))

	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(holder)

	_swatches[field] = []
	# Built at the maximum count any race has, then shown or hidden per race -
	# rebuilding the row on every race click would drop the focus and make the
	# screen flicker.
	for i in _max_options(field):
		var button := Button.new()
		button.custom_minimum_size = Vector2(44, 36)
		button.pressed.connect(_on_swatch_pressed.bind(field, i))
		holder.add_child(button)
		(_swatches[field] as Array).append(button)
	_rows[field] = row
	return row


func _max_options(field: String) -> int:
	var most := 0
	for race in Races.RACE_COUNT:
		most = maxi(most, _option_count(race, field))
	return most


func _picker_row(field: String, label_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(label_text))

	var back := Button.new()
	back.text = "<"
	back.custom_minimum_size = Vector2(44, 36)
	back.pressed.connect(_on_picker.bind(field, -1))
	row.add_child(back)

	var value := Deco.label("", &"AccentLabel")
	value.add_theme_font_size_override("font_size", 22)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	_labels[field] = value

	var forward := Button.new()
	forward.text = ">"
	forward.custom_minimum_size = Vector2(44, 36)
	forward.pressed.connect(_on_picker.bind(field, 1))
	row.add_child(forward)

	_rows[field] = row
	return row


func _name_row() -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label("Name"))

	_name_edit = LineEdit.new()
	_name_edit.max_length = CharacterDef.NAME_MAX
	_name_edit.placeholder_text = "up to %d characters" % CharacterDef.NAME_MAX
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(_on_name_changed)
	row.add_child(_name_edit)
	return row


# --- Behaviour ----------------------------------------------------------------

func _on_race_pressed(race: int) -> void:
	def.race = race
	# Clamped rather than reset: someone who liked skin 3 on a human and
	# switches to a dwarf keeps skin 3 if the dwarf has one, which is what
	# "the same character, a different race" should feel like.
	def.validate()
	_rebuild()


func _on_build_pressed(build: int) -> void:
	def.build = build
	def.validate()
	_rebuild()


func _on_swatch_pressed(field: String, index: int) -> void:
	def.set(field, index)
	def.validate()
	_rebuild()


func _on_picker(field: String, step: int) -> void:
	var count := _option_count(def.race, field)
	if count <= 0:
		return
	def.set(field, posmod(int(def.get(field)) + step, count))
	def.validate()
	_rebuild()


func _on_name_changed(text: String) -> void:
	# Stored raw and sanitised on the way out, so a player typing a space in
	# the middle of a name does not have it eaten mid-keystroke.
	def.name_text = text


## RANDOMISE MAY USE randi(). Hard rule 13: determinism is not required here,
## because an appearance is data that is SENT and never derived on two machines
## from a seed. The deterministic path exists too and is `--look N`, which is
## what the headless tests use.
func _on_randomise() -> void:
	def.randomise_from(randi())
	_name_edit.text = def.name_text
	_rebuild()


func _on_done() -> void:
	def.name_text = CharacterDef.sanitise_name(def.name_text, 0)
	def.validate()
	def.save()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Escape leaves WITHOUT saving, which is the only way to back out of a
		# change of mind. Done is the only thing that writes the file.
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# --- Refresh ------------------------------------------------------------------

## Rebuild the preview and bring every control into line with the def.
func _rebuild() -> void:
	_view.build(def)
	_frame_preview()

	for race in Races.RACE_COUNT:
		(_race_buttons[race] as Button).button_pressed = (race == def.race)

	var has_lean := Races.has_lean(def.race)
	for build in Races.BUILD_COUNT:
		var button: Button = _build_buttons[build]
		button.button_pressed = (build == def.build)
		button.disabled = not has_lean

	for field in ["skin", "hair_color", "eyes"]:
		var count := _option_count(def.race, field)
		var buttons: Array = _swatches[field]
		for i in buttons.size():
			var button: Button = buttons[i]
			button.visible = i < count
			if i >= count:
				continue
			button.button_pressed = (i == int(def.get(field)))
			_paint_swatch(button, field, i, i == int(def.get(field)))

	_set_picker("hair", Races.HAIR_OPTIONS[def.race])
	# THE BEARD ROW DISAPPEARS for a race with none, rather than showing one
	# dead option. The elf has no beard at all and the plan says so; a greyed
	# picker would imply there is something there to unlock.
	var beards: Array = Races.BEARD_OPTIONS[def.race]
	(_rows["beard"] as Control).visible = not beards.is_empty()
	if not beards.is_empty():
		_set_picker("beard", beards)

	if _name_edit.text != def.name_text:
		_name_edit.text = def.name_text


func _set_picker(field: String, options: Array) -> void:
	var index: int = clampi(int(def.get(field)), 0, options.size() - 1)
	(_labels[field] as Label).text = "%s  (%d/%d)" % [
		str(options[index]).capitalize(), index + 1, options.size()]


func _paint_swatch(button: Button, field: String, index: int, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(_swatch_hex(field, index))
	# The theme's chamfer, so a swatch is the same octagon as a button.
	style.set_corner_radius_all(8)
	style.corner_detail = 1
	style.set_border_width_all(3)
	# Gold picks the current one out; ink keeps the rest from floating on
	# paper when the swatch is a pale skin tone.
	style.border_color = Deco.GOLD if selected else Deco.INK
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)


func _swatch_hex(field: String, index: int) -> String:
	match field:
		"skin":
			return Races.SKIN_HEX[def.race][index]
		"hair_color":
			return Races.HAIR_HEX[def.race][index]
		"eyes":
			return Races.EYE_HEX[def.race][index]
	return "#FF00FF"


func _option_count(race: int, field: String) -> int:
	match field:
		"skin":
			return Races.skin_count(race)
		"hair_color":
			return Races.hair_color_count(race)
		"eyes":
			return Races.eye_count(race)
		"hair":
			return Races.hair_count(race)
		"beard":
			return Races.beard_count(race)
	return 0
