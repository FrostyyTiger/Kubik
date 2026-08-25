extends Node3D

## The character comparison harness. Photographs characters on a flat pad under
## frozen light and quits.
##
##     godot --path . scenes/character/gallery.tscn -- --label some-name
##     godot --path . scenes/character/gallery.tscn -- --label dusk --time 0.82
##     godot --path . scenes/character/gallery.tscn -- --sheet masks-40
##
## WHY NOT THE WORLD. The screenshot tour photographs terrain, and terrain is
## the thing it has to hold still: it freezes the sun for exactly that reason.
## A character comparison needs one more thing held still - the ground. Two
## shots of a dwarf taken a minute apart in the world differ in the hillside
## behind him, the fog depth, and which way the slope runs, and every one of
## those changes the silhouette you were trying to compare. Here the ground is
## a flat pad, the light is frozen, the camera is on rails, and the ONLY thing
## that differs between two runs is the character.
##
## This is the file every stage of character-v1 shoots its evidence with, and
## the sheets it writes are what Marcel judges the run by in the morning. The
## renderer here is not the renderer he will judge it on - see the status doc's
## "Tuned blind" table - so the sheets exist to make the difference between two
## versions visible, not to be the final word on any colour.

## Same root as the tour's build/tour, one directory along. `--label NAME`
## writes to a subdirectory of its own, which is what makes this a comparison
## harness rather than a screenshot tool.
const OUT_DIR := "res://build/character"

## The lineup stands here and the camera backs away from it along +Z. Not the
## origin: an 80 m shot puts the camera at z = 40, which has to still be on the
## pad or the far shots are taken from mid-air over a void.
const SUBJECT_Z := -40.0

## Metres. 60 x 120, as the plan fixes it. At 40 m the frame is 61 m wide, so
## the pad fills it exactly at the distance the silhouette test is judged at.
const PAD_HALF_X := 30.0
const PAD_HALF_Z := 60.0

## The "against a hillside" backdrop. WIDER THAN THE PAD, deliberately: at 80 m
## the frame is 123 m across and a 60 m wall would be a stripe with sky either
## side, which is neither the sky variant nor the hill variant.
const WALL_Z := -56.0
const WALL_HALF_X := 80.0
const WALL_HEIGHT := 20.0

## The game's camera, so a character photographed here is the size it is in
## play. Camera3D's default fov is 75 and player.tscn does not override it.
const FOV := 75.0
const EYE_HEIGHT := 1.7

## Frames to let the renderer settle after moving anything. Nothing streams
## here, but a material override applied on the same frame as the capture has
## not necessarily reached the GPU.
const SETTLE_FRAMES := 4

## Metres between characters in a lineup. Wide enough that two silhouettes
## never touch at 15 m, which would make the mask metric measure the gap.
const LINEUP_SPACING := 2.6

## The yaw a subject stands at to FACE the camera.
##
## A character faces -Z and the camera backs away along +Z, so a subject left
## at yaw 0 shows the camera its back. The first lineup shot taken here was a
## row of backs labelled "front", which is a cheap mistake to make and an
## expensive one to leave in a comparison harness - every silhouette sheet and
## the whole mask metric would have been measuring the wrong side of the
## character.
const FACING_CAMERA := PI

var config: WorldgenConfig = null

@onready var _sun: DirectionalLight3D = $Sun
@onready var _env_node: WorldEnvironment = $WorldEnvironment
@onready var _sky: SkyCycle = $SkyCycle

var _camera: Camera3D = null
var _pad: MeshInstance3D = null
var _wall: MeshInstance3D = null
var _subjects_root: Node3D = null

var _out_dir := OUT_DIR
var _written := 0


func _ready() -> void:
	config = WorldgenConfig.load_or_default()
	# The gallery is not the world and must never write world tuning, but it
	# has to LOOK like the world or a colour judged here means nothing there.
	_sky.setup(config, _sun, _env_node)
	_freeze_time()

	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.far = 600.0
	_camera.current = true
	add_child(_camera)

	_subjects_root = Node3D.new()
	_subjects_root.name = "Subjects"
	add_child(_subjects_root)

	_build_pad()
	_build_wall()

	_run.call_deferred()


func _run() -> void:
	var wanted := _wanted_sheets()
	print("[Gallery] writing to %s" % _out_dir)
	for name in _sheets():
		if not wanted.is_empty() and not wanted.has(name):
			continue
		var fn: Callable = _sheets()[name]
		await fn.call()
	print("[Gallery] done, %d images in %s" % [_written, _out_dir])
	get_tree().quit()


