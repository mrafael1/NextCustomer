class_name CardFoil
extends ColorRect
## A prize card's rarity look (v0.97, the user's picks of 2026-11-04 on
## docs/art/mockups/card_rarity.html; spec in card_rarity_B.html and card_rarity_C.html): the
## card itself changes per rarity, on V3's 72x122 art px card (PrizeTicket.SIZE), its name band,
## chips, pips and win sticker kept where V3 put them.
## - COMMON, look C "store promo": a shelf label on receipt paper. An ink edge with a torn foot
##   (a 0-1-2-1 art px zigzag, period 4) and a perforation dot every 3 px over it, a cream edge,
##   plain paper; the art window carries a printed barcode in the kind's dark (in the corner the
##   art's own chip leaves free); the tab is a flat cream COMMON label (RarityTab).
## - RARE, look B "foil": a teal holo laminate. Ink, a teal and a bright teal line, then paper;
##   dithered diagonal foil stripes (16 art px apart, a 2 px core, 1 px dithered edges) run through
##   the frame, the art window (the kind's ramp) and the name band (cores only, under the name),
##   and slide (STRIPE_RATE art px a second, three times as fast while hovered) and cycle their
##   colours every CYCLE_S.
## - LEGENDARY, look B "foil": gold foil. A gold bevel frame and a PLATE header plate under the
##   tab (the art window starts that much lower), gold stripes through them, gold-fleck paper
##   inside an ink line, a 16-ray sunburst in the window turning a step every RAY_STEP_S, gold
##   stripe cores over the band, gold corner brackets round the rule and the art breaking out of
##   its window over the plate (PrizeArt.break_out: an ink outline on what pokes out).
## RARE and LEGENDARY also send a dithered sweep across the whole card face (on landing, then
## every few seconds: TicketRim.sheen_at; one every HOVER_SWEEP_S while hovered). Under reduced
## motion the stripes hold one phase, the colours and the rays stand still and no sweep crosses.
## The stock (frame, paper, flecks, barcode, band) is drawn once (draw_stock, on the ticket's
## card layer); the stripes, the rays and the sweep are this node, a ColorRect over the whole
## card under its art and its words, drawn by presentation/card_foil.gdshader from palette colours
## passed in (no per-frame allocation: frame() only sets its numbers).
## The rarity comes from look_of (the prize's own rarity today). A LEGENDARY card's gold stays
## apart from a GOLDEN item: the gold sits in the frame and plate, the window keeps the kind's
## colour, and a GOLDEN sprite on it wears a 1 art px ink outline all round (PrizeArt.break_out).

const SHADER := preload("res://presentation/card_foil.gdshader")
## The legendary header plate (canvas px; 9 art px) under the tab.
const PLATE := 18.0
## The card in art px.
const CARD_ART := Vector2i(72, 122)
const STRIPE_RATE: Array[float] = [0.0, 6.0, 8.0]
const HOVER_RATE := 3.0
const CYCLE_S := 0.35
const RAY_STEP_S := 0.25
const RAY_STEP := PI / 32.0
const HOVER_SWEEP_S := 1.2
## The stripes' phase under reduced motion (the mock-up's).
const STILL_PHASE := 5.0
## The legendary paper's gold flecks: one paper art pixel in FLECK_ONE (the mock-up's hash).
const FLECK_ONE := 53
## The common card's torn foot (art px per column, period 4) and its perforation.
const TEAR: Array[int] = [0, 1, 2, 1]
const PERFORATION_STEP := 3
const PERFORATION_UP := 6
## The rare frame's stripes (teal pale and paper) and the legendary gold ramp (the frame's and the
## plate's).
const RARE_RING: Array[Color] = [Palette.TEAL_PALE, Palette.PAPER]
const GILT: Array[Color] = [Palette.MUSTARD_LIGHT, Palette.MUSTARD_PALE, Palette.GOLD]
## The barcode's bars (art px columns) and height.
const BARCODE: Array[int] = [1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1]
const BARCODE_HEIGHT := 5
## The legendary rule's corner brackets: an arm's length (art px).
const BRACKET := 3

var rarity: int = 0
var kind: MachinePrize.Kind = MachinePrize.Kind.PRODUCT
var _look: ShaderMaterial
var _phase: float = 0.0
var _last_idle: float = -1.0
var _hover_from: float = -1.0


