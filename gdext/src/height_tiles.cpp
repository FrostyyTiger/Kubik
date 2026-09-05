#include "height_tiles.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void KubikHeightTiles::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "world"), &KubikHeightTiles::setup);
	ClassDB::bind_method(D_METHOD("is_ready"), &KubikHeightTiles::is_ready);
	ClassDB::bind_method(D_METHOD("build_tile", "args"),
			&KubikHeightTiles::build_tile);
	ClassDB::bind_method(D_METHOD("height_at_block", "bx", "bz"),
			&KubikHeightTiles::height_at_block);
	ClassDB::bind_method(D_METHOD("setup_zones", "world"),
			&KubikHeightTiles::setup_zones);
	ClassDB::bind_method(D_METHOD("zones_ready"), &KubikHeightTiles::zones_ready);
	ClassDB::bind_method(D_METHOD("build_materials", "args"),
			&KubikHeightTiles::build_materials);
}

void KubikHeightTiles::setup_zones(const Dictionary &d) {
	zones.setup(d);
	zones_set = zones.zone_thresholds.size() > 0 && zones.jitter_noise.is_valid();
}

PackedByteArray KubikHeightTiles::build_materials(const Dictionary &args) const {
	PackedByteArray out;
	if (!zones_set) {
		return out;
	}
	int64_t bx0 = (int64_t)args.get("bx0", 0);
	int64_t bz0 = (int64_t)args.get("bz0", 0);
	int64_t cols = (int64_t)args.get("cols", 0);
	int64_t rows = (int64_t)args.get("rows", 0);
	int64_t step = (int64_t)args.get("step", 4);
	PackedFloat32Array heights = args.get("heights", PackedFloat32Array());
	if (cols <= 1 || rows <= 1 || heights.size() != cols * rows) {
		return out;
	}
	out.resize(cols * rows);
	uint8_t *p = out.ptrw();
	const float *h = heights.ptr();
	double inv = 1.0 / (2.0 * (double)step);
	double edge = 1.0 / (double)step;
	for (int64_t j = 0; j < rows; j++) {
		int64_t bz = bz0 + j * step;
		int64_t row = j * cols;
		int64_t up = (j > 0 ? j - 1 : j) * cols;
		int64_t dn = (j < rows - 1 ? j + 1 : j) * cols;
		double jscale = (j > 0 && j < rows - 1) ? inv : edge;
		for (int64_t i = 0; i < cols; i++) {
			int64_t i0 = i > 0 ? i - 1 : i;
			int64_t i1 = i < cols - 1 ? i + 1 : i;
			double iscale = (i > 0 && i < cols - 1) ? inv : edge;
			double gx = ((double)h[row + i1] - (double)h[row + i0]) * iscale;
			double gz = ((double)h[dn + i] - (double)h[up + i]) * jscale;
			double slope = Math::rad_to_deg(Math::atan(Math::sqrt(gx * gx + gz * gz)));
			p[row + i] = (uint8_t)zones.surface_zone_with(bx0 + i * step, bz,
					(double)h[row + i], slope);
		}
	}
	return out;
}

static double cfg_f(const Dictionary &d, const char *key, double fallback) {
	Variant v = d.get(String(key), Variant());
	if (v.get_type() == Variant::NIL) {
		return fallback;
	}
	return (double)v;
}

