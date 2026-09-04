#include "chunk_mesher.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void KubikChunkMesher::_bind_methods() {
	ClassDB::bind_method(D_METHOD("ping"), &KubikChunkMesher::ping);
	ClassDB::bind_method(D_METHOD("setup", "world"), &KubikChunkMesher::setup);
	ClassDB::bind_method(D_METHOD("is_ready"), &KubikChunkMesher::is_ready);
	ClassDB::bind_method(D_METHOD("build", "args"), &KubikChunkMesher::build);
	ClassDB::bind_method(D_METHOD("has_colors"), &KubikChunkMesher::has_colors);
}

String KubikChunkMesher::ping() const {
	return "kubik chunk mesher, C++";
}

// ONCE PER WORLD (plan Q1). Three values and a table; no world state, no
// engine object, nothing that could be mutated by the main thread while a
// worker is inside build().
void KubikChunkMesher::setup(const Dictionary &p_world) {
	ready = false;
	Variant bs = p_world.get("block_size", Variant());
	if (bs.get_type() != Variant::NIL) {
		// real_t, deliberately: the GDScript twin multiplies a Vector3 by this
		// and Vector3 arithmetic is float32 in a single-precision build, so the
		// double is truncated on that side too. Truncating here as well is what
		// makes the two vertex streams bit-identical.
		block_size = (float)(double)bs;
	}
	Variant ao = p_world.get("ao_strength", Variant());
	if (ao.get_type() != Variant::NIL) {
		ao_strength = (double)ao;
	}
	Variant pal = p_world.get("palette", Variant());
	if (pal.get_type() == Variant::PACKED_COLOR_ARRAY) {
		palette = pal;
	}
	// EVERY FIELD OR NONE, exactly as KubikHeightTiles::setup insists. A short
	// palette is an out-of-range read on the first quad, tens of thousands of
	// times a world, and the answer to one is to keep GDScript rather than to
	// try.
	ready = palette.size() >= 96 && block_size > 0.0f;
}

bool KubikChunkMesher::is_ready() const {
	return ready;
}

// STAGE 0: nothing is painted yet, because nothing is meshed yet.
bool KubikChunkMesher::has_colors() const {
	return false;
}

// STAGE 0: THE STUB. The class registers, loads, pings and accepts a world, and
// the parity harness in the self-test is wired to it before a line of the port
// exists - distance v4 Stage 1's order, and for its reason: a harness written
// after the code it tests is a harness shaped by the code it tests.
Dictionary KubikChunkMesher::build(const Dictionary &p_args) {
	return Dictionary();
}

bool KubikChunkMesher::solid_at(const Borders &b, int x, int y, int z) const {
	return false;
}

int KubikChunkMesher::corner_ao(const Borders &b, int d, int u, int v,
		int air_d, int iu, int jv) const {
	return AO_OPEN;
}
