extends GdUnitTestSuite
## #108 piece 2: the family perks and jackpots on the live data/upgrades/ files (plan section
## 3.8). The example rows' totals are the decision page's (docs/art/mockups/
## machine_loyalty_108.html, its scorer machine_loyalty_108_src/scorer.js on the same card
## numbers), so the game scores what the user chose from. Updated when perk numbers are tuned.

const UPGRADE_DIR := "res://data/upgrades"
const CARDS_DIR := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
## The page's five example rows.
const ROWS: Dictionary[String, String] = {
	"R1": "lemon,banana,banana,banana,strawberries,fruit_salad,milk",
	"R2": "coffee,milk,tea_bags,milk,eggs,bread,cheese",
	"R3": "opening_deal,milk,repeat,banana,banana,scissors,final_markdown",
	"R4":
	(
		"flickering_bulb,dented_can,reduced_yogurt,squashed_cake,dented_can,day_old_buns,"
		+ "final_markdown"
	),
	"R5": "banana,banana,banana,banana,banana,banana",
}
## Each row's total with no perk, then with each perk alone (scorer.js).
const TOTALS: Dictionary[String, Dictionary] = {
	"R1":
	{
		"": 40,
		"produce_regulars": 62,
		"breakfast_regulars": 40,
		"clearance_regulars": 40,
		"produce_aisle_run": 64,
		"breakfast_aisle_run": 40,
		"clearance_aisle_run": 40,
		"mixed_basket": 46,
		"bulk_deal": 52,
		"banana_stand": 59,
		"lemon_squeezer": 71,
		"fire_sale": 40,
		"produce_regulars_lv3": 106,
		"produce_aisle_run_lv3": 88,
	},
	"R2":
	{
		"": 57,
		"produce_regulars": 57,
		"breakfast_regulars": 86,
		"breakfast_aisle_run": 77,
		"mixed_basket": 69,
		"bulk_deal": 69,
		"banana_stand": 57,
	},
	"R3":
	{
		"": 55,
		"produce_regulars": 56,
		"mixed_basket": 94,
		"bulk_deal": 58,
		"produce_regulars_lv3": 58,
	},
	"R4":
	{
		"": 44,
		"clearance_regulars": 63,
		"clearance_aisle_run": 54,
		"mixed_basket": 53,
		"bulk_deal": 50,
		"fire_sale": 49,
	},
	"R5":
	{
		"": 42,
		"produce_regulars": 77,
		"produce_aisle_run": 66,
		"mixed_basket": 60,
		"bulk_deal": 147,
		"banana_stand": 42,
		"produce_regulars_lv3": 147,
		"produce_aisle_run_lv3": 90,
	},
}


## Every perk alone on the page's rows gives the page's total, and with no perk the rows score as
## on the page (the same card numbers).
func test_the_example_rows_score_as_on_the_decision_page() -> void:
	for row_key: String in TOTALS:
		var expected: Dictionary = TOTALS[row_key]
		for perk_id: String in expected:
			var perks: Array[UpgradeDefinition] = []
			if not perk_id.is_empty():
				perks.append(_upgrade(perk_id))
			var row: Array[CardInstance] = _row(ROWS[row_key])
			var message: String = "%s with %s" % [row_key, perk_id]
			var total: int = Scoring.score(row, perks).total
			assert_int(total).override_failure_message(message).is_equal(expected[perk_id])
			# The total-only path (the simulator's) agrees.
			assert_int(Scoring.total(row, perks)).override_failure_message(message).is_equal(total)


## Perks feed the Banana chain (the user's Q1 A, no ceiling): a perk's flat bonus is part of the
## price the next Banana adds. Produce regulars, Produce aisle run and Banana stand together on
## the page's rows.
func test_perks_feed_the_banana_chain() -> void:
	var stack: Array[UpgradeDefinition] = [
		_upgrade("produce_regulars"), _upgrade("produce_aisle_run"), _upgrade("banana_stand")
	]
	assert_int(Scoring.score(_row(ROWS["R1"]), stack).total).is_equal(173)
	assert_int(Scoring.score(_row(ROWS["R5"]), stack).total).is_equal(131)
	# Three Bananas with Produce regulars: 2; 2 + 2 + 1 = 5; 2 + 5 + 2 = 9 (the second link's
	# +1 is in the price the third adds).
	var regulars: Array[UpgradeDefinition] = [_upgrade("produce_regulars")]
	var result: ScoreResult = Scoring.score(_row("banana,banana,banana"), regulars)
	assert_array(Array(result.payouts)).is_equal([2, 5, 9])


