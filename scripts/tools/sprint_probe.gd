class_name SprintProbe
extends Node

## Measures the frame while the player is SPRINTING, and quits.
##
##     godot --headless --path . -- --host --seed 42 --sprint-probe --label x
##
## THE INSTRUMENT THIS PROJECT HAS NEVER HAD, and the north star's third
## sentence cannot be judged without it: "60 FPS at max settings on mid
## hardware, measured while sprinting through forest". Every frame number in
## this repository before tonight was taken by the screenshot tour, which
## STANDS STILL at a settled vantage and photographs it - the one condition
## under which the far field never rebuilds, the chunk queue is empty and the
## tree ring has nothing to do. That is the frame the player never sees.
##
## So this one runs. Sixty seconds of held sprint from spawn along +X, every
## frame's delta recorded, and the summary printed as one machine-parseable
## line.
##
##
## IT EXITS BY CONSTRUCTION, AND THAT IS ITS FIRST GATE.
##
## `stream_probe.gd` is retired tonight (grill Q22) for the opposite property:
## it waits on a world condition, and a world condition that never arrives is a
## probe that never returns. This box has produced one of those, and STATUS.md
## carries the lesson at the top. Three things here make that impossible:
##
##   1. THE RUN IS BOUNDED BY FRAMES, not by distance, not by chunks and not by
##      "the world is loaded". `--seconds` of process time elapses whatever the
##      world does; a player wedged against a cliff still finishes.
##   2. THE WATCHDOG IS BOUNDED TOO. If the ground has not arrived within
##      WATCHDOG_S of process time the probe writes WATCHDOG and quits(2). A
##      non-zero exit with a reason beats a hang with none.
##   3. PROGRESS IS FLUSHED EVERY SECOND. Godot buffers stdout under
##      redirection - light v1's Q23 - so a run killed at 04:00 leaves sixty
##      lines on disk rather than an empty file and a mystery. The per-second
##      file is written with `FileAccess.flush()` after every line.
##
##
## WHAT IT REPORTS, and each number answers a different question.
##
##   median_ms   the frame the player is in most of the time. The GATE: under
##               16.7 ms is 60 FPS.
##   p99_ms      the tail. A median that passes with a fat tail is a game that
##               stutters, and the eye finds a stutter faster than it finds a
##               low average.
##   worst_ms    the single worst frame of the run.
##   over25      how many frames took longer than 25 ms - the plan's second
##               gate, and it is a COUNT rather than a percentage because the
##               gate is zero.
##   chunks      voxel chunks built during the run. The load the frame was
##               carrying, so two runs with different chunk counts are not
##               comparable and the probe says so rather than the reader
##               having to know.
##   far_rebuilds / far_ms_median
##               how often the far country was rebuilt and what a rebuild cost
##               on its worker. Stage 3's own gate.
##   tree_rebuilds  the same for the impostor ring.
##   mem_mb      static memory at the end. The tile store's eviction is judged
##               on it (failure protocol item 12).
##
##
## THE BOX DRIFTS. One run of this proves nothing about a change: ganymede
## shares a GPU with the mesher lane tonight and shares its cores with
## whatever else is on it. A comparison is three runs ABAB, medians and
## spread, and the counts - chunks, rebuilds - are what say whether the two
## runs were even measuring the same walk.

## Where the per-second progress lands. Relative to res://.
const OUT_DIR := "res://build/probe"

## Seconds of sprint, unless --seconds says otherwise.
const DEFAULT_SECONDS := 60.0

## How long the ground has to arrive before the run is declared broken.
## Process time, so a headless box that is merely slow still finishes; a world
## that never spawns does not.
const WATCHDOG_S := 120.0

## A beat of standing still after the ground arrives, before the sprint starts.
## The first frames after release carry the spawn chunk's collision upload and
## the first far-field handover, and neither is a frame the player is walking
## through.
const SETTLE_S := 1.0

## The frame the gate is written against, in milliseconds. 60 FPS.
const GATE_MEDIAN_MS := 16.7

## And the tail's. A frame over this is a visible hitch.
const GATE_WORST_MS := 25.0

## THE STUCK DETECTOR'S TWO NUMBERS - see `_check_stuck`. Half a metre is a
## block; half a second is long enough that a normal step-up is not read as
## being stuck and short enough that a wedge costs a fraction of a second of
## the sample.
const STUCK_M := 0.5
const STUCK_S := 0.5

