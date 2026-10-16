extends GdUnitTestSuite
## Style frame v2's round-2 props (debug/style_frame_v2, #75; the delta file): which mat stands in
## each belt cell (following core's capacity counts), the mats and their engraved numbers, the
## CLOSED cell and its inspection's name, the purse (#76) that opens only while counting, and the
## TOTAL key that is down only while counting, and the belt's valance (round 3) above the mats.
## Layout, numbers and the scanner are in style_frame_v2_test.gd.

const SCENE := "res://debug/style_frame_v2/style_frame_v2.tscn"
const STAGE := Rect2(0, 0, 1280, 720)
const STATES: Array[StyleFrameV2.State] = [
	StyleFrameV2.State.PLANNING,
	StyleFrameV2.State.COUNT_UP,
	StyleFrameV2.State.SCAN,
	StyleFrameV2.State.SCAN_BELT,
]


## Which mat stands in each belt cell follows core's capacity counts (delta section 3).
func test_mat_kinds_follow_the_row_and_the_limits() -> void:
	var product: int = BeltView.MatKind.PRODUCT
	var coupon: int = BeltView.MatKind.COUPON
	var closed: int = BeltView.MatKind.CLOSED
	var limits: ShiftLimits = StyleFrameFixture.limits()
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.PLANNING)
	var planning: Array[int] = [product, product, product, coupon, product, product, closed]
	assert_array(BeltView.mat_kinds(limits, _row(frame))).is_equal(planning)
	frame = await _frame(StyleFrameV2.State.COUNT_UP)
	var counting: Array[int] = [product, product, product, product, coupon, product, closed]
	assert_array(BeltView.mat_kinds(limits, _row(frame))).is_equal(counting)
	var empty: Array[CardInstance] = []
	var none: Array[int] = [product, product, product, product, product, coupon, closed]
	assert_array(BeltView.mat_kinds(limits, empty)).is_equal(none)
	var products: Array[CardInstance] = []
	for card_id: String in ["cheese", "strawberries", "croissant", "coffee", "banana"]:
		products.append(CardInstance.new(StyleFrameFixture.card(card_id), products.size() + 1))
	var full: Array[int] = [product, product, product, product, product, coupon, closed]
	assert_array(BeltView.mat_kinds(limits, products)).is_equal(full)
	var coupon_closed: ShiftLimits = ShiftLimits.new()
	coupon_closed.slot_count = 5
	coupon_closed.coupon_slot_count = 0
	coupon_closed.closed_coupon_slots = 1
	var kinds: Array[int] = BeltView.mat_kinds(coupon_closed, products)
	assert_int(kinds.size()).is_equal(6)
	assert_int(kinds[kinds.size() - 1]).is_equal(BeltView.MatKind.CLOSED_COUPON)


## Every open cell has its mat (the coupon slot's gold perforated one under the coupon room's
## coupon); the empty mats show their engraved numbers; the CLOSED cell has no mat.
func test_every_open_cell_has_its_mat() -> void:
	for state: StyleFrameV2.State in [StyleFrameV2.State.PLANNING, StyleFrameV2.State.COUNT_UP]:
		var frame: StyleFrameV2 = await _frame(state)
		var row: Array[CardInstance] = _row(frame)
		var kinds: Array[int] = BeltView.mat_kinds(StyleFrameFixture.limits(), row)
		var mats: Array[Panel] = frame.belt().mats()
		assert_int(mats.size()).is_equal(kinds.size())
		for cell: int in range(kinds.size()):
			if kinds[cell] == BeltView.MatKind.CLOSED:
				assert_object(mats[cell]).is_null()
				continue
			var coupon: bool = kinds[cell] == BeltView.MatKind.COUPON
			var product_mat: Texture2D = (
				BeltView.SLOT_MAT if cell < row.size() else BeltView.SLOT_MAT_EMPTY
			)
			assert_object(BeltView.mat_texture(mats[cell])).is_same(
				BeltView.SLOT_MAT_COUPON if coupon else product_mat
			)
			var number: Label = mats[cell].find_child("SlotNumber", false, false) as Label
			if cell < row.size():
				assert_object(number).is_null()
			else:
				assert_str(number.text).is_equal(str(cell + 1))
	var planning: StyleFrameV2 = await _frame(StyleFrameV2.State.PLANNING)
	var numbers: PackedStringArray = PackedStringArray()
	for mat: Panel in planning.belt().mats():
		if mat == null:
			continue
		var number: Label = mat.find_child("SlotNumber", false, false) as Label
		if number != null:
			numbers.append(number.text)
	assert_array(numbers).is_equal(PackedStringArray(["5", "6"]))


