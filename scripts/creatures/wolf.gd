class_name Wolf
extends Creature

## The rusher, and the first behaviour tree in the game.
##
## THE PACK IS THE POINT (design decision 1). Two wolves that converge from
## DIFFERENT DIRECTIONS - pillar 1's flanking, mirrored back at the players.
## A lone rusher would not answer Playtest 1's question, so the pack is not
## stretch scope, it IS the scope, and the flank is EXPLICIT rather than
## emergent: a converging member takes a bearing offset 90-140 degrees from
## the howler's, so Stage 6's gate measures a mechanism and not luck.
##
## HARD RULE 4 LIVES IN THIS FILE OR NOWHERE. No node of the tree below
## contains a distance or a position check against a player. Perception happens
## once per brain tick in `pre_tick()`, through `SensesBus` and nothing else,
## and the tree reads what it found. Coordination happens through `PackBoard`.
## The two distances this file DOES compute are against the DEN and against the
## board's remembered `target_pos` - one is not perception at all, and the
## other is perception the board already did.
##
## THE TREE IS BEEHAVE'S (Stage 0, rung b) and the shape would be the same on
## any rung:
##
##     SelectorReactive                 first branch that fires, re-checked every tick
##       leash      : beyond the border      -> turn back, go home, ignore everything
##       engage     : within engage range    -> circle, lunge on cooldown
##       converge   : the pack has howled    -> come in on a flanking bearing
##       stalk      : I can see them         -> howl if nobody has, then close
##       investigate: I heard something      -> go and look
##       patrol     : otherwise              -> walk the ring around the den
##
## Reactive rather than plain, deliberately: a wolf that hears a howl while
## halfway through a patrol leg must abandon the leg on the NEXT tick, not when
## the leg finishes.

## How close counts as engaged, as a multiple of the species' bite range. Two
## and a bit: close enough that a lunge is imminent, far enough apart that two
## wolves on opposite sides are visibly on opposite sides.
const ENGAGE_RANGE_SCALE := 2.0

## How far from the den a patrol leg goes, as a fraction of the territory.
## A DEN'S BEAT IS AROUND THE DEN. This was 0.55 - an 82 m loop walked at
## 2 m/s, which is most of a minute in one direction and put the pack's EYES
## most of the way to its border. `senses-honest` needs a band where hearing is
## the only sense that reaches, and that band only exists when the patrol is
## tighter than the difference between the ear and the eye.
const PATROL_RADIUS_SCALE := 0.30

## Seconds a wolf keeps going to where it last perceived a target before
## giving up on it. Rule 3, memory: a pack that forgets you the instant the
## cone stops containing you is a pack you can beat by stepping sideways.
const MEMORY_SECONDS := 12.0

## A returning wolf is done returning when it is this deep inside its own
## territory. Matches the `leash` scenario's own gate, deliberately: the
## behaviour and the measurement should not be able to disagree.
const HOME_AGAIN_SCALE := 0.5

## Journal a re-sighting no more often than this, in ms. Perception is
## continuous and the journal is a record of things that HAPPENED.
const SPOT_REPEAT_MS := 4000

## How near its own bearing a wolf has to be before it counts as engaged.
## See `in_engage_range` for why "near the target" is not enough.
const ON_BEARING_DEG := 15.0

## ...and how long it will keep trying to get there before engaging anyway.
const ENGAGE_TIMEOUT_MS := 8000

## The shortest a leash turn lasts, in ms, however near home the wolf already
## was. See `do_leash`.
const LEASH_COOLOFF_MS := 3000

## How near its own border counts as having been stopped by it.
##
## A WOLF PRESSED AGAINST THE MASK NEVER REACHES THE NOMINAL RADIUS, and this
## number is that gap rather than a fudge. `CreatureNav` marks every cell whose
## CENTRE is beyond `territory_m` solid, so the last walkable centre can be
## most of a 2 m cell inside the line; `Creature.WAYPOINT_M` lets it stop 1.2 m
## short of that; and a path that arrives at an angle stops short again. Twelve
## metres is a handful of cells of slack, measured from a `leash` run in which
## the pack chased to 134.5 m of its own 150 m border and stopped there.
const BORDER_MARGIN_M := 12.0

