class_name Lens
extends CanvasLayer

## The film half of D40's lens: grain and a vignette, after the tonemap.
##
## THE OTHER TWO THIRDS ARE THE ENGINE'S. Halation is the environment's glow
## gated by `glow_hdr_threshold`, and the muted midtones are its colour
## adjustment; both live in `Look.configure_environment()` because both are
## properties of the environment and neither can be done here. What is left is
## the pair that must land AFTER tonemapping, and that is why this is a
## `CanvasLayer` and not a spatial shader: a 3D shader writes into the linear
## HDR buffer that AgX then reshapes, so grain added there would be graded, and
## a vignette added there would be tonemapped into something that is not a
## vignette. Film grain is on the print, not in the scene.
##
## UNDER THE HUD, deliberately. Layer 5 against the HUD's own, so the debug
## readout, the status line and the character sheet are not grained and not
## vignetted - they are not photographed things, they are the instrument you
## read the photograph with.
##
## THE THREE FENCES OF D40, and this pass is judged against all three:
##
##   1. "Subtle film grain, fine and even, never heavy. Test: a 1-cube gold
##      line on a landmark still reads at 100 m." That test is the tour's
##      `25-lens-fence` and `26-lens-fence-off` pair.
##   2. "A gentle vignette at most. No chromatic aberration, no lens flare, no
##      sharpening." There is no aberration and no flare here, and there never
##      will be: they are named as forbidden, not as unimplemented.
##   3. "The decided hours and regions keep their colour." The grain is
##      MONOCHROME - one value added to all three channels - so it cannot tint
##      an hour, and the vignette multiplies, so it cannot either.

## The layer this draws on. **-1, not the plan's 5**, and the reason is worth a
## line: every `CanvasLayer` in `game.tscn` - the HUD, the debug readout, the
## character screen - leaves `layer` at its default of 0, and a canvas layer
## draws over every layer below it. At 5 the film pass would have grained and
## vignetted the whole interface. A negative layer still draws over the 3D
## world (canvas layers are composited after the viewport, in layer order), so
## -1 is exactly the plan's intent - "under the HUD's" - expressed against the
## layers the scene actually has.
const LAYER := -1

## How strong the grain is, in DISPLAY space. Range 0.02-0.06, judged on the
## lens fence and the night shot.
const GRAIN_AMOUNT := 0.035

## How dark the corners go. Range 0.1-0.3. "Gentle" is the bible's word, and
## 0.18 over a wide falloff is a thing you notice when it is switched off
## rather than when it is on.
const VIGNETTE := 0.18

const SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float grain_amount = 0.035;
uniform float vignette = 0.18;

// ONE HASH, RE-SEEDED PER FRAME. A grain that does not move is a dirty lens,
// not film - and it is worse than no grain at all, because the eye locks onto
// a fixed pattern in seconds. TIME goes into the hash rather than into a
// texture lookup so there is no texture: hard rule 3 holds here too.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;

	// MONOCHROME, AND ZERO-MEAN. One value added to all three channels, so the
	// grain cannot shift a hue - which is D40's third fence, that the decided
	// hours keep their colour. Centred on zero so the EXPECTED image is
	// unchanged and the grain adds variance without adding exposure.
	float g = hash12(FRAGCOORD.xy + vec2(TIME * 61.7, TIME * 39.1)) - 0.5;
	c += g * grain_amount;

	// A WIDE FALLOFF, so the corners darken and the frame does not. The
	// smoothstep runs from 0.4 to 1.4 of the half-diagonal, which means it has
	// barely begun at the edge of the safe area and never closes fully even in
	// the corner.
	vec2 d = SCREEN_UV - vec2(0.5);
	float r = length(d) * 2.0;
	c *= 1.0 - vignette * smoothstep(0.4, 1.4, r);

	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	layer = LAYER
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grain_amount", GRAIN_AMOUNT)
	mat.set_shader_parameter("vignette", VIGNETTE)

	var rect := ColorRect.new()
	rect.name = "Film"
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The rect is a carrier for the shader and must never eat a click.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


## `--lens off`, and the F4 toggle. One call turns the whole lens off - this
## pass and the environment's glow and grade together - so "lens off" is one
## state rather than three switches that can disagree.
##
## IT TOUCHES THE LENS AND NOTHING ELSE, and the first version did not. It
## called `Look.configure_environment()` with `lens` false, which is the
## builder for the WHOLE environment - so switching the lens off also reset the
## fog density, the height fog, the volumetric field and the ambient energy to
## their Stage 0 defaults. `SkyCycle.apply()` puts most of that back on the next
## frame, but `27-hour-night-lens-off` is captured before it does, and it came
## back with the night's fog bank simply gone: V 4.5 at the haze pixel where
## the same hour from the same eye reads V 17.5. Measured against a whole
## `--lens off` tour, which has the fog, so the fault was the toggle and never
## the lens.
##
## Three fields and a visibility flag. Everything else about the environment
## belongs to the hour and is written every frame by SkyCycle.
static func set_enabled(root: Node, env: Environment, on: bool) -> void:
	if env != null:
		env.glow_enabled = on
		env.adjustment_enabled = on
	var lens := root.get_node_or_null("Lens")
	if lens != null:
		lens.visible = on
