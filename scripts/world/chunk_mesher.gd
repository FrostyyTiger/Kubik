class_name ChunkMesher

## Turns a Chunk's voxels into mesh arrays.
##
## COLOUR COMES FROM THE VERTICES, NOT A TEXTURE. The world is read at a
## distance - the whole design is sold on being able to tell a meadow from a
## forest from a snowfield across a valley - and flat saturated colour reads
## further and more clearly than any 16x16 texture would.
##
## assets/textures/block_placeholder.png and its committed .import settings are
## unused as of Stage 3. They are left in the repo rather than deleted, because
## a texture atlas with per-face UVs is still on the roadmap and the import
## settings were the fiddly part to get right.
##
##
## GREEDY MESHING
##
## The naive version emitted one quad per exposed block face. It was easy to
## verify and it was measured, on this world, at 16.7 ms per chunk against
## 1.9 ms to generate the voxels in the first place - meshing dominated 9 to 1,
## which is what justified replacing it rather than assuming it needed to be.
##
## Greedy meshing merges adjacent faces that share a plane, a direction and a
## colour into one large quad. A flat meadow chunk goes from 256 top quads to
## 1. The saving is not in the triangle count so much as in the work: the naive
## mesher's time went almost entirely into pushing four vertices per face into
## packed arrays, and merging removes most of those pushes.
##
## The algorithm sweeps the chunk three times, once per axis. For each of the
## 17 planes between (and either side of) the 16 layers of blocks, it builds a
## 16x16 MASK of which faces are visible there and what colour they are, then
## repeatedly takes the largest rectangle of equal values out of the mask.
## Encoding the direction as the SIGN of the mask value is what lets one pass
## handle both facings of a plane at once.
##
##
## BAKED AMBIENT OCCLUSION, AND WHY IT FIGHTS GREEDY MESHING
##
## A greedy-meshed hillside in flat vertex colour carries no edge information
## at all: an entire slope is literally one colour, so the eye has nothing to
## grab and the world reads as smooth shapes rather than as stacked cubes.
## Corner AO is the standard fix and it is what makes a voxel world look like
## one - each vertex is darkened by how many of the three blocks meeting at
## that corner (two sides and the diagonal) are solid.
##
## The two techniques are in direct conflict. Merging assumes every cell in a
## quad looks identical; AO makes cells next to a wall differ from cells in the
## open. So the AO code joins the mask, and a run only merges while BOTH the
## block id and the four corner AO values repeat.
##
## That is not merely conservative, it is exactly right, and the reason is
## worth stating because it is what makes the interpolation across a merged
## quad correct rather than approximate. Two side-by-side cells SHARE two
## lattice corners, and a shared corner is computed from the same three blocks
## by both, so it gets the same value in both. If their AO codes are equal,
## then each cell's leading corner equals its own trailing corner - the code is
## constant along the run - and a linear interpolation across the merged quad
## reproduces every cell it swallowed. A run that would have needed a gradient
## cannot form in the first place, because its codes would differ and the merge
## would stop.

## For each sweep axis d, which axes play the roles of u and v.
##
## The triples are chosen so that (u, v, d) is right-handed - u cross v == d.
## That is not cosmetic: the winding order of the emitted quads is derived from
## it, and a left-handed triple silently turns the world inside out.
const AXIS_U := [1, 2, 0]   # d = X -> u = Y ; d = Y -> u = Z ; d = Z -> u = X
const AXIS_V := [2, 0, 1]   # d = X -> v = Z ; d = Y -> v = X ; d = Z -> v = Y

## Four corner AO levels of 3 (fully open), packed two bits each. The value a
## face carries when AO is switched off, so the merge test behaves identically
## to the pre-AO mesher rather than needing a second code path.
const AO_OPEN := 0xFF

## Corner order inside a packed AO code: index = su + sv * 2, where su and sv
## are 0 for the u0/v0 side of the cell and 1 for the u1/v1 side.
##
## CANONICAL, and deliberately NOT the order the quad's vertices come out in -
## that order differs between the two facings, and a code whose meaning
## depended on the facing could not be compared between neighbouring cells.
const AO_CORNER_U0V0 := 0
const AO_CORNER_U1V0 := 1
const AO_CORNER_U0V1 := 2
const AO_CORNER_U1V1 := 3

