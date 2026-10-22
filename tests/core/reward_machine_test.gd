extends GdUnitTestSuite
## The RECEIPT REWARDS machine's logic (#77, build spec 1.6 and 9): prizes come from the chosen
## chute and a pick does what its preview says (issue #77 item 2), the Regular meters (item 4),
## the first-draw flags, the register cap and STAMP DAY, the bonus ticket, UPGRADES' lock, the
## deck limit, clear_visits, reveal order, short draws and the machine's save form. Runs are built
## with the current RunState; the machine gets its own seeded RNG and the shift records are made
## here, so no checkout is played.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS_DIR := "res://data/cards"
const UPGRADES_DIR := "res://data/upgrades"

var _balance: BalanceDefinition
var _starter: DeckDefinition
var _rngs: Dictionary = {}


func before() -> void:
	_balance = load(BALANCE)
	_starter = load(STARTER)


## Issue #77 item 2: every chute, seeded: the prizes come from the chosen chute, and picking one
## adds or upgrades exactly that item, as its preview said.
func test_prizes_come_from_the_chute_and_a_pick_does_what_its_preview_says() -> void:
	for chute: int in RewardMachine.CHUTES:
		for seed_value: int in range(1, 13):
			var run: RunState = _run(seed_value)
			var machine: RewardMachine = _machine(seed_value)
			_pass(run, machine, 3)
			assert_bool(machine.choose(run, chute)).is_true()
			var prizes: Array[MachinePrize] = machine.prizes()
			assert_int(prizes.size()).is_between(1, 3)
			for prize: MachinePrize in prizes:
				_assert_from_chute(run, chute, prize)
			var index: int = seed_value % prizes.size()
			_assert_pick_matches_preview(run, machine, index)
			assert_int(run.history[-1].visits.size()).is_equal(1)
			assert_int(run.history[-1].visits[0].picked).is_equal(index)
			assert_int(run.history[-1].visits[0].chute).is_equal(chute)


## Issue #77 item 4: Regular rises by one per pick and per bin, unlocks the level's odds and, at
## the top, "1 of 3 at least RARE"; a new run's machine starts at 0.
func test_the_meter_rises_per_pick_and_bin_and_unlocks_the_level_odds() -> void:
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	var chute: int = RewardMachine.Chute.NEW_ITEMS
	for shift_number: int in [1, 2, 3]:
		_pass(run, machine, shift_number)
		var info: MachineChuteInfo = machine.chute_info(run, chute)
		assert_bool(info.meter_rises).is_true()
		assert_int(info.odds.level).is_equal(shift_number - 1)
		assert_int(info.odds.next_level).is_equal(shift_number)
		assert_bool(machine.choose(run, chute)).is_true()
		if shift_number == 2:
			assert_bool(machine.bin(run)).is_true()
		else:
			assert_object(machine.pick(run, 0)).is_not_null()
		assert_int(machine.level(chute)).is_equal(shift_number)
		_finish_stamp_day(run, machine)
	_pass(run, machine, 4)
	var top: MachineChuteInfo = machine.chute_info(run, chute)
	assert_int(top.level).is_equal(3)
	assert_int(top.max_level).is_equal(3)
	assert_bool(top.meter_rises).is_false()
	assert_int(top.odds.first_drop_min_rarity).is_equal(1)
	assert_float(top.odds.first_share[MachinePrize.Rarity.COMMON]).is_equal(0.0)
	var level_three: MachineOddsLevel = _balance.machine.odds_levels[3]
	assert_int(level_three.first_drop_min_rarity).is_equal(1)
	var fresh: RewardMachine = _machine()
	assert_array(Array(fresh.levels)).is_equal([0, 0, 0, 0])


