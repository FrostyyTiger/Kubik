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
		"transfer": _sheet_transfer,
		"light": _sheet_light,
		"closeup": _sheet_closeup,
		"lineup-front": _sheet_lineup_front,
		"lineup-back": _sheet_lineup_back,
		"anim-walk": _sheet_anim_walk,
		"anim-sprint": _sheet_anim_sprint,
		"anim-jump": _sheet_anim_jump,
		"anim-poses": _sheet_anim_poses,
		"study": _sheet_study,
		"silhouettes": _sheet_silhouettes,
		"palette-tiers": _sheet_palette_tiers,
		"masks-40": _sheet_masks_40,
		"outline": _sheet_outline,
		"variants": _sheet_variants,
		"masks-options": _sheet_masks_options,
		"armour": _sheet_armour,
		"tiers": _sheet_tiers,
		"gear": _sheet_gear,
		"campfire": _sheet_campfire,
		"critter": _sheet_critter,
		"budget": _sheet_budget,
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


## Who stands in the lineup. Every race, in its default look.
##
## Character v1 stood the lean human beside the stocky one here, because the
## proportion decision was the first thing Marcel was asked to make. Look v1
## made it - stocky, everywhere - and the lean part set is gone.
func _lineup_defs() -> Array:
	var out := []
	for race in Races.RACE_COUNT:
		if not Races.has_part_set(race):
			continue
		var def := CharacterDef.new()
		def.race = race
		def.validate()
		out.append(def)
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


# --- The two colour sheets ----------------------------------------------------
#
# LIGHT V1 STAGE 0 SPLIT ONE SHEET INTO TWO, and the split is grill Q4.
#
# Until light v1 there was one sheet and it was a hard gate: eight authored
# colours drawn lit and shaded, sampled out of the frame, and held against
# `Look.predict()`, a GDScript mirror of the toon ramp. That worked because the
# ramp was arithmetic simple enough to mirror line for line. There is no ramp
# any more - the engine lights the world - and nothing in GDScript can predict
# a PBR frame with sky ambient, SSAO and a filmic tonemap in it. A gate that
# cannot be predicted is not a gate.
#
# So the one question the old sheet really answered is split from the one it
# only appeared to:
#
#   TRANSFER - still a hard gate, still 6 units per channel, never widened.
#   Eight colours on an UNSHADED material with the tonemap forced to LINEAR:
#   no light, no tonemap curve, no grade. What comes back is exactly what the
#   engine did to the value between `push_back` and the frame, so this proves
#   there is ONE CONVERSION in the colour path and nothing else. It is the
#   claim "what is authored is what is on screen", stated where it can still
#   be stated.
#
#   LIGHT - a MEASUREMENT, not a gate. The same eight through the real
#   material under the real environment, lit and in shadow, at each of four
#   hours, printed as authored / lit / shadow. Where real light lands against
#   the bible's hexes is the round 3 report's colour evidence, and the bible
#   says at the top of `10-color-and-light.md` that its hexes are "starting
#   points for the grading, not exact targets". A number here is never a
#   failure; it is a finding.
#
# The quads cast no shadow. A vertical quad at 3.2 m throws a shadow onto the
# pad about 1.7 m downsun of it, and with the sun's arc tilted that lands on a
# NEIGHBOURING lit swatch - which would be measured as its own colour in the
# shade band and read as an enormous delta.

## The eight. White, mid grey and near black size the transfer at the ends and
## the middle; the five after them are the palette's actual working colours -
## meadow, deep leaf, sand, skin, water - so a miss is a miss on a colour the
## game ships.
const SWATCHES: Array[String] = [
	"#FFFFFF", "#808080", "#202020", "#86B04A",
	"#4E7A32", "#BFB48C", "#E0AC7E", "#4C8FBF",
]

const SWATCH_SIZE := 1.2
const SWATCH_PITCH := 1.55
## y of the shade row's centre. Clear of the lit row, and clear of the pad.
const SWATCH_SHADE_Y := 3.2
## Per-channel sRGB units a transfer swatch may miss the authored value by.
## The plan's number, and it is not widened - see light-v1-tech.md section 5.2.
const SWATCH_TOLERANCE := 6

## THE FOUR HOURS THE LIGHT SHEET IS SHOT AT.
##
## Times of day in Stage 0, because `SkyCycle.HOURS` and the elevation anchors
## it resolves are Stage 1's. Stage 1 replaces these with
## `SkyCycle.time_for_elevation()` on the anchors so the sheet and the tour ask
## for an hour by the same name and get the same sun.
const LIGHT_HOURS := [
	{"name": "day", "t": 0.50},
	{"name": "evening", "t": 0.74},
	{"name": "dusk", "t": 0.79},
	{"name": "night", "t": 0.95},
]

var _swatch_probes: Array = []


## Build the two rows of swatches. Shared by both sheets so they measure the
## same geometry in the same frame, and only the material differs.
##
## THE SHADE ROW FACES THE CAMERA, and under real light that is what a shadow
## IS. The sun's z is negative at every hour, so a +Z normal never has the sun
## on it: the quad receives sky ambient alone, which is exactly the condition
## D8 describes - "shadows are never black outdoors; they take the sky colour".
## No caster is needed to produce it and none is built. Recorded in the status
## doc under "Questions taken alone": the plan asked for a wall, and a wall
## would measure the same sky-lit surface with a wall's own occlusion added.
func _build_swatch_rows(material: Material) -> void:
	for child in _subjects_root.get_children():
		child.free()
	_swatch_probes.clear()

	var holder := Node3D.new()
	_subjects_root.add_child(holder)
	var half := SWATCH_SIZE * 0.5
	for i in SWATCHES.size():
		var authored := Color.html(SWATCHES[i])
		var linear := authored.srgb_to_linear()
		var cx := (float(i) - float(SWATCHES.size() - 1) * 0.5) * SWATCH_PITCH

		# The lit row: flat on the pad, normal up.
		var lit_c := Vector3(cx, 0.02, SUBJECT_Z)
		var lit_q := _swatch_quad([
			Vector3(cx - half, 0.02, SUBJECT_Z - half),
			Vector3(cx - half, 0.02, SUBJECT_Z + half),
			Vector3(cx + half, 0.02, SUBJECT_Z + half),
			Vector3(cx + half, 0.02, SUBJECT_Z - half),
		], Vector3.UP, linear)
		lit_q.mesh.surface_set_material(0, material)
		holder.add_child(lit_q)

		# The shade row: standing, normal at the camera, sky-lit only.
		var sh_c := Vector3(cx, SWATCH_SHADE_Y, SUBJECT_Z)
		var sh_q := _swatch_quad([
			Vector3(cx - half, SWATCH_SHADE_Y - half, SUBJECT_Z),
			Vector3(cx + half, SWATCH_SHADE_Y - half, SUBJECT_Z),
			Vector3(cx + half, SWATCH_SHADE_Y + half, SUBJECT_Z),
			Vector3(cx - half, SWATCH_SHADE_Y + half, SUBJECT_Z),
		], Vector3.BACK, linear)
		sh_q.mesh.surface_set_material(0, material)
		holder.add_child(sh_q)

		_swatch_probes.append({
			"name": SWATCHES[i], "authored": SWATCHES[i], "linear": linear,
			"lit_centre": lit_c, "shade_centre": sh_c})


