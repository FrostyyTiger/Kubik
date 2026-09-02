# Kubik repo vs Kubik-bible — audit of characters, creatures, flora, gameplay, networking and UI

Date: 2026-09-03. Auditor: read-only pass over `/Users/marcel/Documents/Kubik` (game),
`/Users/marcel/Documents/Kubik-bible` (authoritative direction), `/Users/marcel/Documents/Kubik-assets`.
Nothing was modified in any of the three repos.

Test applied to every item: **would you build it this way today, for the bible?**
Engine is fixed (D42: Godot 4 + C++ GDExtension for hot paths). Sunk cost is not an argument.

Note on numbering: the brief said "candidate decisions D42 onward". D42 was taken while this
audit ran (`/Users/marcel/Documents/Kubik-bible/03-DECISIONS.md:267` — the engine decision; the
file's own Status line now says "Next number: D43"). The candidate list in section 3 is therefore
numbered **D43 onward**.

---

## 0. The headline conflict, stated once

The bible's D1 says characters are **"built on the bought templates as they are (59-69 voxels
tall, big-headed and about 3 heads tall, reskinned clothes only)"**
(`/Users/marcel/Documents/Kubik-bible/03-DECISIONS.md:17`), one character voxel ≈ 3.3 cm,
**15 character voxels per 0.5 m world cube** (same line), and
`/Users/marcel/Documents/Kubik-bible/style-bible/40-characters.md:3` adds *"their proportions,
grain and rigs are not changed"*.

The repo builds characters the opposite way. `/Users/marcel/Documents/Kubik/scripts/character/voxel_model.gd:76`
sets `const VOXEL_M := 2.0 / 96.0` — **24 model voxels per world block, 2.083 cm, a human 96
voxels tall** — and `/Users/marcel/Documents/Kubik/docs/DESIGN.md:351-354` calls that
*"Settled by character v1, re-settled by look v1, re-settled by character v2."* Every body is
generated from ASCII slices by a Python authoring kit
(`/Users/marcel/Documents/Kubik/tools/parts_author/`), not reskinned from a bought `.vox`.

This is not a tuning difference. It is two different pipelines with no shared artefact:

| | Bible (D1, 40-characters.md) | Repo (voxel_model.gd:76, DESIGN.md:351) |
|---|---|---|
| Source of a body | bought `.vox` template, reskinned | generated ASCII slices from Python |
| Voxels per world cube | 15 (3.3 cm) | 24 (2.083 cm) |
| Player height in voxels | 59-69 | 96 |
| Proportion | ~3 heads, as the templates | head ≈ 1/3 height (close), but authored |
| Animation | the packs' ~200 clips | procedural, no clips (`animator.gd:4`) |
| Races | one people (D37) | four, incl. lizardfolk (`races.gd:24`) |

Everything in section 2 about the character system follows from this row.

---

## 1. Inventory

Line counts are `wc -l` on 2026-09-03. Subsystem totals: `scripts/character` 4,728;
`tools/parts_author` 2,912 (Python); `assets/characters/parts/*.json` 32,897 lines / 1.8 MB;
`scripts/world/flora` 5,872; `scripts/physics` 1,586; `scripts/ui` 3,954; `scripts/net` 296;
`scripts/player` 655; `scripts/game` 1,692.

### 1.1 Character body pipeline — parts_author + parts_data + voxel_model + rig

Files: `/Users/marcel/Documents/Kubik/tools/parts_author/{__main__,voxlib,human,elf,dwarf,lizardfolk,hair,gear,armour,critter}.py`
(2,912 lines); `/Users/marcel/Documents/Kubik/assets/characters/parts/*.json` (32,897 lines,
1.8 MB, of which `armour.json` is 20,873 lines / 1.1 MB and `hair.json` 6,316 / 384 KB);
`/Users/marcel/Documents/Kubik/scripts/character/parts_data.gd` (132);
`/Users/marcel/Documents/Kubik/scripts/character/voxel_model.gd` (503);
`/Users/marcel/Documents/Kubik/scripts/character/rig.gd` (464);
`/Users/marcel/Documents/Kubik/scripts/character/vox_loader.gd` (305).

What it does: Python generators author every body part as ASCII slices in 20 semantic slots
(`voxel_model.gd:84-109`), write JSON, and GDScript meshes them onto a Node3D skeleton
(`rig.gd:5-20` — deliberately not a `Skeleton3D`). A `.vox` drop-in path exists
(`vox_loader.gd:5-9`): if `assets/characters/<race>/<part>.vox` exists it replaces the ASCII part
at load; a `.vox` whose palette indices 1-13 are the slot legend keeps palette swaps
(`vox_loader.gd:19-24`).

Status docs: see §1.11.

### 1.2 Races — `scripts/character/races.gd` (839 lines)

Four races as a hard enum: `HUMAN=0, ELF=1, DWARF=2, LIZARDFOLK=3`
(`/Users/marcel/Documents/Kubik/scripts/character/races.gd:16-24`). Every per-race number lives
here (`races.gd:5-10`): totals 96 / 108 / 72 / 90 voxels = 2.00 / 2.25 / 1.50 / 1.88 m
(`races.gd:137,152,168,183`); lizardfolk carries `snout`, `tail_len: 42`,
`tail_segments: [12,12,10,8]`, `lean_deg: 26.0` and a digitigrade `leg_stance`
(`races.gd:186-194`). Per-race gait multipliers (`races.gd:135-136,150-151,166-167,181-182`),
per-race palettes of 5 skins / 5 hairs / 4 eyes (`races.gd:212-231`), a fixed near-black liner
`#14100C` (`races.gd:279`) and four value tiers (`races.gd:299-302`).
Design intent is recorded as *"race is never a stat"* (`races.gd:5-6`).

### 1.3 Character definition, armour and skills

`/Users/marcel/Documents/Kubik/scripts/character/character_def.gd` (397): 20-byte wire format,
version 2 (`character_def.gd:26-34`), fields race/build/skin/hair_color/eyes/hair/beard/name plus
six armour slots and six tiers (`character_def.gd:49-86`). Host clamps every claim
(`character_def.gd:94-124`).

`/Users/marcel/Documents/Kubik/scripts/character/armour.gd` (254): six slots
(`armour.gd:72-85`), a five-tier ladder `none / cloth / hide / mail / plate / named` with
0/0/1/1/3/5 outline events (`armour.gd:51-58`), pieces per slot per tier
(`armour.gd:123-130`), and an asymmetric tier-5 `pauldron_runed` with a glow slot capped at
12 voxels (`armour.gd:142-144`, `races.gd:322-327`). It states it is not an item system
(`armour.gd:5-10`).

`/Users/marcel/Documents/Kubik/scripts/character/skills.gd` (26): five names only —
`["Blades", "Bows", "Magic", "Mobility", "Gathering"]` (`skills.gd:17`), rendered as a dash
(`skills.gd:22`). No levels, no XP, nothing spendable.

### 1.4 Character view, animation, purchased-template stand-in

`/Users/marcel/Documents/Kubik/scripts/character/character_view.gd` (242) — the single visual
entry point; `build(def)` is idempotent and rebuilt on every creation-screen click
(`character_view.gd:12-17`).
`/Users/marcel/Documents/Kubik/scripts/character/animator.gd` (895) — **procedural animation, no
clips, no AnimationPlayer** (`animator.gd:4`); the walk cycle is driven by distance not time
(`animator.gd:14-20`); poses include sit, downed and wave (`locomotion_state.gd:23-28`).
`/Users/marcel/Documents/Kubik/scripts/character/character_config.gd` (260) — every eye-tuned knob;
triangle budget **48,000 per character**, measured worst case 44,936 on the dwarf
(`character_config.gd:30-54`).
`/Users/marcel/Documents/Kubik/scripts/character/purchased_view.gd` (127) — **the only
bible-shaped path in the repo**: loads `assets/purchased/characters/viking/male_a1.gltf`
(`purchased_view.gd:20`), normalises its height, drives its ~200-clip AnimationPlayer from the
same `LocomotionState` (`purchased_view.gd:14-18,73-90`). Opt-in behind `--viking` /
`KUBIK_VIKING=1` (`purchased_view.gd:33-36`) and explicitly labelled *"DEMO SCAFFOLDING, NOT THE
CHARACTER PIPELINE"* (`purchased_view.gd:6-8`).

