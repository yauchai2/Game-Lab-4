shader_type spatial;
render_mode diffuse_lambert;

// Velvety Gouache 3D Diorama Terrain Shader (06_29_51 Cozy Night Meadow x vC7OEC Sunlit Miniature)
// Vertex COLOR: R = Sandy Trail, G = Campfire Warm Clearing, B = Wet Shoreline Bank
// Persistent state_map (filter_linear): R = Scorch, G = Snow/Frost, B = Wetness/Footprints
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
	float n2 = vnoise(v_world_pos.xz * 1.10);
	float brush = vnoise(vec2(v_world_pos.x * 5.2, v_world_pos.z * 2.1));
	float fine_grain = vnoise(v_world_pos.xz * 8.5);

	// Rich mossy-olive meadow with warm hilltops & deep twilight hollows
	float hill_t = clamp((v_world_pos.y + 0.05) * 0.50, 0.0, 1.0);
	vec3 g_col = mix(grass_deep.rgb, grass_mid.rgb, smoothstep(0.18, 0.82, n1));
	g_col = mix(g_col, grass_hill.rgb, hill_t * 0.68);

	// Mossy cliff bank on steep slopes
	float slope = 1.0 - clamp(v_world_nrm.y, 0.0, 1.0);
	g_col = mix(g_col, cliff_rock.rgb, smoothstep(0.20, 0.48, slope));

	// Organic shoreline, warm sandy path & wide golden-honey campfire clearing
	vec3 col = mix(g_col, shore_sand.rgb, smoothstep(0.22, 0.88, shore_w));
	col = mix(col, trail_col.rgb, smoothstep(0.20, 0.72, trail_w + (n2 - 0.5) * 0.14));
	float fire_pool = smoothstep(0.04, 0.80, fire_w + (n1 - 0.5) * 0.14);
	col = mix(col, campfire_dirt.rgb, fire_pool * 0.90);

	// Soft golden hearth heart right under campfire (smooth radial falloff — NO hard circle!)
	float d_hearth = length(v_world_pos.xz - vec2(0.0, 0.2));
	float hearth_glow = smoothstep(1.85, 0.25, d_hearth);
	col = mix(col, vec3(1.0, 0.82, 0.34), hearth_glow * 0.65 * night_mix);

	// Subtle gouache paper & dry-brush texture
	col *= 1.0 + (brush - 0.5) * 0.11 + (fine_grain - 0.5) * 0.05;

	// Smooth Bilinear Persistent Surface State (R=Scorch, G=Snow/Frost, B=Wetness/Footprints)
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

	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = mix(0.95, 0.38, wet_m);
	METALLIC = 0.0;
	SPECULAR = mix(0.03, 0.25, wet_m);
	// Luminous cozy night meadow floor + warm hearth bounce (zero daytime bleach!)
	EMISSION = col * mix(0.02, 0.13, night_mix)
		+ vec3(0.98, 0.56, 0.16) * fire_pool * 0.24 * night_mix
		+ vec3(1.0, 0.76, 0.28) * hearth_glow * 0.32 * night_mix
		+ vec3(0.95, 0.45, 0.14) * ember * 0.38;
}
