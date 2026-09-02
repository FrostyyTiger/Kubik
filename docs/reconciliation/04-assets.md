# Assets audit — Kubik-assets and the game's consumption of it, against the bible

Date: 2026-09-03. Read-only audit. Nothing in `Kubik-bible`, `Kubik` or
`Kubik-assets` was modified.

Test applied to every item: *would you build it this way today, for the bible?*

Bible read: `03-DECISIONS.md` (D1, D9, D17, D19, D21, D24, D27, D37–D43),
`ASSETS-PLAN.md`, `ROUND-3-BRIEF.md`, `00-TONE.md`, `style-bible/00-pillars.md`,
`10-color-and-light.md`, `20-world-and-terrain.md`, `30-architecture.md`,
`35-interiors.md`, `40-characters.md`, `50-props-and-tech.md`,
`60-ui-and-2d.md`, `70-scale-metrics.md`, `80-do-dont.md`.

**D43 landed mid-audit** (bible commits `0c11571` and `0aba9df`, 2026-09-03).
Generated buildings move from the world grain to **the tree grain: 0.125 m,
4 voxels per world cube, baked with the trees' three LOD rungs**. §3.4 below is
written against D43, not against the superseded "one voxel per world cube"
wording. The same commits corrected `70-scale-metrics.md`'s stale "6 heads"
player row to "about 3 heads", so that contradiction with `40-characters.md` is
already closed and is not reported here.

All voxel dimensions below were **measured**, not quoted: every `.vox` in
`Kubik-assets/game/` was parsed with the repo's own
`derived/knight/vox_parse.py` and its bounding box, voxel count and colour
count printed. Clip counts were counted from the glTF JSON.

---

## 1. Inventory

### 1.1 The eight purchased packs (`Kubik-assets/packs/`)

| Pack | On disk | Files | What is in it | Measured |
|---|---|---|---|---|
| `voxel-viking-characters` | 438 MB | 338 (5 vox, 5 gltf, 5 dae, 322 png, 1 unitypackage) | 5 rigged templates: Female_A1, Male_A1, Male_B1, Male_B3, Male_D1 | **57–63 voxels tall**, 23–29 colours, 39–112 vox parts. `male_a1.gltf` carries **199 clips** |
| `voxel-dwarf-characters` | 558 MB | 341 (10 vox, 10 gltf, 10 glb, 10 dae, 300 png, 1 unitypackage) | 10 rigged dwarfs | **47–53 tall**, 22–42 colours, 15 parts each. `dwarf_01.gltf` **154 clips** |
| `voxel-elf-characters` | 247 MB | 181 (5 vox, 5 gltf, 5 dae, 160 png, 6 unitypackage) | 5 rigged elfs | **58–63 tall**, 22–29 colours, 16 parts. `elf_1.gltf` **180 clips** |
| `voxel-knight-character` | 56 MB | 35 (1 gltf, 1 glb, 1 usdz, 32 png) | one rigged knight | **no `.vox` delivered**. `knight.gltf` **179 clips** |
| `voxel-forest-animals` | 105 MB | 2 828 (9 vox, 10 gltf, 74 dae, 2 734 png, 1 unitypackage) | 10 quadruped/bird wildlife species | see §1.2. `bear.gltf` **7 clips**, `wolf.gltf` **9** |
| `voxel-winter-animals` | 277 MB | 192 (5 vox, 5 gltf, 5 dae, 166 png, 6 unitypackage, 5 zip) | **5 anthropomorphic animal warriors**: Bear/Bison/Eagle/Moose/Wolf Model | **57–66 tall**, 27–36 colours. `bear_warrior.gltf` **181 clips** |
| `voxel-weapons-pack` | 20 MB | 650 (27 vox, 49 vxm, 9 vxa, 9 vxr, 97 prefab, 54 obj, 11 gltf, 3 fbx, 275 png, 1 unitypackage) | 50 weapons in 8 classes, two distributions (Unity + native) | axes **50–51 voxels long**, 4–8 colours each |
| `voxel-stylized-trees` | 325 MB | 2 349 (**55 vox**, 115 gltf, 115 obj+mtl, 116 dae, 1 743 png, 89 zip, 1 unitypackage) | **16** species folders `Tree 01`…`Tree 16` | Tree 01–04 and 06 ship **no `.vox`** (45 gltf meshes only) |

Total tracked in the assets repo: **7 141 files**, of which **6 906 are under
`packs/`**. `.git` is **1.6 GB**.

Two corrections to records that are relied on elsewhere:

- `LICENSES/voxel-stylized-trees.md:14` says "~29 tree species in numbered
  folders". There are **16**. The 55 `.vox` figure on line 18 is correct.
- `ASSETS-PLAN.md` "What exists" lists **"Winter animals (5)"** and **"Animal
  warriors (bear, wolf, moose, bison, eagle)"** as two owned things. They are
  **one pack**: `packs/voxel-winter-animals/` contains `Bear Model`,
  `Bison Model`, `Eagle Model`, `Moose Model`, `Wolf Model`, and
  `LICENSES/voxel-winter-animals.md:15-19` states plainly that they are
  "5 ANTHROPOMORPHIC animal warriors … NOT wildlife". There is **no second
  quadruped bear** and no eagle bird. `40-characters.md`'s row "Winter animals
  (5) | bear 21, bison 21, moose 29 tall (parts)" measured *individual vox
  parts*, not models; the models are 57–66 voxels tall.

### 1.2 Forest animals, measured (the scale question)

| Species | w × h × d (voxels) | Voxels | Colours | At 3.3 cm (character grain) |
|---|---|---|---|---|
| bear | 76 × **98** × 171 | 462 814 | 21 | 3.27 m tall, **5.70 m long** |
| moose | 65 × 87 × 73 | 30 722 | 21 | 2.90 × 2.43 m |
| deer | 40 × 101 × 67 | 24 924 | 14 | 3.37 m tall |
| wolf | 33 × 65 × 73 | 24 797 | 23 | 2.17 × 2.43 m |
| wild boar | 31 × 59 × 70 | 23 980 | 19 | 1.97 × 2.33 m |
| fox | 16 × 42 × 14 | 2 013 | 15 | 1.40 m tall |
| raccoon | 14 × 39 × 12 | 2 179 | 12 | 1.30 m |
| squirrel | 15 × 37 × 12 | 1 897 | 16 | 1.23 m |
| rabbit | 14 × 30 × 12 | 1 885 | 11 | 1.00 m |
| owl | glTF only, no `.vox` | – | – | – |

