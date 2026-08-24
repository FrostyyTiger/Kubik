class_name TreePlacement

## WHERE a tree goes, as distinct from what it is.
##
## `tree_species.gd` owns the shapes. This owns the decision: which candidate
## cells grow something, which species stands there, and how the answer is kept
## identical on two machines that have never spoken to each other.
##
##
## THE CANDIDATE LATTICE.
##
## Trees are not scattered continuously. The world is divided into cells of
## `tree_cell_blocks`, each cell is one candidate, and a candidate either grows
## a tree or does not. That is what makes the whole thing addressable: a tree
## is identified by its cell's integer coordinates, every parameter it has is
## hashed from them, and no part of the answer depends on which chunk asked or
## in what order.
##
##
## WHY EVERY CHUNK SCANS MORE CELLS THAN IT CONTAINS.
##
## A tree rooted in one cell reaches several blocks sideways, so it crosses
## into chunks that do not contain its trunk. If a chunk only drew the trees
## rooted inside itself, every tree near a boundary would be sliced off - and
## which slice you saw would depend on which chunks happened to be loaded.
##
## So each chunk iterates candidates over a region wider than itself by the
## furthest a crown can spread, draws all of them, and lets the writer discard
## what falls outside. The margin is DERIVED from the species table's widest
## crown, never typed, so adding a wider species cannot silently start clipping.
##
## `_test_tree_borders` in the self-test suite is the proof, and it is not
## decorative: it compares a chunk generated normally against the same chunk
## with a deliberately over-wide scan, and any tree the narrow scan missed
## shows up as a differing voxel.


## Stamp every tree that reaches into this chunk.
##
## The one entry point TerrainGenerator._place_trees() calls.
static func stamp_chunk(chunk: Chunk, gen: TerrainGenerator) -> void:
	var config := gen.config
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		return

	var origin := chunk.origin()
	var margin := TreeSpecies.max_reach(config)

	var writer := TreeSpecies.ChunkWriter.new()
	writer.bind(chunk)

	var cx0 := Chunk.floor_div(origin.x - margin, cell)
	var cx1 := Chunk.floor_div(origin.x + Chunk.SIZE - 1 + margin, cell)
	var cz0 := Chunk.floor_div(origin.z - margin, cell)
	var cz1 := Chunk.floor_div(origin.z + Chunk.SIZE - 1 + margin, cell)

	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			stamp_cell(writer, gen, cx, cz)


## Draw one candidate cell's tree, if it has one.
##
## Called by every chunk the tree reaches, and MUST produce the same tree for
## all of them - which is why nothing in here reads the chunk, the writer, or
## anything else that differs between those calls.
static func stamp_cell(writer, gen: TerrainGenerator, cell_x: int, cell_z: int) -> void:
	var config := gen.config
	var bx: int = cell_x * config.tree_cell_blocks
	var bz: int = cell_z * config.tree_cell_blocks

	var surface := gen.surface_at(float(bx), float(bz))
	if not accepts(gen, cell_x, cell_z, surface):
		return

	var species := species_at(gen, cell_x, cell_z, surface)
	var params := TreeSpecies.params_for(species, cell_x, cell_z, gen.world_seed, config)
	# floor(), not round(): the block at altitude N occupies the space from N to
	# N+1, so a surface at 40.7 means block 40 is the top solid one and the
	# trunk starts at 41.
	TreeSpecies.draw(writer, species, bx, int(floor(surface)), bz, params, config)


## Does a tree stand at this candidate?
##
## Hashed from the cell's own coordinates, never drawn from a stream, so the
## answer does not depend on how many candidates were considered before it.
##
## STAGE 4 REPLACES THE BODY with the product of grove, glade, slope, bench and
## spawn terms. It is a separate function from the start so that the probe and
## the screenshot tour can ask the question without restating it, and so that
## the day the formula arrives nothing above this line changes.
static func accepts(gen: TerrainGenerator, cell_x: int, cell_z: int,
		surface: float) -> bool:
	var bx: int = cell_x * gen.config.tree_cell_blocks
	var bz: int = cell_z * gen.config.tree_cell_blocks
	var chance := gen.tree_probability_at(
		surface, gen.zone_jitter_at(float(bx), float(bz)))
	if chance <= 0.0:
		return false
	return WorldHash.hash01(cell_x, cell_z, gen.world_seed,
		TerrainGenerator.SALT_TREE) < chance


## Which species stands at an accepted candidate.
##
## One species until Stage 3, and going through this function anyway: the
## weight table that replaces it depends on altitude within the forest band, on
## zone and on wildness, and every caller that wants to know which species is
## where - the probe, the gallery's world counterpart, the far-tree ring - can
## then ask the same question the world asked.
static func species_at(_gen: TerrainGenerator, _cell_x: int, _cell_z: int,
		_surface: float) -> int:
	return TreeSpecies.SPRUCE
