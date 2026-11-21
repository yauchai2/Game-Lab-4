shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// vC7OEC Fake Volumetric God Rays (Additive Blending + Soft Fresnel Edge Fade + Smooth Vertical Fade!)
uniform vec4 ray_color : source_color = vec4(1.0, 0.94, 0.62, 0.28);

void fragment() {
	// Soft horizontal beam profile + animated dappled canopy shimmer
	float edge_x = pow(sin(UV.x * PI), 1.6);
	float vert_fade = smoothstep(0.0, 0.22, UV.y) * smoothstep(1.0, 0.18, UV.y);
	float shimmer = 0.84 + 0.16 * sin(UV.x * 11.0 + TIME * 0.75);
	// Soft Fresnel view-angle fade so beam never looks like a flat intersecting card
	float fresnel = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.65);

	float alpha = edge_x * vert_fade * shimmer * fresnel * ray_color.a;
	ALBEDO = ray_color.rgb * alpha;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