## How long one wolf's turn calls the rest of the pack home, in ms. Shorter
## than LEASH_COOLOFF_MS on purpose, so a wolf that has finished returning
## cannot be called back by its own turn.
const PACK_TURN_WINDOW_MS := 1500

var server: CreatureServer = null

## Which side this wolf flanks from, +1 or -1, hashed from its id so two
## members of a pack split rather than agreeing.
var flank_sign := 1.0

## Set on the wolf whose sighting called the pack together. The howler comes
## in straight; everybody else comes in off a bearing.
var is_howler := false

## --- What perception found this brain tick. Written ONLY by pre_tick().
var seen_peer := -1
var seen_pos := Vector3.ZERO
var heard_pos := Vector3.ZERO
var heard_kind := ""
var heard_loudness := 0.0
var heard_something := false

## Where this wolf is currently on its way to look. Vector3.INF when it is not.
var _investigating := Vector3.INF

var _was_seeing := false
var _saw_at_ms := 0
var _spot_logged_ms := 0
var _last_bite_ms := 0
var _engaged := false
## When this wolf first got within engage range of the current target, so the
## on-bearing requirement can time out. 0 when it is not close.
var _close_since_ms := 0
var _converged_for := 0
## True from a leash turn until the wolf is home again. While it is set the
## wolf ignores everything it perceives - the chase is over.
var _returning := false
var _leashed_at_ms := 0
var _brain_ms := 0
## What `_repath_to` last aimed at, so a path is kept until it is spent or the
## target has really moved.
var _path_target := Vector3.INF

var _tree: BeehaveTree = null


func setup_wolf(p_id: int, p_world: World, p_nav: CreatureNav,
		p_board: PackBoard, p_server: CreatureServer) -> void:
	setup(Species.WOLF, p_id, p_world, p_nav, p_board)
	server = p_server
	flank_sign = 1.0 if (p_id % 2) == 0 else -1.0
	_build_brain()


# --- Perception, once per brain tick -----------------------------------------

