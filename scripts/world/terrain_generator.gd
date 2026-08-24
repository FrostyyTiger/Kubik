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
const SALT_TREE_TRUNK := 203
const SALT_TREE_CANOPY := 204
const SALT_SLOPE_ZONE := 205

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
	# The zones are percentiles of THIS world's altitudes, so they cannot be
	# known until the altitudes are. Everything downstream - voxels, the far
	# mesh, trees, the probe - reads them from here.
	_resolve_zone_thresholds()
	return Time.get_ticks_msec() - started


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
	return clampf(h, config.min_altitude, config.max_altitude)


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

	# Only the upper half of the mask's range, so these are occasional rather
	# than the default state of the world.
	var where := smoothstep(0.1, 0.55, mask.get_noise_2d(wx, wz))
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
func detail_at(bx: float, bz: float) -> float:
	var d := _detail.get_noise_2d(bx, bz) * config.detail_amp
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
	# The forest band is wherever Stage 7 put it this world, not a pair of
	# altitudes in the config. Without this the treeline and the forest FLOOR
	# would be two different bands, and trees would grow on grass.
	var band := zone_band(ZONE_FOREST)
	var lo := band.x + jitter
	var hi := band.y + jitter
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
	# Everything up to and including heath grows on soil; rock and snow are
	# stone all the way down. A cliff face in the bare-rock zone with a brown
	# stripe three blocks below its top reads as wrong from a long way off.
	if zone <= ZONE_HEATH and depth < 5:
		return Block.DIRT
	return Block.STONE
