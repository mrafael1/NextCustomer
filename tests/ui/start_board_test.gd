extends GdUnitTestSuite
## The start screen's clock-in board (#107's choice, mock-up start_screen.html layout A,
## 2026-11-03): the layout on screen at 1280x720 and 1920x1080 (every part inside the board, apart),
## a pick and a hover updating the cart preview, the preview being exactly the deck the run starts
## with, the worn pins, and TODAY'S STOCK's pools (a new profile's, and one with a machine-opened
## aisle listed). The board is driven by its API: headless runs deliver no input events.

const SCREEN := "res://ui/shift_screen.tscn"
const RECIPE := "res://data/decks/pack_starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const SEEDS: Array[int] = [20261103, 20261014, 99, 7]
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
const REPACK := "res://data/pins/repack.tres"

var _host: Control
var _cart: Control
var _folder: String = ""


func before_test() -> void:
	_host = auto_free(Control.new())
	_host.size = ShiftStage.SIZE
	add_child(_host)
	_cart = Control.new()
	_cart.position = Vector2(1078, 10)
	_cart.size = Vector2(128, 36)
	_host.add_child(_cart)
	_folder = "user://test_board_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## On screen at 1280x720 and 1920x1080, for several deals and every pack shown: the board inside
## the stage under the top bar (its header plate above it, clear of the Cart button), and its
## parts inside it and apart: the packs, the cart sheet (every ticket inside it, none touching
## another, BY FAMILY clear of the deal), the stock's rows and footer, the pins and the key.
func test_the_board_fits_the_screen_with_no_overlaps() -> void:
	for window_size: Vector2 in WINDOWS:
		_host.size = window_size
		for seed_value: int in SEEDS:
			var reveal: CartReveal = _reveal(_choice_run(seed_value, true, []))
			reveal.freeze_at(reveal.end_time())
			await get_tree().process_frame
			var board: StartBoard = reveal.board
			for shown: int in range(-1, board.choice.faces.size()):
				board.pick(shown)
				await get_tree().process_frame
				_assert_layout(board, "%s seed %d pack %d" % [window_size, seed_value, shown])
			reveal.close()


func _assert_layout(board: StartBoard, what: String) -> void:
	var box: Rect2 = board.get_global_rect()
	var stage: Rect2 = Rect2(box.position - StartBoard.RECT.position, ShiftStage.SIZE)
	assert_bool(stage.encloses(box)).override_failure_message(what).is_true()
	var header: Rect2 = Rect2(
		stage.position + StartBoard.HEADER_RECT.position, StartBoard.HEADER_RECT.size
	)
	assert_float(header.end.y).override_failure_message(what).is_less_equal(
		stage.position.y + ShiftStage.TOP_BAR_BOTTOM
	)
	assert_float(header.end.x).is_less(_cart.get_global_rect().position.x)
	var parts: Array[Rect2] = [
		board.sheet.get_global_rect(),
		_rect_of(board.shelves, board.shelves.footer()),
		board.pins.get_global_rect(),
		board.find_child("OpenStoreKey", true, false).get_global_rect(),
	]
	for face: PackFace in board.choice.faces:
		parts.append(face.get_global_rect())
	for index: int in parts.size():
		var message: String = "%s part %d %s in %s" % [what, index, parts[index], box]
		assert_bool(box.encloses(parts[index])).override_failure_message(message).is_true()
		for other: int in range(index + 1, parts.size()):
			(
				assert_bool(parts[index].intersects(parts[other]))
				. override_failure_message("%s: parts %d and %d" % [what, index, other])
				. is_false()
			)
	var sheet: Rect2 = board.sheet.get_global_rect()
	var tickets: Array[CartTicket] = board.sheet.tickets()
	var tally: Rect2 = Rect2(
		sheet.position + CartSheet.TALLY_RECT.position, CartSheet.TALLY_RECT.size
	)
	for index: int in tickets.size():
		var rect: Rect2 = tickets[index].get_global_rect()
		var message: String = "%s ticket %s" % [what, tickets[index].name]
		assert_bool(sheet.encloses(rect)).override_failure_message(message).is_true()
		assert_bool(rect.intersects(tally)).override_failure_message(message).is_false()
		for other: int in range(index + 1, tickets.size()):
			var apart: bool = not rect.intersects(tickets[other].get_global_rect())
			assert_bool(apart).override_failure_message(message).is_true()
	for label: Label in board.pins.name_labels() + board.pins.rule_labels() + [board.pins.foot()]:
		var rect: Rect2 = Rect2(label.global_position, label.get_minimum_size() * label.scale)
		var message: String = "%s pin text %s" % [what, label.text]
		assert_bool(box.encloses(rect)).override_failure_message(message).is_true()


