# Ideas

## Next 3

Seeded once from the pillars, to reach a first playable build. From the next
playtest onward this list is filled by what the playtest taught us.

1. **Player body.** Physics character, collision against chunk meshes, input
   sent to the host and simulated there - replacing the provisional
   position-reporting in `Game._srv_report_state`.
   *Answers:* does moving through this world feel good enough to want to walk
   further into it?

2. **First enemy and the light attack.** One enemy type, one attack, shaped so
   two bodies beat it and one struggles.
   *Answers:* does fighting it together actually produce flanking and saves, or
   do we both just mash forward?

3. **Campfire.** The first placeable object: light, regen, respawn anchor.
   *Answers:* is reaching the fire a relief, and does dying cost time without
   costing progress?

Together these make the loop loop at small scale: walk out, get attacked, fight
it together, retreat to the fire or die trying. That is the smallest thing that
can tell us whether the pillars are true.

Deliberately not here:

- **Chunk streaming.** Pillar 3 needs it eventually, but it is a large
  engineering job that answers no design question. The fixed 5x5 area is enough
  world to test all three items above.
- **Day/night and darkness.** Half of pillar 2's danger axis, but a modifier on
  a loop that does not exist yet.
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
