class_name StartBoard
extends Control
## The start screen (#107's starter pack choice, redrawn as the clock-in board: mock-up
## start_screen.html layout A, the designer's recommendation, built 2026-11-03). A new run
## waiting for its pick (RunState.Phase.CHOOSE_START) opens the cart reveal on it, over shift 1.
## One steel board (a charcoal rim, a steel bevel, brass rivets) under an OPENING TIME · SHIFT 1 OF
## 12 plate and the run's seed, in four numbered parts:
## 1. the offer's packs (PackChoice): hover previews a pack, a click (or 1 to 3) picks it;
## 2. YOUR CART (CartSheet): the cart the run starts with for the shown pack, as tickets;
## 3. TODAY'S STOCK (StockShelves): where today's deal is dealt from; hovering a shelf lights the
##    deal's tickets that came from it;
## 4. BADGE PINS (BoardPins): the pins the run wears.
## The red OPEN STORE › key (grey, PICK A PACK FIRST, until a pack is picked; it glows once one is)
## or Enter confirms. Everything shown is already dealt: the offer and today's products are the
## run's (StartingDeck.deal_offer, saved before the screen opens) and the cart is
## StartingDeck.cart, which RunState.take_pack deals. Display only: CartReveal routes the pointer
## and keys, and its board sits on the 1280x720 stage in stage coordinates.

const RECT := Rect2(22, 70, 1236, 630)
## The frame: a hard shadow, an ink line, the charcoal rim, the steel bevel and the rivets.
const SHADOW_DROP := 8.0
const RIM := 4.0
const BEVEL := 2.0
const RIVET := 6.0
const RIVET_INSET := 8.0
## The header plate over the top bar's left (stage coordinates), its clock and its text, and the
## seed line right of it.
const HEADER_RECT := Rect2(22, 12, 404, 38)
const CLOCK_SIZE := Vector2(44, 44) * (2.0 / 3.0)
const HEADER_TEXT := "OPENING TIME  ·  SHIFT %d OF %d"
const HEADER_SIZE := 18
const SEED_RECT := Rect2(440, 20, 620, 24)
const SEED_TEXT := "Seed %d  ·  %s"
const SEED_SIZE := 14
const CLOCK := preload("res://art/scenery/wall_clock.png")
## The OPEN STORE key (stage coordinates): its face, ledge, text and sub line.
const KEY_RECT := Rect2(850, 624, 388, 62)
const KEY_LEDGE := 6.0
const KEY_TEXT_SIZE := 24
const KEY_SUB_SIZE := 12
const KEY_GLOW := 4.0
const KEY_OPEN_TEXT := "OPEN STORE ›"
const KEY_IDLE_TEXT := "PICK A PACK FIRST"
const KEY_SUB_TEXT := "Start shift %d with %s · %d cards"
const KEY_IDLE_SUB := "1 · 2 · 3 pick a pack  ·  Enter opens the store"

var choice: PackChoice
var sheet: CartSheet
var shelves: StockShelves
var pins: BoardPins
var key_hovered: bool = false
var _content: Control
var _key: Control
var _key_text: Label
var _key_sub: Label
var _shift: int = 1
var _clock_s: float = 0.0
var _glow_hz: float = 0.0


## The board for `run` (waiting for its pick, with its offer), the profile's `unlocked` items (the
## stock's locked aisles), with `timing`'s ticket pop and key glow (none: `reduced` motion).
func _init(
	run: RunState, unlocked: Dictionary[StringName, int], timing: CartRevealTuning, reduced: bool
) -> void:
	name = "StartBoard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = RECT.position
	size = RECT.size
	_shift = run.shift_index + 1
	_glow_hz = 0.0 if reduced else timing.key_glow_hz
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.position = -RECT.position
	add_child(_content)
	_build_header(run)
	var offer: StartOffer = run.start_offer
	choice = PackChoice.new(offer)
	_content.add_child(choice)
	var pin_cards: Array[CardDefinition] = []
	for pin: PinDefinition in run.pins:
		pin_cards.append_array(pin.starting_cards)
	var pack_size: int = offer.packs[0].cards.size() if not offer.packs.is_empty() else 0
	sheet = CartSheet.new(
		run.starter.core_cards, offer.shared, pin_cards, run.balance.deck_limit, pack_size
	)
	if not reduced:
		sheet.pop_s = timing.ticket_pop_s
		sheet.stagger_s = timing.ticket_stagger_s
	_content.add_child(sheet)
	var pool: Array[CardDefinition] = StartingDeck.deal_pool(run.starter, run.stock, run.balance)
	shelves = StockShelves.new(
		run.balance, run.stock, pool, offer.shared, unlocked, run.starter.copy_max
	)
	_content.add_child(shelves)
	pins = BoardPins.new(run.pins, run.balance.pin_slots)
	_content.add_child(pins)
	_build_key()
	_refresh_sheet()
	# The first pack shown pops in with the board, not after it.
	sheet.advance(1000.0)


