class_name FloraPlacement

## Which plant stands on which block, and how it is turned.
##
## The counterpart of TreePlacement, one scale down. Trees are decided per
## CANDIDATE CELL, four blocks apart, because a tree is bigger than a block.
## Ground cover is decided PER BLOCK COLUMN, because a grass tuft is smaller
## than one and every block that can carry one is a separate question.
##
##
## EVERYTHING HERE IS HASHED FROM (seed, bx, bz, salt).
##
## No RNG, no stream, no dependence on which column was built first. That is
## the same contract worldgen has lived under since v1, and it buys three
## things at once here: two players see the same meadow; a column rebuilt after
## an edit comes back identical except where the edit was; and Stage 9 can name
## an individual tuft by its coordinates alone, because its identity is a
## function of where it is rather than of when it was made.
##
##
## WHAT A COLUMN IS.
##
## One chunk COLUMN - 16 x 16 blocks, all altitudes. Not a chunk: the surface
## crosses a column exactly once, so one node per column holds every plant in
## it and nothing has to be split across the chunk boundary the surface happens
## to fall on.

## Salts, one per independent question.
const SALT_PRESENT := 300
const SALT_MODEL := 301
const SALT_YAW := 302
const SALT_SCALE := 303
const SALT_TINT := 304
const SALT_KIND := 306
const SALT_PATCH_COLOR := 307
const SALT_BOULDER_SIZE := 308
const SALT_FIREFLY := 309

## Fireflies per block column, in meadow. Their own roll, not part of the zone
## density - at 0.004 they would be swamped by grass at 0.35, and a firefly is
## not competing for the ground anyway. It hovers a metre over it.
const FIREFLY_DENSITY := 0.004

## Steepest ground a plant will stand on, in degrees.
##
## Higher than the trees' 40: moss and grass hold onto slopes a spruce cannot,
## and the alternative - bare rock wherever the ground tips - reads as a bald
## patch rather than as a crag.
const MAX_SLOPE_DEG := 50.0

## Per-instance size variation, and per-instance value tint. Both small on
## purpose: this is texture, not confetti, the same argument Block.jitter makes
## about the terrain.
const SCALE_RANGE := Vector2(0.85, 1.15)
const TINT_AMOUNT := 0.06


# --- The masks --------------------------------------------------------------
#
# Three more fbm fields, at three different wavelengths, and they exist for one
# reason: EVEN DENSITY READS AS TEXTURE, NOT AS GROUND COVER. Ferns scattered
# uniformly through a forest are a green carpet; ferns in patches with bare
# floor between them are a forest floor. It is the same argument the grove mask
# makes about trees, one scale down, and it is why these are separate fields
# rather than one shared "clumpiness" - a flower patch is 40 m across and a
# fern stand is 25 m, and at one wavelength they would clump in the same
# places, which reads as a single feature wearing two costumes.

class Masks extends RefCounted:
	var flower: FastNoiseLite = null     # ~40 m, where meadow flowers grow
	var fern: FastNoiseLite = null       # ~25 m, where ferns clump
	var shrub: FastNoiseLite = null      # ~20 m, where heath thickens
	var flower_cut := 0.0
	var fern_cut := 0.0
	var shrub_cut := 0.0
	var key := ""

	## Wavelengths in BLOCKS. Blocks are 0.5 m, so 40 m is 80 blocks.
	const FLOWER_WAVELENGTH := 80.0
	const FERN_WAVELENGTH := 50.0
	const SHRUB_WAVELENGTH := 40.0

	## Share of the world above each threshold - the top 30% of the flower
	## field is a flower patch, and so on.
	const FLOWER_SHARE := 0.30
	const FERN_SHARE := 0.45
	const SHRUB_SHARE := 0.50

	const SAMPLES := 64

	func build(world_seed: int, config: WorldgenConfig) -> void:
		flower = _noise(world_seed, 901, 1.0 / FLOWER_WAVELENGTH)
		fern = _noise(world_seed, 902, 1.0 / FERN_WAVELENGTH)
		shrub = _noise(world_seed, 903, 1.0 / SHRUB_WAVELENGTH)
		flower_cut = _quantile(flower, config, FLOWER_SHARE)
		fern_cut = _quantile(fern, config, FERN_SHARE)
		shrub_cut = _quantile(shrub, config, SHRUB_SHARE)
		key = "%d|%d" % [world_seed, config.world_blocks_xz]

	static func _noise(world_seed: int, offset: int, freq: float) -> FastNoiseLite:
		var n := FastNoiseLite.new()
		n.seed = world_seed + offset
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = freq
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 2
		return n

	## Measured, not assumed - the same argument TreePlacement.Masks makes.
	func _quantile(n: FastNoiseLite, config: WorldgenConfig, share: float) -> float:
		var half := float(config.world_blocks_xz) * 0.5
		var step := float(config.world_blocks_xz) / float(SAMPLES)
		var values := PackedFloat32Array()
		values.resize(SAMPLES * SAMPLES)
		var i := 0
		for j in SAMPLES:
			for k in SAMPLES:
				values[i] = n.get_noise_2d(
					-half + float(k) * step, -half + float(j) * step)
				i += 1
		values.sort()
		return values[clampi(int(float(values.size()) * (1.0 - share)),
			0, values.size() - 1)]


