extends Node3D

## The character comparison harness. Photographs characters on a flat pad under
## frozen light and quits.
##
##     godot --path . scenes/character/gallery.tscn -- --label some-name
##     godot --path . scenes/character/gallery.tscn -- --label dusk --time 0.82
##     godot --path . scenes/character/gallery.tscn -- --sheet masks-40
##
## WHY NOT THE WORLD. The screenshot tour photographs terrain, and terrain is
## the thing it has to hold still: it freezes the sun for exactly that reason.
## A character comparison needs one more thing held still - the ground. Two
## shots of a dwarf taken a minute apart in the world differ in the hillside
## behind him, the fog depth, and which way the slope runs, and every one of
## those changes the silhouette you were trying to compare. Here the ground is
## a flat pad, the light is frozen, the camera is on rails, and the ONLY thing
## that differs between two runs is the character.
##
## This is the file every stage of character-v1 shoots its evidence with, and
## the sheets it writes are what Marcel judges the run by in the morning. The
## renderer here is not the renderer he will judge it on - see the status doc's
## "Tuned blind" table - so the sheets exist to make the difference between two
## versions visible, not to be the final word on any colour.

## Same root as the tour's build/tour, one directory along. `--label NAME`
## writes to a subdirectory of its own, which is what makes this a comparison
## harness rather than a screenshot tool.
const OUT_DIR := "res://build/character"

## The lineup stands here and the camera backs away from it along +Z. Not the
## origin: an 80 m shot puts the camera at z = 40, which has to still be on the
## pad or the far shots are taken from mid-air over a void.
const SUBJECT_Z := -40.0

## Metres. 60 x 120, as the plan fixes it. At 40 m the frame is 61 m wide, so
## the pad fills it exactly at the distance the silhouette test is judged at.
const PAD_HALF_X := 30.0
const PAD_HALF_Z := 60.0

## The "against a hillside" backdrop. WIDER THAN THE PAD, deliberately: at 80 m
## the frame is 123 m across and a 60 m wall would be a stripe with sky either
## side, which is neither the sky variant nor the hill variant.
const WALL_Z := -56.0
const WALL_HALF_X := 80.0
const WALL_HEIGHT := 20.0

## The game's camera, so a character photographed here is the size it is in
## play. Camera3D's default fov is 75 and player.tscn does not override it.
const FOV := 75.0
const EYE_HEIGHT := 1.7

## Frames to let the renderer settle after moving anything. Nothing streams
## here, but a material override applied on the same frame as the capture has
## not necessarily reached the GPU.
const SETTLE_FRAMES := 4

## Metres between characters in a lineup. Wide enough that two silhouettes
## never touch at 15 m, which would make the mask metric measure the gap.
const LINEUP_SPACING := 2.6

var config: WorldgenConfig = null

@onready var _sun: DirectionalLight3D = $Sun
@onready var _env_node: WorldEnvironment = $WorldEnvironment
@onready var _sky: SkyCycle = $SkyCycle

var _camera: Camera3D = null
var _pad: MeshInstance3D = null
var _wall: MeshInstance3D = null
var _subjects_root: Node3D = null

var _out_dir := OUT_DIR
var _written := 0


func _ready() -> void:
	config = WorldgenConfig.load_or_default()
	# The gallery is not the world and must never write world tuning, but it
	# has to LOOK like the world or a colour judged here means nothing there.
	_sky.setup(config, _sun, _env_node)
	_freeze_time()

	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.far = 600.0
	_camera.current = true
	add_child(_camera)

	_subjects_root = Node3D.new()
	_subjects_root.name = "Subjects"
	add_child(_subjects_root)

	_build_pad()
	_build_wall()

	_run.call_deferred()


func _run() -> void:
	var wanted := _wanted_sheets()
	print("[Gallery] writing to %s" % _out_dir)
	for name in _sheets():
		if not wanted.is_empty() and not wanted.has(name):
			continue
		var fn: Callable = _sheets()[name]
		await fn.call()
	print("[Gallery] done, %d images in %s" % [_written, _out_dir])
	get_tree().quit()


## The sheets this gallery can shoot, in the order they are shot. Stages add
## entries here as the thing each one photographs comes into existence.
func _sheets() -> Dictionary:
	return {
		"testcube": _sheet_testcube,
		"lineup-front": _sheet_lineup_front,
		"lineup-back": _sheet_lineup_back,
	}


