# Distant Horizons: how it renders an epic vista of blocks

Research for distance v3, 2026-08-31 — the day the world went unbounded and
Marcel named the Distant Horizons look as the feel he is chasing. Produced by
an Opus research agent that cloned both DH repositories at `main` and read the
mechanisms out of the source rather than out of blog posts. Kept verbatim
below, method note and all.

**Method note.** Almost every claim below is read directly from source, not
from prose. Cloned at `main` (2026-08-31):

- `https://gitlab.com/distant-horizons-team/distant-horizons-core` — version-independent core (552 Java files, all GLSL)
- `https://gitlab.com/distant-horizons-team/distant-horizons` — Minecraft-facing wrappers and GL/Blaze3D backends
- `https://gitlab.com/distant-horizons-team/distant-horizons.wiki.git` — the user/dev wiki

File paths below are relative to those clones. Where a number has no file path
it is either from the wiki, a web source, or the researcher's own arithmetic —
and it says which. **Anything unconfirmed is explicitly flagged.**

One framing point up front, because it reorders everything else: DH's current
build (3.0.0-b) **does not render distant terrain as flat colour**. It has a
block-texture atlas that multiplies a per-block detail texture onto the LOD
colour, UV'd off the block grid. That is very close to the "per-block colour
fleck" we suspect is the key, and it is implemented as a *ratio* texture
specifically so it does not disturb the average colour at distance. Section 2
is the important one.

---

## 1. LOD data structure and generation

### Mechanism

**Two separate representations.** DH keeps a *full data* form (source of
truth, on disk) and transforms it into a *render data* form (colour resolved,
ready to mesh). They have different 64-bit packings.

**Full data point** — `core/util/FullDataPointUtil.java`:

```
SL SL SL SL  BL BL BL BL   <- top bits
MY MY MY MY  MY MY MY MY
MY MY MY MY  HI HI HI HI
HI HI HI HI  HI HI HI HI
ID ID ID ID  ID ID ID ID
ID ID ID ID  ID ID ID ID
ID ID ID ID  ID ID ID ID
ID ID ID ID  ID ID ID ID   <- bottom bits
```

- `ID` (32 bits) — index into a per-section `FullDataPointIdMap` of **(blockstate, biome) pairs**. Not a colour.
- `HI` (12 bits) — **height of this run in blocks**
- `MY` (12 bits) — min Y relative to level minimum
- `BL`/`SL` (4 bits each) — block light, sky light

So a column is a **run-length-encoded vertical stack**, sorted top-down, not a
single surface height. Overhangs, caves and floating islands survive by
construction. `FullDataSourceV2.dataPoints` is `LongArrayList[]` — one
variable-length list per (x,z).

**Render data point** — `core/util/RenderDataPointUtil.java`:

```
BM BM BM BM  A A A A     <- 4-bit Iris material id, 4-bit alpha
R R R R R R R R
G G G G G G G G
B B B B B B B B
H H H H H H H H          <- 12-bit column max Y
H H H H D D D D
D D D D D D D D          <- 12-bit column min Y
BL BL BL BL  SL SL SL SL
```

Colour is **baked per data point** at transform time (8-8-8 RGB, alpha
quantised to 4 bits).

**Sections and the quadtree.** `core/pos/DhSectionPos.java`:

> "A section contains 64 x 64 LOD columns at a given quality."
> "Too small, and we'll have 1,000s of sections running around... Too big, and
> the LOD dropoff will be very noticeable. With those thoughts in mind we
> decided on a smallest section size of 64 data points square (IE 4x4 chunks)."

- `SECTION_MINIMUM_DETAIL_LEVEL = 6`; `FullDataSourceV2.WIDTH = 64`
- Section detail levels run **6 → 15** (`LEAF_SECTION_DETAIL_LEVEL` = 6, `ROOT_SECTION_DETAIL_LEVEL` = 6 + `REGION_DETAIL_LEVEL(9)` = 15, in `core/file/fullDatafile/V2/FullDataSourceProviderV2.java`)
- Data detail level = section detail − 6, so **10 levels: cell sizes 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 blocks**
- **A section is always 64×64 data points at every level.** Only the world
  size of a cell changes. Section world width = 64 × 2^d: 64, 128, 256, 512,
  1024 … 32,768 blocks.

This constant-cells-per-section property is the load-bearing architectural
decision — see §3.

**Detail drop-off is logarithmic in distance.**
`core/render/QuadTree/LodQuadTree.java:1160-1180`:

```java
this.detailDropOffDistanceUnit = horizontalQuality.distanceUnitInBlocks * LodUtil.CHUNK_WIDTH;
this.detailDropOffLogBase = Math.log(horizontalQuality.quadraticBase);
...
int detailLevel = (int)(Math.log(blockDistance / this.detailDropOffDistanceUnit) / this.detailDropOffLogBase);
```

With `EDhApiHorizontalQuality` (`api/enums/config/EDhApiHorizontalQuality.java`)
— `MEDIUM(quadraticBase 2.0, distanceUnitInBlocks 12)`, so the unit is
12×16 = 192 blocks. **Researcher's arithmetic**, from those constants:

| distance (blocks) | data detail | cell size |
|---|---|---|
| < 192 | 0 | 1 block |
| 192 – 384 | 0 | 1 block |
| 384 – 768 | 1 | 2 blocks |
| 768 – 1536 | 2 | 4 blocks |
| 1536 – 3072 | 3 | 8 blocks |
| 3072 – 6144 | 4 | 16 blocks |

`HIGH` uses base 2.2 and unit 256, `EXTREME` base 2.2 unit 320 — so the rings
get wider, not differently shaped.

**Vertical detail is a separate, level-dependent budget.**
`api/enums/config/EDhApiVerticalQuality.java` gives max vertical slices
*indexed by data detail level*:

```
HEIGHT_MAP  {1,   1,   1,  1,  1,  1,  1,  1,  1,  1, 1}
LOW         {4,   4,   4,  3,  3,  3,  3,  3,  3,  3, 1}
MEDIUM      {6,   6,   6,  4,  4,  4,  4,  4,  4,  4, 1}   <- default
HIGH        {16, 16,  12, 12,  8,  8,  8,  8,  8,  8, 1}
EXTREME     {64, 32,  32, 32, 16, 16, 16, 16, 16, 16, 1}
PIXEL_ART   {512,256, 128, 64, 32, 32, 16, 16, 16, 16, 1}
```

So by default a near LOD column carries **6 vertical slices**, a far one 4,
and the coarsest level exactly 1 (a heightmap). `HEIGHT_MAP` mode makes the
whole field top-surfaces-only — DH ships our current approach as its lowest
quality setting.

When a column has more runs than the budget,
`core/util/RenderDataPointReducingList.java` reduces it. It is a doubly-linked
structure sorted **simultaneously by height and by slice size**, and
`reduce(target)` runs, in order: `mergeVerySmallConnectedSegments`,
`mergeConnectedSegments`, `removeLeastImportantSegments`,
`forceBottomToMerge`. i.e. **merge the least visually significant gaps first**,
not uniform decimation.

