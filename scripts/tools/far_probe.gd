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

## SHELF STABILITY: the same measurement over a 200 m WALK rather than a 16 m
## step. Blocks. Distance v2 Stage 1.
##
## The gate that stage is written against is "walk 200 m and back; a named shelf
## does not change height", and that is a different question from fizz. Fizz
## isolates the LOD boundary sliding past a mountain over one rebuild's worth of
## walking. This asks whether the quantisation itself is world-absolute: a
## terrace grid with any player term in it would slide the whole far country by
## up to half a step here, and 400 blocks is a multiple of every ring's step
## (8, 16, 32) for exactly the reason FIZZ_OFFSET_BLOCKS is, so a ring's lattice
## still lands on the same world positions in both builds and the quantisation
## is the only thing left that can differ.
const SHELF_OFFSET_BLOCKS := 400

## THE SEAM, distance v2 Stage 8: how far past the voxel boundary to read the
## far mesh's opinion of the ground, in blocks, and how many samples round.
##
## The far mesh's inner edge is at voxel_radius - 2 * far_step (176 blocks at
## High), and just outside it _corner_y() blends the far mesh onto the VOXEL
## surface - coarse + detail + half a block, which is the top face of the
## topmost solid block. So the two meshes are supposed to meet at exactly the
## same altitude there, and the number that says whether terracing broke that
## is the difference between them, sampled on a ring just outside the hole.
##
## 6 blocks out rather than 0: the quad whose CENTRE is at the hole radius has
## corners either side of it, and sampling exactly on the edge reads whichever
## quad the lookup grid happened to claim.
const SEAM_PROBE_OUT_BLOCKS := 6
const SEAM_PROBE_SAMPLES := 720

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

## HALF-WIDTH OF THE RING-BOUNDARY WINDOW, in metres. Distance v2 Stage 0.
##
## The 100 m bins above are what Stage 2 of distance v1 was read against, and
## they are too wide for the question distance v2 Stage 9 asks: the 400 m ring
## boundary shows up as the max of the 300-400 bin OR of the 400-500 one,
## depending on which side of it the worst sample fell. 25 m each side puts one
## number on each boundary, taken over the samples that actually straddle it.
const BOUNDARY_HALF_M := 25.0

## TERRACE COMPLIANCE, distance v2 Stage 1: how close a corner height has to be
## to a multiple of its ring's step before it counts as landing on the grid.
## Blocks. Slack for float32 in the vertex buffer and for the y_offset being
## added and taken away again, not for arithmetic that nearly quantises.
const TERRACE_EPS_BLOCKS := 0.002

## THE TWO ROW BANDS EVERY PER-PIXEL NUMBER IN THIS EPIC IS TAKEN OVER.
## Distance v3 Stage 0, and they are constants here because they are a finding
## rather than a preference.
##
## Distance v2 measured two tours of IDENTICAL code: the far band came back at
## mean |dL| 0.0000 and worst 0.0 - bit-identical - while the near field
## differed by up to 48 luma levels, because which flora columns have finished
## streaming when the shutter opens is not deterministic. So a whole-frame diff
## of a tour pair proves nothing and a far-band diff proves everything, and any
## number in the status doc that does not say which rows it came from is not a
## number.
##
## The near band is not there to be diffed. It is the fleck REFERENCE: what a
## surface made of real blocks measures on the same frame, which is the only
## thing "the far country stops being mush" can be read against.
const FLECK_FAR_ROWS := Vector2i(0, 300)
const FLECK_NEAR_ROWS := Vector2i(500, 720)

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
	# DISTANCE V2 STAGE 0. Every number below is a function of these two, and a
	# table without them in its header is a table nobody can place afterwards.
	print("[FarProbe] far_terrace %.2f, far_riser_shade %.2f, far_band_m %.1f, far_band_step %.3f" % [
		_config.far_terrace, _config.far_riser_shade,
		_config.far_band_m, _config.far_band_step])

	# DISTANCE V4 STAGE 7. Take every mesh below through the C++ mesher.
	if "--cpp" in OS.get_cmdline_user_args():
		var m := FarMesher.new()
		if not FarMesher.available() or not m.setup(_heightmap, _generator, _config):
			print("[FarProbe] --cpp asked for, and there is no C++ mesher to ask")
			get_tree().quit(1)
			return
		_cpp_mesher = m
	print("[FarProbe] mesher: %s" % ["c++" if _cpp_mesher != null else "gdscript"])

	# THE COST TABLE, distance v3 Stage 0. See _cost_table().
	if "--cost" in OS.get_cmdline_user_args():
		await _cost_table()
		get_tree().quit(0)
		return

	# THE PORT'S OWN NUMBERS, distance v4 Stage 6. See _bench_table().
	if "--bench" in OS.get_cmdline_user_args():
		await _bench_table()
		get_tree().quit(0)
		return

	# DISTANCE V5 STAGE 0, appended after it. The two cheap instruments this
	# night's gates are read on - see _upload_table() and _idle_table().
	if "--upload" in OS.get_cmdline_user_args():
		await _upload_table()
		get_tree().quit(0)
		return

	if "--idle" in OS.get_cmdline_user_args():
		await _idle_table()
		get_tree().quit(0)
		return

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
	_print_fleck_recipe()
	print("[FarProbe] %s" % ["PASS" if same else "FAIL"])
	get_tree().quit(0 if same else 1)


