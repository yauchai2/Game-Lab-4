shader_type spatial;
render_mode blend_mix, diffuse_lambert, cull_disabled, depth_draw_never;

uniform vec4 water_top : source_color = vec4(0.46, 0.67, 0.80, 1.0);
uniform vec4 water_bot : source_color = vec4(0.34, 0.54, 0.70, 1.0);
uniform vec4 froth : source_color = vec4(0.76, 0.85, 0.89, 1.0);

void fragment() {
	vec2 uv = UV;
	float runoff = uv.y * (1.65 + 0.70 * uv.y) - TIME * 1.46;
	float drape = sin(uv.x * 19.0 + sin(uv.y * 4.4 - TIME * 0.85) * 0.8);
	float fine = sin(uv.x * 57.0 + cos(runoff * 3.2) * 0.95);
	float ribbon = smoothstep(0.05, 0.88, drape * 0.70 + fine * 0.30);
	float slide = 0.55 + 0.45 * sin(TAU * runoff + floor(uv.x * 7.0) * 1.7);
	float crest = (1.0 - smoothstep(0.0, 0.20, uv.y)) * 0.29;
	float skirt = smoothstep(0.60, 0.96, uv.y) * 0.34;
	vec3 col = mix(water_top.rgb, water_bot.rgb, uv.y);
	ALBEDO = mix(col, froth.rgb, clamp(ribbon * (0.21 + slide * 0.38) + crest + skirt, 0.0, 0.83));
	float edge = smoothstep(0.0, 0.25, uv.x) * (1.0 - smoothstep(0.75, 1.0, uv.x));
	float ends = smoothstep(0.0, 0.094, uv.y) * (1.0 - smoothstep(0.84, 1.0, uv.y));
	ALPHA = edge * ends * (0.64 + 0.24 * ribbon);
	ROUGHNESS = 0.87;
	SPECULAR = 0.07;
}
