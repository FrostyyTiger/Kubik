class_name TreeSpecies

## WHAT A TREE IS, as data - and nothing about how one is DRAWN.
##
## THIS FILE WAS 3,383 LINES AND ROUGHLY HALF OF IT WAS SHAPES. Whorled cones,
## larch ziggurats, lobed beech scallops, bowed birches, wind-flagged krummholz
## cushions, three kinds of snag and a re-proportioned hero - every one of them
## a function that stamped `Block.LEAVES` and `Block.TRUNK` into a chunk. Trees
## v3 ruling 5 deleted all of it, and this header is the receipt.
##
## THEY WERE NOT BAD CODE AND THEY DID NOT FAIL. They were the best a tree can
## be when a tree is made of the same 0.5 m blocks as the mountain behind it,
## and trees v1 got them there: TWINS 1.00 down to 0.72 on all seven species,
## no pair over 0.56, the sparse species 24-65% cheaper in quads than the solid
## ones. What ended them is that a tree is the one object in this game read
## against both the valley AND the player (`DESIGN.md` § the read-against
## table), and at 1:1 with the world's own grid it could never be read against
## the player without being a staircase. The ladder closed from the other end.
##
## WHAT THEY TAUGHT, kept because the lessons outlived the code:
##
##   GREEDY MESHING AND PER-BLOCK VARIATION DO NOT MIX. A crown of two
##   interleaved leaf shades cost hundreds of quads where one shade cost a few,
##   and per-BLOCK holes in a sparse crown were the single worst input this
##   game's mesher was ever handed - a 588-block birch buying 937 quads. Both
##   were fixed by moving the variation up a level: one shade per TREE, and
##   holes as CLUMPS hashed at 2x2. The same lesson arrived from the other side
##   tonight (Stage 1): greedy meshing and one-voxel-thick geometry do not mix
##   either, and Tree 10 is 54% of the library's triangles for 1.5% of its
##   voxels.
##
##   BIGNESS READS THROUGH PROPORTION, NOT MAGNIFICATION. The hero was a scaled
##   spruce once and it read as a spruce you were standing closer to.
##
##   CHECK WINDING WITH THE CROSS PRODUCT, NOT WITH YOUR EYES. Recorded by
##   `FloraModels` and paid for again in Stage 2, where four of six faces were
##   backwards and the picture looked like a modelling choice.
##
##
## WHAT SURVIVES, AND WHY EACH PIECE DOES.
##
## The TABLE - names, height and crown ranges, the read share, the slope a
## species will stand on. `TreePlacement` reads it to decide what grows where,
## `TreeTable` joins its names to the library, and the probe counts by it.
##
## `params_for()` - still pure, still hashed from the cell, still the whole
## determinism contract. It is what `decide()` puts in its `params` key and
## four consumers read.
##
## `max_reach()` - the margin every column widens its candidate scan by. The
## crowns it bounds are drawn by `TreeField` now, but the SCAN still has to be
## wide enough that every column sees every tree whose canopy covers it, or the
## forest floor's shade would depend on which column asked.
##
## `max_height()` - kept and its meaning narrowed; see the note on it.
##
## THE BLOCK IDS IN THE TABLE STAY, and `params_for()` still returns them.
## Open question 5 asks whether it slims to placement-only fields now or later,
## and the answer is LATER: the plan requires that `decide()`'s output SHAPE
## does not change, the ids cost nothing, and a stage that is already almost
## all red is the wrong place to also reshape the dictionary four consumers
## read. `Block`'s ids stay parked for the same reason - removing one
## renumbers a wire format for zero benefit.


# --- Species ids ------------------------------------------------------------
#
# Indices into SPECIES. They are NOT block ids and never cross the network, so
# unlike Block they may be reordered - but the placement weight tables are
# written in terms of them, so do not do it casually.

enum {
	SPRUCE = 0,
	BEECH = 1,
	LARCH = 2,
	KRUMMHOLZ = 3,
	BIRCH = 4,
	SNAG = 5,
	HERO = 6,
}

const COUNT := 7

# --- Salts ------------------------------------------------------------------
#
# Every parameter a tree hashes gets its own, or its height and its crown
# radius would agree with each other and every tall tree in the world would
# also be the widest one.
#
# 203 AND 204 KEEP THE VALUES THEY HAD IN TerrainGenerator. A salt is part of
# what a seed means; changing one silently rearranges every tree in every
# existing world, and there is no reason to spend that here.

