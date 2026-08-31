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


# --- The pack ----------------------------------------------------------------

## Every live creature, by id.
var creatures := {}

## The one pack night 1 spawns. Night 2's marmots and eagle get their own.
var pack: PackBoard = null
var pack_nav: CreatureNav = null

## The den this pack lives at, as HomePlacement returned it.
var den := {}

var _next_id := 1
## Which seed the current creatures belong to. A reroll changes the world under
## them, so it has to change them too - and comparing seeds is how that happens
## without this file knowing what a reroll is.
var _spawned_seed := 0
var _brain_accum := 0.0
var _tick_index := 0


## Build the pack at the nearest den, once the world exists.
##
## POLLED RATHER THAN SIGNALLED, and that is a deliberate simplicity. The
## world emits `generation_finished` on every batch, so a signal would need a
## guard anyway; comparing the seed the creatures were built for against the
## world's current one gets the reroll case right for free, which is exactly
## what the probe's five-run loop needs.
func _try_spawn_pack() -> void:
	if not _is_host or world == null or not world.has_seed():
		return
	if _spawned_seed == world.world_seed:
		return
	if not world.is_idle():
		return
	_spawned_seed = world.world_seed
	_despawn_all()

	var gen: TerrainGenerator = world.generator
	var spawn := world.spawn_position_m(0.0)
	den = HomePlacement.nearest(gen, "den", spawn)
	if den.is_empty():
		push_warning("[Creatures] no den in this region - no pack")
		return

	pack = PackBoard.new(Species.WOLF, self)
	pack.den_id = int(den["id"])
	pack.den_pos = den["pos"]
	# THE FIRST ADDRESS THE WORLD EVER HAD, written into the journal as an
	# event rather than only existing as a position. `id` here is the HOME's
	# identity, not a creature's - see the schema in species.gd.
	log_event("den_placed", Species.WOLF, pack.den_id, pack.den_pos, {
		"home": "den", "danger": den["danger"], "slope_deg": den["slope_deg"],
	})

	pack_nav = CreatureNav.build(world, Species.WOLF, pack.den_pos)

	var wanted := mini(Species.pack_size(Species.WOLF),
		Species.MAX_LIVE - creatures.size())
	for k in wanted:
		var wolf := Wolf.new()
		var wolf_id := _next_id
		_next_id += 1
		# Spread around the den mouth rather than stacked in one point, or the
		# first frame has two wolves inside each other and the flank starts
		# from a coin flip.
		var angle := TAU * float(k) / float(maxi(wanted, 1))
		# ADD FIRST, THEN PLACE. `global_position` on a node that is not in the
		# tree yet is an engine error and silently returns the identity
		# transform, so a wolf positioned before it was added started at the
		# world origin - half a world away from its own den.
		add_child(wolf)
		wolf.global_position = pack.den_pos + Vector3(cos(angle), 0.0, sin(angle)) * 3.0
		wolf.setup_wolf(wolf_id, world, pack_nav, pack, self)
		creatures[wolf_id] = wolf
		pack.members.append(wolf_id)
	print("[Creatures] pack of %d at den %d, %.0f m from spawn, danger %.2f" % [
		creatures.size(), pack.den_id,
		(pack.den_pos as Vector3).distance_to(spawn), den["danger"]])


## Tear the pack down and build it again from the current numbers.
##
## The F10 panel's button. Territory is baked into the A* grid when it is
## built, so a territory slider that only changed a number would appear to do
## nothing at all - see `creature_debug.gd`'s note.
func respawn_pack() -> void:
	if not _is_host:
		return
	_spawned_seed = 0
	_try_spawn_pack()


func _despawn_all() -> void:
	for id in creatures:
		(creatures[id] as Node).queue_free()
	creatures.clear()
	for id in views:
		(views[id] as Node).queue_free()
	views.clear()
	pack = null
	pack_nav = null


