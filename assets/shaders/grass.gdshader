shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
// MultiMesh grass blades: instance colour, darker roots, wind sway at the tip.

varying vec3 tint;
varying float h;

void vertex() {
	h = clamp(VERTEX.y / 0.38, 0.0, 1.0);
	tint = COLOR.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wind = sin(TIME * 2.0 + wp.x * 0.4 + wp.z * 0.3) * 0.12 + sin(TIME * 4.3 + wp.z * 1.3) * 0.04;
	VERTEX.x += wind * h * h;
	VERTEX.z += wind * 0.5 * h * h;
}

void fragment() {
	ALBEDO = tint * mix(0.45, 1.15, h);
	ROUGHNESS = 0.9;
}
