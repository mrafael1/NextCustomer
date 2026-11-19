class_name BuildPageDraw
extends RefCounted
## YOUR BUILD's drawing (BuildPage, v1.32; the mock-up start_boosters_v3's drawPage2 and its
## parts), in art px through each layer's ArtPen: the staff room with the corkboard's badge, the
## floor row and the top bar; the REGULARS crate is BuildRegulars'. The BADGE PINS step is
## PinStepDraw's, the OPEN STORE flight StoreFlight's. (The starter packs' bench, deck pile, strips,
## stamps and plan note went with the packs in v1.41.)

const PIN_BADGE := preload("res://art/scenery/pin_badge.png")
const SIGN := preload("res://art/frames/sign.png")
## The ticker while OPEN STORE waits for the BADGE PINS step (cleared while the step is open).
const PINS_FIRST_HINT := "BADGE PINS FIRST · PRESS P"


static func draw(layer: BuildLayer) -> void:
	var page: BuildPage = layer.page
	if page.run == null:
		return
	var pen: ArtPen = layer.pen
	match layer.layer:
		"Room":
			pen.tex(StaffRoomArt.texture(), 0, 0)
			_pins_board(pen, page)
			BuildRegulars.draw(pen, page)
		"Over2":
			for p: Dictionary in page.sparks:
				if page.now >= (p.t as float):
					pen.tex_c(BoosterArt.SPARKLE, p.x, p.y)
		"Floor":
			_floor(pen, page)
		"Top":
			BoosterChromeDraw.top_bar_view(pen, BuildPageDraw.top_view(page))
		"Pins":
			PinStepDraw.draw(pen, page)
		"Store":
			if page.flight != null:
				page.flight.draw(pen)


## Whether card `card` shows RARE (a BIG or GOLDEN product, a rare or legendary coupon).
static func rare(card: CardDefinition, balance: BalanceDefinition) -> bool:
	if card.is_product():
		return card.tier != CardDefinition.Tier.PLAIN
	var machine: MachineDefinition = balance.machine
	return machine != null and machine.coupon_rarity(card) >= MachinePrize.Rarity.RARE


