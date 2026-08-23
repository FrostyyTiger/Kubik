class_name ENetTransport
extends NetTransport

## ENet: reliable-UDP networking bundled with Godot. Zero setup, perfect for
## localhost and LAN.
##
## Its limitation is why we plan to move to Steam networking later: ENet needs
## the joining player to reach the host's IP and port directly, which means port
## forwarding for anyone outside your LAN. Steam's relay does NAT traversal for
## us. That swap will replace this file, and nothing else.

var _peer: ENetMultiplayerPeer = null


func display_name() -> String:
	return "ENet"


func create_host(port: int, max_clients: int) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		return err
	_peer = peer
	return OK


func create_client(address: String, port: int) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_peer = peer
	return OK


func get_peer() -> MultiplayerPeer:
	return _peer


func close() -> void:
	if _peer != null:
		# Disconnects everyone and frees the underlying ENet host. Safe to call
		# on a peer that never connected.
		_peer.close()
		_peer = null