# --- The backend, and the seam it crosses (mesher v1) -------------------------
#
# THE MESHER DECIDES HOW A CHUNK LOOKS, NEVER WHAT IT IS (CLAUDE.md, engine
# rules). That sentence is what makes this crossing cheap where the height
# map's was expensive: a disagreement between the two meshers draws a slightly
# different face, and it cannot move the ground, the spawn or a lake. The
# parity gate is still exact - see Q8 - but it is exact because it can be, not
# because two players would otherwise walk in different worlds.
#
# DATA IN, ARRAYS OUT (Q1). `KubikChunkMesher` never sees a Chunk, a
# TerrainGenerator, a WorldgenConfig or a Look. It is handed 4,096 voxel bytes,
# whatever the six faces need to answer for the blocks just outside them, and
# a palette; it hands back four packed arrays. It never calls back into
# GDScript during a build.
#
# COLOUR CROSSES AS A TABLE, NOT AS ARITHMETIC (Q3). Every Windows parity
# failure this project has had - 15, then 7, then today's 1 - was gcc and MSVC
# rounding the last bit of a colour differently. So GDScript computes every
# colour the mesher can ever emit, once per world, and the C++ colour path is
# an INDEX. There is no float arithmetic on a colour on the other side of the
# seam and therefore nothing for two compilers to disagree about.

const CPP_CLASS := "KubikChunkMesher"

## "cpp", "gdscript", or "" before the question has been asked.
##
## A STATIC AND NOT A CONFIG FIELD (Q6). `worldgen_config.gd` belongs to the
## other lane this month, and a mesher switch has no business on the wire in
## any case: it changes how long a chunk takes to build and never what is in
## it, so two machines at different settings still build the same world.
static var backend := ""

## Why the twin is running, when it is. Shown on the F3 line so "the C++ is off"
## and "the C++ is not there" are never the same message.
static var _backend_note := ""

## The setup arguments, computed once per (block_size, ao_strength) pair and
## shared by every worker. Guarded because column jobs run on the pool and the
## first one to arrive builds the table.
static var _setup_key := ""
static var _setup_args := {}
static var _backend_lock := Mutex.new()


## Is the compiled class there, loadable, AND does it actually mesh?
##
## THREE QUESTIONS AND NOT ONE. `ClassDB.class_exists` is true for a stub, and
## through Stage 2 of mesher v1 this class WAS a stub that returned an empty
## Dictionary - so a check that stopped at the name would have switched the
## whole streaming path onto a mesher that draws nothing. The probe below meshes
## one solid block in an otherwise empty chunk and insists on getting a cube
## back, which is the smallest thing that cannot pass by accident.
static func class_present() -> bool:
	if not ClassDB.class_exists(CPP_CLASS):
		return false
	if not ClassDB.class_has_method(CPP_CLASS, "build"):
		return false
	var impl: Object = ClassDB.instantiate(CPP_CLASS)
	if impl == null:
		return false
	if String(impl.ping()) == "":
		return false
	impl.setup({
		"block_size": 1.0,
		"ao_strength": 0.0,
		"palette": wire_palette(0.0),
	})
	if not bool(impl.is_ready()):
		return false
	var voxels := PackedByteArray()
	voxels.resize(Chunk.VOLUME)
	voxels[Chunk.index(8, 8, 8)] = Block.STONE
	# Nothing solid anywhere outside: every strip says the ground stops far
	# below this chunk, so the single block is a free-standing cube.
	var empty_col := PackedInt32Array()
	empty_col.resize(Chunk.SIZE_SQ)
	empty_col.fill(-1_000_000)
	var empty_row := PackedInt32Array()
	empty_row.resize(Chunk.SIZE)
	empty_row.fill(-1_000_000)
	var got = impl.build({
		"voxels": voxels,
		"origin_y": 0,
		"has_solid": true,
		"has_air": true,
		"top_col": empty_col,
		"top_px": empty_row, "top_nx": empty_row,
		"top_pz": empty_row, "top_nz": empty_row,
	})
	if not (got is Dictionary):
		return false
	return int((got as Dictionary).get("quads", 0)) == 6


## `cpp` or `gdscript`, decided once and remembered.
static func resolve_backend() -> String:
	if backend != "":
		return backend
	_backend_lock.lock()
	if backend == "":
		if "gdscript" in _mesher_override():
			backend = "gdscript"
			_backend_note = "forced by --mesher gdscript"
		elif class_present():
			backend = "cpp"
			_backend_note = ""
		else:
			backend = "gdscript"
			# TWO DIFFERENT FACTS AND THE F3 LINE SAYS WHICH. A checkout with
			# no compiler has no class at all; a checkout mid-port has one that
			# does not mesh yet. Reading "no c++ library" on the second would
			# send somebody to rebuild a library that is already there.
			_backend_note = "c++ mesher present but not meshing" \
				if ClassDB.class_exists(CPP_CLASS) else "no c++ library"
	_backend_lock.unlock()
	return backend


