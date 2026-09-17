shader_type spatial;

// Zombie glow shader for threat detection and visual appeal
// Features: Pulsing emission, eye glow, threat radius visualization

uniform float u_threat_level : hint_range(0.0, 1.0) = 0.5;
uniform vec4 u_glow_color : source_color = vec4(0.8, 0.2, 0.1, 1.0);
uniform float u_pulse_speed : hint_range(0.1, 3.0) = 1.5;
uniform float u_emission_strength : hint_range(0.0, 3.0) = 1.5;
uniform float u_eye_intensity : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D u_diffuse : hint_default_white;
uniform sampler2D u_normal : hint_normal;

void fragment() {
	vec4 tex = texture(u_diffuse, UV);
	
	// Pulsing threat indicator
	float pulse = sin(TIME * u_pulse_speed) * 0.5 + 0.5;
	float threat_glow = u_threat_level * (0.6 + pulse * 0.4);
	
	// Eye glow detection (sample center-ish for head area)
	float eye_factor = length(UV - vec2(0.5)) < 0.15 ? u_eye_intensity : 0.0;
	
	// Combine emissions
	float total_emission = threat_glow + eye_factor * 0.5;
	
	ALBEDO = tex.rgb;
	NORMAL_MAP = texture(u_normal, UV).rgb;
	EMISSION = u_glow_color.rgb * total_emission * u_emission_strength;
}
