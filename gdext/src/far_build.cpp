#include "far_build.h"

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>
#include <limits>
#include <unordered_map>
#include <vector>

namespace kubik {

// THE FAR MESHER, TRANSCRIBED FROM scripts/world/far_field_job.gd.
//
// Read that file for WHY any of this is shaped the way it is - every constant
// in it carries a war story and none of them is repeated here. What this file
// owes is that it computes the SAME NUMBERS, and the self-test's parity gate is
// what says whether it does. Where the GDScript does something that looks like
// an accident, it is transcribed as-is and the reason is noted: an "improved"
// expression is a failed gate, and a silently improved one is worse.
//
// THE THREE PLACES PRECISION IS DELIBERATE, because they are the three the
// gate would otherwise catch as mysteries:
//
//   1. THE CELL CACHE IS float32. `_t_h`, `_t_hq` and `_t_t` are
//      PackedFloat32Arrays, so a value stored and read back is TRUNCATED.
//   2. `_cell_h` RETURNS A DOUBLE ON THE COMPUTE PATH AND A float ON A CACHE
//      HIT. The GDScript returns the local `v` the first time and `_t_h[at]`
//      every time after. That asymmetry is visible in `_is_ridge`'s
//      comparisons, so the walk order is part of the output and is preserved
//      exactly.
//   3. VERTEX AND NORMAL MATHS GOES THROUGH godot::Vector3, whose arithmetic
//      is float32 in a single-precision build. A cross product done in double
//      and rounded at the end is a DIFFERENT normal from one done in float
//      throughout, and the difference survives normalize().

// --- The constants, from far_field_job.gd ------------------------------------

static constexpr double FOG_MARGIN = 1.2;
static const double RING_OUTER_M[5] = { 150.0, 300.0, 600.0, 1200.0, 2400.0 };
static const int RING_STEP_MULTIPLE[6] = { 1, 2, 4, 8, 16, 32 };
static constexpr int RING_COUNT = 6;
static constexpr double SKIRT_DEPTH_CELLS = 1.0;
static constexpr double SEAM_BAND_CELLS = 8.0;
static constexpr double TERRACE_FADE_CELLS = 12.0;
static constexpr double VOXEL_TOP_BIAS_BLOCKS = 0.5;
static constexpr double SEAM_SINK_BLOCKS = 3.0;
static constexpr int TERRACE_LEVEL_RING = 0;
static constexpr int RIDGE_SPAN_BLOCKS = 96;
static constexpr int RIDGE_SUBSTEP = 4;
static constexpr double INV_LN2 = 1.4426950408889634;
static constexpr int CHUNK_SIZE = 16;
static constexpr int FRONTIER_SECTORS = 16;

// FarFieldJob.ring_div / base_step_blocks.
static int ring_div(const Config &c) {
	if (c.far_ring_div >= 3.0) {
		return 4;
	}
	int v = (int)c.far_ring_div; // int() truncates toward zero, as GDScript does
	return v > 1 ? v : 1;
}

static int base_step_blocks(const Config &c) {
	int v = c.far_step / ring_div(c); // int division, both positive
	return v > 1 ? v : 1;
}

// World.frontier_sector_of, which FarFieldJob calls rather than copying - so
// this is the one place the copy exists, and it is a transcription of that
// static and of nothing else.
static int frontier_sector_of(int64_t dx, int64_t dz) {
	double a = Math::atan2((double)dz, (double)dx) + Math::PI;
	int s = (int)(a / Math::TAU * (double)FRONTIER_SECTORS);
	return s < 0 ? 0 : (s > FRONTIER_SECTORS - 1 ? FRONTIER_SECTORS - 1 : s);
}

// --- The builder ---------------------------------------------------------

struct Mesher {
	World &w;
	const Config &c;
	double bs;

	int64_t center_x = 0;
	int64_t center_z = 0;

	// FarFieldJob's members, by the same names.
	double seam_radius = 0.0;
	int64_t ring_cx = 0;
	int64_t ring_cz = 0;
	double t_amount = 0.0;
	double t_step_y = 0.0;
	double t_level = 0.0;
	int t_step = 0;
	double t_band = 0.0;
	bool t_full = false;
	int t_ridge = 1;
	int t_off = 0;
	int t_w = 0;
	std::vector<float> t_h;
	std::vector<float> t_hq;
	std::vector<float> t_t;
	std::vector<float> sector_exclude;

