class_name TreePlacement

## WHERE a tree goes, as distinct from what it is.
##
## `tree_species.gd` owns the shapes. This owns the decision: which candidate
## cells grow something, which species stands there, and how the answer is kept
## identical on two machines that have never spoken to each other.
##
##
## THE CANDIDATE LATTICE.
##
## Trees are not scattered continuously. The world is divided into cells of
## `tree_cell_blocks`, each cell is one candidate, and a candidate either grows
## a tree or does not. That is what makes the whole thing addressable: a tree
## is identified by its cell's integer coordinates, every parameter it has is
## hashed from them, and no part of the answer depends on which chunk asked or
## in what order.
##
##
## THE PRODUCT, AND WHY IT IS A PRODUCT.
##
##   p = base(zone, altitude in band) * grove * glade
##       * slope_ok * bench_ok * spawn_ok * tree_density_scale
##
## Each term answers ONE question and none of them has to know what the others
## decided. That is not tidiness, it is the difference between a forest and
## wallpaper. The world before this stage had exactly one term - a probability
## that peaked in the middle of the forest band - and one term is precisely
## what "evenly scattered" means: a Poisson scatter has no clumps, no
## clearings, no edges and no reason for anything to be anywhere.
##
## Multiplying independent masks gives all of those for free. A grove mask
## makes thickets; a glade mask punches holes in them; slope, bench and spawn
## each subtract somewhere for a reason you can point at. Turn any one of them
## to 0 in the F4 panel and watch what it was doing.
##
##
## WHY EVERY CHUNK SCANS MORE CELLS THAN IT CONTAINS.
##
## A tree rooted in one cell reaches several blocks sideways, so it crosses
## into chunks that do not contain its trunk. If a chunk only drew the trees
## rooted inside itself, every tree near a boundary would be sliced off - and
## which slice you saw would depend on which chunks happened to be loaded.
##
## So each chunk iterates candidates over a region wider than itself by the
## furthest a crown can spread, draws all of them, and lets the writer discard
## what falls outside. The margin is DERIVED from the species table's widest
## crown, never typed, so adding a wider species cannot silently start clipping.

## Salts. Independent uses of the coordinate hash must not agree with each
## other, or every tree that jitters north would also be a snag.
##
## SALT_TREE itself stays on TerrainGenerator at 202 and keeps its value: it
## decides which candidates grow anything at all, and changing it would
## rearrange every tree in every existing world.
const SALT_SPECIES := 220
const SALT_HERO := 221
const SALT_JITTER_X := 222
const SALT_JITTER_Z := 223
const SALT_MEADOW_KIND := 224
## Which KIND a grove is - ordinary or old growth. Hashed on the grove's own
## cell rather than the tree's, so a whole grove is one kind and the boundary
## between two is a district edge rather than a speckle.
const SALT_GROVE_KIND := 225
## Thins the candidates inside an old-growth grove. Its own salt, so raising or
## lowering old_growth_keep does not reshuffle which trees are old growth.
const SALT_OLD_GROWTH_THIN := 226

## Which of two crowns that want the same ground keeps it (trees v4). Its own
## salt, so spacing cannot correlate with the species or jitter rolls - a tree
## must not be likelier to win because of what it is.
const SALT_SPACING := 227


# --- The masks --------------------------------------------------------------

## The grove and glade noise, and the thresholds that turn them into shares.
##
## HELD APART FROM TerrainGenerator, which owns every other noise layer in the
## world, for one reason: the generator is the file another plan may be working
## in tonight, and the plan this belongs to says the hooks into it are the ones
## it names. So the flora masks live here, built once per world and shared by
## every worker thread - which is safe for exactly the reason the terrain noise
## is safe to share: nothing writes to a FastNoiseLite after it is built, and
## the engine already samples the generator's layers from three worker threads
## at once.
class Masks extends RefCounted:
	var grove: FastNoiseLite = null
	var glade: FastNoiseLite = null
	## Noise values above these are "in a grove" / "in a glade".
	var grove_cut := 0.0
	var glade_cut := 0.0
	## What a candidate outside a grove is multiplied by. Copied from the
	## config at build time so the hot path never reaches back through the
	## generator for it.
	var grove_floor := 0.35
	## What the cuts are for, so a cached set can be recognised.
	var key := ""

	## How many points are sampled to find the two thresholds.
	##
	## MEASURED, NOT ASSUMED, and it is the same trick the elevation zones use:
	## "the top 35% of this noise" is a question about the noise's actual
	## distribution, and fbm's distribution is not something to guess a constant
	## for. 96 x 96 points over a 3 km world pins a quantile far tighter than
	## anybody reads it, and it is deterministic - same points, same order, same
	## sort, on every machine.
	const SAMPLES := 96

	func build(world_seed: int, config: WorldgenConfig) -> void:
		grove = _noise(world_seed, 811, config.grove_freq)
		glade = _noise(world_seed, 812, config.glade_freq)
		grove_cut = _quantile(grove, config, config.grove_share)
		glade_cut = _quantile(glade, config, config.glade_share)
		grove_floor = config.grove_floor
		key = _key_for(world_seed, config)

	static func _key_for(world_seed: int, config: WorldgenConfig) -> String:
		return "%d|%.8f|%.6f|%.8f|%.6f|%.6f|%d" % [
			world_seed, config.grove_freq, config.grove_share,
			config.glade_freq, config.glade_share, config.grove_floor,
			config.world_blocks_xz]

	static func _noise(world_seed: int, offset: int, freq: float) -> FastNoiseLite:
		var n := FastNoiseLite.new()
		n.seed = world_seed + offset
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = freq
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		# Two octaves. These are masks that pick DISTRICTS - the detail of a
		# third octave is smaller than one tree and only makes the edge of a
		# grove ragged at a scale nobody standing in it can perceive.
		n.fractal_octaves = 2
		return n

	## The value this noise exceeds `share` of the time, over the whole world.
	func _quantile(n: FastNoiseLite, config: WorldgenConfig,
			share: float) -> float:
		if share <= 0.0:
			return INF     # nothing is ever above it
		if share >= 1.0:
			return -INF    # everything is
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
		var idx := clampi(int(float(values.size()) * (1.0 - share)),
			0, values.size() - 1)
		return values[idx]


