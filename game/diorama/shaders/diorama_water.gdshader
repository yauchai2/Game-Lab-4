shader_type spatial;
render_mode blend_mix, diffuse_lambert, cull_disabled;

// vC7OEC-inspired Living Diorama Water with Automatic Shoreline Foam & Expanding Ripple Rings!
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-22.0, -17.0);
uniform vec2 map_size = vec2(44.0, 34.0);
uniform float water_level = -0.58;

uniform vec4 deep_color : source_color = vec4(0.09, 0.27, 0.58, 0.94);
uniform vec4 shallow_color : source_color = vec4(0.18, 0.49, 0.86, 0.88);
uniform vec4 foam_color : source_color = vec4(0.84, 0.94, 1.0, 0.95);
uniform vec3 bobber_pos = vec3(-1.3, -0.58, 5.9);
uniform vec3 waterfall_pos = vec3(-8.8, -0.58, 5.2);

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
	VERTEX.y += sin(v_world_pos.x * 1.4 + TIME * 1.8) * 0.015 + cos(v_world_pos.z * 1.6 + TIME * 1.4) * 0.015;
}

void fragment() {
	vec2 uv_h = clamp((v_world_pos.xz - map_min) / map_size, vec2(0.0), vec2(1.0));
	// height_tex stores normalized terrain height in R: real_h = r * 6.0 - 2.0
	float terrain_h = texture(height_tex, uv_h).r * 6.0 - 2.0;
	float depth = water_level - terrain_h;

	float flow_n = vnoise(v_world_pos.xz * 0.95 + vec2(-TIME * 0.25, -TIME * 0.55));
	float wave_n = vnoise(v_world_pos.xz * 2.2 + vec2(TIME * 0.35, -TIME * 0.65));

	// Depth gradient: bright cerulean in river & shallows, deep sapphire in lake center
	float depth_t = smoothstep(0.05, 0.95, depth);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth_t);
	col += vec3(0.06, 0.12, 0.18) * smoothstep(0.55, 0.85, flow_n);

	// 1. Automatic animated shoreline foam hugging EVERY curved bank (vC7OEC signature!)
	float shore_wave = sin(depth * 22.0 - TIME * 2.4 + flow_n * 3.0);
	float shore_foam = smoothstep(0.26, 0.02, depth) * 0.85 + smoothstep(0.45, 0.12, depth) * smoothstep(0.65, 0.92, shore_wave) * 0.45;

	// 2. Stylized circular water ripples drifting along stream + pulsing around bobber & waterfall
	vec2 cell_uv = (v_world_pos.xz + vec2(0.0, -TIME * 0.65)) * 0.52;
	vec2 cid = floor(cell_uv);
	vec2 cf = fract(cell_uv) - 0.5;
	float rnd = hash21(cid);
	float r_phase = fract(TIME * 0.42 + rnd);
	float d_cell = length(cf);
	float stream_ring = smoothstep(0.04, 0.0, abs(d_cell - r_phase * 0.36)) * (1.0 - r_phase) * step(0.52, rnd) * smoothstep(0.08, 0.35, depth);

	float d_bob = length(v_world_pos.xz - bobber_pos.xz);
	float bob_ring = smoothstep(0.05, 0.0, abs(fract(d_bob * 0.95 - TIME * 0.55) - 0.5)) * smoothstep(2.4, 0.2, d_bob) * 0.75;

	float d_wf = length(v_world_pos.xz - waterfall_pos.xz);
	float wf_foam = smoothstep(2.4, 0.5, d_wf + (wave_n - 0.5) * 0.9) * 0.92;

	float total_foam = clamp(shore_foam + stream_ring * 0.55 + bob_ring + wf_foam, 0.0, 1.0);
	col = mix(col, foam_color.rgb, total_foam);

	ALBEDO = col;
	ALPHA = clamp(mix(0.84, 0.96, depth_t) + total_foam * 0.15, 0.0, 1.0);
	ROUGHNESS = mix(0.22, 0.85, total_foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.55, 0.05, total_foam);
	EMISSION = col * 0.14 + foam_color.rgb * total_foam * 0.18;
}
