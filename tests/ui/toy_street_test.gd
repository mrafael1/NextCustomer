extends GdUnitTestSuite
## The street through the TOY MACHINES' doors (v0.79): a car's glow crosses the glass behind the
## frames and leaves, cars come again on their own, the lamp flickers but never while a car
## passes, and `still` (reduced motion) holds both. The windows' art lines up with the doors.


func test_a_car_crosses_the_doors_and_leaves() -> void:
	var street: ToyStreet = _street()
	var glass: Rect2 = _glass()
	assert_bool(street.core().visible).is_false()
	street.pass_car(1)
	var lefts: Array[float] = []
	var elapsed: float = 0.0
	while elapsed < ToyStreet.SWEEP_TIME:
		assert_bool(street.core().visible).is_true()
		assert_bool(street.fringe().visible).is_true()
		var core: Rect2 = street.core().get_global_rect()
		lefts.append(core.position.x)
		# The core sits in its fringe and never past the doors' frame.
		assert_bool(street.fringe().get_global_rect().encloses(core)).is_true()
		assert_bool(core.end.x > glass.position.x - _fringe_px()).is_true()
		assert_bool(core.position.x < glass.end.x + _fringe_px()).is_true()
		# The art stays on the doors, wherever the window is.
		var view: Control = street.core().get_child(0) as Control
		assert_vector(view.global_position).is_equal(street.global_position)
		assert_float(fmod(core.position.x, ArtStyle.ART_SCALE)).is_equal(0.0)
		street._process(ToyStreet.SWEEP_STEP)
		elapsed += ToyStreet.SWEEP_STEP
	assert_bool(street.core().visible).is_false()
	assert_bool(street.fringe().visible).is_false()
	for index: int in range(1, lefts.size()):
		assert_float(lefts[index]).is_greater_equal(lefts[index - 1])
	assert_float(lefts.back()).is_greater(lefts.front())
	# The other way round, right to left.
	street.pass_car(-1)
	var first: float = street.core().get_global_rect().position.x
	street._process(ToyStreet.SWEEP_TIME / 2.0)
	assert_float(street.core().get_global_rect().position.x).is_less(first)


func test_cars_come_on_their_own() -> void:
	var street: ToyStreet = _street()
	street._process(ToyStreet.SWEEP_FIRST - 0.01)
	assert_bool(street.car_passing()).is_false()
	street._process(0.02)
	assert_bool(street.car_passing()).is_true()
	var cars: int = 1
	var was_passing: bool = true
	for tenth: int in roundi(ToyStreet.SWEEP_GAP.y * 3 * 10):
		street._process(0.1)
		if street.car_passing() and not was_passing:
			cars += 1
		was_passing = street.car_passing()
	assert_int(cars).is_greater_equal(3)


func test_the_lamp_flickers_but_not_under_a_car() -> void:
	var street: ToyStreet = _street()
	assert_bool(street.lamp_lit()).is_true()
	street._process(ToyStreet.LAMP_FRAME * (ToyStreet.LAMP_OFF[0] + 0.5))
	assert_bool(street.lamp_lit()).is_false()
	street.pass_car(1)
	assert_bool(street.lamp_lit()).is_true()


func test_still_holds_the_car_and_the_lamp() -> void:
	var street: ToyStreet = _street()
	street.still = true
	for tenth: int in roundi((ToyStreet.SWEEP_FIRST + ToyStreet.SWEEP_GAP.y) * 2 * 10):
		street._process(0.1)
		assert_bool(street.core().visible).is_false()
		assert_bool(street.lamp_lit()).is_true()
	street.pass_car(1)
	assert_bool(street.core().visible).is_false()


func test_the_street_lies_on_the_screen_s_doors() -> void:
	var screen: ToyMachinesScreen = auto_free(ToyMachinesScreen.new())
	var street: ToyStreet = screen.street()
	assert_object(street.get_parent()).is_same(screen.board().get_parent())
	assert_int(street.get_index()).is_less(screen.board().get_index())
	var layer: Rect2i = ToyExitArt.DOORS_LAYER
	assert_vector(street.position).is_equal(Vector2(layer.position) * ArtStyle.ART_SCALE)


func _street() -> ToyStreet:
	var street: ToyStreet = auto_free(ToyStreet.new())
	add_child(street)
	return street


## The doors' glass in the street's coordinates (the street sits at the stage's origin here).
func _glass() -> Rect2:
	return Rect2(
		Vector2(ToyExitArt.DOORS_RECT.position) * ArtStyle.ART_SCALE,
		Vector2(ToyExitArt.DOORS_RECT.size) * ArtStyle.ART_SCALE
	)


func _fringe_px() -> float:
	return (ToyStreet.CORE_WIDTH + 2 * ToyStreet.FRINGE_WIDTH) * ArtStyle.ART_SCALE
