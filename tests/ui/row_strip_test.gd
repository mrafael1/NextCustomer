extends GdUnitTestSuite
## The checkout row's pixel-art slots (#55, style frame v2): empty slots show the recessed mat
## and their engraved number, a slot holding a card shows no mat, the placeable ring is a solid
## mustard frame between ink lines drawn over the slot or its card, the drag's landing fill shows
## on empty slots only, CLOSED is a velvet rope between brass posts with the CLOSED sign and the
## closing inspections' names, and wide rows still scale to the 7-slot width.

const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
const INSPECTIONS := "res://data/inspections"


func test_empty_slots_show_the_mat_and_their_number() -> void:
	var strip: RowStrip = await _strip(7)
	for slot: int in range(7):
		var panel: PanelContainer = strip.slots[slot]
		var style: StyleBoxTexture = panel.get_theme_stylebox("panel") as StyleBoxTexture
		assert_object(style.texture).is_same(RowStrip.SLOT_MAT_EMPTY)
		assert_bool(RowStrip.shows_mat(panel)).is_true()
		# The mat reaches one art pixel past the slot; the slot itself stays card-sized.
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			assert_float(style.get_expand_margin(side)).is_equal(float(RowStrip.MAT_GROW))
		var number: Label = panel.get_child(0) as Label
		assert_str(number.text).is_equal(str(slot + 1))
		# Engraved: brass dark in the number font, over a paper highlight under it.
		assert_object(number.get_theme_font("font")).is_same(ArtStyle.number_font())
		assert_int(number.get_theme_font_size("font_size")).is_equal(RowStrip.NUMBER_SIZE)
		assert_that(number.get_theme_color("font_color")).is_equal(Palette.BRASS_DARK)
		assert_that(number.get_theme_color("font_shadow_color")).is_equal(Palette.PAPER)
		assert_int(number.get_theme_constant("shadow_offset_y")).is_equal(RowStrip.ENGRAVE_OFFSET)
		assert_vector(panel.get_global_rect().size).is_equal(ArtCardView.SIZE)
		assert_bool(strip.is_outlined(slot)).is_false()
		assert_bool(RowStrip.is_hovered(panel)).is_false()


## A slot holding a card shows no mat under it, only the card; emptied again, it shows its mat.
func test_a_filled_slot_shows_no_mat() -> void:
	var strip: RowStrip = await _strip(7)
	var row: Array[CardInstance] = [_card("bread", 1), _card("milk", 2)]
	strip.show_cards(row, -1, _ignore, load(BALANCE))
	await _frames(1)
	for slot: int in range(7):
		var panel: PanelContainer = strip.slots[slot]
		assert_bool(RowStrip.shows_mat(panel)).is_equal(slot >= row.size())
		assert_vector(panel.get_global_rect().size).is_equal(ArtCardView.SIZE)
	strip.show_cards([] as Array[CardInstance], -1, _ignore, load(BALANCE))
	for slot: int in range(7):
		assert_bool(RowStrip.shows_mat(strip.slots[slot])).is_true()
	# The cards taken out are freed.
	await _frames(1)


## The placeable ring's art: solid mustard between an ink line outside and one inside, so it
## reads on the brass mats and on a card.
func test_the_placeable_ring_has_ink_lines() -> void:
	var image: Image = RowStrip.SLOT_PLACEABLE.get_image()
	var scale: int = ArtStyle.ART_SCALE
	var middle: int = floori(image.get_height() / 2.0)
	# Across the left edge at mid-height, one art pixel at a time: ink, mustard, mustard dark, ink.
	var expected: Array[String] = [
		Palette.INK.to_html(false),
		Palette.MUSTARD.to_html(false),
		"b38425",
		Palette.INK.to_html(false)
	]
	for art_x: int in range(expected.size()):
		var pixel: Color = image.get_pixel(art_x * scale, middle)
		assert_str(pixel.to_html(false)).is_equal(expected[art_x])
	# The middle stays clear, so the card or the mat shows through.
	assert_float(image.get_pixel(floori(image.get_width() / 2.0), middle).a).is_equal(0.0)