## THE ONE PLACE THIS ANIMAL FINDS ANYTHING OUT.
##
## Called by the server immediately before the tree ticks. Everything below the
## tree reads the fields this writes and never asks the bus again, which is
## what makes hard rule 4 checkable by reading one function rather than by
## auditing eleven.
func pre_tick() -> void:
	seen_peer = -1
	heard_something = false
	if server == null or server.senses == null:
		return
	# A RETURNING WOLF PERCEIVES NOTHING. Not an optimisation: it is what "the
	# chase is over" means, and without it a wolf that leashed while the player
	# was still in view would turn round, see them again, and howl - producing
	# a second leash turn from the same animal and an encounter that never ends.
	if _returning:
		return

	# THE HOWLER PUBLISHES ITS POSITION EVERY BRAIN TICK, not only while it is
	# stalking or engaging. Everybody else holds their flank against this, and
	# a howler that dropped into `investigate` or `patrol` for a few ticks left
	# the flanker aiming at where the howler had BEEN - which is exactly the
	# staleness that replacing the frozen howl bearing was supposed to end.
	if is_howler:
		board.howler_pos = global_position

	var sight := Species.sight_m(species)
	var cone := Species.sight_deg(species)
	var border := Species.territory_m(species)
	for p in server.players():
		if not SensesBus.can_see(global_position, facing(), p["pos"], sight, cone):
			continue
		# ACQUIRING A TARGET AND TRACKING ONE ARE DIFFERENT QUESTIONS, and
		# getting them confused broke this scenario twice in opposite
		# directions.
		#
		# A player standing outside the territory is visible and is not this
		# pack's business - design decision 6, "you wandered into THEIR valley;
		# you can leave it". Without that rule the leash is an infinite loop
		# rather than an ending: the pack turns back at the border, gets home,
		# sees the player still standing forty metres out, howls, finds the
		# target outside the border, and turns back again. The first `leash`
		# run journalled 140 turns from a pack of two, at ten a second.
		#
		# But a chase ALREADY UNDERWAY has to keep watching, or the pack simply
		# loses sight at the border and wanders off - no turn, no event, and
		# nothing to see. The honest leash is a pack that follows you to its
		# edge and then stops, and it can only stop at an edge it noticed you
		# crossing. So: outside the border is not somewhere a target is TAKEN,
		# and is somewhere the current target is still FOLLOWED.
		var outside := Creature.flat_distance(p["pos"], board.den_pos) > border
		var already_chasing := board.target_peer == int(p["peer"]) \
			and board.seconds_since_seen() < MEMORY_SECONDS
		if outside and not already_chasing:
			continue
		seen_peer = int(p["peer"])
		seen_pos = p["pos"]
		break

	if seen_peer >= 0:
		_saw_at_ms = Time.get_ticks_msec()
		# JOURNAL A SIGHTING, NOT A STARE. `spotted` is an event; a wolf that
		# can see you for a minute has spotted you once, and then again some
		# time later if it is worth saying.
		if not _was_seeing or Time.get_ticks_msec() - _spot_logged_ms > SPOT_REPEAT_MS:
			_spot_logged_ms = Time.get_ticks_msec()
			board.broadcast("spotted", {
				"id": id, "pos": global_position, "target": seen_peer,
				"target_pos": seen_pos,
				"range_m": global_position.distance_to(seen_pos),
			})
		else:
			# Still keep the board current even when not journalling.
			board.target_pos = seen_pos
			board.last_seen_ms = Time.get_ticks_msec()
		_was_seeing = true
	elif _was_seeing:
		_was_seeing = false
		server.log_event("lost", species, id, global_position, {
			"target": board.target_peer,
			"seconds": float(Time.get_ticks_msec() - _saw_at_ms) / 1000.0,
		})

	# Hearing. A wolf's own pack makes noise too, so anything this creature or
	# its packmates emitted is not news.
	#
	# THE KIND IS PART OF THE TEST, AND LEAVING IT OUT COST AN EVENING.
	# `source` is a peer id for a player and a creature id for a creature, and
	# the two are separate counters that both start at 1 - so on an offline
	# host, where `Net.local_peer_id()` is 1, the pack's own member #1 made the
	# player's footsteps invisible to the entire pack. `senses-honest` reported
	# it as "a sprinting player at 88 m was never investigated in 120 s", which
	# is a sentence about hearing that was really about a namespace.
	for e in server.senses.hear_events_for(global_position, Species.hear_m(species)):
		if str(e.get("kind", "")) != "player" and board.members.has(int(e["source"])):
			continue
		heard_pos = e["pos"]
		heard_kind = str(e.get("kind", ""))
		heard_loudness = float(e.get("loudness_m", 0.0))
		heard_something = true
		break
	if not heard_something:
		_investigating = Vector3.INF


## One brain tick: perceive, then decide. Called at `Species.BRAIN_HZ`.
func think() -> void:
	pre_tick()
	if _tree != null:
		_tree.tick()


# --- What the tree's leaves actually do --------------------------------------
#
# Kept as methods on the wolf rather than inside the leaves, so the leaves stay
# three lines each and the behaviour stays readable in one place.

## Am I, or the thing I am chasing, outside the border?
##
## THE HONEST LEASH (design decision 6). A chase ends because the pack turns
## back at its territory edge, not because a timer despawned something. Both
## distances here are against the DEN - which is not perception - and against
## the board's remembered target position, which is perception the board
## already did.
func should_leash() -> bool:
	if _returning:
		return true
	# A PACKMATE TURNED, SO I TURN. Brief, because it only has to survive long
	# enough for every member to get a brain tick and latch its own
	# `_returning` - after which each is running on its own clock.
	if board.turned_back_ms > 0 \
			and Time.get_ticks_msec() - board.turned_back_ms < PACK_TURN_WINDOW_MS:
		return true
	var border := Species.territory_m(species)
	# A safety net rather than the mechanism: `CreatureNav` masks everything
	# outside the territory solid, so a wolf following a path cannot get here.
	if Creature.flat_distance(global_position, board.den_pos) > border:
		return true
	if board.target_peer < 0 or board.seconds_since_seen() >= MEMORY_SECONDS:
		return false
	# The pack SAW you cross.
	if Creature.flat_distance(board.target_pos, board.den_pos) > border:
		return true
	# ...or it did not, and the border stopped it anyway.
	#
	# THIS IS THE CLAUSE THAT MAKES THE LEASH OBSERVABLE, and the `leash`
	# scenario needed it because of an honest fact about the numbers: a player
	# sprints at 13 m/s and a wolf runs at 7.5, so a player who turns and runs
	# is out of the wolf's 40 m sight within a few seconds - well before they
	# reach the 150 m border. The pack then chases the last position it knew,
	# is stopped dead by the territory mask, and stands at its own edge until
	# memory expires. That IS the leash working; it just never said so, and a
	# chase that ends in silence is indistinguishable in the journal from one
	# that never happened.
	#
	# So: still chasing, and pressed against my own border, is a turn.
	return Creature.flat_distance(global_position, board.den_pos) >= border - BORDER_MARGIN_M


