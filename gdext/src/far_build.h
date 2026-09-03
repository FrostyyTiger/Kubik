#pragma once

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "far_world.h"

namespace kubik {

// One far mesh. `p_args` carries the centre, the frontier, the overlap
// constant and the live knobs; the result is {arrays, vertex_count,
// elapsed_ms}, which is FarFieldJob's three members by another route.
Dictionary build_far_mesh(World &p_world, const Dictionary &p_args);

// LIGHT V1 STAGE 3 REMOVED THIS BLOCK. What stood here was the colour path
// declared one expression at a time - aspect_shade, block_jitter,
// treeline_band, band_m_at and band_color - exposed to the self-test so a
// parity miss could be located rather than merely detected. There is no colour
// path left to locate: a far vertex carries Look.to_wire(zone colour) and
// nothing else, which is one expression and the parity test compares it whole.

} // namespace kubik
