# Trees v3 - the forest becomes models, the whole way out

Written 2026-09-01, evening, from Marcel's rulings of the same evening (this
session, with the purchased tree pack surveyed voxel by voxel). Supersedes
`trees-v2.md` where the two disagree; what trees v2 got right is carried
forward by name. Target: **ganymede, one night, unattended, Opus, branch
`feat/trees-v3`** - but **NOT SCHEDULED** until (a) `feat/distance-v5` has
MERGED to main and its session has released the checkout, and (b) Marcel has
given the explicit go. The agent executing this plan reads **How to use this
document** before its first edit.

**What this night is for, in one line:** trees stop being terrain, stop being
generated, and stop being different creatures near and far - one library of
sculpted voxel trees, meshed through the game's own pipeline, instanced from
your boots to the fog.

## The rulings

All Marcel, 2026-09-01, evening session. Each is recorded so it does not have
to be re-derived; the older rulings they overturn are named.

1. **The purchased tree pack is the tree library.** Overturns trees-v2
   decision 5. That decision rejected the pack's *chamfered low-poly meshes*
   as a third surface language - and it was right, and it stands: the
   delivered `.gltf`/`.obj`/`.dae` files stay untouched in the assets repo.
   What was missed: the pack ships **55 MagicaVoxel `.vox` sources**. A vox
   file is not a surface language, it is a build plan - a voxel grid, the
   same species of data `FloraModels` and the character system already eat.
   Pulled through the game's own mesher and palette, the chamfer never
   exists and the third language never arrives. The artist's contribution is
   where the cubes go; the surface is ours.
2. **Whole-tree models.** Overturns trees-v2 decision 2 and hard rule 3.
   The pack's trunks - bent, tapered, root-flared - are half the art, and a
   0.5 m block pillar under a 12.5 cm-voxel canopy would be the ladder
   mismatch this epic exists to close. Trunks leave the block grid with the
   canopy. Consequences owned in this plan: per-tree colliders near the
   player (Stage 6), "is there a tree here" asks placement instead of the
   volume, and chopping - when it arrives - is fell-as-a-unit, not
   block-by-block. Nothing in this plan builds chopping; it only leaves the
   removed-set seam for it.
3. **Monumental native scale.** The pack's trees land at 17-28 m when their
   voxels sit on the model ladder's tree rung (4 voxels per block, 12.5 cm).
   Today's drawn trees are 13-21 m (26-42 m real / `world_scale` 4 x
   `tree_read_scale` 2.0), so this is a register shift of roughly +30% at
   the top, not an apocalypse - and it is the monumental north star, chosen
   with the numbers on the table. Models are authored at world size like
   characters; per-species height lives in the mapping table (Stage 3) and
   is Marcel's to retune by editing data.
4. **Geometry all the way out. No cards.** Replaces trees-v2 decision 6 and
   its Stage 5. There are no impostor billboards, no baked octahedral
   sheets, and no painted far ring: every drawn tree at every distance is an
   instanced mesh from the same library, at a coarser LOD rung the further
   out it stands. The far register comes from downsampled "fat voxel"
   versions of the same grids - the Distant Horizons move, applied to a
   model library. Two consequences bought deliberately: the near/far seam
   stops being a *kind* boundary (block tree vs cone) and becomes only a
   *resolution* boundary; and looking down from a peak works, which cards
   never did. If the fog line ever moves past today's 600 m, a
   merged-lump rung (many trees, one mesh per far cell) is the recorded
   next step - designed for, not built tonight.
5. **The block-tree system is deleted.** Not flagged off - deleted.
   `TreeSpecies`' shape half (whorls, ziggurats, lobes - some 2,400 lines),
   every `Block.LEAVES*`/`TRUNK*` write, and `FarTreeMeshes`' cone/stack
   shapes go. What survives, byte for byte: the placement half
   (`tree_placement.gd`), the species mix, the masks, and `decide()`'s
   contract to its four consumers. Block ids stay parked in `block.gd`
   (removing ids renumbers a wire format for zero benefit); only their
   writers die.
6. **The public build ships treeless, and that is the design.** The
   README's rule - "the game must always run without these assets present" -
   is satisfied by *running*: placement computes, the library loader finds
   no mount, nothing is planted, nothing crashes, every self-test passes.
   No fallback tree system is kept (Marcel: "not two"). CI has no assets
   repo, so the treeless build is proven green on every push by
   construction. What the public build loses with the trees - forest
   shade, wood-to-chop someday - is accepted and Marcel's to revisit.

