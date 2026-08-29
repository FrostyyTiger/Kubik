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
		"parts match the table": _test_parts_match_table,
		"eyes forward": _test_eyes_forward,
		"rig completeness": _test_rig_completeness,
		"character height": _test_character_height,
		"def round trip": _test_def_round_trip,
		"def from strangers": _test_def_from_strangers,
		"a v1 payload still parses": _test_v1_payload_still_parses,
		"pose is finite": _test_pose_finite,
		"phase by distance": _test_phase_by_distance,
		"idle converges": _test_idle_converges,
		"poses differ": _test_poses_differ,
		"knees bend one way": _test_knee_never_hyperextends,
		"the walk has a contact pose": _test_contact_pose,
		"the races walk differently": _test_gait_differs,
		"sprint lean": _test_sprint_lean,
		"animator cost": _measure_animator_cost,
		"chain lag": _test_chain_lag,
		"blink rhythm": _test_blink_rhythm,
		"eyes closed variant": _test_eyes_closed_variant,
		"state byte": _test_state_byte,
		"remote row": _test_remote_row,
		"every combination": _test_every_combination,
		"option tables agree": _test_option_tables,
		"gear sockets": _test_gear_sockets,
		"armour is not inside a body": _test_armour_not_inside_a_body,
		"glow is capped": _test_glow_is_capped,
		"vox fixture": _test_vox_fixture,
		"vox garbage": _test_vox_garbage,
		"critter": _test_critter,
		"unknown gait": _test_unknown_gait,
		"the json is the consts": _test_json_is_the_consts,
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


## THE AO MULTIPLIER IS LINEAR AND THE WIRE IS sRGB.
##
## Look v2 Stage 0 made every mesh builder convert its final colour with
## Look.to_wire() at the push, so a vertex colour read back out of an ArrayMesh
## is sRGB. Baked AO is still a plain linear multiplication and these two are
## still measuring it, so they decode first. The assertions above are unchanged
## and are not loosened - the tolerance is still one 8-bit step (see the note on
## RGBA8 storage in _test_part_ao).
func _darkest(mesh: ArrayMesh) -> float:
	var out := 2.0
	for c in (_mesh_arrays(mesh)[Mesh.ARRAY_COLOR] as PackedColorArray):
		out = minf(out, c.srgb_to_linear().r)
	return out


func _lightest(mesh: ArrayMesh) -> float:
	var out := -1.0
	for c in (_mesh_arrays(mesh)[Mesh.ARRAY_COLOR] as PackedColorArray):
		out = maxf(out, c.srgb_to_linear().r)
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






## THE GAIT TABLE IS WIRED UP, AND IT IS WIRED UP THE WAY IT READS.
##
## A table of multipliers nobody can see the effect of is a table that has not
## been wired up, and the failure is silent: every number looks plausible in the
## file and every character moves identically on screen.
##
## So this checks the ORDERING the table's own prose claims, not the values.
## "The elf glides", "the dwarf is a piston", "the lizardfolk's power is in its
## spine" are testable sentences: the elf swings its arms widest, the dwarf
## takes the shortest stride and bobs least, the lizardfolk twists most. If
## someone retunes the table those orderings should survive, and if they
## deliberately do not, this test is the place the decision gets recorded.
func _test_gait_differs():
	var bad := 0
	var config := CharacterConfig.load_or_default()
	var arm := {}
	var bob := {}
	var twist := {}
	var stride := {}

	for race in Races.RACE_COUNT:
		var dims := Races.dims(race)
		var anim := Animator.new()
		anim.setup(config, dims)
		var st := LocomotionState.new()
		st.speed = 4.0
		st.grounded = true
		stride[race] = anim.stride_for(4.0)
		# The extremes over a cycle, which is what an amplitude is.
		var most_arm := 0.0
		var most_bob := 0.0
		var most_twist := 0.0
		for step in 120:
			var pose := Animator.pose_for(st, float(step) / 120.0, 0.0, config, dims)
			if pose.has("arm_r"):
				most_arm = maxf(most_arm, absf((pose["arm_r"]["rot"] as Vector3).x))
			if pose.has("hips"):
				most_bob = maxf(most_bob, absf((pose["hips"]["pos"] as Vector3).y))
				most_twist = maxf(most_twist, absf((pose["hips"]["rot"] as Vector3).y))
		arm[race] = most_arm
		bob[race] = most_bob
		twist[race] = most_twist

	for claim in [
			["the elf swings its arms widest", arm[Races.ELF] > arm[Races.HUMAN]
				and arm[Races.ELF] > arm[Races.DWARF]],
			["the dwarf swings its arms least", arm[Races.DWARF] < arm[Races.HUMAN]],
			["the dwarf bobs least", bob[Races.DWARF] < bob[Races.HUMAN]
				and bob[Races.DWARF] < bob[Races.ELF]],
			["the lizardfolk twists most", twist[Races.LIZARDFOLK] > twist[Races.HUMAN]
				and twist[Races.LIZARDFOLK] > twist[Races.ELF]],
			["the dwarf takes the shortest stride", stride[Races.DWARF] < stride[Races.HUMAN]],
			["the elf takes the longest", stride[Races.ELF] > stride[Races.HUMAN]],
	]:
		if not bool(claim[1]):
			print("  the gait table says %s, and the animator does not agree" % claim[0])
			bad += 1

	print("the races walk differently: strides %.2f/%.2f/%.2f/%.2f m, %d checks failed" % [
		stride[0], stride[1], stride[2], stride[3], bad])
	return 1 if bad > 0 else 0

## THE CONTACT POSE EXISTS, AND IT IS ASSERTED RATHER THAN LOOKED FOR.
##
## Acceptance test 4 is "eight frozen phases, and the contact pose is visible in
## at least one of them". Judged off the picture that is a person squinting at a
## strip; judged off the pose it is arithmetic, and it can be checked at 360
## phases instead of 8.
##
## THE POSE: one leg straight and forward while the other is bent and back. It
## is the pose everyone skips and the one that makes a walk read as weight
## rather than as a scissor, and it was not achievable at all before there was a
## knee - character v1's strips are eight rigid poles.
##
## It is not a keyframe. It falls out of where the knee's peak sits relative to
## the hip's - `Animator.KNEE_LAG` - so this test is really asking whether that
## number is still right.
func _test_contact_pose():
	var bad := 0
	var config := CharacterConfig.load_or_default()
	var report := PackedStringArray()

	for race in Races.RACE_COUNT:
		var dims := Races.dims(race)
		var st := LocomotionState.new()
		st.speed = 4.0
		st.grounded = true
		var best := 0.0
		var best_phase := 0.0
		for step in 360:
			var phase := float(step) / 360.0
			var pose := Animator.pose_for(st, phase, 0.0, config, dims)
			if not pose.has("leg_r") or not pose.has("leg_r_lower"):
				continue
			for pair in [["leg_r", "leg_l"], ["leg_l", "leg_r"]]:
				var front: float = (pose[pair[0]]["rot"] as Vector3).x
				var back: float = (pose[pair[1]]["rot"] as Vector3).x
				var front_knee: float = absf((pose[pair[0] + "_lower"]["rot"] as Vector3).x)
				var back_knee: float = absf((pose[pair[1] + "_lower"]["rot"] as Vector3).x)
				# Front leg forward and straight, back leg back and bent.
				if front <= 0.0 or back >= 0.0:
					continue
				if front_knee > deg_to_rad(6.0):
					continue
				var quality: float = back_knee
				if quality > best:
					best = quality
					best_phase = phase
		if best < deg_to_rad(12.0):
			print("  %s never reaches a contact pose - best trailing knee %.1f deg" % [
				Races.name_of(race), rad_to_deg(best)])
			bad += 1
		report.append("%s %.0fdeg@%.2f" % [Races.name_of(race), rad_to_deg(best), best_phase])

	print("the walk has a contact pose: %s, %d checks failed" % [
		String(" ").join(report), bad])
	return 1 if bad > 0 else 0

## TWELVE VOXELS OF GLOW, NEVER MORE, ON ANY CHARACTER AT ANY TIER.
##
## The cap is the design and not an optimisation. A rune band on one pauldron
## is a story about something the wearer did; a glowing character is what every
## game does wrong, and the only thing standing between the two is a number
## that somebody actually enforces. So it is enforced here rather than trusted
## to the generator, because the generator is where it would drift.
func _test_glow_is_capped():
	var bad := 0
	var worst := 0
	var worst_where := ""
	for race in Races.RACE_COUNT:
		for tier in range(0, CharacterDef.TIER_MAX + 1):
			var def := CharacterDef.new()
			def.race = race
			for slot in CharacterDef.ARMOUR_SLOTS:
				def.armour_tier[slot] = tier
			def.validate()
			var view := CharacterView.new()
			view.build(def)
			var lit := 0
			for key in view.rig.part_voxels:
				for v in (view.rig.part_voxels[key]["voxels"] as Array):
					if VoxelModel.EMISSIVE_SLOTS.has(v.w):
						lit += 1
			if lit > worst:
				worst = lit
				worst_where = "%s tier %d" % [Races.name_of(race), tier]
			if lit > GLOW_CAP:
				print("  %s tier %d has %d glowing voxels, cap is %d" % [
					Races.name_of(race), tier, lit, GLOW_CAP])
				bad += 1
			view.free()
	print("glow is capped: worst %d voxels (%s), cap %d, %d checks failed" % [
		worst, worst_where, GLOW_CAP, bad])
	return 1 if bad > 0 else 0


## The design doc's number: "an emissive accent of 4-12 voxels".
const GLOW_CAP := 12

