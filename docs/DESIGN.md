# Design

Settled details. Terse on purpose - this is a working doc.

Subject to the three pillars in the README. A line here that contradicts a
pillar is a bug in this file, not a licence to bend the pillar.

## Setting

Fantasy.

Playable races: human, elf, dwarf, more later. Cosmetic plus one small flavour
perk each. Not a balance lever - a race must never be the correct answer to a
fight.

No character classes.

## Character progression

Skill-by-use. Swing a sword, sword skill grows.

No skill trees, no allocation screens. Your "class" is what you carry and how
you behave, not something picked at character creation.

## Combat

Simple and readable. If a player cannot tell what just hit them, it is wrong.

- Light attack, dodge / block.
- Weapon types with distinct feel. Sword, bow, staff first.
- Enemies designed for duo tactics - encounters assume two bodies.

## Death

- Downed player can be revived by their partner.
- Otherwise respawn at the last campfire.
- While dead, the camera follows the partner.
- Costs time, not progress.

## Mounts

Planned for v0.3+. Speed and flavour, not a combat system.

## Multiplayer

- Host-authoritative. 1 host + 1 client. Never more.
- Both players must run the same build.
- ENet now, GodotSteam later behind the existing `NetTransport` interface.

The architecture contract these obey is in the README.
