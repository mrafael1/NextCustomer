class_name FigurineBook
extends Control
## The FIGURINE BOOK (v1.26 round 2; it replaces the FIGURINE SHELF, the user: "transform to a
## glossary ... a card book, like a pokemon card book, with cards of items sorted by family,
## maybe a sorting feature too"): a 1280x720 stage (the TOY MACHINES' own, never scaled) of one
## 640x360 art scene at 2x (BookArt): the stock room after closing, a binder open on the counter
## under two lamps. Its pages of clear sleeves (three by two a page, PER_SPREAD a spread) hold
## one trading card per product of the game (BookOrder: every family, starters too), each a
## BookCard: full colour when owned (a starter always is), grey with a ? when not collected yet,
## the name and the rule readable either way. A card drawn since the book was last opened wears
## the NEW tag (and the FAMILY options it shows under a dot); opening the book marks them seen
## (the TOY MACHINES call CapsuleCounter.mark_all_seen after show_collection). Round 3: the book
## ends with
## the COUPONS, a card per coupon of the live pools (BookOrder), owned once played in an ended
## run; a coupon never wears NEW (nothing draws it at the machines).
##
## The LED at the top left counts every card owned, coupons included ("31/58 CARDS"), the one at
## the right the new figurines; each page's header names what it shows with its count. The
## arrows, the keys and the wheel turn the pages with a pixel page turn (BookPageTurn; at once
## under reduced motion); BACK (or Escape) returns where the book was opened from (back_pressed).
## Every word is hard pixel lettering, its numbers in the number font. Rounds 4 to 6 (divider
## tabs per family, a SORT dropdown of FAMILY, NEWEST, FOOD and NON-FOOD, OTHER FOOD for a family
## too small for a tab of its own, BookOrder.MIN_GROUP) led to round 7:
##
## Round 7 (the user: "double family are a problem for breakfast and clearance ... remove family
## section on top of book => book stay sorted as all by default and don't show doublon ... sort by
## family can be removed from sort and have its own dropdown somewhere where old bookmarks where
## ... sort can keep newest / food / non-food. it will sort selected first dropdown"): the tabs
## are gone. The book opens on ALL in book order (the families in palette order, OTHER FOOD,
## the coupons last), each card once, each group's pages headed as before. The FAMILY dropdown
## (a PixelDropdown where the tabs stood, top left over the binder) picks ALL or a family
## (BookOrder.families: every family that had a tab, OTHER FOOD, COUPONS; each with its glyph),
## and shows every card carrying it; an option holding a NEW card carries a dot, the closed plate
## too when any does. The SORT dropdown (the footer's, the same PixelDropdown) picks BOOK ORDER
## (the default), NEWEST, FOOD or NON-FOOD, within the family picked: a family's pages are headed
## with the family, the sort and the count of what shows ("BREAKFAST · NON-FOOD 2/2"; ALL's
## "NEWEST FIRST 31/58", "NON-FOOD 7/18"), and a pick that shows nothing says so (NO CARDS). One
## list is open at a time (opening one closes the other); a click outside closes it.
##
## The keys: Left and Right (Page Up and Down) and the wheel turn the pages; Up and Down step the
## FAMILY pick (wrapping); Tab and Shift+Tab step the SORT pick; Enter or Space opens the SORT
## list; while a list is open, Up and Down move its mark, Enter or Space picks, and Esc (or
## Backspace) closes it; with none open, Esc (or Backspace) leaves the book.

signal back_pressed

