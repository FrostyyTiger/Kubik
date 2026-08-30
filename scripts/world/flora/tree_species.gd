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
## RETIRED AT TREES V1 STAGE 3, and the number stays claimed. It salted the
## krummholz's one-block lean, which the wind flag replaced - and the lean was
## also the loose-block bug the whole time, because it stepped the trunk out
## from under the crown it was carrying.
const SALT_LEAN := 213
const SALT_STUBS := 214
## RETIRED AT TREES V1 STAGE 3, and the number stays claimed. It salted the
## PER-BLOCK holes in a sparse crown, hashed from the block's own world position
## so that every chunk drawing one larch punched the same holes in it. The
## krummholz was the last species still asking it, and with the cushion drawn
## through `_whorl_disc` there is no per-block hole left anywhere in the file -
## which is what plan rule 6 asked for and what took the sparse species from
## dearer in quads than a solid beech to cheaper than they have ever been.
const SALT_SPARSE := 215
## Never used. Free.
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
## THE SERIES IS 217 + key * 7919 AND IT COULD NOT MEET SALT_SPARSE'S. That one
## was 215 + y * 7919: same stride, and the two offsets differ by 2, which no
## multiple of 7919 is. They shared a world until every sparse species had moved
## over, which finished at Stage 3 - the hazard is historical now, and the rule
## that no new salt may land on either series is not.
const SALT_CLUMP := 217
## Per-tier whorl arms: how many, how long each one is.
const SALT_WHORL := 218
## Per-layer crown radius jitter.
const SALT_JITTER := 219
## Everything a conifer decides once for itself: notch phase, arm phase, drift
## direction, top treatment, whether it self-pruned.
const SALT_CONIFER := 220

## Everything a beech decides once: how oblate it is, where its crown starts,
## how many lobes, which way the first one leans, the plan ellipse and its
## swap, whether it forks and how wide.
const SALT_BEECH := 221
## Per-lobe: the vertical jitter that stops four lobes from stacking in the
## same four places on every tree.
const SALT_LOBE := 222
## Per-bite: radius, how deep it cuts, how high up the side it lands.
const SALT_BITE := 223
## Everything a birch decides once: the bow, the clump layout, whether it grew
## a second stem and how far aside.
const SALT_BIRCH := 224
## THE SHARED WIND DIRECTION, and it is hashed from the SEED ALONE. See
## params_for() - this is the one hashed thing in the file that is a property of
## the world rather than of a tree.
const SALT_WIND := 225
## The limb blocks entering a beech's crown underside.
const SALT_LIMB := 226

## Everything a krummholz decides once (trees v1 Stage 3): how oblate its
## cushion is, one step of wind off the world's, and the ragged edge of its plan.
const SALT_KRUMM := 227
## Per-spar: which way off the axis it stands, how far, and how proud of the
## cushion it finishes.
const SALT_SPAR := 228
## Everything a snag decides: which of the three it is, where it broke, which
## way it leans, and the one direction neighbourhood its stubs all come out of.
const SALT_SNAG := 229
## Everything a hero decides once: which dead element it carries, where it
## forks, how many lobes, and the azimuth the whole crown is laid out from.
const SALT_HERO := 230
## Per-lobe and per-limb: how high up the crown a lobe rides and how long the
## limb that carries it runs.
const SALT_HERO_LOBE := 231


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
		# FILL 0.80, AND THE HOLES ARE CLUMPS NOW (trees v1 Stage 2). At 0.70,
		# hashed per block, the sparseness was the most expensive thing on the
		# tree - 588 blocks bought 937 quads - and at forty metres it read as
		# static rather than as leaves. The openness is the SHAPE now: three to
		# five clumps with real sky between them. What is left of the fill is a
		# texture on a solid thing, hashed at 2 x 2 under the clump's own key.
		"shape": SHAPE_SLENDER, "fill": BIRCH_FILL,
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
		# THE HERO TAKES ITS PARENT'S SIZE RANGE AND IDS, NOT ITS SHAPE (trees
		# v1 Stage 3). It used to be the same beech or spruce scaled, and a
		# scaled parent is exactly what the poster tradition says a big tree
		# must never be - bigness reads through changed PROPORTIONS, not
		# through magnification. What survives of the parent is which of the
		# two archetypes the hero is, the leaf and trunk ids that go with it,
		# and the height and crown roll the scale is applied to; `_draw_hero`
		# is the rest.
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

	# THE WIND BLOWS ONE WAY IN ONE WORLD, and this is the only thing in the
	# file hashed from the seed WITHOUT the cell. Every other decision here is
	# per-tree because two neighbours must not be the same tree; this one is
	# per-WORLD because a treeline that combed in twelve directions would read
	# as twelve accidents instead of as weather. The birch bows along it (Stage
	# 2) and the krummholz will flag along it (Stage 3), each taking a step or
	# two of its own variation off it - correlation is the point, uniformity is
	# not.
	var wind_dir := WorldHash.hash2(0, 0, world_seed, SALT_WIND) % GOLDEN_N

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
		"wind_dir": wind_dir,
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
	# THE HERO HAS ITS OWN SHAPE AGAIN (trees v1 Stage 3). Until tonight
	# SHAPE_HERO was a row in the table that nothing ever dispatched: the hero
	# took its PARENT's shape entry and drew as a scaled beech or spruce, which
	# is the one thing the poster tradition says a big tree must not be. It
	# keeps the parent for the leaf and trunk ids and for the broad archetype -
	# broadleaf or conifer - and nothing else.
	var shape: int = SHAPE_HERO if species == HERO \
		else table(config)[params.get("draw", species)]["shape"]
	match shape:
		SHAPE_WHORL_CONE:
			return _draw_whorl_cone(writer, bx, ground, bz, params)
		SHAPE_DOME:
			return _draw_beech(writer, bx, ground, bz, params)
		SHAPE_MOUND:
			return _draw_mound(writer, bx, ground, bz, params)
		SHAPE_SLENDER:
			return _draw_birch(writer, bx, ground, bz, params)
		SHAPE_BARE:
			return _draw_bare(writer, bx, ground, bz, params)
		SHAPE_HERO:
			return _draw_hero(writer, bx, ground, bz, params)
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


# --- The broadleaves (trees v1 Stage 2) --------------------------------------
#
# art-direction 2.5: a beech is "an oblate scallop 1.2-1.3x wider than tall,
# widest at 40% of the crown, a sky gap under it"; a birch is the pale trunk,
# and the pale trunk stays full height and visible. The consts below are what
# those two sentences cost in numbers, beside the shapes that read them.

## The beech's width : height, and how much of twice its half-width a LOBED
## union actually spans.
##
## A single ellipsoid 1.25 wide is 1.25 wide from every azimuth, which is the
## solid of revolution this stage exists to delete. Two lobes that between them
## reach the envelope in two directions and fall short of it everywhere else
## average about seven eighths of it - so the crown HEIGHT is derived from the
## envelope through that factor, or a lobed beech comes out taller than 2.5
## asks exactly when the lobes are doing their job.
const BEECH_OBLATE_MIN := 1.20
const BEECH_OBLATE_MAX := 1.30
const BEECH_UNION := 0.88

## Where the crown starts, as a fraction of total height, hashed +/- 0.08.
##
## THE SKY GAP IS THIS NUMBER. 2.5 asks for "a sky gap under it on a clean
## trunk", and on a voxel tree that is not a subtraction - it is where the
## foliage begins. Four tenths of the height in bare trunk, with the crown's own
## underside falling away above it (see BEECH_WIDE), is the whole of it.
const BEECH_BASE := 0.40
const BEECH_BASE_JITTER := 0.08

## The shortest crown, in layers, and the shortest as a share of the height the
## trunk fraction left over.
##
## THE FLOOR IS THE HERO'S, NOT THE BEECH'S. A hero draws as its parent, and a
## beech-parent hero is up to 84 blocks tall with a crown radius capped at 16:
## the oblate rule alone would give it a 23-layer crown on 61 blocks of bare
## trunk, which is a lollipop with a redesign inside it. The hero is
## re-proportioned in Stage 3; until then it keeps two thirds of the space it
## had. The floor does not bind on any beech - a beech's oblate crown is always
## the taller of the two numbers.
const BEECH_CROWN_MIN := 4
const BEECH_CROWN_FLOOR := 0.65

## Two to four lobes, and each one's horizontal radius as a fraction of the
## crown's half-width.
##
## BIG / MEDIUM / SMALL, AT ROUGHLY 60 / 25 / 15 OF THE VOLUME (trees research
## 2: broadleaf crowns are 2-4 overlapping lobes in a big/medium/small
## hierarchy). Volume goes as radius squared times vertical span, so 0.80 over a
## whole crown, 0.60 over seven tenths of one and 0.50 over half of one come out
## at 62 / 24 / 13 - and it is a HIERARCHY rather than three equal blobs,
## because three equal blobs are a cloud.
const BEECH_LOBE_MIN := 2
const BEECH_LOBE_MAX := 4
const BEECH_LOBE_A := [0.72, 0.54, 0.46, 0.42]

## And the same two when the tree forked: closer in size, because a forked beech
## carries two leaders and neither of them is the whole tree.
const BEECH_LOBE_FORK := [0.62, 0.58]

## Each lobe's vertical span, as fractions of the crown's own height. Lobe 0
## spans all of it; the others start above the underside and stop short of the
## top, so the outline is scalloped at both ends and not only in plan.
const BEECH_LOBE_LO := [0.00, 0.30, 0.12, 0.45]
const BEECH_LOBE_HI := [0.86, 1.00, 0.64, 0.94]

## Which of the thirteen directions each lobe leans, as a step off the tree's
## own. Six of thirteen is 166 degrees - the medium lobe sits opposite the big
## one, which is what a fork does and what a scallop looks like.
const BEECH_LOBE_DIR := [0, 6, 5, 10]

## How much of its available offset a SMALL lobe takes.
##
## THE HARD CAP IS THREE SILHOUETTE EVENTS PER TREE (trees research 2, Harper:
## "I try to leave everything out"), and a lobe is an event only if it breaks
## the outline. So the big and the medium lobe are pushed out until they touch
## the envelope - one event, and it is the scallop - while the small ones sit at
## half of theirs, inside the outline, where they cost the eye nothing and give
## the crown its lumpiness. That leaves two events for the bites.
const BEECH_TUCK := 0.5

## Where a lobe is widest as a fraction of its own height, and how far its upper
## half reaches.
##
## 0.40 IS 2.5's NUMBER, and it is what makes the underside fall away: below the
## widest point the profile runs out to nothing over four tenths of the crown,
## above it over six. The upper divisor is 0.63 rather than 0.60 so the top
## layer still carries a quarter of the radius - a beech is domed, not pointed.
const BEECH_WIDE := 0.40
const BEECH_TOP := 0.63

## The narrowest a hashed plan ellipse gets.
##
## AREA IS HELD: the long axis is the nominal radius divided by the root of the
## ratio and the short one multiplied by it, so a beech carries the same amount
## of tree whichever way its ellipse points and the mean crown mass does not
## move. The axis SWAP is hashed too, or every beech in the world would be long
## in the same direction, which is a solid of revolution with extra steps.
const BEECH_ELLIPSE_MIN := 0.80

