shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;
// MultiMesh grass tufts: dark damp roots, fresh mid blades, sun-dried tips; light shines
// through the blades from behind; wind bends each blade along its length with a phase
// of its own so the field ripples instead of moving as one sheet.

// Wind only moves the grass near the camera (WIND_NEAR..WIND_FAR m); further out the
// blades stand still and shrink away towards draw_distance, so the cut-off never pops.
uniform float draw_distance = 70.0;
const float WIND_NEAR = 14.0;
const float WIND_FAR = 26.0;

varying vec3 tint;
varying float h;

void vertex() {
	h = UV.y;
	tint = COLOR.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = fract(sin(dot(wp.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.283;
	float gust = sin(TIME * 0.6 + wp.x * 0.05 + wp.z * 0.04) * 0.5 + 0.5;
	float wind = (sin(TIME * 1.9 + wp.x * 0.35 + wp.z * 0.27 + phase) * 0.09 + sin(TIME * 4.1 + phase * 2.0) * 0.025) * (0.6 + gust);
	float dist = distance(wp, INV_VIEW_MATRIX[3].xyz);
	wind *= 1.0 - smoothstep(WIND_NEAR, WIND_FAR, dist);
	VERTEX *= 1.0 - smoothstep(draw_distance * 0.75, draw_distance, dist);
	float bend = h * h;
	VERTEX.x += wind * bend;
	VERTEX.z += wind * 0.6 * bend;
	VERTEX.y -= abs(wind) * bend * 0.25;
}

void fragment() {
	vec3 root = tint * 0.35;
	vec3 mid = tint;
	vec3 tip = mix(tint * 1.25, vec3(0.78, 0.74, 0.42), 0.35);
	vec3 col = h < 0.5 ? mix(root, mid, h * 2.0) : mix(mid, tip, (h - 0.5) * 2.0);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.35, 0.45, 0.2) * h;
}
