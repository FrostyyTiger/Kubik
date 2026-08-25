# Character v1 — run status

Unattended run of `docs/plans/character-v1.md`, the night of 2026-08-24, on the
Linux box. All fifteen stages attempted, committed one per stage on
`feat/character-v1`, branched from `7bfba8c`.

It ran the same night as foliage v1, on its own branch, and touched none of the
same files — see **Hard rule 1, checked** below.

---

## Read this first

```bash
# The character system, on its own, without the game
godot --headless --path . scenes/character/selftest_character.tscn

# The world self-test, unchanged, still passing
godot --headless --path . scenes/selftest.tscn

# Every sheet, into build/character/<label>/
godot --path . scenes/character/gallery.tscn -- --label look-at-this

# Just the one you want
godot --path . scenes/character/gallery.tscn -- --label x --sheet study
godot --path . scenes/character/gallery.tscn -- --label x --sheet silhouettes --time 0.82

# In the game. F8 is the character panel; T is gear; X sits, B goes down, V waves.
godot --path . -- --host --seed 42
godot --path . -- --host --seed 42 --race dwarf --name Marcel
```

The sheets from the final pass are already on disk in
`build/character/character-final/`.

---

## What wants your judgement, in order

### 1. The proportion study — this is the decision the run is waiting on

`build/character/character-final/study-*.png`, ten images.

The stocky human and the lean human, side by side, at 4 m (detail), 15 m and
40 m, at noon and at dusk, front and three-quarter. Same rig, same animator,
same palette — one part set with different numbers in it. That was the point of
single-segment limbs in both schemes: if the two needed two animators the study
would be measuring the animator.

Both are exactly 2.0000 m. The stocky one is 3308 triangles with hair, the lean
one 2352.

Start with `study-detail-4m-three-quarter.png` for the shapes, then
`study-noon-40m-front.png` for whether the difference survives the distance the
game is actually played at. The 4 m pair is not in the plan's list; it is there
because at 15 m a 2 m character is sixty pixels tall and a proportion decision
is also a decision about shapes.

Whichever you pick, the other should be deleted, not left as an option — see
**Next step**.

### 2. The 40 m dusk lineup

`silhouettes-40.png` and `silhouettes-40-hill.png`, plus `-15` and `-80` of
each. The acceptance test's first sentence: four races at 40 m at dusk, named
without walking closer.

Then `masks-40.png` and the IoU table below it. **One pair does not separate
front on** and the reason is structural rather than a mistake — read the
silhouette section before deciding what to do about it.

### 3. The animation feel

`anim-stocky-human-walk.png`, `-sprint.png`, `-jump.png`, `-poses.png`, and the
same for every race. Eight frozen phases of one cycle in a row, which is the
only form of animation review that can be diffed between two runs.

Everything about it is a knob on the F8 panel and every one of those knobs was
chosen on the wrong renderer. See **Tuned blind**.

---

## Hard rule 1, checked

Nothing on the never-touch list was modified. Against the branch point:

```bash
git diff --stat 7bfba8c -- scripts/world/ scripts/net/ \
  scripts/tools/selftest.gd scripts/tools/screenshot_tour.gd \
  scripts/tools/worldgen_probe.gd scripts/tools/traversal_probe.gd \
  scripts/ui/debug_hud.gd scenes/selftest.tscn
# (no output)
```

The existing files this branch DID edit are exactly the ones the plan allowed:
`scenes/player.tscn`, `scripts/player/player.gd`, `scenes/remote_player.tscn`,
`scripts/player/remote_player.gd`, `scripts/game/game.gd` (Stage 6 only),
`scenes/game.tscn` (the CharacterDebug layer), `scenes/main_menu.tscn` and
`scripts/ui/main_menu.gd` (Stage 12 only), and the three docs in Stage 15.

`origin/main` has since moved — the foliage run has been landing on it — so
diff against `7bfba8c`, not against `main`.

