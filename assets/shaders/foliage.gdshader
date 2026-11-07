shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
// Leaves / grass: colour gradient with height, gentle wind sway that grows with height.

uniform vec4 base_color : source_color = vec4(0.2, 0.45, 0.22, 1.0);
uniform vec4 tip_color : source_color = vec4(0.45, 0.7, 0.35, 1.0);
uniform float sway = 0.08;
uniform float height_ref = 1.0;

varying float h;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	float wind = sin(TIME * 1.6 + wp.x * 0.35 + wp.z * 0.27) + 0.4 * sin(TIME * 3.1 + wp.z);
	VERTEX.x += wind * sway * h * h;
	VERTEX.z += wind * sway * 0.6 * h * h;
}

void fragment() {
	ALBEDO = mix(base_color.rgb, tip_color.rgb, h);
	ROUGHNESS = 0.85;
}