## The share of beeches that fork, where they fork, and how far apart the two
## leaders stand.
##
## THE FORK IS THE CURE FOR THE DOME (trees research 3, lever 10). Two beeches
## in five, between 55 and 75 per cent of the height - which is inside the
## crown, so the leaders are read through foliage rather than against sky.
const BEECH_FORK_CHANCE := 0.40
const BEECH_FORK_LO := 0.55
const BEECH_FORK_HI := 0.75
const BEECH_FORK_MIN := 1
const BEECH_FORK_MAX := 3

## One or two bites, their radius and how deep they cut as fractions of the
## crown's half-width, and the band of the crown they land in.
##
## SUBTRACT, NEVER ADD. A bite is a sphere centred OUTSIDE the silhouette, so it
## can only remove - and it is the one lever that still reads at sixty to ninety
## metres, where a bump does not.
const BEECH_BITE_MIN := 1
const BEECH_BITE_MAX := 2
const BEECH_BITE_R := 0.55
const BEECH_BITE_DEPTH := 0.35
const BEECH_BITE_LO := 0.25
const BEECH_BITE_HI := 0.85
const BEECH_BITE_DIR := [3, 9]

## How far into the crown the trunk is drawn, as a fraction of the crown's
## height, so the foliage wraps the trunk instead of balancing on it.
const BEECH_TRUNK_INTO := 0.45

## The limb blocks entering the crown underside: how many, where up the crown,
## and how far past the trunk they reach.
##
## THE ONE DETAIL THAT SEPARATES "BEECH" FROM "LOLLIPOP" (trees research 2:
## always one visible fork or limb entering the crown from below). Every beech
## gets one or two, in TRUNK id and drawn BEFORE the foliage so the leaves -
## which go over air only - cannot paint over them, and on one of the four AXES
## so each block has a face against the one inward of it.
const BEECH_LIMB_MIN := 1
const BEECH_LIMB_MAX := 2
const BEECH_LIMB_LO := 0.08
const BEECH_LIMB_HI := 0.28
const BEECH_LIMB_LEN := 2


## BEECH. An oblate scallop: two to four overlapping ellipsoid LOBES in a
## big/medium/small hierarchy, one or two concave BITES taken out of the outside
## of it, two trees in five FORKED, a limb or two entering the underside, and a
## sky gap under all of it on a clean trunk.
##
## WHAT THIS REPLACES is the worst shape in the file. The old beech was one
## centred ellipsoid on one axis - `build/gallery/memo-baseline/
## species-beech.png` - and Stage 0 measured it at SYMMETRY 0.93, TWINS 1.00:
## two beeches hashed from two different cells were the same tree, and each of
## them was the same tree from every azimuth. It is the single picture this epic
## is judged by.
##
## THE CROWN IS BUILT AS A SET AND FLOODED FROM THE TRUNK. Beech is solid, so
## the lobes alone cannot strand anything - but a bite is a sphere subtracted
## from a union of spheres, and there is no local test that says whether it has
## just severed one. So rather than prove it cannot, the crown is rasterised
## into a byte volume, flooded in three dimensions from the cells the trunk
## stands in, and only what the flood reached is written. It is a pure function
## of this tree's own params - no writer read-back, no order dependence - so
## every chunk that draws this beech computes the same set and
## `_test_species_borders` holds. It is the same guarantee Stage 1 gave the
## larch's shelves, one dimension up.
static func _draw_beech(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var table_r: int = maxi(int(params["crown"]), 1)
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var id: int = params["leaves"]
	var w: int = maxi(int(params.get("trunk_width", 1)), 1)
	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_BEECH)
	var roll2 := _hash_keyed(cell, seed, SALT_BEECH, 2)
	var top := ground + h

	# THE PROPORTION IS THE SHAPE, and the table's crown is only the ceiling it
	# may not pass - the discipline the spruce's spire takes. The crown's height
	# comes from the half-width through the oblate ratio, so a beech is 1.2 to
	# 1.3 times wider than tall whatever the table rolled; and where the trunk
	# fraction did not leave that much room the HALF-WIDTH comes back down
	# instead, so the tree is a smaller scallop rather than a taller one.
	var oblate := lerpf(BEECH_OBLATE_MIN, BEECH_OBLATE_MAX,
		float(roll & 0xFF) / 255.0)
	var base_frac := BEECH_BASE + BEECH_BASE_JITTER \
		* (float((roll >> 8) & 0xFF) / 127.5 - 1.0)
	var base0 := ground + maxi(1, int(round(float(h) * base_frac)))
	var avail := maxi(top - base0 + 1, BEECH_CROWN_MIN)
	var crown_h := clampi(
		int(round(2.0 * float(table_r) * BEECH_UNION / oblate)),
		mini(maxi(BEECH_CROWN_MIN,
			int(round(float(avail) * BEECH_CROWN_FLOOR))), avail),
		avail)
	var rw := clampi(int(round(float(crown_h) * oblate
		/ (2.0 * BEECH_UNION))), 1, table_r)
	var crown_base := top - crown_h + 1

	var ratio := lerpf(BEECH_ELLIPSE_MIN, 1.0, float((roll >> 16) & 0xF) / 15.0)
	var sq := sqrt(ratio)
	var swap := ((roll >> 20) & 1) == 1

	var n_lobes := BEECH_LOBE_MIN \
		+ int((roll >> 21) % (BEECH_LOBE_MAX - BEECH_LOBE_MIN + 1))
	var d0 := int((roll >> 24) % GOLDEN_N)
	var forked := (roll2 & 0xFF) < int(BEECH_FORK_CHANCE * 256.0)
	var fork_d := BEECH_FORK_MIN \
		+ int((roll2 >> 8) % (BEECH_FORK_MAX - BEECH_FORK_MIN + 1))

	# Each lobe as (plan radius along x, along z, offset x, offset z) and its
	# (bottom, top) layer. Laid out before anything is drawn, because a leader
	# is drawn UP TO its own lobe and the limbs go in under the lowest one.
	var lobes: Array[Vector4i] = []
	var spans: Array[Vector2i] = []
	for i in n_lobes:
		var lr := _hash_keyed(cell, seed, SALT_LOBE, i)
		var frac: float = BEECH_LOBE_FORK[i] if forked and i < 2 \
			else BEECH_LOBE_A[i]
		var m := maxi(int(round(float(rw) * frac)), 1)
		var ra := clampi(int(round(float(m) / sq)), 1, rw)
		var rb := clampi(int(round(float(m) * sq)), 1, rw)
		if swap:
			var t := ra
			ra = rb
			rb = t
		# THE OFFSET IS WHAT THE ENVELOPE HAS LEFT OVER. `_golden_offset` never
		# returns a component longer than the distance asked of it, so a lobe
		# pushed out by `rw - reach` cannot write further than `rw` from the
		# root - which is the crown radius the table declared and every column
		# in the world widened its candidate scan by.
		var reach := maxi(ra, rb)
		var omax := maxi(rw - reach, 0)
		var o := omax if i < 2 else int(round(float(omax) * BEECH_TUCK))
		var off := _golden_offset(
			GOLDEN_DIRS[(d0 + int(BEECH_LOBE_DIR[i])) % GOLDEN_N], o)
		var jit := 0 if i == 0 else int(lr % 3) - 1
		var y0 := clampi(crown_base
			+ int(round(float(crown_h - 1) * BEECH_LOBE_LO[i])) + jit,
			crown_base, top)
		var y1 := clampi(crown_base
			+ int(round(float(crown_h - 1) * BEECH_LOBE_HI[i])) + jit,
			mini(y0 + 1, top), top)
		lobes.append(Vector4i(ra, rb, off.x, off.y))
		spans.append(Vector2i(y0, y1))

	# The bites, as (offset x, offset z, altitude, radius). A bite that would
	# reach the CORE is skipped rather than moved: the flood below seeds on the
	# trunk's own cells, and a bite that ate them would take the crown with it.
	var core := w + 1
	var n_bites := BEECH_BITE_MIN \
		+ int((roll2 >> 12) % (BEECH_BITE_MAX - BEECH_BITE_MIN + 1))
	var bites: Array[Vector4i] = []
	for j in n_bites:
		var brl := _hash_keyed(cell, seed, SALT_BITE, j)
		var br := clampi(int(round(float(rw) * BEECH_BITE_R))
			+ int(brl % 3) - 1, 2, rw)
		var depth := clampi(int(round(float(rw) * BEECH_BITE_DEPTH))
			+ int((brl >> 4) % 3) - 1, 2, maxi(rw - core, 0))
		if depth < 2:
			continue
		var boff := _golden_offset(GOLDEN_DIRS[
			(d0 + int(BEECH_BITE_DIR[j % BEECH_BITE_DIR.size()])) % GOLDEN_N],
			rw + br - depth)
		if boff.x * boff.x + boff.y * boff.y < (br + core) * (br + core):
			continue
		bites.append(Vector4i(boff.x, boff.y,
			crown_base + int(round(float(crown_h - 1)
				* lerpf(BEECH_BITE_LO, BEECH_BITE_HI,
					float((brl >> 8) & 0xFF) / 255.0))), br))

	# The trunk, the leaders and the limbs go in FIRST and in trunk id, so the
	# foliage - drawn over air only - cannot paint over any of them.
	var drawn := 0
	var stem_top := crown_base + int(round(float(crown_h) * BEECH_TRUNK_INTO))
	if forked:
		var fork_y := clampi(ground + int(round(float(h)
			* lerpf(BEECH_FORK_LO, BEECH_FORK_HI,
				float((roll2 >> 16) & 0xFF) / 255.0))),
			mini(crown_base, top - 2), top - 2)
		stem_top = fork_y
		drawn += _draw_trunk(writer, bx, ground, bz, fork_y, params)
		var lw := maxi(w - 1, 1)
		for i in 2:
			var sp: Vector2i = spans[mini(i, spans.size() - 1)]
			var lead_top := clampi(sp.x
				+ int(round(float(sp.y - sp.x) * BEECH_WIDE)), fork_y + 1, top)
			drawn += _draw_leader(writer, bx, bz, fork_y + 1, lead_top,
				GOLDEN_DIRS[(d0 + int(BEECH_LOBE_DIR[i])) % GOLDEN_N],
				(fork_d + 1 - i) / 2, lw, params["trunk_id"])
	else:
		drawn += _draw_trunk(writer, bx, ground, bz, stem_top, params)

	var n_limbs := BEECH_LIMB_MIN \
		+ int((roll2 >> 24) % (BEECH_LIMB_MAX - BEECH_LIMB_MIN + 1))
	for j in n_limbs:
		var lrl := _hash_keyed(cell, seed, SALT_LIMB, j)
		var yl := clampi(crown_base + int(round(float(crown_h - 1)
			* lerpf(BEECH_LIMB_LO, BEECH_LIMB_HI, float(lrl & 0xFF) / 255.0))),
			crown_base, maxi(stem_top, crown_base))
		var step: Vector2i = NUB_DIRS[int((lrl >> 8) % NUB_DIRS.size())]
		for d in range(1, BEECH_LIMB_LEN + 1):
			# Out past the trunk's own width on the sides it grows to, so the
			# first block of a limb has a face against the trunk and every one
			# after it against the block inward of it.
			var lx := 0
			var lz := 0
			if step.x != 0:
				lx = (w - 1 + d) if step.x > 0 else -d
			else:
				lz = (w - 1 + d) if step.y > 0 else -d
			writer.set_block(bx + lx, yl, bz + lz, params["trunk_id"], false)
			drawn += 1

	if id == Block.AIR:
		return drawn

	# --- the crown, as a set, flooded, then written -------------------------
	var side := 2 * rw + 1
	var plane := side * side
	var keep := PackedByteArray()
	keep.resize(plane * crown_h)

	for i in lobes.size():
		var lobe: Vector4i = lobes[i]
		var sp: Vector2i = spans[i]
		var span := maxi(sp.y - sp.x, 1)
		for y in range(sp.x, sp.y + 1):
			var v := float(y - sp.x) / float(span)
			# WIDEST AT 0.40 OF ITS OWN HEIGHT, with a different quarter-ellipse
			# either side of that: the underside falls away, the top is domed.
			var q := (BEECH_WIDE - v) / BEECH_WIDE if v <= BEECH_WIDE \
				else (v - BEECH_WIDE) / BEECH_TOP
			var f := sqrt(maxf(1.0 - q * q, 0.0))
			var ay := int(round(float(lobe.x) * f))
			var by := int(round(float(lobe.y) * f))
			var iy := (y - crown_base) * plane
			for dz in range(lobe.w - by, lobe.w + by + 1):
				var row := iy + (dz + rw) * side
				for dx in range(lobe.z - ay, lobe.z + ay + 1):
					if not _in_plan_ab(dx - lobe.z, dz - lobe.w, ay, by):
						continue
					if _bitten(bites, dx, dz, y):
						continue
					keep[row + dx + rw] = 1

	# Seeded on the trunk's own footprint and on the big lobe's axis, which the
	# bites are forbidden to reach and which the trunk therefore always
	# connects to.
	var seeds: Array[int] = []
	_add_seed(seeds, lobes[0].z, lobes[0].w, rw, side)
	for dz in w:
		for dx in w:
			_add_seed(seeds, dx, dz, rw, side)
	var stack: Array[int] = []
	for iy in crown_h:
		for s in seeds:
			var i2: int = iy * plane + s
			if keep[i2] == 1:
				keep[i2] = 2
				stack.push_back(i2)

	while not stack.is_empty():
		var i3: int = stack.pop_back()
		var ry := i3 / plane
		var rem := i3 % plane
		var rz := rem / side
		var rx := rem % side
		if rx > 0 and keep[i3 - 1] == 1:
			keep[i3 - 1] = 2
			stack.push_back(i3 - 1)
		if rx < side - 1 and keep[i3 + 1] == 1:
			keep[i3 + 1] = 2
			stack.push_back(i3 + 1)
		if rz > 0 and keep[i3 - side] == 1:
			keep[i3 - side] = 2
			stack.push_back(i3 - side)
		if rz < side - 1 and keep[i3 + side] == 1:
			keep[i3 + side] = 2
			stack.push_back(i3 + side)
		if ry > 0 and keep[i3 - plane] == 1:
			keep[i3 - plane] = 2
			stack.push_back(i3 - plane)
		if ry < crown_h - 1 and keep[i3 + plane] == 1:
			keep[i3 + plane] = 2
			stack.push_back(i3 + plane)

	for iy in crown_h:
		var y := crown_base + iy
		var base_i := iy * plane
		for dz in range(-rw, rw + 1):
			var row := base_i + (dz + rw) * side
			for dx in range(-rw, rw + 1):
				if keep[row + dx + rw] != 2:
					continue
				writer.set_block(bx + dx, y, bz + dz, id, true)
				drawn += 1
	return drawn


