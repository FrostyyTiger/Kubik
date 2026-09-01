class_name TreePalette

## What colour a tree's voxels are, as a table the repo owns.
##
##
## THE ARTIST DECIDES WHERE THE CUBES GO. KUBIK DECIDES WHAT COLOUR THEY ARE.
##
## That is ruling 1 of trees v3 in one sentence, and this file is the half of
## it the game keeps. The baked library carries palette INDICES in its geometry
## and the pack's own RGB in its sidecars; nothing in this repo reads that RGB.
## An index arrives here, comes out an authored Kubik colour, and goes through
## `Look.to_wire()` at mesh assembly exactly as `FloraModels` does.
##
## So retuning a canopy green is editing a row of FAMILIES below. It is not
## re-running a Python tool, it is not re-baking 38 geometries, and it is not
## touching the assets repo at all.
##
##
## WHY THERE ARE FAMILIES AND NOT ONE COLOUR PER INDEX.
##
## Fifty-five variants carry about three hundred palette entries between them,
## and they are the same dozen decisions over and over - a dark conifer green,
## a lighter one, trunk brown, a deeper trunk brown, the autumn ramp. Naming
## the dozen and pointing three hundred indices at them means a retune is one
## edit rather than three hundred, and it means the world's greens are ONE
## FAMILY by construction rather than by discipline.
##
## The first pass points every family at `block.gd`'s existing leaf and bark
## rows wherever one exists, which is what keeps a purchased forest in the same
## palette as the terrain it stands on. Four families are new because the block
## world had nothing to be: the deep burnt orange at the bottom of the autumn
## ramp, a bark darker than `TRUNK`, and the two fantasy colourways.
##
##
## THE PACK'S COLOURS ARE NEON AND KUBIK'S ARE NOT, AND THAT IS THE MAPPING
## DOING ITS JOB. The pack's brightest autumn is `V 98, S 92`; `LEAVES_LARCH`
## is a muted gold. Pointing the first at the second desaturates a purchased
## tree into this world's own register, which is the whole reason the colour is
## mapped in the game instead of shipped from the tool.


## The authored colours, LINEAR, hex beside each - the same convention
## `Block.COLORS` and `FloraModels.COLORS` use, and for the same reason: Godot
## treats a vertex colour as already linear, so an sRGB hex fed straight in
## draws far brighter and far less saturated than intended. `Look.to_wire()` is
## applied once, at the push, by the mesh builder.
const FAMILIES := {
	# The canopy ramp, darkest first. Block.LEAVES, LEAVES_SPRUCE_B,
	# LEAVES_BEECH and LEAVES_BEECH_B, unchanged - so a purchased conifer and a
	# block-tree beech were the same green, right up until tonight deleted the
	# block-tree beech.
	&"CANOPY_A": Color(0.0284, 0.0782, 0.0482),   # #2F4F3E
	&"CANOPY_B": Color(0.0395, 0.1070, 0.0648),   # #385C48
	&"CANOPY_C": Color(0.0782, 0.1946, 0.0423),   # #4F7A3A
	&"CANOPY_D": Color(0.1144, 0.2542, 0.0612),   # #5F8A46

	# The autumn ramp. B and C are LEAVES_LARCH and LEAVES_LARCH_B - the warm
	# accent this world already had - and A is NEW, because the block palette
	# had no deep burnt orange under them and the pack's autumn ramp has three
	# rungs, not two.
	&"AUTUMN_A": Color(0.3813, 0.1245, 0.0137),   # #A6631F  new
	&"AUTUMN_B": Color(0.5089, 0.3185, 0.0704),   # #BD994B
	&"AUTUMN_C": Color(0.5841, 0.3864, 0.1095),   # #C9A75D

	# THE TWO FANTASY COLOURWAYS, present and inert. Decision 12 parks crimson
	# and pink at spawn weight 0 as distance-strangeness candidates: the
	# geometry exists, the colours exist, and no cell in the world picks one
	# until Marcel edits a weight. Both are new - nothing in a block world is
	# this colour, which is rather the point of a strange forest.
	&"CRIMSON_A": Color(0.1945, 0.0052, 0.0296),  # #7A1030  new
	&"CRIMSON_B": Color(0.3916, 0.0152, 0.0497),  # #A8213F  new
	&"PINK_A": Color(0.4565, 0.0886, 0.2747),     # #B4548F  new
	&"PINK_B": Color(0.7156, 0.2662, 0.5271),     # #DC8DC0  new

	# Block.SNOW itself, so a snow-dusted crown and the snow on the ridge
	# behind it are the same white.
	&"SNOW": Color(0.8879, 0.8714, 0.8070),       # #F2F0E8

	# The bark ramp. BARK is Block.TRUNK and BARK_LIGHT is FOREST_FLOOR, both
	# unchanged; BARK_DARK is NEW and is the most-used family in the whole
	# table, because this pack shades its trunks far darker than one block id
	# ever could.
	&"BARK": Color(0.1119, 0.0545, 0.0395),       # #5E4238
	&"BARK_DARK": Color(0.0481, 0.0252, 0.0177),  # #3E2C24  new
	&"BARK_LIGHT": Color(0.1620, 0.0976, 0.0467), # #70583D
	# TRUNK_DEAD, the weathered snag grey. NO ROW IN THE GENERATED TABLE POINTS
	# HERE YET and it is defined anyway: it is where a variant goes when Stage
	# 3 benches one into the snag register, and a family that has to be
	# invented at that moment is a family somebody will invent differently.
	&"BARK_DEAD": Color(0.3419, 0.3185, 0.2789),  # #9E9990
}