## The ring marks the slots up to placeable_until, filled or not, drawn above the card and one
## art pixel past the slot on every side.
func test_the_placeable_ring_is_drawn_over_slots_and_cards() -> void:
	var strip: RowStrip = await _strip(7)
	var row: Array[CardInstance] = [_card("bread", 1), _card("milk", 2)]
	var views: Array[CardView] = strip.show_cards(row, 2, _ignore, load(BALANCE))
	await _frames(2)
	assert_int(views.size()).is_equal(2)
	for slot: int in range(7):
		assert_bool(strip.is_outlined(slot)).is_equal(slot <= 2)
	var panel: PanelContainer = strip.slots[1]
	# The card stays child 0; the marks layer is last, so the ring draws over the card.
	assert_object(panel.get_child(0)).is_same(views[1])
	var marks: Control = panel.get_child(panel.get_child_count() - 1) as Control
	var ring: NinePatchRect = marks.get_node(NodePath(RowStrip.RING_NAME)) as NinePatchRect
	assert_object(ring.texture).is_same(RowStrip.SLOT_PLACEABLE)
	var grown: Rect2 = panel.get_global_rect().grow(RowStrip.RING_GROW)
	assert_vector(ring.get_global_rect().position).is_equal_approx(grown.position, Vector2.ONE)
	assert_vector(ring.get_global_rect().size).is_equal_approx(grown.size, Vector2.ONE)
	# A refresh without a picked card clears every ring.
	strip.show_cards(row, -1, _ignore, load(BALANCE))
	await _frames(1)
	for slot: int in range(7):
		assert_bool(strip.is_outlined(slot)).is_false()


## The landing fill shows on an empty slot only (a card there is tinted by CardDrag instead).
func test_the_hover_fill_shows_on_empty_slots_only() -> void:
	var strip: RowStrip = await _strip(7)
	var row: Array[CardInstance] = [_card("bread", 1)]
	strip.show_cards(row, 1, _ignore, load(BALANCE))
	RowStrip.set_hovered(strip.slots[1], true)
	assert_bool(RowStrip.is_hovered(strip.slots[1])).is_true()
	RowStrip.set_hovered(strip.slots[0], true)
	assert_bool(RowStrip.is_hovered(strip.slots[0])).is_false()
	RowStrip.set_hovered(strip.slots[1], false)
	assert_bool(RowStrip.is_hovered(strip.slots[1])).is_false()


## Row cards are art cards with their aisle mark.
func test_row_cards_wear_their_aisle_mark() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var aisle: AisleDefinition = balance.aisles[0]
	var stocked: CardDefinition = (aisle.base_cards + aisle.capsule_cards)[0]
	var strip: RowStrip = await _strip(7)
	var row: Array[CardInstance] = [
		CardInstance.new(stocked, 1), _card("bread", 2), _card("repeat", 3)
	]
	var views: Array[CardView] = strip.show_cards(row, -1, _ignore, balance)
	var marked: ArtCardView = views[0] as ArtCardView
	assert_object(marked).is_not_null()
	assert_object(marked.aisle).is_same(aisle)
	assert_bool(marked.has_band()).is_true()
	assert_bool((views[1] as ArtCardView).has_band()).is_false()
	assert_bool((views[2] as ArtCardView).has_band()).is_false()