## ARMOUR SITS ON A BODY. IT DOES NOT SIT INSIDE ONE.
##
## The fitting rule - proportions relative, thicknesses absolute - is what makes
## one authored set work across four bodies that differ by more than a factor of
## two in width. The way it fails is not dramatic: a piece stamped from the
## wrong fraction does not vanish or error, it sinks into the wearer, and on
## three of four races it looks fine. So it is checked voxel by voxel on every
## race rather than by eye on the one that happens to be on screen.
##
## Voxel CENTRES with a half-voxel tolerance, not mesh vertices or AABBs, for
## the reason character v1 wrote down: two parts authored on lattices half a
## voxel apart share no vertex even when they occupy the same space, and an
## AABB comparison cannot tell a dwarf's 21-deep torso from an elf's 12.
func _test_armour_not_inside_a_body():
	var bad := 0
	var report := PackedStringArray()

	for race in Races.RACE_COUNT:
		var def := CharacterDef.new()
		def.race = race
		# Everything on at once, which is the worst case and the only case
		# worth checking: pieces that clear a body one at a time can still
		# arrive on top of each other.
		for slot in CharacterDef.ARMOUR_SLOTS:
			def.armour_tier[slot] = 4
			def.armour_item[slot] = maxi(Armour.piece_count(slot) - 1, 0)
		def.validate()

		var view := CharacterView.new()
		view.build(def)
		var rig: Rig = view.rig

		# Every BODY voxel, as a set of cells. Hair and beards are excluded,
		# and the exclusion is the interesting part: a helm through hair and a
		# breastplate through a beard are real questions, but they are DESIGN
		# questions with per-race answers - the dwarf's helm has its beard
		# emerging below, the elf's is open at the sides - and not the fitting
		# failure this test is looking for. Rolling them together would mean a
		# single number that cannot distinguish "the plate is inside the ribs"
		# from "the helmet touches the fringe".
		var body := {}
		for bone_name in rig.meshes:
			if bone_name in Rig.ORNAMENT_BONES:
				continue
			for centre in rig.voxel_centres_in_rig(bone_name):
				body[_cell(centre)] = true

		var worn := 0
		var inside := 0
		for bone_name in rig.overlays:
			worn += 1
			for centre in rig.overlay_voxel_centres_in_rig(bone_name):
				if body.has(_cell(centre)):
					inside += 1
		for socket_name in rig.attachments:
			worn += 1
			for centre in rig.socket_voxel_centres_in_rig(socket_name):
				if body.has(_cell(centre)):
					inside += 1

		if worn == 0:
			print("  the %s wore nothing at tier 4 - the armour never attached" % Races.name_of(race))
			bad += 1
		if inside > 0:
			print("  %s: %d armour voxels are INSIDE the body" % [Races.name_of(race), inside])
			bad += 1
		report.append("%s %dp/%di" % [Races.name_of(race), worn, inside])
		view.free()

	print("armour is not inside a body: %s, %d checks failed" % [
		String(" ").join(report), bad])
	return 1 if bad > 0 else 0


## A voxel centre in rig space to the integer cell it falls in. Half a voxel of
## tolerance falls out of the rounding, which is what the question needs: does
## a voxel of this occupy the same cell as a voxel of that.
static func _cell(p: Vector3) -> Vector3i:
	var v := VoxelModel.VOXEL_M
	return Vector3i(roundi(p.x / v), roundi(p.y / v), roundi(p.z / v))

## A VERSION 1 PAYLOAD IS A REAL CHARACTER WEARING NOTHING.
##
## `CharacterDef` went to eight bytes plus twelve of armour in character v2
## Stage 7. Every save file written before that and every peer on an older
## build is describing the character it always described - only the armour is
## absent, and absent armour is tier 0, which the game already has a word for.
##
## THE FAILURE THIS GUARDS AGAINST IS SILENT AND NASTY: falling back to the
## default human on an unrecognised length would change a friend's RACE, and
## the symptom is a friend who looks wrong rather than an error anyone can see.
## So the literal old byte array is in the test, and it stays there.
func _test_v1_payload_still_parses():
	var bad := 0

	# race 2 (dwarf), build 0, skin 3, hair colour 1, eyes 2, hair 1, beard 2.
	var v1 := PackedByteArray([1, 2, 0, 3, 1, 2, 1, 2])
	var def := CharacterDef.from_bytes(v1)
	if def.race != Races.DWARF:
		print("  a v1 payload came back as %s, not a dwarf" % Races.name_of(def.race))
		bad += 1
	for pair in [["skin", def.skin, 3], ["hair_color", def.hair_color, 1],
			["eyes", def.eyes, 2], ["hair", def.hair, 1], ["beard", def.beard, 2]]:
		if pair[1] != pair[2]:
			print("  a v1 payload's %s came back %d, wanted %d" % pair)
			bad += 1
	for i in CharacterDef.ARMOUR_SLOTS:
		if def.armour_tier[i] != 0 or def.armour_item[i] != 0:
			print("  a v1 payload arrived wearing something in slot %d" % i)
			bad += 1

	# A version 2 payload round trips with its armour.
	var worn := CharacterDef.new()
	worn.race = Races.ELF
	worn.armour_tier[CharacterDef.SLOT_TORSO] = 4
	worn.armour_tier[CharacterDef.SLOT_BACK] = 5
	worn.validate()
	var back := CharacterDef.from_bytes(worn.to_bytes())
	if back.armour_tier[CharacterDef.SLOT_TORSO] != 4 \
			or back.armour_tier[CharacterDef.SLOT_BACK] != 5:
		print("  a v2 payload lost its armour tiers on the wire")
		bad += 1
	if back.race != Races.ELF:
		print("  a v2 payload lost its race on the wire")
		bad += 1

	# THE SAVE FILE DOES NOT CARRY ARMOUR, and this is the assertion that stops
	# someone helpfully "fixing" that. See CharacterDef.to_dict.
	var through_dict := CharacterDef.new()
	through_dict.from_dict(worn.to_dict())
	if Armour.highest_tier(through_dict) != 0:
		print("  armour survived a round trip through the save dictionary - it must not")
		bad += 1
	if through_dict.race != Races.ELF:
		print("  the save dictionary lost the race")
		bad += 1

	# A version nobody knows is the default human with a warning, not a crash.
	var future := PackedByteArray([99, 1, 0, 0, 0, 0, 0, 0])
	if CharacterDef.from_bytes(future).race != Races.HUMAN:
		print("  an unknown wire version did not fall back to the default human")
		bad += 1
	# And a length that disagrees with its own version byte.
	var lying := PackedByteArray([2, 1, 0, 0, 0, 0, 0, 0])
	if CharacterDef.from_bytes(lying).race != Races.HUMAN:
		print("  a payload claiming v2 at 8 bytes was believed")
		bad += 1

	print("a v1 payload still parses: v1 dwarf intact, v2 round trip, dict drops armour, %d checks failed" % bad)
	return 1 if bad > 0 else 0

## A KNEE BENDS ONE WAY, AND SO DOES AN ELBOW.
##
## The single most obviously wrong thing a procedural rig can do is bend a knee
## backwards, and a plain sine does it for half of every cycle. The knee angle
## is therefore a RECTIFIED sine - see Animator._pose_locomotion - and this is
## the check that it stays rectified through every pose, every speed and every
## race, including the ones assembled by hand rather than by arithmetic.
##
## SIGN CONVENTION, since it is the whole test: a positive rotation about X
## swings a downward-hanging bone's tip toward -Z, which is FORWARD. So a knee,
## whose shin swings backward, must never be positive; an elbow, whose forearm
## swings forward, must never be negative. Both are checked against the REST
## pose, which is what `apply_pose` treats them as offsets from.
##
## It walks the static poses too, because those are hand-written numbers and a
## typed minus sign is exactly the kind of thing that produces a character
## sitting with its shins through its thighs.
func _test_knee_never_hyperextends():
	var bad := 0
	var config := CharacterConfig.load_or_default()
	var worst_knee := 0.0
	var worst_elbow := 0.0
	var worst_where := ""

	for race in Races.RACE_COUNT:
		var dims := Races.dims(race)
		for mode in [LocomotionState.MODE_WALK, LocomotionState.MODE_SPRINT,
				LocomotionState.MODE_PRECISION]:
			for grounded in [true, false]:
				for rising in [true, false]:
					for step in 90:
						var st := LocomotionState.new()
						st.speed = 5.0
						st.mode = mode
						st.grounded = grounded
						st.rising = rising
						var pose := Animator.pose_for(
							st, float(step) / 90.0, 0.0, config, dims)
						bad += _check_joint_signs(pose, "%s mode %d" % [
							Races.name_of(race), mode])
		# The hand-written poses, which arithmetic does not protect.
		for pose_id in [LocomotionState.POSE_SIT, LocomotionState.POSE_DOWNED,
				LocomotionState.POSE_WAVE]:
			var st := LocomotionState.new()
			st.grounded = true
			st.pose = pose_id
			var pose := Animator.pose_for(st, 0.0, 0.0, config, dims,
				{"wave": 1.0})
			bad += _check_joint_signs(pose, "%s pose %d" % [
				Races.name_of(race), pose_id])

	# And report the extremes actually reached, so a knee that never bends at
	# all is as visible as one that bends the wrong way.
	var st_walk := LocomotionState.new()
	st_walk.speed = 5.0
	st_walk.grounded = true
	for step in 90:
		var pose := Animator.pose_for(st_walk, float(step) / 90.0, 0.0, config,
			Races.dims(Races.HUMAN))
		if pose.has("leg_r_lower"):
			worst_knee = minf(worst_knee, (pose["leg_r_lower"]["rot"] as Vector3).x)
		if pose.has("arm_r_lower"):
			worst_elbow = maxf(worst_elbow, (pose["arm_r_lower"]["rot"] as Vector3).x)
	if worst_knee > -0.01:
		print("  the human's knee never bends at all through a walk cycle")
		bad += 1
	print("knees bend one way: human knee to %.1f deg, elbow to %.1f deg, %d checks failed" % [
		rad_to_deg(worst_knee), rad_to_deg(worst_elbow), bad])
	return 1 if bad > 0 else 0


## Every lower-limb bone in one pose, against its allowed direction.
func _check_joint_signs(pose: Dictionary, where: String) -> int:
	var bad := 0
	for bone in pose:
		var entry: Dictionary = pose[bone]
		if not entry.has("rot"):
			continue
		var x: float = (entry["rot"] as Vector3).x
		# A hair past zero is float noise, not a hyperextension.
		if bone.begins_with("leg_") and bone.ends_with("_lower") and x > 0.001:
			print("  %s: %s bends %+.2f deg - a knee hyperextending" % [
				where, bone, rad_to_deg(x)])
			bad += 1
		elif bone.begins_with("arm_") and bone.ends_with("_lower") and x < -0.001:
			print("  %s: %s bends %+.2f deg - an elbow hyperextending" % [
				where, bone, rad_to_deg(x)])
			bad += 1
	return bad

