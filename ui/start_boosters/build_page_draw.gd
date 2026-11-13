class_name BuildPageDraw
extends RefCounted
## YOUR BUILD's drawing (BuildPage, v1.32; the mock-up start_boosters_v3's drawPage2 and its
## parts), in art px through each layer's ArtPen: the staff room with the corkboard's badge, the
## deck pile (NEW PACKS), the packs as shingled cards on the bench (the spread one over its
## neighbours, the others sunk behind the bench), the strips with each pack's family and name,
## the plan note, the deal flights, the held slots, the floor row and the top bar. The BADGE PINS
## step is PinStepDraw's, the OPEN STORE flight StoreFlight's.

const CW := BoosterArt.CW
const CH := BoosterArt.CH
const PIN_BADGE := preload("res://art/scenery/pin_badge.png")
const SIGN := preload("res://art/frames/sign.png")
const STAMP_RING := preload("res://art/icons/stamp_ring.png")
## The x of the lockers' handles painted in the room (y 140, 5 x 26): the held slots' dashes
## break round them.
const LOCKER_HANDLES: Array[int] = [238, 298, 358, 418]
## A card behind a pack's front card shows its frame top and its name band (rows 53 on).
const BAND_ROW := 53
## The plan note on the corkboard (art px).
const NOTE := Rect2i(100, 80, 76, 76)
## The tape over the held slots.
const TAPE_W := 236
const TAPE_Y := 104


static func draw(layer: BuildLayer) -> void:
	var page: BuildPage = layer.page
	if page.run == null:
		return
	var pen: ArtPen = layer.pen
	match layer.layer:
		"Room":
			pen.tex(StaffRoomArt.texture(), 0, 0)
			_pins_board(pen, page)
			_deck(pen, page)
		"Stacks":
			for k: int in _stack_order(page):
				_stack(pen, page, k)
		"Over":
			if page.spread >= 0:
				_spread(pen, page, page.spread)
			for k: int in page.stacks.size():
				_strip(pen, page, k)
			_note(pen, page)
		"Flights":
			_flights(pen, page)
		"Over2":
			_good_first(pen, page)
			if not page.dealt:
				_held_slots(pen, page)
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


static func _stack_order(page: BuildPage) -> Array[int]:
	var order: Array[int] = []
	for k: int in page.stacks.size():
		if k != page.spread:
			order.append(k)
	if page.spread >= 0 and page.spread < page.stacks.size():
		order.append(page.spread)
	return order


## Whether pack card `card` shows RARE (a BIG or GOLDEN product, a rare or legendary coupon).
static func rare(card: CardDefinition, balance: BalanceDefinition) -> bool:
	if card.is_product():
		return card.tier != CardDefinition.Tier.PLAIN
	var machine: MachineDefinition = balance.machine
	return machine != null and machine.coupon_rarity(card) >= MachinePrize.Rarity.RARE


## A card's shingle height: its frame top, its name band and their lines.
static func header_h(card: CardDefinition, is_rare: bool) -> int:
	var lines: PackedStringArray = ArtPen.pix_wrap(
		card.display_name.to_upper(), CW - (16 if is_rare else 12)
	)
	return 9 + 9 * lines.size()


## The rest places of pack `pack`'s cards on bench place `k`: the front card's top on the bench,
## each card behind it its header higher.
static func rest_positions_in(
	k: int, pack: StarterPackDefinition, balance: BalanceDefinition
) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for j: int in pack.cards.size():
		var y: float = BuildPage.BENCH_Y - CH
		for i: int in range(pack.cards.size() - 1, j, -1):
			var card: CardDefinition = pack.cards[i - 1]
			y -= header_h(card, balance != null and rare(card, balance))
		found.append(Vector2(BuildPage.STX[k], y))
	return found


static func _card(
	pen: ArtPen, page: BuildPage, card: CardDefinition, x: float, y: float, o: Dictionary = {}
) -> void:
	o["now"] = page.now
	if page.rm:
		o["still"] = true
	BoosterCardDraw.draw(pen, card, rare(card, page.run.balance), x, y, o)


