shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never;

void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * smoothstep(0.0, 0.78, facing);
}
