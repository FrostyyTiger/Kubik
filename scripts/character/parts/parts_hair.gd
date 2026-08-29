class_name PartsHair

## Which hair and which beard each race's options mean.
##
## HAND-WRITTEN AND PERMANENT, unlike everything else that used to be in this
## directory. The geometry left for `assets/characters/parts/hair.json` in
## parts-data v1; what stayed is the part of the file no JSON can hold - two
## positional tables and the lookup that reads them.
##
## Indexed by race and then by the option index in the def. An empty entry
## means "this option adds no geometry", which is what the human's "none"
## beard is. Rig treats a hair or beard bone with no part as an optional bone
## and says nothing about it.
##
## THE ORDER HERE IS THE ORDER IN Races.HAIR_OPTIONS AND Races.BEARD_OPTIONS.
## The index is one byte on the wire and one number in a save file, so the two
## lists have to agree; the self-test walks both and would catch a slip.
##
## The names are keys into the `hair` module - and the fact that they are
## still hard-coded three-to-a-race is the honest limit of this refactor. When
## hair becomes something a director or an item hands out, these two tables
## follow the parts into data.

const HAIR := [
	["human_hair_short", "human_hair_long", "human_hair_tied"],
	["elf_hair_short", "elf_hair_long", "elf_hair_braided"],
	["dwarf_hair_short", "dwarf_hair_long", "dwarf_hair_braided"],
	["lizard_crest_low", "lizard_crest_tall", "lizard_frill"],
]

const BEARD := [
	["", "human_beard_short", "human_beard_full"],
	[],
	["dwarf_beard_short", "dwarf_beard_full", "dwarf_beard_forked"],
	[],
]


## The hair or crest part for this race and option, or null.
static func hair_part(race: int, index: int):
	return _lookup(HAIR, race, index)


static func beard_part(race: int, index: int):
	return _lookup(BEARD, race, index)


## NULL, NOT AN EMPTY DICTIONARY, for every way of asking for nothing - an
## out-of-range index, a race with no beards, the human's "none". Callers
## test `!= null` and always have.
static func _lookup(table: Array, race: int, index: int):
	var options: Array = table[clampi(race, 0, table.size() - 1)]
	if options.is_empty() or index < 0 or index >= options.size():
		return null
	var part_name: String = options[index]
	if part_name.is_empty():
		return null
	var part = PartsData.module("hair").get(part_name)
	if part == null:
		push_error("[PartsHair] no part '%s' in the hair module" % part_name)
	return part
