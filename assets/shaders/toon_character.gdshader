shader_type spatial;
render_mode diffuse_toon, specular_toon;
// Anime-style character surface: flat toon light, soft rim, optional starry "galaxy" fabric
// (twinkling stars in mesh space) and an optional vertical colour gradient (hair tips, sleeves).

uniform vec4 albedo : source_color = vec4(1.0);
// Gradient end colour, blended over local Y from grad_top to grad_bottom (metres, mesh space).
uniform vec4 albedo_end : source_color = vec4(1.0);
uniform float grad_top = 0.0;
uniform float grad_bottom = 0.0;
uniform float roughness = 0.75;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.95, 1.0);
uniform float rim_strength = 0.3;
// 0 = plain fabric, 1 = galaxy suit.
uniform float star_amount = 0.0;
uniform vec4 star_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float star_scale = 34.0;

varying vec3 local_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 base = albedo.rgb;
	if (grad_top != grad_bottom) {
		float g = clamp((local_pos.y - grad_top) / (grad_bottom - grad_top), 0.0, 1.0);
		base = mix(albedo.rgb, albedo_end.rgb, smoothstep(0.0, 1.0, g));
	}
	vec3 glow = emission.rgb * emission_energy;
	if (star_amount > 0.0) {
		vec3 q = local_pos * star_scale;
		vec3 cell = floor(q);
		float h = hash(cell);
		float d = length(fract(q) - 0.5);
		float star = step(0.9, h) * smoothstep(0.22, 0.0, d);
		float twinkle = 0.55 + 0.45 * sin(TIME * 2.6 + h * 47.0);
		glow += star_color.rgb * star * twinkle * star_amount * 1.6;
		float nebula = hash(floor(local_pos * 5.0));
		base = mix(base, base * vec3(1.5, 0.9, 1.8), nebula * 0.45 * star_amount);
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	glow += rim_color.rgb * rim * rim_strength;
	ALBEDO = base;
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	EMISSION = glow;
}
