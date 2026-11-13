class_name DeckView
extends PanelContainer
## The deck view (plan section 2, extended in full build phase 1), in the look of #56's deck view B
## (mock-up screens_deck_b.html): a teal hand basket (frames/basket_panel, its slotted foot and
## cart badge) with the pages in its dark well. Its header holds the shown page's title and the
## framed Cart, Run info and Close buttons (the shown page's tab sunk on the paper face of a
## picked tab, FramedButton.selected).
##
## The Cart page shows the cart as cards (mock-up docs/art/mockups/cart_cards.html, view CARDS,
## layout "2x8 cart face", approved by the user on 2026-11-13: "perfect with your recommended"):
## one small card face (DeckCell) per distinct card with its copies stacked behind it and counted,
## its FULL rule on it with its keywords and families as chips, its rarity on a tab (COMMON, RARE
## for BIG and the rare coupons, LEGENDARY with a gold foil for GOLDEN and the legendary coupons,
## machine.tres). The cards stand in CartLayout.ROWS rows of up to CartLayout.COLUMNS: the
## products from the top left, the coupons in a group of their own after them, behind a dashed
## separator, so a 15-card cart fits unscrolled at 1280x720 and 1920x1080 (a bigger one adds rows
## and scrolls). The page's top line counts the copies carrying each printed tag as icons (one
## FamilyCount chip per family, most common first), then the PRODUCTS shelf-edge label and the
## room left (ROOM FOR 2 MORE, or CART FULL; outside the chooser); the COUPONS label stands over
## the coupons' group and the START legend left of it. An item picked at the start (the starter
## pack's or a counted booster's, start_sources) wears the green START chip over its barcode, its
## tooltip saying where it came from; the regulars, swapped or not, and a pin's card carry none.
## Marks go by product (a later copy, even a BIG or GOLDEN one from the machine, shares its mark).
##
## The Run info page shows the run at a glance (RunInfoHero: the run family's card, the run's two
## aisles in stock and the staples' line, the cart's families as big tiles), then MACHINE STOCK as
## a compact icon grid (StockGrid: STAPLES, each aisle, COUPONS; an item's price or its coupon
## rarity, an in-cart badge). It scrolls only when the stock is too big for it. The upgrades (the
## top bar's LOYALTY card) and the inspections (the day calendar and slip) show elsewhere.
##
## Hovering a card lifts it and opens its paper tip (CardTip, the mock-up's hover_tips B) beside
## it: its rarity in the header's colour and tag, what its colour means ("Works with Breakfast"),
## its full rule, its price and families, where a START item came from, and a KEYWORD box for each
## keyword of its rule. Hovering a stock icon opens the tip with its card face and whether the cart
## holds it. The mix highlight (#105 piece 3, MixModel) paints the Cart's cards: the hovered
## card lights the cards it works with (a broad "next Food" match faint) and greys the rest, and
## `mix_family` (a family glyph's tooltip in the view, PlanningEffects.watch_glyphs) lights that
## family's cards instead. Off in choosing mode.
##
## The family filter (the cart and run info polish, play feedback 2026-11-12): the page's family
## icons (the Cart's tag chips, the Run info's family tiles) switch its items. On the Cart the
## pointer on one shows only that family's products (the coupons hide), re-packed from the top
## left (preview_family); on Run info the other families' icons dim where they stand. Leaving it
## shows them all again. A click pins the filter (toggle_pin; the icon stays lit and sunk,
## FamilyCount.pinned), so the pointer may go read the items' tips; the pointer on another icon
## previews its family meanwhile, and leaving it returns to the pinned one. Clicking the pinned icon
## again, another icon (it switches), Esc (taken before the pause), switching tabs or closing the
## view clears it. An icon whose family has no item on the page does nothing. The icons never move
## and a filtered grid keeps its unfiltered height, so the page neither shrinks under the pointer
## nor clamps its scroll. Off in choosing and placing mode. In choosing mode (#77) only the Cart
## page shows, a hovered card gets a gold ring, and clicking it chooses one of its copies (to remove
## it from the deck); Close cancels the pick. The machine's pick opens it in placing mode
## (2026-10-29, open_placing, CartPlacing): the prize's card rides on the pointer, the cart's free
## places show as gold RoomSpots after the products, and the drop adds it (`added`), swaps a card's
## copy out (`card_chosen`) or goes back (`closed`). It only displays RunState and DeckSummary.

