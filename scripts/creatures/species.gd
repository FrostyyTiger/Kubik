class_name Species

## The three creatures, as data. Senses, speeds, slope costs, territory, home,
## and what a bite is worth.
##
## EVERY PER-SPECIES NUMBER IN THE GAME LIVES HERE. This is `Races` doctrine
## (`scripts/character/races.gd`) applied to animals, and it is hard rule 5 of
## `docs/plans/creatures-v1-tech.md`: `wolf.gd` must not contain a single
## number from this file, and the way to guarantee that is for there to be
## exactly one file that has them. A future enemy is then a row here plus a
## behaviour tree, which is design decision 2 - "the groundwork is the
## deliverable" - stated as a file rather than as an intention.
##
## It is also habit 1 of the three (`CLAUDE.md`): facts as data, not prose in
## code. A director can only steer what it can read, and a table it can read is
## the difference between "the wolves are dangerous" being a fact about the
## world and being a paragraph inside somebody's `_process`.
##
## THE NUMBERS BELOW ARE PROPOSALS. Every one of them is an F10 row and every
## one of them is listed in `docs/status/creatures-v1.md` with its starting
## value, because this run happens on a headless box and nothing here was
## chosen by watching a wolf.


enum {
	WOLF = 0,
	MARMOT = 1,
	EAGLE = 2,
}

const SPECIES_COUNT := 3
const SPECIES_NAMES := ["wolf", "marmot", "eagle"]


# --- The shared numbers ------------------------------------------------------
#
# NOT PER-SPECIES, and kept here anyway. These are numbers the plan chose by
# feel rather than facts about an animal, and hard rule 5's real point is that
# a number chosen by eye must live somewhere a panel can reach - which is this
# file, because a second numbers file is how two numbers files start disagreeing.

## How loud a player is, in metres of hearing radius consumed, by what they are
## doing. Multiplied against the listening creature's own `hear_m`, so a
## sprinting player is heard at 1.5 times the range a walking one is.
##
## THE STILL CASE IS NOT ZERO, and that is a design statement rather than a
## rounding. A player standing perfectly still is quiet, not absent: breathing,
## gear, a shifted boot. 0.3 means you can be found by standing in the wrong
## place, which is the difference between stealth being a skill and stealth
## being a switch.
## ...and how far a walking player's noise carries, in metres.
##
## THE TWO HALVES ARE CALIBRATED AGAINST EACH OTHER, and this constant is what
## makes that true. A noise states its carry in METRES - `emit_noise` takes
## `loudness_m` and nothing has to know who is listening - and a listener's
## `hear_m` is its range FOR A NOISE THAT CARRIES THIS FAR. So the audibility
## test is `distance <= hear_m * (loudness_m / reference_m)`, and a wolf with
## `hear_m` 30 hears a walking player at 30 m, a sprinting one at 45 and a
## still one at 9, while the marmot's 45 scales all three up together.
##
## Without a reference the two units cannot be reconciled: `min(loudness_m,
## hear_m)` makes a sprint and a walk identical to any listener whose hearing
## is the shorter of the two, which is every listener that matters.
const NOISE := {
	"sprint": 1.5,
	"move": 1.0,
	"still": 0.3,
	"reference_m": 30.0,
}

## Brain ticks per second, staggered across the live creatures. Hard rule 8.
##
## Ten, not sixty: a decision is a thing an animal makes a few times a second
## at most, and the MOVEMENT between decisions is smooth because movement is
## not a decision - it is the path being followed at frame rate.
const BRAIN_HZ := 10.0

## The most creatures alive at once, anywhere. Hard rule 8.
const MAX_LIVE := 16

## Sync rows per second from the creature server, and how far they carry.
## Decision 3, copying the BodyField school (`body_field.gd`).
const SYNC_HZ := 20.0
const REPLICATE_RANGE_M := 128.0
const ROWS_PER_PACKET := 16


# --- The table ---------------------------------------------------------------

