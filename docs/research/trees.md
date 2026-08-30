# Tree research - the poster tradition and the voxel levers

Compiled 2026-08-29 from three research passes commissioned for the trees v1
epic: the Art Deco / travel-poster tradition, the voxel/procedural technique
survey, and a full audit of Kubik's own tree code and harnesses. The taste
authority remains `docs/research/art-direction.md` §2.5 "Forest" - look v2's
own research, which already wrote the Deco tree vocabulary. This file is the
variation machinery and the cost model that §2.5 does not cover: §2.5 says
what a spruce IS; this says how two spruces stop being the same spruce.

## 1. The diagnosis, in one sentence each

- A poster tree is drawn from one viewpoint, so its left is not its right; a
  stack of centred discs has no viewpoint, which is why every tree in the
  gallery reads as a bollard. (Every Kubik crown today is `_disc()` on one
  axis: an 8-fold-symmetric solid of revolution.)
- With shade as a flat ink there is no lighting cue: silhouette and the sky
  gaps through the crown are 100% of what the player receives. A gap is worth
  more than a bump.
- The voxel model's job ends at ~96 m, where the impostor ring takes over. A
  0.5 m block subtends ~39 px at 20 m, ~13 px at 60 m, ~8 px at 96 m. Every
  lever must pay off between 5 and 100 m or it is wasted blocks.

## 2. What the poster tradition prescribes (beyond §2.5)

From Broders (PLM), Cardinaux, Maurer, the WPA park serigraphs, Provensen /
Blair / Earle, and Firewatch / Sable's documented pipelines:

- **Tiers are whorls, not discs.** A real conifer grows one ring of branches
  per year; the poster draws the branch tips as a jagged edge, never a smooth
  arc. 4-6 discrete arms of unequal length per tier, each tier yawed from the
  one below, is what makes every azimuth a different silhouette.
- **3-6 readable tiers, no more** - the eye cannot count past five (WPA).
- **The crown underside is a row of down-points**, never a horizontal cut.
- **Asymmetry needs a cause.** One axis per tree; the deviation monotone or
  single-peaked up the stack; correlated across a stand (wind, light, slope).
  Uncorrelated random lean reads as an earthquake; per-tier alternating
  offsets read as damage.
- **Subtract, never add.** Harper: "I don't try to put everything in, I try
  to leave everything out." Break a silhouette by removing a quadrant of one
  tier or biting a notch from a crown - hard cap ~3 silhouette events per
  tree. More is noise.
- **Broadleaf crowns are 2-4 overlapping lobes** in a big/medium/small
  hierarchy with 1-2 concave notches, widest above centre, and always one
  visible fork or limb entering the crown from below - that single detail is
  the difference between "beech" and "lollipop".
- **Dead trees are the one archetype where lopsidedness is the subject**:
  3-7 straight segments, blunt broken ends, half with snapped tops, and
  taller than their neighbours - a snag's job is to puncture the canopy line.
- **A hero tree must not be a scaled parent.** Bigness reads through changed
  proportions: a massive trunk, 2-4 limbs readable against the sky before
  any foliage, a crown broken into 3-5 lobes with real sky between them, a
  flattened top, one dead element, a root flare - and placement in a
  clearing, ringed by ordinary trees. (Veloren agrees: its giant trees get
  more recursion depth, never the same tree scaled.)
- **At 50-200 m only the canopy top line survives.** Height syncopation is
  the whole game at range: ~70% of a stand within ±15% of base height, ~20%
  notably short, ~10% emergents at 125-150% - the emergents and snags are
  the punctuation that makes the line read. A uniform stand is a hedge.

## 3. The ranked levers (voxel survey)

Ranked by payoff ÷ (complexity + cost + reach tax). Sources: Minecraft's
trunk/foliage placer taxonomy and fancy-oak algorithm, Veloren's
`ProceduralTree` (open source), Vintage Story's data-driven grower.

1. **Per-layer radius jitter + hashed whorl phase.** `ri = round(taper) +
   J(y)`, J in {-1,0,0,+1} hashed per layer, clamped to the table radius;
   and hash the notch's starting parity (vanilla spruce hashes exactly this
   one bit). Trivial, zero cost, zero reach. The highest payoff per line.
2. **Crown spine drift.** A crown axis `off(t) = A*t + B*4t(1-t)` with A
   (lean) and B (bow) hashed 1-3 block vectors, trunk drawn along the same
   curve. The strongest "these are not stamps" signal. Costs reach: pay for
   it by narrowing the base radius so the envelope is unchanged.
3. **Coherent clumped fill instead of per-block noise.** Hash holes at
   2x2x2-block resolution instead of per block. Same void fraction, ~5-8x
   fewer triangles (measured: a max larch at fill 0.6 is 791 blocks but
   2,049 quads - 8x the quads-per-block of a solid beech), and it reads as
   foliage clumps instead of static.
4. **Coherent two-tone crown.** One colour boundary per tree - §2.5 puts the
   second colour on the whorl undersides as detached slivers. Coherent runs
   cost a handful of quads; interleaving would cost hundreds. Colour is the
   lever that survives longest - it reaches the impostor ring automatically
   via `color_of_species()`.
5. **Hashed crown-base and crown-height fractions.** The proportions are
   constants today; hashing them ±0.08 adds two variation axes for free.