## One plan cell of the flood's seed set, if it is inside the crown's box.
##
## The bound matters: a hero's trunk is four voxels square and its crown box can
## be narrower than that, so a seed taken on faith would index past the array.
static func _add_seed(seeds: Array[int], dx: int, dz: int, rw: int,
		side: int) -> void:
	if absi(dx) > rw or absi(dz) > rw:
		return
	var i := (dz + rw) * side + dx + rw
	if not seeds.has(i):
		seeds.append(i)


## Is this cell inside any of the bites?
##
## A true sphere, because a bite is read as a scoop out of the side of a crown
## and a scoop with flat sides is a chamfer. It costs two multiply-adds per
## candidate cell, and it is the only thing in the beech that subtracts.
static func _bitten(bites: Array[Vector4i], dx: int, dz: int, y: int) -> bool:
	for b in bites:
		var ex := dx - b.x
		var ez := dz - b.y
		var ey := y - b.z
		if ex * ex + ez * ez + ey * ey <= b.w * b.w:
			return true
	return false


## One leader of a forked beech: a narrow stem that steps sideways one block a
## layer until it stands `dist` off the trunk, then rises straight.
##
## ONE STEP AT A TIME, AND THE BRIDGE BLOCKS ARE WHY. A one-wide column that
## moves sideways at all between two layers touches the block below it at an
## EDGE and at no face - the same floating block the dead stubs and the leader
## nubs were fixed for in Stage 1, and the sweep caught it again here on ANY
## step rather than only on a diagonal one. Two blocks in the upper layer - one
## directly above the old offset, one across to the new one - make every step
## face-connected. A two-wide column overlaps itself across a step and needs
## none of this.
static func _draw_leader(writer, bx: int, bz: int, y0: int, y1: int,
		dir: Vector2i, dist: int, w: int, id: int) -> int:
	var drawn := 0
	var prev := Vector2i.ZERO
	for y in range(y0, y1 + 1):
		var off := _golden_offset(dir, mini(y - y0 + 1, maxi(dist, 0)))
		if w < 2 and off != prev:
			writer.set_block(bx + prev.x, y, bz + prev.y, id, false)
			writer.set_block(bx + off.x, y, bz + prev.y, id, false)
			drawn += 2
		for dz in w:
			for dx in w:
				writer.set_block(bx + off.x + dx, y, bz + off.y + dz, id, false)
				drawn += 1
		prev = off
	return drawn


# --- The krummholz cushion (trees v1 Stage 3) --------------------------------
#
# art-direction 2.5, in one sentence: "a cushion 2.0-2.5x wider than tall, flat
# top, no spike". The consts below are what that costs in numbers.

## Width : height of the cushion. THE PROPORTION IS THE SHAPE and the table's
## crown radius is only the ceiling it may not pass - the discipline the
## spruce's spire and the beech's scallop both take. A tall krummholz is
## therefore held to the table and comes out flatter than 2.0; a short one is
## the full cushion.
const CUSHION_MIN := 2.0
const CUSHION_MAX := 2.5

## How much of its DOWNWIND radius the cushion keeps on the UPWIND side.
##
## THE FLAG IS THE SPECIES, AND IT IS THE ONLY ASYMMETRY THAT MAY BE SHARED.
## Every krummholz in a world combs the same way, because `params["wind_dir"]`
## is hashed from the seed alone - a treeline that flagged in thirteen
## directions would read as thirteen accidents rather than as weather (trees
## research 3, lever 12). One step of its own off the world's is all a tree
## gets, which is the birch's precedent from Stage 2.
const FLAG_UPWIND := 0.60

## How much of its own plan radius a sector still holds at the TOP layer.
##
## FLAT TOP AND NO SPIKE (2.5). Upwind the cushion keeps nearly its whole width
## all the way up, so the top is a plateau and the windward face is steep;
## downwind it falls to a one-block skirt, which is the flag. A half-ellipsoid
## - what this replaces - closes to a point at the top, which is the one
## silhouette 2.5 names and rejects.
const FLAG_TOP_UP := 0.85
const FLAG_TOP_DOWN := 0.10

## How far a sector's edge may run in or out of its nominal radius. One block,
## hashed per direction and held for the whole tree, so the taper up any one
## sector stays monotone and the cushion never overhangs itself.
const CUSHION_EDGE := 1

## The bare dead spars: how many, and how far proud of the mass they finish.
##
## THREE VOXELS, AND AN ENORMOUS READ. A cushion is a blob at any distance; one
## grey spike out of it is a tree that has been up there a long time and lost
## an argument with the weather. They are drawn from the GROUND up in
## TRUNK_DEAD rather than hung off the surface - the buried half costs four
## blocks and is what makes a spar part of the shrub instead of a chip in the
## sky.
## ONE SPAR ON THREE TREES IN FOUR (judge round 2). Two spars two blocks proud
## on every cushion photographed as a graveyard: the round-1 stand was a dozen
## shrubs behind two dozen pale posts, and the posts were the subject. A spar is
## punctuation, and punctuation on every word is not punctuation.
const SPAR_MIN := 1
const SPAR_MAX := 2
const SPAR_TWO_CHANCE := 0.25
const SPAR_PROUD_MIN := 1
const SPAR_PROUD_MAX := 2


## KRUMMHOLZ. A wind-flagged cushion: wider than tall, flat on top, steep and
## thick on the windward side, tapering to a one-block skirt downwind, with one
## or two bare dead spars standing proud of it.
##
## This is the tree that makes a treeline read as a treeline rather than as a
## line. Above the last upright spruce, real mountainsides carry wind-flattened
## pine that is more shrub than tree, and it thins out over a hundred metres
## instead of stopping.
##
## WHAT THIS REPLACES was a half-ellipsoid on a leaning stub: the most
## symmetric thing left in the file at Stage 2 (SYMMETRY 0.99, TWINS 0.97), and
## the only species the loose-block sweep was still red on - about a thousand
## floating blocks, two per tree at worst, because the lean stepped the trunk
## one block sideways and the dome it carried shed cells off the bottom edge on
## the far side. Both are gone for the same reason: the mound goes through
## `_whorl_disc` now, which builds every layer as a SET and floods it from its
## own axis before writing, so a cell the flood could not reach is never drawn.
## The axis column is solid from the ground up - the spine is never a hole -
## so a layer connected to its own axis is connected to the trunk.
static func _draw_mound(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = maxi(int(params["height"]), 1)
	var table_r: int = maxi(int(params["crown"]), 1)
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_KRUMM)
	var roll2 := _hash_keyed(cell, seed, SALT_KRUMM, 2)

	var ratio := lerpf(CUSHION_MIN, CUSHION_MAX, float(roll & 0xFF) / 255.0)
	var r := clampi(int(round(float(h) * ratio * 0.5)), 1, table_r)
	# AND THE HEIGHT COMES BACK OUT OF THE RATIO (judge round 2). The width is
	# capped by the table, so a tall krummholz that kept its table height came
	# out at four wide by five tall - which is not a cushion, it is a bush, and
	# 2.5 names that silhouette to reject it. Inverting the ratio against the
	# width the table actually allowed is what makes the proportion true for
	# every size rather than only the small ones. It can only ever SHORTEN the
	# tree.
	h = clampi(int(round(2.0 * float(r) / ratio)), 1, h)

	var wind := (int(params.get("wind_dir", 0)) + GOLDEN_N
		+ int((roll >> 8) % 3) - 1) % GOLDEN_N
	var wv: Vector2i = GOLDEN_DIRS[wind]

	# The cushion, as thirteen (base radius, top radius) pairs.
	#
	# A DOT PRODUCT, NOT AN ANGLE. Both vectors are authored at magnitude eight,
	# so their dot over 64 is the cosine between them without a line of trig -
	# and trig in shape code is forbidden anyway, because two machines stamp the
	# same chunk independently. `u` is 1 straight downwind and 0 straight into
	# the wind.
	var base_r: Array[int] = []
	var top_r: Array[int] = []
	base_r.resize(GOLDEN_N)
	top_r.resize(GOLDEN_N)
	for s in GOLDEN_N:
		var d: Vector2i = GOLDEN_DIRS[s]
		var u := clampf(
			(float(d.x * wv.x + d.y * wv.y) / 64.0 + 1.0) * 0.5, 0.0, 1.0)
		# Two bits per sector: in, out, and twice unchanged, so an edge holds
		# still more often than it moves - `_shelf_limits`' rule, one species
		# over. Hashed ONCE for the tree rather than per layer, which is what
		# keeps every sector's taper monotone: a cell present at one layer is
		# present at the layer below it, so the cushion never overhangs.
		var step := int((roll2 >> (s * 2)) & 3)
		var j := 0
		if step == 0:
			j = -CUSHION_EDGE
		elif step == 3:
			j = CUSHION_EDGE
		var rb := clampi(int(round(float(r) * lerpf(FLAG_UPWIND, 1.0, u))) + j,
			1, r)
		base_r[s] = rb
		top_r[s] = mini(int(round(float(rb)
			* lerpf(FLAG_TOP_UP, FLAG_TOP_DOWN, u))), rb)

	# A stub of a trunk, one or two blocks, and PLUMB. The lean is in the plan
	# now, where it cannot strand anything.
	var drawn := _draw_trunk(writer, bx, ground, bz,
		ground + 1 + int((roll >> 16) & 1), params)
	drawn += _draw_spars(writer, bx, ground, bz, h, base_r, top_r, wv, params)

	var limits: Array[int] = []
	limits.resize(GOLDEN_N)
	for i in h:
		var v := float(i) / float(maxi(h - 1, 1))
		var widest := 0
		for s in GOLDEN_N:
			limits[s] = int(round(lerpf(float(base_r[s]), float(top_r[s]), v)))
			widest = maxi(widest, limits[s])
		drawn += _whorl_disc(writer, bx, ground + 1 + i, bz, widest, limits,
			params, 0, widest)
	return drawn


