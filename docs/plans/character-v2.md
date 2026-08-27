# Character v2 - what the people should look like

The **design** doc for the character redesign. What the four races should look
like, what the armour system should be, what the animation set should be, and
what voxel grid all of that is drawn on. It is opinionated on purpose.

It is not a build plan. The staged plan is `docs/plans/character-v2-tech.md`,
written in a later run; the last section here is the list of things that plan
has to reckon with, not the plan itself.

Written 2026-08-27 on `feat/character-v2`, against `b346c4a`. Nothing under
`scripts/` was touched by the run that produced it.

---

## How this doc was arrived at

Two things happened before a word of it was written, and both matter.

**1. The models were re-shot on a real GPU.** Ganymede acquired a working
Vulkan ICD an hour before this run started; Godot now reports
`Vulkan 1.4.329 - Forward+ - NVIDIA GeForce RTX 3070 Ti` under the existing
`xvfb-run` invocation, where every previous character run was drawing on Mesa
llvmpipe in Compatibility. So the baseline was re-shot:

```bash
xvfb-run -a godot --path . scenes/character/gallery.tscn -- --label v2-baseline
# 53 images -> build/character/v2-baseline/
```

Every claim in the diagnosis below is something visible in those images. This
is the first time anyone has looked at these characters on the renderer the
game ships on.

**2. Three research lanes ran in parallel** - one on voxel character design and
silhouette, one on animation sets for procedural rigid-part rigs, one on armour
as a visual system. Their findings are folded in where they survived contact
with the codebase and argued with where they did not. See **The research lane**
near the end, including the one that produced nothing.

---

## The diagnosis: three failures, and none of them is resolution

Open `build/character/v2-baseline/closeup-three-quarter.png` and
`closeup-front.png`. Four races, four metres, Forward+, noon.

### Failure 1 - the entire cast is wearing the same black shirt

This is the first thing you see and it is the worst thing in the build.

Look v2 Stage 5 imposed a rule: for every skin a player can pick, the tunic must
sit at or below half that skin's luminance. The rule was applied correctly. Here
is what it produced:

| race | tunic | Y | ratio to its darkest skin |
| --- | --- | --- | --- |
| human | `#262119` | 0.0157 | 0.47 |
| elf | `#465C44` | 0.0937 | 0.47 |
| dwarf | `#34271C` | 0.0226 | 0.48 |
| lizardfolk | `#302A1F` | 0.0238 | 0.48 |

Four hues, and all four land under Y = 0.10. Grass is Y = 0.221. Against that
ground every one of them is a black rectangle. The elf's tunic is nominally
green and is six times the human's luminance, and on screen you cannot tell.

The rule was not wrong about contrast. It was wrong about **which pair has to
carry the contrast**. It made cloth separate from skin *directly*, and since
each race's five skins span most of the luminance range - the human's from 0.033
to 0.632 - the only value that clears all five is one below the darkest. Four
races solved the same constraint and arrived at the same colour. The constraint
had exactly one solution and it was black.

**The fix is structural, and it is the single highest-value decision in this
doc: put a fixed dark liner between skin and cloth.** One or two voxels of a
constant near-black at every boundary where skin meets cloth - collar, cuff,
waist, boot top. Call the slot `LINER`, fix it at `#14100C` (Y = 0.0055) for
every race and every palette, and never let it be a player pick.

Then the contrast pair that must hold is **skin ↔ liner**, and it holds by
construction:

| skin | Y | ratio to liner |
| --- | --- | --- |
| `#F5E3D3` lightest elf | 0.7905 | 145× |
| `#F1C9A5` lightest human | 0.6319 | 116× |
| `#6F7F73` cool elf | 0.1980 | 36× |
| `#5A3420` dark dwarf | 0.0473 | 8.7× |
| `#4A2C17` darkest human | 0.0332 | **6.1×** |

Worst case 6.1:1, against the 2.1:1 that the old rule scraped. And the tunic is
now free. Any hue, any value above about Y = 0.03, because it is no longer the
thing doing the separating. This is how comic inking works and it is why an
inked figure can wear any colour without dissolving.

That one change is what lets the rest of this document have a palette.

### Failure 2 - nothing breaks the outline

Fill any of the four with black. You get a rectangle on two rectangles. The
elf's ears and the lizardfolk's crest are the entire outline budget for the
whole cast. There is no pauldron, no cloak, no belt hanging past the hip, no
strap, no asymmetry anywhere on any of them.

The measured consequence is in `docs/status/character-v1.md`, and this run
reproduced it on the GPU: front-on, human vs lizardfolk is **0.868 IoU**, and
across every hair and beard option the worst pair is **0.928**. Fifteen of the
94 cross-race variant pairs are over the 0.70 target and every one of them is
that pair.

The status doc is honest about why - the lizardfolk's body *is* the human's
body, same torso, same legs, deliberately, so the test could tell which feature
was doing the work. Fine as an experiment. It is now the thing to fix. Put the
two ratios side by side:

| race | shoulder width ÷ height | head ÷ height |
| --- | --- | --- |
| human | 0.313 | 0.344 |
| elf | 0.167 | 0.306 |
| dwarf | 0.542 | 0.417 |
| **lizardfolk** | **0.333** | 0.300 |

The lizardfolk is a *wider-shouldered* human. Of course the masks agree. No
crest fixes a number dominated by an identical torso and identical legs.

### Failure 3 - one segment per limb, so the walk is a scissor

Open `anim-human-walk.png`. Eight frozen phases of one cycle. The legs swing
from the hip as rigid poles, the arms barely move, the torso does not
counter-rotate, and there is no knee and no elbow anywhere in the rig.

This is the deepest of the three, because a rigid single-segment limb has
exactly one expressive degree of freedom - its angle. Every technique that
makes a walk read as weight rather than as machinery needs a second: the knee
bending through swing, the foot rolling heel to toe, the contact pose where the
front leg is straight and the back leg is bent, the compression on landing.
None of them exist without a joint, and none of them can be faked by animating
the one angle harder.

`rig.gd` is already the right shape for this - bones are plain `Node3D`s, poses
are dictionaries of offsets from rest, and a new bone cannot break an old pose.
Adding a knee and an elbow is four bones and a pose rewrite, not a rewrite of
the system.

### What the diagnosis means

**The current characters are not short of voxels. They are short of colour,
outline and joints.** At 64 voxels they already carry a face with a two-by-two
iris and a one-row brow, and you can see it at four metres. If you doubled the
grid today and re-authored every part at the same design, you would get a
higher-resolution version of exactly the same four black rectangles.

