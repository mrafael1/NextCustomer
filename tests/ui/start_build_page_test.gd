extends GdUnitTestSuite
## Start screen page 2, YOUR BUILD (v1.32, mock-up start_boosters_v3; no starter packs since
## v1.45): the BADGE PINS step that holds OPEN STORE (confirming with no pin allowed, pins changed
## later with no re-deal), OPEN STORE always lit otherwise, and the card -> item -> cart flight.
## Geometry on the stage at 1280x720 and 1920x1080.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261103
const ART := Rect2(0, 0, 640, 360)

var _folder: String


func before_test() -> void:
	_folder = "user://start_build_page_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## The page opens on the BADGE PINS step while OPEN STORE waits: the primary key says BADGE PINS.
## The step's box and its confirm key sit on the stage. Confirming with no pin is allowed: OPEN
## STORE is lit, the confirm is saved and nothing is worn.
func test_badge_pins_step_holds_open_store() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = board.staff
	board.show_page(2)
	staff.advance(0.2)
	assert_bool(staff.pins.owned().is_empty()).is_false()
	assert_bool(staff.pins_pending()).is_true()
	assert_bool(staff.pins_open).is_true()
	assert_str(BuildPageDraw.primary_label(staff)[0]).is_equal("BADGE PINS")
	var box: Rect2 = Rect2(BuildPage.PIN_BOX)
	assert_bool(ART.encloses(box)).is_true()
	var confirm: Dictionary = _hit(staff, "pinsok")
	assert_bool(confirm.is_empty()).is_false()
	assert_bool(box.encloses(confirm.rect)).is_true()
	# The order sheet lists the whole cart already: the regulars and the boosters' cards.
	var cart: int = screen.run.starter.core_cards.size() + screen.run.start_setup.shared().size()
	assert_int(staff.order.shown_cards.size()).is_equal(cart)
	assert_int(staff.cart_target()).is_equal(cart)
	# Esc closes the step: OPEN STORE (also straight through the board's clock-in) is refused.
	assert_bool(staff.handle_key(KEY_ESCAPE)).is_true()
	assert_bool(staff.pins_open).is_false()
	assert_bool(board.clock_in()).is_false()
	assert_bool(staff.open_store()).is_false()
	assert_object(staff.flight).is_null()
	# P opens it again; NO PINS confirms.
	assert_bool(staff.handle_key(KEY_P)).is_true()
	staff.advance(0.2)
	assert_bool(staff.primary()).is_true()
	assert_bool(staff.pins_open).is_false()
	assert_bool(staff.pins_pending()).is_false()
	assert_str(BuildPageDraw.primary_label(staff)[0]).is_equal("OPEN STORE ›")
	assert_array(screen.run.pins).is_empty()
	var saved: RunSave = RunSave.from_dictionary(_save(), ContentLookup.new(screen.run.balance))
	assert_bool(saved.run.start_setup.pins_confirmed).is_true()


## A profile owning only the pins every profile starts with (none earned, none worn) gets OPEN
## STORE at once (mock-up NEW · 0): no step, the key lit with the cart's count, and the primary key
## opens the store.
func test_a_new_profile_opens_the_store_at_once() -> void:
	var screen: ShiftScreen = await _screen(0)
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = board.staff
	assert_bool(staff.pins.owned().is_empty()).is_false()
	assert_int(staff.pins.gate_count()).is_equal(0)
	board.show_page(2)
	staff.advance(0.2)
	assert_bool(staff.pins_pending()).is_false()
	assert_bool(staff.pins_open).is_false()
	# The REGULARS crate's KEEP comes first, every run (v1.45): OPEN STORE stays dim until then.
	assert_bool(staff.regulars_pending()).is_true()
	assert_array(BuildPageDraw.primary_label(staff)).is_equal(
		["OPEN STORE ›", "KEEP REGULARS FIRST", false]
	)
	assert_str(BuildPageDraw.hint_line(staff)).is_equal(BuildRegulars.HINT)
	assert_bool(staff.open_store()).is_false()
	assert_bool(_hit(staff, BuildRegulars.KEEP_ID).is_empty()).is_false()
	assert_bool(staff.primary("key")).is_true()
	assert_bool(staff.regulars_pending()).is_false()
	assert_bool(_hit(staff, BuildRegulars.KEEP_ID).is_empty()).is_true()
	var label: Array = BuildPageDraw.primary_label(staff)
	assert_str(label[0]).is_equal("OPEN STORE ›")
	assert_str(label[1]).is_equal("%d CARDS" % staff.cart_target())
	assert_bool(label[2]).is_true()
	assert_str(BuildPageDraw.hint_line(staff)).is_equal(BuildPage.READY_HINT)
	# No starter pack is drawn or hit any more (v1.45).
	for id: String in ["pack0", "newpacks", "heldpacks"]:
		assert_bool(_hit(staff, id).is_empty()).is_true()
	# Wearing one of those pins holds the next run's OPEN STORE for the step.
	screen.profile.worn_pins.append(staff.pins.owned()[0].id)
	assert_int(staff.pins.gate_count()).is_equal(1)
	assert_bool(staff.primary()).is_true()


