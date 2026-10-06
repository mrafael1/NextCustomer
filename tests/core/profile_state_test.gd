extends GdUnitTestSuite
## The profile (full build plan sections 4 and 7.3): recording an ended run (run count, coupon
## uses, deck and variant unlocks) and the saved form. Uses the live starter deck and balance
## with every quota at 5, and builds conditions, decks and variants in code.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"
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
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	assert_array(profile.record_run(run, _catalogue([], []))).is_empty()
	assert_int(profile.run_count).is_equal(0)
	assert_dict(profile.coupon_uses).is_empty()
	run.skip_reward()
	run.next_shift()
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
	var deck: DeckDefinition = _deck(&"repeat_deck", UnlockCondition.Kind.WIN_WITH_CARD, REPEAT, 0)
	var catalogue: CatalogueDefinition = _catalogue([load(STARTER), deck], [])
	assert_bool(profile.has_deck(deck)).is_false()
	var lost: RunState = _run(3)
	_check_out(lost, [])
	assert_array(profile.record_run(lost, catalogue)).is_empty()
	assert_array(profile.record_run(_won_run(4), catalogue)).is_equal([&"repeat_deck"])
	assert_bool(profile.has_deck(deck)).is_true()
	# Unlocked once; a deck without a condition is never listed.
	assert_array(profile.record_run(_won_run(5), catalogue)).is_empty()
	assert_array(profile.unlocked_decks).is_equal([&"repeat_deck"])


func test_coupon_use_unlocks_count_earlier_runs_then_add_this_one() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.coupon_uses[&"repeat"] = 2
	var variant: CardDefinition = _variant(UnlockCondition.Kind.USE_COUPON_TIMES, REPEAT, 4)
	var catalogue: CatalogueDefinition = _catalogue([], [variant])
	var run: RunState = _run(6)
	_check_out(run, [BREAD, REPEAT, BREAD])
	run.skip_reward()
	run.next_shift()
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


func test_the_saved_form_states_its_format_version() -> void:
	var data: Dictionary = ProfileState.new().to_dictionary()
	assert_int(data["format_version"]).is_equal(ProfileState.FORMAT_VERSION)
	assert_int(ProfileState.FORMAT_VERSION).is_equal(1)


func test_missing_fields_keep_defaults_and_unknown_ones_are_ignored() -> void:
	var read: ProfileState = ProfileState.from_dictionary(
		{"format_version": 1.0, "run_count": 3.0, "later_field": "x"}
	)
	assert_int(read.run_count).is_equal(3)
	assert_int(read.coins).is_equal(0)
	assert_array(read.last_list).is_empty()


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
	]
	for data: Dictionary in bad:
		(
			assert_object(ProfileState.from_dictionary(data))
			. override_failure_message(str(data))
			. is_null()
		)


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
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
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
