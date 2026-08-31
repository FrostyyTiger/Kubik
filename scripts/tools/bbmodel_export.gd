extends SceneTree

## Export the saved character (user://character.tres) as a Blockbench .bbmodel.
##
## Run headless:
##   <godot> --headless --path . -s scripts/tools/bbmodel_export.gd -- --out C:/path/kubik-character.bbmodel
##
## The character is assembled by the SAME code the game uses - Races.bone_table,
## Races.parts_for, Races.palette, Rig.build - so what lands in Blockbench is
## exactly what the game draws, part for part, voxel for voxel. Each part
## becomes a named group at its rest-pose offset; voxels are greedy-merged into
## boxes (one Blockbench cube per box) so the editor stays responsive; colours
## live in a small embedded palette texture, one pixel per semantic slot, so
## repainting a slot in Blockbench recolours everything that uses it.
##
## UNITS: 1 Blockbench unit = 1 model voxel (2.083 cm; a human is 96 tall).
## The character faces -Z ("north" in Blockbench), Godot's own convention.
##
## THIS IS AN EXPORT, NOT A ROUND TRIP. The parts data is authored in
## tools/parts_author/ and this file does not import anything back. To bring an
## edit home, change the Python and re-run it - or read the edited .bbmodel and
## transcribe the voxels; the group/box structure is kept 1:1 with parts to
## keep that mechanical.

const OUT_DEFAULT := "user://character.bbmodel"


func _init() -> void:
	var out_path := OUT_DEFAULT
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--out")
	if i >= 0 and i + 1 < argv.size():
		out_path = argv[i + 1]

	var def := CharacterDef.load_or_default()
	print("[bbmodel] exporting %s" % def.describe())

	var rig := Rig.new()
	rig.build(
		Races.bone_table(def.race, def.build),
		Races.parts_for(def),
		Races.palette(def.race, def.skin, def.hair_color, def.eyes),
		0.0,  # AO is render-time shading; the export wants the authored colours
		Races.hips_pitch_rad(def.race))

	# Whatever the def says the character wears, through the same tables the
	# game resolves (CharacterView.apply_armour does exactly this walk).
	var palette := Races.palette(def.race, def.skin, def.hair_color, def.eyes)
	for slot in CharacterDef.ARMOUR_SLOTS:
		if def.armour_tier[slot] <= 0:
			continue
		var armour_parts := PartsData.module("armour")
		var where := Armour.attach_points(slot)
		var bones: Array = where.get("bones", [])
		for b in bones.size():
			var piece := Armour.part_name_for(slot, def.armour_tier[slot], def.race, b)
			if not piece.is_empty() and armour_parts.has(piece):
				rig.attach_overlay(bones[b], armour_parts[piece], piece, palette, 0.0)
		var carried := Armour.part_name(slot, def.armour_tier[slot], def.race)
		if not carried.is_empty() and armour_parts.has(carried):
			for socket in where.get("sockets", []):
				rig.attach_to_socket(socket, armour_parts[carried], carried, palette, 0.0)

	var doc := _build_bbmodel(rig, palette, def.describe())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("[bbmodel] cannot open %s: %s" % [out_path, error_string(FileAccess.get_open_error())])
		quit(1)
		return
	f.store_string(JSON.stringify(doc))
	f.close()
	print("[bbmodel] wrote %s" % out_path)
	quit(0)


