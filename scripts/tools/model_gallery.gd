extends Node3D

## Photographs every tree species and every plant model, side by side, against
## a known camera and a frozen noon sun.
##
##     godot --path . scenes/gallery.tscn -- --label some-name
##
## WHY THIS EXISTS, AND WHY IT IS THE FIRST THING FOLIAGE V1 BUILDS.
##
## This box has no display. Godot falls back to OpenGL Compatibility on Mesa
## llvmpipe under Xvfb, and Marcel plays on Forward+ on a real GPU - so every
## shape and every colour chosen here is chosen on the wrong renderer. The
## honest answer to that is not to stop tuning, it is to make what was tuned
## easy to re-check: one image, every species, a fixed camera, a known light.
##
## TUNING AGAINST THE WORLD IS THE MISTAKE THIS REPLACES. A tree seen in the
## world is seen at whatever distance the terrain put it, through fog, half
## behind its neighbours, at whatever hour the tour happened to freeze. Two
## runs of the same seed then differ in a dozen ways at once and none of them
## is the shape you were trying to judge. Here a spruce is 9 m from the camera
## with nothing in front of it, and the ONLY thing that can change between two
## gallery shots is the model.
##
## The trees are stamped through the same species stamper the world uses, into
## scratch chunks, and meshed with the same ChunkMesher. Nothing here draws a
## tree its own way - a gallery that flattered the model by drawing it
## differently from the game would be worse than no gallery at all.

## Where the images go. `--label NAME` writes to a subdirectory, exactly as the
## screenshot tour does, so two gallery sets sit side by side on disk.
const OUT_DIR := "res://build/gallery"

## Blocks between the min, mid and max of ONE species, along X.
##
## THE THREE SIZES SHARE A DEPTH, and that is the whole reason they are laid
## out sideways rather than receding. The point of the row is to compare a
## species' smallest against its largest, and two trees at different distances
## from the camera cannot be compared at all - perspective makes the far one
## smaller, which is precisely the difference being looked for. Side by side,
## a size difference in the image is a size difference in the model.
const SIZE_BLOCKS := 14

## Blocks between one species' bay and the next, along X.
const BAY_BLOCKS := 50

## Blocks between the two SPECIES rows, along Z.
##
## Seven species by three sizes in a single line is 21 trees and 150 m of pad,
## which photographs each tree about sixty pixels wide - too small to tell a
## spruce from a larch, which is the acceptance test. Two rows halve the width
## and cost one depth comparison that nothing depends on: sizes are compared
## within a species, never across two.
const ROW_BLOCKS := 34

## Species in the front row before wrapping to the back one.
const SPECIES_PER_ROW := 4

## The flat pad every specimen stands on, in blocks beyond the outermost tree.
const PAD_MARGIN := 10

## Altitude of the pad's top surface, in blocks. Well clear of zero so the
## scratch chunks below it are ordinary chunks rather than the bottom of the
## world.
const GROUND := 40

## Frames to let the renderer settle before the shutter. The meshes are all
## built in one frame here - there is no streaming - but the light and the sky
## still need a frame to take.
const SETTLE_FRAMES := 4

## Noon, frozen. The tour photographs the world at day_start because that is
## the light the palette was tuned against; the gallery wants the opposite -
## the most neutral, most overhead light there is, so a shape is judged as a
## shape rather than as a silhouette against a dusk sky.
const GALLERY_TIME := 0.5

var _config: WorldgenConfig = null
var _camera: Camera3D = null
var _out_dir := OUT_DIR

## One entry per specimen actually built: {"name", "size", "center" (Vector3 in
## metres), "height_m"}. The close-up pass reads this rather than recomputing
## the layout, so the two can never disagree about where a tree is.
var _specimens: Array = []

## Species name -> the specimens belonging to it, in min/mid/max order.
var _by_species := {}


func _ready() -> void:
	_config = WorldgenConfig.load_or_default()
	_config.apply_cli_overrides(OS.get_cmdline_user_args())
	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	var sky: SkyCycle = $SkyCycle
	sky.setup(_config, $Sun, $WorldEnvironment)
	sky.time_of_day = GALLERY_TIME
	sky.frozen = true
	sky.apply()

	_camera = $Camera3D
	_camera.current = true

	_build()
	_shoot.call_deferred()


# --- Building the pad -------------------------------------------------------

