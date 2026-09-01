extends Node3D

## Photographs every tree species and every plant model, side by side, against
## a known camera and a frozen noon sun.
##
##     godot --path . scenes/gallery.tscn -- --label some-name
##     godot --path . scenes/gallery.tscn -- --label some-name --vary spruce 8
##     godot --path . scenes/gallery.tscn -- --label some-name --stand spruce
##     godot --path . scenes/gallery.tscn -- --label some-name --masks
##     godot --path . scenes/gallery.tscn -- --label some-name --trees
##
## THE THREE EXTRA MODES ARE TREES V1 STAGE 0, and they exist because the
## default sheet answers a question the trees epic is not asking. Three sizes
## of one species is the right instrument for a size range and the wrong one
## for VARIATION: it photographs one tree three times, so two spruces that are
## the same spruce look exactly as they should. `--vary` puts n specimens of
## one species at one size side by side, `--stand` puts a dozen of them at the
## spacing the world actually plants them at - which is where a repeated
## silhouette gives itself away - and `--masks` turns the eye's answer into a
## number.
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

## Metres between plant models in the 1:1 strip. Wide enough that a 90 cm heath
## shrub does not touch its neighbours.
const PLANT_SPACING_M := 1.4

## Metres between rows of the plant grid.
const PLANT_ROW_M := 1.6

## Metres of clear ground between one model and the next, on top of the width
## of the widest model in that row.
const PLANT_GAP_M := 0.6

## Models per row before wrapping.
##
## NINETEEN MODELS IN ONE LINE IS 27 m, and a camera far enough back to fit
## that photographs each plant about forty pixels wide - which is no more use
## than the wide tree shot was. Wrapping into rows of six keeps the strip under
## nine metres, which is close enough to read a mushroom cap from.
const PLANTS_PER_ROW := 6

## Blocks of empty pad in FRONT of the trees, for the 1:1 strip to stand on.
##
## APRON, NOT MARGIN, and it needs to be this deep for a reason worth stating:
## the plant close-up is shot from about a metre away at knee height, and at
## that distance and that angle anything within a few metres behind fills the
## frame. With the strip tucked against the front row, the first shot came back
## as a krummholz with two specks of grass in front of it. Ten metres of clear
## ground puts the trees where they belong - in the background, at background
## size.
const PLANT_APRON := 20

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

# --- The variation instruments (trees v1 Stage 0) ---------------------------

enum {
	MODE_GALLERY = 0,   # the default sheet: every species at three sizes
	MODE_VARY = 1,      # --vary <species> <n>
	MODE_STAND = 2,     # --stand <species>
	MODE_MASKS = 3,     # --masks
	MODE_TREES = 4,     # --trees  (trees v3 Stage 2)
}

## The size `--vary` and `--masks` compare variation at.
##
## THE MIDDLE OF THE RANGE, because that is where a species spends most of its
## population and where a shape has room to be wrong in both directions. It is
## also the size the species-pair matrix is taken at, so one number can be read
## against another without asking which tree it came from.
const VARY_SIZE := 0.5

## How many specimens the TWINS measurement compares.
const TWIN_COUNT := 8

## The cells a variation row hashes its specimens from.
##
## FIXED, FAR FROM THE WORLD'S, AND FAR FROM stamp_specimen()'s OWN, so a
## variation row is reproducible between stages: specimen 3 of a spruce is the
## same tree tonight as in three stages' time, and any difference in the
## picture is a difference in the shape code rather than a difference in the
## draw. The two strides are odd and coprime so no two specimens land on cells
## that differ by a shift the hash might not have mixed away.
const VARY_CELL_ORIGIN := Vector2i(100000, 200000)
const VARY_CELL_STEP := Vector2i(97, 61)

## Trees in a `--stand`, and how they are laid out.
##
## A DOZEN, IN A GRID AT THE WORLD'S OWN CELL PITCH. The number is the plan's;
## the pitch is `tree_cell_blocks`, read from the config rather than typed, and
## the jitter is the same +/- the world jitters a trunk off its lattice by. A
## stand photographed at a spacing the world never plants at would answer a
## question nobody asked.
const STAND_COLS := 4
const STAND_ROWS := 3

## The cells a stand hashes from, and the salt it picks each tree's SIZE with.
##
## A GALLERY-SIDE SALT, deliberately nowhere near the world's band. Salts 200
## to 299 belong to worldgen and are part of what a seed means; this one is
## read by nothing that ever writes a world block, so it lives well outside
## them where it cannot collide with a shape salt a later stage adds.
const STAND_CELL_ORIGIN := Vector2i(300000, 400000)
const SALT_STAND_SIZE := 901
const SALT_STAND_JITTER_X := 902
const SALT_STAND_JITTER_Z := 903

