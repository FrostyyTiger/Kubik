# Character v1 - who walks the land

Overnight implementation plan. Runs the **same night as `foliage-v1.md`, in
parallel, on its own branch**, and touches none of the same files. Where
terrain v2 built the land and foliage v1 grows things on it, this plan builds
the people who walk it: four races as modular voxel models on a simple rig,
procedurally animated, customisable on one screen, and visible to the other
players.

Decided in a design session on 2026-08-24. Every choice below was made by
Marcel; where the plan says "decided", it means by him, not by this file.

**Why now, against the Next 3.** Characters are not on the Next 3 list, and
`CLAUDE.md` says to push back when something jumps the queue. The argument for
this plan is the one `IDEAS.md` made for terrain: it is a prerequisite, not a
detour. Item 2 (the first enemy) needs an animated rig pipeline, and Stage 13
proves the one built here is not secretly humanoid-only. Item 3 (the campfire)
is sold on "your character sitting at the campfire *is* the progress screen",
which needs a character, a sit pose and gear sockets - all here. And the 180
degree facing bug fixed in terrain v2 has only ever been verified by a formula;
this is the first time anyone will *see* which way the player faces.

---

## How to use this document

Execute it in one pass, top to bottom. **Do not stop to ask questions.** Every
number below is already decided; where a judgement call remains, the rule for
making it is stated. If something is genuinely ambiguous, pick the option that
keeps the game running and record the choice in `docs/status/character-v1.md`.