## One row per species, indexed by the enum above.
##
## `dims` IS CRITTER-DIMS-SHAPED, AND FOR THE WOLF IT IS THE CRITTER'S EXACTLY.
## Night 1 has no wolf model - decision 4 puts every creature in the critter's
## body and gives the wolf its own parts on night 2 - so the wolf's dims are
## `PartsCritter.DIMS` written out here rather than referenced, which is the
## point: night 2 changes these numbers and nothing else has to move. The
## marmot's and the eagle's already differ, and until their models exist a
## stride computed from them would disagree with the critter geometry actually
## on screen. Neither is spawned tonight, so neither can.
const TABLE := [
	{
		"name": "wolf",
		# THE RUSHER of DESIGN.md's launch roster, and the trio's threat layer.
		"archetype": "rusher",
		"gait": "trot",
		"dims": {
			"name": "wolf", "total": 22, "legs": 10, "torso": 12, "head": 12,
			"torso_w": 12, "torso_d": 12, "head_w": 12, "head_d": 18,
			"leg_w": 4, "arm_len": 0, "arm_w": 0,
			"gait": "trot", "lean_deg": 0.0,
		},
		# Walks its patrol, runs when it has a target. The run is well over the
		# player's 4.4 m/s walk and under their sprint, which is the shape the
		# encounter needs: you cannot stroll away from a wolf and you can
		# outrun one if you commit to it - and committing to it is how you end
		# up somewhere worse, which is the third pillar doing its job.
		"walk_mps": 2.0,
		"run_mps": 7.5,
		# Sight is a CONE, not a radius - rule 1 of DESIGN.md's five. 110
		# degrees is a predator's forward field, wide enough to be threatening
		# and narrow enough that behind it is a real place to be.
		"sight_m": 40.0,
		"sight_deg": 110.0,
		# HEARING IS THE LONG-RANGE SENSE AND SIGHT IS THE CONFIRMATION, which
		# is a correction rather than a preference, and `senses-honest` is what
		# forced it.
		#
		# It was 30 m against 40 m of sight. A wolf patrols a beat around its
		# den and sees 40 m from wherever it has got to, so its EYE reaches
		# `patrol + 40` from home while its EAR reaches only `1.5 * hear_m`
		# from itself. With hearing shorter than sight there is NO position in
		# the world where a sprinting player is heard but a still one is not
		# seen: the noise channel is vestigial, what the player is DOING never
		# decides anything, and DESIGN.md rule 1's "a wolf players LEARN" has
		# nothing to teach.
		#
		# 60 m makes the ear half again the eye. A sprinting player is heard at
		# 90 m and a still one at 18; the wolf's beat is 45 m; so there is a
		# comfortable band - about 85 to 90 m from the den - in which standing
		# still is genuinely safe and running is genuinely not. Real wolves
		# hear over kilometres, so if anything this is still shy.
		"hear_m": 60.0,
		# What the ground costs this animal, for the territory A* in
		# creature_nav.gd. A wolf pays for climbing and is happy to drop, which
		# is what puts it on the contour rather than over the crest - and the
		# ibex, when it arrives, is the same table with the signs the other way
		# round. Terrain use as one weight table, per DESIGN.md.
		# `cliff_deg` IS THE PLAYER'S OWN FLOOR ANGLE, and that is a decision
		# rather than a feel. `Locomotion.FLOOR_MAX_ANGLE_DEG` is 55, so a
		# wolf can go anywhere a player can go and nowhere they cannot. Set
		# lower - it was 42 for one stage - the rusher is LESS mobile than the
		# thing it is chasing, which quietly deletes the encounter: you escape
		# by walking up a hill you can walk up and it cannot. It also mattered
		# more than it looked: this world's mean slope is 30.7 degrees and a
		# third of it is over 45, so 42 marked two thirds of a real territory
		# impassable and the pack had nowhere to go.
		"slope_cost": {"uphill": 2.6, "downhill": 0.8, "cliff_deg": 55.0},
		# The honest leash (design decision 6). A chase ends because the pack
		# turns back at its border, not because a timer despawned it.
		"territory_m": 150.0,
		"home": "den",
		"pack": 2,
		# THE FLANK IS EXPLICIT. A converging member takes a bearing this far
		# off the howler's, so the gate in Stage 6 measures a mechanism rather
		# than luck. Pillar 1's flanking, mirrored back at the players.
		"flank_deg": {"min": 90.0, "max": 140.0},
		# Real wildlife, so huntable - DESIGN.md's cozy-honest rule.
		"huntable": true,
		# DISARMED TONIGHT, and built to full shape anyway (design decision 4 /
		# hard rule 6). `damage` is proposed through the mutation path and
		# journaled with `applied: 0`; arming it is one line in night 2, after
		# feat/ui-v1's StatsTable has landed.
		"bite": {"damage": 15.0, "range_m": 2.2, "cooldown_s": 1.6},
		"silhouette": "low, level back, head carried below the shoulder",
	},
	{
		"name": "marmot",
		# The ground texture and the information layer. Not a threat and never
		# a target: it whistles and it dives, and that is the whole animal.
		"archetype": "ambient",
		"gait": "trot",
		"dims": {
			"name": "marmot", "total": 14, "legs": 5, "torso": 9, "head": 9,
			"torso_w": 10, "torso_d": 10, "head_w": 9, "head_d": 11,
			"leg_w": 3, "arm_len": 0, "arm_w": 0,
			"gait": "trot", "lean_deg": 0.0,
		},
		"walk_mps": 1.0,
		"run_mps": 4.5,
		# PREY EYES: shorter than a wolf's and very much wider. A sentry on its
		# hind legs sees most of the bench at once, which is what makes the
		# whistle arrive before you have seen the marmot.
		"sight_m": 30.0,
		"sight_deg": 240.0,
		# And it hears further than it sees, which is the other half of why it
		# is a danger radar.
		"hear_m": 45.0,
		# Lower than the wolf's on purpose: a marmot lives on its bench and
		# gives up on a slope sooner than a person would. It never leaves the
		# bench anyway, so this number is about where it forages.
		"slope_cost": {"uphill": 1.4, "downhill": 1.0, "cliff_deg": 45.0},
		# It lives on its bench and never leaves it.
		"territory_m": 40.0,
		"home": "burrow",
		"pack": 4,
		"flank_deg": {"min": 0.0, "max": 0.0},
		# NOT HUNTABLE, and this column IS the cozy-honest rule. DESIGN.md:
		# "they simply cannot be targeted." No mechanical punishment needed
		# because there is no mechanism to punish.
		"huntable": false,
		"bite": {"damage": 0.0, "range_m": 0.0, "cooldown_s": 0.0},
		"silhouette": "an upright thumb on a rock, or a low brown wedge running",
	},
	{
		"name": "eagle",
		# The sky texture. Circles, cries, lands on crags, never interacts -
		# DESIGN.md's first ambient-sky creature, and in v1 that is all it is.
		"archetype": "sky",
		"gait": "trot",
		"dims": {
			"name": "eagle", "total": 12, "legs": 3, "torso": 7, "head": 7,
			"torso_w": 8, "torso_d": 14, "head_w": 7, "head_d": 9,
			"leg_w": 2, "arm_len": 0, "arm_w": 0,
			"gait": "trot", "lean_deg": 0.0,
		},
		# `walk_mps` is the perched shuffle and is nearly meaningless; the orbit
		# speed is the one that matters.
		"walk_mps": 0.8,
		"run_mps": 18.0,
		"sight_m": 120.0,
		"sight_deg": 90.0,
		# ALOFT AND DEAF, deliberately: an eagle at 80 m does not react to a
		# footstep, and giving it a hearing radius would have it notice things
		# it has no business noticing. Zero here is a statement.
		"hear_m": 0.0,
		# It does not walk anywhere, so its ground costs are the flattest
		# possible - they exist so that the accessor never has a hole in it.
		"slope_cost": {"uphill": 1.0, "downhill": 1.0, "cliff_deg": 90.0},
		"territory_m": 400.0,
		"home": "crag",
		"pack": 1,
		"flank_deg": {"min": 0.0, "max": 0.0},
		"huntable": false,
		"bite": {"damage": 0.0, "range_m": 0.0, "cooldown_s": 0.0},
		"silhouette": "a long flat crossbow against the sky, wings barely moving",
	},
]

