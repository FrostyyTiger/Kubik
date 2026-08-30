# Trees v1 - status

The run of `docs/plans/trees-v1.md`, on `feat/trees-v1` from `main` at
`93b32bd`, over the night of 2026-08-29/30. Seven stages: Stage 0 builds the
instruments, Stages 1-4 re-author the seven species, Stage 5 takes the world's
judgement and Stage 6 is this document and the merge.

**Nothing about where a tree stands changed, at any stage.** Heightmap
`76cccdb6`, 28,383 trees, the species mix to the decimal, spawn `(-44, -124)`,
`max_reach()` 28, `max_height()` 129, every table height and every crown range
as they were. `tree_placement.gd` was never opened and the `far_*` files were
never opened. This epic changed what a tree LOOKS like and never where one is,
which is distance v1's sentence one layer up.

**`DESIGN.md` art-direction rule 4 has said "Trees are cones and ziggurats (not
yet - see IDEAS)" since look v1.** As of this run it does not say "not yet".

## Read this first

- **The epic has exactly one failed gate and it is canopy closure.** Old growth
  0.694 -> 0.648, grove 0.523 -> 0.481. The plan's self-fail clause says
  closure must not get WORSE where the design said fuller, and it did. It ships
  anyway under plan rule 1, and the ruling is written out in full in Stage 5.
  The reconciliation is stem DENSITY, not fatter trees, and that is placement -
  outside this epic's rules and already Marcel's open `TODO(marcel)` at
  `WorldgenConfig.grove_floor`, which this number now feeds.
- **Spruce SYMMETRY misses its starting target and was priced deliberately**,
  0.86 against <= 0.80. Art direction §2.5 says a conifer is a dark cut-out
  with a jagged edge and a SOLID body, and a solid body is a symmetrical one.
  The picture outranks the number; see Stage 1.
- **TWINS 1.00 is gone.** Two spruces hashed from two different cells were the
  same tree down to the pixel at Stage 0. They now overlap 0.72, and no species
  is above 0.78.
- **Every sparse species is cheaper in quads than it began** - larch -24%,
  birch -44%, krummholz -65% - which is plan rule 6, and the whole gallery
  sheet fell 21,582 quads to 15,608 with the second colour switched on.
- **There is no floating block left in the forest.** `loose_check.gd` is a
  committed tool now and reports 0 on all seven species over 1,673 specimens
  each. It found 3,002 on spruce, 18,548 on larch, 9,813 on birch and 1,076 on
  krummholz on the way there.

## How this run was judged

Orchestrated with a **bounded judge loop**, plan rule 8: at most three adjust
rounds per shape stage, every verdict written against a picture, then the best
round ships and the disagreement is written down. What that cost, per stage:

| stage | rounds | what the rounds were about |
| --- | --- | --- |
| 1, conifers | 3 (the cap) | amplitude, then the larch rebuilt as the ziggurat, then the shelf/gap floor and the detached gold chips |
| 2, broadleaves | 2 orchestrator rounds over the beech; the birch took the rest of the night | the beech's lobe scales; the birch's mass, found after three wrong turns - the answer was a waist |
| 3, edge species | 3 internal, accepted with one envelope-bound disagreement | the cushion's height, the spar count, and why the hero photographed as dinner plates |
| 4, second colour | 2 | the violet had to be authored bluer than it looks |

Two stage-1 and stage-3 verdicts are **deviations from the plan, recorded
rather than smoothed**: the larch shelf radius is `h/5` and not §2.5's 1:4.2
(Stage 1, round 2 - a gap needs two solid shelves either side of it before it
is a gap), and the mid-size broadleaf hero ships not reading as designed
because the fix is a wider crown range, which plan rule 4 forbids (Stage 3).

### Provenance

Every number below carries one of these. The column exists because
`e63554f` is this project's bill for conflating "a number" with "a number
worth comparing".

| provenance | means |
| --- | --- |
| `ganymede, deterministic` | the worldgen probe, the mask sheets, the cost lines or `loose_check`. Pure geometry from a seeded generator: the same number every run, and the mask sheets are asserted bit-stable on this GPU. |
| `ganymede, single run` | one wall-clock measurement. A smoke alarm, not evidence of a delta. |
| `ganymede, ABAB median` | interleaved, three runs each, median with spread, run order and ports recorded. The only kind of number this epic compares two commits with. |
| `ganymede, eye` | a judgement made by looking at a render taken here, under Vulkan Forward+ on the RTX 3070 Ti. |

**Mask sheets are bit-stable on this GPU; lit sheets are not** - 31 of 53
character sheets differ run-to-run, which character v2 found and this epic
inherited. So SYMMETRY, TWINS and the pair matrix are the epic's exact visual
gate and every lit judgement is an eye call. All comparative streams were run
ABAB-interleaved on ganymede.

---

## Stage 0 - The instruments, before any shape moves

**Shipped.** No shape moved. The gallery photographed three sizes of ONE
species, which is the right instrument for a size range and the wrong one for
variation - it draws one tree three times, so two spruces that are the same
spruce look exactly as they should.

Three new modes in `model_gallery.gd`, plus a cost line:

- `--vary <species> <n>` - n specimens of one species at ONE size, hashed from
  n different cells. The instrument this epic is about.
- `--stand <species>` - a dozen at the world's own 8-block cell pitch with the
  world's own jitter, where a repeated silhouette reveals itself.
- `--masks` - every specimen white-on-black, unshaded, under a fixed
  orthogonal camera, cropped bottom-centre. Prints **SYMMETRY** (a mask
  against its own mirror), **TWINS** (median pairwise IoU of eight same-size
  specimens from different cells) and the 7x7 species-pair matrix at t = 0.5.
