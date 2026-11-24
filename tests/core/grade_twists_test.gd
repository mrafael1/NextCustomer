extends GdUnitTestSuite
## The grade twists (#182, v1.49; full build plan 7.5): Shrinkflation (grade 2), Expiry dates
## (grade 3) and the Picky regular (grade 5), played by GradeRules on the run's GradeState; their
## events, their news, the run save's `grade_state` (v21 on), and the balance simulator's players.
## Uses the live balance and starter deck.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const MILK := "res://data/cards/milk.tres"
const EGGS := "res://data/cards/eggs.tres"
const BREAD_BIG := "res://data/cards/bread_big.tres"
const MILK_BIG := "res://data/cards/milk_big.tres"
const TWO_FOR_ONE := "res://data/cards/two_for_one.tres"

var _base: BalanceDefinition


func before_test() -> void:
	_base = load(BALANCE)


## Grade 2 adds Shrinkflation, grade 3 Expiry dates, grade 5 the Picky regular, each stacking up
## the ladder; the balance data lists none.
func test_the_twists_are_grade_data() -> void:
	assert_array(_base.twists).is_empty()
	assert_array(GradeApply.balance_for(_base, 1).twists).is_empty()
	var g2: BalanceDefinition = GradeApply.balance_for(_base, 2)
	assert_object(GradeRules.shrinkflation(g2)).is_not_null()
	assert_object(GradeRules.expiry(g2)).is_null()
	var g3: BalanceDefinition = GradeApply.balance_for(_base, 3)
	assert_object(GradeRules.shrinkflation(g3)).is_not_null()
	var dates: ExpiryTwist = GradeRules.expiry(g3)
	assert_int(dates.coupon_shifts).is_equal(8)
	assert_int(dates.item_shifts).is_equal(8)
	assert_int(dates.items_min).is_equal(1)
	assert_int(dates.items_max).is_equal(2)
	assert_object(GradeRules.picky(GradeApply.balance_for(_base, 4))).is_null()
	var g5: BalanceDefinition = GradeApply.balance_for(_base, 5)
	var picky: PickyRegularTwist = GradeRules.picky(g5)
	assert_object(picky).is_not_null()
	assert_int(g5.twists.size()).is_equal(3)
	var cut: FamilyPayCutRule = picky.event.rules[0] as FamilyPayCutRule
	assert_int(cut.pay_percent).is_equal(75)  # A day with no cut drawn (default_cut).
	assert_int(picky.default_cut()).is_equal(25)
	assert_array(picky.cut_options()).is_equal([15, 20, 25, 30])
	assert_int(picky.start_week).is_equal(2)
	# No grade cuts the boon days nor the machine's prizes.
	assert_array(Array(g5.boon_shifts)).is_equal(Array(_base.boon_shifts))
	assert_int(g5.machine.prizes_per_visit).is_equal(_base.machine.prizes_per_visit)


## At a week's end the product checked out most that week loses 1€ for the rest of the run, again
## each week it is the top one; a product at the floor (Eggs, 1€) never counts; the news says it.
func test_shrinkflation_shrinks_the_week_top_product() -> void:
	var run: RunState = _run(GradeApply.balance_for(_base, 2), 11)
	_end_week(run, [[BREAD, BREAD, EGGS, EGGS, EGGS], [BREAD, MILK]])
	assert_int(run.shift_index).is_equal(4)
	assert_int(run.twists.shrinks.get(&"bread", 0)).is_equal(1)
	assert_bool(run.twists.shrinks.has(&"eggs")).is_false()
	assert_str(GradeRules.notice(run)).is_equal("Shrinkflation: Bread -1€")
	assert_int(GradeRules.shrink_of(run, load(BREAD))).is_equal(1)
	# The checkout pays it 1€ less than the same shift at grade 1, as a step of its own.
	var plain: RunState = _run(GradeApply.balance_for(_base, 1), 11, 1)
	_end_week(plain, [[BREAD, BREAD, EGGS, EGGS, EGGS], [BREAD, MILK]])
	var bread: CardInstance = run.debug_add_to_hand(load(BREAD))
	run.place(bread, 0)
	plain.place(plain.debug_add_to_hand(load(BREAD)), 0)
	var result: ScoreResult = run.preview()
	assert_int(result.payouts[0]).is_equal(plain.preview().payouts[0] - 1)
	var shrunk: bool = false
	for step: ScoreStep in result.steps:
		shrunk = shrunk or step.text == "Shrinkflation" and step.value == -1
	assert_bool(shrunk).is_true()
	run.remove(bread)
	_end_week(run, [[MILK], [BREAD]])
	assert_int(run.twists.shrinks[&"bread"]).is_equal(2)
	assert_str(GradeRules.notice(run)).is_equal("Shrinkflation: Bread -1€")