## The shelves' rect down to its footer's last line.
func _rect_of(shelves: StockShelves, footer: Label) -> Rect2:
	var rect: Rect2 = shelves.get_global_rect()
	var bottom: float = (
		footer.global_position.y + footer.get_line_count() * footer.get_line_height()
	)
	rect.size.y = bottom - rect.position.y
	return rect


## A pick shows its pack in the cart (and names it on the key); hovering another pack previews it
## without changing the pick; leaving it shows the pick again. The preview is StartingDeck.cart.
func test_a_pick_and_a_hover_update_the_cart_preview() -> void:
	var run: RunState = _choice_run(SEEDS[0], false, [])
	var reveal: CartReveal = _reveal(run)
	reveal.freeze_at(reveal.end_time())
	var board: StartBoard = reveal.board
	assert_object(board.sheet.pack).is_null()
	assert_str(board.key_text()).is_equal(StartBoard.KEY_IDLE_TEXT)
	assert_int(board.sheet.pack_tickets.size()).is_equal(3)
	assert_bool(board.sheet.pack_tickets[0].is_empty()).is_true()
	var packs: Array[StarterPackDefinition] = run.start_offer.packs
	reveal.raise_pack(0)
	assert_object(board.sheet.pack).is_same(packs[0])
	assert_bool(board.sheet.previewing).is_false()
	assert_str(board.key_text()).is_equal(StartBoard.KEY_OPEN_TEXT)
	assert_str(board.key_sub_text()).contains(packs[0].display_name)
	assert_array(board.preview_cards()).is_equal(
		StartingDeck.cart(run.starter, packs[0], run.start_offer.shared, run.pins)
	)
	assert_str(board.sheet.equation_text()).contains(packs[0].display_name)
	assert_str(board.sheet.total_text()).is_equal("13/%d" % run.balance.deck_limit)
	board.set_pointer(board.choice.faces[2].get_global_rect().get_center())
	assert_object(board.sheet.pack).is_same(packs[2])
	assert_bool(board.sheet.previewing).is_true()
	assert_object(board.picked_pack()).is_same(packs[0])
	assert_str(board.key_sub_text()).contains(packs[0].display_name)
	assert_array(board.preview_cards()).is_equal(
		StartingDeck.cart(run.starter, packs[2], run.start_offer.shared, run.pins)
	)
	board.set_pointer(Vector2(-100, -100))
	assert_object(board.sheet.pack).is_same(packs[0])
	assert_bool(board.sheet.previewing).is_false()


## The cart's tickets group identical cards: one ticket per card per bracket, its ×N the card's
## copies over the whole cart; their names, prices and the deal's count read as the cart.
func test_the_cart_groups_identical_cards_with_their_count() -> void:
	var run: RunState = _choice_run(SEEDS[1], true, [])
	var reveal: CartReveal = _reveal(run)
	var sheet: CartSheet = reveal.board.sheet
	var cart: Array[CardDefinition] = sheet.cart_cards()
	assert_int(cart.size()).is_equal(13)
	for ticket: CartTicket in sheet.tickets():
		if ticket.is_empty():
			continue
		assert_int(ticket.count).is_equal(cart.count(ticket.card))
		assert_bool(ticket.count_badge.visible).is_equal(ticket.count > 1)
		if ticket.card.is_product():
			assert_str(ticket.price_label().text).is_equal(
				PriceSticker.price_text(ticket.card.base)
			)
	var deal_cards: Array[CardDefinition] = []
	for ticket: CartTicket in sheet.deal_tickets:
		assert_bool(deal_cards.has(ticket.card)).is_false()
		deal_cards.append(ticket.card)
	for card: CardDefinition in run.start_offer.shared:
		assert_bool(deal_cards.has(card)).is_true()
	for ticket: CartTicket in sheet.staple_tickets:
		assert_object(ticket.lock_badge).is_not_null()


