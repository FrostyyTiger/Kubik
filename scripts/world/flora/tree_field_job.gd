class_name TreeFieldJob
extends RefCounted

## The tree field's contents, computed on a worker thread.
##
## Sibling of FarFieldJob, and the same shape for the same reasons: it captures
## what it needs at submit time, calls back into nothing, and returns packed
## arrays because MultiMesh belongs to the main thread.
##
##
## WHY THIS EXISTS AT ALL, AND WHY IT NOW EXISTS FOR EVERYTHING.
##
## It began as the impostor ring: real voxel trees stopped at the voxel radius
## and beyond it a forest became a flat dark-green slope, visibly ENDING at a
## circle centred on the player and moving when they did.
##
## Trees v3 deleted the block trees, so there is no inner edge left to start
## from and this walk is the only thing that draws a tree anywhere. The band
## structure survives unchanged - it is what makes a 600 m radius affordable -
## and its innermost band is now stride 1 at LOD0 from distance zero.
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

## WHICH LOD RUNG EACH BAND DRAWS A LIBRARY MESH AT. Trees v3 Stage 5, and
## open question 1, decided on the numbers rather than on taste.
##
## Stage 4 drew LOD0 in every band, deliberately, so its gate could be read
## with nothing hidden behind a downsample - and one species cost 606,484
## triangles where the whole cone ring had cost 17,700. All seven species at
## LOD0 everywhere is not a configuration this game can afford.
##
##     band          radius           stride   rung   voxel
##     0             0 -> 1.6 x r     1        LOD0   12.5 cm
##     1             1.6 r -> 400 m   2        LOD1   25 cm
##     2             400 -> 600 m     4        LOD2   50 cm
##     3             600 m -> fog     8        LOD2   50 cm
##
## THE NEAREST BAND IS STRIDE 1 AND LOD0 ALL THE WAY TO THE OLD SEAM, which
## answers the second half of open question 1: there is no nearer cut. That
## band covers 0 to 1.6 times the voxel radius - 154 m at High - and it is the
## band a player walks through, stands under and looks at. Every tree in it is
## the tree the artist drew, at 12.5 cm voxels, and the handover to the rung
## above happens well beyond where anyone can resolve a voxel.
##
## THE OUTER TWO BANDS SHARE LOD2 rather than adding a fourth rung. The tool
## bakes three, and band 3 is past 600 m where the fog is already 87% of the
## frame (distance v1 Stage 7's own note) - a rung nobody can see is a rung
## nobody should pay to bake, and the merged-lump step the plan records as the
## next move is what band 3 actually wants if the fog ever moves out.
const BAND_LOD := [0, 1, 2, 2]

## The heightmap the far mesh draws from, for the colour convergence below.
## Read-only here, and its pyramid is built on first use under its own mutex.
var heightmap: Heightmap = null

## The result: SLOT KEY -> PackedFloat32Array, 16 floats per instance.
##
## THE KEY IS A STRING NOW AND IT USED TO BE A SPECIES ID (trees v3 Stage 4).
## One species draws many library variants at several LOD rungs, and each
## (variant, rung) pair is its own mesh and therefore its own MultiMesh - so
## the key has to name both. Two forms, and they are told apart by their
## prefix rather than by a flag:
##
##     "c<species>"          a cone, the impostor this ring drew until tonight
##     "m<variant>|<lod>"    a library mesh at one rung
##
## A cone key is still one per species, so nothing about the old ring's cost
## or its draw-call count moves while both systems are alive.
var buffers := {}

## WITHIN THIS RADIUS, IN BLOCKS, A TREE GETS A TRUNK COLLIDER. 0 disables.
##
## The sim radius rather than the voxel radius, because a collider is a
## GAMEPLAY fact and the sim radius is where gameplay happens - it is the ring
## World already streams collidable ground into for every simulated peer.
var collider_blocks := 0.0

