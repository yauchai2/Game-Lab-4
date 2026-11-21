shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// vC7OEC Signature Stylized White Wind Trails (Scrolling Gradient Streak along Curved 3D Bezier Ribbons!)
uniform vec4 trail_color : source_color = vec4(0.95, 0.98, 1.0, 0.78);
uniform float speed = 0.26;
uniform float phase_offset = 0.0;
uniform float streak_len = 0.34;

void fragment() {
	// Scrolling head-to-tail breeze streak along UV.x
	float head = fract(TIME * speed + phase_offset) * 1.45 - 0.15;
	float dist_behind = head - UV.x;
	float in_streak = smoothstep(streak_len, 0.0, dist_behind) * smoothstep(-0.04, 0.02, dist_behind);

	// Taper softly at ribbon edges (UV.y) and overall path ends (UV.x)
	float width_fade = sin(UV.y * PI);
	float path_fade = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float alpha = in_streak * width_fade * path_fade * trail_color.a;

	ALBEDO = trail_color.rgb;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
