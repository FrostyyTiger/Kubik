class_name StreamProbe

## TODO(marcel): THIS PROBE CAN COMPARE TWO COMMITS - ON A DEDICATED BOX,
## INTERLEAVED, REPORTING MEDIANS. Everything below was written when the only
## comparative data came from a contended desktop, and it concluded the probe
## could not compare commits at all. That was too pessimistic; see the
## amendment at the end of this note. The diagnosis of WHY those runs were
## useless is unchanged and is still the useful part.
##
## It is a good gate - "did this build ever drop a frame or leave a hole" - and
## it is not a measuring instrument, which is what world feel v1 kept trying to
## use it as. Ten runs on one Forward+ box, seed 42, --view High:
##
##     8500d3e, identical code, three runs:   0,  0, 12  long frames
##     add4b2e, identical code, twice:       29, 14      long frames
##     across all ten runs:      0-40 long frames, 61-151 chunks/s
##
## The same commit produced PASS PASS FAIL. The commits do not order
## monotonically inside that spread - one measured worse than both commits that
## come after it - and the confound is RUN ORDER: the runs were sequential, the
## box drifts downward across a session, and the first run of the day was the
## fastest thing measured while the last run of the same commit was among the
## slowest. Thermal or background load, not code.
##
## TWO THINGS MAKE IT WORSE THAN ORDINARY NOISE.
##
## The headline is a THRESHOLD COUNT. "Frames over 33 ms" turns a continuous,
## drifting quantity into a coin flip for every frame sitting near the line, so
## a few percent of drift near the boundary swings the count by tens. built/s
## is the continuous quantity underneath it and moves far more sanely.
##
## And a run takes twenty-five minutes, which is exactly long enough that
## nobody runs it twice, which is how every night-2 performance number in this
## project came to be a single-run comparison.
##
## WHAT WOULD ACTUALLY ANSWER IT, if a number is ever needed:
##
##   - INTERLEAVE the commits ABABAB. Running all of A then all of B measures
##     the session as much as the code, which is precisely what happened.
##   - At least FIVE runs each.
##   - Report the MEDIAN of chunks/s with its spread. Not a long-frame count,
##     and not a mean - one thermally throttled run drags a mean and leaves a
##     median alone.
##   - Print the RUN ORDER and a wall clock, so drift is visible in the output
##     rather than reconstructed afterwards.
##
## THE PAIR PROBE ALREADY DOES THIS AND IT WORKS, which is why the list above
## is a shape rather than a hope. Run twice on the same box in the same session
## that swung this probe from 0 to 12 long frames on identical code, it
## reported a median prediction error of 0.217 m BOTH TIMES - reproducible to
## three decimal places - and a p95 agreeing to one millimetre. It takes a
## median over thousands of per-frame samples; this takes a count over a
## threshold. That is the whole difference.
##
## Until then: trust `holes`, which is a count of a discrete event and was
## stable at 0 across all ten runs, and treat the frame numbers as a smoke
## alarm rather than as a measurement.
##
## --- AMENDMENT, 2026-08-27: RUN THEM ON GANYMEDE ---------------------------
##
## The ten runs above were all taken on a Windows DESKTOP, which has a
## compositor, a browser and another game competing for the card. Two runs of
## identical code on ganymede - headless, an X server that exists only to
## satisfy a windowing call, nothing else on the machine - vary by about NINE
## percent on chunks/s (78.1 - 85.2) against about SIXTY percent on the desktop
## (93.3 - 150.7).
##
## The faster machine is the less trustworthy instrument, and it is not the
## card's fault. So: comparative runs belong HERE, not on the fast box. The
## method in the list above is unchanged - interleave ABAB, five runs each,
## median chunks/s with its spread, print the run order - it simply has
## somewhere to run now.
##
## (Ganymede was itself useless for this until 2026-08-27, for a reason worth
## knowing: it shipped with the COMPUTE-ONLY nvidia driver, so Vulkan found no
## ICD and Mesa fell back to llvmpipe. Every world feel v1 frame time was drawn
## on the CPU by a rasteriser competing with the chunk workers for cores. One
## package - libnvidia-gl-595 - and the worst frame went from ~700 ms to
## ~38 ms. If a frame number here ever looks impossible again, check
## `vulkaninfo --summary` before believing it.)

extends Node

