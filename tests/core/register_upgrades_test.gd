extends GdUnitTestSuite
## The register upgrades of issue #38 (plan section 3.8, v0.24): the shift limits they change
## (ShiftLimits: slots, redraws, Big basket's raised quota), Rule bender's links, Slot engine's
## 6th product, the builds an upgrade supports and the offer's "fits the deck" guarantee.
## Scoring rows use the frozen fixtures, upgrades built here from their rule scripts.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"
const FINAL_MARKDOWN := "res://data/cards/final_markdown.tres"
const UPGRADES := "res://data/upgrades/%s.tres"
const BUILDS := "res://data/builds/%s.tres"
const FIXTURE_V0_4 := "res://tests/fixtures/cards_v0_4/%s.tres"
const FIXTURE_V0_5 := "res://tests/fixtures/cards_v0_5/%s.tres"


func test_limits_default_to_the_balance_data() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, _none(), 2)
	assert_int(limits.slot_count).is_equal(balance.slot_count)
	assert_int(limits.coupon_slot_count).is_equal(balance.coupon_slot_count)
	assert_int(limits.redraws).is_equal(RunState.BASE_REDRAWS)
	assert_int(limits.quota).is_equal(balance.quotas[2])
	assert_int(limits.card_limit()).is_equal(balance.slot_count + balance.coupon_slot_count)


func test_upgrades_add_slots_and_redraws() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var owned: Array[UpgradeDefinition] = [
		_upgrade("extra_redraw"), _upgrade("extra_coupon_slot"), _upgrade("big_basket")
	]
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, owned, 0)
	assert_int(limits.slot_count).is_equal(balance.slot_count + 1)
	assert_int(limits.coupon_slot_count).is_equal(balance.coupon_slot_count + 1)
	assert_int(limits.redraws).is_equal(RunState.BASE_REDRAWS + 1)
	assert_int(limits.card_limit()).is_equal(9)


## Big basket: +15%, rounded up to whole euros, on every shift's quota.
func test_big_basket_raises_every_quota_rounded_up() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var owned: Array[UpgradeDefinition] = [_upgrade("big_basket")]
	var raised: Array = []
	for shift: int in range(balance.quotas.size()):
		raised.append(ShiftLimits.for_shift(balance, owned, shift).quota)
	assert_array(Array(balance.quotas)).is_equal([41, 42, 65, 77, 87, 123, 124, 149])
	assert_array(raised).is_equal([48, 49, 75, 89, 101, 142, 143, 172])
	assert_int(ShiftLimits.raised_quota(20, 15)).is_equal(23)
	assert_int(ShiftLimits.raised_quota(17, 0)).is_equal(17)


## The quota is fixed when the shift starts: Big basket picked after shift 2 leaves shift 2's
## record, pass and quota alone and raises shift 3's.
func test_the_quota_is_fixed_for_the_shift() -> void:
	var run: RunState = _run(41)
	run.debug_skip_to_shift(1)
	_pass(run)
	run.skip_reward()
	var basket: UpgradeDefinition = _upgrade("big_basket")
	run.upgrade_offer = [basket]
	assert_bool(run.pick_upgrade(basket)).is_true()
	assert_int(run.quota()).is_equal(run.balance.quotas[1])
	assert_int(run.history[-1].quota).is_equal(run.balance.quotas[1])
	assert_bool(run.passed()).is_true()
	assert_bool(run.next_shift()).is_true()
	assert_int(run.quota()).is_equal(ShiftLimits.raised_quota(run.balance.quotas[2], 15))
	assert_int(run.limits.slot_count).is_equal(run.balance.slot_count + 1)


## Big basket's 7th product fits; Extra coupon slot's second coupon fits as a coupon only.
func test_extra_slots_reach_the_row() -> void:
	var run: RunState = _run(42)
	for index: int in range(6):
		run.place(run.debug_add_to_hand(load(BREAD)), index)
	assert_bool(run.can_place(run.debug_add_to_hand(load(BREAD)))).is_false()
	run.upgrades.append(_upgrade("big_basket"))
	run.upgrades.append(_upgrade("extra_coupon_slot"))
	run.debug_skip_to_shift(run.shift_index)
	for index: int in range(7):
		assert_bool(run.place(run.debug_add_to_hand(load(BREAD)), index)).is_true()
	assert_bool(run.can_place(run.debug_add_to_hand(load(BREAD)))).is_false()
	assert_bool(run.place(run.debug_add_to_hand(load(REPEAT)), 7)).is_true()
	assert_bool(run.place(run.debug_add_to_hand(load(FINAL_MARKDOWN)), 8)).is_true()
	assert_int(run.row.size()).is_equal(9)
	assert_int(RowCapacity.coupon_slots_used(run.limits, run.row)).is_equal(2)
	assert_bool(run.can_place(run.debug_add_to_hand(load(REPEAT)))).is_false()


