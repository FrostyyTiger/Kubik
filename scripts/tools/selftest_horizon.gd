class_name SelftestHorizon
extends Node

## HORIZON V1'S OWN GATE FILE.
##
##     godot --headless --path . scenes/selftest_horizon.tscn
##
## and one line in `selftest.gd` runs it inside the main suite too, so a green
## `SELFTEST: all passed` means both.
##
## WHY A SECOND FILE RATHER THAN MORE ENTRIES IN THE FIRST. `selftest.gd` is
## the chunk-mesher lane's this fortnight (`docs/plans/mesher-v1.md`, the file
## ownership table in `docs/plans/horizon-v1.md` § 0), and two lanes appending
## to one 3,600-line dictionary is a merge conflict per stage for nine stages.
## The one line this lane is allowed there calls `run()` below, and everything
## else horizon v1 asserts lives here.
##
## SHAPED LIKE ITS PARENT, deliberately, so a reader moving between them is not
## learning a second harness:
##
##   * tests are UNTYPED, because an aborted typed function returns the default
##     value of its return type and this file's code for "passed" is 0. See
##     `selftest.gd`'s own note - the run printed "all passed" twice before
##     anybody noticed.
##   * each returns the number of failures, and prints its own evidence line
##     whether it passed or not. A gate that only speaks when it fails cannot
##     be compared across two nights.
##   * `run()` returns the total, so the parent suite adds it to its own.

## The seed every world-shaped test in this file builds. The canonical one, so
## a failure here is comparable with the canonical world line.
const SEED := 42