	// The output.
	std::vector<Vector3> verts;
	std::vector<Vector3> normals;
	std::vector<Color> colors;
	std::vector<int32_t> indices;

	explicit Mesher(World &p_w) :
			w(p_w), c(p_w.config), bs(p_w.config.block_size) {}

	// --- TerrainGenerator, the parts the far mesher reaches for -------------

	// TerrainGenerator._cell_index
	int64_t cell_index(double bx, double bz) const {
		int64_t i = (int64_t)Math::floor((bx - (double)w.min_block) / (double)w.hm_step);
		int64_t j = (int64_t)Math::floor((bz - (double)w.min_block) / (double)w.hm_step);
		if (i < 0 || j < 0 || i >= w.cols || j >= w.cols) {
			return -1;
		}
		return i + j * (int64_t)w.cols;
	}

	// Lakes.shore_level_at_cell. NAN means "no shore near this cell".
	double shore_level_at_cell(int64_t idx) const {
		if (w.shore_near.empty() || idx < 0 || idx >= (int64_t)w.shore_near.size()) {
			return std::numeric_limits<double>::quiet_NaN();
		}
		if (w.shore_near[(size_t)idx] == 0) {
			return std::numeric_limits<double>::quiet_NaN();
		}
		return w.shore_level[(size_t)idx];
	}

	// TerrainGenerator.detail_at. The ONE noise sample the far field pays for,
	// and the reason the seam band is deliberately narrow.
	double detail_at(double bx, double bz) const {
		double d = (double)w.detail_noise->get_noise_2d(bx, bz) * c.detail_amp;
		if (c.detail_flat_damp > 0.0) {
			double on_slope = Math::smoothstep(c.detail_flat_deg,
					c.detail_full_deg, w.slope_deg_at(bx, bz));
			d *= Math::lerp(1.0, on_slope, Math::clamp(c.detail_flat_damp, 0.0, 1.0));
		}
		if (w.shore_near.empty() || c.shore_flat_blocks <= 0.0) {
			return d;
		}
		double level = shore_level_at_cell(cell_index(bx, bz));
		if (Math::is_nan(level)) {
			return d;
		}
		double t = Math::clamp(Math::abs(w.height_at(bx, bz) - level)
						/ c.shore_flat_blocks, 0.0, 1.0);
		return d * t;
	}

	// --- FarFieldJob ------------------------------------------------------

	// _level_at
	double level_at(int64_t bx, int64_t bz, double band) const {
		double dx = (double)(bx - ring_cx);
		double dz = (double)(bz - ring_cz);
		double d_m = Math::sqrt(dx * dx + dz * dz) * bs;
		if (d_m <= 0.001) {
			return 0.0;
		}
		double level = Math::log(d_m / Math::max(c.far_level_ref_m, 1.0)) * INV_LN2
				+ c.far_filter_bias;
		level = Math::clamp(level, 0.0, (double)w.max_level);
		if (band > 0.0 && level > 0.0) {
			double sx = (double)(bx - center_x);
			double sz = (double)(bz - center_z);
			double blend = Math::clamp(
					1.0 - (Math::sqrt(sx * sx + sz * sz) - seam_radius) / band, 0.0, 1.0);
			level *= 1.0 - blend;
		}
		return level;
	}

	// _filtered
	double filtered(int64_t bx, int64_t bz, double band) const {
		double level = level_at(bx, bz, band);
		if (level <= 0.0) {
			return w.height_at((double)bx, (double)bz);
		}
		double mean = w.height_filtered((double)bx, (double)bz, level);
		double gain = c.far_peak_gain;
		if (gain <= 0.0) {
			return mean;
		}
		return Math::lerp(mean, w.height_max_filtered((double)bx, (double)bz, level), gain);
	}

	// _flank_normal
	Vector3 flank_normal(int64_t bx, int64_t bz) const {
		int64_t span = (int64_t)Math::round(c.far_normal_m / bs * 0.5);
		if (span < 1) {
			span = 1;
		}
		double dx = (filtered(bx + span, bz, 0.0) - filtered(bx - span, bz, 0.0)) * bs;
		double dz = (filtered(bx, bz + span, 0.0) - filtered(bx, bz - span, 0.0)) * bs;
		double run = (double)span * 2.0 * bs;
		return Vector3((real_t)-dx, (real_t)run, (real_t)-dz).normalized();
	}