## `--mesher gdscript` on the command line, after the `--`. Q6: no config knob,
## no F4 row, nothing saved to `user://` - a switch that exists to take one
## measurement should not be able to survive the run that took it.
static func _mesher_override() -> String:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--mesher")
	if i < 0 or i + 1 >= argv.size():
		return ""
	return String(argv[i + 1]).strip_edges().to_lower()


## What the F3 line says.
static func backend_name() -> String:
	var name := resolve_backend()
	if _backend_note != "":
		return "%s (%s)" % [name, _backend_note]
	return name


## The self-test and the bench flip this directly; nothing else may.
static func force_backend(name: String) -> void:
	_backend_lock.lock()
	backend = name
	_backend_note = "forced by the test harness" if name == "gdscript" else ""
	_backend_lock.unlock()


## EVERY COLOUR THE MESHER CAN EVER EMIT, computed once, in GDScript (Q3).
##
## `palette[id * 4 + level]` is `Look.to_wire(Block.color_of(id) * shade)` with
## `shade = 1.0 - ao_strength * (1.0 - level / 3.0)` - the twin's own
## expression, lifted out of `_emit_quad` unchanged, so both meshers push the
## identical float.
##
## 256 IDS AND NOT 24. The plan's table was the palette's own length; this is
## the whole byte range, because `Block.color_of()` answers MAGENTA outside the
## palette and magenta in a screenshot is the gate that catches an index bug in
## the port. A table that stopped at 24 would have made that case an
## out-of-range read on the other side of the seam instead of the loud pink
## face it is supposed to be. The extra 928 entries cost one loop, once.
const PALETTE_IDS := 256
const PALETTE_LEVELS := 4


static func wire_palette(ao_strength: float) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(PALETTE_IDS * PALETTE_LEVELS)
	for id in PALETTE_IDS:
		var color := Block.color_of(id)
		for level in PALETTE_LEVELS:
			var shade := 1.0 - ao_strength * (1.0 - _ao_curve(level))
			out[id * PALETTE_LEVELS + level] = Look.to_wire(Color(
				color.r * shade, color.g * shade, color.b * shade, color.a))
	return out


## What `setup()` is given, once per world. Cached on the two values it depends
## on, so the self-test moving `ao_strength` rebuilds the table and the
## streaming path never does.
static func setup_args(config: WorldgenConfig) -> Dictionary:
	var key := "%.9f|%.9f" % [config.block_size, config.ao_strength]
	_backend_lock.lock()
	if key != _setup_key:
		_setup_args = {
			"block_size": config.block_size,
			"ao_strength": config.ao_strength,
			"palette": wire_palette(config.ao_strength),
		}
		_setup_key = key
	var out: Dictionary = _setup_args
	_backend_lock.unlock()
	return out


## A configured C++ mesher, or null.
##
## ONE PER COLUMN JOB, AND THAT IS DELIBERATE. Sharing a single instance across
## the pool would be sharing a GDExtension object between threads for no gain:
## `setup()` stores three values and takes a REFERENCE to the palette - a
## PackedColorArray is copy-on-write - so a fresh instance per job costs one
## small allocation and copies nothing. The alternative is a lock on the hot
## path, or a race nobody would reproduce.
static func new_cpp_mesher(config: WorldgenConfig) -> Object:
	if resolve_backend() != "cpp":
		return null
	var impl: Object = ClassDB.instantiate(CPP_CLASS)
	if impl == null:
		return null
	impl.setup(setup_args(config))
	if not bool(impl.is_ready()):
		return null
	return impl


## The AO shell is the chunk plus one block on every side: 18 x 18 x 18 = 5,832
## solidity bytes. Every coordinate either mesher ever reads is inside it - the
## mask asks one step outside a face, and a corner asks one step diagonally -
## so a build handed a shell needs nothing else.
const SHELL := Chunk.SIZE + 2
const SHELL_SQ := SHELL * SHELL
const SHELL_VOLUME := SHELL * SHELL * SHELL


static func shell_index(x: int, y: int, z: int) -> int:
	return (x + 1) + (z + 1) * SHELL + (y + 1) * SHELL_SQ