## Banana stand: every Produce chains like a Banana, a Golden Banana's chain counting twice; a
## Banana chained by the stand has no WASTED step for its own lone chain; the stand's bonus is its
## step (from its loyalty box).
func test_banana_stand_chains_every_produce() -> void:
	var stand: Array[UpgradeDefinition] = [_upgrade("banana_stand")]
	# Strawberries (2 + 3 beside a Produce) = 5, then the Banana + 5.
	var result: ScoreResult = Scoring.score(_row("strawberries,banana"), stand)
	assert_array(Array(result.payouts)).is_equal([5, 7])
	assert_array(_wasted(result, 1)).is_empty()
	var bonus: ScoreStep = _upgrade_steps(result, ScoreStep.StepType.FLAT)[0]
	assert_int(bonus.slot).is_equal(1)
	assert_int(bonus.value).is_equal(5)
	assert_str(bonus.text).is_equal("Banana stand")
	# A Golden Banana (base 4) adds it twice.
	assert_array(Array(Scoring.score(_row("strawberries,banana_golden"), stand).payouts)).is_equal(
		[5, 14]
	)
	# Without the stand the Banana is alone.
	var plain: ScoreResult = Scoring.score(_row("strawberries,banana"))
	assert_array(Array(plain.payouts)).is_equal([5, 2])
	assert_array(_wasted(plain, 1)).is_not_empty()
	# No two Produce side by side: the stand fizzles on the row's last slot.
	var lone: ScoreResult = Scoring.score(_row("banana,bread"), stand)
	assert_array(_row_wasted(lone)).is_equal(["no two Produce products side by side"])


## Lemon squeezer: the Lemon's own charge stays the Lemon's; every later Produce past it takes x2
## as the perk's MULTIPLIER step, and the effect never reports unused charges.
func test_lemon_squeezer_reaches_every_later_produce() -> void:
	var squeezer: Array[UpgradeDefinition] = [_upgrade("lemon_squeezer")]
	var result: ScoreResult = Scoring.score(_row("lemon,bread,banana,strawberries"), squeezer)
	# Lemon 1, Bread 5, Banana 2 x2 (the Lemon's charge), Strawberries (2 + 3) x2 (the perk).
	assert_array(Array(result.payouts)).is_equal([1, 5, 4, 10])
	var reached: Array[ScoreStep] = _upgrade_steps(result, ScoreStep.StepType.MULTIPLIER)
	assert_int(reached.size()).is_equal(1)
	assert_int(reached[0].slot).is_equal(3)
	assert_int(reached[0].value).is_equal(2)
	assert_str(reached[0].text).is_equal("Lemon squeezer")
	assert_array(_row_wasted(result)).is_empty()
	# The Lemon's effect never reports unused charges.
	assert_array(_wasted(result, 0)).is_empty()
	# Only the Lemon's own charge used: the perk fizzles.
	var one: ScoreResult = Scoring.score(_row("lemon,banana"), squeezer)
	assert_array(_row_wasted(one)).is_equal(["no more Produce products after the Lemon"])
	# No Lemon: it fizzles too.
	var none: ScoreResult = Scoring.score(_row("banana,banana"), squeezer)
	assert_array(_row_wasted(none)).is_equal(["no Lemon in the row"])
	# A second Lemon (a Produce itself, so the first one's reach doubles it) resets the reach: it
	# starts again from the new Lemon.
	var two: ScoreResult = Scoring.score(_row("lemon,banana,lemon,banana,banana"), squeezer)
	# The last Banana: 2 + the previous Banana's payout 4 (a chain's first link), then x2.
	assert_array(Array(two.payouts)).is_equal([1, 4, 2, 4, 12])


## Fire sale: Squashed cake's x2 reaches every later Clearance product.
func test_fire_sale_reaches_every_later_clearance() -> void:
	var fire_sale: Array[UpgradeDefinition] = [_upgrade("fire_sale")]
	var row: String = "squashed_cake,dented_can,reduced_yogurt"
	var without: ScoreResult = Scoring.score(_row(row))
	var with_perk: ScoreResult = Scoring.score(_row(row), fire_sale)
	# The Dented can takes the cake's own x2 either way; the Reduced yogurt only with the perk.
	assert_int(with_perk.payouts[1]).is_equal(without.payouts[1])
	assert_int(with_perk.payouts[2]).is_equal(without.payouts[2] * 2)
	var none: ScoreResult = Scoring.score(_row("dented_can"), fire_sale)
	assert_array(_row_wasted(none)).is_equal(["no Squashed cake in the row"])


