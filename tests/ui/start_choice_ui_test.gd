extends GdUnitTestSuite
## The starter pack choice in the cart reveal (#107, mock-up starter_choice_107.html layout A,
## v0.63; decided with the user on 2026-10-26: Q1 C, Q2 A, Q3 B, Q4 A): the offer's packs under
## the staples with the good first pick raised, today's products as pictures in the dispenser, the
## raise and the confirm, taps that never end the choice, the popups, the layout, and on the real
## shift screen the run saved before the choice, the pick starting shift 1 and a resume that opens
## the same offer. The reveal is driven by its API: headless runs deliver no input events.

const SCREEN := "res://ui/shift_screen.tscn"
const RECIPE := "res://data/decks/pack_starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const SEED := 20261026

var _host: Control
var _cart: Control
var _taken: Array[StarterPackDefinition] = []
var _folder: String = ""


func before_test() -> void:
	_taken = []
	_host = auto_free(Control.new())
	_host.size = ShiftStage.SIZE
	add_child(_host)
	_cart = Control.new()
	_cart.position = Vector2(1078, 10)
	_cart.size = Vector2(128, 36)
	_host.add_child(_cart)
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The choice: the offer's three packs (names, three cards each), the good first pick raised with
## its ribbon and named on the push bar, today's shared products in the dispenser's window, and no
## TODAY'S PICKS yet.
func test_the_choice_shows_the_offer_with_the_first_pick_raised() -> void:
	var run: RunState = _choice_run(SEED, true)
	var reveal: CartReveal = _reveal(run)
	assert_bool(reveal.is_choosing()).is_true()
	var panel: RevealPanel = reveal.panel()
	var choice: PackChoice = panel.choice
	assert_int(choice.faces.size()).is_equal(3)
	for index: int in choice.faces.size():
		var face: PackFace = choice.faces[index]
		var pack: StarterPackDefinition = run.start_offer.packs[index]
		assert_str(face.name_text()).is_equal(pack.display_name)
		assert_int(face.tiles.size()).is_equal(3)
		assert_bool(face.has_ribbon()).is_equal(pack == run.start_offer.first_pick)
		assert_bool(face.raised).is_equal(pack == run.start_offer.first_pick)
	assert_int(choice.raised_index).is_equal(1)
	assert_str(choice.bar_text()).is_equal("TAKE BREAKFAST RUN ›")
	assert_array(panel.picks).is_empty()
	assert_int(panel.dispenser.heap_left()).is_equal(run.start_offer.shared.size())
	reveal.freeze_at(reveal.end_time())
	assert_str(panel.dispenser.led_text()).is_equal(RevealPanel.CHOOSE_LED)
	# A profile that has won: nothing raised, the bar waits.
	var won: CartReveal = _reveal(_choice_run(SEED, false))
	assert_int(won.panel().choice.raised_index).is_equal(-1)
	assert_str(won.panel().choice.bar_text()).is_equal(PackChoice.BAR_IDLE_TEXT)
	assert_bool(won.take_pack()).is_false()
	assert_bool(won.is_choosing()).is_true()


## A tap during the packs' drop jumps to the choice; after that taps and time never end it: only
## taking a pack does.
func test_taps_and_time_never_end_the_choice() -> void:
	var reveal: CartReveal = _reveal(_choice_run(SEED, true))
	assert_float(reveal.time()).is_less(reveal.end_time())
	reveal.tap()
	assert_float(reveal.time()).is_equal_approx(reveal.end_time(), 0.001)
	reveal.tap()
	reveal.advance(30.0)
	assert_bool(reveal.is_choosing()).is_true()
	assert_bool(reveal.is_folding()).is_false()
	assert_array(_taken).is_empty()


