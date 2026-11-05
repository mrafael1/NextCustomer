class_name PackCrate
extends Control
## A live starter pack on the staff bench (reworked 2026-11-05, v1.01): its three items standing
## big in a wood crate, and on the crate's paper label the pack's name in its family's colour,
## its key (1 to 3) and its family. No strategy sentence, not even as a tooltip (the cards keep
## their own popups on hover). The items stand at their sprites' own size, overlapping a little.

signal picked(index: int)
signal previewed(index: int)

const SIZE := Vector2(272, 256)
## An unpicked crate once another is picked (mock-up v4 B_s0): clearly greyed back.
const DIMMED := Color(0.58, 0.6, 0.6, 1.0)
## The items: ITEM px each, ITEM_STEP apart from ITEM_LEFT, standing on the crate's rim.
const ITEM := 96.0
const ITEM_STEP := 88.0
const ITEM_LEFT := 0.0
## The wood crate under them, and the paper label on its front (crate px).
const CRATE_RECT := Rect2(0, 84, 272, 172)
const LABEL_RECT := Rect2(22, 104, 228, 120)
## The label's name bar, and the family line (glyph over name) under it (label px).
const NAME_BAR := Rect2(0, 0, 228, 38)
const FAMILY_GLYPH := Rect2(92, 44, 45, 45)
const FAMILY_LINE := Rect2(8, 92, 212, 22)
## The PICKED tag on the crate's bottom rail, under the label (crate px).
const PICKED_RECT := Rect2(180, 229, 84, 24)
## The dithered halo behind a picked or hovered crate's items (crate px): an ellipse as wide as the
## crate, its top HALO_RADIUS_Y over HALO_CENTRE_Y, so a lifted crate's halo stays under the badge
## pins board (feedback 2026-11-05: it spilled onto the board's frame).
const HALO_CENTRE_Y := 58.0
const HALO_RADIUS_Y := 68.0

var pack: StarterPackDefinition
## The paper label on the crate's front (its name bar, key and family line).
var label: Panel
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
		var item: Control = StartBoardKit.item(
			self, pack.cards[card_index], Vector2(ITEM_LEFT + card_index * ITEM_STEP, 0), ITEM
		)
		item.name = "Item%d" % card_index
	label = StartBoardKit.panel(self, LABEL_RECT, Palette.PAPER)
	label.name = "Label"
	StartBoardKit.panel(label, NAME_BAR, _face)
	var heading: Label = StartBoardKit.words(
		label,
		pack.display_name,
		Rect2(8, 3, 180, 32),
		(
			Palette.PAPER
			if pack.family in [&"Coupon", &"Dairy", &"Household", &"Snack", &"Clearance"]
			else Palette.INK
		)
	)
	heading.name = "Name"
	heading.clip_text = true
	StartBoardKit.centre(heading, Rect2(4, 3, 188, 32))
	var key: Panel = StartBoardKit.panel(label, Rect2(194, 5, 28, 28), Palette.CREAM)
	key.name = "Key"
	StartBoardKit.number(key, str(index + 1), Rect2(4, 0, 22, 26))
	if family_style != null and family_style.glyph != null:
		var glyph: TextureRect = UiKit.sprite(family_style.glyph)
		glyph.name = "Glyph"
		glyph.position = FAMILY_GLYPH.position
		glyph.size = FAMILY_GLYPH.size
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		label.add_child(glyph)
	var family: Label = StartBoardKit.words(
		label, String(pack.family).to_upper(), FAMILY_LINE, Palette.INK_LIGHT
	)
	family.name = "Family"
	StartBoardKit.centre(family, FAMILY_LINE)
	_picked_tag = StartBoardKit.panel(self, PICKED_RECT, Palette.MUSTARD)
	_picked_tag.name = "Picked"
	_picked_tag.pivot_offset = PICKED_RECT.size / 2.0
	_picked_tag.rotation = deg_to_rad(-2)
	var words_rect: Rect2 = Rect2(2, 0, PICKED_RECT.size.x - 4, PICKED_RECT.size.y)
	var picked_words: Label = StartBoardKit.words(_picked_tag, "PICKED", words_rect)
	StartBoardKit.centre(picked_words, words_rect)
	_picked_tag.visible = false
	if first:
		_wobbler = StartBoardKit.panel(self, Rect2(194, -56, 74, 56), Palette.MUSTARD_PALE)
		_wobbler.name = "FirstPick"
		_wobbler.rotation = deg_to_rad(5)
		_wobbler.pivot_offset = Vector2(36, 56)
		for line: int in 3:
			var sign_words: Label = StartBoardKit.words(
				_wobbler, ["GOOD", "FIRST", "PICK"][line], Rect2(2, 2 + line * 17, 70, 18)
			)
			StartBoardKit.centre(sign_words, Rect2(2, 2 + line * 17, 70, 18))
	mouse_entered.connect(_enter)
	mouse_exited.connect(_exit)
	gui_input.connect(_click)


## The PICKED tag (shown once this crate is picked).
func picked_tag() -> Control:
	return _picked_tag


## The GOOD FIRST PICK sign over the crate, or null.
func first_pick_sign() -> Control:
	return _wobbler


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
		for y: int in range(int(HALO_CENTRE_Y - HALO_RADIUS_Y), int(CRATE_RECT.position.y) + 12, 2):
			for x: int in range(0, int(SIZE.x), 2):
				var across: float = (x - SIZE.x / 2.0) / (SIZE.x / 2.0)
				var down: float = (y - HALO_CENTRE_Y) / HALO_RADIUS_Y
				if pow(across, 2) + pow(down, 2) < 1 and (x + y) % 4 == 0:
					draw_rect(Rect2(x, y, 2, 2), Palette.MUSTARD_DARK)
	var crate: Rect2 = CRATE_RECT
	draw_rect(crate, Palette.INK)
	draw_rect(crate.grow(-2), Palette.BROWN_DARK)
	for y: float in [88.0, 128.0, 168.0, 208.0, 246.0]:
		draw_rect(Rect2(4, y, SIZE.x - 8, 6), Palette.BROWN_LIGHT)
	for x: float in [4.0, SIZE.x - 14.0]:
		draw_rect(Rect2(x, 92, 10, 160), Palette.WOOD)
		for bulb: int in 9:
			var lit: bool = hovered or reduced or (bulb + int(_time * 10)) % 4 < 2
			draw_rect(Rect2(x, 104 + bulb * 16, 10, 10), Palette.INK)
			if selected or hovered:
				draw_rect(
					Rect2(x + 2, 106 + bulb * 16, 6, 6),
					Palette.GOLD if lit else Palette.MUSTARD_DARK
				)
	if selected or hovered:
		draw_rect(crate.grow(4), Palette.MUSTARD if selected else Palette.TEAL_LIGHT, false, 4)
	if _wobbler != null:
		draw_line(Vector2(232, 0), Vector2(232, CRATE_RECT.position.y), Palette.STEEL_LIGHT, 4)