## Sizes a stand draws from, as tenths.
##
## QUANTISED, not continuous, for one reason: `t` is printed on every cost line
## and a cost table is only greppable if the same tree always prints the same
## string.
const STAND_SIZE_STEPS := 10

## Where the camera aims, as a fraction of the subject's height. See _look_at().
const LOOK_FRACTION := 0.40

var _config: WorldgenConfig = null
var _camera: Camera3D = null
var _out_dir := OUT_DIR
var _mode := MODE_GALLERY

## `--vary`/`--stand`'s subject: the species id and the name it was asked for.
var _subject := -1
var _subject_name := ""
var _vary_count := TWIN_COUNT

## One entry per specimen actually built: {"name", "size", "center" (Vector3 in
## metres), "height_m", "blocks", "quads"}. The close-up pass reads this rather
## than recomputing the layout, so the two can never disagree about where a
## tree is.
var _specimens: Array = []

## Species name -> the specimens belonging to it, in min/mid/max order.
var _by_species := {}

## Where the 1:1 plant strip ended up, in metres: x from, x to, and its z.
## Recorded by _build_plant_strip() so the close-up can frame exactly what was
## built rather than recomputing the layout and drifting from it.
var _plant_span := Vector3(0.0, 0.0, 0.0)
var _plant_tallest := 0.0
var _plant_depth := 0.0


func _ready() -> void:
	_config = WorldgenConfig.load_or_default()
	_config.apply_cli_overrides(OS.get_cmdline_user_args())
	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	var sky: SkyCycle = $SkyCycle
	sky.setup(_config, $Sun, $WorldEnvironment)
	sky.time_of_day = _resolve_time()
	sky.frozen = true
	sky.apply()

	_camera = $Camera3D
	_camera.current = true

	_resolve_mode()
	# TREES V3 STAGE 7: THE BLOCK-TREE MODES ARE RETIRED WITH THE BLOCK TREES.
	#
	# `--vary`, `--stand` and `--masks` were trees v1 Stage 0's instruments and
	# good ones - a variation row, a stand at the world's own cell pitch, and a
	# silhouette metric that turned "they're all the same" into TWINS 1.00 ->
	# 0.72 on seven species. Every one of them stamped a SHAPE FUNCTION into a
	# scratch volume, and there are no shape functions.
	#
	# They are not reimplemented against the library, and that is a decision
	# rather than an omission. Variety is `variant library x rotation x scale
	# jitter` now (trees v2 decision 4, carried into v3), so "do two spruces
	# look the same" is answered by counting rows in `TreeTable` rather than by
	# measuring silhouettes - and `--trees` photographs every variant beside
	# the player capsule, which is the picture those modes were reaching for.
	if _mode == MODE_VARY or _mode == MODE_STAND or _mode == MODE_MASKS:
		print("[Gallery] --vary, --stand and --masks retired with the block trees")
		print("[Gallery] (trees v3 Stage 7). Use --trees: every library variant,")
		print("[Gallery] beside the player capsule, and every LOD beside its LOD0.")
		get_tree().quit()
		return
	if _mode == MODE_TREES:
		# THE LIBRARY SHEET BUILDS NO PAD, for the same reason the mask sheet
		# does not: its subjects are loaded meshes rather than stamped blocks,
		# and it re-lays the frame out once per sheet.
		_shoot_trees.call_deferred()
		return
	_build()
	_shoot.call_deferred()


# --- Building the pad -------------------------------------------------------

func _build() -> void:
	var vol := ScratchVolume.new()
	# TREES V3 STAGE 7: THE SPECIES ROWS ARE GONE AND THE PLANT STRIP IS NOT.
	#
	# This laid out seven tree species at three sizes each and then a 1:1 strip
	# of ground cover beside them, so a 30 cm grass tuft and a 21 m spruce were
	# in one frame and the two rows of `DESIGN.md`'s read-against table could be
	# checked against each other. Half of that comparison moved: `--trees`
	# photographs the library beside the same player capsule, at the same 1:1,
	# under the same frozen noon sun. The plants keep this sheet.
	_stamp_pad(vol)
	_place_plant_models()
	_publish(vol)
	_place_scale_figure(_pad_min().x + 6)

func _print_cost(name: String, t: float, blocks: int, quads: int,
		cell: Vector2i) -> void:
	print("[Cost] %s t=%.1f blocks %d quads %d cell (%d, %d)" % [
		name, t, blocks, quads, cell.x, cell.y])