func do_leash() -> void:
	look_at_pos = Vector3.INF
	if not _returning:
		_returning = true
		_leashed_at_ms = Time.get_ticks_msec()
		_engaged = false
		_close_since_ms = 0
		is_howler = false
		var over := maxf(
			Creature.flat_distance(global_position, board.den_pos),
			Creature.flat_distance(board.target_pos, board.den_pos)) - Species.territory_m(species)
		server.log_event("leash_turn", species, id, global_position, {
			"home": board.den_id, "over_by_m": maxf(over, 0.0),
		})
		# ONE WOLF TURNING TURNS THE PACK. The board is how a pack agrees, and
		# a pack half of which is still chasing is not a pack.
		board.turn_back()
		board.forget_target()
		# ...and drop whatever it was running along, or it finishes walking to
		# the chase's last waypoint before it starts going home.
		_path_target = Vector3.INF
		set_path(PackedVector3Array())
	# HOME AGAIN, AND NOT BEFORE. A wolf that leashed while already near its
	# den would otherwise clear this on the same tick it set it, which is how
	# the loop above got started in the first place - so the cool-off is a
	# floor as well as a distance.
	if Time.get_ticks_msec() - _leashed_at_ms > LEASH_COOLOFF_MS \
			and Creature.flat_distance(global_position, board.den_pos) \
			<= Species.territory_m(species) * HOME_AGAIN_SCALE:
		_returning = false
		set_path(PackedVector3Array())
		return
	speed_mps = Species.run_mps(species)
	_repath_to(board.den_pos)


## Close enough to bite.
func in_engage_range() -> bool:
	if board.target_peer < 0 or board.seconds_since_seen() > MEMORY_SECONDS:
		return false
	if Creature.flat_distance(global_position, board.target_pos) \
			> Species.bite(species)["range_m"] * ENGAGE_RANGE_SCALE:
		_close_since_ms = 0
		return false
	if _engaged:
		return true

	# ENGAGED MEANS AT BITE RANGE **AND ON MY OWN SIDE**, not merely near.
	#
	# The first version engaged on arrival, and the flank gate read 80 degrees
	# against a commanded offset of 103: a flanker journals `engage` the
	# instant it is within range, which is while it is still swinging round the
	# arc it spent thirty metres building. Measuring the flank there measures
	# the approach rather than the position.
	#
	# The one-sided timeout is the safety valve: a wolf that cannot reach its
	# bearing - the player has its back to a cliff, the arc is solid ground -
	# engages anyway rather than circling forever at four metres, which would
	# read as two dogs who have forgotten what they came for.
	var now := Time.get_ticks_msec()
	if _close_since_ms == 0:
		_close_since_ms = now
	var off := absf(rad_to_deg(angle_difference(
		atan2((global_position - board.target_pos).x,
			(global_position - board.target_pos).z),
		deg_to_rad(stand_bearing_deg()))))
	return off <= ON_BEARING_DEG or now - _close_since_ms > ENGAGE_TIMEOUT_MS


