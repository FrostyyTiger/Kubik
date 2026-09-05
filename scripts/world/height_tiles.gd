class_name HeightTiles
extends RefCounted

## The C++ height-map tile builder, and the seam it crosses. Distance v5 Stage 4.
##
## Sibling of `far_mesher.gd` and deliberately the same shape - `available()`,
## `setup()` once per world, data in and arrays out, and a GDScript
## implementation that stays in the tree as the reference. What is different is
## the stakes, and it is worth saying at the top:
##
## **THE FAR MESH IS LOOK-ONLY AND THIS IS NOT.** Distance v4's doctrine is that
## the C++ mesher may be trusted because the worst a disagreement can do is draw
## a slightly different mountain. The height map decides where the ground IS -
## `world.gd` computes lakes and spawn from it, every voxel column reads it, and
## terrain is never sent over the network because both machines regenerate it
## from a seed. So a one-ULP disagreement here is two players in different
## worlds with NEITHER MACHINE REPORTING AN ERROR, which is the failure
## `Heightmap.hash_key()` has existed to catch since terrain v1.
##
## HENCE DECISION 3'S QUANTISATION, which is the reason this crossing is safe
## and the reason it could be attempted at all. Distance v4's Windows bring-up
## measured gcc and MSVC rounding the same expression one float ULP apart. Both
## builders therefore round every height they emit to **1/1024 of a block** as
## the last step - `TerrainGenerator.HEIGHT_QUANTUM`, the same constant, applied
## in the same place. Half a quantum is 0.24 mm of world and a ULP at these
## altitudes is about 0.00005 mm, so two compilers cannot round to different
## multiples; and k/1024 for any k a world can produce is exactly representable
## in float32, so the value stored in `cells` is the quantised value with no
## second rounding to disagree about.
##
## THE GAME RUNS WITHOUT ANY OF THIS. `available()` is false on a checkout with
## no compiled library and `TerrainGenerator` builds every tile in GDScript,
## which is hard rule 1 - and hard rule 1 is why the quantisation is applied on
## BOTH legs rather than only on the crossing: a library-less checkout and a
## compiled one have to agree, or hard rule zero fails between two machines of
## the same project.

const CLASS_NAME := "KubikHeightTiles"


static func class_present() -> bool:
	return ClassDB.class_exists(CLASS_NAME) \
		and ClassDB.class_has_method(CLASS_NAME, "build_tile")


static func available() -> bool:
	return class_present()


var _impl: Object = null
var _ready := false


## Hand over the eight noise fields and the config, once per world.
##
## The noise objects are the generator's OWN - engine `FastNoiseLite` refs,
## sampled natively on the other side of the seam. No GDScript frame is entered
## during a build, and the noise is bit-identical BY CONSTRUCTION rather than by
## a reimplementation somebody has to keep in step with the engine's.
func setup(generator: TerrainGenerator, config: WorldgenConfig) -> bool:
	_ready = false
	if not class_present() or generator == null or config == null:
		return false
	if _impl == null:
		_impl = ClassDB.instantiate(CLASS_NAME)
	_impl.setup({
		"continent": generator._continent,
		"mountain": generator._mountain,
		"hills": generator._hills,
		"warp_x": generator._warp_x,
		"warp_z": generator._warp_z,
		"hills_mask": generator._hills_mask,
		"bench_mask": generator._bench_mask,
		"plateau_mask": generator._plateau_mask,
		"config": _config_data(config),
	})
	_ready = _impl.is_ready()
	return _ready


## Every config scalar `height_at_block` and its four callees read, by name.
## Checked against `terrain_generator.gd` by grep rather than by memory.
const CONFIG_KEYS: PackedStringArray = [
	"base_altitude", "continent_amp", "mountain_freq", "mountain_amp",
	"mountain_mask_lo", "mountain_mask_hi",
	"hills_amp", "hills_gate_strength", "hills_mask_lo", "hills_mask_hi",
	"wildness_relief", "warp_strength", "valley_curve",
	"terrace_height", "terrace_sharpness",
	"bench_strength", "bench_height", "plateau_strength", "plateau_height",
	"min_altitude", "max_altitude", "world_blocks_xz",
]


static func _config_data(config: WorldgenConfig) -> Dictionary:
	var out := {}
	for key in CONFIG_KEYS:
		out[key] = float(config.get(key))
	return out


## One tile's heights, row-major, `cols` x `rows` cells from block
## (`bx0`, `bz0`) at `step` blocks apart. Empty if the builder is not ready.
func build_tile(bx0: int, bz0: int, cols: int, rows: int,
		step: int) -> PackedFloat32Array:
	if not _ready:
		return PackedFloat32Array()
	return _impl.build_tile({
		"bx0": bx0, "bz0": bz0, "cols": cols, "rows": rows, "step": step,
	})


## One cell, for the micro-gate. A whole-tile diff says the two builders
## disagree and never where.
func height_at_block(bx: float, bz: float) -> float:
	return _impl.height_at_block(bx, bz)


# --- THE MATERIAL PYRAMID'S LEVEL 0, horizon v1 Stage 4 -----------------------
#
# A SECOND SETUP, AND IT IS DELIBERATELY SEPARATE FROM THE FIRST. The heights
# are world truth and are built the moment the world is; the zone thresholds are
# percentiles of those heights and do not exist until afterwards. So the tile
# builder learns to answer heights at `setup()` and learns to answer materials
# at `setup_zones()`, one phase later, and `zones_ready()` is how the store
# knows which of the two it may ask for.
#
# THE ZONE RULES ARE NOT REIMPLEMENTED. The C++ side holds a second instance of
# the far mesher's own `World` struct - the one place in this project's C++
# where `zone_at`, `_slope_zone` and `wildness_at` are written - filled with the
# four things they read. See height_tiles.h.


## Hand over the zone thresholds, the seed, the jitter noise and the config,
## after `_resolve_zone_thresholds()` has run.
func setup_zones(generator: TerrainGenerator, config: WorldgenConfig) -> bool:
	if _impl == null or not _ready:
		return false
	if not ClassDB.class_has_method(CLASS_NAME, "setup_zones"):
		return false
	_impl.setup_zones({
		"zone_thresholds": generator.zone_thresholds,
		"world_seed": generator.world_seed,
		"jitter_noise": generator._jitter,
		"config": FarMesher.config_data(config),
	})
	return _impl.zones_ready()


func zones_ready() -> bool:
	if _impl == null or not ClassDB.class_has_method(CLASS_NAME, "zones_ready"):
		return false
	return _impl.zones_ready()


## One grid's materials, the same shape as `build_tile`'s heights and taking
## them as its input. Empty if the zone rules are not set up yet.
func build_materials(bx0: int, bz0: int, cols: int, rows: int, step: int,
		heights: PackedFloat32Array) -> PackedByteArray:
	if not _ready:
		return PackedByteArray()
	return _impl.build_materials({
		"bx0": bx0, "bz0": bz0, "cols": cols, "rows": rows, "step": step,
		"heights": heights,
	})
