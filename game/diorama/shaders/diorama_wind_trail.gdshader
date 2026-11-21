shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform vec4 trail_color : source_color = vec4(0.95, 0.98, 1.0, 0.78);
uniform float speed = 0.26;
uniform float phase_offset = 0.0;
uniform float streak_len = 0.34;

global uniform vec2 wind_direction;
global uniform float wind_speed;

// Reorient the narrow curve strip towards the camera at each point.
void vertex() {
	vec3 position_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tangent_view = (MODELVIEW_MATRIX * vec4(CUSTOM0.xyz, 0.0)).xyz;
	vec2 perpendicular = vec2(-tangent_view.y, tangent_view.x);
	perpendicular /= max(length(perpendicular), 0.001);
	float width = CUSTOM0.w * mix(0.23, 1.0, sin(UV.x * PI));
	float stroke_side = UV.y * 2.0 - 1.0;
	vec3 breeze = vec3(wind_direction.x, 0.0, wind_direction.y);
	vec3 drift = (VIEW_MATRIX * vec4(breeze, 0.0)).xyz
		* sin(TIME * wind_speed * 0.67 + phase_offset * TAU) * 0.22;
	VERTEX = position_view + vec3(perpendicular * width * stroke_side, 0.0) + drift;
}

void fragment() {
	float head = fract(TIME * speed + phase_offset) * 1.45 - 0.15;
	float distance_from_head = head - UV.x;
	float tail = 1.0 - smoothstep(0.025, streak_len, distance_from_head);
	float nose = smoothstep(-0.045, 0.01, distance_from_head);
	float width_fade = pow(sin(UV.y * PI), 1.55);
	float path_fade = smoothstep(0.01, 0.15, UV.x) * (1.0 - smoothstep(0.82, 0.99, UV.x));

	ALBEDO = trail_color.rgb;
	ALPHA = tail * nose * width_fade * path_fade * trail_color.a;
}