## THE TRANSFER GATE. One conversion between `push_back` and the frame.
##
## The material is private to this sheet and `unshaded`: it does the same
## decode the real material does and then hands the value straight to ALBEDO,
## so no light, no ambient and no SSAO touch it. The tonemap is forced to
## LINEAR and glow and the adjustments off FOR THIS SHEET ONLY and restored
## afterwards, because AgX reshapes a highlight by design and would be measured
## here as a transfer error.
func _sheet_transfer() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;

vec3 kubik_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	ALBEDO = kubik_to_linear(COLOR.rgb);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_build_swatch_rows(mat)

	var env := _env_node.environment
	var tonemap := env.tonemap_mode
	var exposure := env.tonemap_exposure
	var glow := env.glow_enabled
	var adjust := env.adjustment_enabled
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.adjustment_enabled = false

	_aim_at_swatches()
	var image := await _capture()
	_save_image(image, "transfer")
	_report_transfer(image)

	env.tonemap_mode = tonemap
	env.tonemap_exposure = exposure
	env.glow_enabled = glow
	env.adjustment_enabled = adjust


func _report_transfer(image: Image) -> void:
	print("[Transfer] the one conversion, unshaded, tonemap LINEAR")
	print("[Transfer] %-10s %-9s %-9s %s" % [
		"name", "authored", "measured", "delta r,g,b"])
	var rows := []
	var worst := 0
	for probe in _swatch_probes:
		# The lit quad alone: unshaded, both rows are the same value, and one
		# row is one measurement rather than two of the same thing.
		var measured := _sample_at(image,
			_camera.unproject_position(probe["lit_centre"]))
		var authored: Color = Color.html(probe["authored"])
		var dr := int(round(measured.r * 255.0)) - int(round(authored.r * 255.0))
		var dg := int(round(measured.g * 255.0)) - int(round(authored.g * 255.0))
		var db := int(round(measured.b * 255.0)) - int(round(authored.b * 255.0))
		var delta := maxi(absi(dr), maxi(absi(dg), absi(db)))
		worst = maxi(worst, delta)
		print("[Transfer] %-10s %-9s #%-8s %+4d %+4d %+4d%s" % [
			probe["name"], probe["authored"], measured.to_html(false),
			dr, dg, db, "   MISS" if delta > SWATCH_TOLERANCE else ""])
		rows.append({
			"name": probe["name"], "authored": probe["authored"],
			"measured": measured.to_html(false),
			"delta": [dr, dg, db], "worst": delta})

	var report := {
		"renderer": RenderingServer.get_video_adapter_name(),
		"driver": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"tolerance": SWATCH_TOLERANCE, "worst": worst, "swatches": rows,
	}
	_write_json(report, "transfer")
	print("[Transfer] worst channel delta %d (tolerance %d): %s" % [
		worst, SWATCH_TOLERANCE, "PASS" if worst <= SWATCH_TOLERANCE else "FAIL"])
	if worst > SWATCH_TOLERANCE and _strict():
		push_error("[Transfer] --strict: worst delta %d over tolerance %d" % [
			worst, SWATCH_TOLERANCE])
		get_tree().quit(1)


## THE LIGHT SHEET. Where real light lands, at four hours, lit and in shadow.
##
## No pass and no fail: the bible's hexes are starting points and this is the
## measurement the round 3 report is built from. The grain is forced off for
## the sheet - a 1.2 m swatch is two half-metre cells across, so with it on a
## 9x9 sample measures whichever cell it landed in.
func _sheet_light() -> void:
	_build_swatch_rows(Look.opaque_material())
	var mat := Look.opaque_material()
	mat.set_shader_parameter("grain_sparse", 0.0)
	_aim_at_swatches()

	var hours := []
	for hour in LIGHT_HOURS:
		_set_time(hour["t"])
		var image := await _capture()
		_save_image(image, "light-%s" % hour["name"])
		hours.append(_report_light(image, hour))
	_set_time(-1.0)

	_write_json({
		"renderer": RenderingServer.get_video_adapter_name(),
		"grain_forced_off": true, "hours": hours,
	}, "light")
	Look.apply_local_knobs(config)


func _report_light(image: Image, hour: Dictionary) -> Dictionary:
	var elevation := SkyCycle.sun_position(_sky.time_of_day).y
	var kf := SkyCycle.keyframe_at(elevation, _sky.time_of_day < 0.5)
	print("[Light] %s - t %.3f, elevation %+.3f, sun %s, energy %.2f" % [
		hour["name"], _sky.time_of_day, elevation,
		(kf["sun"] as Color).linear_to_srgb().to_html(false), kf["energy"]])
	print("[Light] %-10s %-9s %-9s %s" % ["name", "authored", "lit", "shadow"])
	var rows := []
	for probe in _swatch_probes:
		var lit := _sample_at(image, _camera.unproject_position(probe["lit_centre"]))
		var shade := _sample_at(image, _camera.unproject_position(probe["shade_centre"]))
		print("[Light] %-10s %-9s #%-8s #%-8s" % [
			probe["name"], probe["authored"],
			lit.to_html(false), shade.to_html(false)])
		rows.append({
			"name": probe["name"], "authored": probe["authored"],
			"lit": lit.to_html(false), "shadow": shade.to_html(false)})
	return {
		"hour": hour["name"], "time_of_day": _sky.time_of_day,
		"elevation": elevation, "energy": kf["energy"],
		"sun": (kf["sun"] as Color).linear_to_srgb().to_html(false),
		"swatches": rows,
	}


