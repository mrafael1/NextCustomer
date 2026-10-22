extends GdUnitTestSuite
## The scan overlay (#75; mock-up B2, #80): a hover brackets the sprite in tomato with a scan
## line across its middle, a count-up scan in gold with no line, and dock() clears the marks.
## There is no handheld scanner. Sprites are given as global rects, so a scaled row is marked
## where it is drawn, wherever the overlay sits. A hover's scan line pulses in a looping tween
## until the scan ends. The count-up's scanner (#86 v6) brackets the item at the scanner in
## gold with the scan line resting across its middle; its sweep runs the line from the item's
## foot to its top once (never looping, on the tween it is given), then rests it again, and stays
## still under reduced motion.

const STAGE := Rect2(0, 0, 1280, 720)
const STAGE_OFFSET := Vector2(0, 280)
const CELL_PITCH := 128.0
const BELT_SPRITE := Rect2(40, 298, 96, 96)

var _stage: Control
var _overlay: ScanOverlay


func before_test() -> void:
	_stage = auto_free(Control.new())
	_stage.position = STAGE_OFFSET
	_stage.size = STAGE.size
	add_child(_stage)
	_overlay = ScanOverlay.new()
	_overlay.size = STAGE.size
	_stage.add_child(_overlay)


func test_a_hover_marks_a_scaled_sprite_where_it_is_drawn() -> void:
	var row: Control = Control.new()
	row.position = Vector2(32, 268)
	row.scale = Vector2(0.8, 0.8)
	_stage.add_child(row)
	var sprite: Control = Control.new()
	sprite.position = Vector2(8 + 2 * CELL_PITCH, 30)
	sprite.size = Vector2(96, 96)
	row.add_child(sprite)
	var drawn: Rect2 = sprite.get_global_rect()
	assert_bool(_overlay.is_posed()).is_false()
	_overlay.pose_hover(drawn)
	assert_bool(_overlay.is_posed()).is_true()
	var brackets: Rect2 = _global(_overlay.brackets())
	assert_bool(brackets.is_equal_approx(drawn.grow(ScanOverlay.BRACKET_OUTSET))).is_true()
	assert_object(_overlay.bracket_color()).is_equal(Palette.TOMATO)
	# The scan line runs across the sprite's middle.
	var line: Rect2 = _global(_overlay.scan_line())
	assert_float(line.position.x).is_equal_approx(drawn.position.x, 0.01)
	assert_float(line.size.x).is_equal_approx(drawn.size.x, 0.01)
	assert_float(line.get_center().y).is_equal_approx(drawn.get_center().y, 0.01)
	assert_bool(drawn.encloses(line)).is_true()


func test_a_scan_is_gold_and_dock_clears_the_marks() -> void:
	var sprite: Rect2 = Rect2(BELT_SPRITE.position + STAGE_OFFSET, BELT_SPRITE.size)
	_overlay.pose_hover(sprite)
	_overlay.pose_scan(sprite)
	assert_object(_overlay.bracket_color()).is_equal(Palette.GOLD)
	assert_bool(_overlay.is_posed()).is_true()
	assert_bool(_overlay.scan_line().has_area()).is_false()
	_overlay.clear()
	assert_bool(_overlay.brackets().has_area()).is_false()
	assert_bool(_overlay.is_posed()).is_false()
	_overlay.pose_scan(sprite)
	_overlay.dock()
	assert_bool(_overlay.is_posed()).is_false()
	assert_bool(_overlay.brackets().has_area()).is_false()
	# Docking twice changes nothing.
	_overlay.dock()
	assert_bool(_overlay.is_posed()).is_false()


## A hover's scan line pulses in one looping tween (fading and back) until the scan ends or a
## count-up scan takes over; it is then back at full strength. Starting it twice runs one loop.
func test_the_beam_pulses_until_the_scan_ends() -> void:
	var sprite: Rect2 = Rect2(BELT_SPRITE.position + STAGE_OFFSET, BELT_SPRITE.size)
	_overlay.pose_hover(sprite)
	_overlay.start_beam_loop()
	_overlay.start_beam_loop()
	assert_bool(_overlay.has_beam_loop()).is_true()
	assert_int(_looping_tweens()).is_equal(1)
	await _wall_ms(int(ScanOverlay.BEAM_PULSE_S * 250.0))
	assert_float(_overlay._beam_strength).is_less(1.0)
	_overlay.clear()
	assert_bool(_overlay.has_beam_loop()).is_false()
	assert_int(_looping_tweens()).is_equal(0)
	assert_float(_overlay._beam_strength).is_equal(1.0)
	_overlay.pose_hover(sprite)
	_overlay.start_beam_loop()
	_overlay.pose_scan(sprite)
	assert_bool(_overlay.has_beam_loop()).is_false()
	_overlay.dock()