## On the real screen: the confirm starts the run with exactly the cart the board showed for the
## picked pack (the same cards, whatever their order in the shuffled deck), and the run's offer
## and today's products are the ones the board showed before the pick.
func test_confirm_starts_the_run_with_exactly_the_previewed_deck() -> void:
	var screen: ShiftScreen = await _screen()
	for pick: int in range(3):
		screen.start_new_run(SEEDS[pick], true, true)
		var reveal: CartReveal = screen._cart_reveal
		assert_bool(reveal.is_choosing()).is_true()
		reveal.freeze_at(reveal.end_time())
		var shown_shared: Array[CardDefinition] = reveal.board.sheet.shared.duplicate()
		reveal.raise_pack(pick)
		var preview: Array[CardDefinition] = reveal.board.preview_cards()
		var pack: StarterPackDefinition = reveal.board.picked_pack()
		assert_bool(reveal.take_pack()).is_true()
		var run: RunState = screen.run
		assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
		assert_object(run.starter.starter_pack).is_same(pack)
		assert_array(StartingDeck.shared_of(run.starter)).is_equal(shown_shared)
		var dealt: Array[String] = []
		for card: CardInstance in run.deck.cards:
			dealt.append(String(card.definition.id))
		var shown: Array[String] = []
		for card: CardDefinition in preview:
			shown.append(String(card.id))
		dealt.sort()
		shown.sort()
		assert_array(dealt).is_equal(shown)
		# The board folds into the Cart button, then closes.
		assert_bool(reveal.is_folding()).is_true()
		reveal.advance(reveal.tuning.outro_s + 0.1)
		assert_bool(reveal.is_open()).is_false()


## The same seed and choice give the same deck as the preview with a pin that brings cards: its
## cards are in the preview (FROM YOUR PINS) and in the deck the pick deals.
func test_a_pins_cards_are_in_the_preview_and_the_deck() -> void:
	var pin: PinDefinition = PinDefinition.new()
	pin.id = &"test_pin"
	pin.display_name = "Test pin"
	pin.rule_text = "Brings two cards."
	var milk: CardDefinition = load("res://data/cards/milk.tres")
	pin.starting_cards = [milk, milk]
	var run: RunState = _choice_run(SEEDS[2], true, [pin])
	var reveal: CartReveal = _reveal(run)
	var board: StartBoard = reveal.board
	assert_int(board.sheet.pin_tickets.size()).is_equal(1)
	assert_str(board.sheet.equation_text()).contains("+ 2 from your pins")
	var preview: Array[CardDefinition] = board.preview_cards()
	assert_bool(run.take_pack(board.picked_pack())).is_true()
	var dealt: Array[CardDefinition] = []
	for card: CardInstance in run.deck.cards:
		dealt.append(card.definition)
	assert_int(dealt.size()).is_equal(preview.size())
	for card: CardDefinition in preview:
		assert_int(dealt.count(card)).is_equal(preview.count(card))


## BADGE PINS: a worn pin's name and rule beside the badge, its face on the badge; with none worn,
## "No pin worn" and the free slot; the foot points to REWARDS.
func test_the_worn_pins_are_shown() -> void:
	var repack: PinDefinition = load(REPACK)
	var worn: CartReveal = _reveal(_choice_run(SEEDS[0], true, [repack]))
	var pins: BoardPins = worn.board.pins
	assert_str(pins.name_labels()[0].text).is_equal(repack.display_name)
	assert_str(pins.rule_labels()[0].text).is_equal(repack.rule_text)
	assert_bool(pins.badge.slot_faces()[0].is_empty()).is_false()
	assert_str(pins.foot().text).is_equal(BoardPins.FOOT_TEXT)
	worn.close()
	var bare: CartReveal = _reveal(_choice_run(SEEDS[0], true, []))
	var none: BoardPins = bare.board.pins
	assert_str(none.name_labels()[0].text).is_equal(BoardPins.NONE_TEXT)
	assert_str(none.rule_labels()[0].text).starts_with("1 slot free")
	assert_bool(none.badge.slot_faces()[0].is_empty()).is_true()


