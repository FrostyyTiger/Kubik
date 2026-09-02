# Audit: the game repo's direction documents against the bible

Scope: the direction documents of `/Users/marcel/Documents/Kubik`, measured against
`/Users/marcel/Documents/Kubik-bible` as the authoritative direction. Read in full:
`README.md`, `CLAUDE.md`, `STATUS.md`, `TODO.md`, `docs/DESIGN.md`, `docs/IDEAS.md`,
`docs/ROADMAP.md`, `docs/DIRECTOR.md`, `docs/research/art-direction.md`,
`docs/research/distant-horizons.md`, `docs/plans/look-v1.md`, `look-v2.md`,
`look-v2-tech.md`, `docs/status/look-v1.md`, `look-v2.md`, `look-v1-characters.md`,
`look-v1-ui.md`. Skimmed for direction statements: the remaining `docs/plans/` and
`docs/status/` files, `docs/plans/ui-v1.md`, `creatures-v1.md`, `terrain-v2.md`,
`world-feel-v1.md`, `trees-v2.md`, `trees-v3.md`, `foliage-v1.md`.

The test applied to every item: **would you write this line today, for the bible?**
Nothing is kept because it exists.

Date: 2026-09-03. No file in any of the three repos was modified.

---

## 1. Conflicts

Every direction statement in the game docs that contradicts a bible rule. `file:line`
on both sides.

### 1.1 Art direction: the look

| # | Game doc (file:line) | Bible rule | What the conflict means in practice |
|---|---|---|---|
| A1 | `docs/DESIGN.md:89-97` rule 2: "a material is now PAINTED, in tones of its own family - **steel in five greys, skin in four tones**, bark in three browns - laid as patches and runs with intent: a highlight row along a plate's top edge, **wear at a rim, strata in a cliff face**, slivers under a whorl." | `style-bible/10-color-and-light.md:57` "Every material is **one body colour in three shades** (base, shade, light) plus a little per-cube noise"; `80-do-dont.md:27` "Surfaces \| flat-coloured cubes in three shades everywhere"; pillar 2 (`00-pillars.md:9`) "Mood comes from light, fog, the hour and the lens, **never from repainting a thing**." | Four or five tones with authored wear and strata is the three-shades rule broken by one to two tones on every material in the game, and painted strata is repainting nature. Every palette entry, the mesher's colour path and the parts library are authored against the wrong tone count. |
| A2 | `docs/DESIGN.md:143-146` "**The KNIGHT TEST**, for anything that moves: set the model beside the reference knight and barbarian; it passes when it reads as the same game - layered forms, family-toned paint" | Pillar 2 (`00-pillars.md:9`) "every surface is a flat-coloured cube in three shades"; `ASSETS-PLAN.md:44` "Never … Any photo-textured or smooth-mesh pack: pillar 2." | The gate that decides whether art is good points at a reference (a painted, worn, five-grey knight) the bible does not accept. A gate cannot be kept when the thing it measures against is out. |
| A3 | `docs/DESIGN.md:119-125` rule 4: "**Forms are sculpted** … A pauldron is three layered plates, not a box; a helmet has a brow, a visor slit and cheek guards; a blade has a shaped edge and a fitted socket." | `style-bible/40-characters.md:31-35` "Straight lines only. Column coats and dresses, one vertical seam, no folds, no patterns on fabric. Gold bands 1 to 2 voxels wide…"; `:59` "No re-proportioning of the templates." | The clothing/armour language is opposite: the bible wants flat columns with gold bands on bought templates; the doc wants layered sculpted plates on re-authored parts. |
| A4 | `docs/DESIGN.md:98-118` rule 3: "**Fog steps** to a colour **a step darker than the sky's lowest band** (look v2: the horizon is not the fog…) and holds its hue"; `docs/plans/look-v1.md:48-50` rule 3 "**Distance is bands, not haze.** Fog steps in flat bands toward the sky colour." | `style-bible/10-color-and-light.md:8` "**Volumetric fog** that fades to the sky colour with distance and lowers saturation as well as contrast"; `:89` "**Fog always fades to the current sky colour**"; `:83-88` fog has three jobs — valley bands, pooling at castle feet, hiding tops. | Two conflicts in one line: banded depth fog is not volumetric fog, and the fog target is deliberately *not* the sky colour. The bible's three fog jobs (bands lying in valleys, pooling at building feet, swallowing tops in eerie weather) are impossible with a camera-distance band function. This is also the single largest engine gap. |
| A5 | `docs/plans/look-v1.md:24` "**A sun with rays**"; `:166` "Sunburst is the single most Deco thing in the sky; **do not make it subtle**"; `docs/DESIGN.md:126` rule 5 lists "the sun disc" as a gold-accent object. | D18 (`03-DECISIONS.md:137`) "Cubic clouds, **no light beams unless they mean something in the game**"; D5 (`:56`) teal-gold rays "only in the good faction's capital and at moments of triumph"; `80-do-dont.md:16` DON'T = "`day-happy-deco-tower-sun-rays.png` as the everyday sky". | The everyday sky in the game is the one sky the bible names as a mistake. Rays become a place and a moment, not a default. |
| A6 | `docs/plans/look-v1.md:169` "**Clouds:** flat shapes from a thresholded 2-octave value noise on the view direction, hard-edged"; `docs/research/art-direction.md:203-208` "clouds are cut paper, elongated along the horizon". | D18 (`03-DECISIONS.md:137`) "**Cubic clouds**"; `style-bible/20-world-and-terrain.md:27` "**Clouds are cubes** (D18). The world is cubes all the way up." | The sky is painted in the game and built in the bible. A sky-shader cloud is a painted sky, which `10-color-and-light.md:9` forbids ("Real sky with cubic clouds. **No painted skies.**"). |
| A7 | `docs/research/art-direction.md:406-407` "**No waves, no mirror reflection** - the posters never do it"; `README.md:575` "**Water is scenery.** Flat, translucent, no physics"; water body `#4A6A8A` (`art-direction.md:400`). | `style-bible/10-color-and-light.md:10` "**Clear water that reflects** the sky and the lit walls"; `20-world-and-terrain.md:26` "Water is clear and reflects. Lakes are **teal** and still"; `10-color-and-light.md:70` Lake `#265f6e / #42c1c9`. | Reflection is a decided part of the lighting model, explicitly rejected in the game's research. And the game rejected `#4C8FBF` as "a swimming pool" (`art-direction.md:399`) — the bible's `#42c1c9` is *more* saturated than the value the game threw out. |
| A8 | `docs/status/look-v1.md:34` "one lighting ramp … ambient off; **hard shadows**"; `docs/plans/look-v1.md:129-131` "the unlit side is the shade colour … the shadow is the shade colour too", banded to three levels. | D8 (`03-DECISIONS.md:80`) "**Soft and tinted by the sky** (navy day, magenta evening, violet dusk). Hard black at most **indoors at night**"; `10-color-and-light.md:7,12`. | Hard shadows everywhere outdoors is the one thing D8 restricts to interiors. Also: a hand-authored three-band ramp with ambient disabled is not "real light" (pillar 2, D5) — the bible asks for a real sun and real soft shadows, not a quantised poster ramp. |
| A9 | `docs/DESIGN.md:126-131` rule 5: "**The gold has an hour**: `Look.accent_color()` reads the keyframe table, dawn `#F2A80D` through noon `#C9A24A` to night `#E8892E`." | `style-bible/10-color-and-light.md:71` "Gold `#97742f / #c9a24a / #e9ca74` — **the same gold everywhere; never a second gold**"; pillar 2 mood "never from repainting a thing." | Re-tinting the gold albedo by the hour is repainting a material. The bible's gold is one fixed three-shade material; the light does the hour. (The base hue `#C9A24A` is an exact match — see §2.) |
| A10 | `docs/DESIGN.md:24-32` "**ART DECO FANTASY, in sculpted voxels** … The heritage has not moved - the 1920s-30s railway and resort posters of the Alps, Broders' PLM series"; `docs/research/art-direction.md:96-114` "The two registers … Cardinaux register for the cozy noon valley, Broders register for dusk". | `style-bible/10-color-and-light.md:3` palettes sampled from `EXTRACTION.md` and the 26 reference pictures; `10-color-and-light.md:16` the lens reference is **Project Hail Mary** (D40); the hours table (`:29-34`) is sampled from the voxel targets and the pink/violet evening. | The whole colour authority is a different reference set. Every hex in the game (`Block.COLORS`, `FloraModels.COLORS`, the four SkyCycle keyframes) was derived from twenty-four travel posters; the bible's hours, families and materials were sampled from twenty-six of Marcel's pictures. Two complete palettes, neither a superset of the other. |
| A11 | `docs/DESIGN.md:59-73` "For built FORMS the **monumental stepped strand of Deco is in bounds**; look v1's 'never the Manhattan strand' was a ruling about the poster's colour world and stands as one - **the palette authority stays Alpine**." | `style-bible/10-color-and-light.md:39` black-and-gold is "only how the capital skyline looks from far away at night"; D3 (`03-DECISIONS.md:37`) "black stone + gold for landmarks". | Half-agreement, half-conflict: the game already moved to the monumental stepped strand (good), but pinned the palette to the Alpine poster set, which has no black-and-gold landmark stone, no teal-crystal, no purple hostile family, and no cream/teal/gold capital. |
| A12 | `docs/DESIGN.md:98-118`, `:152-160` no film-lens language anywhere in the repo; the pipeline (`:185-207`) ends at `Look.to_wire()`/`SkyCycle`. | D40 (`03-DECISIONS.md:256-258`); `style-bible/10-color-and-light.md:14-25` the lens: grain, halation on emissive only, soft highlight roll-off, muted midtones, gentle vignette, no aberration, no flare. | The decided top layer of the look does not exist in any game doc. Not a contradiction of words — a whole decided layer missing, and rule 3's "one open question … whether the fog's step stays banded or softens" (`DESIGN.md:115-118`) is answered by the bible's volumetric fog before it can be judged. |