const SALT_HEIGHT := 203
const SALT_CROWN := 204
const SALT_SHADE := 210
const SALT_HERO_PARENT := 211
const SALT_HERO_SCALE := 212
## RETIRED AT TREES V1 STAGE 3, and the number stays claimed. It salted the
## krummholz's one-block lean, which the wind flag replaced - and the lean was
## also the loose-block bug the whole time, because it stepped the trunk out
## from under the crown it was carrying.
const SALT_LEAN := 213
const SALT_STUBS := 214
## RETIRED AT TREES V1 STAGE 3, and the number stays claimed. It salted the
## PER-BLOCK holes in a sparse crown, hashed from the block's own world position
## so that every chunk drawing one larch punched the same holes in it. The
## krummholz was the last species still asking it, and with the cushion drawn
## through `_whorl_disc` there is no per-block hole left anywhere in the file -
## which is what plan rule 6 asked for and what took the sparse species from
## dearer in quads than a solid beech to cheaper than they have ever been.
const SALT_SPARSE := 215
## Never used. Free.
const SALT_MOUND := 216

## Salts the COHERENT holes in a sparse crown (trees v1 Stage 1), which is what
## replaces SALT_SPARSE species by species as the epic works through them.
##
## The position is hashed at 2 x 2 resolution in plan - `(x >> 1, z >> 1)` -
## under a salt keyed by the shape's own unit (a larch shelf), so a hole is a
## clump of eight blocks rather than one block, which is both the look (foliage,
## not static) and roughly a fivefold cut in quads, because per-block holes are
## the worst input greedy meshing can be handed.
##
## THE SERIES IS 217 + key * 7919 AND IT COULD NOT MEET SALT_SPARSE'S. That one
## was 215 + y * 7919: same stride, and the two offsets differ by 2, which no
## multiple of 7919 is. They shared a world until every sparse species had moved
## over, which finished at Stage 3 - the hazard is historical now, and the rule
## that no new salt may land on either series is not.
const SALT_CLUMP := 217
## Per-tier whorl arms: how many, how long each one is.
const SALT_WHORL := 218
## Per-layer crown radius jitter.
const SALT_JITTER := 219
## Everything a conifer decides once for itself: notch phase, arm phase, drift
## direction, top treatment, whether it self-pruned.
const SALT_CONIFER := 220

## Everything a beech decides once: how oblate it is, where its crown starts,
## how many lobes, which way the first one leans, the plan ellipse and its
## swap, whether it forks and how wide.
const SALT_BEECH := 221
## Per-lobe: the vertical jitter that stops four lobes from stacking in the
## same four places on every tree.
const SALT_LOBE := 222
## Per-bite: radius, how deep it cuts, how high up the side it lands.
const SALT_BITE := 223
## Everything a birch decides once: the bow, the clump layout, whether it grew
## a second stem and how far aside.
const SALT_BIRCH := 224
## THE SHARED WIND DIRECTION, and it is hashed from the SEED ALONE. See
## params_for() - this is the one hashed thing in the file that is a property of
## the world rather than of a tree.
const SALT_WIND := 225
## The limb blocks entering a beech's crown underside.
const SALT_LIMB := 226

## Everything a krummholz decides once (trees v1 Stage 3): how oblate its
## cushion is, one step of wind off the world's, and the ragged edge of its plan.
const SALT_KRUMM := 227
## Per-spar: which way off the axis it stands, how far, and how proud of the
## cushion it finishes.
const SALT_SPAR := 228
## Everything a snag decides: which of the three it is, where it broke, which
## way it leans, and the one direction neighbourhood its stubs all come out of.
const SALT_SNAG := 229
## Everything a hero decides once: which dead element it carries, where it
## forks, how many lobes, and the azimuth the whole crown is laid out from.
const SALT_HERO := 230
## Per-lobe and per-limb: how high up the crown a lobe rides and how long the
## limb that carries it runs.
const SALT_HERO_LOBE := 231


## HOW MANY DIRECTIONS THE WORLD'S WIND CAN BLOW FROM.
##
## THIRTEEN, AND THE NUMBER IS INHERITED RATHER THAN CHOSEN HERE. It was the
## length of the golden-angle direction table the whorl arms stepped through,
## picked because thirteen is coprime with every tier count a conifer used, so
## arms never repeated an azimuth. That table is deleted; the modulus stays,
## because `params_for()` hashes the world's wind direction against it and
## changing it would turn the wind in every existing world.
##
## Nothing reads the direction yet - the shapes that flagged a krummholz and
## bowed a birch along it are gone, and `Look.tree_material()`'s sway is
## driven by world position rather than by a world wind. It is kept in
## `params` because it is part of what a seed means and because a world wind
## is exactly the input a directional sway would want.
const GOLDEN_N := 13


