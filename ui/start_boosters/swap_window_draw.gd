class_name SwapWindowDraw
extends RefCounted
## Draws the swap window (SwapWindow) over YOUR STORE in art px, a port of the mock-up's
## drawSwapModal and drawSwapScene (docs/art/mockups/start_regulars_swap.html, variant A): the
## veil, the window's frame, its stock-room back wall, the two swap boosters (sealed, opening with
## page 1's own opening draw, their fans), the basket of regulars with its price tags and aisle
## chips, the drop targets of a held card, a refusal's tag, the SWAPS LEFT LED, RESET, the title
## tab, the close key, the hint LED and DONE; and the window's hit list (it is modal).

## The window (art px) and its keys.
const RECT := Rect2(14, 40, 612, 316)
const CLOSE_RECT := Rect2(604, 31, 17, 17)
const LED_RECT := Rect2(18, 226, 86, 46)
const RESET_RECT := Rect2(540, 236, 80, 24)
const HINT_RECT := Rect2(110, 326, 380, 18)
const DONE_RECT := Rect2(514, 322, 104, 28)
## The swap boosters' centres; page 1's fan and pouch places moved up SHIFT art px.
const BOOSTER_CX: Array[float] = [196.0, 444.0]
const SHIFT := -86
## The basket: the items' top, its back board, its front, its foot; its left and width.
const ITEM_TOP := 194
const BACK_Y := 214
const FRONT_Y := 262
const BASE_Y := 302
const BASKET_X := 104
const BASKET_W := 432
const SLOT_STEP := 106
const SLOT_X0 := 161
const PADLOCK := preload("res://art/icons/padlock.png")

static var _room: ImageTexture


## Basket slot `slot`'s centre x.
static func slot_cx(slot: int) -> float:
	return SLOT_X0 + slot * SLOT_STEP


## Basket slot `slot`'s drop target (drawn while a card is held, and hit-tested by slot_at).
static func slot_rect(slot: int) -> Rect2:
	return Rect2(slot_cx(slot) - 51, ITEM_TOP - 4, 102, BASE_Y - ITEM_TOP + 2)


## The basket slot under art point `at` (-1: none) among `count` slots: its drop target grown 2
## px each side, so the 4 px gaps between targets still take a drop.
static func slot_at(at: Vector2, count: int = 4) -> int:
	for slot: int in count:
		if slot_rect(slot).grow(2).has_point(at):
			return slot
	return -1


static func item_centre(slot: int) -> Vector2:
	return Vector2(slot_cx(slot), ITEM_TOP + 48)


## Swap booster `bi`'s fan card `k`'s centre.
static func fan_centre(bi: int, k: int) -> Vector2:
	var p: Vector2 = BoosterArt.fan_pos(BOOSTER_CX[bi], k)
	return p + Vector2(BoosterArt.CW / 2.0, SHIFT + BoosterArt.CH / 2.0)


static func pouch_pos(cx: float) -> Vector2:
	return BoosterArt.pouch_pos(cx) + Vector2(0, SHIFT)


## Draws window layer `layer` (SwapVeil, SwapFrame, Swap, SwapTop) of `page`.
static func draw(pen: ArtPen, page: BoosterPage, layer: String) -> void:
	var w: SwapWindow = page.swap
	if page.run == null or not w.visible():
		return
	match layer:
		"SwapVeil":
			pen.r(0, 28, BoosterArt.AW, BoosterArt.AH - 28, Color(Palette.INK, 0.62 * w.veil()))
		"SwapFrame":
			_frame(pen)
		"Swap":
			_scene(pen, page, w)
		"SwapTop":
			_top(pen, page, w)


static func _frame(pen: ArtPen) -> void:
	var r: Rect2 = RECT
	pen.r(r.position.x - 3, r.position.y - 3, r.size.x + 6, r.size.y + 6, Palette.INK)
	pen.r(r.position.x - 2, r.position.y - 2, r.size.x + 4, r.size.y + 4, Palette.TEAL_SHADE)
	pen.r(r.position.x - 2, r.position.y - 2, r.size.x + 4, 1, Palette.TEAL)
	pen.r(r.position.x - 2, r.position.y - 2, 1, r.size.y + 4, Palette.TEAL)
	pen.r(r.position.x, r.position.y, r.size.x, r.size.y, Palette.CREAM)


