shader_type spatial;
render_mode unshaded, blend_add, cull_back;

// Issue #9 Phase 2 / #21 — refined vinyl action-figure look.
// Overlay pass: attach this material as `material_overlay` on any MeshInstance3D.
// It ADDS a view-dependent Fresnel rim to the existing surface, so it never
// replaces the character's authored albedo and adds ZERO real-time lights
// (DESIGN.md section 6: <=3 real-time lights, mobile renderer).
// "Dynamic": Fresnel uses NORMAL . VIEW, so the crisp silhouette highlight
// tracks the camera as it orbits the figure.

uniform vec3 rim_color : source_color = vec3(0.55, 0.72, 1.0);
uniform float rim_power : hint_range(0.5, 16.0) = 4.0;     // higher = sharper edge
uniform float rim_strength : hint_range(0.0, 4.0) = 1.15;  // crisp, not blown out
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float sheen : hint_range(0.0, 1.0) = 0.28;         // soft vinyl bloom

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(dot(n, v), 0.0, 1.0);

	// Sharp rim: narrow the Fresnel falloff then hard-threshold it, so low-poly
	// facet edges get a crisp moulded-plastic highlight, not a broad soft glow.
	float fres = pow(1.0 - ndv, rim_power);
	float rim = smoothstep(rim_threshold, 1.0, fres) * rim_strength;
	float broad = pow(1.0 - ndv, 2.0) * sheen;

	ALBEDO = vec3(0.0);
	EMISSION = rim_color * (rim + broad);
}
