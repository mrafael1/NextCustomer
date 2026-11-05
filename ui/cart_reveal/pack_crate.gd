class_name PackCrate
extends Control
## A live starter pack on the staff bench. Whole items, price tags, paper label and post bulbs.

signal picked(index: int)
signal previewed(index: int)

const SIZE := Vector2(264, 210)
## An unpicked crate once another is picked (mock-up v4 B_s0): clearly greyed back.
const DIMMED := Color(0.58, 0.6, 0.6, 1.0)
## The strategy sentence's box on the label, and the example slip under the bench (crate px).
const HINT_RECT := Rect2(8, 30, 204, 50)
## The strategy sentence's line spacing (px): three lines fit its box.
const HINT_LINE_SPACING := -5
const SLIP_RECT := Rect2(8, 222, 248, 50)

var pack: StarterPackDefinition
## The strategy sentence and the example slip (null when the pack has no example row).
var hint: Label
var slip: Panel
var index: int = 0
var selected: bool = false
var hovered: bool = false
var dimmed: bool = false
var reduced: bool = false
var _face: Color
var _picked_tag: Control
var _time: float = 0.0
var _wobbler: Control


func _init(definition: StarterPackDefinition, slot: int, first: bool) -> void:
	pack = definition
	index = slot
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A local palette, not FamilyPalette.shared().style(...): that chained call made
	# `godot --check-only` segfault on exit about 1 run in 4 (Godot 4.7.stable).
	var palette: FamilyPalette = FamilyPalette.shared()
	var family_style: FamilyStyle = palette.style(pack.family)
	_face = PackFrame.pack_colour(pack)
	for card_index: int in pack.cards.size():
		var card: CardDefinition = pack.cards[card_index]
		StartBoardKit.item(self, card, Vector2(16 + card_index * 82, 0), 76)
		var tag: Panel = StartBoardKit.panel(
			self,
			Rect2(26 + card_index * 82, 72, 54, 24),
			Palette.TEAL_PALE if card.is_coupon() else Palette.PAPER
		)
		var price: Label = StartBoardKit.number(
			tag,
			"✂" if card.is_coupon() else "%d€" % card.base,
			Rect2(2, -2, 50, 24),
			Palette.INK,
			22
		)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var label: Panel = StartBoardKit.panel(self, Rect2(22, 100, 220, 102), Palette.PAPER)
	StartBoardKit.panel(label, Rect2(0, 0, 220, 28), _face)
	var heading: Label = StartBoardKit.words(
		label,
		pack.display_name,
		Rect2(8, 0, 180, 28),
		(
			Palette.PAPER
			if pack.family in [&"Coupon", &"Dairy", &"Household", &"Snack", &"Clearance"]
			else Palette.INK
		)
	)
	heading.clip_text = true
	StartBoardKit.centre(heading, Rect2(4, 0, 188, 28))
	StartBoardKit.panel(label, Rect2(194, 2, 24, 24), Palette.CREAM)
	StartBoardKit.number(label, str(index + 1), Rect2(198, 0, 22, 24))
	# The strategy sentence (pack data).
	hint = StartBoardKit.body(label, pack.hint_text, HINT_RECT, Palette.INK, 13)
	hint.name = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Three lines of 12 px, set tight (the body font's line height is tall).
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_constant_override("line_spacing", HINT_LINE_SPACING)
	_example_slip()
	# The family line (glyph and name) centred as one group.
	var family_name: String = String(pack.family).to_upper()
	var has_glyph: bool = family_style != null and family_style.glyph != null
	var family_width: float = (
		StartBoardKit.text_width(family_name.replace(" ", "  ")) + (22.0 if has_glyph else 0.0)
	)
	var family_left: float = 2.0 * floorf((220.0 - family_width) / 4.0)
	if has_glyph:
		var glyph: TextureRect = UiKit.sprite(family_style.glyph)
		glyph.position = Vector2(family_left, 80)
		glyph.size = Vector2(18, 18)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		label.add_child(glyph)
	StartBoardKit.words(
		label,
		family_name,
		Rect2(family_left + (22.0 if has_glyph else 0.0), 80, 180, 20),
		Palette.INK_LIGHT
	)
	_picked_tag = StartBoardKit.panel(self, Rect2(170, 196, 88, 26), Palette.MUSTARD)
	_picked_tag.rotation = deg_to_rad(-4)
	var picked_words: Label = StartBoardKit.words(_picked_tag, "PICKED", Rect2(2, 0, 84, 24))
	StartBoardKit.centre(picked_words, Rect2(2, 0, 84, 24))
	_picked_tag.visible = false
	if first:
		_wobbler = StartBoardKit.panel(self, Rect2(188, -78, 74, 68), Palette.MUSTARD_PALE)
		_wobbler.rotation = deg_to_rad(5)
		_wobbler.pivot_offset = Vector2(36, 68)
		for line: int in 3:
			var sign_words: Label = StartBoardKit.words(
				_wobbler, ["GOOD", "FIRST", "PICK"][line], Rect2(2, 4 + line * 20, 70, 18)
			)
			StartBoardKit.centre(sign_words, Rect2(2, 4 + line * 20, 70, 18))
	mouse_entered.connect(_enter)
	mouse_exited.connect(_exit)
	gui_input.connect(_click)


## The example slip hung under the crate (pack data): TRY THIS ROW, the row's items in order and
## its total; the slip's tip is the worked example, each item keeps its scan popup.
func _example_slip() -> void:
	if pack.example_cards.is_empty():
		return
	slip = StartBoardKit.panel(self, SLIP_RECT, Palette.PAPER, Palette.INK)
	slip.name = "Example"
	slip.mouse_filter = Control.MOUSE_FILTER_PASS
	slip.tooltip_text = pack.example_text
	StartBoardKit.panel(slip, Rect2(SLIP_RECT.size.x / 2.0 - 30, -6, 60, 10), Palette.MUSTARD_PALE)
	var heading: Label = StartBoardKit.tag(
		slip, "TRY THIS ROW", Rect2(8, 2, 150, 20), Palette.INK_LIGHT
	)
	heading.name = "Heading"
	var total: Label = StartBoardKit.number(
		slip,
		"= %d€" % pack.example_total,
		Rect2(SLIP_RECT.size.x - 96, -4, 88, 28),
		Palette.GREEN_DARK,
		24
	)
	total.name = "Total"
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var count: int = pack.example_cards.size()
	var step: float = minf(34.0, floorf((SLIP_RECT.size.x - 16) / count))
	var left: float = floorf((SLIP_RECT.size.x - step * count) / 2.0)
	for at: int in count:
		var card: CardDefinition = pack.example_cards[at]
		var art: Control = StartBoardKit.item(
			slip, card, Vector2(left + at * step + (step - 24) / 2.0, 22), 24
		)
		art.name = "Step%d" % at
		art.tooltip_text = pack.example_text
		if pack.cards.has(card):
			StartBoardKit.panel(slip, Rect2(left + at * step + 6, 46, step - 12, 2), _face, _face)


func show_state(on: bool, other_picked: bool) -> void:
	var changed: bool = selected != on
	selected = on
	dimmed = other_picked and not selected and not hovered
	_picked_tag.visible = selected
	queue_redraw()
	if changed and on and not reduced and is_inside_tree():
		_picked_tag.scale = Vector2.ONE * 1.4
		(
			create_tween()
			. tween_property(_picked_tag, "scale", Vector2.ONE, 0.25)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		if _wobbler != null:
			var swing: Tween = create_tween()
			swing.tween_property(_wobbler, "rotation", deg_to_rad(-8), 0.08)
			swing.tween_property(_wobbler, "rotation", deg_to_rad(5), 0.2)
	modulate = DIMMED if dimmed else Color.WHITE


func _process(delta: float) -> void:
	if selected and not reduced:
		_time += delta
		queue_redraw()


func _enter() -> void:
	hovered = true
	previewed.emit(index)


func _exit() -> void:
	hovered = false
	previewed.emit(-1)


func _click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		picked.emit(index)


func _draw() -> void:
	if selected or hovered:
		for y: int in range(-44, 76, 2):
			for x: int in range(0, 264, 2):
				if pow((x - 132.0) / 132.0, 2) + pow((y - 36.0) / 82.0, 2) < 1 and (x + y) % 4 == 0:
					draw_rect(Rect2(x, y, 2, 2), Palette.MUSTARD_DARK)
	var crate: Rect2 = Rect2(0, 56, SIZE.x, 148)
	draw_rect(crate, Palette.INK)
	draw_rect(crate.grow(-2), Palette.BROWN_DARK)
	for y: float in [60.0, 88.0, 124.0, 162.0, 198.0]:
		draw_rect(Rect2(4, y, 256, 6), Palette.BROWN_LIGHT)
	for x: float in [4.0, 250.0]:
		draw_rect(Rect2(x, 64, 10, 138), Palette.WOOD)
		for bulb: int in 8:
			var lit: bool = hovered or reduced or (bulb + int(_time * 10)) % 4 < 2
			draw_rect(Rect2(x, 78 + bulb * 16, 10, 10), Palette.INK)
			if selected or hovered:
				draw_rect(
					Rect2(x + 2, 80 + bulb * 16, 6, 6),
					Palette.GOLD if lit else Palette.MUSTARD_DARK
				)
	if selected or hovered:
		draw_rect(crate.grow(4), Palette.MUSTARD if selected else Palette.TEAL_LIGHT, false, 4)
	if _wobbler != null:
		draw_line(Vector2(240, -12), Vector2(240, 50), Palette.STEEL_LIGHT, 4)