**Cave and occlusion culling.**
`core/dataObjects/transformers/FullDataOcclusionCuller.java` drops runs fully
enclosed by opaque neighbours in ±X/±Z and above/below. Separately in the
transformer (`FullDataToRenderDataTransformer.setRenderColumnView`), a run
with sky light 0, below a config height, not at the top or bottom of the
column, is merged away — DH assumes "no skylight ⇒ underground ⇒ invisible".
Explicitly disabled for dimensions with a ceiling and for The End, because
overhangs over the void break the heuristic.

### Where the data comes from

Three sources, all converging on the same `FullDataSourceV2`:

1. **Loaded vanilla chunks.** `core/dataObjects/transformers/LodDataBuilder.createFromChunk()`.
2. **DH's own "Distant Generator"** — `core/generation/DhWorldGenerator.java`,
   driven by `EDhApiDistantGeneratorMode`: `PRE_EXISTING_ONLY`, `SURFACE` (no
   caves/trees/structures), `FEATURES` (default; structures, chunks *not*
   saved to MC region files), `INTERNAL_SERVER` (asks the server, does save).
   The wiki notes `FEATURES` is why "trees/structures suddenly
   appear/disappear when I fly around" — the feature generator lacks
   neighbour context.
3. **Server-supplied** over DH's own protocol (`core/multiplayer`,
   `core/network`), when DH is installed server-side.

DH bakes its **own lighting** rather than relying on MC's:
`core/generation/DhLightingEngine.java`, "roughly based on Starlight's
technical documentation."

### Storage on disk

**SQLite**, not flat files. `core/sql/`, schema in
`core/src/main/resources/sqlScripts/`:

```sql
CREATE TABLE FullData (
     DetailLevel TINYINT NOT NULL  -- LOD detail level, not section detail level IE 0, 1, 2 not 6, 7, 8
    ,PosX INT NOT NULL
    ,PosZ INT NOT NULL
    ,MinY INT NOT NULL
    ,DataChecksum INT NOT NULL
    ,Data BLOB NULL
    ,ColumnGenerationStep BLOB NULL
    ,ColumnWorldCompressionMode BLOB NULL
    ,Mapping BLOB NULL
    ,DataFormatVersion TINYINT NULL
    ,CompressionMode TINYINT NULL
    ,ApplyToParent BIT NULL
    ,LastModifiedUnixDateTime BIGINT NOT NULL
    ,CreatedUnixDateTime BIGINT NOT NULL
    ,PRIMARY KEY (DetailLevel, PosX, PosZ)
);
```

Later migration `0090` adds `NorthAdjData` / `SouthAdjData` / `EastAdjData` /
`WestAdjData` BLOBs, with the rationale in the script itself: *"storing
adjacent data (IE a single line of data on the +X/-X/+Z/-Z axis) allows for
significantly reduced render loading times since we only have to handle part
of the adjacent data source vs all of it."* Border face culling without
paging in four neighbour sections.

Blob compression is selectable (`api/enums/config/EDhApiDataCompressionMode.java`),
with the authors' own measurements in the Javadoc: `LZ4` ratio 0.4513,
`Z_STD_BLOCK` ratio 0.2606 at 2.1 ms read / 4.9 ms write per DTO, `LZMA2`
slowest/smallest. Separately `EDhApiWorldCompressionMode` is *lossy*:
`MERGE_SAME_BLOCKS` (every change recorded) vs `VISUALLY_EQUAL` (hidden
blocks like ores dropped) — the wiki attributes visible "grid lines"
artefacts to `VISUALLY_EQUAL`.