## Raising another pack changes the bar; taking it emits pack_taken, and the pack's cards are then
## the first picks (flying in from the face), today's products the rest, and the summary names
## the pack.
func test_raising_and_taking_a_pack() -> void:
	var run: RunState = _choice_run(SEED, true)
	var reveal: CartReveal = _reveal(run)
	reveal.freeze_at(reveal.end_time())
	var other: StarterPackDefinition = run.start_offer.packs[2]
	reveal.raise_pack(2)
	assert_int(reveal.panel().choice.raised_index).is_equal(2)
	assert_str(reveal.panel().choice.bar_text()).is_equal(
		"TAKE %s ›" % other.display_name.to_upper()
	)
	assert_bool(reveal.take_pack()).is_true()
	assert_array(_taken).is_equal([other])
	assert_bool(reveal.is_choosing()).is_false()
	var panel: RevealPanel = reveal.panel()
	assert_object(panel.pack).is_same(other)
	assert_array(panel.picks).is_equal(other.cards + run.start_offer.shared)
	assert_int(panel.pick_tiles.size()).is_equal(9)
	reveal.freeze_at(reveal.end_time())
	var texts: Array[String] = []
	for found: Node in panel.summary.find_children("*", "Label", true, false):
		texts.append((found as Label).text)
	assert_array(texts).contains(["3 from %s" % other.display_name, "6 from today’s stock"])
	assert_bool(panel.dispenser.is_sold_out()).is_true()


## The popups: a pack's card and one of today's products in the dispenser's window (Q2 A) open
## their scan popup.
func test_pack_cards_and_todays_products_open_their_popup() -> void:
	var run: RunState = _choice_run(SEED, true)
	var reveal: CartReveal = _reveal(run)
	reveal.freeze_at(reveal.end_time())
	var tile: RevealTile = reveal.panel().choice.faces[0].tiles[1]
	assert_object(reveal.tile_at(tile.get_global_rect().get_center())).is_same(tile)
	reveal.show_popup(tile)
	assert_bool(reveal.popup().visible).is_true()
	assert_object(reveal.popup_tile()).is_same(tile)
	var heap: Array[TextureRect] = reveal.panel().dispenser.heap_art()
	var front: TextureRect = heap[heap.size() - 1]
	var at: Vector2 = front.get_global_rect().get_center()
	var target: Control = reveal.target_at(at)
	assert_object(target).is_not_null()
	reveal.show_popup(target)
	assert_bool(reveal.popup().visible).is_true()
	assert_bool(run.start_offer.shared.has(reveal.panel().dispenser.card_at(at))).is_true()
	# The first popup's content, cleared by the second, is freed on the next frame.
	await get_tree().process_frame


## The layout at the 1280x720 stage: the faces inside the panel, apart from each other, from the
## dispenser and from the push bar; each face's cards and its line inside it, the line on at most
## two rows; the push bar inside the panel.
func test_the_choice_fits_the_panel() -> void:
	var reveal: CartReveal = _reveal(_choice_run(SEED, true))
	reveal.freeze_at(reveal.end_time())
	var panel: RevealPanel = reveal.panel()
	var box: Rect2 = panel.get_global_rect()
	var faces: Array[PackFace] = panel.choice.faces
	var bar: Control = panel.choice.find_child("ConfirmBar", true, false)
	assert_bool(box.encloses(bar.get_global_rect())).is_true()
	var cabinet: Rect2 = Rect2(
		panel.get_global_rect().position - RevealPanel.RECT.position, Vector2.ZERO
	)
	cabinet.position += StockDispenser.CABINET_RECT.position
	cabinet.size = StockDispenser.CABINET_RECT.size
	for index: int in faces.size():
		var face: Rect2 = faces[index].get_global_rect()
		var what: String = String(faces[index].pack.id)
		assert_bool(box.encloses(face)).override_failure_message(what).is_true()
		(
			assert_bool(face.intersects(bar.get_global_rect()))
			. override_failure_message(what)
			. is_false()
		)
		assert_bool(face.intersects(cabinet)).override_failure_message(what).is_false()
		for other: int in range(index + 1, faces.size()):
			assert_bool(face.intersects(faces[other].get_global_rect())).is_false()
		for tile: RevealTile in faces[index].tiles:
			var rect: Rect2 = tile.get_global_rect()
			assert_bool(face.encloses(rect)).override_failure_message(what).is_true()
		for found: Node in faces[index].find_children("*", "Label", true, false):
			var label: Label = found as Label
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				continue
			assert_int(label.get_line_count()).override_failure_message(what).is_less_equal(2)
			var rows: float = label.get_line_count() * label.get_line_height()
			assert_float(rows).override_failure_message(what).is_less_equal(label.size.y + 0.5)
			for tile: RevealTile in faces[index].tiles:
				(
					assert_bool(label.get_global_rect().intersects(tile.get_global_rect()))
					. override_failure_message(what)
					. is_false()
				)


