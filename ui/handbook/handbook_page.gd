class_name HandbookPage
extends Control
## The STAFF HANDBOOK (v1.06, mock-up keywords_guide.html, variant A, the user's pick: "a handbook
## is the best"): a store ring binder over the shaded screen that explains every word the tickets,
## the monitor and the shift use, one entry at a time, all from data (HandbookBook).
##
## Its look is the store's own pixel art (the guide polish of 2026-11-11): the binder's teal board
## (frames/handbook_cover: a stitched groove, brass corner caps) with its index tabs (HandbookButton
## TABs, the book's groups) tucked along its top edge and the CLOSE key (the primary tomato button)
## at its right. On the board, left, the contents on a receipt (frames/receipt_paper): the teal
## STAFF HANDBOOK sign (frames/sign) over the picked tab's entries (each one's mark and title, the
## picked one marked by the price-gun tick on a mustard pale band) and the deep-link hint on a pin
## card (frames/pin_card) at its foot (icons/right_click_hint: a tooltip and a mouse, its right
## button lit; resting the pointer on it shows HINT_TIP); the steel binder rings
## (icons/binder_ring) across the gutter; right, the picked entry (HandbookEntryView) on the popup
## sheet (frames/popup, the title's popups' paper with its gold trim) in a scrolling column.
## Opening shades the screen and raises the binder RISE px in RISE_STEPS (at once under `still`).
## It takes every click over the screen while open; Esc, CLOSE or a right-click outside the binder
## closes it, and it swallows Enter and Space (CONFIRM_KEYS) so nothing behind it acts on them. It
## opens at the last entry viewed (the book's first at first). Over the shift (mount with a top
## bar) the band from the screen's top down to the bar's foot is shaded deeper (TOP_SHADE_ALPHA,
## polish batch 2), so the shift's LOYALTY strip and ☰ button no longer stand beside CLOSE.
##
## Opened from the title's GUIDE plate, the shift's menu (TopBar's Guide), or a tooltip: a
## right-click while a tooltip shows opens that keyword's, family's or coupon's entry (mount wires
## GlyphTips.guide_requested, entry_for_target finds the entry), and such a tooltip says so on its
## footer (GlyphTips.guide_for). A screen with no GlyphTips (the title) gets the handbook's own,
## so the clips' chips and glyphs show their tips there too. Nothing in a run is timed, so the
## shift just waits behind it.
##
## The tutorial's replay (2026-11-14): on the book's first tab, a teal PLAY THE GUIDED SHIFT plate
## stands at the foot of the index column (REPLAY_RECT, just over the hint card). The page has no
## profile: a click emits replay_requested, and the owner sets TutorialFlags.GUIDE_REPLAY and saves
## the profile (the title: peek, change, save; a run: its profile, never the saved run). What the
## foot shows comes from `replay_offer` (read on every opening and after each click): the plate
## (OFFERED), the line REPLAY_SET_TEXT once the next new run is guided (SET), or nothing
## (HIDDEN: no owner, an unreadable profile, a guided run under way).
##
## Coupons not found yet (play test feedback, 2026-11-15): `discovered` (the owner's, read on
## every opening) says which coupons the profile has owned (CouponFinds); any other coupon's row
## in the COUPONS tab is locked: "???" beside its mark's dark silhouette, and no click opens it.
## A deep link (a coupon's tooltip) still opens its page.

signal opened(entry_id: StringName)
signal closed
## PLAY THE GUIDED SHIFT was clicked (the owner asks for the guided run; replay_offer is read
## again right after).
signal replay_requested

## What the first tab's foot shows (replay_offer): nothing, the replay plate, or the line saying
## the next new run is guided.
enum ReplayOffer { HIDDEN, OFFERED, SET }