### 1.5 Creatures

**There is no creature system.** The only non-humanoid is `critter` — a four-legged test rig whose
own header says *"IT EXISTS TO FAIL LOUDLY IF ANY OF THIS IS SECRETLY HUMANOID... GALLERY ONLY. No
AI, no scene, no spawning, no CharacterDef"* (`/Users/marcel/Documents/Kubik/tools/parts_author/critter.py:74-81`),
plus `scripts/character/parts/parts_critter.gd` (81) and `assets/characters/parts/critter.json`
(548 lines). `DESIGN.md:674-675` confirms: *"Nothing here is built yet."*

The purchased animal art is already mounted: `assets/purchased/creatures/` holds bear, deer, fox,
moose, owl, rabbit, raccoon, squirrel, wild_boar, wolf (32 MB), and
`assets/purchased/weapons/` holds axe, dagger, hammer, polearm, scythe, spear, staff, sword
(6.2 MB). No code reads either.

### 1.6 Flora and trees — `scripts/world/flora/` (5,872 lines)

`tree_models.gd` (643) loads a baked library from `assets/purchased/trees/*.ktree` with
`const VOXELS_PER_BLOCK := 4` — **0.125 m per tree voxel** (`tree_models.gd:47-53`), three LOD
rungs (`tree_models.gd:55-56`), GDScript assembles quads and never meshes (`tree_models.gd:33-41`).
`tree_table.gd` (459) maps game species to pack variants and keeps heights native: *"The library
lands at 21-28 m for the trees proper"* (`tree_table.gd:24-31`).
`tree_species.gd` (541) is now data only — seven species SPRUCE/BEECH/LARCH/KRUMMHOLZ/BIRCH/SNAG/HERO
(`tree_species.gd:72-82`); the 2,851 lines of block-tree shape code were deleted
(`tree_species.gd:5-18`, `/Users/marcel/Documents/Kubik/STATUS.md:28-34`).
`tree_field.gd` (459) is the single tree renderer, geometry all the way out, **no impostor cards**
(`tree_field.gd:4-25`). `tree_placement.gd` (1,011) and `tree_palette.gd` (211) — the repo owns the
colours, the artist owns the shapes (`tree_palette.gd:6-16`).
`far_tree_meshes.gd` (37) is a deleted file kept as its own gravestone (`far_tree_meshes.gd:3`).
`flora_models.gd` (916) / `flora_placement.gd` (602) / `flora_column.gd` / `flora_job.gd` are ground
cover on a separate decoration layer at 8 voxels per block = 6.25 cm, with boulders at 2 and shrubs
at 4 (`flora_models.gd:34-62`).

### 1.7 Gameplay: game, journal, stats, physics, player

`/Users/marcel/Documents/Kubik/scripts/game/game.gd` (1,510) — join handshake, the authoritative
state table (`game.gd:59-74`), 20 Hz position sync (`game.gd:19`), host-side `PlayerSim` per peer.
`/Users/marcel/Documents/Kubik/scripts/game/journal.gd` (47) — an in-memory array of untyped
dictionaries; *"there is no schema on purpose"* (`journal.gd:30-31`), *"IN MEMORY, AND DELIBERATELY
NOTHING ELSE. No file, no rotation, no cap"* (`journal.gd:21-24`), host only (`journal.gd:18`).
`/Users/marcel/Documents/Kubik/scripts/game/stats.gd` (135) — hp/sp/mp, all 100.0
(`stats.gd:34-38`), one mutation seam `apply_delta()` that journals with a cause string
(`stats.gd:85-111`), and *"THERE IS NO DEATH IN THIS TABLE"* (`stats.gd:22-26`).
`scripts/physics/` (1,586) — `locomotion.gd` (401) is the one movement step both host and client
run (`locomotion.gd:6-19`); `player_sim.gd` (215) is the host's invisible body per remote peer;
`body_field.gd` (454), `world_body.gd` (161), `world_body_view.gd` (80), `push.gd` (159) —
the co-op push rule, two players move a `boulder_l` (`push.gd:6-18`, `body_table.gd:12-17`);
`body_table.gd` (116) — three kinds, boulder_m/boulder_l/log.
`scripts/player/player.gd` (520) — third-person orbit camera on a SpringArm3D, *"There is no
first-person mode and there is not going to be one"* (`player.gd:7-10`); camera far plane is driven
from the fog end (`player.gd:514-520`).

### 1.8 Networking — `scripts/net/` (296 lines) + the mutation path in `world.gd`

`net_manager.gd` (201), autoloaded as `Net` (`project.godot:25`); role OFFLINE/HOST/CLIENT
(`net_manager.gd:32`); single player is a host with nobody joining (`net_manager.gd:12-13,93-97`);
max 3 clients (`net_manager.gd:30`). `net_transport.gd` (47) / `enet_transport.gd` (48) — a seam
sized exactly for the later Steam swap and nothing more (`net_transport.gd:11-14`).
The one mutation path is drawn in `/Users/marcel/Documents/Kubik/scripts/world/world.gd:1667-1681`
and implemented at `world.gd:1709-1737`: anyone calls `request_set_block()`, a client RPCs peer 1,
the host validates, applies, journals (`world.gd:1778-1783`) and broadcasts. *"Clients never write to
their own chunks, not even optimistically"* (`world.gd:1678-1681`).

### 1.9 UI — `scripts/ui/` (3,954 lines) + `assets/ui` + `assets/fonts`

Two registers, stated at `/Users/marcel/Documents/Kubik/scripts/ui/hud.gd:4-15`: the **field
register** (HUD) and the **poster register** (menu, creation, sheet).

- `deco.gd` (158) — the UI palette: PAPER `#F2E8D0`, PAPER_SHADE `#E3D6B4`, INK `#1E2430`,
  GOLD `#C9A24A`, ALPINE `#2F5D8A`, SUN `#E8863A`, INK_PALE `#7D7C78` (`deco.gd:17-33`), plus four
  drawn ornaments: dots, chevron, roundel, stepped frame (`deco.gd:64-108`).
- `deco_rule.gd` (40) — a double gold rule with square terminals.
- `deco_panel.gd` (50) — the stepped corner, ink r14 / gold r10 inset 5 / paper r6 inset 10
  (`deco_panel.gd:15-19`).
- `poster_backdrop.gd` (164) — a drawn Art Deco poster: a 24-pair tapered sunburst
  (`poster_backdrop.gd:19-26`) and three ranges of **stepped** mountains, *"a Deco mountain is a
  ziggurat, not a cone"* (`poster_backdrop.gd:46-48`).
- `hud.gd` (562) — bottom-centre cluster (3 bars + hotbar), top strip, four empty corners, and the
  fade: *"when you are safe, nothing at all"* (`hud.gd:4-15`).
- `compass.gd` (156) — a strip, **no minimap and no setting that turns one on**
  (`compass.gd:4-7`); north is -Z (`compass.gd:19-34`).
- `hotbar.gd` (142) — five slots; slot 1 is the debug SLAB tool (`hotbar.gd:29-35`).
- `party_icons.gd` (136) — one roundel per party member; a friend's health appears **only when they
  are in trouble** (`party_icons.gd:10-14`); zero icons solo (`party_icons.gd:16-17`).
- `character_creation.gd` (419) — race, palette swaps, hair/beard, name. *"NO SLIDERS. NO STATS."*
  (`character_creation.gd:5-7`).
- `character_screen.gd` (283) — the sheet: turntable, six armour sockets, five skills, read-only
  (`character_screen.gd:4-10`).
- `main_menu.gd` (213), `character_preview.gd` (173), `hud_config.gd` (138), `hud_tuner.gd` (159),
  `ui_mouse.gd` (80), `ui_shot.gd` (144), `character_debug.gd` (328), `debug_hud.gd` (609).
- `assets/ui/deco_theme.tres` (8,962 bytes) is the **project-wide theme** (`project.godot:54`), so
  every Control opts out of the poster rather than into it (theme header comment).
- `assets/fonts/` (412 KB): **Limelight** (Deco display), **Josefin Sans Variable** (geometric sans,
  tracked capitals for buttons), **Poiret One** (the line under a title) — theme header. All three
  OFL, licence files beside them. No serif face is present.

### 1.10 Tools and probes in scope

