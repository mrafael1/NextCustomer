extends GdUnitTestSuite
## The checkout row's cells on the belt (#80, mock-up B2, step 6): an empty open cell shows a
## dashed footprint on the belt leaning to the belt's vanishing point and a dashed blank ticket
## (the "mat") on the rail with its slot number, and takes clicks and drops on those two only;
## the row's cards stand on the belt as belt items with their sticker on the ticket's place over
## the ticket's shadow, the placeable ring is a solid mustard frame between ink lines around the
## ticket and under the item, the drag's landing fill shows on empty tickets only, CLOSED is a
## velvet rope between two tall stanchions on the belt over the ink plate with CLOSED and the
## closing inspections' names, and wide rows close their gaps, then scale to the 7-slot width with
## their text still legible.

const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
const INSPECTIONS := "res://data/inspections"
## The smallest a scaled row's sticker summary (PriceSticker.SUMMARY_SIZE) may print, in canvas
## pixels.
const MIN_SUMMARY_PX := 10.0


## Each open cell is a belt cell that draws nothing itself; empty, it shows its footprint on the
## belt and its blank ticket (the "mat", ticket_empty's art at its size) at TICKET_RECT on the
## rail with its slot number, and no ticket shadow.
func test_every_open_cell_has_a_mat_with_its_number() -> void:
	var strip: RowStrip = await _strip(7)
	for slot: int in range(7):
		var panel: PanelContainer = strip.slots[slot]
		var cell: Rect2 = panel.get_global_rect()
		assert_vector(cell.size).is_equal(ItemView.BELT_SIZE)
		assert_bool(panel.get_theme_stylebox("panel") is StyleBoxEmpty).is_true()
		var mat: TextureRect = RowStrip.mat(panel)
		assert_bool(RowStrip.shows_empty_mat(panel)).is_true()
		assert_that(mat.get_global_rect()).is_equal(_in_cell(cell, RowStrip.TICKET_RECT))
		assert_object(mat.texture).is_same(RowStrip.TICKET_EMPTY)
		assert_vector(Vector2(mat.texture.get_size())).is_equal(RowStrip.TICKET_RECT.size)
		assert_bool(mat.has_meta(ArtStyle.PIXEL_ART_META)).is_true()
		assert_int(mat.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_bool(RowStrip.ticket_shadow(panel).visible).is_false()
		var footprint: BeltFootprint = RowStrip.footprint(panel)
		assert_bool(footprint.visible).is_true()
		assert_that(footprint.get_global_rect()).is_equal(_in_cell(cell, RowStrip.FOOTPRINT_RECT))
		assert_float(footprint.get_global_rect().end.y).is_less_equal(
			mat.get_global_rect().position.y
		)
		assert_int(footprint.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		var number: Label = RowStrip.slot_number(panel)
		assert_bool(number.visible).is_true()
		assert_str(number.text).is_equal(str(slot + 1))
		assert_that(number.get_global_rect()).is_equal(_in_cell(cell, RowStrip.NUMBER_RECT))
		assert_bool(mat.get_global_rect().encloses(number.get_global_rect())).is_true()
		assert_float(number.get_minimum_size().y).is_less_equal(number.size.y)
		assert_object(number.get_theme_font("font")).is_same(ArtStyle.number_font())
		assert_int(number.get_theme_font_size("font_size")).is_equal(RowStrip.NUMBER_SIZE)
		assert_that(number.get_theme_color("font_color")).is_equal(RowStrip.NUMBER_COLOR)
		assert_bool(strip.is_outlined(slot)).is_false()
		assert_bool(RowStrip.is_hovered(panel)).is_false()
		if slot > 0:
			var gap: float = cell.position.x - strip.slots[slot - 1].get_global_rect().end.x
			assert_float(gap).is_equal(float(RowStrip.SEPARATION))


## A card stands on the belt as a belt item filling the cell: the sprite above the ticket's place,
## the payout plaque over the sprite inside the cell, the sticker on the ticket's place; the
## footprint, the blank ticket and the number hide. Emptied again, they show.
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
		assert_bool(RowStrip.footprint(panel).visible).is_equal(not filled)
		assert_bool(RowStrip.ticket_shadow(panel).visible).is_equal(filled)
		assert_bool(RowStrip.slot_number(panel).visible).is_equal(not filled)
		if not filled:
			continue
		var item: ItemView = views[slot] as ItemView
		assert_object(item).is_not_null()
		assert_int(item.form).is_equal(ItemView.Form.BELT)
		assert_object(item.get_parent()).is_same(panel)
		var cell: Rect2 = panel.get_global_rect()
		assert_that(item.get_global_rect()).is_equal(cell)
		var ticket: Rect2 = RowStrip.mat(panel).get_global_rect()
		var sprite: Rect2 = item.body.get_global_rect()
		assert_float(sprite.end.y).override_failure_message(str(sprite)).is_less_equal(
			ticket.position.y
		)
		# The count-up's paid chip (#80, step 7): in the cell's column, over the art's top.
		item.show_badge(12, false)
		var face: Rect2 = (item.badge as PayoutPlaque).face().get_global_rect()
		assert_float(face.position.x).is_greater_equal(cell.position.x)
		assert_float(face.end.x).is_less_equal(cell.end.x)
		assert_float(face.end.y).is_less_equal(cell.position.y + item._art_top() + 0.01)
		var sticker: Rect2 = item.sticker().get_global_rect()
		assert_that(sticker).is_equal(ticket)
		assert_bool(cell.encloses(sticker)).is_true()
		# The ticket's shadow falls down and right of it, under the item, inside the cell.
		var shadow: ColorRect = RowStrip.ticket_shadow(panel)
		var offset: Vector2 = RowStrip.TICKET_SHADOW_OFFSET
		assert_that(shadow.get_global_rect()).is_equal(Rect2(ticket.position + offset, ticket.size))
		assert_bool(cell.encloses(shadow.get_global_rect())).is_true()
		assert_float(shadow.color.a).is_equal_approx(RowStrip.TICKET_SHADOW_ALPHA, 0.001)
		assert_int(shadow.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	strip.show_cards([] as Array[CardInstance], -1, _ignore, load(BALANCE))
	for slot: int in range(7):
		assert_bool(RowStrip.shows_empty_mat(strip.slots[slot])).is_true()
		assert_bool(RowStrip.slot_number(strip.slots[slot]).visible).is_true()
	# The items taken out are freed.
	await _frames(1)
	for panel: PanelContainer in strip.slots:
		for child: Node in panel.get_children():
			assert_bool(child is CardView).is_false()


## An empty slot's footprint lies on the belt's plane: its front edge is its rect's bottom edge,
## its back corners lie on the lines from the front ones to the belt's vanishing point, so a slot
## left of the stage's middle leans right and one right of it leans left (mock-up B2).
func test_the_footprint_recedes_to_the_vanishing_point() -> void:
	var strip: RowStrip = await _strip(7)
	# Built alone, the row stands as if at ShiftStage.ROW_POSITION.
	var stage_vanishing: Vector2 = BeltPanel.VANISHING_POINT
	var leans: Array[float] = []
	var previous: PackedVector2Array = PackedVector2Array()
	for slot: int in range(7):
		var footprint: BeltFootprint = RowStrip.footprint(strip.slots[slot])
		var corners: PackedVector2Array = footprint.outline()
		assert_int(corners.size()).is_equal(4)
		var size: Vector2 = footprint.size
		assert_vector(corners[3]).is_equal(Vector2(0, size.y))
		assert_vector(corners[2]).is_equal(size)
		assert_float(corners[0].y).is_equal(0.0)
		assert_float(corners[1].y).is_equal(0.0)
		var on_stage: Transform2D = (
			Transform2D(0.0, ShiftStage.ROW_POSITION - strip.global_position)
			* footprint.get_global_transform()
		)
		for pair: Vector2i in [Vector2i(0, 3), Vector2i(1, 2)]:
			var back: Vector2 = on_stage * corners[pair.x]
			var front: Vector2 = on_stage * corners[pair.y]
			# The sine of the angle between the edge and the line to the vanishing point.
			var sine: float = (back - front).normalized().cross(
				(stage_vanishing - front).normalized()
			)
			assert_float(absf(sine)).override_failure_message(str(slot)).is_less(0.0001)
		leans.append(corners[0].x)
		# The back edge is the front's width or narrower.
		assert_float(corners[1].x - corners[0].x).is_less_equal(size.x)
		# Clear of the previous slot's footprint, front and back.
		var outline: PackedVector2Array = on_stage * corners
		if not previous.is_empty():
			assert_float(outline[0].x).is_greater(previous[1].x)
			assert_float(outline[3].x).is_greater(previous[2].x)
		previous = outline
	assert_float(leans[0]).is_greater(0.0)
	assert_float(leans[6]).is_less(0.0)
	# On the belt's top face, above the ticket.
	var rect: Rect2 = RowStrip.FOOTPRINT_RECT
	var face_top: float = ShiftStage.COUNTER_TOP - ShiftStage.ROW_POSITION.y
	assert_float(rect.position.y).is_greater_equal(face_top)
	assert_float(rect.end.y).is_less_equal(RowStrip.TICKET_RECT.position.y)


## An open slot takes clicks and drops only on its footprint and its ticket: its drop target
## (DROP_RECT, the two merged) is the one control in the cell that stops the mouse, and a click on
## it is the slot's input. The cell's band above the footprint takes no click.
func test_the_drop_target_covers_the_footprint_and_the_ticket() -> void:
	var strip: RowStrip = await _strip(7)
	assert_that(RowStrip.DROP_RECT).is_equal(RowStrip.FOOTPRINT_RECT.merge(RowStrip.TICKET_RECT))
	var inputs: Array[int] = []
	strip.slot_input.connect(func(_event: InputEvent, slot: int) -> void: inputs.append(slot))
	for slot: int in range(7):
		var panel: PanelContainer = strip.slots[slot]
		var cell: Rect2 = panel.get_global_rect()
		var target: Control = RowStrip.drop_target(panel)
		assert_that(target.get_global_rect()).is_equal(_in_cell(cell, RowStrip.DROP_RECT))
		assert_that(RowStrip.drop_rect(panel)).is_equal(target.get_global_rect())
		assert_bool(cell.encloses(target.get_global_rect())).is_true()
		assert_int(target.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
		var stops: Array[Control] = []
		_collect_stops(panel, stops)
		assert_array(stops).is_equal([target])
		var press: InputEventMouseButton = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		target.gui_input.emit(press)
	assert_array(inputs).is_equal([0, 1, 2, 3, 4, 5, 6])
	assert_that(RowStrip.drop_rect(strip.slots[0])).is_not_equal(Rect2())


## The tickets keep tomato for CLOSED alone (mock-up B2's colour rule): the product ticket's band
## is mustard light, the coupon ticket's teal dashes, the empty ticket steel and paper, and the
## CLOSED plate ink with a tomato band.
func test_only_the_closed_plate_is_tomato() -> void:
	var tomato: Array[String] = [
		Palette.TOMATO.to_html(false),
		Palette.TOMATO_DARK.to_html(false),
		Palette.TOMATO_LIGHT.to_html(false),
	]
	var tickets: Dictionary[Texture2D, bool] = {
		PriceSticker.FRAME: false,
		PriceSticker.COUPON_FRAME: false,
		RowStrip.TICKET_EMPTY: false,
		RowStrip.TICKET_CLOSED: true,
	}
	for texture: Texture2D in tickets:
		var image: Image = texture.get_image()
		var found: bool = false
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a > 0.0 and tomato.has(pixel.to_html(false)):
					found = true
		assert_bool(found).override_failure_message(texture.resource_path).is_equal(
			tickets[texture]
		)
	var band: Color = PriceSticker.FRAME.get_image().get_pixel(8, 3)
	assert_str(band.to_html(false)).is_equal(Palette.MUSTARD_LIGHT.to_html(false))


## The placeable ring's art: solid mustard between an ink line outside and one inside, so it
## reads on the steel rail.
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
	# The middle stays clear, so the ticket shows through.
	assert_float(image.get_pixel(floori(image.get_width() / 2.0), middle).a).is_equal(0.0)


## The ring marks the slots up to placeable_until, filled or not: one art pixel around the
## ticket, inside the cell, over the ticket and under the item (whose plaque and sprite stay
## whole).
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


## The landing fill covers an empty ticket only (an item there is tinted by CardDrag instead).
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


## CLOSED: no ticket, footprint or drop target, two stanchions standing on the belt behind the
## items' foot (each the post art's top region over its foot region, as tall as POST_RECTS, the
## right one mirrored) with their contact shadows, the velvet rope hooked over them at its art's
## size, and on the rail the ink plate (ticket_closed, drawn behind the word over its shadow)
## with CLOSED on its top and the caption under it, the tooltip and the click signal. Nothing in
## the cell takes the click from the cell.
func test_a_closed_slot_shows_the_rope_and_the_sign() -> void:
	var strip: RowStrip = await _strip(
		6, 1, "Closed by the inspection: Short belt", RowStrip.CLOSED_CAPTION_TEXT
	)
	assert_int(strip.closed.size()).is_equal(1)
	var panel: PanelContainer = strip.closed[0]
	assert_object(RowStrip.mat(panel)).is_null()
	assert_object(RowStrip.drop_target(panel)).is_null()
	assert_that(RowStrip.drop_rect(panel)).is_equal(Rect2())
	assert_bool(RowStrip.shows_empty_mat(panel)).is_false()
	assert_bool(panel.get_theme_stylebox("panel") is StyleBoxEmpty).is_true()
	assert_str(panel.tooltip_text).contains("Short belt")
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var cell: Rect2 = panel.get_global_rect()
	assert_vector(cell.size).is_equal(ItemView.BELT_SIZE)
	var label: Label = panel.get_child(0) as Label
	assert_str(label.text).is_equal(RowStrip.CLOSED_TEXT)
	assert_object(label.material).is_null()
	var plate: Panel = label.get_node(NodePath(RowStrip.PLATE_NAME)) as Panel
	assert_bool(plate.show_behind_parent).is_true()
	assert_that(plate.get_global_rect()).is_equal(_in_cell(cell, RowStrip.CLOSED_PLATE_RECT))
	var face: StyleBoxTexture = plate.get_theme_stylebox("panel") as StyleBoxTexture
	assert_object(face.texture).is_same(RowStrip.TICKET_CLOSED)
	assert_object(plate.material).is_same(ArtStyle.pixel_material())
	var plate_shadow: ColorRect = label.get_node(NodePath(RowStrip.PLATE_SHADOW_NAME)) as ColorRect
	assert_bool(plate_shadow.show_behind_parent).is_true()
	assert_int(plate_shadow.get_index()).is_less(plate.get_index())
	assert_vector(plate_shadow.get_global_rect().position).is_equal(
		plate.get_global_rect().position + RowStrip.TICKET_SHADOW_OFFSET
	)
	var sign_area: Control = label.get_node(NodePath(RowStrip.SIGN_NAME)) as Control
	assert_that(sign_area.get_global_rect()).is_equal(_in_cell(cell, RowStrip.CLOSED_SIGN_RECT))
	assert_bool(plate.get_global_rect().encloses(sign_area.get_global_rect())).is_true()
	# The word fits the sign.
	var font: Font = label.get_theme_font("font")
	var word: Vector2 = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
	)
	assert_float(word.x).is_less_equal(RowStrip.CLOSED_SIGN_RECT.size.x - 8.0)
	assert_float(word.y).is_less_equal(RowStrip.CLOSED_SIGN_RECT.size.y)
	# The stanchions: each the post art's two regions at their size (never stretched), stacked to
	# the post's height, inside the cell; their feet on the belt behind the items' foot.
	var foot_y: float = ItemView.BELT_SPRITE.y + ItemView.SPRITE_SIZE.y
	var parts: Array[TextureRect] = []
	for index: int in range(2):
		var post: Control = label.get_node("Post%d" % index) as Control
		var post_rect: Rect2 = post.get_global_rect()
		assert_that(post_rect).is_equal(_in_cell(cell, RowStrip.POST_RECTS[index]))
		assert_bool(cell.encloses(post_rect)).is_true()
		assert_float(post_rect.end.y - cell.position.y).is_less(foot_y)
		var top: TextureRect = post.get_node("Top") as TextureRect
		var foot: TextureRect = post.get_node("Foot") as TextureRect
		var regions: Array[Rect2] = [RowStrip.POST_TOP_REGION, RowStrip.POST_FOOT_REGION]
		var pair: Array[TextureRect] = [top, foot]
		for part_index: int in range(2):
			var part: TextureRect = pair[part_index]
			var atlas: AtlasTexture = part.texture as AtlasTexture
			assert_object(atlas.atlas).is_same(RowStrip.ROPE_POST)
			assert_that(atlas.region).is_equal(regions[part_index])
			assert_vector(part.size).is_equal(atlas.region.size)
			assert_bool(part.flip_h).is_equal(index == 1)
			parts.append(part)
		assert_float(top.get_global_rect().position.y).is_equal(post_rect.position.y)
		assert_float(foot.get_global_rect().end.y).is_equal(post_rect.end.y)
		assert_float(foot.get_global_rect().position.y).is_equal(top.get_global_rect().end.y)
		var shadow: ContactShadow = label.get_node("PostShadow%d" % index) as ContactShadow
		var shadow_rect: Rect2 = shadow.get_global_rect()
		assert_that(shadow_rect).is_equal(_in_cell(cell, RowStrip.POST_SHADOW_RECTS[index]))
		assert_bool(shadow_rect.intersects(foot.get_global_rect())).is_true()
		assert_float(shadow_rect.get_center().x).is_greater(post_rect.get_center().x)
		assert_int(shadow.get_index()).is_less(post.get_index())
	var rope: TextureRect = label.get_node("Rope") as TextureRect
	assert_object(rope.texture).is_same(RowStrip.VELVET_ROPE)
	assert_vector(rope.size).is_equal(Vector2(rope.texture.get_size()))
	assert_that(rope.get_global_rect()).is_equal(_in_cell(cell, RowStrip.ROPE_RECT))
	assert_bool(cell.encloses(rope.get_global_rect())).is_true()
	parts.append(rope)
	for part: TextureRect in parts:
		assert_bool(part.has_meta(ArtStyle.PIXEL_ART_META)).is_true()
	var caption: Label = RowStrip.closed_caption_label(panel)
	assert_str(caption.text).is_equal(RowStrip.CLOSED_CAPTION_TEXT)
	assert_that(caption.get_global_rect()).is_equal(_in_cell(cell, RowStrip.CLOSED_CAPTION_RECT))
	assert_float(caption.get_global_rect().position.y).is_greater_equal(
		parts[1].get_global_rect().end.y
	)
	assert_bool(plate.get_global_rect().encloses(caption.get_global_rect())).is_true()
	var stops: Array[Control] = []
	_collect_stops(label, stops)
	assert_array(stops).is_empty()
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


## The caption says "inspection" when an inspection closes slots (from data), and fits the
## caption's rect (two lines at most), for each one and for all of them together.
func test_every_closed_caption_fits() -> void:
	var closing: Array[InspectionDefinition] = []
	for file_name: String in DirAccess.get_files_at(INSPECTIONS):
		if not file_name.ends_with(".tres"):
			continue
		var inspection: InspectionDefinition = load(INSPECTIONS.path_join(file_name))
		var caption: String = RowStrip.closed_caption([inspection])
		if inspection.extra_slots < 0 or inspection.extra_coupon_slots < 0:
			assert_str(caption).is_equal(RowStrip.CLOSED_CAPTION_TEXT)
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
		# The caption's lines sit CLOSED_CAPTION_LINE_SPACING closer than the font's.
		var lines: int = roundi(needed.y / font.get_height(RowStrip.CLOSED_CAPTION_SIZE))
		needed.y += RowStrip.CLOSED_CAPTION_LINE_SPACING * (lines - 1)
		(
			assert_bool(needed.x <= width and needed.y <= RowStrip.CLOSED_CAPTION_RECT.size.y)
			. override_failure_message("%s needs %s" % [caption, needed])
			. is_true()
		)


## Plan 3.8: the 7 slots fill the belt at pitch 128 unscaled; 8 or 9 slots close their gaps,
## then scale to the 7-slot width, their cells touching but never overlapping, each item's
## sprite above its ticket and its plaque and chips in its cell, and the sticker's summary still at
## least MIN_SUMMARY_PX tall on screen. A closed slot never rescales the row (plan 3.9), since
## the row keeps its usual cell count.
func test_wide_rows_close_their_gaps_then_scale() -> void:
	var seven: RowStrip = await _strip(7)
	assert_vector(seven.box.scale).is_equal(Vector2.ONE)
	assert_float(seven.box.get_global_rect().size.x).is_equal(RowStrip.row_width(7))
	assert_float(RowStrip.row_width(7)).is_equal(884.0)
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
			item.show_mark(true)
			var cell: Rect2 = strip.slots[slot].get_global_rect()
			var message: String = "%d slots, cell %d" % [count, slot]
			if slot > 0:
				assert_float(cell.position.x).is_greater_equal(previous.end.x - 0.01)
			previous = cell
			var mat: Rect2 = RowStrip.mat(strip.slots[slot]).get_global_rect()
			var sprite: Rect2 = item.body.get_global_rect()
			assert_float(sprite.end.y).override_failure_message(message).is_less_equal(
				mat.position.y
			)
			var parts: Array[Control] = [item._mark, item.sticker()]
			for part: Control in parts:
				var rect: Rect2 = part.get_global_rect()
				(
					assert_bool(cell.grow(0.01).encloses(rect))
					. override_failure_message("%s: %s" % [message, rect])
					. is_true()
				)
			# The paid chip stays in its cell's column (it rises over the cell's top).
			var face: Rect2 = (item.badge as PayoutPlaque).face().get_global_rect()
			assert_float(face.position.x).is_greater_equal(cell.position.x - 0.01)
			assert_float(face.end.x).is_less_equal(cell.end.x + 0.01)
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


## Every control under `node` (itself included) that stops the mouse.
static func _collect_stops(node: Node, stops: Array[Control]) -> void:
	var control: Control = node as Control
	if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		stops.append(control)
	for child: Node in node.get_children():
		_collect_stops(child, stops)


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