## One row per species.
##
## TREES V3 DROPPED TWO COLUMNS FROM THIS TABLE: `shape`, which named the
## function that drew a species, and `fill`, the probability a crown block
## existed at all. Both were read by the shape half and by nothing else, and
## what a species LOOKS like is `TreeTable`'s job now. The rows' long notes
## about why larch was 0.75 and birch 0.80 went with them - they are in this
## file's git history and in `docs/status/trees-v1.md`, which is where a
## sparse-crown argument belongs now that no crown is made of blocks.
##
##   name        for the probe, the gallery and STATUS.md
##   height      min/max TOTAL height in blocks - trunk and crown together
##   crown       min/max crown radius in blocks
##   leaves      block id, shade A; leaves_b is shade B
##   trunk_id    block id for the trunk
##   slope       steepest ground, in degrees, this species will stand on
##
## HEIGHTS ARE TOTAL, and that is a change from the old code, which stored a
## trunk height and grew a cone on top of it. Total is the number a person can
## picture and check against the scale table - a 21-block spruce is 10.5 m at
## 1:4, which is a real spruce - whereas "trunk 14 plus canopy 6" is a number
## you have to reconstruct the tree from before you know whether it is wrong.
const SPECIES := [
	{
		"read": 1.0, "name": "spruce", "height": Vector2i(13, 21), "crown": Vector2i(2, 4),
		"leaves": Block.LEAVES, "leaves_b": Block.LEAVES_SPRUCE_B,
		"sliver": Block.LEAVES_SLIVER,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"read": 1.0, "name": "beech", "height": Vector2i(10, 16), "crown": Vector2i(4, 6),
		"leaves": Block.LEAVES_BEECH, "leaves_b": Block.LEAVES_BEECH_B,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"read": 1.0, "name": "larch", "height": Vector2i(12, 20), "crown": Vector2i(2, 3),
		# FILL 0.75, AND THE OPENNESS IS THE SHAPE (trees v1 Stage 1, judge
		# round 2). §2.5 asks for 0.5 "so sky shows through", and 0.6 was
		# per-block noise: lace at five metres, invisible at forty, and dearer
		# in quads than a max beech's entire crown. Round 1 kept the halving and
		# clumped it, and the renders came back as burnt scaffolding - a crown
		# with half of it missing has nothing left to be a crown. The sky now
		# shows through the AIR GAPS BETWEEN THE SHELVES (see the ziggurat), and
		# what is left of the fill is a texture on a solid thing. Read
		# SHELF_FILL for the number the shape actually uses; this row is what
		# params_for() hands the writer.
		"leaves": Block.LEAVES_LARCH, "leaves_b": Block.LEAVES_LARCH_B,
		"sliver": Block.LEAVES_SLIVER,
		"trunk_id": Block.TRUNK, "slope": 40.0,
	},
	{
		"read": 0.0, "name": "krummholz", "height": Vector2i(3, 6), "crown": Vector2i(3, 5),
		"leaves": Block.LEAVES_PINE, "leaves_b": Block.LEAVES_PINE_B,
		"trunk_id": Block.TRUNK, "slope": 55.0,
	},
	{
		"read": 0.5, "name": "birch", "height": Vector2i(10, 16), "crown": Vector2i(2, 3),
		# FILL 0.80, AND THE HOLES ARE CLUMPS NOW (trees v1 Stage 2). At 0.70,
		# hashed per block, the sparseness was the most expensive thing on the
		# tree - 588 blocks bought 937 quads - and at forty metres it read as
		# static rather than as leaves. The openness is the SHAPE now: three to
		# five clumps with real sky between them. What is left of the fill is a
		# texture on a solid thing, hashed at 2 x 2 under the clump's own key.
		"leaves": Block.LEAVES_BIRCH, "leaves_b": Block.LEAVES_BIRCH_B,
		"trunk_id": Block.TRUNK_BIRCH, "slope": 40.0,
	},
	{
		"read": 0.0, "name": "snag", "height": Vector2i(6, 14), "crown": Vector2i(0, 0),
		"leaves": Block.AIR, "leaves_b": Block.AIR,
		"trunk_id": Block.TRUNK_DEAD, "slope": 45.0,
	},
	{
		# 1.6x the smallest beech through 2.0x the largest spruce. Stated as a
		# range rather than left implicit, because max_height() reads this
		# table to decide how much empty sky the world reserves above the
		# terrain - and a hero whose real size exceeded what the table admits
		# would have its crown cut off by a chunk that was never queued.
		"read": 1.0, "name": "hero", "height": Vector2i(16, 42), "crown": Vector2i(3, 8),
		"leaves": Block.LEAVES, "leaves_b": Block.LEAVES_SPRUCE_B,
		"sliver": Block.LEAVES_SLIVER,
		"trunk_id": Block.TRUNK, "slope": 30.0,
	},
]

