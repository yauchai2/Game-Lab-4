shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

// Clean Low-Contrast Fluffy Grass Tufts (Upward-Locked Normal + Ground-Matched Root — ZERO Black Ants!)
uniform float night_mix : hint_range(0.0, 1.0) = 1.0;

varying float v_tip;
varying vec3 v_col;

global uniform vec2 wind_direction;
global uniform float wind_speed;
global uniform float wind_strength;

void vertex() {
	v_tip = clamp(UV.y, 0.0, 1.0);
	v_col = COLOR.rgb;
	// Force normal straight UP so grass receives identical lighting to the ground beneath it!
	NORMAL = vec3(0.0, 1.0, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind = normalize(wind_direction);
	float gust = sin(dot(wp.xz, wind) * 0.52 - TIME * wind_speed * 1.25);
	float sway = gust * (0.18 + 0.22 * sin(TIME * 0.39)) * wind_strength * v_tip * v_tip;
	vec3 world_bend = vec3(wind.x, 0.0, wind.y);
	vec2 local_bend = vec2(dot(normalize(MODEL_MATRIX[0].xyz), world_bend),
		dot(normalize(MODEL_MATRIX[2].xyz), world_bend));
	VERTEX.xz += local_bend * sway;
}

void fragment() {
	// Double-sided cards share the ground normal even when seen from the back.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	// Root (UV.y = 0) matches ground color 1:1; tip (UV.y = 1) lifts gently without dark contrast!
	vec3 col = v_col * mix(1.00, 1.15, v_tip);
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = col * mix(0.02, 0.14, night_mix);
}
