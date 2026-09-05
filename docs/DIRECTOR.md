# The Director - a pointer

Rewritten 2026-09-04 against the bible as of D84; where an older document
disagrees, the bible wins.

**The doctrine is not here any more.** It lives in
`../../Kubik-bible/director/`, and that folder is the direction:

| File | What it holds |
| --- | --- |
| `../../Kubik-bible/director/00-principles.md` | Marcel's eight principles and the eight hardening rules (D34) |
| `../../Kubik-bible/director/10-verbs.md` | the five verbs, their proposed fields, and what the host checks |
| `../../Kubik-bible/director/20-world-digest.md` | what the model is given to read |
| `../../Kubik-bible/director/30-roadmap.md` | v0, v1, v2, and what each needs |
| `../../Kubik-bible/director/40-open-questions.md` | what is still open |

What used to be in this file - the two-layer thesis, the cadence, the
steering doctrine, graceful degradation, the quest model - is in
`00-principles.md`, said the same way and decided (D34). This page keeps only
what the game repo has to know.

## The four things this repo must not get wrong

1. **The game owns all truth.** The model never invents world-truth. The host
   holds what exists, what characters know and want, which outcomes are
   possible, and a structured event log of what happened.
2. **Facts by ID (D34 rule 1).** A deterministic chronicler turns the raw
   event log into typed facts with IDs. **Every verb references IDs, never
   free text about the world.** This is the rule that killed the old verb
   table on this page: every signature it carried took a free description of
   the world (`place_fragment(text, site_type)`,
   `spawn_rumor(text, source, points_to)`,
   `mark_site(location_hint, flavor)`), which is exactly the shape D34
   forbids. The real signatures are in `10-verbs.md`.
3. **One mutation path.** Every verb is a proposal. The host validates it and
   applies it exactly as it applies a client's block edit. Nothing generative
   touches state directly. `README.md` § Architecture 2 is the path; habit 3
   in `CLAUDE.md` is the rule.
4. **The game is complete with the director off.** The template path ships
   first (D34 rule 5): a non-model generator fills the same slots from the
   same log, and the model is a better writer of identical structured output.
   Offline, with no key, or in a stranger's build, the defaults play.

## Cadence and scope, in one line each

- **Campfire cadence.** Invoked at campfire rests and at session start.
  State machines own seconds; the director owns minutes; combat never waits
  on a model call.
- **Which campfire (D35).** Generation by distance from the **capital**;
  pacing and threat by distance from the **current fire**. Two different
  dials, and this repo's `wildness` is the first one.
- **Per-player rumours (D36).** Rumours are delivered to one player at a
  time and the truth is shared, so players tell each other.
- **Opportunity, never walls.** A rumour, a light in a valley, a stranger's
  mention. It seduces; it never blocks or railroads.
- **Nowhere near seconds.** Behaviour trees, utility scores and planners own
  creature decisions. The seam is a verb: the director may `mark_site` a
  carcass; the wolves' tree decides what to do about it.

## The verbs, named only

`place_fragment`, `spawn_rumor`, `mark_site`, `advance_beat`,
`reroute_beat`. Five, and growing the list is a design act done in the bible,
not here. A verb takes IDs and a `voice`; no verb changes terrain, spawns
enemies or moves NPCs. **Any feature that needs the model to invent
world-truth or act outside the verbs is rejected and flagged** (`CLAUDE.md`
§ Rule).

The signs the director may light - `window_on`, `campfire_smoke`,
`crystal_glow`, `mask_hung`, `fog_lift`, `zeppelin_pass`, `lighthouse_lit` -
are the seduction vocabulary, and each belongs to a colour family. The table
is in `10-verbs.md`.

## What the pivot changed here (D74, D77, D79, D80, D83)

The lore moved on 2026-09-03 and three of its rulings land on the director:

- **The knowledge ladder rides `place_fragment` and adds no verb** (D74,
  D80). A Builder fragment is an authored site the game owns, unlocked by
  state with the director off; the director only makes it readable or
  noticeable. Five steps for the whole game, capped at one page of design.
  The ladder enters at **v1**, not v0 (`30-roadmap.md`).
- **The Engineers' frontier (D77) and the small falls (D83) are state
  machines.** The highest mine head advances by a fixed rule over play time;
  a lamp goes dark in the capital, an engine runs wild at a mine head. They
  run with the director off at every version; the director only points at
  them. Two signs are proposed for them and not yet in the art bible's list:
  `lamp_dim` and `engine_wild`.
- **The stranger is not the storm-scholar.** v2's one NPC was written here
  as the *garabonciás* storm-scholar; that archetype is gone with the old
  setting. The bible's stranger is a masked figure whose people is open, and
  what v2 actually requires is a knowledge set by fact and rumour IDs, a goal
  the game owns, speech tagging (D34 rule 8) and an "I don't know" default.
  The Engineer expedition going outward (D79) is a candidate for it
  (`40-open-questions.md`).

## The roadmap, and where this repo is on it

`30-roadmap.md` holds v0, v1 and v2 with what each needs. The gate on all
three is in `CLAUDE.md`: **base-game milestones precede director
milestones**, and the director's v0 needs the journal, the campfire and a
first creature playtest before any model call exists. Under the working
order that is phase 6, after the world-truth break, people and fire,
buildings and the round 3 scene.

## What the code does about it today

The three habits in `CLAUDE.md` and architecture decision 6 in `README.md`:
facts as data, the host's journal, everything through the one mutation path.
The journal today is untyped dictionaries held in memory; the bible asks for
typed facts with IDs, a chronicler, salience and persistence, and that redo
is on the list in `RECONCILIATION.md` § 6. Godot needs nothing added -
`HTTPRequest` and `WebSocketPeer` are built in and the model never runs
in-engine.