## Cached per world. Built under a mutex because chunk generation runs on
## several worker threads and the first of them to arrive is whichever the
## scheduler picked - there is no main-thread moment to build this in that does
## not mean editing world.gd, which this plan does not allow until Stage 5.
##
## Locked ONCE PER CHUNK, not once per candidate: stamp_chunk() takes the masks
## and hands them down. A lock on the path of three million candidate
## evaluations would cost more than the trees.
static var _masks: Masks = null
static var _masks_mutex := Mutex.new()


static func masks_for(gen: TerrainGenerator) -> Masks:
	var want := Masks._key_for(gen.world_seed, gen.config)
	var got := _masks
	if got != null and got.key == want:
		return got
	_masks_mutex.lock()
	# Checked again inside the lock: two workers can both have missed above.
	if _masks == null or _masks.key != want:
		var built := Masks.new()
		built.build(gen.world_seed, gen.config)
		# Published as one reference assignment, fully built, so a reader that
		# raced past the lock can never see a half-filled object.
		_masks = built
	got = _masks
	_masks_mutex.unlock()
	return got


# --- Stamping ---------------------------------------------------------------

## Stamp every tree that reaches into this chunk.
##
## The one entry point TerrainGenerator._place_trees() calls.
## Every tree that reaches into ONE COLUMN, stamped once across all its chunks.
##
## The candidate scan is the same one stamp_chunk() does - the column's
## footprint grown by max_reach - but it happens once for the whole column
## instead of once per chunk. Same cells, same decide() calls, same trees; a
## sixth or a seventh of the work.
## How much of a column's sky its own trees cover, 0 to 1.
##
## Crown area over column area, from the tree list the column already decided -
## so it costs nothing beyond a sum. Clamped, because crowns overlap and the
## question is "is there a roof", not "how many layers of roof".
##
## Returned by stamp_column() rather than computed separately: the candidate
## scan is the expensive part and it has already run.
## TREES V3 STAGE 7: THIS WAS `stamp_column()` AND IT WRITES NOTHING NOW.
##
## The scan half is byte-for-byte what it was - the same footprint walk, the
## same `max_reach` margin, the same crown-area sum - and the writer half is
## gone with the block trees. What comes back is what always came back:
## `canopy_cover`, the share of this column's sky its own trees cover, which
## `ChunkMesher._under_canopy()` shades the forest floor with.
##
## THE FOREST FLOOR IS UNAFFECTED BY THE DELETION, and that is decision 6's
## whole claim: the shade's input always came from THIS SCAN and never from
## the voxels. A column asks which trees reach it, sums their crowns, and
## darkens its ground. It never once looked at a leaf block to do it.
static func cover_column(gen: TerrainGenerator,
		chunk_x: int, chunk_z: int) -> float:
	var config := gen.config
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		return 0.0

	var margin := TreeSpecies.max_reach(config) + config.tree_jitter_blocks
	var masks := masks_for(gen)
	var ox := chunk_x * Chunk.SIZE
	var oz := chunk_z * Chunk.SIZE

	var cx0 := Chunk.floor_div(ox - margin, cell)
	var cx1 := Chunk.floor_div(ox + Chunk.SIZE - 1 + margin, cell)
	var cz0 := Chunk.floor_div(oz - margin, cell)
	var cz1 := Chunk.floor_div(oz + Chunk.SIZE - 1 + margin, cell)

	var crown_area := 0.0
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var found := decide(gen, cx, cz, masks)
			if found.is_empty():
				continue
			# Only the part of the crown that is over THIS column counts, and
			# a crown centred a long way off contributes nothing - so the sum
			# is weighted by how much of the trunk's own cell overlaps us.
			var r := float(found["params"].get("crown", 0))
			if r <= 0.0:
				continue
			var dx := absf(float(found["bx"]) - float(ox) - float(Chunk.SIZE) * 0.5)
			var dz := absf(float(found["bz"]) - float(oz) - float(Chunk.SIZE) * 0.5)
			var reach := r + float(Chunk.SIZE) * 0.5
			if dx > reach or dz > reach:
				continue
			crown_area += PI * r * r \
				* clampf(1.0 - maxf(dx, dz) / maxf(reach, 0.001), 0.0, 1.0)
	var column_area := float(Chunk.SIZE * Chunk.SIZE)
	return clampf(crown_area / column_area, 0.0, 1.0)


