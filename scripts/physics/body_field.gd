class_name BodyField
extends Node3D

## Every body in the loaded world, and the only thing that decides which of
## them cross the wire.
##
## WHY THIS IS A NODE AND NOT MORE OF `World`. World streams voxels; this
## streams things that sit on voxels and can leave the column they were born
## in. They have different lifetimes - a boulder outlives the chunk it rolled
## off - and World is already the largest file in the project. What they share
## is a column key, and that is the whole interface: World says "this column
## landed, here are its bodies" and "this column is gone".
##
## HOST AND CLIENT RUN THE SAME PROMOTION AND BUILD DIFFERENT THINGS. The set of
## bodies is a pure function of the seed and the config, so nobody sends a list
## of rocks; the host builds a `WorldBody` that Jolt simulates and each client
## builds a `WorldBodyView` that follows the table. A rock nobody has ever
## touched costs zero packets forever, because both sides built it in the same
## place from the same hash.
##
## WHAT MOVES IS THE EXCEPTION, AND IT IS STORED. A body that has never moved
## regenerates identically when its column comes back, so unloading it is free.
## One that HAS moved is remembered by id in `_moved` - a position and a
## rotation, kept whether or not its column is loaded - because "where did we
## leave that rock" is world state and the seed no longer knows it.

## How far from a peer a body has to be before it stops being replicated.
##
## A rolling boulder 128 m away is smaller than a pixel and behind fog on every
## preset. The number is generous because the failure it prevents is ugly - you
## walk into view and the rock jumps to where it actually is - and cheap,
## because the filter below is distance-squared against a handful of centres.
const REPLICATE_RANGE_M := 128.0

## At most this many body rows in one packet. The players' rows share the
## packet and they are the ones that must not be delayed.
const ROWS_PER_PACKET := 32

## How long after its last movement a body keeps being sent, in milliseconds.
## Covers the gap between Jolt deciding a body is asleep and the last packet
## arriving, so a client's copy ends where the host's did.
const SETTLE_TAIL_MS := 1000

var _is_host := false
var _block_size := 1.0
var _journal: Journal = null

## Asked whether the chunk under a body has its collider yet. See _thaw_pass().
var _world: Node = null

## id -> node. WorldBody on the host, WorldBodyView on a client.
var _bodies := {}

## column -> {id: true}. What to free when a column goes; kept in step with
## re-homing, so a boulder that rolled into the next column leaves with THAT
## column and not with the one it was born in.
var _by_column := {}

## id -> the column that currently owns it. The reverse of _by_column, kept
## because host_tick asks "has this body left its column" for every awake body
## every tick, and searching _by_column for the answer would be a scan over
## every loaded column per body.
var _home := {}

## id -> [pos, quat]. Bodies that have moved, whether or not they are loaded.
## This is the only world state bodies have that the seed does not.
var _moved := {}

## id -> ticks_msec of the last movement seen, for the settle tail.
var _last_move := {}

## Bodies built but not yet handed to the solver. See _thaw_pass().
var _frozen := {}

var _awake := 0

## The push accumulator, refilled and applied every physics tick. See push.gd.
var _push := Push.new()

## id -> push direction, for bodies being leaned on but not moved. These are
## replicated even though they are asleep and have not moved, because the whole
## point of a rock is that the OTHER player sees it give.
var _rocking := {}

## Ticks on which at least one body was held against but not moved. Cumulative,
## because "did it ever rock" sampled once a frame misses a rule that fires on
## physics ticks - the probe read `false` while it was happening.
var _rock_ticks := 0

## How many bodies have been built and destroyed over the session.
##
## CHURN, WHICH IS THE NUMBER THAT MATTERS, not the count. A body is three
## nodes, a collision shape and a physics registration, all built on the main
## thread - so what a crossing costs is not how many bodies exist but how many
## times they are created. Freeing them on the wrong boundary cost 37% of chunk
## throughput on Marcel's box and was invisible in every count.
var spawns := 0
var frees := 0


func setup(is_host: bool, block_size: float, world: Node,
		journal: Journal = null) -> void:
	_is_host = is_host
	_block_size = block_size
	_world = world
	_journal = journal


# --- Streaming ---------------------------------------------------------------

