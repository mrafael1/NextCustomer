extends GdUnitTestSuite
## A run stocks only its boosters' two aisles (v1.32 feedback, 2026-11-13; full build plan 7.2):
## dealt or picked at PICK 2 OF 3, the setup's stock, the run stock and the RECEIPT REWARDS
## machine's NEW ITEMS hold no third aisle's product. On the live data, with the named derived
## streams the game uses; nothing here touches a save file.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261104

var _balance: BalanceDefinition


func before_test() -> void:
	_balance = Kit.balance()


## v1.32 feedback (2026-11-13): a run stocks exactly its two boosters' aisles, dealt (any
## completed count below PICK 2 OF 3) or picked (each pair of PICK 2 OF 3): the setup's stock, the
## run stock's aisles and its products (staples aside) are those two aisles' only.
func test_the_run_stocks_only_its_two_booster_aisles() -> void:
	for completed: int in [0, 3, 6]:
		for seed_value: int in range(SEED, SEED + 3):
			var pairs: Array = [[]] if completed < 6 else [[0, 1], [0, 2], [1, 2]]
			for pair: Array in pairs:
				var profile: ProfileState = Kit.profile(completed)
				var run: RunState = Kit.dealt(profile, seed_value)
				if not pair.is_empty():
					var picks: Array[int] = []
					picks.assign(pair)
					StartSetupRules.pick_boosters(run, profile, picks, Kit.pick_rng(run))
				var aisles: Array[StringName] = []
				for booster: StartBooster in run.start_setup.active_boosters():
					aisles.append(booster.aisle)
				var label: String = "%d %d %s" % [completed, seed_value, str(pair)]
				assert_int(aisles.size()).override_failure_message(label).is_equal(2)
				assert_array(run.start_setup.stock_aisles).is_equal(
					StartSetupRules.ordered_pair(_balance, aisles)
				)
				assert_array(run.stock.aisle_ids).is_equal(run.start_setup.stock_aisles)
				_assert_stock_of(run, aisles, label)


## No product of a third aisle reaches the RECEIPT REWARDS machine: NEW ITEMS' pools (every tier)
## hold only staples and the two stocked aisles' products.
func test_the_machine_never_offers_a_third_aisles_product() -> void:
	for completed: int in [0, 3, 6]:
		var profile: ProfileState = Kit.profile(completed)
		var run: RunState = Kit.locked(profile, SEED)
		var context: MachineContext = MachineContext.from_run(run, _balance.machine, false)
		var allowed: Array[CardDefinition] = _allowed(run, profile)
		var seen: int = 0
		for tier: Array in MachineDraw.pools(RewardMachine.Chute.NEW_ITEMS, context):
			for prize: MachinePrize in tier:
				if prize.kind != MachinePrize.Kind.PRODUCT:
					continue
				seen += 1
				var plain: CardDefinition = prize.card.product_card()
				assert_bool(allowed.has(plain)).override_failure_message(String(plain.id)).is_true()
		assert_int(seen).is_greater(0)


## v1.32 (the user, 2026-11-13): a capsule item unlocked at the end of the run just before, from an
## aisle this run doesn't stock, never reaches the run: not in its stock, and not in any NEW ITEMS
## draw, the first (whose coupon is the first offer's; it once held such a "new arrival") or a
## later one, CLASSIC or PREMIUM, at any odds level. The end-cap is gone.
func test_a_just_unlocked_item_of_another_aisle_never_reaches_the_run() -> void:
	for completed: int in [0, 3, 6]:
		for seed_value: int in range(SEED, SEED + 3):
			var profile: ProfileState = Kit.profile(completed)
			profile.run_count = 4
			# Every aisle's next locked capsule item comes out at the end of run index 3.
			for aisle: AisleDefinition in _balance.aisles:
				for card: CardDefinition in aisle.capsule_cards:
					if not profile.unlocked_items.has(card.id):
						profile.unlocked_items[card.id] = profile.capsule_run_index(false)
						break
			var run: RunState = Kit.locked(profile, seed_value)
			var label: String = "%d %d" % [completed, seed_value]
			assert_object(run).override_failure_message(label).is_not_null()
			var stocked: Array[StringName] = run.start_setup.stock_aisles
			assert_int(stocked.size()).override_failure_message(label).is_equal(2)
			_assert_stock_of(run, stocked, label)
			var allowed: Array[CardDefinition] = _allowed(run, profile)
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = seed_value
			for first_done: bool in [false, true]:
				for premium: bool in [false, true]:
					var context: MachineContext = MachineContext.from_run(
						run, _balance.machine, first_done, premium
					)
					for draw: int in 40:
						for prize: MachinePrize in MachineDraw.draw(
							RewardMachine.Chute.NEW_ITEMS, context, draw % 4, rng
						):
							if prize.kind != MachinePrize.Kind.PRODUCT:
								continue
							var plain: CardDefinition = prize.card.product_card()
							(
								assert_bool(allowed.has(plain))
								. override_failure_message("%s: %s" % [label, plain.id])
								. is_true()
							)


## The products a run's machine may offer: the staples and its stocked aisles' items (base cards
## and the profile's unlocked capsule cards only, so a still-locked item would fail too).
func _allowed(run: RunState, profile: ProfileState) -> Array[CardDefinition]:
	var allowed: Array[CardDefinition] = RunStock.staples(_balance)
	for aisle: AisleDefinition in _balance.aisles:
		if run.start_setup.stock_aisles.has(aisle.id):
			allowed.append_array(RunStock.items(aisle, profile.unlocked_items))
	return allowed


func _assert_stock_of(run: RunState, aisles: Array[StringName], label: String) -> void:
	var staples: Array[CardDefinition] = RunStock.staples(_balance)
	for card: CardDefinition in run.stock.cards:
		if not card.is_product() or staples.has(card):
			continue
		var home: AisleDefinition = _balance.aisle_of(card)
		(
			assert_bool(home != null and aisles.has(home.id))
			. override_failure_message("%s: %s" % [label, card.id])
			. is_true()
		)