## How far a real sprint gets in a second: WALK_SPEED x SPRINT_MULTIPLIER. Used
## only to decide whether a run covered enough ground to be called one.
const SPRINT_MPS := 13.0

var _world: World = null
var _player: Player = null
var _game: Node = null

var _label := "sprint"
var _seconds := DEFAULT_SECONDS

## Where the per-second lines go, held open for the whole run so the flush is
## a flush and not a reopen.
var _file: FileAccess = null

## Process time since run() started, in seconds. Its own accumulator rather
## than Time.get_ticks_msec() because the watchdog and the sprint must measure
## the same clock as the deltas that are being recorded.
var _t := 0.0

## When the sprint started, on that same clock. -1 until the ground arrives.
var _sprint_from := -1.0

## Every frame's delta during the sprint, in milliseconds.
var _frames := PackedFloat32Array()

## The second currently being accumulated, and what happened in it.
var _sec := 0
var _sec_frames := PackedFloat32Array()
var _sec_far := 0
var _sec_slices := 0
var _sec_rebase := 0

## Counts at the moment the sprint started, so every total is a DELTA over the
## sprint rather than a total since the world loaded. The load is the biggest
## number in the session and it is not what is being measured.
var _base_chunks := 0
var _base_far := 0
var _base_rebases := 0
var _base_tree := 0
var _base_uploaded := 0

## When the settle began, on the process clock, and where the sprint started.
## `_sprint_from` is the state machine: -1 waiting for ground, -2 settling, a
## real time sprinting since.
var _settle_at := 0.0
var _start_m := Vector3.ZERO

## Slices uploaded and origin rebases as of the last per-second line.
var _last_uploaded := 0
var _last_rebases := 0

## THE STUCK DETECTOR. Where the body was when it was last checked, when that
## was, and how many times a jump has been asked for.
var _stuck_at := Vector3.ZERO
var _stuck_since := 0.0
var _jumps := 0

var _far_ms := PackedInt32Array()
var _last_far_rebuilds := 0
var _done := false


func run(world: World, player: Player, game: Node) -> void:
	_world = world
	_player = player
	_game = game
	var argv := OS.get_cmdline_user_args()
	_label = _arg(argv, "--label", "sprint")
	_seconds = maxf(float(_arg(argv, "--seconds", str(DEFAULT_SECONDS))), 1.0)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path := "%s/sprint-%s.txt" % [OUT_DIR, _label]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("[Sprint] could not open %s" % path)
	_say("[Sprint] label=%s seconds=%.0f preset=%s seed=%d" % [
		_label, _seconds, _world.config.view_distance_name(), _world.world_seed])
	# THE PLAYER IS NOT FROZEN BY THIS PROBE. Game releases it when the spawn
	# chunk's collision exists, exactly as it does for a person; the probe
	# waits for the same event rather than inventing a second definition of
	# "the ground is there". _process below is the whole of the run.
	set_process(true)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta

	# THE THREE PHASES, and `_sprint_from` is the whole state machine:
	#   -1  waiting for the ground under spawn. The watchdog runs here.
	#   -2  settling, one second, standing still.
	#   >=0 sprinting, since that time on the process clock.
	if _sprint_from == -1.0:
		if _t > WATCHDOG_S:
			_say("WATCHDOG no ground after %.0f s of process time" % _t)
			_finish(2)
			return
		# Game releases the player when the spawn chunk's COLLISION exists - see
		# `_release_player_when_ground_exists`. Waiting on that rather than on
		# `is_world_ready` is deliberate: the probe wants the moment a body can
		# stand, which is the moment a person could start walking.
		if not _player.is_physics_processing():
			return
		_sprint_from = -2.0
		_settle_at = _t
		return

	if _sprint_from == -2.0:
		_drive(false)
		# THE SETTLE IS THE JITTER SAMPLE. A second of a body standing on the
		# ground with no wish - which is exactly the plan's "the player's
		# standing-still position delta per frame".
		_track_jitter(false)
		if _t - _settle_at < SETTLE_S:
			return
		_begin()
		return

	_step_sprint(delta)


