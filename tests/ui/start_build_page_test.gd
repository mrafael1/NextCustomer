extends GdUnitTestSuite
## Start screen page 2, YOUR BUILD (v1.32, mock-up start_boosters_v3): the BADGE PINS step that
## gates the packs (confirming with no pin allowed, pins changed later with no re-deal), the packs
## face up with a hover spread (the others sink behind the bench) and a pick, NEW PACKS once a run
## (keeps the pick, then USED), OPEN STORE held until a pick, and the card -> item -> cart flight.
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


## The page opens on the BADGE PINS step while the packs wait: no pick, no NEW PACKS, one hit over
## the held packs (it opens the step), the primary key says BADGE PINS. The step's box and its
## confirm key sit on the stage. Confirming with no pin is allowed: the packs deal, the confirm is
## saved and nothing is worn.
func test_badge_pins_step_gates_the_packs() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = board.staff
	board.show_page(2)
	staff.advance(0.2)
	assert_bool(staff.pins.owned().is_empty()).is_false()
	assert_bool(staff.packs_held()).is_true()
	assert_bool(staff.pins_open).is_true()
	assert_bool(staff.dealt).is_false()
	assert_str(BuildPageDraw.primary_label(staff)[0]).is_equal("BADGE PINS")
	assert_bool(_hit(staff, "heldpacks").is_empty()).is_false()
	assert_bool(_hit(staff, "pack0").is_empty()).is_true()
	var box: Rect2 = Rect2(BuildPage.PIN_BOX)
	assert_bool(ART.encloses(box)).is_true()
	var confirm: Dictionary = _hit(staff, "pinsok")
	assert_bool(confirm.is_empty()).is_false()
	assert_bool(box.encloses(confirm.rect)).is_true()
	# While held, the order sheet keeps the pack's lines pending ("? ? ?") and out of the count.
	var regulars: int = screen.run.starter.core_cards.size()
	var row: Label = staff.order.find_child("RowName%d" % regulars, true, false)
	assert_str(row.text).is_equal("? ? ?")
	assert_int(staff.order.shown_cards.size()).is_equal(
		regulars + screen.run.start_setup.shared().size()
	)
	assert_int(staff.cart_target()).is_equal(staff.order.shown_cards.size())
	assert_str(staff.order.waiting_note.text).contains("after your pins")
	# Esc closes the step: the packs stay held; a pick, NEW PACKS and OPEN STORE (also straight
	# through the board's clock-in) are refused.
	assert_bool(staff.handle_key(KEY_ESCAPE)).is_true()
	assert_bool(staff.pins_open).is_false()
	assert_int(staff.picked()).is_equal(-1)
	board.pick(0)
	assert_int(staff.picked()).is_equal(-1)
	assert_bool(staff.new_packs()).is_false()
	assert_str(staff.message).is_equal("PACKS DEAL AFTER PINS")
	assert_bool(board.clock_in()).is_false()
	assert_bool(staff.open_store()).is_false()
	assert_object(staff.flight).is_null()
	# P opens it again; NO PINS confirms.
	assert_bool(staff.handle_key(KEY_P)).is_true()
	staff.advance(0.2)
	assert_bool(staff.primary()).is_true()
	assert_bool(staff.pins_open).is_false()
	assert_bool(staff.packs_held()).is_false()
	assert_bool(staff.dealt).is_true()
	assert_int(staff.stacks.size()).is_equal(3)
	assert_array(screen.run.pins).is_empty()
	var saved: RunSave = RunSave.from_dictionary(_save(), ContentLookup.new(screen.run.balance))
	assert_bool(saved.run.start_setup.pins_confirmed).is_true()