- a cost line: blocks asked and real `ChunkMesher` quads per specimen.

The pure-image half - `_crop_mask`, `_mask_iou`, `_mask_at` - is ported
verbatim from `character_gallery.gd` so the two galleries' numbers mean the
same thing. The scene half is native here; a character rig and a scratch
volume of blocks have nothing in common but the intent.

The framing fix that came with it: `_look_at()` aims at 0.40 of a subject's
height and `_fit()` fitted a span centred on the look point, so only 0.50 h of
a 0.60 h crown was ever in frame. That is why every species close-up cropped
the top off the max spruce and the hero. `_fit_span()` solves the down-pitched
camera properly.

`tree_species.gd` changed only to let a caller choose the cell:
`stamp_specimen_at()` takes one, `stamp_specimen()` calls straight through
with the one it always used, and the world calls neither.

### The baseline, which is exactly the complaint in numbers

`ganymede, deterministic`, sheet `trees-0-masks`.

| species | SYMMETRY | TWINS |
| --- | --- | --- |
| spruce | 0.81 | **1.00** |
| beech | 0.93 | **1.00** |
| larch | 0.75 | 0.94 |
| krummholz | 0.99 | 0.97 |
| birch | 0.78 | 0.99 |
| snag | 0.21 | 0.37 |
| hero | 0.82 | 0.44 |

TWINS 1.00 is not a rounding. Two solid-crowned trees of one size from two
different cells were the SAME TREE down to the pixel, and the only thing the
cell decided was a leaf shade the mask cannot see.

### Two traps the instruments set, both recorded

1. **Sparse noise faked asymmetry.** Larch 0.75 and birch 0.78 look like the
   two species that already varied. They are not: their per-block hole noise
   is simply not mirror-symmetric, so the three species that beat the target
   beat it by accident. Clumping the fill - which plan rule 6 requires - takes
   that variation away again, so those two baselines are **noise, and were
   replaced by structure rather than defended**. Larch ends the epic at 0.74,
   a hundredth below where it started, and the 0.74 means something the 0.75
   did not.
2. **The pair matrix is size-dominated.** At t = 0.5 two species of similar
   height and width overlap because they are the same size, not because they
   are the same shape. Only the spruce/larch cell is read as meaningful in
   this document; the rest are reported and not steered by.

And two things the numbers taught that the plan did not know: a sparse crown's
holes were hashed from each BLOCK's world position rather than from the cell,
so a larch's block count moved when the larch moved (the mask sheet stands its
specimens one cell apart for that reason); and greedy meshing runs per chunk,
so quads move with position even for a solid species - **compare quads within
one sheet, never across two**.

### Gates

| gate | result |
| --- | --- |
| heightmap hash | **`76cccdb6`** |
| trees | **28,383** |
| spawn | **(-44, -124)** |
| self-tests | all passed |
| baseline recorded | `trees-0`, `-vary`, `-stand`, `-masks`, cost lines |

---

## Stage 1 - The conifers

**Shipped.** `_draw_whorl_cone` was a stack of centred discs on one axis with
every other layer a block narrower. It is now two constructions behind one
shape entry, because spruce and larch are one archetype that the world tells
apart by openness and colour.

**The spruce** is §2.5's spire: the radius comes from the HEIGHT (one third of
it) rather than from the table, which is only the ceiling it may not pass; the
skirt runs to 0.12 h with the bottom two whorls turned in; the notch cuts on
alternate layers and only while there is a radius to cut from, which is what
killed the pagoda ribbing at the tip. Tiers are 4-6 ARMS of unequal hashed
length around a solid core, each tier yawed from the one below by a
golden-angle step off a 13-entry direction table - 5/13 of a turn, the
Fibonacci convergent, and 13 rather than 16 because `gcd(6, 16)` is 2 and the
arms would visit half the azimuths and repeat every eighth tier.

**The larch** is the ziggurat: four to six shelves two to four layers deep,
the top layer of each at the shelf radius and everything under it a block
narrower - the down-point the poster tradition asks of every crown underside -
with one to three layers of real AIR between them, crossed only by the spine.
Sky shows through the GAPS, not through the crown volume. A fifth self-prune;
the top is blunt or short-forked and never a leader, which is the pair's
far-field discriminator at range.

No trig anywhere: `_sector_of` is a 17x17 lookup table, because the
alternative is `atan2` in the inner loop of every crown layer of every tree in
the world, and two machines stamp the same chunk independently.

### The three rounds, and what each moved

**Round 1** was the right spruce at the wrong amplitude and a failed larch.
The leader was 15% of height - six bare blocks on a forty-block tree - so a
stand's canopy line was a row of TV aerials; arms cut to 70% of the tier
radius around an r-2 core left the mid-crown moth-eaten, with sky straight
through the body of a tree that is supposed to be a dark cut-out; and every
spruce leaned. The larch took §2.5 at its word - the same spire at 1:4.2, fill
0.5 - and a radius-two crown with half its blocks hashed away is not a thin
tree, it is a stack of detached slabs on a stick. The stand photographed as
burnt scaffolding.

**Round 2** capped the leader at `clamp(round(0.10 h), 2, 4)` and hung one or
two single-block nubs off the layers under it so the spike grows OUT of the
crown; raised the arm floor to 85% around an r-1 core; and made drift
character rather than damage - a third of spruces exactly plumb, one block
below 34 blocks tall, two above. The taper moved from `round()` to `ceil()`,
because rounding puts `lerp(3, 1, t)` at 1 for every t over 0.75 and the tree
carried a one-wide mast under its short leader.

