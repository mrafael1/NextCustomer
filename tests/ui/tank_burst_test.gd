extends GdUnitTestSuite
## The count's gold outside the monitor's glass (TankBurst; the monitor juice, mock-up
## monitor_juice_v2.html, K1 with WIN B, the coin fountain). On the real stage: the win's fountain
## sprays coins out of the number and € (GoldTank.group_rect) for win_fountain_s, low and mostly
## to the right; coins falling back onto the screen go behind the glass (GLASS_RECT), so once the
## fountain is over no coin covers the number, the scanner bay or the inspection line; the rest
## come to rest on the belt's top face (COIN_REST) and go. The splashes stay on the bezel off the
## paper, the monitor shakes and comes back to rest, all stepped in real time (advance; the
## count-up's hit-stops never reach it). A landing's droplets and sparkle, and the small fountain
## after the quota. Reduced motion leaves only STILL_SPLASHES on the bezel: no coins, drops,
## sparks or shake. The real saves and logs are never touched.

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
## monitor hands it its LED (the number and €) and itself.
func test_the_layer_sits_over_the_top_bar() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	assert_object(stage.monitor.tank_burst).is_same(burst)
	assert_that(Rect2(burst.position, burst.size)).is_equal(TankBurst.STAGE_RECT)
	assert_int(burst.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(burst.get_index()).is_greater(stage.top_bar.get_index())
	assert_int(burst.get_index()).is_less(stage.scan_layer.get_index())
	assert_bool(burst.is_active()).is_false()


## The burst, stepped over five seconds: every piece on the stage, the splashes on the bezel and
## off the paper (within the shake), coins spraying for win_fountain_s only, mostly to the right,
## coins resting on the belt's top face, the monitor shaken then back at rest, and nothing left
## at the end.
func test_the_burst_stays_on_the_stage() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	var monitor: MonitorView = stage.monitor
	await _counting(monitor)
	var tune: CountUpTuning = burst.tuning()
	burst.burst()
	assert_bool(burst.is_active()).is_true()
	var shook: bool = false
	var splashed: bool = false
	var rested: Array[Vector2] = []
	var failures: Array[String] = []
	var right: int = 0
	var left: int = 0
	var seen: Array[TankBurst.Coin] = []
	var last_new: float = 0.0
	for frame: int in range(roundi(5.0 / STEP)):
		burst.advance(STEP)
		for coin: TankBurst.Coin in burst._coins:
			if not seen.has(coin):
				seen.append(coin)
				last_new = (frame + 1) * STEP
				if coin.velocity.x > 0.0:
					right += 1
				else:
					left += 1
		var offset: Vector2 = burst.shake_offset()
		shook = shook or offset != Vector2.ZERO
		assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position + offset)
		var paper: Rect2 = Rect2(
			MonitorView.PAPER_RECT.position + offset, MonitorView.PAPER_RECT.size
		)
		var bezel: Rect2 = Rect2(
			ShiftStage.MONITOR_RECT.position + offset, ShiftStage.MONITOR_RECT.size
		)
		for layer: TankBurst.Layer in [TankBurst.Layer.PARTICLES, TankBurst.Layer.COINS]:
			for rect: Rect2 in burst.drawn_rects(layer):
				if not TankBurst.STAGE_RECT.encloses(rect):
					failures.append("piece %s at frame %d" % [rect, frame])
		for rect: Rect2 in burst.drawn_rects(TankBurst.Layer.SPLASHES):
			splashed = true
			if not bezel.encloses(rect) or paper.intersects(rect):
				failures.append("splash %s at frame %d" % [rect, frame])
			if not MonitorView.DRAWN_RECT.grow(tune.win_shake_px).encloses(rect):
				failures.append("splash %s off the monitor at frame %d" % [rect, frame])
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
	# The fountain: win_fountain_s long, mostly to the right.
	assert_float(last_new).is_less_equal(tune.win_fountain_s + 2.0 * STEP)
	assert_int(right + left).is_greater(20)
	assert_int(right).is_greater(left)
	assert_int(left).is_greater(0)
	assert_int(rested.size()).is_greater(5)
	for spot: Vector2 in rested:
		assert_float(spot.y).is_between(
			TankBurst.COIN_REST.x * TankBurst.CELL, TankBurst.COIN_REST.y * TankBurst.CELL
		)
		# On the belt (its top face under the row), never off the stage.
		assert_float(spot.x).is_between(ShiftStage.BELT_RECT.position.x, ShiftStage.BELT_RECT.end.x)
	assert_bool(burst.is_active()).is_false()
	assert_int(burst.coin_count()).is_equal(0)
	assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)


