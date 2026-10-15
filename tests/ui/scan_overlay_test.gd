extends GdUnitTestSuite
## The scan overlay (#75): a hover brackets the sprite in tomato and a count-up scan in gold, the
## handheld leaves its cradle for its posed look overhead beside the sprite (flipped to the left
## on request) with its beam across the sprite, and dock() puts it back exactly where and as it
## was, in front of nothing it was behind. Sprites are given as global rects, so a scaled row is
## marked where it is drawn, wherever the overlay sits. Posed over any belt cell or hand position
## of style frame v2's stage, the scanner stays inside 1280x720 and under the top bar. A hover's
## beam pulses in a looping tween until the scan ends.

const STAGE := Rect2(0, 0, 1280, 720)
const STAGE_OFFSET := Vector2(0, 280)
const HANDHELD := preload("res://art/scenery/scanner_handheld.png")
const CRADLE := preload("res://art/scenery/scanner_cradle.png")
const CRADLE_RECT := Rect2(880, 318, 60, 54)
const DOCKED := Rect2(2, 0, 56, 32)
## Style frame v2's stage (the layout the shift screen adopts in #75): the lifted sprites of the
## belt's cells and of the tray's, and the top bar's foot.
const BELT_SPRITE := Rect2(44, 98, 96, 96)
const CELL_PITCH := 124.0
const CELL_COUNT := 7
const TRAY_SPRITE := Rect2(28, 412, 96, 96)
const TRAY_PITCH := 112.0
const TRAY_COUNT := 8
const TOP_BAR_BOTTOM := 64.0

var _stage: Control
var _cradle: Control
var _handheld: TextureRect
var _overlay: ScanOverlay


func before_test() -> void:
	_stage = auto_free(Control.new())
	_stage.position = STAGE_OFFSET
	_stage.size = STAGE.size
	add_child(_stage)
	_cradle = Control.new()
	_cradle.position = CRADLE_RECT.position
	_cradle.size = CRADLE_RECT.size
	_stage.add_child(_cradle)
	_handheld = UiKit.sprite(HANDHELD)
	_handheld.position = DOCKED.position
	_handheld.size = DOCKED.size
	_cradle.add_child(_handheld)
	var front: TextureRect = UiKit.sprite(CRADLE)
	front.size = CRADLE_RECT.size
	_cradle.add_child(front)
	_overlay = ScanOverlay.new()
	_overlay.size = STAGE.size
	_stage.add_child(_overlay)
	_overlay.set_handheld(_handheld)


func test_a_hover_marks_a_scaled_sprite_where_it_is_drawn() -> void:
	var row: Control = Control.new()
	row.position = Vector2(16, 68)
	row.scale = Vector2(0.8, 0.8)
	_stage.add_child(row)
	var sprite: Control = Control.new()
	sprite.position = Vector2(12 + 2 * CELL_PITCH, 22)
	sprite.size = Vector2(96, 96)
	row.add_child(sprite)
	var drawn: Rect2 = sprite.get_global_rect()
	assert_bool(_overlay.is_posed()).is_false()
	_overlay.pose_hover(drawn, false)
	assert_bool(_overlay.is_posed()).is_true()
	var brackets: Rect2 = _global(_overlay.brackets())
	assert_bool(brackets.is_equal_approx(drawn.grow(ScanOverlay.BRACKET_OUTSET))).is_true()
	assert_object(_overlay.bracket_color()).is_equal(Palette.TOMATO)
	assert_object(_handheld.get_parent()).is_same(_overlay)
	assert_object(_handheld.texture).is_same(ScanOverlay.SCANNER_AIM)
	assert_bool(_handheld.flip_h).is_false()
	var scanner: Rect2 = _handheld.get_global_rect()
	(
		assert_bool(scanner.is_equal_approx(ScanOverlay.scanner_rect(drawn, false)))
		. override_failure_message(str(scanner))
		. is_true()
	)
	# The beam leaves the scanner's window and fans to the sprite's far (left) edge.
	var beam: PackedVector2Array = _overlay.beam()
	assert_int(beam.size()).is_equal(3)
	var nose: Vector2 = scanner.position + ScanOverlay.NOSE
	assert_bool(_global_point(beam[0]).is_equal_approx(nose)).is_true()
	for point: Vector2 in [beam[1], beam[2]]:
		var at: Vector2 = _global_point(point)
		assert_float(at.x).is_equal_approx(drawn.position.x + ScanOverlay.CONE_INSET, 0.01)
		assert_bool(drawn.has_point(at)).is_true()


