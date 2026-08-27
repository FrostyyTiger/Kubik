class_name Push
extends RefCounted

## Players leaning on things, and what happens when enough of them do.
##
## THE CO-OP RULE, and it is one comparison. Every player whose capsule is
## touching a body, and who is WALKING INTO IT rather than merely resting
## against it, contributes `Locomotion.PUSH_FORCE_N` along the contact. The
## sums are collected per body and then, once per tick:
##
##     sum >= hold   the body wakes and takes the impulse - it goes
##     sum <  hold   the body stays asleep and ROCKS - it gives, and does not
##
## The rocking half is the important one and it is not decoration. A boulder_l
## that simply ignores one player is indistinguishable from scenery, and a
## player who cannot tell the difference stops trying. A boulder_l that shifts
## an inch and settles back says "not on your own" without a line of UI, which
## is pillar 1 stated in the only vocabulary the world has.
##
## HOST ONLY, hard rule 4. A client's push is an INPUT - it is walking into the
## rock - and the host measures the contact. There is no RPC that moves a body,
## and "move this rock to here" is the single most useful message a cheat could
## send.
##
## WHY IT IS A CLASS AND NOT A METHOD ON PlayerSim. The accumulator spans
## bodies AND players: the whole point is that two players pushing the same rock
## add up, so nothing that lives on one player can decide the outcome. This is
## the thing that sees all of them.

## How far a body tilts while it is being pushed but not moved, in degrees.
##
## Small on purpose. It has to read as "it gave" rather than as "it wobbled",
## and anything past a few degrees on a two-metre boulder starts to look like
## the physics has come loose.
const ROCK_DEGREES := 3.0

## How fast the tilt goes on and comes off, per second. Fast enough that it
## tracks a player leaning in, slow enough that walking past a rock does not
## flick it.
const ROCK_RATE := 6.0

## body id -> newtons accumulated this tick.
var _sum := {}

## body id -> the direction the push is coming from, horizontal and unit.
var _dir := {}

## How many player-into-body contacts have been seen since the last reset. A
## push that does nothing has two very different causes - no contact at all, or
## a contact that never reaches the hold - and from outside they are the same
## rock sitting still.
var contacts := 0


func clear() -> void:
	_sum.clear()
	_dir.clear()


## Collect one player's contacts. `wish` is its horizontal intent in world
## space - the same vector Locomotion moved it with.
##
## `get_slide_collision` is the right source rather than a shape query, because
## it reports exactly what actually blocked the body's own move this tick. A
## query would also find the rock a player is standing on top of, and standing
## on a boulder is not pushing it.
func add_player(body: CharacterBody3D, wish: Vector2) -> void:
	if wish == Vector2.ZERO:
		return  # resting against a rock is not pushing it
	var want := Vector3(wish.x, 0.0, wish.y).normalized()
	for i in body.get_slide_collision_count():
		var hit := body.get_slide_collision(i)
		var rock := hit.get_collider() as WorldBody
		if rock == null:
			continue
		# INTO IT, not along it. The contact normal points back at the player,
		# so the push direction is its opposite; a player sliding along a
		# boulder's flank has a wish almost perpendicular to that and
		# contributes almost nothing, which is right.
		var into := -hit.get_normal()
		into.y = 0.0
		if into.length_squared() < 0.0001:
			continue
		into = into.normalized()
		var lean := want.dot(into)
		if lean <= 0.0:
			continue
		var id: int = rock.id
		contacts += 1
		_sum[id] = float(_sum.get(id, 0.0)) + Locomotion.PUSH_FORCE_N * lean
		# The directions of several players are summed and normalised at the
		# end, so two people pushing opposite sides of the same rock cancel -
		# which is both correct and funnier than special-casing it.
		_dir[id] = (_dir.get(id, Vector3.ZERO) as Vector3) + into * lean


## Apply the tick's accumulated pushes. Returns the ids that are ROCKING - held
## against, but not hard enough - for the table's rock flag.
func apply(bodies: Dictionary, delta: float) -> Dictionary:
	var rocking := {}
	for id in _sum:
		var rock: WorldBody = bodies.get(id)
		if rock == null:
			continue
		var sum: float = _sum[id]
		var dir: Vector3 = _dir[id]
		if dir.length_squared() < 0.0001:
			continue  # pushed from both sides at once
		dir = dir.normalized()
		if sum >= BodyTable.hold_of(rock.kind):
			# IMPULSE, NOT FORCE, and multiplied by dt - so the same push moves
			# the same rock the same distance whatever the tick rate is. A
			# force applied to a sleeping body is discarded; shove() wakes it
			# first. See WorldBody.shove().
			rock.shove(dir * sum * delta)
			continue
		# NOTHING TO DO TO MAKE IT STAY. A body that has not been shoved is
		# frozen - see WorldBody.shove() - so "it rocks and stays" is the
		# default and this branch only records that it is being leaned on.
		rocking[id] = dir
	return rocking


## Ease a body's MESH toward the tilt its push direction implies, and return the
## new ease value for the caller to keep.
##
## THE MESH AND NOT THE BODY. Rotating the rigid body would rotate its collision
## shape, which would push back on the player who is leaning on it - and a
## boulder that shoves you away when you fail to move it is worse than one that
## does nothing at all. The shape stays exactly where it was; only what you see
## leans.
##
## THE EASE IS A SCALAR AND THE BASIS IS REBUILT, rather than slerping the
## mesh's own basis toward a target. The mesh carries the decoration's +-15%
## scale, and a basis that is both rotated and scaled does not interpolate as
## either of those things - the first version of this slerped between scaled
## bases and would have breathed every pushed rock in and out as it tilted.
##
## Shared by WorldBody and WorldBodyView so the host and every client tilt the
## same rock the same way by the same amount, from one implementation.
static func tilt(mesh: MeshInstance3D, dir: Vector3, scale_f: float,
		ease_t: float, delta: float) -> float:
	if mesh == null:
		return ease_t
	var want := 1.0 if dir.length_squared() > 0.0001 else 0.0
	var next := lerpf(ease_t, want, 1.0 - exp(-ROCK_RATE * delta))
	if next < 0.001 and want == 0.0:
		if ease_t >= 0.001:
			mesh.basis = Basis.IDENTITY.scaled(Vector3.ONE * scale_f)
		return 0.0
	# The axis to tip AROUND is perpendicular to the push and horizontal: push
	# north, tip about east. Vector3.UP.cross(dir) is exactly that, and it is
	# already unit because both inputs are.
	var axis := Vector3.UP.cross(dir if want > 0.0 else Vector3.FORWARD)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	mesh.basis = Basis(axis.normalized(), deg_to_rad(ROCK_DEGREES) * next) \
		.scaled(Vector3.ONE * scale_f)
	return next
