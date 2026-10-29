extends GdUnitTestSuite
## The shift screen's store look (#80, mock-up B2's greybox): the backdrop's window bands (the
## top bar's band, the plaster wall, which keeps the background clicks, the counter's wood and
## the floor) at 1280x720 and at 1920x1080; the belt's bands; the register (RegisterCabinet) with
## its printer, column, key deck, keypad, drawer and keys at their rects, and the keys' looks;
## decor that never takes a click (a click on an empty slot, a hand card or a register key still
## reaches it, and one on the bare belt, the monitor, the keypad or the drawer reaches the wall);
## the hand's basket items under a shade while the shift is counted. The real saves and logs are
## never touched.

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## In a 1280x720 and a 1920x1080 window: the wall fills the window and takes the clicks; the top
## band runs from the window's top to the stage's top bar foot, the counter from the stage's
## counter line to the bottom and the floor from the stage's floor line to the bottom, each
## spanning the window and taking no click; the stage is centred.
func test_the_backdrop_fits_each_window() -> void:
	for window_size: Vector2 in WINDOWS:
		var window: Control = auto_free(Control.new())
		window.size = window_size
		add_child(window)
		var wall: ColorRect = StoreBackdrop.screen_parts(window)
		StoreBackdrop.top_parts(window)
		var stage: ShiftStage = ShiftStage.new(7)
		window.add_child(stage)
		await _frames(2)
		var bounds: Rect2 = window.get_global_rect()
		var stage_rect: Rect2 = stage.get_global_rect()
		assert_vector(stage_rect.size).is_equal(ShiftStage.SIZE)
		assert_vector(stage_rect.get_center()).is_equal_approx(bounds.get_center(), Vector2.ONE)
		assert_object(window.get_child(0)).is_same(wall)
		# The wall runs past the window's right edge, for the camera at the machine (#77 v2).
		var wall_rect: Rect2 = wall.get_global_rect()
		assert_vector(wall_rect.position).is_equal(bounds.position)
		assert_float(wall_rect.end.y).is_equal(bounds.end.y)
		assert_float(wall_rect.end.x).is_equal(bounds.end.x + StoreBackdrop.WORLD_EXTRA)
		assert_int(wall.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
		var top_band: Rect2 = _band(window, "TopBand", bounds)
		assert_float(top_band.position.y).is_less_equal(bounds.position.y)
		assert_float(top_band.end.y).is_equal(stage_rect.position.y + ShiftStage.TOP_BAR_BOTTOM)
		# B2's ink line along the band's foot, inside it.
		var edge: Rect2 = _band(window, "TopEdge", bounds)
		assert_float(edge.end.y).is_equal(top_band.end.y)
		assert_float(edge.size.y).is_equal(StoreBackdrop.TOP_EDGE)
		assert_object((window.get_node("TopEdge") as ColorRect).color).is_equal(Palette.INK)
		var counter: Rect2 = _band(window, "Counter", bounds)
		assert_float(counter.position.y).is_equal(stage_rect.position.y + ShiftStage.COUNTER_TOP)
		assert_float(counter.end.y).is_greater_equal(bounds.end.y)
		var floor_band: Rect2 = _band(window, "Floor", bounds)
		assert_float(floor_band.position.y).is_equal(stage_rect.position.y + ShiftStage.FLOOR_TOP)
		assert_float(floor_band.end.y).is_greater_equal(bounds.end.y)
		window.queue_free()


## The belt's bands: the top face the items stand on and the rail the tickets clip onto, inside
## the belt, the rail under the top face.
func test_the_belt_draws_its_bands() -> void:
	var screen: ShiftScreen = await _screen()
	var belt: BeltPanel = screen._stage.belt
	var inside: Rect2 = Rect2(Vector2.ZERO, belt.size)
	assert_vector(belt.size).is_equal(ShiftStage.BELT_RECT.size)
	for band: Rect2 in [belt.top_face(), belt.rail()]:
		assert_bool(inside.encloses(band)).override_failure_message(str(band)).is_true()
	assert_float(belt.rail().position.y).is_greater_equal(belt.top_face().end.y)
	var top_face: Rect2 = belt.get_global_transform() * belt.top_face()
	assert_float(top_face.position.y).is_equal(
		screen._stage.get_global_rect().position.y + ShiftStage.COUNTER_TOP
	)


## Decor takes no click: the window bands other than the wall, the belt, the monitor, the
## baskets and the register (with every part of them) are MOUSE_FILTER_IGNORE. A click on an
## empty slot or a hand card reaches it, one in the gap between two slots reaches the nearer
## slot's drop target (the targets meet in the gap's middle), and one on the monitor reaches the
## wall (the background click), as does one on the idle machine on the back wall (#77 machine v2).
func test_decor_takes_no_clicks() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var wall: Control = screen._wall
	assert_int(wall.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(wall.gui_input.is_connected(screen._on_background_input)).is_true()
	# The camera's parts (the backdrop in it, the stage's world aside) and the top band.
	var parts: Array[Node] = screen._camera.content.get_children()
	parts.append(screen._camera)
	for index: int in range(1, stage.get_index()):
		parts.append(screen.get_child(index))
	for node: Node in parts:
		var part: Control = node as Control
		if part == wall or part == stage.world:
			continue
		assert_int(part.mouse_filter).override_failure_message(str(part.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
	var decors: Array[Control] = [
		stage.belt,
		stage.monitor,
		stage.baskets,
		stage.basket_fronts,
		stage.hand_shade,
		stage.cabinet
	]
	for decor: Control in decors:
		assert_int(decor.mouse_filter).override_failure_message(str(decor.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
		for child: Node in decor.get_children():
			# The row's cells and the register's keys take their own clicks.
			if child is Control and child != stage.row_strip and not child is RegisterKey:
				(
					assert_int((child as Control).mouse_filter)
					. override_failure_message(str(child.name))
					. is_equal(Control.MOUSE_FILTER_IGNORE)
				)
	var slot: PanelContainer = screen._slots[2]
	var slot_hit: Control = _topmost_at(screen, slot.get_global_rect().get_center())
	assert_bool(slot_hit == slot or slot.is_ancestor_of(slot_hit)).is_true()
	var card: Control = screen._hand_box.cards()[0]
	var card_hit: Control = _topmost_at(screen, card.get_global_rect().get_center())
	assert_bool(card_hit == card or card.is_ancestor_of(card_hit)).is_true()
	# The gap between slots 1 and 2, on the belt's top face: each half is its nearer slot's.
	var gap_middle: float = slot.get_global_rect().position.x - RowStrip.SEPARATION / 2.0
	var centre_y: float = slot.get_global_rect().get_center().y
	var left_hit: Control = _topmost_at(screen, Vector2(gap_middle - 2.0, centre_y))
	assert_object(left_hit).is_same(RowStrip.drop_target(screen._slots[1]))
	var right_hit: Control = _topmost_at(screen, Vector2(gap_middle + 2.0, centre_y))
	assert_object(right_hit).is_same(RowStrip.drop_target(slot))
	# The register: its keys take their clicks; its keypad, drawer and bare deck don't.
	for key: RegisterKey in [stage.checkout_button, stage.redraw_button]:
		assert_object(_topmost_at(screen, key.get_global_rect().get_center())).is_same(key)
	var cabinet: RegisterCabinet = stage.cabinet
	for part_name: String in ["Keypad", "Drawer"]:
		var part_rect: Rect2 = (cabinet.get_node(part_name) as Control).get_global_rect()
		assert_object(_topmost_at(screen, part_rect.get_center())).is_same(wall)
	var bare_deck: Vector2 = _on_stage(screen, ShiftStage.DECK_RECT).position + Vector2(4, 100)
	assert_object(_topmost_at(screen, bare_deck)).is_same(wall)
	var bezel: Rect2 = stage.monitor.get_global_rect()
	var on_bezel: Vector2 = bezel.position + Vector2(4, 4)
	assert_object(_topmost_at(screen, on_bezel)).is_same(wall)
	var machine: Rect2 = screen._machine.view.get_global_rect()
	assert_object(_topmost_at(screen, machine.get_center())).is_same(wall)


## CHECKOUT's caption as B2 sets it: the word letter-spaced, then the smaller "›" a gap after it,
## the pair centred on the key, the "›" inside the face and taking no click.
func _assert_checkout_caption(checkout: RegisterKey, arrow: Label) -> void:
	var caption: Label = checkout.caption_label()
	assert_str(caption.text).is_equal(RegisterCabinet.CHECKOUT_TEXT)
	var word_font: Font = caption.get_theme_font("font")
	assert_int((word_font as FontVariation).spacing_glyph).is_equal(
		RegisterCabinet.CHECKOUT_SPACING
	)
	assert_object(arrow.get_parent()).is_same(caption)
	assert_str(arrow.text).is_equal(RegisterCabinet.CHECKOUT_ARROW)
	assert_int(arrow.get_theme_font_size("font_size")).is_equal(RegisterCabinet.CHECKOUT_ARROW_SIZE)
	assert_int(arrow.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var size: int = RegisterCabinet.CHECKOUT_FONT_SIZE
	var word_width: float = (
		word_font.get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	)
	var face: Rect2 = checkout.get_global_rect()
	var word_left: float = (
		face.get_center().x - (word_width + RegisterCabinet.CHECKOUT_ARROW_GAP + arrow.size.x) / 2.0
	)
	var arrow_rect: Rect2 = arrow.get_global_rect()
	assert_float(arrow_rect.position.x - (word_left + word_width)).is_equal_approx(
		RegisterCabinet.CHECKOUT_ARROW_GAP, 0.5
	)
	assert_float(arrow_rect.get_center().y).is_equal_approx(
		caption.get_global_rect().get_center().y, 0.5
	)
	assert_bool(face.encloses(arrow_rect)).is_true()
	assert_float(word_left).is_greater(face.position.x)


## The register (RegisterCabinet) at its rect, the stage's rattle target (#80, step 9): its
## column, printer, key deck (its shadow down and right on the column), keypad and drawer at their
## stage rects, inside the column and taking no click; the printer, keypad and drawer are their
## art at 1:1, and the slot's lip art sits at the slot rect over the receipt, drawn after it. The
## keys (CHECKOUT, Redraw, Cancel) and the seed line are the cabinet's, so they rattle with it, on
## the key deck clear of the keypad and of each other, with the drawer under the deck.
func test_the_register_cabinet() -> void:
	var screen: ShiftScreen = await _screen()
	var cabinet: RegisterCabinet = screen._cabinet
	assert_object(screen._register).is_same(cabinet)
	assert_that(cabinet.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.REGISTER_RECT))
	var shadow: Rect2 = ShiftStage.DECK_RECT
	shadow.position += RegisterCabinet.DECK_SHADOW_OFFSET
	shadow.size.y -= RegisterCabinet.DECK_SHADOW_SHORTER
	var parts: Dictionary[String, Rect2] = {
		"Column": ShiftStage.COLUMN_RECT,
		"Printer": ShiftStage.PRINTER_RECT,
		"DeckShadow": shadow,
		"Deck": ShiftStage.DECK_RECT,
		"Keypad": ShiftStage.KEYPAD_RECT,
		"Drawer": ShiftStage.DRAWER_RECT,
	}
	var column: Rect2 = _on_stage(screen, ShiftStage.COLUMN_RECT)
	for part_name: String in parts:
		var part: Control = cabinet.get_node(part_name) as Control
		assert_that(part.get_global_rect()).is_equal(_on_stage(screen, parts[part_name]))
		assert_bool(cabinet.get_global_rect().encloses(part.get_global_rect())).is_true()
		assert_int(part.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		if part_name != "Printer":
			var inside: bool = column.encloses(part.get_global_rect())
			assert_bool(inside).override_failure_message(part_name).is_true()
	assert_object(cabinet.get_node_or_null("Pull")).is_null()
	var arts: Dictionary[String, Texture2D] = {
		"Printer": RegisterCabinet.PRINTER_BOX,
		"Keypad": RegisterCabinet.KEYPAD,
		"Drawer": RegisterCabinet.DRAWER,
	}
	for part_name: String in arts:
		var sprite: TextureRect = cabinet.get_node(part_name) as TextureRect
		assert_object(sprite.texture).is_same(arts[part_name])
		assert_that(Vector2(sprite.texture.get_size())).is_equal(sprite.size)
	var lip: TextureRect = screen._stage.printer_lip
	assert_object(lip.texture).is_same(ShiftStage.PRINTER_LIP)
	assert_int(lip.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that(lip.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.PRINTER_SLOT_RECT))
	assert_that(Vector2(lip.texture.get_size())).is_equal(ShiftStage.PRINTER_SLOT_RECT.size)
	# The lip is the stage's, after the receipt (drawn over its foot), and stays at the slot.
	assert_object(lip.get_parent()).is_same(screen._receipt.get_parent())
	assert_int(lip.get_index()).is_greater(screen._receipt.get_index())
	assert_bool(lip.get_global_rect().intersects(screen._receipt.get_global_rect())).is_true()

	# The keys and the seed line on the deck: the cabinet's, apart, clear of the keypad (Cancel
	# stands in its place), with the drawer under the deck.
	var deck: Rect2 = _on_stage(screen, ShiftStage.DECK_RECT)
	var keypad: Rect2 = _on_stage(screen, ShiftStage.KEYPAD_RECT)
	var drawer: Rect2 = _on_stage(screen, ShiftStage.DRAWER_RECT)
	assert_float(drawer.position.y).is_greater_equal(deck.end.y)
	# B2's 4 px shadow band ends 4 px above the drawer.
	var deck_shadow: Rect2 = (cabinet.get_node("DeckShadow") as Control).get_global_rect()
	assert_float(drawer.position.y - deck_shadow.end.y).is_equal(4.0)
	var keys: Array[Control] = [
		cabinet.checkout_key, cabinet.redraw_key, cabinet.cancel_key, cabinet.seed_label
	]
	assert_object(screen._stage.checkout_button).is_same(cabinet.checkout_key)
	assert_object(screen._stage.redraw_button).is_same(cabinet.redraw_key)
	assert_object(screen._stage.cancel_button).is_same(cabinet.cancel_key)
	assert_object(screen._seed_label).is_same(cabinet.seed_label)
	for index: int in keys.size():
		var key: Control = keys[index]
		var rect: Rect2 = key.get_global_rect()
		assert_object(key.get_parent()).is_same(cabinet)
		assert_bool(deck.encloses(rect)).override_failure_message(str(key.name)).is_true()
		if key is RegisterKey:
			assert_object(key).is_instanceof(BaseButton)
			# The key's shadow, and its face sunk by SINK, stay on the deck too.
			var lowest: Vector2 = rect.end + RegisterKey.SHADOW_UP + Vector2(0, RegisterKey.SINK)
			assert_bool(deck.has_point(lowest - Vector2.ONE)).is_true()
		if key != cabinet.cancel_key:
			var clear: bool = not rect.intersects(keypad)
			assert_bool(clear).override_failure_message(str(key.name)).is_true()
		for other: Control in keys.slice(index + 1):
			assert_bool(rect.intersects(other.get_global_rect())).is_false()
	# They rattle with the register.
	var rest: Vector2 = cabinet.checkout_key.get_global_rect().position
	cabinet.position.x += 5.0
	assert_that(cabinet.checkout_key.get_global_rect().position).is_equal(rest + Vector2(5, 0))
	cabinet.position.x -= 5.0
	# Cancel takes the keypad's place in redraw mode.
	assert_bool(cabinet.keypad.visible).is_true()
	screen._on_redraw_pressed()
	assert_bool(cabinet.cancel_key.visible).is_true()
	assert_bool(cabinet.keypad.visible).is_false()
	screen._on_cancel_pressed()
	assert_bool(cabinet.cancel_key.visible).is_false()
	assert_bool(cabinet.keypad.visible).is_true()


## The keys' looks (#80, step 9): CHECKOUT's tomato frames and the cream ones (Redraw, Cancel),
## three each (normal, lit, off), big enough for their 9-slice margins. Up, a key shows its normal
## frame with its caption on the front face under the top band; disabled it shows the off frame,
## sunk by SINK with a faded caption; CHECKOUT held (set_total_down) shows the same.
func test_the_register_keys_look() -> void:
	var screen: ShiftScreen = await _screen()
	var cabinet: RegisterCabinet = screen._cabinet
	for kind: RegisterKey.Kind in RegisterKey.FRAMES:
		var frames: Array = RegisterKey.FRAMES[kind]
		assert_int(frames.size()).is_equal(3)
		var margins: Vector2 = Vector2(
			2 * RegisterKey.SIDE_MARGIN, RegisterKey.TOP_MARGINS[kind] + RegisterKey.BOTTOM_MARGIN
		)
		for frame: Texture2D in frames:
			var art: Vector2 = Vector2(frame.get_size()) / float(ArtStyle.ART_SCALE)
			var fits: bool = art.x > margins.x and art.y > margins.y
			assert_bool(fits).override_failure_message(frame.resource_path).is_true()
	var checkout: RegisterKey = cabinet.checkout_key
	var redraw: RegisterKey = cabinet.redraw_key
	var tomato: Array = RegisterKey.FRAMES[RegisterKey.Kind.CHECKOUT]
	assert_object(_face_frame(checkout)).is_same(tomato[RegisterKey.Look.NORMAL])
	var cream: Array = RegisterKey.FRAMES[RegisterKey.Kind.CREAM]
	assert_object(_face_frame(redraw)).is_same(cream[RegisterKey.Look.NORMAL])
	assert_str(checkout.accessibility_name).is_equal(RegisterCabinet.CHECKOUT_NAME)
	_assert_checkout_caption(checkout, cabinet.checkout_arrow)
	for key: RegisterKey in [checkout, redraw]:
		assert_bool(key.disabled).is_false()
		assert_int(key.look()).is_equal(RegisterKey.Look.NORMAL)
		var top: float = key.get_global_rect().position.y
		assert_float(key.face().get_global_rect().position.y).is_equal(top)
		var caption: Rect2 = key.caption_label().get_global_rect()
		assert_float(caption.position.y).is_greater_equal(top + key.band_height())
		assert_float(caption.end.y).is_less_equal(key.get_global_rect().end.y)
		assert_float(key.caption_label().modulate.a).is_equal(1.0)
		key.disabled = true
		await _frames(1)
		_assert_off(key)
		key.disabled = false
		await _frames(1)
		assert_int(key.look()).is_equal(RegisterKey.Look.NORMAL)
	cabinet.set_total_down(true)
	assert_bool(checkout.held).is_true()
	await _frames(1)
	_assert_off(checkout)
	assert_object(_face_frame(checkout)).is_same(tomato[RegisterKey.Look.OFF])
	cabinet.set_total_down(false)
	assert_bool(checkout.held).is_false()
	await _frames(1)
	assert_int(checkout.look()).is_equal(RegisterKey.Look.NORMAL)
	assert_float(checkout.face().offset_top).is_equal(0.0)


## `key` shows its off look: sunk by SINK (its whole face), the caption faded, never dimmed.
func _assert_off(key: RegisterKey) -> void:
	assert_int(key.look()).is_equal(RegisterKey.Look.OFF)
	assert_bool(key.is_sunk()).is_true()
	var face: Rect2 = key.face().get_global_rect()
	assert_float(face.position.y).is_equal(key.get_global_rect().position.y + RegisterKey.SINK)
	assert_float(face.size.y).is_equal(key.size.y)
	var faded: float = key.caption_label().modulate.a
	assert_float(faded).is_equal_approx(RegisterKey.OFF_CAPTION_ALPHA, 0.001)
	assert_float(key.modulate.a).is_equal(1.0)


## The frame texture on `key`'s face now.
static func _face_frame(key: RegisterKey) -> Texture2D:
	return (key.face().get_theme_stylebox("panel") as StyleBoxTexture).texture


## The hand is basket items (#80, step 8), and while the shift is counted a shade (ink at
## COUNTING_SHADE_ALPHA) covers the hand and its baskets, over the basket fronts; it lifts once the
## count-up ends. The items and baskets keep their own alpha.
func test_the_hand_is_basket_items_under_a_shade_while_counting() -> void:
	var screen: ShiftScreen = await _screen()
	var views: Array[Control] = screen._hand_box.cards()
	assert_int(views.size()).is_equal(screen.run.balance.hand_size)
	for view: Control in views:
		assert_object(view).is_instanceof(ItemView)
		assert_int((view as ItemView).form).is_equal(ItemView.Form.BASKET)
	var stage: ShiftStage = screen._stage
	var shade: ColorRect = stage.hand_shade
	assert_bool(shade.visible).is_false()
	assert_that(shade.get_global_rect()).is_equal(
		Rect2(
			stage.get_global_rect().position + ShiftStage.COUNTING_SHADE_RECT.position,
			ShiftStage.COUNTING_SHADE_RECT.size
		)
	)
	assert_that(shade.color).is_equal(Color(Palette.INK, ShiftStage.COUNTING_SHADE_ALPHA))
	assert_int(shade.get_index()).is_greater(stage.basket_fronts.get_index())
	assert_int(stage.basket_fronts.get_index()).is_greater(stage.hand.get_index())
	assert_int(stage.hand.get_index()).is_greater(stage.baskets.get_index())
	var shade_rect: Rect2 = shade.get_global_rect()
	for part: Control in stage.baskets.parts() + stage.basket_fronts.parts() + views:
		assert_bool(shade_rect.encloses(part.get_global_rect())).is_true()
	# Read on the first frame of the count-up.
	var counting: Array[bool] = []
	var record: Callable = func() -> void: counting.append(shade.visible)
	get_tree().process_frame.connect(record, CONNECT_ONE_SHOT)
	await Rush.checkout(screen)
	assert_array(counting).is_equal([true])
	assert_bool(shade.visible).is_false()
	for part: Control in [stage.baskets, stage.hand, stage.basket_fronts]:
		assert_float(part.modulate.a).is_equal(1.0)


## `window`'s band `part`: spanning the window and taking no click. Returns its rect.
func _band(window: Control, part: String, bounds: Rect2) -> Rect2:
	var band: Control = window.get_node(part) as Control
	var shown: Rect2 = band.get_global_rect()
	assert_float(shown.position.x).is_less_equal(bounds.position.x)
	assert_float(shown.end.x).is_greater_equal(bounds.end.x)
	assert_int(band.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	return shown


## The screen on shift 1, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(3)
	return screen


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


## The control a click at `point` reaches, picked as the GUI does: the last drawn visible
## control under the point that doesn't ignore the mouse (children over their parent, later
## siblings over earlier ones), or null.
static func _topmost_at(node: Node, point: Vector2) -> Control:
	for index: int in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(index)
		var item: CanvasItem = child as CanvasItem
		if item != null and not item.visible:
			continue
		var disabled: Control = child as Control
		if (
			disabled != null
			and disabled.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED
		):
			continue
		var found: Control = _topmost_at(child, point)
		if found != null:
			return found
	var control: Control = node as Control
	if (
		control != null
		and control.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and control.get_global_rect().has_point(point)
	):
		return control
	return null


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
