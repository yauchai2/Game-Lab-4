shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

// Clean Low-Contrast Fluffy Grass Tufts (Upward-Locked Normal + Ground-Matched Root — ZERO Black Ants!)
uniform float night_mix : hint_range(0.0, 1.0) = 1.0;

varying float v_tip;
varying vec3 v_col;

#include "res://diorama/shaders/diorama_wind_field.gdshaderinc"

void vertex() {
	v_tip = clamp(UV.y, 0.0, 1.0);
	v_col = COLOR.rgb;
	// Force normal straight UP so grass receives identical lighting to the ground beneath it!
	NORMAL = vec3(0.0, 1.0, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 bend = diorama_bend(wp.xz, TIME) * v_tip * v_tip * 0.34;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(bend.x, 0.0, bend.y);
}

void fragment() {
	// Double-sided cards share the ground normal even when seen from the back.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	// Root (UV.y = 0) matches ground color 1:1; tip (UV.y = 1) lifts gently without dark contrast!
	vec3 col = v_col * mix(0.84, 1.09, v_tip);
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = col * mix(0.02, 0.14, night_mix);
}
