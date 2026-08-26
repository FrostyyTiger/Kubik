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
## comes out of `params_for()`, which is pure - including the details a shape
## invents for itself, like which way a krummholz leans, because `params`
## carries the cell coordinates and the seed so the shape can keep hashing.
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


## A writer that spans every chunk of ONE COLUMN, so a column's trees can be
## stamped once instead of once per chunk.
##
## WHY THIS EXISTS (world feel v1 Stage 2). stamp_chunk() scans
## (16 + 2 * max_reach)^2 / cell^2 candidate cells and calls decide() for each,
## and the six or seven chunks of a column each did it again - the same cells,
## the same answers, six or seven times. Tree stamping is half the generation
## cost, so that was a third of the whole streaming budget spent re-deciding
## trees that had already been decided.
##
## It clips exactly as ChunkWriter does: a block outside every chunk of this
## column is dropped, because the column that owns it will stamp the same tree
## itself. stamp_cell() must produce the same tree for every column that sees
## it, which is why nothing in this class is readable from there.
class ColumnWriter extends RefCounted:
	## chunk y index -> Chunk. Only the chunks the column actually built; a
	## block above the ceiling has nowhere to go and is dropped, which is what
	## makes the sky reserve a ceiling rather than a build list.
	var chunks := {}

	func bind(p_chunks: Dictionary) -> void:
		chunks = p_chunks

	func set_block(bx: int, by: int, bz: int, id: int, only_air: bool) -> void:
		var chunk: Chunk = chunks.get(Chunk.floor_div(by, Chunk.SIZE))
		if chunk == null:
			return
		var origin := chunk.origin()
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
# unlike Block they may be reordered - but the placement weight tables are
# written in terms of them, so do not do it casually.

enum {
	SPRUCE = 0,
	BEECH = 1,
	LARCH = 2,
	KRUMMHOLZ = 3,
	BIRCH = 4,
	SNAG = 5,
	HERO = 6,
}

const COUNT := 7

## Shape functions, by name rather than by species, because three species share
## one: larch is the spruce's cone with holes in it, and the hero is whichever
## of spruce or beech it grew up to be.
const SHAPE_WHORL_CONE := 0
const SHAPE_DOME := 1
const SHAPE_MOUND := 2
const SHAPE_SLENDER := 3
const SHAPE_BARE := 4
const SHAPE_HERO := 5

# --- Salts ------------------------------------------------------------------
#
# Every parameter a tree hashes gets its own, or its height and its crown
# radius would agree with each other and every tall tree in the world would
# also be the widest one.
#
# 203 AND 204 KEEP THE VALUES THEY HAD IN TerrainGenerator. A salt is part of
# what a seed means; changing one silently rearranges every tree in every
# existing world, and there is no reason to spend that here.

const SALT_HEIGHT := 203
const SALT_CROWN := 204
const SALT_SHADE := 210
const SALT_HERO_PARENT := 211
const SALT_HERO_SCALE := 212
const SALT_LEAN := 213
const SALT_STUBS := 214
## Salts the PER-BLOCK holes in a sparse crown. Hashed from the block's own
## world position, not from the cell, so a larch is sparse the same way in
## every chunk that draws it - and two larches standing next to each other are
## sparse differently.
const SALT_SPARSE := 215
const SALT_MOUND := 216