## THE BORDER FORM THE CALLABLE PATH PRODUCES: one shell, and nothing else.
##
## The Callable answers "is this world block solid" and cannot be asked for a
## surface altitude, so the compact strips `ColumnJob` hands over are not
## available here. A shell is the honest translation - it is exactly the set of
## blocks a build may read - and it costs 1,736 Callable invocations for the
## rim, the interior coming straight off the chunk's own bytes.
##
## THIS IS A COLD PATH AND IS MEANT TO BE. The edit path meshes one chunk per
## broken block, and the self-test meshes a few dozen; the streaming path goes
## through `ColumnJob.borders_for()` instead, which reads a neighbour chunk's
## bytes by reference and answers the rest with one integer per column.
static func borders_from_callable(chunk: Chunk, solid_outside: Callable) -> Dictionary:
	var origin := chunk.origin()
	var shell := PackedByteArray()
	shell.resize(SHELL_VOLUME)
	for y in range(-1, Chunk.SIZE + 1):
		for z in range(-1, Chunk.SIZE + 1):
			for x in range(-1, Chunk.SIZE + 1):
				var solid := false
				if Chunk.in_bounds(x, y, z):
					solid = chunk.voxels[Chunk.index(x, y, z)] != Block.AIR
				else:
					solid = solid_outside.call(
						origin.x + x, origin.y + y, origin.z + z)
				shell[shell_index(x, y, z)] = 1 if solid else 0
	return {
		"voxels": chunk.voxels,
		"origin_y": origin.y,
		"has_solid": chunk.has_solid,
		"has_air": chunk.has_air,
		"shell": shell,
	}


## The reverse trip: a Callable over a border Dictionary, so the twin can be
## driven from borders somebody else built and its signature never has to change
## (Stage 3.1). Only ever used where a caller has borders and no Callable.
static func solid_from_borders(chunk: Chunk, borders: Dictionary) -> Callable:
	var origin := chunk.origin()
	return func(wx: int, wy: int, wz: int) -> bool:
		var x := wx - origin.x
		var y := wy - origin.y
		var z := wz - origin.z
		if borders.has("shell"):
			var shell: PackedByteArray = borders["shell"]
			return shell[shell_index(x, y, z)] != 0
		var face := ""
		var ni := 0
		if x >= Chunk.SIZE:
			face = "px"
			ni = Chunk.index(0, y, z)
		elif x < 0:
			face = "nx"
			ni = Chunk.index(Chunk.SIZE - 1, y, z)
		elif y >= Chunk.SIZE:
			face = "py"
			ni = Chunk.index(x, 0, z)
		elif y < 0:
			face = "ny"
			ni = Chunk.index(x, Chunk.SIZE - 1, z)
		elif z >= Chunk.SIZE:
			face = "pz"
			ni = Chunk.index(x, y, 0)
		elif z < 0:
			face = "nz"
			ni = Chunk.index(x, y, Chunk.SIZE - 1)
		else:
			return chunk.voxels[Chunk.index(x, y, z)] != Block.AIR
		if borders.has("n_" + face):
			var n: PackedByteArray = borders["n_" + face]
			return n[ni] != 0
		if wy < 0:
			return true
		var top := -1_000_000
		match face:
			"px": top = (borders["top_px"] as PackedInt32Array)[z]
			"nx": top = (borders["top_nx"] as PackedInt32Array)[z]
			"pz": top = (borders["top_pz"] as PackedInt32Array)[x]
			"nz": top = (borders["top_nz"] as PackedInt32Array)[x]
			_: top = (borders["top_col"] as PackedInt32Array)[x + z * Chunk.SIZE]
		return wy <= top


## The C++ Dictionary, in the Array shape `ChunkNode.apply_arrays()` has always
## been handed. An empty Dictionary is a chunk with nothing to draw, exactly
## where the twin returns `[]`.
static func arrays_from_cpp(got: Dictionary) -> Array:
	if got.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = got["verts"]
	arrays[Mesh.ARRAY_NORMAL] = got["normals"]
	arrays[Mesh.ARRAY_COLOR] = got["colors"]
	arrays[Mesh.ARRAY_INDEX] = got["indices"]
	return arrays


## Mesh one chunk from borders somebody else built - the entry the column job
## uses, because a worker already knows its neighbours and should not have to
## discover them through a Callable one block at a time.
##
## `cpp` is the job's own configured mesher, or null. `solid_outside` is the
## job's own Callable, passed so the GDScript leg costs nothing to reach; where
## it is absent one is rebuilt from the borders.
static func build_arrays_from(chunk: Chunk, borders: Dictionary,
		config: WorldgenConfig, world_seed: int,
		cpp: Object = null, solid_outside := Callable()) -> Array:
	if cpp != null and resolve_backend() == "cpp":
		return arrays_from_cpp(cpp.build(borders))
	var callable := solid_outside if solid_outside.is_valid() \
		else solid_from_borders(chunk, borders)
	return build_arrays_gd(chunk, callable, config, world_seed)