## Movement every frame, brains at `Species.BRAIN_HZ`, STAGGERED.
##
## Staggered because sixteen animals all deciding on the same tick is a spike
## sixteen times the size of the one it replaces, and because a pack that
## thinks in lockstep moves in lockstep - which reads as a formation rather
## than as animals.
func _process(delta: float) -> void:
	if not _is_host:
		return
	_try_spawn_pack()
	if creatures.is_empty():
		return
	tick_senses()

	for id in creatures:
		(creatures[id] as Creature).advance(delta)

	# ...and the wire, on this node's OWN accumulator. game.gd's sync tick is
	# not touched; see decision 2.
	_sync_accum += delta
	if _sync_accum >= 1.0 / Species.SYNC_HZ:
		_sync_accum = 0.0
		var packet := rows_for(sim_centres_m())
		if Net.is_online() and not Net.other_peer_ids().is_empty():
			_cl_sync_creatures.rpc(packet)
		# The host draws its own creatures from the same rows it would send.
		_apply_rows(packet)

	_brain_accum += delta
	var period := 1.0 / Species.brain_hz()
	# ONE SLICE OF THE PACK PER SUB-TICK. At 10 Hz with two wolves each thinks
	# five times a second; with sixteen, each still thinks whenever its slice
	# comes up, and no frame ever runs more than a slice.
	var slices := maxi(creatures.size(), 1)
	while _brain_accum >= period / float(slices):
		_brain_accum -= period / float(slices)
		var ids := creatures.keys()
		var who: int = ids[_tick_index % ids.size()]
		_tick_index += 1
		var creature: Node = creatures.get(who)
		if creature is Wolf:
			(creature as Wolf).think()


# --- The wire ----------------------------------------------------------------
#
# Decisions 2 and 3: this node publishes its own rows on its own accumulator
# and its own rpc, so `game.gd`'s sync path, rates and packet shape are
# untouched. The filter is `body_field.gd`'s, copied rather than shared -
# nearest first, distance-capped, count-capped - because the two will want to
# diverge (a creature that has moved is not an interesting exception the way a
# boulder that has moved is; every creature is always moving).

## Client only. creature id -> CreatureView. The host has these too, built from
## its own creatures - see `_refresh_views`.
var views := {}

var _sync_accum := 0.0


## Every creature's row, distance-filtered and capped, nearest first.
##
## `centres` is every peer's position INCLUDING the host's own, exactly as
## BodyField's is: a creature only the host can see still has to be sent,
## because the host is not the only one who will walk over there later.
func rows_for(centres: Array) -> Dictionary:
	var out := {}
	if not _is_host or creatures.is_empty():
		return out
	var range_sq := Species.REPLICATE_RANGE_M * Species.REPLICATE_RANGE_M
	var near := []
	for id in creatures:
		var c: Creature = creatures[id]
		var best := INF
		for centre in centres:
			best = minf(best, c.global_position.distance_squared_to(centre))
		if best > range_sq:
			continue
		near.append([best, id, c])
	if near.size() > Species.ROWS_PER_PACKET:
		# NEAREST FIRST when there are too many. If a packet has to drop rows,
		# the ones to drop are the ones nobody is standing next to.
		near.sort_custom(func(a, b): return a[0] < b[0])
		near.resize(Species.ROWS_PER_PACKET)
	for entry in near:
		out[entry[1]] = (entry[2] as Creature).to_row()
	return out


## Every creature's row, unfiltered. For the probe and the selftests.
func rows() -> Dictionary:
	var out := {}
	for id in creatures:
		out[id] = (creatures[id] as Creature).to_row()
	return out


## Sent by the host, executed on every client.
##
## UNRELIABLE ORDERED, like every other continuous position feed in this
## project: a dropped creature row is corrected 50 ms later by the next one,
## and re-sending it would arrive after the correction.
@rpc("authority", "call_remote", "unreliable_ordered")
func _cl_sync_creatures(rows_in: Dictionary) -> void:
	if _is_host:
		return
	_apply_rows(rows_in)


## Build, feed and retire the display bodies.
##
## THE HOST RUNS THIS TOO, on its own creatures. One code path for what a
## creature looks like: a wolf cannot look different to the player hosting than
## to the player who joined.
func _apply_rows(rows_in: Dictionary) -> void:
	for id in rows_in:
		var row: Array = rows_in[id]
		if row.size() < 4:
			continue
		var view: CreatureView = views.get(id)
		if view == null:
			view = CreatureView.new()
			view.setup(int(row[3]), int(id))
			add_child(view)
			views[id] = view
		view.set_row(row)
	# A CREATURE THAT STOPPED BEING SENT IS GONE, whether it died, was culled
	# by the distance filter, or the pack despawned. A view kept for one that
	# is no longer in the packet is a wolf standing forever where one used to
	# be, which is worse than one that vanishes.
	for id in views.keys():
		if not rows_in.has(id):
			(views[id] as Node).queue_free()
			views.erase(id)


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