func test_a_hover_can_stand_the_scanner_on_the_left() -> void:
	var third: Vector2 = TRAY_SPRITE.position + Vector2(2 * TRAY_PITCH, 0)
	var sprite: Rect2 = Rect2(third + STAGE_OFFSET, TRAY_SPRITE.size)
	_overlay.pose_hover(sprite, true)
	assert_bool(_handheld.flip_h).is_true()
	var scanner: Rect2 = _handheld.get_global_rect()
	assert_bool(scanner == ScanOverlay.scanner_rect(sprite, true)).is_true()
	assert_float(scanner.end.x - sprite.position.x).is_equal(ScanOverlay.SCANNER_TUCK)
	var nose: Vector2 = _global_point(_overlay.beam()[0])
	assert_float(nose.x).is_equal(scanner.end.x - ScanOverlay.NOSE.x)
	assert_float(_global_point(_overlay.beam()[1]).x).is_equal(
		sprite.end.x - ScanOverlay.CONE_INSET
	)


func test_a_scan_is_gold_and_dock_puts_the_handheld_back() -> void:
	var sprite: Rect2 = Rect2(BELT_SPRITE.position + STAGE_OFFSET, BELT_SPRITE.size)
	_overlay.pose_hover(sprite, true)
	_overlay.pose_scan(sprite)
	assert_object(_overlay.bracket_color()).is_equal(Palette.GOLD)
	assert_bool(_handheld.flip_h).is_false()
	assert_bool(_handheld.get_global_rect() == ScanOverlay.scanner_rect(sprite, false)).is_true()
	_overlay.clear()
	assert_bool(_overlay.brackets().has_area()).is_false()
	assert_int(_overlay.beam().size()).is_equal(0)
	assert_bool(_overlay.is_posed()).is_true()
	_overlay.pose_scan(sprite)
	_overlay.dock()
	assert_bool(_overlay.is_posed()).is_false()
	assert_bool(_overlay.brackets().has_area()).is_false()
	assert_int(_overlay.beam().size()).is_equal(0)
	# Back behind the cradle's front, in its docked look and place.
	assert_object(_handheld.get_parent()).is_same(_cradle)
	assert_int(_handheld.get_index()).is_equal(0)
	assert_object(_handheld.texture).is_same(HANDHELD)
	assert_bool(_handheld.flip_h).is_false()
	var docked: Rect2 = Rect2(CRADLE_RECT.position + DOCKED.position + STAGE_OFFSET, DOCKED.size)
	(
		assert_bool(_handheld.get_global_rect() == docked)
		. override_failure_message(str(_handheld.get_global_rect()))
		. is_true()
	)
	# Docking twice changes nothing.
	_overlay.dock()
	assert_object(_handheld.get_parent()).is_same(_cradle)


## A hover's beam pulses in one looping tween (its cone fading and back) until the scan ends or
## a count-up scan takes the scanner; the cone is then back at full strength. Starting it twice
## runs one loop.
func test_the_beam_pulses_until_the_scan_ends() -> void:
	var sprite: Rect2 = Rect2(BELT_SPRITE.position + STAGE_OFFSET, BELT_SPRITE.size)
	_overlay.pose_hover(sprite, false)
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
	_overlay.pose_hover(sprite, false)
	_overlay.start_beam_loop()
	_overlay.pose_scan(sprite)
	assert_bool(_overlay.has_beam_loop()).is_false()
	_overlay.dock()


## Over every belt cell and hand position the posed scanner stays inside the stage and under
## the top bar, on the side asked for unless that side would leave the stage.
func test_the_posed_scanner_stays_in_the_stage() -> void:
	var sprites: Array[Rect2] = []
	for index: int in range(CELL_COUNT):
		sprites.append(
			Rect2(BELT_SPRITE.position + Vector2(index * CELL_PITCH, 0), BELT_SPRITE.size)
		)
	for index: int in range(TRAY_COUNT):
		sprites.append(
			Rect2(TRAY_SPRITE.position + Vector2(index * TRAY_PITCH, 0), TRAY_SPRITE.size)
		)
	for sprite: Rect2 in sprites:
		for on_left: bool in [false, true]:
			_overlay.pose_hover(Rect2(sprite.position + STAGE_OFFSET, sprite.size), on_left)
			var scanner: Rect2 = _handheld.get_global_rect()
			scanner.position -= STAGE_OFFSET
			var message: String = "%s %s: %s" % [sprite, on_left, scanner]
			assert_bool(STAGE.encloses(scanner)).override_failure_message(message).is_true()
			assert_float(scanner.position.y).override_failure_message(message).is_greater_equal(
				TOP_BAR_BOTTOM
			)
			assert_bool(scanner.intersects(sprite)).override_failure_message(message).is_false()
			var asked: bool = STAGE.encloses(ScanOverlay.scanner_rect(sprite, on_left))
			assert_bool(_handheld.flip_h == on_left).override_failure_message(message).is_equal(
				asked
			)


func _global(rect: Rect2) -> Rect2:
	return _overlay.get_global_transform() * rect


func _global_point(point: Vector2) -> Vector2:
	return _overlay.get_global_transform() * point


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
