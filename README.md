# Kubik

## What is this

Kubik is a 2-4 player co-op voxel exploration game (designed and tuned for
pairs) set in a cozy-but-eerie fantasy Alps. An authored world with a
generative director: the game quietly notices what your party does and
answers at the campfire. Open source (MIT), Godot 4, built by two friends (and
playtested by four) as a learning project in both gamedev and AI-native game
design.

**Core loop:** we roam a generated alpine world together, fight what lives in
it, and grow stronger from what it drops, pushing further from the safety of
firelight into stranger territory - while the world reads our journey and
answers: fragments that reflect our deeds, rumours that point somewhere,
quests whose middles nobody - including the developers - has seen before.

### Design pillars

Four. Every feature serves at least one, and contradicts none.

1. **BETTER TOGETHER.** Built for pairs, room for four. Encounters assume two
   bodies; 3-4 players handled by simple scaling. Cap constant: 4.
2. **TENSE OUT, COZY IN THE LIGHT.** Danger scales with distance, altitude,
   and darkness. Firelight and daylight are the warm register. Death costs
   time, not progress. No base building.
3. **THE WORLD IS THE CONTENT.** Progression is ranging further. Distance is
   the difficulty, strangeness, and content axis.
4. **THE WORLD ANSWERS.** Authored truth, generative direction. A semantic
   director reads what the journey MEANS and responds through opportunity,
   never railroading. The tech is invisible: we market the experience, never
   the AI. Doctrine in [docs/DIRECTOR.md](docs/DIRECTOR.md).

Settled details live in [docs/DESIGN.md](docs/DESIGN.md). What is queued and
what is deferred lives in [docs/IDEAS.md](docs/IDEAS.md).

> **Status: early, walkable, and it has a look.** A 3 x 3 km Swiss
> pre-Alpine landscape at 1:4 scale - the first generated region of a world
> that is by design unbounded - meadow valleys, seven tree species that
> clump and leave clearings, bare rock, snow peaks, lakes in real basins, 8.7 M
> pieces of ground cover, fireflies after dark - drawn as an Art Deco travel
> poster: one three-tone lighting ramp under everything, banded fog, a sky with
> rays. Four playable races in stocky voxel bodies with a creation screen, seen
> by every other player. Nothing lives in the world yet, nothing can be broken
> or placed, and the director does not exist: the next playtest is the wolf,
> the marmot and the eagle.
>
> Verified on Godot 4.7.2: both peers generate an identical world from the same
> seed and config (heightmap hash `76cccdb6`, 73,675 trees on seed 42), the
> world and character self-tests pass, and the world is clean of runtime
> errors. See `STATUS.md` for the latest run.

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

### 5. Chunks and the two-scale world

Voxels exist only in a disc around the player — real, editable, collidable
terrain. Everything beyond is one low-poly mesh built from a **coarse
heightmap** at 2 m resolution — today a single global one covering the whole
3 km region. That coarse heightmap is also what makes lakes possible: a basin
is a depression with a rim all the way round it, and you cannot see one by
looking at a chunk.

The world itself is **unbounded by design** (ruled 2026-08-31, overturning
the bounded decision that used to be recorded here — the ruling and the
constraints it inherits are in `docs/DESIGN.md` § World). What survives of
the old argument is the mechanism: lakes need a heightmap wider than a basin,
so an unbounded world gets **regional heightmap tiles**, not no heightmap.
The current single-region build is a stage, and no new system may assume a
world edge or a global extent.

Chunks are 16x16x16 blocks, stored as a flat `PackedByteArray` — one byte per voxel, one
contiguous allocation, serialises as-is. Index order is `x + z*16 + y*256`.

Coordinate conversion floor-divides rather than using integer division.
Truncation towards zero puts block `-1` in chunk `0` instead of chunk `-1`,
which corrupts a band of world on the negative side of the origin only, and is
a miserable thing to debug. See `Chunk.floor_div`.

### 6. The world answers: authored truth, generative direction

The fourth pillar, as architecture. The game has a **Director**: a model that
reads what the party's journey means and improvises the path to authored
stakes - which fragment you find, which rumour points where, how a quest's
middle unfolds. Its doctrine is `docs/DIRECTOR.md`; it arrives late, on the
ladder in `docs/IDEAS.md`. What it asks of the code is decided now, because
it is cheap now and a rewrite later:

- **Facts are data.** What exists, what things want, what can happen - tables
  a program can read, never prose in a script. `Races`, the worldgen config
  and every character part already are: the parts are 101 entries of ASCII in
  `assets/characters/parts/*.json`, read by `PartsData`, generated by
  `tools/parts_author/` and no longer GDScript at all. Creatures, places, lore
  fragments and quest beats follow.
- **The host keeps a journal.** Structured events - edit, death, campfire,
  kill, first sight of a lake - appended as they happen. It is the director's
  input later and a debugging record today.