## The stock room behind the counter (the mock-up's paintRegBG), painted once.
static func room() -> ImageTexture:
	if _room != null:
		return _room
	var image: Image = Image.create(BoosterArt.AW, BoosterArt.AH, false, Image.FORMAT_RGBA8)
	var fill: Callable = func(x: int, y: int, w: int, h: int, c: Color) -> void:
		image.fill_rect(Rect2i(x, y, w, h), c)
	var dither: Callable = func(x: int, y: int, w: int, h: int, c: Color, level: int) -> void:
		for yy: int in range(y, y + h):
			for xx: int in range(x, x + w):
				if ArtPen.BAYER[(yy % 4) * 4 + xx % 4] < level:
					image.set_pixel(xx, yy, c)
	fill.call(0, 28, BoosterArt.AW, 16, Palette.CHARCOAL)
	dither.call(0, 28, BoosterArt.AW, 10, Palette.TEAL_BLACK, 8)
	fill.call(0, 38, BoosterArt.AW, 1, Palette.STEEL_DARKEST)
	fill.call(0, 39, BoosterArt.AW, 1, Palette.STEEL_DARK)
	fill.call(0, 40, BoosterArt.AW, 3, Palette.STEEL_DARKEST)
	fill.call(0, 40, BoosterArt.AW, 1, Palette.STEEL_SHADE)
	fill.call(0, 43, BoosterArt.AW, 1, Palette.INK)
	fill.call(0, 44, BoosterArt.AW, 256, Palette.TEAL_BLACK)
	dither.call(0, 44, BoosterArt.AW, 256, Palette.BACKGROUND, 4)
	for y: int in range(52, 296, 12):
		for x: int in range(6 + (int(y / 12.0) % 2) * 6, BoosterArt.AW, 12):
			fill.call(x, y, 1, 1, Palette.SLATE_DARK)
	var c0: int = BASE_Y
	fill.call(0, c0, BoosterArt.AW, 1, Palette.INK)
	fill.call(0, c0 + 1, BoosterArt.AW, 1, Palette.WOOD)
	fill.call(0, c0 + 2, BoosterArt.AW, 5, Palette.WOOD_DARK)
	fill.call(0, c0 + 7, BoosterArt.AW, 1, Palette.WOOD_DARKEST)
	fill.call(0, c0 + 8, BoosterArt.AW, BoosterArt.AH - c0 - 8, Palette.BROWN_DARKEST)
	for x: int in range(20, BoosterArt.AW, 40):
		fill.call(x, c0 + 10, 1, BoosterArt.AH - c0 - 12, Palette.WOOD_DARKEST)
		fill.call(x + 1, c0 + 10, 1, BoosterArt.AH - c0 - 12, Palette.WOOD_DARK)
	fill.call(0, c0 + 8, BoosterArt.AW, 2, Palette.WOOD_DARKEST)
	_room = ImageTexture.create_from_image(image)
	return _room


static func _scene(pen: ArtPen, page: BoosterPage, w: SwapWindow) -> void:
	pen.tex(room(), 0, 0)
	for bi: int in w.boosters.size():
		var b: BoosterOpening = w.boosters[bi]
		if b.state == BoosterOpening.State.SEALED:
			_sealed(pen, page, w, bi)
		elif b.state == BoosterOpening.State.OPENING:
			var saved: Vector2 = pen.origin
			pen.origin += Vector2(0, SHIFT * pen.unit.y)
			BoosterPageDraw.open_booster(pen, page, b, BACK_Y - SHIFT)
			BoosterPageDraw.tear(pen, page, b)
			pen.origin = saved
	var held: SwapPiece = w.held
	if held != null:
		var home: Dictionary = w.target(held)
		if not home.item:
			var at: Vector2 = home.pos
			dashes(
				pen,
				Rect2(
					at.x - BoosterArt.CW / 2.0,
					at.y - BoosterArt.CH / 2.0,
					BoosterArt.CW,
					BoosterArt.CH
				),
				Palette.TEAL_SHADE,
				0
			)
	for piece: SwapPiece in w.pieces:
		if piece == held or not _shown(w, piece) or piece.flying(page.now) or piece.item:
			continue
		var lift: float = 3.0 if held == null and _hovered(page, w, piece) else 0.0
		_card(pen, page, w, piece, {"pos": piece.pos, "sc": 1.0, "held": false}, lift)
	_basket_back(pen)
	for slot: int in page.run.starter.core_cards.size():
		var piece: SwapPiece = _in_slot(page, w, slot)
		if piece == null:
			continue
		var lift: float = 0.0
		var pu: float = page.now - w.pop_t[slot]
		if not page.rm and pu >= 0.0 and pu < 0.16:
			lift = roundf(sin(pu / 0.16 * PI) * 6)
		if (
			held != null
			and w.hover_slot == slot
			and not _home(w, held, slot)
			and w.drop_reason(held, slot) == ""
		):
			lift += 0.0 if page.rm else 4.0
		elif held == null and _hovered(page, w, piece) and not page.rm:
			lift += 2.0
		_item(pen, page, piece, piece.pos, lift)
	_basket_front(pen)
	for slot: int in page.run.starter.core_cards.size():
		_slot_tag(pen, page, slot)
	if held != null:
		_targets(pen, page, w, held)
	for piece: SwapPiece in w.pieces:
		if piece != held and _shown(w, piece) and piece.flying(page.now):
			var p: Dictionary = w.pose(piece)
			if p.item:
				_item(pen, page, piece, p.pos, 0.0)
			else:
				_card(pen, page, w, piece, p, 0.0)
	_refusal(pen, page, w)
	_led(pen, page, w)
	_reset_key(pen, page)


