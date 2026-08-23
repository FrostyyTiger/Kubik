class_name TerrainGenerator
extends RefCounted

## Turns a seed plus a position into terrain. Deterministically.
##
## This determinism is the whole reason terrain never touches the network: the
## host picks one integer, sends it (with the config, from Stage 11), and both
## machines compute an identical world locally. Only player EDITS get
## transmitted. Break determinism - a randf() in here, a dependence on
## Dictionary iteration order, a value read from something that varies per
## machine - and the two players quietly end up in different worlds with no
## error on either side. Heightmap.hash_key() is the automated guard on that.
##
##
## SHAPE: FOUR LAYERS, COARSE TO FINE
##
## The previous version was a 3D density field, which buys overhangs and costs
## you the ability to ever find a valley. This one is a heightmap, because
## every feature the design actually asks for - readable ridgelines, a treeline
## you can see from below, lakes in real basins - is a question about the
## SURFACE, and a surface is what a heightmap is.
##
##   continent  1200 blk / 600 m   where high ground is at all
##   mountain    300 blk / 150 m   THE feature layer, ridged
##   hills        60 blk /  30 m   slope detail
##   detail       12 blk /   6 m   per-block roughness (voxel time only)
##
## They are summed, never fused into one expression. A single combined noise
## call is shorter and completely untunable, because every knob then moves
## every feature at once. Keeping them apart is what makes the tuning panel
## mean anything.
##
## The wavelengths are chosen against a readability target: mountain footprints
## land at 100-200 m across. Bigger and you cannot see a mountain is a mountain
## from its own slope; smaller and the skyline turns to gravel.
##
##
## WHERE DETAIL LIVES, AND WHY IT MATTERS
##
## The first three layers build the COARSE HEIGHTMAP, once, for the whole world.
## `detail` is added later, per block, when voxels are built - after lake levels
## have been decided.
##
## That ordering is not tidiness. Lakes are found by looking for basins in the
## coarse heightmap. If a 3-block bump could appear before that, a bump on a
## basin rim would silently drain the lake, and a dip would invent one. Detail
## must never be able to change the shape of the world at the scale lakes are
## decided at.

## Distinct seed per noise layer, derived from the world seed. Two layers
## sharing a seed are correlated - their peaks line up - and the sum looks
## subtly wrong in a way that is very hard to spot and very hard to unsee.
const SEED_CONTINENT := 1
const SEED_MOUNTAIN := 2
const SEED_HILLS := 3
const SEED_DETAIL := 4
const SEED_JITTER := 5
const SEED_WARP_X := 6
const SEED_WARP_Z := 7

## Salts keep independent uses of the coordinate hash from agreeing with each
## other. Without them every tree in the world would stand exactly where the
## ground happens to dither.
const SALT_ZONE_DITHER := 101
const SALT_TREE := 202
const SALT_TREE_TRUNK := 203
const SALT_TREE_CANOPY := 204

## Elevation zones, low to high.
const ZONE_MEADOW := 0
const ZONE_FOREST := 1
const ZONE_ROCK := 2
const ZONE_SNOW := 3

const ZONE_NAMES := ["meadow", "forest", "rock", "snow"]

## The block that shows at the surface of each zone.
const ZONE_SURFACE := [
	Block.GRASS,          # meadow
	Block.FOREST_FLOOR,   # forest floor
	Block.STONE,          # bare rock
	Block.SNOW,           # snow
]

var world_seed: int
var config: WorldgenConfig

## Built once by build_heightmap(). Everything downstream - voxels, the far
## mesh, lakes, trees - reads the world's shape from here rather than
## recomputing noise, so they cannot disagree about it.
var heightmap: Heightmap = null

var _continent: FastNoiseLite
var _mountain: FastNoiseLite
var _hills: FastNoiseLite
var _detail: FastNoiseLite
var _jitter: FastNoiseLite
var _warp_x: FastNoiseLite
var _warp_z: FastNoiseLite


