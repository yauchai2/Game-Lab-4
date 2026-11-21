shader_type spatial;
render_mode diffuse_lambert;

// Restrained Velvety Painterly GLB Shader (Zero Neon Overexposure! Preserves Real Soft Shadows & Volume!)
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool has_albedo_tex = true;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_mix : hint_range(0.0, 0.85) = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.13, 0.18, 0.42, 1.0);
uniform float brightness : hint_range(0.4, 1.6) = 1.02;
uniform float saturation : hint_range(0.4, 1.6) = 1.06;
uniform float ambient_lift : hint_range(0.0, 0.18) = 0.05;

void fragment() {
	vec3 tex_c = has_albedo_tex ? texture(albedo_tex, UV).rgb : vec3(1.0);
	vec3 col = tex_c * base_color.rgb * brightness;

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	// Softly blend art-directed palette tint without clipping highlights to neon
	col = mix(col, tint_color.rgb * clamp(luma * 1.25 + 0.22, 0.25, 1.05), tint_mix);

	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.06;
	EMISSION = col * ambient_lift;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndotl + 0.30) / 1.30, 0.0, 1.0);
	float soft_cel = mix(wrap, smoothstep(0.14, 0.86, wrap), 0.38);
	float lit = clamp(soft_cel * ATTENUATION, 0.0, 1.0);
	vec3 shaded = mix(shadow_tint.rgb, vec3(1.0, 0.99, 0.95), lit);
	DIFFUSE_LIGHT += ALBEDO * shaded * LIGHT_COLOR / PI;
}