---

## What got done, per stage

| Stage | What | State |
| --- | --- | --- |
| 1 | Gallery and a second self-test suite | done |
| 2 | The voxel model system: ASCII parts, mesher, baked AO | done |
| 3 | Rig, CharacterDef, Races, the first human in the game | done |
| 4 | Animator, CharacterConfig, the F8 panel | done |
| 5 | Blink, static poses, the generic chain rule, close-camera hide | done |
| 6 | The other players: additive wire fields, appearance announce | done |
| 7 | The lean human and the silhouette metric | done |
| 8 | Elf, dwarf, lizardfolk; three silhouette passes | done, one pair over |
| 9 | Every hair, beard and crest; the option sweep | done |
| 10 | Six sockets, three placeholders, the overlap check | done |
| 11 | The `.vox` importer and the drop-in rule | done |
| 12 | The creation screen | done |
| 13 | The critter and the gait table | done |
| 14 | The budget and the last pass | done |
| 15 | This document, and the three doc edits | done |

28 self-tests in `selftest_character.tscn`, all passing. The world suite is
unchanged and still passes.

---

## Every measured number

### Triangles

Mesh triangles, from the ArrayMesh index arrays. The budget is **6000 for a
stocky character with hair and beard**, and every race is under it.

| | mesh | + gear | drawn |
| --- | --- | --- | --- |
| stocky human | 3308 | 3676 | 6616 |
| stocky elf | 2848 | 3216 | 5696 |
| **stocky dwarf** | **4104** | 4472 | 8208 |
| stocky lizardfolk | 3564 | 3932 | 7128 |
| lean human | 2352 | 2720 | 4704 |
| critter (not a budget) | 1820 | — | 3640 |

`drawn` is `RENDER_TOTAL_PRIMITIVES_IN_FRAME` with the pad's 10 subtracted, and
it is **exactly twice** the mesh count on every row. That is the shadow pass —
every triangle is submitted once for the shadow map and once for the scene. It
is worth watching rather than ignoring: a *third* copy would mean something is
genuinely being drawn twice, which is what the eyes-closed head variant would
do if it were ever left visible alongside the open one.

The dwarf is the worst because it has the biggest head, the widest torso and a
mandatory beard. Its full beard is the single largest part in the game.

### Animator cost

**0.045 to 0.053 ms per character per frame**, averaged over 600 frames after a
60-frame warm-up, `update()` and `apply()` together, on this box under
llvmpipe. Budget 0.15, so about a third of it, and four players cost about
0.2 ms of a 16.6 ms frame.

Reported, not gated. A threshold measured on llvmpipe would fail on a machine
that is faster in every other respect.

### The walk cycle

| | value |
| --- | --- |
| Stocky human stride at walk | 1.429 m per cycle |
| Stocky human stride at sprint (13 m/s) | 3.714 m per cycle |
| Leg rate at sprint | 3.50 Hz — the `cycle_hz_max` cap, exactly |
| Stride order | dwarf < human < elf, from one line of arithmetic |
| Sprint torso lean, settled | 12.00 deg (config says 12.0) |
| Walking torso lean | 0.00 deg |
| Chain lag between links | 0.150 s (config says 0.15) |
| Blinks per minute | 12 to 13; eyes shut 2.7 to 2.9% of the time |

### Heights, measured off the built rig

At the crown, ornaments excluded — see the departures list.

| | measured | table | with hair/crest |
| --- | --- | --- | --- |
| stocky human | 2.00 m | 2.00 | 2.12 |
| lean human | 2.00 m | 2.00 | 2.25 |
| stocky elf | 2.25 m | 2.25 | 2.38 |
| stocky dwarf | 1.50 m | 1.50 | 1.62 |
| stocky lizardfolk | 1.93 m | 1.88 | 2.33 |

The lizardfolk is 0.05 m over its tabled 1.88 because its 8 degree forward lean
is baked into the hips rest pose and the measurement is an axis-aligned bound
of the leaning body. Within one voxel, which is what the test allows.

