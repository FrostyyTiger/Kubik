class_name Skills

## THE FIVE SKILLS, AS NAMES. That is the whole of this file today, and saying
## so is the point.
##
## HABIT 1, applied to something that does not exist yet. The character sheet
## renders these rows and a dash for each level; Skills v1 (J) replaces the
## dash with a number and does not touch the sheet's structure, because the
## sheet reads a table rather than knowing five things.
##
## THE SHEET IS READ-ONLY AND SO IS THIS (ui-v1.md, decision 6). "Skill chain"
## means DISPLAYING what levelled. Nothing is spent here, on the sheet, or
## anywhere else - the moment a sheet lets you spend, it is the skill tree this
## design rejected. The level-up toast belongs to Skills v1 too.
##
## The five are DESIGN.md's, in its order.
const NAMES := ["Blades", "Bows", "Magic", "Mobility", "Gathering"]

## What the sheet shows where a level will go. An em-dash, not a zero: a zero
## is a claim that the system exists and you have none of it, and a dash is the
## truth, which is that there is nothing to report yet.
const NO_LEVEL := "-"


static func count() -> int:
	return NAMES.size()
