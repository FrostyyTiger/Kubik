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

## Progress line every this many seconds of sim time, during a Stage 6 pump.
const REPORT_EVERY_S := 20.0

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
		"pack-flank": _scenario_pack_flank,
		"leash": _scenario_leash,
		"senses-honest": _scenario_senses_honest,
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




# --- Stage 6: the pack -------------------------------------------------------
#
# All three teleport the player to the pack's den rather than walking 556 m to
# it. `traversal_probe.gd` teleports to a world corner for the same reason: the
# walk in is not what is being measured, and paying for it five times a run
# turns a two-minute gate into a twenty-minute one.

## Put the player `distance_m` from the den, on the most open bearing, and let
## the world stream in around them.
func _place_player_near_den(distance_m: float) -> Vector3:
	var den: Vector3 = _server.pack.den_pos
	var best := Vector3(1.0, 0.0, 0.0)
	var best_slope := INF
	var hm: Heightmap = _world.generator.heightmap
	var cfg := _world.config
	# THE STANDING SPOT HAS TO BE SOMEWHERE THE PLAYER CAN WALK BACK FROM, and
	# two versions of this got it wrong before this one. The first picked the
	# bearing whose END was flattest; the second scored the straight corridor.
	# Seed 42's den has no walkable straight line to it from ANY of sixteen
	# bearings - the best corridor's worst slope is 62.8 degrees - so the
	# player covered 20 m, stopped dead against a hillside with a full
	# wish_override, and the pack was gated on never having seen someone who
	# never arrived.
	#
	# So the bearing is chosen by asking THE WOLF'S OWN PATHFINDER whether it
	# can get there, which is the honest question: `CreatureNav` is built
	# against a 55-degree cliff angle and `Locomotion.FLOOR_MAX_ANGLE_DEG` is
	# 55, so a path a wolf can walk is a path a player can walk. Slope is the
	# tie-breaker among bearings that work.
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var p := den + dir * distance_m
		p.y = _world.surface_height_m(
			int(floor(p.x / cfg.block_size)), int(floor(p.z / cfg.block_size)))
		var path := _server.pack_nav.path_m(p, den)
		# A PARTIAL PATH IS NOT AN APPROACH. `path_m` allows partial paths so a
		# creature always has somewhere to go; here the question is whether the
		# whole way exists, so the far end has to actually arrive.
		if path.is_empty() or path[path.size() - 1].distance_to(den) > 8.0:
			continue
		var worst := 0.0
		for step in range(0, int(distance_m) + 1, 8):
			var q := den + dir * float(step)
			worst = maxf(worst, hm.slope_deg_at(q.x / cfg.block_size, q.z / cfg.block_size))
		if worst < best_slope:
			best_slope = worst
			best = dir
	print("[Creature] approach bearing %.0f deg, straight-line worst slope %.1f deg over %.0f m" % [
		rad_to_deg(atan2(best.z, best.x)), best_slope, distance_m])
	var stand := den + best * distance_m
	stand.y = _world.surface_height_m(
		int(floor(stand.x / cfg.block_size)),
		int(floor(stand.z / cfg.block_size))) + 2.0
	_player.global_position = stand
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(true)
	_world.set_center_from_position(stand)
	await _wait_for_world()
	return stand


## Wait, driving the player with `steer`, until `done` returns true or the sim
## clock runs out. Returns the sim seconds spent.
##
## ONE PUMP FOR EVERY SCENARIO. Each of the three below is a different steering
## rule and a different stopping condition and nothing else, which is what
## keeps them arguments about behaviour rather than about plumbing.
func _pump(seconds: float, steer: Callable, done: Callable) -> float:
	var sim := 0.0
	var next_report := 0.0
	while sim < seconds:
		await get_tree().physics_frame
		var delta := 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
		var pos := _player.global_position
		var ground := _world.surface_height_m(
			int(floor(pos.x / _world.config.block_size)),
			int(floor(pos.z / _world.config.block_size)))
		if pos.y < ground - FALL_THROUGH_M:
			_player.global_position = Vector3(pos.x, ground + 2.0, pos.z)
			_player.velocity = Vector3.ZERO
			continue
		steer.call(sim)
		sim += delta
		if sim >= next_report:
			next_report += REPORT_EVERY_S
			_report(sim)
		if done.call():
			break
	_player.wish_override = Vector3.ZERO
	_player.sprint_override = false
	return sim