func _write_json(report: Dictionary, json_name: String) -> void:
	var path := "%s/%s.json" % [_out_dir, json_name]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("[Gallery]   -> %s" % path)


## One swatch quad: nothing thrown on its neighbours.
func _swatch_quad(points: Array, normal: Vector3, linear: Color) -> MeshInstance3D:
	var mi := _flat_mesh(points, normal, linear)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Both rows in frame, pitched down far enough that the flat row is not a line.
##
## The distance is computed from the viewport's aspect the way _shoot_row does
## it, so the sheet frames the same on a 16:9 window and a 4:3 one - a swatch
## half off the edge is a swatch that cannot be sampled.
func _aim_at_swatches() -> void:
	var span := float(SWATCHES.size()) * SWATCH_PITCH + 1.0
	var aspect := float(get_viewport().size.x) / float(get_viewport().size.y)
	var half_angle := atan(tan(deg_to_rad(FOV) * 0.5) * aspect)
	var distance := maxf(9.0, (span * 0.5) / tan(half_angle))
	var pitch := deg_to_rad(40.0)
	var look_at := Vector3(0.0, 1.6, SUBJECT_Z)
	_camera.global_position = look_at + Vector3(0.0, sin(pitch), cos(pitch)) * distance
	_camera.look_at(look_at, Vector3.UP)


## A 9x9 mean around a point, in sRGB as the frame stores it.
##
## Nine across because a single pixel on a software rasteriser is one sample of
## a dithered edge; nine is a flat field's mean and still well inside the
## smallest swatch on screen.
func _sample_at(image: Image, at: Vector2) -> Color:
	var cx := clampi(int(round(at.x)), 4, image.get_width() - 5)
	var cy := clampi(int(round(at.y)), 4, image.get_height() - 5)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var c := image.get_pixel(cx + dx, cy + dy)
			r += c.r
			g += c.g
			b += c.b
	return Color(r / 81.0, g / 81.0, b / 81.0)


## `--strict` turns a swatch miss into a non-zero exit, which is what makes the
## sheet a gate rather than a report.
func _strict() -> bool:
	return OS.get_cmdline_user_args().has("--strict")


## _save() takes a name and shoots; this takes a frame already in hand, so the
## pixels that are reported are the pixels that were written.
func _save_image(image: Image, file_name: String) -> void:
	var path := "%s/%s.png" % [_out_dir, file_name]
	var err := image.save_png(path)
	if err != OK:
		push_warning("[Gallery] could not write %s: %s" % [path, error_string(err)])
		return
	_written += 1
	print("[Gallery]   -> %s (%dx%d)" % [path, image.get_width(), image.get_height()])


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
	# FROZEN THE MOMENT IT IS BUILT, for the same reason `_freeze_pose` freezes
	# a strip: the pose in the picture must be the pose that was asked for.
	#
	# A live CharacterView breathes on wall-clock `time` and blinks on real
	# randomness - deliberately, both of them, because a character that blinks
	# on a schedule reads as a scripted event rather than as life. That is
	# right in the game and wrong in a gallery, where a still sheet that
	# happens to catch an eyelid is a sheet nobody can compare to yesterday's.
	# It does not fire today: a sheet is shot four process frames after its
	# subjects are built, and the blink timer starts at 3 to 6 seconds. It
	# fires the moment anything makes a sheet slower, which the 96-voxel grid
	# will.
	#
	# HONEST NOTE, because this line was added on a hypothesis the measurement
	# then refuted: this is NOT why two runs of the gallery differ. They differ
	# anyway, and character v2's Stage 0 measured why - see the status doc.
	# Freezing the subject fixed none of it. It is kept because a still sheet
	# catching a blink is a real hazard that costs one line to remove, not
	# because it made anything reproducible.
	view.set_process(false)
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
## The whole lineup at both distances and both times of day, front and
## three-quarter, plus one close pair at four metres. The distance and the
## time are in the FILENAME rather than burned into the image, so the
## pictures can be flipped between without a caption getting in the way.
##
## Character v1 shot the stocky and lean humans here for the proportion
## study; look v1 decided stocky and this is now the lineup's own sheet. The
## 4 m pair is the human and the dwarf - the two faces that differ most - and
## it is where a face, a chamfer and a hand can actually be looked at, since
## at 15 m a 2 m character is sixty pixels tall.
func _sheet_study() -> void:
	var human := CharacterDef.new()
	human.race = Races.HUMAN
	human.validate()
	var dwarf := CharacterDef.new()
	dwarf.race = Races.DWARF
	dwarf.validate()

	_set_time(0.5)
	for angle in [{"deg": 0.0, "name": "front"}, {"deg": 35.0, "name": "three-quarter"}]:
		_set_lineup([human, dwarf])
		_face(FACING_CAMERA + deg_to_rad(angle["deg"]))
		await _shoot("study-detail-4m-%s" % angle["name"], 4.0)

	for time_entry in [{"t": 0.5, "name": "noon"}, {"t": 0.82, "name": "dusk"}]:
		_set_time(time_entry["t"])
		for distance in [15.0, 40.0]:
			for angle in [{"deg": 0.0, "name": "front"},
					{"deg": 35.0, "name": "three-quarter"}]:
				_set_lineup(_lineup_defs())
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


# --- The budget -----------------------------------------------------------------