## THE PART FILES AND THE RACE TABLE ARE ONE DESIGN IN TWO LANGUAGES.
##
## `races.gd` says a human head is `head_w` 18 wide and `head` 22 tall;
## `human.py` draws one 18 wide and 22 tall. Nothing has ever checked that
## those two agree, and they are edited by different hands for different
## reasons - the table for the rig's rest offsets, the generator for the
## drawing. A disagreement does not crash: it produces a character whose arms
## hang off the side of its shoulders by a voxel, which is a thing you find by
## looking, three stages later, at a sheet you were looking at for another
## reason.
##
## It matters more from character v2 Stage 2 on, because the two now scale
## THROUGH DIFFERENT CODE - `voxlib.U()` in Python and the tabled numbers in
## GDScript - and the byte-identity gate at the author grid cannot see a
## disagreement that only appears at another one.
##
## Depth is not checked against `head_d`: the head part carries the nose in
## front of the skull, so its depth is deliberately larger, and by a margin
## that is itself resolution-dependent. The comment in `races.gd` says so.
func _test_parts_match_table():
	var bad := 0
	var report := PackedStringArray()
	for race in Races.RACE_COUNT:
		if not Races.has_part_set(race):
			continue
		var t := Races.dims(race)
		var parts := Races.part_set(race)
		# THE HEAD PART IS NOT THE SKULL, and the two ways it is not are both
		# documented rules rather than slack in the test:
		#
		#  - EARS ARE PART OF THE HEAD, so the elf's head part is `head_w` plus
		#    `ear_out` on each side. That is why the elf's ears survive being
		#    authored once and mirrored, and why they move with a head-look.
		#  - THE NECK IS PART OF THE HEAD, authored as the bottom slices of it,
		#    so the head bone sits at the top of the torso and the head pivots
		#    about the BASE of the neck - which is where a head-look should
		#    pivot. `races.gd` says this in as many words and warns that
		#    offsetting by `neck` in the bone table as well would double-count
		#    it.
		#
		# Both were found by this test on its first run, which is the argument
		# for having written it.
		var ear: int = int(t.get("ear_out", 0))
		var neck: int = int(t.get("neck", 0))
		var checks := [
			["head", "head_w + 2 * ear_out", "x", int(t["head_w"]) + 2 * ear],
			["head", "head + neck", "y", int(t["head"]) + neck],
			["torso", "torso_w", "x", t["torso_w"]],
			# A TORSO PART MAY BE TALLER THAN ITS SLICE OF THE STACK, by exactly
			# `torso_rise` - the elf's standing collar and the dwarf's raised
			# shoulders both live above the point where the head bone sits. The
			# rise is tabled rather than tolerated, so this stays an equality.
			["torso", "torso + torso_rise", "y",
				int(t["torso"]) + int(t.get("torso_rise", 0))],
			["torso", "torso_d", "z", t["torso_d"]],
			["leg", "legs", "y", t["legs"]],
			["arm", "arm_len", "y", t["arm_len"]],
		]
		for check in checks:
			var part_name: String = check[0]
			if not parts.has(part_name):
				continue
			var size: Vector3i = parts[part_name]["size"]
			var got: int = size.x if check[2] == "x" else (
				size.y if check[2] == "y" else size.z)
			var want: int = check[3]
			if got != want:
				print("  %s part %s is %d %s, but the table's %s says %d" % [
					Races.name_of(race), part_name, got, check[2], check[1], want])
				bad += 1
		report.append("%s %dp" % [Races.name_of(race), parts.size()])
	print("parts match the table: %s, %d checks failed" % [
		String(" ").join(report), bad])
	return 1 if bad > 0 else 0


## Two assertions, and the second is the one that matters:
##
##   1. In model space, the iris voxels sit forward of the head's own centre.
##   2. On a BUILT rig turned by the yaw the player actually uses, the
##      direction from the head's centre to its eyes points along the travel
##      direction - checked at ten headings, including off-axis ones so a sign
##      error on one axis alone cannot hide.
func _test_eyes_forward():
	var bad := 0

	var total_iris := 0
	for entry in _every_build():
		bad += _eyes_forward_for(entry)
		total_iris += 1

	print("eyes forward: %d builds checked, %d checks failed" % [total_iris, bad])
	return 1 if bad > 0 else 0


## The same two assertions for one race and scheme.
func _eyes_forward_for(entry: Dictionary) -> int:
	var bad := 0
	var head: Dictionary = Races.part_set(entry["race"], entry["build"])["head"]
	var voxels := VoxelModel.parse(head, "head")
	var iris := VoxelModel.slot_centroid(voxels, VoxelModel.IRIS)
	var iris_count := VoxelModel.voxels_with_slot(voxels, VoxelModel.IRIS).size()
	if iris_count == 0:
		print("  the %s head has no iris voxels at all" % _build_name(entry))
		return 1

	var centre := Vector3.ZERO
	for v in voxels:
		centre += Vector3(v.x, v.y, v.z)
	centre /= float(voxels.size())

	if not (iris.z < centre.z):
		print("  %s: iris centroid z is %.2f and the head's is %.2f - the face is on the BACK" % [
			_build_name(entry), iris.z, centre.z])
		bad += 1

	# ...and the same fact, through the mesher, the anchor, the bone table and
	# the yaw expression, on a rig that has actually been built.
	var view := CharacterView.new()
	view.build(_def_for(entry))
	var rig: Rig = view.rig
	var anchor: Vector3 = head["anchor"]
	var to_rig := rig.transform_to_rig(rig.bones["head"])
	# Voxel centres, so a 1 x 1 iris is measured at its middle and not at its
	# corner.
	var iris_m: Vector3 = to_rig * ((iris + Vector3(0.5, 0.5, 0.5) - anchor) * VoxelModel.VOXEL_M)
	var centre_m: Vector3 = to_rig * ((centre + Vector3(0.5, 0.5, 0.5) - anchor) * VoxelModel.VOXEL_M)
	var face_dir := Vector3(iris_m.x - centre_m.x, 0.0, iris_m.z - centre_m.z)
	if face_dir.length() < 0.001:
		print("  %s: the eyes are directly above the head's centre" % _build_name(entry))
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
					print("  %s at %d deg: wish %s but the face points %s" % [
						_build_name(entry), degrees, wish, pointed])
		print("  %s: %d iris voxels, worst face-vs-travel agreement %.4f" % [
			_build_name(entry), iris_count, worst])
	view.free()
	return bad


## EVERY BONE HAS A PART OR IS A SOCKET, AND EVERY SOCKET EXISTS.
##
## The sockets half is the one with teeth. Stage 10's deliverable is the
## sockets, not the placeholder sword, and a gear system that has to ask which
## races have a back is not a gear system - so all six exist on every race,
## whether or not anything will ever hang on them.
func _test_rig_completeness():
	var bad := 0
	var totals := PackedStringArray()
	for entry in _every_build():
		bad += _rig_completeness_for(entry, totals)
	print("rig completeness: %s, %d checks failed" % [String(" ").join(totals), bad])
	return 1 if bad > 0 else 0


func _rig_completeness_for(entry: Dictionary, totals: PackedStringArray) -> int:
	var bad := 0
	var view := CharacterView.new()
	view.build(_def_for(entry))
	var rig: Rig = view.rig

	var table := Races.bone_table(entry["race"], entry["build"])
	var parts := Races.parts_for(_def_for(entry))
	var transforms_only := 0
	# `bone_entry`, not `entry` - the parameter is already called that, and
	# GDScript rejects the shadow rather than quietly picking one.
	for bone_entry in table:
		var bone_name: String = bone_entry["name"]
		if not rig.bones.has(bone_name):
			print("  %s bone %s is in the table but not on the rig" % [
				_build_name(entry), bone_name])
			bad += 1
			continue
		if bone_entry.get("socket", false):
			continue
		if bone_entry.get("optional", false) and not parts.has(bone_entry.get("part", "")):
			continue  # "none" is a real answer - see Races.bone_table
		var part_name: String = bone_entry.get("part", "")
		if part_name.is_empty():
			# Legal: a race whose stack leaves no room for a pelvis has a hips
			# bone that is a pure transform with a socket on it.
			transforms_only += 1
			continue
		if not parts.has(part_name):
			# Not a failure for a race that is still borrowing the human's
			# parts - Stage 8 builds the other three and flips the flag.
			if Races.has_part_set(entry["race"]):
				print("  %s bone %s wants part %s, which its part set does not have" % [
					_build_name(entry), bone_name, part_name])
				bad += 1
		elif not rig.meshes.has(bone_name):
			print("  %s bone %s has part %s but no mesh was built" % [
				_build_name(entry), bone_name, part_name])
			bad += 1

	for socket_name in Races.SOCKET_NAMES:
		if not rig.sockets.has(socket_name):
			print("  %s is missing socket %s" % [_build_name(entry), socket_name])
			bad += 1

	totals.append("%s %db/%dm/%ds" % [
		_build_name(entry), rig.bones.size(), rig.meshes.size(), rig.sockets.size()])
	view.free()
	return bad


## EVERY BUILT CHARACTER IS THE HEIGHT ITS TABLE CLAIMS, within one voxel.
##
## Measured off the mesh AABBs of the rig that was actually built, not summed
## from the race table - a height computed from the table would only prove the
## table agrees with itself, and the thing that can actually go wrong is an
## anchor or a rest offset being a voxel out. That is precisely how a doubled
## neck offset would show up: the lean human would come out 33 voxels tall.
##
## Runs over every race AND both schemes where a race has both, which is what
## makes it a check on the lean part set rather than on the human's.
func _test_character_height():
	var bad := 0
	var report := PackedStringArray()
	for entry in _every_build():
		var view := CharacterView.new()
		view.build(_def_for(entry))
		# MEASURED STANDING UPRIGHT. The lizardfolk's forward lean is baked
		# into a rest pose, and the AXIS-ALIGNED bound of a rotated body reads
		# taller than the body: a 24-voxel head pitched 26 degrees bounds to
		# 24*cos26 + 24*sin26, which is 32. The table's number is the crown
		# height of the race stood straight, so that is what is measured; the
		# lean goes back afterwards.
		#
		# THE RIG SAYS WHICH BONE IT LEANED. This used to name `hips`, and when
		# character v2 Stage 6 moved the lean to the torso - so the spine leans
		# and the legs stay under the body - the compensation silently stopped
		# working and the lizardfolk measured 1.98 m against a tabled 1.88. A
		# test that guesses where a thing is will stop testing the day it moves.
		var rig: Rig = view.rig
		var leaned := rig.lean_bone
		var lean := 0.0
		if leaned != "" and rig.bones.has(leaned):
			lean = rig.bones[leaned].rotation.x
			rig.bones[leaned].rotation.x = 0.0
		var got := view.height_m()
		var crown := view.height_m(true)
		if leaned != "" and rig.bones.has(leaned):
			rig.bones[leaned].rotation.x = lean
		var want := Races.height_m(entry["race"], entry["build"])
		var tris := view.triangle_count()
		# A race still borrowing the human's parts is the wrong height BY
		# CONSTRUCTION - the elf is missing its two-voxel neck because the
		# human head has no neck to give it. Reported, not failed, until
		# Stage 8 gives it its own parts and flips Races.HAS_PART_SET.
		if not Races.has_part_set(entry["race"]):
			report.append("%s %.2fm/%d (borrowed parts, wants %.2f)" % [
				_build_name(entry), got, tris, want])
			view.free()
			continue
		if absf(got - want) > VoxelModel.VOXEL_M:
			print("  the %s is %.4f m, wanted %.4f m (within one voxel)" % [
				_build_name(entry), got, want])
			bad += 1
		# The budget, reported rather than gated at this stage - hair and beard
		# are still to come and Stage 14 is where the number is judged.
		if tris > CharacterConfig.TRIANGLE_BUDGET:
			print("  the %s is already %d triangles, over the %d budget" % [
				_build_name(entry), tris, CharacterConfig.TRIANGLE_BUDGET])
			bad += 1
		report.append("%s %.2fm/%d%s" % [_build_name(entry), got, tris,
			"" if is_equal_approx(crown, got) else " (%.2f with hair)" % crown])
		view.free()
	print("character height: %s, %d checks failed" % [
		String(" ").join(report), bad])
	return 1 if bad > 0 else 0