`scripts/tools/character_gallery.gd` (2,036) — photographs characters on a flat pad under frozen
light; includes a **campfire sheet**: four characters in tier-3 gear, seated, at dusk t=0.78,
framed from the row's own span (`character_gallery.gd:1030-1061`), with the note *"If this image is
not one Marcel would put on a poster, the epic is not done"* (`character_gallery.gd:1028-1029`).
`model_gallery.gd` (1,184) — every tree and plant side by side, with `--vary`, `--stand`, `--masks`,
`--trees` modes (`model_gallery.gd:6-20`).
`tree_probe.gd` (175), `flora_probe.gd` (113), `physics_probe.gd` (147), `traversal_probe.gd` (308),
`selftest.gd` (3,595), `selftest_character.gd` (2,411).

### 1.11 What the status and plan docs say, with numbers

All paths below are relative to `/Users/marcel/Documents/Kubik/`.

**The character grain has moved three times, and each move cost a re-author.**
`docs/plans/character-v1.md:196-197` — 1/8 of a block, 6.25 cm, human 32 voxels.
`docs/status/look-v1-characters.md:11-13` — 1/16, 3.125 cm, human 64; *"Every part re-authored"*
(`look-v1-characters.md:16`). `docs/plans/character-v2-tech.md:643-646` — 1/24, 2.083 cm, human 96.
The triangle budget followed it: **6,000** (`character-v1.md:377`) → **24,000**
(`look-v1-characters.md:66-68`) → **44,000** (`docs/status/character-v2.md:551-554`) → **48,000**
(`docs/status/character-v2.md:770`). Measured triangles per character at each grain:
human 3,308 → 16,824 → 38,828; dwarf (worst) 4,104 → 17,740 → 40,268 → 44,936
(`docs/status/character-v1.md:138-145`, `look-v1-characters.md:88-94`,
`docs/status/character-v2.md:541-549`). Retained voxel memory for the dwarf went 413 KB → **1,401 KB**;
a party of four is 5.5 MB (`docs/status/character-v2.md:541-559`).

**Character v2 ran 13 stages over two nights and did not pass its own tier gate.**
`docs/status/character-v2.md:1387-1388` — the tier ladder is *"NOT PASSED"*, 6 of 24 rows off; the
measured ladder is human 1/1/3/4, elf 1/1/2/3, dwarf 1/1/3/5, lizardfolk 1/2/5/6 against a wanted
1/1/3/5 (`docs/status/character-v2.md:1095-1101`). Its own acceptance shot — the campfire — is
recorded as *"Honestly: it is not yet a poster… the gorget reads as a tray; and there is no fire"*
(`docs/status/character-v2.md:1357-1362`). Self-tests went 28 → 35
(`docs/status/character-v2.md:1404-1415`); 67 sheets are shot per run.
Ranked leftovers (`docs/status/character-v2.md:1428-1443`): the tier ladder's six rows, the armour
shapes (*"the helms read as caps and the gorget as a tray"*), stateful animation details, the elf's
hair, hands and boots up 15%.

**The silhouette work is the one place the generated pipeline beat its target — on a problem D37
deletes.** Human/lizardfolk IoU went 0.913 → **0.664** and cross-race variant pairs over 0.70 went
15 of 94 → **1 of 94** (`docs/status/character-v2.md:806-815`). That result exists only because four
races had to be told apart at 40 m.

**The parts data move was already done once, and it is the shape a template pipeline wants.**
`docs/plans/parts-data-v1.md:350-355` — *"33,158 lines under `scripts/character/parts/` became 171,
and 1,829,020 bytes of JSON now live under `assets/`"*. 101 parts (`parts-data-v1.md:149-151`),
eight frozen module hashes as the regression gate (`parts-data-v1.md:338-342`).
`docs/plans/character-v2.md:253-255` sized the generators at *"1,887 lines of Python"*; they are
2,912 today.

**Creatures: a plan and a tech plan, no status doc, nothing run.**
`docs/plans/creatures-v1.md:2-3` — the trio is **wolf / marmot / eagle**. The bite *"ships
disarmed"*, damage gated to zero (`creatures-v1.md:70-79`).
`docs/plans/creatures-v1-tech.md:474-482` holds the numbers still awaiting a ruling: pack size 2,
territory 150 m, sight 40 m / 110°, hearing 30 m, wolf walk 2.0 / run 7.5 m/s, bite damage 15
(disarmed). Live creatures capped at 16 (`creatures-v1-tech.md:334-347`); LimboAI would be *"the
project's first GDExtension"* (`creatures-v1.md:81-114`).

**Trees v3 is the run that paid for itself.** `docs/status/trees-v3.md:344-351` — the tool bakes 55
`.vox` sources into **38 distinct geometries** in 88 seconds, 2.7 MB, worst LOD0 variant **33,194
triangles** against a 40,000 gate (`trees-v3.md:518-534`). Deleting the block-tree system took the
column job from **242.476 ms to 39.030 ms (6.2x)** and the load wall from 24,872 to 19,322 ms
(`trees-v3.md:977-1011`), while the field went from 17,700 to **1,277,218** tree triangles — 72x
(`trees-v3.md:810-821`). Native heights land at **2.00 to 28.00 m, the trees proper at 21-28 m**
(`trees-v3.md:338-340`). Costs it names honestly: **93-95 draw calls** where there were seven,
~12 MB of resident library (`trees-v3.md:1258-1261`), the krummholz row mapped to six cut stumps
(*"The right SIZE and the wrong THING"*, `trees-v3.md:576-584`), and Trees 09 and 10 benched —
*"a fifth of the purchase sitting idle"* (`trees-v3.md:1404-1439`).

**Foliage v1 missed its boot budget and it is still the open cost.**
`docs/status/foliage-v1.md:191` — boot to idle **34.3 s → 60.3 s (+76%)** against a +10% budget,
MISSED. `docs/status/flora-streaming.md:56-63` later took grass re-streaming to **+0 ms** on every
jump, at a cost of 16,901 → 27,856 instances and 1.85 → 3.13 M triangles at spawn.
`foliage-v1.md:319-322` is the measurement behind the grain table: *"At 8 the large boulder was
35,964 triangles"*.

**UI v1 passed all eight of its acceptance rows** (`docs/status/ui-v1.md:558-566`). The sheet's own
dump reads *"6 sockets [...] | 5 skills ["Blades","Bows","Magic","Mobility","Gathering"]"*
(`docs/status/ui-v1.md:441-443`). Nineteen F9 tunables shipped with their starting values and none
was retuned (`docs/status/ui-v1.md:504-532`). Two things are marked TEMPORARY and owned by later
plans: the **H key** (host-side −10 hp, Combat v1 deletes it) and **the slab in hotbar slot 1**
(Items v1 deletes it) (`docs/status/ui-v1.md:652-660`).

**The UI has always been called Deco, and Art Nouveau appears in none of these documents.**
`docs/plans/ui-v1.md:41-45` — the poster register is *"Full Deco"*.
`docs/status/look-v1-ui.md:8-27` — the theme is *"Paper, ink, gold, alpine blue and sun, and no
sixth colour"*, with Limelight / Josefin Sans / Poiret One. D2 is a direction the repo has never
been pointed in, so §2.16 is a first pass rather than a correction.

---

## 2. Verdicts

Effort key: S = under a day, M = days, L = a week or more.