## A run saved with the extra slots in use resumes with the same limits and row.
func test_a_resumed_run_keeps_its_limits() -> void:
	var run: RunState = _run(43)
	run.upgrades.append(_upgrade("big_basket"))
	run.debug_skip_to_shift(2)
	for index: int in range(7):
		run.place(run.debug_add_to_hand(load(BREAD)), index)
	var lookup: ContentLookup = ContentLookup.new(run.balance)
	var data: Dictionary = JSON.parse_string(
		JSON.stringify(RunSave.to_dictionary(run, "0011223344556677", 1000))
	)
	var restored: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(restored).is_not_null()
	assert_int(restored.run.row.size()).is_equal(7)
	assert_int(restored.run.quota()).is_equal(run.quota())
	assert_int(restored.run.limits.slot_count).is_equal(run.limits.slot_count)


## Rule bender: coupons no longer break adjacency (the last product before a run of coupons and
## the first after it), hazards included, without linking a pair twice.
func test_rule_bender_rows(
	row: String,
	payouts: Array,
	links: int,
	_test_parameters := [
		# Banana's pair through Multipack: 2, then (2 + 2) x2.
		["v4:banana,multipack,banana", [2, 0, 8], 1],
		# 2 for 1 already links Banana to Banana: no second link.
		["v5:banana,two_for_one,banana", [2, 0, 8], 1],
		# Different products: 2 for 1 fizzles, but Cheese still counts as after Bread.
		["v5:bread,two_for_one,cheese", [3, 0, 7], 1],
		# Soup now counts as beside Frozen peas through Repeat: it pays 0.
		["v4:frozen_peas,repeat,soup", [3, 3, 0], 1],
		# Two coupons in a row bridge as one.
		["v4:banana,repeat,final_markdown,banana", [2, 2, 0, 4], 1],
		# Nothing to bridge: no step.
		["v4:banana,banana,repeat", [2, 4, 4], 0],
	]
) -> void:
	var bender: UpgradeDefinition = _built_upgrade(CouponBridgeRule.new())
	var result: ScoreResult = Scoring.score(_row(row), [bender])
	assert_array(Array(result.payouts)).override_failure_message(row).is_equal(payouts)
	var upgrade_links: Array[ScoreStep] = _steps(
		result, ScoreStep.StepType.LINKED, ScoreStep.SourceKind.UPGRADE
	)
	var card_links: Array[ScoreStep] = _steps(
		result, ScoreStep.StepType.LINKED, ScoreStep.SourceKind.CARD
	)
	assert_int(upgrade_links.size()).override_failure_message(row).is_equal(
		links - card_links.size()
	)
	for step: ScoreStep in upgrade_links:
		assert_int(step.source_index).is_equal(0)
		assert_str(step.text).is_equal("Test upgrade")


## Slot engine: the 6th product (coupons skipped) pays x2, and a later Repeat copies the doubled
## payout. With fewer than 6 products it does nothing.
func test_slot_engine_rows(
	row: String,
	total: int,
	doubled_slot: int,
	_test_parameters := [
		["bread,eggs,repeat,coffee,bread,banana,milk", 45, 6],
		# The best order of that hand: Repeat copies the doubled Milk.
		["bread,banana,eggs,bread,coffee,milk,repeat", 126, 5],
		["bread,bread,bread,bread,bread", 15, -1],
	]
) -> void:
	var rule: NthProductMultiplierRule = NthProductMultiplierRule.new()
	rule.product_number = 6
	rule.factor = 2
	var result: ScoreResult = Scoring.score(_row("v4:" + row), [_built_upgrade(rule)])
	assert_int(result.total).override_failure_message(row).is_equal(total)
	var doubled: Array[ScoreStep] = _steps(
		result, ScoreStep.StepType.MULTIPLIER, ScoreStep.SourceKind.UPGRADE
	)
	if doubled_slot < 0:
		assert_array(doubled).is_empty()
	else:
		assert_int(doubled.size()).is_equal(1)
		assert_int(doubled[0].slot).is_equal(doubled_slot)