So resolution is the *enabler* in this epic, not the fix. Which is convenient,
because it means the resolution decision can be made on its own merits rather
than being asked to rescue the look.

---

## The resolution decision

**Recommendation: raise the human from 64 to 96 voxels. One model voxel becomes
1/24 of a block, 2.083 cm. Do not go to 128.**

Here is the argument, and it is arithmetic before it is taste.

### What the screen can actually resolve

The game runs a 75 degree vertical FOV. A 2.00 m character at distance *d*
occupies `1080 × 2.0 / (2d × tan 37.5°)` pixels at 1080p:

| distance | px @1080p | px @1440p | px per voxel @64 | @96 | @128 |
| --- | --- | --- | --- | --- | --- |
| 2 m (creation screen) | 704 | 938 | 11.0 | 7.3 | 5.5 |
| 3 m (campfire) | 469 | 626 | 7.3 | 4.9 | 3.7 |
| 5 m | 281 | 375 | 4.4 | 2.9 | 2.2 |
| 10 m | 141 | 188 | 2.2 | 1.5 | 1.1 |
| **15 m** | **94** | **125** | **1.5** | **0.98** | **0.73** |
| 25 m | 56 | 75 | 0.9 | 0.6 | 0.4 |
| 40 m | 35 | 47 | 0.6 | 0.4 | 0.3 |

Read the 15 m row. At the far edge of the band the game is actually played in,
**one voxel on the current grid is already only 1.5 px**. At 96 it is 0.98 px -
right at the limit, still a pixel, still capable of being a thing you can see.
At 128 it is 0.73 px, which is below the sampling limit: that detail does not
render, it *aliases*, and every frame of movement makes it shimmer.

128 is not "more detail at gameplay distance". It is detail the monitor cannot
show, that costs four times the triangles to carry, and that actively makes the
image noisier when the character moves. I am declining it and this is why.

### What 96 buys that 64 does not

Three concrete things, in order of importance:

1. **A leg that can have a knee.** The human's legs are 16 voxels today. Split
   that and each segment is 8 voxels - a limb whose joint is half its own
   thickness. At 96 the legs are 24, and 12/12 thigh and shin with a 2-voxel
   joint gap is a joint you can see bend. Same for the arm: 20 → 30, 15/15.
   This is the reason to raise the grid. Everything else is a bonus.

2. **Three layers that read as three layers.** The armour system below stacks
   an under-layer, a hard layer and a soft over-layer. Each needs at least 2
   voxels of its own to survive the baked AO at its edges - so 6 voxels of
   stack. The human's torso is 11 voxels deep today; 6 of that is 55% of the
   body and the character becomes a barrel. At 96 the torso is ~17 deep and 6 is
   35%, which is what a person in armour actually looks like.

3. **A stack that divides by three.** The whole proportion scheme is thirds -
   "head about a third of the height" is the Cube World read look v1 settled on.
   64 does not divide by 3, which is why `races.gd` says head 22 and carries a
   rounding error into every part. 96 does: head 32, and every race's height
   lands on an integer too (elf 108 = 2.25 m, dwarf 72 = 1.50 m, lizardfolk 90
   = 1.875 m). Small thing; it removes a class of off-by-one from every
   generator.

### What it costs, from measured numbers

The GPU baseline measured the worst character at **17,788 triangles** (stocky
dwarf, with hair and mandatory beard). Triangles scale as surface area, voxels
as volume:

| height | triangles | ×  | voxels × | retained ~MB/char | 4 players |
| --- | --- | --- | --- | --- | --- |
| 64 (now) | 17,788 | 1.00 | 1.00 | 0.53 | 2.1 MB |
| 80 | ~27,800 | 1.56 | 1.95 | 1.03 | 4.1 MB |
| **96** | **~40,000** | **2.25** | **3.38** | **1.78** | **7.1 MB** |
| 128 | ~71,200 | 4.00 | 8.00 | 4.21 | 16.8 MB |

The retained-memory column is the one nobody has looked at. `rig.gd` keeps
`{"voxels": Array, "anchor": Vector3}` per bone after meshing, because the gear
overlap check has to ask "is there a voxel here" and a mesh cannot answer. Each
voxel is a `Vector4i` in a GDScript `Array`, so ~24 bytes of Variant each, and
the worst character carries roughly 23,000 of them. That is half a megabyte per
character today and 1.8 MB at 96. Tolerable. At 128 it is 4.2 MB per character
and 17 MB for a full party before a single creature exists, for detail the
screen cannot render. Another reason 128 is the wrong answer.

Triangles are not the constraint on either box. 40,000 × 4 players × 2 for the
shadow pass is 320,000 triangles, which is nothing on a 3070 Ti and less than
nothing on Marcel's 5080. The budget constant just has to move from 24,000 to
about 48,000 and be **re-measured, not predicted**.

### The escape hatch, and the requirement that creates

Every part in the game is generated: `tools/parts_author/` is 1,887 lines of
Python that emits the ASCII in `scripts/character/parts/`. Nothing is drawn by
hand. That is the single most important fact about this decision, because it
means **the resolution is a number in a generator, not four thousand lines of
handiwork.**

So the design requirement is: **the generators take the grid as a parameter.**
`voxlib.py` gets a resolution constant, every dimension in every generator is
expressed as a fraction of the race's height rather than as a literal, and
re-authoring at a different grid is a re-run rather than a rewrite.

Do that and the 96-vs-128 call stops being irreversible. If the poster shots at
96 look thin next to what Marcel wants, moving is one constant and one
`python -m tools.parts_author`. If they look right, we saved 2× the triangles
and 2.4× the memory. There is no version of this where parameterising the
generators is the wrong move, and it is worth a stage of its own.

---

## The common language

Before the races: the rules all four obey. A cast reads as one cast because of
what it shares, not what it varies.

### Proportion - stocky, and the exaggeration is at the extremities

Look v1 settled this and it survives review: head about a third of the height,
big hands, big boots, no neck except the elf's. The research lane's instinct
was to reach for "heroic = 7-8 heads tall", and that is advice for a medium
that can carry a face at 1/8 of the frame. At 94 px tall a 1/8 head is 12 px.
Ours is 32 px and has eyes in it. **Keep the stocky read; it is correct for the
distance the game is played at.**

What the stocky read is missing is not proportion, it is *exaggeration at the
extremities* - the Warhammer trick of oversizing head, hands and weapon while
keeping the frame compact. Hands and boots go up another 15% at 96. It costs
nothing and it is what stops "stocky" from reading as "doll".

