class_name BoosterArt
extends RefCounted
## YOUR STORE's booster art and geometry (v1.32, mock-up docs/art/mockups/start_boosters_v3.html):
## the art grid's places (640x360 art px, 2 stage px each), the sprites (art/start: pouches, torn
## strips, card backs, the STOCKED! stamp), each aisle's ramp, and the card faces painted once
## per card in code from the mock-up's paintFace (the CardFoil looks: COMMON a store promo on
## receipt paper, RARE a teal holo laminate), their words drawn live (BoosterCardDraw).

## A face's rarity look (face_sized): the booster's COMMON and RARE, and the cart's LEGENDARY.
enum Look { COMMON, RARE, LEGENDARY }

## The counter sits DY art px lower than v2's (the mock-up's F7), so the cards are 76x128.
const DY := 40
const AW := 640
const AH := 360
## A card and a booster pouch, in art px.
const CW := 76
const CH := 128
const BW := 84
const BH := 112
## The booster zones on the counter: two aisle boosters (A, B), three while picking 2 of 3.
const ZONE_A := 277
const ZONE_B := 514
const PICK_X: Array[int] = [222, 396, 570]
## Three art px between two cards of a fan.
const FAN_STEP := CW + 3
## The pouch's top on the counter, the counter's top row, the lamp's top and its cone's top.
const POUCH_Y := 120 + DY
const COUNTER_Y := 229 + DY
const LAMP_TOP := 49
const CONE_TOP := 68
## The crate's regulars: x of regular `slot` is REG_X + slot * REG_STEP, their top REG_Y.
const REG_X := 8
const REG_STEP := 34
const REG_Y := 168 + DY
## The floor row: the TITLE plate, the hint LED, the primary plate (art px).
const TITLE_RECT := Rect2i(8, 323, 72, 26)
const HINT_RECT := Rect2i(120, 326, 360, 18)
const PRIMARY_RECT := Rect2i(528, 322, 104, 28)
## The RESTOCK key on the floor row (v1.32 feedback): KEY_GAP art px left of the primary key, as
## tall as it, its width from its refresh glyph and label; the hint LED shrinks to HINT_MARGIN
## art px either side between TITLE and the key while the key shows.
const KEY_GAP := 8
const HINT_MARGIN := 16
## The returns tote's bay in the counter front, centred between the two aisle places.
const BAY_RECT := Rect2i(358, 239 + DY, 76, 24)
## The refresh glyph (two arrows in a loop, 9x9 art px, one px each) the RESTOCK key wears; its
## quarter turn (refresh_glyph(true)) alternates with it while RESTOCK is armed.
const REFRESH_GLYPH: Array[String] = [
	"..####.#.",
	".#....##.",
	"#....###.",
	"#........",
	"#.......#",
	"........#",
	".###....#",
	".##....#.",
	".#.####..",
]
## The STOCKED! stamp's centre, hung under the YOUR STORE board.
const STOCKED_CENTRE := Vector2i(396, 77)
## The unlit pouch's flat modulate (the mock-up's #7e8e8c multiply).
const UNLIT := Color("7e8e8c")
## A COMMON face's tan name band and frame line (the mock-up's tan and tan dark).
const TAN := Color("e6d8b4")
const TAN_DARK := Color("c9b78d")

