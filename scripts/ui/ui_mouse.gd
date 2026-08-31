class_name UiMouse

## WHO WANTS THE CURSOR. A set of owners, not a boolean.
##
## Until ui v1 Stage 2 this was `DebugHUD.ui_has_mouse`, one static bool that
## every screen wanting the pointer wrote true and then false. With two screens
## that is a latent bug and with three it is a real one: open F4, open F8,
## close F8, and the cursor is recaptured while F4 is still on screen and still
## unclickable. The boolean cannot represent "somebody else still wants it",
## because it does not know how many somebodies there are.
##
## A set does. The mouse becomes VISIBLE on the FIRST claim and CAPTURED again
## on the LAST release, and any number of screens in between is just an entry.
## The character sheet (Stage 6) is the third owner and needed this to exist
## before it could be written.
##
## STATIC, like the flag it replaces, and for the same reason: the player's
## camera checks this before grabbing the cursor back and has no reference to
## any UI at all. Threading one through for this would be a lot of plumbing to
## express "is anything open".
##
## Owners are held by reference and never by name, so a screen cannot release
## another screen's claim by guessing a string - and a screen that is freed
## while holding a claim is the one failure mode left. That is what
## `release_freed()` is for; every owner here is a CanvasLayer that lives as
## long as the scene, so it is insurance rather than a code path in use.

static var _owners: Array = []


## This object wants the cursor. Idempotent: claiming twice is one claim.
static func claim(owner: Object) -> void:
	if owner == null or _owners.has(owner):
		return
	_owners.append(owner)
	_apply()


## This object is done with the cursor. Harmless if it never claimed.
static func release(owner: Object) -> void:
	var i := _owners.find(owner)
	if i < 0:
		return
	_owners.remove_at(i)
	_apply()


## Does anything want the cursor right now?
static func held() -> bool:
	return not _owners.is_empty()


## How many owners. For the F3 readout and the self-test.
static func count() -> int:
	return _owners.size()


## Drop every owner. Used when a scene is torn down, so a claim cannot survive
## into the next one - the set is static and the scene is not.
static func clear() -> void:
	if _owners.is_empty():
		return
	_owners.clear()
	_apply()


## Drop any owner that has been freed out from under us, then re-apply.
##
## An owner that is freed while holding a claim would otherwise hold the cursor
## visible forever with nothing on screen to explain it.
static func release_freed() -> void:
	var before := _owners.size()
	_owners = _owners.filter(func(o): return is_instance_valid(o))
	if _owners.size() != before:
		_apply()


static func _apply() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if held() \
		else Input.MOUSE_MODE_CAPTURED
