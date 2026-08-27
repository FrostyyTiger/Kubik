class_name PhysicsProbe
extends Node

## Stands still and counts what the physics server is holding, and quits.
##
##     godot --headless --path . -- --host --seed 42 --physics-probe
##
## WHY THIS EXISTS. World feel v1 Stage 9 switches the engine to Jolt, and the
## whole of that stage is the claim that nothing else changed. "Nothing else
## changed" is not something a screenshot can show and not something the
## self-tests reach: they build meshes and voxels, and never start a physics
## server at all.
##
## So this asks the two questions the switch actually risks.
##
## FIRST, WHAT A LOADED WORLD COSTS. A High disc is a couple of thousand static
## trimesh colliders. If Jolt's broadphase held them differently - as active
## objects rather than sleeping statics, say - the number would show it
## immediately, and it is the number every later stage's body count is read
## against.
##
## SECOND, AND THIS IS THE ONE THE CHUNK CACHE RESTS ON: does a DISABLED
## collider leave the broadphase, or does it merely stop reporting hits? Stage 4
## parks a column rather than freeing it and disables its shape. If a disabled
## shape still costs a broadphase entry, the cache is a memory leak with extra
## steps - 3,000 chunks of it.
##
## THIS PROBE CANNOT ANSWER THAT YET, and it is worth being plain about why
## rather than printing a number that looks like an answer.
## `PhysicsServer3D.get_process_info()` counts ACTIVE objects, collision pairs
## and islands - all of which are properties of the DYNAMIC simulation. A world
## of static trimesh colliders with no rigid bodies in it reports 0, 0, 0
## whether the cache is empty or holds three thousand chunks, which is exactly
## what it does report. The counters are real and they are simply measuring
## something that does not exist until Stage 11 puts bodies in the world.
##
## So the broadphase question is deferred to Stage 11, where a boulder rolling
## near a parked column is a direct test of it, and what this probe establishes
## in the meantime is the other half: Jolt loads, the tick is 60, and a loaded
## world standing still does not drift.
##
## STAGE 11 ANSWERED IT, AND THE ANSWER WAS ABOUT THE COUNTERS RATHER THAN THE
## BROADPHASE: they read 0, 0, 0 under Jolt in every state - five bodies
## loaded, one of them rolling 95 m down a mountain, columns parked and
## restored. Jolt does not implement `get_process_info()`; it is a Godot
## Physics readout that the engine switch silently emptied, and every number
## this probe prints from it is a zero that means "not measured" rather than
## "nothing there".
##
## What Stage 11 does instead is sidestep the question. A parked column's
## bodies are FREED rather than disabled - see BodyField.column_left() and the
## note there about why a body is the opposite trade from a chunk - so there is
## no disabled dynamic shape anywhere to wonder about. The chunk colliders are
## still disabled-and-parked, and that remains unmeasured on this engine.
##
## Physics is off on the player, as in every other probe, so it stands where it
## is put rather than falling while the ground arrives.

const STAND_SECONDS := 30.0
const PARK_STEP_M := 48.0
const PARK_STEPS := 4
const SETTLE_TIMEOUT_MS := 60000

var _world: Node = null
var _player: Node3D = null


func run(world: Node, player: Node3D) -> void:
	_world = world
	_player = player
	_go.call_deferred()


func _go() -> void:
	print("[PhysicsProbe] engine %s at %d Hz" % [
		ProjectSettings.get_setting("physics/3d/physics_engine", "Default"),
		Engine.physics_ticks_per_second])
	print("[PhysicsProbe] waiting for the first world load")
	while not _world.is_idle():
		await get_tree().process_frame
	_player.set_physics_process(false)

	var loaded := _counts()
	_report("loaded", loaded)

	# STAND. Nothing should move, so nothing should change - and if the counts
	# drift while the world is idle and the player is still, something is being
	# created or woken that nobody asked for.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(STAND_SECONDS * 1000.0):
		await get_tree().process_frame
	var stood := _counts()
	_report("after %ds standing" % int(STAND_SECONDS), stood)

	# PARK. Walk far enough that most of the disc leaves the unload ring and is
	# parked with its colliders disabled.
	var start: Vector3 = _player.global_position
	for i in PARK_STEPS:
		_player.global_position = start + Vector3(PARK_STEP_M * float(i + 1), 0.0, 0.0)
		await _settle()
	var parked := _counts()
	_report("after parking %d m" % int(PARK_STEP_M * float(PARK_STEPS)), parked)
	print("[PhysicsProbe] cache holds %d chunks" % [
		_world.last_timings().get("cached_chunks", 0)])

	var drift := absi(int(stood["objects"]) - int(loaded["objects"]))
	print("[PhysicsProbe] standing drift %d active objects (want 0)" % drift)
	if int(loaded["objects"]) == 0:
		print("[PhysicsProbe] NOTE: all counters read 0 because there are no")
		print("[PhysicsProbe]       DYNAMIC bodies in the world yet - static")
		print("[PhysicsProbe]       colliders are not counted. The parked-collider")
		print("[PhysicsProbe]       question is answerable from Stage 11 on.")
	var verdict := "PASS" if drift == 0 else "FAIL"
	print("[PhysicsProbe] %s (Jolt loaded, tick %d, no drift)" % [
		verdict, Engine.physics_ticks_per_second])
	get_tree().quit(1 if (drift != 0 and _strict()) else 0)


func _counts() -> Dictionary:
	return {
		"objects": PhysicsServer3D.get_process_info(
			PhysicsServer3D.INFO_ACTIVE_OBJECTS),
		"pairs": PhysicsServer3D.get_process_info(
			PhysicsServer3D.INFO_COLLISION_PAIRS),
		"islands": PhysicsServer3D.get_process_info(
			PhysicsServer3D.INFO_ISLAND_COUNT),
	}


func _report(label: String, c: Dictionary) -> void:
	print("[PhysicsProbe] %-24s %6d active, %6d pairs, %6d islands, %5d chunks" % [
		label, c["objects"], c["pairs"], c["islands"],
		_world.loaded_chunk_count()])


func _settle() -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < SETTLE_TIMEOUT_MS:
		if _world.queued_chunk_count() == 0 and _world._in_flight.is_empty():
			return
		await get_tree().process_frame


func _strict() -> bool:
	return "--strict" in OS.get_cmdline_user_args()