Before starting, read `CLAUDE.md`, `README.md`, `docs/DESIGN.md` (the
"Character identity model", "Races", "Character creation", "Gear" and "Art
pipeline" sections are the brief), `docs/IDEAS.md`, and `STATUS.md`. The
design pillars outrank anything in this file.

Godot 4.7.2. On the Linux box it is `godot` on PATH; on Marcel's Windows box it
is the full WinGet path recorded in `terrain-v2.md`. `<godot>` below means
whichever applies.

### Before touching anything

```
git checkout main && git pull
git checkout -b feat/character-v1
<godot> --headless --editor --quit --path .
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . --quit-after 2500 -- --host --seed 42
```

Expect zero script errors, `SELFTEST: all passed`, and a host that boots and
releases the player at spawn (`[Game] spawn chunk ready, player released`).

**The foliage run is on `feat/foliage-v1` the same night.** Do not look at it,
merge it, or rebase onto it. Branch from `main`. The allowed-files list in the
hard rules is the only thing standing between the two branches and a painful
merge - respect it even when a one-line edit to a shared file would be
convenient.

---

## What exists, and what it taught us

**1. The player is a capsule, and the physics under it is finished.**
`Player` is a `CharacterBody3D` with step-up, floor snap, sprint, precision
crawl and a jump derived from `sqrt(2gh)`. None of that changes. `Body` is a
`CapsuleMesh` child at `(0, 1, 0)` and `_body` is referenced in exactly one
place - `_set_noclip()` hides it. Swapping the capsule for a character is a
scene edit and one reference, not a rewrite.

**2. The facing fix has never been seen.** `_face_movement()` uses
`atan2(-wish.x, -wish.z)` and the self-test proves that yaw points
`Vector3.FORWARD` along the wish direction. What nobody has checked is that
*the model's face* is on the `-Z` side of the model. Stage 3 adds the test that
closes that gap: the eye voxels must sit forward of the head's centre.

**3. The sync channel is the right shape with the wrong payload.**
`Game._states[pid] = {"p": Vector3, "y": float}` at 20 Hz, host-owned,
broadcast by `_cl_sync_players`. The README marks it provisional and names
`_srv_report_state` as the function to replace. This plan does not replace it;
it adds fields. A remote character needs velocity, a grounded flag and a pose
id to animate, and an appearance to build from. Both ride in that table.

**4. Colours are linear, and the hex code lives beside them.** `Block.COLORS`
stores linear values with the authored sRGB hex in a comment, because a vertex
colour fed straight from a hex value renders pale and washed out. Every colour
this plan authors follows the same convention: sRGB hex in the table,
converted once with `Color.html(hex).srgb_to_linear()`.

**5. Flat vertex colour plus baked corner AO is the look.** Terrain has no
textures; it is colour, and it reads as cubes because each vertex is darkened
by how many of its three diagonal neighbours are solid. Characters must be
made of the same material or they will look pasted on. They get the same
shading rule, baked the same way, in their own mesher.

**6. Two voxel scales.** `DESIGN.md` says model voxels are 6-8x finer than
blocks and left the exact number unconfirmed. Foliage v1 fixed it for plants
at **8 per block, 6.25 cm**, citing the character scale. This plan confirms it
for characters: a 2 m human is **32 voxels** tall.

**7. The camera pivot is `top_level`.** `CamPivot` does not inherit the body's
rotation, so the body can turn to face its travel while the camera orbits
freely. The character view is a child of the body and turns with it. Do not
touch the pivot.

**8. The tour is a comparison harness, and so is the gallery.** The foliage
plan tunes models in a gallery scene with a fixed camera and frozen light,
never in the world. This plan does the same with its own gallery, because the
world has weather and a moving sun and a comparison needs neither.

---

## Hard rules

1. **Zero overlap with the foliage and terrain work.** New code goes in new
   files under `scripts/character/`, `scenes/character/` and
   `scripts/ui/character_*.gd`. The ONLY existing files this plan may edit:

   | File | Edit |
   | --- | --- |
   | `scenes/player.tscn`, `scripts/player/player.gd` | replace `Body` with the view; feed the animator |
   | `scenes/remote_player.tscn`, `scripts/player/remote_player.gd` | same, from synced state |
   | `scripts/game/game.gd` | the payload fields and the appearance announce, Stage 6 only |
   | `scenes/game.tscn` | add the `CharacterDebug` layer node |
   | `scenes/main_menu.tscn`, `scripts/ui/main_menu.gd` | the Character button and the def handoff, Stage 12 only |
   | `docs/DESIGN.md` | the "Art pipeline" section ONLY - foliage edits the scale section |
   | `docs/IDEAS.md` | one paragraph, Stage 15 |
   | `STATUS.md` | one pointer line, Stage 15 |

   **Never:** anything under `scripts/world/`, `scripts/tools/selftest.gd`,
   `scripts/tools/screenshot_tour.gd`, `scripts/tools/worldgen_probe.gd`,
   `scripts/ui/debug_hud.gd`, `scripts/net/*`, `scenes/selftest.tscn`. Self-
   tests, the gallery and the tuning panel all get their own files.
2. **The net protocol grows additively and nowhere else.** Exactly two
   changes, both in Stage 6: new keys in the existing state dictionary, and one
   new reliable RPC by which a client announces its appearance to the host.
   The join handshake (`_srv_request_join_state` / `_cl_receive_join_state`),
   the edit path and `Net` are untouched. **The host validates every claim** -
   `CharacterDef.from_bytes()` clamps every field into range and a client can
   never crash another client with a bad appearance.
3. **Race is never a stat.** One capsule (`radius 0.4, height 2.0`), one camera
   pivot height, one `MAX_STEP`, one speed table, for every race. No per-race
   number may appear in `player.gd`. The dwarf's head sits at 1.5 m inside a
   2 m capsule and the elf's pokes 0.25 m above it - cosmetic, by decision.
4. **Do not change the design pillars.** If a stage seems to need one bent,
   stop that stage, write the argument into the status doc, move on.
5. **Do not rewrite or delete `TODO(marcel)` exercises.** New ones follow the
   same shape: a working fallback, a hint, no dependency on being done.
6. **No unverified performance claims.** Every number in the status doc is
   measured or says "not measured".
7. **GDScript only. No shaders.** `StandardMaterial3D` with
   `vertex_color_use_as_albedo`, roughness 1, no specular - the terrain's
   material. Blinking is a mesh swap, not a shader. Nothing here has to
   compile on two renderers because nothing here is a shader.
8. **Commit after every stage.** Never leave the tree dirty between stages.
9. **Verify after every stage.** `scenes/character/selftest_character.tscn`
   passes AND `scenes/selftest.tscn` still passes AND `--host --seed 42`
   still boots headless. Three fix attempts, then commit what works, record
   the failure, continue to the next independent stage.
10. **Third person only.**
11. **No sliders. No stats.** The creation screen is picks and swatches.
12. **Parts are data, not code.** Every voxel of every part is authored as
    ASCII slices (or loaded from `.vox`). No part geometry is built from box
    primitives in code, not even the critter. The one exception is the
    gallery's ground pad.
13. **Randomness is allowed here, determinism is not required.** Nothing in
    this plan generates the world. The creation screen's Randomise button may
    use `randi()`. Appearance is *data that is sent*, never *derived* on two
    machines from a seed.

### The renderer caveat, again

This box has no display. Godot falls back to OpenGL Compatibility on Mesa
llvmpipe under Xvfb. **Marcel runs Forward+ on an RTX 5080.** Every colour and
every animation amplitude in this plan will be judged on the wrong renderer.

You are cleared to tune values anyway. In exchange:

- **Every value chosen by eye goes in `CharacterConfig`** (Stage 4), reachable
  from the F8 panel, never hardcoded. Not in `WorldgenConfig` - it is not
  worldgen, and that file belongs to two other runs tonight.
- **Every visual decision is listed in one status-doc section** titled
  "Tuned blind - re-check these first", with before/after and the knob name.
- Never delete a previous value. Record it beside the new one.
- **The gallery (Stage 1) is what you tune against**, not the world.

---

## Fixed numbers

### Scale

| Thing | Value |
| --- | --- |
| Block | 0.5 m (unchanged) |
| **Model voxel** | **1/8 block = 6.25 cm** (matches foliage v1) |
| Human | 32 voxels = 2.00 m |
| Physics capsule | radius 0.4 m, height 2.0 m, every race |
| Camera pivot | 1.5 m, every race |

The character is the deliberate exception to the world's 1:4 scale, at 1:0.9.
That is already settled in `DESIGN.md` and is not revisited.

### Two proportion schemes, and the study

Decided: build the **human in both** schemes, shoot them side by side, and
Marcel picks in the morning. The other three races are built in the stocky
scheme only. A `build` field on `CharacterDef` selects the scheme; for races
without a lean part set it clamps to stocky.

Starting numbers in model voxels. Adjust in the gallery; record the finals.

| | Stocky (Cube World) | Lean (naturalistic) |
| --- | --- | --- |
| Total height | 32 | 32 |
| Head (without hair) | 9 tall, 8 wide, 8 deep | 6 tall, 6 wide, 6 deep |
| Neck | 0 | 1 |
| Torso | 10 tall, 8 wide, 5 deep | 11 tall, 7 wide, 4 deep |
| Legs | 9 tall, 3 x 3, single segment | 14 tall, 2 x 2, single segment |
| Arms | 9 long, 3 x 3 | 12 long, 2 x 2 |
| Hands | 3 cube, part of the arm | 2 cube, part of the arm |
| Feet | 4 deep, part of the leg | 3 deep, part of the leg |

Single-segment limbs in both schemes, swinging from the shoulder and the hip.
That is the Cube World look, and it means both schemes share one animator with
nothing but different bone lengths. Knees and elbows are a later plan.

**The head is the face.** In the stocky scheme it must carry two eyes (2 x 2
each, white plus iris), a mouth line and a nose voxel readable at 15 m. In the
lean scheme the eyes are 1 x 2 and the requirement drops to "has a face at
5 m" - the lean scheme's readability comes from neck and shoulders, and the
silhouette sheets are where it is judged.

### The four races, stocky scheme

`DESIGN.md`: fixed proportions per race, and *strong distinct silhouettes
readable at distance in dim light* is a hard requirement. Starting numbers:

| Race | Height | Torso W x D | Head | Legs | Arms | The silhouette is |
| --- | --- | --- | --- | --- | --- | --- |
| Human | 32 (2.00 m) | 8 x 5 | 9 | 9 | 9 x 3 | the reference: square shoulders |
| Elf | 36 (2.25 m) | 6 x 4 | 9, +2 neck, ears 2 out each side | 12 | 11 x 2 | **tall and narrow**, ears |
| Dwarf | 24 (1.50 m) | 12 x 7 | 10 | 5 | 8 x 4 | **as wide as it is tall**, beard |
| Lizardfolk | 30 (1.88 m) at the crown, posture leaning 8 deg forward | 8 x 5 | 9 + a snout 4 forward | 9 | 9 x 3 | **tail** 14 long in 3 bones, crest, snout |

Rules that follow from the table:

- The dwarf's beard is half its silhouette, so **a dwarf always has a beard**:
  its beard picker has three options and no "none".
- The elf has no beard option at all. The lizardfolk has no hair; its `hair`
  slot holds a **crest** with three options.
- Every race's eye height is derived from its own table and exposed as
  `Races.eye_height_m(race)`, for the head-look and the gallery camera.
- The tail is three bones, `tail_1..3`, each a rigid part, animated as a chain
  with per-bone lag (Stage 5). The chain machinery is generic - the critter
  uses it too.

### Palette slots

Parts are authored in **semantic slots**, not colours. The legend, shared by
every part file:

| Char | Slot | Resolved from |
| --- | --- | --- |
| `.` | empty | - |
| `S` | skin | def.skin -> race skin palette |
| `s` | skin, shaded | skin x 0.8 |
| `H` | hair / crest | def.hair_color -> race hair palette |
| `E` | iris | def.eyes -> race eye palette |
| `W` | eye white | fixed #F4F0E8 |
| `M` | mouth | skin x 0.55 |
| `C` | cloth | race outfit, fixed |
| `c` | cloth, dark | cloth x 0.75 |
| `L` | leather / boots | race outfit, fixed |
| `B` | belt / straps | race outfit, fixed |
| `T` | tooth / claw / bone | fixed #EDE6D4 |
| `X` | metal | fixed #9A9FA6 |
| `D` | wood | fixed #7A5230 |

The same voxels with a different resolve table are a different-looking
character. That is what makes palette swaps free.

Per-race palettes, sRGB hex, converted to linear once at load. **Starting
values, tuned blind** - every one goes in the re-check table.

| Race | Skin (5) | Hair / crest (5) | Eyes (4) |
| --- | --- | --- | --- |
| Human | `#F1C9A5 #E0AC7E #C68642 #8D5524 #4A2C17` | `#1B1411 #4A2E1B #C9A05A #A63A1E #B8B2A8` | `#4B2E1A #3A6EA5 #4E7B3A #7A7A7A` |
| Elf | `#F5E3D3 #E8C9B0 #C7A98A #9FA8A3 #6F7F73` | `#E8E4DA #F0D9A0 #2A1E1A #7A4B2A #4C5A3C` | `#7FB2D9 #57A773 #C9A227 #6A5ACD` |
| Dwarf | `#E9B48E #D08C5A #B36A3C #8A4B2A #5A3420` | `#A8321E #C27A2C #3B2A1F #1E1A17 #D8D2C6` | `#3F2A1A #2F5F8F #6B6B6B #7B5B2A` |
| Lizardfolk | `#4E8A3C #2F6F6A #B8A05A #8A3F2A #3A3F4A` | `#D14A2A #E0B030 #2A7FB0 #6A2A8A #F0E6D0` | `#E0B030 #C93A2A #101010 #9AD0C0` |

Outfits are fixed per race in v1 - a tunic, trousers and boots for human, elf
and dwarf; a harness and loincloth for lizardfolk - because the torso slot
belongs to the gear plan. Cloth `#7A6A4F`, dark cloth derived, leather
`#3A2A1E`, straps `#5A4632`. Elf tunic `#5C7A5A`, dwarf tunic `#6B4F3A`.

### Hair and beards

Decided: **3 hair per race; 3 beards for human and dwarf; elf 0 beards;
lizardfolk crests instead of hair.**

| Race | `hair` slot | `beard` slot |
| --- | --- | --- |
| Human | short, long, tied back | none, short, full |
| Elf | short, long, braided | none |
| Dwarf | short, long, braided | short, full, forked |
| Lizardfolk | crest low, crest tall, frill | none |

Hair is a separate part attached to the head bone, so it swaps without
touching the head. Beards likewise. A hair part may write over head voxels
(it sits outside them); the mesher culls the shared faces.

### Animation numbers

Initial values. All in `CharacterConfig`, all on the F8 panel, all in the
re-check table.

| Knob | Start | What |
| --- | --- | --- |
| `walk_swing_deg` | 35 | leg swing amplitude at walk speed |
| `sprint_swing_deg` | 60 | at sprint |
| `arm_swing_ratio` | 0.8 | arm amplitude as a fraction of leg amplitude |
| `precision_swing_ratio` | 0.4 | precision crawl amplitude as a fraction of walk |
| `sprint_lean_deg` | 12 | torso pitched forward at sprint |
| `bob_walk_vox` / `bob_sprint_vox` | 1.5 / 3.0 | hips rise per step, in voxels |
| `stride_walk_m` | 1.3 | metres per full cycle (two steps) at walk, human |
| `cycle_hz_max` | 3.5 | stride stretches rather than the legs exceeding this |
| `pose_smoothing` | 10 | per-bone `1 - exp(-k dt)` |
| `jump_tuck_deg` | 25 | legs tucked while rising |
| `fall_arms_deg` | 30 | arms out while falling |
| `land_squash_vox` / `land_squash_ms` | 2 / 120 | hips dip on landing |
| `breath_hz` / `breath_vox` | 0.25 / 0.5 | idle torso rise |
| `blink_min_s` / `blink_max_s` / `blink_ms` | 3 / 6 / 120 | |
| `look_yaw_deg` / `look_pitch_deg` / `look_smoothing` | 60 / 25 / 8 | head follows the camera |
| `tail_hz` / `tail_deg` / `tail_lag` | 1.2 / 12 / 0.15 s | idle sway, per-bone lag |
| `view_hide_m` | 1.0 | the local view hides when the camera is nearer than this to the head |

**The walk cycle is driven by distance, not time.** Phase advances by
`speed * dt / stride`, so feet do not slide at any speed. At sprint (13 m/s)
a 1.3 m stride would be a 10 Hz flail; `cycle_hz_max` caps the leg rate and
lets the stride grow to `speed / cycle_hz_max` = 3.7 m instead. The player
will look like they are bounding. That is the honest visual of the sprint
speed `DESIGN.md` already accepted - "sprint looks fast" - and it is a knob.

Stride scales with leg length across races and schemes: `stride =
stride_walk_m * leg_length / human_stocky_leg_length`. The dwarf takes short
quick steps and the elf long slow ones, from one table.

### The wire format

State dictionary, additive keys beside the existing `"p"` and `"y"`:

| Key | Type | Meaning |
| --- | --- | --- |
| `"v"` | Vector3 | velocity, m/s |
| `"s"` | int | state byte: bit0 grounded, bit1 sprint, bit2 precision, bit3 rising, bits 4-6 pose id (0 none, 1 sit, 2 downed, 3 wave), bit7 noclip |
| `"l"` | float | look yaw, radians, world space |
| `"a"` | PackedByteArray | appearance, 8 bytes below |
| `"n"` | String | display name, at most 16 characters, sanitised by the host |

Appearance, 8 bytes: `[version=1, race, build, skin, hair_color, eyes, hair,
beard]`. `CharacterDef.from_bytes()` never throws: a wrong version or length
yields the default human; every index is clamped into its race's range. The
host's own appearance goes straight into its table; a client sends its bytes
and name once with `_srv_announce_appearance`, reliable, and the host writes
the validated result into that peer's row. Every peer therefore gets every
appearance on the next sync tick, including a late joiner, with no join-order
race and no handshake change.

Estimated cost, **not measured**: about 70 bytes of payload per player per
tick before variant overhead, 20 Hz, four players. If you can measure it,
do, and replace this line.

### Performance budget

- A stocky character, hair and beard included: **at most 6,000 triangles**.
  Lean fewer. Measured from the gallery with
  `Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME`, one character on the pad,
  minus the pad's own count.
- Animator: **at most 0.15 ms per character per frame** on this box, measured
  with `Time.get_ticks_usec()` around `update()` + `apply()`, averaged over
  600 frames. Reported, not gated - four players cannot break a frame budget
  at any plausible value.
- The creation screen's preview viewport: 512 x 640, only alive while the
  screen is open.
- Boot to `is_idle()` at High: **no change** - this plan adds nothing to the
  world build.

---

## Stages

Order matters. Instruments first, then the model system, then one human in
the game, then movement, then the other players, then the study, then the
other three races, then variety, then the tools that make it Marcel's.

### Stage 1 - instruments

Nothing here changes the game.

- **Gallery.** `scenes/character/gallery.tscn` +
  `scripts/tools/character_gallery.gd`. Its own Sun, WorldEnvironment and a
  `SkyCycle` bound to `WorldgenConfig.load_or_default()` so light and fog
  match the game; `time_of_day` frozen by `--time`, default `config.day_start`.
  A flat pad of `Block.GRASS` blocks meshed once, 60 x 120 m, and a dark
  `Block.STONE` wall 20 m tall at the far end for the "against a hillside"
  variant. Fixed camera at the game's FOV (75), eye 1.7 m, looking at chest
  height of the lineup. Writes `build/character/<label>/*.png` with the
  tour's `--label` sanitising rule copied, not imported. Run as
  `<godot> --path . scenes/character/gallery.tscn -- --label some-name`.
  It renders whatever `CharacterView` can build; tonight that is nothing, so
  it renders the capsule. **Shoot it anyway** - that is the "before".
- **Sheets** the gallery produces once the stages below exist, each one shot
  when its stage lands and again at the end:
  - `lineup-front.png`, `lineup-back.png`: every race, stocky, plus the lean
    human, side by side at 15 m, noon.
  - `silhouettes-15.png`, `silhouettes-40.png`, `silhouettes-80.png`: the same
    lineup at dusk, `--time 0.82`, against the sky; and `-hill` variants
    against the stone wall.
  - `masks-40.png`: the lineup unshaded black on white at 40 m - a
    `StandardMaterial3D` override with `shading_mode = SHADING_MODE_UNSHADED`
    and black albedo - plus **the silhouette metric**: crop each race's mask
    to its bounding box, align bottom-centre, and report pairwise IoU over the
    union canvas. Print all six pairs and the capsule-vs-human pair. **Target:
    every pair under 0.70.** A pair over it says which two races to separate
    and the fix is to exaggerate the *differentiating* feature in the table
    (ears, beard, tail, width), never the shared ones.
  - `anim-<race>-walk.png`, `-sprint.png`, `-jump.png`, `-poses.png`: eight
    copies of the same character posed at phase `k/8` (or takeoff / rising /
    apex / falling / landing / recovered for jump; sit / downed / wave / idle
    for poses), in a row. Static, so it costs no time to shoot and compares
    exactly between runs.
  - `variants-<race>.png`: hair x beard x three palettes, a grid.
  - `gear.png`: the human with the three placeholders.
  - `study.png`: stocky human and lean human alone, 15 m and 40 m, day and
    dusk, front and three-quarter - the sheet Marcel decides from.
  - `critter-walk.png`: Stage 13.
- **Self-tests.** `scenes/character/selftest_character.tscn` +
  `scripts/tools/selftest_character.gd`, in the exact shape of `selftest.gd`:
  a dictionary of UNTYPED test callables, each returning an int failure count,
  a crash reported as "did not complete", non-zero exit on failure. Starts
  empty tonight and every stage below adds to it.

*Verify:* the gallery runs and writes a capsule shot to
`build/character/character-baseline/`. The self-test scene runs and passes
with zero tests.

### Stage 2 - the voxel model system

`scripts/character/voxel_model.gd` - class `VoxelModel`.

- **The ASCII format.** A part is a Dictionary constant:

  ```gdscript
  const HEAD := {
      "size": Vector3i(8, 9, 8),      # x width, y height, z depth
      "anchor": Vector3i(4, 0, 4),    # the voxel that sits ON the bone pivot
      "slices": [                     # y = 0 first (bottom), one entry per layer
          [   # each slice: z rows, FRONT row first; each row: x chars, character's LEFT first
              "..SSSS..",
              ".SSSSSS.",
              # ...
          ],
          # ...
      ],
  }
  ```

  The character faces `-Z`. The front row of a slice is the `-Z` face. `+X`
  is the character's left hand side. State this once, in the class docstring,
  and test it (Stage 3, the eyes-forward test).

  The parser rejects ragged rows and wrong slice counts loudly with the part
  name and the slice index - a silent off-by-one in a 32-slice part is an
  evening lost.
- **The voxel list.** Parsed parts become `Array[Vector4i]` of `(x, y, z,
  slot)`. `VoxelModel.from_list()` also accepts foliage's `(x, y, z, colour,
  emissive)` shape with colours already resolved, so the two builders can be
  unified after both branches land. Say so in a comment; do not do it now.
- **The mesher.** One `ArrayMesh` per part. Faces between two voxels of the
  same part are culled. No greedy merge - parts are small and merging fights
  AO; record the triangle counts and revisit only if the budget breaks.
  **Baked corner AO** by the terrain's rule: each vertex darkened by how many
  of the three voxels diagonally adjacent to that corner within the part are
  solid, `ao_strength` from `CharacterConfig` (start 0.35 - a face is smaller
  than a hillside and the same 0.45 goes muddy). Vertex colours linear.
  Surface arrays in metres at 0.0625 m per voxel, offset so the anchor voxel's
  bottom-centre sits at the origin.
- **The material.** One shared `StandardMaterial3D`: `vertex_color_use_as_albedo`,
  roughness 1, specular 0, `cull_mode BACK`. Cast shadows on.
- **Resolve.** `VoxelModel.build_mesh(part, palette: Dictionary)` where
  `palette` maps slot -> linear `Color`. Same part, two palettes, two meshes,
  identical vertices.

*Verify (self-tests):* a hand-written 2 x 2 x 2 test part meshes to 6 faces
and 12 triangles with every normal pointing away from its centroid; a solid
3 x 3 x 3 part culls to exactly 54 quads; an L-shaped part has darker
vertices at the inner corner than at the open ones; the same part with two
palettes produces identical vertex arrays and differing colours only where
the slot differs; a ragged slice throws a readable error. Gallery: the test
cube on the pad.

### Stage 3 - rig, view, and the first human

- `scripts/character/rig.gd` - class `Rig extends Node3D`. Built from a **bone
  table**: `[{name, parent, rest: Vector3 (metres), part: String}]`. Each bone
  is a `Node3D`; its part is a `MeshInstance3D` child. Plain `Node3D` bones
  rather than `Skeleton3D`, deliberately: every part is rigid, nothing is
  skinned, and a `Node3D` transform is the entire animation state - it can be
  read in a self-test and set from a dictionary. `AnimationPlayer` can drive
  `Node3D` properties later if anyone wants keyframes. Humanoid bones: `hips`,
  `torso`, `head`, `arm_l`, `arm_r`, `leg_l`, `leg_r`, and for the lizardfolk
  `tail_1`, `tail_2`, `tail_3`. **Sockets** are empty `Node3D`s on the rig:
  `hand_r`, `hand_l`, `back`, `chest`, `neck`, `belt` - all six on every race,
  positioned from the race table.
- `scripts/character/character_def.gd` - class `CharacterDef`: `race`,
  `build`, `skin`, `hair_color`, `eyes`, `hair`, `beard`, `name`.
  `to_bytes()` / `from_bytes()` per the wire format; `to_dict()` /
  `from_dict()` for the save file; `validate()` clamps everything into the
  ranges `Races` declares; `sanitise_name()` strips control characters, trims,
  caps at 16, and returns `"peer %d"` for an empty result. `static func
  load_or_default()` reads `user://character.tres`; `save()` writes it.