const CARD_BACK := preload("res://art/start/card_back.png")
const CARD_BACK_HIT := preload("res://art/start/card_back_hit.png")
const CARD_BACK_USED := preload("res://art/start/card_back_used.png")
const STOCKED := preload("res://art/start/stocked_stamp.png")
const LAMP := preload("res://art/scenery/ceiling_lamp.png")
const WALL_CLOCK := preload("res://art/scenery/wall_clock.png")
const SPARKLE := preload("res://art/effects/sparkle.png")
const TICK := preload("res://art/icons/tick_marker.png")
const PADLOCK := preload("res://art/icons/padlock_dim.png")
const PRICE_TAG := preload("res://art/icons/price_tag_mini.png")
const SWAP := preload("res://art/icons/swap_arrows.png")
const UNDO := preload("res://art/icons/redraw_arrow.png")
const CART := preload("res://art/icons/cart.png")
const CLOCK := preload("res://art/icons/clock.png")
const BUTTON := preload("res://art/frames/button.png")
const BUTTON_LIT := preload("res://art/frames/button_lit.png")
const BUTTON_TEAL := preload("res://art/frames/button_teal.png")
const LED := preload("res://art/frames/led_panel.png")
const COIN_LED := preload("res://art/frames/coin_led.png")
const KEY := preload("res://art/frames/key_cream.png")
const KEY_LIT := preload("res://art/frames/key_cream_lit.png")
const KEY_OFF := preload("res://art/frames/key_cream_off.png")
const KEY_BRASS := preload("res://art/frames/key_payday_lit.png")
const BUTTON_TEAL_LIT := preload("res://art/frames/button_teal_lit.png")
const PLATE := preload("res://art/frames/toy_plate.png")
const PLATE_LIT := preload("res://art/frames/toy_plate_lit.png")
const PLATE_OFF := preload("res://art/frames/toy_plate_off.png")
const POPUP := preload("res://art/frames/popup.png")
const RECEIPT := preload("res://art/frames/receipt_paper.png")
const TAB := preload("res://art/frames/handbook_tab.png")
const TAB_PICKED := preload("res://art/frames/handbook_tab_picked.png")
const POUCHES: Dictionary[StringName, Texture2D] = {
	&"bakery": preload("res://art/start/booster_pouch_bakery.png"),
	&"cold_cases": preload("res://art/start/booster_pouch_cold_cases.png"),
	&"fruit_and_veg": preload("res://art/start/booster_pouch_fruit_and_veg.png"),
	&"household": preload("res://art/start/booster_pouch_household.png"),
	&"pantry": preload("res://art/start/booster_pouch_pantry.png"),
	&"snacks": preload("res://art/start/booster_pouch_snacks.png"),
}
const STRIPS: Dictionary[StringName, Texture2D] = {
	&"bakery": preload("res://art/start/booster_strip_bakery.png"),
	&"cold_cases": preload("res://art/start/booster_strip_cold_cases.png"),
	&"fruit_and_veg": preload("res://art/start/booster_strip_fruit_and_veg.png"),
	&"household": preload("res://art/start/booster_strip_household.png"),
	&"pantry": preload("res://art/start/booster_strip_pantry.png"),
	&"snacks": preload("res://art/start/booster_strip_snacks.png"),
}
const SIGN_PATH := "res://art/frames/aisle_sign_%s.png"
## The aisles whose sign is light, so its words are ink (the rest cream).
const LIGHT_SIGNS: Array[StringName] = [&"pantry", &"bakery", &"household"]

static var _faces: Dictionary[String, ImageTexture] = {}
static var _suns: Dictionary[Vector2i, ImageTexture] = {}
static var _foils: Array[ImageTexture] = []
static var _laminate: ImageTexture


## Each aisle's 4-step ramp (light, base, shade, dark), sampled from its sign (the mock-up's RAMP).
static func ramp(aisle_id: StringName) -> Array[Color]:
	match aisle_id:
		&"household":
			return [Palette.GREY_LIGHT, Palette.GREY, Palette.GREY_DARK, Palette.INK_LIGHT]
		&"pantry":
			return [
				Palette.MUSTARD_LIGHT,
				Palette.MUSTARD,
				Palette.MUSTARD_DARK,
				Palette.MUSTARD_DARKEST
			]
		&"bakery":
			return [Palette.CREAM_SHADE, Palette.BROWN_LIGHT, Palette.BROWN, Palette.BROWN_DARK]
		&"fruit_and_veg":
			return [Palette.GREEN_LIGHT, Palette.GOOD, Palette.GREEN_DARK, Palette.BACKGROUND]
		&"snacks":
			return [Palette.BROWN, Palette.BROWN_DARK, Palette.BROWN_DARKEST, Palette.WOOD_DARKEST]
	return [Palette.TEAL_LIGHT, Palette.TEAL, Palette.TEAL_SHADE, Palette.TEAL_DARK]


static func short_name(aisle: AisleDefinition) -> String:
	return aisle.display_name.to_upper() if aisle != null else ""


static func pouch(aisle_id: StringName) -> Texture2D:
	return POUCHES.get(aisle_id, POUCHES[&"cold_cases"])


static func strip(aisle_id: StringName) -> Texture2D:
	return STRIPS.get(aisle_id, STRIPS[&"cold_cases"])


static func sign_frame(aisle_id: StringName) -> Texture2D:
	var path: String = SIGN_PATH % aisle_id
	return (
		load(path) as Texture2D
		if ResourceLoader.exists(path)
		else load("res://art/frames/aisle_sign.png")
	)


static func glyph(aisle_id: StringName) -> Texture2D:
	var path: String = "res://art/icons/aisle_%s.png" % aisle_id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Card k of a fan centred on booster centre `cx`: its top left (the middle card 2 px higher).
static func fan_pos(cx: float, k: int) -> Vector2:
	return Vector2(roundf(cx) - 117 + k * FAN_STEP, 144 + (0 if k == 1 else 2))


