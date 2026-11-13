class_name BoosterChromeDraw
extends RefCounted
## YOUR STORE's furniture and keys (v1.32, the mock-up's drawCrate, drawTote, drawCounterPlates,
## drawHintLED, drawPrimary, drawShutterP1 and drawTopBar; the crate as the swap window's button
## from docs/art/mockups/start_regulars_swap.html): the regulars' crate, the returns tote, the
## counter plates, the floor row (TITLE, the hint LED, RESTOCK's key, the primary key), the
## storefront at dawn and the top bar; and the page's hit list.

const DY := BoosterArt.DY
## The crate's button (it opens the swap window) and its gold dashed outline on hover.
const CRATE_RECT := Rect2(4, 158 + DY, 156, 74)
const CRATE_OUTLINE := Rect2(1, 155 + DY, 162, 80)
const SPARKLE := BoosterArt.SPARKLE
const STAMP_RING := preload("res://art/icons/stamp_ring.png")

## The item sprites drawn so far, held so they stay loaded: a texture loaded for the first time
## inside a draw call (or freed and loaded again there) is drawn blank white on that frame.
static var _sprites: Dictionary[String, Texture2D] = {}


## Card `card`'s item sprite (its coupon icon for a coupon), loaded once and kept; the swap window
## warms its cards' sprites through this before they are drawn.
static func sprite(card: CardDefinition) -> Texture2D:
	if not _sprites.has(String(card.id)):
		var texture: Texture2D = ArtStyle.item_sprite(card)
		_sprites[String(card.id)] = texture if texture != null else ArtStyle.coupon_icon(card)
	return _sprites[String(card.id)]


static func _sprite(card: CardDefinition) -> Texture2D:
	return sprite(card)


static func _completed(page: BoosterPage) -> Array[AisleDefinition]:
	return StartSetupRules.completed(page.run.balance, page.profile)


## The RESTOCK key on the floor row, just left of the primary key and as tall (v1.32 feedback):
## the refresh glyph, then its label.
static func key_rect() -> Rect2:
	var primary: Rect2i = BoosterArt.PRIMARY_RECT
	var w: float = 6 + BoosterArt.REFRESH_GLYPH.size() + 5 + ArtPen.pix_width("RESTOCK") + 7
	return Rect2(primary.position.x - BoosterArt.KEY_GAP - w, primary.position.y, w, primary.size.y)


## Whether the RESTOCK key shows: RESTOCK unlocked, and the counter past PICK 2 OF 3's dress.
static func key_shown(page: BoosterPage) -> bool:
	return not page.openings.pick_layout() and page.counter.restock_unlocked()


## The hint LED: its full width, its right end cut to HINT_MARGIN short of the RESTOCK key while
## the key shows (the left end stays put, so only the right end moves when the key appears).
static func hint_rect(page: BoosterPage) -> Rect2:
	if not key_shown(page):
		return Rect2(BoosterArt.HINT_RECT)
	var hint: Rect2i = BoosterArt.HINT_RECT
	var right: float = key_rect().position.x - BoosterArt.HINT_MARGIN
	return Rect2(hint.position.x, hint.position.y, right - hint.position.x, hint.size.y)


## The returns tote's bay in the counter front (the old cards fly into it).
static func bay_rect() -> Rect2:
	return Rect2(BoosterArt.BAY_RECT)


## The primary key's face lift this frame (BoosterPageDraw.key_lift) once NEXT is armed: the arm
## hop, then the idle press-bob, at rest while hovered or while Space is held (the hold ring
## stays 1 px clear of the face); its rect stays PRIMARY_RECT.
static func primary_lift(page: BoosterPage) -> int:
	var armed_t: float = INF
	if page.page_done() and not page.restock_armed:
		armed_t = page.complete_t + 0.3
	var enabled: bool = page.primary_label()[2]
	var rest: bool = (enabled and page.is_hovered("primary")) or page.hold_t >= 0.0
	return BoosterPageDraw.key_lift(page.now, armed_t, page.tuning, page.rm, rest)


static func regular_x(slot: int) -> float:
	return BoosterArt.REG_X + slot * BoosterArt.REG_STEP


## Whether the crate is the swap window's button now (the store open, the window shut).
static func crate_button(page: BoosterPage) -> bool:
	return page.shutter == BoosterPage.Shutter.UP and not page.swap.active


