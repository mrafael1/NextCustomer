class_name BoosterChromeDraw
extends RefCounted
## YOUR STORE's keys and bars (v1.32; trimmed for the aisle board, v1.40): the floor row (TITLE,
## RESTOCK's key, the primary key, a flashed message), the top bar both pages share (the page
## tabs and the CART count), RESTOCK's call round a returnable fan, the page's hit list and its
## hover tips.

## The top bar's CART LED and the page tabs (art px).
const CART_LED := Rect2i(520, 4, 116, 20)
const TAB_X := 8
const TAB_STEP := 84
const TAB_W := 82
## The flashed message's plate on the floor row (art px).
const MESSAGE_RECT := Rect2i(96, 326, 360, 18)
## The tutorial's lock word (the swap plate, RESTOCK's key).
const LOCKED_TEXT := "LOCKED"

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


## The RESTOCK key on the floor row, just left of the primary key and as tall (v1.32 feedback):
## the refresh glyph, then its label.
static func key_rect() -> Rect2:
	var primary: Rect2i = BoosterArt.PRIMARY_RECT
	var w: float = 6 + BoosterArt.REFRESH_GLYPH.size() + 5 + ArtPen.pix_width("RESTOCK") + 7
	return Rect2(primary.position.x - BoosterArt.KEY_GAP - w, primary.position.y, w, primary.size.y)


## Whether the RESTOCK key shows: RESTOCK unlocked for the profile (a tutorial lock then draws it
## LOCKED; v1.40: a profile without RESTOCK never sees the key, locked or not).
static func key_shown(page: BoosterPage) -> bool:
	return page.counter.restock_unlocked()


## Whether the tutorial locks RESTOCK's key (drawn grey with a padlock, LOCKED; refused).
static func key_locked(page: BoosterPage) -> bool:
	return StartBoardActions.is_locked(page.actions, TutorialAnchors.RESTOCK)


## RESTOCK's key on the floor row: teal with a brass refresh glyph when ready, lit under the
## pointer, brass and pressed in while armed (its glyph turning; a second click cancels), grey
## once used; hidden while locked.
static func _restock_key(pen: ArtPen, page: BoosterPage) -> void:
	if not key_shown(page):
		return
	if key_locked(page):
		_locked_key(pen)
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


