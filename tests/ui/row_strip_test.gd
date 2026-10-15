extends GdUnitTestSuite
## The checkout row's cells on the belt (#55, #75; style frame v2): every open cell has a mat
## (its empty face a step darker, with the slot number engraved), the row's cards stand on the
## mats as belt items, the placeable ring is a solid mustard frame between ink lines around the
## mat and under the item, the drag's landing fill shows on empty mats only, CLOSED is bare rubber
## behind a velvet rope between brass posts with the CLOSED sign and the closing inspections'
## names, and wide rows close their gaps, then scale to the 7-slot width with their text still
## legible.

const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
const INSPECTIONS := "res://data/inspections"
## The smallest a scaled row's sticker summary (PriceSticker.SUMMARY_SIZE) may print, in canvas
## pixels.
const MIN_SUMMARY_PX := 10.0
## The mat's ink line and brass ring, in canvas pixels: the item's sprite stands inside them.
const MAT_RIM := 6.0


## Each open cell is a belt cell with a mat at MAT_RECT, its empty face showing the engraved
## slot number; the cell itself draws nothing.
func test_every_open_cell_has_a_mat_with_its_number() -> void:
	var strip: RowStrip = await _strip(7)
	for slot: int in range(7):
		var panel: PanelContainer = strip.slots[slot]
		var cell: Rect2 = panel.get_global_rect()
		assert_vector(cell.size).is_equal(ItemView.BELT_SIZE)
		assert_bool(panel.get_theme_stylebox("panel") is StyleBoxEmpty).is_true()
		var mat: Panel = RowStrip.mat(panel)
		var style: StyleBoxTexture = mat.get_theme_stylebox("panel") as StyleBoxTexture
		assert_object(style.texture).is_same(RowStrip.SLOT_MAT_EMPTY)
		assert_bool(RowStrip.shows_empty_mat(panel)).is_true()
		assert_that(mat.get_global_rect()).is_equal(_in_cell(cell, RowStrip.MAT_RECT))
		assert_bool(mat.has_meta(ArtStyle.PIXEL_ART_META)).is_true()
		assert_int(mat.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		var number: Label = RowStrip.slot_number(panel)
		assert_bool(number.visible).is_true()
		assert_str(number.text).is_equal(str(slot + 1))
		assert_that(number.get_global_rect()).is_equal(_in_cell(cell, RowStrip.NUMBER_RECT))
		assert_bool(mat.get_global_rect().encloses(number.get_global_rect())).is_true()
		assert_float(number.get_minimum_size().y).is_less_equal(number.size.y)
		# Engraved: brass dark in the number font, over a paper highlight under it.
		assert_object(number.get_theme_font("font")).is_same(ArtStyle.number_font())
		assert_int(number.get_theme_font_size("font_size")).is_equal(RowStrip.NUMBER_SIZE)
		assert_that(number.get_theme_color("font_color")).is_equal(Palette.BRASS_DARK)
		assert_that(number.get_theme_color("font_shadow_color")).is_equal(Palette.PAPER)
		assert_int(number.get_theme_constant("shadow_offset_y")).is_equal(RowStrip.ENGRAVE_OFFSET)
		assert_bool(strip.is_outlined(slot)).is_false()
		assert_bool(RowStrip.is_hovered(panel)).is_false()
		if slot > 0:
			var gap: float = cell.position.x - strip.slots[slot - 1].get_global_rect().end.x
			assert_float(gap).is_equal(float(RowStrip.SEPARATION))


## A card stands on its mat as a belt item filling the cell: the sprite in the mat's recess, the
## payout plaque on the mat's top rim, the sticker under the mat; the mat shows its plain face
## and no number. Emptied again, the mat shows its empty face and number.
func test_items_stand_on_their_mats() -> void:
	var strip: RowStrip = await _strip(7)
	var row: Array[CardInstance] = [_card("bread", 1), _card("milk", 2), _card("repeat", 3)]
	var views: Array[CardView] = strip.show_cards(row, -1, _ignore, load(BALANCE))
	await _frames(2)
	assert_int(views.size()).is_equal(row.size())
	for slot: int in range(7):
		var panel: PanelContainer = strip.slots[slot]
		var filled: bool = slot < row.size()
		assert_bool(RowStrip.shows_empty_mat(panel)).is_equal(not filled)
		assert_bool(RowStrip.slot_number(panel).visible).is_equal(not filled)
		if not filled:
			continue
		var style: StyleBoxTexture = (
			RowStrip.mat(panel).get_theme_stylebox("panel") as StyleBoxTexture
		)
		assert_object(style.texture).is_same(RowStrip.SLOT_MAT)
		var item: ItemView = views[slot] as ItemView
		assert_object(item).is_not_null()
		assert_int(item.form).is_equal(ItemView.Form.BELT)
		assert_object(item.get_parent()).is_same(panel)
		var cell: Rect2 = panel.get_global_rect()
		assert_that(item.get_global_rect()).is_equal(cell)
		var mat: Rect2 = RowStrip.mat(panel).get_global_rect()
		var recess: Rect2 = mat.grow(-MAT_RIM)
		var sprite: Rect2 = item.body.get_global_rect()
		assert_bool(recess.encloses(sprite)).override_failure_message(str(sprite)).is_true()
		item.show_badge(12, false)
		var face: Rect2 = (item.badge as PayoutPlaque).face().get_global_rect()
		assert_float(face.position.y).is_less_equal(mat.position.y)
		assert_float(face.end.y).is_greater(mat.position.y)
		assert_bool(cell.encloses(face)).is_true()
		assert_bool(face.intersects(sprite)).is_false()
		var sticker: Rect2 = item.sticker().get_global_rect()
		assert_float(sticker.position.y).is_greater_equal(mat.end.y)
		assert_bool(cell.encloses(sticker)).is_true()
	strip.show_cards([] as Array[CardInstance], -1, _ignore, load(BALANCE))
	for slot: int in range(7):
		assert_bool(RowStrip.shows_empty_mat(strip.slots[slot])).is_true()
		assert_bool(RowStrip.slot_number(strip.slots[slot]).visible).is_true()
	# The items taken out are freed.
	await _frames(1)
	for panel: PanelContainer in strip.slots:
		for child: Node in panel.get_children():
			assert_bool(child is CardView).is_false()


## The placeable ring's art: solid mustard between an ink line outside and one inside, so it
## reads on the brass mats.
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
	# The middle stays clear, so the mat shows through.
	assert_float(image.get_pixel(floori(image.get_width() / 2.0), middle).a).is_equal(0.0)


## The ring marks the slots up to placeable_until, filled or not: one art pixel around the mat,
## inside the cell, over the mat and under the item (whose plaque and sprite stay whole).
func test_the_placeable_ring_rings_the_mat_under_the_item() -> void:
	var strip: RowStrip = await _strip(7)
	var row: Array[CardInstance] = [_card("bread", 1), _card("milk", 2)]
	var views: Array[CardView] = strip.show_cards(row, 2, _ignore, load(BALANCE))
	await _frames(2)
	assert_int(views.size()).is_equal(2)
	for slot: int in range(7):
		assert_bool(strip.is_outlined(slot)).is_equal(slot <= 2)
	for slot: int in [1, 2]:
		var panel: PanelContainer = strip.slots[slot]
		var marks: Control = panel.get_node(NodePath(RowStrip.MARKS_NAME)) as Control
		var ring: NinePatchRect = marks.get_node(NodePath(RowStrip.RING_NAME)) as NinePatchRect
		assert_object(ring.texture).is_same(RowStrip.SLOT_PLACEABLE)
		var mat: Rect2 = RowStrip.mat(panel).get_global_rect()
		assert_that(ring.get_global_rect()).is_equal(mat.grow(RowStrip.RING_GROW))
		assert_bool(panel.get_global_rect().encloses(ring.get_global_rect())).is_true()
		assert_int(marks.get_index()).is_greater(RowStrip.mat(panel).get_parent().get_index())
	assert_int(views[1].get_index()).is_greater(
		strip.slots[1].get_node(NodePath(RowStrip.MARKS_NAME)).get_index()
	)
	# A refresh without a picked card clears every ring.
	strip.show_cards(row, -1, _ignore, load(BALANCE))
	await _frames(1)
	for slot: int in range(7):
		assert_bool(strip.is_outlined(slot)).is_false()


## The landing fill covers an empty mat only (an item there is tinted by CardDrag instead).
func test_the_hover_fill_shows_on_empty_mats_only() -> void:
	var strip: RowStrip = await _strip(7)
	var row: Array[CardInstance] = [_card("bread", 1)]
	strip.show_cards(row, 1, _ignore, load(BALANCE))
	await _frames(1)
	RowStrip.set_hovered(strip.slots[1], true)
	assert_bool(RowStrip.is_hovered(strip.slots[1])).is_true()
	var marks: Control = strip.slots[1].get_node(NodePath(RowStrip.MARKS_NAME)) as Control
	var fill: Control = marks.get_node(NodePath(RowStrip.HOVER_NAME)) as Control
	assert_that(fill.get_global_rect()).is_equal(RowStrip.mat(strip.slots[1]).get_global_rect())
	RowStrip.set_hovered(strip.slots[0], true)
	assert_bool(RowStrip.is_hovered(strip.slots[0])).is_false()
	RowStrip.set_hovered(strip.slots[1], false)
	assert_bool(RowStrip.is_hovered(strip.slots[1])).is_false()


## Row items carry their aisle (a staple and a coupon have none).
func test_row_items_carry_their_aisle() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var aisle: AisleDefinition = balance.aisles[0]
	var stocked: CardDefinition = (aisle.base_cards + aisle.capsule_cards)[0]
	var strip: RowStrip = await _strip(7)
	var row: Array[CardInstance] = [
		CardInstance.new(stocked, 1), _card("bread", 2), _card("repeat", 3)
	]
	var views: Array[CardView] = strip.show_cards(row, -1, _ignore, balance)
	assert_object((views[0] as ItemView).aisle).is_same(aisle)
	assert_object((views[1] as ItemView).aisle).is_null()
	assert_object((views[2] as ItemView).aisle).is_null()


## CLOSED: bare rubber (no mat), the word on the inspection tag's frame (drawn behind it),
## hanging from the velvet rope between two brass posts at their art's size, the caption under
## them, the tooltip and the click signal. Nothing in the cell takes the click from the cell.
func test_a_closed_slot_shows_the_rope_and_the_sign() -> void:
	var strip: RowStrip = await _strip(6, 1, "Closed by the inspection: Short belt", "Short belt")
	assert_int(strip.closed.size()).is_equal(1)
	var panel: PanelContainer = strip.closed[0]
	assert_object(RowStrip.mat(panel)).is_null()
	assert_bool(RowStrip.shows_empty_mat(panel)).is_false()
	assert_bool(panel.get_theme_stylebox("panel") is StyleBoxEmpty).is_true()
	assert_str(panel.tooltip_text).contains("Short belt")
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var cell: Rect2 = panel.get_global_rect()
	assert_vector(cell.size).is_equal(ItemView.BELT_SIZE)
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


## Plan 3.8: the 7 slots fill the rubber at pitch 124 unscaled; 8 or 9 slots close their gaps,
## then scale to the 7-slot width, their cells touching but never overlapping, each item's
## sprite in its mat and its plaque and chips in its cell, and the sticker's summary still at
## least MIN_SUMMARY_PX tall on screen. A closed slot never rescales the row (plan 3.9), since
## the row keeps its usual cell count.
func test_wide_rows_close_their_gaps_then_scale() -> void:
	var seven: RowStrip = await _strip(7)
	assert_vector(seven.box.scale).is_equal(Vector2.ONE)
	assert_float(seven.box.get_global_rect().size.x).is_equal(RowStrip.row_width(7))
	assert_float(RowStrip.row_width(7)).is_equal(864.0)
	for count: int in [8, 9]:
		var strip: RowStrip = await _strip(count)
		assert_int(RowStrip.separation_for(count)).is_equal(RowStrip.WIDE_SEPARATION)
		var width: float = strip.box.get_global_rect().size.x
		assert_float(width).is_equal_approx(RowStrip.row_width(RowStrip.LAID_OUT_SLOTS), 0.5)
		var factor: float = strip.box.scale.x
		var natural: float = RowStrip.row_width(count, RowStrip.WIDE_SEPARATION)
		assert_float(factor).is_equal_approx(RowStrip.row_width(7) / natural, 0.001)
		assert_float(PriceSticker.SUMMARY_SIZE * factor).is_greater_equal(MIN_SUMMARY_PX)
		var row: Array[CardInstance] = []
		for slot: int in range(count):
			row.append(_card("milk" if slot % 2 == 0 else "repeat", slot + 1))
		var views: Array[CardView] = strip.show_cards(row, -1, _ignore, load(BALANCE))
		await _frames(2)
		var previous: Rect2 = Rect2()
		for slot: int in range(count):
			var item: ItemView = views[slot] as ItemView
			item.show_badge(9999, false)
			for text: String in ["+15 · Category", "×3 · Multipack", "Coupon engine"]:
				item.add_chip(text, false)
			var cell: Rect2 = strip.slots[slot].get_global_rect()
			var message: String = "%d slots, cell %d" % [count, slot]
			if slot > 0:
				assert_float(cell.position.x).is_greater_equal(previous.end.x - 0.01)
			previous = cell
			var mat: Rect2 = RowStrip.mat(strip.slots[slot]).get_global_rect()
			var sprite: Rect2 = item.body.get_global_rect()
			assert_bool(mat.encloses(sprite)).override_failure_message(message).is_true()
			var parts: Array[Control] = [(item.badge as PayoutPlaque).face(), item.sticker()]
			parts.append_array(item.chips())
			for part: Control in parts:
				var rect: Rect2 = part.get_global_rect()
				(
					assert_bool(cell.grow(0.01).encloses(rect))
					. override_failure_message("%s: %s" % [message, rect])
					. is_true()
				)
			var summary: Label = item.sticker().summary_label()
			var shown: float = (
				summary.get_theme_font_size("font_size")
				* summary.get_global_transform().get_scale().y
			)
			assert_float(shown).is_greater_equal(MIN_SUMMARY_PX)
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
