shader_type spatial;
render_mode diffuse_lambert;

// Velvety Gouache Diorama Prop Shader (Spherical Normal Transfer + Vertex Wind Sway + Dry-Brush Grain + Vertical Gradient!)
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool has_albedo_tex = true;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_mix : hint_range(0.0, 0.92) = 0.0;
uniform float brightness : hint_range(0.4, 1.8) = 1.00;
uniform float saturation : hint_range(0.4, 1.6) = 1.14;
uniform float ambient_lift : hint_range(0.0, 0.25) = 0.09;
uniform float grad_strength : hint_range(0.0, 0.75) = 0.44;
uniform float min_y = -0.5;
uniform float max_y = 0.5;
uniform vec3 aabb_center = vec3(0.0, 0.0, 0.0);
uniform float spherical_normal_mix : hint_range(0.0, 1.0) = 0.0;
uniform float wind_strength : hint_range(0.0, 0.35) = 0.0;

varying float v_norm_y;
varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.12);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
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
	v_norm_y = clamp((VERTEX.y - min_y) / max(0.001, max_y - min_y), 0.0, 1.0);

	// 1. Procedural Spherical Normal Transfer (vC7OEC Fluffy Cloud-Crown Technique!)
	if (spherical_normal_mix > 0.001) {
		vec3 sph_n = normalize(VERTEX - aabb_center + vec3(0.0, 0.15, 0.0));
		NORMAL = normalize(mix(NORMAL, sph_n, spherical_normal_mix));
	}

	// 2. World-Space Vertex Wind Sway (gentle breathing foliage anchored at root)
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wind_strength > 0.001) {
		float w_mask = v_norm_y * v_norm_y;
		float sway_x = sin(TIME * 1.65 + wp.x * 0.45 + wp.z * 0.35) * wind_strength * w_mask;
		float sway_z = cos(TIME * 1.30 + wp.z * 0.50) * wind_strength * 0.55 * w_mask;
		VERTEX.x += sway_x;
		VERTEX.z += sway_z;
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 tex_c = has_albedo_tex ? texture(albedo_tex, UV).rgb : vec3(1.0);
	vec3 col = tex_c * base_color.rgb * brightness;

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	// Rich gouache tinting that preserves deep crevices
	vec3 tinted = tint_color.rgb * clamp(luma * 1.32 + 0.15, 0.24, 1.18);
	col = mix(col, tinted, tint_mix);

	// Painterly dry-brush vertical strokes
	float brush = vnoise(vec2((v_world_pos.x + v_world_pos.z) * 6.5, v_world_pos.y * 2.8));
	float speckle = vnoise(vec2(v_world_pos.x * 14.0 - v_world_pos.z * 11.0, v_world_pos.y * 9.0));
	col *= 1.0 + (brush - 0.5) * 0.13 + (speckle - 0.5) * 0.05;

	// vC7OEC x 06_29_51 signature: Grounded base AO -> luminous painted crown!
	float g_t = smoothstep(0.04, 0.92, v_norm_y);
	float grad = mix(1.0 - grad_strength * 0.80, 1.0 + grad_strength * 0.40, g_t);
	vec3 base_cool = mix(vec3(0.80, 0.84, 0.96), vec3(1.0), g_t);
	col *= grad * base_cool;

	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	SPECULAR = 0.03;
	EMISSION = col * ambient_lift;
}