## THE DISPATCHER. Mesher v1 Stage 3.
##
## Through Stage 2 this went straight to the twin whatever the backend said,
## because the C++ class was a stub and then a mesher that painted every quad
## white: the parity harness drove it directly and the game never saw it.
##
## THE CALLABLE FORM IS THE COLD ONE. A worker that already knows its
## neighbours goes through `build_arrays_from()` with borders it built once per
## column; this entry has only a Callable, so it pays for a shell. Everything
## still in the tree that reaches for it - the model gallery through `build()`,
## the edit path through `build()` - is one chunk at a time and stays on the
## twin by name, so in practice this is the API and not a hot path.
static func build_arrays(chunk: Chunk, solid_outside: Callable,
		config: WorldgenConfig, world_seed: int) -> Array:
	if resolve_backend() == "cpp":
		var impl := new_cpp_mesher(config)
		if impl != null:
			return arrays_from_cpp(impl.build(
				borders_from_callable(chunk, solid_outside)))
	return build_arrays_gd(chunk, solid_outside, config, world_seed)


## Build the surface arrays for `chunk`.
##
## `solid_outside` is called as solid_outside.call(wx, wy, wz) -> bool and ONLY
## for neighbours outside this chunk. We cannot answer those ourselves, and
## answering "air" would draw a wall of faces at every chunk seam.
##
## `block_size` is metres per block. The arrays come out in metres so the node
## holding them needs no scale: a scaled node scales its collision shape too,
## and scaled physics shapes are a class of bug nobody should have to debug.
##
## Returns an empty Array for a chunk with nothing to draw. This function
## touches no scene state and no rendering API, which is what lets it run on a
## worker thread.
## `config` is the world's SNAPSHOT of its tuning values - World clones it at
## setup and never writes to it again - so reading it from a worker thread is
## safe and needs no copying. It replaced a growing list of loose float
## parameters at Stage 10, when per-vertex tinting added five more.
##
## MESHER V1 STAGE 0 RENAMED IT. This body is now the REFERENCE TWIN and the
## dispatcher above carries its old name. Not one expression in it moved; the
## C++ port is asserted against it array for array by the self-test's
## `chunk parity` gate, and an improvement made here without one made there is
## how two meshers start drawing two worlds.
static func build_arrays_gd(chunk: Chunk, solid_outside: Callable,
		config: WorldgenConfig, world_seed: int) -> Array:
	var block_size: float = config.block_size
	var ao_strength: float = config.ao_strength
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# A chunk with no solid blocks has no faces at all - not even at its
	# boundary, because a face is only ever drawn by the chunk that owns the
	# SOLID side of it. Most of a heightmap world is empty sky, so this one
	# test skips the whole sweep for a large fraction of all chunks.
	if not chunk.has_solid:
		return []

	var origin := chunk.origin()
	var size := Chunk.SIZE
	var mask := PackedInt32Array()
	mask.resize(size * size)
	# Parallel to `mask`, one packed AO code per face cell. Separate rather than
	# folded into the mask value because the mask's sign already carries the
	# facing, and stuffing a third field into one int would make the one line
	# that decides whether two faces may merge unreadable.
	var ao_mask := PackedInt32Array()
	ao_mask.resize(size * size)
	var want_ao := ao_strength > 0.0

	# A chunk with no air in it can only have faces where it meets the outside
	# world, so only the two outermost planes of each axis can carry any. The
	# other 15 are guaranteed empty and sweeping them is pure cost - and
	# underground chunks are the other large fraction of the world.
	var solid_throughout := not chunk.has_air

	for d in 3:
		var u: int = AXIS_U[d]
		var v: int = AXIS_V[d]

		# slice is the coordinate of the block on the NEGATIVE side of the
		# plane. It starts at -1 so the chunk's own outer face is considered,
		# and ends at size - 1 so the far outer face is too.
		for slice in range(-1, size):
			if solid_throughout and slice != -1 and slice != size - 1:
				continue
			var a_in := slice >= 0
			var b_in := slice + 1 < size
			var has_face := false

			for jv in size:
				for iu in size:
					var a := Vector3i.ZERO
					a[d] = slice
					a[u] = iu
					a[v] = jv
					var b := a
					b[d] = slice + 1

					var id_a := 0
					var solid_a := false
					if a_in:
						id_a = chunk.voxels[Chunk.index(a.x, a.y, a.z)]
						solid_a = id_a != Block.AIR
					else:
						solid_a = solid_outside.call(
							origin.x + a.x, origin.y + a.y, origin.z + a.z)

					var id_b := 0
					var solid_b := false
					if b_in:
						id_b = chunk.voxels[Chunk.index(b.x, b.y, b.z)]
						solid_b = id_b != Block.AIR
					else:
						solid_b = solid_outside.call(
							origin.x + b.x, origin.y + b.y, origin.z + b.z)

					# A face exists only where solid meets air, and we draw it
					# only if the SOLID side is a block of ours - otherwise the
					# neighbouring chunk would draw the same face as well and
					# the two would z-fight.
					var m := 0
					if solid_a != solid_b:
						if solid_a:
							if a_in:
								m = id_a          # faces along +d
						elif b_in:
							m = -id_b             # faces along -d
					mask[iu + jv * size] = m
					if m != 0:
						has_face = true
						# The air is on the far side of the face from the solid
						# block, and AO is a question about the air side: which
						# of the blocks around this corner are in the way of
						# light arriving.
						ao_mask[iu + jv * size] = _corner_ao(
							chunk, origin, solid_outside, d, u, v,
							slice + 1 if m > 0 else slice, iu, jv) if want_ao else AO_OPEN
					else:
						ao_mask[iu + jv * size] = AO_OPEN

			if has_face:
				_emit_slice(mask, ao_mask, size, d, u, v, slice + 1,
					config, world_seed, origin,
					verts, normals, colors, indices)

	if verts.is_empty():
		return []

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## Take rectangles out of one mask until it is empty.
##
## For each cell still set, grow right as far as the value repeats, then grow
## down as far as every cell of that width matches, emit the rectangle, and
## clear it. Greedy rather than optimal: finding the genuinely minimal set of
## rectangles is expensive, and this gets within a few percent of it for the
## shapes terrain actually makes.
static func _emit_slice(mask: PackedInt32Array, ao_mask: PackedInt32Array, size: int,
		d: int, u: int, v: int, plane: int,
		config: WorldgenConfig, world_seed: int, origin: Vector3i,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array,
) -> void:
	for jv in size:
		var iu := 0
		while iu < size:
			var value := mask[iu + jv * size]
			if value == 0:
				iu += 1
				continue
			# The AO code is part of the identity of a face, so a run stops
			# where the shading changes even though the blocks are identical.
			# With AO off every code is AO_OPEN and this reduces exactly to the
			# pre-AO behaviour.
			var ao_value := ao_mask[iu + jv * size]

			var w := 1
			while iu + w < size and mask[iu + w + jv * size] == value \
					and ao_mask[iu + w + jv * size] == ao_value:
				w += 1

			var h := 1
			while jv + h < size:
				var row_matches := true
				for k in w:
					if mask[iu + k + (jv + h) * size] != value \
							or ao_mask[iu + k + (jv + h) * size] != ao_value:
						row_matches = false
						break
				if not row_matches:
					break
				h += 1

			_emit_quad(d, u, v, plane, iu, jv, w, h, value, ao_value,
				config, world_seed, origin, verts, normals, colors, indices,
)

			for dv in h:
				for du in w:
					mask[iu + du + (jv + dv) * size] = 0
			iu += w


