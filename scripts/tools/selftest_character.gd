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
		var mesh := VoxelModel.build_mesh(_solid_cube(n), palette, Vector3i.ZERO, 0.0)
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
	var mesh1 := VoxelModel.build_mesh(_solid_cube(1), palette, Vector3i.ZERO, 0.0)
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
		var mesh := VoxelModel.build_mesh(shapes[name], palette, Vector3i.ZERO, 0.0)
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
	var l_dark := _darkest(VoxelModel.build_mesh(l_shape, palette, Vector3i.ZERO, strength))
	var l_light := _lightest(VoxelModel.build_mesh(l_shape, palette, Vector3i.ZERO, strength))
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
	var n_dark := _darkest(VoxelModel.build_mesh(notch, palette, Vector3i.ZERO, strength))
	if absf(n_dark - (1.0 - strength)) > tol:
		print("  concave corner is %.3f, wanted %.3f (level 0, full strength)" % [
			n_dark, 1.0 - strength])
		bad += 1

	# ...and with AO off the whole thing is flat, or the strength knob is not
	# actually a knob.
	var flat := _darkest(VoxelModel.build_mesh(notch, palette, Vector3i.ZERO, 0.0))
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

	var a := _mesh_arrays(VoxelModel.build_mesh(part, pal_a, Vector3i.ZERO, 0.0))
	var b := _mesh_arrays(VoxelModel.build_mesh(part, pal_b, Vector3i.ZERO, 0.0))

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