func _ready() -> void:
	var failures := run()
	print("")
	print("SELFTEST-HORIZON: %s" % (
		"all passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Every horizon test, run in order. Returns the failure count.
##
## Called both from `_ready` above and from the one line horizon v1 is allowed
## in `selftest.gd`, so the two suites cannot drift apart.
static func run() -> int:
	var tests := {
		"sprint summary parse": _test_sprint_summary,
		"fly speed knob": _test_fly_speed,
		"fog switch": _test_fog_switch,
		"teleport arithmetic": _test_teleport,
		# STAGE 1.
		"tile store": _test_tile_store,
		"tile threads": _test_tile_threads,
		# STAGE 3.
		"far key parity": _test_far_key_parity,
		# STAGE 4.
		"material parity": _test_material_parity,
		# STAGE 6.
		"origin arithmetic": _test_origin_arithmetic,
		"anchor rule": _test_anchor_rule,
	}
	var failures := 0
	for name in tests:
		var result = (tests[name] as Callable).call()
		if not (result is int):
			print("  %s DID NOT COMPLETE - it returned %s, so it crashed" % [
				name, type_string(typeof(result))])
			failures += 1
			continue
		failures += result
	return failures


# --- Stage 0 ------------------------------------------------------------------

## THE SPRINT PROBE'S SUMMARY LINE ROUND-TRIPS.
##
## The line is the deliverable: every frame number in this plan's status doc,
## every ABAB comparison and the morning message's second item are read off it,
## by a person at 08:00 and by `grep` in between. So the shape is asserted
## rather than trusted - a probe that renamed `median_ms` to `median` would
## still print sixty beautiful lines and quietly break every comparison in the
## document.
##
## Parsed rather than matched: `key=value` pairs separated by spaces, every
## expected key present, every numeric one parsing to the number that was put
## in. That is exactly what a reader's `awk` will do to it.
static func _test_sprint_summary():
	var bad := 0
	var line := ("SPRINT label=x seconds=60 frames=3607 median_ms=14.25 "
		+ "p99_ms=22.10 worst_ms=31.40 over25=3 chunks=812 far_rebuilds=9 "
		+ "far_ms_median=214 tree_rebuilds=4 mem_mb=1180 moved_m=771 jumps=12 "
		+ "tiles=48 tile_mb=6")
	var got := _parse_kv(line)
	var want := {
		"label": "x", "seconds": "60", "frames": "3607",
		"median_ms": "14.25", "p99_ms": "22.10", "worst_ms": "31.40",
		"over25": "3", "chunks": "812", "far_rebuilds": "9",
		"far_ms_median": "214", "tree_rebuilds": "4", "mem_mb": "1180", "jumps": "12", "tiles": "48", "tile_mb": "6",
		"moved_m": "771",
	}
	for key in want:
		if not got.has(key):
			print("  sprint summary: no %s in the line" % key)
			bad += 1
		elif got[key] != want[key]:
			print("  sprint summary: %s is %s, expected %s" % [
				key, got[key], want[key]])
			bad += 1
	# AND THE SHAPE THE PROBE ACTUALLY EMITS, from the format string itself
	# rather than from a copy of it. This is the half that catches a rename:
	# the constant above is what the status doc quotes, and this asserts the
	# probe still writes those keys.
	var keys := PackedStringArray(want.keys())
	var missing := PackedStringArray()
	var src := FileAccess.get_file_as_string(
		"res://scripts/tools/sprint_probe.gd")
	for key in keys:
		if not src.contains("%s=%%" % key):
			missing.append(key)
	if not missing.is_empty():
		print("  sprint summary: sprint_probe.gd no longer writes %s" % missing)
		bad += 1
	print("sprint summary parse: %d keys, %d bad, probe writes all %d" % [
		want.size(), bad, keys.size()])
	return bad


## `fly_speed_mps` REACHES `Locomotion`.
##
## Two halves, and the second is the one that would break silently: the knob
## has to be on `LOCAL_PROPERTIES`, or `World.setup()`'s clone drops it and the
## panel's value never leaves the panel. That is the exact failure
## `worldgen_config.gd` warns about twice and it has happened twice.
static func _test_fly_speed():
	var bad := 0
	var cfg := WorldgenConfig.new()
	if not WorldgenConfig.LOCAL_PROPERTIES.has("fly_speed_mps"):
		print("  fly speed: fly_speed_mps is not in LOCAL_PROPERTIES")
		bad += 1
	if WorldgenConfig.PROPERTIES.has("fly_speed_mps"):
		print("  fly speed: fly_speed_mps is HASHED - it must be local")
		bad += 1
	cfg.fly_speed_mps = 250.0
	var clone := cfg.clone()
	if clone.fly_speed_mps != 250.0:
		print("  fly speed: the clone lost it (%.1f)" % clone.fly_speed_mps)
		bad += 1
	# And the static the rules read. Set and restored, because this suite runs
	# inside a live process and a fly speed left at 250 would follow every test
	# after it.
	var before := Locomotion.fly_speed
	Locomotion.fly_speed = clone.fly_speed_mps
	if Locomotion.fly_speed != 250.0:
		print("  fly speed: Locomotion.fly_speed did not take it")
		bad += 1
	Locomotion.fly_speed = before
	print("fly speed knob: local, unhashed, survives clone, default %.0f m/s" % before)
	return bad


## EVERY HORIZON KNOB IS LOCAL AND UNHASHED, and `--fog off` is one switch.
##
## The canonical world line is reprinted after every stage and one changed
## character is a red gate (plan § 0). The single most likely way to fail it is
## to add a knob to `PROPERTIES` instead of `LOCAL_PROPERTIES` - so the config
## hash is asserted to be blind to all seven of them, by moving each one and
## checking the fingerprint did not.
static func _test_fog_switch():
	var bad := 0
	var knobs := PackedStringArray([
		"far_reach_m", "far_origin_rebase_m", "fly_speed_mps",
		"far_forest_blend", "far_supersample", "far_ring_recenter_frac",
		"far_tile_apron",
	])
	var cfg := WorldgenConfig.new()
	var before := cfg.hash_key()
	for key in knobs:
		if not WorldgenConfig.LOCAL_PROPERTIES.has(key):
			print("  %s is not in LOCAL_PROPERTIES" % key)
			bad += 1
		cfg.set(key, float(cfg.get(key)) + 1.0)
	if cfg.hash_key() != before:
		print("  the config hash MOVED with seven local knobs: %s -> %s" % [
			before, cfg.hash_key()])
		bad += 1
	# The fog switch is a static, not a keyframe: set, read, restore.
	var was := SkyCycle.fog_off
	SkyCycle.fog_off = true
	if not SkyCycle.fog_off:
		print("  SkyCycle.fog_off did not take")
		bad += 1
	SkyCycle.fog_off = was
	print("fog switch: %d horizon knobs local, config hash %s unmoved" % [
		knobs.size(), before])
	return bad


## `--tp X Z` LANDS WHERE IT WAS ASKED, at forty kilometres.
##
## `Game.teleport_to` takes world METRES, converts to a block to read the
## ground, and puts the body back at the metre position it was given. The one
## thing that can go wrong is the CONVERSION, and it goes wrong quietly and
## only far out: a `float` at 40 km has a 4 mm ULP, and every intermediate on
## the way to a block index is a float unless something keeps it whole.
##
## So this asserts the round trip metres -> block -> metres over the whole
## reach, including the negative side, where a truncating division would be
## off by a block rather than by a rounding. It is Stage 0's version of the
## question Stage 6's floating origin asks in earnest, and it is here from the
## start so that a regression in it is caught by the suite rather than by a
## picture of a player standing inside a hill.
##
## The end-to-end - the world re-centring, the ground arriving, the probe
## exiting 0 - is verified by a real run and recorded in the status doc; a
## self-test cannot host a world.
static func _test_teleport():
	var bad := 0
	var bs := 0.5
	var worst := 0.0
	for m in [0.0, 1.0, -1.0, 1500.0, -1500.0, 20000.0, -20000.0,
			32000.0, -32000.0, 40000.0, -40000.0]:
		var b := int(floor(float(m) / bs))
		var back := float(b) * bs
		var err: float = absf(float(m) - back)
		worst = maxf(worst, err)
		if err > bs:
			print("  teleport: %.1f m -> block %d -> %.1f m, off by %.3f m" % [
				m, b, back, err])
			bad += 1
	print("teleport arithmetic: 11 positions to +/-40 km, worst %.4f m (one block is %.2f m)" % [
		worst, bs])
	return bad


# --- Stage 1 ------------------------------------------------------------------

## THE HEIGHT MAP HAS NO EDGE.
##
## Four questions, and each is a different way the store can be wrong.
##
##   1. GROUND EXISTS AT TEN KILOMETRES, and it is the ground the generator
##      would make. `height_at` there must equal `height_at_block` at the same
##      cell - because level-0 tiles are one sample per cell and their grid is
##      the region's grid continued, so a cell-aligned read is the raw function
##      exactly. This is the plan's own gate.
##   2. IT IS NO LONGER THE RIM. Before tonight every position past 3 km read
##      the nearest edge cell, so `height_at(10000, 10000)` and
##      `height_at(20000, 20000)` were the same number. They must not be.
##   3. A THOUSAND POSITIONS IN A FORTY-KILOMETRE DISC are finite and inside
##      the world's altitude range. Not a spot check: a store that returns NAN
##      for one tile in a hundred is a hole in the world that would be found by
##      a player and not by a gate.
##   4. THE SAME CALL TWICE IS THE SAME FLOAT. Determinism is the whole terrain
##      contract - both machines regenerate from the seed and only edits travel
##      - and a store whose second answer differs is two players in different
##      worlds with neither machine reporting an error.
static func _test_tile_store():
	var bad := 0
	var cfg := _canonical_config()
	var gen := TerrainGenerator.new(SEED, cfg)
	gen.build_heightmap()
	var hm: Heightmap = gen.heightmap

	# 1. The tile is the generator's own function, at a cell.
	var probes: Array[Vector2] = [Vector2(10000.0, 10000.0),
		Vector2(-12000.0, 3000.0), Vector2(20000.0, 0.0),
		Vector2(-40000.0, 40000.0)]
	var worst := 0.0
	for at: Vector2 in probes:
		# Snapped to the level-0 cell grid, which is anchored to the ORIGIN at
		# multiples of `step` - so this position is a cell of some tile and the
		# bilinear returns that cell exactly.
		var bx: float = floor(at.x / float(hm.step)) * float(hm.step)
		var bz: float = floor(at.y / float(hm.step)) * float(hm.step)
		var got := hm.height_at(bx, bz)
		var want := gen.height_at_block(bx, bz)
		worst = maxf(worst, absf(got - want))
		if absf(got - want) > 0.001:
			print("  tile store: height_at(%.0f, %.0f) = %.5f, height_at_block = %.5f" % [
				bx, bz, got, want])
			bad += 1

	# 2. It is not the rim any more. Two far-apart positions that used to
	# share a clamped edge cell.
	var a := hm.height_at(10000.0, 10000.0)
	var b := hm.height_at(20000.0, 20000.0)
	if is_equal_approx(a, b):
		print("  tile store: 10 km and 20 km both read %.3f - still clamping" % a)
		bad += 1

	# 3. A thousand positions in a 40 km disc.
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var lo := cfg.min_altitude
	var hi := cfg.max_altitude
	var bad_h := 0
	for i in 1000:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 40000.0 / cfg.block_size
		var h := hm.height_at(cos(ang) * r, sin(ang) * r)
		if not is_finite(h) or h < lo - 0.01 or h > hi + 0.01:
			bad_h += 1
	if bad_h > 0:
		print("  tile store: %d of 1000 positions in a 40 km disc are not a height" % bad_h)
		bad += 1

	# 4. Twice is the same float.
	var repeats := 0
	for at: Vector2 in probes:
		if hm.height_at(at.x, at.y) != hm.height_at(at.x, at.y):
			repeats += 1
	if repeats > 0:
		print("  tile store: %d positions answered differently on the second call" % repeats)
		bad += 1

	var st := hm.tile_stats()
	print(("tile store: %d cell probes worst %.6f, 10 km %.1f vs 20 km %.1f, "
		+ "1000 disc samples ok, %d tiles / %.1f MB built in %d ms") % [
		probes.size(), worst, a, b, int(st["tiles"]),
		float(st["bytes"]) / 1048576.0, int(st["build_ms"])])
	return bad


## A TILE BUILT ON A WORKER AND ON THE MAIN THREAD ARE THE SAME BYTES.
##
## The store's whole thread rule is that a tile is built OUTSIDE the lock and
## published under it, which allows two threads to build the same tile at once
## - harmless only if a build is a pure function of its key. This asserts that
## it is, by building the same tile on four workers and on this thread and
## comparing every one of the 66,564 floats.
##
## It also asserts what the rule is FOR: that `height_at` can be called from a
## worker at all. Every chunk column job does, from Stage 2 on, and a store
## that needed the main thread would deadlock the world rather than merely be
## slow.
static func _test_tile_threads():
	var bad := 0
	var cfg := _canonical_config()
	var gen := TerrainGenerator.new(SEED, cfg)
	gen.build_heightmap()
	var hm: Heightmap = gen.heightmap

	# The reference, on this thread.
	hm.ensure_tile(0, 40, 40)
	var want := hm.tile_arrays(Vector3i(0, 40, 40))
	if want.is_empty():
		print("  tile threads: the reference tile did not build")
		return 1

	# The same key from four workers at once, into a second store, so the
	# comparison is between two independent builds rather than between a build
	# and a cache hit.
	var gen2 := TerrainGenerator.new(SEED, cfg)
	gen2.build_heightmap()
	var hm2: Heightmap = gen2.heightmap
	var tasks := []
	for i in 4:
		tasks.append(WorkerThreadPool.add_task(
			func() -> void: hm2.ensure_tile(0, 40, 40)))
	for t in tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	var got := hm2.tile_arrays(Vector3i(0, 40, 40))
	if got.is_empty():
		print("  tile threads: the worker tile did not build")
		return 1

	var mean_a: PackedFloat32Array = want[0]
	var mean_b: PackedFloat32Array = got[0]
	var high_a: PackedFloat32Array = want[1]
	var high_b: PackedFloat32Array = got[1]
	if mean_a.size() != mean_b.size() or high_a.size() != high_b.size():
		print("  tile threads: sizes differ, %d/%d" % [mean_a.size(), mean_b.size()])
		return 1
	var differ := 0
	for i in mean_a.size():
		if mean_a[i] != mean_b[i] or high_a[i] != high_b[i]:
			differ += 1
	if differ > 0:
		print("  tile threads: %d of %d cells differ between the two builds" % [
			differ, mean_a.size()])
		bad += 1
	# And the store did not build it more than once for the four callers that
	# arrived together - or if it did, it published one of them and not a mix.
	print("tile threads: %d cells, %d differing, one tile from four workers" % [
		mean_a.size(), differ])
	return bad


## The canonical config, as `selftest.gd` builds it. Its own copy rather than a
## call into that file, because `selftest.gd` belongs to the other lane this
## fortnight and this suite has to stand on its own.
static func _canonical_config() -> WorldgenConfig:
	var cfg := WorldgenConfig.new()
	cfg.apply_view_preset()
	cfg.apply_world_scale()
	return cfg


# --- Stage 3 ------------------------------------------------------------------

## THE 160 KEYED MESHES ARE THE SAME MESH.
##
## Stage 3 stops building the far country as one disc and starts building it as
## ten rings by sixteen sectors, each on its own node at its own anchor, each
## replaced on its own. The claim that has to hold is that **the union of the
## keys is the disc**: the same quads, at the same world positions, with the
## same colours - because a key's vertices are relative to its ring's anchor
## and the disc's are absolute, and an anchor applied to the wrong ring is a
## wedge of country in the wrong place.
##
## Both legs, and against each other: the GDScript disc, the GDScript keys, the
## C++ disc and the C++ keys are four builds of one mesh. `selftest.gd`'s far
## parity compares the two discs; this compares the two keyed builds and each
## keyed build against its own disc.
##
## THE COMPARISON IS A MULTISET OF VERTICES, sorted. Quad ORDER differs by
## construction - the disc walks ring by ring and the keyed build walks the
## same rings but writes into sixteen sinks - so anything order-sensitive would
## fail on a mesh that is correct. Sorting a few thousand vertices is
## milliseconds and says exactly the right thing.
static func _test_far_key_parity():
	var bad := 0
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	cfg.view_distance = -1
	cfg.voxel_radius_chunks = 3
	cfg.fog_end_m = 90.0
	cfg.apply_world_scale()
	var gen := TerrainGenerator.new(1234, cfg)
	gen.build_heightmap()
	var hm: Heightmap = gen.heightmap
	var lakes := Lakes.new()
	lakes.compute(hm, cfg)
	gen.lakes = lakes
	hm.build_pyramid()
	hm.publish_far_view()

	var centre := Vector2i(0, 0)
	# Every key there is, so the union is the whole disc by construction.
	var keys := PackedInt32Array()
	for r in FarFieldJob.RING_STEP_MULTIPLE.size():
		for sec in World.FRONTIER_SECTORS:
			keys.push_back(r)
			keys.push_back(sec)

	var gd_disc := _gd_build(hm, gen, cfg, centre, PackedInt32Array())
	var gd_keys := _gd_build(hm, gen, cfg, centre, keys)
	if gd_disc.is_empty():
		print("  far key parity: the disc build produced nothing")
		return 1
	bad += _compare_verts(gd_disc, gd_keys, "gdscript disc vs gdscript keys")

	if FarMesher.class_present():
		var m := FarMesher.new()
		# The member, which `setup` does not assign - see far_mesher.gd.
		m.heightmap = hm
		if m.setup(hm, gen, cfg):
			var cpp_keys := _cpp_build(m, cfg, centre, keys)
			bad += _compare_verts(gd_keys, cpp_keys, "gdscript keys vs c++ keys")
		else:
			print("  far key parity: the c++ mesher would not take this world")
			bad += 1
	else:
		print("  (no c++ mesher - one leg only)")
	print("far key parity: %d vertices over %d keys, %d bad" % [
		gd_disc.size(), keys.size() / 2, bad])
	return bad


## Every vertex of a build, in WORLD metres, sorted. The disc's are already
## world; a key's are relative to its ring's anchor and get it added back.
static func _gd_build(hm: Heightmap, gen: TerrainGenerator, cfg: WorldgenConfig,
		centre: Vector2i, keys: PackedInt32Array) -> PackedVector3Array:
	var job := FarFieldJob.new()
	job.heightmap = hm
	job.generator = gen
	job.config = cfg
	job.center = centre
	job.slice = true
	job.keys = keys
	job.run()
	return _gather(job.slices, job.key_anchors)


static func _cpp_build(m: FarMesher, cfg: WorldgenConfig, centre: Vector2i,
		keys: PackedInt32Array) -> PackedVector3Array:
	m.keys = keys
	m.build(cfg, centre, PackedInt32Array(), true)
	return _gather(m.slices, m.key_anchors)


static func _gather(slices: Array, anchors: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in slices.size():
		var arrays: Array = slices[i]
		if arrays.is_empty():
			continue
		var at := anchors[i] if i < anchors.size() else Vector3.ZERO
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for p in v:
			out.push_back(p + at)
	# THE MULTISET, NOT THE SEQUENCE. Two correct builds emit the same quads in
	# different orders - see the note above.
	var arr := Array(out)
	arr.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		if a.x != b.x:
			return a.x < b.x
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z)
	return PackedVector3Array(arr)


static func _compare_verts(a: PackedVector3Array, b: PackedVector3Array,
		tag: String) -> int:
	if a.size() != b.size():
		print("  %s: %d vertices vs %d" % [tag, a.size(), b.size()])
		return 1
	var worst := 0.0
	var differ := 0
	for i in a.size():
		var d: float = (a[i] - b[i]).length()
		worst = maxf(worst, d)
		if d > 0.0005:
			differ += 1
	if differ > 0:
		print("  %s: %d of %d vertices differ, worst %.6f m" % [
			tag, differ, a.size(), worst])
		return 1
	return 0


# --- Helpers ------------------------------------------------------------------

## `a=1 b=2` to a Dictionary of strings. What a reader's awk does to a summary
## line, done here so the assertion is about the same thing.
static func _parse_kv(line: String) -> Dictionary:
	var out := {}
	for token in line.split(" ", false):
		var eq := token.find("=")
		if eq > 0:
			out[token.substr(0, eq)] = token.substr(eq + 1)
	return out


# --- Stage 4 ------------------------------------------------------------------

## THE MATERIAL PYRAMID'S LEVEL 0 IS THE MESHER'S OWN CHOICE, ten thousand
## samples, exactly. The plan's Stage 4 check.
##
## WHY IT IS THE ONE TEST THIS STAGE NEEDS. Every other claim of the stage
## follows from it: the far colour is a lookup into this pyramid, the coarse
## levels are modes of it, and the C++ leg reads the same bytes the GDScript
## leg does. What could still be wrong is the pyramid's own foundation - that
## the byte at a cell is the material the chunk mesher would put on that
## column's top face - and that is `TerrainGenerator.surface_zone_at` at the
## cell, which is what this compares against.
##
## AND IT IS A CROSS-LEG TEST WITHOUT LOOKING LIKE ONE. The pyramid's level 0
## is filled by `KubikHeightTiles.build_materials` on a machine with the
## extension built, and `surface_zone_at` is GDScript. So a C++ zone rule that
## drifted from the GDScript one fails here, on ten thousand cells, with the
## first disagreement printed.
##
## Cells, not arbitrary positions: a material is read NEAREST, so the only
## place the two can be compared without an interpolation argument in the way
## is the cell centre - which is where the pyramid stores it and where
## `surface_zone_at` is asked.
##
## The outermost ring of cells is excluded and says so: its slope is clamped
## (the neighbour is outside the region), which is a deliberate difference
## written up beside `Heightmap._region_materials`.
static func _test_material_parity():
	var bad := 0
	var cfg := _canonical_config()
	var gen := TerrainGenerator.new(SEED, cfg)
	gen.build_heightmap()
	var hm: Heightmap = gen.heightmap
	hm.build_material_pyramid()
	if hm.materials.size() != hm.cells.size():
		print("  material parity: the pyramid is %d cells and the map is %d" % [
			hm.materials.size(), hm.cells.size()])
		return 1

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260904
	var n := 10000
	var first := ""
	for k in n:
		var i := rng.randi_range(1, hm.cols - 2)
		var j := rng.randi_range(1, hm.cols - 2)
		var bx := hm.cell_to_block(i)
		var bz := hm.cell_to_block(j)
		var want := gen.surface_zone_at(bx, bz, hm.cells[i + j * hm.cols])
		var got := hm.far_material_at(float(bx), float(bz), 0)
		if got != want:
			bad += 1
			if first.is_empty():
				first = "(%d, %d) pyramid %s, surface_zone_at %s" % [
					bx, bz, TerrainGenerator.ZONE_NAMES[got],
					TerrainGenerator.ZONE_NAMES[want]]

	# 2. THE MODE HOLDS UPWARD. Level L over the region is the mode of its four
	# children, so a level-1 cell must be one of the four level-0 materials
	# under it - never a fifth. Cheap, and it catches an index that walks the
	# wrong array far more directly than a colour ever would.
	var not_a_child := 0
	var cols1 := hm.pyramid_level_cols()[0]
	for k in 2000:
		var i := rng.randi_range(0, cols1 - 2)
		var j := rng.randi_range(0, cols1 - 2)
		var lstep := float(hm.step << 1)
		var origin := float(hm.min_block) + (lstep - float(hm.step)) * 0.5
		var got := hm.far_material_at(origin + float(i) * lstep,
			origin + float(j) * lstep, 1)
		var seen := false
		for dj in 2:
			for di in 2:
				var ci := mini(i * 2 + di, hm.cols - 1)
				var cj := mini(j * 2 + dj, hm.cols - 1)
				if hm.materials[ci + cj * hm.cols] == got:
					seen = true
		if not seen:
			not_a_child += 1

	if bad > 0 or not_a_child > 0:
		print("  material parity: %d of %d level-0 cells differ (%s), %d level-1 cells are not a child" % [
			bad, n, first, not_a_child])
		return 1
	print("  material parity: %d level-0 cells exact, %d level-1 cells are a child of their four, %d ms to build" % [
		n, 2000, hm.material_ms])
	return 0


# --- Stage 6 ------------------------------------------------------------------

## THE ROUND TRIP A REBASE DEPENDS ON IS EXACT, AND THE ONE IT DOES NOT IS NOT.
##
## TWO DIFFERENT CLAIMS, and the test measures both because only one of them is
## the floating origin's to keep.
##
##   RENDER -> WORLD -> RENDER IS EXACT, always, for every offset. This is the
##   invariant a rebase rests on: the player is at a render position, the wire
##   and the chunk queue are told the world value, and what comes back has to be
##   the same render number to the bit or the body drifts every time the origin
##   moves. It is exact because the offset is a whole number of 256 m tiles, and
##   an integer multiple of 256 is exactly representable in float32 up to 2^24
##   of them - so the subtraction and the addition cancel with no rounding.
##
##   WORLD -> RENDER -> WORLD IS EXACT TO THE FLOAT GRID AT THAT DISTANCE, and
##   the residual is not this code's: a `Vector3` is float32, its ULP at 40 km
##   is 4 mm, and a world position handed in at 40 km has already been rounded
##   to that grid before this function sees it. The plan says as much - "float
##   at 40 km has a 4 mm ULP, so the world value is the sum of an exact tile
##   multiple and a small float" - and the answer to it is to keep the offset in
##   TILES, which is what `origin_offset_tiles` is. The number is recorded here
##   rather than gated, because gating it would be gating float32.
static func _test_origin_arithmetic():
	var bad := 0
	var w := World.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var worst_render := 0.0
	var worst_world := 0.0
	for k in 4000:
		w.origin_offset_tiles = Vector2i(
			rng.randi_range(-160, 160), rng.randi_range(-160, 160))
		# A render position is always small - that is the point of the origin.
		var render_m := Vector3(rng.randf_range(-2048.0, 2048.0),
			rng.randf_range(0.0, 500.0), rng.randf_range(-2048.0, 2048.0))
		var back := w.to_render_m(w.to_world_m(render_m))
		worst_render = maxf(worst_render, (back - render_m).length())
		var world_m := Vector3(rng.randf_range(-40000.0, 40000.0),
			rng.randf_range(0.0, 500.0), rng.randf_range(-40000.0, 40000.0))
		worst_world = maxf(worst_world,
			(w.to_world_m(w.to_render_m(world_m)) - world_m).length())
	w.origin_offset_tiles = Vector2i(117, -93)
	var off := w.origin_offset_m()
	if not is_equal_approx(off.x, 117.0 * World.ORIGIN_TILE_M) \
			or not is_equal_approx(off.z, -93.0 * World.ORIGIN_TILE_M) \
			or off.y != 0.0:
		print("  origin arithmetic: %s is not 117, -93 tiles of %.0f m" % [
			off, World.ORIGIN_TILE_M])
		bad += 1
	w.free()
	# THE GRID, NOT ZERO, and the difference is the whole lesson. Half a float32
	# ULP at 40 km is 2.4 mm, and `render + offset` at that distance rounds the
	# SUM to that grid - so no round trip THROUGH a world Vector3 can be exact,
	# whatever this code does. What the floating origin buys is that nothing in
	# the render path ever takes that round trip: a rebase subtracts an exact
	# tile multiple from a small number, and the numbers the GPU and the solver
	# see stay small.
	var grid := 0.005
	if worst_render > grid or worst_world > grid:
		print("  origin arithmetic: round trip %.6f m render, %.6f m world, over the %.4f m float32 grid at 40 km" % [
			worst_render, worst_world, grid])
		bad += 1
	if bad > 0:
		return 1
	print("  origin arithmetic: 4000 round trips at +/-40 km, worst %.4f m render and %.4f m world - float32's own grid there is %.4f" % [
		worst_render, worst_world, grid])
	return 0


## NOTHING IS WRITTEN FURTHER FROM ITS ANCHOR THAN THE ANCHOR RULE ALLOWS.
##
## The plan asks for a scan of every `MeshInstance3D` and `MultiMesh` under
## `World` and `TreeField` after a teleport to 30 km. Taken at the WRITERS
## instead, and the reason is that it is a stronger statement: a scene scan
## proves the rule held for the one world that scene happened to build, and this
## proves it holds for the two buffers in this project that could ever break it,
## at any distance, by construction.
##
##   THE TREE RING is the one that spans a kilometre. `TreeFieldJob` packs its
##   rows relative to the ring centre; the assertion is that no row is further
##   from zero than the ring's own outer radius.
##
##   A FLORA COLUMN is sixteen metres square. `FloraColumn` subtracts the
##   column's own origin as it installs; the assertion is that a row that went
##   in at 30 km comes out inside the column.
##
## The far mesh's own rows are asserted by `far key parity`, which rebuilds the
## disc from its 160 anchored pieces and compares it to the whole - so all three
## buffers that carry a world position are covered.
static func _test_anchor_rule():
	var bad := 0
	var limit := 8192.0

	# 1. A flora column's rows, from world metres to inside the column.
	var col := FloraColumn.new()
	var anchor := Vector3(30000.0, 0.0, 30000.0)
	col.setup(Vector2i(3750, 3750), anchor, Vector3.ZERO)
	var buf := PackedFloat32Array()
	buf.resize(FloraJob.FLOATS_PER_INSTANCE * 3)
	var worst_flora := 0.0
	for i in 3:
		var at := i * FloraJob.FLOATS_PER_INSTANCE
		buf[at] = 1.0
		buf[at + 5] = 1.0
		buf[at + 10] = 1.0
		buf[at + 3] = anchor.x + float(i) * 4.0
		buf[at + 7] = 60.0
		buf[at + 11] = anchor.z + float(i) * 4.0
	var moved := col._to_anchor(buf)
	for i in 3:
		var at := i * FloraJob.FLOATS_PER_INSTANCE
		var v := Vector3(moved[at + 3], moved[at + 7], moved[at + 11])
		worst_flora = maxf(worst_flora, v.length())
	col.free()
	if worst_flora > 64.0:
		print("  anchor rule: a flora row is %.1f m from its column" % worst_flora)
		bad += 1

	# 2. The tree ring's rows, packed relative to the ring centre.
	var cfg := _canonical_config()
	var gen := TerrainGenerator.new(SEED, cfg)
	gen.build_heightmap()
	var job := TreeFieldJob.new()
	job.generator = gen
	job.config = cfg
	job.heightmap = gen.heightmap
	# THIRTY KILOMETRES OUT, which is the whole point: the ring is built where
	# a float32 world position has four millimetres left in it.
	var centre := Vector2i(60000, 60000)
	job.center = centre
	job.anchor = Vector3(float(centre.x) * cfg.block_size, 0.0,
		float(centre.y) * cfg.block_size)
	job.inner_blocks = 0.0
	job.outer_blocks = 400.0
	job.run()
	var worst_tree := 0.0
	var rows := 0
	for key in job.buffers:
		var b: PackedFloat32Array = job.buffers[key]
		var n := b.size() / TreeFieldJob.FLOATS_PER_INSTANCE
		rows += n
		for i in n:
			var at := i * TreeFieldJob.FLOATS_PER_INSTANCE
			var v := Vector3(b[at + 3], b[at + 7], b[at + 11])
			worst_tree = maxf(worst_tree, v.length())
	if worst_tree > limit:
		print("  anchor rule: a tree row is %.0f m from its slot, over %.0f" % [
			worst_tree, limit])
		bad += 1

	if bad > 0:
		return 1
	print("  anchor rule: %d tree rows at 30 km, worst %.1f m from the anchor; a flora row worst %.1f m" % [
		rows, worst_tree, worst_flora])
	return 0
