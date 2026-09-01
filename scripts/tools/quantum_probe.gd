extends Node

## WHAT THE HEIGHT QUANTUM COSTS THE WORLD. Distance v5 Stage 4, one night only.
##
## Decision 3 asks for a quantisation to 1/1024 block so two compilers cannot
## disagree, and Stage 4's gate asks for spawn and lakes byte-equal to main's.
## Those two cannot both be had - a quantisation that changes nothing changes
## nothing - so this measures the ladder and the status doc records where it
## landed.
##
## GDScript builder only: the point is what the QUANTUM does, and the crossing
## is proved separately by `height tile parity`.

const LADDER := [0.0, 1024.0, 16384.0, 65536.0, 1048576.0, 16777216.0]


func _ready() -> void:
	print("[Quantum] seed 42, default config, GDScript builder")
	print("[Quantum] %-12s %-10s %-14s %s" % ["quantum", "heightmap", "spawn", "lakes"])
	for q in LADDER:
		TerrainGenerator.HEIGHT_QUANTUM = q
		var cfg := WorldgenConfig.new()
		cfg.apply_view_preset()
		cfg.apply_world_scale()
		var gen := TerrainGenerator.new(42, cfg)
		# The C++ builder quantises with its own constant, so this probe forces
		# the reference implementation - see the header.
		gen.force_gdscript_tiles = true
		gen.build_heightmap()
		var lakes := Lakes.new()
		lakes.compute(gen.heightmap, cfg)
		gen.lakes = lakes
		var spawn := gen.find_spawn()
		print("[Quantum] %-12s %-10s (%4d,%5d)  %d" % [
			("off" if q <= 0.0 else "1/%d" % int(q)),
			gen.heightmap.hash_key(), spawn.x, spawn.y, lakes.lake_count()])
	TerrainGenerator.HEIGHT_QUANTUM = 1024.0
	get_tree().quit()