## Picks pack `index` (-1: none): the cart sheet shows it (unless another is hovered) and the key
## lights.
func pick(index: int) -> void:
	choice.raise(index)
	_refresh_sheet()


## The picked pack, or null.
func picked_pack() -> StarterPackDefinition:
	return choice.raised_pack()


## The pointer at `point` (global): a pack under it is previewed in the cart, a shelf under it
## lights its tickets, the key under it lights.
func set_pointer(point: Vector2) -> void:
	if choice.set_pointer(choice.face_at(point)):
		_refresh_sheet()
	var row: int = shelves.row_at(point)
	if row != shelves.hovered_index:
		shelves.set_hovered(row)
		_light_shelf()
	var on_key: bool = key_has(point)
	if on_key != key_hovered:
		key_hovered = on_key
		_key.queue_redraw()


## Whether `point` (global) is on the OPEN STORE key.
func key_has(point: Vector2) -> bool:
	return _key.get_global_rect().has_point(point)


## What under `point` (global) shows a card's popup: a cart ticket or a pack's tile; else null.
func ticket_at(point: Vector2) -> Control:
	var ticket: CartTicket = sheet.ticket_at(point)
	if ticket != null:
		return ticket
	for tile: CartTicket in choice.tiles():
		if tile.is_visible_in_tree() and tile.get_global_rect().has_point(point):
			return tile
	return null


## The cart as shown: StartingDeck.cart of the shown pack (the hovered one, else the picked one).
func preview_cards() -> Array[CardDefinition]:
	return sheet.cart_cards()


## Poses the board at `t` on the reveal's timeline (the packs drop in).
func show_at(t: float, timing: CartRevealTuning) -> void:
	choice.show_at(t, timing)


## Moves the tickets' pop-in and the key's glow on by `seconds` (each frame, _process).
func advance(seconds: float) -> void:
	_clock_s += seconds
	sheet.advance(seconds)
	if picked_pack() != null and _glow_hz > 0.0:
		_key.queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## The key's text and sub line (for tests).
func key_text() -> String:
	return _key_text.text


func key_sub_text() -> String:
	return _key_sub.text


## The header plate's rect and the key's (stage coordinates, for tests).
func header_rect() -> Rect2:
	return HEADER_RECT


func _refresh_sheet() -> void:
	var shown: StarterPackDefinition = choice.shown_pack()
	var preview: bool = shown != null and shown != choice.raised_pack()
	if shown != sheet.pack or preview != sheet.previewing:
		sheet.show_pack(shown, preview)
		_light_shelf()
	var pack: StarterPackDefinition = picked_pack()
	_key_text.text = KEY_OPEN_TEXT if pack != null else KEY_IDLE_TEXT
	_key_text.add_theme_color_override(
		"font_color", Palette.PAPER if pack != null else Palette.GREY_DARK
	)
	_key_sub.text = (
		KEY_SUB_TEXT % [_shift, pack.display_name, sheet.cart_size()]
		if pack != null
		else KEY_IDLE_SUB
	)
	_key_sub.add_theme_color_override(
		"font_color", Palette.TOMATO_PALE if pack != null else Palette.GREY_DARK
	)
	_key.queue_redraw()


func _light_shelf() -> void:
	var row: int = shelves.hovered_index
	if row < 0:
		sheet.light_deal([], false)
		return
	sheet.light_deal(shelves.dealt_from(shelves.shelf_ids[row]), true)


func _build_header(run: RunState) -> void:
	var plate: Control = Control.new()
	plate.name = "Header"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = HEADER_RECT.position
	plate.size = HEADER_RECT.size
	plate.draw.connect(_draw_plate.bind(plate))
	_content.add_child(plate)
	var clock: TextureRect = UiKit.sprite(CLOCK)
	clock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clock.stretch_mode = TextureRect.STRETCH_SCALE
	clock.size = CLOCK_SIZE
	clock.position = Vector2(6, (HEADER_RECT.size.y - CLOCK_SIZE.y) / 2.0)
	plate.add_child(clock)
	var text: Label = UiKit.body_label(
		HEADER_TEXT % [run.shift_index + 1, run.shift_count()], HEADER_SIZE, Palette.INK
	)
	text.add_theme_font_override("font", CartReveal.spaced_font(800, 2))
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.position = Vector2(CLOCK_SIZE.x + 14, 0)
	text.size = Vector2(HEADER_RECT.size.x - CLOCK_SIZE.x - 18, HEADER_RECT.size.y)
	plate.add_child(text)
	var build: String = str(ProjectSettings.get_setting("next_customer/build_label", ""))
	var seed_line: Label = UiKit.body_label(
		SEED_TEXT % [run.run_seed, build], SEED_SIZE, Palette.TEAL_LIGHT
	)
	seed_line.add_theme_font_override("font", CartReveal.spaced_font(700, 1))
	seed_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seed_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_line.position = SEED_RECT.position
	seed_line.size = SEED_RECT.size
	_content.add_child(seed_line)


