extends GdUnitTestSuite
## The tutorial's overlay kit (tutorial plan WP-2, mock-up docs/art/mockups/tutorial.html), built
## against StepViews with no game behind them: the dim's holes let clicks through to the ringed
## targets and the rest of the screen is blocked (a click there, or on a LOCKED plate, shakes the
## callout); the callout opens beside its ring, inside the screen at 1280x720 and 1920x1080, never
## over a ring, its words inside its paper; the header, count and footer follow the step's kind;
## the LOCKED plates fit their pill; rings follow their anchors as they move; reduced motion holds
## the pulse, the fade and the shake; Enter and Space press the callout's key (never on a move's
## step); the text size grows the body and the card. Clicks are sent to the handlers, because
## headless runs don't deliver input events.

const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
const LONG_TEXT := (
	"Eggs: the NEXT Food item, anywhere later, pays {x2}. Try Eggs in slot 3. [WASTED] means"
	+ " the rule did nothing, so order is the whole game."
)

var _folder: String = ""
var _host: Control
var _reading_scale: float = 1.0


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_reading_scale = UiKit.reading_scale
	_host = auto_free(Control.new())
	_host.name = "Host"
	add_child(_host)


func after_test() -> void:
	UiKit.reading_scale = _reading_scale
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A click inside a ring's hole reaches the target under the overlay; a click on another control
## is taken by the shade (outside_clicked: the callout shakes), and so is one on a LOCKED plate.
func test_holes_let_clicks_through_and_the_rest_is_blocked() -> void:
	_host.size = WINDOWS[0]
	var target: Button = _button(Rect2(500, 400, 120, 60))
	var other: Button = _button(Rect2(100, 100, 120, 60))
	var locked: Button = _button(Rect2(900, 600, 200, 60))
	var overlay: TutorialOverlay = _overlay()
	var view: StepView = StepView.guided(10, 26, "Drag Bread to slot 1.", true)
	view.ring(&"", target.get_global_rect(), true).lock(&"", locked.get_global_rect())
	overlay.show_view(view)
	await _frames(2)
	assert_array(_blockers(target)).is_empty()
	assert_array(_blockers(other)).contains([str(overlay.shade().get_path())])
	var plate: LockPlate = overlay.locks()[0]
	assert_array(_blockers(locked)).contains([str(plate.get_path())])
	# The hole is the ring's rect, round the target.
	var hole: Rect2 = overlay.shade().holes()[0]
	assert_bool(hole.encloses(target.get_global_rect())).is_true()
	assert_bool(overlay.shade().in_hole(target.get_global_rect().get_center())).is_true()
	# The dim covers the rest, never the hole.
	for rect: Rect2 in overlay.shade().shaded_rects():
		assert_bool(rect.intersects(hole)).is_false()
	var outside: Array[int] = [0]
	overlay.outside_clicked.connect(func() -> void: outside[0] += 1)
	overlay.shade().call("_gui_input", _left_click())
	assert_int(outside[0]).is_equal(1)
	assert_bool(overlay.callout().is_shaking()).is_true()
	plate.call("_gui_input", _left_click())
	assert_int(outside[0]).is_equal(2)
	overlay.clear()
	assert_bool(overlay.is_showing()).is_false()
	assert_array(_blockers(other)).is_empty()


## At both sizes, for targets at the screen's corners, edges and middle and every side asked: the
## callout (its shadow too) lies MARGIN inside the screen, covers none of the rings, and its
## header, body and footer lie inside its paper, apart; its tail shows on the side facing its ring.
func test_the_callout_stays_on_screen_and_clear_of_its_rings() -> void:
	for window: Vector2 in WINDOWS:
		_host.size = window
		var overlay: TutorialOverlay = _overlay()
		var inside: Rect2 = Rect2(Vector2.ZERO, window).grow(-TipCard.MARGIN + 0.5)
		for at: Vector2 in _spots(window):
			for side: StepView.Opening in StepView.Opening.values():
				var target: Rect2 = Rect2(at, Vector2(140, 90))
				var view: StepView = StepView.guided(14, 26, LONG_TEXT, true)
				view.ring(&"", target, true).ring(&"", Rect2(window.x / 2.0 - 30, 20, 60, 40))
				view.side = side
				overlay.show_view(view)
				await _frames(1)
				var label: String = "%s %s side %d" % [window, at, side]
				var callout: TutorialCallout = overlay.callout()
				var card: Rect2 = callout.get_global_rect()
				var shadowed: Rect2 = card.merge(Rect2(card.position + TipCard.SHADOW, card.size))
				assert_bool(inside.encloses(shadowed)).override_failure_message(label).is_true()
				for ring: TutorialRing in overlay.rings():
					var ringed: Rect2 = ring.get_global_rect()
					(
						assert_bool(shadowed.intersects(ringed))
						. override_failure_message(label)
						. is_false()
					)
				_assert_fits(callout, label)
				assert_bool(callout.tail().visible).is_true()
		overlay.queue_free()
		await _frames(1)