## Trunk width by total height, in blocks: a tree at or above the first number
## gets a trunk that many voxels square.
##
## A 20-block tree on a 1-block stalk reads as a lollipop, and once the forest
## doubles (world feel v1 Stage 5) a 2 x 2 trunk under a 60-block spruce reads
## as one too. Real trunk diameter scales with height; this is that, as data
## rather than as one threshold.
##
## Read top down - the first row a height clears wins.
const TRUNK_TIERS := [
	{"height": 48, "width": 4},
	{"height": 32, "width": 3},
	{"height": 16, "width": 2},
]

## Kept for anything still asking the old yes/no question.
const THICK_TRUNK_HEIGHT := 16


## How many voxels square a trunk of this height is. Heroes are never under 3.
static func trunk_width(height: int, species: int) -> int:
	var w := 1
	for tier in TRUNK_TIERS:
		if height >= int(tier["height"]):
			w = int(tier["width"])
			break
	if species == HERO:
		w = maxi(w, 3)
	return w


## The table with `tree_size_scale` applied.
##
## Scaled here rather than at every call site, so that everything downstream -
## the maxima, the gallery, the stamper - is looking at the same numbers. The
## scale is a SHAPE knob and lives in PROPERTIES: two machines that disagreed
## about it would grow different trees while the handshake reported a match.
static func table(config: WorldgenConfig) -> Array:
	var scale: float = config.tree_size_scale
	var read: float = config.tree_read_scale
	if is_equal_approx(scale, 1.0) and is_equal_approx(read, 1.0):
		return SPECIES
	var out := []
	for row in SPECIES:
		var copy: Dictionary = (row as Dictionary).duplicate()
		# TWO SCALES, COMPOSED PER SPECIES (world feel v1 Stage 5).
		#
		# tree_size_scale is what the LAND says: derived from world_scale, it
		# keeps a tree the right size against a mountain. tree_read_scale is
		# what the PLAYER says: a tree is the one object read against both, and
		# at 1:4 land scale a spruce was 7 player-heights where a real one is
		# 25. The land is not rescaled; the trees are.
		#
		# `read` is how much of that a species takes: 1.0 for the forest
		# proper, 0.5 for birch, 0.0 for krummholz and snags - a knee-high
		# alpine shrub at twice the size is not a bigger shrub, it is a tree.
		var f: float = scale * (1.0 + (read - 1.0) * float(row.get("read", 0.0)))
		copy["height"] = Vector2i(
			maxi(1, int(round(float(row["height"].x) * f))),
			maxi(1, int(round(float(row["height"].y) * f))))
		copy["crown"] = Vector2i(
			int(round(float(row["crown"].x) * f)),
			int(round(float(row["crown"].y) * f)))
		out.append(copy)
	return out


## THE TALLEST TREE THE TABLE CAN GROW, IN BLOCKS - AND IT NO LONGER RESERVES
## ANY SKY.
##
## TREES V3 STAGE 7 NARROWED WHAT THIS MEANS WITHOUT CHANGING WHAT IT RETURNS.
## World used to add it to the top of every column's chunk range, because a
## crown stamped into the volume must not be cut off by a chunk nobody built -
## and that was twenty-one metres of empty chunks above every column in the
## world. Nothing is written above the terrain now, so World adds nothing and
## `world_height_blocks` carries no tree in it.
##
## It survives because the number is still true and still wanted: the probe
## prints it, the mapping table is read against it, and "how tall can a tree
## be" is a question about the table that should have one answer. `max_reach()`
## is the one that is still LOAD-BEARING - it is the horizontal margin every
## column widens its candidate scan by, and the forest floor's shade depends on
## it being wide enough.
##
## The +3 is the same margin the single-species version carried: a shape may
## round a layer upward.
static func max_height(config: WorldgenConfig) -> int:
	var tallest := 0
	for row in table(config):
		# AND OLD GROWTH, for the same reason max_reach() takes it: the scale
		# is applied per tree, not in the table.
		var h := float(row["height"].y)
		h *= 1.0 + (maxf(config.old_growth_scale, 1.0) - 1.0) \
			* float(row.get("read", 0.0))
		tallest = maxi(tallest, int(ceil(h)) + 3)
	return tallest


