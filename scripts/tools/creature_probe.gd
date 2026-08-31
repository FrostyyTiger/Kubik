class_name CreatureProbe
extends Node

## The scenario harness: a seeded, scripted encounter, run headless, judged
## from the journal.
##
##     godot --headless --path . -- --host --seed 42 --creature-probe \
##         --scenario walk --runs 5 --view low
##
## WHY THIS IS BUILT SECOND, BEFORE ANY CREATURE EXISTS. Every later stage's
## evidence comes out of it. Design decision 5 makes the probe a stage rather
## than a checking step, and the reason is that "the wolves flank" is not a
## claim anybody can settle by looking at a screenshot: it is an angle between
## two animals at a moment, and the only honest way to have it is to log the
## moment and measure the angle.
##
## IT NEEDS NO GPU AND NO DISPLAY. The probe draws nothing, so it runs
## `--headless` and unwrapped beside another lane's rendering tours with zero
## contention - which is exactly what it did on the night it was written.
##
## HOST-SIDE AI IS NOT PROMISED DETERMINISTIC (DESIGN.md), so nothing here
## asserts a bit-exact anything. Gates are TOLERANCE BANDS over repeated seeded
## runs, reported as medians - the repo's own measurement culture, and the only
## kind of gate that can be true of a system whose whole point is that it
## reacts.
##
## The walker is `traversal_probe.gd`'s, copied rather than shared: the wish
## and sprint overrides, the physics re-enable after a teleport, and the
## fall-through rescue against `surface_height_m`. That file measures the
## world; this one measures what lives in it, and the two will want to diverge.

## How far below the local ground counts as having fallen out of the world.
## See traversal_probe.gd - unloaded ground has no collision mesh, and a
## player who drops through it ends up sealed inside rock when it streams in.
const FALL_THROUGH_M := 6.0

## Give up on any one scenario after this much SIM time. Generous: a scenario
## that hits it has failed, and the failure should be legible rather than
## ambiguous with a slow machine.
const MAX_SCENARIO_SECONDS := 300.0

## Where the evidence goes.
const OUT_ROOT := "res://build/creatures"

## Physics ticks per second at time_scale 1. Read once at startup rather than
## assumed, so raising the scale multiplies whatever the project actually uses.
var _base_physics_hz := 60


# --- What a scenario is ------------------------------------------------------
#
# A Callable that awaits, drives the player, and returns a Dictionary. Two keys
# are read by the harness and the rest are the scenario's own:
#
#     ok       bool     did this run pass its own gate
#     why      String   ...and if not, why - printed, not swallowed
#
# EVERY OTHER NUMERIC KEY IS MEDIANED ACROSS RUNS and printed in the summary
# table. That is the whole reporting contract: a scenario states its numbers
# and the harness does the statistics, so no scenario has to grow its own
# five-run bookkeeping.

var _scenarios := {}

var _server: CreatureServer = null
var _world: World = null
var _player: Player = null
var _game: Node = null

var _scenario_name := "walk"
var _runs := 1
var _base_seed := 0
var _time_scale := 0.0  # 0 = let the scenario choose

## One entry per run: the scenario's result dict, plus the harness's own.
var _results: Array[Dictionary] = []

## How many journal rows existed when this run started. See the assignment in
## run() for why a mark is needed at all.
var _journal_mark := 0


