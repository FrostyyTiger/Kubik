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


## Density per zone, as the probability that a block column carries one
## instance.
##
## STAGE 5 SHIPS ONE MODEL DELIBERATELY. The infrastructure - the worker job,
## the buffer packing, the MultiMesh node, the shader - is the risky half of
## this feature, and shipping it with a single grass tuft means the first thing
## judged is whether the LAYER works rather than whether nine models look
## right. Stage 6 fills the rest of this table in.
const DENSITY := {
	TerrainGenerator.ZONE_MEADOW: 0.35,
	TerrainGenerator.ZONE_FOREST: 0.10,
}


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
		cx: int, cz: int, removed: Dictionary = {}) -> Array:
	var out: Array = []
	var bx0 := cx * Chunk.SIZE
	var bz0 := cz * Chunk.SIZE
	var seed := gen.world_seed
	var bs: float = config.block_size

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

			var surface := gen.surface_at(float(bx), float(bz))
			var zone := gen.surface_zone_at(bx, bz, surface)
			var density: float = DENSITY.get(zone, 0.0)
			if density <= 0.0 or roll >= density:
				continue

			if not _ground_allows(gen, config, bx, bz, surface):
				continue

			var model := _model_for(zone, bx, bz, seed)
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
	return out


## The largest value in DENSITY, for the early-out above.
##
## A true upper bound, so the early-out can never reject a block that should
## have carried something - the same argument TreePlacement.max_probability()
## makes one scale up.
const MAX_DENSITY := 0.35


## Can anything grow on this block at all?
static func _ground_allows(gen: TerrainGenerator, config: WorldgenConfig,
		bx: int, bz: int, surface: float) -> bool:
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
	return not _tree_occupies(gen, config, bx, bz)


## Does a trunk stand on this block?
##
## Only the trunk, not the canopy: grass under a canopy is exactly what a
## forest floor is, and the plan puts ferns and mushrooms there on purpose.
## The check is over the candidate cells that could have put a trunk on this
## block, which after jitter is at most the four nearest.
static func _tree_occupies(gen: TerrainGenerator, config: WorldgenConfig,
		bx: int, bz: int) -> bool:
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		return false
	var jitter: int = config.tree_jitter_blocks
	var c0x := Chunk.floor_div(bx - jitter - 1, cell)
	var c1x := Chunk.floor_div(bx + jitter + 1, cell)
	var c0z := Chunk.floor_div(bz - jitter - 1, cell)
	var c1z := Chunk.floor_div(bz + jitter + 1, cell)
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			var found := TreePlacement.decide(gen, cx, cz)
			if found.is_empty():
				continue
			var tx: int = found["bx"]
			var tz: int = found["bz"]
			# A 2 x 2 trunk occupies (bx, bz) and one block further out on
			# each axis - see TreeSpecies._draw_trunk().
			var span := 1 if found["params"]["thick"] else 0
			if bx >= tx and bx <= tx + span and bz >= tz and bz <= tz + span:
				return true
	return false


## Which model, given the zone.
static func _model_for(zone: int, bx: int, bz: int, seed: int) -> int:
	match zone:
		TerrainGenerator.ZONE_MEADOW, TerrainGenerator.ZONE_FOREST:
			# Two shapes, evenly. The eye stops counting at two.
			return FloraModels.GRASS_TUFT_A \
				if WorldHash.hash2(bx, bz, seed, SALT_MODEL) & 1 == 0 \
				else FloraModels.GRASS_TUFT_B
	return -1


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
	var half := int(config.world_blocks_xz / 2)
	var scale := float(stride * stride)
	var seed := gen.world_seed

	for bz in range(-half, half, stride):
		for bx in range(-half, half, stride):
			var roll := WorldHash.hash01(bx, bz, seed, SALT_PRESENT)
			if roll >= MAX_DENSITY:
				continue
			var surface := gen.surface_at(float(bx), float(bz))
			var zone := gen.surface_zone_at(bx, bz, surface)
			var density: float = DENSITY.get(zone, 0.0)
			if density <= 0.0 or roll >= density:
				continue
			if not _ground_allows(gen, config, bx, bz, surface):
				continue
			out[TerrainGenerator.ZONE_NAMES[zone]] += int(scale)
			out["total"] += int(scale)
	return out
