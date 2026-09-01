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
const SEED_HILLS_MASK := 8
const SEED_BENCH := 9
const SEED_PLATEAU := 10

## Salts keep independent uses of the coordinate hash from agreeing with each
## other. Without them every tree in the world would stand exactly where the
## ground happens to dither.
const SALT_ZONE_DITHER := 101
const SALT_TREE := 202
const SALT_SLOPE_ZONE := 205

# 203 and 204 were SALT_TREE_TRUNK and SALT_TREE_CANOPY. They moved to
# TreeSpecies with the shapes in Stage 2 and kept their VALUES, which is the
# point of naming them here: a salt is part of what a seed means, so reusing
# 203 for something else would silently rearrange every tree in every existing
# world. Do not hand them out again.

## Elevation zones, low to high. Seven since terrain v2 Stage 7.
const ZONE_SHORE := 0
const ZONE_MEADOW := 1
const ZONE_FOREST := 2
const ZONE_ALPINE := 3
const ZONE_HEATH := 4
const ZONE_ROCK := 5
const ZONE_SNOW := 6

const ZONE_COUNT := 7

const ZONE_NAMES := [
	"shore", "meadow", "forest", "alpine", "heath", "rock", "snow",
]

## The block that shows at the surface of each zone.
const ZONE_SURFACE := [
	Block.SHORE,          # shore / wetland
	Block.GRASS,          # meadow
	Block.FOREST_FLOOR,   # forest floor
	Block.ALPINE_GRASS,   # alpine meadow
	Block.HEATH,          # heath
	Block.STONE,          # bare rock and scree
	Block.SNOW,           # snow
]

## Buckets in the altitude histogram the zone thresholds are resolved against.
## Over a 318 block range that is 0.16 blocks per bucket, which is finer than
## the zone boundary wobbles anyway.
const ZONE_HISTOGRAM_BUCKETS := 2048

## Sample every Nth cell on each axis when building that histogram. A quarter
## of a 750x750 map is 140,000 samples, which pins a percentile far more
## tightly than the 1% tolerance this has to hit, for a quarter of the cost.
const ZONE_SAMPLE_STRIDE := 2

## Correction rounds run when slope-aware zoning is on, and how coarsely they
## sample.
##
## The (altitude - jitter) percentile is EXACT while altitude is the only thing
## that decides a zone. Slope-aware zoning breaks that: it moves cells between
## zones after the fact, and it moves far more of them than the shares can
## absorb - at a 45 degree threshold, 29% of this map is steep and rock's whole
## budget is 11%.
##
## So the solver closes the loop. Resolve thresholds, MEASURE what the full
## zone function actually produced, push the targets by the error, resolve
## again. Three rounds is enough to converge and it costs a few hundred
## milliseconds at stride 4, which is a sixteenth of the map and still tens of
## thousands of samples.
##
## The virtue of doing it this way is that it is indifferent to WHAT the extra
## rule is. Any future rule that moves cells between zones - a river carving
## its banks, a burnt area, anything - is absorbed the same way without
## touching this code.
const ZONE_CORRECT_ROUNDS := 3
const ZONE_CORRECT_STRIDE := 4

var world_seed: int
var config: WorldgenConfig

## Built once by build_heightmap(). Everything downstream - voxels, the far
## mesh, lakes, trees - reads the world's shape from here rather than
## recomputing noise, so they cannot disagree about it.
var heightmap: Heightmap = null

## What each tile of the last build cost, in milliseconds, and which builder
## built them. Distance v5 Stage 4 - the tile size is chosen on these.
var tile_ms := PackedInt32Array()
var heightmap_builder := "gdscript"

## The C++ tile builder, when there is one. Null on a checkout with no compiled
## library, which is hard rule 1: the game builds every tile in GDScript and the
## world it gets is the same world, because both legs quantise.
var _tiles: HeightTiles = null

## Force the reference implementation, for the one probe that measures what the
## QUANTUM does rather than what the crossing does.
var force_gdscript_tiles := false

## Altitude, in blocks, of the top of each zone except the highest - so six
## values for seven zones. Resolved from the world's own altitude histogram at
## the end of build_heightmap(), and read-only from then on, which is what lets
## the far-field job and the chunk mesher ask about zones from worker threads.
var zone_thresholds := PackedFloat32Array()

## The world's lakes, once they have been found. Optional: everything here
## works without it, and the detail layer is simply not damped near water.
##
## Set AFTER build_heightmap() and after Lakes.compute(), never before - lakes
## are found in the coarse heightmap and the coarse heightmap must not depend
## on them, or the two would be defined in terms of each other.
var lakes: Lakes = null

