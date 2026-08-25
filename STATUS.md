# Status

The latest run is **look v2 — the poster, refined**, 2026-08-25, on
`feat/look-v2`: `docs/status/look-v2.md`.

**It has a BLOCKING finding at the top and it is the first thing to read.** The
run executed on ganymede, which has no Vulkan ICD, so every frame in it was
rendered by Mesa llvmpipe on the Compatibility renderer and **Forward+ was
never exercised**. The colour transfer was measured rather than assumed and the
fix is green on Compatibility; whether it is green on Forward+ is one command
on the Windows box, and the status doc names it.

Earlier runs, newest first:

- `docs/status/look-v1.md` — look v1, the poster, 2026-08-25, with the
  character half in `docs/status/look-v1-characters.md` and the UI half in
  `docs/status/look-v1-ui.md`
- `docs/status/foliage-v1.md` — foliage v1, 2026-08-24/25
- `docs/status/character-v1.md` — character v1, 2026-08-24/25
- `docs/plans/terrain-v2.md`, `docs/plans/terrain-v1.md` — terrain, whose
  status sections live in the plans
