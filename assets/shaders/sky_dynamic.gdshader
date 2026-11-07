shader_type sky;
// Region sky with day/night: gradient, sun glow, drifting clouds, stars at night.

uniform vec4 top_color : source_color = vec4(0.25, 0.4, 0.7, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.65, 0.72, 0.82, 1.0);
uniform vec4 night_top : source_color = vec4(0.01, 0.015, 0.05, 1.0);
uniform vec4 night_horizon : source_color = vec4(0.05, 0.07, 0.14, 1.0);
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.35;
// 0 … 1 around sunrise / sunset: orange horizon under a violet sky (owner's trailer look).
uniform float dusk : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dusk_horizon : source_color = vec4(1.0, 0.52, 0.3, 1.0);
uniform vec4 dusk_top : source_color = vec4(0.28, 0.18, 0.45, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, -0.2, 1.0);
	vec3 day = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.6, up));
	vec3 night = mix(night_horizon.rgb, night_top.rgb, smoothstep(0.0, 0.6, up));
	vec3 col = mix(night, day, daylight);
	vec3 dusk_col = mix(dusk_horizon.rgb, dusk_top.rgb, smoothstep(-0.05, 0.45, up));
	// Warmest towards the sun.
	dusk_col = mix(dusk_col, dusk_horizon.rgb * 1.15, pow(max(dot(normalize(vec3(d.x, 0.0, d.z)), normalize(vec3(LIGHT0_DIRECTION.x, 0.0, LIGHT0_DIRECTION.z))), 0.0), 3.0) * (1.0 - smoothstep(0.0, 0.35, up)));
	col = mix(col, dusk_col, dusk);
	// Sun / moon glow.
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += vec3(1.0, 0.85, 0.6) * (pow(sd, 400.0) * 3.0 + pow(sd, 8.0) * 0.25) * daylight;
	col += vec3(0.7, 0.8, 1.0) * pow(max(dot(d, -LIGHT0_DIRECTION), 0.0), 900.0) * (1.0 - daylight) * 2.0;
	// Clouds on a dome above the horizon.
	if (d.y > 0.02) {
		vec2 cuv = d.xz / (d.y + 0.15) * 1.4 + vec2(TIME * 0.006, TIME * 0.003);
		float c = smoothstep(1.0 - cloud_cover, 1.05 - cloud_cover * 0.6, fbm(cuv));
		vec3 cloud = mix(vec3(0.12, 0.13, 0.18), vec3(1.0, 0.98, 0.95), daylight * 0.9 + 0.05);
		cloud = mix(cloud, vec3(0.75, 0.42, 0.45), dusk * 0.8);
		col = mix(col, cloud, c * smoothstep(0.02, 0.2, d.y) * 0.85);
		// Stars at night where there are no clouds.
		vec2 suv = d.xz / (d.y + 0.3) * 80.0;
		float star = step(0.995, hash(floor(suv))) * smoothstep(0.35, 0.0, length(fract(suv) - 0.5));
		col += vec3(star) * (1.0 - daylight) * (1.0 - c) * (0.6 + 0.4 * sin(TIME * 2.0 + hash(floor(suv)) * 30.0));
	}
	COLOR = col;
}
