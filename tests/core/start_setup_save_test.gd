extends GdUnitTestSuite
## The opening-time setup's saved forms and telemetry (StartSetup, RunSave, ProfileState,
## RunEvents; full build plan 7.2, v1.32 "boosters", run save format 13): a resume restores every
## booster, choice, offer and spent action; damaged setups are refused; the run save cross-checks
## the setup; a setup in an older form (the first build's, v1.07's baskets, a version 12 save)
## restarts (or is dropped past clock-in); the profile's saved pair; the setup events. On the live
## data; nothing here touches a save file.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261104

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = Kit.balance()
	_recipe = Kit.recipe()


## A resume restores every choice exactly: the stage, the boosters (sealed or opened, RESTOCKED),
## the spent NEW PACKS, the pins step, the regular offers, the pick and the swapped regulars, in
## SELECT, DEALT and BUILD; PICK 2 OF 3 resumes still picking, or with its SOLD OUT booster.
func test_a_resume_restores_the_boosters_choices_and_spent_actions() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var profile: ProfileState = Kit.profile(3)
	var waiting: RunState = Kit.run(profile, SEED)
	var read: RunSave = _round_trip(waiting, lookup)
	assert_object(read).is_not_null()
	assert_dict(read.run.start_setup.to_dictionary()).is_equal(waiting.start_setup.to_dictionary())
	assert_array(read.run.start_offer.packs).is_empty()
	var sealed: RunState = Kit.dealt(profile, SEED)
	var resumed: RunSave = _round_trip(sealed, lookup)
	assert_object(resumed).is_not_null()
	assert_bool(resumed.run.start_setup.boosters[0].opened).is_false()
	assert_str(String(StartSetupRules.open_booster(resumed.run, 0))).is_empty()
	var run: RunState = Kit.locked(profile, SEED)
	var cold: AisleDefinition = _balance.aisles[0]
	StartSetupRules.regular_offer(run, profile, 1, cold.id, Kit.regulars_rng(run, 1, cold.id))
	assert_bool(Kit.swap(run, profile, 1)).is_true()
	StartSetupRules.restock(run, profile, 1, Kit.restock_rng(run, 1))
	StartSetupRules.open_booster(run, 1)
	StartSetupRules.new_packs(run, profile, Kit.new_packs_rng(run))
	StartSetupRules.confirm_pins(run)
	run.start_setup.picked = run.start_offer.packs[2].id
	StartSetupRules.mark_build(run)
	var saved: RunSave = _round_trip(run, lookup)
	assert_object(saved).is_not_null()
	var setup: StartSetup = saved.run.start_setup
	assert_dict(setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	assert_int(setup.stage).is_equal(StartSetup.Stage.BUILD)
	assert_int(setup.restock_booster()).is_equal(1)
	assert_bool(setup.boosters[1].opened).is_true()
	assert_bool(setup.packs_redrawn).is_true()
	assert_bool(setup.pins_confirmed).is_true()
	assert_array(setup.regular_offer(1, cold.id)).is_equal(
		run.start_setup.regular_offer(1, cold.id)
	)
	assert_array(saved.run.start_offer.packs).is_equal(run.start_offer.packs)
	assert_array(saved.run.start_offer.shared).is_equal(run.start_offer.shared)
	assert_array(saved.run.starter.core_cards).is_equal(run.starter.core_cards)
	assert_str(String(StartSetupRules.restock_block(saved.run, profile, 0))).is_equal("used")
	assert_str(String(StartSetupRules.new_packs_block(saved.run, profile))).is_equal("used")
	var all: ProfileState = Kit.profile(6)
	var picking: RunState = Kit.dealt(all, SEED)
	var still: RunSave = _round_trip(picking, lookup)
	assert_object(still).is_not_null()
	assert_bool(still.run.start_setup.picking()).is_true()
	assert_array(still.run.start_offer.shared).is_equal(picking.start_setup.shared())
	var picks: Array[int] = [1, 2]
	StartSetupRules.pick_boosters(picking, all, picks, Kit.pick_rng(picking))
	var picked: RunSave = _round_trip(picking, lookup)
	assert_object(picked).is_not_null()
	assert_bool(picked.run.start_setup.boosters[0].sold_out).is_true()
	assert_array(picked.run.start_setup.stock_aisles).is_equal(picking.start_setup.stock_aisles)
	assert_array(picked.run.stock.aisle_ids).is_equal(picking.stock.aisle_ids)


## A RARE hit card (a BIG tier at the hit place, RARE odds forced to 100%) survives a round trip,
## sealed and opened, still RARE at its place.
func test_a_rare_hit_card_survives_a_round_trip() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.run(profile, SEED)
	var odds: BalanceDefinition = _balance.duplicate()
	odds.start_booster_hit_rare_percent = 100
	run.balance = odds
	assert_str(String(Kit.deal(run, profile))).is_empty()
	var rare: int = 0
	for booster: StartBooster in run.start_setup.boosters:
		rare += booster.rare_count()
	assert_int(rare).is_greater(0)
	for opened: bool in [false, true]:
		if opened:
			Kit.open_all(run)
		var read: RunSave = _round_trip(run, lookup)
		assert_object(read).is_not_null()
		assert_dict(read.run.start_setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
		for index: int in run.start_setup.boosters.size():
			var booster: StartBooster = run.start_setup.boosters[index]
			var again: StartBooster = read.run.start_setup.boosters[index]
			assert_int(again.rare_count()).is_equal(booster.rare_count())
			for place: int in booster.cards.size():
				assert_bool(again.is_rare(place)).is_equal(booster.is_rare(place))


func test_a_damaged_setup_is_refused() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = Kit.locked(Kit.profile(3), SEED)
	var good: Dictionary = Kit.json(run.start_setup.to_dictionary())
	assert_object(StartSetup.from_dictionary(good, lookup)).is_not_null()
	var cold: String = String(_balance.aisles[0].id)
	var first: Dictionary = good["boosters"][0]
	var cards: Array = first["cards"]
	var table: Array[ItemUpgradeDefinition] = _balance.machine.item_upgrades
	var plain: CardDefinition = run.start_setup.boosters[0].cards[0]
	var chain: ItemUpgradeDefinition = ItemUpgrades.chain_for(table, plain)
	var other_aisle: Variant = good["boosters"][1]["aisle"]
	var run_only: Variant = good["stock_aisles"][2]
	for change: Dictionary in [
		{"stage": "done"},
		{"stage": "revealed"},
		{"stock_aisles": []},
		{"stock_aisles": ["pantry", "pantry", "household"]},
		{"stock_aisles": ["pantry", "household", "unknown"]},
		{"completed_count": 99},
		{"picked": 3},
		{"packs_redrawn": "yes"},
		{"pins_confirmed": "yes"},
		{"boosters": []},
		{"boosters": "x"},
		_booster(good, 0, {"aisle": other_aisle}),
		_booster(good, 0, {"aisle": run_only}),
		_booster(good, 0, {"cards": cards + [cards[0]]}),
		_booster(good, 0, {"cards": [cards[0], cards[0], cards[2]]}),
		_booster(good, 0, {"cards": [String(chain.big.id), cards[1], cards[2]]}),
		_booster(good, 0, {"cards": [cards[0], cards[1], String(chain.golden.id)]}),
		_booster(good, 0, {"cards": ["unknown_card", cards[1], cards[2]]}),
		_booster(good, 0, {"hits": 2}),
		_booster(good, 0, {"hits": -1}),
		_booster(good, 0, {"opened": "yes"}),
		_booster(good, 0, {"sold_out": true}),
		_booster(good, 0, {"restocked": true}).merged({"completed_count": 0}, true),
		{"boosters": [_restocked(first), _restocked(good["boosters"][1])]},
		{"regular_offers": {"9:%s" % cold: ["cheese"]}},
		{"regular_offers": {"0:%s" % cold: ["cereal"]}},
		{"regular_offers": {"0:%s" % cold: ["cheese", "cheese"]}},
		{"regular_offers": {"0:%s" % cold: ["cheese", "butter", "yogurt", "frozen_peas"]}},
		{"regular_offers": {"x": ["cheese"]}},
		{"regular_offers": []},
		{"originals": "milk"},
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
	for change: Dictionary in [
		{"packs_redrawn": true},
		{"picked": "x"},
		{"pins_confirmed": true},
		{"boosters": good["boosters"]}
	]:
		var bad: Dictionary = select.duplicate(true)
		bad.merge(change, true)
		assert_object(StartSetup.from_dictionary(bad, lookup)).is_null()


## PICK 2 OF 3's saved states: while picking nothing is opened, restocked or redrawn and the
## seeded pair stays today's; after it exactly the others are SOLD OUT, never opened.
func test_a_damaged_pick_is_refused() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var all: ProfileState = Kit.profile(6)
	var picking: Dictionary = Kit.json(Kit.dealt(all, SEED).start_setup.to_dictionary())
	assert_object(StartSetup.from_dictionary(picking, lookup)).is_not_null()
	for change: Dictionary in [
		_booster(picking, 0, {"opened": true}),
		_booster(picking, 2, {"opened": true}),
		{"packs_redrawn": true},
		{"stage": "build"},
		{"completed_count": 5},
		_booster(picking, 2, {"aisle": picking["boosters"][0]["aisle"]}),
	]:
		var bad: Dictionary = picking.duplicate(true)
		bad.merge(change, true)
		(
			assert_object(StartSetup.from_dictionary(bad, lookup))
			. override_failure_message(str(change))
			. is_null()
		)
	var run: RunState = Kit.dealt(all, SEED)
	var picks: Array[int] = [0, 2]
	StartSetupRules.pick_boosters(run, all, picks, Kit.pick_rng(run))
	var picked: Dictionary = Kit.json(run.start_setup.to_dictionary())
	assert_object(StartSetup.from_dictionary(picked, lookup)).is_not_null()
	for change: Dictionary in [
		_booster(picked, 1, {"opened": true}),
		_booster(picked, 1, {"restocked": true}),
		_booster(picked, 0, {"sold_out": true}),
		{
			"stock_aisles":
			Kit.json(Kit.dealt(all, SEED).start_setup.to_dictionary())["stock_aisles"]
		},
	]:
		var bad: Dictionary = picked.duplicate(true)
		bad.merge(change, true)
		(
			assert_object(StartSetup.from_dictionary(bad, lookup))
			. override_failure_message(str(change))
			. is_null()
		)


## The run save keeps the setup: its originals are the recipe's regulars, a swapped regular is a
## plain product, the offer's shared products are the counted boosters' cards in order, the
## picked pack is offered, and a SELECT setup has an empty offer and waits for its pick.
func test_the_run_save_cross_checks_the_setup() -> void:
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	assert_bool(Kit.swap(run, profile, 0)).is_true()
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var good: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	assert_int(int(good["format_version"])).is_equal(13)
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
	var other_order: Dictionary = good.duplicate(true)
	var swapped: Array = other_order["start_setup"]["boosters"][1]["cards"]
	other_order["start_setup"]["boosters"][1]["cards"] = [swapped[1], swapped[0], swapped[2]]
	assert_object(RunSave.from_dictionary(other_order, lookup)).is_null()
	var picked: Dictionary = good.duplicate(true)
	picked["start_setup"]["picked"] = "not_offered"
	assert_object(RunSave.from_dictionary(picked, lookup)).is_null()
	var select: Dictionary = Kit.json(RunSave.to_dictionary(Kit.run(profile, SEED), "run", 0))
	assert_object(RunSave.from_dictionary(select, lookup)).is_not_null()
	var with_packs: Dictionary = select.duplicate(true)
	with_packs["start_offer"] = good["start_offer"]
	assert_object(RunSave.from_dictionary(with_packs, lookup)).is_null()


## A run waiting for its pick with a setup in an older form (the first build's with no stage,
## v1.07's baskets, a version 12 save) reads with no setup and restarts it; a run past clock-in
## drops it. Nothing is printed.
func test_an_older_setup_restarts_or_is_dropped() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var first_build: Dictionary = {
		"stock_aisles": ["pantry", "household", "cold_cases"],
		"first_aisles": ["pantry", "household", "cold_cases"],
		"first_deal": [],
		"restocks": 0,
		"use_second": false,
		"picked": "",
	}
	var baskets: Dictionary = {
		"stage": "revealed",
		"stock_aisles": ["pantry", "household", "cold_cases"],
		"completed_count": 0,
		"originals": ["banana", "banana", "milk", "eggs"],
		"baskets":
		[
			{"source": "staples", "cards": ["bread", "soup"]},
			{"source": "pantry", "cards": ["cereal", "tea_bags"]},
			{"source": "household", "cards": ["scissors", "batteries"]},
		],
		"restock_basket": -1,
		"restock_source": "",
		"dealt_sets": {},
		"regular_offers": {},
		"packs_redrawn": false,
		"picked": "",
	}
	for old_setup: Dictionary in [first_build, baskets]:
		for version: int in [RunSave.FORMAT_VERSION, RunSave.BEFORE_BOOSTERS_VERSION]:
			assert_bool(StartSetup.is_old_format(old_setup)).is_true()
			assert_object(StartSetup.from_dictionary(old_setup, lookup)).is_null()
			var run: RunState = Kit.locked(Kit.profile(0), SEED)
			var waiting: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
			waiting["start_setup"] = old_setup
			waiting["format_version"] = version
			var read: RunSave = RunSave.from_dictionary(waiting, lookup)
			assert_object(read).override_failure_message(str(version)).is_not_null()
			assert_object(read.run.start_setup).is_null()
			assert_bool(read.run.restart_setup).is_true()
			assert_int(read.run.phase).is_equal(RunState.Phase.CHOOSE_START)
			assert_bool(run.take_pack(run.start_offer.default_pack())).is_true()
			run.start_shift()
			var playing: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
			playing["start_setup"] = old_setup
			playing["format_version"] = version
			var later: RunSave = RunSave.from_dictionary(playing, lookup)
			assert_object(later).is_not_null()
			assert_object(later.run.start_setup).is_null()
			assert_bool(later.run.restart_setup).is_false()


## The profile still reads and writes its saved pair (format unchanged), but no regular swap
## (v1.08: swaps reset each run). A version 4 profile's saved swaps (any form) still read, are
## dropped, and never saved again.
func test_the_profile_keeps_its_saved_pair_but_no_swaps() -> void:
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


## v1.32: the pair is always seeded; the profile's saved pair (stock_pair) is no longer read,
## even with every aisle complete (the choice is PICK 2 OF 3 now).
func test_the_profiles_saved_pair_is_no_longer_read() -> void:
	for seed_value: int in range(SEED, SEED + 10):
		var plain: ProfileState = Kit.profile(6)
		var saved: ProfileState = Kit.profile(6)
		saved.stock_pair = [&"snacks", &"bakery"]
		assert_array(Kit.suggest(saved, seed_value)).is_equal(Kit.suggest(plain, seed_value))


## The setup's telemetry: start_booster_pick (PICK 2 OF 3), restock (one booster), new_packs,
## start_choice's setup fields and run_start's boosters.
func test_the_setup_events() -> void:
	var all: ProfileState = Kit.profile(6)
	var chosen: RunState = Kit.dealt(all, SEED)
	var sold: StringName = chosen.start_setup.boosters[1].aisle
	var picks: Array[int] = [0, 2]
	StartSetupRules.pick_boosters(chosen, all, picks, Kit.pick_rng(chosen))
	var pick: Dictionary = RunEvents.start_booster_pick(chosen, picks)
	assert_array(pick["picked"]).is_equal([0, 2])
	assert_array(pick["sold_out"]).is_equal([String(sold)])
	assert_int(pick["aisles"].size()).is_equal(2)
	assert_array(pick["green"]).is_equal(Array(chosen.start_setup.green_ids(_balance)))
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var kept: Array[CardDefinition] = run.start_setup.boosters[1].cards.duplicate()
	StartSetupRules.restock(run, profile, 1, Kit.restock_rng(run, 1))
	var restock: Dictionary = RunEvents.start_restock(run, 1, kept)
	assert_int(restock["booster"]).is_equal(1)
	assert_str(restock["aisle"]).is_equal(String(run.start_setup.boosters[1].aisle))
	assert_array(restock["before"]).is_equal(RunEvents.definition_ids(kept))
	assert_array(restock["after"]).is_equal(
		RunEvents.definition_ids(run.start_setup.boosters[1].cards)
	)
	assert_int(restock["rare"]).is_equal(run.start_setup.boosters[1].rare_count())
	var fields: Dictionary = RunEvents.start_setup_fields(run)
	assert_int(fields["restock"]).is_equal(1)
	assert_int(fields["restock_booster"]).is_equal(1)
	assert_int(fields["new_packs"]).is_equal(0)
	assert_bool(fields["pins_confirmed"]).is_false()
	assert_int(fields["boosters"].size()).is_equal(2)
	assert_bool(fields["boosters"][1]["restocked"]).is_true()
	assert_dict(RunEvents.new_packs([], [], &"x")).is_equal(
		{"before": [], "after": [], "picked_before": "x"}
	)
	assert_array(RunEvents.run_start(run)["boosters"]).is_equal(fields["boosters"])


func _round_trip(run: RunState, lookup: ContentLookup) -> RunSave:
	return RunSave.from_dictionary(Kit.json(RunSave.to_dictionary(run, "run", 0)), lookup)


## `data`'s boosters with booster `index`'s fields changed by `change`, as a merge into the setup.
static func _booster(data: Dictionary, index: int, change: Dictionary) -> Dictionary:
	var boosters: Array = (data["boosters"] as Array).duplicate(true)
	(boosters[index] as Dictionary).merge(change, true)
	return {"boosters": boosters}


static func _restocked(booster: Dictionary) -> Dictionary:
	return booster.merged({"restocked": true}, true)
