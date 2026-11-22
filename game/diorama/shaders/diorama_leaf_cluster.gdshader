shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_lambert;

#include "res://diorama/shaders/diorama_wind_field.gdshaderinc"
#include "res://diorama/shaders/diorama_canopy_cover.gdshaderinc"

uniform vec4 tint_color : source_color = vec4(1.0);
uniform float night_mix = 0.0;
varying vec3 rest_normal;
varying vec3 leaf_world;
varying float face_phase;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec3 up = MAIN_CAM_INV_VIEW_MATRIX[1].xyz;
	vec3 right = MAIN_CAM_INV_VIEW_MATRIX[0].xyz;
	vec2 tilt = diorama_bend(anchor.xz, TIME);
	anchor.xz += tilt * 0.081;
	face_phase = INSTANCE_CUSTOM.w * 6.283185;
	float gust = diorama_gust(anchor.xz, TIME);
	float roll = face_phase + gust * 0.54 + sin(TIME * 2.8 + face_phase) * 0.074;
	float c = cos(roll);
	float s = sin(roll);
	vec2 corner = (UV - vec2(0.5)) * length(MODEL_MATRIX[0].xyz);
	corner = mat2(vec2(c, s), vec2(-s, c)) * corner;
	VERTEX = anchor + right * corner.x + up * corner.y;
	leaf_world = VERTEX;
	rest_normal = normalize(INSTANCE_CUSTOM.xyz * 2.0 - 1.0);
}

float leaf_silhouette(vec2 p) {
	float middle = length(p * vec2(1.02, 0.91)) - 0.29;
	float left = length((p - vec2(-0.18, 0.03)) * vec2(1.13, 1.0)) - 0.22;
	float right = length((p - vec2(0.18, 0.10)) * vec2(0.99, 1.07)) - 0.19;
	float top = length((p - vec2(-0.04, -0.21)) * vec2(1.05, 1.0)) - 0.18;
	return min(min(middle, left), min(right, top));
}

void fragment() {
	if (leaf_silhouette(UV - vec2(0.5)) > 0.0 || canopy_blocks_player(leaf_world, FRAGCOORD.xy)) {
		discard;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(rest_normal, 0.0)).xyz);
	float crown_light = smoothstep(-0.18, 0.89, dot(rest_normal, normalize(vec3(-0.42, 0.83, 0.36))));
	vec3 hue = mix(vec3(0.50, 0.68, 0.73), vec3(1.09, 1.06, 0.86), crown_light);
	float variation = mix(0.91, 1.03, (sin(face_phase) + 1.0) * 0.5);
	float lobe_tone = mix(0.90, 1.025, smoothstep(-0.35, 0.33, -UV.y + 0.5 - (UV.x - 0.5) * 0.45));
	ALBEDO = COLOR.rgb * tint_color.rgb * hue * variation * lobe_tone;
	ROUGHNESS = 0.9;
	SPECULAR = 0.09;
	EMISSION = COLOR.rgb * crown_light * (1.0 - night_mix) * 0.035;
}
