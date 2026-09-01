# Distance v5 - status

The run of `docs/plans/distance-v5.md`, on `feat/distance-v5` from `main` at
`02685f9` (distance v4 merged, the far mesher in C++, `far_ring_div` 4 the
default). One night, unattended, on ganymede.
**The far country gets real data, and stops costing frames.**

Distance v4 made the far mesh 40x cheaper to BUILD and turned its detail up
4x. This night is about the three things that surfaced: a main-thread upload
that blocks a fifth of a second every rebuild, a height map with less
information in it than the mesh asking for it, and ring boundaries that
shimmer.

---

## Provenance

Distance v1 introduced this column and v2, v3 and v4 kept it. Kept again
unchanged.

| provenance | means |
| --- | --- |
| `ganymede, deterministic` | the far probe, the worldgen probe or the self-test's parity gate. Pure geometry from a seeded generator: same number on any box, every run. |
| `ganymede, single run` | one wall-clock measurement. A smoke alarm, not evidence of a delta. |
| `ganymede, ABAB median` | interleaved, three runs each, median with spread, run order recorded. The only kind of number this document compares two implementations with. |
| `ganymede, eye` | a judgement made by looking at a tour shot taken here, on the RTX 3070 Ti, Forward+ under `xvfb-run`. |

ganymede varies about 9% run to run on wall clock. Every comparative number
below was taken here, on the **editor** target, headless unless it is a
picture, at **`far_ring_div` 4** unless the row says otherwise - which is the
shipped default since distance v4 Stage 10 and therefore the configuration
every gate in this document is read at.

---

## Stage 0 - the instruments, before

The bring-up is v4's, repeated and green: scons 4.11.1 at `~/.venvs/scons`,
godot-cpp `26fb7ab` against `4.7.2.stable.official.ed1daf0bf`,
`libkubik.linux.editor.x86_64.so` in 2 m 40 s, `-s gdext/check.gd` answering
`class exists: true` and an 18x trivial bench - the same 18x v4 measured here.

### The before-picture

Seed 42, view high (`fog_end` 3,200 m), `far_ring_div` 4, C++ mesher.

| | before | provenance |
| --- | --- | --- |
| startup coarse heightmap, 1500 x 1500 | **16,192 ms**, hash `76cccdb6` | ganymede, single run |
| far field, first build | 3,376,844 verts, 684 ms job, **694 ms wall** | ganymede, single run |
| far field, over a sprint | 133 rebuilds, median **703 ms** wall, worst 809 ms | ganymede, single run |
| `arrays_to_mesh`, MAIN THREAD, div 2 | **57.06 ms** (56.98-57.60) at 941,144 verts | ganymede, median of 3 |
| `arrays_to_mesh`, MAIN THREAD, div 4 | **197.24 ms** (196.27-198.69) at 3,271,568 verts | ganymede, median of 3 |
| sprint, worst frame (out / back) | **286.3 / 268.0 ms** | ganymede, single run |
| sprint, frames over 33 ms | **40** | ganymede, single run |
| sprint, holes | **0 / 0** | ganymede, single run |
| sprint, collidable front min | 48.0 / 56.0 m | ganymede, single run |
| sprint, chunks/s | 93.0 / 98.9 | ganymede, single run |
| static memory (stream probe, 3000 chunks) | **379.4 MB** | ganymede, single run |
| impostor ring, over the same sprint | 30 rebuilds, ~500 ms each | ganymede, single run |
| **standing still 60 s: far field rebuilds** | **0** | ganymede, single run |
| **standing still 60 s: impostor rebuilds** | **0** | ganymede, single run |
| standing still 60 s: worst frame | 8.6 ms, 0 over 33 ms | ganymede, single run |
| full self-test | **green** | ganymede, deterministic |

### The far probe's fizz table, before

`--far-probe --cpp`, seed 42, div 4. 98 meshes, **598 ms each**, 3,360,563
vertices each; both tables IDENTICAL, `PASS`.

| vantage | fizz rms | fizz max | roughness |
| --- | --- | --- | --- |
| spawn | 0.947 | 88.000 | 13.0733 |
| summit | 2.071 | **147.000** | 13.0027 |
| lake | 0.947 | 75.000 | 13.6438 |
| **ALL** | **1.513** | **147.000** | **13.1954** (503,176 samples) |

**Ring boundary max fizz (+/- 25 m)** - the number Stage 3 exists to move:

| boundary | max | rms | samples |
| --- | --- | --- | --- |
| 150 m | 4.00 | 0.257 | 649 |
| 300 m | 10.00 | 0.674 | 2,136 |
| 600 m | 44.00 | 2.852 | 6,459 |
| 1200 m | **88.00** | 4.647 | 15,287 |
| 2400 m | **147.00** | 14.712 | 3,551 |