const BINDER := Rect2(64, 48, 1152, 640)
const TAB_HEIGHT := 40.0
const TAB_WIDTH := 160.0
const TAB_GAP := 4.0
const TAB_LEFT := 20.0
## How far a tab tucks under the board's top edge (the picked one stands in front of it).
const TAB_TUCK := 8.0
const CLOSE_SIZE := Vector2(112, 40)
const BORDER := 2.0
const SHADOW := 6.0
const SHADE_ALPHA := 0.72
## Over the shift, the band down to the top bar's foot takes this much more ink.
const TOP_SHADE_ALPHA := 0.7
## The keys it swallows while open (nothing behind it acts on them).
const CONFIRM_KEYS: Array[Key] = [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
## The board's art and its 9-slice margin (art px), the pages', the hint card's and the rings'.
const COVER := preload("res://art/frames/handbook_cover.png")
const COVER_MARGIN := 5
const INDEX_PAPER := preload("res://art/frames/receipt_paper.png")
const INDEX_PAPER_MARGIN := 2
const ENTRY_PAPER := preload("res://art/frames/popup.png")
const ENTRY_PAPER_MARGIN := 4
const HINT_CARD := preload("res://art/frames/pin_card.png")
const HINT_CARD_MARGIN := 3
const RING := preload("res://art/icons/binder_ring.png")
const RING_SIZE := Vector2(28, 16)
const RING_EVERY := 72.0
## The pages on the board (binder coordinates): the contents receipt, the gutter the rings cross,
## the entry's sheet.
const INDEX_PAGE := Rect2(16, 16, 264, 608)
const SPINE_X := 298.0
const ENTRY_PAGE := Rect2(316, 16, 820, 608)
## The index column, its rows, the sign over it and the hint card under it (binder coordinates).
const TITLE_RECT := Rect2(28, 28, 240, 40)
const INDEX_RECT := Rect2(28, 84, 240, 456)
const ROW_SIZE := Vector2(240, 40)
const ROW_GAP := 4.0
## A locked coupon row's title, and the tint that darkens its mark to a silhouette.
const LOCKED_TITLE := "???"
const LOCKED_TINT := Color(0.12, 0.12, 0.16)
const HINT_RECT := Rect2(28, 536, 240, 76)
## The hint on the pin card (the guide feedback of 2026-11-11, round 3: "a mouse right clic icon"):
## a tooltip beside a mouse with its right button lit, HINT_SCALE times its art, centred on the
## card's paper face (above its HINT_FOOT px cream shade foot).
const HINT_ICON := preload("res://art/icons/right_click_hint.png")
const HINT_SCALE := 3.0
const HINT_FOOT := 4.0
## The hint's tooltip (round 4, "hovering it should show your textbox"): the game's own hover tip
## (GlyphTips), so it takes no clicks and the page's wheel still scrolls.
const HINT_TIP := "Right-click a tooltip to open its page."
## The entry's scrolling column on the sheet, inside its gold trim.
const DETAIL_RECT := Rect2(336, 32, 788, 584)
## The replay plate (or its line) at the index column's foot, just over the hint card (binder
## coordinates); the first tab's rows must end above it.
const REPLAY_RECT := Rect2(28, 484, 240, 44)
const REPLAY_TEXT := "PLAY THE GUIDED SHIFT"
const REPLAY_SET_TEXT := "Your next NEW RUN is the guided shift."
const REPLAY_SET_FONT := 13
const TITLE := "STAFF HANDBOOK"
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
## Returns the ReplayOffer to show at the first tab's foot, read on every opening and
## click on the plate. None: HIDDEN.
var replay_offer: Callable = Callable()
## Returns whether the coupon of card id (StringName) was found (CouponFinds.found on the owner's
## profile); read as the index builds. None: every coupon shows.
var discovered: Callable = Callable()
## The bar whose row is shaded deeper (the shift's top bar: mount), or null.
var shade_bar: Control = null:
	set(value):
		shade_bar = value
		queue_redraw()
## The PLAY THE GUIDED SHIFT plate (shown on the first tab when OFFERED) and its line (SET);
## read only.
var replay_plate: HandbookButton
var replay_note: Label
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
var _offer: ReplayOffer = ReplayOffer.HIDDEN


func _init(book: HandbookBook = null) -> void:
	name = "HandbookPage"
	_book = book if book != null else HandbookBook.shared()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
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
			TAB_LEFT + (TAB_WIDTH + TAB_GAP) * index, -TAB_HEIGHT + TAB_TUCK
		)
		tab_button.show_behind_parent = true
		tab_button.pressed.connect(show_group.bind(group_id))
		_binder.add_child(tab_button)
		_tabs[group_id] = tab_button
	_close = HandbookButton.new(HandbookButton.Kind.CLOSE, CLOSE_TEXT, CLOSE_SIZE)
	_close.name = "Close"
	_close.position = Vector2(BINDER.size.x - CLOSE_SIZE.x - 16, -CLOSE_SIZE.y - 2)
	_close.pressed.connect(close)
	_binder.add_child(_close)
	_index = Control.new()
	_index.name = "Index"
	_index.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_index.position = INDEX_RECT.position
	_index.size = INDEX_RECT.size
	_binder.add_child(_index)
	var board: PanelContainer = UiKit.frame_panel(UiKit.SIGN_FRAME, FramedButton.FRAME_MARGIN)
	board.name = "Sign"
	board.position = TITLE_RECT.position
	board.size = TITLE_RECT.size
	_binder.add_child(board)
	var title: Label = UiKit.pixel_label(TITLE, 2, Palette.PAPER)
	title.name = "Title"
	_binder.add_child(title)
	HandbookButton.centre_words(title, TITLE_RECT)
	var card: PanelContainer = UiKit.frame_panel(HINT_CARD, HINT_CARD_MARGIN)
	card.name = "HintCard"
	card.position = HINT_RECT.position
	card.size = HINT_RECT.size
	_binder.add_child(card)
	var hint: TipTarget = TipTarget.new()
	hint.name = "Hint"
	hint.texture = HINT_ICON
	hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint.stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(hint)
	hint.tip_text = HINT_TIP
	hint.tip_side = TipCard.Opens.ABOVE  # Just over the icon, clear of the entry.
	hint.size = HINT_ICON.get_size() * HINT_SCALE
	var face: Rect2 = HINT_RECT.grow_individual(0, 0, 0, -HINT_FOOT)
	hint.position = (face.get_center() - hint.size / 2.0).round()
	_binder.add_child(hint)
	_scroll = ScrollContainer.new()
	_scroll.name = "Entry"
	_scroll.position = DETAIL_RECT.position
	_scroll.size = DETAIL_RECT.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_binder.add_child(_scroll)
	_add_replay()
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
		page.shade_bar = top_bar
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
	_offer = _read_offer()
	_shown_id = target
	_build_index()  # What was found may have changed since the last opening.
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
		_show_tab(_tabs[group_id], group_id == _group)
	for index: int in range(_rows.size()):
		_rows[index].picked = _row_entries[index] == entry_id
	_show_replay()
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
## entry whose title opens the tip (a monitor line's "Opening deal ...", "2 for 1 ..."); a tip
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


