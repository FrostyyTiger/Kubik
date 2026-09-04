#include "chunk_mesher.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

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
	ready = palette.size() >= PALETTE_IDS * PALETTE_LEVELS && block_size > 0.0f;
}

bool KubikChunkMesher::is_ready() const {
	return ready;
}

// STAGE 2: the palette crossed, so the parity harness compares colours too and
// its comparison is total.
bool KubikChunkMesher::has_colors() const {
	return true;
}

// --- Is the block at these chunk-local coordinates solid? ---------------------
//
// `chunk_mesher.gd:_solid_at` and `ColumnJob._solid_at` folded into one, with
// the fallback resolved ONCE PER BUILD instead of once per read. Coordinates run
// -1 to 16 on every axis: the mask asks one step outside a face, and a corner
// asks one step diagonally, and nothing in either mesher reaches further.
//
// THREE ANSWERS, IN THE ORDER THE GDSCRIPT ASKS THEM.
//
//   1. THE SHELL, when there is one. AO on reaches the diagonal neighbours a
//      six-face border cannot supply, so the dispatcher hands over the whole
//      18^3 solidity block and this reads straight out of it. The shell's
//      interior IS the chunk's own bytes, so taking this branch first changes
//      nothing about an interior read.
//   2. THE CHUNK'S OWN BYTES, for anything inside it.
//   3. THE FACE THE COORDINATE LEFT BY. Either the neighbour chunk's bytes,
//      which cost a reference to cross, or the generator's answer - and that is
//      `by < 0 or by <= floor(surface)`, one integer per block column. See
//      `column_job.gd`'s note for why an integer and not a float.
bool KubikChunkMesher::solid_at(const Borders &b, int x, int y, int z) const {
	if (b.shell != nullptr) {
		return b.shell[(x + 1) + (z + 1) * SHELL + (y + 1) * SHELL_SQ] != 0;
	}
	if (x >= 0 && x < SIZE && y >= 0 && y < SIZE && z >= 0 && z < SIZE) {
		return b.voxels[x + z * SIZE + y * SIZE_SQ] != 0;
	}
	const int32_t *strip = nullptr;
	int strip_at = 0;
	int64_t wy = b.origin_y + (int64_t)y;
	if (x >= SIZE) {
		if (b.n[0] != nullptr) {
			return b.n[0][0 + z * SIZE + y * SIZE_SQ] != 0;
		}
		strip = b.top_px;
		strip_at = z;
	} else if (x < 0) {
		if (b.n[1] != nullptr) {
			return b.n[1][(SIZE - 1) + z * SIZE + y * SIZE_SQ] != 0;
		}
		strip = b.top_nx;
		strip_at = z;
	} else if (y >= SIZE) {
		if (b.n[2] != nullptr) {
			return b.n[2][x + z * SIZE + 0] != 0;
		}
		strip = b.top_col;
		strip_at = x + z * SIZE;
		wy = b.origin_y + (int64_t)SIZE;
	} else if (y < 0) {
		if (b.n[3] != nullptr) {
			return b.n[3][x + z * SIZE + (SIZE - 1) * SIZE_SQ] != 0;
		}
		strip = b.top_col;
		strip_at = x + z * SIZE;
		wy = b.origin_y - 1;
	} else if (z >= SIZE) {
		if (b.n[4] != nullptr) {
			return b.n[4][x + 0 + y * SIZE_SQ] != 0;
		}
		strip = b.top_pz;
		strip_at = x;
	} else {
		if (b.n[5] != nullptr) {
			return b.n[5][x + (SIZE - 1) * SIZE + y * SIZE_SQ] != 0;
		}
		strip = b.top_nz;
		strip_at = x;
	}
	// Bedrock, so you cannot fall out of the world. TerrainGenerator.is_solid_at
	// asks this before it asks the surface, and so does this.
	if (wy < 0) {
		return true;
	}
	if (strip == nullptr) {
		// The dispatcher gave this face neither a neighbour nor a strip. Air is
		// the answer that draws a wall of faces at the seam, which is exactly
		// what the counter is for: a number in the build's result rather than a
		// mystery in a screenshot.
		b.missing++;
		return false;
	}
	return wy <= (int64_t)strip[strip_at];
}

bool KubikChunkMesher::solid_duv(const Borders &b, int d, int u, int v,
		int dd, int uu, int vv) const {
	int p[3] = { 0, 0, 0 };
	p[d] = dd;
	p[u] = uu;
	p[v] = vv;
	return solid_at(b, p[0], p[1], p[2]);
}