## The meter rises only when a later draw from the chute can use it: shift 7's ticket with and
## without a bonus visit due, UPGRADES on shift 7's ticket (a bonus follows) and bonus, REGISTER at
## 2 picked, and STAMP DAY never.
func test_the_meter_rises_only_when_a_later_visit_can_use_it() -> void:
	var items: int = RewardMachine.Chute.NEW_ITEMS
	var upgrades: int = RewardMachine.Chute.UPGRADES
	# Shift 7 with an inspection: the ticket's pick rises, the bonus visit's doesn't.
	for chute: int in [items, upgrades]:
		var run: RunState = _run()
		var machine: RewardMachine = _machine()
		_pass(run, machine, 7, true)
		assert_bool(machine.chute_info(run, chute).meter_rises).is_true()
		assert_bool(machine.choose(run, chute)).is_true()
		assert_bool(machine.pick(run, 0).meter_rose).is_true()
		assert_int(machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
		assert_bool(machine.chute_info(run, chute).meter_rises).is_false()
		assert_bool(machine.choose(run, chute)).is_true()
		assert_bool(machine.pick(run, 0).meter_rose).is_false()
		assert_int(machine.level(chute)).is_equal(1)
	# Shift 7 without an inspection: no later visit.
	var last: RunState = _run()
	var last_machine: RewardMachine = _machine()
	_pass(last, last_machine, 7)
	assert_bool(last_machine.chute_info(last, items).meter_rises).is_false()
	# REGISTER rises at 1 picked (the pick makes 2, below the cap of 3), not at 2.
	for picked: int in [1, 2]:
		var run: RunState = _run()
		var machine: RewardMachine = _machine()
		for index: int in picked:
			_give_register(run, _upgrade(["extra_redraw", "big_basket"][index]), index + 1)
		_pass(run, machine, 3)
		var rises: bool = machine.chute_info(run, RewardMachine.Chute.REGISTER).meter_rises
		assert_bool(rises).is_equal(picked == 1)


## A shift-4 ticket at 1 register picked: the ticket's pick (another chute) rises, then STAMP DAY
## follows (1 below the floor of 2) and its REGISTER pick doesn't raise the meter. With none picked,
## a REGISTER pick on the ticket rises and its STAMP DAY pick doesn't.
func test_stamp_day_picks_never_raise_the_meter() -> void:
	var register: int = RewardMachine.Chute.REGISTER
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_give_register(run, _upgrade("extra_redraw"), 2)
	_pass(run, machine, 4)
	assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(machine.pick(run, 0).meter_rose).is_true()
	assert_int(machine.current_visit().kind).is_equal(MachineVisit.Kind.STAMP_DAY)
	assert_bool(machine.chute_info(run, register).meter_rises).is_false()
	var landing: MachineLanding = machine.pick(run, 0)
	assert_bool(landing.meter_rose).is_false()
	assert_bool(landing.last_of_shift).is_true()
	assert_int(machine.level(register)).is_equal(0)
	assert_int(machine.registers_picked(run)).is_equal(2)
	var none: RunState = _run()
	var none_machine: RewardMachine = _machine()
	_pass(none, none_machine, 4)
	assert_bool(none_machine.choose(none, register)).is_true()
	assert_bool(none_machine.pick(none, 0).meter_rose).is_true()
	assert_int(none_machine.current_visit().kind).is_equal(MachineVisit.Kind.STAMP_DAY)
	assert_bool(none_machine.pick(none, 0).meter_rose).is_false()
	assert_int(none_machine.level(register)).is_equal(1)


## STAMP DAY: behind the floor it skips CHOOSE, draws REGISTER at the REGISTER level with the run's
## RNG when it becomes current, can't be binned, and its odds card is the one it drew from; on
## schedule there is none.
func test_stamp_day_follows_a_run_behind_the_floor() -> void:
	var run: RunState = _run()
	var machine: RewardMachine = _machine(31)
	machine.levels[RewardMachine.Chute.REGISTER] = 2
	_pass(run, machine, 2)
	assert_array(machine.pending_kinds()).is_equal([MachineVisit.Kind.STAMP_DAY])
	assert_bool(machine.choose(run, RewardMachine.Chute.COUPONS)).is_true()
	var rng: RandomNumberGenerator = _rngs[31]
	var state: int = rng.state
	var landing: MachineLanding = machine.pick(run, 0)
	assert_bool(landing.last_of_shift).is_false()
	assert_int(rng.state).is_not_equal(state)
	var visit: MachineVisit = machine.current_visit()
	assert_int(visit.kind).is_equal(MachineVisit.Kind.STAMP_DAY)
	assert_int(machine.stage).is_equal(RewardMachine.Stage.PICK)
	assert_int(visit.chute).is_equal(RewardMachine.Chute.REGISTER)
	assert_int(visit.level_before).is_equal(2)
	assert_bool(machine.can_bin()).is_false()
	assert_bool(machine.bin(run)).is_false()
	for prize: MachinePrize in machine.prizes():
		assert_int(prize.kind).is_equal(MachinePrize.Kind.REGISTER)
	var info: MachineChuteInfo = machine.chute_info(run, RewardMachine.Chute.REGISTER)
	assert_object(info.odds).is_same(visit.stamp_day_odds)
	assert_int(info.odds.level).is_equal(2)
	# Resumed at STAMP DAY's pick: the same prizes, and its odds card is computed again.
	var resumed: RewardMachine = _machine(32)
	assert_bool(resumed.restore_from(_saved(machine), _lookup())).is_true()
	assert_array(resumed.prizes().map(_key)).is_equal(machine.prizes().map(_key))
	var resumed_odds: MachineOddsCard = resumed.chute_info(run, RewardMachine.Chute.REGISTER).odds
	assert_dict(resumed_odds.in_draw).is_equal(info.odds.in_draw)
	assert_object(resumed.current_visit().stamp_day_odds).is_same(resumed_odds)
	assert_bool(resumed_odds.meter_rises).is_false()
	assert_bool(resumed.can_bin()).is_false()
	# Resumed and picked at once: the pick pins the card on the visit for the log.
	var picked_at_once: RewardMachine = _machine(33)
	assert_bool(picked_at_once.restore_from(_saved(machine), _lookup())).is_true()
	var stamp_visit: MachineVisit = picked_at_once.current_visit()
	assert_object(picked_at_once.pick(run, 0)).is_not_null()
	assert_object(stamp_visit.stamp_day_odds).is_not_null()
	assert_dict(stamp_visit.stamp_day_odds.in_draw).is_equal(info.odds.in_draw)
	assert_int(picked_at_once.registers_picked(run)).is_equal(1)
	assert_int(picked_at_once.stage).is_equal(RewardMachine.Stage.IDLE)
	# On schedule: the ticket's REGISTER pick reaches the floor.
	var on_time: RunState = _run()
	var on_time_machine: RewardMachine = _machine()
	_pass(on_time, on_time_machine, 2)
	assert_bool(on_time_machine.choose(on_time, RewardMachine.Chute.REGISTER)).is_true()
	assert_bool(on_time_machine.pick(on_time, 0).last_of_shift).is_true()
	assert_int(on_time_machine.stage).is_equal(RewardMachine.Stage.IDLE)
	assert_array(on_time.history[-1].visits.map(_kind)).is_equal([MachineVisit.Kind.TICKET])


## The register cap counts machine picks only: a starting deck's upgrade doesn't count, the card is
## full after 3 machine picks (REGISTER refused), and the STAMP DAY floor ignores the starter's.
func test_the_register_cap_counts_machine_picks_only() -> void:
	var run: RunState = _run()
	run.upgrades.append(_upgrade("rule_bender"))
	var machine: RewardMachine = _machine()
	assert_int(machine.registers_picked(run)).is_equal(0)
	var register: int = RewardMachine.Chute.REGISTER
	for shift_number: int in [1, 3, 5]:
		_pass(run, machine, shift_number)
		assert_int(machine.chute_info(run, register).state).is_equal(RewardMachine.ChuteState.OPEN)
		assert_bool(machine.choose(run, register)).is_true()
		assert_object(machine.pick(run, 0)).is_not_null()
	assert_int(machine.registers_picked(run)).is_equal(3)
	assert_int(run.upgrades.size()).is_equal(4)
	_pass(run, machine, 7)
	assert_int(machine.chute_info(run, register).state).is_equal(RewardMachine.ChuteState.CARD_FULL)
	assert_bool(machine.choose(run, register)).is_false()
	var starter_only: RunState = _run()
	starter_only.upgrades.append(_upgrade("rule_bender"))
	var floor_machine: RewardMachine = _machine()
	_pass(starter_only, floor_machine, 2)
	assert_array(floor_machine.pending_kinds()).is_equal([MachineVisit.Kind.STAMP_DAY])


## The first COUPONS draw holds a first-offer coupon and spends its flag at the draw, whether the
## prizes are then picked or binned, and the flag stays spent across a save. While its prizes
## wait (and after a resume there), the chute's odds card is still the first draw's (the
## guarantee, the first NEW ITEMS draw's new-arrival note): the card the player confirmed.
func test_the_first_coupons_flag_is_spent_at_the_draw() -> void:
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 1)
	var coupons: int = RewardMachine.Chute.COUPONS
	var shown: MachineOddsCard = machine.chute_info(run, coupons).odds
	assert_bool(shown.guarded).is_true()
	assert_bool(machine.choose(run, coupons)).is_true()
	assert_bool(machine.coupons_first_done).is_true()
	assert_bool(machine.current_visit().guarantee_held).is_true()
	_assert_same_card(machine.chute_info(run, coupons).odds, shown)
	var restored: RewardMachine = _machine()
	assert_bool(restored.restore_from(_saved(machine), _lookup())).is_true()
	assert_bool(restored.coupons_first_done).is_true()
	_assert_same_card(restored.chute_info(run, coupons).odds, shown)
	assert_bool(machine.bin(run)).is_true()
	_pass(run, machine, 3)
	assert_bool(machine.chute_info(run, coupons).odds.guarded).is_false()
	assert_bool(machine.new_items_first_done).is_false()
	var new_items: int = RewardMachine.Chute.NEW_ITEMS
	var first_items: MachineOddsCard = machine.chute_info(run, new_items).odds
	assert_bool(machine.choose(run, new_items)).is_true()
	assert_bool(machine.new_items_first_done).is_true()
	var resumed: RewardMachine = _machine()
	assert_bool(resumed.restore_from(_saved(machine), _lookup())).is_true()
	_assert_same_card(resumed.chute_info(run, new_items).odds, first_items)
	# A later draw of the chute is no first draw: the card is the spent-flag one.
	assert_bool(machine.bin(run)).is_true()
	_pass(run, machine, 5)
	var later: MachineOddsCard = machine.chute_info(run, coupons).odds
	assert_bool(machine.choose(run, coupons)).is_true()
	_assert_same_card(machine.chute_info(run, coupons).odds, later)
	assert_bool(machine.chute_info(run, coupons).odds.guarded).is_false()