## THE FLECK NUMBER IS NOT MEASURED HERE, AND THIS PRINTS WHERE IT IS.
## Distance v3 Stage 0.
##
## "The far country stops being mush" is the epic's whole claim, and mush is a
## property of PIXELS - neighbouring ones agreeing - which this probe cannot
## see: it reads a mesh's triangles and never a frame. So the number lives in
## tools/png_diff.py's --local-contrast mode, over a tour shot's far band, and
## what belongs here is the command that takes it, printed with THIS run's own
## band and knob values so the two halves of the instrument cannot drift apart.
##
## The near field's own band is printed beside it on purpose. A fleck number
## means nothing on its own; it means something against the band of the same
## frame where the blocks are real.
func _print_fleck_recipe() -> void:
	print("[FarProbe] the fleck number (mush is low, blocks are high) is taken from")
	print("[FarProbe]   a tour shot, not from this probe - it is a pixel measurement:")
	print("[FarProbe]   ~/.venvs/kubik/bin/python tools/png_diff.py --local-contrast \\")
	print("[FarProbe]       --rows %d:%d build/tour/<label>          # the far band" % [
		FLECK_FAR_ROWS.x, FLECK_FAR_ROWS.y])
	print("[FarProbe]   ~/.venvs/kubik/bin/python tools/png_diff.py --local-contrast \\")
	print("[FarProbe]       --rows %d:%d build/tour/<label>        # the near field, for reference" % [
		FLECK_NEAR_ROWS.x, FLECK_NEAR_ROWS.y])


## THE ABAB INSTRUMENT FOR WHAT A FAR MESH COSTS. Distance v3 Stage 0.
##
##     godot --headless --path . -- --host --seed 42 --far-probe --cost
##
## Hard rule 7 says perf claims are ABAB medians on ganymede, and the full table
## above is four minutes a run - twenty-four for one three-and-three comparison,
## at every stage that touches the job. This is the same builder, at the same
## three vantages, with the geometry questions taken out: COST_REPEATS meshes
## per vantage, the per-mesh job time reported as a median with its range, and
## the vertex count reported beside it because the vertex count is deterministic
## and a cost that moved without the geometry moving is a different finding from
## one that moved with it.
##
## IT IS THE JOB'S OWN TIME, ON THE MAIN THREAD, WITH NOTHING ELSE HAPPENING -
## the least contended number this project can take, and deliberately not the
## number the player feels. What the player feels is `[FarField] first build`,
## printed at world load, which waits for a worker pool that runs one GDScript
## task at a time while 2,400 chunks are being generated on it. Both are in the
## status doc; neither is the other.
##
## THE FRONTIER IS STILL EMPTY HERE, which is distance v2's carried item 13 and
## is not fixed by this: FarFieldJob is built without one, so the per-sector
## hole is dead code to it and the vertex count below is the disc's, not the
## world's. That is why `[FarField] first build` is reported next to it.
const COST_REPEATS := 3


func _cost_table() -> void:
	print("[FarProbe] cost: %d meshes per vantage, job ms on the main thread" % [
		COST_REPEATS])
	var all := PackedFloat32Array()
	for v in _vantages():
		var centre: Vector2i = v["centre"]
		var ms := PackedFloat32Array()
		var verts := 0
		for k in COST_REPEATS:
			await get_tree().process_frame
			var job := FarFieldJob.new()
			job.heightmap = _heightmap
			job.generator = _generator
			job.config = _config
			job.center = centre
			job.run()
			ms.append(float(job.elapsed_ms))
			verts = job.vertex_count
			all.append(float(job.elapsed_ms))
		var sorted := ms.duplicate()
		sorted.sort()
		print("[FarProbe] cost %-14s median %6.0f ms  (%.0f-%.0f)  %d vertices" % [
			v["name"], sorted[sorted.size() / 2], sorted[0],
			sorted[sorted.size() - 1], verts])
	var s_all := all.duplicate()
	s_all.sort()
	print("[FarProbe] cost ALL            median %6.0f ms  (%.0f-%.0f) over %d meshes" % [
		s_all[s_all.size() / 2], s_all[0], s_all[s_all.size() - 1], s_all.size()])
	await _idle_rebuild()