func _mesh_quads(vol: ScratchVolume, root: Node3D) -> int:
	var indices := 0
	for cpos in vol.chunks:
		var chunk: Chunk = vol.chunks[cpos]
		var mesh := ChunkMesher.build(chunk, vol.solid_at, _config, 0)
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			# The index COUNT, not the index array. surface_get_arrays() copies
			# the whole vertex stream out of the mesh to answer a question about
			# its length, and the pad is sixty-odd chunks of it.
			indices += mesh.surface_get_array_index_len(s)
		if root != null:
			var node := MeshInstance3D.new()
			node.mesh = mesh
			node.position = Vector3(chunk.origin()) * _config.block_size
			root.add_child(node)
	return indices / 6


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
	# THE APRON IS THE DEFAULT SHEET'S ALONE. It is ten metres of clear ground
	# for the 1:1 plant strip to stand on, and --vary and --stand build no
	# strip - so on those it is just a tongue of meadow sticking out of the
	# bottom of the frame, taking up the room the trees wanted.
	var apron := PLANT_APRON if _mode == MODE_GALLERY else 0
	lo -= Vector2i(PAD_MARGIN, PAD_MARGIN + apron)
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
	_mesh_quads(vol, root)


## The player, for scale, at 1:1.
##
## Trees are 1:4 landscape and plants are 1:1, and the whole reason the scale
## table in the plan has two rows is that those two numbers are easy to mix up
## when everything is grey boxes. A capsule of exactly the player's dimensions
## standing in the same frame is what makes a 12 cm grass tuft obviously wrong.
func _place_scale_figure(bx: int) -> void:
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
	var z: float = _plant_span.z if _plant_span.y > _plant_span.x \
		else float(_pad_min().y + 4) * _config.block_size
	node.position = Vector3(float(bx) * _config.block_size,
		float(GROUND + 1) * _config.block_size + height_m * 0.5, z)
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
##
## SORTED BY SIZE, AND SPACED BY WHAT IS ACTUALLY IN THE ROW.
##
## A fixed spacing works only while every model is about the same size, and
## these are not: an alpine flower is 12 cm and a large boulder is 3 m, a factor
## of twenty-five. At a spacing that suits the flowers the boulder swallows its
## neighbours whole - the first version of this hid two models completely - and
## at a spacing that suits the boulder the flowers are four pixels apart in a
## field of grass.
##
## So the meshes are built FIRST, measured, and sorted; each row is then spaced
## by the widest thing in it. Small models end up together and tightly packed,
## large ones together and generously spaced, and the strip stays readable
## however many models Stage 6 or a later plan adds.
func _build_plant_strip() -> void:
	var script := load("res://scripts/world/flora/flora_models.gd")
	if script == null:
		return
	var names: Array = script.gallery_names()

	# Build and measure before placing anything.
	var built: Array = []
	for n in names:
		var mesh: ArrayMesh = script.build_mesh(n)
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		built.append({"name": n, "mesh": mesh, "aabb": aabb,
			"span": maxf(aabb.size.x, aabb.size.z)})
	built.sort_custom(func(a, b): return a["span"] < b["span"])

	var root := Node3D.new()
	root.name = "Plants"
	add_child(root)
	var box := _extent()
	var ground := float(GROUND + 1) * _config.block_size
	var x0 := float(box.position.x + 10) * _config.block_size
	var z := float(box.position.y + 4) * _config.block_size

	var i := 0
	var widest_row := 0.0
	while i < built.size():
		var row: Array = built.slice(i, mini(i + PLANTS_PER_ROW, built.size()))
		var pitch := 0.0
		var depth := 0.0
		for e in row:
			pitch = maxf(pitch, float(e["span"]))
			depth = maxf(depth, float(e["aabb"].size.z))
		pitch += PLANT_GAP_M
		for c in row.size():
			var e: Dictionary = row[c]
			var node := MeshInstance3D.new()
			node.mesh = e["mesh"]
			node.material_override = script.gallery_material_for(e["name"])
			# CAST NO SHADOWS, because the world does not - FloraColumn turns
			# shadow casting off on every flora MultiMesh, and a gallery that
			# lit its models differently from the game would be showing you
			# something the game never draws.
			#
			# It also removes an artefact that looked like a modelling bug and
			# was not: a rounded voxel blob self-shadowing without a normal
			# bias bands horizontally, and boulders and shrubs came back
			# striped as though slices were missing out of them.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.position = Vector3(x0 + float(c) * pitch, ground, z)
			root.add_child(node)
			_plant_tallest = maxf(_plant_tallest, float(e["aabb"].size.y))
		widest_row = maxf(widest_row, float(row.size() - 1) * pitch)
		z += depth + PLANT_GAP_M
		i += PLANTS_PER_ROW

	_plant_span = Vector3(x0, x0 + widest_row,
		(float(box.position.y + 4) * _config.block_size + z) * 0.5)
	_plant_depth = z - float(box.position.y + 4) * _config.block_size
	print("[Gallery] %d plant models, %d rows, tallest %.2f m, strip %.1f x %.1f m" % [
		built.size(), int(ceil(float(built.size()) / float(PLANTS_PER_ROW))),
		_plant_tallest, widest_row, _plant_depth])