## The header and footer follow the step: a guided move reads YOUR MOVE, n/26 and CLICK THE RING
## (no key, no link); a guided step without a move NEXT ›, its last GOT IT; a one-time tip NEW ·
## TITLE, ONCE, MORE › its page (more_pressed names it) and GOT IT on the mustard band; a quick
## tutorial its n/total on the teal-light band.
func test_the_header_and_footer_follow_the_step_kind() -> void:
	_host.size = WINDOWS[0]
	var overlay: TutorialOverlay = _overlay()
	var target: Rect2 = Rect2(600, 300, 100, 80)
	overlay.show_view(StepView.guided(3, 26, "Click a [PAIR].", true).ring(&"", target, true))
	await _frames(1)
	var callout: TutorialCallout = overlay.callout()
	assert_str(callout.header_title().text).is_equal(StepView.YOUR_MOVE)
	assert_str(callout.count_title().text).is_equal("3/26")
	assert_object(callout.key()).is_null()
	assert_object(callout.link()).is_null()
	assert_object(callout.hint()).is_not_null()
	assert_str(callout.callout_text()).contains(StepView.CLICK_HINT)
	assert_object(callout.band_colour()).is_equal(Palette.MUSTARD)
	assert_bool(overlay.rings()[0].act).is_true()
	assert_bool(overlay.rings()[0].tab().visible).is_true()
	overlay.show_view(StepView.guided(9, 26, "Reach the ~quota|QUOTA~.", false).ring(&"", target))
	await _frames(1)
	assert_str(callout.header_title().text).is_equal(StepView.TIP_HEAD)
	assert_str(callout.key().caption).is_equal(StepView.NEXT_CAPTION)
	assert_object(callout.hint()).is_null()
	assert_bool(overlay.rings()[0].tab().visible).is_false()
	overlay.show_view(StepView.guided(26, 26, "That's the basics!", false).ring(&"", target))
	await _frames(1)
	assert_str(callout.key().caption).is_equal(StepView.GOT_IT_CAPTION)
	var tip: StepView = StepView.tip("Redraw", "Bad cards? Press REDRAW.", "Redraw", &"redraw")
	overlay.show_view(tip.ring(&"", target))
	await _frames(1)
	assert_str(callout.header_title().text).is_equal("NEW · REDRAW")
	assert_str(callout.count_title().text).is_equal(StepView.ONCE)
	assert_str(callout.key().caption).is_equal(StepView.GOT_IT_CAPTION)
	assert_object(callout.link()).is_not_null()
	assert_str(callout.callout_text()).contains("MORE › REDRAW")
	# The pixel font draws the link's arrow.
	assert_bool(ArtStyle.pixel_display_font().has_char("›".unicode_at(0))).is_true()
	var pages: Array[StringName] = []
	overlay.more_pressed.connect(func(page: StringName) -> void: pages.append(page))
	callout.link().pressed.emit()
	assert_array(pages).is_equal([&"redraw"])
	var quick: StepView = StepView.quick(
		"Restock", 2, 4, "Click RETURN THIS ONE.", false, "Restock", &"restock"
	)
	overlay.show_view(quick.ring(&"", target))
	await _frames(1)
	assert_str(callout.count_title().text).is_equal("2/4")
	assert_object(callout.band_colour()).is_equal(Palette.TEAL_LIGHT)
	assert_str(callout.key().caption).is_equal(StepView.NEXT_CAPTION)
	_assert_fits(callout, "quick")


## Enter, the keypad's Enter and Space press the callout's key (and are taken); on a move's step
## (no key) they pass; Esc is never taken.
func test_enter_and_space_press_the_key() -> void:
	_host.size = WINDOWS[0]
	var overlay: TutorialOverlay = _overlay()
	var presses: Array[int] = [0]
	overlay.button_pressed.connect(func() -> void: presses[0] += 1)
	overlay.show_view(StepView.guided(2, 26, "These are your regulars.", false))
	await _frames(1)
	for keycode: Key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		overlay.call("_input", _key(keycode))
	assert_int(presses[0]).is_equal(3)
	overlay.call("_input", _key(KEY_ESCAPE))
	assert_int(presses[0]).is_equal(3)
	overlay.callout().key().pressed.emit()
	assert_int(presses[0]).is_equal(4)
	var target: Rect2 = Rect2(600, 300, 100, 80)
	overlay.show_view(StepView.guided(3, 26, "Click a booster.", true).ring(&"", target, true))
	await _frames(1)
	overlay.call("_input", _key(KEY_ENTER))
	overlay.call("_input", _key(KEY_SPACE))
	assert_int(presses[0]).is_equal(4)


