# Kubik

Rewritten 2026-09-04 against the bible as of D84; where an older document
disagrees, the bible wins. The § Running it section is owned by the horizon v1
and mesher v1 lanes and was not touched by that rewrite.

## What is this

Kubik is a co-op voxel exploration game for two, in a real-sized fantasy Alps
that fell a long time ago and is still magnificent. You are small, it is huge,
you will not understand all of it, and you keep walking. An authored world with
a generative director: the game quietly notices what your party does and
answers at the campfire. Open source (MIT), Godot 4 with the hot paths in C++,
built by two friends as a learning project in both gamedev and AI-native game
design.

**The world.** Three ages. The Builders, gone, who tried to gather the magic of
the whole land into one place and broke it - their black-and-gold monuments
still stand and still run. The mountain folk, fading, who hold the high places
and treat the crystals as sacred. The Engineers, rising, who hold the one
valley with coal and iron and have learned to **burn** crystals for power, a
little, because that is how they see a crystal's use. A burning crystal drives
an engine and fades as it does, and the magic it held is gone from the world
for good. The fall is coming again, slowly, and nobody says so. Nobody is the
villain.

**Core loop:** two people walk out from a campfire into a world that gets
stranger the further they get from the capital, learn from both peoples what
neither will finish, and come back to a fire. The world reads the journey and
answers: fragments that reflect what you did, rumours that point somewhere,
quests whose middles nobody - including the developers - has seen before.

The tone is the thing above everything and it is one file:
[`../Kubik-bible/00-TONE.md`](../Kubik-bible/00-TONE.md) (D38, D39, D40).
Warmth and earned humour between the two players are welcome; the world is
grave, the friendship is not. Nothing cute, no comic relief, no villain with a
speech, no frantic survival, no graphic violence, no horror dressing.

### Gameplay pillars

Four. Every feature serves at least one and contradicts none. They sit under
the tone and beside the bible's five art pillars
([`../Kubik-bible/style-bible/00-pillars.md`](../Kubik-bible/style-bible/00-pillars.md)).

1. **BETTER TOGETHER.** Two people who walk between. The game allows four and
   is designed for two (D46): every encounter, rumour and line of fiction is
   written for two, and **there is no party frame, ever.** Solo is a dev
   convenience, never a balanced mode.
2. **TENSE OUT, WARM AT THE FIRE.** Danger and pacing scale with distance from
   the current campfire, with eerie weather, and with distance from the
   capital (D35). Firelight and daylight are the warm register: light, regen,
   respawn. **Every dread beat ends at a fire.** Death costs time, not
   progress, and is quiet and remembered (D39). No base building: players place
   objects, never terrain. No timers, no hunger bars, no alarms.
3. **THE WORLD IS THE CONTENT.** Progression is ranging further. What the
   world IS comes from distance from the Engineers' capital, in rings (D44,
   D26); what it FEELS like right now comes from the current fire (D35). The
   register is monumental against tiny, in a real-sized Alps (D45), seen to
   the horizon (D41, D84).
4. **THE WORLD ANSWERS.** Authored truth, generative direction. The game owns
   all truth and a structured event log; at campfire rests a model proposes
   small, validated actions through five verbs, and the game is complete and
   fun with it off. Doctrine:
   [`../Kubik-bible/director/`](../Kubik-bible/director/), pointed at by
   [docs/DIRECTOR.md](docs/DIRECTOR.md).

The technical truth - the renderer, the grains, the camera, physics,
multiplayer - is [docs/DESIGN.md](docs/DESIGN.md). What in this repo stays, is
adapted or is ripped, and in what order, is
[RECONCILIATION.md](RECONCILIATION.md). What is queued is [TODO.md](TODO.md)
and [docs/IDEAS.md](docs/IDEAS.md).

> **Status: walkable, lit by the engine, meshed in C++, and as big as the view.**
> An alpine landscape with no edge - generated on demand in origin-anchored
> tiles and drawn to the horizon, 32 km on a clear day, since horizon v1
> landed (`docs/status/horizon-v1.md`, merged 2026-09-05; the home 3 km is
> bookkeeping now, and the relief stays a quarter of real until the
> world-truth break, which follows upload v1, D85) - meadow valleys, seven tree species that clump and leave clearings,
> bare rock, snow peaks, lakes in real basins, 8.7 M pieces of ground cover,
> fireflies after dark. **Lit since light v1** (merged 2026-09-04) by a real
> sun with soft sky-tinted shadows, a physical sky, four hours plus eerie,
> volumetric fog, reflective water and a film lens
> (`docs/status/light-v1.md`), under the bible's art pillars. **Meshed in C++
> since mesher v1** (merged 2026-09-04, phase 1b, D56):
> `docs/status/mesher-v1.md`.
>
> The character path is the next thing to change. The four playable races and
> their creation screen still run, and they are on the rip list: under D37 and
> D70 there is one people, nobody changes, and the characters are the bought
> viking, dwarf and elf templates used as they are, reskinned clothes only
> (D1). Nothing lives in the world yet, nothing can be broken or placed, and
> the director does not exist.
>
> Verified on Godot 4.7.2: both peers generate an identical world from the same
> seed and config, the world and character self-tests pass, and the world is
> clean of runtime errors. See `STATUS.md` for the latest run.