func _init(shown_rarity: int, shown_kind: MachinePrize.Kind) -> void:
	rarity = shown_rarity
	kind = shown_kind
	name = "Foil"
	color = Palette.PAPER.lightened(1.0)  # White: the shader paints the palette colours.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(CARD_ART) * MachineArt.PIXEL
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	material = _look
	_look.set_shader_parameter(&"card_px", Vector2(CARD_ART))
	visible = rarity != MachinePrize.Rarity.COMMON
	match rarity:
		MachinePrize.Rarity.RARE:
			_set_ring(Rect2(1, 1, 70, 120), Rect2(3, 3, 66, 116), RARE_RING)
			_set_colours(&"window", window_colours(kind, false))
			_set_rect(&"window_rect", art_window(rarity))
		MachinePrize.Rarity.LEGENDARY:
			_set_ring(Rect2(1, 1, 70, 120), legendary_paper(), GILT)
			_set_rect(&"window_rect", art_window(rarity))
			_look.set_shader_parameter(&"rays", true)
			_look.set_shader_parameter(&"ray_colour", ray_colour(kind))
			var window: Rect2 = art_window(rarity)
			_look.set_shader_parameter(&"ray_centre", Vector2(window.get_center().x, 28.0))
	_look.set_shader_parameter(&"sweep_cols", PackedColorArray(sweep_colours(rarity)))
	_look.set_shader_parameter(&"sweep_n", sweep_colours(rarity).size())


## The rarity a prize's card wears. Today the prize's own rarity (MachineDraw's). Every rarity cue
## reads it (PrizeTicket.look: the stock, foil, band, chips, tab, pips, glints and landing effects;
## the machine's landing timing and the pedestal strips through MachinePlan.set_draw), so mapping a
## PRODUCT's tier here (plain COMMON, BIG RARE, GOLDEN LEGENDARY, feature/tier-rarity) moves them
## all together. What the prize does stays on MachinePrize.rarity (an UPGRADES pick's words and the
## SHELF art).
static func look_of(shown: MachinePrize) -> int:
	return clampi(shown.rarity, MachinePrize.Rarity.COMMON, MachinePrize.Rarity.LEGENDARY)


## The art window in art px on the card: V3's (3, 3, 66, 50), less the plate on LEGENDARY.
static func art_window(card_rarity: int) -> Rect2:
	if card_rarity == MachinePrize.Rarity.LEGENDARY:
		return Rect2(3, 3 + PLATE / MachineArt.PIXEL, 66, 50 - PLATE / MachineArt.PIXEL)
	return Rect2(3, 3, 66, 50)


## The art window in canvas px on the card (PrizeTicket.ART_RECT, less the plate on LEGENDARY).
static func window_rect(card_rarity: int) -> Rect2:
	var art: Rect2 = art_window(card_rarity)
	return Rect2(art.position * MachineArt.PIXEL, art.size * MachineArt.PIXEL)


## The legendary paper inside its ink line (art px): under the plate, inside the bevel.
static func legendary_paper() -> Rect2:
	var top: float = 2.0 + PLATE / MachineArt.PIXEL
	return Rect2(2, top, CARD_ART.x - 4, CARD_ART.y - 3 - top)


## The rare window's stripe colours by kind (hovered: brighter, but a coupon's).
static func window_colours(shown_kind: MachinePrize.Kind, hovered: bool) -> Array[Color]:
	if hovered and shown_kind != MachinePrize.Kind.COUPON:
		return [Palette.PAPER, Palette.TEAL_PALE, Palette.PAPER]
	match shown_kind:
		MachinePrize.Kind.COUPON:
			return [Palette.PAPER, Palette.TEAL_LIGHT, Palette.TEAL_BRIGHT]
		MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE:
			return [Palette.TEAL_PALE, Palette.TEAL_LIGHT, Palette.PAPER]
	return [Palette.TEAL_PALE, Palette.TEAL_LIGHT, Palette.TEAL_PALE]