**And the larch was rebuilt as the ziggurat here.** *Deviation from §2.5,
under plan rule 1, recorded:* the shelf radius is `h/5`, WIDER than the
spruce's `h/6`, and not §2.5's 1:4.2. A gap needs two solid shelves either
side of it before it is a gap at all. §2.5 is the taste authority and this is
the one place in the epic where a judge round overrode it on a picture.

**Round 3** fixed three things the round-2 renders showed: tall specimens had
closed into one continuous column with gold rims, so above thirty blocks a gap
is never less than two layers and may be three, and both shelf count and shelf
depth are chosen against that floor; the top shelves held two, which after an
inward edge jitter is the width of the spine that crosses the gaps, so above
thirty-two blocks they hold three; and gold chips floated detached at the
shelf edges.

**That last one is worth keeping, because the obvious fix was wrong.** Holes
only on the outermost two rings, plus dropping a cell whose inward neighbour
was hashed away, fixes every stranding a HOLE can cause and misses the other
half entirely: two cells at nearly the same azimuth can land in different
sectors of the thirteen, and a sector one block shorter than its neighbour
cuts the ground out from under the longer one's outermost cell. There is no
local test for that. **So a sparse layer is built as a set, flooded from its
own axis, and only what the flood reached is written** - a pure function of
the layer's own arguments, so every chunk that draws the tree computes the
same set and `_test_species_borders` still passes. The solid species never
enter that path.

### The numbers

`ganymede, deterministic`, Stage 0 baseline through round 3:

| | SYMMETRY | TWINS |
| --- | --- | --- |
| spruce | 0.81 -> 0.57, 0.85, **0.86** | 1.00 -> 0.66, 0.72, **0.72** |
| larch | 0.75 -> 0.48, 0.76, **0.74** | 0.94 -> 0.61, 0.66, **0.64** |

The spruce/larch pair separated a little further every round, 0.59 then 0.56.

**Spruce SYMMETRY 0.86 MISSES Stage 0's <= 0.80 starting target and is
recorded as not met.** It was priced deliberately: §2.5's rule is that a
conifer is a dark cut-out with a jagged edge and a solid body, and a solid
body is a symmetrical one. The only asymmetry a spruce has left is the
outermost block of its arms, the two thirds of trees that drift, and the nubs.
That is the trade, and the picture is the authority.

Costs at the gallery's max specimen, `ganymede, deterministic`:

| | blocks | quads |
| --- | --- | --- |
| spruce | 2,125 -> 1,997 | 1,580 -> 1,798 |
| larch | 791 -> 1,697 | **2,049 -> 1,471** |

The larch is plan rule 6 and it holds: a third fewer quads for twice the
blocks, because the openness moved from per-block noise - the worst input
greedy meshing can be handed - to shelves and air gaps, which cost the mesher
nothing. The spruce is 14% dearer in quads than the old cone, is **not in rule
6's list**, and is recorded here rather than tuned away; it is the price of
the solid body and the `ceil` taper.

### Gates

| gate | result |
| --- | --- |
| heightmap / trees / spawn | `76cccdb6` / 28,383 / (-44, -124) |
| species mix | unchanged to the decimal |
| `max_reach()` / `max_height()` | 28 / 129 |
| self-tests | all passed, tree borders and species borders included |
| loose blocks, 1,673 specimens each | spruce 3,002 -> **0**, larch 18,548 -> **0** |
| spruce SYMMETRY <= 0.80 | **NOT MET** at 0.86, priced above |

---

## Stage 2 - The broadleaves

**Shipped.** The beech was one centred ellipsoid on one axis and the birch was
a lollipop with per-block noise in it.

**The beech** is §2.5's oblate scallop, and the proportion is the shape: the
crown's HEIGHT is derived from its half-width through a hashed 1.20-1.30
ratio, so a beech is wider than tall whatever the table rolled, and where the
trunk fraction did not leave room the half-width comes back down instead - a
smaller scallop rather than a taller one. Two to four overlapping ellipsoid
LOBES at 0.72 / 0.54 / 0.46 / 0.42 of that half-width come out at 59 / 27 / 15
by volume: the big/medium/small hierarchy the poster tradition asks for, and a
hierarchy rather than three equal blobs because three equal blobs are a cloud.
One hashed plan ellipse per tree with a hashed axis swap, area held on the
geometric mean. One or two BITES - spheres centred outside the silhouette, so
they can only remove. Two beeches in five FORK at 55-75% of their height. Every
beech carries one or two limb blocks into the crown underside, in trunk id and
drawn before the foliage, which is the single detail that separates "beech"
from "lollipop".

The hard cap of three silhouette events is structural rather than counted: the
big and medium lobes are pushed out until they touch the envelope, which is
one event and it is the scallop, while the small ones sit at half of theirs.
That leaves two for the bites.

**The beech's crown is built as a set and flooded from the trunk, in three
dimensions.** Beech is solid, so the lobes alone cannot strand anything - but
a bite is a sphere subtracted from a union of spheres and there is no local
test that says whether it has just severed one. It is Stage 1's guarantee to
the larch's shelves, one dimension up.

**The birch** is the pale trunk, and the pale trunk stays full height and
visible - a birch whose foliage closes over its own bark is a thin beech.
Three to five clumps along the top half of the stem, laid out downwards from
the top as the ziggurat is, with the arrangement chosen as the one that FILLS
most of the crown. The whole stem bows: `off(t) = B * 4t(1-t)`, one or two
blocks, single-peaked, so the tree leaves the ground plumb and comes back
under its own crown. A birch arches; it does not tilt. Two in five grow as two
stems from one base.