var _continent: FastNoiseLite
var _mountain: FastNoiseLite
var _hills: FastNoiseLite
var _detail: FastNoiseLite
var _jitter: FastNoiseLite
var _warp_x: FastNoiseLite
var _warp_z: FastNoiseLite
var _hills_mask: FastNoiseLite
var _bench_mask: FastNoiseLite
var _plateau_mask: FastNoiseLite


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
	# Two octaves, not three: this decides WHERE hills are, and a mask with
	# fine detail in it makes hilly and flat country interleave at a scale you
	# cannot see, which is the uniform bumpiness the mask exists to remove.
	_hills_mask = _make_noise(SEED_HILLS_MASK, config.hills_mask_freq, 2)
	# One octave each: these decide WHERE a bench or a plateau is, and detail
	# in that answer would scatter them into fragments instead of districts.
	_bench_mask = _make_noise(SEED_BENCH, config.bench_freq, 1)
	_plateau_mask = _make_noise(SEED_PLATEAU, config.plateau_freq, 1)


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
## AT 3 KM IT IS 10.8 S, AND IT STAYS ON ONE THREAD because there is no other
## option, not because nobody tried. Handing the rows to the worker pool was
## measured on a 20-thread machine: two workers took exactly as long as one,
## four took 1.2x longer, sixteen took 4x longer - and the same again with a
## private generator and config per worker, so it is not shared state. GDScript
## execution is serialised across threads in this build and every extra worker
## only adds contention. The wait can be hidden behind a loading state or cut
## with cheaper per-cell maths; it cannot be parallelised from GDScript.
##
## Note that Heightmap does not call back into here. It is a plain data
## structure that knows how to interpolate itself, and the generator fills it -
## the two referring to each other by type is a cycle GDScript cannot resolve.
## BUILT IN TILES SINCE DISTANCE V5 STAGE 4, and the tiles are the world's
## rather than this region's - see Heightmap's own note and decision 4. The
## loop below walks exactly the cells the flat loop walked, in a different
## order, and every cell is a pure function of its own position, so the
## heightmap hash is identical across the change. That is Stage 4's own gate
## and it is the reason the tiling could land before the crossing did.
##
## `tile_ms` is left behind for the status doc: the plan's rule for the tile
## size is "under ~100 ms a tile", which needs the number.
func build_heightmap() -> int:
	var started := Time.get_ticks_msec()
	heightmap = Heightmap.new(config)
	tile_ms = PackedInt32Array()
	var n := heightmap.tile_count()
	var cols := heightmap.cols
	# THE CROSSING, ONE OBJECT PER WORLD, ON THE MAIN THREAD. A failure to
	# marshal is not an error: `_tiles` stays null and every tile is built in
	# GDScript, which is the path this game shipped on and hard rule 1.
	_tiles = null
	if HeightTiles.available() and not force_gdscript_tiles:
		var t := HeightTiles.new()
		if t.setup(self, config):
			_tiles = t
		else:
			push_warning("[Heightmap] the C++ tile builder would not take this world - building in GDScript")
	heightmap_builder = "c++" if _tiles != null else "gdscript"
	for tz in range(heightmap.tile_lo, heightmap.tile_hi + 1):
		for tx in range(heightmap.tile_lo, heightmap.tile_hi + 1):
			var t0 := Time.get_ticks_msec()
			var r := heightmap.tile_cell_rect(tx, tz)
			if r.size.x <= 0 or r.size.y <= 0:
				continue
			_build_tile(r)
			tile_ms.append(Time.get_ticks_msec() - t0)
	# The zones are percentiles of THIS world's altitudes, so they cannot be
	# known until the altitudes are. Everything downstream - voxels, the far
	# mesh, trees, the probe - reads them from here.
	_resolve_zone_thresholds()
	var total := Time.get_ticks_msec() - started
	if not tile_ms.is_empty():
		var sorted := tile_ms.duplicate()
		sorted.sort()
		print("[Heightmap] %d x %d tiles of %d blocks: median %d ms, worst %d ms, builder %s" % [
			n, n, heightmap.tile_blocks, sorted[sorted.size() / 2],
			sorted[sorted.size() - 1], heightmap_builder])
	return total


## One tile's cells. The whole of what a tile builder has to do, so the C++ one
## replaces exactly this function and nothing around it.
func _build_tile(r: Rect2i) -> void:
	var cols := heightmap.cols
	var bx0 := heightmap.cell_to_block(r.position.x)
	var bz0 := heightmap.cell_to_block(r.position.y)
	if _tiles != null:
		var got := _tiles.build_tile(bx0, bz0, r.size.x, r.size.y, heightmap.step)
		if got.size() == r.size.x * r.size.y:
			for j in r.size.y:
				var row := (r.position.y + j) * cols + r.position.x
				var src := j * r.size.x
				for i in r.size.x:
					heightmap.cells[row + i] = got[src + i]
			return
		# A short tile is a marshalling bug rather than a slow path, and the
		# answer to one is the reference implementation, loudly.
		push_warning("[Heightmap] the C++ tile builder returned %d of %d cells - building this tile in GDScript"
			% [got.size(), r.size.x * r.size.y])
	for j in range(r.position.y, r.position.y + r.size.y):
		var bz := float(heightmap.cell_to_block(j))
		var row := j * cols
		for i in range(r.position.x, r.position.x + r.size.x):
			var bx := float(heightmap.cell_to_block(i))
			heightmap.cells[row + i] = height_at_block(bx, bz)


## Turn the seven target shares of map area into six altitudes.
##
## THE HISTOGRAM IS OF (altitude - jitter), NOT OF ALTITUDE, and that is the
## whole trick. A cell's zone is decided by comparing its altitude against
## threshold + jitter, which is the same comparison as altitude - jitter
## against threshold. Taking the percentiles of the jittered quantity makes the
## resulting shares exact by construction instead of approximately right and
## then off by however much the jitter happened to bias them.
##
## Dither needs no such treatment: it decides which side of a boundary a cell
## falls on within the blend band, symmetrically, so it moves individual cells
## across and does not move the boundary.
##
## Buckets rather than a sort. Sorting 2.25 million floats to read six
## percentiles off them is seconds of work for an answer that is already exact
## to a sixth of a block at 2048 buckets.
func _resolve_zone_thresholds() -> void:
	var lo := config.min_altitude
	var span := maxf(config.max_altitude - lo, 0.001)

	var counts := PackedInt32Array()
	counts.resize(ZONE_HISTOGRAM_BUCKETS)
	var total := 0
	var cols := heightmap.cols
	for j in range(0, cols, ZONE_SAMPLE_STRIDE):
		var bz := float(heightmap.cell_to_block(j))
		var row := j * cols
		for i in range(0, cols, ZONE_SAMPLE_STRIDE):
			var bx := float(heightmap.cell_to_block(i))
			var v := heightmap.cells[row + i] - zone_jitter_at(bx, bz)
			var bucket := clampi(
				int((v - lo) / span * float(ZONE_HISTOGRAM_BUCKETS)),
				0, ZONE_HISTOGRAM_BUCKETS - 1)
			counts[bucket] += 1
			total += 1

	var target := config.zone_shares()
	var working := target.duplicate()
	_thresholds_from(counts, total, lo, span, working)

	# Only when something other than altitude decides a zone. With slope-aware
	# zoning off, the first pass is already exact and three more passes over
	# the map would buy nothing.
	if config.slope_zone_strength > 0.0:
		for round_index in ZONE_CORRECT_ROUNDS:
			var got := _measure_zone_shares()
			for z in ZONE_COUNT:
				working[z] = maxf(working[z] + (target[z] - got[z]), 0.0)
			_thresholds_from(counts, total, lo, span, working)


