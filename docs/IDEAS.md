# Ideas

## Next 3

Seeded once from the pillars, then re-ordered when terrain v1 was scoped. From
here on this list is filled by what a playtest taught us.

1. **Terrain v1 - the world itself.** Swiss pre-Alpine landscape: meadow
   valleys, forested slopes, bare rock, snow peaks, lakes in real depressions,
   fog and a day/night cycle. Full plan in
   [plans/terrain-v1.md](plans/terrain-v1.md).
   *Answers:* the postcard test - can I frame a mountain, its forest and a lake
   in one view within two minutes of walking from spawn?

2. **First enemy and the light attack.** One enemy type, one attack, shaped so
   two bodies beat it and one struggles.
   *Answers:* does fighting it together actually produce flanking and saves, or
   do we both just mash forward?

3. **Campfire.** The first placeable object: light, regen, respawn anchor.
   *Answers:* is reaching the fire a relief, and does dying cost time without
   costing progress?

Terrain moved to the front because items 2 and 3 both need somewhere to happen -
readable geography with flat valley floors to fight and camp on. It is a
prerequisite, not a detour.

Terrain v1 delivers a walking third-person player as a side effect, but on
**local physics only**. Rewiring it into the host-authoritative input path is a
carried ticket, not done.

Deliberately not here:

- **Day/night as a danger axis.** The cycle ships in terrain v1, but visual
  only. Pillar 2 wants darkness to mean something; that needs the enemy first.
- **Breaking terrain.** Unsettled in DESIGN.md. Settle it before building it.

## Someday

Not rejected, not queued. Nothing moves up from here without a playtest saying
it should.

- Explosions that destroy terrain. Wanted, but it drags two roadmap items
  forward with it: the edit log grows without bound and is sent in full to
  every joining player, and remeshing eight chunks at ~13 ms each is a visible
  hitch. Needs greedy meshing and edit-log compaction first.
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