### The silhouette metric

Unshaded black on white at 40 m, each subject cropped to its own bounding box
and aligned bottom-centre. **Target: every RACE pair under 0.70.**

Front on — the judged view, since a lineup at 40 m is what the acceptance test
describes:

| pair | IoU | |
| --- | --- | --- |
| human / elf | 0.608 | |
| human / dwarf | 0.561 | |
| **human / lizardfolk** | **0.868** | **over** |
| elf / dwarf | 0.372 | |
| elf / lizardfolk | 0.580 | |
| dwarf / lizardfolk | 0.593 | |
| elf / lean human | 0.635 | |
| dwarf / lean human | 0.530 | |
| lizardfolk / lean human | 0.667 | |
| *stocky / lean human* | *0.659* | *reference, not judged* |
| *human / capsule* | *0.732* | *reference* |
| *elf / capsule* | *0.444* | *reference* |
| *dwarf / capsule* | *0.661* | *reference* |
| *lizardfolk / capsule* | *0.725* | *reference* |
| *lean human / capsule* | *0.565* | *reference* |

Three-quarter on, reported and not judged:

| pair | IoU |
| --- | --- |
| human / elf | 0.595 |
| human / dwarf | 0.575 |
| **human / lizardfolk** | **0.619** |
| elf / dwarf | 0.325 |
| elf / lizardfolk | 0.466 |
| dwarf / lizardfolk | 0.598 |
| elf / lean human | 0.643 |
| dwarf / lean human | 0.462 |
| lizardfolk / lean human | 0.535 |

Across **every** hair and beard option, front on: 94 cross-race variant pairs,
15 over 0.70, and every one of the 15 is human-vs-lizardfolk. Worst 0.903, with
the frill.

Two schemes of one race are not a judged pair — they are two ways of drawing
the same person and are supposed to look alike. A capsule is not a race anyone
has to tell apart from a human at dusk; it is in the table because "is a
character more readable than the thing it replaced" is worth a number.

**Three passes were spent on this, as the plan allows. Here is all three, plus
the final re-shoot** — pass 3 and final differ by a few thousandths because the
lineup's chest height, and so the camera, moves with whoever is standing in it:

| | human/elf | human/lizard | elf/lizard | elf/lean | over |
| --- | --- | --- | --- | --- | --- |
| pass 1 | 0.667 | 0.750 | 0.545 | 0.789 | 3 |
| pass 2 | 0.735 | 0.885 | 0.714 | 0.789 | 3 |
| pass 3 | 0.588 | 0.875 | 0.611 | 0.650 | 1 |
| final | 0.608 | 0.868 | 0.580 | 0.635 | 1 |

**Pass 2 is worse than pass 1 because pass 2 fixed a bug in the harness, not in
the models.** `_mask_of()` was rendering each subject from wherever the previous
sheet had left the camera. The pass 1 numbers were measured from an undefined
viewpoint and should be read as void.

What changed between passes, and only ever the *differentiating* feature:

- The elf's ears went from two voxels out to three, and swept.
- The elf's torso and legs narrowed from 6 and 3 to 5 and 2. "Width" is on the
  plan's own list of what an elf may be exaggerated by, and the ears alone are
  a handful of pixels at head height against a mask dominated by
  torso-and-legs mass.
- The lizardfolk's default crest went from 2 x 4 to 3 x 7 and now rakes
  backward.

**The human/lizardfolk pair will not separate front on, and it was designed
that way.** The lizardfolk's body IS the human's body — same 8 x 5 torso, same
9-voxel legs — precisely so the test can tell which feature is doing the work.
Two of its three differentiating features, the tail and the snout, are PROFILE
features a front-on mask cannot see at all. Front on, the crest is the only
lever there is, and no plausible crest moves a number dominated by an identical
torso and identical legs.

