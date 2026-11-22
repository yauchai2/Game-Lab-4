global uniform vec2 wind_direction;
global uniform float wind_speed;
global uniform float wind_strength;
uniform sampler2D wind_field : repeat_enable, filter_linear_mipmap;

float diorama_gust(vec2 world_xz, float time) {
	vec2 direction = normalize(wind_direction);
	vec2 drift = direction * time * wind_speed * 0.035;
	float broad = textureLod(wind_field, world_xz * 0.033 - drift, 1.0).r * 2.0 - 1.0;
	float pulse = sin(dot(world_xz, direction) * 0.52 - time * wind_speed * 1.25);
	return broad * 0.64 + pulse * 0.36;
}

vec2 diorama_bend(vec2 world_xz, float time) {
	return normalize(wind_direction) * diorama_gust(world_xz, time) * wind_strength;
}
