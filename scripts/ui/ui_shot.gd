class_name UiShot

## Photographs the menu screens and quits. The UI's comparison harness, in
## the shape of the terrain tour and the character gallery: same flag, same
## output root, labelled directories side by side.
##
##     godot --path . -- --shot-ui look-7
##
## writes build/ui/look-7/main-menu.png and build/ui/look-7/character-creation.png.
## Needs a window - a viewport capture is a GPU readback - so no --headless.
##
## Driven from the screens themselves rather than from a tool scene, because
## the thing being photographed IS the screen as the player gets it: the main
## menu shoots itself and then presses its own Character button, the creation
## screen shoots itself and quits. Nothing here changes what either screen
## does when the flag is absent.

const ROOT := "res://build/ui"

## Frames to let a screen settle before the capture. A font loads on first
## use and a SubViewport renders one frame behind.
const SETTLE_FRAMES := 6

## THE SHOT SIZE, PINNED (ui v1 Stage 1).
##
## From Stage 1 the project stretches `canvas_items` + `expand`, which means
## the LOGICAL CANVAS - the coordinate space every Control is laid out in - is
## no longer fixed at 1280x720. `expand` picks the scale from the smaller of
## the two window/design ratios and hands the surplus back as canvas, so a
## 1280x1000 window lays out into 1280x1000 and a 1900x720 one into 1900x720.
## Measured on ganymede, not assumed; it is the whole of Decision 11.
##
## AND THE CAPTURE IS THAT CANVAS, NOT THE WINDOW. `get_texture()` on the root
## viewport returns the canvas as drawn, before the stretch transform scales it
## up for the display - so the size of every PNG this harness writes is the
## logical size and nothing else. Two shots taken at two window sizes with the
## same aspect are therefore already identical in size, and two taken at
## different aspects are not.
##
## Which is why the pin below sets `root.size` rather than the OS window. A
## `DisplayServer.window_set_size()` at runtime resizes the window and leaves
## the canvas where it was - it looks like it works, writes a correctly-sized
## PNG for the wrong reason, and would go on doing so until the day a shot ran
## at a different startup resolution.
const SHOT_SIZE := Vector2i(1280, 720)


## The logical canvas to shoot at: SHOT_SIZE, or `--shot-size 1280x1000`.
##
## The override exists to exercise the screens at a canvas they were not
## designed around - a taller one, a wider one - which is the audit the design
## doc asked for and the thing Stage 1 actually has to survive. A flag rather
## than the temporary driver edit the plan suggested: it is the same few lines
## and it leaves the check re-runnable.
static func shot_size() -> Vector2i:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot-size")
	if i < 0 or i + 1 >= args.size():
		return SHOT_SIZE
	var parts := args[i + 1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_warning("[UiShot] --shot-size %s is not WxH" % args[i + 1])
		return SHOT_SIZE
	var out := Vector2i(parts[0].to_int(), parts[1].to_int())
	if out.x < 16 or out.y < 16:
		push_warning("[UiShot] --shot-size %s is too small to draw" % args[i + 1])
		return SHOT_SIZE
	return out


## Force the logical canvas to shot_size(), before anything is captured.
##
## Called from capture() rather than once at startup, because a screen that
## shoots itself does so from its own _ready and there is no earlier hook the
## two screens share. Setting it repeatedly is free once it already matches.
static func pin_canvas(tree: SceneTree) -> void:
	if not wanted() or tree == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	var wanted_size := shot_size()
	if tree.root.size != wanted_size:
		tree.root.size = wanted_size


## The label after `--shot-ui`, or "" when the flag is absent.
static func label() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot-ui")
	if i < 0:
		return ""
	if i + 1 < args.size() and not args[i + 1].begins_with("--"):
		return args[i + 1]
	return "unlabelled"


static func wanted() -> bool:
	return not label().is_empty()


## Save the viewport as build/ui/<label>/<name>.png. Awaits the settle and
## the end of the frame, so call it with `await`.
static func capture(tree: SceneTree, name: String) -> void:
	pin_canvas(tree)
	for i in SETTLE_FRAMES:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var dir := "%s/%s" % [ROOT, label()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	print("[UiShot] logical canvas %s" % tree.root.size)
	var image := tree.root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [dir, name]
	var err := image.save_png(path)
	if err != OK:
		push_error("[UiShot] could not write %s: %s" % [path, error_string(err)])
	else:
		print("[UiShot] wrote %s" % ProjectSettings.globalize_path(path))
