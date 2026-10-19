extends GdUnitTestSuite
## The belt items' corner marks and paid chips on the real shift screen (#80, step 7, BeltChips;
## mock-up B2). Marks: one EffectMark per item with a step EffectChip.qualifies (a fizzle, or a
## bonus or factor another source caused), a fizzle disc when one of them fizzled, else a check;
## no count. Planning shows none since #71 (mock-up h1: its stickers stack over the items, and
## follow every place and remove); a resumed checkout shows them all (the marks' rules below are
## checked there). The CHECKOUT click clears them and
## each comes back, popping, as CountUp.step_landed says one of its item's steps landed (shown at
## once, unpopped, under reduced motion), never beside #60's marker for the same landing, and the
## row ends with the preview's marks. Every mark sits on its art's visible top-right corner inside
## its own cell, clear of its ticket, the other items and the other marks, and takes no clicks.
## Paid chips: none in planning; in the count-up the scanned item's pops as the current one (with
## its echo, none under reduced motion) and the others settle and stay; a resumed checkout shows
## them all settled. Every rect is checked on screen (headless runs use a 1280x1280 window: the
## stage is centred, 280 px down). The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## #60's reference row (count_up_test), with Coupon engine and Slot engine given and the Spot
## check set.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
## Six products whose last (the 6th) gathers four marking steps (with Category engine and Slot
## engine given).
const FOLDED_ROW: Array[String] = ["milk", "milk", "milk", "eggs", "coffee", "bread"]
## A mark's kind in _mark_kinds: none, a check, a fizzle disc.
const NO_MARK := 0
const CHECK := 1
const FIZZLE := 2

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


## Planning shows no mark and no paid chip (#71, mock-up h1). Shown (as a resumed checkout shows
## them): one mark per item that has a marking step, a fizzle disc when one fizzled, none scaled.
func test_marks_follow_the_steps() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	for view: CardView in screen._row_views:
		assert_bool(view.badge.visible).is_false()
		assert_object((view as ItemView)._mark).is_null()
	_show_marks(screen)
	assert_array(_mark_kinds(screen)).is_equal(_expected_kinds(result))
	var fizzles: int = 0
	var marks: int = 0
	for view: CardView in screen._row_views:
		var mark: EffectMark = (view as ItemView)._mark
		if mark == null:
			continue
		marks += 1
		assert_that(mark.scale).is_equal(Vector2.ONE)
		if mark.is_fizzle():
			fizzles += 1
	assert_int(marks).is_greater_equal(2)
	# Multipack's Coupon engine fizzle and its own ×3 fizzle, at least.
	assert_int(fizzles).is_greater_equal(1)


## An item with many marking steps still has one mark: Bread, last and 6th, takes Coffee's +3,
## Eggs' ×2, Slot engine's ×2 and Category engine's bonus, and shows one check.
func test_many_steps_make_one_mark() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("category_engine")
	screen._debug.give_upgrade("slot_engine")
	await _place(screen, FOLDED_ROW)
	var result: ScoreResult = screen.run.preview()
	_show_marks(screen)
	var last: int = FOLDED_ROW.size() - 1
	assert_int(EffectChip.step_indices(result, last).size()).is_greater(1)
	var item: ItemView = screen._row_views[last] as ItemView
	assert_object(item._mark).is_not_null()
	(
		assert_int(item.get_children().filter(func(n: Node) -> bool: return n is EffectMark).size())
		. is_equal(1)
	)
	assert_array(_mark_kinds(screen)).is_equal(_expected_kinds(result))


