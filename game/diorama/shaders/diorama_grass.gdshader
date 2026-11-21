shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

// Seamless Fluffy Lawn Grass Tufts (Upward Normals + Root-Matched Seamless Base Color + Gentle Breeze!)
uniform float night_mix : hint_range(0.0, 1.0) = 1.0;

varying float v_tip;
varying vec3 v_col;

void vertex() {
	v_tip = clamp(UV.y, 0.0, 1.0);
	v_col = COLOR.rgb;
	// Lock ALL grass normals straight UP so grass blends seamlessly with ground lighting (ZERO weird black shadows!)
	NORMAL = vec3(0.0, 1.0, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 2.0 + wp.x * 0.72 + wp.z * 0.62) * 0.055 * v_tip * v_tip;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.40;
}

void fragment() {
	// Seamless root color matching lawn -> subtly brighter sunlit/warm tips!
	vec3 col = v_col * mix(0.94, 1.22, v_tip);
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = col * mix(0.03, 0.14, night_mix);
}
