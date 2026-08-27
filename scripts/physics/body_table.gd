class_name BodyTable
extends RefCounted

## WHAT A BODY IS, AS DATA (world feel v1 Stage 11).
##
## Habit 1 of the three (CLAUDE.md): facts as data, not prose in code. A
## director can only steer what it can read, and "how heavy is a boulder" is
## exactly the kind of fact that ends up as a literal inside three different
## functions if nobody writes a table on the day it is first needed. This is
## `Races` for things that roll.
##
## WHY BODIES AT ALL. Pillar 1 is BETTER TOGETHER, and the cheapest honest
## expression of it is a rock one person cannot move. `hold` is the whole
## design: a boulder_m gives way to one player, a boulder_l does not and gives
## way to two. Nothing in the game has to know what "two players" means - the
## push accumulator adds up whatever is leaning on the rock, and the rock
## compares the total against one number. Stage 12 spends that.
##
## THE HOST OWNS ALL OF IT. A body is a RigidBody3D on the host and a mesh on
## every client (see world_body.gd and world_body_view.gd). Hard rule 4: no RPC
## moves a body. A client's push is an input - it is walking into the rock -
## and the host measures the contact.

enum {
	BOULDER_M = 0,
	BOULDER_L = 1,
	LOG = 2,
}

const COUNT := 3

## kind -> its row.
##
##   model     the FloraModels id it is promoted FROM, and whose mesh it uses
##   mass      kg
##   hold      newtons of summed push that starts it moving (Stage 12)
##   damp      linear / angular damping, which is what decides how far it
##             rolls before it settles
##
## STARTING VALUES, ALL OF THEM, and tuned blind - nobody has pushed a rock
## yet. A player pushes with PUSH_FORCE_N (600, in Locomotion), so the holds
## below are "one player" and "two players" with a margin either side rather
## than numbers anybody measured.
const ROWS := [
	{
		"name": "boulder_m", "model": FloraModels.BOULDER_M,
		"mass": 250.0, "hold": 400.0,
		"linear_damp": 0.3, "angular_damp": 0.5,
	},
	{
		"name": "boulder_l", "model": FloraModels.BOULDER_L,
		"mass": 900.0, "hold": 1000.0,
		"linear_damp": 0.3, "angular_damp": 0.5,
	},
	{
		# NOT PROMOTED IN v1 - see promote() and the note there. The row is
		# here because the table's shape is the point: felled trees (roadmap
		# G) and Stage 12's push both want a long thing that rolls badly, and
		# a table with a hole in it invites a literal somewhere else.
		"name": "log", "model": -1,
		"mass": 120.0, "hold": 150.0,
		"linear_damp": 0.4, "angular_damp": 0.9,
	},
]

## The hash that decides promotion. Its own salt, so turning body_fraction up
## reveals bodies rather than reshuffling which rocks are which.
const SALT_BODY := 320


static func row(kind: int) -> Dictionary:
	return ROWS[clampi(kind, 0, COUNT - 1)]


static func name_of(kind: int) -> String:
	return row(kind)["name"]


static func hold_of(kind: int) -> float:
	return row(kind)["hold"]


## WHICH KIND, IF ANY, THIS DECORATION INSTANCE BECOMES.
##
## Pure, seeded and cheap: it takes the block the instance stands on and the
## model it was going to be drawn as, and answers with a kind or -1. Every peer
## runs it over its own columns and gets the same answer, which is what makes a
## body id agree across the network without anybody sending a list of rocks.
##
## THE FRACTION IS A PROPERTY, NOT A LOCAL KNOB (hard rule 5): it changes what
## the world CONTAINS, so it is hashed into the config. Two machines at
## different values would disagree about which rocks are pushable, and the
## symptom would be a friend heaving at a boulder that is scenery on your
## screen.
##
## LOGS ARE NOT PROMOTED HERE, and the reason is hard rule 1 rather than
## effort. The plan asks for `SNAG` instances under `log_fraction` to become a
## log lying beside the stump - but a snag is not a decoration, it is a TREE
## SPECIES stamped into the chunk as voxels (`TreeSpecies.SNAG`). Turning one
## into a body means not stamping its trunk, which changes what the world
## contains - and hard rule 1 says the heightmap, the config hash and the tree
## count move in Stages 5 and 6 only. See the status doc; it is Marcel's call
## whether to spend a hash move on it.
static func promote(model: int, bx: int, bz: int, world_seed: int,
		config: WorldgenConfig) -> int:
	var kind := -1
	match model:
		FloraModels.BOULDER_M:
			kind = BOULDER_M
		FloraModels.BOULDER_L:
			kind = BOULDER_L
		_:
			return -1
	if WorldHash.hash01(bx, bz, world_seed, SALT_BODY) >= config.body_fraction:
		return -1
	return kind