func _build_key() -> void:
	_key = Control.new()
	_key.name = "OpenStoreKey"
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key.position = KEY_RECT.position
	_key.size = KEY_RECT.size
	_key.draw.connect(_draw_key)
	_content.add_child(_key)
	_key_text = UiKit.body_label("", KEY_TEXT_SIZE, Palette.PAPER)
	_key_text.add_theme_font_override("font", CartReveal.spaced_font(800, 2))
	_key_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_text.position = Vector2(0, 4)
	_key_text.size = Vector2(KEY_RECT.size.x, 32)
	_key.add_child(_key_text)
	_key_sub = UiKit.body_label("", KEY_SUB_SIZE, Palette.TOMATO_PALE)
	_key_sub.add_theme_font_override("font", CartReveal.font(700))
	_key_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_sub.position = Vector2(0, 36)
	_key_sub.size = Vector2(KEY_RECT.size.x, 16)
	_key.add_child(_key_sub)


## The board's frame: its shadow, ink line, charcoal rim, steel bevel, panel and brass rivets.
func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var outer: Rect2 = rect.grow(RIM + 2.0)
	draw_rect(Rect2(outer.position + Vector2(0, SHADOW_DROP), outer.size), Color(0, 0, 0, 0.4))
	draw_rect(outer, Palette.INK)
	draw_rect(rect.grow(RIM), Palette.CHARCOAL)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, BEVEL)), Palette.STEEL_LIGHT)
	draw_rect(Rect2(rect.position, Vector2(BEVEL, rect.size.y)), Palette.STEEL_LIGHT)
	draw_rect(Rect2(0, rect.size.y - BEVEL, rect.size.x, BEVEL), Palette.STEEL_DARK)
	draw_rect(Rect2(rect.size.x - BEVEL, 0, BEVEL, rect.size.y), Palette.STEEL_DARK)
	draw_rect(rect.grow(-BEVEL), Palette.PANEL)
	for corner: Vector2 in [
		Vector2(RIVET_INSET, RIVET_INSET),
		Vector2(size.x - RIVET_INSET - RIVET, RIVET_INSET),
		Vector2(RIVET_INSET, size.y - RIVET_INSET - RIVET),
		Vector2(size.x - RIVET_INSET - RIVET, size.y - RIVET_INSET - RIVET),
	]:
		draw_rect(Rect2(corner, Vector2.ONE * RIVET).grow(2.0), Palette.INK)
		draw_rect(Rect2(corner, Vector2.ONE * RIVET), Palette.BRASS)
		draw_rect(Rect2(corner, Vector2(2, 2)), Palette.GOLD)
		draw_rect(Rect2(corner + Vector2(RIVET - 2, RIVET - 2), Vector2(2, 2)), Palette.BRASS_DARK)


## The header plate: mustard with an ink line and a dark ledge.
func _draw_plate(plate: Control) -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, plate.size)
	plate.draw_rect(
		Rect2(rect.position + Vector2(0, 4), rect.size).grow(2.0), Palette.MUSTARD_DARKEST
	)
	plate.draw_rect(rect.grow(2.0), Palette.INK)
	plate.draw_rect(rect, Palette.MUSTARD)
	plate.draw_rect(Rect2(0, 0, rect.size.x, 2), Palette.MUSTARD_LIGHT)


## The register key: red with a dark ledge (grey before a pick), lighter under the pointer, a gold
## glow pulsing round it once a pack is picked.
func _draw_key() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, KEY_RECT.size)
	var live: bool = picked_pack() != null
	if live and _glow_hz > 0.0:
		var glow: float = 0.5 + 0.5 * sin(_clock_s * TAU * _glow_hz)
		_key.draw_rect(rect.grow(2.0 + KEY_GLOW), Color(Palette.GOLD, 0.35 + 0.5 * glow))
	elif live:
		_key.draw_rect(rect.grow(2.0 + KEY_GLOW), Color(Palette.GOLD, 0.6))
	var face: Color = Palette.GREY_LIGHT
	var ledge: Color = Palette.GREY
	if live:
		face = Palette.TOMATO_LIGHT if key_hovered else Palette.TOMATO
		ledge = Palette.TOMATO_DARKEST
	_key.draw_rect(rect.grow(2.0), Palette.INK)
	_key.draw_rect(rect, face)
	_key.draw_rect(Rect2(0, 0, rect.size.x, 2), Palette.TOMATO_PALE if live else Palette.CREAM)
	_key.draw_rect(Rect2(0, rect.size.y - KEY_LEDGE, rect.size.x, KEY_LEDGE), ledge)