Three ways forward, none of them taken here because this is your call:

1. **Accept it.** Three-quarter on the pair is 0.619 and no race pair exceeds
   0.70 in that view. In play you see characters from every angle, and the
   14-voxel tail is nearly half a body length.
2. **Give the lizardfolk its own body.** Digitigrade legs, a longer torso, a
   forward-leaning stance that is more than 8 degrees. That is the honest fix
   and it is a change to the race table, not to this code.
3. **Judge the metric three-quarter on.** One line in
   `_sheet_masks_40`. It is a weaker test but it is the one that can see a
   tail.

### The world, unchanged

- Seed 42 spawn: `(-44, -124)`, altitude 56 blocks, released at 31.0 m — the
  same numbers `main` produces.
- Coarse heightmap hash `76cccdb6`, 53 lakes, 65656 m², identical.
- The screenshot tour produces its six shots with **no character in any frame**
  — the close-camera hide covers the tour, which parks the player at the
  camera's eye, without touching `screenshot_tour.gd`.
- Every race walked seed 42 with `--traverse --view low` for 3600 frames:
  **zero script errors and zero warnings**, five for five.

### Two peers

```
godot --headless --path . --quit-after 3000 -- --host --seed 42 --race dwarf --name Marcel
godot --headless --path . --quit-after 3000 -- --join 127.0.0.1 --race elf --name Friend
```

Host log:

```
[Game] appearance for peer 727605351: elf "Friend"
[RemotePlayer] peer 727605351 (peer 727605351) is a stocky human
[Game] spawned a character for peer 727605351
[RemotePlayer] peer 727605351 (Friend) is a stocky elf
```

Client log:

```
[RemotePlayer] peer 1 (peer 1) is a stocky human
[Game] spawned a character for peer 1
[RemotePlayer] peer 1 (Marcel) is a stocky dwarf
```

Zero script errors on either side. Each peer appears first as the default human
and then becomes itself — that is the ordering Stage 6 designed for and
deliberately did not try to prevent: the appearance rides its own reliable RPC
and a row can exist before it lands, so a late joiner needs no special case.

**The hostile-payload case is covered offline, not live.** A client sending
`[9, 99, 99, ...]` must produce a valid default human and a warning; proving
that live would need a deliberately-lying client, which is test scaffolding in
shipped code. Instead `_test_def_from_strangers` feeds `CharacterDef.from_bytes`
— the exact function the host calls — 100 well-formed payloads full of garbage
plus four malformed ones, and `_test_remote_row` feeds `RemotePlayer` the four
row shapes it will really see including that payload. Both pass.

**The two-peer test could not be run for most of the night.** The foliage run
hosts on the same UDP port, and a client started into it would either fail to
bind or — much worse — join that branch's world. It was run at the first gap
and again at the end.

### Not measured

- **Bytes on the wire.** The plan estimates ~70 bytes per player per tick and
  asks for a measurement if one is possible. Godot's `MultiplayerAPI` does not
  expose per-RPC payload sizes and packet-capturing the loopback would have
  meant a tool this run does not need. The estimate stands as an estimate.
- **Boot to `is_idle()` at High.** The claim is "no change", and it is
  structural rather than measured: this branch touches no file under
  `scripts/world/`, which the diff above proves. A timing comparison against
  `main` on a box that was running another Godot workload all night would have
  been noise.

---

## Tuned blind — re-check these first

This box has no display. Godot falls back to OpenGL Compatibility on llvmpipe
under Xvfb; you run Forward+ on an RTX 5080. **Every value in this section was
chosen on a renderer that is not yours.**

The deal the plan strikes is that tuning blind is allowed provided nothing
chosen by eye is hardcoded. It is not: every animation number below is a spin
row on the **F8 panel** in game, and saves to `user://character_tuning.tres`.

### The one that will hit you first

