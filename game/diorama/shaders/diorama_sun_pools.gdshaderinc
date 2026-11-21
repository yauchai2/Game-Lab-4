uniform vec2 sun_patches[3];

float sun_pools(vec2 world_xz) {
	float light = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 difference = (world_xz - sun_patches[i]) * vec2(0.74, 1.04);
		light = max(light, 1.0 - smoothstep(0.36, 1.88, length(difference)));
	}
	return light;
}