## CLOSED: bare rubber (no mat), the word on the inspection tag's frame (drawn behind it),
## hanging from the velvet rope between two brass posts at their art's size, the caption under
## them, the tooltip and the click signal. Nothing in the cell takes the click from the panel.
func test_a_closed_slot_shows_the_rope_and_the_sign() -> void:
	var strip: RowStrip = await _strip(6, 1, "Closed by the inspection: Short belt", "Short belt")
	assert_int(strip.closed.size()).is_equal(1)
	var panel: PanelContainer = strip.closed[0]
	assert_bool(RowStrip.shows_mat(panel)).is_false()
	assert_bool(panel.get_theme_stylebox("panel") is StyleBoxEmpty).is_true()
	assert_str(panel.tooltip_text).contains("Short belt")
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var cell: Rect2 = panel.get_global_rect()
	assert_vector(cell.size).is_equal(ArtCardView.SIZE)
	var label: Label = panel.get_child(0) as Label
	assert_str(label.text).is_equal(RowStrip.CLOSED_TEXT)
	assert_object(label.material).is_null()
	var sign_frame: NinePatchRect = label.get_node(NodePath(RowStrip.SIGN_NAME)) as NinePatchRect
	assert_object(sign_frame.texture).is_same(RowStrip.TAG_FRAME)
	assert_bool(sign_frame.show_behind_parent).is_true()
	assert_that(sign_frame.get_global_rect()).is_equal(_in_cell(cell, RowStrip.CLOSED_SIGN_RECT))
	# The word fits the sign.
	var font: Font = label.get_theme_font("font")
	var word: Vector2 = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
	)
	assert_float(word.x).is_less_equal(RowStrip.CLOSED_SIGN_RECT.size.x - 8.0)
	assert_float(word.y).is_less_equal(RowStrip.CLOSED_SIGN_RECT.size.y)
	# The posts and the rope at their art's size (never stretched), inside the cell.
	var parts: Array[TextureRect] = [
		label.get_node("Post0") as TextureRect,
		label.get_node("Post1") as TextureRect,
		label.get_node("Rope") as TextureRect,
	]
	var rects: Array[Rect2] = RowStrip.POST_RECTS.duplicate()
	rects.append(RowStrip.ROPE_RECT)
	for index: int in range(parts.size()):
		var part: TextureRect = parts[index]
		assert_vector(part.size).is_equal(Vector2(part.texture.get_size()))
		assert_that(part.get_global_rect()).is_equal(_in_cell(cell, rects[index]))
		assert_bool(cell.encloses(part.get_global_rect())).is_true()
		assert_bool(part.has_meta(ArtStyle.PIXEL_ART_META)).is_true()
	assert_object(parts[0].texture).is_same(RowStrip.ROPE_POST)
	assert_object(parts[2].texture).is_same(RowStrip.VELVET_ROPE)
	var caption: Label = RowStrip.closed_caption_label(panel)
	assert_str(caption.text).is_equal("Short belt")
	assert_that(caption.get_global_rect()).is_equal(_in_cell(cell, RowStrip.CLOSED_CAPTION_RECT))
	assert_float(caption.get_global_rect().position.y).is_greater_equal(
		parts[0].get_global_rect().end.y
	)
	for child: Node in label.get_children():
		assert_int((child as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# The same counts again only update the tooltip and the caption.
	strip.set_slot_count(6, 1, "Closed", "Coupon slot closed")
	assert_object(strip.closed[0]).is_same(panel)
	assert_str(RowStrip.closed_caption_label(panel).text).is_equal("Coupon slot closed")
	var clicks: Array[int] = [0]
	strip.closed_clicked.connect(func() -> void: clicks[0] += 1)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	panel.gui_input.emit(press)
	assert_int(clicks[0]).is_equal(1)


## The caption names the inspections that close slots, from data; every one of them, and all of
## them together, fit the caption's rect (two lines at most).
func test_every_closed_caption_fits() -> void:
	var closing: Array[InspectionDefinition] = []
	for file_name: String in DirAccess.get_files_at(INSPECTIONS):
		if not file_name.ends_with(".tres"):
			continue
		var inspection: InspectionDefinition = load(INSPECTIONS.path_join(file_name))
		var caption: String = RowStrip.closed_caption([inspection])
		if inspection.extra_slots < 0 or inspection.extra_coupon_slots < 0:
			assert_str(caption).is_equal(inspection.display_name)
			closing.append(inspection)
		else:
			assert_str(caption).is_empty()
	assert_int(closing.size()).is_greater_equal(2)
	var captions: Array[String] = [RowStrip.closed_caption(closing)]
	for inspection: InspectionDefinition in closing:
		captions.append(RowStrip.closed_caption([inspection]))
	var font: Font = RowStrip.caption_font()
	var width: float = RowStrip.CLOSED_CAPTION_RECT.size.x
	for caption: String in captions:
		var needed: Vector2 = font.get_multiline_string_size(
			caption,
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			RowStrip.CLOSED_CAPTION_SIZE,
			-1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		)
		(
			assert_bool(needed.x <= width and needed.y <= RowStrip.CLOSED_CAPTION_RECT.size.y)
			. override_failure_message("%s needs %s" % [caption, needed])
			. is_true()
		)


## Plan 3.8: 8 or 9 slots scale to the 7-slot width; a closed slot never rescales the row
## (plan 3.9), since the row keeps its usual panel count.
func test_wide_rows_scale_to_seven_slots() -> void:
	for count: int in [8, 9]:
		var strip: RowStrip = await _strip(count)
		var width: float = strip.box.get_global_rect().size.x
		assert_float(width).is_equal_approx(RowStrip.row_width(RowStrip.LAID_OUT_SLOTS), 0.5)
	var closed: RowStrip = await _strip(6, 1, "Closed")
	assert_vector(closed.box.scale).is_equal(Vector2.ONE)


func _strip(
	count: int, closed_count: int = 0, reason: String = "", caption: String = ""
) -> RowStrip:
	var strip: RowStrip = auto_free(RowStrip.new())
	add_child(strip)
	strip.set_slot_count(count, closed_count, reason, caption)
	await _frames(2)
	return strip


## `rect` (a cell's coordinates) in the cell at `cell`.
static func _in_cell(cell: Rect2, rect: Rect2) -> Rect2:
	return Rect2(cell.position + rect.position, rect.size)


func _card(id: String, instance_id: int) -> CardInstance:
	return CardInstance.new(load("%s/%s.tres" % [CARDS, id]), instance_id)


func _ignore(_view: CardView) -> void:
	pass


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