- `scripts/character/races.gd` - class `Races`: the race table from Fixed
  Numbers as data - heights, bone tables per scheme, part-set names, palette
  lists, hair and beard option lists, `eye_height_m()`, `leg_length_m()`.
- `scripts/character/parts/parts_human.gd`: every stocky human part - head,
  torso, arm (one part, mirrored for the left by the mesher's `mirror_x`
  flag), leg (same), plus the default outfit baked into the torso and leg
  parts as `C`/`c`/`L`/`B` slots. Hair and beard parts come in Stage 9; for
  now the human is bald, and that is fine.
- `scripts/character/character_view.gd` - class `CharacterView extends
  Node3D`: `build(def)` tears down and rebuilds the rig and meshes (idempotent
  - the creation screen calls it on every click), `set_state(state)`,
  `set_gear_placeholders(on)`, `local: bool`. The single visual entry point;
  `Player`, `RemotePlayer`, the creation preview and the gallery all use it
  and nothing else builds a character.
- **In the game.** `scenes/player.tscn`: delete the `Body` `CapsuleMesh`, add
  `View` (`CharacterView`) at the origin - the model's feet are at y = 0, the
  capsule's centre is at y = 1, and they agree. `player.gd`: `_body` becomes
  `_view`, `_set_noclip()` hides it as before, and `_ready()` calls
  `_view.build(CharacterDef.load_or_default())`. The human stands in rest
  pose and slides around. Ugly, correct, committed.