static var _masks: Masks = null
static var _masks_mutex := Mutex.new()


static func masks_for(gen: TerrainGenerator, config: WorldgenConfig) -> Masks:
	var want := "%d|%d" % [gen.world_seed, config.world_blocks_xz]
	var got := _masks
	if got != null and got.key == want:
		return got
	_masks_mutex.lock()
	if _masks == null or _masks.key != want:
		var built := Masks.new()
		built.build(gen.world_seed, config)
		_masks = built
	got = _masks
	_masks_mutex.unlock()
	return got


# --- The zone rules ---------------------------------------------------------

## Density per zone: the probability that a block column carries one instance.
##
## THE TOTAL IS WHAT MATTERS FOR THE BUDGET, and it is why these are stated per
## zone rather than per model. One roll decides whether a block carries
## anything at all; a second decides what. That keeps the cost of an empty
## block to a single hash however many models a zone can grow, and it means
## raising the variety of a zone never raises its triangle count.
## MEADOW WAS 0.50 through foliage v1 and look v1 took a third off it: at one
## tuft on every second block the meadow close-up read as confetti, and the
## poster wants a colour field with drifts on it. The flowers did not thin
## with it - see _meadow(), which grows them denser inside a patch instead.
const ZONE_DENSITY := {
	TerrainGenerator.ZONE_SHORE: 0.35,
	TerrainGenerator.ZONE_MEADOW: 0.34,
	TerrainGenerator.ZONE_FOREST: 0.24,
	TerrainGenerator.ZONE_ALPINE: 0.24,
	TerrainGenerator.ZONE_HEATH: 0.26,
	TerrainGenerator.ZONE_ROCK: 0.075,
	TerrainGenerator.ZONE_SNOW: 0.005,
}

## The largest value above, for the early-out. A true upper bound, so it can
## never reject a block that should have carried something.
const MAX_DENSITY := 0.50


