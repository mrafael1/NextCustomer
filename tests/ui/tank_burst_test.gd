extends GdUnitTestSuite
## The count's gold outside the monitor (#86 v6 scan count-up, TankBurst; it leaves from the plain
## € after the number since the monitor bay follow-up). On the real stage: the burst's jets rise
## from the € (crossing the monitor's paper, as the pour does) past the top bar but never off the
## stage, the splashes stay on the bezel off the paper, the coins come to rest on the belt's top
## face (COIN_REST) and go (the monitor's right edge turns a coin back only beside it), the
## monitor shakes and comes back to rest, all stepped in real time (advance; the count-up's
## hit-stops never reach it). The pour hops from where it is given into the €, on the paper.
## Reduced motion leaves only STILL_SPLASHES on the bezel: no coins, jets, pour, spurt or shake.
## The real saves and logs are never touched.

const STEP := 1.0 / 60.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_tank_burst_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The layer covers the stage over the top bar and under the scan layer, taking no clicks; the
## monitor hands it its LED (the €) and itself.
func test_the_layer_sits_over_the_top_bar() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	assert_object(stage.monitor.tank_burst).is_same(burst)
	assert_that(Rect2(burst.position, burst.size)).is_equal(TankBurst.STAGE_RECT)
	assert_int(burst.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(burst.get_index()).is_greater(stage.top_bar.get_index())
	assert_int(burst.get_index()).is_less(stage.scan_layer.get_index())
	assert_bool(burst.is_active()).is_false()


## The burst, stepped over five seconds: every piece on the stage, the €'s gold seen on the
## (shaking) paper as it leaves the €, the splashes on the bezel and off the paper, the jet up past
## the top bar, coins resting on the belt's top face, the monitor shaken then back at rest, and
## nothing left at the end.
func test_the_burst_stays_on_the_stage_and_leaves_the_euro() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	var monitor: MonitorView = stage.monitor
	await _counting(monitor)
	burst.burst()
	assert_bool(burst.is_active()).is_true()
	var highest: float = INF
	var shook: bool = false
	var splashed: bool = false
	var rested: Array[Vector2] = []
	var on_paper: bool = false
	var failures: Array[String] = []
	for frame: int in range(roundi(5.0 / STEP)):
		burst.advance(STEP)
		var offset: Vector2 = burst.shake_offset()
		shook = shook or offset != Vector2.ZERO
		assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position + offset)
		var paper: Rect2 = Rect2(
			MonitorView.PAPER_RECT.position + offset, MonitorView.PAPER_RECT.size
		)
		var bezel: Rect2 = Rect2(
			ShiftStage.MONITOR_RECT.position + offset, ShiftStage.MONITOR_RECT.size
		)
		for rect: Rect2 in burst.drawn_rects(TankBurst.Layer.PARTICLES):
			highest = minf(highest, rect.position.y)
			on_paper = on_paper or paper.intersects(rect)
			if not TankBurst.STAGE_RECT.encloses(rect):
				failures.append("particle %s at frame %d" % [rect, frame])
		for rect: Rect2 in burst.drawn_rects(TankBurst.Layer.SPLASHES):
			splashed = true
			if not bezel.encloses(rect) or paper.intersects(rect):
				failures.append("splash %s at frame %d" % [rect, frame])
			if not MonitorView.DRAWN_RECT.grow(TankBurst.BURST_SHAKE).encloses(rect):
				failures.append("splash %s off the monitor at frame %d" % [rect, frame])
		assert_array(burst.drawn_rects(TankBurst.Layer.POUR)).is_empty()
		for spot: Vector2 in burst.resting_coins():
			if not rested.has(spot):
				rested.append(spot)
	(
		assert_array(failures.slice(0, 5))
		. override_failure_message(str(failures.slice(0, 5)))
		. is_empty()
	)
	assert_bool(shook).is_true()
	assert_bool(splashed).is_true()
	assert_bool(on_paper).is_true()
	# The jet rises past the top bar (its foot is the stage's top: the jet is cut there).
	assert_float(highest).is_less(stage.top_bar.get_global_rect().end.y)
	assert_float(highest).is_greater_equal(0.0)
	assert_int(rested.size()).is_greater(10)
	for spot: Vector2 in rested:
		assert_float(spot.y).is_between(
			TankBurst.COIN_REST.x * TankBurst.CELL, TankBurst.COIN_REST.y * TankBurst.CELL
		)
		# On the belt (its top face under the row), never off the stage.
		assert_float(spot.x).is_between(ShiftStage.BELT_RECT.position.x, ShiftStage.BELT_RECT.end.x)
	assert_bool(burst.is_active()).is_false()
	assert_int(burst.coin_count()).is_equal(0)
	assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)