# --- Sheets -----------------------------------------------------------------

func _sheet_lineup_front() -> void:
	_set_lineup(_lineup_defs())
	await _shoot("lineup-front", 15.0)


func _sheet_lineup_back() -> void:
	_set_lineup(_lineup_defs())
	for s in _subjects_root.get_children():
		(s as Node3D).rotation.y = PI
	await _shoot("lineup-back", 15.0)


## Who stands in the lineup. Every race in the stocky scheme plus the lean
## human, once those exist. Tonight there is no character system at all, so the
## lineup is one capsule - which is exactly the "before" the run is measured
## against, and the reason the plan says to shoot it anyway.
func _lineup_defs() -> Array:
	return [null]


## The part mesher, on the pad, at a distance where you can count the voxels.
##
## A 12-voxel cube with a bite out of one corner: the flat faces show the
## palette arriving linear rather than washed out, and the bite is the only
## place a concave corner exists, so it is where baked AO either shows up or
## does not. The self-tests prove the numbers; this proves they reach a screen.
func _sheet_testcube() -> void:
	for child in _subjects_root.get_children():
		child.free()
	var n := 12
	var voxels := []
	for y in n:
		for z in n:
			for x in n:
				# The bite: a quarter of the cube removed from one top corner.
				if x >= n / 2 and y >= n / 2 and z >= n / 2:
					continue
				voxels.append(Vector4i(x, y, z, VoxelModel.SKIN))
	var palette := {VoxelModel.SKIN: Color.html("#E0AC7E").srgb_to_linear()}
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelModel.build_mesh(voxels, palette, Vector3i(n / 2, 0, n / 2), 0.35)
	var holder := Node3D.new()
	holder.add_child(mi)
	holder.position = Vector3(0.0, 0.0, SUBJECT_Z)
	_subjects_root.add_child(holder)
	await _shoot("testcube", 2.4)


# --- Subjects ---------------------------------------------------------------

## Replace the lineup. `defs` is an array of CharacterDef, or null for the
## capsule stand-in that predates the character system.
func _set_lineup(defs: Array) -> void:
	for child in _subjects_root.get_children():
		child.free()
	var span := float(defs.size() - 1) * LINEUP_SPACING
	for i in defs.size():
		var node := _make_subject(defs[i])
		node.position = Vector3(-span * 0.5 + float(i) * LINEUP_SPACING, 0.0, SUBJECT_Z)
		_subjects_root.add_child(node)


## One subject. THE ONLY PLACE the gallery decides what a character looks like,
## so that when CharacterView arrives this function is the whole of the change.
func _make_subject(_def) -> Node3D:
	# The capsule from player.tscn, at the same offset: its centre sits 1 m up
	# inside a 2 m body whose feet are at y = 0.
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 2.0
	mi.mesh = capsule
	mi.position = Vector3(0.0, 1.0, 0.0)
	var holder := Node3D.new()
	holder.add_child(mi)
	return holder


## Chest height of whatever is standing in the lineup, for the camera to aim
## at. Derived rather than fixed so a 1.5 m dwarf and a 2.25 m elf in the same
## row are both in frame.
func _lineup_chest_height() -> float:
	return 1.3


# --- Taking the picture -----------------------------------------------------

## Photograph the lineup from `distance` metres in front of it.
func _shoot(sheet_name: String, distance: float, suffix := "") -> void:
	var look_at := Vector3(0.0, _lineup_chest_height(), SUBJECT_Z)
	_camera.global_position = Vector3(0.0, EYE_HEIGHT, SUBJECT_Z + distance)
	_camera.look_at(look_at, Vector3.UP)
	await _save("%s%s" % [sheet_name, suffix])


func _save(file_name: String) -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	# The image is only valid once the frame has actually been drawn.
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, file_name]
	var err := image.save_png(path)
	if err != OK:
		push_warning("[Gallery] could not write %s: %s" % [path, error_string(err)])
		return
	_written += 1
	print("[Gallery]   -> %s (%dx%d)" % [path, image.get_width(), image.get_height()])


# --- The set ----------------------------------------------------------------