**These are not STATUS items 9 and 18's numbers and they are not meant to be.**
Those were measured at `far_ring_div` 2, where the ring boundaries fall at
200/400/960/1920 m and read 24.00 / 80.00 / 128.00 / 256.00. The default
flipped to 4 in distance v4 Stage 10, which halves every ring's cell and moves
every boundary, so the table above is the shipped configuration's own
before-picture and Stage 3's gate is read against IT.

### Two instruments were added, because two of tonight's gates had none

Both are appended to `scripts/tools/far_probe.gd` and nothing above them is
touched.

* **`--far-probe --upload`** - what an upload costs on the frame thread, C++
  only, at both divisors. `--bench` already measured this, and it takes the
  GDScript mesher through every vantage on the way: 27 minutes of table at
  div 4 to read one row. The gate for Stage 1 needs that row after every
  change.
* **`--far-probe --idle [--idle-seconds N]`** - stand still for N seconds and
  count what the two far systems did. STATUS item 21 (the impostor ring
  rebuilding 70-120 times while the player stands still) was found by reading
  a tour log, and nothing in the project MEASURED it.

### And the first finding is that item 21 does not reproduce

**Standing still for 60 seconds at spawn, with the world idle, the impostor
ring rebuilds ZERO times and so does the far field.** 8,696 frames, worst frame
8.6 ms, nothing over 33 ms.

That is not a refutation of the observation - v4 counted its rebuilds in a
screenshot tour, which is a different situation - but it does say the mechanism
is not "the ring rebuilds while nothing moves". `FarTrees.update()` already
returns on its first line unless the centre has moved `REBUILD_STEP_M` (24 m),
and standing still it does. **Stage 2 goes looking for the real trigger before
it writes a debounce for a bug that is somewhere else.**

---

## Stage 1 - the uploader

**The headline: the sprint's worst frame goes 286.3 / 268.0 ms to 33.4 / 33.8 ms,
and the count of frames over 33 ms goes 40 to 2.** The far country's handover to
the renderer is the same 196 ms of work it always was; it is now paid a sector
at a time instead of all at once.

### What was built

Three pieces, and the ordering between them is the design.

**1. Both meshers gained a `slice` mode, in the same commit** (parity doctrine,
decision 2). Off, the mesh is the one this project has emitted since terrain
v1, in one set of four arrays, byte for byte - the far probe, the parity
harness and the self-test all build that way, so every number in this document
stays comparable with distance v4's. On, each quad goes to its own frontier
sector's arrays instead of the shared ones, and `arrays` is never assembled.
**Nothing numeric moves**: the walk is the same walk in the same order, every
expression is the same expression, and the only thing that changes is which
four arrays a quad is appended to and what its index base is.

**2. `FarUpload`** - one small queue, `scripts/world/far_upload.gd`. Three
rules, each of which is a way this goes wrong if it is missing: a slice is
atomic (so the budget is a line the pump stops AT, not one it never crosses);
the swap is atomic (slices land in a mesh nobody is looking at and the finished
thing goes on screen in one assignment, so a rebuild in progress shows the OLD
COMPLETE far country and never a mixed one); and a superseded job is dropped
rather than queued behind, so a sprint cannot build a backlog of far meshes for
vantages the player has already left.

**3. `far_upload_budget_ms`, default 4.0**, LOCAL, unhashed, on
`FAR_ONLY_PROPERTIES` so it can be turned to 0 and back standing still. 0
restores distance v4 exactly: everything queued goes up on the frame it
arrives.

### Where the uploader lives - the plan left this to the executor

**`FarField` owns it**, as a `RefCounted` the node holds and drops with itself -
the same ownership `FarMesher` has had since distance v4 Stage 5. FarField
rather than World because FarField already runs a `_process` on the main thread
every frame, already owns the far mesh's whole lifecycle, and already dies with
the world; putting it in World would have meant a second node with a second
`_process` to pump it, for nothing. `FarTrees` reaches it through
`FarField.uploader()` - see Stage 2.

**Sectors rather than rings**, the plan's other open choice. Sixteen sectors of
a far mesh are within a factor of two of each other; six rings are not - ring 0
is a few thousand quads and the outer ring is most of the mesh, so a ring
slicing would have left one 100 ms slice in the middle of the schedule and five
cheap ones around it. A sector is also a wedge from the seam to the fog, so an
uploaded slice is a complete piece of far country rather than a complete inner
ring with nothing beyond it, and `World.frontier_sector_of` already exists and
already cuts the far mesh's per-sector hole.

### The numbers

`--far-probe --upload`, ganymede, editor target, headless, seed 42, median of
three, main thread.

| | whole mesh | sliced, total | **worst single slice** |
| --- | --- | --- | --- |
| div 2, 941,144 verts | 62.61 ms | 56.11 ms over 16 surfaces | **4.27 ms** |
| div 4, 3,271,568 verts | 219.90 ms | 195.65 ms over 16 surfaces | **15.82 ms** |