void KubikHeightTiles::setup(const Dictionary &d) {
	ready = false;
	continent = d.get("continent", Variant());
	mountain = d.get("mountain", Variant());
	hills = d.get("hills", Variant());
	warp_x = d.get("warp_x", Variant());
	warp_z = d.get("warp_z", Variant());
	hills_mask = d.get("hills_mask", Variant());
	bench_mask = d.get("bench_mask", Variant());
	plateau_mask = d.get("plateau_mask", Variant());

	Dictionary c = d.get("config", Dictionary());
	base_altitude = cfg_f(c, "base_altitude", base_altitude);
	continent_amp = cfg_f(c, "continent_amp", continent_amp);
	mountain_freq = cfg_f(c, "mountain_freq", mountain_freq);
	mountain_amp = cfg_f(c, "mountain_amp", mountain_amp);
	mountain_mask_lo = cfg_f(c, "mountain_mask_lo", mountain_mask_lo);
	mountain_mask_hi = cfg_f(c, "mountain_mask_hi", mountain_mask_hi);
	hills_amp = cfg_f(c, "hills_amp", hills_amp);
	hills_gate_strength = cfg_f(c, "hills_gate_strength", hills_gate_strength);
	hills_mask_lo = cfg_f(c, "hills_mask_lo", hills_mask_lo);
	hills_mask_hi = cfg_f(c, "hills_mask_hi", hills_mask_hi);
	wildness_relief = cfg_f(c, "wildness_relief", wildness_relief);
	warp_strength = cfg_f(c, "warp_strength", warp_strength);
	valley_curve = cfg_f(c, "valley_curve", valley_curve);
	terrace_height = cfg_f(c, "terrace_height", terrace_height);
	terrace_sharpness = cfg_f(c, "terrace_sharpness", terrace_sharpness);
	bench_strength = cfg_f(c, "bench_strength", bench_strength);
	bench_height = cfg_f(c, "bench_height", bench_height);
	plateau_strength = cfg_f(c, "plateau_strength", plateau_strength);
	plateau_height = cfg_f(c, "plateau_height", plateau_height);
	min_altitude = cfg_f(c, "min_altitude", min_altitude);
	max_altitude = cfg_f(c, "max_altitude", max_altitude);
	world_blocks_xz = (int)cfg_f(c, "world_blocks_xz", world_blocks_xz);

	// EVERY FIELD OR NONE. A missing noise object is a null deref on the first
	// cell, tens of millions of times a build, and the answer to one is to keep
	// GDScript rather than to try - the same rule far_mesher.gd's is_ready()
	// enforces on the pyramid.
	ready = continent.is_valid() && mountain.is_valid() && hills.is_valid() &&
			warp_x.is_valid() && warp_z.is_valid() && hills_mask.is_valid() &&
			bench_mask.is_valid() && plateau_mask.is_valid();
}

bool KubikHeightTiles::is_ready() const {
	return ready;
}

// TerrainGenerator.wildness_at
double KubikHeightTiles::wildness_at(double bx, double bz) const {
	double half = (double)world_blocks_xz * 0.5;
	if (half <= 0.0) {
		return 0.0;
	}
	return Math::clamp(Math::max(Math::abs(bx), Math::abs(bz)) / half, 0.0, 1.0);
}

// TerrainGenerator._hills_gate
double KubikHeightTiles::hills_gate(double wx, double wz) const {
	if (hills_gate_strength <= 0.0) {
		return 1.0;
	}
	double mask = Math::smoothstep(hills_mask_lo, hills_mask_hi,
			(double)hills_mask->get_noise_2d(wx, wz));
	return Math::lerp(1.0, mask, Math::clamp(hills_gate_strength, 0.0, 1.0));
}

// TerrainGenerator._flatten_valleys
double KubikHeightTiles::flatten_valleys(double h) const {
	double lo = min_altitude;
	double hi = max_altitude;
	double t = (h - lo) / (hi - lo);
	t = Math::clamp(t, 0.0, 1.0);
	t = Math::pow(t, valley_curve);
	return lo + t * (hi - lo);
}

// TerrainGenerator._terrace
double KubikHeightTiles::terrace(double h) const {
	if (terrace_height <= 0.0) {
		return h;
	}
	double t = h / terrace_height;
	double shelf = Math::floor(t);
	double frac = t - shelf;
	double curved = Math::pow(frac, Math::max(terrace_sharpness, 0.001));
	return (shelf + Math::smoothstep(0.0, 1.0, curved)) * terrace_height;
}

// TerrainGenerator._masked_terrace. `band_lo`/`band_hi` arrive as float32
// because BENCH_ALTITUDE_BAND and PLATEAU_ALTITUDE_BAND are Vector2s, and a
// Vector2 is float32 in a single-precision build - see the header.
double KubikHeightTiles::masked_terrace(double h, double wx, double wz,
		const Ref<FastNoiseLite> &mask, double strength, double height,
		float band_lo, float band_hi) const {
	if (height <= 0.0) {
		return h;
	}
	double t = (h - min_altitude) / Math::max(max_altitude - min_altitude, 0.001);
	double lo = (double)band_lo;
	double hi = (double)band_hi;
	double fade = (hi - lo) * MASKED_BAND_FADE;
	double in_band = Math::smoothstep(lo, lo + fade, t) *
			(1.0 - Math::smoothstep(hi - fade, hi, t));
	if (in_band <= 0.0) {
		return h;
	}
	// TerrainGenerator._bench_placement, inlined - it is one smoothstep and
	// ignores its two position arguments.
	double where = Math::smoothstep(0.1, 0.55, (double)mask->get_noise_2d(wx, wz));
	double amount = Math::clamp(strength, 0.0, 1.0) * in_band * where;
	if (amount <= 0.0) {
		return h;
	}
	double t_shelf = h / height;
	double shelf = Math::floor(t_shelf);
	double frac = t_shelf - shelf;
	double curved = Math::pow(frac, 4.0);
	double stepped = (shelf + Math::smoothstep(0.0, 1.0, curved)) * height;
	return Math::lerp(h, stepped, amount);
}