**And every birch in one world bows the same way.** `params["wind_dir"]` is
the one thing in the file hashed from the SEED without the cell - every other
decision here is per-tree because two neighbours must not be the same tree,
and this one is per-world because a treeline combing in thirteen directions
reads as thirteen accidents instead of as weather. Stage 3's krummholz flag
reads it next.

### The birch took the rest of the night, and four rounds were the wrong lever

The vary row said "plates on a stick", so the clumps were narrowed - twice -
and the tree went bald without ever stopping being a stack of plates. Then the
count was biased up and the depth fell out of it, which changed nothing:
on an eleven-layer crown every arrangement that fits trades depth against
count almost exactly. Three clumps of three fill nine layers, four of two fill
eight. **The layout was never what was starving it. The WIDTH was**, and three
things were quietly taking it: a cap of depth-plus-two holding the crown to
four blocks against a table radius of five, a profile `r-1, r, r-1` at full
width on one layer of three, and `_arm_limits` holding the body at `r - 1` -
right for a spruce tier, where the radius IS the envelope, and a straight
block off a clump that was four wide to begin with.

**The last round is the one worth keeping: a WAIST.** Clumps with clear air
between them are three slabs on a pole - they read as separate objects, and a
crown that reads as separate objects is not a crown. A three-wide column of
foliage through each gap makes the whole thing one body with wide lobes and
narrow waists, and it costs the sky nothing, because the lobes are nine blocks
across. Two more things came out of that round: the topmost clump is now a CAP
on the stem top and never offset, so no birch ends in a bare spike, and the
lateral offset came down from two blocks to one, because a clump standing two
out reads as a shelf bolted to the stem.

### `loose_check.gd` became a tool here

Stage 1 built the floating-block sweep by hand in a judge round and threw it
away; by Stage 2 it had caught bugs in two stages, so it is written down as
`scripts/tools/loose_check.gd` and committed. It draws a specimen into an
unbounded buffer through the same stamper the gallery uses, floods
six-connected from the blocks standing on the pad, and counts what the flood
could not reach - **1,673 trees per species**, the gallery's own vary, stand
and size specimens plus a 150-cell sweep at eleven size steps.

What it caught this time: **9,813 loose blocks over 1,673 birches**, nearly
all of them whole bowed stems adrift above their own feet. The bridging that
keeps a one-wide stem connected fired only on a DIAGONAL step, on the
reasoning that an axis step still touches - and it does not: a one-wide column
at `(0, y)` and `(-1, y + 1)` shares an edge and no face. Any change of offset
bridges now, and the beech's fork leaders took the same fix.

It also reported what was still broken and not that stage's to fix: krummholz
shedding about a thousand blocks over the same sweep.

### The numbers

`ganymede, deterministic`, Stage 0 baseline to Stage 2:

| | SYMMETRY | TWINS |
| --- | --- | --- |
| beech | 0.93 -> **0.62** | 1.00 -> **0.70** |
| birch | 0.78 -> **0.55** | 0.99 -> **0.68** |

| | blocks | quads |
| --- | --- | --- |
| beech | 6,154 -> 3,563 | 1,897 -> **1,119** |
| birch | 588 -> 855 | 937 -> **527** |

The beech is 41% cheaper in quads and 42% in blocks, which is more mass than
intended to lose and is **recorded rather than tuned back**: the lobed union
simply encloses less than the ellipsoid it replaces. The birch is plan rule 6
and it holds - 44% cheaper in quads while carrying half again as many blocks.

**Two deviations from the plan, both deliberate.** `BEECH_CROWN_FLOOR` is a
crown height floor that binds on no beech at all: a hero drew as its beech
parent, and at 84 blocks tall with a crown capped at 16 the oblate rule alone
would have given it a 23-layer crown on 61 blocks of bare trunk. Stage 3
re-proportions the hero; until then it keeps two thirds of the space it had.
And the birch's bow, splay and clump offsets spend envelope outside its own
table crown - eleven blocks of reach against the row's five - which is the
spruce's precedent from Stage 1. The bound the world actually pays is
`max_reach()`, and a birch at eleven is nowhere near its twenty-eight. The
beech, which IS one of the wide species, stays strictly inside its own.

### Gates

| gate | result |
| --- | --- |
| heightmap / trees / spawn | `76cccdb6` / 28,383 / (-44, -124) |
| self-tests | all passed |
| loose blocks | birch 9,813 -> **0**; beech and hero **0** |
| SYMMETRY <= 0.80, TWINS <= 0.85 | **MET** on both species |
| salts | 221-226, inside the 217-299 ledger |

---

## Stage 3 - The edge species

**Shipped.** The krummholz was the most symmetric thing left in the file -
SYMMETRY 0.99, TWINS 0.97, a half-ellipsoid on a leaning stub, and two of them
from two different cells were the same shrub. The snag's numbers were already
the best in the file and its variety was one accident with the stubs moved.
The hero was a beech at twice the size on a very long stick, which is the one
thing the poster tradition says a big tree must never be.

**The krummholz** is §2.5's cushion: 2.0-2.5x wider than tall, flat top, no
spike. The proportion is the shape and the table's crown is the ceiling it may
not pass, so the height comes back OUT of the ratio against the width the
table actually allowed - which can only ever shorten the tree, and is what
stops a big krummholz from being four wide by five tall, a bush rather than a
cushion.

