extends GdUnitTestSuite
## The tag's payouts on the monitor (#86 round 7, TALLY): as a payout's roll first rises the tag
## turns gold and one chip flies from its send point into the digits; as the chip lands the gold
## hops from the gap before the € into the € (the monitor bay follow-up, mock-up
## monitor_bay_v1.html: no drop crosses a digit); once met, a payout's spurt and tab punch wait for
## its pour to land (TankBurst.POUR_S). Split from monitor_view_test for the file's line limit.


## A payout (#86 round 7): as its roll's first reading rises the tag turns gold and one chip flies
## from the tag's send point into the digits' middle (the middle of LedDisplay.digits_text_rect)
## over the receipt chip's flight; the roll's next readings send none; a payout of 0 sends none;
## under reduced motion none flies and the tag still turns gold.
func test_a_payout_sends_one_chip_from_the_tag_into_the_number() -> void:
	var monitor: MonitorView = await _monitor()
	var made: Array[Tween] = []
	monitor.led.beat().make_tween = func() -> Tween:
		var tween: Tween = monitor.create_tween()
		tween.pause()
		made.append(tween)
		return tween
	var count_up: CountUp = _follow(monitor)
	monitor.led.start_count(40)
	var bay: ScannerBay = monitor.bay()
	var tag: BayTag = bay.tag()
	tag.show_value(12, false)
	var beat: CountUpBeat = _payout_beat(12)
	beat.roll_ms = 150
	count_up.beat_started.emit(beat, _payout_step(12), "", null, 1)
	assert_array(monitor.chips().chip_rects()).is_empty()
	monitor.led.show_subtotal(3, false)
	assert_bool(tag.is_paid()).is_true()
	var rects: Array[Rect2] = monitor.chips().chip_rects()
	assert_int(rects.size()).is_equal(1)
	var chip: TallyChips.Chip = monitor.chips()._chips[0]
	var width: float = TallyChips.chip_width("+€12")
	assert_float(rects[0].get_center().x).is_equal_approx(
		tag.send_point().x + TallyChips.START_RIGHT - width / 2.0, 0.001
	)
	assert_float(rects[0].get_center().y).is_equal_approx(tag.send_point().y, 0.001)
	var number: Vector2 = monitor.led.digits_text_rect().get_center()
	assert_vector(chip.to).is_equal(number - ShiftStage.MONITOR_RECT.position)
	assert_bool(monitor.led.digits_text_rect().has_point(number)).is_true()
	monitor.led.show_subtotal(8, false)
	monitor.led.show_subtotal(12, false)
	assert_int(monitor.chips().chip_rects().size()).is_equal(1)
	# The flight: the receipt chip's (clamped roll).
	_step_all(made, 0.14)
	assert_int(monitor.chips().chip_rects().size()).is_equal(1)
	_step_all(made, 0.02)
	assert_int(monitor.chips().chip_rects().size()).is_equal(0)
	# A payout of 0 sends none.
	count_up.beat_started.emit(_payout_beat(0), _payout_step(0), "", null, 1)
	monitor.led.show_subtotal(13, false)
	assert_array(monitor.chips().chip_rects()).is_empty()
	# Reduced motion: none, the tag gold.
	monitor.reduced_motion = func() -> bool: return true
	tag.show_value(4, false)
	count_up.beat_started.emit(_payout_beat(4), _payout_step(4), "", null, 1)
	monitor.led.show_subtotal(17, false)
	assert_array(monitor.chips().chip_rects()).is_empty()
	assert_bool(tag.is_paid()).is_true()


## The pour (the monitor bay follow-up, mock-up monitor_bay_v1.html) leaves the gap just above
## the digits, before the € (TankBurst.pour_point), as the chip lands, and hops into the €: no drop
## crosses a digit (every drop right of the digits' ink, within 2 art px), each lands in the €'s
## ink, all within POUR_S.
func test_the_pour_hops_from_the_digits_into_the_euro() -> void:
	var stage: ShiftStage = await _stage()
	var monitor: MonitorView = stage.monitor
	var burst: TankBurst = stage.tank_burst
	var origin: Vector2 = stage.get_global_rect().position
	var led: LedDisplay = monitor.led
	led.start_count(140)
	led.show_subtotal(56, false)
	await _frames(1)
	var digits: Rect2 = led.digits_text_rect()
	var euro: Rect2 = led.euro_text_rect()
	var from: Vector2 = TankBurst.pour_point(led)
	assert_float(from.x).is_greater(digits.end.x)
	assert_float(from.x).is_less(euro.position.x)
	assert_float(from.y).is_less(digits.position.y)
	monitor.chips().landed.emit(12, 0)
	burst.advance(0.001)
	var rects: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.POUR)
	assert_array(rects).is_not_empty()
	var start: Rect2 = rects[0]
	for rect: Rect2 in rects:
		start = start.merge(rect)
	(
		assert_bool(start.grow(4.0).has_point(from - origin))
		. override_failure_message("%s from %s" % [start, from - origin])
		. is_true()
	)
	var steps: int = 0
	while not burst.drawn_rects(TankBurst.Layer.POUR).is_empty():
		for rect: Rect2 in burst.drawn_rects(TankBurst.Layer.POUR):
			var message: String = "%s over the digits %s" % [rect, digits]
			assert_float(rect.end.x + origin.x).override_failure_message(message).is_greater(
				digits.end.x - 2.0 * ArtStyle.ART_SCALE
			)
		burst.advance(0.02)
		steps += 1
		var last_lands: float = TankBurst.POUR_S + TankBurst.POUR_MAX * TankBurst.POUR_STAGGER
		assert_int(steps).is_less(ceili(last_lands / 0.02) + 3)
	# Outside the count nothing pours.
	burst.clear()
	monitor.led.clear()
	monitor.chips().landed.emit(12, 0)
	burst.advance(0.001)
	assert_array(burst.drawn_rects(TankBurst.Layer.POUR)).is_empty()