| § | System | Verdict | Effort | Bible rule it answers to |
|---|---|---|---|---|
| 2.1 | `races.gd`, the four-race table | **RIP** | L | D37 only humans |
| 2.2 | `parts_author/` + generated parts JSON | **RIP** | L | D1 bought templates as they are |
| 2.3 | `voxel_model.gd` grain, 24/block | **ADAPT** | S + M fallout | D1 15 voxels per cube |
| 2.4 | `rig.gd`, `animator.gd`, `locomotion_state.gd` | **ADAPT** | M | 40-characters.md rigs not changed |
| 2.5 | `purchased_view.gd` | **KEEP, promote** | S–M | D1, ASSETS-PLAN order of work |
| 2.6 | Character creation screen | **ADAPT** | M | D37, 40-characters.md colours |
| 2.7 | `armour.gd` + the five-tier ladder | **RIP the ladder** | M | D27 plate is the Engineers' |
| 2.8 | `skills.gd` + the magic design | **ADAPT** | S + M design | D23, D25, 30-magic-and-tech |
| 2.9 | `stats.gd`, survival | **KEEP**, delete `mp` | S | 00-TONE no frantic survival |
| 2.10 | Combat and death (design only) | **REDO design** | M | D39 restrained, remembered |
| 2.11 | Creatures (design only) | **REDO** | L | lore/20-peoples, 00-TONE forbids |
| 2.12 | Trees | **KEEP** | S | D21 real size, 0.125 m |
| 2.13 | Ground cover | **ADAPT** | S | 50-props 15/cube, sparse |
| 2.14 | `journal.gd` | **REDO** | M | director hardening rule 1 |
| 2.15 | `net_manager.gd` + mutation path | **KEEP** | S | one mutation path, host owns truth |
| 2.16 | UI ornament: deco.gd and friends | **REDO** | M | D2 nouveau on paper only |
| 2.17 | UI behaviour: HUD, compass, party, sheet | **KEEP** | S | 00-TONE no clutter |
| 2.18 | Camera | **KEEP** | S | pillar 3 monumental against tiny |
| 2.19 | Physics, push, bodies | **KEEP** | S | D40 warmth between the two |
| 2.20 | Galleries and probes | **KEEP** | S | 70-scale-metrics distance test |

### 2.1 `races.gd` — the four-race table — **RIP** (L to replace)

Bible rule: D37 *"Yes, only humans."* (`03-DECISIONS.md:243`), and
`style-bible/40-characters.md:23-25`: *"There are no other races. The elf and dwarf templates are
body types and stages of change within one people."*

The repo has `LIZARDFOLK = 3` (`races.gd:20`) with a 42-voxel tail, a 26-degree lean and a
digitigrade stance (`races.gd:186-194`), and `DESIGN.md:238` gives it a swimming perk. There is no
lizardfolk in the bible's world and no asset for one; the Perchten (`lore/20-peoples.md:19`) are the
animal-warrior packs, not a reptile race. This is a whole species to delete, not a rename.

Elf and dwarf survive *as words* but not *as this data*: the bible's dwarfs and elves are the bought
templates (48-55 and 59-65 voxels, `40-characters.md:11,10`), not procedurally generated 72- and
108-voxel bodies with per-race gait multipliers. `races.gd`'s honest core — one file owning every
per-race number, race never a stat (`races.gd:5-6`) — is a good idea worth keeping as a shape; its
contents are all wrong.

Also RIP by consequence: `tools/parts_author/lizardfolk.py` (309), the lizardfolk rows of
`hair.json` / `armour.json`, and `parts_hair.gd:28` (`lizard_crest_low`, `lizard_crest_tall`,
`lizard_frill`).

### 2.2 `parts_author/` + `parts_data.gd` + generated parts JSON — **RIP** (L)

Bible rule: D1 (`03-DECISIONS.md:17`) *"built on the bought templates as they are... reskinned
clothes only"*; `40-characters.md:3` *"their proportions, grain and rigs are not changed"*;
`40-characters.md:59` *"No re-proportioning of the templates."*

The generators exist to build bodies from scratch at 24 voxels per block. That is the thing the
bible says not to do. Keeping them means keeping two character pipelines, and
`ASSETS-PLAN.md:50` puts the reskin work in the *assets* repo as *"repaint scripts on the
viking/elf/dwarf templates, like `derived/knight/knight_template.py`"* — a different tool in a
different repo. 2,912 lines of Python and 32,897 lines of generated JSON (1.8 MB, of which 1.1 MB is
armour that the bible does not want either) go.

Cost evidence for the ripping, from the repo's own record: the grain has moved three times and each
move re-authored every part (`docs/status/look-v1-characters.md:16`,
`docs/plans/character-v2-tech.md:643-646`), and the parts already moved out of `scripts/` once —
*"33,158 lines… became 171"* (`docs/plans/parts-data-v1.md:350-355`). A fourth grain move to the
bible's 15/block would be a fourth re-author of a body set the bible does not want authored at all.

What survives from it, and it is worth naming: the **slot idea**. `voxel_model.gd:78-107` authors in
semantic slots so a palette swap is one array of colours. `vox_loader.gd:19-24` already implements
the bridge — *"a `.vox` whose palette indices 1 to 13 are reserved to mean the thirteen slots... is
loaded WITH `use_slots` and comes back as an ordinary slotted part."* That is exactly the hook a
reskin pipeline needs. Keep the concept and the loader; drop the generators.

### 2.3 `voxel_model.gd` grain (`VOXEL_M = 2.0/96.0`) — **ADAPT** (S for the constant, M for the fallout)

Bible rule: D1 — 15 character voxels per world cube, ~3.3 cm, player 59-69 voxels
(`03-DECISIONS.md:17`); `style-bible/70-scale-metrics.md:3` repeats it.

The constant is one line (`voxel_model.gd:76`). The fallout is not: `character_config.gd:25` bumps
its save path for exactly this reason (`character_tuning_v3.tres`, third grid change),
`animator.gd:42` derives the stride reference from it, `armour.py:47-57` authors thicknesses in
author voxels and scales at output, and the triangle budget was re-measured at each move
(6,000 → 24,000 → 48,000, `character_config.gd:30-31`). Going to a bought template removes most of
this: the template *is* the mesh, and its own voxel size is the grain. The right move is not to
retune 96 down to 60 — it is to stop generating bodies at all (2.2) and let the template's grain be
the answer.

### 2.4 `rig.gd` + `animator.gd` + `locomotion_state.gd` — **ADAPT** (M)

`rig.gd`'s choice of plain Node3Ds over a `Skeleton3D` (`rig.gd:5-20`) is right for rigid voxel
parts and stays right. `animator.gd` is 895 lines of clip-free procedural animation
(`animator.gd:4`) with a genuinely good property: distance-driven phase, so feet never slide at any
speed (`animator.gd:14-20`).

But the bible's templates ship **about 200 animation clips** (`40-characters.md:9`,
`ASSETS-PLAN.md:9`), and `40-characters.md:3` says the rigs are not changed. A game that buys 200
clips and then poses the body with arithmetic is paying twice and getting the worse half:
`purchased_view.gd:16-18` already records the exact failure mode — *"Distance sync is approximate
(clips are time-based, our Animator is distance-based); that mismatch is one of the things this demo
exists to let Marcel judge."*

`LocomotionState` is the piece that makes the swap cheap and it should be the thing that survives:
*"THIS STRUCT IS THE SEAM"* (`locomotion_state.gd:6-12`) — the animator never reads Input, never
reads a CharacterBody3D, never learns which of local/remote/host is driving it. Keep the seam, keep
`rig.gd` for whatever stays rigid (props on sockets), and let clips drive the body.

Verdict detail: `locomotion_state.gd` KEEP (S), `rig.gd` ADAPT (S), `animator.gd` ADAPT — most of it
becomes a clip selector plus the good bits (head-look, blink, idle breaks) as additive layers (M).

### 2.5 `purchased_view.gd` — **KEEP and promote** (S to promote, M to make it the only path)

Bible rule: D1, `40-characters.md:5-17`, `ASSETS-PLAN.md:70-73`.

This 127-line file is the only thing in the character area that does what the bible says. It loads
the viking glTF, normalises height, grounds the feet, fixes the +Z/-Z facing
(`purchased_view.gd:45-68`) and drives the pack's clips from `LocomotionState`
(`purchased_view.gd:73-90`). It is currently opt-in and self-described as scaffolding
(`purchased_view.gd:6-12,33-36`). Under the bible it is the pipeline. Promote it, drop the flag,
and let `CharacterView` own it rather than side-load it.

Two known gaps it names honestly: clip speed guessing (`purchased_view.gd:22-25`, three hardcoded
speeds) and the time-vs-distance sync (`purchased_view.gd:16-18`).

### 2.6 Character creation screen — **ADAPT** (M)

Bible rule: D37 (one people), `40-characters.md:29` *"Identity comes from hat, hair block, cloak and
colour, not from the face"*, `40-characters.md:43` *"Base colours are dark... Gold #c9a24a is the
only trim."*

`character_creation.gd:5-7` — *"NO SLIDERS. NO STATS."* — is exactly right and matches the bible's
temperament. What has to change is the content: the race row becomes a **body-type** row (viking /
dwarf-stocky / elf-changed, all one people), lizardfolk goes, and the palette rows narrow to the
bible's dark bases plus gold trim rather than five free skin ramps per race
(`races.gd:212-217`). The screen's machinery — a table-driven row loop, rebuild-on-every-click —
survives untouched.

