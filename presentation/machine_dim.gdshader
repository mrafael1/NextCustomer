shader_type canvas_item;
// The idle RECEIPT REWARDS machine's desaturation (#77 machine v2, the approved page's
// saturate()): a veil over the machine that reads what is drawn under it (already dimmed by the
// machine's modulate) and mixes it towards its grey. Nearest sampling at the screen's own pixels,
// so the pixel art stays sharp.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 under = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float grey = dot(under, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(grey), under, saturation), 1.0);
}