### Value structure - every race needs a span

Grass is Y = 0.221. Dusk sky is roughly Y = 0.03 to 0.08. A character that is
entirely mid-value dissolves into the meadow; a character that is entirely dark
dissolves into dusk. The current cast is entirely dark, which is why it is
*visible* at both times of day and *identifiable* at neither.

So: **every race's palette must span at least three value tiers**, and it must
place them in the same structural places so the cast reads as one family:

| tier | Y band | where it goes |
| --- | --- | --- |
| liner | 0.005 - 0.012 | every skin/cloth boundary, part seams, boot tops, the inside of the mouth |
| deep | 0.03 - 0.09 | legs, the lower half generally, under-layer, shadowed cloth |
| mid | 0.15 - 0.30 | the torso mass - the race's main hue lives here |
| light | 0.45 - 0.70 | one element only: hair, a collar, a beard, a belly |
| accent | any | saturated, **under 10% of silhouette area**, the race's identity colour |

The "light" tier is doing a specific job: it is the element that stays visible
when the whole figure has gone to silhouette at dusk. The elf's white hair is
already doing this by accident in `silhouettes-15.png` and it is the only thing
in the shot that works. Make it deliberate for all four.

The accent tier is the identity colour and it must be small. A saturated colour
covering 40% of a character reads as a costume; covering 8% it reads as a
choice someone made.

### Material in flat colour - and a correction to the received wisdom

The armour research came back recommending the miniature painter's
non-metallic-metal technique: paint the top and right faces of each plate bright
and the bottom and left dark, to fake a curved reflective surface.

**Do not do that here, and the reason is in the mesher.** `voxel_model.gd` bakes
corner ambient occlusion into vertex colour with the same rule as `ChunkMesher`
- each vertex darkened by how many of its three diagonal neighbours are solid.
The form is *already* being shaded by geometry. Painting a second, hand-authored
shading on top double-darkens every concave corner and produces mud, and it
fights the one rule that makes characters look like they belong on the terrain.

The correct rule for a mesher that bakes its own AO:

> **A material is one base value plus a hue and a saturation. Form comes from
> the AO. Contrast comes from putting two materials next to each other, not
> from shading one of them.**

Metal looks like metal because a *bright rim slot* sits beside a *dark body
slot* across a real geometric edge - a raised trim voxel with a liner voxel
under it. That is two slots and one voxel of relief, and it reads at 10 m
because it is an actual edge that the AO actually darkens.

The material table, on that rule:

| material | hue | base Y | saturation | the tell |
| --- | --- | --- | --- | --- |
| steel | cool neutral, 210° | 0.22 | 3-6% | bright rim slot at Y 0.50 over liner |
| iron | cool neutral, 220° | 0.10 | 5% | no rim; matte, one value, dull |
| bronze | warm 35° | 0.23 | 35% | rim slot warm at Y 0.48 |
| gold | warm 45° | 0.42 | 65% | rim at Y 0.75; **only** above tier 4 |
| leather | warm 20° | 0.09 | 35% | 1-voxel stitch line in liner along every edge |
| cloth | any | 0.15-0.30 | 25-50% | no rim at all - that absence is what reads as soft |
| fur | warm 25° | 0.14 | 45% | silhouette is ragged by ±1 voxel; nothing else is |
| bone | warm 45° | 0.55 | 8% | light tier, always; the only thing brighter than skin |
| chitin / scale | cool 150-190° | 0.11 | 20% | 1-voxel checker of two adjacent values |
| obsidian | cool 275° | 0.03 | 40% | stays dark even lit; no rim, ever |

The 1-voxel checker for scale is the one place a value pattern is right, and it
is right because of what it does at *both* distances: at 5 m you see individual
scales; at 15 m the checker averages to a flat mid-tone, which is exactly what
mail and scale look like from across a field. Free LOD.

---

## The four races

Each gets: the silhouette rule that names it at 15 m, the proportions, the
signature features, the colour and material language, and the cliché it is
forbidden from being.

The organising principle: **one big idea each, and no two races may express
their idea in the same axis.** The human owns diagonal, the elf owns vertical,
the dwarf owns horizontal mass, the lizardfolk owns the low line. If two races
compete on the same axis you get the human/lizardfolk problem again.

### Human - the outfitted one

**The cliché to avoid:** human as the beige default, the race with no design
because it is the baseline the others are measured against. Every version of
this game so far has a human that is a shape with nothing on it.

**The one big idea:** the human is the only race whose look is *acquired*.
Nothing a human wears was made for a human body - it was made, traded for and
adjusted. So the human's signature is straps: a baldric from the left shoulder
to the right hip, a belt that hangs past the hip on one side, a bedroll lashed
across the back.

**The silhouette rule at 15 m: the diagonal.** No other race in the game has a
diagonal anywhere on it. It is a handful of voxels across the biggest flat
surface the character has, it is asymmetric for free, and it breaks the torso
rectangle at the exact point where a rectangle is least forgiving. It survives
every armour tier, because a strap goes *over* armour.

**Proportions.** The reference, at 96: total 96, legs 24, pelvis 8, torso 30,
head 32. Shoulder ÷ height 0.31. Hands and boots at the exaggerated size.

**Signature features.** The baldric. A hood that lives *down*, bunched at the
back of the neck as a lump that raises the shoulder line by 3 voxels - the
cheapest way to say "traveller" ever invented. Rolled sleeves, so the forearm is
skin and the upper arm is cloth, which puts a liner ring at the elbow exactly
where the new joint is and makes the joint legible.

**Colour and material.** Cool neutral cloth - slate `#4C5566` (Y 0.090) deep,
`#6E7A8C` (Y 0.191) mid - with warm leather and one ochre accent `#B98A34`
(Y 0.287) on the strap and the belt. The human is the only race whose accent is
on a *worn object* rather than on its body, which is the design idea restated as
a palette. Light tier is hair or a bleached linen collar.

The human is the mid-tone the other three are read against. That is a job, not
an absence of one.

### Elf - the vertical

**The cliché to avoid:** pale, willowy, green-robed, nature-mother, and the
lazy conflation of "graceful" with "feminine". Also: the elf is currently a
grey-lavender corpse in `closeup-front.png` with a slab of hair on the side of
its head. Kubik's elf should be **severe**, not pretty.