# --- Taking the pictures ----------------------------------------------------

func _shoot() -> void:
	await _settle()

	# TREES V3 STAGE 7: THE WIDE SHOT AND THE PER-SPECIES CLOSE-UPS WENT WITH
	# THE SPECIES ROWS. What is left is the picture this sheet was always best
	# at and `--trees` cannot take: ground cover at 1:1, from a metre away, with
	# the player capsule in frame.
	await _shoot_plants()


	print("[Gallery] done, %d images in %s" % [1, _out_dir])
	get_tree().quit()


## THE 1:1 STRIP, CLOSE UP, WITH THE PLAYER IN FRAME.
##
## The wide shot cannot serve for this and it is not a framing problem, it is a
## scale problem: a 30 cm grass tuft photographed from far enough back to fit
## seven trees is four pixels tall. Ground cover has to be judged from where a
## player would see it - a metre or two away, at about eye height - and beside
## something whose size is not in question.
##
## THE CAPSULE IS THE WHOLE POINT OF THE SHOT. Plants are the one thing in this
## world drawn at 1:1 while the landscape around them is at 1:4, so "is this
## the right size" cannot be answered by looking at the tree behind it. It can
## only be answered against the player, and this is the only frame the two
## appear in together.
func _shoot_plants() -> void:
	if _plant_span.y <= _plant_span.x:
		print("[Gallery] no plant strip to photograph yet")
		return
	var player_h: float = _config.player_height_blocks * _config.block_size
	# The capsule stands to the left of the strip; include it.
	# 1.8 m of margin on the capsule's side, not 0.6: the capsule is 2 m tall
	# and 80 cm wide, and a frame that ends exactly at its centre line cuts it
	# in half - which is what the first version did, leaving its shadow in the
	# picture and the ruler itself outside it.
	var left := minf(_plant_span.x,
		float(_pad_min().x + 4) * _config.block_size) - 1.8
	var right := _plant_span.y + 0.6
	var cx := (left + right) * 0.5
	var ground := float(GROUND + 1) * _config.block_size
	var subject_h := maxf(player_h, _plant_tallest) * 1.15

	var aspect := float(get_viewport().get_visible_rect().size.aspect())
	var tan_v := tan(deg_to_rad(_camera.fov) * 0.5)
	var dist := maxf((right - left) * 0.5 / maxf(tan_v * aspect, 0.001),
		(subject_h * 0.5 + _plant_depth * 0.3) / maxf(tan_v, 0.001)) * 1.15

	# Low and barely tilted - the angle a standing player looks down at their
	# own feet from, rather than a plan view.
	var look := Vector3(cx, ground + subject_h * 0.35, _plant_span.z)
	var pitch := deg_to_rad(20.0)
	await _capture("plants",
		look + Vector3(0.0, sin(pitch), -cos(pitch)) * dist, look)


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
	return Vector3(cx,
		float(GROUND) * _config.block_size + height_m * LOOK_FRACTION, 0.0)


## The `height_m` to hand _fit() so a tree this tall fits ENTIRELY in frame.
##
## THE FRAMING BUG THIS FIXES CUT THE TOP OFF THE TALLEST SPRUCE AND THE HERO
## in every gallery sheet up to trees v1 - and it is arithmetic, not taste.
## _fit() treats `height_m` as a span CENTRED on the look point, and _look_at()
## puts the look point at 0.40 of the subject's height rather than at half of
## it. So the crown stands 0.60 h above the axis while only 0.50 h of it was
## ever being fitted, and the taller the species the more of it was outside the
## frame. The wide shot survived on the 1.12 margin; the close-ups did not.
##
## The second term is the DOWN-PITCH, which the flat version ignored. A camera
## tilted down by p sees a point dy above its aim point at
## atan(dy cos p / (d - dy sin p)) - the tilt carries the eye up and forward,
## which brings the crown nearer in depth and therefore wider in angle. Solving
## that for d and turning it back into the span _fit() would have needed is the
## `sin p * tan_v` term. At 12 degrees it is worth about a sixth of the answer,
## which is a whole whorl on a max spruce.
func _fit_span(height_m: float, pitch_deg: float) -> float:
	var above := height_m * (1.0 - LOOK_FRACTION)
	var p := deg_to_rad(pitch_deg)
	var tan_v := tan(deg_to_rad(_camera.fov) * 0.5)
	return 2.0 * above * (cos(p) + sin(p) * tan_v)
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
	_save_image(await _shutter(), image_name)


