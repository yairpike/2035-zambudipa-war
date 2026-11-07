shader_type canvas_item;
// Faction plate surface for HUD frames. The item's StyleBoxFlat draws the shape:
// fill pixels arrive in the metal colour, trim pixels in the trim colour.
// pattern: 0 teak grain (GTFC), 1 songket lattice (NMRF), 2 circuit lines (MVD), 3 primer patches (Black Market).

uniform vec4 metal : source_color;
uniform vec4 metal_hi : source_color;
uniform vec4 trim : source_color;
uniform vec4 accent : source_color;
uniform vec4 glow : source_color;
uniform int pattern = 0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 src = COLOR;
	if (src.a < 0.9) {
		COLOR = src;
	} else {
		vec2 p = FRAGCOORD.xy;
		float brushed = vnoise(vec2(p.x * 0.015, p.y * 0.9)) * 0.6 + hash(vec2(floor(p.y), 3.0)) * 0.4;
		bool is_trim = distance(src.rgb, metal.rgb) > 0.06;
		vec3 col;
		if (is_trim) {
			float sheen = 0.78 + 0.42 * brushed + 0.12 * sin(p.x * 0.05 + p.y * 0.05);
			col = trim.rgb * sheen;
		} else if (pattern == 0) {
			float warp = vnoise(vec2(p.x * 0.008, p.y * 0.04)) * 5.0;
			float grain = 0.5 + 0.5 * sin(p.y * 0.42 + warp);
			float fine = vnoise(vec2(p.x * 0.05, p.y * 1.4));
			col = mix(metal.rgb, metal_hi.rgb, 0.18 + 0.32 * grain * grain + 0.12 * fine);
		} else if (pattern == 1) {
			col = mix(metal.rgb, metal_hi.rgb, 0.22 + 0.3 * brushed);
			float d = abs(fract((p.x + p.y) / 16.0) - 0.5);
			float e = abs(fract((p.x - p.y) / 16.0) - 0.5);
			float lattice = smoothstep(0.07, 0.0, min(d, e));
			col = mix(col, trim.rgb, lattice * 0.14);
		} else if (pattern == 2) {
			col = mix(metal.rgb, metal_hi.rgb, 0.12 + 0.28 * brushed);
			vec2 cell = fract(p / vec2(28.0, 18.0));
			float line = max(smoothstep(0.03, 0.0, abs(cell.y - 0.5)) * step(0.35, hash(floor(p / vec2(28.0, 18.0)))),
				smoothstep(0.02, 0.0, abs(cell.x - 0.5)) * step(0.7, hash(floor(p / vec2(28.0, 18.0)) + 7.0)));
			col = mix(col, glow.rgb, line * 0.12);
		} else {
			col = mix(metal.rgb, metal_hi.rgb, 0.1 + 0.35 * brushed);
			float patch = smoothstep(0.58, 0.64, vnoise(p * 0.011 + 4.0));
			col = mix(col, vec3(0.3, 0.17, 0.13), patch * 0.55);
			float scratch = step(0.985, hash(vec2(floor(p.x / 3.0), floor(p.y / 40.0))));
			col += vec3(0.18) * scratch;
		}
		COLOR = vec4(col, src.a);
	}
}
