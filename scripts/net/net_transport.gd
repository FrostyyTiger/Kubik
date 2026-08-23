class_name NetTransport
extends RefCounted

## The seam between "how packets reach the other machine" and everything else.
##
## Godot's high-level multiplayer API talks to a MultiplayerPeer and does not
## care what is underneath it. ENet, WebRTC and GodotSteam's SteamMultiplayerPeer
## are all MultiplayerPeer implementations. So a transport has exactly one job:
## build a configured peer, or explain why it could not.
##
## Deliberately NOT in this interface: sending messages. Game code uses plain
## @rpc functions. If we wrapped RPCs here, every gameplay system would be
## written against our wrapper and "swap the transport" would quietly become
## "rewrite the game".


## Short name for logs and UI ("ENet", "Steam", ...).
func display_name() -> String:
	return "abstract"


## Start listening. Returns OK, or a Godot error code (e.g. ERR_ALREADY_IN_USE
## when the port is taken - which happens a lot when testing two local copies).
func create_host(_port: int, _max_clients: int) -> Error:
	_not_implemented("create_host")
	return ERR_UNCONFIGURED


## Begin connecting to a host. OK here only means the ATTEMPT started; whether
## the handshake succeeds arrives later via MultiplayerAPI signals.
func create_client(_address: String, _port: int) -> Error:
	_not_implemented("create_client")
	return ERR_UNCONFIGURED


## The peer to assign to `multiplayer.multiplayer_peer`, or null if not started.
func get_peer() -> MultiplayerPeer:
	return null


## Tear everything down. Must be safe to call on an already-closed transport.
func close() -> void:
	pass


func _not_implemented(what: String) -> void:
	push_error("NetTransport.%s() called on the abstract base class." % what)
