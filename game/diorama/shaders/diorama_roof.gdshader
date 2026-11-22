shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 clay_base : source_color = vec4(0.68, 0.28, 0.15, 1.0);
uniform vec4 clay_light : source_color = vec4(0.92, 0.47, 0.29, 1.0);
varying vec3 tile_position;

float roof_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	tile_position = VERTEX;
}

uniform float cover_opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float screen_pattern = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776, 0.5698403)));
	if (screen_pattern > cover_opacity) {
		discard;
	}
	vec2 grid = tile_position.xz * vec2(2.60, 3.10);
	float row = floor(grid.y);
	grid.x += mod(row, 2.0) * 0.5;
	vec2 id = floor(grid);
	vec2 cell = fract(grid);
	vec2 antialias = max(fwidth(grid), vec2(0.014));
	float joint_x = min(cell.x, 1.0 - cell.x);
	float joint_y = min(cell.y, 1.0 - cell.y);
	float edge_x = smoothstep(0.012, 0.035 + antialias.x, joint_x);
	float edge_y = smoothstep(0.016, 0.067 + antialias.y, joint_y);
	vec3 terracotta = mix(clay_base.rgb, clay_light.rgb, 0.18 + 0.48 * roof_hash(id));
	float hand_painted = mix(0.85, 1.02, smoothstep(0.04, 0.50, cell.y));
	float curved = 1.04 - 0.09 * pow(abs(cell.x * 2.0 - 1.0), 1.6);
	float bevel = 0.79 + 0.21 * edge_x * edge_y;
	ALBEDO = terracotta * hand_painted * curved * bevel;
	ROUGHNESS = mix(0.91, 0.81, edge_x * edge_y);
	SPECULAR = 0.085;
	CLEARCOAT = 0.015;
	CLEARCOAT_ROUGHNESS = 0.54;
}
