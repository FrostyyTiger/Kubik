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
## from and this walk is the only thing that draws a tree anywhere. Trees v4
## then deleted the band STRIDES too: this walks every candidate at every
## distance and changes only the rung it draws them at, because a model that
## halves in width as you approach reads as the world rearranging itself.
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

## How far in from the OUTER edge they fade back down. Distance v1 Stage 7.
## 0 disables it.
var outer_fade_blocks := 0.0

## THE RUNG BOUNDARIES, in blocks. Distance decides which of the four rungs a
## tree is drawn at, and since trees v4 that is ALL it decides.
##
## WHAT THESE USED TO BE. Each boundary also started a coarser candidate
## lattice - stride 2, 4 and 8 - and the survivors were widened 2x, 4x and 8x
## to cover the cells that were skipped. That bought a 800 m ring for the cost
## of a 400 m one, and it was the right trade while a far tree was a
## six-triangle cone: nobody can say how many cones a hillside should have.
##
## AGAINST A MODEL LIBRARY IT WAS WRONG, and it is what Marcel saw. Walking in,
## a tree crossed a boundary, halved in width, and fifteen neighbours appeared
## where there had been nothing. Because the boundaries are measured from a
## ring centre that jumps `far_tree_step_m` at a time, it happened to a whole
## annulus in one frame rather than tree by tree.
##
##     band     radius             rung   voxel     triangles (mean)
##     0        0 -> 1.6 x r       LOD0   12.5 cm   5801
##     1        1.6 r -> 400 m     LOD1   25 cm     2002
##     2        400 -> 600 m       LOD2   50 cm      822
##     3        600 m -> the fog   PROXY  -           16
##
## THE PROXY RUNG IS WHAT MADE FULL DENSITY AFFORDABLE. The baked ladder only
## falls sevenfold from LOD0 to LOD2, which is nowhere near enough to carry
## every tree to the fog; the 16-triangle lump falls 360-fold and does. See
## `TreeModels.PROXY_LOD`.
var lod_blocks := 0.0
var lod2_blocks := 0.0
var lod3_blocks := 0.0

## Which rung each distance band draws. Trees v4 gives the outermost band the
## proxy rung instead of repeating LOD2, which is what lets every tree be drawn
## rather than one in sixty-four.
const BAND_LOD := [0, 1, 2, TreeModels.PROXY_LOD]

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
##     "m<variant>|<lod>"    a library mesh at one rung
##
## THE `c<species>` FORM IS GONE (Stage 7). It named a cone, and there are no
## cones - the prefix is kept on the surviving form so a stored key from an
## older build cannot be mistaken for a variant name.
var buffers := {}

## WITHIN THIS RADIUS, IN BLOCKS, A TREE GETS A TRUNK COLLIDER. 0 disables.
##
## The sim radius rather than the voxel radius, because a collider is a
## GAMEPLAY fact and the sim radius is where gameplay happens - it is the ring
## World already streams collidable ground into for every simulated peer.
var collider_blocks := 0.0

