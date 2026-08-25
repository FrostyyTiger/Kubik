class_name FloraJob
extends RefCounted

## One chunk column's ground cover, packed for the renderer, on a worker thread.
##
## THE SAME SHAPE AS MeshJob, FOR THE SAME REASON. Everything a worker touches
## has to be reachable without the scene tree and stable for the whole life of
## the job, and nothing a worker produces may touch the rendering server. So
## this captures what it needs at submit time, returns plain packed arrays, and
## lets the main thread turn them into MultiMeshes.
##
## What it hands back is one PackedFloat32Array per model type - exactly the
## buffer RenderingServer wants - so the main thread's whole job is to set
## `instance_count` and then `buffer`. No per-instance work survives the
## worker, which matters: a busy meadow column is two hundred plants, and two
## hundred main-thread transform builds per column would be the frame budget.

## Which column, in chunk coordinates.
var column := Vector2i.ZERO

## Pure and read-only once its heightmap is built, so every worker can share it.
var generator: TerrainGenerator = null

## The world's snapshot of its tuning values, captured at submit time.
var config: WorldgenConfig = null

## Host-owned set of flora identities that have been gathered, snapshotted at
## submit time. Empty until Stage 9.
var removed := {}

## Block columns inside this chunk column that carry an edit, keyed by
## Vector2i(bx, bz). Snapshotted at submit time for the same reason `removed`
## is: the main thread writes to _edits while this runs.
var edited := {}

## Only instances whose hash falls below this are drawn. A LOCAL knob: identity
## is unaffected, so two machines at the same fraction hide the same plants and
## two machines at different fractions still agree about what exists.
var draw_fraction := 1.0

## The result. model id -> PackedFloat32Array of 16 floats per instance.
var buffers := {}

## How many instances were placed, and how many survived draw_fraction.
var placed := 0
var drawn := 0

## Worker time, microseconds, recorded by the worker rather than measured by
## the main thread - which can only see when it got round to collecting.
var elapsed_usec := 0

## Floats per instance in a MultiMesh buffer: a 3x4 transform, then a colour.
const FLOATS_PER_INSTANCE := 16

const SALT_DRAW := 305


func run() -> void:
	var started := Time.get_ticks_usec()
	var instances := FloraPlacement.column(
		generator, config, column.x, column.y, removed, edited)
	placed = instances.size()

	var by_model := {}
	for inst in instances:
		# HASHED, NOT COUNTED. Dropping every Nth instance would make the
		# survivors depend on iteration order; hashing the position means a
		# machine at 0.5 hides the same half as any other machine at 0.5,
		# and turning the knob up reveals plants rather than reshuffling
		# them.
		var p: Vector3 = inst["pos"]
		var key := WorldHash.hash01(int(p.x * 64.0), int(p.z * 64.0),
			generator.world_seed, SALT_DRAW)
		if draw_fraction < 1.0 and key >= draw_fraction:
			continue
		var model: int = inst["model"]
		if not by_model.has(model):
			by_model[model] = []
		by_model[model].append([key, inst])
		drawn += 1

	# SORTED BY THAT SAME HASH, ascending, so that the first N instances of a
	# buffer ARE the hashed subset at fraction N / count. That is what lets
	# the sparse ring be a MultiMesh visible_instance_count on a buffer built
	# once, rather than a second build - a column crossing from the far ring
	# into the near one reveals the rest of a buffer it already has. See
	# World._refresh_flora and FloraColumn.set_fraction.
	for model in by_model:
		var entries: Array = by_model[model]
		entries.sort_custom(func(a, b): return a[0] < b[0])
		var ordered := []
		for e in entries:
			ordered.append(e[1])
		buffers[model] = _pack(ordered)
	elapsed_usec = Time.get_ticks_usec() - started


## Instances to a MultiMesh buffer.
##
## The layout is fixed by RenderingServer: twelve floats of 3x4 transform in
## ROW-major order, then four floats of colour. Row-major is the trap - the
## rows are made of the basis's COLUMNS, so a matrix built the intuitive way is
## transposed, and a transposed rotation about Y is still a rotation about Y,
## which means the mistake shows up as plants facing the wrong way rather than
## as anything obviously broken.
func _pack(instances: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(instances.size() * FLOATS_PER_INSTANCE)
	var i := 0
	for inst in instances:
		var pos: Vector3 = inst["pos"]
		var s: float = inst["scale"]
		var yaw: float = inst["yaw"]
		var c := cos(yaw) * s
		var sn := sin(yaw) * s
		var tint: float = inst["tint"]

		buf[i] = c;      buf[i + 1] = 0.0; buf[i + 2] = sn;  buf[i + 3] = pos.x
		buf[i + 4] = 0.0; buf[i + 5] = s;  buf[i + 6] = 0.0; buf[i + 7] = pos.y
		buf[i + 8] = -sn; buf[i + 9] = 0.0; buf[i + 10] = c; buf[i + 11] = pos.z
		# The per-instance tint, applied through the MultiMesh colour so the
		# shader needs to know nothing about it. Alpha is left at 1: the
		# model's own vertex alpha carries emissive, and multiplying the two
		# would make a firefly's glow depend on its tint.
		buf[i + 12] = tint; buf[i + 13] = tint
		buf[i + 14] = tint; buf[i + 15] = 1.0
		i += FLOATS_PER_INSTANCE
	return buf