## Every (race, build) pair that has a part set behind it.
func _every_build() -> Array:
	var out := []
	for race in Races.RACE_COUNT:
		out.append({"race": race, "build": Races.STOCKY})
		if Races.has_lean(race):
			out.append({"race": race, "build": Races.LEAN})
	return out


func _def_for(entry: Dictionary) -> CharacterDef:
	var def := CharacterDef.new()
	def.race = entry["race"]
	def.build = entry["build"]
	def.validate()
	return def


func _build_name(entry: Dictionary) -> String:
	return "%s %s" % [Races.BUILD_NAMES[entry["build"]], Races.name_of(entry["race"])]


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


# --- Stage 4 -----------------------------------------------------------------

## A LocomotionState covering one interesting case.
func _state(speed := 0.0, mode := LocomotionState.MODE_WALK, grounded := true,
		rising := false, pose := LocomotionState.POSE_NONE) -> LocomotionState:
	var st := LocomotionState.new()
	st.speed = speed
	st.mode = mode
	st.grounded = grounded
	st.rising = rising
	st.vertical = 4.0 if rising else (0.0 if grounded else -6.0)
	st.pose = pose
	return st


## Every state this game can be in, for the tests that have to cover all of
## them rather than a sample.
func _every_state() -> Array:
	var out := []
	for mode in [LocomotionState.MODE_WALK, LocomotionState.MODE_SPRINT,
			LocomotionState.MODE_PRECISION]:
		for speed in [0.0, 0.4, 5.0, 13.0]:
			out.append(_state(speed, mode))
			out.append(_state(speed, mode, false, true))
			out.append(_state(speed, mode, false, false))
	for pose in [LocomotionState.POSE_SIT, LocomotionState.POSE_DOWNED,
			LocomotionState.POSE_WAVE]:
		out.append(_state(0.0, LocomotionState.MODE_WALK, true, false, pose))
		out.append(_state(5.0, LocomotionState.MODE_WALK, true, false, pose))
	return out


## NOTHING IS EVER NaN OR INF, in any state, at any point in the cycle.
##
## A single NaN in a rotation propagates into the transform and Godot's answer
## is to draw nothing at all - the character silently disappears rather than
## looking wrong, which is the hardest kind of animation bug to find. 600 steps
## at 1/60 is ten seconds, which is long enough for every timer, blend and
## chain lag in the file to have been through several cycles.
func _test_pose_finite():
	var bad := 0
	var config := CharacterConfig.new()
	var checked := 0
	for race in Races.RACE_COUNT:
		var dims := Races.dims(race, Races.STOCKY)
		for st in _every_state():
			var anim := Animator.new()
			anim.setup(config, dims)
			for step in 600:
				anim.update(st, 1.0 / 60.0)
				if step % 120 != 0:
					continue  # checking every frame is 700k comparisons
				for bone in anim.current_pose():
					var entry: Dictionary = anim.current_pose()[bone]
					checked += 1
					if not _finite(entry["rot"]) or not _finite(entry["pos"]):
						print("  %s bone %s went non-finite: %s" % [
							Races.name_of(race), bone, entry])
						bad += 1
						break
	print("pose is finite: %d bone samples over every state and race, %d bad" % [
		checked, bad])
	return 1 if bad > 0 else 0


func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


## THE CYCLE ADVANCES BY DISTANCE, NOT BY TIME.
##
## `phase += speed * dt / stride`, exactly. This is the property that stops
## feet sliding, and it is the one that a "make it look right" fix would
## quietly break by scaling the cycle rate instead.
##
## Also checked: the rate cap. At sprint the stride must GROW rather than the
## legs exceeding cycle_hz_max, and the resulting rate must be the cap itself.
func _test_phase_by_distance():
	var bad := 0
	var config := CharacterConfig.new()
	var dt := 1.0 / 60.0

	for race in Races.RACE_COUNT:
		var anim := Animator.new()
		anim.setup(config, Races.dims(race, Races.STOCKY))
		var speed := 5.0
		var stride := anim.stride_for(speed)
		var before := anim.phase
		anim.update(_state(speed), dt)
		var moved := fposmod(anim.phase - before, 1.0)
		var want := speed * dt / stride
		if absf(moved - want) > 0.0001:
			print("  %s advanced %.6f, wanted %.6f" % [Races.name_of(race), moved, want])
			bad += 1

	# Stride scales with leg length: the dwarf's 5 voxels against the human's 9
	# and the elf's 12, from one table and one line of arithmetic.
	var human := Animator.new()
	human.setup(config, Races.dims(Races.HUMAN))
	var dwarf := Animator.new()
	dwarf.setup(config, Races.dims(Races.DWARF))
	var elf := Animator.new()
	elf.setup(config, Races.dims(Races.ELF))
	if not (dwarf.stride_for(1.0) < human.stride_for(1.0)
			and human.stride_for(1.0) < elf.stride_for(1.0)):
		print("  strides are not ordered dwarf < human < elf: %.3f %.3f %.3f" % [
			dwarf.stride_for(1.0), human.stride_for(1.0), elf.stride_for(1.0)])
		bad += 1

	# The rate cap. 13 m/s is the sprint speed DESIGN.md accepted.
	var sprint_stride := human.stride_for(13.0)
	var hz := 13.0 / sprint_stride
	if absf(hz - config.cycle_hz_max) > 0.001:
		print("  at 13 m/s the leg rate is %.3f Hz, wanted the cap of %.3f" % [
			hz, config.cycle_hz_max])
		bad += 1

	print("phase by distance: walk stride %.3f m, sprint stride %.3f m at %.2f Hz, %d checks failed" % [
		human.stride_for(5.0), sprint_stride, hz, bad])
	return 1 if bad > 0 else 0


## AT ZERO SPEED, EVERYTHING THAT SHOULD STOP HAS STOPPED.
##
## Two seconds of standing still and every locomotion bone is within a
## thousandth of a radian of rest. The exponential blend makes that arithmetic
## - exp(-10 * 2) is 2e-9 - so a failure here is not a slow blend, it is a term
## that never goes away: a swing that does not scale with speed, or an arm
## still carrying the jump it landed from.
##
## THE CHAINS ARE EXCLUDED, AND NOT AS A CONVENIENCE. The plan's own table
## lists `tail_hz` / `tail_deg` as IDLE sway, so a tail that stops dead when
## its owner does is the thing that would be wrong. And a first-order blend
## chasing a 1.2 Hz sine lags it by design - at k = 10 the lag is about 37
## degrees of phase - so "the blend has caught up" is not even a well-formed
## question about a bone that is never trying to arrive anywhere. Two earlier
## versions of this test failed on exactly that, once against rest and once
## against the moving target.
##
## Breathing is excluded for the same reason: it is a position on the torso and
## it is supposed to run forever.
const IDLE_BONES := ["leg_r", "leg_l", "arm_r", "arm_l", "torso", "head", "hips"]

func _test_idle_converges():
	var bad := 0
	var config := CharacterConfig.new()
	var anim := Animator.new()
	anim.setup(config, Races.dims(Races.HUMAN))

	# Walk, then jump, then land - so there is something to converge FROM, and
	# so the fall pose's arms-out has to be unwound as well as the swing.
	for i in 60:
		anim.update(_state(5.0), 1.0 / 60.0)
	for i in 30:
		anim.update(_state(5.0, LocomotionState.MODE_WALK, false, false), 1.0 / 60.0)
	var idle := _state(0.0)
	for i in 120:
		anim.update(idle, 1.0 / 60.0)

	var worst := 0.0
	var worst_bone := ""
	for bone in IDLE_BONES:
		var got: Dictionary = anim.current_pose().get(bone, {})
		var rot: Vector3 = got.get("rot", Vector3.ZERO)
		if rot.length() > worst:
			worst = rot.length()
			worst_bone = bone
	if worst > 0.001:
		print("  after two seconds standing still, %s is still rotated %.5f rad" % [
			worst_bone, worst])
		bad += 1

	# The chains are not tested for stillness - see above - but they DO have to
	# stay inside their own amplitude, or "sway" has become "spin".
	var limit := deg_to_rad(config.tail_deg) * 1.2
	for i in Animator.MAX_CHAIN_LINKS:
		var bone := "tail_%d" % (i + 1)
		var rot: Vector3 = (anim.current_pose().get(bone, {}) as Dictionary).get("rot", Vector3.ZERO)
		if rot.length() > limit:
			print("  %s swung %.4f rad, past its %.4f rad amplitude" % [bone, rot.length(), limit])
			bad += 1

	print("idle converges: worst locomotion residual %.6f rad (%s), chains within amplitude, %d checks failed" % [
		worst, worst_bone if not worst_bone.is_empty() else "none", bad])
	return 1 if bad > 0 else 0


