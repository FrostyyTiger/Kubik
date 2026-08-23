extends Node3D

## Root of the in-game scene. For now it only reports which role we are;
## the world, camera and player sync land in later commits.


func _ready() -> void:
	var role_name := "host" if Net.is_host() else "client"
	$HUD/Status.text = "Running as %s (peer id %d)" % [role_name, Net.local_peer_id()]
	print("[Game] entered as %s" % role_name)


func _unhandled_input(event: InputEvent) -> void:
	# Escape leaves the session and returns to the menu, which also tears the
	# ENet peer down so the port is free for the next Host.
	if event.is_action_pressed("ui_cancel"):
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
