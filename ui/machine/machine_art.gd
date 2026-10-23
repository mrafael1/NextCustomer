class_name MachineArt
extends RefCounted
## The RECEIPT REWARDS machine's code-drawn shapes (v0.50, mock-up
## docs/art/mockups/premium_machine_v1.html): its R / box / ring / bevel / shine on the 2 px grid
## (one art pixel is PIXEL canvas px; every rect is in canvas px, on that grid), its easings, and
## the sparkle and coin sprites it scatters. The machine is drawn in code where the game already
## draws its machine in code; its new sprites (the sealed tickets, the +1 slot) are PNGs built from
## art/src.

## Canvas px per art pixel.
const PIXEL := 2.0
const SPARKLE := preload("res://art/effects/sparkle.png")
const COIN := preload("res://art/icons/coin.png")
## The mock-up's eBack overshoot.
const BACK_C := 1.9
## A coin's spin: its width in art px through the turn (the mock-up's coins()).
const COIN_WIDTHS: Array[float] = [12.0, 8.0, 4.0, 8.0]

static var _spaced: Dictionary[String, Font] = {}


## `t`'s progress from `a` to `b`, clamped to 0..1 (a step when b <= a).
static func seg(t: float, a: float, b: float) -> float:
	if b <= a:
		return 1.0 if t >= a else 0.0
	return clampf((t - a) / (b - a), 0.0, 1.0)


## Smoothstep.
static func smooth(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)


## The mock-up's eOut: cubic ease out.
static func ease_out(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)


## The mock-up's eInOut: cubic ease in and out.
static func ease_in_out(p: float) -> float:
	if p < 0.5:
		return 4.0 * p * p * p
	return 1.0 - pow(-2.0 * p + 2.0, 3.0) / 2.0


## The mock-up's eBack: 0 at 0, overshooting past 1, 1 at 1.
static func ease_back(p: float) -> float:
	return 1.0 + (BACK_C + 1.0) * pow(p - 1.0, 3.0) + BACK_C * pow(p - 1.0, 2.0)


## Snaps `value` to the 2 px grid.
static func snap(value: float) -> float:
	return roundf(value / PIXEL) * PIXEL


## Snaps a point to the 2 px grid.
static func snap_point(at: Vector2) -> Vector2:
	return Vector2(snap(at.x), snap(at.y))


## A box with a 1 art px `line` outline and notched corners, filled with `fill` (a clear colour:
## either left out).
static func box(item: CanvasItem, rect: Rect2, fill: Color, line: Color) -> void:
	var p: float = PIXEL
	if line.a > 0.0:
		item.draw_rect(
			Rect2(rect.position.x + p, rect.position.y, rect.size.x - 2.0 * p, rect.size.y), line
		)
		item.draw_rect(
			Rect2(rect.position.x, rect.position.y + p, rect.size.x, rect.size.y - 2.0 * p), line
		)
	if fill.a > 0.0:
		item.draw_rect(rect.grow(-p), fill)


## A `thickness` art px ring inside `rect`, its corners notched.
static func ring(item: CanvasItem, rect: Rect2, colour: Color, thickness: float = 1.0) -> void:
	var p: float = PIXEL
	var th: float = thickness * p
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	item.draw_rect(Rect2(x + p, y, w - 2.0 * p, th), colour)
	item.draw_rect(Rect2(x + p, y + h - th, w - 2.0 * p, th), colour)
	item.draw_rect(Rect2(x, y + p, th, h - 2.0 * p), colour)
	item.draw_rect(Rect2(x + w - th, y + p, th, h - 2.0 * p), colour)


## A box with a 1 art px highlight (`hi`, top and left) and shadow (`lo`, bottom and right).
static func bevel(
	item: CanvasItem, rect: Rect2, fill: Color, hi: Color, lo: Color, line: Color = Palette.INK
) -> void:
	var p: float = PIXEL
	box(item, rect, fill, line)
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	item.draw_rect(Rect2(x + p, y + p, w - 2.0 * p, p), hi)
	item.draw_rect(Rect2(x + p, y + p, p, h - 2.0 * p), hi)
	item.draw_rect(Rect2(x + p, y + h - 2.0 * p, w - 2.0 * p, p), lo)
	item.draw_rect(Rect2(x + w - 2.0 * p, y + p, p, h - 2.0 * p), lo)


