extends GdUnitTestSuite
## The RECEIPT REWARDS machine's logic (#77, build spec 1.6 and 9; #108's two chutes): prizes come
## from the chosen chute and a pick does what its preview says (issue #77 item 2), CLASSIC and
## PREMIUM visits and the odds that rise with the run's progress, the first-draw flags, the
## register cap and loyalty level-ups, the bonus ticket, the deck limit, clear_visits, reveal
## order, short draws and the machine's save form. Runs are built with the current RunState; the
## machine gets its own seeded RNG and the shift records are made here, so no checkout is played.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS_DIR := "res://data/cards"
const UPGRADES_DIR := "res://data/upgrades"
## The approved odds level after each shift (v0.47): shifts 1-2 level 0, 3-4 1, 5-6 2, 7 3.
const LEVEL_AFTER: Array[int] = [0, 0, 1, 1, 2, 2, 3]

var _balance: BalanceDefinition
var _starter: DeckDefinition
var _rngs: Dictionary = {}


func before() -> void:
	_balance = load(BALANCE)
	_starter = load(STARTER)


## Issue #77 item 2: both chutes, seeded, on a CLASSIC visit (after shift 1) and a PREMIUM one
## (after shift 3): the prizes come from the chosen chute, and picking one adds, stamps or upgrades
## exactly that item, as its preview said.
func test_prizes_come_from_the_chute_and_a_pick_does_what_its_preview_says() -> void:
	for chute: int in RewardMachine.CHUTES:
		for shift_number: int in [1, 3]:
			for seed_value: int in range(1, 13):
				var run: RunState = _run(seed_value)
				var machine: RewardMachine = _machine(seed_value)
				_pass(run, machine, shift_number)
				assert_bool(machine.choose(run, chute)).is_true()
				var prizes: Array[MachinePrize] = machine.prizes()
				assert_int(prizes.size()).is_equal(3)
				for prize: MachinePrize in prizes:
					_assert_from_chute(run, chute, prize)
				var index: int = seed_value % prizes.size()
				_assert_pick_matches_preview(run, machine, index)
				assert_int(run.history[-1].visits.size()).is_equal(1)
				assert_int(run.history[-1].visits[0].picked).is_equal(index)
				assert_int(run.history[-1].visits[0].chute).is_equal(chute)


## The ticket's visit after shifts 3, 5 and 7 is PREMIUM, CLASSIC after the others; both chutes
## are open either way. A PREMIUM draw is RARE or better, its products with a chain BIG or better.
func test_premium_and_classic_visits_per_shift() -> void:
	assert_array(Array(_balance.machine.premium_shifts)).is_equal([3, 5, 7])
	for shift_number: int in range(1, 8):
		var run: RunState = _run(shift_number)
		var machine: RewardMachine = _machine(shift_number)
		_pass(run, machine, shift_number)
		var premium: bool = [3, 5, 7].has(shift_number)
		var failure: String = "shift %d" % shift_number
		assert_bool(machine.is_premium()).override_failure_message(failure).is_equal(premium)
		var visit: MachineVisit = machine.current_visit()
		assert_bool(visit.premium).is_equal(premium)
		assert_str(RewardMachine.state_of(visit)).is_equal(
			RewardMachine.STATE_PREMIUM if premium else RewardMachine.STATE_CLASSIC
		)
		for chute: int in RewardMachine.CHUTES:
			var info: MachineChuteInfo = machine.chute_info(run, chute)
			assert_int(info.state).override_failure_message(failure).is_equal(
				RewardMachine.ChuteState.OPEN
			)
			assert_bool(info.premium).is_equal(premium)
			assert_bool(info.odds.premium).is_equal(premium)
		assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		if premium:
			_assert_premium_prizes(machine)
	assert_str(RewardMachine.state_for(true)).is_equal(RewardMachine.STATE_PREMIUM)
	assert_str(RewardMachine.state_for(false)).is_equal(RewardMachine.STATE_CLASSIC)
	_assert_premium_if_passed_matches_the_checkout()


