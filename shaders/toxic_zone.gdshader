shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Toxic radiation zone shader for hazard visualization
// Features: Animated warning glow, ripple distortion, geiger-like pulsing

uniform vec4 u_zone_color : source_color = vec4(0.2, 0.8, 0.3, 0.4);
uniform float u_zone_density : hint_range(0.0, 1.0) = 0.5;
uniform float u_pulse_speed : hint_range(0.5, 3.0) = 2.0;
uniform float u_ripple_scale : hint_range(0.5, 5.0) = 2.0;
uniform float u_ripple_speed : hint_range(0.0, 2.0) = 0.8;
uniform float u_distortion_strength : hint_range(0.0, 0.3) = 0.1;
uniform sampler2D u_noise_texture : hint_default_white;

void fragment() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world_pos.xz * u_ripple_scale;
	
	// Sample noise for organic movement
	float noise1 = texture(u_noise_texture, uv + TIME * u_ripple_speed).r;
	float noise2 = texture(u_noise_texture, uv * 0.5 + TIME * u_ripple_speed * 0.7).r;
	
	// Ripple distortion pattern
	float ripple = sin(length(uv) - TIME * u_ripple_speed * 2.0) * 0.5 + 0.5;
	float distorted = mix(noise1, ripple, 0.6);
	
	// Geiger-like pulsing (rapid intensity changes)
	float pulse = abs(sin(TIME * u_pulse_speed * 3.14159)) * 0.6 + 0.4;
	
	// Combine effects
	float intensity = (distorted + noise2 * 0.3) * pulse;
	float density = u_zone_density * intensity;
	
	// Green glow with flicker
	vec3 glow_color = u_zone_color.rgb * (1.0 + noise2 * 0.3);
	
	ALBEDO = glow_color;
	EMISSION = glow_color * intensity * 0.8;
	ALPHA = u_zone_color.a * density;
}
