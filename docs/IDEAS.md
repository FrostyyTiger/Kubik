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

   **Plan B** splits in two, and the first half is done.

   **Foliage v1 - what grows on the land** ran overnight on 2026-08-24/25 and
   landed on `feat/foliage-v1`, all eleven stages.
   [plans/foliage-v1.md](plans/foliage-v1.md). Seven tree species instead of
   one, a forest that clumps and leaves clearings, 8.7 M pieces of ground cover
   on a decoration layer that never touches a chunk, an impostor ring so the
   forest does not stop at 96 m, and fireflies and glowing mushrooms after
   dark. Trees went from 34,925 to 73,675 on seed 42 and the terrain under them
   did not move - same heightmap hash, same zone shares, same spawn.
   `STATUS.md` has every number and the list of things tuned on the wrong
   renderer.

   **Water and rivers** is the other half and is still not written. What
   foliage v1 leaves ready for it is at the end of `STATUS.md`: the placement
   product takes another `base` case and another binary gate almost for free,
   the decoration layer takes water plants without changing, and reeds already
   follow `Lakes.shore_level_at_cell()` - which is the same question a river
   would have to answer.

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

- **Gathering.** Foliage v1 built the identity and the removal path for it and
  stopped short of the RPC, deliberately - the comment at
  `World.remove_flora_local()` writes out the call it is waiting for. Gathering
  is a launch skill in `DESIGN.md`, but it is a SKILL, and skills are not on
  this list until something is worth gathering for.
- **Day/night as a danger axis.** The cycle shipped in terrain v1, but visual
  only. Pillar 2 wants darkness to mean something; that needs the enemy first.
  Foliage v1 added the first thing that exists only after dark - fireflies and
  glowing mushrooms - and they are deliberately on the cozy side of the
  register, not the tense one.
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

## Second Age: The Sea (post-1.0 expansion arc, not before)

Bigger than a Someday item - an expansion arc, so it gets its own section.

The launch world is Alpine and bounded. Long-term, one world edge descends past
the far ranges to a COAST, and the game's second act opens: the sea.

- **Coast at ONE world edge.** World edges are asymmetric: peaks on most sides,
  descent to water on one.
- **Interactive water.** Swimming ships here, and with it the lizardfolk swim
  perk (replaces the fish-shadow placeholder in `DESIGN.md`).
- **Sailing.** Boat controller, wind matters. Valheim-school: sailing should be
  a skill and a feeling, not a fast-travel skin.
- **Ocean and island generation.** Island kingdoms as the new far-zone content
  tier.
- **The lizardfolk homeland lies across the water** - the answer to "why is a
  water-race in the mountains".
- **Trailer moment to build toward:** two players crest the last ridge and see
  open water for the first time.

Scope honesty: this is an expansion-sized arc (2.0 energy), not a feature.
Nothing here before the Alpine game is complete and shipped. BUT the sea may be
foreshadowed from day one via lore fragments, which are cheap: shells in high
ruins, lizardfolk graves facing away from the mountains, salt references.
Longing is free; water physics are not.

What it asks of the code today is one thing only, recorded in `CLAUDE.md`: do
not hardcode "world edge = mountains" anywhere.