static func _emit_quad(d: int, u: int, v: int, plane: int,
		u0: int, v0: int, w: int, h: int, value: int, ao_value: int,
		config: WorldgenConfig, world_seed: int, origin: Vector3i,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array,
) -> void:
	var positive := value > 0
	var block_size: float = config.block_size
	var ao_strength: float = config.ao_strength
	var color := Block.color_of(absi(value))

	var normal := Vector3.ZERO
	normal[d] = 1.0 if positive else -1.0

	var u1 := u0 + w
	var v1 := v0 + h

	# WINDING ORDER MATTERS. Godot's front face is the CLOCKWISE one as seen
	# from the front and back faces are culled, so a mistake here does not make
	# one face vanish - it turns the world inside out, and you see the far side
	# of the terrain through the near side.
	#
	# With (u, v, d) right-handed, these two orders satisfy
	# (p1 - p0) x (p2 - p0) == -normal, which is the algebraic form of
	# "clockwise seen from outside". Check any new face against that identity
	# rather than eyeballing it in-engine.
	# The second entry of each pair is the CANONICAL AO corner this vertex is,
	# which is why the two lists are not just reorderings of the same four
	# points - the winding differs between facings and the AO code does not.
	var corners: Array
	if positive:
		corners = [
			[u0, v0, AO_CORNER_U0V0], [u0, v1, AO_CORNER_U0V1],
			[u1, v1, AO_CORNER_U1V1], [u1, v0, AO_CORNER_U1V0]]
	else:
		corners = [
			[u0, v0, AO_CORNER_U0V0], [u1, v0, AO_CORNER_U1V0],
			[u1, v1, AO_CORNER_U1V1], [u0, v1, AO_CORNER_U0V1]]

	# ONE FLAT COLOUR PER MATERIAL (light v1 Stage 3). The aspect and slope
	# tint that used to be computed once per quad here, and the per-corner
	# jitter below it, were paint doing what light does; both left with
	# Block.aspect_shade and Block.jitter.
	var first := verts.size()
	for c in corners:
		var p := Vector3.ZERO
		p[d] = float(plane)
		p[u] = float(c[0])
		p[v] = float(c[1])
		verts.push_back(p * block_size)
		normals.push_back(normal)
		# BAKED AO IS OFF BY DEFAULT NOW (Q9): SSAO does this downstream of the
		# mesh, and at ao_strength 0 the mask carries AO_OPEN without the
		# corners ever being sampled, so a run merges by block id alone. The
		# multiply is kept for the one thing it is still good for -
		# photographing the old look for the report - and it is a plain linear
		# scale, so it stays correct if the palette is re-authored.
		var level: int = (ao_value >> (int(c[2]) * 2)) & 3
		var shade := 1.0 - ao_strength * (1.0 - _ao_curve(level))
		var lit := Color(color.r * shade, color.g * shade,
			color.b * shade, color.a)
		# sRGB on the wire: the AO multiply above is linear, this is the one
		# conversion, and it is the last thing before the push. See Look.to_wire.
		colors.push_back(Look.to_wire(lit))

	indices.push_back(first)
	indices.push_back(first + 1)
	indices.push_back(first + 2)
	indices.push_back(first)
	indices.push_back(first + 2)
	indices.push_back(first + 3)