## One row per species.
##
##   name        for the probe, the gallery and STATUS.md
##   height      min/max TOTAL height in blocks - trunk and crown together
##   crown       min/max crown radius in blocks
##   shape       which shape function draws it
##   fill        probability a crown block exists at all; 1.0 is solid
##   leaves      block id, shade A; leaves_b is shade B
##   trunk_id    block id for the trunk
##   slope       steepest ground, in degrees, this species will stand on
##
## HEIGHTS ARE TOTAL, and that is a change from the old code, which stored a
## trunk height and grew a cone on top of it. Total is the number a person can
## picture and check against the scale table - a 21-block spruce is 10.5 m at
## 1:4, which is a real spruce - whereas "trunk 14 plus canopy 6" is a number
## you have to reconstruct the tree from before you know whether it is wrong.
const SPECIES := [
	{
		"name": "spruce", "height": Vector2i(13, 21), "crown": Vector2i(2, 4),
		"shape": SHAPE_WHORL_CONE, "fill": 1.0,
		"leaves": Block.LEAVES, "leaves_b": Block.LEAVES_SPRUCE_B,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"name": "beech", "height": Vector2i(10, 16), "crown": Vector2i(4, 6),
		"shape": SHAPE_DOME, "fill": 1.0,
		"leaves": Block.LEAVES_BEECH, "leaves_b": Block.LEAVES_BEECH_B,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"name": "larch", "height": Vector2i(12, 20), "crown": Vector2i(2, 3),
		"shape": SHAPE_WHORL_CONE, "fill": 0.6,
		"leaves": Block.LEAVES_LARCH, "leaves_b": Block.LEAVES_LARCH_B,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"name": "krummholz", "height": Vector2i(3, 6), "crown": Vector2i(3, 5),
		"shape": SHAPE_MOUND, "fill": 0.82,
		"leaves": Block.LEAVES_PINE, "leaves_b": Block.LEAVES_PINE_B,
		"trunk_id": Block.TRUNK, "slope": 55.0,
	},
	{
		"name": "birch", "height": Vector2i(10, 16), "crown": Vector2i(2, 3),
		"shape": SHAPE_SLENDER, "fill": 0.7,
		"leaves": Block.LEAVES_BIRCH, "leaves_b": Block.LEAVES_BIRCH_B,
		"trunk_id": Block.TRUNK_BIRCH, "slope": 40.0,
	},
	{
		"name": "snag", "height": Vector2i(6, 14), "crown": Vector2i(0, 0),
		"shape": SHAPE_BARE, "fill": 0.0,
		"leaves": Block.AIR, "leaves_b": Block.AIR,
		"trunk_id": Block.TRUNK_DEAD, "slope": 45.0,
	},
	{
		# 1.6x the smallest beech through 2.0x the largest spruce. Stated as a
		# range rather than left implicit, because max_height() reads this
		# table to decide how much empty sky the world reserves above the
		# terrain - and a hero whose real size exceeded what the table admits
		# would have its crown cut off by a chunk that was never queued.
		"name": "hero", "height": Vector2i(16, 42), "crown": Vector2i(3, 8),
		"shape": SHAPE_HERO, "fill": 1.0,
		"leaves": Block.LEAVES, "leaves_b": Block.LEAVES_SPRUCE_B,
		"trunk_id": Block.TRUNK, "slope": 30.0,
	},
]

## Total height at or above which a trunk is 2 x 2 rather than 1 x 1.
##
## A 20-block tree on a 1-block stalk reads as a lollipop. Real trunk diameter
## scales with height, and at 1:4 the first place that becomes visible is
## around 8 m of tree - which is 16 blocks.
const THICK_TRUNK_HEIGHT := 16


## The table with `tree_size_scale` applied.
##
## Scaled here rather than at every call site, so that everything downstream -
## the maxima, the gallery, the stamper - is looking at the same numbers. The
## scale is a SHAPE knob and lives in PROPERTIES: two machines that disagreed
## about it would grow different trees while the handshake reported a match.
static func table(config: WorldgenConfig) -> Array:
	var scale: float = config.tree_size_scale
	if is_equal_approx(scale, 1.0):
		return SPECIES
	var out := []
	for row in SPECIES:
		var copy: Dictionary = (row as Dictionary).duplicate()
		copy["height"] = Vector2i(
			maxi(1, int(round(float(row["height"].x) * scale))),
			maxi(1, int(round(float(row["height"].y) * scale))))
		copy["crown"] = Vector2i(
			int(round(float(row["crown"].x) * scale)),
			int(round(float(row["crown"].y) * scale)))
		out.append(copy)
	return out


## How far above the ground the tallest possible tree reaches, in blocks.
##
## DERIVED FROM THE TABLE, NEVER TYPED. World reserves this much empty sky
## above the terrain when it decides which chunks of a column to build, and a
## constant that did not grow with the biggest species would silently cut the
## crown off every tree taller than whatever the number happened to be.
##
## The +3 is the same margin the single-species version carried: a shape may
## round a layer upward, and the reserve should never be the thing that decides
## where a tree stops.
static func max_height(config: WorldgenConfig) -> int:
	var tallest := 0
	for row in table(config):
		tallest = maxi(tallest, row["height"].y + 3)
	return tallest