func do_engage() -> void:
	var bite: Dictionary = Species.bite(species)
	# EYES ON THE TARGET while circling it - see Creature.look_at_pos.
	look_at_pos = board.target_pos
	if is_howler:
		board.howler_pos = global_position
	var to_target := board.target_pos - global_position
	to_target.y = 0.0
	var range_m := to_target.length()
	if not _engaged:
		_engaged = true
		board.broadcast("engage", {
			"id": id, "pos": global_position, "target": board.target_peer,
			"target_pos": board.target_pos, "range_m": range_m,
			"bearing_deg": rad_to_deg(atan2(-to_target.x, -to_target.z)),
		})
	# CIRCLE AT BITE RANGE ON THIS WOLF'S OWN BEARING rather than standing in
	# the target's lap: a wolf that arrives and stops is a statue, and two
	# statues on the same side are not a flank. The bearing is the one it
	# converged on, so the geometry the pack built on the way in survives
	# arriving.
	# A CIRCLING WOLF STILL HAS TO KEEP UP. This was `run * 0.6` - 4.5 m/s
	# against a player's 4.4 m/s walk - so a player who simply kept walking
	# drew away from an engaged wolf at ten centimetres a second, slid out of
	# its 40 m sight, and the pack lost a target it was in contact with. A
	# creature holding a flank on something that is moving is not strolling.
	speed_mps = Species.run_mps(species) * 0.9
	var stand := _stand_point(bite["range_m"])
	# STRAIGHT AT IT, NOT PATHED. At this range the A* grid is coarser than the
	# move - one 2 m cell is most of a bite range - so pathing here would
	# quantise the circling into hops between two cells.
	set_path(PackedVector3Array([stand]))

	var now := Time.get_ticks_msec()
	# A LUNGE IS A LUNGE. The wolf circles at bite range and springs the last
	# bit, so the trigger is engage range and not a tight multiple of the bite
	# itself: standing at `bite_range` and requiring `bite_range * 1.35` meant a
	# wolf parked 1.2 m short of its own waypoint - the arrival tolerance - was
	# permanently just out of its own reach, and the pack circled a player for
	# twelve seconds without ever trying.
	if range_m <= bite["range_m"] * ENGAGE_RANGE_SCALE \
			and now - _last_bite_ms >= int(bite["cooldown_s"] * 1000.0):
		_last_bite_ms = now
		lunge()
		# HARD RULE 6. The damage is PROPOSED and nothing applies it. `applied`
		# is a field rather than an absence so that arming the bite on night 2
		# changes a value and not a schema - and so that the probe can assert
		# on the evidence that nothing was applied, however it got there.
		server.log_event("bite", species, id, global_position, {
			"target": board.target_peer,
			"damage_proposed": bite["damage"],
			"applied": 0.0,
		})


## The pack has been called and I am not the one who called it.
func should_converge() -> bool:
	if not board.has_howled() or is_howler:
		return false
	return board.target_peer >= 0 and board.seconds_since_seen() < MEMORY_SECONDS


## COME IN OFF A BEARING, WHICH IS THE WHOLE POINT.
##
## The howler comes straight down its own line. Everybody else takes a stand
## point on the ring around the target, offset 90-140 degrees from where the
## howler is coming from, so at engage the two are on genuinely different
## sides. The offset is hashed from the wolf's id, so it is repeatable and two
## members do not pick the same side.
func do_converge() -> void:
	if _converged_for != board.howled_at_ms:
		_converged_for = board.howled_at_ms
		board.broadcast("converge", {
			"id": id, "pos": global_position, "target": board.target_peer,
			"bearing_deg": board.howl_bearing_deg,
			"offset_deg": flank_offset_deg(),
		})
	look_at_pos = board.target_pos
	speed_mps = Species.run_mps(species)
	_repath_to(_stand_point(
		Species.bite(species)["range_m"] * ENGAGE_RANGE_SCALE * 0.9))


func can_see_target() -> bool:
	return seen_peer >= 0


## HOWL ON FIRST CONFIRMED SIGHT, then close.
func do_stalk() -> void:
	if not board.has_howled():
		var to_target := seen_pos - global_position
		to_target.y = 0.0
		is_howler = true
		board.broadcast("howl", {
			"id": id, "pos": global_position, "target": seen_peer,
			"target_pos": seen_pos,
			"bearing_deg": rad_to_deg(atan2(to_target.x, to_target.z)),
		})
		# A HOWL IS A NOISE IN THE WORLD, not only a message. It goes on the
		# same bus a footstep does, which is what will let the marmot's whistle
		# and this be one mechanism on night 2 - and what lets a player
		# eventually hear it coming.
		if server.senses != null:
			server.senses.emit_noise(global_position,
				Species.NOISE["reference_m"] * 3.0, "howl", id)
	# THE HOWLER PUBLISHES WHERE IT IS, because that is what everybody else
	# holds their flank against. Through the board, which is the only way a
	# pack is allowed to know anything about itself.
	if is_howler:
		board.howler_pos = global_position
	look_at_pos = seen_pos
	speed_mps = Species.run_mps(species)
	_repath_to(seen_pos)


