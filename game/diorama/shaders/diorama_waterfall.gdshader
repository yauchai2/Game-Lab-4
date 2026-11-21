shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

// Stylized flowing waterfall ribbon (vC7OEC x 151bb106)
uniform vec4 water_top : source_color = vec4(0.45, 0.82, 1.0, 0.92);
uniform vec4 water_bot : source_color = vec4(0.24, 0.60, 0.94, 0.90);
uniform vec4 streak_col : source_color = vec4(0.90, 0.97, 1.0, 0.95);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float s1 = sin(uv.x * 26.0) * 0.5 + 0.5;
	float scroll = fract(uv.y * 2.4 - TIME * 1.85 + floor(uv.x * 10.0) * 0.17);
	float streak = smoothstep(0.62, 0.88, s1) * smoothstep(0.15, 0.55, scroll) * smoothstep(0.95, 0.65, scroll);
	float edge_foam = smoothstep(0.16, 0.0, uv.y) + smoothstep(0.82, 1.0, uv.y);

	vec3 col = mix(water_top.rgb, water_bot.rgb, uv.y);
	col = mix(col, streak_col.rgb, clamp(streak * 0.78 + edge_foam * 0.65, 0.0, 1.0));
	float side_fade = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);

	ALBEDO = col;
	ALPHA = side_fade * 0.94;
}