## Read six threshold altitudes off the histogram for one set of shares.
func _thresholds_from(counts: PackedInt32Array, total: int, lo: float, span: float,
		shares: PackedFloat32Array) -> void:
	zone_thresholds = PackedFloat32Array()
	zone_thresholds.resize(ZONE_COUNT - 1)

	var sum := 0.0
	for v in shares:
		sum += v
	if sum <= 0.0:
		sum = 1.0

	var cumulative := 0.0
	var seen := 0
	var bucket := 0
	var previous := lo
	for z in ZONE_COUNT - 1:
		cumulative += shares[z] / sum
		var want := int(round(cumulative * float(total)))
		# The cursor never moves backwards, so the six thresholds come out of
		# one pass over the histogram in order.
		while bucket < ZONE_HISTOGRAM_BUCKETS - 1 and seen + counts[bucket] < want:
			seen += counts[bucket]
			bucket += 1
		var altitude := lo + (float(bucket) + 0.5) / float(ZONE_HISTOGRAM_BUCKETS) * span
		# Two tiny shares can land in the same bucket. Left equal, the zone
		# between them would have zero area and the one above it would inherit
		# its colour, which reads as a zone that simply does not exist.
		zone_thresholds[z] = maxf(altitude, previous + 0.01)
		previous = zone_thresholds[z]


## What share of the map each zone ACTUALLY came out as, jitter, dither and
## slope included - which is the only way to find out, since the whole point of
## the correction rounds is that the analytic answer is no longer right.
func _measure_zone_shares() -> PackedFloat32Array:
	var counts := PackedInt32Array()
	counts.resize(ZONE_COUNT)
	var total := 0
	var cols := heightmap.cols
	for j in range(0, cols, ZONE_CORRECT_STRIDE):
		var bz := heightmap.cell_to_block(j)
		var row := j * cols
		for i in range(0, cols, ZONE_CORRECT_STRIDE):
			var bx := heightmap.cell_to_block(i)
			counts[surface_zone_at(bx, bz, heightmap.cells[row + i])] += 1
			total += 1
	var out := PackedFloat32Array()
	out.resize(ZONE_COUNT)
	for z in ZONE_COUNT:
		out[z] = float(counts[z]) / float(maxi(total, 1))
	return out


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
	# ...and how tall they are depends on how far out you are. Pillar 3 makes
	# distance the difficulty and content axis, and this is the terrain saying
	# so before anything dangerous is there to say it.
	h += _ridge(_mountain.get_noise_2d(wx, wz)) * config.mountain_amp * massif \
		* (1.0 + config.wildness_relief * wildness_at(bx, bz))

	# Rolling country, gated the same way the mountains are.
	#
	# Ungated, this layer is everywhere at uniform strength, which is even
	# bumpiness rather than landscape. The gate gives hilly districts and flat
	# districts, and the flat ones are where a campfire or a fight can happen.
	h += _hills.get_noise_2d(wx, wz) * config.hills_amp * _hills_gate(wx, wz)

	h = _flatten_valleys(h)
	h = _terrace(h)
	h = _benches_and_plateaus(h, wx, wz)
	# QUANTISED TO 1/1024 OF A BLOCK, AS THE LAST STEP. Distance v5 Stage 4,
	# decision 3, and it is hard rule zero rather than tidiness.
	#
	# Terrain is never sent over the network - both machines regenerate it from
	# a seed - so if two builds of this project round one expression differently
	# the two players walk different worlds and NEITHER MACHINE REPORTS AN
	# ERROR. Distance v4's Windows bring-up measured exactly that: gcc and MSVC
	# one float ULP apart on the same expression (docs/status/distance-v4.md,
	# the Windows addendum). It did not matter there because the far mesh is
	# look-only. It matters here, because spawn and lakes are computed from this
	# number.
	#
	# Half a quantum is 0.24 mm of world and a ULP at these altitudes is about
	# 0.00005 mm, so two compilers cannot round to different multiples of it.
	# And k/1024 is EXACTLY representable in float32 for every k a world can
	# produce, so what lands in `cells` is this value with no second rounding to
	# disagree about.
	#
	# The C++ tile builder does the same thing in the same place - one edit,
	# same commit - see scripts/world/height_tiles.gd.
	return quantise_height(clampf(h, config.min_altitude, config.max_altitude))


## Steps per block in the height map's quantisation. See height_at_block().
##
## A STATIC VAR RATHER THAN A CONST, and only so the Stage 4 ladder could be
## measured - it is a determinism contract, not a knob, and nothing in the game
## writes it. `scripts/tools/quantum_probe.gd` is the one caller.
static var HEIGHT_QUANTUM := 1024.0


## THE ONE PLACE A HEIGHT IS ROUNDED, so the two builders cannot drift.
static func quantise_height(h: float) -> float:
	if HEIGHT_QUANTUM <= 0.0:
		return h
	return round(h * HEIGHT_QUANTUM) / HEIGHT_QUANTUM


## Altitude window, as a fraction of the world's vertical range, in which each
## of the two masked layers is allowed to act.
##
## Constants rather than config, because they are what the two layers MEAN
## rather than how strong they are. A bench belongs on the middle of a slope
## and a plateau belongs high up; moving those windows turns one feature into
## the other, which is not a tuning operation.
const BENCH_ALTITUDE_BAND := Vector2(0.20, 0.60)
const PLATEAU_ALTITUDE_BAND := Vector2(0.50, 1.00)

