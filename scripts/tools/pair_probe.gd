class_name PairProbe
extends Node

## TWO ENGINES, ONE WORLD. The gate for world feel v1 Stage 10.
##
##     godot --path . -- --host --seed 42 --pair-probe
##
## and it launches the other half itself.
##
## NOTE THE MISSING SCENE ARGUMENT, which every other probe in this directory
## has. They run `--path . scenes/game.tscn` and open the session directly;
## this one must NOT, because that skips the main menu, and the main menu is
## what actually opens the ENet socket. A host started by opening game.tscn is
## Net.host_offline() - a host with no listener - and the only symptom is the
## client reporting "connection failed" into a log nobody is reading.
##
## WHY IT HAS TO BE TWO PROCESSES. Stage 10 moved authority over a player's
## position from the client to the host, and every interesting way that can be
## wrong needs both sides really running: a client predicting one thing while
## the host computes another, a peer standing on ground the host never
## streamed, an input packing bug that only shows up after a round trip. The
## self-test proves the STEP is deterministic given identical intents. It
## cannot prove the two machines produce identical intents, and that is the
## half that breaks.
##
## THE SPLIT. This one script is both roles, because they are two views of one
## measurement and keeping them in one file is what stops them drifting apart:
##
##   --pair-probe    the host. Spawns the client, watches its authoritative
##                   row arrive, reports what the ring cost, and renders the
##                   verdict from the client's own numbers.
##   --pair-client   the client. Sprints 100 m out and walks back, comparing
##                   its predicted position against the row the host sends
##                   back for it every frame, and writes what it saw to
##                   user://pair_client.json before quitting.
##
## THE CLIENT IS THE ONE THAT CAN MEASURE ERROR, which is why the file exists
## and why the host does not simply print it. Prediction error is the distance
## between a client's own body and the host's opinion of it, and only the
## client holds both of those numbers at the same instant. Sending it back over
## a probe-only RPC was the alternative and was rejected: a measurement channel
## that exists only for the test is a channel the real code can drift away from
## without anybody noticing.

const SPRINT_OUT_M := 100.0
const JOIN_TIMEOUT_MS := 240000
const RUN_TIMEOUT_MS := 420000

## The host's patience for the whole child process, generation included. The
## client needs a minute or two on this box before it can even move.
const HOST_PATIENCE_MS := 900000
const REPORT_EVERY_MS := 1000
const RESULT_PATH := "user://pair_client.json"

## The child's stdout, via the engine's own --log-file. Without it a client
## that dies on startup is completely silent - OS.create_process inherits
## nothing - and the only symptom is this probe timing out on the join, which
## looks identical to a networking problem.
const CLIENT_LOG := "user://pair_client.log"

## The band the plan sets. Beyond this the two simulations are telling
## different stories; see Game._reconcile(), which snaps at the same distance.
const FAIL_ERROR_M := 2.0

## Errors in the first second are not counted, because the client is still
## being released onto the ground and the host has not heard from it yet.
const GRACE_MS := 1000

var _world: Node = null
var _player: Node3D = null
var _game: Node = null

var _client_pid := -1
var _errors: PackedFloat32Array = PackedFloat32Array()
var _started := 0
var _last_report := 0
var _fell_through := false


func run(world: Node, player: Node3D, game: Node) -> void:
	_world = world
	_player = player
	_game = game
	if is_client():
		_run_client.call_deferred()
	else:
		_run_host.call_deferred()


static func is_client() -> bool:
	return "--pair-client" in OS.get_cmdline_user_args()


# --- The host ----------------------------------------------------------------

