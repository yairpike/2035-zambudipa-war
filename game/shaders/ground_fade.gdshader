shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float use_tex = 0.0;
uniform float contrast = 1.0;
uniform vec3 tone_mid : source_color = vec3(0.32, 0.24, 0.15);
uniform float wear = 0.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 tex = mix(vec3(1.0), texture(albedo_tex, UV).rgb, clamp(use_tex, 0.0, 1.0));
	tex = mix(tone_mid, tex, clamp(contrast, 0.0, 1.0));
	float n = hash21(floor(world_pos.xz * 3.2));
	tex *= mix(0.9, 1.08, n);
	if (wear > 0.01) {
		float rut = abs(sin(world_pos.x * 0.55) * 0.35 + sin(world_pos.z * 0.22) * 0.65);
		tex *= mix(1.0, mix(0.78, 1.0, rut), clamp(wear, 0.0, 1.0));
	}
	ALBEDO = tex * COLOR.rgb;
	ROUGHNESS = mix(0.94, 0.82, clamp(wear, 0.0, 1.0));
	float fringe = (value_noise(world_pos.xz * 1.6) - 0.5) * 0.7;
	ALPHA = clamp(COLOR.a + fringe, 0.0, 1.0) * 0.92;
}
