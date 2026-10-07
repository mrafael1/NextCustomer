class_name DeckView
extends PanelContainer
## The deck view (plan section 2, extended in full build phase 1). The Deck tab shows the deck
## as products and coupons, one card per distinct card with its number of copies, and how many
## copies carry each printed tag. The Run info tab shows the owned upgrades, this shift's and
## the next shift's inspections, and the run's stock: every card a reward or the impulse rack
## can offer. In choosing mode it shows only the deck, and clicking a card chooses one of its
## copies (to remove it from the deck). It only displays RunState and DeckSummary.

signal closed
signal card_chosen(card: CardInstance)

const COLUMNS := 8
const GAP := 8
## The pages scroll inside this area, so the view fits the window at any deck or stock size.
## It holds a starting deck's page (tags, two headings, a product row, a coupon row) unscrolled.
const PAGE_SIZE := Vector2(COLUMNS * CardView.CARD_SIZE.x + (COLUMNS - 1) * GAP + 16, 500)

var _title: Label
var _deck_tab: Button
var _info_tab: Button
var _scroll: ScrollContainer
var _deck_page: VBoxContainer
var _info_page: VBoxContainer
var _choosing: bool = false


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.CREAM
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	_title = UiKit.label("", 22, Palette.LIGHT_TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_deck_tab = UiKit.button(header, "Deck", func() -> void: show_page(false), 16)
	_info_tab = UiKit.button(header, "Run info", func() -> void: show_page(true), 16)
	UiKit.button(header, "Close", func() -> void: _close(), 16)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = PAGE_SIZE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	var pages: VBoxContainer = VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)
	_deck_page = _page(pages)
	_info_page = _page(pages)
	visible = false


## `choosing`: only the deck shows, and clicking a card chooses a copy of it (to remove it).
func open(run: RunState, title: String, choosing: bool) -> void:
	_choosing = choosing
	_title.text = title
	_fill_deck_page(run.deck.cards)
	_fill_info_page(run)
	_deck_tab.visible = not choosing
	_info_tab.visible = not choosing
	show_page(false)
	UiKit.pop_in(self)


## Shows the Run info tab, or the Deck tab.
func show_page(info: bool) -> void:
	_deck_page.visible = not info
	_info_page.visible = info
	_deck_tab.disabled = not info
	_info_tab.disabled = info
	_scroll.scroll_vertical = 0


## The labels' texts on the shown page, in order (for tests).
func texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var page: Control = _info_page if _info_page.visible else _deck_page
	for label: Label in page.find_children("*", "Label", true, false):
		if not _is_on_card(label) and not label.text.is_empty():
			found.append(label.text)
	return found


## The card views on the shown page, in order (for tests).
func card_views() -> Array[CardView]:
	var found: Array[CardView] = []
	var page: Control = _info_page if _info_page.visible else _deck_page
	for view: Node in page.find_children("*", "CardView", true, false):
		found.append(view as CardView)
	return found


func _fill_deck_page(cards: Array[CardInstance]) -> void:
	_clear(_deck_page)
	var tags: PackedStringArray = PackedStringArray()
	var counts: Dictionary[String, int] = DeckSummary.tag_counts(cards)
	for tag: String in counts:
		tags.append("%s %d" % [tag, counts[tag]])
	if not tags.is_empty():
		_deck_page.add_child(_line("Tags: " + "  ·  ".join(tags), 16, Palette.LIGHT_TEXT))
	var products: Array[DeckSummary.Group] = []
	var coupons: Array[DeckSummary.Group] = []
	for group: DeckSummary.Group in DeckSummary.groups(cards):
		if group.card.is_product():
			products.append(group)
		else:
			coupons.append(group)
	_add_section("PRODUCTS", products)
	_add_section("COUPONS", coupons)


