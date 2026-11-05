class_name RegularSwapStrip
extends Panel
## Replacing a regular (full build plan 7.2, "middle ground"): the small strip of one aisle's
## offered items for the carried regular (2 to 4, data order; an item the slot can't take is
## muted with its reason), then the preview of the replacement with CONFIRM and CANCEL. Also the
## RESTORE preview of a replaced regular. StartBoard places it and acts on its signals.

signal chosen(card: CardDefinition)
signal confirmed
signal cancelled

## A strip item's width and height, the gap between items, and the preview's width.
const ITEM := Vector2(100, 150)
const GAP := 8.0
const PREVIEW_WIDTH := 480.0
const STRIP_HEIGHT := 230.0
const PREVIEW_HEIGHT := 236.0
## The preview's rule card: its tallest height and its text size.
const RULE_BAND := 104.0
const RULE_FONT_SIZE := 13

## The strip's item buttons in offer order (empty in the preview), and their cards.
var items: Array[Button] = []
var offer: Array[CardDefinition] = []
var confirm_key: Button
var cancel_key: Button
var title: Label
## Whether the preview (not the strip) shows.
var previewing: bool = false


func _init() -> void:
	name = "SwapStrip"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.MUSTARD
	style.set_border_width_all(4)
	style.shadow_color = Color(Palette.INK, 0.5)
	style.shadow_size = 6
	style.shadow_offset = Vector2(3, 3)
	add_theme_stylebox_override("panel", style)


## The strip: `regular` (slot `slot`) and `cards`, the aisle's offer; `reasons[i]` is cards[i]'s
## swap_block reason (&"" when it can be taken).
func show_strip(
	run: RunState,
	regular: CardDefinition,
	aisle: AisleDefinition,
	cards: Array[CardDefinition],
	reasons: Array[StringName]
) -> void:
	_reset()
	offer = cards.duplicate()
	size = Vector2(maxf(24 + cards.size() * (ITEM.x + GAP) - GAP + 24, 360), STRIP_HEIGHT)
	title = StartBoardKit.tag(
		self, "REPLACE %s" % regular.display_name.to_upper(), Rect2(16, 10, size.x - 32, 28)
	)
	title.name = "Title"
	var line: Label = StartBoardKit.body(
		self,
		"with an item from %s" % aisle.display_name,
		Rect2(16, 38, size.x - 32, 20),
		Palette.INK_LIGHT,
		13
	)
	line.name = "Subtitle"
	line.add_theme_font_override("font", ArtStyle.bold_font(700))
	var left: float = floorf((size.x - (cards.size() * (ITEM.x + GAP) - GAP)) / 2.0)
	for at: int in cards.size():
		var card: CardDefinition = cards[at]
		var reason: StringName = reasons[at]
		var button: Button = Button.new()
		button.name = "Item%d" % at
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(left + at * (ITEM.x + GAP), 64)
		button.size = ITEM
		button.disabled = reason != &""
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		)
		button.tooltip_text = "%s · %d€\n%s" % [card.display_name, card.base, card.rule_text]
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var face: StyleBoxFlat = StyleBoxFlat.new()
			face.bg_color = Palette.MUSTARD_PALE if state == "hover" else Palette.CREAM
			if state == "disabled":
				face.bg_color = Palette.CREAM_SHADE
			face.border_color = Palette.MUSTARD if state == "hover" else Palette.INK
			face.set_border_width_all(2)
			face.border_width_bottom = 4
			button.add_theme_stylebox_override(state, face)
		button.pressed.connect(func() -> void: chosen.emit(card))
		add_child(button)
		items.append(button)
		var art: Control = StartBoardKit.item(button, card, Vector2(14, 4), 72)
		art.modulate = Color(1, 1, 1, 0.45) if button.disabled else Color.WHITE
		var key: Panel = StartBoardKit.panel(button, Rect2(4, 4, 20, 20), Palette.PAPER)
		var digit: Label = StartBoardKit.number(
			key, str(at + 1), Rect2(0, -3, 20, 20), Palette.INK, 18
		)
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var item_name: Label = StartBoardKit.body(
			button,
			card.display_name,
			Rect2(4, 78, ITEM.x - 8, 20),
			Palette.GREY_DARK if button.disabled else Palette.INK,
			13
		)
		item_name.name = "Name"
		item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name.add_theme_font_override("font", ArtStyle.bold_font(700))
		var price: Label = StartBoardKit.number(
			button, "%d€" % card.base, Rect2(4, 96, ITEM.x - 8, 26), Palette.INK, 22
		)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if button.disabled:
			var why: Label = StartBoardKit.body(
				button,
				StartReasons.swap_word(run, reason),
				Rect2(2, 122, ITEM.x - 4, 22),
				Palette.TOMATO_DARK,
				11
			)
			why.name = "Reason"
			why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			why.add_theme_font_override("font", ArtStyle.bold_font(700))
	cancel_key = null
	confirm_key = null