## TODAY'S STOCK on a new profile: the staples and the three base aisles are dealt from, the
## machine-opened aisles locked, and the footer counts the deal's pool. Hovering a shelf names how
## many of today's deal came from it and lights those tickets (the others dim).
func test_a_new_profiles_pools_are_shown() -> void:
	var run: RunState = _choice_run(SEEDS[0], true, [])
	var reveal: CartReveal = _reveal(run)
	var shelves: StockShelves = reveal.board.shelves
	var pool: Array[CardDefinition] = StartingDeck.deal_pool(run.starter, run.stock, run.balance)
	assert_int(shelves.pool_size).is_equal(pool.size())
	assert_str(shelves.footer().text).contains("%d products" % pool.size())
	assert_int(shelves.state_of(StockShelves.STAPLES_ID)).is_equal(StockShelves.State.DEALT_FROM)
	for aisle: AisleDefinition in run.balance.aisles:
		var expected: StockShelves.State = StockShelves.State.LOCKED
		if not aisle.base_cards.is_empty():
			expected = StockShelves.State.DEALT_FROM
		assert_int(shelves.state_of(aisle.id)).override_failure_message(aisle.id).is_equal(expected)
	var counted: int = 0
	for index: int in shelves.shelf_ids.size():
		counted += shelves.dealt_from(shelves.shelf_ids[index]).size()
	assert_int(counted).is_equal(run.start_offer.shared.size())
	var staples_row: int = shelves.shelf_ids.find(StockShelves.STAPLES_ID)
	var row: Rect2 = shelves.row_rect(staples_row)
	reveal.board.set_pointer(shelves.get_global_transform() * row.get_center())
	var from_staples: Array[CardDefinition] = shelves.dealt_from(StockShelves.STAPLES_ID)
	assert_str(shelves.sub_text()).is_equal(
		StockShelves.HOVER_TEXT % ["Staples", from_staples.size(), run.start_offer.shared.size()]
	)
	for ticket: CartTicket in reveal.board.sheet.deal_tickets:
		assert_bool(ticket.lit).is_equal(from_staples.has(ticket.card))
		assert_bool(ticket.dimmed).is_equal(not from_staples.has(ticket.card))
	reveal.board.set_pointer(Vector2(-100, -100))
	assert_str(shelves.sub_text()).is_equal(StockShelves.SUB_TEXT % run.start_offer.shared.size())


## A profile with a machine-opened aisle listed: that aisle is stocked for the machine's prizes
## only (PRIZES ONLY: a recipe without random_capsules never deals its capsule items), the
## listable aisles left off the list are NOT LISTED, and the pool shrinks to the dealt shelves.
func test_a_listed_machine_aisle_is_prizes_only() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var unlocked: Dictionary[StringName, int] = {}
	var opened: AisleDefinition = null
	for aisle: AisleDefinition in balance.aisles:
		if aisle.base_cards.is_empty() and opened == null:
			opened = aisle
			for card: CardDefinition in aisle.capsule_cards:
				unlocked[card.id] = 0
	var listed: Array[StringName] = [opened.id]
	var base_listed: AisleDefinition = null
	for aisle: AisleDefinition in balance.aisles:
		if not aisle.base_cards.is_empty() and base_listed == null:
			base_listed = aisle
			listed.append(aisle.id)
	var stock: RunStock = RunStock.build(balance, listed, unlocked, 1)
	var run: RunState = _run_on(stock, SEEDS[2], [])
	var reveal: CartReveal = CartReveal.new()
	_host.add_child(reveal)
	assert_bool(reveal.play(run, _cart, false, unlocked)).is_true()
	reveal.set_process(false)
	var shelves: StockShelves = reveal.board.shelves
	if not stock.list_skipped:
		assert_int(shelves.state_of(opened.id)).is_equal(StockShelves.State.PRIZES_ONLY)
		assert_int(shelves.state_of(base_listed.id)).is_equal(StockShelves.State.DEALT_FROM)
		for aisle: AisleDefinition in balance.aisles:
			if not stock.aisle_ids.has(aisle.id) and not aisle.base_cards.is_empty():
				assert_int(shelves.state_of(aisle.id)).is_equal(StockShelves.State.NOT_LISTED)
	var pool: Array[CardDefinition] = StartingDeck.deal_pool(run.starter, stock, balance)
	assert_int(shelves.pool_size).is_equal(pool.size())
	for card: CardDefinition in opened.capsule_cards:
		assert_bool(pool.has(card)).is_false()


func _choice_run(seed_value: int, first_pick: bool, pins: Array[PinDefinition]) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	return _run_on(RunStock.starting(balance), seed_value, pins, first_pick)


func _run_on(
	stock: RunStock, seed_value: int, pins: Array[PinDefinition], first_pick: bool = true
) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var recipe: DeckDefinition = load(RECIPE)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.STARTING_DECK_STREAM
	)
	var offer: StartOffer = StartingDeck.deal_offer(recipe, stock, balance, stream, first_pick)
	var deck: DeckDefinition = StartingDeck.before_pick(recipe, offer)
	var run: RunState = RunState.new(seed_value, deck, balance, stock, offer)
	RunPins.wear(run, pins)
	return run


func _reveal(run: RunState) -> CartReveal:
	var reveal: CartReveal = CartReveal.new()
	_host.add_child(reveal)
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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