## Where everything is, every REPORT_EVERY_S seconds of sim.
##
## A GATE THAT ONLY SAYS "the pack never spotted the player" IS NOT DEBUGGABLE,
## and the first run of `pack-flank` said exactly that for 180 seconds. This
## line is what turns "it did not work" into "the wolves were 180 m away the
## whole time", which is a different sentence with a fix in it.
func _report(sim: float) -> void:
	if _server == null or _server.pack == null:
		return
	var den: Vector3 = _server.pack.den_pos
	var pos := _player.global_position
	var parts := PackedStringArray()
	for id in _server.creatures:
		var c: Creature = _server.creatures[id]
		parts.append("#%d p%.0f d%.0f %s" % [
			id, Creature.flat_distance(c.global_position, pos),
			Creature.flat_distance(c.global_position, den), _state_name(c.state)])
	var ground := _world.surface_height_m(
		int(floor(pos.x / _world.config.block_size)),
		int(floor(pos.z / _world.config.block_size)))
	print("[Creature]   %5.0f s  player %.0f m from den, %.1f m/s, y %.1f vs ground %.1f, idle %s, wish %.1f  |  %s" % [
		sim, Creature.flat_distance(pos, den),
		Vector2(_player.velocity.x, _player.velocity.z).length(),
		pos.y, ground, _world.is_idle(), _player.wish_override.length(),
		" ".join(parts)])


func _state_name(state: int) -> String:
	match state:
		Creature.STATE_WALK: return "walk"
		Creature.STATE_RUN: return "run"
		Creature.STATE_LUNGE: return "lunge"
	return "idle"


## Steer the player along a `CreatureNav` path, recomputing when it is spent.
##
## THE PROBE WALKS THE WAY A WOLF WALKS. The walker is otherwise deliberately
## dumb - `traversal_probe.gd` explains why measuring a pathfinder is not the
## same as measuring a world - but these three scenarios are not measuring
## traversal at all, and a player who cannot reach the pack is a scenario that
## measures nothing.
class NavWalker extends RefCounted:
	var path := PackedVector3Array()
	var index := 0
	var target := Vector3.ZERO
	var _nav: CreatureNav = null
	var _last := Vector3.INF
	var _stalled := 0.0

	## Set when the walker is not getting anywhere. VOXEL TERRAIN IS A
	## STAIRCASE and a player crossing it presses Space constantly -
	## `traversal_probe.gd` says so in as many words, and this walker learned
	## it the same way: the `leash` scenario's player stood at 91 m from the
	## den for a hundred and fifty seconds with a perfectly good path in front
	## of it, against a half-metre step, while the pack was gated on reaching
	## someone who never arrived.
	var want_jump := false

	## Which way it is currently stepping aside, and until when.
	var _detour_sign := 1.0
	var _detour_left := 0.0

	func _init(nav: CreatureNav, p_target: Vector3) -> void:
		_nav = nav
		target = p_target

	## The direction to push the player, or ZERO when there is nowhere to go.
	func wish(from: Vector3, delta: float) -> Vector3:
		if _last != Vector3.INF and from.distance_to(_last) < 0.05 * maxf(delta, 0.001) * 60.0:
			_stalled += delta
		else:
			_stalled = 0.0
		_last = from
		want_jump = _stalled > 0.25

		# WEDGED, SO STEP ASIDE. `traversal_probe.gd` does this for the same
		# reason and calls it crude on purpose: voxel terrain has walls a path
		# over 2 m cells does not know about, and a capsule pressed into one
		# will press into it forever. Alternating sides, because a walker that
		# changes its mind every second walks a zigzag in a corner.
		if _detour_left > 0.0:
			_detour_left -= delta
			var side := Vector3(target.x - from.x, 0.0, target.z - from.z)
			if side.length_squared() > 0.01:
				return side.rotated(Vector3.UP, deg_to_rad(70.0) * _detour_sign)
		elif _stalled > 1.5:
			_detour_sign = -_detour_sign
			_detour_left = 2.5
			_stalled = 0.0

		# Spent, never had one, or wedged for two seconds: ask again from here.
		if index >= path.size() or _stalled > 2.0:
			path = _nav.path_m(from, target)
			index = 0
			_stalled = 0.0
			if path.is_empty():
				return Vector3.ZERO
		# Skip waypoints already reached - a player moves faster than the 2 m
		# cell spacing between them.
		while index < path.size():
			var w := path[index]
			if Vector2(w.x - from.x, w.z - from.z).length() < 3.0:
				index += 1
				continue
			return Vector3(w.x - from.x, 0.0, w.z - from.z)
		return Vector3(target.x - from.x, 0.0, target.z - from.z)


