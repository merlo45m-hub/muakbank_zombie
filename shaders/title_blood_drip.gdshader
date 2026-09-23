shader_type canvas_item;

// Blood drip effect for title screen wordmark
// Hangs animated blood drops from the bottom of rendered text characters

uniform float drip_speed : hint_range(0.1, 2.0) = 0.8;
uniform float drip_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float drip_length : hint_range(0.01, 0.25) = 0.18;
uniform vec4 blood_color : source_color = vec4(0.65, 0.03, 0.03, 1.0);
uniform vec4 blood_dark : source_color = vec4(0.35, 0.01, 0.01, 1.0);

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	COLOR = original;

	if (original.a < 0.005) {
		// Pixel is background — check if we should draw a drip here (below text)
		for (float step = 0.003; step <= drip_length; step += 0.003) {
			vec4 above = texture(TEXTURE, vec2(UV.x, UV.y - step));
			if (above.a > 0.1) {
				// There is text directly above — potentially a drip hanging from it
				float seed = fract(UV.x * 71.0 + (UV.y - step) * 157.0);
				float drop_id = fract(seed + TIME * drip_speed * 0.08);

				if (drop_id < drip_intensity) {
					// This column gets a drip
					float dist_down = step;
					float progress = dist_down / drip_length;
					float shape = sin(progress * 3.14159); // bell: 0 at top/bottom, 1 at middle
					shape = shape * shape;

					// Narrow drip column, snapped for stability
					float x_snap = floor(UV.x * 150.0) / 150.0;
					float x_dist = abs(UV.x - x_snap);
					float max_w = 0.012 * shape;

					if (x_dist < max_w) {
						vec4 drip_col = mix(blood_color, blood_dark, progress * 0.7);
						float alpha = shape * 0.85;
						COLOR.rgb = mix(COLOR.rgb, drip_col.rgb, alpha);
						COLOR.a = max(COLOR.a, alpha);
					}
				}
				break;
			}
		}
	}
}