## Decisions this plan makes

1. **One field, many rungs.** `FarTrees` stops being "the impostor ring"
   and becomes **`TreeField`** - the only tree renderer in the game. Its
   job (`far_trees_job.gd`) already walks the placement lattice in four
   stride bands from the voxel seam to the fog; tonight the walk extends
   inward to distance zero (there is no seam left to start from), and each
   band draws library meshes at that band's LOD rung instead of unit cones.
   Nearest band: LOD0, full 12.5 cm voxels. Middle bands: LOD1 (2x
   downsample). Outer bands: LOD2 (4x). Exact band-to-rung assignment is
   the executor's, decided on Stage 5's numbers and recorded. The
   ring-walk, per-sector frontier holes, fades, terrace footing lift
   (`FarFieldJob.terrace_offset()`), backdrop convergence, distance-v5's
   debounce and its budgeted-uploader routing are all inherited, not
   rewritten. One shipped fact about that debounce (distance lane,
   post-merge): the knob is `far_tree_step_m`, default 24.0, and it
   measures HORIZONTAL distance deliberately - the thrash it killed was a
   3D step retriggered by altitude changes. If the cadence is touched,
   the measurement stays horizontal.
2. **The library is baked offline, in the assets repo, by a Python tool.**
   `Kubik-assets/tools/trees_convert.py` (the `weapons_convert.py` /
   `derived/knight/vox_parse.py` precedents), run on a machine, committed
   with its output. Per variant it: parses the vox scene graph (up to 115
   parts, merged with offsets - `vox_parse.py` already does this);
   **dedupes colourway twins** (species 12-15 ship identical geometry in
   green/autumn/crimson/pink/snow palettes - hash the position set, keep
   one geometry, emit the palettes as tint tables; 55 files collapse to
   ~30 geometries); **hollows** (drop voxels with six filled neighbours -
   the 1.3 M-voxel canopies keep only their shells); **downsamples** to
   LOD1 (2x) and LOD2 (4x) by majority colour; **greedy-meshes** each LOD
   per palette index; and emits a compact binary of packed quads plus a
   JSON sidecar (dimensions, native height in metres at the 12.5 cm rung,
   origin, trunk radius and height for the collider, dominant canopy
   palette index, palette RGB list). Format details are the executor's;
   the constraints are: no Godot import dependence, quads not raw voxels
   (GDScript must assemble, never mesh - worker threads are serialised and
   meshing a 300 K-shell grid in GDScript is the known pathology), and
   palette INDICES in the geometry with RGB kept separate.
3. **Colour is mapped in the game, as data.** The tool ships original pack
   palettes; the repo owns `tree_palette.gd` (or a `.tres` - executor's
   choice) mapping each species' palette indices to authored Kubik colours,
   `Look.to_wire()` applied at mesh assembly exactly as `FloraModels` does.
   Retuning a canopy green is editing a table, not re-running a tool. The
   far colour pin (decision 7) and the swatch discipline both hang off this
   table, and it is the habit-1 surface the director could someday read
   (autumn as a fact, not a hex).
4. **`TreeModels` is a sibling of `FloraModels`, not a tenant.**
   `FloraModels`' ids are the top byte of a 64-bit flora identity and its
   removal/body-promotion machinery keys off them; trees get their own
   loader/cache class with the same shape (`available()`, `mesh_for()`,
   `triangles_for()`, mutex-cached lazy assembly) reading
   `res://assets/purchased/trees/`. `available() == false` is the treeless
   public build and must be a first-class, self-tested state.
5. **Placement does not move, but its baseline is reprinted.** `decide()`
   at `tree_placement.gd:297` returns the same dictionary to the same four
   consumers. Distance-v5 landed (58641b3) with the heightmap TILED
   (`heightmap_tile_blocks` 512) but its resolution step DEFERRED -
   `coarse_step` stays 4 blocks and the world is UNCHANGED on the same
   seed - so trees-v2's counts likely still hold. Stage 0 reprints tree
   count, species mix and spawn against post-v5 main anyway (the reprint
   is discipline, not doubt) and THAT tuple is this epic's invariant. Variant, rotation, jitter, tint and
   scale-jitter are hashed from the cell on NEW salts (232+; stay clear of
   the `SALT_CLUMP` series `217 + key*7919`) - never stored, never synced.
   No code may assume a heightmap cell size; it is a config knob after v5.