## The preview: regular `from` becoming `to`; `restore` names it a PUT BACK.
func show_preview(from: CardDefinition, to: CardDefinition, restore: bool) -> void:
	_reset()
	previewing = true
	size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	title = StartBoardKit.tag(
		self,
		"PUT BACK %s?" % to.display_name.to_upper() if restore else "REPLACE THIS REGULAR?",
		Rect2(16, 10, size.x - 32, 28)
	)
	title.name = "Title"
	for side: int in 2:
		var card: CardDefinition = from if side == 0 else to
		var x: float = 24.0 if side == 0 else 184.0
		var art: Control = StartBoardKit.item(self, card, Vector2(x, 44), 64)
		art.name = "From" if side == 0 else "To"
		var item_name: Label = StartBoardKit.body(
			self, card.display_name, Rect2(x - 18, 110, 100, 20), Palette.INK, 13
		)
		item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name.add_theme_font_override("font", ArtStyle.bold_font(700))
		var price: Label = StartBoardKit.number(
			self, "%d€" % card.base, Rect2(x - 18, 128, 100, 24), Palette.INK, 22
		)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StartBoardKit.tag(self, "›", Rect2(112, 60, 56, 40), Palette.MUSTARD_DARK, 4, true)
	# The rule card fits its wrapped text (at most RULE_BAND tall), centred beside the items.
	var rule_text: String = to.rule_text if to.rule_text != "" else "No rule: just its price"
	var box_width: float = size.x - 296
	var text_height: float = (
		ArtStyle
		. BODY_FONT
		. get_multiline_string_size(
			rule_text, HORIZONTAL_ALIGNMENT_LEFT, box_width - 20, RULE_FONT_SIZE
		)
		. y
	)
	var box_height: float = clampf(ceilf(text_height) + 36, 52, RULE_BAND)
	var card_box: Panel = StartBoardKit.panel(
		self,
		Rect2(280, 46 + floorf((RULE_BAND - box_height) / 4.0) * 2, box_width, box_height),
		Palette.CREAM,
		Palette.MUSTARD
	)
	card_box.name = "RuleCard"
	var heading: Label = StartBoardKit.body(
		card_box,
		to.display_name.to_upper(),
		Rect2(10, 6, card_box.size.x - 20, 18),
		Palette.INK,
		12
	)
	heading.add_theme_font_override("font", ArtStyle.bold_font(700))
	var rule: Label = StartBoardKit.body(
		card_box,
		rule_text,
		Rect2(10, 26, card_box.size.x - 20, card_box.size.y - 32),
		Palette.INK,
		RULE_FONT_SIZE
	)
	rule.name = "Rule"
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var note: Label = StartBoardKit.body(
		self,
		"Saved for your next runs · the baskets are not re-dealt",
		Rect2(16, 156, size.x - 32, 18),
		Palette.INK_LIGHT,
		12
	)
	note.name = "Note"
	cancel_key = StartBoardKit.key(
		self, "CANCEL", Rect2(16, size.y - 58, 150, 44), func() -> void: cancelled.emit()
	)
	cancel_key.name = "Cancel"
	confirm_key = StartBoardKit.key(
		self,
		"PUT BACK" if restore else "CONFIRM",
		Rect2(size.x - 16 - 200, size.y - 58, 200, 44),
		func() -> void: confirmed.emit()
	)
	confirm_key.name = "Confirm"
	StartBoardKit.restyle(confirm_key, Palette.TOMATO, Palette.INK)


## Item `at` of the strip (a 1–4 key), when it can be taken.
func choose(at: int) -> void:
	if at >= 0 and at < items.size() and not items[at].disabled:
		chosen.emit(offer[at])


func _reset() -> void:
	StartBoardKit.clear(self)
	items.clear()
	previewing = false