(`40-characters.md` says the bear is 533 000 voxels; the merged grid in
`game/creatures/bear/bear.vox` is **462 814**. Fox is 42 tall, not 32; deer 101,
not 107; rabbit 30, not 32.)

### 1.3 Derived sets (`Kubik-assets/game/`) — 209 files

| Set | Contents | Notes |
|---|---|---|
| `game/characters/viking/` | 5 `.vox` + `male_a1.gltf` (75 MB, LFS) | the construction templates |
| `game/characters/dwarf/` | 10 `.gltf` (≈35 MB each) + 10 `.vox` | |
| `game/characters/elf/` | 5 `.gltf` (≈50 MB each) + 5 `.vox` | |
| `game/characters/knight/` | `knight.gltf` only | no `.vox` exists to reskin |
| `game/creatures/` (15 dirs) | 10 wildlife (10 gltf, 9 vox) + 5 warriors (5 gltf, 5 vox) | |
| `game/weapons/` (8 classes) | 50 `.gltf`, textured, atlas embedded | axe 10, dagger 4, hammer 2, polearm 10, scythe 2, spear 8, staff 1, sword 13 |
| `game/trees/` | **38 `.ktree`** + **55 `.json`** sidecars | 38 geometries from 55 files; 17 colourway twins share geometry |

Totals: 82 `.gltf`, 34 `.vox`, 38 `.ktree`, 55 `.json`.

### 1.4 The tree library, measured from its 55 sidecars

Every sidecar carries `"voxel_m": 0.125` and `"voxels_per_block": 4` — no
exceptions. Heights:

- **6 variants at exactly 2.000 m** (`t16_1`…`t16_6`, the cut stumps)
- **49 variants at 9.125 m to 28.000 m** (t10_4 = 9.125, t10_5 = 13.125, the
  rest 16.75–28.0)
- LOD rungs: three per geometry at steps 1 / 2 / 4, greedy-meshed offline
- Worst LOD0 in the library: `t10_3` at 16 597 quads (33 194 triangles)

Colourways, computed by resolving each sidecar's `canopy_palette` through the
game's own `PACK_FAMILIES` table:

| Canopy family | Variants |
|---|---|
| CANOPY (green) | **27** |
| AUTUMN | **12** |
| CRIMSON | **5** |
| PINK | **1** |
| SNOW | **2** |
| BARK (snags, stumps) | **8** |

This is where `20-world-and-terrain.md`'s "27 green variants", "2 white
variants" and "5 purple and magenta variants" come from — they check out. Its
"13 orange variants" is **12**.

### 1.5 Tools

| Script | Lines | What it does | Constants |
|---|---|---|---|
| `tools/trees_convert.py` | 627 | parses the pack's `.vox` scene graphs → merged grid → geometry hash dedupe → 3 downsampled rungs → greedy mesh per palette index → `.ktree` + `.json` | `VOXELS_PER_BLOCK = 4` (:48), `BLOCK_M = 0.5` (:49), `VOXEL_M = 0.125` (:50), `MAGIC = b"KTRE"` (:52), `VERSION = 1` (:53), `LOD_STEPS = (1,2,4)` (:54) |
| `tools/trees_palette_table.py` | 132 | reads the sidecars, classifies each pack index into a Kubik family name by HSV rule, prints the GDScript `PACK_FAMILIES` block. **Prints indices and family names only, never the pack's RGB** | HSV thresholds only |
| `tools/weapons_convert.py` | 175 | decodes Unity-YAML meshes → one self-contained textured `.gltf` per weapon | **`SCRATCH = r"C:/Users/tiger/AppData/Local/Temp/…"` (:13)** — a dead Windows path; the script cannot run today |
| `derived/knight/vox_parse.py` | 202 | `.vox` chunk reader with `nTRN` scene-graph walk and rotation matrices. `trees_convert.py` imports it | – |
| `derived/knight/knight_template.py` | 387 | takes the Male_A1 template's parts, repaints them, drops the viking dressing, paints a face, **builds fresh armour geometry**, greedy-merges, emits a **`.bbmodel`** | **`VOX = "C:/Users/tiger/Documents/GitHub/Kubik-assets/…/male_a1.vox"` (:19)**; output `kubik-knight-demo.bbmodel` (:368) |

### 1.6 Where the game uses it — every consumer

Exhaustive: `grep -rn "assets/purchased" scripts scenes` returns **two**
consumers.

| Asset | Consumer | Verdict on usage |
|---|---|---|
| `characters/viking/male_a1.gltf` | `scripts/character/purchased_view.gd:20` (`SCENE_PATH`), instantiated at `scripts/character/character_view.gd:89-91`, opt-in behind `--viking` / `KUBIK_VIKING=1` (`purchased_view.gd:33-36`) | the only character the game loads |
| `trees/*.ktree` + `*.json` | `scripts/world/flora/tree_models.gd:45` (`ROOT`), `:53` (`VOXELS_PER_BLOCK := 4`), `:57` (`LOD_COUNT := 3`), `:307-309` (sidecar `voxels_per_block` asserted against the build) | the whole tree renderer |
| **50 weapons** | **nothing** | mounted, never read |
| **10 wildlife creatures** | **nothing** | mounted, never read |
| **5 animal warriors** | **nothing** | not even mounted |
| **10 dwarfs, 5 elfs, 1 knight** | **nothing** | not even mounted |