## The bonus ticket: only after a passed inspected shift (why: the inspection) or a bonus extra
## shift (why: ""); any chute; its odds reflect the first pick (an owned register no longer drops,
## the meter just raised counts).
func test_the_bonus_visit_follows_an_inspected_pass() -> void:
	var plain: RunState = _run()
	var plain_machine: RewardMachine = _machine()
	_pass(plain, plain_machine, 3)
	assert_array(plain_machine.pending_kinds()).is_empty()
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 3, true)
	assert_array(machine.pending_kinds()).is_equal([MachineVisit.Kind.BONUS])
	var register: int = RewardMachine.Chute.REGISTER
	assert_bool(machine.choose(run, register)).is_true()
	var taken: UpgradeDefinition = machine.pick(run, 0).register
	var visit: MachineVisit = machine.current_visit()
	assert_int(visit.kind).is_equal(MachineVisit.Kind.BONUS)
	assert_str(visit.why).is_equal(String(_balance.inspection_pool[0].id))
	assert_int(machine.stage).is_equal(RewardMachine.Stage.CHOOSE)
	var info: MachineChuteInfo = machine.chute_info(run, register)
	assert_int(info.level).is_equal(1)
	for key: String in info.odds.in_draw:
		assert_bool(key.contains(":%s:" % taken.id)).is_false()
	# What the first pick changed here, for the bonus band (the UI only words it).
	assert_int(info.first_pick_level_before).is_equal(0)
	assert_bool(info.first_pick_kept).is_true()
	assert_bool(info.first_pick_spent_coupon).is_false()
	var other: MachineChuteInfo = machine.chute_info(run, RewardMachine.Chute.NEW_ITEMS)
	assert_int(other.first_pick_level_before).is_equal(-1)
	assert_bool(other.first_pick_kept).is_false()
	# COUPONS: the first pick spent the run's first-visit coupon only on the run's first COUPONS
	# draw.
	var coupons: int = RewardMachine.Chute.COUPONS
	for earlier_coupons: bool in [false, true]:
		var coupon_run: RunState = _run()
		var coupon_machine: RewardMachine = _machine(9)
		if earlier_coupons:
			_pass(coupon_run, coupon_machine, 1)
			assert_bool(coupon_machine.choose(coupon_run, coupons)).is_true()
			assert_bool(coupon_machine.bin(coupon_run)).is_true()
		_pass(coupon_run, coupon_machine, 3, true)
		assert_int(coupon_machine.chute_info(coupon_run, coupons).first_pick_level_before).is_equal(
			-1
		)
		(
			assert_bool(coupon_machine.chute_info(coupon_run, coupons).first_pick_spent_coupon)
			. is_false()
		)
		assert_bool(coupon_machine.choose(coupon_run, coupons)).is_true()
		coupon_machine.pick(coupon_run, 0)
		assert_int(coupon_machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
		var coupon_info: MachineChuteInfo = coupon_machine.chute_info(coupon_run, coupons)
		assert_bool(coupon_info.first_pick_spent_coupon).is_equal(not earlier_coupons)
		assert_bool(coupon_info.first_pick_kept).is_true()
	assert_bool(machine.choose(run, register)).is_true()
	assert_object(machine.pick(run, 0)).is_not_null()
	assert_int(machine.stage).is_equal(RewardMachine.Stage.IDLE)
	assert_array(run.history[-1].visits.map(_kind)).is_equal(
		[MachineVisit.Kind.TICKET, MachineVisit.Kind.BONUS]
	)
	# A bonus extra shift (a balance lever) gives one without an inspection.
	var extra: MachineDefinition = _balance.machine.duplicate()
	extra.bonus_extra_shifts = PackedInt32Array([1])
	var extra_run: RunState = _run()
	var extra_machine: RewardMachine = _machine(7, extra)
	_pass(extra_run, extra_machine, 1)
	assert_bool(extra_machine.choose(extra_run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	extra_machine.pick(extra_run, 0)
	assert_int(extra_machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
	assert_str(extra_machine.current_visit().why).is_empty()
	# Off in the data: no bonus.
	var off: MachineDefinition = _balance.machine.duplicate()
	off.bonus_after_inspection = false
	var off_run: RunState = _run()
	var off_machine: RewardMachine = _machine(7, off)
	_pass(off_run, off_machine, 3, true)
	assert_array(off_machine.pending_kinds()).is_empty()
	_assert_bonus_if_passed_matches_the_checkout()


## The planning notice's query (#77 machine v2): bonus_if_passed, asked during the shift, agrees
## with pending_kinds() after that shift's passed checkout: inspected, uninspected, a bonus extra
## shift, the data's switch off, and the last shift (no machine: false); bonus_earned after it
## (the chip's EARNED) only for an inspected pass that queued it.
func _assert_bonus_if_passed_matches_the_checkout() -> void:
	assert_bool(_machine().bonus_earned(_run())).is_false()
	var extra: MachineDefinition = _balance.machine.duplicate() as MachineDefinition
	extra.bonus_extra_shifts = PackedInt32Array([2])
	var off: MachineDefinition = _balance.machine.duplicate() as MachineDefinition
	off.bonus_after_inspection = false
	var last: int = _balance.quotas.size()
	var cases: Array[Array] = [
		[_balance.machine, 3, true, true],
		[_balance.machine, 3, false, false],
		[extra, 2, false, true],
		[off, 3, true, false],
		[_balance.machine, last, true, false],
	]
	for case: Array in cases:
		var run: RunState = _run()
		var machine: RewardMachine = _machine(7, case[0] as MachineDefinition)
		var shift_number: int = case[1]
		var inspected: bool = case[2]
		run.shift_index = shift_number - 1
		run.inspections = []
		if inspected:
			run.inspections.append(_balance.inspection_pool[0])
		var promised: bool = machine.bonus_if_passed(run)
		var failure: String = "shift %d inspected %s" % [shift_number, inspected]
		assert_bool(promised).override_failure_message(failure).is_equal(bool(case[3]))
		_pass(run, machine, shift_number, inspected)
		var queued: bool = machine.pending_kinds().has(MachineVisit.Kind.BONUS)
		assert_bool(queued).override_failure_message(failure).is_equal(promised)
		var earned: bool = machine.bonus_earned(run)
		assert_bool(earned).override_failure_message(failure).is_equal(promised and inspected)


## Big basket picked on the bonus visit changes only the next shift's quota: the scored shift's
## limits stay.
func test_big_basket_on_the_bonus_visit_changes_only_the_next_shift() -> void:
	var basket: UpgradeDefinition = _upgrade("big_basket")
	for seed_value: int in range(1, 40):
		var run: RunState = _run(seed_value)
		run.upgrades = _upgrades(
			["coupon_engine", "category_engine", "extra_redraw", "extra_coupon_slot"]
		)
		run.shift_index = 2
		run.start_shift()
		var scored: ShiftLimits = run.limits
		var scored_quota: int = run.quota()
		var machine: RewardMachine = _machine(seed_value)
		_pass(run, machine, 3, true)
		assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		machine.pick(run, 0)
		assert_bool(machine.choose(run, RewardMachine.Chute.REGISTER)).is_true()
		var index: int = machine.prizes().map(_upgrade_of).find(basket)
		if index == -1:
			continue
		assert_object(machine.pick(run, index)).is_not_null()
		assert_object(run.limits).is_same(scored)
		assert_int(run.quota()).is_equal(scored_quota)
		var without: Array[UpgradeDefinition] = run.upgrades.slice(0, 4)
		var plain_next: int = ShiftLimits.for_shift(_balance, without, 3).quota
		run.shift_index = 3
		run.start_shift()
		assert_int(run.quota()).is_greater(plain_next)
		return
	fail("no draw offered Big basket")


## UPGRADES is locked after a shift it doesn't open on (with the next shift it opens after) and
## EMPTY when nothing can step.
func test_upgrades_is_locked_off_shift_and_empty_with_nothing_to_improve() -> void:
	var upgrades: int = RewardMachine.Chute.UPGRADES
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 1)
	var locked: MachineChuteInfo = machine.chute_info(run, upgrades)
	assert_int(locked.state).is_equal(RewardMachine.ChuteState.LOCKED_SHIFT)
	assert_int(locked.opens_after_shift).is_equal(3)
	assert_bool(locked.meter_rises).is_false()
	assert_int(locked.odds.next_level).is_equal(locked.level)
	assert_bool(machine.choose(run, upgrades)).is_false()
	var golden: RunState = _run()
	golden.deck = Deck.new(RandomNumberGenerator.new())
	golden.deck.add_card(load("%s/eggs_golden.tres" % CARDS_DIR))
	golden.deck.add_card(load("%s/bread.tres" % CARDS_DIR))
	var golden_machine: RewardMachine = _machine()
	_pass(golden, golden_machine, 3)
	assert_int(golden_machine.chute_info(golden, upgrades).state).is_equal(
		RewardMachine.ChuteState.EMPTY
	)
	assert_bool(golden_machine.choose(golden, upgrades)).is_false()


## At the deck limit a card prize needs a card swapped out: refused without one (or with a card
## not in the cart), swapped with one.
func test_a_full_cart_swaps_a_card_out() -> void:
	var run: RunState = _run()
	var bread: CardDefinition = load("%s/bread.tres" % CARDS_DIR)
	while run.deck.size() < _balance.deck_limit:
		run.deck.add_card(bread)
	var machine: RewardMachine = _machine()
	_pass(run, machine, 1)
	var info: MachineChuteInfo = machine.chute_info(run, RewardMachine.Chute.NEW_ITEMS)
	assert_bool(info.cart_full).is_true()
	assert_array(info.odds.notes).contains([MachineOddsCard.NOTE_CART_FULL])
	assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(machine.needs_replace(run, 0)).is_true()
	assert_bool(machine.preview(run, 0).needs_replace).is_true()
	assert_object(machine.pick(run, 0)).is_null()
	assert_object(machine.pick(run, 0, CardInstance.new(bread, 999))).is_null()
	var out: CardInstance = run.deck.cards[0]
	var landing: MachineLanding = machine.pick(run, 0, out)
	assert_object(landing.replaced).is_same(out)
	assert_int(run.deck.size()).is_equal(_balance.deck_limit)
	assert_bool(run.deck.cards.has(out)).is_false()
	assert_object(run.history[-1].visits[0].replaced).is_same(out.definition)


## clear_visits (a debug jump) from CHOOSE and from PICK: queue, visit and stage cleared, levels
## kept.
func test_clear_visits_keeps_the_levels() -> void:
	for draw_first: bool in [false, true]:
		var run: RunState = _run()
		var machine: RewardMachine = _machine()
		machine.levels[RewardMachine.Chute.COUPONS] = 2
		_pass(run, machine, 3, true)
		if draw_first:
			assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		machine.clear_visits()
		assert_int(machine.stage).is_equal(RewardMachine.Stage.IDLE)
		assert_object(machine.current_visit()).is_null()
		assert_array(machine.pending_kinds()).is_empty()
		assert_array(machine.prizes()).is_empty()
		assert_int(machine.level(RewardMachine.Chute.COUPONS)).is_equal(2)
		_pass(run, machine, 4)
		assert_int(machine.stage).is_equal(RewardMachine.Stage.CHOOSE)


## Prizes are in reveal order (rarity ascending, drop order within a rarity); drop_order keeps
## the draw's own order, which is what MachineDraw.draw returns from the same RNG state.
func test_reveal_order_and_drop_order() -> void:
	for seed_value: int in range(1, 30):
		var run: RunState = _run(seed_value)
		var machine: RewardMachine = _machine(seed_value)
		_pass(run, machine, 3)
		var copy: RandomNumberGenerator = RandomNumberGenerator.new()
		copy.state = (_rngs[seed_value] as RandomNumberGenerator).state
		var context: MachineContext = MachineContext.from_run(run, _balance.machine, false, false)
		var level: int = seed_value % 4
		machine.levels[RewardMachine.Chute.NEW_ITEMS] = level
		var expected: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.NEW_ITEMS, context, level, copy
		)
		assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		var visit: MachineVisit = machine.current_visit()
		assert_array(visit.in_drop_order().map(_key)).is_equal(expected.map(_key))
		for index: int in range(1, visit.prizes.size()):
			assert_int(visit.prizes[index].rarity).is_greater_equal(visit.prizes[index - 1].rarity)


## Short draws (REGISTER with only 2 types left) pick and save like full ones.
func test_short_draws_pick_and_save() -> void:
	var run: RunState = _run()
	run.upgrades = _upgrades(
		["coupon_engine", "category_engine", "extra_redraw", "extra_coupon_slot"]
	)
	var machine: RewardMachine = _machine()
	_pass(run, machine, 3)
	assert_bool(machine.choose(run, RewardMachine.Chute.REGISTER)).is_true()
	var prizes: Array[MachinePrize] = machine.prizes()
	assert_int(prizes.size()).is_between(1, 2)
	var restored: RewardMachine = _machine()
	assert_bool(restored.restore_from(_saved(machine), _lookup())).is_true()
	assert_array(restored.prizes().map(_key)).is_equal(prizes.map(_key))
	var last: int = prizes.size() - 1
	assert_object(restored.pick(run, last).register).is_same(prizes[last].upgrade)


## The machine's save form round-trips at CHOOSE (with a bonus queued) and PICK, and a save that
## doesn't fit is refused without changing the machine.
func test_the_save_form_round_trips_and_bad_fields_are_refused() -> void:
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	machine.levels[RewardMachine.Chute.UPGRADES] = 1
	_pass(run, machine, 3, true)
	for stage: int in [RewardMachine.Stage.CHOOSE, RewardMachine.Stage.PICK]:
		if stage == RewardMachine.Stage.PICK:
			assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADES)).is_true()
		var saved: Dictionary = _saved(machine)
		var restored: RewardMachine = _machine()
		assert_bool(restored.restore_from(saved, _lookup())).is_true()
		assert_dict(_saved(restored)).is_equal(saved)
		assert_int(restored.stage).is_equal(stage)
	var good: Dictionary = _saved(machine)
	var bad: Array[Dictionary] = []
	for change: Array in [
		["levels", [9, 0, 0, 0]],
		["levels", [0, 0, 0]],
		["stage", "dance"],
		["stage", "choose"],
		["stage", "idle"],
		["queue", ["ticket"]],
		["visit", {}],
		["coupons_first_done", "yes"],
		["first_draw", "yes"],
	]:
		var copy: Dictionary = good.duplicate(true)
		copy[change[0]] = change[1]
		bad.append(copy)
	var no_prizes: Dictionary = good.duplicate(true)
	no_prizes["visit"]["prizes"] = []
	no_prizes["visit"]["drop_order"] = []
	bad.append(no_prizes)
	var missing: Dictionary = good.duplicate(true)
	missing.erase("upgrades_at_checkout")
	bad.append(missing)
	for data: Dictionary in bad:
		var untouched: RewardMachine = _machine()
		untouched.levels[0] = 1
		(
			assert_bool(untouched.restore_from(data, _lookup()))
			. override_failure_message(str(data))
			. is_false()
		)
		assert_int(untouched.level(0)).is_equal(1)
		assert_int(untouched.stage).is_equal(RewardMachine.Stage.IDLE)


