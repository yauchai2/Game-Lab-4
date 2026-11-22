shader_type spatial;

uniform vec4 finish_color : source_color = vec4(1.0);
uniform float finish_roughness : hint_range(0.0, 1.0) = 0.73;
uniform float finish_specular : hint_range(0.0, 1.0) = 0.23;
uniform vec4 glow_color : source_color = vec4(0.0);
uniform float glow_energy = 0.0;
uniform float cover_opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float coverage = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776, 0.5698403)));
	if (coverage > cover_opacity) {
		discard;
	}
	ALBEDO = finish_color.rgb;
	EMISSION = glow_color.rgb * glow_energy;
	ROUGHNESS = finish_roughness;
	SPECULAR = finish_specular;
}
