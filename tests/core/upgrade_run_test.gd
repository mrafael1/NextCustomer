extends GdUnitTestSuite
## Registers in a run (plan section 3.8; #77): the upgrade pool, a register taken from the
## machine's REGISTER chute applies from the next shift (Extra redraw adds a redraw), a lost or
## last shift opens no visit, and the run history keeps one record per played shift with its
## visits. The machine's own rules are tested in reward_machine_test.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const UPGRADE_DIR := "res://data/upgrades"


func test_balance_upgrade_data_fits_the_run() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var ids: Array = []
	var types: Dictionary = {}
	for upgrade: UpgradeDefinition in balance.upgrade_pool:
		ids.append(String(upgrade.id))
		types[upgrade.type] = true
	ids.sort()
	(
		assert_array(ids)
		. is_equal(
			[
				"bakery_aisle_run",
				"bakery_regulars",
				"banana_stand",
				"big_basket",
				"breakfast_aisle_run",
				"breakfast_regulars",
				"bulk_deal",
				"category_engine",
				"clearance_aisle_run",
				"clearance_regulars",
				"coupon_engine",
				"dairy_aisle_run",
				"dairy_regulars",
				"extra_redraw",
				"fire_sale",
				"household_aisle_run",
				"household_regulars",
				"lemon_squeezer",
				"mixed_basket",
				"produce_aisle_run",
				"produce_regulars",
				"slot_engine",
				"snack_aisle_run",
				"snack_regulars",
			]
		)
	)
	# One per type (Extra coupon slot, the second Economy one, left in v0.56, #106; Rule bender
	# left the pool in #42), plus #108's family perks: Regulars and Aisle runs for 7 families,
	# Mixed basket, Bulk deal and the jackpots.
	assert_int(types.size()).is_equal(10)
	# The loyalty card holds 3 machine registers (#77).
	assert_int(balance.machine.register_cap).is_equal(3)


## A slip gets no visit and the run goes on (v0.65, v0.68's training week); a miss from shift 5
## ends the run.
func test_a_slip_gets_no_visit_and_a_miss_after_training_ends_the_run() -> void:
	var run: RunState = _run(26)
	run.debug_skip_to_shift(1)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_object(run.machine.current_visit()).is_null()
	assert_bool(run.machine.choose(run, RewardMachine.Chute.UPGRADE)).is_false()
	assert_bool(run.history[-1].passed).is_false()
	assert_array(run.history[-1].visits).is_empty()
	# Shift 5 is past the training week (v0.68): its miss ends the run, slips left or not.
	run.debug_skip_to_shift(4)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_object(run.machine.current_visit()).is_null()
	assert_array(run.history[-1].visits).is_empty()


func test_the_last_shift_has_no_visit() -> void:
	var run: RunState = _run(27)
	run.debug_skip_to_shift(run.shift_count() - 1)
	_pass(run)
	assert_int(run.phase).is_equal(RunState.Phase.WON)
	assert_object(run.machine.current_visit()).is_null()


func test_history_has_one_entry_per_played_shift() -> void:
	var run: RunState = _run(28)
	# Shift 1: a NEW ITEMS prize picked.
	_pass(run)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	var card: CardDefinition = run.machine.prizes()[0].card
	MachineSteps.take(run, 0)
	run.next_shift()
	# Shift 2: a register taken.
	_pass(run)
	var upgrade: UpgradeDefinition = MachineSteps.take_register(run)
	assert_object(upgrade).is_not_null()
	run.next_shift()
	# Shift 3: missed with an empty row (a write-up).
	run.checkout()
	assert_int(run.history.size()).is_equal(3)
	var first: Dictionary = run.history[0].to_dictionary()
	var visits: Array = first["visits"]
	first.erase("visits")
	(
		assert_dict(first)
		. is_equal(
			{
				"shift": 1,
				"quota": 5,
				"total": 10,
				"passed": true,
				"inspection": "",
				"inspections": [],
				"played": ["bread", "bread"],
			}
		)
	)
	assert_int(visits.size()).is_equal(1)
	assert_str(visits[0]["chute"]).is_equal("new_items")
	assert_array(run.history[0].cards_added()).is_equal([card])
	assert_array(run.history[1].registers_taken()).is_equal([upgrade])
	assert_int(run.history[1].shift).is_equal(2)
	var lost: ShiftRecord = run.history[2]
	assert_int(lost.shift).is_equal(3)
	assert_int(lost.total).is_equal(0)
	assert_bool(lost.passed).is_false()
	assert_array(lost.visits).is_empty()


## Extra redraw: one more redraw each shift (a third on top of the balance's 2), each of one
## basket, and no redraw brings back a card that an earlier one replaced.
func test_extra_redraw_allows_a_third_redraw() -> void:
	var extra: UpgradeDefinition = _upgrade("extra_redraw")
	var run: RunState = null
	# The seed whose UPGRADE draw after shift 2 holds it.
	for seed_value: int in range(29, 129):
		run = _run(seed_value)
		assert_int(run.redraws_allowed).is_equal(2)
		run.debug_skip_to_shift(1)
		_pass(run)
		MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)
		if MachineSteps.offers(run, extra):
			break
	assert_object(MachineSteps.take_register(run, extra)).is_same(extra)
	# It applies from the next shift on.
	assert_int(run.redraws_allowed).is_equal(2)
	assert_bool(run.next_shift()).is_true()
	assert_int(run.redraws_allowed).is_equal(3)
	assert_int(run.redraws_used).is_equal(0)
	var replaced: Array[CardInstance] = []
	for basket: int in range(3):
		assert_bool(run.can_redraw_basket(basket)).is_true()
		var by_place: Array[CardInstance] = run.hand_places()
		var swapped: Array[int] = run.redraw_basket(basket)
		assert_int(swapped.size()).is_greater(0)
		for place: int in swapped:
			replaced.append(by_place[place])
		assert_int(run.redraws_used).is_equal(basket + 1)
	assert_bool(run.can_redraw_basket(3)).is_false()
	assert_array(run.redraw_basket(3)).is_empty()
	# Neither redraw brought back a replaced card.
	for card: CardInstance in replaced:
		assert_bool(run.hand().has(card)).is_false()


