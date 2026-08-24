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
const COLORS := [
	Color(0.0000, 0.0000, 0.0000),   # AIR          #000000  never drawn
	Color(0.3231, 0.2747, 0.2159),   # STONE        #9A8F80  bare rock
	Color(0.2582, 0.1590, 0.0630),   # DIRT         #8B6F47  soil
	Color(0.2384, 0.4342, 0.0685),   # GRASS        #86B04A  meadow
	Color(0.6939, 0.5711, 0.2346),   # SAND         #D9C785  unused for now
	Color(0.8879, 0.8714, 0.8070),   # SNOW         #F2F0E8
	Color(0.1022, 0.2623, 0.0452),   # FOREST_FLOOR #5A8C3C
	Color(0.0762, 0.1946, 0.0319),   # LEAVES       #4E7A32  foliage
	Color(0.1470, 0.0782, 0.0232),   # TRUNK        #6B4F2A
	Color(0.5209, 0.4508, 0.2549),   # SHORE        #BFB48C  wet gravel
	Color(0.3864, 0.4793, 0.1170),   # ALPINE_GRASS #A7B860  short yellow turf
	Color(0.2623, 0.1144, 0.0704),   # HEATH        #8C5F4B  rusty dwarf shrub
]

const NAMES := [
	"air", "stone", "dirt", "grass", "sand", "snow",
	"forest_floor", "leaves", "trunk",
	"shore", "alpine_grass", "heath",
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
