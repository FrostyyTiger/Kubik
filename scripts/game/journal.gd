class_name Journal
extends RefCounted

## What happened, in order, as the host saw it.
##
## HABIT 2 OF THE THREE (CLAUDE.md): keep the journal. The host already sees
## every event worth knowing about - a block edit, a death, a campfire lit, the
## first sight of a lake, a friend arriving - and the director this project is
## eventually for reads a JOURNEY, not a world state. A world state answers
## "where is the player"; a journal answers "what has this trip been like",
## which is the only one of the two a director can respond to.
##
## It costs nothing today, which is the point of writing it today. The
## alternative is reaching the director milestone and discovering that the
## events it wants to read were never recorded because each one was, at the
## time, one line of somebody else's function.
##
## HOST ONLY. A client's journal would be a journal of what a client was told,
## which is a different and much less useful document.
##
## IN MEMORY, AND DELIBERATELY NOTHING ELSE. No file, no rotation, no cap - the
## session plan gives it a file, and a persistence format invented before there
## is anything to persist is a format that gets thrown away. `dump()` exists so
## that a probe or the F8 panel can read it back.

var _events: Array[Dictionary] = []


## Record one event. `kind` is the only required key and everything else is
## whatever that kind means; there is no schema on purpose, because inventing
## one before the second consumer exists is how tables become prose.
func log_event(kind: String, fields: Dictionary = {}) -> void:
	var row := fields.duplicate()
	row["kind"] = kind
	# Milliseconds since the session started, not a wall clock. What a director
	# wants to know is how long ago something happened relative to everything
	# else, and a wall clock drags a timezone into the data for no gain.
	row["t"] = Time.get_ticks_msec()
	_events.append(row)


func dump() -> Array[Dictionary]:
	return _events.duplicate()


func size() -> int:
	return _events.size()