## A coin flying right past the monitor's right edge (less COIN_EDGE) turns back while beside the
## bezel, and carries on below it (nothing to turn it there).
func test_the_monitor_edge_turns_coins_back_only_beside_it() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	var bezel: Rect2 = Rect2(
		ShiftStage.MONITOR_RECT.position / TankBurst.CELL,
		ShiftStage.MONITOR_RECT.size / TankBurst.CELL
	)
	var edge: float = bezel.end.x - TankBurst.COIN_EDGE
	var beside: TankBurst.Coin = burst._new_coin(Vector2(edge + 1.0, bezel.get_center().y))
	beside.velocity = Vector2(40.0, 0.0)
	var below: TankBurst.Coin = burst._new_coin(Vector2(edge + 1.0, bezel.end.y + 4.0))
	below.velocity = Vector2(40.0, 0.0)
	burst.advance(STEP)
	assert_float(beside.velocity.x).is_less(0.0)
	assert_float(below.velocity.x).is_greater(0.0)


## The burst runs on its own (real) time: frames move it with no count-up running.
func test_the_burst_moves_in_real_time() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	burst.burst()
	var earlier: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.PARTICLES)
	await get_tree().create_timer(0.2).timeout
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_not_equal(earlier)
	assert_bool(burst.coin_count() > 0 or not burst.resting_coins().is_empty()).is_true()
	burst.clear()
	assert_bool(burst.is_active()).is_false()
	assert_vector(stage.monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)


## A payout's pour: POUR_MIN plus one per POUR_PER_EURO drops, at most POUR_MAX (here 8), from
## the gap before the € (TankBurst.pour_point, the monitor bay follow-up) on a low arc (at most
## POUR_ARC.y art px up) into the €, all on the paper, gone after POUR_S.
func test_the_pour_hops_from_the_number_into_the_euro() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	var monitor: MonitorView = stage.monitor
	monitor.led.start_count(140)
	monitor.led.show_subtotal(56, false)
	await get_tree().process_frame
	# The layer's (stage) coordinates of the given (global) point.
	var origin: Vector2 = stage.get_global_rect().position
	var from: Vector2 = TankBurst.pour_point(monitor.led)
	burst.pour(from, 12)
	burst.advance(0.001)
	var first: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.POUR)
	assert_array(first).is_not_empty()
	var start: Rect2 = first[0]
	for rect: Rect2 in first:
		start = start.merge(rect)
	assert_bool(start.grow(8.0).has_point(from - origin)).is_true()
	var drops: int = 0
	var lowest_end: Vector2 = Vector2.ZERO
	var highest: float = INF
	for frame: int in range(roundi(0.6 / STEP)):
		burst.advance(STEP)
		var rects: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.POUR)
		# Five rects per drop.
		drops = maxi(drops, floori(rects.size() / 5.0))
		for rect: Rect2 in rects:
			(
				assert_bool(MonitorView.PAPER_RECT.encloses(rect))
				. override_failure_message(str(rect))
				. is_true()
			)
			if rect.position.x > lowest_end.x:
				lowest_end = rect.get_center()
			highest = minf(highest, rect.position.y)
		assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_empty()
	assert_int(drops).is_equal(mini(TankBurst.POUR_MAX, TankBurst.POUR_MIN + 4))
	# A low arc: never more than POUR_ARC.y art px (plus the drop's own height) over the number.
	var ceiling: float = (from - origin).y - (TankBurst.POUR_ARC.y + 3.0) * ArtStyle.ART_SCALE
	assert_float(highest).is_greater_equal(ceiling)
	# They end in the €, under its top.
	var euro: Rect2 = monitor.led.euro_text_rect()
	euro.position -= origin
	assert_float(lowest_end.x).is_between(euro.position.x, euro.end.x)
	assert_float(lowest_end.y).is_greater(euro.position.y)
	assert_array(burst.drawn_rects(TankBurst.Layer.POUR)).is_empty()
	assert_bool(burst.is_active()).is_false()
	# A big payout pours at most POUR_MAX.
	burst.pour(from, 500)
	assert_int(burst._pours.size()).is_equal(TankBurst.POUR_MAX)


