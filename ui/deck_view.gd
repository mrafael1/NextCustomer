class_name DeckView
extends PanelContainer
## Shows every card in the deck (plan section 2: deck view). In choosing mode it is also how
## the player picks the card to remove when the deck is at its limit.

signal closed
signal card_chosen(card: CardInstance)

var _title: Label
var _grid: GridContainer
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
	column.add_child(header)
	_title = UiKit.label("", 22, Palette.LIGHT_TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	UiKit.button(header, "Close", func() -> void: _close(), 16)
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(_grid)
	visible = false


## `choosing`: clicking a card chooses it (to remove it from the deck).
func open(cards: Array[CardInstance], title: String, choosing: bool) -> void:
	_choosing = choosing
	_title.text = title
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var sorted: Array[CardInstance] = cards.duplicate()
	sorted.sort_custom(
		func(a: CardInstance, b: CardInstance) -> bool:
			return a.definition.display_name < b.definition.display_name
	)
	for card: CardInstance in sorted:
		var view: CardView = CardView.new(card)
		view.clicked.connect(_on_card_clicked)
		if not choosing:
			view.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_grid.add_child(view)
	UiKit.pop_in(self)


func _on_card_clicked(view: CardView) -> void:
	if _choosing:
		visible = false
		card_chosen.emit(view.card)


func _close() -> void:
	visible = false
	closed.emit()
