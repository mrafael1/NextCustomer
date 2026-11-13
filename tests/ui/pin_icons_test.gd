extends GdUnitTestSuite
## The badge pins' icons (pin icons review, picked by the user on 2026-11-14): every pin carries
## its small and large icon (art/pin_icons/<id>.png, <id>_big.png), and every face shows the icon
## in place of its letters, the small one on the small faces and the large one on the large:
## the lanyard's and the pin tip's 32 px faces on the real shift screen, the badge screen's name
## badge (44 px) and rows (48 px), the results' new-pin card (60 px), and the start screen's pins
## step (PinStepDraw: compact rows 14, corkboard badge 16, big rows 20, badge card 28 art px).
## The PinFace icons are crisp at 1280x720 and 1920x1080: the sharp-pixel material, the art's
## whole scale, on the 2 px grid and on whole screen px. The real saves and logs are never touched.

const SHIFT_SCREEN := "res://ui/shift_screen.tscn"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
## The icons' largest sizes, art px: small, large.
const SMALL_MAX := Vector2(8, 8)
const BIG_MAX := Vector2(14, 14)


## A pen that records its sprites instead of drawing them; its rects, frames and pixel text
## draw nothing (the start screen's pin faces, badge card and corkboard, outside a draw).
class RecordingPen:
	extends ArtPen

	var sprites: Array[Dictionary] = []

	func tex(
		texture: Texture2D, x: float, y: float, _modulate: Color = Color.WHITE, scale: float = 1.0
	) -> void:
		sprites.append({"texture": texture, "at": Vector2(x, y), "scale": scale})

	func r(_x: float, _y: float, _w: float, _h: float, _colour: Color) -> void:
		pass

	func nine(
		_frame: Texture2D,
		_x: float,
		_y: float,
		_w: float,
		_h: float,
		_margins: Vector4i,
		_modulate: Color = Color.WHITE
	) -> void:
		pass

	func pix(
		_text: String,
		_x: float,
		_y: float,
		_colour: Color,
		_scale: float = 1.0,
		_align: int = HORIZONTAL_ALIGNMENT_LEFT
	) -> float:
		return 0.0

	## The pin icons drawn (small or large of any pin), in order.
	func icons() -> Array[Texture2D]:
		var found: Array[Texture2D] = []
		for sprite: Dictionary in sprites:
			var texture: Texture2D = sprite.texture
			if texture != null and texture.resource_path.begins_with("res://art/pin_icons/"):
				found.append(texture)
		return found


var _folder: String = ""
var _window_size: Vector2i = Vector2i.ZERO
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_pin_icons_%d" % Time.get_ticks_usec()
	_window_size = get_tree().root.size
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Each pin of the catalogue has its own small and large icon, named by its id, within the sizes
## the faces hold.
func test_every_pin_has_its_icons() -> void:
	var pins: Array[PinDefinition] = _pins()
	assert_int(pins.size()).is_equal(8)
	for pin: PinDefinition in pins:
		var what: String = String(pin.id)
		assert_object(pin.icon).override_failure_message(what).is_not_null()
		assert_object(pin.icon_big).override_failure_message(what).is_not_null()
		assert_str(pin.icon.resource_path).is_equal("res://art/pin_icons/%s.png" % pin.id)
		assert_str(pin.icon_big.resource_path).is_equal("res://art/pin_icons/%s_big.png" % pin.id)
		var small: Vector2 = pin.icon.get_size()
		var big: Vector2 = pin.icon_big.get_size()
		assert_bool(small.x <= SMALL_MAX.x and small.y <= SMALL_MAX.y).is_true()
		assert_bool(big.x <= BIG_MAX.x and big.y <= BIG_MAX.y).is_true()
		assert_bool(big.x > small.x or big.y > small.y).override_failure_message(what).is_true()


