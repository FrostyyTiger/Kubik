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
@onready var _players_root: Node3D = $Players
@onready var _debug: DebugHUD = $DebugHUD
@onready var _sky: SkyCycle = $SkyCycle

## The forest beyond the voxel radius. A sibling of World rather than a child
## of it, exactly as FarField is not: the plan for this stage says the ring is
## a node in the game scene, and it keeps World's edits down to the four flora
## hooks the plan allows.
@onready var _far_trees: FarTrees = $FarTrees

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
	_sky.setup(config, $Sun, $WorldEnvironment)
	_debug.setup(config, _world, _player, _sky)
	# The session's config, which may carry CLI overrides the saved file does
	# not - so the far plane matches the fog this run actually uses.
	_player.apply_view_config(config)
	_debug.set_far_trees(_far_trees)
	# Wind and night are LOCAL knobs and live on the shared flora materials, so
	# they are pushed once here and again whenever the F4 panel moves.
	FloraModels.apply_local_knobs(config)
	Look.apply_local_knobs(config)
	# A client retuning its own terrain has silently left the host's world, so
	# the panel is read-only there. Read-only rather than synced-from-host
	# because it is the safer of the two and this is a debug tool.
	_debug.set_tuning_editable(Net.is_host())
	_debug.reroll_requested.connect(_on_reroll_requested)
	_debug.config_changed.connect(_on_config_changed)
	_debug.config_reload_requested.connect(_on_config_reload_requested)

	_world.generation_finished.connect(_on_world_ready)
	Net.peer_left.connect(_on_peer_left)
	Net.host_disconnected.connect(_on_host_disconnected)

	if not Net.is_online():
		# Reached by pressing F6 on this scene, and by single player. Host with
		# zero clients rather than a separate offline mode.
		Net.host_offline()

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

	if Net.is_host():
		# The host invents the world. Godot randomises its RNG seed at startup,
		# so this differs every session.
		_status.text = "host - generating world..."
		# Godot randomises its RNG seed at startup, so a bare host differs every
		# session; --seed pins it, which is what makes a tour reproducible.
		_world.setup(_startup_seed(), config)
		print("[Game] hosting world: seed %d, config %s" % [
			_world.world_seed, _world.config.hash_key()])
		_far_trees.setup(_world.generator, _world.config)
		_far_trees.rebuilt.connect(_on_far_trees_rebuilt)
		# The impostor ring cuts its inner edge to the frontier, so it wants to
		# know when the frontier moves (world feel v1 Stage 3).
		_world.frontier_moved.connect(_on_frontier_moved)
		_spawn_player()
	else:
		# Clients generate NOTHING until the host tells them the seed. This
		# request plus the reply is the entire world transfer: one integer and
		# a dictionary of edits, no matter how large the world is.
		_status.text = "client - asking host for the world..."
		_request_join_state()


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
		# cheap when nothing has moved - FarTrees decides for itself whether
		# the player has gone far enough to be worth a rebuild.
		_far_trees.update(_player.global_position)
	_release_player_when_ground_exists()

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
		# The host is the only one that assembles and distributes the table.
		# Skip the broadcast when hosting alone - single player is just a host
		# with no clients, and there is nobody to send to.
		if not Net.other_peer_ids().is_empty():
			_cl_sync_players.rpc(_states)
		_apply_states(_states)


## Reported once per rebuild rather than every frame - a ring is rebuilt every
## sixteen metres of walking, and its cost is the number Stage 7 is judged on.
func _on_far_trees_rebuilt(count: int, elapsed_ms: int) -> void:
	print("[FarTrees] %d impostors in %d ms" % [count, elapsed_ms])


func _on_world_ready(chunk_count: int, elapsed_ms: int) -> void:
	_chunk_count = chunk_count
	_build_ms = elapsed_ms
	_update_status()


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
	var spawn := _world.generator.spawn_block
	var spawn_block := Vector3i(
		spawn.x, _world.find_surface_y(spawn.x, spawn.y), spawn.y)
	if not _world.is_chunk_collidable(Chunk.world_to_chunk(spawn_block)):
		return
	_awaiting_ground = false
	_player.set_physics_process(true)
	print("[Game] spawn chunk ready, player released at %.1f m" % _player.global_position.y)


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
	tour.run(_world, _player, _sky)


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