## WHAT AN F4 KNOB COSTS, WITH THE POOL IDLE. Distance v3 Stage 4.
##
## The acceptance criterion is "wall rebuild under 5 s", and until this existed
## every wall number any run printed was contended. The first build waits behind
## 2,400 chunks; a rebuild during a screenshot tour waits behind whatever that
## vantage is streaming; the stream probe's rebuilds happen during a sprint,
## which is the worst case by construction. None of them is the thing the
## criterion is about, which is a person standing still moving a slider and
## watching the far country redraw - `FarField.apply_far_knobs()`, the property
## distance v2 built the epic's judging instrument out of.
##
## So: the REAL world, fully loaded, the pool idle, `rebuild_in_place()` called
## the way the F4 panel calls it, and the wall time FarField itself reports.
## Three of them, median with range.
func _idle_rebuild() -> void:
	var far_field: Node = _world.get_node_or_null("FarField")
	if far_field == null or not far_field.has_method("rebuild_in_place"):
		print("[FarProbe] cost idle rebuild: no FarField to ask")
		return
	# The world has been idle since _go() waited for it, and this probe has run
	# every mesh above on the MAIN thread, so the pool really is empty.
	var walls := PackedFloat32Array()
	for k in COST_REPEATS:
		var before: int = far_field.stats()["rebuilds"]
		if not far_field.rebuild_in_place():
			print("[FarProbe] cost idle rebuild: FarField refused")
			return
		var frames := 0
		while int(far_field.stats()["rebuilds"]) == before and frames < 100000:
			await get_tree().process_frame
			frames += 1
		walls.append(float(far_field.stats()["wall_ms"]))
	var sorted := walls.duplicate()
	sorted.sort()
	print("[FarProbe] cost idle rebuild   median %6.0f ms wall  (%.0f-%.0f) over %d rebuilds" % [
		sorted[sorted.size() / 2], sorted[0], sorted[sorted.size() - 1],
		sorted.size()])


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
	# DISTANCE V2 STAGE 0: one max per ring boundary, over the whole run, and
	# one terrace-compliance line per vantage.
	var edge_max := PackedFloat32Array()
	edge_max.resize(FarFieldJob.RING_OUTER_M.size())
	edge_max.fill(0.0)
	var edge_sum := PackedFloat64Array()
	edge_sum.resize(edge_max.size())
	edge_sum.fill(0.0)
	var edge_count := PackedInt32Array()
	edge_count.resize(edge_max.size())
	edge_count.fill(0)
	var terrace := PackedStringArray()
	var shelf_rows := PackedStringArray()
	var seam_rows := PackedStringArray()

	for v in vantages:
		var centre: Vector2i = v["centre"]
		var a: Surface = await _surface(centre)
		var b: Surface = await _surface(centre + Vector2i(FIZZ_OFFSET_BLOCKS, 0))
		var fizz := _fizz(a, b, centre)
		var rough := _roughness(a, centre)
		# THE 200 m WALK, Stage 1's gate. Compared against the SAME first
		# surface, so the only difference is where the second one was centred.
		var walked: Surface = await _surface(centre + Vector2i(SHELF_OFFSET_BLOCKS, 0))
		var shelf := _fizz(a, walked, centre)
		shelf_rows.append("[FarProbe] %-14s rms %7.3f  max %7.3f  over %d samples" % [
			v["name"], float(shelf["rms"]), float(shelf["max"]), int(shelf["n"])])
		fizz_sq += float(fizz["sum_sq"])
		fizz_n += int(fizz["n"])
		fizz_max = maxf(fizz_max, float(fizz["max"]))
		rough_sum += float(rough["sum"])
		rough_n += int(rough["n"])
		var edges: PackedFloat32Array = fizz["edges"]
		var e_sq: PackedFloat64Array = fizz["edge_sq"]
		var e_n: PackedInt32Array = fizz["edge_n"]
		for i in edge_max.size():
			edge_max[i] = maxf(edge_max[i], edges[i])
			edge_sum[i] += e_sq[i]
			edge_count[i] += e_n[i]
		out.append("[FarProbe] %-14s %9.3f %9.3f %10.4f %s" % [
			v["name"], float(fizz["rms"]), float(fizz["max"]), float(rough["mean"]),
			fizz["bands"]])
		terrace.append("[FarProbe] %-14s %s" % [v["name"], _terrace_row(a)])
		seam_rows.append("[FarProbe] %-14s %s" % [v["name"], _seam_row(a, centre)])

	print("[FarProbe]   ... %d meshes built so far" % _builds)
	var total_rms := sqrt(fizz_sq / maxf(float(fizz_n), 1.0))
	var total_rough := rough_sum / maxf(float(rough_n), 1.0)
	out.append("[FarProbe] %-14s %9.3f %9.3f %10.4f  (%d samples)" % [
		"ALL", total_rms, fizz_max, total_rough, fizz_n])

	# THE RING BOUNDARIES, ONE NUMBER EACH. Distance v2 Stage 9 asks whether
	# the power-of-two step ladder removed the 400 m re-cut without a geomorph,
	# and that question needs the boundary measured over a window that
	# straddles it rather than read off whichever 100 m bin it fell in.
	var edge_parts := PackedStringArray()
	for i in FarFieldJob.RING_OUTER_M.size():
		edge_parts.append("%.0f m: max %.2f rms %.3f over %d" % [
			FarFieldJob.RING_OUTER_M[i], edge_max[i],
			sqrt(edge_sum[i] / maxf(float(edge_count[i]), 1.0)), edge_count[i]])
	out.append("[FarProbe] ring boundary max fizz (+/- %.0f m) - %s" % [
		BOUNDARY_HALF_M, String("   ").join(edge_parts)])

	# TERRACE COMPLIANCE, Stage 1's gate as a number rather than as a promise.
	out.append("[FarProbe] terrace: ground-quad corners on their ring's step grid")
	out.append_array(terrace)

	# THE SEAM, Stage 8's gate as a number: does the far mesh still meet the
	# voxel surface where the voxels stop?
	out.append("[FarProbe] seam: far mesh against the voxel surface, %d blocks out (blocks)" % [
		SEAM_PROBE_OUT_BLOCKS])
	out.append_array(seam_rows)

	# AND THE SHELF HELD STILL OVER A 200 m WALK - the other half of that gate.
	out.append("[FarProbe] shelf stability over a %d m walk (drawn height, blocks)" % [
		int(float(SHELF_OFFSET_BLOCKS) * _config.block_size)])
	out.append_array(shelf_rows)

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
	var edges := PackedFloat32Array()
	edges.resize(FarFieldJob.RING_OUTER_M.size())
	edges.fill(0.0)
	# AND THE RMS IN THE SAME WINDOW. A max is one sample, and "the boundary got
	# three times worse" is a different claim from "one quad at the boundary got
	# three times worse". Stage 9 needs both.
	var edge_sq := PackedFloat64Array()
	edge_sq.resize(edges.size())
	edge_sq.fill(0.0)
	var edge_n := PackedInt32Array()
	edge_n.resize(edges.size())
	edge_n.fill(0)

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
			for e in edges.size():
				if absf(dist_m - FarFieldJob.RING_OUTER_M[e]) <= BOUNDARY_HALF_M:
					edges[e] = maxf(edges[e], d)
					edge_sq[e] += float(d) * float(d)
					edge_n[e] += 1
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
		"edges": edges,
		"edge_sq": edge_sq,
		"edge_n": edge_n,
	}