## A flat pad of meadow, as ONE QUAD rather than as blocks.
##
## Hard rule 12 says parts are data and nothing is built from primitives in
## code - and names this pad as its one exception. Worth saying why it is a
## quad and not 240 x 120 real blocks: the pad's colour is flat, so a lattice
## of blocks would produce an identical image for 57,600 triangles, and the
## per-vertex jitter that gives real terrain its mottling is deliberately OFF
## here. A backdrop that varies between runs is a backdrop that cannot be
## compared against itself.
func _build_pad() -> void:
	_pad = _flat_mesh([
		Vector3(-PAD_HALF_X, 0.0, -PAD_HALF_Z),
		Vector3(-PAD_HALF_X, 0.0, PAD_HALF_Z),
		Vector3(PAD_HALF_X, 0.0, PAD_HALF_Z),
		Vector3(PAD_HALF_X, 0.0, -PAD_HALF_Z),
	], Vector3.UP, Block.color_of(Block.GRASS))
	_pad.name = "Pad"
	add_child(_pad)


## The hillside stand-in: a dark stone wall behind the lineup. Hidden for the
## sky variants, shown for the `-hill` ones. A silhouette that reads against
## bright sky can vanish completely against rock, which is half of what the
## 40 m dusk test is actually asking.
func _build_wall() -> void:
	_wall = _flat_mesh([
		Vector3(-WALL_HALF_X, 0.0, WALL_Z),
		Vector3(WALL_HALF_X, 0.0, WALL_Z),
		Vector3(WALL_HALF_X, WALL_HEIGHT, WALL_Z),
		Vector3(-WALL_HALF_X, WALL_HEIGHT, WALL_Z),
	], Vector3.BACK, Block.color_of(Block.STONE))
	_wall.name = "Wall"
	_wall.visible = false
	add_child(_wall)


## One flat quad, wound so it faces `normal`, in the terrain's material.
##
## The winding identity is the mesher's: (p1 - p0) x (p2 - p0) == -normal is
## "clockwise seen from outside", which is the face Godot draws. Points are
## reversed rather than eyeballed if the quad comes out invisible.
func _flat_mesh(points: Array, normal: Vector3, color: Color) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for p in points:
		verts.push_back(p)
		normals.push_back(normal)
		colors.push_back(color)
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var cross := (verts[1] - verts[0]).cross(verts[2] - verts[0]).normalized()
	if cross.dot(normal) > 0.0:
		indices = PackedInt32Array([0, 2, 1, 0, 3, 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


# --- Command line -----------------------------------------------------------

## Stop the sun where it is, for the whole run.
##
## Same reason as the tour: a day is day_seconds long, a sheet under software
## rendering is not instant, and a comparison harness whose lighting depends on
## how long rendering took compares the wrong thing. `--time 0.82` is dusk and
## is what the silhouette sheets are shot at.
func _freeze_time() -> void:
	var t := -1.0
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--time")
	if i >= 0 and i + 1 < argv.size():
		t = clampf(argv[i + 1].to_float(), 0.0, 1.0)
	if t < 0.0:
		t = config.day_start
	_sky.time_of_day = t
	_sky.frozen = true
	_sky.apply()
	print("[Gallery] time of day frozen at %.3f" % t)


## `--sheet a,b` shoots only those. Empty means every sheet this build has.
func _wanted_sheets() -> Array:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--sheet")
	if i < 0 or i + 1 >= argv.size():
		return []
	var out := []
	for part in argv[i + 1].split(","):
		var clean := part.strip_edges()
		if not clean.is_empty():
			out.append(clean)
	return out


## `--label NAME` -> res://build/character/NAME. No label -> build/character.
##
## The sanitising rule is COPIED FROM THE TOUR, not imported from it. Hard rule
## 1 puts screenshot_tour.gd on the never-touch list, and importing a private
## helper out of it would couple this file to a file this branch may not edit -
## which is exactly the coupling that makes the two runs collide on merge.
func _resolve_out_dir() -> String:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--label")
	if i < 0 or i + 1 >= argv.size():
		return OUT_DIR
	var label := argv[i + 1].strip_edges()
	# Letters, digits, dash, underscore and dot survive; everything else
	# becomes a dash. is_valid_identifier() alone rejects digits, since a digit
	# cannot START an identifier - "v2-baseline" would come out "--baseline".
	var clean := ""
	for c in label:
		if c.is_valid_identifier() or (c >= "0" and c <= "9") or c in "-_.":
			clean += c
		else:
			clean += "-"
	clean = clean.strip_edges()
	if clean.is_empty():
		push_warning("[Gallery] --label %s is not usable as a directory name" % label)
		return OUT_DIR
	return "%s/%s" % [OUT_DIR, clean]