## The bonus ticket's visit after a premium shift is PREMIUM too (v0.53): shift 3 inspected gives a
## PREMIUM ticket visit, then a PREMIUM BONUS visit with both chutes open; every visit can be
## binned. A bonus visit after a CLASSIC shift stays CLASSIC.
func test_the_bonus_visit_after_a_premium_shift_is_premium() -> void:
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 3, true)
	assert_bool(machine.is_premium()).is_true()
	assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	_assert_premium_prizes(machine)
	assert_bool(machine.can_bin()).is_true()
	assert_object(machine.pick(run, _perk_index(machine))).is_not_null()
	var bonus: MachineVisit = machine.current_visit()
	assert_int(bonus.kind).is_equal(MachineVisit.Kind.BONUS)
	assert_bool(bonus.premium).is_true()
	assert_bool(machine.is_premium()).is_true()
	assert_str(RewardMachine.state_of(bonus)).is_equal(RewardMachine.STATE_PREMIUM)
	for chute: int in RewardMachine.CHUTES:
		var info: MachineChuteInfo = machine.chute_info(run, chute)
		assert_int(info.state).is_equal(RewardMachine.ChuteState.OPEN)
	assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	_assert_premium_prizes(machine)
	assert_bool(machine.can_bin()).is_true()
	assert_object(machine.pick(run, 0)).is_not_null()
	assert_array(run.history[-1].visits.map(_premium)).is_equal([true, true])
	# A bonus visit after a shift that isn't premium (a bonus extra shift) is CLASSIC.
	var classic_run: RunState = _run()
	var extra: MachineDefinition = _balance.machine.duplicate() as MachineDefinition
	extra.bonus_extra_shifts = PackedInt32Array([2])
	var classic_machine: RewardMachine = _machine(7, extra)
	_pass(classic_run, classic_machine, 2)
	assert_bool(classic_machine.is_premium()).is_false()
	assert_bool(classic_machine.choose(classic_run, RewardMachine.Chute.UPGRADE)).is_true()
	assert_bool(classic_machine.bin(classic_run)).is_true()
	var classic_bonus: MachineVisit = classic_machine.current_visit()
	assert_int(classic_bonus.kind).is_equal(MachineVisit.Kind.BONUS)
	assert_bool(classic_bonus.premium).is_false()


## A full loyalty card (3 machine perks) still opens UPGRADE: its perks drawn are level-ups only,
## and taking one replaces the perk in its own box (the preview says so), so the card stays full.
## With every perk at its top level (or without levels) and nothing to improve, UPGRADE is EMPTY.
func test_a_full_card_levels_up_its_perks_in_their_boxes() -> void:
	var run: RunState = _run(5)
	var perks: Array[String] = ["coupon_engine", "extra_redraw", "big_basket"]
	for index: int in perks.size():
		_give_register(run, _upgrade(perks[index]), index + 1)
	var machine: RewardMachine = _machine(5)
	_pass(run, machine, 4)
	assert_int(RewardMachine.registers_picked(run)).is_equal(3)
	var upgrade: int = RewardMachine.Chute.UPGRADE
	assert_int(machine.chute_info(run, upgrade).state).is_equal(RewardMachine.ChuteState.OPEN)
	assert_bool(machine.choose(run, upgrade)).is_true()
	for prize: MachinePrize in machine.prizes():
		if prize.kind == MachinePrize.Kind.REGISTER:
			assert_bool(PerkLevels.is_level_up(prize.upgrade)).is_true()
	var index: int = _perk_index(machine)
	assert_int(index).is_not_equal(-1)
	var level_up: UpgradeDefinition = machine.prizes()[index].upgrade
	var box: int = PerkLevels.owned_index(run.upgrades, level_up)
	var preview: MachinePreview = machine.preview(run, index)
	assert_bool(preview.level_up).is_true()
	assert_int(preview.from_level).is_equal(1)
	assert_int(preview.box_index).is_equal(box)
	var landing: MachineLanding = machine.pick(run, index)
	assert_bool(landing.level_up).is_true()
	assert_int(landing.box_index).is_equal(box)
	assert_object(run.upgrades[box]).is_same(level_up)
	assert_int(level_up.level_number()).is_equal(2)
	assert_int(run.upgrades.size()).is_equal(3)
	assert_int(RewardMachine.registers_picked(run)).is_equal(3)
	assert_array(run.history[-1].level_ups()).is_equal([level_up])
	assert_array(run.history[-1].perks_added()).is_empty()
	# Top levels, a perk without levels and a cart nothing can step in: UPGRADE is EMPTY.
	var top: RunState = _golden_run()
	for index_given: int in perks.size():
		_give_register(top, _upgrade(perks[index_given]), index_given + 1)
	top.upgrades[0] = _upgrade("coupon_engine_lv3")
	top.upgrades[1] = _upgrade("extra_redraw_lv3")
	var top_machine: RewardMachine = _machine()
	_pass(top, top_machine, 4)
	assert_int(top_machine.chute_info(top, upgrade).state).is_equal(RewardMachine.ChuteState.EMPTY)
	assert_bool(top_machine.choose(top, upgrade)).is_false()
	assert_bool(top_machine.choose(top, RewardMachine.Chute.NEW_ITEMS)).is_true()


