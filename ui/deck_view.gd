class_name DeckView
extends PanelContainer
## The deck view (plan section 2, extended in full build phase 1), in the look of #56's deck view B
## (mock-up screens_deck_b.html): a teal hand basket (frames/basket_panel, its slotted foot and
## cart badge) holding shelves of tray items on steel price rails in its dark well. Its header
## holds the shown page's title and the framed Cart, Run info and Close buttons (the shown page's
## tab sunk on the paper face of a picked tab, FramedButton.selected).
##
## The Cart page (the cart and run info polish, 2026-11-12) shows the deck as items, one cell
## (DeckCell) per distinct card with its copies stacked behind it and counted on a cream label. Its
## top line counts the copies carrying each printed tag as icons: one FamilyCount chip per family
## (its glyph and the count in the number font; its tooltip names it and lights its cells), most
## common first. Products fill the shelves from the top left; the coupons stand at the right end of
## the last shelf, at least one empty column after the products, so a 15-card cart (up to 15
## distinct cards) fits on two shelves unscrolled. Each section's heading is a shelf-edge label
## (DeckShelf.heading: PRODUCTS 13). The empty rail between them says CART FULL, or how much room is
## left (ROOM_NOTE) on a shelf label of its own, outside the chooser. A BIG or GOLDEN copy shows its
## tier tag under its sticker (PriceSticker.tier_text), so a player never swaps one out unknowingly.
## An item picked at the start (the starter pack's or a dealt one, the set the cart reveal's "+"
## marked since v0.51: start_sources) carries the green START chip on its art for the whole run, its
## tooltip saying where it came from; the regulars and the machine's items carry none. Marks go by
## product (a later copy, even a BIG or GOLDEN one from the machine, shares its mark, since copies
## carry no origin in the save). A legend at the line's right names the chip. The tickets' family
## glyphs show their names below the ticket on hover (GlyphTips, mounted by the screen).
##
## The Run info page shows the run at a glance (RunInfoHero: the run family's card, the aisles in
## stock, the cart's families as big tiles), then the run's stock: every item the RECEIPT REWARDS
## machine can offer, products then coupons under their shelf labels, new arrivals with a NEW chip.
## Its shelves scroll. The upgrades (the top bar's LOYALTY card) and the inspections (the day
## calendar and slip) show elsewhere, so it repeats neither.
##
## Hovering an item opens the scan popup (ScanPopup, as on the machine's prizes) beside it with
## its rule text in full. The mix highlight (#105 piece 3, MixModel; mock-up readability v3's Cart)
## paints every cell of both pages: the hovered item lights the cells it works with (a broad "next
## Food" match faint) and greys the rest, and `mix_family` (a family glyph's tooltip in the view,
## PlanningEffects.watch_glyphs) lights that family's cells instead. Off in choosing mode.
##
## The family filter (the cart and run info polish, play feedback 2026-11-12): the page's family
## icons (the Cart's tag chips, the Run info's family tiles) switch its item grid. The pointer on
## one shows only that family's items (preview_family), re-packed from the grid's top left with no
## gap before the coupons (shelf_slots' `packed`); leaving it shows them all again. A click pins
## the filter (toggle_pin; the icon stays lit and sunk, FamilyCount.pinned), so the pointer may go
## read the items' popups; the pointer on another icon previews its family meanwhile, and leaving
## it returns to the pinned one. Clicking the pinned icon again, another icon (it switches), Esc
## (taken before the pause), switching tabs or closing the view clears it. An icon whose family
## has no item on the page does nothing. The icons never move: they scroll with the page, so the
## scroll stays put and a filtered grid keeps its unfiltered height (_hold_height), so the page
## neither shrinks under the pointer nor clamps its scroll. Off in choosing and placing mode. In
## choosing mode (#77) only the Cart page shows, a hovered item gets a gold ring, and clicking it
## chooses one of its copies (to remove it from the deck); Close cancels the pick. The machine's
## pick opens it in placing mode (2026-10-29, open_placing, CartPlacing): the prize's item rides on
## the pointer, the cart's free places show as gold RoomSpots in empty shelf spots, and the drop
## adds it (`added`), swaps an item's copy out (`card_chosen`) or goes back (`closed`). It only
## displays RunState and DeckSummary.

