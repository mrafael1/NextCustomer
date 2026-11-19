extends GdUnitTestSuite
## The guided first run's scripted deal (the tutorial, WP-1: GuidedStartDefinition,
## StartSetupRules.deal_fixed, StartChoice's guided branch): the fixed boosters (Dairy and
## Pantry, no hit) and the 4 regulars; a deal StartSetup's load check keeps, so a
## resume keeps it; shift 1's hand is the definition's 8 in place order;
## a guided run wears no pin and a restart keeps it guided; a normal run is dealt exactly as
## before. The live data; the screen suites save into a temp folder.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261114
const REGULARS: Array[StringName] = [&"banana", &"banana", &"milk", &"eggs"]
const AISLES: Array[StringName] = [&"dairy", &"pantry"]
## Shift 1's hand by place: basket 1 Bananas, basket 2 Milk and Eggs, basket 3 Yogurt and
## Cereal, basket 4 Tea bags and Cheese (the regulars, then 4 booster cards).
const HAND: Array[StringName] = [
	&"banana", &"banana", &"milk", &"eggs", &"yogurt", &"cereal", &"tea_bags", &"cheese"
]

var _balance: BalanceDefinition
var _guide: GuidedStartDefinition
var _folder: String = ""


func before_test() -> void:
	_balance = Kit.balance()
	_guide = StartChoice.guided_start()


func after_test() -> void:
	if _folder.is_empty():
		return
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)
	_folder = ""


## The shipped definition deals on the live balance: its recipe (a recipe, 4 regulars), its
## boosters, and a hand of hand_size cards all in the cart.
func test_the_definition_deals_on_the_live_balance() -> void:
	assert_str(String(_guide.block(_balance))).is_empty()
	var recipe: DeckDefinition = _guide.recipe
	assert_object(recipe).is_same(load("res://data/decks/guided_starter.tres"))
	assert_bool(recipe.is_recipe()).is_true()
	assert_array(_ids(recipe.core_cards)).is_equal(REGULARS)
	assert_bool(recipe.opening_time).is_true()
	assert_array(_guide.aisle_ids()).is_equal(AISLES)
	# Owned cards only, start_booster_size each (v1.41).
	assert_array(_ids(_guide.booster_cards(&"dairy"))).is_equal(
		[&"cheese", &"butter", &"yogurt", &"reduced_yogurt"]
	)
	assert_array(_ids(_guide.booster_cards(&"pantry"))).is_equal(
		[&"cereal", &"tea_bags", &"crackers", &"dented_can"]
	)
	assert_array(_guide.booster_cards(&"fruit_and_veg")).is_empty()
	assert_array(_ids(_guide.hand)).is_equal(HAND)
	# 4 regulars and 2 boosters stay within the cart's limit.
	var cart: int = recipe.core_cards.size() + 2 * _balance.start_booster_size
	assert_int(cart).is_less_equal(_balance.deck_limit)


## Each broken definition is refused with its reason, and deal_fixed then changes nothing.
func test_a_broken_definition_is_refused() -> void:
	var broken: GuidedStartDefinition = _copy()
	broken.recipe = null
	assert_str(String(broken.block(_balance))).is_equal("recipe")
	broken = _copy()
	broken.boosters = broken.boosters.slice(0, 1)
	assert_str(String(broken.block(_balance))).is_equal("boosters")
	broken = _copy()
	broken.boosters[1] = _spec(broken.boosters[0].aisle, broken.boosters[1].cards)
	assert_str(String(broken.block(_balance))).is_equal("boosters")
	broken = _copy()
	broken.boosters[1] = _spec(broken.boosters[1].aisle, broken.boosters[0].cards)
	assert_str(String(broken.block(_balance))).is_equal("cards")
	broken = _copy()
	var twice: Array[CardDefinition] = [_card(&"cheese"), _card(&"cheese")]
	broken.boosters[0] = _spec(broken.boosters[0].aisle, twice)
	assert_str(String(broken.block(_balance))).is_equal("cards")
	broken = _copy()
	var rare: Array[CardDefinition] = [_card(&"cheese_big")]
	broken.boosters[0] = _spec(broken.boosters[0].aisle, rare)
	assert_str(String(broken.block(_balance))).is_equal("cards")
	broken = _copy()
	broken.hand = broken.hand.slice(0, 7)
	assert_str(String(broken.block(_balance))).is_equal("hand")
	broken = _copy()
	broken.hand[7] = _card(&"bread")
	assert_str(String(broken.block(_balance))).is_equal("hand")
	var run: RunState = _setup(ProfileState.new())
	var untouched: Dictionary = run.start_setup.to_dictionary()
	assert_str(String(StartSetupRules.deal_fixed(run, ProfileState.new(), broken))).is_equal("hand")
	assert_dict(run.start_setup.to_dictionary()).is_equal(untouched)


