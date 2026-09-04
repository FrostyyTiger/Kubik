extends Node3D

## Root of the in-game scene. Owns the join handshake and player position sync.
##
## Both peers load this same scene, so every node here sits at the same path on
## both machines - which is what makes @rpc work: Godot addresses RPCs by node
## path, and a mismatch means the call silently lands nowhere.

## Scaffolding: how far above the ground at spawn the debug slab is placed, in
## blocks. Relative rather than a fixed altitude, because the terrain at spawn
## is now anywhere between 25 and 250 blocks up depending on the seed.
const DEBUG_SLAB_CLEARANCE := 6

## How far above the ground to drop the camera once the world exists, in metres.
const SPAWN_CLEARANCE := 3.0

## Position updates per second. 20 is plenty for two players; the smoothing on
## the receiving end hides the gaps.
const SYNC_HZ := 20.0

## If the very first join request races the host scene change, ask again.
const JOIN_RETRY_SECONDS := 1.0

const REMOTE_PLAYER_SCENE := preload("res://scenes/remote_player.tscn")

@onready var _world: World = $World
@onready var _player: Player = $Player
@onready var _status: Label = $HUD/Status
@onready var _hud: Hud = $HUD
@onready var _hud_tuner: HudTuner = $HudTuner
@onready var _sheet: CharacterScreen = $CharacterScreen
@onready var _players_root: Node3D = $Players

## Built in code rather than put in the scene, because it only ever has
## children on a host and an empty node in every client's scene tree is a
## thing somebody eventually wonders about.
var _sims_root: Node3D = null

## Every body in the loaded world - a RigidBody3D each on the host, a mesh each
## on a client. See body_field.gd; World feeds it columns.
var _body_field: BodyField = null
@onready var _debug: DebugHUD = $DebugHUD
@onready var _sky: SkyCycle = $SkyCycle

## The forest beyond the voxel radius. A sibling of World rather than a child
## of it, exactly as FarField is not: the plan for this stage says the ring is
## a node in the game scene, and it keeps World's edits down to the four flora
## hooks the plan allows.
@onready var _tree_field: TreeField = $TreeField

## Every tunable number. Loaded once here and handed to World, so there is
## exactly one instance per session and no chance of two halves of the game
## generating against different values.
var config: WorldgenConfig = null

## peer_id -> RemotePlayer. Everyone except us.
var _players := {}

## HOST ONLY. peer_id -> one row of the authoritative table.
##
##     "p" Vector3          position
##     "y" float            body yaw
##     "v" Vector3          velocity, m/s
##     "s" int              state byte - see LocomotionState.to_state_byte()
##     "l" float            look yaw, radians, world space
##     "a" PackedByteArray  appearance, 8 bytes - see CharacterDef
##     "n" String           display name, at most 16 characters
##
## THE FIRST FIVE ARE REWRITTEN EVERY TICK AND THE LAST TWO ARE NOT. Appearance
## and name arrive once, on a reliable RPC, and the position path MERGES into
## the row rather than replacing it - a `_states[who] = {...}` in
## _srv_report_state would wipe a peer's appearance twenty times a second and
## the symptom would be a friend flickering back to the default human.
var _states := {}

## HOST ONLY. peer_id -> PlayerSim. The authoritative body for each remote
## peer; the table rows above are read off these.
var _sims := {}

## HOST ONLY. See journal.gd - habit 2 of the three.
var _journal := Journal.new()

## HOST ONLY. Health, stamina and mana for everybody - see stats.gd, habit 1.
##
## Beside _states rather than inside it, because the two have different
## lifetimes and different authorities: a state row is rewritten off a body
## twenty times a second, and a stat only ever changes because something
## happened. They MEET on the wire - _publish_stats() merges the three numbers
## into each peer's state row - which is the whole of Decision 1: no new
## channel, no reliable-on-change RPC, three floats on a packet that was going
## out anyway.
var _stats := StatsTable.new()

## CLIENT ONLY. The last whole table the host sent, kept so a client can read
## ANOTHER peer's stats - the party icons need a friend's health, and
## _last_authority is only ever our own row.
var _last_states := {}

## CLIENT ONLY. The part of a correction not yet applied, and how long is
## left to apply it in. An OFFSET rather than a destination, because the body
## goes on walking while the correction eases and a destination would drag it
## back to where it was when the packet arrived.
var _fix_remaining := Vector3.ZERO
var _fix_left := 0.0

## CLIENT ONLY. The last authoritative row the host sent for us.
var _last_authority := {}

## CLIENT ONLY. How many input packets we have put on the wire. Probe
## diagnostics; see PlayerSim.packets for the other end of the same count.
var _inputs_sent := 0

## HOST ONLY. Every input RPC that arrived, whichever peer it was for, and the
## id of the last sender. Probe diagnostics: an input that arrives but reaches
## no sim looks exactly like an input that never arrived.
var _inputs_received := 0
var _last_sender := 0

var _slab_present := false
var _sync_accum := 0.0
var _join_retry := 0.0
var _chunk_count := 0
var _build_ms := 0