**The mount is five commits stale.** `assets/purchased/.sync_manifest.json` was
last written **2026-08-31 23:12** and holds **75 entries** (50 weapons,
19 creature files, 6 viking files). The assets repo has added the knight,
dwarfs, elfs, animal warriors and the whole tree library since
(`5eab075`, `388692c`, `76b1321`, `490ce13`). **`assets/purchased/trees/` does
not exist**, so `TreeModels.available()` is false in this working copy and the
game currently plants no trees. One command fixes it:
`python3 scripts/tools/sync_assets.py`.

### 1.7 The game's own asset directories

| Path | Contents | Tracked? |
|---|---|---|
| `assets/purchased/` | 61 gltf, 14 vox, 695 png (Godot-extracted glTF textures), 756 `.import`, 1 manifest | **git-ignored** (`.gitignore` last line) |
| `assets/characters/parts/` | 8 JSON modules, **101 parts, ~1.85 MB**: `human` 71 KB, `elf` 71 KB, `dwarf` 77 KB, `lizardfolk` 66 KB, `critter` 35 KB, `hair` 393 KB, `gear` 7 KB, `armour` **1.11 MB** | tracked (10 files) |
| `assets/textures/` | `block_placeholder.png` — **16 × 16, 560 bytes**, and its `.import`. `scripts/world/chunk_mesher.gd:10-13`: "unused as of Stage 3 … left in the repo rather than deleted, because a texture atlas with per-face UVs is still on the roadmap" | tracked |
| `assets/ui/` | `deco_theme.tres`, 251 lines, the project-wide Godot theme | tracked |
| `assets/fonts/` | Limelight, Josefin Sans (variable), Poiret One + 3 OFL licence files + 3 `.import` | tracked |

Total tracked under `assets/`: **22 files**.

---

## 2. Verdicts

### 2.1 Trees — does the pipeline match D21?

**Yes, on every measurable count. KEEP, with one colour retune.**

| D21 / bible requirement | Delivered | Evidence |
|---|---|---|
| 0.125 m per tree voxel | ✔ | `"voxel_m": 0.125` in all 55 sidecars; `trees_convert.py:50` |
| 4 tree voxels per world cube | ✔ | `"voxels_per_block": 4`; `tree_models.gd:53`; asserted at load `:307-309` |
| Real size 9–28 m | ✔ | 49 variants span **9.125–28.000 m**; 6 stumps at exactly 2.000 m, which is `70-scale-metrics`'s "Small tree (bush variants) — 1 player, 2 m, 4 cubes" |
| Greedy-meshed | ✔ | `trees_convert.greedy()` :239-268, offline; `tree_models.gd:32-41` — "GDScript assembles, it never meshes" |
| LOD rungs | ✔ | 3 rungs at steps 1/2/4; the game maps 4 distance bands onto them (`docs/status/trees-v3.md:734-745`), sharing LOD2 for the outer two |
| "Chamfered meshes stay rejected" | ✔ | Tree 01–04 and 06 hold **45 gltf, 0 vox** and are never imported (`docs/plans/trees-v3.md:237`: "mesh-only species (01-04, 06) are NOT imported - chamfer stays out"). No `.obj`/`.dae`/`.gltf` from the pack reaches the game |
| Wild colours only in the far islands | ✔ | `tree_table.gd` parks the crimson and pink colourways at **weight 0** — present, inert, one character to awaken |

**ADAPT — the one mismatch.** `tree_palette.gd:52-55` canopy ramp is
`#2F4F3E / #385C48 / #4F7A3A / #5F8A46`. `10-color-and-light.md`'s Conifer row
is `#575d54 / #7e8986 / #9b9f81` — a desaturated grey-green, three shades, not
four saturated forest greens. This is exactly the one-file edit the design was
built for ("retuning a canopy green is editing a row of FAMILIES below",
`tree_palette.gd:15-16`). No re-bake, no assets-repo commit.

Second, smaller: `tree_table.gd` sets `height_m = NATIVE` on every row, so the
library lands at 21–28 m for the trees proper. The bible allows 9–28 m. If the
valleys read too dark, `height_m` is the knob and it is already there.

### 2.2 Characters — used "as they are, reskinned clothes only"? **No.**

D1: "built on the bought templates as they are (59-69 voxels tall … reskinned
clothes only)". `40-characters.md`: "their proportions, grain and rigs are not
changed", "No re-proportioning of the templates".

The game has **two character systems**, and the one that is actually built is
not the templates:

1. **The parts system** — `assets/characters/parts/*.json`, 101 parts,
   1.85 MB of ASCII, generated by `tools/parts_author/`; assembled by
   `VoxelModel` and `Rig`; four races in `races.gd:16-21`
   (`HUMAN`, `ELF`, `DWARF`, `LIZARDFOLK`) plus a `critter` module.
   `voxel_model.gd:76`: **`const VOXEL_M := 2.0 / 96.0`** — a 2 m human is
   **96 voxels**, one voxel **2.083 cm**.
   `vox_loader.gd:47`: drop-ins are looked for **per part** at
   `assets/characters/<race>/<part>.vox`.
   **This is a character cut into parts, at a different grain, on races the
   bible has abolished.**
2. **The template system** — `purchased_view.gd`, one glTF, opt-in, explicitly
   labelled "DEMO SCAFFOLDING, NOT THE CHARACTER PIPELINE" (`:6`).

Verdicts:

- `purchased_view.gd` + `character_view.gd:89-91` — **KEEP**. It is the seed of
  the pipeline D1 asks for: it loads a whole template, normalises its height,
  grounds the feet, and drives the seller's clips. It needs promoting from a
  flag to the default path, and extending from 1 template to 21
  (5 viking + 5 elf + 10 dwarf + 1 knight).
- `voxel_model.gd`'s **96-voxel grain — ADAPT or RIP**. The bible pins the
  character grain to the templates: 59–63 voxels for 2 m, **3.3 cm per voxel,
  15 per world cube**. The game's is 2.08 cm, 24 per cube. Two grains cannot
  both be "the" character voxel; `50-props-and-tech.md` sizes every prop in the
  bible's ("a 1 m object is about 30 voxels"), so props authored against
  `VOXEL_M` would come out 1.6× too fine.
