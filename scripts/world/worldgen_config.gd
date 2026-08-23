class_name WorldgenConfig
extends Resource

## Every tunable number that shapes the world, in one place.
##
## Two reasons this is a Resource and not a pile of constants:
##
## 1. TUNING. Terrain is found by trial and error, and recompiling your way to
##    a mountain range is miserable. These values load from user://worldgen.tres
##    at startup and re-read on a key press, so the loop is "edit, press F5,
##    look" instead of "edit, restart, walk back to where you were".
##
## 2. DETERMINISM. The README's contract is that terrain is never sent, only a
##    seed - both machines regenerate an identical world from it. That is only
##    true if both machines also agree on every number below. The config is
##    therefore part of the determinism contract ALONGSIDE the seed, and it is
##    sent in the join handshake next to it. A client generating with a
##    different treeline is the silent-desync failure the README warns about.
##
## Hence to_dict()/from_dict()/hash_key(): serialisable from the start, so
## putting it on the wire is a two-line change rather than a refactor.

## Where the hot-reloadable copy lives. Absent on a fresh install, which is
## why every value below has a default that is already the shipped spec.
const USER_PATH := "user://worldgen.tres"


# --- Scale ------------------------------------------------------------------
#
# The one number here that touches everything else is block_size. Voxel maths
# stays in integer BLOCKS everywhere; metres only appear when we hand a
# position to the renderer or the physics engine. Keeping that line sharp is
# what stops "is this 0.5 or 1.0?" bugs from spreading through the codebase.

## Metres per block. 0.5 means a 4-block player is 2 m tall.
@export var block_size := 0.5

## World footprint in blocks, centred on the origin: x and z run
## -world_blocks_xz/2 .. world_blocks_xz/2 - 1.
@export var world_blocks_xz := 3000

## Vertical extent in blocks. 320 blocks = 160 m.
@export var world_height_blocks := 320

## Blocks per coarse heightmap cell. 4 blocks = 2 m, giving a 750x750 grid.
@export var coarse_step := 4

## Blocks per far-field mesh vertex. 8 blocks = 4 m, giving 375x375.
@export var far_step := 8

## Radius, in chunks, of real editable voxels around the player.
## THIS IS THE PERFORMANCE DIAL. If the frame budget cannot be met, turn this
## down rather than changing anything else.
@export var voxel_radius_chunks := 8

## How many chunks of solid rock to build below the surface. The world is 320
## blocks tall but nobody can see the bottom 250 of it, so building a full
## vertical column would be ~4x the chunks for no visible difference.
@export var voxel_depth_chunks := 3

## Player capsule, in blocks. 4 blocks tall = 2.0 m.
@export var player_height_blocks := 4.0
@export var player_radius_blocks := 0.8


# --- Terrain shape ----------------------------------------------------------
#
# Four noise layers, coarse to fine, summed. They are kept SEPARATE on purpose:
# one fused noise expression is shorter but you cannot tune it, because every
# knob moves every feature at once.
#
# Frequency is 1 / wavelength, in blocks. The comment on each line is the
# wavelength it works out to, because that is the number you can actually
# picture standing in the world.

## 1200 blocks / 600 m - broad "where is high ground at all" trend.
@export var continent_freq := 0.00083
@export var continent_amp := 48.0

## 300 blocks / 150 m - THE feature layer. Ridged, so it makes peaks and
## valleys rather than lumps. Mountain footprints land at 100-200 m across,
## which is the readability target: big enough to be a landmark, small enough
## to walk around before you get bored.
@export var mountain_freq := 0.00333
@export var mountain_amp := 178.0

## Where mountains are ALLOWED to be, as a window on the continent layer.
##
## Summing the layers everywhere gives a world that is uniformly bumpy - the
## same amount of relief in every direction, no lowlands to speak of, and
## nowhere flat enough to hold a lake. Gating the mountain layer on the
## continent layer instead gives what the design actually asks for: broad
## lowlands with meadows and water, and mountain country concentrated into
## massifs you can see from outside and walk into.
##
## Below _lo the mountain layer contributes nothing at all; above _hi it
## contributes in full; between them it fades in. Both are values of the
## continent noise, so they live in [-1, 1].
@export var mountain_mask_lo := -0.12
@export var mountain_mask_hi := 0.47

## 60 blocks / 30 m - slope detail, so hillsides are not smooth ramps.
@export var hills_freq := 0.01667
@export var hills_amp := 16.0

## 12 blocks / 6 m - per-block roughness, added at voxel time only. Deliberately
## NOT part of the coarse heightmap: lake basins are found in the coarse map,
## and a 3-block bump must never be able to invent or drain a lake.
@export var detail_freq := 0.08333
@export var detail_amp := 3.0

## 400 blocks / 200 m - wobbles the elevation zone thresholds so the treeline
## is not a ruler-straight contour line.
@export var zone_jitter_freq := 0.0025

## Blocks of threshold wobble at full jitter, applied +/-.
@export var zone_jitter_blocks := 12.0

## Altitude the layers build up from, in blocks.
@export var base_altitude := 70.0

## Hard clamps. 0 is bedrock and the very top must stay air, or the sky is
## solid and the far mesh has nothing to draw against.
@export var min_altitude := 1.0
@export var max_altitude := 318.0

## Domain warp strength in blocks, used by the TODO(marcel) exercise in
## TerrainGenerator. Ignored by the fallback.
@export var warp_strength := 40.0