## The CLOSED cell: a rope on two posts with the CLOSED sign and the closing inspection's name,
## all inside its cell.
func test_the_closed_cell_names_its_inspection() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		var closed: Array[Control] = frame.belt().closed_cells()
		assert_int(closed.size()).is_equal(StyleFrameFixture.limits().closed_slots)
		var cell: Control = closed[0]
		var origin: Vector2 = StyleFrameV2.CELL_ORIGIN + Vector2(6 * StyleFrameV2.CELL_PITCH, 0)
		var cell_rect: Rect2 = Rect2(origin, ItemView.BELT_SIZE)
		assert_bool(_rect(frame, cell) == cell_rect).is_true()
		var sign_panel: Control = cell.get_node("ClosedSign") as Control
		assert_str((sign_panel.get_child(0) as Label).text).is_equal(BeltView.CLOSED_TEXT)
		var caption: Label = cell.get_node("ClosedCaption") as Label
		assert_str(caption.text).is_equal(StyleFrameFixture.inspections()[0].display_name)
		for part: String in ["Post0", "Post1", "Rope", "ClosedSign", "ClosedCaption"]:
			var rect: Rect2 = _rect(frame, cell.get_node(part) as Control)
			assert_bool(cell_rect.encloses(rect)).override_failure_message(part).is_true()


## A closed coupon slot: its coupon mat shows faintly under the rope, and the CLOSED cell names
## the inspection that closed it.
func test_a_closed_coupon_slot_keeps_its_faint_mat() -> void:
	var belt: BeltView = auto_free(BeltView.new()) as BeltView
	belt.position = StyleFrameV2.BELT_RECT.position
	belt.size = StyleFrameV2.BELT_RECT.size
	add_child(belt)
	var kinds: Array[int] = [BeltView.MatKind.PRODUCT, BeltView.MatKind.CLOSED_COUPON]
	var grounds: Array[Control] = belt.lay_out(kinds, 0, "A", "B")
	assert_int(grounds.size()).is_equal(2)
	var mats: Array[Panel] = belt.mats()
	assert_object(BeltView.mat_texture(mats[0])).is_same(BeltView.SLOT_MAT_EMPTY)
	assert_object(BeltView.mat_texture(mats[1])).is_same(BeltView.SLOT_MAT_COUPON)
	assert_float(mats[1].modulate.a).is_equal_approx(BeltView.CLOSED_MAT_ALPHA, 0.001)
	var closed: Array[Control] = belt.closed_cells()
	assert_int(closed.size()).is_equal(1)
	assert_object(grounds[1]).is_same(closed[0])
	assert_str((closed[0].get_node("ClosedCaption") as Label).text).is_equal("B")
	assert_bool(closed[0].position == belt.cell_origin(1)).is_true()
	assert_bool(closed[0].size == ItemView.BELT_SIZE).is_true()


## Every fixture card has its round-2 art: each product its own 48x48 item (shown at 2x, so its
## pixels match the frames'), each coupon the shared slip with its own 20x14 icon.
func test_every_card_has_its_48x48_art() -> void:
	for card_id: String in StyleFrameFixture.card_ids():
		var definition: CardDefinition = StyleFrameFixture.card(card_id)
		var texture: Texture2D = ItemView.sprite_texture(definition)
		assert_object(texture).override_failure_message(card_id).is_not_null()
		var size: Vector2 = texture.get_size()
		assert_bool(size == Vector2(48, 48)).override_failure_message(card_id).is_true()
		assert_bool(ItemView.SPRITE_SIZE == size * ArtStyle.ART_SCALE).is_true()
		if definition.is_coupon():
			assert_object(texture).is_same(ItemView.COUPON_SLIP)
			var icon: Texture2D = ItemView.icon_texture(definition)
			assert_object(icon).override_failure_message(card_id).is_not_null()
			var icon_size: Vector2 = icon.get_size()
			assert_bool(icon_size == Vector2(20, 14)).override_failure_message(card_id).is_true()
		else:
			assert_str(texture.resource_path).is_equal(ItemView.ITEM_PATH % definition.id)


