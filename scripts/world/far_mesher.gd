class_name FarMesher
extends RefCounted

## The C++ far mesher, and the seam it crosses. Distance v4.
##
## WHAT THIS FILE IS. `FarFieldJob` is the far mesh, written in GDScript, and
## it stays that way - it is the REFERENCE implementation, not the casualty
## (decision 1). This is the other half: it hands the C++ class everything it
## needs as plain arrays, asks it for a mesh, and presents the answer with the
## same three members `FarFieldJob` exposes - `arrays`, `vertex_count`,
## `elapsed_ms` - so `far_field.gd` can swap one for the other and nothing
## downstream can tell which built the mesh.
##
## THE BOUNDARY IS DATA IN, ARRAYS OUT (decision 2). The C++ class never holds a
## reference to `Heightmap`, `TerrainGenerator`, `WorldgenConfig` or `Look`, and
## never calls back into GDScript during a build. `setup()` hands over the
## heightmap pyramid, the zone tables and the world constants ONCE per world;
## `build()` hands over the centre, the frontier and the live far knobs. A
## cross-language call per cell is how a 30x speedup becomes 1.5x, and
## forbidding it at the seam is cheaper than measuring it out later.
##
## THE TWO NOISE OBJECTS ARE THE EXCEPTION, AND THEY ARE NOT A CALLBACK.
## `TerrainGenerator.detail_at()` and `zone_jitter_at()` are FastNoiseLite
## samples, and FastNoiseLite is an ENGINE class: the C++ mesher holds the very
## same `Ref<FastNoiseLite>` the generator built and calls `get_noise_2d` on it
## natively. No GDScript frame is entered, and - the reason this is the right
## answer rather than merely a permitted one - the noise is then bit-identical
## by construction rather than by a reimplementation somebody has to keep in
## step. Both are confined to ring 0's seam band, which is a few hundred quads.
##
## THE GAME RUNS WITHOUT ANY OF THIS. `available()` is false on a checkout with
## no compiled library, and `far_field.gd` builds through `FarFieldJob` exactly
## as it has since terrain v1. Hard rule 1.

## The class the GDExtension registers. Named once, here.
const CLASS_NAME := "KubikFarMesher"


## Is the compiled library present and far enough along to be handed a world?
##
## Stage 0 shipped a class with nothing but `ping()` on it, so the class name
## alone proves nothing - each of the three questions below asks for the method
## that the caller is actually about to use.
static func class_present() -> bool:
	return ClassDB.class_exists(CLASS_NAME) \
		and ClassDB.class_has_method(CLASS_NAME, "setup")


## Can it build a whole mesh? This is the one the dispatch asks.
static func available() -> bool:
	return class_present() and ClassDB.class_has_method(CLASS_NAME, "build")


## Whether the C++ mesher paints as well as it shapes. False through Stage 3,
## where it emits positions and normals and leaves every colour white - which
## is exactly what the parity harness needs to be told, so it compares the
## rows that are meant to match and no others.
static func colors_ready() -> bool:
	if not available():
		return false
	return ClassDB.class_has_method(CLASS_NAME, "has_colors") \
		and _probe().has_colors()


static func _probe() -> Object:
	return ClassDB.instantiate(CLASS_NAME)


# --- One instance per world, owned by FarField -------------------------------

var _impl: Object = null

## The same three members FarFieldJob presents, and for the same readers.
var arrays: Array = []
var vertex_count := 0
var elapsed_ms := 0

## What setup() marshalled, kept so a rebuild does not re-marshal a pyramid
## that has not moved.
var _ready := false


