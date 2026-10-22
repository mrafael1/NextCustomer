// The count's gold tank (the monitor juice, mock-up monitor_juice_v2.html, K1 "one tank" with FILL
// A, FONT C): the LED's digits and their € are one glass window onto the same liquid gold. On the
// LED's digits and € labels (GoldTank sets one material per label in the count layout, and one on
// the dessert's TOTAL slam), it repaints only their fill pass, the one drawn in fill_marker's
// colour (the labels' font colour; their ink outline and mustard shadow are drawn in other
// colours and pass through). An ancestor's grey dim or fade scales that colour: the pass is found
// by its hue (the colour over its brightest channel), and the gold is dimmed alike. Each
// fragment's place is taken in the LED's own px from the label's own vertex and the label's place
// in the LED (label_origin, label_scale: GoldTank's, from the label's transform in the LED), so
// the monitor's shakes never offset it and the waterline stands at the same height in every
// glyph, also while the digits punch. On the art's 2 px grid: above the waterline the empty glass
// (grey-beige, a darker 2 px cap at the digits' ink top) with a slanted glare per glyph; below it
// the gold in hard bands over the digits' ink height, a 2 px pale and a 2 px light row on its
// surface, and bubbles rising in it; over both, FONT C's shine bands rising up the group.
// Everything is GoldTank's: this only draws.
shader_type canvas_item;

const int GLARES = 6;
const int BUBBLES = 8;
const int SHINES = 2;

// The labels' fill colour (raw, as the vertex colour carries it): only that pass is repainted,
// found by its hue within fill_tolerance (GoldTank.is_fill_colour is the same test).
uniform vec3 fill_marker = vec3(1.0, 0.811765, 0.247059);
uniform float fill_tolerance = 0.02;
// The label's point in the LED's px = label_origin + its own point x label_scale (no rotation).
uniform vec2 label_origin = vec2(0.0);
uniform vec2 label_scale = vec2(1.0);
// The digits' ink top and baseline (the bands span them), LED px.
uniform float ink_top = 0.0;
uniform float ink_base = 1.0;
// The waterline at rest (LED px), its waves' amplitude (0: flat) and clock.
uniform float level_y = 1000.0;
uniform float wave_px = 0.0;
uniform float wave_time = 0.0;
// A landing's ripple: its middle (x), age (s, < 0 for none), depth, speed, width and life.
uniform float ripple_x = 0.0;
uniform float ripple_age = -1.0;
uniform float ripple_px = 0.0;
uniform float ripple_speed = 0.0;
uniform float ripple_width = 1.0;
uniform float ripple_s = 1.0;
// Each glyph's left (LED px; the glare stripe starts 12 px right of it at the ink top).
uniform float glare_x[6];
uniform int glare_count = 0;
// The bubbles (LED px; their top left) and the shine bands' tops (LED px).
uniform vec2 bubbles[8];
uniform int bubble_count = 0;
uniform float shines[2];
uniform int shine_count = 0;
// The mock-up's colours.
uniform vec3 empty_colour = vec3(0.827451, 0.776471, 0.650980);
uniform vec3 cap_colour = vec3(0.776471, 0.717647, 0.584314);
uniform vec4 glare_colour = vec4(0.956863, 0.933333, 0.878431, 0.9);
uniform vec3 band_0 = vec3(1.0, 0.956863, 0.811765);
uniform vec3 band_1 = vec3(1.0, 0.886275, 0.478431);
uniform vec3 band_2 = vec3(1.0, 0.811765, 0.247059);
uniform vec3 band_3 = vec3(0.949020, 0.690196, 0.180392);
uniform vec3 surface_colour = vec3(1.0, 0.945098, 0.690196);
uniform vec4 shine_colour = vec4(1.0, 1.0, 1.0, 0.85);
uniform vec4 shine_line_colour = vec4(1.0, 1.0, 1.0, 0.55);

varying vec2 led_point;
varying float is_fill;
// The ancestors' grey dim of the fill pass (1: none).
varying float dim;

float peak(vec3 colour) {
	return max(colour.r, max(colour.g, colour.b));
}

void vertex() {
	led_point = label_origin + VERTEX * label_scale;
	float bright = peak(COLOR.rgb);
	float marker = max(peak(fill_marker), 0.0001);
	vec3 hue = COLOR.rgb / max(bright, 0.0001);
	bool gold = bright > 0.02 && distance(hue, fill_marker / marker) < fill_tolerance;
	is_fill = gold ? 1.0 : 0.0;
	dim = bright / marker;
}

float q2(float value) {
	return floor(value / 2.0 + 0.5) * 2.0;
}

// The waterline over column `x` (LED px), as GoldTank.waterline_at.
float waterline(float x) {
	float y = level_y;
	y += sin(x * 0.16 + wave_time * 7.0) * wave_px * 0.6;
	y += sin(x * 0.06 - wave_time * 4.3) * wave_px * 0.4;
	if (ripple_age >= 0.0 && ripple_age < ripple_s) {
		float d = abs(x - ripple_x) - ripple_age * ripple_speed;
		y -= ripple_px * exp(-d * d / ripple_width) * (1.0 - ripple_age / ripple_s);
	}
	return y;
}

vec3 band(float y) {
	float t = (y - ink_top) / max(1.0, ink_base - ink_top);
	if (t < 0.16) {
		return band_0;
	}
	if (t < 0.4) {
		return band_1;
	}
	if (t < 0.74) {
		return band_2;
	}
	return band_3;
}

void fragment() {
	if (is_fill > 0.5) {
		float x = floor(led_point.x / 2.0) * 2.0;
		float y = floor(led_point.y);
		float water = q2(waterline(x));
		vec3 colour;
		if (y >= water) {
			colour = band(y);
			if (y < water + 2.0) {
				colour = surface_colour;
			} else if (y < water + 4.0) {
				colour = band_1;
			}
			for (int index = 0; index < BUBBLES; index++) {
				if (index >= bubble_count) {
					break;
				}
				vec2 bubble = bubbles[index];
				bool inside = x == bubble.x && y >= bubble.y && y < bubble.y + 2.0;
				if (inside && bubble.y >= waterline(bubble.x) + 4.0) {
					colour = surface_colour;
				}
			}
		} else {
			colour = y < ink_top + 2.0 ? cap_colour : empty_colour;
			float share = (y - ink_top) / max(1.0, ink_base - ink_top);
			for (int index = 0; index < GLARES; index++) {
				if (index >= glare_count) {
					break;
				}
				float left = glare_x[index] + 12.0 - 18.0 * share;
				if (led_point.x >= left && led_point.x < left + 4.0) {
					colour = mix(colour, glare_colour.rgb, glare_colour.a);
				}
			}
		}
		for (int index = 0; index < SHINES; index++) {
			if (index >= shine_count) {
				break;
			}
			float top = shines[index];
			if (y >= top && y < top + 6.0) {
				colour = mix(colour, shine_colour.rgb, shine_colour.a);
			} else if (y >= top + 10.0 && y < top + 12.0) {
				colour = mix(colour, shine_line_colour.rgb, shine_line_colour.a);
			}
		}
		COLOR = vec4(colour * dim, COLOR.a);
	}
}