**And it is wind-flagged**, off `params["wind_dir"]`. Thirteen per-sector
radii come from the DOT PRODUCT of each golden direction against the wind,
both authored at magnitude eight, so the cosine between them costs a multiply
and a divide and there is no trig anywhere near shape code. Downwind the
cushion runs long and falls to a one-block skirt; upwind it holds sixty per
cent of that width and eighty-five of it all the way to the top - the steep
windward face and the flat plateau. One or two bare dead spars stand proud on
the upwind half, where the cushion is thick enough for a spike to come out of
something.

**The krummholz was also the one species the loose sweep was still red on**,
and had been for two stages: about a thousand floating blocks, two per tree at
worst, because the lean stepped the trunk one block sideways and the dome it
carried shed cells off the bottom edge on the far side. Both the lean and the
bug are gone for one reason - the cushion goes through `_whorl_disc`, whose
per-layer flood from the axis settles connectivity by construction rather than
by argument. The flag is the asymmetry now, and it lives in the plan, where it
cannot strand anything.

**The snag** is three hashed shapes: broken-jagged (the majority - the stem
stops one or two blocks short and a splinter overlapping the break carries the
rest, because a one-wide dead trunk that simply stops reads as a fence post),
leaning (a quarter, two blocks of monotone drift, bridged on every step), and
a low stump (two to four blocks of 2x2 with four independently splintered
corners - it is the bottom of a tree that broke off, so it carries the
diameter of a tree and not of a stick). Stubs get length two to four with a
lift in them, and every stub on one tree comes out of the same neighbourhood
of the thirteen directions: a snag is lopsided, and stubs in thirteen
directions are a bottle brush.

**The hero is no longer its parent scaled.** `SHAPE_HERO` had been a row in
the table that nothing ever dispatched. It keeps the parent for leaf and trunk
ids and for which archetype it is, and nothing else. Both carry the full trunk
width with a ragged root-flare collar on two to four axes, which reads under
25 m, where players live. The broadleaf hero forks at 55-75% into two leaders
and hangs three to five SEPARATE lobes on two to four one-wide limbs drawn in
trunk id before any foliage, so a limb is readable against the sky; a lobe is
convex and contains the limb tip it was centred on, so it can neither strand
anything nor come adrift, and the top lobe is CUT by the crown ceiling, which
is the flattened top and the cheapest way to say "no dome apex". Exactly one
dead element. The conifer hero is the ziggurat at hero scale - five or six
heavy whorls with three to five layers of air between them, at the larch's
fifth rather than the spruce's sixth, ending blunt because an old spruce loses
its leader.

### Three rounds, which is the cap

Round one shipped the krummholz nearly as authored and photographed the hero
as **dinner plates on a telegraph pole**: the crown was a seventh of the
tree's own bounding box. Round two shortened the cushion, cut the spars to one
on three trees in four (two spars on every mound had photographed as a
graveyard - a dozen shrubs behind two dozen pale posts) and doubled the lobe
scales. Round three found the real cause of the plates: **a limb foot may only
sit between the crown base and the fork**, because above the fork there is no
trunk left to leave from, so with the rise tied to the run every lobe but the
fork's sat in the bottom third of the crown and had its underside sliced off
square by the crown base. Limbs climb further than they run now, and the
crown's underside hangs below its base.

### What ships unfixed, and it is the envelope rather than the code

Accepted with one disagreement, `ganymede, eye`: **at mid size the broadleaf
hero still reads as two or three broad flat masses on a long trunk rather than
as a cauliflower.** The hero's table is 84 blocks tall by 32 wide, so at
t = 0.5 - 58 by 22 - there is no room for three to five lobes to be separated
ACROSS the crown; the separation is vertical, and the sky is above and below
the lobes rather than between them. The fix is a wider hero crown range, which
plan rule 4 forbids: crown ranges are shrink-only, and the hero is the species
that sets `max_reach`. **The max-size hero, where the envelope is wide enough,
does read as designed.** Carried forward.

### And the last per-block hole in the forest is gone

The krummholz was the final species still asking `SALT_SPARSE`, so `_disc()`
has no callers and both are retired here - the numbers stay claimed in the
ledger, because a salt is part of what a seed means. **Plan rule 6 is
satisfied in full**: no per-block colour noise and no per-block hole anywhere
in `tree_species.gd`.

### The numbers

`ganymede, deterministic`:

| | SYMMETRY | TWINS |
| --- | --- | --- |
| krummholz | 0.99 -> **0.59** | 0.97 -> **0.78** |
| snag | 0.21 -> **0.28** | 0.37 -> **0.22** |
| hero | 0.62 -> **0.57** | 0.37 -> **0.43** |

The four species this stage did not touch reprint bit-identically, which is
the proof the shared helpers did not shift under them.

| | blocks | quads |
| --- | --- | --- |
| krummholz | 274 -> 150 | 461 -> **160** |
| snag | 16 -> 21 | 27 -> 47 |
| hero | 13,720 -> 9,827 | flat |

Krummholz is a 65% cut in quads and rule 6 is met. The snag is ~1.7x its
baseline quads, which is the price of stubs that slope, and it is inside the
brief: a snag is sixteen blocks and they already punctuate the canopy line.
Measured worst actual reach is the beech at 18 and the hero at 16, against a
`max_reach()` of 28.

### Gates

| gate | result |
| --- | --- |
| heightmap / trees / spawn | `76cccdb6` / 28,383 / (-44, -124) |
| self-tests | all passed |
| loose blocks, all seven species, 1,673 specimens each | **0**, worst tree zero |
| `loose_check.gd`'s "what it knows is still broken" paragraph | now says nothing |
| plan rule 6, per-block noise | **retired entirely** |
| mid-size broadleaf hero | **envelope-bound, accepted, carried forward** |

