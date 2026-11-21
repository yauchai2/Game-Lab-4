shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// vC7OEC-inspired Soft Diagonal Volumetric God-Ray Shafts!
uniform vec4 ray_color : source_color = vec4(0.58, 0.78, 1.0, 0.16);
uniform float pulse_speed = 0.75;

void fragment() {
	// Soft Gaussian-like falloff on left/right edges & top/bottom ends (zero hard quad edges!)
	float x_fade = sin(UV.x * 3.14159265);
	x_fade = pow(clamp(x_fade, 0.0, 1.0), 1.8);
	float y_fade = smoothstep(0.0, 0.32, UV.y) * smoothstep(1.0, 0.18, UV.y);
	float shimmer = 0.82 + 0.18 * sin(TIME * pulse_speed + UV.x * 5.0);
	ALBEDO = ray_color.rgb;
	ALPHA = ray_color.a * x_fade * y_fade * shimmer;
}