---

## Architecture

These are decisions, not suggestions. They were made up front because each one
is expensive to retrofit and cheap to obey.

### 1. Host-authoritative, always

The game runs as a **host** (owns the world, runs the simulation) or a
**client** (sends input, receives state). There is no third mode.

Single player is *a host with zero clients*. This matters more than it sounds:
it means there is no solo-only code path that quietly rots while you test
multiplayer, and no "works alone, breaks together" class of bug.

The server is always peer id 1 — that is Godot's convention and the whole
codebase leans on it.

### 2. One mutation path

Every change to the world follows exactly one route:

```
  anyone: World.request_set_block()
     |                        \
     | (client) RPC to peer 1  | (host) direct call, no network
     v                        /
  host: _host_apply_edit()  ->  validate  ->  apply  ->  broadcast diff
                                                            |
                                         every client: _cl_apply_block()
```

A client **never** writes to its own chunk data, not even optimistically.
If we ever want client-side prediction, it gets added here as an explicitly
reconciled layer — not by quietly letting a client mutate state.

Identity always comes from `multiplayer.get_remote_sender_id()`, which the
network layer assigns and a client cannot forge. Never from a peer id in the
payload.

**The director is a client too.** Every verb it proposes is validated and
applied through this exact path, and it never touches state directly. That is
habit 3 in `CLAUDE.md` and principle 4 in `../Kubik-bible/director/00-principles.md`.

### 3. Terrain is never sent, only edits

Both machines generate identical terrain locally from a shared 64-bit seed **and
a shared worldgen config**. The host picks both and sends them once during the
join handshake — the config matters just as much as the seed, because two
machines generating with different treelines are in different worlds. After
that, the only world data on the wire is the **edit dictionary** — the
difference between what the seed generates and what the world actually looks
like.

That makes generation determinism a hard requirement. No `randf()` in
`TerrainGenerator`, no dependence on iteration order, no floats that might round
differently. Break it and players quietly end up in different worlds.

**Both legs quantise every height to 1/1024 of a block** as their last step, so
gcc and MSVC cannot produce two worlds. That rule survives every C++ rung and
is asserted on every self-test run (D42, D56).

### 4. Networking lives behind a seam

`NetTransport` is an interface with one job: build a configured
`MultiplayerPeer`. `ENetTransport` implements it today; `SteamMultiplayerPeer`
will implement it later for NAT punch-through, and that swap should touch one
file.

The seam deliberately has **no send/receive methods**. Godot's high-level
multiplayer already talks to `MultiplayerPeer`, so that is the natural boundary.
Wrapping RPCs in a custom message layer would mean every gameplay system is
written against the wrapper, and "swap the transport" would quietly become
"rewrite the game".

### 5. The world is as big as the view

**The north star (D84, 2026-09-04).** Three things outrank every knob in this
repo:

1. **The world is as big as the view.** Terrain on demand, no edge, no region.
2. **The view reaches the horizon.** 32 km on a clear day, fog as a ramp
   normalised to that distance and never a wall, nothing pops in.
3. **The frame holds.** 60 FPS at max settings on mid hardware - an RTX
   3070 Ti - measured while sprinting through forest.

**Unbounded terrain, ringed content (D44).** The terrain is seeded and has no
wall and no edge. **No system may bake in a world edge, a global heightmap or
a global-extent assumption.** The content is ringed from the Engineers'
capital and ends at the Builders' city, the last authored place; beyond it the
seeded terrain goes on as sea and eerie weather with nothing in it. Nothing
generates "a region". The home 3 km, where lakes, spawn and the zone shares
are still computed until the world-truth break, is bookkeeping and never an
edge. Direction treatment stays configurable: never hardcode "far away =
mountains".

**Two scales, one world.** Voxels exist only in a disc around the player -
real, editable, collidable terrain, and since horizon v1 they follow the player
anywhere rather than stopping at the home region's edge. Everything beyond is
the far field: low-poly meshes built from a coarse heightmap at 2 m resolution
and coarser. That coarse heightmap is also what makes lakes possible: a basin
is a depression with a rim all the way round it, and you cannot see one by
looking at a chunk.

**The height store is origin-anchored tiles at every level** (horizon v1). A
level-L tile is 129 x 129 cells of `4 << L` blocks and spans `256 << L` metres,
so one key is `(level, tx, tz)` anchored to the ORIGIN and never to the player;
it holds the cell mean, the cell max (which is what `far_peak_gain` pulls a
summit towards), one byte of material per cell and a coarser byte of forest
cover. Tiles are built on demand from the seed by whoever asks and evicted by
distance, and the far mesh reads a PUBLISHED, frozen view of the store rather
than the live one - because it has two legs, one of them cannot build a tile,
and two legs reading different ground is the one thing that seam may not do.
Inside the home 3 km the region's own pyramid still answers; the world-truth
break replaces it with tiles everywhere.

