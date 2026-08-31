class_name Hud
extends CanvasLayer

## THE FIELD REGISTER. One furniture cluster at the bottom centre, one thin
## strip at the top, four empty corners - and when you are safe, nothing at all.
##
## The other register is the poster: the menu, the creation screen, the
## character sheet. Those are printed things you visit, and they use the whole
## Deco kit. This is an instrument panel, and you only see instruments when you
## need them. See docs/plans/ui-v1.md, "The thesis".
##
## THE FADE IS THE LOAD-BEARING IDEA. Cozy does not look like a warm-coloured
## HUD; it looks like a clean screen with a huge world behind it. Danger looks
## like instruments appearing. That is the same TENSE OUT, COZY IN THE LIGHT
## register the world is built on, applied to the screen furniture.
##
## ON THE EXISTING $HUD CANVASLAYER (layer 0), which is not an accident: every
## probe and tour path in game.gd already does `$HUD.visible = false`, so the
## play HUD is excluded from a terrain photograph for free and no probe had to
## learn about it.
##
## LAYOUT LIVES HERE AND NOWHERE ELSE. The pieces - bars, hotbar, strip, icons -
## draw themselves and are told where they are; anchors and margins are this
## file's, and no piece knows a screen coordinate. That is what makes the
## cluster movable from one F9 row rather than from five.

## Every number in this file that was chosen by eye. Hard rule 5.
var config: HudConfig = null

var _sky: SkyCycle = null
var _world: Node = null
var _player: Node3D = null
var _game: Node = null

## The bottom-centre cluster and its three bars.
var _cluster: Control = null
var _bars := {}          # stat name -> _Bar
var _hotbar: Hotbar = null
var _icons: PartyIcons = null
var _compass: Compass = null
var _dot: _ContextDot = null

## 0 when safe and 1 when not, eased. What the whole field register is
## modulated by; the compass strip re-adds its own floor on top (Stage 5).
var _shown := 1.0

## Seconds since anything changed one of our stats. The grace half of "safe".
var _since_change := 999.0
var _last_row := {}

## The four conditions, kept as fields rather than locals so the F3 readout can
## print WHICH one is holding the HUD in. A fade nobody can explain is a fade
## that gets called broken.
var _stats_full := true
var _night := 0.0
var _danger := 0.0


func _ready() -> void:
	config = HudConfig.load_or_default()
	_build()
	set_process(true)


## Called by Game once the scene is up. Everything is optional: this layer must
## draw SOMETHING even in a scene assembled by a probe that has no sky.
func setup(sky: SkyCycle, world: Node, player: Node3D, game: Node) -> void:
	_sky = sky
	_world = world
	_player = player
	_game = game


# --- Layout -------------------------------------------------------------------

func _build() -> void:
	_cluster = Control.new()
	_cluster.name = "Cluster"
	_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# BOTTOM CENTRE, as anchors and margins rather than a position. The canvas
	# is at least 1280x720 but may be larger in either dimension (Stage 1), so
	# anything placed by arithmetic off 1280x720 would drift. See _layout.
	add_child(_cluster)

	for stat in StatsTable.ORDER:
		var bar := _Bar.new()
		bar.tint = BAR_COLORS[stat]
		_cluster.add_child(bar)
		_bars[stat] = bar

	# The hotbar sits under the bars, inside the same cluster - one piece of
	# furniture, moved by one margin.
	_hotbar = Hotbar.new()
	_hotbar.config = config
	_hotbar.slot_used.connect(_on_slot_used)
	_cluster.add_child(_hotbar)

	# The party, at the cluster's LEFT EDGE (ui-v1.md, "Defaults set on
	# delegated trust"). Outside the cluster's own box rather than in it, so
	# the bars stay centred on the screen whether there is a party or not.
	_icons = PartyIcons.new()
	_icons.config = config
	add_child(_icons)

	# The strip, top centre. Its own mount, because the top of the screen and
	# the bottom of it are the two halves of the poster's mat and nothing
	# should ever tie them together.
	_compass = Compass.new()
	_compass.config = config
	add_child(_compass)

	# The only crosshair there is, and it is not permanent.
	_dot = _ContextDot.new()
	_dot.config = config
	add_child(_dot)
	_layout()


