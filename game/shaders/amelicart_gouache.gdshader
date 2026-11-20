shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// @amelicart-inspired lineless matte gouache, dry-brush grain & colored shadows
uniform vec4 albedo_color : source_color = vec4(0.55, 0.72, 0.35, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.32, 0.34, 0.56, 1.0);
uniform float grain_strength : hint_range(0.0, 0.35) = 0.11;
uniform float hatch_strength : hint_range(0.0, 0.35) = 0.10;
uniform float cel_steps : hint_range(2.0, 5.0) = 3.0;
uniform float ambient_lift : hint_range(0.0, 0.45) = 0.18;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Dry-brush directional gouache streaks + chalky paper grain (world-space, no UV seams)
	vec2 p_xy = v_world_pos.xz * vec2(1.4, 3.8);
	vec2 p_side = vec2(v_world_pos.x + v_world_pos.z, v_world_pos.y * 3.4);
	float top_w = abs(v_world_nrm.y);
	vec2 sample_uv = mix(p_side, p_xy, smoothstep(0.35, 0.75, top_w));

	float brush = value_noise(sample_uv * 2.2) * 0.65 + value_noise(sample_uv * 7.5) * 0.35;
	float paper = hash21(floor(sample_uv * 26.0));
	float delta_val = (brush - 0.5) * grain_strength + (paper - 0.5) * (grain_strength * 0.45);

	vec3 col = clamp(albedo_color.rgb + vec3(delta_val), 0.0, 1.0);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	// Slight unlit storybook lift so dark areas stay luminous like watercolor/gouache
	EMISSION = col * ambient_lift;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float raw = clamp(ndotl * 0.5 + 0.5, 0.0, 1.0);
	float stepped = floor(raw * cel_steps + 0.35) / cel_steps;
	float lit_factor = clamp(stepped * ATTENUATION, 0.0, 1.0);

	// Selective hand-drawn hatching lines (///) softly appearing only in mid-shadow
	float hatch_wave = sin((v_world_pos.x + v_world_pos.z - v_world_pos.y) * 28.0);
	float hatch_mask = smoothstep(0.65, 0.25, lit_factor) * smoothstep(0.65, 0.92, hatch_wave);
	vec3 shaded = mix(shadow_tint.rgb, vec3(1.0, 0.99, 0.95), lit_factor);
	shaded *= (1.0 - hatch_mask * hatch_strength);

	DIFFUSE_LIGHT += ALBEDO * shaded * LIGHT_COLOR / PI;
}