## The band's stripe cores by rarity and kind: teal on RARE, gold on LEGENDARY (dark gold behind a
## coupon's paper name); none on COMMON.
static func band_colours(card_rarity: int, shown_kind: MachinePrize.Kind) -> Array[Color]:
	var coupon: bool = shown_kind == MachinePrize.Kind.COUPON
	var mustard: bool = (
		shown_kind == MachinePrize.Kind.REGISTER or shown_kind == MachinePrize.Kind.UPGRADE
	)
	match card_rarity:
		MachinePrize.Rarity.RARE:
			if coupon:
				return [Palette.TEAL_BRIGHT, Palette.TEAL_SHADE]
			if mustard:
				return [Palette.TEAL_PALE, Palette.MUSTARD_LIGHT]
			return [Palette.TEAL_PALE, Palette.TEAL_LIGHT]
		MachinePrize.Rarity.LEGENDARY:
			if coupon:
				return [Palette.BRASS, Palette.MUSTARD_DARK]
			if mustard:
				return [Palette.MUSTARD_PALE, Palette.MUSTARD_LIGHT]
			return [Palette.MUSTARD_LIGHT, Palette.MUSTARD_PALE]
	return []


## The legendary sunburst's rays by kind.
static func ray_colour(shown_kind: MachinePrize.Kind) -> Color:
	match shown_kind:
		MachinePrize.Kind.COUPON:
			return Palette.TEAL_LIGHT
		MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE:
			return Palette.MUSTARD_LIGHT
	return Palette.CREAM_SHADE


## The sweep's run: teal and paper on RARE, the gold ramp on LEGENDARY.
static func sweep_colours(card_rarity: int) -> Array[Color]:
	if card_rarity == MachinePrize.Rarity.LEGENDARY:
		return [
			Palette.MUSTARD_LIGHT,
			Palette.GOLD,
			Palette.MUSTARD_PALE,
			Palette.PAPER,
			Palette.MUSTARD_PALE,
			Palette.GOLD,
			Palette.MUSTARD_LIGHT,
		]
	return [Palette.TEAL_PALE, Palette.PAPER, Palette.PAPER, Palette.TEAL_PALE]


## The art window's colour and its foot's, by kind (cream item, teal pale coupon, mustard pale
## upgrade or loyalty), then its dark (the common barcode's).
static func kind_colours(shown_kind: MachinePrize.Kind) -> Array[Color]:
	match shown_kind:
		MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE:
			return [Palette.MUSTARD_PALE, Palette.MUSTARD_LIGHT, Palette.MUSTARD]
		MachinePrize.Kind.COUPON:
			return [Palette.TEAL_PALE, Palette.TEAL_LIGHT, Palette.TEAL]
	return [Palette.CREAM, Palette.CREAM_SHADE, Palette.CREAM_DARKEST]


## The common barcode's rect (canvas px on the card): the window's bottom left, or its bottom right
## when the art's own chip takes that corner (`chip_left`).
static func barcode_rect(chip_left: bool) -> Rect2:
	var window: Rect2 = window_rect(MachinePrize.Rarity.COMMON)
	var p: float = MachineArt.PIXEL
	var bar_size: Vector2 = Vector2(BARCODE.size(), BARCODE_HEIGHT) * p
	var x: float = window.position.x + 2.0 * p
	if chip_left:
		x = window.end.x - 2.0 * p - bar_size.x
	return Rect2(Vector2(x, window.end.y - 7.0 * p), bar_size)


## Whether the legendary paper's art pixel (x, y) (art px on the card) is a gold fleck.
static func is_fleck(x: int, y: int) -> bool:
	var mixed: int = ((x * 73856093) ^ (y * 19349663)) & 0xFFFFFFFF
	return mixed % FLECK_ONE == 0