### 2.7 `armour.gd` + `armour.py` + the five-tier ladder — **RIP the ladder, KEEP the fitting idea** (M)

Bible rule: D27 (`03-DECISIONS.md:191-194`) *"Mountain folk in leather, fur, wool, felt, mail, wood
and horn; plate is the Engineers' guard"*; `40-characters.md:37-38`; `lore/20-peoples.md:8`
*"No plate."*

The repo's ladder is `none → cloth → hide → mail → plate → named` (`armour.gd:51-58`) — a
progression ladder every character climbs regardless of who they are. Under D27 plate is not tier 4
of anything; it is **a faction's uniform**. A mountain-folk player who reaches "tier 4" and puts on
plate has just changed sides by accident. That is a design collision, not a numbers collision.

Tier 5 `named` is worse against the bible: it adds *"a cloak and one vertical element above the
head"* plus a glowing rune band (`armour.gd:121-122,142-144`, `races.gd:322-327` `GLOW_HEX
#8FD8FF`). `lore/30-magic-and-tech.md:30` — *"Nobody throws lightning"*, magic is
weather-reading and wards — and `50-props-and-tech.md:41` puts glow on crystals in ruins and
dungeons only. A glowing shoulder on a player is loot-game vocabulary the bible does not have.

What is genuinely good and should be carried forward as a *rule*, not as this code: **"proportions
relative, thicknesses absolute"** (`armour.gd:26-38`, `armour.py:3-18`) and **"a tier is a count of
outline events, not surface decoration"** (`armour.gd:13-23`). The second is the same instinct as
the bible's own 100 m distance test (`70-scale-metrics.md:50-52`) and the ornament budget (D9). Keep
the sentences; delete the 20,873-line `armour.json` and the six-slot ladder.

Six slots on the wire (`character_def.gd:49-58`) can stay — clothes have to hang somewhere.

Worth knowing before defending it: the ladder **never passed its own gate**.
`docs/status/character-v2.md:1387-1388` records it as NOT PASSED, 6 of 24 rows off, and
`:1428-1443` ranks the fix as still-outstanding work together with *"the helms read as caps and the
gorget as a tray"*. The thing being kept for sunk cost is a system that does not yet do what it was
built to do, in a shape the bible does not want.

### 2.8 `skills.gd` and DESIGN.md's skill design — **ADAPT** (S for the file, M for the design)

Bible rules: D23 magic is altitude (`03-DECISIONS.md:171-174`), D25 no crystal-powered tech
(`03-DECISIONS.md:181-184`), `lore/30-magic-and-tech.md:30` *"Mountain-folk magic is small and
practical: weather-reading, wards, calling and calming beasts, horns that carry across a valley,
masks... Nobody throws lightning."*

`skills.gd:17` lists `Blades, Bows, Magic, Mobility, Gathering`. Four of those five are fine.
"Magic" as a combat skill is not: `DESIGN.md:289-297` spends it on **Fire bolt** and **Frost bolt**,
*"one player slows, the other finishes"*. That is a spell-slinging game; the bible's magic is
environmental and non-combat, and belongs to the Builders and the far islands
(`lore/30-magic-and-tech.md:30`). The `mp` bar in `stats.gd:34-38` is the same decision one layer
down.

The file itself is 26 lines and read-only by design (`skills.gd:11-14`), so the cost is in the
design, not the code. Rename or re-scope the fifth skill; drop the elemental bolts.

### 2.9 `stats.gd` (hp/sp/mp) and survival — **KEEP with one deletion** (S)

Tone rule: *"Frantic survival: timers, hunger bars that scream, constant alarms"* is forbidden
(`00-TONE.md:51`).

The repo passes cleanly. There is **no hunger, thirst, temperature or fatigue anywhere** in
`stats.gd` or in `DESIGN.md` (verified by grep across DESIGN.md; the only "hunger" is a creature
utility-AI score at `DESIGN.md:796`). Three stats, all 100, nothing drains any of them
(`stats.gd:11-15,34-38`). One mutation seam that journals with a cause (`stats.gd:85-111`) is the
right shape for the director. Health hitting 0 does nothing, on purpose (`stats.gd:22-26`).

The deletion is `mp`: see 2.8. Everything else stays. Note `stats.gd:32-33` already anticipates
*"a racial health bonus"* — under D37 there are no races to bonus, so that line should go with the
race table.

### 2.10 Combat and death (design only, no code) — **REDO the design** (M, design work)

Bible rule: D39 (`03-DECISIONS.md:250-253`) and `00-TONE.md:53` — *"Graphic violence: blood, gore,
dismemberment... Combat is restrained; death is quiet and remembered."*

`DESIGN.md:831-837` — *"Light attack, dodge / block"*, sword/bow/staff, *"Tuned for 2, must not go
trivial at 4"* — is not against the bible; it is simply silent about tone. `DESIGN.md:839-844` is
closer to the bible than it looks: revive by a teammate, respawn at the last campfire, *"Costs time,
not progress"*, and while dead the camera follows a living teammate. That last line is almost a
tone statement (D40's *"warmth between the two"*).

What is missing rather than wrong: nothing in the design says death is **remembered**. D39 requires
it, and the mechanism already exists — `stats.gd:85-111` journals every change with a cause.
Nothing is built yet (`DESIGN.md:674`), so this is cheap to get right before it is written.

### 2.11 Creatures — **REDO** (L, and nothing to rip)

Bible rules: `lore/20-peoples.md:12,19` — wolves and bears; *"The Perchten... masked, horned, part
beast... the animal-warrior assets are them"*; `40-characters.md:53` — *"Wolves, bears, deer, foxes,
rabbits and boars in the alpine default"*. Tone forbids: *"Cute, zany, comic relief, mascots"*
(`00-TONE.md:47`) and *"Horror dressing: tentacle gods, madness meters, cults, jump scares"*
(`00-TONE.md:54`).

Nothing is built (`DESIGN.md:674-675`) and there is no status doc for `creatures-v1` — only a design
plan and a tech plan (`docs/plans/creatures-v1.md`, 134 lines; `creatures-v1-tech.md`, 491). So
there is nothing to rip, and the cheapest moment to correct it is now, before
`creatures-v1-tech.md:474-482`'s open numbers (pack size 2, territory 150 m, sight 40 m / 110°,
bite damage 15, disarmed) are ruled on. The design, however, has three items that fail the bible as
written:

1. **Invented fauna.** `DESIGN.md:679-683` proposes *"scree-worm (Tatzelwurm energy), frost-folk,
   storm-beings"*. The bible's non-human threats are **changed people** (the Perchten) and
   **changed beasts** — `lore/30-magic-and-tech.md:24`: *"wolves are wolves in ring 1 and something
   else in ring 4."* Same silhouette, further along. That is a better and cheaper answer, and it is
   the decided one.
2. **Cute.** `DESIGN.md:713-719` makes *"Small cute ambient creatures - marmot-tier"* untargetable,
   and `DESIGN.md:824-829` puts the marmot in the first playtest trio. `00-TONE.md:47` forbids cute.
   A marmot as *information* (the whistle as a danger radar, `DESIGN.md:684-689`) is a fine mechanic;
   as charm it is out.
3. **Megafauna as awe.** `DESIGN.md:721-726` — *"a few RARE giant creatures as awe encounters, in
   the Pilatus-dragon register: near-sacred, witnessed more than fought."* This one is **more**
   bible than the bible: it is `00-TONE.md:41` cosmic dread at the edges, exactly. Keep it.

The behaviour tech stance (`DESIGN.md:779-822` — LimboAI, AStarGrid2D over the coarse heightmap,
boids, utility AI, no learning agents) is engine work and survives the bible unchanged. The seam
rule at `DESIGN.md:818-822` — *"the director may `mark_site` a carcass as interesting; the wolves'
tree decides what to do about it"* — matches `director/10-verbs.md:17` exactly.

Also note the art is already bought and mounted (§1.5) and the bible's grain warning applies:
`40-characters.md:13` says the forest pack is *much finer* than the characters (the bear is 533,000
voxels) and `70-scale-metrics.md:34` says the bear ships at 1.6 players and must come down to ~0.7
at the shoulder.