## A tie is drawn with the run's RNG: the same seed picks the same product.
func test_a_shrink_tie_is_seeded() -> void:
	var picks: Array[StringName] = []
	for attempt: int in range(2):
		var run: RunState = _run(GradeApply.balance_for(_base, 2), 23)
		_end_week(run, [[BREAD, MILK], [BREAD, MILK]])
		assert_int(run.twists.shrinks.size()).is_equal(1)
		picks.append(run.twists.shrinks.keys()[0])
	assert_str(String(picks[0])).is_equal(String(picks[1]))


## A machine coupon plays 8 shifts, then leaves the deck as the 9th after it starts, with its
## news; the starter's cards never expire.
func test_a_coupon_expires_after_two_weeks() -> void:
	var run: RunState = _run(GradeApply.balance_for(_base, 3), 5, 3)
	var coupon: CardInstance = run.deck.add_card(load(TWO_FOR_ONE))
	GradeRules.on_added(run, coupon)  # Taken after shift 1's checkout.
	run.phase = RunState.Phase.SCORED
	assert_int(GradeRules.shifts_left(run, coupon)).is_equal(8)
	assert_int(GradeRules.shifts_left(run, run.deck.cards[0])).is_equal(-1)
	for shift: int in range(2, 10):
		_next(run)
		assert_bool(run.deck.cards.has(coupon)).override_failure_message(str(shift)).is_true()
	assert_int(run.shift_index + 1).is_equal(9)
	assert_int(GradeRules.shifts_left(run, coupon)).is_equal(1)
	var size: int = run.deck.size()
	_next(run)
	assert_bool(run.deck.cards.has(coupon)).is_false()
	assert_int(run.deck.size()).is_equal(size - 1)
	assert_str(GradeRules.notice(run)).contains("Expired: 2 for 1")
	assert_bool(run.twists.expiry.is_empty()).is_true()


## At a week's end one or two of the week's new products get a BEST BEFORE date 8 shifts after
## they were taken; the others and the starter's never expire.
func test_best_before_dates_some_new_items() -> void:
	var run: RunState = _run(GradeApply.balance_for(_base, 3), 31, 3)
	var added: Array[CardInstance] = []
	for path: String in [BREAD, MILK, EGGS]:
		var card: CardInstance = run.deck.add_card(load(path))
		run.shift_index = 1  # Taken after shift 2's checkout.
		GradeRules.on_added(run, card)
		added.append(card)
	_end_week(run, [[], []])
	var dated: int = 0
	for card: CardInstance in added:
		if run.twists.expiry.has(card.instance_id):
			dated += 1
			assert_int(run.twists.expiry[card.instance_id]).is_equal(10)
			assert_int(GradeRules.shifts_left(run, card)).is_equal(6)
	assert_int(dated).is_between(1, 2)
	assert_str(GradeRules.notice(run)).starts_with("Best before: ")
	assert_bool(run.twists.week_added.is_empty()).is_true()
	assert_int(run.twists.expiry.size()).is_equal(dated)