## With every pin owned (8), the step's rows turn compact and all fit inside the box, above the
## gate note and the confirm key, apart from each other; each rule fits its one line; keys
## 6-8 reach the last rows. No pin is left locked.
func test_every_pin_owned_fits_the_step() -> void:
	var screen: ShiftScreen = await _screen(99)
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = board.staff
	board.show_page(2)
	staff.advance(0.5)
	assert_bool(staff.pins_open).is_true()
	var owned: Array[PinDefinition] = staff.pins.owned()
	assert_int(owned.size()).is_equal(screen._catalogue.pins.size())
	assert_int(owned.size()).is_greater(PinStepDraw.FULL_ROWS)
	var top: float = PinStepDraw.box_y(staff)
	var box: Rect2 = Rect2(BuildPage.PIN_BOX)
	var bottom: float = top + PinStepDraw.ROWS_BOTTOM
	var confirm: Rect2 = PinStepDraw.confirm_rect(top)
	var rows: Array[Rect2] = []
	for pin: PinDefinition in owned:
		var hit: Dictionary = _hit(staff, "pin_%s" % pin.id)
		assert_bool(hit.is_empty()).is_false()
		var rect: Rect2 = hit.rect
		assert_bool(box.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.end.y).is_less_equal(bottom)
		assert_bool(rect.intersects(confirm)).is_false()
		for other: Rect2 in rows:
			assert_bool(rect.intersects(other)).is_false()
		rows.append(rect)
		var width: float = PinStepDraw.compact_rule_width(rect.size.x)
		var size: float = PinStepDraw.compact_rule_size(pin.rule_text, width)
		(
			assert_int(BoosterCardDraw.wrap_words(pin.rule_text, size, width).size())
			. override_failure_message(pin.rule_text)
			. is_equal(1)
		)
	assert_bool(staff.handle_key(KEY_8)).is_true()
	assert_bool(staff.pins_sel.has(owned[7])).is_true()
	assert_array(PinStepDraw.locked_pins(staff)).is_empty()


