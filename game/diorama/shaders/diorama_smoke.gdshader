shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, cull_back;

uniform float night_mix = 0.0;
uniform float opacity = 0.5;

void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float silver_light = smoothstep(-0.42, 0.80, dot(world_normal, vec3(-0.4, 0.88, 0.22)));
	ALBEDO = mix(vec3(0.65, 0.72, 0.77), vec3(0.99, 0.96, 0.87), silver_light);
	ALBEDO *= mix(vec3(1.0), vec3(0.44, 0.53, 0.69), night_mix);
	ALPHA = smoothstep(0.0, 0.67, facing) * opacity;
}