## Whether `piece` shows: a regular always, a card once its booster is open.
static func _shown(w: SwapWindow, piece: SwapPiece) -> bool:
	return piece.regular or w.boosters[piece.booster].state == BoosterOpening.State.OPEN


static func _hovered(page: BoosterPage, w: SwapWindow, piece: SwapPiece) -> bool:
	return page.is_hovered("piece%d" % w.pieces.find(piece))


## The piece resting in basket slot `slot` (its regular, or the card swapped in), or null.
static func _in_slot(page: BoosterPage, w: SwapWindow, slot: int) -> SwapPiece:
	var swapped: bool = page.run.starter.core_cards[slot] != page.run.start_setup.originals[slot]
	for piece: SwapPiece in w.pieces:
		if piece == w.held or not piece.item or piece.flying(page.now):
			continue
		if piece.regular and piece.slot == slot and not swapped:
			return piece
		if not piece.regular and swapped and w.slot_of(piece) == slot:
			return piece
	return null


static func _sealed(pen: ArtPen, page: BoosterPage, w: SwapWindow, bi: int) -> void:
	var b: BoosterOpening = w.boosters[bi]
	var at: Vector2 = pouch_pos(b.cx)
	if page.now < b.drop_t:
		return
	var du: float = (page.now - b.drop_t) / maxf(page.tuning.drop_s, 0.001)
	var y: float = at.y
	var bw: float = BoosterArt.BW
	var bh: float = BoosterArt.BH
	if not page.rm and du < 1.0:
		y = lerpf(-BoosterArt.BH - 30, at.y, BoosterPageDraw.e_back(du, 1.9))
	elif not page.rm and du < 1.6:
		var s: float = clampf(1.0 - (du - 1.0) / 0.6, 0.0, 1.0)
		bw += roundf(4 * s)
		bh -= roundf(8 * s)
	var hv: bool = page.is_hovered("swb%d" % bi) and not w.locked
	var lift: float = 0.0
	var shear: float = 0.0
	var hu: float = page.now - page.hover_t0
	if not page.rm and du >= 1.6:
		if hv:
			lift = minf(4, floorf(hu / 0.02))
			shear = roundf(2.7 * sin(11 * hu) * maxf(0.0, 1.0 - hu / 1.15))
		elif not w.locked:
			y += int(floorf((page.now + bi * 0.17) / 0.5)) % 2
	pen.r(at.x + 5, at.y + BoosterArt.BH + 1, BoosterArt.BW, 3, Palette.SLATE_DARK)
	var sheen: float = -1.0
	if not page.rm and not w.locked:
		sheen = fmod(hu, 1.2) / 0.45 if hv else fmod(page.now + bi * 0.6, 3.2) / 0.45
	BoosterPageDraw.pouch(
		pen,
		b.aisle,
		0 if w.locked else (2 if hv else 1),
		at.x,
		roundf(y) - lift,
		{"w": bw, "h": bh, "shear": shear, "sheen": sheen, "sweep": hv}
	)
	if w.locked:
		var cx: float = at.x + BoosterArt.BW / 2.0
		var cy: float = at.y + 44
		pen.rn(cx - 13, cy - 13, 26, 28, Palette.CREAM)
		pen.r(cx - 12, cy - 12, 24, 1, Palette.PAPER)
		pen.tex(PADLOCK, cx - 9, cy - 9, Color.WHITE, 2.0)


## A card piece (or an OUT regular) at its pose: held with a shadow; at rest with its tab (OUT),
## dimmed with "MAX 2 IN CART" when no slot can take it.
static func _card(
	pen: ArtPen, page: BoosterPage, w: SwapWindow, piece: SwapPiece, p: Dictionary, lift: float
) -> void:
	var sc: float = roundf((p.sc as float) * 20) / 20.0
	var at: Vector2 = p.pos
	var x: float = at.x - BoosterArt.CW / 2.0
	var y: float = at.y - BoosterArt.CH / 2.0 - lift
	if p.get("held", false):
		var cw: float = roundf(BoosterArt.CW * sc)
		var ch: float = roundf(BoosterArt.CH * sc)
		pen.d(roundf(at.x - cw / 2.0) + 5, roundf(at.y - ch / 2.0) + 7, cw, ch, Palette.INK, 8)
	BoosterCardDraw.draw(
		pen, piece.card, false, x, y, {"scale": sc, "now": page.now, "still": page.rm}
	)
	if p.get("held", false) or sc < 0.99:
		return
	if piece.regular:
		tag_above(pen, at.x, y - 7, "OUT", "bad")
	else:
		BoosterCardDraw.tab(pen, false, at.x, y - 1)
	pen.r(x + 2, y + BoosterArt.CH, BoosterArt.CW - 4, 1, Palette.INK)
	if w.blocked(piece):
		pen.r(x, y, BoosterArt.CW, BoosterArt.CH, Color(Palette.INK, 0.55))
		var text: String = StartTips.COPY_LIMIT_TAG % page.run.starter.copy_max
		var tw: float = ArtPen.word_texture(text, Palette.PAPER, false).get_width() + 8
		var tx: float = roundf(at.x - tw / 2.0)
		pen.rn(tx, y + BoosterArt.CH - 16, tw, 11, Palette.TOMATO)
		pen.r(tx + 1, y + BoosterArt.CH - 15, tw - 2, 1, Palette.TOMATO_LIGHT)
		pen.caps(
			text, at.x, y + BoosterArt.CH - 13, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER
		)