**The outfits read as near-black.** Cloth `#7A6A4F` is linear (0.194, 0.145,
0.078) and leather `#3A2A1E` is (0.038, 0.021, 0.012) — against meadow green's
(0.238, 0.434, 0.069). On this renderer the whole lower body is one dark mass
and only the head has any colour in it. Those hex values are the plan's and
were not changed; if they look the same to you, the trousers and boots are the
first thing to lift.

### Animation knobs — `CharacterConfig`, all on F8

| Knob | Plan | Shipped | Note |
| --- | --- | --- | --- |
| `walk_swing_deg` | 35 | 35 | unchanged |
| `sprint_swing_deg` | 60 | 60 | unchanged |
| `arm_swing_ratio` | 0.8 | 0.8 | unchanged |
| `precision_swing_ratio` | 0.4 | 0.4 | unchanged |
| `sprint_lean_deg` | 12 | 12 | unchanged |
| `bob_walk_vox` / `bob_sprint_vox` | 1.5 / 3.0 | 1.5 / 3.0 | unchanged |
| `stride_walk_m` | 1.3 | 1.3 | unchanged |
| `cycle_hz_max` | 3.5 | 3.5 | unchanged |
| `pose_smoothing` | 10 | 10 | unchanged |
| `jump_tuck_deg` | 25 | 25 | unchanged |
| `fall_arms_deg` | 30 | 30 | unchanged |
| `land_squash_vox` / `_ms` | 2 / 120 | 2 / 120 | unchanged |
| `breath_hz` / `breath_vox` | 0.25 / 0.5 | 0.25 / 0.5 | unchanged |
| `blink_min_s` / `_max_s` / `_ms` | 3 / 6 / 120 | 3 / 6 / 120 | unchanged |
| `look_yaw_deg` / `_pitch_deg` / `_smoothing` | 60 / 25 / 8 | 60 / 25 / 8 | unchanged |
| `tail_hz` / `tail_deg` / `tail_lag` | 1.2 / 12 / 0.15 | 1.2 / 12 / 0.15 | unchanged |
| `view_hide_m` | 1.0 | 1.0 | unchanged |
| `ao_strength` | 0.35 | 0.35 | unchanged |
| **`sit_lift_vox`** | — | **1.5** | new, see departures |
| **`downed_lift_vox`** | — | **2.5** | new, see departures |

Every amplitude is the plan's starting value. Nothing needed halving, which is
the fallback the plan offers if the motion would not read — the strips look
like walking and running at these numbers on this renderer.

### Race dimensions changed from the plan's table

| Race | Field | Plan | Shipped | Why |
| --- | --- | --- | --- | --- |
| all | pelvis | — | 4 / 3 / 0 / 2 | the table stacks to 28 and the human is 32 |
| dwarf | torso | 10 | 9 | 5 + 10 + 10 overshoots its total of 24 |
| elf | `ear_out` | 2 | 3 | silhouette pass 3 |
| elf | `torso_w` | 6 | 5 | silhouette pass 3 |
| elf | `leg_w` | 3 | 2 | follows the narrower torso |
| lizardfolk | crest (default) | — | 3 x 7 | silhouette passes 2 and 3 |
| lean human | eyes | 1 x 2 | 1 x 2, all iris | no room for white beside it |

### Palettes

Every hex in `Races` is the plan's, unchanged, and every one was judged on the
wrong renderer. The skins read well; the outfits do not (above). The critter's
hide `#6B5B45` is not in the plan and was chosen here.

---

## Departures from the plan, and why

Ordered by how much they matter.

### 1. The proportion table stacks to 28 voxels and the human is 32

"Head 9, Neck 0, Torso 10, Legs 9" is 28, or 1.75 m, against a total of 32 =
2.00 m that the plan states twice and makes a self-test of.

Rather than inflate three tabled numbers, the four voxels went into a **pelvis
on the `hips` bone** — which the plan's own bone list already required and
which its "every bone has a part or is a socket" rule already wanted. Every
tabled number is preserved exactly and the built human measures 2.0000 m.

