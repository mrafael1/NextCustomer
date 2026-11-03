extends GdUnitTestSuite
## The starter pack choice in the cart reveal (#107, v0.63; decided with the user on 2026-10-26:
## Q1 C, Q2 A, Q3 B, Q4 A), on the start screen's board since 2026-11-03 (mock-up start_screen.html
## layout A): the offer's packs with the good first pick picked, the pick and the confirm, taps
## that never end the choice, the popups, the packs' layout, and on the real shift screen the run
## saved before the choice, the pick starting shift 1 and a resume that opens the same offer. The
## board's own layout and preview are start_board_test's. The reveal is driven by its API:
## headless runs deliver no input events.

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


## The choice: the offer's three packs (names, three cards each), the good first pick picked with
## its ribbon and named on the OPEN STORE key; a profile that has won picks nothing, and the key
## waits.
func test_the_choice_shows_the_offer_with_the_first_pick_raised() -> void:
	var run: RunState = _choice_run(SEED, true)
	var reveal: CartReveal = _reveal(run)
	assert_bool(reveal.is_choosing()).is_true()
	var choice: PackChoice = reveal.board.choice
	assert_int(choice.faces.size()).is_equal(3)
	for index: int in choice.faces.size():
		var face: PackFace = choice.faces[index]
		var pack: StarterPackDefinition = run.start_offer.packs[index]
		assert_str(face.name_text()).is_equal(pack.display_name)
		assert_int(face.tiles.size()).is_equal(3)
		assert_bool(face.has_ribbon()).is_equal(pack == run.start_offer.first_pick)
		assert_bool(face.raised).is_equal(pack == run.start_offer.first_pick)
		assert_bool(face.picked_tab.visible).is_equal(face.raised)
	assert_int(choice.raised_index).is_equal(1)
	assert_str(reveal.board.key_text()).is_equal(StartBoard.KEY_OPEN_TEXT)
	assert_str(reveal.board.key_sub_text()).is_equal(
		StartBoard.KEY_SUB_TEXT % [1, "Breakfast run", 13]
	)
	# A profile that has won: nothing picked, the key waits.
	var won: CartReveal = _reveal(_choice_run(SEED, false))
	assert_int(won.board.choice.raised_index).is_equal(-1)
	assert_str(won.board.key_text()).is_equal(StartBoard.KEY_IDLE_TEXT)
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


## Picking another pack changes the key; taking it emits pack_taken and the board folds into the
## Cart button at once (no fly-in: the cart was shown), then the reveal closes and finishes.
func test_raising_and_taking_a_pack() -> void:
	var run: RunState = _choice_run(SEED, true)
	var reveal: CartReveal = _reveal(run)
	var finished: Array[bool] = []
	reveal.finished.connect(func() -> void: finished.append(true))
	reveal.freeze_at(reveal.end_time())
	var other: StarterPackDefinition = run.start_offer.packs[2]
	reveal.raise_pack(2)
	assert_int(reveal.board.choice.raised_index).is_equal(2)
	assert_str(reveal.board.key_sub_text()).contains(other.display_name)
	assert_bool(reveal.take_pack()).is_true()
	assert_array(_taken).is_equal([other])
	assert_bool(reveal.is_choosing()).is_false()
	assert_bool(reveal.is_folding()).is_true()
	assert_object(reveal.board.picked_pack()).is_same(other)
	reveal.advance(reveal.tuning.outro_s + 0.1)
	assert_bool(reveal.is_open()).is_false()
	assert_array(finished).is_equal([true])
	# With reduced motion the reveal closes at the pick.
	var reduced: CartReveal = CartReveal.new()
	_host.add_child(reduced)
	assert_bool(reduced.play(_choice_run(SEED, true), _cart, true)).is_true()
	reduced.set_process(false)
	assert_bool(reduced.take_pack()).is_true()
	assert_bool(reduced.is_open()).is_false()


## The popups open at once on hover on the board: a pack's card and a ticket of today's deal in the
## cart.
func test_pack_cards_and_todays_products_open_their_popup() -> void:
	var run: RunState = _choice_run(SEED, true)
	var reveal: CartReveal = _reveal(run)
	reveal.freeze_at(reveal.end_time())
	var tile: CartTicket = reveal.board.choice.faces[0].tiles[1]
	assert_object(reveal.target_at(tile.get_global_rect().get_center())).is_same(tile)
	reveal.hover(tile)
	assert_bool(reveal.popup().visible).is_true()
	assert_object(reveal.popup_tile()).is_same(tile)
	var ticket: CartTicket = reveal.board.sheet.deal_tickets[0]
	var target: Control = reveal.target_at(ticket.get_global_rect().get_center())
	assert_object(target).is_same(ticket)
	reveal.hover(target)
	assert_bool(reveal.popup().visible).is_true()
	assert_bool(run.start_offer.shared.has(ticket.card)).is_true()
	reveal.hover(null)
	assert_bool(reveal.popup().visible).is_false()
	# The popups' content, cleared by the next, is freed on the next frame.
	await get_tree().process_frame


## The packs' layout on the board: the faces apart; each face's cards and its line inside it, the
## line on at most three rows and clear of the cards; each card's name on at most two rows.
func test_the_choice_fits_the_panel() -> void:
	var reveal: CartReveal = _reveal(_choice_run(SEED, true))
	reveal.freeze_at(reveal.end_time())
	var faces: Array[PackFace] = reveal.board.choice.faces
	for index: int in faces.size():
		var face: Rect2 = faces[index].get_global_rect()
		var what: String = String(faces[index].pack.id)
		for other: int in range(index + 1, faces.size()):
			assert_bool(face.intersects(faces[other].get_global_rect())).is_false()
		for tile: CartTicket in faces[index].tiles:
			var rect: Rect2 = tile.get_global_rect()
			assert_bool(face.encloses(rect)).override_failure_message(what).is_true()
		for found: Node in faces[index].find_children("*", "Label", false, false):
			var label: Label = found as Label
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				continue
			assert_int(label.get_line_count()).override_failure_message(what).is_less_equal(3)
			var rows: float = label.get_line_count() * label.get_line_height()
			assert_float(rows).override_failure_message(what).is_less_equal(label.size.y + 0.5)
			for tile: CartTicket in faces[index].tiles:
				(
					assert_bool(label.get_global_rect().intersects(tile.get_global_rect()))
					. override_failure_message(what)
					. is_false()
				)
		for tile: CartTicket in faces[index].tiles:
			if tile.name_label() != null:
				var lines: int = tile.name_label().get_line_count()
				assert_int(lines).override_failure_message(tile.name).is_less_equal(2)


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