## Steps may land in any order (a landing whose marker is still being absorbed can come after a
## later step of the same item): each marking landing returns its item's mark, in the kind of the
## steps landed so far, and a step landing twice, or one that marks nothing, returns null. The row
## ends with the preview's marks.
func test_marks_land_in_any_order() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	var planned: Array[int] = _expected_kinds(result)
	var chips: BeltChips = BeltChips.new()
	chips.begin_count(result, screen._row_views, true)
	for kind: int in _mark_kinds(screen):
		assert_int(kind).is_equal(NO_MARK)
	var landed: Dictionary[int, PackedInt32Array] = {}
	for index: int in range(result.steps.size() - 1, -1, -1):
		var step: ScoreStep = result.steps[index]
		var mark: EffectMark = chips.land(index)
		assert_bool(mark != null).is_equal(EffectChip.qualifies(step))
		if mark == null:
			continue
		var on_slot: PackedInt32Array = landed.get(step.slot, PackedInt32Array())
		on_slot.append(index)
		landed[step.slot] = on_slot
		assert_object(mark).is_same((screen._row_views[step.slot] as ItemView)._mark)
		assert_bool(mark.is_fizzle()).is_equal(EffectChip.fizzles(result, on_slot))
	var first: int = EffectChip.step_indices(result, 3)[0]
	assert_object(chips.land(first)).is_null()
	assert_array(_mark_kinds(screen)).is_equal(planned)


## Every mark sits on its art's visible top-right corner (EffectMark.corner), on the stage inside
## its own cell, clear of the belt's rail and its ticket, of every other item's sprite and of every
## other mark, and takes no clicks (shown as a resumed checkout shows them).
func test_marks_sit_on_their_art_corners_inside_their_cells() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	_show_marks(screen)
	var stage: Rect2 = screen._stage.get_global_rect()
	var rail: Rect2 = screen._stage.belt.get_global_transform() * screen._stage.belt.rail()
	var marks: Array[Rect2] = []
	for slot: int in range(screen._row_views.size()):
		var item: ItemView = screen._row_views[slot] as ItemView
		var mark: EffectMark = item._mark
		if mark == null:
			continue
		var rect: Rect2 = mark.get_global_rect()
		var message: String = "slot %d at %s" % [slot, rect]
		var sprite: Rect2 = item.sprite().get_global_rect()
		var corner: Vector2 = EffectMark.corner(item.sprite().texture, sprite)
		assert_vector(rect.position).is_equal_approx(corner, Vector2(0.01, 0.01))
		assert_int(mark.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_bool(stage.encloses(rect)).override_failure_message(message).is_true()
		var cell: Rect2 = screen._slots[slot].get_global_rect().grow(0.01)
		assert_bool(cell.encloses(rect)).override_failure_message(message).is_true()
		assert_bool(rect.intersects(rail)).override_failure_message(message).is_false()
		var sticker: Rect2 = item.sticker().get_global_rect()
		assert_bool(rect.intersects(sticker)).override_failure_message(message).is_false()
		for other: int in range(screen._row_views.size()):
			if other != slot:
				var art: Rect2 = screen._row_views[other].body.get_global_rect()
				assert_bool(rect.intersects(art)).override_failure_message(message).is_false()
		for placed: Rect2 in marks:
			assert_bool(rect.intersects(placed)).override_failure_message(message).is_false()
		marks.append(rect)
	assert_int(marks.size()).is_greater_equal(2)


## Planning's effects follow the row on every place and remove, as stickers (#71), never as marks:
## Coffee alone fizzles (no Breakfast product after it); Bread placed after it takes Coffee's +3
## and Coffee's fizzle goes; Bread taken back out brings the fizzle back.
func test_marks_refresh_on_place_and_remove() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["coffee"])
	assert_array(_mark_kinds(screen)).is_equal([NO_MARK])
	assert_array(_chip_texts(screen, 0)).contains(["pfff"])
	await _place(screen, ["bread"])
	assert_array(_mark_kinds(screen)).is_equal([NO_MARK, NO_MARK])
	assert_array(_chip_texts(screen, 0)).not_contains(["pfff"])
	assert_array(_chip_texts(screen, 1)).contains(["+3"])
	# Bread taken out of the row and let go: back in the hand.
	screen._on_row_card_clicked(screen._row_views[1])
	screen._let_go()
	await _frames(2)
	assert_int(screen.run.row.size()).is_equal(1)
	assert_array(_mark_kinds(screen)).is_equal([NO_MARK])
	assert_array(_chip_texts(screen, 0)).contains(["pfff"])


