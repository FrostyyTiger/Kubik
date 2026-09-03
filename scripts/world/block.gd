class_name Block

## Block type table. One byte per voxel, so we have room for 256 types.
##
## The values are part of our network protocol (block edits are sent as ids),
## so NEVER renumber an existing entry - only append new ones at the end.

enum {
	AIR = 0,
	STONE = 1,
	DIRT = 2,
	GRASS = 3,
	SAND = 4,
	SNOW = 5,
	FOREST_FLOOR = 6,
	LEAVES = 7,
	TRUNK = 8,
	SHORE = 9,
	ALPINE_GRASS = 10,
	HEATH = 11,

	# --- Foliage v1 Stage 3: seven species instead of one ------------------
	#
	# APPENDED, NEVER RENUMBERED, like everything above them - these ids are
	# the wire format for block edits.
	#
	# TWO IDS PER SPECIES, A AND B. A grove drawn in one exact green reads as
	# one object rather than as many trees, and the fix that does NOT work is
	# per-block colour variation: it is incompatible with greedy meshing, and
	# a flat canopy would go from one quad to hundreds. Per-TREE variation
	# costs nothing at all - each tree hashes A or B for its whole crown, the
	# mesher merges within a tree exactly as before, and neighbouring trees
	# stop being the same colour. The two shades are a few percent apart in
	# value and hue; more reads as two species rather than as light.
	#
	# LEAVES stays spruce A and TRUNK stays every brown trunk, so no existing
	# world changes colour.
	LEAVES_SPRUCE_B = 12,
	LEAVES_BEECH = 13,
	LEAVES_BEECH_B = 14,
	LEAVES_LARCH = 15,
	LEAVES_LARCH_B = 16,
	LEAVES_PINE = 17,
	LEAVES_PINE_B = 18,
	LEAVES_BIRCH = 19,
	LEAVES_BIRCH_B = 20,
	TRUNK_BIRCH = 21,
	TRUNK_DEAD = 22,

	# --- Trees v1 Stage 4: the second colour -------------------------------
	#
	# ONE id, not one per species. art-direction.md 2.5 asks for "two colours
	# per tree, and the second lives on the whorl underside - detached
	# blue-violet slivers where a shelf shades the one below". The underside is
	# a SHADOW, and look v2's shade ink is one colour for the whole world; an
	# authored shadow that changed hue by species would be arguing with it. So
	# the spruce, the larch and the conifer hero all take the same violet, and
	# the species keeps its own two greens (or golds) for everything the sun
	# can reach.
	#
	# It is a THIRD id and not a third shade: the A/B per-tree roll still picks
	# the crown's colour, and this rides on top of whichever it picked.
	LEAVES_SLIVER = 23,
}