func run(server: CreatureServer) -> void:
	_server = server
	_world = server.world
	_game = server.game
	_base_physics_hz = Engine.physics_ticks_per_second

	# THE WORLD FIRST, AND THIS ORDER IS LOAD-BEARING. The elif that starts
	# this probe is deferred from _ready, which runs BEFORE the host has
	# invented a world - so `_world.world_seed` is 0 at this point and the base
	# seed every run counts from would silently be the wrong one.
	await _wait_for_seed()
	_parse_args()
	_hide_the_hud()
	_player = _find_player(_game)
	if _player == null:
		_fail("no Player in the scene - the probe drives the real one")
		return
	if not _scenarios.has(_scenario_name):
		_fail("no scenario '%s' - have %s" % [
			_scenario_name, ", ".join(_scenarios.keys())])
		return

	print("[Creature] scenario '%s', %d run(s), seed %d, %s" % [
		_scenario_name, _runs, _base_seed,
		"host" if _server.is_host() else "CLIENT - creatures decide on the host only"])

	for i in _runs:
		var run_seed := _base_seed + i
		if i > 0 and not await _reroll_to(run_seed):
			_fail("could not reroll to seed %d for run %d" % [run_seed, i])
			return
		print("[Creature] --- run %d/%d, seed %d ---" % [i + 1, _runs, run_seed])
		await _wait_for_world()
		_reset_player()
		# WHERE THIS RUN'S JOURNAL STARTS. The Journal is the host's and it is
		# never reset - a reroll rebuilds the world, not the record of the
		# session - so without a mark, run 5 would be judged on the events of
		# runs 1 to 5 and every count in the table would climb for a reason
		# that has nothing to do with the seed.
		_journal_mark = _journal_size()

		var started := Time.get_ticks_msec()
		var result: Dictionary = await (_scenarios[_scenario_name] as Callable).call()
		result["wall_s"] = float(Time.get_ticks_msec() - started) / 1000.0
		result["seed"] = run_seed
		result["time_scale"] = Engine.time_scale
		result["physics_hz"] = Engine.physics_ticks_per_second
		_results.append(result)
		_dump_events(i)
		print("[Creature] run %d: %s%s" % [i + 1,
			"ok" if result.get("ok", false) else "FAILED",
			"" if result.get("ok", false) else " - " + str(result.get("why", ""))])
		_restore_time_scale()

	_finish()


# --- The scenarios -----------------------------------------------------------

func _build_scenarios() -> void:
	_scenarios = {
		"walk": _scenario_walk,
		"homes": _scenario_homes,
	}


## THE NULL SCENARIO. Walk 200 m through the meadow and come back with a
## journal.
##
## It asserts almost nothing about creatures, and that is its job: it is the
## test of the HARNESS. If `walk` passes five times out of five then the world
## loads, the player can be driven, the reroll between runs works, the journal
## is readable and the events file lands on disk - and every later scenario's
## failure is therefore about a creature rather than about the rig it runs on.
##
## Written before any creature exists so that it can never quietly start
## depending on one.
func _scenario_walk() -> Dictionary:
	# The walk is wall-clock bound and nothing in it needs real time, so it is
	# the first place decision 10 applies: run the sim faster than the clock
	# and record what it was run at.
	_set_time_scale(4.0)

	var start := _player.global_position
	# NOT DUE EAST, AND THAT WAS THE FIRST VERSION'S BUG. A fixed heading walks
	# into whatever the seed put there: the first five-run pass had seeds 44,
	# 45 and 46 stopping dead at 45, 78 and 106 m against a mountainside, which
	# is a true fact about those worlds and says nothing at all about the
	# harness this scenario exists to test. So the walk picks OPEN GROUND to
	# walk across, deterministically, from the terrain itself.
	var heading := _open_heading(start, 200.0)
	var target := start + heading * 200.0
	var walked := await _walk_towards(target, 200.0)

	var events := _creature_events()
	var out := {
		"walked_m": walked["walked_m"],
		"sim_s": walked["sim_s"],
		"rescues": walked["rescues"],
		"waited_s": walked["waited_s"],
		"events": events.size(),
	}
	# THE GATE IS THE HARNESS, NOT THE WALK. 200 m of meadow can contain a
	# lake or a cliff and the player is not pathfinding, so "got most of the
	# way" is the honest bar; what must be exact is that the journal came back
	# and that the schema validated.
	var schema := _validate_schema(events)
	out["schema_bad"] = schema.size()
	out["heading_deg"] = rad_to_deg(atan2(heading.z, heading.x))
	if walked["walked_m"] < 150.0:
		out["ok"] = false
		out["why"] = "only walked %.0f m of 200 m - the player is not being driven" % walked["walked_m"]
	elif not schema.is_empty():
		out["ok"] = false
		out["why"] = "%d events broke the schema: %s" % [schema.size(), schema[0]]
	else:
		out["ok"] = true
	return out


