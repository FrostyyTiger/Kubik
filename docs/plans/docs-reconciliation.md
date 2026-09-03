# The document rewrites - a brief for a docs-only session

Written 2026-09-03 at Marcel's ask (light v1 grill, Q18): a note a separate
Claude session can be pointed at to bring this repo's documents into line
with the bible, without touching code and without colliding with the light
v1 run. Everything below comes from `RECONCILIATION.md` section 8 and
`CLAUDE.md` § Where things live; this file only turns them into a work
order.

**When.** Now is fine, in parallel with light v1, for everything that the
bible already settles (D1 to D56). Two spots are reserved for the light v1
run and must be left alone until its status doc exists: `README.md` § Where
it is shot, and the colour-pipeline paragraph of `docs/DESIGN.md` (the one
that describes the ramp, "distance is bands" and the swatch sheet). Every
other rewrite is independent of what light v1 finds.

## Rules

- **The bible wins.** `../Kubik-bible/` is the direction; a sentence here
  that disagrees with it is wrong. Cite decisions by number (D44, D56). Do
  not edit the bible from this side: a bible rule that turns out wrong goes
  into a "For the bible" list at the bottom of this file's commit message,
  and Marcel logs it.
- **Docs only.** No `.gd`, no `.cpp`, no `.tscn`, no `project.godot`. If a
  rewrite seems to need a code change, write the sentence the code should
  make true and stop.
- **`main`, directly, one commit per file**, `docs:` prefix, fast-forward
  only; `git pull --rebase` before every push, because the assets session
  and the light v1 branch both move. Never touch `docs/plans/light-v1-tech.md`
  or `docs/status/light-v1.md`.
- **Keep what stays.** Section 8 of the reconciliation names, per file,
  what survives. Rewriting a paragraph that already agrees with the bible
  is churn; leave it.
- **Dates and numbers stay honest.** A status number that was measured is
  kept with its date; a design claim the bible overturns is replaced, not
  softened.
- Every rewritten file opens with one line: "Rewritten YYYY-MM-DD against
  the bible as of D56; where an older document disagrees, the bible wins."
  `CLAUDE.md` already has it and is the model.

## The files

| File | Keep | Replace | Source |
|---|---|---|---|
| `README.md` | the architecture contract (host authority, one mutation path, terrain never sent, the transport seam, chunk format), the probes, the build notes, § Where it is shot (reserved) | the pitch ("cozy" leaves the world's register and stays at the fire), the four pillars become the gameplay pillars under the tone, the status paragraph, the "unbounded" section per D44, hard rule one (retired by D49: the compiled library is required) | `CLAUDE.md` § Gameplay pillars, § World rules, § Engine rules; RECONCILIATION § 8 |
| `docs/DESIGN.md` | the parts-as-data and `.vox` drop-in rule, the resolution ladder as engine grains, the frontier rule, physics, traversal, multiplayer, camera, saves, placeables, the creature behaviour stance, the magic section amended to D54 (a spark and a chill that obey altitude), the colour pipeline (reserved) | the setting, the races (D37, D51), the scale ratio (D45), the "bounded" and "unbounded" rulings (D44), the art-direction sections (pillar 2 and D40), the fantastic roster; each replaced by a pointer into `lore/` or `style-bible/` | RECONCILIATION § 8, `docs/reconciliation/01-direction-docs.md` for every line |
| `docs/DIRECTOR.md` | nothing but the title | a thin pointer to `../Kubik-bible/director/`: the eight hardening rules (D34), which campfire (D35), per-player rumours (D36); the verb table goes (every signature is the free-text shape D34 forbids); the storm-scholar goes, the bible's stranger is a masked figure | `../Kubik-bible/director/00-principles.md`, `10-verbs.md`, D34-D36 |
| `docs/IDEAS.md` | the structure: Next 3, Someday, the ladder | Next 3 becomes the phases of RECONCILIATION § 9; Look v3 "the painted world" is replaced by the round 3 scene; the "Second Age" sea framing, island kingdoms and the lizardfolk homeland go (D26: the sea is rings two to four of the one world); campfire raids and the blood-moon dial go (the fire is where dread ends); Sites v1 inherits the four building families and the rings; fog, the lens and the far view become engine items | RECONCILIATION § 5 and § 8 |
| `docs/ROADMAP.md` | the shape: epics, territories, pushbacks | the epics become the phases (0 to 6) with 1b the mesher (D56) and 5 the world-truth break; the pushbacks are re-read against the pillars | RECONCILIATION § 9, `CLAUDE.md` § Working order |
| `TODO.md` | the checklist form | the waves become the phases; done items stay ticked with their dates | same |
| `docs/research/art-direction.md` | all of it, as evidence | a reading note at the top: evidence, not authority; its colour-transfer finding and its sampling method are still the method | RECONCILIATION § 8 |
| `docs/plans/look-v1.md`, `look-v2.md`, `look-v2-tech.md` | all of it, as history | one line at the top: superseded by `light-v1-tech.md`; `look-v2-tech.md` remains the work-order template | - |

## Gates

- Every `[[link]]` and relative path in a rewritten file resolves.
- Every decision cited exists in `../Kubik-bible/03-DECISIONS.md` under that
  number.
- `grep -rn "lizardfolk\|Second Age\|blood moon\|campfire raid\|1:4\|quarter-scale" README.md docs/*.md TODO.md`
  returns nothing outside `docs/reconciliation/`, `docs/research/`,
  `docs/plans/` and `docs/status/` (history keeps its words).
- `CLAUDE.md` § Where things live is updated so that no file is still
  marked "pending rewrite" once its rewrite has landed.

## Deliver

A short message: the files rewritten with their commits, what was left
because it already agreed, and the "For the bible" list, if any.
