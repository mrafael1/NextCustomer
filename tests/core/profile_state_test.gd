extends GdUnitTestSuite
## The profile (full build plan sections 4 and 7.3): recording an ended run (run count, coupon
## uses, deck and variant unlocks) and the saved form. Uses the live starter deck and balance
## with every quota at 5, and builds conditions, decks and variants in code.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"
const FINAL_MARKDOWN := "res://data/cards/final_markdown.tres"
const BANANA := "res://data/cards/banana.tres"


func test_a_new_profile_is_empty() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_int(profile.coins).is_equal(0)
	assert_int(profile.run_count).is_equal(0)
	assert_dict(profile.unlocked_items).is_empty()
	assert_dict(profile.coupon_uses).is_empty()
	assert_bool(profile.has_deck(load(STARTER))).is_true()


func test_only_an_ended_run_is_recorded() -> void:
	var profile: ProfileState = ProfileState.new()
	var run: RunState = _run(1)
	_check_out(run, [BREAD, REPEAT, BREAD])
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_array(profile.record_run(run, _catalogue([], []))).is_empty()
	assert_int(profile.run_count).is_equal(0)
	assert_dict(profile.coupon_uses).is_empty()
	MachineSteps.next_shift(run)
	_check_out(run, [REPEAT])
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	profile.record_run(run, _catalogue([], []))
	assert_int(profile.run_count).is_equal(1)
	assert_dict(profile.coupon_uses).is_equal({&"repeat": 2})
	var won: RunState = _won_run(2)
	assert_int(won.phase).is_equal(RunState.Phase.WON)
	profile.record_run(won, _catalogue([], []))
	assert_int(profile.run_count).is_equal(2)
	assert_dict(profile.coupon_uses).is_equal({&"repeat": 2})


func test_a_locked_deck_unlocks_when_its_condition_is_met() -> void:
	var profile: ProfileState = ProfileState.new()
	var deck: DeckDefinition = _deck(
		&"markdown_deck", UnlockCondition.Kind.WIN_WITH_CARD, FINAL_MARKDOWN, 0
	)
	var catalogue: CatalogueDefinition = _catalogue([load(STARTER), deck], [])
	assert_bool(profile.has_deck(deck)).is_false()
	var lost: RunState = _run(3)
	_check_out(lost, [])
	assert_array(profile.record_run(lost, catalogue)).is_empty()
	assert_array(profile.record_run(_won_run(4), catalogue)).is_equal([&"markdown_deck"])
	assert_bool(profile.has_deck(deck)).is_true()
	# Unlocked once; a deck without a condition is never listed.
	assert_array(profile.record_run(_won_run(5), catalogue)).is_empty()
	assert_array(profile.unlocked_decks).is_equal([&"markdown_deck"])


func test_coupon_use_unlocks_count_earlier_runs_then_add_this_one() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.coupon_uses[&"repeat"] = 2
	var variant: CardDefinition = _variant(UnlockCondition.Kind.USE_COUPON_TIMES, REPEAT, 4)
	var catalogue: CatalogueDefinition = _catalogue([], [variant])
	var run: RunState = _run(6)
	_check_out(run, [BREAD, REPEAT, BREAD])
	MachineSteps.next_shift(run)
	_check_out(run, [REPEAT])
	# 2 earlier + 2 now = 4 is checked before this run's uses are stored: 5 stays locked (it
	# would unlock if they were added first and counted twice), 4 unlocks.
	var five: CardDefinition = _variant(UnlockCondition.Kind.USE_COUPON_TIMES, REPEAT, 5)
	var stored: ProfileState = ProfileState.new()
	stored.coupon_uses[&"repeat"] = 2
	assert_array(stored.record_run(run, _catalogue([], [five]))).is_empty()
	assert_dict(stored.coupon_uses).is_equal({&"repeat": 4})
	assert_array(profile.record_run(run, catalogue)).is_equal([&"organic_banana"])
	assert_bool(profile.has_variant(variant)).is_true()
	assert_dict(profile.coupon_uses).is_equal({&"repeat": 4})