## What a character actually costs, measured rather than predicted.
##
## TWO NUMBERS PER CHARACTER, and they answer different questions. The mesh
## count comes from the ArrayMesh index arrays and is what the model IS; the
## renderer count comes from RENDER_TOTAL_PRIMITIVES_IN_FRAME with the pad
## subtracted and is what the GPU is ASKED FOR.
##
## THE SECOND IS TWICE THE FIRST, AND THAT IS CORRECT: the sun casts shadows,
## so every triangle is submitted once for the shadow map and once for the
## scene. Worth knowing before anyone reads the drawn column as a model being
## twice the size it is - and worth watching, because a THIRD copy would mean
## something is genuinely being drawn twice, which is what the eyes-closed head
## variant would do if it were ever left visible alongside the open one.
##
## The budget is CharacterConfig.TRIANGLE_BUDGET for a character with hair and
## beard, and it is the MESH column that is judged against it.
func _sheet_budget() -> void:
	for child in _subjects_root.get_children():
		child.free()
	# The pad and the wall have to be paid for once and subtracted, and the
	# renderer needs a frame with nothing on the pad to tell us what that is.
	var empty := await _primitives()
	print("[Gallery] triangle budget, %d per character with hair and beard:" % CharacterConfig.TRIANGLE_BUDGET)
	print("[Gallery]   %-22s %8s %8s %9s %8s   (drawn = mesh x 2, the shadow pass)" % [
		"", "mesh", "drawn", "voxels", "KB"])
	print("[Gallery]   %-22s %8s %8d" % ["(pad and sky alone)", "-", empty])

	var worst := 0
	var worst_name := ""
	for def: CharacterDef in _lineup_defs():
		for gear in [false, true]:
			_set_lineup([def])
			var view: CharacterView = _subjects_root.get_child(0)
			view.set_gear_placeholders(gear)
			var drawn := await _primitives()
			var mesh_tris := view.triangle_count()
			var label := "%s%s" % [_mask_name(def), " + gear" if gear else ""]
			# THE RETAINED VOXEL LIST, which nobody has ever looked at.
			#
			# Rig keeps `{"voxels": Array, "anchor": Vector3}` per bone after
			# meshing, because the gear overlap check has to ask "is there a
			# voxel here" and a mesh cannot answer. Each voxel is a Vector4i in
			# a GDScript Array, so a Variant, so 24 bytes. It is free at 64
			# voxels and it is the number the resolution raise multiplies by
			# 3.375 - so it stops being free somewhere, and the only way to
			# know where is to print it before and after. See the tech plan's
			# item 5: measure, then choose.
			var voxels := _retained_voxels(view.rig)
			print("[Gallery]   %-22s %8d %8d %9d %7dK%s" % [
				label, mesh_tris, drawn - empty, voxels, voxels * 24 / 1024,
				"   OVER" if mesh_tris > CharacterConfig.TRIANGLE_BUDGET else ""])
			if not gear and mesh_tris > worst:
				worst = mesh_tris
				worst_name = _mask_name(def)

	# The critter is not a character and has no budget of its own, but the
	# first-enemy plan will want the number.
	for child in _subjects_root.get_children():
		child.free()
	var rig := Rig.new()
	rig.build(PartsCritter.bone_table(), PartsData.module("critter"),
		PartsCritter.palette(), CharacterConfig.load_or_default().ao_strength)
	var holder := Node3D.new()
	holder.add_child(rig)
	holder.position = Vector3(0.0, 0.0, SUBJECT_Z)
	_subjects_root.add_child(holder)
	var critter_drawn := await _primitives()
	print("[Gallery]   %-22s %8d %8d" % ["critter (not a budget)",
		rig.triangle_count(), critter_drawn - empty])

	print("[Gallery]   worst character: %s at %d triangles, budget %d" % [
		worst_name, worst, CharacterConfig.TRIANGLE_BUDGET])


## Every voxel Rig is still holding on to after meshing, bones and sockets.
static func _retained_voxels(rig: Rig) -> int:
	var total := 0
	for key in rig.part_voxels:
		total += (rig.part_voxels[key]["voxels"] as Array).size()
	return total


## Triangles the renderer drew this frame. Needs a real frame to have happened,
## which is why this awaits the same way a capture does.
func _primitives() -> int:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


## THE SHOT THAT IS NOT A TEST, AND IS THE ACTUAL POINT.
##
## Four characters in tier-3 gear, sitting, at 3 m, at dusk. `DESIGN.md` says
## "your character sitting at the campfire IS the progress screen", and that
## sentence is a specification: progression has to be legible on the body, at
## campfire distance, without a menu - and the payoff moment is a LOOK AT EACH
## OTHER, which is why armour is a character-design problem and not an
## inventory one.
##
## If this image is not one Marcel would put on a poster, the epic is not done,
## whatever the numbers say. There is no assertion here on purpose.
func _sheet_campfire() -> void:
	var seated := []
	for def: CharacterDef in _lineup_defs():
		var v: CharacterDef = def.duplicate_def()
		for slot in CharacterDef.ARMOUR_SLOTS:
			v.armour_tier[slot] = 3
		v.validate()
		seated.append(v)
	# Late dusk rather than full night: the hour the design doc calls the warm
	# register, where firelight would be the only light and a silhouette has to
	# carry itself on its light tier alone.
	_set_time(0.78)
	_set_lineup(seated)
	# Sat down, and shot from 55 degrees - a sitting character photographed
	# from the front looks like a standing one with short legs, because its
	# legs point along its own forward axis straight at the camera. Character
	# v1 found that the hard way and the strip has been shot off-axis since.
	_face(FACING_CAMERA + deg_to_rad(55.0))
	for child in _subjects_root.get_children():
		var view := child as CharacterView
		if view == null:
			continue
		var st := LocomotionState.new()
		st.grounded = true
		st.pose = LocomotionState.POSE_SIT
		_freeze_pose(view, {"state": st})
	# FRAMED FROM THE ROW'S OWN SPAN, not from a fixed 3 m: four characters at
	# 2.6 m apart are a 7.8 m row, and 3 m in front of it puts two of them off
	# the sides. `_shoot_row` computes the distance that fits, which is what
	# "campfire distance" means for a group rather than for one person.
	await _shoot_row("campfire", seated.size())
	_set_time(-1.0)