## Mean absolute second difference of drawn height along a fan of rays.
func _roughness(s: Surface, centre: Vector2i) -> Dictionary:
	var bs: float = _config.block_size
	var reach := _config.fog_end_m / bs
	var start := maxf(_config.voxel_radius_chunks * Chunk.SIZE
		- float(2 * FarFieldJob.base_step_blocks(_config)), 0.0)
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


## STAGE 8'S GATE AS A NUMBER: does the far mesh still meet the voxel surface
## at the seam, with the terrace on?
##
## The voxel surface a player stands on is `height_at + detail_at +
## VOXEL_TOP_BIAS_BLOCKS` - the coarse height plus the per-block detail plus
## half a block, because "the topmost solid block in a column is floor(surface)
## and the face you see is its top". `_corner_y()` computes exactly that at the
## seam and fades to the plain coarse height a band further out, which is what
## makes the boundary invisible.
##
## Terracing inside that band would break the agreement the band exists to
## create, so `_terrace_at()` fades the terrace in over the same cells the
## detail fades out over. If that fade is right this number is the same with the
## knob at 0 and at 1. If it is wrong, this is where the step appears.
func _seam_row(s: Surface, centre: Vector2i) -> String:
	var r := maxf(float(_config.voxel_radius_chunks * Chunk.SIZE)
		- float(2 * FarFieldJob.base_step_blocks(_config)), 0.0) \
		+ float(SEAM_PROBE_OUT_BLOCKS)
	var worst := 0.0
	var sum_sq := 0.0
	var n := 0
	for k in SEAM_PROBE_SAMPLES:
		var a := TAU * float(k) / float(SEAM_PROBE_SAMPLES)
		var bx := float(centre.x) + cos(a) * r
		var bz := float(centre.y) + sin(a) * r
		var drawn := s.height_at(bx, bz)
		if is_nan(drawn):
			continue
		var voxel := _heightmap.height_at(bx, bz) + _generator.detail_at(bx, bz) \
			+ FarFieldJob.VOXEL_TOP_BIAS_BLOCKS
		var d := absf(drawn - voxel)
		worst = maxf(worst, d)
		sum_sq += d * d
		n += 1
	return "max %6.3f  rms %6.3f  over %d samples" % [
		worst, sqrt(sum_sq / maxf(float(n), 1.0)), n]


