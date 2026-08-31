class_name HomePlacement

## WHERE AN ANIMAL LIVES, decided from the seed, like everything else in the
## world.
##
## Design decision 6: **every creature has an address - the den, not the
## spawner.** A pack is anchored to a real, worldgen-placed site, and what that
## buys is written in `creatures-v1.md`: encounters have geography (you
## wandered into THEIR valley and you can leave it), the territory edge is the
## honest leash, the pack survives the players leaving because it is data
## rather than theatre, and the world gets its first ADDRESSES - a den is a
## site before Sites v1 exists, a thing a name can attach to and a director can
## `mark_site`.
##
## THE `TreePlacement` SCHOOL, DELIBERATELY. Same candidate lattice, same
## product of independent terms, same ceiling-first early-out, same
## hash-the-coordinates contract:
##
##     p = base(home type) * zone_ok * slope_ok * danger * spawn_ok
##
## Each term answers ONE question and none of them has to know what the others
## decided. Nothing here rolls an RNG, nothing depends on which chunk asked
## first, and two machines that have never spoken agree about every den in the
## world without sending a byte - which is the same contract the trees have
## lived under since terrain v1.
##
## NOTHING HERE WRITES TERRAIN. Hard rule 2: homes READ the generator. A den is
## a position and an identity, not a hole in the ground - whether it ever gets
## a visible scree mouth is on Marcel's list and is night 2's at the earliest.

## Salts, 400-419, claimed for creature homes and documented beside the
## registry pattern in `tree_placement.gd:52-67`. Independent uses of the
## coordinate hash must not agree with each other, or every den would sit
## exactly where a burrow field does.
const SALT_DEN_PRESENT := 400
const SALT_DEN_JITTER_X := 401
const SALT_DEN_JITTER_Z := 402
const SALT_BURROW_FIELD := 403
const SALT_BURROW_COUNT := 404
# 405-419 reserved. Night 2's crag takes 405-407.

## Home model numbers, for the packed identity. WELL CLEAR OF `FloraModels`,
## which occupies 0-18 and has room to grow: the identity packs the model into
## one byte and a collision would make a den and a boulder the same name.
const MODEL_DEN := 200
const MODEL_BURROW := 201
const MODEL_CRAG := 202  ## reserved; the eagle is night 2

## The candidate lattice: one candidate every 64 blocks (32 m), jittered off it
## by up to 24 blocks. Coarser than the trees' by design - a den is a rare
## thing and a lattice fine enough for grass would be a lattice that has to
## reject 99.9% of its own candidates.
const CELL_BLOCKS := 64
const JITTER_BLOCKS := 24

## --- The dials ---------------------------------------------------------------
##
## PLACEMENT DENSITY, NOT A PER-SPECIES NUMBER, so it lives here rather than in
## `species.gd` - exactly as `TreePlacement` keeps its own and `TreeSpecies`
## keeps the shapes. Hard rule 5 is about what a wolf IS; this is about how many
## of them the world has.

## The chance a qualifying candidate is a den, before the danger ramp.
const DEN_BASE := 0.022

## How much likelier a den is at the far edge of the world than at the near
## edge of its own band. Pillar 3: distance is the difficulty axis, so the
## packs thicken as you range further, and they do it smoothly rather than at
## a line somebody painted.
const DEN_DANGER_GAIN := 1.5

## Below this `danger_at` there are no dens at all. The near valley is the warm
## register.
const DEN_DANGER_MIN := 0.25

## A den's ground: steep enough to be somewhere, walkable enough to live on.
const DEN_SLOPE_MIN := 5.0
const DEN_SLOPE_MAX := 25.0

## No den closer than this to spawn, in metres. The first hour is not supposed
## to contain a wolf pack.
const DEN_SPAWN_CLEAR_M := 300.0

## Which zones a den can be in - the steep, the dark and the far.
const DEN_ZONES := [
	TerrainGenerator.ZONE_FOREST,
	TerrainGenerator.ZONE_HEATH,
	TerrainGenerator.ZONE_ROCK,
]

## Burrow fields: common, sunny, and on the flat.
const BURROW_BASE := 0.20
const BURROW_SLOPE_MAX := 10.0
## How flat the neighbourhood has to be, in degrees, for a bench to be a bench.
const BURROW_BENCH_MAX := 14.0
## Cells either side sampled for that flatness.
const BURROW_BENCH_CELLS := 2
const BURROW_SPAWN_CLEAR_M := 60.0
## Burrows per field, hashed inclusive.
const BURROW_COUNT_MIN := 3
const BURROW_COUNT_MAX := 6


