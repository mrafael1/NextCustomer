class_name CartSheet
extends Control
## The start screen's YOUR CART (#107's clock-in board, mock-up start_screen.html layout A, part 2;
## 2026-11-03): the cart the run starts with, before the pick is confirmed, on a sheet of cream
## receipt paper. Its header says YOUR CART n/limit and the equation (4 staples + 3 from <pack> + 6
## from today's deal [+ n from your pins]); under it the cart in brackets of CartTickets: STAPLES
## (padlocked, in every run), the PACK (the picked or hovered pack's cards, or empty dashed slots
## with "pick a pack ↑"), TODAY'S DEAL (the offer's shared products, the same for every pack) and
## FROM YOUR PINS (only when a worn pin brings cards). Identical cards share one ticket per
## bracket, its ×N counting the card's copies over the whole cart. BY FAMILY tallies the cart's
## family tags beside the deal. A pack change pops its tickets in (CartRevealTuning's ticket pop,
## at once with reduced motion). Display only: the cards come from StartingDeck.cart, the same as
## RunState.take_pack deals.

const RECT := Rect2(44, 326, 780, 362)
const HEADER_TOP := 10.0
const NUMBER_CHIP := Rect2(16, 12, 22, 22)
const TITLE_RECT := Rect2(48, 12, 140, 22)
const TITLE_TEXT := "YOUR CART"
const TOTAL_AT := Vector2(176, 4)
const TOTAL_SIZE := 26
const EQUATION_RECT := Rect2(292, 12, 476, 22)
const EQUATION_SIZE := 13
## The brackets' rows: their labels' tops and their tickets' tops; tickets TICKET_STEP apart from
## LEFT, the brackets BRACKET_GAP apart.
const ROW_LABEL_TOPS: Array[float] = [46.0, 206.0]
const ROW_TICKET_TOPS: Array[float] = [74.0, 234.0]
const LEFT := 16.0
const TICKET_STEP := 92.0
const BRACKET_GAP := 30.0
const LABEL_SIZE := 13
const LABEL_HEIGHT := 18.0
const COUNT_CHIP := Vector2(18, 18)
const SUB_SIZE := 11
const BAR_HEIGHT := 4.0
const BAR_DROP := 8.0
## BY FAMILY: its heading and two columns of rows.
const TALLY_RECT := Rect2(576, 206, 196, 146)
const TALLY_ROW := 22.0
const TALLY_COLUMN := 102.0
const TALLY_ROWS := 5
const TALLY_SIZE := 12
const TALLY_GLYPH := 12.0
const STAPLES_TEXT := "STAPLES"
const STAPLES_SUB := "in every run"
const PACK_SUB_PICKED := "your pick"
const PACK_SUB_PREVIEW := "preview"
const PACK_EMPTY_TEXT := "PACK"
const PACK_EMPTY_SUB := "pick a pack ↑"
const DEAL_TEXT := "TODAY’S DEAL"
const DEAL_SUB := "from today’s stock · the same whichever pack you pick"
const PINS_TEXT := "FROM YOUR PINS"
const TALLY_TEXT := "BY FAMILY"
const SHADOW_DROP := 6.0

var staples: Array[CardDefinition] = []
var shared: Array[CardDefinition] = []
var pin_cards: Array[CardDefinition] = []
## The pack the sheet shows (null: none yet), and whether it is only previewed (hovered).
var pack: StarterPackDefinition
var previewing: bool = false
var staple_tickets: Array[CartTicket] = []
var pack_tickets: Array[CartTicket] = []
var deal_tickets: Array[CartTicket] = []
var pin_tickets: Array[CartTicket] = []
## The pop-in after a pack change: CartRevealTuning's ticket_pop_s and ticket_stagger_s, or none.
var pop_s: float = 0.0
var stagger_s: float = 0.0
var _deck_limit: int = 0
## The cards a pack brings (every offered pack brings as many; shown while none is picked).
var _pack_size: int = 0
var _body: Control
var _total: Label
var _equation: Label
var _since: float = 0.0
var _tally: Dictionary[String, int] = {}


## The sheet for `core` (the staples), `shared` (today's deal), the worn pins' `pins_cards`, a
## cart of `deck_limit`, with packs of `pack_size` cards.
func _init(
	core: Array[CardDefinition],
	shared_cards: Array[CardDefinition],
	pins_cards: Array[CardDefinition],
	deck_limit: int,
	pack_size: int
) -> void:
	name = "CartSheet"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = RECT.position
	size = RECT.size
	staples = core.duplicate()
	shared = shared_cards.duplicate()
	pin_cards = pins_cards.duplicate()
	_deck_limit = deck_limit
	_pack_size = pack_size
	var chip: RevealChip = RevealChip.new(
		Palette.TOMATO, NUMBER_CHIP.size, null, "2", 15, Palette.PAPER
	)
	chip.position = NUMBER_CHIP.position
	add_child(chip)
	var title: Label = UiKit.pixel_label(TITLE_TEXT, 2, Palette.TOMATO_DARK)
	add_child(title)
	UiKit.place_pixel_label(title, TITLE_RECT, true)
	_total = UiKit.number_label("", TOTAL_SIZE, false)
	_total.position = TOTAL_AT
	add_child(_total)
	_equation = _text("", EQUATION_SIZE, Palette.INK, 700)
	_equation.position = EQUATION_RECT.position
	_equation.size = EQUATION_RECT.size
	_equation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_equation.clip_text = true
	add_child(_equation)
	show_pack(null, false)