signal closed
signal card_chosen(card: CardInstance)
## Placing mode: the prize was dropped on a free spot.
signal added

const COLUMNS := 10
const GAP := 10.0
## Room on the right for the scroll bar.
const SCROLL_ROOM := 14.0
## The pages scroll inside this area, so the view fits the window at any deck or stock size. Two
## shelves with their heading bands and the tag line fit it unscrolled: any cart up to the deck
## limit (15 distinct cards at most).
const PAGE_SIZE := Vector2(COLUMNS * DeckCell.SIZE.x + (COLUMNS - 1) * GAP + SCROLL_ROOM, 480)
const PAGE_GAP := 4
## The Cart page always shows this many shelves (an empty rail is room left in the cart).
const MIN_SHELVES := 2
## The tag line's height (its chips and legend), the gap between its chips.
const TOP_LINE_HEIGHT := FamilyCount.CHIP_HEIGHT
const CHIP_GAP := 6
## The basket's 9-slice margin (art pixels) and padding (left, top, right, bottom).
const BASKET := preload("res://art/frames/basket_panel.png")
const BASKET_MARGIN := 5
const BASKET_PADDING := Vector4(14, 14, 14, 6)
const WELL := preload("res://art/frames/basket_well.png")
const WELL_MARGIN := 3
const WELL_PADDING := Vector4(10, 8, 6, 8)
const SLOTS := preload("res://art/frames/basket_slots.png")
const CART_ICON := preload("res://art/icons/cart.png")
const FOOT_HEIGHT := 14.0
const BADGE_SIZE := Vector2(48, 24)
const HEADER_HEIGHT := 40.0
const TITLE_SIZE := 24
const BUTTON_SIZE := Vector2(112, 40)
const BUTTON_FONT := 18
const LEGEND_SIZE := 15
const START_LEGEND := "picked at the start"
const PRODUCTS := "PRODUCTS %d"
const COUPONS := "COUPONS %d"
## The rail's note across the empty columns of the Cart's last shelf (outside the chooser).
const FULL_NOTE := "CART FULL"
const ROOM_NOTE := "ROOM FOR %d MORE"
## The Run info page's title, and its stock's heading and caption.
const INFO_TITLE := "Run info"
const STOCK_HEADING := "MACHINE STOCK"
const STOCK_CAPTION := "what the machine can offer this run"
const STOCK_CAPTION_SIZE := 16
## The gap above the stock's heading on the Run info page.
const STOCK_GAP := 6.0
## Each page's item grid's node name (for tests).
const GRID := "Grid"
## A grid's meta: its unfiltered shelf count (_hold_height).
const FULL_SHELVES := &"full_shelves"

## The family whose glyph's tooltip shows in the view (#105 piece 3), or "": its cells light.
var mix_family: String = "":
	set(value):
		if mix_family != value:
			mix_family = value
			_paint_mix()
## The mix highlight's grey (PlanningTuning's).
var tuning: PlanningTuning = load(PlanningEffects.TUNING_PATH) as PlanningTuning
## The family filter: the family the pointer previews, the pinned one ("" for none), and the
## family each page's grid shows now.
var _preview: String = ""
var _pinned: String = ""
var _deck_grid_family: String = ""
var _info_grid_family: String = ""
var _title: MixedLabel
var _deck_tab: FramedButton
var _info_tab: FramedButton
var _close_button: FramedButton
var _scroll: ScrollContainer
var _deck_page: VBoxContainer
var _info_page: VBoxContainer
## Each page's item grid (its shelves), its groups and its family icons (the filter's switches).
var _deck_grid: VBoxContainer
var _info_grid: VBoxContainer
var _deck_groups: Array[DeckSummary.Group] = []
var _stock_groups: Array[DeckSummary.Group] = []
var _arrivals: Array[CardDefinition] = []
var _deck_icons: Array[FamilyCount] = []
var _info_icons: Array[FamilyCount] = []
var _run: RunState
## The title the caller gave (the Cart page's; the Run info page shows INFO_TITLE).
var _cart_title: String = ""
var _choosing: bool = false
## Placing mode's held prize, and the Cart page's shelves with the slots its cells take.
var _placing: CartPlacing
var _shelves: Array[DeckShelf] = []
var _used_slots: Array[int] = []
## Where each product picked at the start came from (start_sources: product id → the START
## chip's tip), empty for a run with no dealt start (no marks).
var _sources: Dictionary[StringName, String] = {}
var _balance: BalanceDefinition
## The scan popup's layer (top level, over the view), the popup, and the hovered cell.
var _popup_layer: Control
var _popup: ScanPopup
var _hovered: DeckCell