## Polish audit v1.36: a profile with pins still to earn shows them as grey LOCKED rows with their
## milestone under the owned ones (no empty band), every row inside the box above the gate note
## and the confirm key; only the owned rows take clicks and no row shows a number. NO PIN IS FINE
## TOO stands under the badge's NO PIN, ESC · BACK in the gate note; the ticker is clear while
## the step is open and says BADGE PINS FIRST · PRESS P once it closes unconfirmed.
func test_locked_pins_fill_the_step_as_grey_rows() -> void:
	var screen: ShiftScreen = await _screen(1)
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = board.staff
	board.show_page(2)
	staff.advance(0.5)
	assert_bool(staff.pins_open).is_true()
	var owned: Array[PinDefinition] = staff.pins.owned()
	var locked: Array[PinDefinition] = PinStepDraw.locked_pins(staff)
	assert_int(locked.size()).is_greater(0)
	assert_int(owned.size() + locked.size()).is_equal(screen._catalogue.pins.size())
	var count: int = owned.size() + locked.size()
	var top: float = PinStepDraw.box_y(staff)
	var box: Rect2 = Rect2(BuildPage.PIN_BOX)
	var confirm: Rect2 = PinStepDraw.confirm_rect(top)
	var rows: Array[Rect2] = []
	for k: int in count:
		var rect: Rect2 = PinStepDraw.row_rect(k, count, top)
		assert_bool(box.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.end.y).is_less_equal(top + PinStepDraw.ROWS_BOTTOM)
		assert_bool(rect.intersects(confirm)).is_false()
		for other: Rect2 in rows:
			assert_bool(rect.intersects(other)).is_false()
		rows.append(rect)
	# Each click rect is the row drawn for it (rows counted over the whole catalogue), also for a
	# new profile's few pins (only the pins every profile starts with).
	var rest: float = BuildPage.PIN_BOX.position.y
	var unlocked: Array[StringName] = staff.profile.unlocked_pins.duplicate()
	for earned: Array[StringName] in [unlocked, [] as Array[StringName]]:
		staff.profile.unlocked_pins = earned
		var mine: Array[PinDefinition] = staff.pins.owned()
		for k: int in mine.size():
			var hit: Dictionary = _hit(staff, "pin_%s" % mine[k].id)
			assert_bool(hit.is_empty()).is_false()
			assert_that(hit.rect).is_equal(PinStepDraw.row_rect(k, count, rest))
	assert_int(staff.pins.owned().size()).is_less_equal(PinStepDraw.FULL_ROWS)
	staff.profile.unlocked_pins = unlocked
	for pin: PinDefinition in locked:
		assert_bool(_hit(staff, "pin_%s" % pin.id).is_empty()).is_true()
		assert_str(PinStepDraw.unlock_text(pin)).starts_with("Unlock: ")
	var pen: _PenRecorder = _PenRecorder.new()
	PinStepDraw.draw(pen, staff)
	assert_int(pen.texts.count(PinStepDraw.LOCKED_TEXT)).is_equal(locked.size())
	assert_bool(pen.texts.has(PinStepDraw.NO_PIN_NOTE)).is_true()
	assert_bool(pen.texts.has(PinStepDraw.BACK_NOTE)).is_true()
	assert_bool(pen.texts.has("NONE IS FINE TOO")).is_false()
	# No row numbers (a face's own text may read as one: Last call's "+5").
	var faces: Array[String] = []
	for pin: PinDefinition in screen._catalogue.pins:
		faces.append(pin.face_text)
	for text: String in pen.texts:
		if not faces.has(text):
			assert_bool(text.is_valid_int()).override_failure_message(text).is_false()
	assert_str(BuildPageDraw.hint_line(staff)).is_empty()
	assert_bool(staff.pins.close()).is_true()
	assert_bool(staff.pins_pending()).is_true()
	assert_str(BuildPageDraw.hint_line(staff)).is_equal(BuildPageDraw.PINS_FIRST_HINT)


## A pin worn in the step is saved on the run and the profile; the step opens again later (the
## corkboard) and a new choice keeps the cart (no re-deal).
func test_pins_change_later_without_a_redeal() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = board.staff
	board.show_page(2)
	staff.advance(0.2)
	var owned: Array[PinDefinition] = staff.pins.owned()
	assert_int(owned.size()).is_greater_equal(2)
	assert_bool(staff.handle_key(KEY_1)).is_true()
	assert_bool(staff.primary()).is_true()
	assert_array(screen.run.pins).is_equal([owned[0]])
	assert_bool(screen.profile.worn_pins.has(owned[0].id)).is_true()
	var shared: Array[CardDefinition] = screen.run.start_offer.shared.duplicate()
	staff.advance(1.0)
	(_hit(staff, "pins").act as Callable).call()
	assert_bool(staff.pins_open).is_true()
	staff.advance(0.2)
	assert_bool(staff.handle_key(KEY_2)).is_true()
	assert_bool(staff.primary()).is_true()
	assert_array(screen.run.pins).is_equal([owned[1]])
	assert_array(screen.run.start_offer.shared).is_equal(shared)
	assert_bool(staff.pins_pending()).is_false()


## OPEN STORE with motion plays the flight (cards -> items -> cart): one modal hit swallows the
## page, every cart card flies from a point on the stage, then the board clocks in.
func test_open_store_flies_the_cards_to_the_cart() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	screen.profile.set_reduced_motion(false)
	board.refresh()
	var clocked: Array[bool] = []
	board.clocked_in.connect(func() -> void: clocked.append(true))
	assert_bool(board.clock_in()).is_true()
	var flight: StoreFlight = staff.flight
	assert_object(flight).is_not_null()
	staff.advance(0.0)
	assert_int(staff.hits.size()).is_equal(1)
	assert_str(staff.hits[0].id).is_equal("modal_store")
	assert_int(flight.items.size()).is_equal(staff.cart_target())
	for item: Dictionary in flight.items:
		assert_bool(ART.has_point(item.from)).is_true()
	var t: float = 0.0
	while staff.flight != null and t < 5.0:
		staff.advance(0.05)
		t += 0.05
	assert_object(staff.flight).is_null()
	assert_int(flight.landed).is_equal(flight.items.size())
	assert_array(clocked).is_equal([true])


