shader_type spatial;

// Enhanced water/puddle shader with improved visuals
// Features: Animated normal maps, parallax distortion, fresnel reflection, edge fade

uniform sampler2D u_normal_map : hint_normal;
uniform sampler2D u_surface_texture;
uniform float u_scroll_speed : hint_range(0.0, 2.0) = 0.15;
uniform float u_wave_strength : hint_range(0.0, 1.0) = 0.4;
uniform vec4 u_water_color : source_color = vec4(0.1, 0.3, 0.5, 0.6);
uniform float u_fresnel_power : hint_range(0.5, 5.0) = 2.5;
uniform float u_edge_fade : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV;
	
	// Dual-layer normal map scrolling for wave effect
	vec2 uv1 = uv + vec2(TIME * u_scroll_speed, TIME * u_scroll_speed * 0.7);
	vec2 uv2 = uv + vec2(TIME * u_scroll_speed * -0.5, TIME * u_scroll_speed * 0.3);
	
	// Sample normal maps
	vec3 normal1 = texture(u_normal_map, uv1).rgb * 2.0 - 1.0;
	vec3 normal2 = texture(u_normal_map, uv2).rgb * 2.0 - 1.0;
	vec3 combined_normal = normalize(normal1 + normal2);
	
	// Parallax offset using normals for depth illusion
	vec2 parallax = combined_normal.xy * u_wave_strength * 0.05;
	vec2 parallax_uv = uv + parallax;
	
	// Sample surface with parallax
	vec4 surface_tex = texture(u_surface_texture, parallax_uv);
	
	// Fresnel effect for edge highlights
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), u_fresnel_power);
	fresnel = mix(fresnel, 1.0, u_edge_fade);
	
	// Mix colors based on view angle
	vec3 base_color = u_water_color.rgb * surface_tex.rgb;
	vec3 reflection = vec3(0.8, 0.9, 1.0) * fresnel;
	vec3 final_color = mix(base_color, reflection, fresnel * 0.6);
	
	ALBEDO = final_color;
	NORMAL_MAP = combined_normal;
	ALPHA = u_water_color.a * (0.7 + fresnel * 0.3);
}
