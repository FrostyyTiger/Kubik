# Parts data v1 - the ASCII leaves the code, and the comments stop lying

Two items, one evening. The main course moves 33,158 lines of generated GDScript
out of `scripts/` into data files a loader reads; the side dish is a sweep over
comments that merged work has made false. Written 2026-08-29 against `main` at
**`fd4a2c8`**, with other sessions in distance, trees and possibly UI tonight -
which is what hard rule 1 is about.

The case is habit 1 in `CLAUDE.md`: *facts as data, not prose in code.* An ASCII
voxel is a fact. `scripts/character/parts/` is 1.8 MB of it declared as `const`
dictionaries - 20,920 lines in `parts_armour.gd` alone - which Godot compiles at
load, `git` cannot review, and every session that greps `scripts/character/` pays
for in tokens. Nothing about the format is wrong. Its address is.

---

## What was checked before this plan was written

Five things, on ganymede, against `fd4a2c8`. Two of them change the brief.

**1. The generator is NOT behind, and there are no hand-edits to fold back.**
Every generated file carries *"Editing the ASCII by hand is legal - say so on
this line if you do."* Nobody has, and the stronger check agrees:
`python3 -m tools.parts_author && git diff --stat scripts/character/parts/`
produces **zero diff across all eight files**. The risk the brief names is real
and absent today, so Stage 0 is a one-command confirmation rather than a salvage
- run anyway, because it is the cheapest thing here and the only proof of the
premise on the day.

**2. Not everything in these files is data, and that is the good news.** Three
modules carry GDScript no JSON can hold: `parts_hair.gd`'s `HAIR` / `BEARD` /
`hair_part()` / `beard_part()` / `_lookup()`, `parts_critter.gd`'s `V`, `DIMS`,
`bone_table()` and `palette()`, and `parts_gear.gd`'s `PLACEHOLDERS`. All of it
lives today as literal GDScript strings inside `hair.py`, `gear.py` and
`critter.py` - code generating code, only because it had to share a file with the
ASCII. **The refactor deletes 33,000 generated lines and un-generates 120 more.**

**3. `.json` IS a native Resource in Godot 4.7, so the export needs no change.**
The brief expects an `include_filter` edit. Probed instead:
`load("res://assets/characters/parts/_probe.json")` returns a `JSON` resource and
`ResourceLoader.exists()` is `true`, so `export_filter="all_resources"` already
covers these files and `export_presets.cfg` is untouched by this epic. The probe
also pinned the one format hazard: JSON numbers come back as **floats**
(`[1.0, 2.0, 3.0]`), so `size` needs an explicit `int()` into `Vector3i`. No
`.uid` sidecar is produced. Stage 4 still adds a three-line CI check: "I probed
it" is not a gate, and the failure mode - a shipped build with no characters in
it - is the worst one available.

**4. Baseline.** `~/bin/godot --headless --path . scenes/character/selftest_character.tscn`
on `fd4a2c8`: **35 tests, all passed**, exit 0. Godot `4.7.2.stable.official`.

**5. `player.gd:12` is false, and the sweep is small.** *"PHYSICS IS LOCAL, FOR
NOW. The host does not simulate this yet"* against `STATUS.md` item 3: *"Stage 10
closed the carried ticket - clients send input, the host simulates"*, measured on
`322a10d`. Grepping the in-scope paths for the whole candidate vocabulary returns
**9 lines in `.gd` and 6 in `README.md` / `docs/DESIGN.md`**, most of them true
and staying. One stage, not an epic.

## Where this disagrees with the brief

**JSON, not `.tres` or a custom Resource.** A `.tres` would sidestep the export
question - except finding 3 says there is no export question. What is left is the
trade already made: a part must stay hand-inspectable and diffable, because the
ASCII rows *are* the art and a reviewer reading a diff is the only review this art
gets. `.tres` is engine-owned, rewritten on save, and renders a nested array of
strings as one long line; JSON keeps one row per authored row. A custom
`Resource` subclass would also put the schema back into GDScript, the thing being
removed. JSON, and the only cost is one `int()`.

---

## Hard rules

1. **The excluded paths are not touched, in either item.** `scripts/world/**`
   (flora included), `scripts/ui/**` and the menu scenes, `scripts/game/game.gd`,
   `scripts/tools/{stream_probe,screenshot_tour,worldgen_probe}.gd`, and
   `STATUS.md`. Other sessions are in those files tonight. If a change here seems
   to need one of them, stop and write it into the handoff instead.
