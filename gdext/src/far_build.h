#pragma once

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "far_world.h"

namespace kubik {

// One far mesh. `p_args` carries the centre, the frontier, the overlap
// constant and the live knobs; the result is {arrays, vertex_count,
// elapsed_ms}, which is FarFieldJob's three members by another route.
Dictionary build_far_mesh(World &p_world, const Dictionary &p_args);

// --- Stage 4's micro-gates ---------------------------------------------------
//
// The colour path, one expression at a time, for the same reason Stage 2's
// pyramid is: a whole-mesh diff says the two meshers disagree and never where.
// Declared here rather than left static in the .cpp purely so the self-test can
// reach them.

Color aspect_shade(const Color &p_color, const Vector3 &p_normal,
		double p_slope_amount, double p_aspect_amount);
Color block_jitter(const Color &p_color, int64_t p_bx, int64_t p_bz,
		int64_t p_world_seed, int64_t p_patch, double p_value, double p_hue);
int treeline_band(const World &p_world, double p_band_m);
double band_m_at(const Config &p_config, int p_step_blocks, double p_terrace);
Color band_color(const Color &p_color, double p_y_m, const Config &p_config,
		int p_band_treeline, double p_band_m);

} // namespace kubik
