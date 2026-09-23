shader_type canvas_item;
render_mode unshaded;

// VesperaFX-based chromatic aberration
// RGB channel offset from VesperaFX crt.gdshaderinc (apply_vhs_chromatic)

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

uniform float u_chromatic_offset : hint_range(0.0, 0.02, 0.001) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	if (u_chromatic_offset <= 0.0) {
		COLOR = texture(screen_texture, uv);
	} else {
		float r = texture(screen_texture, uv + vec2(u_chromatic_offset, 0.0)).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv - vec2(u_chromatic_offset, 0.0)).b;
		COLOR = vec4(r, g, b, 1.0);
	}
}
