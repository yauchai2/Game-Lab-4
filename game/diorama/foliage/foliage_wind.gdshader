shader_type spatial;
render_mode cull_disabled, diffuse_lambert, world_vertex_coords;

uniform vec2 wind_direction = vec2(0.91, 0.42);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.75;
uniform float wind_clock = -1.0;
varying vec3 stable_position;
varying vec3 rest_normal;

void vertex() {
	stable_position = VERTEX - MODEL_MATRIX[3].xyz;
	rest_normal = NORMAL;
	float time = wind_clock < 0.0 ? TIME : wind_clock;
	vec2 direction = normalize(wind_direction + vec2(0.00001));
	vec2 crosswind = vec2(-direction.y, direction.x);
	float phase = dot(MODEL_MATRIX[3].xz, direction) * 0.62;
	float gust = sin(time * 1.85 - phase) * 0.69 + sin(time * 0.85 - phase * 0.6) * 0.31;
	float local_flutter = sin(time * 3.8 - phase + dot(stable_position, vec3(1.4, 3.6, 1.9)));
	VERTEX.xz += wind_strength * (
		direction * (gust * UV.x + local_flutter * UV.y * 0.31)
		+ crosswind * (sin(time * 1.3 - phase * 0.8) * UV.x * 0.25)
	);
}

void fragment() {
	// Consistent canopy shading, anchored to the resting mesh as it moves.
	float facing_up = clamp(normalize(rest_normal).y * 0.5 + 0.5, 0.0, 1.0);
	float leaf_weight = smoothstep(0.001, 0.033, UV.y) * COLOR.a;
	if (COLOR.a < 0.5) {
		NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	}
	vec3 leaf_shade = mix(vec3(0.54, 0.74, 0.79), vec3(1.12, 1.10, 0.85), facing_up);
	ALBEDO = COLOR.rgb * mix(vec3(1.0), leaf_shade, leaf_weight);
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
}