## v1.36: during OPEN STORE's flight the floor's ticker says CLICK OR ENTER TO SKIP (no stale
## ready line, no loose body-text hint), and the cart's wheels clear it.
func test_the_store_flight_ticker_says_skip() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	screen.profile.set_reduced_motion(false)
	board.refresh()
	staff.advance(2.5)
	assert_str(BuildPageDraw.hint_line(staff)).is_equal(BuildPage.READY_HINT)
	assert_bool(board.clock_in()).is_true()
	staff.advance(0.05)
	assert_object(staff.flight).is_not_null()
	assert_str(BuildPageDraw.hint_line(staff)).is_equal(StoreFlight.SKIP_HINT)
	assert_float(BuildPageDraw.hint_start(staff)).is_equal(staff.flight.t0)
	var wheels: float = StoreFlight.CART_Y + StoreFlight.WHEELS_BOTTOM + 1.0
	assert_float(wheels).is_less_equal(float(BuildPage.LED_RECT.position.y))
	assert_float(ArtPen.pix_width(StoreFlight.SKIP_HINT)).is_less(BuildPage.LED_RECT.size.x - 8.0)


## The page fills the stage at both sizes; its keys (‹ STORE, the LED, the primary key) sit on
## it, clear of each other; the order sheet sits above the footer, its columns lined up.
func test_page_parts_fit_the_stage_at_both_sizes() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		await _resize(board, extent)
		var stage: Rect2 = _stage_rect(board)
		var k: float = board._stage.scale.x
		assert_bool(staff.get_global_rect().is_equal_approx(stage)).is_true()
		var parts: Array[Rect2] = [
			Rect2(BuildPage.BACK_RECT),
			Rect2(BuildPage.LED_RECT),
			Rect2(BuildPage.PRIMARY_RECT),
		]
		for a: int in parts.size():
			assert_bool(ART.encloses(parts[a])).is_true()
			for b: int in range(a + 1, parts.size()):
				assert_bool(parts[a].intersects(parts[b])).is_false()
		var sheet: Rect2 = staff.order.get_global_rect()
		assert_bool(stage.encloses(sheet)).is_true()
		var footer_top: float = stage.position.y + BuildPage.LED_RECT.position.y * 2.0 * k
		assert_float(sheet.end.y).is_less_equal(footer_top)
		_assert_sheet_aligned(staff.order, k)


## v1.32 press-bob on page 2: OPEN STORE (armed 0.3 s after the page opens) and the pins step's OK
## key (armed 0.3 s after the step opens) hop to 2 art px, then bob 1 px; each rests while hovered
## and under reduced motion; the 9-slice and its labels ride the lift and the hit rects never move.
func test_page_two_keys_press_bob_on_fixed_rects() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	staff.rm = false
	var rect: Rect2 = Rect2(BuildPage.PRIMARY_RECT)
	assert_that(_hit(staff, "primary").rect).is_equal(rect)
	var armed: float = staff.page_t + 0.3
	_assert_key_lift(staff, rect, "primary", armed - 0.1, armed, 0)
	_assert_key_lift(staff, rect, "primary", armed + 0.1, armed, 2)
	_assert_key_lift(staff, rect, "primary", armed + 0.55, armed, 1)
	staff.hover_id = "primary"
	_assert_key_lift(staff, rect, "primary", armed + 0.55, armed, 0)
	staff.hover_id = ""
	staff.rm = true
	_assert_key_lift(staff, rect, "primary", armed + 0.1, armed, 0)
	staff.rm = false
	assert_bool(staff.pins.open(staff.now)).is_true()
	staff.now = staff.pins_t + staff.tuning.pins_pop_s + 0.1
	var ok: Rect2 = PinStepDraw.confirm_rect(PinStepDraw.box_y(staff))
	assert_that(_hit(staff, "pinsok").rect).is_equal(ok)
	armed = staff.pins_t + 0.3
	_assert_key_lift(staff, ok, "pinsok", armed + 0.1, armed, 2)
	_assert_key_lift(staff, ok, "pinsok", armed + 0.55, armed, 1)
	staff.hover_id = "pinsok"
	_assert_key_lift(staff, ok, "pinsok", armed + 0.55, armed, 0)
	staff.hover_id = ""
	staff.rm = true
	_assert_key_lift(staff, ok, "pinsok", armed + 0.55, armed, 0)
	staff.rm = false