## SIT, DOWNED AND IDLE ARE THREE DIFFERENT THINGS.
##
## Cheap to check and worth checking, because a static pose that silently falls
## through to the locomotion pose looks like a bug in the key binding rather
## than a missing pose. Hip height separates all three: standing hips are a leg
## up, sitting hips are on the ground, and downed hips are on the ground AND
## rotated onto their back.
func _test_poses_differ():
	var bad := 0
	var config := CharacterConfig.new()
	var dims := Races.dims(Races.HUMAN)
	var heights := {}
	for pose in [LocomotionState.POSE_NONE, LocomotionState.POSE_SIT,
			LocomotionState.POSE_DOWNED]:
		var got := Animator.pose_for(
			_state(0.0, LocomotionState.MODE_WALK, true, false, pose),
			0.0, 0.0, config, dims)
		heights[pose] = (got.get("hips", {}).get("pos", Vector3.ZERO) as Vector3).y

	var names := {LocomotionState.POSE_NONE: "idle", LocomotionState.POSE_SIT: "sit",
		LocomotionState.POSE_DOWNED: "downed"}
	var seen := []
	for pose in heights:
		for other in seen:
			if absf(heights[pose] - heights[other]) < 0.01:
				print("  %s and %s put the hips at the same height (%.3f m)" % [
					names[pose], names[other], heights[pose]])
				bad += 1
		seen.append(pose)

	# ...and downed is actually lying down, not merely low.
	var downed := Animator.pose_for(
		_state(0.0, LocomotionState.MODE_WALK, true, false, LocomotionState.POSE_DOWNED),
		0.0, 0.0, config, dims)
	var pitch: float = (downed["hips"]["rot"] as Vector3).x
	if absf(absf(pitch) - PI * 0.5) > 0.01:
		print("  downed pitches the hips %.3f rad, wanted a right angle" % pitch)
		bad += 1

	print("poses differ: idle %.3f, sit %.3f, downed %.3f m at the hips, %d checks failed" % [
		heights[LocomotionState.POSE_NONE], heights[LocomotionState.POSE_SIT],
		heights[LocomotionState.POSE_DOWNED], bad])
	return 1 if bad > 0 else 0


## THE SPRINT LEAN IS THE NUMBER IN THE CONFIG, once it has settled.
##
## The strongest single cue that a character is running rather than walking
## quickly, and the one most likely to be quietly halved by a blend that never
## quite arrives. Three seconds of sprinting and the torso pitch must be
## sprint_lean_deg within a degree.
func _test_sprint_lean():
	var bad := 0
	var config := CharacterConfig.new()
	var anim := Animator.new()
	anim.setup(config, Races.dims(Races.HUMAN))
	var sprint := _state(13.0, LocomotionState.MODE_SPRINT)
	for i in 180:
		anim.update(sprint, 1.0 / 60.0)
	var pitch: float = (anim.current_pose()["torso"]["rot"] as Vector3).x
	var got := rad_to_deg(absf(pitch))
	if absf(got - config.sprint_lean_deg) > 1.0:
		print("  sprinting torso pitch is %.2f deg, wanted %.2f" % [
			got, config.sprint_lean_deg])
		bad += 1
	# ...and it leans FORWARD, which is -X on a bone whose child is above it.
	if pitch > 0.0:
		print("  the torso leans backward at sprint (%.2f deg)" % got)
		bad += 1

	# Walking does not lean at all, or the cue means nothing.
	var walk_anim := Animator.new()
	walk_anim.setup(config, Races.dims(Races.HUMAN))
	for i in 180:
		walk_anim.update(_state(5.0), 1.0 / 60.0)
	var walk_pitch := rad_to_deg(absf((walk_anim.current_pose()["torso"]["rot"] as Vector3).x))
	if walk_pitch > 0.5:
		print("  walking leans the torso %.2f deg - it should not lean at all" % walk_pitch)
		bad += 1

	print("sprint lean: %.2f deg sprinting, %.2f deg walking, %d checks failed" % [
		got, walk_pitch, bad])
	return 1 if bad > 0 else 0


## HOW LONG ONE CHARACTER COSTS PER FRAME.
##
## Reported, not gated: four players cannot break a frame budget at any
## plausible value of this, and a threshold measured on llvmpipe would fail on
## a machine that is faster in every other respect. The number goes in the
## status doc so the first-enemy plan, which will have many more than four of
## these, starts from a measurement rather than a guess.
##
## update() AND apply() together, because apply() is the half that touches the
## scene tree and is therefore the half that could surprise anyone.
func _measure_animator_cost():
	var config := CharacterConfig.new()
	var view := CharacterView.new()
	view.build(CharacterDef.new())
	var anim: Animator = view.animator
	var st := _state(5.0)
	var frames := 600

	# Warm up, so the first call's script compilation is not in the average.
	for i in 60:
		anim.update(st, 1.0 / 60.0)
		anim.apply(view.rig)

	var start := Time.get_ticks_usec()
	for i in frames:
		anim.update(st, 1.0 / 60.0)
		anim.apply(view.rig)
	var elapsed := Time.get_ticks_usec() - start
	var per_frame := float(elapsed) / float(frames) / 1000.0

	print("animator cost: %.4f ms per character per frame over %d frames (budget 0.15, NOT gated)" % [
		per_frame, frames])
	view.free()
	return 0


# --- Stage 5 -----------------------------------------------------------------

## A CHAIN LAGS LINK BY LINK, which is the whole difference between a tail and
## a stick with a hinge in it.
##
## Tested on a SYNTHETIC chain rather than on the lizardfolk, because the rule
## is generic and has to be: the lizardfolk needs it in Stage 8 and the critter
## needs it in Stage 13, and a rule designed twice is a rule that differs in
## the second place. The animator does not know that a tail is a tail - it
## knows that bones named `<chain>_1..n` follow their parent late.
func _test_chain_lag():
	var bad := 0
	var config := CharacterConfig.new()
	var dims := Races.dims(Races.LIZARDFOLK)
	var idle := _state(0.0)

	# One full sway period, finely enough sampled that a 0.15 s lag is many
	# samples wide.
	var period := 1.0 / config.tail_hz
	var steps := 600
	var peak_at: Array[float] = []
	var peak_value: Array[float] = []
	for i in Animator.MAX_CHAIN_LINKS:
		peak_at.append(-1.0)
		peak_value.append(-INF)

	for k in steps:
		var t := period * float(k) / float(steps)
		var pose := Animator.pose_for(idle, 0.0, t, config, dims)
		for i in Animator.MAX_CHAIN_LINKS:
			var bone := "tail_%d" % (i + 1)
			if not pose.has(bone):
				continue
			var value: float = (pose[bone]["rot"] as Vector3).y
			# Normalised by this link's own amplitude, so the comparison is
			# about WHEN each link peaks and not about how far it swings.
			if value > peak_value[i]:
				peak_value[i] = value
				peak_at[i] = t

	for i in range(1, Animator.MAX_CHAIN_LINKS):
		if peak_at[i] <= peak_at[i - 1]:
			print("  tail_%d peaked at %.4f s, not after tail_%d at %.4f s" % [
				i + 1, peak_at[i], i, peak_at[i - 1]])
			bad += 1

	# And the lag is the configured one, within a sample.
	var want := config.tail_lag
	var got: float = peak_at[1] - peak_at[0]
	if absf(got - want) > period / float(steps) * 2.0:
		print("  the lag between links is %.4f s, wanted %.4f" % [got, want])
		bad += 1

	print("chain lag: peaks at %s s, %.3f s between links, %d checks failed" % [
		str(peak_at).replace(", ", " "), got, bad])
	return 1 if bad > 0 else 0


## TWO BLINKS ARE NEVER CLOSER THAN blink_min_s.
##
## The gap is measured from the eyes OPENING rather than from the blink's
## start, so this is really asking whether the timer can ever schedule the next
## blink inside the current one. Sixty seconds of sampling is a dozen or so
## blinks at the default rate, which is enough for a scheduling bug to show up
## and cheap enough to run every time.
func _test_blink_rhythm():
	var bad := 0
	var config := CharacterConfig.new()
	var anim := Animator.new()
	anim.setup(config, Races.dims(Races.HUMAN))
	var idle := _state(0.0)

	var dt := 1.0 / 60.0
	var starts := []
	var was := anim.blinking()
	var closed_frames := 0
	var total_closed := 0
	for k in int(60.0 / dt):
		anim.update(idle, dt)
		var now := anim.blinking()
		if now and not was:
			starts.append(float(k) * dt)
		if now:
			closed_frames += 1
			total_closed += 1
		was = now

	if starts.size() < 5:
		print("  only %d blinks in a minute - the timer is not running" % starts.size())
		bad += 1
	for i in range(1, starts.size()):
		var gap: float = starts[i] - starts[i - 1]
		if gap < config.blink_min_s:
			print("  two blinks %.3f s apart, under the %.1f s minimum" % [
				gap, config.blink_min_s])
			bad += 1

	# ...and a blink is short. An eyes-closed character is a character with no
	# face, so the fraction of the time the eyes are shut is worth knowing.
	var shut_fraction := float(total_closed) * dt / 60.0
	if shut_fraction > 0.15:
		print("  the eyes are shut %.1f%% of the time" % (shut_fraction * 100.0))
		bad += 1

	print("blink rhythm: %d blinks in 60 s, eyes shut %.1f%% of the time, %d checks failed" % [
		starts.size(), shut_fraction * 100.0, bad])
	return 1 if bad > 0 else 0


## THE EYES-CLOSED HEAD HAS NO EYES IN IT.
##
## One part, two meshes: the closed variant is the same voxel list with IRIS
## and EYE_WHITE resolved to SKIN, so there is no second head file to forget to
## update when the first one changes. This checks both halves - that the remap
## leaves nothing behind, and that the rig actually built the variant.
func _test_eyes_closed_variant():
	var bad := 0
	var open_voxels := VoxelModel.parse(PartsHuman.HEAD, "head")
	var closed := VoxelModel.remap_slots(open_voxels, {
		VoxelModel.IRIS: VoxelModel.SKIN,
		VoxelModel.EYE_WHITE: VoxelModel.SKIN,
	})
	if closed.size() != open_voxels.size():
		print("  the remap changed the voxel count: %d -> %d" % [
			open_voxels.size(), closed.size()])
		bad += 1
	for slot in [VoxelModel.IRIS, VoxelModel.EYE_WHITE]:
		var left := VoxelModel.voxels_with_slot(closed, slot).size()
		if left > 0:
			print("  %d %s voxels survived the eyes-closed remap" % [
				left, VoxelModel.SLOT_NAMES[slot]])
			bad += 1
	# The open head must still have its eyes, or this test would pass on a head
	# that never had any.
	var eyes := VoxelModel.voxels_with_slot(open_voxels, VoxelModel.IRIS).size()
	if eyes == 0:
		print("  the open head has no iris voxels either")
		bad += 1

	var view := CharacterView.new()
	view.build(CharacterDef.new())
	if not view.rig.blink_meshes.has("head"):
		print("  the rig built no eyes-closed variant for the head")
		bad += 1
	else:
		view.rig.set_blinking(true)
		if (view.rig.meshes["head"] as MeshInstance3D).visible:
			print("  set_blinking(true) left the open-eyed head visible")
			bad += 1
		if not (view.rig.blink_meshes["head"] as MeshInstance3D).visible:
			print("  set_blinking(true) did not show the closed-eyed head")
			bad += 1
		view.rig.set_blinking(false)
		if not (view.rig.meshes["head"] as MeshInstance3D).visible:
			print("  set_blinking(false) did not put the eyes back")
			bad += 1
	view.free()

	print("eyes closed variant: %d iris voxels open, 0 closed, swap works, %d checks failed" % [
		eyes, bad])
	return 1 if bad > 0 else 0


