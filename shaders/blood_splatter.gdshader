shader_type spatial;
render_mode unshader, cull_disabled, blend_mix, depth_test_less;

// Blood splatter shader for impact decals and gore effects
// Features: Dynamic pooling, splatter pattern, fade-out animation

uniform sampler2D u_splatter_texture : hint_default_white;
uniform vec4 u_blood_color : source_color = vec4(0.6, 0.05, 0.05, 0.8);
uniform float u_splatter_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float u_edge_softness : hint_range(0.0, 1.0) = 0.3;
uniform float u_fade_time : hint_range(0.0, 10.0) = 3.0;
uniform float u_spawn_time : hint_range(0.0, 100.0) = 0.0;
uniform float u_drip_speed : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec2 uv = UV;
	
	// Dripping effect — vertical offset increases over time
	float age = TIME - u_spawn_time;
	float drip_offset = age * u_drip_speed * 0.1;
	uv.y -= drip_offset;
	
	// Sample splatter pattern
	vec4 splatter = texture(u_splatter_texture, uv);
	
	// Splatter alpha with edge softness
	float alpha = splatter.a;
	alpha = smoothstep(0.0, u_edge_softness, alpha) * splatter.a;
	
	// Fade out over time
	float fade = 1.0 - smoothstep(0.0, u_fade_time, age);
	alpha *= fade * u_splatter_intensity;
	
	// Intensify red channel for blood
	vec3 blood = u_blood_color.rgb * (1.0 + splatter.r * 0.5);
	
	ALBEDO = blood;
	ALPHA = alpha;
}
