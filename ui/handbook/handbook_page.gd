class_name HandbookPage
extends Control
## The STAFF HANDBOOK (v1.06, mock-up keywords_guide.html, variant A, the user's pick: "a handbook
## is the best"): a cream ring binder over the shaded screen that explains every word the tickets,
## the monitor and the shift use, one entry at a time, all from data (HandbookBook).
##
## The binder (BINDER at 1280x720) has its tabs (the book's groups) along its top edge and the
## CLOSE plate at its right; under them the page: the picked tab's index on the left (each entry's
## mark and title, the picked one mustard pale in an ink box), the binder rings down the spine, and
## the picked entry on the right (HandbookEntryView) in a scrolling column, with the deep-link hint
## under the index. Opening shades the screen and raises the binder RISE px in RISE_STEPS (at once
## under `still`). It takes every click over the screen while open; Esc, CLOSE or a right-click
## outside the binder closes it. It opens at the last entry viewed (the book's first at first).
##
## Opened from the title's GUIDE plate, the shift's menu (TopBar's Guide), or a tooltip: a
## right-click while a tooltip shows opens that keyword's, family's or coupon's entry (mount wires
## GlyphTips.guide_requested, entry_for_target finds the entry), and such a tooltip says so on its
## footer (GlyphTips.guide_for). A screen with no GlyphTips (the title) gets the handbook's own,
## so the clips' chips and glyphs show their tips there too. Nothing in a run is timed, so the
## shift just waits behind it.

signal opened(entry_id: StringName)
signal closed

const BINDER := Rect2(64, 48, 1152, 640)
const TAB_HEIGHT := 40.0
const TAB_WIDTH := 160.0
const TAB_GAP := 4.0
const TAB_LEFT := 16.0
const CLOSE_SIZE := Vector2(104, 34)
const BORDER := 2.0
const SHADOW := 6.0
const SHADE_ALPHA := 0.72
## The index column and the entry column, in the binder's coordinates.
const INDEX_RECT := Rect2(16, 64, 262, 500)
const ROW_SIZE := Vector2(262, 40)
const ROW_GAP := 4.0
const SPINE_X := 292.0
const RING_SIZE := Vector2(16, 10)
const RING_EVERY := 64.0
const DETAIL_RECT := Rect2(318, 24, 818, 600)
const HINT_RECT := Rect2(16, 582, 262, 44)
const TITLE_RECT := Rect2(16, 20, 262, 28)
const TITLE := "STAFF HANDBOOK"
const HINT := "RIGHT-CLICK A TOOLTIP\nTO OPEN ITS PAGE"
const CLOSE_TEXT := "CLOSE"
const RISE := 24.0
const RISE_STEPS := 4.0
const RISE_S := 0.16

## Shows the binder at once and the clips still (the profile's reduced motion).
var still: bool = false
## Returns true when the player asked for reduced motion, read on every opening (it sets `still`).
## None: `still` stays as set.
var reduced_motion: Callable = Callable()
## Returns true while a right-click belongs to something else (a cart placement cancels, a day slip
## or a pin card closes): the deep link then does nothing. None: never.
var deep_link_blocked: Callable = Callable()
var _book: HandbookBook
var _binder: Control
var _tabs: Dictionary[StringName, HandbookButton] = {}
var _rows: Array[HandbookButton] = []
var _row_entries: Array[StringName] = []
var _index: Control
var _scroll: ScrollContainer
var _view: HandbookEntryView
var _close: HandbookButton
var _group: StringName = &""
var _shown_id: StringName = &""
var _rise: Tween


func _init(book: HandbookBook = null) -> void:
	name = "HandbookPage"
	_book = book if book != null else HandbookBook.shared()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 50
	_binder = _Binder.new()
	_binder.position = BINDER.position
	_binder.size = BINDER.size
	add_child(_binder)
	for index: int in range(_book.group_ids.size()):
		var group_id: StringName = _book.group_ids[index]
		var tab_button: HandbookButton = HandbookButton.new(
			HandbookButton.Kind.TAB, _book.group_titles[index], Vector2(TAB_WIDTH, TAB_HEIGHT)
		)
		tab_button.name = "Tab_%s" % group_id
		tab_button.position = Vector2(
			TAB_LEFT + (TAB_WIDTH + TAB_GAP) * index, -TAB_HEIGHT + BORDER
		)
		tab_button.pressed.connect(show_group.bind(group_id))
		_binder.add_child(tab_button)
		_tabs[group_id] = tab_button
	_close = HandbookButton.new(HandbookButton.Kind.CLOSE, CLOSE_TEXT, CLOSE_SIZE)
	_close.name = "Close"
	_close.position = Vector2(BINDER.size.x - CLOSE_SIZE.x - 12, -CLOSE_SIZE.y - 4)
	_close.pressed.connect(close)
	_binder.add_child(_close)
	_index = Control.new()
	_index.name = "Index"
	_index.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_index.position = INDEX_RECT.position
	_index.size = INDEX_RECT.size
	_binder.add_child(_index)
	var title: Label = UiKit.pixel_label(TITLE, 2, Palette.INK)
	title.name = "Title"
	_binder.add_child(title)
	UiKit.place_pixel_label(title, TITLE_RECT)
	var hint: Label = UiKit.pixel_label(HINT, 2, Palette.TEAL_SHADE)
	hint.name = "Hint"
	_binder.add_child(hint)
	UiKit.place_pixel_label(hint, HINT_RECT)
	_scroll = ScrollContainer.new()
	_scroll.name = "Entry"
	_scroll.position = DETAIL_RECT.position
	_scroll.size = DETAIL_RECT.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_binder.add_child(_scroll)
	_shown_id = _book.first_entry