	// _corner_y
	double corner_y(int64_t bx, int64_t bz, double coarse, double band,
			double y_offset) const {
		if (band <= 0.0) {
			return coarse * bs + y_offset;
		}
		double dx = (double)(bx - center_x);
		double dz = (double)(bz - center_z);
		double dist = Math::sqrt(dx * dx + dz * dz);
		double blend = Math::clamp(1.0 - (dist - seam_radius) / band, 0.0, 1.0);
		if (blend <= 0.0) {
			return coarse * bs + y_offset;
		}
		double h = coarse + (detail_at((double)bx, (double)bz) + VOXEL_TOP_BIAS_BLOCKS) * blend;
		double over = Math::clamp((seam_radius - dist) / band, 0.0, 1.0);
		return (h - over * SEAM_SINK_BLOCKS) * bs + y_offset * (1.0 - blend);
	}

	// _cell_h. Returns the freshly computed DOUBLE on the compute path and the
	// float32 out of the cache on a hit, exactly as the GDScript does - see the
	// note at the top of this file.
	double cell_h(int64_t i, int64_t j) {
		size_t at = (size_t)((i + t_off) + (j + t_off) * (int64_t)t_w);
		float cached = t_h[at];
		if (!Math::is_nan(cached)) {
			return (double)cached;
		}
		int64_t half = t_step / 2;
		double bx = (double)(ring_cx + i * (int64_t)t_step + half);
		double bz = (double)(ring_cz + j * (int64_t)t_step + half);
		double v = w.height_filtered(bx, bz, t_level);
		double gain = c.far_peak_gain;
		if (gain > 0.0) {
			v = Math::lerp(v, w.height_max_filtered(bx, bz, t_level), gain);
		}
		t_h[at] = (float)v;
		return v;
	}

	// _is_ridge
	bool is_ridge(int64_t i, int64_t j, double h) {
		int64_t r = t_ridge;
		return h >= cell_h(i - r, j) && h >= cell_h(i + r, j)
				&& h >= cell_h(i, j - r) && h >= cell_h(i, j + r);
	}

	// _terrace_at
	double terrace_at(int64_t i, int64_t j) const {
		if (t_band <= 0.0) {
			return t_amount;
		}
		int64_t half = t_step / 2;
		double dx = (double)(ring_cx + i * (int64_t)t_step + half - center_x);
		double dz = (double)(ring_cz + j * (int64_t)t_step + half - center_z);
		double band = t_band * TERRACE_FADE_CELLS / SEAM_BAND_CELLS;
		double blend = Math::clamp(
				1.0 - (Math::sqrt(dx * dx + dz * dz) - seam_radius) / band, 0.0, 1.0);
		return t_amount * (1.0 - blend);
	}

	// _cell. Returns the cache index, so the caller reads t_hq and t_t without
	// a second lookup - and reads them as float32, which is what they are.
	size_t cell(int64_t i, int64_t j) {
		size_t at = (size_t)((i + t_off) + (j + t_off) * (int64_t)t_w);
		if (!Math::is_nan(t_hq[at])) {
			return at;
		}
		double step = t_step_y > 0.0 ? t_step_y : (double)t_step;
		double h = cell_h(i, j);
		if (is_ridge(i, j, h)) {
			double fine = Math::max(step / (double)RIDGE_SUBSTEP, 1.0);
			t_hq[at] = (float)(Math::ceil(h / fine) * fine);
		} else {
			t_hq[at] = (float)(Math::round(h / step) * step);
		}
		t_t[at] = (float)terrace_at(i, j);
		return at;
	}

	// _in_ring
	bool in_ring(int64_t bx0, int64_t bz0, int step, double inner, double outer) const {
		double dx = (double)(bx0 + step / 2 - center_x);
		double dz = (double)(bz0 + step / 2 - center_z);
		double d_sq = dx * dx + dz * dz;
		if (d_sq >= outer * outer) {
			return false;
		}
		double hole = inner;
		if (!sector_exclude.empty() && inner <= seam_radius) {
			int s = frontier_sector_of(bx0 + step / 2 - center_x,
					bz0 + step / 2 - center_z);
			double e = (double)sector_exclude[(size_t)s];
			hole = Math::min(inner, e);
		}
		return d_sq >= hole * hole;
	}