## A column's flora landed. Build whatever of its bodies do not exist yet.
##
## IDEMPOTENT BY ID, because a column can land twice: the cache restores one
## while a job for it is still in flight, and a body that rolled out of its
## birth column is still owned by wherever it is now. Checking `_bodies` rather
## than the column is what makes both of those harmless.
func column_landed(col: Vector2i, bodies: Array) -> void:
	if not _by_column.has(col):
		_by_column[col] = {}
	for b in bodies:
		var id: int = b["id"]
		if _bodies.has(id):
			continue
		_spawn(col, id, b["kind"], b["pos"], b["yaw"], b["scale"])


## EVERY BODY MOVED BY -DELTA, horizon v1 Stage 6.
##
## A body's position is render space like every other node's, and a rebase
## moves the render origin under it. `_moved` - the one thing about a body that
## cannot be regenerated - holds WORLD positions and is deliberately not
## touched: it is what a rejoining client is told, and the wire is world metres.
##
## Physics is told rather than asked: a `RigidBody3D` moved by writing
## `position` keeps its velocity and its sleep state, which is what a rebase
## must not disturb - the delta is the same for the body and for the ground
## under it, so nothing has moved as far as the solver is concerned.
func shift_anchors(delta: Vector3) -> void:
	for id in _bodies:
		var node: Node3D = _bodies[id]
		if is_instance_valid(node):
			node.position -= delta


## A column left the loaded set. Its bodies go with it.
##
## FREED, NOT PARKED, unlike a chunk. A chunk is expensive to rebuild - the
## generator, the tree scan, the mesh - and cheap to keep hidden. A body is the
## opposite: rebuilding it is a node and a shared shape, and keeping it costs a
## broadphase entry and, if it is awake, solver time for a rock nobody is near.
## What is worth keeping is the one thing that cannot be regenerated, and that
## is already in `_moved`.
func column_left(col: Vector2i) -> void:
	var ids: Dictionary = _by_column.get(col, {})
	for id in ids:
		var node: Node3D = _bodies.get(id)
		if node == null:
			continue
		_remember(id, node)
		frees += 1
		_bodies.erase(id)
		_home.erase(id)
		_frozen.erase(id)
		node.queue_free()
	_by_column.erase(col)


func _spawn(col: Vector2i, id: int, kind: int, pos: Vector3, yaw: float,
		scale_f: float) -> void:
	# A body we have moved before comes back where we left it, not where the
	# seed says. This is the whole reason _moved exists.
	var start_pos := pos
	var start_rot := Quaternion(Vector3.UP, yaw)
	var known: Array = _moved.get(id, [])
	if known.size() >= 2:
		start_pos = known[0]
		start_rot = known[1]

	var node: Node3D
	if _is_host:
		var body := WorldBody.new()
		body.setup(id, kind, pos, yaw, scale_f, _block_size)
		node = body
	else:
		var view := WorldBodyView.new()
		view.setup(id, kind, pos, yaw, scale_f, _block_size)
		node = view
	add_child(node)
	node.global_position = start_pos
	node.quaternion = start_rot
	if _is_host and known.size() >= 2:
		(node as WorldBody).moved = true
	spawns += 1
	_bodies[id] = node
	if not _by_column.has(col):
		_by_column[col] = {}
	_by_column[col][id] = true
	_home[id] = col

	# FROZEN, WHICH IS THE RESTING STATE OF EVERY BODY - see WorldBody.shove().
	# A rock nobody has shifted is scenery that happens to know how to roll.
	#
	# It also covers the window this started out solving: a column's voxels are
	# published several frames before its collider is installed, and a live
	# RigidBody3D created in that window is a rock in mid-air over a hole. It
	# fell from y 77 to y -152 and came back 181 m from where it had "settled".
	if _is_host:
		(node as WorldBody).freeze = true
		_frozen[id] = true


func _remember(id: int, node: Node3D) -> void:
	if not _is_host:
		return
	var body := node as WorldBody
	if body == null or not body.moved:
		return
	_moved[id] = _world_row(body)


## A body's row in WORLD metres - horizon v1 Stage 6.
##
## `to_row()` reports the node's position, which is render space, and `_moved`
## is the one place a body's position leaves the scene tree: it is sent to
## clients, read back by `_spawn` when a column returns, and survives a rebase.
## All three want world.
func _world_row(body: WorldBody) -> Array:
	var row: Array = body.to_row()
	row[0] = (row[0] as Vector3) + World.origin_m
	return row