func _ready() -> void:
	config = WorldgenConfig.load_or_default()
	_apply_view_arg()
	# After the preset, so --set can override a value the preset owns; before
	# everything that reads one.
	config.apply_cli_overrides(OS.get_cmdline_user_args())
	_apply_weather_arg()
	_apply_msaa()
	# The camera's far plane is on this line because it used to disagree with
	# the fog and nobody could see that it did: player.tscn carried a literal
	# 400 m while High fog ran to 600, so the far ridge was clipped out of
	# every frame on High and Ultra and the only symptom was a view that
	# stopped short. It is derived now (world feel v1 Stage 0); printing it is
	# what makes a future disagreement visible in one line of any log.
	print("[Game] view distance %s: voxel radius %d chunks (%d m), fog %d m, camera far %d m" % [
		config.view_distance_name(), config.voxel_radius_chunks,
		int(config.voxel_radius_chunks * Chunk.SIZE * config.block_size),
		int(config.fog_end_m),
		int(config.fog_end_m * Player.FAR_PLANE_RATIO)])
	# WHICH PHYSICS ENGINE IS ACTUALLY RUNNING (world feel v1 Stage 9). Printed
	# for the same reason the camera's far plane is: it is a project setting
	# that decides how the world behaves, and a setting nobody can see is a
	# setting that drifts. Jolt and Godot Physics differ on floor snap, step-up
	# and sleeping, so a bug report that does not say which one was running is
	# a bug report that has to be reproduced twice.
	print("[Game] physics %s at %d Hz" % [
		ProjectSettings.get_setting("physics/3d/physics_engine", "Default"),
		Engine.physics_ticks_per_second])
	# THE SKY NEEDS THE WORLD FOR ONE THING (Stage 2): where the valley floor
	# is, so the height fog and the fog bands sit in the valley rather than
	# around the camera. Wired before setup(), which applies the hour once.
	# THE FILM PASS (D40, Stage 4). Added from code rather than as a scene node
	# so `Lens.LAYER` is the single place the ordering against the HUD is
	# decided. `--lens off` and the F4 toggle hide it and switch the
	# environment's glow and grade off with it, so "lens off" is ONE state.
	var lens := Lens.new()
	lens.name = "Lens"
	add_child(lens)

	_sky.world = _world
	_sky.valley_fog = ValleyFog.new()
	_sky.valley_fog.name = "ValleyFog"
	_world.add_child(_sky.valley_fog)
	_sky.setup(config, $Sun, $WorldEnvironment)
	_apply_lens_arg()
	_debug.setup(config, _world, _player, _sky)
	# THE PLAY HUD (ui v1 Stage 4). Same shape as the line above it: this
	# node asks these four for numbers and never tells them anything.
	_hud.setup(_sky, _world, _player, self)
	_hud_tuner.setup(_hud)
	_debug.set_hud(_hud)
	_sheet.setup(_player, _hud)
	# The session's config, which may carry CLI overrides the saved file does
	# not - so the far plane matches the fog this run actually uses.
	_player.apply_view_config(config)
	_debug.set_tree_field(_tree_field)
	# Wind and night are LOCAL knobs and live on the shared flora materials, so
	# they are pushed once here and again whenever the F4 panel moves.
	FloraModels.apply_local_knobs(config)
	Look.apply_local_knobs(config)
	# TREES V3 STAGE 8. Its own call rather than a line inside
	# apply_local_knobs(), because the tree material is not one of the four
	# that function pushes to and folding it in would make a knob that moves
	# the WIND look like a knob that moves the terrain's grain.
	Look.apply_tree_knobs(config)
	# HORIZON V1 STAGE 0. The noclip speed is a static on Locomotion - see the
	# note there - written on the main thread here and again from
	# `_on_config_changed`, which is every place the knob can move.
	Locomotion.fly_speed = config.fly_speed_mps
	# AND THE FOG SWITCH, before the sky applies its first hour. `--fog off`
	# is what every colour measurement in this plan is taken through: a
	# 9 x 9 window on a hillside at 8 km is measuring the fog and not the
	# hillside otherwise, and the handover gate is about the hillside.
	SkyCycle.fog_off = "off" == _arg_value("--fog", "")
	if SkyCycle.fog_off:
		print("[Game] --fog off: every fog term zero for this run")
	# A client retuning its own terrain has silently left the host's world, so
	# the panel is read-only there. Read-only rather than synced-from-host
	# because it is the safer of the two and this is a debug tool.
	_debug.set_tuning_editable(Net.is_host())
	_debug.reroll_requested.connect(_on_reroll_requested)
	_debug.config_changed.connect(_on_config_changed)
	_debug.config_reload_requested.connect(_on_config_reload_requested)

	_world.generation_finished.connect(_on_world_ready)
	_sims_root = Node3D.new()
	_sims_root.name = "Sims"
	add_child(_sims_root)

	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.host_disconnected.connect(_on_host_disconnected)

	if not Net.is_online():
		# Reached by pressing F6 on this scene, and by single player. Host with
		# zero clients rather than a separate offline mode.
		Net.host_offline()

	# AFTER host_offline(), AND THAT ORDERING IS THE WHOLE OF IT. BodyField
	# builds RigidBody3Ds on a host and inert meshes on a client, and it decides
	# which once, here. Set up two lines earlier - before the offline fallback
	# has run - Net.is_host() is still false, and a single-player session builds
	# a world full of scenery that cannot be pushed and reports no error at all.
	# The body probe found it as "Nonexistent function 'apply_central_impulse'
	# in base Node3D (WorldBodyView)" on a session started with --host.
	#
	# Still before the world generates: the first columns land a frame or two
	# after this and their bodies would otherwise have nowhere to go.
	_body_field = BodyField.new()
	_body_field.name = "Bodies"
	add_child(_body_field)
	_body_field.setup(Net.is_host(), config.block_size, _world, _journal)
	# THE SAME INJECTION SITE, three lines apart, because they are the same
	# kind of wiring: the host's journal reaching the two things that have
	# events worth recording. World's is Decision 10 - block edits are
	# CLAUDE.md's own first example of habit 2 and were still not journalled.
	_stats.set_journal(_journal)
	_world.set_journal(_journal)
	# See _physics_process: the push must be collected after the bodies that
	# make the contacts have moved.
	process_physics_priority = 100
	_world.body_field = _body_field
	_debug.body_field = _body_field

	if "--tour" in OS.get_cmdline_user_args():
		_start_tour.call_deferred()
	elif "--traverse" in OS.get_cmdline_user_args():
		_start_traverse.call_deferred()
	elif "--flora-probe" in OS.get_cmdline_user_args():
		_start_flora_probe.call_deferred()
	elif "--stream-probe" in OS.get_cmdline_user_args():
		_start_stream_probe.call_deferred()
	elif "--physics-probe" in OS.get_cmdline_user_args():
		_start_physics_probe.call_deferred()
	elif ("--pair-probe" in OS.get_cmdline_user_args()
			or "--pair-client" in OS.get_cmdline_user_args()):
		_start_pair_probe.call_deferred()
	elif "--body-probe" in OS.get_cmdline_user_args():
		_start_body_probe.call_deferred()
	# DISTANCE V1 STAGE 0, appended at the end of the chain.
	elif "--far-probe" in OS.get_cmdline_user_args():
		_start_far_probe.call_deferred()
	# HORIZON V1 STAGE 0, appended after it.
	elif "--sprint-probe" in OS.get_cmdline_user_args():
		_start_sprint_probe.call_deferred()
	# UI V1 STAGE 4, appended after it.
	elif UiShot.hud_wanted():
		_start_hud_shots.call_deferred()

	if Net.is_host():
		# The host invents the world. Godot randomises its RNG seed at startup,
		# so this differs every session.
		_status.text = "host - generating world..."
		# Godot randomises its RNG seed at startup, so a bare host differs every
		# session; --seed pins it, which is what makes a tour reproducible.
		_world.setup(_startup_seed(), config)
		print("[Game] hosting world: seed %d, config %s" % [
			_world.world_seed, _world.config.hash_key()])
		_tree_field.setup(_world.generator, _world.config)
		_tree_field.rebuilt.connect(_on_tree_field_rebuilt)
		# The impostor ring cuts its inner edge to the frontier, so it wants to
		# know when the frontier moves (world feel v1 Stage 3).
		_world.frontier_moved.connect(_on_frontier_moved)
		_spawn_player()
		# HORIZON V1 STAGE 0. After the spawn, so it overrides it; before the
		# first frame, so the world's first refresh is already centred where
		# the run wants to be rather than loading 3,000 chunks at spawn and
		# throwing them away.
		_apply_tp_arg()
	else:
		# Clients generate NOTHING until the host tells them the seed. This
		# request plus the reply is the entire world transfer: one integer and
		# a dictionary of edits, no matter how large the world is.
		_status.text = "client - asking host for the world..."
		_request_join_state()


## THE PUSH RUNS AFTER EVERYTHING THAT CAN PUSH (world feel v1 Stage 12).
##
## `process_physics_priority` is set in _ready so that this node's physics tick
## runs AFTER the player's and every PlayerSim's. It matters: the push is read
## from `get_slide_collision()`, which reports what blocked a body's own move
## THIS tick, and a parent node's _physics_process runs before its children's
## by default - so without the priority every push would be acting on last
## tick's contacts, one tick behind the body that made them.
func _physics_process(delta: float) -> void:
	if not Net.is_host() or _body_field == null:
		return
	var pushers := []
	# The host's own player pushes exactly like anybody else. Solo is a host
	# with zero clients, and there is no second code path for it.
	if _player.is_physics_processing():
		pushers.append([_player, _player.current_input().wish])
	for peer_id in _sims:
		var sim: PlayerSim = _sims[peer_id]
		pushers.append([sim, sim.wish()])
	_body_field.push_tick(pushers, delta)


func _process(delta: float) -> void:
	# Retry the handshake if we somehow asked before the host game scene
	# existed. Cheap insurance against an otherwise silent hang.
	if Net.is_client() and not _world.has_seed():
		_join_retry -= delta
		if _join_retry <= 0.0:
			_request_join_state()

	# Voxels exist only near the player.
	if _world.has_seed():
		_world.set_center_from_position(_player.global_position)
		# And impostor trees exist only beyond them. Asked every frame and
		# cheap when nothing has moved - TreeField decides for itself whether
		# the player has gone far enough to be worth a rebuild.
		_tree_field.update(_player.global_position)
	_release_player_when_ground_exists()
	# WHAT EVERYBODY IS STANDING ON, once a frame rather than once a tick.
	# A zone lookup is a heightmap read and a noise sample, and a body crosses
	# a zone boundary in seconds - so per-frame is already far finer than the
	# thing it describes, and per physics tick would be three times the cost
	# for no difference anybody could see.
	if _world.has_seed():
		_player.ground_zone = _world.zone_at_m(
			_player.global_position.x, _player.global_position.z)
		for peer_id in _sims:
			var sim: PlayerSim = _sims[peer_id]
			sim.ground_zone = _world.zone_at_m(
				sim.global_position.x, sim.global_position.z)
	if Net.is_client():
		_advance_correction(delta)

	# A session we are no longer part of has nothing to sync, and calling rpc()
	# without a live peer is an engine error, not a no-op.
	if not Net.is_online():
		return

	_sync_accum += delta
	if _sync_accum < 1.0 / SYNC_HZ:
		return
	_sync_accum = 0.0
	_publish_local_state()
	if Net.is_host():
		# Every remote body, as the host's physics left it.
		_publish_sim_states()
		# ...and every body that has been pushed. Bookkeeping only: Jolt has
		# already simulated them correctly, and this notices what moved,
		# re-homes what left its column and keeps the journal.
		_body_field.host_tick()
		# ...and the ground under them. THE COST OF AUTHORITY: the world
		# streams around the local player, so a peer 500 m away has nothing to
		# stand on until the host builds it. See WorldgenConfig.sim_radius_chunks.
		_world.set_sim_centres(_sim_columns())
		# ...and how everybody is doing. THREE FLOATS PER PEER ON A PACKET THAT
		# WAS GOING OUT ANYWAY (Decision 1). Merged rather than assigned, the
		# same contract p/v/s obey: a `_states[who] = {...}` here would wipe
		# appearance and name twenty times a second.
		_publish_stats()
		# The host is the only one that assembles and distributes the table.
		# Skip the broadcast when hosting alone - single player is just a host
		# with no clients, and there is nobody to send to.
		if not Net.other_peer_ids().is_empty():
			_cl_sync_players.rpc(_states, _body_field.rows_for(_sim_centres_m()))
		_apply_states(_states)


