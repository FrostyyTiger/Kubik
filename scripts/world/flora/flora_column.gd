class_name FloraColumn
extends Node3D

## The plants of one chunk column, as MultiMeshes.
##
## ONE NODE PER COLUMN, NOT PER CHUNK. The surface crosses a column exactly
## once, so every plant in a 16 x 16 footprint belongs to one node however many
## chunks tall the column is - and nothing has to be split across whichever
## chunk boundary the ground happens to fall on. It also means a column can be
## rebuilt after an edit without touching the terrain mesh at all.
##
## ONE MultiMeshInstance3D PER MODEL TYPE, because a MultiMesh draws one mesh
## many times. Two grass variants in one column are two nodes and two draw
## calls - and two hundred tufts are still two draw calls, which is the whole
## reason the decoration layer can exist at a density that reads as ground
## cover rather than as scattered ornaments.

var column := Vector2i.ZERO

## How many instances this column is currently drawing, for the F3 readout.
var instance_count := 0

var _slots := {}   # model id -> MultiMeshInstance3D


func setup(p_column: Vector2i) -> void:
	column = p_column
	name = "Flora%d_%d" % [p_column.x, p_column.y]


## Install buffers built on a worker thread.
##
## THIS HALF HAS TO BE ON THE MAIN THREAD, exactly as installing a chunk mesh
## does: MultiMesh talks to the rendering server, which is not safe to call
## from anywhere else. That is precisely why FloraJob hands back packed arrays
## instead of MultiMeshes.
##
## `instance_count` is set BEFORE `buffer`, and the order is not stylistic -
## the buffer setter validates its length against the count, so setting them
## the other way round either drops the data or errors.
func apply_buffers(buffers: Dictionary, config: WorldgenConfig) -> void:
	instance_count = 0

	for model in buffers:
		var buf: PackedFloat32Array = buffers[model]
		var count := buf.size() / FloraJob.FLOATS_PER_INSTANCE
		if count <= 0:
			continue
		var slot: MultiMeshInstance3D = _slots.get(model)
		if slot == null:
			slot = _make_slot(model, config)
			if slot == null:
				continue
			_slots[model] = slot
		slot.multimesh.instance_count = count
		slot.multimesh.buffer = buf
		slot.visible = true
		instance_count += count

	# A model this column no longer has any of keeps its node but draws
	# nothing. Freeing and rebuilding the node instead would churn the
	# rendering server every time a column is rebuilt after an edit, which is
	# the one case where this path is on the frame budget.
	for model in _slots:
		if not buffers.has(model):
			_slots[model].multimesh.instance_count = 0
			_slots[model].visible = false


func _make_slot(model: int, config: WorldgenConfig) -> MultiMeshInstance3D:
	var mesh := FloraModels.mesh_for(model, config.block_size)
	if mesh == null:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# The per-instance tint rides here. Without it every plant of one model in
	# one column is the same exact colour, which is the flat-green problem the
	# terrain's vertex jitter exists to solve, one scale down.
	mm.use_colors = true
	mm.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.name = "Model%d" % model
	node.multimesh = mm
	# Fireflies are drawn with their own shader - see FloraModels.material_for.
	node.material_override = FloraModels.material_for(model)
	# CAST NO SHADOWS. A meadow's worth of grass in the shadow map costs as
	# much as drawing it again, and 30 cm of grass casts a shadow nobody will
	# ever identify as a shadow. Trees are blocks and still cast theirs.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
