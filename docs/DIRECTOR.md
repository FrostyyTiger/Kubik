# The Director - design & architecture doctrine

The fourth pillar, THE WORLD ANSWERS, as doctrine. Settled 2026-08-25. Terse
on purpose, like `DESIGN.md`; a line here that contradicts a pillar is a bug
in this file.

## Thesis

LLM value in games is not chatbot NPCs. It is **goal-directed improvisation
under constraints** - a game master: authored destinations and stakes,
emergent paths. Reference experience: how a coding agent holds fixed
requirements but routes creatively to meet them.

## Two-layer architecture - the core discipline

- **AUTHORED TRUTH** (game state, in code): what is real, what exists where,
  what characters know and want, what outcomes are possible, and what
  actually happened (the event log). **The model never invents
  world-truth.**
- **GENERATIVE DIRECTION** (the model): reads true state plus the event log,
  and improvises expression and routing WITHIN it.

## The verb list - the enforcement mechanism

The director acts ONLY through a small set of verbs the game exposes. The
initial set:

| Verb | What it does |
| --- | --- |
| `place_fragment(text, site_type)` | a piece of found writing appears at a site of that type |
| `spawn_rumor(text, source, points_to)` | a rumour enters the world, from a source, pointing somewhere |
| `mark_site(location_hint, flavor)` | a place is flagged with a flavour for later authored content to use |
| `advance_beat(quest, beat)` | a quest moves to its next authored beat |
| `reroute_beat(quest, alternative)` | a quest takes an authored alternative to its next beat |

Growing this list is a design act, done deliberately and recorded here.
**Any feature requiring the director to invent world-truth or act outside
the verbs is REJECTED.** Every verb's effect goes through the host's one
mutation path, validated like a client's block edit; the director proposes,
the host applies.

## Cadence

The director is invoked at **campfire rests** - the natural story-beat pause,
where latency is irrelevant - and at session start. Combat and
moment-to-moment play NEVER wait on the model. **State machines own seconds;
the director owns minutes.**

## Steering doctrine

Opportunity, never walls. The director seduces - a rumour, a light in a
valley, a stranger's mention - and never blocks, forces or closes a path. If
players ignore every hook, the world stays fully playable.

## Graceful degradation - non-negotiable

The game must be complete and fun with the director OFF: for players of the
open-source build with no API key, for offline sessions, and to keep us
honest about the base game. **The director is the haunted layer, not a
load-bearing wall.** Director calls run host-side on the host's API key;
strangers' builds default to off.

## Quest model

Beats are authored - the spine: what must be true at each stage, verifiable
in game state. The connective tissue between beats is directed. Verification
grounds in mechanical state: **the game must KNOW a beat completed, never
take the model's word for it.**

## Risk, named

This doubles the project's research content. Some director experiments will
fail. That is expected and affordable under the fun-first utility function.
**The base game's milestones are unchanged by the director's existence and
always come first** - `CLAUDE.md` carries this as a rule.

## Roadmap

- **v0 - "the world remembers".** At the campfire, fragments and rumours
  generated from the true event log appear. Read-only reflection, no quest
  logic. First build after the wolf / marmot / eagle playtest works.
- **v1 - "the world beckons".** Rumour-driven quest routing on authored beat
  spines.
- **v2 - "the stranger speaks".** One NPC - the storm-scholar, the
  *garabonciás* archetype - with fixed goals, knowledge bounds, and
  generative speech. Uncanny is lore-correct for him.

Beyond v2 is the Director ladder in `docs/IDEAS.md`.

## What the code does about it today

The three habits in `CLAUDE.md` and architecture decision 6 in `README.md`:
facts as data, the host's journal, everything through the one mutation path.
Godot needs nothing added - the model never runs in-engine; `HTTPRequest`
and `WebSocketPeer` are built in for the sidecar.