## How far sideways a crown can spread, in blocks. The margin `stamp_chunk()`
## widens its candidate scan by, and derived for the same reason.
static func max_reach(config: WorldgenConfig) -> int:
	var widest := 0
	for row in table(config):
		widest = maxi(widest, row["crown"].y)
	# A 2 x 2 trunk occupies one block further out than the cell it is rooted
	# in, and a mound's raggedness never exceeds its radius - so the crown
	# maximum plus one is a true bound on how far a tree can write.
	return widest + 1


# --- One tree's parameters --------------------------------------------------

## Everything one tree needs to know about itself, hashed from its cell.
##
## Pure, and the whole determinism contract rests on that: two machines, two
## chunk build orders and two hemispheres of the map all call this with the
## same three integers and get the same tree back.
static func params_for(species: int, cell_x: int, cell_z: int,
		world_seed: int, config: WorldgenConfig) -> Dictionary:
	var rows := table(config)
	var row: Dictionary = rows[species]

	var height := WorldHash.hash_range(cell_x, cell_z, world_seed, SALT_HEIGHT,
		row["height"].x, row["height"].y)
	var crown := WorldHash.hash_range(cell_x, cell_z, world_seed, SALT_CROWN,
		row["crown"].x, row["crown"].y)
	var draw_species := species
	var leaves_row := row

	if species == HERO:
		# THE HERO IS ITS PARENT, SCALED. It is not an eighth shape - it is the
		# same beech or spruce grown to a size nothing else in the world
		# reaches, which is what makes one standing alone in a meadow read as
		# remarkable rather than as a different kind of tree.
		var parent := BEECH if WorldHash.hash01(cell_x, cell_z, world_seed,
			SALT_HERO_PARENT) < 0.6 else SPRUCE
		var parent_row: Dictionary = rows[parent]
		var scale := lerpf(1.6, 2.0,
			WorldHash.hash01(cell_x, cell_z, world_seed, SALT_HERO_SCALE))
		var parent_h := WorldHash.hash_range(cell_x, cell_z, world_seed,
			SALT_HEIGHT, parent_row["height"].x, parent_row["height"].y)
		var parent_r := WorldHash.hash_range(cell_x, cell_z, world_seed,
			SALT_CROWN, parent_row["crown"].x, parent_row["crown"].y)
		# Clamped to what the hero row admits, because max_height() and
		# max_reach() are computed from that row and the world reserved its
		# sky accordingly.
		height = clampi(int(round(float(parent_h) * scale)),
			row["height"].x, row["height"].y)
		crown = clampi(int(round(float(parent_r) * scale)),
			row["crown"].x, row["crown"].y)
		draw_species = parent
		leaves_row = parent_row

	# A OR B, hashed once for the whole tree. Per-tree, never per-block: the
	# mesher merges blocks of one colour into one quad, so a crown of two
	# interleaved shades would cost hundreds of quads instead of a few, for a
	# result that reads as noise rather than as two trees.
	var shade := WorldHash.hash2(cell_x, cell_z, world_seed, SALT_SHADE) & 1

	return {
		"species": species,
		"draw": draw_species,
		"height": height,
		"crown": crown,
		"fill": float(leaves_row["fill"]),
		"leaves": leaves_row["leaves"] if shade == 0 else leaves_row["leaves_b"],
		"trunk_id": leaves_row["trunk_id"],
		# Hero trunks are ALWAYS 2 x 2, whatever the height rule says. A tree
		# twice the size of everything around it standing on the same stalk as
		# everything around it is the one way to make it look wrong.
		"thick": species == HERO or height >= THICK_TRUNK_HEIGHT,
		"cell": Vector2i(cell_x, cell_z),
		"seed": world_seed,
	}


## Total height of a tree with these parameters, in blocks.
static func total_height(_species: int, params: Dictionary,
		_config: WorldgenConfig = null) -> int:
	return params["height"]


