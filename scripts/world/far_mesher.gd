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
	if _impl == null:
		_impl = ClassDB.instantiate(CLASS_NAME)
	_impl.setup(_world_data(heightmap, generator, config))
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
		"levels": heightmap.pyramid_levels(),
		"max_levels": heightmap.pyramid_max_levels(),
		"level_cols": heightmap.pyramid_level_cols(),
		"max_level": Heightmap.MAX_LEVEL,
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
	"far_filter_bias", "far_peak_gain", "far_level_ref_m", "far_normal_m",
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
	var out: Dictionary = _impl.build({
		"center_x": center.x,
		"center_z": center.y,
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
	})
	arrays = out.get("arrays", [])
	slices = out.get("slices", [])
	vertex_count = int(out.get("vertex_count", 0))
	elapsed_ms = int(out.get("elapsed_ms", 0))
	return true


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
