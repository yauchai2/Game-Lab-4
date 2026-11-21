shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float night_mix = 0.0;
uniform float orbit_blur = 1.0;

float bayer2(vec2 cell) {
	return 2.0 * cell.x + 3.0 * cell.y - 4.0 * cell.x * cell.y;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = uv * 2.0 - 1.0;
	float focus_band = abs(uv.y - 0.54 + p.x * 0.026);
	float defocus = smoothstep(0.18, 0.48, focus_band);
	float falloff = smoothstep(0.48, 1.39, length(p));
	float lod = defocus * mix(2.56, 2.16, night_mix) * orbit_blur;
	vec3 color = textureLod(scene_color, uv, lod).rgb;
	// Slow, broad glow that only responds to the brightest painted highlights.
	vec3 halo = textureLod(scene_color, uv, 3.55).rgb;
	float brightness = dot(halo, vec3(0.2126, 0.7152, 0.0722));
	float highlight = smoothstep(0.58, 0.92, brightness);
	color += halo * highlight * mix(0.068, 0.035, night_mix);
	color *= 1.0 - 0.12 * falloff;
	vec2 pixel = mod(floor(FRAGCOORD.xy), 4.0);
	float threshold = (4.0 * bayer2(mod(pixel, 2.0)) + bayer2(floor(pixel * 0.5)) + 0.5) / 16.0;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float soft_tones = smoothstep(0.05, 0.25, luma) * (1.0 - smoothstep(0.68, 0.91, luma));
	color += (threshold - 0.5) * 0.0085 * soft_tones;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