const STAGE := Vector2(1280, 720)
const PER_PAGE := BookArt.COLUMNS * BookArt.ROWS
const PER_SPREAD := PER_PAGE * 2
const TITLE_TEXT := "FIGURINE BOOK"
const CARDS_TEXT := "CARDS"
const NEW_TEXT := "NEW"
const COUNT_TEXT := "%d/%d"
const NEWEST_HEADER := "NEWEST FIRST"
const FOOD_TEXT := "FOOD"
const NON_FOOD_TEXT := "NON-FOOD"
## The dropdowns (round 7): FAMILY's prefix and first option, SORT's prefix and options (one per
## BookOrder.Sort, in its order); a sort's word in a family's header (none for BOOK ORDER).
const FAMILY_PREFIX := "FAMILY:"
const ALL_TEXT := "ALL"
const SORT_PREFIX := "SORT:"
const SORT_CAPTIONS: Array[String] = ["BOOK ORDER", "NEWEST", FOOD_TEXT, NON_FOOD_TEXT]
const SORT_WORDS: Array[String] = ["", "NEWEST", FOOD_TEXT, NON_FOOD_TEXT]
## A pick that shows no card (COUPONS + FOOD): its page says so, EMPTY_TOP art px under the
## page's top.
const EMPTY_TEXT := "NO CARDS"
const EMPTY_TOP := 120
## The FAMILY sort's header under ALL for the unfamilied last pages (round 6: a small family's
## items not printed Food land there).
const OTHER_ITEMS_TEXT := "OTHER ITEMS"
const PAGE_TEXT := "PAGE"
const BACK_TEXT := "BACK"
const TURN_SOUND := "card_pickup"
const BACK_SOUND := "ui_back"
## The LEDs (art px): the count at COUNT_AT, the NEW one right-aligned on NEW_RIGHT; LED_HEIGHT
## tall, their row's cap top LED_CAP_TOP, LED_PADDING each side.
const COUNT_AT := Vector2i(10, 5)
const NEW_RIGHT := 630
const LED_HEIGHT := 20
const LED_CAP_TOP := 7
const LED_PADDING := Vector2i(8, 8)
const LED_GAP := 4
## The title: 2x paper words on a board in the TOY MACHINES board's style (BookArt.
## title_board; review fix: the cream plate didn't match the sister screen) centred on the stage,
## TITLE_TOP art px down.
const TITLE_TOP := 2
const TITLE_CAP_TOP := 4
const TITLE_PADDING := 10
## A page's header: its cap top HEADER_AT art px from the page's top left.
const HEADER_AT := Vector2i(6, 5)
## The FAMILY dropdown's plate (canvas px; round 7), where the tabs stood: over the binder's
## top left, under the count LED, its list opening down over the pages.
const FAMILY_RECT := Rect2(36, 52, 320, 34)
## The footer (canvas px): the SORT dropdown's plate, the arrows round the page LED and BACK (the
## TOY MACHINES' DONE rect).
const SORT_RECT := Rect2(36, 662, 264, 40)
const PREV_RECT := Rect2(476, 662, 52, 40)
const NEXT_RECT := Rect2(752, 662, 52, 40)
const PAGE_LED_CENTRE := 320
const PAGE_LED_TOP := 332
const BACK_RECT := Rect2(1080, 656, 160, 56)
const PLATE_FRAMES: Array[Texture2D] = [
	preload("res://art/frames/button_teal.png"), preload("res://art/frames/button_teal_lit.png")
]
## The arrows' chevrons: CHEVRON_ROWS rows of a 2 px stroke (art px), paper, or teal shade on
## an arrow with no spread its way.
const CHEVRON_ROWS := 5
## The plates' hover tick, canvas px left of a plate (the TOY MACHINES').
const TICK_LEFT := 14.0

var _palette: FamilyPalette
var _book: Array[BookEntry] = []
var _fresh: Array[StringName] = []
## The FAMILY dropdown's values, in its order: "" (ALL) first, then BookOrder.families.
var _families: PackedStringArray = PackedStringArray([""])
var _sort: BookOrder.Sort = BookOrder.Sort.BOOK
var _filter: String = ""
var _pages: Array[Array] = []
var _spread: int = 0
var _still: bool = false
var _pages_layer: Control
## The shown spread's page layers (left, right) and, during a turn, the layers to drop when it
## lands (the page under the sheet's landing and the sheet's front) and the one it brings (its
## back).
var _sides: Array[Control] = [null, null]
var _leaving: Control
var _front: Control
var _arriving: Control
## Pages built ahead while the book is idle (by page index), so a turn only swaps them in.
var _ready_pages: Dictionary[int, Control] = {}
var _turn: BookPageTurn
var _count_led: ToyLed
var _new_led: ToyLed
var _page_led: ToyLed
var _family_menu: PixelDropdown
var _sort_menu: PixelDropdown
var _prev: MenuPlate
var _next: MenuPlate
var _back: MenuPlate
var _chevrons: Array[Control] = []


