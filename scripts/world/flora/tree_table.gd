class_name TreeTable

## Which library variants stand for which of the game's tree species.
##
## THE ONE PLACE THE PACK'S NAMES APPEAR (trees v3 decision 12). `t11_4` means
## nothing anywhere else in this repo: `TreeField` asks for a species and a
## cell hash and gets a variant back, and every other file talks about spruce
## and beech exactly as it did when a spruce was made of blocks.
##
## MARCEL RETUNES BY EDITING THIS FILE. Which variants a species draws from,
## how they are weighted against each other, what a species is allowed to be at
## altitude, and whether the fantasy colourways exist at all - all data, all
## here, and none of it requires re-running a tool or touching the assets repo.
##
##
## THE MAPPING IS PROVISIONAL AND PHOTOGRAPHED.
##
## It was made by Opus from the gallery sheets and the sidecars' own shape
## statistics, and the plan says so in as many words. Every row below names
## what it was reading. Where the pack has nothing good for a species, the row
## says that too rather than quietly choosing the least-bad thing.
##
##
## HEIGHTS ARE THE ARTIST'S (ruling 3).
##
## `height_m` of 0 means "draw it at the size it was drawn at", which is what
## every row uses. The library lands at 21-28 m for the trees proper against
## the block trees' 13-21 m, and that register shift is the monumental north
## star, chosen with the numbers on the table rather than stumbled into. A
## non-zero `height_m` scales a species to a target instead, and it is the
## first knob to reach for if the valleys come back too dark.


## What the pack turned out to actually contain, which is not what the plan
## guessed - and the difference is worth stating once, at the top, because two
## whole species folders are benched on it.
##
##   t05   32 x 206 x 32    a crimson column, dense. Strange, not alpine.
##   t07   180 x 206 x 139  a broad branching broadleaf, the widest crown here
##   t08   17 x 175 x 16    a thin crimson spire
##   t09   COCONUT PALMS    five trunk segments, twenty-four radiating fronds
##   t10   COCONUT PALMS    the same, shorter and more of them
##   t11   the classic stepped conifer - and two BARE DEAD SPIRES among them
##   t12   a tiered conifer, ten variants: green, snow-dusted, autumn, crimson
##   t13   a big rounded broadleaf on a straight trunk, five colourways
##   t14   the same register, a different crown, five colourways
##   t15   the largest crowns in the pack, six colourways including pink
##   t16   CUT STUMPS, 2 m, six of them
const PACK_SHAPES := &"see the comment above - do not delete it"

## `height_m` 0 means the model's own height.
const NATIVE := 0.0