## Numbers cached once per world, in `TreePlacement.Masks`' shape and for its
## reason: the hot path must not reach back through the generator for a value
## that cannot change.
##
## THERE IS NO NEW NOISE LAYER HERE, and that is worth saying rather than
## leaving as an absence. The trees needed grove and glade noise because a
## forest's clumping is not a property of the terrain. Everything a home asks -
## what zone this is, how steep, how flat the bench, how far out - the terrain
## already answers, so adding a noise layer would have been inventing a
## structure the world does not have.
class Masks extends RefCounted:
	var block_size := 0.5
	var spawn_m := Vector3.ZERO


static func masks_for(gen: TerrainGenerator) -> Masks:
	var m := Masks.new()
	m.block_size = gen.config.block_size
	m.spawn_m = Vector3(
		float(gen.spawn_block.x) * m.block_size, 0.0,
		float(gen.spawn_block.y) * m.block_size)
	return m


## The highest probability any candidate anywhere can reach.
##
## The ceiling the first roll is tested against, and it has to be a TRUE upper
## bound or the early-out silently deletes homes. Den probability is
## `DEN_BASE * (1 + DEN_DANGER_GAIN * t)` with `t` at most 1.
static func max_probability() -> float:
	return maxf(DEN_BASE * (1.0 + DEN_DANGER_GAIN), BURROW_BASE)


## EVERYTHING ABOUT THE HOME AT ONE CANDIDATE, or {} if there is none.
##
## ONE FUNCTION, ASKED BY EVERYTHING - `TreePlacement.decide`'s rule, for its
## reason. The probe counts what this returns, the server spawns from it, and
## night 2's marmot reads the same rows. Three restatements of a placement rule
## drift apart by the second stage.
static func decide(gen: TerrainGenerator, cell_x: int, cell_z: int,
		masks: Masks = null) -> Dictionary:
	# ROLL AGAINST THE CEILING FIRST, exactly as the trees do: two integer
	# hashes reject most candidates before anything asks where the ground is,
	# and that is the difference between enumerating a region in milliseconds
	# and in seconds.
	var den_roll := WorldHash.hash01(cell_x, cell_z, gen.world_seed, SALT_DEN_PRESENT)
	var burrow_roll := WorldHash.hash01(cell_x, cell_z, gen.world_seed, SALT_BURROW_FIELD)
	if den_roll >= max_probability() and burrow_roll >= BURROW_BASE:
		return {}

	if masks == null:
		masks = masks_for(gen)

	# The SITE's position, jittered off the lattice, and everything below is
	# asked about where the home actually is - not about where its cell is, or
	# a den jittered onto a cliff would be judged on the bench next door.
	var bx := cell_x * CELL_BLOCKS + WorldHash.hash_range(
		cell_x, cell_z, gen.world_seed, SALT_DEN_JITTER_X,
		-JITTER_BLOCKS, JITTER_BLOCKS)
	var bz := cell_z * CELL_BLOCKS + WorldHash.hash_range(
		cell_x, cell_z, gen.world_seed, SALT_DEN_JITTER_Z,
		-JITTER_BLOCKS, JITTER_BLOCKS)
	if not gen.heightmap.in_bounds(bx, bz):
		return {}

	var surface := gen.surface_at(float(bx), float(bz))
	var zone := gen.surface_zone_at(bx, bz, surface)
	var slope := gen.heightmap.slope_deg_at(float(bx), float(bz))
	var pos := Vector3(float(bx) * masks.block_size,
		surface * masks.block_size, float(bz) * masks.block_size)
	var from_spawn := Vector2(pos.x - masks.spawn_m.x, pos.z - masks.spawn_m.z).length()

	# THE DEN IS TRIED FIRST because it is by far the rarer thing, and a
	# candidate that is a den is not also a burrow field.
	var danger := gen.danger_at(float(bx), float(bz))
	if DEN_ZONES.has(zone) \
			and slope >= DEN_SLOPE_MIN and slope <= DEN_SLOPE_MAX \
			and danger >= DEN_DANGER_MIN \
			and from_spawn >= DEN_SPAWN_CLEAR_M:
		# THE DANGER RAMP. 1.0 at the near edge of the band, 1 + gain at the
		# far corner of the world - so packs thicken with distance smoothly,
		# and nobody had to paint a zone.
		var t := (danger - DEN_DANGER_MIN) / maxf(1.0 - DEN_DANGER_MIN, 0.001)
		if den_roll < DEN_BASE * (1.0 + DEN_DANGER_GAIN * t):
			return {
				"home": "den", "species": Species.WOLF, "model": MODEL_DEN,
				"bx": bx, "bz": bz, "pos": pos,
				"id": identity(MODEL_DEN, bx, bz),
				"slope_deg": slope, "danger": danger, "zone": zone,
				"from_spawn_m": from_spawn, "count": 1,
			}

	# A BURROW FIELD: sunny meadow, flat, and flat AROUND it - a bench, not the
	# one level cell on a hillside.
	if zone == TerrainGenerator.ZONE_MEADOW \
			and slope <= BURROW_SLOPE_MAX \
			and from_spawn >= BURROW_SPAWN_CLEAR_M \
			and burrow_roll < BURROW_BASE \
			and _is_bench(gen, bx, bz):
		return {
			"home": "burrow", "species": Species.MARMOT, "model": MODEL_BURROW,
			"bx": bx, "bz": bz, "pos": pos,
			"id": identity(MODEL_BURROW, bx, bz),
			"slope_deg": slope, "danger": danger, "zone": zone,
			"from_spawn_m": from_spawn,
			"count": WorldHash.hash_range(cell_x, cell_z, gen.world_seed,
				SALT_BURROW_COUNT, BURROW_COUNT_MIN, BURROW_COUNT_MAX),
		}

	return {}