## The sheets this gallery can shoot, in the order they are shot. Stages add
## entries here as the thing each one photographs comes into existence.
func _sheets() -> Dictionary:
	return {
		"testcube": _sheet_testcube,
		"closeup": _sheet_closeup,
		"lineup-front": _sheet_lineup_front,
		"lineup-back": _sheet_lineup_back,
		"anim-walk": _sheet_anim_walk,
		"anim-sprint": _sheet_anim_sprint,
		"anim-jump": _sheet_anim_jump,
		"anim-poses": _sheet_anim_poses,
		"study": _sheet_study,
		"silhouettes": _sheet_silhouettes,
		"masks-40": _sheet_masks_40,
		"variants": _sheet_variants,
		"masks-options": _sheet_masks_options,
	}


# --- Sheets -----------------------------------------------------------------

## The lineup as close as the frame allows, from four sides. NOT part of the
## plan's sheet list - it is the working shot, the one you look at while
## deciding whether a face reads at all, before asking whether it reads at
## 15 m. The PROFILE view is where the lizardfolk's tail and snout live, and
## they are invisible in every other sheet.
func _sheet_closeup() -> void:
	var defs := _lineup_defs()
	_set_lineup(defs)
	await _shoot_row("closeup-front", defs.size())
	_face(FACING_CAMERA + deg_to_rad(35.0))
	await _shoot_row("closeup-three-quarter", defs.size())
	_face(FACING_CAMERA + deg_to_rad(90.0))
	await _shoot_row("closeup-profile", defs.size())
	_face(0.0)
	await _shoot_row("closeup-back", defs.size())


func _sheet_lineup_front() -> void:
	_set_lineup(_lineup_defs())
	await _shoot("lineup-front", 15.0)


func _sheet_lineup_back() -> void:
	_set_lineup(_lineup_defs())
	_face(0.0)
	await _shoot("lineup-back", 15.0)


## Turn every subject. Yaw is absolute, and FACING_CAMERA is the default the
## lineup is built at.
func _face(yaw: float) -> void:
	for s in _subjects_root.get_children():
		(s as Node3D).rotation.y = yaw


## Who stands in the lineup. Every race in the stocky scheme, plus the lean
## human once Stage 7 builds it. Stage 3 has only the human, so that is the
## whole lineup; the capsule "before" is already on disk under
## build/character/character-baseline.
func _lineup_defs() -> Array:
	var out := []
	for race in Races.RACE_COUNT:
		if not Races.has_part_set(race):
			continue
		var def := CharacterDef.new()
		def.race = race
		def.validate()
		out.append(def)
	# The lean human stands beside the stocky one in every sheet, because the
	# proportion decision is the first thing Marcel is asked to make and a
	# comparison you have to open two files for is a comparison nobody makes.
	var lean := CharacterDef.new()
	lean.race = Races.HUMAN
	lean.build = Races.LEAN
	lean.validate()
	out.append(lean)
	return out


## The part mesher, on the pad, at a distance where you can count the voxels.
##
## A 12-voxel cube with a bite out of one corner: the flat faces show the
## palette arriving linear rather than washed out, and the bite is the only
## place a concave corner exists, so it is where baked AO either shows up or
## does not. The self-tests prove the numbers; this proves they reach a screen.
func _sheet_testcube() -> void:
	for child in _subjects_root.get_children():
		child.free()
	var n := 12
	var voxels := []
	for y in n:
		for z in n:
			for x in n:
				# The bite: a quarter of the cube removed from one top corner.
				if x >= n / 2 and y >= n / 2 and z >= n / 2:
					continue
				voxels.append(Vector4i(x, y, z, VoxelModel.SKIN))
	var palette := {VoxelModel.SKIN: Color.html("#E0AC7E").srgb_to_linear()}
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelModel.build_mesh(voxels, palette, Vector3(n / 2.0, 0.0, n / 2.0), 0.35)
	var holder := Node3D.new()
	holder.add_child(mi)
	holder.position = Vector3(0.0, 0.0, SUBJECT_Z)
	_subjects_root.add_child(holder)
	await _shoot("testcube", 2.4)


# --- Animation strips ---------------------------------------------------------
#
# EIGHT COPIES OF ONE CHARACTER, POSED AT PHASE k/8, IN A ROW.
#
# Static, so a strip costs no more to shoot than a portrait, and - the part
# that matters - two runs of the same stage produce pixel-comparable images.
# A video of a walk cycle cannot be diffed; a row of eight frozen poses can,
# and "nothing about the stocky human changed" is a claim Stage 7 has to make
# and Stage 14 has to make again.

## How many phases a locomotion strip is cut into.
const STRIP_STEPS := 8

func _sheet_anim_walk() -> void:
	await _phase_strip("anim-%s-walk", 5.0, LocomotionState.MODE_WALK)


func _sheet_anim_sprint() -> void:
	await _phase_strip("anim-%s-sprint", 13.0, LocomotionState.MODE_SPRINT)


## The name a per-character sheet is filed under.
##
## The BUILD is in it, not just the race. Once the lean human joined the lineup
## both schemes were writing to anim-human-walk.png and the second was
## silently overwriting the first - which would have made "nothing about the
## stocky human changed" impossible to check, since the file with that name
## was the lean one.
func _sheet_slug(def: CharacterDef) -> String:
	if Races.has_lean(def.race):
		return "%s-%s" % [Races.BUILD_NAMES[def.build], Races.name_of(def.race)]
	return Races.name_of(def.race)


