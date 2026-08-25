# World feel v1 - status

The run of `docs/plans/world-feel-v1.md`, on `feat/world-feel-v1` from `main`
at `a4bddbe`. Night 1 is streaming and the forest; night 2 is physics.

**Where this ran.** ganymede: headless, Mesa llvmpipe, no Vulkan. Every
**streaming** number here is CPU and is meaningful. Everything **visual** is
tuned blind on the Compatibility renderer and is marked as such, section by
section.

---

## Stage 0 - Measure first, and one bug

**Shipped.**

- `scripts/tools/stream_probe.gd`, `--stream-probe`, wired in `game.gd` beside
  the flora probe. Two parts: the flora probe's twelve 48 m jumps, and a
  **sprint** - 13.0 m/s along +X for 240 m and back, in real frames, sampled
  four times a second for `frontier_m`, `hole`, `frame_ms` and `built/s`.
  `--strict` exits non-zero on any hole or any frame over 33 ms.
- F4 counters: gen and mesh in flight, chunks built, nodes freed and
  `refresh_region` ms on the **last crossing**, and the worst frame in a
  rolling **2 s** window. The existing gen/mesh averages are cumulative since
  load, which is the right number for "did the world arrive" and the wrong one
  for "is it keeping up now".
- **The camera bug, and it was in three places.** `player.tscn` carried
  `far = 400.0` while High fog and the far field both run to 600 m. It is now
  derived - `fog_end_m * Player.FAR_PLANE_RATIO` (1.25) - set from the
  session's config by `Game`, and the literal is gone from the scene.

### The baseline, and it is the point of the stage

Three runs, seed 42, ganymede. Medians:

| | median | plan's expectation |
| --- | --- | --- |
| 48 m settle, outward | **8,857 ms** | 5-9 s, confirmed |
| 48 m settle, back | **7,332 ms** | - |
| hole samples (of 144) | **126** | non-zero, confirmed |
| worst holes in one sample (of 64 probe points) | **24** | - |
| frames over 33 ms | **43** (worst frame 70.6 ms) | - |
| `built/s` at sprint | **87 - 106** | supply 60-150, confirmed |
| `frontier_m` min / p10 | **32.0 m / 40.0 m** | **expected < 0** |

Run-to-run spread is tiny: 48 m settle 8,851 / 9,107 / 8,857 ms, holes 126 /
127 / 126, frames over 33 ms 44 / 43 / 38.

### The verify condition that did not hold, and what it means

The plan says: *"the baseline shows a non-zero hole count and frontier min < 0
(the player is ahead of the ground) at sprint - if it does not, the probe is
not measuring what the playtest felt, and that is the first thing to fix."*

The hole count is there - **126 of 144 samples**, up to 24 of 64 probe points
at once. `frontier_m` never went negative: sprinting 240 m from a settled
world, the collidable ground held **32-40 m ahead** the whole way.

The probe is not wrong, and it was not adjusted until it produced a negative
number. What the two halves say together is that **the missing ground is the
far mesh retreating, not the player outrunning collidable voxels** - which is
what the plan's own opening analysis says in as many words: *"the far-field
hole is cut at radius - 2 cells = 88 m the moment the centre column changes,
so ahead of a moving player the far mesh retreats seconds before the voxels
arrive - that is the missing ground."* The `frontier < 0` line was a second,
stronger hypothesis and it does not reproduce at 13 m/s.

**What follows from it:** Stage 3 (never a hole) is the stage that fixes the
reported symptom. Stages 1 and 2 are still the supply lever and Stage 2 is
still what makes the big trees affordable, but neither is what the playtest
felt. Recorded here so the Stage 3 numbers are read as the headline.

### The camera fix cannot be checked by the tour

The plan's check is *"the tour's vantage that looks at the far ridge"*. It
cannot be, for two reasons found here:

1. **The tour has its own camera.** `screenshot_tour.gd` builds a `Camera3D`
   with a hardcoded `far = 600.0` and never touches the player's rig - a
   *third* independent far plane. No tour shot has ever been taken through
   the camera that had the bug.
2. **At 600 m nothing visible is clipped anyway.** The fog reaches 1.0 at
   `fog_end_m`, so geometry beyond it is already fog-coloured. `6-postcard`
   shot at 600 m and at 750 m is pixel-for-pixel the same frame.

So: the tour's camera now takes the same expression the player's does (one
rule, two cameras), and the fix is verified where it can be - the startup line
now reads `camera far 750 m` and prints in every log. The pre-existing
horizontal banding on the far peaks in `6-postcard` is unchanged by any of
this; it is a look v2-era far-field artefact and is not this stage's.

**Gates, Stage 0:** self-test all passed; character self-test 28 all passed;
worldgen probe `76cccdb6` / `da8868d1` / 73,675 trees / spawn `(-44, -124)` -
unchanged, as a stage that touches no worldgen must leave them. Tour `feel-0`,
14 shots.
