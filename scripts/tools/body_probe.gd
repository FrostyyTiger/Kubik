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

## How many columns to scan looking for a body of a given kind. A promoted
## boulder_l is about one percent of boulders, so this has to be generous; at
## roughly ten milliseconds a column it is the slowest thing in the probe.
const SEARCH_COLUMNS := 2000

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

	var bad_push: Array[String] = []
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

	# THE PUSH, WITH A REAL PLAYER AND A REAL CONTACT (Stage 12).
	#
	# The self-test checks the ARITHMETIC of the co-op rule - one player moves
	# a boulder_m, two move a boulder_l - and cannot check that a capsule
	# walking into a rock produces a contact the accumulator recognises. That
	# is what this is: the host's own player, physics on, walking into the
	# nearest boulder_l with a real wish, for three seconds.
	# BOTH HALVES OF THE RULE, and both need a body of the right kind under the
	# player - a boulder_l is one in twelve boulders, so "the nearest body" is
	# almost never one. Each is hunted for and walked to.
	# UP TO THREE CANDIDATES OF EACH KIND. The first boulder_l the search finds
	# is not necessarily one a player can walk up to - rocks sit on ledges, in
	# clefts, and on the far side of drops - and three runs in a row failed to
	# make contact with the same unreachable one while the boulder_m beside it
	# worked every time. Trying the next one is cheaper than a smarter search.
	var big := await _reachable(field, BodyTable.BOULDER_L)
	if big["id"] == 0:
		bad_push.append("found no boulder_l in the world - the co-op half is untested")
	else:
		var pushed: Dictionary = big["result"]
		print("[BodyProbe] one player leaned on a boulder_l for 3 s: it moved %.3f m, rocked on %d ticks, %d push contacts" % [
			pushed["moved"], pushed["rocked"], pushed["contacts"]])
		# NO CONTACT IS NOT A PASS AND IT IS NOT A FAILURE OF THE RULE. It
		# means the probe could not arrange the test - the rock was on a ledge,
		# or the walk-up missed - and reporting that as "the boulder did not
		# move" would be the most flattering possible lie.
		if not pushed["arranged"]:
			bad_push.append("the boulder_l was streamed out mid-test - untested")
		elif int(pushed["contacts"]) <= 0:
			bad_push.append("never made contact with the boulder_l - untested")
		else:
			if pushed["moved"] > 0.1:
				bad_push.append("one player moved a boulder_l %.2f m" % pushed["moved"])
			if int(pushed["rocked"]) <= 0:
				bad_push.append("a boulder_l leaned on by one player never rocked")

	var small := await _reachable(field, BodyTable.BOULDER_M)
	if small["id"] == 0:
		bad_push.append("found no boulder_m in the world")
	else:
		var pushed: Dictionary = small["result"]
		print("[BodyProbe] one player leaned on a boulder_m for 3 s: it moved %.3f m, rocked on %d ticks, %d push contacts" % [
			pushed["moved"], pushed["rocked"], pushed["contacts"]])
		# THE OTHER HALF. A boulder_m that also refuses one player would make
		# every rock in the world scenery, and every assertion about boulder_l
		# above would still pass.
		if int(pushed["contacts"]) <= 0:
			bad_push.append("never made contact with the boulder_m - untested")
		elif pushed["moved"] < 0.2:
			bad_push.append("one player could not move a boulder_m (%.3f m)" % pushed["moved"])

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

	var bad := bad_push.duplicate()
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


## Walk up to successive bodies of one kind until one of them can actually be
## leaned on, and return that attempt.
##
## "No contact" is not a result. It means the probe could not arrange the test,
## and reporting it as "the boulder did not move" would be the most flattering
## possible lie - so the probe tries again on another rock rather than scoring
## an unreachable one as a pass.
func _reachable(field, kind: int) -> Dictionary:
	var last := {"moved": 0.0, "rocked": 0, "contacts": 0, "arranged": false}
	for attempt in 3:
		var id := await _goto_kind(field, kind, attempt)
		if id == 0:
			break
		var result := await _lean_on(field, id, 3.0)
		last = result
		if int(result["contacts"]) > 0:
			return {"id": id, "result": result}
		print("[BodyProbe]   no contact with that one - trying another")
	return {"id": 0 if int(last["contacts"]) == 0 else 1, "result": last}