## The palette. These ARE the look of the game - there are no textures, so a
## block is exactly its colour and nothing else.
##
## Warm and slightly saturated on purpose. A physically plausible grey-green
## reads as washed out at distance, and distance is what this world is for: the
## design is sold on telling a meadow from a forest from a snowfield across a
## valley, which is a question about colour separation, not realism.
##
## SEVEN ZONES, NOT FOUR, since terrain v2 Stage 7. The three added surfaces
## exist to break up the green: the world was 57% meadow by area and read as
## one colour with a treeline drawn on it. Low to high the surfaces now run
## gravel, meadow, forest floor, short yellow alpine turf, rusty heath, bare
## rock, snow - a progression that changes hue as well as value, so a slope
## reads as bands at a distance rather than as a gradient.
##
## THE VALUES BELOW ARE LINEAR, and the hex code beside each is what it was
## authored as. Godot renders in linear space and treats a vertex colour as
## already linear, so feeding it an sRGB hex value directly draws it far
## brighter and far less saturated than intended - #86B04A meadow arrives on
## screen as pale lime, and every zone washes into every other zone. The first
## screenshot tour is what caught it; the numbers had all looked fine.
##
## Converted here rather than by setting vertex_color_is_srgb on the material,
## because that flag does nothing under the Compatibility renderer and this
## has to be right on both.
##
## ... AND sRGB ON THE WIRE since look v2 Stage 0. These entries are still
## LINEAR and so is every multiplier that acts on them - baked AO, the far
## field's skirt and band, the aspect tint, the jitter. What changed is the
## last step: each mesh builder calls Look.to_wire() on its final colour at
## push_back, because the renderer decodes an 8-bit vertex colour on the way to
## the shader, and a linear value pushed straight in is decoded twice. The
## transfer sheet (`--sheet transfer`) proves the round trip every stage.
##
## THE HEXES BELOW ARE THE BIBLE'S WHERE THE BIBLE HAS ONE (light v1 Stage 3).
##
## `../Kubik-bible/style-bible/10-color-and-light.md` names three materials this
## table carries: Rock `#3e3734 / #5e524b / #8b8a83`, Snow
## `#cfd6dc / #e6dad1 / #f4f1ee` and Conifer `#575d54 / #7e8986 / #9b9f81`. Each
## is "one body colour in three shades", and under pillar 2 the block carries
## the BASE and the other two shades come from light and from the per-cube step
## - which is grill Q5, answered in the bible's own words. So `STONE` and `SNOW`
## take their base hex here, and the conifer ramp lands on `TreePalette`.
##
## EVERY OTHER ROW IS A BIBLE SILENCE and is kept exactly as look v2 Stage 4
## authored it, marked as such in its comment. `20-world-and-terrain.md` says
## only "meadow green", "greens, grey rock" and "natural by default"; inventing
## a hex to fill that would be this repo deciding art direction from the wrong
## side. The silences are listed in docs/status/light-v1.md so the round 3
## report can ask for them.
const COLORS := [
	Color(0.0000, 0.0000, 0.0000),   # AIR          #000000  never drawn
	Color(0.1119, 0.0844, 0.0704),   # STONE           #5E524B  bible "Rock", base of #3e3734 / #5e524b / #8b8a83
	Color(0.1946, 0.1144, 0.0630),   # DIRT            #7A5F47  soil - a bible silence, kept
	Color(0.2159, 0.3185, 0.0595),   # GRASS           #809945  "meadow green" only - a bible silence, kept
	Color(0.5711, 0.5271, 0.4072),   # SAND            #C7C0AB  a bible silence, kept
	Color(0.7913, 0.7011, 0.6376),   # SNOW            #E6DAD1  bible "Snow", base of #cfd6dc / #e6dad1 / #f4f1ee
	Color(0.1620, 0.0976, 0.0467),   # FOREST_FLOOR    #70583D  a bible silence, kept
	Color(0.0284, 0.0782, 0.0482),   # LEAVES          #2F4F3E  foliage
	Color(0.1119, 0.0545, 0.0395),   # TRUNK           #5E4238  
	Color(0.2831, 0.2961, 0.2705),   # SHORE           #91948E  wet gravel - the bible is silent; kept
	Color(0.3325, 0.3372, 0.1384),   # ALPINE_GRASS    #9C9D68  a bible silence, kept
	Color(0.1470, 0.0409, 0.0331),   # HEATH           #6B3933  a bible silence, kept
	Color(0.0395, 0.1070, 0.0648),   # LEAVES_SPRUCE_B #385C48  spruce, shade B
	Color(0.0782, 0.1946, 0.0423),   # LEAVES_BEECH    #4F7A3A  beech, shade A
	Color(0.1144, 0.2542, 0.0612),   # LEAVES_BEECH_B  #5F8A46  beech, shade B
	Color(0.5089, 0.3185, 0.0704),   # LEAVES_LARCH    #BD994B  larch, shade A - the warm accent
	Color(0.5841, 0.3864, 0.1095),   # LEAVES_LARCH_B  #C9A75D  larch, shade B
	Color(0.0497, 0.1119, 0.0356),   # LEAVES_PINE     #3F5E35  krummholz, shade A
	Color(0.0742, 0.1470, 0.0513),   # LEAVES_PINE_B   #4D6B40  krummholz, shade B
	Color(0.2307, 0.3916, 0.1046),   # LEAVES_BIRCH    #84A85B  birch, shade A
	Color(0.2874, 0.4452, 0.1384),   # LEAVES_BIRCH_B  #92B268  birch, shade B
	Color(0.6654, 0.6445, 0.5520),   # TRUNK_BIRCH      #D5D2C4  birch bark
	Color(0.3419, 0.3185, 0.2789),   # TRUNK_DEAD      #9E9990  snag, weathered
	# AUTHORED BLUER THAN IT LOOKS ON SCREEN, and that is the whole of trees v1
	# Stage 4's judge round 1. The first take was #2A2F3E - H225 S32, the value
	# the brief asks for - and it photographed at H270 S6: a neutral black band,
	# not a blue-violet sliver. The noon sun in this world is warm, and measured
	# off a lit crown face it lands on the three channels as roughly
	# (0.72, 0.54, 0.38): blue arrives at 53% of red, so a third of the authored
	# hue is cancelled on the way to the screen. #1F2A46 is that transform run
	# backwards from the colour the picture wanted. Measured on the lit side of
	# a Stage 4 spruce it renders H219 S36 V15, against the H213 S28 V13 the
	# shade ink makes of the same tree's dark side - which is the design: a lit
	# sliver reads as the shadow the ink would have drawn there, and a sliver on
	# the shade side has nothing to give itself away against.
	Color(0.0137, 0.0232, 0.0612),   # LEAVES_SLIVER   #1F2A46  the whorl underside
]

