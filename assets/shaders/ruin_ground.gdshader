shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// Ground of a dead city (owner's baked tiles): broken asphalt with dirt, mud and rooty
// grass breaking through, mixed by world-space noise so no two metres look the same.
// Top-down world projection; sides fall back to darkened dirt.

uniform sampler2D tex_asphalt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_mud : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_grass : source_color, filter_linear_mipmap, repeat_enable;
// Metres per texture repeat.
uniform float tile_m = 2.6;
// How much of the surface is still asphalt (1 road … 0 bare ground).
uniform float paved = 0.75;
// How green it has grown.
uniform float overgrowth = 0.35;
uniform float wetness = 0.15;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.3) * 0.3 + noise(p * 5.1) * 0.15; }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Each tile repeat gets a random 90° rotation + offset so the repeats do not line up.
vec3 sample_tile(sampler2D t, vec2 p) {
	vec2 cell = floor(p / tile_m);
	vec2 f = fract(p / tile_m);
	float r = floor(hash(cell) * 4.0);
	f = r < 1.0 ? f : (r < 2.0 ? vec2(1.0 - f.y, f.x) : (r < 3.0 ? 1.0 - f : vec2(f.y, 1.0 - f.x)));
	return texture(t, f * 0.92 + 0.04).rgb;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 asphalt = sample_tile(tex_asphalt, p);
	vec3 dirt = sample_tile(tex_dirt, p + vec2(1.7, 3.1));
	vec3 mud = sample_tile(tex_mud, p + vec2(5.3, 0.7));
	vec3 grass = sample_tile(tex_grass, p + vec2(2.9, 6.1));
	float broken = smoothstep(paved - 0.12, paved + 0.12, fbm(p * 0.11 + vec2(3.0)));
	vec3 col = mix(asphalt, dirt, broken);
	float green = smoothstep(1.0 - overgrowth - 0.1, 1.0 - overgrowth + 0.1, fbm(p * 0.17 + vec2(11.0)));
	// Grass grows where the asphalt broke, and in thin seams across the rest.
	col = mix(col, grass, green * (0.35 + 0.65 * broken));
	float wet = smoothstep(1.0 - wetness - 0.05, 1.0 - wetness + 0.05, fbm(p * 0.07 + vec2(23.0)));
	col = mix(col, mud, wet * 0.85);
	float up = smoothstep(0.4, 0.9, world_normal.y);
	col = mix(dirt * 0.55, col, up);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.35, wet * up);
}