## Reported once per rebuild rather than every frame - a ring is rebuilt every
## sixteen metres of walking, and its cost is the number Stage 7 is judged on.
func _on_tree_field_rebuilt(count: int, elapsed_ms: int) -> void:
	print("[TreeField] %d trees in %d ms" % [count, elapsed_ms])


func _on_world_ready(chunk_count: int, elapsed_ms: int) -> void:
	_chunk_count = chunk_count
	_build_ms = elapsed_ms
	# The host's own row. Here rather than in _ready because a host is only
	# really in the world once the world exists, and because solo play is a
	# host with zero clients - so this is the line that gives a single player
	# a set of bars at all.
	if Net.is_host():
		_stats.ensure_row(Net.local_peer_id())
	# The load message has been answered. The status line is transient now
	# (Decision 5) and a transient line that never clears is a permanent one.
	_status.text = ""


# --- Spawning ---------------------------------------------------------------
#
# The player is frozen until the ground beneath the spawn point exists.
#
# Not cosmetic: chunks are built over many frames, and a CharacterBody3D
# dropped into a world with no collision in it yet does not wait politely - it
# accelerates downward, and by the time its chunk arrives it is a hundred
# metres below and still falling. Waiting for one specific chunk rather than
# for the whole world means the wait is a moment rather than the full load.

var _awaiting_ground := false


func _spawn_player() -> void:
	# In METRES: surface_height_m answers in metres, find_surface_y in blocks,
	# and the scene graph is metres.
	# Not the origin any more. Since terrain v2 Stage 12 the world chooses a
	# spawn that satisfies the acceptance test by construction - flat, dry, a
	# mountain in view and water within a two-minute walk - rather than
	# dropping the player at (0, 0) and hoping.
	_player.global_position = _world.spawn_position_m(SPAWN_CLEARANCE)
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_awaiting_ground = true


## THE CHUNK UNDER SPAWN, not the chunk at the origin.
##
## This checked (0, 0) until terrain v2 Stage 12 moved spawn off the origin,
## and the two are not the same place any more. The world loads chunks around
## the PLAYER, so if spawn lands further from the origin than the voxel radius
## - 192 blocks at High, against a spawn search that ranges over 750 - the
## chunk at (0, 0) never loads, the condition below is never satisfied, and the
## player stays frozen with physics disabled forever.
##
## Seed 42 spawns 131 blocks out and worked by luck. The traversal probe found
## it by teleporting to a corner and reporting 0 m walked in 90 seconds.
##
## AND ITS COLLISION, NOT JUST ITS VOXELS. has_chunk() answers true the moment
## the voxels are published, but the trimesh the body actually lands on is
## installed by the mesh upload, frames later, and a body released in between
## falls straight through the world. That gap was a frame or two while
## generation trickled, and became many frames the day generation stopped
## trickling - which is when the spawn started dropping the player into rock.
func _release_player_when_ground_exists() -> void:
	if not _awaiting_ground:
		return
	# THE COLUMN THE PLAYER IS STANDING OVER, not the generator's spawn.
	#
	# The two were the same thing until horizon v1's `--tp` (grill Q10): the
	# world loads chunks around the PLAYER, so a session that teleported to
	# (20000, 0) at launch would wait forever for a chunk 20 km behind it -
	# which is the exact failure this function's own comment records from
	# terrain v2, arrived at from the other direction. Reading the player's own
	# position asks the question that was always meant: is there ground under
	# the body about to be dropped?
	var at := _player.global_position / config.block_size
	var bx := int(floor(at.x))
	var bz := int(floor(at.z))
	var ground := Vector3i(bx, _world.find_surface_y(bx, bz), bz)
	if not _world.is_chunk_collidable(Chunk.world_to_chunk(ground)):
		return
	_awaiting_ground = false
	_player.set_physics_process(true)
	print("[Game] ground chunk ready, player released at %.1f m" % _player.global_position.y)


## Seed for a new world: --seed N if given, otherwise a fresh random one.
func _startup_seed() -> int:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seed")
	if i != -1 and i + 1 < args.size():
		return args[i + 1].to_int()
	return randi()


## Hand the session over to the screenshot tour, which drives the camera to six
## vantage points, photographs each and quits.
func _start_tour() -> void:
	# The HUD is for playing, not for photographs - a debug readout across the
	# corner of every picture makes them useless for judging terrain.
	$HUD.visible = false
	_debug.visible = false
	var tour := ScreenshotTour.new()
	tour.name = "ScreenshotTour"
	add_child(tour)
	tour.run(_world, _player, _sky, self)


## Walk the player from one corner of the world to the other and time it.
##
## The world doubled to 3 km in terrain v2 and the one thing that could make
## that a mistake is traversal. See TraversalProbe for why the answer has to be
## walked rather than divided.
func _start_traverse() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := TraversalProbe.new()
	probe.name = "TraversalProbe"
	add_child(probe)
	probe.run(_world, _player)


## Hand the session to the flora streaming probe - see scripts/tools/flora_probe.gd.
func _start_flora_probe() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := FloraProbe.new()
	probe.name = "FloraProbe"
	add_child(probe)
	probe.run(_world, _player)


## Hand the session to the physics probe - see scripts/tools/physics_probe.gd.
func _start_physics_probe() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := PhysicsProbe.new()
	probe.name = "PhysicsProbe"
	add_child(probe)
	probe.run(_world, _player)


## Hand the session to the body probe - see scripts/tools/body_probe.gd.
func _start_body_probe() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := BodyProbe.new()
	probe.name = "BodyProbe"
	add_child(probe)
	probe.run(_world, _player, self)


## Hand the session to the pair probe - see scripts/tools/pair_probe.gd. Both
## halves of it run through here; the probe decides which one it is.
func _start_pair_probe() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := PairProbe.new()
	probe.name = "PairProbe"
	add_child(probe)
	probe.run(_world, _player, self)


## Hand the session to the streaming probe - see scripts/tools/stream_probe.gd.
func _start_stream_probe() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := StreamProbe.new()
	probe.name = "StreamProbe"
	add_child(probe)
	probe.run(_world, _player)


## Hand the session to the far-field probe - see scripts/tools/far_probe.gd.
##
## Needs a hosted world and nothing else: it builds FarFieldJob directly, reads
## heights back out of the triangles, and never renders. Distance v1 Stage 0.
func _start_far_probe() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := FarProbe.new()
	probe.name = "FarProbe"
	add_child(probe)
	probe.run(_world)


## Hand the session to the sprint probe - see scripts/tools/sprint_probe.gd.
##
## THE ONE PROBE THAT NEEDS A RENDERER. Every other entry in this chain is
## geometry or arithmetic and runs headless; this one is measuring the FRAME,
## so it is run under xvfb with the GPU underneath it and its first console
## line has to say Forward+ on the 3070 Ti or the number means nothing.
##
## It gets `self` as well as the world and the player, because the impostor
## ring is Game's child rather than World's and the probe reports its rebuild
## count beside the far field's.
func _start_sprint_probe() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := SprintProbe.new()
	probe.name = "SprintProbe"
	add_child(probe)
	probe.run(_world, _player, self)


## The loaded frontier moved: hand the impostor ring the new one. The ring
## rebuilds on its own schedule (REBUILD_STEP_M); this only keeps the array it
## will use current.
# --- The HUD shot harness (ui v1 Stage 4) -----------------------------------
#
#     xvfb-run -a godot --path . -- --shot-hud ui-v1-hud --seed 42
#
# writes build/ui/ui-v1-hud/{safe-noon,night,hurt,...}.png and quits.
#
# THE HARNESS COMES WITH THE HUD, NOT AFTER IT. Every stage from here on is
# judged on one of these PNGs, so the thing that takes them is built first -
# the alternative is three stages of work whose only evidence is that it
# compiled.
#
# It drives the game rather than a mock of it: the real HUD, the real stats
# table, the real fade, on the real world at seed 42. What it stages is the
# SITUATION - noon, midnight, thirty points of damage - and it stages each one
# through the same seam the game uses. There is no "shot mode" inside the HUD.

## Seconds of simulated fade to settle before each capture. Comfortably past
## fade_grace_s and either ease, so what is photographed is a steady state
## rather than a moment somewhere inside a 1.4 s transition - and a state the
## game can genuinely reach, because the settle runs the HUD's own _process.
const HUD_SHOT_SETTLE_S := 20.0