func _init() -> void:
	var style: StyleBoxTexture = ArtStyle.frame_style(BASKET, BASKET_MARGIN)
	style.content_margin_left = BASKET_PADDING.x
	style.content_margin_top = BASKET_PADDING.y
	style.content_margin_right = BASKET_PADDING.z
	style.content_margin_bottom = BASKET_PADDING.w
	add_theme_stylebox_override("panel", style)
	ArtStyle.use_pixel_material(self)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.add_child(_header())
	var well: PanelContainer = UiKit.frame_panel(WELL, WELL_MARGIN, WELL_PADDING)
	well.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(well)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = PAGE_SIZE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _unhover())
	well.add_child(_scroll)
	var pages: VBoxContainer = VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)
	_deck_page = _page(pages)
	_info_page = _page(pages)
	column.add_child(_foot())
	_popup_layer = Control.new()
	_popup_layer.name = "PopupLayer"
	_popup_layer.top_level = true
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popup_layer)
	_popup = ScanPopup.new()
	_popup.name = "ScanPopup"
	_popup.visible = false
	_popup_layer.add_child(_popup)
	_placing = CartPlacing.new()
	add_child(_placing)
	_placing.added.connect(_on_placed_added)
	_placing.swapped.connect(_on_placed_swapped)
	_placing.cancelled.connect(_close)
	_placing.visible = false
	visibility_changed.connect(
		func() -> void:
			if not visible:
				_placing.end()
				_preview = ""
				_pinned = ""
	)
	visible = false


## `choosing`: only the deck shows, and clicking an item chooses a copy of it (to remove it).
func open(run: RunState, title: String, choosing: bool) -> void:
	_placing.end()
	_choosing = choosing
	_cart_title = title
	_sources.clear()
	if run.starter != null and run.starter.is_recipe():
		_sources = start_sources(run)
	_balance = run.balance
	_run = run
	_preview = ""
	_pinned = ""
	_unhover()
	_fill_deck_page(run)
	_fill_info_page(run)
	_deck_tab.visible = not choosing
	_info_tab.visible = not choosing
	show_page(false)
	# The items fan out as the panel pops in (#62).
	Sfx.play_at(self, "fan")
	UiKit.pop_in(self)


## Placing mode (the machine's pick): the cart with `room` free spots (at most the empty shelf
## spots) and `prize`'s item on the pointer (CartPlacing).
func open_placing(run: RunState, title: String, prize: CardDefinition, room: int) -> void:
	open(run, title, true)
	var spots: Array[RoomSpot] = _add_room_spots(room)
	var held: CardInstance = CardInstance.new(prize, -1)
	var shown: Callable = func(cell: DeckCell) -> void:
		if cell != null:
			hover(cell)
		else:
			_unhover()
	_placing.begin(held, _balance.aisle_of(prize), cells(), spots, _close_button, shown)


## The placing mode's held prize (for tests).
func placing() -> CartPlacing:
	return _placing


## Shows the Run info tab, or the Cart tab.
func show_page(info: bool) -> void:
	_unhover()
	_preview = ""
	_pinned = ""
	_deck_page.visible = not info
	_info_page.visible = info
	_deck_tab.disabled = not info
	_info_tab.disabled = info
	_deck_tab.selected = not info
	_info_tab.selected = info
	_title.set_text(INFO_TITLE if info else _cart_title)
	_refilter()
	_scroll.scroll_vertical = 0


## The family filter's preview: the pointer rests on `family`'s icon ("": on none). An icon whose
## family has no item on the shown page previews nothing, and nothing filters in choosing mode.
func preview_family(family: String) -> void:
	var wanted: String = family if can_filter(family) else ""
	if wanted != _preview:
		_preview = wanted
		_refilter()