## How much of each band is spent fading in and out at its edges, as a
## fraction. Without a fade, a bench stops at exactly one altitude across the
## whole world - which is a contour line, and contour lines are what the jitter
## and the blend elsewhere exist to destroy.
const MASKED_BAND_FADE := 0.25


## Alpine benches and high plateaux: terracing again, with a bigger riser, in
## some places only.
##
## Both are the same mechanism and that is deliberate. A bench is a wide flat
## interrupting a slope; a plateau is a very wide flat on top of one. The only
## differences are how far apart the shelves are and how high up they happen,
## so writing them as one function with two sets of numbers keeps the thing you
## have to understand down to one.
func _benches_and_plateaus(h: float, wx: float, wz: float) -> float:
	var out := h
	if config.bench_strength > 0.0:
		out = _masked_terrace(out, wx, wz, _bench_mask, config.bench_strength,
			config.bench_height, BENCH_ALTITUDE_BAND)
	if config.plateau_strength > 0.0:
		out = _masked_terrace(out, wx, wz, _plateau_mask, config.plateau_strength,
			config.plateau_height, PLATEAU_ALTITUDE_BAND)
	return out


## Blend `h` towards a terraced version of itself, by how much the mask and the
## altitude window both allow.
func _masked_terrace(h: float, wx: float, wz: float, mask: FastNoiseLite,
		strength: float, height: float, band: Vector2) -> float:
	if height <= 0.0:
		return h

	# Where in the world's vertical range this point sits.
	var t := (h - config.min_altitude) \
		/ maxf(config.max_altitude - config.min_altitude, 0.001)
	var fade := (band.y - band.x) * MASKED_BAND_FADE
	var in_band := smoothstep(band.x, band.x + fade, t) \
		* (1.0 - smoothstep(band.y - fade, band.y, t))
	if in_band <= 0.0:
		return h

	var where := _bench_placement(mask.get_noise_2d(wx, wz), wx, wz)
	var amount := clampf(strength, 0.0, 1.0) * in_band * where
	if amount <= 0.0:
		return h

	var t_shelf := h / height
	var shelf := floorf(t_shelf)
	var frac := t_shelf - shelf
	# Sharper than ordinary terracing: the point of a bench is that most of it
	# is flat and you arrive at the next one over a short rise.
	var curved: float = pow(frac, 4.0)
	var stepped := (shelf + smoothstep(0.0, 1.0, curved)) * height
	return lerpf(h, stepped, amount)


## How strongly the hills layer speaks here, 0 to 1.
##
## Deliberately the same shape as the mountain gate above rather than a second
## mechanism: one idea, applied at two scales, is a thing you can hold in your
## head, and the mountain gate had already proved the idea works.
func _hills_gate(wx: float, wz: float) -> float:
	if config.hills_gate_strength <= 0.0:
		return 1.0
	var mask := smoothstep(config.hills_mask_lo, config.hills_mask_hi,
		_hills_mask.get_noise_2d(wx, wz))
	# Blended towards 1 rather than used raw, so the knob is a dial from "no
	# gating at all" to "fully gated" instead of an on/off switch.
	return lerpf(1.0, mask, clampf(config.hills_gate_strength, 0.0, 1.0))


## Quantise height onto shelves with short risers between them.
##
## WHY THIS EXISTS AND A WAVELENGTH CANNOT REPLACE IT. fbm noise is a sum of
## smooth waves, so every point sits on some slope and the set of genuinely
## level ground has measure zero. Stretching a wavelength makes slopes gentler
## and leaves the world uniformly undulating - measured over a 12x sweep of the
## hills wavelength, the share of map under 5 degrees moved from 1.3% to 5.6%
## and then stopped. Flat ground needs a transform with a DEAD ZONE in it, and
## this is one: over most of a shelf the output does not change at all.
##
## smoothstep(pow(frac, sharpness)) rather than a hard floor(): a hard one
## makes cliffs at every riser, which is a different world from the one this is
## trying to build. Higher sharpness pushes the riser into a smaller fraction
## of the shelf, so the shelf itself gets flatter.
func _terrace(h: float) -> float:
	if config.terrace_height <= 0.0:
		return h
	var t := h / config.terrace_height
	# Types spelled out: the untyped pow() global returns Variant, and := on one
	# is a parse error under this project's warnings-as-errors.
	var shelf := floorf(t)
	var frac := t - shelf
	var curved: float = pow(frac, maxf(config.terrace_sharpness, 0.001))
	return (shelf + smoothstep(0.0, 1.0, curved)) * config.terrace_height


## Per-block roughness, in blocks. Added to the interpolated coarse height when
## voxels are built - never before lakes are decided. See the file header.
##
## FADED OUT NEAR A WATER LINE. Lakes are capped shallow to stay in scale and
## this layer is up to three blocks tall, so without the fade a sheet of water
## over rough ground breaks into a hundred disconnected islands - which is what
## the first postcard of the new terrain showed along every shoreline. At the
## water line the ground is exactly the coarse heightmap, which is the surface
## the lake's level was computed against, so the edge is clean by construction.
##
## Note this cannot move a lake. The coarse map decides where water is; this
## only decides how rough the ground is once that is settled.
##
## ALSO FADED OUT ON FLAT GROUND. The flats exist because terracing and hill
## gating carved them out of the coarse map, and a uniform +/-3 blocks of
## roughness on top of one reads as scattered single protruding blocks, not
## as ground - which is what the first walk across a Stage 9 plain showed.
## The damp keys on the COARSE map's slope, so it cannot react to the bumps
## it is itself removing, and past detail_full_deg it does nothing at all -
## a mountain face keeps every bit of its texture.
func detail_at(bx: float, bz: float) -> float:
	var d := _detail.get_noise_2d(bx, bz) * config.detail_amp
	if config.detail_flat_damp > 0.0 and heightmap != null:
		var on_slope := smoothstep(config.detail_flat_deg, config.detail_full_deg,
			heightmap.slope_deg_at(bx, bz))
		d *= lerpf(1.0, on_slope, clampf(config.detail_flat_damp, 0.0, 1.0))
	if lakes == null or config.shore_flat_blocks <= 0.0:
		return d
	var level := lakes.shore_level_at_cell(_cell_index(bx, bz))
	if is_nan(level):
		return d
	# 0 at the water line, 1 a full band away from it - so the fade covers the
	# ground just above the water AND the lake bed just below, and the shore
	# has no step in it at the point where the two meet.
	var t := clampf(absf(heightmap.height_at(bx, bz) - level)
		/ config.shore_flat_blocks, 0.0, 1.0)
	return d * t