## A spurt past the quota: a smaller jet and some coins, on the stage; the jet is seen on the paper
## as it leaves the €.
func test_a_spurt_is_a_small_burst() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	await _counting(stage.monitor)
	burst.spurt(20)
	var coins: int = 0
	var spurt_on_paper: bool = false
	for frame: int in range(roundi(0.5 / STEP)):
		burst.advance(STEP)
		coins = maxi(coins, burst.coin_count())
		for rect: Rect2 in burst.drawn_rects(TankBurst.Layer.PARTICLES):
			assert_bool(TankBurst.STAGE_RECT.encloses(rect)).is_true()
			spurt_on_paper = spurt_on_paper or MonitorView.PAPER_RECT.intersects(rect)
	assert_bool(spurt_on_paper).is_true()
	assert_int(coins).is_between(1, 8)
	assert_vector(burst.shake_offset()).is_equal(Vector2.ZERO)
	# A delayed spurt (#86 round 7: as the pour lands in the €) starts after its delay.
	burst.clear()
	burst.spurt(20, TankBurst.POUR_S)
	burst.advance(TankBurst.POUR_S - STEP)
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_empty()
	burst.advance(2.0 * STEP)
	burst.advance(0.1)
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_not_empty()


## Reduced motion: the burst leaves STILL_SPLASHES on the bezel (off the paper) and nothing else;
## they stay. The pour, the spurt and the shakes do nothing.
func test_reduced_motion_leaves_still_splashes() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	stage.monitor.reduced_motion = func() -> bool: return true
	burst.burst()
	burst.spurt(30)
	burst.pour(stage.monitor.bay().landing_point(), 30)
	burst.shake(6.0, 0.5)
	var splashes: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.SPLASHES)
	assert_array(splashes).is_not_empty()
	for rect: Rect2 in splashes:
		(
			assert_bool(ShiftStage.MONITOR_RECT.encloses(rect))
			. override_failure_message(str(rect))
			. is_true()
		)
		assert_bool(MonitorView.PAPER_RECT.intersects(rect)).is_false()
	for frame: int in range(roundi(3.0 / STEP)):
		burst.advance(STEP)
		assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_empty()
		assert_array(burst.drawn_rects(TankBurst.Layer.POUR)).is_empty()
		assert_vector(stage.monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)
	assert_array(burst.drawn_rects(TankBurst.Layer.SPLASHES)).is_equal(splashes)
	assert_int(burst.coin_count()).is_equal(0)
	# Each still splash is one of the bezel's spots.
	var spots: int = 0
	for still: Vector4i in TankBurst.STILL_SPLASHES:
		var at: Vector2 = (
			ShiftStage.MONITOR_RECT.position / TankBurst.CELL + Vector2(still.x, still.y)
		)
		for rect: Rect2 in splashes:
			if rect.grow(still.z * TankBurst.CELL).has_point(at * TankBurst.CELL):
				spots += 1
				break
	assert_int(spots).is_equal(TankBurst.STILL_SPLASHES.size())
	burst.clear()
	assert_bool(burst.is_active()).is_false()


## A stage in the window (the layer draws in its coordinates).
## The monitor's LED in the count layout, its € on the paper (where the gold leaves from).
func _counting(monitor: MonitorView) -> void:
	monitor.led.start_count(140)
	monitor.led.show_subtotal(56, false)
	await get_tree().process_frame


func _stage() -> ShiftStage:
	var stage: ShiftStage = auto_free(ShiftStage.new(7))
	get_tree().root.add_child(stage)
	await get_tree().process_frame
	return stage


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
