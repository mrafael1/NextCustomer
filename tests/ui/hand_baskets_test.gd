extends GdUnitTestSuite
## The hand in its baskets (#80, mock-up B2, step 8) on the real screen: a hand of hand_size 8
## fills four baskets at HandRow.BASKET_PITCH, two items each in hand order, none overlapping;
## each item's art sinks about a third under its basket's front rim; the ledge, the baskets'
## backs and fronts and every item (lifted or not, with its REDRAW flag or selected outline) stay
## in the ledge band (from the hand's top, down to the ledge's foot, right of the register);
## baskets stay when items leave for the belt; more than 8 items (debug) add baskets and narrow
## the basket step, and then hover brings an item to the front so it takes the click; a selected
## item lifts with a mustard outline, a redraw-marked one dims under its REDRAW flag; a full hand
## clears the keys, the hint and the receipt; the drag ghost is centred on the mouse; clearing a
## hovered hand reorders nothing. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## hand_size 8 gives four baskets at the natural pitch from HAND_RECT's left edge, their backs and
## fronts drawn there (a left inner wall left of the stage's centre, else a right one); each item
## is a BASKET item in the left or right half of basket index / 2, apart from the others; its
## art's foot is inside the basket, under the front rim by about a third of its visible height
## (a coupon's slip rides BASKET_COUPON_RISE higher); and everything stays in the ledge band.
func test_a_hand_of_eight_fills_four_baskets() -> void:
	var screen: ShiftScreen = await _screen()
	assert_int(screen.run.balance.hand_size).is_equal(8)
	var stage: ShiftStage = screen._stage
	var hand: HandRow = screen._hand_box
	assert_int(hand.basket_count()).is_equal(4)
	assert_bool(hand.overlaps()).is_false()
	var lefts: Array[float] = stage.baskets.basket_lefts()
	assert_int(lefts.size()).is_equal(4)
	assert_array(stage.basket_fronts.basket_lefts()).is_equal(lefts)
	for index: int in range(lefts.size()):
		var expected: float = ShiftStage.HAND_RECT.position.x + index * HandRow.BASKET_PITCH
		assert_float(lefts[index]).is_equal(expected)
	var last: Rect2 = stage.baskets.basket_rect(3)
	assert_float(last.end.x).is_equal(ShiftStage.HAND_RECT.end.x)
	var backs: Array[Texture2D] = []
	for part: Control in stage.baskets.parts():
		if part.name.begins_with(HandBaskets.BACK_NAME):
			backs.append((part as TextureRect).texture)
	assert_array(backs).is_equal(
		[
			HandBaskets.BACK_LEFT,
			HandBaskets.BACK_RIGHT,
			HandBaskets.BACK_RIGHT,
			HandBaskets.BACK_RIGHT
		]
	)
	# The ledge's floor shadow lies under the ledge, clear of the register (#83's mirror).
	var ledge: Rect2 = ShiftStage.LEDGE_RECT
	assert_float(HandBaskets.LEDGE_SHADOW.position.y).is_equal(ledge.end.y)
	assert_float(HandBaskets.LEDGE_SHADOW.position.x).is_greater_equal(ledge.position.x)
	assert_float(HandBaskets.LEDGE_SHADOW.end.x).is_less_equal(ledge.end.x)
	assert_bool(HandBaskets.LEDGE_SHADOW.intersects(ShiftStage.REGISTER_RECT)).is_false()
	var band: Rect2 = _ledge_band(screen)
	for layer: HandBaskets in [stage.baskets, stage.basket_fronts]:
		var parts: Array[Control] = layer.parts()
		assert_int(parts.size()).is_greater_equal(4)
		for part: Control in parts:
			var rect: Rect2 = part.get_global_rect()
			assert_bool(band.encloses(rect)).override_failure_message(str(part.name)).is_true()
	var fronts: Array[Rect2] = []
	for part: Control in stage.basket_fronts.parts():
		fronts.append(part.get_global_rect())
	_assert_rects_apart(fronts, "basket fronts")

	var views: Array[Control] = hand.cards()
	assert_int(views.size()).is_equal(8)
	var hits: Array[Rect2] = []
	var rim: float = _on_stage(screen, Rect2(0, HandBaskets.RIM_FRONT_Y, 0, 0)).position.y
	var face_foot: float = _on_stage(screen, Rect2(0, HandBaskets.FACE_FOOT_Y, 0, 0)).position.y
	for index: int in range(views.size()):
		var view: ItemView = views[index] as ItemView
		var message: String = "%d %s" % [index, view.card.definition.id]
		assert_int(view.form).is_equal(ItemView.Form.BASKET)
		assert_vector(view.size).is_equal(ItemView.BASKET_SIZE)
		assert_bool(view.sticker().visible).is_false()
		var basket: Rect2 = _on_stage(screen, stage.baskets.basket_rect(floori(index / 2.0)))
		var offset: float = HandRow.ITEM_OFFSETS[index % 2]
		assert_float(view.get_global_rect().position.x).is_equal(basket.position.x + offset)
		var art: Rect2 = _art(view)
		assert_float(art.end.y).override_failure_message(message).is_greater(rim)
		assert_float(art.end.y).override_failure_message(message).is_less(face_foot)
		var sunk: float = art.end.y - rim
		if view.card.definition.is_coupon():
			sunk += ItemView.BASKET_COUPON_RISE
		assert_float(sunk).override_failure_message(message).is_equal_approx(
			art.size.y / 3.0, ArtStyle.ART_SCALE
		)
		assert_bool(band.encloses(art)).override_failure_message(message).is_true()
		var lifted: Rect2 = Rect2(art.position - Vector2(0, ItemView.BASKET_LIFT), art.size)
		assert_bool(band.encloses(lifted)).override_failure_message(message).is_true()
		hits.append(view.get_global_transform() * view.hit_rect())
	_assert_rects_apart(hits, "hand items")


