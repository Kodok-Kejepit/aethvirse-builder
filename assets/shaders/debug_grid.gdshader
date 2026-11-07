shader_type spatial;
// World-space grid for test scenes: 1 m minor lines, 10 m major lines. Makes speed readable.

uniform vec3 base_color : source_color = vec3(0.32, 0.34, 0.38);
uniform vec3 line_color : source_color = vec3(0.55, 0.6, 0.68);
uniform vec3 major_color : source_color = vec3(0.35, 0.65, 1.0);
uniform float minor_width = 0.02;
uniform float major_width = 0.05;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid(vec2 p, float spacing, float width) {
	vec2 g = abs(fract(p / spacing - 0.5) - 0.5) * spacing;
	vec2 aa = fwidth(p);
	vec2 lines = 1.0 - smoothstep(vec2(width) - aa, vec2(width) + aa, g);
	return max(lines.x, lines.y);
}

void fragment() {
	vec3 n = abs(world_normal);
	// Project the grid on the plane facing the dominant normal axis.
	vec2 p = n.y > 0.5 ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float minor = grid(p, 1.0, minor_width);
	float major = grid(p, 10.0, major_width);
	vec3 col = mix(base_color, line_color, minor * 0.6);
	col = mix(col, major_color, major);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
