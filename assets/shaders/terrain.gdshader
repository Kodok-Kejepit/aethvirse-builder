shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// Region terrain: base soil, grass/sand patches, rock on steep slopes, optional snow on
// tops; world-space noise at three scales so nothing reads as a flat colour.

uniform vec4 base_color : source_color = vec4(0.36, 0.34, 0.3, 1.0);
uniform vec4 patch_color : source_color = vec4(0.33, 0.42, 0.25, 1.0);
uniform vec4 rock_color : source_color = vec4(0.45, 0.43, 0.42, 1.0);
uniform vec4 top_color : source_color = vec4(0.9, 0.93, 1.0, 1.0);
uniform float top_from = 99.0;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float big = noise(wp.xz * 0.03);
	float mid = noise(wp.xz * 0.18);
	float fine = noise(wp.xz * 1.7);
	vec3 col = base_color.rgb;
	col = mix(col, patch_color.rgb, smoothstep(0.42, 0.68, big * 0.7 + mid * 0.3));
	float slope = 1.0 - smoothstep(0.62, 0.86, wn.y);
	col = mix(col, rock_color.rgb * (0.85 + 0.3 * mid), slope);
	float top = smoothstep(top_from, top_from + 1.5, wp.y + (mid - 0.5) * 1.5) * (1.0 - slope * 0.7);
	col = mix(col, top_color.rgb, top);
	col *= 0.86 + 0.28 * fine * (0.6 + 0.4 * mid);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