signal closed
signal card_chosen(card: CardInstance)
## Placing mode: the prize was dropped on a free spot.
signal added

## The Cart's cards' grid (CartLayout) and its sides' padding.
const GRID_PAD := CartLayout.GRID_PAD
## Room on the right for the scroll bar.
const SCROLL_ROOM := 14.0
## The pages scroll inside this area, so the view fits the window at any cart or stock size. The
## top line and two rows of cards fit it unscrolled: any cart up to the deck limit (15 distinct
## cards at most).
const PAGE_SIZE := Vector2(1184, 480)
const PAGE_GAP := 4
## The top line's height (its chips and labels), the gap between its chips and between its parts.
const TOP_LINE_HEIGHT := 30.0
const CHIP_GAP := 6
const LINE_GAP := 14
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
## The START legend's gap before the COUPONS label.
const LEGEND_GAP := 16.0
const PRODUCTS := "PRODUCTS %d"
const COUPONS := "COUPONS %d"
## The shelf-edge labels: their size, padding and border.
const HEADING_SIZE := 16
const HEADING_PADDING := 8.0
const HEADING_BORDER := 2
## The room left on the top line (outside the chooser): CART FULL, or ROOM FOR n MORE.
const FULL_NOTE := "CART FULL"
const ROOM_NOTE := "ROOM FOR %d MORE"
const NOTE_SIZE := 16
const ROOM_NOTE_NAME := "RoomNote"
## The Run info page's title, and its stock's heading and caption.
const INFO_TITLE := "Run info"
const STOCK_HEADING := "MACHINE STOCK"
const STOCK_CAPTION := "what the machine can offer this run · hover an item for its card"
const STOCK_CAPTION_SIZE := 16
## The gap above the stock's heading on the Run info page.
const STOCK_GAP := 6.0
## Each page's item grid's node name (for tests), the top line's and the separator's.
const GRID := "Grid"
const TOP_LINE := "TagLine"
const SEPARATOR := "Separator"

## The family whose glyph's tooltip shows in the view (#105 piece 3), or "": its cards light.
var mix_family: String = "":
	set(value):
		if mix_family != value:
			mix_family = value
			_paint_mix()
## The mix highlight's grey (PlanningTuning's).
var tuning: PlanningTuning = load(PlanningEffects.TUNING_PATH) as PlanningTuning
## The family filter: the family the pointer previews, the pinned one ("" for none), and the
## family each page shows now.
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
## The Cart's top line (its chips stay; its labels follow the grid), its labels' row after the
## chips, and its grid; the Run info's stock grid.
var _top_line: Control
var _top_left: HBoxContainer
var _deck_grid: Control
var _info_grid: StockGrid
var _deck_groups: Array[DeckSummary.Group] = []
var _stock_groups: Array[DeckSummary.Group] = []
var _deck_icons: Array[FamilyCount] = []
var _info_icons: Array[FamilyCount] = []
var _run: RunState
## The title the caller gave (the Cart page's; the Run info page shows INFO_TITLE).
var _cart_title: String = ""
var _choosing: bool = false
## Placing mode's held prize, the free spots it shows and how many.
var _placing: CartPlacing
var _spots: Array[RoomSpot] = []
var _spot_count: int = 0
## Where each product picked at the start came from (start_sources: product id → the START
## chip's tip), empty for a run with no dealt start (no marks).
var _sources: Dictionary[StringName, String] = {}
var _balance: BalanceDefinition
## The tip's layer (top level, over the view), the tip, and the hovered card or icon.
var _popup_layer: Control
var _tip: CardTip
var _hovered: Control


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
	_tip = CardTip.new()
	_tip.visible = false
	_popup_layer.add_child(_tip)
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


## `choosing`: only the cart shows, and clicking a card chooses a copy of it (to remove it).
## `spots`: the free places placing mode shows (open_placing).
func open(run: RunState, title: String, choosing: bool, spots: int = 0) -> void:
	_placing.end()
	_choosing = choosing
	_spot_count = spots
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
	# The cards fan out as the panel pops in (#62).
	Sfx.play_at(self, "fan")
	UiKit.pop_in(self)


