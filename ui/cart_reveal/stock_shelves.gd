class_name StockShelves
extends Control
## The start screen's TODAY'S STOCK (#107's clock-in board, mock-up start_screen.html layout A,
## part 3; 2026-11-03): where today's deal comes from. One row per shelf: STAPLES first, then the
## store's aisles in data order, each with its sign plate (the aisle's sign_color and glyph), its
## name, its count and its state: DEALT FROM (its stocked products are in the deal's pool,
## StartingDeck.deal_pool), PRIZES ONLY (stocked, but only as the machine's prizes: capsule items a
## recipe without random_capsules never deals), NOT LISTED (listable, not on today's list) or
## LOCKED (it opens at its toy machine; its count is the items held of its capsules). The footer
## gives the pool's size and the copy rule. Hovering a row (set_hovered) names how many of today's
## deal came from it; the board lights those tickets in the cart. Display only: it reads the run's
## stock, never changes it.

enum State { DEALT_FROM, PRIZES_ONLY, NOT_LISTED, LOCKED }

const RECT := Rect2(846, 84, 392, 344)
const STAPLES_ID := &"staples"
const NUMBER_CHIP := Rect2(4, 0, 22, 22)
const TITLE_RECT := Rect2(36, 0, 300, 22)
const TITLE_TEXT := "TODAY'S STOCK"
const SUB_AT := Vector2(2, 28)
const SUB_SIZE := 13
const SUB_TEXT := "Today’s %d are dealt from the green shelves."
const HOVER_TEXT := "%s: %d of today’s %d"
const ROWS_TOP := 52.0
const ROW_HEIGHT := 34.0
const SIGN_RECT := Rect2(8, 5, 24, 24)
const GLYPH_SIZE := 18.0
const NAME_X := 42.0
const COUNT_X := 196.0
const COUNT_SIZE := 13
const TAG_RIGHT := 384.0
const TAG_SIZE := Vector2(84, 20)
const TAG_TEXT_SIZE := 11
const FOOTER_GAP := 8.0
const FOOTER_SIZE := 12
const FOOTER_TEXT := (
	"%d products in the deal’s pool · at most %d of a card (the staples count)."
	+ " LOCKED aisles open at their toy machine."
)
const STATE_TEXTS: Array[String] = ["DEALT FROM", "PRIZES ONLY", "NOT LISTED", "LOCKED"]
const LOCKED_ALPHA := 0.55

## Each row's shelf id (STAPLES_ID or an aisle id), state and count text, in row order.
var shelf_ids: Array[StringName] = []
var states: Array[State] = []
var counts: Array[String] = []
## The deal's pool's size.
var pool_size: int = 0
## The hovered row, or -1.
var hovered_index: int = -1
var _balance: BalanceDefinition
var _shared: Array[CardDefinition] = []
var _sub: Label
var _footer: Label
var _tags: Array[RevealChip] = []


