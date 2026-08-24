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
static func stamp_chunk(chunk: Chunk, gen: TerrainGenerator) -> void:
	var config := gen.config
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		return

	var origin := chunk.origin()
	var margin := TreeSpecies.max_reach(config) + config.tree_jitter_blocks
	var masks := masks_for(gen)

	var writer := TreeSpecies.ChunkWriter.new()
	writer.bind(chunk)

	var cx0 := Chunk.floor_div(origin.x - margin, cell)
	var cx1 := Chunk.floor_div(origin.x + Chunk.SIZE - 1 + margin, cell)
	var cz0 := Chunk.floor_div(origin.z - margin, cell)
	var cz1 := Chunk.floor_div(origin.z + Chunk.SIZE - 1 + margin, cell)

	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			stamp_cell(writer, gen, cx, cz, masks)


## Draw one candidate cell's tree, if it has one.
##
## Called by every chunk the tree reaches, and MUST produce the same tree for
## all of them - which is why nothing in here reads the chunk, the writer, or
## anything else that differs between those calls.
static func stamp_cell(writer, gen: TerrainGenerator, cell_x: int, cell_z: int,
		masks: Masks = null) -> void:
	var found := decide(gen, cell_x, cell_z, masks)
	if found.is_empty():
		return
	TreeSpecies.draw(writer, found["species"], found["bx"], found["ground"],
		found["bz"], found["params"], gen.config)


## Everything about the tree at one candidate, or {} if there is none.
##
## ONE FUNCTION, ASKED BY EVERYTHING. The chunk stamper draws what it returns;
## the probe counts it; the screenshot tour looks for the densest patch of it;
## Stage 7's far-tree ring builds impostors from it, which is what makes a tree
## you walk up to the tree you saw at 300 m. Three restatements of a placement
## rule would have drifted apart by the second stage.
static func decide(gen: TerrainGenerator, cell_x: int, cell_z: int,
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
				return _tree(gen, TreeSpecies.HERO, cell_x, cell_z, bx, bz, surface)
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

	var species := species_at(gen, cell_x, cell_z, zone, surface, bx, bz)
	if species < 0:
		return {}
	return _tree(gen, species, cell_x, cell_z, bx, bz, surface)


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
		bx: int, bz: int, surface: float) -> Dictionary:
	return {
		"species": species,
		"cell": Vector2i(cell_x, cell_z),
		"bx": bx,
		"bz": bz,
		# floor(), not round(): the block at altitude N occupies the space from
		# N to N+1, so a surface at 40.7 means block 40 is the top solid one
		# and the trunk starts at 41.
		"ground": int(floor(surface)),
		"surface": surface,
		"params": TreeSpecies.params_for(species, cell_x, cell_z,
			gen.world_seed, gen.config),
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


## Forest clumps. 1 inside a grove, `grove_floor` outside it.
static func _grove(masks: Masks, bx: int, bz: int) -> float:
	if masks.grove_cut == INF:
		return 1.0   # share 0: the term is off
	if masks.grove.get_noise_2d(float(bx), float(bz)) >= masks.grove_cut:
		return 1.0
	return masks.grove_floor


## Clearings. 0 inside a glade, 1 everywhere else.
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
	var f := clampf(t * 4.0 - 0.5, 0.0, 3.0)
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
