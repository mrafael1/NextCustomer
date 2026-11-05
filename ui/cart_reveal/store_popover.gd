class_name StorePopover
extends Panel
## The YOUR STORE page's two small pop-ups (page 1 "Counter", v1.07; mock-up start_store_v6.html,
## direction A). StartBoard places it and acts on its signals.
## - The swap shelf (show_swap): "SWAP <REGULAR> FOR…", one tab per completed aisle (a tab the
##   slot can't take from is muted with its reason in its tip), up to regular_offer_max items of
##   the open tab's offer (an item the slot can't take is muted with its reason), a put-back tab
##   on a swapped regular, and a rule line that reads the hovered item's rule. A click on an item
##   swaps at once (no confirm; the tile's put-back tag undoes it); 1–4 pick an item.
## - The aisle choice (show_aisles): "BASKET n: CHANGE <AISLE> FOR…" and one sign per other
##   completed aisle; a click deals that basket again from it.

signal tab_chosen(aisle_id: StringName)
signal chosen(card: CardDefinition)
signal restore_chosen
signal aisle_chosen(aisle_id: StringName)
signal closed

## The swap shelf's width, an offer's size and the gap between offers, and the aisle pop-up's
## width.
const SWAP_WIDTH := 432.0
const OFFER := Vector2(92, 124)
const OFFER_GAP := 10.0
const AISLE_WIDTH := 420.0
const RULE_FONT_SIZE := 14

## The open tab's aisle (swap shelf), the tab buttons by aisle id, the offer buttons in offer
## order and their cards, and the rule line.
var aisle: StringName = &""
var tabs: Dictionary[StringName, Button] = {}
var offers: Array[Button] = []
var offer_cards: Array[CardDefinition] = []
var restore_key: Button
var rule_line: Label
var close_key: Button
## The aisle pop-up's sign buttons, by aisle id.
var options: Dictionary[StringName, Button] = {}
var _regular: CardDefinition


func _init() -> void:
	name = "StorePopover"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(3)
	style.border_width_bottom = 6
	style.shadow_color = Color(Palette.INK, 0.4)
	style.shadow_size = 0
	style.shadow_offset = Vector2(0, 6)
	add_theme_stylebox_override("panel", style)


## The swap shelf for `regular` (now in its slot; `original` its recipe card): `aisles` the
## completed aisles with `blocks[i]` aisles[i]'s target_block reason (&"" open), the open tab
## `open` with its offer `cards` and `reasons[i]` cards[i]'s swap_block reason.
func show_swap(
	run: RunState,
	regular: CardDefinition,
	original: CardDefinition,
	aisles: Array[AisleDefinition],
	blocks: Array[StringName],
	open: StringName,
	cards: Array[CardDefinition],
	reasons: Array[StringName]
) -> void:
	_reset()
	_regular = regular
	aisle = open
	var y: float = _header("SWAP %s FOR..." % regular.display_name.to_upper(), SWAP_WIDTH, regular)
	var x: float = 14
	for index: int in aisles.size():
		var shown: AisleDefinition = aisles[index]
		var width: float = StartBoardKit.text_width(shown.display_name) + 40
		if x + width > SWAP_WIDTH - 14:
			x = 14
			y += 34
		var tab: Button = _aisle_key(shown, Rect2(x, y, width, 28))
		tab.name = "Tab_%s" % shown.id
		tab.disabled = blocks[index] != &""
		tab.tooltip_text = (
			StartReasons.target(run, blocks[index]) if tab.disabled else shown.display_name
		)
		if shown.id == open:
			var style: StyleBoxFlat = tab.get_theme_stylebox("normal") as StyleBoxFlat
			for state: String in ["normal", "hover", "pressed"]:
				var lit: StyleBoxFlat = style.duplicate()
				lit.border_color = Palette.MUSTARD
				lit.set_border_width_all(3)
				tab.add_theme_stylebox_override(state, lit)
		else:
			tab.modulate = Color(1, 1, 1, 0.45 if tab.disabled else 0.8)
		tab.pressed.connect(func() -> void: tab_chosen.emit(shown.id))
		tabs[shown.id] = tab
		x += width + 8
	if regular != original:
		var width: float = StartBoardKit.text_width("BACK TO") + 46
		if x + width > SWAP_WIDTH - 14:
			x = 14
			y += 34
		restore_key = StartBoardKit.key(
			self, "BACK TO", Rect2(x, y, width, 28), func() -> void: restore_chosen.emit()
		)
		restore_key.name = "Restore"
		restore_key.tooltip_text = "Put %s back" % original.display_name
		StartBoardKit.restyle(restore_key, Palette.CREAM, Palette.INK, 2)
		var caption: Label = StartBoardKit.key_caption(restore_key)
		caption.add_theme_color_override("font_color", Palette.INK)
		UiKit.place_pixel_label(caption, Rect2(8, 0, width - 40, 24), true)
		var small: Control = StartBoardKit.item(restore_key, original, Vector2(width - 30, 2), 22)
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		small.remove_meta("card")
	y += 40
	var left: float = 14
	for at: int in cards.size():
		_offer(run, cards[at], reasons[at], Rect2(Vector2(left, y), OFFER), at)
		left += OFFER.x + OFFER_GAP
	if cards.is_empty():
		var none: Label = StartBoardKit.body(
			self, "Nothing here for this regular.", Rect2(14, y, 300, 22), Palette.INK_LIGHT, 14
		)
		none.name = "None"
	y += OFFER.y + 10
	var dash: Control = Control.new()
	dash.name = "Dash"
	dash.position = Vector2(14, y)
	dash.size = Vector2(SWAP_WIDTH - 28, 3)
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash.draw.connect(
		func() -> void:
			for dx: int in range(0, int(dash.size.x), 10):
				dash.draw_rect(Rect2(dx, 0, 6, 3), Palette.CREAM_DARKEST)
	)
	add_child(dash)
	rule_line = StartBoardKit.body(
		self, "", Rect2(14, y + 8, SWAP_WIDTH - 28, 40), Palette.INK_LIGHT, RULE_FONT_SIZE
	)
	rule_line.name = "Rule"
	rule_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_line.clip_text = false
	rule_line.add_theme_font_override("font", ArtStyle.bold_font(700))
	show_rule(null)
	size = Vector2(SWAP_WIDTH, y + 58)