## Settle, wait for the frame to actually exist, and read it back.
func _shutter() -> Image:
	await _settle()
	# The image is only valid once the frame has actually been drawn.
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _save_image(image: Image, image_name: String) -> void:
	var path := "%s/%s.png" % [_out_dir, image_name]
	var err := image.save_png(path)
	if err != OK:
		push_warning("[Gallery] could not write %s: %s" % [path, error_string(err)])
	else:
		print("[Gallery]   -> %s (%dx%d)" % [path, image.get_width(), image.get_height()])


# --- The silhouette metric --------------------------------------------------
#
# THE TEST THE TREE REDESIGN HANGS ON, and the reason it is built before any
# shape moves. The complaint trees v1 answers is "no variation, they're all
# symmetrical" - which is a claim about OUTLINES, so it is measured on
# outlines, exactly as character v2 measured its races. Three numbers:
#
#   SYMMETRY   a mask against its own mirror image. 1.0 is a solid of
#              revolution seen end on, which is what every crown in this file
#              is today: a stack of centred discs has no left and no right.
#   TWINS      the median pairwise overlap of eight specimens of one species at
#              ONE size, hashed from eight different cells. 1.0 means the cell
#              decides nothing - that a spruce is a stamp.
#   PAIRS      the seven-by-seven species matrix at t = 0.5, which is the
#              question the size row was already answering by eye: can you tell
#              a larch from a spruce with the colour taken away.
#
# The starting targets (trees v1 Stage 0): SYMMETRY median <= 0.80, TWINS
# median <= 0.85, no species pair above 0.70 except spruce/larch, which are the
# same archetype and are separated by openness and colour rather than outline.
# They are targets to be judged against pictures, not gates to be tuned to.
#
# The pure-image half of the machinery - _crop_mask, _mask_iou, _mask_at - is
# ported from character_gallery.gd unchanged, so the two galleries' numbers
# mean the same thing. The scene half is NOT shared: a character rig and a
# scratch volume of blocks have nothing in common but the intent, and one
# gallery reaching into the other's node tree to borrow a camera would couple
# two tools that are going to keep diverging.

## Anything darker than this on the white background is silhouette. Generous,
## because the edges of an unshaded black mesh are antialiased against white
## and a threshold at the midpoint would eat a voxel off every outline.
const MASK_THRESHOLD := 0.75

## Metres of clear ground under the tree in a mask frame. Enough that the base
## is not touching the bottom edge, which would make _crop_mask's bounding box
## depend on where the pad ended rather than on where the tree does.
const MASK_FLOOR_M := 1.0

## How far the mask camera stands off. It is an ORTHOGONAL camera, so this
## changes nothing about the picture and only has to clear the subject.
const MASK_DISTANCE := 120.0

## The mask sheet's subdirectory under the label.
const MASK_SUBDIR := "masks"

var _mask_material: StandardMaterial3D = null
var _mask_root: Node3D = null


func _enter_mask_mode() -> void:
	_mask_material = StandardMaterial3D.new()
	_mask_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mask_material.albedo_color = Color.BLACK
	var env: Environment = ($WorldEnvironment as WorldEnvironment).environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.fog_enabled = false
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_mask_root = Node3D.new()
	_mask_root.name = "Mask"
	add_child(_mask_root)


func _leave_mask_mode() -> void:
	for child in _mask_root.get_children():
		child.free()