## A booster's pouch top left at centre `cx`.
static func pouch_pos(cx: float) -> Vector2:
	return Vector2(roundf(cx) - 42, POUCH_Y)


## The families whose chips a card face wears (at most two; the ticket's families).
static func families(card: CardDefinition) -> Array[FamilyStyle]:
	var found: Array[FamilyStyle] = []
	var shared: FamilyPalette = FamilyPalette.shared()
	for id: String in shared.ticket_families(card):
		var style: FamilyStyle = shared.style(id)
		if style != null and found.size() < 2:
			found.append(style)
	return found


## The art window of a face `cw` art px wide: (x, y, w, h) in card art px.
static func window_of(rare: bool, cw: int = CW) -> Rect2i:
	return Rect2i(5, 5, cw - 10, 48) if rare else Rect2i(3, 3, cw - 6, 50)


## A card face's static layer (the mock-up's paintFace without its words), painted once per card
## and rarity: frame, art window with the item, barcode (COMMON), pips, family chips, the price
## window, the BIG chip, the name band (its height from the name's lines), the perforation and
## the torn foot (COMMON). A RARE leaves its 3 px frame clear for the foil (BoosterCardDraw).
static func face(card: CardDefinition, rare: bool) -> ImageTexture:
	return face_sized(card, Look.RARE if rare else Look.COMMON, CW, rare)


## The face of `card` in `look`, `cw` art px wide (the cart's cards are wider: mock-up
## cart_cards.html's cart face), its BIG chip baked in when `big_chip` (the booster's RARE
## product; the cart draws its own tier sticker, CartCardDraw), its family chips baked in when
## `chips` (the cart draws its own, with their glyphs as tip targets: CartCardDraw.chip_families).
## A LEGENDARY face is a RARE's on gold-flecked paper with a mustard art window, a mustard name
## band and three brass pips; its frame is left clear for the gold foil. Cached per card, look,
## width, chip and chips.
static func face_sized(
	card: CardDefinition, look: Look, cw: int, big_chip: bool, chips: bool = true
) -> ImageTexture:
	var key: String = "%s|%d|%d|%s|%s" % [card.id, look, cw, big_chip, chips]
	if _faces.has(key):
		return _faces[key]
	var rare: bool = look != Look.COMMON
	var gold: bool = look == Look.LEGENDARY
	var image: Image = Image.create(cw, CH, false, Image.FORMAT_RGBA8)
	var coupon: bool = card.kind == CardDefinition.Kind.COUPON
	image.fill(Palette.INK)
	var win: Rect2i = window_of(rare, cw)
	if rare:
		image.fill_rect(Rect2i(1, 1, cw - 2, CH - 2), Color(0, 0, 0, 0))
		image.fill_rect(Rect2i(4, 4, cw - 8, CH - 8), Palette.INK)
		image.fill_rect(Rect2i(5, 5, cw - 10, CH - 10), Palette.PAPER)
		if gold:
			_dither(image, Rect2i(5, 5, cw - 10, CH - 10), Palette.MUSTARD_PALE, 8)
			_dither(
				image,
				Rect2i(5, win.end.y + 1, cw - 10, CH - win.end.y - 7),
				Palette.MUSTARD_LIGHT,
				2
			)
	else:
		image.fill_rect(Rect2i(1, 1, cw - 2, CH - 2), TAN_DARK)
		image.fill_rect(Rect2i(2, 2, cw - 4, CH - 4), Palette.PAPER)
	var window_fill: Color = Palette.CREAM
	if coupon:
		window_fill = Palette.TEAL_PALE
	elif gold:
		window_fill = Palette.MUSTARD_PALE
	image.fill_rect(win, window_fill)
	if not coupon:
		_dither(
			image,
			Rect2i(win.position.x, win.end.y - 10, win.size.x, 10),
			Palette.MUSTARD_LIGHT if gold else Palette.CREAM_SHADE,
			4
		)
	_paint_art(image, card, win, coupon)
	if not rare and not coupon:
		var bx: int = win.position.x + 3
		var widths: Array[int] = [1, 1, 2, 1, 1, 2, 1, 1, 1, 2, 1, 1]
		for k: int in widths.size():
			if k % 2 == 0:
				image.fill_rect(Rect2i(bx, win.end.y - 8, widths[k], 6), Palette.INK)
			bx += widths[k] + 1
	image.fill_rect(Rect2i(win.position.x, win.end.y, win.size.x, 1), Palette.INK)
	if rare:
		var pip: Color = Palette.BRASS_DARK if gold else Palette.TEAL
		for k: int in 3 if gold else 2:
			var px: int = win.position.x + 3 + k * 5
			var py: int = win.position.y + 3
			image.fill_rect(Rect2i(px + 1, py, 1, 1), pip)
			image.fill_rect(Rect2i(px, py + 1, 3, 1), pip)
			image.fill_rect(Rect2i(px + 1, py + 2, 1, 1), pip)
	else:
		image.fill_rect(Rect2i(win.position.x + 3, win.position.y + 3, 2, 2), Palette.GREY)
	var styles: Array[FamilyStyle] = []
	if chips:
		styles = families(card)
	for k: int in styles.size():
		var cx: int = win.position.x + 1
		var cy: int = win.position.y + 8 + k * 14
		image.fill_rect(Rect2i(cx, cy, 12, 12), Palette.INK)
		image.fill_rect(Rect2i(cx + 1, cy + 1, 10, 10), styles[k].face)
		image.fill_rect(Rect2i(cx + 1, cy + 1, 10, 1), styles[k].light)
		if styles[k].glyph != null:
			_blit(image, styles[k].glyph, Vector2i(cx + 2, cy + 2))
	if not coupon:
		var price: ImageTexture = ArtPen.word_texture("%d€" % card.base, Palette.INK, true)
		var w: int = price.get_width() + 5
		var px0: int = win.end.x - w - 1
		_notched(image, Rect2i(px0, win.position.y + 2, w, 12), Palette.PAPER)
		_blit(image, price, Vector2i(win.end.x - w + 2, win.position.y + 4))
	if big_chip and rare and not coupon:
		_notched(image, Rect2i(win.end.x - 18, win.end.y - 11, 17, 9), Palette.MUSTARD)
		_blit(
			image,
			ArtPen.word_texture("BIG", Palette.INK, false),
			Vector2i(win.end.x - 15, win.end.y - 9)
		)
	var lines: PackedStringArray = ArtPen.pix_wrap(card.display_name.to_upper(), win.size.x - 6)
	var band_h: int = 4 + lines.size() * 9
	var by: int = win.end.y + 1
	var band: Color = TAN
	if coupon:
		band = Palette.TEAL
	elif gold:
		band = Palette.MUSTARD_LIGHT
	image.fill_rect(Rect2i(win.position.x, by, win.size.x, band_h), band)
	image.fill_rect(
		Rect2i(win.position.x, by + band_h, win.size.x, 1),
		Palette.TEAL_SHADE if coupon else TAN_DARK
	)
	if not rare:
		var x: int = 4
		while x < cw - 4:
			image.set_pixel(x, CH - 7, Palette.CREAM_DARKEST)
			x += 2
		var foot: Array[int] = [0, 1, 2, 1]
		for fx: int in cw:
			var depth: int = foot[fx % 4]
			for dy: int in depth:
				image.set_pixel(fx, CH - 1 - dy, Color(0, 0, 0, 0))
			image.set_pixel(fx, CH - depth - 1, Palette.INK)
	_faces[key] = ImageTexture.create_from_image(image)
	return _faces[key]


