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
	_layout()


## THE THREE BAR COLOURS, AND THEY ARE A GUESS.
##
## Deco constants, so hard rule 4 holds - no colour outside the palette - but
## WHICH constant goes on WHICH stat is a taste call, not a technical one. Sun
## for health because sun is the palette's warning; the two alpine values for
## stamina and mana because they are tints of one colour and the two of them
## should read as a pair against the health bar rather than as three unrelated
## stripes. Listed in the status doc under "For Marcel to rule on".
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
	_cluster.offset_top = -stack_h - config.cluster_margin_y
	_cluster.offset_bottom = -config.cluster_margin_y
	var y := 0.0
	for stat in StatsTable.ORDER:
		var bar: _Bar = _bars[stat]
		bar.position = Vector2(0.0, y)
		bar.size = Vector2(config.bar_width, config.bar_height)
		bar.queue_redraw()
		y += config.bar_height + config.bar_gap


## The F9 panel moved something.
func apply_config() -> void:
	_layout()


# --- The fade -----------------------------------------------------------------

func _process(delta: float) -> void:
	_read_stats(delta)
	_read_world()
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


## What the fade is thinking, for the F3 readout. Named conditions rather than
## one number, because "the HUD will not go away" is a question with four
## possible answers and a single opacity cannot tell you which.
func fade_line() -> String:
	return "hud %.2f shown | full %s, since %.1f/%.1f s, night %.2f/%.2f, danger %.2f/%.2f" % [
		_shown, _stats_full, minf(_since_change, 99.9), config.fade_grace_s,
		_night, config.fade_night_max, _danger, config.fade_danger_max]


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