## The starter deck fits no build, so the offer's guarantee follows what the player drafts:
## 2 more Banana make a bulk buyer, 2 more Breakfast cards a breakfast special.
func test_builds_measure_the_deck() -> void:
	var starter: Array[CardDefinition] = _starter_cards()
	for build_id: String in [
		"breakfast_special",
		"bulk_buyer",
		"coupon_specialist",
		"clearance_collector",
		"mixed_basket"
	]:
		var build: BuildDefinition = load(BUILDS % build_id)
		assert_bool(build.fits(starter)).override_failure_message(build_id).is_false()
	var bananas: Array[CardDefinition] = starter.duplicate()
	bananas.append(load("res://data/cards/banana.tres"))
	assert_bool((load(BUILDS % "bulk_buyer") as BuildDefinition).fits(bananas)).is_true()
	var breakfast: Array[CardDefinition] = starter.duplicate()
	breakfast.append(load("res://data/cards/cereal.tres"))
	breakfast.append(load("res://data/cards/yogurt.tres"))
	assert_bool((load(BUILDS % "breakfast_special") as BuildDefinition).fits(breakfast)).is_true()
	var coupons: Array[CardDefinition] = starter.duplicate()
	coupons.append(load(FINAL_MARKDOWN))
	assert_bool((load(BUILDS % "coupon_specialist") as BuildDefinition).fits(coupons)).is_true()
	# An Economy upgrade never counts as fitting, even when its build does.
	assert_bool(_upgrade("extra_coupon_slot").fits(coupons)).is_false()
	assert_bool(_upgrade("coupon_engine").fits(coupons)).is_true()
	assert_str(_upgrade("extra_redraw").build_names()).is_equal("Any build")
	assert_str(_upgrade("big_basket").build_names()).is_equal("Clearance collector")


## The offer guarantees an upgrade that fits the deck when one is unowned, keeps 3 options of
## different types, and is the same for the same seed.
func test_offers_include_a_fitting_upgrade() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	# A coupon-heavy deck: only Coupon engine fits (Extra coupon slot is Economy).
	var starter: Array[CardDefinition] = _starter_cards()
	starter.append(load(FINAL_MARKDOWN))
	var owned: Array[UpgradeDefinition] = []
	for seed_value: int in range(300):
		var where: String = "seed %d" % seed_value
		var offer: Array[UpgradeDefinition] = UpgradeOffer.make(
			_rng(seed_value), balance, owned, starter
		)
		assert_int(offer.size()).override_failure_message(where).is_equal(3)
		assert_bool(offer.has(_upgrade("coupon_engine"))).override_failure_message(where).is_true()
		var types: Dictionary = {}
		for upgrade: UpgradeDefinition in offer:
			types[upgrade.type] = true
		assert_int(types.size()).override_failure_message(where).is_equal(3)
	var again: Array[UpgradeDefinition] = UpgradeOffer.make(_rng(7), balance, owned, starter)
	assert_array(UpgradeOffer.make(_rng(7), balance, owned, starter)).is_equal(again)
	# Nothing fits an empty deck: still a full offer.
	var nothing: Array[CardDefinition] = []
	assert_int(UpgradeOffer.make(_rng(3), balance, owned, nothing).size()).is_equal(3)


## The steps of one type from one kind of source, in order.
static func _steps(
	result: ScoreResult, step_type: ScoreStep.StepType, source_kind: ScoreStep.SourceKind
) -> Array[ScoreStep]:
	var found: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.step_type == step_type and step.source_kind == source_kind:
			found.append(step)
	return found


static func _built_upgrade(rule: UpgradeRule) -> UpgradeDefinition:
	var upgrade: UpgradeDefinition = UpgradeDefinition.new()
	upgrade.display_name = "Test upgrade"
	upgrade.type = UpgradeDefinition.Type.RULE_BENDER
	var rules: Array[UpgradeRule] = [rule]
	upgrade.rules = rules
	return upgrade


static func _row(spec: String) -> Array[CardInstance]:
	var fixture: String = FIXTURE_V0_5 if spec.begins_with("v5:") else FIXTURE_V0_4
	var row: Array[CardInstance] = []
	for card_id: String in spec.substr(3).split(","):
		row.append(CardInstance.new(load(fixture % card_id), row.size() + 1))
	return row


static func _starter_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	cards.assign((load(STARTER) as DeckDefinition).cards)
	return cards


static func _upgrade(upgrade_id: String) -> UpgradeDefinition:
	return load(UPGRADES % upgrade_id)


static func _none() -> Array[UpgradeDefinition]:
	return []


static func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	# No inspected shifts: an inspection's slot changes would hide the upgrades' here.
	balance.inspection_shifts = PackedInt32Array()
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	return run


static func _pass(run: RunState) -> void:
	for _index: int in range(2):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