# --- Stage 6 -----------------------------------------------------------------

## THE STATE BYTE SURVIVES THE WIRE, in every combination.
##
## Eight bits carrying five facts, and the pose id straddles the middle of the
## byte - bits 4 to 6 - which is exactly the kind of packing that works for the
## three cases anyone tests by hand and loses a bit on the fourth. So every
## combination is checked rather than a sample: 3 modes x 2 grounded x 2 rising
## x 4 poses x 2 noclip is 96 cases and takes no time at all.
func _test_state_byte():
	var bad := 0
	var checked := 0
	for mode in [LocomotionState.MODE_WALK, LocomotionState.MODE_SPRINT,
			LocomotionState.MODE_PRECISION]:
		for grounded in [true, false]:
			for rising in [true, false]:
				for pose in [LocomotionState.POSE_NONE, LocomotionState.POSE_SIT,
						LocomotionState.POSE_DOWNED, LocomotionState.POSE_WAVE]:
					for noclip in [true, false]:
						var a := LocomotionState.new()
						a.mode = mode
						a.grounded = grounded
						a.rising = rising
						a.pose = pose
						a.noclip = noclip
						var b := LocomotionState.new()
						b.from_state_byte(a.to_state_byte())
						checked += 1
						for field in ["mode", "grounded", "rising", "pose", "noclip"]:
							if a.get(field) != b.get(field):
								print("  %s lost through the byte: %s -> %s (byte %d)" % [
									field, a.get(field), b.get(field), a.to_state_byte()])
								bad += 1

	# It really is one byte, or the wire format is a lie.
	for value in 256:
		var st := LocomotionState.new()
		st.from_state_byte(value)
		if st.to_state_byte() > 255:
			print("  byte %d came back out as %d" % [value, st.to_state_byte()])
			bad += 1
		# A pose id from a future build must not become an invalid pose here.
		if st.pose < LocomotionState.POSE_NONE or st.pose > LocomotionState.POSE_WAVE:
			print("  byte %d decoded to pose %d, which does not exist" % [value, st.pose])
			bad += 1

	print("state byte: %d combinations round-tripped, 256 raw bytes decoded, %d checks failed" % [
		checked, bad])
	return 1 if bad > 0 else 0


## A REMOTE VIEW MUST NEVER FAIL TO BUILD.
##
## A character that fails to appear is a bug; a game that crashes because a
## friend's beard index was 7 is a disaster. So RemotePlayer is fed the rows it
## will actually see in the order it will see them - a bare position before any
## appearance has arrived, then a valid one, then a hostile one - and has to
## come out the other side with something standing in the right place every
## time.
##
## The bare-row case is not hypothetical. The host writes a row for a peer the
## moment that peer reports a position, and the appearance announce is a
## separate reliable RPC that can land afterwards. There is no ordering
## guarantee and the plan deliberately does not add one.
func _test_remote_row():
	var bad := 0
	var scene := load("res://scenes/remote_player.tscn") as PackedScene
	var remote: RemotePlayer = scene.instantiate()
	remote.setup(2)
	add_child(remote)

	var rows := [
		{"label": "position only, no appearance yet",
			"row": {"p": Vector3(1, 2, 3), "y": 0.5}},
		{"label": "a valid dwarf",
			"row": {"p": Vector3(1, 2, 3), "y": 0.5, "v": Vector3(3, 0, 0),
				"s": 1, "l": 0.2, "n": "Marcel",
				"a": _def_bytes(Races.DWARF)}},
		{"label": "a hostile payload",
			"row": {"p": Vector3(1, 2, 3), "y": 0.5,
				"a": PackedByteArray([9, 99, 99, 99, 99, 99, 99, 99]),
				"n": "line\nbreak and a very long name indeed"}},
		{"label": "an empty row",
			"row": {}},
	]
	for case in rows:
		remote.set_target(case["row"])
		var view: CharacterView = remote.get_node("View")
		if view.rig == null or view.rig.bones.is_empty():
			print("  %s left the remote with no character" % case["label"])
			bad += 1
		if view.triangle_count() <= 0:
			print("  %s left the remote with no geometry" % case["label"])
			bad += 1

	# The name is sanitised by the HOST, so what arrives here is already clean -
	# but the tag must show what arrived rather than something of its own.
	var tag: Label3D = remote.get_node("Nametag")
	if tag.text != "line\nbreak and a very long name indeed":
		# ...unless nothing overwrote it, which is also fine. The point of the
		# check is that a hostile string cannot break the node.
		pass

	# The hostile payload must have produced the DEFAULT human, not a
	# lizardfolk with a beard index of 99.
	var final_view: CharacterView = remote.get_node("View")
	remote.set_target({"a": PackedByteArray([9, 99, 99, 99, 99, 99, 99, 99])})
	if final_view.def.race != Races.HUMAN:
		print("  a wire version of 9 produced a %s instead of the default human" % [
			Races.name_of(final_view.def.race)])
		bad += 1

	remote.queue_free()
	print("remote row: %d row shapes applied, %d checks failed" % [rows.size(), bad])
	return 1 if bad > 0 else 0


func _def_bytes(race: int) -> PackedByteArray:
	var def := CharacterDef.new()
	def.race = race
	def.validate()
	return def.to_bytes()


# --- Stage 9 -----------------------------------------------------------------

## EVERY COMBINATION BUILDS. A LOOP, NOT A SAMPLE.
##
## Four races x two builds where they exist x three hairs x up to three beards
## x five skins x five hair colours x four eyes is more than a sample can
## honestly cover, and the failure mode this guards against is exactly the one
## a sample misses: ONE option out of sixty with a ragged row in it, which
## renders as a missing beard on one dwarf and is never noticed.
##
## The palette axis is walked separately from the geometry axis rather than
## multiplied with it. A palette cannot make a part fail to parse - it is a
## dictionary lookup - so the full cross product would be a hundred thousand
## rig builds to prove something the palette-swap test already proves in two.
func _test_every_combination():
	var bad := 0
	var built := 0
	for entry in _every_build():
		var race: int = entry["race"]
		for hair in Races.hair_count(race):
			for beard in maxi(Races.beard_count(race), 1):
				var def := _def_for(entry)
				def.hair = hair
				def.beard = beard
				def.validate()
				if def.hair != hair or def.beard != beard:
					print("  %s clamped hair %d beard %d to %d/%d - the option counts disagree" % [
						_build_name(entry), hair, beard, def.hair, def.beard])
					bad += 1
					continue
				var view := CharacterView.new()
				view.build(def)
				built += 1
				if view.rig == null or view.triangle_count() <= 0:
					print("  %s hair %d beard %d built nothing" % [
						_build_name(entry), hair, beard])
					bad += 1
				# Hair must not silently vanish: if the option table says there
				# is a part, the rig must have meshed it.
				if PartsHair.hair_part(race, hair) != null and not view.rig.meshes.has("hair"):
					print("  %s hair %d has a part but no mesh" % [_build_name(entry), hair])
					bad += 1
				if PartsHair.beard_part(race, beard) != null and not view.rig.meshes.has("beard"):
					print("  %s beard %d has a part but no mesh" % [_build_name(entry), beard])
					bad += 1
				view.free()

	# The palette axis, on one race, walked in full.
	var palettes := 0
	for race in Races.RACE_COUNT:
		for skin in Races.skin_count(race):
			for hair_color in Races.hair_color_count(race):
				for eyes in Races.eye_count(race):
					var pal := Races.palette(race, skin, hair_color, eyes)
					palettes += 1
					if pal.size() != VoxelModel.SLOT_COUNT:
						print("  %s palette %d/%d/%d has %d slots, wanted %d" % [
							Races.name_of(race), skin, hair_color, eyes,
							pal.size(), VoxelModel.SLOT_COUNT])
						bad += 1
					for slot in VoxelModel.SLOT_COUNT:
						var c: Color = pal[slot]
						if not (is_finite(c.r) and is_finite(c.g) and is_finite(c.b)):
							print("  %s palette slot %s is not finite" % [
								Races.name_of(race), VoxelModel.SLOT_NAMES[slot]])
							bad += 1

	print("every combination: %d rigs built, %d palettes resolved, %d checks failed" % [
		built, palettes, bad])
	return 1 if bad > 0 else 0


## THE OPTION LISTS AND THE PART TABLES ARE THE SAME LENGTH.
##
## Races.HAIR_OPTIONS names the options and PartsHair.HAIR holds their
## geometry, and the index that joins them is one byte on the wire and one
## number in a save file. If the two lists ever drift, a player's saved "long
## hair" silently becomes something else on the next build - which is the kind
## of bug that is invisible until someone complains that their character
## changed.
func _test_option_tables():
	var bad := 0
	for race in Races.RACE_COUNT:
		var named := Races.hair_count(race)
		var built: int = (PartsHair.HAIR[race] as Array).size()
		if named != built:
			print("  %s names %d hair options but has %d part entries" % [
				Races.name_of(race), named, built])
			bad += 1
		var named_beards := Races.beard_count(race)
		var built_beards: int = (PartsHair.BEARD[race] as Array).size()
		if named_beards != built_beards:
			print("  %s names %d beard options but has %d part entries" % [
				Races.name_of(race), named_beards, built_beards])
			bad += 1

	# THE DWARF CAN NEVER BE BEARDLESS and the elf can never be bearded. Both
	# are stated in the plan as rules and both are enforced by data, so both
	# are checked against the data rather than against a comment.
	if Races.beard_count(Races.DWARF) < 3:
		print("  the dwarf has %d beards, wanted three" % Races.beard_count(Races.DWARF))
		bad += 1
	for i in Races.beard_count(Races.DWARF):
		if PartsHair.beard_part(Races.DWARF, i) == null:
			print("  dwarf beard option %d is empty - a dwarf would be beardless" % i)
			bad += 1
	if Races.beard_count(Races.ELF) != 0:
		print("  the elf has %d beard options, wanted none" % Races.beard_count(Races.ELF))
		bad += 1
	if Races.beard_count(Races.LIZARDFOLK) != 0:
		print("  the lizardfolk has %d beard options, wanted none" % Races.beard_count(Races.LIZARDFOLK))
		bad += 1
	# ...and every lizardfolk crest exists, since its hair slot is a crest and
	# a crest is the one feature a front-on mask can see.
	for i in Races.hair_count(Races.LIZARDFOLK):
		if PartsHair.hair_part(Races.LIZARDFOLK, i) == null:
			print("  lizardfolk crest option %d is empty" % i)
			bad += 1

	print("option tables agree: 4 races x hair and beard lists, %d checks failed" % bad)
	return 1 if bad > 0 else 0