func _build_bbmodel(rig: Rig, palette: Dictionary, label: String) -> Dictionary:
	var elements := []
	var outliner := []
	var used_slots := {}
	var cube_count := 0

	for key in rig.part_voxels:
		var node := _node_for(rig, key)
		if node == null:
			continue
		var entry: Dictionary = rig.part_voxels[key]
		var voxels: Array = entry["voxels"]
		var anchor: Vector3 = entry["anchor"]
		var to_rig := rig.transform_to_rig(node)
		var t := to_rig.origin / VoxelModel.VOXEL_M
		var rot_deg := to_rig.basis.get_euler() * 180.0 / PI

		var child_ids := []
		for box in _greedy_boxes(voxels):
			used_slots[box["slot"]] = true
			var lo: Vector3i = box["min"]
			var hi: Vector3i = box["max"]
			var from := [
				t.x + float(lo.x) - anchor.x,
				t.y + float(lo.y) - anchor.y,
				t.z + float(lo.z) - anchor.z,
			]
			var to := [
				t.x + float(hi.x) + 1.0 - anchor.x,
				t.y + float(hi.y) + 1.0 - anchor.y,
				t.z + float(hi.z) + 1.0 - anchor.z,
			]
			var id := _uuid()
			child_ids.append(id)
			elements.append(_cube(id, "%s_%s" % [key, VoxelModel.SLOT_NAMES[box["slot"]]],
				from, to, box["slot"]))
			cube_count += 1

		outliner.append({
			"name": String(key), "origin": [t.x, t.y, t.z],
			"rotation": [rot_deg.x, rot_deg.y, rot_deg.z],
			"color": 0, "uuid": _uuid(), "export": true, "isOpen": false,
			"locked": false, "visibility": true, "autouv": 0,
			"children": child_ids,
		})

	# One pixel per slot the model actually uses; painting that pixel in
	# Blockbench repaints every face that references the slot.
	var slot_to_px := {}
	var n := 0
	for slot in used_slots:
		slot_to_px[slot] = n
		n += 1
	var img := Image.create(maxi(n, 1), 1, false, Image.FORMAT_RGBA8)
	for slot in slot_to_px:
		var c: Color = palette.get(slot, Color.MAGENTA)
		img.set_pixel(slot_to_px[slot], 0, c.linear_to_srgb())
	var png_b64 := Marshalls.raw_to_base64(img.save_png_to_buffer())

	# Faces were written with the slot index as a placeholder; remap to pixels.
	for el in elements:
		var px: int = slot_to_px[el["color"]]
		for face in el["faces"]:
			el["faces"][face]["uv"] = [px, 0, px + 1, 1]
		el["color"] = px % 8

	print("[bbmodel] %d parts, %d cubes, %d colours" % [outliner.size(), cube_count, n])

	return {
		"meta": {"format_version": "4.10", "model_format": "free", "box_uv": false},
		"name": label,
		"model_identifier": "",
		"resolution": {"width": maxi(n, 1), "height": 1},
		"elements": elements,
		"outliner": outliner,
		"textures": [{
			"path": "", "name": "palette.png", "folder": "", "namespace": "",
			"id": "0", "particle": false, "render_mode": "default",
			"visible": true, "mode": "bitmap", "saved": false, "uuid": _uuid(),
			"relative_path": "", "source": "data:image/png;base64," + png_b64,
		}],
	}


func _node_for(rig: Rig, key: String) -> Node3D:
	if key.begins_with("overlay:"):
		return rig.overlays.get(key.substr(8))
	if key.begins_with("socket:"):
		return rig.attachments.get(key.substr(7))
	return rig.meshes.get(key)


func _cube(id: String, name: String, from: Array, to: Array, slot: int) -> Dictionary:
	var faces := {}
	for face in ["north", "east", "south", "west", "up", "down"]:
		faces[face] = {"uv": [0, 0, 1, 1], "texture": 0}
	return {
		"name": name, "type": "cube", "box_uv": false, "rescale": false,
		"locked": false, "from": from, "to": to, "autouv": 0,
		"color": slot,  # placeholder; remapped to the palette pixel above
		"origin": [0, 0, 0], "faces": faces, "uuid": id,
	}


## Merge same-slot voxels into axis-aligned boxes: extend a run along X, widen
## it along Z, then thicken along Y. Not optimal, deterministic, and cuts a
## few-hundred-voxel part to a few dozen cubes, which is what keeps Blockbench
## interactive.
func _greedy_boxes(voxels: Array) -> Array:
	var grid := {}
	for v in voxels:
		grid[Vector3i(v.x, v.y, v.z)] = v.w
	var keys := grid.keys()
	keys.sort()
	var consumed := {}
	var boxes := []
	for p in keys:
		if consumed.has(p):
			continue
		var slot: int = grid[p]
		var ex: int = p.x
		while _free(grid, consumed, Vector3i(ex + 1, p.y, p.z), slot):
			ex += 1
		var ez: int = p.z
		var ok := true
		while ok:
			for x in range(p.x, ex + 1):
				if not _free(grid, consumed, Vector3i(x, p.y, ez + 1), slot):
					ok = false
					break
			if ok:
				ez += 1
		var ey: int = p.y
		ok = true
		while ok:
			for z in range(p.z, ez + 1):
				if not ok:
					break
				for x in range(p.x, ex + 1):
					if not _free(grid, consumed, Vector3i(x, ey + 1, z), slot):
						ok = false
						break
			if ok:
				ey += 1
		for y in range(p.y, ey + 1):
			for z in range(p.z, ez + 1):
				for x in range(p.x, ex + 1):
					consumed[Vector3i(x, y, z)] = true
		boxes.append({"min": p, "max": Vector3i(ex, ey, ez), "slot": slot})
	return boxes


func _free(grid: Dictionary, consumed: Dictionary, q: Vector3i, slot: int) -> bool:
	return grid.get(q, -1) == slot and not consumed.has(q)


func _uuid() -> String:
	var b := PackedByteArray()
	b.resize(16)
	for i in 16:
		b[i] = randi() % 256
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	var hex := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4),
		hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