func do_investigate() -> void:
	look_at_pos = Vector3.INF
	# ONE EVENT PER THING GONE TO LOOK AT, not one per tick. A noise that keeps
	# being made - a player sprinting on the spot - is heard continuously, and
	# journalling that ten times a second would drown the record it belongs to.
	if global_position.distance_to(_investigating) > REPATH_M:
		_investigating = heard_pos
		server.log_event("investigate", species, id, global_position, {
			"kind": heard_kind, "range_m": global_position.distance_to(heard_pos),
			"loudness_m": heard_loudness,
		})
	speed_mps = Species.walk_mps(species) * 1.8
	_repath_to(heard_pos)


## The ring around the den, walked at a walk. Waypoints are HASHED from the den
## and the leg number, so a pack patrols the same beat every session and a
## player who watched it once has learned something true.
func do_patrol() -> void:
	look_at_pos = Vector3.INF
	if has_path():
		return
	speed_mps = Species.walk_mps(species)
	var leg := (Time.get_ticks_msec() / 9000) + id
	var angle := WorldHash.hash01(leg, id, board.den_id & 0xFFFF, 412) * TAU
	var r := Species.territory_m(species) * PATROL_RADIUS_SCALE \
		* (0.4 + 0.6 * WorldHash.hash01(leg, id, board.den_id & 0xFFFF, 413))
	_repath_to(board.den_pos + Vector3(cos(angle), 0.0, sin(angle)) * r)


## Path to a point, but NOT every brain tick.
##
## THE FIRST VERSION REPATHED ON EVERY TICK AND THE WOLVES STOOD STILL. Ten
## times a second, `set_path` reset the waypoint index to 0 - and waypoint 0 is
## the centre of the cell the creature is already standing in, at most 1.4 m
## away. Between ticks it could cover 0.75 m, so it never reached waypoint 1
## before the path was thrown away and rebuilt. It looked like running and it
## moved nowhere, which is the most expensive kind of nothing: two full A*
## solves a second, each over 23,000 cells, to stay put.
##
## So a path is kept until it is spent or until the thing it was aimed at has
## actually moved. `REPATH_M` is generous because a chased player moves
## continuously and a wolf that recomputed for every step would be back where
## it started.
const REPATH_M := 4.0


## THE BEARING THIS WOLF COMES IN ON, in degrees, measured FROM the target.
##
## THE FLANK IS ONE NUMBER AND BOTH BRANCHES USE IT. Converging and engaging
## used to compute their own approach independently, so a wolf spent thirty
## metres holding a flank and then gave it up the moment it was close enough to
## bite - which is precisely when the flank is worth having, and precisely when
## the gate measures it.
##
## The howler comes in on its own line. Everybody else takes the howler's
## CURRENT bearing plus their offset, so the two stay on opposite sides while
## the target moves rather than only at the instant of the howl.
func stand_bearing_deg() -> float:
	var mine := global_position - board.target_pos
	var own := rad_to_deg(atan2(mine.x, mine.z))
	if is_howler or not board.has_howled():
		return own
	var to_howler := board.howler_pos - board.target_pos
	if to_howler.length_squared() < 0.01:
		# Nothing to flank off yet: fall back on the frozen howl bearing,
		# which is what the event log recorded anyway.
		return board.howl_bearing_deg + 180.0 + flank_offset_deg()
	return rad_to_deg(atan2(to_howler.x, to_howler.z)) + flank_offset_deg()


## How far off the howler this wolf comes in, signed. Hashed from the id so it
## is repeatable and two members of a pack do not pick the same side.
func flank_offset_deg() -> float:
	var band: Dictionary = Species.flank_deg(species)
	var t := WorldHash.hash01(id, board.den_id & 0xFFFF, 1, 411)
	return lerpf(band["min"], band["max"], t) * flank_sign


