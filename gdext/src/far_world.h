#pragma once

// The world, as the C++ far mesher sees it. Distance v4 Stage 2.
//
// DATA IN, ARRAYS OUT (plan decision 2). Nothing in here is a Godot object
// except the two FastNoiseLite references, which are engine C++ and not a
// GDScript callback - see far_mesher.gd's header. Everything else is a plain
// array handed over once per world load by FarMesher.setup().
//
// EXACTNESS IS THE POINT OF EVERY LINE. The GDScript mesher is the reference
// implementation and the self-test asserts the two produce IDENTICAL arrays,
// so each expression below is the GDScript one transcribed rather than the
// same thing said better. GDScript's float is a C++ double and its int is an
// int64_t, so:
//
//   * every intermediate is `double`, and a value only becomes float where
//     GDScript's would - inside a Vector3, a Color, or a PackedFloat32Array;
//   * integer division truncates toward zero, which for the positive operands
//     here is floor, and `int(x)` on a float truncates toward zero too;
//   * Vector3 and Color arithmetic goes through godot-cpp's own types, whose
//     implementations are the engine's line for line, so the float rounding of
//     a cross product or a normalize is right by construction rather than by
//     a reimplementation somebody has to keep in step.

#include <godot_cpp/classes/fast_noise_lite.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <limits>
#include <unordered_map>
#include <vector>

namespace kubik {

using namespace godot;

// --- WorldHash, transcribed ---------------------------------------------------
//
// scripts/world/world_hash.gd. GDScript ints are 64-bit and overflow WRAPS, so
// the products are done in uint64_t (signed overflow is undefined in C++ and
// the optimiser is entitled to act on that) and the shifts on the signed value,
// where GDScript's `>>` is an arithmetic shift.

constexpr int64_t HASH_PRIME_X = 374761393;
constexpr int64_t HASH_PRIME_Z = 668265263;
constexpr int64_t HASH_PRIME_S = 1274126177;
constexpr int64_t HASH_MIX = 1103515245;

inline int64_t hash2(int64_t x, int64_t z, int64_t world_seed, int64_t salt) {
	uint64_t u = (uint64_t)x * (uint64_t)HASH_PRIME_X +
			(uint64_t)z * (uint64_t)HASH_PRIME_Z +
			(uint64_t)world_seed * (uint64_t)HASH_PRIME_S +
			(uint64_t)salt * (uint64_t)HASH_MIX;
	int64_t h = (int64_t)u;
	u = (uint64_t)(h ^ (h >> 15)) * (uint64_t)HASH_PRIME_S;
	h = (int64_t)u;
	u = (uint64_t)(h ^ (h >> 13)) * (uint64_t)HASH_MIX;
	h = (int64_t)u;
	h = h ^ (h >> 16);
	return h & 0x7FFFFFFF;
}

inline double hash01(int64_t x, int64_t z, int64_t world_seed, int64_t salt) {
	return (double)hash2(x, z, world_seed, salt) / 2147483648.0;
}

// Chunk.floor_div: `(a - posmod(a, b)) / b`, integer throughout.
inline int64_t floor_div(int64_t a, int64_t b) {
	int64_t m = a % b;
	if (m < 0) {
		m += b;
	}
	return (a - m) / b;
}

// The salts the far mesher's callees use. terrain_generator.gd and block.gd.
constexpr int64_t SALT_ZONE_DITHER = 101;
constexpr int64_t SALT_SLOPE_ZONE = 205;
// SALT_TINT_VALUE and SALT_TINT_HUE left with the per-vertex jitter in light
// v1 Stage 3. Nothing hashes a colour any more.

// terrain_generator.gd's elevation zones, low to high.
constexpr int ZONE_SHORE = 0;
constexpr int ZONE_FOREST = 2;
constexpr int ZONE_ROCK = 5;
constexpr int ZONE_SNOW = 6;
constexpr int ZONE_COUNT = 7;

// SUN_ASPECT left with the aspect tint in light v1 Stage 3. A fixed compass
// direction baked into a vertex colour is the definition of painting what
// light should do, and there is real light now.

// --- The config -----------------------------------------------------------

struct Config {
	// Geometry and the world's own constants.
	double block_size = 0.5;
	int world_blocks_xz = 6000;
	int coarse_step = 4;
	int far_step = 8;
	int voxel_radius_chunks = 12;
	double fog_end_m = 600.0;
	// The far knobs.
	double far_terrace = 1.0;
	double far_step_y_blocks = 1.0;
	double far_ring_div = 2.0;
	double far_vote = 0.0;
	double far_filter_bias = 1.0;
	double far_peak_gain = 0.60;
	double far_level_ref_m = 100.0;
	// far_normal_m STAYS. A flank-averaged normal is a coarse mesh's CORRECT
	// normal under real light - it is shape, not paint, and it is the reason a
	// far mountain is one lit flank instead of a patchwork of facets.
	double far_normal_m = 96.0;
	double far_zone_cell_m = 24.0;
	double far_zone_cell_ratio = 0.06;
	double far_geomorph_cells = 4.0;
	double far_detail = 1.0;
	// The detail layer, for the seam band.
	double detail_amp = 3.0;
	double detail_freq = 0.08333;
	double detail_flat_damp = 1.0;
	double detail_flat_deg = 5.0;
	double detail_full_deg = 20.0;
	double shore_flat_blocks = 4.0;
	// The zone rules.
	double zone_blend_blocks = 6.0;
	int zone_dither_blocks = 4;
	double zone_jitter_blocks = 31.5;
	double slope_zone_strength = 1.0;
	double snow_max_slope_deg = 72.0;
	double rock_slope_deg = 78.0;
	double wildness_rock_deg = 12.0;
	double min_altitude = 1.0;
	double max_altitude = 833.7;
	// THE COLOUR PATH IS GONE (light v1 Stage 3, grill Q15). far_band_m,
	// far_band_step, far_riser_shade, far_riser_lift, far_riser_axis,
	// slope_tint, aspect_tint and the three color_jitter_* fields left this
	// struct with the code that read them. A far vertex now carries
	// Look.to_wire(zone colour) and nothing else: one flat colour per material,
	// near and far, and the light does the rest.