	// _push_quad. The normal is derived from the winding unless a lighting
	// normal is handed in, so the identity the whole mesher rests on -
	// (p1 - p0) x (p2 - p0) == -normal - holds by construction.
	void push_quad(const Vector3 &p0, const Vector3 &p1, const Vector3 &p2,
			const Vector3 &p3, const Color &color,
			const Vector3 &lighting_normal = Vector3()) {
		Vector3 normal = -((p1 - p0).cross(p2 - p0));
		if (normal.length_squared() < (real_t)0.000001) {
			normal = Vector3(0, 1, 0);
		} else {
			normal = normal.normalized();
		}
		if (lighting_normal != Vector3()) {
			normal = lighting_normal;
		}
		int32_t first = (int32_t)verts.size();
		const Vector3 quad[4] = { p0, p1, p2, p3 };
		for (int k = 0; k < 4; k++) {
			verts.push_back(quad[k]);
			normals.push_back(normal);
			colors.push_back(shade_vertex(color, normal, quad[k]));
		}
		indices.push_back(first);
		indices.push_back(first + 1);
		indices.push_back(first + 2);
		indices.push_back(first);
		indices.push_back(first + 2);
		indices.push_back(first + 3);
	}

	// STAGE 3 EMITS WHITE. The aspect shade, the jitter and the wire conversion
	// are Stage 4's, and until they land the parity harness compares positions,
	// normals and indices and is told to skip colours - which is why
	// has_colors() exists rather than the harness guessing.
	Color shade_vertex(const Color &color, const Vector3 &normal,
			const Vector3 &p) const {
		(void)normal;
		(void)p;
		return color;
	}

	// _push_riser, and _push_skirt through it with equal depths.
	void push_riser(const Vector3 &a, const Vector3 &b, double drop_a, double drop_b,
			const Color &color, bool both_sides = true) {
		Vector3 a_down = a - Vector3(0, (real_t)drop_a, 0);
		Vector3 b_down = b - Vector3(0, (real_t)drop_b, 0);
		push_quad(a_down, b_down, b, a, color);
		if (both_sides) {
			push_quad(a, b, b_down, a_down, color);
		}
	}

