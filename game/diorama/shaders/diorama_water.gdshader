shader_type spatial;

#include "res://diorama/shaders/diorama_sun_pools.gdshaderinc"
render_mode blend_mix, diffuse_lambert, cull_disabled;

// Muted Painterly Diorama Water (ZERO Neon Emission — Soft Slate-Blue Night & Clean Azure Day!)
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-24.0, -18.0);
uniform vec2 map_size = vec2(48.0, 36.0);
uniform float water_level = -0.58;

uniform vec4 deep_color : source_color = vec4(0.11, 0.21, 0.33, 0.96);
uniform vec4 shallow_color : source_color = vec4(0.17, 0.31, 0.43, 0.92);
uniform vec4 foam_color : source_color = vec4(0.42, 0.55, 0.68, 0.85);
uniform vec3 bobber_pos = vec3(-1.35, -0.58, 5.85);
uniform vec3 waterfall_pos = vec3(-8.5, -0.58, 5.10);

uniform vec2 channel_stones[4];
uniform float daylight = 0.0;
uniform float rain_amount = 0.0;

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
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(v_world_pos.x * 1.2 + TIME * 1.5) * 0.010 + cos(v_world_pos.z * 1.4 + TIME * 1.2) * 0.010;
}

void fragment() {
	vec2 uv_h = clamp((v_world_pos.xz - map_min) / map_size, vec2(0.0), vec2(1.0));
	float terrain_h = texture(height_tex, uv_h).r * 6.0 - 2.0;
	float bed_depth = water_level - terrain_h;
	float raw_depth = texture(scene_depth, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ndc.z = raw_depth * 2.0 - 1.0;
	#endif
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 scene_world = (INV_VIEW_MATRIX * vec4(scene_view.xyz / scene_view.w, 1.0)).xyz;
	// Terrain defines the overall color ramp. Opaque objects add local shallows.
	float contact_depth = max(0.0, water_level - scene_world.y);
	float depth = min(bed_depth, contact_depth + 0.07);

	float flow_n = vnoise(v_world_pos.xz * 0.85 + vec2(-TIME * 0.18, -TIME * 0.48));
	float wave_n = vnoise(v_world_pos.xz * 2.1 + vec2(TIME * 0.25, -TIME * 0.55));

	float depth_t = smoothstep(0.06, 0.95, depth);
	float is_river = smoothstep(4.6, 6.2, v_world_pos.x) * smoothstep(6.2, 3.8, v_world_pos.z);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth_t * (1.0 - is_river * 0.36));
	vec2 surface_wave = vec2(
		sin(dot(v_world_pos.xz, vec2(1.12, 0.54)) + TIME * 1.02),
		cos(dot(v_world_pos.xz, vec2(-0.58, 1.31)) - TIME * 0.77)
	);
	vec3 surface_normal = normalize(vec3(surface_wave.x * 0.036, 1.0, surface_wave.y * 0.044));
	NORMAL = normalize((VIEW_MATRIX * vec4(surface_normal, 0.0)).xyz);

	// Subtle hand-painted horizontal strokes on calm lake
	float lake_stroke = vnoise(vec2(v_world_pos.x * 0.45 + TIME * 0.08, v_world_pos.z * 3.8));
	col += vec3(0.03, 0.06, 0.09) * smoothstep(0.64, 0.88, lake_stroke) * (1.0 - is_river);

	// Convert shallow vertical depth into an approximate horizontal shore distance.
	float shore_foam = 0.0;
	if (bed_depth < 0.62) {
		vec2 step_uv = 1.0 / vec2(textureSize(height_tex, 0));
		float east = texture(height_tex, uv_h + vec2(step_uv.x, 0.0)).r;
		float west = texture(height_tex, uv_h - vec2(step_uv.x, 0.0)).r;
		float south = texture(height_tex, uv_h + vec2(0.0, step_uv.y)).r;
		float north = texture(height_tex, uv_h - vec2(0.0, step_uv.y)).r;
		vec2 slope = 3.0 * vec2(east - west, south - north) / (step_uv * map_size);
		float shore_distance = max(0.0, bed_depth) / max(0.26, length(slope));
		float drift = sin(TIME * 1.35 + flow_n * 4.0) * 0.025;
		float lip = 1.0 - smoothstep(0.018, 0.095, shore_distance);
		float broken_line = (1.0 - smoothstep(0.026, 0.115, abs(shore_distance - 0.22 - drift)))
			* smoothstep(0.37, 0.72, wave_n);
		shore_foam = lip * 0.57 + broken_line * 0.31;
	}

	// 2. River-only concentric ripples
	vec2 cell_uv = (v_world_pos.xz + vec2(0.0, -TIME * 0.58)) * 0.58;
	vec2 cid = floor(cell_uv);
	vec2 cf = fract(cell_uv) - 0.5 - (vec2(hash21(cid + 3.7), hash21(cid + 8.1)) - 0.5) * 0.18;
	float rnd = hash21(cid);
	float r_phase = fract(TIME * 0.40 + rnd);
	float d_cell = length(cf);
	float stream_ring = smoothstep(0.035, 0.0, abs(d_cell - r_phase * 0.32)) * (1.0 - r_phase) * step(0.60, rnd) * is_river * smoothstep(0.08, 0.30, depth);

	// 3. Fishing bobber ripples
	float d_bob = length(v_world_pos.xz - bobber_pos.xz);
	float bob_ring = smoothstep(0.04, 0.0, abs(fract(d_bob * 1.15 - TIME * 0.48) - 0.5)) * smoothstep(1.9, 0.15, d_bob) * 0.55;

	// 4. Waterfall splash foam ring
	float d_wf = length(v_world_pos.xz - waterfall_pos.xz);
	float impact_white = 1.0 - smoothstep(0.22, 1.16, d_wf + (wave_n - 0.5) * 0.38);
	float outgoing = sin(d_wf * 21.0 - TIME * 6.3 + flow_n * 1.6);
	float spread = smoothstep(0.66, 0.94, outgoing) * (1.0 - smoothstep(0.50, 1.88, d_wf));
	float wf_foam = impact_white * 0.59 + spread * 0.18;

	// Arc ends break up in the current; the lake catches smaller rings near its banks.
	float wake = stream_ring + (1.0 - is_river) * smoothstep(0.065, 0.012, abs(d_cell - r_phase * 0.32))
		* sin(PI * r_phase) * step(0.83, rnd) * smoothstep(0.08, 0.35, depth);
	col *= mix(0.78, 1.10, flow_n);
	float object_foam = (1.0 - smoothstep(0.04, 0.23, contact_depth))
		* smoothstep(0.21, 0.52, bed_depth) * smoothstep(0.23, 0.66, wave_n) * 0.68;
	float total_foam = clamp(shore_foam + object_foam + wake * smoothstep(0.20, 0.66, wave_n) * 0.47 + bob_ring + wf_foam, 0.0, 1.0);
	for (int i = 0; i < 4; i++) {
		vec2 offset = v_world_pos.xz - channel_stones[i];
		float radius = length(offset * vec2(1.0, 0.86));
		float phase = fract(TIME * 0.54 + float(i) * 0.37);
		float ring = 1.0 - smoothstep(0.018,0.052,abs(radius - (0.34 + phase * 0.70)));
		float arc = smoothstep(-0.65,0.4,offset.x + 0.27 * sin(radius * 3.0 + phase * 4.0));
		total_foam = max(total_foam, ring * arc * sin(PI * phase) * 0.85);
	}
	if (rain_amount > 0.015) {
		vec2 rain_grid = v_world_pos.xz * 1.13;
		vec2 tile = floor(rain_grid);
		float clock = TIME * 1.68 + hash21(tile);
		float age = fract(clock);
		vec2 seed = tile + floor(clock) * vec2(9.7, 4.2);
		vec2 point = mix(vec2(0.22), vec2(0.78), vec2(hash21(seed + 1.0), hash21(seed + 5.0)));
		float gap = abs(length(fract(rain_grid) - point) - (0.026 + age * 0.20));
		float drop = (1.0 - smoothstep(0.012, 0.038, gap)) * sin(age * PI) * (1.0 - age);
		total_foam = max(total_foam, drop * rain_amount * 0.48);
	}
	col = mix(col, foam_color.rgb, total_foam);

	float sunlight = sun_pools(v_world_pos.xz) * daylight;
	float glint = smoothstep(0.32, 0.82, wave_n * 0.45 + lake_stroke * 0.55);
	vec2 reflection_grid = v_world_pos.xz * 0.54;
	vec2 reflection_cell = floor(reflection_grid);
	float random_glint = hash21(reflection_cell + 10.3);
	float phase = fract(TIME * 0.29 + random_glint);
	vec2 center = fract(reflection_grid) - vec2(0.42 + phase * 0.16, 0.5);
	float diamond = abs(center.x) * 0.71 + abs(center.y) * 1.75;
	float reflection = (1.0 - smoothstep(0.008, 0.034, diamond))
		* pow(sin(PI * phase), 4.0) * step(0.86, random_glint) * daylight * depth_t * (1.0 - 0.85 * rain_amount);
	vec3 lit_water = mix(col, vec3(0.59, 0.72, 0.73), sunlight * (0.10 + 0.22 * glint));
	ALBEDO = mix(lit_water, vec3(0.78, 0.85, 0.80), reflection * 0.61);
	float visibility = 1.0 - abs(dot(NORMAL, normalize(VIEW)));
	ALPHA = clamp(mix(0.68, 0.96, depth_t) + visibility * 0.04 + total_foam * 0.22, 0.0, 1.0);
	ROUGHNESS = mix(0.45, 0.95, total_foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.18, 0.02, total_foam);
	// ZERO EMISSION — foam & water respond naturally to ambient & scene lighting!
	EMISSION = vec3(0.0);
}
