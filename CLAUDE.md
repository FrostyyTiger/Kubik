# Kubik

Rewritten 2026-09-03 against the bible, amended 2026-09-04 for the north star
(D84) and 2026-09-05 for the upload (D85). Everything below agrees with the
bible as of D85; where an older document in this repo disagrees, it is stale
and the bible wins.

## What decides things

- **The bible is the direction.** The sibling repo `../Kubik-bible`: tone
  (`00-TONE.md`), art (`style-bible/`), lore (`lore/`), director
  (`director/`), the decisions log (`03-DECISIONS.md`, D1 onward), the assets
  plan and the round 3 brief. This repo is the translation of it into a game.
- **Decisions have numbers.** A thing is decided when it has a D-number in the
  bible. Anything else is a proposal. If work here finds a bible rule wrong,
  too expensive or impossible, do not edit the bible from this side: write the
  finding into the report of the current phase and it becomes the next
  D-number. Check the "Next number" line before logging one; two sessions
  share the bible repo, so fetch and rebase before pushing.
- **The audit.** `RECONCILIATION.md` is what in this repo stays, is adapted,
  ripped or redone, with the twelve decisions it raised (D44 to D55) and the
  order of work in section 9. The four detailed audits with every file:line are
  in `docs/reconciliation/`.

## The tone, above everything

`../Kubik-bible/00-TONE.md` (D38, D39, D40). The world is magnificent because
it fell; you are small, it is huge, you will not understand all of it, and you
keep walking. Nothing cute, no comic relief, no villain with a speech, no
frantic survival, no graphic violence, no horror dressing. Warmth and earned
humour between the two players are welcome; the world is grave, the friendship
is not. When a rule below cannot decide, the tone decides.

## Gameplay pillars

Four. Every feature serves at least one and contradicts none. They sit under
the tone and beside the five art pillars.

- **BETTER TOGETHER.** Two people who walk between. The game allows four and is
  designed for two (D46): every encounter, rumour and line of fiction is
  written for two, and there is no party frame, ever. Solo is a dev
  convenience, never a balanced mode.
- **TENSE OUT, WARM AT THE FIRE.** Danger and pacing scale with distance from
  the current campfire, with eerie weather, and with distance from the capital
  (D35, D63). Firelight
  and daylight are the warm register: light, regen, respawn. Every dread beat
  ends at a fire. Death costs time, not progress, and is quiet and remembered
  (D39). No base building: players place objects (campfire, torch, marker),
  never terrain. No timers, no hunger bars, no alarms.
- **THE WORLD IS THE CONTENT.** Progression is ranging further. What the world
  is comes from distance from the Engineers' capital, in rings (D44, D35);
  what it feels like right now comes from the current fire. The scale is
  monumental against tiny in a real-sized Alps (art pillar 3, D45), seen to the
  horizon (D41).
- **THE WORLD ANSWERS.** Authored truth, generative direction. The game owns
  all truth and a structured event log; at campfire rests a model proposes
  small, validated actions through five verbs, and the game is complete and fun
  with it off. Doctrine, verbs and the eight hardening rules:
  `../Kubik-bible/director/` (D34, D35, D36).

## Art pillars

`../Kubik-bible/style-bible/00-pillars.md`, one line each:

1. Mass is plain, edges are gold.
2. Real light on flat cubes, through a film lens. No textures, on anything,
   ever. One body colour per material in three shades plus per-cube noise;
   mood comes from light, fog, the hour and the lens, never from repainting.
3. Monumental against tiny, in a real-sized Alps, with the view to the horizon.
4. Two colour families and one warm colour.
5. Deco is for the built and the dressed; nature stays nature; Art Nouveau on
   paper only (UI, cards, map).

## The three habits

Cheap now, and what the fourth pillar asks of every plan:

1. **Facts as data, not prose in code.** Creature goals, what a place is, lore
   fragments, a quest's allowed outcomes: tables. A director can only steer
   what it can read, and it reads facts by ID (D34 rule 1).
2. **Keep the journal.** The host sees every event: edit, death, campfire, kill,
   first sight of a lake. Log them as structured events. A chronicler turns
   them into typed facts with IDs; that is the director's input.