# --- The critter ---------------------------------------------------------------

## Eight phases of a trot, in a row.
##
## THE SHEET IS THE PROOF that the pipeline is not humanoid-only. The critter
## has no torso, no hips and four legs, and it is meshed by the same mesher,
## rigged by the same Rig, animated by the same Animator and photographed by
## the same camera as a person. Its legs move in DIAGONAL PAIRS, which is one
## entry in Animator.RIG_SHAPES rather than a branch anywhere.
##
## Gallery only. No AI, no scene, no spawning - it is what the first-enemy plan
## starts from.
func _sheet_critter() -> void:
	for child in _subjects_root.get_children():
		child.free()

	var config := CharacterConfig.load_or_default()
	var span := float(STRIP_STEPS - 1) * LINEUP_SPACING
	for k in STRIP_STEPS:
		var holder := Node3D.new()
		var rig := Rig.new()
		rig.build(PartsCritter.bone_table(), PartsData.module("critter"),
			PartsCritter.palette(), config.ao_strength)
		var st := LocomotionState.new()
		st.speed = 4.0
		st.grounded = true
		rig.apply_pose(Animator.pose_for(st, float(k) / float(STRIP_STEPS), 0.0,
			config, PartsCritter.DIMS))
		holder.add_child(rig)
		holder.position = Vector3(-span * 0.5 + float(k) * LINEUP_SPACING, 0.0, SUBJECT_Z)
		# Nearly side on: a trot is a statement about which legs are forward,
		# and from the front all four are foreshortened into one.
		holder.rotation.y = FACING_CAMERA + deg_to_rad(70.0)
		_subjects_root.add_child(holder)

	# Framed from its own shoulder height rather than a person's - a 0.69 m
	# animal photographed at a human's chest height is a row of dots.
	var span_m := float(STRIP_STEPS - 1) * LINEUP_SPACING + 2.0
	var aspect := float(get_viewport().size.x) / float(get_viewport().size.y)
	var half := atan(tan(deg_to_rad(FOV) * 0.5) * aspect)
	var distance := (span_m * 0.5) / tan(half)
	var eye := 0.5
	var look_at := Vector3(0.0, 0.45, SUBJECT_Z)
	_camera.global_position = Vector3(0.0, eye, SUBJECT_Z + distance)
	_camera.look_at(look_at, Vector3.UP)
	await _save("critter-walk")


# --- Gear ---------------------------------------------------------------------

## THE SOCKETS FOLLOW THE ANIMATION, which is the whole claim of Stage 10.
##
## Two sheets. `gear.png` is every race wearing all three placeholders, so the
## fit can be judged on the widest body and the narrowest. `gear-walk.png` is
## the human's walk cycle with them on: the sword swings with the arm because
## it is a child of the arm bone, the tunic rides the torso, and the pendant
## stays on the chest. A still sheet can show that, because the strip is eight
## poses of the same cycle - if the sword did not follow the arm it would be in
## the same place in all eight.
func _sheet_gear() -> void:
	var defs := _lineup_defs()
	_set_lineup(defs)
	for child in _subjects_root.get_children():
		(child as CharacterView).set_gear_placeholders(true)
	_face(FACING_CAMERA + deg_to_rad(25.0))
	await _shoot_row("gear", defs.size())

	var human := CharacterDef.new()
	human.race = Races.HUMAN
	human.validate()
	var states := []
	for k in STRIP_STEPS:
		var st := LocomotionState.new()
		st.speed = 5.0
		st.grounded = true
		states.append({"state": st, "phase": float(k) / float(STRIP_STEPS)})
	_set_posed_row(human, states)
	for child in _subjects_root.get_children():
		(child as CharacterView).set_gear_placeholders(true)
	await _shoot_row("gear-walk", states.size())


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


## Every race wearing everything that has geometry, at three distances.
##
## THREE DISTANCES BECAUSE THE PIECE IS DIFFERENT AT EACH. At 3 m you are
## judging whether a plate looks like a plate; at 15 m whether the tier reads;
## at 40 m whether any of it survives at the distance the game is mostly played
## at. A sheet at one distance answers one of those and quietly implies the
## other two.
func _sheet_armour() -> void:
	var worn := []
	for def: CharacterDef in _lineup_defs():
		var v: CharacterDef = def.duplicate_def()
		for slot in CharacterDef.ARMOUR_SLOTS:
			v.armour_tier[slot] = 4
			v.armour_item[slot] = maxi(Armour.piece_count(slot) - 1, 0)
		v.validate()
		worn.append(v)
	for entry in [{"deg": 0.0, "name": "front"}, {"deg": 35.0, "name": "three-quarter"}]:
		for distance in [3.0, 15.0, 40.0]:
			_set_lineup(worn)
			_face(FACING_CAMERA + deg_to_rad(entry["deg"]))
			await _shoot("armour-%dm-%s" % [int(distance), entry["name"]], distance)


## One race, every tier, side by side, at three distances and two hours.
##
## THE SHEET MARCEL ORDERS THE LADDER FROM. The count is taken at 3 m by
## `--sheet outline`, where a voxel exists; this is the picture, and the claim
## it has to support is that a viewer who has never seen the game puts the six
## in the right order without being told what the order is.
func _sheet_tiers() -> void:
	var base := CharacterDef.new()
	base.race = Races.HUMAN
	base.validate()
	var row := []
	for tier in range(0, CharacterDef.TIER_MAX + 1):
		var v: CharacterDef = base.duplicate_def()
		for slot in CharacterDef.ARMOUR_SLOTS:
			v.armour_tier[slot] = tier
		v.validate()
		row.append(v)
	for time_entry in [{"t": 0.5, "name": "noon"}, {"t": 0.82, "name": "dusk"}]:
		_set_time(time_entry["t"])
		for distance in [3.0, 15.0, 40.0]:
			_set_lineup(row)
			_face(FACING_CAMERA + deg_to_rad(20.0))
			await _shoot("tiers-%s-%dm" % [time_entry["name"], int(distance)], distance)
	_set_time(-1.0)