## Hand the world over, once. False if the library is absent or the world is
## not far enough along to be described - the caller then keeps GDScript.
func setup(heightmap: Heightmap, generator: TerrainGenerator,
		config: WorldgenConfig) -> bool:
	_ready = false
	if not class_present() or heightmap == null or generator == null \
			or config == null:
		return false
	# THE PYRAMID IS BUILT ON THE CALLER'S THREAD, and that is a change of
	# WHERE rather than of what: FarFieldJob.run() builds it on the worker
	# inside its own elapsed_ms. Here it has to exist before it can be
	# marshalled, and it is idempotent and behind a mutex either way.
	heightmap.build_pyramid()
	# WITH THE WORLD. See `_sent_tiles`: the C++ side empties its tile map in
	# setup(), so this has to empty with it.
	_sent_tiles.clear()
	if _impl == null:
		_impl = ClassDB.instantiate(CLASS_NAME)
	# THE TILES THE STORE ALREADY HAS, with the world. The rim is prepared at
	# load (`Heightmap.ensure_region_rim`), so a mesher set up before any far
	# build has run - the self-test's parity harness, the far probe - starts
	# with the same ground the GDScript leg reads rather than with an empty map
	# and the region's clamped edge.
	var data := _world_data(heightmap, generator, config)
	# THE PARAMETER, NOT THE MEMBER. `setup`'s first argument shadows the
	# `heightmap` member, and the member is not assigned until `far_field.gd`
	# submits a build - so a `_new_tiles()` that read the member would send
	# nothing here and the C++ leg would start a world with an empty tile map
	# while the GDScript leg read the rim tiles. That is exactly what the far
	# parity gate reported: 391,840 vertices against 391,640.
	data["tiles"] = _new_tiles(heightmap)
	_impl.setup(data)
	# THE MESHER SAYS WHETHER IT GOT A WORLD IT CAN USE. `bilinear()` indexes
	# the pyramid without a bounds check tens of millions of times a build, so
	# a short marshal is a crash rather than a wrong mesh - and the answer to
	# one is to keep GDScript, not to try.
	_ready = _impl.is_ready()
	return _ready


## Everything the mesher needs that does not change while a world is loaded.
static func _world_data(heightmap: Heightmap, generator: TerrainGenerator,
		config: WorldgenConfig) -> Dictionary:
	return {
		# The heightmap, level 0 and the two pyramids above it.
		"cells": heightmap.cells,
		"cols": heightmap.cols,
		"hm_step": heightmap.step,
		"min_block": heightmap.min_block,
		# THE TILE STORE'S GEOMETRY. The tiles themselves are marshalled
		# incrementally by `build()`, not here: at setup nothing is prepared
		# yet, and a world that sent every tile it might ever need would send
		# an unbounded number of them.
		"tile_blocks": heightmap.tile_blocks,
		"levels": heightmap.pyramid_levels(),
		"max_levels": heightmap.pyramid_max_levels(),
		"level_cols": heightmap.pyramid_level_cols(),
		"max_level": Heightmap.MAX_LEVEL,
		# THE MATERIAL PYRAMID, horizon v1 Stage 4. Level 0 over the region
		# grid and levels 1..MAX_LEVEL above it, one byte per cell. Data, sent
		# whole once per world - so the two legs paint from the same bytes and
		# there is no second rule here to disagree with the first.
		"materials": heightmap.pyramid_materials(),
		"material_levels": heightmap.pyramid_material_levels(),
		# And the forest cover beside it - coarser, one grid, no pyramid.
		"cover": heightmap.pyramid_cover(),
		"cover_cols": heightmap.cover_cols_for(heightmap.cols),
		"canopy_color": FarFieldJob.canopy_color(),
		# The generator's zone tables. Thresholds are resolved once at world
		# load from a histogram, so they are data by the time anyone asks.
		"zone_thresholds": generator.zone_thresholds,
		"world_seed": generator.world_seed,
		# The two noise objects - see the header. Engine objects, sampled
		# natively, never a GDScript call.
		"detail_noise": generator._detail,
		"jitter_noise": generator._jitter,
		# The lakes' shore fade, as the two arrays detail_at() actually reads.
		"shore_near": generator.lakes.shore_near if generator.lakes != null \
			else PackedByteArray(),
		"shore_level": generator.lakes.shore_level if generator.lakes != null \
			else PackedFloat32Array(),
		# The surface block colour of each zone, in LINEAR - so the mesher
		# never has to know what a Block is.
		"zone_colors": _zone_colors(),
		"config": _config_data(config),
	}


