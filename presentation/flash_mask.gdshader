shader_type canvas_item;
// A white flash masked to a sprite (#77 machine v2, the upgrade swapping in place): the texture's
// alpha, sampled with the art's sharp pixels (as pixel_art.gdshader), painted in `flash_colour`;
// the node's modulate alpha fades it.

uniform vec4 flash_colour : source_color = vec4(1.0, 0.984, 0.91, 1.0);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = UV * size;
	vec2 seam = floor(texel + 0.5);
	texel = seam + clamp((texel - seam) / fwidth(texel), -0.5, 0.5);
	float alpha = texture(TEXTURE, texel / size).a;
	COLOR = vec4(flash_colour.rgb, alpha * modulate.a);
}