## One row per race in the lineup, at eight points of its own cycle.
func _phase_strip(name_format: String, speed: float, mode: int) -> void:
	for def in _lineup_defs():
		var states := []
		for k in STRIP_STEPS:
			var st := LocomotionState.new()
			st.speed = speed
			st.mode = mode
			st.grounded = true
			states.append({"state": st, "phase": float(k) / float(STRIP_STEPS)})
		_set_posed_row(def, states)
		await _shoot_row(name_format % _sheet_slug(def), states.size())


## Takeoff, rising, apex, falling, landing, recovered - the six moments of a
## jump, which is not a cycle and so cannot be cut into eight equal phases.
func _sheet_anim_jump() -> void:
	for def in _lineup_defs():
		var moments := []
		for m in [
			{"g": true, "r": false, "v": 0.0, "land": 0.0},
			{"g": false, "r": true, "v": 6.0, "land": 0.0},
			{"g": false, "r": false, "v": 0.2, "land": 0.0},
			{"g": false, "r": false, "v": -4.0, "land": 0.0},
			{"g": true, "r": false, "v": 0.0, "land": 1.0},
			{"g": true, "r": false, "v": 0.0, "land": 0.0},
		]:
			var st := LocomotionState.new()
			st.speed = 5.0
			st.grounded = m["g"]
			st.rising = m["r"]
			st.vertical = m["v"]
			moments.append({"state": st, "phase": 0.25, "land": m["land"]})
		_set_posed_row(def, moments)
		await _shoot_row("anim-%s-jump" % _sheet_slug(def), moments.size())


## Sit, downed, wave, idle. The four things a character does when it is not
## going anywhere, and the sheet the campfire plan and the death design will
## both want to look at before they own their halves of it.
func _sheet_anim_poses() -> void:
	for def in _lineup_defs():
		var poses := []
		for p in [LocomotionState.POSE_SIT, LocomotionState.POSE_DOWNED,
				LocomotionState.POSE_WAVE, LocomotionState.POSE_NONE]:
			var st := LocomotionState.new()
			st.pose = p
			st.grounded = true
			poses.append({"state": st, "phase": 0.0,
				# Mid-wave rather than at the start of it, or the arm is still
				# on its way up.
				"wave": Animator.WAVE_SECONDS * 0.5 if p == LocomotionState.POSE_WAVE else 0.0,
				"t": 0.35})
		# NEARLY SIDE ON, and this is not a preference. A sitting character's
		# legs point along its own forward axis, straight at a camera it is
		# facing, so from the front a sit is a standing character with short
		# legs - which is exactly what the first version of this sheet showed
		# and what nearly had the sit pose debugged for being correct. 55 degrees
		# rather than a full 90: side on hides the wave, which is on the right
		# arm, so the angle is the compromise that shows all four.
		_set_posed_row(def, poses, 55.0)
		await _shoot_row("anim-%s-poses" % _sheet_slug(def), poses.size())


## A row of copies of one character, each frozen in its own pose.
func _set_posed_row(def: CharacterDef, entries: Array, yaw_deg := 35.0) -> void:
	for child in _subjects_root.get_children():
		child.free()
	var span := float(entries.size() - 1) * LINEUP_SPACING
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var view: CharacterView = _make_subject(def)
		view.position = Vector3(-span * 0.5 + float(i) * LINEUP_SPACING, 0.0, SUBJECT_Z)
		# Three-quarter rather than square on: a leg swing is almost invisible
		# from directly in front, which is the one angle a walk strip must not
		# be shot from.
		view.rotation.y = FACING_CAMERA + deg_to_rad(yaw_deg)
		_subjects_root.add_child(view)
		_freeze_pose(view, entry)


## Put one character into one pose and stop it animating.
##
## `_process` is turned OFF rather than the pose being applied every frame,
## because the view would otherwise blend back toward whatever its own
## LocomotionState says on the very next frame - and the whole point of a strip
## is that the pose in the picture is the pose that was asked for.
func _freeze_pose(view: CharacterView, entry: Dictionary) -> void:
	view.set_process(false)
	var state: LocomotionState = entry["state"]
	var pose := Animator.pose_for(state, float(entry.get("phase", 0.0)),
		float(entry.get("t", 0.0)), CharacterConfig.load_or_default(),
		Races.dims(view.def.race, view.def.build),
		{"look_yaw": 0.0, "look_pitch": 0.0,
		"land": float(entry.get("land", 0.0)), "wave": float(entry.get("wave", 0.0))})
	view.rig.apply_pose(pose)


