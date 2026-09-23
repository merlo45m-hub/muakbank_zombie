shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Enhanced dissolve shader for zombie death sequences
// Features: Emission trails, animated edge glow, particle breakup effect

uniform float u_dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_edge_width : hint_range(0.01, 0.3) = 0.1;
uniform vec4 u_edge_color : source_color = vec4(1.0, 0.3, 0.05, 1.0);
uniform vec4 u_base_color : source_color = vec4(0.6, 0.55, 0.5, 1.0);
uniform float u_dissolve_seed : hint_range(0.0, 100.0) = 42.0;
uniform float u_emission_intensity : hint_range(0.0, 3.0) = 2.0;
uniform float u_breakup_scale : hint_range(0.5, 5.0) = 2.0;

// Improved 3D hash for less banding
float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z * 43758.5453);
}

// Perlin-like noise for smoother dissolve
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	
	// Hermite interpolation
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec3(1.0, 0.0, 0.0));
	float c = hash(i + vec3(0.0, 1.0, 0.0));
	float d = hash(i + vec3(1.0, 1.0, 0.0));
	float e = hash(i + vec3(0.0, 0.0, 1.0));
	float f_val = hash(i + vec3(1.0, 0.0, 1.0));
	float g = hash(i + vec3(0.0, 1.0, 1.0));
	float h = hash(i + vec3(1.0, 1.0, 1.0));
	
	return mix(
		mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
		mix(mix(e, f_val, f.x), mix(g, h, f.x), f.y),
		f.z
	);
}

void fragment() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Dual-layer noise for better detail
	float n1 = noise(world_pos * 3.0 + u_dissolve_seed);
	float n2 = noise(world_pos * u_breakup_scale + u_dissolve_seed * 0.5);
	float combined = mix(n1, n2, 0.4);
	
	// Smooth threshold for organic dissolve
	float threshold = u_dissolve_progress * 1.1;
	float edge_low = threshold - u_edge_width;
	float edge_high = threshold;
	
	// Edge detection with smooth falloff
	float edge = smoothstep(edge_low - 0.05, edge_low, combined) - 
				 smoothstep(edge_high, edge_high + 0.05, combined);
	
	// Discard fully dissolved pixels
	if (combined < edge_low) {
		discard;
	}
	
	// Color and emission based on position in dissolve edge
	vec3 final_color = u_base_color.rgb;
	float emission = 0.0;
	
	if (edge > 0.1) {
		// Bright edge glow
		final_color = mix(u_edge_color.rgb, vec3(1.0, 0.6, 0.2), edge * 0.8);
		emission = edge * u_emission_intensity;
	}
	
	ALBEDO = final_color;
	EMISSION = u_edge_color.rgb * emission;
	ALPHA = 1.0 - smoothstep(edge_low + u_edge_width, threshold + u_edge_width, combined);
}