## How far sideways a crown can spread, in blocks. The margin `stamp_chunk()`
## widens its candidate scan by, and derived for the same reason.
static func max_reach(config: WorldgenConfig) -> int:
	var widest := 0
	for row in table(config):
		# AND OLD GROWTH, whose crowns are old_growth_scale times the table's -
		# applied per tree in params_for(), so a bound taken from the table
		# alone is not a bound at all, and the symptom is a crown clipped at a
		# column boundary in some groves on the side away from the trunk.
		#
		# This margin is paid by EVERY column in the world, so it is the one
		# place an old-growth knob costs something everywhere.
		var c := float(row["crown"].y)
		c *= 1.0 + (maxf(config.old_growth_scale, 1.0) - 1.0) \
			* float(row.get("read", 0.0))
		widest = maxi(widest, int(ceil(c)))
	# A wide trunk occupies blocks further out than the cell it is rooted in,
	# and a mound's raggedness never exceeds its radius - so the crown maximum
	# plus the widest trunk is a true bound on how far a tree can write.
	var widest_trunk := 1
	for tier in TRUNK_TIERS:
		widest_trunk = maxi(widest_trunk, int(tier["width"]))
	return widest + widest_trunk


# --- One tree's parameters --------------------------------------------------

## Everything one tree needs to know about itself, hashed from its cell.
##
## Pure, and the whole determinism contract rests on that: two machines, two
## chunk build orders and two hemispheres of the map all call this with the
## same three integers and get the same tree back.
## `extra` is a further size multiplier on top of the table - old growth, at
## world feel v1 Stage 6. It takes the species' own `read` share exactly as
## tree_read_scale does, so krummholz and snags are the same size in an old
## wood as anywhere else: an ancient forest is ancient trees, and a shrub that
## has been there a long time is still a shrub.
static func params_for(species: int, cell_x: int, cell_z: int,
		world_seed: int, config: WorldgenConfig, extra := 1.0) -> Dictionary:
	var rows := table(config)
	var row: Dictionary = rows[species]

	# OLD GROWTH GROWS IN BOTH DIRECTIONS, and getting here took one wrong turn
	# worth recording. Crowns were briefly left unscaled, because scaling them
	# grows TreeSpecies.max_reach() - the margin every column in the world
	# widens its candidate scan by - and Stage 6 was at that moment showing 73
	# frames over 33 ms and ten of twelve jumps failing to settle. The crowns
	# were not the cause; a RenderingServer call on a worker thread was (see
	# ChunkMesher._under_canopy). With that fixed the margin is affordable, and
	# height alone left an old-growth grove no more CLOSED than an ordinary one
	# - 0.553 against 0.517 - which is most of what old growth is for.
	var f := 1.0
	if not is_equal_approx(extra, 1.0):
		f = 1.0 + (extra - 1.0) * float(row.get("read", 0.0))
	var height := int(round(float(WorldHash.hash_range(
		cell_x, cell_z, world_seed, SALT_HEIGHT,
		row["height"].x, row["height"].y)) * f))
	var crown := int(round(float(WorldHash.hash_range(
		cell_x, cell_z, world_seed, SALT_CROWN,
		row["crown"].x, row["crown"].y)) * f))
	var draw_species := species
	var leaves_row := row

	if species == HERO:
		# THE HERO TAKES ITS PARENT'S SIZE RANGE AND IDS, NOT ITS SHAPE (trees
		# v1 Stage 3). It used to be the same beech or spruce scaled, and a
		# scaled parent is exactly what the poster tradition says a big tree
		# must never be - bigness reads through changed PROPORTIONS, not
		# through magnification. What survives of the parent is which of the
		# two archetypes the hero is, the leaf and trunk ids that go with it,
		# and the height and crown roll the scale is applied to; `_draw_hero`
		# is the rest.
		var parent := BEECH if WorldHash.hash01(cell_x, cell_z, world_seed,
			SALT_HERO_PARENT) < 0.6 else SPRUCE
		var parent_row: Dictionary = rows[parent]
		var scale := lerpf(1.6, 2.0,
			WorldHash.hash01(cell_x, cell_z, world_seed, SALT_HERO_SCALE))
		var parent_h := WorldHash.hash_range(cell_x, cell_z, world_seed,
			SALT_HEIGHT, parent_row["height"].x, parent_row["height"].y)
		var parent_r := WorldHash.hash_range(cell_x, cell_z, world_seed,
			SALT_CROWN, parent_row["crown"].x, parent_row["crown"].y)
		# Clamped to what the hero row admits, because max_height() and
		# max_reach() are computed from that row and the world reserved its
		# sky accordingly.
		height = clampi(int(round(float(parent_h) * scale)),
			row["height"].x, row["height"].y)
		crown = clampi(int(round(float(parent_r) * scale)),
			row["crown"].x, row["crown"].y)
		draw_species = parent
		leaves_row = parent_row

	# THE WIND BLOWS ONE WAY IN ONE WORLD, and this is the only thing in the
	# file hashed from the seed WITHOUT the cell. Every other decision here is
	# per-tree because two neighbours must not be the same tree; this one is
	# per-WORLD because a treeline that combed in twelve directions would read
	# as twelve accidents instead of as weather. The birch bows along it (Stage
	# 2) and the krummholz will flag along it (Stage 3), each taking a step or
	# two of its own variation off it - correlation is the point, uniformity is
	# not.
	var wind_dir := WorldHash.hash2(0, 0, world_seed, SALT_WIND) % GOLDEN_N

	# A OR B, hashed once for the whole tree. Per-tree, never per-block: the
	# mesher merges blocks of one colour into one quad, so a crown of two
	# interleaved shades would cost hundreds of quads instead of a few, for a
	# result that reads as noise rather than as two trees.
	var shade := WorldHash.hash2(cell_x, cell_z, world_seed, SALT_SHADE) & 1

	return {
		"species": species,
		"draw": draw_species,
		"height": height,
		"crown": crown,
		"leaves": leaves_row["leaves"] if shade == 0 else leaves_row["leaves_b"],
		# THE SECOND COLOUR IS NOT A THIRD SHADE (trees v1 Stage 4). It does
		# not take the A/B roll: A and B are two trees of one species catching
		# the same light, and the sliver is the SHADOW under a whorl, which is
		# the same shadow on both of them. Absent (AIR) for every species whose
		# crown has no shelves to shade the one below - the broadleaves, the
		# cushion, the snag - and the shape code draws nothing where it is AIR.
		"sliver": leaves_row.get("sliver", Block.AIR),
		"trunk_id": leaves_row["trunk_id"],
		# Hero trunks are ALWAYS 2 x 2, whatever the height rule says. A tree
		# twice the size of everything around it standing on the same stalk as
		# everything around it is the one way to make it look wrong.
		"thick": species == HERO or height >= THICK_TRUNK_HEIGHT,
		"trunk_width": trunk_width(height, species),
		"cell": Vector2i(cell_x, cell_z),
		"seed": world_seed,
		"wind_dir": wind_dir,
	}