The dwarf needed the opposite: 5 + 10 + 10 is 25 against a total of 24. The
torso gave the voxel up, because the head and the beard are half of what makes
a dwarf nameable at 40 m.

### 2. The `.vox` depth axis is the mirror of the plan's formula

The plan specifies `model.z = size_y - 1 - vox.y` and — correctly — says to
prove the mapping with a fixture rather than by reasoning about it.

The fixture marks the voxel a MagicaVoxel user sees at the FRONT of the default
view, which is minimum Y, and asserts it comes out on the `-Z` side, which is
`Vector3.FORWARD` and is where this game's faces are. The mapping that
satisfies that is `model.z = vox.y`, **unflipped**. The plan's formula would
load every model back to front.

`VoxLoader.FLIP_DEPTH` is the one line to change if real exports ever come out
the wrong way, and the fixture's expectation flips with it. **This is the first
thing to check when real `.vox` art arrives.**

### 3. `sit` and `downed` cannot both put the hips "at ground level"

The plan says both do. A sitting character rests on its thighs and a downed one
on the depth of its whole body, which is thicker, so the two hip heights differ
by construction. The difference was chosen by eye, which under the plan's own
rule means it had to go in `CharacterConfig` rather than in the animator —
hence `sit_lift_vox` and `downed_lift_vox`, both on the F8 panel.

### 4. The plan's "2 x 2 x 2 part meshes to 6 faces and 12 triangles" is the
1 x 1 x 1 answer

With no greedy merge a solid 2-cube has four voxel-faces per side: 24 quads, 48
triangles. The plan's own "3 x 3 x 3 culls to exactly 54 quads" agrees with
that arithmetic and not with the 2-cube line. All three cases are checked
against what the stated rule actually implies.

### 5. The anchor is a lattice point, not a voxel index

The plan writes `"anchor": Vector3i(4, 0, 4)` for an 8-wide head. Read as a
voxel index that puts the head's middle half a voxel — 3.1 cm — to one side,
which is a visible list on a character whose whole readability argument is
symmetry. Read as a lattice coordinate, where integers fall on voxel
*boundaries*, `(4, 0, 4)` is exactly the bottom-centre of an 8-wide head — the
plan's own number, exactly right instead of nearly right. Anchors are `Vector3`
and may be fractional, negative, or past the end of the part.

### 6. `Rig.height_m()` excludes hair and crests by default

The race table measures a race at the CROWN, which the plan says for the
lizardfolk in as many words. Four voxels of crest would otherwise make a
lizardfolk 2.14 m in the height test and 1.88 m in every other sentence about
it. Pass `true` for the silhouette's real extent, which is what the mask metric
sees.

### 7. `Animator.pose_for` takes two more parameters than the plan writes

The plan writes `pose_for(state, phase, t)`. It takes `config` and `dims` as
well, because "every value chosen by eye lives in `CharacterConfig`" and a pure
function cannot reach a member variable. A sixth parameter, `extra`, carries
the values `update()` smooths over time — the head look, the landing dip, the
wave countdown — which are stateful by nature and would otherwise be the one
thing forcing this function to stop being pure.

### 8. The variants sheet is two rows, not a grid

A grid on a flat pad means putting the back row further from the camera, which
changes its scale and its light and makes the two rows incomparable — the one
thing a variants sheet must not do. `variants-<race>.png` is every hair x beard
combination in one row and `palettes-<race>.png` is every palette in another,
both at one distance.

### 9. The gallery's wall is wider than its pad

The pad is the plan's 60 x 120 m. At 80 m the frame is 123 m across, so a 60 m
wall would be a stripe with sky either side — neither the sky variant nor the
hill variant. The wall is 160 m wide.

---

## Things that were nearly debugged for being correct

Recorded because each one cost real time and each would cost it again.

