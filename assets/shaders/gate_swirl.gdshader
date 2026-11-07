shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, shadows_disabled;
// Gate portal surface: spiralling energy that brightens toward the rim.

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
	float spiral = noise(vec2(a * 2.0 + r * 6.0 - TIME * speed * 3.0, r * 4.0 - TIME * speed));
	float rim = smoothstep(0.5, 1.0, r);
	float core = 1.0 - smoothstep(0.0, 0.35, r);
	vec3 c = color.rgb * (0.25 + spiral * 0.9 + rim * 0.8) + vec3(1.0) * core * 0.25;
	ALBEDO = c;
	ALPHA = (0.35 + spiral * 0.5 + rim * 0.4) * (1.0 - smoothstep(0.92, 1.0, r));
}