## A heading with the number of copies, then one card per group with its count of copies.
func _add_section(heading: String, groups: Array[DeckSummary.Group]) -> void:
	if groups.is_empty():
		return
	var copies: int = 0
	for group: DeckSummary.Group in groups:
		copies += group.copies.size()
	_deck_page.add_child(_line("%s  (%d)" % [heading, copies], 16, Palette.MUSTARD))
	var grid: GridContainer = _grid(_deck_page)
	for group: DeckSummary.Group in groups:
		var count: String = "×%d" % group.copies.size() if group.copies.size() > 1 else ""
		grid.add_child(_cell(group.copies[0], count))


func _fill_info_page(run: RunState) -> void:
	_clear(_info_page)
	_info_page.add_child(_line("UPGRADES", 16, Palette.MUSTARD))
	if run.upgrades.is_empty():
		_info_page.add_child(_line("None yet.", 16, Palette.LIGHT_TEXT))
	for upgrade: UpgradeDefinition in run.upgrades:
		var line: String = (
			"%s (%s): %s" % [upgrade.display_name, upgrade.type_label(), upgrade.effect_text]
		)
		if not upgrade.condition_text.is_empty():
			line += "  ·  " + upgrade.condition_text
		_info_page.add_child(_line(line, 16, Palette.LIGHT_TEXT))
	_info_page.add_child(_line("INSPECTIONS", 16, Palette.MUSTARD))
	for line: String in _inspection_lines(run):
		_info_page.add_child(_line(line, 16, Palette.CREAM))
	var heading: String = "STOCK  (every card a reward or the impulse rack can offer this run)"
	_info_page.add_child(_line(heading, 16, Palette.MUSTARD))
	var aisles: PackedStringArray = PackedStringArray()
	for aisle: AisleDefinition in run.balance.aisles:
		if run.stock.aisle_ids.has(aisle.id):
			aisles.append(aisle.display_name)
	if not aisles.is_empty():
		_info_page.add_child(_line("Aisles: " + ", ".join(aisles), 16, Palette.LIGHT_TEXT))
	var grid: GridContainer = _grid(_info_page)
	for card: CardDefinition in DeckSummary.in_view_order(run.stock.cards):
		var note: String = "NEW" if run.stock.new_arrivals.has(card) else ""
		grid.add_child(_cell(CardInstance.new(card, 0), note))


## While planning (or at the impulse rack): this shift's inspections. After a checkout,
## run.inspections still holds the shift just played, so only the next shift shows. The next
## shift's inspection is drawn at the previous passed checkout: before that, a scheduled one is
## announced as coming. The last shift has no next shift.
static func _inspection_lines(run: RunState) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var planning: bool = run.phase == RunState.Phase.PLANNING or run.phase == RunState.Phase.IMPULSE
	if planning:
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


## A card with a short line under it (a count of copies, or NEW).
func _cell(card: CardInstance, note: String) -> VBoxContainer:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	var view: CardView = CardView.new(card)
	view.clicked.connect(_on_card_clicked)
	if not _choosing:
		view.mouse_default_cursor_shape = Control.CURSOR_ARROW
	cell.add_child(view)
	var label: Label = UiKit.label(note, 16, Palette.CREAM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 20)
	cell.add_child(label)
	return cell


func _line(text: String, font_size: int, color: Color) -> Label:
	var label: Label = UiKit.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wrapped lines are measured at the page's width from the start.
	label.custom_minimum_size = Vector2(PAGE_SIZE.x - 20, 0)
	return label


func _grid(parent: Control) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	parent.add_child(grid)
	return grid


func _page(parent: Control) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	parent.add_child(page)
	return page


func _is_on_card(label: Label) -> bool:
	var node: Node = label.get_parent()
	while node != null and node != self:
		if node is CardView:
			return true
		node = node.get_parent()
	return false


static func _clear(page: Control) -> void:
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()


func _on_card_clicked(view: CardView) -> void:
	if _choosing:
		visible = false
		card_chosen.emit(view.card)


func _close() -> void:
	visible = false
	closed.emit()