**The one big idea:** the elf reads as taller than it is because every element
on it is vertical. Not "tall" - the dwarf is short and nobody mistakes it for a
child. *Vertical.*

**The silhouette rule at 15 m: the column.** Shoulder ÷ height 0.17, the
narrowest in the game by a factor of three against the dwarf. And - this is the
part that is new - **a high standing collar that raises the shoulder line by 4
voxels**, so the head appears to emerge from a shaft rather than to sit on a
pair of shoulders.

Why the collar and not the ears: **the ears do not survive a helmet.** The elf's
ears are its only current differentiator and the moment armour v2 puts a helm on
it, the elf becomes a narrow human. The collar is torso, the collar is under the
helm, the collar is always there. Ears stay, swept back and *up* in the plane of
the collar so that at 15 m ear plus collar reads as one continuous vertical fin;
but the identity is carried by the thing that cannot be taken off.

**Proportions.** Total 108 (2.25 m), legs 36, pelvis 10, torso 30, neck 4, head
28. The elf keeps its neck - it is the only race with one and it is worth four
voxels of height.

**Signature features.** The collar. Ears. Long hair that is *narrow* - a single
column down the spine, never the side-of-head slab currently in the build, which
widens the one race whose whole idea is narrowness. Trousers and sleeves that
taper: 8 voxels at the shoulder to 5 at the wrist, which is only possible at 96.

**Colour and material.** Desaturated cool - pewter `#3E4550` (Y 0.059) deep,
`#7C8794` (Y 0.238) mid, bone `#D8D2C2` (Y 0.646) light. The accent is a cold
violet `#8C6FB0` (Y 0.201), and it is **never green**. Green is the cliché and
the current build is wearing it.

**Material rule, elf-specific:** the elf wears cloth *over* hard, not hard over
cloth. Its plate lives under a wrap, so the outline stays soft and the value
stays hard. That is one sentence and it makes elven armour a distinct thing
without a single extra slot.

### Dwarf - the mass

**The cliché to avoid:** Scottish drunk, mandatory identical beard, everything
brown. The current dwarf is brown on brown with a red brick glued to its face.

**The one big idea:** the dwarf is the only race **wider than the space it
occupies**. It fills a doorway. It is not a short human; a short human is a
child, and no part of the dwarf may read as one.

**The silhouette rule at 15 m: two stacked trapezoids, head recessed.** Shoulder
÷ height 0.54. And the beard is a *second* wide shape hanging below the first,
so from 15 m the dwarf is a wide block, a wide block, and legs - with the head
sitting *inside* the shoulder line rather than above it. That last part is the
whole trick. A head that pokes above the shoulders reads as a person; a head set
between them reads as mass.

**Proportions.** Total 72 (1.50 m), legs 16, pelvis 0, torso 26, head 30.
Shoulder width 39 voxels - wider than the head is tall. No neck, by
construction.

**Signature features.** The beard, which is not decoration but **structure**: it
is the lower trapezoid and it is load-bearing on the silhouette. Beard rings are
the dwarf's tier signal - one at tier 1, three by tier 4, and at tier 3+ the
beard plaits *into* the gorget so the armour and the body are the same shape.
Boots so heavy the ankle disappears. A tool on the belt, always, on the same
side.

**Colour and material.** The dwarf owns saturation. It is the only race allowed
a fully saturated primary at tier 1 - madder `#7A2320` (Y 0.054) deep and
`#A83A2E` (Y 0.116) mid - and the only race that wears metal before tier 3, as a
bronze belt plate `#B07A2A` (Y 0.233). Light tier is the beard at `#D9C08A`
(Y 0.543) or its hair.

**The rule the current build breaks:** the beard must never share a value tier
with the tunic. It is the second-highest-contrast element on the character after
the eyes, and right now it is a mid-red on a near-black shirt, which is one
smudge. Beard and tunic must be at least two tiers apart, always.

### Lizardfolk - the low line

This is the race that needs the most work and I am going to be blunt about why:
**it is currently a human with a tail and a snout, and the silhouette metric has
been telling us so for three passes.** 0.868 front-on, 0.928 worst variant. The
status doc offered three ways forward and left the call open. It is option 2 -
give the lizardfolk its own body - because options 1 and 3 are both "change what
we measure" and the thing that is wrong is the model. **Settled by Marcel on
2026-08-27**; see the settled decisions section.

**The cliché to avoid:** green, hunched, savage, bestial, low-intelligence-coded
posture. And separately: the "human in a lizard suit", which is the actual
failure state we are in.

**The one big idea:** the lizardfolk is the only race whose **centre of mass is
not over its feet**. Digitigrade legs - ankle raised, a real backward-facing
hock - a torso carried forward and low, and a tail that arcs down and back as a
counterweight rather than sticking out sideways like a plank, which is what it
does today.

**The silhouette rule at 15 m: the horizontal S.** Head low and forward, spine
sloping *up* from neck to hips, tail sloping down and back. Through the middle
of the body it should be the only race in the game wider than it is tall. The
read moves from "person" to "runner", and no mask that sees it can confuse it
with a human.

Shoulder ÷ height drops from 0.333 to **0.24**, which is the numeric statement
of the fix: it is now the only race in the gap between the elf's 0.17 and the
human's 0.31, instead of sitting on top of the human.

**Proportions.** Total 90 (1.875 m) measured along the body, standing height
lower because of the lean. Legs 30 across three segments (thigh / shin / long
foot), pelvis 6, torso 30, head 24. Forward lean 18°, up from the current 8°,
carried in the hips rest pose. Tail 42 voxels over four chain links, arcing.

**Signature features.** Digitigrade legs - this is the expensive one and it is
where the resolution raise pays for itself, because a three-segment leg at 30
voxels gives 10 per segment and at the old grid it would have given 5. A **short
broad snout**, not a long one: a long snout at 15 m is a smudge, whereas a blunt
head with a heavy brow ridge and a jaw wider than the skull reads as reptile at
any distance. A dorsal ridge from the base of the skull to the tail, which is
the profile feature that survives every helmet. The crest stays.

**Colour and material.** **Not green.** The lizardfolk takes the game's warm
exotic register - ochre `#7A5A26` (Y 0.116) and `#B98A3A` (Y 0.288), oxblood
`#6B2620` (Y 0.046) for the hard parts - with a single cold accent `#9FB8C4`
(Y 0.456) on the crest and the throat.

And the cheapest thing in this entire document: **countershading.** Dark dorsal,
light ventral - a light belly, throat and underside of the tail. It costs zero
extra voxels because it is a palette split of a slot that already exists, and it
is the single strongest signal that a thing is an animal rather than a person in
a costume. Every real animal has it and no fantasy game bothers.