## Items placed on the belt leave their baskets empty, never fewer baskets: the hand that is left
## fills the baskets from the first, in hand order.
func test_the_baskets_stay_when_items_leave() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	for slot: int in range(3):
		assert_bool(run.place(run.hand()[0], slot)).is_true()
	screen._refresh()
	await _frames(2)
	var views: Array[Control] = screen._hand_box.cards()
	assert_int(views.size()).is_equal(5)
	assert_int(screen._hand_box.basket_count()).is_equal(4)
	assert_int(screen._stage.baskets.basket_lefts().size()).is_equal(4)
	for index: int in range(views.size()):
		assert_object((views[index] as ItemView).card).is_same(run.hand()[index])
		var basket: Rect2 = screen._stage.baskets.basket_rect(floori(index / 2.0))
		assert_float(views[index].position.x + ShiftStage.HAND_RECT.position.x).is_equal(
			basket.position.x + HandRow.ITEM_OFFSETS[index % 2]
		)


## More items than hand_size fills (debug) add a basket per two items and narrow the basket step
## so they all still fit HAND_RECT; then the items overlap. 9 items take 5 baskets, as 10 do.
func test_more_than_eight_items_add_baskets() -> void:
	var screen: ShiftScreen = await _screen()
	var width: float = ShiftStage.HAND_RECT.size.x
	assert_float(HandRow.step_for(4, width)).is_equal(HandRow.BASKET_PITCH)
	assert_float(HandRow.step_for(5, width)).is_less(HandRow.BASKET_PITCH)
	for count: int in [9, 10]:
		screen._debug.add_card("bread")
		await _frames(2)
		var hand: HandRow = screen._hand_box
		assert_int(hand.cards().size()).is_equal(count)
		assert_int(hand.basket_count()).is_equal(5)
		assert_bool(hand.overlaps()).is_true()
		var lefts: Array[float] = screen._stage.basket_fronts.basket_lefts()
		assert_int(lefts.size()).is_equal(5)
		assert_float(lefts[1] - lefts[0]).is_less(HandRow.BASKET_PITCH)
		var row: Rect2 = _on_stage(screen, ShiftStage.HAND_RECT)
		var last: Rect2 = _on_stage(screen, screen._stage.baskets.basket_rect(4))
		assert_float(last.end.x).is_less_equal(row.end.x)
		var band: Rect2 = _ledge_band(screen)
		for view: Control in hand.cards():
			var item: ItemView = view as ItemView
			assert_float(view.get_global_rect().end.x).is_less_equal(row.end.x)
			assert_bool(band.encloses(_art(item))).is_true()


## Hovering an item brings it to the front by child order (clicks follow what is drawn on top)
## only while items overlap (more than 8); leaving it puts the hand order back. A full hand of 8
## keeps its order.
func test_hover_brings_an_item_to_the_front() -> void:
	var screen: ShiftScreen = await _screen()
	var views: Array[Control] = screen._hand_box.cards()
	views[3].mouse_entered.emit()
	assert_int(views[3].get_index()).is_equal(3)
	views[3].mouse_exited.emit()
	screen._debug.add_card("bread")
	await _frames(2)
	views = screen._hand_box.cards()
	var hovered: Control = views[3]
	hovered.mouse_entered.emit()
	assert_int(hovered.get_index()).is_equal(screen._hand_box.get_child_count() - 1)
	hovered.mouse_exited.emit()
	for index: int in range(views.size()):
		assert_int(views[index].get_index()).is_equal(index)