## The count-up's hand-off: the CHECKOUT click clears every mark; each comes back (popping from
## EffectMark.POP_SCALE) as CountUp.step_landed says one of its item's steps landed, and only
## then; the row ends with exactly the preview's marks, at rest. Every step lands once, and the
## plan gains no beat.
func test_marks_clear_at_the_click_and_pop_in_as_their_steps_land() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var planned: Array[int] = _expected_kinds(screen.run.preview())
	var steps: int = screen.run.preview().steps.size()
	screen._on_checkout_pressed()
	for kind: int in _mark_kinds(screen):
		assert_int(kind).is_equal(NO_MARK)
	var result: ScoreResult = screen.run.last_result
	var landed: Array[int] = []
	var failures: Array[String] = []
	var popped: Array[bool] = [false]
	var on_landed: Callable = func(index: int) -> void:
		landed.append(index)
		var step: ScoreStep = result.steps[index]
		if not EffectChip.qualifies(step):
			return
		var mark: EffectMark = (screen._row_views[step.slot] as ItemView)._mark
		if mark == null:
			failures.append("step %d: no mark on slot %d" % [index, step.slot])
		elif mark.scale.x > 1.0:
			popped[0] = true
	screen._count_up.step_landed.connect(on_landed)
	# Every frame: an item shows a mark only once one of its marking steps landed.
	while screen._counting:
		await get_tree().process_frame
		for slot: int in range(screen._row_views.size()):
			var shown: bool = (screen._row_views[slot] as ItemView)._mark != null
			if shown and _landed_on(result, landed, slot) == 0:
				failures.append("slot %d: a mark before its steps landed" % slot)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_bool(popped[0]).is_true()
	var sorted: Array[int] = landed.duplicate()
	sorted.sort()
	assert_int(landed.size()).is_equal(steps)
	assert_array(sorted).is_equal(range(steps))
	assert_int(screen._count_up.plan.step_count).is_equal(steps)
	await _frames(int(EffectMark.POP_TIME * 60.0) + 10)
	assert_array(_mark_kinds(screen)).is_equal(planned)
	for view: CardView in screen._row_views:
		var mark: EffectMark = (view as ItemView)._mark
		if mark != null:
			assert_that(mark.scale).is_equal(Vector2.ONE)


## No mark and #60's marker show the same landing together: a landing's mark comes only once its
## marker is gone (absorbed), and no marker still waits for a landing whose mark shows. The
## reference row lands Eggs once and Multipack three times.
func test_marks_and_markers_never_show_the_same_landing_together() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	screen._on_checkout_pressed()
	var count_up: CountUp = screen._count_up
	var plan: CountUpPlan = count_up.plan
	var beat_of: Dictionary[int, int] = {}
	for beat_index: int in range(plan.beats.size()):
		for step_index: int in plan.beats[beat_index].steps:
			beat_of[step_index] = beat_index
	var seen_markers: Dictionary[int, EffectMarker] = {}
	var landed: Dictionary[int, bool] = {}
	var failures: Array[String] = []
	var marked_landings: Array[int] = [0]
	var on_landed: Callable = func(index: int) -> void:
		var beat: int = beat_of[index]
		landed[beat] = true
		if not seen_markers.has(beat):
			return
		marked_landings[0] += 1
		var marker: EffectMarker = seen_markers[beat]
		if is_instance_valid(marker) and not marker.is_queued_for_deletion():
			failures.append("beat %d: its mark came with its marker still there" % beat)
	count_up.step_landed.connect(on_landed)
	while screen._counting:
		await get_tree().process_frame
		if count_up._tokens == null:
			continue
		for beat: int in count_up._tokens.markers.keys():
			var marker: EffectMarker = count_up._tokens.markers[beat]
			seen_markers[beat] = marker
			var alive: bool = is_instance_valid(marker) and not marker.is_queued_for_deletion()
			if alive and landed.has(beat):
				failures.append("beat %d: a marker waits for a landed mark" % beat)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(seen_markers.size()).is_equal(4)
	assert_int(marked_landings[0]).is_equal(4)


