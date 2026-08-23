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
}

## Per-type tint. We use one greyscale placeholder texture for every block and
## multiply it by these vertex colours, so a single 16x16 png gives us a whole
## palette. Real per-face textures (an atlas) come later.
const COLORS := [
	Color(0, 0, 0),             # AIR - never drawn
	Color(0.55, 0.56, 0.58),    # STONE
	Color(0.45, 0.33, 0.22),    # DIRT
	Color(0.36, 0.62, 0.28),    # GRASS
	Color(0.85, 0.78, 0.52),    # SAND
	Color(0.92, 0.94, 0.97),    # SNOW
]

const NAMES := ["air", "stone", "dirt", "grass", "sand", "snow"]


## Solid blocks hide the faces of their neighbours. Everything except air, for
## now; when we add glass or water this becomes "is opaque" and stops being
## the same question as "is solid for collision".
static func is_solid(id: int) -> bool:
	return id != AIR


static func color_of(id: int) -> Color:
	return COLORS[id] if id >= 0 and id < COLORS.size() else Color.MAGENTA


static func name_of(id: int) -> String:
	return NAMES[id] if id >= 0 and id < NAMES.size() else "unknown(%d)" % id
