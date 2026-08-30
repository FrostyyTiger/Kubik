extends SceneTree

## Counts the blocks a tree shape leaves FLOATING - touching the rest of the
## tree at an edge or a corner, or at nothing at all.
##
##     godot --headless --path . --script scripts/tools/loose_check.gd
##     godot --headless --path . --script scripts/tools/loose_check.gd -- birch
##     godot --headless --path . --script scripts/tools/loose_check.gd -- birch beech
##
## WHY THIS EXISTS, AND WHY IT IS NOT PART OF THE SELF-TEST.
##
## `_test_species_borders` proves a tree is the SAME tree however the chunk
## boundaries cut it up. It says nothing about whether that tree is a connected
## object, because the writer will happily place a leaf block with six faces
## against air - and on a shape hashed from a cell, a stranded block is not a
## crash or a wrong pixel. It is one leaf hanging in the sky, on one tree in
## thirty, which nobody sees in a gallery sheet and everybody sees in the world.
##
## THE INSTRUMENT IS A FLOOD FILL FROM THE GROUND. Draw a specimen into an
## unbounded buffer - the whole tree, clipped by nothing, through the same
## `stamp_specimen_at()` the gallery uses - seed a six-connected flood on every
## block standing on the pad, and count what the flood could not reach. There is
## no tolerance and no judgement in it: a tree is connected or it is not.
##
## WHAT IT HAS CAUGHT. Trees v1 Stage 1, judge round 3: 3,002 loose blocks on
## spruce and 18,548 on larch, from per-block holes in a sparse crown, plus a
## dead stub and a leader nub each aimed down a DIAGONAL golden direction onto a
## cell that touched the trunk at an edge and no face. Stage 2: 9,813 loose
## blocks over 1,673 birches - whole bowed stems adrift above their own feet,
## because the bridging that keeps a one-wide stem connected was firing only on
## a diagonal step when an axis step strands it just as thoroughly.
##
## Stage 3: the krummholz, which this file recorded as knowingly broken through
## two stages - about a thousand loose blocks over the sweep, two per tree at
## worst, because `_draw_mound` leaned its trunk one block sideways and the
## half-ellipsoid it carried shed cells off the bottom edge on the far side.
## The cushion that replaced it goes through `_whorl_disc`, whose per-layer
## flood settles the question by construction rather than by argument.
##
## WHAT IT KNOWS IS STILL BROKEN: nothing. All seven species are green, and the
## rule from here is that they stay that way - a shape stage that turns one of
## them red is not done.
##
## THE SAMPLE IS THE GALLERY'S, PLUS A SWEEP. The exact specimens the gallery
## photographs - three sizes, eight `--vary` cells, twelve `--stand` cells - so
## a number here can be read against a picture there, and then 150 further cells
## at eleven size steps each, which is what turns "the specimens look fine" into
## "no arrangement of this shape's hashes strands anything". 1,673 trees per
## species.

## The pad altitude specimens are stamped onto. Anything sitting on it is a
## seed; the number itself only has to be clear of the bottom of the world.
const GROUND := 40

## Cells in the sweep, and size steps at each cell.
const SWEEP := 150
const STEPS := 11

## The gallery's own layout constants, mirrored rather than imported, because
## `model_gallery.gd` is a Node3D scene script and this is a SceneTree tool. If
## the gallery's cells ever move, these move with them - the point of sharing
## them is that a loose block found here has a picture there.
const VARY_CELL_ORIGIN := Vector2i(100000, 200000)
const VARY_CELL_STEP := Vector2i(97, 61)
const VARY_COUNT := 8
const STAND_CELL_ORIGIN := Vector2i(300000, 400000)
const STAND_COLS := 4
const STAND_ROWS := 3
const SALT_STAND_SIZE := 901
const STAND_SIZE_STEPS := 10

## The sweep's own cells. Far from the gallery's and far from any world's.
const SWEEP_ORIGIN := Vector2i(500000, 600000)
const SWEEP_STEP := Vector2i(131, 137)


## A writer that clips to nothing, so the buffer is the WHOLE tree.
##
## `only_air` is honoured exactly as the world's writers honour it, or the
## trunk would be painted over by its own foliage and the flood would start
## from a block that is not there.
class LooseWriter extends RefCounted:
	var blocks := {}

	func set_block(bx: int, by: int, bz: int, id: int, only_air: bool) -> void:
		var pos := Vector3i(bx, by, bz)
		if only_air and blocks.has(pos):
			return
		blocks[pos] = id


func _init() -> void:
	var cfg := WorldgenConfig.new()
	var wanted := []
	for arg in OS.get_cmdline_user_args():
		wanted.append(String(arg))

	var bad := 0
	for species in TreeSpecies.table(cfg).size():
		var name := String(TreeSpecies.table(cfg)[species]["name"])
		if not wanted.is_empty() and not wanted.has(name):
			continue
		var loose := 0
		var total := 0
		var worst := 0
		var trees := _cells(species, cfg)
		for entry in trees:
			var cell: Vector2i = entry[0]
			var w := LooseWriter.new()
			TreeSpecies.stamp_specimen_at(w, species, 0, GROUND, 0,
				float(entry[1]), cell.x, cell.y, cfg)
			var n := _loose(w.blocks)
			if n > worst:
				worst = n
				print("  %s worst so far: cell %s t=%.2f, %d loose of %d" % [
					name, cell, float(entry[1]), n, w.blocks.size()])
			loose += n
			total += w.blocks.size()
		print("%s: %d specimens, %d blocks, %d LOOSE (worst tree %d)" % [
			name, trees.size(), total, loose, worst])
		if loose > 0:
			bad += 1
	print("loose check: %d species with floating blocks" % bad)
	quit(0 if bad == 0 else 1)


## Every (cell, size) this species is checked at.
func _cells(species: int, _cfg: WorldgenConfig) -> Array:
	var out := []
	for j in 3:
		var t := float(j) * 0.5
		out.append([TreeSpecies.specimen_cell(species, t), t])
	for i in VARY_COUNT:
		out.append([VARY_CELL_ORIGIN + VARY_CELL_STEP * i, 0.5])
	for r in STAND_ROWS:
		for c in STAND_COLS:
			var cx := STAND_CELL_ORIGIN.x + c
			var cz := STAND_CELL_ORIGIN.y + r
			out.append([Vector2i(cx, cz), float(WorldHash.hash_range(
				cx, cz, TreeSpecies.SPECIMEN_SEED, SALT_STAND_SIZE,
				0, STAND_SIZE_STEPS)) / float(STAND_SIZE_STEPS)])
	for i in SWEEP:
		for j in STEPS:
			out.append([SWEEP_ORIGIN + SWEEP_STEP * i,
				float(j) / float(STEPS - 1)])
	return out


## Blocks the flood from the ground could not reach.
##
## SIX-CONNECTED, because that is what "attached" means to the eye: two blocks
## meeting at an edge or a corner share no face, and the mesher draws both of
## their faces, so the pair reads as two objects and not one.
func _loose(blocks: Dictionary) -> int:
	var seen := {}
	var stack: Array[Vector3i] = []
	for pos in blocks:
		if pos.y == GROUND + 1:
			seen[pos] = true
			stack.push_back(pos)
	while not stack.is_empty():
		var p: Vector3i = stack.pop_back()
		for d in DIRS:
			var q: Vector3i = p + d
			if blocks.has(q) and not seen.has(q):
				seen[q] = true
				stack.push_back(q)
	return blocks.size() - seen.size()


const DIRS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