## v0.47: no Regular meter. Every visit after a shift draws at that shift's odds level (shifts 1-2
## level 0, 3-4 1, 5-6 2, 7 3; level 3's first drop at least RARE), whatever was picked or binned
## before: the ticket and the bonus ticket alike.
func test_the_odds_rise_with_the_run_progress() -> void:
	assert_array(Array(_balance.machine.shift_odds_levels).slice(0, 7)).is_equal(LEVEL_AFTER)
	var classic_only: MachineDefinition = _classic_only()
	classic_only.bonus_extra_shifts = PackedInt32Array([1, 2, 3, 4, 5, 6, 7])
	var run: RunState = _run()
	var machine: RewardMachine = _machine(7, classic_only)
	for shift_number: int in range(1, 8):
		_pass(run, machine, shift_number)
		var level: int = LEVEL_AFTER[shift_number - 1]
		assert_int(machine.odds_level(run)).is_equal(level)
		for chute: int in RewardMachine.CHUTES:
			var odds: MachineOddsCard = machine.chute_info(run, chute).odds
			assert_int(odds.level).override_failure_message("shift %d" % shift_number).is_equal(
				level
			)
		assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		assert_bool(machine.bin(run)).is_true()
		# The bonus visit draws at the same level: binning raised nothing.
		assert_int(machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
		var bonus_odds: MachineOddsCard = machine.chute_info(run, RewardMachine.Chute.UPGRADE).odds
		assert_int(bonus_odds.level).is_equal(level)
		assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
		assert_bool(machine.bin(run)).is_true()
		assert_int(machine.stage).is_equal(RewardMachine.Stage.IDLE)
	_pass(run, machine, 7)
	var top: MachineOddsCard = machine.chute_info(run, RewardMachine.Chute.NEW_ITEMS).odds
	assert_int(top.first_drop_min_rarity).is_equal(1)
	assert_float(top.first_share[MachinePrize.Rarity.COMMON]).is_equal(0.0)
	assert_int(_balance.machine.odds_levels[3].first_drop_min_rarity).is_equal(1)
	# The data's mapping: a shift past its end uses the last entry; none at all is level 0.
	assert_int(_balance.machine.odds_level_after(99)).is_equal(3)
	var empty: MachineDefinition = _balance.machine.duplicate() as MachineDefinition
	empty.shift_odds_levels = PackedInt32Array()
	assert_int(empty.odds_level_after(7)).is_equal(0)


## The register cap counts new perks picked from the machine only: a starting deck's upgrade and a
## level-up don't count; the card is full after 3 machine picks, and then UPGRADE draws only
## level-ups.
func test_the_register_cap_counts_machine_picks_only() -> void:
	for seed_value: int in range(1, 30):
		var run: RunState = _run(seed_value)
		run.upgrades.append(_upgrade("rule_bender"))
		_give_register(run, _upgrade("extra_redraw"), 1)
		_give_register(run, _upgrade("big_basket"), 2)
		assert_int(RewardMachine.registers_picked(run)).is_equal(2)
		var machine: RewardMachine = _machine(seed_value)
		_pass(run, machine, 3)
		assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
		var index: int = _perk_index(machine, true)
		if index == -1:
			continue
		assert_object(machine.pick(run, index)).is_not_null()
		assert_int(RewardMachine.registers_picked(run)).is_equal(3)
		assert_int(run.upgrades.size()).is_equal(4)
		_pass(run, machine, 4)
		assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
		var drawn: int = 0
		for prize: MachinePrize in machine.prizes():
			if prize.kind == MachinePrize.Kind.REGISTER:
				assert_bool(PerkLevels.is_level_up(prize.upgrade)).is_true()
				drawn += 1
		assert_int(drawn).is_greater(0)
		return
	fail("no draw offered a new perk")


## The run's first NEW ITEMS draw holds a first-offer coupon and spends both first-draw flags at
## the draw, whether the prizes are then picked or binned, and the flags stay spent across a save.
## While its prizes wait (and after a resume there), the chute's odds card is still the first
## draw's (the guarantee, the new-arrival note): the card the player confirmed. An UPGRADE draw
## spends neither.
func test_the_first_new_items_draw_spends_both_flags() -> void:
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 1)
	var new_items: int = RewardMachine.Chute.NEW_ITEMS
	assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	assert_bool(machine.coupons_first_done).is_false()
	assert_bool(machine.new_items_first_done).is_false()
	assert_bool(machine.bin(run)).is_true()
	_pass(run, machine, 2)
	var shown: MachineOddsCard = machine.chute_info(run, new_items).odds
	assert_bool(shown.guarded).is_true()
	assert_bool(machine.choose(run, new_items)).is_true()
	assert_bool(machine.coupons_first_done).is_true()
	assert_bool(machine.new_items_first_done).is_true()
	assert_bool(machine.current_visit().guarantee_held).is_true()
	var coupons: Array = machine.prizes().filter(
		func(prize: MachinePrize) -> bool: return prize.kind == MachinePrize.Kind.COUPON
	)
	assert_int(coupons.size()).is_equal(1)
	assert_bool(_balance.first_offer_pool.has((coupons[0] as MachinePrize).card)).is_true()
	_assert_same_card(machine.chute_info(run, new_items).odds, shown)
	var restored: RewardMachine = _machine()
	assert_bool(restored.restore_from(_saved(machine), _lookup())).is_true()
	assert_bool(restored.coupons_first_done).is_true()
	assert_bool(restored.new_items_first_done).is_true()
	_assert_same_card(restored.chute_info(run, new_items).odds, shown)
	# A later draw is no first draw: the card is the spent-flags one.
	assert_bool(machine.bin(run)).is_true()
	_pass(run, machine, 4)
	var later: MachineOddsCard = machine.chute_info(run, new_items).odds
	assert_bool(machine.choose(run, new_items)).is_true()
	_assert_same_card(machine.chute_info(run, new_items).odds, later)