## The cart's cards as shown: the staples, the pack's (none without a pack), today's deal and the
## pins' cards, in deal order (StartingDeck.cart's).
func cart_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = staples.duplicate()
	if pack != null:
		cards.append_array(pack.cards)
	cards.append_array(shared)
	cards.append_array(pin_cards)
	return cards


## The cart's size as the header counts it: a pack's cards are counted before one is picked.
func cart_size() -> int:
	return staples.size() + _pack_size + shared.size() + pin_cards.size()


## Shows `shown_pack` in the PACK bracket (null: empty slots), `preview` when it is only hovered;
## its tickets pop in. Every ticket's ×N is counted again over the new cart.
func show_pack(shown_pack: StarterPackDefinition, preview: bool) -> void:
	var changed: bool = shown_pack != pack
	pack = shown_pack
	previewing = preview and pack != null
	if _body != null:
		remove_child(_body)
		_body.free()
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	add_child(_body)
	_build_brackets()
	_build_tally()
	_total.text = "%d/%d" % [cart_size(), _deck_limit]
	_equation.text = equation_text()
	if changed:
		_since = 0.0
	advance(0.0)


## The equation after the total: "= 4 staples + 3 from <pack> + 6 from today's deal".
func equation_text() -> String:
	var from_pack: String = pack.display_name if pack != null else "your pick"
	var text: String = (
		"= %d staples + %d from %s + %d from today’s deal"
		% [staples.size(), _pack_size, from_pack, shared.size()]
	)
	if not pin_cards.is_empty():
		text += " + %d from your pins" % pin_cards.size()
	return text


## The total's text, "13/15" (for tests).
func total_text() -> String:
	return _total.text


## Every ticket on the sheet, the empty slots included.
func tickets() -> Array[CartTicket]:
	return staple_tickets + pack_tickets + deal_tickets + pin_tickets


## The ticket with a card under `point` (global), or null.
func ticket_at(point: Vector2) -> CartTicket:
	for ticket: CartTicket in tickets():
		if not ticket.is_empty() and ticket.get_global_rect().has_point(point):
			return ticket
	return null


## BY FAMILY's counts (family id: cards of the cart counting as it).
func tally() -> Dictionary[String, int]:
	return _tally


## Lights today's deal's tickets whose card is in `cards` and dims its others (a hovered shelf);
## none lit and none dimmed when `on` is false.
func light_deal(cards: Array[CardDefinition], on: bool) -> void:
	for ticket: CartTicket in deal_tickets:
		var hit: bool = cards.has(ticket.card)
		ticket.set_light(on and hit, on and not hit)


## Moves the pack's pop-in on by `seconds`.
func advance(seconds: float) -> void:
	_since += seconds
	for index: int in pack_tickets.size():
		var start: float = index * stagger_s
		var q: float = 1.0 if pop_s <= 0.0 else (_since - start) / pop_s
		pack_tickets[index].show_pop(q)


## The copies of `card` in the cart shown (a variant counts as itself: only identical cards).
func copies_of(card: CardDefinition) -> int:
	return cart_cards().count(card)


func _build_brackets() -> void:
	staple_tickets = []
	pack_tickets = []
	deal_tickets = []
	pin_tickets = []
	var x: float = LEFT
	x = _bracket(STAPLES_TEXT, staples, STAPLES_SUB, x, 0, staple_tickets, true)
	if pack != null:
		var sub: String = PACK_SUB_PREVIEW if previewing else PACK_SUB_PICKED
		var start: float = x
		x = _bracket(pack.display_name.to_upper(), pack.cards, sub, x, 0, pack_tickets, false)
		_pack_bar(
			start, start + pack.cards.size() * TICKET_STEP - (TICKET_STEP - CartTicket.SIZE.x)
		)
	else:
		_row_label(PACK_EMPTY_TEXT, _pack_size, PACK_EMPTY_SUB, x, 0)
		for index: int in _pack_size:
			var slot: CartTicket = CartTicket.new(null)
			slot.set_rest(Vector2(x + index * TICKET_STEP, ROW_TICKET_TOPS[0]))
			_body.add_child(slot)
			pack_tickets.append(slot)
		x += _pack_size * TICKET_STEP + BRACKET_GAP
	if not pin_cards.is_empty():
		_bracket(PINS_TEXT, pin_cards, "", x, 0, pin_tickets, false)
	_bracket(DEAL_TEXT, shared, DEAL_SUB, LEFT, 1, deal_tickets, false)