func _init(p_seed: int, p_config: WorldgenConfig = null) -> void:
	world_seed = p_seed
	config = p_config if p_config != null else WorldgenConfig.new()

	# 3 octaves on the broad layers, 4 on the mountains, 2 on the fine ones.
	# Octaves are the "how many times do we add a half-size copy of this" knob;
	# past about 4 the extra detail is smaller than a block and you are paying
	# for noise nobody can see.
	_continent = _make_noise(SEED_CONTINENT, config.continent_freq, 3)
	_mountain = _make_noise(SEED_MOUNTAIN, config.mountain_freq, 4)
	_hills = _make_noise(SEED_HILLS, config.hills_freq, 3)
	_detail = _make_noise(SEED_DETAIL, config.detail_freq, 2)
	_jitter = _make_noise(SEED_JITTER, config.zone_jitter_freq, 2)
	# The warp fields are sampled at the mountain wavelength's big brother, so
	# they bend whole ridgelines rather than jiggling individual blocks.
	_warp_x = _make_noise(SEED_WARP_X, config.mountain_freq * 0.5, 2)
	_warp_z = _make_noise(SEED_WARP_Z, config.mountain_freq * 0.5, 2)


func _make_noise(seed_offset: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = world_seed + seed_offset
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	return n


## Build the coarse heightmap for the whole world. Returns milliseconds spent,
## because that number belongs on the debug readout.
## The loop is j (z) outer, i (x) inner so it walks the array front to back.
## It is plain and slow-looking on purpose: this is the file Marcel reads to
## understand how the world is made, and a clever vectorised version would
## teach him nothing to save 300 ms once per session. Measured on the target
## machine it is ~650 ms for 562,500 cells, which is the entire argument for a
## bounded world - an infinite one could never afford a global heightmap, and
## lakes and the far field are worth more than infinity is.
##
## Note that Heightmap does not call back into here. It is a plain data
## structure that knows how to interpolate itself, and the generator fills it -
## the two referring to each other by type is a cycle GDScript cannot resolve.
func build_heightmap() -> int:
	var started := Time.get_ticks_msec()
	heightmap = Heightmap.new(config)
	var cols := heightmap.cols
	for j in cols:
		var bz := float(heightmap.cell_to_block(j))
		var row := j * cols
		for i in cols:
			var bx := float(heightmap.cell_to_block(i))
			heightmap.cells[row + i] = height_at_block(bx, bz)
	return Time.get_ticks_msec() - started


# --- The layered heightmap --------------------------------------------------

## Surface altitude in blocks at a coarse sample point.
##
## Read this function top to bottom and you have the entire shape of the world.
func height_at_block(bx: float, bz: float) -> float:
	# Domain warp first: it bends the coordinate system, so every layer sampled
	# afterwards is bent with it and they stay consistent with each other.
	var warp := _domain_warp(bx, bz)
	var wx := bx + warp.x
	var wz := bz + warp.y

	var h := config.base_altitude

	# Broad trend. Decides which parts of the map are high ground at all.
	var continent := _continent.get_noise_2d(wx, wz)
	h += continent * config.continent_amp

	# ...and then decides where mountains are allowed to grow.
	#
	# This gate is the difference between a landscape and a texture. Summing
	# the layers everywhere gives uniform bumpiness: relief in every direction,
	# no lowlands, and nowhere flat and enclosed enough for a lake to sit. With
	# the gate, the continent layer carves the world into broad low country and
	# mountain country, and the mountain layer only speaks in the second - so
	# a massif reads as a massif, with an outside to see it from.
	var massif := smoothstep(config.mountain_mask_lo, config.mountain_mask_hi, continent)

	# The feature layer. _ridge() is what turns rolling lumps into peaks with
	# valleys between them, and it is the single biggest lever on how the
	# skyline reads.
	h += _ridge(_mountain.get_noise_2d(wx, wz)) * config.mountain_amp * massif

	# Slope detail, so hillsides are not smooth ramps.
	h += _hills.get_noise_2d(wx, wz) * config.hills_amp

	h = _flatten_valleys(h)
	return clampf(h, config.min_altitude, config.max_altitude)


## Per-block roughness, in blocks. Added to the interpolated coarse height when
## voxels are built - never before lakes are decided. See the file header.
func detail_at(bx: float, bz: float) -> float:
	return _detail.get_noise_2d(bx, bz) * config.detail_amp


## Wobble applied to the elevation zone boundaries, in blocks. Without it every
## treeline in the world is the same perfectly flat contour and the place looks
## like a topographic map.
func zone_jitter_at(bx: float, bz: float) -> float:
	return _jitter.get_noise_2d(bx, bz) * config.zone_jitter_blocks


## Final surface altitude at one block column: coarse heightmap plus detail.
## This is the function that decides where the ground is.
func surface_at(bx: float, bz: float) -> float:
	return heightmap.height_at(bx, bz) + detail_at(bx, bz)


## Lowest and highest surface altitude over one chunk column's 16x16 footprint.
##
## Used to decide which chunks of a column are worth building at all. Sampling
## the coarse heightmap's cells rather than all 256 block columns is the whole
## point: a chunk is 16 blocks and a cell is 4, so five samples per axis cover
## the footprint exactly, and the answer costs 25 array reads instead of 256
## interpolations plus 256 noise calls.
##
## detail_amp is added as a margin on both ends because detail is applied per
## block AFTER this, and a range that did not allow for it would clip the tops
## off hills by up to three blocks.
func column_surface_range(chunk_x: int, chunk_z: int) -> Vector2:
	var bx0 := chunk_x * Chunk.SIZE
	var bz0 := chunk_z * Chunk.SIZE
	var lo := INF
	var hi := -INF
	# 0, 4, 8, 12, 16 - inclusive of the far edge, so a chunk's last block is
	# covered by the same sample its neighbour's first block uses.
	for dz in range(0, Chunk.SIZE + 1, heightmap.step):
		for dx in range(0, Chunk.SIZE + 1, heightmap.step):
			var h := heightmap.height_at(float(bx0 + dx), float(bz0 + dz))
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo - config.detail_amp, hi + config.detail_amp)