## The Picky regular: none in week 1, then a family per shift, never the same two shifts in a
## row, each day at its own cut, its items paying the rest (rounded down) as a day event of tone
## TWIST on the calendar's list.
func test_the_picky_regular_cuts_a_family() -> void:
	var run: RunState = _run(GradeApply.balance_for(_base, 5), 9, 5)
	var week: int = WeekSchedule.length(run.balance)
	for shift: int in range(1, week + 1):
		assert_str(GradeRules.picky_family(run, shift)).is_empty()
	assert_object(GradeRules.picky_event(run)).is_null()
	run.twists.picky[1] = "Dairy"  # A save from before v1.49's play test: week 1 still has none.
	assert_str(GradeRules.picky_family(run, 1)).is_empty()
	_end_week(run, [[MILK]])
	assert_int(run.shift_index + 1).is_equal(week + 1)
	for shift: int in range(week + 1, 2 * week + 1):
		assert_str(GradeRules.picky_family(run, shift)).is_not_empty()
		if shift > 1:
			var yesterday: String = GradeRules.picky_family(run, shift - 1)
			assert_str(GradeRules.picky_family(run, shift)).is_not_equal(yesterday)
	var event: InspectionDefinition = GradeRules.picky_event(run)
	assert_bool(event.is_twist()).is_true()
	assert_bool(WeekSchedule.shift_events(run).has(event)).is_true()
	assert_bool(WeekFlow.day_events(run).has(event)).is_true()
	# Read as a store promo (the user's play tests of 2026-11-24): the day's drawn cut, "-25%" on
	# its tag and chip, "price reduced by 25%" in its sentences.
	var family: String = GradeRules.picky_family(run)
	var today_cut: int = GradeRules.picky_cut(run)
	assert_int(today_cut).is_equal(run.twists.promo_cuts[run.shift_index + 1])
	assert_str(event.display_name).is_equal("Promo day")
	assert_str(event.notice_text).is_equal("%s price reduced by %d%%" % [family, today_cut])
	assert_str(event.chip_text).is_equal("-%d%% promo" % today_cut)
	var day_rule: FamilyPayCutRule = event.rules[0] as FamilyPayCutRule
	assert_str(day_rule.receipt_text).is_equal("-%d%%" % today_cut)
	assert_int(day_rule.pay_percent).is_equal(100 - today_cut)
	assert_int(GradeRules.picky_percent(run)).is_equal(100 - today_cut)
	assert_str(GradeRules.promo_text(run)).is_equal("-%d%%" % today_cut)
	assert_bool(GradeRules.picky(run.balance).event.notice_text.contains("{cut}")).is_true()
	# Bakery out of favour: Bread pays 75% (rounded down) of what it pays on a Frozen day.
	var bread: CardInstance = run.debug_add_to_hand(load(BREAD))
	var milk: CardInstance = run.debug_add_to_hand(load(MILK))
	run.place(bread, 0)
	run.place(milk, 1)
	var today: int = run.shift_index + 1
	run.twists.picky[today] = "Frozen"
	run.twists.promo_cuts[today] = 25
	run.twists.clear_events()
	var plain: ScoreResult = run.preview()
	run.twists.picky[today] = "Bakery"
	var result: ScoreResult = run.preview()
	assert_int(result.payouts[0]).is_equal(floori(plain.payouts[0] * 0.75))
	assert_int(result.payouts[1]).is_equal(plain.payouts[1])
	# Bread is on today's promo, Milk is not; a promo day's shift start stamps its tags on.
	assert_bool(GradeRules.on_promo(run, bread)).is_true()
	assert_bool(GradeRules.on_promo(run, milk)).is_false()
	assert_bool(GradeRules.promo_slot(run, result, 0, bread)).is_true()
	assert_bool(GradeRules.promo_slot(run, result, 1, milk)).is_false()
	var cut: ScoreStep = null
	for step: ScoreStep in result.steps:
		if step.slot == 0 and step.step_type == ScoreStep.StepType.PAYOUT_OVERRIDE:
			cut = step
	assert_object(cut).is_not_null()
	assert_str(cut.text).is_equal("-25%")
	# The step says it is a promo's cut, not a denial (the count-up's PROMO beat reads it).
	assert_int(cut.promo_cut).is_equal(25)
	assert_int(cut.to_dictionary().get("promo_cut", 0) as int).is_equal(25)
	run.twists.clear_fresh()
	GradeRules.start_shift(run)
	assert_bool(run.twists.fresh_promo).is_true()
	assert_bool(run.twists.has_fresh()).is_true()
	run.twists.clear_fresh()
	assert_bool(run.twists.has_fresh()).is_false()


