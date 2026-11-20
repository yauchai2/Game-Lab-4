shader_type spatial;
render_mode unshaded, cull_disabled;

// Animated stylized ocean / starry lake / rolling sunset cloud-sea (zero flat single-color void!)
uniform vec4 deep_color : source_color = vec4(0.10, 0.44, 0.82, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.68, 0.94, 1.0);
uniform vec4 foam_color : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float wave_scale : hint_range(0.02, 0.6) = 0.14;
uniform float wave_speed : hint_range(0.05, 1.5) = 0.35;
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv1 = v_world_pos.xz * wave_scale + vec2(TIME * wave_speed, TIME * wave_speed * 0.45);
	vec2 uv2 = v_world_pos.xz * (wave_scale * 1.85) - vec2(TIME * wave_speed * 0.65, -TIME * wave_speed * 0.32);

	float n1 = vnoise(uv1);
	float n2 = vnoise(uv2);
	float blend = clamp(n1 * 0.6 + n2 * 0.4, 0.0, 1.0);

	// Painterly stepped water/cloud bands so it never looks like a flat color
	float bands = floor(blend * 4.0) / 4.0;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, mix(blend, bands, 0.45));

	// Stylized rippling white foam rings & wave crests (@shoejaat Little Joy look)
	float crest = smoothstep(0.73, 0.80, blend);
	col = mix(col, foam_color.rgb, crest * 0.52);

	// Subtle sparkling dots on water surface (like e986e55c ocean stars)
	vec2 cell = floor(v_world_pos.xz * 0.85);
	float sp = hash21(cell);
	float twinkle = smoothstep(0.965, 0.995, sp) * (0.5 + 0.5 * sin(TIME * 2.8 + sp * 40.0));
	col = mix(col, foam_color.rgb, twinkle * sparkle_amount);

	ALBEDO = col;
}