	void read(const Dictionary &p_d);
};

// --- The world ------------------------------------------------------------

// --- THE TILE STORE, horizon v1 Stage 1 --------------------------------------
//
// THE HEIGHT MAP STOPS BEING ONE ARRAY WITH AN EDGE, on this side of the seam
// too. `scripts/world/heightmap.gd` carries the whole argument; what this side
// owes is that it reads the SAME numbers, and the far parity gate is what says
// whether it does.
//
// IT NEVER BUILDS ONE. This side has no generator - it is handed noise objects
// and arrays, decision 2 - so a tile that was not marshalled cannot be made
// here. That is not a limitation to work around: it is the rule BOTH legs
// obey. `Heightmap.far_height_at` and friends do not build either, and a
// missing tile reads the region's clamped rim on both sides, so the two
// meshers cannot disagree about ground neither of them has.
//
// `FarField` prepares what a build will read - `Heightmap.ensure_disc`, on the
// main thread - and `FarMesher.build` marshals the new ones. Marshal once per
// TILE rather than once per world: a tile is 66 KB and a build that re-sent
// every one of them would spend the whole speedup on the seam.

// A tile's identity. Origin-anchored, so it means the same square of world
// whatever region is loaded - which is the property D44 asks for and a
// region-relative grid cannot have.
struct TileKey {
	int level = 0;
	int tx = 0;
	int tz = 0;
	bool operator==(const TileKey &o) const {
		return level == o.level && tx == o.tx && tz == o.tz;
	}
};

struct TileKeyHash {
	size_t operator()(const TileKey &k) const {
		// Three small ints into one size_t. The multipliers are odd and
		// coprime; this is a hash table key and not a world hash, so nothing
		// downstream depends on the exact bits.
		uint64_t h = (uint64_t)(uint32_t)k.tx * 0x9E3779B185EBCA87ull;
		h ^= (uint64_t)(uint32_t)k.tz * 0xC2B2AE3D27D4EB4Full;
		h ^= (uint64_t)(uint32_t)k.level * 0x165667B19E3779F9ull;
		h ^= h >> 29;
		return (size_t)h;
	}
};

// One tile's two arrays: the cell mean, which is where the ground is, and the
// cell max, which is what far_peak_gain pulls a summit towards. Both are
// (TILE_CELLS + 1) squared - the apron column is the shared edge, stored twice
// so a bilinear at the last cell needs no neighbour.
struct Tile {
	std::vector<float> mean;
	std::vector<float> high;
};

// Heightmap.TILE_CELLS. The apron makes the stored side one longer.
constexpr int TILE_CELLS = 128;
constexpr int TILE_STRIDE = TILE_CELLS + 1;

// Heightmap.TILE_MAX_LEVEL. The coarsest level the TILE store builds - ring 9's
// 1,024 m cell. The region PYRAMID's own top is `World::max_level`, which is 5,
// and every level clamp below asks which source the position has.
constexpr int TILE_MAX_LEVEL = 9;

struct World {
	// Heightmap level 0, and its dimensions.
	std::vector<float> cells;
	int cols = 0;
	int hm_step = 4;
	int min_block = 0;
	int max_block = 0;

