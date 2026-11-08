shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// World blocks: world-space noise so big slabs are not flat colour, a lighter "top" on
// upward faces (grass / sand crust / snow), darker grime low on walls, soft toon light.

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.55, 1.0);
uniform vec4 top_color : source_color = vec4(0.6, 0.6, 0.65, 1.0);
uniform float noise_scale = 0.35;
uniform float noise_strength = 0.38;
uniform float top_amount = 0.6;
// 0 plain, 1 building facade, 2 concrete, 3 canvas, 4 brick/stone, 5 wood, 6 rusted metal,
// 7 ruined asphalt (crack network, moss in the cracks, potholes, worn patches).
uniform int style = 0;
// 0 day … 1 night (windows light up).
uniform float night = 0.0;
// Share of windows lit at night (abandoned districts stay mostly dark).
uniform float lit_share : hint_range(0.0, 1.0) = 0.15;
// Real moss (owner's baked tile) for facades and ledges; without it a flat tint is used.
uniform sampler2D tex_moss : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_moss = false;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = noise(world_pos * noise_scale) * 0.5 + noise(world_pos * noise_scale * 4.1) * 0.3
		+ noise(world_pos * noise_scale * 0.08) * 0.2;
	vec3 col = base_color.rgb;
	float up = smoothstep(0.55, 0.95, world_normal.y);
	float patches = smoothstep(0.35, 0.75, noise(world_pos * noise_scale * 0.6 + vec3(7.0)));
	col = mix(col, top_color.rgb, up * top_amount * patches);
	col *= 1.0 + (n - 0.5) * 2.0 * noise_strength;
	// Grime / ambient occlusion near the ground on walls.
	float low = 1.0 - smoothstep(0.0, 1.4, world_pos.y - floor(world_pos.y / 100.0) * 100.0);
	col *= 1.0 - (1.0 - up) * low * 0.25;
	vec3 glow = vec3(0.0);
	float side = 1.0 - up;
	vec2 wall = abs(world_normal.x) > abs(world_normal.z) ? world_pos.zy : world_pos.xy;
	if (style == 1 && side > 0.5) {
		// Windows on a 3 m × 3.2 m grid, some lit at night; floor slab lines.
		vec2 cell = wall / vec2(3.0, 3.2);
		vec2 f = fract(cell);
		float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.8);
		float lit = step(1.0 - lit_share, hash(vec3(floor(cell), 3.0)));
		float warmth = hash(vec3(floor(cell), 7.0));
		col = mix(col, vec3(0.08, 0.1, 0.14), win * 0.85);
		glow += mix(vec3(1.0, 0.72, 0.4), vec3(0.75, 0.85, 1.0), step(0.7, warmth)) * win * lit * night * 0.9;
		col *= 1.0 - smoothstep(0.03, 0.0, f.y) * 0.4;
		// Moss creeping up from the street in ragged tongues, damp streaks down from ledges.
		// Textured and broken up at the edge so it reads as growth, not paint.
		float edge = noise(world_pos * 2.6) * 0.5 + noise(world_pos * 7.3) * 0.5;
		float creep = smoothstep(0.5, 0.75, noise(world_pos * 0.35 + vec3(13.0)) + (edge - 0.5) * 0.35)
			* (1.0 - smoothstep(0.5, 5.0 + noise(world_pos * 0.2) * 3.0, world_pos.y));
		float streak = smoothstep(0.78, 0.9, noise(vec3(world_pos.x * 1.7, world_pos.y * 0.15, world_pos.z * 1.7)) + (edge - 0.5) * 0.2);
		vec3 moss = has_moss ? texture(tex_moss, wall * 0.35).rgb : vec3(0.2, 0.31, 0.15);
		col = mix(col, moss, clamp(creep * 0.85 + streak * 0.25, 0.0, 0.85));
		col *= 1.0 - streak * 0.25;
	} else if (style == 1) {
		// Roofs / ledges of facade blocks: moss beds.
		vec3 bed = has_moss ? texture(tex_moss, world_pos.xz * 0.35).rgb : vec3(0.24, 0.36, 0.17);
		col = mix(col, bed, smoothstep(0.35, 0.7, noise(world_pos * 0.4 + vec3(5.0)) + (noise(world_pos * 3.0) - 0.5) * 0.3) * 0.85);
	} else if (style == 2) {
		float crack = smoothstep(0.012, 0.0, abs(noise(world_pos * 3.2) - 0.5))
			* smoothstep(0.55, 0.7, noise(world_pos * 0.4 + vec3(11.0))) * 0.22;
		float stain = smoothstep(0.55, 0.85, noise(world_pos * 0.25 + vec3(3.0))) * 0.25 * side;
		col *= 1.0 - crack - stain;
		vec2 slab = fract(world_pos.xz / 4.0);
		col *= 1.0 - up * smoothstep(0.02, 0.0, min(slab.x, slab.y)) * 0.3;
	} else if (style == 7) {
		// Two crack networks (iso-lines of noise) of different scales, moss growing in them.
		float c1 = smoothstep(0.03, 0.0, abs(noise(world_pos * 0.9) - 0.5));
		float c2 = smoothstep(0.02, 0.0, abs(noise(world_pos * 2.7 + vec3(5.0)) - 0.5))
			* smoothstep(0.45, 0.6, noise(world_pos * 0.3 + vec3(2.0)));
		float cracks = max(c1, c2 * 0.8) * up;
		float moss = smoothstep(0.35, 0.75, noise(world_pos * 0.5 + vec3(9.0)));
		col = mix(col, mix(col * 0.35, vec3(0.2, 0.32, 0.14), moss), cracks);
		// Potholes: dark wet blobs with a lighter broken rim.
		float hole = noise(world_pos * 0.45 + vec3(31.0)) * noise(world_pos * 0.13 + vec3(17.0));
		col = mix(col, col * 0.55, smoothstep(0.62, 0.66, hole) * up);
		col = mix(col, col * 1.2, smoothstep(0.58, 0.62, hole) * (1.0 - smoothstep(0.62, 0.66, hole)) * up);
		// Sun-bleached, worn patches and creeping moss at the edges.
		col = mix(col, col * 1.18, smoothstep(0.55, 0.8, noise(world_pos * 0.12 + vec3(4.0))) * 0.6 * up);
		col = mix(col, vec3(0.24, 0.36, 0.17), smoothstep(0.7, 0.9, moss * noise(world_pos * 1.3)) * 0.55 * up);
	} else if (style == 3) {
		float stripe = step(0.5, fract((wall.x + world_pos.x + world_pos.z) * 0.6));
		col = mix(col, col * vec3(1.25, 1.15, 0.95), stripe * 0.6);
	} else if (style == 4 && side > 0.5) {
		vec2 b = wall / vec2(0.9, 0.42);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 f2 = fract(b);
		float mortar = 1.0 - step(0.06, f2.x) * step(0.1, f2.y);
		col = mix(col * (0.9 + 0.2 * hash(vec3(floor(b), 1.0))), col * 0.6, mortar);
	} else if (style == 5) {
		float plank = fract((side > 0.5 ? wall.y : world_pos.x) / 0.32);
		col *= 0.85 + 0.15 * noise(vec3(world_pos.x * 0.3, world_pos.y * 6.0, world_pos.z * 0.3));
		col *= 1.0 - smoothstep(0.06, 0.0, plank) * 0.35;
	} else if (style == 6) {
		float rust = smoothstep(0.4, 0.8, noise(world_pos * 0.8));
		col = mix(col, vec3(0.45, 0.22, 0.1), rust * 0.6);
	}
	ALBEDO = col;
	EMISSION = glow;
	ROUGHNESS = style == 6 ? 0.55 : 0.9;
}
