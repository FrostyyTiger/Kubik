class_name FarTreesJob
extends RefCounted

## The impostor ring's contents, computed on a worker thread.
##
## Sibling of FarFieldJob, and the same shape for the same reasons: it captures
## what it needs at submit time, calls back into nothing, and returns packed
## arrays because MultiMesh belongs to the main thread.
##
##
## WHY THIS EXISTS AT ALL.
##
## Real voxel trees stop at the voxel radius - 96 m at High. Beyond that the
## far field draws the coarse heightmap coloured by zone, so a forest becomes a
## flat dark-green slope. Nobody noticed that under thick fog and with 35,000
## evenly scattered cones; with the forest Stage 4 built it is the first thing
## you see from a meadow, because the forest visibly STOPS at a circle centred
## on the player and moves when they do.
##
##
## THE SAME CANDIDATES, THE SAME HASH.
##
## This does not scatter its own trees. It walks the identical candidate
## lattice TreePlacement.decide() walks, so an impostor stands exactly where
## the voxel tree will stand when the player gets there, is the same species,
## and is the same height. Walking towards a forest therefore does not
## rearrange it - which is the entire difference between distant trees and
## distant tree-coloured noise.

## Where the ring is centred, in blocks.
var center := Vector2i.ZERO

## Pure and read-only once its heightmap is built.
var generator: TerrainGenerator = null
var config: WorldgenConfig = null

## Inner and outer radius of the ring, in blocks.
var inner_blocks := 0.0

## Per-sector radius in CHUNKS out to which the real trees have landed. A
## candidate inside its own sector's frontier is covered by a real tree and is
## skipped; one outside it is not, whatever the nominal radius says.
var frontier := PackedInt32Array()
var outer_blocks := 0.0

## How far in from the inner edge impostors fade up to full size, in blocks.
## 0 disables the fade.
var fade_blocks := 0.0

## Beyond this radius, only every second candidate cell on each axis is
## considered - a quarter of them - and each impostor is drawn twice as wide to
## keep the canopy covering the same ground.
##
## WHY THERE IS AN LOD HERE AT ALL, and it is a measurement rather than a
## preference. The full ring at High is 63,000 candidate cells, and a placement
## decision is several noise samples and a heightmap lookup - about 500 ms of
## worker time per rebuild, measured. That would be fine if workers were free,
## but this engine build SERIALISES GDScript across threads (see the note on
## World._max_jobs_in_flight, which has the measurements), so half a second of
## ring is half a second of chunk generation not happening. At sprint the ring
## rebuilds every 1.2 s, and it would have taken forty per cent of everything.
##
## The near band stays exact, and it is the one that matters: it covers the
## handover to real voxel trees, so a tree you walk up to is still the tree you
## saw. Past it a quarter of the trees are drawn at twice the width, which at
## 160 m and beyond is a clump rather than a tree in any case.
##
## Recorded in STATUS.md as a departure from "iterates the same tree
## candidates".
var lod_blocks := 0.0

## The heightmap the far mesh draws from, for the colour convergence below.
## Read-only here, and its pyramid is built on first use under its own mutex.
var heightmap: Heightmap = null

## The result: species id -> PackedFloat32Array, 16 floats per instance.
var buffers := {}
var count := 0
var elapsed_usec := 0

const FLOATS_PER_INSTANCE := 16

## Candidate cells scanned, for the log line. A ring 300 m across is a lot of
## them and it is worth knowing how many when the rebuild time is read.
var scanned := 0

## The altitude band the treeline falls in, read once per job from the same
## place FarFieldJob reads it. Only meaningful when the tint is on.
var _band_treeline := 0


