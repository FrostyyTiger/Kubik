# Character v2 - tech plan: the grid, the joint, the liner, the ladder

The build plan for `docs/plans/character-v2.md`. That document decides what the
people should look like; this one is the procedure that gets there: numbered
stages, one commit each, every stage with its file list, its evidence, and a
verify step that is a **count** rather than an opinion.

Written 2026-08-28 on `feat/character-v2`, against `main` at **`f23c3f0`**
(distance v1 night 2 merged, which matters - see Stage 10). Two nights, one
branch. Nothing under `scripts/` or `tools/` was touched by the run that
produced this file.

**Night 1 is the grid and the bodies** (Stages 0-6): measure, the palette, the
generator parameterisation, the move to 96, the knee and the elbow, and the
four races re-authored. It ends on a build that is playable and complete and
has no armour and no new animation - a real checkpoint.

**Night 2 is armour, animation and the record** (Stages 7-13). It starts from
night 1's last commit, never from `main`, because every armour piece is fitted
to a body night 1 rebuilds.

---

## What was measured before this plan was written

Four things, all on ganymede, all on the GPU. They are here because two of them
contradict something the design doc says, and a plan that inherited those
numbers would have inherited the contradiction.

### 1. The harness works, and the triangle number reproduces exactly

```
xvfb-run -a ~/bin/godot --path . scenes/character/gallery.tscn -- --label v2-tech-probe --sheet budget
```

`Vulkan 1.4.329 - Forward+ - NVIDIA GeForce RTX 3070 Ti`, and:

| | mesh | + gear | drawn |
| --- | --- | --- | --- |
| stocky human | 17,052 | 18,356 | 34,104 |
| stocky elf | 14,692 | 15,996 | 29,384 |
| **stocky dwarf** | **17,788** | 19,092 | 35,576 |
| stocky lizardfolk | 16,592 | 17,896 | 33,184 |
| critter (not a budget) | 7,280 | - | 14,560 |

17,788 is the design doc's number, to the triangle. Budget 24,000. `--sheet
budget` writes **no images** and prints this table, which makes it the cheapest
gate in the project: it is one command, it takes under a minute, and every
number in it is a count.

### 2. The IoU harness is bit-stable on this GPU - and the recorded numbers are wrong

`--sheet masks-40`, run three times:

| pair | this run, x3 | `docs/status/character-v1.md` (llvmpipe) | design doc claims |
| --- | --- | --- | --- |
| human / elf, front | **0.530** | 0.608 | - |
| human / dwarf, front | **0.561** | 0.561 | - |
| **human / lizardfolk, front** | **0.913** | 0.868 | "reproduced on the GPU: 0.868" |
| elf / dwarf, front | **0.357** | 0.372 | - |
| human / lizardfolk, three-quarter | **0.759** | 0.619 | "0.619 and no pair exceeds 0.70" |

Three runs, identical to the thousandth every time. So:

- **The metric is a count and it survives noise.** One run gates a stage. It
  needs no ABAB, no median, no spread. That is the property this whole plan is
  built on.
- **Every IoU number in `docs/status/character-v1.md` is void as a baseline.**
  They were measured on llvmpipe in Compatibility. They are not reproducible on
  the renderer the game ships on and they must not be compared against.
- **The design doc's 0.868 is not a GPU number.** The GPU number is 0.913. The
  worst pair is worse than recorded, not better.
- **The option sweep's headline numbers do reproduce**, which sharpens the
  point rather than softening it: `--sheet masks-options` on the GPU reports
  **94 cross-race variant pairs, 15 over 0.70, worst 0.928** - the same counts
  and the same worst case as the llvmpipe record. So the *sweep* is stable
  across renderers and the *default pair* is not, and the reason is that the
  sweep's worst case is a hair combination that was already extreme while the
  default pair sits where a few pixels of antialiasing decide the number. Both
  are re-baselined in Stage 0; neither is taken from character v1.
- **The escape hatch the v1 status doc offered is gone.** Its option 3 was
  "judge the metric three-quarter on", on the strength of 0.619. On the GPU that
  view is **0.759**, which is over the 0.70 target. There was never a view in
  which the human and the lizardfolk separated. The rebuild is not the expensive
  option any more; it is the only one.

Stage 0 re-baselines all of it and writes the corrections into the status doc.

### 3. The parallel lane did not start

The brief said a Kimi-backed session was making `tools/parts_author/`
resolution-parametric on its own clone, and to check the path before writing
that stage. Checked, **2026-08-28 14:19 UTC**:

```
sg agents -c 'ls -la /home/kimi/work/'
# character-research-kimi.md   20,909 bytes, Aug 27 20:18
# fizzbuzz.js                     143 bytes, Aug 27 12:37
# .claude/
```

There is no clone of this repository anywhere under `/home/kimi` (`find` for
`parts_author`, `voxlib.py`, `Kubik*` and `*.git` returns only `.nvm/.git`).
Nothing in `/home/kimi/work` has been modified since 20:18 on the 27th. The two
`claude` processes running under that account are the fizzbuzz smoke test and
the **research** brief - `/tmp/kimi_brief.md`, which asks for one markdown file
and says nothing about the generator.

So the lane produced the research document folded into the design doc, and it
never produced a parameterisation. **Stage 2 is written to do the work here.**
The integration path, if a clone appears later, is at the top of that stage.

### 4. `Look.figure_material()` stopped being shared yesterday

This is the one that changes an answer. On 2026-08-27 the character material had
two callers: `VoxelModel.material()` and `FarTreeMeshes.material()` - the
impostor forest. Distance v1 Stage 6 (`987b076`, merged in `f23c3f0` this
morning) split them: impostors now take `Look.far_tree_material()`, and
`figure_material()` has exactly one caller, which is characters.

That is what makes Stage 10 possible. Before it, adding an emissive channel to
the character material would have set two thousand cones on every distant
hillside glowing. See Stage 10.

---

## Where I disagree with the design doc

The house rule is that Marcel wants the disagreement rather than compliance.
Six, in descending order of how much work they save or cost.

### 1. Four new bones do NOT invalidate every existing pose - if they are added rather than substituted

The design doc's tech-list item 7 says `pose_for()` is fine but "every existing
pose - locomotion, sit, downed, wave - describes limbs that no longer exist in
one piece", and its animation section says the bone table goes to `leg_upper`,
`leg_lower`, `arm_upper`, `arm_lower`.

Rename them and that is true. **Do not rename them.** `Rig.apply_pose()` has one
contract and it is written down in the file: *"A pose that says nothing about a
bone leaves it at rest, so the animator only has to describe what it is actually
moving and a new bone cannot break an old pose."*

So: `leg_r` stays the name of the hip bone and gains a child `leg_r_lower`;
`arm_r` stays and gains `arm_r_lower`. Then

- `_pose_sit`, `_pose_downed` and `_apply_wave` compile and run unchanged, and
  produce today's poses with straight lower limbs, which is what they draw
  today;
- `IDLE_BONES` in `selftest_character.gd` needs no edit;
- `RIG_SHAPES["trot"]` and the critter's four legs need no edit - a rig shape
  with no `lower` key is a rig with no knee, which is the correct description of
  a critter;
- `Animator.pose_for()` gains entries rather than losing them.

Four static poses then get their knees *refined* as a deliberate improvement
(Stage 4), instead of being rewritten to keep working. The distinction is the
difference between a stage and a rewrite.

The cost of the choice is that `leg_r` names a thigh, which is slightly
dishonest. The *part* keys get honest names instead - `leg_upper`, `leg_lower` -
because a part key is an asset contract with exactly one consumer
(`assets/characters/README.md`, and that directory ships empty), while a bone
name is a pose contract with a dozen. Rename the cheap one.

### 2. Item 12 does not need the two voxel formats to become one array shape

The comment in `voxel_model.gd` promises "a ten-line change once both branches
have landed", meaning `Vector4i(x, y, z, slot)` and flora's
`[x, y, z, colour, emissive]` become one thing.

They should not. Flora resolves colours at author time and characters resolve
them through a per-character palette - that difference *is* the palette-swap
feature, and collapsing it would cost the creation screen. What the two formats
actually have to agree on is the **channel**: emissive travels in the vertex
colour's alpha, authored per voxel, read by one shader line.

And a character does not need a fifth component to say so, because it already
has a semantic slot. **An emissive voxel is a voxel in the `GLOW` slot**, and
which slots glow is a one-entry table - habit 1, facts as data. `build_mesh()`
already passes `color.a` through from the palette untouched. So the change is:
one slot, one alpha in `Races.palette()`, one uniform, one shader line. It is
smaller than the promise, not larger, and it leaves both formats where they are.

### 3. Armour belongs on `CharacterDef`, but not in the save file

Item 4 puts six armour slots on `CharacterDef`. Right, for one announce path and
one rebuild path - but `CharacterDef` is also `user://character.tres`, the
player's chosen *appearance*, and `DESIGN.md` is explicit that gear is world
state living in the host's save. If armour is written to `character.tres` then a
player who changes worlds arrives wearing the last world's plate.

So: the six slots ride the wire and **`to_dict()` / `from_dict()` do not carry
them**. Stage 7 says exactly that, and the self-test asserts a round trip through
the dictionary comes back with tier 0 everywhere. Items v1 (Wave 3, G) owns who
sets them; this plan owns only that they can be worn, drawn and announced.

### 4. The tier ladder cannot be *measured* at 15 m, and the design doc asks for it there

The gallery renders at the project's 1280x720. At 15 m a 2 m character is
**62 px tall**, so at 96 voxels one voxel is 0.65 px. The Kimi lane's floor for
an armour piece to read - 2 voxels per side - is 1.3 px of width change. You
cannot count that.

The picture stays at 15 m because that is the judgement Marcel makes. **The count
moves to 3 m**, where a character is ~313 px and one voxel is 3.3 px, and where a
2-voxel event is 6-7 px and unambiguous. Stage 0 builds the metric at that
distance and says so in the sheet's own header, so nobody later reads a 3 m count
as a 15 m claim.

The mask/IoU sheet stays at 1280x720 and at 40 m, untouched, forever - every IoU
number this project has ever recorded was measured there and changing the
viewport would silently move all of them.

### 5. Character v2 is not on the queue, and the plan should say where it goes

`TODO.md` has no character v2 line. Wave 0 is distance v1 (now done); Wave 1 is
creatures, combat and water. This epic is a pillar-2 and pillar-1 job that Marcel
commissioned directly and that has a merged design doc, so it is not jumping the
queue by accident - but the queue should stop being silent about it. Stage 13
adds the line to `TODO.md`, `docs/IDEAS.md` and `docs/ROADMAP.md`, positioned
**before Wave 1**, with the reason: creatures v1 builds a quadruped rig on
`Animator.RIG_SHAPES` and combat v1 builds hit and death poses on `pose_for()`,
and both are cheaper against a rig that already has a knee than against one that
grows one afterwards.

The one thing this plan must not do is build any part of Items v1. No item
table, no inventory, no drops, no what-grants-a-tier. Armour here is a
**visual** system with a byte on the wire and a debug key; Stage 8 says so in
the code, the way `parts_gear.gd` already says "THIS IS NOT A GEAR SYSTEM".

### 6. The design doc's human stack is two voxels short

Small, and worth stating because it is the same slip character v1 found in *its*
plan's table and because a plan that copied it would have shipped it. The design
doc writes the human at 96 as "total 96, legs 24, pelvis 8, torso 30, head 32",
which sums to **94**.