## A popping face keeps its resting face's icon: the corkboard's 16 popping to 18 and 20 keeps
## the small one, the badge card's 28 popping to 30 and 32 keeps the large one.
func test_a_popping_start_face_keeps_its_icon() -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(18, 16), Vector2i(20, 16), Vector2i(30, 28), Vector2i(32, 28)
	]
	for pin: PinDefinition in _pins():
		for popped: Vector2i in sizes:
			var pen: RecordingPen = RecordingPen.new(null)
			PinStepDraw.face(pen, pin, 0, 40, 30, popped.x, popped.y)
			var big: bool = popped.y >= PinStepDraw.BIG_FACE
			var expected: Texture2D = pin.icon_big if big else pin.icon
			var what: String = "%s at %s" % [pin.id, popped]
			assert_array(pen.icons()).override_failure_message(what).is_equal([expected])


## The real corkboard (BuildPageDraw) and badge card (PinStepDraw.badge) through their landing and
## toggle pops: the corkboard's pin shows its small icon on every frame, the badge card's its
## large one.
func test_the_corkboard_and_badge_card_keep_their_icons_through_the_pop() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var page: BuildPage = auto_free(BuildPage.new())
	page.run = RunState.new(1, load(STARTER), balance, RunStock.starting(balance))
	page.fly_t = 0.0
	for pin: PinDefinition in _pins():
		var worn: Array[PinDefinition] = [pin]
		page.run.pins = worn
		for u: float in [0.0, 0.03, 0.06, 0.08, 0.12, 0.3]:
			var what: String = "%s at %.2f" % [pin.id, u]
			page.now = page.tuning.pin_fly_s + u
			var cork: RecordingPen = RecordingPen.new(null)
			BuildPageDraw._pins_board(cork, page)
			assert_array(cork.icons()).override_failure_message("cork " + what).is_equal([pin.icon])
			page.now = u
			var card: RecordingPen = RecordingPen.new(null)
			PinStepDraw.badge(card, page, 10, 30, 82, 92, worn, 28, 0.0)
			assert_array(card.icons()).override_failure_message("badge " + what).is_equal(
				[pin.icon_big]
			)


## The lanyard's faces and the pin tip's face (now 32 px, as the lanyard's) on the real shift
## screen show each pin's small icon, crisp, at both window sizes.
func test_the_lanyard_and_the_tip_show_the_small_icons() -> void:
	assert_float(PinTip.FACE_SIZE).is_equal(PinLanyard.PIN_SIZE)
	var pins: Array[PinDefinition] = _pins()
	for window: Vector2i in WINDOWS:
		get_tree().root.size = window
		var screen: ShiftScreen = await _shift_screen()
		var lanyard: PinLanyard = screen._stage.pin_lanyard
		for first: int in range(0, pins.size(), 2):
			var worn: Array[PinDefinition] = [pins[first], pins[first + 1]]
			screen.run.pins = worn
			screen._refresh()
			await _frames(2)
			var faces: Array[PinFace] = lanyard.faces()
			assert_int(faces.size()).is_equal(2)
			for index: int in faces.size():
				var where: String = "lanyard %s %s" % [window, worn[index].id]
				_assert_icon(faces[index], worn[index], false, where)
				lanyard.hover_pin(index, true)
				await _frames(2)
				var tip: PinTip = lanyard.card() as PinTip
				assert_bool(tip.visible).override_failure_message(where).is_true()
				_assert_icon(tip.face(), worn[index], false, "tip " + where)
				var box: Rect2 = (tip.get_node("IconBox") as Control).get_global_rect()
				(
					assert_bool(box.encloses(tip.face().get_global_rect()))
					. override_failure_message(where)
					. is_true()
				)
				lanyard.hover_pin(index, false)
				await _frames(1)