## A click on `family`'s icon: pins its filter, or unpins it when it is the pinned one (a family
## with no item on the shown page: nothing).
func toggle_pin(family: String) -> void:
	if not can_filter(family):
		return
	_pinned = "" if _pinned == family else family
	_refilter()


## Clears the pinned filter and the preview (Esc).
func clear_filter() -> void:
	_preview = ""
	_pinned = ""
	_refilter()


## The family the shown page's grid shows ("" for all): the previewed one, else the pinned one.
func filter_family() -> String:
	return _preview if not _preview.is_empty() else _pinned


## The pinned family, or "".
func pinned_family() -> String:
	return _pinned


## Whether `family` can filter the shown page (some item on it has the family; never in choosing
## mode).
func can_filter(family: String) -> bool:
	if _choosing or family.is_empty() or _deck_page == null:
		return false
	var groups: Array[DeckSummary.Group] = _stock_groups if _info_page.visible else _deck_groups
	return groups.any(func(group: DeckSummary.Group) -> bool: return group.card.tags.has(family))


## The shown page's family icons (the Cart's tag chips, the Run info's tiles), in order.
func family_icons() -> Array[FamilyCount]:
	return _info_icons if _info_page.visible else _deck_icons


## The pointer is at `at` (the viewport's coordinates): the family icon under it previews its
## family (the view's _input calls it; tests too).
func point_at(at: Vector2) -> void:
	var icon: FamilyCount = _icon_at(at)
	preview_family(icon.family if icon != null else "")


## A left click at `at`: the family icon under it pins or unpins its filter. Whether one was hit.
func click_at(at: Vector2) -> bool:
	var icon: FamilyCount = _icon_at(at)
	if icon == null or not can_filter(icon.family):
		return false
	toggle_pin(icon.family)
	return true


## The texts on the shown page, in order (a MixedLabel's as one line), but the items' own
## (their stickers, names, counts and marks) (for tests).
func texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for node: Node in _shown_page().find_children("*", "", true, false):
		var text: String = ""
		if node is MixedLabel:
			text = (node as MixedLabel).text
		elif node is Label and not node.get_parent() is MixedLabel:
			text = (node as Label).text
		if not text.is_empty() and not _is_in_cell(node):
			found.append(text)
	return found


## The title's text (for tests).
func title_text() -> String:
	return _title.text


## The item views on the shown page, in order (for tests).
func card_views() -> Array[CardView]:
	var found: Array[CardView] = []
	for cell: DeckCell in cells():
		found.append(cell.item())
	return found


## The cells on the shown page, in order (for tests).
func cells() -> Array[DeckCell]:
	var found: Array[DeckCell] = []
	for cell: Node in _shown_page().find_children("*", "DeckCell", true, false):
		found.append(cell as DeckCell)
	return found


## The scan popup (for tests and captures).
func popup() -> ScanPopup:
	return _popup


## The pointer rests on `cell`'s item: its art lifts and the scan popup opens beside it (and the
## chooser rings it). The item's hover calls it; tests and captures call it directly.
func hover(cell: DeckCell) -> void:
	if _hovered == cell:
		return
	_unhover()
	_hovered = cell
	var item: ItemView = cell.item()
	item.lifted = true
	cell.ringed = _choosing and not _placing.is_holding()
	_popup.visible = true
	_popup.show_card(item.card.definition, item.tags())
	_popup.place_at(
		item.get_global_transform() * Rect2(ItemView.TRAY_SPRITE, ItemView.SPRITE_SIZE),
		item.below_rect(),
		get_viewport_rect(),
		_scroll.get_global_rect()
	)
	_paint_mix()