## Wrap finished arrays in an ArrayMesh. MUST run on the main thread - this is
## the only part of meshing that touches the rendering server, which is exactly
## why build_arrays() returns arrays instead of a mesh.
## The triangle soup `ArrayMesh.create_trimesh_shape()` would derive: every
## index expanded to its vertex, three at a time.
##
## WHY IT IS HERE AND NOT ON THE MAIN THREAD (world feel v1 Stage 1). Deriving
## the collision shape from a finished ArrayMesh is pure arithmetic over the
## index buffer - no server call, no Resource - and it was being done on the
## main thread for every chunk. On a worker it leaves the main thread
## `ConcavePolygonShape3D.new()` and `set_faces()`: one allocation and one
## memcpy. See ChunkNode.apply_arrays().
static func faces_from(mesh_arrays: Array) -> PackedVector3Array:
	if mesh_arrays.is_empty():
		return PackedVector3Array()
	var verts: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for i in indices.size():
		faces[i] = verts[indices[i]]
	return faces


# LIGHT V1 STAGE 3 REMOVED THE CANOPY INK. `_under_canopy` tinted a column's
# ground toward the shade colour in proportion to how much of its own sky its
# trees covered, because no tree cast a shadow at any distance and a wood had to
# be made to read as shaded somehow. LOD0 trees cast real shadows now (Q10), so
# this was painting a second one on top of the first.
static func arrays_to_mesh(arrays: Array) -> ArrayMesh:
	if arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, get_material())
	return mesh


## Synchronous build, for the one chunk changed by an edit. Bulk loading goes
## through build_arrays() on a worker thread instead.
##
## STAYS ON THE TWIN UNTIL MARCEL RETIRES IT (mesher v1 Q7). One chunk per
## broken block, on the main thread, is not a hot path, and until the parity
## gate has been green on BOTH boxes across two merges there is no reason for
## the one path a player can trigger by hand to be the one with the newer
## mesher under it. `build_arrays_gd` and not `build_arrays`, so that stays true
## when the dispatcher starts choosing.
static func build(chunk: Chunk, world_solid: Callable,
		config: WorldgenConfig, world_seed: int) -> ArrayMesh:
	return arrays_to_mesh(build_arrays_gd(chunk, world_solid, config, world_seed))


