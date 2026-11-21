shader_type spatial;
render_mode blend_mix, diffuse_lambert, cull_disabled;

// Muted Painterly Diorama Water (ZERO Neon Emission — Soft Slate-Blue Night & Clean Azure Day!)
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-24.0, -18.0);
uniform vec2 map_size = vec2(48.0, 36.0);
uniform float water_level = -0.58;

uniform vec4 deep_color : source_color = vec4(0.11, 0.21, 0.33, 0.96);
uniform vec4 shallow_color : source_color = vec4(0.17, 0.31, 0.43, 0.92);
uniform vec4 foam_color : source_color = vec4(0.42, 0.55, 0.68, 0.85);
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
	VERTEX.y += sin(v_world_pos.x * 1.2 + TIME * 1.5) * 0.010 + cos(v_world_pos.z * 1.4 + TIME * 1.2) * 0.010;
}

void fragment() {
	vec2 uv_h = clamp((v_world_pos.xz - map_min) / map_size, vec2(0.0), vec2(1.0));
	float terrain_h = texture(height_tex, uv_h).r * 6.0 - 2.0;
	float depth = water_level - terrain_h;

	float flow_n = vnoise(v_world_pos.xz * 0.85 + vec2(-TIME * 0.18, -TIME * 0.48));
	float wave_n = vnoise(v_world_pos.xz * 2.1 + vec2(TIME * 0.25, -TIME * 0.55));

	float depth_t = smoothstep(0.06, 0.95, depth);
	float is_river = smoothstep(4.6, 6.2, v_world_pos.x) * smoothstep(6.2, 3.8, v_world_pos.z);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth_t * (1.0 - is_river * 0.50));

	// Subtle hand-painted horizontal strokes on calm lake
	float lake_stroke = vnoise(vec2(v_world_pos.x * 0.45 + TIME * 0.08, v_world_pos.z * 3.8));
	col += vec3(0.03, 0.06, 0.09) * smoothstep(0.64, 0.88, lake_stroke) * (1.0 - is_river);

	// 1. Soft non-emissive shoreline foam hugging curved banks (NO neon glow!)
	float shore_wave = sin(depth * 18.0 - TIME * 1.8 + flow_n * 2.5);
	float shore_foam = smoothstep(0.18, 0.02, depth) * 0.58 + smoothstep(0.32, 0.10, depth) * smoothstep(0.75, 0.95, shore_wave) * 0.22;

	// 2. River-only concentric ripples
	vec2 cell_uv = (v_world_pos.xz + vec2(0.0, -TIME * 0.58)) * 0.58;
	vec2 cid = floor(cell_uv);
	vec2 cf = fract(cell_uv) - 0.5;
	float rnd = hash21(cid);
	float r_phase = fract(TIME * 0.40 + rnd);
	float d_cell = length(cf);
	float stream_ring = smoothstep(0.035, 0.0, abs(d_cell - r_phase * 0.32)) * (1.0 - r_phase) * step(0.60, rnd) * is_river * smoothstep(0.08, 0.30, depth);

	// 3. Fishing bobber ripples
	float d_bob = length(v_world_pos.xz - bobber_pos.xz);
	float bob_ring = smoothstep(0.04, 0.0, abs(fract(d_bob * 1.15 - TIME * 0.48) - 0.5)) * smoothstep(1.9, 0.15, d_bob) * 0.55;

	// 4. Waterfall splash foam ring
	float d_wf = length(v_world_pos.xz - waterfall_pos.xz);
	float wf_foam = smoothstep(1.9, 0.40, d_wf + (wave_n - 0.5) * 0.7) * 0.65;

	float total_foam = clamp(shore_foam + stream_ring * 0.48 + bob_ring + wf_foam, 0.0, 1.0);
	col = mix(col, foam_color.rgb, total_foam);

	ALBEDO = col;
	ALPHA = clamp(mix(0.88, 0.97, depth_t) + total_foam * 0.10, 0.0, 1.0);
	ROUGHNESS = mix(0.45, 0.95, total_foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.18, 0.02, total_foam);
	// ZERO EMISSION — foam & water respond naturally to ambient & scene lighting!
	EMISSION = vec3(0.0);
}
