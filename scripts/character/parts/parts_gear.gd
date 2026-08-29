class_name PartsGear

## Three placeholders that hang on three sockets.
##
## HAND-WRITTEN AND PERMANENT. The geometry left for
## `assets/characters/parts/gear.json` in parts-data v1; this table is what
## stayed, because an index from a socket to a part is not itself a part.
##
## THIS IS NOT A GEAR SYSTEM. There are no slots on CharacterDef, nothing on
## the wire, and no stats. THE SOCKETS ARE THE DELIVERABLE; the three items
## exist to prove them - that a thing attached to `hand_r` swings with the
## arm, a thing on `chest` rides the sprint lean, and a thing on `neck` stays
## put through a sit. The gear plan owns everything past that.

## Socket name -> the name of the part that hangs on it, in the `gear` module.
##
## THE TWO NAMES ARE THE SAME NAME TODAY, and the indirection is kept anyway:
## a placeholder is named for the socket it proves, which is a fact about
## these three items and not a fact about sockets. The first real item hung on
## `hand_r` will not be called `hand_r`.
##
## The other three sockets - `hand_l`, `back` and `belt` - get nothing, and
## that is the point: they exist on every race whether or not anything is
## hanging on them.
const PLACEHOLDERS := {
	"hand_r": "hand_r",
	"chest": "chest",
	"neck": "neck",
}