### 1.2 Scale and the resolution ladder

| # | Game doc | Bible rule | What it means |
|---|---|---|---|
| B1 | `docs/DESIGN.md:522-527` "**Scale: the world is 1:4 against reality.** Every object in the world is a quarter of its real-world size, and the value of saying so is that ONE ratio has to appear on every line … an object at 1:10 standing next to one at 1:4 does not read as a small world - it reads as a **broken** one." | Pillar 3 (`00-pillars.md:12`) "Monumental against tiny, **in a real-sized Alps**"; D21 (`03-DECISIONS.md:151`) "**Real size.** Trees stay 9-28 m"; `70-scale-metrics.md:3` world cube 0.5 m, player 2 m. | The world is a quarter-size Alps and the bible's is a real-size Alps. Worse, the game has *already* broken its own one-ratio rule: trees v3 authored trees at real size (`DESIGN.md:571-578`, 21-28 m) standing on 1:4 mountains. By the doc's own standard that is the broken world. Terrain, lakes and mountain relief must be re-derived, or the ratio must be stated as a knowing exception with the bible's numbers on top. |
| B2 | `docs/DESIGN.md:529-534` table: "Mountain relief \| **~350 m** \| ~1400 m"; "Largest lake \| ~116 m across \| ~400 m tarn". | `style-bible/20-world-and-terrain.md:35` "conifers **above 1500 m**"; `30-architecture.md:18` landmark tower 60-120 m "so it clears a 28 m forest by at least double"; `:36` castle 40-80 m. | In a world with 350 m of total relief, a 120 m landmark is a third of the mountain it stands on and a 28 m forest is a twelfth of it. The bible's whole architecture size table assumes a real mountain to be small against. |
| B3 | `docs/DESIGN.md:641-650` "**Full scale was considered and rejected, in writing, so it is not relitigated.** A real 1400 m mountain needs roughly a 6 km base, which does not fit inside a 3 km world at all… *The 2026-08-31 unbounded ruling does not reopen this.*" | D41 (`03-DECISIONS.md:262-265`) "the world and view distance etc needs to be **monumental and grand**… the far world draws to at least **10 km** on a clear day"; `70-scale-metrics.md:56-64` the horizon test. | A standing, explicit refusal to reopen the exact question the bible has now reopened and answered. This paragraph must be struck, not softened: the traversal argument under it (six-minute sprint diagonal, `DESIGN.md:663-670`) is now a design problem to solve, not a reason to keep the land at 1:4. |
| B4 | `docs/DESIGN.md:604-618` the resolution ladder: "Characters \| **24** \| 2.08 cm"; "Plants \| 8 \| 6.25 cm"; "Boulders \| 2 \| 25 cm". `docs/DESIGN.md:352-354` "One model voxel is **1/24 of a block, 2.083 cm**, and a human is **96 voxels = 2.00 m**." | D1 (`03-DECISIONS.md:17`) "one character voxel is about **3.3 cm** and there are about **15 character voxels per world cube**"; `40-characters.md:17` "The player is 2 m, 4 world cubes, **about 60 voxels**"; `50-props-and-tech.md:3` "Props are fine voxels **at the character grain**". | The character grain is 24/block against the bible's 15/block, because the bible's grain is set by the purchased templates (59-69 voxels tall) and the game's by a knee in its own generated rig. Every ASCII part in `assets/characters/parts/` is authored at the wrong grain for a bought-template pipeline. Plants at 8 and boulders at 2 are two more grains the bible does not have (it has three: world cube, tree voxel, character voxel). |
| B5 | `docs/DESIGN.md:531` "Tree \| **13 - 21 m** (old growth 19.5 - 31.5 m)". | D21; `70-scale-metrics.md:18` "Forest tree \| 4.5 to 14 \| **9 to 28 m**". | Stale table row: trees v3 already moved to 21-28 m (`DESIGN.md:571-575`) and the row above it was never rewritten. The doc contradicts itself and the bible in the same section. |

### 1.3 World model

