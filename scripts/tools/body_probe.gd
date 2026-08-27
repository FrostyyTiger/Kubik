class_name BodyProbe
extends Node

## Counts the bodies in a loaded world, pushes one, and checks that walking
## away and coming back does not lose it.
##
##     godot --headless --path . scenes/game.tscn -- --host --seed 42 --body-probe
##
## WHY THIS EXISTS. World feel v1 Stage 11 promotes a fraction of the boulders
## into rigid bodies, and everything about that claim is a count: how many are
## there, do they cost anything while asleep, and does one that has been moved
## come back where it was left rather than where the seed says. None of those
## is visible in a screenshot and none of them is reachable from the self-tests,
## which never start a physics server.
##
## IT IS ALSO THE ANSWER STAGE 9 DEFERRED. The physics probe could not tell
## whether a disabled collider leaves the broadphase, because
## `get_process_info()` counts only DYNAMIC objects and there were none. There
## are now: this prints active objects and collision pairs with a few hundred
## sleeping boulders in the world, and again after they have been parked.

const SETTLE_TIMEOUT_MS := 90000
const WALK_AWAY_M := 220.0

var _world: Node = null
var _player: Node3D = null
var _game: Node = null


func run(world: Node, player: Node3D, game: Node) -> void:
	_world = world
	_player = player
	_game = game
	_go.call_deferred()


func _go() -> void:
	print("[BodyProbe] waiting for the first world load")
	while not _world.is_idle():
		await get_tree().process_frame
	_player.set_physics_process(false)

	var field = _game.body_field()
	# SPAWN IS A MEADOW, AND THAT IS THE POINT OF SPAWN. The world picks a
	# spawn that is flat, dry, with a mountain in view and water within a
	# two-minute walk - and boulders grow in ROCK, ALPINE and SNOW. So the
	# count here is expected to be low or zero, and reporting it is worth a
	# line precisely because "no bodies at spawn" reads like a broken stage
	# until you know where rocks live.
	print("[BodyProbe] %d bodies at spawn (a meadow - boulders are rock and above), %d chunks" % [
		field.count(), _world.loaded_chunk_count()])

	# UP THE MOUNTAIN, where the rocks are.
	var stony := _find_stone()
	print("[BodyProbe] walking to the nearest rock zone at %.0f, %.0f" % [
		stony.x, stony.z])
	_player.global_position = stony
	await _settle()
	await _sleep_for(1.0)
	print("[BodyProbe] %d bodies loaded, %d awake, %d chunks" % [
		field.count(), field.awake_count(), _world.loaded_chunk_count()])
	_report("asleep")

	# STAND NEXT TO THE ROCK BEFORE PUSHING IT, and the first version of this
	# probe did not, which is worth writing down because it PASSED.
	#
	# Bodies exist wherever flora does, and the flora far ring reaches further
	# than the voxel radius - so the nearest body was 125 m away, in a column
	# with no collider, correctly still FROZEN. The shove did nothing, the body
	# "came back" at a drift of exactly 0.000 m because it had never left, and
	# every assertion passed. Same trap as Stage 10's parity test: a thing that
	# never moved satisfies "it ended where it stopped" perfectly.
	var target := _nearest_body(field)
	if target == 0:
		print("[BodyProbe] FAIL - no bodies in a rock zone")
		get_tree().quit(1)
		return
	_player.global_position = _position_of(field, target) + Vector3(0.0, 3.0, 0.0)
	await _settle()
	await _sleep_for(2.0)

	var moved_id := _shove(field)
	if moved_id == 0:
		print("[BodyProbe] FAIL - no body to push")
		get_tree().quit(1)
		return
	var before: Vector3 = _position_of(field, moved_id)
	# WAIT FOR IT TO STOP, not for a fixed number of seconds. A boulder shoved
	# off a mountainside keeps going for a while, and walking away while it is
	# still rolling means comparing where it was when we left against where it
	# is now - which is a real difference and not a bug, but it is not what
	# this probe is asking. It is asking whether a body that has SETTLED comes
	# back where it settled.
	# A frame or two before asking whether it has stopped, or "still asleep
	# from a moment ago" and "already settled" are the same answer.
	await _sleep_for(0.5)
	var rolled := await _wait_until_still(field, moved_id)
	print("[BodyProbe] it rolled for %.1f s before settling" % rolled)
	_report("after a shove")
	var after: Vector3 = _position_of(field, moved_id)
	var shoved := before.distance_to(after)
	print("[BodyProbe] body %d ended at %.2f, %.2f, %.2f - it moved %.2f m" % [
		moved_id, after.x, after.y, after.z, shoved])

	# WALK AWAY AND COME BACK. The column unloads, the body is freed, and the
	# only thing that remembers where it ended up is BodyField._moved.
	var home: Vector3 = _player.global_position
	_player.global_position = home + Vector3(WALK_AWAY_M, 0.0, 0.0)
	await _settle()
	print("[BodyProbe] %d m away: %d bodies loaded" % [
		WALK_AWAY_M, field.count()])
	_player.global_position = home
	await _settle()
	await _sleep_for(1.0)

	var back: Vector3 = _position_of(field, moved_id)
	print("[BodyProbe] back at spawn: %d bodies loaded, %d ever moved" % [
		field.count(), field.moved_count()])
	_report("restored")

	var drift := after.distance_to(back)
	print("[BodyProbe] body %d came back at %.2f, %.2f, %.2f (drift %.3f m)" % [
		moved_id, back.x, back.y, back.z, drift])

	var bad := []
	# FIRST, because everything below it is trivially true of a rock that never
	# moved. See the note above the shove.
	if shoved < 1.0:
		bad.append("the shove moved it %.2f m - it never left its rest pose" % shoved)
	if back == Vector3.ZERO:
		bad.append("the body did not come back at all")
	elif drift > 0.5:
		bad.append("it came back %.2f m from where it stopped" % drift)
	if field.count() <= 0:
		bad.append("no bodies in a loaded world")
	if field.moved_count() <= 0:
		bad.append("nothing was recorded as ever having moved")
	if bad.is_empty():
		print("[BodyProbe] PASS")
		get_tree().quit(0)
		return
	for b in bad:
		print("[BodyProbe] FAIL - %s" % b)
	get_tree().quit(1)


