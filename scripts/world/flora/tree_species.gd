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

## Salts the COHERENT holes in a sparse crown (trees v1 Stage 1), which is what
## replaces SALT_SPARSE species by species as the epic works through them.
##
## The position is hashed at 2 x 2 resolution in plan - `(x >> 1, z >> 1)` -
## under a salt keyed by the shape's own unit (a larch shelf), so a hole is a
## clump of eight blocks rather than one block, which is both the look (foliage,
## not static) and roughly a fivefold cut in quads, because per-block holes are
## the worst input greedy meshing can be handed.
##
## THE SERIES IS 217 + key * 7919 AND IT CANNOT MEET SALT_SPARSE'S. That one is
## 215 + y * 7919: same stride, and the two offsets differ by 2, which no
## multiple of 7919 is. Both live in one world until every sparse species has
## moved over, and a collision would give two species the same holes.
const SALT_CLUMP := 217
## Per-tier whorl arms: how many, how long each one is.
const SALT_WHORL := 218
## Per-layer crown radius jitter.
const SALT_JITTER := 219
## Everything a conifer decides once for itself: notch phase, arm phase, drift
## direction, top treatment, whether it self-pruned.
const SALT_CONIFER := 220


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
		"read": 1.0, "name": "spruce", "height": Vector2i(13, 21), "crown": Vector2i(2, 4),
		"shape": SHAPE_WHORL_CONE, "fill": 1.0,
		"leaves": Block.LEAVES, "leaves_b": Block.LEAVES_SPRUCE_B,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"read": 1.0, "name": "beech", "height": Vector2i(10, 16), "crown": Vector2i(4, 6),
		"shape": SHAPE_DOME, "fill": 1.0,
		"leaves": Block.LEAVES_BEECH, "leaves_b": Block.LEAVES_BEECH_B,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"read": 1.0, "name": "larch", "height": Vector2i(12, 20), "crown": Vector2i(2, 3),
		# FILL 0.75, AND THE OPENNESS IS THE SHAPE (trees v1 Stage 1, judge
		# round 2). §2.5 asks for 0.5 "so sky shows through", and 0.6 was
		# per-block noise: lace at five metres, invisible at forty, and dearer
		# in quads than a max beech's entire crown. Round 1 kept the halving and
		# clumped it, and the renders came back as burnt scaffolding - a crown
		# with half of it missing has nothing left to be a crown. The sky now
		# shows through the AIR GAPS BETWEEN THE SHELVES (see the ziggurat), and
		# what is left of the fill is a texture on a solid thing. Read
		# SHELF_FILL for the number the shape actually uses; this row is what
		# params_for() hands the writer.
		"shape": SHAPE_WHORL_CONE, "fill": SHELF_FILL,
		"leaves": Block.LEAVES_LARCH, "leaves_b": Block.LEAVES_LARCH_B,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"read": 0.0, "name": "krummholz", "height": Vector2i(3, 6), "crown": Vector2i(3, 5),
		"shape": SHAPE_MOUND, "fill": 0.82,
		"leaves": Block.LEAVES_PINE, "leaves_b": Block.LEAVES_PINE_B,
		"trunk_id": Block.TRUNK, "slope": 55.0,
	},
	{
		"read": 0.5, "name": "birch", "height": Vector2i(10, 16), "crown": Vector2i(2, 3),
		"shape": SHAPE_SLENDER, "fill": 0.7,
		"leaves": Block.LEAVES_BIRCH, "leaves_b": Block.LEAVES_BIRCH_B,
		"trunk_id": Block.TRUNK_BIRCH, "slope": 40.0,
	},
	{
		"read": 0.0, "name": "snag", "height": Vector2i(6, 14), "crown": Vector2i(0, 0),
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
		"read": 1.0, "name": "hero", "height": Vector2i(16, 42), "crown": Vector2i(3, 8),
		"shape": SHAPE_HERO, "fill": 1.0,
		"leaves": Block.LEAVES, "leaves_b": Block.LEAVES_SPRUCE_B,
		"trunk_id": Block.TRUNK, "slope": 30.0,
	},
]

## Trunk width by total height, in blocks: a tree at or above the first number
## gets a trunk that many voxels square.
##
## A 20-block tree on a 1-block stalk reads as a lollipop, and once the forest
## doubles (world feel v1 Stage 5) a 2 x 2 trunk under a 60-block spruce reads
## as one too. Real trunk diameter scales with height; this is that, as data
## rather than as one threshold.
##
## Read top down - the first row a height clears wins.
const TRUNK_TIERS := [
	{"height": 48, "width": 4},
	{"height": 32, "width": 3},
	{"height": 16, "width": 2},
]

## Kept for anything still asking the old yes/no question.
const THICK_TRUNK_HEIGHT := 16


## How many voxels square a trunk of this height is. Heroes are never under 3.
static func trunk_width(height: int, species: int) -> int:
	var w := 1
	for tier in TRUNK_TIERS:
		if height >= int(tier["height"]):
			w = int(tier["width"])
			break
	if species == HERO:
		w = maxi(w, 3)
	return w


## The table with `tree_size_scale` applied.
##
## Scaled here rather than at every call site, so that everything downstream -
## the maxima, the gallery, the stamper - is looking at the same numbers. The
## scale is a SHAPE knob and lives in PROPERTIES: two machines that disagreed
## about it would grow different trees while the handshake reported a match.
static func table(config: WorldgenConfig) -> Array:
	var scale: float = config.tree_size_scale
	var read: float = config.tree_read_scale
	if is_equal_approx(scale, 1.0) and is_equal_approx(read, 1.0):
		return SPECIES
	var out := []
	for row in SPECIES:
		var copy: Dictionary = (row as Dictionary).duplicate()
		# TWO SCALES, COMPOSED PER SPECIES (world feel v1 Stage 5).
		#
		# tree_size_scale is what the LAND says: derived from world_scale, it
		# keeps a tree the right size against a mountain. tree_read_scale is
		# what the PLAYER says: a tree is the one object read against both, and
		# at 1:4 land scale a spruce was 7 player-heights where a real one is
		# 25. The land is not rescaled; the trees are.
		#
		# `read` is how much of that a species takes: 1.0 for the forest
		# proper, 0.5 for birch, 0.0 for krummholz and snags - a knee-high
		# alpine shrub at twice the size is not a bigger shrub, it is a tree.
		var f: float = scale * (1.0 + (read - 1.0) * float(row.get("read", 0.0)))
		copy["height"] = Vector2i(
			maxi(1, int(round(float(row["height"].x) * f))),
			maxi(1, int(round(float(row["height"].y) * f))))
		copy["crown"] = Vector2i(
			int(round(float(row["crown"].x) * f)),
			int(round(float(row["crown"].y) * f)))
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
		# AND OLD GROWTH, for the same reason max_reach() takes it: the scale
		# is applied per tree, not in the table.
		var h := float(row["height"].y)
		h *= 1.0 + (maxf(config.old_growth_scale, 1.0) - 1.0) \
			* float(row.get("read", 0.0))
		tallest = maxi(tallest, int(ceil(h)) + 3)
	return tallest


