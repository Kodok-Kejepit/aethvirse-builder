shader_type spatial;
render_mode diffuse_toon, cull_disabled, depth_draw_always;
// Stylised water: two scrolling wave normals, fresnel tint toward the sky, foam sparkles.

uniform vec4 deep_color : source_color = vec4(0.08, 0.22, 0.32, 0.88);
uniform vec4 shallow_color : source_color = vec4(0.3, 0.6, 0.7, 0.75);
uniform float wave_speed = 0.35;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.6 + TIME * 1.3) * 0.03 + cos(world_pos.z * 0.5 + TIME) * 0.03;
}

void fragment() {
	vec2 uv = world_pos.xz * 0.25;
	float a = noise(uv + vec2(TIME * wave_speed, 0.0));
	float b = noise(uv * 1.7 - vec2(0.0, TIME * wave_speed * 0.8));
	vec3 n = normalize(vec3((a - 0.5) * 0.6, 1.0, (b - 0.5) * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, 0.4 + 0.3 * a);
	float foam = smoothstep(0.82, 0.95, a * b * 1.6);
	ALBEDO = col + foam * 0.25;
	EMISSION = vec3(0.6, 0.8, 1.0) * fres * 0.25;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	ALPHA = mix(deep_color.a, 1.0, fres * 0.5);
}