// `chunk_mesher.gd:_vertex_ao`. THE SPECIAL CASE IS THE WHOLE POINT: two solid
// sides give 0 whatever the diagonal does, because you cannot see past two
// walls meeting.
static inline int vertex_ao(bool side1, bool side2, bool corner) {
	if (side1 && side2) {
		return 0;
	}
	return 3 - ((side1 ? 1 : 0) + (side2 ? 1 : 0) + (corner ? 1 : 0));
}

int KubikChunkMesher::corner_ao(const Borders &b, int d, int u, int v,
		int air_d, int iu, int jv) const {
	const bool n00 = solid_duv(b, d, u, v, air_d, iu - 1, jv - 1);
	const bool n10 = solid_duv(b, d, u, v, air_d, iu, jv - 1);
	const bool n20 = solid_duv(b, d, u, v, air_d, iu + 1, jv - 1);
	const bool n01 = solid_duv(b, d, u, v, air_d, iu - 1, jv);
	const bool n21 = solid_duv(b, d, u, v, air_d, iu + 1, jv);
	const bool n02 = solid_duv(b, d, u, v, air_d, iu - 1, jv + 1);
	const bool n12 = solid_duv(b, d, u, v, air_d, iu, jv + 1);
	const bool n22 = solid_duv(b, d, u, v, air_d, iu + 1, jv + 1);
	return vertex_ao(n01, n10, n00)
			| (vertex_ao(n21, n10, n20) << 2)
			| (vertex_ao(n01, n12, n02) << 4)
			| (vertex_ao(n21, n12, n22) << 6);
}

// --- The rectangles -----------------------------------------------------------
//
// `chunk_mesher.gd:_emit_slice`, line for line. Grow right while the value AND
// the AO code repeat, then grow down while every cell of that width matches,
// emit, clear, advance. Greedy rather than optimal, and the AO code is part of
// the identity of a face so a run stops where the shading changes.
void KubikChunkMesher::emit_slice(int32_t *mask, const int32_t *ao_mask,
		int d, int u, int v, int plane, Sink &sink) const {
	for (int jv = 0; jv < SIZE; jv++) {
		int iu = 0;
		while (iu < SIZE) {
			const int32_t value = mask[iu + jv * SIZE];
			if (value == 0) {
				iu++;
				continue;
			}
			const int32_t ao_value = ao_mask[iu + jv * SIZE];

			int w = 1;
			while (iu + w < SIZE && mask[iu + w + jv * SIZE] == value
					&& ao_mask[iu + w + jv * SIZE] == ao_value) {
				w++;
			}

			int h = 1;
			while (jv + h < SIZE) {
				bool row_matches = true;
				for (int k = 0; k < w; k++) {
					if (mask[iu + k + (jv + h) * SIZE] != value
							|| ao_mask[iu + k + (jv + h) * SIZE] != ao_value) {
						row_matches = false;
						break;
					}
				}
				if (!row_matches) {
					break;
				}
				h++;
			}

			emit_quad(d, u, v, plane, iu, jv, w, h, value, ao_value, sink);

			for (int dv = 0; dv < h; dv++) {
				for (int du = 0; du < w; du++) {
					mask[iu + du + (jv + dv) * SIZE] = 0;
				}
			}
			iu += w;
		}
	}
}

// `chunk_mesher.gd:_emit_quad`. WINDING ORDER MATTERS: with (u, v, d)
// right-handed these two orders satisfy (p1 - p0) x (p2 - p0) == -normal, which
// is "clockwise seen from outside" - the face Godot draws. The second entry of
// each pair is the CANONICAL AO corner the vertex is, which is why the two lists
// are not reorderings of the same four points: the winding differs between
// facings and the AO code does not.
void KubikChunkMesher::emit_quad(int d, int u, int v, int plane,
		int u0, int v0, int w, int h, int value, int ao_value,
		Sink &sink) const {
	const bool positive = value > 0;
	const int id = value < 0 ? -value : value;

	Vector3 normal(0.0f, 0.0f, 0.0f);
	normal[d] = positive ? 1.0f : -1.0f;

	const int u1 = u0 + w;
	const int v1 = v0 + h;

	// { u, v, canonical AO corner }, in winding order.
	int corners[4][3];
	if (positive) {
		corners[0][0] = u0; corners[0][1] = v0; corners[0][2] = 0;
		corners[1][0] = u0; corners[1][1] = v1; corners[1][2] = 2;
		corners[2][0] = u1; corners[2][1] = v1; corners[2][2] = 3;
		corners[3][0] = u1; corners[3][1] = v0; corners[3][2] = 1;
	} else {
		corners[0][0] = u0; corners[0][1] = v0; corners[0][2] = 0;
		corners[1][0] = u1; corners[1][1] = v0; corners[1][2] = 1;
		corners[2][0] = u1; corners[2][1] = v1; corners[2][2] = 3;
		corners[3][0] = u0; corners[3][1] = v1; corners[3][2] = 2;
	}

	const int32_t first = (int32_t)sink.verts.size();
	for (int c = 0; c < 4; c++) {
		float p[3] = { 0.0f, 0.0f, 0.0f };
		p[d] = (float)plane;
		p[u] = (float)corners[c][0];
		p[v] = (float)corners[c][1];
		sink.verts.push_back(Vector3(p[0], p[1], p[2]) * block_size);
		sink.normals.push_back(normal);
		// THE COLOUR PATH IS AN INDEX AND NOTHING ELSE (Q3). The twin computes
		// `Look.to_wire(Block.color_of(id) * shade)` per vertex with
		// `shade = 1 - ao_strength * (1 - level / 3)`; GDScript evaluated that
		// same expression for all 256 ids at all 4 levels once per world and
		// handed the table over, so what happens here is a lookup. Two
		// compilers cannot round a lookup differently, which is why this gate
		// reads exact zero on Windows as well.
		const int level = (ao_value >> (corners[c][2] * 2)) & 3;
		sink.colors.push_back(palette[id * PALETTE_LEVELS + level]);
	}

	sink.indices.push_back(first);
	sink.indices.push_back(first + 1);
	sink.indices.push_back(first + 2);
	sink.indices.push_back(first);
	sink.indices.push_back(first + 2);
	sink.indices.push_back(first + 3);
}