## ONE PHYSICS TICK OF PUSHING (world feel v1 Stage 12).
##
## Called by Game with every body that can push - its own player and every
## remote peer's sim. It runs AFTER those bodies have moved, which is what
## `process_physics_priority` on Game is for: `get_slide_collision()` reports
## what blocked a body's own move this tick, and asking before the move gets
## last tick's answer.
func push_tick(pushers: Array, delta: float) -> void:
	if not _is_host:
		return
	_push.clear()
	for entry in pushers:
		_push.add_player(entry[0], entry[1])
	var rocking := _push.apply(_bodies, delta)
	# Bodies that stopped being pushed have to be told, or they stay tilted.
	for id in _rocking:
		if not rocking.has(id):
			var was: WorldBody = _bodies.get(id)
			if was != null:
				was.rock_dir = Vector3.ZERO
	for id in rocking:
		var rock: WorldBody = _bodies.get(id)
		if rock != null:
			rock.rock_dir = rocking[id]
	_rocking = rocking
	if not rocking.is_empty():
		_rock_ticks += 1


# --- The host's tick ---------------------------------------------------------

## Notice what moved, re-home it, and keep the journal. Called once per sync
## tick rather than per physics tick: everything here is bookkeeping about
## bodies that are already being simulated correctly by Jolt, and none of it
## needs to happen sixty times a second.
func host_tick() -> void:
	if not _is_host:
		return
	_thaw_pass()
	_awake = 0
	var now := Time.get_ticks_msec()
	var rehome := []
	for id in _bodies:
		var body: WorldBody = _bodies[id]
		if body.freeze:
			continue
		if body.sleeping:
			# IT HAS COME TO REST. Freeze it again, which is the resting state
			# of every body: from here it is solid, still, and costs the solver
			# nothing until somebody pushes it again. `moved` stays set - it is
			# world state now, and _remember() reads it when the column goes.
			body.freeze = true
			continue
		_awake += 1
		if not _last_move.has(id):
			# The first tick of a body that has just been pushed. Worth a
			# journal line: from here on this rock is world state rather than
			# a function of the seed.
			if _journal != null:
				_journal.log_event("body_moved", {
					"id": id, "kind": BodyTable.name_of(body.kind),
					"from": FloraPlacement.column_of(id),
				})
		_last_move[id] = now
		_moved[id] = _world_row(body)
		var col := _column_of_node(body)
		if col != _home.get(id, col):
			rehome.append([id, col])
	for pair in rehome:
		_rehome(pair[0], pair[1])
	_settle_pass(now)


## Hand over every body whose ground has arrived.
##
## Cheap because it only ever walks bodies that are still frozen, and a body
## leaves that set for good the first time its chunk is collidable.
func _thaw_pass() -> void:
	if _frozen.is_empty() or _world == null:
		return
	var ready := []
	for id in _frozen:
		var body: WorldBody = _bodies.get(id)
		if body == null:
			ready.append(id)
			continue
		var p := body.global_position
		var chunk := Chunk.world_to_chunk(Vector3i(
			int(floor(p.x / _block_size)),
			# HALF A METRE DOWN, not at the body's own origin. The origin is
			# the bottom face of the rock, which sits ON the top face of the
			# surface block - so it is exactly on a chunk boundary as often as
			# not, and asking about the chunk above the ground answers about
			# the air the rock is standing in.
			int(floor((p.y - 0.5) / _block_size)),
			int(floor(p.z / _block_size))))
		if not _world.is_chunk_collidable(chunk):
			continue
		# ELIGIBLE, NOT RELEASED. The body stays frozen; all this decides is
		# that there is ground under it, so a push that clears its hold may
		# now unfreeze it. See WorldBody.shove().
		body.ready_to_move = true
		ready.append(id)
	for id in ready:
		_frozen.erase(id)


## Bodies that stopped this tick. Split out because it walks _last_move rather
## than _bodies, and a body can settle in a column that has since unloaded.
func _settle_pass(now: int) -> void:
	var done := []
	for id in _last_move:
		if now - int(_last_move[id]) < SETTLE_TAIL_MS:
			continue
		done.append(id)
	for id in done:
		_last_move.erase(id)
		if _journal != null:
			_journal.log_event("body_settled", {"id": id})