## How far sideways a crown can spread, in blocks. The margin `stamp_chunk()`
## widens its candidate scan by, and derived for the same reason.
static func max_reach(config: WorldgenConfig) -> int:
	var widest := 0
	for row in table(config):
		# AND OLD GROWTH, whose crowns are old_growth_scale times the table's -
		# applied per tree in params_for(), so a bound taken from the table
		# alone is not a bound at all, and the symptom is a crown clipped at a
		# column boundary in some groves on the side away from the trunk.
		#
		# This margin is paid by EVERY column in the world, so it is the one
		# place an old-growth knob costs something everywhere.
		var c := float(row["crown"].y)
		c *= 1.0 + (maxf(config.old_growth_scale, 1.0) - 1.0) \
			* float(row.get("read", 0.0))
		widest = maxi(widest, int(ceil(c)))
	# A wide trunk occupies blocks further out than the cell it is rooted in,
	# and a mound's raggedness never exceeds its radius - so the crown maximum
	# plus the widest trunk is a true bound on how far a tree can write.
	var widest_trunk := 1
	for tier in TRUNK_TIERS:
		widest_trunk = maxi(widest_trunk, int(tier["width"]))
	return widest + widest_trunk


# --- One tree's parameters --------------------------------------------------

## Everything one tree needs to know about itself, hashed from its cell.
##
## Pure, and the whole determinism contract rests on that: two machines, two
## chunk build orders and two hemispheres of the map all call this with the
## same three integers and get the same tree back.
## `extra` is a further size multiplier on top of the table - old growth, at
## world feel v1 Stage 6. It takes the species' own `read` share exactly as
## tree_read_scale does, so krummholz and snags are the same size in an old
## wood as anywhere else: an ancient forest is ancient trees, and a shrub that
## has been there a long time is still a shrub.
static func params_for(species: int, cell_x: int, cell_z: int,
		world_seed: int, config: WorldgenConfig, extra := 1.0) -> Dictionary:
	var rows := table(config)
	var row: Dictionary = rows[species]

	# OLD GROWTH GROWS IN BOTH DIRECTIONS, and getting here took one wrong turn
	# worth recording. Crowns were briefly left unscaled, because scaling them
	# grows TreeSpecies.max_reach() - the margin every column in the world
	# widens its candidate scan by - and Stage 6 was at that moment showing 73
	# frames over 33 ms and ten of twelve jumps failing to settle. The crowns
	# were not the cause; a RenderingServer call on a worker thread was (see
	# ChunkMesher._under_canopy). With that fixed the margin is affordable, and
	# height alone left an old-growth grove no more CLOSED than an ordinary one
	# - 0.553 against 0.517 - which is most of what old growth is for.
	var f := 1.0
	if not is_equal_approx(extra, 1.0):
		f = 1.0 + (extra - 1.0) * float(row.get("read", 0.0))
	var height := int(round(float(WorldHash.hash_range(
		cell_x, cell_z, world_seed, SALT_HEIGHT,
		row["height"].x, row["height"].y)) * f))
	var crown := int(round(float(WorldHash.hash_range(
		cell_x, cell_z, world_seed, SALT_CROWN,
		row["crown"].x, row["crown"].y)) * f))
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
		"trunk_width": trunk_width(height, species),
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


# --- The conifer spire (trees v1 Stage 1) ------------------------------------
#
# art-direction §2.5's numbers, as consts beside the shape that reads them
# rather than as PROPERTIES entries: they are what a spruce IS, not a setting,
# and a knob two machines could disagree about is a hole in the handshake.

## Width : height of the spruce spire. §2.5: a spruce is one third of its
## height wide. THE PROPORTION IS THE SHAPE and the table's crown radius is
## only the ceiling it may not pass - a spire that took its width from an
## independently hashed table roll would be a spire on average and a bollard a
## third of the time.
const SPIRE_SPRUCE := 3.0

## The larch's shelf radius, as a divisor of its height - AND IT IS NOT §2.5's
## 1:4.2 (judge round 2, plan rule 8).
##
## At 1:4.2 the open conifer had no width left to be open WITH. A radius of two
## with half its blocks hashed away is not a thin tree, it is a stack of
## detached slabs on a stick, and the round-1 stand photographed as burnt
## scaffolding - the one verdict in this stage that was a failure rather than
## an amplitude complaint. A fifth of the height is WIDER than the spruce's
## sixth, which is the point: the larch's openness now comes from the gaps
## BETWEEN its shelves, and a gap needs two solid shelves either side of it
## before it is a gap at all. §2.5 keeps the colour, the accent and the
## archetype; this one number is recorded against it as a deviation.
const SHELF_RATIO := 5.0

## Where the crown starts, as a fraction of total height. §2.5 puts the skirt
## nearly on the ground at 0.12, against the 0.28 this file used to carry; a
## self-pruned larch has lost its lower whorls and starts a third of the way up.
##
## For the larch it is a FLOOR rather than the answer: the ziggurat is laid out
## downwards from the top, and where it stops is where the crown begins. A tall
## larch therefore carries more bare trunk than a short one, which is what a
## larch in a stand actually does.
const CROWN_BASE_CONIFER := 0.12
const CROWN_BASE_PRUNED := 0.34

## The share of larches that self-prune.
const PRUNE_CHANCE := 0.2

## THE LEADER IS TWO TO FOUR BLOCKS, NOT A FRACTION OF THE HEIGHT (judge round
## 2). §2.5 asks for a one-wide leader over the top 15%, and 15% of a
## forty-block spruce is six bare blocks: the round-1 stand's canopy line was a
## row of TV aerials, which is the opposite of the read a spire is for. Ten per
## cent, floored at two and capped at four, keeps the point without the pole -
## and `_leader_nubs()` hangs one or two single blocks off the layers just
## under it so the spike grows OUT of the crown instead of standing on it.
##
## IT REPLACES LAYERS AND ADDS NONE: the sky above a tree was reserved from the
## table's height range, not from the shape.
const LEADER_FRAC := 0.10
const LEADER_MIN := 2
const LEADER_MAX := 4

## How many layers under the leader carry nubs, and how many there may be.
const NUB_LAYERS := 2
const NUB_MIN := 1
const NUB_MAX := 2

## And which way one points. THE FOUR AXES AND NOT THE THIRTEEN GOLDEN
## DIRECTIONS: a nub is a single block and it has to touch the layer it hangs
## off, which on an axis it always does and on a diagonal it does not. See
## `_leader_nubs`.
const NUB_DIRS := [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]

## Layers between notches on a spruce: alternate (§2.5). It is also what a tier
## IS - the arms hold still for one notch cycle, so an arm is a shelf rather
## than a stack of loose rings.
const NOTCH_SPRUCE := 2

## Arms per tier, and the shortest an arm may be as a fraction of its tier's
## radius. Never longer than the radius: the radius is the envelope.
##
## 0.85 AND NOT 0.70 (judge round 2). A poster conifer is a dark cut-out: a
## jagged EDGE around a solid BODY. At 0.70 the gaps between the arms cut a
## third of the way to the spine and the round-1 mid-crown was moth-eaten - sky
## visible straight through the middle of the tree, which no Broders spruce
## has ever done. With the core at `r - 1` (see `_arm_limits`) only the
## outermost block or two belongs to the arms, and the body closes up.
const ARM_MIN_COUNT := 4
const ARM_MAX_COUNT := 6
const ARM_SHORT := 0.85

