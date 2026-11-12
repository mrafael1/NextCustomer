extends GdUnitTestSuite
## The profile's loyalty perks (v1.30 round 10, the FIGURINE BOOK's PERKS): the highest level
## picked from the machine per perk in runs that ended (ProfileState.perk_levels,
## PerkLevels.picked_levels), the chain lengths, and the saved form (format 7).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"
const DAIRY_REGULARS := "res://data/upgrades/dairy_regulars.tres"
const DAIRY_REGULARS_LV2 := "res://data/upgrades/dairy_regulars_lv2.tres"
const EXTRA_REDRAW := "res://data/upgrades/extra_redraw.tres"
const BANANA_STAND := "res://data/upgrades/banana_stand.tres"
const BIG_BASKET := "res://data/upgrades/big_basket.tres"


func test_picked_levels_take_the_highest_level_per_perk() -> void:
	var first: ShiftRecord = ShiftRecord.new(1, 5, 6)
	first.visits.append(_visit(load(DAIRY_REGULARS)))
	first.visits.append(_visit(null))
	var second: ShiftRecord = ShiftRecord.new(1, 5, 6)
	second.visits.append(_visit(load(DAIRY_REGULARS_LV2)))
	second.visits.append(_visit(load(EXTRA_REDRAW)))
	# A binned visit picked nothing.
	var binned: MachineVisit = _visit(load(BIG_BASKET))
	binned.picked = -1
	binned.binned = true
	second.visits.append(binned)
	var history: Array[ShiftRecord] = [first, second]
	assert_dict(PerkLevels.picked_levels(history)).is_equal(
		{&"dairy_regulars": 2, &"extra_redraw": 1}
	)


func test_a_starting_upgrade_is_not_picked() -> void:
	var deck: DeckDefinition = (load(STARTER) as DeckDefinition).duplicate()
	deck.starting_upgrade = load(BIG_BASKET)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(7, deck, balance, RunStock.starting(balance))
	run.start_shift()
	assert_bool(run.upgrades.has(load(BIG_BASKET))).is_true()
	assert_dict(PerkLevels.picked_levels(run.history)).is_empty()


func test_chain_length() -> void:
	assert_int(PerkLevels.chain_length(load(DAIRY_REGULARS))).is_equal(3)
	assert_int(PerkLevels.chain_length(load(DAIRY_REGULARS_LV2))).is_equal(2)
	assert_int(PerkLevels.chain_length(load(BANANA_STAND))).is_equal(1)
	assert_int(PerkLevels.chain_length(load(BIG_BASKET))).is_equal(1)
	assert_int(PerkLevels.chain_length(null)).is_equal(1)


func test_only_an_ended_run_records_perks() -> void:
	var profile: ProfileState = ProfileState.new()
	var run: RunState = _run(1)
	_check_out(run, [BREAD, REPEAT, BREAD])
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	run.history[-1].visits.append(_visit(load(DAIRY_REGULARS)))
	run.history[-1].visits.append(_visit(load(DAIRY_REGULARS_LV2)))
	profile.record_run(run, CatalogueDefinition.new())
	assert_dict(profile.perk_levels).is_empty()
	MachineSteps.next_shift(run)
	_check_out(run, [REPEAT])
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	profile.record_run(run, CatalogueDefinition.new())
	assert_dict(profile.perk_levels).is_equal({&"dairy_regulars": 2})
	# A later run at a lower level keeps the highest.
	var won: RunState = _won_run(2)
	assert_int(won.phase).is_equal(RunState.Phase.WON)
	won.history[-1].visits.append(_visit(load(DAIRY_REGULARS)))
	won.history[-1].visits.append(_visit(load(BANANA_STAND)))
	profile.record_run(won, CatalogueDefinition.new())
	assert_dict(profile.perk_levels).is_equal({&"dairy_regulars": 2, &"banana_stand": 1})


func test_perk_levels_round_trip_and_format_7() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.perk_levels = {&"dairy_regulars": 3, &"banana_stand": 1}
	var data: Dictionary = profile.to_dictionary()
	assert_int(data["format_version"]).is_equal(7)
	assert_int(ProfileState.FORMAT_VERSION).is_equal(7)
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	var read: ProfileState = ProfileState.from_dictionary(parsed as Dictionary)
	assert_object(read).is_not_null()
	assert_dict(read.perk_levels).is_equal({&"dairy_regulars": 3, &"banana_stand": 1})


func test_a_version_6_profile_reads_with_no_perks() -> void:
	var old: Dictionary = {
		"format_version": 6.0,
		"coins": 3.0,
		"coupon_uses": {"repeat": 2.0},
		"new_figurines": ["baguette"],
	}
	var read: ProfileState = ProfileState.from_dictionary(old)
	assert_object(read).is_not_null()
	assert_dict(read.perk_levels).is_empty()
	assert_dict(read.coupon_uses).is_equal({&"repeat": 2})
	assert_int(read.to_dictionary()["format_version"]).is_equal(ProfileState.FORMAT_VERSION)


func test_unreadable_perk_levels_are_rejected() -> void:
	for bad: Variant in [["dairy_regulars"], {"dairy_regulars": -1.0}, {"dairy_regulars": 1.5}]:
		var data: Dictionary = {"format_version": 7.0, "perk_levels": bad}
		assert_object(ProfileState.from_dictionary(data)).is_null()


## A machine visit that picked a REGISTER prize of `perk` (or nothing picked when null).
static func _visit(perk: UpgradeDefinition) -> MachineVisit:
	var visit: MachineVisit = MachineVisit.new()
	visit.chute = 1
	if perk == null:
		return visit
	visit.prizes.append(MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, perk))
	visit.picked = 0
	return visit


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