## Coarse cell index for a block position, or -1 outside the world.
## THE RAW DETAIL FIELD, undamped, for the far mesh's own grain layer.
## Distance v5 Stage 6.
##
## `detail_at()` is the voxel surface's roughness: the same noise, damped by
## slope and faded out at a shore, and both of those are heightmap reads the far
## mesh cannot afford per cell. This is the field underneath it, so the far
## country's grain is the near country's grain and not a second invented
## texture - see far_field_job.gd's own note.
func detail_noise_at(bx: float, bz: float) -> float:
	return _detail.get_noise_2d(bx, bz)


func _cell_index(bx: float, bz: float) -> int:
	if heightmap == null:
		return -1
	var i := int(floor((bx - float(heightmap.min_block)) / float(heightmap.step)))
	var j := int(floor((bz - float(heightmap.min_block)) / float(heightmap.step)))
	if i < 0 or j < 0 or i >= heightmap.cols or j >= heightmap.cols:
		return -1
	return i + j * heightmap.cols


## How far out you are, 0 at the middle of the map and 1 at the edge.
##
## MEASURED FROM THE CENTRE OF THE WORLD, NOT FROM SPAWN, and the reason is an
## ordering one. Spawn is chosen by looking at the finished heightmap - it has
## to be, since it needs to know where the flat ground and the water are - so a
## terrain that varied with distance from spawn would need the heightmap to
## exist before itself. The two are kept interchangeable instead, by requiring
## spawn to land near the middle of the map (spawn_center_fraction).
##
## Chebyshev distance rather than Euclidean, so the ramp follows the square
## world and the corners are not a third wilder than the edges next to them.
func wildness_at(bx: float, bz: float) -> float:
	var half := float(config.world_blocks_xz) * 0.5
	if half <= 0.0:
		return 0.0
	return clampf(maxf(absf(bx), absf(bz)) / half, 0.0, 1.0)


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
	var blend := maxf(config.zone_blend_blocks, 0.001)
	var zone := ZONE_SHORE
	for i in zone_thresholds.size():
		# 0 at the bottom of the blend band, 1 at the top.
		var edge := (altitude - (zone_thresholds[i] + jitter)) / blend + 0.5
		if edge <= 0.0:
			break
		if edge >= 1.0 or dither < edge:
			zone = i + 1
		else:
			break
	return zone


## Altitude range of one zone, in blocks, before jitter.
##
## The bottom zone runs down to min_altitude and the top one up to
## max_altitude; everything between is bounded by two resolved thresholds.
func zone_band(zone: int) -> Vector2:
	var lo: float = config.min_altitude if zone <= 0 else zone_thresholds[zone - 1]
	var hi: float = config.max_altitude if zone >= zone_thresholds.size() \
		else zone_thresholds[zone]
	return Vector2(lo, hi)


## Zone of the surface at one block column.
func surface_zone_at(bx: int, bz: int, altitude: float) -> int:
	# Hashed on a coarser grid than the blocks themselves, so the interleave at
	# a zone boundary happens in patches rather than per block. See
	# zone_dither_blocks: per-block dither reads as a gradient on a hillside and
	# as confetti on a plain, and Stage 9 made a great many plains.
	var patch: int = maxi(config.zone_dither_blocks, 1)
	var zone := zone_at(
		altitude,
		zone_jitter_at(float(bx), float(bz)),
		WorldHash.hash01(Chunk.floor_div(bx, patch), Chunk.floor_div(bz, patch),
			world_seed, SALT_ZONE_DITHER))
	return _slope_zone(bx, bz, zone)