Sources: repo files as cited; wiki `1-user-guide/.../General.md` ("Where is
LOD data stored").

---

## 2. Colour — where a far block's colour comes from

The question that matters most to us, traced through the whole chain.

### 2a. Base colour per blockstate: alpha-weighted average of the texture, in linear space

`dhmain/common/.../wrappers/block/ClientBlockStateColorCache.calculateColorFromTexture()`:

```java
red   += srgbToLinearTable[r] * a * scale;
green += srgbToLinearTable[g] * a * scale;
blue  += srgbToLinearTable[b] * a * scale;
alpha += a * scale;
...
tempColor = ColorUtil.argbToInt(
        alpha / count,
        linearToSrgb((float)(red   / (double)alpha)),
        linearToSrgb((float)(green / (double)alpha)),
        linearToSrgb((float)(blue  / (double)alpha)));
```

Three details worth stealing: the average is done in **linear light** and
converted back (the comment `//gamma correction is complicated`, and a note
that the sRGB conversion was "suggested by IMS from the Iris/Sodium team");
it is **alpha-weighted**, so cutout textures like fences don't average toward
black; and there are per-block-class overrides via `EColorMode` — `Leaves`
forces `a=255` on any non-zero pixel, `Flower` weights saturated pixels by
`FLOWER_COLOR_SCALE` so a red flower reads red rather than mostly-green-stem.

### 2b. Biome tint applied per block position, not per blockstate

`ClientBlockStateColorCache.getColor(biome, dataSource, blockPos, ...)` only
runs the tint path when `needPostTinting` (derived from the baked quad's tint
index). It uses MC's own `BlockColors`/`BlockTintSource` resolver at the
actual world position, with a DH-side cache (`TintWithoutLevelOverrider`) to
avoid touching a loaded level. So grass and foliage get real per-position
biome blending, including biome-edge interpolation.

The call site is `FullDataToRenderDataTransformer.setRenderColumnView`, which
computes `mutableBlockPos` for **every data point in every column**:

```java
color = levelWrapper.getBlockColor(mutableBlockPos, biome, fullDataSource, block);
```

### 2c. Coarsening does NOT average colour — it takes a majority vote on block ID

This is the mechanism we were looking for. In `FullDataSourceV2`, merging
four fine columns into one coarse column walks the union of Y transitions,
samples each of the 4 sub-columns **at the slice midpoint**, and then:

```java
// Determine merged values for this slice
int id = determineMostCommonValueInColumnSlice(mergeIds, inputDataSource.mapping);

// Only average light from sub-columns that match the winning ID.
// Otherwise light from an outvoted block (ie: surface water) can bleed
// into the merged datapoint (ie: sand under the water),
// causing incorrect bright spots.
byte blockLight = (byte) determineAverageValueInColumnSliceWithId(mergeBlockLights, mergeIds, id);
byte skyLight   = (byte) determineAverageValueInColumnSliceWithId(mergeSkyLights,  mergeIds, id);
```

`determineMostCommonValueInColumnSlice` is a plain mode over 4 values, with
one rule: **air never wins** —

```java
if (mapping != null && mapping.getBlockStateWrapper(value).isAir())
{
    // always overwrite air to prevent holes in hollow structures
    continue;
}
```

Consequences, and these are exactly the "doesn't average to mush" answer:

- A coarse cell is always **one real blockstate**, so its colour is a real
  block's colour, at full saturation. Colours never regress toward the mean.
  Two adjacent coarse cells over a mixed forest floor can be *leaves* and
  *dirt*, not two shades of brown-green.
- Because the vote is per Y-slice sampled at midpoints and then
  re-run-length-encoded (`if (id != lastId || blockLight != lastBlockLight
  || skyLight != lastSkyLight)` starts a new run), vertical structure and
  colour banding survive.
- Only **light** is averaged, and only among the sub-columns that voted for
  the winner.
- Ties fall through to `value0`, i.e. the first sub-column — deterministic
  but arbitrary. That arbitrariness is itself a source of high-frequency
  variation, which reads as texture rather than as error.

Note also the *other* direction: `downsampleFromOneAboveDetailLevel()`
(despite the name) **copies coarse data into finer sections** as a
placeholder when fine data is missing, tagged
`EDhApiWorldGenerationStep.DOWN_SAMPLED`, and only into columns that are
currently empty. That's the "LODs load blurry then sharpen" behaviour in the
3.0.0-b changelog.

### 2d. The block texture atlas — per-block detail as a *colour ratio*

New in 3.0.0-b, and the strongest single idea in DH for our problem.
`core/dataObjects/render/textures/BlockTextureRegistry.java`:

> "Tile pixels are stored as color ratios relative to the LOD's average color
> instead of absolute colors (a gray value of 128 means the base color is
> used without modification). This way the current tinting/shading pipeline
> and the average color seen at a distance is unchanged."

- Every blockstate **face** gets a global tile id. `TILE_HEIGHT_AND_WIDTH = 16`,
  RGBA, `MAX_TILE_COUNT = 65_536` (ids live in 16 vertex bits).
- `convertColorsToDifferenceRatios()` averages **only the visible pixels**
  ("otherwise cutout textures (IE fences) would have overly dark averages"),
  then encodes each texel as `Math.round((channel / average) * 127.5f)` — so
  128 ≈ ×1.0, 255 ≈ ×2.0, clamped.
- A tile where every texel is 128 is discarded entirely
  (`anyPixelDiffersFromAverage`), falling back to `UNTEXTURED_ID = 0` which
  renders flat.
- Atlas layout: `TILES_PER_ROW = 256`, so "256 tiles × 16 pixels = a constant
  4096 pixel wide texture", growing 16 rows (~1 MB) at a time
  (`core/render/AbstractBlockTextureAtlas.java`).

The fragment shader (`shaders/terrain/gl/frag.frag`):

```glsl
ivec2 atlasSize = textureSize(uBlockAtlas, 0);
vec2 tileOrigin = vec2(float(vTextureTileId % 256u), float(vTextureTileId / 256u)) * 16.0;
vec2 uv = (tileOrigin + blockFaceUv() * 16.0) / vec2(atlasSize);
vec4 tile = texture(uBlockAtlas, uv);

// Tile color value of gray, 128 ... means the LOD will use it's base color.
vec3 clampedColor = clamp(fragColor.rgb * (tile.rgb * 2.0), 0.0, 1.0);
fragColor.rgb = mix(fragColor.rgb, clampedColor, tile.a);
```

and crucially the UV comes from `fract(vBlockPos)` where
`vBlockPos = vec3(vPosition.xyz)` is the **integer block coordinate** (vertex
shader), switched per face by `vNormalIndex`:

```glsl
vec2 blockFaceUv() {
    vec3 pos = fract(vBlockPos);
    switch (vNormalIndex) {
        case 0u: return vec2(pos.x, 1.0 - pos.z); // down
        case 1u: return vec2(pos.x, pos.z);       // up
        ...
    }
}
```

**So the texture tiles once per world block, on a greedy-merged quad that may
be up to 2048 blocks wide.** One quad, N×M block texels. That is the "true
block-grid surface reading" we described, obtained for free from a `fract()`
in the fragment shader.

Which data point supplies the tile id:
`FullDataToRenderDataTransformer.applyTextureSetIds()` walks back into the
*full* data to find the block at the render point's **top** — "merged data
points keep their top block's color, keeping the texture consistent with the
color it multiplies" — with a documented hack for snow so snow-over-grass
doesn't texture as grass.

Storage on the render side is palettised: `ColumnRenderSource` holds
`ByteArrayList textureSetPaletteIndices` parallel to the data points,
indexing a per-section `ShortArrayList texturePalette` capped at
`MAX_TEXTURE_PALETTE_SIZE = 256`. One byte per data point instead of two.

Defaults (`core/config/Config.java`, `Graphics.Texture`):
`enableTexturedLods = true`, `maxTexturedLodDetailLevel = 2` (min 0, max 4),
commented:

> "Only applies to high detail LODs where the texture is actually visible,
> distant LODs always use flat colors."
> "At higher detail levels each LOD covers multiple blocks, which can
> essentially make textures smaller than a pixel and therefore invisible."

So real textures cover data detail 0–2 (cells of 1, 2, 4 blocks ⇒ roughly
the first ~1536 blocks at MEDIUM), and beyond that DH falls back to flat
colour + the noise texture (§4).

### 2e. Directional face shading

`core/dataObjects/render/bufferBuilding/ColumnBox.java` bakes MC's own
per-direction shade multipliers into vertex colour at build time:

```java
color = ColorUtil.applyShade(color, clientLevelWrapper.getShade(direction));
```

(In vanilla MC these are 1.0 up, 0.5 down, 0.8 north/south, 0.6 east/west —
**not verified that DH's wrapper returns exactly those**, but it delegates to
MC's level.) This is the cheapest and most effective single thing making the
far field read as cubes rather than a surface.

---

## 3. Rendering and performance

### Mechanism

**Greedy meshing, two passes, colour-and-texture-equality gated.**
`core/dataObjects/render/bufferBuilding/LodQuadBuilder.java`:

```java
/** Uses Greedy meshing to merge this builder's Quads. */
public void mergeQuads()
```

For each of the 6 face directions it sorts and merges along
`BufferMergeDirectionEnum.EastWest`, then — **only for up/down faces** — a
second pass along `NorthSouthOrUpDown`. So top surfaces get 2D rectangle
merging, side faces get 1D strip merging. There is also a "premerge" attempt
against the last-emitted quad during construction (`premergeCount`).

`BufferQuad.tryMerge()` gates on same direction, same perpendicular axis,
adjacency, non-overlap, and a hard `NORMAL_MAX_QUAD_WIDTH = 2048` (dropping
to `MAX_QUAD_WIDTH_FOR_EARTH_CURVATURE = 16` when the earth-curvature option
is on, since a long quad can't bend).

**Vertex format: 16 bytes.** `LodQuadBuilder.BYTES_PER_VERTEX = 16`,
`BYTES_PER_QUAD = 64`. From `shaders/terrain/gl/vert.vert`:

```glsl
in uvec4 vPosition;   // xyz = integer block pos; .a = meta (8 bits light, 6 bits micro-offset)
in vec4 color;
in uvec4 irisData;    // x: iris material id, y: face normal index, zw: block texture tile id (little endian)
```

Positions are **integers**, lights are packed into the position's `.a` and
expanded in the vertex shader against MC's lightmap texture:

```glsl
uint lights = meta & 0xFFu;
float skyLight   = (float(lights/16u)+0.5) / 16.0;
float blockLight = (mod(float(lights),16.0)+0.5) / 16.0;
vertexColor = vec4(texture(uLightMap, vec2(skyLight, blockLight)).xyz, 1.0);
if (!uIsWhiteWorld) vertexColor *= color;
```

There is also a 2-bit-per-axis "micro offset" (`0b00zzyyxx`) applied in world
space — a sub-block nudge to break coplanar z-fighting between adjacent LOD
levels.

**Buffers: one container per render section, indexed quads, shared IBO.**
`LodBufferContainer` holds `IVertexBufferWrapper[] vboOpaqueWrappers` and
`vboTransparentWrappers` (arrays, because a section can spill into multiple
VBOs). `IndexBufferBuilder` emits the standard `0,1,2, 2,3,0` per quad, in
byte/short/int width as needed; `RENDER_DEF.useSingleIbo()` lets the backend
share one global index buffer across all sections. Upload is async
(`uploadBuffersAsync`).

**Instancing is NOT used for terrain.** Grep across `dhmain` render code
shows instanced paths only in `GlGenericObjectRenderer` /
`BlazeDhGenericObjectRenderer` — clouds, beacons, debug boxes. The 3.0.0-b
changelog line "Remove instanced rendering config option" refers to those.

**Culling, in four layers:**

1. **Frustum culling per section**, `core/render/RenderBufferHandler.buildRenderList()`
   — `frustum.intersects(blockMinX, blockMinZ, blockWidth, detailLevel)`,
   overridable via the public API (`IDhApiCullingFrustum`). The shadow pass
   binds `NeverCullFrustum` by default.
2. **Near-plane culling** — DH's own projection matrix has its near plane
   pushed far out (§5), so everything inside vanilla's radius is clipped in
   hardware.
3. **Cave culling** at transform time (§1).
4. **Occlusion culling of enclosed runs** at data time (`FullDataOcclusionCuller`).

Buffers are kept in a `SortedArraySet<LodBufferContainer>` sorted near-to-far
for early-Z, and `LodQuadTree` prioritises work by detail level then
Manhattan distance to the player. The 3.0.0-b changelog explicitly lists
"ensure LOD updates happen around the player instead of FIFO".

### Numbers

Confirmed from config (`core/config/Config.java`):

- `lodChunkRenderDistanceRadius` — **min 32, default 256, max 4096 chunks**
  (default = 4096 blocks radius)
- `horizontalQuality` default `MEDIUM`, `maxHorizontalResolution` default
  `BLOCK`, `verticalQuality` default `MEDIUM`
- `LodUtil.MAX_ALLOCATABLE_DIRECT_MEMORY = 64 MB` (cap for the direct-buffer
  pool, not total VRAM)

**Researcher's derivation — flagged as arithmetic, not measured.** The
constant-cells-per-section design has a striking consequence. At data detail
*d* (MEDIUM), the ring spans radius [192·2^d, 192·2^(d+1)). Annulus area =
π·192²·3·4^d ≈ 3.48×10^5 · 4^d blocks². Section footprint = (64·2^d)² =
4096·4^d. So **sections per ring ≈ 85, independent of d** — and therefore
≈ 85 × 4096 ≈ 348k data columns per ring, also independent of d. At the
default 4096-block radius that is 5 active rings (d = 0…4) ⇒ **~1.7M columns
in the full 360°**, of which a ~90° frustum keeps roughly a quarter plus the
near ring.

Cost is therefore **logarithmic in render distance**, not quadratic: doubling
render distance adds one ring, i.e. a constant ~348k columns. That, more than
any micro-optimisation, is why DH scales to 4096 chunks.

Turning columns into triangles: at MEDIUM vertical quality each column
carries 4–6 render data points, each becoming a box of up to 6 faces, but
`ColumnBox` only emits side faces where the neighbour column is lower. For
terrain that is mostly surface, expect ~2–3 quads per column before greedy
meshing, and greedy meshing removes a large fraction on flat ground. **Order
of magnitude: single-digit millions of quads in the full sphere, low millions
in frustum, at 64 bytes/quad ⇒ a few hundred MB of vertex data at maximum
settings.** No measured triangle counts were found in the repo or reachable
sources; treat this paragraph as an estimate.

Web sources on real-world performance are all anecdotal: "anything above 512
render distance may become difficult due to high VRAM/GPU usage"; RTX 3060 /
RX 6600 comfortable at 64–128 chunks. Specific FPS numbers not citable.

**Where the CPU actually goes.** Wiki "My game is stuttering or FPS are low"
lists CPU near 100%, GPU near 100%, and **VRAM near 100%** as separate
diagnoses, and the mod recommends 6–16 GB heap and a concurrent GC
(ZGC/Shenandoah) — i.e. the dominant cost is *build-time and allocation*, not
draw. The source corroborates: `PhantomArrayListPool` object pools
everywhere, `ThreadLocal` builders, "Minor garbage collection optimization"
comments, and a 3.0.0-b changelog entry "Drastically improve framerate
stability" via async and GC-pressure work.

---

## 4. Shading and atmosphere — "the look"

### Directional shading and SSAO

Face shading is baked (§2e). Ambient occlusion is **screen-space,
depth-only**, `shaders/ssao/gl/ao.frag`:

- Golden-angle spiral sampling (`GOLDEN_ANGLE = 2.39996323`), radius stepped
  outward per sample, up to `SAMPLE_MAX 64`
- Normals reconstructed from depth derivatives, `dFdxFine`/`dFdyFine` when
  `GL_ARB_derivative_control` is available
- Rotation dithered per-pixel with interleaved gradient noise
- `occlusion = smoothstep(0.0, uStrength, ao) * (1.0 - uMinLight)`
- **Linear distance fade**: beyond `uFadeDistanceInBlocks` SSAO is skipped
  entirely, and inside it
  `occlusion *= (fadeDistance - distanceFromCamera)/fadeDistance` — "fading
  is done to prevent banding/noise at super far distance"

Order matters: SSAO runs *before* fog, and the fog shader comment says so —
"This should be run last so it applies above other affects like Ambient
Occlusioning."

### The noise texture — fake surface detail at distance

`shaders/terrain/gl/frag.frag`, `applyNoise()`. Mechanism:

```glsl
vec3 vertexNormal = normalize(cross(dFdy(vPos.xyz), dFdx(vPos.xyz)));
vec3 fixedVPos = vPos.xyz + vertexNormal * 0.001;   // nudge off the plane to fix float precision

float noiseAmplification = uNoiseIntensity;
float lum = (fragColor.r + fragColor.g + fragColor.b) / 3.0;
// Lessen the effect depending on how dark the object is, equasion ... -(2x-1)^2+1
noiseAmplification = (1.0 - pow(lum * 2.0 - 1.0, 2.0)) * noiseAmplification;
noiseAmplification *= fragColor.a;

float randomValue = rand(quantize(fixedVPos, uNoiseSteps)) * 2.0 * noiseAmplification - noiseAmplification;

// 0 -> original color, 1 -> fully bright
vec3 newCol = fragColor.rgb + (1.0 - fragColor.rgb) * randomValue;

if (uNoiseDropoff != 0) {
    float distF = min(viewDist / uNoiseDropoff, 1.0);
    newCol = mix(newCol, fragColor.rgb, distF);   // less noise the further away
}
```

Five things to note:

- The hash key is `quantize(worldPos, uNoiseSteps)` = `floor(val * steps)/steps`
  — a **3D world-space lattice**, so the fleck is stable under camera motion
  and does not swim. Default `noiseSteps = 4` ⇒ quarter-block cells.
- It brightens toward white rather than perturbing RGB symmetrically, so it
  never muddies hue.
- The amplitude is **luminance-weighted by a parabola peaking at mid-grey** —
  no noise on blacks or whites.
- It **fades out with distance** (`noiseDropoff` default **1024 blocks**),
  which is the opposite of what one might guess. It exists to fake *texture*,
  and beyond ~1 km a quarter-block lattice is sub-pixel and would alias.
- Defaults: `enableNoiseTexture = true`, `noiseSteps = 4`,
  `noiseIntensity = 0.05`, `noiseDropoff = 1024`. And it is **mutually
  exclusive with the block atlas**:

```glsl
if (uNoiseEnabled
    // only apply noise to untextured blocks,
    // textured blocks don't need the fake texturing
    && vTextureTileId == 0u)
```

### Fog

DH's fog is a **deferred, full-screen pass on its own depth buffer**, not
per-vertex — `shaders/fog/gl/fog.frag`. Structure:

- `fragmentDepth == 1.0` ⇒ untouched, so fog is applied to LODs only, never
  to the sky. The horizon is where LOD geometry ends and sky begins, with no
  fog plane.
- Distance is **cylindrical by default** (`length(vertexWorldPos.xz)`),
  spherical optionally (`uUseSphericalFog`). Cylindrical is what stops the
  sky above you going foggy when you look up.
- Three curves: `LINEAR`, `EXPONENTIAL` (`fogMin + fogRange - fogRange/exp(x)`),
  `EXPONENTIAL_SQUARED` (`.../exp(x*x)`). **Default is `EXPONENTIAL_SQUARED`,
  density 2.5.**
- Independent **height fog** with its own curve, base height, up/down
  direction, and **ten mixing modes** (`MAX`, `ADDITION`, `MULTIPLY`,
  `INVERSE_MULTIPLY`, `LIMITED_ADDITION`, `MULTIPLY_ADDITION`,
  `INVERSE_MULTIPLY_ADDITION`, `AVERAGE`, …).
- Colour source: `USE_WORLD_FOG_COLOR` (default) or `USE_SKY_COLOR`.
- **Vanilla fog is disabled by default** (`enableVanillaFog = false`).

**How the fog wall is avoided — the scaling.**
`dhmain/.../postProcessing/fog/GlDhFogShader.java`:

```java
int lodDrawDistance = Config...lodChunkRenderDistanceRadius.get() * LodUtil.CHUNK_WIDTH;
this.shader.setUniform(this.uFogScale, 1.f / lodDrawDistance);
```

Fog distances are normalised to **DH's** render distance, and `farFogStart`
defaults to **0.4**, `farFogEnd` **1.0**. So at the default 4096-block
radius, fog begins at ~1600 blocks and saturates at ~4096. An exp² ramp over
a 2.5 km span reads as **aerial perspective**, not as a wall. Vanilla's fog
wall exists because it ramps over the last ~2 chunks of a 200-block radius;
DH's ramps over 60% of a 4 km radius.

⚠️ **Documentation/code mismatch worth flagging:** the config comments say
"1.0: Fog starts at the closest edge of the vanilla render distance", but the
shader scales by `lodChunkRenderDistanceRadius` (DH's), not vanilla's. The
code is the authority.

### TAA and sharpening

DH ships its own TAA (`shaders/antialias/gl/taa.frag`, `sharpen.frag`),
driven from the terrain vertex shader with an 8-frame jitter table:

```glsl
vec2 jitterOffsets[8] = vec2[8](vec2(0.125,-0.375), vec2(-0.125,0.375), ...);
if (uFrameMod8 > 0) gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
```

This matters for the look: sub-pixel LOD geometry at 4 km would otherwise
crawl badly.

There is also an **earth curvature** option, applied in the vertex shader:

```glsl
float localRadius = uEarthRadius + vertexYPos;
float phi = length(vertexWorldPos.xz) / localRadius;
vertexWorldPos.y += (cos(phi) - 1.0) * localRadius;
vertexWorldPos.xz = vertexWorldPos.xz * sin(phi) / phi;
```

(and it is why `MAX_QUAD_WIDTH_FOR_EARTH_CURVATURE = 16` — long quads can't
bend).

### Shader-pack (Iris) integration — what packs actually add

DH does **not** implement shadows, god rays, or physical atmosphere itself.
Iris exposes DH geometry to the pack. From the Iris docs and ShaderDoc:

- **Three programs**, all requiring the `compatibility` profile: `dh_terrain`
  (runs before vanilla terrain), `dh_water` (before vanilla water),
  `dh_shadow` (before shadow terrain/water). `dh_shadow` deliberately **keeps
  vanilla projection and textures**, not DH's.
- **Uniforms**: `dhProjection` / `dhProjectionInverse` /
  `dhPreviousProjection`, `dhNearPlane`, `dhFarPlane` (explicitly distinct
  from render distance), `dhRenderDistance`. Preprocessor define
  `DISTANT_HORIZONS`.
- **Depth**: `dhDepthTex0` / `dhDepthTex1` contain **only** DH geometry under
  DH's near/far planes — a separate depth domain the pack composites itself.
- **Attributes**: `gl_Vertex`, `gl_MultiTexCoord2`, `gl_Normal`, `gl_Color`,
  `dhMaterialId`.
- **`dhMaterialId` instead of `mc_Entity`** — DH cannot supply block IDs,
  only ~14–16 "mini-ID" material classes (leaves, stone, wood, metal, dirt,
  grass, lava, deepslate, snow, sand, terracotta, nether stone, water, air,
  illuminated). This is the `IRIS_BLOCK_MATERIAL_ID` 4-bit field in
  `RenderDataPointUtil` — that is why it is 4 bits.
- **Limitation**: no shadow-distance configuration; all DH geometry goes
  through the shadow pass.

So what makes the famous screenshots: the pack applies its **own atmospheric
scattering / aerial perspective**, **shadow maps that now include the far
terrain** (mountains casting shadows across valleys 2 km away), volumetric
light shafts, water reflections, and its own tonemapping — all on geometry
DH supplied and material classes DH tagged. DH's own fog is typically turned
off in that configuration.

Sources: <https://shaders.properties/current/reference/mod-support/distant_horizons/>,
<https://github.com/IrisShaders/ShaderDoc/blob/master/dh-support.md>, and
`RenderDataPointUtil.IRIS_BLOCK_MATERIAL_ID_SHIFT = 60` in core.

---

## 5. The near/far seam

DH's framing, from the wiki ("How does DH render so far?"), is a
**Source-engine skybox**:

> "This means that what we render is entirely separate from MC's normal
> world. This prevents issues with z-fighting and other problems related to
> depth calculations at extreme distances."

DH renders into its own framebuffer with its own projection matrix and depth
buffer, then composites. Three cooperating mechanisms handle the join.

### 5a. Overdraw prevention — push DH's near clip plane out

`core/util/RenderUtil.java`:

```java
nearClipPlane = vanillaBlockRenderedDistance;   // chunkRenderDistance * 16
nearClipPlane *= overdrawPreventionPercent;
if (nearClipPlane < 1.0f) nearClipPlane = 1.0f;
```

Automatic mode (`overdraw < 0`) picks the percentage from vanilla render
distance:

| vanilla RD (chunks) | overdraw |
|---|---|
| Iris shader pack in use | 0.2 |
| ≤ 2 | 0.2 |
| ≤ 4 | 0.3 |
| ≤ 6 | 0.6 |
| ≤ 10 | 0.8 |
| > 10 | 0.9 |

So at a normal 12-chunk vanilla RD, DH's near plane sits at 0.9 × 192 ≈ 173
blocks — DH draws *behind* the last ~19 blocks of vanilla terrain,
guaranteeing overlap rather than a gap.

There is also `reduceOverdrawWithFastMovement`: above 10 blocks/s the
overdraw ratio scales down toward `MIN_OVERDRAW_RATIO = 0.2` as speed
approaches `MAX_SPECTATOR_SPEED = 100 blocks/s`, "to give MC a chance to
load/generate". And a height-based override
(`getHeightBasedNearClipOverrideBlockDistance`) for when the camera is near
the ground.

Comment worth noting: *"a near clip plane distance of 2 blocks is enough to
allow the fragment culling to take effect instead of seeing the near clip
plane"*, and *"setting this to a number lower than 1.0 can cause distant
clouds to flash due to depth buffer precision loss. This is not an issue when
using Reverse Z depth."*

### 5b. Dithered fragment discard

`shaders/terrain/gl/frag.frag`:

```glsl
if (uDitherDhRendering)
{
    // Dithering is used since it works for both opaque and transparent rendering
    float worldNoise = bayerMatrix4x4(gl_FragCoord.xy);
    // minor fudge factor to make sure all pixels fade out
    // if not included 1 in 16 pixels would never fade away
    worldNoise += 0.001;

    float fadeStep = smoothstep(uClipDistance, uClipDistance * 1.5, viewDist);
    if (fadeStep <= worldNoise) discard;
}
else
{
    if (viewDist < uClipDistance && uClipDistance > 0.0) discard;
}
```

A 4×4 Bayer matrix keyed on **screen coordinates** (deliberately: "the
fragCoord is used since it is stable and small so the dithering is cleaner"),
smoothstepped over `[uClipDistance, 1.5×uClipDistance]`. Dither rather than
alpha because it works identically for opaque and transparent passes and
needs no sorting. Default `ditherDhFade = true`.

### 5c. Post-process cross-fade between the two colour buffers

Two shaders in `shaders/fade/gl/`, selected by `vanillaFadeMode` (default
`DOUBLE_PASS`):

`dh_fade.frag` — fade *DH in*:
```glsl
float fadeStep = smoothstep(startFade, endFade, dhFragmentDistance);
fragColor = mix(combinedMcDhColor, dhColor, fadeStep);
```

`vanilla_fade.frag` — fade *vanilla out*, using MC's depth:
```glsl
float fadeStep = smoothstep(uStartFadeBlockDistance, uEndFadeBlockDistance, mcFragmentDistance);
fragColor = mix(combinedMcDhColor, dhColor, fadeStep);
```

Both special-case `dhColor.a == 0` ("if not done vanilla clouds will render
incorrectly at night") and `vanilla_fade` has a
`dhVertexWorldPos.y > uMaxLevelHeight` branch that is a "work around to
prevent MC clouds rendering behind DH clouds".

### Remaining artefacts, in the authors' own words

From the wiki's Problems-and-Solutions page:

- **"There are holes at the edge of my vanilla Render Distance, especially
  when moving"** — *"caused by either vanilla terrain not loading in fast
  enough, or your shader having an incorrect overdraw prevention
  implementation... The easiest fix is to move slower and/or ignore it."*
  The #1 seam complaint: at speed, vanilla hasn't meshed the chunk yet and
  DH has already clipped itself away from it.
- **"There are low quality full blocks behind and around non-full blocks,
  i.e. fences and ladders"** — *"This is intended behavior, to prevent holes
  in the world when moving, DH will overlap with some vanilla terrain."* The
  cost of 5a: you see coarse LOD blocks through vanilla fences.
- **"Flat LOD chunks don't match the color of the real chunks, and have
  weird grid lines"** — *"The discoloration is due to DH not having enough
  vertical slices"* (raise Vertical Quality); *"The grid lines are
  compression artifacts"* (switch `Lossy World Compression` to `Merge Same
  Blocks`, and regenerate).
- **"Trees/structures suddenly appear/disappear when I fly around"** — the
  `FEATURES` worldgen mode not saving chunks, so regeneration differs.
- **"My terrain is duplicating across the sky when using shaders"** — a
  known shader-pack bug (linked to a Bliss-Shader issue).
- **"The LOD chunks are totally black"** — a mod interfering with the
  lightmap.

The transformer source also documents artefacts it fixes: black spots under
opaque cover, "grid lines on LOD borders" from missing light transfer, snow
rendering as grey grass, water under ice, and light bleeding from water into
sand.

---

## 6. Contrast: how others do it

*(Kept brief per brief. Sources are code on `master` unless noted.)*

**Veloren** is the most instructive contrast because it inverts DH's trade.
The far world is **not voxel data at all** — it is three textures at **one
texel per 32×32-block chunk**, covering a 1024×1024-chunk world in **~12 MB
of static VRAM**, uploaded once at login
(`voxygen/src/render/pipelines/lod_terrain.rs`): `map` (`Rgba8UnormSrgb`, one
RGB per chunk), `alt` (13-bit altitude packed into 16 bits), `horizon` (a
horizon-angle shadow map, west in `rg`, east in `ba`).

That is drawn as **one static VBO** — a camera-centred radial grid whose
vertices are literally `struct Vertex { pos: [f32; 2] }`, 8 bytes, no height,
no colour. `splay()` biases density toward the camera with `pow(dist,5.5)`,
so there are **no LOD rings and no seams at all**. Height comes from bicubic
16-bit reconstruction of the alt texture. `lod_detail` defaults to 250 ⇒
~63k quads, one draw call.

**The part that matters for our question**: Veloren makes that smooth
heightfield *read as blocks in the fragment shader*. `lod_voxels()` picks a
virtual voxel size that grows with distance in quantised exp/log steps and is
divided by screen resolution — so a distant block stays a roughly constant
number of *pixels*, clamped 1–128 world units — then runs a short DDA
raymarch (≤40 steps) against that virtual grid and returns a
**voxel-aligned position, an axis-aligned normal, and an AO term**. Crisp
cube facets and cube-shaped shading on geometry that has none. Devblog 94:
*"I've reimplemented the Level of Detail 'fake voxel' effect in a way that
much more closely fits patterns visible on actual voxels."* An experimental
flag `ProceduralLodDetail` additionally warps the colour lookup by two noise
octaves (32- and 16-block) *before* sampling the map texture — synthesising
sub-chunk colour variation from nothing.

Colour, notably, is **a point sample, not an average**: one authored colour
per chunk from the same `ColumnGen` code the block renderer uses. Cheaper
*and* more saturated than averaging, but sub-chunk variation is simply not
stored — it is re-synthesised in the shader.

Distant trees are **separate instanced LoD objects**:
`lod::Object { kind, pos: Vec3<i16>, flags, color: Rgb<u8> }` — **13 bytes
per tree**, carrying the real per-tree leaf colour, with 2 random-rotation
bits. 26 hand-made low-poly meshes, streamed by 32×32-chunk zones. The
near/far join is a **hard swap with no crossfade**: LoD terrain gets
`f_pos.z -= 1.0/pow(dist/(view_distance*0.95), 20.0)`, and LoD trees inside
the real-terrain radius are teleported 10,000 units underground.

**Others, briefly.** *Teardown*: no heightfield LOD at all — a
1252×128×1252 3D texture (2×2×2 voxels per texel, ~200 MB), DDA raymarched
in the fragment shader, LOD via **3 levels of 3D mipmaps** that also kill
distant shimmer by blurring. *Aokana* (I3D 2025): 256³ SVDAG chunks, 8→1
voxels when ≥2 non-empty, colour by **averaging the 8 children** — and the
paper concedes *"this approach can introduce a potential risk of degenerated
color quality"*, which is exactly the mush problem. 6 ms at 64K render
distance on a 3060 Ti. *No Man's Sky*: dual-contouring with octree LOD
(smooth, so the problem doesn't arise). *Voxy* (the other MC mod): re-meshes
far sections with **real block textures** captured from the GL atlas,
greedy-meshed, biome tints via the game's `ColorResolver`. *POP buffers*
(0fps): the blocky-specific LOD — round vertices down to powers of two with
"stable rounding" so cracks never form, no skirts, no stitching. *Dreams*:
point splats sized to ~1 pixel — **choose LOD by projected screen size, not
world distance**.

**Not confirmed, do not cite**: Hytale and Enshrouded have no public
technical writeup on far LOD; "Lay of the Land" has none either. Third-party
claims about Hytale's LOD are unsourced aggregator content.

---

## What transfers to a Godot heightmap far-field, and what does not

Factual observations only.

**Transfers directly, low cost:**

- **The colour-ratio detail texture is the single most portable idea here.**
  Encode each material's texture as `round((channel/average) * 127.5)`, UV
  it from `fract(worldPos)` in the fragment shader, multiply:
  `base * (tile.rgb * 2.0)` mixed by `tile.a`. It tiles once per block on an
  arbitrarily large quad, costs one texture fetch, and **provably does not
  change the average colour at distance** — which is why DH can leave it on
  without the far field shifting hue. This works on a heightmap mesh with no
  change to the mesh whatsoever, provided the shader can recover world
  position.
- **Mode-vote instead of averaging when coarsening.** Where the far field
  currently averages a colour over a 4/8/16 m cell, taking the *most common*
  material (with air excluded, ties → first) keeps cells at full saturation
  and preserves high-frequency variation. Cheap: an integer histogram over 4
  values.
- **Averaging colour in linear space, alpha-weighted**, with per-class
  overrides (force alpha for foliage, weight saturated pixels for flowers).
  Applies to any material-average we compute.
- **Baked directional face shading** as vertex colour. On a quantised-step
  heightmap the vertical step faces already exist; multiplying them by a
  per-direction constant is what makes steps read as *blocks*.
- **The noise-texture recipe**, if the atlas is too much: hash a
  **world-space quantised** position (stable under camera motion), amplitude
  weighted by a parabola in luminance, brighten toward white, fade out with
  distance. DH's defaults — 4 steps, 0.05 intensity, 1024-block dropoff —
  are a tuned starting point.
- **Deferred, depth-based fog with an exp² curve normalised to the far-field
  radius**, starting at ~0.4 of it, cylindrical rather than spherical,
  applied only where depth < 1. This is the specific set of choices that
  avoids the fog wall, and it is a full-screen shader in Godot, not a mesh
  change.
- **Screen-coordinate 4×4 Bayer dithered discard over a
  `smoothstep(d, 1.5d, viewDist)` band** for the near/far join. Works for
  opaque and transparent, needs no sorting, no alpha blending.
- **Overdraw by construction**: have the far field start *inside* the near
  field's radius rather than exactly at it, and clip per-fragment. DH's
  automatic percentages (0.8–0.9 of the near radius at normal settings,
  dropping toward 0.2 at speed) are empirically tuned.
- **TAA jitter.** Sub-pixel far geometry crawls without it. DH's 8-frame
  table is directly reusable; Godot 4 Forward+ has TAA built in.
- **From Veloren, if we ever want blocks without block geometry**: the
  `lod_voxels()` screen-space cubification — virtual voxel size quantised by
  distance *and divided by screen resolution*, short DDA march for an
  axis-aligned normal and AO. It makes a smooth heightfield read as cubes
  with zero data cost. A genuine alternative to true block-grid geometry.

**Transfers with modification:**

- **Constant cells per section with logarithmic ring spacing.** DH's
  64×64-cells-per-section at every level is what makes cost logarithmic in
  render distance. Our concentric rings already approximate this; the
  specific formula `detail = floor(log(dist/unit)/log(base))` with base 2.0
  and unit 192 blocks (= 384 at 0.5 m blocks) is a directly usable ring
  schedule.
- **Greedy meshing.** DH's two-pass (merge east-west always; merge
  north-south only for up/down faces) with a 2048-cell width cap is
  straightforward, **but GDScript worker threads being serialised makes this
  a real build-time cost**. Note that DH gates merging on *equal colour*,
  and the atlas texture then re-introduces per-block variation across the
  merged quad — so merging aggressively does **not** cost variation.
- **The atlas layout constants** (16×16 tiles, 256 per row, 4096 px wide,
  grow 16 rows at a time) are sized for Minecraft's 16px textures. Scale to
  our texel density.
- **Palettised texture ids** — one byte per cell indexing a per-section
  palette of ≤256 tile ids — a good memory pattern if the far field grows to
  many materials.

**Does not transfer / not needed:**

- **The entire vertical-run data structure.** The 64-bit full data point
  with 12-bit run height and 12-bit min Y exists to represent caves,
  overhangs and floating islands. With no caves in the far field, a
  heightmap cell needs height + material, not a run list. Everything in
  `RenderDataPointReducingList`, `FullDataOcclusionCuller`, cave culling,
  and `EDhApiVerticalQuality` falls away. (Note DH ships `HEIGHT_MAP`
  vertical quality = 1 slice — our current representation is DH's cheapest
  mode, and it is a supported one.)
- **The two-representation split (full data ↔ render data).** DH needs it
  because block state and biome must be re-resolved when the resource pack,
  biome colours or config change. If the far field is generated from the
  same heightmap source as the near field, one representation suffices.
- **SQLite storage, LZ4/ZSTD blobs, adjacent-column columns, the
  update-propagation machinery.** These solve "an arbitrary Minecraft world
  was explored in arbitrary order and must persist across sessions".
  Deterministic streamed generation from a seed does not need them.
- **The skybox/separate-projection architecture.** DH uses a second
  projection matrix and depth buffer because it must coexist with a renderer
  it does not control at distances that break MC's depth precision. In one
  engine with one depth buffer, Forward+ and a reversed-Z or well-chosen
  near plane, this is unnecessary complexity — the cross-fade shaders exist
  only to composite two independently-rendered colour buffers.
- **Instancing for terrain** — DH doesn't use it, and neither should a
  static per-ring mesh.
- **`dhMaterialId` / Iris material classes.** That 4-bit field exists purely
  to give third-party shader packs something to switch on. In a first-party
  renderer, materials are already known.
- **Distant world generation modes.** DH's `SURFACE`/`FEATURES`/
  `INTERNAL_SERVER` distinction, and the resulting "trees pop in and out"
  artefact, is an artefact of not owning the world generator.

**One caution.** DH's `maxTexturedLodDetailLevel` defaults to **2** — real
textures only up to 4-block cells, roughly the first 1.5 km, "distant LODs
always use flat colors... textures [become] smaller than a pixel and
therefore invisible". And the noise texture *fades out* past 1024 blocks for
the same reason. Both suggest that beyond a certain angular size, per-block
colour variation stops helping and starts aliasing. On an RTX 5080 with TAA
the crossover is probably further out than DH's defaults, but the shape of
the curve — detail near, flat far, atmosphere carrying the distance — is
what the screenshots actually depend on.

---

### Source index

**Primary (source code, cloned `main`, 2026-08-31)**
- `gitlab.com/distant-horizons-team/distant-horizons-core` — `core/util/FullDataPointUtil.java`, `core/util/RenderDataPointUtil.java`, `core/util/RenderUtil.java`, `core/util/RenderDataPointReducingList.java`, `core/util/LodUtil.java`, `core/pos/DhSectionPos.java`, `core/dataObjects/fullData/sources/FullDataSourceV2.java`, `core/dataObjects/transformers/FullDataToRenderDataTransformer.java`, `core/dataObjects/transformers/FullDataOcclusionCuller.java`, `core/dataObjects/render/ColumnRenderSource.java`, `core/dataObjects/render/textures/BlockTextureRegistry.java`, `core/dataObjects/render/textures/BlockFaceTexture.java`, `core/dataObjects/render/bufferBuilding/{LodQuadBuilder,BufferQuad,ColumnBox,LodBufferContainer,IndexBufferBuilder}.java`, `core/render/AbstractBlockTextureAtlas.java`, `core/render/QuadTree/LodQuadTree.java`, `core/render/RenderBufferHandler.java`, `core/render/renderer/{LodRenderer,FogRenderParamFactory}.java`, `core/file/fullDatafile/V2/FullDataSourceProviderV2.java`, `core/config/Config.java`, `core/generation/DhLightingEngine.java`, `api/enums/config/EDhApi{HorizontalQuality,VerticalQuality,MaxHorizontalResolution,DataCompressionMode,WorldCompressionMode}.java`, `api/enums/worldGeneration/EDhApi{WorldGenerationStep,DistantGeneratorMode}.java`, `core/src/main/resources/sqlScripts/*.sql`, `core/src/main/resources/assets/distanthorizons/shaders/{terrain,fog,ssao,fade}/gl/*`
- `gitlab.com/distant-horizons-team/distant-horizons` — `common/.../wrappers/block/ClientBlockStateColorCache.java`, `common/.../wrappers/world/ClientLevelWrapper.java`, `common/.../render/openGl/postProcessing/fog/GlDhFogShader.java`, `common/.../render/openGl/generic/GlGenericObjectRenderer.java`, `common/.../render/blaze/*`

**Wiki**
- <https://gitlab.com/distant-horizons-team/distant-horizons/-/wikis/1-user-guide/1-frequently-asked-questions/1-general/General>
- <https://gitlab.com/distant-horizons-team/distant-horizons/-/wikis/1-user-guide/1-frequently-asked-questions/2-problems-and-solutions/Problems-and-Solutions>

**Iris / shader integration**
- <https://shaders.properties/current/reference/mod-support/distant_horizons/>
- <https://github.com/IrisShaders/ShaderDoc/blob/master/dh-support.md>

**Release / distribution**
- <https://modrinth.com/mod/distanthorizons>
- <https://www.curseforge.com/minecraft/mc-mods/distant-horizons/files/7945586> (3.0.0-b changelog)

**Contrast section**
- Veloren source at `https://gitlab.com/veloren/veloren/-/raw/master/` — `voxygen/src/scene/lod.rs`, `voxygen/src/render/pipelines/lod_terrain.rs`, `assets/voxygen/shaders/include/lod.glsl`, `lod-terrain-{vert,frag}.glsl`, `lod-object-vert.glsl`, `common/src/lod.rs`, `world/src/lib.rs`, `world/src/sim/map.rs`, `voxygen/src/settings/graphics.rs`
- <https://veloren.net/blog/devblog-94/>, <https://veloren.net/blog/devblog-65/>
- <https://juandiegomontoya.github.io/teardown_breakdown.html>
- <https://arxiv.org/abs/2505.02017> (Aokana, I3D 2025)
- <https://0fps.net/2018/03/03/a-level-of-detail-method-for-blocky-voxels/> (POP buffers)
- <https://www.mediamolecule.com/blog/article/siggraph_2015> (Dreams)
- <https://www.gdcvault.com/play/1024265/Continuous-World-Generation-in-No> (No Man's Sky)
- <https://github.com/JustinTHChapman/voxy> (Voxy)