- **The director acts only through verbs.** It runs beside the host as a
  sidecar process, talks to Godot over local HTTP/WebSocket, and *proposes*
  through the small verb list in `DIRECTOR.md` (place a fragment, spawn a
  rumour, mark a site, advance or reroute a beat). The host validates every
  proposal against the allowed outcomes and applies it through the one
  mutation path - exactly how a client's block edit is treated. It never
  touches state directly, never runs inside the engine's loop, and is invoked
  at campfire rests and session start: state machines own seconds, the
  director owns minutes. No combat, no physics.
- **The game is complete without it.** Every beat it can steer has an
  authored default. Offline, with no key, or in a stranger's build, the
  defaults play. The host pays for it; clients get it through the host.

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

### Both renderers

The game is played on **Forward+** and shot on **Compatibility**, and the two
have been found to disagree about colour more than once. Anything that touches
a colour path is checked on both:

```
godot --path . -- --tour --seed 42 --label <name>
godot --path . --rendering-driver opengl3 -- --tour --seed 42 --label <name>-gl
```

**`--rendering-driver` goes BEFORE the `--`, and the line above used to have it
after.** Anything after `--` is passed to the game rather than to the engine, so
the old form selected no driver at all and silently took the second set of
pictures on Forward+ as well. It is not an error and there is no warning: the
two directories fill up, the images differ by a frame of the day cycle, and
nothing says the comparison did not happen. Found in distance v2 Stage 5, when a
"both renderers" gate produced two identical measurements.

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

Every push to `main` builds a standalone `Kubik.exe` on GitHub Actions. You do
not need Godot to run it, and you do not need to build it yourself.

**To get one:** repo -> *Actions* tab -> click the newest `build` run -> download
the `Kubik-windows-...` artifact at the bottom. Unzip and run `Kubik.exe`.

- The `.pck` is embedded, so it really is one file.
- It is unsigned, so Windows shows *"Windows protected your PC"* on first run.
  *More info -> Run anyway*. Warn whoever you send it to, or they will assume it
  is broken.
- `BUILD_INFO.txt` in the zip records the commit the build came from.
- Downloading an Actions artifact requires a (free) GitHub account. If we ever
  want a plain public link, we add a tag-triggered Release.

### All players must run the same build

Kubik never sends terrain over the network, only the seed - every machine
regenerates the world from it. Two builds with even slightly different terrain
code therefore produce two *different* worlds from the same seed, and neither
machine reports an error. You would just see the other player's capsule walking
through solid rock.

Check `BUILD_INFO.txt` matches before blaming the netcode.

---

## Layout

```
assets/textures/     one 16x16 greyscale placeholder, no longer used
assets/characters/   the character part data, and .vox drop-ins that replace it
scenes/              main_menu, game, player, remote_player
scripts/net/         transport seam, ENet implementation, Net autoload
scripts/world/       worldgen config, heightmap, terrain generator, lakes,
                     chunk, greedy mesher, mesh job, far field, sky, world
scripts/player/      player character, remote player capsule
scripts/ui/          main menu, debug HUD and tuning panel
scripts/game/        join handshake and player sync
scripts/tools/       headless self-tests, worldgen probe, screenshot tour
docs/plans/          implementation plans
```

---

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
- **Worldgen is GDScript, and GDScript is serialised across the worker pool.**
  Measured in world feel v1: 3,742 chunks × 7.6 ms of worker time, in 29.5 s of
  wall clock — about **one** effective worker thread whatever the job cap says.
  So the levers are how much work a chunk costs and how few chunks there are,
  not parallelism. Moving generation and meshing into a GDExtension is the next
  one and it is named in `docs/status/world-feel-v1.md` with the per-phase
  timings that would justify it.
- **The block texture is unused.** Terrain is flat vertex colour, so
  `assets/textures/block_placeholder.png` and its committed `.import` settings
  are not read by anything. Both are kept because a texture atlas with per-face
  UVs is still on the roadmap and the import settings were the fiddly part.
- **Water is scenery.** Flat, translucent, no physics, no swimming.
- **The far field is a separate mesh from the voxels**, so there is a visible
  seam where one gives way to the other. Since world feel v1 the seam is where
  the voxels have actually ARRIVED rather than where they are expected — see
  "the frontier rule" in `docs/DESIGN.md` — so it moves, but there is never a
  hole in it.

## Roadmap

- Block interaction: voxel raycast, break and place, through the existing
  request path
- Threaded chunk generation
- Texture atlas with per-face UVs
- GodotSteam transport

Done in terrain v1: the real player and collision, chunk streaming, greedy
meshing and threaded mesh building.

Done in world feel v1: host-authoritative player input — the client sends
input, the host simulates, the host broadcasts the position.

## Licence

MIT — see [LICENSE](LICENSE).