## The radius inside which an open crown is never holed, and the radius of the
## spine that crosses a larch's air gaps. One: a three-wide column, which
## greedy meshing merges into a handful of quads however tall it gets, and
## which is what stops "sky shows through" from meaning "the tree comes apart".
const SPARSE_CORE := 1

## Radius at which a plan stops being round and becomes an octagon (§2.5).
const OCTAGON_MIN := 3

## THE ZIGGURAT (judge round 2). A larch crown is four to six SHELVES, two to
## four layers deep - the top layer at the shelf's radius, everything under it
## a block narrower, which is the down-point the poster tradition asks of every
## crown underside - separated by one or two layers of real AIR crossed only by
## the spine.
##
## SKY SHOWS THROUGH THE GAPS, NOT THROUGH THE CROWN. Round 1 read §2.5's
## "fill 0.5" as a licence to void half the crown volume and the result had no
## volume left to void; the openness belongs to the SHAPE, where the research
## has been saying it belongs since it priced the levers. A gap between two
## shelves is a silhouette event the eye still gets at ninety metres and the
## mesher charges nothing for, and it is also the oldest way anyone has drawn a
## conifer.
const SHELF_MIN := 4
const SHELF_MAX := 6
const GAP_MIN := 1
const GAP_MAX := 2

## AND THE GAP GROWS WITH THE TREE (judge round 3). Judge round 2 deepened the
## shelves so the ziggurat would fill the crown, and left the gaps where they
## were - so the tall specimens closed up into one continuous column with gold
## rims and the sky slots, which are the species, went away. Above thirty
## blocks a gap is never less than two layers and may be three; below it the
## shelves are two deep and one layer of air still reads.
const GAP_TALL_HEIGHT := 30
const GAP_TALL_MIN := 2
const GAP_TALL_MAX := 3

## Above this height the top shelves hold a wider radius, so the tallest
## larches finish in a crown rather than tapering into the spine.
const SHELF_TOP_TALL_HEIGHT := 32
const SHELF_TOP_TALL := 3

## And how DEEP a shelf is, in layers: two at least, four at most, and the
## layout picks the largest that fits.
##
## THE ZIGGURAT FILLS THE CROWN OR IT IS A LOLLIPOP. Six shelves two layers
## deep with two-layer gaps come to twenty-two blocks, and the world's larch is
## up to forty - so a fixed two left the first render of this round standing on
## a third of a bare trunk. The eye cannot count past five tiers, so the answer
## is not more shelves; it is deeper ones. Only the topmost layer of a shelf
## sits at the shelf's full radius, whatever the depth, so the crown underside
## stays a row of down-points.
const SHELF_MIN_LAYERS := 2
const SHELF_MAX_LAYERS := 4

## How wide the topmost shelf is. Two, or the crown radius if that is less: a
## top shelf of one is indistinguishable from the spine that runs through the
## gaps, and a stack of those under the cap reads as a mast. The larch is the
## conifer WITHOUT a leader - blunt or short-forked - and that is the pair's
## far-field discriminator, so the top of the ziggurat is the top of the tree.
const SHELF_TOP := 2

## How many layers the fork's two prongs rise above the last shelf.
const FORK_LAYERS := 2

## How far a shelf's edge may run in or out of its nominal radius, per
## direction. ONE BLOCK, hashed per sector - modest, because a shelf is a
## shelf: the eye reads it as a single horizontal event, and an edge that
## wandered by three would read as damage rather than as a tree. Clamped to the
## lowest shelf's radius, so the ziggurat never grows past the crown the table
## declared.
const SHELF_EDGE := 1

## The larch's clumped fill, WITHIN a shelf only.
##
## 0.75 and not 0.5 (judge round 2): with the shelves and the air gaps carrying
## the openness, the holes are now a texture on a solid thing rather than the
## thing itself. Hashed at 2 x 2 in plan under the SHELF's key, so both layers
## of one shelf lose the same clumps and the pair merges vertically - a 2 x 2 x
## 2 clump aligned to the shape instead of to the world grid.
const SHELF_FILL := 0.75

## How far a conifer's crown axis wanders from its trunk, top to bottom, in
## blocks, and the height above which it may wander the second one.
##
## DRIFT IS CHARACTER, NOT DAMAGE (judge round 2). Round 1 allowed one block on
## every spruce and several vary specimens still read windthrown, because a
## block of lean on a short tree is a bigger angle than a block on a tall one
## and because ALL of them leaned. So: a third of spruces are exactly plumb,
## the rest take one block, and only a tree over thirty-four blocks takes two.
## Spruces are the composition's verticals; the birch's bow and the krummholz's
## flag are where drift is the subject.
const DRIFT_SHORT := 1
const DRIFT_TALL := 2
const DRIFT_TALL_HEIGHT := 34
const PLUMB_CHANCE := 0.35