## Let the STEEPNESS of the ground override what its altitude said.
##
## Two rules, and between them they are what makes a mountain read as a
## mountain rather than as a green cone with a white hat:
##
##   SNOW DOES NOT SIT ON A CLIFF. It slides off. High ground that is steep is
##   bare rock, and the snowfields are the gentler shoulders and summit
##   plateaux - which is exactly the pattern you see on a real skyline and
##   exactly what was missing when snow was painted on near-vertical spires.
##
##   NOTHING GROWS ON SCREE. A face too steep to hold soil is rock at any
##   altitude, so a forested slope shows its crags instead of a green sheet
##   draped over them.
##
## Off by default. Both thresholds are in degrees because that is the unit the
## slope histogram is reported in, so a value here can be read straight off the
## probe rather than converted.
func _slope_zone(bx: int, bz: int, zone: int) -> int:
	if config.slope_zone_strength <= 0.0 or heightmap == null:
		return zone

	var slope := heightmap.slope_deg_at(float(bx), float(bz))

	# The strength knob is a probability rather than a blend, because a zone is
	# an integer and there is no half-way between rock and snow. Hashed from
	# the position, never drawn from a stream, so it is deterministic - and on
	# its own salt, or the same cells that dither would also be the cells that
	# turn to rock and the two patterns would visibly line up.
	var roll := WorldHash.hash01(bx, bz, world_seed, SALT_SLOPE_ZONE)
	if roll > clampf(config.slope_zone_strength, 0.0, 1.0):
		return zone

	if zone == ZONE_SNOW and slope >= config.snow_max_slope_deg:
		return ZONE_ROCK
	# Shore is left alone: a steep lake margin is still a lake margin, and
	# turning it to rock would put scree at the waterline everywhere.
	# Further out, less of a slope is needed before the soil gives up. Same
	# hook as the relief ramp, and the threshold solver absorbs whatever it
	# does to the shares.
	var rock_at := config.rock_slope_deg \
		- config.wildness_rock_deg * wildness_at(float(bx), float(bz))
	if zone > ZONE_SHORE and zone < ZONE_ROCK and slope >= rock_at:
		return ZONE_ROCK
	return zone


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
	var r := 1.0 - absf(n)
	return r * r


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
func _domain_warp(bx: float, bz: float) -> Vector2:
	# Two INDEPENDENT noise fields, one per axis. Sharing a single field
	# would offset every point along the same diagonal, which slides the
	# terrain rather than bending it - the grid alignment we are trying to
	# destroy would survive the move completely intact.
	#
	# Both are seeded at half the mountain frequency (see _build_noise), so
	# the warp varies over a longer distance than the mountains it bends.
	# Warping faster than the feature being warped shreds it instead.
	return Vector2(
		_warp_x.get_noise_2d(bx, bz) * config.warp_strength,
		_warp_z.get_noise_2d(bx, bz) * config.warp_strength)


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
	var lo := config.min_altitude
	var hi := config.max_altitude

	# Normalise into 0..1 so the exponent always means the same thing. Left
	# in raw blocks, the curve would silently change character every time
	# min_altitude or max_altitude moved.
	var t := (h - lo) / (hi - lo)

	# Defensive: the layers can sum below min_altitude, and the clamp that
	# catches that happens in the CALLER, after this runs. pow() of a
	# negative base with a fractional exponent is NaN, and a NaN here would
	# not crash - it would quietly poison one heightmap cell and every
	# chunk, lake and tree that reads it.
	t = clampf(t, 0.0, 1.0)

	# The height change is the obvious effect; the GRADIENT change is the
	# one that matters. d/dt of t^c is c * t^(c-1), so at c = 1.6 the slope
	# of low ground (t = 0.1) is multiplied by 0.40 and the slope of high
	# ground (t = 0.9) by 1.50. One exponent flattens the valley floors and
	# steepens the peaks at the same time, which is the profile erosion
	# carves - and it is why this is a curve and not two separate knobs.
	#
	# smoothstep() is the other defensible answer. It flattens the TOPS as
	# well, so summits become plateaus. Worth trying before settling.
	t = pow(t, config.valley_curve)

	return lo + t * (hi - lo)


# --- Spawn ------------------------------------------------------------------

## Where the player starts, in blocks. Found by find_spawn(), (0, 0) until then.
var spawn_block := Vector2i.ZERO

## Why the chosen spawn was chosen, and which criteria the world could not
## satisfy. Read by the probe and printed at boot.
var spawn_report := {}

## Coarse cells per tile in the summed-area tables the search uses.
const SPAWN_TILE_CELLS := 8


## Choose a spawn that satisfies the acceptance test BY CONSTRUCTION.
##
##   flat enough to stand on, not in a lake, in meadow or forest,
##   a mountain visible within spawn_mountain_m,
##   water within spawn_water_m,
##   and near the middle of the map.
##
## The naive search is unaffordable and it is worth saying why, because the
## affordable one looks like overkill until you cost the naive one. "Is there a
## mountain within 600 m" over a 300-cell radius is 280,000 cells per
## candidate, and there are tens of thousands of candidates. So the map is
## reduced to tiles of 8 cells, each carrying a count of mountain cells and a
## count of water cells, and those two grids get SUMMED-AREA TABLES - after
## which any rectangular query is four array reads whatever its size. The whole
## search then costs one pass to build the tiles and one pass over candidates.
##
## Called after lakes are computed, because it needs to know where water is.
func find_spawn() -> Vector2i:
	var cols := heightmap.cols
	var tiles := (cols + SPAWN_TILE_CELLS - 1) / SPAWN_TILE_CELLS

	# Mountain means rock or snow: the two zones you can see from a long way
	# off and read as a mountain rather than as a hill.
	var rock_altitude: float = zone_thresholds[ZONE_ROCK - 1] \
		if zone_thresholds.size() >= ZONE_ROCK else config.max_altitude

	var mountain_tiles := PackedInt32Array()
	mountain_tiles.resize(tiles * tiles)
	var water_tiles := PackedInt32Array()
	water_tiles.resize(tiles * tiles)

	for j in cols:
		var row := j * cols
		var tj := j / SPAWN_TILE_CELLS
		for i in cols:
			var t := tj * tiles + i / SPAWN_TILE_CELLS
			if heightmap.cells[row + i] >= rock_altitude:
				mountain_tiles[t] += 1
			if lakes != null and not lakes.lake_id.is_empty() \
					and lakes.lake_id[row + i] >= 0:
				water_tiles[t] += 1

	var mountain_sat := _summed_area(mountain_tiles, tiles)
	var water_sat := _summed_area(water_tiles, tiles)

	var cell_blocks := float(heightmap.step)
	var view_tiles := int(ceil(config.spawn_mountain_m / config.block_size
		/ cell_blocks / float(SPAWN_TILE_CELLS)))
	var walk_tiles := int(ceil(config.spawn_water_m / config.block_size
		/ cell_blocks / float(SPAWN_TILE_CELLS)))
	var centre_cells := int(float(cols) * 0.5 * config.spawn_center_fraction)
	var mid := cols / 2

	var best := Vector2i.ZERO
	var best_score := -INF
	var failed := {"slope": 0, "zone": 0, "water": 0, "mountain": 0, "wet": 0}
	var considered := 0

	# Every fourth cell on each axis. Finer buys nothing: the criteria are all
	# neighbourhood questions and neighbours a few metres apart answer them the
	# same way.
	for j in range(mid - centre_cells, mid + centre_cells, 4):
		if j < 1 or j >= cols - 1:
			continue
		for i in range(mid - centre_cells, mid + centre_cells, 4):
			if i < 1 or i >= cols - 1:
				continue
			considered += 1
			var idx := i + j * cols
			var bx := heightmap.cell_to_block(i)
			var bz := heightmap.cell_to_block(j)
			var altitude := heightmap.cells[idx]

			if lakes != null and not lakes.lake_id.is_empty() and lakes.lake_id[idx] >= 0:
				failed["wet"] += 1
				continue
			var slope := heightmap.slope_deg_at(float(bx), float(bz))
			if slope > config.spawn_max_slope_deg:
				failed["slope"] += 1
				continue
			var zone := surface_zone_at(bx, bz, altitude)
			if zone != ZONE_MEADOW and zone != ZONE_FOREST:
				failed["zone"] += 1
				continue
			var ti := i / SPAWN_TILE_CELLS
			var tj := j / SPAWN_TILE_CELLS
			if _sat_query(water_sat, tiles, ti, tj, walk_tiles) <= 0:
				failed["water"] += 1
				continue
			if _sat_query(mountain_sat, tiles, ti, tj, view_tiles) <= 0:
				failed["mountain"] += 1
				continue

			# Everything from here is preference rather than requirement:
			# flatter is better, nearer the middle is better, and a little
			# water close by is better than water at the limit of the walk.
			var to_centre := Vector2(float(i - mid), float(j - mid)).length()
			var near_water := float(_sat_query(water_sat, tiles, ti, tj, maxi(walk_tiles / 3, 1)))
			var score := -slope * 2.0 - to_centre * 0.05 + minf(near_water, 60.0) * 0.1
			if score > best_score:
				best_score = score
				best = Vector2i(bx, bz)

	spawn_report = {
		"ok": best_score > -INF,
		"considered": considered,
		"failed": failed,
		"slope": heightmap.slope_deg_at(float(best.x), float(best.y)),
		"altitude": heightmap.height_at(float(best.x), float(best.y)),
	}
	spawn_block = best
	return best