func _header() -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, HEADER_HEIGHT)
	header.add_theme_constant_override("separation", 10)
	var icon: TextureRect = UiKit.sprite(CART_ICON)
	icon.custom_minimum_size = CART_ICON.get_size() * ArtStyle.ART_SCALE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(icon)
	_title = MixedLabel.new("", TITLE_SIZE, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_deck_tab = _framed(header, "Cart", func() -> void: show_page(false), "ui_switch")
	_info_tab = _framed(header, "Run info", func() -> void: show_page(true), "ui_switch")
	_close_button = _framed(header, "Close", func() -> void: _close(), "ui_close")
	return header


func _framed(parent: Control, text: String, action: Callable, sound: String) -> FramedButton:
	var button: FramedButton = UiKit.framed_button(
		parent, text, action, BUTTON_FONT, UiKit.SIGN_FRAME, BUTTON_SIZE, sound
	)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


## The basket's slotted foot with the cart badge in its middle.
func _foot() -> HBoxContainer:
	var foot: HBoxContainer = HBoxContainer.new()
	foot.custom_minimum_size = Vector2(0, FOOT_HEIGHT)
	foot.add_theme_constant_override("separation", 8)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: int in 2:
		var slots: TextureRect = UiKit.tiled(SLOTS)
		slots.custom_minimum_size = Vector2(0, FOOT_HEIGHT)
		slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(slots)
		if side == 0:
			var badge: RevealChip = RevealChip.new(Palette.TEAL_DARK, BADGE_SIZE, CART_ICON)
			badge.custom_minimum_size = BADGE_SIZE
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			foot.add_child(badge)
	return foot


func _input(event: InputEvent) -> void:
	if not visible or _choosing:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if not _pinned.is_empty():
			# Esc clears the pinned filter first; the next one opens the pause.
			get_viewport().set_input_as_handled()
			clear_filter()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		point_at(motion.position)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		click_at(button.position)


## The shown page's family icon under `at` (viewport coordinates), inside the scroll area and not
## under something drawn over the view, or null.
func _icon_at(at: Vector2) -> FamilyCount:
	if not visible or not _scroll.get_global_rect().has_point(at):
		return null
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered != null and hovered != self and not is_ancestor_of(hovered):
		return null
	for icon: FamilyCount in family_icons():
		if is_instance_valid(icon) and icon.is_visible_in_tree():
			if icon.get_global_rect().has_point(at):
				return icon
	return null


## Shows the filter's family on the shown page's grid (and every item on the hidden page's),
## rebuilding a grid only when its family changed (the scroll left as it is); then the icons'
## looks.
func _refilter() -> void:
	if _run == null:
		return
	var family: String = filter_family()
	var deck_family: String = "" if _info_page.visible else family
	var info_family: String = family if _info_page.visible else ""
	var changed: bool = false
	if deck_family != _deck_grid_family:
		_unhover()
		_fill_deck_grid(deck_family)
		changed = true
	if info_family != _info_grid_family:
		_unhover()
		_fill_info_grid(info_family)
		changed = true
	if changed:
		_paint_mix()
	var shown: Array[FamilyCount] = family_icons()
	for icon: FamilyCount in _deck_icons + _info_icons:
		if is_instance_valid(icon):
			icon.pinned = shown.has(icon) and icon.family == _pinned
			icon.lit = shown.has(icon) and icon.family == _preview and not icon.pinned


func _fill_deck_page(run: RunState) -> void:
	_clear(_deck_page)
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "TagLine"
	top.add_theme_constant_override("separation", CHIP_GAP)
	top.custom_minimum_size = Vector2(0, TOP_LINE_HEIGHT)
	_deck_page.add_child(top)
	var tags: HBoxContainer = _tag_chips(run.deck.cards)
	tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tags)
	_deck_icons.clear()
	for chip: Node in tags.get_children():
		if chip is FamilyCount:
			_deck_icons.append(chip as FamilyCount)
	if not _sources.is_empty():
		top.add_child(_legend())
	_deck_groups = DeckSummary.groups(run.deck.cards)
	_deck_grid = _grid(_deck_page)
	_fill_deck_grid("")


## The Cart's shelves: every item (with the room left on the rail), or `family`'s items packed
## from the top left on as few shelves as they take.
func _fill_deck_grid(family: String) -> void:
	_clear(_deck_grid)
	_deck_grid_family = family
	var filtered: bool = not family.is_empty()
	var groups: Array[DeckSummary.Group] = _of_family(_deck_groups, family)
	_shelves = _shelve(_deck_grid, groups, 1 if filtered else MIN_SHELVES, true, [], filtered)
	_hold_height(_deck_grid, _shelves.size(), filtered)
	if not _choosing and not filtered:
		_note_room(_run)