## A profile owning only the pins every profile starts with (none earned, none worn) gets its
## packs at once (mock-up NEW · 0): no step, no hold, the order sheet lists the regulars and
## booster lines; the good first pick is suggested (TAKE PACK) and the primary key takes it.
func test_a_new_profile_deals_the_packs_at_once() -> void:
	var screen: ShiftScreen = await _screen(0)
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = board.staff
	assert_bool(staff.pins.owned().is_empty()).is_false()
	assert_int(staff.pins.gate_count()).is_equal(0)
	board.show_page(2)
	staff.advance(0.2)
	assert_bool(staff.packs_held()).is_false()
	assert_bool(staff.pins_open).is_false()
	assert_bool(staff.dealt).is_true()
	assert_bool(_hit(staff, "pack0").is_empty()).is_false()
	var regulars: int = screen.run.starter.core_cards.size()
	var row: Label = staff.order.find_child("RowName%d" % regulars, true, false)
	assert_str(row.text).is_not_equal("? ? ?")
	# A player who has never won gets the good first pick suggested, not made (mock-up v3): nothing
	# picked, the cart without a pack, the primary key TAKE PACK 2, which takes it.
	staff.advance(1.0)
	var first: StarterPackDefinition = screen.run.start_offer.first_pick
	assert_object(first).is_not_null()
	assert_int(staff.picked()).is_equal(-1)
	assert_str(String(screen.run.start_setup.picked)).is_empty()
	var at: int = screen.run.start_offer.packs.find(first)
	assert_str(BuildPageDraw.primary_label(staff)[0]).is_equal("TAKE PACK %d" % (at + 1))
	assert_bool(staff.primary()).is_true()
	assert_int(staff.picked()).is_equal(at)
	assert_str(String(screen.run.start_setup.picked)).is_equal(String(first.id))
	# Wearing one of those pins holds the next run's packs for the step.
	screen.profile.worn_pins.append(staff.pins.owned()[0].id)
	assert_int(staff.pins.gate_count()).is_equal(1)


## With every pin owned (8), the step's rows turn compact and all fit inside the box, above the
## packs' gate note and the confirm key, apart from each other; each rule fits its one line; keys
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
## TOO stands under the badge's NO PIN, ESC · BACK in the packs' note; the ticker is clear while
## the step is open and says BADGE PINS FIRST · PRESS P once it closes with the packs held.
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
	for pin: PinDefinition in owned:
		assert_bool(_hit(staff, "pin_%s" % pin.id).is_empty()).is_false()
	for pin: PinDefinition in locked:
		assert_bool(_hit(staff, "pin_%s" % pin.id).is_empty()).is_true()
		assert_str(PinStepDraw.unlock_text(pin)).starts_with("Unlock: ")
	var pen: _PenRecorder = _PenRecorder.new()
	PinStepDraw.draw(pen, staff)
	assert_int(pen.texts.count(PinStepDraw.LOCKED_TEXT)).is_equal(locked.size())
	assert_bool(pen.texts.has(PinStepDraw.NO_PIN_NOTE)).is_true()
	assert_bool(pen.texts.has(PinStepDraw.BACK_NOTE)).is_true()
	assert_bool(pen.texts.has("NONE IS FINE TOO")).is_false()
	for text: String in pen.texts:
		assert_bool(text.is_valid_int()).override_failure_message(text).is_false()
	assert_str(BuildPageDraw.hint_line(staff)).is_empty()
	assert_bool(staff.pins.close()).is_true()
	assert_bool(staff.packs_held()).is_true()
	assert_str(BuildPageDraw.hint_line(staff)).is_equal(BuildPageDraw.PINS_FIRST_HINT)


## A pin worn in the step is saved on the run and the profile; the step opens again later (the
## corkboard) and a new choice keeps the dealt packs (no re-deal).
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
	var packs: Array[StarterPackDefinition] = screen.run.start_offer.packs.duplicate()
	staff.advance(1.0)
	(_hit(staff, "pins").act as Callable).call()
	assert_bool(staff.pins_open).is_true()
	staff.advance(0.2)
	assert_bool(staff.handle_key(KEY_2)).is_true()
	assert_bool(staff.primary()).is_true()
	assert_array(screen.run.pins).is_equal([owned[1]])
	assert_array(screen.run.start_offer.packs).is_equal(packs)
	assert_bool(staff.dealt).is_true()
	assert_bool(staff.packs_held()).is_false()