## Each promo day draws its own cut from 15 to 30% in 5% steps with the run's RNG, as its family
## is drawn: two runs on one seed draw the same days, and the cuts vary; the cut pays
## floor(base * (100 - cut) / 100).
func test_each_promo_day_draws_its_cut() -> void:
	var balance: BalanceDefinition = GradeApply.balance_for(_base, 5)
	var seen: Dictionary[int, bool] = {}
	for seed_value: int in range(20, 26):
		var seeded: RunState = _run(balance, seed_value, 5)
		var twin: RunState = _run(balance, seed_value, 5)
		_end_week(seeded, [[MILK]])
		_end_week(twin, [[MILK]])
		assert_bool(seeded.twists.promo_cuts.is_empty()).is_false()
		assert_str(str(seeded.twists.promo_cuts)).is_equal(str(twin.twists.promo_cuts))
		assert_str(str(seeded.twists.picky)).is_equal(str(twin.twists.picky))
		for shift: int in seeded.twists.promo_cuts:
			var cut: int = seeded.twists.promo_cuts[shift]
			assert_bool(seeded.twists.picky.has(shift)).is_true()
			assert_int(cut).is_between(15, 30)
			assert_int(cut % 5).is_equal(0)
			seen[cut] = true
	assert_int(seen.size()).is_greater_equal(3)  # Random, not one fixed cut.
	# Bread on a -15% day and on a -30% day: floor(base * 85 / 100), floor(base * 70 / 100).
	var run: RunState = _run(balance, 9, 5)
	_end_week(run, [[MILK]])
	var bread: CardInstance = run.debug_add_to_hand(load(BREAD))
	run.place(bread, 0)
	var today: int = run.shift_index + 1
	run.twists.picky[today] = "Frozen"
	run.twists.clear_events()
	var plain: int = run.preview().payouts[0]
	run.twists.picky[today] = "Bakery"
	for cut: int in [15, 30]:
		run.twists.promo_cuts[today] = cut
		assert_int(run.preview().payouts[0]).is_equal(floori(plain * (100 - cut) / 100.0))
		assert_str(GradeRules.promo_text(run)).is_equal("-%d%%" % cut)
		assert_str(GradeRules.picky_event(run).notice_text).is_equal(
			"Bakery price reduced by %d%%" % cut
		)


## The grade's rule line reads the range of cuts ("-15 to -30% promo ..."), one cut's "-25%" when
## the range is one cut; a day's words put in its cut.
func test_the_rule_line_reads_the_cut_range() -> void:
	var lines: PackedStringArray = GradeApply.rule_lines(_base, 5)
	assert_str(lines[lines.size() - 1]).is_equal(
		"-15 to -30% promo on one family each shift from week 2"
	)
	var twist: PickyRegularTwist = PickyRegularTwist.new()
	twist.cut_min = 25
	twist.cut_max = 25
	assert_str(twist.format_text("{off} promo")).is_equal("-25% promo")
	assert_str(PickyRegularTwist.format_day("{off}, {cut}", 20)).is_equal("-20%, 20%")


## The run save keeps each promo day's cut (v23) and a resumed run plays it; a version 22 save
## (cuts fixed at 25%) reads with every promo day it names at -25%; a malformed cut is refused.
func test_the_promo_cuts_round_trip_and_migrate() -> void:
	var lookup: ContentLookup = ContentLookup.new(_base)
	var balance: BalanceDefinition = GradeApply.balance_for(_base, 5)
	var run: RunState = _run(balance, 41, 5)
	_end_week(run, [[MILK]])
	var today: int = run.shift_index + 1
	run.twists.promo_cuts[today] = 15
	run.twists.clear_events()
	var data: Dictionary = RunSave.to_dictionary(run, "run-2", 10)
	assert_int(int(data["format_version"])).is_equal(23)
	var save: RunSave = RunSave.from_dictionary(_json(data), lookup)
	assert_object(save).is_not_null()
	assert_str(str(save.run.twists.promo_cuts)).is_equal(str(run.twists.promo_cuts))
	assert_int(GradeRules.picky_cut(save.run)).is_equal(15)
	assert_str(GradeRules.promo_text(save.run)).is_equal("-15%")
	var again: Dictionary = RunSave.to_dictionary(save.run, save.run_id, save.run_ms)
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	var v22: Dictionary = _json(data)
	v22["format_version"] = RunSave.BEFORE_PROMO_CUTS_VERSION
	(v22["grade_state"] as Dictionary).erase("promo_cuts")
	var old: RunSave = RunSave.from_dictionary(v22, lookup)
	assert_object(old).is_not_null()
	assert_int(old.run.twists.promo_cuts.size()).is_equal(old.run.twists.picky.size())
	for shift: int in old.run.twists.picky:
		assert_int(old.run.twists.promo_cuts[shift]).is_equal(RunSaveMigration.V22_PROMO_CUT)
	assert_str(GradeRules.promo_text(old.run)).is_equal("-25%")
	assert_int(GradeRules.picky_percent(old.run)).is_equal(75)
	var bad: Dictionary = _json(data)
	(bad["grade_state"] as Dictionary)["promo_cuts"] = {str(today): 140}
	assert_object(RunSave.from_dictionary(bad, lookup)).is_null()
	(bad["grade_state"] as Dictionary)["promo_cuts"] = {str(today): "15"}
	assert_object(RunSave.from_dictionary(bad, lookup)).is_null()


