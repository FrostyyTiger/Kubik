class_name FarProbe
extends Node

## Measures whether the far country HOLDS STILL, and quits.
##
##     godot --headless --path . -- --host --seed 42 --far-probe
##
## THE INSTRUMENT THIS PROJECT DID NOT HAVE. World feel v1's most expensive
## lesson is at the top of STATUS.md: the stream probe measures wall-clock on a
## box that drifts, so it cannot compare two commits, and a number from a
## different run is not a baseline. Every night-2 performance number in the
## project was a single-run comparison and one of them had to be retracted.
##
## The far field does not have that problem, and it is worth saying why: its
## output is PURE GEOMETRY FROM A SEEDED GENERATOR. No timing, no scheduler, no
## GPU. Given a seed and a centre, FarFieldJob produces the same vertices on any
## machine on every run. So this is a MEASURING INSTRUMENT rather than a gate,
## and it settles by arithmetic what the tour can only settle by eye - which
## matters because fizz cannot be judged by eye at all. You cannot see whether a
## ridge re-cut itself by comparing two screenshots taken from slightly
## different places.
##
## Hard rule 7 of distance v1: same seed, same numbers, every run, on any box.
## This runs the whole table TWICE in one session and exits non-zero if the two
## disagree by a single character.
##
##
## WHAT IT MEASURES, and each one is a different failure.
##
##   FIZZ       Build the mesh at centre C, then again at C + 16 m along +X.
##              Over every world position covered by both, the difference in
##              DRAWN height. RMS and max, in blocks. This is "does the far
##              country change shape when I walk", as a number.
##
##              16 m is chosen, not arbitrary: at far_step 8 the three rings
##              step by 8, 16 and 32 blocks, and 16 m is 32 blocks - a multiple
##              of all three. Every ring's snapped lattice therefore lands on
##              exactly the same world positions in both builds, so anything
##              this reports is the LOD boundary moving past a mountain and
##              nothing else. That is the artefact, isolated.
##
##   ROUGHNESS  Along a fan of rays out from the centre, the mean absolute
##              second difference of drawn height per sample. This is
##              "jaggedness", and it wants to fall while PEAK LOSS does not.
##
##   PEAK LOSS  For the twenty highest summits in the world, the drawn height
##              at 600 m against the true height_at(). This is the number that
##              stops the fix from becoming a different fault: a filter that
##              removes fizz by flattening the mountains has not fixed
##              anything, and a mountain that visibly GROWS as you walk up to
##              it is worse than the one being fixed.
##
##
## IT READS THE MESH, NOT THE FORMULA. Drawn height comes from the triangles
## FarFieldJob actually emitted - the quad is split p0-p2 exactly the way the
## index buffer splits it, and the height is barycentric inside whichever of
## the two triangles the sample lands in. Re-deriving "what the height would
## be" from the ring rules would measure this file's opinion of the far field
## rather than the far field, and the two would drift apart the first time a
## stage changed one and not the other.
##
## Skirts are excluded, and the test for one is exact rather than heuristic: a
## skirt quad is a vertical curtain, so its footprint in XZ is a line and one
## of its two edge vectors is zero. Ground quads are axis-aligned squares.
##
## Where two rings overlap - a coarse quad whose centre is just outside a ring
## boundary still covers ground the fine ring also covered - THE FINER QUAD
## WINS. It is the one nearer the player and the one drawn in front, and "the
## smaller step wins" is a rule that gives the same answer on every run.

## FIZZ: how far the player walks between the two builds, in BLOCKS. 32 blocks
## is 16 m. See the note above on why it is a multiple of every ring's step.
const FIZZ_OFFSET_BLOCKS := 32

## FIZZ: the sampling lattice, in blocks. Anchored to the WORLD, not to the
## centre, so the sample set does not move when the centre does.
##
## THIRTEEN, AND IT HAS TO BE ODD OF THE RING STEPS - the first version of this
## probe used 16 and under-reported, which was caught before any baseline was
## recorded. The rings step by 8, 16 and 32 blocks, and a coarse ring's vertices
## are a SUBSET of a fine ring's: at a shared lattice point the two rings agree
## exactly, by construction, whatever they do in between. Sampling on a multiple
## of 16 therefore lands on agreement points on purpose - it measured the 200 m
## ring boundary as a flat 0.00 while the same boundary is plainly visible in
## play. 13 shares no factor with 8, 16 or 32, so the samples walk across the
## quads instead of sitting on their corners. An instrument aliased against the
## thing it measures is worse than no instrument.
const FIZZ_STEP_BLOCKS := 13