## A hard diagonal shine band `band` art px wide across `rect` at `p` (0 .. 1: left of it .. past
## it; nothing outside 0 < p < 1), clipped to the rect.
static func shine(
	item: CanvasItem, rect: Rect2, p: float, colour: Color, band: float = 3.0
) -> void:
	if p <= 0.0 or p >= 1.0:
		return
	var h: float = rect.size.y
	var bw: float = band * PIXEL
	var sx: float = rect.position.x - h / 2.0 - bw + p * (rect.size.x + h / 2.0 + bw * 2.0)
	var j: float = 0.0
	while j < h:
		var x0: float = maxf(snap(sx + (h - j) / 2.0), rect.position.x)
		var x1: float = minf(snap(sx + (h - j) / 2.0) + bw, rect.end.x)
		if x1 > x0:
			item.draw_rect(Rect2(x0, rect.position.y + j, x1 - x0, minf(PIXEL, h - j)), colour)
		j += PIXEL


## The sparkle sprite centred on `centre`, `k` times its art size (at least 1) and `alpha` opaque.
static func sparkle(item: CanvasItem, centre: Vector2, k: float, alpha: float) -> void:
	if alpha <= 0.0 or k <= 0.0:
		return
	var side: Vector2 = SPARKLE.get_size() * maxf(1.0, roundf(k)) * PIXEL
	var at: Vector2 = snap_point(centre - side / 2.0)
	var tint: Color = Color(Palette.PAPER.lightened(1.0), clampf(alpha, 0.0, 1.0))  # White, faded.
	item.draw_texture_rect(SPARKLE, Rect2(at, side), false, tint)


## The mock-up's coin fountain `te` seconds after it fired, from `centre`: `count` coins on fixed
## paths (`path_seed`), spinning; `power` scales their throw; `floor_y` is where they leave the
## view.
static func coins(
	item: CanvasItem,
	centre: Vector2,
	te: float,
	count: int,
	path_seed: int,
	power: float,
	floor_y: float
) -> void:
	if te < 0.0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = path_seed
	for index: int in range(count):
		var vx: float = (rng.randf() - 0.5) * 440.0 * power
		var vy: float = -(220.0 + rng.randf() * 180.0) * power
		var tt: float = te - rng.randf() * 0.15
		if tt < 0.0:
			continue
		var at: Vector2 = centre + Vector2(vx * tt, vy * tt + 600.0 * tt * tt)
		if at.y > floor_y:
			continue
		var width: float = COIN_WIDTHS[int(floorf((tt * 9.0 + index) * 2.0)) % COIN_WIDTHS.size()]
		var rect: Rect2 = Rect2(snap_point(at - Vector2(width, 12.0)), Vector2(width, 12.0) * PIXEL)
		item.draw_texture_rect(COIN, rect, false)


## `font` with its glyphs `spacing` px apart (cached by font and spacing). A FontVariation's own
## (empty) coordinates replace its base's, so a variation `font` (a bold weight) is copied onto one
## variation of its base font rather than wrapped, or the result would draw at regular weight.
static func spaced(font: Font, spacing: int) -> Font:
	var key: String = "%d:%d" % [font.get_instance_id(), spacing]
	if not _spaced.has(key):
		var font_variation: FontVariation = FontVariation.new()
		var inner: FontVariation = font as FontVariation
		if inner != null:
			font_variation.base_font = inner.base_font
			font_variation.variation_opentype = inner.variation_opentype
			font_variation.variation_embolden = inner.variation_embolden
			font_variation.variation_transform = inner.variation_transform
		else:
			font_variation.base_font = font
		font_variation.spacing_glyph = spacing
		_spaced[key] = font_variation
	return _spaced[key]


## Draws `text` centred on `centre` (its middle line) in `font` at `font_size` in `colour`, with
## `shadow` (a clear colour: none) one art px under it.
static func centred_text(
	item: CanvasItem,
	text: String,
	centre: Vector2,
	font: Font,
	font_size: int,
	colour: Color,
	shadow: Color = Color(Palette.INK, 0.0)
) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var base: Vector2 = Vector2(
		roundf(centre.x - width / 2.0), roundf(centre.y + (ascent - descent) / 2.0)
	)
	if shadow.a > 0.0:
		item.draw_string(
			font, base + Vector2(0, PIXEL), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow
		)
	item.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


## `text`'s width in `font` at `font_size`.
static func text_width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
