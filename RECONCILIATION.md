# Reconciliation: this repo against the bible

Date: 2026-09-03. Written by the bible-side agent from four read-only audits of this repo, `Kubik-bible` and `Kubik-assets`. The four audits, with every file:line, are in `docs/reconciliation/`. Nothing in any repo was changed by the audit; this file and the appendices are the only additions.

The question Marcel asked: the bible is now the direction and will only be refined from here. This repo was built on an earlier direction. What in it serves the bible and stays, what must be adapted, what must be ripped out or redone. Sunk cost is not an argument, and a full redo was on the table.

The test applied to every system: would you build it this way today, for the bible?

*Amended 2026-09-04 by the docs-only sync, in place and dated, because this is a record and not a live document. Two things happened after it was written. **The pivot (D60 to D83, logged 2026-09-03, hours after this audit):** magic and machines can be joined and it always costs; the burn; no gunpowder; magic is distance, not altitude (D63 replaces D23); the ranged set; the bolts become runes (D65 amends D54); starting people; nobody changes (D70 amends D37 and D51, so the elf and dwarf LOOK is cut and the packs are lean and stocky human bodies); the Perchten as a rite and the animal warriors as creatures (D71); the knowledge ladder (D74, D80). **The north star (D84, 2026-09-04):** the world as big as the view, the view to 32 km, 60 FPS at max settings on mid hardware, which reordered § 9. Every finding in sections 4 to 8 still holds; the sentences the pivot moved carry a parenthesis where they sit.*

## 1. The verdict

Not a full redo. Not "keep it because it is there" either. The repo splits cleanly along one line: everything built for the poster look and the four-race character model goes, and everything built for a streaming, deterministic, host-authoritative voxel world stays.

**Foundation, keep as is.** The streaming world and its determinism contract. The far field with its C++ mesher and its level-of-detail ring ladder. The single host mutation path. The tree pipeline and the tree library. Locomotion, physics, the co-op push, the camera. The UI's behaviour. The probes and galleries. The swatch gate. The seam discipline between GDScript and C++.

**Redo.** The renderer, whole. The character body pipeline. The UI ornament layer. The journal store. Buildings, of which nothing exists.

**Rip.** The four-race table and the lizardfolk. The generated-parts authoring kit. The armour tier ladder. The toon ramp, the banded fog, the poster sky, flat water, the dither, the linear tonemapper. The rule that the game must run without the compiled library. Campfire raids. The "Second Age" framing of the sea. The art-direction sections of the design docs.

**Adapt.** The block palette, the snow rule, the zones, the wildness axis, the sky cycle table, the heightmap store, the creation screen, the animator, the ground-cover grain, the forest-animal scale, the knight template, the weapons bake, and most of the documents.

Why not a full redo: the world plumbing is about fifteen thousand lines that already pass the bible, some of it reached independently before the bible existed. Trees are at real size at the tree grain, the far field never pops, the mutation path is the director's habit three, the UI hides itself when you are safe. Rebuilding those would buy nothing. The third of the code that goes was written for a look and a character model the bible has replaced, and none of it is load-bearing for the rest.

## 2. Where the bible and the repo agreed on their own

Worth naming, because it says the direction was already converging.

- **Deco is the grammar of everything built, never of nature.** `docs/DESIGN.md:59` and pillar 5, word for word in spirit.
- **World cube, player height, tree voxel.** `block_size 0.5`, player four blocks, tree voxel 0.125 m at four per cube. D1 and D21 were written from this repo's own sidecars.
- **Trees at real size, geometry all the way out, no impostor cards.** `tree_models.gd`, `tree_field.gd`. D21 and D41's "never pops in".
- **The chamfered tree meshes stay rejected.** Both repos, the same ruling.
- **No textures on anything.** The one placeholder texture is unused.
- **One host mutation path, clients never write.** `world.gd:1667-1737`. The director's principle four.
- **Campfire cadence, opportunity never walls, verifiable beats, graceful degradation.** `docs/DIRECTOR.md` and `director/00-principles.md` say the same sentences.
- **No minimap ever, a HUD that vanishes when safe, a friend's health only when they are hurt, a read-only sheet.** The tone's "no clutter" as code.
- **Warmth is in the light and the albedo has neither.** `DESIGN.md:133-137`. Pillar 2's "never from repainting a thing".
- **Distant Horizons as the feel.** `docs/research/distant-horizons.md` is D41's engine research, done a day before D41 was written.