## Everything about the tree at one candidate, or {} if there is none.
##
## ONE FUNCTION, ASKED BY EVERYTHING. The chunk stamper draws what it returns;
## the probe counts it; the screenshot tour looks for the densest patch of it;
## Stage 7's far-tree ring builds impostors from it, which is what makes a tree
## you walk up to the tree you saw at 300 m. Three restatements of a placement
## rule would have drifted apart by the second stage.
## Does a tree stand at this candidate, and what is it?
##
## TWO HALVES SINCE TREES V4. `_decide_raw()` is the placement rule as it has
## always been - zones, masks, rolls - and answers for ONE cell knowing nothing
## about its neighbours. `_suppressed()` is the crown-spacing rule on top, and
## it is the half that needs neighbours.
##
## THE SPLIT IS WHAT STOPS THE RECURSION. Spacing has to ask its neighbours
## whether they grew a tree, and if that question were `decide()` the neighbour
## would ask ITS neighbours and the world would never finish generating. It
## asks `_decide_raw()` instead: one level, bounded, and the property below
## survives it.
## `cache` is an optional per-CALLER dictionary of raw decisions. A caller that
## walks a whole region - the ring - hands the same one to every call and pays
## for each cell once instead of once per neighbour that looks at it; see
## `_raw_cached()`. Pass nothing and the behaviour is identical, just slower.
static func decide(gen: TerrainGenerator, cell_x: int, cell_z: int,
		masks: Masks = null, cache = null) -> Dictionary:
	var found := _raw_cached(gen, cell_x, cell_z, masks, cache)
	if found.is_empty():
		return {}
	if _suppressed(gen, found, masks, cache):
		return {}
	return found


## A raw decision, from the cache when there is one.
##
## THE KEY IS ONE INTEGER, not a Vector2i. A candidate lattice never exceeds a
## few million cells on an axis and packing the pair into one int makes this a
## hash of a number rather than of a struct - which matters because this is the
## hottest lookup in placement, called about fifty times per tree.
static func _raw_cached(gen: TerrainGenerator, cell_x: int, cell_z: int,
		masks: Masks, cache) -> Dictionary:
	if cache == null:
		return _decide_raw(gen, cell_x, cell_z, masks)
	# 32 bits each into a 64-bit int, the low half masked so a NEGATIVE z
	# cannot sign-extend over x and collide two different cells onto one key -
	# which is a wrong tree rather than a slow one.
	var key := (cell_x << 32) | (cell_z & 0xFFFFFFFF)
	var hit = cache.get(key)
	if hit != null:
		return hit
	var found := _decide_raw(gen, cell_x, cell_z, masks)
	cache[key] = found
	return found


## THE CROWN SPACING RULE: no two trees that SURVIVE may have crowns that
## interpenetrate, and that is a guarantee rather than a tendency.
##
## WHY IT HOLDS. Each candidate gets a hashed priority. A candidate dies if any
## RAW-accepted neighbour with a higher priority stands close enough that their
## crowns would meet. Suppose two survivors A and B did overlap: one of them
## has the higher priority - say A - and A is raw-accepted by definition, so B
## would have seen A and died. B is therefore not a survivor, and the pair
## cannot exist. The proof needs the suppressor set to be the RAW decisions and
## not the survivors, which is the same thing that keeps it one level deep.
##
## WHAT IT COSTS IN LOOK: a hole. A tree can be killed by a neighbour that is
## itself killed by a third, so the ground it wanted is left empty. That is
## visible as slightly thinner stands than the density asks for, and it is the
## price of a rule that terminates. Raising `tree_density_scale` pays it back.
##
## ORDER-INDEPENDENT AND DETERMINISTIC, like every other decision in this file:
## the answer is a function of (seed, cell) alone, so two players see the same
## forest and a column rebuilt after an edit comes back identical.
static func _suppressed(gen: TerrainGenerator, found: Dictionary,
		masks: Masks, cache = null) -> bool:
	var config := gen.config
	var spacing: float = config.tree_canopy_spacing
	if spacing <= 0.0:
		return false
	var r_self := canopy_radius_blocks(gen, found)
	if r_self <= 0.0:
		return false
	# HOW FAR A NEIGHBOUR CAN REACH FROM. The widest crown in the library plus
	# this one's, because that pair is the furthest apart two trunks can be and
	# still touch.
	#
	# AND TWICE THE JITTER, which the first cut of this rule left out and the
	# `tree spacing` gate caught: 2 overlapping pairs in 459 trees. The bound
	# is on CELLS but the test is on TRUNKS, and a trunk sits up to
	# `tree_jitter_blocks` from its cell centre. Two of them leaning toward
	# each other put a pair one cell beyond the scan close enough to touch, and
	# because neither could see the other, both survived.
	var cell: int = maxi(config.tree_cell_blocks, 1)
	var r_max := TreeModels.max_canopy_radius_m() / config.block_size
	var jitter := float(maxi(config.tree_jitter_blocks, 0))
	var reach := int(ceil(
		((r_self + maxf(r_max, r_self)) * spacing + jitter * 2.0) / float(cell)))
	var c: Vector2i = found["cell"]
	var mine := WorldHash.hash01(c.x, c.y, gen.world_seed, SALT_SPACING)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx == 0 and dz == 0:
				continue
			var nx := c.x + dx
			var nz := c.y + dz
			var theirs := WorldHash.hash01(nx, nz, gen.world_seed, SALT_SPACING)
			# STRICTLY HIGHER WINS, and an exact tie is broken on the cell
			# coordinates so that the comparison can never call both of a pair
			# the winner - which would delete both trees instead of one.
			if theirs < mine:
				continue
			if theirs == mine and Vector2i(nz, nx) <= Vector2i(c.y, c.x):
				continue
			var other := _raw_cached(gen, nx, nz, masks, cache)
			if other.is_empty():
				continue
			var r_other := canopy_radius_blocks(gen, other)
			if r_other <= 0.0:
				continue
			var ddx := float(int(other["bx"]) - int(found["bx"]))
			var ddz := float(int(other["bz"]) - int(found["bz"]))
			var need := (r_self + r_other) * spacing
			if ddx * ddx + ddz * ddz < need * need:
				return true
	return false