## Frame a row of `count` subjects, from far enough back that the whole row is
## in shot with a margin.
func _shoot_row(file_name: String, count: int) -> void:
	var span := float(count - 1) * LINEUP_SPACING + 2.0
	# Horizontal half-angle: Godot's fov is VERTICAL and keep_aspect is
	# KEEP_HEIGHT, so the horizontal extent follows the viewport's aspect.
	var aspect := float(get_viewport().size.x) / float(get_viewport().size.y)
	var half := atan(tan(deg_to_rad(FOV) * 0.5) * aspect)
	var distance := (span * 0.5) / tan(half)
	# Level with the row's chest rather than at standing eye height. A strip
	# shot from 1.7 m at 12 m back is a nearly level view either way, but the
	# level one centres the row instead of parking it in the top third and
	# giving over half the frame to grass.
	await _shoot(file_name, distance, "", _lineup_chest_height())


# --- Subjects ---------------------------------------------------------------

## Replace the lineup. `defs` is an array of CharacterDef, or null for the
## capsule stand-in that predates the character system.
func _set_lineup(defs: Array) -> void:
	for child in _subjects_root.get_children():
		child.free()
	var span := float(defs.size() - 1) * LINEUP_SPACING
	for i in defs.size():
		var node := _make_subject(defs[i])
		node.position = Vector3(-span * 0.5 + float(i) * LINEUP_SPACING, 0.0, SUBJECT_Z)
		node.rotation.y = FACING_CAMERA
		_subjects_root.add_child(node)
		if _mask_override:
			_paint_mask(node)


## One subject. THE ONLY PLACE the gallery decides what a character looks like -
## and it decides by handing the def to CharacterView, which is the same thing
## Player and RemotePlayer do. A gallery with its own model builder would be a
## gallery that photographs something the game does not contain.
##
## `null` still means the capsule, so a "before" shot can be retaken at any
## time against the same pad and the same light.
func _make_subject(def) -> Node3D:
	if def == null:
		# The capsule from the old player.tscn, at the same offset: its centre
		# sat 1 m up inside a 2 m body whose feet are at y = 0.
		var mi := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.4
		capsule.height = 2.0
		mi.mesh = capsule
		mi.position = Vector3(0.0, 1.0, 0.0)
		var holder := Node3D.new()
		holder.add_child(mi)
		return holder
	var view := CharacterView.new()
	view.build(def)
	return view


## Chest height of whatever is standing in the lineup, for the camera to aim
## at. Derived from the tallest subject rather than fixed, so a 1.5 m dwarf and
## a 2.25 m elf in the same row are both in frame.
func _lineup_chest_height() -> float:
	var tallest := 2.0
	for def in _lineup_defs():
		if def != null:
			tallest = maxf(tallest, Races.height_m(def.race, def.build))
	return tallest * 0.62


# --- Taking the picture -----------------------------------------------------

## Photograph the lineup from `distance` metres in front of it.
func _shoot(sheet_name: String, distance: float, suffix := "", eye := -1.0) -> void:
	var look_at := Vector3(0.0, _lineup_chest_height(), SUBJECT_Z)
	_camera.global_position = Vector3(
		0.0, EYE_HEIGHT if eye < 0.0 else eye, SUBJECT_Z + distance)
	_camera.look_at(look_at, Vector3.UP)
	await _save("%s%s" % [sheet_name, suffix])


## Draw the current scene and hand back the pixels, without writing anything.
## The mask metric needs the image and not the file.
func _capture() -> Image:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	# The image is only valid once the frame has actually been drawn.
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _save(file_name: String) -> void:
	var image := await _capture()
	var path := "%s/%s.png" % [_out_dir, file_name]
	var err := image.save_png(path)
	if err != OK:
		push_warning("[Gallery] could not write %s: %s" % [path, error_string(err)])
		return
	_written += 1
	print("[Gallery]   -> %s (%dx%d)" % [path, image.get_width(), image.get_height()])


# --- The proportion study -----------------------------------------------------

## THE SHEET MARCEL DECIDES FROM.
##
## Stocky and lean humans side by side, at both distances and both times of
## day, front and three-quarter. The distance and the time are in the FILENAME
## rather than burned into the image, so the eight pictures can be flipped
## between without a caption getting in the way of the comparison.
##
## Same animator on both, which is the point: if the two schemes needed two
## animators the study would be measuring the animator.
func _sheet_study() -> void:
	var stocky := CharacterDef.new()
	stocky.race = Races.HUMAN
	stocky.build = Races.STOCKY
	stocky.validate()
	var lean := CharacterDef.new()
	lean.race = Races.HUMAN
	lean.build = Races.LEAN
	lean.validate()

	# THE DETAIL PAIR FIRST, at four metres. The two distances the plan names
	# are the ones a character is actually seen at, and that is what makes them
	# the right test of READABILITY - but a proportion decision is also a
	# decision about shapes, and at 15 m a 2 m character is sixty pixels tall.
	# One close pair costs one picture and is where the head-to-torso ratio can
	# actually be looked at.
	_set_time(0.5)
	for angle in [{"deg": 0.0, "name": "front"}, {"deg": 35.0, "name": "three-quarter"}]:
		_set_lineup([stocky, lean])
		_face(FACING_CAMERA + deg_to_rad(angle["deg"]))
		await _shoot("study-detail-4m-%s" % angle["name"], 4.0)

	for time_entry in [{"t": 0.5, "name": "noon"}, {"t": 0.82, "name": "dusk"}]:
		_set_time(time_entry["t"])
		for distance in [15.0, 40.0]:
			for angle in [{"deg": 0.0, "name": "front"},
					{"deg": 35.0, "name": "three-quarter"}]:
				_set_lineup([stocky, lean])
				_face(FACING_CAMERA + deg_to_rad(angle["deg"]))
				await _shoot("study-%s-%dm-%s" % [
					time_entry["name"], int(distance), angle["name"]], distance)
	_set_time(-1.0)