## Once the fountain is over (win_fountain_s plus a coin's rise), no coin covers the number and €,
## the scanner bay or the inspection line (PASSED): those falling back onto the screen are gone
## behind the glass; some coins did fly over the screen.
func test_coins_clear_the_number_after_the_win() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	var monitor: MonitorView = stage.monitor
	await _counting(monitor)
	var origin: Vector2 = stage.get_global_rect().position
	var covered: Dictionary[String, Rect2] = {
		"number": monitor.led.gold_tank.group_rect(),
		"bay": monitor.bay().get_global_rect(),
		"inspection": monitor.inspection_passed_label.get_global_rect(),
	}
	for key: String in covered:
		covered[key] = Rect2(covered[key].position - origin, covered[key].size)
	var glass: Rect2 = Rect2(
		ShiftStage.MONITOR_RECT.position + TankBurst.GLASS_RECT.position * TankBurst.CELL,
		TankBurst.GLASS_RECT.size * TankBurst.CELL
	)
	var tune: CountUpTuning = burst.tuning()
	var rise: float = (tune.fountain_up.x + tune.fountain_up.y) / TankBurst.GRAVITY
	var settled_at: float = tune.win_fountain_s + rise + 0.05
	burst.burst()
	var over_glass: bool = false
	var failures: Array[String] = []
	for frame: int in range(roundi(3.0 / STEP)):
		burst.advance(STEP)
		var time: float = (frame + 1) * STEP
		for rect: Rect2 in burst.drawn_rects(TankBurst.Layer.COINS):
			over_glass = over_glass or glass.intersects(rect)
			if time < settled_at:
				continue
			for key: String in covered:
				if covered[key].intersects(rect):
					failures.append("%s covers the %s at %.2f s" % [rect, key, time])
	assert_bool(over_glass).is_true()
	(
		assert_array(failures.slice(0, 5))
		. override_failure_message(str(failures.slice(0, 5)))
		. is_empty()
	)


## The burst runs on its own (real) time: frames move it with no count-up running.
func test_the_burst_moves_in_real_time() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	await _counting(stage.monitor)
	burst.burst()
	burst.advance(STEP)
	var earlier: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.COINS)
	await get_tree().create_timer(0.2).timeout
	assert_array(burst.drawn_rects(TankBurst.Layer.COINS)).is_not_equal(earlier)
	assert_bool(burst.coin_count() > 0 or not burst.resting_coins().is_empty()).is_true()
	burst.clear()
	assert_bool(burst.is_active()).is_false()
	assert_vector(stage.monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)


## A landing's droplets jump off the gold's surface and sink back (gone within DROP_LIFE), and its
## sparkle (a spark and a ring of dust) pops round the given point; no coins, no shake.
func test_a_landing_jumps_droplets_and_sparkles() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	var monitor: MonitorView = stage.monitor
	await _counting(monitor)
	var origin: Vector2 = stage.get_global_rect().position
	var tank: GoldTank = monitor.led.gold_tank
	burst.surface_drops(tank.surface_points(6))
	burst.advance(STEP)
	var drops: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.PARTICLES)
	assert_int(drops.size()).is_equal(6)
	var group: Rect2 = tank.group_rect()
	group.position -= origin
	for rect: Rect2 in drops:
		assert_bool(group.grow(16.0).intersects(rect)).override_failure_message(str(rect)).is_true()
	burst.advance(TankBurst.DROP_LIFE)
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_empty()
	var middle: Vector2 = group.get_center()
	burst.sparkle(middle + origin)
	burst.advance(STEP)
	var sparkle: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.PARTICLES)
	assert_int(sparkle.size()).is_greater_equal(TankBurst.DUST_COUNT)
	for rect: Rect2 in sparkle:
		assert_bool(Rect2(middle, Vector2.ZERO).grow(40.0).intersects(rect)).is_true()
	burst.advance(TankBurst.SPARKLE_S)
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_empty()
	assert_int(burst.coin_count()).is_equal(0)
	assert_vector(burst.shake_offset()).is_equal(Vector2.ZERO)


## A landing past the quota: a short, lower fountain (after_fountain_s) and a few sparks, on the
## stage, with no shake and no splashes.
func test_a_spurt_is_a_small_fountain() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	await _counting(stage.monitor)
	var tune: CountUpTuning = burst.tuning()
	burst.spurt()
	var coins: int = 0
	for frame: int in range(roundi(0.6 / STEP)):
		burst.advance(STEP)
		coins = maxi(coins, burst.coin_count())
		for rect: Rect2 in burst.drawn_rects(TankBurst.Layer.COINS):
			assert_bool(TankBurst.STAGE_RECT.encloses(rect)).is_true()
	var most: int = ceili(tune.after_fountain_s * tune.after_fountain_rate) + 1
	assert_int(coins).is_between(1, most)
	assert_vector(burst.shake_offset()).is_equal(Vector2.ZERO)
	assert_array(burst.drawn_rects(TankBurst.Layer.SPLASHES)).is_empty()


## Reduced motion: the burst leaves STILL_SPLASHES on the bezel (off the paper) and nothing else;
## they stay. The spurt, the droplets, the sparkle and the shakes do nothing.
func test_reduced_motion_leaves_still_splashes() -> void:
	var stage: ShiftStage = await _stage()
	var burst: TankBurst = stage.tank_burst
	stage.monitor.reduced_motion = func() -> bool: return true
	await _counting(stage.monitor)
	burst.burst()
	burst.spurt()
	burst.surface_drops(stage.monitor.led.gold_tank.surface_points(6))
	burst.sparkle(stage.monitor.bay().landing_point())
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
		assert_array(burst.drawn_rects(TankBurst.Layer.COINS)).is_empty()
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


## The monitor's LED in the count layout, its number and € on the paper (where the gold leaves
## from).
func _counting(monitor: MonitorView) -> void:
	monitor.led.start_count(140, 140)
	monitor.led.show_subtotal(56, false)
	await get_tree().process_frame


## A stage in the window (the layer draws in its coordinates).
func _stage() -> ShiftStage:
	var stage: ShiftStage = auto_free(ShiftStage.new(7))
	get_tree().root.add_child(stage)
	await get_tree().process_frame
	return stage


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