## Exponent for the valley flattening curve, used by the other TODO(marcel)
## exercise. Ignored by the fallback.
@export var valley_curve := 1.6


# --- Elevation zones --------------------------------------------------------
#
# Altitudes in blocks. Each boundary is nudged by the zone_jitter layer, and
# colours blend across zone_blend_blocks so the transition reads as a gradient
# rather than a contour line on a map.

@export var meadow_max := 100.0
@export var forest_max := 165.0
@export var rock_max := 215.0

## Blocks over which two neighbouring zone colours cross-fade.
@export var zone_blend_blocks := 6.0


# --- Content ----------------------------------------------------------------

## One candidate tree per this many blocks, in both x and z.
@export var tree_cell_blocks := 4

## Placement probability in the MIDDLE of the forest band. Tapers linearly to
## zero at both edges of the band, so the treeline thins out instead of
## stopping dead.
@export var tree_probability := 0.12

@export var tree_trunk_min := 3
@export var tree_trunk_max := 5
@export var tree_canopy_min := 2
@export var tree_canopy_max := 3

## A basin smaller than this many coarse cells is a puddle, not a lake, and is
## discarded. 40 cells at 2 m per cell is about 160 m2.
@export var lake_min_cells := 40

## Blocks below the spill point to set the water surface. Without it the water
## sits exactly at the lip and leaks visually over the edge.
@export var lake_level_offset := 1.0


# --- Atmosphere -------------------------------------------------------------

## Metres. Beyond fog_end nothing is visible, which is what makes the far-field
## mesh's edge invisible rather than a cliff at the horizon.
@export var fog_start_m := 120.0
@export var fog_end_m := 200.0

## Real seconds per in-game day.
@export var day_seconds := 480.0

## Where the cycle starts. 0.25 is morning, 0.5 midday - the world should open
## in daylight, not at midnight.
@export var day_start := 0.3


# --- Serialisation ----------------------------------------------------------
#
# ORDER MATTERS AND IS FIXED. hash_key() walks this list, and a Dictionary in
# GDScript preserves insertion order but nothing promises that two machines
# built the dictionary the same way. Naming the order explicitly means the hash
# depends on the VALUES and nothing else - which is the entire point of having
# a hash.
const PROPERTIES: PackedStringArray = [
	"block_size", "world_blocks_xz", "world_height_blocks", "coarse_step",
	"far_step", "voxel_radius_chunks", "voxel_depth_chunks",
	"player_height_blocks", "player_radius_blocks",
	"continent_freq", "continent_amp", "mountain_freq", "mountain_amp",
	"hills_freq", "hills_amp", "detail_freq", "detail_amp",
	"zone_jitter_freq", "zone_jitter_blocks",
	"base_altitude", "min_altitude", "max_altitude",
	"warp_strength", "valley_curve",
	"meadow_max", "forest_max", "rock_max", "zone_blend_blocks",
	"tree_cell_blocks", "tree_probability",
	"tree_trunk_min", "tree_trunk_max", "tree_canopy_min", "tree_canopy_max",
	"lake_min_cells", "lake_level_offset",
	"fog_start_m", "fog_end_m", "day_seconds", "day_start",
]


func to_dict() -> Dictionary:
	var out := {}
	for key in PROPERTIES:
		out[key] = get(key)
	return out


## Missing keys keep their default. That is deliberate: an older client joining
## a newer host gets sensible values for fields it has never heard of rather
## than a crash. It does NOT get an identical world - the config hash comparison
## in the handshake is what catches that.
func from_dict(data: Dictionary) -> void:
	for key in PROPERTIES:
		if data.has(key):
			set(key, data[key])


## A short stable fingerprint of every value, for comparing two machines.
##
## Floats are formatted to 6 decimal places rather than hashed directly:
## printing pins the comparison to a fixed precision, so a value that survives
## a round trip through the network as a slightly different double still
## fingerprints the same. Two configs that differ in a way a player could ever
## notice differ far more than 1e-6.
func hash_key() -> String:
	var parts := PackedStringArray()
	for key in PROPERTIES:
		var v = get(key)
		if v is float:
			parts.append("%s=%.6f" % [key, v])
		else:
			parts.append("%s=%s" % [key, v])
	return String.num_uint64(hash(String("|").join(parts)), 16)


func clone() -> WorldgenConfig:
	var c := WorldgenConfig.new()
	c.from_dict(to_dict())
	return c


# --- Loading ----------------------------------------------------------------

## Defaults, or the user's tuned copy if there is one.
##
## A broken or stale .tres must never stop the game booting - the whole point
## of the file is that Marcel edits it by hand at 1 a.m. So a failed load is a
## warning and the defaults, never an error.
static func load_or_default() -> WorldgenConfig:
	if not ResourceLoader.exists(USER_PATH):
		return WorldgenConfig.new()
	var res := ResourceLoader.load(USER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res is WorldgenConfig:
		print("[Worldgen] loaded config from %s" % USER_PATH)
		return res
	push_warning("[Worldgen] %s is not a WorldgenConfig, using defaults" % USER_PATH)
	return WorldgenConfig.new()


## Write the current values out so there is something to edit. Called by the
## tuning panel's save, and once on first run so the file exists to be found.
func save_to_user() -> void:
	var err := ResourceSaver.save(self, USER_PATH)
	if err != OK:
		push_warning("[Worldgen] could not save config: %s" % error_string(err))
	else:
		print("[Worldgen] saved config to %s" % USER_PATH)
