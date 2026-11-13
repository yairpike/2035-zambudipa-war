shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert;

uniform sampler2D shallow_tex : source_color, repeat_enable, hint_default_white;
uniform sampler2D deep_tex : source_color, repeat_enable, hint_default_white;
uniform float use_tex = 0.0;

void vertex() {
	float amp = mix(0.07, 0.035, COLOR.r);
	VERTEX.y += sin(VERTEX.x * 0.42 + TIME * 1.25) * cos(VERTEX.z * 0.31 + TIME * 0.85) * amp;
}

void fragment() {
	vec3 shallow_col = vec3(0.18, 0.48, 0.52);
	vec3 deep_col = vec3(0.04, 0.12, 0.2);
	vec3 painted = mix(shallow_col, deep_col, COLOR.r);
	vec3 sampled = mix(texture(shallow_tex, UV).rgb, texture(deep_tex, UV).rgb, COLOR.r);
	vec3 water = mix(painted, sampled, clamp(use_tex, 0.0, 1.0));
	float foam = pow(1.0 - COLOR.r, 2.4) * 0.22;
	ALBEDO = mix(water, vec3(0.72, 0.82, 0.78), foam);
	ROUGHNESS = mix(0.18, 0.08, COLOR.r);
	METALLIC = 0.04;
	ALPHA = mix(0.82, 0.96, COLOR.r);
}