---

## The armour system

### Why this design

The pillar it serves is **tense out, cozy in the light**: "your character
sitting at the campfire *is* the progress screen" (`docs/DESIGN.md`, Gear). That
sentence is a specification. It says progression must be legible on the body, at
campfire distance, without a menu - and it says the payoff moment is a *look at
each other*, which is why armour is a character-design problem and not an
inventory problem.

`DESIGN.md` currently says three visible slots: weapon, torso armour, trinket.
This doc proposes six, and argues the order.

### The governing rule

> **With flat vertex colour and no textures, surface detail is free to author
> and invisible at range. The outline is the only currency. Therefore: armour
> tiers are a ladder of outline events, not a ladder of surface decoration.**

An "outline event" is anywhere the silhouette's width profile has a local
maximum that the naked body does not have - a pauldron past the arm line, a
gorget raising the shoulder, faulds flaring below the belt, a crest above the
head, a cloak behind the legs. It is a countable thing, which means it is
testable, which matters: `docs/status/character-v1.md` records that counts
survive measurement noise and frame times do not, and this whole system can be
gated on a count.

### The slots

| # | slot | share of silhouette | why it is here |
| --- | --- | --- | --- |
| 1 | **torso** (chest + back) | ~38% | the largest surface; carries the race's main hue and every layer |
| 2 | **shoulders** | ~12% | the only slot that grows the outline *outward at the widest point*. Best silhouette per voxel in the game |
| 3 | **back** (cloak / pack / quiver) | ~15% | reads at 40 m, carries motion, and is the cheapest "expensive" signal there is |
| 4 | **head** (helm / hood / circlet) | ~20% | second-most-looked-at, and the slot that fights race identity hardest, so it needs rules |
| 5 | **legs** (greaves + boots) | ~15% | lowest return - often occluded by grass and by the character's own faulds |
| 6 | **hands** (weapon + offhand) | — | sockets already exist from character v1 Stage 10 |

**If only four ship: torso, shoulders, back, head.** That is 85% of the outline
budget and it is the set where every piece changes the black shape. Legs go last
and that is not a slight - it is that a greave at 15 m is nine pixels behind a
tuft of grass.

**The head slot needs a rule, because it is where race identity goes to die.**
A full helm erases the elf's ears, the dwarf's beard line and the lizardfolk's
snout in one item. The rule: **every head item is authored per-race in the same
way its wearer's head is, and each must leave its race's identity feature
intact or replace it in kind.** The elf's helm is open at the sides or the ears
pass through it. The dwarf's helm has the beard emerging below and gets *horns*
because the dwarf's silhouette can afford width above the shoulders where
nobody else's can. The lizardfolk's helm sits behind the brow ridge and never
covers the snout. The human's helm can be anything, because the human's
identity is on its chest.

### The tier ladder

Five tiers. The ladder is outline events, and everything else follows.

| tier | outline events | material | colour | asymmetry | reads as |
| --- | --- | --- | --- | --- | --- |
| **1** cloth | **0** | cloth only | race's deep + mid, no accent | none | what you start in |
| **2** hide | **1** — a shoulder cap | leather over cloth | + warm leather, accent appears | one strap | you killed something |
| **3** mail / scale | **1** — a raised collar | 1-voxel checker over cloth | + iron, matte, one value | strap + one pouch | someone made this for money |
| **4** plate | **3** — pauldrons past the arm line, gorget +2 at the shoulder, faulds below the belt | steel with bright rim slots | + steel; value spread widens hard | one pauldron larger | someone made this for *you* |
| **5** named | **5** — the three above, plus a cloak and one vertical element above the head | steel + a second metal | + gold rim, and one emissive accent of 4-12 voxels | deliberate: one big pauldron, one bare arm | you did something |

Notes on the ladder that are not obvious:

- **Tier 1 has zero outline events on purpose.** If starting gear changes the
  silhouette then the naked character is not the design, the starting gear is.
  The four races have to be identifiable in nothing.
- **Tier 3's checker is the free-LOD trick from the material table.** Mail is
  the one tier that does nothing to the outline and everything to the surface,
  and that is correct: mail's whole character is that it *drapes*, which is the
  absence of an outline event. Tier 3 is where a player learns that armour is
  not monotonically bigger.
- **The emissive accent at tier 5 is capped at 12 voxels.** Foliage v1 already
  put emissive voxels in the game (fireflies, glowing mushrooms) so the
  machinery exists. Twelve voxels is a rune band on one pauldron. It is not a
  glowing character, and a glowing character is what every game does wrong.
- **Verticality above the head is reserved for tier 5** on three races. The
  dwarf gets it at tier 4, because the dwarf is the race whose silhouette has
  the width to carry horns without becoming ambiguous.

### What actually makes armour look expensive

Ranked by value per voxel authored, for this renderer:

1. **A cloak.** 40-60 voxels, adds 30-50% to the visual mass, is the only thing
   on the character that can move independently, and hides bad leg geometry. It
   is the best purchase in the game and it should arrive early.
2. **Asymmetry.** Free. Symmetric armour reads as issued; asymmetric reads as
   assembled by someone who lived through things. One pauldron bigger than the
   other, a cloak over one shoulder, a pouch on one hip.
3. **Layering visible at the edges.** Not a modelled under-suit - a 1-2 voxel
   band of the under-layer colour showing where the hard layer stops. Same
   mechanism as the liner rule, same reason it works.
4. **Trim.** A 1-voxel raised rim in a bright slot along plate edges. Raised, so
   the AO catches it. This is the whole difference between steel and steel that
   cost something.
5. **Dangling elements.** Tassets, a chain, a trophy. High authoring cost, but
   they are the only things that make an armoured character look like it has
   *inertia* when it moves.
6. **Heraldry.** A 6×6 block of a contrasting hue on the chest. Cheap, reads at
   15 m, and in a four-player co-op game it is how you find your friends.

### Cross-race fitting

One armour idea worn by a 39-voxel-wide dwarf, a 18-voxel-wide elf and a
forward-leaning lizardfolk with a tail. The research surveyed four approaches;
the two extremes are both wrong here. Per-race remodelling (WoW) is 4× the
authoring for four races. A single scaled mesh puts a dwarf breastplate on an
elf and it looks like a barrel.

**The rule: proportions are relative, thicknesses are absolute.**

