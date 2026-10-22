extends GdUnitTestSuite
## The tag's payouts on the monitor (#86 round 7, TALLY): as a payout's roll first rises the tag
## turns gold and one chip flies from its send point into the digits; as the payout lands the gold
## sloshes and shines (the monitor juice, mock-up monitor_juice_v2.html: nothing travels into the
## €); once met, each landing sprays a small fountain and punches the tab at once. Split from
## monitor_view_test for the file's line limit.


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


## A payout's landing (CountUp.payout_landed; the monitor juice, mock-up monitor_juice_v2.html):
## the gold sloshes (a ripple from the group's middle), the shine rises up the number and the €,
## droplets jump off the surface and a spark and dust pop on the digits (TankBurst's particles, on
## the paper), with no coin and no tab punch before the quota; nothing travels from the number
## into the € (no pour). Outside the count a landing does nothing.
func test_a_landing_sloshes_and_shines_the_gold() -> void:
	var stage: ShiftStage = await _stage()
	var monitor: MonitorView = stage.monitor
	var burst: TankBurst = stage.tank_burst
	var count_up: CountUp = _follow(monitor)
	var led: LedDisplay = monitor.led
	var tank: GoldTank = led.gold_tank
	led.start_count(140, 140)
	led.show_subtotal(56, false)
	await _frames(1)
	burst.clear()
	var calm: float = absf(tank.waterline_at(0.0) - tank.waterline_at(40.0))
	count_up.payout_landed.emit(12, 56)
	tank.advance(0.05)
	assert_int(tank.shine_tops().size()).is_equal(1)
	assert_int(tank.twinkle_count()).is_equal(tank.tuning().twinkles)
	# The kick: the waves are bigger than at rest.
	var kicked: float = 0.0
	for x: int in range(0, 200, 4):
		kicked = maxf(kicked, absf(tank.waterline_at(x) - tank.waterline_at(x + 2)))
	assert_float(kicked).is_greater(calm)
	burst.advance(0.02)
	var particles: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.PARTICLES)
	assert_array(particles).is_not_empty()
	var origin: Vector2 = stage.get_global_rect().position
	var group: Rect2 = tank.group_rect()
	group.position -= origin
	for rect: Rect2 in particles:
		(
			assert_bool(group.grow(60.0).intersects(rect))
			. override_failure_message("%s far from the number %s" % [rect, group])
			. is_true()
		)
	assert_array(burst.drawn_rects(TankBurst.Layer.COINS)).is_empty()
	assert_vector(monitor.over_tab().scale).is_equal(Vector2.ONE)
	# The shine is gone after shine_s.
	tank.advance(tank.tuning().shine_s)
	assert_int(tank.shine_tops().size()).is_equal(0)
	# Outside the count nothing happens.
	burst.clear()
	led.clear()
	count_up.payout_landed.emit(12, 68)
	burst.advance(0.02)
	assert_bool(burst.is_active()).is_false()


## Once the quota is met each later landing sprays a small fountain (coins) and punches the tab at
## once; the landing that meets the quota (its payout_landed before quota_met) does not spray its
## own small fountain: the win's burst is its fountain. A chip still in flight as its payout lands
## (its flight on the count's tweens, frozen here as by the quota's hit-stop) goes at once, so no
## chip covers the number at the win or after it.
func test_after_the_quota_a_landing_sprays_and_punches_the_tab() -> void:
	var stage: ShiftStage = await _stage()
	var monitor: MonitorView = stage.monitor
	var burst: TankBurst = stage.tank_burst
	var count_up: CountUp = _follow(monitor)
	monitor.led.beat().make_tween = func() -> Tween:
		var frozen: Tween = monitor.create_tween()
		frozen.pause()
		return frozen
	monitor.led.start_count(40, 50)
	var beat: CountUpBeat = _payout_beat(45)
	beat.roll_ms = 150
	count_up.beat_started.emit(beat, _payout_step(45), "", null, 1)
	monitor.led.show_subtotal(20, false)
	assert_int(monitor.chips().chip_rects().size()).is_equal(1)
	# The landing that meets the quota: no spurt yet, the chip gone.
	monitor.led.show_subtotal(45, false)
	count_up.payout_landed.emit(45, 45)
	assert_array(monitor.chips().chip_rects()).is_empty()
	burst.advance(0.1)
	assert_int(burst.coin_count()).is_equal(0)
	monitor.led.show_subtotal(45, true)
	count_up.quota_met.emit(true)
	var number: Rect2 = monitor.led.digits_text_rect()
	for rect: Rect2 in monitor.chips().chip_rects():
		assert_bool(rect.intersects(number)).override_failure_message(str(rect)).is_false()
	assert_float(monitor.led.gold_tank.target()).is_equal(
		monitor.led.gold_tank.tuning().tank_overfill
	)
	burst.clear()
	await get_tree().create_timer(OverTab.DELAY_S + OverTab.POP_S + 0.1).timeout
	var tab: OverTab = monitor.over_tab()
	assert_vector(tab.scale).is_equal(Vector2.ONE)
	burst.clear()
	monitor.led.show_subtotal(50, true)
	count_up.payout_landed.emit(5, 50)
	burst.advance(0.1)
	assert_int(burst.coin_count()).is_greater(0)
	assert_float(await _largest_scale(tab, 0.2)).is_greater(1.0)


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