# --- The value tiers -----------------------------------------------------------
#
# CHARACTER V2 STAGE 1'S GATE, and the reason a data-only stage has one.
#
# The liner is a SHAPE, so the stage that introduces the slot changes no
# picture: the liner voxels arrive with the re-authored parts several stages
# later. That would leave the single highest-value decision in the design doc
# unverified for four stages, which is exactly how a palette ships wrong.
#
# So the palette is photographed as flat swatches through the real ground
# material and MEASURED - the same swatch machinery look v2 built, at the same
# 6-units-per-channel tolerance - and the luminance relationships the design
# rests on are asserted as arithmetic rather than trusted:
#
#   - every skin clears the liner by at least 6:1  (the worst case in the game
#     is the darkest human at 6.1:1, and that number IS the argument for the
#     liner: the old rule managed 2.1:1)
#   - every race spans at least three of the five value tiers
#   - no two races sit in the same place in the mid band, which is the torso,
#     which is most of what you see at 15 m

## How far apart two races' mid tiers have to be, in luminance. The design
## doc's palettes clear this with 0.046 at the tightest (human against elf).
const MID_BAND_MIN_GAP := 0.03

## The floor under skin-to-liner contrast. The whole point of the slot.
const LINER_MIN_RATIO := 6.0


func _sheet_palette_tiers() -> void:
	for child in _subjects_root.get_children():
		child.free()
	_swatch_probes.clear()

	var holder := Node3D.new()
	_subjects_root.add_child(holder)
	var half := SWATCH_SIZE * 0.5
	# One row per race, five tiers across. Laid out in the same frame the light
	# sheet uses so the sampler is the same one.
	var rows := Races.RACE_COUNT
	for race in rows:
		for t in Races.TIER_NAMES.size():
			var hex: String = Races.tier_hex(race, Races.TIER_NAMES[t])
			var linear := Color.html(hex).srgb_to_linear()
			var cx := (float(t) - float(Races.TIER_NAMES.size() - 1) * 0.5) * SWATCH_PITCH
			var cy := SWATCH_SHADE_Y + (float(rows - 1) * 0.5 - float(race)) * SWATCH_PITCH
			holder.add_child(_swatch_quad([
				Vector3(cx - half, cy - half, SUBJECT_Z),
				Vector3(cx + half, cy - half, SUBJECT_Z),
				Vector3(cx + half, cy + half, SUBJECT_Z),
				Vector3(cx - half, cy + half, SUBJECT_Z),
			], Vector3.BACK, linear))
			_swatch_probes.append({
				"name": "%s %s" % [Races.name_of(race), Races.TIER_NAMES[t]],
				"authored": hex, "linear": linear,
				"shade_centre": Vector3(cx, cy, SUBJECT_Z)})

	# GRAIN OFF for the reason the light sheet turns it off: a 1.2 m swatch is
	# two half-metre cells across, so with the material noise on, a 9x9 sample
	# measures whichever cell it landed in.
	#
	# THE CONTACT BAND IS GONE and so is the artefact it caused here. It
	# darkened the bottom half of every half-metre cell of a vertical face, and
	# these swatches are vertical faces stacked four rows high, so each row
	# landed at a different point inside its cell and was darkened by a
	# different amount - measured, before it was switched off for this sheet, as
	# a clean gradient down the page: the bottom race off by 0, the top race off
	# by 11, the misses in perfect vertical order. That was the sheet measuring
	# its own Y coordinate. Light v1 Stage 0 deleted the band outright.
	var mat := Look.opaque_material()
	mat.set_shader_parameter("grain_sparse", 0.0)
	_aim_at_swatches()
	var image := await _capture()
	_save_image(image, "palette-tiers")
	_report_palette_tiers(image)
	Look.apply_local_knobs(config)

	_report_value_tiers()


## A MEASUREMENT, like the light sheet, and for the same reason.
##
## This sheet held every race's five tiers against `Look.predict()` at a
## tolerance of 6 until light v1. There is no prediction under real light, so
## what it reports now is where each authored tier lands on a sky-lit vertical
## face at the frozen hour - the same shape the light sheet uses. The gate that
## still matters for these colours is the transfer sheet, which measures the
## conversion they travel through; the value ladder below is judged by
## arithmetic on the authored hexes and never needed a frame at all.
func _report_palette_tiers(image: Image) -> void:
	print("[Tiers] authored against measured, sky-lit vertical face")
	print("[Tiers] %-22s %-9s %s" % ["name", "authored", "measured"])
	var rows := []
	for probe in _swatch_probes:
		var measured := _sample_at(image,
			_camera.unproject_position(probe["shade_centre"]))
		print("[Tiers] %-22s %-9s #%-8s" % [
			probe["name"], probe["authored"], measured.to_html(false)])
		rows.append({"name": probe["name"], "authored": probe["authored"],
			"measured": measured.to_html(false)})
	_write_json({"time_of_day": _sky.time_of_day, "tiers": rows},
		"palette-tiers")


## The arithmetic the palette has to satisfy, printed and judged.
func _report_value_tiers() -> void:
	print("[Gallery] --- value tiers ---")
	var liner_y := _luminance(Races.LINER_HEX)
	print("[Gallery] liner %s Y=%.4f, and every skin must clear it by %.1fx" % [
		Races.LINER_HEX, liner_y, LINER_MIN_RATIO])

	var bad := 0
	var worst := 1e9
	var worst_name := ""
	for race in Races.RACE_COUNT:
		var line := ""
		for i in Races.skin_count(race):
			var hex: String = Races.SKIN_HEX[race][i]
			var ratio := _luminance(hex) / liner_y
			line += " %s %5.1fx" % [hex, ratio]
			if ratio < worst:
				worst = ratio
				worst_name = "%s %s" % [Races.name_of(race), hex]
			if ratio < LINER_MIN_RATIO:
				bad += 1
		print("[Gallery]   %-11s%s" % [Races.name_of(race), line])
	print("[Gallery]   worst skin/liner %.2f:1 (%s), %d under %.1f" % [
		worst, worst_name, bad, LINER_MIN_RATIO])

	print("[Gallery]   %-11s %8s %8s %8s %8s" % ["race", "deep", "mid", "light", "accent"])
	var mids := []
	for race in Races.RACE_COUNT:
		var ys := []
		for tier in ["deep", "mid", "light", "accent"]:
			ys.append(_luminance(Races.tier_hex(race, tier)))
		mids.append(ys[1])
		print("[Gallery]   %-11s %8.4f %8.4f %8.4f %8.4f" % [
			Races.name_of(race), ys[0], ys[1], ys[2], ys[3]])

	var gap_bad := 0
	var min_gap := 1e9
	for i in mids.size():
		for j in range(i + 1, mids.size()):
			var gap: float = absf(mids[i] - mids[j])
			min_gap = minf(min_gap, gap)
			if gap < MID_BAND_MIN_GAP:
				gap_bad += 1
				print("[Gallery]   %s and %s share a mid band: %.4f apart" % [
					Races.name_of(i), Races.name_of(j), gap])
	print("[Gallery]   closest pair of mid tiers %.4f apart, floor %.2f, %d too close" % [
		min_gap, MID_BAND_MIN_GAP, gap_bad])
	print("[Gallery]   VALUE TIERS: %s" % ["PASS" if bad == 0 and gap_bad == 0 else "FAIL"])