## Reduced motion: marks still come back at their landing, at full size, with no pop, and no paid
## chip shows its echo.
func test_reduced_motion_lands_marks_without_a_pop_or_an_echo() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(true)
	await _full_row(screen)
	screen._on_checkout_pressed()
	var scales: Array[Vector2] = []
	var on_landed: Callable = func(index: int) -> void:
		var step: ScoreStep = screen.run.last_result.steps[index]
		if EffectChip.qualifies(step):
			var mark: EffectMark = (screen._row_views[step.slot] as ItemView)._mark
			scales.append(mark.scale if mark != null else Vector2.ZERO)
	screen._count_up.step_landed.connect(on_landed)
	var echoes: Array[int] = [0]
	while screen._counting:
		await get_tree().process_frame
		for view: CardView in screen._row_views:
			if (view.badge as PayoutPlaque).echo_frame().visible:
				echoes[0] += 1
	assert_int(scales.size()).is_greater_equal(3)
	for mark_scale: Vector2 in scales:
		assert_that(mark_scale).is_equal(Vector2.ONE)
	assert_int(echoes[0]).is_equal(0)
	assert_array(_mark_kinds(screen)).is_equal(_expected_kinds(screen.run.last_result))


## The count-up's paid chips (mock-up B2): the CHECKOUT click hides them; on every frame at most
## one chip shows the current face, the one of the item CountUp.beat_started last named; a chip
## once shown stays (earlier chips stay, settled); one pops with its echo. Every shown chip stays
## on the stage in its cell's column, under the hung monitor, clear of every ticket and of every
## other item's chip and mark; a settled one also clears its own mark. At the end every item shows
## its payout, settled: the last current chip settles as the monitor shows the total.
func test_paid_chips_pop_on_the_scanned_item_and_earlier_ones_stay() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	screen._on_checkout_pressed()
	for view: CardView in screen._row_views:
		assert_bool(view.badge.visible).is_false()
	var stage: Rect2 = screen._stage.get_global_rect()
	# (Less a hair: the scan lift's TRANS_BACK overshoots by a fraction of a pixel.)
	var monitor: Rect2 = _on_stage(screen, MonitorView.DRAWN_RECT).grow_side(SIDE_BOTTOM, -1.0)
	var scanned: Array[CardView] = [null]
	var on_beat: Callable = func(
		_beat: CountUpBeat, _step: ScoreStep, _line: String, view: CardView, _items: int
	) -> void:
		scanned[0] = view
	screen._count_up.beat_started.connect(on_beat)
	var shown: Dictionary[int, bool] = {}
	var failures: Array[String] = []
	var echoes: Array[int] = [0]
	var settled_seen: Array[int] = [0]
	while screen._counting:
		await get_tree().process_frame
		var current: int = 0
		var faces: Array[Rect2] = []
		for slot: int in range(screen._row_views.size()):
			var item: ItemView = screen._row_views[slot] as ItemView
			var plaque: PayoutPlaque = item.badge as PayoutPlaque
			if not plaque.visible:
				if shown.has(slot):
					failures.append("slot %d: its chip went away" % slot)
				continue
			shown[slot] = true
			if plaque.echo_frame().visible:
				echoes[0] += 1
			if plaque.is_current():
				current += 1
				if item != scanned[0]:
					failures.append("slot %d: current but not the scanned item" % slot)
			else:
				settled_seen[0] += 1
			# At its place and size, unpunched (a punch scales it for a moment).
			var face: Rect2 = Rect2(item.get_global_transform() * plaque.position, plaque.size)
			var cell: Rect2 = screen._slots[slot].get_global_rect().grow(0.01)
			var message: String = "slot %d: %s at %s" % [slot, plaque.text, face]
			if not stage.encloses(face) or face.intersects(monitor):
				failures.append("%s: off the stage or over the monitor" % message)
			if face.position.x < cell.position.x or face.end.x > cell.end.x:
				failures.append("%s: out of its cell's column" % message)
			for other: int in range(screen._row_views.size()):
				var other_item: ItemView = screen._row_views[other] as ItemView
				if face.intersects(other_item.sticker().get_global_rect()):
					failures.append("%s: over a ticket" % message)
				var mark: EffectMark = other_item._mark
				var own: bool = other == slot
				if mark != null and (not own or not plaque.is_current()):
					if face.intersects(mark.get_global_rect()):
						failures.append("%s: over the mark of slot %d" % [message, other])
			for placed: Rect2 in faces:
				if face.intersects(placed):
					failures.append("%s: over another chip" % message)
			faces.append(face)
		if current > 1:
			failures.append("%d current chips" % current)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(echoes[0]).is_greater(0)
	assert_int(settled_seen[0]).is_greater(0)
	var result: ScoreResult = screen.run.last_result
	for slot: int in range(screen._row_views.size()):
		var plaque: PayoutPlaque = screen._row_views[slot].badge as PayoutPlaque
		assert_bool(plaque.visible).override_failure_message(str(slot)).is_true()
		assert_bool(plaque.is_current()).override_failure_message(str(slot)).is_false()
		assert_str(plaque.text).is_equal(PayoutPlaque.text_for(result.payouts[slot]))


