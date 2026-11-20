shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Painterly Volumetric Foliage Canopy (gouache brush clusters + synced wind + rim light)
global uniform vec2 wind_direction;
global uniform float wind_speed;
global uniform float wind_strength;
global uniform float wind_scale;

uniform vec4 foliage_color : source_color = vec4(0.48, 0.72, 0.34, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.76, 0.89, 0.48, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.28, 0.34, 0.54, 1.0);
uniform float cel_steps : hint_range(2.0, 5.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 0.65) = 0.28;

varying vec3 v_world_pos;
varying vec3 v_sphere_light_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.12);
	return fract(p.x * p.y);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	// Store pre-wind view position so canopy shadows stay smoothly spherical without flicker
	v_sphere_light_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_pos = w_pos;

	vec2 w_dir = length(wind_direction) > 0.001 ? normalize(wind_direction) : vec2(1.0, 0.35);
	float gust = smooth_noise(w_pos.xz * wind_scale * 0.7 - w_dir * (TIME * wind_speed * 0.85));
	float flutter = sin(TIME * (wind_speed * 2.2 + 1.2) + w_pos.x * 2.1 + w_pos.z * 1.7);

	// Gentle painterly canopy sway + subtle leaf-edge ruffling
	VERTEX.x += (gust - 0.4) * wind_strength * 0.42 + flutter * wind_strength * 0.08;
	VERTEX.z += (gust - 0.4) * wind_strength * 0.24;
	VERTEX.y += flutter * wind_strength * 0.05;
}

void fragment() {
	LIGHT_VERTEX = v_sphere_light_pos;
	// Gouache dabs across the canopy surface
	float dab = smooth_noise(v_world_pos.xz * 2.8 + vec2(v_world_pos.y * 1.9, -v_world_pos.y * 1.4));
	float paper = hash21(floor(v_world_pos.xz * 18.0 + v_world_pos.y * 12.0));
	vec3 col = mix(foliage_color.rgb, highlight_color.rgb, smoothstep(0.38, 0.76, dab));
	col += vec3((paper - 0.5) * 0.06);

	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = ALBEDO * 0.18;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float raw = clamp(ndotl * 0.5 + 0.5, 0.0, 1.0);
	float stepped = floor(raw * cel_steps + 0.35) / cel_steps;
	float lit_factor = clamp(stepped * ATTENUATION, 0.0, 1.0);
	vec3 shaded = mix(shadow_tint.rgb, vec3(1.0, 0.99, 0.94), lit_factor);

	// Soft lit-side painterly Rim Light
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	float rim = smoothstep(0.45, 0.82, fresnel) * smoothstep(0.45, 0.75, lit_factor) * rim_strength;

	DIFFUSE_LIGHT += (ALBEDO * shaded + highlight_color.rgb * rim) * LIGHT_COLOR / PI;
}
