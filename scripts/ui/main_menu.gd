extends Control

## Host / Join / Quit. The menu never touches ENet directly - it only talks to
## the `Net` autoload and reacts to its signals.

@onready var _character_button: Button = $Center/VBox/CharacterButton
@onready var _character_line: Label = $Center/VBox/CharacterLine
@onready var _host_button: Button = $Center/VBox/HostButton
@onready var _join_button: Button = $Center/VBox/JoinButton
@onready var _quit_button: Button = $Center/VBox/QuitButton
@onready var _address_edit: LineEdit = $Center/VBox/AddressEdit
@onready var _status: Label = $Center/VBox/Status
@onready var _backdrop: PosterBackdrop = $Backdrop
@onready var _title: Label = $Center/VBox/Title
@onready var _subtitle: Label = $Center/VBox/Subtitle

static var _launch_handled := false


func _ready() -> void:
	# FlyCamera releases the cursor when it leaves the tree, but the menu is
	# completely unusable if that ever fails, so assert it here too.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Coming back to the menu from a game means the old session must go, or the
	# next Host will fail with "port already in use".
	if Net.is_online():
		Net.leave()

	# THE TITLE BAND (look v2 Stage 6). Paper caps on an ink band, the subtitle
	# in gold under it, and the band positioned from the Title label's real
	# rect rather than from a fraction of the window - the VBox owns where the
	# type is, and a band that misses the type it carries is worse than none.
	_title.add_theme_color_override("font_color", Deco.PAPER)
	_subtitle.add_theme_color_override("font_color", Deco.GOLD)
	_place_title_band()
	get_tree().get_root().size_changed.connect(_place_title_band)
	_title.resized.connect(_place_title_band)

	_character_button.pressed.connect(_on_character_pressed)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	Net.hosting_started.connect(_enter_game)
	Net.join_succeeded.connect(_enter_game)
	Net.host_failed.connect(_on_failed)
	Net.join_failed.connect(_on_failed)

	_show_character()

	# Explains a bounce back from a session that ended without us asking.
	_status.text = Net.last_status
	Net.last_status = ""
	# Deferred: acting on these immediately would call change_scene_to_file()
	# while the SceneTree is still busy attaching this very node, which Godot
	# refuses ("Parent node is busy adding/removing children"). One frame later
	# the tree is settled.
	_apply_launch_args.call_deferred()


## Skip the menu from the command line, so testing two instances does not mean
## clicking through it twice every run. Anything after a bare `--` is passed to
## the game rather than the engine:
##
##     Godot_v4.exe --path . -- --host
##     Godot_v4.exe --path . -- --join 127.0.0.1
##
## `--port N` overrides the default on either side. Added in foliage v1: every
## headless session on this box hosts, and two of them - a screenshot tour and
## a probe run, or the two peers Stage 10's handshake check needs - collide on
## the one port and the second dies with "Couldn\'t create an ENet host". The
## symptom is worth naming because it is not obviously about ports: the second
## instance sits on the main menu, generates nothing, and eventually times out
## having printed no error anybody was watching for.
func _apply_launch_args() -> void:
	# Once per process. `static` survives the menu being freed and rebuilt, so
	# bouncing back here after a session ends does not silently reconnect you.
	if _launch_handled:
		return
	_launch_handled = true

	# The UI comparison harness: photograph this screen, then open the next.
	if UiShot.wanted():
		_shoot_ui()
		return

	# THE HUD HARNESS SKIPS THIS SCREEN ENTIRELY (ui v1 Stage 4). Straight
	# into the game scene rather than through _on_host_pressed(), because
	# game.gd falls back to Net.host_offline() when nothing is online - so
	# the driver hosts with zero clients and BINDS NO PORT. That matters on
	# a box where another lane may already be hosting on the default one:
	# the tour's failure mode is sitting on this menu having printed
	# "Couldn't create an ENet host" into a log nobody was watching.
	if UiShot.hud_wanted():
		_enter_game()
		return

	var args := OS.get_cmdline_user_args()
	# The screenshot tour is a host session that drives itself, so it implies
	# --host rather than needing both spelled out.
	if args.has("--host") or args.has("--tour") or args.has("--traverse"):
		_on_host_pressed()
	elif args.has("--join"):
		var i := args.find("--join")
		if i + 1 < args.size():
			_address_edit.text = args[i + 1]
		_on_join_pressed()


## Who you will be when you press Host or Join.
##
## Shown on the menu rather than only inside the creation screen, because the
## character is chosen once and played for hours - and the moment to notice you
## are still the default human is before you join a friend's world, not after.
func _show_character() -> void:
	var def := CharacterDef.load_or_default()
	# "unnamed" rather than sanitise_name's "peer N". That fallback exists so
	# that a friend without a name still has something to be CALLED on their
	# tag; on your own menu it reads as a bug.
	var display := def.name_text.strip_edges()
	if display.is_empty():
		display = "unnamed"
	_character_line.text = "%s - %s %s" % [
		display, Races.BUILD_NAMES[def.build], Races.name_of(def.race)]


func _on_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character/creation.tscn")


## `--shot-ui <label>`: save this screen to build/ui/<label>/main-menu.png and
## press Character, whose screen shoots itself and quits. See UiShot.
func _shoot_ui() -> void:
	await UiShot.capture(get_tree(), "main-menu")
	_on_character_pressed()


## `--port N`, or the default if it is absent or unusable.
func _launch_port() -> int:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--port")
	if i < 0 or i + 1 >= args.size():
		return Net.DEFAULT_PORT
	var port := args[i + 1].to_int()
	if port <= 0 or port > 65535:
		push_warning("[Menu] --port %s is not a usable port" % args[i + 1])
		return Net.DEFAULT_PORT
	return port


func _on_host_pressed() -> void:
	_set_busy(true, "Starting host...")
	Net.host_game(_launch_port())


func _on_join_pressed() -> void:
	var address := _address_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	_set_busy(true, "Connecting to %s..." % address)
	Net.join_game(address, _launch_port())


func _on_quit_pressed() -> void:
	# Closes the window and ends the process cleanly (runs _exit_tree, etc).
	get_tree().quit()


func _enter_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_failed(reason: String) -> void:
	_set_busy(false, reason)


func _set_busy(busy: bool, message: String) -> void:
	_character_button.disabled = busy
	_host_button.disabled = busy
	_join_button.disabled = busy
	_address_edit.editable = not busy
	_status.text = message


## Put the backdrop's ink band behind the title, once the VBox has laid out.
##
## Deferred because a Control's rect is not final until the container has run,
## and _ready() is before that.
func _place_title_band() -> void:
	_place_band.call_deferred()


func _place_band() -> void:
	if _backdrop == null or _title == null:
		return
	var r := _title.get_global_rect()
	if r.size.y <= 0.0:
		return
	# INTO THE BACKDROP'S OWN SPACE, and until ui v1 Stage 1 this crossed by
	# luck. set_title_band() takes a rectangle it will draw in its own _draw(),
	# which is backdrop-local; what arrives here is global. The two happened to
	# agree because the Backdrop is a full-rect Control sitting at the origin,
	# so its transform was the identity - and a screen with a margin, an offset
	# or a scale on the backdrop would have painted the band somewhere the type
	# is not, with nothing to say why.
	#
	# The affine inverse rather than a position subtraction: it is the same
	# answer when the transform is a translation and the right one when it is
	# not.
	var to_local := _backdrop.get_global_transform().affine_inverse()
	_backdrop.set_title_band(Rect2(
		to_local * r.position, r.size * to_local.get_scale()))