## The Run info's stock shelves: every item, or `family`'s packed.
func _fill_info_grid(family: String) -> void:
	_clear(_info_grid)
	_info_grid_family = family
	var groups: Array[DeckSummary.Group] = _of_family(_stock_groups, family)
	var filtered: bool = not family.is_empty()
	var shelves: int = _shelve(_info_grid, groups, 1, false, _arrivals, filtered).size()
	_hold_height(_info_grid, shelves, filtered)


## Keeps `grid` (now `shelves` shelves) as tall as unfiltered while `filtered` (the unfiltered
## shelf count is kept on it, FULL_SHELVES), so the page's height and its scroll never change and
## the family icons above it stay under the pointer.
static func _hold_height(grid: Control, shelves: int, filtered: bool) -> void:
	if not filtered:
		grid.set_meta(FULL_SHELVES, shelves)
	var full: int = grid.get_meta(FULL_SHELVES, shelves)
	var height: float = full * (DeckShelf.BAND_HEIGHT + DeckCell.SIZE.y) + (full - 1) * PAGE_GAP
	grid.custom_minimum_size = Vector2(0, height if filtered else 0.0)


## `groups` whose card has `family`'s printed tag (all of them for "").
static func _of_family(
	groups: Array[DeckSummary.Group], family: String
) -> Array[DeckSummary.Group]:
	if family.is_empty():
		return groups
	var found: Array[DeckSummary.Group] = []
	for group: DeckSummary.Group in groups:
		if group.card.tags.has(family):
			found.append(group)
	return found


## A page's item grid: a column for its shelves, the page's gap between them.
func _grid(page: Control) -> VBoxContainer:
	var grid: VBoxContainer = VBoxContainer.new()
	grid.name = GRID
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("separation", PAGE_GAP)
	page.add_child(grid)
	return grid


## One FamilyCount chip per printed tag of `cards` (most common first, DeckSummary.tag_counts);
## a tag with no family look shows as its word and count.
func _tag_chips(cards: Array[CardInstance]) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Tags"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", CHIP_GAP)
	var counts: Dictionary[String, int] = DeckSummary.tag_counts(cards)
	var palette: FamilyPalette = FamilyPalette.shared()
	for tag: String in counts:
		var style: FamilyStyle = palette.style(tag)
		if style != null and style.glyph != null:
			var chip: FamilyCount = FamilyCount.new(style, counts[tag], FamilyCount.Look.CHIP)
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(chip)
		else:
			line.add_child(MixedLabel.new("%s %d" % [tag, counts[tag]], 16, true))
	return line


## Puts `groups`' cells on shelves added to `page` (at least `least` shelves): the products from
## the first slot, the coupons at the end of the last shelf (shelf_slots; right after the products
## when `packed`, the family filter's), each section under its shelf label. `cart`: the Cart
## page's (its cells get their START chips and copies, and the slots they take are kept for
## placing mode); else the stock's (the `arrivals` get their NEW chip).
func _shelve(
	page: Control,
	groups: Array[DeckSummary.Group],
	least: int,
	cart: bool,
	arrivals: Array[CardDefinition] = [],
	packed: bool = false
) -> Array[DeckShelf]:
	var products: Array[DeckSummary.Group] = []
	var coupons: Array[DeckSummary.Group] = []
	for group: DeckSummary.Group in groups:
		if group.card.is_product():
			products.append(group)
		else:
			coupons.append(group)
	var slots: Array[int] = shelf_slots(products.size(), coupons.size(), COLUMNS, packed)
	var shelves: Array[DeckShelf] = []
	var last_slot: int = 0 if slots.is_empty() else slots[-1]
	for _shelf: int in range(maxi(least, floori(last_slot / float(COLUMNS)) + 1)):
		shelves.append(DeckShelf.new(COLUMNS, GAP, true))
		page.add_child(shelves[-1])
	if cart and not packed:
		_used_slots = slots
	var ordered: Array[DeckSummary.Group] = products + coupons
	for index: int in ordered.size():
		var slot: int = slots[index]
		var shelf: DeckShelf = shelves[floori(slot / float(COLUMNS))]
		if index == 0 and not products.is_empty():
			shelf.heading(PRODUCTS % _copies(products), 0)
		if index == products.size():
			shelf.heading(COUPONS % _copies(coupons), slot % COLUMNS)
		var group: DeckSummary.Group = ordered[index]
		var cell: DeckCell = _cell(group.copies[0], group.copies.size())
		var product: StringName = group.card.product_card().id
		if cart and _sources.has(product):
			cell.add_start_mark(_sources[product])
		if not cart and arrivals.has(group.card):
			cell.add_new_mark()
		shelf.put(cell, slot % COLUMNS)
	return shelves