## The placement memo, owned by TreeField and shared across rebuilds. See where
## it is used in run(). Null means "no memo", which is what the self-test and
## the probes use so that each of their runs is independent.
var cache = null

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
	# `_band_treeline` stays at 0: the altitude bands it indexed left with the
	# far field's paint in light v1 Stage 3, and backdrop_color no longer reads
	# it. Kept as a parameter so the call shape does not churn.

	var inner_sq := inner_blocks * inner_blocks
	var outer_sq := outer_blocks * outer_blocks
	var lod_sq := lod_blocks * lod_blocks if lod_blocks > 0.0 else INF
	var lod2_sq := lod2_blocks * lod2_blocks if lod2_blocks > 0.0 else INF
	var lod3_sq := lod3_blocks * lod3_blocks if lod3_blocks > 0.0 else INF

	# ONE PASS, EVERY TREE, AND THE RUNG IS THE ONLY THING DISTANCE CHANGES -
	# trees v4 decision 1. This replaces distance v1 Stage 7's four passes at
	# strides 1, 2, 4 and 8.
	#
	# WHAT THE STRIDES WERE FOR. A stride-8 band drew one candidate in
	# sixty-four and widened it eightfold to cover the ones it skipped, which
	# is Distant Horizons applied to a model library. It worked for cones,
	# because a cone is an abstraction and nobody can say how many cones a
	# hillside ought to have. It does not work for MODELS: walking toward a
	# stand, a tree halved in width at every band edge while its neighbours
	# appeared out of nothing, and both happened to a whole annulus at once
	# because the band radii are measured from a ring centre that only moves
	# in `far_tree_step_m` jumps. Marcel reported it as "a different tree
	# spawns when I get closer" and as the distance changing while he walked,
	# and it is one mechanism behind both.
	#
	# WHAT PAYS FOR DROPPING IT is `TreeModels.PROXY_LOD` - a 16-triangle rung
	# where the baked ladder stopped at 822. Every tree in the ring is now
	# drawn at its own place at its own size, and only its rung changes with
	# distance. And a coarser CANDIDATE LATTICE pays for the scan: trees v4
	# took `tree_cell_blocks` from 8 to 24 because crown spacing rejects most
	# of what a 4 m lattice offers anyway, so the cells this loop visits fell
	# by nine while the trees it keeps did not.
	var lod_bounds := [lod_sq, lod2_sq, lod3_sq]
	# Is anything drawn from the library at all? False in the public build and
	# false before Stage 4's slot list has anything in it, and when it is false
	# every line below behaves exactly as it did before trees v3.
	var any_models := TreeModels.available()

	# ONE RAW DECISION PER CELL, AND IT OUTLIVES THIS JOB.
	#
	# Crown spacing asks every accepted tree's neighbours whether they grew
	# anything - about fifty questions per tree - so without a memo the same
	# cell is decided from scratch by each of its fifty neighbours in turn:
	# 4.6 SECONDS of ring against 2.6 with it.
	#
	# AND THE RING MOVES 24 m INTO A 800 m WALK, so about 94% of the cells it
	# visits are the ones it visited last time and the answers cannot have
	# changed - placement is a pure function of (seed, cell). `TreeField` owns
	# the dictionary and hands the same one to every job, which is what makes a
	# REBUILD cheap rather than just a first build.
	var place_cache = cache if cache != null else {}

	# The one band left is the whole ring, and `spread` stays at 1: nothing is
	# stretched to stand in for anything any more.
	var lo_sq := -1.0
	var hi_sq := outer_sq
	var spread := 1.0
	var reach := int(ceil(outer_blocks))
	var c0x := Chunk.floor_div(center.x - reach, cell)
	var c1x := Chunk.floor_div(center.x + reach, cell)
	var c0z := Chunk.floor_div(center.y - reach, cell)
	var c1z := Chunk.floor_div(center.y + reach, cell)
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
			if d_sq > hi_sq or d_sq <= lo_sq:
				continue
			# THE RUNG, PER TREE, FROM ITS OWN DISTANCE. The only thing
			# distance decides any more.
			var lod_of_band := 0
			while lod_of_band < 3 and d_sq > float(lod_bounds[lod_of_band]):
				lod_of_band += 1
			lod_of_band = int(BAND_LOD[lod_of_band])
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
			# THE INNER TEST IS DEAD AND ITS RADIUS IS NOT.
			#
			# `inner_here_sq` was where the real voxel trees began, and a
			# cone must not stand where one had landed. There are no voxel
			# trees: the field draws every tree in the game, from distance
			# zero outward, and there is nothing for it to collide with.
			# The frontier is still READ, because `TreeField` still hands
			# it over and a future rung (the merged lump the plan records)
			# will want it.
			scanned += 1

			var found := TreePlacement.decide(generator, cx, cz, masks,
				place_cache)
			if found.is_empty():
				continue
			# THE FELLED SET, checked once, here. A tree that has been cut
			# down is not drawn and does not collide, and both follow from
			# this one line rather than from two that could disagree.
			if not removed.is_empty() and removed.has(found["cell"]):
				continue

			var species: int = found["species"]
			# NO VARIANT, NO TREE. That is three different situations with
			# one answer: the public build has no library mounted, a
			# species could have every weight in its row parked at 0, and
			# a species could be missing a row altogether. In all three the
			# field draws nothing there and the world is treeless in that
			# spot, which is ruling 6 - the public build ships treeless and
			# that is the design, not a fallback.
			# THE SNOW BIAS, and it is ALTITUDE rather than a knob: how far
			# this tree stands up its own zone's band toward the treeline.
			# 0 in the valley, 1 at the top, so a snow-dusted crown is a
			# thing you climb to. Read off the same `zone_band` the far
			# field's colour convergence uses, so the white on a distant
			# ridge and the white on the tree standing on it agree about
			# where the treeline is.
			var variant := variant_of(generator, config, found) \
				if any_models else &""
			if variant == &"":
				continue
			var key := "m%s|%d" % [variant, lod_of_band]
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


