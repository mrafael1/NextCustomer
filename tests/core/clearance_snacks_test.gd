extends GdUnitTestSuite
## Clearance and Snacks (#128 v3, the redraw tension, decided with the user on 2026-11-02):
## Clearance profits from what went wrong (Dusty toffees +3 per WASTED product before it, up to
## 3; Flickering bulb ×3 just after a WASTED product; Dented can +2 per card redrawn this
## shift), Snacks spread out and keep their redraws (Pick 'n' mix +3 per lone Snack, Bent lolly
## +2 per product to the nearest other Snack, up to 3; Crisps +3 per redraw left; Stale popcorn
## the next Snack ×1, +1 per redraw left, Golden ×2, +2 per redraw left). The redraws reach
## scoring as context (ScoreCredits.cards_redrawn and redraws_left, Scoring.total's): each redraw
## is a basket of 2. Live data: the numbers are placeholders for the end balance pass.

const CARDS := "res://data/cards/%s.tres"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"


func test_rows(
	row: String,
	redrawn: int,
	left: int,
	payouts: Array,
	_test_parameters := [
		# Two lone Bananas are WASTED: Dusty toffees 1 + 3 × 2.
		["banana,bread,banana,dusty_toffees", 0, 0, [2, 5, 2, 7]],
		# Four WASTED, counted up to 3: 1 + 9. Golden: 3 + 6 × 1.
		[
			"banana,bread,banana,bread,banana,bread,banana,dusty_toffees",
			0,
			0,
			[2, 5, 2, 5, 2, 5, 2, 10],
		],
		["banana,dusty_toffees_golden", 0, 0, [2, 9]],
		# Flickering bulb just after a WASTED product: 1 × 3; Golden 3 × 4.
		["banana,flickering_bulb", 0, 0, [2, 3]],
		["banana,flickering_bulb_golden", 0, 0, [2, 12]],
		# The bulb itself WASTED feeds the toffees after it.
		["bread,flickering_bulb,dusty_toffees", 0, 0, [5, 1, 4]],
		# Dented can: 2 + 2 per card redrawn (two redraws: 4 cards). Golden +4 each.
		["dented_can", 4, 0, [10]],
		["dented_can_golden", 2, 1, [12]],
		# Crisps: +3 per redraw left; Golden +6.
		["crisps", 0, 2, [8]],
		["crisps", 2, 1, [5]],
		["crisps", 4, 0, [2]],
		["crisps_golden", 0, 2, [16]],
		# Stale popcorn: the next Snack ×(1 + 1 per redraw left). 2 left: the Crisps' 8 × 3;
		# 1 left: 5 × 2; none: WASTED. Golden ×2 that: 5 × 4, 8 × 6, and ×2 with none left.
		["stale_popcorn,bread,crisps", 0, 2, [2, 5, 24]],
		["stale_popcorn,bread,crisps", 2, 1, [2, 5, 10]],
		["stale_popcorn,bread,crisps", 4, 0, [2, 5, 2]],
		["stale_popcorn_golden,bread,crisps", 2, 1, [4, 5, 20]],
		["stale_popcorn_golden,bread,crisps", 0, 2, [4, 5, 48]],
		["stale_popcorn_golden,bread,crisps", 4, 0, [4, 5, 4]],
		# Pick 'n' mix: the Crisps and itself are lone Snacks (1 + 3 × 2). Beside each other none is.
		["crisps,bread,pick_n_mix", 0, 0, [2, 5, 7]],
		["crisps,pick_n_mix", 0, 0, [2, 1]],
		["crisps,bread,pick_n_mix_golden", 0, 0, [2, 5, 15]],
		# Bent lolly: +2 per product between it and the nearest other Snack, up to 3.
		["bent_lolly,bread,potatoes,crisps", 0, 0, [6, 5, 3, 2]],
		["bent_lolly,bread,potatoes,bread,potatoes,crisps", 0, 0, [8, 5, 3, 5, 3, 2]],
		["crisps,bread,bent_lolly,potatoes,potatoes,pick_n_mix", 0, 0, [2, 5, 4, 3, 3, 10]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row), [], [], _credits(redrawn, left))
	assert_array(Array(result.payouts)).is_equal(payouts)
	# A total-only score (the simulator's) tracks the WASTED products and the redraws too.
	assert_int(Scoring.total(_row(row), [], [], redrawn, left)).is_equal(result.total)


func test_fizzles(
	row: String,
	left: int,
	wasted: Array,
	_test_parameters := [
		["bread,dusty_toffees", 0, [[1, "no WASTED item before it"]]],
		["bread,flickering_bulb", 0, [[1, "the item right before it was not WASTED"]]],
		["dented_can", 2, [[0, "no card redrawn this shift"]]],
		["crisps", 0, [[0, "no redraw left this shift"]]],
		[
			"stale_popcorn,bread,crisps",
			0,
			[[0, "no redraw left this shift"], [2, "no redraw left this shift"]],
		],
		["crisps,pick_n_mix", 1, [[1, "no lone Snack in the row"]]],
		["bent_lolly,bread", 0, [[0, "no other Snack in the row"]]],
		["bent_lolly,crisps", 1, [[0, "no item between it and the next Snack"]]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row), [], [], _credits(0, left))
	assert_array(_wasted(result)).is_equal(wasted)


## In place, the cards show no WASTED step.
func test_in_place_never_fizzle() -> void:
	for row: String in [
		"stale_popcorn,bread,crisps,potatoes,pick_n_mix", "bent_lolly,bread,crisps"
	]:
		assert_array(_wasted(Scoring.score(_row(row), [], [], _credits(0, 1)))).is_empty()
	assert_array(_wasted(Scoring.score(_row("dented_can"), [], [], _credits(2, 1)))).is_empty()


## Stale popcorn's ×N is a live step: with 1 redraw left its value is 2 and its percent 200 (the
## live factor's), on the armed step and on the multiplied Crisps alike.
func test_a_live_multiplier_names_its_percent() -> void:
	var result: ScoreResult = Scoring.score(
		_row("stale_popcorn,bread,crisps"), [], [], _credits(2, 1)
	)
	var armed: Array[ScoreStep] = _steps(result, ScoreStep.StepType.EFFECT_ARMED)
	assert_int(armed.size()).is_equal(1)
	assert_int(armed[0].percent).is_equal(200)
	# The receipt's arm line reads the step's factor, its ×N in amber.
	var popcorn: CardDefinition = load(CARDS % "stale_popcorn")
	assert_str(ReceiptInk.arm_words(armed[0], popcorn)).is_equal("arms ×2 next Snack")
	var golden: ScoreResult = Scoring.score(
		_row("stale_popcorn_golden,bread,crisps"), [], [], _credits(0, 2)
	)
	var golden_armed: ScoreStep = _steps(golden, ScoreStep.StepType.EFFECT_ARMED)[0]
	assert_str(ReceiptInk.arm_words(golden_armed, load(CARDS % "stale_popcorn_golden"))).is_equal(
		"arms ×6 next Snack"
	)
	var amber: RegEx = RegEx.create_from_string(ReceiptInk.AMBER_PATTERN)
	assert_str(amber.search("a ×1.5 b").get_string()).is_equal("×1.5")
	var multiplied: Array[ScoreStep] = _steps(result, ScoreStep.StepType.MULTIPLIER)
	assert_int(multiplied.size()).is_equal(1)
	assert_int(multiplied[0].slot).is_equal(2)
	assert_int(multiplied[0].value).is_equal(2)
	assert_str(multiplied[0].factor_text()).is_equal("2")
	assert_int(multiplied[0].value_after).is_equal(10)
	assert_str(EffectLinks.token_text(multiplied[0])).is_equal("×2")
	var equation: PaymentEquation = PaymentEquation.of(result.steps, 2)
	assert_str(equation.text("→")).is_equal("€5 × 2 → €10")


func test_percent_rounds_half_up(
	amount: int,
	factor_percent: int,
	expected: int,
	_test_parameters := [
		[7, 150, 11],
		[5, 150, 8],
		[8, 150, 12],
		[5, 175, 9],
		[4, 125, 5],
		[-7, 150, -11],
		[0, 250, 0],
	]
) -> void:
	assert_int(ScoreStep.times_percent(amount, factor_percent)).is_equal(expected)


func test_percent_words() -> void:
	assert_str(ScoreStep.percent_text(150)).is_equal("1.5")
	assert_str(ScoreStep.percent_text(175)).is_equal("1.75")
	assert_str(ScoreStep.percent_text(200)).is_equal("2")
	assert_str(ScoreStep.percent_text(325)).is_equal("3.25")


## The run passes its redraws to scoring: each redraw is a basket of the balance's 2 cards, and
## the redraws left are the shift's allowed ones less the used.
func test_run_counts_redraws() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(5, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	var allowed: int = run.redraws_allowed
	assert_int(ScoreCredits.for_run(run).cards_redrawn).is_equal(0)
	assert_int(ScoreCredits.for_run(run).redraws_left).is_equal(allowed)
	run.redraw_basket(0)
	assert_int(ScoreCredits.for_run(run).cards_redrawn).is_equal(balance.basket_size)
	assert_int(ScoreCredits.for_run(run).redraws_left).is_equal(allowed - 1)
	run.redraw_basket(1)
	assert_int(ScoreCredits.for_run(run).cards_redrawn).is_equal(2 * balance.basket_size)
	assert_int(ScoreCredits.for_run(run).redraws_left).is_equal(allowed - 2)


static func _credits(redrawn: int, left: int) -> ScoreCredits:
	var credits: ScoreCredits = ScoreCredits.new()
	credits.cards_redrawn = redrawn
	credits.redraws_left = left
	return credits


static func _steps(result: ScoreResult, type: ScoreStep.StepType) -> Array[ScoreStep]:
	var found: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.step_type == type:
			found.append(step)
	return found


static func _wasted(result: ScoreResult) -> Array:
	var found: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and not step.row_wide:
			found.append([step.slot, step.reason])
	return found


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % id) as CardDefinition, row.size() + 1))
	return row