## FIZZ: width of the distance bins the max is reported in, in metres. The
## Stage 2 gate is "no spike at 200 m or 400 m", which needs the max broken out
## by range rather than one number over the whole disc.
const FIZZ_BIN_M := 100.0

## ROUGHNESS: rays out from the centre, and the spacing along one. 13 for the
## same reason FIZZ_STEP_BLOCKS is 13 - four of the sixteen rays are axis
## aligned, and on a multiple of the ring step those four would sample nothing
## but vertices.
const ROUGH_RAYS := 16
const ROUGH_STEP_BLOCKS := 13

## PEAK LOSS: how many summits, how far apart they must be before two of them
## count as two mountains rather than as one lumpy one, and the range the drawn
## height is read at.
const PEAK_COUNT := 20
const PEAK_SEPARATION_CELLS := 40
const PEAK_RANGE_M := 600.0

## The grid the quad lookup is indexed on, in blocks. far_step is the finest
## ring's step, so one cell is covered by at most one quad of every ring.
const LOOKUP_CELL_BLOCKS := 8

var _world: Node = null
var _heightmap: Heightmap = null
var _config: WorldgenConfig = null
var _generator: TerrainGenerator = null

## What the meshes this probe built cost, summed. Not a gate - FarFieldJob is
## the same work whoever calls it, and this runs it on the main thread with
## nothing else happening, which is the least contended number the project has.
## Reported so the cost of Stages 1-4 has a deterministic-ish companion to the
## F3 readout's wall clock.
var _builds := 0
var _build_ms := 0
var _build_verts := 0


func run(world: Node) -> void:
	_world = world
	_go.call_deferred()


func _go() -> void:
	print("[FarProbe] waiting for the first world load")
	while not _world.is_idle():
		await get_tree().process_frame
	_heightmap = _world.generator.heightmap
	_config = _world.config
	_generator = _world.generator

	print("[FarProbe] seed %d, view %s, fog_end %.0f m, far_step %d blocks" % [
		_world.world_seed, _config.view_distance_name(), _config.fog_end_m,
		_config.far_step])

	var t0 := Time.get_ticks_msec()
	var first: PackedStringArray = await _measure()
	var mid := Time.get_ticks_msec()
	var second: PackedStringArray = await _measure()
	var t1 := Time.get_ticks_msec()

	for line in first:
		print(line)

	# HARD RULE 7. Not "close enough" - identical, character for character.
	# A probe that varies is not an instrument, and the whole argument for
	# building this one instead of trusting the tour rests on it.
	var same := String("\n").join(first) == String("\n").join(second)
	print("[FarProbe] far meshes: %d built, %.0f ms each, %d vertices each" % [
		_builds, float(_build_ms) / maxf(float(_builds), 1.0),
		_build_verts / maxi(_builds, 1)])
	print("[FarProbe] determinism: run 1 in %d ms, run 2 in %d ms, tables %s" % [
		mid - t0, t1 - mid, "IDENTICAL" if same else "DIFFER"])
	if not same:
		print("[FarProbe] --- run 2 ---")
		for line in second:
			print(line)
	print("[FarProbe] %s" % ["PASS" if same else "FAIL"])
	get_tree().quit(0 if same else 1)


# --- The table ----------------------------------------------------------------

