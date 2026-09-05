#include "far_world.h"

#include <godot_cpp/variant/array.hpp>

namespace kubik {

static double cfg_f(const Dictionary &p_d, const char *p_key, double p_default) {
	Variant v = p_d.get(String(p_key), Variant());
	if (v.get_type() == Variant::NIL) {
		return p_default;
	}
	return (double)v;
}

// EVERY KEY NAMED ONCE, and the default beside it is the one worldgen_config.gd
// declares. A missing key is then the config's own default rather than a silent
// zero - which is the failure mode a hand-written struct filled from a
// Dictionary has, and it would show up as a mesh that is subtly wrong rather
// than as an error.
void Config::read(const Dictionary &d) {
	block_size = cfg_f(d, "block_size", block_size);
	world_blocks_xz = (int)cfg_f(d, "world_blocks_xz", world_blocks_xz);
	coarse_step = (int)cfg_f(d, "coarse_step", coarse_step);
	far_step = (int)cfg_f(d, "far_step", far_step);
	voxel_radius_chunks = (int)cfg_f(d, "voxel_radius_chunks", voxel_radius_chunks);
	fog_end_m = cfg_f(d, "fog_end_m", fog_end_m);

	far_terrace = cfg_f(d, "far_terrace", far_terrace);
	far_step_y_blocks = cfg_f(d, "far_step_y_blocks", far_step_y_blocks);
	far_ring_div = cfg_f(d, "far_ring_div", far_ring_div);
	far_vote = cfg_f(d, "far_vote", far_vote);
	far_filter_bias = cfg_f(d, "far_filter_bias", far_filter_bias);
	far_peak_gain = cfg_f(d, "far_peak_gain", far_peak_gain);
	far_forest_blend = cfg_f(d, "far_forest_blend", far_forest_blend);
	far_level_ref_m = cfg_f(d, "far_level_ref_m", far_level_ref_m);
	far_normal_m = cfg_f(d, "far_normal_m", far_normal_m);
	far_zone_cell_m = cfg_f(d, "far_zone_cell_m", far_zone_cell_m);
	far_zone_cell_ratio = cfg_f(d, "far_zone_cell_ratio", far_zone_cell_ratio);
	far_geomorph_cells = cfg_f(d, "far_geomorph_cells", far_geomorph_cells);
	far_detail = cfg_f(d, "far_detail", far_detail);

	detail_amp = cfg_f(d, "detail_amp", detail_amp);
	detail_freq = cfg_f(d, "detail_freq", detail_freq);
	detail_flat_damp = cfg_f(d, "detail_flat_damp", detail_flat_damp);
	detail_flat_deg = cfg_f(d, "detail_flat_deg", detail_flat_deg);
	detail_full_deg = cfg_f(d, "detail_full_deg", detail_full_deg);
	shore_flat_blocks = cfg_f(d, "shore_flat_blocks", shore_flat_blocks);

	zone_blend_blocks = cfg_f(d, "zone_blend_blocks", zone_blend_blocks);
	zone_dither_blocks = (int)cfg_f(d, "zone_dither_blocks", zone_dither_blocks);
	zone_jitter_blocks = cfg_f(d, "zone_jitter_blocks", zone_jitter_blocks);
	slope_zone_strength = cfg_f(d, "slope_zone_strength", slope_zone_strength);
	snow_max_slope_deg = cfg_f(d, "snow_max_slope_deg", snow_max_slope_deg);
	rock_slope_deg = cfg_f(d, "rock_slope_deg", rock_slope_deg);
	wildness_rock_deg = cfg_f(d, "wildness_rock_deg", wildness_rock_deg);
	min_altitude = cfg_f(d, "min_altitude", min_altitude);
	max_altitude = cfg_f(d, "max_altitude", max_altitude);

}

static std::vector<float> to_floats(const Variant &p_v) {
	PackedFloat32Array a = p_v;
	std::vector<float> out;
	out.resize((size_t)a.size());
	if (a.size() > 0) {
		const float *p = a.ptr();
		for (int64_t i = 0; i < a.size(); i++) {
			out[(size_t)i] = p[i];
		}
	}
	return out;
}

// ONE COPY, ONCE PER WORLD LOAD. The pyramid is ~3 MB and the alternative is
// holding a PackedFloat32Array reference and paying its copy-on-write check on
// every read, tens of millions of times a rebuild. The world does not move
// while it is loaded - hard rule 8, nothing in C++ decides world truth - so a
// copy cannot go stale.
void World::setup(const Dictionary &d) {
	ready = false;
	cells = to_floats(d.get("cells", Variant()));
	cols = (int)(int64_t)d.get("cols", 0);
	hm_step = (int)(int64_t)d.get("hm_step", 4);
	min_block = (int)(int64_t)d.get("min_block", 0);
	max_block = min_block + (cols - 1) * hm_step;
	max_level = (int)(int64_t)d.get("max_level", 5);
	tile_blocks = (int)(int64_t)d.get("tile_blocks", 512);
	// THE TILE STORE IS EMPTIED, NOT MERGED, on a world load. Tiles are keyed
	// to the ORIGIN, so two worlds' tiles have the same keys and different
	// ground; carrying one world's over into the next is the one way this
	// store can be wrong rather than merely absent.
	tiles.clear();
	material_tiles.clear();
	cover_tiles.clear();
	add_tiles(d.get("tiles", Array()));

	// THE MATERIAL PYRAMID, Stage 4. Data, sent whole once per world.
	materials.clear();
	PackedByteArray mat0 = d.get("materials", PackedByteArray());
	materials.resize((size_t)mat0.size());
	for (int64_t i = 0; i < mat0.size(); i++) {
		materials[(size_t)i] = mat0[i];
	}
	cover.clear();
	PackedByteArray cv = d.get("cover", PackedByteArray());
	cover.resize((size_t)cv.size());
	for (int64_t i = 0; i < cv.size(); i++) {
		cover[(size_t)i] = cv[i];
	}
	cover_cols = (int)(int64_t)d.get("cover_cols", 0);
	canopy_color = d.get("canopy_color", Color(0.0284f, 0.0782f, 0.0482f));

	material_levels.clear();
	Array ml = d.get("material_levels", Array());
	for (int64_t i = 0; i < ml.size(); i++) {
		PackedByteArray one = ml[i];
		std::vector<uint8_t> v((size_t)one.size());
		for (int64_t k = 0; k < one.size(); k++) {
			v[(size_t)k] = one[k];
		}
		material_levels.push_back(v);
	}

	levels.clear();
	max_levels.clear();
	Array lv = d.get("levels", Array());
	Array mv = d.get("max_levels", Array());
	for (int64_t i = 0; i < lv.size(); i++) {
		levels.push_back(to_floats(lv[i]));
	}
	for (int64_t i = 0; i < mv.size(); i++) {
		max_levels.push_back(to_floats(mv[i]));
	}
	level_cols.clear();
	PackedInt32Array lc = d.get("level_cols", PackedInt32Array());
	for (int64_t i = 0; i < lc.size(); i++) {
		level_cols.push_back(lc[i]);
	}

	zone_thresholds = to_floats(d.get("zone_thresholds", Variant()));
	world_seed = (int64_t)d.get("world_seed", 0);

	shore_near.clear();
	PackedByteArray sn = d.get("shore_near", PackedByteArray());
	shore_near.resize((size_t)sn.size());
	for (int64_t i = 0; i < sn.size(); i++) {
		shore_near[(size_t)i] = sn[i];
	}
	shore_level = to_floats(d.get("shore_level", Variant()));

	zone_colors.clear();
	PackedColorArray zc = d.get("zone_colors", PackedColorArray());
	for (int64_t i = 0; i < zc.size(); i++) {
		zone_colors.push_back(zc[i]);
	}

	detail_noise = d.get("detail_noise", Variant());
	jitter_noise = d.get("jitter_noise", Variant());

	config.read(d.get("config", Dictionary()));

	// The pyramid must be complete before anything reads it: bilinear() indexes
	// levels[l - 1] without a bounds check, tens of millions of times a build,
	// and a missing level is a crash rather than a wrong mesh. If it is short,
	// the mesher stays unready and far_field.gd keeps GDScript.
	ready = cols > 0 && !cells.empty() &&
			(int)levels.size() >= max_level &&
			(int)max_levels.size() >= max_level &&
			(int)level_cols.size() >= max_level &&
			zone_colors.size() >= 7;
}

// ONE TILE OFF THE WIRE. The two arrays are copied for the reason the pyramid
// is: `tile_bilinear` indexes them tens of millions of times a build and a
// PackedFloat32Array read pays a copy-on-write check every time.
//
// A SHORT TILE IS DROPPED RATHER THAN STORED. `tile_bilinear` checks the size
// and answers NAN, and every caller then reads the region's rim, so a
// marshalling bug is a far mesh that looks like the old one instead of a
// crash - which is the same trade `is_ready()` makes for the pyramid.
void World::add_tile(int level, int tx, int tz, const PackedFloat32Array &mean,
		const PackedFloat32Array &high, const PackedByteArray &mat,
		const PackedByteArray &cov) {
	const int64_t want = (int64_t)TILE_STRIDE * (int64_t)TILE_STRIDE;
	if (mean.size() != want || high.size() != want) {
		return;
	}
	TileKey key;
	key.level = level;
	key.tx = tx;
	key.tz = tz;
	Tile t;
	t.mean.resize((size_t)want);
	t.high.resize((size_t)want);
	const float *mp = mean.ptr();
	const float *hp = high.ptr();
	for (int64_t i = 0; i < want; i++) {
		t.mean[(size_t)i] = mp[i];
		t.high[(size_t)i] = hp[i];
	}
	tiles[key] = t;
	// The material rides with the heights and is stored only when it is whole:
	// a short array is a tile whose material has not been built, and
	// `tile_material` answering -1 sends the read to the region rather than to
	// a byte that is not there.
	if (mat.size() == want) {
		std::vector<uint8_t> m((size_t)want);
		const uint8_t *bp = mat.ptr();
		for (int64_t i = 0; i < want; i++) {
			m[(size_t)i] = bp[i];
		}
		material_tiles[key] = m;
	}
	const int64_t cwant = (int64_t)cover_cols_for(TILE_CELLS)
			* (int64_t)cover_cols_for(TILE_CELLS);
	if (cov.size() == cwant) {
		std::vector<uint8_t> c((size_t)cwant);
		const uint8_t *cp = cov.ptr();
		for (int64_t i = 0; i < cwant; i++) {
			c[(size_t)i] = cp[i];
		}
		cover_tiles[key] = c;
	}
}

// The wire form: a flat Array of [level, tx, tz, mean, high, mat, cover, ...].
// Flat rather than an Array of Dictionaries because a build sends up to a few
// dozen of these and seven Variants each is cheaper than seven hash lookups.
void World::add_tiles(const Array &p_tiles) {
	for (int64_t i = 0; i + 6 < p_tiles.size(); i += 7) {
		add_tile((int)(int64_t)p_tiles[i], (int)(int64_t)p_tiles[i + 1],
				(int)(int64_t)p_tiles[i + 2],
				(PackedFloat32Array)p_tiles[i + 3],
				(PackedFloat32Array)p_tiles[i + 4],
				(PackedByteArray)p_tiles[i + 5],
				(PackedByteArray)p_tiles[i + 6]);
	}
}

void World::prune_tiles(const PackedInt32Array &p_keep) {
	// An empty list is "the view is empty", which is a real state at world
	// load and before the first publish - and dropping everything is the right
	// answer to it, because the GDScript leg would read the region's rim for
	// every position too.
	std::unordered_set<TileKey, TileKeyHash> live;
	live.reserve((size_t)(p_keep.size() / 3 + 1));
	for (int64_t i = 0; i + 2 < p_keep.size(); i += 3) {
		TileKey k;
		k.level = p_keep[i];
		k.tx = p_keep[i + 1];
		k.tz = p_keep[i + 2];
		live.insert(k);
	}
	for (auto it = tiles.begin(); it != tiles.end();) {
		if (live.find(it->first) == live.end()) {
			material_tiles.erase(it->first);
			cover_tiles.erase(it->first);
			it = tiles.erase(it);
		} else {
			++it;
		}
	}
}

} // namespace kubik
