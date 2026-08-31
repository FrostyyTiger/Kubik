class_name StatsTable
extends RefCounted

## Health, stamina and mana, for everybody, on the host.
##
## HABIT 1 OF THE THREE (CLAUDE.md): facts as data. The bars in ui v1 read
## THIS, and a director reading the journal one day will find "they limped home
## at 3 health" already written down - because every change goes through
## apply_delta(), which journals.
##
## ALL THREE STATS FROM DAY ONE, and nothing drains any of them yet. That is
## Marcel's explicit call over a health-only start (ui-v1.md, decision 3): the
## bars are scaffolding for the systems that will move them - combat, sprint,
## magic - and a table that grows a column later is a table every consumer has
## to be revisited for.
##
## HOST ONLY. A client renders what the host's row says and never writes one;
## DESIGN.md's networking section forbids trusting a client about its own
## stats, and there is nothing here to predict anyway - a stat is not a
## position, there is no input sequence to reconcile against.
##
## THERE IS NO DEATH IN THIS TABLE. Health reaching 0 clamps at 0 and does
## nothing else: no respawn, no downed state, no event beyond the stat_changed
## every change produces. Combat v1 owns what 0 means, and inventing it here -
## before there is damage to reach it with - is how a rule ends up written in
## the place nobody looks for it.

## The starting value of each stat AND its maximum, in one place.
##
## Maxima equal defaults until a system says otherwise, and BOTH are data in
## this const rather than a number in apply_delta's clamp - which is the whole
## of habit 1 applied to five lines. A racial health bonus or a mana pool that
## grows with Magic changes this table and nothing else.
const DEFAULTS := {
	"hp": 100.0,
	"sp": 100.0,
	"mp": 100.0,
}

## The stat names, in the order the bars stack. Derived from DEFAULTS rather
## than written twice, so a fourth stat cannot be added to one and not the
## other.
const ORDER := ["hp", "sp", "mp"]

## peer_id -> {hp, sp, mp}. Absent until ensure_row().
var _rows := {}

## Injected by Game, exactly as BodyField's is. Null is fine: a table with no
## journal still clamps correctly, which is what the self-test builds.
var _journal: Journal = null


func set_journal(journal: Journal) -> void:
	_journal = journal


## Give this peer a row of defaults if it has none. Idempotent - a peer that
## rejoins keeps whatever it had, and calling this on every world ready is
## cheaper than remembering whether it was called.
func ensure_row(peer_id: int) -> void:
	if _rows.has(peer_id):
		return
	_rows[peer_id] = DEFAULTS.duplicate()


func erase(peer_id: int) -> void:
	_rows.erase(peer_id)


## One peer's stats, or an empty dictionary. A COPY: the only way to change a
## stat is apply_delta, and handing out the live row would make that a
## suggestion rather than a rule.
func get_row(peer_id: int) -> Dictionary:
	return (_rows[peer_id] as Dictionary).duplicate() if _rows.has(peer_id) else {}


func has_row(peer_id: int) -> bool:
	return _rows.has(peer_id)


func peer_ids() -> Array:
	return _rows.keys()


## THE ONE MUTATION SEAM. Nothing else in the game writes a stat.
##
## Returns the value AFTER the change, clamped to [0, max]. `cause` is a short
## string that goes straight into the journal - "fall", "wolf", "regen",
## "debug" - because a director reading a run wants to know what took the
## health, and reconstructing that from a number is not possible.
##
## A delta that changes nothing journals nothing. Regen ticking against a full
## bar is the case that matters: at 20 Hz it would otherwise write 1200 events
## a minute that all say the same thing, and a journal nobody can read is the
## same as no journal.
func apply_delta(peer_id: int, stat: String, delta: float, cause: String) -> float:
	if not DEFAULTS.has(stat):
		push_warning("[Stats] no such stat: %s" % stat)
		return 0.0
	ensure_row(peer_id)
	var row: Dictionary = _rows[peer_id]
	var from: float = row[stat]
	var to := clampf(from + delta, 0.0, float(DEFAULTS[stat]))
	if is_equal_approx(to, from):
		return from
	row[stat] = to
	if _journal != null:
		_journal.log_event("stat_changed", {
			"peer": peer_id, "stat": stat, "from": from, "to": to,
			"cause": cause})
	return to


## Is every stat of this peer at its maximum? The fade's first condition
## (Stage 4), asked of the table rather than computed by the thing asking.
func is_full(peer_id: int) -> bool:
	if not _rows.has(peer_id):
		return true
	var row: Dictionary = _rows[peer_id]
	for stat in ORDER:
		if not is_equal_approx(float(row.get(stat, 0.0)), float(DEFAULTS[stat])):
			return false
	return true


## The fraction of maximum, 0..1, for a bar to draw. Reads a row that may have
## come off the wire rather than out of this table, so a client can use the
## same function on its copy.
static func fraction_of(row: Dictionary, stat: String) -> float:
	if not DEFAULTS.has(stat):
		return 0.0
	var maximum := float(DEFAULTS[stat])
	if maximum <= 0.0:
		return 0.0
	return clampf(float(row.get(stat, maximum)) / maximum, 0.0, 1.0)
