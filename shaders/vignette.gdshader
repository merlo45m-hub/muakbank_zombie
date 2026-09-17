shader_type canvas_item;
render_mode unshaded;

// VesperaFX-based screen vignette
// Edge-darkening with smooth falloff, inspired by VesperaFX crt.gdshaderinc

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

uniform float u_vignette_intensity : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float u_vignette_smoothness : hint_range(0.01, 1.0, 0.01) = 0.5;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color = texture(screen_texture, uv).rgb;

	if (u_vignette_intensity <= 0.0) {
		COLOR = vec4(color, 1.0);
		return;
	}

	vec2 centered = uv - 0.5;
	float dist = length(centered) * 2.0;
	float vignette = smoothstep(1.0, 1.0 - u_vignette_smoothness, dist);
	vignette = mix(1.0, vignette, u_vignette_intensity);

	COLOR = vec4(color * vignette, 1.0);
}