func test_decks_unlock_before_variants_in_catalogue_order() -> void:
	var profile: ProfileState = ProfileState.new()
	var score: UnlockCondition.Kind = UnlockCondition.Kind.SCORE_IN_ONE_CHECKOUT
	var second: DeckDefinition = _deck(&"second", score, "", 1)
	var first: DeckDefinition = _deck(&"first", score, "", 1)
	var variant: CardDefinition = _variant(score, "", 1)
	var catalogue: CatalogueDefinition = _catalogue([second, first], [variant])
	assert_array(profile.record_run(_won_run(7), catalogue)).is_equal(
		[&"second", &"first", &"organic_banana"]
	)


func test_the_saved_form_round_trips_through_json() -> void:
	var profile: ProfileState = _full_profile()
	var text: String = JSON.stringify(profile.to_dictionary())
	var read: ProfileState = ProfileState.from_dictionary(JSON.parse_string(text))
	assert_object(read).is_not_null()
	assert_dict(read.to_dictionary()).is_equal(profile.to_dictionary())
	# Draw order survives a writer that sorts keys.
	assert_array(read.unlocked_items.keys()).is_equal([&"zucchini", &"apple", &"melon"])
	assert_int(read.unlocked_items[&"apple"]).is_equal(4)
	assert_dict(read.coupon_uses).is_equal({&"repeat": 7})
	assert_dict(read.settings).is_equal({"volume": 0.5, "reduced_motion": true})
	assert_array(read.worn_pins).is_equal([&"full_redraw"])
	assert_int(read.pins_bought).is_equal(1)


func test_the_saved_form_states_its_format_version() -> void:
	var data: Dictionary = ProfileState.new().to_dictionary()
	assert_int(data["format_version"]).is_equal(ProfileState.FORMAT_VERSION)
	assert_int(ProfileState.FORMAT_VERSION).is_equal(3)


func test_missing_fields_keep_defaults_and_unknown_ones_are_ignored() -> void:
	var read: ProfileState = ProfileState.from_dictionary(
		{"format_version": 1.0, "run_count": 3.0, "later_field": "x"}
	)
	assert_int(read.run_count).is_equal(3)
	assert_int(read.coins).is_equal(0)
	assert_array(read.last_list).is_empty()


func test_the_count_up_settings_default_to_normal_speed_and_full_motion() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_float(profile.count_up_speed()).is_equal(ProfileState.COUNT_UP_NORMAL)
	assert_bool(profile.reduced_motion()).is_false()
	# An old profile, saved before these settings existed.
	var old: ProfileState = ProfileState.from_dictionary(
		{"format_version": 1.0, "settings": {"volume": 0.5}}
	)
	assert_float(old.count_up_speed()).is_equal(ProfileState.COUNT_UP_NORMAL)
	assert_bool(old.reduced_motion()).is_false()
	assert_float(ProfileState.COUNT_UP_NORMAL).is_equal(1.0)
	assert_float(ProfileState.COUNT_UP_FAST).is_equal(1.5)


## The count-up settings survive a profile save and load, as JSON in the profile's settings.
func test_the_count_up_settings_survive_a_save_and_load() -> void:
	var folder: String = "user://test_profile_settings_%d" % Time.get_ticks_usec()
	var errors: Array[String] = []
	var service: SaveService = SaveService.new(
		folder, func(message: String) -> void: errors.append(message)
	)
	var profile: ProfileState = ProfileState.new()
	profile.settings["volume"] = 0.5
	profile.set_count_up_speed(ProfileState.COUNT_UP_FAST)
	profile.set_reduced_motion(true)
	assert_dict(profile.settings).is_equal(
		{"volume": 0.5, "count_up_speed": 1.5, "reduced_motion": true}
	)
	assert_bool(service.save_profile(profile)).is_true()
	var read: ProfileState = service.load_profile()
	assert_float(read.count_up_speed()).is_equal(ProfileState.COUNT_UP_FAST)
	assert_bool(read.reduced_motion()).is_true()
	read.set_count_up_speed(ProfileState.COUNT_UP_NORMAL)
	read.set_reduced_motion(false)
	assert_bool(service.save_profile(read)).is_true()
	var again: ProfileState = service.load_profile()
	assert_float(again.count_up_speed()).is_equal(ProfileState.COUNT_UP_NORMAL)
	assert_bool(again.reduced_motion()).is_false()
	assert_float(again.settings["volume"]).is_equal(0.5)
	assert_array(errors).is_empty()
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