## The crown radius of a placed tree, in BLOCKS.
##
## PUBLIC BECAUSE THE GATE MUST ASK THE SAME QUESTION. The first `tree spacing`
## gate computed the radius its own way and reported two overlapping pairs that
## did not exist: it read the library for species that are not DRAWN from the
## library, where the rule reads the table. A gate that measures something the
## rule never promised is a gate that fails for the wrong reason, so there is
## one function and both call it.
##
## Off the model when there is one, because that is what is actually drawn.
## The species table's `crown` is the fallback and it is only right in the
## public build, where no model is drawn and the number describes nothing that
## can overlap anyway.
static func canopy_radius_blocks(gen: TerrainGenerator,
		found: Dictionary) -> float:
	var config := gen.config
	if TreeTable.drawn_as_model(int(found["species"]), config):
		# THE SPECIES' WIDEST, NOT THIS TREE'S. Which variant is drawn depends
		# on the snow bias, and resolving that is a zone solve per candidate -
		# paid 25 times per tree once neighbours ask it too. A species' variants
		# are one tree in several colourways, so the widest of them stands in
		# for any of them to within a voxel. See TreeModels.max_canopy_radius_of.
		var slot := TreeTable.slot_of(int(found["species"]), config)
		if slot != &"":
			var r := TreeModels.max_canopy_radius_of(slot) / config.block_size
			if r > 0.0:
				return r
	return float(found["params"].get("crown", 0))


static func _decide_raw(gen: TerrainGenerator, cell_x: int, cell_z: int,
		masks: Masks = null) -> Dictionary:
	var config := gen.config

	# THE ORDER OF THE TERMS IS A PERFORMANCE DECISION, and a load-bearing one.
	#
	# decide() runs for every candidate cell every chunk scans - about eighty
	# per chunk, three million over a world - so what it costs lands directly
	# on chunk generation, and therefore on how fast the world arrives around a
	# walking player. Written in the order the plan states the formula in, it
	# was four times slower than the single-term rule it replaced.
	#
	# Two rearrangements make it cheap again, and neither changes which
	# candidates are accepted.
	#
	# FIRST, ROLL AGAINST THE CEILING. Accept requires hash < p, and p can
	# never exceed the largest base probability anywhere in the world - every
	# other term is at most 1. So a candidate whose hash is already above that
	# ceiling cannot possibly grow a tree, and can be rejected on two integer
	# hashes before anything asks where the ground is. On the tuned numbers
	# that is over half of them, and it costs no heightmap lookup, no noise
	# sample and no zone resolution.
	#
	# SECOND, DEFER THE BINARY TERMS. Glade, slope and bench are only ever 0 or
	# 1, and a 0-or-1 term can be tested after the roll instead of multiplied
	# into it: `hash < p * 1` accepts exactly what `hash < p` then a passing
	# gate accepts, and `p * 0` rejects exactly what a failing gate rejects. So
	# the two noise samples the bench test costs are paid only by candidates
	# that have already won their roll.
	#
	# Only the base and the grove mask are genuinely continuous, and only they
	# stay in the product.
	var roll := WorldHash.hash01(cell_x, cell_z, gen.world_seed,
		TerrainGenerator.SALT_TREE)
	var hero_roll := WorldHash.hash01(cell_x, cell_z, gen.world_seed, SALT_HERO)
	if roll >= max_probability(config) and hero_roll >= config.hero_probability:
		return {}

	var cell: int = config.tree_cell_blocks
	# The TRUNK's position, jittered off the lattice. Everything below - the
	# surface, the zone, the masks - is asked about where the tree actually
	# stands, not about where its cell is, or a tree jittered onto a cliff
	# would have been judged on the flat ground next door.
	var jitter: int = config.tree_jitter_blocks
	var bx := cell_x * cell
	var bz := cell_z * cell
	if jitter > 0:
		bx += WorldHash.hash_range(cell_x, cell_z, gen.world_seed,
			SALT_JITTER_X, -jitter, jitter)
		bz += WorldHash.hash_range(cell_x, cell_z, gen.world_seed,
			SALT_JITTER_Z, -jitter, jitter)

	var surface := gen.surface_at(float(bx), float(bz))
	var zone := gen.surface_zone_at(bx, bz, surface)

	# Spawn is a distance and a smoothstep, and is 1 for all but a disc 60 m
	# across in a 3 km world.
	var spawn := _spawn_ok(gen, bx, bz)
	if spawn <= 0.0:
		return {}

	if masks == null:
		masks = masks_for(gen)

	# THE HERO, rolled separately and on its own terms. It is not drawn from
	# the same roll as everything else - rolling it inside the meadow's own
	# 0.008 would make it rarer than rare by accident.
	#
	# THE GLADE MASK DOES NOT APPLY TO IT, deliberately, and that is the one
	# place a hero differs from every other tree. A glade is a clearing inside
	# a FOREST; in open meadow the mask still has values but it no longer means
	# anything, and letting it through would delete one lone beech in eight for
	# a reason that does not exist out there.
	if zone == TerrainGenerator.ZONE_MEADOW and config.hero_probability > 0.0:
		if hero_roll < config.hero_probability * spawn:
			if _ground_ok(gen, surface, bx, bz, zone):
				return _tree(gen, TreeSpecies.HERO, cell_x, cell_z, bx, bz,
					surface, false, zone)
			return {}

	var base := _base_probability(gen, zone, surface, bx, bz)
	if base <= 0.0:
		return {}

	var p := base * spawn * config.tree_density_scale * _grove(masks, bx, bz)
	if roll >= p:
		return {}

	if _glade(masks, bx, bz) <= 0.0:
		return {}
	if not _ground_ok(gen, surface, bx, bz, zone):
		return {}

	# OLD GROWTH: fewer trunks, further apart, each one far bigger. Thinning
	# here rather than lowering the base keeps the ordinary groves untouched.
	var old_growth := is_old_growth(gen, bx, bz, masks)
	if old_growth and WorldHash.hash01(cell_x, cell_z, gen.world_seed,
			SALT_OLD_GROWTH_THIN) >= config.old_growth_keep:
		return {}

	var species := species_at(gen, cell_x, cell_z, zone, surface, bx, bz)
	if species < 0:
		return {}
	if old_growth:
		species = _old_growth_species(gen, cell_x, cell_z, species)
	return _tree(gen, species, cell_x, cell_z, bx, bz, surface, old_growth, zone)


