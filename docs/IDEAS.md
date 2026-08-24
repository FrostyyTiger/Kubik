# Ideas

## Next 3

Seeded once from the pillars, then re-ordered when terrain v1 was scoped. From
here on this list is filled by what a playtest taught us.

1. ~~**Terrain v1 - the world itself.**~~ **DONE**, merged to `main`
   2026-08-24. Swiss pre-Alpine landscape: meadow valleys, forested slopes,
   bare rock, snow peaks, lakes in real depressions, fog and a day/night cycle.
   [plans/terrain-v1.md](plans/terrain-v1.md).

   **Terrain v2 - the shape of the land** followed it on `feat/terrain-v2`:
   3 x 3 km at a coherent 1:4 scale, seven elevation zones resolved as shares
   of map area, real flat ground, baked ambient occlusion, LOD rings, and a
   spawn that satisfies the postcard test by construction.
   [plans/terrain-v2.md](plans/terrain-v2.md).
   *Answers:* the postcard test - can I frame a mountain, its forest and a lake
   in one view within two minutes of walking from spawn?

   **Plan B** splits in two. **Foliage v1 - what grows on the land** is
   written and queued for an overnight run: seven tree species, dense forest
   with glades, ground cover in every zone on a decoration layer, far trees
   to 300 m, fireflies and glowing mushrooms after dark.
   [plans/foliage-v1.md](plans/foliage-v1.md). **Water and rivers** is the
   other half and is not written yet. What v2 left ready for both is listed
   at the end of `STATUS.md`.

2. **First enemy and the light attack.** One enemy type, one attack, shaped so
   two bodies beat it and one struggles.
   *Answers:* does fighting it together actually produce flanking and saves, or
   do we both just mash forward?

   Terrain v2 left the hook: worldgen exposes a normalised
   `TerrainGenerator.danger_at()`, 0 at spawn and 1 at the furthest corner, and
   the terrain itself already grows wilder with it. Nothing consumes it yet.

3. **Campfire.** The first placeable object: light, regen, respawn anchor.
   *Answers:* is reaching the fire a relief, and does dying cost time without
   costing progress?

   Terrain v2 built the alpine benches for exactly this - wide flat shelves
   partway up a slope, which is where a fire or a fight can happen on ground
   that is otherwise all gradient.

Terrain moved to the front because items 2 and 3 both need somewhere to happen -
readable geography with flat valley floors to fight and camp on. It is a
prerequisite, not a detour.

Terrain v1 delivered a walking third-person player as a side effect, and v2
added sprint, but both on **local physics only**. Rewiring it into the
host-authoritative input path is a carried ticket, not done.

Deliberately not here:

- **Day/night as a danger axis.** The cycle shipped in terrain v1, but visual
  only. Pillar 2 wants darkness to mean something; that needs the enemy first.
- **Breaking terrain.** Unsettled in DESIGN.md. Settle it before building it.

## Someday

Not rejected, not queued. Nothing moves up from here without a playtest saying
it should.

- Explosions that destroy terrain. Wanted, but it drags two roadmap items
  forward with it: the edit log grows without bound and is sent in full to
  every joining player, and remeshing eight chunks is a visible hitch. Greedy
  meshing landed in terrain v1; edit-log compaction is still needed.
- Found cozy places - villages, hot springs
- Mounts
- More races
- Full class system *(contradicts a pillar)*
- Skill trees *(contradicts a pillar)*
- Base building *(contradicts a pillar)*
- Arbitrary block placement *(contradicts a pillar)*

The tagged entries contradict a pillar as written. That is fine as a parking
space, but building one means amending the pillar first, deliberately and in
writing - not discovering halfway through a branch that the design moved.
