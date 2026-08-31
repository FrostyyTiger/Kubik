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
	far_level_ref_m = cfg_f(d, "far_level_ref_m", far_level_ref_m);
	far_normal_m = cfg_f(d, "far_normal_m", far_normal_m);
	far_band_m = cfg_f(d, "far_band_m", far_band_m);
	far_band_step = cfg_f(d, "far_band_step", far_band_step);
	far_zone_cell_m = cfg_f(d, "far_zone_cell_m", far_zone_cell_m);
	far_zone_cell_ratio = cfg_f(d, "far_zone_cell_ratio", far_zone_cell_ratio);
	far_riser_shade = cfg_f(d, "far_riser_shade", far_riser_shade);
	far_riser_lift = cfg_f(d, "far_riser_lift", far_riser_lift);
	far_riser_axis = cfg_f(d, "far_riser_axis", far_riser_axis);

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

	slope_tint = cfg_f(d, "slope_tint", slope_tint);
	aspect_tint = cfg_f(d, "aspect_tint", aspect_tint);
	color_jitter_blocks = (int)cfg_f(d, "color_jitter_blocks", color_jitter_blocks);
	color_jitter_value = cfg_f(d, "color_jitter_value", color_jitter_value);
	color_jitter_hue = cfg_f(d, "color_jitter_hue", color_jitter_hue);
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

} // namespace kubik