func _column_of_node(node: Node3D) -> Vector2i:
	var p := node.global_position
	var bx := int(floor(p.x / _block_size))
	var bz := int(floor(p.z / _block_size))
	return Vector2i(Chunk.floor_div(bx, Chunk.SIZE),
		Chunk.floor_div(bz, Chunk.SIZE))


## A body rolled out of its column and into another one.
##
## It moves to the new column's bucket even if that column is not loaded, which
## looks wrong and is not: the bucket is about WHO FREES IT, and a body sitting
## in an unloaded column's bucket is freed the moment that column is next
## dropped - or, if it never loads, when it is next asked for. What must not
## happen is the birth column unloading and taking a rock that is no longer in
## it, which is a boulder vanishing from under a player's hands.
func _rehome(id: int, col: Vector2i) -> void:
	var was: Vector2i = _home.get(id, col)
	if _by_column.has(was):
		(_by_column[was] as Dictionary).erase(id)
	if not _by_column.has(col):
		_by_column[col] = {}
	_by_column[col][id] = true
	_home[id] = col


# --- Replication -------------------------------------------------------------

## The `"b"` half of the authoritative table: {id: [pos, quat]}.
##
## THREE FILTERS, IN THE ORDER THAT MAKES THE COMMON CASE FREE. Almost every
## body in a loaded world is asleep and has never moved, so the first test -
## "is it in _last_move at all" - rejects the whole scenery in one dictionary
## lookup per body. Distance is next because it is arithmetic; the packet cap
## is last because it is a sort.
##
## `centres` is every peer's position INCLUDING the host's own. A body only the
## host can see still has to be sent, because the host is not the only one who
## will walk over there later - and a body no one is near is not sent at all.
func rows_for(centres: Array) -> Dictionary:
	var out := {}
	if not _is_host:
		return out
	# A rocking body is ASLEEP and has never moved, so it is in neither
	# _last_move nor anything else this filter looks at - and it is exactly the
	# body a second player most needs to see, because "it gave and did not go"
	# is the message that says come and help.
	var interesting := {}
	for id in _last_move:
		interesting[id] = true
	for id in _rocking:
		interesting[id] = true
	if interesting.is_empty():
		return out
	var range_sq := REPLICATE_RANGE_M * REPLICATE_RANGE_M
	var near := []
	for id in interesting:
		var body: WorldBody = _bodies.get(id)
		if body == null:
			continue
		var best := INF
		for c in centres:
			best = minf(best, body.global_position.distance_squared_to(c))
		if best > range_sq:
			continue
		near.append([best, id, body])
	if near.size() > ROWS_PER_PACKET:
		# NEAREST FIRST when there are too many. If a packet has to drop rows,
		# the ones to drop are the ones nobody is standing next to.
		near.sort_custom(func(a, b): return a[0] < b[0])
		near.resize(ROWS_PER_PACKET)
	for entry in near:
		out[entry[1]] = (entry[2] as WorldBody).to_row()
	return out


## A client applying the host's rows. Bodies it has no node for are remembered
## anyway: the column may not have loaded yet, and _spawn reads _moved.
func apply_rows(rows: Dictionary) -> void:
	if _is_host:
		return
	for id in rows:
		var row: Array = rows[id]
		if row.size() != 3:
			continue
		_moved[id] = row
		var view: WorldBodyView = _bodies.get(id)
		if view != null:
			# The wire is world metres and a view is render space.
			view.set_target((row[0] as Vector3) - World.origin_m, row[1])
			view.rock_dir = row[2]
	# A body that has stopped rocking simply stops appearing in the packet, so
	# anything we are still tilting and did not hear about is finished.
	for id in _bodies:
		if rows.has(id):
			continue
		var view: WorldBodyView = _bodies[id]
		if view != null and view.rock_dir != Vector3.ZERO:
			view.rock_dir = Vector3.ZERO


# --- Readouts ----------------------------------------------------------------

func count() -> int:
	return _bodies.size()


func awake_count() -> int:
	return _awake


func moved_count() -> int:
	return _moved.size()


func rocking_count() -> int:
	return _rocking.size()


## Player-into-body contacts seen since the field was built. Probe diagnostic;
## see Push.contacts.
func push_contacts() -> int:
	return _push.contacts


func rock_ticks() -> int:
	return _rock_ticks


## The loaded bodies, by id. For the probes.
func bodies() -> Dictionary:
	return _bodies