func run() -> void:
	var started := Time.get_ticks_usec()
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		elapsed_usec = Time.get_ticks_usec() - started
		return

	var masks := TreePlacement.masks_for(generator)
	var by_species := {}
	# THE BACKDROP THE TREES CONVERGE TOWARDS, distance v1 Stage 6. Idempotent
	# and behind the heightmap's own mutex, so in practice FarFieldJob has
	# already paid for it - but the ring must not depend on which of the two
	# workers happened to run first.
	if _tint_on():
		heightmap.build_pyramid()
		_band_treeline = FarFieldJob.treeline_band(generator, config)

	var outer := int(ceil(outer_blocks))
	var c0x := Chunk.floor_div(center.x - outer, cell)
	var c1x := Chunk.floor_div(center.x + outer, cell)
	var c0z := Chunk.floor_div(center.y - outer, cell)
	var c1z := Chunk.floor_div(center.y + outer, cell)

	var inner_sq := inner_blocks * inner_blocks
	var outer_sq := outer_blocks * outer_blocks
	var lod_sq := lod_blocks * lod_blocks if lod_blocks > 0.0 else INF

	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			# THE ANNULUS TEST FIRST, on the cell's own coordinates, before
			# decide() is asked anything. It is two multiplies against the
			# thousands of heightmap lookups and noise samples a placement
			# decision costs, and it throws away the corners of the scanned
			# square - which is a quarter of it.
			var dx := float(cx * cell - center.x)
			var dz := float(cz * cell - center.y)
			var d_sq := dx * dx + dz * dz
			if d_sq > outer_sq:
				continue
			# THE INNER EDGE IS PER SECTOR (world feel v1 Stage 3): a candidate
			# is skipped only where the real tree that would replace it has
			# actually landed.
			var inner_here_sq := inner_sq
			if not frontier.is_empty():
				var s := World.frontier_sector_of(
					int(cx * cell - center.x), int(cz * cell - center.y))
				var f := float(frontier[s] * Chunk.SIZE)
				inner_here_sq = f * f
			if d_sq < inner_here_sq:
				continue
			# The LOD. Skipping on the cell's own parity rather than on a
			# counter means which trees survive does not depend on where the
			# scan started, so the far forest does not reshuffle itself every
			# time the ring is rebuilt around a walking player.
			var spread := 1.0
			if d_sq > lod_sq:
				if (cx & 1) != 0 or (cz & 1) != 0:
					continue
				spread = 2.0
			scanned += 1

			var found := TreePlacement.decide(generator, cx, cz, masks)
			if found.is_empty():
				continue

			var species: int = found["species"]
			if not by_species.has(species):
				by_species[species] = []
			var d := sqrt(d_sq)
			by_species[species].append({
				"spread": spread,
				"pos": Vector3(
					float(found["bx"]) * config.block_size,
					float(found["ground"] + 1) * config.block_size,
					float(found["bz"]) * config.block_size),
				"height": float(found["params"]["height"]) * config.block_size,
				"crown": float(found["params"]["crown"]) * config.block_size,
				"fade": _fade_at(d),
				"cell": found["cell"],
				# Paid per PLACED tree, not per candidate: a few thousand
				# pyramid reads against sixty thousand placement decisions.
				"tint": _tint_at(found["bx"], found["bz"], d),
			})

	for species in by_species:
		buffers[species] = _pack(by_species[species], species)
		count += by_species[species].size()
	elapsed_usec = Time.get_ticks_usec() - started


## Scale multiplier at this distance from the centre.
##
## THE HANDOVER IS THE ONLY PLACE A POP CAN HAPPEN. Just inside the inner
## radius a tree is drawn as real voxels; just outside it as a six-triangle
## cone. The two do not look identical however carefully the cone is shaped, so
## walking outward there is a visible substitution at a fixed distance from the
## player - which reads as the world changing rather than as the player moving.
##
## Growing the impostor from nothing over the first stretch of the ring turns
## that substitution into an appearance, which the eye forgives: a tree that
## fades up as it recedes looks like distance, and a tree that snaps looks like
## a bug.
func _fade_at(distance: float) -> float:
	if fade_blocks <= 0.0:
		return 1.0
	return clampf((distance - inner_blocks) / fade_blocks, 0.0, 1.0)


## Is the colour convergence on at all? At far_tree_tint 0 the ring costs
## exactly what it cost before Stage 6 - no pyramid, no extra lookups - and the
## impostors are flat species colour, which is the old behaviour bit for bit.
func _tint_on() -> bool:
	return config.far_tree_tint > 0.0 and heightmap != null and generator != null


## THE COLOUR THIS IMPOSTOR CONVERGES TOWARDS, AND HOW FAR, distance v1
## Stage 6.
##
## Returns the far mesh's own backdrop colour at the tree's position - LINEAR,
## in rgb - with the mix factor in ALPHA. One value rather than two dictionary
## keys because the alpha channel is sitting there unused and this is the inner
## loop of a job whose whole cost model is "how much work per tree".
##
## THE RAMP IS AGAINST THE FOG, NOT AGAINST THE RING'S OWN OUTER EDGE. A tree
## at 300 m must be tinted the same amount whatever the ring's radius happens
## to be, or Stage 7 - which takes the ring from 400 m to the fog - would
## silently retint every tree already on screen. 0 at the voxel edge, and
## far_tree_tint at fog end.
func _tint_at(bx: int, bz: int, d_blocks: float) -> Color:
	if not _tint_on():
		return Color(0.0, 0.0, 0.0, 0.0)
	var bs: float = config.block_size
	var inner_m := inner_blocks * bs
	var span := maxf(config.fog_end_m - inner_m, 1.0)
	var t: float = config.far_tree_tint \
		* clampf((d_blocks * bs - inner_m) / span, 0.0, 1.0)
	if t <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var c := FarFieldJob.backdrop_color(heightmap, generator, config,
		bx, bz, d_blocks * bs, _band_treeline)
	return Color(c.r, c.g, c.b, t)


