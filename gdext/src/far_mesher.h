#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

#include "far_world.h"

using namespace godot;

// The far mesher, ported from scripts/world/far_field_job.gd. 2026-09-01.
//
// THE GDSCRIPT JOB IS THE REFERENCE AND NOT THE CASUALTY (plan decision 1).
// `far_field_job.gd` stays in-tree and the self-test asserts this class
// reproduces its output array for array. Two implementations is the price of a
// fallback that keeps the game playable on a machine with no compiler, and the
// parity gate is what stops that price becoming drift.
//
// DATA IN, ARRAYS OUT (decision 2). setup() takes the world once; build()
// takes a centre, a frontier and the live knobs and returns the four mesh
// arrays. Nothing here holds a Heightmap, a TerrainGenerator, a WorldgenConfig
// or a Look, and nothing calls back into GDScript during a build.
class KubikFarMesher : public RefCounted {
	GDCLASS(KubikFarMesher, RefCounted)

	kubik::World world;

protected:
	static void _bind_methods();

public:
	String ping() const;
	double bench_sum(const PackedFloat32Array &p_values) const;

	void setup(const Dictionary &p_world);

	// --- Stage 2's micro-gate ---------------------------------------------
	//
	// The pyramid, exposed one expression at a time so the self-test can put
	// 10,000 random triples through both implementations and compare. They are
	// bound rather than merely used because a whole-mesh diff tells you the
	// meshers disagree and never where - and "where" is what a port needs.
	double h_at(double p_bx, double p_bz) const;
	double h_filtered(double p_bx, double p_bz, double p_level) const;
	double h_max_filtered(double p_bx, double p_bz, double p_level) const;
	double h_peak(double p_bx, double p_bz, double p_level) const;
	double h_slope_deg(double p_bx, double p_bz) const;
	bool is_ready() const;

	// --- The mesh ----------------------------------------------------------

	Dictionary build(const Dictionary &p_args);

	// Does this build paint as well as shape? False through Stage 3, where
	// every colour is white and the parity harness is told to compare the rows
	// that are meant to match and no others.
	bool has_colors() const;
};