## A wrong-typed or unknown value (a hand-edited or older save) reads as the default; the
## profile still loads.
func test_wrong_count_up_settings_fall_back_to_the_defaults() -> void:
	var wrong: Array[Dictionary] = [
		{"count_up_speed": "fast", "reduced_motion": "yes"},
		{"count_up_speed": true, "reduced_motion": 1.0},
		{"count_up_speed": 3.0, "reduced_motion": null},
		{"count_up_speed": [1.5], "reduced_motion": {}},
	]
	for settings: Dictionary in wrong:
		var read: ProfileState = ProfileState.from_dictionary(
			{"format_version": 1, "settings": settings}
		)
		assert_object(read).override_failure_message(str(settings)).is_not_null()
		assert_float(read.count_up_speed()).override_failure_message(str(settings)).is_equal(
			ProfileState.COUNT_UP_NORMAL
		)
		assert_bool(read.reduced_motion()).override_failure_message(str(settings)).is_false()
	# JSON numbers load as floats, so an int is not a stored speed: it reads as Normal. A speed
	# other than the two is stored as Normal.
	var profile: ProfileState = ProfileState.new()
	profile.settings["count_up_speed"] = 1
	assert_float(profile.count_up_speed()).is_equal(ProfileState.COUNT_UP_NORMAL)
	profile.set_count_up_speed(2.0)
	assert_float(profile.settings["count_up_speed"]).is_equal(ProfileState.COUNT_UP_NORMAL)


func test_unreadable_forms_are_rejected() -> void:
	var bad: Array[Dictionary] = [
		{},
		{"format_version": "1"},
		{"format_version": 0},
		{"format_version": ProfileState.FORMAT_VERSION + 1},
		{"format_version": 1, "coins": 2.5},
		{"format_version": 1, "run_count": -1},
		{"format_version": 1, "unlocked_items": {"apple": 1}},
		{"format_version": 1, "unlocked_items": [["apple"]]},
		{"format_version": 1, "unlocked_items": [[3, 1]]},
		{"format_version": 1, "last_list": "dairy"},
		{"format_version": 1, "seen": [1]},
		{"format_version": 1, "coupon_uses": {"repeat": "2"}},
		{"format_version": 1, "stats": []},
		{"format_version": 1, "settings": []},
		{"format_version": 2, "capsule_seed": 12},
		{"format_version": 2, "capsule_seed": "12x"},
		{"format_version": 2, "capsule_seed": "-3"},
		{"format_version": 2, "capsule_draws": -1},
		{"format_version": 2, "unlocked_items": [["apple", -2]]},
		{"format_version": 3, "worn_pins": [1]},
		{"format_version": 3, "unlocked_pins": "full_redraw"},
		{"format_version": 3, "pins_bought": -1},
	]
	for data: Dictionary in bad:
		(
			assert_object(ProfileState.from_dictionary(data))
			. override_failure_message(str(data))
			. is_null()
		)


## Version 1 saves (before #63) read with no capsule seed and 0 draws.
func test_a_version_1_profile_reads_without_a_capsule_seed() -> void:
	var read: ProfileState = ProfileState.from_dictionary(
		{"format_version": 1.0, "coins": 3.0, "unlocked_items": [["cream", 0.0]]}
	)
	assert_object(read).is_not_null()
	assert_bool(read.has_capsule_seed).is_false()
	assert_int(read.capsule_draws).is_equal(0)
	assert_int(read.coins).is_equal(3)
	assert_str(read.to_dictionary()["capsule_seed"]).is_equal("")
	assert_int(read.to_dictionary()["format_version"]).is_equal(3)


## The seed is a decimal string, so one past 2^31 (and any 64-bit one) survives JSON.
func test_the_capsule_seed_round_trips_as_a_decimal_string() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_bool(profile.set_capsule_seed(4294967295)).is_true()
	var data: Dictionary = profile.to_dictionary()
	assert_str(data["capsule_seed"]).is_equal("4294967295")
	var read: ProfileState = ProfileState.from_dictionary(JSON.parse_string(JSON.stringify(data)))
	assert_bool(read.has_capsule_seed).is_true()
	assert_int(read.capsule_seed).is_equal(4294967295)
	var big: ProfileState = ProfileState.from_dictionary(
		{"format_version": 2, "capsule_seed": "9007199254740993", "capsule_draws": 4.0}
	)
	assert_int(big.capsule_seed).is_equal(9007199254740993)
	assert_int(big.capsule_draws).is_equal(4)