## THE INSTANCE COLOUR IS A MULTIPLIER, NOT A COLOUR, and that is the whole
## reason this function is more than a lerp.
##
## The renderer multiplies a MultiMesh instance colour into the mesh's own
## vertex colour - which is why the buffer has been full of white since the
## ring was built, white being the identity. So "mix this cone half way to its
## hillside" has to be expressed as "what do you multiply the cone's colour by
## to land on the mixture", and both sides of that division live in WIRE space
## (sRGB), because the multiply happens after Look.to_wire() has already been
## applied to the mesh and before the shader decodes.
##
## The mix itself is in LINEAR, which is the project's one rule about colour
## arithmetic: linear maths, sRGB on the wire.
##
## A dome's TRUNK is multiplied by the same ratio as its crown, because there
## is one instance colour per tree and the mesh carries two. That is the right
## approximation: the ratio is "how far towards the hillside", and a trunk at
## 500 m that recedes with its own crown is better than one that does not.
func _instance_color(base_lin: Color, base_wire: Color, tint: Color) -> Color:
	var t := tint.a
	if t <= 0.0:
		return Color(1.0, 1.0, 1.0, 1.0)
	var mixed := Look.to_wire(
		base_lin.lerp(Color(tint.r, tint.g, tint.b, 1.0), t))
	# The floor is a guard, not a tuning value: a palette entry with a channel
	# at zero would otherwise divide by zero, and no Block colour is that dark.
	return Color(
		clampf(mixed.r / maxf(base_wire.r, 0.002), 0.0, 4.0),
		clampf(mixed.g / maxf(base_wire.g, 0.002), 0.0, 4.0),
		clampf(mixed.b / maxf(base_wire.b, 0.002), 0.0, 4.0), 1.0)


func _pack(instances: Array, species: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(instances.size() * FLOATS_PER_INSTANCE)
	# The mesh's own colour, once per species. See _instance_color().
	var base_lin := FarTreeMeshes.color_of_species(species, config)
	var base_wire := Look.to_wire(base_lin)
	var i := 0
	for inst in instances:
		var pos: Vector3 = inst["pos"]
		var fade: float = inst["fade"]
		# The impostor mesh is a UNIT shape - one metre tall, half a metre
		# across - so the transform carries the tree's real size. That is what
		# lets one mesh serve every spruce in the world at every height it can
		# grow to, which is the whole point of a MultiMesh.
		var spread: float = inst["spread"]
		# Height barely grows with the LOD. A quarter of the trees drawn four
		# times as tall would be a skyline of towers; drawn twice as wide they
		# are a canopy with the same coverage, which is what a forest is at
		# that distance.
		var sy: float = maxf(inst["height"], 0.001) * fade \
			* (1.0 if spread <= 1.0 else 1.15)
		var sxz: float = maxf(inst["crown"] * 2.0, 0.5) * fade * spread
		# Yaw hashed from the cell, so a stand of impostors is not a row of
		# identically-oriented cones. Costs nothing: the transform is being
		# built either way.
		var cell: Vector2i = inst["cell"]
		var yaw := WorldHash.hash01(cell.x, cell.y, 0, 931) * TAU
		var c := cos(yaw) * sxz
		var s := sin(yaw) * sxz

		buf[i] = c;       buf[i + 1] = 0.0; buf[i + 2] = s;   buf[i + 3] = pos.x
		buf[i + 4] = 0.0; buf[i + 5] = sy;  buf[i + 6] = 0.0; buf[i + 7] = pos.y
		buf[i + 8] = -s;  buf[i + 9] = 0.0; buf[i + 10] = c;  buf[i + 11] = pos.z
		var tint: Color = inst["tint"]
		var mul := _instance_color(base_lin, base_wire, tint)
		buf[i + 12] = mul.r; buf[i + 13] = mul.g
		buf[i + 14] = mul.b; buf[i + 15] = 1.0
		i += FLOATS_PER_INSTANCE
	return buf