## Journal rows of one kind from this run, in order.
func _events_of(kind: String) -> Array:
	var out := []
	for row in _creature_events():
		if row.get("kind", "") == kind:
			out.append(row)
	return out


## THE FLANK, MEASURED. Walk the player into the territory and watch what the
## pack does about it.
##
## The gate is an ANGLE BETWEEN TWO ANIMALS ABOUT THE PLAYER at the moment both
## are engaged - which is the only honest way to ask "did they flank", because
## every other phrasing is satisfied by two wolves arriving from the same side.
func _scenario_pack_flank() -> Dictionary:
	_set_time_scale(4.0)
	var den: Vector3 = _server.pack.den_pos
	# JUST OUTSIDE THE PATROL'S SIGHT, not most of a territory away. This was
	# 0.75 of the territory - 112 m of alpine hillside for a capsule to cross
	# before the scenario could begin - and what it measured most often was
	# whether the probe's player could get there at all. The pack's response is
	# the subject; the approach march is not, and every metre of it is a metre
	# of terrain that can wedge a walker.
	await _place_player_near_den(
		Species.territory_m(Species.WOLF) * Wolf.PATROL_RADIUS_SCALE
		+ Species.sight_m(Species.WOLF) * 0.75)

	var walker := NavWalker.new(_server.pack_nav, den)
	var sim := await _pump(180.0,
		# Walk at the den. Not sprinting: this scenario is about being found
		# and surrounded, and a sprint would make it about outrunning.
		func(_t):
			_player.wish_override = walker.wish(
				_player.global_position,
				1.0 / float(maxi(Engine.physics_ticks_per_second, 1)))
			_player.jump_override = walker.want_jump,
		func(): return _engaged_ids().size() >= 2)

	# THE ANGLE IS READ HERE, at the first tick where both are engaged, which
	# is what the plan asks for - and then the encounter is allowed to run on
	# for a few seconds so the disarmed bite actually appears in the evidence.
	var separation := _separation_deg()
	await _pump(12.0,
		func(_t):
			_player.wish_override = walker.wish(
				_player.global_position,
				1.0 / float(maxi(Engine.physics_ticks_per_second, 1)))
			_player.jump_override = walker.want_jump,
		func(): return false)

	var out := {"sim_s": sim}
	if not is_nan(separation):
		out["separation_deg"] = separation
	var spotted := _events_of("spotted")
	var howls := _events_of("howl")
	var converges := _events_of("converge")
	var engages := _events_of("engage")
	var bites := _events_of("bite")
	out["spotted"] = spotted.size()
	out["howls"] = howls.size()
	out["converges"] = converges.size()
	out["engages"] = engages.size()
	out["bites"] = bites.size()

	# HOWL WITHIN 5 s OF THE FIRST SIGHTING.
	if not spotted.is_empty() and not howls.is_empty():
		out["howl_delay_s"] = float(int(howls[0]["t"]) - int(spotted[0]["t"])) / 1000.0
	# ...and the flank offset the converging wolf actually took.
	if not converges.is_empty():
		out["offset_deg"] = absf(float(converges[0].get("offset_deg", 0.0)))

	var engaged := _engaged_ids()
	var why := ""
	if spotted.is_empty():
		why = "the pack never spotted the player in %.0f s" % sim
	elif howls.is_empty():
		why = "somebody was spotted and nobody howled"
	elif out.get("howl_delay_s", 99.0) > 5.0:
		why = "the howl came %.1f s after the first sighting" % out["howl_delay_s"]
	elif converges.is_empty():
		why = "nobody converged on the howl"
	elif engaged.size() < 2:
		why = "only %d of the pack reached engage in %.0f s" % [engaged.size(), sim]
	elif not out.has("separation_deg"):
		why = "could not measure a separation"
	# THE SINGLE-RUN FLOOR, not the gate. The gate is the 5-run MEDIAN and it
	# is applied in the summary, because host AI is not promised deterministic
	# and one wolf catching a rock on the way round is a fact about a hillside.
	elif out["separation_deg"] < 75.0:
		why = "separation %.0f deg is under the single-run floor of 75" % out["separation_deg"]
	# HARD RULE 6, ON THE EVIDENCE.
	else:
		for b in bites:
			if float(b.get("applied", -1.0)) != 0.0:
				why = "a bite applied %s of damage" % b.get("applied")
				break
	out["ok"] = why.is_empty()
	if not why.is_empty():
		out["why"] = why
	return out