## 3. Decisions only Marcel can make

These are not audit findings. They are places where the bible and Marcel's own earlier rulings in this repo disagree, or where the repo committed to something the bible never mentions. Each gets a recommendation.

**Decided 2026-09-03, logged in the bible as D44 to D55.** A both (D44). B real relief with the vista rule (D45). C cap four, design for two (D46). D placed volumes (D47). E the assets-side pipeline (D48). F retire the rule (D49). G the public checkout is source, not a runnable game, since every development and test machine mounts all three repos (D50). H body type, no perks (D51). I about forty minutes (D52). J the forest pack at its own grain, about 1.9 cm (D53). K the bolts stay, against the recommendation, as a spark and a chill that obey altitude, with the lore amended (D54). L sprint and field of view logged as they are (D55). The recommendations below are kept as written for the record.

**A. Bounded or unbounded.** The repo rules the world unbounded by design and forbids any system from assuming a world edge (`CLAUDE.md:54-58`, Marcel, 2026-08-31). The bible's lore has rings zero to four from the capital and "the end of the map" at the Builders' city. Recommendation: both, because they are not the same question. The terrain is unbounded and seeded, with no wall. The content is ringed and ends at the far city, and beyond ring four there is only sea and eerie weather. Keep the "no global-extent assumption" rule, since D41's ten kilometres needs it, and rewrite only the parts of worldgen that measure wildness from the map centre instead of from the capital.

**B. Relief at one to four, or real.** The repo's world is a quarter-size Alps, about 350 m of relief, and the design doc rejects full scale in writing on a traversal argument (`DESIGN.md:522-527, 641-650`). The bible wants a real-sized Alps, and trees are already at real size, so the world is mixed-scale today, which the repo's own one-ratio rule calls a broken world. Recommendation: real relief. D21 fixed the trees, D41 fixed the sightline, and D24's airships, cog rails and ferries answer the traversal objection that killed full scale. The alternative is to shrink the trees back to a quarter, which reverses D21. Cost: terrain retuning and a bigger far field, not new systems. *(2026-09-04: pulled forward - the world-truth break now runs right after horizon v1, D84.)*

**C. Two players or four.** The repo caps at four and tunes for two. The tone and both songs are written for two. Recommendation: keep the cap of four as an engineering allowance and design every encounter and every line of fiction for two. Log it so nobody builds a party frame.

**D. Heightmap terrain, so no overhangs.** The generator is a heightmap (`terrain_generator.gd:16-21`). The bible has mountain gates cut into cliff faces and dungeons. Recommendation: keep the heightmap and make gates and dungeons placed volumes. A gate is a model standing against a cliff, its interior a separate chunk volume stitched in behind the door. Decide before the landmark gate is generated, because it changes what the generator emits.

**E. How buildings enter the world.** D43 settled the grain: tree grain, baked with three level-of-detail rungs like the trees. Three things are still open. Where the house generator lives, since it produced the previews in the bible repo but its script and outputs are in none of the three repos as of this audit. How a landmark of 480 to 960 voxels gets past the 256-voxel limit of the `.vox` format, where the clean answer is to build the grid in memory and bake straight to `.ktree`. And how buildings are placed, since nothing in this repo stamps a structure into terrain. Recommendation: generator and outputs in `Kubik-assets`, a `BuildingModels` sibling of `TreeModels` in the game, and a placement pass that owns roads, footprints and flattening.

