shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, shadows_disabled, depth_draw_never;
// Gate portal as a tear in space: a black core that swallows light, a swirling bright
// accretion ring in the rank colour, a thin white event horizon, sparks drawn inward.

uniform vec4 color : source_color = vec4(0.5, 0.6, 1.0, 1.0);
uniform float speed = 0.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float a = atan(p.y, p.x);
	float t = TIME * speed;
	// Swirl: angle twisted more toward the centre, streams flowing inward.
	float twist = a + 2.5 / (r + 0.25) - t * 2.2;
	float streams = noise(vec2(twist * 2.0, r * 7.0 + t * 3.0)) * noise(vec2(twist * 5.0, r * 3.0 - t));
	float ring = smoothstep(0.32, 0.5, r) * (1.0 - smoothstep(0.62, 1.0, r));
	float horizon = smoothstep(0.03, 0.0, abs(r - 0.33));
	float core = 1.0 - smoothstep(0.26, 0.34, r);
	vec3 glow = color.rgb * (0.6 + streams * 2.4) * ring + vec3(1.0) * horizon * 1.6;
	// Sparks spiralling in.
	float spark = step(0.985, hash(floor(vec2(twist * 8.0, r * 30.0 + t * 6.0))));
	glow += mix(color.rgb, vec3(1.0), 0.6) * spark * ring * 2.0;
	vec3 col = mix(glow, vec3(0.0), core);
	ALBEDO = col;
	ALPHA = max(core, clamp(ring * (0.45 + streams * 1.2) + horizon, 0.0, 1.0)) * (1.0 - smoothstep(0.9, 1.0, r));
	EMISSION = glow * (1.0 - core);
}