| # | Game doc | Bible rule | What it means |
|---|---|---|---|
| C1 | `docs/DESIGN.md:447-456` "Procedurally generated and **effectively unbounded** … **No world edge, no 'the map ends here'** … no new system may bake in a world edge or a global-extent assumption"; `CLAUDE.md:54-58`; `README.md:137-144`. | `lore/10-geography.md:5-10` a long thin continent with two seas; `:13-22` **rings 0-4**; `:36` "The Builders' capital stands at the farthest point: a whole black-and-gold city, intact, empty, mountain-sized. **The end of the map.**" D26 (`03-DECISIONS.md:189`). | The bible's world is finite, ringed, and has an authored end that is the destination of the whole game. The unbounded ruling is not just a different answer — it is a rule in `CLAUDE.md` that forbids any system from knowing the end exists. This is the deepest architectural conflict in the repo. |
| C2 | `docs/DESIGN.md:695-700` danger dials: "**Distance from spawn** - stretches everything wilder (`TerrainGenerator.danger_at()`)", 0 at spawn, 1 at the furthest corner. | D35 (`03-DECISIONS.md:233`) "**Generation by distance from the capital; pacing and threat by distance from the current fire.**" `lore/10-geography.md:40`. | One axis is doing two jobs. The bible splits them: what the world *is* comes from the capital, what it *feels like right now* comes from the fire the players last lit. Ring 4 beside your own fire is a safe pocket; that behaviour is impossible with one `danger_at()`. |
| C3 | `docs/IDEAS.md:366-401` "**Second Age: The Sea** (post-1.0 expansion arc, not before) … The launch world is Alpine. Long-term, the land in one compass direction descends past the far ranges to a COAST, and the game's second act opens … **Island kingdoms** as the new far-zone content tier … **The lizardfolk homeland lies across the water**." | D26 (`03-DECISIONS.md:189`) sea and desert are expeditions in the same world; `lore/10-geography.md:16-22` rings 2, 3, 4 are coasts, near islands and far islands; `:42` zeppelins, ferries and the lighthouse chain; `20-peoples.md:10` the sea folk; D37 (only humans). | The sea is not act two; it is rings 2-4 of the one world, reached by zeppelin, rail and ferry, and it holds the Builders' city that ends the game. "Island kingdoms" and a lizardfolk homeland are not in the lore at all. The *sequencing* (Alps first) survives and matches `ASSETS-PLAN.md:27`; the framing does not. |
| C4 | `docs/ROADMAP.md:30` "**biomes** \| H. Sites v1 (regions) \| Terrain v2 already has seven elevation zones. 'Biomes' = **named regions anchored on sites**, not a worldgen rewrite"; `docs/DESIGN.md:691-704` "Danger structure: **no painted zones**". | `lore/10-geography.md:24-36` three biomes (Alps, sea and islands, desert) each with its own palette, folk, Builder monument, weather and signature hour; `style-bible/20-world-and-terrain.md:33-40` four regions by tree colour. | Seven elevation zones renamed is not the bible's biome model. The bible's biomes are places you travel to, recognisable from a distance by tree colour, each owning one weather and one hour. "No painted zones" survives as a *spawning* rule and dies as a *world* rule. |
| C5 | `docs/DESIGN.md:16-20` "**## Setting** — Fantasy. Cozy but adventurous. Playable races are described under Character identity below." | `00-TONE.md:13` "The world is magnificent because it fell. You are small, it is huge, you will not understand all of it, and you keep walking. Underneath the awe there is a slow ache"; the whole of `lore/`. | The game's setting section is two lines and one of them is a pointer to a race table. There is no fall, no Builders, no Engineers, no mountain folk, no rings, no three ages, no magic rule, no timeline anywhere in the game repo. This is the largest single gap, and it is why so many downstream sections (creatures, magic, gear, sites) drifted. |
| C6 | `README.md:5-10` "set in a **cozy-but-eerie fantasy Alps**"; `docs/DESIGN.md:18` "Cozy but adventurous."; `CLAUDE.md:10` pillar 2 "**COZY IN THE LIGHT**". | `00-TONE.md:27` "**Nobody is the villain and nothing is cute.** No comic relief, no zany… Melancholy is not sadness; it is scale plus time"; `:47` forbids "Cute, zany, comic relief, mascots"; D40 (`:43`) warmth is *between the two players*, not the register of the world. | "Cozy" as the register of the *world* is out; "cozy" as the register of the *fire and the two people at it* is exactly D40 and stays. One word, and it changes which of the two it labels. The word appears in the game's one-line pitch, in pillar 2's name and in the creature docs' "cozy register" (`IDEAS.md:292`, `DESIGN.md:713`). |

### 1.4 Characters, races, skills, magic, gear

| # | Game doc | Bible rule | What it means |
|---|---|---|---|
| D1 | `docs/DESIGN.md:227-244` "## Races — Launch set of four … **Human / Elf / Dwarf / Lizardfolk**", each with a build and a perk; `docs/DESIGN.md:367-374` the four races at 96/108/72/90 voxels. | D37 (`03-DECISIONS.md:243`) "**Yes, only humans.** One people; magic changes people at the edges"; `lore/00-overview.md:29-31`; `style-bible/40-characters.md:23-25` "There are no other races. The elf and dwarf templates are **body types and stages of change within one people**." | Elf and dwarf survive as *body types and stages of change*, not as races: no race picker, no per-race perk, no "who you are" layer. **Lizardfolk has no place in the bible at all** — no reptilian people, no homeland, nothing. It is the only asset-and-code investment in the repo with zero bible support. |
| D2 | `docs/DESIGN.md:219-221` "**Race = who you are.** Cosmetic plus one small situational perk"; `:236-244` elf "sees further at dusk", dwarf "ore glints", lizardfolk "swimming", human "learns all skills slightly faster". | D37; `lore/20-peoples.md:17` "The assets are used as they are; **the lore is what makes them one people**." | A perk table makes body type a mechanical choice, which re-creates races through the back door. The doc already records that two of the four perks are IOUs and that the human's perk breaks its own rule (`DESIGN.md:246-263`) — it should be deleted, not fixed. |
| D3 | `docs/DESIGN.md:385-390` "**Every race is stocky - decided in look v1.** Head about a third of the height … the Cube World read"; `docs/status/look-v1-characters.md:11-27` re-authored ASCII parts, generated by `tools/parts_author/`. | `style-bible/40-characters.md:3` "Characters are built on the **purchased templates** in `Kubik-assets` and reskinned; their **proportions, grain and rigs are not changed**"; `:21` "about 3 heads tall"; `ASSETS-PLAN.md:50` "repaint scripts on the viking/elf/dwarf templates". | The proportion *result* agrees (3 heads / head about a third — see §2), but the *pipeline* does not: the game generates its own bodies in Python and the bible reskins bought ones. The `.vox` drop-in rule (`DESIGN.md:412-418`) is the bridge and is the one part of this system that was built the way the bible would build it. |
| D4 | `docs/DESIGN.md:289-297` "## Magic (v1) — Two elements, no more. **Fire bolt** - small burn over time. **Frost bolt** - brief slow"; `docs/DESIGN.md:274` Magic is one of five levelling skills. | `lore/30-magic-and-tech.md:30` "Mountain-folk magic is small and practical: weather-reading, wards, calling and calming beasts, horns… **Nobody throws lightning.** Big magic belongs to the Builders and to the far islands, and using it is how the last world ended"; D23 (magic is altitude — absent in the valleys); D25 (no crystal-powered anything). | A player throwing bolts on demand at any altitude contradicts three decisions at once. The co-op design goal ("one player slows, the other finishes", `:295`) is worth keeping; the vocabulary must be re-founded on wards, weather, calming, masks and horns. |
| D5 | `docs/DESIGN.md:316-322` "**Tiers are a ladder of OUTLINE EVENTS** … five tiers are defined by how many places the silhouette gains a local maximum … 0 / 1 / 1 / 3 / 5". | D27 (`03-DECISIONS.md:194`) "**Armour is a tech level.** Mountain folk in leather, fur, wool, felt, mail, wood and horn; **plate is the Engineers' guard**"; `style-bible/40-characters.md:37`; `lore/20-peoples.md:18` "Nobody needs a banner to tell them apart." | A tier ladder that escalates a player from cloth to plate turns armour into progression, which erases the one signal that tells a mountain man from an Engineer at a glance. Tiers must run *within* a tech level, or gear must say where you have been rather than how far you have levelled. |
| D6 | `docs/DESIGN.md:299-302` "**Six slots, all visible on the character**: torso, shoulders, back, head, legs, hands"; `:326-330` "One authored set fits **four bodies**: proportions relative, thicknesses absolute"; `:332-335` "Every head item is authored **per race**". | D37; `40-characters.md:59` "No re-proportioning of the templates." | Six visible slots is fine and worth keeping. "Four bodies" and "per race" are the race model leaking into the gear format; with one people and bought templates the axis becomes body type and tech level. |
| D7 | `docs/DESIGN.md:266-270` "## Character creation — One screen. **Race**, palette swaps … hair and beard picks per race, name." | D37. | The creation screen's primary axis does not exist any more. What replaces it (body type? where you are from? nothing?) is a genuine open question — see §3, candidate D42. |

### 1.5 Creatures, combat, death, night

