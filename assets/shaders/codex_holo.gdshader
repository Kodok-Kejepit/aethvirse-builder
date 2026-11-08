shader_type canvas_item;
// Codex "System" card: dark tinted glass (jade / violet by hero), a faint sweep of light,
// fine grain, and a double trim frame (gold / silver) with diamond studs at the corners.

uniform vec4 base_color : source_color = vec4(0.02, 0.08, 0.06, 0.96);
uniform vec4 glow_color : source_color = vec4(0.52, 0.92, 0.74, 1.0);
uniform vec4 trim_color : source_color = vec4(0.9, 0.76, 0.45, 1.0);
uniform float scan_density = 220.0;
uniform float frame_px = 3.0;
uniform vec2 rect_size = vec2(1600.0, 900.0);
uniform float open_t = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float line_at(float edge, float at, float width) {
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + 0.8, abs(edge - at));
}

void fragment() {
	vec2 px = UV * rect_size;
	vec3 col = base_color.rgb;
	// Light from the top, a slow soft sweep, faint scanlines and grain.
	col += glow_color.rgb * 0.05 * (1.0 - UV.y);
	float sweep = smoothstep(0.1, 0.0, abs(fract(UV.y - TIME * 0.05) - 0.5));
	col += glow_color.rgb * 0.025 * sweep;
	col += glow_color.rgb * 0.008 * (0.5 + 0.5 * sin((UV.y + TIME * 0.02) * scan_density * 3.14159));
	col += (hash(floor(px * 0.5) + floor(TIME * 12.0)) - 0.5) * 0.01;
	// Vignette.
	vec2 c = UV - 0.5;
	col *= 1.0 - dot(c, c) * 0.6;
	// Double trim frame.
	float edge = min(min(px.x, px.y), min(rect_size.x - px.x, rect_size.y - px.y));
	float trim = max(line_at(edge, 2.0, 2.0), line_at(edge, 10.0, 1.2));
	col = mix(col, trim_color.rgb, trim);
	// Inner glow along the frame.
	col += trim_color.rgb * 0.08 * smoothstep(40.0, 0.0, edge);
	// Diamond studs at the corners.
	vec2 q = min(px, rect_size - px);
	float diamond = 1.0 - smoothstep(6.0, 7.5, abs(q.x - 10.0) + abs(q.y - 10.0));
	col = mix(col, trim_color.rgb * 1.15, diamond);
	float a = base_color.a * open_t;
	COLOR = vec4(col, max(a, trim * open_t));
}