## Measures whether the ground keeps up with the player, and quits.
##
##     godot --headless --path . -- --host --seed 42 --stream-probe
##     godot --headless --path . -- --host --seed 42 --stream-probe --strict
##
## WHY THIS EXISTS, AND WHY IT WALKS. The flora probe measures a teleport,
## which is the harshest case of streaming and the easiest to reason about.
## What the playtest actually reported - "the world unloads in front of me
## when I sprint" - is a real-time thing: a hole is a frame in which there is
## nothing under or ahead of you, and a teleport cannot show one because
## nothing is moving while the world catches up.
##
## So this has two parts. The JUMPS are the flora probe's twelve, kept so the
## two probes' terrain numbers can be read against each other. The SPRINT is
## the new half: 13 m/s along +X for 240 m and back, in real frames, sampling
## four times a second.
##
## WHAT IT MEASURES, and each one is a different failure:
##
##   frontier_m  How far ahead of the player, along the way they are going,
##               the collidable ground reaches. NEGATIVE means the player is
##               past the edge of the world that exists - they are running on
##               ground that has not arrived. The 10th percentile is the
##               number to tune against; the minimum is the worst moment.
##   hole        A wanted column inside the voxel radius that is neither
##               collidable NOR covered by the far mesh. This is the one the
##               plan's hard rule S1 forbids outright: the far field must
##               cover whatever the voxels have not reached, at any speed.
##   frame_ms    The crossing hitch. A column crossing does a lot of work in
##               one frame and the plan's budget is 33 ms.
##   built/s     Supply. The whole of night 1's first half is this number.
##
## WALL CLOCK, on purpose, and the same discipline as the flora probe: workers
## run on the wall clock whatever the frame rate does, and "is the ground there
## when I get to it" is a wall-clock question.
##
## Physics is off on the player so it does not fall through ground that is not
## there yet, and so the sprint is exactly 13.0 m/s rather than whatever the
## character controller does on a slope.

const STEPS := 6
const STEP_M := 48.0
const SETTLE_TIMEOUT_MS := 60000

## The sprint. 13.0 m/s is the character's sprint speed; 240 m is five column
## crossings out, which is long enough for the backlog to reach steady state
## and short enough to stay inside the meadow the spawn search guarantees.
const SPRINT_SPEED := 13.0
const SPRINT_M := 240.0
const SAMPLE_S := 0.25

var _world: Node = null
var _player: Node3D = null
var _rows: Array = []
var _sprint: Array = []


func run(world: Node, player: Node3D) -> void:
	_world = world
	_player = player
	_go.call_deferred()


func _go() -> void:
	print("[StreamProbe] waiting for the first world load")
	while not _world.is_idle():
		await get_tree().process_frame
	_player.set_physics_process(false)
	var start: Vector3 = _player.global_position
	print("[StreamProbe] start at (%.0f, %.0f), %d chunks loaded" % [
		start.x, start.z, _world.loaded_chunk_count()])

	for i in STEPS:
		await _jump(start + Vector3(STEP_M * float(i + 1), 0.0, 0.0), "out %d" % (i + 1))
	for i in STEPS:
		await _jump(start + Vector3(STEP_M * float(STEPS - i - 1), 0.0, 0.0), "back %d" % (i + 1))

	# Back to where we began, settled, before the sprint - so the sprint starts
	# from a full world exactly as a player standing still would.
	_player.global_position = start
	await _settle()
	await _sprint_leg(start, Vector3(1.0, 0.0, 0.0), "sprint out")
	await _sprint_leg(_player.global_position, Vector3(-1.0, 0.0, 0.0), "sprint back")

	_report()
	get_tree().quit(1 if (_strict() and _failed()) else 0)


# --- The jumps ----------------------------------------------------------------

func _jump(to: Vector3, label: String) -> void:
	var built_before: int = _world.built_chunk_count()
	_player.global_position = to
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	await get_tree().process_frame
	var terrain_ms := -1
	while Time.get_ticks_msec() - t0 < SETTLE_TIMEOUT_MS:
		if _terrain_idle():
			terrain_ms = Time.get_ticks_msec() - t0
			break
		await get_tree().process_frame
	_rows.append({
		"label": label,
		"terrain_ms": terrain_ms,
		"built": _world.built_chunk_count() - built_before,
	})
	print("[StreamProbe] %s: terrain %d ms, %d chunks built" % [
		label, terrain_ms, _world.built_chunk_count() - built_before])


func _settle() -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < SETTLE_TIMEOUT_MS and not _terrain_idle():
		await get_tree().process_frame


# --- The sprint ---------------------------------------------------------------