## One shared material for every chunk. Sharing it means the renderer can batch
## chunks together; a material per chunk would defeat that.
##
## SINCE LOOK V1 IT IS THE POSTER MATERIAL, shared with the far field, the far
## trees and the characters - see Look. What it keeps from the terrain v1
## StandardMaterial3D: the per-block colour baked into the vertices IS the
## albedo, no texture, no UVs in the vertex stream, and nothing shiny, because
## a specular highlight sliding across a hillside as you walk is the fastest
## way to make a matte world look like wet plastic. What it adds is the ramp.
static func get_material() -> Material:
	return Look.opaque_material()


# --- Corner ambient occlusion -----------------------------------------------

## The four corner AO levels of one face cell, packed two bits each in
## canonical (su + sv * 2) order.
##
## `air_d` is the d-coordinate of the block on the AIR side of the face. AO is
## a question about that side and only that side: how much of the sky arriving
## at this corner is blocked by the blocks standing around it.
static func _corner_ao(chunk: Chunk, origin: Vector3i, solid_outside: Callable,
		d: int, u: int, v: int, air_d: int, iu: int, jv: int) -> int:
	# The eight blocks around the air block, in its own plane. The centre is
	# the air block itself and is not asked about.
	var n00 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu - 1, jv - 1)
	var n10 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu, jv - 1)
	var n20 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu + 1, jv - 1)
	var n01 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu - 1, jv)
	var n21 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu + 1, jv)
	var n02 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu - 1, jv + 1)
	var n12 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu, jv + 1)
	var n22 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu + 1, jv + 1)

	return _vertex_ao(n01, n10, n00) \
		| (_vertex_ao(n21, n10, n20) << 2) \
		| (_vertex_ao(n01, n12, n02) << 4) \
		| (_vertex_ao(n21, n12, n22) << 6)


## AO level 0 (darkest) to 3 (fully open) for one corner.
##
## THE SPECIAL CASE IS THE WHOLE POINT. When both SIDES are solid the corner is
## in an interior angle and it makes no difference whether the diagonal block
## is there too - you cannot see past two walls meeting. Without this test the
## inside of every corner would come out one step lighter where the diagonal
## happens to be missing, which reads as a bright seam running up the join
## between two walls.
static func _vertex_ao(side1: bool, side2: bool, corner: bool) -> int:
	if side1 and side2:
		return 0
	return 3 - (int(side1) + int(side2) + int(corner))


## Is the block at these (d, u, v) chunk-local coordinates solid?
##
## Reads the chunk's own array where it can and only falls back to the Callable
## outside it. That branch is worth writing out: AO asks about eight blocks per
## face and a Callable invocation in GDScript costs far more than an array
## index, so routing the interior through the Callable as well would have made
## meshing several times more expensive for no difference in the result.
static func _solid_at(chunk: Chunk, origin: Vector3i, solid_outside: Callable,
		d: int, u: int, v: int, dd: int, uu: int, vv: int) -> bool:
	var p := Vector3i.ZERO
	p[d] = dd
	p[u] = uu
	p[v] = vv
	if Chunk.in_bounds(p.x, p.y, p.z):
		return chunk.voxels[Chunk.index(p.x, p.y, p.z)] != Block.AIR
	return solid_outside.call(origin.x + p.x, origin.y + p.y, origin.z + p.z)


## TODO(marcel): the AO curve is a straight line and probably should not be.
##
## This maps a corner's occlusion level - 0 for fully enclosed, 3 for fully
## open - onto how bright it is drawn. Straight-line is the obvious choice and
## it spreads the darkening evenly over all four levels, which means level 2
## (one neighbour solid) is already noticeably dark. Most of a voxel world is
## level 2, so most of the world gets a little dirty and the true corners never
## get to be dramatic.
##
##   Hint: try  var t := float(level) / 3.0  and then  return t * t
##   Squaring pulls the middle levels back up towards full brightness while
##   leaving level 0 at zero, so the darkening concentrates where two surfaces
##   genuinely meet.
##
##   pow(t, 0.5) is the other direction and is worth one look, if only to see
##   what "too much AO" is: it darkens the open ground and reads as grime.
##
## Reroll is not needed - AO is baked at mesh time, so F7 or walking away and
## back is enough to see a change.
##
## Fallback: linear, which is what every voxel game does by default and looks
## perfectly reasonable.
static func _ao_curve(level: int) -> float:
	return float(level) / 3.0
