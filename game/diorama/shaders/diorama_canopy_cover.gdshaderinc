uniform vec3 traveler_sight = vec3(0.0, -200.0, 0.0);
uniform vec3 sight_camera = vec3(0.0, 20.0, 25.0);

bool canopy_blocks_player(vec3 world, vec2 pixel_position) {
	vec3 to_camera = normalize(sight_camera - traveler_sight);
	vec3 from_traveler = world - traveler_sight;
	float along = dot(from_traveler, to_camera);
	float from_ray = length(from_traveler - to_camera * along);
	float aperture = (1.0 - smoothstep(0.61, 1.23, from_ray))
		* smoothstep(0.05, 0.65, along) * (1.0 - smoothstep(9.5, 14.0, along));
	float pixel = fract(dot(floor(pixel_position), vec2(0.7548776, 0.5698403)));
	return pixel < aperture * 0.88;
}