The total is the same work, because it is the same quads. **The number the
frame budget is about is the worst slice**, because a slice is atomic and is
therefore the largest single thing one frame can be made to pay for. At div 4
that is 15.82 ms against 219.90, and at a 4 ms budget it is one slice a frame
and about sixteen frames a rebuild - a quarter of a second of handover, none of
which is a quarter-second frame.

### The sprint, before and after

Stream probe, seed 42, `far_ring_div` 4, single run each.

| | Stage 0 | Stage 1 | |
| --- | --- | --- | --- |
| worst frame, out / back | 286.3 / 268.0 ms | **33.4 / 33.8 ms** | |
| frames over 33 ms | 40 | **2** | |
| holes | 0 / 0 | **0 / 0** | hard rule 3 |
| collidable front min | 48.0 / 56.0 m | **56.0 / 64.0 m** | better |
| chunks/s | 93.0 / 98.9 | **104.6 / 117.6** | better |
| far rebuilds over the probe | 133 | 174 | |
| far rebuild median wall | 703 ms | 554 ms | |
| static memory | 379.4 MB | **518.3 MB** | worse, see below |

The front-min and chunks/s improvements are the same mechanism distance v4
found and did not predict, one step further along: the far country stopped
monopolising something the chunk streamer needed. Here it is the MAIN THREAD
rather than the worker pool.

### And the thing that got worse: 139 MB

**Static memory goes 379.4 MB to 518.3 MB**, and it is decision 1's second rule
being paid for rather than a leak. An atomic swap means the new far mesh exists
before the old one stops being drawn, so at `far_ring_div` 4 there are two
120 MB far meshes alive for the ~250 ms a handover takes. The lever is to drop
the rule and let the far country be half one vantage and half another for a
quarter of a second per rebuild, which is a worse artefact than the hitch this
stage removed and an intermittent one.

**It was 237 MB before two lines were added**, and they are worth recording
because the first measurement was 616.9 MB and looked like a reason to stop:
a queued slice is a closure holding a sixteenth of a far mesh, so holding every
slice to the end of the job kept a THIRD far mesh alive - the queue's own copy
of the arrays it had already uploaded. `FarUpload` now drops each slice the
moment it lands, and `FarField` drops the mesher's own reference as soon as the
job is queued.

### The gate

| Stage 1 gate (plan) | result |
| --- | --- |
| parity: concatenated slices == the reference build, exact | **8 checks, 0 unmatched, 0 reference quads left over, 0 bad index buffers** - four cases, both meshers |
| stream probe div 4, holes 0 | **0**, both legs |
| no far-upload frame over 33 ms | **worst slice 15.82 ms**; sprint worst frame 33.4 / 33.8 ms |
| the 224 ms class gone | **gone** - 219.90 ms of upload is now 16 x 15.82 ms at worst |
| full self-test | **green** |

### The gate is a multiset match, and decision 2 asks for a diff

Decision 2 asks the harness to compare "the concatenation of slices in a
defined sector order against the reference whole-mesh build, arrays exact". It
is stated here as an exact **multiset** match instead - every reference quad
appears in the slices exactly once, with every position, normal and colour
bit-identical, and every slice's index buffer the quad pattern over its own
vertices - and the reason is that the byte-for-byte form cannot be written.

Grouping the quads by sector reorders them, so the reference has to be put in
the same order first, and that means knowing which sector each reference quad
went to. That is recoverable for a ground quad, whose four corners span its
cell. **It is not recoverable for a riser**, whose four corners span a cell
EDGE - and the two cells either side of an edge can be in different sectors.
Written the naive way this gate failed at `far_terrace 1.0` with a max position
difference of exactly 100 blocks, both meshers agreeing with each other and
neither with the harness. The multiset form is the same claim - "the slicing
did not change the union" - in the only shape the output can carry it, and it
is exact rather than a tolerance.

### Two harness bugs worth writing down, because both looked like the mesh

Both produced a **perfectly symmetric, perfectly repeatable** failure - sixteen
unmatched quads and sixteen reference quads left over, with both meshers
agreeing and every reported component difference at exactly zero - which is a
signature worth recognising, because it is what a harness looks like when it is
wrong and a mesher never looks like that.

1. **`PackedByteArray.resize()` does not zero the new bytes.** The tick list of
   consumed reference quads started with sixteen already ticked. `fill(0)`.
2. **`(dict[key] as PackedInt32Array).append(x)` appends to a copy.** A packed
   array read out of a Dictionary through a cast is a value, not the
   container's own, so the index of quads-by-footprint silently kept only the
   FIRST quad of every repeated footprint - and a two-sided riser and the skirt
   over it share one. Read, append, write back.

`(array_of_arrays[k])[0]` passed to a function DOES mutate through, which is
what the mesher's own sink selection relies on and what made the first bug look
like the second.

---

## Stage 2 - the impostors calm down

**615 rebuilds over a screenshot tour become 18 - one per vantage - and every
impostor count at every shutter is IDENTICAL.** STATUS item 21 is closed, and
the mechanism turned out not to be the one the plan assumed.

