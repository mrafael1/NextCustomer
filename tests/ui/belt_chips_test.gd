extends GdUnitTestSuite
## The belt items' effect chips on the real shift screen (#75, BeltChips; style frame v2's spec
## section 4.4): one chip per step EffectChip.qualifies (a fizzle, or a bonus or factor another
## source caused), at most EffectChip.MAX_PER_CELL per item with the rest as "+N more", worded
## by the measured fallback chain, in step order. In planning they follow every place and
## remove. The count-up hands off as option B: the CHECKOUT click clears them and each pops in as
## CountUp.step_landed says its step landed, never beside #60's marker for the same landing, and
## the row ends with the planning chips. Every chip sits on screen inside its own cell, clear of
## the belt's bottom rail, its sticker, its sprite, its plaque and every other chip. Every rect is
## checked on screen (headless runs use a 1280x1280 window: the stage is centred, 280 px down).
## The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## #60's reference row (count_up_test), with Coupon engine and Slot engine given and the Spot
## check set.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
## Six products whose last (the 6th) gathers four chip steps (with Category engine and Slot
## engine given).
const FOLDED_ROW: Array[String] = ["milk", "milk", "milk", "eggs", "coffee", "bread"]

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


## One chip per qualifying step (at most 2 per item, the rest as "+N more"), worded by the
## measured fallback chain, a fizzle's dashed; in planning none is dimmed, shrunk or faded.
func test_chips_follow_the_steps() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	var total: int = _assert_chips_of(screen, result, "planning")
	assert_int(total).is_greater_equal(3)
	var fizzles: int = 0
	for view: CardView in screen._row_views:
		for chip: EffectChip in (view as ItemView).chips():
			assert_bool(chip.is_dimmed()).is_false()
			assert_float(chip.modulate.a).is_equal(1.0)
			assert_that(chip.scale).is_equal(Vector2.ONE)
			if chip.is_fizzle():
				fizzles += 1
	# Multipack's Coupon engine fizzle and its own ×3 fizzle at the end of the row, at least.
	assert_int(fizzles).is_greater_equal(1)


## An item that gathers more steps than it shows chips: Bread, last and 6th, takes Coffee's +3,
## Eggs' ×2, Slot engine's ×2 and Category engine's bonus. The last chip shown folds into "+N
## more" for itself and the rest.
func test_more_steps_than_chips_fold_into_more() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("category_engine")
	screen._debug.give_upgrade("slot_engine")
	await _place(screen, FOLDED_ROW)
	var result: ScoreResult = screen.run.preview()
	var last: int = FOLDED_ROW.size() - 1
	var indices: PackedInt32Array = EffectChip.step_indices(result, last)
	assert_int(indices.size()).is_greater(EffectChip.MAX_PER_CELL)
	var chips: Array[EffectChip] = (screen._row_views[last] as ItemView).chips()
	assert_int(chips.size()).is_equal(EffectChip.MAX_PER_CELL)
	var more: int = indices.size() - EffectChip.MAX_PER_CELL + 1
	assert_str(chips[-1].label().text).is_equal(EffectChip.MORE_TEXT % more)
	assert_bool(chips[-1].is_fizzle()).is_false()
	_assert_chips_of(screen, result, "folded row")


## A landing whose marker is still being absorbed can come after a later step of the same item:
## the item's chips stay in step order whatever order their steps land in, and a step landing
## twice adds nothing.
func test_chips_keep_step_order_whatever_order_they_land_in() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("category_engine")
	screen._debug.give_upgrade("slot_engine")
	await _place(screen, FOLDED_ROW)
	var planned: Array[PackedStringArray] = _chip_texts(screen)
	var result: ScoreResult = screen.run.preview()
	var chips: BeltChips = BeltChips.new()
	chips.begin_count(
		result,
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		LoyaltyCard.names(screen.run.upgrades),
		InspectionTag.names(screen.run.inspections),
		true
	)
	for texts: PackedStringArray in _chip_texts(screen):
		assert_int(texts.size()).is_equal(0)
	for index: int in range(result.steps.size() - 1, -1, -1):
		var chip: EffectChip = chips.land(index)
		assert_bool(chip != null).is_equal(EffectChip.qualifies(result.steps[index]))
	assert_object(chips.land(EffectChip.step_indices(result, FOLDED_ROW.size() - 1)[0])).is_null()
	assert_array(_chip_texts(screen)).is_equal(planned)


