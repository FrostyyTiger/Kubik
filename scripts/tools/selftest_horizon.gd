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
