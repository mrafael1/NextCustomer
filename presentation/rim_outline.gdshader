// A die-cut rim round pixel art (#105, mock-up readability v3's chained 2 px CSS drop-shadows):
// drawn on a TextureRect that shows the art's own texture over the art's rect grown by 2 art
// pixels on every side, behind (or under) the art. Each art pixel of that grown grid takes the
// band of its square (Chebyshev) distance to the art's nearest opaque pixel: 1 is the first band
// (a price tag's paper, a glyph's paper rim), 2 the second (the tag's ink outline; transparent for
// a glyph's rim); the art itself and anything further are transparent. Chained drop-shadows in 4
// directions dilate by a 3x3 square at each step, so the corners stay square (an L1 halo would
// leave them stepped). The node's modulate still applies.
shader_type canvas_item;

// The bands from the art outwards.
uniform vec4 bands[2];

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	ivec2 grid = size + ivec2(4);
	ivec2 texel = ivec2(floor(UV * vec2(grid))) - ivec2(2);
	int best = 3;
	for (int dy = -2; dy <= 2; dy++) {
		for (int dx = -2; dx <= 2; dx++) {
			int steps = max(abs(dx), abs(dy));
			if (steps >= best) {
				continue;
			}
			ivec2 probe = texel + ivec2(dx, dy);
			if (probe.x < 0 || probe.y < 0 || probe.x >= size.x || probe.y >= size.y) {
				continue;
			}
			if (texelFetch(TEXTURE, probe, 0).a > 0.5) {
				best = steps;
			}
		}
	}
	if (best == 0 || best > 2) {
		discard;
	}
	COLOR = bands[best - 1] * modulate;
}
