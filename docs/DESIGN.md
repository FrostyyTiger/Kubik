# Design

Settled details. Terse on purpose - this is a working doc.

Subject to the four pillars in the README. A line here that contradicts a
pillar is a bug in this file, not a licence to bend the pillar.

The fourth pillar - THE WORLD ANSWERS: authored truth, generative direction -
is the one this file serves most directly: everything settled here is the
authored truth. Where a section defines things the director could one day
steer (creature goals, what a place is, lore fragments, a quest's beats), it
defines them as DATA, per the three habits in `CLAUDE.md`. The director's
doctrine is `DIRECTOR.md`; it arrives late, and nothing here depends on it.
Story delivery is governed by `DIRECTOR.md` (authored beats, directed middles).

## Setting

Fantasy. Cozy but adventurous.

Playable races are described under Character identity below.

## Art direction

**The style was settled by look v1 (2026-08-25): the Art Deco Alpine travel
poster. The register was re-set on 2026-08-31: painted, not flat.** The
identity has not moved - the 1920s-30s railway and resort posters of the
Alps, Broders' PLM series, the Swiss lithographs: mountains as stacked bands,
warm sun and cool violet-ink shade, stepped geometric forms, one gold accent,
the travel-poster strand of Deco and never the Manhattan strand. What moved
is what those colours are painted ON up close.

**The 2026-08-31 ruling, from a reference set Marcel keeps outside the repo**
(nine renders in a desktop folder; this section carries their content so the
doc stands alone): a knight whose pauldrons are layered, sculpted plates with
gold trim woven through them and four greys of painted wear; a barbarian
whose bare skin carries four painted tones under a battered helm; a weapons
sheet where every polearm has a shaped blade, a wrapped grip and a fitting; a
dead fir whose branches are real branches under caps of snow; a garden whose
ground is dense with scatter and whose cliffs carry painted strata; a
timbered house, a bridge-town, a dungeon gate in a cliff, all in soft warm
light. **None of that is a finer grid than ours.** The character grid (96
voxels to a human, 1/24 of a block) already out-resolves those models. It is
the grid we have, actually USED: sculpted forms, painted tones, dense
dressing, soft light. That is the bar, and the old register - one flat colour
per surface - is retired everywhere the player can walk.

The poster does not die; it moves to where it always lived. **Up close the
world is a painting; at distance it is the poster.** The far ranges' flat
poster read survives - the 2026-08-31 comparison run showed it was the one
thing already at the bar - though distance v3, landing the same day, rebuilt
what is UNDER that read: see rule 3.

Five rules, re-cut on 2026-08-31. Everything drawn obeys all of them; a
feature that cannot is drawn differently.

1. **Shade is an ink.** (Look v2, unchanged.) The shade side keeps the
   surface's luminance and takes the ink's hue - blue-violet, a colour and
   never a darkness. The ramp desaturates the albedo toward its own luminance
   (`kubik_shade_desat`, 0.55 day / 0.75 night) and colours the result with
   the ink. Warmth is safety made visible: the campfire is the one warm thing
   in a cool night.
2. **Paint is voxels, never maps.** Supersedes look v1's "no texture, no
   specular, no gradient" - the second half stands, the first is re-read.
   There are still no texture maps, no specular, no gradient across a face: a
   colour is a voxel's colour on a model and a vertex colour on the wire,
   nowhere else. But a material is now PAINTED, in tones of its own family -
   steel in five greys, skin in four tones, bark in three browns - laid as
   patches and runs with intent: a highlight row along a plate's top edge,
   wear at a rim, strata in a cliff face, slivers under a whorl. Never
   white-noise jitter, never a tone from another family's ramp.
3. **Distance is bands, not haze - and distance is where the paint stops.**
   Fog steps in flat bands to a colour a step darker than the sky's lowest
   band (look v2: the horizon is not the fog; the sky owns its own horizon
   row). The near field is painted voxels; the far field is the flat poster;
   the seam between them is owned rather than hidden.

*Amended by distance v3 (2026-08-31), and the rule stands - what changed is
   what is under the bands.* The far field is no longer a stacked backdrop: it
   is the same world made of BIGGER BLOCKS, 4 m at the seam through 8, 16 and
   32 to 64 m at the rim, terraced with lit tops and shaded risers, painted on
   a world-space block lattice that grows with distance so a hillside at 3 km
   is flecked in ten-metre cells rather than in half-metre ones nobody can
   resolve. A far cell is one real material chosen by a majority vote over four
   sub-samples, never a blend. The fog is still bands and the bands are still
   the poster, but the curve UNDER them is now exponential-squared over the
   configured reach, measured cylindrically so looking up does not fog the
   peaks' sky - which is what removes the wall. And the seam is owned by
   OVERDRAW: the far field is drawn under the whole voxel disc, sunk below it,
   so what shows through a hole in the world is ground drawn a metre and a half
   low rather than sky.
4. **Forms are sculpted, stepped and chamfered.** Look v1 said stepped and
   chamfered; the reference set adds sculpted. A pauldron is three layered
   plates, not a box; a helmet has a brow, a visor slit and cheek guards; a
   blade has a shaped edge and a fitted socket. Heads still lose their
   vertical edges to a chamfer; trees keep the trees v1 form language below.
   Everything stays on the voxel grid - "sculpted" is achieved with steps,
   never with rotated geometry in the world mesh.
5. **One accent.** Gold `#C9A24A`: UI rules, the sun disc, trim on the things
   the world honours, later the campfire's light. Nothing else in the world
   is gold. The gold has an hour: `Look.accent_color()` reads the keyframe
   table, dawn `#F2A80D` through noon `#C9A24A` to night `#E8892E`. Gold trim
   on gear obeys the same discipline - it is the accent, so it is never the
   body of a thing.

**Two look v2 rulings stand beneath all five.** Warmth is in the light,
coolness is in the shade, and the albedo has neither - a palette entry is the
thing's colour in flat noon light; the sun makes it warm and the ink makes it
cool, and nothing bakes a cast into an albedo. And what is authored is what
is on screen - an authored hex, lit, at noon, lands at `authored * sun *
energy` and nowhere else, proved by the swatch sheet (`godot --path .
scenes/character/gallery.tscn -- --sheet swatches --strict`, every swatch
within 6 sRGB units of `Look.predict()`) before anyone judges a colour
through a changed stage.

**Two gates, replacing taste.** The KNIGHT TEST, for anything that moves: set
the model beside the reference knight and barbarian; it passes when it reads
as the same game - layered forms, family-toned paint, a silhouette that still
means something at 40 m. The BELONGING TEST, for the world: drop a passing
character into the frame; the ground, the trees and the light must not
embarrass it - painted terrain tones, dense scatter, strata on rock, soft
occlusion in the corners. A screenshot that fails either gate is a bug with a
cause to be found, not a taste dispute.

**Scope of the register (2026-08-31).** Now: characters, gear, weapons,
creatures, trees, flora, terrain dressing, lighting. Later, at birth:
structures - nothing is built yet, so Sites v1 and everything after arrives
at this fidelity rather than being converted to it. Unchanged: the far field,
and the UI's Deco paper and ink. The plan lane is **look v3**; the demo that
set the bar is `kubik-knight-demo.bbmodel` on Marcel's desktop, authored the
day of the ruling.

**Trees v1 (2026-08-30) is the form language of the forest, and it stands.**
A conifer is a notched spire - max width one third of its height - built from
whorl ARMS of unequal length around a solid core, each tier yawed a
golden-angle step from the one below; the larch is the ziggurat, four to six
shelves with real air between them, so its sky shows through the GAPS and
never through the crown volume. A beech is an oblate scallop of two to four
overlapping lobes in a big/medium/small hierarchy, bitten once or twice from
outside, on a clean trunk with a limb entering the crown underside; a birch
is a bowed pale stem the foliage never closes over; a krummholz is a
wind-flagged cushion, twice as wide as tall, and every one in a world combs
the same way. The hero is re-proportioned rather than its parent scaled.
Every conifer carries the second colour as **authored slivers** on the whorl
underside, where a shelf stands proud of the one below - never scattered
through the crown. Under rule 2 as re-cut, the forest's paint deepens - bark
in family browns, snow held on the windward side - without leaving these
silhouettes. The taste authority is `docs/research/art-direction.md` §2.5
"Forest"; the variation machinery and the measured cost model are in
`docs/research/trees.md`, and the run is `docs/status/trees-v1.md`.

### The pipeline: linear maths, sRGB on the wire

Every palette in the game is stored **linear** and every multiplier that acts
on one - baked AO, the far field's skirt and altitude band, the aspect tint -
is a linear multiplication. The **one** conversion is `Look.to_wire()`, called
by each mesh builder on its final colour at `push_back`, because the renderer
decodes an 8-bit vertex colour on the way to the shader; push linear and it is
decoded twice. The sky is converted once on the way out of its own shader,
which does not get the conversion other surfaces do.

`light()` writes the LIGHT, and `ALBEDO` is white: the albedo travels to it in
a varying, so it is applied exactly once whatever the renderer does after
`light()` returns.

Where it lives: `scripts/world/look.gd` holds the one lighting ramp every
shader in the game is built from, the banded fog, the sky, `Look.to_wire()` and
`Look.predict()`; `SkyCycle.KEYFRAMES` is the time-of-day table - four
keyframes (dawn, noon, dusk, night) x eleven rows, blended by
`keyframe_at(elevation, morning)`, and it is the only place an hour's colour is
decided; the UI theme is `assets/ui/deco_theme.tres` (paper `#F2E8D0`, ink
`#1E2430`, gold, alpine blue `#2F5D8A`, sun `#E8863A`, pale ink `#7D7C78`;
Limelight for titles, Josefin Sans for body). `docs/plans/look-v1.md` is the
first argument and `docs/plans/look-v2.md` the second.

## Character identity model

Three layers, each answering a different question.

| Layer | Question | Chosen |
| --- | --- | --- |
| **Race** | who you are | once, at creation |
| **Gear** | what you do | moment to moment |
| **Skills** | what you've done | never - it accrues |

- **Race = who you are.** Cosmetic plus one small situational perk.
  **Never stat modifiers.** A race must never be the correct answer to a fight.
- **Gear = what you do.** No classes, ever. Roles emerge from what you carry:
  holding the staff makes you the mage today. **Never punish switching** - no
  proficiency penalties, no lockouts, no respec cost.
- **Skills = what you've done.** Skill-by-use, growing silently from behaviour.
  Nothing to allocate, nothing to choose.

## Races

Launch set of four. Fixed proportions per race, and **strong distinct
silhouettes readable at distance in dim light** - that is a hard art
requirement, not a preference. Half this game happens at dusk.

| Race | Build | Perk |
| --- | --- | --- |
| Human | medium | learns all skills slightly faster |
| Elf | tall, narrow | sees further at dusk and at night - fog and darkness pushed back a little |
| Dwarf | broad, low | ore and mineral deposits glint visibly |
| Lizardfolk | exotic - tail | swimming |

Perk language is **sensory by default** - perks change what you notice, not what
you can do. Lizardfolk is the deliberate movement exception.

Lizardfolk's swimming ships only when water becomes interactive. Until then the
placeholder perk is seeing fish shadows in lakes.

### Open on the perk set

Recorded rather than quietly resolved:

- **Human's perk is a stat modifier**, which the rule two paragraphs above
  forbids. It is also the only perk that is never situational and that compounds
  across the whole game, which makes it the strongest of the four by some
  distance. Either the rule bends or the perk changes.
- **Dwarf's perk needs ore and mineral deposits**, which no design doc defines
  yet. Gathering is a launch skill so it is plausible, but nothing says what is
  in the ground or why you would want it.
- **Lizardfolk's placeholder needs fish**, which also do not exist.
- **Elf's perk touches a pillar directly.** Pillar 2 makes darkness a danger
  axis; a race that pushes darkness back is mitigating the game's central
  tension rather than a side activity. Situational, so it fits the letter of the
  rule - worth being deliberate about anyway.

Two of the four perks are currently IOUs.

## Character creation

One screen. Race, palette swaps (skin, hair, eyes, from per-race palettes),
hair and beard picks per race, name.

**No sliders. No stats.**

## Skills

Five at launch: **Blades, Bows, Magic, Mobility, Gathering.**

- XP comes from doing the thing. Diminishing curve. **No decay, ever** - putting
  a weapon down for a month must never cost you anything.
- Rewards are two-speed: smooth small bumps every level (swing speed, draw time,
  stamina cost), plus a chunky unlock roughly every five levels - charged shot, a
  dodge-roll upgrade, that sort of thing.
- **Numbers stay small: about +25% total by level 10.** The real power curve is
  two players getting better at the game together, not their characters getting
  better at it for them.
- UI: a character sheet screen from the start, plus a small toast on level-up.

**The sheet is read-only.** The moment it lets you spend anything it becomes the
skill tree this design rejected, and pillar 3 goes with it.

## Magic (v1)

Two elements, no more.

- **Fire bolt** - small burn over time.
- **Frost bolt** - brief slow.

Designed as co-op glue: one player slows, the other finishes. No further
elemental matrix for now - a combination table is a Someday, not a v1.

## Gear

**Six slots, all visible on the character**: torso, shoulders, back, head,
legs, hands. Four ship with geometry; **legs and hands are declared with none**,
so filling them later costs art and not a wire-format change.

Changed from three (weapon, torso armour, trinket) by character v2, and the
order is argued rather than alphabetical - it is the share of the SILHOUETTE
each one owns. Torso is 38%, back is 15% and reads at 40 m, shoulders are the
only slot that grows the outline outward at the widest point the character has.
Legs go last, and that is not a slight: a greave at 15 m is nine pixels behind a
tuft of grass.

Visible gear is the cozy progression payoff. Your character sitting at the
campfire *is* the progress screen - which is pillar 2 doing its job, so keep the
silhouette legible as gear changes.

**Tiers are a ladder of OUTLINE EVENTS, not of surface decoration.** With flat
vertex colour and no textures, surface detail is free to author and invisible at
range: the outline is the only currency a piece has. So five tiers are defined
by how many places the silhouette gains a local maximum the naked body does not
have - 0 / 1 / 1 / 3 / 5 - which is a countable claim, and the gallery's
`--sheet outline` counts it. Tier 1 has zero on purpose: if starting gear
changes the silhouette then the naked character is not the design.

**One authored set fits four bodies: proportions relative, thicknesses
absolute.** A piece is described in fractions of the attachment's own width,
height and depth and stamped into each race's real dimensions, but its plate is
the same number of voxels thick on everyone. Scale the thickness too and dwarf
armour looks like foam rubber while elf armour looks like it was cut from sheet
tin. Two per-race exceptions are named and there are no others: leg armour does
not fit a digitigrade leg, and a back piece has to route around a tail.

**Every head item is authored per race and leaves its wearer's identity feature
intact or replaces it in kind.** A full helm erases the elf's ears, the dwarf's
beard line and the lizardfolk's snout in one item, and then four races that took
a whole epic to separate are four helmets.

None of this is an item system. There is no item table, no inventory, no drops
and no rule about what grants a tier; **Items v1 owns all of that.**

## Art pipeline

**Architectural requirement. Expensive to retrofit, so it is settled now.**

Characters are modular voxel models on a simple skeleton - head, torso, arms and
legs as separate parts.

- **Races** = part sets plus proportions.
- **Customisation** = palette swaps plus part picks.
- **Gear** = models attached to bones, or part swaps.

**Settled by character v1, re-settled by look v1, re-settled by character v2.**
One model voxel is **1/24 of a block, 2.083 cm**, and a human is **96 voxels =
2.00 m**. (Character v1 built at 1/8; look v1 halved the voxel for the detail a
face and a hand need; character v2 took it to 1/24.) Characters and terrain
therefore do not share a voxel grid, and the chunk mesher is not the character
mesher: two systems, not one, and they meet only in the material and the
baked-AO rule.

**The reason for 1/24 is a knee, not detail.** A 16-voxel leg split in two
gives segments 8 voxels long - a limb whose joint is half its own thickness. At
96 the legs are 24 and a 12/12 thigh and shin is a joint you can watch bend.
And **not 128**: at 15 m, the far edge of the band the game is played in, one
voxel is 1.5 px at 64, 0.98 px at 96 and 0.73 px at 128. Below a pixel, detail
does not render - it aliases, and shimmers whenever the character moves. 96 is
the last grid whose atomic unit is still a pixel where the game is played.

The four races, at the crown, all built and measured:

| Race | Height | Silhouette |
| --- | --- | --- |
| Human | 96 vox, 2.00 m | the reference: square, stepped shoulders |
| Elf | 108 vox, 2.25 m | tall and narrow, ears nine voxels out each side |
| Dwarf | 72 vox, 1.50 m | as wide as it is tall, and always bearded |
| Lizardfolk | 90 vox, 1.88 m | tail, crest, snout, leaning 8 degrees forward |

**Every height in metres is unchanged by the grid move** - the totals and the
voxel size moved by reciprocal factors - so the capsule, the camera pivot and
the speed table were untouched by it.

**The collider is identical for every race** - a capsule, radius 0.4 m, height
2.0 m, with the camera pivot at 1.5 m. Race is never a stat: the dwarf's head
sits at 1.5 m inside a 2 m capsule and the elf's pokes 0.25 m above it, and both
are cosmetic by decision. No per-race number appears in `player.gd`.

**Every race is stocky - decided in look v1.** Head about a third of the
height, big hands, big boots, no neck except the elf's: the Cube World read,
kept on the stocky side rather than the doll side, because it is what stays
readable at 40 m at dusk. Character v1 built a lean (naturalistic) human for
comparison; it was retired with the decision and its part set deleted. The
`build` byte stays on the wire, always 0, so the wire version did not bump.

**Look v3 direction (2026-08-31): the parts library is re-authored to the
painted register.** The bar is the knight/barbarian reference set (see Art
direction). The rig, the grid, the slots and the drop-in rule all stand; what
changes is what is authored INTO them - sculpted part shapes and family-toned
paint. The authoring surface becomes **Blockbench**:
`scripts/tools/bbmodel_export.gd` already exports the assembled character
through the same code path the game draws, and the look v3 plan owes the
import half of that round trip. Two constraints bind the tech plan: palette
swaps must stay free (a family re-resolve, exactly as slots resolve today -
the encoding of tone-within-family is the plan's to settle), and no client
may need a wire change to see a part that got prettier.

### Parts are data

Every voxel of every part is authored as **ASCII slices in semantic slots** -
`S` skin, `H` hair, `E` iris, `C` cloth, and nine more - never as colours and
never as box primitives in code. The same voxels through a different resolve
table are a different-looking character, which is what makes a palette swap free
and what lets the creation screen rebuild the model on every click.

### The drop-in rule

If `assets/characters/<race>/<part>.vox` exists, it **replaces the ASCII part of
that name at load, with no code change**. MagicaVoxel art whose palette indices
1 to 13 are the thirteen slots takes skin and hair swaps exactly as ASCII does;
art in arbitrary colours still loads and simply does not. See
`assets/characters/README.md`.

## Characters and saves

**The character lives in the world, on the host.** One save file holds the
world's edits and every character in it.

Consequence, accepted knowingly: a character cannot leave the world it was made
in. If you are not hosting, your friend cannot play that character, and a new
world means everyone starts over.

The alternative considered and rejected was Valheim's split - character on the
client, world on the host, carried between worlds. Rejected because it requires
the host to trust a client's claims about its own stats, and keeping one
authority for everything is worth more to us than portable characters.

## Camera

**Third person only.** No first-person mode.

Cube World style orbit follow: mid-distance, mouse orbits the character, camera
collides with terrain rather than clipping into it. Chosen because the game is
sold on reading landscape at a glance, and an over-the-shoulder framing hides
exactly the thing worth looking at.

A free-fly / noclip toggle exists behind a debug key. It is a tool, not a mode.

## World

**Procedurally generated and effectively unbounded - ruled by Marcel on
2026-08-31, overturning "bounded, not infinite".** The world the game wants
is very, very big: you stand in a valley, see ranges beyond ranges with no
fog wall, and you could walk to any of them. No world edge, no "the map ends
here". The ruling is about the world model, not today's build: generation
does not have to be infinite yet - the current build still generates one
fixed 3 x 3 km region, and that is fine as a stage - but **no new system may
bake in a world edge or a global-extent assumption.** Filling all that space
so it stays fun is deliberately deferred ("get to filling it with things
later"); the size is core and comes first.

Blocks are 0.5 m, so a player is 4 blocks tall.

*The generated region was 1.5 x 1.5 km through terrain v1. Doubled in
terrain v2 Stage 6, once sprint existed to cross it - see Traversal below.*

**What "bounded is a feature" was paying for, kept as constraints the
unbounded world must answer differently rather than pretend away:**

- **Lakes.** A per-basin lake needs a heightmap wider than any one chunk -
  you cannot find a depression by looking at one chunk. The global 2 m
  heightmap paid for that. Unbounded, the heightmap becomes regional tiles
  wide enough to hold a basin, and a basin crossing a tile border is a real
  problem to be solved, not wished away.
- **The director.** Authored truth wants the world's facts finite and in a
  table. An unbounded world concentrates its authored truth in generated
  regions of interest; the space between them is terrain, not content.
- **Traversal.** The 3 km map was sized to a six-minute sprint diagonal, and
  Cube World's 2019 failure - vast and empty - remains the named hazard. The
  answer can no longer be "smaller"; it has to become density near and
  reasons to go far. How reaching the genuinely far works (and whether
  something faster than sprint eventually ships) is open, deliberately.

### The north star: monumental (2026-08-31, same session as the ruling)

Unbounded says how big the world IS; this says how big it must FEEL, and it
is the test every scale decision answers to from here. The game is a huge,
grand adventure: continents, not a map. Factions with massive reach. Built
things - towers, walls, ruins - at a size where a player stands at the foot
of one and feels small; the Voxel Box school of monumental Minecraft
building is the reference Marcel named. The player should be the smallest
thing in frame nearly always, because feeling small against the world is
what makes ranging into it epic - and it is pillar 2's ratio at full
stretch: the vaster and stranger the out-there, the warmer one campfire is.

Two honesty notes, so this stays a north star and not a lie:

- **Content is deferred, not denied.** Marcel's own call: storylines and
  things to do are his to solve later. The FEELING of scale must not wait
  for them, and no one gets to block a scale decision on "but it will be
  empty" - that hazard is already on the record above.
- **Huge buildings are the world's, not the players'.** "No base building"
  is untouched: the world builds monuments, players place objects.

Rendering is voxels near the player and a low-poly heightmap mesh far away.
Terrain generation targets are in `plans/terrain-v2.md`.

**THE FRONTIER RULE, world feel v1: never a hole, at any speed.** The far mesh
and the impostor ring cut their inner edge to where the voxels have ACTUALLY
arrived - `World.loaded_frontier()`, sixteen angular sectors - and not to the
radius where the voxels are merely expected. Keyed to the radius, the hole
moved the instant the player crossed a chunk boundary and the voxels arrived
seconds later, so the ground ahead of a moving player was neither far mesh nor
voxels. That was 126 of 144 sprint samples with a hole in them; it is now zero,
and it is a hard rule rather than a target: overlap is invisible, a gap is not.

### Scale: the world is 1:4 against reality

Every object in the world is a quarter of its real-world size, and the value of
saying so is that ONE ratio has to appear on every line. The eye judges size by
comparison, so an object at 1:10 standing next to one at 1:4 does not read as a
small world - it reads as a broken one.

| Thing | In game | Real equivalent |
| --- | --- | --- |
| Tree | 13 - 21 m (old growth 19.5 - 31.5 m) | 26 - 42 m spruce, beech, larch |
| Grass tuft, flower | 15 - 55 cm | the same, at 1:1 |
| Largest lake | ~116 m across | ~400 m tarn |
| Mountain relief | ~350 m | ~1400 m |

The player is the deliberate exception, at 2 m against a real 1.75 m. A
quarter-scale player would be 44 cm tall and everything about the camera, the
step height and the reach distance would have to be re-derived from it, for a
world that looked exactly the same. So the character is life-size and the land
is quarter-size, and the visible consequence is that sprint looks fast.

**Ground plants and boulders are the second exception, at 1:1.** Added in
foliage v1. The rule is not "small things are life-size", it is **what the
object is read against**:

| Read against | Scale | Examples |
| --- | --- | --- |
| The landscape, from across a valley | 1:4 | terrain, lakes |
| The player, from two metres away | 1:1 | the character, **grass, flowers, ferns, boulders** |
| **Both** | **1:2** | **trees** |

**The third row is world feel v1 (2026-08-26), and it is the one this table
was missing.** A tree is the one object read against BOTH. From across a valley
you judge it against the ridge behind it; standing under it you judge it
against yourself. At 1:4 it was right against the ridge - three per cent of it,
which is exactly real - and seven player-heights tall, where a real spruce is
twenty-five. It read as a shrub you happened to be standing near.

So the trees are drawn at **1:2** and the land is not rescaled. `world_scale`
stays 4 and was not relitigated: rescaling the land would move every lake,
every zone threshold and every slope in the world to fix an object that is one
row of this table. `WorldgenConfig.tree_read_scale` (2.0) composes with
`tree_size_scale` per species in `TreeSpecies.table()`, and each species takes
the share its `read` field allows - spruce, beech, larch and the hero all of
it, birch half, krummholz and snags none. A knee-high alpine shrub at twice the
size is not a bigger shrub; it is a tree.

**Old growth is a second tier on top.** About a third of groves are old growth
(`old_growth_share`), their trees a further 1.5x - so 1:1.33 against the
player, a 31 m spruce - with fewer trunks, further apart, and crowns that
touch. Contrast is what makes huge read: a forest where every tree is a bit
bigger is a forest with bigger trees, and a forest where one grove in three is
enormous is a forest with old growth in it.

A tree at 1:2 is still landscape at distance. You judge it against the slope it
stands on and the treeline above it, and a 21 m spruce still reads as a 42 m
spruce from across the valley - because at that range what you are comparing is
its share of the ridge, and that has not changed.

A grass tuft is not. Nobody ever compares a blade of grass to a mountain -
they compare it to their own boots. A 30 cm tuft drawn at 1:4 is 7.5 cm, which
is not short grass, it is invisible: below the height of the block it stands
on, and gone entirely by the time the camera is where a third-person camera
goes. So ground cover is drawn at its real size.

The two exceptions are the same exception. Anything read against the PLAYER is
1:1, and the player is 1:1 - so they are consistent with each other, which is
the only consistency the eye can actually check. A player wading through
knee-high grass is the picture; a player wading through ankle-high mountains
would not be.

**Ground plants are built at 8 model voxels per block - 6.25 cm each** - not
the world block scale. Characters were the same size through character v1;
look v1 took them one step finer (1/16, see the art pipeline above) and left
the plants where they were, deliberately: a face needs the detail and a tuft
does not, and 8.7 million pieces of ground cover at eight times the voxels is
not a cost worth paying for the tuft. A plant is still read against the
player, at 1:1, which is the consistency the eye actually checks.

**Full scale was considered and rejected, in writing, so it is not
relitigated.** A real 1400 m mountain needs roughly a 6 km base, which does not
fit inside a 3 km world at all; a 15 km world that could hold one has a 21 km
diagonal, about 35 minutes' sprint corner to corner. That is the failure mode
that damaged Cube World's 2019 release.

*The 2026-08-31 unbounded ruling does not reopen this. The half of the
argument that leaned on the world's size is gone; the traversal half - what a
player can reach on foot in a session - still binds, and 1:4 is still what
makes a mountain reachable.*

Rendering was never the constraint. Since terrain v2 the far field is built in
LOD rings, so its cost is roughly logarithmic in view distance - 80k vertices at
600 m, 82k at 800 m. **Traversal was the constraint**, and it still is.

*Distance v3 (2026-08-31) finally spent that logarithm.* High and Ultra see
3,200 m of fog over a 3,840 m far radius, which covers the whole region's rim
from anywhere a player can stand, and it cost **262k vertices to 323k for
sixteen times the visible ground** - one more ring per doubling, exactly as the
ladder promised. The numbers above are the terraced far field's, which is
2.5x the smooth one's; what did not change is the shape of the cost.

### Traversal

The map diagonal is 4243 m and the target is under six minutes at sprint. Walk
is 5 m/s, sprint is 2.6x that at 13 m/s, Shift held. Alt is a precision crawl
for lining up a shot.

A world nobody wants to cross is smaller than a world they do, whatever the map
says. If the world grows again, this number is what has to grow with it.

## Creatures

Designed 2026-08-25. Nothing here is built yet; the first combat playtest
(below) is where it starts.

### Register: three blended layers

- **Real Alpine wildlife, stylised** - ibex, marmot, fox, wolf, eagle, fish.
  The familiar base, concentrated near spawn and in the valleys.
- **Fantastic creatures**, increasingly further out and higher up, rooted in
  the folklore patterns in `docs/lore/swamp/influences.md`: scree-worm
  (Tatzelwurm energy), frost-folk, storm-beings.
- **Environment-interacting behaviour is a design priority across all of
  them.** Worms burst from scree, marmots whistle alarms and dive into
  burrows, fish shadows scatter, birds lift off when something big moves.
  Behaviour over anatomy: it is the cheapest form of "the world is alive",
  and ambient reactions double as player information - the marmot whistle is
  a danger radar.

### Danger structure: no painted zones

Spawning is driven by four dials the worldgen already has:

- **Altitude** - valley floor safest, above the treeline strangest.
- **Distance from spawn** - stretches everything wilder
  (`TerrainGenerator.danger_at()`).
- **Slope and terrain context** - what the ground is, not where it is on a
  map.
- **Time of day.**

Players learn safety as a grammar - "we're high, it's getting dark" - not as
map regions. Passive wildlife is the norm; hostiles are the exception,
concentrated by these dials.

### Hostile roster (launch)

Four to five archetypes, few but distinct, each designed for duo tactics
first (pillar 1), with dumb count-scaling for three and four players:
**rusher, ranged, ambusher, tank, swarm.** Concrete species are assigned to
archetypes later, with lore and art.

### Hunting: the cozy-honest rule

The real-wildlife tier is huntable for food and materials (ibex, fish,
boar-tier); hostiles drop materials. **Small cute ambient creatures -
marmot-tier - are not huntable.** They are the world's texture and
information layer. No mechanical punishment needed: they simply cannot be
targeted.

### Megafauna

A few RARE giant creatures as awe encounters, in the Pilatus-dragon register:
near-sacred, witnessed more than fought. Not bosses on a checklist -
encounters that make a session memorable. Designed later; worldgen should be
flagged that rare large-creature sites may exist.

### Night

v1 night changes creature boldness only mildly. The full night system -
area-dependent night casts, aggro nights, raid events - is a late-game system,
see `IDEAS.md`.

### Mimics: the world that seems

- Some world-objects are creatures in disguise. First: the **mimic-tree**.
  Walk near it and it tears its roots free, shudders upright, and walks.
  Register: an old thing disturbed, not a horror jump-scare.
- **Rarity is the mechanic.** Mimics must be rare enough that each awakening
  is a story, never so common that players distrust the world category. Rough
  north star: a player meets single-digit mimic-trees across many hours.
- **Tells for the attentive.** A mimic is subtly off: it leans against the
  slope's grain; birds never land on it; marmots won't burrow near it. The
  ambient-life information layer doubles as the mimic detection system.
  Veterans get to READ forests.
- Mechanically archetype-cheap: mimic-tree = ambusher or tank archetype plus
  a unique reveal animation. The roster does not grow.
- **Escalation with distance.** Near spawn the world is what it seems;
  further out, seeming frays. Deeper mimics - boulders, a copse, one day a
  hillside - are Someday material.
- Lore hook: fragments may reference it obliquely ("the old forest walks";
  trees "that were not there at lammas"). Story delivery is governed by
  `DIRECTOR.md` (authored beats, directed middles): the fragment's text may be
  directed, the fact that mimics exist is authored.

### The unprompted world: ambient aliveness as a design value

- The world's aliveness lives in things that happen without player cause:
  eagles crossing the sky, fish rising at dusk, marmot sentries whistling,
  wind-waves in grass, a distant rockfall, the rare tree that stands up.
- Each is a small local behaviour script, not a system. This is a jar we add
  one marble to every few sessions, forever.
- **First ambient-sky creature: the eagle.** Circles high on thermals along
  ridgelines, an occasional echoing cry (the classic alpine raptor scream,
  reverb-touched), lands on far crags, never interacts in v1. A silhouette
  model, a slow orbit and one sound file: near-free, huge atmosphere payoff.
- The eagle later joins the information layer (circles over large creatures
  and carrion - the sky becomes readable) and the lore layer (watchers of the
  passes; seeing one land is lucky). Someday.

### Art

Creatures follow the art direction above - the painted register up close,
the poster at distance: silhouette-first, readable at range, family-toned
paint, and the same voxel-part modularity as characters where possible -
the critter rig, `tools/parts_author`, and the part data it writes to
`assets/characters/parts/` for `PartsData` to load.

### Behaviour: the technical stance

Settled 2026-08-25, for the creature plans to inherit. The game's theme is a
world that is smart, so its animals and NPCs must *appear* smart - and the
impressive part is never the decision library. It is perception,
communication, memory and terrain use, designed on top of whatever runs the
decisions.

**The seconds layer** - creatures decide on the host, and only on the host, so
nothing here needs to be deterministic; clients see positions and a state
byte.

| Need | Tool | Why |
| --- | --- | --- |
| Decision structure | **LimboAI** (MIT, C++ GDExtension: behaviour trees, hierarchical state machines, blackboards, a visual editor) | The best-maintained option for Godot 4 and fast enough for dozens of active creatures. Wolves, the mimic reveal, the storm-scholar. Beehave (pure GDScript) is the fallback if the extension fights the build. |
| Ground pathfinding | Godot's built-in **`AStarGrid2D` over the coarse heightmap**, with per-species slope-cost weights | Not the navmesh: `NavigationServer3D` wants navmeshes re-baked per chunk on voxel terrain. The heightmap is already the 2 m grid the lakes and zones live on; a path over it is deterministic and cheap. Ibex flee uphill because uphill is cheap in their table and dear in a wolf's - terrain use as one weight table. |
| Herds, flocks, birds, fish | Boids / steering, written here (a few dozen lines) | Eagle orbits, chough flocks, fish shadows, the cow herd's drift. |
| Needs-driven animals | Utility AI, written here: score actions by hunger, fear, curiosity | Marmot, deer, fox. The same animal does different things on different days, which is what "alive" reads as. |
| Planning NPCs | GOAP, written here or a small open implementation | The fourth pillar on the seconds timescale: authored goals, planned path. The storm-scholar first. |
| Learning agents | Not used | Non-deterministic, opaque, impressive in a demo and nowhere else. |

**The five rules that make them look smart.** Every creature plan states
which of these it delivers.

1. **Perception with senses, not radius checks.** Sight cones, noise events
   with a loudness, scent carried downhill on the wind. A wolf that only
   notices you upwind is a wolf players *learn*.
2. **Communication.** One marmot whistles and every marmot on the bench
   dives. One wolf finds you and the pack converges from different
   directions - pillar 1's flanking, mirrored back at the players.
3. **Memory.** A fled deer returns cautiously to the same patch; a hurt wolf
   keeps its distance. A blackboard entry, not a system.
4. **Terrain use.** Ibex on ledges you cannot reach, wolves out of the dark
   side of a slope, burrows placed at spawn. The environment-interacting
   behaviour above, made mechanical.
5. **Smart objects.** Burrows, crags, carrion and carcasses *advertise* what
   can be done at them (the affordance pattern). Animals then look purposeful
   for free, and the eagle circling over carrion falls out of it.

**Where the director does not go.** Nowhere near this. The director owns
minutes and acts through the verb list in `DIRECTOR.md`; behaviour trees,
utility scores and planners own seconds. The seam is a verb: the director may
`mark_site` a carcass as interesting; the wolves' tree decides what to do
about it.

### The first combat playtest: a trio

One creature per layer of the world: the **wolf** (threat - the rusher), the
**marmot** (ground texture and information - whistle and burrow), and the
**eagle** (sky texture). Recorded in `IDEAS.md` as the candidate for the next
playtest.

## Combat

Simple and readable. If a player cannot tell what just hit them, it is wrong.

- Light attack, dodge / block.
- Weapon types with distinct feel. Sword, bow, staff first.
- Encounters assume at least two bodies. Tuned for 2, must not go trivial at 4.

## Death

- Downed player can be revived by any teammate.
- Whole party down, or nobody in reach: respawn at the last campfire.
- While dead, the camera follows a living teammate.
- Costs time, not progress.

## Placeable objects

A restricted palette of objects - campfire, torch, marker - placed into the
world. **Not terrain.** Players never place raw voxel blocks.

This is the line that keeps "no base building" true. Give players arbitrary
blocks and someone walls off a cave and calls it home, whether we designed for
it or not. Restricting the palette means there is nothing to build walls from.

Breaking terrain is a separate question and **is now settled - see Physics.**

## Physics

Added in world feel v1, night 2.

### Terrain does not move

**Breaking terrain is decided: no, in v1.** Voxels are edited through the
request path and never simulated. No physics body is a block, no body's motion
writes a voxel, and there is no digging.

This is the same line that "no base building" is drawn on, one step further
out. A world you can dig is a world where the interesting answer to every
obstacle is "go through it", and the third pillar - THE WORLD IS THE CONTENT -
only works if the world gets to be an obstacle. It is also the single largest
piece of streaming complexity the project has managed to avoid.

### What a body is

A short table (`scripts/physics/body_table.gd`), like `Races`:

| kind | promoted from | mass | hold | what it means |
| --- | --- | --- | --- | --- |
| boulder_m | `BOULDER_M` decoration | 250 kg | 400 N | one player moves it |
| boulder_l | `BOULDER_L` decoration | 900 kg | 1000 N | two players move it |
| log | *(not promoted in v1)* | 120 kg | 150 N | reserved for felled trees |

A fraction of medium and large boulders - `body_fraction`, 0.15 - are pushable
rather than scenery, decided by a seeded hash so every peer agrees without
anybody sending a list. **Not all of them**: a world where every boulder rolls
has no landmarks in it, and you cannot say "meet me at the big rock" if the big
rock is wherever somebody last shoved it.

A body at rest is FROZEN, not merely asleep. It is solid - you can stand on it
and walk into it - and it does not move until something clears its hold. That
is a rule, not an optimisation: a sleeping body wakes on any contact, and a
boulder on a mountainside that wakes for any reason rolls.

### The push is a co-op rule

Each player leaning on a body contributes **600 N**; the sums are added across
everyone touching it and compared against the body's `hold`.

- **over the hold** - it wakes and goes.
- **under the hold** - it stays, and **rocks**: a three-degree tilt toward the
  push, on every peer's screen.

The rocking half is the design. A boulder that ignores you is scenery; a
boulder that gives an inch and settles back says *not on your own* without a
line of UI. This is pillar 1 - BETTER TOGETHER - in the only vocabulary the
world has, and nothing in the game has to know what "two players" means: the
accumulator adds up whatever is leaning on the rock, which is why three and
four players work with no special case.

### Momentum and the slide

Horizontal speed ramps at 40 m/s² and sheds at 30 (a third of that in the air).
Walking is unchanged; a sprint takes a third of a second to build and 2.8 m to
shed. A world whose content axis is distance cannot afford a sprint that stops
dead.

Over **45°** on alpine, rock or snow, a player **slides** downhill at half of
gravity's downhill component, capped at 8 m/s, and stops stepping up over
ledges while sliding. Meadow, forest and rock do not slide at any angle: a
world where every steep face is a slide is a world where you stop trusting
slopes, and the surfaces that give way are the ones you can see are loose.

Ground friction is per zone - meadow 0.9, forest 0.8, rock 0.7, alpine 0.45,
snow 0.3 - so a boulder's run-out depends on *where* rather than on how hard it
was hit.

### The host owns all of it

Bodies are simulated on the host and nowhere else. **No RPC moves a body.** A
client's push is an *input* - it is walking into the rock - and the host
measures the contact and applies the impulse. "Move this rock to here" is the
single most useful message a cheat could send, so it does not exist.

Every physics constant above is a starting value, tuned blind. Nobody has
pushed a rock yet.

## Mounts

Planned for v0.3+. Speed and flavour, not a combat system.

## Multiplayer

- Host-authoritative, and since world feel v1 that is literally true:
  **clients send input, the host simulates, the host broadcasts.** A client
  can only move itself, and only the way the rules allow.
- **Reconciliation.** The local body keeps predicting with the same movement
  step the host runs, so there is no input latency on your own legs. When the
  host's position for you arrives: under 0.25 m, nothing (the host is
  permanently about one packet behind, and correcting that is a tremble); up
  to 2 m, ease it in over 100 ms; over 2 m, snap, because at that distance the
  two simulations are telling different stories and easing would drag you
  through rock. No rollback in v1 - see the README's provisional list.
- The host streams a small collision ring around every remote peer, so a
  friend 500 m away has ground under them and rocks to push. That is the cost
  of authority and it is measured in `--pair-probe`.
- Host-authoritative. 1 host + up to 3 clients, 4 players maximum.
- Balanced around 2. Solo runs, but is a dev convenience, not a supported mode.
- All players must run the same build.
- ENet now, GodotSteam later behind the existing `NetTransport` interface.

The architecture contract these obey is in the README.