**The far country is ten rings of sixteen sectors**, 160 meshes, each at its
own world anchor, each rebuilt on its own: rings 0 to 2 follow the loaded
frontier and ring r >= 3 re-centres when the player has moved a quarter of its
inner radius. The ladder reaches **38.4 km** at 1,782,136 vertices, and every
ring costs about the same because ring area and cell area both grow fourfold.

**Positions live on a floating origin**, not a double-precision engine build
(D84) - the official Godot binary stays on every machine and in CI. World
metres are what a system means when it says where something is: the wire, a
save, every `_m` argument. The scene tree holds `render = world - offset`, the
offset a whole number of 256 m tiles. A rebase moves every anchor by one delta
in one frame and touches no vertex and no MultiMesh row; the rule that makes
it safe is that no buffer holds a position more than a few hundred metres from
its own node, which `scenes/selftest_horizon.tscn` asserts.

Chunks are 16x16x16 blocks, stored as a flat `PackedByteArray` — one byte per
voxel, one contiguous allocation, serialises as-is. Index order is
`x + z*16 + y*256`.

Coordinate conversion floor-divides rather than using integer division.
Truncation towards zero puts block `-1` in chunk `0` instead of chunk `-1`,
which corrupts a band of world on the negative side of the origin only, and is
a miserable thing to debug. See `Chunk.floor_div`.

**The mesher decides how a chunk looks, never what it is** (D56). It can be
replaced at any time without breaking a world, which is why it was the first
unattended C++ epic.

### 6. The world answers: authored truth, generative direction

The fourth pillar, as architecture. The game has a **Director**: a model that
reads what the party's journey means and improvises the path to authored
stakes - which fragment you find, which rumour points where, how a quest's
middle unfolds. Its doctrine is `../Kubik-bible/director/`, pointed at by
`docs/DIRECTOR.md`; it arrives late, at phase 6 of `RECONCILIATION.md` § 9.
What it asks of the code is decided now, because it is cheap now and a rewrite
later:

- **Facts are data, and the director reads them by ID.** What exists, what
  things want, what can happen - tables a program can read, never prose in a
  script. The worldgen config and the body table already are. Creatures,
  places, lore fragments and quest beats follow. **A deterministic chronicler
  turns the raw event log into typed facts with IDs, and every verb references
  IDs, never free text about the world** (D34 rule 1).
- **The host keeps a journal.** Structured events - edit, death, campfire,
  kill, first sight of a lake - appended as they happen. It is the director's
  input later and a debugging record today. Today it is untyped dictionaries
  held in memory; the typed store with IDs, salience and persistence is on the
  redo list (`RECONCILIATION.md` § 6).
- **The director acts only through five verbs.** `place_fragment`,
  `spawn_rumor`, `mark_site`, `advance_beat`, `reroute_beat`. It runs beside
  the host as a sidecar process, talks to Godot over local HTTP/WebSocket, and
  *proposes*; the host validates every proposal against the allowed outcomes
  and applies it through the one mutation path - exactly how a client's block
  edit is treated. It never touches state directly, never runs inside the
  engine's loop, and is invoked at campfire rests and session start: state
  machines own seconds, the director owns minutes. No combat, no physics.
  **Any feature that needs the model to invent world-truth or act outside the
  verbs is rejected and flagged.**
- **The template path ships first, and the game is complete without the
  model** (D34 rule 5). A non-model generator fills the same slots from the
  same log; the model is a better writer of identical structured output.
  Offline, with no key, or in a stranger's build, the defaults play. The host
  pays for it; clients get it through the host.

Godot needs nothing added for this. `HTTPRequest` and `WebSocketPeer` are
built in; the model never runs in-engine.

---
## Running it

