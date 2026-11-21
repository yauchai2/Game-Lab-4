shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

uniform vec4 tint_color : source_color = vec4(1.0);
uniform bool conifer = false;
uniform float night_mix = 0.0;
varying vec3 crown_position;
varying float crown_light;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Blended cells form soft clusters of needles and leaves, fixed to the branches.
float brush(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(vec3(0.0), vec3(1.0), fract(p));
	vec4 a = vec4(hash(i), hash(i + vec3(1,0,0)), hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)));
	vec3 k = i + vec3(0,0,1);
	vec4 b = vec4(hash(k), hash(k + vec3(1,0,0)), hash(k + vec3(0,1,0)), hash(k + vec3(1,1,0)));
	vec4 slab = mix(a, b, f.z);
	return mix(mix(slab.x, slab.y, f.x), mix(slab.z, slab.w, f.x), f.y);
}

global uniform vec2 wind_direction;
global uniform float wind_speed;
global uniform float wind_strength;

void vertex() {
	crown_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (INSTANCE_CUSTOM.w > 0.5) {
		vec3 whole_crown = normalize(VERTEX + INSTANCE_CUSTOM.xyz);
		NORMAL = normalize(mix(NORMAL, whole_crown, 0.42));
	}
	crown_light = dot(normalize(MODEL_NORMAL_MATRIX * NORMAL), normalize(vec3(-0.42,0.83,0.36)));
	vec2 wind = normalize(wind_direction);
	float gust = sin(dot(crown_position.xz, wind) * 0.52 - TIME * wind_speed * 1.25);
	float sway = gust * (0.18 + 0.22 * sin(TIME * 0.39)) * wind_strength * (conifer ? smoothstep(0.8, 4.0, VERTEX.y) : 0.45);
	vec3 world_bend = vec3(wind.x, 0.0, wind.y);
	vec2 local_bend = vec2(dot(normalize(MODEL_MATRIX[0].xyz), world_bend),
		dot(normalize(MODEL_MATRIX[2].xyz), world_bend));
	VERTEX.xz += local_bend * sway;
}

void fragment() {
	float clusters = brush(crown_position * 2.2);
	float flecks = brush(crown_position * vec3(6.0,4.0,6.0));
	float light = smoothstep(-0.30,0.94,crown_light + 0.25 * (clusters - 0.5));
	vec3 hue = mix(vec3(0.45,0.66,0.71), vec3(1.08,1.07,0.87), light);
	float leaf_tips = smoothstep(0.50,0.76,clusters * 0.68 + flecks * 0.32);
	ALBEDO = COLOR.rgb * tint_color.rgb * hue * mix(0.85,1.10,leaf_tips);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.1);
	float transmitted = rim * smoothstep(0.0, 0.78, 1.0 - abs(crown_light));
	EMISSION = COLOR.rgb * vec3(0.76, 0.94, 0.38) * transmitted * (1.0 - night_mix) * 0.115;
	ROUGHNESS = 0.74;
	SPECULAR = 0.19;
}
