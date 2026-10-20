shader_type canvas_item;
// The count view's sunburst (#86 v6 scan count-up, Sunburst): 2 x `rays` rays, alternately
// `ray_colour` and `gap_colour`, turned by `angle` about `centre` (px in the rect), inside an
// ellipse of `radius` (squashed by `squash` vertically); transparent outside it. Sampled on a
// `pixel` px grid so its edges step like the art's.

uniform vec2 rect_size = vec2(402.0, 154.0);
uniform vec2 centre = vec2(198.0, 60.0);
uniform float radius = 120.0;
uniform float squash = 1.15;
uniform float rays = 10.0;
uniform float angle = 0.0;
uniform float pixel = 2.0;
uniform vec4 ray_colour : source_color = vec4(1.0);
uniform vec4 gap_colour : source_color = vec4(1.0);

void fragment() {
	vec2 at = floor(UV * rect_size / pixel) * pixel + vec2(pixel * 0.5);
	vec2 offset = at - centre;
	offset.y *= squash;
	if (length(offset) > radius) {
		COLOR = vec4(0.0);
	} else {
		float turn = atan(offset.y, offset.x) + angle;
		float sector = mod(floor(turn / PI * rays + 100.0), 2.0);
		COLOR = sector > 0.5 ? ray_colour : gap_colour;
	}
}
