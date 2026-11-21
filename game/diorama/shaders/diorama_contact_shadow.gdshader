shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;

// Ultra-soft radial Contact Shadow Decal (glues every tree, rock, cabin & character to the 3D terrain like vC7OEC!)
uniform vec4 shadow_color : source_color = vec4(0.07, 0.11, 0.26, 0.38);

void fragment() {
	float d = length(UV * 2.0 - vec2(1.0));
	float mask = smoothstep(1.0, 0.15, d);
	mask = mask * mask;
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * mask;
}