## Move the frozen sun. -1 restores whatever --time asked for.
func _set_time(t: float) -> void:
	if t < 0.0:
		_freeze_time()
		return
	_sky.time_of_day = t
	_sky.frozen = true
	_sky.apply()


## THE ACCEPTANCE TEST'S FIRST SENTENCE.
##
## "Standing in the meadow at dusk with the four races lined up 40 m away,
## Marcel can name each one without walking closer." Three distances because
## 15 m is where a face still matters, 40 m is where only the outline does, and
## 80 m is where the plan wants to know whether anything survives at all.
##
## Each distance is shot twice: against the sky, where a silhouette is a dark
## shape on a bright field, and against the stone wall, where it is a dark
## shape on a dark field. A silhouette that reads against sky can vanish
## completely against rock, and half of what the 40 m dusk test is really
## asking is which one you are looking at.
func _sheet_silhouettes() -> void:
	_set_time(0.82)
	for distance in [15.0, 40.0, 80.0]:
		_set_lineup(_lineup_defs())
		_wall.visible = false
		await _shoot("silhouettes-%d" % int(distance), distance)
		_wall.visible = true
		await _shoot("silhouettes-%d-hill" % int(distance), distance)
	_wall.visible = false
	_set_time(-1.0)


# --- Variants -----------------------------------------------------------------

## Every hair and beard a race has, in a row, then every palette in another.
##
## THE PLAN ASKS FOR A GRID and this is two rows instead, because a grid on a
## flat pad means putting the back row further from the camera - which changes
## its scale and its light and makes the two rows incomparable, which is the
## one thing a variants sheet must not do. Two rows at one distance compares
## what it says it compares.
func _sheet_variants() -> void:
	for def: CharacterDef in _lineup_defs():
		if def.build != Races.STOCKY:
			continue  # the lean human wears the same hair as the stocky one
		var race: int = def.race
		var combos := []
		for hair in Races.hair_count(race):
			for beard in maxi(Races.beard_count(race), 1):
				var v: CharacterDef = def.duplicate_def()
				v.hair = hair
				v.beard = beard
				v.validate()
				combos.append(v)
		_set_lineup(combos)
		_face(FACING_CAMERA + deg_to_rad(20.0))
		await _shoot_row("variants-%s" % Races.name_of(race), combos.size())

		var palettes := []
		for skin in Races.skin_count(race):
			var v: CharacterDef = def.duplicate_def()
			v.skin = skin
			# Step the other two with it, so the row walks whole palettes
			# rather than one axis of one.
			v.hair_color = skin % Races.hair_color_count(race)
			v.eyes = skin % Races.eye_count(race)
			v.validate()
			palettes.append(v)
		_set_lineup(palettes)
		_face(FACING_CAMERA + deg_to_rad(20.0))
		await _shoot_row("palettes-%s" % Races.name_of(race), palettes.size())


# --- The silhouette metric ----------------------------------------------------
#
# THE TEST THE WHOLE RACE DESIGN HANGS ON. DESIGN.md asks for "strong distinct
# silhouettes readable at distance in dim light", which is a claim about
# outlines and not about colours - so it is measured on outlines.
#
# Each subject is rendered alone, unshaded black on white at 40 m, cropped to
# its own bounding box and aligned bottom-centre against every other. The
# overlap of two aligned masks over their union is the number: 1.0 means two
# races are the same shape, 0.0 means they share no pixel at all.
#
# TARGET: EVERY PAIR UNDER 0.70. A pair over it says which two races to
# separate, and the fix is to exaggerate the DIFFERENTIATING feature in the
# race table - ears, beard, tail, width - never the shared ones. Making
# everything bigger moves every number at once and separates nothing.

## Distance the metric is measured at. The plan's acceptance test is a dusk
## lineup at 40 m and this is the same distance, so the number and the picture
## are about the same thing.
const MASK_DISTANCE := 40.0

## Anything darker than this on the white background is silhouette. Generous,
## because the edges of an unshaded black mesh are antialiased against white
## and a threshold at the midpoint would eat a voxel off every outline.
const MASK_THRESHOLD := 0.75