## The shelves of `stock` (built from `balance`, the profile's `unlocked` items), today's deal
## `shared` drawn from `pool` (StartingDeck.deal_pool), at most `copy_max` of a card.
func _init(
	balance: BalanceDefinition,
	stock: RunStock,
	pool: Array[CardDefinition],
	shared: Array[CardDefinition],
	unlocked: Dictionary[StringName, int],
	copy_max: int
) -> void:
	name = "StockShelves"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = RECT.position
	size = RECT.size
	_balance = balance
	_shared = shared.duplicate()
	pool_size = pool.size()
	var chip: RevealChip = RevealChip.new(
		Palette.MUSTARD, NUMBER_CHIP.size, null, "3", 15, Palette.INK
	)
	chip.position = NUMBER_CHIP.position
	add_child(chip)
	var title: Label = UiKit.pixel_label(TITLE_TEXT, 2, Palette.MUSTARD_LIGHT)
	add_child(title)
	UiKit.place_pixel_label(title, TITLE_RECT, true)
	_sub = UiKit.body_label(SUB_TEXT % shared.size(), SUB_SIZE, Palette.TEAL_PALE)
	_sub.add_theme_font_override("font", CartReveal.font(700))
	_sub.position = SUB_AT
	add_child(_sub)
	_add_row(STAPLES_ID, "Staples", Palette.MUSTARD, RevealTile.LOCK_ICON, _staples_row(pool))
	for aisle: AisleDefinition in balance.aisles:
		var glyph: Texture2D = null
		if ResourceLoader.exists(ArtStyle.glyph_path(aisle)):
			glyph = load(ArtStyle.glyph_path(aisle)) as Texture2D
		_add_row(
			aisle.id,
			aisle.display_name,
			aisle.sign_color,
			glyph,
			_aisle_row(aisle, stock, pool, unlocked)
		)
	_footer = UiKit.body_label(FOOTER_TEXT % [pool_size, copy_max], FOOTER_SIZE, Palette.TEAL_PALE)
	_footer.add_theme_font_override("font", CartReveal.font(700))
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.position = Vector2(2, rows_bottom() + FOOTER_GAP)
	_footer.size = Vector2(RECT.size.x - 4, 0)
	add_child(_footer)


## The rows' bottom, in the shelves' coordinates.
func rows_bottom() -> float:
	return ROWS_TOP + shelf_ids.size() * ROW_HEIGHT


## Row `index`'s rect, in the shelves' coordinates.
func row_rect(index: int) -> Rect2:
	return Rect2(0, ROWS_TOP + index * ROW_HEIGHT, RECT.size.x, ROW_HEIGHT)


## The row under `point` (global), or -1.
func row_at(point: Vector2) -> int:
	var local: Vector2 = get_global_transform().affine_inverse() * point
	for index: int in shelf_ids.size():
		if row_rect(index).has_point(local):
			return index
	return -1


## The state of shelf `id`'s row (for tests); LOCKED for a shelf with no row.
func state_of(id: StringName) -> State:
	var index: int = shelf_ids.find(id)
	return states[index] if index >= 0 else State.LOCKED


## The shelf a card of today's deal comes from: STAPLES_ID for a staple, else its aisle's id
## (&"" for none).
func shelf_of(card: CardDefinition) -> StringName:
	for staple: CardDefinition in _balance.staples:
		if staple.is_same_product(card):
			return STAPLES_ID
	var aisle: AisleDefinition = _balance.aisle_of(card)
	return aisle.id if aisle != null else &""


## Today's deal's cards from shelf `id`.
func dealt_from(id: StringName) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardDefinition in _shared:
		if shelf_of(card) == id:
			found.append(card)
	return found


## Hovers row `index` (-1: none): the sub line names how many of today's deal came from it.
func set_hovered(index: int) -> void:
	if index == hovered_index:
		return
	hovered_index = index
	if index < 0:
		_sub.text = SUB_TEXT % _shared.size()
	else:
		var row_name: String = (
			"Staples" if shelf_ids[index] == STAPLES_ID else _aisle(shelf_ids[index]).display_name
		)
		_sub.text = HOVER_TEXT % [row_name, dealt_from(shelf_ids[index]).size(), _shared.size()]
	queue_redraw()


## The sub line's text (for tests).
func sub_text() -> String:
	return _sub.text


## The footer (for tests).
func footer() -> Label:
	return _footer


## The STAPLES row: its products, dealt from when the pool holds any of them.
func _staples_row(pool: Array[CardDefinition]) -> Array:
	var staples: Array[CardDefinition] = RunStock.staples(_balance)
	var dealt: bool = staples.any(pool.has)
	return [State.DEALT_FROM if dealt else State.PRIZES_ONLY, "%d items" % staples.size()]