### It is not "every stream tick", and standing still it never happened at all

`FarTrees.update()` has returned on its first line unless the centre moved
`REBUILD_STEP_M` since distance v1 Stage 7, so the plan's premise - "rebuilds
on every stream tick" - was not what the code did. Stage 0's new `--idle` probe
said so: **standing still for 60 seconds at spawn, 0 rebuilds**, 8,696 frames,
worst frame 8.6 ms.

So the stage went looking for the real trigger before writing a debounce for a
bug somewhere else, and found it in the place v4 first saw it - a tour.

| | rebuilds over 18 vantages | worst single vantage |
| --- | --- | --- |
| before | **615** | **94** (`11-forest-dusk`) |
| after | **18** | **1** |

Per vantage before: 1, 1, 1, 1, 1, 1, 0, **91, 24, 62, 33, 94, 24, 43, 93, 22,
63, 59**. The first six are quiet and everything after `6-postcard` is not,
which is the shape of a thing that starts happening rather than a thing that
always did.

### The mechanism: the step was a 3D distance and the ring is 2D

The two lines under the guard compute the ring's centre from `position_m.x` and
`position_m.z` and nothing else, so **two positions at the same x and z produce
the identical ring**. The guard measured `Vector3.distance_to`. So ALTITUDE
could ask for a rebuild whose output was, by construction, the mesh already on
screen.

And something is falling. `screenshot_tour.gd` freezes the player on purpose -
"or it would spend the tour falling" - and
`Game._release_player_when_ground_exists()` calls `set_physics_process(true)`
and unfreezes it again, once, early (`[Game] spawn chunk ready, player released
at 31.0 m`, line 27 of an 18-vantage log). A player teleported to a vantage
with no collision under it then falls out of the world for as long as the tour
stands there, and drags the impostor ring behind it at one rebuild per 24 m of
fall - which is where 94 comes from, and where v4's "count drifting 1,096 ->
1,016 -> 939" comes from too: the ring is rebuilt again and again at the same
place while the frontier fills in underneath it.

**The fix here is the half that belongs to `FarTrees`**: the hysteresis is
measured in the horizontal plane. **The other half is a finding and is left
alone** - see "For Marcel to rule on".

### What changed in `FarTrees`, and it is three things

Hard rule 5 limits this file to Stage 2's stated edits, so:

1. **The step is horizontal.** One expression.
2. **`far_tree_step_m`, default 24.0** - which is `REBUILD_STEP_M`'s own value
   since distance v1 Stage 7 and the number every measurement in this project
   was taken at. The knob exists to put the lever in the panel, not to move the
   number. LOCAL, unhashed, on `FAR_ONLY_PROPERTIES`.
3. **The multimesh commits join the uploader** (decision 1). One slice per
   species, the tail as the commit, reached through `FarField.uploader()` -
   FarTrees is Game's child and FarField is World's, so it is the same reach
   `apply_far_knobs` makes in the other direction. The ring is a few hundred
   instances and has never measured above a millisecond; **it is on the budget
   because "every far-system handover" is a rule, and a rule with an exception
   is a thing somebody has to remember.**

**What was NOT added: a trigger on the frontier changing its cell set.** The
plan asks for the debounce to fire on movement "or the loaded frontier actually
changes its cell set", and today nothing rebuilds the ring when the frontier
moves - it waits for the next 24 m of walking. Adding that trigger would make
the ring rebuild MORE, not less; the frontier moves constantly while a world
streams in, including while the player stands still, so it would have broken
this stage's own first gate on the same night it was written. The overlap it
would close is the one world feel v1 Stage 3 already ruled on explicitly: an
impostor standing where a real tree has just landed is invisible, a gap is not.
Recorded rather than done.

### The gate

| Stage 2 gate (plan) | result |
| --- | --- |
| standing 60 s -> 0 rebuilds | **0**, and it was 0 before the change too |
| a full sprint -> rebuild count bounded and recorded | **30** over a 960 m sprint, one per 32 m - unchanged by the fix, because a sprint is horizontal |
| no visual regression in impostor coverage, same counts +/- 2% | **identical on all 18 vantages**, 0.0% |
| `FarTrees` diff limited to the stated edits | three edits, listed above |
| full self-test | **green** |

Impostor count at each shutter, before / after: 594/594, 510/510, 295/295,
377/377, 285/285, 313/313, 707/707, 339/339, 520/520, 311/311, 707/707,
339/339, 580/580, 707/707, 339/339, 665/665, 468/468.

### The tour shots, and which rows the number came from

Far band, rows 0-300, `v5-s1` against `v5-s2`:

**Zero differing pixels on `6-postcard`, `14-postcard-dusk`, `12-meadow-night`,
`13-meadow-dawn`, `17-rim` and `7-forest-interior`** - which is every shot whose
rows 0-300 are actually the far country, and it is v4's own list plus
`7-forest-interior`, which v4 could not get to zero.