## One row per game species. `slot` is the name `TreePlacement.FOREST_WEIGHTS`
## and `TreeSpecies.SPECIES` already use.
##
## `variants` and `weights` are parallel: a species picks one variant per tree,
## hashed from the cell, with these relative weights. A weight of 0 means the
## variant is PRESENT AND INERT - the geometry is loaded, the palette is
## mapped, the gallery photographs it, and no cell in the world ever picks it
## until Marcel edits the number. That is decision 12's parking space for the
## crimson and pink colourways, and it is a number rather than a comment so
## that awakening a strange forest is a one-character edit.
const ROWS := [
	{
		"slot": &"spruce",
		# TREE 11, THE CLASSIC STEPPED CONIFER. The whole reason this epic is
		# worth running is on this sheet: whorled tiers, a bare trunk under
		# them, and a surface that is this game's own because it went through
		# this game's mesher. `t11_2` and `t11_5` and `t11_8` are colourway
		# twins of the three before them and cost no triangles.
		"variants": [&"t11_1", &"t11_2", &"t11_3", &"t11_4", &"t11_5",
			&"t11_7", &"t11_8"],
		"weights": [1.0, 1.0, 1.0, 0.7, 0.7, 0.7, 0.7],
		"height_m": NATIVE,
		"note": "24-28 m; the forest's backbone",
	},
	{
		"slot": &"larch",
		# TREE 12, THE TIERED CONIFER, AND THE AUTUMN COLOURWAYS ARE THE POINT.
		# Larch is this world's warm accent - the one conifer that turns gold -
		# and this species folder ships that as DATA: three greens, a
		# snow-dusted variant, and five autumn twins over the same geometry. A
		# larch stand in October costs no new mesh.
		"variants": [&"t12_1", &"t12_2", &"t12_3", &"t12_4",
			&"t12_5", &"t12_6", &"t12_7", &"t12_8", &"t12_9", &"t12_10"],
		"weights": [1.0, 1.0, 1.0, 0.4, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8],
		"height_m": NATIVE,
		"note": "25-27 m; greens, one snow-dusted, and the autumn ramp",
	},
	{
		"slot": &"beech",
		# TREES 13 AND 14, THE ROUNDED BROADLEAVES. Only the green and
		# snow-dusted twins are live; the autumn ones are here at a low weight
		# because a broadleaf wood with a few turning trees in it is a wood,
		# and the crimson ones are parked at 0.
		"variants": [&"t13_1", &"t13_5", &"t14_1", &"t14_5",
			&"t13_2", &"t13_3", &"t14_2", &"t14_3",
			&"t13_4", &"t14_4"],
		"weights": [1.0, 0.5, 1.0, 0.5, 0.25, 0.25, 0.25, 0.25, 0.0, 0.0],
		"height_m": NATIVE,
		"note": "21-22 m; t13_4 and t14_4 are crimson, parked at 0",
	},
	{
		"slot": &"birch",
		# TREE 07, THE BRANCHING BROADLEAF. Birch is the pioneer - it grows
		# where light reaches the floor - and this is the one crown in the pack
		# with real branch structure rather than a solid mass, which is what a
		# tree standing on its own in the open should have.
		#
		# ONE VARIANT, AND THAT IS A THIN ROW. Birch is 103 trees of 28,383 on
		# seed 42 (0.4%), so one shape carries it for now; rotation and scale
		# jitter do the rest. If birch ever becomes a real share of the forest
		# this row needs company.
		"variants": [&"t07"],
		"weights": [1.0],
		"height_m": NATIVE,
		"note": "25.8 m; the only branching crown in the pack",
	},
	{
		"slot": &"snag",
		# TREE 11's TWO BARE SPIRES, AND THEY ARE A GIFT. `t11_6` and `t11_9`
		# are dead standing trunks with no canopy at all - exactly what a snag
		# is - and they arrive inside the conifer folder, so a snag among
		# spruces is the same tree with its needles gone. The stumps join them
		# because a stump is dead wood too, at a fifth the height.
		"variants": [&"t11_6", &"t11_9",
			&"t16_1", &"t16_2", &"t16_3", &"t16_4", &"t16_5", &"t16_6"],
		"weights": [1.0, 1.0, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
		"height_m": NATIVE,
		"note": "27 m spires and 2 m stumps; the pack's own dead wood",
	},
	{
		"slot": &"krummholz",
		# THE WEAKEST ROW IN THIS TABLE, AND IT IS FLAGGED RATHER THAN HIDDEN.
		#
		# Krummholz is a wind-flagged alpine cushion - knee-to-shoulder high,
		# spreading, alive. THE PACK HAS NOTHING LIKE IT. What it has at that
		# height is Tree 16, which is six CUT STUMPS: dead wood, sawn flat, 2 m
		# tall. They are the right SIZE and the wrong THING.
		#
		# They are used anyway, because the alternative is an alpine zone with
		# no trees in it at all, and a weathered woody stub above the treeline
		# is not a lie. But the honest reading is that the krummholz cushion
		# trees v1 Stage 3 authored is the one shape this epic loses outright,
		# and getting it back means new art rather than a table edit.
		#
		# Marcel: if this reads wrong on the treeline shots, set every weight
		# here to 0 and the alpine zone simply has no trees - which is a
		# defensible picture and a one-line change.
		"variants": [&"t16_1", &"t16_2", &"t16_3", &"t16_4", &"t16_5", &"t16_6"],
		"weights": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		"height_m": NATIVE,
		"note": "2 m stumps standing in for a cushion - see the note, this is the weak row",
	},
	{
		"slot": &"hero",
		# TREE 15, THE LARGEST CROWNS IN THE PACK - 166 x 193 x 173 voxels,
		# nearly three times Tree 13's volume. A hero has to read as a
		# DIFFERENT KIND of tree rather than as a big one (trees v1 Stage 3's
		# ruling, and the poster tradition's), and the widest crown in the
		# library standing alone in a meadow does exactly that.
		#
		# `t15_4` IS THE PINK ONE and `t15_6` the crimson: both parked at 0,
		# both loaded, both photographed. A single pink hero in a far meadow is
		# the cheapest strangeness this game will ever be able to buy, and it
		# is one number away.
		"variants": [&"t15_1", &"t15_5", &"t15_2", &"t15_3",
			&"t15_4", &"t15_6"],
		"weights": [1.0, 0.6, 0.3, 0.3, 0.0, 0.0],
		"height_m": NATIVE,
		"note": "24 m and the widest crowns here; t15_4 pink and t15_6 crimson parked at 0",
	},
]


## Variants deliberately NOT mapped, and why. The Stage 3 lint reads this, so a
## vox-backed variant that is neither used nor listed here is an error rather
## than an oversight.
const BENCHED := {
	# THE PLAN GOT THESE TWO WRONG, AND IT IS NOT THE PLAN'S FAULT.
	#
	# Decision 12 reads "sprawling bare 09/10 = the krummholz/snag register",
	# from shape statistics that said 163 voxels wide, 13,000 voxels, no dense
	# slice anywhere. Those statistics were computed from geometry that was
	# arriving WRONG - `vox_parse.py` was dropping MagicaVoxel's rotations, so
	# every one of Tree 09's twenty-four fronds lay flat at the top of its
	# trunk in overlapping pairs (Stage 2).
	#
	# With the rotations in they are unmistakable and they are COCONUT PALMS.
	# There is no reading of this world in which a coconut palm stands on an
	# alpine slope. Benched, not deleted: the Second Age's coast is a compass
	# direction the land descends toward (`docs/IDEAS.md`), and a palm is a
	# thing that grows where a coast is warm.
	&"t09": "coconut palms - wrong biome for this region; held for a warm coast",
	&"t10": "coconut palms, shorter - as t09",
	# THE TWO CRIMSON EXOTICS. `t05` is a dense crimson column and `t08` a thin
	# crimson spire, and neither has a green colourway anywhere in the pack -
	# they are crimson or they are nothing. That makes them pure
	# distance-strangeness rather than a colourway of something familiar, which
	# is a different decision from parking `t13_4` at weight 0, and Marcel's.
	&"t05": "crimson column, no green twin - strangeness candidate, not a forest tree",
	&"t08": "crimson spire, no green twin - as t05",
}


## WHICH SPECIES ARE DRAWN FROM THE LIBRARY RATHER THAN STAMPED AS BLOCKS.
##
## STAGE 4 IS DELIBERATELY ONE SPECIES, AND THE COEXISTENCE IS THE POINT. The
## plan asks for the valley broadleaf to be drawn from the library while the
## block stamp still runs for every other species - two systems in one world
## for one night, so a tour shows old and new side by side in the same frame
## and the register shift can be judged rather than argued.
##
## Stage 5 puts every slot in this list and the block stamper stops running at
## all; Stage 7 deletes it. Until then, a species not named here is a species
## `TreeSpecies` still draws out of `Block.LEAVES` and `Block.TRUNK`.
##
## THE PUBLIC BUILD PUTS NOTHING HERE, by construction rather than by a second
## list: `drawn_as_model()` is false whenever the library is not mounted, so
## the block stamper runs for everything and the world is exactly what it was.
## STAGE 5: ALL SEVEN. The block stamper now runs for nothing at all when the
## library is mounted, and Stage 7 deletes it.
const MODEL_SLOTS := [&"spruce", &"beech", &"larch", &"krummholz", &"birch",
	&"snag", &"hero"]


## Is this species drawn from the library tonight?
##
## False without a mount, false for a slot Stage 4 has not reached, and false
## for a slot whose whole row is parked at 0 - which are three different
## reasons for the same answer, and the caller wants the answer.
static func drawn_as_model(species: int, config: WorldgenConfig) -> bool:
	if not TreeModels.available():
		return false
	var slot := slot_of(species, config)
	if not MODEL_SLOTS.has(slot):
		return false
	_build()
	return float(_totals.get(slot, 0.0)) > 0.0


# --- Reading the table ------------------------------------------------------

static var _by_slot := {}
static var _totals := {}
static var _built := false


static func _build() -> void:
	if _built:
		return
	_built = true
	for row in ROWS:
		var slot: StringName = row["slot"]
		_by_slot[slot] = row
		var total := 0.0
		for w in row["weights"]:
			total += maxf(float(w), 0.0)
		_totals[slot] = total


## The row for one species slot, or {}.
static func row_for(slot: StringName) -> Dictionary:
	_build()
	return _by_slot.get(slot, {})


## Every slot this table knows.
static func slots() -> Array:
	_build()
	return _by_slot.keys()


## WHICH VARIANT STANDS AT THIS CELL. Hashed, never stored, never synced.
##
## `&""` when the species has no live variant - which is the public build
## (nothing is mounted), a species whose whole row is parked at 0, or a slot
## with no row at all. Every caller must handle it; it is not an error.
##
## ON ITS OWN SALT, in the 232+ range this epic was given, and clear of the
## `SALT_CLUMP` series `217 + key * 7919` as hard rule 2 requires.
const SALT_VARIANT := 232

## WHAT SEASON A VARIANT IS, read off the palette table rather than declared.
##
## A variant whose dominant canopy index maps into the AUTUMN ramp is an autumn
## tree; one that maps to SNOW is snow-dusted; everything else is green. That
## makes the season a FACT ABOUT THE COLOUR TABLE - so retuning `t13_2` from
## autumn to green by editing one cell also stops it being an autumn tree, and
## there is no second list to keep in step.
const TAG_GREEN := 0
const TAG_AUTUMN := 1
const TAG_SNOW := 2

static var _tags := {}

static func tag_of(variant: StringName) -> int:
	if _tags.has(variant):
		return int(_tags[variant])
	var d := TreeModels.info(variant)
	var tag := TAG_GREEN
	if not d.is_empty():
		var fam := TreePalette.family_of(variant,
			int(d.get("canopy_palette", 0)))
		if fam == &"SNOW":
			tag = TAG_SNOW
		elif String(fam).begins_with("AUTUMN"):
			tag = TAG_AUTUMN
	_tags[variant] = tag
	return tag


## THE SEASON AND ALTITUDE CHANNELS, decision 9's second half - and they are
## WEIGHTS, not tints.
##
## The plan asks for "seasonal/altitude tint hooks: instance colour multiplier
## driven from the mapping table's colourways", and the colourways turned out
## to be better than a multiplier. This pack ships each tree five times over in
## green, autumn, crimson, pink and snow - as SEPARATE PALETTES OVER ONE SHARED
## GEOMETRY - so autumn is not a tint applied to a green tree, it is the autumn
## tree, and it costs no new mesh because the twin already shares the binary.
##
## So a season is a bias on the ROLL rather than a colour on the instance: turn
## `tree_season` up and autumn-tagged variants win more of the table's weight;
## stand above the treeline and snow-tagged ones do. Zero new meshes, zero new
## draw calls, and the result is a real autumn tree rather than a green one
## painted orange - which is what a multiplier would have given, and what the
## per-instance channel is already spending itself on (the far grain and the
## backdrop convergence, both of which still apply on top).
##
## `snow` runs 0 to 1 and is how far above the treeline this tree stands;
## `season` is `WorldgenConfig.tree_season`, 0 for summer and 1 for autumn.
static func variant_at(slot: StringName, cell_x: int, cell_z: int,
		world_seed: int, snow := 0.0, season := 0.0) -> StringName:
	_build()
	var row: Dictionary = _by_slot.get(slot, {})
	if row.is_empty():
		return &""
	var variants: Array = row["variants"]
	var weights: Array = row["weights"]

	# THE BIASED WEIGHTS, computed per call rather than cached, because they
	# depend on where the tree stands. It is a loop over at most ten floats
	# against a placement decision that costs several noise samples.
	var live := PackedFloat32Array()
	live.resize(variants.size())
	var total := 0.0
	for i in variants.size():
		var w := maxf(float(weights[i]), 0.0)
		if w > 0.0:
			match tag_of(StringName(variants[i])):
				TAG_SNOW:
					# UP TO FOUR TIMES at the treeline and down to nothing well
					# below it, so a snow-dusted tree is a thing you climb to
					# rather than something scattered through the valley.
					w *= lerpf(0.15, 4.0, clampf(snow, 0.0, 1.0))
				TAG_AUTUMN:
					w *= lerpf(0.25, 4.0, clampf(season, 0.0, 1.0))
				_:
					# The greens give way rather than being deleted: a forest
					# that is entirely autumn is a texture, and one turning
					# tree in three is a season.
					w *= lerpf(1.0, 0.35, clampf(season, 0.0, 1.0))
		live[i] = w
		total += w
	if total <= 0.0:
		return &""

	# THE ROLL IS OVER THE LIVE TOTAL, so changing one variant's weight
	# reshuffles that species and nothing else - and setting a parked colourway
	# to a non-zero number does not renumber the variants beside it into
	# different trees.
	var roll := WorldHash.hash01(cell_x, cell_z, world_seed, SALT_VARIANT) * total
	var acc := 0.0
	for i in variants.size():
		acc += live[i]
		if roll < acc:
			return StringName(variants[i])
	# Floating-point tail: the last variant with a live weight.
	for i in range(variants.size() - 1, -1, -1):
		if live[i] > 0.0:
			return StringName(variants[i])
	return &""


## What this species should be drawn at, in metres. 0 means the model's own.
static func height_m(slot: StringName) -> float:
	var row := row_for(slot)
	return float(row.get("height_m", NATIVE)) if not row.is_empty() else NATIVE


## THE SLOT NAME FOR A `TreeSpecies` ID, which is the join between the two
## halves of this epic.
##
## Read out of `TreeSpecies.SPECIES[id]["name"]` rather than restated, so a
## species renamed there cannot silently stop finding its row here. That table
## keeps its names through Stage 7's deletion - only its SHAPES die.
static func slot_of(species: int, config: WorldgenConfig) -> StringName:
	var rows := TreeSpecies.table(config)
	if species < 0 or species >= rows.size():
		return &""
	return StringName((rows[species] as Dictionary)["name"])


## The variant for a placed tree, straight from what `decide()` returned.
## `&""` when there is nothing to draw - the public build, or a parked row.
static func variant_for(species: int, cell: Vector2i, world_seed: int,
		config: WorldgenConfig, snow := 0.0) -> StringName:
	return variant_at(slot_of(species, config), cell.x, cell.y, world_seed,
		snow, config.tree_season)


# --- The lint ---------------------------------------------------------------

## Check the table against the mounted library. Returns a list of complaints;
## empty is a pass.
##
## THREE THINGS, and the third is the one that stops this table rotting:
## every variant a row names must exist and have a palette row, no variant may
## be named twice inside one row, and **every variant in the library must be
## either used or explicitly benched.** A pack that gains a species folder
## should fail this rather than quietly not appearing in the world.
static func lint() -> Array:
	_build()
	var out := []
	if not TreeModels.available():
		return out
	var used := {}
	for row in ROWS:
		var slot: StringName = row["slot"]
		var variants: Array = row["variants"]
		var weights: Array = row["weights"]
		if variants.size() != weights.size():
			out.append("%s: %d variants but %d weights" % [
				slot, variants.size(), weights.size()])
			continue
		var seen := {}
		for i in variants.size():
			var v := StringName(variants[i])
			if seen.has(v):
				out.append("%s: %s named twice" % [slot, v])
			seen[v] = true
			used[v] = true
			if TreeModels.info(v).is_empty():
				out.append("%s: %s is not in the library" % [slot, v])
			elif not TreePalette.has(v):
				out.append("%s: %s has no palette row" % [slot, v])
		if float(_totals.get(slot, 0.0)) <= 0.0:
			out.append("%s: every weight is 0 - this species draws nothing" % slot)

	for v in TreeModels.variants():
		if used.has(v):
			continue
		var species := StringName(TreeModels.info(v).get("species", ""))
		if not BENCHED.has(species) and not BENCHED.has(v):
			out.append("%s is in the library, in no row, and not benched" % v)
	return out
