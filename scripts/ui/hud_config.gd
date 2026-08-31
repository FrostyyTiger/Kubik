class_name HudConfig
extends Resource

## Every number the field register was chosen by eye.
##
## HARD RULE 5 OF ui-v1-tech.md: nothing chosen by eye is hardcoded. Every
## value here is on the F9 panel, and every one is listed in
## docs/status/ui-v1.md with its starting value, so Marcel can move them in
## play and the run's guesses are visible rather than buried in a _draw().
##
## ITS OWN RESOURCE AND ITS OWN PANEL, not WorldgenConfig and not F4. Three
## reasons, and they are Decision 2: F4's rows write worldgen properties, its
## F5 reload is a full world reroll - which is the wrong loop entirely for
## judging whether a bar is the right height - and worldgen_config.gd is the
## concurrently-running distance lane's highest-traffic file. This copies the
## CharacterConfig / character_debug.gd precedent, which exists precisely to
## show how a second tuning surface is added without touching the first.

const SAVE_PATH := "user://ui.tres"

# --- The fade ---------------------------------------------------------------
#
# SAFETY LOOKS LIKE A CLEAN SCREEN (ui-v1.md, decision 4). All four conditions
# must hold at once for the HUD to go: stats full, nothing changed a stat
# recently, the warm register holds, and local danger is low.

## Seconds a stat must go unchanged before the HUD is allowed to leave. Without
## it the bars would blink out between two hits of a fight.
@export var fade_grace_s := 6.0

## Night above this keeps the HUD in. 0 is full day, 1 is full night; the value
## is SkyCycle.night_amount() of the sun's elevation, computed CPU-side.
##
## Firelight is the other half of the warm register and does not exist yet -
## Campfire v1 (E) inherits this line, and until then "warm" means "daylight".
@export var fade_night_max := 0.25

## Danger above this keeps the HUD in. TerrainGenerator.danger_at() normalised
## 0 at spawn to 1 at the region's furthest corner - see the status doc's
## caveat about what that means in an unbounded world.
@export var fade_danger_max := 0.35

## Seconds to ease out when safe, and to ease back in when not. IN IS FASTER
## THAN OUT on purpose: instruments appearing is the game telling you something,
## and a leisurely fade-in would tell you late.
@export var fade_out_s := 1.4
@export var fade_in_s := 0.25

## What the compass strip keeps when everything else has gone (Stage 5).
## Navigation should never fully disappear; the bars should.
@export var strip_floor_alpha := 0.0

# --- Sizes ------------------------------------------------------------------
#
# LOGICAL PIXELS, on the canvas Stage 1 guaranteed is at least 1280x720. They
# are absolute in the Deco idiom - a printed rule is a printed rule whatever it
# frames - and the stretch mode scales them with everything else.

## The bottom-centre furniture cluster: how wide the stack of bars is, how tall
## each bar is, and the gap between them.
@export var bar_width := 220.0
@export var bar_height := 7.0
@export var bar_gap := 5.0

## How far the cluster sits off the bottom edge.
@export var cluster_margin_y := 26.0

## The hotbar's five slots (Stage 5): the side of one chamfered square and the
## gap between two of them.
@export var slot_size := 46.0
@export var slot_gap := 8.0

## The compass strip (Stage 5): its width, its height, and how far it hangs
## below the top edge. The height has to carry a row of chevrons above a row of
## cardinals, so it is taller than the type in it.
@export var strip_width := 460.0
@export var strip_height := 34.0
@export var strip_margin_y := 14.0

## Degrees of heading visible across the whole strip. Smaller is a longer lens:
## the cardinals spread out and small turns read. This is the strip's density
## knob and it is one of the calls left open for Marcel.
@export var strip_span_deg := 150.0

## The party icons (Stage 5): the roundel's radius, and the gap between two.
@export var icon_radius := 15.0
@export var icon_gap := 10.0

## The context dot - the only crosshair, and only when the held slot can act.
@export var dot_radius := 2.5


## The panel's rows: property, label, min, max, step. The same shape
## DebugHUD.TUNING_ROWS and CharacterConfig.TUNING_ROWS use, so hud_tuner.gd
## builds itself from a table the way both other panels do.
const TUNING_ROWS := [
	["fade_grace_s", "fade: grace (s)", 0.0, 30.0, 0.5],
	["fade_night_max", "fade: night max", 0.0, 1.0, 0.05],
	["fade_danger_max", "fade: danger max", 0.0, 1.0, 0.05],
	["fade_out_s", "fade: out (s)", 0.0, 6.0, 0.1],
	["fade_in_s", "fade: in (s)", 0.0, 6.0, 0.05],
	["strip_floor_alpha", "strip: floor alpha", 0.0, 1.0, 0.05],
	["bar_width", "bar: width", 60.0, 500.0, 5.0],
	["bar_height", "bar: height", 2.0, 30.0, 1.0],
	["bar_gap", "bar: gap", 0.0, 20.0, 1.0],
	["cluster_margin_y", "cluster: bottom margin", 0.0, 120.0, 2.0],
	["slot_size", "hotbar: slot size", 20.0, 100.0, 2.0],
	["slot_gap", "hotbar: slot gap", 0.0, 30.0, 1.0],
	["strip_width", "strip: width", 120.0, 1200.0, 10.0],
	["strip_height", "strip: height", 10.0, 60.0, 1.0],
	["strip_margin_y", "strip: top margin", 0.0, 100.0, 2.0],
	["strip_span_deg", "strip: span (deg)", 40.0, 360.0, 5.0],
	["icon_radius", "party: icon radius", 6.0, 40.0, 1.0],
	["icon_gap", "party: icon gap", 0.0, 30.0, 1.0],
	["dot_radius", "context dot radius", 0.0, 10.0, 0.5],
]


## The saved file, or a fresh default. Never fails: a ui.tres from an older
## build that is missing a property loads with that property at its default,
## which is the behaviour WorldgenConfig.load_or_default() has and the reason
## both are Resources rather than a JSON blob.
static func load_or_default() -> HudConfig:
	if ResourceLoader.exists(SAVE_PATH):
		var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is HudConfig:
			return loaded
		push_warning("[HudConfig] %s is not a HudConfig; using defaults" % SAVE_PATH)
	return HudConfig.new()


func save_to_user() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK:
		push_error("[HudConfig] could not save %s: %s" % [
			SAVE_PATH, error_string(err)])
	else:
		print("[HudConfig] saved %s" % SAVE_PATH)
