extends SceneTree

func _init() -> void:
	var ok := ClassDB.class_exists("KubikFarMesher")
	print("class exists: ", ok)
	if ok:
		var m: RefCounted = ClassDB.instantiate("KubikFarMesher")
		print("ping: ", m.ping())
		var values := PackedFloat32Array()
		values.resize(10_000_000)
		values.fill(1.0)
		var t := Time.get_ticks_usec()
		var sum: float = m.bench_sum(values)
		var cpp_us := Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		var gd_sum := 0.0
		for v in values:
			gd_sum += v
		var gd_us := Time.get_ticks_usec() - t
		print("bench 10M floats: C++ %d us (sum %.0f), GDScript %d us (sum %.0f), speedup %.0fx" % [
			cpp_us, sum, gd_us, gd_sum, float(gd_us) / maxf(float(cpp_us), 1.0)])
	quit(0 if ok else 1)
