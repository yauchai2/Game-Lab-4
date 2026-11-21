shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

// Organic Curved Waterfall Ribbon with Soft Feathered Edges & Seamless Water Blend!
uniform vec4 water_top : source_color = vec4(0.46, 0.84, 1.0, 0.92);
uniform vec4 water_bot : source_color = vec4(0.20, 0.56, 0.92, 0.90);
uniform vec4 streak_col : source_color = vec4(0.92, 0.98, 1.0, 0.95);

void fragment() {
	vec2 uv = UV;
	float s1 = sin(uv.x * 24.0 + sin(uv.y * 5.0 - TIME * 3.0) * 0.5) * 0.5 + 0.5;
	float scroll = fract(uv.y * 2.4 - TIME * 1.9 + floor(uv.x * 9.0) * 0.19);
	float streak = smoothstep(0.58, 0.86, s1) * smoothstep(0.12, 0.52, scroll) * smoothstep(0.95, 0.62, scroll);
	float top_foam = smoothstep(0.18, 0.0, uv.y) * 0.72;
	float bot_foam = smoothstep(0.76, 1.0, uv.y) * 0.88;

	vec3 col = mix(water_top.rgb, water_bot.rgb, uv.y);
	col = mix(col, streak_col.rgb, clamp(streak * 0.78 + top_foam + bot_foam, 0.0, 1.0));
	// Softly feather left/right edges AND bottom transition so it NEVER looks like a rectangular sticker!
	float side_fade = smoothstep(0.0, 0.22, uv.x) * smoothstep(1.0, 0.78, uv.x);
	float bot_fade = smoothstep(1.0, 0.90, uv.y);

	ALBEDO = col;
	ALPHA = side_fade * bot_fade * 0.94;
}