func _measure() -> PackedStringArray:
	var out := PackedStringArray()
	var vantages := _vantages()
	out.append("[FarProbe] %-14s %9s %9s %10s %s" % [
		"vantage", "fizz rms", "fizz max", "roughness", "max fizz per 100 m band"])

	var fizz_sq := 0.0
	var fizz_n := 0
	var fizz_max := 0.0
	var rough_sum := 0.0
	var rough_n := 0

	for v in vantages:
		var centre: Vector2i = v["centre"]
		var a: Surface = await _surface(centre)
		var b: Surface = await _surface(centre + Vector2i(FIZZ_OFFSET_BLOCKS, 0))
		var fizz := _fizz(a, b, centre)
		var rough := _roughness(a, centre)
		fizz_sq += float(fizz["sum_sq"])
		fizz_n += int(fizz["n"])
		fizz_max = maxf(fizz_max, float(fizz["max"]))
		rough_sum += float(rough["sum"])
		rough_n += int(rough["n"])
		out.append("[FarProbe] %-14s %9.3f %9.3f %10.4f %s" % [
			v["name"], float(fizz["rms"]), float(fizz["max"]), float(rough["mean"]),
			fizz["bands"]])

	print("[FarProbe]   ... %d meshes built so far" % _builds)
	var total_rms := sqrt(fizz_sq / maxf(float(fizz_n), 1.0))
	var total_rough := rough_sum / maxf(float(rough_n), 1.0)
	out.append("[FarProbe] %-14s %9.3f %9.3f %10.4f  (%d samples)" % [
		"ALL", total_rms, fizz_max, total_rough, fizz_n])

	# --- PEAK LOSS, and its mirror --------------------------------------------
	out.append_array(await _extrema_rows(1, "peak loss",
		"positive = the drawn summit is LOWER than the truth"))
	out.append_array(await _extrema_rows(-1, "valley gain",
		"positive = the drawn valley floor is HIGHER than the truth"))
	return out


## One extremum table: twenty peaks, or twenty basins.
func _extrema_rows(sign: int, title: String, sense: String) -> PackedStringArray:
	var out := PackedStringArray()
	var bs: float = _config.block_size
	var cells := _summits(sign)
	out.append("[FarProbe] %s at %.0f m, blocks (%s)" % [
		title, PEAK_RANGE_M, sense])
	var sum := 0.0
	var worst := -INF
	var best := INF
	var over := 0
	for p in cells:
		var cell: Vector2i = p["cell"]
		var bx := _heightmap.cell_to_block(cell.x)
		var bz := _heightmap.cell_to_block(cell.y)
		var truth := _heightmap.height_at(float(bx), float(bz))
		var centre := _peak_centre(bx, bz)
		var s: Surface = await _surface(centre)
		var drawn := s.height_at(float(bx), float(bz))
		if is_nan(drawn):
			out.append("[FarProbe]   %5d %5d  %8.1f  not covered" % [bx, bz, truth])
			continue
		var delta := (truth - drawn) * float(sign)
		sum += delta
		worst = maxf(worst, delta)
		best = minf(best, delta)
		if absf(delta) > 4.0:
			over += 1
		out.append("[FarProbe]   %5d %5d  true %7.1f  drawn %7.1f  %+6.2f" % [
			bx, bz, truth, drawn, delta])
	out.append(("[FarProbe] %s over %d: mean %+.2f, worst %+.2f, best %+.2f, "
		+ "%d over 4 blocks (%.1f m real)") % [title, cells.size(),
		sum / maxf(float(cells.size()), 1.0), worst, best,
		over, 4.0 * bs * _config.world_scale])
	return out


# --- The vantages -------------------------------------------------------------

## Where to stand, derived from the world the way ScreenshotTour derives its
## vantages rather than hardcoded - so the numbers are about seed 42's terrain
## and not about three block coordinates somebody picked.
func _vantages() -> Array:
	var hm := _heightmap
	var spawn: Vector2i = _generator.spawn_block
	var summit := _find_summit()
	var lake := _find_largest_lake()
	return [
		{"name": "spawn", "centre": spawn},
		{"name": "summit", "centre": Vector2i(
			hm.cell_to_block(summit.x), hm.cell_to_block(summit.y))},
		{"name": "lake", "centre": Vector2i(
			hm.cell_to_block(lake.x), hm.cell_to_block(lake.y))},
	]


func _find_summit() -> Vector2i:
	var hm := _heightmap
	var best := Vector2i.ZERO
	var best_h := -INF
	for j in hm.cols:
		for i in hm.cols:
			var h := hm.cells[i + j * hm.cols]
			if h > best_h:
				best_h = h
				best = Vector2i(i, j)
	return best