## AN OLD WOOD IS SPRUCE, BEECH AND DEAD WOOD. Birch is a pioneer - it grows
## where light reaches the floor, which is exactly what an old growth grove does
## not have - so it is re-rolled into the two that belong, and snags are twice
## as likely because an old wood has dead wood standing in it.
static func _old_growth_species(gen: TerrainGenerator, cell_x: int, cell_z: int,
		species: int) -> int:
	var r := WorldHash.hash01(cell_x, cell_z, gen.world_seed, SALT_GROVE_KIND + 1)
	if species == TreeSpecies.BIRCH:
		return TreeSpecies.SPRUCE if r < 0.6 else TreeSpecies.BEECH
	if species == TreeSpecies.LARCH and r < 0.15:
		return TreeSpecies.SNAG
	return species


## The highest probability any candidate anywhere can reach.
##
## The ceiling the first roll is tested against. It has to be a true upper
## bound or the early-out would start rejecting trees that should exist, so it
## takes the largest base in the table and assumes every other term is at its
## own maximum - grove 1, spawn 1.
static func max_probability(config: WorldgenConfig) -> float:
	var base := maxf(maxf(config.tree_base_forest, config.tree_base_meadow),
		maxf(config.tree_base_shore, config.tree_base_alpine))
	return base * maxf(config.tree_density_scale, 0.0)


## Is the ground itself willing to hold a tree here? Slope and benches.
##
## Both are only ever 0 or 1, which is what lets them be asked after the roll -
## see the note in decide(). Kept together because they are the same kind of
## question: not "how likely is a tree" but "can anything stand here at all".
static func _ground_ok(gen: TerrainGenerator, surface: float, bx: int, bz: int,
		zone: int) -> bool:
	if _slope_ok(gen, bx, bz, zone) <= 0.0:
		return false
	return _bench_ok(gen, surface, bx, bz) > 0.0


static func _tree(gen: TerrainGenerator, species: int, cell_x: int, cell_z: int,
		bx: int, bz: int, surface: float, old_growth := false,
		zone := -1) -> Dictionary:
	return {
		"species": species,
		# CARRIED, NOT RECOMPUTED. `decide()` has already solved the elevation
		# zone here, and `TreeFieldJob.variant_of()` wants the same answer to
		# work out the snow bias - once per tree, and there are thousands.
		"zone": zone,
		"old_growth": old_growth,
		"cell": Vector2i(cell_x, cell_z),
		"bx": bx,
		"bz": bz,
		# floor(), not round(): the block at altitude N occupies the space from
		# N to N+1, so a surface at 40.7 means block 40 is the top solid one
		# and the trunk starts at 41.
		"ground": int(floor(surface)),
		"surface": surface,
		"params": TreeSpecies.params_for(species, cell_x, cell_z,
			gen.world_seed, gen.config,
			gen.config.old_growth_scale if old_growth else 1.0),
	}


## Does a tree stand at this candidate? The cheap question, for counting.
static func accepts(gen: TerrainGenerator, cell_x: int, cell_z: int,
		masks: Masks = null) -> bool:
	return not decide(gen, cell_x, cell_z, masks).is_empty()


# --- The terms --------------------------------------------------------------

## How likely a tree is here before any mask, from the zone and where in its
## band the ground sits.
static func _base_probability(gen: TerrainGenerator, zone: int, surface: float,
		bx: int, bz: int) -> float:
	var config := gen.config
	match zone:
		TerrainGenerator.ZONE_FOREST:
			# Peaks in the MIDDLE of the band and tapers to the edge value at
			# both ends, so the treeline thins out instead of stopping dead
			# along a contour. The band is wherever the zone solver put it this
			# world, not a pair of altitudes in the config - without that the
			# treeline and the forest FLOOR would be two different bands and
			# trees would grow on grass.
			var band := gen.zone_band(TerrainGenerator.ZONE_FOREST)
			var t := _band_position(gen, surface, band, bx, bz)
			if t < 0.0:
				return 0.0
			return lerpf(config.tree_base_forest_edge, config.tree_base_forest,
				1.0 - absf(t - 0.5) * 2.0)

		TerrainGenerator.ZONE_MEADOW:
			return config.tree_base_meadow

		TerrainGenerator.ZONE_SHORE:
			return _shore_base(gen, surface, bx, bz)

		TerrainGenerator.ZONE_ALPINE, TerrainGenerator.ZONE_HEATH:
			# KRUMMHOLZ COUNTRY. The plan reads "0.05 fading to 0 halfway up
			# the alpine band", and in this world alpine is the zone
			# immediately above forest with heath above it - so taken
			# literally, krummholz would give out before it reached the heath
			# the same sentence puts it in. Read as the two bands together
			# instead: full strength where the forest ends, gone by the
			# midpoint of the pair, which is early heath. Recorded in
			# STATUS.md as an ambiguity resolved rather than followed.
			var lo := gen.zone_band(TerrainGenerator.ZONE_ALPINE).x
			var hi := gen.zone_band(TerrainGenerator.ZONE_HEATH).y
			var mid := lerpf(lo, hi, 0.5)
			if surface >= mid:
				return 0.0
			return config.tree_base_alpine \
				* (1.0 - (surface - lo) / maxf(mid - lo, 0.001))

	return 0.0