func _build() -> void:
	var species := TreeSpecies.gallery_rows(_config)
	var vol := ScratchVolume.new()
	var layout := _layout(species.size())

	for i in species.size():
		var row: Dictionary = species[i]
		var bay: Vector2i = layout[i]
		for j in 3:
			# MINUS, not plus. The camera stands at -Z and looks along +Z, and
			# with Godot's right-handed axes that puts +X on the LEFT of the
			# frame - so a bay laid out in increasing X photographs backwards.
			# Negating here makes min, mid, max read left to right in the
			# image, which is the only place anybody reads them.
			var bx := bay.x - (j - 1) * SIZE_BLOCKS
			var bz := bay.y
			# min, mid, max of the species' own range, in that order. `t` is
			# handed to the stamper rather than a height in blocks, so a
			# species whose size is not a simple height - the hero, which
			# scales its parent - still has three honest sizes.
			var t := float(j) * 0.5
			var drawn: Dictionary = TreeSpecies.stamp_specimen(
				vol, row["id"], bx, GROUND, bz, t, _config)
			var entry := {
				"name": row["name"],
				"size": ["min", "mid", "max"][j],
				"center": _to_metres(bx, GROUND + drawn["height"] / 2, bz),
				"height_m": float(drawn["height"]) * _config.block_size,
				"blocks": int(drawn["blocks"]),
			}
			_specimens.append(entry)
			if not _by_species.has(row["name"]):
				_by_species[row["name"]] = []
			_by_species[row["name"]].append(entry)

	_stamp_pad(vol)
	_publish(vol)
	_place_scale_figure(_pad_min().x + 4, _pad_min().y + 4)
	_place_plant_models()

	var total_blocks := 0
	for s in _specimens:
		total_blocks += int(s["blocks"])
	print("[Gallery] %d specimens, %d species, %d tree blocks" % [
		_specimens.size(), _by_species.size(), total_blocks])


## Where each species' bay centre sits, in blocks, centred on the origin.
##
## Wrapped into rows of SPECIES_PER_ROW and then shifted so the whole
## arrangement straddles (0, 0) - which means the camera can always aim at the
## origin and the layout can change without the shooting code knowing.
func _layout(count: int) -> Array:
	var out: Array = []
	var rows := int(ceil(float(count) / float(SPECIES_PER_ROW)))
	for i in count:
		var r := i / SPECIES_PER_ROW
		var c := i % SPECIES_PER_ROW
		# How many bays are actually in THIS row, so a short back row is
		# centred over the front one rather than left-aligned against it.
		var in_row := mini(count - r * SPECIES_PER_ROW, SPECIES_PER_ROW)
		# Negated for the same reason the sizes are - see _build().
		var x := -(c - (in_row - 1) * 0.5) * float(BAY_BLOCKS)
		var z := (float(r) - float(rows - 1) * 0.5) * float(ROW_BLOCKS)
		out.append(Vector2i(int(round(x)), int(round(z))))
	return out


## The pad's extent in blocks, from where the specimens actually landed.
func _pad_min() -> Vector2i:
	return Vector2i(_extent().position)


func _extent() -> Rect2i:
	var lo := Vector2i(0, 0)
	var hi := Vector2i(0, 0)
	var first := true
	for s in _specimens:
		var bx := int(round(float(s["center"].x) / _config.block_size))
		var bz := int(round(float(s["center"].z) / _config.block_size))
		if first:
			lo = Vector2i(bx, bz)
			hi = Vector2i(bx, bz)
			first = false
		lo = Vector2i(mini(lo.x, bx), mini(lo.y, bz))
		hi = Vector2i(maxi(hi.x, bx), maxi(hi.y, bz))
	lo -= Vector2i(PAD_MARGIN, PAD_MARGIN)
	hi += Vector2i(PAD_MARGIN, PAD_MARGIN)
	return Rect2i(lo, hi - lo)


## A flat slab of meadow under everything, two blocks thick.
##
## Two, not one, for the same reason the terrain has SURFACE_DEPTH 2: a
## one-block skin shows soil at every edge, and the gallery would be judging
## the models against a different ground than the world puts them on.
func _stamp_pad(vol: ScratchVolume) -> void:
	var box := _extent()
	for bz in range(box.position.y, box.end.y + 1):
		for bx in range(box.position.x, box.end.x + 1):
			vol.set_block(bx, GROUND, bz, Block.GRASS)
			vol.set_block(bx, GROUND - 1, bz, Block.GRASS)
			vol.set_block(bx, GROUND - 2, bz, Block.DIRT)


## Turn every scratch chunk into a mesh, through the real mesher.
func _publish(vol: ScratchVolume) -> void:
	var root := Node3D.new()
	root.name = "Pad"
	add_child(root)
	for cpos in vol.chunks:
		var chunk: Chunk = vol.chunks[cpos]
		var mesh := ChunkMesher.build(chunk, vol.solid_at, _config, 0)
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = Vector3(chunk.origin()) * _config.block_size
		root.add_child(node)


