class_name DeckView
extends PanelContainer
## The deck view (plan section 2, extended in full build phase 1), in the look of #56's deck view B
## (mock-up screens_deck_b.html): a teal hand basket (frames/basket_panel, its slotted foot and
## cart badge) holding shelves of tray items on steel price rails in its dark well. Its header
## holds the cart's title and the framed Cart, Run info and Close buttons (the shown page's tab
## sunk, disabled).
##
## The Cart page shows the deck as items, one cell (DeckCell) per distinct card with its copies
## stacked behind it and counted on a cream label, and how many copies carry each printed tag.
## Products fill the shelves from the top left; the coupons stand at the right end of the last
## shelf, at least one empty column after the products, so a 15-card cart (up to 15 distinct
## cards) fits on two shelves unscrolled. A BIG or GOLDEN copy shows its tier tag under its sticker
## (PriceSticker.tier_text), so a player never swaps one out unknowingly. The cart reveal's pick
## marks (v0.51) stay for the whole run, on each item's art: a dealt pick's product the teal "+"
## (the tomato token for the coupon). The staple padlock shows only on the cart reveal (#105).
## Marks go by product: a later copy of a marked product shares its mark, since copies carry no
## origin in the save; only a product that was not in the deal carries none. A legend beside the
## tag line names the marks. The tickets' family glyphs show their names below the ticket on
## hover (GlyphTips, mounted by the screen).
##
## The Run info page shows the owned upgrades (each with its LOYALTY stamp ring), this shift's and
## the next shift's inspections (a warning sign on an inspected one), and the run's stock: every
## item the RECEIPT REWARDS machine can offer, new arrivals with a NEW chip. Its shelves scroll.
##
## Hovering an item opens the scan popup (ScanPopup, as on the machine's prizes) beside it with
## its rule text in full. The mix highlight (#105 piece 3, MixModel; mock-up readability v3's Cart)
## paints every cell of both pages: the hovered item lights the cells it works with (a broad "next
## Food" match faint) and greys the rest, and `mix_family` (a family glyph's tooltip in the view,
## PlanningEffects.watch_glyphs) lights that family's cells instead. Off in choosing mode. In
## choosing mode (the machine's deck-full chooser, #77) only the Cart page shows, a hovered item
## gets a gold ring, and clicking it chooses one of its copies (to remove it from the deck); Close
## cancels the pick. It only displays RunState and DeckSummary.

signal closed
signal card_chosen(card: CardInstance)

const COLUMNS := 10
const GAP := 10.0
## Room on the right for the scroll bar.
const SCROLL_ROOM := 14.0
## The pages scroll inside this area, so the view fits the window at any deck or stock size. Two
## shelves with their heading bands and the tag line fit it unscrolled: any cart up to the deck
## limit (15 distinct cards at most).
const PAGE_SIZE := Vector2(COLUMNS * DeckCell.SIZE.x + (COLUMNS - 1) * GAP + SCROLL_ROOM, 480)
const PAGE_GAP := 6
## The Cart page always shows this many shelves (an empty rail is room left in the cart).
const MIN_SHELVES := 2
## The tag line's height (its legend chips included).
const TOP_LINE_HEIGHT := 22.0
## The basket's 9-slice margin (art pixels) and padding (left, top, right, bottom).
const BASKET := preload("res://art/frames/basket_panel.png")
const BASKET_MARGIN := 5
const BASKET_PADDING := Vector4(14, 14, 14, 6)
const WELL := preload("res://art/frames/basket_well.png")
const WELL_MARGIN := 3
const WELL_PADDING := Vector4(10, 8, 6, 8)
const SLOTS := preload("res://art/frames/basket_slots.png")
const CART_ICON := preload("res://art/icons/cart.png")
const WARNING := preload("res://art/icons/warning.png")
const FOOT_HEIGHT := 14.0
const BADGE_SIZE := Vector2(48, 24)
const HEADER_HEIGHT := 40.0
const TITLE_SIZE := 24
const BUTTON_SIZE := Vector2(112, 40)
const BUTTON_FONT := 18
const HEADING_SIZE := 18
const LINE_SIZE := 16
const UPGRADE_NAME_SIZE := 17
const UPGRADE_TEXT_SIZE := 15
const UPGRADE_TYPE_SIZE := 12
const UPGRADE_NAME_WEIGHT := 750
const ICON_TEXT_GAP := 8
const LEGEND_SIZE := 14
const LEGEND_CHIP := Vector2(18, 18)
const PICK_LEGEND := "start pick"
const COUPON_LEGEND := "start coupon"
const STOCK_HEADING := "STOCK  (every item the RECEIPT REWARDS machine can offer this run)"