## At `now`, the lift of key `id` armed at `armed_t` is `lift`, and key_button draws its 9-slice
## (same size) and its labels that many art px up (pushed 2 px right while hovered).
func _assert_key_lift(
	staff: BuildPage, rect: Rect2, id: String, now: float, armed_t: float, lift: int
) -> void:
	staff.now = now
	var hv: bool = staff.is_hovered(id)
	assert_int(BoosterPageDraw.key_lift(now, armed_t, staff.tuning, staff.rm, hv)).is_equal(lift)
	var pen: _PenRecorder = _PenRecorder.new()
	BuildPageDraw.key_button(pen, staff, rect, "KEY", "SUB", true, id, armed_t)
	var sh: float = 2.0 if hv and not staff.rm else 0.0
	var face: Rect2 = Rect2(rect.position + Vector2(sh, -lift), rect.size)
	assert_that(pen.nines).is_equal([face])
	assert_that(pen.text_y).is_equal([face.position.y + 5, face.position.y + rect.size.y - 9])


## Page 2 with the BADGE PINS step confirmed (no pin) and the regulars kept.
func _dealt(board: StartBoard) -> BuildPage:
	board.show_page(2)
	var staff: BuildPage = board.staff
	staff.advance(0.2)
	assert_bool(staff.primary()).is_true()
	assert_bool(staff.keep_regulars()).is_true()
	staff.advance(1.0)
	await get_tree().process_frame
	return staff


static func _hit(staff: BuildPage, id: String) -> Dictionary:
	staff.hits = BuildPageDraw.hits(staff)
	for entry: Dictionary in staff.hits:
		if entry.id == id:
			return entry
	return {}


func _assert_sheet_aligned(order: OrderSheet, k: float) -> void:
	var sheet: Rect2 = order.get_global_rect()
	var paper: Rect2 = (order.get_node("Paper") as Control).get_global_rect()
	var clip: Rect2 = (order.get_node("Clip") as Control).get_global_rect()
	assert_float(clip.get_center().x).is_equal_approx(sheet.get_center().x, 0.5)
	assert_float(paper.get_center().x).is_equal_approx(sheet.get_center().x, 0.5)
	var pad: float = OrderSheet.PAD * k
	var right: float = paper.end.x - pad
	var count_box: Rect2 = (order.find_child("CountBox", true, false) as Control).get_global_rect()
	assert_float(count_box.end.x).is_equal_approx(right, 0.5)
	assert_float(order.equation.get_global_rect().position.x).is_equal_approx(
		paper.position.x + pad, 0.5
	)
	var ticks: int = 0
	for tick: Node in order.find_children("Tick*", "", true, false):
		ticks += 1
		assert_float((tick as Control).get_global_rect().end.x).is_equal_approx(right, 0.5)
	assert_int(ticks).is_greater(0)
	var cells: Array[Node] = order.find_children("Family*", "", true, false)
	assert_int(cells.size()).is_equal(3)
	var first: Rect2 = (cells[0] as Control).get_global_rect()
	var last: Rect2 = (cells[2] as Control).get_global_rect()
	assert_float(first.position.x).is_equal_approx(paper.position.x + pad, 0.5)
	assert_float(last.end.x).is_equal_approx(right, 0.5)
	assert_float(paper.end.y - last.end.y).is_equal_approx(pad, 0.5)
	_assert_sheet_header(order, k)
	# Each line's number, name, source and price share one centre line.
	var lines: int = 0
	while order.find_child("RowNumber%d" % lines, true, false) != null:
		var number: Control = order.find_child("RowNumber%d" % lines, true, false)
		var centre: float = number.get_global_rect().get_center().y
		for column: String in ["RowName", "RowSource", "RowPrice"]:
			var part: Control = order.find_child("%s%d" % [column, lines], true, false)
			if part != null:
				assert_float(part.get_global_rect().get_center().y).is_equal_approx(centre, 1.0)
		lines += 1
	assert_int(lines).is_greater(order.shown_cards.size())