## STAGE 1'S GATE AS A NUMBER: are the drawn corner heights on their ring's
## step grid, or are they only nearly on it?
##
## Read off the emitted vertices, not off the quantise expression - the whole
## discipline of this probe. A gate that re-derived what the height ought to be
## would pass on the day the expression and the mesh stopped agreeing, which is
## the only day it matters.
##
## Two things are subtracted before the question is asked. The constant
## y_offset - half a detail_amp, the drop that keeps the far mesh under voxels
## it does not know about - is added to every ground corner and is not part of
## the terrace. And quads inside the seam band are skipped outright: there the
## far mesh computes the voxel surface on purpose (Stage 8), so a corner on the
## step grid there would be the bug.
##
## Reported per ring step, because the three rings quantise to 8, 16 and 32
## blocks and a single fraction over all of them hides which one slipped.
func _terrace_row(s: Surface) -> String:
	var per_step := {}
	for i in s.qstep.size():
		var step := float(s.qstep[i])
		var cx := float(s.qx[i]) + step * 0.5 - float(s.centre.x)
		var cz := float(s.qz[i]) + step * 0.5 - float(s.centre.y)
		# ONE CELL OF MARGIN. The terrace strength is decided at the cell CENTRE
		# and the seam's detail blend is applied at each CORNER, so a quad whose
		# centre has just left the band can still have two corners inside it -
		# 112 quads of ring 0 at spawn, all of them correct and none of them on
		# the step grid. Excluding by centre alone measured them as failures.
		if sqrt(cx * cx + cz * cz) <= s.seam_end_blocks + step:
			continue
		if not per_step.has(step):
			per_step[step] = [0, 0, 0.0]   # on grid, total, worst deviation
		var row: Array = per_step[step]
		# RIDGE CELLS SIT ON A FINER GRID - a quarter of the ring's step, see
		# FarFieldJob.RIDGE_SUBSTEP - so a corner is "on grid" if it is on
		# either. Checked against the sub-step, which the ring's own step is a
		# multiple of, so this still proves the height was quantised and no
		# longer fails on the summits it is supposed to be proud of.
		var fine := step / float(FarFieldJob.RIDGE_SUBSTEP)
		var worst := 0.0
		for k in 4:
			var h := s.qy[i * 4 + k] - s.y_off_blocks
			worst = maxf(worst, absf(h - round(h / fine) * fine))
		row[1] += 1
		if worst <= TERRACE_EPS_BLOCKS:
			row[0] += 1
		row[2] = maxf(row[2], worst)
	var keys := per_step.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		var row: Array = per_step[k]
		parts.append("%d blk (/%d): %d/%d on grid, worst %.3f" % [
			int(k), FarFieldJob.RIDGE_SUBSTEP, row[0], row[1], row[2]])
	return String("   ").join(parts)


# --- Building one far mesh, and reading heights back out of it ----------------

## One FarFieldJob, run here on the main thread, indexed for point lookup.
##
## Awaits a frame first so a run of two dozen builds does not hold the loop for
## a minute at a time - headless does not care, but a probe that never yields
## cannot print progress and cannot be interrupted.
func _surface(centre: Vector2i) -> Surface:
	await get_tree().process_frame
	# DISTANCE V4 STAGE 7. `--cpp` takes the WHOLE table through the C++ mesher
	# instead, and the gate is that the two tables are identical character for
	# character - which is a stronger statement than the self-test's array
	# comparison, because these rows are fizz, roughness, peak loss, terrace
	# compliance and seam agreement, computed off the triangles rather than off
	# the arrays. A mesh can match array-for-array and still be read wrong.
	var job: RefCounted = _cpp_mesher
	if job != null:
		_cpp_mesher.config = _config
		_cpp_mesher.center = centre
		_cpp_mesher.frontier = PackedInt32Array()
		_cpp_mesher.run()
	else:
		var gd := FarFieldJob.new()
		gd.heightmap = _heightmap
		gd.generator = _generator
		gd.config = _config
		gd.center = centre
		gd.run()
		job = gd
	_builds += 1
	_build_ms += job.elapsed_ms
	_build_verts += job.vertex_count
	var s := Surface.new()
	s.build(job, _config)
	return s


## Set by _go() when --cpp is passed, and null otherwise. One instance for the
## whole run: setup() marshals the world and doing it per mesh would measure
## the marshal rather than the mesher.
var _cpp_mesher: FarMesher = null


## A built far mesh, with a point query over the triangles it actually emitted.
class Surface extends RefCounted:
	# Per ground quad: the block coordinates of its low corner, its step in
	# blocks, and the four corner heights in blocks, in FarFieldJob's corner
	# order - (x0,z0), (x1,z0), (x1,z1), (x0,z1).
	var qx := PackedInt32Array()
	var qz := PackedInt32Array()
	var qstep := PackedInt32Array()
	var qy := PackedFloat32Array()

	# DISTANCE V2 STAGE 1. What a terrace check has to know: where the disc was
	# centred, the constant y_offset every ground corner carries (taken back off
	# before asking whether the height is on the step grid), and where the seam
	# band ends - inside it the far mesh deliberately computes the VOXEL surface
	# and is not terraced at all (Stage 8).
	var centre := Vector2i.ZERO
	var y_off_blocks := 0.0
	var seam_end_blocks := 0.0

	# A flat grid of LOOKUP_CELL_BLOCKS cells over the disc's bounding box,
	# each holding the index of the finest quad covering it, or -1.
	var grid := PackedInt32Array()
	var g_min_bx := 0
	var g_min_bz := 0
	var g_cols := 0

	## `job` is a FarFieldJob or a FarMesher - both present `center` and
	## `arrays`, which is all this reads, and distance v4 Stage 7 needs the
	## whole table taken through either mesher. Untyped for that reason and no
	## other; every assertion below is unchanged.
	func build(job: RefCounted, config: WorldgenConfig) -> void:
		var bs: float = config.block_size
		var inv := 1.0 / bs
		centre = job.center
		y_off_blocks = -0.5 * config.detail_amp
		seam_end_blocks = maxf(float(config.voxel_radius_chunks * Chunk.SIZE)
			- float(2 * FarFieldJob.base_step_blocks(config)), 0.0) \
			+ float(FarFieldJob.base_step_blocks(config)) \
			* FarFieldJob.TERRACE_FADE_CELLS
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