## Block.color_of(ZONE_SURFACE[zone]) for every zone, as a table.
static func _zone_colors() -> PackedColorArray:
	var out := PackedColorArray()
	for zone in TerrainGenerator.ZONE_COUNT:
		out.append(Block.color_of(TerrainGenerator.ZONE_SURFACE[zone]))
	return out


## Every config scalar the far mesher reads, by name.
##
## A Dictionary rather than a hand-written struct because the list is long, it
## moves every epic, and a name that is missing is then a lookup that returns
## the default rather than a silent zero. The C++ side names each one once.
static func config_data(config: WorldgenConfig) -> Dictionary:
	return _config_data(config)


static func _config_data(config: WorldgenConfig) -> Dictionary:
	var out := {}
	for key in CONFIG_KEYS:
		out[key] = float(config.get(key))
	return out


## THE FAR MESHER'S WHOLE READ OF THE CONFIG. Checked against far_field_job.gd
## by grep, not by memory: every `config.<name>` in that file, plus the ones
## its callees (`detail_at`, `zone_at`, `_slope_zone`, `wildness_at`) read on
## its behalf. The paint knobs - far_band_m, far_band_step, the three
## far_riser_*, slope_tint, aspect_tint and the color_jitter_* trio - left this
## list with the code that read them in light v1 Stage 3.
const CONFIG_KEYS: PackedStringArray = [
	"block_size", "world_blocks_xz", "coarse_step", "far_step",
	"voxel_radius_chunks", "fog_end_m",
	"far_terrace", "far_step_y_blocks", "far_ring_div", "far_vote",
	"far_filter_bias", "far_peak_gain", "far_forest_blend",
	"far_level_ref_m", "far_normal_m",
	"far_zone_cell_m", "far_zone_cell_ratio",
	# DISTANCE V5 STAGES 3 AND 6.
	"far_geomorph_cells", "far_detail",
	"detail_amp", "detail_freq", "detail_flat_damp", "detail_flat_deg",
	"detail_full_deg", "shore_flat_blocks",
	"zone_blend_blocks", "zone_dither_blocks", "zone_jitter_blocks",
	"slope_zone_strength", "snow_max_slope_deg", "rock_slope_deg",
	"wildness_rock_deg", "min_altitude", "max_altitude",
	
	
]


# --- The job face ------------------------------------------------------------
#
# FarFieldJob's members, by the same names, so `far_field.gd` submits either one
# to the worker pool through the same three lines. `heightmap` and `generator`
# are here for the shape of it and are read only by setup(); the mesher itself
# never holds them past that call - decision 2.

var heightmap: Heightmap = null
var generator: TerrainGenerator = null
var config: WorldgenConfig = null
var center := Vector2i.ZERO
var frontier := PackedInt32Array()

## FarFieldJob's two, by the same names. Distance v5 Stage 1, decision 1: see
## far_field_job.gd's `slice` for what they mean and why the union cannot move.
var slice := false
var slices: Array = []

## FarFieldJob's, by the same names - see its `keys` and `key_anchors`.
var keys := PackedInt32Array()
var key_anchors: PackedVector3Array = PackedVector3Array()


## What FarField submits to the worker pool. The whole build is one call into
## C++, so this GDScript frame exists for the length of that call and no cell
## is ever meshed from it.
func run() -> void:
	build(config, center, frontier, slice)