func _init() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_palette = FamilyPalette.shared()
	var backdrop: TextureRect = UiKit.sprite(BookArt.backdrop())
	backdrop.size = STAGE
	add_child(backdrop)
	_pages_layer = Control.new()
	_pages_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pages_layer.size = STAGE
	add_child(_pages_layer)
	_turn = BookPageTurn.new()
	_turn.turned.connect(_on_turned)
	add_child(_turn)
	_build_header()
	_build_footer()
	# The cards' family glyphs name their family in the game's tip (round 7), none while a page
	# turns or a list is open (its catcher covers the glyphs anyway).
	var tips: GlyphTips = GlyphTips.new()
	tips.blocked = func() -> bool:
		return _turn.is_turning() or _family_menu.is_open() or _sort_menu.is_open()
	tips.reduced_motion = func() -> bool: return _still
	add_child(tips)


## Fills the book with `balance`'s products, owned per `unlocked` (the profile's drawn items, in
## draw order), and its coupons, owned per `used_coupons` (the profile's coupon_uses), the cards
## of `fresh` wearing the NEW tag (dropping in unless `still`, which also turns pages at once).
## It opens on its first spread, ALL in BOOK ORDER.
func show_collection(
	balance: BalanceDefinition,
	unlocked: Dictionary[StringName, int],
	used_coupons: Dictionary[StringName, int],
	fresh: Array[StringName],
	still: bool = false
) -> void:
	_still = still
	_fresh = fresh.duplicate()
	_book = BookOrder.entries(balance, unlocked, _palette.main_family_order, used_coupons)
	_families = PackedStringArray([""])
	_families.append_array(BookOrder.families(_book, _palette.main_family_order))
	var captions: Array[String] = []
	var icons: Array[Texture2D] = []
	var dots: Array[bool] = []
	for family: String in _families:
		var style: FamilyStyle = _family_style(family) if not family.is_empty() else null
		captions.append(style.display_name.to_upper() if style != null else ALL_TEXT)
		icons.append(style.glyph if style != null else null)
		var fresh_here: Callable = func(entry: BookEntry) -> bool:
			return _is_new(entry) and (family.is_empty() or entry.has_family(family))
		dots.append(_book.any(fresh_here))
	_family_menu.set_options(captions, icons, dots)
	_sort_menu.close_list()
	_sort = BookOrder.Sort.BOOK
	_filter = ""
	_show_leds()
	_relayout()


## Sorts the family picked (BOOK, NEWEST, FOOD or NON_FOOD) and opens the book on its first
## spread.
func set_sort(sort: BookOrder.Sort) -> void:
	_sort = sort
	_relayout()


## Keeps only `family`'s cards ("" for every family; one the book has no option for is ALL),
## sorted as picked, and opens the book on its first spread.
func set_filter(family: String) -> void:
	_filter = family if _families.has(family) else ""
	_relayout()


func sort_mode() -> BookOrder.Sort:
	return _sort


func filter() -> String:
	return _filter


## Turns `step` spreads (1 forward, -1 back); false when there is none that way.
func turn(step: int) -> bool:
	var target: int = _spread + step
	if step == 0 or target < 0 or target >= spread_count():
		return false
	if _turn.is_turning():
		_turn.finish()
	var forward: bool = step > 0
	_spread = target
	var left: Control = _build_page(0)
	var right: Control = _build_page(1)
	if _still:
		_drop(_sides[0])
		_drop(_sides[1])
		_sides = [left, right]
	else:
		var kept: int = 0 if forward else 1
		_front = _sides[1 - kept]
		_leaving = _sides[kept]
		_arriving = left if forward else right
		for face: Control in [_front, _arriving] as Array[Control]:
			if face != null:
				face.reparent(_turn, false)
		_sides = [left, right]
		_turn.play(forward, _front, _arriving)
	Sfx.play_at(self, TURN_SOUND)
	_show_nav()
	return true


## Which spread shows (0 the first) and how many there are.
func spread() -> int:
	return _spread


func spread_count() -> int:
	return maxi(ceili(_pages.size() / 2.0), 1)