6. **Branch stubs with leaf blobs at the tips** (fancy oak's core trick:
   leaves blob around branch ENDPOINTS, not the trunk). A 1-wide arm greedy-
   meshes to ~6 quads regardless of length. Envelope discipline required.
7. **Crown bites**: subtract 1-3 hashed spheres centred OUTSIDE the crown.
   Purely subtractive, reads at 60-96 m where nothing else does.
8. **Elliptical / sheared plan** - the same tree looks different as you walk
   around it; hold area constant, declare reach from the long axis.
9. **Top treatment: leader / blunt / snapped**, hashed. The apex is
   silhouetted against sky - the highest-contrast pixels a tree owns. Must
   REPLACE top layers, never extend height (the sky reserve).
10. **Forked leader** (split at 55-75% height, two offset crown lobes) - the
    cure for the dome archetype.
11. **Drooping skirt arcs** below the widest whorls, in hashed azimuth ARCS,
    never per-block fringe.
12. **A shared wind direction** driving lean/flag/eccentricity so a whole
    treeline combs the same way - correlation beats variation at stand scale.
13. Root flare (reads under 25 m, where players live).
14. More leaf shades per species, environment-biased (colour outlives shape).
15. Snag/self-pruned variants (dead lower whorls on dense-stand conifers).

## 4. The constraints that price the levers

- **The reach tax.** The column scan margin is `max_reach + jitter`, squared:
  today 28+2 -> 10x10 = 100 candidate cells per column for 4 real ones,
  ~half of worldgen cost. It steps at multiples of 4 blocks: 28->31 is free,
  28->32 is +44% scan. The discipline (Minecraft fancy oak does exactly
  this): declare the envelope first, fit drift + arms + lobes INSIDE it, and
  never let the widest species grow.
- **Never read back from the writer.** The writer clips silently, so "place
  a leaf only if a trunk landed below" gets a different answer depending on
  which column is drawing. Every condition must come from params. Vertical
  is the same hazard: blocks above the built ceiling are dropped, so "grow
  until blocked" is also a read-back.
- **No libm trig in shape code.** `sin/cos/atan2` are not bit-identical
  across platforms and both machines stamp independently. Use precomputed
  integer direction tables (the golden-angle table is authored once, like
  `LEAN_DIRS`). `sqrt`, `round`, `floor`, `lerp` are fine.
- **Salts:** 217-299 are free. `SALT_SPARSE` occupies the arithmetic series
  `215 + y*7919`; do not land on it. 203/204 keep their values forever - a
  salt is part of what a seed means.
- **Greedy meshing is the client.** The mesher merges same-colour, same-AO
  runs; concavity already fragments merges by +20-40%. Convex-ish, chunky,
  coherent shapes are what the mesher rewards - which is also what the
  poster rewards. Per-block colour or per-block holes are the one sin.
- **The impostor contract.** Silhouette-changing levers (snapped tops,
  forks) ideally get impostor variants - but the far files are distance
  v2's, freshly merged and gated on `far_terrace`; trees v1 leaves them
  untouched and records the drift as carried-forward.

## 5. Cost table (measured on ganymede, isolated specimens, real mesher)

| species (min/mid/max size) | blocks | quads | blocks/quad |
| --- | --- | --- | --- |
| spruce | 416 / 1,097 / 2,125 | 546 / 1,106 / 1,580 | 0.76-1.34 |
| beech | 1,801 / 3,669 / 6,154 | 794 / 1,316 / 1,834 | 2.27-3.36 |
| larch | 248 / 473 / 791 | 686 / 1,160 / 2,049 | 0.36-0.39 |
| krummholz | 51 / 142 / 273 | 103 / 295 / 470 | ~0.5 |
| birch | 146 / 325 / 539 | 303 / 613 / 1,016 | ~0.5 |
| snag | 9 / 12 / 16 | 23 / 22 / 25 | ~0.5 |
| hero | 987 / 9,844 / 28,255 | 878 / 2,318 / 4,690 | 1.12-6.02 |

The finding: **sparseness is the expensive lever, not size.** A max larch
(791 blocks) costs more quads than a max beech (6,154 blocks). Per-block
holes destroy greedy meshing; shape-level openness (a shelf, a gap between
whorls, a bite) is nearly free.

## 6. Sources

Poster tradition: Roger Broders (PLM series and his documented three-area
depth system), Emil Cardinaux (*Zermatt* 1908), Sascha Maurer, Carl Moos,
the WPA National Park serigraphs (C. Don Powell, restored by Doug Leen),
Charley Harper, Provensen, Mary Blair, Eyvind Earle (and L. K. Murphy's
TAMU thesis reverse-engineering Earle trees procedurally), Firewatch (Olly
Moss / Jane Ng - trees designed on their distant silhouette), Sable
(Shedworks - fog as the depth cue over flat shading).

Voxel technique: Minecraft tree definition (trunk/foliage placers, the
cherry placer's hole/hanging knobs, fancy oak's envelope sphere and
branch-tip blobs), Veloren `world/src/layer/tree.rs` (`TreeConfig`,
golden-angle `RAD_PER_BRANCH`, per-species configs, giant = more depth),
Vintage Story's tree grower (`gravityDrag`, evolving angles), Dynamic Trees
and space colonization / L-systems (both rejected: stateful, and sub-block
subtlety at 0.5 m), 0fps greedy meshing.