---

## Stage 4 - The second colour

**Shipped.** §2.5 asks for two colours per tree with the second on the whorl
UNDERSIDE - detached blue-violet slivers where a shelf shades the one below,
never scattered through the crown. That is here, on spruce, larch and the
conifer hero.

**The palette was already right.** The first job was to check look v2's greens
against §2.5's authored values, and **all four match to the hex**: `LEAVES`
`#2F4F3E`, `LEAVES_SPRUCE_B` `#385C48`, `LEAVES_LARCH` `#BD994B`,
`LEAVES_LARCH_B` `#C9A75D`. Nothing moved. **One id was appended -
`LEAVES_SLIVER = 23`** - and it is ONE id rather than one per species, because
the underside is a SHADOW and look v2's shade ink is one colour for the whole
world; a shadow that changed hue by species would be arguing with it.

### `#1F2A46`, authored bluer than it looks on screen

Judge round 1 took the obvious colour - `#2A2F3E`, H225 S32, the value the
design wanted - and it **photographed at H270 S6**: a neutral black band, not
a blue-violet sliver. Measured off a lit crown face, this world's warm noon
sun lands on the three channels at roughly (0.72, 0.54, 0.38), so **blue
arrives at 53% of red** and most of the authored hue is cancelled on the way
to the screen.

`#1F2A46` is that transform run backwards. It renders **H219 S36 V15** on the
lit side against the **H213 S28 V13** the ink makes of the same tree's dark
side - which is the design: a lit sliver reads as the shadow the ink would
have drawn there. The finding is written into `block.gd` beside the entry,
because the next authored dark colour in this game will hit it too.

### The sliver is geometry, not a hash

A cell is drawn in the sliver id when two things are true of it, and both come
out of radii the shape already computed: it is on this layer's OUTERMOST RING,
**and** the cell directly beneath it is OUTSIDE the layer below's plan.
Condition 2 alone paints the whole underside of a larch shelf - a violet tree
with a gold lid; condition 1 alone paints every rim of every layer, which is
the "scattered through the crown" §2.5 forbids. Together they are the shelf
edge where it stands proud of what is under it.

**The detachment is emergent, and nothing imposes it.** A conifer tier's arms
are yawed a golden-angle step from the tier below, so the overhang ring is
INTERRUPTED wherever the tier below happens to have an arm of its own, and
what lands is arcs rather than a band.

### The larch A/B, judged from the species close-ups

§2.5 calls the larch "the warm accent among blue-greens; protect it", so the
risk was real and it was rendered both ways - `trees-4-larchA` (with slivers)
against `trees-4-larchB`. **A ships**, `ganymede, eye`: the sliver is the
drawn line under a shelf's lip, the ziggurat gets its edges back, and the gold
TOP faces - which is where the accent lives - are never touched. Without it
four to six shelves blur into the mauve the shade ink makes of the gold and
read as one mass.

### Cost, and the rule 6 test

A recolour, so block counts are identical in every row and only quad
boundaries move. `ganymede, deterministic`:

| | quads, before -> after |
| --- | --- |
| max spruce | 1,798 -> 1,849 (+51, +2.8%) |
| max larch | 1,471 -> 1,565 |
| conifer hero, t = 0 | 737 -> 795 |
| beech, birch, krummholz, snag, broadleaf heroes | unchanged, zero slivers |

Across the population sheets it is **34-41 quads per larch** - tens per tree,
about 3%, not hundreds, which is the test plan rule 6 sets for "coherent runs"
against "interleaving". Max larch is still 1,565 against Stage 0's 2,049.

**Nothing glows.** Dusk sheet at `--time 0.95`, `ganymede, deterministic`:
sliver pixels **mean luminance 5.6 against 12.2** for leaf, max 20.8 against
81.1.

### Gates

| gate | result |
| --- | --- |
| masks against the pre-stage baseline | **bit-identical in every number** - SYMMETRY 0.86 / 0.74 / 0.57, TWINS 0.72 / 0.64 / 0.43, all 21 pairs unchanged. The stage recoloured and never reshaped. |
| loose blocks | **0** across all seven species |
| dusk glow | **none**, 5.6 against 12.2 |
| heightmap / trees / spawn / mix | `76cccdb6` / 28,383 / (-44, -124) / unchanged to the decimal |
| self-tests | all passed |

---

## Stage 5 - The world

No code. The full judgement, all of it on ganymede.

### The tour, by eye - MET

`build/tour/trees-5/` against `build/tour/memo-baseline/`, `ganymede, eye`.
The plan set two acceptance frames and **both are met**:

- **the forest interior reads as trees rather than columns**
  (`7-forest-interior`, `3-forest-slope`);
- **`15-under-canopy` shows a closed roof** rather than sky between crowns.

A full 17-shot tour is at `build/tour/trees-5-full/` and `-full-gl/` for the
record.

### THE FAILED GATE: canopy closure

`ganymede, deterministic` - the closure probe, deterministic origins,
10 / 10 / 33 samples.

| | before | after | the design's target |
| --- | --- | --- | --- |
| old growth | 0.694 | **0.648** | >= 0.85 |
| grove | 0.523 | **0.481** | >= 0.60 |
| between groves | 0.373 | **0.354** | <= 0.20 |

**The plan's self-fail clause tripped.** This epic was allowed to move all
three numbers - crown shapes moved, so they must - and was to fail itself only
if closure got WORSE where the design said fuller. It did, on both: old growth
and grove are each about four to five hundredths down.