## An aisle's row: [its State, its count text].
func _aisle_row(
	aisle: AisleDefinition,
	stock: RunStock,
	pool: Array[CardDefinition],
	unlocked: Dictionary[StringName, int]
) -> Array:
	var all_items: Array[CardDefinition] = aisle.base_cards + aisle.capsule_cards
	if stock.aisle_ids.has(aisle.id):
		var stocked: Array[CardDefinition] = []
		for card: CardDefinition in all_items:
			if stock.cards.has(card):
				stocked.append(card)
		var dealt: bool = stocked.any(pool.has)
		return [State.DEALT_FROM if dealt else State.PRIZES_ONLY, "%d items" % stocked.size()]
	if RunStock.is_listable(aisle, _balance, unlocked):
		return [State.NOT_LISTED, "%d items" % RunStock.items(aisle, unlocked).size()]
	var held: int = RunStock.items(aisle, unlocked).size()
	return [State.LOCKED, "%d/%d" % [held, all_items.size()]]


func _aisle(id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in _balance.aisles:
		if aisle.id == id:
			return aisle
	return null


func _add_row(
	id: StringName, text: String, sign_colour: Color, glyph: Texture2D, row: Array
) -> void:
	var index: int = shelf_ids.size()
	shelf_ids.append(id)
	var state: State = row[0]
	states.append(state)
	counts.append(row[1])
	var rect: Rect2 = row_rect(index)
	var line: Control = Control.new()
	line.name = "Row_%s" % id
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = rect.position
	line.size = rect.size
	line.modulate.a = LOCKED_ALPHA if state == State.LOCKED else 1.0
	add_child(line)
	var plate: ColorRect = ColorRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.color = sign_colour if state != State.LOCKED else Palette.GREY
	plate.position = SIGN_RECT.position
	plate.size = SIGN_RECT.size
	line.add_child(plate)
	if glyph != null:
		var art: TextureRect = UiKit.sprite(glyph)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.size = Vector2.ONE * GLYPH_SIZE
		art.position = SIGN_RECT.position + (SIGN_RECT.size - art.size) / 2.0
		line.add_child(art)
	var label: Label = UiKit.pixel_label(text, 2, Palette.PAPER)
	line.add_child(label)
	UiKit.place_pixel_label(label, Rect2(NAME_X, 0, COUNT_X - NAME_X - 4, ROW_HEIGHT), true)
	var count: Label = UiKit.body_label(row[1], COUNT_SIZE, Palette.TEAL_PALE)
	count.add_theme_font_override("font", CartReveal.font(700))
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.position = Vector2(COUNT_X, 0)
	count.size = Vector2(90, ROW_HEIGHT)
	line.add_child(count)
	var fill: Color = Palette.GOOD if state == State.DEALT_FROM else Palette.TEAL_BLACK
	if state == State.PRIZES_ONLY:
		fill = Palette.MUSTARD
	var ink: Color = Palette.INK if state != State.LOCKED else Palette.GREY_LIGHT
	if state == State.NOT_LISTED:
		ink = Palette.TEAL_PALE
	var tag: RevealChip = RevealChip.new(
		fill, TAG_SIZE, null, STATE_TEXTS[state], TAG_TEXT_SIZE, ink
	)
	tag.position = Vector2(TAG_RIGHT - TAG_SIZE.x, (ROW_HEIGHT - TAG_SIZE.y) / 2.0)
	line.add_child(tag)
	_tags.append(tag)


## The rows' well, its dividers and the hovered row's light.
func _draw() -> void:
	var well: Rect2 = Rect2(0, ROWS_TOP, RECT.size.x, rows_bottom() - ROWS_TOP)
	draw_rect(well.grow(2), Palette.INK)
	draw_rect(well, Palette.TEAL_BLACK)
	for index: int in shelf_ids.size():
		var rect: Rect2 = row_rect(index)
		if index == hovered_index:
			draw_rect(rect.grow(-1), Palette.TEAL_DARK)
			draw_rect(rect.grow(-1), Palette.GOLD, false, 2.0)
		if index > 0:
			draw_rect(
				Rect2(rect.position.x + 6, rect.position.y, rect.size.x - 12, 1), Palette.PANEL
			)
