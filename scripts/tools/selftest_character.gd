extends Node

## Character self-tests, offline.
##
##     godot --headless --path . scenes/character/selftest_character.tscn
##
## A second suite rather than more cases in scripts/tools/selftest.gd, because
## that file belongs to worldgen and to two other branches running the same
## night. Same shape, same rules, same exit convention - see selftest.gd for
## why the suite is a scene and not `--script`.
##
## Everything here checks something you cannot see by looking at the character:
## which way its face points in model space, whether a byte a stranger sent can
## crash the machine that receives it, whether the walk cycle advances by
## distance rather than by time.

func _ready() -> void:
	# UNTYPED CALLABLES, DELIBERATELY. A runtime error inside a test does not
	# stop the run and does not report one: GDScript aborts the failing
	# function and returns the default value of its declared return type, so a
	# test declared `-> int` that crashes comes back as 0 - this file's code
	# for "passed". An aborted untyped function returns null instead, which is
	# a value no test returns on purpose. See selftest.gd, where a crashing
	# test printed "all passed" twice before anyone noticed.
	var tests := {
		"mesher faces": _test_mesher_faces,
		"mesher winding": _test_mesher_winding,
		"mesher ao": _test_mesher_ao,
		"palette swap": _test_palette_swap,
		"part parsing": _test_part_parsing,
		"eyes forward": _test_eyes_forward,
		"rig completeness": _test_rig_completeness,
		"character height": _test_character_height,
		"def round trip": _test_def_round_trip,
		"def from strangers": _test_def_from_strangers,
	}
	var failures := 0
	for name in tests:
		var result = (tests[name] as Callable).call()
		if not (result is int):
			print("  %s DID NOT COMPLETE - it returned %s, so it crashed" % [
				name, type_string(typeof(result))])
			failures += 1
			continue
		failures += result
	print("")
	print("CHARACTER SELFTEST: %d tests, %s" % [
		tests.size(), "all passed" if failures == 0 else "%d FAILED" % failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- Helpers ----------------------------------------------------------------

## A palette that answers every slot, so a mesh built with it never falls back
## to magenta and a colour comparison is comparing what it means to.
func _flat_palette(c := Color(0.5, 0.5, 0.5)) -> Dictionary:
	var p := {}
	for slot in VoxelModel.SLOT_COUNT:
		p[slot] = c
	return p


func _solid_cube(n: int, slot := VoxelModel.SKIN) -> Array:
	var out := []
	for y in n:
		for z in n:
			for x in n:
				out.append(Vector4i(x, y, z, slot))
	return out


func _mesh_arrays(mesh: ArrayMesh) -> Array:
	return mesh.surface_get_arrays(0)


# --- Tests ------------------------------------------------------------------

## FACE COUNTS, which is the whole of "hidden faces are culled".
##
## A single voxel has six faces and twelve triangles. A solid 3 x 3 x 3 has
## nine voxel-faces on each of its six sides and nothing else visible, so 54
## quads - and that number is the one that proves there is no greedy merge, as
## a merged 3 x 3 x 3 would come back as 6.
##
## THE PLAN SAYS a 2 x 2 x 2 part "meshes to 6 faces and 12 triangles". That is
## the 1 x 1 x 1 answer: with no merging a solid 2 x 2 x 2 has four voxel-faces
## per side, so 24 quads and 48 triangles, and the plan's own 3 x 3 x 3 = 54
## line agrees with that arithmetic and not with the 2 x 2 x 2 line. Both cases
## are checked below against the numbers the mesher's stated rule actually
## implies. See the status doc.
func _test_mesher_faces():
	var bad := 0
	var palette := _flat_palette()

	var cases := [
		{"n": 1, "quads": 6, "tris": 12},
		{"n": 2, "quads": 24, "tris": 48},
		{"n": 3, "quads": 54, "tris": 108},
	]
	for case in cases:
		var n: int = case["n"]
		var mesh := VoxelModel.build_mesh(_solid_cube(n), palette, Vector3.ZERO, 0.0)
		var arrays := _mesh_arrays(mesh)
		var quads: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 4
		var tris: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		if quads != case["quads"] or tris != case["tris"]:
			print("  solid %dx%dx%d: %d quads / %d tris, wanted %d / %d" % [
				n, n, n, quads, tris, case["quads"], case["tris"]])
			bad += 1

	# Every normal points AWAY from the part's centroid. On a convex solid this
	# is exactly "no face is inside out", and it is the check that catches a
	# sign error in the face loop that face counts alone would not.
	var mesh1 := VoxelModel.build_mesh(_solid_cube(1), palette, Vector3.ZERO, 0.0)
	var a1 := _mesh_arrays(mesh1)
	var verts: PackedVector3Array = a1[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = a1[Mesh.ARRAY_NORMAL]
	var centroid := Vector3.ZERO
	for p in verts:
		centroid += p
	centroid /= float(verts.size())
	var inward := 0
	for i in verts.size():
		if (verts[i] - centroid).normalized().dot(normals[i]) <= 0.0:
			inward += 1
	if inward > 0:
		print("  %d of %d vertex normals point inward" % [inward, verts.size()])
		bad += 1

	print("part mesher: 1/2/3-cube face counts and normals, %d checks failed" % bad)
	return 1 if bad > 0 else 0


## WINDING. Every triangle must satisfy (p1 - p0) x (p2 - p0) == -normal, which
## is "clockwise seen from outside" - the face Godot draws, since back faces
## are culled. Same identity the world mesher is tested against, because it is
## the same identity: a character with its winding reversed does not lose a
## face, it renders as the inside of itself.
func _test_mesher_winding():
	var bad := 0
	var checked := 0
	var palette := _flat_palette()
	# A hollow-ish shape as well as a solid one, so both face signs on all
	# three axes are exercised and an interior face cannot hide a mistake.
	var shapes := {
		"cube3": _solid_cube(3),
		"L": [
			Vector4i(0, 0, 0, VoxelModel.SKIN), Vector4i(1, 0, 0, VoxelModel.SKIN),
			Vector4i(2, 0, 0, VoxelModel.SKIN), Vector4i(0, 1, 0, VoxelModel.SKIN),
			Vector4i(0, 2, 0, VoxelModel.SKIN), Vector4i(0, 0, 1, VoxelModel.SKIN),
		],
	}
	for name in shapes:
		var mesh := VoxelModel.build_mesh(shapes[name], palette, Vector3.ZERO, 0.0)
		var arrays := _mesh_arrays(mesh)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var p0 := verts[indices[t]]
			var p1 := verts[indices[t + 1]]
			var p2 := verts[indices[t + 2]]
			var cross := (p1 - p0).cross(p2 - p0).normalized()
			var want := -normals[indices[t]]
			checked += 1
			if cross.distance_to(want) > 0.001:
				bad += 1
				if bad <= 3:
					print("  %s triangle %d: cross %s but -normal is %s" % [
						name, t / 3, cross, want])

	print("part winding: %d triangles checked, %d wrong" % [checked, bad])
	return 1 if bad > 0 else 0


## BAKED CORNER AO, in the two cases that matter.
##
## An L in one plane has an inner corner with ONE side solid: level 2, a gentle
## darkening, and the case almost every vertex on a real character is in. A
## 2 x 2 x 2 cube with one voxel taken out has a genuine concave corner where
## TWO sides are solid: level 0, full strength, and the special case in
## _vertex_ao that stops a bright seam running up every join.
##
## Checking only the L would leave the special case untested, which was the
## first version of this test - it passed, and it was measuring level 2.
##
## THE TOLERANCE IS ONE COLOUR STEP, not an epsilon. ArrayMesh stores vertex
## colours as RGBA8, so a shade of 0.650 comes back out as 165/255 = 0.647 and
## an exact comparison fails by three thousandths. Worth knowing before
## debugging the AO maths over it, which is how this was found.
func _test_mesher_ao():
	var bad := 0
	var strength := 0.35
	# One 8-bit colour step, with a little room. See above.
	var tol := 1.5 / 255.0
	var palette := _flat_palette(Color(1.0, 1.0, 1.0))

	# One side solid -> level 2 -> 1 - strength * (1 - 2/3).
	var l_shape := [
		Vector4i(0, 0, 0, VoxelModel.SKIN),
		Vector4i(1, 0, 0, VoxelModel.SKIN),
		Vector4i(0, 1, 0, VoxelModel.SKIN),
	]
	var l_dark := _darkest(VoxelModel.build_mesh(l_shape, palette, Vector3.ZERO, strength))
	var l_light := _lightest(VoxelModel.build_mesh(l_shape, palette, Vector3.ZERO, strength))
	var want_l := 1.0 - strength * (1.0 - 2.0 / 3.0)
	if not (l_dark < l_light):
		print("  the L is flat (%.3f everywhere) - AO did nothing" % l_dark)
		bad += 1
	if absf(l_dark - want_l) > tol:
		print("  L inner corner is %.3f, wanted %.3f (level 2)" % [l_dark, want_l])
		bad += 1

	# Both sides solid -> level 0 -> full strength, whatever the diagonal does.
	var notch := []
	for y in 2:
		for z in 2:
			for x in 2:
				if not (x == 1 and y == 1 and z == 1):
					notch.append(Vector4i(x, y, z, VoxelModel.SKIN))
	var n_dark := _darkest(VoxelModel.build_mesh(notch, palette, Vector3.ZERO, strength))
	if absf(n_dark - (1.0 - strength)) > tol:
		print("  concave corner is %.3f, wanted %.3f (level 0, full strength)" % [
			n_dark, 1.0 - strength])
		bad += 1

	# ...and with AO off the whole thing is flat, or the strength knob is not
	# actually a knob.
	var flat := _darkest(VoxelModel.build_mesh(notch, palette, Vector3.ZERO, 0.0))
	if absf(flat - 1.0) > tol:
		print("  ao_strength 0 still shaded a vertex to %.3f" % flat)
		bad += 1

	print("part AO: L corner %.3f, concave corner %.3f, open 1.000, %d checks failed" % [
		l_dark, n_dark, bad])
	return 1 if bad > 0 else 0


func _darkest(mesh: ArrayMesh) -> float:
	var out := 2.0
	for c in (_mesh_arrays(mesh)[Mesh.ARRAY_COLOR] as PackedColorArray):
		out = minf(out, c.r)
	return out


func _lightest(mesh: ArrayMesh) -> float:
	var out := -1.0
	for c in (_mesh_arrays(mesh)[Mesh.ARRAY_COLOR] as PackedColorArray):
		out = maxf(out, c.r)
	return out


## THE SAME VOXELS THROUGH TWO PALETTES ARE THE SAME MESH.
##
## This is the property the whole "parts are authored in slots" decision rests
## on: a palette swap must cost nothing but a colour array, so it can be done
## on every click of the creation screen. If the vertices moved, the swap would
## be a rebuild and the screen would have to be built differently.
func _test_palette_swap():
	var bad := 0
	var part := [
		Vector4i(0, 0, 0, VoxelModel.SKIN),
		Vector4i(0, 1, 0, VoxelModel.HAIR),
	]
	var pal_a := _flat_palette(Color(0.2, 0.3, 0.4))
	var pal_b := _flat_palette(Color(0.2, 0.3, 0.4))
	pal_b[VoxelModel.HAIR] = Color(0.9, 0.1, 0.1)

	var a := _mesh_arrays(VoxelModel.build_mesh(part, pal_a, Vector3.ZERO, 0.0))
	var b := _mesh_arrays(VoxelModel.build_mesh(part, pal_b, Vector3.ZERO, 0.0))

	var va: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	if va.size() != vb.size():
		print("  vertex counts differ: %d vs %d" % [va.size(), vb.size()])
		bad += 1
	else:
		for i in va.size():
			if va[i] != vb[i]:
				print("  vertex %d moved: %s vs %s" % [i, va[i], vb[i]])
				bad += 1
				break

	# The colours differ, and ONLY on the vertices belonging to the voxel whose
	# slot the two palettes disagree about.
	var ca: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var cb: PackedColorArray = b[Mesh.ARRAY_COLOR]
	var differ := 0
	for i in ca.size():
		if ca[i] != cb[i]:
			differ += 1
	# The hair voxel is one cube with six faces exposed on five sides (the
	# sixth is against the skin voxel), so five quads, twenty vertices.
	if differ != 20:
		print("  %d vertices changed colour, wanted 20 (the hair voxel's five open faces)" % differ)
		bad += 1

	print("palette swap: %d vertices, %d recoloured, %d checks failed" % [
		ca.size(), differ, bad])
	return 1 if bad > 0 else 0


## THE PARSER REJECTS A MALFORMED PART, and does it loudly.
##
## Four ways to get a part wrong, and every one of them has to come back empty
## rather than nearly right. The push_error lines these produce are EXPECTED
## and are printed by the engine above this test's own line; a run with no
## error output here is a run where the parser stopped checking.
func _test_part_parsing():
	var bad := 0

	# The reference: a well-formed 2 wide, 2 tall, 1 deep part.
	var good := {
		"size": Vector3i(2, 2, 1),
		"anchor": Vector3i(0, 0, 0),
		"slices": [["SS"], ["S."]],
	}
	var voxels := VoxelModel.parse(good, "good")
	if voxels.size() != 3:
		print("  a valid part parsed to %d voxels, wanted 3" % voxels.size())
		bad += 1

	# THE COLUMN MAPPING. "S." is a voxel at the LEFT of the picture, which is
	# +X - so x = size.x - 1 = 1, not 0. Getting this backwards mirrors every
	# part in the game and is invisible on anything symmetric.
	var top := VoxelModel.voxels_with_slot(voxels, VoxelModel.SKIN).filter(
		func(v): return v.y == 1)
	if top.size() != 1 or top[0].x != 1:
		print("  'S.' put its voxel at x=%s, wanted x=1 (first column is +X)" % [
			top[0].x if top.size() == 1 else "?"])
		bad += 1

	print("  (the four ERROR lines below are expected - the parser is meant to shout)")
	var broken := {
		"ragged row": {"size": Vector3i(2, 1, 1), "slices": [["SSS"]]},
		"wrong slice count": {"size": Vector3i(2, 2, 1), "slices": [["SS"]]},
		"wrong depth": {"size": Vector3i(2, 1, 2), "slices": [["SS"]]},
		"unknown character": {"size": Vector3i(2, 1, 1), "slices": [["S?"]]},
	}
	for name in broken:
		var got := VoxelModel.parse(broken[name], name)
		if not got.is_empty():
			print("  a part with a %s parsed to %d voxels instead of nothing" % [
				name, got.size()])
			bad += 1

	print("part parsing: 4 malformed parts rejected, %d checks failed" % bad)
	return 1 if bad > 0 else 0


# --- Stage 3 -----------------------------------------------------------------

## THE EYES ARE ON THE FRONT, AND THE FRONT IS WHERE THE CHARACTER GOES.
##
## This is the test the whole of terrain v2's facing fix has been waiting for.
## `Player._face_movement()` computes `atan2(-wish.x, -wish.z)`, and the world
## self-test already proves that yaw sends `Vector3.FORWARD` along the wish
## direction. What nobody could check until tonight is the other half: that the
## MODEL'S FACE is on the -Z side. The capsule was rotationally symmetric, so a
## model built back-to-front would have looked exactly like a correct one and
## the bug would have surfaced as "the new character walks backwards".
##
## Two assertions, and the second is the one that matters:
##
##   1. In model space, the iris voxels sit forward of the head's own centre.
##   2. On a BUILT rig turned by the yaw the player actually uses, the
##      direction from the head's centre to its eyes points along the travel
##      direction - checked at ten headings, including off-axis ones so a sign
##      error on one axis alone cannot hide.
func _test_eyes_forward():
	var bad := 0

	var head: Dictionary = PartsHuman.HEAD
	var voxels := VoxelModel.parse(head, "head")
	var iris := VoxelModel.slot_centroid(voxels, VoxelModel.IRIS)
	var iris_count := VoxelModel.voxels_with_slot(voxels, VoxelModel.IRIS).size()
	if iris_count == 0:
		print("  the head has no iris voxels at all")
		return 1

	var centre := Vector3.ZERO
	for v in voxels:
		centre += Vector3(v.x, v.y, v.z)
	centre /= float(voxels.size())

	if not (iris.z < centre.z):
		print("  iris centroid z is %.2f and the head's is %.2f - the face is on the BACK" % [
			iris.z, centre.z])
		bad += 1

	# ...and the same fact, through the mesher, the anchor, the bone table and
	# the yaw expression, on a rig that has actually been built.
	var view := CharacterView.new()
	view.build(CharacterDef.new())
	var rig: Rig = view.rig
	var anchor: Vector3 = head["anchor"]
	var to_rig := rig.transform_to_rig(rig.bones["head"])
	# Voxel centres, so a 1 x 1 iris is measured at its middle and not at its
	# corner.
	var iris_m: Vector3 = to_rig * ((iris + Vector3(0.5, 0.5, 0.5) - anchor) * VoxelModel.VOXEL_M)
	var centre_m: Vector3 = to_rig * ((centre + Vector3(0.5, 0.5, 0.5) - anchor) * VoxelModel.VOXEL_M)
	var face_dir := Vector3(iris_m.x - centre_m.x, 0.0, iris_m.z - centre_m.z)
	if face_dir.length() < 0.001:
		print("  the eyes are directly above the head's centre - nothing to face with")
		bad += 1
	else:
		face_dir = face_dir.normalized()
		var worst := 1.0
		for degrees in [0, 45, 90, 135, 180, 225, 270, 315, 23, 197]:
			var a := deg_to_rad(float(degrees))
			var wish := Vector3(sin(a), 0.0, cos(a))
			# The expression from Player._face_movement(), unchanged.
			var yaw := atan2(-wish.x, -wish.z)
			var pointed := (Basis(Vector3.UP, yaw) * face_dir).normalized()
			var agreement := pointed.dot(wish)
			worst = minf(worst, agreement)
			if agreement < 0.999:
				bad += 1
				if bad <= 3:
					print("  %d deg: wish %s but the face points %s" % [degrees, wish, pointed])
		print("  built rig: worst face-vs-travel agreement %.4f over 10 headings" % worst)
	view.free()

	print("eyes forward: %d iris voxels at z %.2f against a head centre of %.2f, %d checks failed" % [
		iris_count, iris.z, centre.z, bad])
	return 1 if bad > 0 else 0


## EVERY BONE HAS A PART OR IS A SOCKET, AND EVERY SOCKET EXISTS.
##
## The sockets half is the one with teeth. Stage 10's deliverable is the
## sockets, not the placeholder sword, and a gear system that has to ask which
## races have a back is not a gear system - so all six exist on every race,
## whether or not anything will ever hang on them.
func _test_rig_completeness():
	var bad := 0
	var view := CharacterView.new()
	view.build(CharacterDef.new())
	var rig: Rig = view.rig

	var table := Races.bone_table(Races.HUMAN, Races.STOCKY)
	var parts := Races.part_set(Races.HUMAN, Races.STOCKY)
	var transforms_only := 0
	for entry in table:
		var bone_name: String = entry["name"]
		if not rig.bones.has(bone_name):
			print("  bone %s is in the table but not on the rig" % bone_name)
			bad += 1
			continue
		if entry.get("socket", false):
			continue
		var part_name: String = entry.get("part", "")
		if part_name.is_empty():
			# Legal: a race whose stack leaves no room for a pelvis has a hips
			# bone that is a pure transform with a socket on it.
			transforms_only += 1
			continue
		if not parts.has(part_name):
			print("  bone %s wants part %s, which the human part set does not have" % [
				bone_name, part_name])
			bad += 1
		elif not rig.meshes.has(bone_name):
			print("  bone %s has part %s but no mesh was built" % [bone_name, part_name])
			bad += 1

	for socket_name in Races.SOCKET_NAMES:
		if not rig.sockets.has(socket_name):
			print("  socket %s is missing" % socket_name)
			bad += 1

	print("rig completeness: %d bones, %d meshes, %d sockets, %d pure transforms, %d checks failed" % [
		rig.bones.size(), rig.meshes.size(), rig.sockets.size(), transforms_only, bad])
	view.free()
	return 1 if bad > 0 else 0


## THE BUILT HUMAN IS 32 VOXELS TALL, within one voxel.
##
## Measured off the mesh AABBs of the rig that was actually built, not summed
## from the race table - a height computed from the table would only prove the
## table agrees with itself, and the thing that can actually go wrong is an
## anchor or a rest offset being a voxel out.
func _test_character_height():
	var bad := 0
	var view := CharacterView.new()
	view.build(CharacterDef.new())
	var got := view.height_m()
	var want := Races.height_m(Races.HUMAN)
	var tris := view.triangle_count()
	if absf(got - want) > VoxelModel.VOXEL_M:
		print("  the human is %.4f m, wanted %.4f m (within one voxel)" % [got, want])
		bad += 1
	# The budget, reported rather than gated at this stage - hair and beard are
	# still to come and Stage 14 is where the number is judged.
	if tris > 6000:
		print("  the bald human is already %d triangles, over the 6000 budget" % tris)
		bad += 1
	print("character height: %.4f m against %.4f m wanted, %d triangles, %d checks failed" % [
		got, want, tris, bad])
	view.free()
	return 1 if bad > 0 else 0


## A DEF SURVIVES BOTH ROUND TRIPS.
##
## Bytes for the wire, a dictionary for the save file. Two shapes rather than
## one because they answer different questions: eight bytes is what a friend
## sends twenty times a second, and a dictionary of named fields is what
## survives a new field being added when the world save eventually exists.
func _test_def_round_trip():
	var bad := 0
	var checked := 0
	for race in Races.RACE_COUNT:
		for skin in Races.skin_count(race):
			var a := CharacterDef.new()
			a.race = race
			a.skin = skin
			a.hair_color = skin % Races.hair_color_count(race)
			a.eyes = skin % Races.eye_count(race)
			a.hair = skin % Races.hair_count(race)
			a.beard = skin % maxi(Races.beard_count(race), 1)
			a.build = Races.LEAN if Races.has_lean(race) else Races.STOCKY
			a.name_text = "peer test"
			a.validate()

			var b := CharacterDef.from_bytes(a.to_bytes())
			checked += 1
			for field in ["race", "build", "skin", "hair_color", "eyes", "hair", "beard"]:
				if a.get(field) != b.get(field):
					print("  bytes lost %s: %s -> %s" % [field, a.get(field), b.get(field)])
					bad += 1

			var c := CharacterDef.new()
			c.from_dict(a.to_dict())
			if c.to_dict() != a.to_dict():
				print("  the dictionary round trip changed %s" % a.describe())
				bad += 1

	# The name is sanitised, not round-tripped: control characters go, the
	# length is capped, and an empty name becomes something a player can be
	# called by.
	var names := {
		"Marcel": "Marcel",
		"  padded  ": "padded",
		"a\nb": "ab",
		"0123456789abcdefGHIJ": "0123456789abcdef",
		"": "peer 7",
		"\t\t": "peer 7",
	}
	for raw in names:
		var got := CharacterDef.sanitise_name(raw, 7)
		if got != names[raw]:
			print("  sanitise_name(%s) gave \"%s\", wanted \"%s\"" % [
				JSON.stringify(raw), got, names[raw]])
			bad += 1

	print("def round trip: %d defs through bytes and dict, %d names, %d checks failed" % [
		checked, names.size(), bad])
	return 1 if bad > 0 else 0


## BYTES FROM A STRANGER NEVER PRODUCE SOMETHING THAT CANNOT BE BUILT.
##
## A remote view must never fail to build. A character that fails to appear is
## a bug; a game that crashes because a friend's beard index was 7 is a
## disaster, and this is the test that keeps the second one from happening.
##
## The hundred arrays are the RIGHT length and the RIGHT version with garbage
## in every other byte, because that is the interesting case - a wrong length
## or version is rejected in one line, and a well-formed packet full of nonsense
## is the one that has to be clamped field by field. The malformed cases are
## checked separately below and DO print warnings; that is the point of them.
func _test_def_from_strangers():
	var bad := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260824

	for i in 100:
		var data := PackedByteArray()
		data.resize(CharacterDef.WIRE_BYTES)
		data[0] = CharacterDef.WIRE_VERSION
		for b in range(1, CharacterDef.WIRE_BYTES):
			data[b] = rng.randi_range(0, 255)
		var def := CharacterDef.from_bytes(data)
		if def == null:
			print("  from_bytes returned null on array %d" % i)
			bad += 1
			continue
		# Already valid: validating again must change nothing.
		var before := def.to_dict()
		def.validate()
		if def.to_dict() != before:
			print("  array %d came back needing another validate(): %s -> %s" % [
				i, before, def.to_dict()])
			bad += 1
		# And it must actually build.
		var view := CharacterView.new()
		view.build(def)
		if view.rig == null or view.rig.bones.is_empty():
			print("  array %d produced a def that would not build: %s" % [i, def.describe()])
			bad += 1
		view.free()

	print("  (the warnings below are expected - four deliberately malformed packets)")
	var malformed := [
		PackedByteArray(),
		PackedByteArray([1, 0, 0]),
		PackedByteArray([9, 99, 99, 99, 99, 99, 99, 99]),
		PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]),
	]
	for data in malformed:
		var def := CharacterDef.from_bytes(data)
		if def == null or def.race != Races.HUMAN:
			print("  a malformed packet did not come back as the default human")
			bad += 1

	print("def from strangers: 100 random payloads plus 4 malformed, %d checks failed" % bad)
	return 1 if bad > 0 else 0