## Move at exactly SPRINT_SPEED along `dir` for SPRINT_M, sampling as we go.
##
## The player is moved by wall-clock delta rather than by frame count, because
## the frame rate is the thing under test: at 20 fps a frame-stepped walk would
## quietly halve the speed and the probe would report a world that keeps up.
func _sprint_leg(from: Vector3, dir: Vector3, label: String) -> void:
	var built_before: int = _world.built_chunk_count()
	var t0 := Time.get_ticks_usec()
	var last_sample := 0.0
	var last_frame := t0
	var samples := []
	var max_frame_ms := 0.0
	var over_33 := 0
	var travelled := 0.0

	while travelled < SPRINT_M:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - last_frame) / 1000.0
		last_frame = now
		max_frame_ms = maxf(max_frame_ms, frame_ms)
		if frame_ms > 33.0:
			over_33 += 1
		var elapsed := float(now - t0) / 1000000.0
		travelled = minf(elapsed * SPRINT_SPEED, SPRINT_M)
		_player.global_position = from + dir * travelled
		if elapsed - last_sample < SAMPLE_S:
			continue
		last_sample = elapsed
		samples.append({
			"frontier_m": _frontier_ahead(dir),
			"holes": _hole_count(),
		})

	var seconds := float(Time.get_ticks_usec() - t0) / 1000000.0
	var fronts := []
	var hole_samples := 0
	var worst_holes := 0
	for s in samples:
		fronts.append(s["frontier_m"])
		if s["holes"] > 0:
			hole_samples += 1
		worst_holes = maxi(worst_holes, s["holes"])
	fronts.sort()
	_sprint.append({
		"label": label,
		"samples": samples.size(),
		"frontier_min": fronts[0] if not fronts.is_empty() else 0.0,
		"frontier_p10": fronts[int(float(fronts.size()) * 0.1)] if not fronts.is_empty() else 0.0,
		"hole_samples": hole_samples,
		"worst_holes": worst_holes,
		"max_frame_ms": max_frame_ms,
		"over_33": over_33,
		"built_per_s": float(_world.built_chunk_count() - built_before) / maxf(seconds, 0.001),
		"seconds": seconds,
	})
	print("[StreamProbe] %s: %d samples over %.1f s" % [label, samples.size(), seconds])


## How far ahead of the player, along `dir`, the collidable ground reaches.
##
## Walks out along the travel direction in chunk steps and stops at the first
## column whose surface chunk is not collidable. Negative when the column the
## player is standing in is itself not collidable - which is the state the
## playtest was describing.
func _frontier_ahead(dir: Vector3) -> float:
	var bs: float = _world.config.block_size
	var reach: int = _world.config.voxel_radius_chunks
	var here := _player.global_position
	for i in range(0, reach + 1):
		var at := here + dir * (float(i) * float(Chunk.SIZE) * bs)
		if not _column_collidable(at):
			return float(i) * float(Chunk.SIZE) * bs - (0.0 if i > 0 else float(Chunk.SIZE) * bs)
	return float(reach) * float(Chunk.SIZE) * bs


## Is the surface of the column at this world position something to stand on?
func _column_collidable(at: Vector3) -> bool:
	var block := Vector3i(int(floor(at.x / _world.config.block_size)), 0,
		int(floor(at.z / _world.config.block_size)))
	var cx := Chunk.floor_div(block.x, Chunk.SIZE)
	var cz := Chunk.floor_div(block.z, Chunk.SIZE)
	# ANNOTATED, not inferred: _world is an untyped Node here (Game holds it as
	# one), so the compiler cannot see what surface_at returns and refuses to
	# infer. Same for every other call through _world in this file.
	var surface: float = _world.generator.surface_at(float(block.x), float(block.z))
	var cy := Chunk.floor_div(int(surface), Chunk.SIZE)
	return _world.is_chunk_collidable(Vector3i(cx, cy, cz))


## Wanted columns inside the voxel radius that are neither collidable nor
## covered by the far mesh.
##
## Sampled on a coarse ring rather than over the whole disc: the disc is 450
## columns and this runs four times a second inside the thing it is measuring.
## Sixteen directions at four radii is enough to catch a leading edge, which is
## the only place a hole has ever been.
func _hole_count() -> int:
	var bs: float = _world.config.block_size
	var reach := float(_world.config.voxel_radius_chunks) * float(Chunk.SIZE) * bs
	var here := _player.global_position
	var holes := 0
	for a in 16:
		var ang := TAU * float(a) / 16.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		for r in range(1, 5):
			var d := reach * float(r) / 4.0
			var at := here + dir * d
			if _column_collidable(at):
				continue
			# Not collidable. Is the far mesh covering it? Stage 3 makes this
			# per sector; until then the far field's exclusion is one radius.
			if d < _world.far_field_exclusion_m(dir):
				holes += 1
	return holes