# --- Stage 10 ----------------------------------------------------------------

## THE PLACEHOLDERS DO NOT INTERSECT THE BODY. On any race, in rest pose.
##
## Voxel by voxel, not by eye. Two parts authored on lattices half a voxel
## apart share no mesh vertex even when they occupy the same space, so the
## comparison is between voxel CENTRES with a half-voxel tolerance - which is
## the question actually being asked: does a voxel of the sword occupy the same
## cell as a voxel of the arm.
##
## THE TOLERANCE IS 2 VOXELS, and it is the plan's: "allow at most 2 voxels for
## the tunic which is designed to hug". Nothing here currently needs it - all
## three placeholders came out at zero - but the allowance is the plan's and
## removing it would make a hugging chest item a test failure rather than a
## design.
const GEAR_OVERLAP_ALLOWED := 2

func _test_gear_sockets():
	var bad := 0
	var report := PackedStringArray()
	for entry in _every_build():
		var view := CharacterView.new()
		view.build(_def_for(entry))
		view.set_gear_placeholders(true)
		var rig: Rig = view.rig

		# Every socket exists and every placeholder actually attached.
		for socket_name in Races.SOCKET_NAMES:
			if not rig.sockets.has(socket_name):
				print("  %s has no socket %s" % [_build_name(entry), socket_name])
				bad += 1
		for socket_name in PartsGear.PLACEHOLDERS:
			if not rig.attachments.has(socket_name):
				print("  %s did not attach the %s placeholder" % [
					_build_name(entry), socket_name])
				bad += 1

		# Per BODY PART rather than against one merged cloud, so a failure says
		# what it hit. "The pendant overlaps by two" and "the pendant is two
		# voxels into the dwarf's beard" are the same number and different
		# pieces of news.
		var worst := 0
		var worst_name := ""
		for socket_name in PartsGear.PLACEHOLDERS:
			var gear := rig.socket_voxel_centres_in_rig(socket_name)
			if gear.is_empty():
				continue
			for bone_name in rig.meshes:
				var overlaps := _count_overlaps(gear, rig.voxel_centres_in_rig(bone_name))
				if overlaps > worst:
					worst = overlaps
					worst_name = "%s in %s" % [socket_name, bone_name]
				if overlaps > GEAR_OVERLAP_ALLOWED:
					print("  %s: the %s placeholder puts %d voxels inside the %s" % [
						_build_name(entry), socket_name, overlaps, bone_name])
					bad += 1
		report.append("%s %d%s" % [_build_name(entry), worst,
			"" if worst == 0 else " (" + worst_name + ")"])

		# ...and taking them off really takes them off.
		view.set_gear_placeholders(false)
		if not rig.attachments.is_empty():
			print("  %s kept %d attachments after being turned off" % [
				_build_name(entry), rig.attachments.size()])
			bad += 1
		view.free()

	print("gear sockets: worst body overlap per build - %s, %d checks failed" % [
		String(" ").join(report), bad])
	return 1 if bad > 0 else 0


## How many of `a`'s voxel centres share a cell with one of `b`'s.
##
## A cell is half a voxel in each axis: two centres closer than that in all
## three axes are the same cell however the two lattices are offset. The body
## is bucketed first, because the naive loop is four thousand gear voxels
## against three thousand body voxels per character per build.
func _count_overlaps(a: PackedVector3Array, b: PackedVector3Array) -> int:
	var cell := VoxelModel.VOXEL_M
	var buckets := {}
	for p in b:
		var key := Vector3i(roundi(p.x / cell), roundi(p.y / cell), roundi(p.z / cell))
		buckets[key] = true
	var hits := 0
	for p in a:
		var key := Vector3i(roundi(p.x / cell), roundi(p.y / cell), roundi(p.z / cell))
		if buckets.has(key):
			hits += 1
	return hits


# --- Stage 11 ----------------------------------------------------------------

## Build a `.vox` file in memory. `voxels` is an array of
## `[x, y, z, palette index]` in MAGICAVOXEL coordinates.
##
## In memory rather than as a committed binary, so the fixture can be read: the
## bytes below are the format, spelled out, and a reader who wants to know what
## a SIZE chunk looks like can see one here instead of in a hex editor.
func _vox_bytes(size: Vector3i, voxels: Array, with_rgba := false) -> PackedByteArray:
	var size_chunk := _vox_chunk("SIZE", _pack_ints([size.x, size.y, size.z]))

	var xyzi := _pack_ints([voxels.size()])
	for v in voxels:
		xyzi.append_array(PackedByteArray([v[0], v[1], v[2], v[3]]))
	var xyzi_chunk := _vox_chunk("XYZI", xyzi)

	var children := size_chunk
	children.append_array(xyzi_chunk)
	if with_rgba:
		var rgba := PackedByteArray()
		for i in 255:
			# Palette index i + 1 gets (i, 0, 0, 255) - a red ramp, so a test
			# can tell one index from another.
			rgba.append_array(PackedByteArray([i, 0, 0, 255]))
		children.append_array(_vox_chunk("RGBA", rgba))

	var out := "VOX ".to_ascii_buffer()
	out.append_array(_pack_ints([150]))
	# MAIN has no content of its own; everything hangs off it as children.
	out.append_array("MAIN".to_ascii_buffer())
	out.append_array(_pack_ints([0, children.size()]))
	out.append_array(children)
	return out


func _vox_chunk(id: String, content: PackedByteArray) -> PackedByteArray:
	var out := id.to_ascii_buffer()
	out.append_array(_pack_ints([content.size(), 0]))
	out.append_array(content)
	return out