## Hand the session to the streaming probe - see scripts/tools/stream_probe.gd.
func _start_stream_probe() -> void:
	$HUD.visible = false
	_debug.visible = false
	var probe := StreamProbe.new()
	probe.name = "StreamProbe"
	add_child(probe)
	probe.run(_world, _player)


## The loaded frontier moved: hand the impostor ring the new one. The ring
## rebuilds on its own schedule (REBUILD_STEP_M); this only keeps the array it
## will use current.
func _on_frontier_moved() -> void:
	if _far_trees != null:
		_far_trees.frontier = _world.loaded_frontier()


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
	_far_trees.setup(_world.generator, _world.config)
	_far_trees.rebuilt.connect(_on_far_trees_rebuilt)
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
# PROVISIONAL. Clients currently report their CAMERA POSITION, because a
# noclip debug camera has no movement rules a host could validate. When the
# real player becomes a physics body this channel becomes:
#
#     client sends INPUT -> host simulates -> host broadcasts the position
#
# The shape is already right - the host owns and distributes the table - only
# the payload changes. _srv_report_state is the function to replace.

func _publish_local_state() -> void:
	var pos := _player.global_position
	var yaw := _player.rotation.y
	var st := _player.locomotion_state()
	if Net.is_host():
		# The host writes its own row directly, appearance and all - there is
		# nobody to announce to.
		_merge_state(Net.local_peer_id(), {
			"p": pos, "y": yaw, "v": _player.velocity,
			"s": st.to_state_byte(), "l": st.look_yaw,
			"a": _player.appearance_bytes(), "n": _player.display_name(),
		})
	else:
		_srv_report_state.rpc_id(1, pos, yaw, _player.velocity,
			st.to_state_byte(), st.look_yaw)
		# Cycling the character on the F8 panel mid-session should be visible
		# to everyone else. Comparing eight bytes per tick is free; the RPC
		# only goes out when they actually differ.
		var bytes := _player.appearance_bytes()
		if bytes != _announced_appearance:
			_announce_appearance()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_report_state(pos: Vector3, yaw: float, vel: Vector3,
		state_byte: int, look_yaw: float) -> void:
	if not Net.is_host():
		return
	# The sender id comes from the network layer and cannot be spoofed, so a
	# client can only ever move itself.
	_merge_state(multiplayer.get_remote_sender_id(), {
		"p": pos, "y": yaw, "v": vel, "s": state_byte, "l": look_yaw})


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
@rpc("authority", "call_remote", "unreliable_ordered")
func _cl_sync_players(states: Dictionary) -> void:
	_apply_states(states)


func _apply_states(states: Dictionary) -> void:
	var me := Net.local_peer_id()
	for pid in states:
		if pid == me:
			continue  # We do not render ourselves.
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


## The host quit or crashed. The world was theirs, so there is nothing sensible
## to keep playing - back to the menu, which explains why.
func _on_host_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_peer_left(peer_id: int) -> void:
	# The host drops them from the authoritative table; everyone drops the
	# capsule right away rather than waiting for the next sync.
	_states.erase(peer_id)
	_remove_player(peer_id)
	_update_status()


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
	_status.text = "config changed - press F7 to rebuild terrain"


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

func _update_status() -> void:
	if not _world.is_world_ready():
		return
	_status.text = "%s (peer %d) | %d others | %d chunks in %d ms | seed %d | WASD+mouse, Space jump, [F] fly, [G] slab, [F3] debug, Esc" % [
		_role_name(), Net.local_peer_id(), _players.size(),
		_chunk_count, _build_ms, _world.world_seed]


func _unhandled_input(event: InputEvent) -> void:
	# Reaches us only if FlyCamera did not consume it, which is how the
	# two-stage Escape works: first press frees the cursor, second lands here.
	if event.is_action_pressed("ui_cancel"):
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	# TEMPORARY until we have block interaction (raycast + break/place).
	# Exists so the authority chain can be verified end to end: press G on the
	# CLIENT and the slab appears on both machines, because the client only
	# sent a request and the host broadcast the result back.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G:
			_toggle_debug_slab()


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