## Placing mode (the machine's pick): the cart with `room` free spots after its products and
## `prize`'s card on the pointer (CartPlacing).
func open_placing(run: RunState, title: String, prize: CardDefinition, room: int) -> void:
	open(run, title, true, room)
	var held: CardInstance = CardInstance.new(prize, -1)
	var shown: Callable = func(cell: DeckCell) -> void:
		if cell != null:
			hover(cell)
		else:
			_unhover()
	_placing.begin(held, _balance.machine, cells(), _spots, _close_button, shown)


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


## The family the shown page shows ("" for all): the previewed one, else the pinned one.
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


## The texts on the shown page, in order (a MixedLabel's as one line), but the cards' and the
## stock icons' own (their rules, counts and marks) (for tests).
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


## The cards on the shown page, in order (for tests; none on Run info).
func cells() -> Array[DeckCell]:
	return _cells_of(_shown_page())


## The cards on `page`, in the Cart's order (the grid holds them last first, _fill_deck_grid).
func _cells_of(page: Control) -> Array[DeckCell]:
	var found: Array[DeckCell] = []
	for cell: Node in page.find_children("*", "DeckCell", true, false):
		found.append(cell as DeckCell)
	found.reverse()
	return found


## The Run info's stock grid (for tests).
func stock_grid() -> StockGrid:
	return _info_grid


## The hover tip (for tests and captures).
func tip() -> CardTip:
	return _tip


## The pointer rests on `cell`'s card: it lifts and its tip opens beside it (and the chooser rings
## it). The card's hover calls it; tests and captures call it directly.
func hover(cell: DeckCell) -> void:
	if _hovered == cell:
		return
	_unhover()
	_hovered = cell
	cell.lifted = true
	cell.ringed = _choosing and not _placing.is_holding()
	_tip.visible = true
	_tip.show_card(cell.card, _machine(), _note_source(cell.card), cell.rule_clipped())
	_place_tip(cell.get_global_rect())
	_paint_mix()


## The pointer rests on a stock icon: it lights and its tip opens beside it with its card face
## and whether the cart holds it.
func hover_stock(icon: StockIcon) -> void:
	if _hovered == icon:
		return
	_unhover()
	_hovered = icon
	icon.lit = true
	_tip.visible = true
	_tip.show_stock(icon.card, _machine(), icon.in_cart)
	_place_tip(icon.get_global_rect())


func _place_tip(item: Rect2) -> void:
	var to_layer: Transform2D = _popup_layer.get_global_transform().affine_inverse()
	_tip.place_beside(to_layer * item, to_layer * _stage())


func _machine() -> MachineDefinition:
	return _balance.machine if _balance != null else null


## Where a START card came from, as its tip says it ("" for none).
func _note_source(card: CardDefinition) -> String:
	return _sources.get(card.product_card().id, "")


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


## Shows the filter's family on the shown page (and every item on the hidden page), rebuilding
## the Cart's cards only when its family changed (the scroll left as it is); then the icons'
## looks.
func _refilter() -> void:
	if _run == null:
		return
	var family: String = filter_family()
	var deck_family: String = "" if _info_page.visible else family
	var info_family: String = family if _info_page.visible else ""
	if deck_family != _deck_grid_family:
		_unhover()
		_fill_deck_grid(deck_family)
		_paint_mix()
	if info_family != _info_grid_family:
		_unhover()
		_info_grid_family = info_family
		_info_grid.filter(info_family)
	var shown: Array[FamilyCount] = family_icons()
	for icon: FamilyCount in _deck_icons + _info_icons:
		if is_instance_valid(icon):
			icon.pinned = shown.has(icon) and icon.family == _pinned
			icon.lit = shown.has(icon) and icon.family == _preview and not icon.pinned


func _fill_deck_page(run: RunState) -> void:
	_clear(_deck_page)
	_top_line = Control.new()
	_top_line.name = TOP_LINE
	_top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_line.custom_minimum_size = Vector2(0, TOP_LINE_HEIGHT)
	_deck_page.add_child(_top_line)
	_top_left = HBoxContainer.new()
	_top_left.name = "TopLeft"
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left.add_theme_constant_override("separation", LINE_GAP)
	_top_left.position = Vector2(GRID_PAD, 0)
	_top_left.size = Vector2(0, TOP_LINE_HEIGHT)
	_top_line.add_child(_top_left)
	var tags: HBoxContainer = _tag_chips(run.deck.cards)
	_top_left.add_child(tags)
	_deck_icons.clear()
	for chip: Node in tags.get_children():
		if chip is FamilyCount:
			_deck_icons.append(chip as FamilyCount)
	_deck_groups = DeckSummary.groups(run.deck.cards)
	_deck_grid = Control.new()
	_deck_grid.name = GRID
	_deck_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_page.add_child(_deck_grid)
	_fill_deck_grid("")