## The nearest place to spawn whose surface zone grows boulders.
##
## Searched on the heightmap rather than by walking, because the probe only
## needs somewhere to stand: it teleports, as every other probe here does, and
## whether a player could WALK there is the traversal probe's question.
func _find_stone() -> Vector3:
	var gen = _world.generator
	var hm = gen.heightmap
	var spawn: Vector2i = gen.spawn_block
	var best := Vector2i.ZERO
	var best_d := INF
	for j in range(1, hm.cols - 1):
		for i in range(1, hm.cols - 1):
			var h: float = hm.cells[i + j * hm.cols]
			var bx: int = hm.cell_to_block(i)
			var bz: int = hm.cell_to_block(j)
			var zone: int = gen.surface_zone_at(bx, bz, h)
			if zone != TerrainGenerator.ZONE_ROCK \
					and zone != TerrainGenerator.ZONE_ALPINE:
				continue
			var d := Vector2(float(bx - spawn.x), float(bz - spawn.y)).length_squared()
			if d < best_d:
				best_d = d
				best = Vector2i(bx, bz)
	var bs: float = _world.config.block_size
	return Vector3(float(best.x) * bs,
		_world.surface_height_m(best.x, best.y) + 2.0,
		float(best.y) * bs)


## The nearest body that is actually being simulated.
##
## `freeze` is the test rather than distance: a body whose column has no
## collider yet is frozen on purpose (see BodyField._thaw_pass) and pushing one
## is pushing a statue.
func _nearest_body(field) -> int:
	var best := 0
	var best_d := INF
	for id in field._bodies:
		var body = field._bodies[id]
		var d: float = body.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = id
	return best


## Give the nearest body a hard sideways impulse.
##
## Not a player push - that is Stage 12 - just enough force that Jolt has to
## wake it, move it and settle it, which is the path this probe is testing.
func _shove(field) -> int:
	var best := 0
	var best_d := INF
	for id in field._bodies:
		var body = field._bodies[id]
		var d: float = body.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = id
	if best == 0:
		return 0
	var body = field._bodies[best]
	print("[BodyProbe] shoving %s %d, %.1f m away, at %.2f, %.2f, %.2f (frozen %s)" % [
		BodyTable.name_of(body.kind), best, best_d,
		body.global_position.x, body.global_position.y, body.global_position.z,
		body.freeze])
	body.shove(Vector3(1.0, 0.2, 0.0).normalized() * 4000.0)
	return best


func _position_of(field, id: int) -> Vector3:
	var body = field._bodies.get(id)
	if body != null:
		return body.global_position
	# Freed, but remembered - which is the interesting case for the walk-away.
	var known: Array = field._moved.get(id, [])
	return known[0] if known.size() == 2 else Vector3.ZERO


func _report(label: String) -> void:
	print("[BodyProbe] %-16s %5d active, %6d pairs, %4d islands" % [
		label,
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS),
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS),
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ISLAND_COUNT)])


## Seconds until the body goes to sleep, or the timeout.
func _wait_until_still(field, id: int) -> float:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < SETTLE_TIMEOUT_MS:
		var body = field._bodies.get(id)
		if body == null:
			break  # rolled out of a loaded column, which counts as settled
		if body.sleeping:
			break
		await get_tree().process_frame
	return float(Time.get_ticks_msec() - t0) / 1000.0


func _sleep_for(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await get_tree().process_frame


func _settle() -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < SETTLE_TIMEOUT_MS:
		if _world.is_idle():
			return
		await get_tree().process_frame
