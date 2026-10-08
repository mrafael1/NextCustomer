extends GdUnitTestSuite
## The art style frame (debug/style_frame): it lays out on its 1280x720 stage with nothing off
## screen or overlapping, scores its row through core/, opens Milk's sizes panel with the card
## at its size, and switches the sharp-pixel shader off and back on.

const SCENE := "res://debug/style_frame/style_frame.tscn"


func test_the_row_hand_and_receipt_lay_out_on_the_stage() -> void:
	var frame: StyleFrame = await _frame()
	var stage: Rect2 = frame._stage.get_global_rect()
	assert_vector(stage.size).is_equal(StyleFrame.STAGE_SIZE)
	var belt: Rect2 = frame._belt.get_global_rect()
	assert_bool(stage.encloses(belt)).is_true()
	assert_int(frame._row_views.size()).is_equal(StyleFrame.ROW_IDS.size())
	# One drawn hand: the row and the hand together hold hand_size cards.
	var drawn: int = StyleFrame.ROW_IDS.size() + StyleFrame.HAND_IDS.size()
	assert_int(drawn).is_equal(StyleFrame.BALANCE.hand_size)
	# The empty slots fill the row up to its capacity.
	assert_int(frame._row_box.get_child_count()).is_equal(RowCapacity.card_limit(frame._limits()))
	assert_float(frame._receipt.get_global_rect().size.x).is_equal(StyleFrame.RECEIPT_WIDTH)
	for view: CardView in frame._row_views:
		var card: Rect2 = view.body.get_global_rect()
		assert_vector(card.size).is_equal(ArtCardView.SIZE)
		assert_bool(belt.encloses(card)).override_failure_message(str(card)).is_true()
	var receipt: Rect2 = frame._receipt.get_global_rect()
	assert_bool(stage.encloses(receipt)).override_failure_message(str(receipt)).is_true()
	assert_bool(receipt.intersects(belt)).is_false()
	var checkout: Rect2 = frame._checkout_button.get_global_rect()
	assert_bool(checkout.intersects(receipt)).is_false()
	for view: Node in frame._hand_box.get_children():
		var card: Rect2 = (view as CardView).body.get_global_rect()
		assert_bool(stage.encloses(card)).override_failure_message(str(card)).is_true()
		assert_bool(card.intersects(receipt) or card.intersects(checkout)).is_false()


func test_the_top_bar_items_do_not_overlap() -> void:
	var frame: StyleFrame = await _frame()
	var stage: Rect2 = frame._stage.get_global_rect()
	var items: Array[Control] = []
	for child: Node in frame._stage.get_children():
		var control: Control = child as Control
		if (
			control != null
			and control.get_global_rect().end.y <= frame._belt.get_global_rect().position.y
		):
			items.append(control)
	assert_int(items.size()).is_greater_equal(4)
	for i: int in range(items.size()):
		var rect: Rect2 = items[i].get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		for j: int in range(i + 1, items.size()):
			(
				assert_bool(rect.intersects(items[j].get_global_rect()))
				. override_failure_message("%s overlaps %s" % [items[i], items[j]])
				. is_false()
			)


## The frame's numbers come from core/: the receipt and badges show Scoring.score's result.
func test_the_row_is_scored_by_core() -> void:
	var frame: StyleFrame = await _frame()
	var expected: ScoreResult = Scoring.score(frame._row, frame._upgrades(), frame._inspections())
	assert_int(frame._result.total).is_equal(expected.total)
	assert_str(frame._projected_label.text).is_equal("Projected €%d" % expected.total)
	for slot: int in range(frame._row_views.size()):
		assert_str(frame._row_views[slot].badge.text).is_equal(str(expected.payouts[slot]))


## Opened after being built hidden, the sizes panel's card keeps its size and sits inside the
## panel, which sits inside the screen.
func test_the_sizes_panel_fits() -> void:
	var frame: StyleFrame = await _frame()
	frame._show_sizes(true)
	for _tick: int in range(4):
		await get_tree().process_frame
	var panel: Rect2 = frame._sizes_panel.get_global_rect()
	(
		assert_bool(frame.get_viewport_rect().encloses(panel))
		. override_failure_message(str(panel))
		. is_true()
	)
	var cards: Array[Node] = frame._sizes_panel.find_children("*", "ArtCardView", true, false)
	assert_int(cards.size()).is_equal(1)
	var card: Rect2 = (cards[0] as CardView).body.get_global_rect()
	assert_vector(card.size).is_equal(ArtCardView.SIZE)
	assert_bool(panel.encloses(card)).override_failure_message(str(card)).is_true()
	frame._show_sizes(false)
	assert_bool(frame._sizes_panel.visible).is_false()


## Text without its own font, like the count-up's flying numbers, uses the number font, and so
## do the frame's money labels.
func test_numbers_use_the_number_font() -> void:
	var frame: StyleFrame = await _frame()
	var label: Label = Label.new()
	frame._overlay.add_child(label)
	assert_object(label.get_theme_default_font()).is_same(ArtStyle.number_font())
	assert_object(frame._projected_label.get_theme_font("font")).is_same(ArtStyle.number_font())
	assert_object(frame._subtotal_label.get_theme_font("font")).is_same(ArtStyle.number_font())


func test_the_shader_switches_off_and_on() -> void:
	var frame: StyleFrame = await _frame()
	var marked: Array[CanvasItem] = _pixel_art(frame)
	assert_int(marked.size()).is_greater(10)
	frame._set_sharp(false)
	for item: CanvasItem in marked:
		assert_object(item.material).is_null()
		assert_int(item.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	frame._set_sharp(true)
	for item: CanvasItem in marked:
		assert_object(item.material).is_same(ArtStyle.pixel_material())


func _frame() -> StyleFrame:
	var frame: StyleFrame = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(frame)
	for _tick: int in range(4):
		await get_tree().process_frame
	return frame


static func _pixel_art(node: Node) -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	var item: CanvasItem = node as CanvasItem
	if item != null and item.has_meta(ArtStyle.PIXEL_ART_META):
		result.append(item)
	for child: Node in node.get_children():
		result.append_array(_pixel_art(child))
	return result
