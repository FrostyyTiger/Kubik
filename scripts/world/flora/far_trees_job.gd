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

## And how far in from the OUTER edge they fade back down. Distance v1 Stage 7.
## 0 disables it.
var outer_fade_blocks := 0.0

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
##
## TWO STEPS SINCE DISTANCE V1 STAGE 7, because the ring now runs to the fog
## rather than to half of it and a second step is what keeps that affordable:
##
##     band                          cells kept   drawn width
##     seam to lod_blocks            all          1x
##     lod_blocks to lod2_blocks     1 in 4       2x
##     lod2_blocks to lod3_blocks    1 in 16      4x
##     lod3_blocks to the fog        1 in 64      8x
##
## At High the radius goes 400 -> 800 m, which is FOUR TIMES the candidate
## cells at a constant rate. The ramp brings that back to about 1.35x the old
## ring, so the count grows with the radius rather than with its square.
##
## THE PLAN ASKED FOR THREE BANDS AND THIS IS FOUR, and the fourth was bought
## by measurement rather than by taste. Three bands (1 in 16 all the way to the
## fog) measured 767 ms against Stage 6's 505 - 1.52x, against a gate of 1.25x
## - and the stream probe's chunks/s on the return leg fell from 82.2 to 74.8,
## which is hard rule 6 and is not negotiable. The fourth band takes the last
## 200 m, where the fog is already 87% of the frame and a clump eight cells
## wide is a shape nobody can resolve. See docs/status/distance-v1.md, Stage 7.
var lod_blocks := 0.0
var lod2_blocks := 0.0
var lod3_blocks := 0.0

## The heightmap the far mesh draws from, for the colour convergence below.
## Read-only here, and its pyramid is built on first use under its own mutex.
var heightmap: Heightmap = null

## The result: species id -> PackedFloat32Array, 16 floats per instance.
var buffers := {}
var count := 0
var elapsed_usec := 0

const FLOATS_PER_INSTANCE := 16