An armour piece is authored once in a **normalised slot frame** - 0..1 across
the attachment's width, height and depth - and stamped into the race's actual
dimensions by the generator. So the pauldron's *shape* is the same fraction of
every shoulder, but its plate is 3 voxels thick on every race, because 3 voxels
is what plate looks like.

Get that backwards - scale the thickness too - and dwarf armour looks like foam
rubber while elf armour looks like it was cut from sheet tin. This is the single
rule that makes one authored set work across four bodies, and it is exactly the
distinction `parts_gear.gd` already learned the hard way with the placeholder
sword.

Per-race trim colour on top of that is free: the same set reads as dwarven in
bronze, elven in pewter, human in brass.

**The lizardfolk needs two exceptions and they should be named now**: leg armour
does not fit a digitigrade leg, and a back slot has to route around a dorsal
ridge and a tail. Both are per-race variants of two pieces, not a per-race
system.

---

## The animation set

### Why this design

Marcel asked for "well animated" and a large set. The thing that makes a large
set worth having in a co-op game is specific: **players look at each other.**
Two-to-four people spend hours in each other's field of view, and animation is
the only channel through which a character has a personality when nobody is
talking. That is pillar 1 doing its job.

The set below is prioritised, and the priority is not "what is easy" - it is
"what does a second player read from ten metres away".

### The prerequisite: two-segment limbs

Before any of it: **the rig gets a knee and an elbow.** This is the single
change that makes the rest possible, and it is the reason for the resolution
raise.

`rig.gd`'s bone table goes from 7 bones + sockets to 11 + sockets (`leg_upper`,
`leg_lower` ×2, `arm_upper`, `arm_lower` ×2), the lizardfolk gets a third leg
segment for the hock, and `Animator.pose_for()` - already a pure function
returning a dictionary of offsets from rest - gains entries. Nothing about the
architecture resists this; it was built for it.

### Tier A - build these, in this order

| animation | what it must communicate at 10 m | the detail that makes it read |
| --- | --- | --- |
| **idle** | alive, alert, not paused | a slow weight shift between feet every 4-7 s, and breathing at 2 voxels of chest rise. Nothing else |
| **walk** | unhurried travel, weight on the ground | the **contact pose**: front leg straight, back leg bent, both feet down for one frame. It is the pose everyone skips and the one that makes a walk a walk |
| **run** | urgency, and that stopping will take a moment | forward torso lean that *leads* the acceleration, and both feet off the ground at the top of the cycle |
| **sprint** | commitment; you gave something up for this | arm swing crosses the body's centre line. Nothing else in the game does that |
| **jump** | committed airtime, a decision made | anticipation - 3 frames of crouch before launch - and the **hold at the apex**, ~40 ms where nothing moves |
| **fall** | this was not the plan | arms rise, legs trail. The opposite of the jump pose, so the two never blur |
| **land** | weight arrived | compression: hips drop 5% of height, recover over 250 ms with one small overshoot. Already in the build as `land_squash_vox`; it needs the overshoot |
| **turn in place** | I am choosing a direction | feet actually re-plant. A body that rotates without its feet moving is the single most common giveaway of a cheap rig |

### Tier B - the traversal and interaction set

| animation | what it must communicate |
| --- | --- |
| **crouch / crawl** | I am being careful; and a smaller silhouette |
| **climb** | effort - fast arms over slow legs is the whole read |
| **wade / swim** | the world is doing something to me |
| **carry** | encumbered: an additive layer, not a new cycle. Stride to 80%, one arm locked |
| **place object** | a deliberate lean-in and a return. The campfire needs this |
| **interact / harvest** | a short repeated arc with a hold at the end of each |
| **sit** | safety. Already exists; needs the settle |
| **downed** | trouble, and *visible from far away* - this is a call for help and it must read at 40 m |
| **revive** | two bodies in a shared geometry. In a co-op game this is the money shot |

### Tier C - combat, when combat exists

Light attack, heavy attack, block, hit reaction (directional - the recoil must
tell the viewer where the threat is), stagger, death. All of them need the
two-segment limb and none of them should be built before the wolf playtest that
`CLAUDE.md` names as a v0 prerequisite.

### Tier D - personality, and it is not optional

Wave (exists), point, nod, shrug, cheer, beckon, and **idle breaks**. Idle
breaks are the cheapest personality in games: after 4 s of true idle, play one
of four short motions - a weight rock, a shoulder roll, a head tilt, a look
around - chosen at random with a randomised interval so it never reads as a
loop. Four short poses, and the character stops being a mannequin.

### The details that make a rigid-part animation read

Curated for a hierarchy of rigid boxes with no skinning. Twelve, in rough order
of value per line of code:

1. **Hip counter-rotation.** Shoulders rotate opposite the hips, ±8°. Costs two
   lines. It is the difference between a person and a wind-up toy.
2. **Pelvis bob at 2× the stride frequency.** The hips rise twice per cycle,
   not once. Getting this wrong makes a walk look like a limp.
3. **The contact pose.** See above. Non-negotiable.
4. **Foot roll.** With a knee, the boot can pitch heel-down at contact and
   toe-down at push-off. ±12° on one bone.
5. **Arm swing asymmetry.** The forward swing is ~20% wider than the back
   swing. Symmetric swing reads mechanical.
6. **Head lag.** The head reaches a new facing 0.12 s after the body. It makes
   the head look attached to a neck rather than welded to a torso.
7. **Overshoot on every settle.** One small overshoot with a critically-damped
   return. Applies to landing, to stopping, to every pose transition.
8. **Anticipation before anything big.** 3 frames of reverse motion. Jump,
   attack, throw.
9. **Secondary motion on hanging things.** The cloak, the beard, the tail, a
   pouch: a spring-damper lag behind the parent bone. The tail chain machinery
   from character v1 Stage 8 is already generic and already does this - it just
   has one customer.
10. **Breathing amplitude tracks exertion.** 2 voxels at idle, 5 after a
    sprint, decaying over 8 s. Free winded-ness with no sound.
11. **Stance width tracks acceleration.** Narrow when accelerating, wide when
    stopping. Two voxels of leg X offset; nobody will consciously see it.
12. **Blend from the current pose, never from the new cycle's frame zero.** The
    animator already normalises poses and blends; it must keep doing that at
    every new state or every transition pops.

### Per-race gait

Race is never a stat, and gait is not a stat - it is the same animator reading
different numbers out of `races.gd`, exactly as stride already does. The
existing rule that stride scales with leg length already produces
dwarf < human < elf from one line of arithmetic. Extend it:

