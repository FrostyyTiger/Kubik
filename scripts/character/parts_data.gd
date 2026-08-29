class_name PartsData

## Every character part in the game, loaded from `assets/characters/parts/`.
##
## THE ASCII IS DATA AND ITS ADDRESS IS `assets/`, not `scripts/`. It used to
## be 33,158 lines of `const` dictionaries under `scripts/character/parts/`,
## which Godot compiled at load, `git` could not usefully review, and every
## grep of `scripts/character/` paid for. Nothing about the format was wrong -
## the rows are still the same rows, written by the same generator - so this
## class is deliberately thin: read the file, check it is what it claims to
## be, turn two arrays into a `Vector3i` and a `Vector3`, and hand back
## exactly the dictionary shape `VoxelModel.parse()` and `Rig.build()` have
## always taken. Nothing downstream learns that a part came from a file.
##
## `tools/parts_author/` remains the source of truth. A voxel moves in the
## Python and nowhere else; see `assets/characters/parts/README.md`.
##
## LAZY, PER MODULE, CACHED FOREVER. A client that never opens the creation
## screen never parses the megabyte of armour; one that does pays for it once,
## off a `load()` the engine has already cached. Eager loading would move that
## cost to every launch to save nothing, since no two screens want the same
## module at the same moment anyway.

const ROOT := "res://assets/characters/parts"

## The schema this loader speaks. Bumped only when the shape changes in a way
## an old loader would read WRONGLY - a new ignored key is not a bump.
const SCHEMA := 1

## Every module, by the name its file is called. The four races, the hair and
## crests, the gear placeholders, the armour, and the critter - which is not a
## race and is in this list anyway, because a module is a file and not a
## species.
const MODULES := ["human", "elf", "dwarf", "lizardfolk",
	"hair", "gear", "armour", "critter"]

static var _cache := {}


## Every part in one module, by the name a bone table refers to it with.
##
## Read-only, cached, loaded on first use. The dictionary handed back is the
## same object every time - which is what `const` bought us before, and why
## `Races.parts_for()` can still take a shallow `duplicate()` of it and write
## a hair part into the copy.
static func module(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var out := _read(name)
	out.make_read_only()
	_cache[name] = out
	return out


## IT FAILS LOUDLY, and that is the whole of the error policy.
##
## A missing file, a parse error, a schema from the future, a part with no
## size or no slices: `push_error` naming the path and the exact reason, then
## an `assert` so the editor and the self-test HALT rather than quietly draw a
## character with no head. Release strips the assert and gets an empty module,
## which `Races._warn_once()` already surfaces at the one place that would
## notice - so the shipped build degrades instead of crashing, and the build
## that could have caught it does not.
static func _read(name: String) -> Dictionary:
	var out := {}
	var path := "%s/%s.json" % [ROOT, name]
	if not ResourceLoader.exists(path):
		_fail(path, "there is no such file")
		return out
	var res = load(path)
	if not (res is JSON):
		_fail(path, "loaded as %s, not a JSON resource" % [
			"nothing" if res == null else res.get_class()])
		return out
	var doc = (res as JSON).data
	if not (doc is Dictionary):
		_fail(path, "the top level is %s, not an object" % type_string(typeof(doc)))
		return out
	var schema := int((doc as Dictionary).get("schema", -1))
	if schema != SCHEMA:
		_fail(path, "declares schema %d and this loader speaks %d" % [schema, SCHEMA])
		return out
	var parts = (doc as Dictionary).get("parts")
	if not (parts is Dictionary):
		_fail(path, "has no `parts` object")
		return out
	# Every other key - `doc`, `notes`, `generator`, `res` - is prose for the
	# next person to read the file, and is ignored here on purpose.
	for key in (parts as Dictionary):
		var part = (parts as Dictionary)[key]
		if not (part is Dictionary):
			_fail(path, "part '%s' is %s, not an object" % [
				key, type_string(typeof(part))])
			return {}
		var built := _part(path, String(key), part as Dictionary)
		if built.is_empty():
			return {}
		built.make_read_only()
		out[String(key)] = built
	return out


## One part, in the shape the runtime takes.
##
## THE `int()` CALLS ARE NOT DECORATION. JSON has one number type and Godot
## parses every one of them as a float, so `size` arrives as `[27.0, 32.0,
## 26.0]` and `Vector3i(27.0, ...)` would be a narrowing conversion the parser
## does not have to like. Cast once, here, where the reason is written down.
static func _part(path: String, key: String, part: Dictionary) -> Dictionary:
	var size = part.get("size")
	if not (size is Array) or (size as Array).size() != 3:
		_fail(path, "part '%s' has no `size` of three numbers" % key)
		return {}
	var slices = part.get("slices")
	if not (slices is Array):
		_fail(path, "part '%s' has no `slices` array" % key)
		return {}
	var anchor = part.get("anchor", [0.0, 0.0, 0.0])
	if not (anchor is Array) or (anchor as Array).size() != 3:
		_fail(path, "part '%s' has an `anchor` that is not three numbers" % key)
		return {}
	return {
		"size": Vector3i(int(size[0]), int(size[1]), int(size[2])),
		"anchor": Vector3(anchor[0], anchor[1], anchor[2]),
		"slices": slices,
	}


static func _fail(path: String, why: String) -> void:
	var message := "[PartsData] %s: %s" % [path, why]
	push_error(message)
	assert(false, message)
