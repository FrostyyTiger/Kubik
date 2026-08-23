extends Node3D

## Root of the in-game scene. Owns the join handshake and player position sync.
##
## Both peers load this same scene, so every node here sits at the same path on
## both machines - which is what makes @rpc work: Godot addresses RPCs by node
## path, and a mismatch means the call silently lands nowhere.

## Scaffolding: a fixed spot well above the terrain band, so the debug slab is
## guaranteed to land in open air and be visible from anywhere.
const DEBUG_SLAB_Y := 47

## How far above the ground to drop the camera once the world exists.
const SPAWN_CLEARANCE := 6.0

## Position updates per second. 20 is plenty for two players; the smoothing on
## the receiving end hides the gaps.
const SYNC_HZ := 20.0

## If the very first join request races the host scene change, ask again.
const JOIN_RETRY_SECONDS := 1.0

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")

@onready var _world: World = $World
@onready var _camera: FlyCamera = $FlyCamera
@onready var _status: Label = $HUD/Status
@onready var _players_root: Node3D = $Players

## peer_id -> RemotePlayer. Everyone except us.
var _players := {}

## HOST ONLY. peer_id -> {"p": Vector3, "y": float}. The authoritative table.
var _states := {}

var _slab_present := false
var _sync_accum := 0.0
var _join_retry := 0.0
var _chunk_count := 0
var _build_ms := 0


func _ready() -> void:
	_world.generation_finished.connect(_on_world_ready)
	Net.peer_left.connect(_on_peer_left)

	if Net.is_host():
		# The host invents the world. Godot randomises its RNG seed at startup,
		# so this differs every session.
		_status.text = "host - generating world..."
		_world.setup(randi())
	else:
		# Clients generate NOTHING until the host tells them the seed. This
		# request plus the reply is the entire world transfer: one integer and
		# a dictionary of edits, no matter how large the world is.
		_status.text = "client - asking host for the world..."
		_request_join_state()


func _process(delta: float) -> void:
	# Retry the handshake if we somehow asked before the host game scene
	# existed. Cheap insurance against an otherwise silent hang.
	if Net.is_client() and not _world.has_seed():
		_join_retry -= delta
		if _join_retry <= 0.0:
			_request_join_state()

	_sync_accum += delta
	if _sync_accum < 1.0 / SYNC_HZ:
		return
	_sync_accum = 0.0
	_publish_local_state()
	if Net.is_host():
		# The host is the only one that assembles and distributes the table.
		# Skip the broadcast when hosting alone - single player is just a host
		# with no clients, and there is nobody to send to.
		if not Net.other_peer_ids().is_empty():
			_cl_sync_players.rpc(_states)
		_apply_states(_states)


func _on_world_ready(chunk_count: int, elapsed_ms: int) -> void:
	_chunk_count = chunk_count
	_build_ms = elapsed_ms
	# The camera starts above everything so it is never buried mid-generation;
	# once the terrain exists we drop it to just above the ground.
	var surface := _world.find_surface_y(0, 0)
	_camera.position = Vector3(0.5, surface + SPAWN_CLEARANCE, 0.5)
	_update_status()


# --- Join handshake ---------------------------------------------------------

func _request_join_state() -> void:
	_join_retry = JOIN_RETRY_SECONDS
	_srv_request_join_state.rpc_id(1)


## Sent by a joining client, executed on the host.
@rpc("any_peer", "call_remote", "reliable")
func _srv_request_join_state() -> void:
	if not Net.is_host():
		return
	var who := multiplayer.get_remote_sender_id()
	print("[Game] sending world state to peer %d" % who)
	_cl_receive_join_state.rpc_id(who, _world.world_seed, _world.get_edits())


## Sent by the host, executed on the joining client.
@rpc("authority", "call_remote", "reliable")
func _cl_receive_join_state(seed_value: int, edits: Dictionary) -> void:
	if _world.has_seed():
		return  # A retry crossed with the reply. Ignore the duplicate.
	_world.setup(seed_value)
	# Safe to apply before the chunks exist: World records edits immediately
	# and replays them as each chunk is generated.
	_world.apply_edit_snapshot(edits)


