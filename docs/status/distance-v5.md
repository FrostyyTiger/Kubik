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