## The cards on the shown spread, left page first (during a turn, the spread being turned to).
func cards() -> Array[BookCard]:
	var found: Array[BookCard] = []
	for side: Control in _sides:
		if side == null:
			continue
		for child: Node in side.get_children():
			if child is BookCard:
				found.append(child as BookCard)
	return found


## The page header's line on `side` (0 left, 1 right), or null on an empty page.
func header(side: int) -> PixelLine:
	return _sides[side].get_node_or_null("Header") as PixelLine if _sides[side] != null else null


## The pieces, for tests and the screen capture.
func page_turn() -> BookPageTurn:
	return _turn


func family_menu() -> PixelDropdown:
	return _family_menu


func sort_menu() -> PixelDropdown:
	return _sort_menu


## The FAMILY dropdown's values in its order ("" for ALL first).
func families() -> PackedStringArray:
	return _families


func prev_button() -> MenuPlate:
	return _prev


func next_button() -> MenuPlate:
	return _next


func back_button() -> MenuPlate:
	return _back


## The LEDs: the cards owned, the new ones (hidden with none), the page.
func leds() -> Array[ToyLed]:
	var found: Array[ToyLed] = [_count_led, _new_led, _page_led]
	return found


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not is_visible_in_tree() or key == null or not key.pressed:
		return
	get_viewport().set_input_as_handled()
	var menu: PixelDropdown = _family_menu if _family_menu.is_open() else _sort_menu
	if menu.is_open() or key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if not key.echo or key.keycode in [KEY_UP, KEY_DOWN]:
			menu.handle_key(key.keycode)
		return
	match key.keycode:
		KEY_RIGHT, KEY_PAGEDOWN:
			turn(1)
		KEY_LEFT, KEY_PAGEUP:
			turn(-1)
		KEY_UP, KEY_DOWN:
			var step: int = 1 if key.keycode == KEY_DOWN else -1
			_on_family_picked(posmod(_families.find(_filter) + step, _families.size()))
		KEY_TAB:
			var step: int = -1 if key.shift_pressed else 1
			_on_sort_picked(posmod(_sort + step, BookOrder.Sort.size()))
		KEY_ESCAPE, KEY_BACKSPACE:
			if not key.echo:
				_go_back()


func _gui_input(event: InputEvent) -> void:
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		turn(1)
		accept_event()
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		turn(-1)
		accept_event()


## The pages for the sort and filter, shown from the first spread at once.
func _relayout() -> void:
	if _turn.is_turning():
		_turn.finish()
	_pages = BookOrder.pages(_book, _sort, _filter, PER_PAGE, _palette.main_family_order)
	if _pages.is_empty():
		_pages.append([])  # A pick that shows nothing: one page, headed, saying so.
	_spread = 0
	for index: int in _ready_pages:
		_drop(_ready_pages[index])
	_ready_pages.clear()
	_drop(_sides[0])
	_drop(_sides[1])
	_sides = [_build_page(0), _build_page(1)]
	_sort_menu.show_value(_sort)
	_family_menu.show_value(_families.find(_filter))
	_show_nav()


## Page `side` of the shown spread (built ahead while idle, or now): its header, its cards in
## their pockets and the sleeves' sheen over them. Its NEW tags drop in as it comes on screen.
func _build_page(side: int) -> Control:
	var index: int = _spread * 2 + side
	if _ready_pages.has(index):
		var built: Control = _ready_pages[index]
		_ready_pages.erase(index)
		built.visible = true
		for child: Node in built.get_children():
			var card: BookCard = child as BookCard
			if card != null and card.new_tag() != null:
				card.new_tag().set_shown(false, true)
				card.new_tag().set_shown(true, _still)
		return built
	return _make_page(index, side)


