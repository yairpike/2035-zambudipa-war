shader_type canvas_item;
// Frosted glass for menus and dialogs. Works on GL Compatibility / WebGL 2.
// The screen copy's mip chain is a Gaussian-blurred downsample on Compatibility,
// so a few taps at a high LOD give a wide, smooth blur for very little fill cost.
// The item's own StyleBoxFlat gives the shape: COLOR.r is 0 inside, 1 on the border.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.06, 0.07, 0.09, 0.42);
uniform vec4 edge : source_color = vec4(1.0, 1.0, 1.0, 0.28);
uniform float lod = 3.6;
uniform float spread = 18.0;
uniform float saturation = 1.18;
uniform float lift = 0.02;

const vec2 TAPS[8] = vec2[](
	vec2(-0.613, 0.617), vec2(0.170, -0.040), vec2(-0.299, -0.792), vec2(0.645, 0.493),
	vec2(-0.651, -0.054), vec2(0.421, -0.706), vec2(-0.146, 0.951), vec2(0.952, -0.146)
);

void fragment() {
	vec3 acc = textureLod(screen_tex, SCREEN_UV, lod).rgb * 2.0;
	for (int i = 0; i < 8; i++) {
		acc += textureLod(screen_tex, SCREEN_UV + TAPS[i] * spread * SCREEN_PIXEL_SIZE, lod).rgb;
	}
	vec3 col = acc / 10.0;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = mix(col, tint.rgb, tint.a) + lift;
	float rim = clamp(COLOR.r, 0.0, 1.0);
	col = mix(col, edge.rgb, rim * edge.a);
	COLOR = vec4(col, COLOR.a);
}