## The card's stock on `item` (the ticket's card layer, canvas px): its shadow, frame and paper by
## rarity, the art window in the kind's colour (a COMMON card's barcode in it), the band (`band`)
## in `band_colour` with its rarity's rules, and a LEGENDARY card's rule brackets.
static func draw_stock(
	item: CanvasItem,
	card_rarity: int,
	shown_kind: MachinePrize.Kind,
	band: Rect2,
	band_colour: Color,
	chip_left: bool
) -> void:
	var p: float = MachineArt.PIXEL
	var card: Vector2 = Vector2(CARD_ART) * p
	item.draw_rect(Rect2(Vector2(6, 6), card), Color(Palette.INK, 0.35))
	match card_rarity:
		MachinePrize.Rarity.COMMON:
			_draw_label_stock(item)
		MachinePrize.Rarity.RARE:
			var face: Rect2 = Rect2(Vector2.ZERO, card)
			item.draw_rect(face, Palette.INK)
			item.draw_rect(face.grow(-p), Palette.TEAL)
			item.draw_rect(face.grow(-2.0 * p), Palette.TEAL_BRIGHT)
			item.draw_rect(face.grow(-3.0 * p), Palette.PAPER)
		_:
			_draw_gold_stock(item)
	var colours: Array[Color] = kind_colours(shown_kind)
	var window: Rect2 = window_rect(card_rarity)
	item.draw_rect(window, colours[0])
	item.draw_rect(Rect2(window.position.x, window.end.y - p, window.size.x, p), colours[1])
	if card_rarity == MachinePrize.Rarity.COMMON:
		var bars: Rect2 = barcode_rect(chip_left)
		for bar: int in BARCODE.size():
			if BARCODE[bar] == 1:
				item.draw_rect(
					Rect2(bars.position + Vector2(bar * p, 0), Vector2(p, bars.size.y)), colours[2]
				)
	item.draw_rect(band, band_colour)
	if card_rarity == MachinePrize.Rarity.RARE:
		item.draw_rect(Rect2(band.position, Vector2(band.size.x, p)), Palette.TEAL_BRIGHT)
		item.draw_rect(Rect2(band.position.x, band.end.y - p, band.size.x, p), Palette.TEAL_BRIGHT)
	elif card_rarity == MachinePrize.Rarity.LEGENDARY:
		item.draw_rect(Rect2(band.position - Vector2(0, p), Vector2(band.size.x, p)), Palette.INK)
		item.draw_rect(Rect2(band.position, Vector2(band.size.x, p)), Palette.GOLD)
		item.draw_rect(Rect2(band.position.x, band.end.y - p, band.size.x, p), Palette.BRASS_DARK)
		_draw_brackets(item, band.end.y + 2.0 * p)


## The sweep's rect (art px on the card): the whole face inside the outline, as look B sweeps it
## (under the art and the words, which draw over the foil).
static func sweep_rect() -> Rect2:
	return Rect2(1, 1, CARD_ART.x - 2, CARD_ART.y - 2)


## Lays the band's stripes over `band` (canvas px on the card).
func set_band(band: Rect2) -> void:
	var p: float = MachineArt.PIXEL
	_set_rect(&"band_rect", Rect2(band.position / p, band.size / p))
	_set_colours(&"band", band_colours(rarity, kind))
	_set_rect(&"sweep_rect", sweep_rect())


## The foil at the machine's `idle` time, `since` seconds after its card landed (below 0: not yet;
## no sweep), on ticket `index`, `hovered` or not, under reduced motion (`rm`) or not.
func frame(idle: float, since: float, index: int, hovered: bool, rm: bool) -> void:
	if not visible:
		return
	if hovered and _hover_from < 0.0:
		_hover_from = idle
		if rarity == MachinePrize.Rarity.RARE:
			_set_colours(&"window", window_colours(kind, true))
	elif not hovered and _hover_from >= 0.0:
		_hover_from = -1.0
		if rarity == MachinePrize.Rarity.RARE:
			_set_colours(&"window", window_colours(kind, false))
	var step: float = idle - _last_idle if _last_idle >= 0.0 else 0.0
	_last_idle = idle
	_phase += maxf(step, 0.0) * STRIPE_RATE[rarity] * (HOVER_RATE if hovered else 1.0)
	_look.set_shader_parameter(&"phase", STILL_PHASE if rm else _phase)
	_look.set_shader_parameter(&"cycle", 0 if rm else int(floorf(idle / CYCLE_S)))
	_look.set_shader_parameter(&"ray_turn", 0.0 if rm else floorf(idle / RAY_STEP_S) * RAY_STEP)
	_look.set_shader_parameter(&"sweep_k", sweep_at(since, idle, index, hovered, rm))


## How far the sweep has crossed (0 .. 1; -1: none): TicketRim's sheen timing, or one every
## HOVER_SWEEP_S while hovered.
func sweep_at(since: float, idle: float, index: int, hovered: bool, rm: bool) -> float:
	if rm or since < 0.0:
		return -1.0
	if hovered and _hover_from >= 0.0 and since >= TicketRim.SHEEN_LAND_S:
		var k: float = fposmod(idle - _hover_from, HOVER_SWEEP_S) / TicketRim.SHEEN_S
		return k if k < 1.0 else -1.0
	return TicketRim.sheen_at(rarity, since, idle, rm, index)


## The shader's current numbers, for tests.
func parameter(parameter_name: StringName) -> Variant:
	return _look.get_shader_parameter(parameter_name)


func _set_ring(outer: Rect2, inner: Rect2, colours: Array[Color]) -> void:
	_set_rect(&"ring_outer", outer)
	_set_rect(&"ring_inner", inner)
	_set_colours(&"ring", colours)


