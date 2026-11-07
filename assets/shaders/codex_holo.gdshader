shader_type canvas_item;
// Codex "System" window: deep blue glass with moving scanlines, a soft vertical sweep,
// faint hex-grain and a glowing frame.

uniform vec4 base_color : source_color = vec4(0.02, 0.05, 0.11, 0.975);
uniform vec4 glow_color : source_color = vec4(0.45, 0.8, 1.0, 1.0);
uniform float scan_density = 220.0;
uniform float frame_px = 3.0;
uniform vec2 rect_size = vec2(1600.0, 900.0);
uniform float open_t = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec3 col = base_color.rgb;
	// Vertical gradient (lighter at the top like a monitor).
	col += glow_color.rgb * 0.06 * (1.0 - UV.y);
	// Scanlines drifting down.
	float scan = 0.5 + 0.5 * sin((UV.y + TIME * 0.02) * scan_density * 3.14159);
	col += glow_color.rgb * 0.025 * scan;
	// Slow bright sweep.
	float sweep = smoothstep(0.08, 0.0, abs(fract(UV.y - TIME * 0.07) - 0.5));
	col += glow_color.rgb * 0.05 * sweep;
	// Grain.
	col += (hash(floor(px * 0.5) + floor(TIME * 12.0)) - 0.5) * 0.012;
	// Frame glow.
	float edge = min(min(px.x, px.y), min(rect_size.x - px.x, rect_size.y - px.y));
	float frame = smoothstep(frame_px + 14.0, frame_px, edge);
	col = mix(col, glow_color.rgb, frame * 0.35);
	if (edge < frame_px) {
		col = glow_color.rgb;
	}
	// Corner brackets.
	float corner = step(min(px.x, rect_size.x - px.x), 46.0) * step(min(px.y, rect_size.y - px.y), 46.0);
	if (corner > 0.5 && edge < frame_px + 3.0) {
		col = vec3(1.0);
	}
	float a = base_color.a * open_t;
	COLOR = vec4(col, max(a, frame * open_t));
}
