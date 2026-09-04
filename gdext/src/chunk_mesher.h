#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <vector>

using namespace godot;

// THE CHUNK MESHER, ported from scripts/world/chunk_mesher.gd. Mesher v1,
// 2026-09-04, phase 1b of RECONCILIATION.md section 9 (bible D56).
//
// READ THE GDSCRIPT FIRST. Every rule this file obeys - the sign-encoded mask,
// the canonical AO corner order, the two winding tables, the interior-angle
// special case - is written down there with the reason it exists, and none of
// those reasons is repeated here. What this file owes is that it emits THE SAME
// ARRAYS, and the self-test's `chunk parity` gate is what says whether it does.
// An "improved" expression is a failed gate; a silently improved one is worse.
//
// THE GDSCRIPT IS THE REFERENCE AND NOT THE CASUALTY (plan Q7). `chunk_mesher.gd`
// keeps its body under the name `build_arrays_gd()` and the parity gate asserts
// this class reproduces it array for array. Retirement is Marcel's call, not
// this lane's.
//
// DATA IN, ARRAYS OUT (plan Q1). setup() takes the world's block size, its AO
// strength and the 96-entry wire palette ONCE; build() takes one chunk's 4,096
// voxels plus whatever the six faces need to answer for the blocks just outside
// them. Nothing here holds a Chunk, a TerrainGenerator, a WorldgenConfig or a
// Look, and nothing calls back into GDScript during a build.
//
// COLOUR CROSSES AS A TABLE, NOT AS ARITHMETIC (plan Q3). Distance v4's Windows
// bring-up measured gcc and MSVC rounding the same colour expression one float
// ULP apart, and every Windows parity failure this project has ever had was of
// that kind. So GDScript computes `Look.to_wire(Block.color_of(id) * shade)` for
// all 24 ids at all 4 AO levels once per world and hands the table over; the C++
// colour path is an INDEX. There is no float arithmetic on a colour in this file
// and therefore nothing for two compilers to disagree about.
class KubikChunkMesher : public RefCounted {
	GDCLASS(KubikChunkMesher, RefCounted)

public:
	// Chunk.SIZE, and the geometry that follows from it. Spelled here rather
	// than marshalled: a chunk that stopped being 16 would change the wire
	// format, the network protocol and the save files, and this class is not
	// where that would be discovered.
	static constexpr int SIZE = 16;
	static constexpr int SIZE_SQ = SIZE * SIZE;
	static constexpr int VOLUME = SIZE * SIZE * SIZE;
	// The AO shell is the chunk plus one block on every side.
	static constexpr int SHELL = SIZE + 2;
	static constexpr int SHELL_SQ = SHELL * SHELL;
	static constexpr int SHELL_VOLUME = SHELL * SHELL * SHELL;

private:
	// chunk_mesher.gd's AXIS_U / AXIS_V. (u, v, d) is right-handed; a
	// left-handed triple silently turns the world inside out.
	static constexpr int AXIS_U[3] = { 1, 2, 0 };
	static constexpr int AXIS_V[3] = { 2, 0, 1 };

	// Four corner AO levels of 3, packed two bits each: the value a face
	// carries when AO is off.
	static constexpr int AO_OPEN = 0xFF;

	float block_size = 0.5f;
	double ao_strength = 0.0;
	PackedColorArray palette; // 24 ids x 4 AO levels, wire-space, from GDScript
	bool ready = false;

	// One build's borders, resolved once per build() rather than per read.
	struct Borders {
		const uint8_t *voxels = nullptr;
		// The six neighbour chunks, in the order +X, -X, +Y, -Y, +Z, -Z.
		const uint8_t *n[6] = { nullptr, nullptr, nullptr, nullptr, nullptr, nullptr };
		// Where a neighbour chunk does not exist, the generator's answer,
		// pre-reduced to ONE INTEGER PER COLUMN: the y of the highest solid
		// block, `floor(surface_at(bx, bz))`. See the note in build().
		const int32_t *top_col = nullptr; // 16 x 16, the column's own footprint
		const int32_t *top_px = nullptr; // 16, indexed by local z
		const int32_t *top_nx = nullptr;
		const int32_t *top_pz = nullptr; // 16, indexed by local x
		const int32_t *top_nz = nullptr;
		// The 18^3 solidity shell, present only when AO is on.
		const uint8_t *shell = nullptr;
		int64_t origin_y = 0;
		// A read that had neither a neighbour nor a strip to answer it. Always
		// zero when the dispatcher did its job; returned so a marshalling bug
		// shows up as a number rather than as a wall of faces in a screenshot.
		mutable int64_t missing = 0;
	};

	// Where a build's arrays accumulate. std::vector and not the packed arrays
	// themselves: a PackedVector3Array grows through the engine's allocator one
	// push at a time, and the whole point of this class is not to.
	struct Sink {
		std::vector<Vector3> verts;
		std::vector<Vector3> normals;
		std::vector<Color> colors;
		std::vector<int32_t> indices;
	};

	bool solid_at(const Borders &b, int x, int y, int z) const;
	// The same question in (d, u, v) coordinates, which is how the AO code asks
	// it. `chunk_mesher.gd:_solid_at`.
	bool solid_duv(const Borders &b, int d, int u, int v,
			int dd, int uu, int vv) const;
	// One face cell's four corner AO levels, packed (su + sv * 2).
	int corner_ao(const Borders &b, int d, int u, int v,
			int air_d, int iu, int jv) const;
	// `chunk_mesher.gd:_emit_slice` and `_emit_quad`.
	void emit_slice(int32_t *mask, const int32_t *ao_mask,
			int d, int u, int v, int plane, Sink &sink) const;
	void emit_quad(int d, int u, int v, int plane,
			int u0, int v0, int w, int h, int value, int ao_value,
			Sink &sink) const;

protected:
	static void _bind_methods();

public:
	String ping() const;
	void setup(const Dictionary &p_world);
	bool is_ready() const;

	// Does this build PAINT as well as shape? False through Stage 1, where
	// every quad is white and the parity harness is told to compare the rows
	// that are meant to match and no others. The far mesher's own gate carried
	// the same flag through distance v4 for the same three stages.
	bool has_colors() const;

	Dictionary build(const Dictionary &p_args);
};