## A resumed machine with the saved RNG state draws the same prizes (and computing odds in
## between uses no RNG).
func test_a_resumed_machine_draws_the_same_prizes() -> void:
	var run: RunState = _run(4)
	var machine: RewardMachine = _machine(4)
	_pass(run, machine, 3, true)
	var rng: RandomNumberGenerator = _rngs[4]
	var saved: Dictionary = _saved(machine)
	var state: int = rng.state
	for chute: int in RewardMachine.CHUTES:
		machine.chute_info(run, chute)
	assert_int(rng.state).is_equal(state)
	var resumed: RewardMachine = _machine(99)
	(_rngs[99] as RandomNumberGenerator).state = state
	assert_bool(resumed.restore_from(saved, _lookup())).is_true()
	assert_bool(machine.choose(run, RewardMachine.Chute.COUPONS)).is_true()
	assert_bool(resumed.choose(run, RewardMachine.Chute.COUPONS)).is_true()
	assert_array(resumed.prizes().map(_key)).is_equal(machine.prizes().map(_key))


## The odds card's next-visit fields: the next level and its per-drop shares.
func test_the_odds_card_shows_the_next_visit() -> void:
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 1)
	var odds: MachineOddsCard = machine.chute_info(run, RewardMachine.Chute.NEW_ITEMS).odds
	assert_bool(odds.meter_rises).is_true()
	assert_int(odds.next_level).is_equal(1)
	var next: MachineOddsCard = MachineOdds.card(
		RewardMachine.Chute.NEW_ITEMS, MachineContext.from_run(run, _balance.machine, true, true), 1
	)
	assert_array(Array(odds.next_rarity_share)).is_equal(Array(next.rarity_share))