func _sheet_masks_40() -> void:
	var defs := _lineup_defs()

	# The sheet itself: the whole lineup as masks, for looking at.
	_enter_mask_mode()
	_set_lineup(defs)
	await _shoot("masks-40", MASK_DISTANCE)
	_leave_mask_mode()

	# THE JUDGED MEASUREMENT IS FRONT-ON, because that is what a lineup at 40 m
	# is. The three-quarter one is reported beside it and is not a second gate:
	# it exists because two of the lizardfolk's three differentiating features -
	# the tail and the snout - are PROFILE features that a front-on mask cannot
	# see at all, and a number that structurally cannot see a tail should say so
	# rather than be quietly believed.
	await _report_masks(defs, 0.0, "front on", true)
	await _report_masks(defs, 35.0, "three-quarter", false)


func _report_masks(defs: Array, yaw_deg: float, label: String, judged: bool) -> void:
	var names := PackedStringArray()
	var masks := []
	# The capsule is in the comparison because "is a character more readable
	# than the capsule it replaced" is a question this run has to answer, and
	# it is the only baseline that exists.
	for def in defs:
		names.append(_mask_name(def))
		masks.append(await _mask_of(def, yaw_deg))
	names.append("capsule")
	masks.append(await _mask_of(null, yaw_deg))
	print("[Gallery] --- %s%s ---" % [label, "" if judged else " (reported, not judged)"])

	# THE TARGET IS ABOUT RACE PAIRS, and only about race pairs.
	#
	# "A pair over it says which two races to separate" - so the two schemes of
	# ONE race are not a failing pair, they are two ways of drawing the same
	# person and are supposed to look alike. Nor is a character against the
	# capsule: that pair is here because "is a character more readable than the
	# thing it replaced" is a question worth a number, not because a capsule is
	# a race anyone has to tell apart from a human at dusk.
	#
	# Both are reported. Only race pairs are judged.
	print("[Gallery] silhouette IoU at %d m, target: every RACE pair under 0.70" % int(MASK_DISTANCE))
	var worst := 0.0
	var worst_pair := ""
	var over := 0
	var race_pairs := 0
	for i in masks.size():
		for j in range(i + 1, masks.size()):
			var iou := _mask_iou(masks[i], masks[j])
			var is_pair := judged and _is_race_pair(defs, i, j)
			var flag := ""
			if is_pair:
				race_pairs += 1
				if iou >= 0.70:
					flag = "  OVER"
					over += 1
				if iou > worst:
					worst = iou
					worst_pair = "%s vs %s" % [names[i], names[j]]
			else:
				flag = "  (reference, not judged)"
			print("[Gallery]   %-22s vs %-22s  %.3f%s" % [names[i], names[j], iou, flag])
	if race_pairs == 0:
		print("[Gallery]   nothing judged in this view")
	else:
		print("[Gallery]   %d race pairs; worst %s at %.3f; %d over 0.70" % [
			race_pairs, worst_pair, worst, over])


## THE WORST CASE ACROSS HAIR AND BEARD OPTIONS.
##
## masks-40 measures the DEFAULT hair and beard, which is what the target is
## judged on. This walks every option instead and reports the worst pair it can
## find, because a player who picks the long hair has not agreed to be
## unrecognisable - and because a metric that only ever sees the defaults is a
## metric that can be satisfied by choosing convenient defaults.
func _sheet_masks_options() -> void:
	var variants := []
	for def: CharacterDef in _lineup_defs():
		if def.build != Races.STOCKY:
			continue
		var race: int = def.race
		for hair in Races.hair_count(race):
			var v: CharacterDef = def.duplicate_def()
			v.hair = hair
			v.validate()
			variants.append({"def": v, "name": "%s hair %d" % [Races.name_of(race), hair]})
		for beard in maxi(Races.beard_count(race), 1):
			if beard == 0:
				continue  # already covered by the default above
			var v: CharacterDef = def.duplicate_def()
			v.beard = beard
			v.validate()
			variants.append({"def": v, "name": "%s beard %d" % [Races.name_of(race), beard]})

	var masks := []
	for entry in variants:
		masks.append(await _mask_of(entry["def"]))

	var worst := 0.0
	var worst_pair := ""
	var over := 0
	var pairs := 0
	for i in variants.size():
		for j in range(i + 1, variants.size()):
			if (variants[i]["def"] as CharacterDef).race == (variants[j]["def"] as CharacterDef).race:
				continue  # two hairstyles on one race are not a race pair
			pairs += 1
			var iou := _mask_iou(masks[i], masks[j])
			if iou >= 0.70:
				over += 1
				print("[Gallery]   %-20s vs %-20s  %.3f  OVER" % [
					variants[i]["name"], variants[j]["name"], iou])
			if iou > worst:
				worst = iou
				worst_pair = "%s vs %s" % [variants[i]["name"], variants[j]["name"]]
	print("[Gallery] worst case across all hair and beard options: %s at %.3f" % [
		worst_pair, worst])
	print("[Gallery]   %d cross-race variant pairs, %d over 0.70" % [pairs, over])