2. **`TODO(marcel)` comments are untouchable.** Seven sit in in-scope files
   (`armour.gd`, `animator.gd`). They are deliberate exercises: not reworded, not
   resolved, not tidied, not moved.
3. **The `.gd` parts files are deleted only after the identity gate passes** -
   Stage 2's test 36, green over all 101 parts, in a commit preceding the delete.
4. **`selftest_character` is green at the end of every stage**: 35 tests until
   Stage 2, 36 after, never fewer. A new test is an **untyped** callable, for the
   reason `_ready()` gives - a typed one that crashes returns a default and reads
   as a pass.
5. **Small staged commits on `main`**, house style, one per stage:
   `refactor(character): stage N - <narrative one-liner>` for the data move,
   `docs:` / `chore:` for the rest. No branch, no squash, no force-push.
6. **After any stage that adds or removes files under `res://`, run
   `~/bin/godot --headless --path . --import` once** before the self-test. Stages
   2, 3 and 4 all move a `class_name`.
7. **The generator stays the source of truth.** No stage hand-edits a generated
   data file. If a voxel must move, it moves in `tools/parts_author/`.

---

## Stage 0 - is the generator behind?

**What.** Confirm finding 1 on the day, before anything depends on it.

**Files.** None. No commit.

**Gate.**
```
python3 -m tools.parts_author && git status --porcelain scripts/character/parts/
~/bin/godot --headless --path . scenes/character/selftest_character.tscn
```
Empty output from the first, `35 tests, all passed` from the second. **If the
first is not empty this plan stops here**, and the evening's job becomes folding
those hand-edits back into the Python until it is - because everything downstream
regenerates, and regenerating over a hand-edit deletes art.

## Stage 1 - the format, and a second emitter

**What.** `tools/parts_author` learns to write JSON, and writes it *alongside*
the `.gd` rather than instead of it. Both come from the same in-memory `Part`
objects, so the unchanged `.gd` is itself evidence the JSON did not drift.

One file per current module, at `res://assets/characters/parts/<module>.json`:

```json
{ "schema": 1, "generator": "tools/parts_author/human.py", "res": 96,
  "doc": ["The stocky human, voxel by voxel, at 1/16 of a block.", "..."],
  "parts": {
    "head": { "size": [18, 22, 17], "anchor": [9.0, 0.0, 9.0],
              "notes": {"5": "the mouth"},
              "doc": ["18 wide, 22 tall, 16 deep PLUS ONE for the nose."],
              "slices": [["..........", "..."], ["..."]] } } }
```

`size` is the `Vector3i` as three ints, `anchor` the `Vector3` as three floats,
`slices` exactly the array-of-arrays-of-rows `VoxelModel.parse()` already walks.
`doc` and `notes` carry the prose and the `# y = 5, the mouth` annotations the
`.gd` comments hold today - the only documentation this art has, and worth 3% of
a megabyte. The loader ignores every key but `parts`. Keys are the `PARTS` /
`PLACEHOLDERS` key where one exists (`head`, `jerkin_human`, `hand_r`); hair has
no such map, so its keys are the lowercased const names (`human_hair_short`).

**Files.** `tools/parts_author/voxlib.py` (`Part.json_obj()` beside `Part.gd()`,
`json_file()` beside `gd_file()`), the eight `render()` functions, `__main__.py`,
and a new `assets/characters/parts/README.md` describing the schema. Nothing
under `scripts/`.

**Gate.** `python3 -m tools.parts_author`, then: `git status --porcelain
scripts/character/parts/` empty (the `.gd` is still byte-identical); eight
`.json` files exist and
`python3 -c "import json,glob; print(sum(len(json.load(open(f))['parts']) for f in glob.glob('assets/characters/parts/*.json')))"`
prints **101**; `--import` exits 0.

## Stage 2 - `PartsData`, and the proof

**What.** The loader, and the test that says it is the same art.

`scripts/character/parts_data.gd`, `class_name PartsData`:

```gdscript
const ROOT := "res://assets/characters/parts"
const MODULES := ["human", "elf", "dwarf", "lizardfolk",
                  "hair", "gear", "armour", "critter"]

## Every part in one module, by the name a bone table refers to it with.
## Read-only, cached, loaded on first use.
static func module(name: String) -> Dictionary
```

