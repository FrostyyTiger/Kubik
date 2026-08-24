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

## The result: species id -> PackedFloat32Array, 16 floats per instance.
var buffers := {}
var count := 0
var elapsed_usec := 0

const FLOATS_PER_INSTANCE := 16

## Candidate cells scanned, for the log line. A ring 300 m across is a lot of
## them and it is worth knowing how many when the rebuild time is read.
var scanned := 0


func run() -> void:
	var started := Time.get_ticks_usec()
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		elapsed_usec = Time.get_ticks_usec() - started
		return

	var masks := TreePlacement.masks_for(generator)
	var by_species := {}

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
			if d_sq < inner_sq or d_sq > outer_sq:
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
			by_species[species].append({
				"spread": spread,
				"pos": Vector3(
					float(found["bx"]) * config.block_size,
					float(found["ground"] + 1) * config.block_size,
					float(found["bz"]) * config.block_size),
				"height": float(found["params"]["height"]) * config.block_size,
				"crown": float(found["params"]["crown"]) * config.block_size,
				"fade": _fade_at(sqrt(d_sq)),
				"cell": found["cell"],
			})

	for species in by_species:
		buffers[species] = _pack(by_species[species])
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


func _pack(instances: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(instances.size() * FLOATS_PER_INSTANCE)
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
		buf[i + 12] = 1.0; buf[i + 13] = 1.0
		buf[i + 14] = 1.0; buf[i + 15] = 1.0
		i += FLOATS_PER_INSTANCE
	return buf
