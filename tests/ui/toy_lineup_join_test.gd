extends GdUnitTestSuite
## A new figurine joins its lineup card (v1.05, mock-up toy_shelf_unlock.html option B,
## ToyLineupJoin): after the reveal's OK the drawn machine's lineup card is the stage (kept up when
## hovered, dropped in otherwise), the figurine flies from the medallion into its mini, which
## flips into colour, and only then do the FIGURINES LED, the plate and the window count it (held
## from the draw); a tap ends the look. A capsule that completes its aisle turns the band gold
## (ALL COLLECTED) and shows the COMPLETED! card, which waits for OK, then SOLD OUT; the last
## capsule of all opens COLLECTION COMPLETE at the end. The card's rows come from the balance's
## rules. Every piece stays on screen, clear of the others. Saves and logs go to a temporary
## folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_toys_join_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


## Hovered, the lineup stays up behind the reveal; the flight lands on the drawn mini, which
## turns to colour; the counts tick after; NEW! sits under the mini; a tap ends the look.
func test_the_figurine_joins_the_hovered_lineup_card() -> void:
	var profile: ProfileState = Kit.profile(2, 2, {&"bakery": 2})
	var screen: ToyMachinesScreen = await _open(profile)
	var bakery: ToyMachineView = _machine(screen, &"bakery")
	bakery._on_hover(true)
	var lineup: ToyLineup = screen.lineup()
	assert_bool(lineup.visible).is_true()
	bakery._gui_input(Kit.left_click())
	await _frames(2)
	var join: ToyLineupJoin = screen.lineup_join()
	assert_bool(lineup.visible).is_true()  # Kept, behind the reveal's shade.
	assert_int(lineup.z_index).is_equal(0)
	assert_bool(screen.board().visible).is_false()
	var drawn: CardDefinition = _drawn(profile, &"bakery", 2)
	var index: int = Kit.aisle(Kit.balance(), &"bakery").capsule_cards.find(drawn)
	assert_bool(lineup.is_owned(index)).is_false()
	await _dismiss(screen)
	assert_bool(join.is_active()).is_true()
	assert_int(lineup.z_index).is_greater(join.shade().z_index)
	assert_float(lineup.position.y).is_equal(lineup.rest_position().y)  # Not dropped again.
	join.seek(ToyLineupJoin.TO_S * 0.5)
	assert_bool(join.flyer().visible).is_true()
	assert_bool(Kit.SCREEN_RECT.encloses(Kit.rect(join.flyer()))).is_true()
	assert_bool(lineup.is_owned(index)).is_false()
	assert_str(screen.figurines_text()).is_equal("2/30")
	join.seek(ToyLineupJoin.TO_S + ToyLineupJoin.TICK_S)
	assert_bool(join.flyer().visible).is_false()
	assert_bool(lineup.is_owned(index)).is_true()
	assert_str(screen.figurines_text()).is_equal("3/30")
	assert_str(bakery.floor_text()).is_equal("5 OF 8 LEFT")
	assert_int(bakery.capsule_count()).is_equal(5)
	assert_str(str(join.current())).is_equal("look")
	var burst: Rect2 = Kit.rect(join.new_burst())
	assert_bool(join.new_burst().visible).is_true()
	assert_bool(Kit.SCREEN_RECT.encloses(burst)).is_true()
	assert_float(burst.get_center().y).is_greater(Kit.rect(lineup.minis()[index]).get_center().y)
	assert_bool(Kit.SCREEN_RECT.encloses(lineup.strip_rect())).is_true()
	join.tap()  # Ends the look.
	assert_str(str(join.current())).is_equal("away")
	join.seek(10.0)
	assert_bool(join.is_active()).is_false()
	assert_bool(lineup.visible).is_false()
	assert_bool(screen.board().visible).is_true()
	assert_int(lineup.z_index).is_equal(0)
	assert_bool(screen.reveal().visible).is_false()


## Not hovered: the card drops in from above its place.
func test_the_lineup_card_drops_in_when_not_hovered() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	var screen: ToyMachinesScreen = await _open(profile)
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	await _frames(2)
	var lineup: ToyLineup = screen.lineup()
	assert_bool(lineup.visible).is_false()
	await _dismiss(screen)
	assert_bool(lineup.visible).is_true()
	assert_float(lineup.position.y).is_less(lineup.rest_position().y)
	screen.lineup_join().seek(ToyLineupJoin.TO_S)
	assert_float(lineup.position.y).is_equal(lineup.rest_position().y)
	assert_str(lineup.title_line().text()).is_equal("PANTRY LINEUP")


