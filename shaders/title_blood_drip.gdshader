shader_type canvas_item;

// Blood drip effect for the title-screen wordmark. Hangs animated, glossy
// blood from the bottom edge of the rendered glyphs. A canvas_item material
// REPLACES the label's draw color, so sampled glyphs render through
// text_color here — that is the real text color.

uniform float drip_speed : hint_range(0.1, 2.0) = 0.45;
uniform float drip_intensity : hint_range(0.0, 1.0) = 0.55;
uniform float drip_length : hint_range(0.01, 0.30) = 0.22;
uniform vec4 blood_color : source_color = vec4(0.62, 0.03, 0.03, 1.0);
uniform vec4 blood_dark : source_color = vec4(0.28, 0.01, 0.01, 1.0);
uniform vec4 text_color : source_color = vec4(0.82, 0.10, 0.07, 1.0);

// Stable per-column random in [0,1).
float col_hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	COLOR = original;
	COLOR.rgb = original.rgb * text_color.rgb;

	if (original.a < 0.005) {
		// Background pixel: look upward for a glyph edge to hang a drip from.
		float x_snap = floor(UV.x * 220.0) / 220.0;   // fine, stable column
		float h = col_hash(x_snap * 311.7);
		// Each drip gets its own length and phase, so drips lengthen and pinch
		// off out of sync instead of moving as one block.
		float len = drip_length * (0.55 + 0.45 * h);
		float phase = fract(h + TIME * drip_speed * 0.12);
		float grown = smoothstep(0.0, 0.65, phase);
		float pinched = smoothstep(0.8, 1.0, phase);
		float L = len * grown * (1.0 - 0.6 * pinched);

		for (float d = 0.002; d <= L; d += 0.002) {
			vec4 above = texture(TEXTURE, vec2(UV.x, UV.y - d));
			if (above.a > 0.1) {
				float x_dist = abs(UV.x - x_snap);
				float progress = d / max(L, 0.0001);   // 0 at glyph, 1 at tip

				// Distinct columns: only some columns get a drip (spacing so they read
				// as separate drops, not a merged curtain). Wider base + round bulb.
				float gate = step(0.42, h);               // ~58% of columns carry a drip
				float col_w = 0.020 * (1.0 - 0.55 * progress);   // wider, gentler taper
				float bulb = smoothstep(0.72, 1.0, progress);
				float bulb_w = 0.028 * bulb;              // clearly wider round tip
				float w = max(col_w, bulb_w);
				// Anti-aliased, rounded edges (no hard blocky cut).
				float edge = 1.0 - smoothstep(w * 0.55, w, x_dist);
				if (edge > 0.001 && d < L && gate > 0.5) {
					// Glossy blood: darker at the edges + a highlight streak.
					float shade = mix(0.6, 1.0, 1.0 - clamp(x_dist / max(w, 0.0001), 0.0, 1.0));
					float streak = smoothstep(0.35, 0.0, x_dist) * (1.0 - progress) * 0.5;
					vec4 drip_col = mix(blood_color, blood_dark, progress * 0.6);
					drip_col.rgb *= shade;
					drip_col.rgb += streak;
					float alpha = edge * (0.9 - 0.3 * pinched);
					COLOR.rgb = mix(COLOR.rgb, drip_col.rgb, alpha);
					COLOR.a = max(COLOR.a, alpha);
				}
				break;
			}
		}
	}
}