## Inclusive prefix sums, one row and column larger than the grid so a query
## never has to special-case the edge.
func _summed_area(grid: PackedInt32Array, n: int) -> PackedInt32Array:
	var sat := PackedInt32Array()
	sat.resize((n + 1) * (n + 1))
	for j in n:
		var row_sum := 0
		for i in n:
			row_sum += grid[i + j * n]
			sat[(i + 1) + (j + 1) * (n + 1)] = sat[(i + 1) + j * (n + 1)] + row_sum
	return sat


## Total inside the square of `radius` tiles around (ti, tj). Four reads.
func _sat_query(sat: PackedInt32Array, n: int, ti: int, tj: int, radius: int) -> int:
	var x0 := clampi(ti - radius, 0, n)
	var x1 := clampi(ti + radius + 1, 0, n)
	var z0 := clampi(tj - radius, 0, n)
	var z1 := clampi(tj + radius + 1, 0, n)
	var w := n + 1
	return sat[x1 + z1 * w] - sat[x0 + z1 * w] - sat[x1 + z0 * w] + sat[x0 + z0 * w]


## Normalised danger, 0 at spawn and 1 at the furthest corner of the world.
##
## NOTHING CONSUMES THIS YET, and that is deliberate. The first enemy is Plan B
## territory, but Pillar 3 makes distance the difficulty and content axis and
## this is the hook it will hang on - so it exists now, with the terrain
## already agreeing with it, rather than being retrofitted later against a
## world that was built without it in mind.
func danger_at(bx: float, bz: float) -> float:
	var half := float(config.world_blocks_xz) * 0.5
	var furthest := Vector2(half, half).distance_to(Vector2(spawn_block))
	if furthest <= 0.0:
		return 0.0
	return clampf(Vector2(bx, bz).distance_to(Vector2(spawn_block)) / furthest, 0.0, 1.0)


# --- Voxels -----------------------------------------------------------------

## Fill a chunk with blocks, one column at a time.
##
## Column by column rather than the mesher's linear order because the surface
## altitude is a property of the COLUMN: computing it once and then walking
## down costs one heightmap lookup and one noise sample per column, instead of
## one per voxel. At 16 blocks tall that is a 16x saving on the hot path.
## Voxels AND the trees that reach into them. The whole of a chunk.
##
## SPLIT IN WORLD FEEL V1 STAGE 2. The ground and the trees are separate calls
## now, because a ColumnJob generates every chunk of a column and then stamps
## the column's trees ONCE across all of them - where this path stamps each
## chunk separately and re-runs the candidate scan every time. This entry point
## stays for the edit path, the far-field probes and the self-tests, which all
## want one chunk in isolation and are not on the streaming budget.
func generate_into(chunk: Chunk) -> void:
	generate_ground_into(chunk)
	_place_trees(chunk)


