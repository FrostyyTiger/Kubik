class_name Rig
extends Node3D

## A skeleton of plain Node3Ds, one per bone, each carrying one rigid part.
##
## NOT A Skeleton3D, DELIBERATELY. Every part here is rigid and nothing is
## skinned, so there are no weights for a Skeleton3D to interpolate and its
## whole apparatus - the skin, the bone rest pose, the pose-override API -
## would be machinery around a thing that is already a transform. A Node3D's
## transform IS the entire animation state of a bone, which means:
##
##   - a self-test can read a pose by reading `rotation`, with no engine call;
##   - `Animator.pose_for()` can be a PURE function returning a dictionary of
##     bone name -> transform, testable with no scene tree at all;
##   - an AnimationPlayer can still drive these as ordinary Node3D properties
##     later, if anyone ever wants keyframes.
##
## Sockets are bones with no part. They exist on every race whether or not
## anything hangs on them, because Stage 10's deliverable is the sockets and a
## gear system that has to ask which races have a back is not a gear system.

## bone name -> Node3D
var bones := {}

## socket name -> Node3D. A subset of `bones` by construction; kept separately
## so gear code never has to know which entries are limbs.
var sockets := {}

## bone name -> the rest transform, so a pose can be expressed as a rotation
## ABOUT the rest rather than as an absolute one. Without this the animator
## would have to know every rest offset, which is exactly the per-race
## knowledge hard rule 3 keeps out of it.
var rest := {}

## bone name -> MeshInstance3D, for the mesh swaps (the blink) and for the
## triangle count.
var meshes := {}

## bone name -> the eyes-closed MeshInstance3D, for any part that has eyes.
## Hidden until a blink swaps it in.
var blink_meshes := {}


## Build the whole skeleton. Parents must appear before their children in the
## table, which Races.bone_table guarantees.
func build(bone_table: Array, part_set: Dictionary, palette: Dictionary,
		ao_strength: float, hips_pitch := 0.0) -> void:
	clear()
	for entry in bone_table:
		var bone_name: String = entry["name"]
		var node := Node3D.new()
		node.name = bone_name
		node.position = entry.get("rest", Vector3.ZERO)

		var parent_name: String = entry.get("parent", "")
		if parent_name.is_empty():
			add_child(node)
		elif bones.has(parent_name):
			bones[parent_name].add_child(node)
		else:
			push_warning("[Rig] bone %s wants parent %s, which does not exist yet - attaching to the root" % [
				bone_name, parent_name])
			add_child(node)

		bones[bone_name] = node
		rest[bone_name] = node.transform
		if entry.get("socket", false):
			sockets[bone_name] = node
			continue

		var part_name: String = entry.get("part", "")
		if part_name.is_empty():
			continue  # a bone that is only a transform, like a pelvis-less hips
		if not part_set.has(part_name):
			# An OPTIONAL bone with no part is not news: a human whose beard is
			# "none" has a beard bone and nothing to hang on it, and that is
			# the answer rather than a missing file.
			if not entry.get("optional", false):
				Races._warn_once("rig:" + part_name,
					"[Rig] no part named %s for bone %s" % [part_name, bone_name])
			continue
		_attach_part(node, bone_name, part_set[part_name], part_name,
			entry.get("mirror", false), palette, ao_strength)

	# The lizardfolk's 8 degree forward lean is baked into the hips REST pose
	# rather than applied by the animator, so it survives every pose and the
	# animator never learns that one race stands differently from the others.
	if hips_pitch != 0.0 and bones.has("hips"):
		bones["hips"].rotation.x = hips_pitch
		rest["hips"] = bones["hips"].transform


func clear() -> void:
	for child in get_children():
		child.free()
	bones.clear()
	sockets.clear()
	rest.clear()
	meshes.clear()
	blink_meshes.clear()


func _attach_part(bone: Node3D, bone_name: String, part: Dictionary,
		part_name: String, mirror: bool, palette: Dictionary,
		ao_strength: float) -> void:
	var voxels := VoxelModel.parse(part, part_name)
	if voxels.is_empty():
		return
	var anchor: Vector3 = part.get("anchor", Vector3.ZERO)
	var size: Vector3i = part["size"]
	if mirror:
		# The part is mirrored in the VOXELS, not by a negative scale on the
		# node. A -1 scale flips the winding of every triangle, so the mesh
		# renders as the inside of itself with back-face culling on, and it
		# flips the child bones' axes too - which would make the animator's
		# left and right rotations mean opposite things.
		voxels = VoxelModel.mirror_x(voxels, size.x)
		anchor = VoxelModel.mirror_anchor_x(anchor, size.x)
	var mesh := VoxelModel.build_mesh(voxels, palette, anchor, ao_strength)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	bone.add_child(mi)
	meshes[bone_name] = mi
	_attach_blink_variant(bone, bone_name, voxels, anchor, palette, ao_strength)