## Birch at the water's edge.
##
## Measured against the LAKE'S OWN SHORE LEVEL rather than against an altitude,
## because a shore is a fact about a particular lake and every lake in the
## world sits at a different height. Lakes.shore_level was built for exactly
## this in terrain v2 and costs one array read.
static func _shore_base(gen: TerrainGenerator, surface: float,
		bx: int, bz: int) -> float:
	if gen.lakes == null or gen.config.tree_shore_blocks <= 0.0:
		return 0.0
	var level := gen.lakes.shore_level_at_cell(
		gen._cell_index(float(bx), float(bz)))
	if is_nan(level):
		return 0.0
	# Above the water only. A birch standing in a lake is not a shore band.
	var above := surface - level
	if above < 0.0 or above > gen.config.tree_shore_blocks:
		return 0.0
	return gen.config.tree_base_shore


## Where in a zone band a surface sits, 0 at the bottom and 1 at the top, or
## -1 if it is outside. Jittered exactly as the zone boundaries are, so the
## band this measures against is the band the ground actually belongs to.
static func _band_position(gen: TerrainGenerator, surface: float,
		band: Vector2, bx: int, bz: int) -> float:
	var jitter := gen.zone_jitter_at(float(bx), float(bz))
	var lo := band.x + jitter
	var hi := band.y + jitter
	if surface <= lo or surface >= hi or hi <= lo:
		return -1.0
	return (surface - lo) / (hi - lo)


## IS THIS AN OLD-GROWTH GROVE? (world feel v1 Stage 6.)
##
## Hashed on the GROVE's cell, not the tree's: `grove_freq` is a wavelength, so
## 1/grove_freq blocks is the scale the grove mask itself varies on, and
## quantising to it gives one answer per grove instead of a speckle of two
## kinds inside one wood.
##
## WHY A TYPE AND NOT A GRADIENT. T5: contrast is what makes huge read. A
## forest where every tree is a bit bigger is a forest with bigger trees; a
## forest where one grove in three is enormous and the rest is ordinary is a
## forest with old growth in it, and you know when you have walked into one.
static func is_old_growth(gen: TerrainGenerator, bx: int, bz: int,
		masks: Masks = null) -> bool:
	var config := gen.config
	if config.old_growth_share <= 0.0 or config.grove_freq <= 0.0:
		return false
	if masks == null:
		masks = masks_for(gen)
	# Outside a grove there is no grove kind.
	if masks.grove_cut != INF \
			and masks.grove.get_noise_2d(float(bx), float(bz)) < masks.grove_cut:
		return false
	var gcx := int(floor(float(bx) * config.grove_freq))
	var gcz := int(floor(float(bz) * config.grove_freq))
	return WorldHash.hash01(gcx, gcz, gen.world_seed, SALT_GROVE_KIND) \
		< config.old_growth_share


## Forest clumps. 1 inside a grove, `grove_floor` outside it.
static func _grove(masks: Masks, bx: int, bz: int) -> float:
	if masks.grove_cut == INF:
		return 1.0   # share 0: the term is off
	if masks.grove.get_noise_2d(float(bx), float(bz)) >= masks.grove_cut:
		return 1.0
	return masks.grove_floor


## TODO(marcel): glades are in the wrong places.
##
## This decides where a clearing happens, from a low-frequency noise mask. Noise
## is a fine way to pick DISTRICTS and a poor way to pick a glade, because a
## glade is not a random location - it is a place where the light gets to the
## floor, and the terrain already knows where those are.
##
## The result today is clearings that sometimes sit on a steep north face where
## nothing would open up, and no clearings at all on the sunny shelf next to it
## where in a real forest there would be one.
##
## Note this is the SAME shape of exercise as `_bench_placement()` in
## TerrainGenerator, deliberately - it is the same mistake made twice, and the
## second one is easier to see now that the first is written down.
##
##   Hint: two things make a clearing, and the terrain has both.
##
##       var slope := gen.heightmap.slope_deg_at(wx, wz)
##       var flat := 1.0 - smoothstep(8.0, 26.0, slope)
##       var sunny := ... the aspect - see Block.SUN_ASPECT and the normal of
##                        the coarse gradient at (wx, wz)
##       return open if mask_value * flat * sunny is in its top glade_share
##
##   Careful, and this is the interesting part: making the glade term depend on
##   slope puts it in the same business as `_slope_ok`, which already refuses
##   trees on anything past 40 degrees. Multiply two terms that both say "not
##   on a slope" and the forest loses its edges twice over. Decide which one
##   owns steepness before you write the other.
##
##   Worth doing with glade_share turned well up in the F4 panel first, so you
##   can see what the mask is doing, and then turning it back down.
##
## Fallback: the noise mask alone, which gives clearings in plausible districts
## at implausible spots.
static func _glade(masks: Masks, bx: int, bz: int) -> float:
	if masks.glade_cut == INF:
		return 1.0   # share 0: the term is off
	return 0.0 if masks.glade.get_noise_2d(float(bx), float(bz)) \
		>= masks.glade_cut else 1.0


## Nothing grows on a face too steep to hold soil.
static func _slope_ok(gen: TerrainGenerator, bx: int, bz: int,
		zone: int) -> float:
	var limit := gen.config.tree_max_slope_deg
	# Krummholz country gets the species table's steeper limit: holding onto a
	# slope nothing else will is the whole reason it is up there.
	if zone == TerrainGenerator.ZONE_ALPINE or zone == TerrainGenerator.ZONE_HEATH:
		limit = float(TreeSpecies.SPECIES[TreeSpecies.KRUMMHOLZ]["slope"])
	if limit <= 0.0 or gen.heightmap == null:
		return 1.0
	return 1.0 if gen.heightmap.slope_deg_at(float(bx), float(bz)) < limit else 0.0