You need **Godot 4.7.2** (standard build, no C# needed) from
[godotengine.org](https://godotengine.org/download). The version is pinned
rather than "4.x or newer" because CI builds against exactly this version,
and an export template that does not match the engine produces a broken build.

1. Open the Godot project manager, *Import*, select `project.godot`.
2. First open takes a moment while Godot imports the fonts.
3. Press F5.

If you launch the game from the command line rather than the editor, run
`godot --headless --path . --import` once after any pull that adds scripts with
a `class_name` - the editor keeps the global class cache in `.godot/`, and a
game started without it fails to parse the first script that names a new
class.

### Three things are C++, and you do not need any of them

Since distance v4 the far-field mesh is built by a GDExtension
(`gdext/`, class `KubikFarMesher`). It is **37-43x** faster than the GDScript
job it replaces, which is what lets `far_ring_div` default to 4.

Since distance v5 the height map's tiles are built by a second class in the
same extension, `KubikHeightTiles` - **16.7 s to 4.8 s** for the canonical
world. That one is not look-only: spawn and lakes are computed from the height
map, and terrain is never sent over the network, so both builders round every
height to **1/1024 of a block** as their last step and the self-test's
`canonical world` gate asserts that the two produce the same heightmap hash,
the same spawn and the same 53 lakes. Run the self-test on a second machine and
compare that one line - that is the whole cross-platform procedure.

Since mesher v1 the CHUNK mesher is a third class in the same extension,
`KubikChunkMesher` - **0.061 ms per chunk against the GDScript twin's 6.443,
106x, measured over the 1,910 chunks of the seed-42 spawn disc** - and the world
at spawn loads in **12.4 s against 30.9 s**. It is look-only in the strongest
sense the project has: the mesher decides how a chunk looks and never what it
is, so a disagreement could draw a different face and could not move the ground.
The gate is exact all the same - the self-test's `chunk parity` compares every
vertex, normal, index and colour component to the bit, at both AO settings, and
the bench repeats the comparison over the whole spawn disc - because colour
crosses the seam as a lookup table computed in GDScript rather than as
arithmetic, which leaves gcc and MSVC nothing to round apart. `--mesher gdscript`
forces the twin for an A/B; `scripts/world/chunk_mesher.gd` keeps the GDScript
implementation as the reference until it is deliberately retired.

**You can ignore all of this and the game works.** `scripts/world/far_field.gd`
and `scripts/world/terrain_generator.gd` each check for their class and fall
back to the GDScript implementation - which stays in the tree as the reference
the self-test compares against - so a checkout with no compiler plays fine, and
gets the same world. The only traces are some
`ERROR` lines from Godot's extension loader at startup and an F3 line reading
`far mesher: gdscript (no c++ library)` beside `mesher: gdscript (no c++
library)`. The far country then rebuilds in
seconds rather than milliseconds; if that bothers you, put `far_ring_div` back
to 2 on F4.

To build it you need a compiler and `scons`, plus a sibling checkout of
godot-cpp built against **this exact engine version**:

```
cd .. && git clone --depth 1 https://github.com/godotengine/godot-cpp.git
cd godot-cpp
godot --headless --dump-extension-api          # writes extension_api.json
scons platform=linux target=editor custom_api_file=extension_api.json -j$(nproc)
cd ../Kubik/gdext
GODOT_CPP=../../godot-cpp scons platform=linux target=editor \
    custom_api_file=../../godot-cpp/extension_api.json -j$(nproc)
```

`platform=macos` / `platform=windows` for the others; `GODOT_CPP` overrides
where godot-cpp is looked for. Check it loaded:

```
godot --headless --path . -s gdext/check.gd     # "class exists: true"
```

**The API file must come from the pinned binary.** godot-cpp built against a
different 4.x dumps no error and produces a library that loads and misbehaves.

`gdext/bin/` is gitignored, so a fresh clone has no library - and the export
does not shrug that off. Godot copies every library named in
`kubik.gdextension` next to the exe and **fails the export** when one is
missing, which is why the Windows build was red from the day that file was
added until 2026-09-04. Both workflows build it now.
`.github/workflows/selftest.yml` builds the Linux editor library on `main` and
every `feat/**` branch and runs the whole self-test against it, so the port
cannot rot silently. `.github/workflows/build.yml` cross-compiles the Windows
`template_release` library with mingw-w64 on the same Linux runner, against the
same pinned godot-cpp commit and the same API dumped from the same 4.7.2
binary, and gates the export on it: the `.dll` is a 64-bit PE that exports
`kubik_library_init` and imports nothing but `KERNEL32` and `msvcrt`, it lands
beside `Kubik.exe` in the artifact, and `kubik.gdextension` is in the pck. So
the Windows artifact under **Builds** below ships **with** the compiled
extension - all three classes - not the GDScript fallbacks.

### Where it is shot

The game is played **and shot on Forward+, on a GPU, and on nothing else**.
Light v1's grill Q1 retired the Compatibility branch outright: volumetric fog,
SSAO, SSR, soft directional shadows and the colour adjustment do not exist
there, and pillar 2 needs all of them. The overnight box, ganymede, has an
RTX 3070 Ti and renders Vulkan Forward+ under a virtual display; every tour and
gallery sheet since distance v1 was taken there, and that is where anything
visual is checked (`CLAUDE.md` § Where work runs):

```
export XDG_RUNTIME_DIR=/tmp/xdg-$USER && mkdir -p $XDG_RUNTIME_DIR
xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . -- --tour --seed 42 --label <name>
```

The first console line must say `Vulkan 1.4 - Forward+ - Using Device #0:
NVIDIA`. Status docs from before 2026-08-27 (world feel v1, look v2) were
rendered on Mesa llvmpipe in Compatibility because the box had no Vulkan driver
then; their frames and numbers are history, not references. The `opengl3`
second run those docs describe is gone with the branch it tested.

**The flags a tour takes.**

| flag | what it does |
| --- | --- |
| `--seed <n>` | the world. 42 everywhere in the status docs |
| `--label <name>` | the directory under `build/tour/` |
| `--weather eerie` | D7's weather: saturation down, fog thick and inverted, every warm light off |
| `--lens off` | D40's film lens off - the grain, the vignette, the glow and the grade together, so "lens off" is one state |
| `--set <name>=<value>` | any config knob, hashed or local |

**Two sheets, not one** (light v1 Q4), from `scenes/character/gallery.tscn`:

```
godot --path . scenes/character/gallery.tscn -- --sheet transfer --strict --label <name>
godot --path . scenes/character/gallery.tscn -- --sheet light --label <name>
```

`transfer` is the **gate**: eight authored colours on an unshaded material with
the tonemap forced to LINEAR and the glow, the grade and the atmosphere switched
off for the sheet alone, measured within **6 units per sRGB channel** of the
authored hex. It proves there is exactly ONE conversion between `push_back` and
the frame, and `--strict` makes a miss a non-zero exit. `light` is a
**measurement and not a gate**: the same eight through the real material under
the real environment, lit and in shadow, at each of the four hours, written to
`light.json`. The bible's hexes are starting points, so a delta there is a
finding rather than a failure.

**The cost line comes from the tour** (light v1 Q23). `_report_cost` measures
twenty frames at each settled vantage and prints the worst and the median beside
the primitive count. The number that matters is the worst per-shot frame across
the five hour shots and `5-lake`, with the lens on and off. The streaming probe
below answers a different question - whether the ground keeps up while you move -
and does not currently exit; see `docs/status/light-v1.md`.

### The streaming probe

Whether the ground keeps up with the player, which is a different question from
whether it arrives at all:

```
godot --headless --path . -- --host --seed 42 --stream-probe
godot --headless --path . -- --host --seed 42 --stream-probe --strict
```

Twelve 48 m jumps, then a 13 m/s sprint 240 m out and back in real frames,
sampled four times a second. It reports how far ahead the collidable ground
reaches, how many wanted columns are neither voxels nor far mesh (**holes** —
this must be zero), the worst frame, and chunks built per second. `--strict`
makes a hole or a frame over 33 ms a non-zero exit.

`--flora-probe` is the same shape for ground cover, and
`--traverse --view low` walks the map diagonal.

### The sprint probe

**The north star's third line as a number** (horizon v1): sixty seconds
sprinting from the spawn along `+X`, in real frames, at whatever preset you
name.

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -- --host --seed 42 \
    --view ultra --sprint-probe --seconds 60 --label mine
```

It drives the body with the same wish and sprint bits a player sends, presses
Space when it has not moved half a metre in half a second (a wedged run is not
a sprint, and the first two baselines wedged), and writes a per-second line plus
one summary:

```
SPRINT label=mine seconds=60 frames=3340 median_ms=16.67 p99_ms=40.44
  worst_ms=84.44 over25=171 chunks=6535 far_rebuilds=67 far_ms_median=100
  tree_rebuilds=3 mem_mb=431 moved_m=543 jumps=10 tiles=172 tile_mb=25
  rebases=0 jitter_mm=0.000
```

`moved_m` is the honesty check - a run that went nowhere warns and says so.
`rebases` counts floating-origin moves and `jitter_mm` is how far a standing
body drifted in a frame, which is 0.000 at thirty kilometres. The gate is
**median under 16.7 ms and no frame over 25**; `docs/status/horizon-v1.md`
carries the line and what is still over it.

Three flags exist for the shrink list and change nothing about the world:
`--no-volumetric`, `--no-tree-shadows`, and `--set chunk_upload_budget_ms=N`.

### Getting somewhere, and switching the air off

```
godot --path . -- --host --seed 42 --tp 30000 30000    # teleport, host only
godot --path . -- --tour --seed 42 --fog off           # every fog term zero
```

`--tp` takes WORLD metres and drops the player on the ground there, building
whatever has to be built on the way; it is how any measurement past the home
region is taken. `--fog off` zeroes the exponential term, the height term, the
volumetric field and the Stage 5 distance ramp, which is what a colour window
on a hillside at 8 km has to be measured through - otherwise it measures the
fog.

### The view presets are the draw distance

`--view low | medium | high | ultra` and the preset sets the reach: **8, 16, 32
and 32 km**, with the camera's far plane at 1.25x that and the fog ramp
normalised to it. Ultra is what every gate in `docs/plans/horizon-v1.md` is
measured at.

### The horizon self-test

```
godot --headless --path . scenes/selftest_horizon.tscn
```

Ten tests that belong to the far country rather than to the world: the sprint
summary's shape, the local knobs, the tile store and its threads, the far
mesh's 160 keyed pieces against the whole disc, the material pyramid's level 0
against `surface_zone_at` on ten thousand cells, the floating origin's
arithmetic and the anchor rule. `scenes/selftest.tscn` runs the world's own
gates and is unchanged.

### A parse gate that works

`ResourceLoader.load` returns a Resource for a script with compile errors, so
`parsecheck.gd` prints "ok" for a broken file. This does not:

```
godot --headless --path . --check-only --script <file> 2>&1 | grep -c 'Parse Error'
```

The COMPILE errors it also prints are noise - autoloads are not registered in
that mode, so every script naming `Net` reports one. Only `Parse Error` counts,
and it carries the line.

### The pair probe

Two engines, one world — the gate for host-authoritative movement:

```
godot --path . -- --host --seed 42 --pair-probe
```

**No scene argument**, unlike every other probe here: that skips the main menu,
and the main menu is what opens the ENet socket. A host started by opening
`game.tscn` is an offline host, and the only symptom is the client logging
"connection failed" where nobody is reading.

It launches the other half itself — a second headless Godot as a client — has
it sprint 100 m out and walk back under host authority, and reports the
client's own prediction error against the host's opinion of where it is, the
chunks the host built for its collision ring, and whether it ever went below
the surface. It also turns the measured error back into an implied latency and
compares that against the host's own frame time, so a slow machine reports
INCONCLUSIVE rather than a failure it cannot substantiate.

On Marcel's box (Forward+, 4 ms frames): median 0.217 m against a 0.50 m line,
worst 1.300 m against a 2.00 m limit.

### The body probe

```
godot --headless --path . scenes/game.tscn -- --host --seed 42 --body-probe
```

Counts the bodies in a loaded world, shoves one and follows it until it stops,
walks 220 m away and back to check it is still where it was left, and leans on
a boulder of each kind to check the co-op rule: a boulder_l must rock and stay
for one player, a boulder_m must give. **Spawn is a meadow and boulders grow in
rock and above**, so it goes and finds them — a count of zero at spawn is
correct, not a broken stage.

### The character sheets

```
godot --path . scenes/character/gallery.tscn -- --label some-name
godot --path . scenes/character/gallery.tscn -- --label x --sheet outline
godot --path . scenes/character/gallery.tscn -- --label x --sheet tiers
```

Sixty-odd images into `build/character/<label>/`, plus four tables that print
and write nothing: `budget` (triangles and the retained voxel list),
`masks-40` (silhouette IoU, target every race pair under 0.70), `outline` (the
armour tier ladder, counted rather than judged) and `palette-tiers` (every
race's five value tiers, measured against what was authored).

**The counts are the gates and the pictures are not.** Two runs of the same
commit differ on every lit sheet on this GPU - mostly by one least-significant
bit, worst case 1.5% of an image - so `tools/png_diff.py` compares them against
a tolerance rather than for equality. Frozen-pose strips, mask sheets and swatch
sheets ARE bit-stable and may be diffed exactly. See `docs/status/character-v2.md`.

### The swatch check

The one gate that says whether an authored colour is the colour on screen:

```
godot --path . scenes/character/gallery.tscn -- --sheet swatches --strict
```

Eight authored colours drawn lit and in shade, sampled out of the frame and
compared with `Look.predict()`, which mirrors the lighting ramp line for line.
Every swatch must land within **6 sRGB units per channel**; `--strict` makes a
miss a non-zero exit. Run it on both renderers after any change to a palette, a
shader, a mesh builder or the time-of-day table. `--sheet swatch-ramp` is the
same instrument one level down: it measures what the renderer does to a value
between `push_back` and the screen, and it is what to reach for when the
swatches miss and it is not obvious why.

### Testing multiplayer locally

In the editor: **Debug -> Run Multiple Instances -> 2 instances**, then F5.
Two windows launch. In one, click **Host**. In the other, click **Join** with
the address left at `127.0.0.1`.

Both windows print to the same editor console, prefixed `[Net/host]` and
`[Net/client:<id>]` so you can tell them apart.

### Playing with somebody who is not on your LAN

`enet_transport.gd` currently offers port forwarding as the answer for
non-LAN play, and there is a much easier one: **a Tailscale share needs no port
forwarding at all.** Both machines join the tailnet, the client joins the
host's tailnet IP, and ENet sees an ordinary routable address.

Tested 2026-08-27: a **Mac joined a Windows host over Tailscale** and the host
logged the whole handshake — peer connected, world state sent, character
spawned, zero errors. That is world feel v1's host-authoritative input path
carrying a real second player, on a second machine, over a real network, rather
than two processes on one box.

### Skipping the menu

Clicking through the menu on every test run gets old. Anything after a bare
`--` is passed to the game instead of the engine:

```
Godot_v4.7.2-stable_win64.exe --path . -- --host
Godot_v4.7.2-stable_win64.exe --path . -- --join 127.0.0.1
```

Add `--headless` to run with no window at all, which is how the networking is
smoke-tested — the logs tell you everything. `--quit-after N` stops after N
frames, though note headless runs far faster than 60 fps, so N is not seconds.

### Looking at the world without playing it

Three offline tools, all headless. They exist because most of what can go wrong
in worldgen is either invisible from inside the game or only obvious once you
already know what you are looking at.

```
# Self-tests: mesher winding (with and without baked AO), the AO cost in
# quads and ms, tree chunk borders, determinism, edits landing in a chunk
# that is still generating, the day cycle, and the config half of the join
# handshake. Exits non-zero on failure.
#
# A SCENE, not --script. --script replaces the main loop and Godot only
# creates autoloads for a real one, so World - which names the Net autoload -
# cannot even be compiled under it.
godot --headless --path . scenes/selftest.tscn

# What a given seed actually produced: altitude spread and percentiles,
# per-layer and measured slope, the share of map under 5 and 10 degrees,
# zone shares, lakes, trees, object scale against real-world sizes, and a
# hash of every altitude.
godot --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42

# How the grass keeps up with a moving player: jumps 48 m six times and
# back, times the terrain and the flora separately after each jump, and
# reports columns built - which is where the flora cache shows up as zero.
godot --headless --path . -- --host --seed 42 --flora-probe

# Six screenshots - summit, forest, valley, lake, and a postcard framing
# a mountain, its forest and a lake together. Writes to build/tour/, or to
# build/tour/<label>/ with --label, so before and after sets can sit side
# by side and be compared.
godot --path . -- --tour --seed 42 --label some-name
```

Run the probe twice with the same seed and every line must match. Run it on the
other player's machine and it must still match — that is the whole terrain
contract, checked.

Pressing **F6** on `scenes/game.tscn` also works: with no session, the game
takes the host role without opening a socket.

### Controls

| Input | Action |
| --- | --- |
| Mouse | Orbit the camera |
| `W` `A` `S` `D` | Walk, relative to where the camera is looking |
| `Space` | Jump — or fly up, in noclip |
| `Ctrl` | Fly down, in noclip |
| `F` | Toggle noclip free-flight. A debug tool, not a mode |
| `G` | Toggle a test slab of blocks — scaffolding, see below |
| `F3` | Debug readout: seed, position, zone, fps, chunk timings |
| `F4` | Worldgen tuning panel |
| `F5` | Re-read `user://worldgen.tres` and rebuild |
| `F7` | Reroll the world (host only) |
| `Esc` | First press frees the cursor, second returns to the menu |

The camera is **third person only**, by design — see `docs/DESIGN.md`.

`G` exists to prove the authority chain works before we have block interaction:
press it on the **client** and the blocks appear on both machines, because the
client only sent a request and the host broadcast the result back.
---

## Builds

Every push to `main` builds a standalone `Kubik.exe` on GitHub Actions
(`.github/workflows/build.yml`), and every push to `main` and to every
`feat/**` branch runs the whole self-test against a freshly built extension
(`.github/workflows/selftest.yml`), so the C++ port cannot rot silently.

**To get one:** repo -> *Actions* tab -> click the newest `build` run ->
download the `Kubik-windows-...` artifact at the bottom. Unzip and run
`Kubik.exe`.

- The `.pck` is embedded, so it really is one file.
- It is unsigned, so Windows shows *"Windows protected your PC"* on first run.
  *More info -> Run anyway*. Warn whoever you send it to, or they will assume
  it is broken.
- `BUILD_INFO.txt` in the zip records the commit the build came from.
- Downloading an Actions artifact requires a (free) GitHub account. If we ever
  want a plain public link, we add a tag-triggered Release.

### The public checkout is source, not a runnable game (D50)

The bought templates are the only character source and the bought trees are the
only forest, so a checkout of this public repo has no characters and no forest.
That is decided, not a gap: **the public repo is code to read.** Development
and testing run on machines that mount all three repos - this one,
`Kubik-bible` and the private `Kubik-assets` - and CI without assets builds the
extension and runs the asset-free self-tests (worldgen, meshing, determinism),
which it already does. The Windows artifact above is built the same way and
ships treeless.

### All players must run the same build

Kubik never sends terrain over the network, only the seed and the worldgen
config - every machine regenerates the world from them. Two builds with even
slightly different terrain code therefore produce two *different* worlds from
the same seed, and neither machine reports an error. You would just see the
other player's capsule walking through solid rock.

Check `BUILD_INFO.txt` matches before blaming the netcode.

---

## Layout

```
assets/textures/     one 16x16 greyscale placeholder, no longer used
assets/characters/   the character part data, and .vox drop-ins that replace it
assets/fonts/        the UI faces
assets/ui/           the UI theme
assets/purchased/    (git-ignored) paid art mounted from the private
                     Kubik-assets repo by scripts/tools/sync_assets.py
gdext/src/           the C++ GDExtension: far mesher, height tiles, chunk mesher
scenes/              main_menu, game, player, remote_player, selftest, gallery
scripts/net/         transport seam, ENet implementation, Net autoload
scripts/world/       worldgen config, heightmap, terrain generator, lakes,
                     chunk, greedy mesher, column job, far field, look, sky,
                     valley fog, flora, world
scripts/character/   the character view, the purchased-template path
scripts/physics/     locomotion, bodies, the push
scripts/player/      player character, remote player capsule
scripts/ui/          main menu, HUD, debug readout, tuning panel, the film lens
scripts/game/        join handshake, player sync, stats, the journal
scripts/tools/       headless self-tests, probes, screenshot tour, asset sync
tools/parts_author/  the generated-parts kit (ripped; parked, not deleted)
docs/plans/          one work order per epic
docs/status/         one status doc per run
docs/reconciliation/ the four audits of this repo against the bible
```

---

## Purchased assets

Some art is bought, not made: licensed for use and modification in the game,
not for redistribution as source. That content lives in the **private**
[Kubik-assets](https://github.com/FrostyyTiger/Kubik-assets) repo - archived
packs plus a curated `game/` subset - and is mounted into this (public) repo at
`assets/purchased/`, which is git-ignored, by `scripts/tools/sync_assets.py`
(clone Kubik-assets as a sibling directory and run it after every pull of that
repo).

Two rules hold:

- **Nothing from the private repo is ever committed here**, in original or
  modified form, and its colours never leak into this repo either - indices and
  Kubik family names only (D50).
- **A checkout without `assets/purchased/` still builds, still passes the
  asset-free self-tests, and is not a playable game.** The old rule - that the
  game must always run with the purchased art absent, as a drop-in layer over
  authored fallbacks - is retired by D50. The bought templates are the
  character path (D1) and the bought pack is the forest (trees v3); there is no
  authored fallback behind them and there is not going to be one.

Tenants: the tree library, the viking / dwarf / elf character templates, the
animal warriors, the weapons pack, and the Voxel Forest Animals Pack at
`assets/purchased/creatures/<species>/`.

## Known provisional bits

Things that work but are explicitly not final. They are marked in the source at
the point where they need replacing.

- **~~Players report position, not input.~~ CLOSED in world feel v1 Stage 10.**
  Clients send input (`Game._srv_report_input`), the host simulates every remote
  body through the same `Locomotion.step` the client predicts with, and the host
  broadcasts the result. A client can still only move itself, and now it can
  only move itself the way the rules allow. The host also streams a
  collision-only ring around every peer so there is ground under them —
  `WorldgenConfig.sim_radius_chunks`.
- **No rollback on the client.** What replaced the carried ticket is not the
  whole of client-side prediction. The local body predicts with the same step,
  and when the host's position for it arrives the client eases (under 2 m) or
  snaps (over) — see `Game._reconcile`. It does not replay the inputs the host
  had not yet processed when it sent that position, so a correction lands where
  the player *was* rather than where they will be.

  The shape a rollback would take, so the next person does not have to
  rediscover it: a sequence number on each input; a ring buffer of the last N
  inputs on the client; the host echoing the last sequence it consumed in the
  table row; and on a correction, snap to the authoritative state and re-run
  every buffered input newer than the echoed sequence. About forty lines. It is
  not worth them until there is something in the world worth being precise
  about — the error it removes is the error a player only notices when
  something is shooting at them.
- **~~Meshing is GDScript.~~ CLOSED in mesher v1** (2026-09-04, phase 1b, D56).
  **Column GENERATION is still GDScript**, and GDScript is serialised across
  the worker pool - measured in world feel v1 at about one effective worker
  thread whatever the job cap says - so the levers there are still how much
  work a column costs and how few there are, not parallelism. The generator's
  truth crosses to C++ in the world-truth break, not before, because that is
  a change to what a seed produces (D56).
- **The block texture is unused, and it always will be.** Terrain is flat
  vertex colour, so `assets/textures/block_placeholder.png` and its committed
  `.import` settings are not read by anything. **The texture atlas that used to
  be the reason for keeping them is off the roadmap for good**: pillar 2 says
  no textures, on anything, ever. Both files are kept only because deleting
  them buys nothing.
- **Water reflects but is still scenery.** Light v1 made it clear, depth-tinted
  and reflective with a Fresnel term and SSR. It still has no physics, no
  wading and no swimming; Water v1 owns those.
- **The far field is a separate mesh from the voxels**, so there is a boundary
  where one gives way to the other. Since world feel v1 the seam is where the
  voxels have actually ARRIVED rather than where they are expected — see "the
  frontier rule" in `docs/DESIGN.md` — so it moves, but there is never a hole
  in it. Horizon v1 is the lane that makes the two agree on colour as well as
  on geometry.
- **The four-race character path still runs.** `scripts/character/races.gd`,
  the creation screen's race row and the parts kit's output are all on the rip
  list under D37, D51 and D70. They are behind nothing yet; they go when the
  bought templates land in phase 3, people and fire.

## Roadmap

The queue is [TODO.md](TODO.md); the order and the reasons are
[RECONCILIATION.md](RECONCILIATION.md) § 9 and
[docs/ROADMAP.md](docs/ROADMAP.md). The phases, from the reconciliation as
reordered by D84 on 2026-09-04 and D85 on 2026-09-05:

| | Phase | State |
| --- | --- | --- |
| 0 | Housekeeping: the house generator into `Kubik-assets`, the licence records, the asset mount | in progress |
| 1 | **Real light** | **done**, merged 2026-09-04 |
| 1b | **The chunk mesher in C++** (D56) | **done**, merged 2026-09-04 |
| 1c | **Horizon v1** - the view to the horizon and a world with no edge (D41, D44, D84) | **done**, merged 2026-09-05 |
| 1d | **Upload v1** - the chunk and flora upload off the frame thread (D85); the hitch half of the frame gate horizon v1 left open | running from 2026-09-05 |
| 2 | The world-truth break (D56 as amended by D84 and D85): real relief (D45), rings from the capital (D44), lakes and zones per tile, the generator's truth in C++ | right after 1d |
| 3 | People and fire: the bought templates as the character path, two players at a campfire | queued |
| 4 | Buildings: the loader, placement, the landmark gate | queued |
| 5 | The round 3 scene and its report | queued |
| 6 | The journal with typed facts and IDs, the nouveau UI, creatures, combat and death | months |

**No texture atlas, ever** (pillar 2). **No base building, ever** (pillar 2).
**No party frame, ever** (D46).

## Licence

MIT — see [LICENSE](LICENSE). The licence covers this repo's code and authored
content only; purchased art (see **Purchased assets**) is proprietary,
lives outside this repo, and is not MIT.