## Find a promoted body of this kind anywhere in the world, walk to it, and
## return its id once it is loaded and thawed.
##
## SEARCHED THROUGH THE PLACEMENT, not through the loaded set: a boulder_l is
## roughly one in twelve boulders and boulders are rare in the first place, so
## whatever happens to be near the player is almost never the kind under test.
## This runs the same FloraPlacement scan the flora job runs and the same
## BodyTable.promote the host runs, which is also a check in itself - if the
## two disagreed, nothing here would be where the search said it was.
func _goto_kind(field, kind: int, skip := 0) -> int:
	var gen = _world.generator
	var cfg = _world.config
	var bs: float = cfg.block_size
	var found := Vector3.ZERO
	var have := false
	var seen := 0
	var scanned := 0
	for col in _spiral_columns(SEARCH_COLUMNS):
		scanned += 1
		for inst in FloraPlacement.column(gen, cfg, col.x, col.y):
			var block: Vector2i = inst["block"]
			if BodyTable.promote(inst["model"], block.x, block.y,
					gen.world_seed, cfg) != kind:
				continue
			if seen < skip:
				seen += 1
				continue
			found = inst["pos"]
			have = true
			break
		if have:
			break
	if not have:
		print("[BodyProbe] no %s in %d columns around the player" % [
			BodyTable.name_of(kind), scanned])
		return 0
	print("[BodyProbe] found a %s at %.0f, %.0f - walking there" % [
		BodyTable.name_of(kind), found.x, found.z])
	# TWO METRES OFF AND ON THE GROUND, settled here and NOT MOVED AGAIN.
	# Teleporting during the measurement was the mistake in the version before
	# this one: each hop restreams the region, and a body whose chunk is
	# mid-rebuild has no collider, so `ready_to_move` is false and every push
	# against it is correctly ignored. The probe read that as "the rule is
	# broken" - a boulder_m with four contacts that moved 0.000 m.

	var stand := found - Vector3(2.0, 0.0, 0.0)
	stand.y = _world.surface_height_m(
		int(floor(stand.x / bs)), int(floor(stand.z / bs))) + 1.0
	_player.global_position = stand
	await _settle()
	await _sleep_for(2.0)
	return _nearest_of_kind(field, kind)


## Columns in a square spiral out from wherever the player is standing.
##
## NOT THE ROCK ZONES FROM THE HEIGHTMAP, and the first version of this was.
## Two things went wrong with that. The coarse heightmap cell classifies a place
## differently from the per-block `surface_at` the placement uses - the
## self-test records the same trap - and even where it agrees, a PROMOTED
## boulder_l is about one percent of boulders: eight percent of boulders are
## large and fifteen percent of those are promoted. Sampling a hundred and
## twenty scattered rock columns found none, twice.
##
## A spiral from the player is dense, is centred on ground the probe has
## already confirmed grows boulders, and finds the nearest example rather than
## an arbitrary one - which also keeps the walk short.
func _spiral_columns(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var bs: float = _world.config.block_size
	var here := Vector2i(
		Chunk.floor_div(int(floor(_player.global_position.x / bs)), Chunk.SIZE),
		Chunk.floor_div(int(floor(_player.global_position.z / bs)), Chunk.SIZE))
	var x := 0
	var z := 0
	var dx := 0
	var dz := -1
	for _i in count * 4:
		if out.size() >= count:
			break
		if -count < x and x <= count and -count < z and z <= count:
			out.append(here + Vector2i(x, z))
		# The standard square-spiral turn: at a corner, rotate the step vector
		# ninety degrees. The corners are where |x| == |z|, plus the two edges
		# that a spiral of even width needs.
		if x == z or (x < 0 and x == -z) or (x > 0 and x == 1 - z):
			var t := dx
			dx = -dz
			dz = t
		x += dx
		z += dz
	return out


## The nearest loaded body of one kind, or 0.
func _nearest_of_kind(field, kind: int) -> int:
	var best := 0
	var best_d := INF
	for id in field.bodies():
		var body = field.bodies()[id]
		if body.kind != kind:
			continue
		var d: float = body.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = id
	return best


## Stand next to a body and walk into it. Returns how far it went and whether
## it ever rocked.
##
## `wish_override` is how every probe here drives a player with no keyboard,
## and it is the same field the traversal probe uses. Physics is turned back on
## for the duration: this is the one measurement in this probe that needs the
## player to be a body rather than a camera.
func _lean_on(field, id: int, seconds: float) -> Dictionary:
	var body = field.bodies().get(id)
	if body == null:
		return {"moved": 0.0, "rocked": 0, "contacts": 0, "arranged": false}
	var from: Vector3 = body.global_position
	# THE NODE, NOT JUST ITS ID. Streaming frees a body when its column leaves
	# and rebuilds it when the column returns - at its REST pose, because an
	# unmoved body is a function of the seed. So a churned column produces a
	# rock in a different place with the same id, and comparing before against
	# after measures the respawn rather than the push. That is where a
	# boulder_l nobody had touched appeared to move 1.52 m.
	var instance: int = body.get_instance_id()

	# NO TELEPORT. The player was already settled beside this rock by
	# _goto_kind, and every hop from here restreams the region - which takes
	# the collider out from under the very body being pushed. It just walks at
	# it from where it is standing.
	var to: Vector3 = body.global_position - _player.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return {"moved": 0.0, "rocked": 0, "contacts": 0, "arranged": false}

	var rocks_before: int = field.rock_ticks()
	var contacts_before: int = field.push_contacts()
	_player.set_physics_process(true)
	_player.wish_override = to.normalized()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await get_tree().process_frame
	_player.wish_override = Vector3.ZERO
	_player.set_physics_process(false)

	body = field.bodies().get(id)
	var same: bool = body != null and body.get_instance_id() == instance
	return {
		"moved": 0.0 if not same else from.distance_to(body.global_position),
		"rocked": field.rock_ticks() - rocks_before,
		"contacts": field.push_contacts() - contacts_before,
		"arranged": same,
	}


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
	return known[0] if known.size() >= 2 else Vector3.ZERO


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