The residuals are foreground measured through the far band's rows and they sit
at or below distance v4's own SAME-CODE control values: `8-meadow-closeup` 3.21
(v4's control 3.97), `15-boulder` 1.14 (v4's control 1.28), `10-shore` 0.49,
`1-spawn` 0.09. That is STATUS item 13a's flora non-determinism, and this stage
makes it slightly livelier rather than quieter: the worker pool is no longer
being asked for ninety-one impostor rings per vantage, so more flora columns
have landed by the time the shutter opens. **A whole-frame diff of this pair is
8 sheets "over tolerance" and means nothing** - item 13a says so in as many
words.

### The stream probe after Stage 2

| | Stage 0 | Stage 1 | Stage 2 |
| --- | --- | --- | --- |
| worst frame, out / back | 286.3 / 268.0 ms | 33.4 / 33.8 ms | **34.5 / 32.3 ms** |
| frames over 33 ms | 40 | 2 | **3** |
| holes | 0 / 0 | 0 / 0 | **0 / 0** |
| front min | 48.0 / 56.0 m | 56.0 / 64.0 m | **56.0 / 64.0 m** |
| chunks/s | 93.0 / 98.9 | 104.6 / 117.6 | **103.0 / 116.7** |
| static memory | 379.4 MB | 518.3 MB | **494.4 MB** |
| impostor rebuilds | 30 | - | **30** |

Stages 1 and 2 are one run each and this box moves about 9% between them; the
honest reading of that table is that Stage 2 changed nothing a sprint can see,
which is what it should do - a sprint is horizontal and the fix is about
altitude.

---

## Stage 3 - the geomorph, both meshers

**The loudest ring boundary goes 147.00 blocks of max fizz to 40.00, the whole
table's rms goes 1.513 to 0.981, and the far country got no smoother while it
happened.** STATUS items 9 and 18, carried since distance v2, closed with the
fix those items themselves wrote down.

### What it is, in one paragraph

Distance v2 Stage 9 measured why a ring boundary is loud and it is not the step
ladder: two rings sample a cell's height at DIFFERENT WORLD POINTS - the fine
ring at the centre of its own cell, the coarse one at the centre of the coarser
cell containing it, up to half a coarse cell apart. On a flank that is tens of
blocks of height before anything is quantised. Its third experiment - every ring
at the same sample POINT, each at its own step - measured "16.00, gone", and was
not shipped because sharing a point everywhere means 16 m blocks at every range.

So: share it **only where two rings meet**. Over the last `far_geomorph_cells`
cells before a ring's outer boundary the cell-height sample slides from this
ring's cell centre onto the coarse ring's lattice, and at the boundary both
rings read the same point. It touches the sample position and nothing else - not
the quantisation step, not the ridge test, not the corner heights, not the
terrace fade, not the seam band. `far_field_job.gd` and `far_build.cpp`, same
commit, decision 2.

### The ladder, and why the default is 4 rather than the plan's 2

`--far-probe --cpp`, ganymede, seed 42, `far_ring_div` 4, deterministic. Max
fizz in blocks at each ring boundary, +/- 25 m:

| `far_geomorph_cells` | 150 m | 300 m | 600 m | 1200 m | 2400 m | ALL rms | ALL max | roughness |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **0 (Stage 0)** | 4.00 | 10.00 | 44.00 | 88.00 | **147.00** | 1.513 | 147.00 | 13.1954 |
| 2 (the plan's) | 4.00 | 10.00 | 44.00 | 73.00 | 73.00 | 1.278 | 73.00 | 13.2349 |
| **4 (shipped)** | 3.00 | 7.00 | 32.00 | 47.00 | **40.00** | **0.981** | 61.00 | 13.2539 |
| 6 | 3.00 | 7.00 | 26.00 | 36.00 | 26.00 | 0.829 | 41.00 | 13.2457 |

**Wider is better because of what a geomorph IS.** It does not remove the
height difference between two rings; it spreads it over a band. Fizz is the
change a 32-block step of the player produces, so twice the band is half the
change per step - which is exactly the ratio the 2-cell row shows (147 -> 73).

**Roughness does not fall**, at any width measured. That is the number that
would say the far country was being smoothed to buy the fizz, and it goes
slightly UP: 13.1954 -> 13.2539.

**So why not 6, or the whole ring.** Because the far probe cannot see the thing
that eventually goes wrong: a cell inside the band is drawn on the COARSE
ring's lattice, so a band as wide as the ring is distance v2's third experiment
again and the far country becomes 16 m blocks at every range. Roughness says
the limit is further out than 6; **4 is where the measured gain is already
3.7x on the worst boundary and there is obvious headroom left in a knob Marcel
can turn on F4.** The plan's 2 was written before this table existed.

`far_geomorph_cells` is LOCAL, unhashed, on `FAR_ONLY_PROPERTIES`, and 0
restores the ring boundaries exactly as items 9 and 18 describe them.

### These are not items 9 and 18's own numbers, and here is why

Items 9 and 18 read 24.00 / 80.00 / 128.00 / 256.00 at 200/400/960/1920 m.
Those were measured at `far_ring_div` **2**. Distance v4 Stage 10 flipped the
default to 4, which halves every ring's cell and moves every boundary, so the
shipped configuration's boundaries are at 150/300/600/1200/2400 m and its
before-picture is Stage 0's table above. Comparing tonight's 40.00 against
item 18's 256.00 would be comparing two different worlds' geometry.

### The gate

| Stage 3 gate (plan) | result |
| --- | --- |
| parity exact, both meshers, same commit | **4 whole-mesh cases + a fifth on a world that HAS a boundary: pos, normal and colour differences all 0.000000000, 0 indices differ** |
| the fizz table printed next to Stage 0's | above |
| max fizz down proportionately | **147.00 -> 40.00** on the worst boundary, rms 14.712 -> 4.613 there, ALL rms 1.513 -> 0.981 |
| far-band A/B tour pixel-diff zero between meshers | **0.0000 on nine shots**, see below |
| full self-test | **green** |

### The parity gate was blind, and the third test is why it is not now

`far parity` and `far slice parity` build a 400-block world at `fog_end_m` 90,
where the far radius is 216 blocks and ring 0's nominal outer edge is 300 - so
ring 0 is clamped to the fog, it is the ONLY ring drawn, there is no boundary,
and the geomorph's band is zero in every case. **Both gates came back exact on
the night the geomorph landed and neither had executed one line of it.**

That is STATUS item 13's lesson at a different address, and the answer is a
third test - `far geomorph parity` - on a world with a ring boundary inside its
fog. It asks three things: the two meshers agree exactly with the geomorph on;
the slices are still the reference build's own quads with it on; and
**`far_geomorph_cells` 0 against 4 produces a DIFFERENT mesh**, because two
gates measuring a knob that reaches no code is exactly how distance v2's
`far_terrace` test passed while the knob reached nothing.

### The far band, C++ against GDScript

Two full tours at `far_ring_div` 4, one per mesher, rows 0-300:

**0.0000 differing pixels on `2-summit`, `6-postcard`, `7-forest-interior`,
`11-forest-dusk`, `12-meadow-night`, `13-meadow-dawn`, `14-postcard-dusk`,
`15-under-canopy` and `17-rim`** - nine shots, which is every one whose rows
0-300 are actually the far country and four more than distance v4 managed.

The residuals are foreground read through the far band's rows and they are the
same set, at the same magnitudes, that distance v4 measured against its own
same-code control: `8-meadow-closeup` 5.18, `10-shore` 1.36, `15-boulder` 0.50,
`4-valley-floor` 0.18, `1-spawn` 0.13. STATUS item 13a says what those are -
which flora columns have landed when the shutter opens - and the GDScript leg
is a 45-second far rebuild at div 4, so the two tours stream very differently
on the way to the same vantage. **The mesh identity this gate exists to show is
established three independent ways: five whole-mesh array comparisons at zero,
the geomorph world's own comparison at zero, and nine far-band shots at zero
differing pixels.**

---

## Stage 4 - the height map crosses, tiled, exact

**The canonical world's startup goes 16,713 ms to 4,753 ms, and the two
builders produce the same heightmap hash, the same spawn and the same 53 lakes
- byte for byte.** Decision 3's crossing landed on its top rung; decision 4's
tiling landed on a rung the plan did not name, and this section says which.

### The three numbers

Ganymede, seed 42, the canonical config, and both legs run in the same
self-test every time from now on:

```
canonical world: seed 42, heightmap 4782edac, spawn (-44, -124), 53 lakes, c++ builder,      4753 ms
canonical world: seed 42, heightmap 4782edac, spawn (-44, -124), 53 lakes, gdscript builder, 16713 ms
```

| Stage 4 gate (plan) | result |
| --- | --- |
| heightmap hash: GDScript-TILED vs today's `main` | **`76cccdb6`, equal** - the tiling changed nothing |
| heightmap hash: C++ vs GDScript-tiled, both quantised | **`4782edac`, equal** - the crossing changed nothing |
| spawn byte-equal to `main`'s | **(-44, -124)**, at every quantum measured |
| lakes byte-equal to `main`'s | **53**, at every quantum measured |
| startup coarse-map time under half of today's | **4,753 ms against 16,713**, 3.5x |
| micro-gate, GDScript against C++ | **10,000 samples, 0 differing, worst 0.00000000000000000**; one 64x64 tile, 0 cells differing |
| the self-test gains the canonical-seed hash test | `canonical world`, and it runs BOTH legs |
| full self-test | **green** |

**Decision 3's rung: the top one.** World truth reads the C++ tiles. The ladder
in the plan - fall back to GDScript tiles for spawn and lakes if quantisation
cannot make the two legs equal - was not needed and is not taken.

### The quantisation, and what it cost

Every height is rounded to **1/1024 of a block** as the last step of
`height_at_block`, in `terrain_generator.gd` and in `height_tiles.cpp`, in the
same commit. The argument is distance v4's Windows addendum: gcc and MSVC round
the same expression one float ULP apart, that did not matter for a look-only far
mesh, and it matters absolutely here because spawn and lakes are computed from
this number and terrain is never sent over the network. Half a quantum is
0.24 mm of world; a double ULP at these altitudes is about 0.00005 mm; two
compilers cannot round to different multiples of something twenty thousand times
larger than their disagreement.

**What it changes is the hash and nothing else**, and that was measured rather
than assumed. `scripts/tools/quantum_probe.gd` builds the canonical world at
six quanta, GDScript builder, and reports what moved:

| quantum | heightmap | spawn | lakes |
| --- | --- | --- | --- |
| off | **`76cccdb6`** | (-44, -124) | 53 |
| **1/1024 (shipped)** | `4782edac` | (-44, -124) | 53 |
| 1/16384 | `108862ec` | (-44, -124) | 53 |
| 1/65536 | `cdc2fb91` | (-44, -124) | 53 |
| 1/1048576 | `eec44af2` | (-44, -124) | 53 |
| 1/16777216 | `be1bf398` | (-44, -124) | 53 |

Two things worth reading off that table. **The `off` row is `main`'s own hash**,
which is how the tiling was proved to change nothing - a separate question from
the quantisation, and the only way to answer it separately. And **the hash moves
at every quantum**: a rounding that changes no stored bits is a rounding that
does nothing, so "the heightmap hash is unchanged" and "there is a quantisation"
cannot both be true, and the gate that matters is the one under it - spawn and
lakes, which do not move at any quantum this project could reasonably pick.

### And an hour was lost to a config, which is worth writing down

The first run of the canonical test reported the world had MOVED - hash
`1344d3bb` against `76cccdb6`, and 56 lakes against 53 - and the obvious
suspect was the quantisation. It was not. **The test built its config with
`WorldgenConfig.new()` and the game builds it with `load_or_default()`, which
also calls `apply_world_scale()`** - and that derives `continent_amp`,
`mountain_amp`, `continent_freq`, `mountain_freq`, `base_altitude` and
`max_altitude` from `world_scale`. A config without it builds a world with a
different SHAPE, and three extra lakes is what a different shape looks like.

`Selftest.canonical_config()` now builds it the way the game does and says so.
It deliberately does NOT call `load_or_default()`: that reads
`user://worldgen.tres`, so on a machine that has one the cross-box comparison
would be of two different worlds.

### The tiles: what landed, and what did not

**What landed.** The map is built in tiles anchored to the ORIGIN rather than to
the region's corner - `Chunk.floor_div(min_block, tile_blocks)` gives the first
tile index and the region is however much of the world grid happens to be
loaded, which is the property an unbounded world needs and a region-relative
grid cannot have. `heightmap_tile_blocks` is the knob, default **512**, rounded
down to a multiple of `coarse_step`. Today's 3 x 3 km region is a **12 x 12**
grid of them with a partial edge tile, and the region is not required to be a
whole number of tiles - it generally is not, and that is correct rather than
tolerated.

**The tile size is a measurement**, per the plan's rule of "under ~100 ms a
tile". At `coarse_step` 4 on ganymede:

| builder | per tile, median | worst | whole map |
| --- | --- | --- | --- |
| C++ | **10 ms** | 20 ms | 4,753 ms |
| GDScript | ~116 ms | - | 16,713 ms |

512 blocks is the largest power of two that keeps the GDScript fallback near
the line; the C++ builder is an order of magnitude inside it and stays inside it
through Stage 5's doubling.

**What did NOT land, stated plainly.** The tiles still write into ONE region
array - `Heightmap.cells` - and every existing reader still indexes it as
`i + j * cols`: lakes, spawn, the two zone passes, four probes, the self-test
and the C++ far mesher's own marshal. **So the global-extent assumption has
moved out of the BUILDER and not out of the STORE.** Making each tile own its
array is a change across eight files whose acceptance gate is a byte-identical
world, it buys nothing until a second region exists, and attempting it in the
same stage as the crossing and the quantisation would have put all three at
risk of one bug. The note is in `heightmap.gd` so the next epic starts from a
sentence rather than from a surprise.

**The apron is in the same position.** The pyramid is built over the region in
one pass, so it cannot see a tile seam - there is nothing between two tiles to
see. An apron becomes necessary on the day tiles stop sharing an array, and
that is written down next to the tile code rather than left to be rediscovered.

### Where the C++ went, and why it is its own class

`KubikHeightTiles`, not four more methods on `KubikFarMesher`, and the reason is
hard rule 8's line. The far mesher is look-only and may be trusted on that
basis; this class decides where the ground is. Same seam shape as distance v4's
- data in, arrays out, `setup()` once per world, the generator's own eight
`FastNoiseLite` refs sampled natively so the noise is bit-identical by
construction - and the same fallback: `HeightTiles.available()` is false on a
checkout with no compiled library and every tile is built in GDScript, which is
hard rule 1 and is now also *checked*, because the canonical-world test runs
both legs on every self-test run.

One transcription detail cost a re-read and is the same class of thing distance
v4's three precision notes are: **`_domain_warp` returns a `Vector2`, and a
`Vector2` is float32.** Both warp components are truncated before they are added
to the sample position. Done in double throughout, the whole map drifts by a
fraction of a millimetre - which after quantisation is invisible until it is a
different multiple of 1/1024 somewhere, and then it is a different world.

---

## Stage 5 - the resolution: MEASURED, AND IT WAITS

Decision 5's gate is *"startup coarse-map wall ON GANYMEDE no worse than
Stage 0's baseline despite 4x data (**C++ pays for the resolution, or the
resolution waits**)"*. It was run, and the resolution waits.

