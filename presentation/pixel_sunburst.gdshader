// The monitor's pixel sunburst (#105 piece 2, mock-up readability_v3.html's sunURL): an ellipse of
// art_size art pixels (each `pixel` px), its 16 sectors alternating ray and gap colours about its
// centre, turned by `angle` (the disc turns as a whole, as the mock-up rotates its image). Outside
// the ellipse nothing is drawn. On a ColorRect as big as art_size x pixel (PixelSunburst).
shader_type canvas_item;

uniform vec2 art_size = vec2(50.0, 34.0);
uniform float angle = 0.0;
uniform vec4 ray_colour : source_color = vec4(0.945098, 0.823529, 0.478431, 1.0);
uniform vec4 gap_colour : source_color = vec4(0.980392, 0.925490, 0.737255, 1.0);

void fragment() {
	vec2 centre = art_size * 0.5;
	vec2 point = UV * art_size - centre;
	float c = cos(-angle);
	float s = sin(-angle);
	point = vec2(point.x * c - point.y * s, point.x * s + point.y * c);
	vec2 cell = floor(point + centre) + 0.5 - centre;
	vec2 unit = cell / centre;
	if (length(unit) > 1.0) {
		COLOR = vec4(0.0);
	} else {
		float a = atan(cell.y, cell.x * art_size.y / art_size.x);
		float sector = floor((a + PI) / (PI / 8.0));
		COLOR = mod(sector, 2.0) > 0.5 ? ray_colour : gap_colour;
	}
}
