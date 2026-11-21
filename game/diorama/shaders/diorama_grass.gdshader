shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

// Clean Low-Contrast Fluffy Grass Tufts (Upward-Locked Normal + Ground-Matched Root — ZERO Black Ants!)
uniform float night_mix : hint_range(0.0, 1.0) = 1.0;

varying float v_tip;
varying vec3 v_col;

void vertex() {
	v_tip = clamp(UV.y, 0.0, 1.0);
	v_col = COLOR.rgb;
	// Force normal straight UP so grass receives identical lighting to the ground beneath it!
	NORMAL = vec3(0.0, 1.0, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.9 + wp.x * 0.70 + wp.z * 0.60) * 0.045 * v_tip * v_tip;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.35;
}

void fragment() {
	// Root (UV.y = 0) matches ground color 1:1; tip (UV.y = 1) lifts gently without dark contrast!
	vec3 col = v_col * mix(1.00, 1.15, v_tip);
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = col * mix(0.02, 0.14, night_mix);
}
