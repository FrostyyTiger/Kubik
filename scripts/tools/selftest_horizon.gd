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
		+ "far_ms_median=214 tree_rebuilds=4 mem_mb=1180 moved_m=771 jumps=12")
	var got := _parse_kv(line)
	var want := {
		"label": "x", "seconds": "60", "frames": "3607",
		"median_ms": "14.25", "p99_ms": "22.10", "worst_ms": "31.40",
		"over25": "3", "chunks": "812", "far_rebuilds": "9",
		"far_ms_median": "214", "tree_rebuilds": "4", "mem_mb": "1180", "jumps": "12",
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
