shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// Inverted-hull outline used as next_pass on character parts.

uniform vec4 color : source_color = vec4(0.12, 0.05, 0.16, 1.0);
uniform float width = 0.008;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
