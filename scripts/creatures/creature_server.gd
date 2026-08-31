class_name CreatureServer
extends Node

## Every creature in the world, and the only thing that decides anything about
## one.
##
## SELF-CONTAINED AND SELF-TICKING, which is decision 2 of
## `docs/plans/creatures-v1-tech.md` and is a fact about the night rather than
## about creatures: `game.gd` belongs to the ui lane tonight, so this node owns
## its own accumulator and its own `@rpc` and asks that file for exactly two
## things - to be built, and for the list of places players are standing.
##
## HOST DECIDES, CLIENT DISPLAYS (hard rule 7). Built on both, from one
## `add_child` in game.gd's banner block, and `_is_host` decides once at setup
## which of the two this is - the BodyField ordering rule, for the BodyField
## reason: read `Net.is_host()` a moment too early and a single-player session
## silently builds a world with no brains in it.
##
## Stage 2 builds the skeleton and the probe hook. The brains arrive in
## Stage 6, the wire and the views in Stage 7.

## Where the world is, for anything that needs to ask about ground.
var world: World = null

## HOST ONLY. See `scripts/game/journal.gd` - habit 2 of the three. Creature
## events are journal events, and the schema is `Species`'s block comment.
var journal: Journal = null

## The game scene, for the probe's sake - it needs a player to drive and a HUD
## to hide. NOT for reaching into: the centres come through `_centres`.
var game: Node = null

## WHERE THE PLAYERS ARE, as a Callable handed over by game.gd's banner block.
##
## A CALLABLE RATHER THAN A METHOD NAME, and that is the whole reason this lane
## adds no function to `game.gd`. The centres live in a private member of a
## file another lane owns tonight; a public accessor would have been a second
## edit to that file, and naming the private one from here would have been
## worse. Handing over a bound Callable lets game.gd choose what it exposes, in
## the one block it already gave us.
var centres: Callable = Callable()

## THE ONLY WAY A CREATURE PERCEIVES ANYTHING - hard rule 4. Host only; a
## client's copy stays null and nothing on a client ever asks.
var senses: SensesBus = null

var _is_host := false


## Called from game.gd's banner block, on host and client alike.
func setup(p_is_host: bool, p_world: World, p_journal: Journal,
		p_game: Node, p_centres: Callable) -> void:
	_is_host = p_is_host
	world = p_world
	journal = p_journal
	game = p_game
	centres = p_centres
	if _is_host:
		senses = SensesBus.new()


func is_host() -> bool:
	return _is_host


## Every place a player is standing, in metres, the host's own included.
##
## Empty rather than wrong when the hook is missing: a creature that thinks
## nobody is anywhere does nothing, which is a much better failure than one
## that thinks everybody is at the origin.
func sim_centres_m() -> Array:
	if not centres.is_valid():
		return []
	return centres.call()


## Every player the host knows about: peer id, position, velocity, state byte.
##
## READ THROUGH `game.peer_row()`, WHICH IS PUBLIC, and that is the point. The
## host's authoritative table already carries everything the senses bus needs -
## where a player is, how fast, and the state byte that says whether they are
## sprinting - so the alternative was for this lane to invent a second, worse
## description of what a player is doing. The bound `centres` Callable is the
## fallback, used only before the first sync tick has filled that table, and it
## reports a still player because that is the quietest honest guess.
func players() -> Array:
	var out := []
	if not _is_host:
		return out
	if game != null and game.has_method("peer_row"):
		var ids := [Net.local_peer_id()]
		ids.append_array(Net.other_peer_ids())
		for peer_id in ids:
			var row: Dictionary = game.peer_row(peer_id)
			if row.is_empty() or not row.has("p"):
				continue
			out.append({
				"peer": peer_id, "pos": row["p"],
				"vel": row.get("v", Vector3.ZERO),
				"state": int(row.get("s", 1)),
			})
	if not out.is_empty():
		return out
	# Before the first sync tick, or on a build where the table is not there.
	var i := 0
	for pos in sim_centres_m():
		out.append({"peer": -1 - i, "pos": pos, "vel": Vector3.ZERO, "state": 1})
		i += 1
	return out


## One server tick of perception: every player's footfall onto the bus, and
## the expired noises off it.
##
## ONCE PER TICK, NOT ONCE PER CREATURE. Sixteen wolves asking sixteen times
## what the same two players are doing is the same answer computed sixteen
## times, and it is also how a bus quietly becomes a per-creature distance
## check with extra steps.
func tick_senses() -> void:
	if not _is_host or senses == null:
		return
	senses.tick_player_noise(players())
	senses.prune()


## Record one creature event. THE ONE PLACE a creature writes to the journal.
##
## Every event carries `{species, id, pos}` on top of the `kind` and `t`
## Journal adds - see the schema in `species.gd`. Funnelling it through here
## rather than letting each behaviour call `log_event` is what makes that
## promise checkable instead of aspirational, and it is why the probe can
## validate a whole run against the schema without trusting anybody.
func log_event(kind: String, species: int, id: int, pos: Vector3,
		fields: Dictionary = {}) -> void:
	if journal == null or not _is_host:
		return
	var row := fields.duplicate()
	row["species"] = species
	row["id"] = id
	row["pos"] = pos
	journal.log_event(kind, row)


# --- The probe hook ----------------------------------------------------------

## Hand the session to the creature probe - see
## `scripts/tools/creature_probe.gd`.
##
## LIVES HERE RATHER THAN IN game.gd, so that file's whole diff is one banner
## block and one elif. The HUD hiding every other probe does in game.gd is done
## by the probe itself, for the same reason.
func start_probe() -> void:
	var probe := CreatureProbe.new()
	probe.name = "CreatureProbe"
	add_child(probe)
	probe.run(self)