func _find_largest_lake() -> Vector2i:
	var hm := _heightmap
	if _world.lakes == null or _world.lakes.lakes.is_empty():
		return Vector2i(hm.cols / 2, hm.cols / 2)
	var biggest := 0
	for i in _world.lakes.lakes.size():
		if _world.lakes.lakes[i]["cells"] > _world.lakes.lakes[biggest]["cells"]:
			biggest = i
	for j in hm.cols:
		for i in hm.cols:
			if _world.lakes.lake_id[i + j * hm.cols] == biggest:
				return Vector2i(i, j)
	return Vector2i(hm.cols / 2, hm.cols / 2)


## The twenty highest summits, or with `sign` -1 the twenty lowest basins.
##
## "A summit" is a cell no lower than anything within PEAK_SEPARATION_CELLS of
## it. Without the separation the top twenty cells are twenty cells of ONE
## mountain, and the column would measure the same peak twenty times.
##
## THE BASINS ARE THE MIRROR OF THE PEAKS AND THEY ARE NOT DECORATION. A box
## filter lowers summits AND raises valleys, and Stage 3's max pyramid buys the
## summits back by dilating - which raises valleys further. A column that only
## watched the peaks would show that trade as pure profit. Reported as GAIN:
## positive means the drawn valley floor is HIGHER than the truth.
##
## Scan order is fixed and ties keep the first found, so this is the same
## twenty cells on every run and on every machine.
func _summits(sign := 1) -> Array:
	var hm := _heightmap
	var found := []
	var claimed := []
	# Sort candidates by height, descending, then take greedily with the
	# separation rule. Sorting the whole map is 2.25 M entries; instead walk a
	# coarse grid of local maxima first, which is what a summit is anyway.
	var cands := []
	var stride := 4
	for j in range(stride, hm.cols - stride, stride):
		for i in range(stride, hm.cols - stride, stride):
			var h := hm.cells[i + j * hm.cols]
			var top := true
			for dj in [-stride, 0, stride]:
				for di in [-stride, 0, stride]:
					if di == 0 and dj == 0:
						continue
					if (hm.cells[i + di + (j + dj) * hm.cols] - h) * float(sign) > 0.0:
						top = false
						break
				if not top:
					break
			if top:
				cands.append({"cell": Vector2i(i, j), "h": h})
	# Height descending; the cell coordinates break ties so the order cannot
	# depend on the sort being stable.
	cands.sort_custom(func(a, b):
		if a["h"] != b["h"]:
			return (a["h"] > b["h"]) if sign > 0 else (a["h"] < b["h"])
		if a["cell"].y != b["cell"].y:
			return a["cell"].y < b["cell"].y
		return a["cell"].x < b["cell"].x)
	for c in cands:
		if found.size() >= PEAK_COUNT:
			break
		var far_enough := true
		for k in claimed:
			if absi(k.x - c["cell"].x) < PEAK_SEPARATION_CELLS \
					and absi(k.y - c["cell"].y) < PEAK_SEPARATION_CELLS:
				far_enough = false
				break
		if not far_enough:
			continue
		claimed.append(c["cell"])
		found.append(c)
	return found


## Where to stand to look at a summit from PEAK_RANGE_M.
##
## Towards the world origin rather than along a fixed axis: a fixed axis puts
## the vantage outside the map for every peak on that side of the world, and a
## centre outside the map builds a mesh with a corner missing.
func _peak_centre(bx: int, bz: int) -> Vector2i:
	var bs: float = _config.block_size
	var reach := PEAK_RANGE_M / bs
	var dir := Vector2(-float(bx), -float(bz))
	if dir.length() < 1.0:
		dir = Vector2(1.0, 0.0)
	dir = dir.normalized()
	return Vector2i(int(round(float(bx) + dir.x * reach)),
		int(round(float(bz) + dir.y * reach)))


# --- The three numbers --------------------------------------------------------

