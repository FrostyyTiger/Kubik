class_name WorldHash

## Deterministic pseudo-randomness for worldgen.
##
## Everything scattered across the world - which cells grow a tree, which block
## a zone boundary dithers to - needs to look random and must NOT be random.
## randf() would give a different world on each machine from the same seed,
## which is the exact failure the README's terrain contract exists to prevent,
## and it fails silently: no error, just two players in two different worlds.
##
## So instead of drawing from a stream, we HASH THE COORDINATES. Position and
## seed in, the same value out, forever, in any order, on any machine, whether
## or not the chunk next door has been generated yet. That last property is the
## one that matters most: a chunk must generate identically whether it is built
## first or last, and a stateful RNG cannot promise that.

## Odd 32-bit constants with well-mixed bits. Multiplying by an even number
## throws away low bits every time and the hash degrades on exactly the small
## coordinates we use most.
const PRIME_X := 374761393
const PRIME_Z := 668265263
const PRIME_S := 1274126177
const MIX := 1103515245


## A 32-bit hash of two coordinates, a seed and a salt.
##
## `salt` separates independent uses at the same position: tree placement and
## zone dithering both hash (x, z) and must not agree with each other, or every
## tree in the world would stand exactly where the ground dithers.
static func hash2(x: int, z: int, world_seed: int, salt: int) -> int:
	var h := x * PRIME_X + z * PRIME_Z + world_seed * PRIME_S + salt * MIX
	# Two xor-shift-multiply rounds. One is not enough: neighbouring
	# coordinates differ in their low bits only, and without mixing them
	# upward the results stay visibly correlated - which shows up as trees in
	# diagonal stripes.
	h = (h ^ (h >> 15)) * PRIME_S
	h = (h ^ (h >> 13)) * MIX
	h = h ^ (h >> 16)
	return h & 0x7FFFFFFF


## The same hash as a float in [0, 1). This is the one callers usually want:
## `if hash01(...) < probability` is a deterministic coin flip.
static func hash01(x: int, z: int, world_seed: int, salt: int) -> float:
	return float(hash2(x, z, world_seed, salt)) / 2147483648.0


## An integer in [lo, hi], inclusive. Used for trunk heights and canopy radii.
static func hash_range(x: int, z: int, world_seed: int, salt: int, lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + (hash2(x, z, world_seed, salt) % (hi - lo + 1))
