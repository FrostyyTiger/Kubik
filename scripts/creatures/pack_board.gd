class_name PackBoard
extends RefCounted

## What a pack knows, shared. One instance per pack, injected into every
## member's tree context.
##
## RULE 2 OF DESIGN.md's FIVE - communication - AND IT IS ONE MECHANISM, NOT
## TWO. Design decision 2 makes this explicit and it is the reason the class is
## called a board rather than a wolf thing: "one marmot whistles and every
## marmot on the bench dives" and "one wolf finds you and the pack converges
## from different directions" are the SAME broadcast, with two species
## listening. Building it once is what makes the marmot cheap on night 2.
##
## IT IS ALSO RULE 3 - memory. `target_pos` and `last_seen_ms` outlive the
## sighting, which is what lets a pack keep going to where you WERE rather than
## forgetting you the instant the cone stops containing you. A blackboard
## entry, not a system, exactly as DESIGN.md says.
##
## HOST ONLY, like everything else that decides.
##
## Deliberately NOT called `Blackboard`: the vendored Beehave declares a global
## class by that name, and two things called the same thing in one project is a
## bug waiting for a tired evening.

## Which species this pack is, for the journal.
var species := Species.WOLF

## The creature ids in it. Written by CreatureServer as it spawns them.
var members: Array[int] = []

## The home this pack is anchored to - design decision 6's address. `den_id` is
## the `HomePlacement` identity; `den_pos` is where it is, in metres.
var den_id := 0
var den_pos := Vector3.ZERO

## THE SHARED TARGET. -1 for "nobody", which is not the same as a target at the
## origin and the distinction has bitten every codebase that used 0.
var target_peer := -1

## Where the target was when it was last perceived, and when that was. Kept
## after the target is lost, which is the memory.
var target_pos := Vector3.ZERO
var last_seen_ms := 0

## When the pack was last called together. Read to stop a wolf howling twice
## about the same sighting, and by the probe to measure howl-to-converge.
var howled_at_ms := 0

## The bearing the howler had to the target, in DEGREES, world space. The
## converging members offset from THIS - which is what makes the flank a
## mechanism the probe can measure rather than an emergent maybe.
var howl_bearing_deg := 0.0

## Set by the server so a broadcast can be journalled. May be null in tests.
var server: CreatureServer = null


func _init(p_species := Species.WOLF, p_server: CreatureServer = null) -> void:
	species = p_species
	server = p_server


## THE ONE WAY ANYTHING TELLS THE PACK ANYTHING.
##
## Writes the board and journals the event, in that order, because a reader
## woken by the journal must not be able to see an event about a board that has
## not been updated yet.
##
## `data` must carry `id` (who is broadcasting) and `pos` (where they are) -
## the two fields the schema in `species.gd` requires of every creature event -
## and whatever else the kind means. Required rather than defaulted: an event
## with no position is an event a director cannot place, and silently writing a
## zero would make that failure invisible.
func broadcast(kind: String, data: Dictionary) -> void:
	if not data.has("id") or not data.has("pos"):
		push_warning("[PackBoard] '%s' broadcast with no id/pos - dropped" % kind)
		return
	_apply(kind, data)
	if server != null:
		var fields := data.duplicate()
		fields.erase("id")
		fields.erase("pos")
		server.log_event(kind, species, int(data["id"]), data["pos"], fields)


## What each kind means to the board. Kinds not named here are journal-only,
## which is a real category: `lost` and `leash_turn` are things that HAPPENED
## and deliberately do not erase what the pack remembers.
func _apply(kind: String, data: Dictionary) -> void:
	match kind:
		"spotted":
			target_peer = int(data.get("target", target_peer))
			target_pos = data.get("target_pos", target_pos)
			last_seen_ms = Time.get_ticks_msec()
		"howl":
			target_peer = int(data.get("target", target_peer))
			target_pos = data.get("target_pos", target_pos)
			last_seen_ms = Time.get_ticks_msec()
			howled_at_ms = last_seen_ms
			howl_bearing_deg = float(data.get("bearing_deg", howl_bearing_deg))
		"engage":
			target_pos = data.get("target_pos", target_pos)
			last_seen_ms = Time.get_ticks_msec()


## How long since the target was perceived, in seconds. INF when it never was,
## rather than a very large number that arithmetic might survive.
func seconds_since_seen() -> float:
	if last_seen_ms == 0:
		return INF
	return float(Time.get_ticks_msec() - last_seen_ms) / 1000.0


## Has the pack been called together about the current target?
func has_howled() -> bool:
	return howled_at_ms != 0


## Forget the target, but not the den. Called when a pack leashes home: the
## chase is over, and the next one starts clean.
func forget_target() -> void:
	target_peer = -1
	howled_at_ms = 0
	last_seen_ms = 0
