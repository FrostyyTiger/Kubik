class_name FarFieldJob
extends RefCounted

## Builds the low-poly terrain mesh that stands in for voxels beyond the voxel
## radius. Runs on a worker thread, for the same reason chunk meshing does.
##
## WHY THIS EXISTS AT ALL. The design wants a 200 m view distance. 200 m of
## voxels is roughly 30,000 chunks, which is not a performance problem so much
## as an impossibility. Everything past the voxel radius is therefore one mesh
## built straight from the coarse heightmap at 4 m per vertex - the same
## heightmap the voxels came from, so the two agree about where the ground is.
##
## IT IS BUILT AROUND THE PLAYER, NOT AROUND THE WORLD. The plan describes one
## mesh over the whole 1.5 km map. Flat-shaded, that is 374x374 quads at four
## unshared vertices each - about 559k vertices, well past the plan's own
## ~300k budget, and it would have to be rebuilt every time the voxel hole
## moved. Fog is fully opaque at 200 m, so terrain past that is not merely
## cheap to draw, it is INVISIBLE. Building a disc sized to the fog instead
## gives ~45k vertices and a rebuild small enough to hide on a worker thread.
## Recorded in STATUS.md as a departure.
##
##
## LOD RINGS, AND WHY VIEW DISTANCE IS NOW NEARLY FREE
##
## Terrain v1 built the whole disc at one resolution, so its cost was quadratic
## in the fog distance: 42,684 vertices at 200 m, 178,428 at 400 m, 404,588 at
## 600 m. That is what made fog_end look expensive, and it is why the v1 world
## could not simply see further.
##
## It is the wrong shape of cost. A vertex 500 m away covers a hundredth of the
## screen area of one 50 m away, so spending equal detail on both spends it
## where it cannot be seen. The rings below step the resolution down with
## distance - 4 m per vertex out to 200 m, 8 m to 400 m, 16 m beyond - and each
## ring covers four times the area of its predecessor for a comparable vertex
## count. Cost becomes roughly logarithmic in view distance, which is what
## turns fog_end from a performance dial into a look dial.
##
##
## CRACKS, AND WHY THIS USES SKIRTS
##
## Where a fine ring meets a coarse one, the fine ring has a vertex halfway
## along each coarse edge. Its height comes from the heightmap; the coarse edge
## is a straight line between its own two ends. The two do not agree, and the
## disagreement is a crack you can see the sky through - the classic T-junction
## of every LOD scheme.
##
## The textbook fix is to snap those midpoints onto the coarse edge. It is
## exact and costs nothing at runtime, and it needs to know which vertices lie
## on a ring boundary and between which two coarse vertices - easy on square
## rings, genuinely awkward on the DISC this builds. The disc is worth keeping:
## it matches the shape of the fog, and a square would build 27% more quads in
## corners that are opaque grey.
##
## So: skirts. Any quad whose neighbour across an edge belongs to a different
## ring, or to no ring at all, drops a vertical curtain from that edge. It costs
## a few percent in vertices, it does not care what shape the rings are, and it
## cannot be subtly wrong the way a snapping rule can - a crack is either
## covered or it is not.

## How far past fog_end to build, as a multiple. Fog hides everything at
## fog_end; a little beyond means the mesh's own edge is never the thing you
## notice first.
const FOG_MARGIN := 1.2

## Where each level of detail ends, in metres. The last ring has no entry here:
## it runs from the final boundary out to the fog.
const RING_OUTER_M := [200.0, 400.0]

## Blocks per vertex in each ring, as a multiple of config.far_step. At the
## default far_step of 8 blocks that is 4, 8 and 16 metres per vertex.
const RING_STEP_MULTIPLE := [1, 2, 4]

## How far a skirt hangs below its edge, as a multiple of that ring's step in
## BLOCKS. At 1.0 a skirt covers any mismatch up to a 45 degree slope across
## one cell, which is well past what a heightmap sampled at that spacing can
## produce. Cheap insurance either way: a skirt that is too long is buried in
## the hillside, a skirt that is too short is a hole in the horizon.
const SKIRT_DEPTH_CELLS := 1.0

