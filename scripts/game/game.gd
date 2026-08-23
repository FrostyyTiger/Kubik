extends Node3D

## Root of the in-game scene.

## Temporary. Next step is the host picking a seed and sending it during the
## join handshake. Until then a shared constant does the same job: both
## machines generate byte-identical terrain with zero voxels on the wire.
const DEBUG_SEED := 1337

## Scaffolding: a fixed spot well above the terrain band, so the debug slab is
## guaranteed to land in open air and be visible from anywhere.
const DEBUG_SLAB_Y := 47

@onready var _world: World = $World
@onready var _status: Label = $HUD/Status

var _slab_present := false


func _ready() -> void:
	var role_name := "host" if Net.is_host() else "client"
	_status.text = "%s - generating world..." % role_name
	_world.generation_finished.connect(_on_world_ready)
	_world.setup(DEBUG_SEED)


func _on_world_ready(chunk_count: int, elapsed_ms: int) -> void:
	var role_name := "host" if Net.is_host() else "client"
	_status.text = "%s (peer %d) - %d chunks in %d ms - seed %d - [G] toggle test slab" % [
		role_name, Net.local_peer_id(), chunk_count, elapsed_ms, _world.world_seed]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	# TEMPORARY until we have block interaction (raycast + break/place).
	# Exists so the authority chain can be verified end to end today: press G
	# on the CLIENT and the slab still appears on both machines, because the
	# client only sent a request and the host broadcast the result back.
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