func is_solid_at(bx: int, by: int, bz: int) -> bool:
	if by < 0:
		return true   # bedrock, so you cannot fall out of the world
	return float(by) <= surface_at(float(bx), float(bz))


# --- Elevation zones --------------------------------------------------------
#
# Altitude decides what a surface block is made of. Two things stop that from
# looking like a contour map:
#
#   JITTER moves each boundary up and down by up to zone_jitter_blocks over a
#   200 m wavelength, so the treeline follows the land instead of cutting
#   across it at one exact altitude.
#
#   DITHER softens each boundary across zone_blend_blocks. Inside that band a
#   block belongs to the higher zone with a probability that rises from 0 to 1,
#   decided by hashing its position - so the two zones interleave, and at 0.5 m
#   per block the eye reads the mixture as a gradient rather than as speckle.
#   Blending the vertex COLOURS instead would be smoother still, but colour
#   here comes from the block id and a block is one byte; keeping it that way
#   is what lets an edit travel over the network as a single number.

## Zone index for an altitude, given this column's jitter and dither values.
func zone_at(altitude: float, jitter: float, dither: float) -> int:
	var thresholds: Array[float] = [
		config.meadow_max + jitter,
		config.forest_max + jitter,
		config.rock_max + jitter,
	]
	var blend := maxf(config.zone_blend_blocks, 0.001)
	var zone := ZONE_MEADOW
	for i in 3:
		# 0 at the bottom of the blend band, 1 at the top.
		var edge := (altitude - thresholds[i]) / blend + 0.5
		if edge <= 0.0:
			break
		if edge >= 1.0 or dither < edge:
			zone = i + 1
		else:
			break
	return zone


## Zone of the surface at one block column.
func surface_zone_at(bx: int, bz: int, altitude: float) -> int:
	return zone_at(
		altitude,
		zone_jitter_at(float(bx), float(bz)),
		WorldHash.hash01(bx, bz, world_seed, SALT_ZONE_DITHER))