The code cannot reproduce the error: `Races.pelvis_height()` derives the pelvis
as `total - legs - torso - head - neck`, so with the doc's other three numbers
the pelvis comes out at **10**, not 8, and the stack is exact. So the question is
not whether to fix it but which number absorbs it, and the honest answer is the
pelvis - it is the part the stack does not otherwise spend, it is what character
v1 invented it for, and nothing in the design doc's human section is *about* the
pelvis. Stage 5 uses head 32 / torso 30 / legs 24 / pelvis 10.

The elf, dwarf and lizardfolk stacks in the design doc all sum correctly. This is
also why the height self-test measures the built rig rather than summing the
table: a height computed from the table would only prove the table agrees with
itself.

---

## The twelve things the design doc said a plan cannot pretend are free

Every one, and the stage that owns it. Nothing on this list is hand-waved
anywhere below.

| # | the item | owned by | the short answer |
| --- | --- | --- | --- |
| 1 | every part authored at 64, regenerate at 96 | Stage 3 | all seven files are outputs; `python -m tools.parts_author` |
| 2 | `tools/parts_author/` must be resolution-parametric first | Stage 2 | done here - the parallel lane never started; byte-identity at R=64 is the gate |
| 3 | the `.vox` drop-in rule breaks | Stage 3 | documented break plus a size-ratio warning; the directory is empty, so the cost is zero **now** and never again |
| 4 | `CharacterDef` is 8 bytes at `WIRE_VERSION 1` | Stage 7 | version 2 at 20 bytes; `from_bytes()` dispatches on `data[0]` and still parses 8-byte v1 payloads into tier 0 |
| 5 | the retained voxel list in `rig.gd` | Stage 3 | measured, then kept; the fallback is `PackedInt32Array` bit-packing, 24 bytes to 4, and it is specified but not built |
| 6 | the triangle budget moves from 24,000 | Stage 3 | re-measured with `--sheet budget`, never predicted; the constant is set from the measurement |
| 7 | four new bones and every pose rewritten | Stage 4 | additive naming - no pose is rewritten, four are refined. See disagreement 1 |
| 8 | new palette slots, and the ceiling on `SLOT_CHARS` | Stage 1 | 13 to 19; the real ceiling is 91 printable characters and the practical one is the legend a person can hold |
| 9 | the self-tests | Stages 1, 4, 7, 8 | completeness is already data-driven off the bone table and needs no edit for bones; it needs edits for sockets, slots and the armour draw |
| 10 | the gallery needs an armour sheet and a tier sheet | Stages 0, 9 | plus the outline-event metric, which is built in Stage 0 because everything downstream gates on it |
| 11 | the critter | Stage 3 | regenerated with everything else; its `DIMS` are in voxels and would otherwise shrink to two thirds |
| 12 | the foliage/character voxel format | Stage 10 | the channel is unified, the formats are not. See disagreement 2 |

---

## How to use this document

Execute top to bottom. One commit per stage on `feat/character-v2`, named
`feat(character): stage N - <title>`. Every number is a starting value to be
judged with the sheets, not a law - the **hard rules** at the end are the laws.
Where a judgement call remains, keep the build green and record the choice in
`docs/status/character-v2.md`, which is written at the end of every stage and
not only at the end of the run.

