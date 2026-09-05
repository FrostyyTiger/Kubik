# Design

Rewritten 2026-09-04 against the bible as of D84; where an older document
disagrees, the bible wins.

**What this file is now: the game's technical truth.** How the engine draws,
what a body is, what the grains are, how the camera and the physics and the
multiplayer work, and what the code must make true. Terse on purpose - this is
a working doc.

**What this file is not any more: the direction.** The setting, the peoples,
the art rules, the scale of the world and the roster of what lives in it are
decided in `../../Kubik-bible/`, by numbered decision, and this file points at
them rather than restating them. A sentence here that disagrees with the bible
is a bug in this file.

| Question | Answered in |
| --- | --- |
| Tone - the thing above everything | `../../Kubik-bible/00-TONE.md` (D38, D39, D40) |
| Setting, peoples, magic, geography | `../../Kubik-bible/lore/` |
| Art: pillars, colour, terrain, architecture, characters, UI, scale | `../../Kubik-bible/style-bible/` |
| Every decision, numbered | `../../Kubik-bible/03-DECISIONS.md` |
| The director | `../../Kubik-bible/director/`, pointed at by `DIRECTOR.md` |
| What in this repo stays, is adapted, is ripped, and in what order | `../RECONCILIATION.md` |

Subject to the four gameplay pillars in `../README.md`, which sit under the tone
and beside the bible's five art pillars. Where a section defines things the
director could one day steer - creature goals, what a place is, lore
fragments, a quest's beats - it defines them as DATA, per the three habits in
`../CLAUDE.md`. Nothing here depends on the director existing.

## Setting

**Pointer, not a summary.** `../../Kubik-bible/lore/00-overview.md` and the
four files beside it. The three things this repo's code has to know:

- **Three ages (D22).** The Builders, gone, who left the black-and-gold
  monuments. The mountain folk, fading, in the alpine heartland. The
  Engineers, rising, in one valley with coal, iron and a dam site.
- **Rings, not regions (D26, D44, D63).** Wildness, weather, ruin size, lit
  windows and how strong the magic is are all **distance from the Engineers'
  capital**, rings 0 to 4. The terrain is unbounded and seeded with no wall;
  it is the CONTENT that is ringed and ends, at the Builders' city on the
  farthest island. Ring geography:
  `../../Kubik-bible/lore/10-geography.md`.
- **Magic is distance, not altitude (D63, replacing D23).** Thin at the
  centre, stronger with every ring out. Height is not a rule. The rings are
  drawn so the high places fall on the heartland's rim, which is why the
  peaks are the first strange ground; the game may still compute "out" from
  altitude and distance together as a danger dial, but the world's law is
  distance.

The spine of the fiction, because it decides what the world is full of
(D60, D61, D69, D74): **one act, joining crystal and machine, with three
answers.** The Builders did it and it ended the world. The Engineers do it
badly, burning crystals for power, and it costs. The mountain folk refuse it.
The players learn it. `../../Kubik-bible/lore/30-magic-and-tech.md`.

## The renderer

**Direction: `../../Kubik-bible/style-bible/00-pillars.md`, pillar 2** - real
light on flat cubes, through a film lens; no textures, on anything, ever; one
body colour per material in three shades plus per-cube noise; mood comes from
light, fog, the hour and the lens, never from repainting. Plus D40 (the film
lens), D5 (the neutral alpine day), D8 (shadows), D18 (clouds).

**Built by light v1**, merged 2026-09-04. `plans/light-v1-tech.md` is
the argument, `status/light-v1.md` is the measurement, and what follows
is what the code now does.

1. **The engine lights; the material only says what a surface IS.** There is
   no lighting ramp and no custom `light()` anywhere. A real directional sun
   with a one-degree angular size, soft shadows tinted by the sky through
   full sky ambient off a `PhysicalSkyMaterial`, SSAO, volumetric fog, SSR and
   an AgX tonemap do all of it. A material declares albedo, roughness,
   specular and - on the two things that glow - emission. Measured, because D8
   is a measurable claim: a tree's cast shadow on open ground reads **V 17.6
   at hue 206.5 against a sky at hue 214.0** - never black, and eight degrees
   off the sky's own colour.

2. **One body colour in three shades, and only one of them is authored.** A
   block carries the **base** hex and nothing else; the shade and the light
   come from the sun and the sky falling on it. Between them sits the bible's
   per-cube noise - one step up or down on random cubes - as a step on the
   `grain_sparse` share of half-metre cells by `grain_step`, at every
   distance, because a material fact does not fade with range. Five paint
   operations were deleted from the C++ far mesher and its GDScript twin in
   one commit to make room: baked corner AO, a slope tint, an aspect tint
   against a fixed compass direction, a per-vertex hash jitter, and an
   altitude band that stepped a mountain's colour every 60 m. `ao_strength`
   survives as a knob at 0 so the old look can still be photographed.

3. **Distance is the same paint, coarser, and fog is a ramp.** The far field
   is the same world made of bigger blocks, terraced with lit tops and shaded
   risers - lit and shaded by the sun, not painted that way. A far cell is one
   real material chosen by a majority vote over sub-samples, never a blend,
   and trees v3 sends the same sculpted trees out as fat-voxel level-of-detail
   rungs, so the forest obeys the rule too. **Under D84 the fog is normalised
   to the draw distance and is never a wall**, and horizon v1
   (`plans/horizon-v1.md`) is the lane that makes that true out to 32 km
   with one colour source shared by every level. Until it lands the far mesh
   still re-derives colour per ring and a mountain changes colour on the walk
   in; that is the fault the lane names, not a rule.

4. **Forms are stepped and chamfered, and everything stays on the grid.**
   "Sculpted" is achieved with steps, never with rotated geometry in the world
   mesh. Heads lose their vertical edges to a chamfer; the chamfered purchased
   tree meshes stay rejected, in both repos.

5. **One accent.** Gold `#C9A24A` (D9, D3): UI rules, the sun disc, trim on
   the things the world honours, the campfire's light. Nothing else in the
   world is gold, and gold is never the body of a thing. The gold has an
   hour - `Look.accent_color()` reads the keyframe table.

