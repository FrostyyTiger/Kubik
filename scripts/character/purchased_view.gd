class_name PurchasedView
extends Node3D

## A purchased, animated character scene standing in for the voxel rig.
##
## DEMO SCAFFOLDING, NOT THE CHARACTER PIPELINE. The look v3 character work
## decides how bought templates really enter the game; this class exists so a
## template can be walked around TODAY and judged in play. It is opt-in
## (`--viking` after the `--` separator, or KUBIK_VIKING=1), it loads only
## from the git-ignored purchased mount, and when the mount or the flag is
## absent the game is exactly what it was - purchased art is a drop-in layer,
## never a dependency.
##
## The scene is the seller's glTF: a segmented node rig with a ~200-clip
## AnimationPlayer. We normalise its height to the race's, ground its feet,
## and pick clips from the same LocomotionState the Animator reads. Distance
## sync is approximate (clips are time-based, our Animator is distance-based);
## that mismatch is one of the things this demo exists to let Marcel judge.

const SCENE_PATH := "res://assets/purchased/characters/viking/male_a1.gltf"

## Clip speeds the sync guesses the clips were authored at, m/s. Only used to
## lean playback speed toward the actual velocity; clamped so a wrong guess
## reads as drift, not slow motion.
const CLIP_SPEED := {"Walk 01": 1.8, "Run 01": 4.0, "Sprint 01": 7.0}
const LOOPED := ["Idle 01", "Walk 01", "Run 01", "Sprint 01",
	"Fall 01", "Jump Hover 01", "Crouch Idle 01", "Crouch Walk 01"]

var _anim: AnimationPlayer = null
var _current := ""


static func enabled() -> bool:
	if OS.get_environment("KUBIK_VIKING") == "1":
		return true
	return "--viking" in OS.get_cmdline_user_args()


static func available() -> bool:
	return ResourceLoader.exists(SCENE_PATH)


## Instance the scene, scale it to `target_height_m`, feet at y 0.
## Returns false (and leaves nothing behind) if the scene cannot be used.
func build(target_height_m: float) -> bool:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		return false
	var inst := packed.instantiate()
	add_child(inst)

	var aabb := _merged_aabb(inst)
	if aabb.size.y <= 0.0:
		inst.queue_free()
		return false
	var s := target_height_m / aabb.size.y
	inst.scale = Vector3(s, s, s)
	inst.position.y = -aabb.position.y * s
	# glTF forward is +Z; the game's characters face -Z.
	inst.rotation.y = PI

	_anim = _find_anim(inst)
	if _anim != null:
		for name in LOOPED:
			if _anim.has_animation(name):
				_anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		_play("Idle 01")
	return true


## Pick and pace a clip from what the character is doing. Called every frame
## by CharacterView while this stand-in is active.
func drive(state: LocomotionState, _delta: float) -> void:
	if _anim == null:
		return
	var clip := "Idle 01"
	if not state.grounded:
		clip = "Jump Hover 01" if state.rising else "Fall 01"
	elif state.speed >= 0.8:
		if state.mode == LocomotionState.MODE_SPRINT and state.speed > 5.0:
			clip = "Sprint 01"
		elif state.speed > 3.2:
			clip = "Run 01"
		else:
			clip = "Walk 01"
	_play(clip)
	if CLIP_SPEED.has(clip):
		_anim.speed_scale = clampf(state.speed / CLIP_SPEED[clip], 0.7, 1.5)
	else:
		_anim.speed_scale = 1.0


func _play(clip: String) -> void:
	if clip == _current or not _anim.has_animation(clip):
		return
	_current = clip
	_anim.play(clip, 0.2)


func _merged_aabb(root: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var n: Node = entry[0]
		var xf: Transform3D = entry[1]
		if n != root and n is Node3D:
			xf = xf * (n as Node3D).transform
		if n is MeshInstance3D:
			var box: AABB = xf * (n as MeshInstance3D).get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in n.get_children():
			stack.append([c, xf])
	return out


func _find_anim(root: Node) -> AnimationPlayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			return n
		for c in n.get_children():
			stack.append(c)
	return null
