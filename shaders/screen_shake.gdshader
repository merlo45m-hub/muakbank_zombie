shader_type canvas_item;
render_mode unshaded;

// Screen shake post-processing shader
// Time-based UV jitter — a post-FX approximation of camera shake.
// For true screen shake, animate the camera or root node in GDScript instead.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

uniform float u_shake_intensity : hint_range(0.0, 0.05, 0.001) = 0.0;
uniform float u_shake_frequency : hint_range(1.0, 30.0, 0.5) = 15.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	if (u_shake_intensity <= 0.0) {
		COLOR = texture(screen_texture, uv);
		return;
	}

	float t = TIME * u_shake_frequency;
	vec2 offset = vec2(
		sin(t * 1.3 + uv.x * 5.0) * 0.5 + cos(t * 0.7 + uv.y * 3.0) * 0.5,
		cos(t * 0.9 + uv.y * 4.0) * 0.5 + sin(t * 1.1 + uv.x * 6.0) * 0.5
	) * u_shake_intensity;

	COLOR = texture(screen_texture, uv + offset);
}