## A shift's record saves its visits (an empty list when there are none, #77 C3) and reads them
## back.
func test_shift_records_save_their_visits() -> void:
	var lookup: ContentLookup = _lookup()
	assert_array(ShiftRecord.new(1, 10, 20).to_dictionary()["visits"]).is_empty()
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 3, true)
	assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	var added: CardDefinition = machine.pick(run, 0).added.definition
	assert_bool(machine.choose(run, RewardMachine.Chute.REGISTER)).is_true()
	var register: UpgradeDefinition = machine.pick(run, 0).register
	var record: ShiftRecord = run.history[-1]
	assert_int(record.cards_added().size()).is_equal(1)
	assert_object(record.cards_added()[0]).is_same(added)
	assert_int(record.registers_taken().size()).is_equal(1)
	assert_object(record.registers_taken()[0]).is_same(register)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(record.to_dictionary()))
	var read: ShiftRecord = ShiftRecord.from_dictionary(saved, lookup)
	assert_object(read).is_not_null()
	assert_dict(read.to_dictionary()).is_equal(record.to_dictionary())
	saved["visits"][0]["picked"] = 7
	assert_object(ShiftRecord.from_dictionary(saved, lookup)).is_null()


## Nothing happens outside the right stage.
func test_calls_outside_their_stage_do_nothing() -> void:
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_false()
	assert_object(machine.pick(run, 0)).is_null()
	assert_object(machine.preview(run, 0)).is_null()
	assert_bool(machine.bin(run)).is_false()
	run.history.append(ShiftRecord.new(1, 10, 5))
	machine.begin_after_checkout(run)
	assert_int(machine.stage).is_equal(RewardMachine.Stage.IDLE)
	_pass(run, machine, 8)
	assert_int(machine.stage).is_equal(RewardMachine.Stage.IDLE)
	_pass(run, machine, 1)
	assert_object(machine.pick(run, 0)).is_null()
	assert_bool(machine.choose(run, 9)).is_false()