## The shelf slot (shelf * columns + column) of each of `products` products, then of `coupons`
## coupons: the products from the first slot, the coupons at the end of the last shelf, with
## at least one empty slot between the two when there are both; when `packed` (the family
## filter's), every one in a row from the first slot.
static func shelf_slots(
	products: int, coupons: int, columns: int, packed: bool = false
) -> Array[int]:
	var slots: Array[int] = []
	if packed:
		for index: int in products + coupons:
			slots.append(index)
		return slots
	var gap: int = 1 if products > 0 and coupons > 0 else 0
	var shelves: int = maxi(1, ceili(float(products + gap + coupons) / columns))
	for index: int in products:
		slots.append(index)
	for index: int in coupons:
		slots.append(shelves * columns - coupons + index)
	return slots


## Where each product picked at `run`'s start came from, by product id (a coupon by its own):
## its starter pack's cards and the dealt ones (by aisle), read from core
## (StartSetupRules.run_cart_lines), the first source of a product kept (StartTip.source_of says
## it). The regulars and the pins' cards are not picks: they carry no START chip.
static func start_sources(run: RunState) -> Dictionary[StringName, String]:
	var picks: Array[StartCartLine.Source] = [StartCartLine.Source.PACK, StartCartLine.Source.DEALT]
	var sources: Dictionary[StringName, String] = {}
	for line: StartCartLine in StartSetupRules.run_cart_lines(run.starter, run.balance, run.pins):
		var id: StringName = line.card.product_card().id
		if picks.has(line.source) and not sources.has(id):
			sources[id] = StartTip.source_of(line)
	return sources


static func _copies(groups: Array[DeckSummary.Group]) -> int:
	var copies: int = 0
	for group: DeckSummary.Group in groups:
		copies += group.copies.size()
	return copies


## CART FULL, or the room left (ROOM_NOTE), on the rail across the widest run of empty columns on
## the Cart's last shelf, when it is at least two columns wide.
func _note_room(run: RunState) -> void:
	var first: int = (_shelves.size() - 1) * COLUMNS
	var best: Vector2i = Vector2i(-1, -2)
	var start: int = -1
	for column: int in range(COLUMNS + 1):
		var free: bool = column < COLUMNS and not _used_slots.has(first + column)
		if free and start < 0:
			start = column
		elif not free and start >= 0:
			if column - 1 - start > best.y - best.x:
				best = Vector2i(start, column - 1)
			start = -1
	if best.y - best.x < 1:
		return
	if run.deck_is_full():
		_shelves[-1].note(FULL_NOTE, best.x, best.y, Palette.TOMATO, Palette.PAPER)
	else:
		var room: int = run.balance.deck_limit - run.deck.size()
		_shelves[-1].note(ROOM_NOTE % room, best.x, best.y, Palette.PAPER, Palette.INK)


## Up to `room` free spots in the Cart page's empty shelf spots, the first ones first.
func _add_room_spots(room: int) -> Array[RoomSpot]:
	var spots: Array[RoomSpot] = []
	for slot: int in range(_shelves.size() * COLUMNS):
		if spots.size() >= room:
			break
		if _used_slots.has(slot):
			continue
		var spot: RoomSpot = RoomSpot.new()
		_shelves[floori(slot / float(COLUMNS))].put_spot(spot, slot % COLUMNS)
		spots.append(spot)
	return spots


## The START chip's legend: the chip and what it means.
func _legend() -> HBoxContainer:
	var legend: HBoxContainer = HBoxContainer.new()
	legend.name = "Legend"
	legend.add_theme_constant_override("separation", 8)
	var chip: RevealChip = DeckCell.make_start_chip()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend.add_child(chip)
	var text: Label = UiKit.body_label(START_LEGEND, LEGEND_SIZE, Palette.TEAL_PALE)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	legend.add_child(text)
	return legend