## Everything is counted from HERE, not from the world load.
##
## The load builds a couple of thousand chunks and rebuilds the far country
## several times; folding that into a sixty-second sprint's counters would make
## every run look identical and hide the thing being measured. So the baselines
## are taken at the first sprinting frame and every total in the summary is a
## delta.
func _begin() -> void:
	_sprint_from = _t
	_start_m = _player.world_position()
	_base_chunks = _world.built_chunk_count()
	_base_far = _far_rebuilds()
	_base_rebases = _rebases()
	_base_tree = _tree_rebuilds()
	_base_uploaded = _uploaded()
	_last_far_rebuilds = _base_far
	_last_uploaded = _base_uploaded
	_stuck_at = Vector3(_start_m.x, 0.0, _start_m.z)
	_stuck_since = _t
	_say("[Sprint] ground at %.1f s, sprinting from (%.0f, %.0f)" % [
		_t, _start_m.x, _start_m.z])


func _step_sprint(delta: float) -> void:
	_drive(true)
	_check_stuck()
	# A sprinting body is never standing still, so this records nothing here -
	# it is the settle phase that feeds it. Called from both so the number is
	# a property of the whole run.
	_track_jitter(true)

	var ms := delta * 1000.0
	_frames.append(ms)
	_sec_frames.append(ms)

	# WHAT ELSE HAPPENED IN THIS SECOND. The gate is "no per-second worst frame
	# over 25 ms ATTRIBUTABLE to a far upload", so the second has to carry what
	# it was carrying - a worst frame with no slices in it is a different fact
	# from one with four.
	var far_now := _far_rebuilds()
	if far_now != _last_far_rebuilds:
		_sec_far += far_now - _last_far_rebuilds
		_last_far_rebuilds = far_now
		var ff := _far_stats()
		if ff.has("build_ms"):
			_far_ms.append(int(ff["build_ms"]))
	var up := _uploaded()
	_sec_slices += up - _last_uploaded
	_last_uploaded = up
	# THE REBASE COUNT IS ZERO UNTIL STAGE 6 and the field is here from Stage 0
	# on purpose: the per-second line's shape is what the status doc quotes for
	# nine stages, and a column that appears half way through is a column
	# nothing can be compared across.
	_sec_rebase += _rebases() - _last_rebases
	_last_rebases = _rebases()

	var elapsed := _t - _sprint_from
	if elapsed >= float(_sec + 1):
		_write_second()
	if elapsed >= _seconds:
		_summary()
		_finish(0)


## HOW MANY TIMES THE ORIGIN HAS MOVED. A field since Stage 6, not a method.
func _rebases() -> int:
	if _world != null:
		return int(_world.origin_rebases)
	return 0


## THE JITTER, IN MILLIMETRES - horizon v1 Stage 6's gate.
##
## The plan asks for "the player's standing-still position delta per frame over
## 2 s, must be 0.0". This is that number, kept as a running worst over the
## whole run: every frame the probe is NOT pressing a wish and the body is on
## the ground, how far the body moved. On a floating origin it is zero because
## the numbers the solver sees are small; without one it is the float32 ULP at
## the player's distance from the origin, which at 30 km is 4 mm and is exactly
## what the north star's "the world is as big as the view" cannot afford.
var jitter_mm := 0.0
var _jitter_last := Vector3.ZERO
var _jitter_have := false


func _track_jitter(moving: bool) -> void:
	var here: Vector3 = _player.global_position
	if moving or not _player.is_on_floor():
		_jitter_have = false
		return
	if _jitter_have:
		jitter_mm = maxf(jitter_mm, (here - _jitter_last).length() * 1000.0)
	_jitter_last = here
	_jitter_have = true


