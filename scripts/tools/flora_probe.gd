class_name FloraProbe
extends Node

## Measures how the ground cover keeps up with a moving player, and quits.
##
##     godot --headless --path . -- --host --seed 42 --flora-probe
##
## WHY THIS EXISTS. The flora streaming pass was started by a playtest report -
## "the grass disappears when I walk and takes ages to come back" - and the
## initial-load line in World measures none of that: it times the first disc,
## built while the player stands still. This walks. It jumps the player STEP_M
## along +X, STEPS times, waits for the world to settle after each jump and
## records how long the terrain took, how long the grass took AFTER the
## terrain, and how many columns were built; then it jumps back the way it
## came and records the same - which is where a cache shows up as zero builds.
##
## TELEPORTS, NOT WALKING. The traversal probe walks in real time because it
## measures the terrain; this measures the streaming, and a jump is the
## harshest case of it: every column in the new disc is missing at once.
## Physics is switched off on the player so it does not fall through ground
## that is not there yet.
##
## Wall clock, on purpose. Workers run on the wall clock whatever the frame
## rate does, and "how long until the grass is back" is a wall-clock question.

const STEPS := 6
const STEP_M := 48.0
const SETTLE_TIMEOUT_MS := 30000

var _world: Node = null
var _player: Node3D = null
var _rows: Array = []


func run(world: Node, player: Node3D) -> void:
	_world = world
	_player = player
	_go.call_deferred()


func _go() -> void:
	print("[FloraProbe] waiting for the first world load")
	while not _world.is_idle():
		await get_tree().process_frame
	_player.set_physics_process(false)
	var start: Vector3 = _player.global_position
	var f: Dictionary = _world.flora_stats()
	print("[FloraProbe] start at (%.0f, %.0f): %d columns, %d instances, %.2f ms per column" % [
		start.x, start.z, f["columns"], f["instances"], f.get("ms_per_column", 0.0)])

	for i in STEPS:
		await _jump(start + Vector3(STEP_M * float(i + 1), 0.0, 0.0), "out %d" % (i + 1))
	for i in STEPS:
		await _jump(start + Vector3(STEP_M * float(STEPS - i - 1), 0.0, 0.0), "back %d" % (i + 1))

	print("[FloraProbe] %-8s %9s %9s %7s %9s %8s" % [
		"jump", "terrain", "grass", "built", "instances", "cached"])
	var out_grass := 0
	var back_grass := 0
	var out_built := 0
	var back_built := 0
	for r in _rows:
		print("[FloraProbe] %-8s %6d ms %6d ms %7d %9d %8d" % [
			r["label"], r["terrain_ms"], r["grass_ms"], r["built"], r["instances"], r["cached"]])
		if r["label"].begins_with("out"):
			out_grass += r["grass_ms"]
			out_built += r["built"]
		else:
			back_grass += r["grass_ms"]
			back_built += r["built"]
	print("[FloraProbe] outward: %d ms of grass after terrain, %d columns built" % [out_grass, out_built])
	print("[FloraProbe] back:    %d ms of grass after terrain, %d columns built" % [back_grass, back_built])
	get_tree().quit()


## Jump, then wait for the terrain to settle and then the grass, timing each.
func _jump(to: Vector3, label: String) -> void:
	var built_before: int = _world.flora_stats().get("built", 0)
	_player.global_position = to
	var t0 := Time.get_ticks_msec()
	# The world recentres from the player's position on the next frame.
	await get_tree().process_frame
	await get_tree().process_frame
	var terrain_ms := -1
	var grass_ms := -1
	while Time.get_ticks_msec() - t0 < SETTLE_TIMEOUT_MS:
		var now := Time.get_ticks_msec() - t0
		if terrain_ms < 0 and _terrain_idle():
			terrain_ms = now
		if terrain_ms >= 0 and _world.flora_stats()["pending"] == 0:
			grass_ms = now - terrain_ms
			break
		await get_tree().process_frame
	var f: Dictionary = _world.flora_stats()
	_rows.append({
		"label": label,
		"terrain_ms": terrain_ms,
		"grass_ms": grass_ms,
		"built": int(f.get("built", 0)) - built_before,
		"instances": f["instances"],
		"cached": f.get("cached", 0),
	})
	print("[FloraProbe] %s: terrain %d ms, grass +%d ms, %d built, %d instances, %d cached" % [
		label, terrain_ms, grass_ms, int(f.get("built", 0)) - built_before,
		f["instances"], f.get("cached", 0)])


func _terrain_idle() -> bool:
	return _world.queued_chunk_count() == 0 and _world._in_flight.is_empty() \
		and _world._gen_in_flight.is_empty()