## Zone name at a position, for the debug readout. Takes metres, because that
## is what the thing asking has.
func zone_name_at_m(x_m: float, z_m: float, y_m: float) -> String:
	var bx := int(floor(x_m / config.block_size))
	var bz := int(floor(z_m / config.block_size))
	return ZONE_NAMES[surface_zone_at(bx, bz, y_m / config.block_size)]


# --- TODO(marcel): three exercises ------------------------------------------
#
# Each has a fallback below it that WORKS. The world generates, is walkable and
# is worth looking at without any of them implemented - they change how good it
# looks, not whether it runs. Do them in any order, and reroll (F7) after each.


## 1. RIDGE TRANSFORM. Takes fbm noise in [-1, 1], returns roughly [0, 1].
##
## TODO(marcel): make the mountains ridged instead of round.
##
##   Hint: ridged noise is  1.0 - abs(n).
##   Fold the noise at zero and what used to be the ZERO CROSSINGS - the most
##   common value in the field - become the peaks, so instead of a few round
##   summits you get long connected ridgelines with valleys between them.
##
##   Then square it. Squaring pulls everything below 1.0 downward, and pulls
##   small values down hardest, so peaks stay sharp while valleys widen and
##   flatten out. That is where walkable valley floors come from.
##
##   Try it with and without the square and watch the skyline. The difference
##   is the exercise; the square is not obviously correct and you should see
##   why before you keep it.
##
## The fallback is the raw fbm value rescaled from [-1, 1] to [0, 1], so the
## mountain layer still spans the same altitude range and the world is playable
## in the morning. It is NOT ridged: the skyline comes out as rounded blobs,
## which is exactly the "before" picture this exercise is the "after" of.
func _ridge(n: float) -> float:
	return (n + 1.0) * 0.5


## 2. DOMAIN WARP. Returns an offset in blocks, added to the sample position.
##
## TODO(marcel): stop the terrain looking grid-aligned.
##
##   Noise is generated on a lattice, and however much you sum it, features
##   keep lining up with the axes - long straight ridges running north-south,
##   valleys meeting at suspiciously square corners. Once you have seen it you
##   see it in every procedural landscape that skipped this step.
##
##   The fix is to bend the coordinate system before sampling:
##
##       return Vector2(
##           _warp_x.get_noise_2d(bx, bz) * config.warp_strength,
##           _warp_z.get_noise_2d(bx, bz) * config.warp_strength)
##
##   config.warp_strength starts at 40 blocks (20 m), which is a good deal less
##   than a mountain is wide - the point is to bend ridgelines, not to scramble
##   them. Turn it up to 200 to see what too much looks like; it is worth doing
##   once.
##
## Fallback: no warp, sample at the plain coordinates.
func _domain_warp(_bx: float, _bz: float) -> Vector2:
	return Vector2.ZERO


## 3. VALLEY FLATTENING. Takes an altitude in blocks, returns one.
##
## TODO(marcel): make the valley floors walkable.
##
##   Straight summed noise gives you a world with no flat ground anywhere -
##   every "valley" is a V, and there is nowhere to put a campfire, a fight, or
##   a lake. You want low altitudes compressed toward flat while high ones are
##   left alone.
##
##   Normalise the height into 0..1 across [min_altitude, max_altitude], bend
##   it, and map it back:
##
##       var t := (h - lo) / (hi - lo)
##       t = pow(t, config.valley_curve)          # curve starts at 1.6
##       return lo + t * (hi - lo)
##
##   pow() with an exponent above 1 has a shallow slope near zero and a steep
##   one near one, which is precisely "squash the bottom, keep the top".
##
##   smoothstep(lo, hi, h) is the other obvious answer and it flattens the TOPS
##   too, so peaks turn into plateaus. Both are defensible. They feel different
##   to walk through, and that difference is the exercise - try both before you
##   pick.
##
## Fallback: linear, i.e. leave the height exactly as the layers built it.
func _flatten_valleys(h: float) -> float:
	return h