**The orchestrator's ruling, recorded as such: it ships as the epic's one
failed gate, under plan rule 1.** §2.5's spire proportion - max width one
third of height - narrowed old-growth spruce crowns by roughly **17% of radius,
which is about 30% of disc area**, and §2.5 outranks the closure number. The
visual acceptance frames improved at the same time, from the same change,
which is the shape of the trade: a spire reads as a tree from inside the wood
and a fat cone reads as a roof from directly beneath it.

**The reconciliation is stem DENSITY, not fatter trees.** More trunks at the
same proportion closes a canopy without contradicting §2.5; wider crowns
contradict it. Density is `grove_floor` and `old_growth_keep` - **placement,
which this epic's rules forbid it to touch** (plan rule 3, `tree_placement.gd`
read-only) - and it is exactly the open `TODO(marcel)` at
`WorldgenConfig.grove_floor`, which this number now feeds with a second
measurement taken under a different tree. **Marcel decides**; the command to
re-measure is in that comment.

### The stream probe, ABAB - GATE MET

`ganymede, ABAB median`. Three runs each against pre-epic `93b32bd`, run order
**ABABAB**, ports 25110-25115, A = the trees v1 tip, B = pre-epic.

| | A, trees v1 | B, pre-epic `93b32bd` |
| --- | --- | --- |
| built/s, out | **82.4** (77.2-85.0) | 80.0 (77.7-84.7) |
| built/s, back | **93.7** (82.6-94.1) | 86.0 (84.9-95.5) |
| holes | **0** in all three | **0** in all three |

**Each side's median sits inside the other side's range on both legs, so the
honest reading is "no measurable difference" and the gate is MET.** The only
frame over 33 ms across all six runs - 43.0 ms - was on the **pre-epic** side.
Holes 0 in all six runs, which is the hard rule.

### The far tier, untouched - confirmed entry for entry

Plan rule 7 and hard rule 3: `far_trees*.gd`, `far_tree_meshes.gd` and
`far_field*.gd` are distance v2's and were never opened. The impostor lines in
the tour logs are **bit-identical pre and post, entry for entry**. The near/far
silhouette drift this creates is carried forward below, not fixed here.

---

## The epic, in numbers

### Silhouette, Stage 0 -> final

`ganymede, deterministic`, mask sheets, which are bit-stable on this GPU.

| species | SYMMETRY | TWINS |
| --- | --- | --- |
| spruce | 0.81 -> **0.86** *(target not met)* | 1.00 -> **0.72** |
| beech | 0.93 -> **0.62** | 1.00 -> **0.70** |
| larch | 0.75 -> **0.74** | 0.94 -> **0.64** |
| krummholz | 0.99 -> **0.59** | 0.97 -> **0.78** |
| birch | 0.78 -> **0.55** | 0.99 -> **0.68** |
| snag | 0.21 -> **0.28** | 0.37 -> **0.22** |
| hero | 0.82 -> **0.57** | 0.44 -> **0.43** |

Targets were SYMMETRY <= 0.80 and TWINS <= 0.85. **TWINS is met on all seven.**
SYMMETRY is met on five; the spruce misses at 0.86 and is priced above; the
larch at 0.74 is a hundredth below its baseline and that baseline was noise
(Stage 0, trap 1). The snag's two numbers moved the "wrong" way and are the
one species where that is right: it was already the most irregular thing in
the file and the epic gave it structure rather than accident.

**Species pairs at t = 0.5:** the worst is spruce/larch, **0.66 -> 0.56**, and
**every other pair is <= 0.42**. The plan's line was 0.70 except for
spruce/larch, which it expected to report rather than force. It came in under
the line anyway.

### Cost, at the gallery's max specimen

`ganymede, deterministic`. Compare within a sheet, never across two.

| species | blocks | quads | rule 6 |
| --- | --- | --- | --- |
| spruce | 2,125 -> 1,997 | 1,580 -> 1,849 | +17%, **not in rule 6's list**, recorded |
| larch | 791 -> 1,697 | 2,049 -> **1,565** | **-24%, MET** |
| beech | 6,154 -> 3,563 | 1,897 -> **1,119** | -41% |
| birch | 588 -> 855 | 937 -> **527** | **-44%, MET** |
| krummholz | 274 -> 150 | 461 -> **160** | **-65%, MET** |
| snag | 16 -> 21 | 27 -> 47 | ~1.7x, inside the brief |
| hero | 28,255 -> 9,827 | 4,669 -> **2,403** | -65% blocks |

**Whole gallery sheet: 21,582 quads -> 15,608, with the second colour on.**
The three species rule 6 names all end the epic cheaper than they began, and
so do three more it does not.

### Connectivity

`ganymede, deterministic`, `scripts/tools/loose_check.gd`, 1,673 specimens per
species per sweep.

