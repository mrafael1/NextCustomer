class_name BoosterCardDraw
extends RefCounted
## One booster card on YOUR STORE (v1.32, the mock-up's cardComp, drawCard and drawTab): a back
## (plain, the brass hit back, or used), or the face with its words, a RARE's moving foil and
## laminate, the sheen sweep and the white flash, squeezed for a flip (`sx`) and scaled for a pop.
## Everything is drawn through an ArtPen whose origin and unit map the card's own 76x128 art px
## onto the stage, so a flip squeezes its words too, as the mock-up's composited card.

enum Back { NONE, PLAIN, HIT, USED }

## The sheen band's dither colour (the mock-up's SHEEN_TILE).
const SHEEN := Color("fffbe6")
## The rule text's largest and smallest size (art px) and the step between them.
const RULE_SIZE_MAX := 7.4
const RULE_SIZE_MIN := 4.8
const RULE_SIZE_STEP := 0.2
const RULE_WEIGHT := 650

static var _rules: Dictionary[String, Array] = {}


## Draws `card` at art (`x`, `y`) with options `o`: back (Back), sx (flip, 0..1), scale, pop (px
## per side), sweep (0..1, <0: none), flash (1: white), hot (fast foil), still (no motion), now
## (the page clock, s).
static func draw(
	pen: ArtPen, card: CardDefinition, rare: bool, x: float, y: float, o: Dictionary = {}
) -> void:
	var sx: float = o.get("sx", 1.0)
	var sc: float = o.get("scale", 1.0)
	var pop: int = o.get("pop", 0)
	var w: float = maxf(1.0, roundf(BoosterArt.CW * sx * sc))
	var h: float = roundf(BoosterArt.CH * sc)
	var left: float = roundf(x) + floorf((BoosterArt.CW - w) / 2.0) - pop
	var top: float = roundf(y) + floorf((BoosterArt.CH - h) / 2.0) - pop
	var saved_origin: Vector2 = pen.origin
	var saved_unit: Vector2 = pen.unit
	pen.origin = pen.at(left, top)
	pen.unit = saved_unit * Vector2((w + pop * 2) / BoosterArt.CW, (h + pop * 2) / BoosterArt.CH)
	_draw_local(pen, card, rare, o)
	pen.origin = saved_origin
	pen.unit = saved_unit


static func _draw_local(pen: ArtPen, card: CardDefinition, rare: bool, o: Dictionary) -> void:
	var back: Back = o.get("back", Back.NONE)
	if back != Back.NONE:
		var texture: Texture2D = BoosterArt.CARD_BACK
		if back == Back.HIT:
			texture = BoosterArt.CARD_BACK_HIT
		elif back == Back.USED:
			texture = BoosterArt.CARD_BACK_USED
		pen.tex(texture, 0, 0)
		return
	var now: float = o.get("now", 0.0)
	var still: bool = o.get("still", false)
	var speed: float = 18.0 if o.get("hot", false) else 6.0
	var off: int = 5 if still else int(floorf(now * speed)) % 16
	if rare:
		var phase: int = 2 if still else int(floorf(now / 0.35)) % 3
		var foil: ImageTexture = BoosterArt.foil_tile(phase)
		var region: Rect2 = Rect2(posmod(-off, 16), 0, BoosterArt.CW, BoosterArt.CH)
		pen.canvas.draw_texture_rect_region(
			foil, Rect2(pen.at(0, 0), pen.size_of(BoosterArt.CW, BoosterArt.CH)), region
		)
	pen.tex(BoosterArt.face(card, rare), 0, 0)
	if rare:
		var win: Rect2i = BoosterArt.window_of(true)
		var lam: Rect2 = Rect2(
			posmod(win.position.x - off, 16), win.position.y, win.size.x, win.size.y
		)
		pen.canvas.draw_texture_rect_region(
			BoosterArt.laminate_tile(),
			Rect2(pen.at(win.position.x, win.position.y), pen.size_of(win.size.x, win.size.y)),
			lam
		)
	_words(pen, card, rare)
	var sweep: float = o.get("sweep", -1.0)
	if sweep >= 0.0 and sweep <= 1.0:
		var band_x: float = roundf(lerpf(-30, BoosterArt.CW + 10, sweep))
		for row: int in BoosterArt.CH:
			var bx: float = band_x + floorf((BoosterArt.CH - row) / 3.0)
			pen.d(maxf(1, bx), row, maxf(0, minf(6, BoosterArt.CW - 1 - bx)), 1, SHEEN, 8)
	if o.get("flash", 0.0) > 0.5:
		pen.r(0, 0, BoosterArt.CW, BoosterArt.CH, Color.WHITE)


