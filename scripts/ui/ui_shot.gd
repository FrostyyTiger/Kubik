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
	for i in SETTLE_FRAMES:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var dir := "%s/%s" % [ROOT, label()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var image := tree.root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [dir, name]
	var err := image.save_png(path)
	if err != OK:
		push_error("[UiShot] could not write %s: %s" % [path, error_string(err)])
	else:
		print("[UiShot] wrote %s" % ProjectSettings.globalize_path(path))
