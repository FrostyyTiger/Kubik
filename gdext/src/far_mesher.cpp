#include "far_mesher.h"

#include <godot_cpp/core/class_db.hpp>

#include "far_build.h"

using namespace godot;

void KubikFarMesher::_bind_methods() {
	ClassDB::bind_method(D_METHOD("ping"), &KubikFarMesher::ping);
	ClassDB::bind_method(D_METHOD("bench_sum", "values"),
			&KubikFarMesher::bench_sum);
	ClassDB::bind_method(D_METHOD("setup", "world"), &KubikFarMesher::setup);
	ClassDB::bind_method(D_METHOD("is_ready"), &KubikFarMesher::is_ready);
	ClassDB::bind_method(D_METHOD("h_at", "bx", "bz"), &KubikFarMesher::h_at);
	ClassDB::bind_method(D_METHOD("h_filtered", "bx", "bz", "level"),
			&KubikFarMesher::h_filtered);
	ClassDB::bind_method(D_METHOD("h_max_filtered", "bx", "bz", "level"),
			&KubikFarMesher::h_max_filtered);
	ClassDB::bind_method(D_METHOD("h_peak", "bx", "bz", "level"),
			&KubikFarMesher::h_peak);
	ClassDB::bind_method(D_METHOD("h_slope_deg", "bx", "bz"),
			&KubikFarMesher::h_slope_deg);
	ClassDB::bind_method(D_METHOD("build", "args"), &KubikFarMesher::build);
	ClassDB::bind_method(D_METHOD("has_colors"), &KubikFarMesher::has_colors);
}

String KubikFarMesher::ping() const {
	return "kubik far mesher, C++";
}

double KubikFarMesher::bench_sum(const PackedFloat32Array &p_values) const {
	const float *ptr = p_values.ptr();
	const int64_t n = p_values.size();
	double sum = 0.0;
	for (int64_t i = 0; i < n; i++) {
		sum += ptr[i];
	}
	return sum;
}

void KubikFarMesher::setup(const Dictionary &p_world) {
	world.setup(p_world);
}

bool KubikFarMesher::is_ready() const {
	return world.ready;
}

double KubikFarMesher::h_at(double p_bx, double p_bz) const {
	return world.height_at(p_bx, p_bz);
}

double KubikFarMesher::h_filtered(double p_bx, double p_bz, double p_level) const {
	return world.height_filtered(p_bx, p_bz, p_level);
}

double KubikFarMesher::h_max_filtered(double p_bx, double p_bz, double p_level) const {
	return world.height_max_filtered(p_bx, p_bz, p_level);
}

double KubikFarMesher::h_peak(double p_bx, double p_bz, double p_level) const {
	return world.filtered_height(p_bx, p_bz, p_level);
}

double KubikFarMesher::h_slope_deg(double p_bx, double p_bz) const {
	return world.slope_deg_at(p_bx, p_bz);
}

Dictionary KubikFarMesher::build(const Dictionary &p_args) {
	return kubik::build_far_mesh(world, p_args);
}

// STAGE 3: geometry only. Flipped in Stage 4, when the zone, the band, the
// aspect shade, the jitter and the wire conversion have all crossed.
bool KubikFarMesher::has_colors() const {
	return false;
}