## On the shift screen: a new run with the reveal waits for its pick (saved as choose_start with
## its offer); taking a pack starts shift 1 (a hand of 8, saved as planning with the pack) and
## logs start_choice.
func test_the_screen_saves_the_offer_and_starts_shift_one_on_the_pick() -> void:
	var screen: ShiftScreen = await _screen()
	screen.start_new_run(SEED, true, true)
	var run: RunState = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_bool(screen._cart_reveal.is_choosing()).is_true()
	var waiting: Dictionary = _saved()
	assert_str(waiting["phase"]).is_equal("choose_start")
	assert_array(waiting["start_offer"]["packs"]).is_equal(
		run.start_offer.packs.map(
			func(offered: StarterPackDefinition) -> String: return String(offered.id)
		)
	)
	screen._cart_reveal.freeze_at(screen._cart_reveal.end_time())
	screen._cart_reveal.raise_pack(0)
	var pack: StarterPackDefinition = run.start_offer.packs[0]
	assert_bool(screen._cart_reveal.take_pack()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(run.hand().size()).is_equal(run.balance.hand_size)
	assert_bool(screen._cart_reveal.is_open()).is_true()
	var playing: Dictionary = _saved()
	assert_str(playing["phase"]).is_equal("planning")
	assert_str(playing["start_pack"]).is_equal(String(pack.id))
	var event: Dictionary = _last_event("start_choice")
	assert_str(event["pick"]).is_equal(String(pack.id))
	assert_bool(event["chosen"]).is_true()
	assert_float(event["decide_ms"]).is_greater_equal(0.0)


## Quitting during the choice can't reroll it: a new screen over the same save opens the same
## offer, waiting for its pick.
func test_a_resume_opens_the_same_offer() -> void:
	var first: ShiftScreen = await _screen()
	first.start_new_run(SEED, true, true)
	var packs: Array[StarterPackDefinition] = first.run.start_offer.packs.duplicate()
	var shared: Array[CardDefinition] = first.run.start_offer.shared.duplicate()
	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_array(resumed.run.start_offer.packs).is_equal(packs)
	assert_array(resumed.run.start_offer.shared).is_equal(shared)
	assert_bool(resumed._cart_reveal.is_choosing()).is_true()


func _choice_run(seed_value: int, first_pick: bool) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var recipe: DeckDefinition = load(RECIPE)
	var stock: RunStock = RunStock.starting(balance)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.STARTING_DECK_STREAM
	)
	var offer: StartOffer = StartingDeck.deal_offer(recipe, stock, balance, stream, first_pick)
	var deck: DeckDefinition = StartingDeck.before_pick(recipe, offer)
	return RunState.new(seed_value, deck, balance, stock, offer)


func _reveal(run: RunState) -> CartReveal:
	var reveal: CartReveal = CartReveal.new()
	_host.add_child(reveal)
	reveal.pack_taken.connect(func(pack: StarterPackDefinition) -> void: _taken.append(pack))
	assert_bool(reveal.play(run, _cart, false)).is_true()
	# Driven by hand only.
	reveal.set_process(false)
	return reveal


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	scene_runner(screen)
	for frame: int in range(4):
		await get_tree().process_frame
	return screen


func _saved() -> Dictionary:
	var path: String = _folder.path_join(SaveService.RUN_FILE)
	if not FileAccess.file_exists(path):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