## Every plant in one chunk column.
##
## Returns an Array of instances, each
##   {"model", "pos" (Vector3, metres), "yaw", "scale", "tint"}
##
## RUNS ON A WORKER THREAD, so it touches nothing but the generator and the
## config - both finished and read-only by the time any column is built. It
## never reads a Chunk, and that is worth being explicit about: a plant's
## position is a question about the SURFACE, which the generator answers
## directly and better than the voxels do, because it can answer for a column
## whose chunks have not been built yet.
static func column(gen: TerrainGenerator, config: WorldgenConfig,
		cx: int, cz: int, removed: Dictionary = {},
		edited: Dictionary = {}) -> Array:
	var out: Array = []
	var bx0 := cx * Chunk.SIZE
	var bz0 := cz * Chunk.SIZE
	var seed := gen.world_seed
	var bs: float = config.block_size
	var masks := masks_for(gen, config)
	# EVERY TREE THAT CAN REACH THIS COLUMN, WORKED OUT ONCE.
	#
	# This was the single most expensive thing in the whole decoration layer
	# and it did not look like it. Two rules need to know about trunks - grass
	# does not grow through one, and mushrooms crowd them - and both were
	# asking TreePlacement.decide() per BLOCK, over the four to nine candidate
	# cells that could reach it. That is several hundred full placement
	# decisions per column, each of them noise samples and a heightmap lookup,
	# to answer a question about at most a dozen trees.
	#
	# Thirty-six cells cover a column and its margin. Deciding them once and
	# scanning the handful of trees that come back took a column from 34 ms to
	# a fraction of it - and it is the same answer, because decide() is a pure
	# function of the cell.
	var trees := _trees_near(gen, config, cx, cz)

	for lz in Chunk.SIZE:
		var bz := bz0 + lz
		for lx in Chunk.SIZE:
			var bx := bx0 + lx

			# One hash decides presence, and it is asked FIRST because it
			# rejects most columns for the cost of some integer arithmetic.
			# Everything below it - the surface, the zone, the slope - is a
			# heightmap lookup or a noise sample, and paying those for a block
			# that was never going to carry anything is the whole cost of this
			# function multiplied by three.
			var roll := WorldHash.hash01(bx, bz, seed, SALT_PRESENT)
			if roll >= MAX_DENSITY:
				continue
			# Disturbed ground grows nothing - see World._edited_blocks_in().
			if not edited.is_empty() and edited.has(Vector2i(bx, bz)):
				continue

			var surface := gen.surface_at(float(bx), float(bz))
			var zone := gen.surface_zone_at(bx, bz, surface)
			var density: float = ZONE_DENSITY.get(zone, 0.0)
			if density <= 0.0 or roll >= density:
				continue

			if not _ground_allows(gen, config, bx, bz, surface, trees):
				continue

			var model := _model_for(gen, config, masks, zone, bx, bz, surface, trees)
			if model < 0:
				continue
			if not removed.is_empty() and removed.has(identity(model, bx, bz)):
				continue

			out.append({
				"model": model,
				# Y IS THE TOP FACE OF THE SURFACE BLOCK, not the surface
				# altitude. The block at altitude N occupies N to N+1, so a
				# plant standing on it stands at N+1 - and a plant placed at
				# the fractional surface height would be buried up to its
				# ankles in the block it is standing on.
				"pos": Vector3(float(bx) * bs,
					float(int(floor(surface)) + 1) * bs,
					float(bz) * bs),
				"yaw": WorldHash.hash01(bx, bz, seed, SALT_YAW) * TAU,
				"scale": lerpf(SCALE_RANGE.x, SCALE_RANGE.y,
					WorldHash.hash01(bx, bz, seed, SALT_SCALE)),
				"tint": 1.0 + (WorldHash.hash01(bx, bz, seed, SALT_TINT) * 2.0 - 1.0)
					* TINT_AMOUNT,
			})
	_add_fireflies(gen, config, cx, cz, out, removed)
	return out


## A METRE OF AIR OVER A MEADOW, AFTER DARK.
##
## Rolled separately from everything else and added on top, because a firefly
## is not ground cover competing for a block - it is in the air above one, and
## a block can perfectly well have a grass tuft under a firefly.
##
## ONLY IN COLUMNS THAT ARE MEADOW AT THEIR CENTRE, which is a deliberate
## coarseness. Testing every block would put a lone firefly on each stray patch
## of meadow inside a forest; testing the column puts them where there is open
## ground to see them over, and costs one zone lookup per column instead of
## two hundred and fifty six.
static func _add_fireflies(gen: TerrainGenerator, config: WorldgenConfig,
		cx: int, cz: int, out: Array, removed: Dictionary) -> void:
	if config.night_life <= 0.0:
		return
	var mid_x := cx * Chunk.SIZE + Chunk.SIZE / 2
	var mid_z := cz * Chunk.SIZE + Chunk.SIZE / 2
	var mid_surface := gen.surface_at(float(mid_x), float(mid_z))
	if gen.surface_zone_at(mid_x, mid_z, mid_surface) != TerrainGenerator.ZONE_MEADOW:
		return

	var seed := gen.world_seed
	var bs: float = config.block_size
	for lz in Chunk.SIZE:
		var bz := cz * Chunk.SIZE + lz
		for lx in Chunk.SIZE:
			var bx := cx * Chunk.SIZE + lx
			if WorldHash.hash01(bx, bz, seed, SALT_FIREFLY) >= FIREFLY_DENSITY:
				continue
			if not removed.is_empty() \
					and removed.has(identity(FloraModels.FIREFLY, bx, bz)):
				continue
			var surface := gen.surface_at(float(bx), float(bz))
			out.append({
				"model": FloraModels.FIREFLY,
				"pos": Vector3(float(bx) * bs,
					float(int(floor(surface)) + 1) * bs, float(bz) * bs),
				"yaw": WorldHash.hash01(bx, bz, seed, SALT_YAW) * TAU,
				"scale": 1.0,
				"tint": 1.0,
			})