## The chip text keeps whole words, in order: the receipt's source text when it fits, else the
## source's display name, else its first word; never a word cut short.
func test_chip_text_falls_back_by_measuring() -> void:
	var font: Font = EffectChip.font()
	var size: int = EffectChip.FONT_SIZE
	var none: PackedStringArray = PackedStringArray()
	# 1. The receipt's text fits: a card's own receipt text ("Coffee").
	var card_step: ScoreStep = ScoreStep.new()
	card_step.step_type = ScoreStep.StepType.FLAT
	card_step.slot = 2
	card_step.value = 3
	card_step.source_kind = ScoreStep.SourceKind.CARD
	card_step.source_slot = 1
	card_step.text = "Coffee"
	var card_names: PackedStringArray = ["Croissant", "A much longer card name"]
	var source: String = ReceiptView.source_text(card_step, none, none)
	assert_str(source).is_equal("Coffee")
	assert_bool(EffectChip.fits("+3 · " + source, font, size)).is_true()
	assert_str(EffectChip.chip_text(card_step, card_names, none, none, font, size)).is_equal(
		"+3 · " + source
	)
	# An upgrade step without its own text: the receipt names the upgrade, which fits.
	var step: ScoreStep = ScoreStep.new()
	step.step_type = ScoreStep.StepType.FLAT
	step.slot = 4
	step.value = 15
	step.source_kind = ScoreStep.SourceKind.UPGRADE
	step.source_index = 0
	step.text = ""
	var upgrade_names: PackedStringArray = ["Tip jar"]
	source = ReceiptView.source_text(step, upgrade_names, none)
	assert_str(source).is_equal("Tip jar")
	assert_bool(EffectChip.fits("+15 · " + source, font, size)).is_true()
	assert_str(EffectChip.chip_text(step, none, upgrade_names, none, font, size)).is_equal(
		"+15 · Tip jar"
	)
	# 2. The receipt's text ("<text> (Tip jar)") is too long, but the display name fits.
	step.text = "A very long receipt text for this upgrade"
	var long_source: String = ReceiptView.source_text(step, upgrade_names, none)
	assert_bool(EffectChip.fits("+15 · " + long_source, font, size)).is_false()
	assert_str(EffectChip.chip_text(step, none, upgrade_names, none, font, size)).is_equal(
		"+15 · Tip jar"
	)
	# 3. The display name is too long too (Slot engine's ×2 on the belt): its first word, whole.
	step.step_type = ScoreStep.StepType.MULTIPLIER
	step.value = 2
	step.text = ""
	upgrade_names = ["Slot engine"]
	assert_bool(EffectChip.fits("×2 · Slot engine", font, size)).is_false()
	var text: String = EffectChip.chip_text(step, none, upgrade_names, none, font, size)
	assert_str(text).is_equal("×2 · Slot")
	assert_bool(EffectChip.fits(text, font, size)).is_true()


## Every chip lies on the stage inside its own cell, CHIP_CLEARANCE clear of its ticket on the
## rail, and covers neither its sticker, its sprite (lifted too), its plaque nor any other chip.
func test_chips_stay_in_their_cells_clear_of_the_bottom_rail() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var stage: Rect2 = screen._stage.get_global_rect()
	var all_chips: Array[Rect2] = []
	for slot: int in range(screen._row_views.size()):
		var item: ItemView = screen._row_views[slot] as ItemView
		item.show_badge(9999, false)
		var cell: Rect2 = screen._slots[slot].get_global_rect().grow(0.01)
		var sprite: Rect2 = item.body.get_global_rect()
		sprite = sprite.merge(Rect2(sprite.position - Vector2(0, ItemView.LIFT), sprite.size))
		var covered: Array[Rect2] = [
			item.sticker().get_global_rect(),
			sprite,
			(item.badge as PayoutPlaque).face().get_global_rect(),
		]
		for chip: EffectChip in item.chips():
			var rect: Rect2 = chip.get_global_rect()
			var message: String = "slot %d: %s at %s" % [slot, chip.label().text, rect]
			assert_bool(stage.encloses(rect)).override_failure_message(message).is_true()
			assert_bool(cell.encloses(rect)).override_failure_message(message).is_true()
			assert_float(rect.end.y).override_failure_message(message).is_less_equal(
				item.sticker().get_global_rect().position.y - ItemView.CHIP_CLEARANCE
			)
			for other: Rect2 in covered + all_chips:
				assert_bool(rect.intersects(other)).override_failure_message(message).is_false()
			all_chips.append(rect)
	assert_int(all_chips.size()).is_greater_equal(3)
	assert_float(ItemView.CHIP_CLEARANCE).is_greater_equal(4.0)