func _start_hud_shots() -> void:
	var label := UiShot.hud_label()
	print("[HudShot] %s: waiting for the world" % label)
	# The debug layers stay out of every frame. They are tools, not the field
	# register, and a photograph of the HUD with the F3 readout over it is a
	# photograph of the F3 readout.
	_debug.visible = false
	$CharacterDebug.visible = false
	_hud_tuner.visible = false
	# The status line is a transient message line now (Decision 5) and it is
	# still showing the world-load message; it is not part of the field
	# register and must not be in the picture.
	_status.visible = false

	await _hud_shot_wait_for_world()
	# THE CLOCK STOPS. A day is eight minutes and these shots take longer than
	# that on a busy box, so without this the "noon" shot would be photographed
	# at whatever hour rendering happened to reach - which is exactly the bug
	# SkyCycle.frozen was added for, and the tour already leans on it.
	_sky.frozen = true

	await _hud_shot("safe-noon", 0.5)
	await _hud_shot("night", 0.0)
	# THIRTY POINTS, through apply_delta like everything else - so the journal
	# records it and the bar reads 0.70 of its track, which is a COUNT the
	# acceptance test can check rather than an impression.
	_stats.apply_delta(Net.local_peer_id(), "hp", -30.0, "shot")
	await _hud_shot("hurt", 0.5)

	# THE PARTY, STAGED. A second peer is injected through the NORMAL path -
	# _merge_state into the authoritative table, then _apply_states, which is
	# the same function the sync tick calls - so the icons and the chevron are
	# built from a row that arrived the way every row arrives. A fake set
	# straight into the icons would photograph the icons and prove nothing
	# about the wire.
	await _hud_shot_party("party")

	# AND THE HELD THING ACTS. Slot 1 is the slab tool; using it drives
	# world.request_set_block through the one mutation path, which journals.
	# The dump below is what that is judged on.
	_hud.select_slot(0)
	use_slab_tool()
	await get_tree().process_frame

	# THE CHARACTER SHEET. Opened through the same set_open() the C key calls,
	# and the label dump printed beside it: the acceptance test COUNTS six
	# sockets and five skills rather than reading them out of a PNG, because
	# there is no OCR on this box.
	await _hud_shot_sheet("sheet")

	# THE F8 PANEL, ON SCREEN, AT 720 LOGICAL. Stage 1 replaced its hard-coded
	# 352x640 scroll box with anchors and offsets and could not photograph the
	# result, because F8 lives in this scene and this scene had no camera on it
	# until now. The debt is discharged here rather than left in the status doc.
	await _hud_shot_panel("panel-f8")

	# THE ONE SHOT THAT IS NOT A MEASUREMENT.
	#
	# Every other picture in this run answers a count: is the ink gone, is the
	# bar at 0.70, is the chevron east of centre. This one answers the question
	# the acceptance test ends on, which no count can - do the strip, the bars
	# and the world read as ONE POSTER, or does the UI look pasted on? It is
	# framed, named, and left for Marcel.
	#
	# Sunset, t = 0.75, where dusk_amount peaks and night_amount has just
	# crossed fade_night_max - so the instruments are coming in exactly as the
	# light goes, which is the whole thesis of the fade in one frame.
	await _hud_shot("dusk-poster", 0.76)

	_dump_journal("after the scripted sequence")
	print("[HudShot] done: %d shots in build/ui/%s" % [_hud_shots_taken, label])
	await _hud_shot_shutdown()


var _hud_shots_taken := 0


## One shot: set the hour, settle the fade, capture.
func _hud_shot(name: String, time_of_day: float) -> void:
	_sky.time_of_day = time_of_day
	_sky.apply()
	# The fade reads the hour it was just given, so the settle has to come
	# after it - and it is simulated rather than waited out, because
	# fade_grace_s alone would be six seconds of wall clock per shot.
	_hud.settle(HUD_SHOT_SETTLE_S)
	print("[HudShot] %s: %s" % [name, _hud.fade_line()])
	print("[HudShot]   %s" % _hud.layout_line())
	await UiShot.capture(get_tree(), name, UiShot.hud_label())
	_hud_shots_taken += 1


## A staged second peer, 20 m due east, hurt, and photographed.
##
## KIRA at 60 health is not a decoration: the icon draws its hurt arc only
## below full, the chevron's bearing is computed from this position against the
## player's, and the hue is color_for_peer(2) - a number the acceptance test
## can compute independently as fposmod(2 * 0.61803398875, 1.0).
##
## DUE EAST because east is +X under the compass's NORTH_IS_MINUS_Z, so the
## chevron must land in the east half of the strip. A bearing that came out
## west would mean the cardinal convention disagrees with itself, which is
## exactly the class of bug a single named constant is supposed to prevent and
## exactly the one nobody notices without a picture.
func _hud_shot_party(name: String) -> void:
	_sky.time_of_day = 0.5
	_sky.apply()
	var here := _player.global_position
	# KIRA, DUE EAST AND HURT. East is +X under NORTH_IS_MINUS_Z, so her
	# chevron must land in the east half of the strip; at 60 health her icon
	# must grow the hurt arc a healthy partner does not have.
	_merge_state(2, {
		"p": here + Vector3(20.0, 0.0, 0.0), "y": 0.0, "v": Vector3.ZERO,
		"s": 1, "l": 0.0, "n": "KIRA",
		"a": CharacterDef.new().to_bytes(),
		"hp": 60.0, "sp": 100.0, "mp": 100.0,
	})
	# TORV, DUE NORTH AND UNHURT, WHICH IS THE ONE THE NAMETAG CHECK NEEDS.
	# The player spawns facing north, so this body is in frame - and a body in
	# frame is the only way to photograph the ABSENCE of a floating Label3D
	# over its head. Kira, off to the east, is outside a 68 degree fov and
	# proves nothing about a tag either way.
	#
	# He is also the second icon, so the row lays out more than one - a cap of
	# four that has only ever been asked to draw one is a cap nobody has tested.
	_merge_state(3, {
		"p": here + Vector3(0.0, 0.0, -8.0), "y": 0.0, "v": Vector3.ZERO,
		"s": 1, "l": 0.0, "n": "TORV",
		"a": CharacterDef.new().to_bytes(),
		"hp": 100.0, "sp": 100.0, "mp": 100.0,
	})
	# Through the same function the sync tick uses, so the RemotePlayer is
	# spawned by the code that spawns every RemotePlayer.
	_apply_states(_states)
	_hud.settle(HUD_SHOT_SETTLE_S)
	print("[HudShot] %s: %s" % [name, _hud.party_line()])
	# WHERE TORV'S HEAD IS, IN PIXELS, so the nametag check has a named band to
	# sample rather than an eyeballed one. A tag would have floated just above
	# this point; the acceptance test asserts there is nothing there.
	var head := _player.get_camera().unproject_position(
		here + Vector3(0.0, 1.9, -8.0))
	print("[HudShot] %s: torv head at %s, tag band would be rows %d-%d" % [
		name, head, int(head.y) - 44, int(head.y) - 4])
	await UiShot.capture(get_tree(), name, UiShot.hud_label())
	_hud_shots_taken += 1


## The character sheet, open, over the world.
##
## AND THE ESCAPE TEST, WHICH IS HARD RULE 10 AS AN ASSERTION RATHER THAN AS A
## PARAGRAPH. An unconsumed ui_cancel from the open sheet walks up to this
## node's _unhandled_input, which calls Net.leave() and changes scene - one
## missed consume between a player pressing Escape on their inventory and being
## dropped out of their friend's world. The driver sends the event and then
## checks that the sheet closed AND that we are still in the game scene.
func _hud_shot_sheet(name: String) -> void:
	_sky.time_of_day = 0.5
	_sky.apply()
	_sheet.set_open(true)
	# Pinned rather than left spinning, so the shot is comparable run to run
	# for the same reason the creation screen's is.
	_sheet.pin_preview(PI)
	await get_tree().process_frame
	print("[HudShot] %s: %s" % [name, _sheet.label_dump()])
	await UiShot.capture(get_tree(), name, UiShot.hud_label())
	_hud_shots_taken += 1

	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	await get_tree().process_frame
	var still_here := get_tree().current_scene == self
	print("[HudShot] esc from the open sheet: sheet open %s, still in the game scene %s" % [
		_sheet.is_open(), still_here])
	if _sheet.is_open() or not still_here:
		push_error("[HudShot] HARD RULE 10 FAILED: esc did not close the sheet, or left the session")
	_sheet.set_open(false)