## The corkboard: the BADGE PINS sign and the run's name badge with the worn pin (or its empty
## ring); it blinks gold while OPEN STORE waits for the pins.
static func _pins_board(pen: ArtPen, page: BuildPage) -> void:
	pen.nine(SIGN, 54, 63, 84, 14, Vector4i(3, 3, 3, 3))
	pen.chunky("BADGE PINS", 96, 66, Palette.CREAM, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var bx: float = 47
	var by: float = 92
	pen.r(bx + 2, by + 2, 50, 51, Palette.BROWN_DARKEST)
	pen.tex(PIN_BADGE, bx, by, Color.WHITE, 0.5)
	pen.caps("NEXT", bx + 25, by + 7, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.caps("CUSTOMER", bx + 25, by + 13, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.pix("CASHIER", bx + 5, by + 25, Palette.INK)
	var cork: Vector2i = BuildPage.CORK_PIN
	var flying: bool = not page.rm and page.now - page.fly_t < page.tuning.pin_fly_s
	if not page.run.pins.is_empty() and not flying:
		var pu: float = page.now - page.fly_t - page.tuning.pin_fly_s
		var pop: int = 0
		if not page.rm and pu >= 0.0 and pu < 0.14:
			pop = 2 if pu < 0.07 else 1
		var pin: PinDefinition = page.run.pins[0]
		PinStepDraw.face(
			pen, pin, page.pins.index_of(pin), cork.x - pop, cork.y - pop, 16 + pop * 2, 16
		)
	else:
		PinStepDraw.empty(pen, cork.x, cork.y, 16)
	pen.r(bx + 24, by - 3, 3, 3, Palette.TOMATO)
	pen.r(bx + 24, by - 3, 1, 1, Palette.TOMATO_LIGHT)
	if (
		page.pins_pending()
		and not page.pins_open
		and not page.rm
		and int(floorf(page.now * 2.5)) % 2 == 1
	):
		pen.r(bx - 2, by - 2, 54, 1, Palette.GOLD)
		pen.r(bx - 2, by + 52, 54, 1, Palette.GOLD)
		pen.r(bx - 2, by - 2, 1, 55, Palette.GOLD)
		pen.r(bx + 51, by - 2, 1, 55, Palette.GOLD)
	if page.is_hovered("pins"):
		pen.r(43, 73, 56, 87, Color(Palette.PAPER, 0.18))
		pen.tex(BoosterArt.TICK, 34, 112)


## The floor row: ‹ STORE, the hint LED across the floor and the primary key.
static func _floor(pen: ArtPen, page: BuildPage) -> void:
	var back: Rect2i = BuildPage.BACK_RECT
	var hv: bool = page.is_hovered("back")
	var bx: float = back.position.x + (2 if hv and not page.rm else 0)
	pen.nine(
		BoosterArt.BUTTON_TEAL, bx, back.position.y, back.size.x, back.size.y, Vector4i(3, 3, 3, 3)
	)
	pen.pix(
		"‹ STORE",
		bx + back.size.x / 2.0,
		back.position.y + 8,
		Palette.PAPER,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if hv:
		pen.tex(BoosterArt.TICK, 1, back.position.y + 10)
	BuildRegulars.draw_keys(pen, page)
	hint_led(pen, page)
	_primary(pen, page)


## The floor's hint LED (the ticker) and its line typing out; the OPEN STORE flight draws it again
## over its dim, so its skip line reads lit.
static func hint_led(pen: ArtPen, page: BuildPage) -> void:
	var led: Rect2i = BuildPage.LED_RECT
	pen.nine(
		BoosterArt.LED, led.position.x, led.position.y, led.size.x, led.size.y, Vector4i(4, 4, 4, 4)
	)
	var line: String = BuildPageDraw.hint_line(page)
	var n: int = (
		line.length() if page.rm else int(floorf((page.now - BuildPageDraw.hint_start(page)) * 40))
	)
	pen.pix(
		line.substr(0, n),
		led.get_center().x,
		led.position.y + 6,
		Palette.GOLD,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## The primary key: lit, its label and sub-label, armed once the cart is ready (no BADGE PINS step
## waiting); teal and dim while the pins step is open.
static func _primary(pen: ArtPen, page: BuildPage) -> void:
	var rect: Rect2 = Rect2(BuildPage.PRIMARY_RECT)
	var label: Array = BuildPageDraw.primary_label(page)
	if page.pins_open:
		var x: float = rect.position.x
		var y: float = rect.position.y
		pen.nine(BoosterArt.BUTTON_TEAL, x, y, rect.size.x, rect.size.y, Vector4i(3, 3, 3, 3))
		var cx: float = x + rect.size.x / 2.0
		pen.pix(label[0] as String, cx, y + 5, Palette.TEAL_PALE, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
		pen.caps(
			label[1] as String,
			cx,
			y + rect.size.y - 9,
			Palette.TEAL_PALE,
			1.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		return
	var armed: float = INF
	if not page.pins_pending() and not page.regulars_pending():
		armed = page.page_t + 0.3
	key_button(
		pen, page, rect, label[0] as String, label[1] as String, label[2] as bool, "primary", armed
	)


## A key (the mock-up's drawPrimary) at art rect `rect`: lit or teal, `label` over `sub`, from
## `armed_t` (INF: never) the arm hop then the idle press-bob, at rest while hovered
## (BoosterPageDraw.key_lift; v1.32 feedback: no chase bulbs; the labels ride the lifted face),
## pushed right under the pointer (hit id `id`, its hit rect `rect`, never resized).
static func key_button(
	pen: ArtPen,
	page: BuildPage,
	rect: Rect2,
	label: String,
	sub: String,
	lit: bool,
	id: String,
	armed_t: float
) -> void:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	var hv: bool = page.is_hovered(id) and lit
	var lift: int = BoosterPageDraw.key_lift(page.now, armed_t, page.tuning, page.rm, hv)
	var sh: float = 2.0 if hv and not page.rm else 0.0
	BoosterPageDraw.lifted_key(
		pen, BoosterArt.BUTTON if lit else BoosterArt.BUTTON_TEAL, x + sh, y, w, h, lift
	)
	var cx: float = x + sh + w / 2.0
	pen.pix(
		label,
		cx,
		y - lift + 5,
		Palette.PAPER if lit else Palette.TEAL_PALE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	pen.caps(
		sub,
		cx,
		y - lift + h - 9,
		Palette.MUSTARD_PALE if lit else Palette.TEAL_PALE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if hv:
		pen.tex(BoosterArt.TICK, x - 7, y + h / 2.0 - 3)


## The page's hits this frame, bottom first: each {rect (art px), id, act}. The flight takes every
## click (a skip); the pins step is modal.
static func hits(page: BuildPage) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if page.run == null:
		return list
	var full: Rect2 = Rect2(0, 0, BoosterArt.AW, BoosterArt.AH)
	if page.flight != null:
		list.append(_hit(full, "modal_store", Callable()))
		return list
	list.append(_hit(BoosterChromeDraw.tab_rect(0), "tab1", page.press_store))
	list.append(_hit(Rect2(43, 73, 56, 87), "pins", page.pins.open.bind(page.now)))
	list.append(_hit(Rect2(BuildPage.BACK_RECT), "back", page.press_store))
	BuildRegulars.hits(page, list)
	list.append(_hit(Rect2(BuildPage.PRIMARY_RECT), "primary", page.primary.bind("click")))
	if page.pins_open:
		PinStepDraw.hits(page, list)
	return list


static func _hit(rect: Rect2, id: String, act: Callable) -> Dictionary:
	return {"rect": rect, "id": id, "act": act}


## Four sparkles round art rect (`x`, `y`, `w`, `h`), `gap` s apart from `t0`, on `page`.
static func add_sparkles(
	page: BuildPage, x: float, y: float, w: float, h: float, t0: float, gap: float
) -> void:
	var places: Array[Vector2] = [
		Vector2(x - 2, y + 6),
		Vector2(x + w - 4, y + 2),
		Vector2(x + w - 2, y + h - 10),
		Vector2(x - 4, y + h - 20)
	]
	for k: int in places.size():
		page.sparks.append({"x": places[k].x, "y": places[k].y, "t": t0 + k * gap})


## The primary key's label, sub-label and whether it is lit.
static func primary_label(page: BuildPage) -> Array:
	if page.pins_pending():
		return ["BADGE PINS", "THEN OPEN STORE", true]
	if page.regulars_pending():
		return ["OPEN STORE ›", "KEEP REGULARS FIRST", false]
	return ["OPEN STORE ›", "%d CARDS" % page.cart_target(), true]


## The hint LED's line: a flashed message for 2 s, else the state's hint.
static func hint_line(page: BuildPage) -> String:
	var line: String = BuildPage.READY_HINT
	if page.flight != null:
		line = StoreFlight.SKIP_HINT
	elif page.message != "" and page.now - page.message_t < 2.0:
		line = page.message
	elif page.pins_open:
		line = ""
	elif page.pins_pending():
		line = PINS_FIRST_HINT
	elif page.regulars_pending():
		line = BuildRegulars.HINT
	elif page.hint != "":
		line = page.hint
	return line


static func hint_start(page: BuildPage) -> float:
	if page.flight != null:
		return page.flight.t0
	return page.message_t if page.message != "" and page.now - page.message_t < 2.0 else page.hint_t


## The top bar's view (BoosterChromeDraw.top_bar_view) on page 2: the YOUR BUILD tab.
static func top_view(page: BuildPage) -> Dictionary:
	return {
		"now": page.now,
		"rm": page.rm,
		"tab": 2,
		"blink": false,
		"cart": page.cart_shown,
		"limit": page.run.balance.deck_limit,
		"punch_t": page.cart_punch_t,
		"punch_s": page.cart_punch_s,
	}


## Whether page 2 shows no hover tip and no tutorial callout: no run, the OPEN STORE flight, the
## BADGE PINS step.
static func tips_blocked(page: BuildPage) -> bool:
	return page.run == null or page.flight != null or page.pins_open