| species | found during the run | now |
| --- | --- | --- |
| spruce | 3,002 | **0** |
| larch | 18,548 | **0** |
| birch | 9,813 (whole bowed stems; edge-not-face bridges) | **0** |
| krummholz | 1,076 (pre-existing, `_draw_mound`'s lean) | **0** |
| beech, snag, hero | 0 | **0** |

The mechanism is a **flood from the axis**, applied per sparse layer (Stage 1),
per crown volume (Stage 2) and by construction through `_whorl_disc` (Stage 3).
It is a pure function of the tree's own params, so every chunk that draws the
tree computes the same set - which is why `_test_species_borders` still passes.
`_disc()` and `SALT_SPARSE` are retired: **no per-block hole is left in the
forest.**

## Gates, at the end of the epic

| gate | result |
| --- | --- |
| heightmap hash | **`76cccdb6`**, every stage |
| trees | **28,383**, every stage |
| spawn | **(-44, -124)**, every stage |
| species mix | unchanged to the decimal, every stage |
| `max_reach()` <= 28 | **28** |
| `max_height()` <= 129 | **129** |
| table heights, crown ranges | unchanged; the only table edit in the epic is the birch's `fill` |
| `REF_MAX_TREE_BLOCKS` | untouched |
| self-tests | **all passed**, tree borders 0 differed, species borders 0 wrong |
| `tree_placement.gd` | never opened |
| `far_*` files | never opened; impostor lines bit-identical pre/post |
| purity: no trig, no writer read-back, salts 217-299 | **held** |
| rule 6: no per-block colour noise, no per-block holes | **held, and `_disc()` retired** |
| rule 6: larch, birch, krummholz cheaper in quads | **MET**, -24% / -44% / -65% |
| TWINS <= 0.85, all seven species | **MET** |
| SYMMETRY <= 0.80 | met on five; **spruce NOT MET at 0.86**, priced against §2.5 |
| tour acceptance frames | **MET**, by eye |
| stream probe, ABAB | **MET**, medians overlap both legs, holes 0 in all six |
| **canopy closure** | **NOT MET** - 0.694 -> 0.648 and 0.523 -> 0.481. The epic's one failed gate. Ships under rule 1; see Stage 5. |

---

## Carried forward

Everything here is known and measured, not suspected. None of it blocks the
merge.

1. **Near/far impostor silhouette drift.** The far files are untouched by plan
   rule 7, and `far_trees_job` sizes an impostor from `params["crown"]`. The
   snag now reaches 6 blocks sideways against a table crown of 0, so at least
   one species' impostor is measurably narrower than the tree it stands in
   for. A far pass owns this; it is a table-vs-geometry question, not a bug.
2. **The mid-size broadleaf hero is envelope-bound.** Verbatim from Stage 3:
   at t = 0.5 the hero's 84 x 32 table leaves no room for three to five lobes
   to be separated ACROSS the crown, so the separation is vertical and the sky
   is above and below the lobes rather than between them. The fix is a wider
   hero crown range, which plan rule 4 forbids. The max-size hero reads as
   designed.
3. **A sliver on the SHADE side renders V10 against the real shade's V13** -
   three points darker rather than invisible. The trade is inherent: the
   lit-side read wants a low luminance and the shade path then darkens it
   again. The lit side is what the rule is about.
4. **The emergent purple shade-ink masses**, on larch shelves and birch
   trunks. Both species photograph warm or pale on the lit side and a
   desaturated purple-grey on the other; no code path draws two ids, it is
   look v2's shade ink and baked AO landing on the palette's brightest crown
   and its palest bark. **Judged acceptable in-world**, `ganymede, eye` -
   it reads as shade, not as a second species. Marcel may still want an ink
   look at the larch specifically, since §2.5 asks that the warm accent be
   protected.
5. **`params_for` discards the old-growth factor for the hero.** Pre-existing,
   not introduced here, and left alone because touching it moves what the
   world contains.
6. **The birch is 0.4% of the world - 103 trees on seed 42.** foliage v1
   flagged it at 1.1% and it has fallen since. This epic re-authored the
   species and may not touch where it grows (plan rule 3), so it is recorded:
   the prettiest thing in the file is nearly invisible in play, and it is a
   placement question.
7. **The tour's 5,400-frame chunk-wait budget should be a time budget.** Four
   of seventeen Vulkan vantages gave up waiting; the GL pass gave up on none.
   A frame count is the wrong unit for "the world has streamed in" on a box
   whose frame time varies.
8. **Two shots numbered 15.** `15-boulder` and `15-under-canopy` both exist in
   every tour directory. A naming collision, harmless until something sorts
   the set.
9. **`world_body.gd` `is_inside_tree` errors** in the tour logs. Physics,
   pre-existing, and absent from every probe run - recorded so the next person
   who greps a tour log does not re-diagnose it.
10. **Canopy closure is the design question and it is Marcel's.** See Stage 5.

### The `TODO(marcel)` items this run touches, and where they live

| where | what this epic added |
| --- | --- |
| `WorldgenConfig.grove_floor` (`scripts/world/worldgen_config.gd`) | a second closure measurement under a new tree shape: 0.648 / 0.481 / 0.354. The comment's argument is unchanged and its re-measure command still applies. `old_growth_keep` is the other half of the same lever. |
| `scripts/world/flora/tree_placement.gd` - glades, and the species blend | untouched by rule 3, but item 6 above (birch at 0.4%) is a question for whoever opens the second of these. |

## What the next plan gets from this run

- `scripts/tools/loose_check.gd` - a floating-block sweep any voxel model can
  be run through, 1,673 specimens per species in one command. It caught real
  bugs in three of four shape stages.
- `model_gallery.gd`'s `--vary`, `--stand` and `--masks`, and a cost line that
  prints real `ChunkMesher` quads. SYMMETRY / TWINS / the pair matrix are the
  same numbers `character_gallery.gd` prints, from the same ported code.
- The **flood-from-the-axis** discipline: build the candidate set, flood it
  from something that is by definition attached, write only what the flood
  reached. Pure in the model's own params, so two machines agree. It is the
  general answer to "did this subtraction sever anything", and there is no
  local test that answers it.
- **An authored dark colour does not land where it was authored.** The sun's
  channel gains are (0.72, 0.54, 0.38) at noon; blue arrives at 53% of red.
  Author the transform backwards or photograph what you get. `block.gd` says
  so beside `LEAVES_SLIVER`.