## The F8 character panel, open, over the world. Not part of the field register
## - it is a tool - so it is shot on its own and the play HUD stays out of it.
func _hud_shot_panel(name: String) -> void:
	_sky.time_of_day = 0.5
	_sky.apply()
	$CharacterDebug.visible = true
	$CharacterDebug.set_panel_open(true)
	var panel: Control = $CharacterDebug.get_child(0)
	print("[HudShot] %s: panel rect %s in a %s canvas" % [
		name, panel.get_global_rect(), get_viewport().get_visible_rect().size])
	await UiShot.capture(get_tree(), name, UiShot.hud_label())
	_hud_shots_taken += 1
	$CharacterDebug.set_panel_open(false)
	$CharacterDebug.visible = false


## Everything the host wrote down, printed. The `use` step in Stage 5 is judged
## on this, and the H key's stat_changed shows up here too.
func _dump_journal(why: String) -> void:
	var events := _journal.dump()
	print("[HudShot] journal %s: %d events" % [why, events.size()])
	for event in events:
		print("[HudShot]   %s" % event)


func _hud_shot_wait_for_world() -> void:
	var frames := 0
	# The same ceiling the tour uses. A world that has not settled in this many
	# frames is a world with something wrong with it, and hanging forever is
	# the worse of the two failures.
	while frames < 5400:
		if _world.is_world_ready() and _world.is_idle() and not _awaiting_ground:
			return
		await get_tree().process_frame
		frames += 1
	push_warning("[HudShot] gave up waiting for the world after %d frames" % frames)


func _hud_shot_shutdown() -> void:
	# Put the world down before ending the main loop, for the reason the tour
	# gives at length: without it the process sits at 100% of several cores
	# after writing its last image and never exits.
	if _world != null and is_instance_valid(_world):
		_world.reset()
	await get_tree().process_frame
	get_tree().quit()


func _on_frontier_moved() -> void:
	if _tree_field != null:
		_tree_field.frontier = _world.loaded_frontier()


# --- Join handshake ---------------------------------------------------------

func _request_join_state() -> void:
	_join_retry = JOIN_RETRY_SECONDS
	_srv_request_join_state.rpc_id(1)


## Sent by a joining client, executed on the host.
@rpc("any_peer", "call_remote", "reliable")
func _srv_request_join_state() -> void:
	if not Net.is_host():
		return
	var who := multiplayer.get_remote_sender_id()
	print("[Game] sending world state to peer %d (config %s)" % [
		who, _world.config.hash_key()])
	# The config travels WITH the seed, and it is the world's snapshot rather
	# than the live tuning object - the client has to generate against exactly
	# what the host generated against, not against whatever the host has since
	# dragged a slider to.
	_cl_receive_join_state.rpc_id(
		who, _world.world_seed, _world.config.to_dict(), _world.get_edits())


## Sent by the host, executed on the joining client.
@rpc("authority", "call_remote", "reliable")
func _cl_receive_join_state(seed_value: int, config_data: Dictionary,
		edits: Dictionary) -> void:
	if _world.has_seed():
		return  # A retry crossed with the reply. Ignore the duplicate.
	_adopt_host_config(config_data)
	_world.setup(seed_value, config)
	print("[Game] joined world: seed %d, config %s" % [
		seed_value, _world.config.hash_key()])
	_tree_field.setup(_world.generator, _world.config)
	_tree_field.rebuilt.connect(_on_tree_field_rebuilt)
	_spawn_player()
	# Safe to apply before the chunks exist: World records edits immediately
	# and replays them as each chunk is generated.
	_world.apply_edit_snapshot(edits)
	# NOW, not during the handshake. The join reply is the moment this client
	# knows it is really in the session, and the appearance rides its own
	# reliable RPC rather than being bolted onto the handshake - which is what
	# keeps the handshake, the edit path and Net untouched by this plan.
	#
	# There is deliberately no ordering requirement: if this arrives after the
	# host has already put a row in the table for us, the row simply carries
	# the default human until it lands. A late joiner therefore needs no
	# special case, and neither does a reconnect.
	_announce_appearance()


# --- Player position sync ---------------------------------------------------
#
# THE CARRIED TICKET, CLOSED (world feel v1 Stage 10). This channel used to
# carry a client's own POSITION, which meant "where is peer 3" was whatever
# peer 3 said it was, and README.md called it the largest provisional bit in
# the codebase. It now carries INPUT:
#
#     client sends input -> host simulates -> host broadcasts the position
#
# The shape did not change - the host still owns and distributes the table -
# only the payload and where the simulation runs. The sender id comes from the
# network layer and cannot be spoofed, so a client can still only ever move
# itself, and now it can only move itself the way the rules allow.
#
# WHAT IS STILL PROVISIONAL is the correction: a client that is told it is
# somewhere else eases or snaps, and does not replay the inputs the host had
# not yet processed. See _reconcile().

func _publish_local_state() -> void:
	if Net.is_host():
		# THE HOST'S OWN ROW IS STILL READ OFF ITS OWN BODY, and that is not an
		# exception to the rule this stage exists for. Solo play is a host with
		# zero clients, the local player IS the host's body, and there is
		# nothing between the two to lie. Appearance goes in directly for the
		# same reason: there is nobody to announce it to.
		var st := _player.locomotion_state()
		_merge_state(Net.local_peer_id(), {
			"p": _player.global_position, "y": _player.rotation.y,
			"v": _player.velocity,
			"s": st.to_state_byte(), "l": st.look_yaw,
			"a": _player.appearance_bytes(), "n": _player.display_name(),
		})
	else:
		var wire := _player.wire_input()
		_srv_report_input.rpc_id(1, wire.wish, wire.bits, wire.look)
		_inputs_sent += 1
		# Cycling the character on the F8 panel mid-session should be visible
		# to everyone else. Comparing eight bytes per tick is free; the RPC
		# only goes out when they actually differ.
		var bytes := _player.appearance_bytes()
		if bytes != _announced_appearance:
			_announce_appearance()


## A CLIENT SAYS WHAT IT WANTS. Thirty times a second, unreliable_ordered -
## a dropped input is superseded by the next one 33 ms later, and PlayerSim
## holds the last one for 200 ms so the gap is invisible.
##
## Nothing is validated. There is nothing in an input to validate: the worst a
## client can claim is that it is holding every key at once, which is a thing
## it could do with its hands. Everything that USED to need validating -
## position, velocity, whether that jump was possible - is now something the
## host computes rather than something it is told.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_report_input(wish: Vector2, bits: int, look: float) -> void:
	_inputs_received += 1
	if not Net.is_host():
		return
	var input := Locomotion.Intent.new()
	# Normalised here rather than trusted: a wish of length 40 would otherwise
	# be a speed hack costing one line of client code. It is the only thing in
	# the payload that has a legal range at all.
	input.wish = wish.limit_length(1.0)
	input.bits = bits
	input.look = look
	# The sender id comes from the network layer and cannot be spoofed, so a
	# client can only ever move itself.
	_last_sender = multiplayer.get_remote_sender_id()
	_sim_for(_last_sender).receive(input)


## How far from the spawn point a joining peer's body is placed.
##
## NOT ZERO, AND THIS IS A REAL BUG AND NOT A PROBE ONE. Everything spawns at
## `spawn_position_m()`, so the second body to arrive arrives inside the first.
## The pair probe found it the hard way: the peer's body landed on top of the
## host's own capsule - `hit Player ... normal (0, 1, 0)`, standing on its head
## - and was wedged there for the whole run. It was `is_on_floor()`, it took
## its input, it set a velocity of 13 m/s, and it moved nowhere, because
## move_and_slide could not get it off the thing it was standing on.
##
## 2 m is clear of two 0.8 m-wide capsules with room to spare.
const SPAWN_RING_M := 2.0


## The host's body for a peer, made on first contact.
##
## Spawned near the world's spawn point, which is the one place the host is
## guaranteed to have ground - a body created under a peer who is already
## somewhere else would fall through a world nobody has streamed. Stage 10's
## collision ring is what makes anywhere else safe.
func _sim_for(peer_id: int) -> PlayerSim:
	if _sims.has(peer_id):
		return _sims[peer_id]
	var sim := PlayerSim.new()
	sim.setup(peer_id)
	_sims_root.add_child(sim)
	# Placed around the spawn point rather than on it. The angle comes from the
	# peer id so it is stable for a given peer and spreads four of them out
	# without anyone having to keep a list of who is standing where.
	var angle := float(peer_id % 360) * TAU / 360.0
	sim.global_position = _world.spawn_position_m(SPAWN_CLEARANCE) + Vector3(
		cos(angle) * SPAWN_RING_M, 0.0, sin(angle) * SPAWN_RING_M)
	_sims[peer_id] = sim
	print("[Game] simulating peer %d from %.0f, %.0f" % [
		peer_id, sim.global_position.x, sim.global_position.z])
	return sim