6. **`stamp_column()` becomes `cover_column()`.** The scan half survives -
   same footprint walk, same `max_reach` margin, same dedup discipline -
   but it writes nothing and returns what it always returned: the
   placement list and `canopy_cover`. Forest-floor shade
   (`ChunkMesher._under_canopy()`) keeps working untouched, because its
   input always came from the scan, not the voxels. The sky reserve above
   terrain (`worldgen_config.gd:1708`, 21+ m of empty chunks per column,
   reserved so canopies had somewhere to land) is REMOVED - columns end at
   the terrain again, which is chunks that stop existing and the single
   cheapest streaming win in this plan. `TreeSpecies.max_height()` /
   `max_reach()` survive only as far as the scan margin and the sky-reserve
   self-test need rewriting to agree.
7. **The far colour re-pins to the library.** `FarTreeMeshes.
   color_of_species()` reads `Block.color_of(row["leaves"])` - dead the
   night leaf blocks die. The new pin: each variant's dominant canopy
   colour through decision 3's table, computed once at load. The
   instance-colour divisor in `FarTreesJob._pack()` re-points at the same
   source. Near and far cannot drift because they are the same mesh under
   the same table - the drift *mechanism* is what got deleted.
8. **Collision and occupancy are explicit, near, and budgeted.** Within the
   sim radius, each placed tree gets a static trunk cylinder (radius and
   height from the library sidecar) through the same worker->main promotion
   path `FloraJob` uses for boulders. The canopy does not collide (it never
   meaningfully did - leaf blocks were `only_air` decorations). Flora's
   `_ground_allows()` / `_trees_near()` already ask placement, not blocks -
   they survive unedited. A `removed_trees` set (cell-keyed, the
   `_flora_removed` pattern) is threaded through `TreeField` and
   `cover_column()` but nothing writes to it tonight - it is the
   fell-as-a-unit seam, and the one mutation path will be its only writer.
9. **Materials: trees are scenery with sway.** A new `Look.tree_material()`:
   opaque-shader family, `fog_dark_mix = 0.0`, `contact_band = 1.0` (the
   `far_tree_meshes.gd:368` argument - a tree is scenery, a person is not),
   plus wind sway in `vertex()` weighted so crowns move and roots do not.
   Weight source is the executor's (vertex height over model height baked
   into COLOR alpha is the obvious slot - trees have no emissive) -
   recorded either way. Per-instance MultiMesh colour stays a *multiplier*
   for seasonal/altitude/grain tint, exactly the far ring's existing trick.