## The aisle pop-up for green basket `basket` holding `current`: one sign per aisle of `choices`;
## `extra_name` names today's extra aisle in the note.
func show_aisles(
	basket: int, current: AisleDefinition, choices: Array[AisleDefinition], extra_name: String
) -> void:
	_reset()
	var title: String = (
		"BASKET %d: CHANGE %s FOR..." % [basket + 1, current.display_name.to_upper()]
	)
	var y: float = _header(title, AISLE_WIDTH, null, StartBoardKit.glyph(current))
	var x: float = 14
	for choice: AisleDefinition in choices:
		var width: float = StartBoardKit.text_width(choice.display_name) + 52
		if x + width > AISLE_WIDTH - 14:
			x = 14
			y += 50
		var key: Button = _aisle_key(choice, Rect2(x, y, width, 42))
		key.name = "Aisle_%s" % choice.id
		key.tooltip_text = "Deal basket %d from %s" % [basket + 1, choice.display_name]
		key.pressed.connect(func() -> void: aisle_chosen.emit(choice.id))
		options[choice.id] = key
		x += width + 10
	y += 52
	var note: Label = (
		StartBoardKit
		. body(
			self,
			(
				"The basket is dealt again from the new aisle. Staples and today's extra aisle (%s) stay."
				% extra_name
			),
			Rect2(14, y, AISLE_WIDTH - 28, 40),
			Palette.INK_LIGHT,
			13
		)
	)
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.clip_text = false
	note.add_theme_font_override("font", ArtStyle.bold_font(700))
	size = Vector2(AISLE_WIDTH, y + 48)


## The rule line: `card`'s price and rule (hovered), else the regular's own rule.
func show_rule(card: CardDefinition) -> void:
	if rule_line == null:
		return
	var shown: CardDefinition = card if card != null else _regular
	if shown == null:
		return
	var rule: String = shown.rule_text if shown.rule_text != "" else "No rule: just its price"
	rule_line.text = (
		"%s · %d€: %s" % [shown.display_name, shown.base, rule]
		if card != null
		else "%s now: %s" % [shown.display_name, rule]
	)


## Offer `at` (a 1–4 key), when the slot can take it.
func choose(at: int) -> void:
	var card: CardDefinition = card_at(at)
	if card != null:
		chosen.emit(card)


## Offer `at`'s card when the slot can take it, else null.
func card_at(at: int) -> CardDefinition:
	if at >= 0 and at < offers.size() and not offers[at].disabled:
		return offer_cards[at]
	return null