3. **Everything through the one mutation path.** The director proposes; the
   host validates and applies, exactly as a client's block edit is treated.
   Nothing generative ever touches state directly.

## Rule

When Marcel proposes a feature, check it against the tone, the pillars, the
decisions and the current phase, and push back if it contradicts them or jumps
the queue.

- The director acts only through the verb list in
  `../Kubik-bible/director/10-verbs.md`. Features that need the model to invent
  world-truth: reject and flag.
- Base-game milestones precede director milestones. The director's v0 needs
  the journal, the campfire and a first creature playtest before any model
  call exists.
- Sunk cost is not an argument. The test for every system is: would you build
  it this way today, for the bible?

## World rules

- **The north star (Marcel, 2026-09-04, D84).** Three things outrank every
  knob and every older sentence in this repo: **the world is as big as the
  view** (terrain on demand, no edge, no region); **the view reaches the
  horizon** (32 km on a clear day, fog as a ramp on that distance and never a
  wall, nothing pops in); **the frame holds** (60 FPS at max settings on mid
  hardware, an RTX 3070 Ti, measured while sprinting through forest; well
  above that on a 5080). No document here may set a world size, a view
  distance or a fog edge that argues with these; where one still does, it is
  stale.
- **Unbounded terrain, ringed content (D44).** The terrain is seeded and has no
  wall and no edge; no system may bake in a world edge, a global heightmap or
  a global-extent assumption. The content is ringed from the capital (rings 0
  to 4, `../Kubik-bible/lore/10-geography.md`) and ends at the Builders' city,
  the last authored place. Nothing generates "a region": terrain is built on
  demand in origin-anchored tiles wherever the player or the far view asks
  (`docs/plans/horizon-v1.md`). The home 3 km is where lakes, spawn and the
  zone shares are still computed until the world-truth break; it is
  bookkeeping, never an edge. Edge and direction treatment stay configurable.
- **Real relief (D45).** 1,400 to 2,500 m from valley floor to peak, trees at
  real size (D21), one ratio everywhere. The vista rule: from every campfire,
  village and pass, a whole mountain and the next landmark fit in frame at the
  default field of view. Sightlines are a worldgen rule. Lands with the
  world-truth break, the lane after upload v1 (D84, D85).
- **Heightmap terrain, placed volumes (D47).** No overhangs from the generator.
  Gates and dungeons are models against a cliff with a separate interior volume
  stitched in behind the door.
- **World truth changes once (D56).** Anything that changes what a seed
  produces (relief, rings from the capital, the tiled heightmap store, the
  generator in C++) lands in one epic, the world-truth break, which runs
  right after upload v1 and before people and fire (D84 and D85 amend D56's
  timing, not its bundle), before any content is authored on a seed. Terrain is never networked; both machines
  regenerate it from the seed and only edits travel.

## Engine rules

- **Godot 4, hot paths in C++ (D42, D49).** The GDExtension is a build
  requirement on every platform. GDScript orchestrates; chunk meshing, column
  generation, the far field, streaming and chunk sync live in `gdext/`. The
  old rule that the game must run without the compiled library is retired;
  delete each GDScript twin as its C++ path lands.
- **Keep the seam discipline.** Data in, arrays out, marshalled once per world;
  engine noise sampled natively; every height quantised to 1/1024 block on
  both sides, so gcc and MSVC cannot produce two worlds.
- **The mesher decides how a chunk looks, never what it is.** It can be
  replaced at any time without breaking a world.
- **The view reaches the horizon (D41, raised by D84).** Far terrain and
  buildings draw to 32 km on a clear day as coarse meshes from persistent
  tiles; fog is a ramp normalised to that distance and never a wall; nothing
  pops in; positions live on a floating origin, so the world is unbounded in
  practice and not only in principle. `docs/plans/horizon-v1.md` was the work
  order; it landed on 2026-09-05 (`docs/status/horizon-v1.md`).