## The most walkable compass heading out of a point, in the world as generated.
##
## Sixteen headings, each scored by the WORST slope along its corridor and
## disqualified outright if any sample is under a lake. Worst rather than mean:
## a corridor that is flat for 190 m and vertical for 10 is not a walk, and a
## mean hides exactly that.
##
## Deterministic - it reads the heightmap and the lakes, and rolls nothing - so
## a rerun on the same seed walks the same way, which is what makes a five-run
## table a comparison rather than a collection.
func _open_heading(from: Vector3, distance_m: float) -> Vector3:
	var cfg := _world.config
	var gen: TerrainGenerator = _world.generator
	var hm := gen.heightmap
	var best := Vector3(1.0, 0.0, 0.0)
	var best_worst := INF
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var worst := 0.0
		var wet := false
		# Every 10 m, which is finer than the 2 m heightmap cell matters at
		# this distance and coarse enough to cost nothing.
		for step in range(10, int(distance_m) + 1, 10):
			var p := from + dir * float(step)
			var bx := p.x / cfg.block_size
			var bz := p.z / cfg.block_size
			worst = maxf(worst, hm.slope_deg_at(bx, bz))
			if not is_nan(gen.lakes.shore_level_at_cell(gen._cell_index(bx, bz))):
				wet = true
				break
		if wet:
			continue
		if worst < best_worst:
			best_worst = worst
			best = dir
	print("[Creature] walking %.0f deg, worst slope on the corridor %.1f deg" % [
		rad_to_deg(atan2(best.z, best.x)), best_worst])
	return best


## THE DETERMINISM CONTRACT, AS A SCENARIO.
##
## Enumerate every home in the region twice and require the two answers to be
## identical - not merely the same count, the same ids in the same order. That
## is the promise `HomePlacement` inherits from `TreePlacement`: hash the
## coordinates, never roll, so two machines that have never spoken agree about
## every den in the world without sending a byte. A count-only check would pass
## a placement that had quietly become order-dependent.
##
## Then the bands: every den outside the spawn exclusion, every den's slope
## inside the band it claims, every den past the danger floor. Those are not
## statistics, they are the product's own terms read back off the product - so
## a term that stops multiplying fails here rather than in a screenshot.
##
## NO PLAYER, NO CLOCK. This one does not walk anywhere, so it never touches
## the time scale.
func _scenario_homes() -> Dictionary:
	var gen: TerrainGenerator = _world.generator
	var started := Time.get_ticks_msec()
	var first := HomePlacement.all_homes(gen)
	var enumerate_ms := Time.get_ticks_msec() - started
	var second := HomePlacement.all_homes(gen)

	var dens := []
	var burrows := []
	for h in first:
		if h["home"] == "den":
			dens.append(h)
		elif h["home"] == "burrow":
			burrows.append(h)

	var out := {
		"dens": dens.size(),
		"burrow_fields": burrows.size(),
		"enumerate_ms": enumerate_ms,
	}

	# --- IDENTICAL, TWICE.
	var drift := 0
	if first.size() != second.size():
		drift += 1
	else:
		for i in first.size():
			if first[i]["id"] != second[i]["id"] 					or first[i]["pos"] != second[i]["pos"] 					or first[i]["home"] != second[i]["home"]:
				drift += 1
	out["drift"] = drift

	# --- THE BANDS, read back off the product.
	var spawn := _world.spawn_position_m(0.0)
	var too_near := 0
	var out_of_slope := 0
	var too_safe := 0
	var duplicate_ids := 0
	var seen := {}
	for h in dens:
		if float(h["from_spawn_m"]) < HomePlacement.DEN_SPAWN_CLEAR_M:
			too_near += 1
		var slope := float(h["slope_deg"])
		if slope < HomePlacement.DEN_SLOPE_MIN or slope > HomePlacement.DEN_SLOPE_MAX:
			out_of_slope += 1
		if float(h["danger"]) < HomePlacement.DEN_DANGER_MIN:
			too_safe += 1
	# IDS ARE NAMES AND TWO THINGS MAY NOT SHARE ONE. The identity packs the
	# block position, and two homes of the same kind on the same block would be
	# indistinguishable to anything that stores one - which is Sites v1 and the
	# director, later.
	for h in first:
		if seen.has(h["id"]):
			duplicate_ids += 1
		seen[h["id"]] = true
	out["too_near"] = too_near
	out["out_of_slope"] = out_of_slope
	out["too_safe"] = too_safe
	out["duplicate_ids"] = duplicate_ids

	# --- The burrow fields, which night 2 consumes. Placed and checked now to
	# prove the pattern generalises past the one home type that is used.
	var burrow_count := 0
	for h in burrows:
		burrow_count += int(h["count"])
	out["burrows"] = burrow_count

	var nearest := HomePlacement.nearest(gen, "den", spawn, first)
	if not nearest.is_empty():
		out["nearest_den_m"] = (nearest["pos"] as Vector3).distance_to(spawn)
		print("[Creature] nearest den: id %d at %.0f, %.0f m, %.0f m from spawn, slope %.1f deg, danger %.2f, zone %s" % [
			nearest["id"], (nearest["pos"] as Vector3).x, (nearest["pos"] as Vector3).z,
			out["nearest_den_m"], nearest["slope_deg"], nearest["danger"],
			TerrainGenerator.ZONE_NAMES[nearest["zone"]]])
	print("[Creature] %d dens, %d burrow fields (%d burrows) in %d ms" % [
		dens.size(), burrows.size(), burrow_count, enumerate_ms])

	var why := ""
	if drift > 0:
		why = "%d homes differed between two enumerations of the same seed" % drift
	elif dens.size() < 3:
		why = "only %d dens in the whole region - a pack needs somewhere to live" % dens.size()
	elif burrows.size() < 10:
		why = "only %d burrow fields - the pattern has not generalised" % burrows.size()
	elif too_near > 0:
		why = "%d dens inside the %.0f m spawn exclusion" % [
			too_near, HomePlacement.DEN_SPAWN_CLEAR_M]
	elif out_of_slope > 0:
		why = "%d dens outside the %.0f-%.0f degree slope band" % [
			out_of_slope, HomePlacement.DEN_SLOPE_MIN, HomePlacement.DEN_SLOPE_MAX]
	elif too_safe > 0:
		why = "%d dens below the danger floor" % too_safe
	elif duplicate_ids > 0:
		why = "%d homes share an id with another" % duplicate_ids
	elif nearest.is_empty():
		why = "no nearest den could be named for Stage 6"
	out["ok"] = why.is_empty()
	if not why.is_empty():
		out["why"] = why
	return out