## Is this pair two DIFFERENT races, both of them characters?
##
## Index `defs.size()` is the capsule, which is a reference and not a race.
func _is_race_pair(defs: Array, i: int, j: int) -> bool:
	if i >= defs.size() or j >= defs.size():
		return false
	return (defs[i] as CharacterDef).race != (defs[j] as CharacterDef).race


func _mask_name(def) -> String:
	if def == null:
		return "capsule"
	return "%s %s" % [Races.BUILD_NAMES[def.build], Races.name_of(def.race)]


## One subject, rendered as a mask and cropped to its own bounding box.
func _mask_of(def, yaw_deg := 0.0) -> Dictionary:
	_enter_mask_mode()
	_set_lineup([def])
	if yaw_deg != 0.0:
		_face(FACING_CAMERA + deg_to_rad(yaw_deg))
	# The camera has to be where the metric says it is, not wherever the last
	# sheet left it.
	_camera.global_position = Vector3(0.0, _lineup_chest_height(), SUBJECT_Z + MASK_DISTANCE)
	_camera.look_at(Vector3(0.0, _lineup_chest_height(), SUBJECT_Z), Vector3.UP)
	var image := await _capture()
	_leave_mask_mode()
	return _crop_mask(image)


## Unshaded black on flat white, with the ground and the sky taken away.
##
## The pad and the wall go because a silhouette is measured against nothing;
## the fog goes because it would grey the mask out at 40 m and move the
## threshold; and the material override is SHADING_MODE_UNSHADED so the sun's
## angle cannot make one race's mask thinner than another's.
var _mask_material: StandardMaterial3D = null
var _saved_background := 0
var _saved_fog := true

func _enter_mask_mode() -> void:
	if _mask_material == null:
		_mask_material = StandardMaterial3D.new()
		_mask_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mask_material.albedo_color = Color.BLACK
	var env := _env_node.environment
	_saved_background = env.background_mode
	_saved_fog = env.fog_enabled
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.fog_enabled = false
	_pad.visible = false
	_wall.visible = false
	_mask_override = true


func _leave_mask_mode() -> void:
	var env := _env_node.environment
	env.background_mode = _saved_background
	env.fog_enabled = _saved_fog
	_pad.visible = true
	_mask_override = false


## Set while the gallery is photographing masks, so _set_lineup paints
## whatever it builds. Applied at build time rather than by walking the tree
## afterwards, because a rig builds its meshes as children of its bones and
## finding them again is the same walk twice.
var _mask_override := false