## The bonus ticket: only after a passed inspected shift (why: the inspection) or a bonus extra
## shift (why: ""); after a premium shift a PREMIUM visit (v0.53); its odds reflect the first pick
## (an owned perk no longer drops as new).
func test_the_bonus_visit_follows_an_inspected_pass() -> void:
	var plain: RunState = _run()
	var plain_machine: RewardMachine = _machine()
	_pass(plain, plain_machine, 3)
	assert_array(plain_machine.pending_kinds()).is_empty()
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 3, true)
	assert_array(machine.pending_kinds()).is_equal([MachineVisit.Kind.BONUS])
	var upgrade: int = RewardMachine.Chute.UPGRADE
	assert_bool(machine.choose(run, upgrade)).is_true()
	var taken: UpgradeDefinition = machine.pick(run, _perk_index(machine)).register
	var visit: MachineVisit = machine.current_visit()
	assert_int(visit.kind).is_equal(MachineVisit.Kind.BONUS)
	assert_str(visit.why).is_equal(String(_balance.inspection_pool[0].id))
	assert_int(machine.stage).is_equal(RewardMachine.Stage.CHOOSE)
	var info: MachineChuteInfo = machine.chute_info(run, upgrade)
	assert_int(info.state).is_equal(RewardMachine.ChuteState.OPEN)
	for key: String in info.odds.in_draw:
		assert_bool(key.contains(":%s:" % taken.id)).is_false()
	# What the first pick changed here, for the bonus band (the UI only words it).
	assert_bool(info.first_pick_kept).is_true()
	assert_bool(info.first_pick_spent_coupon).is_false()
	var other: MachineChuteInfo = machine.chute_info(run, RewardMachine.Chute.NEW_ITEMS)
	assert_bool(other.first_pick_kept).is_false()
	# NEW ITEMS: the first pick spent the run's first-visit coupon only on the run's first NEW
	# ITEMS draw.
	var new_items: int = RewardMachine.Chute.NEW_ITEMS
	for earlier_draw: bool in [false, true]:
		var coupon_run: RunState = _run()
		var coupon_machine: RewardMachine = _machine(9, _classic_only())
		if earlier_draw:
			_pass(coupon_run, coupon_machine, 1)
			assert_bool(coupon_machine.choose(coupon_run, new_items)).is_true()
			assert_bool(coupon_machine.bin(coupon_run)).is_true()
		_pass(coupon_run, coupon_machine, 3, true)
		(
			assert_bool(coupon_machine.chute_info(coupon_run, new_items).first_pick_spent_coupon)
			. is_false()
		)
		assert_bool(coupon_machine.choose(coupon_run, new_items)).is_true()
		coupon_machine.pick(coupon_run, 0)
		assert_int(coupon_machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
		var coupon_info: MachineChuteInfo = coupon_machine.chute_info(coupon_run, new_items)
		assert_bool(coupon_info.first_pick_spent_coupon).is_equal(not earlier_draw)
		assert_bool(coupon_info.first_pick_kept).is_true()
	assert_bool(machine.choose(run, upgrade)).is_true()
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


## Big basket picked from the machine changes only the next shift's slots: the scored shift's
## limits stay, and no quota changes (plan v0.46, #106). (A CLASSIC visit: Big basket is COMMON, so
## a PREMIUM one never drops it.)
func test_big_basket_from_the_machine_changes_only_the_next_shift() -> void:
	var basket: UpgradeDefinition = _upgrade("big_basket")
	for seed_value: int in range(1, 40):
		var run: RunState = _run(seed_value)
		run.upgrades = _upgrades(["coupon_engine", "category_engine", "extra_redraw"])
		run.shift_index = 2
		run.start_shift()
		var scored: ShiftLimits = run.limits
		var scored_quota: int = run.quota()
		var machine: RewardMachine = _machine(seed_value, _classic_only())
		_pass(run, machine, 3, true)
		assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
		var index: int = machine.prizes().map(_upgrade_of).find(basket)
		if index == -1:
			continue
		assert_object(machine.pick(run, index)).is_not_null()
		assert_object(run.limits).is_same(scored)
		assert_int(run.quota()).is_equal(scored_quota)
		var without: Array[UpgradeDefinition] = run.upgrades.slice(0, 3)
		var plain_next: ShiftLimits = ShiftLimits.for_shift(_balance, without, 3)
		run.shift_index = 3
		run.start_shift()
		assert_int(run.limits.slot_count).is_equal(plain_next.slot_count + 1)
		assert_int(run.quota()).is_equal(plain_next.quota)
		return
	fail("no draw offered Big basket")


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
	assert_bool(machine.chute_info(run, RewardMachine.Chute.UPGRADE).cart_full).is_false()
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


## clear_visits (a debug jump) from CHOOSE and from PICK: queue, visit and stage cleared; the
## first-draw flags stay.
func test_clear_visits_empties_the_queue() -> void:
	for draw_first: bool in [false, true]:
		var run: RunState = _run()
		var machine: RewardMachine = _machine()
		machine.coupons_first_done = true
		_pass(run, machine, 3, true)
		if draw_first:
			assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
		machine.clear_visits()
		assert_int(machine.stage).is_equal(RewardMachine.Stage.IDLE)
		assert_object(machine.current_visit()).is_null()
		assert_array(machine.pending_kinds()).is_empty()
		assert_array(machine.prizes()).is_empty()
		assert_bool(machine.coupons_first_done).is_true()
		_pass(run, machine, 4)
		assert_int(machine.stage).is_equal(RewardMachine.Stage.CHOOSE)


## Prizes are in reveal order (rarity ascending, drop order within a rarity); drop_order keeps
## the draw's own order, which is what MachineDraw.draw returns from the same RNG state at the
## shift's odds level.
func test_reveal_order_and_drop_order() -> void:
	var classic_only: MachineDefinition = _classic_only()
	for seed_value: int in range(1, 30):
		var run: RunState = _run(seed_value)
		var machine: RewardMachine = _machine(seed_value, classic_only)
		var shift_number: int = 1 + seed_value % 7
		var chute: int = RewardMachine.CHUTES[seed_value % 2]
		_pass(run, machine, shift_number)
		var copy: RandomNumberGenerator = RandomNumberGenerator.new()
		copy.state = (_rngs[seed_value] as RandomNumberGenerator).state
		var context: MachineContext = MachineContext.from_run(run, classic_only, false, false)
		var level: int = LEVEL_AFTER[shift_number - 1]
		var expected: Array[MachinePrize] = MachineDraw.draw(chute, context, level, copy)
		assert_bool(machine.choose(run, chute)).is_true()
		var visit: MachineVisit = machine.current_visit()
		assert_array(visit.in_drop_order().map(_key)).is_equal(expected.map(_key))
		for index: int in range(1, visit.prizes.size()):
			assert_int(visit.prizes[index].rarity).is_greater_equal(visit.prizes[index - 1].rarity)


## Short draws (UPGRADE with one new perk left, every owned one at its top level and nothing to
## improve) pick and save like full ones.
func test_short_draws_pick_and_save() -> void:
	var run: RunState = _golden_run()
	run.upgrades = _upgrades(
		["coupon_engine_lv3", "category_engine_lv3", "extra_redraw_lv3", "slot_engine_lv3"]
	)
	var machine: RewardMachine = _machine()
	_pass(run, machine, 3)
	assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	var prizes: Array[MachinePrize] = machine.prizes()
	assert_int(prizes.size()).is_equal(1)
	var restored: RewardMachine = _machine()
	assert_bool(restored.restore_from(_saved(machine), _lookup())).is_true()
	assert_array(restored.prizes().map(_key)).is_equal(prizes.map(_key))
	var picked: UpgradeDefinition = restored.pick(run, 0).register
	assert_object(picked).is_same(prizes[0].upgrade)
	assert_object(picked).is_same(_upgrade("big_basket"))


## The machine's save form round-trips at CHOOSE (a PREMIUM visit with a bonus queued) and PICK,
## with no Regular levels and the visit's state and the played perks kept; a save that doesn't fit
## is refused without changing the machine.
func test_the_save_form_round_trips_and_bad_fields_are_refused() -> void:
	var run: RunState = _run()
	run.upgrades = _upgrades(["coupon_engine"])
	var machine: RewardMachine = _machine()
	_pass(run, machine, 3, true)
	for stage: int in [RewardMachine.Stage.CHOOSE, RewardMachine.Stage.PICK]:
		if stage == RewardMachine.Stage.PICK:
			assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
		var saved: Dictionary = _saved(machine)
		assert_bool(saved.has("levels")).is_false()
		assert_bool(saved["visit"]["premium"]).is_true()
		assert_array(saved["played_upgrades"]).is_equal(["coupon_engine"])
		assert_bool((saved["visit"] as Dictionary).has("level_before")).is_false()
		var restored: RewardMachine = _machine()
		assert_bool(restored.restore_from(saved, _lookup())).is_true()
		assert_dict(_saved(restored)).is_equal(saved)
		assert_int(restored.stage).is_equal(stage)
		assert_bool(restored.is_premium()).is_true()
		assert_array(restored.played_upgrades).is_equal(run.upgrades)
	var good: Dictionary = _saved(machine)
	var bad: Array[Dictionary] = []
	for change: Array in [
		["stage", "dance"],
		["stage", "choose"],
		["stage", "idle"],
		["queue", ["ticket"]],
		["queue", ["stamp_day"]],
		["visit", {}],
		["coupons_first_done", "yes"],
		["first_draw", "yes"],
		["played_upgrades", ["gone"]],
	]:
		var copy: Dictionary = good.duplicate(true)
		copy[change[0]] = change[1]
		bad.append(copy)
	var no_prizes: Dictionary = good.duplicate(true)
	no_prizes["visit"]["prizes"] = []
	no_prizes["visit"]["drop_order"] = []
	bad.append(no_prizes)
	var missing: Dictionary = good.duplicate(true)
	missing.erase("played_upgrades")
	bad.append(missing)
	# A STAMP DAY visit, an old chute name, and no state at all.
	var stamp_day: Dictionary = good.duplicate(true)
	stamp_day["visit"]["kind"] = "stamp_day"
	bad.append(stamp_day)
	var old_chute: Dictionary = good.duplicate(true)
	old_chute["visit"]["chute"] = "register"
	bad.append(old_chute)
	var stateless: Dictionary = good.duplicate(true)
	(stateless["visit"] as Dictionary).erase("premium")
	bad.append(stateless)
	for data: Dictionary in bad:
		var untouched: RewardMachine = _machine()
		untouched.new_items_first_done = true
		(
			assert_bool(untouched.restore_from(data, _lookup()))
			. override_failure_message(str(data))
			. is_false()
		)
		assert_bool(untouched.new_items_first_done).is_true()
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
	for chute: int in RewardMachine.CHUTES:
		var first: RewardMachine = _machine(98)
		var second: RewardMachine = _machine(97)
		(_rngs[98] as RandomNumberGenerator).state = state
		(_rngs[97] as RandomNumberGenerator).state = state
		assert_bool(first.restore_from(saved, _lookup())).is_true()
		assert_bool(second.restore_from(saved, _lookup())).is_true()
		assert_bool(first.choose(run, chute)).is_true()
		assert_bool(second.choose(run, chute)).is_true()
		assert_array(second.prizes().map(_key)).is_equal(first.prizes().map(_key))
	assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	assert_bool(resumed.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	assert_array(resumed.prizes().map(_key)).is_equal(machine.prizes().map(_key))


## A shift's record saves its visits (an empty list when there are none, #77 C3) and reads them
## back.
func test_shift_records_save_their_visits() -> void:
	var lookup: ContentLookup = _lookup()
	assert_array(ShiftRecord.new(1, 10, 20).to_dictionary()["visits"]).is_empty()
	var run: RunState = _run()
	var machine: RewardMachine = _machine()
	_pass(run, machine, 3, true)
	assert_bool(machine.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	var register: UpgradeDefinition = machine.pick(run, _perk_index(machine)).register
	assert_bool(machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_object(machine.pick(run, 0)).is_not_null()
	var record: ShiftRecord = run.history[-1]
	assert_int(record.cards_added().size()).is_equal(1)
	assert_int(record.registers_taken().size()).is_equal(1)
	assert_object(record.registers_taken()[0]).is_same(register)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(record.to_dictionary()))
	var read: ShiftRecord = ShiftRecord.from_dictionary(saved, lookup)
	assert_object(read).is_not_null()
	assert_dict(read.to_dictionary()).is_equal(record.to_dictionary())
	assert_bool(read.visits[0].premium).is_true()
	assert_bool(read.visits[1].premium).is_true()
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
			if prize.kind == MachinePrize.Kind.COUPON:
				assert_bool(_balance.coupon_pool.has(prize.card)).is_true()
				return
			assert_int(prize.kind).is_equal(MachinePrize.Kind.PRODUCT)
			var plain: CardDefinition = prize.card
			if plain.tier != CardDefinition.Tier.PLAIN:
				plain = plain.variant_of
			assert_bool(run.stock.cards.has(plain)).is_true()
		RewardMachine.Chute.UPGRADE:
			if prize.kind == MachinePrize.Kind.REGISTER:
				assert_bool(run.upgrades.has(prize.upgrade)).is_false()
				return
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
			assert_bool(preview.level_up).is_false()
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


## Every waiting prize is RARE or better, and a product with a chain BIG or better.
func _assert_premium_prizes(machine: RewardMachine) -> void:
	for prize: MachinePrize in machine.prizes():
		assert_int(prize.rarity).override_failure_message(prize.key()).is_greater_equal(
			MachinePrize.Rarity.RARE
		)
		if MachineDraw.chain_of(machine.machine, prize) != null:
			assert_int(prize.card.tier).override_failure_message(prize.key()).is_not_equal(
				CardDefinition.Tier.PLAIN
			)


## The PREMIUM NEXT announce's query (v0.50): premium_if_passed, asked during a shift's planning,
## agrees with the ticket visit that shift's passed checkout opens (is_premium): the data's premium
## shifts (3, 5, 7) say yes, the others no, and the last shift (no machine) no; it changes nothing
## on the machine.
func _assert_premium_if_passed_matches_the_checkout() -> void:
	var last: int = _balance.quotas.size()
	for shift_number: int in range(1, last + 1):
		var run: RunState = _run()
		var machine: RewardMachine = _machine()
		run.shift_index = shift_number - 1
		var announced: bool = machine.premium_if_passed(run)
		assert_object(machine.current_visit()).is_null()
		var failure: String = "shift %d" % shift_number
		var expected: bool = shift_number < last and _balance.machine.is_premium_shift(shift_number)
		assert_bool(announced).override_failure_message(failure).is_equal(expected)
		if shift_number == last:
			continue
		_pass(run, machine, shift_number)
		assert_bool(machine.is_premium()).override_failure_message(failure).is_equal(announced)


## The reveal index of the first loyalty perk waiting (with `new_only`, the first that isn't a
## level-up), or -1.
func _perk_index(machine: RewardMachine, new_only: bool = false) -> int:
	var prizes: Array[MachinePrize] = machine.prizes()
	for index: int in prizes.size():
		if prizes[index].kind != MachinePrize.Kind.REGISTER:
			continue
		if not new_only or not PerkLevels.is_level_up(prizes[index].upgrade):
			return index
	return -1


## A loyalty perk picked from the machine after an earlier shift, as the history records it.
func _give_register(run: RunState, upgrade: UpgradeDefinition, shift_number: int) -> void:
	var record: ShiftRecord = ShiftRecord.new(shift_number, 10, 20)
	var visit: MachineVisit = MachineVisit.new(MachineVisit.Kind.TICKET)
	visit.chute = RewardMachine.Chute.UPGRADE
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
	return RunState.new(seed_value, _starter, _balance, RunStock.starting(_balance))


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


## The machine data without premium shifts: every visit is CLASSIC.
func _classic_only() -> MachineDefinition:
	var definition: MachineDefinition = _balance.machine.duplicate() as MachineDefinition
	definition.premium_shifts = PackedInt32Array()
	return definition


## A run whose cart holds nothing an item upgrade can step (a GOLDEN copy and a coupon).
func _golden_run() -> RunState:
	var run: RunState = _run()
	run.deck = Deck.new(RandomNumberGenerator.new())
	run.deck.add_card(load("%s/eggs_golden.tres" % CARDS_DIR))
	# A coupon: since v0.52 every product has a chain (the capsule products too), so nothing
	# else in the cart can step.
	run.deck.add_card(load("%s/repeat.tres" % CARDS_DIR))
	return run


func _premium(visit: MachineVisit) -> bool:
	return visit.premium