- **The public checkout is source, not a runnable game (D50).** Purchased art
  lives in the private `Kubik-assets` repo and is mounted by
  `scripts/tools/sync_assets.py`; it is never committed here, and its colours
  never leak into this repo (indices and Kubik family names only). Development
  and testing run on machines that mount all three repos. CI without assets
  builds the extension and runs the asset-free self-tests.

## Where work runs

- **Implement and check on ganymede.** The server (Ubuntu 24.04, RTX 3070 Ti,
  NVIDIA driver 595, `~/bin/godot` 4.7.2, `~/Kubik`, `~/godot-cpp`) renders
  **Vulkan Forward+ on the GPU** under `xvfb-run -a -s "-screen 0 1280x720x24"`;
  export `XDG_RUNTIME_DIR` to a writable directory first. It has done since
  2026-08-27 (`STATUS.md` item 6: the compute-only driver was the only thing
  missing). Every overnight run, every tour, every gallery sheet and every
  probe is taken there, and anything visual is judged from a shot taken there,
  never guessed from numbers. Any document that says ganymede is llvmpipe,
  Compatibility or "no Vulkan" describes the box before that date.
- **The first console line of a run must read** `Vulkan 1.4 - Forward+ -
  Using Device #0: NVIDIA GeForce RTX 3070 Ti`. Anything else is a
  stop-and-record before the first stage. The ALSA errors under it are the
  missing sound card and mean nothing.
- **Pull before you start.** Ganymede's checkout lags `main` between runs;
  `git pull --ff-only` and `--import` come before the baseline.
- **Marcel's Windows box (RTX 5080)** is where the game is played, where the
  final cost line of a phase is re-measured, and where Marcel looks at things
  with an agent in the loop. Overnight work does not run there.

## Character and asset rules

- **Templates as they are (D1).** Characters are the bought viking, dwarf and
  elf templates, reskinned clothes only, rigs and proportions unchanged,
  driven by the packs' clips. Nothing generates a body.
- **Only humans (D37, D51).** Dwarfs and elves are body types and stages of
  change within one people; the animal warriors are the Perchten. Character
  creation offers body type, palette, hair or hat, name, and no perks.
- **Four grains (D1, D21, D43, D53).** World cube 0.5 m; tree voxel 0.125 m;
  character voxel about 3.3 cm; forest-animal voxel about 1.9 cm. Buildings
  are generated at the tree grain in `Kubik-assets` and baked through the tree
  pipeline with three level-of-detail rungs (D48); the game loads them with a
  sibling of the tree loader and places them with a pass that owns roads,
  footprints and flattening. Player-placed things stay at 0.5 m.
- **Armour is a tech level (D27).** Mountain folk in leather, fur, wool, felt,
  mail, wood and horn; plate is the Engineers' guard. No tier ladder to plate.
- **Player magic (D54, D65).** A fire rune and a frost rune, a spark and a
  chill, never a storm; weak in the thin centre, stronger with every ring
  outward (D63); a rune stone is a crystal that dims with use and is recharged
  at a magic site (D76).

## Working order

From `RECONCILIATION.md` section 9. Nothing from a later phase is pulled
forward except where the table says so.

0. Housekeeping: the house generator and its outputs committed to
   `Kubik-assets`; the seller links in its licence records; the asset mount
   synced.
1. Real light - **done** (`feat/light-v1`, merged 2026-09-04): the poster
   renderer out; the engine's sun, soft sky-tinted shadows, sky ambient,
   filmic tonemap; the four hours plus eerie; volumetric fog's three jobs; the
   bible palette; the film lens (D40); reflective water.
1b. The chunk mesher in C++ (D56) - **done** (`feat/mesher-v1`, merged
   2026-09-04, `docs/status/mesher-v1.md`), in parallel with 1c.
1c. Horizon v1 - the view to the horizon and a world with no edge (D41, D44,
   D84) - **done** (`feat/horizon-v1`, merged 2026-09-05,
   `docs/status/horizon-v1.md`): the median sprint frame 41.67 -> 16.67 ms at
   Ultra with the view 3.2 -> 32 km. The hitch half of the frame gate is open
   and is 1d's.