## Build one far mesh. The same three arguments FarFieldJob takes as members,
## plus the knobs that can move between builds.
##
## `overlap_cells` is FarFieldJob.FRONTIER_OVERLAP_CELLS, passed rather than
## re-derived: it is a static the main thread writes and both meshers must cut
## their hole with the SAME number, or the stream probe's hole count is fiction
## (world.gd's far_field_exclusion_m says so in as many words).
func build(config: WorldgenConfig, center: Vector2i,
		frontier: PackedInt32Array, slice := false) -> bool:
	arrays = []
	slices = []
	vertex_count = 0
	elapsed_ms = 0
	if not _ready:
		return false
	var args := {
		"center_x": center.x,
		"center_z": center.y,
		# ONLY THE TILES THIS MESHER HAS NOT SEEN. See `_sent_tiles`.
		"tiles": _new_tiles(heightmap),
		# THE (RING, SECTOR) KEYS THIS BUILD IS FOR - far_field_job.gd's own
		# `keys`. Empty is the whole disc, which is what the probe and the
		# parity harness ask for.
		"keys": keys,
		"frontier": frontier,
		"overlap_cells": FarFieldJob.FRONTIER_OVERLAP_CELLS,
		# ONE SET OF ARRAYS PER SECTOR INSTEAD OF ONE FOR THE WHOLE DISC.
		# Off for the probe, the parity harness and the self-test, which want
		# the mesh this project has always emitted; on for the runtime path,
		# which uploads it a slice at a time.
		"slice": slice,
		# Re-read every build for the reason FarFieldJob re-reads them every
		# run: they are knobs on a shared config the main thread can write
		# while a worker builds, and a value that changed half way through
		# would terrace half a mesh.
		"config": _config_data(config),
	}
	# AND EVERY KEY THE PUBLISHED VIEW HOLDS, so the other side can drop what
	# has been evicted - horizon v1 Stage 4. See `_view_keys`.
	#
	# THE KEY IS ABSENT WHEN THERE IS NO HEIGHTMAP TO ASK, and that is the
	# whole reason it is added here rather than in the literal. The member is
	# assigned by the caller and some callers do not -
	# `scripts/tools/selftest.gd` builds a mesher for its parity cases and this
	# lane may not edit that file. Absent means "no statement about the view";
	# an EMPTY array would mean "the view is empty" and would drop every tile
	# the mesher was set up with.
	if heightmap != null:
		args["tile_keep"] = _view_keys(heightmap)
	var out: Dictionary = _impl.build(args)
	arrays = out.get("arrays", [])
	slices = out.get("slices", [])
	key_anchors = out.get("anchors", PackedVector3Array())
	vertex_count = int(out.get("vertex_count", 0))
	elapsed_ms = int(out.get("elapsed_ms", 0))
	return true


# --- THE TILE MARSHAL, horizon v1 Stage 1 ------------------------------------
#
# MARSHAL ONCE PER TILE. Decision 2 is "data in, arrays out, marshalled once
# per world", and the tile store is the first thing in this seam that a world
# does not have all of at load: tiles are built on demand as the player and the
# far view ask for ground, so "once per world" becomes "once per tile" and the
# rule it was protecting - never re-send what the other side already holds - is
# unchanged.
#
# WHAT THAT COSTS IF IT IS WRONG. A tile is 129 x 129 x 4 bytes twice, 133 KB.
# Re-sending the whole store every build would be tens of megabytes across the
# seam per rebuild, which is the cost the "once per world" rule exists to
# avoid; forgetting to send one is a far mesh that reads the region's rim
# there, which looks like the world before tonight rather than like a bug.
# Hence the set below is kept by KEY and the C++ side stores by the same key.
#
# CLEARED WITH THE WORLD. `setup()` is called once per world and the C++ side
# empties its own map there, so this must empty with it or the second world of
# a session would be missing every tile the first one had sent.

## Every tile key already across the seam.
var _sent_tiles := {}

## The flat wire form of everything the store holds that has not been sent:
## `[level, tx, tz, mean, high, ...]`. Empty when there is nothing new, which
## is most builds.
## Takes the heightmap EXPLICITLY. `setup`'s parameter shadows the member of
## the same name and the member is null until a build is submitted, so a
## caller that let this reach for the member would silently send nothing.
## THE PUBLISHED VIEW'S WHOLE KEY SET, flat, as (level, tx, tz) triples.
##
## WHY THE OTHER SIDE NEEDS IT, and it is a bug this stage found rather than a
## feature. Tiles are sent INCREMENTALLY - `_sent_tiles` makes sure a tile
## crosses the seam once - and nothing ever told the C++ side about an
## EVICTION. So the two legs drifted apart the moment the store evicted
## anything: the GDScript leg read the published view and fell back to the
## region's rim for a tile that was gone, and the C++ leg still had it and
## answered from the tile. Both answers are correct ground; they are not the
## same answer, and two legs that disagree are the one thing this seam may not
## do.
##
## It surfaced as a colour, not as a height: Stage 4's colour handover found
## seven thousand rock and snow quads at the summit vantage painted a colour
## that was not their palette's, because the material the mesher looked up and
## the material this probe looked up came from different tile sets.
##
## The published view is the contract, so it is sent whole. Three ints per
## tile, a couple of hundred tiles: a few kilobytes against a mesh of two
## million vertices.
func _view_keys(hm: Heightmap) -> PackedInt32Array:
	var out := PackedInt32Array()
	if hm == null:
		return out
	for key in hm.far_view_keys():
		var k: Vector3i = key
		out.push_back(k.x)
		out.push_back(k.y)
		out.push_back(k.z)
	return out


