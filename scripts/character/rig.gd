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

## bone name -> {"voxels": Array, "anchor": Vector3}, kept after meshing.
##
## The mesh is triangles and cannot answer "is there a voxel here"; the overlap
## check in Stage 10 has to ask exactly that, of two parts that were authored
## on lattices half a voxel apart. Keeping the list costs a few kilobytes per
## character and is the difference between a real test and an eyeballed one.
var part_voxels := {}

## socket name -> MeshInstance3D, for whatever is currently hanging on it.
var attachments := {}

## Which bone carries the race's baked forward lean, or "" for a race with
## none. Published because the height self-test has to stand a character
## upright before measuring it - an axis-aligned bound of a rotated body reads
## taller than the body - and a test that guessed the bone would silently stop
## compensating the day the lean moved. It did exactly that in character v2
## Stage 6, when the lean went from `hips` to `torso`.
var lean_bone := ""


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

		# A BAKED REST ROTATION, if the race has one. The lizardfolk's
		# digitigrade crouch arrives this way for the same reason its forward
		# lean does: baked into the rest pose, it survives every pose, and the
		# animator never learns that one race stands differently from the
		# others. `apply_pose` composes a pose onto the rest basis, so a pose
		# that says nothing about these bones leaves the crouch alone and one
		# that does adds to it.
		if entry.has("rest_rot"):
			node.rotation = entry["rest_rot"]
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

	# The lizardfolk's forward lean is baked into a REST pose rather than
	# applied by the animator, so it survives every pose and the animator never
	# learns that one race stands differently from the others.
	#
	# ON THE TORSO, NOT THE HIPS, since character v2 Stage 6 - and the
	# difference is the whole race. The legs are children of `hips`, so a lean
	# baked there rotates them too: the character tips backwards from the
	# ankles like a felled tree, its feet swing out behind it, and at anything
	# past about 20 degrees it is plainly falling over rather than running.
	# That was measured by looking: at 52 degrees on the hips the silhouette
	# metric was delighted - 0.658 front on, comfortably past target - and the
	# picture was a face-plant. A count can tell you a shape is not a human's.
	# It cannot tell you it is good.
	#
	# On the TORSO the spine leans and the legs stay under the body, which is
	# what a running animal does and what "its centre of mass is not over its
	# feet" actually means. The head is a child of the torso, so "head low and
	# forward" comes for free; the tail hangs off the hips and stays level to
	# counterweight it, which is the other half of the design doc's horizontal S.
	lean_bone = ""
	var wanted := "torso" if bones.has("torso") else "hips"
	if hips_pitch != 0.0 and bones.has(wanted):
		lean_bone = wanted
		bones[lean_bone].rotation.x = hips_pitch
		rest[lean_bone] = bones[lean_bone].transform


func clear() -> void:
	for child in get_children():
		child.free()
	bones.clear()
	sockets.clear()
	rest.clear()
	meshes.clear()
	blink_meshes.clear()
	part_voxels.clear()
	attachments.clear()
	lean_bone = ""


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
	# A part MAY CARRY ITS OWN PALETTE. A `.vox` loaded without the slot
	# convention has real colours in it rather than slots, and those colours
	# are the artist's intent - so they win over the character's palette for
	# that part, and the part simply does not take a skin swap. See VoxLoader.
	var resolved := palette
	if part.has("palette"):
		resolved = palette.duplicate()
		resolved.merge(part["palette"], true)
	var mesh := VoxelModel.build_mesh(voxels, resolved, anchor, ao_strength)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	bone.add_child(mi)
	meshes[bone_name] = mi
	part_voxels[bone_name] = {"voxels": voxels, "anchor": anchor}
	_attach_blink_variant(bone, bone_name, voxels, anchor, resolved, ao_strength)


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

## Total triangles across every part AND anything hanging on a socket.
##
## Measured from the meshes rather than predicted from the voxel count, because
## face culling is exactly the thing a prediction would get wrong - and the
## attachments are counted because a budget that ignored what a character is
## carrying would be a budget for an unarmed one.
##
## The eyes-closed head variant is NOT counted: it exists but is hidden, and
## exactly one of the two heads is visible at any moment.
func triangle_count() -> int:
	var total := 0
	for bone_name in meshes:
		total += _triangles_of(meshes[bone_name])
	for socket_name in attachments:
		total += _triangles_of(attachments[socket_name])
	return total


func _triangles_of(node: MeshInstance3D) -> int:
	var total := 0
	var mesh: ArrayMesh = node.mesh
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


## Every voxel CENTRE of a built part, in RIG space and in metres.
##
## Centres rather than mesh vertices: two parts authored on lattices half a
## voxel apart share no vertex even when they occupy the same space, so a
## vertex comparison would report no overlap for two solids sitting inside each
## other. Centres plus a half-voxel tolerance is the question actually being
## asked - does a voxel of this part occupy the same cell as a voxel of that
## one.
func voxel_centres_in_rig(bone_name: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not part_voxels.has(bone_name) or not meshes.has(bone_name):
		return out
	var entry: Dictionary = part_voxels[bone_name]
	var anchor: Vector3 = entry["anchor"]
	var to_rig := transform_to_rig(meshes[bone_name])
	for v in (entry["voxels"] as Array):
		var centre := (Vector3(v.x, v.y, v.z) + Vector3(0.5, 0.5, 0.5) - anchor) * VoxelModel.VOXEL_M
		out.push_back(to_rig * centre)
	return out


# --- Sockets ------------------------------------------------------------------

## Hang a part on a socket. The part is authored in the SOCKET's own frame.
func attach_to_socket(socket_name: String, part: Dictionary, part_name: String,
		palette: Dictionary, ao_strength: float) -> void:
	if not sockets.has(socket_name):
		push_warning("[Rig] no socket named %s" % socket_name)
		return
	var voxels := VoxelModel.parse(part, part_name)
	if voxels.is_empty():
		return
	var anchor: Vector3 = part.get("anchor", Vector3.ZERO)
	var mesh := VoxelModel.build_mesh(voxels, palette, anchor, ao_strength)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Gear_" + part_name
	mi.mesh = mesh
	(sockets[socket_name] as Node3D).add_child(mi)
	attachments[socket_name] = mi
	part_voxels["socket:" + socket_name] = {"voxels": voxels, "anchor": anchor}


func clear_attachments() -> void:
	for socket_name in attachments:
		(attachments[socket_name] as MeshInstance3D).queue_free()
		part_voxels.erase("socket:" + socket_name)
	attachments.clear()


## The same voxel-centre question, for something hanging on a socket.
func socket_voxel_centres_in_rig(socket_name: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var key := "socket:" + socket_name
	if not part_voxels.has(key) or not attachments.has(socket_name):
		return out
	var entry: Dictionary = part_voxels[key]
	var anchor: Vector3 = entry["anchor"]
	var to_rig := transform_to_rig(attachments[socket_name])
	for v in (entry["voxels"] as Array):
		var centre := (Vector3(v.x, v.y, v.z) + Vector3(0.5, 0.5, 0.5) - anchor) * VoxelModel.VOXEL_M
		out.push_back(to_rig * centre)
	return out