## The count box clears the brass clip (they touched), and the title, the cart icon and the count
## share the box's centre line.
func _assert_sheet_header(order: OrderSheet, k: float) -> void:
	var clip: Rect2 = (order.get_node("Clip") as Control).get_global_rect()
	var box: Rect2 = (order.find_child("CountBox", true, false) as Control).get_global_rect()
	assert_float(box.position.y - clip.end.y).is_greater_equal(2.0 * k)
	var icon: Rect2 = (order.find_child("CountIcon", true, false) as Control).get_global_rect()
	var count: Rect2 = (order.find_child("Count", true, false) as Control).get_global_rect()
	assert_bool(box.encloses(icon)).is_true()
	assert_float(icon.get_center().y).is_equal_approx(box.get_center().y, 0.5)
	assert_float(absf(count.get_center().y - box.get_center().y)).is_less_equal(k)


func _resize(board: StartBoard, extent: Vector2) -> void:
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	board.size = extent
	board._resize()
	await get_tree().process_frame


func _stage_rect(board: StartBoard) -> Rect2:
	return Rect2(board._stage.global_position, ShiftStage.SIZE * board._stage.scale)


## A new run on a profile that earned the catalogue's first `earned` earned pins (those with an
## unlock condition; the pins every profile starts with are owned anyway): earned > 0 holds OPEN
## STORE for the BADGE PINS step.
func _screen(earned: int = 1) -> ShiftScreen:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(true)
	screen.profile.worn_pins.clear()
	for pin: PinDefinition in screen._catalogue.pins:
		if pin.unlock_condition != null and earned > 0:
			screen.profile.unlocked_pins.append(pin.id)
			earned -= 1
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	# Page 2 follows page 1's opened boosters (the clock-in refuses a sealed one).
	var board: StartBoard = screen._cart_reveal.board
	for index: int in screen.run.start_setup.boosters.size():
		board._choice.open_booster.call(index)
	return screen


func _save() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join(SaveService.RUN_FILE)))


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## An ArtPen that records its nine-slices, its words and their tops instead of drawing.
class _PenRecorder:
	extends ArtPen
	var nines: Array[Rect2] = []
	var text_y: Array[float] = []
	var texts: Array[String] = []

	func _init() -> void:
		super(null)

	func r(_x: float, _y: float, _w: float, _h: float, _colour: Color) -> void:
		pass

	func chunky(
		text: String,
		_x: float,
		_y: float,
		_colour: Color,
		_scale: float = 1.0,
		_align: int = HORIZONTAL_ALIGNMENT_LEFT
	) -> float:
		texts.append(text)
		return 0.0

	func atk(
		text: String,
		_cx: float,
		_baseline: float,
		_art_size: float,
		_colour: Color,
		_weight: int = 650,
		_align: int = HORIZONTAL_ALIGNMENT_CENTER
	) -> void:
		texts.append(text)

	func nine(
		_frame: Texture2D,
		x: float,
		y: float,
		w: float,
		h: float,
		_margins: Vector4i,
		_modulate: Color = Color.WHITE
	) -> void:
		nines.append(Rect2(x, y, w, h))

	func tex_part(
		_texture: Texture2D,
		_region: Rect2,
		_x: float,
		_y: float,
		_w: float,
		_h: float,
		_modulate: Color = Color.WHITE
	) -> void:
		pass

	func tex(
		_texture: Texture2D,
		_x: float,
		_y: float,
		_modulate: Color = Color.WHITE,
		_scale: float = 1.0
	) -> void:
		pass

	func pix(
		text: String,
		_x: float,
		y: float,
		_colour: Color,
		_scale: float = 1.0,
		_align: int = HORIZONTAL_ALIGNMENT_LEFT
	) -> float:
		texts.append(text)
		text_y.append(y)
		return 0.0

	func caps(
		text: String,
		_x: float,
		y: float,
		_colour: Color,
		_scale: float = 1.0,
		_align: int = HORIZONTAL_ALIGNMENT_LEFT
	) -> float:
		texts.append(text)
		text_y.append(y)
		return 0.0