## Every tree whose trunk could stand on or near this chunk column.
##
## The margin is the trunk jitter plus the two blocks a mushroom crowds a trunk
## by, plus one for a 2 x 2 trunk's second column - so nothing that either rule
## cares about can be outside the scan.
static func _trees_near(gen: TerrainGenerator, config: WorldgenConfig,
		cx: int, cz: int) -> Array:
	var out: Array = []
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		return out
	var margin: int = config.tree_jitter_blocks + 3
	var x0 := cx * Chunk.SIZE - margin
	var x1 := cx * Chunk.SIZE + Chunk.SIZE - 1 + margin
	var z0 := cz * Chunk.SIZE - margin
	var z1 := cz * Chunk.SIZE + Chunk.SIZE - 1 + margin
	var masks := TreePlacement.masks_for(gen)
	for tz in range(Chunk.floor_div(z0, cell), Chunk.floor_div(z1, cell) + 1):
		for tx in range(Chunk.floor_div(x0, cell), Chunk.floor_div(x1, cell) + 1):
			var found := TreePlacement.decide(gen, tx, tz, masks)
			if found.is_empty():
				continue
			out.append({
				"bx": int(found["bx"]),
				"bz": int(found["bz"]),
				# A 2 x 2 trunk occupies one block further out on each axis -
				# see TreeSpecies._draw_trunk().
				"span": 1 if found["params"]["thick"] else 0,
			})
	return out


## Which plant, given the zone and the masks. -1 for none.
##
## The second of the two rolls: the first decided that SOMETHING grows here,
## this decides what. `kind` is one hash reused across the whole function, on
## its own salt, so the choice cannot correlate with presence - if it did,
## every densest patch of meadow would also be the flowery one.
static func _model_for(gen: TerrainGenerator, config: WorldgenConfig,
		masks: Masks, zone: int, bx: int, bz: int, surface: float,
		trees: Array) -> int:
	var seed := gen.world_seed
	var kind := WorldHash.hash01(bx, bz, seed, SALT_KIND)

	match zone:
		TerrainGenerator.ZONE_MEADOW:
			return _meadow(masks, kind, bx, bz, seed)

		TerrainGenerator.ZONE_FOREST:
			# A GLADE IS MEADOW. The glade mask is what stopped trees growing
			# here, so the ground is open and the light reaches it - which is
			# exactly the condition flowers want. Reusing the tree mask rather
			# than inventing a second one is what keeps the clearing and the
			# flowers in it in the same place.
			if TreePlacement.in_glade(gen, bx, bz):
				return _meadow(masks, kind, bx, bz, seed)
			# grass 0.10, fern 0.12 damped by its mask, mushrooms 0.02 - and
			# 0.15 within two blocks of a trunk, which is where they really
			# grow.
			var near_trunk := _near_trunk(trees, bx, bz)
			var shroom := 0.15 if near_trunk else 0.02
			if kind < shroom:
				return FloraModels.MUSHROOM
			var fern := 0.0
			if masks.fern.get_noise_2d(float(bx), float(bz)) >= masks.fern_cut:
				fern = 0.50
			if kind < shroom + fern:
				return FloraModels.FERN
			return _tuft(bx, bz, seed)

		TerrainGenerator.ZONE_ALPINE:
			# short grass 0.20, alpine flower 0.04 - so one in six is a flower.
			return FloraModels.ALPINE_FLOWER if kind < 0.17 \
				else FloraModels.GRASS_SHORT

		TerrainGenerator.ZONE_HEATH:
			# shrub 0.25 clumped, boulder 0.01.
			if kind < 0.04:
				return _boulder(bx, bz, seed)
			if masks.shrub.get_noise_2d(float(bx), float(bz)) < masks.shrub_cut:
				return -1
			return FloraModels.SHRUB_A if kind < 0.52 else FloraModels.SHRUB_B

		TerrainGenerator.ZONE_ROCK:
			# scree 0.06, boulder 0.015 - one in five is a boulder.
			return _boulder(bx, bz, seed) if kind < 0.20 \
				else (FloraModels.SCREE_A if kind < 0.60 else FloraModels.SCREE_B)

		TerrainGenerator.ZONE_SNOW:
			return _boulder(bx, bz, seed)

		TerrainGenerator.ZONE_SHORE:
			# REEDS FOLLOW THE WATER, NOT THE ALTITUDE. A shore band is a fact
			# about one particular lake, and every lake in the world sits at a
			# different height - so this asks how far above THIS lake's shore
			# level the ground is, which Lakes.shore_level was built for.
			if gen.lakes != null:
				var level := gen.lakes.shore_level_at_cell(
					gen._cell_index(float(bx), float(bz)))
				if not is_nan(level) and surface - level <= 1.0 and kind < 0.57:
					return FloraModels.REED
			return FloraModels.GRASS_SHORT

	return -1