## Read every simulated body into the table. Called once per sync tick, not
## once per physics tick: the table is what goes on the wire, and the wire runs
## at SYNC_HZ.
func _publish_sim_states() -> void:
	for peer_id in _sims:
		var sim: PlayerSim = _sims[peer_id]
		var st := sim.locomotion_state()
		_merge_state(peer_id, {
			"p": sim.global_position, "y": sim.rotation.y, "v": sim.velocity,
			"s": st.to_state_byte(), "l": st.look_yaw})


## Every stat row into the table that goes on the wire.
##
## DECISION 1, and the reason there is no stats RPC in this file: the three
## numbers ride the 20 Hz `_cl_sync_players` broadcast as three more per-tick
## fields on a row every client already receives and retains. RemotePlayer's
## set_target() ignores keys it does not know by construction, so a peer on an
## older build sees a friend standing in the right place and no error.
##
## Rewritten every tick even though a stat changes rarely. That is the cheap
## and correct choice: three floats against a Vector3 and a Transform already
## in the row, and a change-detecting sender would need an acknowledgement path
## to survive the packet loss unreliable_ordered exists to tolerate.
func _publish_stats() -> void:
	for peer_id in _stats.peer_ids():
		var row := _stats.get_row(peer_id)
		_merge_state(peer_id, {
			"hp": row["hp"], "sp": row["sp"], "mp": row["mp"]})


## One peer's stats, wherever this machine's copy of them lives.
##
## The host reads its own table. A client reads the last row the host sent -
## which is DISPLAY ONLY and says so: there is no client write path to a stat
## anywhere in this game, and no prediction to reconcile, because a stat is not
## a position. Empty until the first packet arrives, and the bars draw full
## against an empty row rather than empty, which is the right way round for a
## number that has not been contradicted yet.
func peer_stats(peer_id: int) -> Dictionary:
	if Net.is_host():
		return _stats.get_row(peer_id)
	var row: Dictionary = _last_states.get(peer_id, {})
	var out := {}
	for stat in StatsTable.ORDER:
		if row.has(stat):
			out[stat] = row[stat]
	return out


## HOST ONLY, and read by the self-test and the shot driver. The table itself
## stays private for the same reason _states does: apply_delta is the seam.
func stats() -> StatsTable:
	return _stats


## A CLIENT SAYS WHAT IT LOOKS LIKE. Once on joining, and again if it changes.
##
## THE HOST VALIDATES EVERY CLAIM, and stores the RE-ENCODED bytes rather than
## the ones that arrived. CharacterDef.from_bytes() clamps every field into its
## race's real range and never throws, so what goes into the table is by
## construction something every other client can build - a peer cannot crash
## another peer with a beard index of 200, because the 200 never leaves this
## function.
##
## Reliable, because an appearance that is dropped is not superseded by the
## next one the way a position is. This is the only reliable per-player RPC in
## the game and it fires about once per session.
@rpc("any_peer", "call_remote", "reliable")
func _srv_announce_appearance(bytes: PackedByteArray, claimed_name: String) -> void:
	if not Net.is_host():
		return
	var who := multiplayer.get_remote_sender_id()
	var def := CharacterDef.from_bytes(bytes)
	var clean := CharacterDef.sanitise_name(claimed_name, who)
	_merge_state(who, {"a": def.to_bytes(), "n": clean})
	print("[Game] appearance for peer %d: %s \"%s\"" % [who, Races.name_of(def.race), clean])


## Write some fields of one row without disturbing the rest of it.
func _merge_state(peer_id: int, fields: Dictionary) -> void:
	var row: Dictionary = _states.get(peer_id, {})
	for key in fields:
		row[key] = fields[key]
	_states[peer_id] = row


## The appearance this client last told the host about, so it only tells it
## again when it has something new to say.
var _announced_appearance := PackedByteArray()


func _announce_appearance() -> void:
	_announced_appearance = _player.appearance_bytes()
	_srv_announce_appearance.rpc_id(1, _announced_appearance, _player.display_name())


## "unreliable_ordered": a position update is worthless once a newer one
## exists, so dropping a late packet beats resending it. Ordered means a stale
## packet arriving out of sequence is discarded instead of making the capsule
## jump backwards.
## THE BODIES RIDE WITH THE PLAYERS, in the same packet and the same channel.
##
## They are the same kind of fact - "where is this thing right now" - with the
## same staleness rule: a newer one supersedes an older one and a dropped one
## costs nothing. Splitting them across two channels would buy nothing and
## would let a body's position arrive from a different instant than the player
## standing next to it.
@rpc("authority", "call_remote", "unreliable_ordered")
func _cl_sync_players(states: Dictionary, bodies: Dictionary = {}) -> void:
	_apply_states(states)
	_body_field.apply_rows(bodies)


func _apply_states(states: Dictionary) -> void:
	# THE WHOLE TABLE, KEPT. _last_authority is our own row only, and the party
	# icons need a FRIEND's health - which is in this table and nowhere else on
	# a client. One line, and it is what makes Stage 5 need no new traffic.
	_last_states = states
	var me := Net.local_peer_id()
	for pid in states:
		if pid == me:
			# We do not RENDER ourselves - but since Stage 10 the host is the
			# authority on where we are, so this row is a correction.
			if Net.is_client():
				_reconcile(states[pid])
			continue
		var st: Dictionary = states[pid]
		# The WHOLE row. RemotePlayer decides what it can use, which is what
		# lets the payload grow without this function growing with it.
		_player_node(pid).set_target(st)

	# Anyone we have a capsule for but who is no longer in the table has left.
	for pid in _players.keys():
		if not states.has(pid):
			_remove_player(pid)
	_update_status()


func _player_node(peer_id: int) -> RemotePlayer:
	if _players.has(peer_id):
		return _players[peer_id]
	var node: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate()
	node.setup(peer_id)
	_players_root.add_child(node)
	_players[peer_id] = node
	print("[Game] spawned a character for peer %d" % peer_id)
	return node


func _remove_player(peer_id: int) -> void:
	if not _players.has(peer_id):
		return
	_players[peer_id].queue_free()
	_players.erase(peer_id)


## THE HOST DISAGREES WITH US ABOUT WHERE WE ARE.
##
## The local body keeps predicting - you do not want a third of a second of
## input latency on your own legs - so it and the host are always slightly
## apart, and the question is only what to do about how far apart.
##
## THREE BANDS, and the reason there are three rather than a lerp is that the
## right response genuinely differs in kind:
##
##   under 0.25 m   nothing. This is the normal state. Physics runs at 60 Hz
##                  and input goes out at 30, so the host is always about one
##                  packet behind, and at sprint that is a few centimetres.
##                  Correcting it would be a permanent tremble.
##   under 2 m      ease over 100 ms. Something real happened - a jump the host
##                  resolved differently, a step the two capsules took at
##                  different moments - and it has to be fixed, but a teleport
##                  of a metre is far more jarring than a fast slide.
##   over 2 m       snap. At this distance the two simulations are telling
##                  different stories and there is nothing to preserve. Easing
##                  would drag the player through whatever is in between,
##                  which on voxel terrain is usually rock.
##
## NO ROLLBACK, and this is written down as provisional. A real client-side
## prediction replays the inputs the host had not yet processed when it sent
## this position, so the correction lands where the player will be rather than
## where they were. That needs an input sequence number, a ring buffer of the
## last N inputs on the client, and the host echoing the last sequence it
## consumed - about forty lines, and none of them useful until there is
## something in the world worth being precise about. The shape is recorded in
## README.md so the next person does not have to rediscover it.
const FIX_IGNORE_M := 0.25
const FIX_SNAP_M := 2.0
const FIX_EASE_SECONDS := 0.1

func _reconcile(row: Dictionary) -> void:
	_last_authority = row
	var authoritative: Vector3 = row.get("p", _player.global_position)
	var error := _player.global_position.distance_to(authoritative)
	if error < FIX_IGNORE_M:
		return
	if error > FIX_SNAP_M:
		_player.global_position = authoritative
		_player.velocity = row.get("v", Vector3.ZERO)
		_fix_remaining = Vector3.ZERO
		_fix_left = 0.0
		return
	# Replaces any correction still in flight rather than adding to it: this
	# packet is newer and already accounts for wherever the previous one left
	# us. Accumulating them would over-correct by a whole packet each time.
	_fix_remaining = authoritative - _player.global_position
	_fix_left = FIX_EASE_SECONDS


## Slide the last correction in. Runs on the frame, not the physics tick,
## because it is about what the player SEES; the body's own step has already
## happened by the time this moves it.
func _advance_correction(delta: float) -> void:
	if _fix_left <= 0.0:
		return
	if delta >= _fix_left:
		# The last frame of the ease pays whatever is left, so the correction
		# is exact no matter how the frames divided it.
		_player.global_position += _fix_remaining
		_fix_remaining = Vector3.ZERO
		_fix_left = 0.0
		return
	var step := _fix_remaining * (delta / _fix_left)
	_player.global_position += step
	_fix_remaining -= step
	_fix_left -= delta