## Hovering a pack spreads its cards and sinks the other two behind the bench (their layer is
## clipped at the bench's top); the order sheet previews the hovered pack dashed. The three pack
## hits stand side by side on the stage, clear of the deck, the order sheet and the primary key.
func test_hover_spreads_one_pack_and_sinks_the_others() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	_clear_pick(board)
	var clip: Control = staff.get_node("BenchClip")
	assert_bool(clip.clip_contents).is_true()
	assert_float(clip.size.y).is_equal(BuildPage.BENCH_Y * ArtPen.UNIT)
	var rects: Array[Rect2] = []
	for k: int in 3:
		rects.append(_hit(staff, "pack%d" % k).rect)
	var deck: Rect2 = _hit(staff, "newpacks").rect
	var sheet: Rect2 = Rect2(BuildPage.ORDER_POSITION / ArtPen.UNIT, staff.order.size / ArtPen.UNIT)
	for k: int in 3:
		assert_bool(ART.encloses(rects[k])).is_true()
		assert_bool(rects[k].intersects(deck)).is_false()
		assert_bool(rects[k].intersects(sheet)).is_false()
		assert_bool(rects[k].intersects(Rect2(BuildPage.PRIMARY_RECT))).is_false()
		if k > 0:
			assert_bool(rects[k].intersects(rects[k - 1])).is_false()
	staff.mouse = rects[1].get_center()
	staff.advance(0.05)
	assert_int(staff.hovered_pack()).is_equal(1)
	assert_int(staff.spread).is_equal(1)
	assert_float(staff.stacks[0].sv).is_equal(1.0)
	assert_float(staff.stacks[2].sv).is_equal(1.0)
	assert_float(staff.stacks[1].sv).is_equal(0.0)
	assert_object(staff.order.pack_rows).is_not_null()
	assert_bool(staff.order.pack_rows.dashed).is_true()
	staff.mouse = Vector2(-1, -1)
	staff.advance(0.05)
	assert_int(staff.spread).is_equal(-1)
	assert_float(staff.stacks[0].sv).is_equal(0.0)


## OPEN STORE waits for a pick: with no pick (and no good first pick) the key is PICK A PACK,
## unlit, and OPEN STORE is refused; the sheet's waiting note says "pick a pack". A pick (key 2)
## lights OPEN STORE and tints the pack's lines solid on the sheet, inside its paper.
func test_open_store_waits_for_a_pick() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	_clear_pick(board)
	var packed: int = screen.run.start_offer.packs[1].cards.size()
	assert_int(staff.picked()).is_equal(-1)
	var label: Array = BuildPageDraw.primary_label(staff)
	assert_str(label[0]).is_equal("PICK A PACK")
	assert_bool(label[2]).is_false()
	assert_bool(board.clock_in()).is_false()
	assert_bool(staff.primary()).is_false()
	assert_str(staff.message).is_equal("PICK A PACK FIRST")
	assert_str(staff.order.waiting_note.text).contains("when you pick a pack")
	assert_bool(staff.handle_key(KEY_2)).is_true()
	assert_int(staff.picked()).is_equal(1)
	label = BuildPageDraw.primary_label(staff)
	assert_str(label[0]).is_equal("OPEN STORE ›")
	assert_str(label[1]).is_equal("%d CARDS" % staff.cart_target())
	assert_bool(label[2]).is_true()
	assert_object(staff.order.waiting_note).is_null()
	assert_bool(staff.order.pack_rows.dashed).is_false()
	var paper: Rect2 = (staff.order.get_node("Paper") as Control).get_global_rect()
	assert_bool(paper.encloses(staff.order.pack_rows.get_global_rect())).is_true()
	var row: float = OrderSheet.ROW * staff.order.get_global_transform().get_scale().y
	assert_float(staff.order.pack_rows.get_global_rect().size.y).is_equal_approx(packed * row, 0.5)
	# Once the refusal's flash is over, the hint LED says what comes next.
	staff.advance(2.5)
	assert_str(BuildPageDraw.hint_line(staff)).is_equal("OPEN STORE, THEN START SHIFT 1")