## SPRUCE AND LARCH. A notched spire and an open ziggurat - one shape entry,
## two constructions, because they are one archetype and the world tells them
## apart by openness and colour.
##
## WHORLS ARE WHAT SEPARATE A CONIFER FROM A CHRISTMAS TREE. A real conifer
## grows one ring of branches a year, so its outline is a stack of shallow
## skirts with a notch between each - not a straight-sided triangle.
##
## Until trees v1 that was the whole of it, and it was one character of
## arithmetic: alternate layers lost a block of radius, and every layer was a
## centred disc. Which meant a spruce looked the same from all eight azimuths
## and identical to every other spruce its size - the Stage 0 baseline measured
## TWINS 1.00, meaning two spruces hashed from two different cells were the
## same tree down to the pixel.
##
## Every decision below is hashed from `cell` and `seed` through `params`. None
## of it is read back from the writer, and none of it is trig.
static func _draw_whorl_cone(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	# Asked by species rather than by fill, because a hero draws as its PARENT
	# and a hero's parent is never a larch.
	if int(params.get("draw", SPRUCE)) == LARCH:
		return _draw_larch_ziggurat(writer, bx, ground, bz, params)
	return _draw_spruce_spire(writer, bx, ground, bz, params)


## How far this tree's crown axis wanders from its trunk, in blocks.
##
## Zero for the third of conifers that are plumb. See DRIFT_SHORT.
static func _drift_blocks(h: int, roll: int) -> int:
	if (roll & 0xFF) < int(PLUMB_CHANCE * 256.0):
		return 0
	return DRIFT_TALL if h >= DRIFT_TALL_HEIGHT else DRIFT_SHORT


## The axis offset `i` layers into a crown `n` layers tall.
##
## MONOTONE, single-peaked at neither end: the deviation grows steadily from
## the trunk to the tip, which is the "asymmetry needs a cause" rule the
## research takes from the poster tradition. Per-layer alternating offsets read
## as damage; this reads as a tree that grew towards the light.
static func _drift_at(dir: Vector2i, blocks: int, i: int, n: int) -> Vector2i:
	if blocks <= 0 or n <= 1:
		return Vector2i.ZERO
	# Clamped, because both callers walk a layer or two past the end of the
	# curve - the spruce's leader and the larch's cap sit above the body the
	# drift was measured over - and DRIFT_TALL is a ceiling, not a slope.
	return _golden_offset(dir,
		int(round(float(blocks) * float(mini(i, n - 1)) / float(n - 1))))


## THE SPRUCE. §2.5's spire: the radius comes from the HEIGHT rather than from
## the table, the skirt goes nearly to the ground with the bottom two whorls
## turned in, the notch cuts on alternate layers while there is a radius to cut
## from, and a two-to-four-block leader with nubs under it finishes the top.
##
## The tiers are 4-6 ARMS of unequal hashed length around a solid core, yawed
## from the tier below by a golden-angle step, so no two azimuths of one tree
## and no two tiers of one trunk agree. The core is `r - 1`: the arms own the
## outermost block, and the body they hang off is solid.
static func _draw_spruce_spire(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var table_r: int = params["crown"]
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_CONIFER)
	# A SECOND ROLL RATHER THAN MORE BITS OF THE FIRST. Round 1 was already
	# reading bit 25 of a 31-bit hash for the drift direction; the fields the
	# judge round adds would have overlapped ones already spoken for, and two
	# decisions sharing a bit are two decisions that agree with each other for
	# ever after.
	var roll2 := _hash_keyed(cell, seed, SALT_CONIFER, 2)

	var r := clampi(int(round(float(h) / (2.0 * SPIRE_SPRUCE) - 0.5)),
		1, maxi(table_r, 1))
	var crown_base := ground + maxi(1, int(round(float(h) * CROWN_BASE_CONIFER)))
	var top := ground + h
	var layers := maxi(top - crown_base + 1, 1)
	var drawn := 0

	# Up into the crown, not just up to it, so the foliage wraps the trunk
	# instead of balancing on it like a hat.
	drawn += _draw_trunk(writer, bx, ground, bz, crown_base + 2, params)

	var notch_phase := (roll >> 13) % NOTCH_SPRUCE
	var arms := ARM_MIN_COUNT + (roll >> 17) % (ARM_MAX_COUNT - ARM_MIN_COUNT + 1)
	var arm_phase := (roll >> 21) % GOLDEN_N
	var drift_dir: Vector2i = GOLDEN_DIRS[(roll >> 25) % GOLDEN_N]
	var drift := _drift_blocks(h, roll2)

	# Never more than the crown minus two layers: a spruce so short that the
	# leader ate the tree would be a stick, not a spire.
	var leader := mini(clampi(int(round(float(h) * LEADER_FRAC)),
		LEADER_MIN, LEADER_MAX), maxi(layers - 2, 1))

	# One array for the whole tree rather than thirteen ints per layer. An
	# Array and not a PackedInt32Array on purpose: packed arrays are values in
	# GDScript, so _arm_limits() would fill a copy and every layer would come
	# back a plain disc.
	var limits: Array[int] = []
	limits.resize(GOLDEN_N)

	# THE TAPER RUNS OUT AT ONE, NOT AT NOTHING, and it runs out at the foot of
	# the leader rather than at the top of the tree. Tapering to zero over the
	# whole stack put the crown's last full block a third of the way down the
	# leader, and the first render came back with a six-block bare aerial on a
	# fifteen-block spruce.
	var body := maxi(layers - leader, 1)

	for i in layers:
		var y := crown_base + i
		var t := minf(float(i) / float(maxi(body - 1, 1)), 1.0)
		# CEIL AND NOT ROUND (judge round 2). Rounding puts the taper's last
		# whole block a quarter of the way down the body - `round(lerp(3, 1, t))`
		# is 1 for every t over 0.75 - so a spruce carried a one-wide mast under
		# its leader and the two together read as an aerial however short the
		# leader was made. Ceiling gives every radius band an equal share of the
		# body and radius one exactly the top layer of it.
		var ri := int(ceil(lerpf(float(r), 1.0, t)))
		# The jitter may never pinch the body out to nothing: a layer hashed to
		# zero half way up leaves a gap the leader then reads as part of.
		ri = clampi(ri + _radius_jitter(cell, seed, i), 1, r)
		# The notch goes on AFTER the jitter, or the wobble undoes it half the
		# time and the shelves stop being shelves. And ONLY while there is a
		# radius left to take it from: under 2 the notch is the whole layer,
		# which is why the unconditional `i % 2` this replaces left every spire
		# ending in pagoda ribbing.
		if ri >= 2 and (i + notch_phase) % NOTCH_SPRUCE == 0:
			ri = maxi(ri - 1, 1)
		# The base turns in (§2.5), so the skirt reads as a skirt rather than
		# as the widest layer of a stack standing on a plinth.
		if i < 2:
			ri = maxi(ri - 1, 0)
		# The leader goes on LAST. A jitter that pushed it back out to two
		# blocks would cost the spruce its signature.
		if i >= body:
			ri = 0

		var off := _drift_at(drift_dir, drift, i, body)
		var cx := bx + off.x
		var cz := bz + off.y

		_arm_limits(limits, ri, cell, seed, i / NOTCH_SPRUCE, arms, arm_phase)
		drawn += _whorl_disc(writer, cx, y, cz, ri, limits, params, 0, ri)

		if i >= body - NUB_LAYERS and i < body:
			drawn += _leader_nubs(writer, cx, y, cz, ri, limits, cell, seed, i,
				params)
	return drawn


## One or two single blocks hung off the layers just below the leader.
##
## THE SPIKE HAS TO GROW OUT OF SOMETHING. A leader standing on a clean
## tapering cone is an aerial on a mast however short you make it; a couple of
## blocks proud of the last two full layers give the eye the branch the leader
## is the continuation of, which is what a Broders spire actually shows. They
## are placed one block past the layer's own radius, so they always touch it -
## a detached block in the sky is the one thing this must not draw.
static func _leader_nubs(writer, cx: int, y: int, cz: int, _r: int,
		limits: Array[int], cell: Vector2i, seed: int, layer: int,
		params: Dictionary) -> int:
	var id: int = params["leaves"]
	if id == Block.AIR:
		return 0
	var roll := _hash_keyed(cell, seed, SALT_WHORL, 90 + layer)
	var n := NUB_MIN + (roll & 1) * (NUB_MAX - NUB_MIN)
	var drawn := 0
	for j in n:
		# ON ONE OF THE FOUR AXES, AND ONE PAST THE LIMIT OF ITS OWN SECTOR
		# (judge round 3). A nub aimed down a golden direction landed on a
		# diagonal cell that the layer's plan had not drawn, and a fifth of
		# spruces carried a leaf block touching nothing. On an axis the cell
		# at `limits[s]` is always inside the plan of radius `limits[s]`, so
		# the nub at `limits[s] + 1` always has a face against it.
		var q := int((roll >> (4 + j * 2)) & 3)
		var step: Vector2i = NUB_DIRS[q]
		var ax := step.x
		var az := step.y
		var d: int = limits[_sector_of(ax, az)] + 1
		writer.set_block(cx + ax * d, y, cz + az * d, id, true)
		drawn += 1
	return drawn


## THE LARCH. The ziggurat: four to six two-layer shelves with air between
## them, laid out DOWNWARDS from the top so the shape is never stretched to
## fill a height it does not have.
##
## What the larch is for is the gap. It is the warm accent among blue-greens
## (§2.5) and the open one, and openness at forty metres is sky between
## shelves, not lace inside a crown - see SHELF_RATIO and the ziggurat block
## above for what round 1 got wrong about that and why the numbers moved.
##
## Whorl arms stay OFF: the shelves already break the outline twice and the cap
## on silhouette events per tree is three.
static func _draw_larch_ziggurat(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var table_r: int = params["crown"]
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var id: int = params["leaves"]
	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_CONIFER)
	var roll2 := _hash_keyed(cell, seed, SALT_CONIFER, 2)

	# A fifth of larches self-prune. Dead lower whorls are what a conifer in a
	# dense stand actually does, and they are one of the two places this file
	# lets a tree look damaged (the snag is the other).
	var pruned := (roll & 0xFF) < int(PRUNE_CHANCE * 256.0)
	var base_frac := CROWN_BASE_PRUNED if pruned else CROWN_BASE_CONIFER
	var floor_base := ground + maxi(1, int(round(float(h) * base_frac)))
	var top := ground + h

	# Blunt or short-forked, never a leader.
	var forked := ((roll >> 8) & 1) == 1
	var cap_layers := FORK_LAYERS if forked else 1
	var span := maxi(top - floor_base + 1 - cap_layers, SHELF_MIN_LAYERS)

	# THE SKY SLOTS ARE RESERVED BEFORE ANYTHING ELSE IS SPENT (judge round 3).
	# Both the shelf count and the shelf depth are chosen against `gap_lo`, so a
	# deeper shelf can only ever be bought out of layers the gaps did not need.
	var gap_lo := GAP_TALL_MIN if h >= GAP_TALL_HEIGHT else GAP_MIN

	# FOUR TO SIX SHELVES, AND THE SPAN DECIDES WHICH. The eye cannot count
	# past five (the WPA serigraphs' own rule), so this never grows a seventh.
	var n := clampi(span / (SHELF_MIN_LAYERS + gap_lo), SHELF_MIN, SHELF_MAX)
	while n > 1 and n * SHELF_MIN_LAYERS + (n - 1) * gap_lo > span:
		n -= 1

	# The deepest shelf the span will pay for - see SHELF_MIN_LAYERS. A taller
	# larch gets THICKER shelves, never more of them.
	var thick := SHELF_MAX_LAYERS
	while thick > SHELF_MIN_LAYERS \
			and n * thick + (n - 1) * gap_lo > span:
		thick -= 1

	# And the gaps take everything the shelves did not - up to three layers on a
	# tall larch, which is what keeps a four-deep shelf from touching the one
	# above it. Spread evenly, one layer of the remainder moved onto the gaps the
	# hash picks, so two larches of one height do not slot in the same places.
	var gap_hi := maxi(GAP_TALL_MAX if h >= GAP_TALL_HEIGHT else GAP_MAX,
		thick - 1)
	var gaps: Array[int] = []
	var stack := n * thick
	var remain := span - stack
	for k in maxi(n - 1, 0):
		var left := n - 1 - k
		var g := clampi(remain / maxi(left, 1), gap_lo, gap_hi)
		if g < gap_hi and remain - g * left > 0 \
				and ((roll2 >> (12 + k)) & 1) == 1:
			g += 1
		g = clampi(g, gap_lo, maxi(remain - (left - 1) * gap_lo, gap_lo))
		gaps.append(g)
		stack += g
		remain -= g

	# Downwards from the top. `start` is the bottom layer of the lowest shelf,
	# and it is never below `floor_base` because `stack <= span`.
	var start := top - cap_layers - stack + 1
	var drawn := 0
	drawn += _draw_trunk(writer, bx, ground, bz, start + 2, params)
	if pruned:
		drawn += _draw_dead_stubs(writer, bx, ground, bz, start, params)

	var r_base := clampi(int(round(float(h) / SHELF_RATIO)), 1, maxi(table_r, 1))
	# The top shelves of a tall larch hold three rather than two, so the last
	# two tiers are still a crown and not a thickening of the spine.
	var r_top := mini(SHELF_TOP_TALL if h >= SHELF_TOP_TALL_HEIGHT
		else SHELF_TOP, r_base)
	var drift_dir: Vector2i = GOLDEN_DIRS[(roll >> 25) % GOLDEN_N]
	var drift := _drift_blocks(h, roll2)
	var fork_off := _golden_offset(GOLDEN_DIRS[(roll >> 9) % GOLDEN_N], 1)

	var limits: Array[int] = []
	limits.resize(GOLDEN_N)
	var spine: Array[int] = []
	spine.resize(GOLDEN_N)
	for s in GOLDEN_N:
		spine[s] = SPARSE_CORE

	var y := start
	for k in n:
		# Ceiling, for the reason the spruce's taper takes it: rounding spends
		# two of five shelves on the same radius and then jumps two at once.
		var rk := int(ceil(lerpf(float(r_base), float(r_top),
			float(k) / float(maxi(n - 1, 1)))))
		for j in thick:
			# ONLY THE TOP LAYER SITS AT THE SHELF'S RADIUS; everything under it
			# is a block narrower, so the crown underside is a row of DOWN-POINTS
			# and never a horizontal cut (trees research §2).
			var ri := rk if j == thick - 1 else maxi(rk - 1, 1)
			var off := _drift_at(drift_dir, drift, y - start, stack)
			var widest := _shelf_limits(limits, ri, r_base, cell, seed, k)
			drawn += _whorl_disc(writer, bx + off.x, y, bz + off.y, widest,
				limits, params, k, ri)
			y += 1
		if k < n - 1:
			for _g in gaps[k]:
				var off2 := _drift_at(drift_dir, drift, y - start, stack)
				drawn += _whorl_disc(writer, bx + off2.x, y, bz + off2.y,
					SPARSE_CORE, spine, params, k, SPARSE_CORE)
				y += 1

	var cap_off := _drift_at(drift_dir, drift, y - start, stack)
	if forked:
		# Where a spruce runs to one point a larch runs to two. The prongs
		# stand on the last shelf's own blocks, which is why the offset is one
		# and the shelf top is at least that wide.
		for _j in cap_layers:
			writer.set_block(bx + cap_off.x + fork_off.x, y,
				bz + cap_off.y + fork_off.y, id, true)
			writer.set_block(bx + cap_off.x - fork_off.x, y,
				bz + cap_off.y - fork_off.y, id, true)
			drawn += 2
			y += 1
	else:
		var rc := maxi(r_top - 1, 0)
		for s in GOLDEN_N:
			limits[s] = rc
		drawn += _whorl_disc(writer, bx + cap_off.x, y, bz + cap_off.y,
			rc, limits, params, n, rc)
	return drawn


## The thirteen per-sector radii of one larch shelf.
##
## A shelf is a SHELF and its edge is straight-ish: one block in or out per
## direction, hashed, and the same pattern for both layers of the shelf so the
## down-point below it follows the edge above it. Returns the widest of the
## thirteen, which is the loop bound `_whorl_disc()` needs.
static func _shelf_limits(limits: Array[int], r: int, cap: int,
		cell: Vector2i, seed: int, shelf: int) -> int:
	var roll := _hash_keyed(cell, seed, SALT_WHORL, shelf)
	# A shelf's edge may run in, but never in as far as the spine: a sector that
	# tapered to SPARSE_CORE would be indistinguishable from the column that
	# crosses the air gaps, and a stack of those under the cap is the mast
	# judge round 2 saw on the tall specimens.
	var floor_r := mini(r, SHELF_TOP)
	for s in GOLDEN_N:
		# Two bits per sector: in, out, and twice unchanged, so an edge holds
		# still more often than it moves.
		var step := int((roll >> (s * 2)) & 3)
		var j := 0
		if step == 0:
			j = -SHELF_EDGE
		elif step == 3:
			j = SHELF_EDGE
		limits[s] = clampi(r + j, floor_r, cap)
	# NEIGHBOURING SECTORS MAY NOT DIFFER BY MORE THAN ONE (judge round 3).
	# Hashed independently they could, and a sector at r + 1 beside one at r - 1
	# put the outermost cell of the long one over a cell the short one never
	# drew: a gold chip floating a block off the shelf. Raising the short
	# neighbour is the cheap fix and it is still pure - the same thirteen
	# numbers come out of the same hash on every machine. Two passes converge,
	# because the span before smoothing is two.
	for _pass in 2:
		for s in GOLDEN_N:
			var prev: int = limits[(s + GOLDEN_N - 1) % GOLDEN_N]
			var next: int = limits[(s + 1) % GOLDEN_N]
			limits[s] = maxi(limits[s], maxi(prev, next) - 1)
	var widest := 0
	for s in GOLDEN_N:
		widest = maxi(widest, limits[s])
	return widest


## The 2-3 dead stubs a self-pruned larch keeps below its raised crown.
##
## One block each, drawn over air only, so a stub can never eat the trunk it
## grew from - and stepped out past the trunk's own width on the sides it grows
## to, so it is proud of the trunk rather than inside it.
static func _draw_dead_stubs(writer, bx: int, ground: int, bz: int,
		crown_base: int, params: Dictionary) -> int:
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var w: int = int(params.get("trunk_width", 1))
	var roll := _hash_keyed(cell, seed, SALT_CONIFER, 1)
	var n := 2 + (roll & 1)
	var lo := ground + 2
	var hi := maxi(crown_base - 1, lo)
	var drawn := 0
	for j in n:
		var y := lo + (hi - lo) * j / maxi(n - 1, 1)
		var off := _golden_offset(
			GOLDEN_DIRS[((roll >> 4) + j * GOLDEN_STEP) % GOLDEN_N], 1)
		# ONE AXIS, NOT TWO (judge round 3). The golden direction was used
		# whole, so a diagonal one put the stub off the CORNER of the trunk -
		# touching it at an edge and at no face, which is a block floating in
		# the air by every rule this file has. Snapped to the dominant axis it
		# is always against a trunk face.
		var sx := 0
		var sz := 0
		if absi(off.x) >= absi(off.y):
			sx = signi(off.x)
		else:
			sz = signi(off.y)
		writer.set_block(bx + (w if sx > 0 else sx), y,
			bz + (w if sz > 0 else sz), Block.TRUNK_DEAD, true)
		drawn += 1
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


# --- The golden-angle direction table (trees v1 Stage 1) ---------------------
#
# THIRTEEN AZIMUTHS AND A STEP OF FIVE. 5/13 of a turn is 138.46 degrees, the
# Fibonacci convergent to the golden angle - which is the angle a real whorl
# yaws by, and the one Veloren's tree generator uses for the same reason - so
# a tier's arms never land where the tier below put theirs and the pattern does
# not close before the tree runs out of tiers. Sixteen is the obvious table
# size and it is the wrong one: the closest step on sixteen is six, gcd(6, 16)
# is 2, and the arms would visit half the azimuths and repeat every eighth tier.
#
# THE VECTORS ARE AUTHORED, AT MAGNITUDE 8. sin/cos are not bit-identical
# across platforms and two machines stamp the same chunk independently, so
# there is no trig anywhere in shape code - a table in the source is the whole
# answer, exactly as LEAN_DIRS is.

const GOLDEN_N := 13
const GOLDEN_STEP := 5
const GOLDEN_DIRS := [
	Vector2i(8, 0), Vector2i(7, 4), Vector2i(5, 7), Vector2i(1, 8),
	Vector2i(-3, 7), Vector2i(-6, 5), Vector2i(-8, 2), Vector2i(-8, -2),
	Vector2i(-6, -5), Vector2i(-3, -7), Vector2i(1, -8), Vector2i(5, -7),
	Vector2i(7, -4),
]

## The half-width of SECTOR_LUT, which is the widest crown the table admits.
const SECTOR_HALF := 8

## Which of the thirteen sectors an offset falls in. Row-major, indexed
## `(dz + SECTOR_HALF) * 17 + (dx + SECTOR_HALF)`.
##
## A LOOKUP, BECAUSE THE ALTERNATIVE IS atan2 IN THE INNER LOOP of every crown
## layer of every tree in the world - and trig in shape code is forbidden
## anyway. The centre entry is never read: the core of a layer is drawn without
## asking which arm it belongs to.
const SECTOR_LUT := [
	 8,  8,  8,  9,  9,  9,  9,  9, 10, 10, 10, 10, 11, 11, 11, 11, 11,
	 8,  8,  8,  8,  9,  9,  9,  9, 10, 10, 10, 11, 11, 11, 11, 11, 12,
	 8,  8,  8,  8,  9,  9,  9,  9, 10, 10, 10, 11, 11, 11, 11, 12, 12,
	 8,  8,  8,  8,  8,  9,  9,  9, 10, 10, 11, 11, 11, 11, 12, 12, 12,
	 7,  8,  8,  8,  8,  8,  9,  9, 10, 10, 11, 11, 11, 12, 12, 12, 12,
	 7,  7,  7,  8,  8,  8,  9,  9, 10, 10, 11, 11, 12, 12, 12, 12, 12,
	 7,  7,  7,  7,  7,  8,  8,  9, 10, 11, 11, 12, 12, 12, 12, 12, 12,
	 7,  7,  7,  7,  7,  7,  7,  8, 10, 11, 12, 12, 12,  0,  0,  0,  0,
	 6,  6,  6,  6,  6,  6,  6,  6,  0,  0,  0,  0,  0,  0,  0,  0,  0,
	 6,  6,  6,  6,  6,  6,  6,  5,  3,  2,  1,  1,  1,  0,  0,  0,  0,
	 6,  6,  6,  6,  6,  5,  5,  4,  3,  2,  2,  1,  1,  1,  1,  1,  1,
	 6,  6,  6,  5,  5,  5,  4,  4,  3,  3,  2,  2,  1,  1,  1,  1,  1,
	 6,  5,  5,  5,  5,  5,  4,  4,  3,  3,  2,  2,  2,  1,  1,  1,  1,
	 5,  5,  5,  5,  5,  4,  4,  4,  3,  3,  2,  2,  2,  2,  1,  1,  1,
	 5,  5,  5,  5,  4,  4,  4,  4,  3,  3,  3,  2,  2,  2,  2,  1,  1,
	 5,  5,  5,  5,  4,  4,  4,  4,  3,  3,  3,  2,  2,  2,  2,  2,  1,
	 5,  5,  5,  4,  4,  4,  4,  4,  3,  3,  3,  3,  2,  2,  2,  2,  2,
]


## Which sector an offset from a crown's axis falls in.
##
## An offset past the table's edge is SCALED onto it, not clipped to it: an old
## growth hero's crown reaches twenty-one blocks, and clipping (14, 3) to
## (8, 3) changes the angle from 12 degrees to 21 - which is the one thing this
## lookup exists to answer. The branch is not taken by any ordinary tree.
static func _sector_of(dx: int, dz: int) -> int:
	var m := maxi(absi(dx), absi(dz))
	if m > SECTOR_HALF:
		dx = int(round(float(dx * SECTOR_HALF) / float(m)))
		dz = int(round(float(dz * SECTOR_HALF) / float(m)))
	return int(SECTOR_LUT[(dz + SECTOR_HALF) * (SECTOR_HALF * 2 + 1)
		+ dx + SECTOR_HALF])


## `d` blocks along one of the thirteen directions, rounded onto the lattice.
##
## The table is magnitude 8, so this is a divide and a round - which are
## bit-identical everywhere, unlike the sin and cos that would otherwise be
## here.
static func _golden_offset(dir: Vector2i, d: int) -> Vector2i:
	if d == 0:
		return Vector2i.ZERO
	return Vector2i(
		int(round(float(d * dir.x) / 8.0)),
		int(round(float(d * dir.y) / 8.0)))


## A second hash of the same tree, keyed by a layer or a tier index.
##
## THE KEY GOES INTO THE COORDINATES, NOT THE SALT. Salts are a namespace
## shared by everything the world hashes, and a tall tree has forty layers;
## spending forty salts on one decision taken forty times would leave the salt
## block above unreadable and the free range half gone. Multiplying the cell
## first is what stops a key from aliasing into the neighbouring cell's answers
## - cells land 131 apart in the hash input where keys run 0 to 40.
static func _hash_keyed(cell: Vector2i, seed: int, salt: int, key: int) -> int:
	return WorldHash.hash2(cell.x * 131 + key, cell.y * 137 - key, seed, salt)


## What a layer's radius jitter may be. Zero twice, so a taper wobbles rather
## than alternates.
const JITTER_STEPS := [-1, 0, 0, 1]


## The per-layer radius wobble (trees research §3, the highest payoff per line
## in the survey). Costs nothing, reaches nothing, and it is the whole
## difference between a taper and a ruled line. The caller clamps it against
## the spire radius, which is the envelope.
static func _radius_jitter(cell: Vector2i, seed: int, layer: int) -> int:
	return int(JITTER_STEPS[
		_hash_keyed(cell, seed, SALT_JITTER, layer) % JITTER_STEPS.size()])


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


## Is this offset inside a plan of radius `r`?
##
## ROUND BELOW 3, OCTAGONAL AT 3 AND ABOVE - §2.5's chamfer, the same one the
## character heads take. It is also what greedy meshing pays for: flat sides
## merge into long runs where a rasterised circle merges into steps.
##
## The +1 on the circle test is the original stamp's, and it is what stops a
## small crown from being a stepped pyramid of squares.
static func _in_plan(dx: int, dz: int, r: int) -> bool:
	if r <= 0:
		return dx == 0 and dz == 0
	var ax := absi(dx)
	var az := absi(dz)
	if maxi(ax, az) > r:
		return false
	if r >= OCTAGON_MIN:
		return ax + az <= r + (r >> 1)
	return dx * dx + dz * dz <= r * r + 1


## The thirteen per-sector radii one crown layer is drawn out to.
##
## TIERS ARE WHORLS, NOT DISCS (trees research §2). A conifer grows a ring of
## branches a year and the poster tradition draws their tips as a jagged edge,
## never a smooth arc: 4-6 arms of unequal length around a solid core, the
## whole pattern yawed from the tier below by a golden-angle step. That is what
## makes every azimuth of one tree a different silhouette, which is what the
## old centred disc could not be.
##
## `limits` is written in place and reused for every layer of a tree. It is
## monotone in the radius - a block inside the core is inside every sector's
## limit - so one lookup per block answers both questions.
static func _arm_limits(limits: Array[int], r: int, cell: Vector2i, seed: int,
		tier: int, arms: int, phase: int) -> void:
	if r < 2:
		# Nothing to carve: below two blocks an arm and its gap are the same
		# block.
		for s in GOLDEN_N:
			limits[s] = r
		return
	# THE CORE IS r - 1, WHATEVER THE TIER IS (judge round 2). It was r - 2 on
	# any tier over three blocks, which cut the gaps between the arms a third of
	# the way to the spine and left the round-1 mid-crown with sky visible
	# straight through it. A poster spruce is a dark cut-out: the EDGE is jagged
	# and the BODY is solid, so the arms own the outermost block and nothing
	# more.
	var core := maxi(r - 1, 0)
	for s in GOLDEN_N:
		limits[s] = core
	var roll := _hash_keyed(cell, seed, SALT_WHORL, tier)
	var base := (phase + tier * GOLDEN_STEP) % GOLDEN_N
	for j in arms:
		# Spread evenly around the thirteen sectors and made unequal by their
		# LENGTHS, not by their angles: a whorl is a ring of branches of
		# different lengths, and branches in random directions read as damage.
		var s := (base + (j * GOLDEN_N) / arms) % GOLDEN_N
		var u := float((roll >> (j * 4)) & 0xF) / 15.0
		# 85-100% of the tier radius and NEVER MORE. The table's crown is the
		# envelope every column in the world widens its candidate scan by, and
		# an arm past it would be clipped at a chunk boundary in the one column
		# that did not know to look.
		var length := maxi(int(round(float(r) * lerpf(ARM_SHORT, 1.0, u))), core)
		limits[s] = maxi(limits[s], length)
		# The arm's shoulders, one block back, so a branch is a wedge rather
		# than a spike - and so the mesher still has runs to merge.
		var prev := (s + GOLDEN_N - 1) % GOLDEN_N
		var next := (s + 1) % GOLDEN_N
		limits[prev] = maxi(limits[prev], length - 1)
		limits[next] = maxi(limits[next], length - 1)


## One crown layer of a conifer: a plan with a different radius per azimuth,
## and holes in coherent clumps rather than per block.
##
## THE CLUMPS ARE THE CHEAP HALF OF THE OPENNESS. A sparse crown hashed per
## block is the worst input greedy meshing can be handed - the Stage 0 baseline
## measured a max larch at 799 blocks and 2,050 quads, more quads than a max
## beech's 6,154 blocks - because every hole fragments every run. Hashed at
## 2 x 2 the void fraction is the same, the silhouette reads as foliage
## instead of as static, and the quads collapse.
##
## `clump_key` IS THE SHELF, NOT THE ALTITUDE (judge round 2). Keying the hash
## by `y >> 1` clumped against the world's grid, which cuts a two-layer shelf
## in half whenever the shelf happens to start on an odd block. Keyed by the
## shelf, both of its layers lose exactly the same clumps, the pair merges
## vertically, and the clump is 2 x 2 x 2 aligned to the SHAPE.
static func _whorl_disc(writer, cx: int, y: int, cz: int, r: int,
		limits: Array[int], params: Dictionary, clump_key: int, rim: int) -> int:
	if r < 0:
		return 0
	var id: int = params["leaves"]
	if id == Block.AIR:
		return 0
	var fill: float = params["fill"]
	var seed: int = params["seed"]
	# The series cannot meet SALT_SPARSE's: see SALT_CLUMP.
	var clump_salt := SALT_CLUMP + clump_key * 7919
	var drawn := 0

	# THE SOLID CASE IS THE HOT PATH AND IT STAYS ONE LOOP. A crown with no
	# holes cannot strand anything - every cell of a plan of one radius touches
	# the cell inward of it - so spruce, beech and the hero never pay for the
	# machinery below.
	if fill >= 1.0:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if not _in_plan(dx, dz, limits[_sector_of(dx, dz)]):
					continue
				writer.set_block(cx + dx, y, cz + dz, id, true)
				drawn += 1
		return drawn

	# NOTHING FLOATS, AND IT IS A GUARANTEE RATHER THAN A PRECAUTION (judge
	# round 3). Round 2's shelves shed gold chips into the air, and the first
	# repair - keep the holes on the rim, and drop a cell whose inward
	# neighbour was hashed away - fixed the holes and missed the other half:
	# two cells at nearly the same azimuth can land in DIFFERENT sectors, and a
	# sector one block shorter than its neighbour cuts the ground out from under
	# the longer one's outermost cell. Chasing that geometrically is a proof
	# nobody can read.
	#
	# So the layer is built as a set, flooded from its own axis, and only what
	# the flood reached is written. It is a PURE function of the layer's own
	# arguments - no writer read-back, no neighbouring column, no order
	# dependence - so every chunk that draws this tree computes the same set and
	# the border test still passes. The axis cell is always in the set (the
	# spine is never a hole and `_in_plan` always admits the centre), and the
	# spine runs unbroken through every layer of the crown, so a layer connected
	# to its own axis is connected to the trunk.
	var side := 2 * r + 1
	var keep := PackedByteArray()
	keep.resize(side * side)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if not _in_plan(dx, dz, limits[_sector_of(dx, dz)]):
				continue
			if _clump_void(cx, cz, dx, dz, rim, seed, clump_salt, fill):
				continue
			keep[(dz + r) * side + dx + r] = 1

	var centre := r * side + r
	if keep[centre] != 1:
		return 0
	keep[centre] = 2
	var stack: Array[int] = [centre]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var ix := i % side
		var iz := i / side
		if ix > 0 and keep[i - 1] == 1:
			keep[i - 1] = 2
			stack.push_back(i - 1)
		if ix < side - 1 and keep[i + 1] == 1:
			keep[i + 1] = 2
			stack.push_back(i + 1)
		if iz > 0 and keep[i - side] == 1:
			keep[i - side] = 2
			stack.push_back(i - side)
		if iz < side - 1 and keep[i + side] == 1:
			keep[i + side] = 2
			stack.push_back(i + side)

	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if keep[(dz + r) * side + dx + r] != 2:
				continue
			writer.set_block(cx + dx, y, cz + dz, id, true)
			drawn += 1
	return drawn


## Is this cell's 2 x 2 clump a hole?
##
## HOLES LIVE ON THE RIM AND NOWHERE ELSE (judge round 3). The clump hash used
## to be asked of every cell outside the spine, so a hole three cells in could
## leave the cells outward of it standing on nothing - the gold chips floating
## off the shelf edges in the round-2 stand. Restricted to the outermost two
## rings (`not _in_plan(rim - 2)`) the chain a hole can break is two cells long,
## which the caller's one-step inward check closes completely.
##
## THE SPINE IS NEVER A HOLE either. An open crown is open at its TIPS - a
## larch is dense against its stem and wispy at the ends, and that is also the
## only way the openness stays subtractive rather than dissolving the tree.
## Hashing the spine too gave a stand of larches that photographed as a rubble
## pile: a dozen columns of detached slabs with nothing joining them.
static func _clump_void(cx: int, cz: int, dx: int, dz: int, rim: int,
		seed: int, clump_salt: int, fill: float) -> bool:
	if _in_plan(dx, dz, SPARSE_CORE) or _in_plan(dx, dz, rim - 2):
		return false
	return WorldHash.hash01((cx + dx) >> 1, (cz + dz) >> 1,
		seed, clump_salt) >= fill


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
	# WIDTH, NOT A FLAG (world feel v1 Stage 5). One threshold was enough while
	# the tallest tree was 42 blocks; with the forest at x2 and old growth at
	# x3 a 2 x 2 trunk under a 60-block spruce reads as a lollipop again. See
	# TRUNK_TIERS.
	var w: int = int(params.get("trunk_width", 2 if params.get("thick", false) else 1))
	var drawn := 0
	for y in range(ground + 1, top_y + 1):
		# Always to +X and +Z, so a wide trunk grows out of the same cell
		# corner every time - which matters for the jitter bound in the
		# placement rules: two neighbouring wide trunks must not be able to
		# close the gap between them.
		for dz in w:
			for dx in w:
				writer.set_block(bx + dx, y, bz + dz, id, false)
				drawn += 1
	return drawn


# --- The gallery ------------------------------------------------------------

## One row per species, in table order, for the model gallery's layout.
static func gallery_rows(config: WorldgenConfig = null) -> Array:
	var cfg := config if config != null else WorldgenConfig.new()
	var rows := []
	for i in table(cfg).size():
		rows.append({"id": i, "name": table(cfg)[i]["name"]})
	return rows


## The seed every gallery specimen is hashed under.
##
## A CONSTANT, AND NOT THE WORLD'S. The gallery photographs shapes, not a
## world, so its trees must not move when somebody plays a different seed -
## and a specimen photographed at one stage has to be the same specimen at the
## next, or two gallery sheets cannot be compared with each other at all.
const SPECIMEN_SEED := 20260824


## The cell stamp_specimen() hashes a specimen from, when the caller has not
## chosen one.
##
## Far from anything the world uses, varied per specimen, so the details a
## shape hashes for itself - lean, stubs, holes - differ between the three
## sizes instead of all three leaning the same way.
static func specimen_cell(species: int, t: float) -> Vector2i:
	return Vector2i(100000 + species * 37, 100000 + int(round(t * 2.0)) * 53)


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
	var cell := specimen_cell(species, t)
	return stamp_specimen_at(writer, species, bx, ground, bz, t,
		cell.x, cell.y, config)


## The same, from a cell the CALLER chooses.
##
## WHY THE CELL IS A PARAMETER (trees v1 Stage 0). One size of one species is
## one tree: `stamp_specimen()` derives its cell from the species and the size,
## so asking it twice gets the same specimen twice. That is right for a size
## row and useless for a variation row, which is n specimens of ONE species at
## ONE size and differs only in what the cell hashed - the lean, the holes, the
## shade, and everything the shape stages are about to hang off the same hash.
##
## Nothing else moves: stamp_specimen() calls straight through with the cell it
## always used, and the world has never called either of them.
static func stamp_specimen_at(writer, species: int, bx: int, ground: int,
		bz: int, t: float, cell_x: int, cell_z: int,
		config: WorldgenConfig = null) -> Dictionary:
	var cfg := config if config != null else WorldgenConfig.new()
	var params := params_for(species, cell_x, cell_z, SPECIMEN_SEED, cfg)
	var row: Dictionary = table(cfg)[species]
	# Override the two hashed sizes with the chosen ones; everything else the
	# hash decided stands.
	params["height"] = int(round(lerpf(
		float(row["height"].x), float(row["height"].y), t)))
	params["crown"] = int(round(lerpf(
		float(row["crown"].x), float(row["crown"].y), t)))
	params["thick"] = species == HERO or params["height"] >= THICK_TRUNK_HEIGHT
	params["trunk_width"] = trunk_width(int(params["height"]), species)

	var blocks := draw(writer, species, bx, ground, bz, params, cfg)
	return {
		"height": params["height"],
		"blocks": blocks,
		"params": params,
	}