func _header(title: String, width: float, card: CardDefinition, glyph: Texture2D = null) -> float:
	var left: float = 14
	if card != null:
		var art: Control = StartBoardKit.item(self, card, Vector2(12, 8), 32)
		art.remove_meta("card")
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left = 50
	elif glyph != null:
		StartBoardKit.icon(self, glyph, Vector2(14, 15))
		left = 40
	var heading: Label = StartBoardKit.tag(
		self, title, Rect2(left, 8, width - left - 52, 32), Palette.INK
	)
	heading.name = "Title"
	UiKit.place_pixel_label(heading, Rect2(left, 8, width - left - 52, 32), true)
	close_key = StartBoardKit.key(
		self, "", Rect2(width - 42, 8, 30, 30), func() -> void: closed.emit()
	)
	close_key.name = "Close"
	close_key.tooltip_text = "Close (Esc)"
	StartBoardKit.restyle(close_key, Palette.CREAM, Palette.INK, 2)
	var cross: Control = Control.new()
	cross.name = "Cross"
	cross.size = Vector2(30, 26)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(
		func() -> void:
			for step: int in 6:
				cross.draw_rect(Rect2(9 + step * 2, 7 + step * 2, 2, 2), Palette.INK)
				cross.draw_rect(Rect2(19 - step * 2, 7 + step * 2, 2, 2), Palette.INK)
	)
	close_key.add_child(cross)
	return 46.0


## A key in aisle `shown`'s sign colour with its glyph and name.
func _aisle_key(shown: AisleDefinition, rect: Rect2) -> Button:
	var key: Button = StartBoardKit.key(self, "", rect, func() -> void: pass)
	var face: Color = shown.sign_color
	var ink: Color = Palette.INK if face.get_luminance() > 0.55 else Palette.PAPER
	StartBoardKit.restyle(key, face, Palette.INK, 2)
	var glyph_top: float = floorf(rect.size.y / 4.0) * 2 - 11
	StartBoardKit.icon(key, StartBoardKit.glyph(shown), Vector2(8, glyph_top))
	var caption: Label = StartBoardKit.key_caption(key)
	caption.text = shown.display_name
	caption.add_theme_color_override("font_color", ink)
	UiKit.place_pixel_label(caption, Rect2(32, 0, rect.size.x - 36, rect.size.y - 4), true)
	return key


func _offer(run: RunState, card: CardDefinition, reason: StringName, rect: Rect2, at: int) -> void:
	var button: Button = Button.new()
	button.name = "Offer%d" % at
	button.focus_mode = Control.FOCUS_NONE
	button.position = rect.position
	button.size = rect.size
	button.disabled = reason != &""
	button.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face: StyleBoxFlat = StyleBoxFlat.new()
		face.bg_color = Palette.PAPER if state == "hover" else Palette.CREAM
		if state == "disabled":
			face.bg_color = Palette.CREAM_SHADE
		face.border_color = Palette.GOLD if state == "hover" else Palette.INK
		face.set_border_width_all(3 if state == "hover" else 2)
		face.border_width_bottom = 5
		button.add_theme_stylebox_override(state, face)
	button.pressed.connect(func() -> void: chosen.emit(card))
	button.mouse_entered.connect(
		func() -> void:
			show_rule(card)
			if not button.disabled:
				button.position.y = rect.position.y - 4
	)
	button.mouse_exited.connect(
		func() -> void:
			show_rule(null)
			button.position.y = rect.position.y
	)
	add_child(button)
	offers.append(button)
	offer_cards.append(card)
	var art: Control = StartBoardKit.item(button, card, Vector2(14, 4), 64)
	art.remove_meta("card")
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color(1, 1, 1, 0.45) if button.disabled else Color.WHITE
	var key: Panel = StartBoardKit.panel(button, Rect2(4, 4, 18, 18), Palette.PAPER)
	key.name = "Key"
	var digit: Label = StartBoardKit.number(key, str(at + 1), Rect2(0, -3, 18, 18), Palette.INK, 16)
	digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var item_name: Label = StartBoardKit.body(
		button,
		card.display_name,
		Rect2(2, 68, rect.size.x - 4, 18),
		Palette.GREY_DARK if button.disabled else Palette.INK,
		12
	)
	item_name.name = "Name"
	item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name.add_theme_font_override("font", ArtStyle.bold_font(700))
	var price: Label = StartBoardKit.number(
		button, "%d€" % card.base, Rect2(2, 86, rect.size.x - 4, 24), Palette.INK, 22
	)
	price.name = "Price"
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if button.disabled:
		button.tooltip_text = StartReasons.swap_word(run, reason)
		var why: Label = StartBoardKit.body(
			button,
			StartReasons.swap_word(run, reason),
			Rect2(2, 104, rect.size.x - 4, 16),
			Palette.TOMATO_DARK,
			11
		)
		why.name = "Reason"
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		why.add_theme_font_override("font", ArtStyle.bold_font(700))


func _reset() -> void:
	StartBoardKit.clear(self)
	tabs.clear()
	offers.clear()
	offer_cards.clear()
	options.clear()
	restore_key = null
	rule_line = null
	close_key = null
	aisle = &""