# --- DISTANCE V4 STAGE 6: WHAT THE PORT ACTUALLY BOUGHT -----------------------
#
#     godot --headless --path . -- --host --seed 42 --far-probe --bench
#
# Appended, and nothing above it is touched. Hard rule 4: the far probe may
# gain code, it may not lose assertions.
#
# THREE MEASUREMENTS, AND THEY ANSWER THREE DIFFERENT QUESTIONS.
#
#   JOB TIME, INTERLEAVED ABAB. The mesher's own work at three vantages, on the
#   main thread, with nothing else happening. GDScript and C++ alternate mesh by
#   mesh rather than run-block by run-block, because STATUS.md item 5 is this
#   project's most expensive lesson: this box drifts, and a block of A followed
#   by a block of B measures the drift as well as the change. This is the least
#   contended number available and it is the honest measure of THE PORT.
#
#   WALL TIME THROUGH FarField, THE POOL IDLE. rebuild_in_place() called the way
#   the F4 panel calls it, which is a person standing still moving a slider. It
#   includes the worker handoff and the main-thread upload, so it is the number
#   Marcel feels and the one "far_ring_div 4 is playable" has to be judged on.
#
#   THE UPLOAD, MEASURED ON ITS OWN. ChunkMesher.arrays_to_mesh() runs on the
#   main thread, at div 4's vertex count, and this port does not touch it.
#   STATUS items 11 and 17 are exactly this cost and tonight makes the mesh it
#   uploads bigger without making the upload faster - so its number goes on the
#   record where the morning can see it rather than being discovered later.

## Meshes per vantage per leg. Three, per the plan's "three runs each".
const BENCH_REPEATS := 3

## The ladder the night is about: 2 is what ships, 4 is the 1 m cell.
const BENCH_DIVS := [2.0, 4.0]


func _bench_table() -> void:
	var mesher := FarMesher.new()
	var have_cpp := FarMesher.available() \
		and mesher.setup(_heightmap, _generator, _config)
	print("[FarBench] c++ mesher: %s" % ["present" if have_cpp else "ABSENT"])
	if not have_cpp:
		print("[FarBench] nothing to compare - build gdext and re-run")
		return
	print("[FarBench] box ganymede, editor target, headless, seed %d" % _world.world_seed)
	print("[FarBench] job time is INTERLEAVED ABAB, %d meshes per vantage per leg" % [
		BENCH_REPEATS])

	var div_was: float = _config.far_ring_div
	var cpp_was: float = _config.far_cpp
	for div in BENCH_DIVS:
		_config.far_ring_div = div
		# The overlap is derived from the divisor through base_step_blocks, and
		# it is a static both meshers read - so it is pushed on the main thread
		# whenever the divisor moves, exactly as FarField does it.
		FarField.apply_overdraw(_config)
		# The knobs crossed at setup(); the divisor crosses again with every
		# build(), so the mesher does not need re-marshalling here.
		await _bench_jobs(div, mesher)
		await _bench_wall(div)
	_config.far_ring_div = div_was
	_config.far_cpp = cpp_was
	FarField.apply_overdraw(_config)


## The mesher's own time, GDScript against C++, alternating mesh by mesh.
func _bench_jobs(div: float, mesher: FarMesher) -> void:
	var gd := PackedFloat32Array()
	var cpp := PackedFloat32Array()
	var verts_gd := 0
	var verts_cpp := 0
	for v in _vantages():
		var centre: Vector2i = v["centre"]
		for k in BENCH_REPEATS:
			await get_tree().process_frame
			var job := FarFieldJob.new()
			job.heightmap = _heightmap
			job.generator = _generator
			job.config = _config
			job.center = centre
			job.run()
			gd.append(float(job.elapsed_ms))
			verts_gd = job.vertex_count
			await get_tree().process_frame
			mesher.build(_config, centre, PackedInt32Array())
			cpp.append(float(mesher.elapsed_ms))
			verts_cpp = mesher.vertex_count
	var g := _bench_median(gd)
	var c := _bench_median(cpp)
	print("[FarBench] div %.0f  job  gdscript median %7.0f ms (%.0f-%.0f)   c++ median %6.0f ms (%.0f-%.0f)   %.1fx   %d/%d verts%s" % [
		div, g[0], g[1], g[2], c[0], c[1], c[2],
		g[0] / maxf(c[0], 1.0), verts_gd, verts_cpp,
		"" if verts_gd == verts_cpp else "  VERTEX COUNTS DIFFER"])