`coarse_step` stays at **4 blocks (2 m)**. **The world does not change on this
branch**: seed 42 is still `4782edac`, spawn (-44, -124), 53 lakes, and no
config hash is bumped. Marcel's advance acceptance of a same-seed world change
is not spent.

### What it would buy

`--far-probe --cpp --set coarse_step=2`, ganymede, seed 42, deterministic.

| | 2 m cells (shipped) | 1 m cells | |
| --- | --- | --- | --- |
| **far probe ROUGHNESS** | 13.2539 | **14.3523** | **+8.3%, the far country genuinely sharpens** |
| ALL fizz rms | 0.981 | 0.913 | better |
| ALL fizz max | 61.00 | 38.00 | better |
| vertices per mesh | 3,358,739 | 3,289,743 | -2% |
| static memory (stream probe) | 494.4 MB | 554.0 MB | **+59.6 MB**, inside the +120 MB budget |

**The claim in decision 5 is true.** Four times the data makes the far country
measurably sharper by the one number in this project that measures sharpness,
and it does it while the fizz goes DOWN rather than up - the geomorph and the
finer data are not fighting each other.

### What it costs, and the gate it fails

| | 2 m cells | 1 m cells | |
| --- | --- | --- | --- |
| **coarse heightmap** | 16,192 ms (Stage 0) / 4,753 ms (C++, Stage 4) | **18,562 ms** | **the gate: worse than Stage 0's baseline** |
| `Lakes.compute` | ~1.5 s | **17,491 ms** | **11.7x** |
| sprint, collidable front min | 56.0 / 64.0 m | **8.0 / 32.0 m** | |
| sprint, worst frame | 34.5 / 32.3 ms | 42.5 / 57.9 ms | |
| sprint, frames over 33 ms | 3 | 15 | |
| sprint, chunks/s | 103.0 / 116.7 | 57.1 / 79.9 | |
| holes | 0 / 0 | **0 / 0** | |