## Relative luminance of an sRGB hex, on the LINEAR values - the same weights
## the shader's own shade band uses.
static func _luminance(hex: String) -> float:
	var c := Color.html(hex).srgb_to_linear()
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


# --- The outline-event metric --------------------------------------------------
#
# THE GATE THE WHOLE ARMOUR TIER LADDER IS DEFINED IN TERMS OF, so it exists
# before there is any armour for it to judge. See docs/plans/character-v2-tech.md
# Stage 0.
#
# WHY THIS METRIC EXISTS AT ALL. With flat vertex colour and no textures,
# surface detail is free to author and invisible at range: the outline is the
# only currency an armour piece has. So an armour tier is a ladder of OUTLINE
# EVENTS - places where the silhouette's width profile has a local maximum the
# naked body does not have - and the design doc's ladder is 0 / 1 / 1 / 3 / 5.
# That is a countable claim, and this counts it.
#
# WHY 3 m AND NOT 15 m, which is where the ladder is JUDGED. At 1280 x 720 a
# 2 m character is 313 px at 3 m and 62 px at 15 m. The smallest legal feature
# is 2 voxels per side, which is 6-7 px at 3 m and about 1 px at 15 m. The
# picture is judged at 15 m by a person; the count is taken where a voxel is
# still a thing that exists. A count taken at 15 m would be measuring the
# antialiaser.
#
# THE REFERENCE IS THE NAKED BODY, not tier 1. That is what makes "tier 1 has
# zero outline events" a measurement rather than a tautology, and a starting
# tunic that quietly widens a shoulder is exactly what it catches.

## Where the count is taken. Not MASK_DISTANCE, and it shares no constants with
## it: the IoU metric's 40 m and 1280 x 720 are load-bearing for every number
## this project has ever recorded and must not move.
const OUTLINE_DISTANCE := 3.0

## An event has to be at least this much wider than the bare body, in model
## voxels, TOTAL across both sides. The Kimi research lane's floor: a chest
## piece that does not change the shoulder outline by at least 2 voxels per
## side will not read as armour.
const OUTLINE_MIN_WIDTH_VOX := 4

## And it has to be at least this tall, in model voxels. Also the research
## lane's: nothing smaller than about 3 x 3 voxels matters at gameplay
## distance, so a one-row bulge is not an event, it is a rounding error.
const OUTLINE_MIN_RUN_VOX := 3


## Count outline events for every race at every tier, against the naked body.
##
## THE LADDER IS 0 / 0 / 1 / 1 / 3 / 5 and this is the gate on it. Anything that
## disagrees is reported with what was wanted, because "tier 4 produced two
## events" is a sentence someone can act on and "the ladder is wrong" is not.
func _sheet_outline() -> void:
	print("[Gallery] --- outline events, measured at %.0f m ---" % OUTLINE_DISTANCE)
	print("[Gallery] an event is >= %d voxels wider than bare, over >= %d voxels of height" % [
		OUTLINE_MIN_WIDTH_VOX, OUTLINE_MIN_RUN_VOX])
	print("[Gallery]   %-34s %6s %6s %6s %6s %7s" % [
		"subject", "front", "prof", "merged", "up", "total"])
	var over := 0
	for def: CharacterDef in _lineup_defs():
		var bare_front := await _outline_mask(def, 0.0, 0)
		var bare_prof := await _outline_mask(def, 90.0, 0)
		for tier in range(0, CharacterDef.TIER_MAX + 1):
			var m_front := bare_front if tier == 0 else await _outline_mask(def, 0.0, tier)
			var m_prof := bare_prof if tier == 0 else await _outline_mask(def, 90.0, tier)
			var f := _outline_bands(m_front, bare_front)
			var p := _outline_bands(m_prof, bare_prof)
			var widths := _merge_bands(f["bands"], p["bands"])
			# A vertical element above the head is one feature however many
			# views can see it.
			var vertical: int = maxi(int(f["vertical"]), int(p["vertical"]))
			var total: int = widths + vertical
			var want: int = int(Armour.TIERS[tier]["events"])
			var flag := ""
			if total != want:
				flag = "   WANTED %d" % want
				over += 1
			print("[Gallery]   %-34s %6d %6d %6d %6d %7d%s" % [
				"%s tier %d %s" % [_mask_name(def), tier, Armour.TIERS[tier]["name"]],
				(f["bands"] as Array).size(), (p["bands"] as Array).size(),
				widths, vertical, total, flag])
	print("[Gallery]   the ladder is %s: %d of %d rows off" % [
		"CORRECT" if over == 0 else "WRONG", over,
		Races.RACE_COUNT * (CharacterDef.TIER_MAX + 1)])