## The crate of regulars (STANDING ORDER) with its two slats, the swap window's button: it lifts
## with a gold dashed outline on hover; a ⇄ tag bobs on its corner until the window has been
## opened. After the window's DONE each changed regular plays in (the old one drops away, the new
## one drops in with its aisle chip and its ⇄ chip).
static func crate(pen: ArtPen, page: BoosterPage) -> void:
	var now: float = page.now
	var button: bool = crate_button(page)
	var live: bool = page.swap.is_live()
	var hv: bool = button and live and page.is_hovered("crate")
	var lift: float = 3.0 if hv and not page.rm else 0.0
	pen.r(4, 186 + DY, 156, 46, Palette.INK)
	pen.r(5, 187 + DY, 154, 44, Palette.WOOD_DARKEST)
	var cards: Array[CardDefinition] = page.run.starter.core_cards
	var chips: Dictionary[int, float] = {}
	for k: int in cards.size():
		var x: float = regular_x(k)
		var y: float = 168 + DY - lift
		if hv and not page.rm:
			var wave: float = now - page.hover_t0 - k * 0.04
			if wave > 0 and wave < 0.12:
				y -= 2
		var dy: float = 0.0
		var st: float = page.swap_t.get(k, -INF)
		var play: float = maxf(page.tuning.swap_play_in_s, 0.001)
		var u: float = (now - st) / play
		if not page.rm and u < 1.0 and page.swap_from.has(k):
			if u < 0.5:
				var falls: float = BoosterPageDraw.stepped(
					BoosterPageDraw.e_in(maxf(0.0, u) * 2) * 24, 2
				)
				pen.tex(_sprite(page.swap_from[k]), x, y + falls)
				continue
			dy = -6 + BoosterPageDraw.stepped(BoosterPageDraw.e_out((u - 0.5) * 2) * 6, 2)
		if page.complete_t != INF and not page.rm:
			var hu: float = now - page.complete_t - 0.05 * k
			if hu > 0 and hu < 0.1:
				dy -= 2
		pen.tex(_sprite(cards[k]), x, y + dy)
		pen.tex(BoosterArt.PRICE_TAG, x + 36, y + 6 + dy)
		if cards[k] != page.run.start_setup.originals[k]:
			chips[k] = now - st - play * 0.75
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
	for k: int in chips:
		_swapped_chips(pen, page, k, regular_x(k) + 8, 205 + DY, chips[k])
	if not button:
		return
	if hv:
		var phase: int = 0 if page.rm else int(floorf(now / 0.12)) % 2
		SwapWindowDraw.dashes(pen, CRATE_OUTLINE, Palette.GOLD, phase)
	if live and page.counter.swap_limit() > 0 and not page.swap.seen and page.page_done():
		var bob: float = 0.0 if page.rm else float(int(floorf(now / 0.4)) % 2)
		pen.rn(141, 158 + DY - bob, 17, 14, Palette.TEAL)
		pen.r(142, 159 + DY - bob, 15, 1, Palette.TEAL_LIGHT)
		pen.tex(BoosterArt.SWAP, 145, 160 + DY - bob)


## A swapped regular's chips on the crate's front under it, at `x`, `y`: its ⇄ chip (a run-only
## regular) and its aisle chip, popping up as it lands (`tu` s after).
static func _swapped_chips(
	pen: ArtPen, page: BoosterPage, k: int, x: float, y: float, tu: float
) -> void:
	if tu < 0 and not page.rm:
		return
	var pop: float = 2.0 if not page.rm and tu < 0.12 else 0.0
	pen.rn(x, y - pop, 13, 12, Palette.TEAL)
	pen.r(x + 1, y + 1 - pop, 11, 1, Palette.TEAL_LIGHT)
	pen.tex(BoosterArt.SWAP, x + 2, y + 1 - pop)
	var aisle: AisleDefinition = page.run.balance.aisle_of(page.run.starter.core_cards[k])
	if aisle == null:
		return
	var ramp: Array[Color] = BoosterArt.ramp(aisle.id)
	pen.rn(x + 14, y - pop, 13, 12, ramp[1])
	pen.r(x + 15, y + 1 - pop, 11, 1, ramp[0])
	var glyph: Texture2D = BoosterArt.glyph(aisle.id)
	if glyph != null:
		pen.tex(glyph, x + 16, y + 1 - pop)


## The window's dawn across the crate's front (additive layer).
static func crate_glow(pen: ArtPen, _page: BoosterPage) -> void:
	for y: int in range(205, 231):
		pen.d(5 + roundf((y - 205) * 1.2), y + DY, 92, 1, Palette.MUSTARD_DARKEST, 4)


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


