#pragma once

#include <godot_cpp/classes/fast_noise_lite.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include "far_world.h"

using namespace godot;

// THE HEIGHT MAP'S TILE BUILDER, ported from
// scripts/world/terrain_generator.gd's height_at_block() and its four callees.
// Distance v5 Stage 4, decisions 3 and 4.
//
// THIS ONE IS WORLD TRUTH AND THE FAR MESHER IS NOT, which is the whole reason
// it is a separate class rather than four more methods on KubikFarMesher. The
// far mesh is look-only: if the two meshers disagreed by a ULP, two players
// would see slightly different mountains and walk on identical ground. The
// height map decides where the ground IS - spawn and lakes are computed from it
// - so a ULP here is two players in different worlds, and hard rule zero says
// that outranks every other consideration in this project.
//
// HENCE THE QUANTISATION, and it is the point of the class rather than a
// detail. Distance v4's Windows bring-up measured gcc and MSVC rounding the
// same expression one float ULP apart (docs/status/distance-v4.md, the Windows
// addendum). So every height this builder emits is rounded to 1/1024 of a
// block as its LAST step, and terrain_generator.gd does the same, in the same
// commit. 1/1024 is 0.5 mm of world; a one-ULP disagreement is fifteen orders
// of magnitude smaller than half a quantum, so the two compilers round to the
// same multiple. And k/1024 for |k| < 2^23 is EXACTLY representable in
// float32, so the value that lands in the PackedFloat32Array is the quantised
// value with no second rounding to disagree about.
//
// DATA IN, ARRAYS OUT, exactly as the far mesher's seam works: setup() takes
// the eight noise objects and the config once, build_tile() takes a rectangle
// of cells and returns their heights. The noise objects are the generator's
// OWN FastNoiseLite refs - engine C++, sampled natively, bit-identical by
// construction rather than by a reimplementation somebody has to keep in step.
class KubikHeightTiles : public RefCounted {
	GDCLASS(KubikHeightTiles, RefCounted)

	// The eight fields height_at_block reaches for. `detail` and `jitter` are
	// deliberately absent: they belong to the voxel surface and the zone rules,
	// neither of which this class touches.
	Ref<FastNoiseLite> continent;
	Ref<FastNoiseLite> mountain;
	Ref<FastNoiseLite> hills;
	Ref<FastNoiseLite> warp_x;
	Ref<FastNoiseLite> warp_z;
	Ref<FastNoiseLite> hills_mask;
	Ref<FastNoiseLite> bench_mask;
	Ref<FastNoiseLite> plateau_mask;

	// terrain_generator.gd's own names, and the defaults are worldgen_config's.
	double base_altitude = 24.0;
	double continent_amp = 120.0;
	double mountain_freq = 0.0015;
	double mountain_amp = 420.0;
	double mountain_mask_lo = 0.05;
	double mountain_mask_hi = 0.45;
	double hills_amp = 26.0;
	double hills_gate_strength = 1.0;
	double hills_mask_lo = -0.10;
	double hills_mask_hi = 0.35;
	double wildness_relief = 0.60;
	double warp_strength = 40.0;
	double valley_curve = 1.6;
	double terrace_height = 6.0;
	double terrace_sharpness = 3.0;
	double bench_strength = 0.7;
	double bench_height = 14.0;
	double plateau_strength = 0.6;
	double plateau_height = 30.0;
	double min_altitude = 1.0;
	double max_altitude = 833.7;
	int world_blocks_xz = 6000;

	bool ready = false;

	// TerrainGenerator's two module constants. Vector2 IS float32 in a
	// single-precision build, so these are float32 and the arithmetic that
	// reads them starts from the truncated value - which is why they are
	// spelled as Vector2 here rather than as two doubles.
	static constexpr float BENCH_BAND_LO = 0.20f;
	static constexpr float BENCH_BAND_HI = 0.60f;
	static constexpr float PLATEAU_BAND_LO = 0.50f;
	static constexpr float PLATEAU_BAND_HI = 1.00f;
	static constexpr double MASKED_BAND_FADE = 0.25;

	// THE QUANTUM. 1/1024 of a block, applied as the last step of
	// height_at_block. See the class note.
	static constexpr double QUANTUM = 1024.0;

protected:
	static void _bind_methods();

public:
	void setup(const Dictionary &p_world);
	bool is_ready() const;

	// One tile: `cols` x `rows` cells starting at block (`bx0`, `bz0`), spaced
	// `step` blocks apart, row-major. Returns cols * rows heights.
	PackedFloat32Array build_tile(const Dictionary &p_args) const;

	// The micro-gate: one cell, so the self-test can put thousands of
	// positions through both implementations and say WHERE they differ rather
	// than only that they do.
	double height_at_block(double p_bx, double p_bz) const;

	// THE MATERIAL PYRAMID'S LEVEL 0, horizon v1 Stage 4.
	//
	// The zone rules, not the height rules - so this class carries a `World`
	// rather than a second copy of `surface_zone_at`. `World` is the far
	// mesher's struct and every zone expression in the project's C++ lives on
	// it exactly once; what is held here is a second INSTANCE of it, filled
	// with the four things the zone rules read (the thresholds, the seed, the
	// jitter noise and the config) and nothing else. Read-only after
	// `setup_zones`, so a dozen chunk workers may fill materials at once for
	// the same reason they may build heights at once.
	//
	// IT IS HERE AND NOT IN GDSCRIPT BECAUSE IT IS 17 MILLION EVALUATIONS. The
	// first spelling of this stage tallied materials in `heightmap.gd` and put
	// the self-test's tile build from 10.5 s to 74; the same loop here is a
	// fraction of a second. Measured, in docs/status/horizon-v1.md.
	void setup_zones(const Dictionary &p_world);
	bool zones_ready() const { return zones_set; }

	// One grid's materials: `cols` x `rows` cells from block (`bx0`, `bz0`),
	// `step` apart, with `heights` the same grid's altitudes. The slope is the
	// central difference over the grid, edge-clamped - at `step` 4 that is
	// exactly `Heightmap.slope_deg_at`.
	PackedByteArray build_materials(const Dictionary &p_args) const;

private:
	kubik::World zones;
	bool zones_set = false;

	double raw_height(double p_bx, double p_bz) const;
	double ridge(double n) const { return (1.0 - Math::abs(n)) * (1.0 - Math::abs(n)); }
	double wildness_at(double bx, double bz) const;
	double hills_gate(double wx, double wz) const;
	double flatten_valleys(double h) const;
	double terrace(double h) const;
	double benches_and_plateaus(double h, double wx, double wz) const;
	double masked_terrace(double h, double wx, double wz,
			const Ref<FastNoiseLite> &mask, double strength, double height,
			float band_lo, float band_hi) const;
};