## THE THREE BAR COLOURS, AND THEY ARE A GUESS.
##
## Deco constants, so hard rule 4 holds - no colour outside the palette - but
## WHICH constant goes on WHICH stat is a taste call, not a technical one. Sun
## for health because sun is the palette's warning; the two alpine values for
## stamina and mana because they are tints of one colour and the two of them
## should read as a pair against the health bar rather than as three unrelated
## stripes. Listed in the status doc under "For Marcel to rule on".
## The gap between the bar stack and the row of slots. Not on F9: it is a
## relationship inside one piece of furniture rather than a size, and the two
## things it separates are both tunable.
const BAR_TO_HOTBAR_GAP := 8.0

const BAR_COLORS := {
	"hp": Deco.SUN,
	"sp": Deco.ALPINE_PALE,
	"mp": Deco.ALPINE_DEEP,
}


## Put every piece where the config says. Called on build, on a resize, and
## whenever the F9 panel moves a number - which is what makes the panel a
## tuning loop rather than a list of values that need a restart.
func _layout() -> void:
	if _cluster == null or config == null:
		return
	var stack_h := float(StatsTable.ORDER.size()) * config.bar_height \
		+ float(StatsTable.ORDER.size() - 1) * config.bar_gap
	# THE CLUSTER IS THE BARS AND THE HOTBAR, and its height has to say so.
	# With only the bar stack in it the five slots were laid out below the
	# cluster's bottom edge, which is below the screen's - the first party shot
	# has them sliced off by the frame. One piece of furniture, one box.
	var cluster_h := stack_h + BAR_TO_HOTBAR_GAP + config.slot_size
	# ANCHORS AND OFFSETS, NEVER `position` AND `size`. A Control under a
	# CanvasLayer does get the viewport as its parent rect, so the anchors
	# below resolve - but `position` is measured from that rect's ORIGIN, not
	# from the anchor, so setting it to (-w/2, -h-margin) puts the cluster off
	# the top left corner of the screen. It did, and the symptom was a HUD that
	# was present, visible, at full opacity and nowhere in the picture; the
	# fade numbers all read correctly the whole time. Offsets are measured from
	# the anchor, which is what was wanted.
	_cluster.anchor_left = 0.5
	_cluster.anchor_right = 0.5
	_cluster.anchor_top = 1.0
	_cluster.anchor_bottom = 1.0
	_cluster.offset_left = -config.bar_width * 0.5
	_cluster.offset_right = config.bar_width * 0.5
	_cluster.offset_top = -cluster_h - config.cluster_margin_y
	_cluster.offset_bottom = -config.cluster_margin_y
	var y := 0.0
	for stat in StatsTable.ORDER:
		var bar: _Bar = _bars[stat]
		bar.position = Vector2(0.0, y)
		bar.size = Vector2(config.bar_width, config.bar_height)
		bar.queue_redraw()
		y += config.bar_height + config.bar_gap

	# The hotbar, centred under the bars. Inside the cluster, so its position
	# is measured from the cluster's own origin and the two move together.
	if _hotbar != null:
		var hw := _hotbar.natural_width()
		_hotbar.position = Vector2((config.bar_width - hw) * 0.5,
			y - config.bar_gap + BAR_TO_HOTBAR_GAP)
		_hotbar.size = Vector2(hw, config.slot_size)
		_hotbar.queue_redraw()

	# The icons, hard against the cluster's left edge, sitting on the bars'
	# baseline. Anchored bottom-centre like the cluster and offset out to the
	# left of it, so a wider cluster pushes them further out rather than
	# overlapping them.
	if _icons != null:
		var iw := _icons.natural_width()
		# Tall enough for the roundel AND the name under it. The first cut sized
		# this to the roundel alone and the name landed on the health bar.
		var ih := config.icon_radius * 2.0 + config.icon_radius * 1.4
		# CLEAR OF THE BARS BY A WHOLE SLOT. The cluster is the widest of the
		# bar stack and the hotbar, so the icons have to clear whichever that
		# is - measuring against bar_width alone put them on top of the hotbar
		# the moment the slots were wider than the bars.
		var cluster_w := maxf(config.bar_width,
			_hotbar.natural_width() if _hotbar != null else 0.0)
		var right := -cluster_w * 0.5 - config.icon_gap * 2.0
		_icons.anchor_left = 0.5
		_icons.anchor_right = 0.5
		_icons.anchor_top = 1.0
		_icons.anchor_bottom = 1.0
		_icons.offset_left = right - iw
		_icons.offset_right = right
		# Sitting on the bars' baseline, not the hotbar's - the icons belong
		# with the stat register, and the row of slots is a different thing.
		_icons.offset_top = -ih - BAR_TO_HOTBAR_GAP - config.slot_size \
			- config.cluster_margin_y
		_icons.offset_bottom = -BAR_TO_HOTBAR_GAP - config.slot_size \
			- config.cluster_margin_y
		_icons.queue_redraw()

	# The strip, top centre.
	if _compass != null:
		_compass.anchor_left = 0.5
		_compass.anchor_right = 0.5
		_compass.anchor_top = 0.0
		_compass.anchor_bottom = 0.0
		_compass.offset_left = -config.strip_width * 0.5
		_compass.offset_right = config.strip_width * 0.5
		_compass.offset_top = config.strip_margin_y
		_compass.offset_bottom = config.strip_margin_y + config.strip_height
		_compass.queue_redraw()

	# The dot, dead centre, always - it is the aim point and nothing else.
	if _dot != null:
		var d := config.dot_radius * 2.0 + 2.0
		_dot.anchor_left = 0.5
		_dot.anchor_right = 0.5
		_dot.anchor_top = 0.5
		_dot.anchor_bottom = 0.5
		_dot.offset_left = -d * 0.5
		_dot.offset_right = d * 0.5
		_dot.offset_top = -d * 0.5
		_dot.offset_bottom = d * 0.5
		_dot.queue_redraw()


