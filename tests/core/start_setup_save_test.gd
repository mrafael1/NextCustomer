extends GdUnitTestSuite
## The opening-time setup's saved forms and telemetry (StartSetup, RunSave, ProfileState,
## RunEvents; full build plan 7.2, reworked 2026-11-05): a resume restores every choice, offer
## and spent action; damaged setups are refused; the run save cross-checks the setup; a setup in
## the first build's form restarts (or is dropped past clock-in); the profile keeps its choice;
## the setup events. On the live data; nothing here touches a save file.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261104

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = Kit.balance()
	_recipe = Kit.recipe()


## A resume restores every choice exactly: the stage, the baskets, the spent RESTOCK and NEW
## PACKS, the regular offers, the pick and the swapped regulars, in SELECT, REVEALED and BUILD.
func test_a_resume_restores_the_choices_offers_and_spent_actions() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var profile: ProfileState = Kit.profile(3)
	var waiting: RunState = Kit.run(profile, SEED)
	var read: RunSave = RunSave.from_dictionary(
		Kit.json(RunSave.to_dictionary(waiting, "run", 0)), lookup
	)
	assert_object(read).is_not_null()
	assert_dict(read.run.start_setup.to_dictionary()).is_equal(waiting.start_setup.to_dictionary())
	assert_array(read.run.start_offer.packs).is_empty()
	var run: RunState = Kit.locked(profile, SEED)
	var cold: AisleDefinition = _balance.aisles[0]
	StartSetupRules.regular_offer(run, profile, 1, cold.id, Kit.regulars_rng(run, 1, cold.id))
	assert_bool(Kit.swap(run, profile, 1)).is_true()
	StartSetupRules.restock(run, profile, 2, Kit.restock_rng(run, 2))
	StartSetupRules.new_packs(run, profile, Kit.new_packs_rng(run))
	run.start_setup.picked = run.start_offer.packs[2].id
	StartSetupRules.mark_build(run)
	var saved: RunSave = RunSave.from_dictionary(
		Kit.json(RunSave.to_dictionary(run, "run", 0)), lookup
	)
	assert_object(saved).is_not_null()
	var setup: StartSetup = saved.run.start_setup
	assert_dict(setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	assert_int(setup.stage).is_equal(StartSetup.Stage.BUILD)
	assert_int(setup.restock_basket).is_equal(2)
	assert_bool(setup.packs_redrawn).is_true()
	assert_array(setup.regular_offer(1, cold.id)).is_equal(
		run.start_setup.regular_offer(1, cold.id)
	)
	assert_array(saved.run.start_offer.packs).is_equal(run.start_offer.packs)
	assert_array(saved.run.start_offer.shared).is_equal(run.start_offer.shared)
	assert_array(saved.run.starter.core_cards).is_equal(run.starter.core_cards)
	assert_str(String(StartSetupRules.restock_block(saved.run, profile, 0))).is_equal("used")
	assert_str(String(StartSetupRules.new_packs_block(saved.run, profile))).is_equal("used")


func test_a_damaged_setup_is_refused() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = Kit.locked(Kit.profile(3), SEED)
	var good: Dictionary = Kit.json(run.start_setup.to_dictionary())
	assert_object(StartSetup.from_dictionary(good, lookup)).is_not_null()
	var cold: String = String(_balance.aisles[0].id)
	var staples: Array = good["baskets"][0]["cards"]
	for change: Dictionary in [
		{"stage": "done"},
		{"stock_aisles": []},
		{"stock_aisles": ["pantry", "pantry", "household"]},
		{"stock_aisles": ["pantry", "household", "unknown"]},
		{"restock_basket": 3},
		{"restock_basket": -2},
		{"completed_count": 99},
		{"picked": 3},
		{"packs_redrawn": "yes"},
		{"baskets": []},
		{"baskets": [{"source": "pantry", "cards": []}] + good["baskets"].slice(1)},
		{
			"baskets":
			[{"source": "staples", "cards": staples + ["bread"]}] + good["baskets"].slice(1)
		},
		{"baskets": [{"source": "staples", "cards": ["cheese"]}] + good["baskets"].slice(1)},
		{"baskets": [{"source": "staples", "cards": ["unknown_card"]}] + good["baskets"].slice(1)},
		{"regular_offers": {"9:%s" % cold: ["cheese"]}},
		{"regular_offers": {"0:%s" % cold: ["cereal"]}},
		{"regular_offers": {"0:%s" % cold: ["cheese", "cheese"]}},
		{"regular_offers": {"x": ["cheese"]}},
		{"regular_offers": []},
		{"originals": "milk"},
		{"restock_source": 3},
		{"restock_source": "pantry"},
		{"dealt_sets": []},
		{"dealt_sets": {"staples": ["cheese"]}},
		{"dealt_sets": {"staples": staples + ["bread", "bread"]}},
	]:
		var bad: Dictionary = good.duplicate(true)
		bad.merge(change, true)
		(
			assert_object(StartSetup.from_dictionary(bad, lookup))
			. override_failure_message(str(change))
			. is_null()
		)
	# SELECT holds nothing dealt, spent or picked.
	var select: Dictionary = Kit.json(Kit.run(Kit.profile(3), SEED).start_setup.to_dictionary())
	assert_object(StartSetup.from_dictionary(select, lookup)).is_not_null()
	for change: Dictionary in [{"restock_basket": 0}, {"packs_redrawn": true}, {"picked": "x"}]:
		var bad: Dictionary = select.duplicate(true)
		bad.merge(change, true)
		assert_object(StartSetup.from_dictionary(bad, lookup)).is_null()
	var dealt: Dictionary = select.duplicate(true)
	dealt["baskets"] = good["baskets"]
	dealt["stock_aisles"] = good["stock_aisles"]
	assert_object(StartSetup.from_dictionary(dealt, lookup)).is_null()


## The run save keeps the setup: its originals are the recipe's regulars, a swapped regular is a
## plain product, the offer's shared products are the baskets' cards, and a SELECT setup has an
## empty offer and waits for its pick.
func test_the_run_save_cross_checks_the_setup() -> void:
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	assert_bool(Kit.swap(run, profile, 0)).is_true()
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var good: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	var saved: RunSave = RunSave.from_dictionary(good, lookup)
	assert_object(saved).is_not_null()
	assert_array(saved.run.starter.core_cards).is_equal(run.starter.core_cards)
	assert_array(saved.run.start_setup.originals).is_equal(_recipe.core_cards)
	var tampered: Dictionary = good.duplicate(true)
	tampered["start_setup"]["originals"][1] = "cheese"
	assert_object(RunSave.from_dictionary(tampered, lookup)).is_null()
	var big: Dictionary = good.duplicate(true)
	big["regulars"][0] = String(Kit.chain_of(_balance.aisles[0]).big.id)
	assert_object(RunSave.from_dictionary(big, lookup)).is_null()
	var other_basket: Dictionary = good.duplicate(true)
	var swapped: Array = other_basket["start_setup"]["baskets"][1]["cards"]
	other_basket["start_setup"]["baskets"][1]["cards"] = [swapped[1], swapped[0]]
	assert_object(RunSave.from_dictionary(other_basket, lookup)).is_null()
	var picked: Dictionary = good.duplicate(true)
	picked["start_setup"]["picked"] = "not_offered"
	assert_object(RunSave.from_dictionary(picked, lookup)).is_null()
	var select: Dictionary = Kit.json(RunSave.to_dictionary(Kit.run(profile, SEED), "run", 0))
	assert_object(RunSave.from_dictionary(select, lookup)).is_not_null()
	var with_packs: Dictionary = select.duplicate(true)
	with_packs["start_offer"] = good["start_offer"]
	assert_object(RunSave.from_dictionary(with_packs, lookup)).is_null()


## A run waiting for its pick with a setup in the first build's form (no stage) reads with no
## setup and restarts it; a run past clock-in drops it. Nothing is printed.
func test_an_old_format_setup_restarts_or_is_dropped() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var old_setup: Dictionary = {
		"stock_aisles": ["pantry", "household", "cold_cases"],
		"first_aisles": ["pantry", "household", "cold_cases"],
		"first_deal": [],
		"restocks": 0,
		"use_second": false,
		"picked": "",
	}
	assert_bool(StartSetup.is_old_format(old_setup)).is_true()
	assert_object(StartSetup.from_dictionary(old_setup, lookup)).is_null()
	var run: RunState = Kit.locked(Kit.profile(0), SEED)
	var waiting: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	waiting["start_setup"] = old_setup
	var read: RunSave = RunSave.from_dictionary(waiting, lookup)
	assert_object(read).is_not_null()
	assert_object(read.run.start_setup).is_null()
	assert_bool(read.run.restart_setup).is_true()
	assert_int(read.run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_bool(run.take_pack(run.start_offer.default_pack())).is_true()
	run.start_shift()
	var playing: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	playing["start_setup"] = old_setup
	var later: RunSave = RunSave.from_dictionary(playing, lookup)
	assert_object(later).is_not_null()
	assert_object(later.run.start_setup).is_null()
	assert_bool(later.run.restart_setup).is_false()


## The profile keeps the aisle choice but no regular swap (v1.08: swaps reset each run). A
## version 4 profile's saved swaps (any form) still read, are dropped, and never saved again.
func test_the_profile_keeps_its_choice_but_no_swaps() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.stock_pair = [&"snacks", &"bakery"]
	profile.stock_run_only = &"pantry"
	var saved: Dictionary = Kit.json(profile.to_dictionary())
	assert_bool(saved.has("staple_swaps")).is_false()
	var read: ProfileState = ProfileState.from_dictionary(saved)
	assert_object(read).is_not_null()
	assert_array(read.stock_pair).is_equal(profile.stock_pair)
	assert_str(String(read.stock_run_only)).is_equal("pantry")
	for swaps: Variant in [["cheese", "", "cereal", ""], "cheese", 3.0]:
		var v4: Dictionary = saved.duplicate(true)
		v4["format_version"] = 4.0
		v4["staple_swaps"] = swaps
		var old: ProfileState = ProfileState.from_dictionary(v4)
		assert_object(old).is_not_null()
		assert_array(old.stock_pair).is_equal(profile.stock_pair)
		assert_bool(Kit.json(old.to_dictionary()).has("staple_swaps")).is_false()
	var older: Dictionary = saved.duplicate(true)
	older["format_version"] = 3
	older.erase("stock_pair")
	older.erase("stock_run_only")
	var oldest: ProfileState = ProfileState.from_dictionary(older)
	assert_object(oldest).is_not_null()
	assert_array(oldest.stock_pair).is_empty()
	assert_str(String(oldest.stock_run_only)).is_empty()
	read.reset_collection()
	assert_array(read.stock_pair).is_empty()
	assert_str(String(read.stock_run_only)).is_empty()


## A save from before v1.07 has no restock_source or dealt_sets: they come from its baskets.
func test_a_setup_saved_before_the_counter_reads_its_dealt_pairs() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	StartSetupRules.restock(run, profile, 2, Kit.restock_rng(run, 2))
	var old: Dictionary = Kit.json(run.start_setup.to_dictionary())
	old.erase("restock_source")
	old.erase("dealt_sets")
	var read: StartSetup = StartSetup.from_dictionary(old, lookup)
	assert_object(read).is_not_null()
	assert_str(String(read.restock_source)).is_equal(String(run.start_setup.baskets[2].source))
	assert_bool(read.restocked(2)).is_true()
	for basket: StartBasket in run.start_setup.baskets:
		assert_array(read.dealt_set(basket.source)).is_equal(basket.cards)
	assert_dict(read.to_dictionary()).is_equal(run.start_setup.to_dictionary())


## An aisle switched away is held only in dealt_sets: it survives a save and a load (the run
## save's checks accept it), and switching back after the resume deals its first pair again (kept),
## so quitting and resuming never rerolls a basket. With RESTOCK spent on the switched-away aisle,
## its restocked pair and RESTOCKED mark come back too.
func test_a_switched_away_aisle_survives_a_resume() -> void:
	for restock_first: bool in [false, true]:
		var lookup: ContentLookup = ContentLookup.new(_balance)
		var profile: ProfileState = Kit.profile(6)
		var run: RunState = Kit.locked(profile, SEED)
		var setup: StartSetup = run.start_setup
		var first: StringName = setup.baskets[1].source
		if restock_first:
			var refused: StringName = StartSetupRules.restock(
				run, profile, 1, Kit.restock_rng(run, 1)
			)
			assert_str(String(refused)).is_empty()
		var first_pair: Array[CardDefinition] = setup.baskets[1].cards.duplicate()
		var other: StringName = StartSetupRules.aisle_options(run, profile, 1)[0]
		assert_str(String(_change(run, profile, 1, other))).is_empty()
		var saved: RunSave = RunSave.from_dictionary(
			Kit.json(RunSave.to_dictionary(run, "run", 0)), lookup
		)
		assert_object(saved).override_failure_message(str(restock_first)).is_not_null()
		var resumed: RunState = saved.run
		var read: StartSetup = resumed.start_setup
		assert_str(String(read.baskets[1].source)).is_equal(String(other))
		assert_array(read.dealt_set(first)).is_equal(first_pair)
		assert_bool(read.restocked(1)).is_false()
		# Switching back after the resume: the first pair returns, nothing rerolled.
		var kept: bool = not read.dealt_set(first).is_empty()
		assert_bool(kept).is_true()
		assert_str(String(_change(resumed, profile, 1, first))).is_empty()
		assert_array(read.baskets[1].cards).is_equal(first_pair)
		assert_bool(read.restocked(1)).is_equal(restock_first)
		var spent: String = "used" if restock_first else ""
		assert_str(String(StartSetupRules.restock_block(resumed, profile, 1))).is_equal(spent)


func _change(run: RunState, profile: ProfileState, basket: int, aisle_id: StringName) -> StringName:
	return StartSetupRules.change_aisle(
		run,
		profile,
		basket,
		aisle_id,
		EventLogService.derived_stream(run.run_seed, EventLogService.START_BASKET_STREAM % aisle_id)
	)


## The setup's telemetry: start_aisle (a starter basket's aisle changed), restock (one basket),
## new_packs and start_choice's setup fields.
func test_the_setup_events() -> void:
	var all: ProfileState = Kit.profile(6)
	var chosen: RunState = Kit.locked(all, SEED)
	var old: StartBasket = chosen.start_setup.baskets[1].copy()
	var aisle_id: StringName = StartSetupRules.aisle_options(chosen, all, 1)[0]
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		SEED, EventLogService.START_BASKET_STREAM % aisle_id
	)
	assert_str(String(StartSetupRules.change_aisle(chosen, all, 1, aisle_id, stream))).is_empty()
	var aisle: Dictionary = RunEvents.start_aisle(chosen, 1, old, false)
	assert_int(aisle["basket"]).is_equal(1)
	assert_str(aisle["from"]).is_equal(String(old.source))
	assert_str(aisle["to"]).is_equal(String(aisle_id))
	assert_array(aisle["before"]).is_equal(RunEvents.definition_ids(old.cards))
	assert_array(aisle["after"]).is_equal(
		RunEvents.definition_ids(chosen.start_setup.baskets[1].cards)
	)
	assert_array(aisle["green"]).is_equal(Array(chosen.start_setup.green_ids(_balance)))
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var kept: Array[CardDefinition] = run.start_setup.baskets[1].cards.duplicate()
	StartSetupRules.restock(run, profile, 1, Kit.restock_rng(run, 1))
	var restock: Dictionary = RunEvents.start_restock(run, 1, kept)
	assert_int(restock["basket"]).is_equal(1)
	assert_str(restock["source"]).is_equal(String(run.start_setup.baskets[1].source))
	assert_array(restock["before"]).is_equal(RunEvents.definition_ids(kept))
	var fields: Dictionary = RunEvents.start_setup_fields(run)
	assert_int(fields["restock"]).is_equal(1)
	assert_int(fields["restock_basket"]).is_equal(1)
	assert_int(fields["new_packs"]).is_equal(0)
	assert_dict(RunEvents.new_packs([], [], &"x")).is_equal(
		{"before": [], "after": [], "picked_before": "x"}
	)
	assert_array(RunEvents.run_start(run)["baskets"]).is_equal(fields["baskets"])
