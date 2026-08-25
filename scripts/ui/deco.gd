class_name Deco

## The poster's UI vocabulary, in one place.
##
## The palette here is the UI half of the palette in docs/plans/look-v1.md.
## Five colours, sRGB, and nothing a screen draws is allowed to be a sixth:
## paper is the ground, ink is the type, gold is the rule line and the one
## accent, alpine blue is a heading, sun is a warning. The world's palette
## (Block.COLORS) is stored linear because it goes into vertices; these go into
## Controls, which take sRGB, so they are stored as authored.
##
## The theme itself is assets/ui/deco_theme.tres and applies to every Control
## through project.godot. What lives here is what a theme cannot express: the
## palette as constants for code that draws, the double rule (DecoRule), and
## the poster backdrop (PosterBackdrop).

const PAPER := Color("#F2E8D0")
const PAPER_SHADE := Color("#E3D6B4")
const INK := Color("#1E2430")
const GOLD := Color("#C9A24A")
const ALPINE := Color("#2F5D8A")
const SUN := Color("#E8863A")

## A deeper and a paler alpine for the mountain bands. Tints of one colour,
## not new colours: a poster's mountains are the same blue at three values.
const ALPINE_DEEP := Color("#24476A")
const ALPINE_PALE := Color("#5C86AE")

## Secondary type: a caption, a status line, the thing under the thing. Look v2
## Stage 6. Not a sixth colour - it is ink with the contrast taken out of it, so
## a screen still reads as five colours and the eye still knows what to read
## first.
const INK_PALE := Color("#7D7C78")


## The double rule, for building in code. Sits in a VBoxContainer like a
## separator and takes the width it is given.
static func rule() -> Control:
	var control := DecoRule.new()
	control.custom_minimum_size = Vector2(0.0, 9.0)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


## A label typed as one of the theme's named variations. The variations are
## TitleLabel, SectionLabel, AccentLabel and StatusLabel - see the theme.
static func label(text: String, variation: StringName, upper := false) -> Label:
	var out := Label.new()
	out.text = text
	out.theme_type_variation = variation
	out.uppercase = upper
	return out


## The theme's font for a variation, for the one place that is not a Control:
## the nametag over a remote player's head is a Label3D.
static func font_of(variation: StringName) -> Font:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_font("font", variation):
		return theme.get_font("font", variation)
	return ThemeDB.fallback_font


# --- Ornaments ----------------------------------------------------------------
#
# Look v2 Stage 6. Four marks, each one Control, each drawn rather than
# textured. They exist so a screen can be broken into sections without adding a
# sixth colour or a second typeface: a poster separates blocks of type with a
# rule and a mark, and these are the marks.


## Three gold dots in a row. The quietest separator there is.
static func dots(count := 3, radius := 3.0, gap := 12.0) -> Control:
	var c := _Ornament.new()
	c.kind = _Ornament.DOTS
	c.count = count
	c.radius = radius
	c.gap = gap
	c.custom_minimum_size = Vector2(float(count) * gap, radius * 4.0)
	return c


## Three chevrons across, amplitude 7, apex about 95 degrees, 3 px thick.
static func chevron(count := 3) -> Control:
	var c := _Ornament.new()
	c.kind = _Ornament.CHEVRON
	c.count = count
	c.custom_minimum_size = Vector2(float(count) * 22.0, 18.0)
	return c


## A paper disc inside a double gold ring, with the Limelight monogram in it.
## The one ornament allowed to carry a letter.
static func roundel(letter := "K", radius := 22.0) -> Control:
	var c := _Ornament.new()
	c.kind = _Ornament.ROUNDEL
	c.letter = letter
	c.radius = radius
	c.custom_minimum_size = Vector2(radius * 2.0 + 4.0, radius * 2.0 + 4.0)
	return c


## A stepped corner frame - ink, gold, paper, each inset from the last. The
## panel a block of type sits in.
static func frame() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", DecoPanel.stepped())
	return p


## The one Control behind dots(), chevron() and roundel(). A class per mark
## would be three files that share a _draw and differ by nine lines.
class _Ornament extends Control:
	enum {DOTS, CHEVRON, ROUNDEL}

	var kind := DOTS
	var count := 3
	var radius := 3.0
	var gap := 12.0
	var letter := "K"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		match kind:
			DOTS:
				var span := float(count - 1) * gap
				var y := size.y * 0.5
				for i in count:
					draw_circle(Vector2(size.x * 0.5 - span * 0.5 + float(i) * gap, y),
						radius, Deco.GOLD)
			CHEVRON:
				# Apex about 95 degrees: half-width 7.5 against amplitude 7.
				var amp := 7.0
				var half := 7.5
				var cy := size.y * 0.5
				var step := half * 2.0 + 7.0
				var span := float(count - 1) * step
				for i in count:
					var cx := size.x * 0.5 - span * 0.5 + float(i) * step
					draw_line(Vector2(cx - half, cy + amp * 0.5),
						Vector2(cx, cy - amp * 0.5), Deco.GOLD, 3.0)
					draw_line(Vector2(cx, cy - amp * 0.5),
						Vector2(cx + half, cy + amp * 0.5), Deco.GOLD, 3.0)
			ROUNDEL:
				var c := size * 0.5
				draw_circle(c, radius, Deco.GOLD)
				draw_circle(c, radius - 2.0, Deco.PAPER)
				draw_circle(c, radius - 5.0, Deco.GOLD)
				draw_circle(c, radius - 7.0, Deco.PAPER)
				var font := Deco.font_of(&"TitleLabel")
				var px := int(radius * 1.1)
				var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT,
					-1.0, px).x
				draw_string(font, c + Vector2(-w * 0.5, px * 0.36), letter,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Deco.INK)
