class_name TreeSpecies

## What a tree IS, separately from where one goes.
##
## Until foliage v1 a tree was one function in TerrainGenerator drawing a
## 1-block trunk and a cone of LEAVES: one species, one green, ~35,000 of them
## on seed 42, and they read as evenly scattered cones because that is exactly
## what they were. This file is the other half of the answer - the shapes - and
## `tree_placement.gd` is where they go.
##
##
## THE BORDER-SAFE STAMP IS THE PATTERN, AND EVERY SPECIES USES IT.
##
## A tree is rooted at one candidate cell and reaches several blocks sideways
## and twenty up, so it crosses chunk boundaries. Every chunk a tree touches
## draws its own share of it, and because every parameter is HASHED FROM THE
## CELL rather than drawn from a stream, all of them compute the same tree. A
## chunk generates identically whether it is built first, last, or on the other
## player's machine. `_test_tree_borders` in the self-test suite is the proof.
##
## What that costs is that a shape function may not depend on anything except
## its own arguments. No RNG state, no "how many blocks have I drawn", no
## Dictionary iteration order. Everything a species needs to know about itself
## comes out of `params_for()`, which is pure.
##
##
## WHY THE SHAPES WRITE THROUGH A WRITER OBJECT.
##
## The world stamps into a Chunk and clips to it. The model gallery stamps into
## a scratch volume with no clipping at all, so it can photograph a whole tree.
## Both want the SAME shape code - a gallery that drew a tree its own way would
## be flattering the model rather than photographing it - so the shapes take
## an object with `set_block(bx, by, bz, id, only_air)` and know nothing about
## which of the two they are drawing into.
##
## It costs one method call per block, which is exactly what the old
## `_set_if_inside()` cost, so the hot path is no worse than it was.

# --- Where a shape writes to --------------------------------------------------

## The world's writer: clips every block to one chunk.
##
## THIS IS THE BORDER-SAFE STAMP, and it is why a tree near a chunk boundary is
## not sliced in half. Every chunk a tree reaches into runs the whole shape
## function and throws away the blocks that are not its own. The shapes do not
## know that is happening and must not - a shape that tried to skip work
## outside the chunk would draw a different tree for each of its neighbours.
##
## One of these is built per chunk, not per tree.
class ChunkWriter extends RefCounted:
	var chunk: Chunk = null
	var origin := Vector3i.ZERO

	func bind(p_chunk: Chunk) -> void:
		chunk = p_chunk
		origin = p_chunk.origin()

	## `only_air` is what stops a canopy from eating its own trunk - leaves are
	## drawn over air only, trunk over anything.
	func set_block(bx: int, by: int, bz: int, id: int, only_air: bool) -> void:
		var lx := bx - origin.x
		var ly := by - origin.y
		var lz := bz - origin.z
		if not Chunk.in_bounds(lx, ly, lz):
			return
		if only_air and chunk.voxels[Chunk.index(lx, ly, lz)] != Block.AIR:
			return
		chunk.set_voxel(lx, ly, lz, id)


# --- Species ids ------------------------------------------------------------
#
# Indices into SPECIES. They are NOT block ids and never cross the network, so
# unlike Block they may be reordered - but the placement weight tables below
# are written in terms of them, so do not do it casually.

enum {
	SPRUCE = 0,
}

const COUNT := 1

## Salts. Every parameter a tree hashes gets its own, or a tree's height and
## its crown radius would agree with each other and every tall tree in the
## world would also be the widest one.
const SALT_TRUNK := 203
const SALT_CROWN := 204


## One row per species.
##
##   name        for the probe, the gallery and STATUS.md
##   trunk       min/max trunk height in blocks, before the crown
##   crown       min/max crown radius in blocks
##   leaves      block id, shade A
##   leaves_b    block id, shade B - the per-tree colour jitter
##   trunk_id    block id for the trunk
##   fill        probability a crown block exists at all; 1.0 is solid
##
## SPRUCE'S NUMBERS COME FROM THE CONFIG, not from this table, and that is
## deliberate for exactly one stage: Stage 2 moves the world's stamping onto
## this file and has to reproduce the baseline tree count EXACTLY, down to the
## last tree. Reading the same four knobs the old code read is what makes that
## checkable rather than hopeful. Stage 3 replaces them with the plan's own
## numbers and the world changes on purpose.
static func table(config: WorldgenConfig) -> Array:
	return [
		{
			"id": SPRUCE,
			"name": "spruce",
			"trunk": Vector2i(config.tree_trunk_min, config.tree_trunk_max),
			"crown": Vector2i(config.tree_canopy_min, config.tree_canopy_max),
			"leaves": Block.LEAVES,
			"leaves_b": Block.LEAVES,
			"trunk_id": Block.TRUNK,
			"fill": 1.0,
		},
	]


## How far above the ground the tallest possible tree reaches, in blocks.
##
## DERIVED FROM THE TABLE, NEVER TYPED. World reserves this much empty sky
## above the terrain when it decides which chunks of a column to build, and a
## constant that did not grow with the biggest species would silently cut the
## crown off every tree taller than whatever the number happened to be.
static func max_height(config: WorldgenConfig) -> int:
	var tallest := 0
	for row in table(config):
		tallest = maxi(tallest, row["trunk"].y + row["crown"].y + 3)
	return tallest