func _assert_from_chute(run: RunState, chute: int, prize: MachinePrize) -> void:
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			assert_int(prize.kind).is_equal(MachinePrize.Kind.PRODUCT)
			assert_bool(run.stock.cards.has(prize.card)).is_true()
		RewardMachine.Chute.COUPONS:
			assert_int(prize.kind).is_equal(MachinePrize.Kind.COUPON)
			assert_bool(_balance.coupon_pool.has(prize.card)).is_true()
		RewardMachine.Chute.REGISTER:
			assert_int(prize.kind).is_equal(MachinePrize.Kind.REGISTER)
			assert_bool(run.upgrades.has(prize.upgrade)).is_false()
		RewardMachine.Chute.UPGRADES:
			assert_int(prize.kind).is_equal(MachinePrize.Kind.UPGRADE)
			(
				assert_object(ItemUpgrades.chain_for(_balance.machine.item_upgrades, prize.card))
				. is_not_null()
			)


func _assert_pick_matches_preview(run: RunState, machine: RewardMachine, index: int) -> void:
	var preview: MachinePreview = machine.preview(run, index)
	var cards_before: Array[CardInstance] = run.deck.cards.duplicate()
	var owned: int = run.upgrades.size()
	var landing: MachineLanding = machine.pick(run, index)
	assert_object(landing).is_not_null()
	assert_object(landing.prize).is_same(preview.prize)
	match preview.prize.kind:
		MachinePrize.Kind.PRODUCT, MachinePrize.Kind.COUPON:
			assert_bool(preview.adds_card).is_true()
			assert_int(run.deck.size()).is_equal(cards_before.size() + 1)
			assert_object(landing.added.definition).is_same(preview.prize.card)
			assert_object(run.deck.cards[-1]).is_same(landing.added)
		MachinePrize.Kind.REGISTER:
			assert_int(preview.box_index).is_equal(owned)
			assert_int(landing.box_index).is_equal(owned)
			assert_object(run.upgrades[-1]).is_same(preview.prize.upgrade)
		MachinePrize.Kind.UPGRADE:
			assert_int(preview.copies).is_greater(0)
			assert_int(landing.upgraded.size()).is_equal(preview.copies)
			assert_int(run.deck.size()).is_equal(cards_before.size())
			for target: int in preview.copies:
				var old: CardInstance = landing.upgraded[target][0]
				var stepped: CardInstance = landing.upgraded[target][1]
				assert_object(old).is_same(preview.targets[target])
				assert_object(stepped.definition).is_same(preview.to_cards[target])
				assert_int(stepped.instance_id).is_equal(old.instance_id)
				assert_object(run.deck.cards[cards_before.find(old)]).is_same(stepped)
			for card: CardInstance in cards_before:
				if not preview.targets.has(card):
					assert_bool(run.deck.cards.has(card)).is_true()