## The entry a tip's text names (entry_for_target's last steps): a keyword's tooltip's keyword,
## else as entry_for_target says; or null.
func _entry_for_tip(target: TipTarget) -> HandbookEntry:
	var found: HandbookEntry = null
	# A keyword's own tooltip (a MORNING mark's on the belt): its keyword's entry.
	for keyword: String in GlyphText.KEYWORD_TIPS:
		if target.tip_text == GlyphText.keyword_tip(keyword):
			return _book.entry_for_keyword(keyword)
	# A dressed tip's title (a ticket colour's family): its family's or keyword's entry.
	if not target.tip_title.is_empty():
		found = _book.entry_for_family(target.tip_title)
		if found == null:
			found = _book.entry_for_keyword(target.tip_title.get_slice(" ", 0))
		if found != null:
			return found
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


## The tutorial's anchors on the handbook (TutorialAnchors, global canvas px): HANDBOOK_TABS, the
## index tabs together. Rect2() when the handbook is closed or the id isn't the handbook's.
func anchor_rect(id: StringName) -> Rect2:
	if not is_visible_in_tree() or id != TutorialAnchors.HANDBOOK_TABS or _tabs.is_empty():
		return Rect2()
	var whole: Rect2 = Rect2()
	for group_id: StringName in _tabs:
		var rect: Rect2 = _tabs[group_id].get_global_rect()
		whole = rect if not whole.has_area() else whole.merge(rect)
	return whole


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
	if key != null and key.keycode in CONFIRM_KEYS and not key.alt_pressed:
		get_viewport().set_input_as_handled()
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_RIGHT:
		var whole: Rect2 = binder_rect().grow_side(SIDE_TOP, TAB_HEIGHT)
		if not whole.has_point(press.position):
			get_viewport().set_input_as_handled()
			close()


## The replay plate and its line at the index column's foot (both hidden until shown).
func _add_replay() -> void:
	replay_plate = HandbookButton.new(HandbookButton.Kind.PLATE, REPLAY_TEXT, REPLAY_RECT.size)
	replay_plate.name = "Replay"
	replay_plate.position = REPLAY_RECT.position
	replay_plate.visible = false
	replay_plate.pressed.connect(_on_replay_pressed)
	_binder.add_child(replay_plate)
	replay_note = UiKit.body_label(REPLAY_SET_TEXT, REPLAY_SET_FONT, Palette.INK)
	replay_note.name = "ReplayNote"
	replay_note.add_theme_font_override("font", ArtStyle.bold_font(700))
	replay_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	replay_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	replay_note.position = REPLAY_RECT.position
	replay_note.size = REPLAY_RECT.size
	replay_note.visible = false
	_binder.add_child(replay_note)


## PLAY THE GUIDED SHIFT: the owner asks for the guided run (replay_requested), then the foot
## shows what replay_offer says now.
func _on_replay_pressed() -> void:
	replay_requested.emit()
	_offer = _read_offer()
	_show_replay()


func _read_offer() -> ReplayOffer:
	if not replay_offer.is_valid():
		return ReplayOffer.HIDDEN
	return replay_offer.call() as ReplayOffer