1d. Upload v1 (D85) - the chunk and flora upload off the frame thread. With
   generation and meshing off the main thread, what is left on it is
   `add_surface_from_arrays` plus a collision shape per column, 214 columns a
   second, and that is the whole hitch column of horizon v1's sprint line;
   a smaller upload slice makes it worse (measured, Stage 7). Fewer, larger
   surfaces per column, or a mesh handed to the rendering server without the
   frame thread touching it. Look-only: changes nothing a seed produces. Runs
   next, alone. Plan `docs/plans/upload-v1.md`, launched 2026-09-05 on
   ganymede in tmux `upload-v1`.
2. The world-truth break (D56, timing amended by D84 and D85): real relief
   (D45), rings from the capital (D44), lakes and zones per tile, the
   generator's truth in C++. Right after 1d lands. Draft at
   `docs/plans/world-truth-v1.md`.
3. People and fire: the viking templates as the character path, two players
   at a campfire, the campfire as the first warm light.
4. Buildings: the loader, placement, the landmark gate.
5. The round 3 scene and its report (`../Kubik-bible/ROUND-3-BRIEF.md`), into
   `../Kubik-bible/discussions/11-ROUND-3-REPORT.md`.
6. The journal with typed facts and IDs, the nouveau UI, creatures, combat and
   death.

When Marcel says "do phase N": start from `RECONCILIATION.md` section 9 and the
bible files it names, write the plan in `docs/plans/` in the shape of
`docs/plans/look-v2-tech.md` (contract, binding pre-run answers, tunable versus
not, failure protocol, gates), run it, and write the status into
`docs/status/`.

## Where things live

Rewritten 2026-09-04 by the docs-only sync, which brought every file below
into line with the bible as of D84. No file here is marked "pending rewrite"
any more; the one paragraph still owed is named at the end.

- `../Kubik-bible/` - the direction; read it before anything here
- `RECONCILIATION.md` - the audit of 2026-09-03, the twelve decisions it
  raised (D44 to D55), and § 9, the order of work, reordered for D84
- `docs/reconciliation/` - the four detailed audits, with every file:line
- `README.md` - the pitch and the four gameplay pillars under the tone; the
  architecture contract (host authority, one mutation path, terrain never
  sent, the transport seam, the world as big as the view, the director's
  five verbs); running it, the probes, the C++ build; builds and the public
  checkout (D50); the provisional list; the phases
- `docs/DESIGN.md` - the game's TECHNICAL truth and nothing else: the
  renderer as light v1 built it, the colour pipeline, the four grains and the
  resolution ladder, the frontier rule, physics, traversal, camera (D57),
  saves, placeables, multiplayer, the creature behaviour stance. Setting,
  peoples, art rules and scale point into the bible rather than restating it
- `docs/DIRECTOR.md` - a pointer to `../Kubik-bible/director/`, plus the four
  things this repo must not get wrong and what the pivot changed (D74, D77,
  D79, D80, D83)
- `docs/IDEAS.md`, `TODO.md`, `docs/ROADMAP.md` - the queue and why it is in
  that order, built around the phases. Out for good and recorded as out: the
  sea as a separate age (D26, D44), attacks on the fire and a night-hostility
  dial (D39), more races (D37, D70), Look v3 "the painted world" (pillars 2
  and 5, D2), and a texture atlas (pillar 2)
- `docs/research/` - evidence, never authority. `art-direction.md` carries a
  reading note saying so; its method and its colour-transfer finding stand
- `docs/plans/`, `docs/status/` - one plan and one status per epic; the look
  plans are history and carry a superseded header, and `look-v2-tech.md`'s
  SHAPE is still the work-order template
- `STATUS.md` - what is running and what last merged

**Still owed, and deliberately not touched on 2026-09-04:** `README.md`
§ Running it, which the horizon v1 and mesher v1 lanes own. Its "Three things
are C++, and you do not need any of them" heading and its "you can ignore all
of this and the game works" paragraph are the last of the retired hard rule
one (D49: the compiled library is a build requirement on every platform, and
each GDScript twin is deleted as its C++ path lands). Rewrite it when the
lanes are done with the file.
