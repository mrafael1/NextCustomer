extends GdUnitTestSuite
## The bay's price tag (#86 round 7, BayTag): its width grows in 2 px steps with its text; a
## count runs on make_tween's tweens (a frozen clock holds it, as a hit-stop does), turning paid
## as it starts; the pop and the swing decay to rest; the face takes the paid or unpaid colours;
## pay() turns it gold without changing its value; reduced motion shows every change at once.

const STEP := 0.01

var _made: Array[Tween] = []


func before_test() -> void:
	_made.clear()


## Wider texts take wider tags, always on the 2 px grid, never under MIN_WIDTH.
func test_the_width_grows_by_two_px_steps() -> void:
	var last: float = 0.0
	for value: int in [0, 9, 99, 999, 9999]:
		var width: float = BayTag.width_for("€%d" % value)
		assert_float(width).is_greater_equal(BayTag.MIN_WIDTH)
		assert_int(int(width) % 2).is_equal(0)
		assert_float(width).is_greater_equal(last)
		last = width
	assert_float(BayTag.width_for("€9999")).is_greater(BayTag.MIN_WIDTH)


## A count on the given tweens: nothing moves while its clock stands still (a hit-stop); stepped,
## it turns paid as it starts and reaches its value after COUNT_S; the pop and the swing decay to
## rest (scale 1, no turn).
func test_count_to_runs_on_the_count_tweens() -> void:
	var tag: BayTag = _tag()
	tag.show_value(4, false)
	tag.count_to(12, true, 0.1)
	assert_int(_made.size()).is_equal(1)
	assert_int(tag.value()).is_equal(4)
	assert_bool(tag.is_paid()).is_false()
	# A frozen clock: nothing moves.
	_advance(0.0)
	assert_int(tag.value()).is_equal(4)
	_advance(0.1 + STEP)
	assert_bool(tag.is_paid()).is_true()
	assert_array(tag.face_colours()).is_equal(BayTag.PAID_COLOURS)
	assert_float(tag.scale.x).is_greater(1.0)
	_advance(BayTag.COUNT_S / 2.0)
	assert_int(tag.value()).is_between(5, 11)
	_advance(BayTag.COUNT_S)
	assert_int(tag.value()).is_equal(12)
	assert_str(tag.text()).is_equal("€12")
	assert_float(tag.rotation_degrees).is_not_equal(0.0)
	_advance(BayTag.SWING_S)
	assert_vector(tag.scale).is_equal(Vector2.ONE)
	assert_float(tag.rotation_degrees).is_equal_approx(0.0, 0.001)
	# A denial: back to paper.
	tag.count_to(0, false, 0.0)
	_advance(BayTag.COUNT_S + STEP)
	assert_int(tag.value()).is_equal(0)
	assert_bool(tag.is_paid()).is_false()
	assert_array(tag.face_colours()).is_equal(BayTag.UNPAID_COLOURS)


## pay() turns a paper tag gold with a pop, its value unchanged; reduced motion shows a count at
## once with no pop; hide_tag() hides it.
func test_pay_and_reduced_motion() -> void:
	var tag: BayTag = _tag()
	var reduced: Array[bool] = [false]
	tag.reduced_motion = func() -> bool: return reduced[0]
	tag.show_value(7, false)
	tag.pay()
	assert_bool(tag.is_paid()).is_true()
	assert_int(tag.value()).is_equal(7)
	_advance(STEP)
	assert_float(tag.scale.x).is_greater(1.0)
	_advance(BayTag.POP_S)
	assert_vector(tag.scale).is_equal(Vector2.ONE)
	reduced[0] = true
	tag.count_to(30, true, 0.1)
	assert_int(tag.value()).is_equal(30)
	assert_vector(tag.scale).is_equal(Vector2.ONE)
	tag.hide_tag()
	assert_bool(tag.visible).is_false()


## The face: ink on the edge, the colours of its look inside, the hole ink; the paid and unpaid
## looks are the palette's gold and paper ramps.
func test_the_face_takes_its_looks_colours() -> void:
	assert_array(BayTag.PAID_COLOURS).is_equal(
		[Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD]
	)
	assert_array(BayTag.UNPAID_COLOURS).is_equal(
		[Palette.PAPER, Palette.PAPER, Palette.CREAM_SHADE]
	)
	var across: int = 26
	var colours: Array[Color] = BayTag.PAID_COLOURS
	assert_that(BayTag._shade(5, 0, across, colours)).is_equal(BayTag.INK_COLOR)
	assert_that(BayTag._shade(10, 1, across, colours)).is_equal(colours[0])
	assert_that(BayTag._shade(10, 5, across, colours)).is_equal(colours[1])
	assert_that(BayTag._shade(10, 9, across, colours)).is_equal(colours[2])
	# The chamfer: the left end's corners are outside.
	assert_bool(BayTag._in(0, 0, across)).is_false()
	assert_bool(BayTag._in(0, 5, across)).is_true()
	assert_bool(BayTag._in(across, 5, across)).is_false()


## A tag in the tree, its tweens made paused for _advance.
func _tag() -> BayTag:
	var tag: BayTag = auto_free(BayTag.new())
	add_child(tag)
	tag.make_tween = func() -> Tween:
		var tween: Tween = tag.create_tween()
		tween.pause()
		_made.append(tween)
		return tween
	return tag


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.00001:
		var step: float = minf(STEP, left)
		for tween: Tween in _made.duplicate():
			if tween.is_valid():
				tween.custom_step(step)
		left -= step
