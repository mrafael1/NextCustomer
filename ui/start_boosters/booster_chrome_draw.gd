class_name BoosterChromeDraw
extends RefCounted
## YOUR STORE's furniture and keys (v1.32, the mock-up's drawCrate, drawTray, drawTote,
## drawCounterPlates, drawHintLED, drawPrimary, drawShutterP1 and drawTopBar): the regulars'
## crate and swap tray, RESTOCK's key and returns tote, the counter plates, the floor row (TITLE,
## the hint LED, the primary key), the storefront at dawn and the top bar; and the page's hit list.

const DY := BoosterArt.DY
const MINI_W := 68
const MINI_GAP := 4
const TRAY_RECT := Rect2(6, 44, 0, 142)
const SPARKLE := BoosterArt.SPARKLE
const STAMP_RING := preload("res://art/icons/stamp_ring.png")

## The item sprites drawn so far, held so they stay loaded: a texture loaded for the first time
## inside a draw call (or freed and loaded again there) is drawn blank white on that frame.
static var _sprites: Dictionary[String, Texture2D] = {}


## Card `card`'s item sprite (its coupon icon for a coupon), loaded once and kept; the swap tray
## warms its tab's sprites through this before they are drawn.
static func sprite(card: CardDefinition) -> Texture2D:
	if not _sprites.has(String(card.id)):
		var texture: Texture2D = ArtStyle.item_sprite(card)
		_sprites[String(card.id)] = texture if texture != null else ArtStyle.coupon_icon(card)
	return _sprites[String(card.id)]


static func _sprite(card: CardDefinition) -> Texture2D:
	return sprite(card)


static func _completed(page: BoosterPage) -> Array[AisleDefinition]:
	return StartSetupRules.completed(page.run.balance, page.profile)


## The RESTOCK key on the counter front (sized from its label) and the tote's bay right of it.
static func key_rect() -> Rect2:
	return Rect2(
		BoosterArt.RESTOCK_X,
		BoosterArt.RESTOCK_Y,
		5 + ArtPen.pix_width("RESTOCK") + 4 + 9 + 4,
		BoosterArt.RESTOCK_H
	)


static func bay_rect() -> Rect2:
	var key: Rect2 = key_rect()
	return Rect2(key.end.x + 6, 239 + DY, 76, 24)


static func regular_x(slot: int) -> float:
	return BoosterArt.REG_X + slot * BoosterArt.REG_STEP


## The crate of regulars (STANDING ORDER) with its two slats; a swapped regular drops in.
static func crate(pen: ArtPen, page: BoosterPage) -> void:
	var now: float = page.now
	pen.r(4, 186 + DY, 156, 46, Palette.INK)
	pen.r(5, 187 + DY, 154, 44, Palette.WOOD_DARKEST)
	var live: bool = page.counter.swaps_live()
	var cards: Array[CardDefinition] = page.run.starter.core_cards
	for k: int in cards.size():
		var x: float = regular_x(k)
		var y: float = 168 + DY
		var hovered: bool = page.is_hovered("reg%d" % k)
		if hovered:
			y -= 3
		var swapped: bool = cards[k] != page.run.start_setup.originals[k]
		var dy: float = 0.0
		var st: float = page.swap_t.get(k, -INF)
		if not page.rm and now - st < 0.3:
			var u: float = (now - st) / 0.3
			dy = (
				-6 + BoosterPageDraw.stepped(BoosterPageDraw.e_out((u - 0.5) * 2) * 6, 2)
				if u >= 0.5
				else 0.0
			)
			if u < 0.5:
				dy = -6
		if page.complete_t != INF and not page.rm:
			var hu: float = now - page.complete_t - 0.05 * k
			if hu > 0 and hu < 0.1:
				dy -= 2
		pen.tex(_sprite(cards[k]), x, y + dy)
		pen.tex(BoosterArt.PRICE_TAG, x + 36, y + 6 + dy)
		if swapped:
			var aisle: AisleDefinition = page.run.balance.aisle_of(cards[k])
			var tu: float = now - st - 0.22
			if aisle != null and (tu >= 0 or page.rm):
				var sc: float = 1.5 if not page.rm and tu < 0.12 else 1.0
				var ramp: Array[Color] = BoosterArt.ramp(aisle.id)
				pen.r(x + 2, y + 40 + dy - (2 if sc > 1 else 0), 14 * sc, 6 * sc, Palette.INK)
				pen.r(x + 3, y + 41 + dy, 14 * sc - 2, 4 * sc, ramp[1])
				pen.tex(BoosterArt.glyph(aisle.id), x + 4, y + 39 + dy)
		# The swap tag shows on hover, and stays on the regular being swapped while its tray is
		# open (so a keyboard player sees which item the tray swaps).
		var swapping: bool = page.tray_slot == k
		if (
			swapping
			or (
				hovered
				and live
				and (swapped or page.counter.swaps_used() < page.counter.swap_limit())
			)
		):
			var tu2: float = clampf((now - page.hover_t0) / 0.12, 0.0, 1.0)
			if swapping and not hovered:
				tu2 = 1.0
			var tw: float = roundf(lerpf(4, 17, 1.0 if page.rm else tu2))
			pen.rn(x + 30, y - 2, tw, 13, Palette.MUSTARD if swapped else Palette.TEAL)
			if tw > 12:
				pen.tex(BoosterArt.UNDO if swapped else BoosterArt.SWAP, x + 34, y + 1)
	pen.r(4, 204 + DY, 156, 28, Palette.INK)
	pen.r(5, 205 + DY, 154, 12, Palette.WOOD)
	pen.r(5, 205 + DY, 154, 1, Palette.WOOD_LIGHT)
	pen.r(5, 217 + DY, 154, 1, Palette.WOOD_DARKEST)
	pen.r(5, 219 + DY, 154, 12, Palette.WOOD_DARK)
	pen.r(5, 219 + DY, 154, 1, Palette.WOOD)
	pen.r(5, 230 + DY, 154, 1, Palette.WOOD_DARKEST)
	for x: float in [5.0, 152.0]:
		pen.r(x, 205 + DY, 7, 26, Palette.WOOD_DARKEST)
		pen.r(x + 1, 205 + DY, 1, 26, Palette.WOOD_DARK)
	var sx: float = 20
	while sx < 150:
		pen.r(sx, 210 + DY, 1, 1, Palette.STEEL_DARK)
		pen.r(sx, 224 + DY, 1, 1, Palette.STEEL_DARK)
		sx += 26