## Every key a row must carry. The selftest walks this against every row, so a
## species added without a hearing range fails loudly at the bench rather than
## quietly at 3 a.m. in a probe run.
const REQUIRED_KEYS := [
	"name", "archetype", "gait", "dims", "walk_mps", "run_mps",
	"sight_m", "sight_deg", "hear_m", "slope_cost", "territory_m",
	"home", "pack", "flank_deg", "huntable", "bite", "silhouette",
]

## And the keys inside the two nested dictionaries.
const REQUIRED_SLOPE_KEYS := ["uphill", "downhill", "cliff_deg"]
const REQUIRED_BITE_KEYS := ["damage", "range_m", "cooldown_s"]


# --- THE EVENT SCHEMA --------------------------------------------------------
#
# Decision 8 of the tech plan, and habit 2 of the three (CLAUDE.md): keep the
# journal. These are the kinds a creature writes into `Journal` (see
# scripts/game/journal.gd), and THIS COMMENT IS THE SCHEMA - the probe's
# evidence, Stage 6's gates, and eventually the stream the director reads are
# all the same rows, so the schema is written here once rather than being
# implied three times.
#
# `Journal.log_event` adds `kind` and `t` (ms since session start) to every
# row. EVERY CREATURE EVENT ALSO CARRIES, WITHOUT EXCEPTION:
#
#     species  int      an index into TABLE above
#     id       int      the creature's server id, or the home's identity
#     pos      Vector3  where it happened, in metres
#
# ...and then its own fields. Night 1 writes these eight:
#
#     den_placed   {home: String, danger: float, slope_deg: float}
#                  A home was placed by HomePlacement. `id` is the home's
#                  packed identity, not a creature's. The first "the world got
#                  an address" event, and Sites v1's first site_type row.
#     spotted      {target: int, range_m: float}
#                  A creature's sight cone found a player. `target` is a peer
#                  id. This is the ONLY way a creature learns where a player
#                  is by sight - hard rule 4.
#     lost         {target: int, seconds: float}
#                  ...and stopped seeing them, having seen them for `seconds`.
#     howl         {target: int, bearing_deg: float}
#                  First confirmed sight, broadcast to the pack. `bearing_deg`
#                  is the howler's bearing to the target, world space, and it
#                  is what the converging members offset from.
#     converge     {target: int, bearing_deg: float, offset_deg: float}
#                  A member took a flanking bearing off the howl. `offset_deg`
#                  is what it added, and is the mechanism the pack-flank gate
#                  measures.
#     engage       {target: int, range_m: float, bearing_deg: float}
#                  Reached bite range and started circling. Two of these at
#                  once, from bearings 90 degrees apart, IS the flank.
#     bite         {target: int, damage_proposed: float, applied: float}
#                  A lunge landed. `applied` IS ALWAYS 0.0 ON NIGHT 1 - hard
#                  rule 6 - and the field exists now so that arming it in
#                  night 2 changes a value rather than a schema.
#     investigate  {kind: String, range_m: float, loudness_m: float}
#                  A noise reached this creature and it went to look. `kind` is
#                  what the noise was ("player", "howl"). THE ONLY EVENT THAT
#                  IS ABOUT HEARING, which is why it exists - see EVENT_KINDS.
#     leash_turn   {home: int, over_by_m: float}
#                  The target or the creature left the territory, so the
#                  creature turned back. Design decision 6's honest leash: a
#                  chase that ends at a border, written down.
#
# RESERVED FOR NIGHT 2, named here so the schema is one document rather than
# two: `whistle` (marmot alarm, the same PackBoard broadcast the howl is),
# `dive` and `emerge` (burrow), `cry` and `perch` (eagle).


