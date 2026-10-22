extends GdUnitTestSuite
## The tag's gold chips (#86 round 7, TallyChips): a chip's path starts with its right edge
## START_RIGHT px past where it is sent from and ends centred on its target, its arc ARC px up at
## its middle; it flies on make_tween's tweens, lands once (landed, with its id), then its spark
## and dust run in real time and go; clear() drops a chip in flight without landing it.

const STEP := 0.01
## A chip's target: the count's digits' middle on the stage (about where the monitor's chips
## land for a two-digit total, the monitor bay follow-up).
const NUMBER := Vector2(730, 137)

var _made: Array[Tween] = []


func before_test() -> void:
	_made.clear()


func test_the_path_runs_from_the_tag_into_the_number() -> void:
	var from: Vector2 = Vector2(600, 111)
	var to: Vector2 = NUMBER
	var width: float = TallyChips.chip_width("+€10")
	var start: Vector2 = from + Vector2(TallyChips.START_RIGHT - width / 2.0, 0.0)
	assert_vector(TallyChips.chip_centre(start, to, 0.0)).is_equal(start)
	assert_vector(TallyChips.chip_centre(start, to, 1.0)).is_equal_approx(to, Vector2(0.001, 0.001))
	var middle: Vector2 = TallyChips.chip_centre(start, to, 0.5)
	assert_float(middle.y).is_equal_approx((start.y + to.y) / 2.0 - TallyChips.ARC, 0.001)
	assert_float(width).is_greater(2.0 * (TallyChips.PAD_X + TallyChips.BORDER) + 10.0)


## A chip on the count's tweens: its box's right edge starts START_RIGHT px past the sender at
## SCALE_FROM; mid-flight it is in the air; it lands once on its target, emitting landed with its
## amount and id; its spark and dust then run in real time and go.
func test_a_chip_lands_once_then_dusts() -> void:
	var chips: TallyChips = _chips()
	var landings: Array[Array] = []
	chips.landed.connect(func(amount: int, chip: int) -> void: landings.append([amount, chip]))
	var from: Vector2 = Vector2(600, 111)
	var to: Vector2 = NUMBER
	var id: int = chips.fly(10, from, to, 0.2)
	var rects: Array[Rect2] = chips.chip_rects()
	assert_int(rects.size()).is_equal(1)
	var width: float = TallyChips.chip_width("+€10")
	var centre: float = from.x + TallyChips.START_RIGHT - width / 2.0
	assert_float(rects[0].get_center().x).is_equal_approx(centre, 0.001)
	assert_float(rects[0].size.y).is_equal_approx(TallyChips.HEIGHT * TallyChips.SCALE_FROM, 0.001)
	_advance(0.1)
	assert_float(chips.chip_rects()[0].get_center().y).is_less(minf(from.y, to.y))
	assert_array(landings).is_empty()
	_advance(0.1 + STEP)
	assert_array(landings).is_equal([[10, id]])
	assert_array(chips.chip_rects()).is_empty()
	assert_bool(chips.has_dust()).is_true()
	_advance(0.3)
	assert_array(landings).is_equal([[10, id]])
	await get_tree().create_timer(TallyChips.SPARK_S + 0.1).timeout
	assert_bool(chips.has_dust()).is_false()


## clear() drops the chips in flight: none lands.
func test_clear_drops_the_chips_without_landing() -> void:
	var chips: TallyChips = _chips()
	var landings: Array[int] = []
	chips.landed.connect(func(amount: int, _chip: int) -> void: landings.append(amount))
	chips.fly(5, Vector2(600, 111), NUMBER, 0.2)
	_advance(0.1)
	chips.clear()
	_advance(0.3)
	assert_array(landings).is_empty()
	assert_array(chips.chip_rects()).is_empty()
	assert_bool(chips.has_dust()).is_false()


func _chips() -> TallyChips:
	var chips: TallyChips = auto_free(TallyChips.new())
	add_child(chips)
	chips.make_tween = func() -> Tween:
		var tween: Tween = chips.create_tween()
		tween.pause()
		_made.append(tween)
		return tween
	return chips


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.00001:
		var step: float = minf(STEP, left)
		for tween: Tween in _made.duplicate():
			if tween.is_valid():
				tween.custom_step(step)
		left -= step