## The F9 panel moved something.
func apply_config() -> void:
	_layout()


# --- The fade -----------------------------------------------------------------

func _process(delta: float) -> void:
	_read_stats(delta)
	_read_world()
	_read_party()
	var safe := _is_safe()
	# IN IS FASTER THAN OUT. Instruments appearing is the game telling you
	# something; a leisurely fade-in tells you late.
	var span: float = config.fade_out_s if safe else config.fade_in_s
	var target := 0.0 if safe else 1.0
	if span <= 0.0:
		_shown = target
	else:
		_shown = move_toward(_shown, target, delta / span)
	_apply_opacity()


## Our own stats, and how long since one of them moved.
##
## Read off Game rather than off a table of our own: the host reads its table,
## a client reads the last row the host sent, and this file does not need to
## know which of the two it is on. DISPLAY ONLY - hard rule 8, and there is
## nothing here that could write one back even by accident.
func _read_stats(delta: float) -> void:
	_since_change += delta
	if _game == null or not _game.has_method("peer_stats"):
		return
	var row: Dictionary = _game.peer_stats(Net.local_peer_id())
	if row.is_empty():
		return
	for stat in StatsTable.ORDER:
		var was: float = _last_row.get(stat, float(row.get(stat, 0.0)))
		if not is_equal_approx(was, float(row.get(stat, 0.0))):
			_since_change = 0.0
	_last_row = row
	_stats_full = true
	for stat in StatsTable.ORDER:
		var f := StatsTable.fraction_of(row, stat)
		(_bars[stat] as _Bar).set_fraction(f)
		if f < 1.0:
			_stats_full = false


## Night and danger, both computed on this machine from things every machine
## agrees on.
##
## NIGHT IS THE CPU-SIDE VALUE, not the `kubik_night` shader global - a shader
## global is write-only from GDScript's side of the fence. SkyCycle's statics
## are pure functions of the time of day and exist to be asked this way, and
## the tour already leans on the same pair.
##
## TIME OF DAY IS PER-CLIENT AND UNSYNCED. Two players can therefore disagree
## about whether it is night, and so about whether their own HUDs are showing.
## That is fine and deliberate: the fade is a LOOK input, not world truth, and
## nothing about the game's state depends on it.
func _read_world() -> void:
	if _sky != null:
		_night = SkyCycle.night_amount(SkyCycle.sun_position(_sky.time_of_day).y)
	if _player != null and _world != null and _world.get("generator") != null:
		var p := _player.global_position
		_danger = _danger_at_m(p.x, p.z)


