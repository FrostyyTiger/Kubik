#include "far_mesher.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void KubikFarMesher::_bind_methods() {
	ClassDB::bind_method(D_METHOD("ping"), &KubikFarMesher::ping);
	ClassDB::bind_method(D_METHOD("bench_sum", "values"),
			&KubikFarMesher::bench_sum);
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