## Chips follow the row on every place and remove: Coffee alone fizzles (no Breakfast product
## after it); Bread placed after it takes Coffee's +3 as a chip and Coffee's fizzle goes; Bread
## taken back out brings the fizzle back.
func test_chips_refresh_on_place_and_remove() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["coffee"])
	var coffee: Array[EffectChip] = (screen._row_views[0] as ItemView).chips()
	assert_int(coffee.size()).is_equal(1)
	assert_bool(coffee[0].is_fizzle()).is_true()
	_assert_chips_of(screen, screen.run.preview(), "coffee alone")
	await _place(screen, ["bread"])
	assert_int((screen._row_views[0] as ItemView).chips().size()).is_equal(0)
	var bread: Array[EffectChip] = (screen._row_views[1] as ItemView).chips()
	assert_int(bread.size()).is_equal(1)
	assert_bool(bread[0].is_fizzle()).is_false()
	assert_str(bread[0].label().text).starts_with("+")
	assert_str(bread[0].label().text).contains("Coffee")
	_assert_chips_of(screen, screen.run.preview(), "coffee, bread")
	# Bread taken out of the row and let go: back in the hand.
	screen._on_row_card_clicked(screen._row_views[1])
	screen._let_go()
	await _frames(2)
	assert_int(screen.run.row.size()).is_equal(1)
	coffee = (screen._row_views[0] as ItemView).chips()
	assert_int(coffee.size()).is_equal(1)
	assert_bool(coffee[0].is_fizzle()).is_true()


## The count-up's hand-off (option B): the CHECKOUT click clears every chip; each pops in (from
## BeltChips.POP_SCALE) as CountUp.step_landed says its step landed, and only then; the row ends
## with exactly the planning chips, at rest. Every step lands once, and the plan gains no beat.
func test_chips_clear_at_the_click_and_pop_in_as_their_steps_land() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var planned: Array[PackedStringArray] = _chip_texts(screen)
	var steps: int = screen.run.preview().steps.size()
	screen._on_checkout_pressed()
	for texts: PackedStringArray in _chip_texts(screen):
		assert_int(texts.size()).is_equal(0)
	var result: ScoreResult = screen.run.last_result
	var landed: Array[int] = []
	var failures: Array[String] = []
	var popped: Array[bool] = [false]
	var on_landed: Callable = func(index: int) -> void:
		landed.append(index)
		var step: ScoreStep = result.steps[index]
		if not EffectChip.qualifies(step):
			return
		# The chip showing it is there now, popping in.
		var chips: Array[EffectChip] = (screen._row_views[step.slot] as ItemView).chips()
		var shown: int = mini(_landed_on(result, landed, step.slot), EffectChip.MAX_PER_CELL)
		if chips.size() != shown:
			failures.append("step %d: %d chips for %d landed" % [index, chips.size(), shown])
		for chip: EffectChip in chips:
			if chip.scale.x > 1.0:
				popped[0] = true
	screen._count_up.step_landed.connect(on_landed)
	# Every frame: an item shows no more chips than its qualifying steps landed so far.
	while screen._counting:
		await get_tree().process_frame
		for slot: int in range(screen._row_views.size()):
			var shown: int = (screen._row_views[slot] as ItemView).chips().size()
			if shown > mini(_landed_on(result, landed, slot), EffectChip.MAX_PER_CELL):
				failures.append("slot %d: %d chips before their steps landed" % [slot, shown])
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_bool(popped[0]).is_true()
	var sorted: Array[int] = landed.duplicate()
	sorted.sort()
	assert_int(landed.size()).is_equal(steps)
	assert_array(sorted).is_equal(range(steps))
	assert_int(screen._count_up.plan.step_count).is_equal(steps)
	await _frames(int(BeltChips.POP_TIME * 60.0) + 10)
	assert_array(_chip_texts(screen)).is_equal(planned)
	for view: CardView in screen._row_views:
		for chip: EffectChip in (view as ItemView).chips():
			assert_that(chip.scale).is_equal(Vector2.ONE)


