// The sharp-pixel material, greyed (#71, mock-up h1, H1_BUILD_SPEC.md sections 4.4 and 3.6):
// pixel_art.gdshader's sampling, then the mock-up's CSS filter in its order: grayscale(1)
// (Rec. 709 luminance), brightness, contrast about the middle grey. A denied item's sprite uses
// ArtStyle.Grey.DENIED, a drained sticker ArtStyle.Grey.DRAINED (ArtStyle.grey_material). The
// node's modulate still applies, as in pixel_art.gdshader. `saturation` keeps that much of the
// colour (CSS saturate(): 0 is grayscale(1), the greys' default; the mix highlight's calm grey,
// #105 piece 3, ArtStyle.set_mix_grey, keeps 0.2).
shader_type canvas_item;

uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 0.0;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = UV * size;
	vec2 seam = floor(texel + 0.5);
	texel = seam + clamp((texel - seam) / fwidth(texel), -0.5, 0.5);
	vec4 colour = texture(TEXTURE, texel / size);
	float grey = dot(colour.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 shown = mix(vec3(grey), colour.rgb, saturation) * brightness;
	shown = clamp((shown - 0.5) * contrast + 0.5, 0.0, 1.0);
	COLOR = vec4(shown, colour.a) * modulate;
}
