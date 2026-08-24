# Design

Settled details. Terse on purpose - this is a working doc.

Subject to the three pillars in the README. A line here that contradicts a
pillar is a bug in this file, not a licence to bend the pillar.

## Setting

Fantasy. Cozy but adventurous.

Playable races are described under Character identity below.

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

Target height ~24-32 model voxels. *(Unconfirmed - the spec was truncated at
this number. Verify before building anything on it.)*

Implication worth stating outright: at 4 terrain blocks (2 m) tall, a 24-32
voxel character means **model voxels are roughly 6-8x finer than world blocks**.
Characters and terrain therefore do not share a voxel grid, and the chunk mesher
is not the character mesher. Two systems, not one.

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

Bounded, not infinite: one fixed 1.5 x 1.5 km region. Blocks are 0.5 m, so a
player is 4 blocks tall.

Bounded is a feature, not a limitation - it is what makes a global heightmap
affordable, and a global heightmap is what makes real per-basin lakes possible
at all. You cannot find a depression by looking at one chunk.

Rendering is voxels near the player and a low-poly heightmap mesh far away.
Terrain generation targets are in `plans/terrain-v1.md`.

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