## A run without twists keeps an empty state and draws as before: its saves have no grade_state.
func test_a_run_without_twists_is_unchanged() -> void:
	var run: RunState = _run(_base, 4)
	var plain: RunState = _run(_base, 4)
	_end_week(run, [[BREAD], [MILK]])
	_end_week(plain, [[BREAD], [MILK]])
	assert_bool(run.twists.is_empty()).is_true()
	assert_int(run.rng_state).is_equal(plain.rng_state)
	assert_array(GradeRules.day_events(run) + GradeRules.tail_events(run)).is_empty()
	var data: Dictionary = RunSave.to_dictionary(run, "run-0", 10)
	assert_bool(data.has("grade_state")).is_false()
	assert_int(int(data["format_version"])).is_equal(RunSave.FORMAT_VERSION)


## The run save keeps the twists' state (v21 on), and a resumed run plays it: its shrinks, dates,
## families and news; a version 20 save reads with none; a version 21 save of the 7-grade ladder
## reads with its grade mapped (its old grade 5, Shrinkflation and Expiry dates, is grade 3) and
## its state kept; a malformed state is refused.
func test_the_twist_state_round_trips_in_the_run_save() -> void:
	var lookup: ContentLookup = ContentLookup.new(_base)
	var balance: BalanceDefinition = GradeApply.balance_for(_base, 5)
	var run: RunState = _run(balance, 17, 5)
	assert_str(GradeRules.picky_family(run)).is_empty()  # Week 1 has none.
	var coupon: CardInstance = run.deck.add_card(load(TWO_FOR_ONE))
	GradeRules.on_added(run, coupon)
	_end_week(run, [[MILK], [BREAD, BREAD]])
	run.twists.picky[5] = "Dairy"  # Saved as it stands, even with no Picky regular in play.
	var data: Dictionary = RunSave.to_dictionary(run, "run-1", 10)
	assert_bool(data.has("grade_state")).is_true()
	var save: RunSave = RunSave.from_dictionary(_json(data), lookup)
	assert_object(save).is_not_null()
	var state: GradeState = save.run.twists
	assert_int(state.shrinks[&"bread"]).is_equal(1)
	assert_int(state.expiry[coupon.instance_id]).is_equal(9)
	assert_str(state.picky[5]).is_equal("Dairy")
	assert_str(GradeRules.notice(save.run)).is_equal(GradeRules.notice(run))
	assert_int(GradeRules.shrink_of(save.run, load(BREAD))).is_equal(1)
	var again: Dictionary = RunSave.to_dictionary(save.run, save.run_id, save.run_ms)
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	var older: Dictionary = data.duplicate()
	older.erase("grade_state")
	older["format_version"] = RunSave.BEFORE_TWISTS_VERSION
	older["grade"] = 3  # The 7-grade ladder's 1 less redraw: grade 1.
	var read: RunSave = RunSave.from_dictionary(_json(older), lookup)
	assert_object(read).is_not_null()
	assert_bool(read.run.twists.is_empty()).is_true()
	assert_int(read.run.grade).is_equal(1)
	var old_ladder: Dictionary = data.duplicate()
	old_ladder["format_version"] = RunSave.OLD_LADDER_VERSION
	old_ladder["grade"] = 5
	var mapped: RunSave = RunSave.from_dictionary(_json(old_ladder), lookup)
	assert_object(mapped).is_not_null()
	assert_int(mapped.run.grade).is_equal(3)
	assert_object(GradeRules.picky(mapped.run.balance)).is_null()
	assert_int(GradeRules.shrink_of(mapped.run, load(BREAD))).is_equal(1)
	assert_int(mapped.run.twists.expiry[coupon.instance_id]).is_equal(9)
	old_ladder["grade"] = 8
	assert_object(RunSave.from_dictionary(_json(old_ladder), lookup)).is_null()
	var bad: Dictionary = data.duplicate()
	bad["grade_state"] = {"shrinks": {"bread": "one"}}
	assert_object(RunSave.from_dictionary(_json(bad), lookup)).is_null()