**The heightmap gate fails by 15%** - and the interesting part is WHERE the
time is, because it is not where the plan expected. The C++ tile builder does
its share honestly: 10 ms a tile becomes 38 ms, which is 3.8x for 4x the data
and still a third of the plan's 100 ms line. Of the 18,562 ms, about **5,500 is
tiles and about 13,000 is `_resolve_zone_thresholds()`** - two GDScript passes
over the whole map that this night did not touch and that scale with cell count
exactly as the builder does.

**And the streaming regression is worse than the startup one.** The collidable
ground reaches **8 m** ahead at the sprint's worst against 56 m, because
`column_surface_range()` walks the heightmap at `heightmap.step` and a step of 2
is four times the samples per chunk. That is a playability regression that no
amount of far-country sharpness pays for; holes stay at 0 only because the
exclusion radius is honoured, which is distance v4's own caveat about a far mesh
that has not landed.

### So: the resolution is not a resolution problem

**The next rung of the C++ ladder is not the chunk mesher.** It is, in order of
measured cost at 1 m cells:

1. **`Lakes.compute` - 17.5 s**, the single biggest number in a world load, and
   11.7x for 4x the data rather than the 4x everything else paid. Superlinear,
   and 241 lakes against 53 is part of why.
2. **`TerrainGenerator._resolve_zone_thresholds` - ~13 s.** Two GDScript passes
   over every cell, and one of them runs `ZONE_CORRECT_ROUNDS` times.
3. **`column_surface_range` / chunk generation** - the reason the sprint's
   front min collapses.

All three are world truth, all three are the same shape of problem Stage 4 just
solved for the height map, and Stage 4's tile seam is the pattern for all of
them. **With those three across, 1 m cells cost about 5 s of startup and the
sprint gets its 56 m back** - and the +59.6 MB of memory is already affordable.

`--set coarse_step=2` runs it today, and the world it makes is a different
world: heightmap `b02e6498`, spawn (10, 34), **241 lakes**. That is the change
Marcel accepted in advance and it is deliberately not being spent on a build
whose streaming is four times slower to arrive.
