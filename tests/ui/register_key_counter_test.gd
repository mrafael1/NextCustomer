extends GdUnitTestSuite
## The Redraw key's counter window (RegisterKey.CounterWindow, the PR #138 left UI: "the number is
## its own part and not just on the redraw button"): the key's footprint splits into the counter
## window at its left and the pressable face right of it. The face takes every state (lit, down,
## disabled, held: the LIT and OFF frames, the sink, the shadow) and every click; the counter is a
## display that keeps its place, its colours and its full strength whatever the face does. A key
## without a count is all face. RedrawNotice.caption_key puts each redraw state on the key.

const KEY_SIZE := Vector2(198, 54)

var _key: RegisterKey


func before_test() -> void:
	_key = RegisterKey.new(RegisterKey.Kind.CREAM, "", 18, KEY_SIZE)
	add_child(_key)
	_key.size = KEY_SIZE


func after_test() -> void:
	_key.free()


## The face's states never touch the counter: the same rect, colours, look and strength in every
## state, while the face changes frame, sinks and fades its caption. Only the face takes clicks.
func test_the_counter_is_a_display_beside_the_face() -> void:
	var color: Color = RedrawNotice.count_color(2)
	_key.show_caption(RedrawNotice.REDRAW_CAPTION, "2", "Redraw (2 left)", color)
	await await_idle_frame()
	var counter: RegisterKey.CounterWindow = _key.counter()
	var counter_rect: Rect2 = counter.get_rect()
	assert_that(counter_rect).is_equal(Rect2(0, 0, RegisterKey.COUNTER_WIDTH, KEY_SIZE.y))
	var face_left: float = RegisterKey.COUNTER_WIDTH + RegisterKey.COUNTER_GAP
	assert_that(_key.face_rect()).is_equal(Rect2(face_left, 0, KEY_SIZE.x - face_left, KEY_SIZE.y))
	var states: Array[String] = ["normal", "lit", "down", "disabled", "held"]
	var looks: Array[RegisterKey.Look] = [
		RegisterKey.Look.NORMAL,
		RegisterKey.Look.LIT,
		RegisterKey.Look.LIT,
		RegisterKey.Look.OFF,
		RegisterKey.Look.OFF,
	]
	for index: int in range(states.size()):
		_set_state(states[index])
		await await_idle_frame()
		var why: String = states[index]
		assert_int(_key.look()).override_failure_message(why).is_equal(looks[index])
		var sunk: float = RegisterKey.SINK if index > 1 else 0.0
		assert_float(_key.face().offset_top).override_failure_message(why).is_equal(sunk)
		assert_float(_key.face().offset_left).override_failure_message(why).is_equal(face_left)
		assert_that(counter.get_rect()).override_failure_message(why).is_equal(counter_rect)
		assert_object(counter.colour).override_failure_message(why).is_equal(color)
		assert_object(counter.digits.color).override_failure_message(why).is_equal(color)
		assert_bool(counter.alert).override_failure_message(why).is_false()
		assert_that(counter.modulate).override_failure_message(why).is_equal(Color.WHITE)
		assert_that(_key.modulate).override_failure_message(why).is_equal(Color.WHITE)
		var faded: bool = looks[index] == RegisterKey.Look.OFF
		var alpha: float = RegisterKey.OFF_CAPTION_ALPHA if faded else 1.0
		assert_float(_key.caption_label().modulate.a).is_equal_approx(alpha, 0.001)
	_set_state("normal")
	assert_bool(_key._has_point(counter_rect.get_center())).is_false()
	assert_bool(_key._has_point(_key.face_rect().get_center())).is_true()
	assert_int(counter.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## A count of 0 (ALERT) reads "none left" without its colour: the unlit pane and the digit
## struck. A key without a count is all face, and a count taken away gives the face its room back.
func test_the_alert_count_and_a_key_without_one() -> void:
	_key.show_caption("Cancel")
	assert_object(_key.counter()).is_null()
	assert_str(_key.note()).is_equal("")
	assert_that(_key.face_rect()).is_equal(Rect2(Vector2.ZERO, KEY_SIZE))
	_key.show_caption("REDRAW", "0", "", Palette.TOMATO_DARK, RegisterKey.NoteLook.ALERT)
	await await_idle_frame()
	assert_bool(_key.counter().alert).is_true()
	assert_str(_key.note()).is_equal("0")
	assert_str(_key.accessibility_name).is_equal("REDRAW, 0")
	assert_float(_key.face().offset_left).is_greater(RegisterKey.COUNTER_WIDTH)
	_key.show_caption("Cancel")
	await await_idle_frame()
	assert_bool(_key.counter().visible).is_false()
	assert_str(_key.note()).is_equal("")
	assert_float(_key.face().offset_left).is_equal(0.0)
	assert_bool(_key._has_point(Vector2(4, 4))).is_true()


## Each redraw state's caption, count, look and spoken name (RedrawNotice.caption_key): the count
## always in the counter in count_color, "(N left)" always heard.
func test_each_redraw_state_captions_the_key() -> void:
	var cases: Array[Array] = [
		[false, 2, true, RedrawNotice.REDRAW_CAPTION],
		[false, 1, true, RedrawNotice.REDRAW_CAPTION],
		[false, 0, true, RedrawNotice.REDRAW_CAPTION],
		[true, 2, true, RedrawNotice.PICK_CAPTION],
		[false, 2, false, RedrawNotice.EMPTY_CAPTION],
	]
	for case: Array in cases:
		var left: int = case[1] as int
		RedrawNotice.caption_key(_key, case[0] as bool, left, case[2] as bool)
		var why: String = str(case)
		assert_str(_key.caption).override_failure_message(why).is_equal(case[3] as String)
		assert_str(_key.note()).override_failure_message(why).is_equal("%d" % left)
		var color: Color = RedrawNotice.count_color(left)
		assert_object(_key.counter().colour).override_failure_message(why).is_equal(color)
		assert_bool(_key.counter().alert).override_failure_message(why).is_equal(left == 0)
		var spoken: String = _key.accessibility_name
		assert_str(spoken).override_failure_message(why).contains("(%d left)" % left)


func _set_state(state: String) -> void:
	_key.lit = state == "lit"
	_key.down = state == "down"
	_key.disabled = state == "disabled"
	_key.held = state == "held"