## A payout after the quota spurts and punches the tab only as its pour lands in the €
## (TankBurst.POUR_S after its chip lands); the ding's own payout (its beat before the quota) does
## not spurt.
func test_spurt_and_tab_punch_wait_for_the_pour() -> void:
	var stage: ShiftStage = await _stage()
	var monitor: MonitorView = stage.monitor
	var burst: TankBurst = stage.tank_burst
	var count_up: CountUp = _follow(monitor)
	var made: Array[Tween] = []
	monitor.led.beat().make_tween = func() -> Tween:
		var tween: Tween = monitor.create_tween()
		tween.pause()
		made.append(tween)
		return tween
	monitor.led.start_count(40)
	# The ding payout: its beat before the quota.
	count_up.beat_started.emit(_payout_beat(45), _payout_step(45), "", null, 1)
	monitor.led.show_subtotal(45, false)
	monitor.led.show_subtotal(45, true)
	count_up.quota_met.emit(true)
	burst.clear()
	_step_all(made, 0.3)
	burst.advance(TankBurst.POUR_S + 0.05)
	assert_bool(burst._jets.is_empty()).is_true()
	# A later payout.
	await get_tree().create_timer(OverTab.DELAY_S + OverTab.POP_S + 0.1).timeout
	var tab: OverTab = monitor.over_tab()
	assert_vector(tab.scale).is_equal(Vector2.ONE)
	burst.clear()
	count_up.beat_started.emit(_payout_beat(5), _payout_step(5), "", null, 1)
	monitor.led.show_subtotal(50, true)
	_step_all(made, 0.3)
	burst.advance(0.001)
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_empty()
	assert_vector(tab.scale).is_equal(Vector2.ONE)
	burst.advance(TankBurst.POUR_S)
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_not_empty()
	# The tab: still until the pour lands, then punched.
	assert_float(await _largest_scale(tab, TankBurst.POUR_S - 0.05)).is_equal(1.0)
	assert_float(await _largest_scale(tab, 0.3)).is_greater(1.0)


## Steps every tween in `made` by `seconds`, 10 ms at a time.
static func _step_all(made: Array[Tween], seconds: float) -> void:
	var left: float = seconds
	while left > 0.00001:
		for tween: Tween in made.duplicate():
			if tween.is_valid():
				tween.custom_step(minf(0.01, left))
		left -= 0.01


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


## A bare stage (the monitor with the tank's burst layer) in the window.
func _stage() -> ShiftStage:
	var stage: ShiftStage = auto_free(ShiftStage.new(7))
	get_tree().root.add_child(stage)
	await _frames(1)
	return stage


## The largest x scale `control` takes over the next `seconds` (real time, frame by frame).
func _largest_scale(control: Control, seconds: float) -> float:
	var largest: float = control.scale.x
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000.0:
		await get_tree().process_frame
		largest = maxf(largest, control.scale.x)
	return largest


## A count-up (not played) the monitor follows: the tests emit its signals.
func _follow(monitor: MonitorView) -> CountUp:
	var count_up: CountUp = auto_free(CountUp.new())
	monitor.follow(count_up)
	return count_up


## A payout beat of `amount` on the item in the scanner (slot 0).
static func _payout_beat(amount: int) -> CountUpBeat:
	var beat: CountUpBeat = CountUpBeat.new()
	beat.kind = CountUpBeat.Kind.PAYOUT
	beat.steps = PackedInt32Array([0])
	beat.slot = 0
	beat.scan_slot = 0
	beat.payout = amount
	return beat


static func _payout_step(amount: int) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = ScoreStep.StepType.PAYOUT
	step.value = amount
	step.value_after = amount
	step.slot = 0
	return step


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