const INV_LN2 := 1.4426950408889634

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
	if _tint_on() or _terrace_on():
		heightmap.build_pyramid()
	if _tint_on():
		_band_treeline = FarFieldJob.treeline_band(generator, config)

	var inner_sq := inner_blocks * inner_blocks
	var outer_sq := outer_blocks * outer_blocks
	var lod_sq := lod_blocks * lod_blocks if lod_blocks > 0.0 else INF
	var lod2_sq := lod2_blocks * lod2_blocks if lod2_blocks > 0.0 else INF
	var lod3_sq := lod3_blocks * lod3_blocks if lod3_blocks > 0.0 else INF

	# ONE PASS PER BAND, EACH STEPPING AT ITS OWN STRIDE - distance v1 Stage 7,
	# and this is what actually pays for the ring reaching the fog.
	#
	# Until Stage 7 there was one pass over the whole square at stride 1, and
	# the LOD was a parity test INSIDE it. That keeps the placement decisions
	# down but not the loop: doubling the radius still quadruples the number of
	# cells visited, and at High the loop alone was 160,000 iterations to keep
	# about 12,000 of them. Walking the coarse bands on the coarse lattice in
	# the first place brings the visited count to about 26,000 for the same
	# output, which is what turns "grows with the square of the radius" into
	# "grows with the radius" - the claim the plan makes for this stage.
	#
	# WHICH CELLS SURVIVE IS UNCHANGED, and that matters more than the speed:
	# the bands are the same radii, the strides are the same lattices the
	# parity test picked (cx & 1, cx & 3), and the radius tests are the same
	# comparisons in the same order. This is the same scan, walked in a better
	# order.
	var bands := [
		# The innermost band's floor is BELOW zero, not at it: the old single
		# pass tested `d_sq > lod_sq` for the band above, so a cell exactly on
		# the centre belonged to band 1. It is always inside the frontier and
		# never survives, but the two scans agreeing on it is what makes "the
		# same scan, walked in a better order" checkable rather than believed.
		[1, -1.0, lod_sq, 1.0],
		[2, lod_sq, lod2_sq, 2.0],
		[4, lod2_sq, lod3_sq, 4.0],
		[8, lod3_sq, outer_sq, 8.0],
	]
	for band in bands:
		var stride: int = band[0]
		var lo_sq: float = band[1]
		var hi_sq: float = minf(band[2], outer_sq)
		var spread: float = band[3]
		if lo_sq >= outer_sq:
			continue
		var reach := int(ceil(minf(sqrt(hi_sq), outer_blocks)))
		var c0x := Chunk.floor_div(center.x - reach, cell)
		var c1x := Chunk.floor_div(center.x + reach, cell)
		var c0z := Chunk.floor_div(center.y - reach, cell)
		var c1z := Chunk.floor_div(center.y + reach, cell)
		# Align the start DOWN to the stride's own lattice, so every cell this
		# pass visits satisfies (cx & (stride - 1)) == 0 - which is exactly the
		# set the parity test used to keep. Aligning down rather than up means
		# the lattice is anchored to the world's origin and not to where the
		# scan happened to start, which is the property that stops the far
		# forest reshuffling itself around a walking player.
		c0x -= c0x & (stride - 1)
		c0z -= c0z & (stride - 1)
		for cz in range(c0z, c1z + 1, stride):
			for cx in range(c0x, c1x + 1, stride):
				# THE ANNULUS TEST FIRST, on the cell's own coordinates, before
				# decide() is asked anything. It is two multiplies against the
				# thousands of heightmap lookups and noise samples a placement
				# decision costs, and it throws away the corners of the scanned
				# square - which is a quarter of it.
				var dx := float(cx * cell - center.x)
				var dz := float(cz * cell - center.y)
				var d_sq := dx * dx + dz * dz
				if d_sq > hi_sq or d_sq <= lo_sq:
					continue
				# THE INNER EDGE IS PER SECTOR (world feel v1 Stage 3): a
				# candidate is skipped only where the real tree that would
				# replace it has actually landed.
				var inner_here_sq := inner_sq
				if not frontier.is_empty():
					var s := World.frontier_sector_of(
						int(cx * cell - center.x), int(cz * cell - center.y))
					var f := float(frontier[s] * Chunk.SIZE)
					inner_here_sq = f * f
				if d_sq < inner_here_sq:
					continue
				scanned += 1

				var found := TreePlacement.decide(generator, cx, cz, masks)
				if found.is_empty():
					continue

				var species: int = found["species"]
				if not by_species.has(species):
					by_species[species] = []
				var d := sqrt(d_sq)
				# THE FOOTING, distance v2 Stage 5. The hillside this impostor
				# stands on has shelves now, so its base has to sit on the SHELF
				# TOP or half the far forest sinks into a riser.
				#
				# terrace_offset() returns how far the terrace MOVED the ground
				# here rather than where the shelf is, and that is what keeps this
				# exact at far_terrace 0. A tree stands on `ground + 1`, the TRUE
				# voxel surface, while the far mesh draws the FILTERED one - at a
				# summit the two differ by tens of blocks, which is PEAK LOSS.
				# Snapping the tree to the shelf outright would move every far tree
				# by that difference at every value of the knob, zero included.
				# Adding the offset moves it by exactly what the ground under it
				# moved, and by nothing at 0. Paid per PLACED tree, like the tint.
				var lift := 0.0
				if _terrace_on():
					lift = FarFieldJob.terrace_offset(heightmap, config,
						found["bx"], found["bz"], d * config.block_size)
				by_species[species].append({
					"spread": spread,
					"pos": Vector3(
						float(found["bx"]) * config.block_size,
						(float(found["ground"] + 1) + lift) * config.block_size,
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
## AND THE MIRROR OF IT AT THE OUTER EDGE, distance v1 Stage 7. Without it the
## forest ENDS AT A CIRCLE, which is the same artefact the inner fade exists to
## remove and the same one the whole ring exists to remove - it is just centred
## on the player at a bigger radius. Trees shrink away into the fog instead.
func _fade_at(distance: float) -> float:
	var f := 1.0
	if fade_blocks > 0.0:
		f = clampf((distance - inner_blocks) / fade_blocks, 0.0, 1.0)
	if outer_fade_blocks > 0.0:
		f = minf(f, clampf((outer_blocks - distance) / outer_fade_blocks,
			0.0, 1.0))
	return f


## Is the colour convergence on at all? At far_tree_tint 0 the ring costs
## exactly what it cost before Stage 6 - no pyramid, no extra lookups - and the
## impostors are flat species colour, which is the old behaviour bit for bit.
func _tint_on() -> bool:
	return config.far_tree_tint > 0.0 and heightmap != null and generator != null


## Is the terrace on at all? At far_terrace 0 the ring costs exactly what it
## cost before distance v2 - no pyramid, no extra lookups - and every impostor
## stands where it stood, which is hard rule 1 on this side of the epic.
func _terrace_on() -> bool:
	return config.far_terrace > 0.0 and heightmap != null


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
		# Height barely grows with the LOD: 1.00, 1.15, 1.30 for widths of 1,
		# 2 and 4. Half a step per doubling, so the outer band's clumps are a
		# canopy rather than a skyline of towers.
		var sy: float = maxf(inst["height"], 0.001) * fade \
			* (1.0 + 0.15 * (log(spread) * INV_LN2))
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
