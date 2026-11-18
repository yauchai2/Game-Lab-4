shader_type spatial;
render_mode unshaded;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float bank_distance(vec2 p, vec2 center, vec2 half_size) {
	vec2 edge = abs(p - center) - half_size;
	return length(max(edge, vec2(0.0)));
}

void fragment() {
	vec2 p = world_xz;
	float coast = min(
		bank_distance(p, vec2(-5.5, 0.5), vec2(4.0, 5.0)),
		bank_distance(p, vec2(5.5, 0.5), vec2(4.0, 5.0))
	);
	coast = min(coast, bank_distance(p, vec2(0.0, 3.5), vec2(1.5, 1.0)));
	float ripple = sin(p.y * 5.0 - TIME * 1.3 + sin(p.x * 2.2)) * 0.5 + 0.5;
	float line = 1.0 - smoothstep(0.025, 0.095, abs(coast - 0.18 - ripple * 0.09));
	vec3 deep = vec3(0.14, 0.32, 0.41);
	vec3 shallow = vec3(0.33, 0.65, 0.65);
	vec3 water = mix(shallow, deep, smoothstep(0.0, 2.8, coast));
	ALBEDO = mix(water + ripple * 0.028, vec3(0.71, 0.85, 0.82), line * 0.72);
}
