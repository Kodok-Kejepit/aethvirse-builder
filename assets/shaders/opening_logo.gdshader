shader_type canvas_item;
// Full-screen animated opening built on top of the square key art.
// The image is cover-fitted to any aspect ratio (16:9 .. 20:9), then animated with
// rotating HUD rings, a pulsing core light, a light sweep over the title and a short glitch.

uniform sampler2D logo_tex : source_color, filter_linear_mipmap;
uniform vec2 rect_size = vec2(1920.0, 1080.0);
// Image-space point kept centered when the image is cropped to the screen.
uniform vec2 focus = vec2(0.5, 0.5);
uniform float zoom = 1.0;
// 0 = black, 1 = fully visible. Driven by the opening script.
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float fx_strength : hint_range(0.0, 1.0) = 1.0;

uniform vec2 ring_center = vec2(0.5, 0.47);
uniform vec3 ring_color : source_color = vec3(0.25, 0.65, 1.0);
uniform vec3 accent_color : source_color = vec3(0.75, 0.45, 1.0);
uniform vec2 core_light_pos = vec2(0.5, 0.40);
// Image-space vertical band that contains the title + tagline.
uniform vec2 title_band = vec2(0.44, 0.70);
uniform float sweep_period = 4.5;
uniform float glitch_period = 6.0;
uniform float glitch_duration = 0.18;
uniform float ring_intensity : hint_range(0.0, 1.0) = 0.45;

const float TAU_F = 6.28318530718;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

// Anti-aliased dashed ring. dashes = segments per turn, duty = filled fraction.
float ring(vec2 p, float radius, float width, float dashes, float duty, float speed) {
	float r = length(p);
	float aa = fwidth(r);
	float band = 1.0 - smoothstep(width, width + aa, abs(r - radius));
	float a = atan(p.y, p.x) / TAU_F + 0.5;
	float seg = fract(a * dashes + TIME * speed);
	float seg_aa = fwidth(a * dashes) + 0.001;
	float dash = smoothstep(0.0, seg_aa, seg) * (1.0 - smoothstep(duty - seg_aa, duty, seg));
	return band * dash;
}

vec2 cover_uv(vec2 screen_uv) {
	float aspect = rect_size.x / rect_size.y;
	vec2 visible = aspect >= 1.0 ? vec2(1.0, 1.0 / aspect) : vec2(aspect, 1.0);
	visible /= zoom;
	vec2 half_vis = visible * 0.5;
	vec2 center = clamp(focus, half_vis, vec2(1.0) - half_vis);
	return center + (screen_uv - 0.5) * visible;
}

vec3 sample_glitched(vec2 uv) {
	float phase = mod(TIME, glitch_period);
	float active = step(phase, glitch_duration);
	float in_title = step(title_band.x, uv.y) * step(uv.y, title_band.y);
	float slice = floor(uv.y * 48.0);
	float jitter = (hash(slice + floor(TIME * 24.0)) - 0.5) * 0.03;
	float offset = jitter * active * in_title * fx_strength;
	float split = 0.004 * active * fx_strength;
	vec2 base = uv + vec2(offset, 0.0);
	float r = texture(logo_tex, base + vec2(split, 0.0)).r;
	float g = texture(logo_tex, base).g;
	float b = texture(logo_tex, base - vec2(split, 0.0)).b;
	return vec3(r, g, b);
}

void fragment() {
	vec2 uv = cover_uv(UV);
	vec3 col = sample_glitched(uv);

	// Rotating HUD rings around the emblem (image space keeps them aligned with the art).
	vec2 p = uv - ring_center;
	float rings = 0.0;
	rings += ring(p, 0.235, 0.0018, 3.0, 0.62, 0.035) * 0.55;
	rings += ring(p, 0.275, 0.0010, 96.0, 0.35, -0.010) * 0.45;
	rings += ring(p, 0.315, 0.0022, 5.0, 0.40, -0.022) * 0.50;
	rings += ring(p, 0.360, 0.0012, 2.0, 0.30, 0.015) * 0.40;
	rings += ring(p, 0.400, 0.0009, 160.0, 0.20, 0.006) * 0.30;
	// Keep the title readable: rings fade where the art is already bright.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float title_zone = smoothstep(title_band.x - 0.03, title_band.x, uv.y) * (1.0 - smoothstep(title_band.y, title_band.y + 0.03, uv.y));
	rings *= (1.0 - smoothstep(0.3, 0.6, lum)) * (1.0 - 0.75 * title_zone);
	col += mix(ring_color, accent_color, step(0.33, length(p))) * rings * ring_intensity * fx_strength;

	// Pulsing core light at the base of the spire + soft vertical beam.
	vec2 d = (uv - core_light_pos) * vec2(1.0, 0.8);
	float pulse = 0.55 + 0.45 * sin(TIME * 1.7);
	float core = exp(-dot(d, d) * 140.0) * (0.10 + 0.14 * pulse);
	float beam = exp(-abs(uv.x - core_light_pos.x) * 140.0) * smoothstep(core_light_pos.y + 0.05, 0.0, uv.y);
	beam *= 0.10 + 0.08 * sin(TIME * 3.1 + uv.y * 30.0);
	col += ring_color * (core + beam) * fx_strength;

	// Light sweep across bright pixels of the title.
	float sweep_t = fract(TIME / sweep_period) * 1.8 - 0.4;
	float sweep = exp(-pow((uv.x + (uv.y - title_band.x) * 0.35 - sweep_t) * 14.0, 2.0));
	float title_mask = step(title_band.x, uv.y) * step(uv.y, title_band.y) * smoothstep(0.45, 0.85, lum);
	col += vec3(0.9, 0.95, 1.0) * sweep * title_mask * 0.6 * fx_strength;

	// Breathing vignette.
	vec2 v = UV - 0.5;
	float vignette = 1.0 - dot(v, v) * (0.9 + 0.1 * sin(TIME * 0.8));
	col *= clamp(vignette, 0.0, 1.0);

	COLOR = vec4(col * reveal, 1.0);
}
