class_name PartyIcons
extends Control

## BETTER TOGETHER GETS UI, BUT QUIET UI.
##
## One small roundel per party member, tucked at the left edge of the furniture
## cluster, each in its peer's golden-ratio hue - the hue that used to be the
## floating nametag's and now lives here (ui-v1.md, decision 5).
##
## A MEMBER'S HEALTH APPEARS ONLY WHEN THEY ARE IN TROUBLE. A healthy partner
## is a presence, not a gauge: the roundel says "they are here", and the arc
## around it says "they are hurt", and those are two different pieces of news
## that should not look the same. A permanent health bar per friend would be a
## party frame, which is the MMO posture this design explicitly is not.
##
## ZERO ICONS SOLO, and not as a special case - the list is what the state
## table says, and solo is a host with no other rows in it.
##
## CAP 4 (CLAUDE.md, pillar 1). Three others is the most this ever lays out,
## and the layout is a row, so the cap is honoured by there being nothing to
## honour: four bodies is four roundels wide and that is a shape that fits.

## DOWNED IS NOT BUILT. There is no death system - see stats.gd - so there is
## no downed state for an icon to show. Combat v1 (D) inherits this: the hook
## is the same arc, drawn in a different colour, and the row it reads already
## travels on the wire.

var config: HudConfig = null

## Array of {name: String, color: Color, health: float}. Set by the HUD each
## frame from the synced table; health is a fraction, 1.0 meaning unhurt.
var members: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Returns true when the party actually changed, so the HUD knows to lay the
## row out again.
##
## IT HAS TO. The icons' box is sized from natural_width(), which is a function
## of who is in the party and how long their names are - and the party is not
## known when the HUD builds itself. Laid out once at build time the box was
## zero wide, and since a Control does not clip its own drawing by default, the
## icons spilled out of it and across the health bar. A stale layout looked
## exactly like a layout bug.
func set_members(rows: Array) -> bool:
	if rows.size() == members.size():
		var same := true
		for i in rows.size():
			if rows[i].get("name") != members[i].get("name") \
					or not is_equal_approx(float(rows[i].get("health", 1.0)),
						float(members[i].get("health", 1.0))):
				same = false
				break
		members = rows
		if same:
			return false
		queue_redraw()
		# A name change resizes the row; a health change does not, but redoing
		# a layout of at most four icons is not worth telling apart.
		return true
	members = rows
	queue_redraw()
	return true


## THE STEP IS THE WIDER OF THE ROUNDEL AND THE NAME UNDER IT.
##
## Sized to the roundel alone, two four-letter names ran into each other -
## "KIRA" and "TORV" overlapped in the first two-peer shot, because a 30 px
## disc plus a 10 px gap is narrower than the word beneath it. A name is part
## of the icon's footprint whether or not it is part of its circle.
func _step() -> float:
	var d := config.icon_radius * 2.0
	var font := Deco.font_of(&"SectionLabel")
	var px := int(config.icon_radius * 0.75)
	var widest := d
	for member in members:
		var who := String(member.get("name", ""))
		if who.is_empty():
			continue
		widest = maxf(widest, font.get_string_size(
			who, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x)
	return widest + config.icon_gap


func natural_width() -> float:
	if config == null or members.is_empty():
		return 0.0
	return float(members.size()) * _step() - config.icon_gap


func _draw() -> void:
	if config == null or members.is_empty():
		return
	var r := config.icon_radius
	var step := _step()
	var font := Deco.font_of(&"SectionLabel")
	var px := int(r * 0.75)
	for i in members.size():
		var member: Dictionary = members[i]
		# Centred in its own cell rather than packed from the left, so a long
		# name and a short one both sit under their own roundel.
		var centre := Vector2((step - config.icon_gap) * 0.5 + float(i) * step, r)
		var tint: Color = member.get("color", Deco.GOLD)
		# The roundel, in the Deco idiom: a paper disc inside a ring. The ring
		# is the PEER's colour rather than gold, because gold is reserved for
		# the selected hotbar slot and nothing else (hard rule 4).
		draw_circle(centre, r, tint)
		draw_circle(centre, r - 2.0, Color(Deco.PAPER, 0.9))
		draw_arc(centre, r, 0.0, TAU, 32, Deco.INK, 1.0)

		# THE INITIAL, not the name. A roundel is the size of one letter and
		# the full name goes underneath.
		var who := String(member.get("name", ""))
		var initial := who.substr(0, 1).to_upper() if not who.is_empty() else "?"
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, centre + Vector2(-w * 0.5, float(px) * 0.36), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Deco.INK)

		# THE HURT ARC, and only when hurt. Sun is the palette's warning and it
		# is the health bar's colour, so a hurt friend and your own hurt bar
		# say the same thing in the same ink.
		var health := float(member.get("health", 1.0))
		if health < 1.0:
			# Clockwise from the top, as much of the ring as is left.
			draw_arc(centre, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * health,
				48, Deco.SUN, 2.5)

		if not who.is_empty():
			var nw := font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, px).x
			draw_string(font, Vector2(centre.x - nw * 0.5, r * 2.0 + float(px)),
				who, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Deco.INK)
