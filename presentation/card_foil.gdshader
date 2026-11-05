// A prize card's foil (v0.99, the user's picks of 2026-11-04 on
// docs/art/mockups/card_rarity.html: look B "foil" for RARE and LEGENDARY, mock-up
// card_rarity_B.html), drawn on a ColorRect over the whole card, under its art and its words
// (CardFoil). Everything is hard art pixels (`art_px` canvas px each, from the rect's UV): no
// blending, no blur, only palette colours passed in.
// - Stripes: diagonal "/" lines in card coordinates (so they run on across the frame, the window
//   and the band), `period` art px apart, a 2 px core and a dithered 1 px edge each side (the
//   band shows the cores only); stripe n takes colour (n + cycle) of its region's list, so the
//   laminate shimmers in place, and `phase` slides them along.
// - The regions: the frame ring (ring_outer less ring_inner), the art window (stripes, or the
//   LEGENDARY sunburst: 32 sectors, every other one lit, dithered past `ray_radius`, turned by
//   `ray_turn`), the name band.
// - The sweep: one diagonal run of sweep_cols crossing sweep_rect at sweep_k (0 .. 1; below 0:
//   none), its outer lines dithered.
// Rects are art px (x, y, w, h) in the card. The node's modulate still applies.
shader_type canvas_item;

uniform vec2 card_px = vec2(72.0, 122.0);
uniform int period = 16;
uniform float phase = 0.0;
uniform int cycle = 0;
uniform vec4 ring_outer = vec4(0.0);
uniform vec4 ring_inner = vec4(0.0);
uniform vec4 ring_cols[3];
uniform int ring_n = 0;
uniform vec4 window_rect = vec4(0.0);
uniform vec4 window_cols[3];
uniform int window_n = 0;
uniform bool rays = false;
uniform vec4 ray_colour = vec4(0.0);
uniform vec2 ray_centre = vec2(0.0);
uniform float ray_turn = 0.0;
uniform float ray_radius = 18.0;
uniform vec4 band_rect = vec4(0.0);
uniform vec4 band_cols[3];
uniform int band_n = 0;
uniform float sweep_k = -1.0;
uniform vec4 sweep_rect = vec4(0.0);
uniform vec4 sweep_cols[7];
uniform int sweep_n = 0;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

bool inside(ivec2 p, vec4 r) {
	return float(p.x) >= r.x && float(p.y) >= r.y && float(p.x) < r.x + r.z
		&& float(p.y) < r.y + r.w;
}

int wrap(int a, int n) {
	return ((a % n) + n) % n;
}

// The stripe index (before the cycle) art pixel `g` lies on, or -1 off the stripes.
int stripe(ivec2 g, bool core_only) {
	int u = g.x + g.y - int(floor(phase));
	int m = wrap(u, period);
	if (m > 3) {
		return -1;
	}
	bool core = m == 1 || m == 2;
	if (!core && (core_only || wrap(g.x, 2) == 1)) {
		return -1;
	}
	return int(floor(float(u) / float(period))) + cycle;
}

void fragment() {
	ivec2 g = ivec2(floor(UV * card_px));
	vec4 paint = vec4(0.0);
	if (ring_n > 0 && inside(g, ring_outer) && !inside(g, ring_inner)) {
		int s = stripe(g, false);
		if (s >= 0) {
			paint = ring_cols[wrap(s, ring_n)];
		}
	}
	if (inside(g, window_rect)) {
		if (rays) {
			vec2 d = vec2(g) + 0.5 - ray_centre;
			float a = atan(d.y, d.x) + ray_turn;
			int sector = int(floor(a / 6.2831853 * 32.0));
			bool far_off = length(d) > ray_radius && wrap(g.x + g.y, 2) == 1;
			if (wrap(sector, 2) == 0 && !far_off) {
				paint = ray_colour;
			}
		} else if (window_n > 0) {
			int s = stripe(g, false);
			if (s >= 0) {
				paint = window_cols[wrap(s, window_n)];
			}
		}
	}
	if (band_n > 0 && inside(g, band_rect)) {
		int s = stripe(g, true);
		if (s >= 0) {
			paint = band_cols[wrap(s, band_n)];
		}
	}
	if (sweep_k >= 0.0 && sweep_n > 0 && inside(g, sweep_rect)) {
		ivec2 r = g - ivec2(sweep_rect.xy);
		float span = sweep_rect.z + sweep_rect.w + float(sweep_n);
		int at = int(round(-float(sweep_n) + sweep_k * span));
		int c = r.x + r.y - at;
		bool edge = c == 0 || c == sweep_n - 1;
		if (c >= 0 && c < sweep_n && !(edge && wrap(r.x, 2) == 1)) {
			paint = sweep_cols[c];
		}
	}
	COLOR = paint * modulate;
}