## The face's words: the name band's hard pixel lines and the rule in Atkinson, fitted to its room.
static func _words(pen: ArtPen, card: CardDefinition, rare: bool) -> void:
	var text: Dictionary = BoosterArt.face_text(card, rare)
	var win: Rect2i = text.window
	var coupon: bool = card.kind == CardDefinition.Kind.COUPON
	var lines: PackedStringArray = text.lines
	var centre: float = win.position.x + win.size.x / 2.0
	for k: int in lines.size():
		pen.pix(
			lines[k],
			centre,
			(text.band_y as int) + 3 + k * 9,
			Palette.PAPER if coupon else Palette.INK,
			1.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	var fit: Array = rule_fit(
		card, win.size.x - 4, (text.rule_bottom as int) - (text.rule_top as int)
	)
	if fit.is_empty():
		return
	var size: float = fit[0]
	var rule_lines: PackedStringArray = fit[1]
	var block: float = rule_lines.size() * (size + 0.9)
	var room: float = (text.rule_bottom as int) - (text.rule_top as int)
	var ry: float = (text.rule_top as int) + maxf(0.0, (room - block) / 2.6)
	for k: int in rule_lines.size():
		pen.atk(
			rule_lines[k],
			centre,
			ry + size * 0.9 + k * (size + 0.9),
			size,
			Palette.INK,
			RULE_WEIGHT
		)


## The rule's size (art px) and its lines in `max_w` art px, shrunk until they fit `room` (cached
## per card): the mock-up's fit loop. Empty for a card without rule text.
static func rule_fit(card: CardDefinition, max_w: float, room: float) -> Array:
	var key: String = "%s|%d|%d" % [card.id, roundi(max_w), roundi(room)]
	if _rules.has(key):
		return _rules[key]
	var rule: String = card.rule_text.strip_edges().replace("\n", " ")
	if rule == "":
		_rules[key] = []
		return []
	var size: float = RULE_SIZE_MAX
	var lines: PackedStringArray = wrap_words(rule, size, max_w)
	while lines.size() * (size + 0.9) > room and size > RULE_SIZE_MIN:
		size -= RULE_SIZE_STEP
		lines = wrap_words(rule, size, max_w)
	_rules[key] = [size, lines]
	return _rules[key]


## Atkinson words of `size` art px wrapped to `max_w` art px (measured at the stage's 2 px).
static func wrap_words(text: String, size: float, max_w: float) -> PackedStringArray:
	var font: Font = ArtStyle.bold_font(RULE_WEIGHT)
	var font_size: int = maxi(1, roundi(size * ArtPen.UNIT))
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in text.split(" ", false):
		var trial: String = word if line == "" else line + " " + word
		var width: float = (
			font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / ArtPen.UNIT
		)
		if width > max_w and line != "":
			lines.append(line)
			line = word
		else:
			line = trial
	if line != "":
		lines.append(line)
	return lines


## The COMMON / RARE! tab over a landed card, centred on `cx` at `y`, `sc` times its size.
static func tab(pen: ArtPen, rare: bool, cx: float, y: float, sc: float = 1.0) -> void:
	var label: String = "RARE!" if rare else "COMMON"
	var tw: float = ArtPen.pix_width(label) + (16 if rare else 13)
	var th: float = 11.0
	var w: float = roundf(tw * sc)
	var h: float = roundf(th * sc)
	var saved_origin: Vector2 = pen.origin
	var saved_unit: Vector2 = pen.unit
	pen.origin = pen.at(roundf(cx - w / 2.0), roundf(y - h / 2.0))
	pen.unit = saved_unit * Vector2(w / tw, h / th)
	pen.rn(0, 0, tw, th, Palette.TEAL if rare else Palette.CREAM)
	pen.r(1, 1, tw - 2, 1, Palette.TEAL_LIGHT if rare else Palette.PAPER)
	pen.r(1, th - 2, tw - 2, 1, Palette.TEAL_SHADE if rare else Palette.CREAM_SHADE)
	if rare:
		for px: float in [3.0, tw - 6]:
			pen.r(px + 1, 3, 1, 1, Palette.PAPER)
			pen.r(px, 4, 3, 1, Palette.PAPER)
			pen.r(px + 1, 5, 1, 1, Palette.PAPER)
		pen.pix(label, tw / 2.0, 3, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		pen.r(4, 4, 2, 2, Palette.GREY)
		pen.pix(label, tw / 2.0 + 2, 3, Palette.INK, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.origin = saved_origin
	pen.unit = saved_unit


## The RARE's teal sunburst centred on (`cx`, `cy`) at `s` of its full 62x82 radii.
static func sun(pen: ArtPen, cx: float, cy: float, s: float) -> void:
	if s <= 0.0:
		return
	var burst: ImageTexture = BoosterArt.sunburst(roundi(62 * s), roundi(82 * s))
	pen.tex(
		burst,
		roundf(cx - (burst.get_width() - 1) / 2.0),
		roundf(cy - (burst.get_height() - 1) / 2.0)
	)