## The wall time a person standing still actually waits, both ways.
func _bench_wall(div: float) -> void:
	var far_field: Node = _world.get_node_or_null("FarField")
	if far_field == null or not far_field.has_method("rebuild_in_place"):
		print("[FarBench] div %.0f  wall: no FarField to ask" % div)
		return
	var walls := {"gdscript": PackedFloat32Array(), "c++": PackedFloat32Array()}
	var uploads := PackedFloat32Array()
	var verts := 0
	for k in BENCH_REPEATS:
		# ALTERNATING, for the reason the job leg alternates.
		for leg in [0.0, 1.0]:
			_config.far_cpp = leg
			var before: int = far_field.stats()["rebuilds"]
			if not far_field.rebuild_in_place():
				print("[FarBench] div %.0f  wall: FarField refused" % div)
				return
			var frames := 0
			while int(far_field.stats()["rebuilds"]) == before and frames < 100000:
				await get_tree().process_frame
				frames += 1
			var st: Dictionary = far_field.stats()
			walls[String(st.get("mesher", "?"))].append(float(st["wall_ms"]))
			verts = int(st["vertices"])
	var g := _bench_median(walls["gdscript"])
	var c := _bench_median(walls["c++"])
	print("[FarBench] div %.0f  wall gdscript median %7.0f ms (%.0f-%.0f)   c++ median %6.0f ms (%.0f-%.0f)   %.1fx   %d verts" % [
		div, g[0], g[1], g[2], c[0], c[1], c[2],
		g[0] / maxf(c[0], 1.0), verts])

	# THE UPLOAD, ON ITS OWN. STATUS items 11 and 17: arrays_to_mesh runs on the
	# main thread and this port does not touch it. Measured here so the morning
	# has the number rather than the inference.
	var job := FarFieldJob.new()
	job.heightmap = _heightmap
	job.generator = _generator
	job.config = _config
	job.center = _vantages()[0]["centre"]
	job.run()
	for k in BENCH_REPEATS:
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		var m := ChunkMesher.arrays_to_mesh(job.arrays)
		uploads.append(float(Time.get_ticks_usec() - t) / 1000.0)
		m = null
	var u := _bench_median(uploads)
	print("[FarBench] div %.0f  upload arrays_to_mesh median %6.2f ms (%.2f-%.2f) at %d vertices, MAIN THREAD, unchanged by this port" % [
		div, u[0], u[1], u[2], job.vertex_count])


## Median, low, high.
func _bench_median(values: PackedFloat32Array) -> Array:
	if values.is_empty():
		return [0.0, 0.0, 0.0]
	var sorted := values.duplicate()
	sorted.sort()
	return [sorted[sorted.size() / 2], sorted[0], sorted[sorted.size() - 1]]


# --- DISTANCE V5 STAGE 0 - the two instruments this night's gates need --------
#
# Appended at the end of the file; nothing above it is touched.
#
# `--bench` already measures the upload and the rebuild, and it is expensive to
# run - it takes the GDScript mesher through every vantage, which is 27 minutes
# of table at div 4. Both modes below are the cheap C++-only halves of numbers
# distance v5 has to take at Stage 0 and again at every stage that claims to
# have moved one.


## HOW LONG AN UPLOAD BLOCKS THE FRAME, C++ ONLY. `--far-probe --upload`.
##
## STATUS items 11 and 17, and this night's first subject: the mesh crosses to
## the renderer on the MAIN THREAD, at 224 ms a rebuild at far_ring_div 4, and
## distance v4 promoted that from a footnote to the far country's binding cost.
##
## Measured at both divisors, because the whole point of the number is how it
## scales with the vertex count. Reported per divisor with the vertex count
## beside it, so a later reading against a budgeted uploader is comparing like
## with like: the SAME arrays, the same box, the same target.
func _upload_table() -> void:
	var mesher := FarMesher.new()
	if not FarMesher.available() or not mesher.setup(_heightmap, _generator, _config):
		print("[FarUpload] no c++ mesher - build gdext and re-run")
		get_tree().quit(1)
		return
	print("[FarUpload] box ganymede, editor target, headless, seed %d, main thread" % [
		_world.world_seed])
	var div_was: float = _config.far_ring_div
	var centre: Vector2i = _vantages()[0]["centre"]
	for div in BENCH_DIVS:
		_config.far_ring_div = div
		FarField.apply_overdraw(_config)
		mesher.build(_config, centre, PackedInt32Array())
		var ms := PackedFloat32Array()
		for k in BENCH_REPEATS:
			await get_tree().process_frame
			var t := Time.get_ticks_usec()
			var m := ChunkMesher.arrays_to_mesh(mesher.arrays)
			ms.append(float(Time.get_ticks_usec() - t) / 1000.0)
			m = null
		var u := _bench_median(ms)
		print("[FarUpload] div %.0f  whole  arrays_to_mesh median %7.2f ms (%.2f-%.2f) at %d vertices" % [
			div, u[0], u[1], u[2], mesher.vertex_count])

		# DISTANCE V5 STAGE 1: THE SAME MESH, A SECTOR AT A TIME. The total is
		# the same work - it has to be, it is the same quads - and the number
		# the frame budget is about is the WORST SLICE, because a slice is
		# atomic and is therefore the largest single thing a frame can be made
		# to pay for.
		mesher.build(_config, centre, PackedInt32Array(), true)
		var totals := PackedFloat32Array()
		var worsts := PackedFloat32Array()
		var surfaces := 0
		for k in BENCH_REPEATS:
			await get_tree().process_frame
			var m := ArrayMesh.new()
			var total := 0.0
			var worst := 0.0
			surfaces = 0
			for arrays in mesher.slices:
				if (arrays as Array).is_empty():
					continue
				var t := Time.get_ticks_usec()
				m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				var one := float(Time.get_ticks_usec() - t) / 1000.0
				total += one
				worst = maxf(worst, one)
				surfaces += 1
			totals.append(total)
			worsts.append(worst)
			m = null
		var ts := _bench_median(totals)
		var ws := _bench_median(worsts)
		print("[FarUpload] div %.0f  sliced total  median %7.2f ms (%.2f-%.2f) over %d surfaces, WORST SLICE median %6.2f ms (%.2f-%.2f)" % [
			div, ts[0], ts[1], ts[2], surfaces, ws[0], ws[1], ws[2]])
	_config.far_ring_div = div_was
	FarField.apply_overdraw(_config)


