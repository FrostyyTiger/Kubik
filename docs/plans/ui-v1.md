# UI v1 - the screen stays clean so the world reads huge

The **design** doc for the game UI: what the player sees while playing, what
opens when they press a key, and what deliberately does not exist. It is
opinionated on purpose.

It is not a build plan. The staged plan is `docs/plans/ui-v1-tech.md`, written
in a later run; the last section here is the list of things that plan has to
reckon with, not the plan itself.

Written 2026-08-31 on `main`, against `1ece781`. Nothing under `scripts/` was
touched by the run that produced it. Distance v3 is running in a parallel
lane; this doc and its tech plan stay out of `scripts/world/` entirely.

---

## How this doc was arrived at

Two things, in order. First a survey of what exists: the Deco theme is
project-wide, the menu and creation screens are finished, and the in-game HUD
is one debug label - no crosshair, no bars, no items, no stats, no scaling.
Second, a seven-question grilling of Marcel (2026-08-31), because three of his
asks collided with decisions already recorded in `ROADMAP.md` and
`DESIGN.md`. All seven came back answered. Where an answer overturns a
recorded decision, this doc says so out loud; where Marcel delegated a call
("minimal but usable - I trust you to make the right call"), the default is
stated here and marked as a default, not a law.

---

## The thesis

Minimal, so the world feels big. The game is fundamentally a free game you
can play RPG-wise - the Minecraft posture, not the MMO posture - and the UI
must say that: no this-goes-in-here item typing beyond the armour sockets,
no screen furniture that competes with a monumental horizon.

Two registers, matching the art direction:

- **The poster register** - menus, the character screen. Full Deco: Limelight
  titles, ink bands, ornaments, the turntable. These are posters you visit.
- **The field register** - the in-game HUD. Nearly nothing: one furniture
  cluster at the bottom centre, one thin strip at the top, and empty corners.
  When you are safe it fades to literally zero. The HUD is an instrument
  panel, and you only see instruments when you need them.

The fade is the load-bearing idea: the HUD itself joins the TENSE OUT, COZY
IN THE LIGHT register. Cozy *looks like* a clean screen with a huge world
behind it. Danger *looks like* instruments appearing.

---

## The seven decisions

### 1. No minimap. A compass strip.