## Motion on: the dim fades in, the ring pulses gold to mustard pale in 4 steps, a refused move
## shakes the callout. Reduced motion: the dim is up at once, the ring stays gold, the callout
## never moves.
func test_reduced_motion_holds_the_pulse_fade_and_shake() -> void:
	_host.size = WINDOWS[0]
	var reduced: Array[bool] = [false]
	var overlay: TutorialOverlay = _overlay()
	overlay.reduced_motion = func() -> bool: return reduced[0]
	var target: Rect2 = Rect2(600, 300, 100, 80)
	overlay.show_view(StepView.guided(11, 26, "Bread pays its price.", false).ring(&"", target))
	assert_float(overlay.modulate.a).is_less(1.0)
	var ring: TutorialRing = overlay.rings()[0]
	var colours: Array[Color] = []
	for step: int in range(TutorialRing.PULSE_STEPS):
		ring.set_time(TutorialRing.PULSE_S * (step + 0.5) / TutorialRing.PULSE_STEPS)
		colours.append(ring.gold())
	assert_object(colours[0]).is_equal(Palette.GOLD)
	assert_object(colours[2]).is_equal(Palette.MUSTARD_PALE)
	assert_object(colours[1]).is_equal(colours[3])
	overlay.refuse()
	assert_bool(overlay.callout().is_shaking()).is_true()
	await _frames(1)
	overlay.clear()
	reduced[0] = true
	overlay.show_view(StepView.guided(11, 26, "Bread pays its price.", false).ring(&"", target))
	assert_float(overlay.modulate.a).is_equal(1.0)
	ring = overlay.rings()[0]
	for step: int in range(TutorialRing.PULSE_STEPS):
		ring.set_time(TutorialRing.PULSE_S * (step + 0.5) / TutorialRing.PULSE_STEPS)
		assert_object(ring.gold()).is_equal(Palette.GOLD)
	var home: Vector2 = overlay.callout().position
	overlay.refuse()
	for _frame: int in range(4):
		await get_tree().process_frame
		assert_object(overlay.callout().position).is_equal(home)


## Rings and locks named by an anchor id follow it: a rect that moves moves its ring, its hole and
## the callout; an anchor not shown hides its ring.
func test_rings_follow_their_anchors() -> void:
	_host.size = WINDOWS[0]
	var rects: Dictionary[StringName, Rect2] = {
		&"slot0": Rect2(400, 400, 100, 120), &"redraw": Rect2(20, 600, 160, 50)
	}
	var overlay: TutorialOverlay = _overlay()
	overlay.anchors = func(id: StringName) -> Rect2: return rects.get(id, Rect2())
	var view: StepView = StepView.guided(10, 26, "Drag Bread to slot 1.", true)
	overlay.show_view(view.ring(&"slot0", Rect2(), true).ring(&"cheese").lock(&"redraw"))
	await _frames(1)
	var ring: TutorialRing = overlay.rings()[0]
	assert_bool(ring.get_global_rect().encloses(rects[&"slot0"])).is_true()
	assert_bool(overlay.rings()[1].visible).is_false()
	assert_bool(overlay.locks()[0].get_global_rect().is_equal_approx(rects[&"redraw"])).is_true()
	rects[&"slot0"] = Rect2(700, 200, 100, 120)
	await _frames(2)
	assert_bool(ring.get_global_rect().encloses(rects[&"slot0"])).is_true()
	assert_bool(overlay.shade().holes()[0].encloses(rects[&"slot0"])).is_true()
	var card: Rect2 = overlay.callout().get_global_rect()
	assert_bool(card.intersects(ring.get_global_rect())).is_false()


## The callout keeps off the LOCKED plates when a side has room: asked below its ring, over a
## plate, it opens on another side.
func test_the_callout_keeps_off_the_locks() -> void:
	_host.size = WINDOWS[0]
	var overlay: TutorialOverlay = _overlay()
	var target: Rect2 = Rect2(560, 300, 120, 80)
	var plate: Rect2 = Rect2(400, 400, 480, 200)
	var view: StepView = StepView.guided(9, 26, LONG_TEXT, false)
	view.ring(&"", target).lock(&"", plate)
	view.side = StepView.Opening.BELOW
	overlay.show_view(view)
	await _frames(1)
	var card: Rect2 = overlay.callout().get_global_rect()
	assert_bool(card.intersects(plate)).is_false()
	assert_bool(card.intersects(overlay.rings()[0].get_global_rect())).is_false()