| # | Game doc | Bible rule | What it means |
|---|---|---|---|
| E1 | `docs/DESIGN.md:681-683` "**Fantastic creatures** … rooted in the folklore patterns in `docs/lore/swamp/influences.md`: **scree-worm (Tatzelwurm energy), frost-folk, storm-beings**." | `lore/20-peoples.md:12,19` the old magic's face is "**the Perchten**: masked spirits of the high forests, part beast; and beasts that were once ordinary"; `30-magic-and-tech.md:24` "wolves are wolves in ring 1 and something else in ring 4"; D37. | A whole second bestiary from a different folklore. Also: **`docs/lore/swamp/influences.md` does not exist in the repo** — the only lore reference in the game docs is a dangling pointer. The bible's answer is that the fantastic tier is people and animals changed by thick magic, not a separate species list. |
| E2 | `docs/DESIGN.md:706-712` "Hostile roster (launch) — Four to five archetypes … **rusher, ranged, ambusher, tank, swarm.** Concrete species are assigned to archetypes later, with lore and art." | `lore/00-overview.md:25-27` "The villain, if there is one: the old magic itself… **Nobody is the villain**"; `20-peoples.md:20`. | Archetype-first design is a mechanics scaffold and can survive, but "concrete species assigned later, with lore" is exactly backwards now: the lore exists and names what is out there. The roster must be filled from `lore/20-peoples.md` and the ring table, not invented to fit five slots. |
| E3 | `docs/DESIGN.md:728-732` "### Night — v1 night changes creature boldness only mildly. The full night system - **area-dependent night casts, aggro nights, raid events** - is a late-game system"; `docs/IDEAS.md:345-347` "Full night system: … **raids on the campfire - a blood-moon-style dial**". | `00-TONE.md:51` forbids "**Frantic survival: timers, hunger bars that scream, constant alarms**"; D39 (`:53-54`) no horror dressing, no jump scares; `:41` "every dread beat **ends at a fire**". | A blood-moon raid on the campfire inverts the tone's central image: the fire is where dread ends, not where it arrives. This item must be struck from the ladder, not deferred. |
| E4 | `docs/DESIGN.md:734-754` "### Mimics: the world that seems … the **mimic-tree**. Walk near it and it tears its roots free… Deeper mimics - boulders, a copse, one day a hillside"; `:753` lore hook "trees that were not there at **lammas**". | `00-TONE.md:54` forbids horror dressing; `style-bible/00-pillars.md:18` "nature stays nature"; `lore/30-magic-and-tech.md:24` beasts change where magic is thick; `lore/50-open-questions.md:11` names are alpine placeholders. | Half-compatible: rarity, tells and "an old thing disturbed, not a horror jump-scare" fit the tone. What conflicts is the category — the bible's old magic changes *beasts and people*, never trees or hillsides — and "lammas" is an English harvest festival in an alpine world. Adapt into the Perchten and the changed-beast rule, or drop. |
| E5 | `docs/DESIGN.md:831-837` "## Combat — Simple and readable… Light attack, dodge / block. Weapon types with distinct feel." `:839-844` "## Death — Downed player can be revived… **Costs time, not progress.**" | D39 / `00-TONE.md:53` "Graphic violence: blood, gore, dismemberment, torture, cruelty as spectacle. **Combat is restrained; death is quiet and remembered.**" | The mechanics do not conflict; the section is silent on the one thing D39 decides. "Restrained" is a content rule that must be written down before the first hit lands (no blood decals, no dismemberment, no gore), and "**remembered**" is a requirement on the journal — a death must become a fact the world can refer to later, which nothing in the game docs currently says. |
| E6 | `docs/DESIGN.md:713-720` "Hunting: the cozy-honest rule … **Small cute ambient creatures - marmot-tier - are not huntable.**" | `00-TONE.md:27` "nothing is **cute**". | Wording, not mechanic. The rule is right (and serves the tone: no cruelty as spectacle); the justification "cute" is the forbidden register. Rewrite as the world's texture and information layer, which the same paragraph already says. |

### 1.6 UI

| # | Game doc | Bible rule | What it means |
|---|---|---|---|
| F1 | `docs/DESIGN.md:62-63` "UI and typography - carries the **Deco vocabulary**: stepped setbacks, sunburst reliefs, streamlined geometric repetition"; `:158` "Unchanged: **the UI's Deco paper and ink**"; `docs/status/look-v1-ui.md:20-24` the sunburst backdrop, stepped mountains, gold double rule; `docs/status/look-v2.md:707-712` "`DecoPanel.stepped()`… `Deco.dots()`, `Deco.chevron()`, `Deco.roundel()`". | D2 (`03-DECISIONS.md:27`) "**B - on paper only: UI, cards, map, portraits**" — nouveau; `style-bible/60-ui-and-2d.md:3` "Art Nouveau lives here and nowhere else… Everything printed, framed or drawn in the game is paper in the nouveau style"; `:27` "**No deco geometry cut into the paper**"; `80-do-dont.md:26` DON'T = "deco geometry on paper". | The entire shipped UI is the exact thing the bible names as the don't. Sunburst backdrop, stepped corners, chevrons, roundels and gold double rules are deco geometry on paper. The frames become curved and floral; the *world* keeps the deco. |
| F2 | `docs/DESIGN.md:204-206` theme "paper `#F2E8D0`, **ink `#1E2430`**, gold, **alpine blue `#2F5D8A`**, sun `#E8863A`, pale ink `#7D7C78`; **Limelight** for titles, **Josefin Sans** for body". | `style-bible/60-ui-and-2d.md:7` "Cream `#f3e1c6` paper. Frame lines in **gold-brown `#917b5c`**, thin… Accents in **sage `#6b7463`** and **dusty pink `#cb9b6e`**. **Low contrast, no black**"; `:19` "Body text: **a plain serif** on cream paper." | Ink `#1E2430` is a near-black on paper the bible says has none. Alpine blue is not in the UI palette. Titles in a geometric deco sans (Limelight, Josefin Sans) are within `60-ui-and-2d.md:19`; the body face must become a serif. |
| F3 | `docs/plans/ui-v1.md:38-46` "Two registers, matching the art direction: **the poster register** - menus, the character screen. **Full Deco**: Limelight titles, ink bands, ornaments, the turntable." | D2; `60-ui-and-2d.md:9-12` cards in the tarot format, nouveau portraits with a halo, the alpine valley card as the model. | The register split (posters you visit vs a near-invisible field HUD) is a good idea that survives; its Deco content does not. Menus become nouveau cards. |

### 1.7 The director

`docs/DIRECTOR.md` and `director/` agree on doctrine and disagree on every signature.