# --- Voxels -----------------------------------------------------------------

## Fill a chunk with blocks, one column at a time.
##
## Column by column rather than the mesher's linear order because the surface
## altitude is a property of the COLUMN: computing it once and then walking
## down costs one heightmap lookup and one noise sample per column, instead of
## one per voxel. At 16 blocks tall that is a 16x saving on the hot path.
func generate_into(chunk: Chunk) -> void:
	var origin := chunk.origin()
	var has_air := false
	var has_solid := false

	for lz in Chunk.SIZE:
		for lx in Chunk.SIZE:
			var bx := origin.x + lx
			var bz := origin.z + lz
			var surface := surface_at(float(bx), float(bz))
			# floor(), not round(): the block at altitude N occupies the space
			# from N to N+1, so a surface at 40.7 means block 40 is the top
			# solid one.
			var top := int(floor(surface))
			# The zone is a property of the COLUMN's surface, not of each
			# voxel: a block three deep is soil because of what grows above it,
			# not because of its own altitude.
			var zone := surface_zone_at(bx, bz, surface)

			for ly in Chunk.SIZE:
				var by := origin.y + ly
				var id := Block.AIR
				if by <= top:
					id = block_for(top - by, zone)
					has_solid = true
				else:
					has_air = true
				chunk.voxels[Chunk.index(lx, ly, lz)] = id

	chunk.has_air = has_air
	chunk.has_solid = has_solid

	_place_trees(chunk)
	chunk.dirty = true


# --- Trees ------------------------------------------------------------------
#
# THE CHUNK BORDER BUG LIVES HERE, and it is the classic one.
#
# A tree is rooted at one candidate cell but its canopy spreads several blocks
# sideways and ten blocks up, so it reaches into neighbouring chunks. The
# tempting implementation - iterate the cells inside this chunk and draw their
# trees - produces a world where a canopy is drawn by the chunk that owns its
# trunk and by nobody else, so every tree near a boundary is sliced off. Worse,
# whether you see the slice depends on which chunks happen to be loaded.
#
# The fix is to iterate candidate cells over a region WIDER than the chunk
# being built, by the largest distance a tree can reach, and let each chunk
# write only the blocks that land inside itself. Every chunk a tree touches
# then draws its own share of it, and because placement is hashed from the
# cell's coordinates rather than drawn from a stream, all of them compute
# exactly the same tree. A chunk generates identically whether it is built
# first, last, or on the other player's machine.

## How far above the surface a tree can reach, in blocks. World uses this to
## decide how much empty sky above the terrain still has to be built - without
## it, a tree on a column near the top of a chunk would have its canopy
## silently cut off by a chunk that was never queued.
func max_tree_height() -> int:
	return config.tree_trunk_max + config.tree_canopy_max + 3


## Probability that a candidate cell grows a tree, given the surface altitude
## there and that column's zone jitter.
##
## Peaks in the MIDDLE of the forest band and tapers linearly to zero at both
## edges, so the treeline thins out instead of stopping dead along a contour.
func tree_probability_at(surface: float, jitter: float) -> float:
	var lo := config.meadow_max + jitter
	var hi := config.forest_max + jitter
	if surface <= lo or surface >= hi or hi <= lo:
		return 0.0
	var t := (surface - lo) / (hi - lo)
	return config.tree_probability * (1.0 - absf(t - 0.5) * 2.0)


func _place_trees(chunk: Chunk) -> void:
	var origin := chunk.origin()
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		return

	# Widen by the furthest a canopy can spread sideways. This is the whole
	# fix for the border bug - see the note above.
	var margin: int = config.tree_canopy_max

	var cx0 := Chunk.floor_div(origin.x - margin, cell)
	var cx1 := Chunk.floor_div(origin.x + Chunk.SIZE - 1 + margin, cell)
	var cz0 := Chunk.floor_div(origin.z - margin, cell)
	var cz1 := Chunk.floor_div(origin.z + Chunk.SIZE - 1 + margin, cell)

	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			_stamp_tree(chunk, cx, cz)


