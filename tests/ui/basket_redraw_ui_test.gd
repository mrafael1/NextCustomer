extends GdUnitTestSuite
## The basket redraw on the real screen (plan section 3.8; mock-up redraw_basket_v1.html): the
## Redraw key arms redraw mode; each basket that can be redrawn shows a REDRAW tag centred on its
## front (none on an empty basket, which can't be clicked); hovering names how many items go
## ("REDRAW 2" / "REDRAW 1") and the monitor's redraw panel explains; clicking a basket redraws it
## (logged with its basket and places, saved), ends redraw mode and plays BasketRedraw's motion
## (RedrawTuning's length, or its reduced-motion fade), every click blocked until it ends; a short
## draw pile swaps the left item and the monitor names the one that stays; a resumed screen shows
## every item at its place. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const TUNING := "res://data/balance/redraw.tres"

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


## The balance's basket size is the hand's (two items to a basket, HandRow's art geometry).
func test_the_basket_size_is_the_hands() -> void:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	assert_int(balance.basket_size).is_equal(HandRow.ITEMS_PER_BASKET)
	var tuning: RedrawTuning = load(TUNING)
	assert_float(tuning.length_s).is_equal_approx(1.1, 0.001)
	assert_float(tuning.duration(true)).is_equal_approx(0.3, 0.001)


## Armed with basket 3 (places 4 and 5) on the belt and basket 2 holding one item (place 2 on the
## belt): tags on baskets 1, 2 and 4 only, each centred on its basket's front at TAG_TOP_Y, on the
## stage and apart; the empty basket's target takes no click. Hovered, a tag names its count and
## turns hot; the monitor's panel covers the paper with its lines inside it. Cancel takes it off.
func test_armed_baskets_show_tags_but_an_empty_one_does_not() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var drawn: Array[CardInstance] = run.hand()
	for place: int in [4, 5, 2]:
		run.place(drawn[place], run.row.size())
	screen._refresh()
	screen._on_redraw_pressed()
	await _frames(2)
	var tags: BasketTags = screen._basket_tags
	assert_bool(tags.is_shown()).is_true()
	assert_bool(screen._redraw_mode).is_true()
	assert_bool(screen._cancel_button.visible).is_true()
	var stage: Rect2 = screen._stage.get_global_rect()
	var rects: Array[Rect2] = []
	for basket: int in range(4):
		var tag: RedrawTag = tags.tag(basket)
		var empty: bool = basket == 2
		assert_bool(tag.visible).override_failure_message(str(basket)).is_equal(not empty)
		var stops: bool = tags.hit(basket).mouse_filter == Control.MOUSE_FILTER_STOP
		assert_bool(stops).override_failure_message(str(basket)).is_equal(not empty)
		if empty:
			continue
		var rect: Rect2 = tag.get_global_rect()
		var front: Rect2 = _on_stage(screen, screen._stage.baskets.basket_rect(basket))
		var centre: float = front.position.x + BasketTags.TAG_CENTRE_X
		assert_float(rect.get_center().x).is_equal_approx(centre, 1.0)
		assert_float(rect.position.y - stage.position.y).is_equal(BasketTags.TAG_TOP_Y)
		assert_float(rect.size.y).is_equal(RedrawTag.TAG_HEIGHT)
		assert_bool(front.encloses(rect)).override_failure_message(str(rect)).is_true()
		var word: Rect2 = tag.word_label().get_global_rect()
		assert_bool(rect.encloses(word)).override_failure_message(str(word)).is_true()
		assert_bool(rect.encloses(tag.arrow().get_global_rect())).is_true()
		assert_str(tag.text()).is_equal("REDRAW")
		rects.append(rect)
	_assert_apart(rects)
	assert_int(tags.swaps(1)).is_equal(1)
	assert_int(tags.swaps(0)).is_equal(2)
	# Hovering basket 2 (one item) and basket 1 (two).
	tags._on_entered(1)
	assert_str(tags.tag(1).text()).is_equal("REDRAW 1")
	assert_bool(tags.tag(1).is_hot()).is_true()
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.REDRAW)
	assert_str(_panel(screen).notice().title).is_equal("REDRAW BASKET 2")
	tags._on_exited(1)
	tags._on_entered(0)
	assert_str(tags.tag(0).text()).is_equal("REDRAW 2")
	assert_bool(tags.tag(1).is_hot()).is_false()
	await _frames(2)
	var paper: Rect2 = _on_stage(screen, MonitorView.PAPER_RECT)
	for label: Label in screen._monitor.shown_labels():
		var rect: Rect2 = label.get_global_rect()
		assert_bool(paper.encloses(rect)).override_failure_message(label.text).is_true()
	# Clicking the empty basket does nothing.
	screen._on_basket_clicked(2)
	assert_int(run.redraws_used).is_equal(0)
	assert_bool(screen._redraw_mode).is_true()
	screen._on_cancel_pressed()
	assert_bool(tags.is_shown()).is_false()
	assert_bool(screen._cancel_button.visible).is_false()
	assert_int(screen._monitor.mode()).is_not_equal(MonitorView.Mode.REDRAW)