	void build_ring(int ring, int step, double inner, double outer, double y_offset);
	void run(const Dictionary &args);
};

void Mesher::build_ring(int ring, int step, double inner, double outer,
		double y_offset) {
	// Snap the centre to THIS RING'S grid - see far_field_job.gd.
	int64_t cx = (int64_t)Math::floor((double)center_x / (double)step) * step;
	int64_t cz = (int64_t)Math::floor((double)center_z / (double)step) * step;
	ring_cx = cx;
	ring_cz = cz;

	int64_t span = (int64_t)Math::ceil(outer / (double)step) + 1;
	double skirt_drop = (double)step * (SKIRT_DEPTH_CELLS + t_amount) * bs;
	double band = ring == 0 ? (double)step * SEAM_BAND_CELLS : 0.0;

	t_step = step;
	t_band = band;
	t_full = t_amount >= 1.0 && band <= 0.0;
	if (t_amount > 0.0) {
		t_ridge = RIDGE_SPAN_BLOCKS / step;
		if (t_ridge < 1) {
			t_ridge = 1;
		}
		t_off = (int)(span + t_ridge + 1);
		t_w = 2 * t_off + 1;
		size_t n = (size_t)t_w * (size_t)t_w;
		const float nan = std::numeric_limits<float>::quiet_NaN();
		t_h.assign(n, nan);
		t_hq.assign(n, nan);
		t_t.assign(n, 0.0f);
	}

	const Color white(1, 1, 1, 1);

	for (int64_t j = -span; j < span; j++) {
		for (int64_t i = -span; i < span; i++) {
			int64_t bx0 = cx + i * step;
			int64_t bz0 = cz + j * step;
			if (!in_ring(bx0, bz0, step, inner, outer)) {
				continue;
			}
			if (!w.in_bounds(bx0, bz0)) {
				continue;
			}
			int64_t bx1 = bx0 + step;
			int64_t bz1 = bz0 + step;

			double h00, h10, h11, h01;
			double r00 = 0.0, r10 = 0.0, r11 = 0.0, r01 = 0.0;
			double terr = 0.0;
			double hq = 0.0;
			double mid_true = 0.0;
			if (t_full) {
				size_t at = cell(i, j);
				hq = (double)t_hq[at];
				mid_true = cell_h(i, j);
				terr = 1.0;
				h00 = hq;
				h10 = hq;
				h11 = hq;
				h01 = hq;
			} else {
				h00 = filtered(bx0, bz0, band);
				h10 = filtered(bx1, bz0, band);
				h11 = filtered(bx1, bz1, band);
				h01 = filtered(bx0, bz1, band);
				r00 = h00;
				r10 = h10;
				r11 = h11;
				r01 = h01;
				mid_true = (h00 + h10 + h11 + h01) * 0.25;
				if (t_amount > 0.0) {
					size_t at = cell(i, j);
					terr = (double)t_t[at];
					hq = (double)t_hq[at];
					if (terr > 0.0) {
						h00 = Math::lerp(h00, hq, terr);
						h10 = Math::lerp(h10, hq, terr);
						h11 = Math::lerp(h11, hq, terr);
						h01 = Math::lerp(h01, hq, terr);
					}
				}
			}
			(void)mid_true; // Stage 4: the zone reads the unquantised height.

			Vector3 p0((real_t)((double)bx0 * bs),
					(real_t)corner_y(bx0, bz0, h00, band, y_offset),
					(real_t)((double)bz0 * bs));
			Vector3 p1((real_t)((double)bx1 * bs),
					(real_t)corner_y(bx1, bz0, h10, band, y_offset),
					(real_t)((double)bz0 * bs));
			Vector3 p2((real_t)((double)bx1 * bs),
					(real_t)corner_y(bx1, bz1, h11, band, y_offset),
					(real_t)((double)bz1 * bs));
			Vector3 p3((real_t)((double)bx0 * bs),
					(real_t)corner_y(bx0, bz1, h01, band, y_offset),
					(real_t)((double)bz1 * bs));

			Color color = white; // Stage 4.
			Vector3 flank = flank_normal(bx0 + step / 2, bz0 + step / 2);
			push_quad(p0, p1, p2, p3, color, flank);

			// One skirt per edge whose neighbour is not in this ring, and one
			// riser per edge whose neighbour is in this ring and lower.
			struct Edge {
				const Vector3 *a;
				const Vector3 *b;
				int64_t dbx;
				int64_t dbz;
				int di;
				int dj;
				double ra;
				double rb;
			};
			const Edge edges[4] = {
				{ &p0, &p1, 0, -(int64_t)step, 0, -1, r00, r10 },
				{ &p1, &p2, (int64_t)step, 0, 1, 0, r10, r11 },
				{ &p2, &p3, 0, (int64_t)step, 0, 1, r11, r01 },
				{ &p3, &p0, -(int64_t)step, 0, -1, 0, r01, r00 },
			};
			Color shaded = color; // Stage 4: SKIRT_SHADE.

			for (int e = 0; e < 4; e++) {
				const Edge &ed = edges[e];
				int64_t nbx = bx0 + ed.dbx;
				int64_t nbz = bz0 + ed.dbz;
				if (!in_ring(nbx, nbz, step, inner, outer)) {
					push_riser(*ed.a, *ed.b, skirt_drop, skirt_drop, shaded);
					continue;
				}
				if (t_amount <= 0.0) {
					continue;
				}
				if (!w.in_bounds(nbx, nbz)) {
					continue;
				}
				size_t nat = cell(i + ed.di, j + ed.dj);
				double nt = (double)t_t[nat];
				double nq = (double)t_hq[nat];
				Color riser = color; // Stage 4: the lift, the axis, the shade.
				double da, db;
				if (t_full) {
					da = hq - nq;
					db = da;
				} else {
					da = Math::lerp(ed.ra, hq, terr) - Math::lerp(ed.ra, nq, nt);
					db = Math::lerp(ed.rb, hq, terr) - Math::lerp(ed.rb, nq, nt);
				}
				if (da <= 0.0 && db <= 0.0) {
					continue;
				}
				push_riser(*ed.a, *ed.b, Math::max(da, 0.0) * bs,
						Math::max(db, 0.0) * bs, riser);
			}
		}
	}
}

void Mesher::run(const Dictionary &args) {
	center_x = (int64_t)args.get("center_x", 0);
	center_z = (int64_t)args.get("center_z", 0);
	int64_t overlap_cells = (int64_t)args.get("overlap_cells", 8);
	PackedInt32Array frontier = args.get("frontier", PackedInt32Array());

	bs = c.block_size;
	int base_step = base_step_blocks(c);
	double far_radius = c.fog_end_m / bs * FOG_MARGIN;
	t_amount = Math::clamp(c.far_terrace, 0.0, 1.0);
	t_step_y = Math::max(c.far_step_y_blocks, 0.0);

	int tlr = TERRACE_LEVEL_RING < 0 ? 0
									 : (TERRACE_LEVEL_RING > RING_COUNT - 1 ? RING_COUNT - 1
																			: TERRACE_LEVEL_RING);
	t_level = Math::clamp(
			Math::log((double)(base_step * RING_STEP_MULTIPLE[tlr]) / (double)w.hm_step)
							* INV_LN2 + c.far_filter_bias,
			0.0, (double)w.max_level);

	double voxel_radius_blocks = (double)(c.voxel_radius_chunks * CHUNK_SIZE);
	seam_radius = Math::max(voxel_radius_blocks - (double)(2 * base_step), 0.0);
	double exclude = Math::max(
			voxel_radius_blocks - (double)(overlap_cells * base_step), 0.0);

	sector_exclude.clear();
	if (frontier.size() > 0) {
		sector_exclude.resize((size_t)frontier.size());
		for (int64_t i = 0; i < frontier.size(); i++) {
			sector_exclude[(size_t)i] = (float)Math::max(
					(double)(frontier[i] * CHUNK_SIZE)
							- (double)(overlap_cells * base_step), 0.0);
		}
	}

	double y_offset = -0.5 * c.detail_amp * bs;

	double inner = exclude;
	for (int ring = 0; ring < RING_COUNT; ring++) {
		int step = base_step * RING_STEP_MULTIPLE[ring];
		double outer = far_radius;
		if (ring < 5) {
			outer = Math::min(RING_OUTER_M[ring] / bs, far_radius);
		}
		if (outer <= inner) {
			inner = Math::max(inner, outer);
			continue;
		}
		build_ring(ring, step, inner, outer, y_offset);
		inner = outer;
	}
}

Dictionary build_far_mesh(World &p_world, const Dictionary &p_args) {
	Dictionary out;
	uint64_t t0 = Time::get_singleton()->get_ticks_msec();

	// The live knobs, re-read every build for the reason FarFieldJob re-reads
	// them: the main thread can move one while this worker runs, and a value
	// that changed half way through would terrace half a mesh.
	Variant cfg = p_args.get("config", Variant());
	if (cfg.get_type() == Variant::DICTIONARY) {
		p_world.config.read(cfg);
	}

	Mesher m(p_world);
	m.run(p_args);

	Array arrays;
	if (!m.verts.empty()) {
		PackedVector3Array v;
		PackedVector3Array n;
		PackedColorArray col;
		PackedInt32Array idx;
		v.resize((int64_t)m.verts.size());
		n.resize((int64_t)m.normals.size());
		col.resize((int64_t)m.colors.size());
		idx.resize((int64_t)m.indices.size());
		{
			Vector3 *vp = v.ptrw();
			Vector3 *np = n.ptrw();
			Color *cp = col.ptrw();
			int32_t *ip = idx.ptrw();
			for (size_t k = 0; k < m.verts.size(); k++) {
				vp[k] = m.verts[k];
				np[k] = m.normals[k];
				cp[k] = m.colors[k];
			}
			for (size_t k = 0; k < m.indices.size(); k++) {
				ip[k] = m.indices[k];
			}
		}
		arrays.resize(Mesh::ARRAY_MAX);
		arrays[Mesh::ARRAY_VERTEX] = v;
		arrays[Mesh::ARRAY_NORMAL] = n;
		arrays[Mesh::ARRAY_COLOR] = col;
		arrays[Mesh::ARRAY_INDEX] = idx;
	}

	out["arrays"] = arrays;
	out["vertex_count"] = (int64_t)m.verts.size();
	out["elapsed_ms"] = (int64_t)(Time::get_singleton()->get_ticks_msec() - t0);
	return out;
}

} // namespace kubik