## Builds the page `index` of the book (on side `side` of its spread).
func _make_page(index: int, side: int) -> Control:
	var layer: Control = Control.new()
	layer.name = "Page%d" % side
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = STAGE
	_pages_layer.add_child(layer)
	if index >= _pages.size():
		return layer
	var page: Array = _pages[index]
	var art: float = ArtStyle.ART_SCALE
	var line: PixelLine = PixelLine.new()
	line.name = "Header"
	line.show_tokens(_header_tokens(page), Palette.CREAM_SHADE, Palette.GOLD, 1, LED_GAP)
	line.position = Vector2(BookArt.PAGE_RECTS[side].position + HEADER_AT) * art
	layer.add_child(line)
	if page.is_empty():
		var note: PixelLine = PixelLine.new()
		note.name = "Empty"
		note.show_tokens([EMPTY_TEXT], Palette.CREAM_SHADE, Palette.GOLD)
		var rect: Rect2i = BookArt.PAGE_RECTS[side]
		var left: float = floorf((rect.size.x * art - note.width()) / 2.0 / art) * art
		note.position = Vector2(rect.position) * art + Vector2(left, EMPTY_TOP * art)
		layer.add_child(note)
	for slot: int in page.size():
		var entry: BookEntry = page[slot]
		var style: FamilyStyle = _family_style(entry.family)
		if entry.coupon:
			style = BookCard.coupon_style(entry.card, _palette)
		var card: BookCard = BookCard.new(entry, style, _is_new(entry), _still, _palette)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var pocket: Vector2i = BookArt.pocket_origin(side, slot)
		card.place(Vector2(pocket + BookArt.CARD_INSET) * art)
		layer.add_child(card)
		var sheen: TextureRect = UiKit.sprite(BookArt.sheen())
		sheen.position = Vector2(pocket) * art
		sheen.size = Vector2(BookArt.POCKET_SIZE) * art
		layer.add_child(sheen)
	return layer


## A page's header. ALL in BOOK ORDER: the page's group's glyph, name and count (its group's
## cards; round 6: OTHER FOOD, the unfamilied last pages "OTHER ITEMS"). Round 7, every other
## pick: the family picked (its glyph and name; none for ALL), the sort's word after a separator
## (none for BOOK ORDER), and the count of the cards the pick shows ("BREAKFAST · NON-FOOD 2/2");
## ALL alone reads "NEWEST FIRST 31/58", "FOOD 22/40" (with Food's glyph) or "NON-FOOD 7/18".
func _header_tokens(page: Array) -> Array:
	if _filter.is_empty() and _sort == BookOrder.Sort.BOOK:
		var group: String = BookOrder.page_family(page)
		var counted: Vector2i = BookOrder.count(_book, group, true)
		if group.is_empty():
			return [OTHER_ITEMS_TEXT, COUNT_TEXT % [counted.x, counted.y]]
		var tokens: Array = _family_tokens(group)
		tokens.append(COUNT_TEXT % [counted.x, counted.y])
		return tokens
	var shown: Vector2i = BookOrder.count_shown(_book, _sort, _filter)
	var words: Array = []
	if not _filter.is_empty():
		words = _family_tokens(_filter)
		if _sort != BookOrder.Sort.BOOK:
			words.append_array([PixelLine.SEPARATOR, SORT_WORDS[_sort]])
	elif _sort == BookOrder.Sort.NEWEST:
		words.append(NEWEST_HEADER)
	else:
		if _sort == BookOrder.Sort.FOOD:
			words = _family_tokens(BookEntry.FOOD_TAG).slice(0, -1)
		words.append(SORT_WORDS[_sort])
	words.append(COUNT_TEXT % [shown.x, shown.y])
	return words


## `family`'s glyph (when it has one) and name in capitals.
func _family_tokens(family: String) -> Array:
	var tokens: Array = []
	var style: FamilyStyle = _family_style(family)
	if style != null and style.glyph != null:
		tokens.append(style.glyph)
	tokens.append(style.display_name.to_upper() if style != null else family.to_upper())
	return tokens


## A family's look for its FAMILY option and its pages' header (BookCard.family_style: the
## coupons', OTHER FOOD's), or null.
func _family_style(family: String) -> FamilyStyle:
	return BookCard.family_style(family, _palette)


## Whether `entry`'s card wears the NEW tag: drawn since the book was last opened (an id the
## profile lists but doesn't own, which a real draw never leaves, shows nothing; a coupon never:
## the machines never draw one).
func _is_new(entry: BookEntry) -> bool:
	return entry.owned and not entry.coupon and _fresh.has(entry.card.id)


func _drop(layer: Control) -> void:
	if layer == null:
		return
	if layer.get_parent() != null:
		layer.get_parent().remove_child(layer)
	layer.queue_free()