# --- Reporting ----------------------------------------------------------------

func _report() -> void:
	print("[StreamProbe] %-10s %10s %8s" % ["jump", "terrain", "built"])
	var out_ms := 0
	var back_ms := 0
	for r in _rows:
		print("[StreamProbe] %-10s %7d ms %8d" % [r["label"], r["terrain_ms"], r["built"]])
		if String(r["label"]).begins_with("out"):
			out_ms += int(r["terrain_ms"])
		else:
			back_ms += int(r["terrain_ms"])
	print("[StreamProbe] 48 m settle: out mean %d ms, back mean %d ms" % [
		out_ms / maxi(STEPS, 1), back_ms / maxi(STEPS, 1)])

	print("[StreamProbe] %-12s %9s %9s %7s %7s %9s %7s %9s" % [
		"leg", "front min", "front p10", "holes", "worst", "max frame", "> 33", "built/s"])
	for s in _sprint:
		print("[StreamProbe] %-12s %7.1f m %7.1f m %7d %7d %6.1f ms %7d %9.1f" % [
			s["label"], s["frontier_min"], s["frontier_p10"], s["hole_samples"],
			s["worst_holes"], s["max_frame_ms"], s["over_33"], s["built_per_s"]])
	# THE CACHE'S FOOTPRINT. The plan puts a 250 MB ceiling on it; static memory
	# at the end of a run that has parked and restored the whole trail is the
	# cheapest honest measure of it on this box.
	# BODY CHURN, world feel v1 Stage 12. Not how many bodies exist - how many
	# times one was built. Each is three nodes, a shape and a physics
	# registration on the main thread, and building them on the wrong streaming
	# boundary is invisible in every count and expensive in every frame.
	if _world.body_field != null:
		print("[StreamProbe] bodies %d loaded, %d built and %d freed over the run" % [
			_world.body_field.count(), _world.body_field.spawns,
			_world.body_field.frees])
	print("[StreamProbe] cache %d chunks, static memory %.1f MB" % [
		_world.last_timings().get("cached_chunks", 0),
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0])
	var verdict := "PASS" if not _failed() else "FAIL"
	print("[StreamProbe] holes %d, frames over 33 ms %d (strict allows %d): %s" % [
		_total_holes(), _total_over_33(), LONG_FRAMES_ALLOWED, verdict])


func _total_holes() -> int:
	var n := 0
	for s in _sprint:
		n += int(s["hole_samples"])
	return n


func _total_over_33() -> int:
	var n := 0
	for s in _sprint:
		n += int(s["over_33"])
	return n


## MORE THAN ONE LONG FRAME, distance v2 Stage 0 and decision 11 - it used to
## be more than zero.
##
## This is a STANDARD, not a measurement, and the measurement behind it is
## settled: twelve `--view High --strict` runs on ganymede across three
## interleaved ABAB batches gave 0 or 1 frames over 33 ms EVERY time, on both
## sides of two nights of far-field work (docs/status/distance-v1.md, carried
## item 6). So the old rule exited 1 on about half of all clean runs, which
## makes a gate a coin flip rather than a signal - exactly what this file's own
## note at the top says a threshold count does to a drifting quantity.
##
## One long frame in a three-minute sprint is a hitch nobody reports. Two is a
## pattern. Holes stay at zero: that one is hard rule S1 and is not a
## threshold, it is a property.
const LONG_FRAMES_ALLOWED := 1


## What --strict fails on. The plan turns each half on at the stage that is
## meant to fix it: holes from Stage 3, the frame budget from Stage 4. Before
## those the baseline is EXPECTED to fail, and that is the point of it.
func _failed() -> bool:
	return _total_holes() > 0 or _total_over_33() > LONG_FRAMES_ALLOWED


func _strict() -> bool:
	return "--strict" in OS.get_cmdline_user_args()


func _terrain_idle() -> bool:
	# ONE IN-FLIGHT SET SINCE WORLD FEEL V1 STAGE 1. There used to be two, one
	# per phase; a chunk in flight now means voxels, mesh and collision faces
	# all still out at the pool. Asking for the set that no longer exists made
	# this answer false forever, and the probe reported a settle of -1.
	return _world.queued_chunk_count() == 0 and _world._in_flight.is_empty()