## No chip and #60's marker show the same landing together: a landing's chip comes only once its
## marker is gone (absorbed), and no marker still waits for a landing whose chip shows. The
## reference row lands Eggs once and Multipack three times.
func test_chips_and_markers_never_show_the_same_landing_together() -> void:
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
			failures.append("beat %d: its chip came with its marker still there" % beat)
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
				failures.append("beat %d: a marker waits for a landed chip" % beat)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(seen_markers.size()).is_equal(4)
	assert_int(marked_landings[0]).is_equal(4)


## Reduced motion: chips appear at their landing at full size, with no pop.
func test_reduced_motion_lands_chips_without_a_pop() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(true)
	await _full_row(screen)
	screen._on_checkout_pressed()
	var scales: Array[Vector2] = []
	var on_landed: Callable = func(index: int) -> void:
		var step: ScoreStep = screen.run.last_result.steps[index]
		if EffectChip.qualifies(step):
			for chip: EffectChip in (screen._row_views[step.slot] as ItemView).chips():
				scales.append(chip.scale)
	screen._count_up.step_landed.connect(on_landed)
	while screen._counting:
		await get_tree().process_frame
	assert_int(scales.size()).is_greater_equal(3)
	for chip_scale: Vector2 in scales:
		assert_that(chip_scale).is_equal(Vector2.ONE)


## Each item's chips are its qualifying steps' (EffectChip.step_indices) as BeltChips words them,
## folded past MAX_PER_CELL. Returns how many chips show.
func _assert_chips_of(screen: ShiftScreen, result: ScoreResult, label: String) -> int:
	var names: PackedStringArray = ShiftScreen._names(screen.run.row)
	var upgrade_names: PackedStringArray = LoyaltyCard.names(screen.run.upgrades)
	var inspection_names: PackedStringArray = InspectionTag.names(screen.run.inspections)
	var total: int = 0
	assert_int(screen._row_views.size()).is_equal(result.payouts.size())
	for slot: int in range(result.payouts.size()):
		var indices: PackedInt32Array = EffectChip.step_indices(result, slot)
		var chips: Array[EffectChip] = (screen._row_views[slot] as ItemView).chips()
		var message: String = "%s, slot %d" % [label, slot]
		assert_int(chips.size()).override_failure_message(message).is_equal(
			mini(indices.size(), EffectChip.MAX_PER_CELL)
		)
		total += chips.size()
		for place: int in range(chips.size()):
			var step: ScoreStep = result.steps[indices[place]]
			var expected: String = EffectChip.chip_text(
				step,
				names,
				upgrade_names,
				inspection_names,
				EffectChip.font(),
				EffectChip.FONT_SIZE
			)
			var folded: bool = (
				place == EffectChip.MAX_PER_CELL - 1 and indices.size() > EffectChip.MAX_PER_CELL
			)
			if folded:
				expected = EffectChip.MORE_TEXT % (indices.size() - place)
			var text: String = chips[place].label().text
			assert_str(text).override_failure_message(message).is_equal(expected)
			assert_bool(EffectChip.fits(text, EffectChip.font(), EffectChip.FONT_SIZE)).is_true()
			var fizzle: bool = step.step_type == ScoreStep.StepType.WASTED and not folded
			assert_bool(chips[place].is_fizzle()).override_failure_message(message).is_equal(fizzle)
	return total


## How many of the `landed` steps of `result` are chips on `slot`.
static func _landed_on(result: ScoreResult, landed: Array[int], slot: int) -> int:
	var count: int = 0
	for index: int in landed:
		var step: ScoreStep = result.steps[index]
		if step.slot == slot and EffectChip.qualifies(step):
			count += 1
	return count


## Each belt item's chip texts, in order.
static func _chip_texts(screen: ShiftScreen) -> Array[PackedStringArray]:
	var texts: Array[PackedStringArray] = []
	for view: CardView in screen._row_views:
		var item_texts: PackedStringArray = PackedStringArray()
		for chip: EffectChip in (view as ItemView).chips():
			item_texts.append(chip.label().text)
		texts.append(item_texts)
	return texts


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