func _paint_mask(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _mask_material
	for child in node.get_children():
		_paint_mask(child)


## The non-white pixels of an image, cropped to their bounding box.
##
## Returned as a flat byte array rather than an Image so the IoU loop is plain
## indexing - a 1280 x 720 get_pixel() per comparison would be four hundred
## thousand engine calls per pair.
func _crop_mask(image: Image) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	var hit := PackedByteArray()
	hit.resize(w * h)
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			var on := (c.r + c.g + c.b) / 3.0 < MASK_THRESHOLD
			hit[x + y * w] = 1 if on else 0
			if on:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return {"w": 0, "h": 0, "bits": PackedByteArray()}

	var cw := hi.x - lo.x + 1
	var ch := hi.y - lo.y + 1
	var bits := PackedByteArray()
	bits.resize(cw * ch)
	for y in ch:
		for x in cw:
			bits[x + y * cw] = hit[(lo.x + x) + (lo.y + y) * w]
	return {"w": cw, "h": ch, "bits": bits}


## Overlap over union of two masks, aligned BOTTOM-CENTRE.
##
## Bottom-centre because two characters compared in the world are standing on
## the same ground and seen from the same side. Aligning by centroid or by
## bounding box would let a dwarf and a human overlap perfectly by sliding one
## up the frame, which is not a thing the eye can do at 40 m.
func _mask_iou(a: Dictionary, b: Dictionary) -> float:
	if a["w"] == 0 or b["w"] == 0:
		return 0.0
	var w: int = maxi(a["w"], b["w"])
	var h: int = maxi(a["h"], b["h"])
	# Offsets that put each mask's bottom edge on the canvas bottom and its
	# horizontal middle on the canvas middle.
	var ax: int = (w - int(a["w"])) / 2
	var ay: int = h - int(a["h"])
	var bx: int = (w - int(b["w"])) / 2
	var by: int = h - int(b["h"])

	var both := 0
	var either := 0
	for y in h:
		for x in w:
			var in_a := _mask_at(a, x - ax, y - ay)
			var in_b := _mask_at(b, x - bx, y - by)
			if in_a and in_b:
				both += 1
			if in_a or in_b:
				either += 1
	return float(both) / float(either) if either > 0 else 0.0


func _mask_at(mask: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= int(mask["w"]) or y >= int(mask["h"]):
		return false
	return (mask["bits"] as PackedByteArray)[x + y * int(mask["w"])] != 0


# --- The set ----------------------------------------------------------------

## A flat pad of meadow, as ONE QUAD rather than as blocks.
##
## Hard rule 12 says parts are data and nothing is built from primitives in
## code - and names this pad as its one exception. Worth saying why it is a
## quad and not 240 x 120 real blocks: the pad's colour is flat, so a lattice
## of blocks would produce an identical image for 57,600 triangles, and the
## per-vertex jitter that gives real terrain its mottling is deliberately OFF
## here. A backdrop that varies between runs is a backdrop that cannot be
## compared against itself.
func _build_pad() -> void:
	_pad = _flat_mesh([
		Vector3(-PAD_HALF_X, 0.0, -PAD_HALF_Z),
		Vector3(-PAD_HALF_X, 0.0, PAD_HALF_Z),
		Vector3(PAD_HALF_X, 0.0, PAD_HALF_Z),
		Vector3(PAD_HALF_X, 0.0, -PAD_HALF_Z),
	], Vector3.UP, Block.color_of(Block.GRASS))
	_pad.name = "Pad"
	add_child(_pad)


## The hillside stand-in: a dark stone wall behind the lineup. Hidden for the
## sky variants, shown for the `-hill` ones. A silhouette that reads against
## bright sky can vanish completely against rock, which is half of what the
## 40 m dusk test is actually asking.
func _build_wall() -> void:
	_wall = _flat_mesh([
		Vector3(-WALL_HALF_X, 0.0, WALL_Z),
		Vector3(WALL_HALF_X, 0.0, WALL_Z),
		Vector3(WALL_HALF_X, WALL_HEIGHT, WALL_Z),
		Vector3(-WALL_HALF_X, WALL_HEIGHT, WALL_Z),
	], Vector3.BACK, Block.color_of(Block.STONE))
	_wall.name = "Wall"
	_wall.visible = false
	add_child(_wall)


## One flat quad, wound so it faces `normal`, in the terrain's material.
##
## The winding identity is the mesher's: (p1 - p0) x (p2 - p0) == -normal is
## "clockwise seen from outside", which is the face Godot draws. Points are
## reversed rather than eyeballed if the quad comes out invisible.
func _flat_mesh(points: Array, normal: Vector3, color: Color) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for p in points:
		verts.push_back(p)
		normals.push_back(normal)
		colors.push_back(color)
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var cross := (verts[1] - verts[0]).cross(verts[2] - verts[0]).normalized()
	if cross.dot(normal) > 0.0:
		indices = PackedInt32Array([0, 2, 1, 0, 3, 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


# --- Command line -----------------------------------------------------------

## Stop the sun where it is, for the whole run.
##
## Same reason as the tour: a day is day_seconds long, a sheet under software
## rendering is not instant, and a comparison harness whose lighting depends on
## how long rendering took compares the wrong thing. `--time 0.82` is dusk and
## is what the silhouette sheets are shot at.
func _freeze_time() -> void:
	var t := -1.0
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--time")
	if i >= 0 and i + 1 < argv.size():
		t = clampf(argv[i + 1].to_float(), 0.0, 1.0)
	if t < 0.0:
		t = config.day_start
	_sky.time_of_day = t
	_sky.frozen = true
	_sky.apply()
	print("[Gallery] time of day frozen at %.3f" % t)


## `--sheet a,b` shoots only those. Empty means every sheet this build has.
func _wanted_sheets() -> Array:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--sheet")
	if i < 0 or i + 1 >= argv.size():
		return []
	var out := []
	for part in argv[i + 1].split(","):
		var clean := part.strip_edges()
		if not clean.is_empty():
			out.append(clean)
	return out


## `--label NAME` -> res://build/character/NAME. No label -> build/character.
##
## The sanitising rule is COPIED FROM THE TOUR, not imported from it. Hard rule
## 1 puts screenshot_tour.gd on the never-touch list, and importing a private
## helper out of it would couple this file to a file this branch may not edit -
## which is exactly the coupling that makes the two runs collide on merge.
func _resolve_out_dir() -> String:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--label")
	if i < 0 or i + 1 >= argv.size():
		return OUT_DIR
	var label := argv[i + 1].strip_edges()
	# Letters, digits, dash, underscore and dot survive; everything else
	# becomes a dash. is_valid_identifier() alone rejects digits, since a digit
	# cannot START an identifier - "v2-baseline" would come out "--baseline".
	var clean := ""
	for c in label:
		if c.is_valid_identifier() or (c >= "0" and c <= "9") or c in "-_.":
			clean += c
		else:
			clean += "-"
	clean = clean.strip_edges()
	if clean.is_empty():
		push_warning("[Gallery] --label %s is not usable as a directory name" % label)
		return OUT_DIR
	return "%s/%s" % [OUT_DIR, clean]