## Mounts a handbook over `screen` (added last, so it covers it) and wires the deep link: a
## right-click on `tips`' tooltip (none: a GlyphTips of the handbook's own) opens its entry, and
## `top_bar`'s Guide opens the last entry.
static func mount(screen: Control, tips: GlyphTips, top_bar: TopBar = null) -> HandbookPage:
	var page: HandbookPage = HandbookPage.new()
	screen.add_child(page)
	page.deep_link_blocked = right_click_taken.bind(screen)
	if tips == null:
		tips = GlyphTips.new()
		page.add_child(tips)
	page.reduced_motion = tips.reduced_motion
	page.still = tips.reduced_motion.is_valid() and bool(tips.reduced_motion.call())
	tips.guide_requested.connect(page.open_for_target)
	tips.guide_for = page.has_entry_for
	if top_bar != null:
		top_bar.guide_pressed.connect(page.open_at)
	return page


## Whether a right-click on `root`'s screen belongs to something else: a cart placement held (it
## cancels), a day slip or a pin's card open (it closes them).
static func right_click_taken(root: Node) -> bool:
	for node: Node in root.find_children("*", "", true, false):
		var placing: CartPlacing = node as CartPlacing
		if placing != null and placing.is_holding():
			return true
		var slip: DaySlip = node as DaySlip
		if slip != null and slip.is_open():
			return true
		var lanyard: PinLanyard = node as PinLanyard
		if lanyard != null and lanyard.is_card_open():
			return true
	return false


## Opens the handbook at `entry_id` (none: the last entry viewed).
func open_at(entry_id: StringName = &"") -> void:
	var target: StringName = entry_id if _book.entry(entry_id) != null else _shown_id
	if _book.entry(target) == null and not _book.entries.is_empty():
		target = _book.entries[0].id
	var was_open: bool = visible
	if reduced_motion.is_valid():
		still = bool(reduced_motion.call())
	visible = true
	show_entry(target)
	if not was_open:
		_rise_in()
	opened.emit(target)


## Opens the entry of the tooltip `target` shows (entry_for_target), unless the right-click belongs
## to something else (deep_link_blocked) or the target names no entry.
func open_for_target(target: TipTarget) -> void:
	if deep_link_blocked.is_valid() and bool(deep_link_blocked.call()):
		return
	var found: HandbookEntry = entry_for_target(target)
	if found != null:
		open_at(found.id)


func close() -> void:
	if not visible:
		return
	visible = false
	if _rise != null:
		_rise.kill()
	if _view != null and _view.clip() != null:
		_view.clip().stop()
	closed.emit()


func is_open() -> bool:
	return visible


## Shows tab `group_id`'s index and its first entry (the shown entry when it is in that tab).
func show_group(group_id: StringName) -> void:
	var listed: Array[HandbookEntry] = _book.entries_in(group_id)
	if listed.is_empty():
		return
	var current: HandbookEntry = _book.entry(_shown_id)
	if current != null and current.group == group_id:
		show_entry(_shown_id)
	else:
		show_entry(listed[0].id)


## Shows entry `entry_id`: its tab picked, its index row picked, its page on the right.
func show_entry(entry_id: StringName) -> void:
	var picked: HandbookEntry = _book.entry(entry_id)
	if picked == null:
		return
	_shown_id = entry_id
	if picked.group != _group:
		_group = picked.group
		_build_index()
	for group_id: StringName in _tabs:
		_tabs[group_id].picked = group_id == _group
	for index: int in range(_rows.size()):
		_rows[index].picked = _row_entries[index] == entry_id
	if _view != null:
		_scroll.remove_child(_view)
		_view.free()
	_view = HandbookEntryView.new(
		picked, DETAIL_RECT.size.x - 18.0, _book.group_title(picked.group), still
	)
	_scroll.add_child(_view)
	_scroll.scroll_vertical = 0


## The entry a tooltip's target names: a keyword chip's keyword; on a coupon's ticket (its colour,
## its glyph, its price) that coupon's own entry; a family glyph's family; else its tip's first
## word (a ticket colour's "Breakfast colour", a family word) as a family or a keyword, or an
## entry whose title opens the tip (a monitor line's "Spot check ...", "Opening deal ..."); a tip
## that says WASTED opens WASTED. Null when none fits.
func entry_for_target(target: TipTarget) -> HandbookEntry:
	if target == null:
		return null
	var chip: KeywordChip = target as KeywordChip
	if chip != null:
		return _book.entry_for_keyword(chip.keyword)
	var ticket: PriceSticker = PriceSticker.of(target)
	if ticket != null and ticket.card() != null and ticket.card().is_coupon():
		var coupon: HandbookEntry = _book.entry_for_card(String(ticket.card().id))
		if coupon != null:
			return coupon
	var glyph: FamilyGlyph = target as FamilyGlyph
	if glyph != null:
		return _book.entry_for_family(glyph.family)
	return _entry_for_tip(target)