## The window's dawn across the crate's front (additive layer).
static func crate_glow(pen: ArtPen, _page: BoosterPage) -> void:
	for y: int in range(205, 231):
		pen.d(5 + roundf((y - 205) * 1.2), y + DY, 92, 1, Palette.MUSTARD_DARKEST, 4)


## Over the scene: the swap tray, or the hovered regular's card in a pop-up.
static func pop(pen: ArtPen, page: BoosterPage) -> void:
	if page.tray_slot >= 0:
		_tray(pen, page)
		return
	for k: int in page.run.starter.core_cards.size():
		if page.is_hovered("reg%d" % k):
			var x: float = 46
			var y: float = 46
			pen.nine(
				BoosterArt.POPUP,
				x - 4,
				y - 4,
				BoosterArt.CW + 8,
				BoosterArt.CH + 8,
				Vector4i(4, 4, 4, 4)
			)
			BoosterCardDraw.draw(pen, page.run.starter.core_cards[k], false, x, y, {"still": true})


## The tray's width for `count` offers.
static func tray_width(count: int) -> float:
	return maxf(16 + 3 * MINI_W + 2 * MINI_GAP, 16 + count * MINI_W + (count - 1) * MINI_GAP)


static func _tray(pen: ArtPen, page: BoosterPage) -> void:
	var aisles: Array[AisleDefinition] = page.counter.tray_aisles()
	if aisles.is_empty():
		return
	var tab: int = clampi(page.tray_tab, 0, aisles.size() - 1)
	var aisle: AisleDefinition = aisles[tab]
	var offer: Array[CardDefinition] = page.counter.tray_offer(tab)
	var used: int = _swaps_from(page, aisle)
	var n: int = offer.size()
	var w: float = tray_width(n)
	var x: float = TRAY_RECT.position.x
	var y: float = TRAY_RECT.position.y
	var h: float = TRAY_RECT.size.y
	var mx0: float = x + roundf((w - (n * MINI_W + (n - 1) * MINI_GAP)) / 2.0)
	pen.nine(BoosterArt.POPUP, x, y, w, h, Vector4i(4, 4, 4, 4))
	var regular: CardDefinition = page.run.starter.core_cards[page.tray_slot]
	pen.pix("SWAP %s FOR" % regular.display_name.to_upper(), x + 8, y + 7, Palette.INK)
	var tx: float = x + 8
	for k: int in aisles.size():
		var on: bool = k == tab
		pen.nine(
			BoosterArt.sign_frame(aisles[k].id),
			tx,
			y + 18 - (2 if on else 0),
			22,
			14 + (2 if on else 0),
			Vector4i(3, 3, 3, 3)
		)
		pen.tex(BoosterArt.glyph(aisles[k].id), tx + 6, y + 21 - (1 if on else 0))
		tx += 24
	pen.pix(BoosterArt.short_name(aisle), tx + 4, y + 22, Palette.TEAL_SHADE)
	var limit: int = page.run.balance.staple_swap_aisle_max
	for k: int in n:
		var mx: float = mx0 + k * (MINI_W + MINI_GAP)
		var my: float = y + 38
		var mh: float = 90
		var reason: StringName = StartSetupRules.swap_block(
			page.run, page.profile, page.tray_slot, offer[k]
		)
		var blocked: bool = reason == &"copies"
		var full: bool = reason != &"" and not blocked
		var hv: float = 2.0 if page.is_hovered("mini%d" % k) and not (blocked or full) else 0.0
		pen.nine(BoosterArt.RECEIPT, mx, my - hv, MINI_W, mh, Vector4i(2, 2, 2, 2))
		pen.tex(_sprite(offer[k]), mx + 10, my + 2 - hv)
		if blocked or full:
			pen.d(mx + 1, my + 1, MINI_W - 2, 50, Palette.PAPER, 10)
		var lines: PackedStringArray = ArtPen.pix_wrap(offer[k].display_name.to_upper(), MINI_W - 6)
		for j: int in mini(2, lines.size()):
			pen.pix(
				lines[j],
				mx + MINI_W / 2.0,
				my + 54 + j * 9 - hv,
				Palette.INK,
				1.0,
				HORIZONTAL_ALIGNMENT_CENTER
			)
		if blocked:
			pen.caps(
				"%d IN CART" % page.run.starter.copy_max,
				mx + MINI_W / 2.0,
				my + mh - 10,
				Palette.TOMATO,
				1.0,
				HORIZONTAL_ALIGNMENT_CENTER
			)
		else:
			pen.chunky(
				"%d€" % offer[k].base,
				mx + MINI_W / 2.0,
				my + mh - 12 - hv,
				Palette.INK,
				1.0,
				HORIZONTAL_ALIGNMENT_CENTER
			)
	if used >= limit:
		pen.caps(
			"%d SWAPS FROM %s: THE MOST FROM ONE AISLE" % [limit, BoosterArt.short_name(aisle)],
			x + 8,
			y + h - 11,
			Palette.TOMATO_DARK
		)