## Is the ground around here a BENCH - flat, and flat for some way in every
## direction?
##
## One cell can be level on a 40 degree hillside; a marmot colony needs the
## shelf, not the ledge. Sampled on the coarse grid because that is the
## resolution the shelf exists at.
static func _is_bench(gen: TerrainGenerator, bx: int, bz: int) -> bool:
	var step := gen.heightmap.step
	for dz in range(-BURROW_BENCH_CELLS, BURROW_BENCH_CELLS + 1):
		for dx in range(-BURROW_BENCH_CELLS, BURROW_BENCH_CELLS + 1):
			var slope := gen.heightmap.slope_deg_at(
				float(bx + dx * step), float(bz + dz * step))
			if slope > BURROW_BENCH_MAX:
				return false
	return true


## A home's 64-bit name, in `FloraPlacement.identity`'s packing.
##
## THE SAME PACKING, ON PURPOSE. A home is an addressable thing in the world
## whose identity is a pure function of where it is, which is exactly what that
## function already means - and reusing it means Sites v1 inherits one id
## scheme rather than two. The model byte is what keeps a den and a boulder
## from sharing a name.
static func identity(model: int, bx: int, bz: int) -> int:
	return FloraPlacement.identity(model, bx, bz)


## Every home in a rectangle of BLOCK coordinates.
##
## `bounds` is in blocks; pass the whole world footprint to enumerate a region.
## The lattice is walked rather than the blocks, so this costs one `decide` per
## candidate and not one per block.
static func homes_in_region(gen: TerrainGenerator, bounds: Rect2i,
		masks: Masks = null) -> Array:
	if masks == null:
		masks = masks_for(gen)
	var out := []
	var lo_x := int(floor(float(bounds.position.x) / float(CELL_BLOCKS))) - 1
	var lo_z := int(floor(float(bounds.position.y) / float(CELL_BLOCKS))) - 1
	var hi_x := int(ceil(float(bounds.end.x) / float(CELL_BLOCKS))) + 1
	var hi_z := int(ceil(float(bounds.end.y) / float(CELL_BLOCKS))) + 1
	for cz in range(lo_z, hi_z + 1):
		for cx in range(lo_x, hi_x + 1):
			var found := decide(gen, cx, cz, masks)
			if found.is_empty():
				continue
			# A candidate whose jitter carried it outside the asked-for
			# rectangle belongs to the neighbour, not to us - which is why the
			# loop above starts one cell wide on every side.
			if not bounds.has_point(Vector2i(found["bx"], found["bz"])):
				continue
			out.append(found)
	return out


## Every home in the whole current region. The probe's enumeration, and the
## server's when it goes looking for the nearest den.
static func all_homes(gen: TerrainGenerator) -> Array:
	var half := int(gen.config.world_blocks_xz / 2)
	return homes_in_region(gen, Rect2i(-half, -half, half * 2, half * 2))


## The nearest home of a kind to a point, or {}. What the server asks on world
## ready, and what Stage 6's pack is anchored to.
static func nearest(gen: TerrainGenerator, kind: String, pos_m: Vector3,
		homes: Array = []) -> Dictionary:
	if homes.is_empty():
		homes = all_homes(gen)
	var best := {}
	var best_d := INF
	for h in homes:
		if h["home"] != kind:
			continue
		var d: float = (h["pos"] as Vector3).distance_to(pos_m)
		if d < best_d:
			best_d = d
			best = h
	return best