## The family whose glyph's tooltip shows in the view (#105 piece 3), or "": its cells light.
var mix_family: String = "":
	set(value):
		if mix_family != value:
			mix_family = value
			_paint_mix()
## The mix highlight's grey (PlanningTuning's).
var tuning: PlanningTuning = load(PlanningEffects.TUNING_PATH) as PlanningTuning
var _title: MixedLabel
var _deck_tab: FramedButton
var _info_tab: FramedButton
var _close_button: FramedButton
var _scroll: ScrollContainer
var _deck_page: VBoxContainer
var _info_page: VBoxContainer
var _choosing: bool = false
## The run's starting deck, for the pick marks (null: no marks).
var _starter: DeckDefinition
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
	visible = false


## `choosing`: only the deck shows, and clicking an item chooses a copy of it (to remove it).
func open(run: RunState, title: String, choosing: bool) -> void:
	_choosing = choosing
	_title.set_text(title)
	_starter = run.starter
	_balance = run.balance
	_unhover()
	_fill_deck_page(run.deck.cards)
	_fill_info_page(run)
	_deck_tab.visible = not choosing
	_info_tab.visible = not choosing
	show_page(false)
	# The items fan out as the panel pops in (#62).
	Sfx.play_at(self, "fan")
	UiKit.pop_in(self)


## Shows the Run info tab, or the Cart tab.
func show_page(info: bool) -> void:
	_unhover()
	_deck_page.visible = not info
	_info_page.visible = info
	_deck_tab.disabled = not info
	_info_tab.disabled = info
	_scroll.scroll_vertical = 0


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
	cell.ringed = _choosing
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


func _fill_deck_page(cards: Array[CardInstance]) -> void:
	_clear(_deck_page)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.custom_minimum_size = Vector2(0, TOP_LINE_HEIGHT)
	_deck_page.add_child(top)
	var tags: PackedStringArray = PackedStringArray()
	var counts: Dictionary[String, int] = DeckSummary.tag_counts(cards)
	for tag: String in counts:
		tags.append("%s %d" % [tag, counts[tag]])
	var tag_text: String = "Tags: " + "  ·  ".join(tags) if not tags.is_empty() else ""
	var tag_line: Label = UiKit.body_label(tag_text, LINE_SIZE, Palette.PAPER)
	tag_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(tag_line)
	if _marks_shown():
		top.add_child(_legend())
	var products: Array[DeckSummary.Group] = []
	var coupons: Array[DeckSummary.Group] = []
	for group: DeckSummary.Group in DeckSummary.groups(cards):
		if group.card.is_product():
			products.append(group)
		else:
			coupons.append(group)
	var slots: Array[int] = shelf_slots(products.size(), coupons.size(), COLUMNS)
	var shelves: Array[DeckShelf] = []
	var last_slot: int = 0 if slots.is_empty() else slots[-1]
	for _shelf: int in range(maxi(MIN_SHELVES, floori(last_slot / float(COLUMNS)) + 1)):
		shelves.append(DeckShelf.new(COLUMNS, GAP, true))
		_deck_page.add_child(shelves[-1])
	var groups: Array[DeckSummary.Group] = products + coupons
	for index: int in groups.size():
		var slot: int = slots[index]
		var shelf: DeckShelf = shelves[floori(slot / float(COLUMNS))]
		if index == 0 and not products.is_empty():
			shelf.heading(_heading_text("PRODUCTS", products), 0)
		if index == products.size():
			shelf.heading(_heading_text("COUPONS", coupons), slot % COLUMNS)
		shelf.put(_deck_cell(groups[index]), slot % COLUMNS)