## HOST-OWNED SET OF FELLED TREES, keyed by placement cell, snapshotted at
## submit time. Trees v3 decision 8's seam, and NOTHING WRITES TO IT TONIGHT.
##
## It is threaded through anyway, and that is deliberate rather than
## speculative: chopping is fell-as-a-unit now (ruling 2), the one mutation
## path will be its only writer, and a removed-set added later would have to be
## threaded through this walk, `cover_column()` and the collider ring in one
## go. Threading it while both are being written costs three lines and proves
## the shape of the seam - the `_flora_removed` pattern, which flora already
## carries for exactly this reason.
var removed := {}

## Trunk colliders for the trees inside `collider_blocks`, for the main thread.
## Each is [Vector3 centre in metres, radius m, height m].
var colliders: Array = []

## Instances that are library models rather than cones, for the log line and
## for Stage 4's gate - which is "the instance count for this species equals
## its placement count".
var model_count := 0
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
		[1, -1.0, lod_sq, 1.0, BAND_LOD[0]],
		[2, lod_sq, lod2_sq, 2.0, BAND_LOD[1]],
		[4, lod2_sq, lod3_sq, 4.0, BAND_LOD[2]],
		[8, lod3_sq, outer_sq, 8.0, BAND_LOD[3]],
	]
	# Is anything drawn from the library at all? False in the public build and
	# false before Stage 4's slot list has anything in it, and when it is false
	# every line below behaves exactly as it did before trees v3.
	var any_models := TreeModels.available()

	for band in bands:
		var stride: int = band[0]
		var lo_sq: float = band[1]
		var hi_sq: float = minf(band[2], outer_sq)
		var spread: float = band[3]
		var lod_of_band: int = band[4]
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
				# THE INNER TEST MOVED BELOW decide() IN TREES V3 STAGE 4, and
				# that is the whole of "the walk extends inward to distance
				# zero". It still applies, unchanged, to every species the
				# block stamper still owns - a cone must not stand where a real
				# voxel tree has landed. It does NOT apply to a species drawn
				# from the library, because for those there is no voxel tree to
				# collide with: the field is the only thing that draws them, so
				# it has to draw them from the player's boots outward.
				#
				# It costs a placement decision for the candidates inside the
				# frontier that used to be rejected on two multiplies. At a 96 m
				# voxel radius against a 600 m ring that is about 2.5% more
				# area, and Stage 5's numbers are read with it in.
				var inside := d_sq < inner_here_sq
				if inside and not any_models:
					continue
				scanned += 1

				var found := TreePlacement.decide(generator, cx, cz, masks)
				if found.is_empty():
					continue
				# THE FELLED SET, checked once, here. A tree that has been cut
				# down is not drawn and does not collide, and both follow from
				# this one line rather than from two that could disagree.
				if not removed.is_empty() and removed.has(found["cell"]):
					continue

				var species: int = found["species"]
				var variant := &""
				if any_models and TreeTable.drawn_as_model(species, config):
					variant = TreeTable.variant_for(species, found["cell"],
						generator.world_seed, config)
				if variant == &"":
					# A cone, and the old rules apply to it in full.
					if inside:
						continue
				var key := "c%d" % species if variant == &"" \
					else "m%s|%d" % [variant, lod_of_band]
				if not by_species.has(key):
					by_species[key] = []
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
				# THE TRUNK COLLIDER, decided here because this is where the
				# variant is known and the sidecar's trunk dimensions hang off
				# it. Inside the sim radius only: a cylinder per tree over a
				# 600 m field would be sixty thousand shapes for a world nobody
				# is standing in.
				if variant != &"" and collider_blocks > 0.0 \
						and d_sq <= collider_blocks * collider_blocks:
					var trunk := TreeModels.trunk_of(variant)
					if trunk.x > 0.0 and trunk.y > 0.0:
						var foot := (float(found["ground"] + 1) + lift) \
							* config.block_size
						colliders.append([
							Vector3(float(found["bx"]) * config.block_size,
								foot + trunk.y * 0.5,
								float(found["bz"]) * config.block_size),
							trunk.x, trunk.y])
				by_species[key].append({
					"variant": variant,
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

	for key in by_species:
		buffers[key] = _pack(by_species[key], key)
		count += by_species[key].size()
		if String(key).begins_with("m"):
			model_count += by_species[key].size()
	elapsed_usec = Time.get_ticks_usec() - started


## The species id a cone key names, or -1 for a model key.
static func species_of_key(key: String) -> int:
	return int(key.substr(1)) if key.begins_with("c") else -1


## The variant and rung a model key names, or ["", 0].
static func model_of_key(key: String) -> Array:
	if not key.begins_with("m"):
		return ["", 0]
	var bits := key.substr(1).split("|")
	return [bits[0], int(bits[1]) if bits.size() > 1 else 0]


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


## PER-TREE COLOUR, distance v3 Stage 8, decision 6's "one light stage".
##
## An impostor is shade A of its species, flat, and after distance v1 Stage 6 it
## is shade A mixed some way toward its own hillside - so a forest at 600 m is
## thousands of copies of ONE green. Veloren ships real per-tree colour in
## thirteen bytes; ours is free, because every far tree already has a
## deterministic hash of its placement cell and the yaw is already drawn from
## it.
##
## THE SAME FORM AS Block.jitter() AND AS THE POSTER'S OWN GRAIN, deliberately:
## a symmetric value multiplier with a smaller hue tilt, red against blue, at
## the ratio Look's grain uses (grain_hue / grain_amount = 0.03 / 0.065). The
## far country's terrain grain and its forest grain are then the same effect
## with the same proportions, which is what stops a flecked hillside carrying a
## flat forest.
##
## THE AVERAGE IS PRESERVED, hard rule 6, and by construction rather than by
## hope: the multiplier is `1 + g` with `g` uniform on `[-a, a]`, so its
## expectation is exactly 1. It multiplies in WIRE space, which is where the
## MultiMesh instance colour acts, so the mean it preserves is the mean of the
## sRGB values - which is also what the fleck number measures. Measured in
## docs/status/distance-v3.md.
##
## ON ITS OWN SALT. The yaw already hashes this cell at salt 931, and a tree
## that was both darker and turned the same way as its neighbour would put a
## visible pattern in the wood.
const SALT_FAR_TREE_GRAIN := 941

## The poster grain's own hue-to-value ratio, so the two read as one effect.
const FAR_TREE_GRAIN_HUE_RATIO := 0.46


func _far_tree_grain(mul: Color, cell: Vector2i) -> Color:
	var amount: float = config.far_tree_grain
	if amount <= 0.0 or generator == null:
		return mul
	var g := (WorldHash.hash01(cell.x, cell.y, generator.world_seed,
		SALT_FAR_TREE_GRAIN) * 2.0 - 1.0) * amount
	var h := (WorldHash.hash01(cell.x, cell.y, generator.world_seed,
		SALT_FAR_TREE_GRAIN + 1) * 2.0 - 1.0) * amount * FAR_TREE_GRAIN_HUE_RATIO
	var v := 1.0 + g
	return Color(
		maxf(mul.r * v * (1.0 + h), 0.0),
		maxf(mul.g * v, 0.0),
		maxf(mul.b * v * (1.0 - h), 0.0), 1.0)


## THE SCALE JITTER'S SALT. New, in the 232+ range this epic was given, and
## clear of the SALT_CLUMP series `217 + key * 7919` (hard rule 2).
##
## ITS OWN SALT RATHER THAN THE YAW'S, for the reason every salt in this
## project has its own: a tree that was both turned further and grown taller
## than its neighbour would put a visible correlation in a stand, and the whole
## point of hashing two things separately is that they do not agree.
const SALT_TREE_SCALE := 233

## How much a library tree may differ from its authored size, either way.
##
## FIFTEEN PER CENT, which is the most that does not turn into a size RANGE.
## The block trees had one (`TreeSpecies` rolls height between the table's two
## numbers) and a model does not - it is exactly as tall as it was drawn - so
## this is what puts a stand of one variant back into a stand of trees rather
## than a row of copies. Bigger than this and a spruce and its neighbour read
## as two different species; smaller and it reads as nothing at all.
const MODEL_SCALE_JITTER := 0.15


func _pack(instances: Array, key: String) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(instances.size() * FLOATS_PER_INSTANCE)
	var species := species_of_key(key)
	# THE MESH'S OWN COLOUR, once per slot. For a cone that is shade A of its
	# species out of Block.COLORS; for a library mesh it is the variant's
	# dominant canopy colour through the palette table, which is decision 7's
	# new pin. Both are "what colour is this mesh already", which is what
	# _instance_color() has to divide by.
	var base_lin := FarTreeMeshes.color_of_species(species, config) \
		if species >= 0 else TreeModels.canopy_color(StringName(
			model_of_key(key)[0]))
	var base_wire := Look.to_wire(base_lin)
	var i := 0
	for inst in instances:
		var pos: Vector3 = inst["pos"]
		var fade: float = inst["fade"]
		var spread: float = inst["spread"]
		var cell0: Vector2i = inst["cell"]

		# A LIBRARY MESH IS ALREADY THE RIGHT SIZE, and that is ruling 3 in one
		# branch. A cone is a UNIT shape and the transform carries the tree's
		# height and crown; a model was authored at world size like a character,
		# so its transform carries only the jitter. Scaling a model by the
		# placement table's height would be scaling the artist's tree to fit a
		# number that describes a different tree.
		if inst["variant"] != &"":
			var j := 1.0 + (WorldHash.hash01(cell0.x, cell0.y,
				generator.world_seed, SALT_TREE_SCALE) * 2.0 - 1.0) \
				* MODEL_SCALE_JITTER
			# The fade still applies: it is what turns the handover at the
			# outer edge into an appearance rather than a pop, and a model
			# shrinking away into the fog needs it exactly as a cone did.
			var mbase := maxf(j * fade, 0.001)
			# THE BAND'S SPREAD APPLIES TO A MODEL EXACTLY AS IT DID TO A CONE,
			# and it has to. The outer bands walk one candidate cell in four,
			# sixteen and sixty-four; without widening what they DO draw, the
			# far forest would be sixty-four times sparser than the near one and
			# the treeline would thin out into nothing. The cone ring solved
			# this in distance v1 Stage 7 and the arithmetic is unchanged:
			# full width, and height by half a step per doubling, so the outer
			# band reads as a canopy rather than as a skyline of towers.
			var mxz := mbase * spread
			var msy := mbase * (1.0 + 0.15 * (log(spread) * INV_LN2))
			var myaw := WorldHash.hash01(cell0.x, cell0.y, 0, 931) * TAU
			var mc := cos(myaw) * mxz
			var msn := sin(myaw) * mxz
			buf[i] = mc;       buf[i + 1] = 0.0; buf[i + 2] = msn; buf[i + 3] = pos.x
			buf[i + 4] = 0.0;  buf[i + 5] = msy; buf[i + 6] = 0.0; buf[i + 7] = pos.y
			buf[i + 8] = -msn; buf[i + 9] = 0.0; buf[i + 10] = mc; buf[i + 11] = pos.z
			var mtint: Color = inst["tint"]
			var mmul := _far_tree_grain(
				_instance_color(base_lin, base_wire, mtint), cell0)
			buf[i + 12] = mmul.r; buf[i + 13] = mmul.g
			buf[i + 14] = mmul.b; buf[i + 15] = 1.0
			i += FLOATS_PER_INSTANCE
			continue
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
		var mul := _far_tree_grain(_instance_color(base_lin, base_wire, tint), cell)
		buf[i + 12] = mul.r; buf[i + 13] = mul.g
		buf[i + 14] = mul.b; buf[i + 15] = 1.0
		i += FLOATS_PER_INSTANCE
	return buf