**F. The compiled library is a requirement.** Hard rule one says the game must run with no compiled library, which forces a GDScript twin of every C++ path and a parity gate. Under D42 that rule is wrong. Recommendation: retire it, make the extension a build requirement, fix the red `build.yml`, ship the library on every platform, and delete each GDScript twin as its C++ path lands. Keep the quantisation rule, since the gcc-versus-MSVC hazard is real regardless.

**G. The public build has no bought art.** The bible makes the bought templates the only character source and the bought trees the only forest. The public MIT build therefore has no characters and no trees. Recommendation: accept it and say so. The public repo is source; the playable build is a binary with the licensed assets inside it. A placeholder capsule keeps the public checkout runnable for engine work.

**H. What replaces race at character creation.** D37 removes the axis the creation screen is built on. Recommendation: a body-type row, viking, stocky and changed, all one people, with no perks attached to any of them. *(2026-09-04: D51 took it, then D70 amended it the same day. Nobody changes, so "changed" goes and the row is square, lean, stocky; the elf and dwarf look - the ears, the beard-as-identity, the winged helmets - is stripped by script. D66 adds a second row, the starting people, soft: it sets the first fire, the kit and the recipes, never stats and never a lock.)*

**I. Day length.** A full day is eight minutes (`worldgen_config.gd:1570`). The tone wants slowness and an evening that lands like the song's swell. Recommendation: a day in the tens of minutes, and the pink-then-violet evening never shorter than a few minutes.

**J. The forest-animal grain.** The bible contradicts itself: it asks for the forest pack at the character grain and for a bear at 0.7 players at the shoulder. At the character grain the bear is 5.7 m long. Recommendation: give the forest pack its own grain of about 1.9 cm per voxel and accept the finer texture, and fix the sentence in `70-scale-metrics.md`.