// TerrainGenerator._benches_and_plateaus
double KubikHeightTiles::benches_and_plateaus(double h, double wx, double wz) const {
	double out = h;
	if (bench_strength > 0.0) {
		out = masked_terrace(out, wx, wz, bench_mask, bench_strength,
				bench_height, BENCH_BAND_LO, BENCH_BAND_HI);
	}
	if (plateau_strength > 0.0) {
		out = masked_terrace(out, wx, wz, plateau_mask, plateau_strength,
				plateau_height, PLATEAU_BAND_LO, PLATEAU_BAND_HI);
	}
	return out;
}

// TerrainGenerator.height_at_block, MINUS the quantisation - so the micro-gate
// can compare the raw expression too and say whether a disagreement was there
// before the rounding hid it.
double KubikHeightTiles::raw_height(double bx, double bz) const {
	// TerrainGenerator._domain_warp. THE Vector2 IS THE POINT: the GDScript
	// builds one, and a Vector2 is float32, so both components are TRUNCATED
	// before they are added to bx and bz. Done in double throughout, the warp
	// lands a fraction of a millimetre elsewhere and the whole map drifts.
	Vector2 warp((real_t)((double)warp_x->get_noise_2d(bx, bz) * warp_strength),
			(real_t)((double)warp_z->get_noise_2d(bx, bz) * warp_strength));
	double wx = bx + (double)warp.x;
	double wz = bz + (double)warp.y;

	double h = base_altitude;
	double cont = (double)continent->get_noise_2d(wx, wz);
	h += cont * continent_amp;
	double massif = Math::smoothstep(mountain_mask_lo, mountain_mask_hi, cont);
	h += ridge((double)mountain->get_noise_2d(wx, wz)) * mountain_amp * massif *
			(1.0 + wildness_relief * wildness_at(bx, bz));
	h += (double)hills->get_noise_2d(wx, wz) * hills_amp * hills_gate(wx, wz);
	h = flatten_valleys(h);
	h = terrace(h);
	h = benches_and_plateaus(h, wx, wz);
	return Math::clamp(h, min_altitude, max_altitude);
}

double KubikHeightTiles::height_at_block(double bx, double bz) const {
	if (!ready) {
		return 0.0;
	}
	return Math::round(raw_height(bx, bz) * QUANTUM) / QUANTUM;
}

PackedFloat32Array KubikHeightTiles::build_tile(const Dictionary &args) const {
	PackedFloat32Array out;
	if (!ready) {
		return out;
	}
	int64_t bx0 = (int64_t)args.get("bx0", 0);
	int64_t bz0 = (int64_t)args.get("bz0", 0);
	int64_t cols = (int64_t)args.get("cols", 0);
	int64_t rows = (int64_t)args.get("rows", 0);
	int64_t step = (int64_t)args.get("step", 4);
	if (cols <= 0 || rows <= 0) {
		return out;
	}
	out.resize(cols * rows);
	float *p = out.ptrw();
	// j (z) outer, i (x) inner, so it walks the array front to back - the same
	// order build_heightmap() has walked since terrain v1. Order does not
	// change the answer here (every cell is a pure function of its own
	// position) and it does change the cache behaviour.
	for (int64_t j = 0; j < rows; j++) {
		double bz = (double)(bz0 + j * step);
		int64_t row = j * cols;
		for (int64_t i = 0; i < cols; i++) {
			double bx = (double)(bx0 + i * step);
			p[row + i] = (float)(Math::round(raw_height(bx, bz) * QUANTUM) / QUANTUM);
		}
	}
	return out;
}