	// The tile store - see the note above. `tile_blocks` is the level-0 tile's
	// side in blocks; a level-L tile is `tile_blocks << L`.
	std::unordered_map<TileKey, Tile, TileKeyHash> tiles;
	int tile_blocks = 512;

	// MATERIAL TILES, Stage 4. Named here and empty until then, so the struct
	// the marshal fills has one shape for the whole lane.
	std::unordered_map<TileKey, std::vector<uint8_t>, TileKeyHash> material_tiles;

	// Take one tile off the wire. Called from setup() and from build().
	void add_tile(int level, int tx, int tz, const PackedFloat32Array &mean,
			const PackedFloat32Array &high);

	// The wire form: [level, tx, tz, mean, high, ...], flat.
	void add_tiles(const Array &p_tiles);

	// Heightmap.tile_of / Chunk.floor_div, for a tile index.
	static inline int64_t tile_index(int64_t b, int64_t span) {
		return floor_div(b, span);
	}

	// Heightmap._tile_bilinear, with `may_build` false - which is the only
	// mode this side has. Returns NAN when the tile is absent, and every
	// caller falls back to the region's clamped rim, exactly as the GDScript
	// does.
	double tile_bilinear(int level, double bx, double bz, bool use_max) const {
		int64_t span = (int64_t)tile_blocks << level;
		int64_t cstep = (int64_t)hm_step << level;
		TileKey key;
		key.level = level;
		key.tx = (int)tile_index((int64_t)Math::floor(bx), span);
		key.tz = (int)tile_index((int64_t)Math::floor(bz), span);
		auto hit = tiles.find(key);
		if (hit == tiles.end()) {
			return std::numeric_limits<double>::quiet_NaN();
		}
		const std::vector<float> &data = use_max ? hit->second.high : hit->second.mean;
		if (data.size() != (size_t)TILE_STRIDE * (size_t)TILE_STRIDE) {
			return std::numeric_limits<double>::quiet_NaN();
		}
		double fx = (bx - (double)(key.tx * span)) / (double)cstep;
		double fz = (bz - (double)(key.tz * span)) / (double)cstep;
		int i0 = (int)Math::floor(fx);
		int j0 = (int)Math::floor(fz);
		i0 = i0 < 0 ? 0 : (i0 > TILE_CELLS - 1 ? TILE_CELLS - 1 : i0);
		j0 = j0 < 0 ? 0 : (j0 > TILE_CELLS - 1 ? TILE_CELLS - 1 : j0);
		double u = Math::clamp(fx - (double)i0, 0.0, 1.0);
		double v = Math::clamp(fz - (double)j0, 0.0, 1.0);
		double h00 = data[(size_t)(i0 + j0 * TILE_STRIDE)];
		double h10 = data[(size_t)(i0 + 1 + j0 * TILE_STRIDE)];
		double h01 = data[(size_t)(i0 + (j0 + 1) * TILE_STRIDE)];
		double h11 = data[(size_t)(i0 + 1 + (j0 + 1) * TILE_STRIDE)];
		return Math::lerp(Math::lerp(h00, h10, u), Math::lerp(h01, h11, u), v);
	}