## Picks the first prize of a STAMP DAY visit if one is waiting.
func _finish_stamp_day(run: RunState, machine: RewardMachine) -> void:
	var visit: MachineVisit = machine.current_visit()
	if visit != null and visit.kind == MachineVisit.Kind.STAMP_DAY:
		machine.pick(run, 0)


## A register picked from the machine after an earlier shift, as the history records it.
func _give_register(run: RunState, upgrade: UpgradeDefinition, shift_number: int) -> void:
	var record: ShiftRecord = ShiftRecord.new(shift_number, 10, 20)
	var visit: MachineVisit = MachineVisit.new(MachineVisit.Kind.TICKET)
	visit.chute = RewardMachine.Chute.REGISTER
	var prizes: Array[MachinePrize] = [
		MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, upgrade)
	]
	visit.set_drawn(prizes)
	visit.picked = 0
	record.visits.append(visit)
	run.history.append(record)
	run.upgrades.append(upgrade)


## Records a passed shift (1-based) and opens the machine after it.
func _pass(
	run: RunState, machine: RewardMachine, shift_number: int, inspected: bool = false
) -> void:
	var record: ShiftRecord = ShiftRecord.new(shift_number, 10, 20)
	if inspected:
		record.inspection = _balance.inspection_pool[0]
	run.history.append(record)
	run.shift_index = shift_number - 1
	machine.begin_after_checkout(run)