## Which family every variant's every palette index belongs to.
##
## GENERATED, THEN AUTHORED. `Kubik-assets/tools/trees_palette_table.py`
## printed this block from the baked sidecars and it is checked in as data:
## edit a cell and that variant's colour moves, with no tool, no re-bake and
## no assets-repo commit. Regenerate it only if the library is re-baked.
##
## KEYED ON THE VARIANT, NOT ON THE SPECIES, and that is a finding rather than
## a preference - the plan asks for "each species' palette indices" and a
## species' indices are not stable across its own colourways. Tree 13's index 3
## is green foliage on `t13_1`, autumn on `t13_2` and crimson on `t13_4`.
## A colourway IS a palette, so the palette table is per file.
##
## An index missing from a row falls back to BARK_DARK rather than to magenta:
## a tree with one wrongly-dark voxel is a blemish, and a tree with a magenta
## one is a bug report. `--trees` in the gallery prints any that miss.
const PACK_FAMILIES := {
	&"t05": {1: &"SNOW", 2: &"BARK_LIGHT", 3: &"CRIMSON_B", 4: &"CRIMSON_A", 5: &"CRIMSON_A", 6: &"BARK_DARK", 7: &"BARK_DARK"},
	&"t07": {1: &"BARK_LIGHT", 2: &"BARK_LIGHT", 3: &"CANOPY_C", 4: &"CANOPY_B", 5: &"BARK_DARK", 6: &"CANOPY_B", 7: &"BARK_DARK"},
	&"t08": {1: &"SNOW", 2: &"BARK_LIGHT", 3: &"CRIMSON_B", 4: &"CRIMSON_A", 5: &"CRIMSON_A", 6: &"BARK_DARK", 7: &"BARK_DARK"},
	&"t09_1": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"BARK", 4: &"BARK", 5: &"CANOPY_B"},
	&"t09_2": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CRIMSON_A", 4: &"CRIMSON_A", 5: &"BARK", 6: &"BARK", 7: &"CRIMSON_A", 8: &"CANOPY_B"},
	&"t09_3": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CRIMSON_A", 4: &"CRIMSON_A", 5: &"BARK", 6: &"BARK", 7: &"CRIMSON_A", 8: &"CANOPY_B"},
	&"t09_4": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CRIMSON_A", 4: &"CRIMSON_A", 5: &"BARK", 6: &"BARK", 7: &"CRIMSON_A", 8: &"CANOPY_B"},
	&"t10_1": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CANOPY_D", 4: &"CANOPY_D", 5: &"CANOPY_D", 6: &"CRIMSON_A", 7: &"BARK_DARK", 8: &"CRIMSON_A", 9: &"BARK", 10: &"BARK", 11: &"CRIMSON_A"},
	&"t10_2": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CANOPY_D", 4: &"CANOPY_D", 5: &"CANOPY_D", 6: &"CRIMSON_A", 7: &"BARK_DARK", 8: &"CRIMSON_A", 9: &"BARK", 10: &"BARK", 11: &"CRIMSON_A"},
	&"t10_3": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CANOPY_D", 4: &"CANOPY_D", 5: &"CANOPY_D", 6: &"CRIMSON_A", 7: &"BARK_DARK", 8: &"CRIMSON_A", 9: &"BARK", 10: &"BARK", 11: &"CRIMSON_A"},
	&"t10_4": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CANOPY_D", 4: &"CANOPY_D", 5: &"CANOPY_D", 6: &"BARK_DARK", 7: &"BARK", 8: &"BARK"},
	&"t10_5": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CANOPY_D", 4: &"CANOPY_D", 5: &"CANOPY_D", 6: &"BARK_DARK", 7: &"BARK", 8: &"BARK"},
	&"t10_6": {1: &"CANOPY_C", 2: &"CANOPY_D", 3: &"CANOPY_D", 4: &"CANOPY_D", 5: &"CANOPY_D", 6: &"BARK_DARK", 7: &"BARK", 8: &"BARK"},
	&"t11_1": {31: &"BARK_DARK", 32: &"BARK_DARK", 81: &"CANOPY_A", 82: &"CANOPY_A", 84: &"CANOPY_B", 86: &"CANOPY_C"},
	&"t11_2": {31: &"BARK_DARK", 32: &"BARK_DARK", 81: &"CANOPY_A", 82: &"CANOPY_A", 84: &"CANOPY_B", 86: &"CANOPY_C"},
	&"t11_3": {31: &"BARK_DARK", 32: &"BARK_DARK", 81: &"CANOPY_A", 82: &"CANOPY_A", 84: &"CANOPY_B", 86: &"CANOPY_C"},
	&"t11_4": {1: &"CANOPY_C", 2: &"BARK_DARK", 3: &"BARK_DARK", 4: &"CANOPY_A", 5: &"CANOPY_A", 6: &"CANOPY_A", 7: &"CANOPY_B"},
	&"t11_5": {1: &"CANOPY_C", 2: &"BARK_DARK", 3: &"BARK_DARK", 4: &"CANOPY_A", 5: &"CANOPY_A", 6: &"CANOPY_A", 7: &"CANOPY_B"},
	&"t11_6": {31: &"BARK_DARK", 32: &"BARK_DARK"},
	&"t11_7": {1: &"SNOW", 2: &"CANOPY_C", 3: &"BARK_DARK", 4: &"BARK_DARK", 5: &"CANOPY_A", 6: &"CANOPY_A", 7: &"CANOPY_A", 8: &"CANOPY_B"},
	&"t11_8": {1: &"SNOW", 2: &"CANOPY_C", 3: &"BARK_DARK", 4: &"BARK_DARK", 5: &"CANOPY_A", 6: &"CANOPY_A", 7: &"CANOPY_A", 8: &"CANOPY_B"},
	&"t11_9": {13: &"SNOW", 31: &"BARK_DARK", 32: &"BARK_DARK"},
	&"t12_1": {31: &"BARK_DARK", 32: &"BARK_DARK", 84: &"CANOPY_B", 85: &"CANOPY_B", 86: &"CANOPY_C"},
	&"t12_10": {1: &"AUTUMN_C", 2: &"AUTUMN_A", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t12_2": {31: &"BARK_DARK", 32: &"BARK_DARK", 84: &"CANOPY_B", 85: &"CANOPY_B", 86: &"CANOPY_C"},
	&"t12_3": {31: &"BARK_DARK", 32: &"BARK_DARK", 84: &"CANOPY_B", 85: &"CANOPY_B", 86: &"CANOPY_C"},
	&"t12_4": {13: &"SNOW", 31: &"BARK_DARK", 32: &"BARK_DARK", 84: &"CANOPY_B", 85: &"CANOPY_B", 86: &"CANOPY_C"},
	&"t12_5": {1: &"AUTUMN_C", 2: &"AUTUMN_C", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t12_6": {1: &"AUTUMN_C", 2: &"AUTUMN_A", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t12_7": {1: &"AUTUMN_C", 2: &"AUTUMN_A", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t12_8": {1: &"AUTUMN_C", 2: &"AUTUMN_C", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t12_9": {1: &"AUTUMN_C", 2: &"AUTUMN_C", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t13_1": {1: &"CANOPY_C", 2: &"CANOPY_B", 3: &"BARK_DARK", 4: &"BARK_DARK", 5: &"CANOPY_B"},
	&"t13_2": {1: &"AUTUMN_C", 2: &"AUTUMN_C", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t13_3": {1: &"AUTUMN_C", 2: &"AUTUMN_A", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t13_4": {1: &"CRIMSON_B", 2: &"CRIMSON_A", 3: &"CRIMSON_A", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t13_5": {1: &"SNOW", 2: &"CANOPY_C", 3: &"CANOPY_B", 4: &"BARK_DARK", 5: &"BARK_DARK", 6: &"CANOPY_B"},
	&"t14_1": {1: &"CANOPY_C", 2: &"CANOPY_B", 3: &"BARK_DARK", 4: &"BARK_DARK", 5: &"CANOPY_B"},
	&"t14_2": {1: &"AUTUMN_C", 2: &"AUTUMN_C", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t14_3": {1: &"AUTUMN_C", 2: &"AUTUMN_A", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t14_4": {1: &"CRIMSON_B", 2: &"CRIMSON_A", 3: &"CRIMSON_A", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t14_5": {1: &"SNOW", 2: &"CANOPY_C", 3: &"CANOPY_B", 4: &"BARK_DARK", 5: &"BARK_DARK", 6: &"CANOPY_B"},
	&"t15_1": {31: &"BARK_DARK", 32: &"BARK_DARK", 84: &"CANOPY_B", 85: &"CANOPY_B", 86: &"CANOPY_C"},
	&"t15_2": {1: &"AUTUMN_C", 2: &"AUTUMN_C", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t15_3": {1: &"AUTUMN_C", 2: &"AUTUMN_A", 3: &"AUTUMN_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t15_4": {1: &"PINK_A", 2: &"PINK_A", 3: &"PINK_B", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t15_5": {1: &"SNOW", 2: &"CANOPY_C", 3: &"CANOPY_B", 4: &"BARK_DARK", 5: &"BARK_DARK", 6: &"CANOPY_B"},
	&"t15_6": {1: &"CRIMSON_B", 2: &"CRIMSON_A", 3: &"CRIMSON_A", 4: &"BARK_DARK", 5: &"BARK_DARK"},
	&"t16_1": {30: &"BARK", 31: &"BARK_DARK", 32: &"BARK_DARK"},
	&"t16_2": {31: &"BARK_DARK", 32: &"BARK_DARK"},
	&"t16_3": {29: &"BARK", 30: &"BARK", 31: &"BARK_DARK"},
	&"t16_4": {1: &"BARK_DARK", 13: &"SNOW", 121: &"BARK", 123: &"BARK_LIGHT"},
	&"t16_5": {31: &"BARK_DARK", 32: &"BARK_DARK"},
	&"t16_6": {1: &"BARK_DARK", 13: &"BARK_LIGHT", 219: &"BARK_LIGHT", 221: &"BARK_LIGHT"},
	&"t5_5": {13: &"SNOW", 31: &"BARK_DARK", 32: &"BARK_DARK", 84: &"CANOPY_B", 85: &"CANOPY_B", 86: &"CANOPY_C"},
}


const FALLBACK := &"BARK_DARK"


## The authored colour for one variant's palette index, LINEAR.
static func color_of(variant: StringName, index: int) -> Color:
	var row: Dictionary = PACK_FAMILIES.get(variant, {})
	var family: StringName = row.get(index, FALLBACK)
	return FAMILIES.get(family, FAMILIES[FALLBACK])


## The whole of one variant's mapping as a lookup array, 256 entries, LINEAR.
##
## Built once per variant at mesh assembly, because the alternative is a
## dictionary lookup per QUAD and a big tree is three thousand of them.
static func table_for(variant: StringName) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(256)
	var fallback: Color = FAMILIES[FALLBACK]
	out.fill(fallback)
	var row: Dictionary = PACK_FAMILIES.get(variant, {})
	for index in row:
		out[int(index) & 0xFF] = FAMILIES.get(row[index], fallback)
	return out


## Does this variant have a mapping at all? The gallery's lint, and the
## Stage 3 table's.
static func has(variant: StringName) -> bool:
	return PACK_FAMILIES.has(variant)


## Every variant this table knows, for the lint and the gallery.
static func variants() -> Array:
	return PACK_FAMILIES.keys()