## Hold the sprint key.
##
## THROUGH THE HOOKS THE TRAVERSAL PROBE ALREADY HAS, and not through a second
## set of them: `wish_override` is a WORLD-SPACE direction that bypasses
## `_wish_direction`'s camera rotation, and `sprint_override` is read in
## `_sample_input` beside the real Shift. So this probe drives a player exactly
## as `--traverse` does - along +X whatever the camera is doing - and
## `player.gd`'s own note applies unchanged: "a hook rather than synthesised
## key events - Input state is global and faking a held key would leak".
##
## AND IT DOES NOT JUMP. The plan says the wish and the sprint bit and nothing
## else; a probe that jumped would measure a different walk from the one the
## gate is written against. What that costs is a run that wedges against a
## cliff, so every per-second line carries `moved_m` and the summary carries
## the total and a warning - a wedged run is then visibly a wedged run rather
## than a quietly optimistic frame time.
func _drive(sprinting: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.wish_override = Vector3(1.0, 0.0, 0.0) if sprinting else Vector3.ZERO
	_player.sprint_override = sprinting


## AND IT JUMPS WHEN IT IS STUCK, which the plan did not ask for and the first
## baseline run demanded.
##
## The plan says the wish and the sprint bit and nothing else, and taken
## literally that is what the first two Ultra baselines did: both wedged
## against a rise 354 m out at second 43 and then measured SEVENTEEN SECONDS OF
## STANDING STILL. Those are the cheapest frames in the game - no chunk queue,
## no far rebuild, no tree ring - and they landed in the middle of the sample
## the 60 FPS gate is read off. The median came out flattered by a run that had
## stopped being a sprint.
##
## A frame gate measured on a stationary player is not a frame gate, so the
## body does what a person does at a rise: it presses Space. `jump_override` is
## the traversal probe's own hook and the one `player.gd` documents for exactly
## this - "voxel terrain is a staircase and a player crossing it presses Space
## a lot; a probe that never jumps measures a world nobody plays in".
##
## STILL A STRAIGHT LINE ALONG +X. It does not steer, it does not fly and it
## does not teleport past anything: if the ground genuinely will not let a
## sprinting player through, the run still wedges and the summary still says so
## in `moved_m` and in a warning. What this removes is the case where half a
## metre of step was all that stood between the probe and its own measurement.
##
## `jumps` is in the summary line, because a run that jumped forty times and a
## run that jumped twice crossed different ground and their medians are not the
## same measurement.
func _check_stuck() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var here: Vector3 = _player.world_position()
	here.y = 0.0
	if here.distance_to(_stuck_at) > STUCK_M:
		_stuck_at = here
		_stuck_since = _t
		return
	if _t - _stuck_since < STUCK_S:
		return
	# Still in the same half metre after STUCK_S of holding sprint. Ask for one
	# jump; `player.gd` consumes the flag on the next sample, so this is one
	# press and not a held key.
	_player.jump_override = true
	_jumps += 1
	_stuck_since = _t


func _write_second() -> void:
	_sec += 1
	var sorted := _sec_frames.duplicate()
	sorted.sort()
	var med := 0.0
	var worst := 0.0
	if not sorted.is_empty():
		med = sorted[sorted.size() / 2]
		worst = sorted[sorted.size() - 1]
	var moved: Vector3 = _player.world_position() - _start_m
	moved.y = 0.0
	var line := ("s=%02d frames=%d median_ms=%.2f worst_ms=%.2f "
		+ "far=%d slices=%d rebase=%d moved_m=%.0f chunks=%d") % [
		_sec, _sec_frames.size(), med, worst, _sec_far, _sec_slices,
		_sec_rebase, moved.length(),
		_world.built_chunk_count() - _base_chunks]
	_say(line)
	_sec_frames = PackedFloat32Array()
	_sec_far = 0
	_sec_slices = 0
	_sec_rebase = 0


## THE ONE LINE, machine-parseable, and the shape is the plan's.
func _summary() -> void:
	var sorted := _frames.duplicate()
	sorted.sort()
	var n := sorted.size()
	var med := 0.0
	var p99 := 0.0
	var worst := 0.0
	var over := 0
	if n > 0:
		med = sorted[n / 2]
		p99 = sorted[mini(int(float(n) * 0.99), n - 1)]
		worst = sorted[n - 1]
		for ms in sorted:
			if ms > GATE_WORST_MS:
				over += 1
	var far_med := 0
	if not _far_ms.is_empty():
		var f := _far_ms.duplicate()
		f.sort()
		far_med = f[f.size() / 2]
	var mem := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	_say(("SPRINT label=%s seconds=%.0f frames=%d median_ms=%.2f p99_ms=%.2f "
		+ "worst_ms=%.2f over25=%d chunks=%d far_rebuilds=%d far_ms_median=%d "
		+ "tree_rebuilds=%d mem_mb=%.0f moved_m=%.0f jumps=%d "
		+ "tiles=%d tile_mb=%.0f rebases=%d jitter_mm=%.3f") % [
		_label, _seconds, n, med, p99, worst, over,
		_world.built_chunk_count() - _base_chunks,
		_far_rebuilds() - _base_far, far_med,
		_tree_rebuilds() - _base_tree, mem, _moved(), _jumps,
		_tile_stat("tiles"), float(_tile_stat("bytes")) / 1048576.0,
		_rebases() - _base_rebases, jitter_mm])
	# A RUN THAT DID NOT GO ANYWHERE IS NOT A SPRINT, and it is the one way
	# this instrument can look green while measuring nothing: a player wedged
	# against a rise builds no chunks, rebuilds no far country and holds a
	# beautiful 17 ms frame. Sixty seconds at SPRINT_MPS is about 780 m; the
	# threshold is HALF of that, because the failure this has to catch is not
	# only "went nowhere" but "stopped half way and spent the rest of the
	# sample standing still", which is what the first two Ultra baselines did.
	var want_m := _seconds * SPRINT_MPS
	if _moved() < want_m * 0.5:
		_say(("SPRINT WARNING: %.0f m of an expected %.0f in %.0f s - this run "
			+ "wedged, so part of the frame sample is a standing player") % [
			_moved(), want_m, _seconds])
	# AND THE VERDICT IN WORDS, because the gate is two numbers and a reader
	# skimming a log at 4 a.m. should not have to remember which way round they
	# go. It is a READOUT and not an exit code: a failed frame gate is Stage 7's
	# subject and section 5 item 5's ladder, not a reason for a probe to return
	# non-zero and stop a run at 02:00.
	var pass_med := med > 0.0 and med < GATE_MEDIAN_MS
	_say("SPRINT gate: median %s (%.2f vs %.1f), over25 %s (%d)" % [
		"PASS" if pass_med else "FAIL", med, GATE_MEDIAN_MS,
		"PASS" if over == 0 else "FAIL", over])


func _finish(code: int) -> void:
	_done = true
	set_process(false)
	if _file != null:
		_file.close()
		_file = null
	# The world holds worker tasks; put it down while the tree is still alive.
	# Exactly ScreenshotTour._shutdown's argument, and for the same reason.
	if _world != null and is_instance_valid(_world):
		_world.reset()
	get_tree().quit(code)


## One line, to stdout AND to the progress file, flushed.
##
## BOTH, ALWAYS. stdout is what a person watching the run sees; the file is
## what survives the run being killed. Godot buffers stdout under redirection
## (light v1 Q23), so the file is the one that can be trusted at 04:00 and the
## flush is what makes it so.
func _say(line: String) -> void:
	print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()


## THE TILE STORE'S SIZE, horizon v1 Stage 1. Failure protocol item 12 is a
## memory rule with a number on it, and this is where that number comes from:
## a store whose eviction is wrong grows for the whole sprint and says so here
## rather than in a swap storm forty minutes later.
func _tile_stat(key: String) -> int:
	if _world == null or _world.generator == null \
			or _world.generator.heightmap == null:
		return 0
	return int(_world.generator.heightmap.tile_stats().get(key, 0))


## How far the player actually got, in metres, on the flat.
func _moved() -> float:
	if _player == null or not is_instance_valid(_player) or _sprint_from < 0.0:
		return 0.0
	var d: Vector3 = _player.world_position() - _start_m
	d.y = 0.0
	return d.length()


func _far_stats() -> Dictionary:
	var far_field: Node = _world.get_node_or_null("FarField")
	if far_field != null and far_field.has_method("stats"):
		return far_field.stats()
	return {}


func _far_rebuilds() -> int:
	var s := _far_stats()
	return int(s.get("rebuilds", 0))


func _uploaded() -> int:
	var far_field: Node = _world.get_node_or_null("FarField")
	if far_field != null and far_field.has_method("uploader"):
		var up = far_field.uploader()
		if up != null:
			return int(up.stats().get("uploaded", 0))
	return 0


func _tree_rebuilds() -> int:
	# TreeField is Game's child rather than World's, so it is reached through
	# the tree the way `apply_far_knobs` reaches FarField. See far_field.gd's
	# note on `uploader()`: reaching across is cheaper than a wiring line, and
	# there is exactly one of these to reach for.
	if _game == null:
		return 0
	var tf: Node = _game.get_node_or_null("TreeField")
	if tf != null and tf.has_method("rebuild_count"):
		return int(tf.rebuild_count())
	return 0


static func _arg(argv: PackedStringArray, name: String, fallback: String) -> String:
	var i := argv.find(name)
	if i >= 0 and i + 1 < argv.size():
		return argv[i + 1]
	return fallback