## The one or two dead spars a krummholz carries.
##
## ON THE UPWIND HALF, SNAPPED TO AN AXIS, AND DRAWN FROM THE GROUND. Upwind is
## where the cushion is thick, so a spar there stands out of a mass rather than
## out of the skirt; the axis snap is Stage 1's dead-stub lesson (a diagonal
## offset touches the column beside it at an edge and at no face); and starting
## at the ground rather than at the surface is four buried blocks bought
## against any chance of a spar hanging in the air.
##
## `surf` is where the cushion's own surface is at that plan cell, computed from
## the same thirteen numbers the layers are drawn from - pure, and never read
## back from the writer.
static func _draw_spars(writer, bx: int, ground: int, bz: int, h: int,
		base_r: Array[int], top_r: Array[int], wv: Vector2i,
		params: Dictionary) -> int:
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var roll := _hash_keyed(cell, seed, SALT_SPAR, 0)
	var n := SPAR_MIN
	if int(roll & 0xFF) < int(SPAR_TWO_CHANCE * 256.0):
		n = SPAR_MAX
	var up := Vector2i(-signi(wv.x), 0) if absi(wv.x) >= absi(wv.y) \
		else Vector2i(0, -signi(wv.y))
	var perp := Vector2i(-up.y, up.x)
	var drawn := 0
	for j in n:
		var sr := _hash_keyed(cell, seed, SALT_SPAR, 1 + j)
		var off := up * (1 + int(sr % 2)) + perp * (int((sr >> 3) % 3) - 1)
		var s := _sector_of(off.x, off.y)
		var surf := 1
		for i in h:
			var v := float(i) / float(maxi(h - 1, 1))
			if _in_plan(off.x, off.y, int(round(
					lerpf(float(base_r[s]), float(top_r[s]), v)))):
				surf = i + 1
		var proud := SPAR_PROUD_MIN + int((sr >> 6)
			% (SPAR_PROUD_MAX - SPAR_PROUD_MIN + 1))
		for y in range(ground + 1, ground + surf + proud + 1):
			writer.set_block(bx + off.x, y, bz + off.y, Block.TRUNK_DEAD, false)
			drawn += 1
	return drawn


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
# answer, exactly as NUB_DIRS is.

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


## The birch's crown, as fractions of TOTAL height: where it starts (hashed),
## where its widest clump sits, how fast it narrows either side of that, and how
## narrow it may get.
##
## THE PALE TRUNK IS THE SPECIES (2.5), which is why the trunk is drawn to full
## height and why the crown is not a crown so much as three to five small clumps
## strung along the top half of the stem with sky between them. A birch whose
## foliage closed over its own trunk would be a thin beech.
const BIRCH_CROWN_BASE := 0.52
const BIRCH_CROWN_JITTER := 0.03
const BIRCH_WIDE := 0.65
const BIRCH_WIDE_SPREAD := 0.50
const BIRCH_NARROW := 0.80

## The clumps: how many, how deep, and how much air between two of them.
##
## THREE TO FIVE, AND THE SPAN DECIDES WHICH, laid out DOWNWARDS from the top
## exactly as the larch's ziggurat is - a crown laid out from the top can never
## leave the tree with a bald tip, and where the stack runs out is where the
## crown begins. The gap is the species: it is what "you can see through a
## birch" means at a distance where a per-block hole is invisible.
const CLUMP_MIN := 3
const CLUMP_MAX := 5
const CLUMP_DEEP := 4
const CLUMP_SHALLOW := 2
const CLUMP_GAP_MIN := 1
const CLUMP_GAP_MAX := 2

## The bow, in blocks, and the height above which a birch may take the second.
##
## B DOMINANT AND A ZERO - A BIRCH ARCHES, IT DOES NOT TILT. The drift curve the
## research prices is `off(t) = A*t + B*4t(1-t)`: A leans the tree, B bows it,
## and the two read completely differently at stand scale. A stand of leaning
## trees is a windthrow; a stand of bowed ones is a birch wood. So A is zero and
## the whole displacement is the single-peaked term, which returns the crown
## over the root at the top. Never more than two blocks, and only on a tall one.
const BIRCH_BOW_MIN := 1
const BIRCH_BOW_MAX := 2
const BIRCH_BOW_TALL := 20

## The share of birches that grow as two stems from one base, how far aside the
## second one stands, and the fill left in a clump once the shape carries the
## openness.
##
## 0.80 AND CLUMPED, not 0.70 per block: see the table row. The holes are a
## texture on a solid thing now, and the sky comes from the gaps between the
## clumps, where the mesher charges nothing for it.
const BIRCH_TWO_CHANCE := 0.40
## How many arms a clump's edge is cut into. Three: a clump is small, and
## more arms than that on a radius of three is a circle again.
const BIRCH_ARMS := 3
const BIRCH_STEM_MIN := 1
const BIRCH_STEM_MAX := 2
const BIRCH_FILL := 0.88