## An item in the basket, 2x, centred on `at` (it pops as it lands).
static func _item(
	pen: ArtPen, page: BoosterPage, piece: SwapPiece, at: Vector2, lift: float
) -> void:
	var pu: float = page.now - piece.land_t
	var s: float = 2.0
	if not page.rm and pu < 0.14:
		s = 2.0 + 0.5 * (1.0 - BoosterPageDraw.e_out(pu / 0.14))
	var sp: float = roundf(s * 4) / 4.0
	var texture: Texture2D = BoosterChromeDraw.sprite(piece.card)
	if texture == null:
		return
	var size: Vector2 = texture.get_size() * sp
	pen.tex(
		texture,
		roundf(at.x - size.x / 2.0),
		roundf(at.y - size.y / 2.0 - lift + (-2 if s > 2.0 else 0)),
		Color.WHITE,
		sp
	)


static func _basket_back(pen: ArtPen) -> void:
	pen.r(BASKET_X + 6, BASE_Y - 2, BASKET_W, 4, Palette.WOOD_DARKEST)
	pen.r(BASKET_X, BACK_Y, BASKET_W, BASE_Y - BACK_Y, Palette.INK)
	pen.r(BASKET_X + 1, BACK_Y + 1, BASKET_W - 2, BASE_Y - BACK_Y - 2, Palette.WOOD_DARKEST)
	pen.r(BASKET_X + 1, BACK_Y + 1, BASKET_W - 2, 6, Palette.BROWN_DARKEST)
	for k: int in range(1, 4):
		pen.r(roundf(slot_cx(k) - 53), BACK_Y + 8, 1, FRONT_Y - BACK_Y - 8, Palette.BROWN_DARKEST)


static func _basket_front(pen: ArtPen) -> void:
	var x: float = BASKET_X
	var w: float = BASKET_W
	var h: float = BASE_Y - FRONT_Y
	pen.r(x, FRONT_Y, w, h, Palette.INK)
	pen.r(x + 1, FRONT_Y + 1, w - 2, 19, Palette.WOOD)
	pen.r(x + 1, FRONT_Y + 1, w - 2, 1, Palette.WOOD_LIGHT)
	pen.r(x + 1, FRONT_Y + 19, w - 2, 1, Palette.WOOD_DARKEST)
	pen.r(x + 1, FRONT_Y + 21, w - 2, h - 22, Palette.WOOD_DARK)
	pen.r(x + 1, FRONT_Y + 21, w - 2, 1, Palette.WOOD)
	pen.r(x + 1, BASE_Y - 2, w - 2, 1, Palette.WOOD_DARKEST)
	for px: float in [x + 1, x + w - 12]:
		pen.r(px, FRONT_Y + 1, 11, h - 2, Palette.WOOD_DARKEST)
		pen.r(px + 1, FRONT_Y + 1, 1, h - 2, Palette.WOOD_DARK)
		pen.r(px + 9, FRONT_Y + 1, 1, h - 2, Palette.INK)
	var sx: float = x + 30
	while sx < x + w - 20:
		pen.r(sx, FRONT_Y + 6, 1, 1, Palette.STEEL_DARK)
		pen.r(sx, FRONT_Y + 30, 1, 1, Palette.STEEL_DARK)
		sx += 52


