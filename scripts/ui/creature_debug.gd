class_name CreatureDebug
extends CanvasLayer

## The F10 panel: every creature number, tunable without leaving the world.
##
## THE OTHER HALF OF THE SAME DEAL `character_debug.gd` describes. This box has
## no display; every speed, every sense range and every flank angle in this run
## was chosen by reading a plan, not by watching an animal. So hard rule 5 of
## `docs/plans/creatures-v1-tech.md` says every one of them is reachable from
## here and listed in `docs/status/creatures-v1.md` with its starting value.
##
## SEPARATE FROM DebugHUD's TUNING_ROWS, deliberately: the distance lane is
## appending there tonight, and `character_debug.gd`'s row pattern is the one
## this copies - including copying `_spin_row` rather than importing it, for
## the reason that file's docstring gives.
##
## F4 is worldgen, F8 is characters, F10 is this. Stage 2 builds the node so
## game.gd's banner block can be landed complete and never grown again; the
## rows arrive in Stage 8, once Stage 6 has chosen the numbers by feel.

const TOGGLE_KEY := KEY_F10


func _ready() -> void:
	# Above DebugHUD's 10 and CharacterDebug's 11, so three panels do not fight.
	layer = 13