## Difference in drawn height between two builds 16 m apart, over every world
## position both of them cover.
func _fizz(a: Surface, b: Surface, centre: Vector2i) -> Dictionary:
	var bs: float = _config.block_size
	var reach := int(ceil(_config.fog_end_m / bs * FarFieldJob.FOG_MARGIN))
	var lo_x := _snap(centre.x - reach)
	var lo_z := _snap(centre.y - reach)
	var bins := PackedFloat32Array()
	bins.resize(int(ceil((_config.fog_end_m * FarFieldJob.FOG_MARGIN) / FIZZ_BIN_M)) + 1)
	bins.fill(0.0)

	var sum_sq := 0.0
	var n := 0
	var worst := 0.0
	var bz := lo_z
	while bz <= centre.y + reach:
		var bx := lo_x
		while bx <= centre.x + reach:
			var ha := a.height_at(float(bx), float(bz))
			if is_nan(ha):
				bx += FIZZ_STEP_BLOCKS
				continue
			var hb := b.height_at(float(bx), float(bz))
			if is_nan(hb):
				bx += FIZZ_STEP_BLOCKS
				continue
			var d := absf(ha - hb)
			sum_sq += d * d
			n += 1
			worst = maxf(worst, d)
			var dist_m := Vector2(float(bx - centre.x), float(bz - centre.y)).length() * bs
			var bin := clampi(int(dist_m / FIZZ_BIN_M), 0, bins.size() - 1)
			bins[bin] = maxf(bins[bin], d)
			bx += FIZZ_STEP_BLOCKS
		bz += FIZZ_STEP_BLOCKS

	var parts := PackedStringArray()
	for i in bins.size():
		parts.append("%.2f" % bins[i])
	return {
		"rms": sqrt(sum_sq / maxf(float(n), 1.0)),
		"max": worst,
		"sum_sq": sum_sq,
		"n": n,
		"bands": String(" ").join(parts),
	}


## Mean absolute second difference of drawn height along a fan of rays.
func _roughness(s: Surface, centre: Vector2i) -> Dictionary:
	var bs: float = _config.block_size
	var reach := _config.fog_end_m / bs
	var start := maxf(_config.voxel_radius_chunks * Chunk.SIZE
		- float(2 * _config.far_step), 0.0)
	var sum := 0.0
	var n := 0
	for k in ROUGH_RAYS:
		var ang := TAU * float(k) / float(ROUGH_RAYS)
		var dir := Vector2(cos(ang), sin(ang))
		var prev2 := NAN
		var prev1 := NAN
		var r := start
		while r <= reach:
			var p := Vector2(float(centre.x), float(centre.y)) + dir * r
			var h := s.height_at(p.x, p.y)
			if not is_nan(prev2) and not is_nan(prev1) and not is_nan(h):
				sum += absf(prev2 - 2.0 * prev1 + h)
				n += 1
			prev2 = prev1
			prev1 = h
			r += float(ROUGH_STEP_BLOCKS)
	return {"mean": sum / maxf(float(n), 1.0), "sum": sum, "n": n}


func _snap(b: int) -> int:
	return int(floor(float(b) / float(FIZZ_STEP_BLOCKS))) * FIZZ_STEP_BLOCKS


# --- Building one far mesh, and reading heights back out of it ----------------

## One FarFieldJob, run here on the main thread, indexed for point lookup.
##
## Awaits a frame first so a run of two dozen builds does not hold the loop for
## a minute at a time - headless does not care, but a probe that never yields
## cannot print progress and cannot be interrupted.
func _surface(centre: Vector2i) -> Surface:
	await get_tree().process_frame
	var job := FarFieldJob.new()
	job.heightmap = _heightmap
	job.generator = _generator
	job.config = _config
	job.center = centre
	job.run()
	_builds += 1
	_build_ms += job.elapsed_ms
	_build_verts += job.vertex_count
	var s := Surface.new()
	s.build(job, _config)
	return s