## One subject as a mask at the outline distance, optionally wearing something.
func _outline_mask(def, yaw_deg: float, tier: int) -> Dictionary:
	var worn = def
	if def != null and tier > 0:
		worn = (def as CharacterDef).duplicate_def()
		for slot in CharacterDef.ARMOUR_SLOTS:
			worn.armour_tier[slot] = tier
		worn.validate()
	_enter_mask_mode()
	_set_lineup([worn])
	if yaw_deg != 0.0:
		_face(FACING_CAMERA + deg_to_rad(yaw_deg))
	var eye := _lineup_chest_height()
	_camera.global_position = Vector3(0.0, eye, SUBJECT_Z + OUTLINE_DISTANCE)
	_camera.look_at(Vector3(0.0, eye, SUBJECT_Z), Vector3.UP)
	var image := await _capture()
	_leave_mask_mode()
	return _crop_mask(image)


## Pixels per model voxel at the outline distance.
##
## DERIVED FROM THE CAMERA, not measured off the mask. Godot's `fov` is
## VERTICAL and `keep_aspect` is KEEP_HEIGHT, so the vertical extent at a
## distance is exactly `2 d tan(fov/2)` and this is arithmetic rather than an
## estimate. Measuring it off the mask would fold the subject's own hair into
## the scale factor, and then a race with a taller crest would be measured in
## different units from one without.
func _outline_px_per_voxel() -> float:
	var extent_m := 2.0 * OUTLINE_DISTANCE * tan(deg_to_rad(FOV) * 0.5)
	return (float(get_viewport().size.y) / extent_m) * VoxelModel.VOXEL_M


## The outline's width per row, in pixels, indexed from the BOTTOM row up.
##
## The OUTLINE's width - rightmost minus leftmost - and not the count of set
## pixels, so a gap inside the shape is not an event. An arm held away from the
## body is one outline; the daylight under it is not a second one.
func _width_profile(mask: Dictionary) -> PackedInt32Array:
	var w: int = mask["w"]
	var h: int = mask["h"]
	var bits: PackedByteArray = mask["bits"]
	var out := PackedInt32Array()
	out.resize(h)
	for y in h:
		var lo := -1
		var hi := -1
		for x in w:
			if bits[x + y * w] != 0:
				if lo < 0:
					lo = x
				hi = x
		# Bottom row first: the two masks are compared bottom-aligned, for the
		# same reason _mask_iou aligns them there - two characters standing in
		# the world are standing on the same ground.
		out[h - 1 - y] = 0 if lo < 0 else hi - lo + 1
	return out


## The HEIGHT BANDS at which `worn` is wider than `bare`, plus a vertical flag.
##
## BANDS RATHER THAN A COUNT, because an outline event is a FEATURE and a
## feature can be seen from more than one side. A gorget shows in the front
## view and in profile; counting each view separately made one collar into two
## events, and the ladder disagreed with itself on three of four races. Merging
## by the height a feature sits at is what turns two sightings of one thing back
## into one thing - and it is also just a better description of what an outline
## event is.
func _outline_bands(worn: Dictionary, bare: Dictionary) -> Dictionary:
	if int(worn["w"]) == 0 or int(bare["w"]) == 0:
		return {"bands": [], "vertical": 0}
	var px := _outline_px_per_voxel()
	var min_width := int(round(float(OUTLINE_MIN_WIDTH_VOX) * px))
	var min_run := maxi(1, int(round(float(OUTLINE_MIN_RUN_VOX) * px)))

	var pw := _width_profile(worn)
	var pb := _width_profile(bare)

	var bands := []
	var run := 0
	var limit := mini(pw.size(), pb.size())
	for i in limit + 1:
		var wide := i < limit and pw[i] - pb[i] >= min_width
		if wide:
			run += 1
			continue
		if run >= min_run:
			# Normalised to a fraction of the body's height, so a band on a
			# 1.5 m dwarf and a band on a 2.25 m elf can be compared - and so
			# the front and profile views, whose masks are different heights,
			# agree about where a thing is.
			bands.append([float(i - run) / float(limit), float(i) / float(limit)])
		run = 0

	# Anything standing above the bare body's crown: a crest, a helm spike, the
	# vertical element tier 5 is allowed. At most one per view - two spikes on
	# one helmet are one idea, not two.
	var above := 0
	for i in range(pb.size(), pw.size()):
		if pw[i] > 0:
			above += 1
	return {"bands": bands, "vertical": 1 if above >= min_run else 0}


## Two views' bands, merged into one count of FEATURES.
##
## Two bands are the same feature when they overlap by more than half of the
## LONGER one - not the shorter.
##
## The difference decides whether a cloak can ever be an event. Two sightings of
## one feature have similar extents and overlap almost entirely, so either rule
## merges them. Two DIFFERENT features do not: a cloak's band runs most of the
## body and a pauldron's is a tenth of it, and against the shorter one the
## overlap is the pauldron's whole length - so the cloak swallowed it and tier 5
## measured four events instead of five however big the cloak was. Against the
## longer, a short band inside a long one stays its own feature, which is what
## a pauldron under a cloak actually is.
static func _merge_bands(a: Array, b: Array) -> int:
	var all := a.duplicate()
	for band in b:
		var merged := false
		for other in all:
			var lo: float = maxf(band[0], other[0])
			var hi: float = minf(band[1], other[1])
			var longer: float = maxf(band[1] - band[0], other[1] - other[0])
			if longer > 0.0 and (hi - lo) > longer * 0.5:
				other[0] = minf(other[0], band[0])
				other[1] = maxf(other[1], band[1])
				merged = true
				break
		if not merged:
			all.append(band)
	return all.size()


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
func _flat_mesh(points: Array, normal: Vector3, color: Color,
		wire := true) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	# sRGB on the wire, exactly as every mesh builder in the game does it, so
	# the pad and the swatches travel the path the terrain travels.
	var pushed := Look.to_wire(color) if wire else color
	for p in points:
		verts.push_back(p)
		normals.push_back(normal)
		colors.push_back(pushed)
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

	# THE WORLD'S MATERIAL, not a StandardMaterial3D. The pad, the wall and the
	# swatch quads are the ground the characters stand on and the field a
	# colour is judged against; drawn through anything else they are a
	# different world. The transfer sheet overrides it on its own quads, which
	# is the one place a private material is the point.
	mesh.surface_set_material(0, Look.opaque_material())

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
