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

## And how many triangles those instances add up to.
##
## THE BUDGET IS IN TRIANGLES, NOT INSTANCES, and the two are not
## proportional: a grass tuft is a few dozen and a three-metre boulder is
## thousands. A column of heath costs many times a column of meadow at the same
## instance count, and only this number says so.
var triangle_count := 0

## The share of each model's instances currently VISIBLE - 1 in the full
## ring, the far fraction in the sparse one. Never rebuilds anything: the
## buffers are built once at full density with their instances sorted by
## hash (see FloraJob), so a fraction is a prefix and set_fraction() is a
## visible_instance_count per slot.
var draw_fraction := 1.0

## The bodies this column promoted (world feel v1 Stage 11), kept so that a
## column coming back from the cache can hand them to BodyField again. The
## plants are cached as MultiMeshes; the bodies were freed on the way out,
## and no job runs on a cache hit to rebuild them.
var bodies: Array = []

var _slots := {}   # model id -> MultiMeshInstance3D
var _counts := {}  # model id -> instances in the buffer (all of them)
var _block_size := 0.5


# --- THE ANCHOR, horizon v1 Stage 6 ------------------------------------------
#
# A COLUMN IS ITS OWN ANCHOR. `FloraJob` writes instance transforms in WORLD
# metres - it is not this lane's file and it does not know about the floating
# origin - so `apply_buffers` subtracts this column's own world origin from
# every row as it installs it, and the node carries that origin instead.
#
# It is the cheapest possible place to do it: the loop is over the rows of one
# column, on the main thread, in the same pass that was already copying them
# into the rendering server. A column is sixteen metres square, so after the
# subtraction no row is more than 23 m from its node - which is the anchor rule
# with three orders of magnitude to spare, at any distance from the origin.

## This column's world origin, in metres. The node's position is this minus the
## world's origin offset.
var anchor := Vector3.ZERO


func setup(p_column: Vector2i, p_anchor := Vector3.ZERO,
		p_origin := Vector3.ZERO) -> void:
	column = p_column
	name = "Flora%d_%d" % [p_column.x, p_column.y]
	anchor = p_anchor
	position = anchor - p_origin


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
	triangle_count = 0

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
		slot.multimesh.buffer = _to_anchor(buf)
		slot.visible = true
		_counts[model] = count

	# A model this column no longer has any of keeps its node but draws
	# nothing. Freeing and rebuilding the node instead would churn the
	# rendering server every time a column is rebuilt after an edit, which is
	# the one case where this path is on the frame budget.
	for model in _slots:
		if not buffers.has(model):
			_slots[model].multimesh.instance_count = 0
			_slots[model].visible = false
			_counts[model] = 0
	_block_size = config.block_size
	set_fraction(draw_fraction)


## Show this share of every model's instances, cheapest possible: a prefix of
## a hash-sorted buffer. Recounts instance_count and triangle_count as what
## is actually drawn, which is what the budget readout wants to know.
func set_fraction(fraction: float) -> void:
	draw_fraction = fraction
	instance_count = 0
	triangle_count = 0
	for model in _slots:
		var total: int = _counts.get(model, 0)
		var shown := total if fraction >= 0.999 else int(floor(float(total) * fraction))
		var mm: MultiMesh = _slots[model].multimesh
		mm.visible_instance_count = -1 if shown >= total else shown
		instance_count += shown
		triangle_count += shown * FloraModels.triangles_for(model, _block_size)


## One buffer's rows moved from world metres into this column's anchor space.
##
## The 3D transform layout is twelve floats per instance, row-major, and the
## translation is the last float of each row: indices 3, 7 and 11. Nothing else
## in the row is touched - a rotation and a scale are the same in both spaces.
##
## A copy rather than an in-place edit, because the array handed in belongs to
## the job and the flora self-tests compare against it.
func _to_anchor(buf: PackedFloat32Array) -> PackedFloat32Array:
	if anchor == Vector3.ZERO:
		return buf
	var out := buf.duplicate()
	var n := out.size() / FloraJob.FLOATS_PER_INSTANCE
	for i in n:
		var at := i * FloraJob.FLOATS_PER_INSTANCE
		out[at + 3] -= anchor.x
		out[at + 7] -= anchor.y
		out[at + 11] -= anchor.z
	return out


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