## BIRCH. The pale trunk, full height and visible, with three to five small
## clumps strung along the top half of it - and the whole stem BOWED along the
## world's one wind direction.
##
## WHAT THIS REPLACES was a lollipop: one ellipsoid over the top 45%, its holes
## hashed per block. Stage 0 measured SYMMETRY 0.78 and TWINS 0.99, and the 0.78
## was not structure - it was per-block NOISE, the cheapest possible way to look
## different and the most expensive one to draw (588 blocks bought 937 quads,
## more than a max beech's whole crown). The noise is gone and real structure
## replaces it: where the clumps sit, which way the tree bows, and whether it
## grew one stem or two.
##
## Everything is hashed from the cell except the wind, which is hashed from the
## SEED - see `params_for()`. Foliage goes through `_whorl_disc`, so the clumped
## fill takes the flood-from-axis guarantee with it and nothing floats.
static func _draw_birch(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = params["height"]
	var table_r: int = maxi(int(params["crown"]), 1)
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_BIRCH)
	var roll2 := _hash_keyed(cell, seed, SALT_BIRCH, 2)
	var top := ground + h

	# THE WHOLE WOOD BOWS ONE WAY, and one step of variation off it is all a
	# tree gets. Correlation beats variation at stand scale (trees research 3,
	# lever 12): a treeline that combed in thirteen directions would read as
	# thirteen accidents rather than as weather.
	#
	# THE BOW, THE SPLAY AND THE CLUMP OFFSET SPEND ENVELOPE, and they spend
	# it outside the birch's own table crown - eleven blocks of Chebyshev
	# reach against the row's five. That is the spruce's precedent from Stage
	# 1, where the drift is added on top of a spire already at the table
	# radius: the bound the world actually widens its candidate scan by is
	# `max_reach()`, which is the WIDEST species' crown plus the widest trunk
	# - twenty-eight blocks - and a birch at eleven is nowhere near it. The
	# beech, which IS one of the wide species, stays strictly inside its own.
	var wind := (int(params.get("wind_dir", 0)) + GOLDEN_N
		+ int(roll % 3) - 1) % GOLDEN_N
	var bow_dir: Vector2i = GOLDEN_DIRS[wind]
	var bow := BIRCH_BOW_MIN
	if h >= BIRCH_BOW_TALL:
		bow += int((roll >> 4) % (BIRCH_BOW_MAX - BIRCH_BOW_MIN + 1))

	var cb_frac := BIRCH_CROWN_BASE + BIRCH_CROWN_JITTER \
		* (float((roll >> 8) & 0xFF) / 127.5 - 1.0)
	var crown_lo := ground + maxi(1, int(round(float(h) * cb_frac)))
	var span := maxi(top - crown_lo + 1, CLUMP_SHALLOW)
	# THE LAYOUT IS THE ONE THAT FILLS THE MOST OF THE CROWN, and where two
	# fill the same it is the one with MORE clumps (judge round 4).
	#
	# Two rounds of picking the count first and letting the depth fall out of
	# it, and two of the reverse, and both are wrong for the same reason: the
	# span is small - eleven to thirteen layers on an ordinary birch - and
	# every arrangement that fits trades depth against count almost exactly.
	# Three clumps of three fill nine layers of thirteen; four of two fill
	# eight. A tree read as bare poles with bracket fungus on one side either
	# way, because the layout was never what was starving it - the WIDTH was.
	# So this searches the nine arrangements and keeps the fullest, the width
	# below takes the table radius, and the gaps take whatever is left, which
	# is one layer nearly always.
	var deep := CLUMP_SHALLOW
	var n := CLUMP_MIN
	var best := -1
	for d in range(CLUMP_SHALLOW, CLUMP_DEEP + 1):
		for c in range(CLUMP_MIN, CLUMP_MAX + 1):
			if c * d + (c - 1) * CLUMP_GAP_MIN > span:
				continue
			if c * d > best or (c * d == best and c > n):
				best = c * d
				deep = d
				n = c
	if best < 0:
		# A tree too short for even three clumps: take what the span will hold.
		n = clampi((span + CLUMP_GAP_MIN) / (CLUMP_SHALLOW + CLUMP_GAP_MIN),
			1, CLUMP_MAX)

	var gaps: Array[int] = []
	var stack_h := n * deep
	var remain := span - stack_h
	for k in maxi(n - 1, 0):
		var left := n - 1 - k
		var g := clampi(remain / maxi(left, 1), CLUMP_GAP_MIN, CLUMP_GAP_MAX)
		if g < CLUMP_GAP_MAX and remain - g * left > 0 \
				and ((roll2 >> (8 + k)) & 1) == 1:
			g += 1
		g = clampi(g, CLUMP_GAP_MIN,
			maxi(remain - (left - 1) * CLUMP_GAP_MIN, CLUMP_GAP_MIN))
		gaps.append(g)
		stack_h += g
		remain -= g

	# Where each clump's bottom layer sits, worked out before anything is drawn
	# so the second stem can stop at the top of the last clump it carries.
	var floors: Array[int] = []
	var y := maxi(top - stack_h + 1, ground + 2)
	for k in n:
		floors.append(y)
		y += deep
		if k < n - 1:
			y += gaps[k]
	# AND THE TOP CLUMP IS A CAP: it sits ON the stem top, and it never sits
	# off to one side (judge round 4). The stack is laid out from the top
	# already, so this only bites on a tree short enough for the clamp above
	# to have pushed the whole stack down - and when it does bite, the tree
	# ends in a bare spike, which is the one thing no birch may do. The gap a
	# birch is for lives BETWEEN the clumps, never over the last one.
	floors[n - 1] = maxi(floors[n - 1], top - deep + 1)

	# TWO STEMS FROM ONE BASE, on two birches in five. The second is shorter,
	# carries the lowest clump or two, and steps aside ONE BLOCK A LAYER so its
	# foot is against the first one's rather than beside it in the air.
	var two := (roll2 & 0xFF) < int(BIRCH_TWO_CHANCE * 256.0)
	var take := 0
	var side_dir: Vector2i = GOLDEN_DIRS[(wind + 3) % GOLDEN_N]
	var side_d := 0
	if two and n >= 2:
		take = mini(1 + int((roll2 >> 20) & 1), n - 1)
		side_d = BIRCH_STEM_MIN \
			+ int((roll2 >> 22) % (BIRCH_STEM_MAX - BIRCH_STEM_MIN + 1))

	var drawn := _draw_bowed_stem(writer, bx, ground, bz, ground + 1, top - 1,
		bow_dir, bow, h, side_dir, 0, params)
	if take > 0:
		drawn += _draw_bowed_stem(writer, bx, ground, bz, ground + 1,
			mini(floors[take - 1] + deep, top - 1), bow_dir, bow, h,
			side_dir, side_d, params)

	var id: int = params["leaves"]
	if id == Block.AIR:
		return drawn
	var limits: Array[int] = []
	limits.resize(GOLDEN_N)
	for k in n:
		var stem_off := _golden_offset(side_dir, side_d) if k < take \
			else Vector2i.ZERO
		var soff := stem_off
		var mid := floors[k] + deep / 2
		# WIDEST AT TWO THIRDS OF THE TREE, not of the crown. The crown is the
		# top half, so a profile read against the crown would put the widest
		# clump in the middle of it and the birch back on the lollipop.
		var u := (float(mid - ground) / float(maxi(h, 1)) - BIRCH_WIDE) \
			/ BIRCH_WIDE_SPREAD
		var wgt := clampf(1.0 - u * u, BIRCH_NARROW, 1.0)
		# THE DEPTH SETS THE WIDTH, AND IT SETS IT TWO BLOCKS OVER (judge
		# rounds 1-4). At the table's own radius a clump is nine blocks across
		# and reads as a PLATE bolted to the stem - the first vary row was a
		# bonsai, not a birch. But narrowing it was the wrong half of the
		# answer twice over: at the depth exactly, and even at depth plus one,
		# the crown was a rounding error on a pole. With four or five clumps a
		# layer apart the mass has to come from somewhere, and width is where
		# the quads are cheapest - a wide clump greedy-meshes into long runs
		# where a tall one is all rim.
		#
		# THREE OVER THE DEPTH, WHICH MAKES THE TABLE RADIUS THE REAL CEILING.
		# With the count biased to four or five the depth lands at two on every
		# ordinary birch, so a cap of depth-plus-two held the crown to four
		# blocks against a table radius of five and the tree stayed bald. The
		# depth still governs - it is what keeps a two-layer clump from being
		# nine blocks across on a shrub - but on a full-grown birch the table
		# is what binds, which is where it should have been all along.
		var rk := clampi(int(round(float(mini(table_r, deep + 3)) * wgt))
			+ _radius_jitter(cell, seed, k), 3, table_r)
		# AND A CLUMP SITS OFF THE STEM (judge rounds 1 and 2). Concentric
		# clumps on one axis are a stack of PLATES however round each one is,
		# and two rounds of narrowing them only made the pagoda thinner. The
		# offset is what makes a stem read as STRUNG with foliage rather than
		# skewered through it, and two clumps at nearly one height on opposite
		# sides read as a crown rather than as a rung.
		#
		# ONE BLOCK, ON ONE OF THE FOUR AXES, AND NEVER ON THE CAP (judge round
		# 4). Two blocks was too far: a clump standing that far out reads as a
		# SHELF bolted to the side of the stem rather than a mass the stem
		# passes through, which is the whole difference between a birch and a
		# bracket fungus. One block still breaks the concentric stack, which is
		# what the offset was for.
		#
		# A block is inside `rk - 1` of the clump's centre, which `_arm_limits`
		# holds solid, so the offset clump still covers the stem cell each
		# layer's flood is seeded from - which is the whole of why a clump is
		# attached to the tree rather than hanging beside it. A DIAGONAL offset
		# would not do: two blocks meeting at a corner meet at no face, which
		# is Stage 1's lesson three times over.
		var croll := _hash_keyed(cell, seed, SALT_BIRCH, 16 + k)
		if k < n - 1 and int(croll % 3) > 0:
			soff += NUB_DIRS[int((croll >> 2) % NUB_DIRS.size())] \
				* mini(1, maxi(rk - 1, 0))
		for j in deep:
			var yy := floors[k] + j
			if yy > top:
				break
			var off := _bow_at(bow_dir, bow, yy - ground, h) + soff
			# ONLY THE TOP LAYER TAPERS (judge round 4). A clump built as
			# `rk - 1, rk, rk - 1` is at its full width on ONE layer of three,
			# and from the side that reads as a thin plate with a bevel - which
			# is exactly what the vary row was showing. The down-point under
			# every tier is a CONIFER's rule; a birch clump is a mass of leaves
			# and wants to be full to its underside.
			var ri := rk if j < deep - 1 else maxi(rk - 1, 1)
			# THE CLUMP'S EDGE IS THE WHORL EDGE (judge round 2). A full
			# octagon is a plate whatever its radius; the arms that give a
			# spruce tier its jagged outline cost nothing here and are the
			# difference between a disc of leaves and a clump of them. Every
			# layer of one clump takes the SAME pattern, so a clump is one solid
			# thing and not a stack of loose rings.
			#
			# AND THE ARMS ARE PAID FOR OUT OF A BLOCK OF EXTRA RADIUS WHERE THE
			# TABLE ALLOWS ONE (judge round 4). `_arm_limits` holds the body at
			# `r - 1` and lets the arms own the outermost block - right for a
			# spruce tier, where the radius IS the envelope, and a straight
			# block of width off a birch clump that is only four wide to begin
			# with. Asking for one more leaves the body at `ri` and the arms
			# outside it.
			var ra := mini(ri + 1, table_r)
			_arm_limits(limits, ra, cell, seed, k, BIRCH_ARMS,
				int(roll >> 12) % GOLDEN_N)
			drawn += _whorl_disc(writer, bx + off.x, yy, bz + off.y, ra,
				limits, params, k, ra)
		# THE WAIST: one block of foliage through the gap, on the stem (judge
		# round 4). Clumps with clear air between them are three SLABS on a
		# pole - they read as separate objects, and a crown that reads as
		# separate objects is not a crown. A three-wide column through the gap
		# makes the whole thing one body with wide lobes and narrow waists,
		# and it costs the sky nothing: the lobes are nine blocks across, so
		# there are still three blocks of daylight either side of every waist.
		# It is the larch's spine, doing the same job one species over, and it
		# is never holed - SPARSE_CORE is what `_clump_void` protects.
		if k < n - 1:
			for s2 in GOLDEN_N:
				limits[s2] = SPARSE_CORE
			for wy in range(floors[k] + deep, mini(floors[k + 1], top + 1)):
				var woff := _bow_at(bow_dir, bow, wy - ground, h) + stem_off
				drawn += _whorl_disc(writer, bx + woff.x, wy, bz + woff.y,
					SPARSE_CORE, limits, params, k, SPARSE_CORE)
	return drawn


## The bow: how far a stem stands off its root, `i` blocks up a tree `n` tall.
##
## SINGLE-PEAKED, AND NOWHERE ALTERNATING. `4t(1-t)` is one at the middle and
## zero at both ends, so the stem leaves the root plumb, leans out over the
## middle of its height and comes back under its own crown. The conifers'
## `_drift_at` is the other half of the same idea - monotone, a tree that grew
## towards the light - and between them they are the whole of "asymmetry needs a
## cause". Per-layer alternating offsets, which neither of them does, read as
## damage.
static func _bow_at(dir: Vector2i, bow: int, i: int, n: int) -> Vector2i:
	if bow <= 0 or n <= 1:
		return Vector2i.ZERO
	var t := float(clampi(i, 0, n - 1)) / float(n - 1)
	return _golden_offset(dir, int(round(float(bow) * 4.0 * t * (1.0 - t))))


## One stem of a birch: a column following the bow, which - if it is the second
## stem - also steps sideways one block a layer until it stands `dist` off the
## root.
##
## THE BRIDGE BLOCKS ARE THE SAME FIX THE LEADERS TAKE, AND THE SWEEP IS WHY
## THEY ARE ON EVERY STEP. The first version bridged only a DIAGONAL step, on
## the reasoning that an axis step still touches - and it does not: a one-wide
## column at (0, y) and (-1, y + 1) shares an edge and no face. The Stage 2
## sweep counted 9,813 loose blocks over 1,673 birches, nearly all of them
## whole bowed stems adrift above their own foot. Any change of offset now
## bridges. A two-wide stem overlaps itself across a step and needs none of it.
static func _draw_bowed_stem(writer, bx: int, ground: int, bz: int,
		y0: int, y1: int, dir: Vector2i, bow: int, n: int,
		side_dir: Vector2i, dist: int, params: Dictionary) -> int:
	var id: int = params["trunk_id"]
	var w: int = maxi(int(params.get("trunk_width", 1)), 1)
	var drawn := 0
	var prev := Vector2i.ZERO
	for y in range(y0, y1 + 1):
		var off := _bow_at(dir, bow, y - ground, n) \
			+ _golden_offset(side_dir, mini(y - y0 + 1, maxi(dist, 0)))
		if w < 2 and off != prev:
			writer.set_block(bx + prev.x, y, bz + prev.y, id, false)
			writer.set_block(bx + off.x, y, bz + prev.y, id, false)
			drawn += 2
		for dz in w:
			for dx in w:
				writer.set_block(bx + off.x + dx, y, bz + off.y + dz, id, false)
				drawn += 1
		prev = off
	return drawn