	// Is this position outside the home region - the 3 km the lakes, the spawn
	// and the zone thresholds are computed over? Heightmap's own test, and the
	// one that decides which source answers.
	inline bool outside_region(double bx, double bz) const {
		return bx < (double)min_block || bx > (double)max_block ||
				bz < (double)min_block || bz > (double)max_block;
	}

	// Levels 1..max_level of the mean pyramid and of the max pyramid, plus
	// each level's side length. Level 0 is `cells` and is never copied, exactly
	// as in heightmap.gd.
	std::vector<std::vector<float>> levels;
	std::vector<std::vector<float>> max_levels;
	std::vector<int> level_cols;
	int max_level = 5;

	// The generator's resolved zone thresholds, and its seed.
	std::vector<float> zone_thresholds;
	int64_t world_seed = 0;

	// The lakes' shore fade, as detail_at() reads it.
	std::vector<uint8_t> shore_near;
	std::vector<float> shore_level;

	// Block.color_of(ZONE_SURFACE[zone]), linear, one per zone.
	std::vector<Color> zone_colors;

	// The two noise objects. Engine C++, sampled natively.
	Ref<FastNoiseLite> detail_noise;
	Ref<FastNoiseLite> jitter_noise;

	Config config;
	bool ready = false;

	void setup(const Dictionary &p_d);

	// --- heightmap.gd ------------------------------------------------------

	inline float cell_at(int i, int j) const {
		return cells[(size_t)i + (size_t)j * (size_t)cols];
	}

	// Heightmap.far_height_at - the far mesh's door, which never builds a tile.
	// Outside the region: the level-0 tile if it was marshalled, the region's
	// clamped rim if it was not.
	double height_at(double bx, double bz) const {
		if (outside_region(bx, bz)) {
			double h = tile_bilinear(0, bx, bz, false);
			if (!Math::is_nan(h)) {
				return h;
			}
		}
		return region_bilinear(bx, bz);
	}

	// Heightmap._region_bilinear
	double region_bilinear(double bx, double bz) const {
		const double lo = (double)min_block;
		const double hi = (double)max_block;
		double fx = (Math::clamp(bx, lo, hi) - (double)min_block) / (double)hm_step;
		double fz = (Math::clamp(bz, lo, hi) - (double)min_block) / (double)hm_step;
		int i0 = (int)Math::floor(fx);
		int j0 = (int)Math::floor(fz);
		double tx = fx - (double)i0;
		double tz = fz - (double)j0;
		int i1 = i0 + 1 < cols - 1 ? i0 + 1 : cols - 1;
		int j1 = j0 + 1 < cols - 1 ? j0 + 1 : cols - 1;
		double h00 = cell_at(i0, j0);
		double h10 = cell_at(i1, j0);
		double h01 = cell_at(i0, j1);
		double h11 = cell_at(i1, j1);
		return Math::lerp(Math::lerp(h00, h10, tx), Math::lerp(h01, h11, tx), tz);
	}

	// Heightmap.slope_deg_at
	double slope_deg_at(double bx, double bz) const {
		double d = (double)hm_step;
		double gx = (height_at(bx + d, bz) - height_at(bx - d, bz)) / (2.0 * d);
		double gz = (height_at(bx, bz + d) - height_at(bx, bz - d)) / (2.0 * d);
		return Math::rad_to_deg(Math::atan(Math::sqrt(gx * gx + gz * gz)));
	}