## Meadow and glade: grass, and flowers inside a patch.
##
## EVERY FLOWER IN ONE PATCH IS THE SAME COLOUR, which is the whole reason a
## patch exists as a concept. Four colours scattered evenly through a meadow
## read as confetti; a field of yellow with a field of purple beyond it reads
## as two kinds of flower, which is what a real meadow looks like from a
## distance. The colour is hashed from the PATCH cell, not the block.
static func _meadow(masks: Masks, kind: float, bx: int, bz: int,
		seed: int) -> int:
	# HALF OF WHAT GROWS IN A PATCH IS FLOWERS - was 0.30 through foliage v1.
	# Look v1 thinned the meadow by a third (ZONE_DENSITY) and raised this so
	# the flowers did not thin with it: about as many flowers per block inside
	# a patch as before, on half the grass, which is a drift of one colour on
	# a plain field rather than flowers scattered through confetti.
	if masks.flower.get_noise_2d(float(bx), float(bz)) >= masks.flower_cut \
			and kind < 0.50:
		var cell := int(Masks.FLOWER_WAVELENGTH)
		var px := Chunk.floor_div(bx, cell)
		var pz := Chunk.floor_div(bz, cell)
		return FloraModels.FLOWERS[
			WorldHash.hash2(px, pz, seed, SALT_PATCH_COLOR) % 4]
	return _tuft(bx, bz, seed)


static func _tuft(bx: int, bz: int, seed: int) -> int:
	return FloraModels.GRASS_TUFT_A \
		if WorldHash.hash2(bx, bz, seed, SALT_MODEL) & 1 == 0 \
		else FloraModels.GRASS_TUFT_B


## Three sizes of boulder, the small one commonest.
static func _boulder(bx: int, bz: int, seed: int) -> int:
	var r := WorldHash.hash01(bx, bz, seed, SALT_BOULDER_SIZE)
	if r < 0.62:
		return FloraModels.BOULDER_S
	return FloraModels.BOULDER_M if r < 0.92 else FloraModels.BOULDER_L


## Is there a trunk within two blocks? Mushrooms crowd them.
static func _near_trunk(trees: Array, bx: int, bz: int) -> bool:
	for t in trees:
		if absi(int(t["bx"]) - bx) <= 2 and absi(int(t["bz"]) - bz) <= 2:
			return true
	return false


## Can anything grow on this block at all?
static func _ground_allows(gen: TerrainGenerator, config: WorldgenConfig,
		bx: int, bz: int, surface: float, trees: Array) -> bool:
	# NOT UNDER WATER. A lake's surface is drawn as a flat sheet and the bed
	# below it is ordinary ground, so without this every lake in the world
	# would have a meadow at the bottom of it.
	if gen.lakes != null:
		var level := gen.lakes.shore_level_at_cell(
			gen._cell_index(float(bx), float(bz)))
		if not is_nan(level) and surface < level:
			return false

	if gen.heightmap != null \
			and gen.heightmap.slope_deg_at(float(bx), float(bz)) >= MAX_SLOPE_DEG:
		return false

	# NOT UNDER A TREE, and this is the one rule that has to ask TreePlacement.
	# A trunk stands on a block column, and a tuft of grass sharing that column
	# grows straight through it. Asking the placement rule rather than reading
	# the voxels keeps this on a worker thread with no chunk in hand - and
	# gives the same answer, because both are functions of the same seed.
	return not _tree_occupies(trees, bx, bz)