## A regular's tag on the basket front: its price; a swapped slot adds its aisle chip and ⇄.
static func _slot_tag(pen: ArtPen, page: BoosterPage, slot: int) -> void:
	var card: CardDefinition = page.run.starter.core_cards[slot]
	var x: float = slot_cx(slot)
	var y: float = FRONT_Y + 9
	var price: String = "%d€" % card.base
	var pw: float = ArtPen.word_texture(price, Palette.INK, true).get_width() + 8
	if card == page.run.start_setup.originals[slot]:
		pen.rn(roundf(x - pw / 2.0), y - 3, pw, 12, Palette.PAPER)
		pen.chunky(price, roundf(x - pw / 2.0) + 4, y - 1, Palette.INK)
		return
	var aisle: AisleDefinition = page.run.balance.aisle_of(card)
	var ramp: Array[Color] = BoosterArt.ramp(aisle.id if aisle != null else &"")
	var cw: float = 30
	var x0: float = roundf(x - (pw + 2 + cw) / 2.0)
	pen.rn(x0, y - 3, pw, 12, Palette.PAPER)
	pen.chunky(price, x0 + 4, y - 1, Palette.INK)
	pen.rn(x0 + pw + 2, y - 3, cw, 12, ramp[1])
	pen.r(x0 + pw + 3, y - 2, cw - 2, 1, ramp[0])
	if aisle != null:
		pen.tex(BoosterArt.glyph(aisle.id), x0 + pw + 5, y - 1)
	pen.tex(BoosterArt.SWAP, x0 + pw + 18, y - 2)


## The held piece's drop targets: each allowed slot dashed brass; the one under it gold with
## SWAP / TRADE / PUT BACK, or tomato with its reason.
static func _targets(pen: ArtPen, page: BoosterPage, w: SwapWindow, held: SwapPiece) -> void:
	var phase: int = 0 if page.rm else int(floorf(page.now / 0.12)) % 2
	for slot: int in page.run.starter.core_cards.size():
		if _home(w, held, slot):
			continue
		var why: String = w.drop_reason(held, slot)
		var r: Rect2 = slot_rect(slot)
		if w.hover_slot == slot:
			if why != "":
				dashes(pen, r, Palette.TOMATO, 0)
			else:
				pen.r(r.position.x, r.position.y, r.size.x, 2, Palette.GOLD)
				pen.r(r.position.x, r.end.y - 2, r.size.x, 2, Palette.GOLD)
				pen.r(r.position.x, r.position.y, 2, r.size.y, Palette.GOLD)
				pen.r(r.end.x - 2, r.position.y, 2, r.size.y, Palette.GOLD)
		elif why == "":
			dashes(pen, r, Palette.BRASS, phase)


## Whether `held` is a swapped-in item over its own slot (no target there: it just goes home).
static func _home(w: SwapWindow, held: SwapPiece, slot: int) -> bool:
	return slot >= 0 and not held.regular and w.slot_of(held) == slot


## The tag of the slot under the held piece (SWAP / TRADE / PUT BACK, or its refusal), drawn on
## the top layer over the held card so the card never hides it.
static func _hover_tag(pen: ArtPen, page: BoosterPage, w: SwapWindow, held: SwapPiece) -> void:
	var slot: int = w.hover_slot
	if slot < 0 or _home(w, held, slot):
		return
	var why: String = w.drop_reason(held, slot)
	var r: Rect2 = slot_rect(slot)
	if why != "":
		tag_above(pen, slot_cx(slot), r.position.y + 4, why, "bad")
		return
	var word: String = "SWAP"
	if held.regular:
		word = "PUT BACK"
	elif page.run.starter.core_cards[slot] != page.run.start_setup.originals[slot]:
		word = "TRADE"
	tag_above(pen, slot_cx(slot), r.position.y + 4, word, "good")


## A refused drop: its reason over the slot for 1.4 s, the slot shaking at first.
static func _refusal(pen: ArtPen, page: BoosterPage, w: SwapWindow) -> void:
	var u: float = page.now - w.err_t
	if w.err_slot < 0 or u >= 1.4 or w.held != null:
		return
	var shake: float = 0.0
	if not page.rm and u < 0.25:
		shake = 2.0 if int(floorf(u / 0.04)) % 2 else -2.0
	var r: Rect2 = slot_rect(w.err_slot)
	r.position.x += shake
	dashes(pen, r, Palette.TOMATO, 0)
	tag_above(pen, slot_cx(w.err_slot) + shake, r.position.y + 4, w.err_text, "bad")