**K. A player's magic verb.** Fire and frost bolts are out under the lore's "nobody throws lightning". The bible says what magic is, not what a player does with it. Recommendation: strike the bolts now, keep the co-op glue idea, and decide the verb list later from wards, weather, calming beasts, horns and masks. *(2026-09-04: the decision above, D54, was amended the same evening it was taken. D65 turns the bolts into a fire rune and a frost rune with the same mechanics, carried as rune stones that dim with use and are recharged at a magic site (D76); and D63 replaces D23, so they obey DISTANCE from the capital, never altitude. The line "a spark and a chill that obey altitude" in the paragraph above, and the same phrase in § 8's DESIGN.md row, are stale in exactly that one word.)*

**L. Sprint speed and field of view.** Sprint is 13 m/s, field of view 75 degrees, neither in the bible, and the sprint sits against the tone's slowness. Recommendation: log both as they are for now and revisit with the real-scale terrain, since traversal changes when the mountains do.

The full candidate lists, about seventy items across the four audits, are in the appendices. Most are engineering facts worth ratifying, not choices.

## 4. What stays

| System | Where | Why it passes |
|---|---|---|
| Chunk store, world hash, streamer | `chunk.gd`, `world_hash.gd`, `world.gd` | A disc of columns, nearest-first, a park cache, a sixteen-sector frontier that took hole samples to zero. An unbounded seeded world needs exactly this. |
| The host mutation path | `world.gd:1667-1802` | Request, validate, apply, journal, broadcast. The director's habit three, built. |
| The far field's ring ladder and C++ mesher | `far_field_job.gd:60-128`, `gdext/src/far_*` | Sixteen times the visible area for a fifth more vertices. The code says ten kilometres needs one more ring and nothing else. |
| `FarUpload` | `far_upload.gd` | Budgeted main-thread upload with an atomic swap. Any far field needs it. |
| The seam discipline | `far_mesher.gd:14-29`, `height_tiles.gd:20-36` | Data in, arrays out, native noise, heights quantised to one part in 1024 on both legs. What makes world truth in C++ safe. |
| Trees: pipeline, library, renderer | `Kubik-assets/tools/trees_convert.py`, `scripts/world/flora/tree_*` | D21 to the number, and D43 reuses it unchanged for buildings. |
| Per-cube grain | `look.gd:238-300` | The bible's material noise rule, measured under-strength. Keep the mechanism, raise the range. |
| Locomotion, physics, push, bodies | `scripts/physics/` | One shared step on host and client. The boulder that says "not on your own" is the tone as physics. |
| Camera | `player.gd:7-10` | Third person only, for the bible's reason. |
| UI behaviour | `hud.gd`, `compass.gd`, `party_icons.gd`, `character_screen.gd` | No minimap, a HUD that vanishes, health only when hurt, a read-only sheet. |
| `stats.gd` | `scripts/game/stats.gd` | No hunger, no thirst, nothing drains. The tone's anti-survival rule passes. `mp` stays with the bolts (D54) *(the runes, since D65)*. |
| `purchased_view.gd` | `scripts/character/purchased_view.gd` | The only bible-shaped character path in the repo. Promote it. |
| Probes, galleries, the swatch gate | `scripts/tools/`, `look.gd:predict()` | The instruments round 3 is graded with. The gallery already has a campfire sheet. |
| Fonts, the template `.vox` files, the animal warriors | `assets/fonts/`, `Kubik-assets/game/` | The warriors are the Perchten at the character grain with 181 clips. |

## 5. What is ripped

| Item | Where | Bible rule | Effort |
|---|---|---|---|
| The four-race table and the lizardfolk | `races.gd`, `parts_author/lizardfolk.py`, its rows in `hair.json` and `armour.json` | D37, only humans. The lizardfolk has no asset and no place in the lore. | L to replace with body types |
| The generated-parts kit and its output | `tools/parts_author/` (2,912 lines), `assets/characters/parts/` (32,897 lines, 1.8 MB) | D1, templates as they are. The grain moved three times and re-authored every part each time. Park the JSON, do not delete it yet. | L |
| The armour tier ladder | `armour.gd:51-58`, `armour.json` (1.1 MB) | D27, plate is the Engineers' uniform, not tier four. It never passed its own gate. Keep two sentences: proportions relative and thicknesses absolute, and a tier is outline events. | M |
| The toon ramp, ambient off, hard shadows | `look.gd:100-151`, `sky_cycle.gd:157-159, 325` | Pillar 2, D5, D8. | M |
| Banded fog | `look.gd:206`, `worldgen_config.gd:940` | The three fog jobs need a volume, not a depth quantiser. | M |
| The poster sky | `look.gd:354-550` | D18 cubic clouds, D5 rays only in the capital. "No painted skies." | L |
| Altitude bands, flank normals, riser shading on the far field | `worldgen_config.gd:954-959`, `far_field_job.gd:1382-1407` | They exist only because the toon ramp facets. | M |
| The Bayer dither | `look.gd:898-942` | D41, nothing arrives at a boundary. The geomorph already fixed the fizz. | S |
| Flat non-reflective water | `look.gd:326-351`, `lakes.gd:390-429` | D5, water reflects. | M |
| The linear tonemapper and the empty environment | `sky_cycle.gd:362-372`, `scenes/game.tscn:19-24` | D40 needs roll-off, glow, a LUT. | S |
| `world_scale := 4.0` and every reader that needs a map edge | `worldgen_config.gd:50, 106-113`, `lakes.gd:16-17`, `wildness_at` | Decisions A and B above. | L |
| Hard rule one and the GDScript twins | `far_field_job.gd` (1,951 lines), the parity harness | Decision F. | S to retire, then savings |
| Campfire raids, the blood-moon dial | `DESIGN.md:728-732`, `IDEAS.md:345-347` | The fire is where dread ends. | S |
| The "Second Age" sea framing, island kingdoms, the lizardfolk homeland | `IDEAS.md:366-401` | D26, the sea is rings two to four of the one world. | S |
| The UV-atlas roadmap item | `chunk_mesher.gd:10-13` | Pillar 2. Park the 560-byte file. | S |
| `weapons_convert.py` | `Kubik-assets/tools/` | Dead Windows path, one-shot, superseded by a `.vox` bake. | S |

## 6. What is rebuilt

| System | Why a redo, not an adapt | Effort |
|---|---|---|
| The renderer | `look.gd` is 1,128 lines and everything load-bearing is on the rip list. Rebuild as a thin materials module over Godot's own lighting, plus a compositor post chain for D40: grain, halation on emissives only, soft roll-off, LUT, gentle vignette. Carry `to_wire()`, the grain, `predict()` and the swatch gate. | L |
| The mesher's colour path | Five paint operations do what light should do. Emit one flat albedo per material plus the per-cube noise. This also removes the AO-versus-merge constraint, so quads get bigger and meshing gets faster. | M |
| Fog | Three jobs, valley bands, pooling at feet, hiding tops, need volumetric fog and fog volumes. Different mechanism. Carry the exponential curve and the cylindrical distance as the far term. | M |
| Warm light | No emissive block, no point light ever exercised, no campfire, no window. The tone's most-named image is wholly unbuilt. | M |
| Weather and eerie | Nothing exists. D16 and brief items five and six. | M |
| Regions | One global autumn flag. The bible has alpine, autumn, wild-colour and winter, recognisable from a distance by tree colour, so the region must reach the far field's colour vote. | M |
| The character pipeline | Promote `purchased_view.gd` to the path `CharacterView` takes, drive the packs' clips from `LocomotionState`, keep `rig.gd` for rigid props on sockets, keep the animator's additive layers (head look, blink, idle breaks). | M |
| The journal store | Forty-seven lines of untyped dictionaries, in memory, no schema on purpose. The bible is the second consumer and asks for typed facts with IDs, a chronicler, salience and persistence. Keep the call sites in `world.gd` and `stats.gd`. | M |
| The UI ornament layer | `deco.gd`, `deco_panel.gd`, `deco_rule.gd`, `poster_backdrop.gd`, `deco_theme.tres` are deco geometry on paper, the exact don't in `80-do-dont.md`. Nouveau frames, tarot cards, halo portraits, a serif body face, no black ink. The behaviour underneath stays. | M |
| Buildings | Nothing exists in the game. A `BuildingModels` loader as a sibling of `TreeModels`, placement, the landmark generator, the `.ktree` direct bake. | L |
| Creatures | Nothing is built, so nothing to rip. The design invents fauna where the lore wants beasts that were once ordinary, and makes the marmot cute. Megafauna witnessed more than fought stays. *(2026-09-04, D70 and D71: nobody changes, so the Perchten are a WINTER RITE of the mountain folk - masked people, not creatures - and it is the animal-warrior assets that become creatures of the outer rings.)* | L |
| Combat and death | Designed, unbuilt, silent on D39. Write the restraint rule and "death is remembered" into the journal before the first hit lands. | M, design |

## 7. What is adapted

| System | Change | Effort |
|---|---|---|
| Block palette | The bible's hexes, one flat colour per material; the three shades come from light. | S |
| Snow | An altitude line as the primary rule; keep the slope cutoff as the modifier. | M |
| Zones | The bible's five bands; expose the tree line as a queryable altitude for placement; replace percentiles, which do not survive an unbounded world. | M |
| Wildness | Distance from the capital in metres, driving the ring table: biome, weather, ruin size, lit windows *(and, since D63, how strong the magic is: thin at the centre, stronger with every ring out, with altitude no longer a rule)*. The highest-leverage adapt in the world. | M |
| Sky cycle | Keep the keyframe machine; re-author to day, pink evening, violet dusk, slate night, plus eerie as a modifier; drop the hour-tinted gold. | M |
| Heightmap store | Per-tile arrays with an apron; lakes, spawn, zones and the far marshal onto a tile API. Eight files, acceptance a byte-identical world. | L |
| Far ring table | One more ring and a ten-kilometre preset. Buys nothing until the world is bigger than three kilometres. | S |
| Character creation | Body-type row, dark bases plus gold trim, no perks. The table-driven screen survives. | M |
| Animator | Clip selector over the packs' clips; keep the distance-driven phase idea as the sync target. | M |
| Ground cover | Fifteen voxels per cube for props; boulders are terrain; sparse. | S |
| Forest animals | One global scale to about 1.9 cm per voxel. | S |
| Knight template | Split into a repaint pass emitting `.vox` and an optional armour author; fix the dead path; no painted face. | M |
| Weapons | Re-bake from the 27 `.vox` and 49 `.vxm` sources through the tree route; drop the textured glTFs. | S |
| Tree canopy colours | The bible's grey-green conifer ramp. One file, no re-bake. | S |
| The asset mount | Five commits stale, no trees mounted. Run `sync_assets.py`. | minutes |

## 8. The documents

- **`README.md`, `CLAUDE.md`.** *(Done 2026-09-04, except README § Running it, which the horizon v1 and mesher v1 lanes owned that night; the last of hard rule one still stands in it.)* Keep the architecture, the probes, the build notes, the three habits. The four pillars become gameplay pillars under `00-TONE.md`, beside the bible's five art pillars. Pillar three's citation points at the bible. The worldgen guidance is rewritten per decision A. The pitch loses "cozy" as the world's register and keeps it for the fire.
- **`docs/DESIGN.md`.** Split. *(Done 2026-09-04.)* It survives as the game's technical truth: the parts-as-data and `.vox` drop-in rule, the colour pipeline, the resolution ladder as engine grains, the frontier rule, physics, traversal, multiplayer, camera, saves, placeables, the creature behaviour stance. Its setting, races, scale ratio, unbounded ruling, art rules and fantastic roster go, replaced by pointers to `lore/` and `style-bible/`. Its magic section stays, amended to D54: the bolts are a spark and a chill that obey altitude.
- **`docs/DIRECTOR.md`.** A thin pointer to `director/`. *(Done 2026-09-04.)* The verb table is ripped: every signature is the free-text, no-ID shape D34 forbids. The eight hardening rules, D35 and D36 are added. The storm-scholar goes; the bible's stranger is a masked figure whose people is open.
- **`docs/IDEAS.md`, `docs/ROADMAP.md`, `TODO.md`.** *(Done 2026-09-04.)* Keep the structure. Look v3 "the painted world" is replaced by the round 3 test scene. Sites v1 inherits the four building families and the rings. Fog, the lens and the far view become engine work items.
- **`docs/research/art-direction.md`.** *(Done 2026-09-04.)* Evidence, not authority. Its colour-transfer finding and its measurement method are the bible's own method.
- **The plans and status files.** History. Mark the look plans superseded. *(Done; and `look-v2-tech.md` now says in its own banner that its shape is the template, so the banner is not read as retiring that too.)* `look-v2-tech.md` is the work-order template round 3 should be run in.

Two things the audit found in the bible itself go back as fixes: the "13 orange variants" is twelve, and the assets plan double-counts the winter animals and the animal warriors, which are one pack. The stale "6 heads" was fixed during the audit.

## 9. Order of work to the round 3 test scene

The brief needs a landmark gate, five houses, a campfire with two viking players, a real-size forest, fog, four hours plus eerie, and the film lens. Trees are done. Characters are one promotion away. The campfire is an afternoon. Buildings are the long pole, and rendering is the bulk.

*Reordered 2026-09-04 (D84): horizon v1 joins 1b at the front, and the world-truth break moves from after the scene to right after horizon v1. The scene slips by about a month; Marcel's call, with the north star as the reason.*

*Reordered again 2026-09-05 (D85): horizon v1 landed with the median frame gate met and the hitch gate open, the cause measured as the chunk and flora upload on the frame thread. Upload v1 runs next, alone, as 1d; the world-truth break moves to right after it. D56's bundle is unchanged; only its timing moves again. Marcel's call.*

| Phase | Work | Effort |
|---|---|---|
| 0. Housekeeping | Fill the eight blank seller fields in the licence records. Run `sync_assets.py`. Land the house generator and its outputs in `Kubik-assets`. Log decisions A to L in the bible. | hours |
| 1. Real light | New environment, sun with soft sky-tinted shadows, sky ambient, filmic tonemap. Rip the ramp. Then the four hours plus eerie in the sky cycle. Then volumetric fog's three jobs. Then the bible palette and the stripped mesher colour path. Then the D40 lens pass. Then reflective water. | about two weeks |
| 1b. The chunk mesher in C++ (D56) | The first unattended C++ epic, once the material rule is proven on screen: voxels in, arrays out, one flat colour per material plus per-cube noise, no baked corner shading, so quads merge bigger. Removes about three quarters of the column cost before fog and buildings add theirs. Cannot break a world: the mesher decides how a chunk looks, never what it is. | about one week |
| 1c. Horizon v1 (D41, D44, D84) | Pulled to the front by Marcel on 2026-09-04, in parallel with 1b: origin-anchored height tiles at every level, voxels anywhere, the far field to 32 km as persistent per-ring, per-sector meshes that re-mesh only what moved, one material source for every level, a fog ramp normalised to the draw distance, a floating origin, and the sprint probe that measures the frame while moving. Changes nothing a seed produces. `docs/plans/horizon-v1.md`. | three nights |
| 1d. Upload v1 (D85) | Added 2026-09-05, right after 1c landed. The chunk and flora upload off the frame thread: `add_surface_from_arrays` plus a collision shape per column, 214 columns a second, is the whole hitch column of horizon v1's sprint line (171 to 233 frames of about 3,340 over 25 ms at Ultra, 32 km), and a smaller upload slice makes it worse. Fewer, larger surfaces per column, or a mesh handed to the rendering server without the frame thread touching it. Look-only; changes nothing a seed produces. `docs/plans/upload-v1.md`, not yet written. | nights |
| 2. The world-truth break (D56, timing amended by D84 and D85) | One epic, right after upload v1 lands (D85) and before people and fire, before any content is authored on a seed: real relief (D45), rings measured from the capital (D44), the tiled heightmap store, the generator, lakes and zone pass in C++, the 10 km far field. Every one of these changes what a seed produces, so they happen once and together. About two to three weeks. | weeks |
| 3. People and fire | Promote `purchased_view.gd`, load two vikings, drive the sit pose from the packs' clips. The campfire prop with an emissive core and a point light. Rip races and the parts kit behind a flag first, delete after the scene passes. | about one week |
| 4. Buildings | `BuildingModels` loader. Place five houses at the tree line with flattened footprints. The landmark generator with setbacks, flutes, sunburst and crown, baked straight to `.ktree`. Place it on a knoll. | one to two weeks |
| 5. The scene and the report | The brief's shots and measurements, into `discussions/11-ROUND-3-REPORT.md` in the bible. | days |
| 6. After that | The journal with typed facts and IDs, the nouveau UI, creatures, combat and death. | months |

Nothing in phases five and six is needed for one valley. Do not let them in early. The mesher is the one engine item pulled forward, because it is safe at any time and it is the biggest single cost.

## 10. What this costs, honestly

Roughly a third of the GDScript goes: the parts kit and its JSON, the renderer, the far field's GDScript twin, the races and armour, the deco UI, and about two thousand lines of character self-tests that test the pipeline being removed. What stays is the part that took the longest to get right and is measured: the streamer, the far field, determinism, trees.

The single largest new thing is not on any rip list. It is warm light and buildings, which never existed in either direction. The second largest is the renderer, which is smaller to rebuild on the engine's own lighting than to argue with.

## Appendices

- `docs/reconciliation/01-direction-docs.md`: every direction statement in this repo's documents against the bible. Forty-one conflicts, twenty-eight agreements, twenty-four candidate decisions.
- `docs/reconciliation/02-world-render.md`: the world, terrain and rendering code. Inventory with measured costs, the GDScript-versus-C++ case, fourteen candidate decisions.
- `docs/reconciliation/03-gameplay-characters-ui.md`: characters, creatures, flora, gameplay, networking and UI. Twenty verdicts, thirty-seven candidate decisions.
- `docs/reconciliation/04-assets.md`: the assets repo, the tree pipeline measured from its sidecars, the gaps, and the licensing check.
