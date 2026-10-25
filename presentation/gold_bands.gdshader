// The monitor's total in gold bands (#105 piece 2, mock-up readability_v3.html, monitor b): on a
// TotalNumber's digit and € labels (one material each), it repaints only their fill pass, the one
// drawn in fill_marker's colour (their ink outline and ink drop are drawn in other colours and pass
// through), in four hard bands over the digits' ink height from the bottom: mustard dark to 12 %,
// gold to 60 %, mustard light to 76 %, gold above. A shine (FONT C) runs across the whole group
// while `shine` is between 0 and 1: a white band slanted at 110°, its left at -20 % + 150 % x shine
// of the group's width. An ancestor's grey dim scales that colour: the pass is found by its hue and
// the gold is dimmed alike. Everything is TotalNumber's: this only draws.
shader_type canvas_item;

uniform vec3 fill_marker = vec3(1.0, 0.811765, 0.247059);
uniform float fill_tolerance = 0.02;
// The digits' ink top and baseline in the label's own px.
uniform float ink_top = 0.0;
uniform float ink_base = 1.0;
// The label's left in the group, the group's width, and the shine (< 0 or > 1: none).
uniform float group_x = 0.0;
uniform float group_w = 1.0;
uniform float shine = -1.0;
uniform vec3 band_dark = vec3(0.701961, 0.517647, 0.145098);
uniform vec3 band_gold = vec3(1.0, 0.811765, 0.247059);
uniform vec3 band_light = vec3(0.945098, 0.823529, 0.478431);
uniform vec4 shine_colour = vec4(1.0, 1.0, 1.0, 0.9);

varying vec2 local_point;
varying float is_fill;
varying float dim;

float peak(vec3 colour) {
	return max(colour.r, max(colour.g, colour.b));
}

void vertex() {
	local_point = VERTEX;
	float bright = peak(COLOR.rgb);
	float marker = max(peak(fill_marker), 0.0001);
	vec3 hue = COLOR.rgb / max(bright, 0.0001);
	bool gold = bright > 0.02 && distance(hue, fill_marker / marker) < fill_tolerance;
	is_fill = gold ? 1.0 : 0.0;
	dim = bright / marker;
}

void fragment() {
	if (is_fill > 0.5) {
		float y = floor(local_point.y);
		float t = (ink_base - y) / max(1.0, ink_base - ink_top);
		vec3 colour = band_gold;
		if (t < 0.12) {
			colour = band_dark;
		} else if (t < 0.6) {
			colour = band_gold;
		} else if (t < 0.76) {
			colour = band_light;
		}
		if (shine >= 0.0 && shine <= 1.0) {
			// 110°: the band leans right going up, about 0.36 px across per px up.
			float x = group_x + local_point.x + (ink_base - y) * 0.36;
			float u = x / max(1.0, group_w) * 100.0;
			float left = -20.0 + 150.0 * shine;
			if (u >= left && u < left + 12.0) {
				colour = mix(colour, shine_colour.rgb, shine_colour.a);
			}
		}
		COLOR = vec4(colour * dim, COLOR.a);
	}
}