## In a hand of more than 8 (debug), hovering an item brings it to the front, so a click where its
## sprite overlaps the next basket's first item goes to the hovered item, the one drawn on top.
## Headless runs deliver no mouse input, so this follows Godot's own rule: a click goes to the
## last child (drawn on top) whose hit area (ItemView.hit_rect) is under the mouse and stops it.
func test_the_hovered_item_takes_the_click() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.add_card("bread")
	await _frames(2)
	var views: Array[Control] = screen._hand_box.cards()
	var hovered: ItemView = views[3] as ItemView
	var under: ItemView = views[4] as ItemView
	var hovered_hit: Rect2 = hovered.get_global_transform() * hovered.hit_rect()
	var under_hit: Rect2 = under.get_global_transform() * under.hit_rect()
	var overlap: Rect2 = hovered_hit.intersection(under_hit)
	assert_float(overlap.size.x).is_greater(0.0)
	var point: Vector2 = overlap.get_center()
	# Before the hover, the next item is on top where they overlap.
	assert_object(_card_at(screen._hand_box, point)).is_same(under)
	hovered.mouse_entered.emit()
	var top: CardView = _card_at(screen._hand_box, point) as CardView
	assert_object(top).is_same(hovered)
	top._gui_input(_button(point, true))
	assert_object(screen._picked).is_same(hovered.card)


## A selected item lifts by LIFT with a mustard outline one art pixel round its sprite and no gold
## brackets; in redraw mode a marked item dims to REDRAW_ALPHA under its REDRAW flag, centred over
## its sprite. The outline and the flags stay in the ledge band, under the rail, and the flags
## apart.
func test_the_selected_and_redraw_looks_in_a_basket() -> void:
	var screen: ShiftScreen = await _screen()
	var band: Rect2 = _ledge_band(screen)
	var view: ItemView = screen._hand_box.cards()[1] as ItemView
	var rest: Rect2 = view.sprite().get_global_rect()
	screen._on_hand_card_clicked(view)
	await _frames(2)
	var picked: ItemView = screen._hand_box.cards()[1] as ItemView
	assert_object(picked.card).is_same(screen._picked)
	var sprite: Rect2 = picked.sprite().get_global_rect()
	assert_float(sprite.position.y).is_equal(rest.position.y - ItemView.LIFT)
	assert_that(picked.brackets()).is_equal(Rect2())
	var outline: TextureRect = picked._outline
	assert_object(outline).is_not_null()
	assert_bool(outline.visible).is_true()
	assert_bool(outline.show_behind_parent).is_true()
	var pixel: float = ArtStyle.ART_SCALE
	assert_that(outline.get_global_rect()).is_equal(sprite.grow(pixel))
	assert_vector(outline.texture.get_size()).is_equal(
		picked.sprite().texture.get_size() + Vector2(2, 2)
	)
	var art: Rect2 = _art(picked).grow(pixel)
	assert_bool(band.encloses(art)).override_failure_message(str(art)).is_true()

	screen._drop_pick()
	screen._on_redraw_pressed()
	screen._on_hand_card_clicked(screen._hand_box.cards()[0] as CardView)
	screen._on_hand_card_clicked(screen._hand_box.cards()[1] as CardView)
	await _frames(2)
	var flags: Array[Rect2] = []
	for index: int in [0, 1]:
		var marked: ItemView = screen._hand_box.cards()[index] as ItemView
		assert_float(marked.body.modulate.a).is_equal_approx(ItemView.REDRAW_ALPHA, 0.001)
		var flag: Label = marked._redraw_mark
		assert_bool(flag.visible).is_true()
		var rect: Rect2 = flag.get_global_rect()
		assert_vector(rect.size).is_equal(ItemView.REDRAW_RECT.size)
		assert_float(flag.get_minimum_size().x).is_less_equal(rect.size.x)
		var centre: float = marked.sprite().get_global_rect().get_center().x
		assert_float(rect.get_center().x).is_equal_approx(centre, 0.5)
		assert_float(rect.position.y).is_less(_art(marked).position.y)
		assert_bool(band.encloses(rect)).override_failure_message(str(rect)).is_true()
		flags.append(rect)
	_assert_rects_apart(flags, "flags")
	assert_bool((screen._hand_box.cards()[2] as ItemView)._redraw_mark.visible).is_false()


## A full hand of 8 (with Cancel shown, in redraw mode) stays on the stage, clear of CHECKOUT,
## Redraw, Cancel, the rail and the receipt, even lifted with its outline.
func test_a_full_hand_clears_the_buttons_and_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_redraw_pressed()
	await _frames(2)
	assert_bool(screen._cancel_button.visible).is_true()
	var stage: Rect2 = screen._stage.get_global_rect()
	var blockers: Array[Control] = [
		screen._cancel_button,
		screen._redraw_button,
		screen._checkout_button,
		screen._receipt,
	]
	var rail: Rect2 = screen._stage.belt.get_global_transform() * screen._stage.belt.rail()
	var views: Array[Control] = screen._hand_box.cards()
	assert_int(views.size()).is_equal(screen.run.balance.hand_size)
	for view: Control in views:
		var item: ItemView = view as ItemView
		var art: Rect2 = _art(item)
		var lifted: Rect2 = Rect2(art.position - Vector2(0, ItemView.BASKET_LIFT), art.size)
		var rect: Rect2 = lifted.grow(ArtStyle.ART_SCALE)
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(rect.intersects(rail)).is_false()
		for blocker: Control in blockers:
			(
				assert_bool(rect.intersects(blocker.get_global_rect()))
				. override_failure_message("%s overlaps %s" % [rect, blocker])
				. is_false()
			)