## The ground only: everything a chunk is before anything grows on it.
func generate_ground_into(chunk: Chunk) -> void:
	var origin := chunk.origin()

	# MOST CHUNKS ARE SOLID ROCK. A column is built from the tree tops down to
	# voxel_depth_chunks below the ground, so of its five or six chunks one or
	# two cross the surface and the rest are buried. The range is the same
	# bound World queued the column from, and its low end is a true minimum of
	# the surface over the footprint (the coarse samples sit on the cell
	# corners, and bilinear never leaves the corners' range) less the most the
	# detail layer can subtract - so a chunk whose top is SOIL_DEPTH below it
	# would have come out of the loop below as stone in every voxel. Trees
	# cannot reach it either: a trunk stands on its own column, which is inside
	# the footprint or not in this chunk, and a canopy only ever writes over air.
	var span := column_surface_range(chunk.chunk_pos.x, chunk.chunk_pos.z)
	if span.x >= float(origin.y + Chunk.SIZE - 1 + SOIL_DEPTH):
		chunk.voxels.fill(Block.STONE)
		chunk.has_air = false
		chunk.has_solid = true
		chunk.dirty = true
		return

	var has_air := false
	var has_solid := false
	var voxels := chunk.voxels

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
			# block_for() is a function of depth in three bands, so ask it once
			# per band per column rather than once per voxel. On a worker thread
			# that GDScript can only run one of at a time, 4096 calls a chunk
			# was a third of the whole generation cost.
			var turf := block_for(0, zone)
			var soil := block_for(SURFACE_DEPTH, zone)
			var column := Chunk.index(lx, 0, lz)

			for ly in Chunk.SIZE:
				var by := origin.y + ly
				var id := Block.AIR
				if by <= top:
					var depth := top - by
					if depth < SURFACE_DEPTH:
						id = turf
					elif depth < SOIL_DEPTH:
						id = soil
					else:
						id = Block.STONE
					has_solid = true
				else:
					has_air = true
				voxels[column + ly * Chunk.SIZE_SQ] = id

	chunk.has_air = has_air
	chunk.has_solid = has_solid
	chunk.dirty = true


# --- Trees ------------------------------------------------------------------
#
# THE TREES THEMSELVES MOVED OUT IN FOLIAGE V1 STAGE 2. Shapes now live in
# scripts/world/flora/tree_species.gd and the placement decision in
# tree_placement.gd, including the chunk-border argument that used to be
# written out here - a tree reaches into chunks that do not contain its trunk,
# so every chunk scans a region wider than itself and clips.
#
# What is left below is the one question the rest of the engine asks about
# trees and cannot get anywhere else - how much sky to reserve above the
# terrain - and the hook that draws them.
#
# tree_probability_at() went with the rest in Stage 4. It was "the chance in
# the middle of the forest band", and there is no such single number any more:
# the probability is a product of six terms across five zones, and anything
# that wants to know whether a tree stands somewhere asks TreePlacement.

## How far above the surface a tree can reach, in blocks. World uses this to
## decide how much empty sky above the terrain still has to be built - without
## it, a tree on a column near the top of a chunk would have its canopy
## silently cut off by a chunk that was never queued.
##
## DERIVED FROM THE SPECIES TABLE since foliage v1 Stage 2, not from a pair of
## config knobs. There are seven species now and they are not all the same
## height; a reserve computed from the spruce's numbers would quietly decapitate
## every larch in the world, and the symptom - a flat-topped tree, but only
## sometimes, and only near a chunk ceiling - is a miserable thing to find.
func max_tree_height() -> int:
	return TreeSpecies.max_height(config)


func _place_trees(chunk: Chunk) -> void:
	# TREES V3 STAGE 7: NOTHING STAMPS A TREE INTO A CHUNK ANY MORE.
	#
	# `TreePlacement.stamp_chunk()` used to run here, drawing every candidate
	# whose crown reached this chunk. Trees are a model library instanced by
	# `TreeField` now (ruling 5), so a generated chunk is terrain and nothing
	# else - which is what this function's own name always claimed.
	pass


## The three depth bands block_for() answers in. Named so generate_into() can
## sample the rule at its boundaries instead of restating it.
##
## TWO blocks of surface, not one.
##
## The detail layer puts a one-block step every few blocks, and with a
## single-block skin every one of those steps exposes the soil beneath it.
## On screen that is a haze of dark brown flecks over every hillside -
## clearly visible in the first screenshot tour, and confirmed as soil
## rather than tree trunks by re-shooting the same seed with trees off.
## A second block of turf covers the one-block risers and leaves soil
## showing only where the ground is genuinely steep, which is where you
## want to see it.
const SURFACE_DEPTH := 2

## Soil reaches this deep; from here down it is stone in every zone.
const SOIL_DEPTH := 5


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
	if depth < SURFACE_DEPTH:
		return ZONE_SURFACE[zone]
	# Everything up to and including heath grows on soil; rock and snow are
	# stone all the way down. A cliff face in the bare-rock zone with a brown
	# stripe three blocks below its top reads as wrong from a long way off.
	if zone <= ZONE_HEATH and depth < SOIL_DEPTH:
		return Block.DIRT
	return Block.STONE


## TODO(marcel): benches are in the wrong places.
##
## This decides where a bench or a plateau is allowed to happen, from a
## low-frequency noise mask. Noise is a fine way to pick DISTRICTS and a poor
## way to pick a bench, because a bench is not a random location - it is a
## place where a slope happens to ease off, and the terrain already knows where
## those are.
##
## The result today is benches that sometimes cut across a slope that was
## perfectly steep either side of them, which reads as a shelf that was put
## there rather than one that grew there.
##
##   Hint: heightmap.slope_deg_at(wx, wz) is the local steepness in degrees,
##   and it is already used by the zone code. Something like
##
##       var eased := 1.0 - smoothstep(12.0, 30.0, heightmap.slope_deg_at(wx, wz))
##       return smoothstep(0.1, 0.55, mask_value) * eased
##
##   keeps the mask as a "which districts have benches at all" filter and lets
##   the terrain choose where within them. Watch the mountain shoulders.
##
##   Careful, and this is the interesting part: flattening the ground CHANGES
##   its slope, so a rule that reads the slope it is about to change can chase
##   its own tail. It does not here, because slope_deg_at reads the coarse
##   heightmap and this runs while that heightmap is still being built - so it
##   sees the cell's neighbours from the array, which are zero until they are
##   written. Decide whether that is a bug or a feature before relying on it.
##
## Fallback: the mask alone, which gives benches in plausible districts at
## implausible spots.
func _bench_placement(mask_value: float, _wx: float, _wz: float) -> float:
	# Only the upper half of the mask's range, so these are occasional rather
	# than the default state of the world.
	return smoothstep(0.1, 0.55, mask_value)