## The counter's plates: the regulars' (SWAP REGULARS with its ⇄ chip and the swaps left as
## "⇄ N"; a padlock while none is unlocked) and each booster's.
static func counter_plates(pen: ArtPen, page: BoosterPage) -> void:
	var button: bool = crate_button(page)
	var live: bool = page.swap.is_live()
	var limit: int = page.counter.swap_limit()
	var label: String = "YOUR REGULARS"
	if button and limit > 0:
		label = "SWAP REGULARS" if live else "SWAP AFTER OPENING"
	var plate_lit: bool = button and live and page.is_hovered("crate")
	pen.nine(
		BoosterArt.PLATE_LIT if plate_lit else BoosterArt.PLATE,
		6,
		241 + DY,
		152,
		17,
		Vector4i(4, 4, 4, 4)
	)
	if button and limit > 0 and live:
		pen.rn(9, 243 + DY, 13, 13, Palette.TEAL_LIGHT if plate_lit else Palette.TEAL)
		pen.r(10, 244 + DY, 11, 1, Palette.TEAL_PALE)
		pen.tex(BoosterArt.SWAP, 11, 244 + DY)
		pen.pix(label, 26, 246 + DY, Palette.INK)
	else:
		pen.pix(label, 10, 246 + DY, Palette.INK)
	if limit < 1 and button:
		pen.tex(BoosterArt.PADLOCK, 144, 244 + DY)
	if limit >= 1:
		var left: int = maxi(0, limit - page.counter.swaps_used())
		var count: String = str(left)
		var lw: float = 9 + 3 + ArtPen.word_texture(count, Palette.GOLD, true).get_width() + 8
		var lx: float = 154 - lw
		pen.nine(BoosterArt.LED, lx, 243 + DY, lw, 12, Vector4i(4, 4, 4, 4))
		pen.tex(BoosterArt.SWAP, lx + 3, 244 + DY)
		pen.chunky(count, lx + 15, 245 + DY, Palette.GOLD if left > 0 else Palette.TOMATO)
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


## Over the bay: the old cards flying into the tote, and the floor row with RESTOCK's key.
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