## The balance simulator's players play every twist without a crash, and value an expiring
## coupon only for the share of the run it plays.
func test_the_simulator_plays_the_twists() -> void:
	var balance: BalanceDefinition = GradeApply.balance_for(_base, 5)
	var run: RunState = _run(balance, 3, 5)
	assert_float(GradeRules.lasting_share(run, load(TWO_FOR_ONE))).is_equal_approx(
		8.0 / (run.shift_count() - 1), 0.001
	)
	assert_float(GradeRules.lasting_share(run, load(BREAD))).is_equal(1.0)
	assert_float(GradeRules.lasting_share(_run(_base, 3), load(TWO_FOR_ONE))).is_equal(1.0)
	var search: SimRowSearch = SimRowSearch.new(balance)
	var player: SimPlayer = SimPlayer.new(load(STARTER), balance, search, "greedy@sensible", 1)
	player.grade = 5
	var record: SimRunRecord = player.play(5)
	assert_object(record).is_not_null()


## A run of `balance` on `seed_value`, started.
## An upgraded product loses its BEST BEFORE date and never gets one (the user's play test of
## 2026-11-24): the machine's upgrade keeps the card's instance id; a coupon keeps its date.
func test_an_upgrade_cancels_the_expiry_date() -> void:
	var run: RunState = _run(GradeApply.balance_for(_base, 3), 31, 3)
	var dated: CardInstance = run.deck.add_card(load(BREAD))
	var fresh: CardInstance = run.deck.add_card(load(MILK))
	var coupon: CardInstance = run.deck.add_card(load(TWO_FOR_ONE))
	run.twists.expiry[dated.instance_id] = 6
	GradeRules.on_added(run, fresh)
	GradeRules.on_added(run, coupon)
	var upgraded: CardInstance = run.deck.upgrade(dated, load(BREAD_BIG))
	GradeRules.on_upgraded(run, upgraded)
	GradeRules.on_upgraded(run, run.deck.upgrade(fresh, load(MILK_BIG)))
	GradeRules.on_upgraded(run, coupon)
	assert_int(GradeRules.shifts_left(run, upgraded)).is_equal(-1)
	assert_bool(run.twists.week_added.has(fresh.instance_id)).is_false()
	assert_int(GradeRules.shifts_left(run, coupon)).is_greater(0)


## A week's end leaves what it changed for the shift screen's stamps (GradeMoves): the product
## shrunk, the cards dated, the cards expired. A save never keeps them, so a resumed shift plays
## nothing again; the next shift start forgets them.
func test_a_shift_start_leaves_its_fresh_changes() -> void:
	var lookup: ContentLookup = ContentLookup.new(_base)
	var run: RunState = _run(GradeApply.balance_for(_base, 3), 31, 3)
	var bread: CardInstance = run.deck.add_card(load(BREAD))
	GradeRules.on_added(run, bread)
	var coupon: CardInstance = run.deck.add_card(load(TWO_FOR_ONE))
	run.twists.expiry[coupon.instance_id] = 4  # Its last shift is 4: it leaves as 5 starts.
	_end_week(run, [[BREAD, BREAD], [BREAD]])
	assert_bool(run.twists.has_fresh()).is_true()
	assert_bool(run.twists.fresh_shrunk.has(&"bread")).is_true()
	assert_bool(run.twists.fresh_dated.has(bread.instance_id)).is_true()
	assert_bool(run.twists.fresh_expired.has(coupon.definition)).is_true()
	var save: RunSave = RunSave.from_dictionary(
		_json(RunSave.to_dictionary(run, "run-2", 10)), lookup
	)
	assert_object(save).is_not_null()
	assert_bool(save.run.twists.has_fresh()).is_false()
	_next(run)
	assert_bool(run.twists.has_fresh()).is_false()


func _run(balance: BalanceDefinition, seed_value: int, grade: int = 2) -> RunState:
	var run: RunState = RunState.new(seed_value, load(STARTER), balance, RunStock.starting(balance))
	run.grade = grade if not balance.twists.is_empty() else 0
	run.start_shift()
	return run


## Plays out the current week as checked out with `rows` (card paths per shift, the last rows
## repeated), then starts the next week's first shift.
func _end_week(run: RunState, rows: Array) -> void:
	var first: int = WeekSchedule.first_shift(run.balance, run.shift_index + 1)
	var last: int = first + WeekSchedule.days_in(run.balance, run.shift_index + 1) - 1
	for shift: int in range(run.shift_index + 1, last + 1):
		var record: ShiftRecord = ShiftRecord.new(shift, 1, 1)
		var paths: Array = rows[mini(shift - first, rows.size() - 1)]
		for path: String in paths:
			record.played.append(load(path))
		run.history.append(record)
		if shift < last:
			_next(run)
	_next(run)


## Starts the next shift as after a passed checkout with no machine visit left.
func _next(run: RunState) -> void:
	run.phase = RunState.Phase.SCORED
	run.next_shift()


static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data