| parameter | human | elf | dwarf | lizardfolk |
| --- | --- | --- | --- | --- |
| cadence multiplier | 1.00 | 0.85 | 1.20 | 1.10 |
| arm swing amplitude | 1.00 | 1.35 | 0.65 | 0.80 |
| hip counter-rotation | 1.00 | 1.20 | 0.60 | 1.40 |
| pelvis bob | 1.00 | 1.15 | 0.55 | 0.70 |
| torso lean at sprint | 1.00 | 0.80 | 1.10 | 1.60 |
| settle time after stop | 1.00 | 1.30 | 0.55 | 0.90 |
| idle break rate | 1.00 | 0.70 | 1.40 | 1.20 |
| head lag | 1.00 | 1.30 | 0.70 | 0.60 |

The intent, in words: the elf glides and takes a long time to stop. The dwarf is
a piston - short, quick, low bob, settles instantly, fidgets constantly. The
lizardfolk's power is in its spine, so its counter-rotation and its lean are the
highest in the cast and its arms do the least. The human is 1.00 everywhere,
which is what being the reference means.

Every one of these is a multiplier on an existing `CharacterConfig` knob, which
means all of it lands on the F8 panel and none of it is hardcoded - the rule
character v1 set for tuning on the wrong renderer, still correct now that the
renderer is right.

### What I am deferring, and why

**Full two-bone IK foot planting.** The research put it in tier 1 and it is
wrong for this game. Kubik's ground is 0.5 m voxel blocks. An IK solver planting
on that surface pops by a full half-metre at every block boundary and jitters
along every edge. The cheap correct thing is a **foot height clamp with a
spring**: raycast down, clamp the foot to the surface, let the hip absorb the
delta with a critically-damped spring. Most of the benefit, none of the jitter,
and it degrades gracefully. Real IK is a later decision on smoother ground.

---

## The research lane

Marcel's brief said to treat the parallel research as a peer's opinion to argue
with. Here is the argument.

### The Kimi lane produced nothing

`/home/kimi/work/character-research-kimi.md` does not exist. Polled at 15:29,
15:38 and 15:44 UTC; the directory contains one file, `fizzbuzz.js`, timestamped
12:37, and a `.claude` directory created at 15:37. The brief at
`/tmp/kimi_brief.md` is good and the questions it asks are the right ones - if
that lane lands later, the sections most worth re-reading against it are the
per-race design language and the resolution decision, because those are the two
places a second opinion could genuinely move this doc.

This section stays as the record that the lane was checked, not skipped.

### Where my own research was right

- **Silhouette-first, and the black shape test as the acceptance gate.** Already
  the house method - the gallery's IoU harness *is* a black shape test - and the
  research confirmed the framing is standard rather than idiosyncratic.
- **The cape/cloak as the best value-per-voxel item in a game.** Consistent
  across every source. It is why the back slot is third in the slot order rather
  than sixth.
- **Asymmetry as the marker of status.** Symmetric reads issued; asymmetric
  reads earned. This shaped both the human's baldric and the tier ladder.
- **Veloren as the closest prior art**, and specifically its finding that neck
  detail on the chest piece is what stops the head disconnecting when it turns.
  That is a real bug we will hit the moment head-look meets a gorget.

### Where I disagree with it

**1. "Heroic is 7-8 heads tall."** Correct for a medium that can carry a face at
1/8 of the frame. At our distances a 1/8 head is 12 px at 15 m. Look v1's
stocky, third-of-the-height read is right and it stays. What the research is
actually reaching for is *exaggeration at the extremities*, which the Warhammer
entry states properly - and which we adopt.

**2. Non-metallic-metal painting.** Recommended by the armour lane in detail.
Wrong here, and the reason is in `voxel_model.gd`: the mesher already bakes
corner AO into vertex colour. Hand-painted face shading on top double-darkens
every concave corner. See the material rule above - this is the clearest case in
the whole exercise of research that has never seen the codebase giving advice
that would actively make the build worse.

**3. "~25-40 ms of CPU for a four-player squad's animation."** The measured cost
in this repo is **0.045-0.053 ms per character**, `update()` and `apply()`
together, averaged over 600 frames - about 0.2 ms for four players. The research
figure is off by two orders of magnitude, and it matters because a number like
that would have talked us out of secondary motion, spring damping and idle
breaks on cost grounds that do not exist. We can afford all of it.

**4. "96+ voxels: detail exceeds what perspective distance permits."** Half
right and it stopped one step short. The design lane's own diminishing-returns
call was 48-64 - which is where we already are, and which would argue against
raising at all. The pixel table above says 96 is the last grid whose atomic unit
is still ≥ 1 px at 15 m, and the argument for raising is not surface detail at
all, it is *the knee*. The research had no way to know that, because the thing
that makes 96 correct is a fact about our rig.

**5. Full IK foot planting as a tier-1 must-have.** Addressed above. Wrong for
half-metre voxel ground.

---

## What the tech plan has to solve

Not a plan. The list of things a plan cannot pretend are free.

1. **Every part is authored at 64 and must be regenerated at 96.** The rest
   offsets in `Races.bone_table` are all `* V` and survive a change to
   `VoxelModel.VOXEL_M` untouched; the ASCII does not. All seven files under
   `scripts/character/parts/` are outputs.
2. **`tools/parts_author/` must become resolution-parametric first.** 1,887
   lines of Python. Until every literal dimension is a fraction of race height
   in `voxlib.py`, the resolution decision is one-way. This is a stage, and it
   is the stage that makes the rest reversible.
3. **The `.vox` drop-in rule breaks.** `assets/characters/<race>/<part>.vox`
   replaces an ASCII part with no code change (`DESIGN.md`, "The drop-in rule").
   Any file authored against the 64-voxel grid loads at 2/3 scale after the
   change. Needs either a declared scale per file or a documented break, and
   `assets/characters/README.md` updated either way.
4. **`CharacterDef` is 8 bytes at `WIRE_VERSION 1`.** Six armour slots with an
   item id and a tier need at least 6-12 more. Bump to 2 - and `from_bytes()`
   must still accept a version-1 payload and fill armour with tier 0, or every
   existing save and every un-updated peer fails to parse. The host-validates-
   every-claim rule holds unchanged: clamp, never throw.
5. **The retained voxel list.** `rig.gd` keeps every part's voxels after meshing
   for the gear overlap check: ~0.53 MB per character now, ~1.78 MB at 96, and
   the armour system adds parts. Either accept ~7 MB for a party, or drop the
   list to bounds-plus-occupancy-hash once the overlap test has run. Measure
   before choosing.