## The plate (OFFERED) or its line (SET) on the book's first tab only.
func _show_replay() -> void:
	var first: bool = not _book.group_ids.is_empty() and _group == _book.group_ids[0]
	replay_plate.visible = first and _offer == ReplayOffer.OFFERED
	replay_note.visible = first and _offer == ReplayOffer.SET


## A picked tab stands in front of the board, TAB_RISE taller; the others tuck behind it.
static func _show_tab(tab_button: HandbookButton, picked: bool) -> void:
	tab_button.picked = picked
	tab_button.show_behind_parent = not picked
	var rise: float = HandbookButton.TAB_RISE if picked else 0.0
	tab_button.size.y = TAB_HEIGHT + rise
	tab_button.position.y = -TAB_HEIGHT + TAB_TUCK - rise


func _build_index() -> void:
	for row: HandbookButton in _rows:
		_index.remove_child(row)
		row.free()
	_rows.clear()
	_row_entries.clear()
	var listed: Array[HandbookEntry] = _book.entries_in(_group)
	var marks: Array[Control] = []
	var room: float = HandbookButton.MARK_ROOM
	for listed_entry: HandbookEntry in listed:
		var mark: Control = HandbookMark.make(listed_entry)
		marks.append(mark)
		room = maxf(room, mark.custom_minimum_size.x)
	for index: int in range(listed.size()):
		var listed_entry: HandbookEntry = listed[index]
		var locked: bool = is_locked(listed_entry) and listed_entry.id != _shown_id
		var title: String = LOCKED_TITLE if locked else listed_entry.title
		if locked:
			marks[index].modulate = LOCKED_TINT
		var row: HandbookButton = HandbookButton.new(
			HandbookButton.Kind.ROW, title, ROW_SIZE, marks[index], room
		)
		row.name = "Row_%s" % listed_entry.id
		row.position = Vector2(0, (ROW_SIZE.y + ROW_GAP) * index)
		row.locked = locked
		row.pressed.connect(show_entry.bind(listed_entry.id))
		_index.add_child(row)
		_rows.append(row)
		_row_entries.append(listed_entry.id)


## Whether `entry` is a coupon's page the profile hasn't found yet (`discovered`): its card, or
## none of the retired cards it also explains.
func is_locked(entry: HandbookEntry) -> bool:
	if not discovered.is_valid() or entry.mark != HandbookEntry.Mark.CARD:
		return false
	if bool(discovered.call(StringName(entry.mark_value))):
		return false
	for card_id: String in entry.also_cards:
		if bool(discovered.call(StringName(card_id))):
			return false
	return true


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
	var band: Rect2 = top_shade_rect()
	if band.has_area():
		draw_rect(band, Color(Palette.INK, TOP_SHADE_ALPHA))


## The band shaded deeper over the shift (shade_bar), in its own coordinates: its width, from its
## top down to the bar's foot; none without a bar.
func top_shade_rect() -> Rect2:
	if shade_bar == null or not is_instance_valid(shade_bar):
		return Rect2()
	var bar: Rect2 = get_global_transform().affine_inverse() * shade_bar.get_global_rect()
	return Rect2(0.0, 0.0, size.x, maxf(bar.end.y, 0.0))


## The binder's body: a hard ink shadow, the teal board, the contents receipt and the entry's sheet
## on it with their hard shadows, and the steel rings across the gutter between them.
class _Binder:
	extends Control

	func _init() -> void:
		name = "Binder"
		mouse_filter = Control.MOUSE_FILTER_STOP
		ArtStyle.use_pixel_material(self)

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(Vector2.ONE * SHADOW, size), Palette.INK)
		draw_style_box(ArtStyle.frame_style(COVER, COVER_MARGIN), rect)
		for page: Rect2 in [INDEX_PAGE, ENTRY_PAGE]:
			draw_rect(Rect2(page.position + Vector2.ONE * BORDER, page.size), Palette.TEAL_BLACK)
		draw_style_box(ArtStyle.frame_style(INDEX_PAPER, INDEX_PAPER_MARGIN), INDEX_PAGE)
		draw_style_box(ArtStyle.frame_style(ENTRY_PAPER, ENTRY_PAPER_MARGIN), ENTRY_PAGE)
		var y: float = ENTRY_PAGE.position.y + RING_EVERY / 2.0
		while y < ENTRY_PAGE.end.y - RING_SIZE.y:
			var at: Vector2 = Vector2(SPINE_X - RING_SIZE.x / 2.0, y)
			draw_texture_rect(RING, Rect2(at, RING_SIZE), false)
			y += RING_EVERY