## The shelf slot (shelf * columns + column) of each of `products` products, then of `coupons`
## coupons: the products from the first slot on, the coupons at the end of the last shelf, with
## at least one empty slot between the two when there are both.
static func shelf_slots(products: int, coupons: int, columns: int) -> Array[int]:
	var gap: int = 1 if products > 0 and coupons > 0 else 0
	var shelves: int = maxi(1, ceili(float(products + gap + coupons) / columns))
	var slots: Array[int] = []
	for index: int in products:
		slots.append(index)
	for index: int in coupons:
		slots.append(shelves * columns - coupons + index)
	return slots


func _heading_text(heading: String, groups: Array[DeckSummary.Group]) -> String:
	var copies: int = 0
	for group: DeckSummary.Group in groups:
		copies += group.copies.size()
	return "%s  (%d)" % [heading, copies]


func _deck_cell(group: DeckSummary.Group) -> DeckCell:
	var cell: DeckCell = _cell(group.copies[0], group.copies.size())
	if _marks_shown():
		var card: CardDefinition = group.card
		cell.add_origin_marks(StartingDeck.picks(_starter).any(card.is_same_product))
	return cell


func _marks_shown() -> bool:
	return _starter != null and _starter.is_recipe()


## The marks' legend: each mark's chip and what it means.
func _legend() -> HBoxContainer:
	var legend: HBoxContainer = HBoxContainer.new()
	legend.name = "Legend"
	legend.add_theme_constant_override("separation", 6)
	var entries: Array[Array] = [
		[Palette.TEAL_BRIGHT, RevealTile.PICK_ICON, PICK_LEGEND],
		[Palette.TOMATO, RevealTile.COUPON_ICON, COUPON_LEGEND],
	]
	for index: int in entries.size():
		var entry: Array = entries[index]
		if index > 0:
			legend.add_child(_spacer(8))
		var chip: RevealChip = RevealChip.new(entry[0] as Color, LEGEND_CHIP, entry[1] as Texture2D)
		chip.custom_minimum_size = LEGEND_CHIP
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(chip)
		var text: Label = UiKit.body_label(entry[2] as String, LEGEND_SIZE, Palette.TEAL_PALE)
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		legend.add_child(text)
	return legend


func _fill_info_page(run: RunState) -> void:
	_clear(_info_page)
	_info_page.add_child(_heading("UPGRADES"))
	if run.upgrades.is_empty():
		_info_page.add_child(_line("None yet.", Palette.PAPER))
	for upgrade: UpgradeDefinition in run.upgrades:
		_info_page.add_child(_upgrade_row(upgrade))
	_info_page.add_child(_heading("INSPECTIONS"))
	for line: String in _inspection_lines(run):
		var row: HBoxContainer = _icon_row(not line.ends_with("no inspection."))
		row.add_child(_line(line, Palette.CREAM))
		_info_page.add_child(row)
	_info_page.add_child(_heading(STOCK_HEADING))
	var aisles: Array[AisleDefinition] = []
	for aisle: AisleDefinition in run.balance.aisles:
		if run.stock.aisle_ids.has(aisle.id):
			aisles.append(aisle)
	if not aisles.is_empty():
		_info_page.add_child(_aisle_line(aisles))
	var cards: Array[CardDefinition] = DeckSummary.in_view_order(run.stock.cards)
	var shelf: DeckShelf
	for index: int in cards.size():
		if index % COLUMNS == 0:
			shelf = DeckShelf.new(COLUMNS, GAP, false)
			_info_page.add_child(shelf)
		var cell: DeckCell = _cell(CardInstance.new(cards[index], 0), 1)
		if run.stock.new_arrivals.has(cards[index]):
			cell.add_new_mark()
		shelf.put(cell, index % COLUMNS)