## Is this block id part of a tree?
##
## Asked by the self-test, which counts tree blocks to prove it actually had
## trees in its sample, and by anything else that has a block id and wants to
## know whether something grew there. A list rather than a range test, because
## block ids are appended in the order features arrive and tree ids are
## therefore NOT contiguous with each other.
static func is_tree_block(id: int) -> bool:
	return id in TREE_BLOCKS


const TREE_BLOCKS := [
	Block.LEAVES, Block.LEAVES_SPRUCE_B,
	Block.LEAVES_BEECH, Block.LEAVES_BEECH_B,
	Block.LEAVES_LARCH, Block.LEAVES_LARCH_B,
	Block.LEAVES_PINE, Block.LEAVES_PINE_B,
	Block.LEAVES_BIRCH, Block.LEAVES_BIRCH_B,
	Block.TRUNK, Block.TRUNK_BIRCH, Block.TRUNK_DEAD,
]


# --- Drawing ----------------------------------------------------------------

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
	var shape: int = table(config)[params.get("draw", species)]["shape"]
	match shape:
		SHAPE_WHORL_CONE:
			return _draw_whorl_cone(writer, bx, ground, bz, params)
		SHAPE_DOME:
			return _draw_dome(writer, bx, ground, bz, params)
		SHAPE_MOUND:
			return _draw_mound(writer, bx, ground, bz, params)
		SHAPE_SLENDER:
			return _draw_slender(writer, bx, ground, bz, params)
		SHAPE_BARE:
			return _draw_bare(writer, bx, ground, bz, params)
	return 0


