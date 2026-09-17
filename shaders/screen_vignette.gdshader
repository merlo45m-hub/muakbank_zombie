shader_type canvas_item;

// Screen vignette shader for health/stress feedback
// Features: Dynamic edge darkening, chromatic aberration, screen distortion

uniform float u_vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float u_vignette_smoothness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 u_vignette_color : source_color = vec4(0.8, 0.1, 0.0, 1.0);
uniform float u_damage_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float u_chromatic_aberration : hint_range(0.0, 0.05) = 0.015;
uniform float u_distortion_amount : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec2 screen_uv = UV;
	vec2 center = vec2(0.5);
	
	// Vignette mask from center
	float dist_from_center = length(screen_uv - center);
	float vignette = smoothstep(1.0 + u_vignette_smoothness, 0.3, dist_from_center);
	vignette *= u_vignette_intensity + (u_damage_pulse * 0.3);
	
	// Chromatic aberration on damage
	vec2 ca_offset = normalize(screen_uv - center) * u_chromatic_aberration * u_damage_pulse;
	vec3 color = texture(TEXTURE, screen_uv).rgb;
	color.r = texture(TEXTURE, screen_uv + ca_offset).r;
	color.b = texture(TEXTURE, screen_uv - ca_offset).b;
	
	// Subtle screen distortion from damage
	vec2 distort = (screen_uv - center) * u_distortion_amount * u_damage_pulse;
	color = mix(color, texture(TEXTURE, screen_uv + distort).rgb, u_damage_pulse * 0.2);
	
	// Apply vignette overlay
	vec3 final_color = mix(color, u_vignette_color.rgb, vignette * u_damage_pulse);
	
	COLOR = vec4(final_color, 1.0);
}