*Verify (self-tests):* **eyes forward** - the mean `z` of the head part's
`E` voxels is less than the head's centre `z`, so the face is on `-Z` and the
terrain v2 facing fix is finally checked against a face; every bone in the
table has a part or is a socket; every socket exists; the built human's total
height is 32 voxels within one; `CharacterDef` round-trips through bytes and
dict; `from_bytes()` on 100 random byte arrays never throws and always
validates. Gallery: `lineup-front` and `lineup-back` with one bald human.
Headless host boot still releases the player.

### Stage 4 - the animator, the config, and the panel

- `scripts/character/locomotion_state.gd` - class `LocomotionState`: `speed`
  (horizontal m/s), `vertical` (m/s), `grounded`, `mode` (walk / sprint /
  precision), `rising`, `pose` (none / sit / downed / wave), `look_yaw`,
  `look_pitch`, `noclip`. `to_state_byte()` / `from_state_byte()` for Stage
  6. **This struct is the seam** between physics and animation: the local
  player fills it from its own body, the remote fills it from the wire, and
  the future host-simulated player will fill it from the host's table. The
  animator never reads `Input`, never reads a `CharacterBody3D`.
- `scripts/character/animator.gd` - class `Animator`. `update(state, dt)`
  advances the cycle phase (by distance, per Fixed Numbers) and the
  per-bone smoothing; `apply(rig)` writes transforms. **`static func
  pose_for(state, phase, t) -> Dictionary`** is pure - bone name -> `{"rot":
  Vector3, "pos": Vector3}` - and is what the gallery strips and the self-
  tests call. Locomotion core: idle, walk, sprint (with lean and bob),
  precision, jump (tuck while rising), fall (arms out), land (squash then
  recover). Blend by exponential smoothing, `1 - exp(-k dt)`, per bone - the
  codebase's frame-rate-independent convention, and say why in the comment as
  `RemotePlayer` does.
