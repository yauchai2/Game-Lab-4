shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

// Stylized Painterly Grass Tuft Shader (06_29_51 & vC7OEC signature grass blades!)
uniform float night_mix : hint_range(0.0, 1.0) = 1.0;

varying float v_tip;
varying vec3 v_col;

void vertex() {
	v_tip = clamp(UV.y, 0.0, 1.0);
	v_col = COLOR.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 2.1 + wp.x * 0.75 + wp.z * 0.65) * 0.07 * v_tip * v_tip;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.45;
}

void fragment() {
	// Grounded darker base -> brighter painted tip
	vec3 col = v_col * mix(0.68, 1.18, v_tip);
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	SPECULAR = 0.02;
	EMISSION = col * mix(0.04, 0.08, night_mix);
}
