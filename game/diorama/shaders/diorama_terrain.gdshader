shader_type spatial;
render_mode diffuse_lambert;

// Smooth 3D Sculpted Diorama Terrain Shader (Uses Godot Native Ambient + Soft Shadows — ZERO Pitch-Black Crush!)
// Vertex COLOR: R = Sandy Trail, G = Campfire Warm Clearing, B = Wet Shoreline Bank
// Persistent state_map (filter_linear): R = Scorch, G = Snow/Frost, B = Wetness/Footprints
uniform sampler2D state_map : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-22.0, -17.0);
uniform vec2 map_size = vec2(44.0, 34.0);

uniform vec4 grass_deep : source_color = vec4(0.24, 0.40, 0.38, 1.0);
uniform vec4 grass_mid : source_color = vec4(0.32, 0.50, 0.40, 1.0);
uniform vec4 grass_hill : source_color = vec4(0.42, 0.59, 0.40, 1.0);
uniform vec4 trail_col : source_color = vec4(0.86, 0.68, 0.48, 1.0);
uniform vec4 campfire_dirt : source_color = vec4(0.92, 0.68, 0.34, 1.0);
uniform vec4 shore_sand : source_color = vec4(0.32, 0.44, 0.52, 1.0);
uniform vec4 cliff_rock : source_color = vec4(0.34, 0.40, 0.56, 1.0);
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

	float n1 = vnoise(v_world_pos.xz * 0.28);
	float n2 = vnoise(v_world_pos.xz * 1.15);
	float grain = vnoise(v_world_pos.xz * 4.5);

	// Luminous velvety storybook meadow (06_29_51 sage-teal night / vC7OEC emerald day)
	float hill_t = clamp((v_world_pos.y + 0.05) * 0.52, 0.0, 1.0);
	vec3 g_col = mix(grass_deep.rgb, grass_mid.rgb, smoothstep(0.20, 0.80, n1));
	g_col = mix(g_col, grass_hill.rgb, hill_t * 0.62);

	// Soft rocky bank on steep slopes
	float slope = 1.0 - clamp(v_world_nrm.y, 0.0, 1.0);
	g_col = mix(g_col, cliff_rock.rgb, smoothstep(0.18, 0.45, slope));

	// Smooth organic blending for shoreline, sandy trail & golden campfire pool
	vec3 col = mix(g_col, shore_sand.rgb, smoothstep(0.18, 0.85, shore_w));
	col = mix(col, trail_col.rgb, smoothstep(0.20, 0.72, trail_w + (n2 - 0.5) * 0.14));
	col = mix(col, campfire_dirt.rgb, smoothstep(0.12, 0.82, fire_w + (n1 - 0.5) * 0.12) * 0.90);

	// Subtle gouache paper texture
	col += vec3((grain - 0.5) * 0.038);

	// Smooth Bilinear Persistent Surface State (R=Scorch, G=Snow/Frost, B=Wetness/Footprints)
	vec2 uv_s = clamp((v_world_pos.xz - map_min) / map_size, vec2(0.0), vec2(1.0));
	vec4 st = texture(state_map, uv_s);
	float scorch = st.r;
	float snow = st.g;
	float wet = st.b;

	float wet_m = smoothstep(0.06, 0.55, wet);
	col = mix(col, col * vec3(0.68, 0.78, 0.94), wet_m * 0.58);

	float snow_m = smoothstep(0.14, 0.60, snow + (n2 - 0.5) * 0.12) * smoothstep(0.38, 0.10, slope);
	vec3 snow_c = mix(vec3(0.80, 0.88, 0.98), vec3(0.95, 0.98, 1.0), n2 * 0.5 + 0.3);
	col = mix(col, snow_c, snow_m * 0.90);

	float scorch_m = smoothstep(0.18, 0.74, scorch + (n2 - 0.5) * 0.10);
	vec3 char_c = vec3(0.24, 0.18, 0.19);
	col = mix(col, char_c, scorch_m * 0.68);
	float ember = smoothstep(0.18, 0.36, scorch) * smoothstep(0.62, 0.32, scorch);

	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = mix(0.94, 0.28, wet_m);
	METALLIC = 0.0;
	SPECULAR = mix(0.04, 0.50, wet_m);
	// Gentle luminous gouache lift so night grass stays rich & readable like 06_29_51.png!
	EMISSION = col * mix(0.10, 0.22, night_mix) + vec3(0.95, 0.48, 0.16) * ember * 0.35 + vec3(0.95, 0.62, 0.20) * fire_w * 0.14 * night_mix;
}