func _on_turned() -> void:
	_drop(_leaving)
	_drop(_front)
	_leaving = null
	_front = null
	if _arriving != null:
		_arriving.reparent(_pages_layer, false)
		_arriving.visible = true
	_arriving = null


## While idle, builds the pages of the spreads either side of the shown one ahead, one page a
## frame, hidden (a turn then only swaps them in), and lets go of any further away.
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _turn.is_turning():
		return
	var wanted: Array[int] = []
	for spread_index: int in [_spread + 1, _spread - 1]:
		if spread_index >= 0 and spread_index < spread_count():
			wanted.append_array([spread_index * 2, spread_index * 2 + 1])
	for index: int in _ready_pages.keys():
		if not wanted.has(index):
			_drop(_ready_pages[index])
			_ready_pages.erase(index)
	for index: int in wanted:
		if index < _pages.size() and not _ready_pages.has(index):
			var layer: Control = _make_page(index, index % 2)
			layer.visible = false
			_ready_pages[index] = layer
			return


## The pages built ahead and waiting (their page indices), for tests.
func ready_pages() -> Array[int]:
	var found: Array[int] = []
	found.assign(_ready_pages.keys())
	return found


func _build_header() -> void:
	var art: float = ArtStyle.ART_SCALE
	_count_led = ToyLed.new()
	_count_led.position = Vector2(COUNT_AT) * art
	add_child(_count_led)
	_new_led = ToyLed.new()
	add_child(_new_led)
	var words: PixelLine = PixelLine.new()
	words.show_tokens([TITLE_TEXT], Palette.PAPER, Palette.PAPER, 2)
	var width: int = ceili(words.width() / art) + TITLE_PADDING * 2
	var board: TextureRect = UiKit.sprite(BookArt.title_board(width))
	board.name = "Title"
	board.size = Vector2(width, BookArt.TITLE_BOARD_HEIGHT) * art
	board.position = Vector2(floori((BookArt.STAGE.x - width) / 2.0), TITLE_TOP) * art
	words.position = Vector2(TITLE_PADDING, TITLE_CAP_TOP) * art
	board.add_child(words)
	add_child(board)


func _build_footer() -> void:
	_prev = _plate("", PREV_RECT)
	_prev.pressed.connect(func() -> void: turn(-1))
	_add_chevron(_prev, false)
	_next = _plate("", NEXT_RECT)
	_next.pressed.connect(func() -> void: turn(1))
	_add_chevron(_next, true)
	_page_led = ToyLed.new()
	add_child(_page_led)
	_back = MenuPlate.new(BACK_TEXT, MenuPlate.Kind.PRIMARY, BACK_RECT.size)
	_back.centre_caption()
	_back.position = BACK_RECT.position
	_back.pressed.connect(_go_back)
	_hover_marks(_back)
	add_child(_back)
	# Last, so their open lists stand over the pages and the footer; one open at a time.
	_sort_menu = PixelDropdown.new(SORT_PREFIX, SORT_RECT, false, STAGE)
	_sort_menu.name = "SortMenu"
	_sort_menu.set_options(SORT_CAPTIONS)
	_sort_menu.picked.connect(_on_sort_picked)
	add_child(_sort_menu)
	_family_menu = PixelDropdown.new(FAMILY_PREFIX, FAMILY_RECT, true, STAGE)
	_family_menu.name = "FamilyMenu"
	_family_menu.set_options([ALL_TEXT] as Array[String])
	_family_menu.picked.connect(_on_family_picked)
	add_child(_family_menu)
	_sort_menu.opened.connect(_family_menu.close_list)
	_family_menu.opened.connect(_sort_menu.close_list)
	_sort_menu.pass_through(_family_menu.plate(), _family_menu.open_list)
	_family_menu.pass_through(_sort_menu.plate(), _sort_menu.open_list)


func _plate(caption: String, rect: Rect2) -> MenuPlate:
	var plate: MenuPlate = MenuPlate.new(caption, MenuPlate.Kind.PLATE, rect.size)
	plate.use_frames(PLATE_FRAMES)
	plate.centre_caption(MenuPlate.PLATE_TEXT_SCALE)
	plate.position = rect.position
	_hover_marks(plate)
	add_child(plate)
	return plate