## A pass lets a click through to its control with no ring and no hole (the dim stays on it): the
## menu on a guided step; the rest of the screen is still the shade's.
func test_a_pass_lets_a_click_through_and_stays_dimmed() -> void:
	_host.size = WINDOWS[0]
	var target: Button = _button(Rect2(500, 400, 120, 60))
	var menu: Button = _button(Rect2(1220, 9, 44, 42))
	var other: Button = _button(Rect2(100, 100, 120, 60))
	var overlay: TutorialOverlay = _overlay()
	var view: StepView = StepView.guided(10, 26, "Drag Bread to slot 1.", true)
	view.ring(&"", target.get_global_rect(), true).pass_through(&"", menu.get_global_rect())
	overlay.show_view(view)
	await _frames(2)
	assert_array(_blockers(menu)).is_empty()
	assert_array(_blockers(other)).contains([str(overlay.shade().get_path())])
	assert_int(overlay.rings().size()).is_equal(1)
	assert_int(overlay.shade().holes().size()).is_equal(1)
	var dimmed: bool = false
	for rect: Rect2 in overlay.shade().shaded_rects():
		dimmed = dimmed or rect.encloses(menu.get_global_rect())
	assert_bool(dimmed).is_true()
	assert_array(overlay.pass_rects()).is_equal([menu.get_global_rect()] as Array[Rect2])
	# A view with no pass takes the click again.
	overlay.show_view(StepView.guided(10, 26, "Drag Bread.", true).ring(&"", Rect2(500, 400, 9, 9)))
	await _frames(1)
	assert_array(_blockers(menu)).contains([str(overlay.shade().get_path())])


## The callout keeps off what the view keeps clear when a side has room (G19's Bananas on the
## belt above its rings), even against the side asked; with no room it falls back to the rings
## alone.
func test_the_callout_keeps_off_what_is_kept_clear() -> void:
	_host.size = WINDOWS[0]
	var overlay: TutorialOverlay = _overlay()
	var target: Rect2 = Rect2(880, 458, 108, 76)
	var item: Rect2 = Rect2(876, 292, 116, 160)
	var view: StepView = StepView.guided(19, 26, LONG_TEXT, false)
	view.ring(&"", target).keep_clear(&"", item)
	view.side = StepView.Opening.ABOVE
	overlay.show_view(view)
	await _frames(1)
	var card: Rect2 = overlay.callout().get_global_rect()
	assert_bool(card.intersects(item)).is_false()
	assert_bool(card.intersects(overlay.rings()[0].get_global_rect())).is_false()
	assert_array(overlay.clear_rects()).is_equal([item] as Array[Rect2])
	# Kept clear over the whole screen: no side has room, the callout still clears its ring.
	var everything: StepView = StepView.guided(19, 26, LONG_TEXT, false)
	everything.ring(&"", target).keep_clear(&"", Rect2(Vector2.ZERO, WINDOWS[0]))
	overlay.show_view(everything)
	await _frames(1)
	card = overlay.callout().get_global_rect()
	assert_bool(card.intersects(overlay.rings()[0].get_global_rect())).is_false()
	assert_bool(Rect2(Vector2.ZERO, WINDOWS[0]).encloses(card)).is_true()


## A LOCKED plate's pill (padlock and words) lies in its middle, inside it: the big pill on a
## plate that holds it (the swap plate, REDRAW), the small one on a narrow plate.
func test_lock_plates_fit_their_pill() -> void:
	_host.size = WINDOWS[0]
	var overlay: TutorialOverlay = _overlay()
	var plates: Array[Rect2] = [Rect2(12, 480, 304, 36), Rect2(20, 600, 160, 50)]
	var narrow: Rect2 = Rect2(900, 40, 64, 20)
	var view: StepView = StepView.guided(2, 26, "These are your regulars.", false)
	for rect: Rect2 in plates + [narrow]:
		view.lock(&"", rect)
	overlay.show_view(view)
	await _frames(1)
	var locks: Array[LockPlate] = overlay.locks()
	for index: int in range(locks.size()):
		var plate: LockPlate = locks[index]
		var area: Rect2 = plate.get_global_rect()
		var pill: Rect2 = plate.pill().get_global_rect()
		assert_bool(area.grow(0.5).encloses(pill)).override_failure_message(str(index)).is_true()
		assert_float(pill.get_center().x).is_equal_approx(area.get_center().x, 2.0)
		var words: Rect2 = Rect2(
			plate.words_label().global_position, UiKit.pixel_text_size(plate.words_label())
		)
		assert_bool(pill.grow(0.5).encloses(plate.padlock().get_global_rect())).is_true()
		assert_float(words.position.x).is_greater_equal(plate.padlock().get_global_rect().end.x)
		assert_float(words.end.x).is_less_equal(pill.end.x + 0.5)
	assert_float(locks[0].padlock().size.x).is_equal(18.0)
	assert_float(locks[2].padlock().size.x).is_equal(9.0)