## The host quit or crashed. The world was theirs, so there is nothing sensible
## to keep playing - back to the menu, which explains why.
func _on_host_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_peer_joined(peer_id: int) -> void:
	if Net.is_host():
		_stats.ensure_row(peer_id)
		_journal.log_event("peer_joined", {"peer": peer_id})


func _on_peer_left(peer_id: int) -> void:
	# The host drops them from the authoritative table; everyone drops the
	# capsule right away rather than waiting for the next sync.
	_states.erase(peer_id)
	_remove_player(peer_id)
	if Net.is_host():
		_stats.erase(peer_id)
		_journal.log_event("peer_left", {"peer": peer_id})
		if _sims.has(peer_id):
			_sims[peer_id].queue_free()
			_sims.erase(peer_id)
	_update_status()


## Every player position the host knows, in metres, its own included. The
## replication filter asks "is any body near anybody" and the host's own player
## counts: a rock only the host can see still has to reach the clients, or they
## would walk over later and find it somewhere else.
func _sim_centres_m() -> Array:
	var out := [_player.global_position]
	for peer_id in _sims:
		out.append((_sims[peer_id] as PlayerSim).global_position)
	return out


## The chunk column each simulated peer is standing in. Typed, because World
## compares this against the set it already has and an untyped array never
## compares equal to a typed one.
func _sim_columns() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for peer_id in _sims:
		var sim: PlayerSim = _sims[peer_id]
		var p := sim.global_position
		var bx := int(floor(p.x / config.block_size))
		var bz := int(floor(p.z / config.block_size))
		out.append(Vector2i(
			Chunk.floor_div(bx, Chunk.SIZE), Chunk.floor_div(bz, Chunk.SIZE)))
	return out


## The host's authoritative row for one peer, or an empty dictionary. Read by
## the pair probe; the table itself stays private.
func peer_row(peer_id: int) -> Dictionary:
	return _states.get(peer_id, {})


## Everybody except us, as {peer, row} pairs, wherever this machine's copy of
## the table lives (ui v1 Stage 5).
##
## The host reads its own `_states`; a client reads the whole table the host
## last sent. The party icons and the compass chevrons are built from this and
## from nothing else, which is what makes them cost NO NEW NETWORK TRAFFIC: a
## bearing comes out of a position the sync has always carried, and a friend's
## health out of the three floats Stage 3 put on the same packet.
func other_peer_rows() -> Array:
	var me := Net.local_peer_id()
	var table: Dictionary = _states if Net.is_host() else _last_states
	var out := []
	for peer_id in table:
		if peer_id == me:
			continue
		out.append({"peer": peer_id, "row": table[peer_id]})
	return out


## THE HOTBAR'S SLOT 1 ACTS. Called by the HUD, and it is the same call the G
## key used to make - a request through the one mutation path, which the host
## validates, applies, broadcasts and (since Stage 3) journals.
##
## The point of a stand-in item before Items v1 exists: select-and-use is
## proven end to end through the real chain rather than asserted about a chain
## nobody has driven.
func use_slab_tool() -> void:
	_toggle_debug_slab()


## What the host's body for that peer was last told. Probe diagnostics only.
func peer_input_line(peer_id: int) -> String:
	if not _sims.has(peer_id):
		return "no sim, %d inputs from %d" % [_inputs_received, _last_sender]
	return "%s; %d in from %d, %d sims" % [
		(_sims[peer_id] as PlayerSim).debug_line(),
		_inputs_received, _last_sender, _sims.size()]


## CLIENT ONLY. The last row the host sent for US - what it believes we are
## doing, as opposed to what we predicted. Empty until the first one arrives.
##
## Kept as a field rather than only consumed by _reconcile() because the size
## of the gap between this and the local body is the number Stage 10 is judged
## on, and it belongs on the F3 readout as much as in a probe.
func last_authority() -> Dictionary:
	return _last_authority


## CLIENT ONLY. Input packets sent so far.
func inputs_sent() -> int:
	return _inputs_sent


## HOST ONLY, and read by the pair probe. See journal.gd.
func journal() -> Journal:
	return _journal


## For the F4 readout and the probes.
func body_field() -> BodyField:
	return _body_field


# --- Tuning loop ------------------------------------------------------------
#
# Reroll rebuilds the world in place from a new seed, without leaving the
# session. Stage 11 makes this host-only and has clients follow, because a
# client rerolling alone is exactly the silent desync the README warns about.

func _on_reroll_requested(new_seed: int) -> void:
	# HOST ONLY. A client rerolling on its own would silently walk off into a
	# different world - no error on either machine, just a friend swimming
	# through solid rock. Same rule as every other world change: one authority.
	if not Net.is_host():
		_status.text = "only the host can reroll the world"
		return
	_apply_reroll(new_seed, config.to_dict())
	if not Net.other_peer_ids().is_empty():
		_cl_reroll.rpc(new_seed, config.to_dict())


## Sent by the host, executed on every client.
@rpc("authority", "call_remote", "reliable")
func _cl_reroll(new_seed: int, config_data: Dictionary) -> void:
	_apply_reroll(new_seed, config_data)


func _apply_reroll(new_seed: int, config_data: Dictionary) -> void:
	_adopt_host_config(config_data)
	print("[Game] reroll -> seed %d, config %s" % [new_seed, config.hash_key()])
	_slab_present = false
	_world.reset()
	_world.setup(new_seed, config)
	_spawn_player()
	_status.text = "regenerating world..."


## Take the host's numbers as our own, and tell everything that reads them.
func _adopt_host_config(config_data: Dictionary) -> void:
	config.from_dict(config_data)
	_debug.rebind(config)
	_sky.rebind(config)


## `--view low|medium|high|ultra|custom` overrides the saved preset.
##
## Exists so the four presets can be measured without editing a file between
## runs - the plan asks for chunk and vertex counts per preset, and a
## measurement you have to hand-edit the config for is a measurement nobody
## repeats. Also the fastest way to answer "is it my machine or the settings".
## `--lens off` (D40, Q11). The brief's comparison shot is a comparison of ONE
## thing, so this switch owns the whole lens: the film pass, the glow and the
## grade go together.
var lens_on := true

func _apply_lens_arg() -> void:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--lens")
	if i < 0 or i + 1 >= argv.size():
		return
	var want := argv[i + 1]
	if want != "on" and want != "off":
		push_warning("[Game] --lens %s: expected 'on' or 'off'" % want)
		return
	set_lens(want == "on")
	print("[Game] lens %s" % want)


## Turn the whole lens on or off. The F4 row and the tour's fence shots use it.
func set_lens(on: bool) -> void:
	lens_on = on
	_sky.lens_on = on
	Lens.set_enabled(self, $WorldEnvironment.environment, on)
	# The hour owns the saturation under eerie, so re-apply it: with the lens
	# back on, the grade's value is the keyframe's and not the constant.
	_sky.apply()


## `--weather eerie` (Q13). A modifier on the hour, not a fifth hour.
##
## Its own flag rather than `--set weather=eerie` because the tour and the
## brief both ask for it by name and a string knob does not fit the F4 panel's
## numeric sliders. `--set` reaches it too; this is the readable spelling.
func _apply_weather_arg() -> void:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--weather")
	if i < 0 or i + 1 >= argv.size():
		return
	var want := argv[i + 1]
	if want != "clear" and want != "eerie":
		push_warning("[Game] --weather %s: expected 'clear' or 'eerie'" % want)
		return
	config.weather = want
	print("[Game] weather %s" % want)


# --- HORIZON V1: getting anywhere ------------------------------------------
#
# GRILL Q10: "a developer teleport and a fast fly". The world is unbounded from
# Stage 2 and the view reaches 32 km from Stage 3, and neither is judgeable on
# foot at 13 m/s. Two tools, both HOST ONLY and both debug allowances in the
# sense noclip already is - they change where a developer is, never what the
# world contains.

## `--tp X Z`, in WORLD METRES, applied once at launch.
##
## After `_spawn_player`, so it overrides the spawn the world chose rather than
## racing it, and through `teleport_to` so the world's centre, the frontier and
## the far field all learn about it in the one place that knows how.
func _apply_tp_arg() -> void:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--tp")
	if i < 0 or i + 2 >= argv.size():
		return
	teleport_to(Vector2(argv[i + 1].to_float(), argv[i + 2].to_float()))