- **Head look.** The head bone yaws and pitches toward `look_yaw` /
  `look_pitch` relative to the body, clamped and smoothed. The local player
  feeds `camera_yaw()` and its pitch; the head turns to where you are looking,
  which is what makes a character feel present.
- `scripts/character/character_config.gd` - class `CharacterConfig extends
  Resource`: every knob in the animation table plus `ao_strength`, saved to
  `user://character_tuning.tres`, `load_or_default()`. Not in
  `WorldgenConfig`, not in `PROPERTIES` - nothing here changes a block.
- `scripts/ui/character_debug.gd` - `CharacterDebug extends CanvasLayer`,
  added to `scenes/game.tscn` as a sibling of `DebugHUD`. **F8** toggles a
  panel of spin rows for every `CharacterConfig` knob (copy `DebugHUD`'s
  `_spin_row` shape; do not import it), a Save button, and buttons that
  rebuild the LOCAL player's view with the next race / build / hair / beard /
  palette, so Marcel can cycle through everything without leaving the world.
  It must set `DebugHUD.ui_has_mouse` while open, exactly as the F4 panel
  does, or the first click recaptures the mouse.
- `player.gd`: fill a `LocomotionState` each physics frame from `velocity`,
  `is_on_floor()`, `_speed_multiplier()`'s branch, the jump, `_yaw`, `_pitch`
  and `noclip`; hand it to `_view.set_state()`.