## The purse (#76): shut outside the count-up, open while counting; no text, no number.
func test_the_purse_opens_only_while_counting() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		var purse: TextureRect = frame.purse()
		var counting: bool = state == StyleFrameV2.State.COUNT_UP
		assert_object(purse.texture).is_same(
			StyleFrameV2.PURSE_OPEN if counting else StyleFrameV2.PURSE_CLOSED
		)
		assert_bool(_rect(frame, purse) == StyleFrameV2.PURSE_RECT).is_true()
		assert_array(purse.find_children("*", "Label", true, false)).is_empty()


## The TOTAL key is down only while counting (CHECKOUT was just pressed).
func test_the_total_key_is_down_while_counting() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		var register: RegisterView = frame.register()
		assert_bool(register.is_total_down()).is_equal(state == StyleFrameV2.State.COUNT_UP)
		assert_str(register.total_label().text).is_equal(RegisterView.TOTAL_TEXT)
		var key: Rect2 = _rect(frame, register.total_key())
		assert_bool(key.encloses(_rect(frame, register.total_label()))).is_true()


## The belt's valance (round 3) hangs across the belt's top edge in the stage, its fringe above
## every mat, CLOSED cell's part and belt sprite, and every plaque draws over its braid.
func test_the_valance_hangs_above_the_mats() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		var valance: Control = frame.stage().get_node("Valance") as Control
		var rect: Rect2 = _rect(frame, valance)
		(
			assert_bool(rect == BoutiqueDecor.VALANCE_RECT)
			. override_failure_message(str(rect))
			. is_true()
		)
		assert_bool(STAGE.encloses(rect)).is_true()
		var belt: Rect2 = StyleFrameV2.BELT_RECT
		assert_float(rect.position.x).is_greater_equal(belt.position.x)
		assert_float(rect.end.x).is_less_equal(belt.end.x)
		var below: Array[Control] = []
		for mat: Panel in frame.belt().mats():
			if mat != null:
				below.append(mat)
		# A CLOSED cell's parts (its posts, rope, sign and caption); the cell itself is bare belt.
		for closed: Control in frame.belt().closed_cells():
			for part: Node in closed.get_children():
				below.append(part as Control)
		for view: ItemView in frame.item_views(true):
			below.append(view.sprite())
		assert_int(below.size()).is_greater(6)
		for part: Control in below:
			var top: float = _rect(frame, part).position.y
			(
				assert_float(rect.end.y)
				. override_failure_message("%s: %s at %s" % [state, part.get_path(), top])
				. is_less_equal(top)
			)
		for view: ItemView in frame.item_views(true):
			if view.plaque() == null:
				continue
			# The plaque draws over the braid: its item comes after the valance on the stage.
			var item: Node = view
			while item.get_parent() != frame.stage():
				item = item.get_parent()
			assert_int(item.get_index()).is_greater(valance.get_index())


# --- Helpers ---------------------------------------------------------------------------------


func _frame(state: StyleFrameV2.State) -> StyleFrameV2:
	var runner: GdUnitSceneRunner = scene_runner(SCENE)
	var frame: StyleFrameV2 = runner.scene() as StyleFrameV2
	frame.show_state(state)
	for _index: int in range(3):
		await get_tree().process_frame
	return frame


## `control`'s rect in stage coordinates.
static func _rect(frame: StyleFrameV2, control: Control) -> Rect2:
	var origin: Vector2 = frame.stage().get_global_rect().position
	var rect: Rect2 = control.get_global_rect()
	return Rect2(rect.position - origin, rect.size)


## The belt's row, from its items.
static func _row(frame: StyleFrameV2) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for view: ItemView in frame.item_views(true):
		row.append(view.card)
	return row