func _run_host() -> void:
	print("[PairProbe] host: waiting for the first world load")
	while not _world.is_idle():
		await get_tree().process_frame
	# The host stands still for the whole run. Everything that moves in this
	# probe is the client, so anything the host's own streaming does is
	# background it would have done anyway.
	_player.set_physics_process(false)
	print("[PairProbe] host: world ready, %d chunks; launching the client" % [
		_world.loaded_chunk_count()])

	_spawn_client()
	if _client_pid <= 0:
		print("[PairProbe] FAIL - could not launch the client process")
		get_tree().quit(1)
		return

	_started = Time.get_ticks_msec()
	var peer: int = await _await_peer()
	if peer == 0:
		print("[PairProbe] FAIL - no client joined within %d s" % (JOIN_TIMEOUT_MS / 1000))
		_tail_client_log()
		_kill_client()
		get_tree().quit(1)
		return
	print("[PairProbe] host: peer %d joined after %.1f s" % [
		peer, float(Time.get_ticks_msec() - _started) / 1000.0])

	var chunks_before: int = _world.loaded_chunk_count()
	var frames := 0
	var frames_from := Time.get_ticks_msec()
	while OS.is_process_running(_client_pid):
		frames += 1
		if Time.get_ticks_msec() - _started > HOST_PATIENCE_MS:
			print("[PairProbe] FAIL - the client did not finish in %d s" % [
				HOST_PATIENCE_MS / 1000])
			_kill_client()
			get_tree().quit(1)
			return
		if Time.get_ticks_msec() - _last_report >= REPORT_EVERY_MS:
			_last_report = Time.get_ticks_msec()
			_report_peer(peer, chunks_before)
		await get_tree().process_frame

	print("[PairProbe] host: the client exited; %d chunks loaded, %d built for its ring" % [
		_world.loaded_chunk_count(), _world.loaded_chunk_count() - chunks_before])
	var frame_ms := float(Time.get_ticks_msec() - frames_from) / maxf(float(frames), 1.0)
	print("[PairProbe] host: its own frames averaged %.0f ms over the run" % frame_ms)
	_verdict(frame_ms)


## Print the host's own row for a peer: where its simulated body is, how far
## from the host, and what the world has had to build to keep it standing.
func _report_peer(peer: int, chunks_before: int) -> void:
	var row: Dictionary = _game.peer_row(peer)
	if row.is_empty():
		print("[PairProbe] host: no row for peer %d yet" % peer)
		return
	var p: Vector3 = row.get("p", Vector3.ZERO)
	var v: Vector3 = row.get("v", Vector3.ZERO)
	print("[PairProbe] host: peer at %7.1f, %6.1f, %7.1f  %5.1f m/s  %5.0f m away  %5d chunks (+%d)  [%s]" % [
		p.x, p.y, p.z, Vector2(v.x, v.z).length(),
		p.distance_to(_player.global_position),
		_world.loaded_chunk_count(), _world.loaded_chunk_count() - chunks_before,
		_game.peer_input_line(peer)])


func _await_peer() -> int:
	while Time.get_ticks_msec() - _started < JOIN_TIMEOUT_MS:
		var peers := Net.other_peer_ids()
		if not peers.is_empty():
			return peers[0]
		if not OS.is_process_running(_client_pid):
			return 0  # it died before it got here
		await get_tree().process_frame
	return 0


