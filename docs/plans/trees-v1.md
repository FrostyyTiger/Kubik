# Trees v1 - no two alike, and the ziggurat arrives

One night. The tree MODELS are re-authored - every species, one epic, so the
forest stops being a solid-of-revolution catalogue and this project can stop
thinking about trees for a while. Nothing about WHERE a tree stands changes:
same heightmap hash, same 28,383 trees on seed 42, same species mix, same
spawn. This epic changes what a tree looks like and never where one is -
distance v1's sentence, one layer up.

Written 2026-08-29 against `main` at `93b32bd`, from Marcel's ask of the same
day ("no variation, they're all symmetrical, a bit boring - let's sort of
nail this so we won't have to think about it for a while"), on `feat/trees-v1`.
Other sessions are live in this repo tonight; parts-data v1's hard rule 1
already fences `scripts/world/**` off for us. The port flag on every tour is
not optional (see Evidence).

**The argument is in two documents, and this plan is their execution:**

- `docs/research/art-direction.md` §2.5 "Forest" - look v2's own research
  wrote the Deco tree vocabulary and parked it: *"Tree shapes are frozen for
  look v2... for the later tree plan."* This is the later tree plan. §2.5 is
  the taste authority: where anything below disagrees with it, §2.5 wins.
- `docs/research/trees.md` - the variation machinery §2.5 does not cover
  (whorl arms, drift, clumped fill, bites, forks), the poster tradition's
  rules for asymmetry-with-a-cause, and the measured cost model. Compiled
  2026-08-29 from three research passes.

`DESIGN.md` art-direction rule 4 has said *"Trees are cones and ziggurats
(not yet - see IDEAS)"* since look v1. Tonight "not yet" comes out.

## Why now, against the Next 3

Wave 1 (creatures, combat, water) is next in `TODO.md` and this jumps it, on
the same argument look v1 and character v2 made for themselves: an art
direction is cheap now and dearer with every part authored under the old one.
The trio playtest and every screenshot after it happens in front of a forest;
the campfire's poster shot is framed by trees; wolf encounters happen between
trunks. Every night this waits is another epic's evidence shot against trees
we intend to replace. It is one night, it touches no gameplay system, and it
retires a debt `DESIGN.md` has carried in writing since look v1. It does NOT
touch the canopy-closure design question (`grove_floor`) - that is placement,
Marcel's `TODO`, and stays open; this epic just re-measures it, because crown
shapes moved under it.

## The diagnosis

`tree_species.gd` draws every crown as a stack of `_disc()` layers on one
fixed axis: an 8-fold-symmetric solid of revolution, for all five shapes. The
only asymmetries in the file are the krummholz lean, the snag's three stubs,
the trunk's +X/+Z growth, and per-block noise holes. A tree's whole shape
vocabulary is six numbers (`height`, `crown`, `fill`, `leaves`, `trunk_id`,
`trunk_width`); everything else is a constant inside a shape function. And
the noise holes are the most expensive triangles in the forest: a max larch
is 791 blocks but 2,049 quads - 8x the quads-per-block of a solid beech -
because per-block holes are the worst input greedy meshing can be handed.

The baseline evidence is `build/gallery/memo-baseline/` and
`build/tour/memo-baseline/`: the beech and hero are stacked-disc balloons,
the larch is golden static, the birch a lollipop, and the forest interior is
bare dark columns with sky between the crowns.

## The design, per species

Every prescription below is §2.5 first, the research second. Heights come
from the existing table and do not change; proportions and structure are the
epic. All new per-tree decisions are hashed pure from `(cell, seed)` with new
salts in 217-299, arrive through `params_for()`, and stay inside the
envelope the table already declares.

**Spruce (whorl cone).** The §2.5 spire: max width one third of height
(effective `r = min(table crown, round(h/6))` at draw time), crown base at
0.12 h with the skirt to the ground, the bottom two whorls one block narrower
so the base turns in, the notch on alternate layers only while the tapered
radius is >= 2 (kills the pagoda ribbing at the tip), a one-wide bare leader
for the top 15% of height, octagonal plan for r >= 3 - the same chamfer the
heads take. On top, the variation set: hashed notch phase; per-layer radius
jitter in {-1, 0, 0, +1} clamped to the table radius; tiers drawn as 4-6
whorl ARMS of unequal hashed length around a solid core, each tier's arm
pattern rotated by a golden-angle direction-table step so no two azimuths
match; a small monotone spine drift (<= 1 block total - spruces are the
composition's verticals and stay near-plumb).

**Larch (whorl cone, open).** The same spire at §2.5's 1:4.2, notch every
third layer, `fill` 0.5 - but the holes become coherent 2x2x2 clumps (hash
`(x>>1, z>>1)` with the salt keyed by `y>>1`, keeping the existing
salt-per-layer discipline), which is both the look ("sky shows through") and
a ~5x quad reduction. Blunt or short-forked top on a hashed bit - larch is
the one without the long leader, which is its far-field discriminator. A
minority of larches self-prune: crown base raised, 2-3 one-block dead stubs
below it.

**Beech (dome -> scallop).** §2.5: an oblate scallop 1.2-1.3x wider than
tall, widest at 40% of the crown, a sky gap under it on a clean trunk. The
crown becomes 2-4 overlapping ellipsoid LOBES in a big/medium/small
hierarchy, centres hashed within the envelope, with 1-2 concave bites
(spheres subtracted from outside) - hard cap three silhouette events. A
hashed 40% of beeches fork their trunk at 55-75% height, each leader
carrying its own lobe; every beech shows 1-2 limb blocks entering the crown
underside. Elliptical plan (hashed a/b in 0.7-1.0, area held) so the tree
changes as you walk around it.

**Birch (slender).** The species is the pale trunk - it stays full-height
and visible. The crown breaks into 3-5 small clumps strung along the upper
stem with sky gaps between them, widest around 60-70% of height. The bow:
spine drift with B (mid-bow) dominant and A small - birches arch, they do
not tilt - and all birches in one region bow to the shared wind direction. A
hashed 40% grow as 2-stem clumps splaying from one base, both stems inside
the existing envelope. Fill holes become coherent clumps as with larch.

**Krummholz (mound -> cushion).** §2.5: a cushion 2.0-2.5x wider than tall,
flat top, no spike. Wind-flagged: the existing lean plus plan eccentricity
both take the SHARED wind direction (one hashed direction per world from the
seed, in `params_for` - correlation is the point; a treeline combs one way),
thicker upwind, thin skirt downwind. 1-2 bare dead spar blocks proud of the
mass. Fill clumped.

**Snag (bare).** Three hashed variants: broken-jagged top (the majority),
leaning (up to ~2 blocks of drift), and low stump. Stubs get length 2-4 with
a one-block rise (branch slope), angles consistent within one tree,
lopsidedness welcome - the one archetype where it is the subject. Snags stay
cheap (they are 16 blocks) and they already punctuate the canopy line.

**Hero.** No longer the parent scaled - re-proportioned. Trunk keeps its
width but the crown breaks into 3-5 lobes with real sky between them, carried
on 2-4 one-wide limb lines readable against the sky, a mandatory fork, a
flattened top, exactly one dead element (a bare spike or limb), and a root
flare collar. Everything inside the existing hero envelope - the hero is
already the `max_reach` ceiling and must not raise it.

**The second colour (all conifers).** §2.5: two colours per tree, the second
on the whorl UNDERSIDE - detached slivers where a shelf shades the one below,
never scattered. Implemented as coherent runs (the bottom ring of a shelf
where it overhangs the tier below), which greedy meshing eats for a handful
of quads. New `_U` block ids if the authored blue-violet is not already in
the palette; the A/B per-tree shade mechanism stays as is.

## The rules

1. **§2.5 outranks every number here; the research advises.** Where they
   conflict, §2.5 wins and the conflict is written into the status doc.
2. **The world does not move.** After every stage the worldgen probe prints
   heightmap `76cccdb6`, `28383` trees, the same species mix to the decimal,
   spawn `(-44, -124)`. A stage that moves one of them is not done.
3. **`tree_placement.gd` is read-only.** Nothing in this epic changes a
   `decide()` outcome. (`canopy_cover` will move where crown RADII move -
   that is the floor shade doing its job, judged by eye in Stage 5.)
4. **The envelope is a ceiling.** `TreeSpecies.max_reach()` <= 28 and
   `max_height()` <= 129, asserted in the selftest, every stage. Table
   height ranges do not change; crown ranges may only shrink. Drift + arms +
   lobes fit inside what the table already declares -
   `WorldgenConfig.REF_MAX_TREE_BLOCKS` is not touched.
5. **Purity.** Shape code is a pure function of `params`; no writer
   read-back, no trig (integer direction tables only), new salts only from
   217-299 (216 `SALT_MOUND` is reserved and free), and every new lever
   arrives as a `params_for()` entry so the gallery photographs the truth.
6. **Colour is coherent or absent.** No per-block colour noise; sparse fill
   only as >= 2-block coherent clumps; the second colour only as contiguous
   underside runs. Greedy meshing is the client. Larch, birch and krummholz
   must end the epic CHEAPER in quads than they began.
7. **The far files are not touched.** `far_trees*.gd`, `far_tree_meshes.gd`,
   `far_field*.gd` are distance v2's, merged yesterday, gated on
   `far_terrace`'s byte-identity rule. Near/far silhouette drift is recorded
   as carried-forward, not fixed here.
8. **The judge loop is bounded.** Each shape stage ends with renders judged
   against §2.5 and this plan: at most THREE adjust rounds, then the best
   round ships and the disagreement is written down. No infinite loops; no
   blind tuning - every round's verdict is written against a picture.
9. **No new `PROPERTIES` knobs unless genuinely tunable by Marcel.** Shape
   constants live as consts beside their shape, like today. Anything that
   must be a knob is SHAPE-affecting and goes at the END of `PROPERTIES`
   (the handshake rule), never reordered.

## How to use this document

Execute top to bottom. Every number is a starting value to be judged against
a picture - the rules above outrank all of them. Required reading, in order:
`docs/research/art-direction.md` §2.5 (the taste), `docs/research/trees.md`
(the machinery and costs), `tree_species.gd`'s own header comments (the
contract), `docs/status/world-feel-v1.md` "Stage 5 - Trees at 1:2" and the
closure table (what the forest is for).

### Evidence

```
G=~/bin/godot                      # not on PATH
# invariants - must reprint 76cccdb6 / 28383 / spawn (-44, -124) after every stage
$G --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42     # ~85 s
$G --headless --path . scenes/selftest.tscn                                       # ~3-4 min
# specimens (gallery renders in ~7 s)
xvfb-run -a $G --path . scenes/gallery.tscn -- --label trees-<stage>
# variation, stand and mask modes arrive in Stage 0
# in the world - THE PORT IS MANDATORY, other sessions hold sockets tonight
xvfb-run -a $G --path . -- --host --port 24971 --tour --seed 42 --label trees-<stage> --only forest
xvfb-run -a $G --path . -- --host --port 24971 --tour --seed 42 --label trees-<stage> --only canopy
# closure, once at Stage 5 (~9 min): old growth 0.694 / grove 0.523 / between 0.373 baseline
$G --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42 --canopy
# perf, Stage 5, ABAB medians only, on ganymede
$G --headless --path . -- --host --port 24973 --seed 42 --stream-probe --strict
```

Baselines: `build/gallery/memo-baseline/`, `build/tour/memo-baseline/`
(pixel-stable against `feel-6`), and the cost table in
`docs/research/trees.md` §5. Lit tour shots on this GPU are not
bit-reproducible (31 of 53 sheets differ run-to-run); mask sheets are, and
they are the epic's one exact visual gate.

## Stage 0 - The instruments, before any shape moves

The gallery photographs three sizes of one identical tree per species - the
right instrument for a size range, the wrong one for variation. Extend
`model_gallery.gd` (and `stamp_specimen()` only as needed to let a cell
through):

- **A variation row**: `--vary <species> <n>` - n specimens of one species
  at the SAME size t, hashed from n different cells. The instrument this
  epic is about.
- **A stand shot**: `--stand <species>` - a dozen trees at realistic 8-block
  cell spacing, where a repeated silhouette actually reveals itself.
- **A mask mode**: `--masks` - each specimen white-on-black, unshaded, fixed
  camera, cropped bottom-centre like the character gallery's; port
  `_crop_mask` / `_mask_iou` / `_mask_at` from `character_gallery.gd`
  verbatim (hoist or copy; do not entangle the two galleries). Printed per
  species: **SYMMETRY** (mask vs its mirror, median over specimens),
  **TWINS** (median pairwise IoU over 8 same-size specimens from different
  cells), and the species-pair matrix at t = 0.5.
- **A cost line**: blocks and real-mesher quads per specimen, printed.
- **The framing fix**: the species close-up crops the top off the tallest
  spruce and the hero (`_fit()` with the species' own height).

Record the full baseline: gallery + vary + stand + masks + costs at
`trees-0`, and the numbers in the status doc. Expected baselines from the
memo: SYMMETRY ~0.9+ everywhere, TWINS near 1.0 minus size scatter.
Starting targets for the epic (judged, per rule 8): every species SYMMETRY
median <= 0.80, TWINS median <= 0.85, no species pair above 0.70 except
spruce/larch (same archetype; separated by openness and colour - report it,
don't force it).

**Evidence:** `trees-0` gallery set; invariants green; selftest green;
baseline numbers in `docs/status/trees-v1.md`.

## Stage 1 - The conifers (spruce, larch)

The §2.5 spire and the whorl-arm machinery, as specified in "The design".
Shared helpers built here and reused by every later stage: the golden-angle
direction table (a const, like `LEAN_DIRS`), the per-layer jitter hash, the
octagonal disc (chamfered corners for r >= 3), the clumped-fill hash, the
spine-drift offset function. Larch's clumped fill must show in the cost
line: larch quads at max size drop from ~2,049 toward the ~400s.

**Evidence:** `trees-1` gallery + vary + stand + masks; judge round(s);
invariants; selftest (tree borders green proves the arms stayed in the
envelope).

## Stage 2 - The broadleaves (beech, birch)

Lobes, bites, forks, limbs, the ellipse, the bow, the 2-stem birch, clumped
fill. The beech is where the redesign is most visible; the gallery's
mid-size beech close-up against `memo-baseline/species-beech.png` is the
single picture this epic will be judged by.

**Evidence:** `trees-2` set; judge round(s); invariants; selftest.

## Stage 3 - The edge species (krummholz, snag, hero)

The cushion and the shared wind direction; the snag variants; the hero
re-proportioned into limbs and lobes. The wind direction lands in
`params_for()` (hashed once from the seed) so krummholz, birch bow and any
later lever agree about which way the world leans.

**Evidence:** `trees-3` set; judge round(s); invariants; selftest. The hero
close-up against `memo-baseline/species-hero.png`.

## Stage 4 - The second colour

The whorl-underside slivers on spruce and larch (and the hero when its
parent is a spruce). Check the current `_B` palette entries against §2.5's
authored values first - look v2 re-authored the palette and may already be
right; add `_U` ids only if the underside blue-violet does not exist. Quad
cost of the two-tone measured in the gallery cost line - it should be a
handful per tree, or the implementation is interleaving and violates rule 6.

**Evidence:** `trees-4` set; a dusk gallery (`--time 0.95`) to see the
slivers do not glow; invariants; selftest.

## Stage 5 - The world

No code. The full judgement, in order:

- Tour `--only forest` and `--only canopy` at `trees-5`, against
  `memo-baseline`. The acceptance frames: the forest interior should read
  as trees rather than columns, and `15-under-canopy` should show canopy.
- The closure probe (~9 min): record all three numbers against 0.694 /
  0.523 / 0.373. Crown shapes moved, so these move; the targets (>= 0.85 /
  >= 0.60 / <= 0.20) belong to the `grove_floor` design question, which
  stays Marcel's - this epic reports, and only fails itself if closure got
  WORSE where the design said fuller (old growth, grove).
- Stream probe, ABAB 3+3 against the pre-epic commit, on ganymede: holes 0,
  built/s medians overlapping. Trees are half of column generation; the new
  shapes must not move the curve outside noise. (Clumped fill should if
  anything help the meshing half.)
- A full 17-shot tour at `trees-5-full` for the record, both renderers,
  ports 24971/24972.

**Evidence:** the shots, the three closure numbers, the ABAB table - all in
the status doc with provenance tags.

## Stage 6 - The docs, and the merge

- `docs/status/trees-v1.md`: every number with provenance, every judge
  round's verdict and what changed, the gates not met and why, carried
  forward (impostor silhouette drift; birch at 0.4% of the world - a
  placement question this epic may not touch; the closure design question).
- `DESIGN.md` rule 4: "(not yet - see IDEAS)" comes out; one paragraph on
  what a tree now is. `docs/research/trees.md` referenced beside
  `art-direction.md`.
- `docs/IDEAS.md` (the trees entry joins the done list), `TODO.md` (A3
  ticked - it was stale; trees v1 recorded), `STATUS.md` freshened - NOTE:
  other sessions were told `STATUS.md` is ours tonight; rebase before merge
  and keep their sections intact.
- Fetch, rebase onto `main` (parts-data commits directly to main tonight),
  re-run invariants + selftest at the rebased tip, merge `feat/trees-v1` to
  `main` with a house-style merge message, push.

## Hard rules

1. §2.5 is the taste authority; this plan's numbers are starting values.
2. Same seed -> same heightmap hash, same tree count, same species mix, same
   spawn, every stage. The epic changes what a tree LOOKS like, never where
   one stands or how many there are.
3. `tree_placement.gd` read-only; `far_*` files untouched entirely.
4. `max_reach()` <= 28, `max_height()` <= 129, table heights unchanged,
   crown ranges shrink-only, `REF_MAX_TREE_BLOCKS` untouched.
5. Shape code stays pure and border-safe: params-only, no writer read-back,
   no trig, salts from 217-299, every lever through `params_for()`.
6. No per-block colour noise; holes only as coherent clumps; the sparse
   species end cheaper in quads than they began.
7. At most three judge rounds per stage; then ship the best and write down
   the disagreement. A gate that cannot be met is run anyway, recorded, and
   named as not met - never silently skipped.
8. A stage that leaves an invariant moved, a selftest red, or a judge round
   unwritten is not done.