const NAMES := [
	"air", "stone", "dirt", "grass", "sand", "snow",
	"forest_floor", "leaves", "trunk",
	"shore", "alpine_grass", "heath",
	"leaves_spruce_b",
	"leaves_beech", "leaves_beech_b",
	"leaves_larch", "leaves_larch_b",
	"leaves_pine", "leaves_pine_b",
	"leaves_birch", "leaves_birch_b",
	"trunk_birch", "trunk_dead",
	"leaves_sliver",
]


## Solid blocks hide the faces of their neighbours. Everything except air, for
## now; when we add glass or water this becomes "is opaque" and stops being
## the same question as "is solid for collision".
static func is_solid(id: int) -> bool:
	return id != AIR


static func color_of(id: int) -> Color:
	return COLORS[id] if id >= 0 and id < COLORS.size() else Color.MAGENTA


static func name_of(id: int) -> String:
	return NAMES[id] if id >= 0 and id < NAMES.size() else "unknown(%d)" % id


# --- The colour path, and what left it --------------------------------------
#
# LIGHT V1 STAGE 3 EMPTIED THIS SECTION (grill Q15).
#
# `jitter()` hashed a coarse lattice and tilted a vertex's value and hue by a
# few percent; `aspect_shade()` darkened a face by its steepness and warmed it
# by how far it pointed at a FIXED compass direction; `aspect_curve()` made
# that changeover quick, so a hillside read as two flat tones meeting at the
# ridge. `SUN_ASPECT` and the two hash salts served them.
#
# All five existed because the toon ramp faceted and because a greedy-meshed
# hillside in one flat colour had nothing for the eye to grab. Under real light
# with soft sky-tinted shadows and SSAO neither problem exists, and painting a
# baked compass direction into a vertex is the thing pillar 2 names outright:
# mood "comes from light, fog, the hour and the lens, never from repainting a
# thing".
#
# The per-cube step grain that replaces them is in `Look.OPAQUE_SHADER`, and it
# is not a descendant of these - it is the bible's own sentence, "one step up
# or down on random cubes", applied per cell in the fragment rather than
# interpolated across a quad from its corners.
#
# `flora_models.gd`'s boulder keeps a lit-side plane and now owns the constant
# it needs, so nothing outside this file depended on SUN_ASPECT.