## Benches and plateaux stay clear.
##
## REACHES INTO THE GENERATOR'S TWO MASKS, and that is a deliberate cost. A
## bench is not a shape you can recognise from the finished heightmap - it is
## flat ground, and so is a valley floor - so the only honest way to ask "was
## this ground terraced" is to ask the thing that terraced it. The alternative
## was a public accessor on terrain_generator.gd, which this plan reserves for
## the hooks it names.
##
## The altitude window is applied as well as the mask, because the mask alone
## picks DISTRICTS: without the window this would clear trees off whole regions
## at altitudes where no bench was ever cut.
static func _bench_ok(gen: TerrainGenerator, surface: float,
		bx: int, bz: int) -> float:
	var config := gen.config
	if config.tree_bench_avoid <= 0.0:
		return 1.0
	var wx := float(bx)
	var wz := float(bz)
	var worst := 0.0
	if config.bench_strength > 0.0:
		worst = maxf(worst, _terrace_amount(gen, surface, wx, wz,
			gen._bench_mask, config.bench_strength,
			TerrainGenerator.BENCH_ALTITUDE_BAND))
	if config.plateau_strength > 0.0:
		worst = maxf(worst, _terrace_amount(gen, surface, wx, wz,
			gen._plateau_mask, config.plateau_strength,
			TerrainGenerator.PLATEAU_ALTITUDE_BAND))
	return 0.0 if worst > 0.5 * config.tree_bench_avoid else 1.0


## How strongly the terrain was terraced here - the same product
## TerrainGenerator._masked_terrace() forms before it blends.
##
## MIRRORED, NOT CALLED, because the generator's version returns the terraced
## HEIGHT and throws the amount away. Kept beside it in the file order so the
## two are read together; if the generator's window or fade changes, this has
## to change with it.
static func _terrace_amount(gen: TerrainGenerator, h: float, wx: float,
		wz: float, mask: FastNoiseLite, strength: float,
		band: Vector2) -> float:
	var config := gen.config
	var t := (h - config.min_altitude) \
		/ maxf(config.max_altitude - config.min_altitude, 0.001)
	var fade := (band.y - band.x) * TerrainGenerator.MASKED_BAND_FADE
	var in_band := smoothstep(band.x, band.x + fade, t) \
		* (1.0 - smoothstep(band.y - fade, band.y, t))
	if in_band <= 0.0:
		return 0.0
	var where := gen._bench_placement(mask.get_noise_2d(wx, wz), wx, wz)
	return clampf(strength, 0.0, 1.0) * in_band * where


## Spawn stays open.
static func _spawn_ok(gen: TerrainGenerator, bx: int, bz: int) -> float:
	var config := gen.config
	if config.tree_spawn_clear_m <= 0.0:
		return 1.0
	var spawn := gen.spawn_block
	var dx := float(bx - spawn.x) * config.block_size
	var dz := float(bz - spawn.y) * config.block_size
	var d := sqrt(dx * dx + dz * dz)
	return smoothstep(config.tree_spawn_clear_m,
		maxf(config.tree_spawn_ramp_m, config.tree_spawn_clear_m + 0.001), d)


# --- Which species --------------------------------------------------------

## Weights by quarter of the forest band, low to high.
##
## FOUR ROWS BLENDED LINEARLY, not four bands. Stepping between them would draw
## three horizontal stripes across every mountainside - the exact contour-line
## look that the zone jitter and the colour blend elsewhere exist to destroy.
##
## Read down a column to see what the forest is doing as it climbs: beech gives
## out, larch takes over, and krummholz only appears in the last quarter where
## the trees are already losing.
const FOREST_WEIGHTS := [
	#          spruce beech larch krumm  snag
	[0.45, 0.45, 0.00, 0.00, 0.10],   # bottom quarter
	[0.65, 0.20, 0.10, 0.00, 0.05],   # second
	[0.60, 0.05, 0.30, 0.00, 0.05],   # third
	[0.30, 0.00, 0.35, 0.30, 0.05],   # top
]

## Which species each column of FOREST_WEIGHTS is.
const FOREST_ORDER := [
	TreeSpecies.SPRUCE, TreeSpecies.BEECH, TreeSpecies.LARCH,
	TreeSpecies.KRUMMHOLZ, TreeSpecies.SNAG,
]


## Which species stands at an accepted candidate, or -1 for none.
static func species_at(gen: TerrainGenerator, cell_x: int, cell_z: int,
		zone: int, surface: float, bx: int, bz: int) -> int:
	match zone:
		TerrainGenerator.ZONE_FOREST:
			return _forest_species(gen, cell_x, cell_z, surface, bx, bz)

		TerrainGenerator.ZONE_MEADOW:
			# Beech and birch only. The split is not in the plan, which says
			# only "beech/birch/hero"; birch is put at a quarter because its
			# own row calls it a tree of the shore and of meadow MARGINS, and
			# a margin species that is half the meadow is not a margin.
			return TreeSpecies.BIRCH if WorldHash.hash01(cell_x, cell_z,
				gen.world_seed, SALT_MEADOW_KIND) < 0.25 else TreeSpecies.BEECH

		TerrainGenerator.ZONE_SHORE:
			return TreeSpecies.BIRCH

		TerrainGenerator.ZONE_ALPINE, TerrainGenerator.ZONE_HEATH:
			return TreeSpecies.KRUMMHOLZ

	return -1


