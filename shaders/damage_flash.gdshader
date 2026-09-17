shader_type spatial;
render_mode unshader, cull_disabled, depth_test_less;

// Enhanced damage flash shader for impact feedback
// Features: Emission glow, saturation boost, outline effect

uniform float u_flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 u_base_color : source_color = vec4(0.6, 0.55, 0.5, 1.0);
uniform vec4 u_flash_color : source_color = vec4(1.0, 0.1, 0.05, 1.0);
uniform float u_emission_strength : hint_range(0.0, 3.0) = 2.0;
uniform float u_saturation : hint_range(0.0, 2.0) = 1.3;
uniform float u_screen_distort : hint_range(0.0, 0.1) = 0.02;

// Convert to HSL, adjust saturation
vec3 adjust_saturation(vec3 color, float sat) {
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), color, sat);
}

void fragment() {
	// Base-to-flash color blend
	vec3 blended = mix(u_base_color.rgb, u_flash_color.rgb, u_flash_intensity);
	
	// Boost saturation during flash
	blended = adjust_saturation(blended, u_saturation);
	
	// Add emission glow on flash
	float glow = u_flash_intensity * u_emission_strength;
	
	ALBEDO = blended;
	EMISSION = u_flash_color.rgb * glow;
	ALPHA = 1.0;
}