## The kinds above, as data rather than as prose in the comment alone.
##
## HABIT 1 (CLAUDE.md): facts as data. The probe filters the journal for the
## creature slice, and a filter written as a literal list in the probe is a
## second copy of this schema that drifts from the first by the third stage.
## `investigate` IS A NINTH KIND, ADDED AGAINST DECISION 8's LIST OF EIGHT.
##
## Recorded rather than slipped in. The tech plan's `senses-honest` gate is
## written as "the same position sprinting IS INVESTIGATED within 20 s", and
## there is no way to observe an investigation in a journal that has no word
## for one. The alternative was to gate on `spotted` instead - to wait for the
## wolf to hear the noise, walk 50 m to it, and lay eyes on the player - which
## measures the ear, the legs and the terrain in between, and takes minutes
## rather than seconds to say something about hearing.
##
## The rest of Decision 8 stands: this is a thing that HAPPENED, it carries
## `{species, id, pos}` like everything else, and it is documented in the
## schema above rather than only existing in code.
const EVENT_KINDS := [
	"den_placed", "spotted", "lost", "howl",
	"converge", "engage", "bite", "leash_turn", "investigate",
]

## Named now so the schema is one document rather than two. Night 2 moves
## these up into EVENT_KINDS as it builds the marmot and the eagle.
const EVENT_KINDS_RESERVED := ["whistle", "dive", "emerge", "cry", "perch"]


