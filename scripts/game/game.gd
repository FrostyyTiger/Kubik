extends Node3D

## Root of the in-game scene.

## Temporary. Next step is the host picking a seed and sending it during the
## join handshake. Until then a shared constant does the same job: both
## machines generate byte-identical terrain with zero voxels on the wire.
const DEBUG_SEED := 1337

@onready var _world: World = $World
@onready var _status: Label = $HUD/Status


func _ready() -> void:
	var role_name := "host" if Net.is_host() else "client"
	_status.text = "%s - generating world..." % role_name
	_world.generation_finished.connect(_on_world_ready)
	_world.setup(DEBUG_SEED)


func _on_world_ready(chunk_count: int, elapsed_ms: int) -> void:
	var role_name := "host" if Net.is_host() else "client"
	_status.text = "%s (peer %d) - %d chunks in %d ms - seed %d" % [
		role_name, Net.local_peer_id(), chunk_count, elapsed_ms, _world.world_seed]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