## Put the player at a world position, in metres, and tell the world.
##
## THREE THINGS IN ORDER, and leaving any of them out is a hang or a hole:
##
##   1. The body moves, and its Y is the surface there plus a clearance - a
##      body dropped at the old altitude 20 km away is either underground or
##      falling for a minute.
##   2. `set_center_from_position` so the chunk queue, the frontier and the far
##      field re-centre. Without it the player stands over a world that is
##      still loaded around where they were.
##   3. The ground wait is re-armed, because the chunks under the new position
##      do not exist yet and a body released into nothing falls out of the
##      world - which is what `_spawn_player`'s own note is about.
##
## Host only: a client's position is the host's to decide, and `--tp` on a
## client would be a client reporting where it likes, which is the one thing
## world feel v1 Stage 10 exists to have removed.
func teleport_to(xz_m: Vector2) -> void:
	if not Net.is_host():
		push_warning("[Game] teleport is host only")
		return
	var bx := int(floor(xz_m.x / config.block_size))
	var bz := int(floor(xz_m.y / config.block_size))
	var y := _world.surface_height_m(bx, bz) + SPAWN_CLEARANCE
	_player.global_position = Vector3(xz_m.x, y, xz_m.y)
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_awaiting_ground = true
	_world.set_center_from_position(_player.global_position)
	print("[Game] teleport to (%.0f, %.0f) m, ground %.1f m" % [
		xz_m.x, xz_m.y, y])


## One `--flag value` from the command line, or a fallback.
static func _arg_value(name: String, fallback: String) -> String:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find(name)
	if i >= 0 and i + 1 < argv.size():
		return argv[i + 1]
	return fallback


func _apply_view_arg() -> void:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--view")
	if i < 0 or i + 1 >= argv.size():
		return
	var wanted := argv[i + 1].strip_edges().to_lower()
	if wanted == "custom":
		config.view_distance = WorldgenConfig.VIEW_CUSTOM
		return
	for p in WorldgenConfig.VIEW_PRESETS.size():
		if WorldgenConfig.VIEW_PRESETS[p]["name"] == wanted:
			config.view_distance = p
			config.apply_view_preset()
			return
	push_warning("[Game] --view %s is not a preset, keeping %s" % [
		wanted, config.view_distance_name()])


## Antialiasing for the 3D viewport.
##
## Off by default in Forward+, and terrain is close to the worst case for that:
## every voxel edge is a hard straight line against a bright sky, which is
## exactly the geometry aliasing is most visible on. This is half of the answer
## to "not sharp - maybe missing antialiasing in the distance"; the other half
## is baked AO, which is what gives a surface something to be sharp ABOUT up
## close.
##
## Read from the config rather than project.godot so it is reachable from the
## F4 panel, and applied here rather than in World because it is a property of
## the viewport and there is one of those per game, not per world.
func _apply_msaa() -> void:
	var levels := [
		Viewport.MSAA_DISABLED, Viewport.MSAA_2X,
		Viewport.MSAA_4X, Viewport.MSAA_8X,
	]
	var level := clampi(config.msaa_level, 0, levels.size() - 1)
	get_viewport().msaa_3d = levels[level]
	print("[Game] MSAA %s" % ["off", "2x", "4x", "8x"][level])


## A knob moved in the tuning panel. The config object is shared, so World
## already sees the new value; what it does NOT have is terrain built with it.
func _on_config_changed() -> void:
	_apply_msaa()
	# Fog and day length take effect immediately - they cost nothing to change
	# and are much easier to tune when you can see the result at once. Terrain
	# shape needs a rebuild, which is what the message is about.
	_sky.rebind(config)
	# Wind and night-life are the same kind of knob - they live on the shared
	# flora materials and take effect on the next frame, with nothing to
	# rebuild. flora_radius_m and flora_draw_fraction are NOT: they change what
	# a column contains, so they land with the next column the player walks
	# into rather than immediately.
	FloraModels.apply_local_knobs(config)
	Look.apply_local_knobs(config)
	# TREES V3 STAGE 8. Its own call rather than a line inside
	# apply_local_knobs(), because the tree material is not one of the four
	# that function pushes to and folding it in would make a knob that moves
	# the WIND look like a knob that moves the terrain's grain.
	Look.apply_tree_knobs(config)
	# HORIZON V1 STAGE 0 - see _ready. Main thread, and the only two places
	# this static is ever written.
	Locomotion.fly_speed = config.fly_speed_mps
	_status.text = "config changed - press F7 to rebuild terrain"
	# DISTANCE V2 STAGE 0, AND THIS IS THE ONE LINE THIS EPIC SPENDS HERE.
	# far_terrace, far_riser_shade and distance v1's four geometry knobs change
	# the far mesh and the impostor ring and never a voxel chunk, so they do not
	# need F7's full reroll - forty seconds with the world streaming back in
	# around you, which is not an A/B anybody can judge by eye. FarField owns
	# the whole decision, including which knobs qualify and whether one actually
	# moved; this keeps whatever message it hands back. See
	# FarField.apply_far_knobs().
	_status.text = FarField.apply_far_knobs(_world, _tree_field, config, _status.text)


func _on_config_reload_requested() -> void:
	config = WorldgenConfig.load_or_default()
	_apply_view_arg()
	# After the preset, so --set can override a value the preset owns; before
	# everything that reads one.
	config.apply_cli_overrides(OS.get_cmdline_user_args())
	_apply_msaa()
	print("[Game] view distance %s: voxel radius %d chunks (%d m), fog %d m" % [
		config.view_distance_name(), config.voxel_radius_chunks,
		int(config.voxel_radius_chunks * Chunk.SIZE * config.block_size),
		int(config.fog_end_m)])
	_debug.rebind(config)
	_sky.rebind(config)
	_on_reroll_requested(_world.world_seed)


# --- HUD and debug ----------------------------------------------------------

## THE PERMANENT LINE IS GONE (ui v1 Stage 4, Decision 5).
##
## It used to say peer id, chunk count, seed and the keybind crib, always, in
## the top left of every frame - a dev convenience from before there was a HUD,
## and the thing this whole plan exists to replace. Every one of those facts is
## on the F3 readout now, where the rest of the instruments are.
##
## What is left is a TRANSIENT MESSAGE LINE: the reroll notice, the config
## message, "only the host can reroll". Those are answers to something you just
## did and they belong on screen for a moment. The line is left where it is,
## and it is empty until something has something to say.
func _update_status() -> void:
	pass


## The line the crib used to be, for the F3 readout to print.
func status_line() -> String:
	return "%s (peer %d) | %d others | %d chunks in %d ms | seed %d" % [
		_role_name(), Net.local_peer_id(), _players.size(),
		_chunk_count, _build_ms, _world.world_seed]


## The keys, for the same readout. Kept as data next to the line it prints on,
## and the one place a new binding has to be written down.
func keybind_line() -> String:
	return "WASD+mouse, Space jump, [1-5]/wheel hotbar, LMB use, [F] fly, [H] hurt, [C] sheet, Esc"


func _unhandled_input(event: InputEvent) -> void:
	# Reaches us only if FlyCamera did not consume it, which is how the
	# two-stage Escape works: first press frees the cursor, second lands here.
	if event.is_action_pressed("ui_cancel"):
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	# UI V1 STAGE 5 RETIRED THE G BINDING. The slab is hotbar slot 1 now and it
	# is used by selecting it and clicking, which drives this same request
	# through the same one mutation path - so the authority chain is still
	# verified end to end, and now by the thing a player would actually do
	# rather than by a key nothing will ever ship. See use_slab_tool().
	if event is InputEventKey and event.pressed and not event.echo:
		# TEMPORARY, AND ON THE SAME CONTRACT THE SLAB IS ON. THE COMBAT PLAN
		# DELETES THIS KEY (ui v1 Stage 3, Decision 6).
		#
		# Nothing in the game changes a stat yet, and the bars, the fade, the
		# hurt icon on a partner and the stat_changed journal event cannot be
		# DEMONSTRATED - let alone photographed - without something that does.
		# H takes 10 health off whoever presses it, host-side, through
		# apply_delta like everything else will.
		#
		# Host-only on purpose: a client key that took a client's own health
		# would be the one thing DESIGN.md's networking section forbids, and
		# writing it "just for a test" is how that rule gets broken for real.
		if event.physical_keycode == KEY_H and Net.is_host():
			var left := _stats.apply_delta(
				Net.local_peer_id(), "hp", -10.0, "debug")
			print("[Game] debug damage: hp %.0f" % left)
			return


func _toggle_debug_slab() -> void:
	_slab_present = not _slab_present
	var id := Block.SNOW if _slab_present else Block.AIR
	var y := _world.find_surface_y(0, 0) + DEBUG_SLAB_CLEARANCE
	for x in range(-1, 2):
		for z in range(-1, 2):
			# Note: a request, not a write. Even the host goes through this.
			_world.request_set_block(Vector3i(x, y, z), id)


func _role_name() -> String:
	return "host" if Net.is_host() else "client"