## One bracket: its label row (`text`, its card count, `sub`) at `x` on `row`, then one ticket per
## distinct card of `cards` (in order). Returns the next bracket's x.
func _bracket(
	text: String,
	cards: Array[CardDefinition],
	sub: String,
	x: float,
	row: int,
	into: Array[CartTicket],
	staple: bool
) -> float:
	_row_label(text, cards.size(), sub, x, row)
	var seen: Array[CardDefinition] = []
	for card: CardDefinition in cards:
		if seen.has(card):
			continue
		seen.append(card)
		var ticket: CartTicket = CartTicket.new(card, staple, copies_of(card))
		ticket.set_rest(Vector2(x + into.size() * TICKET_STEP, ROW_TICKET_TOPS[row]))
		_body.add_child(ticket)
		into.append(ticket)
	return x + maxi(into.size(), 1) * TICKET_STEP + BRACKET_GAP - (TICKET_STEP - CartTicket.SIZE.x)


func _row_label(text: String, count: int, sub: String, x: float, row: int) -> void:
	var box: HBoxContainer = HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	box.position = Vector2(x, ROW_LABEL_TOPS[row])
	box.size = Vector2(0, LABEL_HEIGHT)
	_body.add_child(box)
	var label: Label = _text(text, LABEL_SIZE, Palette.INK, 800)
	label.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
	box.add_child(label)
	var chip: RevealChip = RevealChip.new(
		Palette.PAPER, COUNT_CHIP, null, str(count), 12, Palette.INK
	)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(chip)
	if not sub.is_empty():
		var note: Label = _text(sub, SUB_SIZE, Palette.GREY_DARK, 600)
		box.add_child(note)


## The pack's bar under its tickets, in its family's colour.
func _pack_bar(left: float, right: float) -> void:
	var bar: ColorRect = ColorRect.new()
	bar.name = "PackBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = PackFace.pack_look(pack)[0]
	bar.position = Vector2(left, ROW_TICKET_TOPS[0] + CartTicket.SIZE.y + BAR_DROP)
	bar.size = Vector2(right - left, BAR_HEIGHT)
	_body.add_child(bar)


func _build_tally() -> void:
	_tally = {}
	var palette: FamilyPalette = FamilyPalette.shared()
	for card: CardDefinition in cart_cards():
		var families: PackedStringArray = card.tags.duplicate()
		if card.is_coupon():
			families.insert(0, "Coupon")
		for family: String in families:
			if palette.style(family) != null and not _tally.has(family):
				_tally[family] = 0
			if _tally.has(family):
				_tally[family] += 1
	var heading: Label = _text(TALLY_TEXT, LABEL_SIZE, Palette.INK, 800)
	heading.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
	heading.position = TALLY_RECT.position
	_body.add_child(heading)
	var order: Array[String] = []
	order.assign(_tally.keys())
	order.sort_custom(func(a: String, b: String) -> bool: return _tally[a] > _tally[b])
	for index: int in mini(order.size(), TALLY_ROWS * 2):
		var family: String = order[index]
		var at: Vector2 = (
			TALLY_RECT.position
			+ Vector2(
				floori(float(index) / TALLY_ROWS) * TALLY_COLUMN,
				26.0 + (index % TALLY_ROWS) * TALLY_ROW
			)
		)
		var style: FamilyStyle = palette.style(family)
		if style.glyph != null:
			var glyph: TextureRect = UiKit.sprite(style.glyph)
			glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			glyph.stretch_mode = TextureRect.STRETCH_SCALE
			glyph.size = Vector2.ONE * TALLY_GLYPH
			glyph.position = at + Vector2(0, 3)
			_body.add_child(glyph)
		var label: Label = _text(palette.display_name(family), TALLY_SIZE, Palette.INK, 700)
		label.position = at + Vector2(TALLY_GLYPH + 4, 0)
		_body.add_child(label)
		var number: Label = _text(str(_tally[family]), TALLY_SIZE, Palette.INK, 800)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.position = at
		number.size = Vector2(TALLY_COLUMN - 10, 0)
		_body.add_child(number)


func _text(text: String, font_size: int, colour: Color, weight: int) -> Label:
	var label: Label = UiKit.body_label(text, font_size, colour)
	label.add_theme_font_override("font", CartReveal.font(weight))
	return label


## The receipt paper: a hard shadow, an ink line, the cream sheet with a torn-looking foot.
func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(
		Rect2(rect.position + Vector2(0, SHADOW_DROP), rect.size).grow(2), Color(0, 0, 0, 0.35)
	)
	draw_rect(rect.grow(2), Palette.INK)
	draw_rect(rect, Palette.PAPER)
	draw_rect(Rect2(0, size.y - 4, size.x, 4), Palette.CREAM_SHADE)


## The rule between the two rows, dashed.
func _draw_body() -> void:
	var y: float = ROW_LABEL_TOPS[1] - 10.0
	var x: float = LEFT
	while x < size.x - LEFT:
		_body.draw_rect(Rect2(x, y, 6, 2), Palette.CREAM_DARKEST)
		x += 12.0