Before starting read `CLAUDE.md`, `README.md`, `docs/DESIGN.md` ("Art
direction", "Art pipeline", "Gear", "Races", "Character creation"),
`docs/plans/character-v2.md` (all of it), `docs/status/character-v1.md` (all of
it - it is the case history, and its IoU table is void; see above), and the
comment blocks at the top of `voxel_model.gd`, `rig.gd`, `animator.gd`,
`races.gd`, `character_def.gd`, `vox_loader.gd` and `tools/parts_author/voxlib.py`.
They contain the reasoning this plan is built on and most of them are longer
than the code they sit above, on purpose.

Godot 4.7.2. **`godot` is at `~/bin/godot` and is not on `PATH`.** Ganymede now
renders on the GPU: `xvfb-run -a` gives `Vulkan 1.4.329 - Forward+ - NVIDIA
GeForce RTX 3070 Ti`, so for the first time in this project's history every
visual judgement in a character run is made on the renderer the game ships on.
Say so in the status doc; it is the single biggest difference between this run
and character v1.

After any pull that adds a `class_name` script:
`~/bin/godot --headless --path . --import`.

### Evidence

```bash
G=~/bin/godot

# The two self-test suites. Green at the end of every stage, both of them.
$G --headless --path . scenes/character/selftest_character.tscn
$G --headless --path . scenes/selftest.tscn

# The counts. No images, one table, under a minute.
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label <label> --sheet budget
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label <label> --sheet masks-40
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label <label> --sheet masks-options
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label <label> --sheet outline     # Stage 0 on

# The pictures. 53 images today, more as sheets are added.
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label <label>
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label <label> --sheet silhouettes --time 0.82

# The parts. Byte-identity is the gate in Stage 2.
python -m tools.parts_author && git diff --stat scripts/character/parts/

# The world, which this branch must not move.
$G --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
```

The baseline is `build/character/v2-baseline/` (53 images, shot on the GPU on
2026-08-27) plus the three tables above. Stage 0 re-shoots it as
`build/character/v2-0` and the two are compared once; from there every stage
shoots `build/character/v2-<N>` and the status doc gains a column.

The world self-test and the worldgen probe run at the end of every stage for one
reason: **this branch must not move a block.** The probe must print heightmap
hash `76cccdb6` and spawn `(-44, -124)` at every stage. A character branch that
moved the terrain has a bug somewhere it should not be able to reach.

### The measurement rule, stated once

**No stage in this plan gates on a frame time.** Not one. Every gate below is a
count: triangles, voxels, bones, parts, slots, holes, outline events, IoU, bytes,
or a hash. That is not fastidiousness - `docs/status/world-feel-v1.md` records a
retraction of a night's performance deltas because a single probe run cannot
compare two commits, and it cost this project credibility once.

The one timing number this run records is the animator's cost per character
(`0.045-0.053 ms` at v1). It is **reported, not gated**. If any stage ever needs
to compare two commits on it, the comparison is ABAB, at least five runs each,
median with spread, and run order recorded in the status doc - and the first
question to ask is whether a count would answer the same question, because it
usually will.

### Against the pillars

Checked stage by stage; the summary, because the answer is the same for most of
them:

| pillar | how this epic serves it | what would break it |
| --- | --- | --- |
| **1. Better together** | The whole point. Two to four people spend hours in each other's field of view; armour and animation are the only channel a character has when nobody is talking, and heraldry (Stage 9) is how you find your friend in a forest. | A cosmetic that only the wearer can see. Nothing here is one. |
| **2. Tense out, cozy in the light** | "Your character sitting at the campfire *is* the progress screen" is a specification, and six visible slots is the answer to it. The acceptance shot is the campfire at dusk. | Progression in a menu. Armour here has no stats and no numbers. |
| **3. The world is the content** | Armour tiers are earned by ranging further; the ladder is a distance ladder wearing armour's clothes. | A crafting tree. Explicitly not built - Items v1 owns what grants a tier. |
| **4. The world answers** | Habit 1 throughout: the slot table, the tier table, the gait multipliers, the armour fitting frame and the emissive-slot set are all **data**, in `races.gd` and beside it, which is what a director can read. Habit 3: armour reaches a character through `CharacterDef` and the announce RPC, which is the same validated path a block edit takes; nothing draws itself. | An armour system that lived in code as four per-race branches. Stage 8's normalised frame is what stops that. |

Habit 2, the journal, has no host events to add here: nothing in this plan
happens in the world. Stage 7 notes the one hook Items v1 will want
(`armour_changed`) and does not build it.

---

# Night 1 - the grid, the joint, the bodies

## Stage 0 - Measure first, correct the record, and build the gate the ladder needs

Nothing is changed before it is measured, and one thing on record is wrong.

**Re-shoot the baseline.** `--label v2-0`, every sheet, on the GPU. Compare it
against `build/character/v2-baseline/` and confirm they agree; if they do not,
something moved between 2026-08-27 and now and that is the first thing to find.

**Record the three count tables as the baseline column** in a new
`docs/status/character-v2.md`: `--sheet budget`, `--sheet masks-40`,
`--sheet masks-options`. The numbers this plan measured are in the section
above; they must reproduce.

**Correct the record, in writing.** `docs/status/character-v1.md` gains a short
box at the top of its silhouette section: every IoU number in it was measured on
llvmpipe in Compatibility, the GPU numbers differ by up to 0.14, the worst pair
is **0.913** rather than 0.868, and the three-quarter view - which that document
offered as a way out at 0.619 - is **0.759** and over target. The old numbers
stay on the page; nothing is deleted, and the box says why they are void as a
baseline. `docs/plans/character-v2.md` gains one line in its diagnosis pointing
at the box.

**`scripts/tools/character_gallery.gd` gains `--sheet outline`.** This is the
gate the entire armour ladder is defined in terms of, so it exists before
anything it will judge.

- **Measured at 3 m, and the sheet's header says so.** At 1280x720 a 2 m
  character is 313 px at 3 m and 62 px at 15 m. The tier ladder's smallest legal
  feature is 2 voxels per side, which is 6-7 px at 3 m and 1.3 px at 15 m. The
  picture is judged at 15 m (Stage 9); the count is taken where a voxel exists.
- **An outline event, defined so it can be counted.** Render the subject alone
  as a mask (the existing `_enter_mask_mode`), at 3 m, in the rest pose, at yaw
  0 and again at yaw 90. The reference `B` is **the same character with every
  armour slot empty** - the naked body, not tier 1. That matters: it is what
  makes "tier 1 has zero outline events" a *measurement* rather than a
  tautology, and a starting tunic that quietly widens a shoulder is exactly the
  thing it catches. For each row `y`, the profile width `w(y)` is
  `rightmost - leftmost + 1` of the on pixels in that row - the *outline's*
  width, not the pixel count, so a gap inside the shape is not an event. With
  `px_per_voxel` derived from the subject's known voxel height and its mask's
  pixel height:
  - a **width event** is a maximal run of rows where
    `w_M(y) - w_B(y) >= 4 voxels` (2 per side, the Kimi lane's floor) and the
    run is at least 3 rows tall (the feature floor). One event per run.
  - a **vertical event** is a run of at least 3 rows above `B`'s top edge where
    `M` is on. At most one is counted per view.
  - the **yaw-90 pass** counts the same two things in profile, which is the
    only way a cloak, a back slot and a dorsal ridge are visible at all.
  - total = front width + front vertical + profile width + profile vertical.
- Prints one line per subject per tier: `race tier N: F=<a>+<b> P=<c>+<d>
  total=<n>`, and the expected ladder beside it once Stage 9 exists.
- The masks it renders are **not** the `masks-40` masks and share no constants
  with them. `MASK_DISTANCE` and the 1280x720 viewport are untouched, because
  every IoU number this project has recorded was measured there.

**`--sheet budget` also reports the retained voxel list.** One column,
`rig.part_voxels` summed over every bone plus every socket, per character. It
costs a loop over a dictionary and it is the number item 5 turns on. Today it
should read roughly 20,000 for the dwarf; Stage 3 is where it matters.

**Files:** `scripts/tools/character_gallery.gd`, `docs/status/character-v2.md`
(new), `docs/status/character-v1.md`, `docs/plans/character-v2.md` (one line).

**Evidence:** the three count tables, three times each, recorded with the fact
that all three runs agreed to the thousandth; `--sheet outline` on the four
races with nothing worn (no armour exists yet, so `M` and `B` are the same mask
and every count must be **0**); both self-test suites; the worldgen probe.

**Verify:** `--sheet outline` reports 0 events for all four races - a metric
that finds an event where there is no armour is measuring noise, and that is the
first thing to fix. `--sheet budget` and `--sheet masks-40` reproduce the
numbers above exactly. Heightmap hash `76cccdb6`, spawn `(-44, -124)`.

## Stage 1 - The liner slot and nineteen palette entries, before any geometry moves

**Why this design.** The single highest-value decision in the design doc is
structural, not chromatic: the reason four races arrived at the same black shirt
is that look v2 made *cloth* carry the separation from *skin*, and each race's
five skins span most of the luminance range, so the only value that cleared all
five sat below the darkest. The constraint had one solution and it was black.
Put a fixed near-black liner at every skin/cloth boundary and the pair that must
hold becomes skin-to-liner, which holds by construction at 6.1:1 in the worst
case against the 2.1:1 the old rule scraped - and the cloth is then free to be
any colour at all. This is how comic inking works.

The liner is a *shape*, so nothing looks different at the end of this stage and
that is correct: the liner voxels arrive with the re-authored parts in Stage 5.
What lands here is the vocabulary those parts will be authored in, and it lands
first because a generator cannot paint a slot the runtime has never heard of.

- **`VoxelModel`: 13 slots to 19.** The enum, `SLOT_COUNT`, `SLOT_CHARS` and
  `SLOT_NAMES` move together or the palette is silently off by one everywhere.
  The six new ones, with letters chosen on the file's existing convention that
  a lowercase letter is the darker sibling of its uppercase:

  | slot | char | what it is |
  | --- | --- | --- |
  | `LINER` | `k` | ink. Fixed `#14100C` for every race and every palette, never a player pick |
  | `SKIN_VENTRAL` | `v` | the countershaded belly, throat and underside of a tail |
  | `TRIM_BRIGHT` | `R` | the raised rim that is the whole difference between steel and steel that cost something |
  | `METAL_DARK` | `x` | the dark body a bright rim sits against |
  | `SCALE_A` | `A` | the checker's first value |
  | `SCALE_B` | `a` | the checker's second, one step apart, never more |

  `GLOW` is the twentieth and arrives in Stage 10 with the thing that needs it.

- **The ceiling on `SLOT_CHARS`, since the design doc asks.** `parse()` reads
  one character per voxel out of a GDScript string, so the hard ceiling is the
  printable ASCII set minus `.` and space (both mean empty) and minus `"` and
  `\` (which would have to be escaped in the source): **91**. That is not the
  real limit. The real limit is the legend a person can hold in their head while
  reading a slice, and the upper/lower convention above roughly doubles it by
  making half the letters derivable. Say **about 24** in the docstring, and say
  that past it the format wants two characters per voxel and a different file.

- **`Races`: the palette becomes tiers.** `TUNIC_HEX` and the look v2 darkening
  rule are retired - the old hexes stay in the file as a comment with the date
  and the reason, because a value someone chose for a stated reason is worth
  more on the page than in the history. Each race gets the design doc's five
  bands as named constants (`DEEP_HEX`, `MID_HEX`, `LIGHT_HEX`, `ACCENT_HEX`)
  and the liner is one shared constant. `palette()` gains the six entries.

- **`tools/parts_author/voxlib.py`: `SLOTS` gains the six letters** and the
  module-level aliases beside them. This set and `VoxelModel.SLOT_CHARS` are two
  copies of one fact in two languages and there is no test that they agree -
  which is exactly the sort of thing that costs an evening. `__main__.py` gains a
  ten-line check that regexes the `SLOT_CHARS` block out of
  `scripts/character/voxel_model.gd` and refuses to write a single file if the
  two disagree, naming both sets.

- **`assets/characters/README.md`: the legend goes from thirteen indices to
  nineteen.** The directory ships empty, so this costs nothing today and would
  cost re-indexing every model the day after the first `.vox` lands. Do it now.

- **`scripts/tools/character_gallery.gd` gains `--sheet palette-tiers`**: for
  each race, its five value bands and its skins as flat swatches through
  `Look.opaque_material()`, measured with the look v2 swatch machinery that is
  already in the file (`_report_swatches`, tolerance 6 units per sRGB channel),
  plus a printed luminance table with each band's measured Y and its target
  band. This is what gives a data-only stage a rendered gate on the day it
  lands, rather than four stages later.

**Files:** `scripts/character/voxel_model.gd`, `scripts/character/races.gd`,
`tools/parts_author/voxlib.py`, `tools/parts_author/__main__.py`,
`assets/characters/README.md`, `scripts/tools/character_gallery.gd`,
`scripts/tools/selftest_character.gd`.

**Evidence:** `--sheet palette-tiers`; the luminance table; both self-test
suites - `_test_every_combination` already asserts `palette().size() ==
SLOT_COUNT` and that every slot resolves to a colour, so a slot added without a
palette entry fails a test that exists.

**Verify:** every race's palette spans at least three of the five bands and
lands inside them; **skin-to-liner luminance ratio is at least 6:1 for every one
of the twenty skins in the game**, against the 2.1:1 the old rule scraped. The
worst case is the darkest human skin at about 6.0:1, which means the gate pins
the **darkest skin** rather than the liner: if a re-authored skin drops under, it
is the skin that moves, and the liner hex is not negotiable. Every swatch within
6 units per channel of its authored value; no two races' mid band within 0.03 of
Y of each other (the design doc's palettes clear this with 0.047 to spare at the
tightest, human against elf). No
part file changed, no triangle count moved, no image other than the new sheet
differs from `v2-0`.

## Stage 2 - The generators take the grid as a parameter, and prove it by changing nothing

**Why this design.** `tools/parts_author/` is 1,887 lines of Python that emits
every voxel in `scripts/character/parts/`. Nothing is drawn by hand, which means
the resolution is a number in a generator rather than four thousand lines of
handiwork - and that is the single fact that makes the 96-vs-128 decision
reversible instead of one-way. It is worth a stage of its own and it comes
before the move, not after it.

**Was this done by the parallel lane?** Checked at 2026-08-28 14:19 UTC and the
answer is no: `/home/kimi/work` holds `character-research-kimi.md` (Aug 27
20:18) and a fizzbuzz, there is no clone of this repository anywhere under
`/home/kimi`, and the session running under that account is the research brief.
**How to tell, if you are running this later:**

```bash
sg agents -c 'ls -la /home/kimi/work/'
sg agents -c 'test -f /home/kimi/work/*/tools/parts_author/voxlib.py && echo LANDED || echo ABSENT'
```

If a clone exists and its `voxlib.py` has a resolution constant: read its diff,
run *this stage's* gate against it (byte-identity at 64), and take it if it
passes - it is the same work and a second implementation that passes the same
gate is a better one than a first that has not been checked. If the gate fails
or the clone is absent, do the work here. **Do not wait for it.**

The mechanism, and the reason it is safe:

- **`voxlib.RES`**, model voxels per 2.00 m human, default 64, settable by
  `python -m tools.parts_author --res 96`.
- **The generators stop restating the race table.** `human.py` has
  `HEAD_SIZE = (18, 22, 17)`, which is `races.gd`'s `head_w`, `head` and
  `head_d + 1` written a second time in a second language. Every such dimension
  becomes a lookup into `voxlib.RACES`, a Python mirror of `Races.TABLE`.
- **Everything the race table does not name is a detail dimension**, and those
  are wrapped: `u(n)` is `round(n * RES / 64)`, with `u_odd(n)` and `u_even(n)`
  for the ones whose parity is load-bearing - a mouth centred on an odd-width
  face, an eye gap that must stay symmetric. Wrapping is mechanical and it can
  be reviewed line by line.
- **Nothing is re-expressed as a fraction of race height.** That would be a
  rewrite of intent and could not be gated. Wrapping can.

**The gate is byte-identity.** At `RES = 64` with today's race table,
`python -m tools.parts_author` must produce **zero diff** in
`scripts/character/parts/`. That single check proves the whole refactor did not
change a voxel, and it is the reason this stage is safe to do in one sitting.

**One new self-test, and it is the guard that outlives this stage.**
`_test_parts_match_table`: for every race, the built head part's size equals
`(head_w, head, head_d + nose)`, the torso's equals `(torso_w, torso, torso_d)`,
the leg's height equals `legs`, the arm's equals `arm_len`. It catches drift
from *either* side of the two-language boundary without either language having
to parse the other.

**Honest note on the value of this stage.** Marcel has approved rebuilding all
four races from scratch, so the parameterisation does not save the re-authoring
labour it would have saved under a "port what exists" constraint. Its value is
two other things: the escape hatch to 128 or back to 80 costs one flag rather
than a week, and `voxlib` acquires the vocabulary - dimensions from the race
table, details in `u()` - that Stages 5 and 6 will author the new bodies in. It
is not throwaway work; it is the language the new work is written in.

**Files:** `tools/parts_author/voxlib.py`, `human.py`, `elf.py`, `dwarf.py`,
`lizardfolk.py`, `hair.py`, `gear.py`, `critter.py`, `__main__.py`;
`scripts/tools/selftest_character.gd`.

**Evidence:** `python -m tools.parts_author && git diff --stat
scripts/character/parts/` - empty; `--res 96` runs to completion and writes
seven files (thrown away, not committed); both self-test suites; `--sheet
budget` and `--sheet masks-40` unchanged from Stage 1.

**Verify:** the diff is empty. Every count in every table is identical to
Stage 1's. A single changed voxel here is a bug in the wrapping, and it is far
cheaper to find now than after the grid has moved.

## Stage 3 - The grid moves to 96, and one model voxel becomes 1/24 of a block

**Why this design.** 96 is the last grid whose atomic unit is still at least one
pixel at 15 m, which is the far edge of the band this game is played in - 0.98 px
at 1080p, against 128's 0.73 px, which is below the sampling limit and aliases
rather than renders. The reason to raise at all is not surface detail: it is
that a 16-voxel leg cannot have a knee, and a 24-voxel leg can. Everything else
is a bonus, including that 96 divides by three and 64 does not, which removes a
rounding error from every generator. The design doc's arithmetic and an
independent lane that never saw this repository both arrive at the same number.

**This stage moves the grid and nothing else.** Every dimension is multiplied by
1.5 and rounded; no race's design changes here. That is deliberate: it isolates
"the grid moved" from "the shape changed", and if a silhouette number moves in
this stage it is a bug rather than a decision. Three of the four races' shoulder
ratios land exactly on the design doc's targets under a plain 1.5x, because
those ratios were never what was wrong.

- **`VoxelModel.VOXEL_M`: `0.03125` to `0.0208333...`** - write it as
  `2.0 / 96.0`, not as a decimal, so the reason is in the expression. One model
  voxel becomes 2.083 cm, 1/24 of a 0.5 m block.
- **`Races.TABLE`, mechanically rescaled.** `pelvis` is *derived*
  (`total - legs - torso - head - neck`), so the totals are exact by
  construction and the pelvis absorbs the rounding:

  | | total | legs | torso | head | neck | pelvis (derived) | torso_w | torso_d | head_w | head_d | leg_w | arm_len | arm_w |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | human | 96 | 24 | 30 | 33 | - | 9 | 30 | 17 | 27 | 24 | 12 | 30 | 12 |
  | elf | 108 | 36 | 30 | 33 | 5 | 4 | 18 | 12 | 24 | 24 | 9 | 36 | 9 |
  | dwarf | 72 | 15 | 27 | 30 | - | 0 | 39 | 21 | 30 | 24 | 15 | 24 | 15 |
  | lizardfolk | 90 | 27 | 30 | 27 | - | 6 | 30 | 17 | 24 | 24 | 12 | 30 | 12 |

  **Every height in metres is unchanged**: 2.00, 2.25, 1.50, 1.875. So the
  capsule, the camera pivot, `MAX_STEP`, the speed table and `player.gd` are not
  touched, and hard rule 10 from world feel v1 still holds - `player.gd` reads no
  number from `Races`.

  **The design doc's human stack is two voxels short.** It writes "total 96,
  legs 24, pelvis 8, torso 30, head 32", which sums to 94. Since `pelvis` is
  derived rather than tabled the code cannot reproduce that error, and the
  question is only which of the other three numbers absorbs it. Stage 5 answers
  it as a design question; Stage 3 uses the mechanical 1.5x above and records the
  discrepancy in the status doc. This is the same class of slip character v1
  found in its own plan's table, and it is the reason the height self-test
  measures the built rig rather than summing the table.

- **`CharacterConfig`: the `_vox` knobs mean something different now.** Six of
  them are in model voxels precisely so a number means the same thing on a dwarf
  and an elf - and that makes every one of them 2/3 of its old size in metres the
  moment the voxel shrinks. Multiply the defaults by 1.5: `bob_walk_vox` 3.0 to
  4.5, `bob_sprint_vox` 6.0 to 9.0, `land_squash_vox` 2 to 3, `sit_lift_vox` 1.5
  to 2.25, `downed_lift_vox` 2.5 to 3.75, `breath_vox` 0.5 to 0.75. Then bump
  `USER_PATH` to `user://character_tuning_v3.tres`, exactly as look v1 bumped it
  to `_v2` for exactly this reason, so a saved tuning file from the old grid is
  simply not read rather than silently applied at two thirds.
- **`Animator.REFERENCE_LEG_M := 16.0 * VoxelModel.VOXEL_M` becomes `24.0 *`**.
  Same 0.5 m, different literal; miss it and every race's stride scales from a
  reference two thirds of the right size. While there: `_pose_locomotion`'s
  `dims.get("legs", 9)` default is a fossil from the 1/8 era and should be a
  loud failure rather than a wrong number.
- **`TRIANGLE_BUDGET` is re-measured, not predicted.** The design doc's estimate
  is 2.25x, which would be about 40,000. **Do not write 40,000.** Run
  `--sheet budget`, take the worst mesh count, round up to the next 4,000, put
  that number in the constant with the measured value and the date in the
  comment beside it. The v1 comment does exactly this and it is why the number
  can be re-argued.
- **All seven part files regenerated** at `--res 96`, including
  `parts_critter.gd`: the critter's `DIMS` are in voxels, so without this it
  arrives at two thirds of its size and the first-enemy plan starts from a
  shrunken animal.
- **The `.vox` drop-in rule breaks, and it is documented rather than defended.**
  A `.vox` authored against the 64-voxel grid loads at 2/3 scale after this
  stage. `assets/characters/` ships empty, so the cost of the break is exactly
  zero today and would be a re-export of every model on any later day. Do not
  invent a sidecar file to declare a scale - MagicaVoxel carries no such
  metadata and a format nobody has ever written a file for is not worth
  designing. What *is* worth ten lines: `VoxLoader.drop_in()` compares the
  replacement's size against the ASCII part it replaces and warns when the ratio
  is outside `[0.75, 1.33]`, naming the likely cause ("authored at the old
  grid?"). That catches the real failure, which is silent.
- **`docs/DESIGN.md` "Art pipeline"**: the "1/16 of a block, 3.125 cm, a human
  is 64 voxels" paragraph and the four-race height table are amended here, not in
  Stage 13, because they are statements of fact that stopped being true in this
  commit. The *design* change in that file - three gear slots becoming six - is a
  decision and waits for Stage 13.

**Files:** `scripts/character/voxel_model.gd`, `races.gd`, `character_config.gd`,
`animator.gd`, `vox_loader.gd`, all seven `scripts/character/parts/*.gd`
(regenerated), `tools/parts_author/voxlib.py` (default `RES`),
`assets/characters/README.md`, `docs/DESIGN.md`.

**Evidence:** `--sheet budget` with the new retained-voxel column;
`--sheet masks-40`; `--sheet masks-options`; `--sheet outline` (still 0);
`--label v2-3`, every sheet; both self-test suites; the worldgen probe.

**Verify:**
1. Every race's measured height in metres is unchanged to within one voxel -
   this is the existing height self-test and it is the one that matters most.
2. Triangles land between 1.9x and 2.6x their Stage 2 values. Outside that band,
   something other than the grid moved and it is found before the stage closes.
3. `masks-40` moves by **less than 0.05 on every pair**, and human/lizardfolk is
   still the worst and still over. The grid does not fix a silhouette and must
   not appear to.
4. The retained voxel list is recorded per race. Expect roughly 3.4x Stage 2 -
   about 68,000 voxels and 1.6 MB for the dwarf. **Then leave it alone.** The
   fallback, specified and not built: pack `(x, y, z, slot)` into one `int32`
   (8+8+8+5 bits fits) in a `PackedInt32Array`, which is 4 bytes per voxel
   against a Variant's 24 and needs no API change beyond the two loops in
   `voxel_centres_in_rig()`. Build it only if a party of four measures over
   8 MB, and record the measurement either way.
5. Heightmap hash `76cccdb6`, spawn `(-44, -124)`.

## Stage 4 - The knee and the elbow, added rather than substituted

**Why this design.** A rigid single-segment limb has exactly one expressive
degree of freedom, its angle, and every technique that makes a walk read as
weight rather than as machinery needs a second: the knee bending through swing,
the foot rolling heel to toe, the contact pose where the front leg is straight
and the back leg is bent, the compression on landing. None of them can be faked
by animating the one angle harder. This is the deepest of the three failures and
it is the reason the grid moved.

**The naming decision is the whole stage.** See disagreement 1: `leg_r` keeps
its name and gains a child. `Rig.apply_pose()`'s contract - a pose that says
nothing about a bone leaves it at rest - means the four static poses, the
critter, the trot and every self-test that names a bone keep working on the day
the bones land, and get refined afterwards because someone chose to.

- **`Races.bone_table()` gains four entries**, and the lizardfolk gains a fifth
  in Stage 6:

  | bone | parent | rest offset | part |
  | --- | --- | --- | --- |
  | `leg_r_lower` | `leg_r` | `(0, -thigh, 0) * V` | `leg_lower` |
  | `leg_l_lower` | `leg_l` | `(0, -thigh, 0) * V` | `leg_lower`, mirrored |
  | `arm_r_lower` | `arm_r` | `(0, -upper_arm, 0) * V` | `arm_lower` |
  | `arm_l_lower` | `arm_l` | `(0, -upper_arm, 0) * V` | `arm_lower`, mirrored |

  `thigh = legs / 2` and `upper_arm = arm_len / 2`, both from the table.
  `arm_len` is even for all four races at 96, so every arm splits cleanly; the
  **dwarf's `legs` is 15** after Stage 3's rescale, so its split is 7 and 8 -
  the thigh takes the floor and the shin the remainder, which is a one-voxel
  asymmetry inside a 15-voxel leg and is invisible. Stage 5 moves the dwarf to
  the design doc's 16 as part of its redesign, and the rule holds either way
  rather than depending on the number being even. The part keys `leg` and `arm`
  become `leg_upper` and `leg_lower`, `arm_upper` and `arm_lower` - the asset
  contract renamed while it has no consumers, per disagreement 1.

- **`hand_r` and `hand_l` reparent** from `arm_r`/`arm_l` to
  `arm_r_lower`/`arm_l_lower`, with rest `(0, -forearm, 0) * V`. This moves
  every placeholder in the game; the existing gear overlap self-test is what
  catches a sword that now ends up inside a dwarf.

- **The joint is an inset, never a gap.** The upper part's last slice and the
  lower part's first are inset by one voxel all round, so the limb has a 2-voxel
  band of narrower cross-section at the joint. An actual gap shows daylight
  through a leg the moment it bends, which is worse than no knee at all. In the
  re-authored parts (Stage 5) that band is the `LINER` slot, which is the same
  trick as the human's rolled sleeve: the joint is legible because it is inked.

- **`Animator.RIG_SHAPES` gains an optional `lower` key per limb entry.**
  Absent means no knee, which is the correct description of the critter's trot
  and of any future rig that has none. `_pose_locomotion` writes the lower bone
  only when the key is there.

- **The knee bends one way.** A knee that hyperextends is the single most
  obviously wrong thing a procedural rig can do. The angle is a **rectified**
  sine, quarter-cycle behind the hip:
  `knee = -knee_swing * max(0, sin(TAU * (phase + p + 0.25)))`, with the sign
  chosen so the shin swings *backward*. The elbow is the same expression with
  its own amplitude and the opposite sign, because an elbow bends forward.
  Two new `CharacterConfig` knobs and two rows in `TUNING_ROWS`:
  `knee_swing_deg := 45`, `elbow_swing_deg := 25`. Starting values.

- **Four static poses refined**, deliberately, now that they can be:
  `_pose_sit` gets knees at 90 degrees, which is what sitting is, instead of legs
  straight out in front - and that fixes the thing the v1 status doc records
  about a sitting character photographed from the front looking like a standing
  one with short legs. `_pose_downed` gets a curl. `_apply_wave` gets an elbow.
  The jump tuck gets a knee, which is most of what makes a tuck read as a tuck.

**Files:** `scripts/character/races.gd`, `animator.gd`, `character_config.gd`,
`scripts/ui/character_debug.gd` (nothing - `TUNING_ROWS` is a table and the panel
reads it), `tools/parts_author/*.py` (the leg and arm generators split),
`scripts/character/parts/*.gd` (regenerated),
`scripts/tools/selftest_character.gd`.

**Evidence:** `--label v2-4`, every sheet, and specifically
`anim-*-walk.png` for all four races side by side with `v2-3`'s; `--sheet
budget`; both self-test suites; two new tests.

**Verify:**
1. **`_test_knee_never_hyperextends`**: 360 phase samples x every race x
   {walk, sprint, jump, fall, land, sit, downed, wave}, asserting the sign of
   every `*_lower` bone's `rot.x` never crosses zero the wrong way. Zero
   violations. This is a count and it is the gate.
2. `_test_rig_completeness` passes with no edit - it is driven off
   `Races.bone_table()` and `parts_for()`, so four new bones with four new parts
   are checked automatically. If it needs an edit, the bone table and the part
   set have drifted and that is the finding.
3. The gear overlap test passes on all four races with the hand sockets moved.
4. Heights unchanged to within one voxel.
5. `masks-40` moves by less than 0.02 - a knee in the rest pose is invisible to
   a front-on silhouette and must stay that way.

## Stage 5 - The human, the elf and the dwarf, re-authored

**Why this design.** Fill any of the four with black today and you get a
rectangle on two rectangles. The elf's ears and the lizardfolk's crest are the
entire outline budget for the whole cast; there is no pauldron, no cloak, no
belt past the hip, no strap and no asymmetry anywhere. The organising principle
is one big idea each, and **no two races may express their idea on the same
axis** - the human owns diagonal, the elf owns vertical, the dwarf owns
horizontal mass, the lizardfolk owns the low line. Two races competing on one
axis is exactly how the human/lizardfolk pair happened.

This is the largest and least predictable stage in the plan. It is three bodies,
and every one of them is a judgement made against a picture. Budget accordingly;
the wrap rule at the end of this document applies to it first.

- **Human - the diagonal.** A baldric from the left shoulder to the right hip; a
  belt that hangs past the hip on one side; a hood that lives *down*, bunched at
  the back of the neck as a lump raising the shoulder line by 3 voxels; rolled
  sleeves, so the forearm is skin and the upper arm is cloth - which puts a
  `LINER` ring at the elbow exactly where the new joint is and makes the joint
  legible for free. Cool neutral cloth, warm leather, one ochre accent on the
  strap and the belt: the human is the only race whose accent is on a *worn
  object*, which is its design idea restated as a palette. Head 32, torso 30,
  legs 24, pelvis 10 - the design doc's numbers, with the two-voxel slip from
  Stage 3 resolved into the pelvis.
- **Elf - the column.** A high standing collar raising the shoulder line by 4
  voxels, so the head emerges from a shaft rather than sitting on a pair of
  shoulders. **The collar and not the ears is the identity**, because the ears do
  not survive a helmet and the collar is torso, is under the helm, and is always
  there. Ears stay, swept back and up in the collar's plane so the two read as
  one vertical fin at 15 m. Hair becomes a narrow column down the spine, never
  the side-of-head slab in the build now, which widens the one race whose whole
  idea is narrowness. Sleeves and trousers taper 8 to 5, which is only possible
  at 96. Desaturated cool, bone light tier, cold violet accent, and **never
  green**.
- **Dwarf - the mass.** Two stacked trapezoids with the head recessed *between*
  the shoulders rather than above them: a head that pokes above reads as a
  person, a head set between them reads as mass, and that is the whole trick.
  The beard is the lower trapezoid and is load-bearing on the silhouette, not
  decoration. Boots so heavy the ankle disappears; a tool on the belt, always,
  on the same side. The dwarf owns saturation - the only race with a fully
  saturated primary at tier 1 and the only one wearing metal before tier 3.
  **The beard must never share a value tier with the tunic**; it is the
  second-highest-contrast element on the character after the eyes and today it
  is a mid-red on a near-black shirt, which is one smudge. Two tiers apart,
  always, and it is a check the palette sheet can make.
- **Everywhere: hands and boots up 15%**, per the design doc's exaggeration at
  the extremities. It costs nothing and it is what stops "stocky" reading as
  "doll".
- **Nothing smaller than 3x3 voxels is authored.** The Kimi lane's floor, and it
  sharpens what the raise was for: at 96 the win is *bigger* features, not finer
  ones. Authoring 1-voxel detail at the new grid wastes the raise.
- **No hand-painted face shading.** `voxel_model.gd` bakes corner AO into vertex
  colour with `ChunkMesher`'s rule; a second, authored shading on top
  double-darkens every concave corner and produces mud. A material is one base
  value plus a hue and a saturation; form comes from the AO; contrast comes from
  putting two materials next to each other. This is the clearest case in the
  whole exercise of research that never saw the codebase giving advice that would
  make the build worse.

**Files:** `tools/parts_author/human.py`, `elf.py`, `dwarf.py`, `hair.py`;
`scripts/character/races.gd` (the three stacks and the three palettes);
`scripts/character/parts/parts_human.gd`, `parts_elf.gd`, `parts_dwarf.gd`,
`parts_hair.gd` (regenerated).

**Evidence:** `--label v2-5`, every sheet; `closeup-*`, `silhouettes-15`,
`silhouettes-40`, `study-*` read against `v2-3`'s; `--sheet masks-40`;
`--sheet masks-options`; `--sheet palette-tiers`; `--sheet budget`; both
self-test suites.

**Verify:**
1. **human/elf and human/dwarf and elf/dwarf all under 0.70 front-on**, which
   they already are - this stage must not make any of them worse than Stage 3.
2. Every race spans three value bands, and no two races share a mid band -
   the `palette-tiers` gate from Stage 1, now with geometry behind it.
3. The dwarf's beard and its tunic are at least two bands apart.
4. Heights exact. Triangles under the Stage 3 budget, or the budget moves once,
   with the measurement.
5. The picture: in `silhouettes-15.png` at dusk, each of the three has at least
   one element still visible when the rest has gone to silhouette. That is what
   the light tier is *for* and the elf's white hair is currently doing it by
   accident.

## Stage 6 - The lizardfolk gets a body

**Why this design.** It is currently a human with a tail and a snout, and the
metric has been saying so for three passes: **0.913 front-on on the GPU, and
0.759 even three-quarter**, which is the view the v1 status doc offered as the
way out. The status doc's other two options both amount to changing the test,
and the thing that is wrong is the model. Marcel settled this on 2026-08-27 and
also removed the constraint that would otherwise have shaped every stage of this
plan: **the re-authoring cost is accepted for all four races**, and where a race
reads better rebuilt than ported it gets rebuilt.

**The one big idea: it is the only race whose centre of mass is not over its
feet.** Digitigrade legs with a real backward-facing hock, a torso carried
forward and low, and a tail that arcs down and back as a counterweight rather
than sticking out sideways like a plank, which is what it does today. The
silhouette rule is the horizontal S: head low and forward, spine sloping up from
neck to hips, tail sloping down and back, and through the middle of the body it
should be the only race in the game wider than it is tall.

- **A third leg segment.** `leg_r_foot` / `leg_l_foot`, children of
  `leg_*_lower`, carrying the long digitigrade foot. This is the expensive one
  and it is where the resolution raise pays for itself: 30 voxels over three
  segments is 10 each, and at the old grid it would have been 5. `RIG_SHAPES`
  gains an optional `foot` key beside `lower`, on the same "absent means it does
  not exist" rule, and the ankle angle is a third rectified sine another quarter
  cycle behind the knee.
- **The stack, from the design doc**: total 90, legs 30 over three segments,
  pelvis 6, torso 30, head 24. `torso_w` drops from 30 to **22**, which is the
  numeric statement of the fix: shoulder over height goes from 0.333 to 0.24,
  putting it in the gap between the elf's 0.17 and the human's 0.31 instead of
  on top of the human.
- **Forward lean 18 degrees**, up from 8, carried in the hips rest pose exactly
  as today - so it survives every pose and the animator never learns that one
  race stands differently. Note that `Rig.height_m()` is an axis-aligned bound
  of the leaning body, so a bigger lean means the measured height drifts further
  below the tabled one; v1 measured 1.93 against a tabled 1.88 at 8 degrees. The
  height test's one-voxel tolerance may need to become a stated per-race
  allowance for this race, and if it does, the allowance is written down with
  the lean that caused it rather than the tolerance being widened for everyone.
- **The tail becomes four links over 42 voxels**, arcing down and back.
  `MAX_CHAIN_LINKS` is already 4 and `CHAIN_NAMES` is already a table, so the
  animator needs no change at all - the segment lengths are tabled and each
  bone's rest offset is the previous segment's length, which is how the chain
  stays continuous by construction.
- **A short broad snout, not a long one.** A long snout at 15 m is a smudge; a
  blunt head with a heavy brow ridge and a jaw wider than the skull reads as
  reptile at any distance. A dorsal ridge from the base of the skull to the tail,
  which is the profile feature that survives every helmet. The crest stays.
- **Not green**, and the cheapest thing in the entire design doc:
  **countershading**. Dark dorsal, light ventral - `SKIN_VENTRAL` on the belly,
  the throat and the underside of the tail. It costs zero extra voxels because it
  is a palette split of a slot that already exists, and it is the strongest
  single signal that a thing is an animal rather than a person in a costume.

**Files:** `tools/parts_author/lizardfolk.py`, `hair.py` (the crest);
`scripts/character/races.gd` (the stack, the third segment in the bone table,
the palette); `scripts/character/animator.gd` (the `foot` key);
`scripts/character/parts/parts_lizardfolk.gd`, `parts_hair.gd` (regenerated);
`scripts/tools/selftest_character.gd`.

**Evidence:** `--label v2-6`, every sheet; `--sheet masks-40`;
`--sheet masks-options`; `--sheet budget`; both self-test suites; the worldgen
probe.

**Verify:**
1. **Every cross-race pair under 0.70 front-on**, human/lizardfolk included.
   This is the number the whole epic is judged on and it starts at 0.913.
2. **Across every hair, beard and crest option**, `--sheet masks-options`
   reports **zero pairs over 0.70**. It reports 15 today, all of them this pair.
3. The three-quarter table is reported and must also be under 0.70 on every
   pair, since the GPU says it is 0.759 today. Reported, and if it is the only
   one still over, that is a recorded finding for Marcel rather than a reason to
   keep cutting.
4. `_test_knee_never_hyperextends` extended to the third segment: the ankle
   never bends forward. Zero violations.
5. Heights within the stated per-race allowance; the walk strip shows the hock
   bending backward, which is the one thing a digitigrade leg has to do.

**Night 1 ends here.** The build is playable: four races, four bodies, two-segment
limbs, a palette that has a liner in it, and no armour. Commit, run both suites,
write the status doc's night 1 half, and stop.

---

# Night 2 - armour, animation, and the record

Starts from night 1's last commit, never from `main`. Every armour piece is
fitted to a body night 1 rebuilt.

## Stage 7 - `CharacterDef` version 2, and the version-1 payload that must still parse

**Why this design.** Everything visible about a player travels in eight bytes,
and the file that owns them is explicit about why it never throws: *"A character
that fails to appear is a bug; a game that crashes because a friend's beard index
was 7 is a disaster, and the difference between those two outcomes is entirely in
this file."* Six armour slots with an item and a tier do not fit in eight bytes,
and the bump has to keep that promise for payloads written before it.

- **`WIRE_VERSION 2`, `WIRE_BYTES 20`.** Bytes 0-7 are byte-for-byte v1; 8-13
  are the item id per slot in the order `torso, shoulders, back, head, legs,
  hands`; 14-19 are the tier per slot, 0-5. One byte per field, not packed: the
  appearance rides its own reliable RPC once per join, not the twenty-times-a-
  second state table, so twelve bytes buys nothing and costs the file its
  one-byte-per-field readability.
- **`from_bytes()` dispatches on `data[0]`, not on length.** A table
  `WIRE_LENGTHS := {1: 8, 2: 20}`; an unknown version or a length that does not
  match its version still returns the default human with a warning naming what
  was wrong, exactly as today. **A version-1 payload parses into a valid
  character with every armour slot at item 0 and tier 0** - not into the default
  human, which would silently change a friend's race.
- **The compatibility is one-way and that is correct.** An old build receiving 20
  bytes sees version 2, does not recognise it, and falls back to the default
  human with a warning. That is the behaviour already written and it fails safe;
  say so in the docstring rather than pretending the wire is symmetric.
- **`validate()` clamps armour**: tier to `0..TIER_MAX`, item id to the count of
  pieces authored for that slot (a table, from Stage 8). Never throws, never
  rejects, per the file's rule.
- **`to_dict()` and `from_dict()` do not carry armour.** See disagreement 3:
  those two are the save file, `user://character.tres` is the player's chosen
  *appearance*, and `DESIGN.md` puts gear in the host's world save. A player who
  changes worlds must not arrive wearing the last world's plate.
- **`randomise_from()` does not draw armour either.** `--look 7` is an
  appearance, and a deterministic random *character* that arrives in tier 4
  plate would quietly change what every headless comparison run is looking at.
  The gallery's armour sheets set tiers explicitly.
- **One line of comment naming the journal hook and not building it**: Items v1
  will want a host `armour_changed` event. Habit 2 says the journal costs nothing
  today; it also says nothing here happens in the world, so there is nothing to
  log yet.

**Files:** `scripts/character/character_def.gd`, `scripts/tools/selftest_character.gd`.

**Evidence:** both self-test suites; a two-peer run
(`--host --race dwarf` against `--join 127.0.0.1 --race elf`, headless,
`--quit-after 3000`) with zero script errors on either side, as character v1 ran
it; `--sheet budget` unchanged.

**Verify:**
1. **`_test_v1_payload_still_parses`**: the literal eight-byte array
   `[1, 2, 0, 3, 1, 2, 1, 2]` comes back as a stocky dwarf with those five
   indices and six tiers of 0. Not the default human.
2. `_test_def_from_strangers` extended: 100 random 20-byte payloads, 100 random
   8-byte payloads, and the four malformed shapes - every one produces a
   buildable character and none produces an error.
3. `_test_def_round_trip` extended: a def with armour set, through
   `to_bytes`/`from_bytes`, is identical; through `to_dict`/`from_dict`, comes
   back with armour cleared. Both assertions, because the second is the design
   decision and an accidental "improvement" would undo it silently.
4. The two peers see each other's race and name, as they do today.

## Stage 8 - The normalised slot frame, and four armour slots

**Why this design.** One armour idea has to be worn by a 39-voxel-wide dwarf, an
18-voxel-wide elf and a forward-leaning lizardfolk with a tail. Per-race
remodelling is four times the authoring for four races; a single scaled mesh puts
a dwarf breastplate on an elf and it looks like a barrel. **The rule is that
proportions are relative and thicknesses are absolute**: a piece is authored once
in a normalised frame - 0..1 across the attachment's width, height and depth -
and stamped into the race's actual dimensions by the generator, but its plate is
3 voxels thick on every race, because 3 voxels is what plate looks like. Get it
backwards and dwarf armour looks like foam rubber while elf armour looks like it
was cut from sheet tin. This is the single rule that makes one authored set work
across four bodies, and it is the distinction `parts_gear.gd` already learned the
hard way with the placeholder sword.

- **`scripts/character/armour.gd`** (new), and it is a table, not behaviour -
  habit 1. The six slots with the bone or socket each attaches to, the five
  tiers, and for each piece its slot, its tier, its material, its expected
  outline-event contribution, and its per-race exceptions. A director, or Items
  v1, can read all of it.

  | slot | attaches to | why there |
  | --- | --- | --- |
  | torso | `torso` bone, as an overlay | the largest surface, ~38% of the silhouette |
  | shoulders | `arm_r` / `arm_l`, as overlays | so a pauldron swings with the arm, which is what a pauldron does |
  | back | the existing `back` socket | a cloak is a carried thing hanging off the torso, and the socket is already there and already proven |
  | head | `head` bone, as an overlay | second-most-looked-at, and the slot that fights race identity hardest |
  | legs | declared, no pieces | lowest return: a greave at 15 m is nine pixels behind a tuft of grass |
  | hands | declared, `hand_r` / `hand_l` | the sockets exist from character v1 Stage 10; Items v1 fills them |

  **Four ship. Two are declared with no geometry**, so Items v1 never has to
  touch the wire format to add them.

- **`Rig.attach_overlay(bone_name, part, ...)`**, beside `attach_to_socket()`.
  An overlay is a second `MeshInstance3D` on an existing bone, so it moves with
  that bone exactly and needs no new transform. Sockets stay what they are - a
  point to hang a carried object from - and the difference is written down,
  because "why is the pauldron a bone overlay and the cloak a socket
  attachment" is a question someone will ask in six months.
- **`tools/parts_author/armour.py`** (new) emits
  `scripts/character/parts/parts_armour.gd`. It reads the same `voxlib.RACES`
  table as the bodies, so a piece authored at 0.0-1.0 across the shoulder is
  stamped into a dwarf's 39 voxels and an elf's 18 by the same three lines.
- **The head slot needs a rule, because it is where race identity goes to die.**
  A full helm erases the elf's ears, the dwarf's beard line and the lizardfolk's
  snout in one item. Every head item is authored per-race in the same way its
  wearer's head is, and each must leave its race's identity feature intact or
  replace it in kind: the elf's helm is open at the sides or the ears pass
  through it; the dwarf's has the beard emerging below and gets *horns*, because
  the dwarf is the only race whose silhouette can afford width above the
  shoulders; the lizardfolk's sits behind the brow ridge and never covers the
  snout; the human's can be anything, because the human's identity is on its
  chest.
- **The lizardfolk's two named exceptions**, and only two: leg armour does not
  fit a digitigrade leg, and a back piece has to route around a dorsal ridge and
  a tail. Both are per-race variants of two pieces, not a per-race system. The
  Kimi lane's "every armour piece needs at least one race-specific variant" is
  not taken: it is right that a literal one-size piece will clip, and wrong that
  the answer is variants everywhere.
- **`CharacterView.set_armour(def)`**, called from `build()`, so the local
  player, the friend across the network and the creation screen's turntable can
  never disagree about what a dwarf in plate looks like - the same reason
  `CharacterView` exists at all. `set_gear_placeholders()` and its `T` key stay
  as they are; they are proving the sockets, which is a different claim.
- **A debug key, and it says in the code that it is scaffolding**, exactly as
  the `X` key does for `sit`: cycle the worn tier 0-5 on the local character.
  Items v1's first job is to delete it.

**Files:** `scripts/character/armour.gd` (new), `rig.gd`, `character_view.gd`,
`character_def.gd` (the piece counts), `tools/parts_author/armour.py` (new),
`__main__.py`, `scripts/character/parts/parts_armour.gd` (new, generated),
`scripts/ui/character_debug.gd`, `scripts/tools/selftest_character.gd`,
`scripts/tools/character_gallery.gd`.

**Evidence:** `--label v2-8`; a new `--sheet armour`: every race wearing every
shipped slot, front and three-quarter, at 3 m and 15 m; `--sheet budget` with
armour on; both self-test suites.

**Verify:**
1. **`_test_armour_never_inside_a_body`**: for all four races and every shipped
   piece, `Rig.voxel_centres_in_rig()` finds **zero** armour voxel cells
   coinciding with a body voxel cell, within the existing half-voxel tolerance.
   Armour sits on a body; it does not sit inside one. This is the same machinery
   the placeholder overlap check uses and it is a count.
2. Plate thickness is 3 voxels on every race - measured off the built part, not
   off the generator, because that is the rule the whole fitting design rests on.
3. Every head piece leaves its race's identity feature visible: the elf's ear
   voxels, the dwarf's beard voxels and the lizardfolk's snout voxels are all
   still on the outside of the silhouette with the helm on. Countable off the
   masks.
4. Triangles with a full four-slot set stay under the budget, or the budget moves
   once, with the measurement.

## Stage 9 - The tier ladder: 0, 1, 1, 3

**Why this design.** With flat vertex colour and no textures, surface detail is
free to author and invisible at range. **The outline is the only currency.** So
armour tiers are a ladder of outline events, not a ladder of surface decoration -
and an outline event is a countable thing, which means the ladder is testable,
which is the reason it is defined that way rather than by adjective.

| tier | events | material | what it reads as |
| --- | --- | --- | --- |
| 1 cloth | **0** | cloth only, race's deep + mid, no accent | what you start in |
| 2 hide | **1** - a shoulder cap | leather over cloth, accent appears | you killed something |
| 3 mail | **1** - a raised collar | the 1-voxel checker over cloth | someone made this for money |
| 4 plate | **3** - pauldrons past the arm line, gorget +2 at the shoulder, faulds below the belt | steel with bright rim slots | someone made this for *you* |

- **Tier 1 has zero outline events on purpose.** If starting gear changes the
  silhouette then the naked character is not the design, the starting gear is,
  and night 1's whole acceptance test is about four races identifiable in
  nothing.
- **Tier 3 does nothing to the outline and everything to the surface, and that
  is correct.** Mail's whole character is that it *drapes*. The 1-voxel checker
  of `SCALE_A`/`SCALE_B` is free LOD: at 5 m you see individual scales, at 15 m
  the checker averages to a flat mid-tone, which is exactly what mail looks like
  from across a field. Tier 3 is where a player learns that armour is not
  monotonically bigger.
- **What makes armour look expensive**, in the order the pieces should be
  authored, because value per voxel is not intuition here: a **cloak** (40-60
  voxels, 30-50% more visual mass, the only thing on the character that can move
  independently, and it hides bad leg geometry); **asymmetry**, which is free and
  is the difference between armour that reads as issued and armour that reads as
  assembled by someone who lived through things; **layering visible at the
  edges**, a 1-2 voxel band of the under-layer where the hard layer stops, the
  same mechanism as the liner and it works for the same reason; **trim**, a
  1-voxel raised rim in `TRIM_BRIGHT` along plate edges, raised so the AO catches
  it; and **heraldry**, a 6x6 block of a contrasting hue on the chest, which is
  cheap, reads at 15 m, and in a four-player co-op game is how you find your
  friends. That last one is pillar 1 in six voxels square.
- **The cloak uses the chain machinery unchanged.** `CHAIN_NAMES` is a table and
  `MAX_CHAIN_LINKS` is 4; a cloak is `["tail", "cloak"]` and two bones under the
  `back` socket. The v1 status doc notes the chain rule was written generic and
  has had one customer; this is the second.
- **`--sheet tiers`**: one race, five tiers in a row, at 3 m, 15 m and 40 m, at
  noon and at dusk. Six images per race. The 3 m row is where the count is taken;
  the 15 m row is what Marcel judges; the 40 m row answers whether any of it
  survives at the distance the game is mostly played at.

**Files:** `scripts/character/armour.gd`, `tools/parts_author/armour.py`,
`scripts/character/parts/parts_armour.gd` (regenerated), `races.gd` (the trim
colours), `animator.gd` (the cloak chain), `scripts/tools/character_gallery.gd`,
`scripts/tools/selftest_character.gd`.

**Evidence:** `--sheet outline` for one race at tiers 1-4; `--sheet tiers`;
`--sheet masks-40` and `--sheet masks-options` (armour must not undo night 1);
`--sheet budget`; both self-test suites.

**Verify:**
1. **`--sheet outline` reports exactly 0, 1, 1, 3.** Not "about". If tier 4
   reports 2, one of the three events is under the 2-voxel-per-side floor and is
   invisible at range, which is the thing the metric exists to catch.
2. Every event is at least 2 voxels per side and at least 3 voxels tall,
   which the metric enforces by construction - so a passing count is also a
   statement that every event would be visible if the pixels were there.
3. `masks-40` with tier 1 on every race is unchanged from Stage 6. Tier 1 has
   zero outline events; if the IoU moved, it does not.
4. Triangles at tier 4 under the budget, or the budget moves once, measured.

## Stage 10 - Tier 5, and the emissive channel a character has never had

**Why this design.** Tier 5 is the only tier that says "you did something", and
its five outline events are the three from tier 4 plus a cloak and one vertical
element above the head. Its identity, though, is one small thing: **an emissive
accent of 4 to 12 voxels**, a rune band on one pauldron. Twelve voxels is the
cap and the cap is the design - a glowing character is what every game does
wrong, and the difference between a rune and a lamp is entirely a number.

**This is the stage the design doc's item 12 is really about, and it got cheaper
yesterday.** Until 2026-08-27, `Look.figure_material()` had two callers:
characters, and the impostor forest. Adding an emissive channel to it would have
set two thousand cones on every distant hillside glowing after dark. Distance v1
Stage 6 (`987b076`, merged in `f23c3f0`) split the impostors onto
`Look.far_tree_material()` for unrelated reasons, and `figure_material()` now has
exactly one caller. **Check that this is still true before touching the shader**
(`git grep -n figure_material -- '*.gd'`); if a third caller has appeared, the
emissive gets its own material rather than a uniform on a shared one.

- **The twentieth slot, `GLOW`, character `G`.** Which slots are emissive is a
  one-entry table, `VoxelModel.EMISSIVE_SLOTS`, because that is a fact and facts
  are data.
- **The channel is the vertex colour's alpha, exactly as flora's is.**
  `Races.palette()` gives every slot alpha 0 and `GLOW` alpha 1; `build_mesh()`
  already passes `color.a` through from the palette untouched, and `Look.to_wire`
  is `linear_to_srgb()`, which preserves alpha. **No format change.** The two
  systems now agree on the channel, which is what item 12 actually needed; they
  keep their own array shapes, because flora resolves colours at author time and
  characters resolve them through a per-character palette, and that difference is
  the palette-swap feature. See disagreement 2.
- **One uniform and one line in `OPAQUE_SHADER`.**
  `uniform float figure_emissive = 0.0;` and
  `EMISSION = kubik_to_linear(COLOR.rgb) * COLOR.a * figure_emissive * mix(0.25, 1.0, kubik_night);`
  `kubik_night` is already a global in `Look.HEADER`, published by `SkyCycle`.
  The default is 0.0, so terrain, the far field and the impostor ring - all of
  which write alpha 1 and share the shader source - are unaffected; only
  `figure_material()` sets it to 1.0. The `0.25` floor means a rune is present by
  day and strong at night, which is pillar 2's register: the dark is where the
  warm things show.
- **The self-tests that read `ARRAY_COLOR` change meaning.** Character vertex
  alpha goes from 1 to 0 for every non-glow voxel.
  `_test_mesher_ao`, `_test_palette_swap` and `_test_eyes_closed_variant` compare
  colours read back off the mesh; each must compare RGB and assert alpha
  deliberately, never loosen a tolerance to make an alpha change go away. Look
  v2's own tech plan hit the same class of thing and its rule applies: update the
  assertion, never weaken it.
- **The cap is a test, not a guideline.** `_test_glow_is_capped`: every buildable
  character at every tier has at most 12 voxels in the `GLOW` slot. It is a
  count, it takes one loop, and it is the only thing standing between "a rune
  band" and "a character made of light".

**Files:** `scripts/world/look.gd`, `scripts/character/voxel_model.gd`,
`races.gd`, `tools/parts_author/armour.py`, `parts_armour.gd` (regenerated),
`assets/characters/README.md` (the twentieth index),
`scripts/tools/selftest_character.gd`.

**Evidence:** `--sheet tiers` at dusk with tier 5 in the row; a tour run
(`--tour --seed 42 --label char-10`) confirming terrain, far field and impostors
are unchanged, which is what proves the uniform did not leak; `--sheet outline`;
both self-test suites; the worldgen probe.

**Verify:**
1. `--sheet outline` reports exactly **5** at tier 5.
2. `_test_glow_is_capped` passes: 12 voxels, never more.
3. The tour shots are pixel-identical to the pre-stage run except where a
   character stands. A single changed pixel on a hillside means the emissive
   uniform reached the terrain material and that is a stop-the-stage finding.
4. `git grep figure_material` shows one caller.

## Stage 11 - The walk that has a contact pose

**Why this design.** Marcel asked for a large animation set, and the reason a
large set is worth having in *this* game is specific: **players look at each
other.** Two to four people spend hours in each other's field of view, and
animation is the only channel through which a character has a personality when
nobody is talking. That is pillar 1 doing its job, and it is why the priority
below is "what does a second player read from ten metres away" rather than
"what is easy".

Tier A, in the design doc's order: idle, walk, run, sprint, jump, fall, land,
turn in place. Most of them exist; what they are missing is the second joint,
which now exists.

The details that make a rigid-part animation read, in rough order of value per
line of code. Two of the twelve are **already in the build** and are listed so
nobody re-implements them: the pelvis bobs at twice the stride frequency
(`sin(2.0 * TAU * phase)`, and getting this wrong makes a walk look like a
limp), and the animator blends from the current pose rather than from the new
cycle's frame zero. The rest land here:

1. **Hip counter-rotation**, shoulders opposite hips, +-8 degrees. Two lines.
   It is the difference between a person and a wind-up toy.
2. **The contact pose** - front leg straight, back leg bent, both feet down for
   one frame. It is the pose everyone skips and the one that makes a walk a
   walk, and it is impossible without the knee. Non-negotiable.
3. **Foot roll**, +-12 degrees on the ankle: heel-down at contact, toe-down at
   push-off. Free now that there is a lower leg to hang a boot pitch off.
4. **Arm swing asymmetry**: the forward swing about 20% wider than the back
   swing. Symmetric swing reads mechanical.
5. **Head lag**: the head reaches a new facing 0.12 s after the body. It makes
   the head look attached to a neck rather than welded to a torso.
6. **Overshoot on every settle**: one small overshoot with a critically-damped
   return, on landing, on stopping, on every pose transition. `land_squash_ms`
   exists and needs the overshoot.
7. **Anticipation**: 3 frames of reverse motion before anything big, and a
   **hold at the jump apex**, about 40 ms where nothing moves.
8. **Breathing amplitude tracks exertion**: 2 voxels at idle, 5 after a sprint,
   decaying over 8 s. Free winded-ness with no sound.
9. **Stance width tracks acceleration**: narrow accelerating, wide stopping, two
   voxels of leg X offset. Nobody will consciously see it.
10. **Turn in place**: the feet actually re-plant. A body that rotates without
    its feet moving is the single most common giveaway of a cheap rig.

Every number is a `CharacterConfig` export with a row in `TUNING_ROWS`, which
puts all of it on the F8 panel and none of it in code - the rule character v1 set
when it was tuning on the wrong renderer, and still correct now that the renderer
is right.

**Files:** `scripts/character/animator.gd`, `character_config.gd`,
`locomotion_state.gd` (the acceleration the stance width reads),
`scripts/tools/selftest_character.gd`, `scripts/tools/character_gallery.gd`.

**Evidence:** `anim-<race>-walk.png`, `-sprint.png`, `-jump.png`, `-poses.png`
for all four races, read against night 1's; the animator cost, reported over 600
frames after a 60-frame warm-up; both self-test suites.

**Verify:**
1. **The contact pose is visible in at least one of the eight frozen phases of
   `anim-human-walk.png`.** That is acceptance test 4 and it is not there today
   because there is no knee. Countable off the pose, not off the picture: at
   some phase, one leg's knee angle is within 3 degrees of zero while the
   other's is over 20, and both feet are within one voxel of the ground plane.
   Assert it in a self-test over 360 phase samples.
2. `_test_idle_converges` still passes - at zero speed the pose converges on
   idle, with the tail's known exception.
3. `_test_knee_never_hyperextends` still passes with every new detail applied.
4. The animator cost is recorded and is **not** gated. Expect the same order as
   v1's 0.045-0.053 ms; the research figure of 25-40 ms for four players is off
   by two orders of magnitude, and it matters because a number like that would
   have talked us out of secondary motion, spring damping and idle breaks on
   cost grounds that do not exist.

## Stage 12 - Per-race gait, idle breaks, and the personality that is not optional

**Why this design.** Race is never a stat, and gait is not a stat either - it is
the same animator reading different numbers out of `races.gd`, exactly as stride
already does. The existing rule that stride scales with leg length already
produces dwarf < human < elf from one line of arithmetic. This extends it, and
it stays data: the multipliers ride in `dims`, which `pose_for()` already
receives, so the animator gains no parameters and learns nothing about which race
it is animating.

- **`Races.TABLE` gains a `gait` sub-dictionary per race**, eight multipliers on
  existing `CharacterConfig` knobs:

  | | human | elf | dwarf | lizardfolk |
  | --- | --- | --- | --- | --- |
  | cadence | 1.00 | 0.85 | 1.20 | 1.10 |
  | arm swing | 1.00 | 1.35 | 0.65 | 0.80 |
  | hip counter-rotation | 1.00 | 1.20 | 0.60 | 1.40 |
  | pelvis bob | 1.00 | 1.15 | 0.55 | 0.70 |
  | sprint lean | 1.00 | 0.80 | 1.10 | 1.60 |
  | settle time | 1.00 | 1.30 | 0.55 | 0.90 |
  | idle break rate | 1.00 | 0.70 | 1.40 | 1.20 |
  | head lag | 1.00 | 1.30 | 0.70 | 0.60 |

  In words: the elf glides and takes a long time to stop; the dwarf is a piston -
  short, quick, low bob, settles instantly, fidgets constantly; the lizardfolk's
  power is in its spine, so its counter-rotation and its lean are the highest in
  the cast and its arms do the least; the human is 1.00 everywhere, which is what
  being the reference means. Starting values, all of them.

- **Idle breaks are the cheapest personality in games.** After 4 s of true idle,
  play one of four short motions - a weight rock, a shoulder roll, a head tilt, a
  look around. Four short poses, and the character stops being a mannequin. The
  four poses are built here; **the chooser is `TODO(marcel)` #1** and ships as a
  stub returning pose 0, which is a working idle break rather than nothing.

- **What is NOT built here, and why.** The design doc's tier B is nine
  animations - crouch, crawl, climb, wade, swim, carry, place object, interact,
  harvest, sit, downed, revive - and **seven of them animate a mechanic that does
  not exist**. There is no climbing, no water to wade in, no carrying, no
  reviving and no harvesting. Building `climb` before climbing exists is
  animating a guess, and the guess will be wrong in the specific way that makes
  it cheaper to throw away than to fix. `sit` and `downed` exist and were refined
  in Stage 4. `place object` belongs to the campfire plan (Wave 2, E) and should
  not be pre-built for the same reason. Tier C, combat, is deferred by the design
  doc itself until the wolf playtest that `CLAUDE.md` names as a v0 prerequisite,
  and that stands.

**Files:** `scripts/character/races.gd`, `animator.gd`, `character_config.gd`,
`scripts/tools/selftest_character.gd`.

**Evidence:** `anim-<race>-walk.png` and `-poses.png` for all four races, with
the per-race gait visible in the strips; both self-test suites.

**Verify:**
1. **`_test_gait_differs`**: at the same speed and phase, the four races produce
   measurably different poses on at least five of the eight axes, and the
   ordering matches the table's intent (dwarf cadence highest, elf arm swing
   highest, lizardfolk lean highest). A table nobody can see the effect of is a
   table that has not been wired up.
2. Stride order is still dwarf < human < elf, from one line of arithmetic.
3. `_test_idle_converges` still passes: an idle break is a departure from idle
   and must return to it.
4. The `TODO(marcel)` stub is reachable, returns pose 0, and the game runs.

## Stage 13 - The critter, the sheets, and the record

- **The critter.** It was regenerated at 96 in Stage 3 because its `DIMS` are in
  voxels; this is where it is looked at. `critter-walk.png` against night 1's,
  `_test_critter` green, and the number the first-enemy plan will want recorded:
  triangles, bones, and animator cost per creature. It has no knee and should not
  grow one here - `RIG_SHAPES["trot"]` with no `lower` key is the correct
  description of a four-legged animal built from rigid parts, and the
  first-enemy plan can decide otherwise with a quadruped in front of it.
- **The gallery, finished.** `--sheet armour` and `--sheet tiers` shoot at 3 m,
  15 m and 40 m rather than one distance, which is item 10; `--sheet outline` is
  in the default set; `--sheet palette-tiers` is in the default set. Count the
  images and record the number - it was 53 at the baseline.
- **`docs/DESIGN.md`.** "Gear": three visible slots become six, named, with the
  sentence that four ship and two are declared. This is a change to settled
  design and it lands here, deliberately, rather than silently in Stage 8 - the
  design doc says so and it is right. "Art pipeline": confirm Stage 3's amendment
  reads correctly against the built game, and add the armour fitting rule
  (proportions relative, thicknesses absolute) as one paragraph, because it is
  architectural and expensive to retrofit, which is the bar that section sets.
  "Races": the four heights are unchanged in metres; the voxel column changes.
- **`README.md`**: the character section's voxel scale; the new gallery sheets
  under "Running it".
- **`TODO.md`, `docs/IDEAS.md`, `docs/ROADMAP.md`**: character v2 gets a line,
  positioned before Wave 1, with the reason from disagreement 5 - creatures v1
  builds a quadruped on `RIG_SHAPES` and combat v1 builds hit and death poses on
  `pose_for()`, and both are cheaper against a rig that already has a knee.
  `STATUS.md` points at the new status doc.
- **`docs/status/character-v2.md`**, finished: the case, the count tables stage
  by stage in one wide table, every starting value with its final value, a
  "Tuned blind" section that is **empty for the first time in this project's
  history** and says why (ganymede has a GPU; every judgement in this run was
  made on Forward+ on a 3070 Ti, which is not Marcel's 5080 but is the same
  renderer and the same driver family), the corrections to
  `docs/status/character-v1.md`, and what is left.
- **The campfire shot.** Four characters in tier-3 gear, sitting, at 3 m, at
  dusk, on the GPU. It is not a test and it is the actual point: if that image is
  not one Marcel would put on a poster, the epic is not done, whatever the
  numbers say.

**Files:** docs, `scripts/tools/character_gallery.gd`, `STATUS.md`.

**Evidence:** the full gallery run; both self-test suites; the worldgen probe;
the two-peer run.

**Verify:** every doc claim matches a number in the status doc; the worldgen
probe prints `76cccdb6` and `(-44, -124)`; both suites green; the campfire image
exists and has been looked at.

---

## The `TODO(marcel)` exercises

House rule: leave a few small, well-defined pieces open with a working fallback
and a hint, and keep everything runnable without them. Three, each owned by a
named stage, each with the fallback that ships.

1. **The idle-break selector** - `animator.gd`, **Stage 12**.
   Four short poses exist; `_pick_idle_break()` is a stub that returns pose 0.
   *Fallback:* a working idle break, the same one every time.
   *Hint:* a weighted random pick with a randomised 4-9 s interval, and never the
   same break twice in a row - the repeat is what makes it read as a loop rather
   than as a person.

2. **The dwarf's beard-ring tier mapping** - `parts_hair.gd` and
   `armour.gd`, **Stage 9**.
   The beard part supports 0-3 rings; `beard_rings_for_tier()` returns 1.
   *Fallback:* every dwarf wears one ring at every tier.
   *Hint:* it is not linear, and the interesting question is whether rings track
   the *torso* tier or the highest tier worn anywhere. One says "this is what I
   paid for my armour"; the other says "this is what I have become".

3. **Per-race armour trim** - `races.gd` and `armour.gd`, **Stage 9**.
   `trim_hex_for(race, piece)` returns steel for everyone.
   *Fallback:* one authored set that reads as steel on all four races, which is
   correct and dull.
   *Hint:* the same set reads as dwarven in bronze, elven in pewter and human in
   brass for the price of one hex per race, and the interesting question is
   whether trim follows the **wearer** or the **item** - a dwarven axe carried
   by an elf is a different story from an elf's axe.

## Explicitly deferred

Named here so a later run does not have to guess whether they were forgotten.

- **Full two-bone IK foot planting.** Kubik's ground is 0.5 m voxel blocks. An IK
  solver planting on that surface pops by a full half-metre at every block
  boundary and jitters along every edge. Real IK is a decision for smoother
  ground.
- **The foot height clamp with a spring**, which the design doc proposes as the
  cheap correct substitute for IK - raycast down, clamp the foot to the surface,
  let the hip absorb the delta with a critically-damped spring. Deferred **too**,
  and this is a departure from the design doc: it is the only item in the
  animation section that reaches out of the character system into the world, it
  needs a world to raycast against so it cannot be judged in the gallery, and
  nothing in the acceptance tests needs it. It wants a playtest, not a stage. The
  specification above is the whole design; keep it.
- **Cloth simulation of any kind.** The cloak is a two-link chain on a
  spring-damper lag, which is the machinery that already exists.
- **Capes that collide with anything.**
- **Per-race remodelled armour sets.** One normalised set, per the fitting rule,
  with two named lizardfolk exceptions.
- **Facial expression** beyond the existing blink.
- **First-person.**
- **Combat animation of any kind** - light, heavy, block, hit reaction, stagger,
  death - until the wolf playtest `CLAUDE.md` names as a v0 prerequisite.
- **Tier B traversal animation** - crouch, crawl, climb, wade, swim, carry,
  interact, harvest, revive - because seven of the nine animate a mechanic that
  does not exist. See Stage 12.
- **`place object`**, which the campfire plan (Wave 2, E) owns.
- **Anything from Items v1**: no item table, no inventory, no drops, no rule
  about what grants a tier. Armour here is a visual system with a byte on the
  wire and a debug key that says in the code that it is scaffolding.
- **The `PackedInt32Array` packing of the retained voxel list.** Specified in
  Stage 3, built only if a party of four measures over 8 MB.
- **The legs and hands armour slots.** Declared in the table with no geometry, so
  that filling them later costs no wire change.

## Hard rules

1. **This branch does not move a block.** The worldgen probe prints heightmap
   hash `76cccdb6` and spawn `(-44, -124)` at the end of every stage. A character
   branch that moved the terrain has a bug somewhere it should not be able to
   reach.
2. **No stage gates on a frame time.** Every gate in this document is a count.
   The animator cost is reported and not gated. If a comparison between two
   commits ever becomes necessary, it is ABAB, five runs each, median with
   spread, run order recorded - and the first question is whether a count would
   answer it instead.
3. **The mask metric's viewport and distance never change.** 1280x720, 40 m,
   `MASK_THRESHOLD 0.75`. Every IoU number this project has recorded was measured
   there. The outline metric is a separate sheet at 3 m and shares no constants
   with it.
4. **`player.gd` reads no number from `Races`.** Still. Every race's height in
   metres is unchanged by the grid move, so nothing about the capsule, the camera
   pivot, `MAX_STEP` or the speed table is touched.
5. **Parts are data, generated.** No voxel is typed by hand into
   `scripts/character/parts/`. Every part file is an output of
   `tools/parts_author/`, and the header line that says so stays true. A stage
   that edits ASCII by hand has to say so on that line, and the next stage
   regenerates over it.
6. **One authored armour set, four bodies.** Proportions relative, thicknesses
   absolute. The two lizardfolk exceptions are named in `armour.gd` and there
   are no others without a written reason.
7. **Race is never a stat.** The gait table is cosmetic multipliers on existing
   knobs. Nothing in this plan gives a race a number that affects the
   simulation.
8. **Every value chosen by eye lives in `CharacterConfig` and on the F8 panel**,
   with a row in `TUNING_ROWS`, and is listed in the status doc with what it was
   and what it is. The renderer is right this time; the rule stands anyway.
9. **The host validates every claim.** `CharacterDef.from_bytes()` never throws,
   never returns null, and never returns something `validate()` would still
   object to - including for armour, including for a version-1 payload.
   Clamp, never reject.
10. **Nothing generative, nothing from Wave 1, nothing from Items v1.** No enemy,
    no combat, no water, no campfire, no item table, no inventory.
11. **Night 2 starts from night 1's last commit**, never from `main`.
12. **Both self-test suites green at the end of every stage.** A red one stops
    the run at that stage with the output in the status doc. The status doc is
    written at the end of every stage, not at the end of the run, so a run that
    dies at 04:00 still leaves a record.
13. **A stage that runs past 1.5x its share of the night is wrapped at its last
    green commit** and the next stage starts; what was left undone goes in the
    status doc. Stages 5 and 6 are where this will bite - they are three bodies
    and one rebuild, and they are the least predictable work in the plan. Stage 2
    is the exception in the other direction: it is not wrapped early, because
    everything after it depends on its byte-identity gate, and a half-done
    parameterisation is worse than none.

## Acceptance

Four tests, all countable, none of them a frame time - and one that is not a
test and is the actual point.

1. **The lineup.** Four races at 15 m and 40 m, at dusk, in tier-1 gear. Every
   race named without walking closer. **No cross-race IoU pair above 0.70
   front-on, across every hair, beard and crest option.** The number that has to
   move is human/lizardfolk, which is **0.913** front-on and **0.759**
   three-quarter on the GPU today, and 15 of 94 cross-race variant pairs are
   over.
2. **The tier ladder.** One race, five tiers, side by side. Outline event counts
   **0 / 1 / 1 / 3 / 5**, measured by `--sheet outline` at 3 m, not by eye. A
   viewer who has never seen the game orders the 15 m sheet correctly.
3. **The colour test.** Four races side by side at 15 m at noon and at dusk, and
   no two of them are the same value tier on the torso. Every skin clears its
   liner by at least 6:1. This is the one the current build fails hardest.
4. **The walk.** Eight frozen phases, and the contact pose is visible in at
   least one of them - asserted over 360 phase samples, not judged off the
   picture. It is not there today because there is no knee.

And: **shoot the campfire.** Four characters in tier-3 gear, sitting, at 3 m, at
dusk, on the GPU. If that image is not one Marcel would put on a poster, the epic
is not done, whatever the numbers say.

## Handoff

`docs/status/character-v2.md`, in the shape of `docs/status/character-v1.md`
grown to two nights: the case, the count tables stage by stage in one wide table
(triangles, retained voxels, IoU per pair, outline events per tier, part counts),
every hash at every stage, every starting value with its final value, the
corrections to character v1's void IoU table, the three `TODO(marcel)`
exercises and where they are, the deferred list and why, and what the next three
plans need from this run:

- **Creatures v1** gets the critter at the new grid, `RIG_SHAPES` with an
  optional `lower` key so a quadruped can grow a knee or not, and
  `LocomotionState` still the seam between physics and animation.
- **Combat v1** gets a rig with two-segment limbs, which is what every hit
  reaction, stagger and death pose needs, and `pose_for()` still a pure function
  it can add to without a scene tree.
- **Items v1** gets six declared slots, four of them with geometry, a byte layout
  on the wire that does not need to change to fill the other two, an
  `armour.gd` table to point item ids at, and a debug key to delete.

`STATUS.md` becomes a pointer to it.