| # | Game doc | Bible rule | What it means |
|---|---|---|---|
| G1 | `docs/DIRECTOR.md:30` `place_fragment(**text**, **site_type**)` | `director/10-verbs.md:7` `site_id`, `fact_ids[]`, `voice`, `text`; host checks "site exists; every fact ID is real; **text cites nothing outside the fact IDs**"; D34 rule 1 (`00-principles.md:18`) "**Facts by ID** … Every verb references IDs, **never free text about the world**." | A free-text fragment at a site *type* is the exact shape D34 rule 1 exists to forbid. Nothing in the game doc grounds a fragment in a fact. |
| G2 | `docs/DIRECTOR.md:31` `spawn_rumor(text, source, points_to)` | `director/10-verbs.md:8` `player_id`, `site_id`, **`truth` (set by the host, not the model)**, `voice`, `text`, `expires`; D34 rule 2; D36 per-player delivery. | Three decided things absent: the host-set truth flag, per-player delivery (D36), and expiry. A rumour with no truth flag cannot be a lead the game knows is false. |
| G3 | `docs/DIRECTOR.md:32` `mark_site(**location_hint**, **flavor**)` | `director/10-verbs.md:9` `site_id`, `sign` from a **closed list**: `window_on, lighthouse_lit, fog_lift, zeppelin_pass, mask_hung, crystal_glow, campfire_smoke`; host checks "the sign is **allowed in that site's colour family**"; `:20-27` the signs-by-family table. | A location *hint* and an open *flavor* string let the model gesture at places that may not exist and light signs that break the two colour families (D11). The bible's sign list is also the seduction vocabulary the tone asks for ("a lit window in a valley at dusk", `00-TONE.md:35`). |
| G4 | `docs/DIRECTOR.md:33-34` `advance_beat(quest, beat)`, `reroute_beat(quest, alternative)` | `director/10-verbs.md:10-11` `route_id` on both; `reason_fact_ids[]` on reroute; host checks "the beat's mechanical precondition is **already true**" and "the current route is **actually blocked** (mechanically)". | No route id means the authored alternative graph (D34 rule 3, "**Reroute chooses, never authors**") has nowhere to live. |
| G5 | `docs/DIRECTOR.md` — the **eight hardening rules do not appear**. No chronicler, no truth flag, no nudge budget, no quest-health pulse, no template path, no "the rest never waits", no director log, no speech tagging. | D34 (`03-DECISIONS.md:228`) "**All eight hardening rules**"; `director/00-principles.md:16-25`. | The eight rules are what makes "never invents world-truth" enforceable. Their absence is the difference between a doctrine and a design. |
| G6 | `docs/DIRECTOR.md:83-86` "**v2 - 'the stranger speaks'.** One NPC - **the storm-scholar, the *garabonciás* archetype** - with fixed goals, knowledge bounds, and generative speech. **Uncanny is lore-correct for him.**" | `director/30-roadmap.md:23-29` "One NPC with fixed goals, knowledge bounds and generative speech… speech tagging… an 'I don't know' default; **a mask**"; `director/40-open-questions.md:13` "the masked figure from the quest-room picture? Which people does it belong to, and what does it want?" | The garabonciás is Hungarian storm-wizard folklore in an alpine world with no storm-scholar in its lore. "Uncanny is lore-correct" cites a lore that does not exist. The bible's answer is a masked figure whose people is an open question. |
| G7 | `docs/DIRECTOR.md:79-86` roadmap has **no v0 prerequisites for the template path**; `:57-61` degradation is about the director being off. | D34 rule 5 (`00-principles.md:22`) "**The template path ships first.** A non-model generator fills the same slots from the same log"; `director/30-roadmap.md:11-13,31-33` "The director-OFF path is **played first at every version**." | The game's degradation promise is "the game is complete without it"; the bible's is stronger — a non-model generator writes the *same structured output* first, and the model is a better writer of it. That changes what v0 builds. |

### 1.8 The pillars: do they hold, and how do they nest

`CLAUDE.md:3-24` and `README.md:18-35` carry four pillars. Under the bible they are
**gameplay** pillars and must nest under `00-TONE.md` (D38), beside the five art pillars.

| Pillar | Holds? | Nesting / conflict |
|---|---|---|
| 1. BETTER TOGETHER (`CLAUDE.md:7-9`) "Built for pairs, room for four. Cap constant: 4." | Holds, narrowed | Nests under D40 (`00-TONE.md:43`) "Warmth between the two… Grace and Rocky in Project Hail Mary" and `lore/00-overview.md:33` "**Two people** who walk between". The bible is written for **two**; "room for four" is bible-silent and slightly against the two-hander framing of the tone and both songs. Keep as a scaling allowance, not a design centre. |
| 2. TENSE OUT, COZY IN THE LIGHT (`CLAUDE.md:10-13`) | Holds, renamed | Nests under `00-TONE.md:35` "Rare warm light… should land like the song's swell" and D39's "every dread beat ends at a fire", and D35's threat-by-distance-from-the-current-fire. The word "cozy" must go (C6); "Firelight and daylight are the warm register" is exactly right. "Danger scales with… darkness" needs re-pointing at eerie weather (`10-color-and-light.md:42-44`) rather than at night, which the bible makes slate-with-warm-windows, not a threat. |
| 3. THE WORLD IS THE CONTENT (`CLAUDE.md:14-19`) "Progression is ranging further… The scale register is monumental" | Holds in name, breaks in numbers | Nests under art pillar 3 (`00-pillars.md:12`) and `00-TONE.md:33` "Scale you feel". But its own supporting text — "**unbounded** world of continents" (`README.md:29-31`) and `DESIGN.md § World` — conflicts with C1, B1, B3. Repoint the citation from `DESIGN.md § World` to `style-bible/00-pillars.md:12` + `70-scale-metrics.md` + D41. |
| 4. THE WORLD ANSWERS (`CLAUDE.md:20-24`) | Holds unchanged | Nests exactly under `director/00-principles.md:7-8` (the game owns all truth; the model improvises under constraints). The three habits (`CLAUDE.md:26-38`) are D34 rule 1 and principle 1 in miniature and stand as written. |
| **Missing** | — | There is **no pillar for the tone**. `00-TONE.md` sits above art, lore and director and decides when they cannot; the game repo has no equivalent and no mention of the fall, melancholy, mystery kept, endings that fade, or one people. There is also **no art pillar** in `CLAUDE.md`/`README.md` — the art direction lives in a `DESIGN.md` section, which is why it drifted furthest. |

---

## 2. What agrees and can stand as is