- **The gallery's first "front" sheet was a row of backs.** A character faces
  `-Z` and the camera backs away along `+Z`. Every silhouette sheet and the
  whole mask metric would have measured the wrong side of the character. It is
  a named constant now, in the gallery and in the creation screen's turntable.
- **A sitting character photographed from the front looks like a standing
  character with short legs**, because its legs point along its own forward
  axis, straight at the camera. The pose strip is shot at 55 degrees.
- **"At zero speed the pose converges on idle" failed on the tail**, which the
  plan's own table says has idle sway. A first-order blend chasing a 1.2 Hz
  sine also lags it by 37 degrees of phase by construction, so "has the blend
  caught up" is not a well-formed question about a bone that is never trying to
  arrive anywhere.
- **`ArrayMesh` stores vertex colours as RGBA8**, so an AO shade of 0.650 reads
  back as 0.647. The AO test's tolerance is one colour step and says why.
- **`md5` is the wrong tool for comparing two renders.** llvmpipe's rasteriser
  is multithreaded and two runs of the same scene differ by a few
  least-significant bits. "Nothing about the stocky human changed" is checked
  pixel by pixel: 0 of 921600 differ on the walk and jump strips, 4 and 1 on
  sprint and poses, worst channel delta 11/255 at a triangle edge.
- **`_srv_report_state` must MERGE into a peer's row, not replace it.** The
  obvious `_states[who] = {...}` wipes the appearance twenty times a second,
  and the symptom is a friend flickering back to the default human rather than
  anything that looks like a protocol bug.
- **Two parts authored on lattices half a voxel apart share no mesh vertex**
  even when they occupy the same space, so the gear overlap check compares
  voxel *centres* with a half-voxel tolerance.

---

## What was NOT done, and why

- **Nothing from the plan's "Not in this plan" list.** No perks, no XP, no gear
  system, no character persistence in the world save, no host-authoritative
  input, no enemy AI, no combat animations, no swimming, no two-segment limbs,
  no first-person camera.
- **Bytes on the wire were not measured** — see Not measured.
- **The boot-to-idle comparison was not run** — see Not measured.
- **The live hostile-payload test was not run** — see Two peers. It is covered
  offline against the same function.
- **`sit`, `downed` and `wave` are biped-only** and name `hips` and `torso`
  directly. Those are things people do; the gait table is about LOCOMOTION,
  which is the part every skeleton has. A quadruped that needs to lie down can
  have its own entry when something asks for one.
- **`--slots` is not a per-part flag.** The plan describes a `.vox` whose
  palette indices 1..13 mean the thirteen slots, "when `--slots` is set on the
  part". The drop-in path always sets it, because a drop-in that could not take
  a skin swap would break the creation screen for anyone who used one. An
  artist who wants literal colours can call `VoxLoader.load_part(path, false)`
  directly.

---

## The exact next step

1. **Decide the proportion scheme.** Then delete the loser: remove
   `PartsHumanLean` or fold it in as the human's only set, set
   `Races.HAS_LEAN` to all false, and drop `build` from `CharacterDef`'s
   validation. One byte of the wire format comes free with it. Leaving both is
   the expensive option — it doubles every part set forever.
2. **Look at `masks-40.png` and pick one of the three options** in the
   silhouette section for the human/lizardfolk pair.
3. **Lift the outfit colours** if they read as dark to you too.
4. Then merge, or say what wants changing first.

Three `TODO(marcel)` exercises are waiting, all in `animator.gd`, all with a
working fallback and a hint:

- `_stride_capped()` — a stride that knows the difference between a walk and a
  run, instead of two regimes with a corner between them.
- `_apply_head_look()` — the torso follows the head past the clamp, so looking
  over your shoulder brings the body round instead of stopping dead.
- `_update_blink()` — blinks cluster, and a character about to turn its head
  blinks first.

---

## What the next three plans need from this

### The first-enemy plan