func _new_tiles(hm: Heightmap) -> Array:
	if hm == null:
		return []
	var out := []
	var keys := hm.far_view_keys()
	# AND FORGET WHAT IS NO LONGER PUBLISHED. Without this a tile that was
	# evicted and then built again would never cross the seam a second time -
	# `_sent_tiles` would still say it had - and the C++ side, which prunes to
	# the published view on every build, would answer the region's rim there
	# while this side answered the tile.
	#
	# UNCONDITIONALLY, and the first spelling's `if size > size` guard is the
	# bug this comment exists for: a view that evicts two tiles and gains two
	# has the same size and a different set, which is exactly what a probe
	# walking twenty summits does. It cost two runs of the colour handover -
	# eight hundred rock quads at the summit vantage painted from a tile one
	# leg had and the other did not.
	var live := {}
	for key in keys:
		live[key] = true
	for key in _sent_tiles.keys():
		if not live.has(key):
			_sent_tiles.erase(key)
	for key in keys:
		if _sent_tiles.has(key):
			continue
		var arrays := hm.far_view_arrays(key)
		if arrays.is_empty():
			continue
		var k: Vector3i = key
		out.append(k.x)
		out.append(k.y)
		out.append(k.z)
		out.append(arrays[0])
		out.append(arrays[1])
		out.append(arrays[2])
		out.append(arrays[3])
		_sent_tiles[key] = true
	return out


# --- Stage 2's micro-gate ----------------------------------------------------
#
# The pyramid, one expression at a time. A whole-mesh diff tells you the two
# meshers disagree and never WHERE, and "where" is the only thing a port needs
# from a failing gate - so each ported expression is also reachable on its own
# and the self-test puts ten thousand random triples through both.

func h_at(bx: float, bz: float) -> float:
	return _impl.h_at(bx, bz)


func h_filtered(bx: float, bz: float, level: float) -> float:
	return _impl.h_filtered(bx, bz, level)


func h_max_filtered(bx: float, bz: float, level: float) -> float:
	return _impl.h_max_filtered(bx, bz, level)


## FarFieldJob.filtered_height: the pyramid read, pulled towards the maxima by
## far_peak_gain.
func h_peak(bx: float, bz: float, level: float) -> float:
	return _impl.h_peak(bx, bz, level)


func h_slope_deg(bx: float, bz: float) -> float:
	return _impl.h_slope_deg(bx, bz)


# --- Stage 4's micro-gates ---------------------------------------------------
#
# The zone rules and the colour path, one expression at a time. Decision 4 asks
# for a 10,000-sample gate per function before the whole-mesh comparison goes
# colour-inclusive, and these are what it runs against.

func z_backdrop(bx: int, bz: int, altitude: float) -> int:
	return _impl.z_backdrop(bx, bz, altitude)


func z_surface(bx: int, bz: int, altitude: float) -> int:
	return _impl.z_surface(bx, bz, altitude)


# c_treeline_band, c_band_m_at, c_band_color and c_aspect_shade left with the
# paint in light v1 Stage 3 (Q15). One expression is all that remains.


## The whole per-vertex tail of _push_quad, which is now Look.to_wire alone.
func c_vertex(color: Color, normal: Vector3, point: Vector3) -> Color:
	return _impl.c_vertex(color, normal, point)