## set_capsule_seed counts the items already unlocked as draws and never replaces a seed.
func test_the_capsule_seed_is_set_once() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.unlocked_items = {&"cream": 0, &"baguette": 1}
	assert_bool(profile.set_capsule_seed(77)).is_true()
	assert_int(profile.capsule_draws).is_equal(2)
	profile.capsule_draws = 5
	assert_bool(profile.set_capsule_seed(99)).is_false()
	assert_int(profile.capsule_seed).is_equal(77)
	assert_int(profile.capsule_draws).is_equal(5)


## A draw spends the price, records the item at the run index (in draw order) and counts it.
func test_a_capsule_spends_the_price_and_records_its_run_index() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	profile.coins = 3
	profile.run_count = 4
	profile.set_capsule_seed(1)
	var bakery: AisleDefinition = _aisle(balance, &"bakery")
	var index: int = profile.capsule_run_index(false)
	var card: CardDefinition = profile.draw_capsule(
		bakery, balance.capsule_price, index, _stream(1, 0)
	)
	assert_str(String(card.id)).is_equal("baguette")
	assert_int(profile.coins).is_equal(3 - balance.capsule_price)
	assert_int(profile.unlocked_items[&"baguette"]).is_equal(3)
	assert_int(profile.capsule_draws).is_equal(1)
	var second: CardDefinition = profile.draw_capsule(
		_aisle(balance, &"pantry"),
		balance.capsule_price,
		profile.capsule_run_index(true),
		_stream(1, 1)
	)
	assert_str(String(second.id)).is_equal("sugar_cubes")
	assert_int(profile.unlocked_items[&"sugar_cubes"]).is_equal(4)
	assert_array(profile.unlocked_items.keys()).is_equal([&"baguette", &"sugar_cubes"])
	assert_int(profile.owned_capsules(balance)).is_equal(2)


## Results or title with no saved run: the ended run's index; title while a run is saved: the
## saved run's. Before any run ended (debug coins) that is -1, which saves and reads back.
func test_the_run_index_rule_and_a_draw_before_any_run() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	profile.run_count = 6
	assert_int(profile.capsule_run_index(false)).is_equal(5)
	assert_int(profile.capsule_run_index(true)).is_equal(6)
	var fresh: ProfileState = ProfileState.new()
	fresh.coins = 1
	assert_int(fresh.capsule_run_index(false)).is_equal(-1)
	fresh.draw_capsule(_aisle(balance, &"snacks"), 1, -1, _stream(2, 0))
	assert_int(fresh.unlocked_items[&"crisps"]).is_equal(-1)
	var read: ProfileState = ProfileState.from_dictionary(
		JSON.parse_string(JSON.stringify(fresh.to_dictionary()))
	)
	assert_object(read).is_not_null()
	assert_int(read.unlocked_items[&"crisps"]).is_equal(-1)


func test_no_coins_or_an_empty_machine_draws_nothing_and_changes_nothing() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	var cold: AisleDefinition = _aisle(balance, &"cold_cases")
	var saved_form: Dictionary = profile.to_dictionary()
	assert_bool(profile.can_draw(cold, 1)).is_false()
	assert_object(profile.draw_capsule(cold, 1, 0, _stream(3, 0))).is_null()
	assert_dict(profile.to_dictionary()).is_equal(saved_form)
	profile.coins = 5
	profile.unlocked_items = {&"cream": 0, &"ham_ends": 0}
	saved_form = profile.to_dictionary()
	assert_bool(profile.can_draw(cold, 1)).is_false()
	assert_object(profile.draw_capsule(cold, 1, 0, _stream(3, 0))).is_null()
	assert_dict(profile.to_dictionary()).is_equal(saved_form)


## The rollback of a failed save gives back exactly the profile before the draw.
func test_undo_capsule_restores_the_profile() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = _full_profile()
	profile.set_capsule_seed(42)
	var saved_form: Dictionary = profile.to_dictionary()
	var draws: int = profile.capsule_draws
	var card: CardDefinition = profile.draw_capsule(
		_aisle(balance, &"bakery"), 1, 8, _stream(42, draws)
	)
	assert_dict(profile.to_dictionary()).is_not_equal(saved_form)
	profile.undo_capsule(card, 1, draws)
	assert_dict(profile.to_dictionary()).is_equal(saved_form)


