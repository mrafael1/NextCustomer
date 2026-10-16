// Sharp pixels for the pixel art (full build plan section 6.1): every art pixel keeps hard
// edges at any scale or rotation, and only the one-screen-pixel seam between two art pixels is
// blended, so a rotating or scaling card doesn't shimmer. Needs linear texture filtering (the
// project default). The node's modulate still applies: the vertex colour (modulate) is passed
// through, because the fragment's COLOR already holds the texture sampled at UV, and multiplying
// the sharp sample by it would square every colour (the art rendered about gamma 2.2 too dark).
shader_type canvas_item;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = UV * size;
	vec2 seam = floor(texel + 0.5);
	texel = seam + clamp((texel - seam) / fwidth(texel), -0.5, 0.5);
	COLOR = texture(TEXTURE, texel / size) * modulate;
}
