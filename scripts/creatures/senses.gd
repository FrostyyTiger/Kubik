class_name SensesBus
extends RefCounted

## What a creature can perceive, and the ONLY way it is allowed to find out.
##
## HARD RULE 4, AND IT IS ABSOLUTE: no behaviour tree and no utility score may
## contain a raw distance-or-position check against a player. A creature asks
## `can_see` or `hear_events_for` and gets an answer, or it does not know.
##
## THE INTERFACE IS HONEST FROM DAY ONE AND THE IMPLEMENTATION IS NOT, which is
## design decision 3 of `docs/plans/creatures-v1.md` and the whole reason this
## file exists this early. What ships tonight is a sight cone and a hearing
## radius - no occlusion, no scent, no wind carry, no darkness modifier. What
## does NOT ship is any tree that knows that. So "make it honest later" means
## replacing the inside of two functions, not rewriting every creature.
##
## The named deferrals, so nobody has to guess what "simplified" meant:
##
##   - OCCLUSION. A wolf sees you through a ridge. Fixing it means a heightmap
##     ray-march between the two points; the heightmap is already the right
##     structure for it and it is cheap, so this is a stage rather than a
##     project. It is deferred because it changes numbers Stage 6 is tuning
##     against and doing both at once would leave neither measurable.
##   - SCENT, carried downhill on the wind. DESIGN.md's rule 1 names it as the
##     thing that makes a wolf an animal players LEARN.
##   - DARKNESS. DESIGN.md § Night says v1 changes boldness only mildly; sight
##     range by time of day belongs with it.
##
## HOST ONLY. A client's senses would be a client deciding something.

## How long a transient noise stays audible, in milliseconds.
##
## A noise is a MOMENT, not a state: a stick breaks and then it has broken. Two
## brain ticks at `Species.BRAIN_HZ` is long enough that a creature whose turn
## comes up just after the sound still gets to hear it, and short enough that
## nothing is chasing an echo.
const TRANSIENT_MS := 250

## Continuous noise, one entry per source, rewritten every server tick.
##
## A WALKING PLAYER IS NOT AN EVENT STREAM. Emitting a fresh transient twenty
## times a second would make the bus a landfill and would make "how many noises
## can you hear" mean nothing. A player is one standing noise whose loudness
## changes; keyed by source, so re-emitting replaces rather than accumulates.
var _standing := {}

## One-off noises with a lifetime: a howl, a rockfall, a whistle.
var _transient: Array[Dictionary] = []


# --- Emission ----------------------------------------------------------------

## A noise happened here, and it carries this far.
##
## `loudness_m` is metres - specifically, how far this noise carries for a
## listener of reference hearing (`Species.NOISE["reference_m"]`). See that
## constant for why the two units are calibrated rather than merely both being
## metres. `kind` is what it was; `source` names who made it, so a creature
## never mistakes its own footfall for a player's.
func emit_noise(pos: Vector3, loudness_m: float, kind: String, source: int) -> void:
	_transient.append({
		"pos": pos, "loudness_m": loudness_m, "kind": kind,
		"source": source, "t": Time.get_ticks_msec(),
	})


## A noise that is ongoing rather than instantaneous. Replaces this source's
## previous one rather than adding to it.
func set_standing_noise(pos: Vector3, loudness_m: float, kind: String,
		source: int) -> void:
	_standing[source] = {
		"pos": pos, "loudness_m": loudness_m, "kind": kind,
		"source": source, "t": Time.get_ticks_msec(),
	}


func clear_standing_noise(source: int) -> void:
	_standing.erase(source)


## Every player's footfall, once per server tick.
##
## Reads the state byte the sync row already carries rather than inventing a
## second description of what a player is doing - see
## `Species.player_loudness`, and `LocomotionState.to_state_byte` for the byte.
## `players` is what `CreatureServer.players()` returns.
func tick_player_noise(players: Array) -> void:
	var live := {}
	for p in players:
		var peer: int = p["peer"]
		live[peer] = true
		var vel: Vector3 = p.get("vel", Vector3.ZERO)
		var factor := Species.player_loudness(
			int(p.get("state", 1)), Vector2(vel.x, vel.z).length())
		set_standing_noise(p["pos"], Species.NOISE["reference_m"] * factor,
			"player", peer)
	# A peer who left stops making noise. Without this a disconnected player is
	# an eternal sound at the place they vanished, and the pack investigates it
	# forever.
	for source in _standing.keys():
		if not live.has(source):
			_standing.erase(source)


## Drop transients that have finished being audible. Called once per server
## tick, so the arithmetic below is over a handful of entries.
func prune() -> void:
	var now := Time.get_ticks_msec()
	var kept: Array[Dictionary] = []
	for e in _transient:
		if now - int(e["t"]) <= TRANSIENT_MS:
			kept.append(e)
	_transient = kept


# --- Queries -----------------------------------------------------------------

## Is `target_pos` inside a cone of `sight_deg` centred on `facing`, within
## `sight_m`?
##
## FLAT, ON PURPOSE. The cone is measured in the XZ plane and altitude is
## ignored, which is right for animals standing on the same hillside and wrong
## for the eagle - whose v1 job is to orbit and cry and never interact, so it
## never asks. When it does, that is the same "swap the inside of the function"
## the class docstring promises.
##
## `sight_deg` is the FULL width of the cone, so 110 degrees means 55 either
## side of the nose. Half-angles are the classic off-by-two here.
static func can_see(from_pos: Vector3, facing: Vector3, target_pos: Vector3,
		sight_m: float, sight_deg: float) -> bool:
	var to_target := target_pos - from_pos
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > sight_m:
		return false
	# STANDING ON EACH OTHER IS SEEING EACH OTHER. Normalising a zero vector
	# gives a zero vector, whose dot with anything is 0 - which reads as
	# 90 degrees off the nose and would make a creature blind to something
	# inside its own body.
	if distance < 0.001:
		return true
	var forward := Vector3(facing.x, 0.0, facing.z)
	if forward.length_squared() < 0.000001:
		return false
	var cos_limit := cos(deg_to_rad(clampf(sight_deg, 0.0, 360.0) * 0.5))
	return forward.normalized().dot(to_target / distance) >= cos_limit


## Every noise a listener at `pos` with this hearing can currently make out.
##
## Loudest first, because a creature that investigates one thing should
## investigate the most arresting thing. Each returned row is the emitted event
## plus `range_m` (how far away it was) and `margin` (how far inside the
## audible radius it fell, 0 at the very edge and 1 on top of it) - so an
## investigate can be about the sound rather than about a second distance
## check, which would be hard rule 4 in through the window.
func hear_events_for(pos: Vector3, hear_m: float) -> Array:
	var out := []
	if hear_m <= 0.0:
		return out
	var now := Time.get_ticks_msec()
	for e in _standing.values():
		_consider(out, e, pos, hear_m)
	for e in _transient:
		if now - int(e["t"]) <= TRANSIENT_MS:
			_consider(out, e, pos, hear_m)
	out.sort_custom(func(a, b): return a["margin"] > b["margin"])
	return out


func _consider(out: Array, e: Dictionary, pos: Vector3, hear_m: float) -> void:
	var audible := hear_m * (float(e["loudness_m"]) / float(Species.NOISE["reference_m"]))
	if audible <= 0.0:
		return
	var range_m := pos.distance_to(e["pos"])
	if range_m > audible:
		return
	var row := e.duplicate()
	row["range_m"] = range_m
	row["margin"] = 1.0 - (range_m / audible)
	out.append(row)


## For the selftest and the F10 readout: how much is on the bus right now.
func size() -> int:
	return _standing.size() + _transient.size()