*Verify (self-tests):* `pose_for` returns finite transforms for every state
over 600 steps at dt 1/60; at walk speed the phase advances by exactly
`speed * dt / stride` per step; at zero speed the pose converges on idle
(every bone within 0.001 rad of the idle pose after two seconds); sit, downed
and idle produce three different hip heights; at sprint the torso pitch
equals `sprint_lean_deg` within a degree once settled. Gallery:
`anim-human-walk`, `-sprint`, `-jump`. Animator cost measured and recorded.
In the game: walk, sprint, jump, precision, and the head follows the mouse.

### Stage 5 - life, poses, and the tail machinery

- **Breathing** on the torso, **blink** by swapping the head mesh for an
  eyes-closed variant (the mesher builds both from one part: the closed
  variant resolves `E` and `W` to `S`) on a timer between `blink_min_s` and
  `blink_max_s`.
- **Chains.** `Animator` gains a generic bone-chain rule: bones named
  `<chain>_1..n` follow a base sway with `tail_lag` seconds of lag per link,
  amplitude growing with speed. Built now on the human (which has no chain,
  so the test is on a synthetic rig) because the lizardfolk and the critter
  both need it and it must not be designed twice.
- **Static poses.** `sit` (hips at ground level, legs forward 90 deg, torso
  upright), `downed` (root pitched 90 deg onto its back, hips at ground, arms
  out), `wave` (right arm raised, oscillating for 1.5 s then back to none).
  Debug keys, local only until the systems that own them exist: `X` sit /
  stand, `B` downed / up, `V` wave. The pose id travels in the state byte in
  Stage 6 so a friend sees you sit. **The campfire plan owns `sit` and the
  death design owns `downed`**; the keys are scaffolding and say so.
- **Close-camera hide.** In `CharacterView._process`, when `local` is true
  and the active camera is within `view_hide_m` of the head bone, the view
  hides. This covers the spring arm collapsing against a wall AND the
  screenshot tour, which parks the player at the camera's eye - both without
  touching the tour.

*Verify (self-tests):* a synthetic four-link chain lags link by link (link
`n` reaches its peak after link `n-1`); the blink timer never fires two
blinks within `blink_min_s`; the eyes-closed variant has zero `E`/`W`
voxels. Gallery: `anim-human-poses`. Headless tour on seed 42 still produces
six shots with no character in frame (`--tour --seed 42 --label
character-stage5` - the tour is not edited, only run).

### Stage 6 - the other players

The only stage that edits `game.gd`, and the two changes from Hard Rule 2.

- `_publish_local_state()` adds `"v"`, `"s"`, `"l"` from the local
  `LocomotionState`, and the host adds its own `"a"` and `"n"` from its def.
- `_srv_report_state(pos, yaw, vel, state_byte, look_yaw)` - the existing
  RPC's signature grows. Same `@rpc` annotation, same sender-id rule.
- New: `@rpc("any_peer", "call_remote", "reliable") func
  _srv_announce_appearance(bytes: PackedByteArray, name: String)`. Host only,
  identity from `get_remote_sender_id()`, runs `CharacterDef.from_bytes()` and
  `sanitise_name()` and stores the result in the sender's row. A client calls
  it once, right after `_cl_receive_join_state`. If a client's row exists
  before its announce arrives, the row carries the default human until it
  does; **a remote view must never fail to build**.
- `RemotePlayer`: `Body` becomes a `CharacterView` with `local = false`.
  `set_target(pos, yaw)` becomes `set_target(state: Dictionary)`: position
  and yaw smoothed as today; velocity, state byte and look yaw go straight
  into a `LocomotionState`; appearance bytes are compared with the last seen
  and the view rebuilt only on change. The nametag shows `"n"`, coloured by
  `color_for_peer()` as now - the peer colour survives on the tag, not the
  body.
- `_apply_states()` passes the whole row.

*Verify:* both self-test scenes pass. **Two peers, headless, on this box:**

```
<godot> --headless --path . --quit-after 3000 -- --host --seed 42 --race dwarf --name Marcel
<godot> --headless --path . --quit-after 3000 -- --join 127.0.0.1 --race elf --name Friend
```

(the `--race` / `--name` flags are Stage 12's, so for this stage read them in
`CharacterDef.load_or_default()` early - a ten-line CLI override, moved into
its final home later). Expect the host log to show `[Game] appearance for
peer 2: elf "Friend"` and the client log to show a dwarf named Marcel in its
table. A client sending `[9, 99, 99, ...]` must produce a valid default human
on the host and a warning, not an error. Record the result verbatim.

### Stage 7 - the proportion study

- `parts_human_lean.gd`: the lean part set from the scheme table. A second
  bone table for `build = 1`. Stride follows leg length automatically.
- `Races` marks which races have a lean set; `CharacterDef.validate()` clamps
  `build` to 0 for the rest.
