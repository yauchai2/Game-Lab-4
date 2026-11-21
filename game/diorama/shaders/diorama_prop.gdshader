shader_type spatial;
render_mode diffuse_lambert;

// Velvety Painterly Diorama Prop Shader (Uses Godot Native Ambient + Soft Shadows + vC7OEC Vertical Gradient & Base AO!)
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool has_albedo_tex = true;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_mix : hint_range(0.0, 0.90) = 0.0;
uniform float brightness : hint_range(0.4, 1.8) = 1.08;
uniform float saturation : hint_range(0.4, 1.6) = 1.08;
uniform float ambient_lift : hint_range(0.0, 0.35) = 0.16;
uniform float grad_strength : hint_range(0.0, 0.60) = 0.26;
uniform float min_y = -0.5;
uniform float max_y = 0.5;

varying float v_norm_y;

void vertex() {
	v_norm_y = clamp((VERTEX.y - min_y) / max(0.001, max_y - min_y), 0.0, 1.0);
}

void fragment() {
	vec3 tex_c = has_albedo_tex ? texture(albedo_tex, UV).rgb : vec3(1.0);
	vec3 col = tex_c * base_color.rgb * brightness;

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	// Blend art-directed storybook palette tint cleanly (preserves light/dark detail!)
	vec3 tinted = tint_color.rgb * clamp(luma * 1.15 + 0.38, 0.42, 1.15);
	col = mix(col, tinted, tint_mix);

	// vC7OEC signature: Top-to-Bottom painterly gradient (brighter crown tips, softer cool-grounded base AO!)
	float grad = mix(1.0 - grad_strength * 0.72, 1.0 + grad_strength * 0.48, smoothstep(0.05, 0.92, v_norm_y));
	col *= grad;

	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
	SPECULAR = 0.04;
	EMISSION = col * ambient_lift;
}