# --- The snag (trees v1 Stage 3) ---------------------------------------------
#
# trees research 2: "dead trees are the one archetype where lopsidedness is the
# subject - 3-7 straight segments, blunt broken ends, half with snapped tops,
# and taller than their neighbours". A snag's job is to puncture the canopy
# line, and it did that already: Stage 0 measured it at SYMMETRY 0.21, TWINS
# 0.37, the best numbers in the file by a wide margin. THIS STAGE IS ABOUT
# VARIETY, NOT METRICS - three snags in a wood should be three different
# accidents, and until tonight they were one accident with the stubs moved.

## The three snags, as shares of the population. Broken-jagged is the majority;
## what is left over after the lean is the low stump.
const SNAG_BROKEN := 0.60
const SNAG_LEAN := 0.25

## The leaning snag's total drift, in blocks - monotone up the stem, which is
## `_drift_at`'s curve and the "asymmetry needs a cause" rule it exists for.
const SNAG_DRIFT := 2

## The broken top: how far the stem's short side finishes below its splinter.
## ONE OR TWO BLOCKS, NEVER A FLAT CUT. A one-wide dead trunk that simply stops
## reads as a fence post; a splinter beside the break reads as a tree that came
## down in a storm, and it costs two blocks.
const SNAG_BREAK_MIN := 1
const SNAG_BREAK_MAX := 2

## The low stump: how tall, and how far the four corners of its 2 x 2 top may
## differ. THE STUMP IS 2 x 2 WHATEVER THE TABLE ROLLED - it is the bottom of a
## tree that broke off, so it carries the diameter of a tree, not of a stick.
const SNAG_STUMP_MIN := 2
const SNAG_STUMP_MAX := 4

## The stubs: how many, and how long a run each one makes.
##
## ANGLES CONSISTENT WITHIN ONE TREE. Every stub comes out of the same
## neighbourhood of the thirteen directions - one step either side of the
## tree's own - so a snag is lopsided rather than spiky, which is what the
## poster tradition asks of the one archetype it lets look damaged. Stubs in
## thirteen directions read as a bottle brush.
const SNAG_STUB_MIN := 1
const SNAG_STUB_MAX := 3
const SNAG_STUB_LEN_MIN := 2
const SNAG_STUB_LEN_MAX := 4

## Where up the stem the stubs land. Upper half only: a stub at ankle height
## reads as a mistake.
const SNAG_STUB_LO := 0.45


## SNAG. A dead trunk in one of three shapes - broken-jagged, leaning, or a low
## stump - with one to three sloping stubs off one side of it.
##
## Cheap in blocks and worth more than it costs. A forest of nothing but
## healthy trees reads as planted; a scatter of grey trunks says the place has
## been there a while and nobody is looking after it - which is the whole
## register of "tense out, cozy in the light". It gets commoner with wildness
## for exactly that reason, and measurably so: on seed 42 snags are about a
## fifteenth of the world's trees near spawn and a fifth at the far corner.
static func _draw_bare(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = maxi(int(params["height"]), 2)
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var id: int = params["trunk_id"]
	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_STUBS)
	var roll2 := WorldHash.hash2(cell.x, cell.y, seed, SALT_SNAG)

	# WHICH OF THE THREE, from one byte. The order matters only in that the
	# stump is what is left over, so widening either of the first two never
	# leaves a share unspoken for.
	var pick := int(roll2 & 0xFF)
	if pick >= int((SNAG_BROKEN + SNAG_LEAN) * 256.0):
		return _draw_snag_stump(writer, bx, ground, bz, roll2, params)

	var leaning := pick >= int(SNAG_BROKEN * 256.0)
	var drift_dir: Vector2i = GOLDEN_DIRS[int((roll2 >> 8) % GOLDEN_N)]
	var drift := SNAG_DRIFT if leaning else 0
	var top := ground + h
	var brk := 0
	if not leaning:
		brk = SNAG_BREAK_MIN \
			+ int((roll2 >> 13) % (SNAG_BREAK_MAX - SNAG_BREAK_MIN + 1))

	# The stem stops `brk` blocks short and the splinter carries the last of
	# the height, so a broken snag is never taller than the table said.
	var drawn := _draw_snag_stem(writer, bx, ground, bz, top - brk,
		drift_dir, drift, h, params)
	if brk > 0:
		# THE SPLINTER OVERLAPS THE BREAK. It runs from one block below the
		# stem's top to the tree's own top, so every one of its blocks has a
		# face against the stem beside it for the first two layers - a spike
		# that started at the break would touch the stem at one corner and
		# nothing else.
		var step: Vector2i = NUB_DIRS[int((roll2 >> 16) % NUB_DIRS.size())]
		var w: int = maxi(int(params.get("trunk_width", 1)), 1)
		var sx := (w if step.x > 0 else step.x)
		var sz := (w if step.y > 0 else step.y)
		for y in range(top - brk - 1, top + 1):
			var soff := _drift_at(drift_dir, drift, y - ground - 1, h)
			writer.set_block(bx + soff.x + sx, y, bz + soff.y + sz, id, false)
			drawn += 1

	drawn += _draw_snag_stubs(writer, bx, ground, bz, h, top - brk,
		drift_dir, drift, roll, params)
	return drawn


## The low stump: two to four blocks of 2 x 2 trunk with a splintered top.
##
## The four corners finish at their own heights, so the top is a broken plane
## rather than a sawn one. Every column starts at the ground, so nothing here
## can float however the hash falls.
static func _draw_snag_stump(writer, bx: int, ground: int, bz: int,
		roll: int, params: Dictionary) -> int:
	var id: int = params["trunk_id"]
	var hh := SNAG_STUMP_MIN \
		+ int((roll >> 8) % (SNAG_STUMP_MAX - SNAG_STUMP_MIN + 1))
	var drawn := 0
	for dz in 2:
		for dx in 2:
			var k := dz * 2 + dx
			var top := maxi(hh + int((roll >> (12 + k * 2)) % 3) - 1, 1)
			for y in range(ground + 1, ground + top + 1):
				writer.set_block(bx + dx, y, bz + dz, id, false)
				drawn += 1
	return drawn


## One snag stem: a column following `_drift_at`'s monotone lean, bridged on
## every step.
##
## THE BRIDGE IS THE SAME FIX THE BOWED STEMS TOOK IN STAGE 2. A one-wide
## column at (0, y) and (-1, y + 1) shares an edge and no face, so any change
## of offset - diagonal or not - strands everything above it. A two-wide stem
## overlaps itself across a step and needs none of this.
static func _draw_snag_stem(writer, bx: int, ground: int, bz: int, top_y: int,
		dir: Vector2i, drift: int, n: int, params: Dictionary) -> int:
	var id: int = params["trunk_id"]
	var w: int = maxi(int(params.get("trunk_width", 1)), 1)
	var drawn := 0
	var prev := Vector2i.ZERO
	for y in range(ground + 1, top_y + 1):
		var off := _drift_at(dir, drift, y - ground - 1, n)
		if w < 2 and off != prev:
			writer.set_block(bx + prev.x, y, bz + prev.y, id, false)
			writer.set_block(bx + off.x, y, bz + prev.y, id, false)
			drawn += 2
		for dz in w:
			for dx in w:
				writer.set_block(bx + off.x + dx, y, bz + off.y + dz, id, false)
				drawn += 1
		prev = off
	return drawn


## The one to three stubs, all out of one neighbourhood of the thirteen
## directions and each rising one block over its run.
static func _draw_snag_stubs(writer, bx: int, ground: int, bz: int, h: int,
		top_y: int, drift_dir: Vector2i, drift: int, roll: int,
		params: Dictionary) -> int:
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var id: int = params["trunk_id"]
	var w: int = maxi(int(params.get("trunk_width", 1)), 1)
	var n := SNAG_STUB_MIN + int(roll % (SNAG_STUB_MAX - SNAG_STUB_MIN + 1))
	var d0 := int((roll >> 3) % GOLDEN_N)
	var drawn := 0
	for i in n:
		var sr := _hash_keyed(cell, seed, SALT_SNAG, 8 + i)
		var y := ground + int(round(lerpf(float(h) * SNAG_STUB_LO,
			float(h) - 1.0, float(sr & 0x1F) / 31.0)))
		y = mini(y, top_y)
		var dir: Vector2i = GOLDEN_DIRS[
			(d0 + GOLDEN_N + int((sr >> 6) % 3) - 1) % GOLDEN_N]
		var length := SNAG_STUB_LEN_MIN + int((sr >> 8)
			% (SNAG_STUB_LEN_MAX - SNAG_STUB_LEN_MIN + 1))
		var soff := _drift_at(drift_dir, drift, y - ground - 1, h)
		drawn += _draw_branch(writer, bx + soff.x, y, bz + soff.y,
			_branch_foot(dir, w), dir, length, 1, id)
	return drawn


## Where a branch's first block goes, given the width of the trunk it leaves.
##
## ONE AXIS, NOT TWO (Stage 1, judge round 3). A foot taken down a diagonal
## golden direction lands off the CORNER of the trunk, touching it at an edge
## and at no face, which is a block floating in the air by every rule this file
## has. Snapped to the dominant axis it is always against a trunk face, and the
## branch's own steps take the angle back from there.
static func _branch_foot(dir: Vector2i, w: int) -> Vector2i:
	if absi(dir.x) >= absi(dir.y):
		return Vector2i(w if dir.x > 0 else -1, 0)
	return Vector2i(0, w if dir.y > 0 else -1)


## One branch: a one-wide line stepping out along a golden direction and RISING
## `rise` blocks over its run.
##
## A BRANCH SLOPES, AND THAT IS THE WHOLE DETAIL. A horizontal one-block spur -
## which is what a snag stub was until tonight - reads as a peg; two to four
## blocks with a lift in them read as a branch, and on a hero the same helper
## draws the limbs the crown hangs off.
##
## EVERY STEP IS BRIDGED, sideways and upwards. `_golden_offset` moves
## diagonally on nine of the thirteen directions, and two cells meeting at a
## corner meet at no face - Stage 1's dead stubs, Stage 1's leader nubs and
## Stage 2's bowed stems are one lesson learned three times. The bridge is one
## extra cell per diagonal step and one more per rise.
static func _draw_branch(writer, bx: int, y0: int, bz: int, foot: Vector2i,
		dir: Vector2i, length: int, rise: int, id: int) -> int:
	var drawn := 0
	var prev := foot
	var y := y0
	writer.set_block(bx + foot.x, y, bz + foot.y, id, false)
	drawn += 1
	var lifts := maxi(rise, 0)
	for d in range(1, length):
		var off := foot + _golden_offset(dir, d)
		# At most one lift per step, because `lifts` never exceeds the run.
		var ny := y0 + (lifts * d) / maxi(length - 1, 1)
		# THE WHOLE RISER IS DRAWN, not just its top block (judge round 3). A
		# hero's limb climbs further than it runs - the envelope is narrow and
		# the crown is tall - so a step can be several blocks of lift, and a
		# lift that only placed its last block would leave the branch in
		# pieces.
		while ny > y:
			y += 1
			writer.set_block(bx + prev.x, y, bz + prev.y, id, false)
			drawn += 1
		if off.x != prev.x and off.y != prev.y:
			writer.set_block(bx + off.x, y, bz + prev.y, id, false)
			drawn += 1
		writer.set_block(bx + off.x, y, bz + off.y, id, false)
		drawn += 1
		prev = off
	return drawn