## The player, for scale, at 1:1.
##
## Trees are 1:4 landscape and plants are 1:1, and the whole reason the scale
## table in the plan has two rows is that those two numbers are easy to mix up
## when everything is grey boxes. A capsule of exactly the player's dimensions
## standing in the same frame is what makes a 12 cm grass tuft obviously wrong.
func _place_scale_figure(bx: int, bz: int) -> void:
	var height_m: float = _config.player_height_blocks * _config.block_size
	var radius_m: float = _config.player_radius_blocks * _config.block_size
	var mesh := CapsuleMesh.new()
	mesh.radius = radius_m
	mesh.height = height_m
	var mat := StandardMaterial3D.new()
	# Not a palette colour. This is a ruler, and it should never be mistaken
	# for something that grows.
	mat.albedo_color = Color(0.55, 0.12, 0.14)
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.name = "ScaleFigure"
	node.mesh = mesh
	node.position = _to_metres(bx, GROUND + 1, bz) + Vector3(0.0, height_m * 0.5, 0.0)
	add_child(node)


## The ground-cover strip, at 1:1, beside the trees.
##
## Empty until Stage 5 builds FloraModels - and deliberately still called here,
## so the layout that Stage 6 fills is the layout Stage 1 photographed. A
## gallery whose composition changes the day the models arrive cannot be used
## to compare the day before with the day after.
func _place_plant_models() -> void:
	if not ResourceLoader.exists("res://scripts/world/flora/flora_models.gd"):
		print("[Gallery] no plant models yet - the 1:1 strip is empty (Stage 5 fills it)")
		return
	_build_plant_strip()


## Fills the 1:1 strip in front of the trees. Stage 6's models land here.
func _build_plant_strip() -> void:
	var script := load("res://scripts/world/flora/flora_models.gd")
	if script == null:
		return
	var names: Array = script.gallery_names()
	var root := Node3D.new()
	root.name = "Plants"
	add_child(root)
	# 1.2 m apart in a row, at 1:1, along the front edge of the pad.
	var box := _extent()
	var z := float(box.position.y + 4) * _config.block_size
	var x0 := float(box.position.x + 10) * _config.block_size
	for i in names.size():
		var node := MeshInstance3D.new()
		node.mesh = script.build_mesh(names[i])
		node.material_override = script.gallery_material()
		node.position = Vector3(x0 + float(i) * 1.2, float(GROUND + 1) * _config.block_size, z)
		root.add_child(node)
	print("[Gallery] %d plant models in the 1:1 strip" % names.size())


# --- Taking the pictures ----------------------------------------------------

func _shoot() -> void:
	await _settle()

	# THE WIDE SHOT. Every species at every size in one frame, from the front
	# and above, so the two rows read as two rows.
	var box := _extent()
	var all_h := _tallest(_specimens)
	await _capture("gallery",
		_fit(0.0, float(box.size.x) * _config.block_size, all_h,
			float(box.size.y) * _config.block_size, 30.0, all_h),
		_look_at(0.0, all_h))

	# ONE CLOSE-UP PER SPECIES. Framed on that species' three sizes only, from
	# nearer and lower, which is the view a shape is actually judged from - a
	# silhouette read against the sky rather than an overview.
	for name in _by_species:
		var group: Array = _by_species[name]
		var cx := 0.0
		for s in group:
			cx += float(s["center"].x)
		cx /= float(group.size())
		var h := _tallest(group)
		# The three sizes of one species share a row, so there is no depth to
		# allow for beyond the tree itself - unlike the wide shot, which has to
		# fit both rows in. Passing the whole pad's depth here would push the
		# camera back until the close-up stopped being close.
		var bay := float(2 * SIZE_BLOCKS + 2 * PAD_MARGIN) * _config.block_size
		await _capture("species-%s" % name,
			_fit(cx, bay, h, 6.0, 12.0, h), _look_at(cx, h))

	print("[Gallery] done, %d images in %s" % [1 + _by_species.size(), _out_dir])
	get_tree().quit()


func _tallest(group: Array) -> float:
	var h := 0.0
	for s in group:
		h = maxf(h, float(s["height_m"]))
	return h


## What the camera aims at: a little below the middle of the tallest thing in
## frame.
##
## Aiming at the true middle puts a third of the picture under the pad. Aiming
## low keeps the crown - which is the part being judged - in the upper half,
## where it reads against the sky rather than against grass.
func _look_at(cx: float, height_m: float) -> Vector3:
	return Vector3(cx, float(GROUND) * _config.block_size + height_m * 0.40, 0.0)