## A card behind the front one: its top 3 rows, then its name band with its words.
static func _header(pen: ArtPen, page: BuildPage, card: CardDefinition, x: float, y: float) -> void:
	var is_rare: bool = rare(card, page.run.balance)
	var h: float = header_h(card, is_rare) - 3
	x = roundf(x)
	y = roundf(y)
	if is_rare:
		var foil: ImageTexture = BoosterArt.foil_tile(2)
		pen.canvas.draw_texture_rect_region(
			foil, Rect2(pen.at(x, y), pen.size_of(CW, 3)), Rect2(5, 0, CW, 3)
		)
		pen.canvas.draw_texture_rect_region(
			foil, Rect2(pen.at(x, y + 3), pen.size_of(CW, h)), Rect2(5, BAND_ROW, CW, h)
		)
	var face: ImageTexture = BoosterArt.face(card, is_rare)
	pen.tex_part(face, Rect2(0, 0, CW, 3), x, y, CW, 3)
	pen.tex_part(face, Rect2(0, BAND_ROW, CW, h), x, y + 3, CW, h)
	var text: Dictionary = BoosterArt.face_text(card, is_rare)
	var lines: PackedStringArray = text.lines
	var win: Rect2i = text.window
	var coupon: bool = card.is_coupon()
	for k: int in lines.size():
		pen.pix(
			lines[k],
			x + win.position.x + win.size.x / 2.0,
			y + 3 + (text.band_y as int) + 3 + k * 9 - BAND_ROW,
			Palette.PAPER if coupon else Palette.INK,
			1.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)


static func _deal_age(page: BuildPage, k: int, j: int) -> float:
	var stack: Dictionary = page.stacks[k]
	return page.now - ((stack.deal_at as float) + j * page.tuning.p2_card_gap_s)


static func _sink(page: BuildPage, k: int) -> float:
	var sv: float = page.stacks[k].sv
	return roundf(BoosterPageDraw.e_in(sv) * (CH + 60))


## Pack `k` on the bench: the NEW PACKS flip of its old cards, then its cards landing from the
## deck, flipping face up, at rest as a shingle (or moving to the spread).
static func _stack(pen: ArtPen, page: BuildPage, k: int) -> void:
	if not page.dealt:
		return
	var stack: Dictionary = page.stacks[k]
	var leave: Dictionary = stack.leave
	if not leave.is_empty() and page.now - (leave.t as float) < 0.1:
		var u: float = page.now - (leave.t as float)
		var old: StarterPackDefinition = leave.pack
		var pos: Array[Vector2] = leave.pos
		for j: int in old.cards.size():
			_card(
				pen,
				page,
				old.cards[j],
				pos[j].x,
				pos[j].y,
				{
					"back": BoosterCardDraw.Back.PLAIN if u > 0.05 else BoosterCardDraw.Back.NONE,
					"sx": absf(cos(PI * u / 0.1))
				}
			)
	var spread_s: float = page.tuning.p2_spread_s
	if page.spread == k and page.now - page.spread_t > spread_s:
		return
	var pack: StarterPackDefinition = stack.pack
	var rest: Array[Vector2] = rest_positions_in(k, pack, page.run.balance)
	var sink: float = _sink(page, k)
	for j: int in pack.cards.size():
		var t: float = _deal_age(page, k, j)
		if t < 0.0:
			continue
		var at: Vector2 = rest[j] + Vector2(0, sink)
		if page.spread == k:
			var v: float = BoosterPageDraw.e_out((page.now - page.spread_t) / spread_s)
			at = Vector2(
				roundf(lerpf(rest[j].x, BuildPage.SPX[j], v)),
				roundf(lerpf(rest[j].y, BuildPage.SPY, v))
			)
		var fly: float = page.tuning.p2_fly_s
		if not page.rm and t < fly:
			continue
		var card: CardDefinition = pack.cards[j]
		if not page.rm and t < fly + page.tuning.p2_flip_s:
			var u: float = (t - fly) / page.tuning.p2_flip_s
			_card(
				pen,
				page,
				card,
				at.x,
				at.y,
				{
					"back": BoosterCardDraw.Back.PLAIN if u < 0.5 else BoosterCardDraw.Back.NONE,
					"sx": absf(cos(PI * u))
				}
			)
		elif j < pack.cards.size() - 1 and page.spread != k:
			_header(pen, page, card, at.x, at.y)
		else:
			_card(pen, page, card, at.x, at.y)