## Debug tools: unlock everything (a draw counted per item), then reset (the seed kept).
func test_unlock_all_and_reset_the_collection() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	profile.set_capsule_seed(9)
	profile.unlocked_items[&"cream"] = 0
	profile.capsule_draws = 1
	profile.unlock_all_capsules(balance, 2)
	assert_int(profile.owned_capsules(balance)).is_equal(30)
	assert_int(profile.capsule_draws).is_equal(30)
	assert_int(profile.unlocked_items[&"cream"]).is_equal(0)
	assert_int(profile.unlocked_items[&"crisps"]).is_equal(2)
	profile.last_list.assign([&"bakery", &"snacks"])
	profile.reset_collection()
	assert_dict(profile.unlocked_items).is_empty()
	assert_int(profile.capsule_draws).is_equal(0)
	assert_array(profile.last_list).is_empty()
	assert_int(profile.capsule_seed).is_equal(9)


static func _aisle(balance: BalanceDefinition, id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in balance.aisles:
		if aisle.id == id:
			return aisle
	return null


static func _stream(seed_value: int, draw: int) -> RandomNumberGenerator:
	return EventLogService.capsule_stream(seed_value, draw)


static func _full_profile() -> ProfileState:
	var profile: ProfileState = ProfileState.new()
	profile.coins = 12
	profile.run_count = 9
	profile.unlocked_items[&"zucchini"] = 2
	profile.unlocked_items[&"apple"] = 4
	profile.unlocked_items[&"melon"] = 4
	profile.last_list.assign([&"dairy", &"bakery"])
	profile.unlocked_decks.append(&"breakfast")
	profile.unlocked_variants.append(&"organic_banana")
	profile.coupon_uses[&"repeat"] = 7
	profile.seen.append(&"capsule_machine")
	profile.achievements.append(&"first_win")
	profile.stats[&"best_checkout"] = 88
	profile.settings = {"volume": 0.5, "reduced_motion": true}
	profile.unlocked_pins.append(&"full_redraw")
	profile.worn_pins.append(&"full_redraw")
	profile.pins_bought = 1
	return profile


static func _catalogue(decks: Array, variants: Array) -> CatalogueDefinition:
	var catalogue: CatalogueDefinition = CatalogueDefinition.new()
	catalogue.decks.assign(decks)
	catalogue.variants.assign(variants)
	return catalogue


static func _condition(
	kind: UnlockCondition.Kind, card_path: String, amount: int
) -> UnlockCondition:
	var condition: UnlockCondition = UnlockCondition.new()
	condition.kind = kind
	if not card_path.is_empty():
		condition.card = load(card_path)
	condition.amount = amount
	return condition


static func _deck(
	id: StringName, kind: UnlockCondition.Kind, card_path: String, amount: int
) -> DeckDefinition:
	var deck: DeckDefinition = (load(STARTER) as DeckDefinition).duplicate()
	deck.id = id
	deck.unlock_condition = _condition(kind, card_path, amount)
	return deck


static func _variant(kind: UnlockCondition.Kind, card_path: String, amount: int) -> CardDefinition:
	var banana: CardDefinition = load(BANANA)
	var variant: CardDefinition = banana.duplicate()
	variant.id = &"organic_banana"
	variant.variant_of = banana
	variant.unlock_condition = _condition(kind, card_path, amount)
	return variant


static func _run(seed_value: int) -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	# The run before v0.65's loop rework: no Manager's reviews, and a miss ends the run.
	balance.review_shifts = PackedInt32Array()
	balance.boon_shifts = PackedInt32Array()
	balance.write_up_limit = 0
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	run.start_shift()
	return run


static func _check_out(run: RunState, paths: Array) -> void:
	for path: String in paths:
		run.place(run.debug_add_to_hand(load(path)), run.row.size())
	run.checkout()


## A run won on its last shift with two Breads (6, every quota is 5).
static func _won_run(seed_value: int) -> RunState:
	var run: RunState = _run(seed_value)
	run.debug_skip_to_shift(run.shift_count() - 1)
	_check_out(run, [BREAD, BREAD])
	return run