## The name band's lines and the rule box (top, bottom) of a face `cw` art px wide, in card art
## px.
static func face_text(card: CardDefinition, rare: bool, cw: int = CW) -> Dictionary:
	var win: Rect2i = window_of(rare, cw)
	var lines: PackedStringArray = ArtPen.pix_wrap(card.display_name.to_upper(), win.size.x - 6)
	var band_h: int = 4 + lines.size() * 9
	var by: int = win.end.y + 1
	return {
		"lines": lines,
		"band_y": by,
		"rule_top": by + band_h + 3,
		"rule_bottom": CH - (6 if rare else 9),
		"window": win,
	}


static func _paint_art(image: Image, card: CardDefinition, win: Rect2i, coupon: bool) -> void:
	if coupon:
		var icon: Texture2D = ArtStyle.coupon_icon(card)
		if icon != null:
			var big: Image = _image(icon)
			big.resize(big.get_width() * 2, big.get_height() * 2, Image.INTERPOLATE_NEAREST)
			var at: Vector2i = Vector2i(
				win.position.x + floori((win.size.x - big.get_width()) / 2.0),
				win.position.y + floori((win.size.y - big.get_height()) / 2.0) + 2
			)
			image.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), at)
		return
	var sprite: Texture2D = ArtStyle.item_sprite(card)
	if sprite != null:
		_blit(
			image,
			sprite,
			Vector2i(win.position.x + floori((win.size.x - 48) / 2.0) + 3, win.position.y + 1)
		)