| # | Game doc | Bible | Verdict |
|---|---|---|---|
| 1 | `docs/DESIGN.md:59-61` "**Deco is the grammar of everything BUILT, and never of nature.** Nature is sculpted-vox naturalism: a mountain, a fir, a boulder take no ornament, no strata-as-pattern, no setbacks. The CONTRAST is the point." | Pillar 5 (`00-pillars.md:17-18`) "**Deco is for the built and the dressed; nature stays nature.** Buildings and characters carry the style… Terrain, trees, water and sky carry only a palette and a grain." | The single strongest agreement in the repo, arrived at independently. Stands verbatim. |
| 2 | `docs/DESIGN.md:89-93` rule 2 "**no texture maps, no specular, no gradient across a face**: a colour is a voxel's colour on a model and a vertex colour on the wire, nowhere else." | Pillar 2 "**No photo textures, on anything, ever**"; `80-do-dont.md:27`; `ASSETS-PLAN.md:44` "Never… any photo-textured or smooth-mesh pack". | Stands. (The *number of tones* per material does not — see A1.) |
| 3 | `docs/DESIGN.md:133-137` "**Warmth is in the light, coolness is in the shade, and the albedo has neither** - a palette entry is the thing's colour in flat noon light; the sun makes it warm and the ink makes it cool, and nothing bakes a cast into an albedo." | Pillar 2 "**Mood comes from light, fog, the hour and the lens, never from repainting a thing**"; `10-color-and-light.md:93` "Weather never changes a material's colour; it changes the light on it." | Stands, word for word in spirit. This is the rule that makes the bible's hour table implementable. |
| 4 | `docs/DESIGN.md:137-141` "**what is authored is what is on screen** … proved by the swatch sheet… every swatch within 6 sRGB units of `Look.predict()`"; `docs/plans/look-v2.md:57-62`; `docs/status/look-v2.md:36-44`. | `ROUND-3-BRIEF.md:27` "Sample the sky, a lit wall, a shadow and the fog in each hour and compare to the hex values in the colour file." | Stands and should be **promoted**: the swatch gate is the instrument round 3 needs and it already exists. |
| 5 | `docs/DESIGN.md:614` resolution ladder "**Trees \| 4 \| 12.5 cm** \| the whole tree"; `:616` "**Terrain \| 1 \| 50 cm**"; `:458` "Blocks are 0.5 m, so a player is 4 blocks tall." | D1 (`03-DECISIONS.md:17`) "World cube = 0.5 m (tree sidecar: 4 tree voxels of 0.125 m per cube), player = 4 cubes = 2 m"; `70-scale-metrics.md:3`. | Exact match on three of the four grains. The bible's D1 was written *from* this pipeline's tree sidecar. |
| 6 | `docs/DESIGN.md:571-578` trees "**AUTHORED AT WORLD SIZE**, like a character… **21 to 28 m**"; `STATUS.md:20-27`; `docs/plans/trees-v3.md`. | D21 (`03-DECISIONS.md:151`) "**Real size.** Trees stay 9-28 m"; `70-scale-metrics.md:18`; `80-do-dont.md:22` DO = "the purchased tree library at real size". | Stands. The game reached D21's answer before D21 was written. |
| 7 | `STATUS.md:20-25` "`FarTrees` is `TreeField` and it is the only tree renderer… **there are no impostor cards anywhere**… the near/far seam stopped being a KIND boundary and became a **RESOLUTION** boundary"; `docs/DESIGN.md:52-58`. | D41 (`03-DECISIONS.md:263`) "far terrain and buildings stay visible as simplified silhouettes fading into fog, **never popping in**"; `70-scale-metrics.md:63` "Popping \| none; far things arrive out of fog, never at a boundary." | Stands and is the mechanism D41 requires, already built. |
| 8 | `STATUS.md:11-13` "not its **chamfered meshes, which stay rejected**, because a `.vox` is a build plan rather than a surface." | `ASSETS-PLAN.md:42` "**The tree pack's chamfered low-poly meshes: a third surface language, already rejected.**" | Identical rulings, independently reached. |
| 9 | `docs/research/distant-horizons.md:1-6` "Research for distance v3, 2026-08-31 — the day the world went unbounded and **Marcel named the Distant Horizons look as the feel he is chasing**." | D41 (`03-DECISIONS.md:262`) "huge like minecraft distant horizon mod". | Same reference, same person, sixteen months of engine research already done for the decision. Promote, do not rewrite. |
| 10 | `docs/DESIGN.md:513-520` "**THE FRONTIER RULE… never a hole, at any speed.**" | `70-scale-metrics.md:63` "Popping \| none"; `20-world-and-terrain.md:21` "nothing pops in." | Stands. |
| 11 | `docs/DESIGN.md:126` gold **`#C9A24A`**. | `10-color-and-light.md:71` Gold `#97742f / #c9a24a / #e9ca74`. | Exact hex match on the base. The game's single accent is the bible's mid shade. |
| 12 | `docs/DESIGN.md:385-388` "Head about a third of the height… the Cube World read, kept on the stocky side"; `docs/research/art-direction.md:439-441`. | `40-characters.md:21` "As the templates: stylised and big-headed, **about 3 heads tall**." | Agree. (Note a bible bug: `70-scale-metrics.md:7` still says "**6 heads**", which `40-characters.md:21` explicitly records as wrong and corrected. Worth fixing in the bible.) |
| 13 | `README.md:67-99` host-authoritative, **one mutation path**, identity from `get_remote_sender_id()`; `README.md:172-179`. | `director/00-principles.md:10` "**One mutation path.** Every verb goes through the host's single mutation path and is validated exactly like a client's block edit. The director proposes, the host applies." | Stands unchanged. The bible's principle was written from this architecture. |
| 14 | `CLAUDE.md:30-38` the three habits: facts as data, keep the journal, everything through the one mutation path. | `director/00-principles.md:7` "The game owns all truth… a structured event log"; D34 rule 1; rule 7 "Log the director." | Stands. Habit 2's event list (edit, death, campfire, kill, first sight of a lake) matches `director/20-world-digest.md:19-27`'s salience list almost line for line. |
| 15 | `docs/DIRECTOR.md:42-47` "invoked at **campfire rests**… and at session start… **State machines own seconds; the director owns minutes.**" | `director/00-principles.md:11` "**Campfire cadence.** Invoked only at campfire rests and session start. State machines own seconds, the director owns minutes; combat never waits on a model call." | Identical. |
| 16 | `docs/DIRECTOR.md:49-53` "**Opportunity, never walls.** The director seduces - a rumour, a light in a valley, a stranger's mention - and never blocks." | `director/00-principles.md:12` — the same sentence, including the same three examples. | Identical. |
| 17 | `docs/DIRECTOR.md:55-61` "**Graceful degradation - non-negotiable.** The game must be complete and fun with the director OFF." | `director/00-principles.md:14` principle 8. | Stands (strengthened by D34 rule 5 — see G7). |
| 18 | `docs/DIRECTOR.md:63-68` "Beats are authored - the spine… **the game must KNOW a beat completed, never take the model's word for it.**" | `director/00-principles.md:13` principle 7 "**Verifiable beats.**" | Identical. |
| 19 | `docs/DIRECTOR.md:79-86` v0 "the world remembers", v1 "the world beckons", v2 "the stranger speaks". | `director/30-roadmap.md:5,15,23` — the same three names in the same order. | Stands (the v2 NPC's identity does not — G6). |
| 20 | `docs/ROADMAP.md:26` "**no minimap, not even a toggle**. The compass strip + the fog-of-exploration map screen are the whole answer"; `docs/plans/ui-v1.md:53-59`; `docs/ROADMAP.md:210-212` "a map screen that reveals as you range (fog of exploration)". | `lore/10-geography.md:44-46` "The Engineers' map: accurate for the continent, sketchy for the near islands, **blank beyond**. **Fog of war is literal fog.**"; `00-TONE.md:50` forbids "noisy UI, **a screen full of markers**". | Strong agreement, and the bible gives the game's decision a *reason*: the map is a faction's artefact whose blankness is the plot. |
| 21 | `docs/plans/ui-v1.md:42-47` "**the field register** - the in-game HUD. Nearly nothing… When you are safe it fades to literally zero." | `00-TONE.md:50` forbids clutter and noisy UI. | Stands. |
| 22 | `docs/DESIGN.md:436-443` "**Third person only.** … the game is sold on reading landscape at a glance, and an over-the-shoulder framing hides exactly the thing worth looking at." | Pillar 3 (`00-pillars.md:12`) "the view reaches the horizon… a whole city in one frame"; `00-TONE.md:33` "Long sightlines." | Stands; the reason given is the bible's reason. |
| 23 | `docs/DESIGN.md:846-853` "**Placeable objects** … campfire, torch, marker… **Players never place raw voxel blocks**"; `:498` "**Huge buildings are the world's, not the players'.**" | Pillar 3; `ASSETS-PLAN.md:49` landmarks, castles, houses "built from world cubes **by rules**… the game repo". | Stands. The bible builds the monumental world; the player lights a fire in it. |
| 24 | `docs/DESIGN.md:722-726` "**Megafauna** — A few RARE giant creatures as awe encounters, in the Pilatus-dragon register: near-sacred, **witnessed more than fought**." | `ASSETS-PLAN.md:36` "Dragons, Mythical Creatures… **ring 4**; the far islands; the wild"; `00-TONE.md:41` "the sublime, beauty that includes fear." | Stands, with a placement rule added: ring 3-4, not near spawn. "Witnessed more than fought" is the tone exactly. |
| 25 | `docs/DESIGN.md:679-680` "**Real Alpine wildlife, stylised** - ibex, marmot, fox, wolf, eagle, fish. The familiar base, concentrated near spawn and in the valleys." | `ASSETS-PLAN.md:13-14` forest and winter animal packs; `style-bible/40-characters.md:53` "Wolves, bears, deer, foxes, rabbits and boars in the alpine default"; ring 0-1. | Stands. |
| 26 | `docs/DESIGN.md:800-816` the five rules that make creatures look smart (senses, communication, memory, terrain use, smart objects); `:818-822` "**Where the director does not go.** Nowhere near this." | `director/00-principles.md:11`; `10-verbs.md:17` "**No verb changes terrain, spawns enemies, or moves NPCs.** Those are the game's, driven by state machines." | Identical seam, stated from both sides. |
| 27 | `docs/DESIGN.md:104-107` "A far cell is **one real material chosen by a majority vote** over four sub-samples, **never a blend**." | `10-color-and-light.md:55-57` three shades per material, no blending; `70-scale-metrics.md:52` the 100 m distance test. | Stands. |
| 28 | `README.md:522-535` purchased art lives in the private repo, mounted at a gitignored path, "the game must always run with `assets/purchased/` **absent**". | `ASSETS-PLAN.md` (whole file) — bought templates are the character pipeline. | Stands as engineering. Note the tension: the bible makes bought art *the* character source, so "never a dependency" now means the fallback is a placeholder, not a second art style. |

---

## 3. Candidate decisions D42 onward — the game answered, the bible is silent

One line each, with the game's current answer.

| # | Question | The game's answer today (file:line) |
|---|---|---|
| 1 | How many players, and is solo supported? | 2-4, cap constant 4, tuned for 2; solo is a dev convenience, never a balanced mode (`CLAUDE.md:7-9`, `DESIGN.md:956-957`). |
| 2 | Camera | Third person only, Cube World orbit follow, camera collides with terrain; noclip is a debug tool (`DESIGN.md:436-443`). |
| 3 | Can players build? | No base building; a restricted placeable palette (campfire, torch, marker); players never place raw blocks (`DESIGN.md:846-853`). |
| 4 | Can players dig or break terrain? | No, in v1. Voxels are edited through the request path and never simulated; no digging (`DESIGN.md:861-871`). |
| 5 | Is anything in the world physical? | A seeded fraction (0.15) of medium/large boulders are pushable co-op bodies; 600 N per player against a `hold`; under the hold they **rock** three degrees; frozen at rest (`DESIGN.md:873-908`). |
| 6 | Movement numbers | Walk 5 m/s, sprint 13 m/s, ramp 40 m/s², shed 30; slide over 45° on alpine/rock/snow at half gravity capped 8 m/s; per-zone ground friction (`DESIGN.md:910-926`, `:663-666`). |
| 7 | Do characters travel between worlds? | No. The character lives in the world on the host; one save file holds world edits and every character; Valheim's split rejected (`DESIGN.md:420-432`). |
| 8 | Netcode | Host-authoritative; clients send input, the host simulates and broadcasts; ease under 2 m, snap over; **no rollback in v1**; ENet now, GodotSteam later (`DESIGN.md:941-959`, `README.md:542-563`). |
| 9 | Determinism contract | Terrain is never sent, only edits; a shared 64-bit seed **and** worldgen config; heights quantised to 1/1024 block so a library-less checkout makes the same world (`README.md:101-113`, `:210-219`). |
| 10 | Death rules | Downed, revivable by any teammate; whole party down → respawn at the last campfire; camera follows a living teammate; costs time, not progress (`DESIGN.md:839-844`). |
| 11 | Progression shape | Skill-by-use, five skills, diminishing, **no decay ever**, ~+25 % by level 10, chunky unlock every five levels, **read-only sheet** (`DESIGN.md:272-287`). |
| 12 | Is there an item system? | Not yet; Items v1 owns the table, pickup, drop, inventory and what grants a tier (`DESIGN.md:337-338`, `ROADMAP.md:160-191`). |
| 13 | Spawning model | No painted danger zones; four dials — altitude, distance, slope/terrain context, time of day (`DESIGN.md:691-704`). |
| 14 | Hunting | Real wildlife huntable; marmot-tier ambient creatures cannot be targeted at all (`DESIGN.md:713-720`). |
| 15 | Creature AI stack | LimboAI behaviour trees, `AStarGrid2D` over the coarse heightmap with per-species slope costs, boids for flocks, utility AI for needs, GOAP for planners; **learning agents rejected** (`DESIGN.md:791-798`). |
| 16 | Where does the director run? | A sidecar process beside the host, local HTTP/WebSocket, host's API key; strangers' builds default off (`README.md:172-179`, `DIRECTOR.md:60-61`). Answers `director/40-open-questions.md:9`. |
| 17 | What goes in the journal? | Structured host events — edit, death, campfire, kill, first sight of a lake — written into the save (`CLAUDE.md:32-35`, `ROADMAP.md:151-158`). Partially answers `director/40-open-questions.md:7`. |
| 18 | Which renderers are supported? | Played on Forward+, shot on Compatibility; any colour path is checked on both and they must agree within 6 sRGB units (`README.md:260-278`). |
| 19 | Licence and openness | MIT, open source, purchased art excluded and non-redistributable (`README.md:596-600`, `:522-535`). |
| 20 | Mounts | v0.3+; speed and flavour, not a combat system (`DESIGN.md:937-939`). Bible-silent; note zeppelins (D24) are the bible's travel answer. |
| 21 | Weather in the engine | Nothing exists. The bible requires fog, rain and falling snow (D16) — a gap, not a silence. |
| 22 | What replaces "race" at character creation? | Open. The bible removes the axis (D37) and the game's creation screen is built on it (`DESIGN.md:266-270`). Needs a decision before any character work. |
| 23 | Is the world bounded? | The game says no (`DESIGN.md:447-456`); the bible implies yes (rings 0-4, "the end of the map"). Needs a decision, and it blocks worldgen. |
| 24 | Is a third and fourth player in the fiction? | The game says four; the tone and lore are written for two. Needs a decision. |

---

## 4. Verdict per document

### `README.md` — **ADAPT**
Keep: the whole Architecture section 1-5 (host authority, one mutation path, terrain
never sent, the transport seam, chunk format) — it is what `director/00-principles.md:10`
assumes; Running it, the six probes, the C++ build instructions, Builds, Layout,
Purchased assets, Known provisional bits, Licence.
Change: lines 5-16 (the pitch: "cozy-but-eerie", "grow stronger from what it drops")
against `00-TONE.md:13,27`; lines 18-35 (the four pillars — nest under `00-TONE.md`, fix
pillar 3's citation); lines 40-53 (the status paragraph names "Art Deco travel poster",
"Art Deco fantasy", "1:4 scale", "Four playable races" — all four are out under A1/A10,
B1, D1); lines 137-144 (unbounded, C1); architecture 5's two-scale world must state
D41's 10 km target.

### `CLAUDE.md` — **ADAPT**
Keep: the three habits (26-38) — they are D34 rule 1 and principle 1; the rule block
(40-50); "Where things live" (65-73) with the bible added as the first entry.
Change: the four pillars become gameplay pillars under `00-TONE.md`, with the five art
pillars added beside them; pillar 3's "monumental" clause repoints from `DESIGN.md § World`
to `style-bible/00-pillars.md:12` + `70-scale-metrics.md` + D41.
**RIP:** "Worldgen guidance" (52-63) — "The world is unbounded by design" and "No new
system may bake in a world edge" directly forbid the bible's ring model and its end of
the map (`lore/10-geography.md:13-22,36`). Replace with the ring model and D35's two axes.

### `STATUS.md` — **KEEP**
A run log, not a direction document. Its two direction-adjacent claims — the purchased
`.vox` library as the tree source and the chamfered meshes rejected — agree with D1, D21
and `ASSETS-PLAN.md:42`. Add one line pointing at the bible; change nothing else.

### `TODO.md` — **ADAPT**
Keep the wave structure, the parallel-lane rule and waves 1-3, which match
`director/30-roadmap.md` and `ASSETS-PLAN.md:68-73`'s order of work.
Change: **A6 Look v3 "the painted world"** (line 25) is RIPPED as scoped — its register
(painted five-tone materials, the knight test, the Blockbench re-author) is A1/A2/A3.
Replace it with the `ROUND-3-BRIEF.md` test scene as the next look item. **H Sites v1**
(48-53) must be re-founded on `style-bible/30-architecture.md`'s four building families and
`lore/10-geography.md`'s rings, not on a generic landmark table. **D Combat v1**'s fire
bolt / frost bolt (line 33) is D4. **J Skills v1**'s Magic is D4. Add: fog (D16, three
jobs), the film lens (D40), the far view distance (D41) as engine work items —
`ASSETS-PLAN.md:54` assigns all four to this repo.