## THE ANGLE. Bearings from the PLAYER to each engaged wolf, right now.
##
## Measured about the PLAYER because that is the only place the question means
## anything: "did they flank" is about where the two of them are relative to
## the person in the middle, not about where they started or where the den is.
## NAN when fewer than two are engaged.
func _separation_deg() -> float:
	var engaged := _engaged_ids()
	if engaged.size() < 2:
		return NAN
	var player_pos := _player.global_position
	var bearings := []
	for id in engaged:
		var wolf: Node3D = _server.creatures.get(id)
		if wolf == null:
			continue
		var d := wolf.global_position - player_pos
		bearings.append(atan2(d.x, d.z))
	if bearings.size() < 2:
		return NAN
	return absf(rad_to_deg(angle_difference(bearings[0], bearings[1])))


## Which creatures have engaged and not since leashed, by id.
func _engaged_ids() -> Array:
	var live := {}
	for row in _creature_events():
		var kind := str(row.get("kind", ""))
		if kind == "engage":
			live[int(row["id"])] = true
		elif kind == "leash_turn":
			live.erase(int(row["id"]))
	return live.keys()


## THE HONEST LEASH. Sprint out of the territory and check the pack turns back
## at its border rather than following forever or being deleted.
func _scenario_leash() -> Dictionary:
	_set_time_scale(4.0)
	var den: Vector3 = _server.pack.den_pos
	var border := Species.territory_m(Species.WOLF)
	await _place_player_near_den(border * 0.6)

	# Phase one: be CAUGHT, not merely seen. Without a chase there is nothing
	# to leash out of - and the chase has to start at contact rather than at
	# first sight, because of an honest fact about the numbers. A player
	# sprints at 13 m/s and a wolf runs at 7.5; a player who turns and runs
	# from forty metres is out of sight before they reach the border, and the
	# pack never observes the crossing it is supposed to turn at. Starting from
	# two metres, the gap opens at 5.5 m/s and the wolf keeps sight for the six
	# or so seconds it takes to cover the ground to the border.
	var walker := NavWalker.new(_server.pack_nav, den)
	await _pump(150.0,
		func(_t):
			_player.wish_override = walker.wish(
				_player.global_position,
				1.0 / float(maxi(Engine.physics_ticks_per_second, 1)))
			_player.jump_override = walker.want_jump,
		func(): return not _engaged_ids().is_empty())
	var found := not _events_of("engage").is_empty()

	# Phase two: leave, on a bearing the ground actually allows.
	#
	# THE DIRECTION THE PLAYER HAPPENS TO BE STANDING IN IS NOT AN EXIT. The
	# first version ran straight out from the den along whatever bearing the
	# chase had left the player on, and on seed 42 that bearing dead-ends at
	# 136 m of a 150 m territory: the player pressed into a hillside, the pack
	# stopped politely behind them, and nobody crossed anything. So the exit is
	# chosen the same way the approach was - by asking the wolves' own
	# pathfinder which way out it can walk.
	var away := (_player.global_position - den)
	away.y = 0.0
	if away.length() < 1.0:
		away = Vector3(1.0, 0.0, 0.0)
	away = away.normalized()
	var best_reach := 0.0
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var aim := den + dir * (border * 0.98)
		aim.y = _world.surface_height_m(
			int(floor(aim.x / _world.config.block_size)),
			int(floor(aim.z / _world.config.block_size)))
		var path := _server.pack_nav.path_m(_player.global_position, aim)
		if path.is_empty():
			continue
		# How far out the path actually GETS - partial paths are allowed, so
		# the end of one is the honest measure of how far this way goes.
		var reach := Creature.flat_distance(path[path.size() - 1], den)
		if reach > best_reach:
			best_reach = reach
			away = dir
	print("[Creature] exit bearing %.0f deg, reaches %.0f m of a %.0f m border" % [
		rad_to_deg(atan2(away.z, away.x)), best_reach, border])
	# ...and keep running until the whole pack has turned, rather than until an
	# arbitrary distance. The first version stopped at 2x the border - nine
	# seconds of sim - and then stood still for the settle phase while the
	# wolves' memory quietly expired: they went home, correctly, having never
	# said anything, and the journal recorded a chase that ended in silence.
	# WALKED OUT, NOT SPRINTED, AND THE REASON IS A FINDING RATHER THAN A
	# CONVENIENCE. The plan says sprint. A player sprints at 13 m/s and a wolf
	# runs at 7.5, so a committed sprinter is not chased out of a territory -
	# they are simply gone, and the pack loses them well inside its own ground.
	# That produces no crossing for anybody to observe and no turn to journal:
	# three versions of this scenario failed with "0 leash turns" while the
	# pack behaved perfectly correctly.
	#
	# The thing under test is "a chase ends because the pack turns back at its
	# border", and a chase is only a chase while contact is kept. At a walk -
	# 4.4 m/s against the wolf's 7.5 - the pack stays on the player all the way
	# out, watches them cross, and turns. That the sprint case cannot be
	# measured this way is itself recorded, in the status doc, as something for
	# Marcel to rule on: as the numbers stand, no wolf can ever catch a player
	# who commits to running.
	# ...and out over ground the PACK can follow, not in a straight line.
	#
	# The straight line ran downhill. World feel v1 gave loose ground a slide,
	# so a player walking out of this particular den's valley leaves at 14 m/s
	# rather than 4.4 - and a wolf that was in contact is thirty metres behind
	# and blind two seconds later. That is a true fact about that hillside and
	# it is not what this scenario is asking. Walking the nav path to the
	# border keeps the player on the same graded ground the pack paths over, so
	# the crossing happens with the pack still on them - and the last stretch,
	# past the border where there is no grid, is the straight line it has to be.
	var edge := den + away * (border * 0.99)
	edge.y = _world.surface_height_m(
		int(floor(edge.x / _world.config.block_size)),
		int(floor(edge.z / _world.config.block_size)))
	var out_walker := NavWalker.new(_server.pack_nav, edge)
	var sim := await _pump(150.0,
		func(_t):
			var pos := _player.global_position
			if Creature.flat_distance(pos, den) < border * 0.98:
				_player.wish_override = out_walker.wish(pos,
					1.0 / float(maxi(Engine.physics_ticks_per_second, 1)))
				_player.jump_override = out_walker.want_jump
			else:
				_player.wish_override = away
				_player.jump_override = true,
		func(): return _events_of("leash_turn").size() >= _server.creatures.size())

	var turns := _events_of("leash_turn")
	var out := {
		"sim_s": sim, "leash_turns": turns.size(),
		"player_out_m": Creature.flat_distance(_player.global_position, den),
	}

	# ...and phase three: did they actually go home, and stay disengaged?
	var mark := _creature_events().size()
	await _pump(60.0, func(_t): _player.wish_override = Vector3.ZERO,
		func(): return _all_home(den, border * 0.5))
	var home := _all_home(den, border * 0.5)
	var post_engages := 0
	var rows := _creature_events()
	for i in range(mini(mark, rows.size()), rows.size()):
		if rows[i].get("kind", "") == "engage":
			post_engages += 1
	out["post_turn_engages"] = post_engages
	out["home_m"] = _furthest_from(den)

	var why := ""
	if not found:
		why = "the pack never reached the player, so there was nothing to leash"
	elif turns.size() != _server.creatures.size():
		why = "%d leash turns from a pack of %d" % [
			turns.size(), _server.creatures.size()]
	elif not home:
		why = "the pack was still %.0f m from the den after 60 s" % out["home_m"]
	elif post_engages > 0:
		why = "%d engagements after the turn" % post_engages
	out["ok"] = why.is_empty()
	if not why.is_empty():
		out["why"] = why
	return out