10. **The uploader contract is read, not guessed.** It shipped: class
    `FarUpload` in `scripts/world/far_upload.gd`, knob
    `far_upload_budget_ms` (F4, default 4.0), slices per frontier sector
    with an atomic swap - a build in progress shows the OLD complete far
    country, never a mixed one. `docs/status/distance-v5.md` ("Stage 1 -
    the uploader", "Where the uploader lives") records the placement
    decision and the enqueue contract; `FarTrees`' multimesh commits
    already flow through it and are the in-tree client example to crib.
    Stage 0 still READS that status doc before the first commit flows;
    every `TreeField` multimesh commit and every collider batch goes
    through `FarUpload` or under a measured 1 ms (v5 hard rule 6 is
    adopted here verbatim).
11. **No far-mesher edits. None.** `far_field.gd`, `far_field_job.gd`,
    `far_build.cpp`, `far_mesher.gd`, `heightmap.gd`: read-only to this
    epic. Forest lumps stamped into the far terrain were considered and
    rejected precisely because `FarFieldJob` is a parity-gated reference
    implementation - the GDScript `TreeField` is the cheaper seam and adds
    no third parity subject. (Agreed with the distance lane 2026-09-01;
    their hard rule 5 reserves `FarTrees` for this lane.)
12. **The mapping is provisional, photographed, and Marcel's to retune.**
    Stage 3 writes the species table: pack species -> game species slots
    (the `FOREST_WEIGHTS` names), biome/zone assignment, height, colourway
    set, spawn weights. Opus maps by shape and colour statistics (tall
    narrow 32w x 206h = conifer for the slopes; broad 166w = valley
    broadleaf; sprawling bare 09/10 = the krummholz/snag register; stumps
    16 = decoration on the shrub rung; snow-dusted variants to altitude;
    autumn to season hooks). The crimson and pink colourways ENTER the
    table with spawn weight 0 near spawn, parked as distance-strangeness
    candidates - present, inert, and Marcel's call to awaken. Every
    variant is photographed beside the player capsule in the gallery and
    every species in a tour; Marcel retunes by editing the table.

## What this buys

- One surface language from boots to fog, by construction - near and far
  are the same mesh at two rungs, so the "two games" seam cannot exist.
- Column generation loses its biggest cost (tree stamping was measured at
  roughly half - `column_job.gd:11`) and the sky reserve's chunks stop
  existing at all. Streaming gets faster by subtraction, in the same month
  the C++ mesher makes it faster by multiplication.
- The greedy chunk mesher loses its worst input (per-block A/B leaf
  scatter - `FloraModels:9`'s pathology) just before its C++ port is
  measured.
- Sculpted old-growth forests at monumental scale, with bare-winter, snow-
  dusted, autumn and fantasy colourways as DATA, feeding season, altitude
  and someday the strangeness axis - without one new mesh.
- Wind sway, per-instance tint, free rotation and scale jitter - everything
  the block grid forbade.
- ~30 geometries x 3 LODs assembled once at load; a whole forest is a few
  dozen MultiMesh draw calls.

## What it costs

- **Chopping a tree block by block is gone**, and wood with it, until
  fell-as-a-unit arrives through the mutation path. Accepted (ruling 2).
- **The public build has no trees. At all.** Accepted and CI-proven
  (ruling 6).
- The pack covers 11 of 16 species folders with vox sources; the 5
  mesh-only species (01-04, 06) are NOT imported - chamfer stays out.
  ~30 geometries is nearly double the 19 the old ring proved sufficient,
  but variety within a species now leans on colourways + rotation + scale
  jitter, and that trade was already accepted in trees-v2 decision 4.
- Triangle budget is a real risk at LOD0: a hollowed 1.3 M-voxel canopy is
  still a big shell. Stage 1 measures per variant BEFORE any game code
  consumes the library; the tool's downsample knob is the escape valve and
  using it on the giants is a recorded decision, not a failure.
- 21 m trees darken and dominate valleys that were tuned around 13-21 m.
  The tour will show it; retuning is table edits, and Marcel sees the
  shots.

## Hard rules

1. **Placement does not move** - against the Stage 0 post-v5 baseline:
   same tree count, same species mix, same spawn, reprinted at every
   stage. A stage that moves a tree's position has a bug, not a feature.
2. **Determinism is not negotiable.** Variant, rotation, tint, scale
   jitter: hashed from the cell on new salts, never stored, never synced,
   identical on both machines.
3. **Both states are first-class.** Every stage ends with the full
   self-test green TWICE: with the purchased mount present, and with it
   absent (moved aside). The absent leg is the public build.
4. **`godot --headless --path . scenes/selftest.tscn`** at every stage
   boundary, exit non-zero on failure; CI selftest green on the branch
   before merge (CI is the assetless leg by construction).
5. **No look change ships by editing a `WorldgenConfig` default** - the F4
   panel's `user://worldgen.tres` shadows defaults forever. New properties
   only, classified deliberately: shape knobs into `PROPERTIES` (the join
   handshake), look knobs into `LOCAL_PROPERTIES`.
6. **Touch only this lane's files.** New files, `TreeField` (née
   `FarTrees`) and its job, `tree_placement.gd`'s scan half,
   `tree_species.gd`, `column_job.gd`'s stamp call site, gallery/tour/
   selftest, and the assets repo. The far field, both far meshers, the
   heightmap, flora's own systems: read-only (decision 11).
7. **No frame-thread work without a budget** - v5's rule, adopted: every
   upload flows through the v5 uploader or is measured under 1 ms and
   recorded.
8. **Two repos, honest commits.** The tool and the baked library commit to
   Kubik-assets (private); code and tables commit to Kubik (public). No
   pack-derived bytes - geometry, palettes, sidecars - may enter the
   public repo. If ganymede cannot push Kubik-assets, the library is left
   in the mount, the tool is committed, and the status doc says so
   plainly.

## Sequencing

- **After `feat/distance-v5` merges - SATISFIED 2026-09-01:** merged to
  main at 58641b3, all gates green, and the morning's cross-box hash ran
  (`docs/status` a684445). This plan consumes its uploader and debounce;
  its status doc is required reading (decision 10). Note `build.yml` (the
  Windows exe export) was red on the merge commit - a pre-existing
  condition of main, not this lane's gate; trees-v3 gates on the selftest
  workflow.
- **Ganymede has ONE working tree.** Do not start while the distance
  session holds it; do not resume the idle creatures-v1 tmux session,
  which holds the checkout hostage if touched. (Both flagged by the
  distance lane, 2026-09-01.)
- **Kubik-assets must be on ganymede** - cloned as a sibling
  (`../Kubik-assets`), `python scripts/tools/sync_assets.py` run, BEFORE
  the night starts. It is a private repo: Marcel confirms the box has
  auth. Without it the night cannot run - Stage 0 checks and stops.
- **The C++ chunk mesher port (rung 2): well before or well after**,
  trees-v2's argument verbatim - this epic deletes the chunk mesher's
  worst input AND its trunk blocks, so interleaving invalidates the
  port's numbers.
- **Against the Next 3:** trees jump the queue again, on trees-v1's own
  precedent - the art direction is cheapest before the creature trio,
  look v3 and Sites v1 are authored in front of these forests. Marcel
  scheduled it explicitly (2026-09-01). Look v3's tree scope is largely
  DISCHARGED by this epic; its plan should be trimmed against it.

---

## How to use this document

**Environment.** Ganymede, headless, `~/bin/godot` (4.7.2), `~/godot-cpp`
built (distance v4 Stage 0), scons via `~/bin/scons`. After the distance
session releases the box:

```bash
G=~/bin/godot
cd ~/Kubik
git fetch && git checkout main && git pull        # post-v5 main
ls ../Kubik-assets/packs/voxel-stylized-trees/ || exit 1   # assets or stop
python scripts/tools/sync_assets.py
git checkout -b feat/trees-v3
$G --headless --path . --import
cd gdext && ~/bin/scons platform=linux target=editor \
  custom_api_file=$HOME/godot-cpp/extension_api.json -j$(nproc) && cd ..
$G --headless --path . -s gdext/check.gd          # class exists: true
```

Tours via `xvfb-run -a`; outputs under `build/`. The tool runs with the
system python3 (stdlib only - `vox_parse.py` needs nothing).

**Reading order before the first edit:** this file whole; `CLAUDE.md`;
`docs/plans/trees-v2.md` (the superseded plan - its diagnosis, hard rules
and Stage 0 audit list are still the map); **`docs/status/distance-v5.md`
WHOLE** (the uploader's recorded owner and enqueue contract, the new
heightmap facts, what red gates if any were left); `scripts/world/flora/
tree_placement.gd` header and `decide()`; `scripts/world/flora/
tree_species.gd:53-109` (the writers being retired) and `:442-535`
(`params_for()`); `scripts/world/flora/far_trees.gd`,
`far_trees_job.gd`, `far_tree_meshes.gd` TOP TO BOTTOM (the machine being
promoted); `scripts/world/flora/flora_models.gd` header, `build_mesh_from`
and `material()`; `scripts/world/flora/flora_job.gd` (the promotion and
pack patterns); `scripts/world/column_job.gd`; `scripts/character/
vox_loader.gd` (the in-repo vox reader, reference for the tool's ground
truth); `Kubik-assets/derived/knight/vox_parse.py` and `Kubik-assets/
tools/weapons_convert.py` (the tool's parents); `Kubik-assets/LICENSES/
voxel-stylized-trees.md`; `scripts/tools/selftest.gd` tree/flora tests;
`scripts/tools/model_gallery.gd` and `screenshot_tour.gd` headers;
`STATUS.md` current items.

**Stage discipline:** a stage is a commit (or several), every stage ends
with the self-test green BOTH WAYS (hard rule 3) and a push, and a stage
that cannot meet its gate STOPS THE LANE - status doc up to that point, no
improvising past red. Kubik-assets commits happen at the stage that
produces them, so a torn night still leaves both repos coherent.

---

## The stages

**Stage 0 - the instruments, the audit, and the post-v5 baseline.**
Bring-up above. Read `docs/status/distance-v5.md`; record the uploader
owner and enqueue contract in this epic's status doc. Reprint against
post-v5 main: tree count / species mix / spawn on the canonical seed
(`worldgen_probe`), chunks and load wall at spawn, sprint frame profile,
`[FarTrees]` rebuild numbers, tour set `--label trees-v3-before`, gallery
`--label trees-v3-before`. Grep-audit every consumer of
`TreeSpecies.TREE_BLOCKS` / `is_tree_block()` / `Block.LEAVES*` /
`TRUNK*` and write the kill-or-keep list into the status doc (trees-v2
Stage 0's audit, executed at last). Gate: self-test green both ways,
untouched; every number in the status doc with its box and target.

**Stage 1 - the tool, and the budget.** `Kubik-assets/tools/
trees_convert.py` per decision 2: parse (via `vox_parse.py`), dedupe
colourways, hollow, LOD 1x/2x/4x, greedy-mesh per palette index, emit
binary + sidecar into `Kubik-assets/game/trees/<species>/`. Print the
night's first table: per variant, voxels -> shell voxels -> quads at each
LOD. GATE ON A NUMBER before any Godot code exists: worst LOD0 variant
under 40,000 triangles (the boulder precedent 35,964 is the order of
magnitude the game has already accepted for one big model); if a giant
busts it, downsample that species at the tool (recorded per species in
the sidecar) rather than carrying a monster into Stage 2. Commit tool +
library to Kubik-assets; `sync_assets.py`; re-run; confirm the mount.

**Stage 2 - `TreeModels`, the palette table, and the gallery.** The
loader/cache per decision 4; `Look.tree_material()` per decision 9
(sway can be a stub uniform at 0 until Stage 8); the palette-index ->
Kubik-colour table per decision 3, first pass mapped toward the existing
leaf/bark colour families in `block.gd` so the world's greens stay one
family. Extend the model gallery: `--trees` photographs every variant at
1:1 beside the player capsule, every LOD beside its LOD0. Gates:
self-test both ways (absent leg: `TreeModels.available()` false, gallery
`--trees` prints "no library" and exits 0); triangle counts at load match
Stage 1's table; gallery sheets on disk for Marcel.

**Stage 3 - the mapping table.** Decision 12. One data file in the PUBLIC
repo (species slots, biome/zone, heights, colourway sets, spawn weights,
collider dims read from sidecars; crimson/pink at weight 0 near spawn) -
the pack names never appear in code, only in this table. Wire
`FOREST_WEIGHTS`' species names to table rows. Gate: table lints against
the mounted library (every referenced variant exists; every vox-backed
species referenced or explicitly benched in a comment); placement
baseline unchanged (nothing consumes the table yet).

**Stage 4 - one species end to end, near.** The pattern-proving stage.
`TreeField` (rename lands in Stage 5; tonight `FarTrees` grows an inner
band) draws the valley broadleaf's LOD0 instances over the voxel radius
while the block stamp still runs for every OTHER species - two systems
coexist for one night, deliberately, so a tour shows old and new side by
side. `cover_column()` split out per decision 6 for this species only.
Gates: self-test both ways; the A/B tour pair; instance count for the
species equals its placement count; no upload over budget (decision 10's
plumbing proven here, on the smallest case).

**Stage 5 - the whole field, every band.** All species to the library;
the walk extended to distance zero; band -> LOD rung assignment chosen on
measured triangle totals and recorded; cones retired; colour re-pin per
decision 7; instance-colour divisor re-pointed; fades and frontier holes
re-verified; `FarTrees` renamed `TreeField` (file, node, log tags, F4
labels - one commit, no behaviour). Gates: self-test both ways; standing
60 s -> 0 rebuilds (v5's gate, still true under the new meshes); sprint
rebuild count bounded and recorded; draw calls counted (expect ~30
geometries x live LOD rungs, high tens); band-boundary tour shots at each
rung crossing, plus one FROM THE HIGHEST SUMMIT LOOKING DOWN (the shot
cards could never survive); worst frame in a sprint recorded vs Stage 0.

**Stage 6 - the body: colliders, occupancy, the removed-set seam.**
Decision 8. Trunk cylinders within the sim radius via the flora
promotion path; `removed_trees` threaded, unwritten; the audit list's
kill-or-keep executed for gameplay queries (everything answers from
placement now). Gates: self-test both ways plus a new test - walk into a
trunk, be stopped; body-probe count matches placed trees in radius;
physics cost of the collider ring measured and recorded.

**Stage 7 - the deletion.** Ruling 5, in one commit that is almost all
red: shape functions, block writers, `stamp_column()`'s writer half, the
sky reserve (`worldgen_config.gd:1708` and `TreeSpecies.max_height()`
reconciled - the self-test that asserts they agree is rewritten to the
new, smaller truth), cone builders, `color_of_species()`'s block read.
Parked block ids stay. The `tree borders` self-test is replaced by its
canopy-aware siblings: `cover determinism` (cover_column twice = same
cover, across a border = same trees) and `registry determinism`
(decide() over a fixed rect hashes equal on repeat). Gates: self-test
both ways; chunks per column at spawn (expect the sky reserve's chunks
GONE - record the count against Stage 0); column generation ms (expect
roughly half - `column_job.gd:11`'s claim, finally cashed); load wall at
spawn vs Stage 0; grep proves no live reference to deleted symbols.

**Stage 8 - sway and the tint channels.** Decision 9's sway weighted by
the chosen channel; seasonal/altitude tint hooks: instance colour
multiplier driven from the mapping table's colourways (snow-dust above
the treeline band, autumn as a table row Marcel can flip - both are
DATA, zero new meshes). Gates: self-test both ways; a sway-on/off tour
pair; swatch-gate discipline - the canopy family's authored hexes land
on screen within the character gallery's 6-unit tolerance (extend the
sheet or add a tree swatch strip - executor's choice, recorded).

**Stage 9 - the numbers, after.** Interleaved ABAB three runs each:
load wall, chunks at spawn, column ms, sprint worst frame, TreeField
rebuild walls, draw calls, static memory, triangle totals per band.
Stream probes both divs, holes 0, both legs. Full tour `--label
trees-v3-after` + the before/after pairs composed. Full self-test both
ways, plus CI green on the branch (the assetless proof).

**Stage 10 - the landing.** `docs/status/trees-v3.md` in the repo's
voice: what shipped, the before/after table, what got worse, the tool's
per-variant table, what is parked (merged-lump rung, fell-as-a-unit,
crimson forests). `DESIGN.md`: the ladder table gains its tree row at
4/block WITH the whole-tree amendment, the read-against table's tree row
retired (models are world-size now), § World's monumental register gains
the forest sentence. `trees-v2.md` banner: superseded by this plan, with
its rulings' fates listed. `TODO.md` + `docs/IDEAS.md` trees lane
updated; look v3's tree scope trimmed. STATUS.md entry at top. Merge to
main ONLY with every gate green including CI; red = branch pushed +
honest status doc, no merge.

## Open questions the executor decides on numbers (and records)

1. Band -> LOD rung assignment, and whether the innermost band wants
   stride 1 at LOD0 all the way to the seam's old 1.6x radius or a
   nearer cut.
2. The hollowing threshold and whether LOD2 wants 4x or 8x for the
   giants - Stage 1's table decides.
3. Sway weight channel (COLOR alpha vs a custom data float).
4. Collider granularity: one cylinder per tree always, or capsule for
   the leaners (Tree 09/10's sprawl) - body-probe cost decides.
5. Whether `params_for()` slims to placement-only fields now or in a
   later cleanup - it must not change `decide()`'s output shape either
   way.
6. The library binary format (packed quads layout, endianness, version
   byte) - constraint list in decision 2.

## What the morning should find

`main` (or, failing gates, `feat/trees-v3` and an honest status doc)
with: one tree system where there were two, drawing sculpted monumental
forests from the player's boots to the fog with no seam a walking eye
can find and no card anywhere; the public build treeless, green, and
proven so by CI; columns that end at the terrain and generate in half
the time; a species/colour/season table Marcel can retune over coffee;
gallery sheets of every variant beside the capsule and tour pairs from
the valley floor and the summit; the assets repo carrying the tool and
the baked library; and the block-tree code - three thousand lines that
taught this game what a tree is - deleted with its lessons written down.
