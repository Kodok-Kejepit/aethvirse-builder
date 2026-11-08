shader_type spatial;
render_mode diffuse_toon;
// Procedural city ground (sharp at any distance, no baked-texture smear).
// mode 0 — concrete slabs (sidewalks, building aprons) on a 1.5 m grid. Each slab is
//   intact (80 %), cracked (10 %) or gone to earth (10 %); moss takes ~22 % of slabs
//   (≈ 17.5 % of the area) and creeps along the joints. The thresholds come from the
//   measured distribution of the same hash / noise mix (see docs/DECISIONS.md).
// mode 1 — asphalt: aggregate grain, long cracks, alligator patches, wet potholes,
//   grass in the seams.
// mode 2 — wall tiles (metro): small glazed tiles in running bond on any wall, grime
//   rising from the floor, missing tiles showing concrete, moss and damp streaks.

uniform int mode = 0;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_moss : source_color, filter_linear_mipmap, repeat_enable;
uniform float slab_m = 1.5;
uniform vec3 concrete : source_color = vec3(0.47, 0.46, 0.44);
uniform vec3 asphalt : source_color = vec3(0.2, 0.205, 0.215);
// Measured thresholds (score = 0.6 hash + 0.4 fbm): P(< intact_max) = 0.8, P(< cracked_max) = 0.9.
uniform float intact_max = 0.6793;
uniform float cracked_max = 0.7434;
// P(moss score > moss_min) = 0.22.
uniform float moss_min = 0.6393;
uniform float overgrowth = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.3) * 0.3 + noise(p * 5.1) * 0.15; }