Confirms the recorded pushback, and resolves it harder than recorded: the
escape hatch ("if Marcel wants the minimap anyway, it is an off-by-default
toggle") is not wanted. There is no minimap in any settings menu. Ever.

The compass strip - a thin horizontal band, top centre - is the navigation
UI, and it moves from Navigation v1 into this pass. At v1 it carries
cardinals and party-member bearings. Placed markers and site names join it
when those systems exist (E, H). The map *screen* - fog of exploration,
"ranging IS the progression" - stays in Navigation v1, untouched.

### 2. The hand is the active hotbar slot. Five slots. No weapon slot, anywhere.

The Minecraft model, chosen on purpose: what you hold is whatever hotbar
slot is active - weapon, torch, campfire, tool - and the character sheet
never has an "equipped weapon" box. The six gear sockets already declared in
`character_def.gd` stay what they are: armour, worn, visible on the body.

Five slots, not nine. Players never place raw voxel blocks (`DESIGN.md`),
so the hotbar will never hold stacks of dirt; it holds a restricted palette
of placeables plus tools and weapons. Five is honest for that. Keys 1-5 and
the mouse wheel select; the selection is visible on the bar and in the hand.

**Binding guidance for Items v1:** items are free-floating things in a bag,
Minecraft-style. No typed inventory slots beyond the armour sockets. When
the inventory screen arrives (G), it is a grid of stuff, not a paper-doll of
labelled holes.

### 3. The stats table comes forward: health, stamina, mana. All three, now.

Pulled from Combat v1 into this pass - habit 1 says facts as data, and bars
need facts. One table on the host, host-authoritative, synced to clients,
three thin bars from day one. Marcel's explicit call over a health-only
start: nothing drains stamina or mana yet, and that is accepted - the bars
are scaffolding for the systems that will move them (combat, sprint, magic).
When damage arrives it goes through the one mutation path, and stat changes
are journal events (habit 2), so the director can one day read "they limped
home at 3 health" without new plumbing.

### 4. The HUD fades out when you are safe.

The default definition of **safe**, all conditions at once: stats full,
nothing changed a stat in the last several seconds, the warm register holds
(daylight, or firelight when campfires exist), and local danger is low -
`danger_at()`, which the terrain already computes and nothing yet consumes,
gets its first consumer here. Any condition failing brings the HUD back.
Thresholds and curve times are tunables, not design; the compass strip may
keep a fainter floor opacity than the bars so navigation never fully
disappears. Exact behaviour is the tech plan's to propose and the playtest's
to judge.

### 5. Party presence: small icons, no floating nametags.

BETTER TOGETHER gets UI, but quiet UI. A small icon per party member (cap 4,
none shown solo), tucked at the screen edge by the furniture cluster - each
in its peer's golden-ratio hue, which already exists per player. A member's
health appears on their icon only when they are in danger (hurt, or downed);
healthy partners are just a presence, not a gauge. Bearing to each member
rides the compass strip.

**The floating `Label3D` nametag dies.** Marcel: it reads Minecrafty and
breaks immersion. In-world identity comes from silhouette, palette, and the
per-peer hue; the hue's new home is the party icon. A ping system is
deliberately deferred - noted, not designed.

### 6. The character screen: a paper-doll you read, not a form you fill.

One screen, opened with one key: the live turntable (the creation screen's
SubViewport rig, reused - this part is cheap), the six armour sockets, and
the five skills as read-only progress. "Skill chain" means *displaying* what
levelled - nothing is spent here, confirming the recorded decision: the
moment the sheet lets you spend, it becomes the skill tree this design
rejected. The level-up toast belongs to Skills v1, not this pass.

### 7. Scope: the foundation, and the queue is overridden to get it.

Marcel, 2026-08-31: "never mind the roadmap now... every foundational
prerequisite that is required for it to work, we should also do." Recorded
as an explicit queue jump - `ROADMAP.md`'s "each epic owns one UI slice"
still governs *later* slices (map screen in I, pause menus in F, level-up
toast in J, real inventory in G), but the frame they slot into is built now:

- the HUD framework and layout language (the field register),
- **display scaling** - the project currently sets no stretch mode; every
  Control is raw 1280x720 pixels. Fixed first, because everything else in
  this pass sits on it,
- the compass strip (cardinals + party bearings),
- the hotbar shell (five slots, selection, a stand-in use action so
  select-and-use is proven end to end before real items exist),
- the stats table and three bars, host-synced,
- the character screen (turntable, sockets, read-only skills),
- party icons, and the nametag removal.

---

## Defaults set on delegated trust

Direction-level, changeable in play, recorded so the tech plan does not
re-litigate them:

- **Layout.** One furniture cluster bottom-centre (hotbar, three thin bars
  stacked above it), the compass strip top-centre, party icons at the left
  edge of the cluster. The four corners of the screen stay empty. That is
  poster framing: the world is the picture, the UI is the mat.
- **No permanent crosshair.** A small context dot appears only when the held
  item can be aimed or placed. An empty hand means an unmarked screen.
- **Keys.** 1-5 and wheel for the hotbar; C for the character screen; Esc
  behaviour unchanged. F3/F4/F8 stay debug, untouched by the fade.
- **Style.** The field register uses the Deco kit sparingly - hairline
  rules, chamfered slot frames, ink on paper, the gold accent reserved for
  the *selected* hotbar slot and nothing else. No new fonts, no new colours.

## What this pass is not

No map screen (I). No ping system (later, on purpose). No inventory screen
or item table (G). No damage, no regen numbers, no combat (D). No pause or
settings menus (F). No spending anything, anywhere (J, and never on the
sheet). No minimap (never).

---

## What the tech plan has to reckon with

1. **Stretch mode.** Choosing `canvas_items` + expand (or arguing for
   something else) and auditing every raw-pixel assumption it lands on: the
   menu's 300x46 buttons, the ink-band placement math in `main_menu.gd`,
   the F4/F8 panels, `ui_shot.gd` output sizes.
2. **Stats sync.** The table lives on the host beside `_states`; whether
   bars ride the existing 20 Hz `_cl_sync_players` packet or a
   reliable-on-change RPC is the plan's call. Clients render, never decide.
3. **The mutation path and the journal.** Stat changes as journal events
   from day one; and while in that file - block edits are *still* not
   journalled despite being `CLAUDE.md`'s first example. Close that gap in
   the same pass.
4. **Fade inputs on the client.** `kubik_night` is a shader global written
   by `SkyCycle`; the UI needs the CPU-side value. `danger_at()` is
   deterministic from the shared generator, so clients can compute it
   locally - confirm, don't assume.
5. **Compass bearings.** Heading from camera yaw; party bearings from
   already-synced `_states` positions. No new network traffic.
6. **Nametag removal fallout.** `remote_player.tscn`'s Label3D and the code
   that feeds it; the per-peer hue survives and moves to the party icon.
7. **Turntable reuse.** `character_creation.gd` builds its rig in code;
   extract a shared helper rather than copy it.
8. **Tunables on F4.** Fade thresholds, timings, and floor opacities as
   `LOCAL_TUNING_ROWS`, so the feel is adjustable in play.
9. **Headless verification.** Every screen and HUD state (safe-faded,
   danger, hurt partner, sheet open) shot through the existing `--shot-ui`
   harness so the overnight run proves its work without a monitor.
10. **Solo is a dev convenience.** Zero party icons solo, fade logic that
    needs no partner, and the cap constant 4 respected everywhere.