## A standing point `ring` metres from the target, on this wolf's bearing.
func _stand_point(ring: float) -> Vector3:
	var b := deg_to_rad(stand_bearing_deg())
	return board.target_pos + Vector3(sin(b), 0.0, cos(b)) * ring


func _repath_to(target: Vector3) -> void:
	if nav == null:
		return
	if has_path() and _path_target.distance_to(target) <= REPATH_M:
		return
	_path_target = target
	set_path(nav.path_m(global_position, target))


# --- The tree ----------------------------------------------------------------

func _build_brain() -> void:
	_tree = BeehaveTree.new()
	_tree.name = "Brain"
	# MANUAL, because the server ticks brains at 10 Hz STAGGERED and Beehave's
	# own thread would tick every one of them every physics frame - sixty times
	# the decisions for none of the difference.
	_tree.process_thread = BeehaveTree.ProcessThread.MANUAL
	_tree.enabled = false
	_tree.actor = self

	# THE TREE IS NOT ADDED TO THE SCENE TREE, and that is not a style choice.
	#
	# `BeehaveTree._ready()` registers itself with two AUTOLOADS -
	# `BeehaveGlobalDebugger` and `BeehaveGlobalMetrics` - which only Beehave's
	# EDITOR PLUGIN installs, and installing it means editing `project.godot`,
	# which this lane may not touch (three lanes are in this repo tonight).
	# Attached without them, every wolf's first frame is
	# "Attempt to call function 'register_tree' in base 'null instance'".
	#
	# A detached tree never runs `_ready`, so it never registers, and `tick()`
	# needs none of it: the blackboard is created lazily by its own getter and
	# the actor is set above. What is lost is the visual tree inspector, which
	# needs the editor plugin anyway - and if Marcel ever enables it, this
	# still works, it just stays out of the panel.
	#
	# The cost is that the tree is not freed with the wolf, so `_notification`
	# below does it by hand.

	var root := SelectorReactiveComposite.new()
	root.name = "Priorities"
	_tree.add_child(root)
	root.add_child(_branch("leash", Cond.new("should_leash"), Act.new("do_leash")))
	root.add_child(_branch("engage", Cond.new("in_engage_range"), Act.new("do_engage")))
	root.add_child(_branch("converge", Cond.new("should_converge"), Act.new("do_converge")))
	root.add_child(_branch("stalk", Cond.new("can_see_target"), Act.new("do_stalk")))
	root.add_child(_branch("investigate", Cond.new("heard_it"), Act.new("do_investigate")))
	root.add_child(Act.new("do_patrol"))


## The detached brain is nobody's child, so nobody frees it. See `_build_brain`.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _tree != null:
		_tree.free()
		_tree = null


func _branch(branch_name: String, cond: ConditionLeaf, act: ActionLeaf) -> Node:
	var seq := SequenceReactiveComposite.new()
	seq.name = branch_name
	seq.add_child(cond)
	seq.add_child(act)
	return seq


## Did I hear something? A method rather than a bare field, so every branch of
## the tree is asked in exactly the same way.
func heard_it() -> bool:
	return heard_something


## A condition that asks the actor one question.
##
## THE LEAVES ARE THREE LINES EACH ON PURPOSE. What a wolf does belongs in the
## methods above, where it can be read in one place; what the TREE does is
## priority and re-checking, and that is all these say.
class Cond extends ConditionLeaf:
	var method := ""

	func _init(p_method: String) -> void:
		method = p_method
		name = p_method

	func tick(actor: Node, _blackboard: Blackboard) -> int:
		return SUCCESS if actor.call(method) else FAILURE


## An action that tells the actor to do one thing, and keeps running.
##
## ALWAYS RUNNING, NEVER SUCCESS. A wolf's behaviours do not finish - patrol
## does not complete, engaging does not complete - and a leaf that returned
## SUCCESS would let the selector fall through to a lower branch in the same
## tick, so a wolf would engage and patrol on one decision.
class Act extends ActionLeaf:
	var method := ""

	func _init(p_method: String) -> void:
		method = p_method
		name = p_method

	func tick(actor: Node, _blackboard: Blackboard) -> int:
		actor.call(method)
		return RUNNING