## Where `_draw_branch` finishes, without drawing it.
##
## The hero hangs a lobe on every limb tip and has to know where the tips are
## before it lays the crown out. Same arithmetic, same inputs, no writer.
static func _branch_tip(foot: Vector2i, dir: Vector2i, length: int,
		rise: int) -> Vector3i:
	var off := foot + _golden_offset(dir, maxi(length - 1, 0))
	return Vector3i(off.x, maxi(rise, 0), off.y)


# --- The hero (trees v1 Stage 3) ---------------------------------------------
#
# trees research 2, and it is the flattest statement in that document: "A HERO
# TREE MUST NOT BE A SCALED PARENT. Bigness reads through changed proportions:
# a massive trunk, 2-4 limbs readable against the sky before any foliage, a
# crown broken into 3-5 lobes with real sky between them, a flattened top, one
# dead element, a root flare - and placement in a clearing, ringed by ordinary
# trees." Placement is `tree_placement.gd`'s and read-only tonight; the other
# six are this section.
#
# EVERYTHING FITS INSIDE THE ENVELOPE THE TABLE ALREADY DECLARED. The hero is
# the species that sets `max_reach()` at 28 and `max_height()` at 129 - the
# margin every column in the world widens its candidate scan by, and half of
# worldgen's cost. It may get cheaper, and it does; it may not get bigger.

## Where a broadleaf hero's crown starts, as a fraction of total height, hashed.
## Four tenths of the tree in bare trunk is the sky gap and the read: a hero is
## a trunk you could not put your arms around, with the weather up above it.
const HERO_BASE := 0.36
const HERO_BASE_JITTER := 0.06

## THE ROOT FLARE: how many of the four axes the collar grows to. One block
## wider than the trunk, one or two blocks tall per direction so the collar is
## ragged rather than a plinth. It reads under 25 m, which is where players
## live (trees research 3, lever 13), and it costs about twenty blocks.
const HERO_FLARE_MIN := 2
const HERO_FLARE_MAX := 4

## Lobes, and the limbs that carry them.
##
## ONE LOBE PER CARRIER, AND THE CARRIER IS DRAWN FIRST. The crown is not a
## union of overlapping blobs the way a beech's is - it is three to five
## SEPARATE masses with sky between them, each one blobbed around the endpoint
## of the limb that holds it up (Minecraft's fancy oak does exactly this, and
## it is why an old oak reads as an oak). Lobe zero rides the fork; the rest
## ride one-wide limbs. Nothing here needs the beech's flood: a lobe is convex
## and contains its own carrier's last block, so it cannot strand anything and
## it cannot come adrift.
const HERO_LOBE_MIN := 3
const HERO_LOBE_MAX := 5
const HERO_LIMB_MAX := 4

## Each lobe's plan radius as a fraction of the crown's half-width, biggest
## first - the big/medium/small hierarchy, held well under a half so that two
## lobes at one height still have daylight between them.
## THE LOBES CARRY THE CROWN OR THERE IS NO CROWN (judge round 2). At 0.44 and
## under, three lobes on a fifty-eight-block hero photographed as dinner plates
## on a telegraph pole: the crown was a seventh of the tree's own bounding box
## and the trunk was the whole read. The hero's envelope is TALL AND NARROW -
## the table gives it 84 blocks of height against 32 of width - so the sky
## between the lobes has to come from their spread up the crown rather than
## across it, and every lobe has to reach the envelope sideways or the tree has
## no shoulders at all.
const HERO_LOBE_A := [0.52, 0.52, 0.48, 0.46, 0.44]

## And how FLAT a lobe is: its vertical semi-axis over its plan radius. Under
## one, because an old crown spreads sideways - and because the flattened top
## is the proportion that says "old" at ninety metres, where nothing else does.
const HERO_LOBE_FLAT := 0.85

## Where up the crown a limb leaves the trunk, as a fraction of the crown's own
## height. Clamped to the fork below it: a limb whose foot was above the fork
## would leave a trunk that is no longer there.
const HERO_LIMB_LO := 0.00
const HERO_LIMB_HI := 0.55

## How far a limb CLIMBS, as a fraction of the crown's height.
##
## MORE THAN IT RUNS, AND THAT IS NOT A COMPROMISE (judge round 3). A limb foot
## may only sit between the crown base and the fork - above the fork there is no
## trunk left to leave from - so with the rise tied to the run every lobe but
## the fork's sat in the bottom third of the crown and got its underside sliced
## off flat by the crown base. Every one of them photographed as a dinner plate.
## An old broadleaf's limbs do sweep up steeply; this is that, and it is what
## spreads the lobes over the whole crown.
const HERO_LIMB_RISE_LO := 0.15
const HERO_LIMB_RISE_HI := 0.50

## Where the crown's UNDERSIDE may hang to, as a fraction of total height.
##
## Below the crown base, and deliberately: the sky gap under a hero is made by
## where the lowest lobe's own underside falls away, not by a horizontal cut
## through it. A lobe clipped square across the bottom is a plate.
const HERO_UNDER := 0.32

## The fork: where, and how far apart the two leaders finish. MANDATORY, unlike
## the beech's two in five - a tree this old has lost its single leader.
const HERO_FORK_LO := 0.55
const HERO_FORK_HI := 0.75
const HERO_FORK_MIN := 2
const HERO_FORK_MAX := 3

## THE ONE DEAD ELEMENT, and exactly one. Either a bare spike out of the top of
## the crown - which on the conifer is the lost leader, the thing that most
## says "old spruce" - or one whole limb carrying no foliage. More than one and
## the tree reads as dying rather than as old.
const HERO_SPIKE_CHANCE := 0.55
const HERO_SPIKE_MIN := 3
const HERO_SPIKE_MAX := 6

## The bare limb, when that is the dead element: how far it runs.
const HERO_DEAD_LIMB_MIN := 4
const HERO_DEAD_LIMB_MAX := 6

## The conifer hero: where the crown starts, and the shelf ratio.
##
## LARCH-ADJACENT, NOT SPRUCE-ADJACENT. An ordinary spruce is a notched spire
## one sixth of its height wide with the whorls touching; a four-hundred-year
## spruce is a stack of heavy separated platforms on a bare column, and the
## column is most of what you see. So the ziggurat, at the larch's fifth rather
## than the spruce's sixth, with gaps three layers deep instead of one.
const HERO_CONIFER_BASE := 0.26
const HERO_SHELF_RATIO := 5.5
const HERO_SHELF_MIN := 5
const HERO_SHELF_MAX := 6
const HERO_SHELF_DEEP_MIN := 3
const HERO_SHELF_DEEP_MAX := 4
const HERO_SHELF_GAP := 3
const HERO_SHELF_GAP_MAX := 5
const HERO_SHELF_TOP := 3

## Arms per whorl on a conifer hero - the top of the spruce's own range, since
## this is the widest whorl in the world and a four-armed one that wide is a
## star rather than a tier.
const HERO_ARMS := 6