### `docs/DESIGN.md` — **SPLIT: parts KEEP, parts RIP**

**RIP (replaced by the bible):**
- `§ Setting` (16-20) — replaced by `lore/`.
- `§ Art direction` (22-207) as *style law* — A1, A2, A3, A4, A5, A9, A10, A12. Rules 1,
  2 (tone count), 4, 5 (the hour) and the two gates go. What survives is listed below.
- `§ Races` (227-263) and the Race layer of `§ Character identity` (209-225) — D37.
- `§ Character creation` (266-270) — its axis no longer exists.
- `§ Magic (v1)` (289-297) — D4.
- `§ Scale: the world is 1:4` (522-602) and "Full scale… rejected… not relitigated"
  (641-650) — B1, B3.
- `§ World`'s unbounded ruling (447-456) — C1.
- `§ Creatures`' fantastic roster (681-683) and Night's raid ladder (728-732) — E1, E3.

**KEEP as the game's own technical truth (the bible has nothing to say and should not):**
- `§ Art pipeline`'s **parts-as-data** and the **drop-in rule** (404-418) — the `.vox`
  drop-in is exactly how bought templates enter the game.
- The **pipeline** paragraph (185-207): linear palettes, one `Look.to_wire()` conversion,
  `light()` writes the light and `ALBEDO` is white, `Look.predict()`, `SkyCycle.KEYFRAMES`
  as the one place an hour's colour is decided. This is the machinery the bible's hour
  table needs; only the *numbers* in it change.