## NEW PACKS (the deck, N) once a run: the packs not picked re-deal, the pick keeps its place,
## the regulars stay, it is saved; then the deck is USED and NEW PACKS is refused.
func test_new_packs_once_keeps_the_pick() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	_clear_pick(board)
	board.pick(1)
	var old: Array[StarterPackDefinition] = screen.run.start_offer.packs.duplicate()
	var core: Array[CardDefinition] = screen.run.starter.core_cards.duplicate()
	assert_bool(BuildPageDraw.deck_live(staff)).is_true()
	assert_bool(staff.handle_key(KEY_N)).is_true()
	var fresh: Array[StarterPackDefinition] = screen.run.start_offer.packs
	assert_array(fresh).is_not_equal(old)
	assert_object(fresh[1]).is_same(old[1])
	assert_int(staff.picked()).is_equal(1)
	assert_array(screen.run.starter.core_cards).is_equal(core)
	assert_bool(BuildPageDraw.deck_live(staff)).is_false()
	staff.advance(1.0)
	assert_bool(staff.new_packs()).is_false()
	assert_str(staff.message).is_equal("NEW PACKS USED")
	for k: int in 3:
		assert_object(staff.stacks[k].pack).is_same(fresh[k])
	var saved: RunSave = RunSave.from_dictionary(_save(), ContentLookup.new(screen.run.balance))
	assert_bool(saved.run.start_setup.packs_redrawn).is_true()
	assert_str(String(saved.run.start_setup.picked)).is_equal(String(old[1].id))


## OPEN STORE with motion plays the flight (cards -> items -> cart): one modal hit swallows the
## page, every cart card flies from a point on the stage, then the board clocks in with the pick.
func test_open_store_flies_the_cards_to_the_cart() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	board.pick(0)
	screen.profile.set_reduced_motion(false)
	board.refresh()
	var clocked: Array[StarterPackDefinition] = []
	board.clocked_in.connect(func(pack: StarterPackDefinition) -> void: clocked.append(pack))
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
	assert_array(clocked).is_equal([screen.run.start_offer.packs[0]])


## The page fills the stage at both sizes; its keys (‹ STORE, the LED, the primary key) and the
## deck sit on it, clear of each other; the order sheet sits above the footer, its columns lined
## up. Picked and not.
func test_page_parts_fit_the_stage_at_both_sizes() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	for selected: int in [-1, 1]:
		if selected >= 0:
			board.pick(selected)
		for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
			await _resize(board, extent)
			var stage: Rect2 = _stage_rect(board)
			var k: float = board._stage.scale.x
			assert_bool(staff.get_global_rect().is_equal_approx(stage)).is_true()
			var parts: Array[Rect2] = [
				Rect2(BuildPage.BACK_RECT),
				Rect2(BuildPage.LED_RECT),
				Rect2(BuildPage.PRIMARY_RECT),
				_hit(staff, "newpacks").rect,
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


## v1.32 press-bob on page 2: OPEN STORE (armed 0.3 s after the pick) and the pins step's OK
## key (armed 0.3 s after the step opens) hop to 2 art px, then bob 1 px; each rests while hovered
## and under reduced motion; the 9-slice and its labels ride the lift and the hit rects never move.
func test_page_two_keys_press_bob_on_fixed_rects() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var staff: BuildPage = await _dealt(board)
	_clear_pick(board)
	assert_bool(staff.handle_key(KEY_2)).is_true()
	staff.rm = false
	var rect: Rect2 = Rect2(BuildPage.PRIMARY_RECT)
	assert_that(_hit(staff, "primary").rect).is_equal(rect)
	var armed: float = staff.pick_t + 0.3
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


## Page 2 with the BADGE PINS step confirmed (no pin) and the deal landed.
func _dealt(board: StartBoard) -> BuildPage:
	board.show_page(2)
	var staff: BuildPage = board.staff
	staff.advance(0.2)
	assert_bool(staff.primary()).is_true()
	staff.advance(1.0)
	await get_tree().process_frame
	return staff


## No pick and no good first pick (a new run only suggests its good first pack).
static func _clear_pick(board: StartBoard) -> void:
	board.run.start_setup.picked = &""
	board.run.start_offer.first_pick = null
	board.refresh()


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
	if order.pack_rows != null:
		# The pack's highlight runs as far past the lines on the right as on the left.
		var rows: Rect2 = order.pack_rows.get_global_rect()
		assert_float(rows.end.x - right).is_equal_approx(
			paper.position.x + pad - rows.position.x, 0.5
		)
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
## unlock condition; the pins every profile starts with are owned anyway): earned > 0 holds the
## packs for the BADGE PINS step.
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