## THE HERO. Not a scaled parent: a re-proportioned tree that keeps its
## parent's leaf and trunk ids and its broad archetype and nothing else.
static func _draw_hero(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	if int(params.get("draw", BEECH)) == SPRUCE:
		return _draw_hero_conifer(writer, bx, ground, bz, params)
	return _draw_hero_broadleaf(writer, bx, ground, bz, params)


## THE BROADLEAF HERO. A massive flared trunk to a mandatory fork, two leaders
## carrying the top lobe, two to four one-wide limbs carrying the rest, real sky
## between all of them, a flat top, and one dead element.
##
## WHAT THIS REPLACES is the most expensive tree in the world and the least
## interesting: a beech's crown at twice the size on a very long stick - 28,255
## blocks before the epic, 13,720 after Stage 2 halved it, and a ball either
## way. `build/gallery/memo-baseline/species-hero.png` is the picture.
static func _draw_hero_broadleaf(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = maxi(int(params["height"]), 8)
	var rw: int = maxi(int(params["crown"]), 2)
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var w: int = maxi(int(params.get("trunk_width", 3)), 1)
	var tid: int = params["trunk_id"]
	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_HERO)
	var roll2 := _hash_keyed(cell, seed, SALT_HERO, 2)
	var top := ground + h

	var base_frac := HERO_BASE \
		+ HERO_BASE_JITTER * (float(roll & 0xFF) / 127.5 - 1.0)
	var crown_base := ground + maxi(2, int(round(float(h) * base_frac)))
	# The dead element, decided first because the spike is what the crown's
	# ceiling is measured down from - it REPLACES crown, it never adds height.
	var spike := (roll2 & 0xFF) < int(HERO_SPIKE_CHANCE * 256.0)
	var spike_len := 0
	if spike:
		spike_len = HERO_SPIKE_MIN + int((roll2 >> 8)
			% (HERO_SPIKE_MAX - HERO_SPIKE_MIN + 1))
	var crown_top := maxi(top - spike_len, crown_base + 3)
	var crown_h := maxi(crown_top - crown_base + 1, 4)

	var n_lobes := HERO_LOBE_MIN \
		+ int((roll >> 8) % (HERO_LOBE_MAX - HERO_LOBE_MIN + 1))
	# One limb per lobe that is not the fork's, plus the bare one when the dead
	# element is a limb rather than a spike.
	var n_limbs := clampi(n_lobes - 1 + (0 if spike else 1), 1, HERO_LIMB_MAX)
	var d0 := int((roll >> 12) % GOLDEN_N)

	var fork_y := clampi(ground + int(round(float(h)
		* lerpf(HERO_FORK_LO, HERO_FORK_HI,
			float((roll >> 16) & 0xFF) / 255.0))),
		crown_base + 1, maxi(crown_top - 3, crown_base + 1))

	var drawn := _draw_trunk(writer, bx, ground, bz, fork_y, params)
	drawn += _draw_root_flare(writer, bx, ground, bz, w, roll, tid)

	# Lobe zero rides the fork, and its top is CUT by the crown's ceiling -
	# which is the flattened top, and the cheapest possible way to say "no dome
	# apex" on a shape built out of ellipsoids.
	var lr0 := maxi(int(round(float(rw) * float(HERO_LOBE_A[0]))), 2)
	var vr0 := maxi(int(round(float(lr0) * HERO_LOBE_FLAT)), 2)
	var cy0 := clampi(crown_top - maxi(vr0 / 2, 1), fork_y + 2, crown_top)
	var lw := maxi(w - 1, 2)
	var fork_d := HERO_FORK_MIN \
		+ int((roll >> 24) % (HERO_FORK_MAX - HERO_FORK_MIN + 1))
	for i in 2:
		# Opposite sides: six of thirteen is 166 degrees.
		var ldir: Vector2i = GOLDEN_DIRS[(d0 + i * 6) % GOLDEN_N]
		drawn += _draw_leader(writer, bx, bz, fork_y + 1,
			maxi(cy0 - i, fork_y + 1), ldir, fork_d, lw, tid)

	if spike:
		# Straight on up out of the first leader, in dead wood. It is inside
		# the foliage for its lower half and clear of it above, which is the
		# whole of what "one dead element" has to look like.
		var soff := _golden_offset(GOLDEN_DIRS[d0], fork_d)
		for y in range(cy0 + 1, top + 1):
			writer.set_block(bx + soff.x, y, bz + soff.y, Block.TRUNK_DEAD,
				false)
			drawn += 1

	# The limbs, and the lobes they carry. Drawn in trunk id BEFORE any
	# foliage, so a limb is readable against the sky where the crown has none
	# and the leaves - which go over air only - can never paint over it.
	var centres: Array[Vector3i] = []
	var radii: Array[int] = []
	for i in n_limbs:
		var lrl := _hash_keyed(cell, seed, SALT_HERO_LOBE, i)
		var dir: Vector2i = GOLDEN_DIRS[(d0 + 2 + i * GOLDEN_STEP) % GOLDEN_N]
		# THE LOBE IS HELD SO THE LIMB STILL HAS A BLOCK TO RUN ALONG, which is
		# also what makes the envelope arithmetic below exact rather than
		# nearly right.
		var lrad := clampi(int(round(float(rw)
			* float(HERO_LOBE_A[mini(i + 1, HERO_LOBE_A.size() - 1)]))),
			2, maxi(rw - w - 1, 2))
		var bare := (not spike) and i == n_limbs - 1
		var foot := _branch_foot(dir, w)
		# THE LIMB IS EXACTLY AS LONG AS THE ENVELOPE HAS LEFT. `_golden_offset`
		# never returns a component longer than the distance asked of it, so a
		# tip at `rw - lrad` puts the lobe's outermost block at `rw` - the crown
		# radius the table declared, and not one block past it.
		var length := maxi(rw - lrad - w + 1, 1)
		if bare:
			length = clampi(HERO_DEAD_LIMB_MIN + int((lrl >> 16) % (
				HERO_DEAD_LIMB_MAX - HERO_DEAD_LIMB_MIN + 1)), 2, rw - w + 1)
		var fy := clampi(crown_base + int(round(float(crown_h - 1)
			* lerpf(HERO_LIMB_LO, HERO_LIMB_HI,
				float(lrl & 0xFF) / 255.0))), crown_base, fork_y)
		var rise := clampi(int(round(float(crown_h) * lerpf(
			HERO_LIMB_RISE_LO, HERO_LIMB_RISE_HI,
			float((lrl >> 8) & 0xFF) / 255.0))), 1, maxi(crown_top - fy - 2, 1))
		drawn += _draw_branch(writer, bx, fy, bz, foot, dir, length, rise,
			Block.TRUNK_DEAD if bare else tid)
		if bare:
			continue
		var tip := _branch_tip(foot, dir, length, rise)
		centres.append(Vector3i(tip.x, fy + tip.y, tip.z))
		radii.append(lrad)

	var under := ground + int(round(float(h) * HERO_UNDER))
	drawn += _draw_hero_lobe(writer, bx, bz, Vector3i(0, cy0, 0), lr0, vr0,
		under, crown_top, params)
	for i in centres.size():
		var lrad: int = radii[i]
		drawn += _draw_hero_lobe(writer, bx, bz, centres[i], lrad,
			maxi(int(round(float(lrad) * HERO_LOBE_FLAT)), 2),
			under, crown_top, params)
	return drawn


## THE CONIFER HERO. The ziggurat again, at hero scale: five or six heavy
## whorls three or four layers deep with three to five layers of air between
## them, hung off a trunk that runs the whole height and is meant to be SEEN
## through the gaps, a blunt cap where an ordinary spruce has a leader, a root
## flare, and one dead element.
static func _draw_hero_conifer(writer, bx: int, ground: int, bz: int,
		params: Dictionary) -> int:
	var h: int = maxi(int(params["height"]), 8)
	var table_r: int = maxi(int(params["crown"]), 2)
	var cell: Vector2i = params["cell"]
	var seed: int = params["seed"]
	var w: int = maxi(int(params.get("trunk_width", 3)), 1)
	var tid: int = params["trunk_id"]
	var roll := WorldHash.hash2(cell.x, cell.y, seed, SALT_HERO)
	var roll2 := _hash_keyed(cell, seed, SALT_HERO, 2)
	var top := ground + h

	var spike := (roll2 & 0xFF) < int(HERO_SPIKE_CHANCE * 256.0)
	var spike_len := 0
	if spike:
		spike_len = HERO_SPIKE_MIN + int((roll2 >> 8)
			% (HERO_SPIKE_MAX - HERO_SPIKE_MIN + 1))
	var crown_top := top - spike_len
	var crown_base := ground + maxi(2,
		int(round(float(h) * HERO_CONIFER_BASE)))
	var span := maxi(crown_top - crown_base + 1, HERO_SHELF_DEEP_MIN)

	# The same layout the larch's ziggurat takes, with the sky slots reserved
	# before anything is spent on shelf depth - see SHELF_MIN_LAYERS.
	var n := clampi(span / (HERO_SHELF_DEEP_MIN + HERO_SHELF_GAP),
		HERO_SHELF_MIN, HERO_SHELF_MAX)
	while n > 1 and n * HERO_SHELF_DEEP_MIN + (n - 1) * HERO_SHELF_GAP > span:
		n -= 1
	var thick := HERO_SHELF_DEEP_MAX
	while thick > HERO_SHELF_DEEP_MIN \
			and n * thick + (n - 1) * HERO_SHELF_GAP > span:
		thick -= 1

	var gaps: Array[int] = []
	var stack := n * thick
	var remain := span - stack
	for k in maxi(n - 1, 0):
		var left := n - 1 - k
		var g := clampi(remain / maxi(left, 1), HERO_SHELF_GAP,
			HERO_SHELF_GAP_MAX)
		if g < HERO_SHELF_GAP_MAX and remain - g * left > 0 \
				and ((roll2 >> (12 + k)) & 1) == 1:
			g += 1
		g = clampi(g, HERO_SHELF_GAP,
			maxi(remain - (left - 1) * HERO_SHELF_GAP, HERO_SHELF_GAP))
		gaps.append(g)
		stack += g
		remain -= g

	# Downwards from the cap. Whatever the shelves did not spend stays as bare
	# trunk under them, which on a hero is not waste - it is the read.
	var start := maxi(crown_top - stack + 1, crown_base)
	# THE TRUNK RUNS TO THE CAP, and that is what holds a ziggurat with
	# three-layer gaps together. An ordinary larch threads a one-wide leaf
	# spine through its gaps; a hero has a four-voxel column there already,
	# and it is the single most hero-like thing in the silhouette.
	var drawn := _draw_trunk(writer, bx, ground, bz, crown_top - 1, params)
	drawn += _draw_root_flare(writer, bx, ground, bz, w, roll, tid)
	if spike:
		for y in range(crown_top, top + 1):
			writer.set_block(bx, y, bz, Block.TRUNK_DEAD, false)
			drawn += 1
	else:
		var ddir: Vector2i = GOLDEN_DIRS[int((roll >> 12) % GOLDEN_N)]
		var dlen := HERO_DEAD_LIMB_MIN + int((roll2 >> 20)
			% (HERO_DEAD_LIMB_MAX - HERO_DEAD_LIMB_MIN + 1))
		drawn += _draw_branch(writer, bx,
			start + (crown_top - start) / 3, bz, _branch_foot(ddir, w),
			ddir, dlen, 1, Block.TRUNK_DEAD)

	var r_base := clampi(int(round(float(h) / HERO_SHELF_RATIO)), 1, table_r)
	var r_top := mini(HERO_SHELF_TOP, r_base)
	var arm_phase := int((roll >> 20) % GOLDEN_N)
	var limits: Array[int] = []
	limits.resize(GOLDEN_N)
	var y := start
	for k in n:
		var rk := int(ceil(lerpf(float(r_base), float(r_top),
			float(k) / float(maxi(n - 1, 1)))))
		for j in thick:
			# Only the topmost layer of a shelf sits at its full radius, so the
			# crown underside is a row of DOWN-POINTS and never a horizontal
			# cut (trees research 2).
			var ri := rk if j == thick - 1 else maxi(rk - 1, 1)
			_arm_limits(limits, ri, cell, seed, k, HERO_ARMS, arm_phase)
			drawn += _whorl_disc(writer, bx, y, bz, ri, limits, params, k, ri)
			y += 1
		if k < n - 1:
			y += gaps[k]
	return drawn


## The root flare: a collar one block wider than the trunk, on two to four of
## the four axes, one or two blocks tall each.
##
## ON AXES AND NOT ON THE THIRTEEN DIRECTIONS, for the reason every one-block
## detail in this file is: a collar block off the CORNER of a trunk touches it
## at an edge and at no face.
static func _draw_root_flare(writer, bx: int, ground: int, bz: int, w: int,
		roll: int, id: int) -> int:
	var n := HERO_FLARE_MIN \
		+ int((roll >> 3) % (HERO_FLARE_MAX - HERO_FLARE_MIN + 1))
	var d0 := int((roll >> 6) & 3)
	var drawn := 0
	for j in n:
		var step: Vector2i = NUB_DIRS[(d0 + j) % NUB_DIRS.size()]
		var lay := 1 + int((roll >> (8 + j)) & 1)
		for y in range(ground + 1, ground + lay + 1):
			for k in w:
				var fx := k
				var fz := k
				if step.x != 0:
					fx = w if step.x > 0 else -1
				else:
					fz = w if step.y > 0 else -1
				writer.set_block(bx + fx, y, bz + fz, id, false)
				drawn += 1
	return drawn


## One lobe of a hero's crown: a FLATTENED ellipsoid centred on the block its
## carrier ends at, cut off at the crown's ceiling.
##
## Convex, nested layer over layer, and it always contains the limb tip or the
## leader top it was centred on - so it is connected to the tree and internally
## connected, without any of the beech's flood machinery. The cut at `y_hi` is
## the flat top; the cut at `y_lo` is the sky gap under the crown.
static func _draw_hero_lobe(writer, bx: int, bz: int, c: Vector3i, lr: int,
		vr: int, y_lo: int, y_hi: int, params: Dictionary) -> int:
	var id: int = params["leaves"]
	if id == Block.AIR:
		return 0
	var drawn := 0
	for dy in range(-vr, vr + 1):
		var y := c.y + dy
		if y < y_lo or y > y_hi:
			continue
		var f := sqrt(maxf(1.0 - float(dy * dy) / float(maxi(vr * vr, 1)), 0.0))
		var ri := int(round(float(lr) * f))
		for dz in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				if not _in_plan(dx, dz, ri):
					continue
				writer.set_block(bx + c.x + dx, y, bz + c.z + dz, id, true)
				drawn += 1
	return drawn


# --- Shared drawing helpers -------------------------------------------------

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


## Is this offset inside an ELLIPTICAL plan of semi-axes `ra` (along x) and `rb`
## (along z)?
##
## The same chamfer `_in_plan` takes, generalised: the octagon's `ax + az <= r +
## r/2` becomes `ax/ra + az/rb <= 1.5` cleared of its divisions, and the circle
## below three blocks becomes the ellipse. With ra = rb it agrees with
## `_in_plan` cell for cell, which is what lets the beech's lobes and the
## conifers' whorls be the same house plan shape at different aspect ratios.
static func _in_plan_ab(dx: int, dz: int, ra: int, rb: int) -> bool:
	if ra <= 0 or rb <= 0:
		return dx == 0 and dz == 0
	var ax := absi(dx)
	var az := absi(dz)
	if ax > ra or az > rb:
		return false
	if maxi(ra, rb) >= OCTAGON_MIN:
		return ax * rb + az * ra <= ra * rb + (ra * rb) / 2
	return ax * ax * rb * rb + az * az * ra * ra <= ra * ra * rb * rb + ra * rb


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