## The same part with its eyes resolved to skin, if it had any.
##
## ONE PART, TWO MESHES. The blink is a mesh swap and not a shader - hard rule
## 7 - and building the closed variant from the SAME voxel list is what stops
## the two heads drifting apart: there is no second head file to forget to
## update when the first one changes. Any part with eyes gets one, so a
## lizardfolk blinks for the same reason a human does and nothing has to know
## which races have eyelids.
func _attach_blink_variant(bone: Node3D, bone_name: String, voxels: Array,
		anchor: Vector3, palette: Dictionary, ao_strength: float) -> void:
	var has_eyes := false
	for v in voxels:
		if v.w == VoxelModel.IRIS or v.w == VoxelModel.EYE_WHITE:
			has_eyes = true
			break
	if not has_eyes:
		return
	var closed := VoxelModel.remap_slots(voxels, {
		VoxelModel.IRIS: VoxelModel.SKIN,
		VoxelModel.EYE_WHITE: VoxelModel.SKIN,
	})
	var mesh := VoxelModel.build_mesh(closed, palette, anchor, ao_strength)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "MeshBlink"
	mi.mesh = mesh
	mi.visible = false
	bone.add_child(mi)
	blink_meshes[bone_name] = mi


## Eyes open or eyes closed. Cheap enough to call every frame; it sets two
## booleans that are usually already what they are being set to.
func set_blinking(on: bool) -> void:
	for bone_name in blink_meshes:
		(meshes[bone_name] as MeshInstance3D).visible = not on
		(blink_meshes[bone_name] as MeshInstance3D).visible = on


# --- Posing ------------------------------------------------------------------

## Apply a pose: bone name -> `{"rot": Vector3 (radians), "pos": Vector3 (m)}`.
##
## Both are OFFSETS FROM REST. A pose that says nothing about a bone leaves it
## at rest, so the animator only has to describe what it is actually moving and
## a new bone cannot break an old pose.
func apply_pose(pose: Dictionary) -> void:
	for bone_name in bones:
		var node: Node3D = bones[bone_name]
		var base: Transform3D = rest[bone_name]
		if not pose.has(bone_name):
			node.transform = base
			continue
		var entry: Dictionary = pose[bone_name]
		var rot: Vector3 = entry.get("rot", Vector3.ZERO)
		var pos: Vector3 = entry.get("pos", Vector3.ZERO)
		# Rotation about the bone's own pivot, applied to the rest basis, so a
		# baked rest rotation (the lizardfolk's lean) composes with the pose
		# instead of being overwritten by it.
		node.transform = Transform3D(
			base.basis * Basis.from_euler(rot),
			base.origin + pos)


func rest_pose() -> void:
	apply_pose({})


# --- Facts, for the self-tests and the budget --------------------------------

## Total triangles across every part. Measured from the meshes rather than
## predicted from the voxel count, because face culling is exactly the thing
## a prediction would get wrong.
func triangle_count() -> int:
	var total := 0
	for bone_name in meshes:
		var mesh: ArrayMesh = (meshes[bone_name] as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			total += mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	return total


## Bones that are decoration on top of a body rather than part of it.
const ORNAMENT_BONES := ["hair", "beard"]

## The tallest point of the built rig, in metres above its own origin.
##
## Measured from the actual mesh AABBs in the actual pose - which is what makes
## the height self-test worth running. A height computed from the race table
## would only prove the race table agrees with itself.
##
## HAIR AND CRESTS ARE EXCLUDED BY DEFAULT, because the race table measures a
## race at the CROWN - the plan says exactly that for the lizardfolk, and it is
## the only definition that survives contact with a crest: four voxels of fin
## would otherwise make a lizardfolk 2.14 m in the height test and 1.88 m in
## every other sentence about it. Pass `true` for the silhouette's real extent,
## which is what the mask metric sees.
func height_m(include_ornaments := false) -> float:
	var top := 0.0
	for bone_name in meshes:
		if not include_ornaments and bone_name in ORNAMENT_BONES:
			continue
		var mi: MeshInstance3D = meshes[bone_name]
		var to_rig := transform_to_rig(mi)
		var aabb := mi.get_aabb()
		for i in 8:
			top = maxf(top, (to_rig * aabb.get_endpoint(i)).y)
	return top


## A node's transform relative to the rig root, composed by hand.
##
## NOT global_transform: a rig built for a self-test or for the creation
## screen's preview is not necessarily inside the scene tree, and
## global_transform outside the tree is not the answer to this question. Walking
## the parents costs nothing at the handful of bones a character has.
func transform_to_rig(node: Node3D) -> Transform3D:
	var out := Transform3D.IDENTITY
	var n := node
	while n != null and n != self:
		out = n.transform * out
		n = n.get_parent() as Node3D
	return out


## Every voxel of a built part, in RIG space and in metres. The overlap check
## in Stage 10 and the eyes-forward test both need to ask where a voxel ended
## up rather than where its part file put it.
func part_voxels_in_rig(bone_name: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not meshes.has(bone_name):
		return out
	var mi: MeshInstance3D = meshes[bone_name]
	var to_rig := transform_to_rig(mi)
	var verts: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in verts:
		out.push_back(to_rig * v)
	return out
