shader_type spatial;
render_mode diffuse_toon, cull_disabled;
// Gate dungeon surfaces from the owner's baked tiles, mixed in world space so no two
// metres repeat: floors are paving with cracked slabs, mud and wet patches (shiny),
// moss and roots in the seams; walls / ceilings are stone with moss creeping up from
// the floor and root streaks hanging from above.

uniform sampler2D tex_base : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_cracked : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_moss : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_mud : source_color, filter_linear_mipmap, repeat_enable;
// Rough cave rock; walls / roofs blend rock -> tex_base by the vertex colour (red = masonry).
uniform sampler2D tex_rock : source_color, filter_linear_mipmap, repeat_enable;
// 0 floor, 1 wall, 2 ceiling.
uniform int surface = 0;
// Metres per texture repeat.
uniform float tile_m = 3.0;
uniform float moss = 0.3;
uniform float wetness = 0.25;
uniform vec3 tint : source_color = vec3(1.0);
// Region kinds of place: glowing cracks (lava, void light), an ice coat, drifted sand.
uniform vec3 glow_color : source_color = vec3(1.0, 0.4, 0.1);
uniform float glow = 0.0;
uniform float frost = 0.0;
uniform float sand = 0.0;
const vec3 ICE = vec3(0.6, 0.72, 0.84);
const vec3 SAND = vec3(0.78, 0.66, 0.46);

varying vec3 world_pos;
varying vec3 world_normal;
varying float masonry;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.3) * 0.3 + noise(p * 5.1) * 0.15; }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masonry = COLOR.r;
}

// Random 90° turn per repeat so tiles never line up.
vec3 tile(sampler2D t, vec2 p) {
	vec2 cell = floor(p / tile_m);
	vec2 f = fract(p / tile_m);
	float r = floor(hash(cell) * 4.0);
	f = r < 1.0 ? f : (r < 2.0 ? vec2(1.0 - f.y, f.x) : (r < 3.0 ? 1.0 - f : vec2(f.y, 1.0 - f.x)));
	return texture(t, f * 0.94 + 0.03).rgb;
}

// World triplanar for walls and ceilings.
vec3 tri(sampler2D t, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy / tile_m).rgb * w.x + texture(t, p.xz / tile_m).rgb * w.y + texture(t, p.xy / tile_m).rgb * w.z;
}

void fragment() {
	vec3 col;
	float rough = 0.9;
	vec3 emit = vec3(0.0);
	if (surface == 0) {
		vec2 p = world_pos.xz;
		col = tile(tex_base, p);
		float cracked = smoothstep(0.5, 0.62, fbm(p * 0.12 + vec2(4.0)));
		col = mix(col, tile(tex_cracked, p + vec2(1.3, 2.7)), cracked);
		float mud = smoothstep(0.62, 0.74, fbm(p * 0.09 + vec2(17.0)));
		col = mix(col, tile(tex_mud, p + vec2(3.1, 0.4)), mud * 0.85);
		float green = smoothstep(1.0 - moss, 1.0 - moss + 0.12, fbm(p * 0.21 + vec2(9.0)));
		col = mix(col, tile(tex_moss, p + vec2(0.7, 5.2)), green * (0.4 + 0.6 * cracked));
		float wet = smoothstep(1.0 - wetness, 1.0 - wetness + 0.08, fbm(p * 0.07 + vec2(31.0)));
		col *= mix(1.0, 0.55, wet);
		rough = mix(0.92, 0.12, wet);
		float drift = smoothstep(1.0 - sand, 1.0 - sand + 0.25, fbm(p * 0.05 + vec2(23.0)) * 0.6 + fbm(p * 0.6) * 0.4) * step(0.01, sand);
		col = mix(col, SAND * (0.85 + 0.3 * noise(p * 3.0)), drift);
		rough = mix(rough, 0.95, drift);
		float ice = smoothstep(1.0 - frost, 1.0 - frost + 0.2, fbm(p * 0.08 + vec2(41.0))) * step(0.01, frost);
		col = mix(col, ICE * (0.85 + 0.25 * noise(p * 1.7)), ice * 0.65);
		rough = mix(rough, 0.08, ice);
		float vein = smoothstep(0.012, 0.0, abs(fbm(p * 0.22 + vec2(51.0)) - 0.5)) * smoothstep(0.35, 0.6, fbm(p * 0.05 + vec2(3.0)));
		col = mix(col, col * 0.35, vein * min(glow, 1.0));
		emit = glow_color * vein * glow * (0.75 + 0.25 * sin(TIME * 1.7 + p.x * 0.3 + p.y * 0.2));
	} else {
		vec3 n = normalize(world_normal);
		col = mix(tri(tex_rock, world_pos * 0.8, n), tri(tex_base, world_pos, n), smoothstep(0.15, 0.85, masonry));
		vec2 q = vec2(world_pos.x + world_pos.z, world_pos.y);
		// Moss climbs from the floor in uneven tongues; roots hang in streaks from above.
		float climb = 1.0 - smoothstep(0.3, 3.5 + fbm(q * 0.25) * 2.5, world_pos.y);
		float patches = smoothstep(1.0 - moss, 1.0 - moss + 0.15, fbm(q * 0.3 + vec2(7.0)));
		float streak = smoothstep(0.62, 0.72, fbm(vec2(q.x * 0.9, q.y * 0.07) + vec2(2.0)));
		float m = clamp(climb * (0.45 + 0.55 * patches) + streak * 0.7 + patches * 0.25, 0.0, 1.0);
		col = mix(col, tri(tex_moss, world_pos + vec3(1.7), n), clamp(m * moss * 2.0, 0.0, 1.0));
		if (surface == 2) {
			col *= 0.55;
		}
		float damp = 1.0 - smoothstep(0.0, 1.2, world_pos.y);
		col *= mix(1.0, 0.7, damp * wetness * 2.0);
		rough = mix(0.95, 0.4, damp * wetness);
		float ice_w = smoothstep(1.0 - frost, 1.0 - frost + 0.25, fbm(q * 0.2 + vec2(19.0))) * step(0.01, frost);
		col = mix(col, ICE, ice_w * 0.6);
		rough = mix(rough, 0.15, ice_w);
		float heap = (1.0 - smoothstep(0.0, 1.0 + fbm(q * 0.3) * 1.6, world_pos.y)) * sand;
		col = mix(col, SAND, clamp(heap * 1.4, 0.0, 1.0));
		float vein_w = smoothstep(0.01, 0.0, abs(fbm(vec2(q.x * 0.5, q.y * 0.15) + vec2(8.0)) - 0.5))
			* smoothstep(0.4, 0.62, fbm(q * 0.08 + vec2(6.0)));
		col = mix(col, col * 0.4, vein_w * min(glow, 1.0));
		emit = glow_color * vein_w * glow * 0.8 * (0.75 + 0.25 * sin(TIME * 1.3 + q.x * 0.4));
	}
	ALBEDO = col * tint;
	ROUGHNESS = rough;
	EMISSION = emit;
}