// Distance to the nearest crack: edges between random cells (Voronoi F2 - F1).
float cracks(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + vec2(5.2, 1.3)));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 slabs(vec2 p, out float rough) {
	vec2 cell = floor(p / slab_m);
	vec2 f = fract(p / slab_m);
	float joint = 1.0 - smoothstep(0.0, 0.025, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	float score = 0.6 * hash(cell) + 0.4 * fbm(cell * 0.21);
	float moss_score = 0.5 * hash(cell + vec2(17.0, 3.0)) + 0.5 * fbm(cell * 0.15 + vec2(5.0));
	// Intact concrete: per-slab tone, fine grain, faint stains.
	float tone = 0.92 + 0.16 * hash(cell + vec2(3.0, 9.0));
	float grain = noise(p * 14.0);
	vec3 col = concrete * tone * (0.92 + 0.16 * grain);
	col *= 1.0 - 0.18 * smoothstep(0.55, 0.85, fbm(p * 0.6 + cell));
	rough = 0.88;
	if (score >= cracked_max) {
		// Slab gone: bare earth, darker towards the broken edges.
		vec3 dirt = texture(tex_dirt, p * 0.35).rgb;
		float edge = smoothstep(0.0, 0.18, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		col = mix(col * 0.55, dirt, edge);
		joint = 0.0;
		rough = 0.95;
	} else if (score >= intact_max) {
		// Cracked slab: a web of dark hairline cracks, slightly sunk (darker).
		float c = cracks(p * 2.2 + cell * 7.0);
		col *= 0.88 * (1.0 - 0.75 * (1.0 - smoothstep(0.0, 0.05, c)));
	}
	col = mix(col, col * 0.35, joint);
	if (moss_score > moss_min) {
		vec3 moss = texture(tex_moss, p * 0.45).rgb;
		// Moss covers most of the slab, thickest along its joints, ragged at its edge.
		float d = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		float cover = smoothstep(0.42, 0.18, d + (fbm(p * 3.0) - 0.5) * 0.35);
		col = mix(col, moss, cover * 0.9);
	} else {
		// Thin moss lines in some joints.
		col = mix(col, texture(tex_moss, p * 0.45).rgb * 0.8, joint * smoothstep(0.55, 0.75, fbm(p * 0.5)));
	}
	return col;
}

vec3 asphalt_ground(vec2 p, out float rough) {
	float grain = noise(p * 18.0);
	vec3 col = asphalt * (0.88 + 0.24 * grain);
	// Light aggregate stones: a few per 10 cm cell, soft so they never sparkle.
	vec2 g = floor(p * 10.0);
	col = mix(col, vec3(0.28, 0.275, 0.27), step(0.96, hash(g)) * (1.0 - smoothstep(0.1, 0.3, length(fract(p * 10.0) - 0.5))) * 0.3);
	// Worn, sun-bleached lanes and dark oil / tar patches.
	col *= 0.9 + 0.22 * fbm(p * 0.08);
	col = mix(col, asphalt * 0.6, smoothstep(0.62, 0.7, fbm(p * 0.13 + vec2(4.0))) * 0.6);
	// Long cracks and alligator cracking in places.
	float long_c = 1.0 - smoothstep(0.0, 0.02, abs(fbm(p * 0.09 + vec2(8.0)) - 0.5));
	float gator_zone = smoothstep(0.64, 0.74, fbm(p * 0.07 + vec2(2.0)));
	float gator = 0.0;
	if (gator_zone > 0.0) {
		gator = (1.0 - smoothstep(0.0, 0.05, cracks(p * 2.6))) * gator_zone;
	}
	float crack = clamp(long_c + gator, 0.0, 1.0);
	col *= 1.0 - 0.7 * crack;
	rough = 0.9;
	// Potholes: wet, dark, shiny.
	float hole = smoothstep(0.74, 0.78, fbm(p * 0.18 + vec2(13.0)));
	col = mix(col, vec3(0.06, 0.065, 0.07), hole * 0.85);
	rough = mix(rough, 0.08, hole);
	// Grass and moss pushing through the cracks.
	vec3 moss = texture(tex_moss, p * 0.4).rgb;
	float green = crack * smoothstep(1.0 - overgrowth, 1.0 - overgrowth + 0.1, fbm(p * 0.21 + vec2(6.0)));
	col = mix(col, moss, clamp(green * 1.4, 0.0, 1.0));
	return col;
}

vec3 wall_tiles(vec3 wp, vec3 n, out float rough) {
	// Wall plane coordinates (horizontal along the wall, vertical up).
	vec2 q = abs(n.x) > abs(n.z) ? vec2(wp.z, wp.y) : vec2(wp.x, wp.y);
	vec2 size = vec2(0.3, 0.15);
	vec2 g = q / size;
	g.x += mod(floor(g.y), 2.0) * 0.5;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float joint = 1.0 - smoothstep(0.0, 0.06, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y) * 2.0));
	vec3 glaze = mix(vec3(0.82, 0.82, 0.78), vec3(0.72, 0.78, 0.74), step(0.85, hash(cell * 0.37)));
	vec3 col = glaze * (0.9 + 0.1 * hash(cell));
	col = mix(col, vec3(0.45, 0.44, 0.41), joint * 0.6);
	rough = 0.25;
	// Missing tiles: bare grey concrete behind.
	if (hash(cell + vec2(11.0, 4.0)) > 0.97 - 0.3 * smoothstep(0.62, 0.85, fbm(cell * 0.11))) {
		col = concrete * (0.7 + 0.2 * noise(q * 9.0));
		rough = 0.95;
	}
	// Grime rising from the floor, damp streaks running down.
	float grime = 1.0 - smoothstep(0.0, 1.8 + fbm(q * 0.4) * 1.5, wp.y);
	float streak = smoothstep(0.6, 0.8, noise(vec2(q.x * 2.2, q.y * 0.12)));
	col *= 1.0 - 0.45 * grime - 0.25 * streak;
	vec3 moss = texture(tex_moss, q * 0.5).rgb;
	col = mix(col, moss, clamp(grime * smoothstep(0.55, 0.75, fbm(q * 0.8 + vec2(3.0))) * 1.3, 0.0, 0.9));
	rough = mix(rough, 0.95, grime * 0.6);
	return col;
}

void fragment() {
	vec2 p = world_pos.xz;
	float rough;
	vec3 col;
	if (mode == 2) {
		col = wall_tiles(world_pos, normalize(world_normal), rough);
	} else {
		col = mode == 0 ? slabs(p, rough) : asphalt_ground(p, rough);
		// Sides of kerbs / slabs: plain concrete (or asphalt), a bit darker.
		float up = smoothstep(0.4, 0.9, world_normal.y);
		vec3 side = (mode == 0 ? concrete : asphalt) * 0.7 * (0.9 + 0.2 * noise(world_pos.xy * 8.0 + world_pos.zy));
		col = mix(side, col, up);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
