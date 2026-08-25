# Design

Settled details. Terse on purpose - this is a working doc.

Subject to the three pillars in the README. A line here that contradicts a
pillar is a bug in this file, not a licence to bend the pillar.

## Setting

Fantasy. Cozy but adventurous.

Playable races are described under Character identity below.

## Art direction

**Settled by look v1 (2026-08-25): the Art Deco Alpine travel poster.** The
1920s-30s railway and resort posters of the Alps - Broders' PLM series, the
Swiss lithographs of the same decade. Flat colour fields, mountains as stacked
bands, warm sun and cool violet shade, stepped geometric forms, a sun with
rays, one gold accent. The travel-poster strand of Deco, never the Manhattan
strand: no chrome, no glamour, no city. The world is cozy-Alpine; Deco is how
it is drawn - world, characters and UI alike.

Why it fits and not merely looks nice: Deco is built from steps and facets,
which is what a voxel terrace and a low-poly far range already are. Under any
other colour language they are artefacts; under this one they are the
vocabulary.

Five rules. Everything drawn obeys all of them; a feature that cannot is drawn
differently.

1. **Two tones and a shade.** A surface is lit, half-lit or in shade - three
   flat bands, no gradient across a face. Shade is a *colour* (blue-violet),
   never a darkness. Shadows are hard-edged and that colour. This is pillar 2
   made visible: warmth is safety, and a campfire is the one warm thing in a
   cool night.
2. **No texture, no specular, no gradient.** Colour variation is per-block
   jitter and altitude/aspect banding, never a map.
3. **Distance is bands, not haze.** Fog steps in flat bands to the sky's
   horizon colour; the far field is a stacked backdrop, the near field a solid
   voxel world, and the seam between them is owned rather than hidden.
4. **Forms are stepped and chamfered.** Heads lose their vertical edges to a
   chamfer, shoulders step, hair is a geometric mass. Trees are cones and
   ziggurats (not yet - see IDEAS).
5. **One accent.** Gold `#C9A24A`: UI rules, the sun disc, later the
   campfire's light. Nothing else in the world is gold.

Where it lives: `scripts/world/look.gd` holds the one lighting ramp every
shader in the game is built from, the banded fog and the sky; `SkyCycle`
publishes the shade and fog colours by time of day; the UI theme is
`assets/ui/deco_theme.tres` (paper `#F2E8D0`, ink `#1E2430`, gold, alpine blue
`#2F5D8A`, sun `#E8863A`; Limelight for titles, Josefin Sans for body).
`docs/plans/look-v1.md` is the full argument.

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

Three slots, **all visible on the character**: weapon, torso armour, trinket.

Visible gear is the cozy progression payoff. Your character sitting at the
campfire *is* the progress screen - which is pillar 2 doing its job, so keep the
silhouette legible as gear changes.

## Art pipeline

**Architectural requirement. Expensive to retrofit, so it is settled now.**

Characters are modular voxel models on a simple skeleton - head, torso, arms and
legs as separate parts.

- **Races** = part sets plus proportions.
- **Customisation** = palette swaps plus part picks.
- **Gear** = models attached to bones, or part swaps.

**Settled by character v1, re-settled by look v1.** One model voxel is **1/16
of a block, 3.125 cm**, and a human is **64 voxels = 2.00 m**. (Character v1
built them at 1/8; look v1 halved the voxel for the detail a face and a hand
need, and re-authored every part.) Characters and terrain therefore do not
share a voxel grid, and the chunk mesher is not the character mesher: two
systems, not one, and they meet only in the material and the baked-AO rule.

The four races, at the crown, all built and measured:

| Race | Height | Silhouette |
| --- | --- | --- |
| Human | 64 vox, 2.00 m | the reference: square, stepped shoulders |
| Elf | 72 vox, 2.25 m | tall and narrow, ears six voxels out each side |
| Dwarf | 48 vox, 1.50 m | as wide as it is tall, and always bearded |
| Lizardfolk | 60 vox, 1.88 m | tail, crest, snout, leaning 8 degrees forward |

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

Bounded, not infinite: one fixed 3 x 3 km region. Blocks are 0.5 m, so a
player is 4 blocks tall.

*Was 1.5 x 1.5 km through terrain v1. Doubled in terrain v2 Stage 6, once
sprint existed to cross it — see Traversal below.*

Bounded is a feature, not a limitation - it is what makes a global heightmap
affordable, and a global heightmap is what makes real per-basin lakes possible
at all. You cannot find a depression by looking at one chunk.

Rendering is voxels near the player and a low-poly heightmap mesh far away.
Terrain generation targets are in `plans/terrain-v2.md`.

### Scale: the world is 1:4 against reality

Every object in the world is a quarter of its real-world size, and the value of
saying so is that ONE ratio has to appear on every line. The eye judges size by
comparison, so an object at 1:10 standing next to one at 1:4 does not read as a
small world - it reads as a broken one.

| Thing | In game | Real equivalent |
| --- | --- | --- |
| Tree | 5 - 10.5 m | 26 - 42 m spruce, beech, larch |
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
| The landscape, from across a valley | 1:4 | terrain, lakes, **trees** |
| The player, from two metres away | 1:1 | the character, **grass, flowers, ferns, boulders** |

A tree is landscape. You judge it against the slope it stands on and the
treeline above it, so it is drawn at 1:4 like the mountain behind it, and a
10.5 m spruce reads as a 42 m spruce.

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

Rendering was never the constraint. Since terrain v2 the far field is built in
LOD rings, so its cost is roughly logarithmic in view distance - 80k vertices at
600 m, 82k at 800 m. **Traversal was the constraint**, and it still is.

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
  trees "that were not there at lammas").

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

Creatures follow the poster art direction (see Art direction, above):
silhouette-first, readable as flat bold shapes at distance, restricted
palette, and the same voxel-part modularity as characters where possible -
the critter rig and `tools/parts_author`.

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

Breaking terrain is a separate question and is not settled.

## Mounts

Planned for v0.3+. Speed and flavour, not a combat system.

## Multiplayer

- Host-authoritative. 1 host + up to 3 clients, 4 players maximum.
- Balanced around 2. Solo runs, but is a dev convenience, not a supported mode.
- All players must run the same build.
- ENet now, GodotSteam later behind the existing `NetTransport` interface.

The architecture contract these obey is in the README.
