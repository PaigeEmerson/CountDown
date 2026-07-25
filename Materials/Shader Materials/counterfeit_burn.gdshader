shader_type spatial;
render_mode cull_disabled;

uniform sampler2D paper_texture : source_color;
uniform sampler2D burn_noise;

uniform float burn_progress : hint_range(0.0, 1.0) = 0.0;
uniform float burn_edge_width : hint_range(0.01, 0.25) = 0.08;

uniform vec3 burned_color : source_color = vec3(0.03, 0.015, 0.005);
uniform vec3 ember_color : source_color = vec3(1.0, 0.18, 0.01);

void fragment() {
	vec4 paper = texture(paper_texture, UV);
	float noise_value = texture(burn_noise, UV * 2.0).r;

	float threshold = burn_progress * 1.2 - 0.1;

	if (noise_value < threshold) {
		discard;
	}

	float edge = 1.0 - smoothstep(
		threshold,
		threshold + burn_edge_width,
		noise_value
	);

	vec3 charred_color = mix(burned_color, ember_color, edge);
	ALBEDO = mix(paper.rgb, charred_color, edge);
	EMISSION = ember_color * edge * 1.5;
	ROUGHNESS = 0.9;
}