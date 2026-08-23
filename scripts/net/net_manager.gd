extends Node

## Autoloaded as `Net`. Owns the multiplayer role and the transport lifecycle.
##
## Two conventions from Godot that the whole project leans on:
##   * The server is ALWAYS peer id 1. `multiplayer.is_server()` and
##     `get_unique_id() == 1` mean the same thing.
##   * The MultiplayerAPI lives on the SceneTree, so it survives scene changes.
##     That is why this is an autoload: we connect in the menu and are still
##     connected after switching to the game scene.
##
## Single player is not a special case - it is host_game() with nobody joining.
## No solo-only branch means no solo-only branch to rot.

signal hosting_started()
signal host_failed(reason: String)
signal join_started()
signal join_succeeded()
signal join_failed(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal host_disconnected()

## Arbitrary high port. Nothing special about it, it just has to match on both
## ends and not collide with something else on your machine.
const DEFAULT_PORT := 24565

## We only need 1, but headroom costs nothing and a mysterious "server full"
## while testing costs an evening.
const MAX_CLIENTS := 3

enum Role { OFFLINE, HOST, CLIENT }

var role: Role = Role.OFFLINE
var transport: NetTransport = null


func _ready() -> void:
	# These five signals are the entire connection lifecycle.
	# peer_connected / peer_disconnected fire on everyone; the other three only
	# ever fire on clients.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Public API -------------------------------------------------------------

func host_game(port: int = DEFAULT_PORT) -> bool:
	_teardown_peer()
	var t: NetTransport = ENetTransport.new()
	var err := t.create_host(port, MAX_CLIENTS)
	if err != OK:
		host_failed.emit(_explain(err, port))
		return false
	transport = t
	multiplayer.multiplayer_peer = t.get_peer()
	role = Role.HOST
	_log("hosting on %s, port %d" % [t.display_name(), port])
	hosting_started.emit()
	return true


func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> bool:
	_teardown_peer()
	var t: NetTransport = ENetTransport.new()
	var err := t.create_client(address, port)
	if err != OK:
		join_failed.emit(_explain(err, port))
		return false
	transport = t
	multiplayer.multiplayer_peer = t.get_peer()
	# We are a CLIENT from this moment, but not yet CONNECTED. The handshake
	# result arrives later as connected_to_server / connection_failed. ENet
	# gives up after a few seconds if the host never answers.
	role = Role.CLIENT
	_log("connecting to %s:%d ..." % [address, port])
	join_started.emit()
	return true


func leave() -> void:
	if role == Role.OFFLINE:
		return
	_log("leaving session")
	_teardown_peer()
	role = Role.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func is_online() -> bool:
	return role != Role.OFFLINE


## Our own peer id. Falls back to 1 when offline so that code written as
## "authority is 1" still behaves sensibly before a session exists.
func local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


## Everyone else currently in the session.
func other_peer_ids() -> PackedInt32Array:
	return multiplayer.get_peers() if is_online() else PackedInt32Array()


# --- Signal handlers --------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	_log("peer %d connected" % peer_id)
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_log("peer %d disconnected" % peer_id)
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	_log("connected, we are peer %d" % multiplayer.get_unique_id())
	join_succeeded.emit()


func _on_connection_failed() -> void:
	_log("connection failed")
	_teardown_peer()
	role = Role.OFFLINE
	join_failed.emit("Could not reach the host. Is it running, and is the port right?")


func _on_server_disconnected() -> void:
	_log("host went away")
	_teardown_peer()
	role = Role.OFFLINE
	host_disconnected.emit()


# --- Internals --------------------------------------------------------------

func _teardown_peer() -> void:
	# Detach from the SceneTree first so nothing tries to poll a dead peer,
	# then let the transport free its own resources.
	multiplayer.multiplayer_peer = null
	if transport != null:
		transport.close()
		transport = null


func _explain(err: Error, port: int) -> String:
	if err == ERR_ALREADY_IN_USE or err == ERR_CANT_CREATE:
		return "Port %d is already in use - another copy of the game is probably still hosting." % port
	return "Network error: %s" % error_string(err)


## Prefixed so you can tell the two local instances apart in the console.
func _log(msg: String) -> void:
	var who := "offline"
	match role:
		Role.HOST:
			who = "host"
		Role.CLIENT:
			who = "client:%d" % multiplayer.get_unique_id()
	print("[Net/%s] %s" % [who, msg])