## The badge screen: the name badge's worn pins (44 px) and the pin rows (48 px) show the large
## icons, crisp, at both window sizes.
func test_the_badge_screen_shows_the_large_icons() -> void:
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	var balance: BalanceDefinition = load(BALANCE)
	for window: Vector2i in WINDOWS:
		get_tree().root.size = window
		var host: Control = auto_free(Control.new())
		host.size = Vector2(1280, 720)
		add_child(host)
		var popup: BadgeScreen = BadgeScreen.new(catalogue, balance)
		popup.still = true
		host.add_child(popup)
		var profile: ProfileState = ProfileState.new()
		for pin: PinDefinition in catalogue.pins:
			profile.unlocked_pins.append(pin.id)
		popup.open(profile, null, _event_log(), false)
		await _frames(2)
		for page: int in popup.page_count():
			popup.show_page(page)
			await _frames(1)
			for row: PinRow in popup.rows():
				if row.visible:
					_assert_icon(row.face(), row.pin, true, "row %s %s" % [window, row.pin.id])
		for pin: PinDefinition in catalogue.pins:
			var worn: Array[PinDefinition] = [pin]
			popup.badge().show_pins(worn, balance.pin_slots, [catalogue.pins.find(pin)])
			await _frames(1)
			var face: PinFace = popup.badge().slot_faces()[0]
			_assert_icon(face, pin, true, "name badge %s %s" % [window, pin.id])
		host.queue_free()
		await _frames(1)


## The results' new-pin card (60 px) shows the pin's large icon, crisp, at both window sizes.
func test_the_new_pin_card_shows_the_large_icon() -> void:
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	var ids: Array[StringName] = []
	for pin: PinDefinition in catalogue.pins:
		if pin.unlock_condition != null:
			ids.append(pin.id)
	assert_array(ids).is_not_empty()
	for window: Vector2i in WINDOWS:
		get_tree().root.size = window
		var root: Control = auto_free(Control.new())
		root.size = Vector2(1280, 720)
		add_child(root)
		var receipt: Control = Control.new()
		receipt.position = Vector2(402, 64)
		receipt.size = Vector2(476, 592)
		root.add_child(receipt)
		var reveal: PinReveal = PinReveal.new()
		reveal.size = root.size
		var now: Array[int] = [0]
		reveal.clock = func() -> int: return now[0]
		reveal.setup(receipt, func() -> bool: return false)
		root.add_child(reveal)
		var profile: ProfileState = ProfileState.new()
		profile.unlocked_pins.assign(ids)
		reveal.show_news(PinUnlockNews.of(ids, profile, catalogue), true)
		reveal.finish()
		await _frames(2)
		for card: PinUnlockCard in reveal.cards():
			assert_vector(card.face().scale).is_equal(Vector2.ONE)
			var pin: PinDefinition = _pin_of(card, catalogue)
			var where: String = "unlock card %s %s" % [window, pin.id]
			_assert_icon(card.face(), pin, true, where)
			# Through the pop the face grows and shrinks; the icon keeps the art's whole scale and
			# its resting place on whole screen px.
			var icon: TextureRect = card.face().get_node("Icon") as TextureRect
			var rest: Transform2D = _on_screen(icon)
			for progress: float in [0.2, 0.5, 0.6, 0.8]:
				card.set_pop(progress)
				var popped: String = "%s pop %.2f" % [where, progress]
				assert_float(card.face().scale.x).override_failure_message(popped).is_not_equal(1.0)
				var at: Transform2D = _on_screen(icon)
				assert_vector(at.get_scale()).override_failure_message(popped).is_equal_approx(
					rest.get_scale(), Vector2.ONE * 0.001
				)
				assert_vector(at.origin).override_failure_message(popped).is_equal_approx(
					rest.origin, Vector2.ONE * 0.001
				)
			card.set_pop(1.0)
			_assert_icon(card.face(), pin, true, where + " landed")
		root.queue_free()
		await _frames(1)