## The Cart's cards (CartLayout): every card with the coupons after the products, or `family`'s
## products packed from the top left (no coupons); the top line's labels over them. The grid
## keeps the unfiltered height.
func _fill_deck_grid(family: String) -> void:
	_clear(_deck_grid)
	_spots.clear()
	for index: int in range(_top_left.get_child_count() - 1, 0, -1):
		var part: Node = _top_left.get_child(index)
		_top_left.remove_child(part)
		part.queue_free()
	for part: Node in _top_line.get_children():
		if part != _top_left:
			_top_line.remove_child(part)
			part.queue_free()
	_deck_grid_family = family
	var filtered: bool = not family.is_empty()
	var products: Array[DeckSummary.Group] = []
	var coupons: Array[DeckSummary.Group] = []
	for group: DeckSummary.Group in _deck_groups:
		if group.card.is_product():
			if not filtered or group.card.tags.has(family):
				products.append(group)
		elif not filtered:
			coupons.append(group)
	var width: float = _line_width()
	var spots: int = 0 if filtered else _spot_count
	var layout: CartLayout = CartLayout.of(products.size() + spots, coupons.size(), width)
	var full: CartLayout = CartLayout.of(
		_products_of(_deck_groups) + _spot_count,
		_deck_groups.size() - _products_of(_deck_groups),
		width
	)
	_deck_grid.custom_minimum_size = Vector2(0, full.height)
	var ordered: Array[DeckSummary.Group] = products + coupons
	# Last first: each card draws over the next column's, so its copies' count (which may reach
	# over that card's corner beside a wide tab, DeckCell) stays whole.
	for index: int in range(ordered.size() - 1, -1, -1):
		var slot: int = index if index < products.size() else index + spots
		var group: DeckSummary.Group = ordered[index]
		var cell: DeckCell = _cell(group.copies[0], group.copies.size())
		var product: StringName = group.card.product_card().id
		if _sources.has(product):
			cell.add_start_mark(_sources[product])
		cell.position = layout.positions[slot]
		cell.fit_stack(layout.gap)
		_deck_grid.add_child(cell)
	for index: int in spots:
		var spot: RoomSpot = RoomSpot.new()
		spot.position = layout.positions[products.size() + index]
		_deck_grid.add_child(spot)
		_spots.append(spot)
	if not products.is_empty() and not coupons.is_empty():
		var separator: CartLayout.DashLine = CartLayout.DashLine.new()
		separator.name = SEPARATOR
		separator.position = Vector2(
			(
				layout.coupon_x
				- (CartLayout.GROUP_GAP + layout.gap) / 2.0
				- CartLayout.DASH_LINE / 2.0
			),
			0
		)
		separator.size = Vector2(CartLayout.DASH_LINE, layout.height)
		_deck_grid.add_child(separator)
	_fill_top_line(products, coupons, layout, width)


## The top line's labels: PRODUCTS (and the room left) after the chips, COUPONS over the coupons'
## group with the START legend left of it (at the line's right end without coupons).
func _fill_top_line(
	products: Array[DeckSummary.Group],
	coupons: Array[DeckSummary.Group],
	layout: CartLayout,
	width: float
) -> void:
	if not products.is_empty():
		_top_left.add_child(_plate("Heading", PRODUCTS % _copies(products), Palette.MUSTARD))
	if not _choosing and _deck_grid_family.is_empty():
		var full: bool = _run.deck_is_full()
		var room: int = _run.balance.deck_limit - _run.deck.size()
		var note: MixedLabel = MixedLabel.new(
			FULL_NOTE if full else ROOM_NOTE % room,
			NOTE_SIZE,
			false,
			Palette.TOMATO_LIGHT if full else Palette.MUSTARD_LIGHT
		)
		note.name = ROOM_NOTE_NAME
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_top_left.add_child(note)
	var legend_right: float = width - GRID_PAD
	if not coupons.is_empty():
		var plate: PanelContainer = _plate("Heading", COUPONS % _copies(coupons), Palette.MUSTARD)
		_top_line.add_child(plate)
		plate.position = Vector2(layout.coupon_x, 0)
		legend_right = layout.coupon_x - LEGEND_GAP
	if not _sources.is_empty():
		var legend: HBoxContainer = _legend()
		_top_line.add_child(legend)
		legend.set_anchors_preset(Control.PRESET_TOP_LEFT)
		legend.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		var wanted: Vector2 = legend.get_combined_minimum_size()
		legend.position = Vector2(legend_right - wanted.x, 0)
		legend.size = Vector2(wanted.x, TOP_LINE_HEIGHT)