- `races.gd`'s **`LIZARDFOLK` and the `critter` module — RIP** under D37 ("no
  other races … Assets are used as they are"). The elf and dwarf *modules* can
  survive as body types (D37 keeps elf and dwarf as body types of one people),
  but the lizardfolk has no place in the bible's world at all.
- `vox_loader.gd`'s **per-part drop-in — ADAPT**. Under D1 the unit of
  replacement is a whole reskinned template, not a `head.vox`. The 20-slot
  palette convention (`assets/characters/README.md`) is the good half and is
  worth keeping for *props*, where authoring in slots is still right.
- `assets/characters/parts/*.json` — **park, do not delete yet**. 1.85 MB and
  101 parts is real work, and the *proportions* are already bible-correct (head
  33 of 96 = a third = about 3 heads, `races.gd:41-52`). What is wrong is the
  grain and the premise (build a body vs. reskin a bought one). It is the
  fallback if the template route stalls; it is not the direction.

### 2.3 The knight reskin template — does it do what ASSETS-PLAN asks?

`ASSETS-PLAN.md` "Make, do not buy": *"Engineers, mountain folk and Perchten
reskins | repaint scripts on the viking/elf/dwarf templates, like
`derived/knight/knight_template.py`"*.

**ADAPT — it is the right idea in the wrong shape, and it cannot run today.**

What it gets right: it reads the real template (`vox_parse.parse(VOX)`), keeps
the body parts in their authored positions, names its groups to match the
purchased rig ("Hip/Belly/Chest/Head/Left_Arm/…") so the ~200-clip library maps
1:1, greedy-merges before emitting, and works in a 21-colour palette of three
shades per material with `#C9A24A` gold — which is `10-color-and-light.md`'s
gold, exactly.

What is wrong for the bible:

1. **It emits a `.bbmodel`** (`:368`), a Blockbench document. The pipeline the
   bible describes wants `.vox` — that is what `vox_loader.gd` reads, what
   `trees_convert.py` reads, and what every pack ships. No `.bbmodel` reader
   exists anywhere in the game. The output has **no consumer**, and no derived
   knight exists in `game/`.
2. **The source path is hardcoded to a dead Windows machine** (`:19`,
   `C:/Users/tiger/…`). The script cannot run on this machine. Same defect as
   `tools/weapons_convert.py:13`.
3. **It builds fresh armour geometry** — helmet bowl, crenellated visor band,
   cheek guards, pauldrons with tilt origins, tassets, a staircase plume — at
   template scale, rather than repainting what the template has. That is a
   defensible reading of "reskinned clothes only" (clothes *are* geometry), and
   D27 explicitly wants "steel-and-brass deco plate, a plain visor helm, a
   stepped plume, tilted pauldrons, a gold belt" — but it means the script is a
   **character author**, not a **repaint script**, and it will not generalise to
   "recolour brown/black/brass to cream/teal/gold" the way ASSETS-PLAN's
   steampunk row asks.
4. It also **paints a face** (eyes, brows, nose, mouth). `40-characters.md`:
   "Faces: as the templates. Identity comes from hat, hair block, cloak and
   colour, not from the face."

What to build instead, reusing this file: split it in two. A **repaint pass**
(a colour-map over a template's existing voxels, emitting `.vox`, three shades
per material, ≤8 materials, gold `#c9a24a` only) is the thing ASSETS-PLAN's
table actually asks for and is maybe 80 lines. An **armour-author pass** (the
box-building half here) is a second, optional layer for the Engineer guard.
`vox_parse.py` and the greedy merger are keepers either way.

### 2.4 Animal packs — right grain and scale?

**Forest animals: ADAPT (a global scale), and the bible contradicts itself
here.**

- `70-scale-metrics.md`: "Bear | 0.7 at the shoulder (target) | delivered at
  1.6 players, too big; **scale the forest-animal pack down so a bear is about
  0.7 players at the shoulder and its voxels match the character grain**".
- `40-characters.md`: "**Match the grain**: scale the forest-animal pack so a
  wolf's voxels are about the size of a character's voxels, or accept fur-like
  texture".

These cannot both hold. At the character grain (3.3 cm) the measured bear is
**3.27 m tall and 5.70 m long** — 1.6 players, which is precisely the "too big"
the scale table complains about. Matching the grain *is* what makes it too big.

The number that satisfies the scale target: **≈1.9 cm per forest-animal voxel**
(≈0.57× the character voxel, ≈26 per world cube). At that rung the whole pack
lands at real size in one uniform factor:

| Species | at 1.9 cm |
|---|---|
| bear | 1.86 m tall, **3.25 m long** |
| wolf | 1.24 m tall, 1.39 m long |
| deer | 1.92 m to the antlers |
| boar | 1.12 × 1.33 m |
| fox | 0.80 m tall |
| rabbit | 0.57 m |

So: **scale the forest pack to a grain of its own (≈1.9 cm), and accept the
finer texture** — the escape `40-characters.md` already allows. Then delete the
"and its voxels match the character grain" clause from `70-scale-metrics.md`, or
the sentence will keep producing 5.7 m bears. **Flag to the bible.**

**Winter animals / animal warriors: KEEP as the Perchten, RIP the second role.**
Measured 57–66 voxels tall — already at the character grain, no scaling needed,
181 clips on a humanoid rig. They are exactly what D37 and `40-characters.md`
want for "people further along that change". But ASSETS-PLAN's owned-table row
"Winter animals (5) | second bear, bison, moose, eagle | coarser; pick one bear"
describes a pack that does not exist. **There is no second bear to pick.** The
"pick one bear so the two grains never stand side by side" instruction is moot:
there is only one quadruped bear in the whole library.

### 2.5 `assets/textures` and pillar 2

`assets/textures/` holds exactly **one** image: `block_placeholder.png`,
**16 × 16, 560 bytes, RGB**. It is a flat placeholder, not a photograph, so it
does not breach "no photo textures, on anything, ever". It is also **unused** —
`chunk_mesher.gd:10-13` says so, and says why it is kept: "a texture atlas with
per-face UVs is still on the roadmap".