**Lazy, per module, cached forever** in a static dictionary. A client that never
opens the creation screen never parses the armour file; one that does pays 1 MB of
`JSON.parse_string` once, off a `load()` the engine has already cached. Eager
loading would move that cost to every launch to save nothing.

**It fails loudly.** Missing file, parse error, unknown `schema`, a part with no
`size` or `slices`: `push_error` naming the path and the exact reason, then
`assert(false, ...)` so the editor and the self-test halt rather than draw an
empty character. Release strips the assert and gets an empty module, which
`Races._warn_once()` already surfaces. Returned dictionaries get
`make_read_only()` - what `const` bought us, and `Races.parts_for()`'s shallow
`duplicate()` still works through it.

**Test 36, `"the json is the consts"`**, untyped: for each of the eight modules
and each of the 101 parts, assert `size`, `anchor` and the full
`VoxelModel.parse()` voxel array are equal between the const table and
`PartsData.module()`. It prints a per-module hash of the parsed voxels - Stage 4
needs those eight numbers.

**Files.** `scripts/character/parts_data.gd` (new), `selftest_character.gd`.

**Gate.** `--import`, then **36 tests, all passed**, with the eight module hashes
in the output and copied into the commit message.

## Stage 3 - the consumers move, the tails come home

**What.** Every reference to a generated const becomes a `PartsData` call, and
the GDScript tails stop being generated.

| was | becomes |
| --- | --- |
| `PartsHuman/Elf/Dwarf/Lizardfolk.PARTS` | `PartsData.module("human")` … in `Races.part_set()` |
| `PartsArmour.PARTS` (x4, `character_view.gd:112-120`) | `PartsData.module("armour")` |
| `PartsHuman.HEAD` (`selftest:1652`) | `PartsData.module("human")["head"]` |
| `PartsCritter.PARTS` | `PartsData.module("critter")` |
| `PartsCritter.{DIMS,bone_table,palette}`, `PartsHair.*`, `PartsGear.PLACEHOLDERS` | stay, hand-written |

`parts_hair.gd`, `parts_gear.gd` and `parts_critter.gd` are **rewritten by hand**
as small permanent files - under 60 lines each, no ASCII - keeping their class
names so nothing else has to change. `PartsHair.HAIR` and `BEARD` become arrays
of part-name **strings** (`""` where the human has no beard at index 0), and
`_lookup()` returns `PartsData.module("hair")[name]` or `null`, so
`selftest_character.gd:1906`'s `.size()` and `:1925`'s `== null` keep working
unedited. `PartsGear.PLACEHOLDERS` becomes socket name -> part name, and
`character_view.gd:184` gains one lookup. `hair.py`, `gear.py` and `critter.py`
lose their `LOOKUP` / `TAIL` constants. Nothing is deleted this stage.

**Files.** `races.gd`, `character_view.gd`, `parts/parts_{hair,gear,critter}.gd`
(rewritten), `selftest_character.gd`, `character_gallery.gd`,
`tools/parts_author/{hair,gear,critter}.py`. `armour.gd` needs no change - it
names pieces, it does not hold them.

**Gate.** `--import`, then **36 tests, all passed** - test 36 is now comparing the
consts against the data the game actually runs on, which is the strongest it will
ever be. Plus, once by eye: `~/bin/godot --path . scenes/character/gallery.tscn
-- --label parts-data-s3` still draws four dressed races and a critter.

## Stage 4 - the deletion, and the hashes are frozen

**What.**

- Delete `parts_{armour,human,elf,dwarf,lizardfolk}.gd` and their `.gd.uid`
  sidecars. The three Stage 3 rewrites survive.
- `__main__.py` stops writing `.gd`; `voxlib.gd_file()` and `Part.gd()` are
  deleted; the package docstring's byte-identity gate is rewritten against JSON.
- Test 36 loses its comparison target, so it gains a frozen one: Stage 2's eight
  module hashes, hard-coded, compared against hashes recomputed from the JSON.
  That keeps the identity claim alive after the thing it was identical to is
  gone. A future regeneration that moves a voxel trips it, and the fix is a
  deliberate one-line update whose reason goes in that commit.