## TODO(marcel): the species blend is a straight line, and forests are not.
##
## `t` is where in the forest band a tree stands, 0 at the bottom and 1 at the
## top, and it is handed to the weight table unchanged - so beech gives way to
## spruce, and spruce to larch, at a perfectly even rate all the way up.
##
## Real treelines do not do that. A forest is one thing for most of its height
## and then changes its mind quickly near the top, where the growing season
## gets short: the bottom two thirds of a slope are much the same wood, and the
## last third is where larch and krummholz take over in a hurry.
##
##   Hint:  return smoothstep(0.0, 1.0, t) is NOT what you want - that is
##   slower at both ends and this only wants to be slower at the bottom. Try
##
##       return pow(t, 1.6)
##
##   which spends longer in the low rows and compresses the top ones, so the
##   changeover happens where the trees are already struggling. 1.0 is the
##   present behaviour; push it up towards 2.5 and the treeline becomes a
##   distinct band rather than a gradient.
##
##   The thing to watch is the SPECIES COUNTS in the probe, not the picture:
##   this moves trees between species without changing the total, so it is the
##   per-species lines that tell you what you did. Bending it too far starves
##   beech, which is the only broadleaf in the forest band and the one giving
##   the conifers something to be compared against.
##
## Fallback: linear, i.e. `t` straight through.
static func _blend_curve(t: float) -> float:
	return t


## The blended weight table, plus wildness.
static func _forest_species(gen: TerrainGenerator, cell_x: int, cell_z: int,
		surface: float, bx: int, bz: int) -> int:
	var band := gen.zone_band(TerrainGenerator.ZONE_FOREST)
	var t := _band_position(gen, surface, band, bx, bz)
	if t < 0.0:
		t = 0.5

	# Position along the four rows: 0 at the middle of the bottom quarter, 3 at
	# the middle of the top one, so the ends of the band are not extrapolated
	# past the rows that describe them.
	var f := clampf(_blend_curve(t) * 4.0 - 0.5, 0.0, 3.0)
	var row := int(floor(f))
	var frac := f - float(row)
	var next := mini(row + 1, FOREST_WEIGHTS.size() - 1)

	var weights := PackedFloat32Array()
	weights.resize(FOREST_ORDER.size())
	var total := 0.0
	for i in FOREST_ORDER.size():
		var w: float = lerpf(FOREST_WEIGHTS[row][i], FOREST_WEIGHTS[next][i], frac)
		weights[i] = w
		total += w

	# WILDNESS TAKES FROM SPRUCE AND GIVES TO THE DEAD AND THE TWISTED. The
	# far edge of the world has more snags in its forests and gives way to
	# krummholz sooner - which is the "distance is the difficulty axis" pillar
	# said in vegetation instead of in numbers.
	var wild := gen.wildness_at(float(bx), float(bz))
	if wild > 0.0:
		var to_snag: float = gen.config.wildness_snag * wild
		# Krummholz only where the table already admits it, so wildness cannot
		# put alpine scrub in a valley-bottom forest.
		var to_krumm: float = gen.config.wildness_krummholz * wild \
			* (1.0 if weights[3] > 0.0 else 0.0)
		var moved := minf(to_snag + to_krumm, weights[0])
		if moved > 0.0:
			var share := moved / (to_snag + to_krumm)
			weights[0] -= moved
			weights[4] += to_snag * share
			weights[3] += to_krumm * share

	if total <= 0.0:
		return TreeSpecies.SPRUCE
	var roll := WorldHash.hash01(cell_x, cell_z, gen.world_seed, SALT_SPECIES) * total
	var acc := 0.0
	for i in FOREST_ORDER.size():
		acc += weights[i]
		if roll < acc:
			return FOREST_ORDER[i]
	return FOREST_ORDER[0]


# --- For the probe ----------------------------------------------------------

## Is this block inside a glade - a clearing the tree mask left open?
##
## Public because the FLORA placement asks it: a glade is where the light
## reaches the forest floor, so it grows meadow rather than forest. Reusing the
## same mask that kept the trees out, rather than inventing a second one, is
## what keeps the clearing and the flowers in it in the same place.
static func in_glade(gen: TerrainGenerator, bx: int, bz: int) -> bool:
	return _glade(masks_for(gen), bx, bz) <= 0.0


## Share of the forest band that is glade, sampled on a stride.
static func glade_share_measured(gen: TerrainGenerator, stride: int) -> float:
	var masks := masks_for(gen)
	var half := int(gen.config.world_blocks_xz / 2)
	var forest := 0
	var glade := 0
	for bz in range(-half, half, stride):
		for bx in range(-half, half, stride):
			var surface := gen.surface_at(float(bx), float(bz))
			if gen.surface_zone_at(bx, bz, surface) != TerrainGenerator.ZONE_FOREST:
				continue
			forest += 1
			if _glade(masks, bx, bz) <= 0.0:
				glade += 1
	return float(glade) / float(maxi(forest, 1))


## Share of the forest band that is inside a grove, sampled the same way.
static func grove_share_measured(gen: TerrainGenerator, stride: int) -> float:
	var masks := masks_for(gen)
	var half := int(gen.config.world_blocks_xz / 2)
	var forest := 0
	var grove := 0
	for bz in range(-half, half, stride):
		for bx in range(-half, half, stride):
			var surface := gen.surface_at(float(bx), float(bz))
			if gen.surface_zone_at(bx, bz, surface) != TerrainGenerator.ZONE_FOREST:
				continue
			forest += 1
			if _grove(masks, bx, bz) >= 1.0:
				grove += 1
	return float(grove) / float(maxi(forest, 1))
