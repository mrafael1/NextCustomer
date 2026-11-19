extends GdUnitTestSuite
## The opening-time setup's saved forms and telemetry (StartSetup, RunSave, ProfileState, RunEvents;
## full build plan 7.2, v1.32 "boosters", run save format 15): a resume restores every booster,
## choice, swap booster (offered and opened) and spent action; damaged setups are refused; the run
## save cross-checks the setup; a setup in an older form (the first build's, v1.07's baskets,
## version 12, 13 and 14 saves) restarts (or is dropped past clock-in); a version 17 save (before
## the Dairy aisle, v1.44) reads with its aisle ids renamed; the profile's saved pair; the setup
## events. On the live data; nothing here touches a save file.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261104

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = Kit.balance()
	_recipe = Kit.recipe()


## A resume restores every choice exactly: the stage, the boosters (sealed or opened, RESTOCKED),
## the pins step, the regular offers and the swapped regulars, in
## SELECT, DEALT and BUILD.
func test_a_resume_restores_the_boosters_choices_and_spent_actions() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var profile: ProfileState = Kit.profile(3)
	var waiting: RunState = Kit.run(profile, SEED)
	var read: RunSave = _round_trip(waiting, lookup)
	assert_object(read).is_not_null()
	assert_dict(read.run.start_setup.to_dictionary()).is_equal(waiting.start_setup.to_dictionary())
	assert_array(read.run.start_offer.shared).is_empty()
	var sealed: RunState = Kit.dealt(profile, SEED)
	var resumed: RunSave = _round_trip(sealed, lookup)
	assert_object(resumed).is_not_null()
	assert_bool(resumed.run.start_setup.boosters[0].opened).is_false()
	assert_str(String(StartSetupRules.open_booster(resumed.run, 0))).is_empty()
	var run: RunState = Kit.locked(profile, SEED)
	Kit.swap_offers(run, profile)
	var opened: StringName = StartSwapBoosters.swap_aisles(run)[1]
	assert_str(String(StartSwapBoosters.open_swap_booster(run, profile, opened))).is_empty()
	assert_bool(Kit.swap(run, profile, 1)).is_true()
	StartSetupRules.restock(run, profile, 1, Kit.restock_rng(run, 1))
	StartSetupRules.open_booster(run, 1)
	StartSetupRules.confirm_pins(run)
	StartSetupRules.mark_build(run)
	var saved: RunSave = _round_trip(run, lookup)
	assert_object(saved).is_not_null()
	var setup: StartSetup = saved.run.start_setup
	assert_dict(setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	assert_int(setup.stage).is_equal(StartSetup.Stage.BUILD)
	assert_int(setup.restock_booster()).is_equal(1)
	assert_bool(setup.boosters[1].opened).is_true()
	assert_bool(setup.pins_confirmed).is_true()
	for aisle_id: StringName in StartSwapBoosters.swap_aisles(run):
		assert_array(setup.swap_offer(aisle_id)).is_equal(run.start_setup.swap_offer(aisle_id))
	assert_array(setup.swap_opened).contains_exactly([opened])
	assert_array(saved.run.start_offer.shared).is_equal(run.start_offer.shared)
	assert_array(saved.run.starter.core_cards).is_equal(run.starter.core_cards)
	assert_str(String(StartSetupRules.restock_block(saved.run, profile, 0))).is_equal("used")


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
	var stocked: String = String(run.start_setup.stock_aisles[0])
	var first: Dictionary = good["boosters"][0]
	var cards: Array = first["cards"]
	var table: Array[ItemUpgradeDefinition] = _balance.machine.item_upgrades
	var plain: CardDefinition = run.start_setup.boosters[0].cards[0]
	var chain: ItemUpgradeDefinition = ItemUpgrades.chain_for(table, plain)
	var other_aisle: Variant = good["boosters"][1]["aisle"]
	# A third stocked aisle (version 13's form) is refused: a run stocks only its boosters' two.
	var third: String = ""
	for aisle: AisleDefinition in _balance.aisles:
		if not (good["stock_aisles"] as Array).has(String(aisle.id)) and third == "":
			third = String(aisle.id)
	for change: Dictionary in [
		{"stage": "done"},
		{"stage": "revealed"},
		{"stock_aisles": []},
		{"stock_aisles": ["pantry", "pantry"]},
		{"stock_aisles": ["pantry", "unknown"]},
		{"stock_aisles": (good["stock_aisles"] as Array) + [third]},
		{"completed_count": 99},
		{"pins_confirmed": "yes"},
		{"boosters": []},
		{"boosters": "x"},
		_booster(good, 0, {"aisle": other_aisle}),
		_booster(good, 0, {"aisle": third}),
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
		{"swap_offers": {third: [String(plain.id)]}},
		{"swap_offers": {stocked: ["two_for_one"]}},
		{"swap_offers": {stocked: [cards[0], cards[0]]}},
		{"swap_offers": {stocked: [String(chain.big.id)]}},
		{"swap_offers": {stocked: [_other_aisle_card(stocked)]}},
		{"swap_offers": {stocked: _four_of(stocked)}},
		{"swap_offers": []},
		{"swap_opened": [stocked]},
		{"swap_opened": "x"},
		{"originals": "milk"},
	]:
		var bad: Dictionary = good.duplicate(true)
		bad.merge(change, true)
		(
			assert_object(StartSetup.from_dictionary(bad, lookup))
			. override_failure_message(str(change))
			. is_null()
		)
	# SELECT holds nothing dealt or spent.
	var select: Dictionary = Kit.json(Kit.run(Kit.profile(3), SEED).start_setup.to_dictionary())
	assert_object(StartSetup.from_dictionary(select, lookup)).is_not_null()
	for change: Dictionary in [{"pins_confirmed": true}, {"boosters": good["boosters"]}]:
		var bad: Dictionary = select.duplicate(true)
		bad.merge(change, true)
		assert_object(StartSetup.from_dictionary(bad, lookup)).is_null()


## A setup saved before v1.46 with PICK 2 OF 3's third booster loads without it: still picking,
## the seeded pair stays today's; once picked, the SOLD OUT booster is dropped and the picked pair
## kept. A SOLD OUT booster opened or restocked is still refused.
func test_an_old_pick_loads_without_its_third_booster() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var dealt: Dictionary = Kit.json(Kit.dealt(Kit.profile(6), SEED).start_setup.to_dictionary())
	var green: Array = dealt["stock_aisles"]
	var third: AisleDefinition = null
	for aisle: AisleDefinition in _balance.aisles:
		if third == null and not green.has(String(aisle.id)):
			third = aisle
	var extra: Dictionary = {
		"aisle": String(third.id),
		"cards": _plain_ids(third, _balance.start_booster_size),
		"hits": 0,
		"opened": false,
		"sold_out": false,
		"restocked": false,
	}
	var picking: Dictionary = dealt.duplicate(true)
	(picking["boosters"] as Array).append(extra.duplicate())
	var still: StartSetup = StartSetup.from_dictionary(picking, lookup)
	assert_object(still).is_not_null()
	assert_dict(Kit.json(still.to_dictionary())).is_equal(dealt)
	# Picked: the first seeded aisle and the third one kept, the second SOLD OUT.
	var picked: Dictionary = dealt.duplicate(true)
	var kept: Array[StringName] = [StringName(green[0]), third.id]
	var kept_ids: Array[String] = []
	for id: StringName in StartSetupRules.ordered_pair(_balance, kept):
		kept_ids.append(String(id))
	picked["stock_aisles"] = kept_ids
	(picked["boosters"][1] as Dictionary)["sold_out"] = true
	(picked["boosters"] as Array).append(extra.duplicate())
	var resolved: StartSetup = StartSetup.from_dictionary(picked, lookup)
	assert_object(resolved).is_not_null()
	assert_int(resolved.boosters.size()).is_equal(2)
	assert_str(String(resolved.boosters[0].aisle)).is_equal(String(green[0]))
	assert_str(String(resolved.boosters[1].aisle)).is_equal(String(third.id))
	assert_array(resolved.stock_aisles).is_equal(StartSetupRules.ordered_pair(_balance, kept))
	for change: Dictionary in [{"opened": true}, {"restocked": true}]:
		var bad: Dictionary = picked.duplicate(true)
		(bad["boosters"][1] as Dictionary).merge(change, true)
		(
			assert_object(StartSetup.from_dictionary(bad, lookup))
			. override_failure_message(str(change))
			. is_null()
		)


## The run save keeps the setup: its originals are the recipe's regulars, a swapped regular is a
## plain product, the offer's shared products are the counted boosters' cards in order, and a
## SELECT setup has an empty offer.
func test_the_run_save_cross_checks_the_setup() -> void:
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	assert_bool(Kit.swap(run, profile, 0)).is_true()
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var good: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	assert_int(int(good["format_version"])).is_equal(19)
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
	var select: Dictionary = Kit.json(RunSave.to_dictionary(Kit.run(profile, SEED), "run", 0))
	assert_object(RunSave.from_dictionary(select, lookup)).is_not_null()
	var dealt_offer: Dictionary = select.duplicate(true)
	dealt_offer["start_setup"] = good["start_setup"]
	dealt_offer["start_setup"]["stage"] = "select"
	assert_object(RunSave.from_dictionary(dealt_offer, lookup)).is_null()


## A version 18 save (v1.44, before v1.45 removed the starter pack choice) still reads: a run
## waiting on the board with a pick and NEW PACKS saved reads with both ignored, its offer's packs
## dropped; a run past clock-in that took a pack (`start_pack`, its cards in the saved deck) reads
## with its deck as saved. Saved again, neither field is written.
func test_a_version_18_save_with_a_starter_pack_reads() -> void:
	assert_int(RunSave.BEFORE_NO_PACKS_VERSION).is_equal(18)
	assert_bool(RunSave.READ_VERSIONS.has(RunSave.BEFORE_NO_PACKS_VERSION)).is_true()
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	var good: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	var waiting: Dictionary = good.duplicate(true)
	waiting["format_version"] = RunSave.BEFORE_NO_PACKS_VERSION
	waiting["start_setup"]["picked"] = "breakfast_run"
	waiting["start_setup"]["packs_redrawn"] = true
	waiting["start_offer"]["packs"] = ["breakfast_run", "deli_counter", "banana_bunch"]
	waiting["start_offer"]["first_pick"] = "breakfast_run"
	waiting["start_pack"] = ""
	var read: RunSave = RunSave.from_dictionary(waiting, lookup)
	assert_object(read).is_not_null()
	assert_int(read.run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_dict(read.run.start_setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	assert_dict(Kit.json(RunSave.to_dictionary(read.run, "run", 0))).is_equal(good)
	assert_bool(run.open_store()).is_true()
	run.start_shift()
	var playing: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	assert_bool(playing.has("start_pack")).is_false()
	var old: Dictionary = playing.duplicate(true)
	old["format_version"] = RunSave.BEFORE_NO_PACKS_VERSION
	old["start_pack"] = "breakfast_run"
	var milk: String = String(_recipe.core_cards[2].id)
	old["starting_deck"].insert(_recipe.core_cards.size(), milk)
	var later: RunSave = RunSave.from_dictionary(old, lookup)
	assert_object(later).is_not_null()
	assert_int(later.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(later.run.starter.cards.size()).is_equal(run.starter.cards.size() + 1)


## A run waiting for its pick with a setup in an older form (the first build's with no stage,
## v1.07's baskets, a version 12 save) reads with no setup and restarts it; a run past clock-in
## drops it. Nothing is printed.
func test_an_older_setup_restarts_or_is_dropped() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var first_build: Dictionary = {
		"stock_aisles": ["pantry", "household", "dairy"],
		"first_aisles": ["pantry", "household", "dairy"],
		"first_deal": [],
		"restocks": 0,
		"use_second": false,
		"picked": "",
	}
	var baskets: Dictionary = {
		"stage": "revealed",
		"stock_aisles": ["pantry", "household", "dairy"],
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
			assert_bool(run.open_store()).is_true()
			run.start_shift()
			var playing: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
			playing["start_setup"] = old_setup
			playing["format_version"] = version
			var later: RunSave = RunSave.from_dictionary(playing, lookup)
			assert_object(later).is_not_null()
			assert_object(later.run.start_setup).is_null()
			assert_bool(later.run.restart_setup).is_false()


## A version 14 save (v1.32 before the swap window: an offer per regular slot and aisle) reads as
## it is; its setup is an older form: a run waiting for its pick restarts it, a run past clock-in
## drops it. Nothing is printed.
func test_a_version_14_setup_restarts_or_is_dropped() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = Kit.locked(Kit.profile(1), SEED)
	var setup: Dictionary = Kit.json(run.start_setup.to_dictionary())
	setup.erase("swap_offers")
	setup.erase("swap_opened")
	setup["regular_offers"] = {}
	var waiting: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	waiting["start_setup"] = setup
	waiting["format_version"] = RunSave.BEFORE_SWAP_WINDOW_VERSION
	var read: RunSave = RunSave.from_dictionary(waiting, lookup)
	assert_object(read).is_not_null()
	assert_object(read.run.start_setup).is_null()
	assert_bool(read.run.restart_setup).is_true()
	# The same setup saved as version 15 or later is refused: it has no swap boosters.
	waiting["format_version"] = RunSave.FORMAT_VERSION
	assert_object(RunSave.from_dictionary(waiting, lookup)).is_null()
	assert_bool(run.open_store()).is_true()
	run.start_shift()
	var playing: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	playing["start_setup"] = setup
	playing["format_version"] = RunSave.BEFORE_SWAP_WINDOW_VERSION
	var later: RunSave = RunSave.from_dictionary(playing, lookup)
	assert_object(later).is_not_null()
	assert_object(later.run.start_setup).is_null()
	assert_bool(later.run.restart_setup).is_false()


## A version 13 save (v1.32 before the 2026-11-13 feedback: a third stocked aisle) reads as it
## is, its stock as saved; its setup is an older form: a run waiting for its pick restarts it, a
## run past clock-in drops it. Nothing is printed.
func test_a_version_13_setup_restarts_or_is_dropped() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = Kit.locked(Kit.profile(0), SEED)
	var setup: Dictionary = Kit.json(run.start_setup.to_dictionary())
	for aisle: AisleDefinition in _balance.aisles:
		if not run.start_setup.stock_aisles.has(aisle.id):
			setup["stock_aisles"].append(String(aisle.id))
			break
	var waiting: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	waiting["start_setup"] = setup
	waiting["format_version"] = RunSave.BEFORE_TWO_AISLES_VERSION
	var read: RunSave = RunSave.from_dictionary(waiting, lookup)
	assert_object(read).is_not_null()
	assert_object(read.run.start_setup).is_null()
	assert_bool(read.run.restart_setup).is_true()
	# The same setup saved as version 15 or later is refused: three stocked aisles never validate
	# now.
	waiting["format_version"] = RunSave.FORMAT_VERSION
	assert_object(RunSave.from_dictionary(waiting, lookup)).is_null()
	assert_bool(run.open_store()).is_true()
	run.start_shift()
	var playing: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	playing["start_setup"] = setup
	playing["format_version"] = RunSave.BEFORE_TWO_AISLES_VERSION
	var later: RunSave = RunSave.from_dictionary(playing, lookup)
	assert_object(later).is_not_null()
	assert_object(later.run.start_setup).is_null()
	assert_bool(later.run.restart_setup).is_false()
	assert_array(later.run.stock.cards).is_equal(run.stock.cards)


## A version 17 save (before the Dairy aisle, v1.44: the aisle's id was `cold_cases`) reads with
## the id renamed everywhere: the listed aisles, the setup's stocked aisles, boosters and swap
## offers. It restores the same run as today's save, at the pick and past clock-in; the old id
## in a version 18 save names no aisle and is refused.
func test_a_version_17_save_reads_with_the_dairy_aisle() -> void:
	assert_int(RunSave.BEFORE_DAIRY_VERSION).is_equal(17)
	assert_bool(RunSave.READ_VERSIONS.has(RunSave.BEFORE_DAIRY_VERSION)).is_true()
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = _dairy_run(profile)
	Kit.swap_offers(run, profile)
	var good: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	var old: Dictionary = _before_dairy(good, false)
	assert_bool((old["listed_aisles"] as Array).has("cold_cases")).is_true()
	assert_bool((old["start_setup"]["stock_aisles"] as Array).has("cold_cases")).is_true()
	assert_bool((old["start_setup"]["swap_offers"] as Dictionary).has("cold_cases")).is_true()
	assert_bool(JSON.stringify(old).contains('"dairy"')).is_false()
	var read: RunSave = RunSave.from_dictionary(old, lookup)
	assert_object(read).is_not_null()
	assert_bool(read.run.restart_setup).is_false()
	assert_array(read.run.stock.aisle_ids).is_equal(run.stock.aisle_ids)
	assert_bool(read.run.stock.aisle_ids.has(&"dairy")).is_true()
	assert_array(read.run.start_setup.stock_aisles).is_equal(run.start_setup.stock_aisles)
	assert_dict(read.run.start_setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	# Saved again, it is today's save.
	assert_dict(Kit.json(RunSave.to_dictionary(read.run, "run", 0))).is_equal(good)
	var unrenamed: Dictionary = old.duplicate(true)
	unrenamed["format_version"] = RunSave.FORMAT_VERSION
	assert_object(RunSave.from_dictionary(unrenamed, lookup)).is_null()
	assert_bool(run.open_store()).is_true()
	run.start_shift()
	var playing: Dictionary = Kit.json(RunSave.to_dictionary(run, "run", 0))
	var later: RunSave = RunSave.from_dictionary(_before_dairy(playing, false), lookup)
	assert_object(later).is_not_null()
	assert_dict(later.run.start_setup.to_dictionary()).is_equal(run.start_setup.to_dictionary())
	assert_dict(Kit.json(RunSave.to_dictionary(later.run, "run", 0))).is_equal(playing)


## A version 17 save whose Cold cases booster holds Frozen peas (a base product of the aisle
## then, a Fruit & veg capsule item now) no longer reads as a setup: a run still waiting for its
## pick restarts its setup instead of being refused, and a run past clock-in drops the setup and
## keeps its cards (Frozen peas with them). The same save as version 18 is refused.
func test_a_version_17_setup_with_frozen_peas_restarts_or_is_dropped() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = _dairy_run(profile)
	var waiting: Dictionary = _before_dairy(Kit.json(RunSave.to_dictionary(run, "run", 0)), true)
	assert_bool((waiting["starting_deck"] as Array).has("frozen_peas")).is_true()
	# The setup itself no longer reads: Frozen peas is no product of the Dairy aisle.
	var setup: Dictionary = AisleRename.renamed(waiting["start_setup"])
	assert_object(StartSetup.from_dictionary(setup, lookup)).is_null()
	var read: RunSave = RunSave.from_dictionary(waiting, lookup)
	assert_object(read).is_not_null()
	assert_int(read.run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_object(read.run.start_setup).is_null()
	assert_bool(read.run.restart_setup).is_true()
	var newer: Dictionary = AisleRename.renamed(waiting)
	newer["format_version"] = RunSave.FORMAT_VERSION
	assert_object(RunSave.from_dictionary(newer, lookup)).is_null()
	assert_bool(run.open_store()).is_true()
	run.start_shift()
	var playing: Dictionary = _before_dairy(Kit.json(RunSave.to_dictionary(run, "run", 0)), true)
	var later: RunSave = RunSave.from_dictionary(playing, lookup)
	assert_object(later).is_not_null()
	assert_int(later.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_object(later.run.start_setup).is_null()
	assert_bool(later.run.restart_setup).is_false()
	var peas: Array = later.run.deck.cards.filter(
		func(card: CardInstance) -> bool: return card.definition.id == &"frozen_peas"
	)
	assert_int(peas.size()).is_equal(1)
	assert_int(later.run.deck.cards.size()).is_equal(run.deck.cards.size())


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
## even with every aisle complete.
func test_the_profiles_saved_pair_is_no_longer_read() -> void:
	for seed_value: int in range(SEED, SEED + 10):
		var plain: ProfileState = Kit.profile(6)
		var saved: ProfileState = Kit.profile(6)
		saved.stock_pair = [&"snacks", &"bakery"]
		assert_array(Kit.suggest(saved, seed_value)).is_equal(Kit.suggest(plain, seed_value))


## The setup's telemetry: restock (one booster), start_choice's setup fields and run_start's
## boosters.
func test_the_setup_events() -> void:
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
	assert_bool(fields.has("new_packs")).is_false()
	assert_bool(fields["pins_confirmed"]).is_false()
	assert_int(fields["boosters"].size()).is_equal(2)
	assert_bool(fields["boosters"][1]["restocked"]).is_true()
	assert_array(RunEvents.run_start(run)["boosters"]).is_equal(fields["boosters"])


func _round_trip(run: RunState, lookup: ContentLookup) -> RunSave:
	return RunSave.from_dictionary(Kit.json(RunSave.to_dictionary(run, "run", 0)), lookup)


## A run dealt with every booster opened whose stocked aisles hold the
## Dairy aisle: the first seed from SEED that stocks it.
func _dairy_run(profile: ProfileState) -> RunState:
	for seed_value: int in range(SEED, SEED + 50):
		var run: RunState = Kit.locked(profile, seed_value)
		if run != null and run.start_setup.stock_aisles.has(&"dairy"):
			return run
	return null


## `save` (today's save, as parsed from JSON) as version 17 wrote it: the Dairy aisle under its
## old id and, with `peas`, Frozen peas in place of the first card of the aisle's booster (in the
## booster and in the run's cards: its starting deck, deck and hand).
static func _before_dairy(save: Dictionary, peas: bool) -> Dictionary:
	var text: String = JSON.stringify(save).replace('"dairy"', '"cold_cases"')
	var old: Dictionary = JSON.parse_string(text)
	old["format_version"] = RunSave.BEFORE_DAIRY_VERSION
	if not peas:
		return old
	for booster: Dictionary in old["start_setup"]["boosters"]:
		if booster["aisle"] != "cold_cases":
			continue
		var was: String = booster["cards"][0]
		booster["cards"][0] = "frozen_peas"
		# The boosters' cards are the starting deck's last ones, in the deck in the same order.
		var starting: Array = old["starting_deck"]
		var at: int = starting.rfind(was)
		starting[at] = "frozen_peas"
		var instance: Array = old["deck"][at]
		instance[1] = "frozen_peas"
		for held: Array in old["hand"]:
			if held[0] == instance[0]:
				held[1] = "frozen_peas"
	return old


## `data`'s boosters with booster `index`'s fields changed by `change`, as a merge into the setup.
static func _booster(data: Dictionary, index: int, change: Dictionary) -> Dictionary:
	var boosters: Array = (data["boosters"] as Array).duplicate(true)
	(boosters[index] as Dictionary).merge(change, true)
	return {"boosters": boosters}


static func _restocked(booster: Dictionary) -> Dictionary:
	return booster.merged({"restocked": true}, true)


## A plain product of an aisle other than `aisle_id` (its id).
func _other_aisle_card(aisle_id: String) -> String:
	for aisle: AisleDefinition in _balance.aisles:
		if String(aisle.id) != aisle_id and not aisle.base_cards.is_empty():
			return String(aisle.base_cards[0].id)
	return ""


## Up to `count` distinct plain-tier products of `aisle`, as ids.
static func _plain_ids(aisle: AisleDefinition, count: int) -> Array[String]:
	var ids: Array[String] = []
	for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
		var plain: bool = card.is_product() and card.tier == CardDefinition.Tier.PLAIN
		if plain and card.variant_of == null and ids.size() < count:
			ids.append(String(card.id))
	return ids


## Four distinct plain products of aisle `aisle_id` (one more than regular_offer_max), as ids.
func _four_of(aisle_id: String) -> Array[String]:
	var ids: Array[String] = []
	for aisle: AisleDefinition in _balance.aisles:
		if String(aisle.id) == aisle_id:
			for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
				if card.variant_of == null and ids.size() < _balance.regular_offer_max + 1:
					ids.append(String(card.id))
	return ids