# --- Driving the player ------------------------------------------------------

## Push the player towards a point until they arrive or stop making progress.
##
## Deliberately NOT pathfinding. The scenarios want a player who walks where a
## player would walk, and a probe that steered perfectly would be measuring the
## steering. `traversal_probe.gd` does the same thing for the same reason, with
## a detour rule this does not need at these distances.
func _walk_towards(target: Vector3, give_up_after_m: float,
		sprint := false) -> Dictionary:
	_player.sprint_override = sprint
	var last := _player.global_position
	var walked := 0.0
	var sim := 0.0
	var waited := 0.0
	var rescues := 0
	var best := INF
	var best_at := 0.0

	while sim < MAX_SCENARIO_SECONDS:
		await get_tree().physics_frame
		var delta := 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
		var pos := _player.global_position

		# Fell through ground that had not streamed in. Being inside rock is
		# not a fact about anything this probe measures.
		var ground := _world.surface_height_m(
			int(pos.x / _world.config.block_size),
			int(pos.z / _world.config.block_size))
		if pos.y < ground - FALL_THROUGH_M:
			_player.global_position = Vector3(pos.x, ground + 2.0, pos.z)
			_player.velocity = Vector3.ZERO
			rescues += 1
			continue

		# Wait for the ground rather than walking off the edge of it. Time
		# spent here is not time the scenario cost.
		if not _world.is_idle():
			_player.wish_override = Vector3.ZERO
			waited += delta
			continue

		var to_target := target - pos
		to_target.y = 0.0
		var remaining := Vector2(to_target.x, to_target.z).length()
		_player.wish_override = to_target

		walked += Vector2(pos.x - last.x, pos.z - last.z).length()
		last = pos
		sim += delta

		if remaining < best - 2.0:
			best = remaining
			best_at = sim
		if remaining <= 3.0:
			break
		# No progress for 20 s of sim: walked into something and stayed there.
		if sim - best_at > 20.0:
			break
		if walked > give_up_after_m * 2.0:
			break

	_player.wish_override = Vector3.ZERO
	_player.sprint_override = false
	return {
		"walked_m": walked, "sim_s": sim,
		"waited_s": waited, "rescues": rescues,
	}


