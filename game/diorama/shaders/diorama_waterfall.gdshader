shader_type spatial;
render_mode blend_mix, diffuse_lambert, cull_disabled;

// Soft Lit Painterly Waterfall (NO Overexposed Unshaded Neon + Strong Left/Right UV Alpha Fade!)
uniform vec4 water_top : source_color = vec4(0.44, 0.66, 0.82, 0.90);
uniform vec4 water_bot : source_color = vec4(0.26, 0.46, 0.66, 0.88);
uniform vec4 streak_col : source_color = vec4(0.76, 0.86, 0.94, 0.92);

void fragment() {
	vec2 uv = UV;
	float s1 = sin(uv.x * 22.0 + sin(uv.y * 5.0 - TIME * 2.8) * 0.5) * 0.5 + 0.5;
	float scroll = fract(uv.y * 2.2 - TIME * 1.7 + floor(uv.x * 8.0) * 0.19);
	float streak = smoothstep(0.60, 0.88, s1) * smoothstep(0.14, 0.52, scroll) * smoothstep(0.94, 0.62, scroll);
	float top_foam = smoothstep(0.16, 0.0, uv.y) * 0.55;
	float bot_foam = smoothstep(0.78, 1.0, uv.y) * 0.65;

	vec3 col = mix(water_top.rgb, water_bot.rgb, uv.y);
	col = mix(col, streak_col.rgb, clamp(streak * 0.68 + top_foam + bot_foam, 0.0, 1.0));
	// Strong smooth left/right & bottom UV alpha fade — ZERO rectangular edge!
	float side_fade = smoothstep(0.0, 0.28, uv.x) * smoothstep(1.0, 0.72, uv.x);
	float bot_fade = smoothstep(1.0, 0.86, uv.y);

	ALBEDO = col;
	ALPHA = side_fade * bot_fade * 0.92;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.04;
	EMISSION = vec3(0.0);
}