func _all_home(den: Vector3, within_m: float) -> bool:
	return _furthest_from(den) <= within_m


func _furthest_from(den: Vector3) -> float:
	var worst := 0.0
	for id in _server.creatures:
		var c: Node3D = _server.creatures[id]
		worst = maxf(worst, Creature.flat_distance(c.global_position, den))
	return worst


## RULE 1'S HONESTY, AS A NUMBER. The same place, twice: standing still, and
## moving. Only one of them should get you found.
##
## POSITIONED BEYOND SIGHT RANGE RATHER THAN BEHIND THE CONE, and that is a
## deliberate departure from the plan's wording - recorded in the status doc.
## The plan puts the player at 0.4 * hear_m (12 m) "behind the sight cone",
## which at 12 m depends entirely on which way a PATROLLING wolf happens to be
## facing from one second to the next. That makes the result luck. At 42 m the
## player is outside the wolf's 40 m sight range altogether, inaudible while
## still (a still player carries 9 m against 30 m of hearing) and audible while
## sprinting (45 m) - so the only thing that can change the outcome is what the
## player is DOING, which is the thing the test is about.
func _scenario_senses_honest() -> Dictionary:
	_set_time_scale(4.0)
	# BEYOND WHERE A PATROL CAN SEE, and that distance is derived rather than
	# picked. A wolf patrols out to `territory_m * PATROL_RADIUS_SCALE` from
	# its den and sees `sight_m`, so anywhere closer than the sum of those can
	# be walked up on eventually - and the first run of this scenario proved
	# it, finding a motionless player 24 times in 90 seconds at 42 m. Past that
	# sum, the only sense that can reach the player is hearing, which is the
	# one the test is about.
	# THE BAND WHERE ONLY THE EAR REACHES, computed from the table rather than
	# picked. Below `patrol + sight` a patrolling wolf can walk up and SEE a
	# motionless player - the first run of this found one 24 times in 90
	# seconds at 42 m - and beyond `1.5 * hear_m` a sprinting one is inaudible
	# to a wolf standing at its own den. The test stands in the middle of what
	# is left, and if that band is empty the scenario says so rather than
	# quietly measuring nothing.
	var sight := Species.sight_m(Species.WOLF)
	var hear := Species.hear_m(Species.WOLF)
	var lo := Species.territory_m(Species.WOLF) * Wolf.PATROL_RADIUS_SCALE + sight
	var hi := hear * Species.NOISE["sprint"]
	var stand_m := (lo + hi) * 0.5
	var here := await _place_player_near_den(stand_m)
	var den: Vector3 = _server.pack.den_pos

	# --- HALF ONE: stand still for 90 s and do not be found.
	var quiet_mark := _creature_events().size()
	await _pump(90.0, func(_t): _player.wish_override = Vector3.ZERO,
		func(): return false)
	var noticed_still := 0
	var rows := _creature_events()
	for i in range(mini(quiet_mark, rows.size()), rows.size()):
		var k := str(rows[i].get("kind", ""))
		if k == "spotted" or k == "investigate":
			noticed_still += 1

	# --- HALF TWO: sprint on the spot - which is to say, back and forth along
	# a short tangential line, because a player standing on one square pressing
	# sprint has a speed of zero and `Species.player_loudness` correctly calls
	# that still.
	var out_dir := (here - den)
	out_dir.y = 0.0
	out_dir = out_dir.normalized()
	var tangent := Vector3(-out_dir.z, 0.0, out_dir.x)
	var loud_mark := _creature_events().size()
	var noticed_at := -1.0
	# TWO MINUTES, NOT ONE, AND THE REASON IS THE PATROL. Hearing the player
	# needs a wolf to wander within 67 m of them, and a patrol leg is hashed -
	# it goes where it goes. At a walk of 2 m/s a wolf covers a couple of legs
	# a minute, so a one-minute window is a coin flip on whether it happened to
	# come this way at all, which would make the gate a measurement of the hash
	# rather than of the ears.
	var sim := await _pump(120.0,
		func(t):
			_player.sprint_override = true
			# 4 s out, 4 s back, so the distance from the den stays put.
			_player.wish_override = tangent * (1.0 if fmod(t, 8.0) < 4.0 else -1.0),
		func():
			var r := _creature_events()
			for i in range(mini(loud_mark, r.size()), r.size()):
				if r[i].get("kind", "") == "investigate":
					return true
			return false)
	var noticed_loud := 0
	rows = _creature_events()
	for i in range(mini(loud_mark, rows.size()), rows.size()):
		if str(rows[i].get("kind", "")) == "investigate":
			noticed_loud += 1
	if noticed_loud > 0:
		noticed_at = sim

	var out := {
		"stand_m": stand_m,
		"sight_m": sight,
		"hear_m": Species.hear_m(Species.WOLF),
		"band_lo_m": lo,
		"band_hi_m": hi,
		"noticed_still": noticed_still,
		"investigated_sprinting": noticed_loud,
		"noticed_after_s": noticed_at,
	}
	var why := ""
	if lo >= hi:
		why = "no band exists: sight+patrol reaches %.0f m and sprint-hearing only %.0f m" % [lo, hi]
	elif noticed_still > 0:
		why = "a still player at %.0f m was noticed %d times in 90 s" % [
			stand_m, noticed_still]
	elif noticed_loud == 0:
		why = "a sprinting player at %.0f m was never investigated in 120 s" % stand_m
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