## Physics back on and feet on the ground, at the start of every run.
##
## `game.gd` freezes the player until the ground under spawn exists, and a
## reroll re-freezes them. Turned back on here rather than waited for, exactly
## as `traversal_probe.gd` does it.
func _reset_player() -> void:
	_player.set_physics_process(true)
	_player.wish_override = Vector3.ZERO
	_player.sprint_override = false
	var pos := _player.global_position
	var ground := _world.surface_height_m(
		int(pos.x / _world.config.block_size),
		int(pos.z / _world.config.block_size))
	if pos.y < ground:
		_player.global_position = Vector3(pos.x, ground + 2.0, pos.z)
		_player.velocity = Vector3.ZERO
	_world.set_center_from_position(_player.global_position)


# --- Runs, seeds and the clock -----------------------------------------------

## A new world for the next run, through the path the game already has.
##
## THE F5 REROLL, EMITTED RATHER THAN REIMPLEMENTED. `game.gd` connects
## `DebugHUD.reroll_requested` to its own host-only handler, which resets the
## world, sets it up on the new seed and respawns the player. Emitting that
## signal is a read-side use of a file this lane may not write, and it means
## the probe's between-run rebuild is the same rebuild a human gets by pressing
## a key - which is the version that will still work in a month.
func _reroll_to(new_seed: int) -> bool:
	var hud := _game.get_node_or_null("DebugHUD")
	if hud == null or not hud.has_signal("reroll_requested"):
		return false
	hud.reroll_requested.emit(new_seed)
	# The rebuild is asynchronous; give it a frame to start before waiting for
	# it to finish, or is_idle() answers about the world we just threw away.
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_for_world()
	return _world.world_seed == new_seed


## Faster than real time, per decision 10.
##
## PHYSICS TICKS SCALE WITH IT, and that is the part that is easy to get wrong.
## `Engine.time_scale` alone stretches the delta each physics tick reports
## without changing how many ticks happen, so a character integrating gravity
## at 4x delta jumps differently - the sim stops being the sim. Scaling the
## tick rate to match keeps every step the same size and simply runs more of
## them per wall second, which is the honest way to hurry.
func _set_time_scale(scale: float) -> void:
	var wanted := _time_scale if _time_scale > 0.0 else scale
	Engine.time_scale = wanted
	Engine.physics_ticks_per_second = int(round(float(_base_physics_hz) * wanted))


func _restore_time_scale() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _base_physics_hz


## Wait until the host has actually invented a world. See run().
func _wait_for_seed() -> void:
	while not _world.has_seed():
		await get_tree().process_frame


func _wait_for_world() -> void:
	while not _world.is_idle():
		await get_tree().process_frame


# --- The journal, and what it has to look like -------------------------------

## The creature slice of the host's journal.
func _creature_events() -> Array:
	if _game == null or not _game.has_method("journal"):
		return []
	var out := []
	var rows := (_game.journal() as Journal).dump()
	for i in range(mini(_journal_mark, rows.size()), rows.size()):
		var row: Dictionary = rows[i]
		if Species.is_creature_event(str(row.get("kind", ""))):
			out.append(row)
	return out


func _journal_size() -> int:
	if _game == null or not _game.has_method("journal"):
		return 0
	return (_game.journal() as Journal).size()


## EVERY EVENT CARRIES `{species, id, pos}` - the schema in `species.gd`, held
## to as a property of the run rather than as an intention.
##
## Returns a list of complaints, empty when the run is clean. Checked here
## rather than at the writing end because a schema nothing reads is a comment:
## this is the thing that makes it a contract, and it is the check the night-1
## acceptance criteria name.
func _validate_schema(events: Array) -> Array:
	var bad := []
	for row in events:
		var kind := str(row.get("kind", "?"))
		for key in ["species", "id", "pos"]:
			if not row.has(key):
				bad.append("%s has no '%s'" % [kind, key])
		if row.has("species") and not (row["species"] is int):
			bad.append("%s: species is %s, not an int" % [
				kind, type_string(typeof(row["species"]))])
		if row.has("pos") and not (row["pos"] is Vector3):
			bad.append("%s: pos is %s, not a Vector3" % [
				kind, type_string(typeof(row["pos"]))])
		# HARD RULE 6, ASSERTED ON THE EVIDENCE rather than on the code. A bite
		# that ever reports applied damage on night 1 is a failed run, however
		# it got there.
		if kind == "bite" and float(row.get("applied", -1.0)) != 0.0:
			bad.append("a bite applied %s - the bite ships disarmed" % row.get("applied"))
	return bad