func test_without_the_upgrade_a_shift_has_two_redraws() -> void:
	var run: RunState = _run(30)
	run.redraw_basket(0)
	assert_bool(run.can_redraw_basket(1)).is_true()
	run.redraw_basket(1)
	assert_bool(run.can_redraw_basket(2)).is_false()


## The preview and the checkout both score with the run's upgrades.
func test_preview_and_checkout_use_the_run_upgrades() -> void:
	var run: RunState = _run(32)
	run.upgrades.append(_upgrade("coupon_engine"))
	run.place(run.debug_add_to_hand(load(BREAD)), 0)
	run.place(run.debug_add_to_hand(load("res://data/cards/final_markdown.tres")), 1)
	var preview: ScoreResult = run.preview()
	assert_int(preview.total).is_equal(13)
	var upgrade_steps: Array = preview.steps.filter(
		func(step: ScoreStep) -> bool: return step.source_kind == ScoreStep.SourceKind.UPGRADE
	)
	assert_int(upgrade_steps.size()).is_equal(1)
	assert_int(run.checkout().total).is_equal(13)


## #108 piece 2: Extra redraw and Big basket print what they earned. A card a redraw past the base
## redraws brought in gets a CREDIT step from Extra redraw's box ("redrawn in"), the card in the
## slot Big basket added one from Big basket's ("slot 8"), each worth the card's payout and after
## its PAYOUT; the total is the same as without credits. The extra redraw's cards are saved.
func test_extra_redraw_and_big_basket_credit_what_they_earned() -> void:
	var run: RunState = _run(40)
	run.upgrades = [_upgrade("extra_redraw"), _upgrade("big_basket")]
	run.start_shift()
	assert_int(run.redraws_allowed).is_equal(3)
	run.redraw_basket(0)
	run.redraw_basket(1)
	assert_array(Array(run.redrawn_in)).is_empty()
	var swapped: Array[int] = run.redraw_basket(2)
	assert_int(swapped.size()).is_greater(0)
	var brought: CardInstance = run.hand_places()[swapped[0]]
	assert_array(Array(run.redrawn_in)).contains([brought.instance_id])
	assert_bool(run.place(brought, 0)).is_true()
	while run.row.size() < 8:
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	var result: ScoreResult = run.preview()
	var credits: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.CREDIT:
			credits.append(step)
	assert_int(credits.size()).is_equal(2)
	assert_int(credits[0].slot).is_equal(0)
	assert_int(credits[0].source_index).is_equal(0)
	assert_str(credits[0].reason).is_equal("redrawn in")
	assert_int(credits[0].value).is_equal(result.payouts[0])
	assert_int(credits[1].slot).is_equal(7)
	assert_int(credits[1].source_index).is_equal(1)
	assert_str(credits[1].reason).is_equal("slot 8")
	assert_int(credits[1].value).is_equal(result.payouts[7])
	assert_int(result.total).is_equal(Scoring.score(run.row, run.upgrades).total)
	# Each credit sits right after its slot's PAYOUT.
	var payout_at: int = -1
	for index: int in result.steps.size():
		var step: ScoreStep = result.steps[index]
		if step.step_type == ScoreStep.StepType.PAYOUT and step.slot == 7:
			payout_at = index
	assert_object(result.steps[payout_at + 1]).is_same(credits[1])
	# The receipt words it as a label: the amount in its words, no amount column.
	var names: PackedStringArray = PackedStringArray()
	for card: CardInstance in run.row:
		names.append(card.definition.display_name)
	var text: PackedStringArray = ReceiptView.step_text(credits[1], names)
	assert_str(text[0]).is_equal("  Big basket earned €%d.00 (slot 8)" % result.payouts[7])
	assert_str(text[1]).is_empty()
	# The extra redraw's cards are saved.
	var saved: Dictionary = RunSave.to_dictionary(run, "id", 0)
	var restored: RunSave = RunSave.from_dictionary(
		JSON.parse_string(JSON.stringify(saved)), ContentLookup.new(run.balance)
	)
	assert_array(Array(restored.run.redrawn_in)).is_equal(Array(run.redrawn_in))


## Quotas all 5.
static func _low_quotas() -> BalanceDefinition:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	# No boon days, and the inspections that change no redraw or hand (v0.69's day events would
	# change the limits these tests count).
	balance.boon_shifts = PackedInt32Array()
	var pool: Array[InspectionDefinition] = [
		load("res://data/inspections/spot_check.tres"),
		load("res://data/inspections/short_belt.tres")
	]
	balance.inspection_pool = pool
	return balance


## A run whose quotas are all 5, so two Breads (6) pass any shift.
static func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = _low_quotas()
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	run.start_shift()
	return run


static func _pass(run: RunState) -> void:
	for _index: int in range(2):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()


static func _upgrade(id: String) -> UpgradeDefinition:
	return load("%s/%s.tres" % [UPGRADE_DIR, id])
