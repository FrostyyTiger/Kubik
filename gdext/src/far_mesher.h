#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

using namespace godot;

// The far mesher, ported from scripts/world/far_field_job.gd. 2026-09-01.
//
// STUB FIRST: ping() proves the library loads and bench_sum() proves packed
// arrays cross the boundary without copies costing more than the work. The
// port itself lands behind these two, function by function, and the GDScript
// job stays the reference implementation the self-tests compare against.
class KubikFarMesher : public RefCounted {
	GDCLASS(KubikFarMesher, RefCounted)

protected:
	static void _bind_methods();

public:
	String ping() const;
	double bench_sum(const PackedFloat32Array &p_values) const;
};
