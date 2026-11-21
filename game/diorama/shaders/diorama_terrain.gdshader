shader_type spatial;

#include "res://diorama/shaders/diorama_sun_pools.gdshaderinc"
render_mode diffuse_lambert;

// Matte Gouache 3D Diorama Terrain Shader (ZERO Plastic Specular + Smooth Hearth Glow + Persistent State!)
uniform sampler2D state_map : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-24.0, -18.0);
uniform vec2 map_size = vec2(48.0, 36.0);

uniform vec4 grass_deep : source_color = vec4(0.16, 0.27, 0.25, 1.0);
uniform vec4 grass_mid : source_color = vec4(0.27, 0.41, 0.27, 1.0);
uniform vec4 grass_hill : source_color = vec4(0.39, 0.51, 0.28, 1.0);
uniform vec4 trail_col : source_color = vec4(0.84, 0.63, 0.42, 1.0);
uniform vec4 campfire_dirt : source_color = vec4(0.95, 0.65, 0.24, 1.0);
uniform vec4 shore_sand : source_color = vec4(0.24, 0.34, 0.45, 1.0);
uniform vec4 cliff_rock : source_color = vec4(0.26, 0.31, 0.46, 1.0);
uniform float night_mix : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

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
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float trail_w = COLOR.r;
	float fire_w = COLOR.g;
	float shore_w = COLOR.b;

	float n1 = vnoise(v_world_pos.xz * 0.25);
	float n2 = vnoise(v_world_pos.xz * 1.15);
	float brush = vnoise(vec2(v_world_pos.x * 5.8, v_world_pos.z * 2.4));
	float fine_grain = vnoise(v_world_pos.xz * 10.0);

	float hill_t = clamp((v_world_pos.y + 0.05) * 0.50, 0.0, 1.0);
	vec3 g_col = mix(grass_deep.rgb, grass_mid.rgb, smoothstep(0.18, 0.82, n1));
	g_col = mix(g_col, grass_hill.rgb, hill_t * 0.68);

	float slope = 1.0 - clamp(v_world_nrm.y, 0.0, 1.0);
	g_col = mix(g_col, cliff_rock.rgb, smoothstep(0.20, 0.48, slope));

	float bank_edge = shore_w + (n2 - 0.5) * 0.24;
	vec3 col = mix(g_col, shore_sand.rgb, smoothstep(0.19, 0.92, bank_edge));
	float stone_band = smoothstep(0.35, 0.76, slope) * smoothstep(0.58, 0.78, n2);
	col = mix(col, cliff_rock.rgb * vec3(1.05, 0.94, 0.91), stone_band * 0.53);
	float trail_mask = smoothstep(0.20, 0.72, trail_w + (n2 - 0.5) * 0.23);
	vec3 packed_earth = trail_col.rgb * mix(vec3(0.79, 0.78, 0.82), vec3(1.06, 1.01, 0.92), n2);
	col = mix(col, packed_earth, trail_mask);
	float fire_pool = smoothstep(0.04, 0.80, fire_w + (n1 - 0.5) * 0.14);
	float packed_circle = smoothstep(0.28, 0.95, fire_pool);
	float dirt_cover = mix(packed_circle * 0.82, fire_pool * 0.90, night_mix);
	col = mix(col, campfire_dirt.rgb, dirt_cover);

	float d_hearth = length(v_world_pos.xz - vec2(0.0, 0.2));
	float hearth_glow = smoothstep(1.85, 0.25, d_hearth);
	col = mix(col, vec3(1.0, 0.82, 0.34), hearth_glow * 0.65 * night_mix);

	// Rich matte gouache grain
	col *= 1.0 + (brush - 0.5) * 0.12 + (fine_grain - 0.5) * 0.06;

	// Broad patches of sunlight move slowly across the clearing.
	float clearing_light = smoothstep(0.28, 0.72, vnoise(v_world_pos.xz * 0.29 + vec2(TIME * 0.018, 0.0)));
	col *= mix(vec3(1.0), mix(vec3(0.70, 0.78, 0.81), vec3(1.16, 1.09, 0.92), clearing_light), 1.0 - night_mix);

	// Persistent Surface State (R=Scorch, G=Snow/Frost, B=Wetness/Footprints)
	vec2 uv_s = clamp((v_world_pos.xz - map_min) / map_size, vec2(0.0), vec2(1.0));
	vec4 st = texture(state_map, uv_s);
	float scorch = st.r;
	float snow = st.g;
	float wet = st.b;

	float wet_m = smoothstep(0.08, 0.58, wet);
	col = mix(col, col * vec3(0.62, 0.72, 0.88), wet_m * 0.50);

	float snow_m = smoothstep(0.16, 0.62, snow + (n2 - 0.5) * 0.12) * smoothstep(0.38, 0.10, slope);
	vec3 snow_c = mix(vec3(0.74, 0.82, 0.96), vec3(0.92, 0.96, 1.0), n2 * 0.5 + 0.3);
	col = mix(col, snow_c, snow_m * 0.88);

	float scorch_m = smoothstep(0.18, 0.74, scorch + (n2 - 0.5) * 0.10);
	vec3 char_c = vec3(0.16, 0.11, 0.12);
	col = mix(col, char_c, scorch_m * 0.72);
	float ember = smoothstep(0.18, 0.36, scorch) * smoothstep(0.62, 0.32, scorch);

	col *= mix(vec3(1.0), vec3(1.20, 1.12, 0.86), sun_pools(v_world_pos.xz) * (1.0 - night_mix));
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = mix(1.0, 0.42, wet_m);
	METALLIC = 0.0;
	SPECULAR = mix(0.0, 0.22, wet_m);
	EMISSION = col * mix(0.02, 0.13, night_mix)
		+ vec3(0.98, 0.56, 0.16) * fire_pool * 0.24 * night_mix
		+ vec3(1.0, 0.76, 0.28) * hearth_glow * 0.32 * night_mix
		+ vec3(0.95, 0.45, 0.14) * ember * 0.38;
}
