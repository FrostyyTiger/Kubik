# Kubik

A two-player co-op voxel exploration game. Godot 4, GDScript, MIT licensed.
Open source hobby project and a learning exercise.

Think Cube World's readability with Minecraft's building blocks: a chunked
voxel world you and one friend explore together, one hosting and one joining.

> **Status: early.** Right now you get generated terrain, a fly camera, and two
> instances that see each other. There is no player character, no collision, and
> no way to break or place blocks yet.

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

Both machines generate identical terrain locally from a shared 64-bit seed. The
host picks it and sends it once during the join handshake. After that, the only
world data on the wire is the **edit dictionary** — the difference between what
the seed generates and what the world actually looks like.

That makes generation determinism a hard requirement. No `randf()` in
`TerrainGenerator`, no dependence on iteration order, no floats that might round
differently. Break it and the two players quietly end up in different worlds.

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

### 5. Chunks

16x16x16 blocks, stored as a flat `PackedByteArray` — one byte per voxel, one
contiguous allocation, serialises as-is. Index order is `x + z*16 + y*256`.

Coordinate conversion floor-divides rather than using integer division.
Truncation towards zero puts block `-1` in chunk `0` instead of chunk `-1`,
which corrupts a band of world on the negative side of the origin only, and is
a miserable thing to debug. See `Chunk.floor_div`.

---

## Running it

You need **Godot 4.4 or newer** (standard build, no C# needed) from
[godotengine.org](https://godotengine.org/download).

1. Open the Godot project manager, *Import*, select `project.godot`.
2. First open takes a moment while Godot imports the block texture.
3. Press F5.

### Testing multiplayer locally

In the editor: **Debug -> Run Multiple Instances -> 2 instances**, then F5.
Two windows launch. In one, click **Host**. In the other, click **Join** with
the address left at `127.0.0.1`.

Both windows print to the same editor console, prefixed `[Net/host]` and
`[Net/client:<id>]` so you can tell them apart.

### Controls

| Input | Action |
| --- | --- |
| Mouse | Look |
| `W` `A` `S` `D` | Fly horizontally, relative to where you are looking |
| `Space` / `Ctrl` | Fly up / down (world vertical) |
| `G` | Toggle a test slab of blocks — scaffolding, see below |
| `Esc` | First press frees the cursor, second returns to the menu |

`G` exists to prove the authority chain works before we have block interaction:
press it on the **client** and the blocks appear on both machines, because the
client only sent a request and the host broadcast the result back.

---

## Layout

```
assets/textures/     one 16x16 greyscale placeholder, tinted per block type
scenes/              main_menu, game, remote_player
scripts/net/         transport seam, ENet implementation, Net autoload
scripts/world/       block table, chunk, terrain generator, mesher, world
scripts/player/      fly camera, remote player capsule
scripts/ui/          main menu
scripts/game/        join handshake and player sync
```

---

## Known provisional bits

Things that work but are explicitly not final. They are marked in the source at
the point where they need replacing.

- **Players report position, not input.** A noclip debug camera has no movement
  rules a host could validate, so clients currently send their camera position.
  When the player becomes a physics body, `Game._srv_report_state` carries input
  instead and the host simulates. The shape is already right — the host owns and
  distributes the table — only the payload is wrong.
- **Naive meshing, single threaded.** One quad per exposed face, built on the
  main thread across an 8 ms-per-frame budget. Greedy meshing and a worker
  thread come once we can measure that this is the bottleneck; the world already
  prints its build time so there is a number to beat.
- **Fixed 5x5 chunk area.** No streaming as players move.
- **No collision.** Nothing to collide with yet.

## Roadmap

- Block interaction: voxel raycast, break and place, through the existing
  request path
- Real player: physics body, collision against chunk meshes, input to host
- Chunk streaming around players
- Greedy meshing + threaded mesh building
- Texture atlas with per-face UVs
- GodotSteam transport

## Licence

MIT — see [LICENSE](LICENSE).