## The spread pack: its three cards side by side, lifted; the picked one pops on its slam.
static func _spread(pen: ArtPen, page: BuildPage, k: int) -> void:
	if k >= page.stacks.size() or page.now - page.spread_t <= page.tuning.p2_spread_s:
		return
	var pack: StarterPackDefinition = page.stacks[k].pack
	var pu: float = page.now - page.pick_t
	var is_picked: bool = page.picked() == k
	var pop: int = 0
	if is_picked and not page.rm and pu < 0.25:
		pop = 2 if pu < 0.08 else (4 if pu < 0.16 else 2)
	var lift: float = minf(4, floorf((page.now - page.spread_t - page.tuning.p2_spread_s) / 0.02))
	if is_picked:
		lift = 2.0 if page.rm else (4.0 if pu < 0.05 else (-1.0 if pu < 0.12 else 2.0))
	for j: int in pack.cards.size():
		if not page.rm and _deal_age(page, k, j) < page.tuning.p2_fly_s + page.tuning.p2_flip_s:
			continue
		var card: CardDefinition = pack.cards[j]
		var x: float = BuildPage.SPX[j]
		var y: float = BuildPage.SPY - lift
		_card(pen, page, card, x, y, {"pop": pop, "hot": true})
		if rare(card, page.run.balance):
			BoosterCardDraw.tab(pen, true, x + CW / 2.0, y - 1 - pop)
		pen.r(x + 2, y + CH + pop, CW - 4, 1, Palette.INK)


## A pack's family's colours (the coupon family in tomato with paper words, as the mock-up's).
static func family(pack: StarterPackDefinition) -> Dictionary:
	var palette: FamilyPalette = FamilyPalette.shared()
	var style: FamilyStyle = palette.style(pack.family)
	if pack.family == "Coupon" or style == null:
		return {
			"face": Palette.TOMATO,
			"light": Palette.TOMATO_LIGHT,
			"shade": Palette.TOMATO_DARK,
			"glyph": style.glyph if style != null else null,
			"paper": true,
		}
	return {
		"face": style.face,
		"light": style.light,
		"shade": style.shade,
		"glyph": style.glyph,
		"paper": style.paper_text,
	}