## A dragged item's ghost is its sprite alone (an ItemView in the GHOST form, SPRITE_SIZE, no
## sticker), centred on the mouse, wherever in its basket the item stood.
func test_the_drag_ghost_is_centred_on_the_mouse() -> void:
	var screen: ShiftScreen = await _screen()
	var view: ItemView = screen._hand_box.cards()[2] as ItemView
	var card: CardInstance = view.card
	var start: Vector2 = view.sprite().get_global_rect().get_center()
	screen._on_hand_card_clicked(view)
	assert_object(screen._picked).is_same(card)
	var target: Vector2 = start + Vector2(37, -151)
	screen._drag._input(_motion(target, MOUSE_BUTTON_MASK_LEFT))
	var ghost: ItemView = screen._drag._ghost
	assert_object(ghost).is_not_null()
	assert_int(ghost.form).is_equal(ItemView.Form.GHOST)
	assert_object(ghost.card).is_same(card)
	assert_vector(ghost.size).is_equal(ItemView.SPRITE_SIZE)
	assert_bool(ghost.sticker().visible).is_false()
	assert_vector(ghost.get_global_rect().get_center()).is_equal_approx(target, Vector2(1, 1))
	# The tilted, enlarged sprite turns about its centre, so it stays centred too.
	var body_center: Vector2 = ghost.body.get_global_transform() * (ItemView.SPRITE_SIZE / 2.0)
	assert_vector(body_center).is_equal_approx(target, Vector2(1, 1))
	screen._drag.cancel()


## Clearing the hand under the mouse: the hovered card's mouse_exited, sent while it leaves the
## tree, must not reorder the hand mid-removal (Godot would print a move_child error, which
## fails the run). Headless runs have no mouse, so the card sends it as a real mouse would.
func test_clearing_a_hovered_hand_reorders_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	var hovered: Control = screen._hand_box.cards()[2]
	hovered.mouse_entered.emit()
	hovered.tree_exiting.connect(hovered.mouse_exited.emit)
	screen._hand_box.clear()
	assert_int(screen._hand_box.get_child_count()).is_equal(0)
	assert_int(screen._hand_box.cards().size()).is_equal(0)


## The ledge band on screen: from the hand's top under the rail, down to the ledge's foot, left
## of the register.
static func _ledge_band(screen: ShiftScreen) -> Rect2:
	var top: float = ShiftStage.HAND_RECT.position.y
	var bottom: float = ShiftStage.LEDGE_RECT.end.y
	var left: float = ShiftStage.REGISTER_RECT.end.x
	return _on_stage(screen, Rect2(left, top, ShiftStage.SIZE.x - left, bottom - top))


## `view`'s visible art (its sprite's opaque box), global.
static func _art(view: ItemView) -> Rect2:
	var texture: Texture2D = view.sprite().texture
	var box: Rect2i = ContactShadow.opaque_rect(texture)
	var sprite: Rect2 = view.sprite().get_global_rect()
	var scale: Vector2 = sprite.size / Vector2(texture.get_size())
	return Rect2(sprite.position + Vector2(box.position) * scale, Vector2(box.size) * scale)


func _assert_rects_apart(rects: Array[Rect2], what: String) -> void:
	for first: int in range(rects.size()):
		for second: int in range(first + 1, rects.size()):
			(
				assert_bool(rects[first].intersects(rects[second]))
				. override_failure_message(
					"%s: %s overlaps %s" % [what, rects[first], rects[second]]
				)
				. is_false()
			)


## The control a click at `point` reaches among `parent`'s children: the last one (drawn on top)
## under it that stops the mouse.
static func _card_at(parent: Control, point: Vector2) -> Control:
	for index: int in range(parent.get_child_count() - 1, -1, -1):
		var child: ItemView = parent.get_child(index) as ItemView
		if child == null or not child.visible or child.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		if child.hit_rect().has_point(child.get_global_transform().affine_inverse() * point):
			return child
	return null


static func _button(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = pressed
	press.position = point
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return press


static func _motion(point: Vector2, mask: int = 0) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = mask
	return motion


## The screen past the impulse rack, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
	await _frames(3)
	return screen


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