## The entry a tip's text names (entry_for_target's last steps), or null.
func _entry_for_tip(target: TipTarget) -> HandbookEntry:
	var found: HandbookEntry = null
	var words: PackedStringArray = target.tip_text.split(" ", false)
	if not words.is_empty():
		var first: String = words[0].rstrip(GlyphText.TRAILING)
		found = _book.entry_for_family(first)
		if found == null:
			found = _book.entry_for_keyword(first)
		if found == null:
			found = _book.entry_titled(target.tip_text)
	if found == null and target.full_tip().contains(CardText.WASTED_WORD):
		found = _book.entry_for_keyword(CardText.WASTED_WORD)
	return found


## Whether right-clicking `target`'s tooltip opens an entry (its tip says so: GlyphTips.guide_for).
func has_entry_for(target: TipTarget) -> bool:
	return entry_for_target(target) != null


func shown_entry() -> HandbookEntry:
	return _book.entry(_shown_id) if visible else null


func shown_group() -> StringName:
	return _group


func entry_view() -> HandbookEntryView:
	return _view


## The binder's rect (canvas coordinates; without its tabs).
func binder_rect() -> Rect2:
	return _binder.get_global_rect()


func tab(group_id: StringName) -> HandbookButton:
	return _tabs.get(group_id) as HandbookButton


func index_rows() -> Array[HandbookButton]:
	return _rows.duplicate()


func close_button() -> HandbookButton:
	return _close


func entry_scroll() -> ScrollContainer:
	return _scroll


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_RIGHT:
		var whole: Rect2 = binder_rect().grow_side(SIDE_TOP, TAB_HEIGHT)
		if not whole.has_point(press.position):
			get_viewport().set_input_as_handled()
			close()


func _build_index() -> void:
	for row: HandbookButton in _rows:
		_index.remove_child(row)
		row.free()
	_rows.clear()
	_row_entries.clear()
	var listed: Array[HandbookEntry] = _book.entries_in(_group)
	for index: int in range(listed.size()):
		var listed_entry: HandbookEntry = listed[index]
		var row: HandbookButton = HandbookButton.new(
			HandbookButton.Kind.ROW, listed_entry.title, ROW_SIZE, HandbookMark.make(listed_entry)
		)
		row.name = "Row_%s" % listed_entry.id
		row.position = Vector2(0, (ROW_SIZE.y + ROW_GAP) * index)
		row.pressed.connect(show_entry.bind(listed_entry.id))
		_index.add_child(row)
		_rows.append(row)
		_row_entries.append(listed_entry.id)


func _rise_in() -> void:
	if _rise != null:
		_rise.kill()
	_binder.position = BINDER.position
	modulate.a = 1.0
	if still or not is_inside_tree():
		return
	_rise = create_tween()
	_rise.tween_method(_step_rise, 0.0, 1.0, RISE_S)


func _step_rise(share: float) -> void:
	var stepped: float = floorf(share * RISE_STEPS) / RISE_STEPS
	_binder.position = BINDER.position + Vector2(0.0, roundf(RISE * (1.0 - stepped)))
	modulate.a = 0.4 + 0.6 * stepped


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, SHADE_ALPHA))


## The binder's body: a hard ink shadow, an ink outline round the cream page, a cream shade
## index column with its spine and the binder rings down it.
class _Binder:
	extends Control

	func _init() -> void:
		name = "Binder"
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(Vector2.ONE * SHADOW, size), Palette.INK)
		draw_rect(rect, Palette.INK)
		var page: Rect2 = rect.grow(-BORDER)
		draw_rect(page, Palette.CREAM)
		draw_rect(Rect2(page.position, Vector2(page.size.x, BORDER)), Palette.PAPER)
		var column: Rect2 = Rect2(page.position, Vector2(SPINE_X - BORDER, page.size.y))
		draw_rect(column, Palette.CREAM_SHADE)
		draw_rect(Rect2(SPINE_X, BORDER, BORDER, page.size.y), Palette.INK)
		var y: float = RING_EVERY
		while y < size.y - RING_EVERY / 2.0:
			var ring: Rect2 = Rect2(Vector2(SPINE_X - RING_SIZE.x / 2.0 + 1.0, y), RING_SIZE)
			draw_rect(ring, Palette.INK)
			draw_rect(ring.grow(-BORDER), Palette.STEEL_LIGHT)
			draw_rect(Rect2(ring.position + Vector2(BORDER, BORDER), Vector2(4, 2)), Palette.PAPER)
			y += RING_EVERY