- The gallery's `study.png`: both humans, 15 m and 40 m, noon and `--time
  0.82`, front and three-quarter, on one sheet with the distance and time
  written into the filename rather than the image. Plus both humans'
  `anim-*` strips - the same animator on both, which is the point.
- Report the silhouette IoU stocky-vs-lean, and each against the capsule.

*Verify:* self-tests extend to both builds (height, eyes forward, sockets).
The sheet exists. Nothing about the stocky human changed - diff its strips
against Stage 4's.

### Stage 8 - the other three races

`parts_elf.gd`, `parts_dwarf.gd`, `parts_lizardfolk.gd`, each with its own
bone table from the race table, each with a default beard or crest where the
table requires one. The lizardfolk gets the three tail bones on the chain
rule and the 8 degree lean baked into its `hips` rest rotation.

Then the test the whole design hangs on. Shoot `silhouettes-40.png` and
`-hill`, and `masks-40.png` with the metric. **Up to three passes** of
adjusting the race table - never the human, it is the reference - to bring
every pair under 0.70 and, more importantly, to make the four *nameable* in
the dusk shot. Record every pass's six numbers. If a pair will not separate
in three passes, record which and why, and move on; Marcel judges the sheet
in the morning anyway.

*Verify:* self-tests run for all four races (height within one voxel of the
table, eyes forward, every socket present, both builds where present). The
40 m dusk sheet and the metric table exist. All four walk, sprint, jump and
sit in their strips. In the game, F8 cycles through all four.

### Stage 9 - hair, beards, crests and palettes

`parts_hair.gd`: every option from the hair and beard table, per race, as
parts attached to `head` (hair, crest) or `head` with a lower anchor (beard).
The full per-race palettes from Fixed Numbers into `Races`. `CharacterDef.
validate()` clamps to each race's real option counts - the dwarf can never be
beardless, the elf never bearded.

*Verify:* every race x every hair x every beard x every palette index builds
without error (a loop, not a sample); `variants-<race>.png` for all four.
Re-shoot `masks-40.png` - hair changes silhouettes, and the metric must still
hold with the DEFAULT hair and beard; report the worst case across options
too.

### Stage 10 - gear sockets, proven

`parts_gear.gd`: three placeholders, ASCII like everything else - a wooden
sword (`D` and `X`, 14 voxels long) for `hand_r`, a plain tunic overlay for
`chest` (a shell one voxel outside the torso, `c`), a pendant on a cord for
`neck` (`X` and `B`). `CharacterView.set_gear_placeholders(on)` attaches or
frees them. Debug key `T` toggles them; the panel has the same button. They
must follow the animation - the sword swings with the arm, the tunic rides
the torso lean, the pendant sits on the chest through a sit.

This is **not** a gear system. No slots in `CharacterDef`, nothing on the
wire, no stats. The sockets are the deliverable; the items prove them.

*Verify:* every socket on every race accepts every placeholder without
intersecting the body in rest pose (a voxel-overlap check between the
placeholder's world voxels and the body parts' - report overlaps, allow at
most 2 voxels for the tunic which is designed to hug). Gallery: `gear.png`
and a walk strip with gear on.

### Stage 11 - the `.vox` importer, and the drop-in rule

`scripts/character/vox_loader.gd`: reads a MagicaVoxel `.vox` (`VOX ` +
version 150; `MAIN`, `SIZE`, `XYZI`, optional `RGBA`; the default palette
when `RGBA` is absent) into a `VoxelModel` part. MagicaVoxel is Z-up and its
default camera looks along `+Y`; map `model = (vox.x, vox.z, size_y - 1 -
vox.y)` and **prove the mapping with the eyes-forward test** on a fixture,
not by reasoning about it - the fixture is a byte literal in the self-test, a
3 x 3 x 3 cube with one marked voxel on the face that must come out at `-Z`.

Colours from a `.vox` are already resolved, so a `.vox` part skips slots -
palette swaps do not apply to it. Document that limitation in the loader's
docstring, and the way round it: a `.vox` whose palette indices 1..13 are
reserved to mean the thirteen slots, which the loader maps back to slots when
`--slots` is set on the part. Implement the mapping; it is ten lines and it
is what makes a MagicaVoxel-authored head take a skin swap.

**The drop-in rule.** If `assets/characters/<race>/<part>.vox` exists, it
replaces the ASCII part of that name at load. No code change to swap art.
Say so in `DESIGN.md`'s Art pipeline section (Stage 15) and in the status doc.

*Verify:* the fixture loads with the mark at `-Z`; a 1-voxel `.vox` with the
default palette resolves to MagicaVoxel's default colour 1; a garbage file
returns null with a warning and the ASCII part is used. Drop a test `.vox` in
`assets/characters/human/head.vox`, confirm the game uses it, **then delete
it** - the assets directory ships empty.

### Stage 12 - the creation screen

`DESIGN.md`: one screen, race, palette swaps, hair and beard picks, name.
**No sliders. No stats.**

- `scenes/character/creation.tscn` + `scripts/ui/character_creation.gd`.
  Left: a `SubViewport` holding a `CharacterView` on a turntable (slow yaw),
  its own light, 512 x 640. Right: four race buttons; a stocky / lean toggle
  that is enabled only for races that have a lean set; swatch rows for skin,
  hair colour, eyes from the race's palettes; `<` / `>` pickers for hair and
  beard (the beard row hidden for races with none); a name `LineEdit`; a
  **Randomise** button (`randi()` is fine here - see Hard Rule 13); **Done**.
  Every change calls `view.build(def)` - which is why `build()` had to be
  idempotent.
- Saves to `user://character.tres` on Done. The main menu gains a
  **Character** button above Host, and a line under the title showing the
  current character's name and race. Host and Join read the saved def; the
  local `Player` builds from it; the client announces it (Stage 6).
- **CLI fallback**, final home for the Stage 6 stub: `--race human|elf|dwarf|
  lizardfolk`, `--build stocky|lean`, `--look N` (a deterministic randomise
  from `N` via `WorldHash.hash01(N, k, 0, salt)` per field - deterministic so
  two headless runs can be compared), `--name X`. Flags override the saved
  file for that run only. `--host` and `--join` never open the screen.