## The scanner's marks: gold brackets around the sprite and the scan line resting across its
## middle, tomato unless the count passes another colour; pose_scan keeps no line, and clear()
## takes both away.
func test_the_scanner_is_gold_with_a_resting_line() -> void:
	var sprite: Rect2 = Rect2(BELT_SPRITE.position + STAGE_OFFSET, BELT_SPRITE.size)
	_overlay.pose_hover(sprite)
	_overlay.start_beam_loop()
	_overlay.pose_scanner(sprite)
	assert_bool(_overlay.has_beam_loop()).is_false()
	assert_bool(_overlay.is_posed()).is_true()
	assert_object(_overlay.bracket_color()).is_equal(Palette.GOLD)
	assert_object(_overlay.line_color()).is_equal(Palette.TOMATO)
	var brackets: Rect2 = _global(_overlay.brackets())
	assert_bool(brackets.is_equal_approx(sprite.grow(ScanOverlay.BRACKET_OUTSET))).is_true()
	var line: Rect2 = _global(_overlay.scan_line())
	assert_float(line.position.x).is_equal_approx(sprite.position.x, 0.01)
	assert_float(line.size.x).is_equal_approx(sprite.size.x, 0.01)
	assert_float(line.size.y).is_equal(ScanOverlay.LINE_WIDTH)
	assert_float(line.get_center().y).is_equal_approx(sprite.get_center().y, 0.01)
	assert_bool(_overlay.is_sweeping()).is_false()
	_overlay.pose_scanner(sprite, Palette.GOOD)
	assert_object(_overlay.line_color()).is_equal(Palette.GOOD)
	# The count-up's plain scan still draws no line; a hover's line is tomato again.
	_overlay.pose_scan(sprite)
	assert_bool(_overlay.scan_line().has_area()).is_false()
	_overlay.pose_hover(sprite)
	assert_object(_overlay.line_color()).is_equal(Palette.TOMATO)
	_overlay.pose_scanner(sprite)
	_overlay.clear()
	assert_bool(_overlay.is_posed()).is_false()
	assert_bool(_overlay.scan_line().has_area()).is_false()


## sweep() runs the line once from the sprite's foot up to its top, in one tween that never
## loops, then rests it across the middle; clear() stops a sweep.
func test_the_sweep_rises_once_then_rests() -> void:
	var sprite: Rect2 = Rect2(BELT_SPRITE.position + STAGE_OFFSET, BELT_SPRITE.size)
	_overlay.pose_scanner(sprite)
	_overlay.sweep(0.3)
	assert_bool(_overlay.is_sweeping()).is_true()
	assert_int(_looping_tweens()).is_equal(0)
	var start: Rect2 = _global(_overlay.scan_line())
	assert_float(start.end.y).is_equal_approx(sprite.end.y, 1.0)
	var previous: float = start.position.y
	var highest: float = previous
	while _overlay.is_sweeping():
		await get_tree().process_frame
		var y: float = _global(_overlay.scan_line()).position.y
		if _overlay.is_sweeping():
			assert_float(y).is_less_equal(previous)
			assert_bool(sprite.grow(0.01).encloses(_global(_overlay.scan_line()))).is_true()
		previous = y
		highest = minf(highest, y)
	assert_float(highest).is_less_equal(sprite.position.y + sprite.size.y / 4.0)
	var rest: Rect2 = _global(_overlay.scan_line())
	assert_float(rest.get_center().y).is_equal_approx(sprite.get_center().y, 0.01)
	assert_bool(_overlay.is_posed()).is_true()
	# Stopped by clear().
	_overlay.pose_scanner(sprite)
	_overlay.sweep(0.3)
	_overlay.clear()
	assert_bool(_overlay.is_sweeping()).is_false()
	assert_bool(_overlay.scan_line().has_area()).is_false()


## Under reduced motion the sweep leaves the line still across the middle; with no line (a plain
## count-up scan, or nothing marked) it does nothing.
func test_the_sweep_stays_still_under_reduced_motion() -> void:
	var sprite: Rect2 = Rect2(BELT_SPRITE.position + STAGE_OFFSET, BELT_SPRITE.size)
	_overlay.pose_scanner(sprite)
	var tweens: int = get_tree().get_processed_tweens().size()
	_overlay.sweep(0.3, true)
	assert_bool(_overlay.is_sweeping()).is_false()
	assert_int(get_tree().get_processed_tweens().size()).is_equal(tweens)
	var line: Rect2 = _global(_overlay.scan_line())
	assert_float(line.get_center().y).is_equal_approx(sprite.get_center().y, 0.01)
	_overlay.pose_scan(sprite)
	_overlay.sweep(0.3)
	assert_bool(_overlay.is_sweeping()).is_false()
	_overlay.clear()
	_overlay.sweep(0.3)
	assert_bool(_overlay.is_sweeping()).is_false()


## The sweep runs on the tween make_tween gives (the count-up's, so its hit-stops hold it).
func test_the_sweep_uses_the_given_tween() -> void:
	var sprite: Rect2 = Rect2(BELT_SPRITE.position + STAGE_OFFSET, BELT_SPRITE.size)
	var made: Array[Tween] = []
	var make: Callable = func() -> Tween:
		var tween: Tween = _stage.create_tween()
		made.append(tween)
		return tween
	_overlay.pose_scanner(sprite)
	_overlay.sweep(0.2, false, make)
	assert_int(made.size()).is_equal(1)
	assert_bool(_overlay.is_sweeping()).is_true()
	made[0].custom_step(0.1)
	var halfway: Rect2 = _global(_overlay.scan_line())
	assert_float(halfway.position.y).is_less(sprite.end.y - ScanOverlay.LINE_WIDTH)
	assert_float(halfway.position.y).is_greater(sprite.position.y)
	made[0].custom_step(0.2)
	assert_bool(_overlay.is_sweeping()).is_false()
	assert_float(_global(_overlay.scan_line()).get_center().y).is_equal_approx(
		sprite.get_center().y, 0.01
	)


func _global(rect: Rect2) -> Rect2:
	return _overlay.get_global_transform() * rect


## How many looping tweens are running.
func _looping_tweens() -> int:
	var count: int = 0
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.get_loops_left() < 0:
			count += 1
	return count


func _wall_ms(ms: int) -> void:
	var until: int = Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