	// Heightmap.in_home_region (renamed from in_bounds, horizon v1 Stage 1 -
	// there is no out of bounds any more; this is the region's bookkeeping).
	bool in_bounds(int64_t bx, int64_t bz) const {
		return bx >= min_block && bz >= min_block &&
				bx <= (int64_t)max_block + hm_step - 1 &&
				bz <= (int64_t)max_block + hm_step - 1;
	}

	// Heightmap.far_max_level - the coarsest level this position has a source
	// for. Nine outside the region, where the tile store answers; the pyramid's
	// own top inside it. Asking the pyramid for level 8 would index levels[7]
	// of a five-level pyramid, which is a crash rather than a coarse mountain.
	inline int far_max_level(double bx, double bz) const {
		return outside_region(bx, bz) ? TILE_MAX_LEVEL : max_level;
	}

	// Heightmap._far_bilinear
	double bilinear(double bx, double bz, int level, bool use_max) const {
		if (level <= 0) {
			return height_at(bx, bz);
		}
		if (outside_region(bx, bz)) {
			int lt = level < TILE_MAX_LEVEL ? level : TILE_MAX_LEVEL;
			double h = tile_bilinear(lt, bx, bz, use_max);
			if (!Math::is_nan(h)) {
				return h;
			}
			// The rim, at this level, exactly as the pyramid read it before
			// tonight - which is what Heightmap._region_clamped does, clamped
			// to the PYRAMID's own top for the reason far_max_level gives.
			bx = Math::clamp(bx, (double)min_block, (double)max_block);
			bz = Math::clamp(bz, (double)min_block, (double)max_block);
		}
		int l = level < max_level ? level : max_level;
		int n = level_cols[l - 1];
		const std::vector<float> &data = use_max ? max_levels[l - 1] : levels[l - 1];
		double lstep = (double)((int64_t)hm_step << l);
		double origin = (double)min_block + (lstep - (double)hm_step) * 0.5;
		double hi = origin + (double)(n - 1) * lstep;
		double fx = (Math::clamp(bx, origin, hi) - origin) / lstep;
		double fz = (Math::clamp(bz, origin, hi) - origin) / lstep;
		int i0 = (int)Math::floor(fx);
		int j0 = (int)Math::floor(fz);
		double tx = fx - (double)i0;
		double tz = fz - (double)j0;
		i0 = i0 < 0 ? 0 : (i0 > n - 1 ? n - 1 : i0);
		j0 = j0 < 0 ? 0 : (j0 > n - 1 ? n - 1 : j0);
		int i1 = i0 + 1 < n - 1 ? i0 + 1 : n - 1;
		int j1 = j0 + 1 < n - 1 ? j0 + 1 : n - 1;
		double h00 = data[(size_t)i0 + (size_t)j0 * (size_t)n];
		double h10 = data[(size_t)i1 + (size_t)j0 * (size_t)n];
		double h01 = data[(size_t)i0 + (size_t)j1 * (size_t)n];
		double h11 = data[(size_t)i1 + (size_t)j1 * (size_t)n];
		return Math::lerp(Math::lerp(h00, h10, tx), Math::lerp(h01, h11, tx), tz);
	}

	// Heightmap._far_trilinear
	double trilinear(double bx, double bz, double level, bool use_max) const {
		int top = far_max_level(bx, bz);
		double l = Math::clamp(level, 0.0, (double)top);
		int lo = (int)Math::floor(l);
		double f = l - (double)lo;
		if (f <= 0.0001 || lo >= top) {
			return bilinear(bx, bz, lo, use_max);
		}
		return Math::lerp(bilinear(bx, bz, lo, use_max),
				bilinear(bx, bz, lo + 1, use_max), f);
	}

	double height_filtered(double bx, double bz, double level) const {
		return trilinear(bx, bz, level, false);
	}

	double height_max_filtered(double bx, double bz, double level) const {
		return trilinear(bx, bz, level, true);
	}