## SWAPS LEFT: its pips and its number (popping as it changes, blinking tomato on a refusal);
## a padlock when no swap is unlocked.
static func _led(pen: ArtPen, page: BoosterPage, w: SwapWindow) -> void:
	var r: Rect2 = LED_RECT
	var x: float = r.position.x
	var y: float = r.position.y
	pen.nine(BoosterArt.LED, x, y, r.size.x, r.size.y, Vector4i(4, 4, 4, 4))
	var cx: float = x + r.size.x / 2.0
	pen.pix(
		"SWAPS" if w.locked else "SWAPS LEFT",
		cx,
		y + 7,
		Palette.MUSTARD_LIGHT,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if w.locked:
		pen.tex(PADLOCK, cx - 9, y + 21, Color.WHITE, 2.0)
		return
	var lu: float = page.now - w.led_t
	var blink: bool = not page.rm and lu < 0.6 and int(floorf(lu / 0.1)) % 2 == 0
	var n: int = StartSetupRules.swap_limit(page.run, page.profile)
	var left: int = StartSetupRules.swaps_left(page.run, page.profile)
	var total: float = n * 10 - 3
	var px0: float = roundf(cx - total / 2.0)
	for k: int in n:
		var on: bool = k < left
		var colour: Color = Palette.TOMATO if blink else (Palette.GOLD if on else Palette.INK_LIGHT)
		pen.r(px0 + k * 10, y + 33, 7, 7, colour)
		if on and not blink:
			pen.r(px0 + k * 10, y + 33, 7, 1, Palette.MUSTARD_PALE)
	var pu: float = page.now - w.left_t
	var s: float = 2.0 + (0.5 * (1.0 - pu / 0.2) if not page.rm and pu < 0.2 else 0.0)
	var words: ImageTexture = ArtPen.word_texture(
		str(left), Palette.GOLD if left > 0 else Palette.TOMATO, true
	)
	var ww: float = roundf(words.get_width() * s)
	var wh: float = roundf(8 * s)
	pen.canvas.draw_texture_rect(
		words,
		Rect2(pen.at(roundf(cx - ww / 2.0), roundf(y + 24 - wh / 2.0)), pen.size_of(ww, wh)),
		false
	)


static func _reset_key(pen: ArtPen, page: BoosterPage) -> void:
	var r: Rect2 = RESET_RECT
	var can: bool = StartSetupRules.applied_swaps(page.run) > 0
	var hv: bool = page.is_hovered("swreset") and can
	var sh: float = 2.0 if hv and not page.rm else 0.0
	pen.nine(
		BoosterArt.BUTTON_TEAL_LIT if hv else BoosterArt.BUTTON_TEAL,
		r.position.x + sh,
		r.position.y,
		r.size.x,
		r.size.y,
		Vector4i(3, 3, 3, 3)
	)
	pen.tex(BoosterArt.UNDO, r.position.x + 10 + sh, r.position.y + 8)
	pen.pix(
		"RESET",
		r.position.x + r.size.x / 2.0 + 6 + sh,
		r.position.y + 7,
		Palette.PAPER if can else Palette.TEAL_LIGHT,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if not can:
		pen.r(r.position.x, r.position.y, r.size.x, r.size.y, Color(Palette.TEAL_BLACK, 0.45))


## Over the window's scene: the title tab, the close key, the hint LED, DONE, the held piece and
## the window's particles.
static func _top(pen: ArtPen, page: BoosterPage, w: SwapWindow) -> void:
	var x: float = RECT.position.x
	var y: float = RECT.position.y
	var title: String = "YOUR REGULARS"
	var tw: float = ArtPen.word_texture(title, Palette.INK, true).get_width() + 20
	pen.rn(x + 10, y - 9, tw, 17, Palette.PAPER)
	pen.r(x + 11, y - 8, tw - 2, 1, Color.WHITE)
	pen.r(x + 11, y + 6, tw - 2, 1, Palette.CREAM_SHADE)
	pen.chunky(title, x + 10 + tw / 2.0, y - 5, Palette.INK, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var c: Rect2 = CLOSE_RECT
	var chv: bool = page.is_hovered("swclose")
	pen.rn(c.position.x, c.position.y, 17, 17, Palette.TOMATO_LIGHT if chv else Palette.TOMATO)
	pen.r(c.position.x + 1, c.position.y + 1, 15, 1, Palette.TOMATO_LIGHT)
	for i: int in 5:
		pen.r(c.position.x + 6 + i, c.position.y + 6 + i, 1, 1, Palette.PAPER)
		pen.r(c.position.x + 10 - i, c.position.y + 6 + i, 1, 1, Palette.PAPER)
	_hint(pen, page, w)
	_done(pen, page, w)
	if w.held != null:
		_card(pen, page, w, w.held, w.pose(w.held), 0.0)
		_hover_tag(pen, page, w, w.held)
	BoosterPageDraw.parts(pen, page, w.fx.parts)


static func _hint(pen: ArtPen, page: BoosterPage, w: SwapWindow) -> void:
	var r: Rect2 = HINT_RECT
	pen.nine(BoosterArt.LED, r.position.x, r.position.y, r.size.x, r.size.y, Vector4i(4, 4, 4, 4))
	var line: String = w.hint_line
	var n: int = line.length() if page.rm else int(floorf((page.now - w.hint_t) * 50))
	pen.pix(
		line.substr(0, clampi(n, 0, line.length())),
		r.position.x + r.size.x / 2.0,
		r.position.y + 6,
		Palette.GOLD,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)


static func _done(pen: ArtPen, page: BoosterPage, w: SwapWindow) -> void:
	var r: Rect2 = DONE_RECT
	var label: Array[String] = done_label(page)
	var hv: bool = page.is_hovered("swdone") and w.active
	var sh: float = 2.0 if hv and not page.rm else 0.0
	pen.nine(
		BoosterArt.BUTTON, r.position.x + sh, r.position.y, r.size.x, r.size.y, Vector4i(3, 3, 3, 3)
	)
	var cx: float = r.position.x + sh + r.size.x / 2.0
	pen.pix(label[0], cx, r.position.y + 5, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.caps(label[1], cx, r.end.y - 9, Palette.MUSTARD_PALE, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if hv:
		pen.tex(BoosterArt.TICK, r.position.x - 7, r.position.y + r.size.y / 2.0 - 3)


## The window's hint LED line: a flashed message for 2 s, else the state's hint.
static func hint_text(page: BoosterPage) -> String:
	var w: SwapWindow = page.swap
	var sealed: int = 0
	for opening: BoosterOpening in w.boosters:
		if opening.state == BoosterOpening.State.SEALED:
			sealed += 1
	var line: String = "DRAG A CARD ONTO A REGULAR"
	if page.message != "" and page.now - page.message_t < 2.0:
		line = page.message
	elif w.locked:
		line = StartTips.SWAPS_LOCKED_LINE
	elif w.held != null:
		line = "BACK TO ITS SPOT" if w.held.regular else "DROP IT ON A REGULAR"
	elif sealed > 0:
		line = "OPEN THE BOOSTERS" if sealed == w.boosters.size() else "OPEN THE OTHER BOOSTER"
	elif w.busy():
		line = ""
	elif StartSetupRules.swaps_left(page.run, page.profile) <= 0:
		line = "NO SWAPS LEFT · DRAG ONE BACK TO UNDO"
	return line


## DONE's label and sub-label.
static func done_label(page: BoosterPage) -> Array[String]:
	var w: SwapWindow = page.swap
	if w.busy():
		return ["SKIP ›", "SPEED IT UP"]
	var done: int = StartSetupRules.applied_swaps(page.run)
	var swaps: String = "%d SWAP%s" % [done, "" if done == 1 else "S"]
	if w.from_next:
		return ["DONE", swaps + " · YOUR BUILD" if done > 0 else "TO YOUR BUILD"]
	return ["DONE", swaps + " · TO STORE" if done > 0 else "BACK TO STORE"]


## A tag over a slot or a card (`look` "bad": tomato, "good": gold) with its pointer.
static func tag_above(pen: ArtPen, cx: float, y: float, text: String, look: String) -> void:
	var w: float = ArtPen.word_texture(text, Palette.INK, false).get_width() + 10
	var x: float = roundf(cx - w / 2.0)
	var bad: bool = look == "bad"
	pen.rn(x, y, w, 11, Palette.TOMATO if bad else Palette.GOLD)
	pen.r(x + 1, y + 1, w - 2, 1, Palette.TOMATO_LIGHT if bad else Palette.MUSTARD_PALE)
	pen.r(roundf(cx) - 1, y + 11, 3, 1, Palette.INK)
	pen.r(roundf(cx), y + 12, 1, 1, Palette.INK)
	pen.caps(
		text, cx, y + 3, Palette.PAPER if bad else Palette.INK, 1.0, HORIZONTAL_ALIGNMENT_CENTER
	)


## A dashed outline 2 art px thick round `r` (`phase` walks it).
static func dashes(pen: ArtPen, r: Rect2, colour: Color, phase: int) -> void:
	var x: float = roundf(r.position.x)
	var y: float = roundf(r.position.y)
	var w: float = r.size.x
	var h: float = r.size.y
	var i: float = 0.0
	while i < w:
		if (int(i) >> 2) % 2 == phase % 2:
			pen.r(x + i, y, minf(2, w - i), 2, colour)
			pen.r(x + i, y + h - 2, minf(2, w - i), 2, colour)
		i += 4
	i = 0.0
	while i < h:
		if (int(i) >> 2) % 2 == phase % 2:
			pen.r(x, y + i, 2, minf(2, h - i), colour)
			pen.r(x + w - 2, y + i, 2, minf(2, h - i), colour)
		i += 4


## The window's hit list this frame (screen art px, the slide added): only its own while open,
## none while it slides away.
static func hits(page: BoosterPage) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var w: SwapWindow = page.swap
	if not w.active:
		return list
	var dy: float = w.slide()
	var add: Callable = func(rect: Rect2, id: String, act: Callable, piece: SwapPiece) -> void:
		var entry: Dictionary = {"rect": Rect2(rect.position + Vector2(0, dy), rect.size), "id": id}
		entry["act"] = act
		if piece != null:
			entry["piece"] = piece
		list.append(entry)
	for bi: int in w.boosters.size():
		var b: BoosterOpening = w.boosters[bi]
		var at: Vector2 = pouch_pos(b.cx)
		if b.state == BoosterOpening.State.SEALED and page.now >= b.drop_t:
			add.call(
				Rect2(at.x, at.y - 6, BoosterArt.BW, BoosterArt.BH + 6),
				"swb%d" % bi,
				w.open_booster.bind(bi, "click"),
				null
			)
		elif b.state == BoosterOpening.State.OPENING:
			var fan: Vector2 = fan_centre(bi, 0)
			add.call(
				Rect2(
					fan.x - BoosterArt.CW / 2.0,
					fan.y - BoosterArt.CH / 2.0 - 40,
					3 * BoosterArt.FAN_STEP,
					BoosterArt.CH + 60
				),
				"swo%d" % bi,
				w.open_booster.bind(bi, "click"),
				null
			)
	if w.held == null:
		_piece_hits(page, w, add)
	add.call(RESET_RECT, "swreset", w.reset, null)
	add.call(CLOSE_RECT, "swclose", w.close.bind(false), null)
	add.call(DONE_RECT, "swdone", w.primary.bind("click"), null)
	return list


static func _piece_hits(page: BoosterPage, w: SwapWindow, add: Callable) -> void:
	for n: int in w.pieces.size():
		var piece: SwapPiece = w.pieces[n]
		if not _shown(w, piece) or piece.flying(page.now) or piece.item:
			continue
		add.call(
			Rect2(
				piece.pos.x - BoosterArt.CW / 2.0,
				piece.pos.y - BoosterArt.CH / 2.0 - 8,
				BoosterArt.CW,
				BoosterArt.CH + 8
			),
			"piece%d" % n,
			Callable(),
			piece
		)
	for slot: int in page.run.starter.core_cards.size():
		var piece: SwapPiece = _in_slot(page, w, slot)
		if piece == null:
			continue
		var rect: Rect2 = Rect2(slot_cx(slot) - 44, ITEM_TOP + 4, 88, FRONT_Y - ITEM_TOP - 4)
		var n: int = w.pieces.find(piece)
		if piece.regular:
			var words: String = StartTips.SWAPS_LOCKED_LINE if w.locked else "DRAG A CARD ONTO IT"
			add.call(rect, "piece%d" % n, page.flash.bind(words), null)
		else:
			add.call(rect, "piece%d" % n, Callable(), piece)


## The window's hover tips this frame (StartTips entries; none while a card is held): each shown
## card with its family chips (tagged with its booster's aisle; dimmed by the copy limit, the limit
## as its live line), an OUT regular, then the basket's items (YOUR REGULAR, or SWAPPED IN).
static func tip_entries(page: BoosterPage) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var w: SwapWindow = page.swap
	if not w.active or w.held != null:
		return list
	var dy: float = w.slide()
	var size: Vector2 = Vector2(BoosterArt.CW, BoosterArt.CH)
	for n: int in w.pieces.size():
		var piece: SwapPiece = w.pieces[n]
		if not _shown(w, piece) or piece.flying(page.now) or piece.item:
			continue
		var at: Vector2 = piece.pos - size / 2.0 + Vector2(0, dy)
		var key: String = "piece%d" % n
		if piece.regular:
			StartTips.card_entries(
				list, piece.card, false, at, key, StartTips.REGULAR_TAG, StartTips.SWAPPED_OUT_LIVE
			)
			continue
		var aisle: AisleDefinition = BoosterPageDraw.aisle_def(
			page, w.boosters[piece.booster].aisle
		)
		var tag: String = BoosterArt.short_name(aisle)
		if w.blocked(piece):
			var limit: String = StartTips.COPY_LIMIT_LIVE % page.run.starter.copy_max
			StartTips.card_entries(list, piece.card, false, at, key, tag, limit, TipSpec.Live.BAD)
		else:
			StartTips.card_entries(list, piece.card, false, at, key, tag)
	for slot: int in page.run.starter.core_cards.size():
		var piece: SwapPiece = _in_slot(page, w, slot)
		if piece == null:
			continue
		var rect: Rect2 = Rect2(slot_cx(slot) - 44, ITEM_TOP + 4 + dy, 88, FRONT_Y - ITEM_TOP - 4)
		var tag: String = StartTips.REGULAR_TAG if piece.regular else StartTips.SWAPPED_IN_TAG
		var line: String = "" if piece.regular else StartTips.SWAPPED_IN_LIVE
		var kind: TipSpec.Live = TipSpec.Live.INFO
		if piece.regular and w.locked:
			line = StartTips.SWAPS_LOCKED_LIVE
			kind = TipSpec.Live.OFF
		var key: String = "slot%d|%s|%s|%s" % [slot, piece.card.id, tag, line]
		var make: Callable = StartTips.card_spec.bind(piece.card, tag, "", line, kind)
		list.append(StartTips.entry_of(rect, key, make))
	return list
