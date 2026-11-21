shader_type spatial;
render_mode blend_mix, diffuse_lambert, cull_disabled;

// Storybook Deep Cobalt Lake & Flowing Stream Shader (06_29_51 calm sapphire lake x vC7OEC shore foam!)
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-24.0, -18.0);
uniform vec2 map_size = vec2(48.0, 36.0);
uniform float water_level = -0.58;

uniform vec4 deep_color : source_color = vec4(0.06, 0.20, 0.48, 0.96);
uniform vec4 shallow_color : source_color = vec4(0.14, 0.38, 0.72, 0.92);
uniform vec4 foam_color : source_color = vec4(0.76, 0.88, 1.0, 0.92);
uniform vec3 bobber_pos = vec3(-1.35, -0.58, 5.85);
uniform vec3 waterfall_pos = vec3(-8.5, -0.58, 5.10);

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
	VERTEX.y += sin(v_world_pos.x * 1.2 + TIME * 1.5) * 0.012 + cos(v_world_pos.z * 1.4 + TIME * 1.2) * 0.012;
}

void fragment() {
	vec2 uv_h = clamp((v_world_pos.xz - map_min) / map_size, vec2(0.0), vec2(1.0));
	float terrain_h = texture(height_tex, uv_h).r * 6.0 - 2.0;
	float depth = water_level - terrain_h;

	float flow_n = vnoise(v_world_pos.xz * 0.85 + vec2(-TIME * 0.18, -TIME * 0.48));
	float wave_n = vnoise(v_world_pos.xz * 2.1 + vec2(TIME * 0.25, -TIME * 0.55));

	// Deep calm sapphire lake transitioning to brighter cerulean in the flowing stream
	float depth_t = smoothstep(0.06, 0.95, depth);
	float is_river = smoothstep(4.6, 6.2, v_world_pos.x) * smoothstep(6.2, 3.8, v_world_pos.z);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth_t * (1.0 - is_river * 0.55));

	// Subtle horizontal hand-painted water strokes on the calm lake (06_29_51 signature!)
	float lake_stroke = vnoise(vec2(v_world_pos.x * 0.45 + TIME * 0.08, v_world_pos.z * 3.8));
	col += vec3(0.05, 0.11, 0.18) * smoothstep(0.62, 0.86, lake_stroke) * (1.0 - is_river);

	// 1. Delicate painterly shoreline rim hugging curved banks
	float shore_wave = sin(depth * 20.0 - TIME * 2.0 + flow_n * 2.8);
	float shore_foam = smoothstep(0.20, 0.02, depth) * 0.72 + smoothstep(0.36, 0.10, depth) * smoothstep(0.72, 0.94, shore_wave) * 0.30;

	// 2. Flowing stream ripples ONLY inside the river channel (NOT cluttering the calm lake!)
	vec2 cell_uv = (v_world_pos.xz + vec2(0.0, -TIME * 0.60)) * 0.58;
	vec2 cid = floor(cell_uv);
	vec2 cf = fract(cell_uv) - 0.5;
	float rnd = hash21(cid);
	float r_phase = fract(TIME * 0.42 + rnd);
	float d_cell = length(cf);
	float stream_ring = smoothstep(0.035, 0.0, abs(d_cell - r_phase * 0.32)) * (1.0 - r_phase) * step(0.58, rnd) * is_river * smoothstep(0.08, 0.30, depth);

	// 3. Concentric ripples around fishing bobber
	float d_bob = length(v_world_pos.xz - bobber_pos.xz);
	float bob_ring = smoothstep(0.04, 0.0, abs(fract(d_bob * 1.15 - TIME * 0.50) - 0.5)) * smoothstep(2.0, 0.15, d_bob) * 0.68;

	// 4. Waterfall splash foam ring
	float d_wf = length(v_world_pos.xz - waterfall_pos.xz);
	float wf_foam = smoothstep(2.1, 0.45, d_wf + (wave_n - 0.5) * 0.8) * 0.85;

	float total_foam = clamp(shore_foam + stream_ring * 0.55 + bob_ring + wf_foam, 0.0, 1.0);
	col = mix(col, foam_color.rgb, total_foam);

	ALBEDO = col;
	ALPHA = clamp(mix(0.88, 0.98, depth_t) + total_foam * 0.12, 0.0, 1.0);
	ROUGHNESS = mix(0.26, 0.88, total_foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.35, 0.04, total_foam);
	EMISSION = col * 0.05 + foam_color.rgb * total_foam * 0.08;
}