## HOW OFTEN THE FAR SYSTEMS REBUILD WHILE THE PLAYER STANDS STILL.
## `--far-probe --idle [--idle-seconds N]`, default 60.
##
## Distance v4 Stage 8 found the impostor ring rebuilding 70-120 times over a
## single stationary tour vantage (STATUS item 21) and could only find it
## because a tour log happened to be open. Nothing in the project MEASURED it,
## so distance v5 Stage 2's gate - "standing 60 s, 0 rebuilds" - had no
## instrument to be read on. This is that instrument.
##
## It does nothing at all: the player is wherever the world put them, the probe
## sleeps for N seconds of real frames and counts what the two far systems did
## in the meantime. Anything above zero is work nobody asked for, and the frame
## histogram beside it says what that work costs.
##
## TreeField is Game's child rather than World's, so it is reached through the
## parent by name - the same way debug_hud and screenshot_tour reach it, and
## for the same reason: `scripts/game/game.gd` is another lane's file.
const IDLE_SECONDS := 60.0


func _idle_table() -> void:
	var far_field: Node = _world.get_node_or_null("FarField")
	var tree_field: Node = null
	if _world.get_parent() != null:
		tree_field = _world.get_parent().get_node_or_null("TreeField")
	var seconds := IDLE_SECONDS
	var argv := OS.get_cmdline_user_args()
	var at := argv.find("--idle-seconds")
	if at >= 0 and at + 1 < argv.size():
		seconds = maxf(float(argv[at + 1]), 1.0)

	var field_before := 0
	if far_field != null and far_field.has_method("stats"):
		field_before = int(far_field.stats()["rebuilds"])
	var trees_before := _idle_tree_count(tree_field)

	print("[FarIdle] standing still for %.0f s at %s, far_ring_div %.0f, mesher %s" % [
		seconds, str(_world.get_parent().get_node("Player").global_position
			if _world.get_parent() != null
				and _world.get_parent().has_node("Player") else Vector3.ZERO),
		_config.far_ring_div,
		"c++" if _config.far_cpp > 0.5 else "gdscript"])

	var frames := 0
	var over_33 := 0
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		var f0 := Time.get_ticks_usec()
		await get_tree().process_frame
		var ms := float(Time.get_ticks_usec() - f0) / 1000.0
		frames += 1
		worst = maxf(worst, ms)
		if ms > 33.0:
			over_33 += 1

	var field_after := field_before
	if far_field != null and far_field.has_method("stats"):
		field_after = int(far_field.stats()["rebuilds"])
	print("[FarIdle] %d frames in %.0f s: far field %d rebuilds, impostor ring %d rebuilds" % [
		frames, seconds, field_after - field_before,
		_idle_tree_count(tree_field) - trees_before])
	print("[FarIdle] worst frame %.1f ms, frames over 33 ms %d" % [worst, over_33])


## How many rings TreeField has built. It reports impostors and milliseconds and
## not a count of rebuilds, so the count is taken off the signal - connected
## here rather than added to that file, which the trees lane owns.
var _idle_tree_rebuilds := 0
var _idle_tree_hooked := false


func _idle_tree_count(tree_field: Node) -> int:
	if tree_field != null and not _idle_tree_hooked \
			and tree_field.has_signal("rebuilt"):
		tree_field.rebuilt.connect(func(_c: int, _ms: int) -> void:
			_idle_tree_rebuilds += 1)
		_idle_tree_hooked = true
	return _idle_tree_rebuilds