- **The critter is your starting point.** `parts_critter.gd`, a bone table with
  no `torso` and no `hips`, and `critter-walk.png`. It has a `back` socket and
  a two-link tail on the same chain rule the lizardfolk uses.
- **`Animator.RIG_SHAPES` is the gait table.** Add an entry, name it in the
  dimension table's `gait` field, and the animator walks your creature. An
  unknown gait falls back to the biped with a warning rather than a crash.
- **`LocomotionState` is the seam.** An enemy driven by AI fills the same
  struct a player fills from input; the animator never learns which.
- 1820 triangles for the critter, and 0.05 ms of animator per creature per
  frame on the slowest machine in this project.
- What it does NOT give you: AI, spawning, health, a scene, or a hitbox. The
  critter is a gallery model.

### The campfire plan

- **`sit` exists and travels on the wire.** Bits 4-6 of the state byte carry
  the pose id, so a friend sees you sit today. `Animator._pose_sit` is the
  pose; `sit_lift_vox` is its one knob.
- **The `X` key is scaffolding and says so in the code.** It is the first thing
  your plan should delete, once something real triggers the pose.
- **Six sockets on every race**, so "your character sitting at the campfire IS
  the progress screen" has somewhere to hang what the character is carrying.
- `Races.eye_height_m(race, build)` gives you where a character is looking
  from, per race, if the fire wants a camera framing.

### The gear plan

- **The sockets are done and proven**: `hand_r`, `hand_l`, `neck`, `chest`,
  `back`, `belt`, on all four races and both builds, positioned from each
  race's own numbers. `Rig.attach_to_socket()` hangs a part on one.
- **The overlap check is written**: `Rig.socket_voxel_centres_in_rig()` and the
  test in `selftest_character.gd` compare voxel cells rather than AABBs, which
  is what you need when a dwarf's torso is 7 voxels deep and an elf's is 4.
- **The three placeholders are placeholders.** The sword rises rather than
  hangs because a 14-voxel sword pointing down from a dwarf's hand is nine
  voxels underground; the pendant floats slightly proud of a narrow chest
  because a cord that sloped back would put two voxels inside a dwarf. Both are
  the sort of thing per-race offsets fix, and per-race offsets are yours.
- **Nothing about gear is on the wire.** `CharacterDef` is eight bytes and has
  no room; adding a ninth is a wire version bump, and `from_bytes()` already
  rejects an unknown version with a warning rather than misreading it.
- **The chest slot belongs to you**, and v1 baked one outfit per race into the
  torso part to keep out of your way.

---

## Files

New:

```
scripts/character/voxel_model.gd        parts, the mesher, baked AO
scripts/character/races.gd              every per-race number in the game
scripts/character/character_def.gd      eight bytes and a name
scripts/character/character_config.gd   every knob chosen by eye
scripts/character/locomotion_state.gd   the seam between physics and animation
scripts/character/rig.gd                bones, sockets, attachments
scripts/character/animator.gd           procedural animation, the gait table
scripts/character/character_view.gd     the single visual entry point
scripts/character/vox_loader.gd         MagicaVoxel, and the drop-in rule
scripts/character/parts/*.gd            nine part files
scripts/ui/character_debug.gd           the F8 panel
scripts/ui/character_creation.gd        the creation screen
scripts/tools/character_gallery.gd      every sheet
scripts/tools/selftest_character.gd     28 tests
scenes/character/gallery.tscn
scenes/character/creation.tscn
scenes/character/selftest_character.tscn
assets/characters/README.md             how to drop in .vox art
```

Edited, and only these: `scenes/player.tscn`, `scripts/player/player.gd`,
`scenes/remote_player.tscn`, `scripts/player/remote_player.gd`,
`scripts/game/game.gd`, `scenes/game.tscn`, `scenes/main_menu.tscn`,
`scripts/ui/main_menu.gd`, `docs/DESIGN.md`, `docs/IDEAS.md`, `STATUS.md`.
