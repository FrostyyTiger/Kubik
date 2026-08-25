# Look v1, Stage 7 - UI in Deco: status

Ran 2026-08-25 on Marcel's Windows box, in a worktree off `feat/look-v1`.
Stage 7 of `docs/plans/look-v1.md` only; the world stages and the character
re-author ran elsewhere the same day.

## What shipped

- `assets/ui/deco_theme.tres`, set as the project theme in `project.godot`
  (`gui/theme/custom`). Paper, ink, gold, alpine blue and sun, and no sixth
  colour. Named variations `TitleLabel`, `SectionLabel`, `AccentLabel` and
  `StatusLabel` so a screen says what a label IS rather than what size it is.
- Fonts, fetched from the google/fonts repository with their OFL licences
  beside them in `assets/fonts/`: **Limelight** (the title), **Josefin Sans**
  (everything you press and read, weight 500 body / 600 capitals via the
  variable axis), **Poiret One** (the line under a title). Not a fallback -
  the network was up.
- `scripts/ui/deco.gd` - the palette as constants and the helpers for screens
  built in code. `scripts/ui/deco_rule.gd` - the gold double rule.
  `scripts/ui/poster_backdrop.gd` - the menu's back: sunburst, three ranges
  of stepped mountains, a ground band. Drawn, not textured.
- Main menu, character creation screen, remote nametag (`Label3D`, paper on
  the peer's hue darkened) and the debug HUD's title line.
- `scripts/ui/ui_shot.gd` and `-- --shot-ui <label>`: the UI comparison
  harness, in the shape of the tour and the gallery. Writes
  `build/ui/<label>/main-menu.png` and `character-creation.png`. Needs a
  window.

## Evidence

`build/ui/look-7/main-menu.png`, `build/ui/look-7/character-creation.png`
(gitignored, like the tour's). Headless host smoke test with the theme
active: `--host --seed 42 --port 7799 --quit-after 300`, exit 0, world built.

## Judgement calls

- **Chamfer, not notch.** The plan asked for a two-step notched corner. A
  `StyleBoxFlat` cannot notch; `corner_detail = 1` turns its rounded corner
  into one straight cut - an octagon - which is the Deco profile with no
  texture and no nine-patch. Rule 2 prefers it. Buttons, fields, swatches and
  the preview frame all share it.
- **The peer colour survives, as the outline.** The nametag used to be the
  peer's hue outright. That is a sixth colour on screen, but it is also how
  two friends tell each other apart at a glance, so it moved to the outline
  (darkened) under paper text rather than being dropped.
- **Sun behind the title.** First shot had the disc under the title,
  colliding with the subtitle. Moved to 21% of the window height so the
  title sits across it and the two rules bracket it.
- **The creation screen keeps its own preview light.** The plan's Stage 1
  ramp is the world's; this screen's key light is untouched here so that the
  character stage can judge both under one change.

## Gotcha worth knowing

A project theme that references fonts which have not yet been imported
stops `--import` before it imports them - the editor fails to load the theme
during init and exits -1 with `No loader found for resource ... .ttf`. On a
fresh checkout this cannot happen (the `.import` files are committed), but
if it ever does: comment out `gui/theme/custom`, import once, restore it.

## Not done

- No hover/pressed screenshots - the harness shoots the resting state.
- The debug panels (F4 / F8) inherit the theme's fonts and styles but were
  not restyled beyond the title line, by the plan's own instruction.