## A larger TEXT SIZE grows the body's font and the card with it (never past the screen).
func test_the_text_size_grows_the_callout() -> void:
	_host.size = WINDOWS[0]
	var overlay: TutorialOverlay = _overlay()
	var target: Rect2 = Rect2(600, 300, 100, 80)
	overlay.show_view(StepView.guided(14, 26, LONG_TEXT, true).ring(&"", target, true))
	await _frames(1)
	var normal: Vector2 = overlay.callout().size
	UiKit.reading_scale = 1.3
	overlay.show_view(StepView.guided(14, 26, LONG_TEXT, true).ring(&"", target, true))
	await _frames(1)
	var larger: Vector2 = overlay.callout().size
	assert_float(larger.x).is_greater(normal.x)
	assert_float(larger.y).is_greater(normal.y)
	_assert_fits(overlay.callout(), "larger")


func _overlay() -> TutorialOverlay:
	var overlay: TutorialOverlay = TutorialOverlay.new()
	_host.add_child(overlay)
	return overlay


func _button(rect: Rect2) -> Button:
	var button: Button = Button.new()
	button.position = rect.position
	button.size = rect.size
	_host.add_child(button)
	return button


## Every part of the callout lies inside its paper (the frame's border in), the header's title and
## count apart, the body under the header, the footer under the body.
func _assert_fits(callout: TutorialCallout, label: String) -> void:
	var paper: Rect2 = callout.get_global_rect().grow(-TipCard.BORDER + 0.5)
	var title: Rect2 = callout.header_title().get_global_rect()
	assert_bool(paper.encloses(title)).override_failure_message(label).is_true()
	if callout.count_title() != null:
		var count: Rect2 = callout.count_title().get_global_rect()
		assert_bool(paper.encloses(count)).override_failure_message(label).is_true()
		assert_bool(count.intersects(title)).override_failure_message(label).is_false()
	var body: Rect2 = callout.body().get_global_rect()
	assert_bool(paper.encloses(body)).override_failure_message(label).is_true()
	assert_float(body.position.y).is_greater_equal(title.end.y)
	var foot: Array[Control] = [callout.key(), callout.hint(), callout.link()]
	for part: Control in foot:
		if part == null:
			continue
		var rect: Rect2 = part.get_global_rect()
		assert_bool(paper.encloses(rect)).override_failure_message(label).is_true()
		assert_float(rect.position.y).is_greater_equal(body.end.y)


## Target spots: the corners, the edges' middles and the middle of a `window` screen.
static func _spots(window: Vector2) -> Array[Vector2]:
	var size: Vector2 = Vector2(140, 90)
	var right: float = window.x - size.x - 4.0
	var bottom: float = window.y - size.y - 4.0
	var mid: Vector2 = ((window - size) / 2.0).floor()
	return [
		Vector2(4, 4),
		Vector2(right, 4),
		Vector2(4, bottom),
		Vector2(right, bottom),
		Vector2(mid.x, 4),
		Vector2(mid.x, bottom),
		Vector2(4, mid.y),
		Vector2(right, mid.y),
		mid,
	]


## The controls after `target` in the tree (drawn and picked over it), shown and not ignoring the
## mouse, that would take a click at its centre: their own _has_point when they have one (the
## shade's holes), else their rect.
func _blockers(target: Control) -> Array[String]:
	var point: Vector2 = target.get_global_rect().get_center()
	var result: Array[String] = []
	var past_target: bool = false
	for node: Node in _host.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control == target:
			past_target = true
			continue
		if not past_target or target.is_ancestor_of(control) or not control.is_visible_in_tree():
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var local: Vector2 = control.get_global_transform().affine_inverse() * point
		var takes: bool = control.get_global_rect().has_point(point)
		if control.get_script() != null and control.has_method("_has_point"):
			takes = bool(control.call("_has_point", local))
		if takes:
			result.append(str(control.get_path()))
	return result


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