func _set_rect(parameter_name: StringName, rect: Rect2) -> void:
	_look.set_shader_parameter(
		parameter_name, Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	)


## Region `region`'s stripe colours (`<region>_cols`, padded to 3) and their count (`<region>_n`).
func _set_colours(region: StringName, colours: Array[Color]) -> void:
	var padded: PackedColorArray = PackedColorArray(colours)
	while padded.size() < 3:
		padded.append(Color(Palette.INK, 0.0))
	_look.set_shader_parameter(StringName("%s_cols" % region), padded)
	_look.set_shader_parameter(StringName("%s_n" % region), colours.size())


## COMMON's shelf label: an ink edge torn at the foot, a cream edge, paper, the perforation.
static func _draw_label_stock(item: CanvasItem) -> void:
	var p: float = MachineArt.PIXEL
	var w: int = CARD_ART.x
	var h: int = CARD_ART.y
	for x: int in range(w):
		var tear: int = TEAR[x % TEAR.size()]
		item.draw_rect(Rect2(x * p, 0, p, (h - tear) * p), Palette.INK)
		if x >= 1 and x < w - 1:
			item.draw_rect(Rect2(x * p, p, p, (h - 2 - tear) * p), Palette.CREAM_DARKEST)
		if x >= 2 and x < w - 2:
			item.draw_rect(Rect2(x * p, 2.0 * p, p, (h - 3 - tear) * p), Palette.PAPER)
	var x_dot: int = 4
	while x_dot < w - 4:
		item.draw_rect(
			Rect2(Vector2(x_dot, h - PERFORATION_UP) * p, Vector2(p, p)), Palette.CREAM_SHADE
		)
		x_dot += PERFORATION_STEP


## LEGENDARY's gold foil stock: ink, a mustard bevel (gold top left, brass dark bottom right), the
## plate's brass lip, an ink line round the paper and the paper's gold flecks.
static func _draw_gold_stock(item: CanvasItem) -> void:
	var p: float = MachineArt.PIXEL
	var w: float = CARD_ART.x
	var h: float = CARD_ART.y
	var face: Rect2 = Rect2(Vector2.ZERO, Vector2(w, h) * p)
	item.draw_rect(face, Palette.INK)
	item.draw_rect(face.grow(-p), Palette.MUSTARD)
	item.draw_rect(Rect2(p, p, (w - 2) * p, p), Palette.GOLD)
	item.draw_rect(Rect2(p, p, p, (h - 2) * p), Palette.GOLD)
	item.draw_rect(Rect2(p, (h - 2) * p, (w - 2) * p, p), Palette.BRASS_DARK)
	item.draw_rect(Rect2((w - 2) * p, p, p, (h - 2) * p), Palette.BRASS_DARK)
	var paper: Rect2 = legendary_paper()
	var lined: Rect2 = Rect2(paper.position * p, paper.size * p)
	item.draw_rect(Rect2(3.0 * p, lined.position.y - p, (w - 6) * p, p), Palette.BRASS_DARK)
	item.draw_rect(lined, Palette.INK)
	var inside: Rect2 = lined.grow(-p)
	item.draw_rect(inside, Palette.PAPER)
	for y: int in range(int(paper.position.y) + 1, int(paper.end.y) - 1):
		for x: int in range(int(paper.position.x) + 1, int(paper.end.x) - 1):
			if is_fleck(x, y):
				item.draw_rect(Rect2(Vector2(x, y) * p, Vector2(p, p)), Palette.MUSTARD_LIGHT)


## The legendary rule's four gold corner brackets, the top two at `top` (canvas px).
static func _draw_brackets(item: CanvasItem, top: float) -> void:
	var p: float = MachineArt.PIXEL
	var arm: float = BRACKET * p
	var left: float = 4.0 * p
	var right: float = (CARD_ART.x - 5) * p
	var bottom: float = (CARD_ART.y - 5) * p
	for corner: Vector2 in [
		Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)
	]:
		var flip_x: bool = corner.x > left
		var flip_y: bool = corner.y > top
		var bar_x: float = corner.x - (arm - p if flip_x else 0.0)
		var bar_y: float = corner.y - (arm - p if flip_y else 0.0)
		item.draw_rect(Rect2(bar_x, corner.y, arm, p), Palette.MUSTARD)
		item.draw_rect(Rect2(corner.x, bar_y, p, arm), Palette.MUSTARD)