## Total height of a tree with these parameters, in blocks.
static func total_height(_species: int, params: Dictionary,
		_config: WorldgenConfig = null) -> int:
	return params["height"]




# --- The gallery ------------------------------------------------------------

## One row per species, in table order, for the model gallery's layout.
static func gallery_rows(config: WorldgenConfig = null) -> Array:
	var cfg := config if config != null else WorldgenConfig.new()
	var rows := []
	for i in table(cfg).size():
		rows.append({"id": i, "name": table(cfg)[i]["name"]})
	return rows


## The seed every gallery specimen is hashed under.
##
## A CONSTANT, AND NOT THE WORLD'S. The gallery photographs shapes, not a
## world, so its trees must not move when somebody plays a different seed -
## and a specimen photographed at one stage has to be the same specimen at the
## next, or two gallery sheets cannot be compared with each other at all.
const SPECIMEN_SEED := 20260824


## The cell stamp_specimen() hashes a specimen from, when the caller has not
## chosen one.
##
## Far from anything the world uses, varied per specimen, so the details a
## shape hashes for itself - lean, stubs, holes - differ between the three
## sizes instead of all three leaning the same way.
static func specimen_cell(species: int, t: float) -> Vector2i:
	return Vector2i(100000 + species * 37, 100000 + int(round(t * 2.0)) * 53)