## The capsule that completes Cold cases: the gold band, the COMPLETED! card waiting for OK (not
## before it arms), the plate held at 0 OF 2 LEFT until SOLD OUT.
func test_a_completing_capsule_shows_the_completed_card() -> void:
	var profile: ProfileState = Kit.profile(2, 2, {&"cold_cases": 1})
	var screen: ToyMachinesScreen = await _open(profile)
	var machine: ToyMachineView = _machine(screen, &"cold_cases")
	machine._gui_input(Kit.left_click())
	await _frames(2)
	await _dismiss(screen)
	var join: ToyLineupJoin = screen.lineup_join()
	join.seek(30.0)  # Held at the card.
	assert_bool(join.is_waiting()).is_true()
	assert_bool(screen.lineup().is_collected()).is_true()
	assert_str(screen.lineup().title_line().text()).is_equal("ALL COLLECTED")
	assert_str(machine.floor_text()).is_equal("0 OF 2 LEFT")
	assert_bool(machine.part("sold_out").visible).is_false()
	assert_bool(screen.lineup().visible).is_true()
	assert_bool(screen.board().visible).is_false()
	var card: ToyCompletedCard = join.completed_card()
	assert_bool(card.visible).is_true()
	join.tap()  # Not armed yet: nothing.
	assert_bool(join.is_waiting()).is_true()
	await _assert_card_on_screen(card)
	assert_int(card.rows().size()).is_equal(1)
	var aisles: Array[AisleDefinition] = Kit.balance().aisles
	assert_int(card.pips().size()).is_equal(aisles.size())
	var at: int = aisles.find(Kit.aisle(Kit.balance(), &"cold_cases"))
	assert_object(card.new_pip()).is_same(card.pips()[at])
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	assert_bool(card.is_armed()).is_true()
	join.tap()
	assert_bool(join.is_waiting()).is_false()
	join.seek(join.time() + ToyLineupJoin.CARD_OUT_S + 0.01)
	assert_str(str(join.current())).is_equal("sold")
	assert_int(machine.state()).is_equal(CapsuleCounter.State.EMPTY)
	assert_str(machine.floor_text()).is_equal("SOLD OUT")
	assert_bool(screen.board().visible).is_true()  # The card has left: the board is back.
	assert_bool(screen.lineup().visible).is_false()
	join.seek(30.0)
	assert_bool(join.is_active()).is_false()
	assert_bool(machine.part("sold_out").visible).is_true()
	assert_float(machine.part("sold_out").rotation).is_equal(0.0)


## The last capsule of all: COLLECTION COMPLETE waits for the end.
func test_the_last_capsule_opens_collection_complete_at_the_end() -> void:
	var counts: Dictionary = Kit.full_counts()
	counts[&"pantry"] = int(counts[&"pantry"]) - 1
	var profile: ProfileState = Kit.profile(2, 2, counts)
	var screen: ToyMachinesScreen = await _open(profile)
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	await _frames(2)
	assert_int(screen.strip_kind()).is_not_equal(ToyMachinesScreen.Strip.COMPLETE)
	await _dismiss(screen)
	var join: ToyLineupJoin = screen.lineup_join()
	join.seek(30.0)
	assert_int(screen.strip_kind()).is_not_equal(ToyMachinesScreen.Strip.COMPLETE)
	var card: ToyCompletedCard = join.completed_card()
	assert_int(card.rows().size()).is_equal(2)  # The last swap choices and CHOOSE YOUR AISLES.
	await _assert_card_on_screen(card)
	join.finish()
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.COMPLETE)
	assert_str(screen.figurines_text()).is_equal("30/30")


## Reduced motion: no flight, no drop; the mini is in colour from the start.
func test_reduced_motion_fades_in_place() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	profile.set_reduced_motion(true)
	var screen: ToyMachinesScreen = await _open(profile)
	_machine(screen, &"snacks")._gui_input(Kit.left_click())
	await _frames(2)
	await _dismiss(screen)
	var join: ToyLineupJoin = screen.lineup_join()
	var lineup: ToyLineup = screen.lineup()
	assert_bool(join.flyer().visible).is_false()
	assert_float(lineup.position.y).is_equal(lineup.rest_position().y)
	var drawn: CardDefinition = _drawn(profile, &"snacks", 0)
	var index: int = Kit.aisle(Kit.balance(), &"snacks").capsule_cards.find(drawn)
	assert_bool(lineup.is_owned(index)).is_true()
	assert_bool(screen.reveal().visible).is_false()
	join.finish()
	assert_bool(join.is_active()).is_false()