static func _swaps_from(page: BoosterPage, aisle: AisleDefinition) -> int:
	var count: int = 0
	var cards: Array[CardDefinition] = page.run.starter.core_cards
	for k: int in cards.size():
		if (
			cards[k] != page.run.start_setup.originals[k]
			and page.run.balance.aisle_of(cards[k]) == aisle
		):
			count += 1
	return count


## RETURN THIS ONE: a chase of brass dots round each returnable fan while RESTOCK is armed.
static func restock_call(pen: ArtPen, page: BoosterPage) -> void:
	if not page.restock_armed:
		return
	for b: BoosterOpening in page.boosters:
		if not page.counter.restockable(b.index):
			continue
		var p0: Vector2 = BoosterArt.fan_pos(b.cx, 0)
		var x: float = p0.x - 4
		var y: float = p0.y - 10
		var w: float = BoosterArt.FAN_STEP * 2 + BoosterArt.CW + 8
		var h: float = BoosterArt.CH + 16
		var hv: bool = page.is_hovered("rcards%d" % b.index)
		var phase: int = 0 if page.rm else int(floorf(page.now / 0.08)) % 4
		var dots: Array[Vector2] = []
		var q: float = 0
		while q < w:
			dots.append(Vector2(x + q, y))
			dots.append(Vector2(x + w - 2 - q, y + h - 2))
			q += 4
		q = 4
		while q < h - 4:
			dots.append(Vector2(x, y + h - 2 - q))
			dots.append(Vector2(x + w - 2, y + q))
			q += 4
		for n: int in dots.size():
			if (n >> 1) % 2 == phase % 2 or hv:
				pen.r(dots[n].x, dots[n].y, 2, 2, Palette.GOLD if hv else Palette.BRASS)
		var label: String = "RETURN THIS ONE"
		var tw: float = ArtPen.word_texture(label, Palette.INK, false).get_width() + 8
		pen.rn(roundf(x + w / 2.0 - tw / 2.0), y - 10, tw, 9, Palette.VELVET_DARKEST)
		pen.caps(
			label,
			x + w / 2.0,
			y - 8,
			Palette.GOLD if hv else Palette.MUSTARD,
			1.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)