static func _image(texture: Texture2D) -> Image:
	var image: Image = texture.get_image().duplicate() as Image
	if image == null or image.is_empty():
		# No texture read-back (the headless test run): a clear image of the same size.
		return Image.create(texture.get_width(), texture.get_height(), false, Image.FORMAT_RGBA8)
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _blit(image: Image, texture: Texture2D, at: Vector2i) -> void:
	var source: Image = _image(texture)
	image.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), at)


static func _notched(image: Image, rect: Rect2i, fill: Color) -> void:
	image.fill_rect(
		Rect2i(rect.position.x + 1, rect.position.y, rect.size.x - 2, rect.size.y), Palette.INK
	)
	image.fill_rect(
		Rect2i(rect.position.x, rect.position.y + 1, rect.size.x, rect.size.y - 2), Palette.INK
	)
	image.fill_rect(rect.grow(-1), fill)


static func _dither(image: Image, rect: Rect2i, colour: Color, level: int) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if ArtPen.BAYER[(y % 4) * 4 + x % 4] < level:
				image.set_pixel(x, y, colour)


## The RARE's teal sunburst (16 sectors) of radii `rx` x `ry` art px, cached per size.
static func sunburst(rx: int, ry: int) -> ImageTexture:
	rx = maxi(4, rx)
	ry = maxi(4, ry)
	var key: Vector2i = Vector2i(rx, ry)
	if _suns.has(key):
		return _suns[key]
	var image: Image = Image.create(rx * 2 + 1, ry * 2 + 1, false, Image.FORMAT_RGBA8)
	for y: int in range(-ry, ry + 1):
		for x: int in range(-rx, rx + 1):
			var e: float = float(x * x) / (rx * rx) + float(y * y) / (ry * ry)
			if e > 1.0:
				continue
			var sector: int = int(floorf((atan2(y, x) + PI) / TAU * 16.0)) % 16
			if sector % 2 == 0:
				if e > 0.7 and posmod(x + y, 2) == 1:
					continue
				image.set_pixel(
					x + rx, y + ry, Palette.TEAL_PALE if e < 0.35 else Palette.TEAL_LIGHT
				)
			elif e < 0.25 and posmod(x + y, 2) == 0:
				image.set_pixel(x + rx, y + ry, Palette.TEAL_PALE)
	_suns[key] = ImageTexture.create_from_image(image)
	return _suns[key]


## The RARE foil's 16x16 tile in core colour `phase` (0..2: teal pale, paper, teal light): teal
## with a diagonal stripe (2 px core, 1 px dithered edges) every 16 px.
static func foil_tile(phase: int) -> ImageTexture:
	if _foils.is_empty():
		for core: Color in [Palette.TEAL_PALE, Palette.PAPER, Palette.TEAL_LIGHT]:
			var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			image.fill(Palette.TEAL)
			for y: int in 16:
				for x: int in 16:
					var dd: int = (x + y) % 16
					if dd < 2 or ((dd == 2 or dd == 15) and (x + y * 3) % 2 == 0):
						image.set_pixel(x, y, core)
			_foils.append(ImageTexture.create_from_image(image))
	return _foils[posmod(phase, 3)]


## The RARE laminate over the art window: a 16x16 tile of sparse white stripe dots.
static func laminate_tile() -> ImageTexture:
	if _laminate == null:
		var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y: int in 16:
			for x: int in 16:
				if (x + y) % 16 < 2 and (x + y) % 2 == 0:
					image.set_pixel(x, y, Color.WHITE)
		_laminate = ImageTexture.create_from_image(image)
	return _laminate


## The shelf zone (0: A, 1: B) under a booster centred on `cx`.
static func zone_of(cx: float) -> int:
	return 0 if cx < 396 else 1


## A sealed pouch's art rect at rest under centre `cx`.
static func pouch_rect(cx: float) -> Rect2:
	return Rect2(pouch_pos(cx), Vector2(BW, BH))


## Card k's art rect at rest in the fan under centre `cx`.
static func card_rect(cx: float, k: int) -> Rect2:
	return Rect2(fan_pos(cx, k), Vector2(CW, CH))


## A fan of `count` cards under centre `cx` (art px, with the 2 px drop of its side cards).
static func fan_rect(cx: float, count: int) -> Rect2:
	return Rect2(fan_pos(cx, 0), Vector2(FAN_STEP * (count - 1) + CW, CH + 2))


## The lamp's shade over centre `cx` (art px).
static func lamp_rect(cx: float) -> Rect2:
	return Rect2(roundf(cx) - 37, LAMP_TOP - 2, 74, 20)
