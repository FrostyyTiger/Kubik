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


# --- Terrain v2 Stage 10: making one colour into many ----------------------
#
# The palette is nine flat colours and the world is built entirely out of them,
# so a meadow is one exact green over its whole extent and reads as a painted
# surface. These two functions break that up without adding a single vertex.
#
# THE CONSTRAINT THAT SHAPES BOTH OF THEM IS GREEDY MESHING. Per-BLOCK colour
# variation is the obvious implementation and it is incompatible with merging:
# if neighbouring blocks differ in colour they cannot share a quad, and a flat
# meadow chunk goes from one quad to two hundred and fifty six. So the
# variation lives in the VERTICES instead, sampled at the quad's corners and
# interpolated across it. Two quads meeting at a lattice point sample the same
# point and get the same value, so the field is continuous, nothing has to
# split, and the cost is zero quads.

## Deterministic per-vertex tint, hashed from a coarse lattice.
##
## `patch` is how many blocks share one hash cell. Small values give fine
## mottling that is mostly invisible after interpolation; large ones give broad
## drifts of tone across a hillside, which is what actually reads. The value
## and hue amounts are fractions and are meant to be small - this is texture,
## not confetti.
##
## Hue is faked as a red-against-blue tilt rather than a real HSV rotation.
## The palette is stored linear, a correct rotation means converting to sRGB,
## to HSV, back, and back again per vertex, and the visible difference between
## that and tilting two channels in opposite directions by two percent is
## nothing at all.
static func jitter(color: Color, bx: int, bz: int, world_seed: int,
		patch: int, value_amount: float, hue_amount: float) -> Color:
	if value_amount <= 0.0 and hue_amount <= 0.0:
		return color
	var cell := maxi(patch, 1)
	var cx := (bx - posmod(bx, cell)) / cell
	var cz := (bz - posmod(bz, cell)) / cell
	var v := 1.0 + (WorldHash.hash01(cx, cz, world_seed, SALT_TINT_VALUE) * 2.0 - 1.0) * value_amount
	var h := (WorldHash.hash01(cx, cz, world_seed, SALT_TINT_HUE) * 2.0 - 1.0) * hue_amount
	return Color(
		maxf(color.r * v * (1.0 + h), 0.0),
		maxf(color.g * v, 0.0),
		maxf(color.b * v * (1.0 - h), 0.0),
		color.a)


## Tint one face by which way it points.
##
## SLOPE. Steep faces get less sky, so they are darker. The renderer's own
## lighting already does some of this, which is why the default is gentle - the
## job here is to separate a wall from a floor when both happen to be lit the
## same, not to relight the world.
##
## ASPECT. A slope facing the sun is warmer and drier than one in shade, and in
## the Alps that is visible as a real difference in what grows on it. Baked
## against a FIXED direction rather than against the sun's actual position,
## deliberately: the mesh is built once and the sun moves, so a baked lighting
## term would be wrong for half of every day. What this bakes is not lighting,
## it is aspect - a fact about the ground, which does not move.
static func aspect_shade(color: Color, normal: Vector3,
		slope_amount: float, aspect_amount: float) -> Color:
	var out := color
	if slope_amount > 0.0:
		# 1 for a floor or ceiling, 0 for a wall.
		var flatness := absf(normal.y)
		var shade := 1.0 - slope_amount * (1.0 - flatness)
		out = Color(out.r * shade, out.g * shade, out.b * shade, out.a)
	if aspect_amount > 0.0:
		var facing := normal.x * SUN_ASPECT.x + normal.z * SUN_ASPECT.y
		var warm := 1.0 + aspect_amount * facing
		var cool := 1.0 - aspect_amount * facing
		out = Color(out.r * warm, out.g * (1.0 + aspect_amount * facing * 0.35),
			out.b * cool, out.a)
	return out


## Which way "sunward" points, in XZ. Any fixed direction would do; this one is
## the -Z the camera starts looking along, so the aspect difference is visible
## in the first screenshot rather than behind you.
const SUN_ASPECT := Vector2(0.0, -1.0)

const SALT_TINT_VALUE := 301
const SALT_TINT_HUE := 302