## Where to stand so a box this size fills the frame.
##
## COMPUTED, NOT GUESSED, and that is the whole reason the gallery can be
## trusted across stages. The pad grows from one species to seven between
## Stage 1 and Stage 3; a camera at a hardcoded distance would photograph a
## postage stamp on the first run and crop the outer species on the last, and
## the two images could not be compared with each other. Fitting the subject
## means the framing changes exactly when the subject does.
##
## MEASURE THE SUBJECT, NOT THE LAYOUT CONSTANTS. The first version of this
## multiplied the species count by the bay pitch, which was right until the
## species wrapped into two rows - after which it claimed the pad was seventy
## per cent wider than it is and shot the whole gallery from too far away.
## Reading the extent the specimens actually landed in cannot drift like that.
##
## Godot's `fov` is the VERTICAL angle, so the horizontal one has to be
## recovered through the aspect ratio - getting that backwards crops the sides
## on a wide window, which is every window here.
func _fit(cx: float, width_m: float, height_m: float, depth_m: float,
		pitch_deg: float, look_height_m: float) -> Vector3:
	var aspect := float(get_viewport().get_visible_rect().size.aspect())
	var tan_v := tan(deg_to_rad(_camera.fov) * 0.5)
	var tan_h := tan_v * aspect
	var need_h := (width_m * 0.5) / maxf(tan_h, 0.001)
	# Rows recede as well as spread, so the pad's depth counts towards what has
	# to fit vertically once the camera is tilted down onto it.
	var need_v := (height_m * 0.5 + depth_m * 0.30) / maxf(tan_v, 0.001)
	# 1.12 leaves a margin of sky and pad around the subject. Without it the
	# outermost crown touches the frame edge and the shot reads as cropped.
	var dist := maxf(maxf(need_h, need_v), 8.0) * 1.12
	var pitch := deg_to_rad(pitch_deg)
	return _look_at(cx, look_height_m) \
		+ Vector3(0.0, sin(pitch), -cos(pitch)) * dist


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


func _capture(image_name: String, eye: Vector3, look: Vector3) -> void:
	_camera.global_position = eye
	_camera.look_at(look, Vector3.UP)
	await _settle()
	# The image is only valid once the frame has actually been drawn.
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, image_name]
	var err := image.save_png(path)
	if err != OK:
		push_warning("[Gallery] could not write %s: %s" % [path, error_string(err)])
	else:
		print("[Gallery]   -> %s (%dx%d)" % [path, image.get_width(), image.get_height()])


# --- Helpers ----------------------------------------------------------------

func _to_metres(bx: int, by: int, bz: int) -> Vector3:
	return Vector3(float(bx), float(by), float(bz)) * _config.block_size


## `--label NAME` -> res://build/gallery/NAME. Sanitised the same way the tour
## sanitises its own, and for the same reason: it becomes a directory name.
func _resolve_out_dir() -> String:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--label")
	if i < 0 or i + 1 >= argv.size():
		return OUT_DIR
	var label := argv[i + 1].strip_edges()
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


# --- A world of scratch chunks ----------------------------------------------

## Somewhere to stamp a tree that is not the world.
##
## The species stamper writes into a Chunk and asks nothing else of its caller,
## which is what makes this possible: the gallery supplies chunks that are not
## part of any terrain, and gets back exactly the tree the world would draw.
## Chunks are created on demand, so a tall specimen simply reaches into a
## chunk that did not exist a moment ago instead of being clipped by one that
## was never allocated.
class ScratchVolume extends RefCounted:
	var chunks := {}   # Vector3i -> Chunk

	func chunk_at(cpos: Vector3i) -> Chunk:
		var c: Chunk = chunks.get(cpos)
		if c == null:
			c = Chunk.new(cpos)
			chunks[cpos] = c
		return c

	## Write one block anywhere. `only_air` matches the world's rule: leaves go
	## over air only, so a canopy never eats its own trunk.
	func set_block(bx: int, by: int, bz: int, id: int, only_air: bool = false) -> void:
		var p := Vector3i(bx, by, bz)
		var chunk := chunk_at(Chunk.world_to_chunk(p))
		var l := Chunk.world_to_local(p)
		if only_air and chunk.voxels[Chunk.index(l.x, l.y, l.z)] != Block.AIR:
			return
		chunk.set_voxel(l.x, l.y, l.z, id)

	## The mesher's neighbour question. A chunk that does not exist is air,
	## which is right: outside the pad there is nothing.
	func solid_at(wx: int, wy: int, wz: int) -> bool:
		var p := Vector3i(wx, wy, wz)
		var chunk: Chunk = chunks.get(Chunk.world_to_chunk(p))
		if chunk == null:
			return false
		var l := Chunk.world_to_local(p)
		return Block.is_solid(chunk.voxels[Chunk.index(l.x, l.y, l.z)])