## A built far mesh, with a point query over the triangles it actually emitted.
class Surface extends RefCounted:
	# Per ground quad: the block coordinates of its low corner, its step in
	# blocks, and the four corner heights in blocks, in FarFieldJob's corner
	# order - (x0,z0), (x1,z0), (x1,z1), (x0,z1).
	var qx := PackedInt32Array()
	var qz := PackedInt32Array()
	var qstep := PackedInt32Array()
	var qy := PackedFloat32Array()

	# A flat grid of LOOKUP_CELL_BLOCKS cells over the disc's bounding box,
	# each holding the index of the finest quad covering it, or -1.
	var grid := PackedInt32Array()
	var g_min_bx := 0
	var g_min_bz := 0
	var g_cols := 0

	func build(job: FarFieldJob, config: WorldgenConfig) -> void:
		var bs: float = config.block_size
		var inv := 1.0 / bs
		var verts: PackedVector3Array = job.arrays[Mesh.ARRAY_VERTEX] \
			if not job.arrays.is_empty() else PackedVector3Array()

		var reach := int(ceil(config.fog_end_m * inv * FarFieldJob.FOG_MARGIN)) \
			+ FarProbe.LOOKUP_CELL_BLOCKS
		g_min_bx = job.center.x - reach
		g_min_bz = job.center.y - reach
		g_cols = 2 * reach / FarProbe.LOOKUP_CELL_BLOCKS + 2
		grid.resize(g_cols * g_cols)
		grid.fill(-1)

		var q := 0
		while q + 3 < verts.size():
			var p0 := verts[q]
			var p1 := verts[q + 1]
			var p2 := verts[q + 2]
			var p3 := verts[q + 3]
			q += 4
			# A SKIRT IS A VERTICAL CURTAIN, so one of its two edge vectors is
			# zero in XZ. A ground quad is an axis-aligned square with both
			# non-zero. Exact, not a tolerance on area.
			var dx := p1.x - p0.x
			var dz := p3.z - p0.z
			if absf(dx) < 0.001 or absf(dz) < 0.001:
				continue
			var bx := int(round(p0.x * inv))
			var bz := int(round(p0.z * inv))
			var step := int(round(absf(dx) * inv))
			var idx := qx.size()
			qx.push_back(bx)
			qz.push_back(bz)
			qstep.push_back(step)
			qy.push_back(p0.y * inv)
			qy.push_back(p1.y * inv)
			qy.push_back(p2.y * inv)
			qy.push_back(p3.y * inv)
			# Claim every lookup cell the quad covers. THE FINER QUAD WINS
			# where two rings overlap: it is the one nearer the player and the
			# one drawn in front.
			var cz := bz
			while cz < bz + step:
				var cx := bx
				while cx < bx + step:
					var gi := (cx - g_min_bx) / FarProbe.LOOKUP_CELL_BLOCKS
					var gj := (cz - g_min_bz) / FarProbe.LOOKUP_CELL_BLOCKS
					if gi >= 0 and gj >= 0 and gi < g_cols and gj < g_cols:
						var at := gi + gj * g_cols
						var was := grid[at]
						if was < 0 or qstep[was] > step:
							grid[at] = idx
					cx += FarProbe.LOOKUP_CELL_BLOCKS
				cz += FarProbe.LOOKUP_CELL_BLOCKS

	## Drawn height in BLOCKS at a block position, or NAN where the mesh has
	## nothing - inside the voxel hole, or past the disc's edge.
	##
	## Barycentric inside whichever of the quad's two triangles the point lands
	## in, split along p0-p2 exactly as the index buffer splits it. Bilinear
	## would be smoother and would not be what is on screen.
	func height_at(bx: float, bz: float) -> float:
		var gi := int(floor((bx - float(g_min_bx)) / float(FarProbe.LOOKUP_CELL_BLOCKS)))
		var gj := int(floor((bz - float(g_min_bz)) / float(FarProbe.LOOKUP_CELL_BLOCKS)))
		if gi < 0 or gj < 0 or gi >= g_cols or gj >= g_cols:
			return NAN
		var idx := grid[gi + gj * g_cols]
		if idx < 0:
			return NAN
		var step := float(qstep[idx])
		var u := (bx - float(qx[idx])) / step
		var v := (bz - float(qz[idx])) / step
		if u < 0.0 or v < 0.0 or u > 1.0 or v > 1.0:
			return NAN
		var y00 := qy[idx * 4]
		var y10 := qy[idx * 4 + 1]
		var y11 := qy[idx * 4 + 2]
		var y01 := qy[idx * 4 + 3]
		if v <= u:
			return y00 + (y10 - y00) * (u - v) + (y11 - y00) * v
		return y00 + (y11 - y00) * u + (y01 - y00) * (v - u)