## RESTOCK's key while the tutorial locks it (the mock-up's locked state): grey as when used, a
## padlock for its refresh glyph, LOCKED under its word.
static func _locked_key(pen: ArtPen) -> void:
	var k: Rect2 = key_rect()
	var x: float = k.position.x
	var y: float = k.position.y
	var h: float = k.size.y
	pen.nine(BoosterArt.KEY_OFF, x, y, k.size.x, h, Vector4i(3, 7, 3, 4))
	pen.tex(BoosterArt.PADLOCK, x + 6, y + roundf((h - 10) / 2.0))
	var tx: float = x + 6 + BoosterArt.REFRESH_GLYPH.size() + 5
	var tw: float = k.end.x - 7 - tx
	pen.pix("RESTOCK", tx + tw / 2.0, y + 5, Palette.STEEL_DARK, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.caps(
		LOCKED_TEXT, tx + tw / 2.0, y + h - 9, Palette.STEEL_DARK, 1.0, HORIZONTAL_ALIGNMENT_CENTER
	)


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


static func _hit(rect: Rect2, id: String, act: Callable) -> Dictionary:
	return {"rect": rect, "id": id, "act": act}


## The floor row: TITLE, RESTOCK's key, a flashed message while it shows, the primary key.
static func floor_row(pen: ArtPen, page: BoosterPage) -> void:
	_title_plate(pen, page)
	_message(pen, page)
	_restock_key(pen, page)
	_primary(pen, page)


## A flashed message (a refused or unsaved action) on an LED plate, only while it shows: the page
## has no standing hint line (v1.40).
static func _message(pen: ArtPen, page: BoosterPage) -> void:
	var line: String = page.hint_line()
	if line == "":
		return
	var r: Rect2 = message_rect(page)
	pen.nine(BoosterArt.LED, r.position.x, r.position.y, r.size.x, r.size.y, Vector4i(4, 4, 4, 4))
	pen.pix(
		line,
		r.position.x + r.size.x / 2.0,
		r.position.y + 6,
		Palette.GOLD,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## The message plate: MESSAGE_RECT, cut short of RESTOCK's key while the key shows.
static func message_rect(page: BoosterPage) -> Rect2:
	var r: Rect2 = Rect2(MESSAGE_RECT)
	if key_shown(page):
		r.size.x = minf(r.size.x, key_rect().position.x - BoosterArt.HINT_MARGIN - r.position.x)
	return r


## The primary key's face lift this frame (BoosterPageDraw.key_lift) once NEXT is armed: the arm
## hop, then the idle press-bob, at rest while hovered; its rect stays PRIMARY_RECT.
static func primary_lift(page: BoosterPage) -> int:
	var armed_t: float = INF
	if page.page_done() and not page.restock_armed:
		armed_t = page.complete_t + 0.3
	var enabled: bool = page.primary_label()[2]
	var rest: bool = enabled and page.is_hovered("primary")
	return BoosterPageDraw.key_lift(page.now, armed_t, page.tuning, page.rm, rest)


## The primary key: its label, its sub-label, the press-bob once NEXT is armed (primary_lift;
## v1.32 feedback: no chase bulbs; the label rides the lifted face).
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
	var quiet: bool = enabled and (label[0] as String).begins_with("SKIP")
	BoosterPageDraw.lifted_key(
		pen,
		BoosterArt.BUTTON if enabled and not quiet else BoosterArt.BUTTON_TEAL,
		x + sh,
		y,
		w,
		h,
		lift
	)
	pen.pix(
		label[0],
		x + sh + w / 2.0,
		y - lift + 5,
		Palette.PAPER if enabled else Palette.TEAL_PALE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	pen.caps(
		label[1],
		x + sh + w / 2.0,
		y - lift + h - 9,
		Palette.MUSTARD_PALE if enabled and not quiet else Palette.TEAL_PALE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if hv:
		pen.tex(BoosterArt.TICK, x - 7, y + h / 2.0 - 3)


## Page tab `k`'s rect (0: YOUR STORE, 1: YOUR BUILD), as both pages draw and hit it.
static func tab_rect(k: int) -> Rect2:
	return Rect2(TAB_X + k * TAB_STEP, 7, TAB_W, 20)


static func top_bar(pen: ArtPen, page: BoosterPage) -> void:
	top_bar_view(
		pen,
		{
			"now": page.now,
			"rm": page.rm,
			"tab": 1,
			"blink": page.page_done() and not page.is_hovered("tab2"),
			"cart": page.cart_shown,
			"limit": page.run.balance.deck_limit,
			"punch_t": page.cart_punch_t,
			"punch_s": page.cart_punch_s,
		}
	)


## The top bar from `v` (both pages draw it): now, rm, tab (the page shown), blink (the other
## tab's gold dot), cart, limit, punch_t and punch_s (the CART count's punch). Since v1.40 it
## holds only the page tabs and the CART count (no clock, no aisle counter).
static func top_bar_view(pen: ArtPen, v: Dictionary) -> void:
	var now: float = v.now
	var rm: bool = v.rm
	var tab: int = v.tab
	pen.r(0, 0, BoosterArt.AW, 27, Palette.TEAL_BLACK)
	pen.d(0, 0, BoosterArt.AW, 27, Palette.SLATE_DARK, 4)
	pen.r(0, 27, BoosterArt.AW, 1, Palette.INK)
	for k: int in 2:
		var x: float = tab_rect(k).position.x
		var on: bool = k + 1 == tab
		var y: float = 5 if on else 7
		pen.nine(
			BoosterArt.TAB_PICKED if on else BoosterArt.TAB,
			x,
			y,
			TAB_W,
			27 - y,
			Vector4i(3, 3, 3, 3)
		)
		pen.chunky(str(k + 1), x + 6, y + 6, Palette.TOMATO if on else Palette.TEAL_PALE)
		pen.pix(
			"YOUR STORE" if k == 0 else "YOUR BUILD",
			x + 15,
			y + 7,
			Palette.INK if on else Palette.PAPER
		)
		if not on and v.blink and not rm and int(floorf(now * 3)) % 2 == 1:
			pen.r(x + TAB_W - 6, y + 4, 2, 2, Palette.GOLD)
	pen.nine(
		BoosterArt.LED,
		CART_LED.position.x,
		CART_LED.position.y,
		CART_LED.size.x,
		CART_LED.size.y,
		Vector4i(4, 4, 4, 4)
	)
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


## The rect RESTOCK's call draws round booster `b`'s fan (the fan and its RETURN THIS ONE plate).
static func return_rect(b: BoosterOpening) -> Rect2:
	var fan: Rect2 = b.fan_rect()
	return Rect2(fan.position.x - 4, fan.position.y - 6, fan.size.x + 8, fan.size.y + 8)


## Booster `b`'s RETURN THIS ONE plate over its fan while RESTOCK is armed.
static func return_plate(b: BoosterOpening) -> Rect2:
	var r: Rect2 = return_rect(b)
	var tw: float = ArtPen.word_texture("RETURN THIS ONE", Palette.INK, false).get_width() + 8
	return Rect2(roundf(r.position.x + r.size.x / 2.0 - tw / 2.0), r.position.y - 10, tw, 9)


## While RESTOCK is armed: a walking dashed line round each returnable fan, RETURN THIS ONE on it.
static func restock_call(pen: ArtPen, page: BoosterPage) -> void:
	if not page.restock_armed:
		return
	for b: BoosterOpening in page.boosters:
		if not page.counter.restockable(b.index):
			continue
		var r: Rect2 = return_rect(b)
		var hv: bool = page.is_hovered("rcards%d" % b.index)
		var phase: int = 0 if page.rm else int(floorf(page.now / 0.08)) % 4
		SwapWindowDraw.dashes(pen, r, Palette.GOLD if hv else Palette.BRASS, 0 if hv else phase)
		var plate: Rect2 = return_plate(b)
		pen.rn(
			plate.position.x, plate.position.y, plate.size.x, plate.size.y, Palette.VELVET_DARKEST
		)
		pen.caps(
			"RETURN THIS ONE",
			plate.position.x + plate.size.x / 2.0,
			plate.position.y + 2,
			Palette.GOLD if hv else Palette.MUSTARD,
			1.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)


## The page's hit list this frame, bottom first: each {rect (art px), id, act, card?}.
static func hits(page: BoosterPage) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if page.run == null:
		return list
	if page.page_done():
		list.append(_hit(tab_rect(1), "tab2", page.press_next))
	for b: BoosterOpening in page.shown_boosters():
		_booster_hits(page, b, list)
	if key_shown(page):
		list.append(_hit(key_rect(), "restock", page.counter.arm_restock))
	list.append(_hit(Rect2(BoosterArt.TITLE_RECT), "title", page.press_title))
	list.append(_hit(Rect2(BoosterArt.PRIMARY_RECT), "primary", page.primary.bind("click")))
	return list


## Booster `b`'s hits: a pouch left sealed on the counter (its
## save failed); its cards once open (the hover that pops the full card); its fan while RESTOCK is
## armed.
static func _booster_hits(page: BoosterPage, b: BoosterOpening, list: Array[Dictionary]) -> void:
	var id: String = "booster%d" % b.index
	if b.state == BoosterOpening.State.SEALED:
		if page.roulette.landed(b) and not page.roulette.busy():
			var at: Vector2 = b.pouch_pos()
			var act: Callable = page.openings.open_booster.bind(b.index, "click")
			list.append(_hit(Rect2(at.x, at.y - 6, BoosterArt.BW, BoosterArt.BH + 6), id, act))
		return
	if b.state != BoosterOpening.State.OPEN:
		return
	if page.restock_armed:
		if page.counter.restockable(b.index):
			var all: Rect2 = return_rect(b).merge(return_plate(b))
			list.append(_hit(all, "rcards%d" % b.index, page.counter.restock.bind(b.index)))
		return
	for k: int in b.cards.size():
		var entry: Dictionary = _hit(b.card_rect(k), "card%d_%d" % [b.index, k], Callable())
		entry["card"] = b.cards[k]
		list.append(entry)


## The page's hover tips this frame (StartTips entries, bottom first): each opened booster's
## cards with their family chips while the fan shows full cards. Compact cards have none: the
## hovered card pops up in full, with its rule (AisleBoardDraw.hover_card).
static func tip_entries(page: BoosterPage) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if page.run == null or page.restock_armed:
		return list
	for b: BoosterOpening in page.boosters:
		if b.state != BoosterOpening.State.OPEN or b.compact:
			continue
		var tag: String = BoosterArt.short_name(BoosterPageDraw.aisle_def(page, b.aisle))
		for k: int in b.cards.size():
			var rare: bool = k < b.rares.size() and b.rares[k]
			StartTips.card_entries(
				list, b.cards[k], rare, b.fan_pos(k), "card%d_%d" % [b.index, k], tag
			)
	return list
