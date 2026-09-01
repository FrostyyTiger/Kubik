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
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

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
constexpr int64_t SALT_TINT_VALUE = 301;
constexpr int64_t SALT_TINT_HUE = 302;

// terrain_generator.gd's elevation zones, low to high.
constexpr int ZONE_SHORE = 0;
constexpr int ZONE_FOREST = 2;
constexpr int ZONE_ROCK = 5;
constexpr int ZONE_SNOW = 6;
constexpr int ZONE_COUNT = 7;

// block.gd. SUN_ASPECT is Vector2(0, -1) - any fixed direction would do, and
// this one is the -Z the camera starts looking along.
constexpr double SUN_ASPECT_X = 0.0;
constexpr double SUN_ASPECT_Y = -1.0;

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
	double far_normal_m = 96.0;
	double far_band_m = 60.0;
	double far_band_step = 0.03;
	double far_zone_cell_m = 24.0;
	double far_zone_cell_ratio = 0.06;
	double far_riser_shade = 1.0;
	double far_riser_lift = 1.6;
	double far_riser_axis = 0.08;
	double far_geomorph_cells = 4.0;
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
	// The colour path.
	double slope_tint = 0.10;
	double aspect_tint = 0.18;
	int color_jitter_blocks = 6;
	double color_jitter_value = 0.0;
	double color_jitter_hue = 0.0;

	void read(const Dictionary &p_d);
};

// --- The world ------------------------------------------------------------

struct World {
	// Heightmap level 0, and its dimensions.
	std::vector<float> cells;
	int cols = 0;
	int hm_step = 4;
	int min_block = 0;
	int max_block = 0;

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

	// Heightmap.height_at
	double height_at(double bx, double bz) const {
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

	// Heightmap.in_bounds
	bool in_bounds(int64_t bx, int64_t bz) const {
		return bx >= min_block && bz >= min_block &&
				bx <= (int64_t)max_block + hm_step - 1 &&
				bz <= (int64_t)max_block + hm_step - 1;
	}

	// Heightmap._bilinear
	double bilinear(double bx, double bz, int level, bool use_max) const {
		if (level <= 0) {
			return height_at(bx, bz);
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

	// Heightmap._trilinear
	double trilinear(double bx, double bz, double level, bool use_max) const {
		double l = Math::clamp(level, 0.0, (double)max_level);
		int lo = (int)Math::floor(l);
		double f = l - (double)lo;
		if (f <= 0.0001 || lo >= max_level) {
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