func _fill_info_page(run: RunState) -> void:
	_clear(_info_page)
	var hero: RunInfoHero = RunInfoHero.new(run, _line_width())
	_info_page.add_child(hero)
	_info_icons = hero.family_tiles()
	_info_page.add_child(_spacer_height(STOCK_GAP))
	var heading: HBoxContainer = HBoxContainer.new()
	heading.name = "StockHeading"
	heading.add_theme_constant_override("separation", 12)
	_info_page.add_child(heading)
	var words: Control = RunInfoHero.pixel_heading(STOCK_HEADING, Palette.MUSTARD)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(words)
	var caption: Label = UiKit.body_label(STOCK_CAPTION, STOCK_CAPTION_SIZE, Palette.TEAL_PALE)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(caption)
	var stock: Array[CardInstance] = []
	for card: CardDefinition in run.stock.cards:
		stock.append(CardInstance.new(card, 0))
	_stock_groups = DeckSummary.groups(stock)
	_arrivals = run.stock.new_arrivals
	_info_grid = _grid(_info_page)
	_fill_info_grid("")
	_info_page.add_child(_spacer_height(STOCK_GAP))


## A cell for `card` with `copies` copies; its item's hover and clicks come to the view.
func _cell(card: CardInstance, copies: int) -> DeckCell:
	var cell: DeckCell = DeckCell.new(card, _balance.aisle_of(card.definition), copies)
	var item: ItemView = cell.item()
	item.clicked.connect(_on_card_clicked)
	item.hovered.connect(func(_view: ItemView) -> void: hover(cell))
	item.unhovered.connect(
		func(_view: ItemView) -> void:
			if _hovered == cell:
				_unhover()
	)
	if not _choosing:
		item.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return cell


func _unhover() -> void:
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.item().lifted = false
		_hovered.ringed = false
	_hovered = null
	if _popup != null:
		_popup.visible = false
	_paint_mix()


## The mix highlight on every cell of both pages: `mix_family`'s, else the hovered cell's
## matches, else none (and none in choosing mode).
func _paint_mix() -> void:
	if _deck_page == null or _info_page == null:
		return
	var painted: Array[DeckCell] = []
	var entries: Array[MixModel.Entry] = []
	var focus: MixModel.Entry = null
	for page: Control in [_deck_page, _info_page]:
		for found: Node in page.find_children("*", "DeckCell", true, false):
			var cell: DeckCell = found as DeckCell
			if cell.is_queued_for_deletion():
				continue
			var entry: MixModel.Entry = MixModel.Entry.new(cell.item().card, cell.item().tags())
			painted.append(cell)
			entries.append(entry)
			if cell == _hovered:
				focus = entry
	var looks: Array[MixModel.Look] = []
	if not _choosing and not mix_family.is_empty():
		looks = MixModel.for_family(entries, mix_family)
	elif not _choosing and focus != null:
		looks = MixModel.for_card(entries, focus, null, FamilyPalette.shared().quiet_families)
	for index: int in range(painted.size()):
		painted[index].mix_greyness = Vector2(tuning.mix_brightness, tuning.mix_saturation)
		painted[index].mix_look = looks[index] if index < looks.size() else MixModel.Look.NONE


static func _line_width() -> float:
	return PAGE_SIZE.x - SCROLL_ROOM


static func _spacer_height(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _page(parent: Control) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", PAGE_GAP)
	parent.add_child(page)
	return page


func _shown_page() -> VBoxContainer:
	return _info_page if _info_page.visible else _deck_page


func _is_in_cell(child: Node) -> bool:
	var node: Node = child.get_parent()
	while node != null and node != self:
		if node is DeckCell:
			return true
		node = node.get_parent()
	return false


static func _clear(page: Control) -> void:
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()


func _on_card_clicked(view: CardView) -> void:
	if _choosing and not _placing.is_holding():
		_unhover()
		visible = false
		card_chosen.emit(view.card)


func _on_placed_added() -> void:
	_unhover()
	visible = false
	added.emit()


func _on_placed_swapped(card: CardInstance) -> void:
	_unhover()
	visible = false
	card_chosen.emit(card)


func _close() -> void:
	_placing.end()
	_unhover()
	visible = false
	closed.emit()