func _run(seed_value: int = 1) -> RunState:
	return RunState.new(seed_value, _starter, _balance, RunStock.starting(_starter, _balance))


func _machine(seed_value: int = 7, definition: MachineDefinition = null) -> RewardMachine:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_rngs[seed_value] = rng
	return RewardMachine.new(definition if definition != null else _balance.machine, rng)


func _saved(machine: RewardMachine) -> Dictionary:
	return JSON.parse_string(JSON.stringify(machine.to_dictionary()))


func _lookup() -> ContentLookup:
	return ContentLookup.new(_balance)


func _upgrade(id: String) -> UpgradeDefinition:
	return load("%s/%s.tres" % [UPGRADES_DIR, id])


func _upgrades(ids: Array[String]) -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for id: String in ids:
		found.append(_upgrade(id))
	return found


## Two odds cards print the same: shares, notes and guarantee.
func _assert_same_card(card: MachineOddsCard, expected: MachineOddsCard) -> void:
	assert_array(Array(card.rarity_share)).is_equal(Array(expected.rarity_share))
	assert_array(card.notes).is_equal(expected.notes)
	assert_bool(card.guarded).is_equal(expected.guarded)
	assert_float(card.p_rare_plus).is_equal_approx(expected.p_rare_plus, 1e-9)


func _key(prize: MachinePrize) -> String:
	return prize.key()


func _kind(visit: MachineVisit) -> int:
	return visit.kind


func _upgrade_of(prize: MachinePrize) -> UpgradeDefinition:
	return prize.upgrade