## A click on a basket's target redraws it: both items swapped in their places (left first), the
## event names the basket (1-based) and the places, the save has the redraw, redraw mode ends.
## While the motion plays every click waits (no pick, no checkout) and the basket tips; it ends
## after RedrawTuning.length_s with the new items shown at their places, every pose at rest and no
## ghost left.
func test_clicking_a_basket_redraws_it_and_plays_the_motion() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var drawn: Array[CardInstance] = run.hand()
	screen._on_redraw_pressed()
	await _frames(1)
	var start: int = Time.get_ticks_msec()
	# A click on basket 2's tag lands on its target (its gui_input, as the viewport sends it).
	var point: Vector2 = screen._basket_tags.tag(1).get_global_rect().get_center()
	var target: Control = screen._basket_tags.hit(1)
	assert_bool(target.get_global_rect().has_point(point)).is_true()
	assert_int(target.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	target.gui_input.emit(_left_click())
	await _frames(2)
	assert_int(run.redraws_used).is_equal(1)
	assert_bool(screen._redraw_mode).is_false()
	assert_bool(screen._redraw_busy).is_true()
	var places: Array[CardInstance] = run.hand_places()
	assert_bool(drawn.has(places[2]) or drawn.has(places[3])).is_false()
	for place: int in [0, 1, 4, 5, 6, 7]:
		assert_object(places[place]).is_same(drawn[place])
	var event: Dictionary = _last_event("redraw")
	assert_int(int(event["basket"])).is_equal(2)
	(
		assert_array((event["places"] as Array).map(func(p: Variant) -> int: return int(p)))
		. is_equal([2, 3])
	)
	assert_array(event["cards_replaced"]).is_equal(
		[String(drawn[2].definition.id), String(drawn[3].definition.id)]
	)
	assert_bool(screen._basket_tags.is_shown()).is_false()
	assert_bool(screen._cancel_button.visible).is_false()
	assert_str(_panel(screen).notice().title).is_equal("REDRAWING")
	assert_bool(screen._checkout_button.disabled).is_true()
	assert_bool(screen._redraw_button.disabled).is_true()
	screen._on_hand_card_clicked(screen._hand_box.view_at(0) as CardView)
	assert_object(screen._picked).is_null()
	screen._on_redraw_pressed()
	assert_bool(screen._redraw_mode).is_false()
	var tuning: RedrawTuning = screen._basket_redraw.tuning
	var most: float = 0.0
	var holder: Control = screen._stage.basket_fronts.holder(1)
	while screen._redraw_busy and Time.get_ticks_msec() - start < 3000:
		most = maxf(most, absf(rad_to_deg(holder.rotation)))
		await get_tree().process_frame
	var took: float = (Time.get_ticks_msec() - start) / 1000.0
	assert_bool(screen._redraw_busy).is_false()
	assert_float(took).is_between(tuning.length_s - 0.05, tuning.length_s + 0.4)
	assert_float(most).is_between(tuning.tip_deg * 0.6, tuning.tip_deg * 1.05)
	await _frames(2)
	for place: int in [2, 3]:
		var view: Control = screen._hand_box.view_at(place)
		assert_object((view as ItemView).card).is_same(run.hand_places()[place])
		assert_float(view.modulate.a).is_equal(1.0)
		assert_vector(view.position).is_equal(screen._hand_box.place_position(place))
		assert_float(view.rotation).is_equal(0.0)
	# The screen's refresh at the end lays the baskets out again: their holders are new.
	holder = screen._stage.basket_fronts.holder(1)
	assert_float(holder.rotation).is_equal(0.0)
	assert_vector(holder.scale).is_equal(Vector2.ONE)
	assert_vector(screen._stage.deck_button.scale).is_equal(Vector2.ONE)
	assert_int(screen._stage.pop_layer.get_child_count()).is_equal(0)
	assert_int(_live_children(screen._stage.redraw_layer)).is_equal(0)
	assert_int(screen._monitor.mode()).is_not_equal(MonitorView.Mode.REDRAW)
	assert_str(screen._redraw_button.note()).is_equal("1 left")


## Reduced motion: no pose (the basket never tips), the redraw ends after the 0.3 s fade.
func test_reduced_motion_fades_in_place() -> void:
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	screen._on_redraw_pressed()
	var start: int = Time.get_ticks_msec()
	screen._on_basket_clicked(0)
	var holder: Control = screen._stage.basket_fronts.holder(0)
	var moved: bool = false
	while screen._redraw_busy and Time.get_ticks_msec() - start < 2000:
		moved = moved or holder.rotation != 0.0 or holder.position != Vector2.ZERO
		await get_tree().process_frame
	var took: float = (Time.get_ticks_msec() - start) / 1000.0
	var tuning: RedrawTuning = screen._basket_redraw.tuning
	assert_float(took).is_between(tuning.duration(true) - 0.05, tuning.duration(true) + 0.3)
	assert_bool(moved).is_false()
	screen.profile.set_reduced_motion(false)


## A draw pile with one card left: the hovered full basket says "REDRAW 1" and the monitor names
## the item that stays; the redraw swaps the left item only and still costs 1.
func test_a_short_pile_swaps_the_left_item_and_says_which_stays() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	while run.deck.draw_pile().size() > 1:
		run.deck.redraw_places([7])
	screen._refresh()
	var stays: CardInstance = run.hand_places()[1]
	screen._on_redraw_pressed()
	screen._basket_tags._on_entered(0)
	assert_str(screen._basket_tags.tag(0).text()).is_equal("REDRAW 1")
	var notice: RedrawNotice = _panel(screen).notice()
	assert_bool(notice.foot_warning).is_true()
	assert_str(notice.foot).is_equal(
		"Only 1 item left to draw: %s stays." % stays.definition.display_name
	)
	screen._on_basket_clicked(0)
	screen._basket_redraw.stop()
	assert_object(run.hand_places()[1]).is_same(stays)
	assert_int(run.redraws_used).is_equal(1)
	assert_str(screen._redraw_button.note()).is_equal("none to draw")


## A resumed screen shows every item at its place (redraw mode is never saved): an item on the
## belt keeps its place empty, a redrawn basket's items are in it.
func test_a_resumed_screen_shows_the_places() -> void:
	var first: ShiftScreen = await _screen()
	var drawn: Array[CardInstance] = first.run.hand()
	first._on_hand_card_clicked(_view_for(first, drawn[2]))
	first._on_slot_input(_left_click(), 0)
	first._on_redraw_pressed()
	first._on_basket_clicked(3)
	first._basket_redraw.stop()
	first._on_redraw_pressed()
	var places: Array[CardInstance] = first.run.hand_places()

	var resumed: ShiftScreen = await _screen()
	assert_bool(resumed._redraw_mode).is_false()
	assert_bool(resumed._basket_tags.is_shown()).is_false()
	assert_array(resumed._hand_box.places()).is_equal([0, 1, 3, 4, 5, 6, 7])
	for place: int in resumed._hand_box.places():
		var view: ItemView = resumed._hand_box.view_at(place) as ItemView
		assert_int(view.card.instance_id).is_equal(places[place].instance_id)
		assert_vector(view.position).is_equal(resumed._hand_box.place_position(place))


## BasketRedraw.pose: at rest the identity; squashed about the centre-bottom at the squash's end;
## fully tipped about the right corner (lifted and pulled) at the tip's end, the corner moving
## only by that; back at rest at the end.
func test_the_basket_pose_follows_the_tuning() -> void:
	var tuning: RedrawTuning = load(TUNING)
	var left: float = 590.0
	assert_that(BasketRedraw.pose(left, INF, tuning)).is_equal(Transform2D.IDENTITY)
	var squashed: Transform2D = BasketRedraw.pose(left, tuning.squash_s, tuning)
	assert_vector(squashed.get_scale()).is_equal_approx(
		Vector2(1.0 + tuning.squash_x, 1.0 - tuning.squash_y), Vector2(0.001, 0.001)
	)
	var centre: Vector2 = Vector2(left + BasketRedraw.CENTRE_X, BasketRedraw.PIVOT_Y)
	assert_vector(squashed * centre).is_equal_approx(centre, Vector2(0.01, 0.01))
	var tipped: Transform2D = BasketRedraw.pose(left, tuning.squash_s + tuning.tip_in_s, tuning)
	assert_float(rad_to_deg(tipped.get_rotation())).is_equal_approx(tuning.tip_deg, 0.01)
	var corner: Vector2 = Vector2(left + BasketRedraw.CORNER_X, BasketRedraw.PIVOT_Y)
	var moved: Vector2 = corner + Vector2(-tuning.tip_pull, -tuning.tip_lift)
	assert_vector(tipped * corner).is_equal_approx(moved, Vector2(0.01, 0.01))
	var ended: Transform2D = BasketRedraw.pose(left, tuning.length_s, tuning, 2)
	assert_vector(ended.origin).is_equal_approx(Vector2.ZERO, Vector2(0.001, 0.001))
	assert_float(ended.get_rotation()).is_equal_approx(0.0, 0.0001)
	# The hover lifts and wobbles about the centre-bottom.
	var hovered: Transform2D = BasketRedraw.pose(left, INF, tuning, 0, tuning.hover_lift, 1.0)
	assert_float(rad_to_deg(hovered.get_rotation())).is_equal_approx(1.0, 0.001)
	assert_vector(hovered * centre).is_equal_approx(
		centre - Vector2(0, tuning.hover_lift), Vector2(0.01, 0.01)
	)


func _panel(screen: ShiftScreen) -> RedrawPanel:
	return screen._monitor.get_node("RedrawPanel") as RedrawPanel


static func _live_children(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func _assert_apart(rects: Array[Rect2]) -> void:
	for first: int in range(rects.size()):
		for second: int in range(first + 1, rects.size()):
			assert_bool(rects[first].intersects(rects[second])).is_false()


## The screen on shift 1, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	return screen


static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
