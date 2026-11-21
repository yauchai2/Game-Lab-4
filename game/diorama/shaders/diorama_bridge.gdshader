shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 stone_light : source_color = vec4(0.72, 0.66, 0.54, 1.0);
uniform vec4 stone_dark : source_color = vec4(0.52, 0.47, 0.40, 1.0);
varying vec3 masonry_position;

float tile_hash(vec2 tile) {
	vec3 p = fract(vec3(tile.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	masonry_position = VERTEX;
}

void fragment() {
	vec2 grid = masonry_position.xz * vec2(3.35, 3.6);
	grid.y += mod(floor(grid.x), 2.0) * 0.5;
	vec2 f = fract(grid);
	vec2 edge = min(f, 1.0 - f);
	vec2 cut = smoothstep(vec2(0.012), vec2(0.055) + fwidth(grid) * 0.35, edge);
	vec3 stone = mix(stone_dark.rgb, stone_light.rgb, 0.37 + 0.60 * tile_hash(floor(grid)));
	stone *= 0.93 + 0.07 * sin(masonry_position.x * 24.0 + sin(masonry_position.z * 22.0));
	ALBEDO = stone * mix(0.72, 1.0, cut.x * cut.y);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
