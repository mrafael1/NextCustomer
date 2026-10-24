shader_type canvas_item;
// The LEGENDARY prize ticket's sunburst (v0.50, mock-up docs/art/mockups/premium_machine_v1.html,
// rays()): `rays` rays round the rect's centre and a solid core disc, fading toward the ray ends
// through a 4x4 ordered (Bayer) dither instead of a hard circle, in three bands (outer, middle,
// core), on the art grid (`pixel` canvas px per cell), so its edges stay stepped. Outside the
// rays is clear (no gap colour). PrizeTicket drives `radius`, `rotation` and `alpha`.

uniform float radius = 220.0;
uniform float rotation = 0.0;
uniform float alpha = 1.0;
uniform float rays = 12.0;
uniform vec2 rect_size = vec2(440.0, 440.0);
uniform float pixel = 2.0;
uniform vec4 outer_colour : source_color = vec4(1.0, 0.812, 0.247, 1.0);
uniform vec4 middle_colour : source_color = vec4(0.945, 0.824, 0.478, 1.0);
uniform vec4 core_colour : source_color = vec4(0.98, 0.925, 0.737, 1.0);

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 cell = floor(UV * rect_size / pixel);
	vec2 d = cell - rect_size / pixel / 2.0 + 0.5;
	float r = length(d);
	float r0 = radius / pixel;
	vec4 colour = vec4(0.0);
	if (r0 >= 1.0 && r <= r0 && alpha > 0.02) {
		float f = fract((atan(d.y, d.x) + rotation) / 6.2831853 * rays);
		bool in_ray = f < 0.42 || r < r0 * 0.22;
		float fade = (1.0 - r / r0) * 1.5 * alpha;
		int index = int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0));
		float threshold = (BAYER[index] + 0.5) / 16.0;
		if (in_ray && fade >= threshold) {
			colour = r < r0 * 0.3 ? core_colour : (r < r0 * 0.6 ? middle_colour : outer_colour);
		}
	}
	COLOR = colour;
}