## The compass heading, and everybody else - both from things already on this
## machine. NO NEW NETWORK TRAFFIC, which is the point: bearings come out of the
## `_states` positions the sync has always carried, and a friend's health out of
## the three floats Stage 3 put on the same packet.
func _read_party() -> void:
	if _player != null and _player.has_method("camera_yaw"):
		_compass.heading_deg = Compass.heading_from_yaw(_player.camera_yaw())
	var marks := []
	var members := []
	if _game != null and _game.has_method("other_peer_rows") and _player != null:
		var here := _player.global_position
		for entry in _game.other_peer_rows():
			var peer_id: int = entry["peer"]
			var row: Dictionary = entry["row"]
			# THE HUE, AND IT IS THE NAMETAG'S OLD ONE. color_for_peer stays
			# where it is, static, per its own doc comment - the colour is
			# derived from the id on both machines and has never been sent.
			var tint := RemotePlayer.color_for_peer(peer_id)
			if row.has("p"):
				marks.append({
					"bearing": Compass.bearing_to(here, row["p"]),
					"color": tint})
			members.append({
				"name": String(row.get("n", "peer %d" % peer_id)),
				"color": tint,
				"health": StatsTable.fraction_of(row, "hp"),
			})
	_compass.marks = marks
	_compass.queue_redraw()
	# The row's WIDTH depends on who is in it, and who is in it is not known
	# when the HUD builds itself - so a change re-lays out rather than only
	# re-drawing. See PartyIcons.set_members.
	if _icons.set_members(members):
		_layout()
	if _dot != null:
		_dot.lit = _hotbar != null and _hotbar.active_acts()


## danger_at() takes BLOCKS and everything on this side of the fence has
## metres, exactly as zone_name_at_m() does - mirrored here in a private helper
## rather than by adding a metres overload to a file this lane may not write.
func _danger_at_m(x_m: float, z_m: float) -> float:
	var generator = _world.generator
	if generator == null or _world.config == null:
		return 0.0
	var bs: float = _world.config.block_size
	if bs <= 0.0:
		return 0.0
	return generator.danger_at(floor(x_m / bs), floor(z_m / bs))


## SAFE IS ALL FOUR AT ONCE, and any one of them failing brings the HUD back.
func _is_safe() -> bool:
	if config == null:
		return false
	return _stats_full \
		and _since_change >= config.fade_grace_s \
		and _night <= config.fade_night_max \
		and _danger <= config.fade_danger_max


func _apply_opacity() -> void:
	if _cluster != null:
		_cluster.modulate.a = _shown
	if _icons != null:
		_icons.modulate.a = _shown
	if _dot != null:
		_dot.modulate.a = _shown
	# THE STRIP KEEPS A FLOOR. Navigation should never fully disappear - you
	# can be perfectly safe and still want to know which way is north - so the
	# strip fades toward strip_floor_alpha rather than toward zero while
	# everything else goes. At the shipped 0.0 it behaves like the rest; the
	# row exists because the design doc reserved the right and Marcel judges it
	# in play.
	if _compass != null:
		_compass.modulate.a = maxf(_shown, config.strip_floor_alpha)


## Advance the fade by `seconds` of simulated time, in the real code path.
##
## FOR THE SHOT DRIVER, and it is deliberately not a bypass. A photograph of a
## HUD caught halfway through a 1.4 s ease is a photograph of nothing anybody
## can check, and waiting out the grace period in real frames would put a
## minute of wall clock into every shot. This runs the SAME _process the game
## runs, in fixed steps, so what is photographed is a state the game can
## actually reach - and if the fade logic is wrong, this reaches the wrong
## state too, which is the property a bypass would lose.
func settle(seconds: float, step := 0.05) -> void:
	var steps := int(ceil(seconds / step))
	for i in steps:
		_process(step)


## Where the pieces actually are, for the shot driver and the F3 readout. A
## layout that is off screen and a layout that is invisible look identical in
## a photograph, and this is what tells them apart.
func layout_line() -> String:
	if _cluster == null:
		return "cluster: none"
	return "cluster rect %s vis %s a %.2f, layer %d, bars %d, first bar rect %s" % [
		_cluster.get_global_rect(), _cluster.visible, _cluster.modulate.a,
		layer, _bars.size(),
		(_bars["hp"] as Control).get_global_rect() if _bars.has("hp") else "none"]


