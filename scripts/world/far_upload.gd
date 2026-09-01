class_name FarUpload
extends RefCounted

## THE FAR COUNTRY'S HANDOVER TO THE RENDERER, ON A BUDGET. Distance v5 Stage 1,
## decision 1.
##
## WHY THIS EXISTS. Building the far mesh is a worker's job and has been since
## terrain v1. Giving it to the renderer is not: `ArrayMesh.add_surface_from_
## arrays` and `MultiMesh.buffer` are RenderingServer calls, and RenderingServer
## wants the main thread. Distance v4 made the mesh 40x cheaper to build and 3.5x
## bigger, so the handover stopped being a footnote and became the far country's
## binding cost - 197 ms of blocked frame at `far_ring_div` 4, every rebuild,
## measured (STATUS items 11, 17 and 20).
##
## The upload cannot be moved off the frame thread. So it is SPLIT: the mesher
## emits one set of arrays per frontier sector, this queue hands them over a few
## at a time, and the frame the player is looking at pays a budget instead of a
## quarter of a second.
##
## THE THREE RULES, and each one is a way this goes wrong if it is missing:
##
##   1. A SLICE IS ATOMIC. `add_surface_from_arrays` cannot be interrupted, so
##      the budget is a line the pump stops AT rather than one it never crosses.
##      One sector of a div-4 far mesh is about 12 ms; the budget's job is to
##      stop it becoming sixteen of them in one frame, not to make one of them
##      free. Plan decision 1: "a slice never splits below one sector".
##
##   2. THE SWAP IS ATOMIC TOO. Slices land in a mesh nobody is looking at, and
##      the finished thing is put on screen in one assignment. A far country
##      half of which is the old vantage and half the new one is a worse
##      artefact than the hitch this replaces, and it would be an intermittent
##      one - the kind that gets photographed and not reproduced.
##
##   3. A SUPERSEDED JOB IS DROPPED, not queued behind. A rebuild arrives every
##      ~700 ms and takes ~16 frames to upload; without this, a sprint would
##      build a backlog of far meshes for vantages the player has already left,
##      and pay for every one of them. Jobs are keyed, and a new job under a key
##      replaces whatever that key still had pending.
##
## NOT A GLOBAL. One of these per `FarField`, which is one per `World`, and it
## dies with the node that holds it - the same ownership `FarMesher` has had
## since distance v4 Stage 5. `FarTrees` reaches this one through the tree, the
## way `apply_far_knobs` reaches `FarField`, because the impostor ring is Game's
## child and not World's.

## One queued handover: a list of slices to run, and the commit that puts the
## result on screen once every slice has landed.
class Job extends RefCounted:
	var key := &""
	var slices: Array[Callable] = []
	var commit: Callable = Callable()
	var at := 0
	## Microseconds this job has spent on the frame thread, and over how many
	## frames. Both are reported, because "the upload costs 197 ms" and "the
	## upload costs 197 ms spread over sixteen frames" are the same number and
	## different facts.
	var spent_us := 0
	var frames := 0


## The queue, oldest first. In practice one or two entries: the far field's and
## the impostor ring's.
var _jobs: Array[Job] = []

## What the last COMPLETED job of each key cost. For the F3 readout and for the
## status doc's after-picture.
var _last := {}

## Slices uploaded and jobs dropped this session, for the summary at exit.
var _uploaded := 0
var _dropped := 0


## Queue a handover. `slices` are run in order, one or more per frame until the
## budget is spent; `commit` runs on the frame the last one lands.
##
## Anything still pending under the same key is DROPPED - see rule 3. The
## dropped job's commit is NOT run: its slices are half-applied to a mesh
## nobody has seen, and putting that on screen is exactly rule 2's artefact.
func submit(key: StringName, slices: Array[Callable], commit: Callable) -> void:
	_drop(key)
	if slices.is_empty():
		# Nothing to upload is still a handover: an empty far mesh has to be
		# able to replace a full one, or a rebuild that legitimately produced
		# no quads would leave the old country standing.
		if commit.is_valid():
			commit.call()
		return
	var job := Job.new()
	job.key = key
	job.slices = slices
	job.commit = commit
	_jobs.append(job)


## Spend up to `budget_ms` of this frame uploading. Main thread only.
##
## A budget of 0 or less means "all of it, now", which is tonight-minus-this and
## is what the A/B knob's 0 setting is for.
func pump(budget_ms: float) -> void:
	if _jobs.is_empty():
		return
	if budget_ms <= 0.0:
		drain()
		return
	var t0 := Time.get_ticks_usec()
	var budget_us := int(budget_ms * 1000.0)
	# Each job that gets any of this frame counts the frame once.
	var counted := {}
	while not _jobs.is_empty():
		var job := _jobs[0]
		if not counted.has(job):
			job.frames += 1
			counted[job] = true
		_run_slice(job)
		if job.at >= job.slices.size():
			_finish(job)
		# THE BUDGET IS CHECKED AFTER THE SLICE, not before it. Rule 1: the
		# slice is the atom, so the honest thing is to spend it and then stop.
		# Checking first would let a frame with 0.1 ms left start a 12 ms
		# upload, which is the same overrun with a less obvious cause.
		if Time.get_ticks_usec() - t0 >= budget_us:
			return


## Run everything now, budget or no budget. World teardown, the self-test's
## pump, and the `far_upload_budget_ms` 0 setting.
func drain() -> void:
	while not _jobs.is_empty():
		var job := _jobs[0]
		job.frames += 1
		while job.at < job.slices.size():
			_run_slice(job)
		_finish(job)


## AND THE SLICE IS DROPPED THE MOMENT IT HAS LANDED, which is a memory rule
## rather than a tidiness one.
##
## Each queued slice is a closure holding a set of mesh arrays - a sixteenth of
## a far mesh, and at `far_ring_div` 4 the whole thing is about 120 MB. Held to
## the end of the job, a handover keeps THREE far meshes alive at once: the one
## on screen, the one being filled, and the queue's own copy of the arrays that
## have already gone into it. Measured on the stream probe as static memory
## 379.4 MB -> 616.9 MB before this line existed.
func _run_slice(job: Job) -> void:
	var t := Time.get_ticks_usec()
	var slice: Callable = job.slices[job.at]
	job.slices[job.at] = Callable()
	job.at += 1
	if slice.is_valid():
		slice.call()
	job.spent_us += Time.get_ticks_usec() - t
	_uploaded += 1


func _finish(job: Job) -> void:
	if job.commit.is_valid():
		job.commit.call()
	_last[job.key] = {
		"slices": job.slices.size(),
		"ms": float(job.spent_us) / 1000.0,
		"frames": job.frames,
	}
	_jobs.erase(job)


func _drop(key: StringName) -> void:
	for job in _jobs.duplicate():
		if job.key == key:
			_jobs.erase(job)
			_dropped += 1


## Slices still waiting. Zero means what is on screen is what was last built,
## which is the question the self-test and the probes ask.
func pending() -> int:
	var n := 0
	for job in _jobs:
		n += job.slices.size() - job.at
	return n


## What the last completed handover under each key cost, plus the session
## totals. For the F3 readout and the status doc.
func stats() -> Dictionary:
	return {
		"pending": pending(),
		"uploaded": _uploaded,
		"dropped": _dropped,
		"last": _last,
	}
