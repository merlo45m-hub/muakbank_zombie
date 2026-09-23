shader_type canvas_item;
render_mode unshaded;

// VesperaFX-based grain / noise overlay
// Animated static grain from VesperaFX crt.gdshaderinc (apply_vhs_noise)

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

uniform float u_grain_intensity : hint_range(0.0, 1.0, 0.01) = 0.0;

// hash helper from VesperaFX crt.gdshaderinc
float _vhs_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color = texture(screen_texture, uv).rgb;

	if (u_grain_intensity > 0.0) {
		float noise = _vhs_hash(uv * 1000.0 + TIME);
		noise = (noise - 0.5) * u_grain_intensity;
		color = color + noise;
	}

	COLOR = vec4(color, 1.0);
}
