shader_type spatial;
render_mode unshader, cull_disabled, blend_mix, depth_test_less;

// Optimized volumetric fog with texture-based sampling
// Features: Faster noise via texture, light interaction, wind animation

uniform sampler2D u_noise_texture : hint_default_white;
uniform vec4 u_fog_color : source_color = vec4(0.4, 0.38, 0.35, 0.15);
uniform float u_fog_density : hint_range(0.0, 1.0) = 0.4;
uniform float u_noise_scale : hint_range(0.5, 5.0) = 1.5;
uniform float u_noise_speed : hint_range(0.0, 1.0) = 0.15;
uniform vec2 u_wind_direction : hint_range(-1.0, 1.0) = vec2(1.0, 0.5);
uniform float u_light_absorption : hint_range(0.0, 2.0) = 1.0;
uniform vec3 u_light_direction = vec3(0.577, 0.577, 0.577); // Normalized

void fragment() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Sample noise texture with wind offset
	vec2 noise_uv = (world_pos.xz + u_wind_direction * TIME * u_noise_speed) / u_noise_scale;
	float n1 = texture(u_noise_texture, noise_uv).r;
	
	// Second octave for better detail
	float n2 = texture(u_noise_texture, noise_uv * 2.0 + vec2(TIME * 0.05)).r;
	float combined_noise = mix(n1, n2, 0.5);
	
	// Height-based density falloff (less fog at top)
	float height_factor = exp(-world_pos.y * 0.1);
	
	// Density calculation
	float density = u_fog_density * (0.4 + combined_noise * 0.6) * height_factor;
	
	// Light absorption based on surface normal (fake directional light)
	float light_factor = max(0.3, dot(normalize(u_light_direction), normalize(NORMAL)));
	density *= mix(1.0 - u_light_absorption, 1.0, light_factor);
	
	ALBEDO = u_fog_color.rgb;
	ALPHA = u_fog_color.a * density;
}