## Is this journal row one of ours? The probe's slice, and eventually the
## director's.
static func is_creature_event(kind: String) -> bool:
	return EVENT_KINDS.has(kind) or EVENT_KINDS_RESERVED.has(kind)


# --- Accessors ---------------------------------------------------------------

## Warned-about species, so an unknown one is reported once rather than sixty
## times a second. The `Races._warn_once` pattern, copied for the same reason.
static var _warned := {}


static func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


## Clamp to a species that exists.
##
## A WARNING AND A FALLBACK, NOT A CRASH, and the wolf is the fallback because
## it is the only species with every column filled in for real. A creature that
## turns out to be a wolf is a visible bug; a creature that fails to exist is
## an invisible one.
static func valid(species: int) -> int:
	if species < 0 or species >= SPECIES_COUNT:
		_warn_once("species:%d" % species,
			"[Species] no species %d - falling back to the wolf" % species)
		return WOLF
	return species


static func name_of(species: int) -> String:
	return SPECIES_NAMES[valid(species)]


## Species index from a name, or -1. For the probe's `--species` argument and
## for anything reading a table row back.
static func from_name(text: String) -> int:
	return SPECIES_NAMES.find(text.strip_edges().to_lower())


static func table(species: int) -> Dictionary:
	return TABLE[valid(species)]


static func dims(species: int) -> Dictionary:
	return table(species)["dims"]


static func archetype(species: int) -> String:
	return table(species)["archetype"]


static func walk_mps(species: int) -> float:
	return table(species)["walk_mps"]


static func run_mps(species: int) -> float:
	return table(species)["run_mps"]


static func sight_m(species: int) -> float:
	return table(species)["sight_m"]


static func sight_deg(species: int) -> float:
	return table(species)["sight_deg"]


static func hear_m(species: int) -> float:
	return table(species)["hear_m"]


static func slope_cost(species: int) -> Dictionary:
	return table(species)["slope_cost"]


static func territory_m(species: int) -> float:
	return table(species)["territory_m"]


static func home(species: int) -> String:
	return table(species)["home"]


static func pack_size(species: int) -> int:
	return int(table(species)["pack"])


static func flank_deg(species: int) -> Dictionary:
	return table(species)["flank_deg"]


## DESIGN.md's cozy-honest rule, as one call. Anything that ever offers a
## target asks this and nothing else - which is what makes "small cute ambient
## creatures cannot be targeted" a property of the table rather than a rule
## somebody has to remember.
static func huntable(species: int) -> bool:
	return bool(table(species)["huntable"])


static func bite(species: int) -> Dictionary:
	return table(species)["bite"]


static func silhouette(species: int) -> String:
	return table(species)["silhouette"]


## How loud a player is right now, as a multiplier on the listener's hear_m.
##
## Reads the STATE BYTE the sync row already carries (see
## `LocomotionState.to_state_byte`) rather than inventing a second description
## of what a player is doing: bit 0 grounded, bit 1 sprint. `speed_mps` decides
## moving from still, because a sprint key held while standing against a wall
## is not a sprint.
static func player_loudness(state_byte: int, speed_mps: float) -> float:
	if speed_mps < 0.5:
		return NOISE["still"]
	if (state_byte & 2) != 0:
		return NOISE["sprint"]
	return NOISE["move"]