*Verify:* the screen opens from the menu, every control rebuilds the preview,
Done saves, relaunch shows the saved character in the menu line and in the
world. Headless: `--race lizardfolk --look 7` twice produces byte-identical
appearance bytes. The two-peer test from Stage 6 re-run with the final flags.

### Stage 13 - the critter, proving the rig is not humanoid

`parts_critter.gd` and a bone table for a four-legged thing the size of a
large dog: `body` (14 x 6 x 6), `head` (6, with a snout), `leg_fl`, `leg_fr`,
`leg_bl`, `leg_br` (5 long), `tail_1`, `tail_2`. The animator gains a **gait
table** - which legs share a phase and at what offset - so a trot (diagonal
pairs) is data, and the humanoid walk is just the two-leg entry in the same
table. Hidden-face culling, AO, palette slots, the chain rule for the tail:
everything from the humanoid path, unchanged.

Gallery only. No AI, no scene, no spawning. It exists to be walked in
`critter-walk.png` and to fail loudly if any part of the pipeline assumed a
`torso` bone or two legs. It is what the first-enemy plan starts from.

*Verify:* the critter builds, has no `torso`, walks in its strip with
diagonal legs in phase, and its tail lags. Self-test: `pose_for` on the
critter rig returns finite transforms for every bone; a rig with an unknown
gait falls back to the two-leg gait with a warning, not a crash.

### Stage 14 - the budget and the last pass

- Measure everything in the performance budget and record it.
- Re-shoot every sheet on the finished branch, labelled `character-final`.
  Re-run the silhouette metric; the table in the status doc is the final one.
- Walk every race across seed 42's spawn meadow headless with the traversal
  probe's flags (`--traverse --view low`, run for 60 s and stop; it is not
  being measured, it is being watched for script errors in the animator
  under real terrain).

*Verify:* both self-test scenes, headless host boot, the two-peer test, zero
script errors across all of it.

### Stage 15 - handoff

- **`docs/status/character-v1.md`** - the full handoff, in the shape of the
  `STATUS.md` rewrites of v1 and v2: read-this-first with the commands to see
  it; the things that want Marcel's judgement in order (the proportion study
  FIRST, then the 40 m dusk sheet, then the animation feel); what got done per
  stage; every measured number; the "Tuned blind - re-check these first"
  table with every knob, palette and race dimension; every departure from
  this plan with its reasoning; what was NOT done and why; the exact next
  step; and what the first-enemy plan, the campfire plan and the gear plan
  will each need from this work.
- `STATUS.md`: **one line**, directly under the title: `Character v1 ran the
  same night on feat/character-v1 - see docs/status/character-v1.md`. If it
  conflicts on merge, it is one line to re-add.
- `docs/DESIGN.md`, **Art pipeline section only**: replace the "Target height
  ~24-32 model voxels (Unconfirmed...)" paragraph and what follows it with the
  settled numbers - 8 voxels per block, 6.25 cm, human 32, the race heights,
  the identical collider rule, the two schemes with "default stocky, lean
  built for comparison, decision pending" - and the drop-in `.vox` rule.
  Do not touch the scale section; foliage edits it tonight.
- `docs/IDEAS.md`: one paragraph after "It is a prerequisite, not a detour.",
  saying character v1 ran on its branch as a prerequisite for items 2 and 3
  and linking this plan and the status doc.
- Leave **two or three new `TODO(marcel)` exercises**, each with a working
  fallback and a hint. Good candidates: the stride derivation
  (`Animator._stride_for()` - fallback: the linear leg-length scale; the
  exercise: a stride that also depends on speed the way a real gait
  transitions from walk to run); torso-follows-head (fallback: the head
  clamps; the exercise: past the clamp, the torso turns a little too); the
  blink rhythm (fallback: uniform between min and max; the exercise: blinks
  cluster, and a character about to speak or turn blinks first).

---

## Not in this plan

Named so nobody spends the night on them:

- Race perks, skills, XP, the character sheet.
- The gear system: slots on the def, items on the wire, stats. Sockets only.
- Character persistence in the world save. The save file does not exist yet;
  `user://character.tres` is a local convenience and `to_dict()` is the shape
  the world save will take.
- Host-authoritative player input. `LocomotionState` is built so that rewrite
  does not touch the animator; the rewrite itself is a carried ticket.
- The first enemy's AI, spawning, or health. The critter is a gallery model.
- Combat animations, including the light attack. Decided out.
- Swimming, water, mounts.
- Two-segment limbs, IK, foot placement on slopes.
- A first-person camera. Never.

---

## If something goes wrong

- Three fix attempts per stage, then commit what works and move on.
- Never leave the repo uncommitted or the game unable to launch. A stage
  that cannot be completed is not a failure of the run - an unfinished branch
  with no status doc is.
- If a remote view cannot be built from what arrived, build the default
  human and warn. A character that fails to appear is a bug; a game that
  crashes because a friend's beard index was 7 is a disaster.
- If the animation will not look right blind after three passes, ship every
  amplitude at half the table's value, say so, and leave the rest to the F8
  panel. Conservative motion reads as stiff; wrong motion reads as broken.
- If the creation screen cannot be finished, ship the CLI flags and the F8
  cycling, and record it. The data model and the sync matter more than the
  screen.
- If the silhouette metric cannot be made to work, drop it, keep the sheets,
  and say the readability test is by eye only. The sheets are the evidence;
  the number was a convenience.
- If a stage would require touching a file outside the allowed list, stop
  that stage and write down what it would have needed.

## The acceptance test

> Standing in the meadow at dusk with the four races lined up 40 m away,
> Marcel can name each one without walking closer. Then, walking, sprinting
> and jumping his own character across a hillside, it reads as a person
> moving - not a capsule, and not a mannequin sliding over the ground.

`silhouettes-40.png` at `--time 0.82` is the first sentence. The in-game
walk on seed 42 is the second. Three additions:

- **The proportion decision is easy.** `study.png` puts the stocky and lean
  humans side by side at the two distances and the two times of day, and one
  of them is obviously right for this game.
- **A friend is a person, not a peer number.** Joining Marcel's world, they
  see the dwarf he made, named, walking and sitting; he sees their elf.
- **Nothing moved that should not have.** Seed 42's terrain, spawn, and the
  six tour shots are identical to `main`'s; the world self-test passes
  unchanged; `player.gd` contains no per-race number.

Nothing in this plan matters more than those four.