**Verdict: RIP the roadmap item, park or delete the file.** Pillar 2 says
"every surface is a flat-coloured cube in three shades", and the mesher's own
opening paragraph already makes the bible's argument better than the bible does
("flat saturated colour reads further and more clearly than any 16×16 texture
would", `chunk_mesher.gd:5-8`). A per-face UV atlas is a second surface
language arriving by roadmap. The 560-byte file is harmless; the plan is not.

Fonts and the UI theme: **KEEP**. Three OFL fonts with licences beside them; the
theme is deco, chamfered corners, "no texture" by explicit rule
(`deco_theme.tres` header). `60-ui-and-2d.md` wants nouveau on paper, which the
theme is not yet — but that is a UI question, not an assets one, and the bible
files it under "later; a separate small task".

### 2.6 A third surface language still in use?

| Candidate | In use? | Verdict |
|---|---|---|
| The tree pack's chamfered low-poly meshes (115 gltf, 115 obj, 116 dae, 1 743 png) | **No.** Archive only; the 5 mesh-only species are not imported | **RIP confirmed, already done** |
| **The 50 converted weapon glTFs** | Mounted at `assets/purchased/weapons/`, **read by nothing** | **ADAPT.** They are triangle meshes with `TEXCOORD_0` and an embedded PNG atlas (nearest-filtered; `axe_1.gltf`: 1 mesh, 1 image, 1 material, 1 127 verts). Flat-colour atlas, so not a photo texture — but a *textured mesh* path alongside the vertex-colour path everything else uses. The pack ships **27 `.vox` and 49 `.vxm`** native sources (`packs/voxel-weapons-pack/native/`), and the axes measure **50–51 voxels**, matching `50-props-and-tech.md`'s "axes about 50 voxels long" exactly. Re-bake from `.vox` through the same greedy/vertex-colour route as the trees; do not ship the atlas path |
| The character glTFs (viking, dwarf, elf, knight, warriors) | 1 of 21 used | These are **skinned meshes with embedded textures** by construction — the only way to get the seller's 150–200 clips. D1 accepts them as the templates, so this is the one licensed exception, not a third language. **KEEP** |
| `docs/DESIGN.md:119-123` "Forms are sculpted, stepped and **chamfered**" | the game's own earlier art rule | **Not a conflict.** This is voxel-level chamfer (a stepped corner), which `50-props-and-tech.md` also allows ("becomes square with a chamfer; no curves smaller than 10 voxels radius"). The rejected thing is chamfered *low-poly meshes*, which are out |

### 2.7 Verdict summary

| Item | Verdict |
|---|---|
| Tree library (38 ktree, 55 sidecars) + `trees_convert.py` + `tree_models.gd` | **KEEP** |
| `tree_palette.gd` canopy ramp | **ADAPT** — retune to `#575d54 / #7e8986 / #9b9f81` |
| `trees_palette_table.py` | **KEEP** — and it is the licensing firewall |
| Viking / elf / dwarf `.vox` templates | **KEEP** — the construction base (D1) |
| Knight glTF | **KEEP** as the Engineer knight (D27); **no `.vox` = no reskin route** |
| Animal warriors (winter pack) | **KEEP** as the Perchten (D37) |
| Forest animals | **ADAPT** — one global scale to ≈1.9 cm/voxel |
| Weapons, 50 glTF | **ADAPT** — re-bake from the 27 `.vox` / 49 `.vxm`, drop the atlas |
| `purchased_view.gd` | **KEEP** — promote from demo flag to the pipeline |
| `voxel_model.gd` `VOXEL_M = 2.0/96` | **ADAPT** — two character grains cannot both be canon |
| `races.gd` LIZARDFOLK + `critter.json` | **RIP** (D37) |
| `assets/characters/parts/*.json` (101 parts) | **PARK** — right proportions, wrong grain, wrong premise |
| `vox_loader.gd` per-part drop-in | **ADAPT** — keep the 20-slot convention for props |
| `knight_template.py` | **ADAPT** — split into a repaint pass (`.vox` out) and an armour author; fix `:19` |
| `weapons_convert.py` | **RIP** — dead Windows path at `:13`, one-shot, superseded |
| `block_placeholder.png` + the UV-atlas roadmap | **RIP the roadmap**, park the file |
| Fonts, `deco_theme.tres` | **KEEP** |
| The stale mount | **FIX NOW** — one command |
| The house generator (exists, produces PNGs into `Kubik-bible/previews/houses/`) | **HOMELESS** — no script and no `.vox`/`.json` in any of the three repos; ASSETS-PLAN says it belongs in `Kubik-assets` |

---

## 3. The gaps

### 3.1 Buy now (ASSETS-PLAN, rings 0–1) — none of it exists

| Wanted | Status | Note |
|---|---|---|
| Voxel Steampunk Characters Pack (€24.99, 10 characters) | **MISSING** | Order-of-work item 1. The rig check ASSETS-PLAN asks for has a measurable target now: the viking rig is a segmented node rig, and `male_a1.gltf` carries 199 clips. If the steampunk pack's node names match, the clip library transfers |
| Props Pack (interior): lamps, tables, chairs, chests | **MISSING** | Needed for `35-interiors.md`. Grain test: character-voxel scale, so a chair is 0.6 players ≈ 36 voxels tall |
| Plants Pack (65 models) | **MISSING** | Note: the game already generates its own ground cover in `FloraModels` (916 lines) at its own rung. A bought plants pack lands next to it, not instead of it — decide which owns undergrowth before buying |

### 3.2 Make, do not buy — reskins

| Wanted | Status |
|---|---|
| Engineers reskin (cream/teal/gold on the steampunk pack) | **MISSING** — blocked on the purchase |
| Mountain-folk reskin (leather, fur, wool, felt, mail; no winged helmets, no beard braids — D27) on viking/dwarf | **MISSING** |
| Perchten reskin (masked, purple/black) on the animal warriors | **MISSING** |
| Any reskin at all | **MISSING** — `derived/` contains one `.bbmodel` and no `.vox` |

### 3.3 Make, do not buy — props

Every one **MISSING**. `50-props-and-tech.md` gives exact sizes, so these are
short scripts, not research:

| Prop | Spec from the bible |
|---|---|
| Campfire | 5 crossed logs, core `#f5c05e`, edge `#bf672d`, ~10 voxels tall × 20 across (≈0.3 players, 1 cube) — **required by ROUND-3-BRIEF item 3** |
| Torch | 30 voxels tall, dark shaft, glowing head |
| Street lamp | 90 voxels tall; green glass in the capital |
| Faceted pendant lamp | 30 across |
| Fan sconce | 24 wide, gold, 5 rays |
| Crystals | teal `#17c0b1`, **2–10 world cubes** tall (so these are world-cube grain, not prop grain) |
| Banners | flat rectangles 1 world cube thick |
| Zeppelin | one `.vox` at world scale: cream envelope, gold lines, brass gondola (D24) |

### 3.4 Make, do not buy — the building generators (rewritten for D43)

**A house generator exists and has run — but it is in none of the three repos.**

`Kubik-bible/previews/houses/` (commits `adc77f4`, `3e9d1b0`, `0c11571`) holds
`REPORT_1.md` and six PNGs: `street_1_day_iso`, `street_1_night_iso`,
`street_1_front`, `street_1_far300m`, `street_1_sheet`, `grain_compare`.
`REPORT_1.md` tables **8 houses** (5 half-timber, 3 chalet), each with type,
floors, size, height check, door, windows per floor, gold count, colour count
and PASS — i.e. the bible-conformance checker ASSETS-PLAN asks for **already
exists too**. Colour counts run 8–14, all pass.

What is **not** anywhere I can see: **the generator script, and its `.vox` and
`.json` outputs.** `Kubik-assets/tools/` holds three scripts (trees ×2,
weapons); `Kubik-assets/derived/` holds the knight; neither has a house or a
`previews/`. `REPORT_1.md` says "Knobs per house are in the .json sidecars" —
there are no sidecars in the bible repo, only PNGs. And ASSETS-PLAN is explicit:
*"Python generators in `Kubik-assets`"*. **Find where that generator lives and
land it in `Kubik-assets/tools/` with its outputs in `game/buildings/`,** or the
first real generator is a set of screenshots with no source.

Game side, still: **nothing.** `scripts/world/` is terrain, heightmap, lakes,
far-field and flora; there is no structure, village, house or landmark code, and
no `BuildingModels` sibling to `TreeModels`. `grep -ril
"village|structure|POI|landmark" scripts` returns only UI, probes and the
compass.

D43's target format: *"generated at 0.125 m voxels, 4 per world cube, and baked
with three level-of-detail rungs (0.125, 0.25, 0.5 m) like the trees"*
(`70-scale-metrics.md` §"Generated buildings (D43)"), *"a `.vox` at the tree
grain (voxel_m 0.125, voxels_per_block 4; D43) with a sidecar like the trees'"*
(`ASSETS-PLAN.md`).

**D43 makes the tree pipeline a near-exact fit — this is the good news of the
audit.** Under the superseded 0.5 m wording, `trees_convert.py:48` and
`tree_models.gd:53` would both have needed their hardcoded `4` parameterised.
At the tree grain **neither constant changes**, `tree_models.gd:307-309`'s
sidecar assertion passes as written, and the LOD ladder D43 asks for
(0.125 / 0.25 / 0.5 m) is bit-for-bit `LOD_STEPS = (1, 2, 4)`
(`trees_convert.py:54`) — the 0.5 m far view D43 wants "for free" is literally
the rung the tree pipeline already bakes.

**What the tree pipeline gives you for free:**

| Reusable | Where | Note |
|---|---|---|
| The whole `.ktree` format and its writer | `trees_convert.py:434-444` (`write_ktree`), `QUAD = struct.Struct("<HHHBBHH")` :58 | 12-byte quads, three LOD blocks, `KTRE` v1 |
| The greedy mesher | `trees_convert.py:239-321` | Merges per palette index — exactly right for a wall of one body colour in three shades |
| The `Grid` volume and its `permuted()` slice trick | `:64-118` | The speed of the whole thing |
| The LOD downsampler | `:189-238` | "any-occupied, majority-coloured" — the right rule for a fluted wall at 2 km too |
| The sidecar writer | `:601-624` | `size`, `origin_voxels`, `voxel_m`, `voxels_per_block`, `height_m`, `palette`, `index_stats` — the exact schema ASSETS-PLAN names |
| The index/family split | `trees_palette_table.py` + `tree_palette.gd` | The pattern that keeps the artist's colours out of the public repo. A building generator authors in Kubik colours from the start, so it can emit family names directly and skip the classifier |
| The game-side loader shape | `tree_models.gd` (643 lines) | `available()` / `mesh_for()` / `triangles_for()`, mutex-guarded lazy cache, sidecar assertion at `:307-309`. A `BuildingModels` sibling is a copy with a different `VOXELS_PER_BLOCK` — and the file's own header (`:8-21`) explains why a sibling and not a tenant |

**What is new and must be written:**

1. **A `BuildingModels` loader in the game.** `tree_models.gd`'s own header
   (`:8-21`) argues why trees are a *sibling* of `FloraModels` and not a tenant
   — an id is the top byte of a flora identity and carries promotion and removal
   machinery with it. The same argument applies again: buildings are a third
   sibling, a copy of `tree_models.gd` with its own ids and its own material.
   The constants do not change; the file does.
2. **The 256-voxel wall.** D43 names it: *"landmarks are 500-1,000 voxels tall
   and need stacked `.vox` models or the engine's grid format."* MagicaVoxel's
   `.vox` caps a model at **256 per axis**, and a landmark tower of 120–240
   world cubes is **480–960 voxels** at 4 per cube. `.ktree` itself is fine —
   its coordinates are `u16` (`trees_convert.py:58`) and its LOD grids are
   per-rung — so the constraint is only on the intermediate `.vox`, and the
   cleanest answer is for a landmark generator to build its `Grid` in memory and
   bake straight to `.ktree`, emitting `.vox` only for pieces under 256. That
   decision is not made anywhere yet.
3. **Cost.** A house is ~30 000 voxels as a shell (D43's own estimate); the
   library's worst tree is 33 194 LOD0 triangles against a 40 000 gate
   (`docs/status/trees-v3.md:1458`). A **village of thirty houses** is a load
   the tree budget work never had to carry, and a landmark of 500–1 000 voxels
   is an order above anything in the library. Measure a house's LOD0 triangle
   count against that gate before generating thirty.
4. **The generators themselves, past houses.** Half-timber and chalet exist as
   PNGs. There is no prior art at all for the landmark: no setback, no flute, no
   sunburst, no crown. `30-architecture.md` gives the numbers (5–7 setbacks
   ≥3 cubes deep, ribs every 2–3 cubes, sunburst 16–24 cubes wide, door 12–20,
   tower 120–240) and `70-scale-metrics.md` the ornament table, now with D43's
   rule that the gold corner line **stays one world cube (4 voxels) wide so it
   reads at 2 km** while ornament inside it may be finer.
5. **Placement.** Even with a `.vox`/`.ktree` house, nothing in the game stamps
   a building into the world. `TreePlacement` (1 011 lines) is the model for a
   seeded lattice, but a village needs roads, slopes and footprint flattening,
   which trees never needed.

Already solved, and worth saying so: the **bible checker** and the **PNG
renderer** ASSETS-PLAN asks for both exist — `REPORT_1.md`'s pass table is the
checker's output (height, door, windows, gold, colour count) and the six
previews are the renderer's. Neither is in the repos either.

### 3.5 Against ROUND-3-BRIEF specifically

| Brief item | Asset status |
|---|---|
| 1. Landmark gate, Family A, ≥120 cubes | **MISSING** — no generator, no model, no placement, and the 256-voxel `.vox` wall unresolved |
| 2. Village of 5 houses (4 half-timber, 1 chalet) | **PART** — a generator has produced 5 half-timber and 3 chalet and passed them against the bible (`previews/houses/REPORT_1.md`), but neither the script nor a `.vox`/`.ktree` is in any repo, and the game has no loader or placement for one |
| 3. Campfire + **two viking players as they are** | Templates **present**; campfire **missing**; the second player and the whole-template path are **missing** (one opt-in glTF today) |
| 4. Forest of real-size trees | **PRESENT and correct** — but not mounted right now |
| 5. Fog / 6. the four hours / 7. the film lens | Engine, not assets (ASSETS-PLAN says so explicitly) |
| Snow line, rock, jagged peaks | Terrain, exists |

**The test scene is one asset-side item away from being mostly buildable:
buildings.** Trees are done. Characters are one promotion away. The campfire is
an afternoon. Houses are generated but homeless — no script in a repo, no
binary, no loader.

---

## 4. Licensing

### 4.1 What each licence record actually says

There are eight records in `Kubik-assets/LICENSES/`. **All eight are Marcel's
own notes, not the sellers' licences.** Every one of them carries this line, in
italics, with the storefront field left blank:

> **Store / seller:** _record the storefront and seller link here — the zip
> ships no license file, so the terms of the store listing are the license._
> — `voxel-dwarf-characters.md:6-8`, `voxel-elf-characters.md:7-9`,
> `voxel-forest-animals.md:6-8`, `voxel-knight-character.md:6-8`,
> `voxel-stylized-trees.md:8-10`, `voxel-viking-characters.md:5-7`,
> `voxel-weapons-pack.md:6-8`, `voxel-winter-animals.md:9-11`

**So on redistribution, every actual licence is silent — because no actual
licence text is on file for any of the eight packs.** None of the eight names
its seller or storefront. The only vendor identification anywhere is a guess:
"Same seller family as the Sketchfab 'Voxel Characters' collection (MrMGames)
**by all appearances**" (`voxel-viking-characters.md:7-8`) and "Same seller
family as the viking templates **by all appearances**"
(`voxel-weapons-pack.md:8-9`).

What each record *does* state, as terms understood at purchase:

| Pack | Line | Text |
|---|---|---|
| dwarf | :9-11 | "licensed for use and modification in Marcel's game projects; NOT open source; **no redistribution of the assets as assets (source files, packs, or extractable form)**" |
| elf | :10-12 | identical wording |
| forest animals | :9-11 | identical wording |
| knight | :9-11 | identical wording |
| stylized trees | :11-13 | identical wording |
| winter animals | :12-14 | identical wording |
| viking | :9-11 | "…; NOT open source; **no redistribution of the assets as assets.**" (no parenthetical) |
| weapons | :10-12 | same short form as viking |

Two records go further and bind the *derived* work:

> "**What is derived from it:** … That output is DERIVED FROM licensed source
> and is covered by the same terms: it lives in this private repo and in the
> gitignored mount, **never in the public Kubik repo**."
> — `voxel-stylized-trees.md:29-33`

> "Derived models are still purchased-derived: they live in this repo or the
> ignored mount, **never in the public repo**."
> — `voxel-viking-characters.md:27-28`

And `voxel-stylized-trees.md:18-28` records the ruling that matters for the
bible's "chamfered meshes stay rejected":

> "What the game mounts: the **55 `.vox` sources**, and nothing else. … the
> pack's **chamfered low-poly meshes** — the `.gltf`, `.obj`, `.dae` and their
> PNG atlases — are a third surface language and are STILL rejected, untouched,
> archive only."

### 4.2 Is anything redistributed in a way the licence forbids?

**In the public `Kubik` repo: no. The firewall holds, and I checked it four
ways.**

The repo is MIT (`LICENSE:1`, "MIT License", copyright Marcell
Bierbauer-Szigeti) with remote `https://github.com/FrostyyTiger/Kubik.git`.

1. **Working tree.** `git ls-files assets` returns **22 files**: 10 parts JSON
   + READMEs, 8 font files/licences/imports, `block_placeholder.png` + import,
   `deco_theme.tres`. No `.vox`, `.gltf`, `.glb`, `.ktree`, `.unitypackage`,
   `.usdz`, `.fbx`, `.dae`, `.prefab`, `.vxm`.
2. **Whole repo, all extensions.** `git ls-files` across the entire repo:
   98 `.uid`, 96 `.gd`, 54 `.md`, 14 `.py`, 10 `.tscn`, 8 `.json`, 5 `.import`,
   5 `.h`, 5 `.cpp`, 3 `.txt`, 3 `.ttf`, 2 `.yml`, and single config files.
   **One `.png`** — the 16×16 placeholder. **Zero** model or archive files of
   any kind.
3. **Full history, every branch.**
   `git log --all --diff-filter=A --name-only` filtered for
   `vox|gltf|glb|ktree|unitypackage|usdz|fbx|dae|vxm|vxr|vxa|prefab`: **empty**.
   No purchased source file has ever been committed to the public repo.
   The same search for images returns three files ever: the placeholder, and
   `fg-before.png` / `fg-after.png` — two debug **screenshots of the running
   game**, added in `e58d88f` and deleted in `ec8d16e` ("fix: remove two debug
   PNGs that git add -A swept into main"). They remain in history. A screenshot
   of your own game is not a source file and is not "the assets as assets";
   showing the game is the purpose the packs were bought for. Not a violation.
4. **Colour leakage.** `trees_palette_table.py:10-13` states the rule ("This
   prints palette INDICES and Kubik's own family names. It never prints the
   pack's RGB"), and the generated `PACK_FAMILIES` block in
   `tree_palette.gd:110-165` bears it out: every cell is
   `<int>: &"<KUBIK_FAMILY_NAME>"`. I grepped the public repo for the pack RGBs
   the private tool's docstring quotes (`914E14`, `A36521`, `C46914`, `EEA711`,
   `FBD336`, `64422B`, `583823`) — **zero hits**. The 20 colours in
   `tree_palette.gd:52-90` are Kubik's own, each with its hex in a comment. The
   `.ktree` binaries and `.json` sidecars, which *do* carry the pack's palettes,
   live only in `Kubik-assets` and the ignored mount.

The gate: `.gitignore` last block —

> "Purchased, licensed art. Lives in the PRIVATE Kubik-assets repo and is
> mounted here by scripts/tools/sync_assets.py. Never commit its contents: the
> licences allow use in the game, not redistribution through a public repo. The
> game must always run with this directory absent."
> `assets/purchased/`

And the design backs it: `tree_models.gd:23-30` — "THE PUBLIC BUILD HAS NO
TREES, AND THAT IS THE DESIGN … CI proves it on every push by construction,
because CI has no assets repo."

### 4.3 The one real risk: the visibility of `Kubik-assets` itself

`Kubik-assets` tracks **6 906 files under `packs/`** — including **17
`.unitypackage` archives**, 116 `.vox`, 162 `.gltf`, 5 724 `.png` and 120 `.zip`
— pushed to `https://github.com/FrostyyTiger/Kubik-assets.git`, with 59 objects
in Git LFS and a 1.6 GB `.git`. The `.gitignore` there is one line
(`__pycache__/`); nothing under `packs/` is excluded.

That is every pack in its **delivered form**, which is exactly what all eight
records forbid redistributing ("no redistribution of the assets as assets
(source files, packs, or extractable form)"). The repo's own README says
**"PRIVATE — never make this repo public"** — but I cannot verify GitHub's
visibility setting from here. **Confirm on GitHub that
`FrostyyTiger/Kubik-assets` is private.** If it is private, nothing is
redistributed and the arrangement is sound. If it is not, the breach is total
and immediate — it would publish eight paid packs in downloadable form,
including the sellers' own `.unitypackage` files.

Two housekeeping items, neither a breach:

- **The eight blank seller fields are the real licensing debt.** Every term
  above is "as understood at purchase". If a seller's actual terms differ — some
  storefront licences forbid use in open-source projects even when the assets
  are not shipped, some require attribution — there is no record to check
  against. Filling in eight storefront URLs is an hour's work and it is the only
  thing standing between "we believe we are compliant" and "we can show we are".
- The three fonts are **SIL OFL** with the full licence text committed beside
  each (`JosefinSans-OFL.txt`, `Limelight-OFL.txt`, `PoiretOne-OFL.txt`).
  Correct for an MIT public repo.

---

## 5. Recommendation

*(order of work for the assets side, to serve ROUND-3-BRIEF)*

1. **Confirm `Kubik-assets` is private on GitHub; fill the eight blank seller
   fields.** Ten minutes. Everything else assumes it.
2. **Run `scripts/tools/sync_assets.py`.** The mount is five commits stale and
   holds no trees. The brief's forest is built and simply not mounted.
3. **Land the house generator in `Kubik-assets/tools/`**, outputs in
   `game/buildings/`. It exists and passes its own bible check
   (`previews/houses/REPORT_1.md`), but no repo holds the script or one output.
   Nothing else here matters if that is lost.
4. **Retune `tree_palette.gd`'s canopy ramp** to `#575d54 / #7e8986 / #9b9f81`.
   One file, no re-bake.
5. **Write the campfire**: 5 crossed logs, `#f5c05e` core, `#bf672d` edge,
   10 × 20 voxels. Brief item 3, and the tone's central object.
6. **Promote `purchased_view.gd` from `--viking` to the default, loading two
   templates.** The brief needs two players at the fire, as they are.
7. **Add a `BuildingModels` sibling to `TreeModels`.** D43 put buildings on the
   tree grain, so `trees_convert.py` and `.ktree` need no change; the game needs
   a loader and placement.
8. **Then the landmark gate** — settling the 256-voxel `.vox` cap first.

Buy nothing yet. Steampunk, interior props and plants serve no shot here.

*(187 words)*