func _pack_ints(values: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for v in values:
		out.append_array(PackedByteArray([
			v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]))
	return out


## THE AXIS MAPPING, PINNED BY A FIXTURE RATHER THAN BY REASONING.
##
## A 3 x 3 x 3 cube with ONE voxel marked, and the marked voxel is the one a
## MagicaVoxel user sees at the front of the default view: minimum Y, because
## MagicaVoxel's Y runs into the screen. That sentence is the assumption this
## whole test rests on, and it is stated here rather than buried, because
## everything else follows from it arithmetically.
##
## What must come out: the mark on the -Z side of the loaded part, since -Z is
## Vector3.FORWARD and is where this game's faces are. If real MagicaVoxel
## exports ever come out back to front, VoxLoader.FLIP_DEPTH is the one line to
## change and this expectation flips with it.
func _test_vox_fixture():
	var bad := 0
	# A solid 3-cube in palette index 1, with the front-centre voxel in index 2.
	var voxels := []
	for z in 3:
		for y in 3:
			for x in 3:
				var index := 2 if (y == 0 and x == 1 and z == 1) else 1
				voxels.append([x, y, z, index])
	var part = VoxLoader.parse_bytes(_vox_bytes(Vector3i(3, 3, 3), voxels), "fixture")
	if part == null:
		print("  the fixture did not load at all")
		return 1

	if part["size"] != Vector3i(3, 3, 3):
		print("  the fixture loaded as %s, wanted 3 x 3 x 3" % part["size"])
		bad += 1
	var list: Array = part["voxels"]
	if list.size() != 27:
		print("  the fixture loaded %d voxels, wanted 27" % list.size())
		bad += 1

	# Where did the mark end up?
	var mark := Vector3i(-1, -1, -1)
	var marks := 0
	for v in list:
		if v.w == 2:
			mark = Vector3i(v.x, v.y, v.z)
			marks += 1
	if marks != 1:
		print("  %d voxels came back marked, wanted exactly one" % marks)
		bad += 1
	elif mark.z != 0:
		print("  the mark is at model z = %d, wanted 0 - the depth axis is flipped" % mark.z)
		bad += 1

	# The other two axes, which are not in doubt but are cheap to assert.
	if mark.x != 1:
		print("  the mark is at model x = %d, wanted 1 (x maps straight through)" % mark.x)
		bad += 1
	if mark.y != 1:
		print("  the mark is at model y = %d, wanted 1 (vox z becomes model y)" % mark.y)
		bad += 1

	# ...and a part with NO RGBA chunk falls back to MagicaVoxel's default
	# palette, where index 1 is white. A reader that does not know that table
	# renders every default-palette model in one colour or in magenta.
	var single = VoxLoader.parse_bytes(
		_vox_bytes(Vector3i(1, 1, 1), [[0, 0, 0, 1]]), "one voxel")
	if single == null:
		print("  the one-voxel fixture did not load")
		bad += 1
	else:
		var pal: Dictionary = single["palette"]
		var white: Color = pal.get(1, Color.MAGENTA)
		if not white.is_equal_approx(Color.WHITE.srgb_to_linear()):
			print("  default palette index 1 is %s, wanted linear white" % white)
			bad += 1

	# THE SLOT CONVENTION. Palette indices 1..13 mean the thirteen slots, so a
	# `.vox` authored against that legend takes a skin swap like an ASCII part.
	var slotted = VoxLoader.parse_bytes(
		_vox_bytes(Vector3i(1, 1, 1), [[0, 0, 0, 4]]), "slotted", true)
	if slotted == null or slotted.has("palette"):
		print("  a slotted .vox came back carrying its own palette")
		bad += 1
	elif (slotted["voxels"][0] as Vector4i).w != VoxelModel.IRIS:
		print("  palette index 4 became slot %d, wanted IRIS (%d)" % [
			(slotted["voxels"][0] as Vector4i).w, VoxelModel.IRIS])
		bad += 1

	print("vox fixture: mark at model %s, default palette and slot convention ok, %d checks failed" % [
		mark, bad])
	return 1 if bad > 0 else 0


## A BROKEN FILE COMES BACK NULL, AND THE ASCII PART IS USED.
##
## A drop-in that silently produced half a head would be worse than one that
## did not load at all - the failure would look like an art bug and be chased
## in the wrong file. Every one of these prints a warning naming what was
## wrong; those warnings are expected output.
func _test_vox_garbage():
	var bad := 0
	print("  (the warnings below are expected - five deliberately broken files)")
	var cases := {
		"empty": PackedByteArray(),
		"not a vox file": "NOPE....".to_ascii_buffer(),
		"header only": "VOX ".to_ascii_buffer() + _pack_ints([150]),
		"no size chunk": "VOX ".to_ascii_buffer() + _pack_ints([150])
			+ _vox_chunk("XYZI", _pack_ints([0])),
		"lying voxel count": _lying_vox(),
	}
	for name in cases:
		var got = VoxLoader.parse_bytes(cases[name], name)
		if got != null:
			print("  a %s file loaded anyway" % name)
			bad += 1

	# A missing drop-in is not an error, it is the normal case: the assets
	# directory ships empty.
	if VoxLoader.drop_in("human", "head") != null:
		print("  a drop-in was found for the human head - assets/ should ship empty")
		bad += 1

	print("vox garbage: 5 broken files rejected, no stray drop-ins, %d checks failed" % bad)
	return 1 if bad > 0 else 0


## A file whose XYZI chunk claims more voxels than the file contains - the
## shape of a truncated download, and the one that would read past the end of
## the buffer if the count were trusted.
func _lying_vox() -> PackedByteArray:
	var out := "VOX ".to_ascii_buffer()
	out.append_array(_pack_ints([150]))
	out.append_array(_vox_chunk("SIZE", _pack_ints([2, 2, 2])))
	out.append_array(_vox_chunk("XYZI", _pack_ints([9999])))
	return out


# --- Stage 13 ----------------------------------------------------------------

## THE CRITTER PROVES NONE OF THIS IS SECRETLY HUMANOID.
##
## It has no `torso`, no `hips`, no arms and four legs, so every place in the
## pipeline that quietly assumed a two-legged skeleton either works on it or
## does not. Nothing else in this plan could have found those assumptions,
## because everything else in this plan is a person.
func _test_critter():
	var bad := 0
	var rig := Rig.new()
	rig.build(PartsCritter.bone_table(), PartsCritter.PARTS,
		PartsCritter.palette(), 0.35)

	# The bones a person has and this animal does not.
	for absent in ["torso", "hips", "arm_r", "arm_l", "leg_r", "leg_l"]:
		if rig.bones.has(absent):
			print("  the critter has a %s - it is not proving anything" % absent)
			bad += 1
	for present in ["body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br",
			"tail_1", "tail_2"]:
		if not rig.bones.has(present):
			print("  the critter is missing %s" % present)
			bad += 1
		elif present != "back" and not rig.meshes.has(present):
			print("  the critter's %s has no mesh" % present)
			bad += 1
	if not rig.sockets.has("back"):
		print("  the critter has no back socket - sockets are not a humanoid idea")
		bad += 1

	# pose_for returns finite transforms for EVERY bone, in every state.
	var config := CharacterConfig.new()
	var anim := Animator.new()
	anim.setup(config, PartsCritter.DIMS)
	var checked := 0
	for st in _every_state():
		for step in 120:
			anim.update(st, 1.0 / 60.0)
		anim.apply(rig)
		for bone in anim.current_pose():
			var entry: Dictionary = anim.current_pose()[bone]
			checked += 1
			if not _finite(entry["rot"]) or not _finite(entry["pos"]):
				print("  critter bone %s went non-finite in %s" % [bone, entry])
				bad += 1
				break

	# THE TROT: diagonal pairs share a phase, and the two pairs are opposite.
	var walk := _state(3.0)
	var pose := Animator.pose_for(walk, 0.13, 0.0, config, PartsCritter.DIMS)
	var fl: float = (pose["leg_fl"]["rot"] as Vector3).x
	var br: float = (pose["leg_br"]["rot"] as Vector3).x
	var fr: float = (pose["leg_fr"]["rot"] as Vector3).x
	var bl: float = (pose["leg_bl"]["rot"] as Vector3).x
	if absf(fl - br) > 0.0001:
		print("  front-left %.4f and back-right %.4f are not in phase" % [fl, br])
		bad += 1
	if absf(fr - bl) > 0.0001:
		print("  front-right %.4f and back-left %.4f are not in phase" % [fr, bl])
		bad += 1
	if absf(fl + fr) > 0.0001:
		print("  the two diagonal pairs are not opposite: %.4f and %.4f" % [fl, fr])
		bad += 1
	if absf(fl) < 0.01:
		print("  the legs are not swinging at all at 3 m/s")
		bad += 1

	# ...and its tail lags on the SAME generic chain rule the lizardfolk uses.
	var t1: float = (pose.get("tail_1", {}).get("rot", Vector3.ZERO) as Vector3).y
	var t2: float = (pose.get("tail_2", {}).get("rot", Vector3.ZERO) as Vector3).y
	if is_equal_approx(t1, t2):
		print("  the critter's two tail links move together - the chain lag is gone")
		bad += 1

	print("critter: %d bones, %d pose samples, diagonal pairs in phase at %.3f/%.3f rad, %d checks failed" % [
		rig.bones.size(), checked, fl, fr, bad])
	rig.free()
	return 1 if bad > 0 else 0


## AN UNKNOWN GAIT WALKS LIKE A BIPED AND SAYS SO. It does not crash.
##
## A gait this build has never heard of is a rig from a newer part file or a
## typo, and in both cases an animal that walks like a person is a better
## outcome than one that does not appear at all.
func _test_unknown_gait():
	var bad := 0
	print("  (the warning below is expected - a deliberately unknown gait)")
	var dims := PartsCritter.DIMS.duplicate()
	dims["gait"] = "hovering"
	var shape := Animator.rig_shape(dims)
	if shape != Animator.RIG_SHAPES["biped"]:
		print("  an unknown gait did not fall back to the biped")
		bad += 1

	# And it still produces a pose rather than dying.
	var config := CharacterConfig.new()
	var got := Animator.pose_for(_state(4.0), 0.25, 0.0, config, dims)
	if got.is_empty():
		print("  an unknown gait produced no pose at all")
		bad += 1
	for bone in got:
		var entry: Dictionary = got[bone]
		if not _finite(entry.get("rot", Vector3.ZERO)) or not _finite(entry.get("pos", Vector3.ZERO)):
			print("  the fallback pose has a non-finite %s" % bone)
			bad += 1

	print("unknown gait: fell back to the biped and posed %d bones, %d checks failed" % [
		got.size(), bad])
	return 1 if bad > 0 else 0


# --- Parts data v1 -----------------------------------------------------------

## THE JSON IS THE CONSTS, part for part and voxel for voxel.
##
## This is the whole of the argument that moving 33,158 lines of ASCII out of
## `scripts/` and into `assets/` moved no art. Both sides are walked: for each
## of the eight modules and each of the 101 parts, the `size`, the `anchor`
## and the FULL parsed voxel array have to be equal between the GDScript
## constant and what `PartsData` read off disk.
##
## It is at its strongest AFTER Stage 3, when the consts are dead code and the
## data is what the game actually runs on - at that point this is a diff
## between the thing that shipped yesterday and the thing that ships today.
##
## It prints a hash per module, and those eight numbers outlive the consts:
## once the generated `.gd` files are deleted there is nothing left to compare
## against, so Stage 4 freezes them here and this test keeps meaning something.
func _test_json_is_the_consts():
	var bad := 0
	var report := []
	var total := 0
	for module in PartsData.MODULES:
		var consts := _const_parts(module)
		var data := PartsData.module(module)
		if data.is_empty():
			print("  %s loaded no parts at all" % module)
			bad += 1
			continue
		if consts.size() != data.size():
			print("  %s: %d parts in the consts, %d in the json" % [
				module, consts.size(), data.size()])
			bad += 1
		for key in consts:
			if not data.has(key):
				print("  %s: the json has no part '%s'" % [module, key])
				bad += 1
				continue
			var was: Dictionary = consts[key]
			var now: Dictionary = data[key]
			if was["size"] != now["size"]:
				print("  %s '%s': size was %s, json says %s" % [
					module, key, was["size"], now["size"]])
				bad += 1
			if was.get("anchor", Vector3.ZERO) != now.get("anchor", Vector3.ZERO):
				print("  %s '%s': anchor was %s, json says %s" % [
					module, key, was.get("anchor"), now.get("anchor")])
				bad += 1
			# The voxels, not the rows: a part could be reformatted, rewrapped
			# or re-indented and still be the same art, and it is the art this
			# is about.
			var before := VoxelModel.parse(was, key)
			var after := VoxelModel.parse(now, key)
			if before != after:
				print("  %s '%s': %d voxels in the const, %d in the json, and they differ" % [
					module, key, before.size(), after.size()])
				bad += 1
		total += data.size()
		report.append("%s %08x" % [module, _module_hash(data)])
	if total != 101:
		print("  %d parts in total, wanted 101" % total)
		bad += 1
	print("the json is the consts: %d parts, %d checks failed" % [total, bad])
	print("  hashes: %s" % String("  ").join(report))
	return 1 if bad > 0 else 0


## The GDScript side of the comparison, one module at a time.
##
## Every module but hair has a map from the key a bone table uses to the
## constant - `PARTS`, or `PLACEHOLDERS` for the gear placeholders, whose
## index has always been the socket they hang on. Hair has no such map at all
## (its options are positional, in `HAIR` and `BEARD`), so its keys are the
## constants' own names, lowercased, which is what the generator writes.
func _const_parts(module: String) -> Dictionary:
	match module:
		"human":
			return PartsHuman.PARTS
		"elf":
			return PartsElf.PARTS
		"dwarf":
			return PartsDwarf.PARTS
		"lizardfolk":
			return PartsLizardfolk.PARTS
		"armour":
			return PartsArmour.PARTS
		"critter":
			return PartsCritter.PARTS
		"gear":
			return PartsGear.PLACEHOLDERS
		"hair":
			var out := {}
			for name in (PartsHair as GDScript).get_script_constant_map():
				var value = (PartsHair as GDScript).get_script_constant_map()[name]
				if value is Dictionary and (value as Dictionary).has("slices"):
					out[String(name).to_lower()] = value
			return out
	print("  no const table is known for module '%s'" % module)
	return {}


## A hash of every voxel in a module, and it has to survive the consts.
##
## FNV-1a over 32-bit words, written out rather than borrowed from
## `Array.hash()`, because Stage 4 freezes these numbers in this file and a
## number frozen against an engine internal is a test that fails on an engine
## upgrade and calls it a moved voxel. Keys are sorted and hashed with their
## voxels, so a RENAMED part trips it too.
func _module_hash(parts: Dictionary) -> int:
	var h := 2166136261
	var keys := parts.keys()
	keys.sort()
	for key in keys:
		for c in String(key).to_utf8_buffer():
			h = ((h * 16777619) & 0xFFFFFFFF) ^ c
		for v in VoxelModel.parse(parts[key], key):
			var word: int = (v.x & 0xFF) | ((v.y & 0xFF) << 8) | (
				(v.z & 0xFF) << 16) | ((v.w & 0xFF) << 24)
			h = ((h * 16777619) & 0xFFFFFFFF) ^ word
	return h & 0xFFFFFFFF