## RESTOCK's key on the floor row: teal with a brass refresh glyph when ready, lit under the
## pointer, brass and pressed in while armed (its glyph turning; a second click cancels), grey
## once used; hidden while locked or picking.
static func _restock_key(pen: ArtPen, page: BoosterPage) -> void:
	if not key_shown(page):
		return
	var k: Rect2 = key_rect()
	var used: bool = page.counter.restock_block() == &"used"
	var armed: bool = page.restock_armed
	var hv: bool = page.is_hovered("restock") and not used
	var down: float = 2 if armed else 0
	var x: float = k.position.x
	var y: float = k.position.y + down
	var h: float = k.size.y - down
	var ink: Color = Palette.PAPER
	var glyph_ink: Color = Palette.MUSTARD_PALE if hv else Palette.GOLD
	var sub_ink: Color = Palette.TEAL_PALE
	var sub: String = "ONCE A RUN"
	if used:
		pen.nine(BoosterArt.KEY_OFF, x, y, k.size.x, h, Vector4i(3, 7, 3, 4))
		ink = Palette.STEEL_DARK
		glyph_ink = Palette.STEEL_DARK
		sub_ink = Palette.STEEL_DARK
		sub = "USED"
	elif armed:
		pen.nine(BoosterArt.KEY_BRASS, x, y, k.size.x, h, Vector4i(3, 8, 3, 4))
		ink = Palette.INK
		glyph_ink = Palette.VELVET_DARKEST
		sub_ink = Palette.VELVET_DARKEST
		sub = "CANCEL"
	else:
		var frame: Texture2D = BoosterArt.BUTTON_TEAL_LIT if hv else BoosterArt.BUTTON_TEAL
		pen.nine(frame, x, y, k.size.x, h, Vector4i(3, 3, 3, 3))
	var turn: bool = armed and not page.rm and int(floorf(page.now / 0.12)) % 2 == 1
	refresh_glyph(pen, x + 6, y + roundf((h - 9) / 2.0), glyph_ink, turn)
	var tx: float = x + 6 + BoosterArt.REFRESH_GLYPH.size() + 5
	var tw: float = k.end.x - 7 - tx
	pen.pix("RESTOCK", tx + tw / 2.0, y + 5, ink, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.caps(sub, tx + tw / 2.0, y + h - 9, sub_ink, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if hv and not armed:
		pen.tex(BoosterArt.TICK, x - 7, k.position.y + k.size.y / 2.0 - 3)


## The refresh glyph (BoosterArt.REFRESH_GLYPH) at art (`x`, `y`), one art px a dot; `turn`
## draws it a quarter turn round (a turning glyph alternates the two).
static func refresh_glyph(pen: ArtPen, x: float, y: float, colour: Color, turn: bool) -> void:
	var rows: Array[String] = BoosterArt.REFRESH_GLYPH
	var n: int = rows.size()
	for row: int in n:
		for column: int in n:
			var dot: bool = rows[row][column] == "#"
			if turn:
				dot = rows[n - 1 - column][row] == "#"
			if dot:
				pen.r(x + column, y + row, 1, 1, colour)


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
	var r: Rect2 = hint_rect(page)
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


## The primary key: its label, its sub-label, the press-bob once NEXT is armed (primary_lift;
## v1.32 feedback: no chase bulbs; the label rides the lifted face), the Space hold ring.
static func _primary(pen: ArtPen, page: BoosterPage) -> void:
	var r: Rect2 = Rect2(BoosterArt.PRIMARY_RECT)
	var label: Array = page.primary_label()
	var enabled: bool = label[2]
	var x: float = r.position.x
	var y: float = r.position.y
	var w: float = r.size.x
	var h: float = r.size.y
	var lift: int = primary_lift(page)
	var hv: bool = page.is_hovered("primary") and enabled
	var sh: float = 2 if hv and not page.rm else 0
	BoosterPageDraw.lifted_key(
		pen, BoosterArt.BUTTON if enabled else BoosterArt.BUTTON_TEAL, x + sh, y, w, h, lift
	)
	var sub: String = label[1]
	pen.pix(
		label[0],
		x + sh + w / 2.0,
		y - lift + 5,
		Palette.PAPER if enabled else Palette.TEAL_PALE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	pen.caps(
		sub,
		x + sh + w / 2.0,
		y - lift + h - 9,
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
	if crate_button(page):
		list.append(_hit(CRATE_RECT, "crate", page.swap.open_window.bind(false)))
		list.append(_hit(Rect2(6, 241 + DY, 152, 17), "crate", page.swap.open_window.bind(false)))
	for b: BoosterOpening in page.boosters:
		_booster_hits(page, b, list)
	if key_shown(page):
		list.append(_hit(key_rect(), "restock", page.counter.arm_restock))
	list.append(_hit(Rect2(BoosterArt.TITLE_RECT), "title", page.press_title))
	list.append(_hit(Rect2(BoosterArt.PRIMARY_RECT), "primary", page.primary.bind("click")))
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


static func _hit(rect: Rect2, id: String, act: Callable) -> Dictionary:
	return {"rect": rect, "id": id, "act": act}


## The page's hover tips this frame (StartTips entries, bottom first): the crate's regulars while
## the crate is the swap window's button (CLICK SWAP opens the window; locked, or waiting for the
## boosters, their live line says so), then each opened booster's cards with their family chips.
static func tip_entries(page: BoosterPage) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if page.run == null:
		return list
	if crate_button(page):
		var cards: Array[CardDefinition] = page.run.starter.core_cards
		var limit: int = page.counter.swap_limit()
		var live: bool = page.swap.is_live()
		var click: String = StartTips.SWAP_CLICK if live and limit > 0 else ""
		var line: String = ""
		var kind: TipSpec.Live = TipSpec.Live.INFO
		if limit < 1:
			line = StartTips.SWAPS_LOCKED_LIVE
			kind = TipSpec.Live.OFF
		elif not live:
			line = StartTips.SWAPS_WAIT_LIVE
		for k: int in cards.size():
			# The sprites overlap (48 art px on a 34 px step): each takes its step, the last its
			# whole width, above the crate's front.
			var w: float = float(BoosterArt.REG_STEP) if k < cards.size() - 1 else 40.0
			var rect: Rect2 = Rect2(regular_x(k) + 7, 172 + DY, w, 32)
			var key: String = "reg%d|%s|%s|%s" % [k, cards[k].id, click, line]
			var make: Callable = StartTips.card_spec.bind(
				cards[k], StartTips.REGULAR_TAG, click, line, kind
			)
			list.append(StartTips.entry_of(rect, key, make))
	for b: BoosterOpening in page.boosters:
		if b.state != BoosterOpening.State.OPEN:
			continue
		var tag: String = BoosterArt.short_name(BoosterPageDraw.aisle_def(page, b.aisle))
		for k: int in b.cards.size():
			var at: Vector2 = BoosterArt.card_rect(b.cx, k).position
			var rare: bool = k < b.rares.size() and b.rares[k]
			StartTips.card_entries(list, b.cards[k], rare, at, "card%d_%d" % [b.index, k], tag)
	return list