### 2.12 Trees — **KEEP** (S to re-check against the bible's library rules)

Bible rule: D21 (`03-DECISIONS.md:147-151`) *"Real size. Trees stay 9-28 m... tree voxels (0.125 m)
stay coarser than character voxels"*; `style-bible/20-world-and-terrain.md:14` *"real-size trees,
9 to 28 m (18 to 56 cubes)... 27 green variants in the tree library"*; `80-do-dont.md:22`
*"the purchased tree library at real size"*.

The repo already does this, to the number. `tree_models.gd:47-53` — `VOXELS_PER_BLOCK := 4`, 12.5 cm,
asserted against every sidecar at load. `tree_table.gd:24-31` — heights are the artist's, native,
*"The library lands at 21-28 m"*. `tree_field.gd:20-25` — geometry all the way out, no impostor
cards, the far register is the same grid downsampled. This is the single best bible-alignment in the
repo and it was reached independently.

The status doc quantifies it: **38 distinct geometries from 55 `.vox` sources in 88 seconds**, worst
LOD0 variant **33,194 triangles** against a 40,000 gate, native heights **2.00 to 28.00 m** with the
trees proper at 21-28 m, and the whole column job **6.2x faster** after the block trees were deleted
(`docs/status/trees-v3.md:344-351,518-534,338-340,977-1011`). The bill it also names: **93-95 draw
calls** where there were seven, and 1,277,218 tree triangles where there were 17,700
(`trees-v3.md:810-821`). That is the price of D21 and D41 together, and it is worth paying.

Two things to check rather than change: the bible expects a full library
(`ASSETS-PLAN.md:17` — 55 `.vox`), and `STATUS.md:36-43` records that **Trees 09 and 10 are benched**
because `vox_parse.py` dropped MagicaVoxel rotations (the coconut palm came out as *"a stick with a
plate balanced on it"*). `ASSETS-PLAN.md:33` separately says the library has no palms and they must
be bought for ring 3 — so the benched palms may not matter yet. Second: `tree_table.gd:59-64` parks
the crimson and pink colourways at weight 0, which is exactly the parking space
`20-world-and-terrain.md:37` wants for the wild-colour region. Third, one row is honestly bad and the status doc says so: krummholz is
mapped to Tree 16, *"six CUT STUMPS: dead wood, sawn flat, 2 m tall. The right SIZE and the wrong
THING"* (`docs/status/trees-v3.md:576-584`). `20-world-and-terrain.md:15` puts scattered small trees
at the tree line, which is where krummholz lives, so this row needs a real model rather than a
table edit.

### 2.13 Ground cover (`flora_models.gd`, `flora_placement.gd`) — **ADAPT** (S)

Bible rule: `50-props-and-tech.md:3` — *"Props are fine voxels at the character grain (about 3.3 cm,
15 per world cube)"*; `20-world-and-terrain.md:48` — *"Sparse. Grass is single tufts. Rocks are a
few big ones, not gravel. If a scene needs more, add fog, not objects."*

The grain is off by a factor: `flora_models.gd:34-35` uses 8 voxels per block = 6.25 cm for plants,
with boulders at 2 and shrubs at 4 (`flora_models.gd:56-62`). The bible wants 15/block for props.
The *reasoning* in the file is sound (`flora_models.gd:38-55` — a 3 m boulder at 8/block cost 35,964
triangles), and the bible's own answer is the same one: a boulder is terrain, not a prop. The fix is
a table edit, not a rewrite. The decoration-layer architecture (`flora_models.gd:6-18` — never enters
a chunk, never enters the mesher, MultiMesh per column) is right and stays.

One open cost belongs here rather than to the world team: `docs/status/foliage-v1.md:191` records
boot to idle going **34.3 s → 60.3 s (+76%)** against a +10% budget — MISSED — when ground cover
landed. `docs/status/flora-streaming.md:56-63` fixed the *re*-streaming (grass costs +0 ms on a
jump now) but not the first load. The bible's *"Sparse… If a scene needs more, add fog, not
objects"* (`20-world-and-terrain.md:48`) is the cheapest fix available and is also the correct one.

`ASSETS-PLAN.md:25` says a 65-model Plants Pack is a **buy now** item, so `flora_models.gd`'s
generated plants may become a loader like `tree_models.gd` rather than a generator. Same shape, and
`tree_models.gd:9-21` already explains why it should be a sibling rather than a tenant.

### 2.14 `journal.gd` — **REDO** (M)

Bible rule: `director/00-principles.md:18`, hardening rule 1 — *"**Facts by ID.** A deterministic
chronicler turns the raw event log into typed facts with IDs. Every verb references IDs, never free
text about the world."* Plus `director/20-world-digest.md:17-28` (salience) and D34
(`03-DECISIONS.md:225-228`).

`journal.gd` is 47 lines and stores untyped dictionaries with a `kind` string and a millisecond
stamp (`journal.gd:32-39`). It says so on purpose: *"there is no schema on purpose, because
inventing one before the second consumer exists is how tables become prose"* (`journal.gd:30-31`).
That was a defensible call before the bible existed. The bible **is** the second consumer, and it
asks for the opposite thing: typed facts, stable IDs, and a deterministic chronicler between the raw
log and the model.

What is missing, concretely:
- No fact IDs. A verb like `place_fragment(site_id, fact_ids[])` (`director/10-verbs.md:7`) has
  nothing to reference.
- No chronicler. `director/20-world-digest.md:11` wants facts *"Typed, ID'd, ranked by salience,
  capped (forty lines is the starting guess)"*.
- No salience. `20-world-digest.md:19-28` lists first sights, deaths, repeats, quest proximity,
  campfires, rare kills, silhouette-changing edits — none of which the log distinguishes today.
- No persistence: *"No file, no rotation, no cap"* (`journal.gd:21-24`). A director reading a journey
  needs the journey to outlive the process.

The **habit** is correct and already wired in at the right places: `world.gd:1778-1783` journals inside
`_host_apply_edit` after the validate gate and after the no-op gate, with the sender in hand; and
`stats.gd:96-111` journals with a cause and suppresses no-op regen ticks. Keep the call sites; redo
the store.

### 2.15 `net_manager.gd` + the mutation path — **KEEP** (S)

Bible rule: *"the host owns all truth, one mutation path, the director is one more client of it"* —
`director/00-principles.md:7,10` and hardening rule via D34; `director/10-verbs.md:3` *"All verbs
are proposals to the host; the host validates and applies, or rejects."*

The repo already is this. `world.gd:1667-1681` draws the single path; `world.gd:1709-1737` implements
it; `world.gd:1727` uses `get_remote_sender_id()` because *"a client cannot forge it"*;
`world.gd:1678-1681` — *"Clients never write to their own chunks, not even optimistically."*
`net_manager.gd:12-13,93-97` makes solo a host with no socket, so there is no second code path to
rot. `player_sim.gd:7-12` and `locomotion.gd:6-19` complete it: clients send input, the host
simulates, one implementation of the step on both sides.

The director slots in as one more caller of `request_set_block()`-shaped functions, which is
precisely what `world.gd:1890-1899` sketches for a future `_srv_request_gather`. Nothing here needs
to change for the bible. `net_transport.gd:11-14` is right to keep RPCs out of the transport seam.

One gap, named by the repo itself: no rollback on the client (`player.gd:16-20`,
`DESIGN.md:946-952` — under 0.25 m nothing, up to 2 m ease over 100 ms, over 2 m snap). That is a
quality issue, not a bible conflict.

### 2.16 UI visual language: `deco.gd`, `deco_panel.gd`, `deco_rule.gd`, `poster_backdrop.gd`, `deco_theme.tres` — **REDO** (M)

Bible rule: **D2** (`03-DECISIONS.md:27`) *"B - on paper only: UI, cards, map, portraits"*, where B
is *"Deco in the 3D world, nouveau only on paper"* (`03-DECISIONS.md:24`).
`style-bible/60-ui-and-2d.md:3` — *"Art Nouveau lives here and nowhere else."*
`60-ui-and-2d.md:27` — **"No deco geometry cut into the paper; the paper is nouveau, the world is
deco."** `80-do-dont.md:26` repeats it as a don't: *"deco geometry on paper"*.