## SPRUCE AND LARCH. A cone whose radius steps rather than tapering smoothly.
##
## WHORLS ARE WHAT SEPARATE A SPRUCE FROM A CHRISTMAS TREE. A real conifer
## grows one ring of branches per year, so its outline is a stack of shallow
## skirts with a notch between each - not a straight-sided triangle. The
## implementation is one character of arithmetic: alternate layers lose a block
## of radius, so the silhouette steps in and back out all the way up.
##
## The old single-species cone tapered smoothly and that is precisely why
## 35,000 of them read as 35,000 identical traffic cones.
static func _draw_whorl_cone(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var r: int = params["crown"]
	var crown_base := ground + maxi(1, int(round(float(h) * 0.28)))
	var top := ground + h
	var layers := maxi(top - crown_base + 1, 1)
	var drawn := 0

	# Up into the crown, not just up to it, so the foliage wraps the trunk
	# instead of balancing on it like a hat.
	drawn += _draw_trunk(writer, bx, ground, bz, crown_base + 2, params)

	for i in layers:
		var t := float(i) / float(maxi(layers - 1, 1))
		var taper := float(r) * (1.0 - t)
		# The whorl. Every other layer is drawn one block narrower than the
		# taper asks for, which is the notch.
		var ri := maxi(int(round(taper)) - (i % 2), 0)
		drawn += _disc(writer, bx, crown_base + i, bz, ri, params)
	return drawn


## BEECH. A dome: an ellipsoid crown, slightly wider than tall, on a clean
## trunk.
##
## The point of it is contrast with the conifers. A forest of nothing but cones
## has one silhouette repeated at three sizes; a broadleaf among them gives the
## eye something to measure the cones against, which is why beech is weighted
## heavily at the bottom of the forest band where it is most visible from the
## meadow below.
static func _draw_dome(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var r: int = params["crown"]
	var crown_base := ground + maxi(1, int(round(float(h) * 0.40)))
	var top := ground + h
	var crown_h := maxi(top - crown_base, 1)
	var centre := float(crown_base) + float(crown_h) * 0.5
	var ry := maxf(float(crown_h) * 0.5, 1.0)
	var drawn := 0

	drawn += _draw_trunk(writer, bx, ground, bz, int(centre), params)

	for y in range(crown_base, top + 1):
		var dy := (float(y) - centre) / ry
		if absf(dy) > 1.0:
			continue
		var ri := int(round(float(r) * sqrt(maxf(1.0 - dy * dy, 0.0))))
		drawn += _disc(writer, bx, y, bz, ri, params)
	return drawn


## KRUMMHOLZ. A low ragged mound, wider than tall, on a stub of a trunk.
##
## This is the tree that makes a treeline read as a treeline rather than as a
## line. Above the last upright spruce, real mountainsides carry wind-flattened
## pine that is more shrub than tree, and it thins out over a hundred metres
## instead of stopping. It leans, because everything up there leans.
static func _draw_mound(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var r: int = params["crown"]
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var drawn := 0

	# A short trunk, one or two blocks, which may step sideways at its top -
	# the lean.
	var lean_roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_LEAN)
	var lean: Vector2i = LEAN_DIRS[lean_roll % LEAN_DIRS.size()]
	var trunk_h := 1 + (lean_roll >> 8) % 2
	var cx := bx
	var cz := bz
	for i in trunk_h:
		# The lean is IN THE TRUNK. Offsetting only the crown would give a
		# straight stem with its foliage slid off to one side, which reads as
		# a bug rather than as a tree the wind has been at.
		if i > 0:
			cx = bx + lean.x
			cz = bz + lean.y
		writer.set_block(cx, ground + 1 + i, cz, params["trunk_id"], false)
		drawn += 1

	for y in range(1, h + 1):
		# A half-ellipsoid sitting on the ground: full radius at the base,
		# closing to nothing at the top.
		var dy := float(y) / float(maxi(h, 1))
		var ri := int(round(float(r) * sqrt(maxf(1.0 - dy * dy, 0.0))))
		drawn += _disc(writer, cx, ground + y, cz, ri, params)
	return drawn


## Which way a krummholz may lean. Four directions, not eight: a diagonal lean
## on a block lattice is two steps, and at three to six blocks tall the tree is
## not big enough to spend two on it.
const LEAN_DIRS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


## BIRCH. Slender, pale-barked, with a small loose crown you can see through.
##
## The trunk is drawn to FULL height rather than stopping inside the crown, and
## that is the whole species: a birch is recognised by its bark, and a birch
## whose trunk vanishes into foliage half way up is just a thin beech. The
## crown is sparse for the same reason - light through the canopy is what a
## stand of birch looks like.
static func _draw_slender(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var r: int = params["crown"]
	var crown_base := ground + maxi(1, int(round(float(h) * 0.55)))
	var top := ground + h
	var crown_h := maxi(top - crown_base, 1)
	var centre := float(crown_base) + float(crown_h) * 0.5
	var ry := maxf(float(crown_h) * 0.5, 1.0)
	var drawn := 0

	drawn += _draw_trunk(writer, bx, ground, bz, top - 1, params)

	for y in range(crown_base, top + 1):
		var dy := (float(y) - centre) / ry
		if absf(dy) > 1.0:
			continue
		var ri := int(round(float(r) * sqrt(maxf(1.0 - dy * dy, 0.0))))
		drawn += _disc(writer, bx, y, bz, ri, params)
	return drawn


## SNAG. A dead trunk with a few stubs and no leaves at all.
##
## Cheap in blocks and worth more than it costs. A forest of nothing but
## healthy trees reads as planted; a scatter of grey trunks says the place has
## been there a while and nobody is looking after it - which is the whole
## register of "tense out, cozy in the light". It gets commoner with wildness
## for exactly that reason, and measurably so: on seed 42 snags are about a
## fifteenth of the world's trees near spawn and a fifth at the far corner.
static func _draw_bare(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var id: int = params["trunk_id"]
	var drawn := _draw_trunk(writer, bx, ground, bz, ground + h, params)

	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_STUBS)
	var stubs := 1 + roll % 3
	for i in stubs:
		# Each stub gets its own bits of the same hash rather than its own
		# hash call: three stubs need six independent small numbers and one
		# 31-bit value has them.
		var shift := 4 + i * 6
		var frac := float((roll >> shift) & 0x1F) / 32.0
		# Upper half only. A stub at ankle height reads as a mistake.
		var y := ground + int(round(lerpf(float(h) * 0.45, float(h) - 1.0, frac)))
		var dir: Vector2i = LEAN_DIRS[(roll >> (shift + 5)) % LEAN_DIRS.size()]
		writer.set_block(bx + dir.x, y, bz + dir.y, id, true)
		drawn += 1
	return drawn


# --- Shared drawing helpers -------------------------------------------------

## One horizontal disc of leaves.
##
## The +1 in the radius test rounds the corners off, so a crown is a cone or a
## dome rather than a stepped pyramid of squares - kept from the original stamp
## because it is what stops every tree in the world from looking cubic.
static func _disc(writer, cx: int, y: int, cz: int, r: int,
		params: Dictionary) -> int:
	if r < 0:
		return 0
	var id: int = params["leaves"]
	if id == Block.AIR:
		return 0
	var fill: float = params["fill"]
	var seed: int = params["seed"]
	var drawn := 0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r + 1:
				continue
			if fill < 1.0:
				# HASHED FROM THE BLOCK'S WORLD POSITION, not from a counter.
				# Every chunk that draws this larch has to punch the same
				# holes in it, and a counter would depend on where the loop
				# started - which differs per chunk.
				#
				# The layer varies the SALT rather than being folded into the
				# z coordinate. Folding it in is the obvious trick and it
				# aliases: with z running over six thousand blocks, (y << 8)
				# + z collides between different layers of different trees,
				# and the holes would line up between them.
				if WorldHash.hash01(cx + dx, cz + dz, seed,
						SALT_SPARSE + y * 7919) >= fill:
					continue
			writer.set_block(cx + dx, y, cz + dz, id, true)
			drawn += 1
	return drawn


## The trunk, from one block above the ground up to and including `top_y`.
##
## 2 x 2 ABOVE THE HEIGHT THRESHOLD. A twenty-block tree on a one-block stalk
## reads as a lollipop, and real trunk diameter scales with height. The second
## column goes to +X and +Z, so a thick trunk grows out of the same cell corner
## every time - which matters for the jitter bound in the placement rules: two
## neighbouring thick trunks must not be able to close the gap between them.
static func _draw_trunk(writer, bx: int, ground: int, bz: int, top_y: int,
		params: Dictionary) -> int:
	var id: int = params["trunk_id"]
	var thick: bool = params["thick"]
	var drawn := 0
	for y in range(ground + 1, top_y + 1):
		writer.set_block(bx, y, bz, id, false)
		drawn += 1
		if thick:
			writer.set_block(bx + 1, y, bz, id, false)
			writer.set_block(bx, y, bz + 1, id, false)
			writer.set_block(bx + 1, y, bz + 1, id, false)
			drawn += 3
	return drawn


# --- The gallery ------------------------------------------------------------

## One row per species, in table order, for the model gallery's layout.
static func gallery_rows(config: WorldgenConfig = null) -> Array:
	var cfg := config if config != null else WorldgenConfig.new()
	var rows := []
	for i in table(cfg).size():
		rows.append({"id": i, "name": table(cfg)[i]["name"]})
	return rows


## Draw one specimen at a chosen size rather than a hashed one.
##
## `t` runs 0 (the species' smallest) to 1 (its largest), so the gallery's three
## columns are the honest ends and middle of the range rather than three draws
## that happened to come out different. Everything else about the shape - the
## whorls, the lean, the holes in a sparse crown, which shade it hashed - is
## exactly what the world would draw, because it all comes from the same
## params dictionary the world builds.
static func stamp_specimen(writer, species: int, bx: int, ground: int, bz: int,
		t: float, config: WorldgenConfig = null) -> Dictionary:
	var cfg := config if config != null else WorldgenConfig.new()
	# A cell far from anything the world uses, varied per specimen, so the
	# details a shape hashes for itself - lean, stubs, holes - differ between
	# the three sizes instead of all three leaning the same way.
	var cell_x := 100000 + species * 37
	var cell_z := 100000 + int(round(t * 2.0)) * 53
	var params := params_for(species, cell_x, cell_z, 20260824, cfg)
	var row: Dictionary = table(cfg)[species]
	# Override the two hashed sizes with the chosen ones; everything else the
	# hash decided stands.
	params["height"] = int(round(lerpf(
		float(row["height"].x), float(row["height"].y), t)))
	params["crown"] = int(round(lerpf(
		float(row["crown"].x), float(row["crown"].y), t)))
	params["thick"] = species == HERO or params["height"] >= THICK_TRUNK_HEIGHT

	var blocks := draw(writer, species, bx, ground, bz, params, cfg)
	return {
		"height": params["height"],
		"blocks": blocks,
		"params": params,
	}
