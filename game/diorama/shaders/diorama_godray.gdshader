shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 ray_color : source_color = vec4(1.0, 0.92, 0.54, 0.32);
uniform float clear_air = 1.0;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;

void fragment() {
	float raw_depth = texture(scene_depth, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ndc.z = raw_depth * 2.0 - 1.0;
	#endif
	vec4 surface = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float gap = VERTEX.z - surface.z / surface.w;
	float contact = smoothstep(0.0, 1.2, gap);

	float width = mix(0.17, 0.49, UV.y);
	float center = abs(UV.x - 0.5);
	float edge = pow(1.0 - smoothstep(0.0, width, center), 1.4);
	float core_center = 0.09 + 0.035 * sin(UV.y * 4.0 + TIME * 0.34);
	float filaments = exp(-19.0 * abs(UV.x - 0.5 - core_center))
		+ exp(-26.0 * abs(UV.x - 0.5 + core_center));
	edge *= 0.74 + 0.34 * filaments;
	float length_fade = smoothstep(0.0, 0.16, UV.y) * (1.0 - smoothstep(0.56, 1.0, UV.y));
	float face = 0.30 + 0.70 * abs(dot(normalize(NORMAL), normalize(VIEW)));
	float shimmer = 0.93 + 0.07 * sin(UV.x * 11.0 + TIME * 0.68);
	ALBEDO = ray_color.rgb;
	ALPHA = edge * length_fade * face * shimmer * ray_color.a * contact * clear_air;
}