## A counter plate centred on `cx` (lit: shifted 4 px with a tick).
static func _plate(
	pen: ArtPen, page: BoosterPage, cx: float, y: float, label: String, lit: bool, off: bool
) -> void:
	var w: float = ArtPen.pix_width(label) + 14
	var x: float = roundf(cx - w / 2.0) + (4 if lit and not page.rm else 0)
	var frame: Texture2D = (
		BoosterArt.PLATE_OFF if off else (BoosterArt.PLATE_LIT if lit else BoosterArt.PLATE)
	)
	pen.nine(frame, x, y, w, 16, Vector4i(4, 4, 4, 4))
	pen.pix(
		label,
		x + w / 2.0,
		y + 4,
		Palette.BROWN_DARK if off else Palette.INK,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if lit:
		pen.tex(BoosterArt.TICK, x - 7, y + 4)


static func counter_plates(pen: ArtPen, page: BoosterPage) -> void:
	var completed: int = _completed(page).size()
	var label: String = "YOUR REGULARS"
	if completed >= 1 and not page.counter.swaps_live():
		label = "SWAP AFTER OPENING"
	pen.nine(BoosterArt.PLATE, 6, 241 + DY, 152, 17, Vector4i(4, 4, 4, 4))
	pen.pix(label, 10, 246 + DY, Palette.INK)
	if completed >= 1:
		var n: int = page.counter.swap_limit()
		var lx: float = 156 - 6 - n * 7 - 4
		pen.nine(BoosterArt.LED, lx, 243 + DY, n * 7 + 6, 12, Vector4i(4, 4, 4, 4))
		for k: int in n:
			pen.r(lx + 3 + k * 7, 246 + DY, 5, 6, Palette.INK_LIGHT)
			if k < n - page.counter.swaps_used():
				pen.r(lx + 3 + k * 7, 246 + DY, 5, 6, Palette.GOLD)
				pen.r(lx + 3 + k * 7, 246 + DY, 5, 1, Palette.MUSTARD_PALE)
	var picking: bool = page.openings.pick_layout()
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.GONE or (b.sink_t != INF and page.now > b.sink_t + 0.3):
			continue
		var lit: bool = (
			page.is_hovered("booster%d" % b.index)
			or BoosterPageDraw.next_booster(page) == b
			or b.picked
		)
		var name: String = BoosterArt.short_name(BoosterPageDraw.aisle_def(page, b.aisle))
		var text: String = "%s · %d" % [name, b.cards.size()]
		if picking:
			text = "PICKED" if b.picked else "%s · %d" % [name, b.cards.size()]
		_plate(pen, page, roundf(b.cx), 242 + DY, text, lit, b.sold_t != INF)


## The tote's bay: a dark recess in the counter front (once RESTOCK is unlocked).
static func bay(pen: ArtPen, page: BoosterPage) -> void:
	if page.openings.pick_layout() or not page.counter.restock_unlocked():
		return
	var r: Rect2 = bay_rect()
	pen.r(r.position.x, r.position.y, r.size.x, r.size.y, Palette.INK)
	pen.r(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 1, Palette.CHARCOAL)
	pen.r(r.position.x + 1, r.position.y + 1, r.size.x - 2, 2, Palette.RUBBER_DARK)


## The returns tote in its bay (clipped to it): it drops away with the old cards and comes back.
static func tote(pen: ArtPen, page: BoosterPage) -> void:
	if page.openings.pick_layout() or not page.counter.restock_unlocked():
		return
	var r: Rect2 = bay_rect()
	var u: float = page.now - page.tote_t
	var tuning: StartBoostersTuning = page.tuning
	var flying: bool = page.tote_cards.size() > 0
	var used: bool = page.counter.restock_block() == &"used" and not flying
	var armed: bool = page.restock_armed
	var dy: float = 0.0
	if flying and not page.rm:
		var d0: float = tuning.restock_tote_at_s
		var d1: float = d0 + tuning.restock_tote_s
		var r1: float = d1 + tuning.restock_tote_back_s
		if u >= d0 and u < d1:
			dy = BoosterPageDraw.stepped(
				BoosterPageDraw.e_in((u - d0) / tuning.restock_tote_s) * 26, 2
			)
		elif u >= d1 and u < r1:
			dy = BoosterPageDraw.stepped(
				(
					(
						1.0
						- BoosterPageDraw.e_out((u - d1) / maxf(tuning.restock_tote_back_s, 0.001))
					)
					* 26
				),
				2
			)
	var tx: float = r.position.x + 4
	var ty: float = r.position.y + 5 + dy
	var tw: float = r.size.x - 8
	var th: float = 18
	var body: Color = Palette.TEAL if armed else (Palette.TEAL_DARK if used else Palette.TEAL_SHADE)
	var rim: Color = Palette.TEAL_LIGHT if armed else (Palette.TEAL_SHADE if used else Palette.TEAL)
	pen.r(tx, ty, tw, th, Palette.INK)
	pen.r(tx + 1, ty + 1, tw - 2, th - 2, body)
	pen.r(tx + 1, ty + 1, tw - 2, 2, rim)
	pen.r(tx + 1, ty + th - 3, tw - 2, 1, Palette.TEAL_BLACK)
	for hx: float in [tx + 5, tx + tw - 13]:
		pen.r(hx, ty + 5, 8, 3, Palette.INK)
		pen.r(hx + 1, ty + 7, 6, 1, Palette.TEAL_BLACK)
	var rib: float = tx + 3
	while rib < tx + tw - 3:
		pen.r(rib, ty + 10, 1, 5, Palette.TEAL_SHADE if armed else Palette.TEAL_BLACK)
		rib += 4
	pen.rn(tx + tw / 2.0 - 20, ty + 9, 40, 7, Palette.CREAM_DARKEST if used else Palette.PAPER)
	pen.caps(
		"RETURNS",
		tx + tw / 2.0,
		ty + 10,
		Palette.STEEL_DARK if used else Palette.INK,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if armed and not page.rm and int(floorf(page.now / 0.3)) % 2:
		pen.r(tx + 1, ty + 1, tw - 2, 1, Palette.PAPER)


## Over the bay: the old cards flying into the tote, RESTOCK's key, and the floor row.
static func front_top(pen: ArtPen, page: BoosterPage) -> void:
	_tote_cards(pen, page)
	_restock_key(pen, page)
	_title_plate(pen, page)
	_hint_led(pen, page)
	_primary(pen, page)


static func _tote_cards(pen: ArtPen, page: BoosterPage) -> void:
	if page.tote_cards.is_empty() or page.rm or page.tote_booster < 0:
		return
	var tuning: StartBoostersTuning = page.tuning
	var u: float = page.now - page.tote_t
	var r: Rect2 = bay_rect()
	var cx: float = page.boosters[page.tote_booster].cx
	for k: int in page.tote_cards.size():
		var card: CardDefinition = page.tote_cards[k]
		var p: Vector2 = BoosterArt.fan_pos(cx, k)
		var f0: float = k * tuning.restock_flip_s
		var fly0: float = 0.12 + k * tuning.restock_flip_s
		if u < f0:
			BoosterCardDraw.draw(pen, card, false, p.x, p.y, {"still": true})
		elif u < f0 + 0.12:
			var q: float = (u - f0) / 0.12
			var back: BoosterCardDraw.Back = (
				BoosterCardDraw.Back.PLAIN if q >= 0.5 else BoosterCardDraw.Back.NONE
			)
			BoosterCardDraw.draw(
				pen, card, false, p.x, p.y, {"still": true, "back": back, "sx": absf(cos(PI * q))}
			)
		elif u < fly0 + tuning.restock_fly_s:
			var q2: float = clampf((u - fly0) / tuning.restock_fly_s, 0.0, 1.0)
			var tx: float = r.get_center().x - BoosterArt.CW / 2.0
			var ty: float = r.position.y - 20
			var xx: float = lerpf(p.x, tx, q2)
			var yy: float = lerpf(p.y, ty, q2) - sin(q2 * PI) * 50
			var sc: float = (
				1.0 if q2 < 0.25 else (0.75 if q2 < 0.5 else (0.5 if q2 < 0.75 else 0.3))
			)
			var w: float = roundf(BoosterArt.CW * sc)
			var h: float = roundf(BoosterArt.CH * sc)
			pen.canvas.draw_texture_rect(
				BoosterArt.CARD_BACK,
				Rect2(
					pen.at(roundf(xx + BoosterArt.CW / 2.0 - w / 2.0), roundf(yy + 30 - h / 2.0)),
					pen.size_of(w, h)
				),
				false
			)


static func _restock_key(pen: ArtPen, page: BoosterPage) -> void:
	if page.openings.pick_layout():
		return
	var k: Rect2 = key_rect()
	var unlocked: bool = page.counter.restock_unlocked()
	var used: bool = page.counter.restock_block() == &"used"
	var armed: bool = page.restock_armed
	var hv: bool = page.is_hovered("restock") and unlocked and not used
	var down: float = 2 if armed else 0
	var frame: Texture2D = BoosterArt.KEY
	if not unlocked or used:
		frame = BoosterArt.KEY_OFF
	elif hv or armed:
		frame = BoosterArt.KEY_LIT
	pen.nine(
		frame, k.position.x, k.position.y + down, k.size.x, k.size.y - down, Vector4i(3, 7, 3, 4)
	)
	pen.pix(
		"RESTOCK",
		k.position.x + 5,
		k.position.y + 5 + down,
		Palette.STEEL_SHADE if not unlocked or used else Palette.INK
	)
	var slot: float = k.end.x - 13
	if not unlocked:
		pen.tex(BoosterArt.PADLOCK, slot, k.position.y + 4 + down)
	else:
		pen.nine(BoosterArt.COIN_LED, slot + 1, k.position.y + 6 + down, 7, 7, Vector4i(1, 1, 1, 1))
		if not used:
			var blink: bool = armed and int(floorf(page.now / 0.15)) % 2 == 1
			pen.r(
				slot + 2,
				k.position.y + 7 + down,
				5,
				5,
				Palette.MUSTARD_PALE if blink else Palette.GOLD
			)


static func _title_plate(pen: ArtPen, page: BoosterPage) -> void:
	var r: Rect2i = BoosterArt.TITLE_RECT
	var hv: bool = page.is_hovered("title")
	var x: float = r.position.x + (2 if hv and not page.rm else 0)
	pen.nine(BoosterArt.BUTTON_TEAL, x, r.position.y, r.size.x, r.size.y, Vector4i(3, 3, 3, 3))
	pen.pix(
		"‹ TITLE",
		x + r.size.x / 2.0,
		r.position.y + 8,
		Palette.PAPER,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if hv:
		pen.tex(BoosterArt.TICK, 1, r.position.y + 10)


static func _hint_led(pen: ArtPen, page: BoosterPage) -> void:
	var r: Rect2i = BoosterArt.HINT_RECT
	var cx: float = r.position.x + r.size.x / 2.0
	pen.nine(BoosterArt.LED, r.position.x, r.position.y, r.size.x, r.size.y, Vector4i(4, 4, 4, 4))
	var line: String = page.hint_line()
	var n: int = line.length() if page.rm else int(floorf((page.now - page.hint_start()) * 40))
	var shown: String = line.substr(0, clampi(n, 0, line.length()))
	var blink: bool = line.begins_with("·") and int(floorf(page.now / 0.15)) % 2 == 1
	if not blink:
		pen.pix(shown, cx, r.position.y + 6, Palette.GOLD, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if n < line.length() and int(floorf(page.now / 0.1)) % 2 == 1:
		pen.r(cx + ArtPen.pix_width(shown) / 2.0 + 2, r.position.y + 6, 3, 7, Palette.GOLD)


## The primary key: its label, its sub-label, chase bulbs once NEXT is armed, the Space hold ring.
static func _primary(pen: ArtPen, page: BoosterPage) -> void:
	var r: Rect2i = BoosterArt.PRIMARY_RECT
	var label: Array = page.primary_label()
	var enabled: bool = label[2]
	var x: float = r.position.x
	var y: float = r.position.y
	var w: float = r.size.x
	var h: float = r.size.y
	var hv: bool = page.is_hovered("primary") and enabled
	var sh: float = 2 if hv and not page.rm else 0
	var armed_t: float = page.complete_t + 0.3
	if page.page_done() and not page.restock_armed and page.now >= armed_t:
		pen.r(x - 6, y - 6, w + 12, h + 12, Palette.INK)
		pen.r(x - 5, y - 5, w + 10, h + 10, Palette.VELVET_DARKEST)
		var u: float = page.now - armed_t
		var bulbs: Array[Vector2] = []
		var i: float = 0
		while i < w + 6:
			bulbs.append(Vector2(x - 3 + i, y - 4))
			i += 5
		i = 0
		while i < h + 6:
			bulbs.append(Vector2(x + w + 2, y - 3 + i))
			i += 5
		i = w + 3
		while i > -3:
			bulbs.append(Vector2(x + i, y + h + 2))
			i -= 5
		i = h + 3
		while i > -3:
			bulbs.append(Vector2(x - 4, y + i))
			i -= 5
		for k: int in bulbs.size():
			var on: bool = true
			if not page.rm:
				on = (
					(k + int(floorf(u * 12))) % 3 == 0
					if u < 0.6
					else (k + int(floorf(u * 3))) % 2 == 0
				)
			pen.r(bulbs[k].x, bulbs[k].y, 2, 2, Palette.GOLD if on else Palette.BRASS_DARK)
			if on:
				pen.r(bulbs[k].x, bulbs[k].y, 1, 1, Palette.MUSTARD_PALE)
	pen.nine(
		BoosterArt.BUTTON if enabled else BoosterArt.BUTTON_TEAL,
		x + sh,
		y,
		w,
		h,
		Vector4i(3, 3, 3, 3)
	)
	var sub: String = label[1]
	pen.pix(
		label[0],
		x + sh + w / 2.0,
		y + 5,
		Palette.PAPER if enabled else Palette.TEAL_PALE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	pen.caps(
		sub,
		x + sh + w / 2.0,
		y + h - 9,
		Palette.MUSTARD_PALE if enabled else Palette.TEAL_PALE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if hv:
		pen.tex(BoosterArt.TICK, x - 7, y + h / 2.0 - 3)
	if page.hold_t >= 0.0:
		var q: float = clampf((page.now - page.hold_t) / page.tuning.hold_space_s, 0.0, 1.0)
		var around: float = 2 * (w + h)
		var count: int = int(floorf(q * around / 2.0)) * 2
		var p: int = 0
		while p < count:
			var px: float
			var py: float
			if p < w:
				px = x + p
				py = y - 2
			elif p < w + h:
				px = x + w
				py = y + p - w
			elif p < 2 * w + h:
				px = x + w - (p - w - h)
				py = y + h
			else:
				px = x - 2
				py = y + h - (p - 2 * w - h)
			pen.r(px, py, 2, 2, Palette.GOLD)
			p += 2


## The storefront at dawn: its shutters down with OPENS 7:00 and ROLL UP, rolling up, then the
## facade growing about the door as the view walks in.
static func storefront(pen: ArtPen, page: BoosterPage) -> void:
	var tuning: StartBoostersTuning = page.tuning
	var e: float = 0.0
	if page.shutter == BoosterPage.Shutter.UP:
		return
	if page.shutter == BoosterPage.Shutter.ROLLING:
		e = 99.0 if page.rm else page.now - page.shutter_t
	if e >= tuning.shutter_up_s + tuning.walk_in_s:
		return
	var door: Rect2i = StoreDawnArt.DOOR
	if e < tuning.shutter_up_s:
		pen.tex(StoreDawnArt.facade(), 0, 0)
		var roll: float = 1.0 - BoosterPageDraw.e_in(e / tuning.shutter_up_s)
		for win: Rect2i in StoreDawnArt.WINDOWS:
			_roller(
				pen,
				win.position.x,
				win.position.y,
				win.size.x,
				BoosterPageDraw.stepped(win.size.y * roll, 2)
			)
		_roller(
			pen,
			door.position.x,
			door.position.y,
			door.size.x,
			BoosterPageDraw.stepped(door.size.y * roll, 2)
		)
		if page.shutter == BoosterPage.Shutter.DOWN:
			_door_sign(pen, page, door)
		return
	var z: float = clampf((e - tuning.shutter_up_s) / tuning.walk_in_s, 0.0, 1.0)
	var s: float = 1.0 + roundf(BoosterPageDraw.e_in(z) * 7 * 4) / 4.0
	var cx: float = door.position.x + door.size.x / 2.0
	var cy: float = door.position.y + door.size.y * 0.55
	var facade: ImageTexture = StoreDawnArt.facade()
	pen.canvas.draw_texture_rect(
		facade,
		Rect2(
			pen.at(roundf(cx - cx * s), roundf(cy - cy * s)),
			pen.size_of(roundf(BoosterArt.AW * s), roundf(BoosterArt.AH * s))
		),
		false
	)


static func _door_sign(pen: ArtPen, page: BoosterPage, door: Rect2i) -> void:
	var top: float = door.position.y
	pen.r(320, top + 4, 1, 14, Palette.STEEL_DARKEST)
	pen.r(304, top + 18, 33, 1, Palette.STEEL_DARKEST)
	pen.rn(286, top + 20, 68, 38, Palette.CREAM)
	pen.r(287, top + 21, 66, 1, Palette.PAPER)
	pen.r(287, top + 56, 66, 1, Palette.CREAM_SHADE)
	pen.chunky("OPENS", 320, top + 26, Palette.TOMATO, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.chunky("7:00", 320, top + 37, Palette.INK, 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	var hv: bool = page.is_hovered("rollup")
	var bob: float = 0.0 if page.rm else float(int(floorf(page.now / 0.5)) % 2)
	var bx: float = 270 + (2 if hv else 0)
	var by: float = top + 98 + bob
	pen.nine(
		BoosterArt.BUTTON_LIT if hv else BoosterArt.BUTTON, bx, by, 100, 30, Vector4i(3, 3, 3, 3)
	)
	pen.pix("ROLL UP", bx + 50, by + 8, Palette.PAPER, 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	if hv:
		pen.tex(BoosterArt.TICK, 263, by + 12)


static func _roller(pen: ArtPen, x: float, y: float, w: float, drop: float) -> void:
	if drop <= 0:
		return
	pen.r(x, y, w, drop, Palette.STEEL_SHADE)
	var yy: float = y + drop - 6
	while yy >= y:
		pen.r(x, yy, w, 1, Palette.STEEL_DARK)
		pen.r(x, yy + 1, w, 1, Palette.STEEL)
		yy -= 4
	pen.r(x, y + drop - 5, w, 5, Palette.STEEL_DARK)
	pen.r(x, y + drop - 5, w, 1, Palette.STEEL_LIGHT)
	pen.r(x, y + drop - 1, w, 1, Palette.INK)


## The top bar: OPENING TIME, the two page tabs, the aisles LED, the CART LED with its punch.
static func top_bar(pen: ArtPen, page: BoosterPage) -> void:
	top_bar_view(
		pen,
		{
			"now": page.now,
			"rm": page.rm,
			"minutes": page.clock_minutes,
			"tab": 1,
			"blink": page.page_done() and not page.is_hovered("tab2"),
			"completed": _completed(page),
			"aisles": page.run.balance.aisles,
			"cart": page.cart_shown,
			"limit": page.run.balance.deck_limit,
			"punch_t": page.cart_punch_t,
			"punch_s": page.cart_punch_s,
		}
	)


## The top bar from `v` (both pages draw it): now, rm, minutes (past 6), tab (the page shown),
## blink (the other tab's gold dot), completed and aisles (AisleDefinitions), cart, limit, punch_t
## and punch_s (the CART count's punch).
static func top_bar_view(pen: ArtPen, v: Dictionary) -> void:
	var now: float = v.now
	var rm: bool = v.rm
	var minutes: int = v.minutes
	var tab: int = v.tab
	pen.r(0, 0, BoosterArt.AW, 27, Palette.TEAL_BLACK)
	pen.d(0, 0, BoosterArt.AW, 27, Palette.SLATE_DARK, 4)
	pen.r(0, 27, BoosterArt.AW, 1, Palette.INK)
	pen.nine(BoosterArt.LED, 4, 4, 146, 20, Vector4i(4, 4, 4, 4))
	pen.tex(BoosterArt.CLOCK, 11, 10)
	pen.pix("OPENING TIME", 24, 11, Palette.MUSTARD_LIGHT)
	var hours: String = "7" if minutes >= 60 else "6"
	pen.chunky(
		"%s:%02d" % [hours, minutes % 60], 143, 10, Palette.GOLD, 1.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	for k: int in 2:
		var x: float = 156 + k * 84
		var on: bool = k + 1 == tab
		var y: float = 5 if on else 7
		pen.nine(
			BoosterArt.TAB_PICKED if on else BoosterArt.TAB, x, y, 82, 27 - y, Vector4i(3, 3, 3, 3)
		)
		pen.chunky(str(k + 1), x + 6, y + 6, Palette.TOMATO if on else Palette.TEAL_PALE)
		pen.pix(
			"YOUR STORE" if k == 0 else "YOUR BUILD",
			x + 15,
			y + 7,
			Palette.INK if on else Palette.PAPER
		)
		if not on and v.blink and not rm and int(floorf(now * 3)) % 2 == 1:
			pen.r(x + 82 - 6, y + 4, 2, 2, Palette.GOLD)
	pen.nine(BoosterArt.LED, 326, 4, 144, 20, Vector4i(4, 4, 4, 4))
	var completed: Array[AisleDefinition] = v.completed
	var aisles: Array[AisleDefinition] = v.aisles
	for k: int in aisles.size():
		var glyph: Texture2D = BoosterArt.glyph(aisles[k].id)
		if completed.has(aisles[k]):
			pen.tex(glyph, 333 + k * 13, 10)
		else:
			pen.tex(ArtPen.silhouette(glyph, Palette.BRASS_DARK), 333 + k * 13, 10)
	pen.chunky(
		"%d/%d" % [completed.size(), aisles.size()],
		463,
		10,
		Palette.GOLD,
		1.0,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	pen.nine(BoosterArt.LED, 520, 4, 116, 20, Vector4i(4, 4, 4, 4))
	pen.tex(BoosterArt.CART, 528, 10)
	pen.pix("CART", 545, 11, Palette.MUSTARD_LIGHT)
	var pu: float = now - (v.punch_t as float)
	var ps: float = 1.0
	if not rm and pu < 0.22:
		ps = lerpf(v.punch_s, 1.0, BoosterPageDraw.e_out(pu / 0.22))
	var count: String = "%d/%d" % [v.cart, v.limit]
	var words: ImageTexture = ArtPen.word_texture(count, Palette.GOLD, true)
	if ps > 1.001:
		var w: float = roundf(words.get_width() * ps)
		var h: float = roundf(8 * ps)
		pen.canvas.draw_texture_rect(
			words,
			Rect2(
				pen.at(roundf(628 - words.get_width() / 2.0 - w / 2.0), roundf(14 - h / 2.0)),
				pen.size_of(w, h)
			),
			false
		)
	else:
		pen.chunky(
			count,
			628,
			10,
			Palette.PAPER if pu < 0.1 else Palette.GOLD,
			1.0,
			HORIZONTAL_ALIGNMENT_RIGHT
		)


## The page's hit list this frame, bottom first: each {rect (art px), id, act, card?}.
static func hits(page: BoosterPage) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if page.run == null:
		return list
	if page.shutter == BoosterPage.Shutter.DOWN:
		list.append(_hit(Rect2(0, 28, BoosterArt.AW, 332), "rollup", page.openings.roll_up))
		return list
	if page.page_done():
		list.append(_hit(Rect2(240, 7, 82, 20), "tab2", page.press_next))
	for k: int in page.run.starter.core_cards.size():
		list.append(
			_hit(
				Rect2(regular_x(k) + 4, 168 + DY, 30, 40),
				"reg%d" % k,
				page.counter.click_regular.bind(k)
			)
		)
	for b: BoosterOpening in page.boosters:
		_booster_hits(page, b, list)
	if not page.openings.pick_layout():
		list.append(_hit(key_rect(), "restock", page.counter.arm_restock))
	list.append(_hit(Rect2(BoosterArt.TITLE_RECT), "title", page.press_title))
	list.append(_hit(Rect2(BoosterArt.PRIMARY_RECT), "primary", page.primary.bind("click")))
	if page.tray_slot >= 0:
		_tray_hits(page, list)
	return list


static func _booster_hits(page: BoosterPage, b: BoosterOpening, list: Array[Dictionary]) -> void:
	if b.state == BoosterOpening.State.SEALED:
		if b.sink_t != INF or page.now < b.drop_t + page.tuning.drop_s:
			return
		var at: Vector2 = BoosterArt.pouch_pos(b.cx)
		var act: Callable = (
			page.openings.pick_booster.bind(b.index)
			if page.picking()
			else page.openings.open_booster.bind(b.index, "click")
		)
		list.append(
			_hit(
				Rect2(at.x, at.y - 6, BoosterArt.BW, BoosterArt.BH + 6), "booster%d" % b.index, act
			)
		)
		return
	if b.state == BoosterOpening.State.GONE:
		return
	if b.state == BoosterOpening.State.OPEN:
		for k: int in b.cards.size():
			var entry: Dictionary = _hit(
				BoosterArt.card_rect(b.cx, k), "card%d_%d" % [b.index, k], Callable()
			)
			entry["card"] = b.cards[k]
			list.append(entry)
	var wk: int = b.waiting_k()
	if wk >= 0 and b.at_rest(page.tuning):
		var p: Vector2 = BoosterArt.fan_pos(b.cx, wk)
		list.append(
			_hit(
				Rect2(p.x - 4, p.y - 6, BoosterArt.CW + 8, BoosterArt.CH + 8),
				"hit%d" % b.index,
				page.openings.flip_hit.bind(b.index)
			)
		)
	if page.restock_armed and page.counter.restockable(b.index):
		var p0: Vector2 = BoosterArt.fan_pos(b.cx, 0)
		list.append(
			_hit(
				Rect2(p0.x, p0.y - 8, BoosterArt.FAN_STEP * 2 + BoosterArt.CW, BoosterArt.CH + 16),
				"rcards%d" % b.index,
				page.counter.restock.bind(b.index)
			)
		)


static func _tray_hits(page: BoosterPage, list: Array[Dictionary]) -> void:
	var aisles: Array[AisleDefinition] = page.counter.tray_aisles()
	var offer: Array[CardDefinition] = page.counter.tray_offer(page.tray_tab)
	var w: float = tray_width(offer.size())
	var x: float = TRAY_RECT.position.x
	var y: float = TRAY_RECT.position.y
	list.append(_hit(Rect2(x, y, w, TRAY_RECT.size.y), "tray", Callable()))
	for k: int in aisles.size():
		list.append(
			_hit(
				Rect2(x + 8 + k * 24, y + 16, 22, 16),
				"ttab%d" % k,
				page.counter.set_tray_tab.bind(k)
			)
		)
	var n: int = offer.size()
	var mx0: float = x + roundf((w - (n * MINI_W + (n - 1) * MINI_GAP)) / 2.0)
	for k: int in n:
		if StartSetupRules.swap_block(page.run, page.profile, page.tray_slot, offer[k]) != &"":
			continue
		list.append(
			_hit(
				Rect2(mx0 + k * (MINI_W + MINI_GAP), y + 38, MINI_W, 90),
				"mini%d" % k,
				page.counter.swap_to.bind(k, "click")
			)
		)


static func _hit(rect: Rect2, id: String, act: Callable) -> Dictionary:
	return {"rect": rect, "id": id, "act": act}
