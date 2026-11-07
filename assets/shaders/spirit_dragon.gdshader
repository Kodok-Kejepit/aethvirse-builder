shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;
// Spirit dragon: pearl-white/pink scales on top, starry violet belly underneath,
// noise dissolve with a glowing pink edge (summon / vanish).

uniform vec4 top_color : source_color = vec4(0.97, 0.92, 0.96, 1.0);
uniform vec4 tint_color : source_color = vec4(1.0, 0.55, 0.78, 1.0);
uniform vec4 belly_color : source_color = vec4(0.32, 0.12, 0.55, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.9, 1.0);
uniform float tint = 0.35;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float glow = 0.6;

varying vec3 local_pos;
varying vec3 local_normal;

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
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	float n = noise(local_pos * 14.0);
	if (n < dissolve) {
		discard;
	}
	float belly = smoothstep(0.1, -0.5, local_normal.y);
	vec3 scales = mix(top_color.rgb, tint_color.rgb, tint * (0.6 + 0.4 * noise(local_pos * 30.0)));
	vec3 base = mix(scales, belly_color.rgb, belly);
	vec3 q = local_pos * 60.0;
	float star = step(0.93, hash(floor(q))) * smoothstep(0.25, 0.0, length(fract(q) - 0.5));
	vec3 em = belly * star * vec3(1.0, 0.85, 1.0) * 2.0;
	em += edge_color.rgb * smoothstep(dissolve + 0.08, dissolve, n) * step(0.001, dissolve) * 3.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	em += tint_color.rgb * rim * glow;
	ALBEDO = base;
	ROUGHNESS = 0.5;
	EMISSION = em;
}