## Does a trunk stand on this block?
##
## Only the trunk, not the canopy: grass under a canopy is exactly what a
## forest floor is, and the plan puts ferns and mushrooms there on purpose.
static func _tree_occupies(trees: Array, bx: int, bz: int) -> bool:
	for t in trees:
		var tx: int = t["bx"]
		var tz: int = t["bz"]
		var span: int = t["span"]
		if bx >= tx and bx <= tx + span and bz >= tz and bz <= tz + span:
			return true
	return false


# --- Identity ---------------------------------------------------------------

## A flora instance's 64-bit name.
##
##   bits 56-63   model id
##   bits 48-55   sub-index, for a future block carrying more than one plant
##   bits 24-47   cell z, signed
##   bits  0-23   cell x, signed
##
## COMPUTED, NEVER STORED. There are millions of these in a world and not one
## of them is worth a byte of memory: the identity is a pure function of where
## the plant is, so it can be recomputed the instant something needs to name
## one. Stage 9 uses it as the key of the removed-flora set, which is how
## gathering will eventually take a plant out of the world with one small
## dictionary entry rather than a per-instance record.
static func identity(model: int, bx: int, bz: int, sub: int = 0) -> int:
	return ((model & 0xFF) << 56) | ((sub & 0xFF) << 48) \
		| ((bz & 0xFFFFFF) << 24) | (bx & 0xFFFFFF)


## The block an identity refers to, unpacked.
##
## SIGN-EXTENDED BY HAND, and this is the part that is easy to get wrong. The
## coordinates are packed into 24 bits, so a negative one comes back out as a
## large positive number - block -100 becomes 16,777,116 - and a column lookup
## on that lands on the far side of a 3 km world with no error anywhere. The
## world is 6,000 blocks across against a 24-bit range of 16.7 million, so
## there is no ambiguity to resolve, only a sign to restore.
static func block_of(id: int) -> Vector2i:
	var bx := id & 0xFFFFFF
	var bz := (id >> 24) & 0xFFFFFF
	if bx >= 0x800000:
		bx -= 0x1000000
	if bz >= 0x800000:
		bz -= 0x1000000
	return Vector2i(bx, bz)


## Which chunk column an identity belongs to.
static func column_of(id: int) -> Vector2i:
	var b := block_of(id)
	return Vector2i(Chunk.floor_div(b.x, Chunk.SIZE),
		Chunk.floor_div(b.y, Chunk.SIZE))


static func model_of(id: int) -> int:
	return (id >> 56) & 0xFF


# --- For the probe ----------------------------------------------------------

## Estimated instance counts per zone, sampled on a stride and scaled up.
##
## SAMPLED AND SAID SO. Every block column in a 3 km world is nine million
## evaluations and this tool runs twice a stage. A stride of 16 is 35,000 of
## them and answers the question the number is actually asked - "does heath
## have shrubs on it" - to well inside the precision anybody reads it at.
static func probe_counts(gen: TerrainGenerator, config: WorldgenConfig,
		stride: int) -> Dictionary:
	var out := {"total": 0}
	for name in TerrainGenerator.ZONE_NAMES:
		out[name] = 0
	for name in FloraModels.NAMES:
		out["model_" + name] = 0
	var half := int(config.world_blocks_xz / 2)
	var scale := stride * stride
	var seed := gen.world_seed
	var masks := masks_for(gen, config)

	for bz in range(-half, half, stride):
		for bx in range(-half, half, stride):
			var roll := WorldHash.hash01(bx, bz, seed, SALT_PRESENT)
			if roll >= MAX_DENSITY:
				continue
			var surface := gen.surface_at(float(bx), float(bz))
			var zone := gen.surface_zone_at(bx, bz, surface)
			var density: float = ZONE_DENSITY.get(zone, 0.0)
			if density <= 0.0 or roll >= density:
				continue
			var trees := _trees_near(gen, config,
				Chunk.floor_div(bx, Chunk.SIZE), Chunk.floor_div(bz, Chunk.SIZE))
			if not _ground_allows(gen, config, bx, bz, surface, trees):
				continue
			var model := _model_for(gen, config, masks, zone, bx, bz, surface, trees)
			if model < 0:
				continue
			out[TerrainGenerator.ZONE_NAMES[zone]] += scale
			out["model_" + FloraModels.NAMES[model]] += scale
			out["total"] += scale
	return out