The repo's UI is Art **Deco** on paper, comprehensively and deliberately:
- `deco_panel.gd:5-7` — *"A poster's panel does not have one rounded corner - it steps in, the way
  the crown of a building steps in, and the step is the ornament."* That is the bible's *building*
  ornament, on paper.
- `poster_backdrop.gd:46-48` — *"a Deco mountain is a ziggurat, not a cone"*, three stepped ranges.
- `deco.gd:83-89` — chevrons; `deco.gd:92-100` — a double-gold-ring roundel; `deco_rule.gd:4-11` —
  a rule with square terminals.
- `assets/ui/deco_theme.tres` header — *"CHAMFERED CORNERS, NOT NOTCHED... corner_detail = 1 turns
  its rounded corner into a single straight cut - an octagon - which is the Deco profile"*.

Every one of those is straight-line stepped geometry, which is the language D2 assigns to the 3D
world and forbids on paper. This is a full visual redo: curved and floral frames, tarot-format
cards (`60-ui-and-2d.md:9-11`), the halo portrait style, line-ridge maps (`60-ui-and-2d.md:13-15`).

Palette, item by item against `60-ui-and-2d.md:7`:

| Bible | Repo | Verdict |
|---|---|---|
| paper cream `#f3e1c6` | PAPER `#F2E8D0` (`deco.gd:17`) | close; retune |
| frame line gold-brown `#917b5c`, thin | GOLD `#C9A24A` (`deco.gd:20`) | wrong role — repo gold is the rule line and accent |
| sage `#6b7463` accent | — | missing |
| dusty pink `#cb9b6e` accent | — | missing |
| *"Low contrast, no black"* | INK `#1E2430` (`deco.gd:19`), used as full-width title bands (`poster_backdrop.gd:151`) and a 94%-opaque ground (`hud.gd:53-55`) | **direct conflict** |
| — | ALPINE `#2F5D8A` (`deco.gd:21`) | not in the bible's paper palette |

Note `#C9A24A` is exactly the bible's gold `#c9a24a` (`40-characters.md:43`) — which is the
*world's* trim colour, not paper's frame colour. The repo picked the right hex for the wrong
surface.

Fonts (`assets/fonts/`, used via `deco_theme.tres`): `60-ui-and-2d.md:19` wants *"Titles: a
geometric deco sans... Body text: a plain serif on cream paper. Never a curly script."*
**Josefin Sans** is a geometric deco sans and satisfies the title rule. **Limelight** is a Deco
display face — allowed for titles, arguably. **Poiret One** is a thin Deco display face used for
subtitles, and there is **no serif in the repo at all**, so the body rule is unmet. One font to buy
or find (OFL serif), one to drop.

### 2.17 UI behaviour: `hud.gd`, `compass.gd`, `party_icons.gd`, `hotbar.gd`, `character_screen.gd` — **KEEP** (S)

Tone rule: *"Clutter: crowded villages, busy interiors, noisy UI, a screen full of markers"* is
forbidden (`00-TONE.md:50`).

The repo's UI *behaviour* is one of the strongest bible alignments in the codebase, and it was
reached before the bible existed:
- `hud.gd:4` — *"one furniture cluster at the bottom centre, one thin strip at the top, four empty
  corners - and when you are safe, nothing at all."*
- `hud.gd:12-15` — *"Cozy does not look like a warm-coloured HUD; it looks like a clean screen with
  a huge world behind it."*
- `compass.gd:4-7` — *"There is no minimap in this game and there is no setting that turns one on."*
- `compass.gd:14-17` — *"a map tells you where everything is, and this game's whole progression is
  that you do not know yet."* That is `00-TONE.md:36` (*"Mystery kept"*) restated as a UI rule.
- `party_icons.gd:10-14` — a friend's health appears only when they are in trouble; *"A permanent
  health bar per friend would be a party frame, which is the MMO posture this design explicitly is
  not."*
- `character_screen.gd:6-10` — read-only sheet; *"the moment a sheet lets you spend something, it has
  become the skill tree this design rejected."*

Keep all of it. Only what these draw with changes (2.16), not when or whether they draw.
`hotbar.gd:29-35` needs its five slots refilled once placeables exist (campfire, torch, marker —
`DESIGN.md:848-849`), which is compatible with the bible's props (`50-props-and-tech.md:21-27`).

### 2.18 Camera — **KEEP** (S)

Bible rule: pillar 3 (`style-bible/00-pillars.md:11-12`) *"Monumental against tiny... The player is
small in front of what matters"*; D41 view distance (`03-DECISIONS.md:260-265`);
`70-scale-metrics.md:54-64` (the horizon test).

`player.gd:7-10` — *"THIRD PERSON ONLY. Not a preference - the design is sold on reading landscape
at a glance, and an over-the-shoulder or first-person framing hides exactly the thing worth looking
at."* `DESIGN.md:436-441` — Cube World orbit, mid-distance, collides with terrain. This is the
correct camera for monumental-against-tiny and the reasoning is already the bible's reasoning.

Two notes rather than objections. First, `player.gd:514-520` sets the camera far plane from
`config.fog_end_m * FAR_PLANE_RATIO` — under D41 that number has to grow to kilometres, and
`03-DECISIONS.md:265` flags the coordinate problem past ~10 km. That is the world team's item, not
this one, but the camera is where it lands. Second, the bible has no FOV; `animator.gd:66` records
that the game runs at 75 degrees. See D45 in section 3.

### 2.19 Physics, push, bodies — **KEEP** (S)

Nothing in the bible contradicts it and one thing endorses it. `push.gd:14-18` — a `boulder_l` that
one player cannot move *"shifts an inch and settles back"* and says *"not on your own"* without a
line of UI. That is `00-TONE.md:43` (warmth between the two) expressed as physics, and
`DESIGN.md:894-908` gives the numbers (600 N per player, hold 400/1000 N, a three-degree rock).
`world_body.gd:5-11` and `push.gd:20-23` keep the host-authoritative rule intact.

`DESIGN.md:861-871` — *"Breaking terrain is decided: no, in v1"* — is compatible with the bible's
sparse, authored world.

### 2.20 Tools and self-tests in scope — **KEEP** (S)

