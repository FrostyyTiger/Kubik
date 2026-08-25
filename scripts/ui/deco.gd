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