	// --- terrain_generator.gd, the zone rules ------------------------------
	//
	// DECISION 4, RUNG (a): every one of these is a pure function of altitude,
	// a slope read off level 0, a hash and config scalars, so they are ported
	// rather than precomputed into a grid. The one that is NOT pure is
	// `zone_jitter_at`, and it is a FastNoiseLite sample - held as the same
	// engine object the generator built and called natively, exactly as
	// `detail_at` already is. See far_mesher.gd's header: no GDScript frame is
	// entered, and the noise is bit-identical by construction.

	// TerrainGenerator.wildness_at
	double wildness_at(double bx, double bz) const {
		double half = (double)config.world_blocks_xz * 0.5;
		if (half <= 0.0) {
			return 0.0;
		}
		return Math::clamp(Math::max(Math::abs(bx), Math::abs(bz)) / half, 0.0, 1.0);
	}

	// TerrainGenerator.zone_jitter_at
	double zone_jitter_at(double bx, double bz) const {
		return (double)jitter_noise->get_noise_2d(bx, bz) * config.zone_jitter_blocks;
	}

	// TerrainGenerator.zone_at
	int zone_at(double altitude, double jitter, double dither) const {
		double blend = Math::max(config.zone_blend_blocks, 0.001);
		int zone = ZONE_SHORE;
		for (size_t i = 0; i < zone_thresholds.size(); i++) {
			double edge = (altitude - ((double)zone_thresholds[i] + jitter)) / blend + 0.5;
			if (edge <= 0.0) {
				break;
			}
			if (edge >= 1.0 || dither < edge) {
				zone = (int)i + 1;
			} else {
				break;
			}
		}
		return zone;
	}

	// TerrainGenerator._slope_zone
	int slope_zone(int64_t bx, int64_t bz, int zone) const {
		if (config.slope_zone_strength <= 0.0) {
			return zone;
		}
		double slope = slope_deg_at((double)bx, (double)bz);
		double roll = hash01(bx, bz, world_seed, SALT_SLOPE_ZONE);
		if (roll > Math::clamp(config.slope_zone_strength, 0.0, 1.0)) {
			return zone;
		}
		if (zone == ZONE_SNOW && slope >= config.snow_max_slope_deg) {
			return ZONE_ROCK;
		}
		double rock_at = config.rock_slope_deg
				- config.wildness_rock_deg * wildness_at((double)bx, (double)bz);
		if (zone > ZONE_SHORE && zone < ZONE_ROCK && slope >= rock_at) {
			return ZONE_ROCK;
		}
		return zone;
	}

	// TerrainGenerator.surface_zone_at - ring 0's zone, jitter and dither and
	// all, because it touches the voxels at the seam and the treeline has to
	// agree with the trees.
	int surface_zone_at(int64_t bx, int64_t bz, double altitude) const {
		int64_t patch = config.zone_dither_blocks > 1 ? config.zone_dither_blocks : 1;
		int zone = zone_at(altitude,
				zone_jitter_at((double)bx, (double)bz),
				hash01(floor_div(bx, patch), floor_div(bz, patch), world_seed,
						SALT_ZONE_DITHER));
		return slope_zone(bx, bz, zone);
	}

	// FarFieldJob.backdrop_zone - altitude alone, no jitter, a dither of
	// exactly 0.5, and the slope override kept.
	int backdrop_zone(int64_t bx, int64_t bz, double altitude) const {
		return slope_zone(bx, bz, zone_at(altitude, 0.0, 0.5));
	}

	// FarFieldJob.filtered_height / _filtered's tail: the peak gain.
	double filtered_height(double bx, double bz, double level) const {
		if (level <= 0.0) {
			return height_at(bx, bz);
		}
		double mean = height_filtered(bx, bz, level);
		double gain = config.far_peak_gain;
		if (gain <= 0.0) {
			return mean;
		}
		return Math::lerp(mean, height_max_filtered(bx, bz, level), gain);
	}
};

} // namespace kubik