## How far sideways a crown can spread, in blocks. The margin `_place_trees()`
## widens its candidate scan by, and derived for the same reason.
static func max_reach(config: WorldgenConfig) -> int:
	var widest := 0
	for row in table(config):
		widest = maxi(widest, row["crown"].y)
	return widest


## Everything one tree needs to know about itself, hashed from its cell.
##
## Pure, and the whole determinism contract rests on that: two machines, two
## chunk build orders and two hemispheres of the map all call this with the
## same three integers and get the same tree back.
static func params_for(species: int, cell_x: int, cell_z: int,
		world_seed: int, config: WorldgenConfig) -> Dictionary:
	var row: Dictionary = table(config)[species]
	return {
		"species": species,
		"trunk": WorldHash.hash_range(cell_x, cell_z, world_seed, SALT_TRUNK,
			row["trunk"].x, row["trunk"].y),
		"crown": WorldHash.hash_range(cell_x, cell_z, world_seed, SALT_CROWN,
			row["crown"].x, row["crown"].y),
	}


## Draw one tree. `writer` is anything with set_block(bx, by, bz, id, only_air).
##
## `ground` is the altitude of the topmost SOLID block of the column the trunk
## stands on, so the first trunk block goes at ground + 1.
##
## Returns the number of blocks the shape asked for - which is not the number
## that landed, since the writer may be clipping to a chunk. The gallery uses
## it; the world ignores it.
static func draw(writer, species: int, bx: int, ground: int, bz: int,
		params: Dictionary, config: WorldgenConfig) -> int:
	match species:
		SPRUCE:
			return _draw_cone_v1(writer, bx, ground, bz, params, config)
	return 0


## THE ORIGINAL CONE, moved here unchanged from TerrainGenerator._stamp_tree().
##
## Kept exactly as it was, block for block, because Stage 2's whole job is to
## prove the move changed nothing: if the refactor displaced a single tree, it
## is wrong. Stage 3 gives the spruce its whorls and this becomes one shape
## among seven.
static func _draw_cone_v1(writer, bx: int, ground: int, bz: int,
		params: Dictionary, config: WorldgenConfig) -> int:
	var row: Dictionary = table(config)[SPRUCE]
	var trunk_height: int = params["trunk"]
	var crown: int = params["crown"]
	var drawn := 0

	for i in trunk_height:
		writer.set_block(bx, ground + 1 + i, bz, row["trunk_id"], false)
		drawn += 1

	# A cone: widest one block below the top of the trunk, narrowing to a point
	# a little above it. Starting below the trunk top is what makes the foliage
	# wrap the trunk instead of balancing on it like a hat.
	var layers := crown + 3
	var base_y := ground + trunk_height - 1
	for layer in layers:
		var r := int(round(float(crown) * (1.0 - float(layer) / float(layers))))
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				# +1 rounds the corners off, so the canopy is a cone rather
				# than a stepped pyramid of squares.
				if dx * dx + dz * dz > r * r + 1:
					continue
				writer.set_block(bx + dx, base_y + layer, bz + dz,
					row["leaves"], true)
				drawn += 1
	return drawn


## Total height of a tree with these parameters, in blocks. Trunk plus whatever
## the crown adds above it, which is what the gallery frames its camera on.
static func total_height(species: int, params: Dictionary, config: WorldgenConfig) -> int:
	match species:
		SPRUCE:
			# base_y is ground + trunk - 1 and the last layer drawn is
			# crown + 2 above it, so the tip sits trunk + crown + 1 up.
			return params["trunk"] + params["crown"] + 1
	return params["trunk"]


## Is this block id part of a tree?
##
## Asked by the self-test, which counts tree blocks to prove it actually had
## trees in its sample, and by anything else that has a block id and wants to
## know whether something grew there. A list rather than a range test, because
## block ids are appended in the order features arrive and tree ids are
## therefore NOT contiguous with each other.
static func is_tree_block(id: int) -> bool:
	return id == Block.LEAVES or id == Block.TRUNK


# --- The gallery ------------------------------------------------------------

## One row per species, in table order, for the model gallery's layout.
static func gallery_rows(config: WorldgenConfig = null) -> Array:
	var cfg := config if config != null else WorldgenConfig.new()
	var rows := []
	for row in table(cfg):
		rows.append({"id": row["id"], "name": row["name"]})
	return rows


## Draw one specimen at a chosen size rather than a hashed one.
##
## `t` runs 0 (the species' smallest) to 1 (its largest), so the gallery's three
## rows are the honest ends and middle of the range rather than three draws
## that happened to come out different. Everything else about the shape is
## exactly what the world would draw.
static func stamp_specimen(writer, species: int, bx: int, ground: int, bz: int,
		t: float, config: WorldgenConfig = null) -> Dictionary:
	var cfg := config if config != null else WorldgenConfig.new()
	var row: Dictionary = table(cfg)[species]
	var params := {
		"species": species,
		"trunk": int(round(lerpf(float(row["trunk"].x), float(row["trunk"].y), t))),
		"crown": int(round(lerpf(float(row["crown"].x), float(row["crown"].y), t))),
	}
	var blocks := draw(writer, species, bx, ground, bz, params, cfg)
	return {
		"height": total_height(species, params, cfg),
		"blocks": blocks,
		"params": params,
	}