## Draw one candidate cell's tree into `chunk`, writing only the blocks that
## fall inside it. Called by every chunk the tree reaches, and must produce the
## same tree for all of them.
func _stamp_tree(chunk: Chunk, cell_x: int, cell_z: int) -> void:
	var bx: int = cell_x * config.tree_cell_blocks
	var bz: int = cell_z * config.tree_cell_blocks

	var surface := surface_at(float(bx), float(bz))
	var jitter := zone_jitter_at(float(bx), float(bz))
	var chance := tree_probability_at(surface, jitter)
	if chance <= 0.0:
		return
	# Hashed from the cell's own coordinates, never drawn from a stream - so
	# the answer does not depend on how many trees were considered before it.
	if WorldHash.hash01(cell_x, cell_z, world_seed, SALT_TREE) >= chance:
		return

	var ground := int(floor(surface))
	var trunk_height := WorldHash.hash_range(
		cell_x, cell_z, world_seed, SALT_TREE_TRUNK,
		config.tree_trunk_min, config.tree_trunk_max)
	var canopy_radius := WorldHash.hash_range(
		cell_x, cell_z, world_seed, SALT_TREE_CANOPY,
		config.tree_canopy_min, config.tree_canopy_max)

	var origin := chunk.origin()

	for i in trunk_height:
		_set_if_inside(chunk, origin, bx, ground + 1 + i, bz, Block.TRUNK, false)

	# A cone: widest one block below the top of the trunk, narrowing to a point
	# a little above it. Starting below the trunk top is what makes the foliage
	# wrap the trunk instead of balancing on it like a hat.
	var layers := canopy_radius + 3
	var base_y := ground + trunk_height - 1
	for layer in layers:
		var r := int(round(float(canopy_radius) * (1.0 - float(layer) / float(layers))))
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				# +1 rounds the corners off, so the canopy is a cone rather
				# than a stepped pyramid of squares.
				if dx * dx + dz * dz > r * r + 1:
					continue
				_set_if_inside(chunk, origin, bx + dx, base_y + layer, bz + dz,
					Block.LEAVES, true)


## Write one block, if it is inside this chunk.
##
## `only_air` is what stops the canopy from eating its own trunk - leaves are
## drawn over air only, trunk over anything.
func _set_if_inside(chunk: Chunk, origin: Vector3i, bx: int, by: int, bz: int,
		id: int, only_air: bool) -> void:
	var lx := bx - origin.x
	var ly := by - origin.y
	var lz := bz - origin.z
	if not Chunk.in_bounds(lx, ly, lz):
		return
	if only_air and chunk.voxels[Chunk.index(lx, ly, lz)] != Block.AIR:
		return
	chunk.set_voxel(lx, ly, lz, id)


## Block type for a solid voxel.
##
## `depth` is how far below the surface this voxel is - 0 is the surface block
## itself - and `zone` is the elevation zone of the column above it.
##
## Soil sits under meadow and forest only. The plan says soil under any
## surface, but a cliff face in the bare-rock zone then shows a brown stripe
## three blocks below its top, and rock that is soil underneath reads as wrong
## from a long way off. Rock and snow are stone all the way down; recorded as a
## deliberate departure.
func block_for(depth: int, zone: int) -> int:
	# TWO blocks of surface, not one.
	#
	# The detail layer puts a one-block step every few blocks, and with a
	# single-block skin every one of those steps exposes the soil beneath it.
	# On screen that is a haze of dark brown flecks over every hillside -
	# clearly visible in the first screenshot tour, and confirmed as soil
	# rather than tree trunks by re-shooting the same seed with trees off.
	# A second block of turf covers the one-block risers and leaves soil
	# showing only where the ground is genuinely steep, which is where you
	# want to see it.
	if depth <= 1:
		return ZONE_SURFACE[zone]
	if zone <= ZONE_FOREST and depth < 5:
		return Block.DIRT
	return Block.STONE
