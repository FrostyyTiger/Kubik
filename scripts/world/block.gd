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
}

## The palette. These ARE the look of the game - there are no textures, so a
## block is exactly its colour and nothing else.
##
## Warm and slightly saturated on purpose. A physically plausible grey-green
## reads as washed out at distance, and distance is what this world is for: the
## design is sold on telling a meadow from a forest from a snowfield across a
## valley, which is a question about colour separation, not realism.
const COLORS := [
	Color(0, 0, 0),                   # AIR - never drawn
	Color(0.604, 0.561, 0.502),       # STONE       #9A8F80 bare rock
	Color(0.545, 0.435, 0.278),       # DIRT        #8B6F47 soil
	Color(0.525, 0.690, 0.290),       # GRASS       #86B04A meadow
	Color(0.85, 0.78, 0.52),          # SAND        (unused for now)
	Color(0.949, 0.941, 0.910),       # SNOW        #F2F0E8
	Color(0.353, 0.549, 0.235),       # FOREST_FLOOR #5A8C3C
	Color(0.306, 0.478, 0.196),       # LEAVES      #4E7A32 foliage
	Color(0.420, 0.310, 0.165),       # TRUNK       #6B4F2A
]

const NAMES := [
	"air", "stone", "dirt", "grass", "sand", "snow",
	"forest_floor", "leaves", "trunk",
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