6. **The film lens (D40).** Halation gated to emissives by an HDR threshold, a
   muted grade, and grain and a vignette after the tonemap. Its three fences
   hold and are measured: a one-cube gold line still reads at 100 m at
   **+23.6 saturation over the meadow and 4 px wide**, there is **not one
   clipped white pixel** in any hour shot, and every mid-frame surface is
   **within 1 V** of its lens-off twin.

**The hours are the bible's four plus a weather** (D5, D6, D7, D16, D52). Day,
evening (pink), dusk (violet) and night (slate), with eerie as a dictionary of
overrides applied on top rather than a fifth hour. A day is **forty minutes**
(D52) and the sun slows threefold across the evening, measured at **360 s**
and asserted by the self-test.

**Fog does its three jobs** (D16, and the tone's "fog hiding the tops of
things"). Aerial perspective to the sky for distance; `FogVolume` bands that
lie in the valley and move with the tracked floor rather than with the camera;
and an eerie lid that puts the summit **within 3.5 V** of the sky beside it.

**Water is clear and reflects** (D5). Tinted by how much water the eye looks
through, read from the depth buffer, with a Fresnel term driving alpha and SSR
for the ranges. No rings, no waves.

**Two rulings stand beneath all of it.** Warmth is in the light, coolness is
in the shade, and the albedo has neither - a palette entry is the thing's
colour in flat noon light, and nothing bakes a cast into an albedo. And what
is authored is what is on screen, proved by the transfer sheet before anyone
judges a colour through a changed stage.

**Two things the old art-direction section carried are gone, by name.** The
"Art Deco fantasy" register cut of 2026-09-01 and its two taste gates, the
KNIGHT TEST and the BELONGING TEST, described a poster-versus-painting
argument the bible settles differently: pillar 2 is real light on flat cubes,
pillar 5 puts deco on the built and never on nature, and Art Nouveau is on
paper only (D2). The nine-render reference set and
`kubik-knight-demo.bbmodel` are Marcel's own material and are not direction.
The style bible is the bar now.

### The pipeline: linear maths, sRGB on the wire

Every palette in the game is stored **linear**. The **one** conversion is
`Look.to_wire()`, called by each mesh builder on its final colour at
`push_back`, because the renderer decodes an 8-bit vertex colour on the way to
the shader; push linear and it is decoded twice. Since light v1 Stage 3 there
is nothing else in the path at all: a far vertex is `Look.to_wire(zone
colour)` and a near one is `Look.to_wire(Block.color_of(id))`, one line each.

`ALBEDO` is the albedo. It travelled as a varying to a custom `light()` while
the ramp existed, because that function owned the whole expression; with the
ramp gone the engine multiplies albedo by its own light and there is nothing
to apply twice.

**The transfer sheet is what keeps this honest**, every stage:

```
godot --path . scenes/character/gallery.tscn -- --sheet transfer --strict --label <name>
```

Eight authored colours through an unshaded material with the tonemap forced to
LINEAR and the glow, the grade and the atmosphere switched off for the sheet
alone and restored after. Tolerance **6 units per sRGB channel**, never
widened; `--strict` makes a miss a non-zero exit. Across light v1's stages it
read a worst channel delta of **1 to 2 of 6**, through the poster renderer and
through the one that replaced it - which is the claim: exactly ONE conversion
between `push_back` and the frame.

Its sibling `--sheet light` is a **measurement and not a gate**: the same
eight through the real material under the real environment, lit and in shadow,
at each of the four hours, written to `light.json`. The bible's hexes are
starting points, so a delta there is a finding rather than a failure - and
light v1 sent seven such findings back (`status/light-v1.md`), including
that a physical sky cannot be made violet at dusk and that seven palette rows
are silences.

**Where it lives.** `../scripts/world/look.gd` holds the one opaque shader every
vertex-coloured mesh in the game is built from, the water shader,
`Look.configure_environment()` - which lights the game AND the gallery's
sheets, so a colour judged on a sheet means what it means in the world - and
`Look.to_wire()`. `SkyCycle.KEYFRAMES` is the time-of-day table and the only
place an hour's colour is decided; `SkyCycle.HOURS` holds the four as sun
elevations and `time_for_elevation()` inverts the arc, so the tour, the light
sheet and the table all name the same hour. The film lens is
`../scripts/ui/lens.gd` plus the glow and the grade in `configure_environment()`;
the valley fog is `../scripts/world/valley_fog.gd`.

The UI theme is `../assets/ui/deco_theme.tres`. **It is on the redo list**
(`../RECONCILIATION.md` § 6): deco geometry on paper is the exact don't in
`../../Kubik-bible/style-bible/80-do-dont.md`, and under D2 the paper layer is
Art Nouveau - frames, tarot cards, halo portraits, a serif body face, no black
ink. The behaviour underneath the ornament stays.

## Character identity model

Three layers, each answering a different question.

| Layer | Question | Chosen |
| --- | --- | --- |
| **Body type and people** | who you are | once, at creation |
| **Gear** | what you do | moment to moment |
| **Skills** | what you've done | never - it accrues |

- **Body type is cosmetic, and there are no perks (D51, amended by D70).**
  Never stat modifiers, and now not even a situational one. A body must never
  be the correct answer to anything.
- **Gear = what you do.** No classes, ever. Roles emerge from what you carry:
  holding the staff makes you the mage today. **Never punish switching** - no
  proficiency penalties, no lockouts, no respec cost.
- **Skills = what you've done.** Skill-by-use, growing silently from
  behaviour. Nothing to allocate, nothing to choose.

## Body types and starting people

**There are no races.** D37: only humans, one people split by how their
ancestors answered the fall. D70 amends it and goes further: **nobody
changes.** The elf and dwarf look is cut completely - the ears, the
beard-as-identity and the winged helmets are stripped by script - and the
purchased elf and dwarf packs are used as **lean** and **stocky** human
bodies. Identity is hair, hat and colour. The far islands hold Builder things
and creatures, not changed people.

**The launch set of four races is ripped** (`../RECONCILIATION.md` § 5).
Human, elf, dwarf and one exotic reptilian fourth, their perk column,
`../scripts/character/races.gd`, that fourth race's authoring script and its
rows in the parts data all go. The fourth had no purchased asset and no place
in the bible's lore at all; the four perks were two IOUs, one stat
modifier that the identity rule forbade in the paragraph above it, and one
that mitigated the game's own central tension.

**What replaces it, at creation (D51, D66, D70):**

| Row | Choices | What it sets |
| --- | --- | --- |
| Body type | square, lean, stocky | proportions only. No perk, no stat, no lock. |
| Starting people | mountain folk or Engineers | soft: the first campfire's place, the starting kit, the starting recipes, and who greets you by name |

The starting people (D66) is **never stats and never a lock**: mountain folk
start at a village on the rim of ring 1 with a bow and a rune stone; Engineers
start at the edge of the capital's valley with a crossbow and a lamp. The
other people's knowledge is learnable by walking there. Both players may pick
the same people; one of each is the natural pairing and is never forced.

**Silhouettes still have to read at distance in dim light** - half this game
happens at dusk - and that requirement survives the rip intact. What changes
is what it is built ON: the old silhouettes were separated by ears, a beard
and a snout, and the three template families are re-read as lean and stocky
humans. That cost is named in D70 and is the game side's to pay.

The peoples themselves, their colours, buildings, clothes and what each
teaches: `../../Kubik-bible/lore/20-peoples.md`.

## Character creation

One screen. Body type, starting people, palette swaps within the bible's dark
bases plus gold trim, hair or hat, name.

**No sliders. No stats. No perks.** The table-driven screen survives the rip;
the race row becomes the body-type row and gains the people row.

## Skills

Five at launch: **Blades, Bows, Magic, Mobility, Gathering.**

- XP comes from doing the thing. Diminishing curve. **No decay, ever** -
  putting a weapon down for a month must never cost you anything.
- Rewards are two-speed: smooth small bumps every level (swing speed, draw
  time, stamina cost), plus a chunky unlock roughly every five levels.
- **Numbers stay small: about +25% total by level 10.** The real power curve
  is two players getting better at the game together, not their characters
  getting better at it for them.
- UI: a character sheet screen from the start, plus a small toast on level-up.

**The sheet is read-only.** The moment it lets you spend anything it becomes
the skill tree this design rejects, and the third pillar goes with it.

## The knowledge layer

**New under the pivot (D74), and capped by D80.** Magic is not broken; its
KNOWLEDGE is. Using magic beyond what you know breaks - a rune misfires, a
crystal cracks, an engine runs wild - and further out it breaks harder for the
ignorant and gives more to the informed.

Three sources hold the pieces: the mountain folk teach handling, in villages;
the Engineers teach work, in the capital; the Builders hold both at once, in
fragments found in ruins outward. **Trust is the party's, never one player's**
(D82), so two co-op partners' starting choices never fight each other.

The ladder, **five steps for the whole game**, and no more:

1. a rune that fires every time
2. a crystal lantern that does not die at the edges - the first join
3. a rune stone shot from the crossbow
4. a rune that works in strong magic without breaking
5. a crystal engine that runs where the Engineers' cannot - the way past the
   airships' range, written as the endgame's horizon (D81) and depended on by
   nothing

**Hard limits, so this does not bloat into the skill tree the design rejects
(D80):** recipes plus a handful of unlocked verbs, riding the director's
existing `place_fragment`; **never a tree**; knowledge is found or taught,
never levelled; it never punishes switching; **at most one page in this
document, and this is it.** The game is complete without the director - the
fragments are authored sites, and the director only points at them.

## Runes

**Two, no more** (D65, amending D54; D76).

- **Fire rune** - a small burn over time.
- **Frost rune** - a brief slow.

They were the fire bolt and the frost bolt; D65 makes them runes with the same
mechanics. **Runes are magic written down - the mountain folk's engineering.**
A rune is a spark or a chill, never a storm; nobody throws lightning, and
mages call weather rather than throwing fireballs. Designed as co-op glue: one
player slows, the other finishes. No elemental matrix - a combination table is
a Someday, not a v1. A ward rune, a small safe circle for the co-op revive, is
also a Someday.

**They obey distance, not altitude (D63).** Weak in the thin centre of ring 0,
stronger with every ring outward. The old sentence "stronger with altitude"
came from D23 and D23 is replaced.

**A rune stone is a crystal, and it fades (D76).** Carved once, thrown by hand
and fetched back like a spear, it dims with use and is recharged at a magic
site: **one durability number, the same rule as the Engineers' crystals.** The
player is on the supply chain too, on purpose, and this is the theme made
mechanical - it is never narrated. Consumed-per-throw was rejected because it
pushes everyone to the bow; infinite was rejected because it breaks the theme.

The `mp` stat stays (D54). The same stone shot from the crossbow is step 3 of
the knowledge ladder.

## Gear

**Six slots, all visible on the character**: torso, shoulders, back, head,
legs, hands. Four ship with geometry; **legs and hands are declared with
none**, so filling them later costs art and not a wire-format change. The
order is the share of the SILHOUETTE each one owns: torso is 38%, back is 15%
and reads at 40 m, shoulders are the only slot that grows the outline outward
at the widest point the character has.

Visible gear is the progression payoff. Your character sitting at the campfire
*is* the progress screen - the second pillar doing its job - so keep the
silhouette legible as gear changes.

**Armour is a tech level, not a tier ladder (D27).** Mountain folk in leather,
fur, wool, felt, mail, wood and horn; **plate is the Engineers' guard**, and
the purchased knight becomes an Engineer knight. There is no ladder that
climbs to plate, because plate is a faction's uniform and not a rung. The
five-tier ladder in `armour.gd` and its 1.1 MB of authored pieces are ripped
(`../RECONCILIATION.md` § 5); it never passed its own gate.

**Two sentences survive the rip, because they are true of any authored set:**

- **Proportions relative, thicknesses absolute.** A piece is described in
  fractions of the attachment's own width, height and depth and stamped into
  each body's real dimensions, but its plate is the same number of voxels
  thick on everyone. Scale the thickness too and a stocky body's armour looks
  like foam rubber while a lean body's looks like it was cut from sheet tin.
- **A tier, where one exists at all, is a ladder of OUTLINE EVENTS.** With no
  textures on anything, ever (pillar 2), surface detail is free to author and
  invisible at range: the outline is the only currency a piece has. The
  gallery's `--sheet outline` counts them rather than judging them.

**The ranged set (D64)** is manufacture, the same rule as armour: **the bow is
what anyone makes, the crossbow is what the valley makes.** The set is bow
(the mountain folk's, the players' main ranged), thrown spear, sling, crossbow
(the Engineers' guard; the rune launcher IS the crossbow, with the rune stone
as one ammo and a plain bolt as the other) and the rune stone itself. The
round shield is made by script and its parry clips exist. **Enemy ranged is a
creature, never a person**, outside story beats. **No gunpowder anywhere in
the world (D62)**: the valley gave the Engineers coal and iron and never
sulphur, which lies on the volcanic far islands past the airships' range. By
asset cost the build order is sword, staff, spear, then bow.

**Head items leave their wearer's identity intact or replace it in kind.**
Under D70 identity is hair, hat and colour, so a full helm now costs less than
it did - but a village of identical helmets is still a village of nobody.

None of this is an item system. There is no item table, no inventory, no drops
and no rule about what grants a piece; **Items v1 owns all of that.**

## The character pipeline

**Architectural requirement. Expensive to retrofit, so it is settled.**

**The characters are the bought templates, used as they are (D1).** The
viking, dwarf and elf packs, reskinned clothes only, rigs and proportions
unchanged, driven by the packs' own clips - 150 to 200 of them per pack.
**Nothing generates a body.** The templates measure 59 to 69 fine voxels tall
at about three heads; with the player at four world cubes (2 m), one character
voxel is about **3.3 cm**, roughly 15 per world cube.

**The generated-parts kit is ripped** (`../RECONCILIATION.md` § 5):
`../tools/parts_author/` at 2,912 lines and `../assets/characters/parts/` at 32,897
lines and 1.8 MB. It authored every part in ASCII at a grid that moved three
times - 1/8, then 1/16, then 1/24 of a block - and re-authored every part each
time. Under D1 the bodies are bought and none of that is the character path.
The JSON is parked, not deleted, until the round 3 scene passes.

**What is promoted instead:** `../scripts/character/purchased_view.gd`, the only
bible-shaped character path in the repo. It becomes the path `CharacterView`
takes; `LocomotionState` drives the clip selector over the packs' clips;
`rig.gd` stays for rigid props on sockets; the animator's additive layers
(head look, blink, idle breaks) stay. That is phase 3, people and fire.

**The collider is identical for every body** - a capsule, radius 0.4 m, height
2.0 m, with the camera pivot at 1.5 m. Body type is never a stat. No per-body
number appears in `player.gd`, and that survives the rip unchanged.

**Deleted with the four races: the silhouette gate as it was written.** The
`masks-40` sheet's target of every race pair under 0.70 was a claim about four
races that no longer exist. Three body types of one people are SUPPOSED to
overlap; what has to read at 40 m at dusk is a person, with a hat or a hood.
The instrument stays and its target is round 3's to set.

### Parts are data

Where a part IS authored in this repo rather than bought, every voxel of it is
authored as **ASCII slices in semantic slots** - `S` skin, `H` hair, `E` iris,
`C` cloth, and nine more - never as colours and never as box primitives in
code. The same voxels through a different resolve table are a different-looking
character, which is what makes a palette swap free and what lets the creation
screen rebuild the model on every click. This is habit 1 in `../CLAUDE.md` and it
outlives the kit that used it.

### The drop-in rule

If `../assets/characters/<body>/<part>.vox` exists, it **replaces the ASCII part
of that name at load, with no code change**. MagicaVoxel art whose palette
indices 1 to 13 are the thirteen slots takes skin and hair swaps exactly as
ASCII does; art in arbitrary colours still loads and simply does not. See
`../assets/characters/README.md`. This is the rule the purchased templates
arrive through.

## Characters and saves

**The character lives in the world, on the host.** One save file holds the
world's edits and every character in it.

Consequence, accepted knowingly: a character cannot leave the world it was
made in. If you are not hosting, your friend cannot play that character, and a
new world means everyone starts over.

The alternative considered and rejected was Valheim's split - character on the
client, world on the host, carried between worlds. Rejected because it
requires the host to trust a client's claims about its own stats, and keeping
one authority for everything is worth more to us than portable characters.

## Camera

**Decided by D57.** Third person only, never first person. A Cube World orbit:
the camera hangs behind and a little above the player on an arm, the mouse
orbits it freely, the body turns to where it walks, and **the scroll wheel
zooms the arm in and out** - Marcel: "that is important". The default sits near
the close end, so the player reads as a character rather than a figure in a
landscape.

| Camera | Value |
| --- | --- |
| Default arm | **4 m** - the player is about a third of the screen height |
| Zoom range, scroll wheel | **2.5 m** (over the shoulder; the rig hides when the camera enters it) to **8 m** (a small figure, landscape first) |
| Pitch | -70 to +35 degrees, default 15 degrees down |
| Field of view | 75 degrees vertical, about 105 horizontal on widescreen (D55) |
| Collision | the arm collapses against walls and terrain rather than clipping |
| First person | none, and not planned |

**What the repo has today:** the orbit, the body turn, the pitch range and the
field of view, on a fixed **5 m** arm with no zoom - a quarter of the screen
height rather than a third. The zoom and the 4 m default are owed, and they
are what the character grain is for: 59 to 69 voxels and three heads are
wasted at 8 m.

**The pitch is what carries the vista rule (D45), not the arm length.** A
whole mountain fits in frame at 4 m as it does at 8 m, because angular size
does not change with the arm; what guarantees the vista is the horizon (D41,
D84), the pitch range, aerial perspective and sightlines as a worldgen rule.

A free-fly / noclip toggle exists behind a debug key, with a developer
teleport and a fast fly added by horizon v1. They are tools, not modes.

## World

**The world is as big as the view (D84, 2026-09-04, the north star).** Three
things outrank every knob in this repo and every older sentence in this file:

1. **The world is as big as the view.** Terrain on demand, no edge, no region.
   Terrain exists wherever the player or the far view asks.
2. **The view reaches the horizon.** 32 km on a clear day, raising D41's 10 km
   floor; fog is a ramp normalised to that distance and **never a wall**;
   nothing pops in.
3. **The frame holds.** 60 FPS at max settings on mid hardware - an RTX
   3070 Ti - measured while sprinting through forest; well above that on a
   5080. Graphics settings come later; the north star first.

**Unbounded terrain, ringed content (D44).** The terrain is seeded and has no
wall and no edge. **No system may bake in a world edge, a global heightmap or
a global-extent assumption.** The content is ringed from the capital
(`../../Kubik-bible/lore/10-geography.md`) and ends at the Builders' city, the
last authored place; beyond it the seeded terrain goes on as sea and eerie
weather with nothing in it. Nothing generates "a region": terrain is built on
demand in **origin-anchored tiles**, at every level of detail, wherever it is
asked for (`plans/horizon-v1.md`).

**The home 3 km is bookkeeping, never an edge.** Lakes, spawn and the zone
shares are still computed inside it until the world-truth break, because a
basin needs a heightmap wider than any one chunk and you cannot find a
depression by looking at a chunk. A basin crossing a tile border is a real
problem to be solved, not wished away.

*History, kept so nobody re-derives it: the generated region was 1.5 x 1.5 km
through terrain v1, doubled in terrain v2 once sprint existed to cross it, and
was 3 x 3 km with the heightmap clamped at its edge and the far mesh ending at
1.2 x the fog distance until horizon v1. Marcel, playing light v1 on
2026-09-04: "I don't want it to be three square kilometers."*

**Precision.** Positions beyond 10 km use a **floating origin**, not a
double-precision engine build: the official Godot binary stays on every
machine and in CI (D84).

**Monumental against tiny** (art pillar 3, D45, and the tone's long
sightlines). The player should be the smallest thing in frame nearly always,
because feeling small against the world is what makes ranging into it epic -
and it is the second pillar's ratio at full stretch: the vaster and stranger
the out-there, the warmer one campfire is. Built things are 1.5 times real
size (D58) so that a house does not read as a miniature from the D57 arm;
trees, relief, people, animals and props stay real size. **Huge buildings are
the world's, not the players'**: "no base building" is untouched - the world
builds monuments, players place objects.

**The vista rule (D45).** From every campfire, village and pass, at least one
whole mountain and the next landmark fit in frame at the default field of view
and the default camera arm. **Sightlines are a worldgen rule**, not a hope.

**Heightmap terrain, placed volumes (D47).** The generator is a heightmap and
makes no overhangs. A mountain gate is a MODEL standing against a cliff, and
its interior is a separate chunk volume stitched in behind the door; dungeons
are the same. Decided before the landmark generator exists, because it changes
what the generator emits.

**Content is deferred, not denied.** Storylines and things to do are Marcel's
to solve later; the FEELING of scale must not wait for them. The named hazard
is Cube World's 2019 failure - vast and empty - and the answer is density near
and reasons to go far, never a smaller world.

Blocks are 0.5 m, so a player is 4 blocks tall.

Rendering is voxels near the player and a low-poly heightmap mesh far away.

**THE FRONTIER RULE, world feel v1: never a hole, at any speed.** The far mesh
and the impostor ring cut their inner edge to where the voxels have ACTUALLY
arrived - `World.loaded_frontier()`, sixteen angular sectors - and not to the
radius where the voxels are merely expected. Keyed to the radius, the hole
moved the instant the player crossed a chunk boundary and the voxels arrived
seconds later, so the ground ahead of a moving player was neither far mesh nor
voxels. That was 126 of 144 sprint samples with a hole in them; it is now
zero, and it is a hard rule rather than a target: overlap is invisible, a gap
is not.

### Scale: real relief, one ratio

**Real relief, one to one (D45), replacing a land a quarter of real size.**
Valley floor to peak is
**1,400 to 2,500 m**, and a mountain's base is several kilometres across. One
ratio everywhere: trees are already at real size (D21), so a quarter-size land
under real-size trees was a mixed-scale world, and the repo's own one-ratio
rule calls that a broken world - the eye judges size by comparison, and an
object at one scale beside an object at another does not read as a small
world, it reads as a broken one.

**This has not landed yet.** `world_scale` is still 4 and the relief is still
about 350 m. Real relief is world truth - it changes what a seed produces - so
it belongs to **the world-truth break**, the lane after upload v1
(D56 as amended by D84 and D85), together with rings measured from the capital, the
tiled heightmap store, lakes and zones per tile, and the generator's truth in
C++. They happen once and together, before any content is authored on a seed.

**The old rejection of full scale is overturned, and by what.** It was
rejected here on 2026-08-24 on two arguments. The SIZE half - a real mountain
does not fit in a 3 km world - is gone with the world's edge (D44, D84). The
TRAVERSAL half - what a player can reach on foot - is answered by the bible
and not by a smaller world: airships with a range (D24 as amended by D73), cog
rails and cable cars across the heartland, ferries to the near islands, and a
crystal engine that goes further as the last step of the knowledge ladder
(D81). Rendering was never the constraint: since terrain v2 the far field is
built in level-of-detail rings, so its cost is roughly logarithmic in view
distance - distance v3 bought sixteen times the visible ground for 262k
vertices to 323k, one more ring per doubling.

**The player is the deliberate exception at 2 m** against a real 1.75 m, and
that stands after the break: a life-size world with a 1.75 m player would move
the camera, the step height and the reach distance for nothing.

| Thing | Today | After the world-truth break (D45) |
| --- | --- | --- |
| Mountain relief | ~350 m (`world_scale` 4) | **1,400 to 2,500 m**, real |
| Forest tree | 21 to 28 m, authored at world size | unchanged - already real (D21) |
| Grass tuft, flower, boulder | 15 to 55 cm, real | unchanged |
| Largest lake | ~116 m across | scales with the relief |
| Player | 2 m | unchanged |

**Ground plants and boulders are read against the PLAYER, and so are drawn at
1:1.** The rule is not "small things are life-size", it is what the object is
read against: the landscape from across a valley, or the player from two
metres away. Nobody compares a blade of grass to a mountain - they compare it
to their own boots, and a 30 cm tuft at a quarter size is below the height of
the block it stands on.

**Trees stopped being scaled at all (trees v3, 2026-09-01).** The library
models are AUTHORED AT WORLD SIZE, like a character, so there is no read-scale
to apply; `tree_read_scale` still scales the placement table's height and
crown numbers, which is what the scan margin and the probe read, but nothing a
player looks at. **Old growth is a second tier on top**: about a third of
groves (`old_growth_share`) are a further 1.5x, with fewer trunks, further
apart, and crowns that touch. Contrast is what makes huge read - a forest
where every tree is a bit bigger is a forest with bigger trees; a forest where
one grove in three is enormous is a forest with old growth in it.

### The resolution ladder

Every object sits on a rung of voxels per world block, and the rung is chosen
by what the object is read against rather than by how much detail it could
carry. A block is 0.5 m. **Four grains (D1, D21, D43, D53):**

| | voxels/block | voxel | what |
| --- | --- | --- | --- |
| Forest animals | ~26 | **1.9 cm** | the purchased forest pack, one scale factor for the whole pack (D53): bear 1.9 m tall and 3.3 m long, wolf 1.2 m |
| Characters | ~15 | **3.3 cm** | the bought templates and everything they wear; the animal warriors (the Perchten) are at this grain and need no scaling |
| Trees, and generated buildings | 4 | **12.5 cm** | the whole tree, trunk and canopy together; and every generated house, landmark, castle and capital block (D43) |
| Shrubs | 4 | 12.5 cm | `SHRUB_A`, `SHRUB_B` |
| Boulders | 2 | 25 cm | `BOULDER_S/M/L`, scree |
| Terrain, and anything a player places | 1 | **50 cm** | the world itself, and the campfire, torch and marker |

**Buildings joined the tree grain (D43), and that is why the tree pipeline is
the building pipeline.** At the world grain a house was a toy up close - beams
half a metre thick, windows of two blocks, no frames. At 0.125 m it is about
30,000 voxels as a shell and bakes with the trees' three level-of-detail
rungs, so the 0.5 m version is the far view for free. The consequence is
owned: **buildings are models, like trees, and are not cube-editable.**
Whatever the players build themselves stays at 0.5 m. Thin things - beams,
mullions, frames, tile lines - may be one fine voxel. The coarse rungs keep a
cube only when at least a quarter of it is solid, not "any voxel" as the trees
do, so sills and frames do not fatten at distance (D59).

**Ground plants are at 8 voxels per block today and are an adapt, not a
grain** (`../RECONCILIATION.md` § 7 puts props at the character grain). A
face needs the detail and a tuft does not, and 8.7 million pieces of ground
cover at a finer grain is not a cost worth paying for the tuft; whichever
number wins, a plant is read against the player at 1:1, which is the
consistency the eye actually checks.

**The tree row is trees v3 and it closed the ladder.** Until then trees were
at 1 voxel per block - they WERE the ground, stamped as `Block.LEAVES` and
`Block.TRUNK` into the chunk volume - which is the one row that was off the
bottom of its own table. And the whole tree moved, not just the canopy: a
0.5 m block pillar under a 12.5 cm canopy is the same mismatch one level down.
The consequences are owned rather than avoided: a tree has an explicit trunk
collider inside the sim radius, "is there a tree here" asks placement rather
than the volume, and chopping - when it arrives - is fell-as-a-unit rather
than block-by-block.

### Traversal

Walk is 5 m/s, sprint is 2.6x that at **13 m/s** with Shift held, and the
field of view is 75 degrees vertical. **Both are logged as they are (D55)**
and revisited once real relief and the rails and airships carry the long
distances; 13 m/s sits against the tone's slowness and that is on the record.
Alt is a precision crawl for lining up a shot.

**The old six-minute sprint diagonal is retired (D84).** It sized a bounded
3 km map and there is no diagonal any more. What replaces it as the measure is
the sprint probe (`plans/horizon-v1.md`): whether the ground keeps up and
the frame holds while a player runs, which is the third leg of the north star.

**How the genuinely far is reached is the bible's answer, not the world's
size** (D24 as amended by D73, D81): cog rails and cable cars across the
heartland, one zeppelin line, the Engineers' ferry to the near islands, and
airships that have a **range, not a ceiling** - their crystal engines run wild
where the magic is strong, so their reach ends where the magic starts. Past
that is step 5 of the knowledge ladder and it is a horizon.

## Creatures

Nothing here is built yet; the first combat playtest is where it starts.

**The roster is the bible's, not a folklore grab-bag.** The old three-layer
register named a scree-worm, frost-folk and storm-beings and cited a
swamp-influences lore file under a docs/lore folder that **has never
existed in this repo**. Both go. What the world actually holds
(`../../Kubik-bible/lore/20-peoples.md`, D71):

- **Real alpine wildlife, stylised** - ibex, marmot, fox, wolf, eagle, fish.
  The familiar base, concentrated near the centre and in the valleys. The
  purchased forest-animal pack is this tier, at its own grain (D53).
- **Beasts that were once ordinary**, further out. The old magic does not make
  new species; it makes strong ones. Masks sit on things that are not people.
- **The animal warriors are creatures of the outer rings (D71)** - bear, wolf,
  moose, bison, eagle, at the character grain with 181 clips. **The Perchten
  themselves are not creatures**: in the heartland they are masked mountain
  folk in a winter rite, furs and carved masks, a practice and not a change
  (D70, D71).
- **Environment-interacting behaviour is a design priority across all of
  them.** Marmots whistle alarms and dive into burrows, fish shadows scatter,
  birds lift off when something big moves. Behaviour over anatomy: it is the
  cheapest form of "the world is alive", and ambient reactions double as
  player information - the marmot whistle is a danger radar.

### Danger structure: no painted zones

Spawning is driven by dials the worldgen has, and **two of them are different
questions** (D35):

- **Distance from the capital** - what the world IS here: biome, wildness,
  ruin size, weather severity, lit windows, how strong the magic is (D44,
  D63). Today this is `TerrainGenerator.danger_at()` measured from the map
  centre; measuring it from the capital instead is part of the world-truth
  break.
- **Distance from the current campfire** - what it FEELS like right now:
  threat and pacing. Deep in ring 4 but beside your fire is a safe pocket.
- **Slope and terrain context** - what the ground is, not where it is.
- **Time of day**, and eerie weather (D35, D16).

**Altitude is not a rule any more (D63).** It may stay in the danger dial as
one term, because the rings are drawn so the high places fall on the
heartland's rim, but the world's law is distance and the lore says only
"further out".

Players learn safety as a grammar - "we're far out, it's getting dark" - not
as map regions. Passive wildlife is the norm; hostiles are the exception,
concentrated by these dials.

### Hostile roster (launch)

Four to five archetypes, few but distinct, each designed for duo tactics first
(pillar 1), with dumb count-scaling for three and four players: **rusher,
ranged, ambusher, tank, swarm.** Concrete species are assigned to archetypes
later, from the bible's roster. **Enemy ranged is a creature, never a person**
(D64), outside story beats.

### Hunting: the honest rule

The real-wildlife tier is huntable for food and materials (ibex, fish,
boar-tier); hostiles drop materials. **Small ambient creatures - marmot-tier -
are not huntable.** They are the world's texture and information layer. No
mechanical punishment needed: they simply cannot be targeted. Nothing in the
world is written as cute (D38); the marmot is small, not adorable.

### Megafauna

A few RARE giant creatures as awe encounters, in the Pilatus-dragon register:
near-sacred, **witnessed more than fought**. Not bosses on a checklist -
encounters that make a session memorable. Designed later; worldgen should be
flagged that rare large-creature sites may exist. This is the tone's cosmic
dread at the edges: scale and indifference, never horror dressing.

### Night

v1 night changes creature boldness only mildly. **Raids on the fire and a
night-hostility dial are OUT** (`../RECONCILIATION.md` § 5): every dread beat
ends at a fire (D39), and a fire that gets raided is a fire that stops being
the warm register. What night is allowed to be is darker, quieter and further
from help.

### Mimics: the world that seems

- Some world-objects are creatures in disguise. First: the **mimic-tree**.
  Walk near it and it tears its roots free, shudders upright, and walks.
  Register: an old thing disturbed, not a horror jump-scare (D39).
- **Rarity is the mechanic.** Rough north star: a player meets single-digit
  mimic-trees across many hours.
- **Tells for the attentive.** A mimic leans against the slope's grain; birds
  never land on it; marmots won't burrow near it. The ambient-life information
  layer doubles as the detection system. Veterans get to READ forests.
- Archetype-cheap: ambusher or tank plus a unique reveal animation. The roster
  does not grow.
- **Escalation with distance (D63).** Near the centre the world is what it
  seems; further out, seeming frays. Deeper mimics - boulders, a copse, one
  day a hillside - are Someday.
- Lore hook: fragments may reference it obliquely. The fragment's TEXT may be
  directed; the fact that mimics exist is authored (`DIRECTOR.md`).

### The unprompted world: ambient aliveness as a design value

- The world's aliveness lives in things that happen without player cause:
  eagles crossing the sky, fish rising at dusk, marmot sentries whistling,
  wind-waves in grass, a distant rockfall, the rare tree that stands up. And,
  after the pivot, the Engineers' own clock: a rail cut higher than last
  season, a lamp gone dark in the capital, an engine running wild at a mine
  head (D77, D83). **Never spoken** - the burn is shown, not said.
- Each is a small local behaviour script, not a system. This is a jar we add
  one marble to every few sessions, forever.
- **First ambient-sky creature: the eagle.** Circles high on thermals along
  ridgelines, an occasional echoing cry, lands on far crags, never interacts
  in v1. A silhouette model, a slow orbit and one sound file: near-free, huge
  atmosphere payoff. Later it joins the information layer (circling marks
  large creatures and carrion) and the lore layer.

### Art

Creatures follow the renderer above and the bible's pillars: silhouette-first,
readable at range, one body colour per material in three shades plus per-cube
noise, and no textures. The purchased packs are the source
(`../../Kubik-bible/ASSETS-PLAN.md`); the parts kit that this section used to
name as the creature authoring route is ripped with the character kit.

### Behaviour: the technical stance

Settled 2026-08-25, for the creature plans to inherit, and untouched by the
bible. The game's theme is a world that is smart, so its animals must *appear*
smart - and the impressive part is never the decision library. It is
perception, communication, memory and terrain use, designed on top of whatever
runs the decisions.

**The seconds layer** - creatures decide on the host, and only on the host, so
nothing here needs to be deterministic; clients see positions and a state
byte.

| Need | Tool | Why |
| --- | --- | --- |
| Decision structure | **LimboAI** (MIT, C++ GDExtension: behaviour trees, hierarchical state machines, blackboards, a visual editor) | The best-maintained option for Godot 4 and fast enough for dozens of active creatures. Beehave (pure GDScript) is the fallback if the extension fights the build. |
| Ground pathfinding | Godot's built-in **`AStarGrid2D` over the coarse heightmap**, with per-species slope-cost weights | Not the navmesh: `NavigationServer3D` wants navmeshes re-baked per chunk on voxel terrain. The heightmap is already the grid the lakes and zones live on. Ibex flee uphill because uphill is cheap in their table and dear in a wolf's - terrain use as one weight table. |
| Herds, flocks, birds, fish | Boids / steering, written here | Eagle orbits, chough flocks, fish shadows, a herd's drift. |
| Needs-driven animals | Utility AI, written here: score actions by hunger, fear, curiosity | Marmot, deer, fox. The same animal does different things on different days, which is what "alive" reads as. |
| Planning NPCs | GOAP, written here or a small open implementation | Authored goals, planned path. |
| Learning agents | Not used | Non-deterministic, opaque, impressive in a demo and nowhere else. |

**The five rules that make them look smart.** Every creature plan states which
of these it delivers.

1. **Perception with senses, not radius checks.** Sight cones, noise events
   with a loudness, scent carried downhill on the wind. A wolf that only
   notices you upwind is a wolf players *learn*.
2. **Communication.** One marmot whistles and every marmot on the bench dives.
   One wolf finds you and the pack converges from different directions -
   pillar 1's flanking, mirrored back at the players.
3. **Memory.** A fled deer returns cautiously to the same patch; a hurt wolf
   keeps its distance. A blackboard entry, not a system.
4. **Terrain use.** Ibex on ledges you cannot reach, wolves out of the dark
   side of a slope, burrows placed at generation.
5. **Smart objects.** Burrows, crags, carrion and carcasses *advertise* what
   can be done at them. Animals then look purposeful for free, and the eagle
   circling over carrion falls out of it.

**Where the director does not go.** Nowhere near this. The director owns
minutes and acts through the verb list; behaviour trees, utility scores and
planners own seconds. The seam is a verb: the director may `mark_site` a
carcass as interesting; the wolves' tree decides what to do about it.

### The first combat playtest: a trio

One creature per layer of the world: the **wolf** (threat - the rusher), the
**marmot** (ground texture and information - whistle and burrow), and the
**eagle** (sky texture). It sits at phase 6 of the working order
(`../RECONCILIATION.md` § 9), behind the world-truth break, people and
fire, buildings and the round 3 scene.

## Combat

Simple and readable. If a player cannot tell what just hit them, it is wrong.

- Light attack, dodge / block.
- Weapon types with distinct feel. **Sword, staff, spear, then bow** - the
  build order by asset cost (D64).
- Encounters assume at least two bodies. Tuned for 2, must not go trivial at 4
  (D46).
- **Restrained (D39).** No blood, no gore, no dismemberment, no cruelty as
  spectacle. Larger-than-life themes, handled quietly. Write the restraint
  rule into the plan before the first hit lands.

## Death

- Downed player can be revived by any teammate.
- Whole party down, or nobody in reach: respawn at the last campfire.
- While dead, the camera follows a living teammate.
- **Costs time, not progress, and is quiet and remembered (D39).** Remembered
  is literal: a death is a journal event, and the journal is the director's
  input. Write that before the first death, not after.

## Placeable objects

A restricted palette of objects - **campfire, torch, marker** - placed into
the world, at the world grain (0.5 m). **Not terrain.** Players never place
raw voxel blocks.

This is the line that keeps "no base building" true. Give players arbitrary
blocks and someone walls off a cave and calls it home, whether we designed for
it or not. Restricting the palette means there is nothing to build walls from.

The campfire is also the game's most load-bearing object: the warm register
(light, regen, respawn), the pacing origin (D35), and the director's cadence.

## Physics

Added in world feel v1, night 2. Unchanged by the bible.

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

A short table (`../scripts/physics/body_table.gd`):

| kind | promoted from | mass | hold | what it means |
| --- | --- | --- | --- | --- |
| boulder_m | `BOULDER_M` decoration | 250 kg | 400 N | one player moves it |
| boulder_l | `BOULDER_L` decoration | 900 kg | 1000 N | two players move it |
| log | *(not promoted in v1)* | 120 kg | 150 N | reserved for felled trees |

A fraction of medium and large boulders - `body_fraction`, 0.15 - are pushable
rather than scenery, decided by a seeded hash so every peer agrees without
anybody sending a list. **Not all of them**: a world where every boulder rolls
has no landmarks in it, and you cannot say "meet me at the big rock" if the
big rock is wherever somebody last shoved it.

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

Horizontal speed ramps at 40 m/s² and sheds at 30 (a third of that in the
air). Walking is unchanged; a sprint takes a third of a second to build and
2.8 m to shed. A world whose content axis is distance cannot afford a sprint
that stops dead.

Over **45°** on alpine, rock or snow, a player **slides** downhill at half of
gravity's downhill component, capped at 8 m/s, and stops stepping up over
ledges while sliding. Meadow, forest and rock do not slide at any angle: a
world where every steep face is a slide is a world where you stop trusting
slopes, and the surfaces that give way are the ones you can see are loose.

Ground friction is per zone - meadow 0.9, forest 0.8, rock 0.7, alpine 0.45,
snow 0.3 - so a boulder's run-out depends on *where* rather than on how hard
it was hit.

*Every physics constant above is a starting value, tuned blind on a
land a quarter of real size. Real relief (D45) changes what a 45-degree face
means and
how far a boulder runs; re-tune after the world-truth break, not before.*

### The host owns all of it

Bodies are simulated on the host and nowhere else. **No RPC moves a body.** A
client's push is an *input* - it is walking into the rock - and the host
measures the contact and applies the impulse. "Move this rock to here" is the
single most useful message a cheat could send, so it does not exist.

## Mounts

Not on any phase. The traversal answer in this world is rails, cable cars,
ferries and airships (D24, D73, D81), which are the world's and not the
player's inventory. Taming and the *táltos*-horse pattern stay in
`IDEAS.md` § Someday.

## Multiplayer

- **Four allowed, two designed for (D46).** Host plus up to three clients.
  Every encounter, rumour and line of fiction is written for two, and **there
  is no party frame, ever.** Solo runs and is a dev convenience, never a
  balanced mode.
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
- **Terrain is never networked.** Both machines regenerate it from the seed
  and the worldgen config, and only edits travel (D56). All players must run
  the same build.
- ENet now, GodotSteam later behind the existing `NetTransport` interface.

The architecture contract these obey is in `../README.md`.
