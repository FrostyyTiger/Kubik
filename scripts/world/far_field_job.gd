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

## How far past fog_end to build, as a multiple. Fog hides everything at
## fog_end; a little beyond means the mesh's own edge is never the thing you
## notice first.
const FOG_MARGIN := 1.2

var heightmap: Heightmap = null
var generator: TerrainGenerator = null
var config: WorldgenConfig = null

## Block position the disc is centred on.
var center := Vector2i.ZERO

var arrays: Array = []
var vertex_count := 0


func run() -> void:
	var step: int = config.far_step
	var far_radius := config.fog_end_m / config.block_size * FOG_MARGIN
	var radius_cells := int(far_radius / float(step))
	var radius_sq := float(radius_cells * radius_cells)

	# Where the voxels take over. Quads well inside this are skipped - the
	# voxel terrain is drawn there instead, and drawing both is overdraw.
	# The margin means the two OVERLAP by two cells rather than meeting
	# exactly: a small overlap is hidden by the voxels, whereas a small gap is
	# a hole you can see the sky through.
	var voxel_radius_blocks: float = float(config.voxel_radius_chunks * Chunk.SIZE)
	var exclude := voxel_radius_blocks - float(2 * step)
	var exclude_sq := exclude * exclude

	# The far mesh is the COARSE heightmap; the voxels are that plus per-block
	# detail, so at the boundary the two differ by up to detail_amp. Dropping
	# the far mesh by half of that keeps it under the voxel surface through the
	# overlap instead of poking up through it.
	var y_offset := -0.5 * config.detail_amp * config.block_size

	# Snap the centre to the grid, so the mesh does not shimmer as it is
	# rebuilt - the vertices land on the same world positions every time.
	var cx := int(floor(float(center.x) / float(step))) * step
	var cz := int(floor(float(center.y) / float(step))) * step

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var bs: float = config.block_size

	for j in range(-radius_cells, radius_cells):
		for i in range(-radius_cells, radius_cells):
			if float(i * i + j * j) > radius_sq:
				continue

			var bx0 := cx + i * step
			var bz0 := cz + j * step
			var bx1 := bx0 + step
			var bz1 := bz0 + step

			# Distance of the quad centre from the player, in blocks.
			var dx := float(bx0 + step / 2 - center.x)
			var dz := float(bz0 + step / 2 - center.y)
			if dx * dx + dz * dz < exclude_sq:
				continue
			if not heightmap.in_bounds(bx0, bz0):
				continue

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

			# One normal for the whole quad: flat shading, matching the voxels.
			# Negated because the winding satisfies (p1-p0)x(p2-p0) == -normal.
			var normal := -((p1 - p0).cross(p2 - p0))
			if normal.length_squared() < 0.000001:
				normal = Vector3.UP
			else:
				normal = normal.normalized()

			# Colour from the same zone rules the voxels use, sampled at the
			# quad's middle. Anything else and the treeline would be in a
			# different place near and far.
			var mid_h := (h00 + h10 + h11 + h01) * 0.25
			var zone := generator.surface_zone_at(
				bx0 + step / 2, bz0 + step / 2, mid_h)
			var color := Block.color_of(TerrainGenerator.ZONE_SURFACE[zone])

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