6. **The triangle budget moves from 24,000 to about 48,000 and must be
   re-measured, not predicted.** Counts survive noise; use the gallery's
   reported numbers, not the 2.25× estimate in this doc.
7. **Four new bones and every pose rewritten.** `pose_for()` is a pure static
   function with no scene tree, which is the good news; the bad news is that
   every existing pose - locomotion, sit, downed, wave - describes limbs that no
   longer exist in one piece.
8. **New palette slots.** `SLOT_COUNT` is 13 and `SLOT_CHARS` maps one ASCII
   character each. This doc needs at least `LINER`, `TRIM_BRIGHT`, `METAL_DARK`,
   `SCALE_A`/`SCALE_B` for the checker, and a ventral skin for the lizardfolk's
   countershading - so roughly 19. There is room in the printable set; there is
   not room forever, and the tech plan should say what the ceiling is.
9. **The self-tests.** The height test is in metres and survives. The part-set
   completeness test needs the new slots and the new bones. The 100-random-
   appearance sweep needs armour in the random draw. The silhouette harness
   needs the **outline-event count** as a new metric alongside IoU, because the
   armour tier ladder is defined in terms of it.
10. **The gallery needs an armour sheet and a tier-ladder sheet**, and given the
    GPU it should shoot both at 3 m, 15 m and 40 m rather than the current
    single distance.
11. **The critter.** Character v1 Stage 13 proved the rig is not humanoid-only,
    and `parts_critter.gd` is authored on the same grid. It gets regenerated
    with everything else or it arrives at 2/3 scale.
12. **`ChunkMesher`'s foliage voxel format.** `voxel_model.gd` notes that
    foliage v1 produces `(x, y, z, colour, emissive)` against our
    `Vector4i(x, y, z, slot)`, and that unifying them is "a ten-line change once
    both branches have landed". Both have landed. Tier 5's emissive accent needs
    the emissive channel, so this is the run that has to do it.

### Explicitly deferred

Full two-bone IK. Cloth simulation of any kind. Per-race remodelled armour sets
(we use one normalised set, per the fitting rule). Facial expression beyond the
existing blink. Capes that collide with anything. First-person. Any combat
animation before the wolf playtest that `CLAUDE.md` names as a v0 prerequisite.

---

## Open items for Marcel

Decisions I made rather than stopping for, each with the door left open.

1. **96, not 128.** Argued from the pixel table and the memory table. If the
   poster shots at 96 read thin, moving is one constant in `voxlib.py` and a
   regeneration - provided item 2 in the tech list is done first. That is the
   whole reason it is item 2.
2. **The lizardfolk gets a new body - SETTLED, see below.** Raised here as the
   one item worth an early veto; it did not get one.
3. **The liner slot, and retiring the look v2 tunic rule.** Look v2's Stage 5
   darkening was correct arithmetic and it produced four black shirts. I am
   replacing the constraint rather than the values. The old hexes stay recorded
   above; nothing is deleted.
4. **Six slots, not three.** `DESIGN.md` says weapon, torso, trinket. This
   proposes torso, shoulders, back, head, legs, hands. That is a change to
   settled design and it should land in `DESIGN.md` as part of the tech plan's
   final stage, not silently.
5. **Green is banned on the elf and on the lizardfolk.** Both currently wear it,
   both are clichés, and the meadow is already green - a green character at 40 m
   against grass at Y = 0.221 is the one value coincidence the palette cannot
   afford.

## Settled decisions

### The lizardfolk gets a new body, and every race may be rebuilt from scratch

**Decided by Marcel, 2026-08-27.** Asked whether to veto the largest piece of
re-authoring in the epic, he did not: *"no complete rebuild and design of the
characters is fine."*

So this stops being a proposal. The reasoning above stands unchanged - the
status doc's options 1 (accept 0.868) and 3 (measure three-quarter instead) both
change the test, and the thing that is wrong is the model - and it is now the
plan rather than the argument for the plan.

The decision is also broader than the lizardfolk. **The re-authoring cost is
accepted for all four races.** The tech plan must not scope itself down to
preserve existing part models: where a race reads better rebuilt from scratch at
the 96-voxel grid than ported to it, it gets rebuilt. `scripts/character/parts/`
is output, `tools/parts_author/` is source, and none of the output is an asset
worth protecting.

That removes the one constraint that would have quietly shaped every stage of
the tech plan - "port what exists" - and replaces it with "author what the
design says". It is the more expensive answer and it is the right one.

### Two exercises to leave open in the implementation

House rule: leave one or two small, well-defined pieces as `TODO(marcel)` with a
hint, and keep everything runnable without them. These are the two I would carve
out, named here so the tech plan does not accidentally do them:

- **`TODO(marcel)`: the idle-break selector.** Four short poses exist; the
  chooser is a stub returning pose 0. Hint: a weighted random pick with a
  randomised 4-9 s interval, and never the same break twice in a row - the
  repeat is what makes it read as a loop.
- **`TODO(marcel)`: the dwarf's beard-ring tier mapping.** The beard part
  supports 0-3 rings; the function mapping armour tier to ring count returns 1.
  Hint: it is not linear, and the interesting question is whether rings track
  the *torso* tier or the highest tier worn anywhere.

---

## Acceptance, when the implementation is done

Four tests, all countable, none of them a frame time:

1. **The lineup.** Four races at 15 m and at 40 m, at dusk, in tier-1 gear.
   Every race named without walking closer. No cross-race IoU pair above 0.70
   front-on, across every hair, beard and crest option - which means the
   human/lizardfolk pair, currently 0.928 at worst, is the number that has to
   move.
2. **The tier ladder.** One race, five tiers, side by side at 15 m. Outline
   event counts 0 / 1 / 1 / 3 / 5, measured by the harness, not by eye. A viewer
   who has never seen the game orders them correctly.
3. **The colour test.** Four races side by side at 15 m at noon and at dusk, and
   no two of them are the same value tier on the torso. This is the one the
   current build fails hardest.
4. **The walk.** Eight frozen phases, and the contact pose is visible in at
   least one of them. It is not there today because there is no knee.

And one that is not a test but is the actual point: **shoot the campfire.** Four
characters in tier-3 gear, sitting, at 3 m, at dusk, on the GPU. If that image
is not one Marcel would put on a poster, the epic is not done, whatever the
numbers say.