# --- Player position sync ---------------------------------------------------
#
# PROVISIONAL. Clients currently report their CAMERA POSITION, because a
# noclip debug camera has no movement rules a host could validate. When the
# real player becomes a physics body this channel becomes:
#
#     client sends INPUT -> host simulates -> host broadcasts the position
#
# The shape is already right - the host owns and distributes the table - only
# the payload changes. _srv_report_state is the function to replace.

func _publish_local_state() -> void:
	var pos := _camera.position
	var yaw := _camera.rotation.y
	if Net.is_host():
		_states[Net.local_peer_id()] = {"p": pos, "y": yaw}
	else:
		_srv_report_state.rpc_id(1, pos, yaw)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_report_state(pos: Vector3, yaw: float) -> void:
	if not Net.is_host():
		return
	# The sender id comes from the network layer and cannot be spoofed, so a
	# client can only ever move itself.
	_states[multiplayer.get_remote_sender_id()] = {"p": pos, "y": yaw}


## "unreliable_ordered": a position update is worthless once a newer one
## exists, so dropping a late packet beats resending it. Ordered means a stale
## packet arriving out of sequence is discarded instead of making the capsule
## jump backwards.
@rpc("authority", "call_remote", "unreliable_ordered")
func _cl_sync_players(states: Dictionary) -> void:
	_apply_states(states)


func _apply_states(states: Dictionary) -> void:
	var me := Net.local_peer_id()
	for pid in states:
		if pid == me:
			continue  # We do not render ourselves.
		var st: Dictionary = states[pid]
		_player_node(pid).set_target(st["p"], st["y"])

	# Anyone we have a capsule for but who is no longer in the table has left.
	for pid in _players.keys():
		if not states.has(pid):
			_remove_player(pid)
	_update_status()


func _player_node(peer_id: int) -> RemotePlayer:
	if _players.has(peer_id):
		return _players[peer_id]
	var node: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate()
	node.setup(peer_id)
	_players_root.add_child(node)
	_players[peer_id] = node
	print("[Game] spawned capsule for peer %d" % peer_id)
	return node


func _remove_player(peer_id: int) -> void:
	if not _players.has(peer_id):
		return
	_players[peer_id].queue_free()
	_players.erase(peer_id)


func _on_peer_left(peer_id: int) -> void:
	# The host drops them from the authoritative table; everyone drops the
	# capsule right away rather than waiting for the next sync.
	_states.erase(peer_id)
	_remove_player(peer_id)
	_update_status()


# --- HUD and debug ----------------------------------------------------------

func _update_status() -> void:
	if not _world.is_world_ready():
		return
	_status.text = "%s (peer %d) | %d others | %d chunks in %d ms | seed %d | WASD+mouse, Space/Ctrl, [G] slab, Esc" % [
		_role_name(), Net.local_peer_id(), _players.size(),
		_chunk_count, _build_ms, _world.world_seed]


func _unhandled_input(event: InputEvent) -> void:
	# Reaches us only if FlyCamera did not consume it, which is how the
	# two-stage Escape works: first press frees the cursor, second lands here.
	if event.is_action_pressed("ui_cancel"):
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	# TEMPORARY until we have block interaction (raycast + break/place).
	# Exists so the authority chain can be verified end to end: press G on the
	# CLIENT and the slab appears on both machines, because the client only
	# sent a request and the host broadcast the result back.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G:
			_toggle_debug_slab()


func _toggle_debug_slab() -> void:
	_slab_present = not _slab_present
	var id := Block.SNOW if _slab_present else Block.AIR
	for x in range(-1, 2):
		for z in range(-1, 2):
			# Note: a request, not a write. Even the host goes through this.
			_world.request_set_block(Vector3i(x, DEBUG_SLAB_Y, z), id)


func _role_name() -> String:
	return "host" if Net.is_host() else "client"
