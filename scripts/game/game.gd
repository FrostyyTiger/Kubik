extends Node3D

## Root of the in-game scene.

## Temporary. Next step is the host picking a seed and sending it during the
## join handshake. Until then a shared constant does the same job: both
## machines generate byte-identical terrain with zero voxels on the wire.
const DEBUG_SEED := 1337

## Scaffolding: a fixed spot well above the terrain band, so the debug slab is
## guaranteed to land in open air and be visible from anywhere.
const DEBUG_SLAB_Y := 47

## How far above the ground to drop the camera once the world exists.
const SPAWN_CLEARANCE := 6.0

@onready var _world: World = $World
@onready var _camera: FlyCamera = $FlyCamera
@onready var _status: Label = $HUD/Status

var _slab_present := false


func _ready() -> void:
	_status.text = "%s - generating world..." % _role_name()
	_world.generation_finished.connect(_on_world_ready)
	_world.setup(DEBUG_SEED)


func _on_world_ready(chunk_count: int, elapsed_ms: int) -> void:
	# The camera starts above everything so it is never buried mid-generation;
	# once the terrain exists we drop it to just above the ground at the
	# origin. Happens within a second of entering the scene.
	var surface := _world.find_surface_y(0, 0)
	_camera.position = Vector3(0.5, surface + SPAWN_CLEARANCE, 0.5)

	_status.text = "%s (peer %d) | %d chunks in %d ms | seed %d | WASD+mouse, Space/Ctrl, [G] test slab, Esc" % [
		_role_name(), Net.local_peer_id(), chunk_count, elapsed_ms, _world.world_seed]


func _unhandled_input(event: InputEvent) -> void:
	# Reaches us only if FlyCamera did not consume it, which is how the
	# two-stage Escape works: first press frees the cursor, second lands here.
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


func _role_name() -> String:
	return "host" if Net.is_host() else "client"