## WHICH VARIANT STANDS AT A DECIDED TREE. ONE FUNCTION, ASKED BY EVERYTHING.
##
## The walk asks it, the collider ring asks it through the walk, and the
## self-test's `tree field` and `registry determinism` gates ask it directly -
## and the first version was a snippet inside the walk that the gates
## reimplemented. They diverged inside one stage: Stage 8 gave the roll a SNOW
## BIAS from altitude, the walk computed it and the gates passed 0, and
## thirteen of two hundred and thirteen trees came out as different variants.
## The gate caught it, which is what it is for, and the fix is not to teach the
## gate the same arithmetic - it is to have one place that knows it.
##
## `TreePlacement.decide()`'s own note makes the same argument for the same
## reason: three restatements of a placement rule would have drifted apart by
## the second stage.
##
## THE SNOW BIAS IS ALTITUDE, NOT A KNOB: how far up its own zone's band this
## tree stands, 0 in the valley and 1 at the treeline. Read off the same
## `zone_band` the far field's colour convergence uses, so the white on a
## distant ridge and the white on the tree standing on it agree about where the
## treeline is.
static func variant_of(generator: TerrainGenerator, config: WorldgenConfig,
		found: Dictionary) -> StringName:
	var snow := 0.0
	# The zone comes off the placement decision that already solved it; the
	# lookup is the fallback for a caller that built `found` by hand.
	var zone := int(found.get("zone", -1))
	if zone < 0:
		zone = generator.surface_zone_at(
			found["bx"], found["bz"], found["surface"])
	var zb := generator.zone_band(zone)
	if zb.y > zb.x:
		snow = clampf((float(found["surface"]) - zb.x) / (zb.y - zb.x),
			0.0, 1.0)
	return TreeTable.variant_for(found["species"], found["cell"],
		generator.world_seed, config, snow)


## The variant and rung a model key names, or ["", 0].
static func model_of_key(key: String) -> Array:
	if not key.begins_with("m"):
		return ["", 0]
	var bits := key.substr(1).split("|")
	return [bits[0], int(bits[1]) if bits.size() > 1 else 0]


## Scale multiplier at this distance from the centre.
##
## THE INNER FADE DIED WITH THE INNER TEST, and this is the receipt.
##
## It existed for ONE reason: just inside the inner radius a tree was drawn as
## real voxels and just outside it as a six-triangle cone, and growing the cone
## from nothing over the first stretch turned that substitution into an
## appearance, which the eye forgives. Ruling 5 deleted the voxel trees and
## Stage 7 emptied `_place_trees()`, so there is no substitution left to hide -
## but the fade outlived its reason by one stage and kept multiplying every
## model's scale by `(d - inner) / fade`, which is ZERO for everything nearer
## than the inner radius. At the shipped 96 m voxel radius that put a 96 m
## bubble of invisible trees around the player, moving with them: the forest
## looked right until you walked up to it and each tree shrank away as you
## approached. The trunk colliders stayed, because `_test_tree_colliders`
## counts one cylinder per PLACEMENT and not per drawn tree - so the trees you
## could not see were still solid, which is what that gate's own note warns a
## fade could do and is the shape the bug was finally recognised by.
##
## THE OUTER FADE STAYS, distance v1 Stage 7. Without it the forest ENDS AT A
## CIRCLE - the same artefact the ring exists to remove, centred on the player
## at a bigger radius. Trees shrink away into the fog instead.
func _fade_at(distance: float) -> float:
	var f := 1.0
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
	# THE MESH'S OWN COLOUR, once per slot - the variant's dominant canopy
	# colour through the palette table, which is decision 7's pin. It is what
	# _instance_color() divides by to turn "mix this tree half way to its
	# hillside" into "what do you multiply its colour by to land there".
	#
	# TREES V3 STAGE 7: THE CONE BRANCH IS GONE WITH THE CONES. It read
	# `FarTreeMeshes.color_of_species()`, which read `Block.color_of(leaves)`,
	# which is dead the night leaf blocks die.
	var base_lin := TreeModels.canopy_color(StringName(model_of_key(key)[0]))
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