// --- The sweep ----------------------------------------------------------------
//
// `chunk_mesher.gd:build_arrays_gd`, line for line. Three axes; for each of the
// 17 planes between and either side of the 16 layers, a 16 x 16 mask of which
// faces are visible and what colour they are, then rectangles taken out of it
// until it is empty. The DIRECTION IS THE SIGN of the mask value, which is what
// lets one pass handle both facings of a plane.
Dictionary KubikChunkMesher::build(const Dictionary &p_args) {
	Dictionary out;
	if (!ready) {
		return out;
	}

	Variant vv = p_args.get("voxels", Variant());
	if (vv.get_type() != Variant::PACKED_BYTE_ARRAY) {
		return out;
	}
	// The Packed arrays are held for the whole build: they are copy-on-write and
	// a raw pointer into one that went out of scope is the class of bug this
	// project cannot afford to debug across a thread boundary.
	const PackedByteArray voxels = vv;
	if (voxels.size() < VOLUME) {
		return out;
	}

	Borders b;
	b.voxels = voxels.ptr();
	b.origin_y = (int64_t)p_args.get("origin_y", Variant(0));

	static const char *N_KEYS[6] = {
		"n_px", "n_nx", "n_py", "n_ny", "n_pz", "n_nz"
	};
	PackedByteArray neighbours[6];
	for (int i = 0; i < 6; i++) {
		Variant nv = p_args.get(N_KEYS[i], Variant());
		if (nv.get_type() != Variant::PACKED_BYTE_ARRAY) {
			continue;
		}
		neighbours[i] = nv;
		if (neighbours[i].size() >= VOLUME) {
			b.n[i] = neighbours[i].ptr();
		}
	}

	static const char *T_KEYS[5] = {
		"top_col", "top_px", "top_nx", "top_pz", "top_nz"
	};
	const int32_t **T_SLOTS[5] = {
		&b.top_col, &b.top_px, &b.top_nx, &b.top_pz, &b.top_nz
	};
	const int T_SIZES[5] = { SIZE_SQ, SIZE, SIZE, SIZE, SIZE };
	PackedInt32Array strips[5];
	for (int i = 0; i < 5; i++) {
		Variant tv = p_args.get(T_KEYS[i], Variant());
		if (tv.get_type() != Variant::PACKED_INT32_ARRAY) {
			continue;
		}
		strips[i] = tv;
		if (strips[i].size() >= T_SIZES[i]) {
			*T_SLOTS[i] = strips[i].ptr();
		}
	}

	PackedByteArray shell;
	Variant sv = p_args.get("shell", Variant());
	if (sv.get_type() == Variant::PACKED_BYTE_ARRAY) {
		shell = sv;
		if (shell.size() >= SHELL_VOLUME) {
			b.shell = shell.ptr();
		}
	}

	// `chunk.gd` maintains has_solid and has_air CONSERVATIVELY - set true,
	// never cleared - so they are marshalled rather than derived: an edit can
	// leave has_air true for a chunk that is now solid throughout, and the twin
	// then sweeps seventeen planes where a scan would sweep two. Same output,
	// but "nearer today's behaviour" is the rule. The scan below is the fallback
	// for a caller that supplies neither.
	bool has_solid;
	bool has_air;
	Variant hs = p_args.get("has_solid", Variant());
	Variant ha = p_args.get("has_air", Variant());
	if (hs.get_type() != Variant::NIL && ha.get_type() != Variant::NIL) {
		has_solid = (bool)hs;
		has_air = (bool)ha;
	} else {
		has_solid = false;
		has_air = false;
		for (int i = 0; i < VOLUME; i++) {
			if (b.voxels[i] == 0) {
				has_air = true;
			} else {
				has_solid = true;
			}
		}
	}

	// A chunk with no solid blocks has no faces at all - not even at its
	// boundary, because a face is only ever drawn by the chunk that owns the
	// SOLID side of it. Most of a heightmap world is empty sky.
	if (!has_solid) {
		return out;
	}

	// A chunk with no air in it can only have faces where it meets the outside
	// world, so only the two outermost planes of each axis can carry any.
	const bool solid_throughout = !has_air;
	const bool want_ao = ao_strength > 0.0;

	int32_t mask[SIZE_SQ];
	int32_t ao_mask[SIZE_SQ];
	Sink sink;

	for (int d = 0; d < 3; d++) {
		const int u = AXIS_U[d];
		const int v = AXIS_V[d];

		// `slice` is the coordinate of the block on the NEGATIVE side of the
		// plane. It starts at -1 so the chunk's own outer face is considered,
		// and ends at SIZE - 1 so the far outer face is too.
		for (int slice = -1; slice < SIZE; slice++) {
			if (solid_throughout && slice != -1 && slice != SIZE - 1) {
				continue;
			}
			const bool a_in = slice >= 0;
			const bool b_in = slice + 1 < SIZE;
			bool has_face = false;

			for (int jv = 0; jv < SIZE; jv++) {
				for (int iu = 0; iu < SIZE; iu++) {
					int pa[3] = { 0, 0, 0 };
					pa[d] = slice;
					pa[u] = iu;
					pa[v] = jv;
					int pb[3] = { pa[0], pa[1], pa[2] };
					pb[d] = slice + 1;

					int id_a = 0;
					bool solid_a = false;
					if (a_in) {
						id_a = b.voxels[pa[0] + pa[2] * SIZE + pa[1] * SIZE_SQ];
						solid_a = id_a != 0;
					} else {
						solid_a = solid_at(b, pa[0], pa[1], pa[2]);
					}

					int id_b = 0;
					bool solid_b = false;
					if (b_in) {
						id_b = b.voxels[pb[0] + pb[2] * SIZE + pb[1] * SIZE_SQ];
						solid_b = id_b != 0;
					} else {
						solid_b = solid_at(b, pb[0], pb[1], pb[2]);
					}

					// A face exists only where solid meets air, and we draw it
					// only if the SOLID side is a block of ours - otherwise the
					// neighbouring chunk would draw the same face as well.
					int32_t m = 0;
					if (solid_a != solid_b) {
						if (solid_a) {
							if (a_in) {
								m = (int32_t)id_a; // faces along +d
							}
						} else if (b_in) {
							m = -(int32_t)id_b; // faces along -d
						}
					}
					mask[iu + jv * SIZE] = m;
					if (m != 0) {
						has_face = true;
						// AO is a question about the AIR side of the face.
						ao_mask[iu + jv * SIZE] = want_ao
								? corner_ao(b, d, u, v,
										m > 0 ? slice + 1 : slice, iu, jv)
								: AO_OPEN;
					} else {
						ao_mask[iu + jv * SIZE] = AO_OPEN;
					}
				}
			}

			if (has_face) {
				emit_slice(mask, ao_mask, d, u, v, slice + 1, sink);
			}
		}
	}

	if (sink.verts.empty()) {
		return out;
	}

	const int64_t n = (int64_t)sink.verts.size();
	PackedVector3Array verts;
	PackedVector3Array normals;
	PackedColorArray colors;
	PackedInt32Array indices;
	verts.resize(n);
	normals.resize(n);
	colors.resize(n);
	indices.resize((int64_t)sink.indices.size());
	{
		Vector3 *vp = verts.ptrw();
		Vector3 *np = normals.ptrw();
		Color *cp = colors.ptrw();
		int32_t *ip = indices.ptrw();
		for (int64_t k = 0; k < n; k++) {
			vp[k] = sink.verts[k];
			np[k] = sink.normals[k];
			cp[k] = sink.colors[k];
		}
		for (size_t k = 0; k < sink.indices.size(); k++) {
			ip[k] = sink.indices[k];
		}
	}

	out["verts"] = verts;
	out["normals"] = normals;
	out["colors"] = colors;
	out["indices"] = indices;
	out["quads"] = (int64_t)(n / 4);
	out["missing"] = b.missing;
	return out;
}