`character_gallery.gd` (2,036) is a real asset regardless of what the character pipeline becomes: it
photographs subjects under frozen light on a flat pad so that *"the ONLY thing that differs between
two runs is the character"* (`character_gallery.gd:10-17`). It already has the **campfire sheet**
(`character_gallery.gd:1030-1061`) — seated characters at dusk t=0.78, framed from the row's own
span — which is very nearly the ROUND-3 shot. `model_gallery.gd:6-20` is the same instrument for
trees and plants and its `--stand` mode (*"a dozen at the spacing the world actually plants them
at"*) is the tool for judging D21 in the engine. `ui_shot.gd:7-9` photographs menus.

Cost note: `selftest_character.gd` is 2,411 lines and most of it tests the generated-parts pipeline
(height from the built rig, part-vs-table agreement, gear-socket clearance on four races,
eight frozen part-file hashes). When 2.2 goes, most of that goes with it — which is a saving, not a
loss, but it should be counted honestly: the character area's test surface shrinks by roughly 2,000
lines and has to be rebuilt against templates.

`selftest.gd` (3,595) is worldgen and mesher and is untouched by this audit's scope.

---

## 3. Places the code decided something the bible is silent on

Candidate decisions, numbered from **D43** (D42 is the engine decision, taken 2026-09-02). One line
each, with the code's current answer.

- **D43 — Third person only, no first-person mode, ever.** Code: yes, and stated as permanent
  (`player.gd:7-10`, `DESIGN.md:436`).
- **D44 — Camera orbit distance and collision.** Code: Cube World mid-distance orbit on a
  `SpringArm3D` that collides with terrain rather than clipping (`DESIGN.md:438-441`,
  `scenes/player.tscn` `CamPivot/SpringArm3D/Camera3D`).
- **D45 — Field of view.** Code: 75 degrees (`voxel_model.gd:66-72` reasons from it; it is the
  number the whole voxel-vs-pixel argument rests on). The bible's 100 m distance test
  (`70-scale-metrics.md:52`) has no FOV attached, so the test is currently unanchored.
- **D46 — Player walk and sprint speed.** Code: walk 5 m/s, sprint 2.6x = 13 m/s, set by traversal
  not realism (`player.gd:26-38`, `DESIGN.md:663-670`). The tone says *"Slowness... Nothing rushes
  the player"* (`00-TONE.md:34`); 47 km/h next to a 2 m character is a live tension the repo names
  itself (`player.gd:32-37`).
- **D47 — North is -Z.** Code: yes, chosen so the sun rises in the east (`compass.gd:19-34`).
- **D48 — No minimap, and no option to turn one on.** Code: a compass strip only
  (`compass.gd:4-7`).
- **D49 — The HUD disappears when the player is safe.** Code: yes, a four-condition fade
  (`hud.gd:12-15,59-65`).
- **D50 — Party UI shows a friend's health only when they are hurt.** Code: yes
  (`party_icons.gd:10-14`).
- **D51 — The character sheet is read-only forever.** Code: yes, as a design rule
  (`character_screen.gd:6-10`, `skills.gd:11-14`).
- **D52 — Five hotbar slots, and players never place raw voxel blocks.** Code: yes
  (`hotbar.gd:4-14`, `DESIGN.md:848-853`).
- **D53 — Skill list and progression shape.** Code: five skills, skill-by-use, no decay, ~+25% total
  by level 10, a chunky unlock every five levels (`skills.gd:17`, `DESIGN.md:274-283`).
- **D54 — Three stats: health, stamina, mana, all 100, none draining yet.** Code: yes
  (`stats.gd:34-43`).
- **D55 — Death: revive by a teammate, respawn at the last campfire, costs time not progress; the
  camera follows a living teammate while dead.** Code: designed, unbuilt (`DESIGN.md:839-844`).
- **D56 — Four players maximum, balanced around two; solo is a dev convenience.** Code: yes
  (`net_manager.gd:30`, `DESIGN.md:956-957`).
- **D57 — The character lives in the world on the host; a character cannot leave the world it was
  made in.** Code: yes, Valheim's split explicitly rejected (`DESIGN.md:420-432`).
- **D58 — Client prediction with no rollback; correction thresholds 0.25 m / 2 m / 100 ms.** Code:
  yes (`DESIGN.md:946-952`, `player.gd:16-20`).
- **D59 — Terrain cannot be broken and there is no digging in v1.** Code: yes
  (`DESIGN.md:861-871`).
- **D60 — Two boulder weights and a co-op push rule (600 N each, hold 400/1000 N).** Code: yes
  (`body_table.gd:24-30`, `DESIGN.md:875-908`).
- **D61 — Ground cover voxel grain: 8 per block for plants, 4 for shrubs, 2 for boulders.** Code:
  yes (`flora_models.gd:34-62`); the bible says props are 15 per block
  (`50-props-and-tech.md:3`), so this is a conflict the bible has not noticed rather than a silence.
- **D62 — Tree LOD bands: LOD0 to 154 m, LOD1 to 400 m, LOD2 beyond.** Code: yes
  (`STATUS.md:22-23`). D41 asks for 10 km; nobody has said what the third band does at that range.
- **D63 — The public build ships with no trees and there is no fallback tree system.** Code: yes, by
  design, CI proves it (`tree_models.gd:24-30`).
- **D64 — Trees 09 and 10 (the coconut palms) are benched.** Code: yes, a `vox_parse.py` rotation
  bug (`STATUS.md:36-43`).
- **D65 — The forest colours are the repo's, not the pack's.** Code: yes — *"THE ARTIST DECIDES
  WHERE THE CUBES GO. KUBIK DECIDES WHAT COLOUR THEY ARE"* (`tree_palette.gd:6-16`). This is a good
  rule and the bible should adopt it explicitly for every bought pack.
- **D66 — A fixed dark liner voxel between skin and cloth on every character.** Code: yes,
  `#14100C`, never a player pick (`races.gd:63-79`). Survives a template pipeline as a *reskin*
  rule and is worth deciding on purpose.
- **D67 — Every character spans four value tiers (liner / deep / mid / light / accent) with one
  light element that stays visible at dusk.** Code: yes (`races.gd:81-102`).
- **D68 — Armour tiers are a count of outline events, not surface decoration.** Code: yes, and
  measured by a gallery sheet (`armour.gd:13-23`, `DESIGN.md:316-322`).
- **D69 — The character voxel grain and the world block grain are separate systems that meet only in
  the material.** Code: yes (`DESIGN.md:351-357`). The bible agrees in spirit (D1's three grains)
  but has never said the meshers are separate.
- **D70 — Cardinal/creature AI stack: LimboAI for behaviour trees, `AStarGrid2D` over the coarse
  heightmap for ground pathing, boids for flocks, utility AI for animals, GOAP for NPCs, no learning
  agents.** Code: designed, unbuilt (`DESIGN.md:791-798`).
- **D71 — Danger is four dials (altitude, distance from spawn, slope, time of day) and never a
  painted zone.** Code: designed (`DESIGN.md:691-704`). This is close to D35's rings
  (`03-DECISIONS.md:230-233`) and the two should be reconciled deliberately.
- **D72 — Small ambient creatures cannot be targeted at all.** Code: designed
  (`DESIGN.md:713-719`).
- **D73 — Magic is two elements, fire bolt and frost bolt, as co-op glue.** Code: designed
  (`DESIGN.md:289-297`). This one is not a silence: it conflicts with
  `lore/30-magic-and-tech.md:30`. Listed here because the bible never says what a *player's* magic
  verb is, only what magic *is*.
- **D74 — Mounts exist, at v0.3+, for speed and flavour.** Code: designed
  (`DESIGN.md:937-939`). The bible has zeppelins (D24) and cog rails but no mounts.
- **D75 — The director runs host-side on the host's API key and is off by default in strangers'
  builds.** Code: designed (`DIRECTOR.md:60-61`). The bible's `director/` folder never says whose
  key pays.
- **D76 — Creature pack size, senses and speeds.** Code: proposed and explicitly awaiting a ruling —
  pack size 2, territory 150 m, sight 40 m / 110°, hearing 30 m, wolf walk 2.0 / run 7.5 m/s against
  a 4.4 m/s player walk, bite damage 15 shipped disarmed
  (`docs/plans/creatures-v1-tech.md:474-482`). Live creatures capped at 16
  (`creatures-v1-tech.md:334-347`).
- **D77 — Every creature has an address: the den, not the spawner.** Code: designed
  (`docs/plans/creatures-v1.md:116-134`). This is compatible with the bible's rings (D35) and worth
  deciding on purpose, because it is what makes a wolf pack a *place* rather than a spawn table.
- **D78 — Season is a weight bias on the tree table, not a tint, and snow is altitude with no
  knob.** Code: yes, `tree_season` is a hashed world property
  (`docs/status/trees-v3.md:1101-1105`). The bible has an autumn *region*
  (`20-world-and-terrain.md:36`), not a season, and the two are different games.
- **D79 — The bought pack's palette is discarded and the repo re-colours every variant through 16
  named families.** Code: yes (`tree_palette.gd:6-16`, `docs/status/trees-v3.md:411-431`). Should
  become a general rule for every bought pack, characters included — it is exactly how a reskin
  pipeline under D1 would work.

---

## 4. Recommendation

*(under 200 words)*

**Foundation, keep as is:** the trees pipeline (`tree_models.gd:47-53` already builds D21 to the
number), the host-authoritative mutation path (`world.gd:1667-1737`), `locomotion.gd`'s one shared
step, the physics push, the camera, and the UI's *behaviour* — no minimap, a HUD that vanishes when
safe, a read-only sheet. The galleries and probes are instruments worth their lines.

**Throwaway:** the generated-body pipeline. `parts_author/` (2,912 lines Python), 32,897 lines of
parts JSON, `races.gd`'s four-race table, and the plate-topped armour ladder are answers to a
question the bible no longer asks. `journal.gd` and the whole UI ornament layer are redos, not
edits.

**Shortest path to two viking-template players at a campfire (ROUND-3-BRIEF.md:11):**
1. Promote `purchased_view.gd` from `--viking` opt-in to the path `CharacterView` takes (it already
   loads, scales, grounds and drives the glTF).
2. Feed `LocomotionState.POSE_SIT` — already player-toggled on KEY_X at `player.gd:478-480` — into
   a clip pick.
3. Reuse the gallery's campfire sheet (`character_gallery.gd:1030-1061`) as the shot.

Nothing above needs `races.gd`, `parts_author/`, or `armour.json` to exist.