## A shelf-edge label: `text` in ink on `fill` in an ink border, its count in the number font,
## centred down the top line.
func _plate(plate_name: String, text: String, fill: Color) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	plate.name = plate_name
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Palette.INK
	style.set_border_width_all(HEADING_BORDER)
	style.content_margin_left = HEADING_PADDING
	style.content_margin_right = HEADING_PADDING
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	plate.add_theme_stylebox_override("panel", style)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(MixedLabel.new(text, HEADING_SIZE, false, Palette.INK))
	plate.size = plate.get_combined_minimum_size()
	plate.position.y = roundf((TOP_LINE_HEIGHT - plate.size.y) / 2.0)
	return plate


static func _products_of(groups: Array[DeckSummary.Group]) -> int:
	return (
		groups.filter(func(group: DeckSummary.Group) -> bool: return group.card.is_product()).size()
	)


## One FamilyCount chip per printed tag of `cards` (most common first, DeckSummary.tag_counts);
## a tag with no family look shows as its word and count.
func _tag_chips(cards: Array[CardInstance]) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Tags"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", CHIP_GAP)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


## The START chip's legend: the chip and what it means.
func _legend() -> HBoxContainer:
	var legend: HBoxContainer = HBoxContainer.new()
	legend.name = "Legend"
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_info_grid = StockGrid.new(run, _line_width())
	for icon: StockIcon in _info_grid.icons():
		icon.hovered.connect(hover_stock)
		icon.unhovered.connect(
			func(left: StockIcon) -> void:
				if _hovered == left:
					_unhover()
		)
	_info_page.add_child(_info_grid)
	_info_grid_family = ""
	_info_page.add_child(_spacer_height(STOCK_GAP))


## A card for `card` with `copies` copies; its hover and clicks come to the view.
func _cell(card: CardInstance, copies: int) -> DeckCell:
	var family: String = FamilySticker.chosen(_run, card) if _run != null else ""
	var cell: DeckCell = DeckCell.new(card, _balance.machine, copies, family)
	cell.clicked.connect(_on_card_clicked)
	cell.hovered.connect(hover)
	cell.unhovered.connect(
		func(left: DeckCell) -> void:
			if _hovered == left:
				_unhover()
	)
	cell.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if _choosing else Control.CURSOR_ARROW
	)
	return cell


func _unhover() -> void:
	if _hovered != null and is_instance_valid(_hovered):
		var cell: DeckCell = _hovered as DeckCell
		if cell != null:
			cell.lifted = false
			cell.ringed = false
		var icon: StockIcon = _hovered as StockIcon
		if icon != null:
			icon.lit = false
	_hovered = null
	if _tip != null:
		_tip.visible = false
	_paint_mix()


## The mix highlight on every card of the Cart: `mix_family`'s, else the hovered card's matches,
## else none (and none in choosing mode).
func _paint_mix() -> void:
	if _deck_page == null:
		return
	var painted: Array[DeckCell] = []
	var entries: Array[MixModel.Entry] = []
	var focus: MixModel.Entry = null
	for cell: DeckCell in _cells_of(_deck_page):
		if cell.is_queued_for_deletion():
			continue
		var entry: MixModel.Entry = MixModel.Entry.new(cell.instance, cell.tags())
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


## Where the tip may open: the window, inside the screen holding the view.
func _stage() -> Rect2:
	var stage: Rect2 = get_viewport_rect()
	var holder: Control = get_parent() as Control
	return stage.intersection(holder.get_global_rect()) if holder != null else stage


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
		if node is DeckCell or node is StockIcon:
			return true
		node = node.get_parent()
	return false


static func _clear(page: Control) -> void:
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()


func _on_card_clicked(cell: DeckCell) -> void:
	if _choosing and not _placing.is_holding():
		_unhover()
		visible = false
		card_chosen.emit(cell.instance)


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