## The start screen's pins step draws each pin's icon centred on its face, on whole art px: the
## small one on the compact rows (14) and the corkboard badge (16), the large one on the big rows
## (20) and the badge card (28).
func test_the_start_screen_faces_draw_the_icons() -> void:
	var pins: Array[PinDefinition] = _pins()
	for d: int in [14, 16, 20, 28]:
		var big: bool = d >= PinStepDraw.BIG_FACE
		for index: int in pins.size():
			var pin: PinDefinition = pins[index]
			var pen: RecordingPen = RecordingPen.new(null)
			PinStepDraw.face(pen, pin, index, 40, 30, d)
			var what: String = "%s at %d" % [pin.id, d]
			assert_int(pen.sprites.size()).override_failure_message(what).is_equal(2)
			var icon: Dictionary = pen.sprites[1]
			var expected: Texture2D = pin.icon_big if big else pin.icon
			assert_object(icon.texture).override_failure_message(what).is_same(expected)
			assert_float(icon.scale).is_equal(1.0)
			var at: Vector2 = icon.at
			assert_vector(at).override_failure_message(what).is_equal(at.floor())
			var art: Vector2 = expected.get_size()
			var inside: Rect2 = Rect2(Vector2(40, 30) + Vector2.ONE * 2, Vector2.ONE * (d - 4))
			assert_bool(inside.encloses(Rect2(at, art))).override_failure_message(what).is_true()
			var centre: Vector2 = at + art / 2.0 - Vector2(40, 30) - Vector2.ONE * d / 2.0
			assert_bool(absf(centre.x) <= 0.5 and absf(centre.y) <= 0.5).is_true()


## `face` shows `pin`'s small or large icon in place of its letters, with the sharp-pixel material
## at the art's whole scale, inside the face's band, on the 2 px grid and on whole screen px.
func _assert_icon(face: PinFace, pin: PinDefinition, big: bool, where: String) -> void:
	var expected: Texture2D = pin.icon_big if big else pin.icon
	assert_object(face.icon()).override_failure_message(where).is_same(expected)
	assert_str(face.letters()).override_failure_message(where).is_empty()
	var icon: TextureRect = face.get_node("Icon") as TextureRect
	assert_bool(icon.is_visible_in_tree()).override_failure_message(where).is_true()
	assert_object(icon.material).override_failure_message(where).is_same(ArtStyle.pixel_material())
	assert_bool(icon.has_meta(ArtStyle.PIXEL_ART_META)).is_true()
	assert_vector(icon.size).is_equal(expected.get_size() * ArtStyle.ART_SCALE)
	assert_float(fmod(icon.position.x, ArtStyle.ART_SCALE)).is_equal(0.0)
	assert_float(fmod(icon.position.y, ArtStyle.ART_SCALE)).is_equal(0.0)
	var band: float = (1 + PinFace.RIM) * PinFace.PX
	var inside: Rect2 = Rect2(Vector2.ONE * band, face.size - Vector2.ONE * band * 2.0)
	(
		assert_bool(inside.encloses(Rect2(icon.position, icon.size)))
		. override_failure_message(where)
		. is_true()
	)
	var on_screen: Transform2D = _on_screen(icon)
	var texel: float = on_screen.get_scale().x * ArtStyle.ART_SCALE
	assert_float(texel).override_failure_message(where).is_equal_approx(roundf(texel), 0.001)
	var origin: Vector2 = on_screen.origin
	(
		assert_bool(origin.is_equal_approx(origin.round()))
		. override_failure_message("%s: %s" % [where, origin])
		. is_true()
	)


## `node`'s transform on the window's screen px.
func _on_screen(node: CanvasItem) -> Transform2D:
	return get_tree().root.get_final_transform() * node.get_global_transform_with_canvas()


static func _pin_of(card: PinUnlockCard, catalogue: CatalogueDefinition) -> PinDefinition:
	var title: String = card.texts()[1]
	for pin: PinDefinition in catalogue.pins:
		if pin.display_name.to_upper() == title:
			return pin
	return null


static func _pins() -> Array[PinDefinition]:
	return (load(CATALOGUE) as CatalogueDefinition).pins


func _shift_screen() -> ShiftScreen:
	_runner = scene_runner(SHIFT_SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(3)
	RunPins.wear(screen.run, [_pins()[0]])
	screen.run.start_shift()
	screen.profile.set_reduced_motion(true)
	screen._refresh()
	screen._week.skip()  # The time card opens over a new shift's start.
	await _frames(2)
	return screen


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