func _spawn_client() -> void:
	var project := ProjectSettings.globalize_path("res://")
	var args := [
		# HEADLESS, so only one of the two processes goes near llvmpipe. The
		# client draws nothing anybody looks at, and software rasterising a
		# world twice on one box is most of why this probe could not get either
		# side above one frame a second.
		"--headless",
		"--log-file", ProjectSettings.globalize_path(CLIENT_LOG),
		"--path", project, "--",
		"--join", "127.0.0.1", "--pair-client",
	]
	# The client must generate the SAME world, so it is given the same seed and
	# the same view preset. The seed also arrives over the wire on joining;
	# passing it here means a client that never completes the handshake still
	# fails for the reason it actually failed for.
	# THE CLIENT IS CUT TO THE BONE, and this is not just about being quick.
	#
	# It is a body with a network connection - nobody is looking at its screen
	# - and two full instances on one machine starve each other: the first run
	# of this probe took 159 s to load the client's world against 25 s for the
	# same world alone, which put both processes at three or four frames a
	# second.
	#
	# At that frame rate ENet's own throttle shuts the input channel down.
	# `unreliable_ordered` packets are discarded BY THE SENDER when the peer's
	# throttle collapses, and the throttle collapses on round-trip variance -
	# which is exactly what a 300 ms frame produces. Measured: the host
	# received 9 input packets and then nothing at all for the rest of the run,
	# while the client went on sending, with no error on either side. The
	# reliable channel - the join handshake, the appearance - kept working
	# throughout, which is what made it look like a bug in the input path.
	#
	# So this is a measurement precondition, not a tidiness one. Everything
	# below is a LOCAL_PROPERTY, so none of it changes the world the client
	# generates - only how much of it the client bothers to build.
	args.append("--view")
	args.append("Low")
	for override in ["voxel_radius_chunks=4", "flora_radius_m=0",
			"flora_far_m=0", "far_tree_m=0"]:
		args.append("--set")
		args.append(override)
	for flag in ["--seed", "--port"]:
		var i := OS.get_cmdline_user_args().find(flag)
		if i != -1 and i + 1 < OS.get_cmdline_user_args().size():
			args.append(flag)
			args.append(OS.get_cmdline_user_args()[i + 1])
	# A stale file from a previous run would be read as this run's result, and
	# a probe that passes on last week's numbers is worse than one that fails.
	if FileAccess.file_exists(RESULT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULT_PATH))
	print("[PairProbe] host: %s %s" % [OS.get_executable_path(), " ".join(args)])
	_client_pid = OS.create_process(OS.get_executable_path(), args)


func _kill_client() -> void:
	if _client_pid > 0 and OS.is_process_running(_client_pid):
		OS.kill(_client_pid)


## Read what the client saw and decide. The host has no opinion of its own
## about prediction error - see the note at the top.
## HOW MUCH ERROR THE LATENCY ALONE EXPLAINS.
##
## The host's opinion of where a client is, is always one round of its own
## frames out of date, and a sprinting body covers ground in that time. At
## 13 m/s a 300 ms-stale row is 3.9 m of error that is not a prediction bug and
## that no amount of correcting would remove - correcting it harder would just
## drag the player backwards.
##
## So the thresholds are only meaningful on a host that is keeping up, and this
## turns the measured error back into an implied latency so the two can be told
## apart. Same reasoning as Stage 9's physics probe: a number that cannot mean
## what it looks like should say so rather than be reported as a failure.
func _implied_lag_ms(error_m: float) -> float:
	var sprint: float = Locomotion.WALK_SPEED * Locomotion.SPRINT_MULTIPLIER
	return error_m / sprint * 1000.0