func _paint_mask(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _mask_material
	for child in node.get_children():
		_paint_mask(child)


## The non-white pixels of an image, cropped to their bounding box.
##
## Ported verbatim from character_gallery.gd. Returned as a flat byte array
## rather than an Image so the IoU loop is plain indexing - a 1280 x 720
## get_pixel() per comparison would be four hundred thousand engine calls per
## pair.
func _crop_mask(image: Image) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	var hit := PackedByteArray()
	hit.resize(w * h)
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			var on := (c.r + c.g + c.b) / 3.0 < MASK_THRESHOLD
			hit[x + y * w] = 1 if on else 0
			if on:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return {"w": 0, "h": 0, "bits": PackedByteArray()}

	var cw := hi.x - lo.x + 1
	var ch := hi.y - lo.y + 1
	var bits := PackedByteArray()
	bits.resize(cw * ch)
	for y in ch:
		for x in cw:
			bits[x + y * cw] = hit[(lo.x + x) + (lo.y + y) * w]
	return {"w": cw, "h": ch, "bits": bits}


## Overlap over union of two masks, aligned BOTTOM-CENTRE.
##
## Ported verbatim from character_gallery.gd. Bottom-centre because two trees
## compared in the world are standing on the same ground and seen from the same
## side. Aligning by centroid or by bounding box would let a krummholz and a
## hero overlap perfectly by sliding one up the frame, which is not a thing the
## eye can do at any distance.
func _mask_iou(a: Dictionary, b: Dictionary) -> float:
	if a["w"] == 0 or b["w"] == 0:
		return 0.0
	var w: int = maxi(a["w"], b["w"])
	var h: int = maxi(a["h"], b["h"])
	# Offsets that put each mask's bottom edge on the canvas bottom and its
	# horizontal middle on the canvas middle.
	var ax: int = (w - int(a["w"])) / 2
	var ay: int = h - int(a["h"])
	var bx: int = (w - int(b["w"])) / 2
	var by: int = h - int(b["h"])

	var both := 0
	var either := 0
	for y in h:
		for x in w:
			var in_a := _mask_at(a, x - ax, y - ay)
			var in_b := _mask_at(b, x - bx, y - by)
			if in_a and in_b:
				both += 1
			if in_a or in_b:
				either += 1
	return float(both) / float(either) if either > 0 else 0.0


func _mask_at(mask: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= int(mask["w"]) or y >= int(mask["h"]):
		return false
	return (mask["bits"] as PackedByteArray)[x + y * int(mask["w"])] != 0


## The tallest tree the table admits, in blocks - the mask frame's height.
func _tallest_in_table() -> int:
	var tallest := 1
	for row in TreeSpecies.table(_config):
		tallest = maxi(tallest, int(row["height"].y))
	return tallest


## A mask flipped left to right, in its own bounding box.
##
## THE MIRROR IS TAKEN OF THE CROP, not of the frame, so SYMMETRY asks whether
## a tree is symmetric about ITSELF rather than about wherever the camera put
## it. A tree that leans is then still symmetric if the lean is the only thing
## about it that is not - which is correct, and is exactly the distinction a
## whorl-arm crown has to beat.
func _mirror_mask(mask: Dictionary) -> Dictionary:
	var w: int = int(mask["w"])
	var h: int = int(mask["h"])
	if w == 0:
		return mask
	var src: PackedByteArray = mask["bits"]
	var bits := PackedByteArray()
	bits.resize(w * h)
	for y in h:
		for x in w:
			bits[x + y * w] = src[(w - 1 - x) + y * w]
	return {"w": w, "h": h, "bits": bits}


## The middle value, or the mean of the two middle ones.
##
## MEDIAN AND NOT MEAN, because one hero that hashed a spruce parent among
## seven that hashed a beech would drag a mean somewhere no specimen actually
## is. The median says what a typical pair of these trees looks like, which is
## the claim being made.
func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n % 2 == 1:
		return float(sorted[n / 2])
	return (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) * 0.5


# --- Helpers ----------------------------------------------------------------

func _to_metres(bx: int, by: int, bz: int) -> Vector3:
	return Vector3(float(bx), float(by), float(bz)) * _config.block_size


## `--time 0.95` photographs the models after dark instead of at noon.
##
## THE ONLY WAY TO SEE HALF OF WHAT STAGE 8 BUILT. A glowing mushroom cap and a
## firefly are both invisible by day on purpose - the firefly's vertices are
## scaled to zero - so a gallery that only ever shoots at noon can prove those
## models compile and never prove they light up.
func _resolve_time() -> float:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--time")
	if i >= 0 and i + 1 < argv.size():
		return clampf(argv[i + 1].to_float(), 0.0, 1.0)
	return GALLERY_TIME


## Which sheet this run is: the default one, a variation row, a stand, or masks.
##
## `--vary <species> <n>`, `--stand <species>`, `--masks`. A species that is not
## in the table is a typo worth stopping for rather than silently photographing
## the default sheet under a label that says otherwise - so it warns loudly and
## falls back, and the warning is the first line of the log.
func _resolve_mode() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.has("--trees"):
		_mode = MODE_TREES
		return
	if argv.has("--masks"):
		_mode = MODE_MASKS
		return

	var i := argv.find("--vary")
	if i >= 0 and i + 1 < argv.size():
		_subject = _species_id(argv[i + 1])
		if _subject >= 0:
			_mode = MODE_VARY
			_subject_name = argv[i + 1]
			_vary_count = TWIN_COUNT
			if i + 2 < argv.size() and argv[i + 2].is_valid_int():
				_vary_count = maxi(argv[i + 2].to_int(), 1)
		return

	i = argv.find("--stand")
	if i >= 0 and i + 1 < argv.size():
		_subject = _species_id(argv[i + 1])
		if _subject >= 0:
			_mode = MODE_STAND
			_subject_name = argv[i + 1]


## The table index of a species by name, or -1 with a warning.
func _species_id(species_name: String) -> int:
	for row in TreeSpecies.gallery_rows(_config):
		if String(row["name"]) == species_name:
			return int(row["id"])
	var names := PackedStringArray()
	for row in TreeSpecies.gallery_rows(_config):
		names.append(String(row["name"]))
	push_warning("[Gallery] no species called %s - it is one of %s" % [
		species_name, ", ".join(names)])
	print("[Gallery] no species called %s - it is one of %s" % [
		species_name, ", ".join(names)])
	return -1


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


# --- Trees v3 Stage 2: the library sheet -------------------------------------

## `--trees`: every variant in the purchased library, at 1:1, beside the player.
##
##     godot --path . scenes/gallery.tscn -- --label some-name --trees
##
## WHY THIS IS ITS OWN MODE AND NOT A ROW ON THE DEFAULT SHEET.
##
## The default sheet photographs SEVEN species at three sizes each, laid out by
## a builder that stamps blocks into a scratch volume. A library variant is not
## a species and has no size range - it is one sculpted model, exactly as tall
## as the artist drew it - and there are fifty-five of them. Threading that
## through `_build_species_rows` would have meant making the block stamper and
## the model loader interchangeable, which they are not and should not be.
##
## THE CAPSULE IS THE WHOLE POINT, exactly as it is for the plant strip.
## Ruling 3 moves the trees from 13-21 m to 21-28 m and calls that "the
## monumental north star, chosen with the numbers on the table". A number on a
## table is not a picture. This is the picture: every variant standing next to
## a capsule of the player's exact dimensions, so "is this the right size" is
## answered against the only thing whose size is not in question.
##
## AND EVERY LOD BESIDE ITS OWN LOD0, which is the other half of the gate.
## Ruling 4 replaces the impostor cards with downsampled versions of the same
## grid, and the claim it rests on is that the near/far seam becomes a
## RESOLUTION boundary rather than a KIND boundary. Three rungs of one tree in
## one frame is that claim, photographed.
##
## SELF-SKIPS WITHOUT THE LIBRARY, prints "no library" and exits 0 - which is
## the public build, and is a gate rather than a courtesy.
## FIVE PER SHEET, NOT EIGHT. Eight variants of Tree 09 side by side is 150 m
## of frame, which puts each tree at a hundred pixels - wide enough to count
## them and far too small to judge one. Five is the most that leaves a 25 m
## tree tall enough to read its crown against the sky.
const TREE_ROW := 5
const TREE_GAP_M := 3.0

## Extra headroom on the library sheets, over the default sheet's 1.12.
##
## A LIBRARY ROW IS MUCH WIDER THAN IT IS TALL, so its outermost subjects sit
## far off the camera axis - and a subject off-axis is projected OUTWARD and
## UPWARD by the perspective, which is what cropped the first sheet's leftmost
## crown while the middle tree fitted comfortably. The default sheet never hits
## this because its bays are narrow. This is the margin, not a framing fudge:
## the fit is the same fit.
const TREE_MARGIN := 1.34

func _shoot_trees() -> void:
	if not TreeModels.available():
		print("[Gallery] --trees: no library mounted, nothing to photograph")
		get_tree().quit()
		return

	var variants := TreeModels.variants()
	print("[Gallery] --trees: %d variants, %d rungs each" % [
		variants.size(), TreeModels.LOD_COUNT])

	# One sheet per row of variants, and one sheet per species' LOD ladder.
	var rows := []
	for i in range(0, variants.size(), TREE_ROW):
		rows.append(variants.slice(i, mini(i + TREE_ROW, variants.size())))

	var written := 0
	var missing := []
	for r in rows.size():
		var row: Array = rows[r]
		_clear_pad()
		var placed := _place_tree_row(row, 0, missing)
		if placed.is_empty():
			continue
		written += 1
		await _shoot_tree_frame("trees-%02d" % (r + 1), placed)

	# THE LOD LADDER, one sheet per pack species: its first variant at all
	# three rungs, side by side, at the same size. What must be visible is that
	# they are the SAME TREE getting coarser - not three different trees.
	for sp in TreeModels.species():
		var of_species := TreeModels.variants_of(sp)
		if of_species.is_empty():
			continue
		_clear_pad()
		var placed := _place_lod_ladder(StringName(of_species[0]))
		if placed.is_empty():
			continue
		written += 1
		await _shoot_tree_frame("lods-%s" % sp, placed)

	if not missing.is_empty():
		print("[Gallery] %d variants built no mesh: %s" % [
			missing.size(), ", ".join(missing)])
	print("[Gallery] done, %d images in %s" % [written, _out_dir])
	get_tree().quit()


## The library sheet's own pad: ground, and the capsule at the left of it.
func _clear_pad() -> void:
	for child in get_children():
		if child.name == "TreePad" or child.name == "ScaleFigure":
			remove_child(child)
			child.queue_free()


## Lay out one row of variants along X, each standing on the origin plane.
## Returns [{"name", "x", "height_m", "triangles"}], and appends any variant
## that built no mesh to `missing`.
func _place_tree_row(row: Array, lod: int, missing: Array) -> Array:
	var root := Node3D.new()
	root.name = "TreePad"
	add_child(root)
	var placed := []
	var x := 0.0
	for name in row:
		var mesh := TreeModels.mesh_for(name, lod, _config.block_size)
		if mesh == null:
			missing.append(String(name))
			continue
		var h := TreeModels.height_m(name)
		var aabb := mesh.get_aabb()
		# SPACED BY WHAT THE MESH ACTUALLY IS, not by a constant. Tree 09 is
		# 20 m wide and Tree 16 is 2 m; a fixed pitch would either overlap the
		# sprawlers or strand the stumps in empty frame.
		var half := maxf(aabb.size.x, 0.5) * 0.5
		x += half
		var node := MeshInstance3D.new()
		node.name = String(name)
		node.mesh = mesh
		node.position = Vector3(x, 0.0, 0.0)
		root.add_child(node)
		placed.append({
			"name": String(name), "x": x, "height_m": h,
			"triangles": TreeModels.triangles_for(name, lod, _config.block_size),
			"half": half,
		})
		x += half + TREE_GAP_M
	if not placed.is_empty():
		_place_tree_capsule(root, -2.0)
	return placed


## One variant at all three rungs, at the same place along Z, spread on X.
func _place_lod_ladder(variant: StringName) -> Array:
	var root := Node3D.new()
	root.name = "TreePad"
	add_child(root)
	var placed := []
	var x := 0.0
	for lod in TreeModels.LOD_COUNT:
		var mesh := TreeModels.mesh_for(variant, lod, _config.block_size)
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		var half := maxf(aabb.size.x, 0.5) * 0.5
		x += half
		var node := MeshInstance3D.new()
		node.name = "%s_lod%d" % [variant, lod]
		node.mesh = mesh
		node.position = Vector3(x, 0.0, 0.0)
		root.add_child(node)
		placed.append({
			"name": "%s lod%d" % [variant, lod], "x": x,
			"height_m": TreeModels.height_m(variant),
			"triangles": TreeModels.triangles_for(variant, lod, _config.block_size),
			"half": half,
		})
		x += half + TREE_GAP_M
	if not placed.is_empty():
		_place_tree_capsule(root, -2.0)
	return placed


## The ruler. Same dimensions as `_place_scale_figure`'s, standing on the same
## plane the trees do - which for a library model is y = 0, because the model's
## own origin is its bottom centre.
func _place_tree_capsule(root: Node3D, x: float) -> void:
	var height_m: float = _config.player_height_blocks * _config.block_size
	var mesh := CapsuleMesh.new()
	mesh.radius = _config.player_radius_blocks * _config.block_size
	mesh.height = height_m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.12, 0.14)
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.name = "Capsule"
	node.mesh = mesh
	node.position = Vector3(x, height_m * 0.5, 0.0)
	root.add_child(node)


## Frame a laid-out row and take the picture, printing the cost line.
func _shoot_tree_frame(image_name: String, placed: Array) -> void:
	var lo := -3.0
	var hi := 0.0
	var tallest := 0.0
	var total := 0
	for p in placed:
		lo = minf(lo, float(p["x"]) - float(p["half"]))
		hi = maxf(hi, float(p["x"]) + float(p["half"]))
		tallest = maxf(tallest, float(p["height_m"]))
		total += int(p["triangles"])
	var cx := (lo + hi) * 0.5
	var width := hi - lo
	# The look point and the fit are the default sheet's own, so a library
	# variant and a block species are framed by the same rule and their two
	# sheets can be held side by side.
	var look := Vector3(cx, tallest * LOOK_FRACTION, 0.0)
	var aspect := float(get_viewport().get_visible_rect().size.aspect())
	var tan_v := tan(deg_to_rad(_camera.fov) * 0.5)
	var need_h := (width * 0.5) / maxf(tan_v * aspect, 0.001)
	var need_v := (_fit_span(tallest, 6.0) * 0.5) / maxf(tan_v, 0.001)
	var dist := maxf(maxf(need_h, need_v), 8.0) * TREE_MARGIN
	# SIX DEGREES, not the default sheet's twelve. A library variant is judged
	# on its SILHOUETTE against the sky, and every degree of down-pitch trades
	# sky for pad.
	var pitch := deg_to_rad(6.0)
	_camera.global_position = look + Vector3(0.0, sin(pitch), -cos(pitch)) * dist
	_camera.look_at(look, Vector3.UP)
	_save_image(await _shutter(), image_name)
	var names := PackedStringArray()
	for p in placed:
		names.append("%s %.1fm %dtri" % [
			p["name"], p["height_m"], p["triangles"]])
	print("[Gallery]      %s: %d subjects, %d triangles - %s" % [
		image_name, placed.size(), total, ", ".join(names)])
