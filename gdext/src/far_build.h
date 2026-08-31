#pragma once

#include <godot_cpp/variant/dictionary.hpp>

#include "far_world.h"

namespace kubik {

// One far mesh. `p_args` carries the centre, the frontier, the overlap
// constant and the live knobs; the result is {arrays, vertex_count,
// elapsed_ms}, which is FarFieldJob's three members by another route.
Dictionary build_far_mesh(World &p_world, const Dictionary &p_args);

} // namespace kubik