## Who the HUD thinks is here, and where. For the shot driver: "the chevron is
## in the east half" is a claim about a number as well as about a picture, and
## the number belongs in the transcript beside the picture.
func party_line() -> String:
	var out := "heading %.1f deg, %d icons, %d chevrons" % [
		_compass.heading_deg, _icons.members.size(), _compass.marks.size()]
	for mark in _compass.marks:
		out += " | bearing %.1f deg" % float(mark["bearing"])
	for member in _icons.members:
		out += " | %s hp %.2f hue %s" % [
			member["name"], member["health"],
			(member["color"] as Color).to_html(false)]
	return out


## Put a slot in the hand from outside. The shot driver's `use` step, which
## presses 1 and clicks in one call.
func select_slot(index: int) -> void:
	if _hotbar != null:
		_hotbar.select(index)


## What the fade is thinking, for the F3 readout. Named conditions rather than
## one number, because "the HUD will not go away" is a question with four
## possible answers and a single opacity cannot tell you which.
func fade_line() -> String:
	return "hud %.2f shown | full %s, since %.1f/%.1f s, night %.2f/%.2f, danger %.2f/%.2f" % [
		_shown, _stats_full, minf(_since_change, 99.9), config.fade_grace_s,
		_night, config.fade_night_max, _danger, config.fade_danger_max]


# --- Input --------------------------------------------------------------------

## The hotbar's keys and wheel, consumed here so nothing downstream sees them.
##
## _unhandled_input rather than _input: F3, F4, F8 and the character sheet all
## get first refusal, and a hotbar that ate a key a panel wanted would be a bug
## that only shows up with a panel open.
func _unhandled_input(event: InputEvent) -> void:
	if _hotbar == null:
		return
	if _hotbar.handle_input(event, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		get_viewport().set_input_as_handled()


## THE HELD THING ACTS. Slot 1 is the slab tool, and its use goes through
## Game -> World.request_set_block, which is THE one mutation path - the host
## validates, applies, broadcasts and journals, exactly as it does for a
## client's edit. That is the whole reason a stand-in item exists before Items
## v1: select-and-use is proven end to end, through the real chain, tonight.
func _on_slot_used(index: int) -> void:
	if index != 0 or _game == null:
		return
	if _game.has_method("use_slab_tool"):
		_game.use_slab_tool()


# --- The bar ------------------------------------------------------------------

## One stat, drawn.
##
## A DRAWN CONTROL AND NOT A TEXTURE (hard rule 4): a hairline ink frame, a
## track of paper at low alpha, and a fill in the stat's Deco colour. That is
## the _Ornament idiom from deco.gd - the poster's marks are drawn, so the
## field register's are too, and the game still ships with no UI image assets
## at all.
##
## NO NUMBER ON IT. A bar is a shape you read at a glance while something is
## trying to kill you; a number is a thing you stop and parse. When there is a
## reason to know the exact figure it belongs on the F3 readout, which is where
## it is.
class _Bar extends Control:
	var tint := Deco.SUN
	var fraction := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_fraction(value: float) -> void:
		var clamped := clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, fraction):
			return
		fraction = clamped
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		# The track: paper, but barely - the world has to read through it, and
		# an opaque strip across the bottom of the screen is exactly the
		# screen furniture this design refuses.
		draw_rect(Rect2(Vector2.ZERO, size), Color(Deco.PAPER, 0.16))
		if fraction > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fraction, size.y)), tint)
		# The hairline. One pixel of ink, drawn as an unfilled rect, so the bar
		# has an edge against a bright sky as well as against a dark hillside.
		draw_rect(Rect2(Vector2.ZERO, size), Deco.INK, false, 1.0)


## THE ONLY CROSSHAIR IN THE GAME, and it is not permanent.
##
## An empty hand means an unmarked screen (ui-v1.md, "Defaults set on delegated
## trust"). The dot appears only while the held slot can act - slot 1 yes,
## the four empty ones no - so the mark on the screen means something rather
## than being furniture that happens to be in the middle.
class _ContextDot extends Control:
	var config: HudConfig = null
	var lit := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if visible != lit:
			visible = lit

	func _ready() -> void:
		set_process(true)

	func _draw() -> void:
		if config == null or config.dot_radius <= 0.0:
			return
		var c := size * 0.5
		# Ink with a paper ring, so it reads on a dark hillside and on a bright
		# sky alike - the same problem the bars' hairline solves.
		draw_circle(c, config.dot_radius + 1.0, Color(Deco.PAPER, 0.7))
		draw_circle(c, config.dot_radius, Deco.INK)
