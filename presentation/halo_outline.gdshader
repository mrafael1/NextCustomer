// A boosted item's stepped pixel halo (#71, mock-up h1, H1_BUILD_SPEC.md section 4.3): drawn on
// a TextureRect that shows the item's own sprite texture over the sprite's rect grown by
// (rings + 1) art pixels on every side, behind the sprite. Each art pixel of that grown grid
// takes the band of its 4-neighbour (L1) distance to the sprite's nearest opaque pixel: 1 to
// `rings` are the bands (inside out), rings + 1 is the ink outline, and the sprite itself
// (distance 0) and anything further are transparent. This is the mock-up's chained 2 px CSS
// drop-shadows (stepped diamond corners) on the texel grid, with no new art. `bands` holds the
// ring colours then the ink (ArtStyle.halo_material). The node's modulate still applies.
shader_type canvas_item;

// The halo's rings, 1 to 3.
uniform int rings = 1;
// The ring colours from the sprite outwards, then the ink at index `rings`.
uniform vec4 bands[4];

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	int margin = clamp(rings, 1, 3) + 1;
	ivec2 grid = size + ivec2(2 * margin);
	ivec2 texel = ivec2(floor(UV * vec2(grid))) - ivec2(margin);
	int best = margin + 1;
	for (int dy = -4; dy <= 4; dy++) {
		for (int dx = -4; dx <= 4; dx++) {
			int steps = abs(dx) + abs(dy);
			if (steps > margin || steps >= best) {
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
	if (best == 0 || best > margin) {
		discard;
	}
	COLOR = bands[best - 1] * modulate;
}