## The strip over pack `k`: its family band and its name, scaled in as it lands; the family stamp
## slams onto the picked one.
static func _strip(pen: ArtPen, page: BuildPage, k: int) -> void:
	if not page.dealt:
		return
	var t: float = _deal_age(page, k, 2) - page.tuning.p2_fly_s
	if t < 0.0 and not page.rm:
		return
	var pack: StarterPackDefinition = page.stacks[k].pack
	var f: Dictionary = family(pack)
	var x: float = BuildPage.STX[k] - 4
	var w: float = 80.0
	var sc: float = 1.0
	if not page.rm and t < 0.2:
		sc = lerpf(1.5, 1.0, BoosterPageDraw.e_back(t / 0.2))
	sc = roundf(sc * 4.0) / 4.0
	var hv: float = 1.0 if page.is_hovered("pack%d" % k) else 0.0
	var saved_origin: Vector2 = pen.origin
	var saved_unit: Vector2 = pen.unit
	pen.origin = pen.at(roundf(x + w / 2.0 - w * sc / 2.0), roundf(89 + 11 - 23 * sc / 2.0 - hv))
	pen.unit = saved_unit * sc
	pen.rn(0, 0, w, 11, f.face as Color)
	pen.r(1, 1, w - 2, 1, f.light as Color)
	pen.tex(f.glyph as Texture2D, 2, 1)
	pen.caps(pack.family.to_upper(), 13, 3, Palette.PAPER if f.paper else Palette.INK)
	pen.rn(0, 10, w, 13, Palette.CREAM)
	pen.r(1, 11, w - 2, 1, Palette.PAPER)
	pen.r(1, 21, w - 2, 1, Palette.CREAM_SHADE)
	var name_text: String = pack.display_name.to_upper()
	if ArtPen.pix_width(name_text) <= w - 6:
		pen.pix(name_text, w / 2.0, 13, Palette.INK, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		pen.caps(name_text, w / 2.0, 14, Palette.INK, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.origin = saved_origin
	pen.unit = saved_unit
	if page.picked() == k:
		_family_stamp(pen, page, pack, x + w / 2.0)


static func family_stamp_size(pack: StarterPackDefinition) -> Vector2:
	var words: ImageTexture = ArtPen.word_texture(pack.family.to_upper(), Palette.TOMATO, true)
	return Vector2(13 + 4 + words.get_width() + 10, 19)


## The family stamp: the glyph in its stamp ring and the family in chunky caps on paper, slammed
## at 2.5x, 1.4x, then at rest across the strip's family band.
static func _family_stamp(
	pen: ArtPen, page: BuildPage, pack: StarterPackDefinition, cx: float
) -> void:
	var u: float = page.now - page.pick_t
	var size_px: Vector2 = family_stamp_size(pack)
	var s2: float = 1.0
	if not page.rm:
		s2 = 2.5 if u < 0.05 else (1.4 if u < 0.1 else 1.0)
	var dy: float = 2.0 if not page.rm and u >= 0.1 and u < 0.16 else 0.0
	if not page.rm and u >= 0.05 and u < 0.09:
		pen.r(
			roundf(cx - size_px.x / 2.0) - 3,
			92 - size_px.y / 2.0 - 3,
			size_px.x + 6,
			size_px.y + 6,
			Color.WHITE
		)
	var f: Dictionary = family(pack)
	var saved_origin: Vector2 = pen.origin
	var saved_unit: Vector2 = pen.unit
	pen.origin = pen.at(roundf(cx - size_px.x * s2 / 2.0), roundf(92 - size_px.y * s2 / 2.0 + dy))
	pen.unit = saved_unit * s2
	var w: float = size_px.x
	var h: float = size_px.y
	pen.rn(0, 0, w, h, Palette.PAPER)
	pen.r(2, 2, w - 4, 1, Palette.TOMATO)
	pen.r(2, h - 3, w - 4, 1, Palette.TOMATO)
	pen.r(2, 2, 1, h - 4, Palette.TOMATO)
	pen.r(w - 3, 2, 1, h - 4, Palette.TOMATO)
	pen.tex(STAMP_RING, 4, 3)
	pen.r(6, 5, 9, 9, f.face as Color)
	pen.tex(f.glyph as Texture2D, 6, 5)
	pen.chunky(pack.family.to_upper(), 21, 6, Palette.TOMATO)
	for n: int in 9:
		pen.r(5 + (n * 29) % int(w - 10), 4 + (n * 7) % int(h - 8), 1, 1, Palette.PAPER)
	pen.origin = saved_origin
	pen.unit = saved_unit


## The plan note pinned on the corkboard: the hovered (or picked) pack's family and plan.
static func _note(pen: ArtPen, page: BuildPage) -> void:
	var x: float = NOTE.position.x
	var y: float = NOTE.position.y
	var w: float = NOTE.size.x
	var h: float = NOTE.size.y
	pen.r(x + 2, y + h, w - 2, 1, Palette.BROWN_DARK)
	pen.nine(BoosterArt.RECEIPT, x, y, w, h, Vector4i(2, 2, 2, 2))
	pen.r(x + w / 2.0 - 1, y + 1, 3, 3, Palette.TOMATO)
	var lines: PackedStringArray = []
	if page.packs_held():
		pen.caps(
			"PINS FIRST", x + w / 2.0, y + 10, Palette.TOMATO_DARK, 1.0, HORIZONTAL_ALIGNMENT_CENTER
		)
		lines = BoosterCardDraw.wrap_words(
			"Choose your badge pins (P). Your 3 starter packs deal when you confirm.", 5.2, w - 8
		)
		_note_lines(pen, lines, x + w / 2.0, y + 26, 5.2, 6.4)
		return
	var hv: int = page.hovered_pack()
	var k: int = hv if hv >= 0 else page.picked()
	if k < 0 or k >= page.stacks.size():
		pen.caps("PICK A PACK", x + w / 2.0, y + 10, Palette.INK, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
		lines = BoosterCardDraw.wrap_words(
			"Hover a pack to spread its cards and read its plan here.", 5.2, w - 8
		)
		_note_lines(pen, lines, x + w / 2.0, y + 26, 5.2, 6.4)
		return
	var pack: StarterPackDefinition = page.stacks[k].pack
	var f: Dictionary = family(pack)
	pen.r(x + 3, y + 6, w - 6, 9, f.face as Color)
	pen.tex(f.glyph as Texture2D, x + 4, y + 6)
	pen.caps(pack.family.to_upper(), x + 15, y + 8, Palette.PAPER if f.paper else Palette.INK)
	lines = BoosterCardDraw.wrap_words(pack.hint_text.strip_edges(), 5.1, w - 8)
	if lines.size() > 9:
		lines = lines.slice(0, 9)
	_note_lines(pen, lines, x + w / 2.0, y + 23, 5.1, 6.2)


static func _note_lines(
	pen: ArtPen, lines: PackedStringArray, cx: float, top: float, size: float, step: float
) -> void:
	for j: int in lines.size():
		pen.atk(lines[j], cx, top + j * step, size, Palette.INK, 700)


## Cards in the air between the deck and the bench: the NEW PACKS sweep into the deck and the deal
## out of it.
static func _flights(pen: ArtPen, page: BuildPage) -> void:
	if not page.dealt or page.rm:
		return
	var deck: Vector2 = Vector2(BuildPage.DECK)
	for k: int in page.stacks.size():
		var stack: Dictionary = page.stacks[k]
		var leave: Dictionary = stack.leave
		if not leave.is_empty():
			var lu: float = page.now - (leave.t as float)
			if lu >= 0.1 and lu < 0.45:
				var q: float = BoosterPageDraw.e_in((lu - 0.1) / 0.3)
				var old: StarterPackDefinition = leave.pack
				var pos: Array[Vector2] = leave.pos
				for j: int in old.cards.size():
					var at: Vector2 = pos[j].lerp(deck, q).round()
					_card(pen, page, old.cards[j], at.x, at.y, {"back": BoosterCardDraw.Back.PLAIN})
		if page.spread == k and page.now - page.spread_t > page.tuning.p2_spread_s:
			continue
		var pack: StarterPackDefinition = stack.pack
		var rest: Array[Vector2] = rest_positions_in(k, pack, page.run.balance)
		var sink: float = _sink(page, k)
		var fly: float = page.tuning.p2_fly_s
		for j: int in pack.cards.size():
			var t: float = _deal_age(page, k, j)
			if t < 0.0 or t >= fly:
				continue
			var to: Vector2 = rest[j] + Vector2(0, sink)
			if page.spread == k:
				var v: float = BoosterPageDraw.e_out(
					(page.now - page.spread_t) / page.tuning.p2_spread_s
				)
				to = rest[j].lerp(Vector2(BuildPage.SPX[j], BuildPage.SPY), v)
			var u: float = t / fly
			var at2: Vector2 = deck.lerp(to, u) - Vector2(0, sin(u * PI) * 50)
			_card(
				pen,
				page,
				pack.cards[j],
				roundf(at2.x),
				roundf(at2.y),
				{"back": BoosterCardDraw.Back.PLAIN}
			)


## GOOD FIRST PICK hangs over the offer's first pick while nothing is picked (a player who has
## never won), swinging every 2 s.
static func _good_first(pen: ArtPen, page: BuildPage) -> void:
	var first: StarterPackDefinition = page.run.start_offer.first_pick
	if first == null or page.picked() >= 0 or not page.dealt:
		return
	var k: int = page.run.start_offer.packs.find(first)
	if k < 0 or (not page.rm and _deal_age(page, k, 2) < page.tuning.p2_fly_s):
		return
	var cx: float = BuildPage.STX[k] + CW / 2.0
	var u: float = fmod(page.now, 2.0)
	var angle: float = 0.0 if page.rm or u > 0.4 else sin(u / 0.4 * PI * 2.0) * 0.12
	var label: String = "GOOD FIRST PICK"
	var w: float = ArtPen.word_texture(label, Palette.PAPER, false).get_width() + 10
	var saved: Vector2 = pen.origin
	pen.canvas.draw_set_transform(pen.at(cx, 74), angle, Vector2.ONE)
	pen.origin = Vector2.ZERO
	pen.r(-1, -2, 1, 5, Palette.STEEL_DARK)
	pen.rn(-roundf(w / 2.0), 3, w, 11, Palette.TOMATO)
	pen.r(-roundf(w / 2.0) + 1, 4, w - 2, 1, Palette.TOMATO_LIGHT)
	pen.caps(label, 0, 6, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	pen.origin = saved


## The bench while the packs wait for the pins: three dashed slots with padlocks under a tape.
static func _held_slots(pen: ArtPen, _page: BuildPage) -> void:
	var y: float = BuildPage.DECK.y - 44
	for k: int in 3:
		var x: float = BuildPage.STX[k]
		pen.d(x + 2, y + 2, CW - 4, CH + 37, Palette.TEAL_BLACK, 2)
		var i: float = 0.0
		while i < CW:
			pen.r(x + i, y + 1, 2, 1, Palette.INK)
			pen.r(x + i, y, 2, 1, Palette.STEEL_HIGHLIGHT)
			pen.r(x + i, y + CH + 41, 2, 1, Palette.INK)
			pen.r(x + i, y + CH + 40, 2, 1, Palette.STEEL_HIGHLIGHT)
			i += 4
		i = 0.0
		while i < CH + 40:
			pen.r(x + 1, y + i, 1, 2, Palette.INK)
			pen.r(x, y + i, 1, 2, Palette.STEEL_HIGHLIGHT)
			pen.r(x + CW, y + i, 1, 2, Palette.INK)
			pen.r(x + CW - 1, y + i, 1, 2, Palette.STEEL_HIGHLIGHT)
			i += 4
		pen.tex(BoosterArt.PADLOCK, x + CW / 2.0 - 5, y + 60)
	var room: ImageTexture = StaffRoomArt.texture()
	for hx: int in LOCKER_HANDLES:
		pen.tex_part(room, Rect2(hx - 1, 139, 7, 28), hx - 1, 139, 7, 28)
	var span: float = BuildPage.STX[2] + CW - BuildPage.STX[0]
	var tx: float = roundf(BuildPage.STX[0] + span / 2.0 - TAPE_W / 2.0)
	pen.r(tx, TAPE_Y, TAPE_W, 15, Palette.INK)
	pen.r(tx + 1, TAPE_Y + 1, TAPE_W - 2, 13, Palette.MUSTARD)
	var s: float = 0.0
	while s < TAPE_W - 2:
		pen.r(tx + 1 + s, TAPE_Y + 1, 4, 13, Palette.MUSTARD_DARK)
		s += 8
	pen.r(tx + 30, TAPE_Y + 2, TAPE_W - 60, 11, Palette.INK)
	pen.r(tx + 31, TAPE_Y + 3, TAPE_W - 62, 9, Palette.MUSTARD_PALE)
	pen.caps(
		"STARTER PACKS AFTER BADGE PINS",
		tx + TAPE_W / 2.0,
		TAPE_Y + 5,
		Palette.INK,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## The corkboard: the BADGE PINS sign and the run's name badge with the worn pin (or its empty
## ring); it blinks gold while the packs wait for the pins.
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
			pen, pin, page.pins.index_of(pin), cork.x - pop, cork.y - pop, 16 + pop * 2
		)
	else:
		PinStepDraw.empty(pen, cork.x, cork.y, 16)
	pen.r(bx + 24, by - 3, 3, 3, Palette.TOMATO)
	pen.r(bx + 24, by - 3, 1, 1, Palette.TOMATO_LIGHT)
	if (
		page.packs_held()
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


## The deck pile: four card backs (dimmed once NEW PACKS is used), the NEW PACKS plate with its
## blinking coin LED, the USED stamp; hover lifts the top card, a deal or re-deal hops it.
static func _deck(pen: ArtPen, page: BuildPage) -> void:
	var used: bool = page.run.start_setup.packs_redrawn
	var held: bool = page.packs_held()
	var live: bool = deck_live(page)
	var hv: bool = live and page.is_hovered("newpacks")
	var hu: float = page.now - page.deck_hop
	var hop: float = 0.0
	if not page.rm and hu >= 0.0 and hu < 0.16:
		hop = 3.0 if hu < 0.08 else 1.0
	var lift: float = (2.0 if hv and not page.rm else 0.0) + hop
	var deck: Vector2i = BuildPage.DECK
	var back: BoosterCardDraw.Back = (
		BoosterCardDraw.Back.USED if used else BoosterCardDraw.Back.PLAIN
	)
	for i: int in range(3, -1, -1):
		var y: float = deck.y + i - 3 - (lift if i == 0 else 0.0)
		BoosterCardDraw.draw(pen, null, false, deck.x - i, y, {"back": back})
	pen.r(deck.x - 3, deck.y + CH, CW + 3, 1, Palette.INK)
	var kx: float = deck.x - 2
	var ky: float = deck.y + CH - 32 - lift
	var kw: float = CW + 2
	var frame: Texture2D = BoosterArt.KEY_OFF
	if live:
		frame = BoosterArt.KEY_LIT if hv else BoosterArt.KEY
	pen.nine(frame, kx, ky, kw, 24, Vector4i(3, 7, 3, 4))
	var dim: bool = not live
	pen.pix(
		"NEW PACKS",
		kx + kw / 2.0 - 5,
		ky + 3,
		Palette.STEEL_SHADE if dim else Palette.INK,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	pen.nine(BoosterArt.COIN_LED, kx + kw - 12, ky + 5, 6, 6, Vector4i(1, 1, 1, 1))
	if live:
		var on: bool = page.rm or int(floorf(page.now * 2)) % 2 == 1
		pen.r(kx + kw - 11, ky + 6, 4, 4, Palette.GOLD if on else Palette.MUSTARD)
	var sub: String = "ONCE A RUN" if used else ("AFTER PINS" if held else "KEEPS YOUR PICK")
	pen.caps(
		sub,
		kx + kw / 2.0,
		ky + 14,
		Palette.STEEL_DARKEST if dim else Palette.TEAL_SHADE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if used:
		stamp(pen, page, "USED", deck.x + CW / 2.0 - 2, deck.y + 40, page.used_t)
	if hv:
		pen.tex(BoosterArt.TICK, deck.x - 12, deck.y + CH / 2.0)


## Whether the deck pile takes a click (NEW PACKS still to use, the packs dealt, the step shut).
static func deck_live(page: BuildPage) -> bool:
	return (
		not page.run.start_setup.packs_redrawn
		and not page.packs_held()
		and page.dealt
		and not page.pins_open
	)


## A tomato stamp slammed at 2x for 70 ms, settling 2 px by 140 ms.
static func stamp(
	pen: ArtPen, page: BuildPage, word: String, cx: float, cy: float, t0: float
) -> void:
	var u: float = page.now - t0
	if u < 0.0:
		return
	var sc: float = 1.0 if page.rm or u >= 0.07 else 2.0
	var settle: float = 0.0 if page.rm or u < 0.07 or u >= 0.14 else -2.0
	var tw: float = ArtPen.word_texture(word, Palette.INK, true).get_width() + 10
	var th: float = 14
	var saved_origin: Vector2 = pen.origin
	var saved_unit: Vector2 = pen.unit
	pen.origin = pen.at(roundf(cx - tw * sc / 2.0), roundf(cy - th * sc / 2.0 + settle))
	pen.unit = saved_unit * sc
	pen.rn(0, 0, tw, th, Palette.PAPER, Palette.TOMATO)
	pen.r(1, 1, tw - 2, 1, Palette.TOMATO)
	pen.r(1, th - 2, tw - 2, 1, Palette.TOMATO)
	pen.chunky(word, tw / 2.0, 3, Palette.TOMATO, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.origin = saved_origin
	pen.unit = saved_unit


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
	_primary(pen, page)


## The primary key: lit or teal, its label and sub-label, the armed LED rim once a pack is
## picked; teal and dim while the pins step is open.
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
	if page.picked() >= 0 and not page.packs_held() and page.now >= page.busy_until:
		armed = page.pick_t + 0.3
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
	list.append(_hit(Rect2(156, 7, 82, 20), "tab1", page.press_store))
	list.append(_hit(Rect2(43, 73, 56, 87), "pins", page.pins.open.bind(page.now)))
	var deck: Vector2i = BuildPage.DECK
	list.append(_hit(Rect2(deck.x - 4, deck.y - 6, CW + 4, CH + 6), "newpacks", page.new_packs))
	if page.dealt:
		for k: int in page.stacks.size():
			list.append(
				_hit(
					Rect2(BuildPage.STX[k] - 4, 89, 80, 209),
					"pack%d" % k,
					page.pick_pack.bind(k, "click")
				)
			)
	else:
		var span: float = BuildPage.STX[2] + CW + 8 - BuildPage.STX[0]
		list.append(
			_hit(
				Rect2(BuildPage.STX[0] - 4, 89, span, 209),
				"heldpacks",
				page.pins.open.bind(page.now)
			)
		)
	list.append(_hit(Rect2(BuildPage.BACK_RECT), "back", page.press_store))
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
	var label: Array = ["PICK A PACK", "1 OF 3 PACKS", false]
	var first: StarterPackDefinition = page.run.start_offer.first_pick
	if page.packs_held():
		label = ["BADGE PINS", "PACKS DEAL AFTER", true]
	elif page.now < page.busy_until:
		label = ["SKIP ›", "DEAL EVERY CARD", true]
	elif page.picked() >= 0:
		label = ["OPEN STORE", "CLOCK IN · %d CARDS" % page.cart_target(), true]
	elif first != null:
		var at: int = page.run.start_offer.packs.find(first) + 1
		label = ["TAKE PACK %d" % at, first.display_name.to_upper(), true]
	return label


## The hint LED's line: a flashed message for 2 s, else the state's hint.
static func hint_line(page: BuildPage) -> String:
	var line: String = "HOVER A PACK, CLICK TO PICK"
	if page.message != "" and page.now - page.message_t < 2.0:
		line = page.message
	elif page.packs_held():
		line = "BADGE PINS FIRST · P"
	elif page.hint != "":
		line = page.hint
	elif page.picked() >= 0:
		line = "OPEN STORE TO CLOCK IN"
	return line


static func hint_start(page: BuildPage) -> float:
	return page.message_t if page.message != "" and page.now - page.message_t < 2.0 else page.hint_t


## The top bar's view (BoosterChromeDraw.top_bar_view) on page 2: 7:00, the YOUR BUILD tab.
static func top_view(page: BuildPage) -> Dictionary:
	return {
		"now": page.now,
		"rm": page.rm,
		"minutes": 60,
		"tab": 2,
		"blink": false,
		"completed": StartSetupRules.completed(page.run.balance, page.profile),
		"aisles": page.run.balance.aisles,
		"cart": page.cart_shown,
		"limit": page.run.balance.deck_limit,
		"punch_t": page.cart_punch_t,
		"punch_s": page.cart_punch_s,
	}