- `.github/workflows/build.yml` gains three lines after the size check:
  `grep -ac "assets/characters/parts/parts_armour.json" build/Kubik.exe` must
  find it. The pck's file table stores paths uncompressed, so this is a count -
  and it is the only thing between finding 3 being wrong and a release build with
  no characters in it.

**Gate.** `--import`, then **36 tests, all passed**;
`git grep -n "PartsArmour\.\|PartsHuman\.\|PartsElf\.\|PartsDwarf\.\|PartsLizardfolk\." -- scripts/`
is empty; `python3 -m tools.parts_author && git status --porcelain` shows no
change. Record the before/after in the commit message: lines under
`scripts/character/parts/` (**33,158** today) and bytes moved to `assets/`.

## Stage 5 - the stale-truth sweep

**What.** A pass over comments and doc lines merged work has made **false**. Not
old, not superseded, not aspirational: false.

**Method**, and the method is the deliverable rather than a findings list:

1. Grep the in-scope paths only - `scripts/player`, `scripts/physics`,
   `scripts/net`, `scripts/character`, `scripts/game/journal.gd`, `README.md`,
   `docs/DESIGN.md` - for `for now`, `not yet`, `TEMPORARY`, `provisional`,
   `does not … yet`, `will be`, `once … lands`. About 15 hits.
2. Verify each against `docs/status/*.md`, `STATUS.md` (read only - hard rule 1)
   and `git log -S`. A comment is false only if a named, merged commit
   contradicts it.
3. Fix only those. A comment that is merely old, or that describes a real
   remaining gap, stays. Rewriting true-but-dated prose is how a sweep becomes a
   rewrite of files three other sessions are holding.
4. Never a `TODO(marcel)` (hard rule 2). Never a file outside the list.
5. Every line changed, with the commit that made it false, goes in the commit
   message. That message is the record; no new doc.

The known one is `player.gd:12-16`. It should say the host simulates and clients
send input, per `STATUS.md` item 3 and world-feel-v1 Stage 10 (`322a10d`). Its
own text points at "the provisional note in Game" - `game.gd` is excluded, so
that reference is dropped rather than followed.

**Gate.** **36 tests, all passed** (a comment sweep cannot break it, which is why
it is run anyway); `git diff --stat` touches no excluded path; and
`git diff | grep -c "TODO(marcel)"` is **0**.

## Stage 6 - the docs, and the last gate

**What.** `README.md`'s architecture section and `docs/DESIGN.md` name the parts
tables as the standing example of habit 1 - *"`Races`, the parts tables and the
worldgen config already are"* - which is now more true than it was and points
somewhere else. Repoint them at `assets/characters/parts/` and `PartsData`.
`assets/characters/README.md` gains a line: the drop-in rule now replaces a part
loaded from JSON, and part names are the JSON keys. Append the outcome to this
plan. Not `STATUS.md`.

**Gate.** Both suites, cold:
```
~/bin/godot --headless --path . --import
~/bin/godot --headless --path . scenes/character/selftest_character.tscn   # 36, all passed
~/bin/godot --headless --path . scenes/selftest.tscn                       # all passed
```
and `git status --porcelain` clean.

---

## What this leaves open

- **The JSON is not smaller, only better addressed.** Roughly the same 1.7 MB,
  now where a grep of `scripts/` does not find it and a diff is one row per row.
  Compression and parse-time arguments wait until something measures a load cost,
  and nothing does: the armour file is read once, by the one screen that dresses
  a character.
- **The drop-in rule still only understands `.vox`.**
  `assets/characters/<race>/<part>.json` is the obvious sibling now, deliberately
  not added: a second unproven path through a directory that ships empty.
- **`hair.py` still hard-codes three options a race.** The option tables moved
  from generated GDScript to hand-written GDScript - one address better, not yet
  data. When hair becomes something a director or an item hands out, `HAIR` and
  `BEARD` follow the parts into JSON.
- **The sweep is a one-off, not a habit.** It fixes what is false on 2026-08-29
  and installs nothing that catches the next one. A lint flagging `for now` older
  than N commits is a real idea and a different evening.
- **Nothing was done about `scripts/world/`, `scripts/ui/` or `game.gd`**, which
  carry their own stale lines. Hard rule 1 said so; whoever owns those files next
  inherits the same grep and the same method.