## An owned upgrade: its LOYALTY stamp ring, its name and type, then its effect and condition.
func _upgrade_row(upgrade: UpgradeDefinition) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ring: PanelContainer = LoyaltyCard.make_ring(upgrade)
	ring.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ring)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_line: HBoxContainer = HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 10)
	text.add_child(name_line)
	var upgrade_name: Label = UiKit.body_label(
		LoyaltyCard.perk_name(upgrade), UPGRADE_NAME_SIZE, Palette.PAPER
	)
	upgrade_name.add_theme_font_override("font", ArtStyle.bold_font(UPGRADE_NAME_WEIGHT))
	name_line.add_child(upgrade_name)
	# Its type in capitals, as the machine's LOYALTY prize prints it.
	var kind_label: Label = UiKit.body_label(
		upgrade.type_label().to_upper(), UPGRADE_TYPE_SIZE, Palette.TEAL_LIGHT
	)
	kind_label.add_theme_font_override("font", ArtStyle.bold_font(UPGRADE_NAME_WEIGHT))
	kind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kind_label.size_flags_vertical = Control.SIZE_FILL
	name_line.add_child(kind_label)
	var rule: String = upgrade.effect_text
	if not upgrade.condition_text.is_empty():
		rule += "  ·  " + upgrade.condition_text
	var rule_line: Label = UiKit.body_label(rule, UPGRADE_TEXT_SIZE, Palette.TEAL_PALE)
	rule_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_line.custom_minimum_size = Vector2(_line_width() - LoyaltyCard.CHIP_BOX_SIZE.x - 10.0, 0)
	text.add_child(rule_line)
	return row


## The stocked aisles, each with its glyph.
func _aisle_line(aisles: Array[AisleDefinition]) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UiKit.body_label("Aisles:", LINE_SIZE, Palette.PAPER))
	for index: int in aisles.size():
		var glyph: TextureRect = UiKit.sprite(load(ArtStyle.glyph_path(aisles[index])) as Texture2D)
		glyph.custom_minimum_size = Vector2.ONE * ArtStyle.FAMILY_GLYPH_SIZE
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
		var comma: String = "," if index < aisles.size() - 1 else ""
		row.add_child(UiKit.body_label(aisles[index].display_name + comma, LINE_SIZE))
	return row


## A row led by the warning sign (`warned`), or by the same room left empty.
func _icon_row(warned: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ICON_TEXT_GAP)
	var icon: TextureRect = UiKit.sprite(WARNING)
	icon.name = "Warning"
	icon.custom_minimum_size = WARNING.get_size() * ArtStyle.ART_SCALE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.self_modulate.a = 1.0 if warned else 0.0
	row.add_child(icon)
	return row


## While planning: this shift's inspections. After a checkout,
## run.inspections still holds the shift just played, so only the next shift shows. The next
## shift's inspection is drawn at the previous passed checkout: before that, a scheduled one is
## announced as coming. The last shift has no next shift.
static func _inspection_lines(run: RunState) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if run.phase == RunState.Phase.PLANNING:
		lines.append(_inspection_line("This shift", run.inspections))
	var next_shift: int = run.shift_index + 2
	if run.next_inspection != null:
		lines.append(_inspection_line("Next shift", [run.next_inspection]))
	elif InspectionSchedule.is_inspection_shift(run.balance, next_shift):
		lines.append("Next shift: inspected (announced at checkout).")
	elif next_shift <= run.shift_count():
		lines.append(_inspection_line("Next shift", []))
	return lines


static func _inspection_line(when: String, inspections: Array[InspectionDefinition]) -> String:
	if inspections.is_empty():
		return "%s: no inspection." % when
	var notices: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		notices.append("%s, %s" % [inspection.display_name, inspection.notice_text])
	return "%s: %s" % [when, "  ·  ".join(notices)]


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


func _heading(text: String) -> MixedLabel:
	return MixedLabel.new(text, HEADING_SIZE, false, Palette.MUSTARD)


func _line(text: String, color: Color) -> Label:
	var label: Label = UiKit.body_label(text, LINE_SIZE, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wrapped lines are measured at the page's width from the start (less a sign's room).
	label.custom_minimum_size = Vector2(_line_width() - 40.0, 0)
	return label


static func _line_width() -> float:
	return PAGE_SIZE.x - SCROLL_ROOM


static func _spacer(width: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(width, 0)
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
	if _choosing:
		_unhover()
		visible = false
		card_chosen.emit(view.card)


func _close() -> void:
	_unhover()
	visible = false
	closed.emit()