- "Warmth is in the light… nothing bakes a cast into an albedo" and "what is authored is
  what is on screen" (133-141) — §2 items 3 and 4.
- "Deco is the grammar of everything BUILT, and never of nature" (59-61) — §2 item 1.
- The **resolution ladder** (604-639) as a table of *engine grains*, with the character
  row renegotiated to D1's 15/block and the plant and boulder rows resolved.
- **The frontier rule** (513-520), `§ Physics` (858-935), `§ Traversal` (663-670),
  `§ Multiplayer` (941-961), `§ Camera` (436-443), `§ Characters and saves` (420-432),
  `§ Placeable objects` (846-856), `§ Combat` and `§ Death` (831-844) with D39's content
  line added, `§ Creatures`' behaviour stance (779-822) and the real-wildlife tier.

### `docs/IDEAS.md` — **ADAPT**
Keep: the Next 3 / Someday / Director-ladder structure, the deliberately-not-here list,
and the pillar-contradiction tagging discipline (362-364), which is the right instinct
and should now read "contradicts a pillar **or a decision**".
RIP: `§ Second Age: The Sea` (366-401) as a framing — C3; "Full night system… raids on
the campfire" (345-347) — E3; "More races" (356) — D37; the lizardfolk homeland (388).
Also: the file is 200 lines of run narrative doing `STATUS.md`'s job; that is a
housekeeping problem, not a bible one, but it makes the direction hard to find.

### `docs/ROADMAP.md` — **ADAPT**
Keep: the epic list, sizes, territories, the zero-overlap parallelism rule, the critical
path and the pushbacks section — all of it is engineering order and none of it is style.
Change: the item→epic table's entries for **biomes** (line 30, C4), **castles and
structures** (27, repoint at `style-bible/30-architecture.md`), **skill tree** (32, keep
the pushback and re-point at pillar 3), **oceans** (23, C3); epic **H Sites v1**
(193-204) must inherit the four building families, the ornament budget (D9) and the
ring placement rules; epic **A6 Look v3** (82-102) as TODO above.

### `docs/DIRECTOR.md` — **REDO as a thin pointer, keeping four paragraphs**
The doctrine (Thesis, Two layers, Cadence, Steering, Degradation, Quest model, Risk) is
`director/00-principles.md` said differently and can stay as prose or be cut to a link.
The **verb table (23-40) is RIPPED** — every signature is the free-text, no-ID shape D34
rule 1 exists to forbid (G1-G4). It is replaced wholesale by `director/10-verbs.md`,
including the closed sign list and the signs-by-colour-family table. The **eight
hardening rules must be added** (G5), along with D35, D36, and the template-path-first
rule (G7). The v2 NPC's identity (83-86) is RIPPED (G6). What the code does today (90-95)
stands.

### `docs/research/art-direction.md` — **KEEP as evidence, DEMOTE as authority**
Keep and promote: `§0` (the colour-transfer finding) — it is the reason any hex in the
game means anything, and it applies to the bible's hexes identically. `§2.1`'s ramp
mechanism and `§2.3`'s fog mechanics as engine knowledge. The method (sample the pixels,
never the memory) is exactly the bible's `EXTRACTION.md` method.
RIP as authority: `§1` (the two poster registers), `§2.2` (sky, rays, the sun disc),
`§2.5` (tree form language — superseded by trees v3 and the purchased library), `§2.7`
(no reflection, water colour — A7), `§2.9` (characters — D1, D37), `§2.10` (UI — D2),
`§2.11` and `§3` (the complete palettes — A10). The file already carries a "how to read
this after 2026-09-01" banner at lines 11-21; it needs a second one for the bible.

### `docs/research/distant-horizons.md` — **KEEP, and promote**
The only game document that is *more* aligned with the bible than the bible is with
itself: it is the engine research for D41, produced from source, on the day Marcel named
the reference. It is the answer to the bible's single engine requirement
(`20-world-and-terrain.md:21`). Nothing to change.

### `docs/plans/look-v1.md` — **RIP as direction, KEEP as history**
Its five rules (37-55) are the ancestor of `DESIGN.md`'s five and three of them conflict
(A4 banded fog, A5 rays, A8 hard shadows). Its stage procedure and evidence discipline
are reusable. Mark superseded at the top; do not delete.

### `docs/plans/look-v2.md` — **RIP as direction, KEEP one rule and the method**
Rule 4, "what is authored is what is on screen" (57-62), is engine law and survives
everything. The rest is the poster refined. Mark superseded.

### `docs/plans/look-v2-tech.md` — **KEEP as a procedure template**
Not a direction document at all: it is a work order (the contract, the pre-run grill with
binding answers, the tunable/not-tunable split, the failure protocol, the gates). This is
the shape `ROUND-3-BRIEF.md` should be executed in. Reuse it; change only the subject.

### `docs/status/look-v1.md` — **KEEP as history**
Its "Tuned blind" section (76-95) is honest and still useful. Its shipped results
(banded fog, sun rays, hard shadows, poster water) are all superseded.

### `docs/status/look-v2.md` — **KEEP as history, with load-bearing engine truth**
The transfer measurement and the swatch gate are the two things in the art history worth
carrying forward whole.

### `docs/status/look-v1-characters.md` — **KEEP as history, RIP its forward claims**
The four-race silhouette programme (the IoU-under-0.70 target, the human/lizardfolk
problem left as "a decision for Marcel") is work on a model D37 deletes. The measurement
technique (silhouette IoU at 40 m) survives and is worth keeping for one people with
several body types.

### `docs/status/look-v1-ui.md` — **KEEP as history, RIP its deliverable**
The Deco theme, the sunburst backdrop, the stepped panels and the drawn ornaments are
precisely `80-do-dont.md:26`'s don't. The *engineering* judgements (no textures, no
nine-patch, everything drawn, the `--shot-ui` harness) carry over to a nouveau theme
unchanged.

---

## 5. Recommendation for this area (under 200 words)

Three documents become thin pointers: **`docs/DIRECTOR.md`** (link to `director/`, keep
only "what the code does today"), the **Setting** and **Races** sections of `DESIGN.md`
(link to `lore/`), and the **art-direction sections** of `DESIGN.md`, `README.md` and
`CLAUDE.md` (link to `style-bible/`). `docs/research/art-direction.md` keeps a banner and
loses its authority.

`DESIGN.md` survives as the game's **technical** truth and should be renamed to say so:
the parts-as-data and `.vox` drop-in pipeline, the colour pipeline (linear maths, one
wire conversion, `Look.predict()`, the swatch gate), the resolution ladder as engine
grains, the frontier rule, physics, traversal, multiplayer, camera, saves, placeables,
and the creature behaviour stance. Everything in it that names a *look*, a *people*, a
*scale ratio* or a *world extent* goes.

The new shape: `00-TONE.md` above everything; four gameplay pillars in `CLAUDE.md` and
five art pillars from the bible beside them; one engineering doc (`DESIGN.md`), one
queue (`TODO.md`/`ROADMAP.md`), one log (`STATUS.md`). Findings that contradict the bible
go back as D42+, never as local edits — `ROUND-3-BRIEF.md:38` already says so.