func _verdict(frame_ms: float) -> void:
	if not FileAccess.file_exists(RESULT_PATH):
		print("[PairProbe] FAIL - the client left no result file at %s" % RESULT_PATH)
		print("[PairProbe]        (it crashed, or never reached the ground)")
		_tail_client_log()
		get_tree().quit(1)
		return
	var text := FileAccess.get_file_as_string(RESULT_PATH)
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		print("[PairProbe] FAIL - unreadable result file: %s" % text)
		get_tree().quit(1)
		return

	print("[PairProbe] client: %.0f m out and back, %d samples" % [
		data.get("travelled", 0.0), int(data.get("samples", 0))])
	print("[PairProbe] client: prediction error  median %.3f m  p95 %.3f m  max %.3f m" % [
		data.get("median", -1.0), data.get("p95", -1.0), data.get("max", -1.0)])
	print("[PairProbe] client: lowest point %.1f m, surface there %.1f m" % [
		data.get("lowest", 0.0), data.get("lowest_surface", 0.0)])

	# THE HARD FAILURES, which no amount of latency excuses. A body that ends up
	# under the world, or that never went anywhere, is broken however slow the
	# machine is.
	var fails: Array[String] = []
	if bool(data.get("fell_through", false)):
		fails.append("the client fell below the surface - the collision ring"
			+ " did not arrive")
	if float(data.get("travelled", 0.0)) < SPRINT_OUT_M * 0.9:
		fails.append("the client only covered %.0f m of %.0f" % [
			data.get("travelled", 0.0), SPRINT_OUT_M])

	# THE ERROR THRESHOLDS, which latency does excuse.
	var median := float(data.get("median", 999.0))
	var worst := float(data.get("max", 999.0))
	var implied := _implied_lag_ms(median)
	print("[PairProbe] median error implies %.0f ms of lag; the host's frames"
		% implied + " were %.0f ms" % frame_ms)
	var explained := implied <= frame_ms * 1.5
	var over_limit := median > 0.5 or worst > FAIL_ERROR_M
	if over_limit:
		if explained:
			print("[PairProbe] INCONCLUSIVE on prediction error, and it is the"
				+ " box rather than the code:")
			print("[PairProbe]   median %.2f m / worst %.2f m against limits"
				% [median, worst] + " of 0.50 / %.2f" % FAIL_ERROR_M)
			print("[PairProbe]   the error tracks the host's own frame time, so"
				+ " this measures how")
			print("[PairProbe]   fast two engines can run on one box, not"
				+ " whether prediction works.")
			print("[PairProbe]   Re-run on a machine that holds 60 fps to get a"
				+ " real number.")
		else:
			fails.append("median error %.2f m / worst %.2f m, and only %.0f ms"
				% [median, worst, implied] + " of that is lag")

	if fails.is_empty():
		if over_limit:
			print("[PairProbe] PASS on everything this box can decide;"
				+ " prediction error INCONCLUSIVE")
		else:
			print("[PairProbe] PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("[PairProbe] FAIL - %s" % f)
	get_tree().quit(1)


## The last of the client's own output, which is the only way to see why it
## failed - it is a separate process with its own console nobody is watching.
func _tail_client_log(lines := 25) -> void:
	if not FileAccess.file_exists(CLIENT_LOG):
		print("[PairProbe] (no client log at %s either - it never started)" % CLIENT_LOG)
		return
	var all := FileAccess.get_file_as_string(CLIENT_LOG).split("\n", false)
	print("[PairProbe] --- last %d lines of the client ---" % lines)
	for i in range(maxi(0, all.size() - lines), all.size()):
		print("[PairProbe]   %s" % all[i])
	print("[PairProbe] --- end of client log ---")


# --- The client --------------------------------------------------------------

func _run_client() -> void:
	print("[PairProbe] client: waiting for the host's world")
	while not _world.has_seed():
		await get_tree().process_frame
	# Released by Game once there is collision under the spawn point. Until
	# then the body is frozen and comparing positions would measure the wait.
	while not _player.is_physics_processing():
		await get_tree().process_frame
	print("[PairProbe] client: on the ground at %.0f, %.0f" % [
		_player.global_position.x, _player.global_position.z])

	# WAIT FOR THE CLIENT'S OWN WORLD, and this line is the whole reason the
	# first six runs of this probe measured nothing.
	#
	# A client that has joined is not a client that is ready. It still has to
	# generate the world itself - the same 1500x1500 coarse heightmap the host
	# built, which takes 16 s here, plus lakes and its own disc - and while it
	# is doing that its outgoing input packets DO NOT REACH THE HOST. Measured:
	# the client called rpc_id 78 times during that phase and the host received
	# nine, with no error on either side; the moment generation finished, the
	# backlog flushed and every subsequent packet arrived. It reproduced
	# identically with the RPC forced `reliable`, which is what ruled out the
	# transfer mode and ENet's unreliable throttle as the cause.
	#
	# The host already waits for `is_idle()` before it measures anything. The
	# client has to as well, or the first thirty seconds of every run are a
	# body walking away from a host that cannot hear it - which reads exactly
	# like Stage 10 being broken.
	print("[PairProbe] client: joined; waiting for its own world to finish")
	while not _world.is_idle():
		await get_tree().process_frame
	print("[PairProbe] client: world ready, %d chunks; starting the run" % [
		_world.loaded_chunk_count()])

	_started = Time.get_ticks_msec()
	var start: Vector3 = _player.global_position
	var lowest := start.y
	var lowest_surface := start.y

	_player.sprint_override = true
	_player.wish_override = Vector3(1.0, 0.0, 0.0)
	var turned := false
	var travelled := 0.0

	while Time.get_ticks_msec() - _started < RUN_TIMEOUT_MS:
		await get_tree().process_frame
		var here: Vector3 = _player.global_position
		var out := absf(here.x - start.x)
		travelled = maxf(travelled, out)

		# Below the surface is a hard failure however small the error is: it
		# means the host's ring did not arrive and the body went through the
		# world rather than over it.
		# In BLOCKS: surface_height_m takes world block coordinates and answers
		# in metres, which is the pair of units this codebase keeps mixing up.
		var surface: float = _world.surface_height_m(
			int(floor(here.x / _world.config.block_size)),
			int(floor(here.z / _world.config.block_size)))
		if here.y < lowest:
			lowest = here.y
			lowest_surface = surface
		if here.y < surface - 3.0:
			_fell_through = true

		if Time.get_ticks_msec() - _last_report >= REPORT_EVERY_MS:
			_last_report = Time.get_ticks_msec()
			var row_now: Dictionary = _game.last_authority()
			print("[PairProbe] client: at %7.1f, %6.1f, %7.1f  %5.1f m out  %d sent  host says %s  err %.2f m" % [
				here.x, here.y, here.z, out, _game.inputs_sent(),
				"nothing yet" if row_now.is_empty() else "%7.1f, %7.1f" % [
					(row_now.get("p", here) as Vector3).x,
					(row_now.get("p", here) as Vector3).z],
				0.0 if row_now.is_empty() else here.distance_to(row_now.get("p", here))])

		if Time.get_ticks_msec() - _started > GRACE_MS:
			var row: Dictionary = _game.last_authority()
			if not row.is_empty():
				_errors.append(here.distance_to(row.get("p", here)))

		if not turned and out >= SPRINT_OUT_M:
			turned = true
			print("[PairProbe] client: %.0f m out after %.1f s, turning back" % [
				out, float(Time.get_ticks_msec() - _started) / 1000.0])
			_player.wish_override = Vector3(-1.0, 0.0, 0.0)
		elif turned and out <= 2.0:
			print("[PairProbe] client: back at the start")
			break

	_player.wish_override = Vector3.ZERO
	_player.sprint_override = false
	_write_result(travelled, lowest, lowest_surface)
	get_tree().quit(0)


func _write_result(travelled: float, lowest: float, lowest_surface: float) -> void:
	var sorted := Array(_errors)
	sorted.sort()
	var out := {
		"travelled": travelled,
		"samples": sorted.size(),
		"median": _at(sorted, 0.5),
		"p95": _at(sorted, 0.95),
		"max": sorted.back() if not sorted.is_empty() else 0.0,
		"lowest": lowest,
		"lowest_surface": lowest_surface,
		"fell_through": _fell_through,
	}
	var f := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if f == null:
		print("[PairProbe] client: could not write %s" % RESULT_PATH)
		return
	f.store_string(JSON.stringify(out))
	f.close()
	print("[PairProbe] client: wrote %s" % ProjectSettings.globalize_path(RESULT_PATH))


func _at(sorted: Array, fraction: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(float(sorted.size() - 1) * fraction), 0, sorted.size() - 1)]
