class_name RewardPanel
extends PanelContainer
## The reward choice after a passed shift (plan section 2): pick 1 of the offered cards for
## the deck, or skip. It only shows the offer and reports the choice; RunState applies it.

signal picked(card: CardDefinition)
signal skipped
signal deck_requested

var _headline: Label
var _note: Label
var _cards: HBoxContainer
var _deck_button: Button
var _skip_button: Button
## The panel only reacts once the mouse has been released after it appeared, so clicks meant
## to speed up the count-up never pick a card the player didn't see.
var _armed: bool = false
var _shown_ms: int = 0


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_headline = UiKit.label("", 28, Palette.INK)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_headline)
	_note = UiKit.label("Pick a card for your deck, or skip.", 16, Palette.MUTED_INK)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 22)
	_cards.custom_minimum_size = Vector2(0, CardView.CARD_SIZE.y + 20)
	column.add_child(_cards)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_skip_button = UiKit.button(buttons, "Skip", func() -> void: skipped.emit(), 18)
	_deck_button = UiKit.button(buttons, "", func() -> void: deck_requested.emit(), 18)
	visible = false


func _process(_delta: float) -> void:
	if not visible or _armed:
		return
	var waited: bool = Time.get_ticks_msec() - _shown_ms >= 350
	if waited and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_armed(true)


func _set_armed(armed: bool) -> void:
	_armed = armed
	_skip_button.disabled = not armed
	_deck_button.disabled = not armed


func show_offer(
	offer: Array[CardDefinition], headline: String, deck_size: int, deck_limit: int
) -> void:
	_headline.text = headline
	var full: bool = deck_size >= deck_limit
	_note.text = (
		"Your deck is full: picking a card means removing one."
		if full
		else "Pick a card for your deck, or skip."
	)
	_deck_button.text = "View deck (%d/%d)" % [deck_size, deck_limit]
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for card: CardDefinition in offer:
		var view: CardView = CardView.new(CardInstance.new(card, 0))
		view.clicked.connect(_on_card_clicked)
		_cards.add_child(view)
	_shown_ms = Time.get_ticks_msec()
	_set_armed(false)
	UiKit.pop_in(self)


func _on_card_clicked(view: CardView) -> void:
	if _armed:
		picked.emit(view.card.definition)
