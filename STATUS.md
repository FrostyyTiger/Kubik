# Terrain v1 - run status

Unattended run of `docs/plans/terrain-v1.md`, started 2026-08-23.
Branch `feat/terrain-v1`. **Marcel: read this first.**

This file is written as the run proceeds. The final section records what was
done, what was not, and the exact next step.

---

## Performance

All numbers from this machine (Linux, i5-8400, 6 cores). Your Windows box
measured ~1.4x faster on the pre-existing baseline (75 chunks in 960 ms there
vs 1333 ms here), so scale accordingly.

The world being measured is **1028-1051 chunks** - a disc of radius 8 chunks,
surface plus 3 chunks of depth. The old figure of 75 chunks was a fixed 5x5x3
box, so it is not comparable; this is roughly 14x the world.

### Chunk build cost, per stage

| Stage | ms/chunk total | generate | mesh | wall clock |
| --- | --- | --- | --- | --- |
| 3 - naive mesher, main thread | 18.6 | 1.9 | 16.7 | 19.5 s |
| 6a - greedy meshing | 13.9 | 2.4 | 11.4 | 14.6 s |
| 6b - + skip uniform chunks | 9.4 | 2.5 | 6.9 | 9.8 s |
| 6c - + worker threads | - | 3.4 | **0.20** (upload) | **7.9 s** |

**Meshing was the bottleneck and is now effectively free on the main thread.**
16.7 ms/chunk to 0.20 ms - the remaining 0.20 is handing finished arrays to the
rendering and physics servers, which has to happen on the main thread.

Three separate wins, in order of size:

1. **Skipping uniform chunks** (6b) was the biggest single one, and was not in
   the plan. Greedy meshing sweeps 51 planes per chunk whether or not there is
   anything in them, so it was *slower* than the naive mesher on the empty sky
   and solid rock that most of a heightmap world consists of. A chunk with no
   solid blocks now returns immediately; one with no air sweeps only its six
   outer planes.
2. **Worker threads** (6c) moved what remained off the frame.
3. **Greedy meshing** (6a) merges coplanar same-colour faces. A flat 16x16
   chunk face goes from 256 quads to 1.

### What the remaining cost is

The main thread now spends its budget almost entirely on **generating voxels**
(3.4 ms/chunk), not meshing. Wall clock for a full load is ~7.9 s here, during
which the game stays responsive - the budget is capped at 8 ms per frame, so
this is load time, not frame time. Frame budget is met.

Generation could be threaded too, which would cut the load to roughly 1 s. It
was not done: the plan scoped Stage 6 to mesh building, and moving generation
to a worker means chunk data no longer exists at submit time, which changes how
edits are replayed. That is a real change to the mutation path and wants doing
deliberately rather than at 3 a.m. **This is the single biggest remaining
performance win.**

If load time bothers you before then, `voxel_radius_chunks` in the tuning panel
is the dial - it is quadratic, so 8 -> 6 is roughly half the chunks.

---

## Verification

- **Determinism holds.** `scripts/tools/worldgen_probe.gd` prints a hash of
  every altitude in the world; two runs of the same seed produce an identical
  hash, and in the two-peer test host and client independently generated
  `b914d4c8` from seed 1622303605.
- **Multiplayer is intact.** Two-peer handshake tested at every stage that
  touched the world: both peers connect, exchange seed and edits, and spawn
  each other's capsules.
- **Mesher is tested.** `scripts/tools/mesher_test.gd` checks every emitted
  triangle's winding against the normal. 24,600 triangles, 0 wrong.