## The run's creature events, on disk, as the evidence.
##
## `events.json` is run 0 - the seed the caller actually asked for - and every
## run also keeps its own file, so a five-run gate can be argued with
## afterwards rather than only believed.
func _dump_events(index: int) -> void:
	var dir := "%s/%s" % [OUT_ROOT, _scenario_name]
	DirAccess.make_dir_recursive_absolute(dir)
	var rows := []
	for row in _creature_events():
		var copy := (row as Dictionary).duplicate()
		# Vector3 does not survive JSON. Written as three numbers rather than
		# as a string, so anything reading this back can do arithmetic on it.
		if copy.has("pos") and copy["pos"] is Vector3:
			var p: Vector3 = copy["pos"]
			copy["pos"] = [p.x, p.y, p.z]
		rows.append(copy)
	var text := JSON.stringify(rows, "  ")
	_write(("%s/events-run%d.json" % [dir, index]), text)
	if index == 0:
		_write("%s/events.json" % dir, text)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("[Creature] could not write %s" % path)
		return
	f.store_string(text)
	f.close()


# --- The summary -------------------------------------------------------------

## Medians across runs, and a nonzero exit if any run failed.
##
## MEDIAN RATHER THAN MEAN, which is the repo's convention and is the right one
## here for a specific reason: one run where the player fell in a lake should
## not be able to move a number the whole gate is read off. A mean lets it.
func _finish() -> void:
	_restore_time_scale()
	var failed := 0
	for r in _results:
		if not r.get("ok", false):
			failed += 1

	print("")
	print("[Creature] scenario '%s': %d of %d runs passed" % [
		_scenario_name, _results.size() - failed, _results.size()])
	for key in _numeric_keys():
		var values := _values_of(key)
		print("[Creature]   %-12s median %10.2f   (%s)" % [
			key, _median(values), _joined(values)])
	for r in _results:
		if not r.get("ok", false):
			print("[Creature]   seed %s FAILED: %s" % [
				r.get("seed", "?"), r.get("why", "no reason given")])
	print("[Creature] events -> %s/%s/" % [OUT_ROOT, _scenario_name])
	get_tree().quit(1 if failed > 0 else 0)


func _fail(why: String) -> void:
	print("[Creature] CANNOT RUN: %s" % why)
	get_tree().quit(1)


## Every numeric key any run reported, in first-seen order - so a scenario
## adds a number by returning it and nothing else has to be told.
func _numeric_keys() -> Array:
	var keys := []
	for r in _results:
		for key in r:
			if key == "ok" or key == "seed":
				continue
			if (r[key] is float or r[key] is int) and not keys.has(key):
				keys.append(key)
	return keys


func _values_of(key: String) -> Array:
	var out := []
	for r in _results:
		if r.has(key) and (r[key] is float or r[key] is int):
			out.append(float(r[key]))
	return out


func _median(values: Array) -> float:
	if values.is_empty():
		return NAN
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n % 2 == 1:
		return sorted[n / 2]
	return (sorted[n / 2 - 1] + sorted[n / 2]) * 0.5


func _joined(values: Array) -> String:
	var parts := PackedStringArray()
	for v in values:
		parts.append("%.2f" % v)
	return ", ".join(parts)


# --- Startup -----------------------------------------------------------------

func _init() -> void:
	_build_scenarios()


func _parse_args() -> void:
	var argv := OS.get_cmdline_user_args()
	_scenario_name = _string_arg(argv, "--scenario", "walk")
	_runs = maxi(1, int(_string_arg(argv, "--runs", "1")))
	_base_seed = _world.world_seed
	# `--time-scale` overrides whatever a scenario asked for. Present so a
	# scenario that misbehaves at 4x can be re-run honestly at 1x without an
	# edit, which is how decision 10's "record both values" stays checkable.
	_time_scale = float(_string_arg(argv, "--time-scale", "0"))


func _string_arg(argv: PackedStringArray, flag: String, fallback: String) -> String:
	var i := argv.find(flag)
	if i < 0 or i + 1 >= argv.size():
		return fallback
	return argv[i + 1]


## The HUD is not this probe's business, and every other probe hides it from
## `game.gd`. This one does it from here, so that file's diff stays at one
## banner block and one elif.
func _hide_the_hud() -> void:
	for path in ["HUD", "DebugHUD", "CharacterDebug"]:
		var node := _game.get_node_or_null(path)
		if node != null and "visible" in node:
			node.visible = false


func _find_player(node: Node) -> Player:
	if node is Player:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null
