class_name CharacterPreview
extends SubViewportContainer

## A character on a turntable, in a box. The creation screen's rig, extracted
## so the character sheet can have the same one (ui v1 Stage 6).
##
## A 3D SCENE IN A BOX, WITH ITS OWN LIGHT AND ITS OWN CAMERA. Its own light,
## not the world's: the creation screen has no world, and a character lit by
## whatever the menu happens to have would be judged under lighting the game
## never uses. This is a key light and a fill, aimed to show a face and still
## separate the silhouette from the background.
##
## `own_world_3d = true` IS THE LOAD-BEARING LINE OF THIS FILE, and it is new.
## The creation screen did not need it: it is its own scene and there is no
## other 3D world for a SubViewport to inherit. The character SHEET is opened
## inside the game, and a SubViewport that shares the game's World3D would
## render THE LIVE WORLD into this box - and, far worse, its `camera.current`
## would fight the player's camera for the main viewport. The symptom is not a
## wrong preview; it is the player's view being taken over by a portrait
## camera that is looking at their own feet.
##
## UPDATE_WHEN_VISIBLE rather than UPDATE_ALWAYS for the same reason: the sheet
## is closed most of the time, and a second 3D scene rendering every frame
## behind a screen nobody is looking at is a cost with no picture attached.

## The floor, not the size. Under `canvas_items` stretch this box is laid out
## in logical pixels and painted at the window's scale, so on a large window
## the viewport follows the container's real size - see _on_resized.
const PREVIEW_SIZE := Vector2i(512, 640)

## Radians per second. Slow enough to read the face, fast enough that you do
## not wait to see the back.
const TURNTABLE_SPEED := 0.5

var view: CharacterView = null

var _turntable: Node3D = null
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _spinning := true


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(PREVIEW_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_on_resized)
	_build()
	set_process(true)


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.size = PREVIEW_SIZE
	_viewport.transparent_bg = false
	# See the class docstring. Both of these lines are what let this rig open
	# inside the game scene instead of only on a screen of its own.
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)

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
	# stands at +Z, so a turntable left at zero opens on the back of your own
	# head - which is the same mistake the gallery's first "front" sheet made,
	# and is worth a named half-turn in both places.
	_turntable.rotation.y = PI
	world.add_child(_turntable)

	view = CharacterView.new()
	_turntable.add_child(view)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.current = true
	world.add_child(_camera)


## Build (or rebuild) the character and frame it.
func build(def: CharacterDef) -> void:
	if view == null:
		return
	view.build(def)
	frame()


## Turn the turntable. Called from the owner's _process rather than from this
## node's, so a screen can freeze it - which the shot harness does.
func spin(delta: float) -> void:
	if _turntable != null and _spinning:
		_turntable.rotation.y += TURNTABLE_SPEED * delta


func set_spinning(on: bool) -> void:
	_spinning = on


## The turntable's angle, so a screen can pin it to a known value for a shot.
func set_angle(radians: float) -> void:
	if _turntable != null:
		_turntable.rotation.y = radians


func _process(delta: float) -> void:
	spin(delta)


## Frame whatever is standing on the turntable.
##
## Derived from the character's own height rather than fixed, because a 1.5 m
## dwarf and a 2.25 m elf in the same box need different framing and a screen
## that cut the elf's ears off would be hiding the one feature that makes it an
## elf.
func frame() -> void:
	if _camera == null or view == null:
		return
	var height := maxf(view.height_m(true), 1.0)
	var centre := height * 0.55
	# 2.2 rather than 1.9: at 40 degrees the vertical frame is 1.6 times the
	# character's height at this distance, which leaves a margin an elf's ears
	# and a lizardfolk's crest both fit inside.
	var distance := height * 2.2
	_camera.global_position = Vector3(0.0, centre + height * 0.12, distance)
	_camera.look_at(Vector3(0.0, centre, 0.0), Vector3.UP)


## Render at the number of pixels this box is actually shown at.
##
## The DISPLAYED size, which under `canvas_items` stretch is the logical size
## times the canvas scale - not the logical size, which is what a Control
## reports. Floored at PREVIEW_SIZE so a small window never renders the
## character at fewer pixels than the screen was designed around, and capped so
## a very large one cannot ask for a viewport that costs real memory for no
## visible gain.
func _on_resized() -> void:
	if _viewport == null:
		return
	var scale := get_global_transform().get_scale()
	var wanted := Vector2i(
		int(round(size.x * maxf(scale.x, 0.01))),
		int(round(size.y * maxf(scale.y, 0.01))))
	wanted.x = clampi(wanted.x, PREVIEW_SIZE.x, PREVIEW_SIZE.x * 4)
	wanted.y = clampi(wanted.y, PREVIEW_SIZE.y, PREVIEW_SIZE.y * 4)
	if _viewport.size != wanted:
		_viewport.size = wanted