## The card's rows: every number from the balance; a threshold of 0 is off.
func test_the_completed_card_lines_follow_the_rules() -> void:
	var balance: BalanceDefinition = Kit.balance()
	var aisle: AisleDefinition = Kit.aisle(balance, &"bakery")
	var one: Array[Dictionary] = ToyCompletedCard.lines(balance, 1, aisle, 4)
	assert_int(one.size()).is_equal(1)
	assert_str(str(one[0]["title"])).is_equal(ToyCompletedCard.SWAP_TITLE)
	var cap: String = ToyCompletedCard.SWAP_TEXT % [1, 4, "Bakery", balance.staple_swap_aisle_max]
	assert_str(str(one[0]["text"])).is_equal(cap)
	var at_restock: int = balance.restock_min_completed
	var restock: Array[Dictionary] = ToyCompletedCard.lines(balance, at_restock, aisle, 4)
	assert_str(str(restock[-1]["title"])).is_equal(ToyCompletedCard.RESTOCK_TITLE)
	var five: Array[Dictionary] = ToyCompletedCard.lines(balance, 5, aisle, 4)
	assert_str(str(five[0]["title"])).is_equal(ToyCompletedCard.CHOICES_TITLE)
	var at_pair: int = balance.pair_choice_min_completed
	var pair: Array[Dictionary] = ToyCompletedCard.lines(balance, at_pair, aisle, 4)
	assert_str(str(pair[-1]["title"])).is_equal(ToyCompletedCard.AISLES_TITLE)
	var next: String = ToyCompletedCard.NEXT_TEXT % [at_restock, ToyCompletedCard.RESTOCK_NAME]
	assert_str(ToyCompletedCard.next_line(balance, 1)).is_equal(next)
	assert_str(ToyCompletedCard.next_line(balance, balance.aisles.size())).is_equal(
		ToyCompletedCard.ALL_TEXT
	)
	var off: BalanceDefinition = balance.duplicate() as BalanceDefinition
	off.restock_min_completed = 0
	for row: Dictionary in ToyCompletedCard.lines(off, at_restock, aisle, 4):
		assert_str(str(row["title"])).is_not_equal(ToyCompletedCard.RESTOCK_TITLE)


## The card inside the screen; its band, heading, rows, pips and OK clear of each other.
func _assert_card_on_screen(card: ToyCompletedCard) -> void:
	await _frames(2)
	var frame: Rect2 = Kit.rect(card.frame())
	assert_bool(Kit.SCREEN_RECT.encloses(frame)).override_failure_message(str(frame)).is_true()
	var pieces: Array[Control] = []
	pieces.append_array(card.rows())
	pieces.append(card.pips()[0].get_parent() as Control)
	pieces.append(card.ok_button())
	for index: int in pieces.size():
		var rect: Rect2 = Kit.rect(pieces[index])
		assert_bool(frame.encloses(rect)).override_failure_message(str(rect)).is_true()
		for other: int in range(index + 1, pieces.size()):
			assert_bool(rect.intersects(Kit.rect(pieces[other]))).is_false()
	var pips: Array[Control] = card.pips()
	for index: int in range(1, pips.size()):
		assert_bool(Kit.rect(pips[index]).intersects(Kit.rect(pips[index - 1]))).is_false()


func _dismiss(screen: ToyMachinesScreen) -> void:
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	screen.reveal().dismiss()


## The capsule item of `aisle_id` drawn after its first `owned` items.
func _drawn(profile: ProfileState, aisle_id: StringName, owned: int) -> CardDefinition:
	var cards: Array[CardDefinition] = Kit.aisle(Kit.balance(), aisle_id).capsule_cards
	for card: CardDefinition in cards.slice(owned):
		if profile.unlocked_items.has(card.id):
			return card
	return null


func _machine(screen: ToyMachinesScreen, id: StringName) -> ToyMachineView:
	for machine: ToyMachineView in screen.machines():
		if machine.aisle().id == id:
			return machine
	return null


func _open(profile: ProfileState) -> ToyMachinesScreen:
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, true
	)
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, Kit.balance())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