## Skirts are drawn darker than the surface they hang from. They stand in for
## ground seen edge-on through a crack, and a crack that lights up BRIGHTER
## than the terrain around it draws the eye straight to the artefact it is
## there to hide.
const SKIRT_SHADE := 0.7

var heightmap: Heightmap = null
var generator: TerrainGenerator = null
var config: WorldgenConfig = null

## Block position the disc is centred on.
var center := Vector2i.ZERO

var arrays: Array = []
var vertex_count := 0


func run() -> void:
	var bs: float = config.block_size
	var base_step: int = config.far_step
	var far_radius := config.fog_end_m / bs * FOG_MARGIN

	# Where the voxels take over. Quads well inside this are skipped - the
	# voxel terrain is drawn there instead, and drawing both is overdraw.
	# The margin means the two OVERLAP by two cells rather than meeting
	# exactly: a small overlap is hidden by the voxels, whereas a small gap is
	# a hole you can see the sky through.
	var voxel_radius_blocks: float = float(config.voxel_radius_chunks * Chunk.SIZE)
	var exclude := maxf(voxel_radius_blocks - float(2 * base_step), 0.0)

	# The far mesh is the COARSE heightmap; the voxels are that plus per-block
	# detail, so at the boundary the two differ by up to detail_amp. Dropping
	# the far mesh by half of that keeps it under the voxel surface through the
	# overlap instead of poking up through it.
	var y_offset := -0.5 * config.detail_amp * bs

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var inner := exclude
	for ring in RING_STEP_MULTIPLE.size():
		var step: int = base_step * RING_STEP_MULTIPLE[ring]
		var outer := far_radius
		if ring < RING_OUTER_M.size():
			outer = minf(RING_OUTER_M[ring] / bs, far_radius)
		if outer <= inner:
			# The whole ring is inside the voxel radius, or past the fog. At
			# the Low preset the 400 m ring is the second of those and the
			# outermost ring never starts at all.
			inner = maxf(inner, outer)
			continue
		_build_ring(ring, step, inner, outer, y_offset, verts, normals, colors, indices)
		inner = outer

	vertex_count = verts.size()
	if verts.is_empty():
		arrays = []
		return

	arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices


## One annulus of the disc, at one resolution.
##
## `inner` and `outer` are radii in BLOCKS from the player, and membership is
## decided by the QUAD CENTRE. Deciding by centre rather than by corner is what
## makes the skirt test below correct: a quad and its neighbour are in the same
## ring exactly when their two centres both pass the same test, so asking about
## the neighbour's centre answers "is there a quad over there" without having
## to have built it yet.
func _build_ring(ring: int, step: int, inner: float, outer: float, y_offset: float,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var bs: float = config.block_size

	# Snap the centre to THIS RING'S grid, so its vertices land on the same
	# world positions every rebuild and the mesh does not shimmer as the player
	# walks. Each ring snaps to its own step, which is also what keeps the
	# coarse rings' vertices a subset of the fine rings' - the property the
	# skirts only have to cover the gaps between.
	var cx := int(floor(float(center.x) / float(step))) * step
	var cz := int(floor(float(center.y) / float(step))) * step

	var span := int(ceil(outer / float(step))) + 1
	var skirt_drop := float(step) * SKIRT_DEPTH_CELLS * bs

	for j in range(-span, span):
		for i in range(-span, span):
			var bx0 := cx + i * step
			var bz0 := cz + j * step
			if not _in_ring(bx0, bz0, step, inner, outer):
				continue
			if not heightmap.in_bounds(bx0, bz0):
				continue

			var bx1 := bx0 + step
			var bz1 := bz0 + step

			var h00 := heightmap.height_at(float(bx0), float(bz0))
			var h10 := heightmap.height_at(float(bx1), float(bz0))
			var h11 := heightmap.height_at(float(bx1), float(bz1))
			var h01 := heightmap.height_at(float(bx0), float(bz1))

			# Corner order is the +Y face order from ChunkMesher, which is
			# clockwise seen from above - the same winding the voxels use, so
			# both are lit and culled identically.
			var p0 := Vector3(float(bx0) * bs, h00 * bs + y_offset, float(bz0) * bs)
			var p1 := Vector3(float(bx1) * bs, h10 * bs + y_offset, float(bz0) * bs)
			var p2 := Vector3(float(bx1) * bs, h11 * bs + y_offset, float(bz1) * bs)
			var p3 := Vector3(float(bx0) * bs, h01 * bs + y_offset, float(bz1) * bs)

			# Colour from the same zone rules the voxels use, sampled at the
			# quad's middle. Anything else and the treeline would be in a
			# different place near and far.
			var mid_h := (h00 + h10 + h11 + h01) * 0.25
			var zone := generator.surface_zone_at(
				bx0 + step / 2, bz0 + step / 2, mid_h)
			var color := Block.color_of(TerrainGenerator.ZONE_SURFACE[zone])

			_push_quad(p0, p1, p2, p3, color, verts, normals, colors, indices)

			# One skirt per edge whose neighbour is not in this ring. The four
			# edges are in the same order as the corners, so edge k runs from
			# corner k to corner k+1.
			var edges := [
				[p0, p1, 0, -step], [p1, p2, step, 0],
				[p2, p3, 0, step], [p3, p0, -step, 0],
			]
			var shaded := Color(color.r * SKIRT_SHADE, color.g * SKIRT_SHADE,
				color.b * SKIRT_SHADE, color.a)
			for e in edges:
				if _in_ring(bx0 + e[2], bz0 + e[3], step, inner, outer):
					continue
				_push_skirt(e[0], e[1], skirt_drop, shaded,
					verts, normals, colors, indices)


## Is the quad whose corner is (bx0, bz0) part of this ring?
func _in_ring(bx0: int, bz0: int, step: int, inner: float, outer: float) -> bool:
	var dx := float(bx0 + step / 2 - center.x)
	var dz := float(bz0 + step / 2 - center.y)
	var d_sq := dx * dx + dz * dz
	return d_sq >= inner * inner and d_sq < outer * outer


## A vertical curtain hanging from one edge, drawn BOTH WAYS ROUND.
##
## Two quads with opposite winding rather than one with the correct winding,
## and it is a deliberate choice rather than laziness. A skirt is needed at the
## outer edge of a ring, where "outside" faces away from the player, and at the
## inner edge against the voxel hole, where "outside" faces towards them. One
## rule cannot serve both, back faces are culled, and a skirt facing the wrong
## way is invisible - which looks exactly like the crack it was meant to cover
## and would be debugged as one. Doubling costs a few hundred quads out of a
## hundred thousand and cannot be wrong.
func _push_skirt(a: Vector3, b: Vector3, drop: float, color: Color,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var a_down := a - Vector3(0.0, drop, 0.0)
	var b_down := b - Vector3(0.0, drop, 0.0)
	_push_quad(a, b, b_down, a_down, color, verts, normals, colors, indices)
	_push_quad(a_down, b_down, b, a, color, verts, normals, colors, indices)


## Four corners in, one flat-shaded quad out. The normal is derived from the
## winding rather than passed in, so the identity the whole mesher rests on -
## (p1 - p0) x (p2 - p0) == -normal - holds by construction here instead of
## being something each caller has to remember.
func _push_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Color,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var normal := -((p1 - p0).cross(p2 - p0))
	if normal.length_squared() < 0.000001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()

	var first := verts.size()
	for p in [p0, p1, p2, p3]:
		verts.push_back(p)
		normals.push_back(normal)
		colors.push_back(color)
	indices.push_back(first)
	indices.push_back(first + 1)
	indices.push_back(first + 2)
	indices.push_back(first)
	indices.push_back(first + 2)
	indices.push_back(first + 3)
