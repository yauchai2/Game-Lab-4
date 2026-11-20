shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Stylized Y-Billboard Wind Grass (unified LIGHT_VERTEX shading + non-thinning wind waves)
global uniform vec2 wind_direction;
global uniform float wind_speed;
global uniform float wind_strength;
global uniform float wind_scale;

uniform vec4 base_color : source_color = vec4(0.45, 0.68, 0.30, 1.0);
uniform vec4 tip_color : source_color = vec4(0.74, 0.88, 0.44, 1.0);
uniform vec4 flower_color : source_color = vec4(1.0, 0.62, 0.74, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.32, 0.36, 0.56, 1.0);
uniform float cel_steps : hint_range(2.0, 5.0) = 3.0;
uniform float sway_multiplier : hint_range(0.2, 2.5) = 1.0;

varying vec3 v_node_pos_view;
varying float v_tip_factor;
varying float v_flower_flag;
varying float v_seed;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.12);
	return fract(p.x * p.y);
}

float wave_noise(vec2 p) {
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
	// Per-instance world center (works for MultiMeshInstance3D & MeshInstance3D)
	vec3 inst_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_seed = hash21(inst_world.xz * 0.73);
	v_flower_flag = INSTANCE_CUSTOM.r;

	// Unified lighting anchor in View space (prevents jagged half-lit grass blades!)
	v_node_pos_view = (VIEW_MATRIX * vec4(inst_world, 1.0)).xyz;

	// Y-Axis Billboard (Keep Scale) so grass faces camera smoothly without thinning
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float sz = length(MODEL_MATRIX[2].xyz);
	vec3 cam_right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 up_vec = vec3(0.0, 1.0, 0.0);
	vec3 cam_fwd = normalize(cross(cam_right, up_vec));

	mat4 y_billboard = mat4(
		vec4(cam_right * sx, 0.0),
		vec4(up_vec * sy, 0.0),
		vec4(cam_fwd * sz, 0.0),
		MODEL_MATRIX[3]
	);

	// Global rolling wind field sampled in world XZ, swaying along local X with roots locked (1.0 - UV.y)
	float root_lock = clamp(1.0 - UV.y, 0.0, 1.0);
	v_tip_factor = root_lock;

	vec2 w_dir = length(wind_direction) > 0.001 ? normalize(wind_direction) : vec2(1.0, 0.35);
	vec2 wind_uv = inst_world.xz * wind_scale - w_dir * (TIME * wind_speed);
	float gust = wave_noise(wind_uv) * 2.0 - 0.65;
	float micro = sin(TIME * (wind_speed * 2.4 + 1.5) + v_seed * 6.2831) * 0.28;
	float bend = (gust + micro) * wind_strength * sway_multiplier * (root_lock * root_lock);

	vec3 v_local = VERTEX;
	v_local.x += bend;
	v_local.y -= abs(bend) * 0.18;

	// Point grass normals straight up so shading matches the ground seamlessly
	NORMAL = vec3(0.0, 1.0, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * y_billboard;
	VERTEX = v_local;
}

void fragment() {
	// Procedural hand-painted 4-blade gouache grass tuft silhouette (zero external PNG needed)
	float x = UV.x;
	float y = 1.0 - UV.y; // 0 at bottom root, 1 at top tip
	float dry = (hash21(floor(UV * 36.0)) - 0.5) * 0.07;

	float b1 = smoothstep(0.11, 0.04, abs(x - (0.20 - y * 0.08))) * step(y, 0.72 + dry);
	float b2 = smoothstep(0.12, 0.04, abs(x - (0.42 - y * 0.02))) * step(y, 0.96 + dry);
	float b3 = smoothstep(0.12, 0.04, abs(x - (0.64 + y * 0.04))) * step(y, 0.88 + dry);
	float b4 = smoothstep(0.10, 0.04, abs(x - (0.83 + y * 0.09))) * step(y, 0.66 + dry);
	float tuft = max(max(b1, b2), max(b3, b4));

	// Optional cute @amelicart flower blossom sitting atop the tuft
	float blossom = 0.0;
	if (v_flower_flag > 0.5) {
		float d_fl = length((vec2(x, y) - vec2(0.52, 0.78)) * vec2(1.0, 1.15));
		blossom = step(d_fl, 0.18 + dry * 0.5);
	}

	float alpha_mask = max(tuft, blossom);
	if (alpha_mask < 0.5) {
		discard;
	}

	// Unified lighting position for the whole tuft
	LIGHT_VERTEX = v_node_pos_view;

	vec3 grass_col = mix(base_color.rgb, tip_color.rgb, clamp(v_tip_factor * 1.15 + (v_seed - 0.5) * 0.16, 0.0, 1.0));
	vec3 final_col = mix(grass_col, flower_color.rgb, blossom);
	ALBEDO = final_col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = final_col * 0.16;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float raw = clamp(ndotl * 0.5 + 0.5, 0.0, 1.0);
	float stepped = floor(raw * cel_steps + 0.35) / cel_steps;
	float lit_factor = clamp(stepped * ATTENUATION, 0.0, 1.0);
	vec3 shaded = mix(shadow_tint.rgb, vec3(1.0, 0.99, 0.95), lit_factor);
	DIFFUSE_LIGHT += ALBEDO * shaded * LIGHT_COLOR / PI;
}