## deal_fixed: the fixed boosters on their aisles (stocked, data order), sealed, no hit; DEALT;
## the same for a veteran with every aisle complete. Dealt once, it refuses again.
func test_deal_fixed_deals_the_boosters() -> void:
	for profile: ProfileState in [ProfileState.new(), Kit.profile(6)]:
		var run: RunState = _dealt(profile)
		var setup: StartSetup = run.start_setup
		assert_int(setup.stage).is_equal(StartSetup.Stage.DEALT)
		assert_array(setup.stock_aisles).is_equal(AISLES)
		assert_array(run.stock.aisle_ids).is_equal(AISLES)
		assert_int(setup.boosters.size()).is_equal(2)
		for booster: StartBooster in setup.boosters:
			assert_array(booster.cards).is_equal(_guide.booster_cards(booster.aisle))
			assert_int(booster.hits).is_equal(0)
			assert_int(booster.rare_count()).is_equal(0)
			assert_bool(booster.opened or booster.restocked).is_false()
		assert_array(run.start_offer.shared).is_equal(setup.shared())
		assert_int(run.deck.cards.size()).is_equal(12)
		assert_str(String(StartSetupRules.deal_fixed(run, profile, _guide))).is_equal("stage")


## A resume keeps the guided deal: sealed, then opened on page 2; StartSetup's load
## check accepts it and the run stays guided.
func test_a_resume_keeps_the_guided_deal() -> void:
	var profile: ProfileState = ProfileState.new()
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = _dealt(profile)
	run.guided = true
	var sealed: RunSave = _round_trip(run, lookup)
	assert_object(sealed).is_not_null()
	assert_object(sealed.run.start_setup).is_not_null()
	assert_bool(sealed.run.restart_setup).is_false()
	assert_bool(sealed.run.guided).is_true()
	assert_dict(sealed.run.start_setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	assert_str(String(sealed.run.starter.id)).is_equal("guided_starter")
	assert_array(sealed.run.starter.core_cards).is_equal(run.starter.core_cards)
	Kit.open_all(run)
	assert_bool(StartSetupRules.mark_build(run)).is_true()
	var picked: RunSave = _round_trip(run, lookup)
	assert_object(picked).is_not_null()
	assert_object(picked.run.start_setup).is_not_null()
	assert_dict(picked.run.start_setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	assert_array(picked.run.start_offer.shared).is_equal(run.start_offer.shared)


## OPEN STORE: the cart holds the regulars and both boosters (12, under the deck limit)
## and shift 1's hand is the definition's 8 in place order, the two Bananas distinct copies; the run
## saves and resumes it.
func test_the_hand_is_the_eight_in_place_order() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = _dealt(ProfileState.new())
	run.guided = true
	Kit.open_all(run)
	assert_bool(run.open_store()).is_true()
	var cart: int = _guide.recipe.core_cards.size()
	for aisle: StringName in _guide.aisle_ids():
		cart += _guide.booster_cards(aisle).size()
	assert_int(run.deck.cards.size()).is_equal(cart)
	run.kept = _guide.hand_ids(run.deck.cards)
	assert_int(run.kept.size()).is_equal(HAND.size())
	run.start_shift()
	var places: Array[CardInstance] = run.hand_places()
	assert_array(_instance_ids(places)).is_equal(HAND)
	assert_int(places[0].instance_id).is_not_equal(places[1].instance_id)
	assert_int(run.kept.size()).is_equal(0)
	var saved: RunSave = _round_trip(run, lookup)
	assert_object(saved).is_not_null()
	assert_array(_instance_ids(saved.run.hand_places())).is_equal(HAND)
	# A deck missing a hand card gives no fixed hand (the shift deals as usual).
	var short: Array[CardInstance] = []
	assert_int(_guide.hand_ids(short).size()).is_equal(0)


## StartChoice: the guided recipe gives the guided run with its fixed deal and no pin, even for a
## profile wearing one; OPEN STORE deals the fixed hand; a restart keeps the run guided; OPEN
## STORE isn't held for the BADGE PINS step.
func test_start_choice_deals_the_guided_run() -> void:
	var screen: ShiftScreen = await _screen()
	var pin: PinDefinition = screen._catalogue.pins[0]
	screen.profile.unlocked_pins.append(pin.id)
	screen.profile.worn_pins.append(pin.id)
	var choice: StartChoice = screen._start_choice
	var run: RunState = choice.new_run(SEED, screen._balance, _guide.recipe)
	assert_bool(run.guided).is_true()
	assert_array(run.pins).is_empty()
	assert_array(run.start_setup.stock_aisles).is_equal(AISLES)
	assert_array(_ids(run.start_setup.shared())).is_equal(
		_ids(_dealt(screen.profile).start_setup.shared())
	)
	screen.run = run
	assert_int(choice._pins_gate()).is_equal(0)
	run.restart_setup = true
	choice._restart_setup()
	var restarted: RunState = screen.run
	assert_object(restarted).is_not_same(run)
	assert_bool(restarted.guided).is_true()
	assert_array(restarted.pins).is_empty()
	assert_dict(restarted.start_setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	Kit.open_all(restarted)
	choice._open(false)
	assert_int(restarted.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(_instance_ids(restarted.hand_places())).is_equal(HAND)
	# The shift's receipt scrolls a frame later: let it settle before the screen is freed.
	await _frames(3)


## A normal run (the pack starter recipe) is dealt exactly as StartSetupRules and StartChoice.deal
## deal it without the guided branch: the same save, not guided; its restart stays normal.
func test_a_normal_run_is_dealt_as_before() -> void:
	var screen: ShiftScreen = await _screen()
	var recipe: DeckDefinition = load(ShiftScreen.STARTER_DECK)
	var made: RunState = screen._start_choice.new_run(SEED, screen._balance, recipe)
	assert_bool(made.guided).is_false()
	var expected: RunState = StartSetupRules.setup_run(
		SEED,
		screen._balance,
		recipe,
		screen.profile,
		EventLogService.derived_stream(SEED, EventLogService.STOCK_AISLES_STREAM)
	)
	assert_str(String(StartChoice.deal(expected, screen.profile))).is_empty()
	RunPins.wear(expected, ProfilePins.worn(screen.profile, screen._catalogue))
	assert_dict(RunSave.to_dictionary(made, "run", 0)).is_equal(
		RunSave.to_dictionary(expected, "run", 0)
	)
	screen.run = made
	screen._start_choice._restart_setup()
	assert_bool(screen.run.guided).is_false()
	assert_dict(RunSave.to_dictionary(screen.run, "run", 0)).is_equal(
		RunSave.to_dictionary(expected, "run", 0)
	)


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


func _screen() -> ShiftScreen:
	_folder = "user://guided_deal_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	return screen


## A new guided-recipe run in SELECT, as StartChoice sets it up.
func _setup(profile: ProfileState) -> RunState:
	return StartSetupRules.setup_run(
		SEED,
		_balance,
		_guide.recipe,
		profile,
		EventLogService.derived_stream(SEED, EventLogService.STOCK_AISLES_STREAM)
	)


func _dealt(profile: ProfileState) -> RunState:
	var run: RunState = _setup(profile)
	assert_str(String(StartSetupRules.deal_fixed(run, profile, _guide))).is_empty()
	return run


func _copy() -> GuidedStartDefinition:
	var copy: GuidedStartDefinition = GuidedStartDefinition.new()
	copy.recipe = _guide.recipe
	copy.boosters = _guide.boosters.duplicate()
	copy.hand = _guide.hand.duplicate()
	return copy


static func _spec(aisle: AisleDefinition, cards: Array[CardDefinition]) -> GuidedBoosterSpec:
	var spec: GuidedBoosterSpec = GuidedBoosterSpec.new()
	spec.aisle = aisle
	spec.cards = cards.duplicate()
	return spec


static func _card(id: StringName) -> CardDefinition:
	return load("res://data/cards/%s.tres" % id)


static func _ids(cards: Array[CardDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardDefinition in cards:
		ids.append(card.id)
	return ids


static func _instance_ids(cards: Array[CardInstance]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardInstance in cards:
		ids.append(card.definition.id if card != null else &"")
	return ids


static func _round_trip(run: RunState, lookup: ContentLookup) -> RunSave:
	return RunSave.from_dictionary(Kit.json(RunSave.to_dictionary(run, "run", 0)), lookup)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