## A run resumed after its checkout shows the row as the count-up left it: every mark, and every
## item's paid chip, settled, with its payout; back in planning the chips go.
func test_a_resumed_checkout_shows_every_paid_chip_settled() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	screen._show_checked_out(result)
	await _frames(2)
	assert_array(_mark_kinds(screen)).is_equal(_expected_kinds(result))
	for slot: int in range(screen._row_views.size()):
		var plaque: PayoutPlaque = screen._row_views[slot].badge as PayoutPlaque
		assert_bool(plaque.visible).is_true()
		assert_bool(plaque.is_current()).is_false()
		assert_str(plaque.text).is_equal(PayoutPlaque.text_for(result.payouts[slot]))
		assert_bool(plaque.is_muted()).is_equal(result.payouts[slot] == 0)
	screen._show_belt(result)
	for view: CardView in screen._row_views:
		assert_bool(view.badge.visible).is_false()


## Each belt item's mark kind as `result` gives it: NO_MARK, CHECK or FIZZLE.
static func _expected_kinds(result: ScoreResult) -> Array[int]:
	var kinds: Array[int] = []
	for slot: int in range(result.payouts.size()):
		var indices: PackedInt32Array = EffectChip.step_indices(result, slot)
		if indices.is_empty():
			kinds.append(NO_MARK)
		else:
			kinds.append(FIZZLE if EffectChip.fizzles(result, indices) else CHECK)
	return kinds


## Shows the preview's marks as a resumed checkout shows them (planning shows none, #71).
static func _show_marks(screen: ShiftScreen) -> void:
	screen._effects.clear()  # As the CHECKOUT click does: no planning lift under the marks.
	screen._belt_chips.show_all(screen.run.preview(), screen._row_views, true)


## The texts of the planning stickers on the belt item in `slot` (#71, mock-up h1).
static func _chip_texts(screen: ShiftScreen, slot: int) -> Array[String]:
	var texts: Array[String] = []
	for sticker: EffectSticker in screen._stage.planning_layer.stack(slot):
		texts.append(sticker.text())
	return texts


## Each belt item's mark kind as shown.
static func _mark_kinds(screen: ShiftScreen) -> Array[int]:
	var kinds: Array[int] = []
	for view: CardView in screen._row_views:
		var mark: EffectMark = (view as ItemView)._mark
		if mark == null:
			kinds.append(NO_MARK)
		else:
			kinds.append(FIZZLE if mark.is_fizzle() else CHECK)
	return kinds


## How many of the `landed` steps of `result` mark `slot`.
static func _landed_on(result: ScoreResult, landed: Array[int], slot: int) -> int:
	var count: int = 0
	for index: int in landed:
		var step: ScoreStep = result.steps[index]
		if step.slot == slot and EffectChip.qualifies(step):
			count += 1
	return count


## A stage rect on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _frames(2)
	return screen


## The reference row on shift 1: Coupon engine and Slot engine given, the Spot check set.
func _full_row(screen: ShiftScreen) -> void:
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	await _place(screen, FULL_ROW)


## Places each card at the row's end as the player does: picked from the hand, then its slot
## clicked.
func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	var placed: int = screen.run.row.size()
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(placed + ids.size())
	await _frames(3)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for view: Control in screen._hand_box.cards():
		if (view as CardView).card == card:
			return view as CardView
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