## Regulars, Aisle run, Mixed basket and Bulk deal fizzle on the row's last slot with their
## reasons when the row never meets their condition; an Aisle run follows adjacency, so a coupon
## between two Produce breaks the run.
func test_family_perks_fizzle_with_their_reasons() -> void:
	var row: Array[CardInstance] = _row("banana,bread")
	var cases: Dictionary[String, String] = {
		"produce_regulars": "fewer than two Produce products",
		"produce_aisle_run": "no 3 Produce products in a row",
		"bulk_deal": "no product with a copy before it",
	}
	for perk_id: String in cases:
		var perks: Array[UpgradeDefinition] = [_upgrade(perk_id)]
		var result: ScoreResult = Scoring.score(row, perks)
		assert_array(_row_wasted(result)).override_failure_message(perk_id).is_equal(
			[cases[perk_id]]
		)
	var mixed: Array[UpgradeDefinition] = [_upgrade("mixed_basket")]
	assert_array(_row_wasted(Scoring.score(_row("repeat"), mixed))).is_equal(
		["no family on the products"]
	)
	var run: Array[UpgradeDefinition] = [_upgrade("produce_aisle_run")]
	var broken: ScoreResult = Scoring.score(
		_row("banana,strawberries,final_markdown,fruit_salad"), run
	)
	assert_array(_row_wasted(broken)).is_equal(["no 3 Produce products in a row"])
	var whole: ScoreResult = Scoring.score(_row("banana,strawberries,fruit_salad,bread"), run)
	assert_array(_row_wasted(whole)).is_empty()
	var tripled: Array[ScoreStep] = _upgrade_steps(whole, ScoreStep.StepType.MULTIPLIER)
	assert_int(tripled.size()).is_equal(1)
	assert_int(tripled[0].slot).is_equal(2)
	assert_int(tripled[0].value).is_equal(3)


## A family perk fits the deck when its family is one of the deck's two most common families
## (ties with the second count; Food never does); a jackpot fits when the deck holds its product.
func test_family_perks_fit_the_top_two_families() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var families: PackedStringArray = balance.machine.families
	var deck: Array[CardDefinition] = _cards("banana,banana,banana,bread,bread,squashed_cake")
	# Produce 3, Bakery 3, Breakfast 2, Clearance 1.
	assert_array(Array(UpgradeDefinition.top_families(deck, families))).is_equal(
		["Bakery", "Produce"]
	)
	assert_bool(_upgrade("produce_regulars").fits(deck, families)).is_true()
	assert_bool(_upgrade("bakery_aisle_run").fits(deck, families)).is_true()
	assert_bool(_upgrade("breakfast_regulars").fits(deck, families)).is_false()
	assert_bool(_upgrade("banana_stand").fits(deck, families)).is_true()
	assert_bool(_upgrade("fire_sale").fits(deck, families)).is_true()
	assert_bool(_upgrade("lemon_squeezer").fits(deck, families)).is_false()
	assert_array(Array(UpgradeDefinition.top_families(_cards("repeat"), families))).is_empty()


## The machine offers a family perk only when the run's stock or deck holds a product of its
## family, and a jackpot only with its product (Snack perks join once Snack is stocked).
func test_the_draw_offers_family_perks_the_stock_holds() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var context: MachineContext = MachineContext.new()
	context.machine = balance.machine
	context.balance = balance
	context.products = _cards("banana,bread")
	context.upgrade_pool = [
		_upgrade("produce_regulars"),
		_upgrade("snack_regulars"),
		_upgrade("lemon_squeezer"),
		_upgrade("fire_sale"),
		_upgrade("bulk_deal"),
	]
	context.deck = Deck.new(null)
	context.deck.add_card(load("%s/squashed_cake.tres" % CARDS_DIR))
	var offered: Array[String] = []
	for pool: Array[MachinePrize] in context.pools(RewardMachine.Chute.UPGRADE):
		for prize: MachinePrize in pool:
			if prize.kind == MachinePrize.Kind.REGISTER:
				offered.append(String(prize.upgrade.id))
	assert_array(offered).contains_exactly_in_any_order(
		["produce_regulars", "fire_sale", "bulk_deal"]
	)


## WASTED reasons of the row-wide kind (an upgrade's condition never met), in order.
static func _row_wasted(result: ScoreResult) -> Array[String]:
	var found: Array[String] = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and step.row_wide:
			found.append(step.reason)
	return found


## The WASTED steps on one slot that aren't row-wide.
static func _wasted(result: ScoreResult, slot: int) -> Array[ScoreStep]:
	var found: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and step.slot == slot and not step.row_wide:
			found.append(step)
	return found


## The upgrade steps of one type.
static func _upgrade_steps(result: ScoreResult, step_type: ScoreStep.StepType) -> Array[ScoreStep]:
	var found: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.step_type == step_type and step.source_kind == ScoreStep.SourceKind.UPGRADE:
			found.append(step)
	return found


static func _upgrade(id: String) -> UpgradeDefinition:
	return load("%s/%s.tres" % [UPGRADE_DIR, id])


static func _cards(ids: String) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card_id: String in ids.split(","):
		found.append(load("%s/%s.tres" % [CARDS_DIR, card_id]))
	return found


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for definition: CardDefinition in _cards(ids):
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