func _hover_marks(plate: MenuPlate) -> void:
	plate.tick().position.x = -TICK_LEFT
	plate.mouse_entered.connect(func() -> void: plate.marked = true)
	plate.mouse_exited.connect(func() -> void: plate.marked = false)


## An arrow plate's chevron (pointing right when `forward`), centred on its face, in paper.
func _add_chevron(plate: MenuPlate, forward: bool) -> void:
	var art: float = ArtStyle.ART_SCALE
	var chevron: Control = Control.new()
	chevron.name = "Chevron"
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows: int = CHEVRON_ROWS * 2 - 1
	chevron.size = Vector2(CHEVRON_ROWS + 1, rows) * art
	var face: Vector2 = plate.face_size()
	var lift: float = MenuPlate.PLATE_FACE_TOP - MenuPlate.PLATE_FACE_BOTTOM
	chevron.position = (
		(Vector2(face.x, face.y + lift) / art / 2.0 - chevron.size / art / 2.0).floor() * art
	)
	chevron.draw.connect(
		func() -> void:
			for row: int in rows:
				var reach: int = CHEVRON_ROWS - 1 - absi(row - (CHEVRON_ROWS - 1))
				var x: int = reach if forward else CHEVRON_ROWS - 1 - reach
				var ink: Color = Palette.TEAL_SHADE if plate.disabled else Palette.PAPER
				chevron.draw_rect(Rect2(Vector2(x, row) * art, Vector2(2, 1) * art), ink)
	)
	plate.caption_label().get_parent().add_child(chevron)
	_chevrons.append(chevron)


func _show_leds() -> void:
	var art: float = ArtStyle.ART_SCALE
	var counted: Vector2i = BookOrder.count(_book)
	var line: PixelLine = PixelLine.new()
	line.show_tokens(
		[COUNT_TEXT % [counted.x, counted.y], CARDS_TEXT], Palette.MUSTARD_DARK, Palette.GOLD
	)
	_count_led.show_rows([line], [LED_CAP_TOP], LED_HEIGHT, LED_PADDING)
	var fresh: int = 0
	for entry: BookEntry in _book:
		fresh += 1 if _is_new(entry) else 0
	_new_led.visible = fresh > 0
	var new_line: PixelLine = PixelLine.new()
	new_line.show_tokens([str(fresh), NEW_TEXT], Palette.TOMATO_LIGHT, Palette.GOLD)
	var width: float = _new_led.show_rows([new_line], [LED_CAP_TOP], LED_HEIGHT, LED_PADDING)
	_new_led.position = Vector2(NEW_RIGHT * art - width, COUNT_AT.y * art)


## The page LED ("PAGE 2/6") centred between the arrows; an arrow with no spread its way is off.
func _show_nav() -> void:
	var art: float = ArtStyle.ART_SCALE
	var line: PixelLine = PixelLine.new()
	line.show_tokens(
		[PAGE_TEXT, COUNT_TEXT % [_spread + 1, spread_count()]], Palette.MUSTARD_DARK, Palette.GOLD
	)
	var width: float = _page_led.show_rows([line], [LED_CAP_TOP], LED_HEIGHT, LED_PADDING)
	_page_led.position = Vector2(PAGE_LED_CENTRE * art - floorf(width / 2.0 / art) * art, 0)
	_page_led.position.y = PAGE_LED_TOP * art
	_prev.disabled = _spread <= 0
	_next.disabled = _spread >= spread_count() - 1
	for plate: MenuPlate in [_prev, _next] as Array[MenuPlate]:
		plate.marked = plate.marked and not plate.disabled
	for chevron: Control in _chevrons:
		chevron.queue_redraw()


func _on_family_picked(index: int) -> void:
	if _families[index] == _filter:
		_family_menu.show_value(index)
		return
	Sfx.play_at(self, UiKit.CLICK_SOUND)
	set_filter(_families[index])


func _on_sort_picked(sort: int) -> void:
	if sort == _sort:
		_sort_menu.show_value(_sort)
		return
	Sfx.play_at(self, UiKit.CLICK_SOUND)
	set_sort(sort as BookOrder.Sort)


func _go_back() -> void:
	if _turn.is_turning():
		_turn.finish()
	Sfx.play_at(self, BACK_SOUND)
	back_pressed.emit()
