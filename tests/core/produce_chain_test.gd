extends GdUnitTestSuite
## Produce links (#128, family identities, approved by the user on 2026-11-02): only Bananas are
## the chain (CardChain: 2 or more Bananas linked one after another, any tier), and each other
## Produce helper has one place by it. Strawberries feed it (just before its first Banana: +1 to
## every Banana of it, carried down the links), Lemon is its knot (between two Bananas: the
## Banana after it chains on the Banana before it, that link's bonus ×2, Golden ×3, carried as a
## flat bonus), Wonky carrot cashes it in (just after its last Banana: +2 per Banana), and Fruit
## salad counts Produce kinds (+3 per different Produce product before it). Anywhere else each
## helper fizzles with a reason. Live data: the numbers are placeholders for the end balance
## pass, so a tuning change updates these rows.

const CARDS := "res://data/cards/%s.tres"
const UPGRADES := "res://data/upgrades/%s.tres"


func test_chain_rows(
	row: String,
	payouts: Array,
	_test_parameters := [
		# Spec row 1: Strawberries' +1 lands on every Banana before its price, so it carries:
		# 2; 2 + 1; 2 + 3 + 1; 2 + 6 + 1; the carrot 2 + 2 × 3 = 28.
		["strawberries,banana,banana,banana,wonky_carrot", [2, 3, 6, 9, 8]],
		# Spec row 2: the knot doubles the link across it (2 + 4 × 2), and the doubled price
		# carries (2 + 10); the carrot counts 4 Bananas (the Lemon is no Banana) = 39.
		["banana,banana,lemon,banana,banana,wonky_carrot", [2, 4, 1, 10, 12, 10]],
		# Spec row 3: Fruit salad counts 3 kinds (Strawberries, Banana, Wonky carrot) = 28.
		["strawberries,banana,banana,wonky_carrot,fruit_salad", [2, 3, 6, 6, 11]],
		# Spec row 4: the Golden Lemon's knot is ×3: 2 + 2 × 3 = 13.
		["banana,lemon_golden,banana", [2, 3, 8]],
		# The knot carries down every later link: 2 + 2 × 2, then 2 + 6.
		["banana,lemon,banana,banana", [2, 1, 6, 8]],
		# A knot just before a Golden Banana: its own ×2 times the knot's ×2 (4 + 2 × 2 × 2).
		["banana,lemon,banana_golden", [2, 1, 12]],
		# Golden Strawberries: +2 on every Banana. Golden Wonky carrot: +4 per Banana.
		["strawberries_golden,banana,banana", [4, 4, 8]],
		["banana,banana,wonky_carrot_golden", [2, 4, 12]],
		# Big tiers keep the plain numbers on a bigger base.
		["strawberries_big,banana,banana,wonky_carrot_big", [4, 3, 6, 8]],
		["banana,lemon_big,banana", [2, 3, 6]],
		# Fruit salad: a whole chain is one kind (tiers count as their plain card), the Potatoes
		# another: 2 + 3 × 2. Golden Fruit salad: +6 per kind (Banana, Lemon).
		["banana,banana_big,banana_golden,potatoes,fruit_salad", [2, 6, 16, 3, 8]],
		["banana,lemon,fruit_salad_golden", [2, 1, 16]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).is_equal(result.total)


## Every row of test_chain_rows that has each helper in its place shows no WASTED step.
func test_helpers_in_place_never_fizzle() -> void:
	for row: String in [
		"strawberries,banana,banana,banana,wonky_carrot",
		"banana,banana,lemon,banana,banana,wonky_carrot",
		"banana,lemon_golden,banana",
	]:
		assert_array(_wasted(Scoring.score(_row(row)))).is_empty()


## Out of place, a helper fizzles: a WASTED step that says why, the total unchanged.
func test_misplaced_helpers_fizzle(
	row: String,
	payouts: Array,
	wasted: Array,
	_test_parameters := [
		# Spec row 5, the teaching row: every helper in the wrong place = 9.
		[
			"lemon,banana,banana,strawberries",
			[1, 2, 4, 2],
			[[0, "not inside a CHAIN"], [3, "no CHAIN right after it"]],
		],
		# Strawberries before a lone Banana: no chain just after it, and the Banana is lone.
		[
			"strawberries,banana",
			[2, 2],
			[[0, "no CHAIN right after it"], [1, "no Banana beside it"]],
		],
		# Strawberries between a lone Banana and a chain still feed the chain after them.
		[
			"banana,strawberries,banana,banana",
			[2, 2, 3, 6],
			[[0, "no Banana beside it"]],
		],
		# Wonky carrot after a lone Banana, or after no Banana at all.
		[
			"banana,wonky_carrot",
			[2, 2],
			[[0, "no Banana beside it"], [1, "no CHAIN right before it"]],
		],
		["potatoes,wonky_carrot", [3, 2], [[1, "no CHAIN right before it"]]],
		# Two Lemons side by side tie nothing: both fizzle, and each Banana is lone.
		[
			"banana,lemon,lemon,banana",
			[2, 1, 1, 2],
			[
				[0, "no Banana beside it"],
				[1, "not inside a CHAIN"],
				[2, "not inside a CHAIN"],
				[3, "no Banana beside it"],
			],
		],
		# A Lemon with a Banana on one side only.
		[
			"banana,banana,lemon",
			[2, 4, 1],
			[[2, "not inside a CHAIN"]],
		],
		# Fruit salad with no Produce before it (unchanged).
		[
			"fruit_salad,banana",
			[2, 2],
			[[0, "no Produce item before it"], [1, "no Banana beside it"]]
		],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_array(_wasted(result)).is_equal(wasted)


## A knot counts as beside for the lone-Banana fizzle: a Banana tied by a Lemon is never lone.
func test_a_knot_counts_as_beside() -> void:
	assert_array(_wasted(Scoring.score(_row("banana,lemon,banana")))).is_empty()


## The knot's link is the chain's only: adjacency (products_before, which every other adjacency
## rule reads) still has the Lemon between the two Bananas.
func test_knots_are_chain_only() -> void:
	var state := ScoreState.new(_row("banana,lemon,banana"))
	for slot: int in range(state.size()):
		for rule: Rule in state.definition(slot).rules:
			rule.modify_chain(state, slot)
	assert_array(Array(state.products_before(2))).is_equal([1])
	assert_array(Array(state.products_beside(0))).is_equal([1])
	assert_array(Array(CardChain.linked_before(state, 2))).is_equal([1, 0])
	assert_int(CardChain.knot_between(state, 0, 2)).is_equal(1)
	assert_bool(CardChain.is_knot(state, 1)).is_true()
	assert_array(Array(CardChain.members(state, 0))).is_equal([0, 2])
	# Yogurt (+3 just after a Banana) never sees a Banana across a knot.
	var yogurt: ScoreResult = Scoring.score(_row("banana,lemon,banana,lemon,yogurt"))
	assert_int(yogurt.payouts[4]).is_equal(_card("yogurt").base)


## A connector's link joins a chain like adjacency: Strawberries feed both Bananas of a 2 for 1
## pair, and the carrot counts both (2 + 3 + 1 = 6, ×2 = 12; 2 + 2 × 2 = 6).
func test_connectors_link_a_chain() -> void:
	var result: ScoreResult = Scoring.score(
		_row("strawberries,banana,two_for_one,banana,wonky_carrot")
	)
	assert_array(Array(result.payouts)).is_equal([2, 3, 0, 12, 6])
	assert_array(_wasted(result)).is_empty()
	assert_array(_chains(result)).is_equal([[1, 3]])


## The score records every chain for the belt (ScoreResult.chains), in slot order with its knots,
## plain Banana pairs too; a lone Banana is in none. A total-only score records none.
func test_chains_are_recorded() -> void:
	(
		assert_array(_chains(Scoring.score(_row("banana,banana,lemon,banana,banana,wonky_carrot"))))
		. is_equal([[0, 1, 2, 3, 4]])
	)
	assert_array(_chains(Scoring.score(_row("banana,banana,eggs,banana,banana")))).is_equal(
		[[0, 1], [3, 4]]
	)
	assert_array(_chains(Scoring.score(_row("banana,eggs,banana")))).is_empty()


## The knot's link is the Banana chain's FLAT step, its giver the Banana before the knot.
func test_the_knot_link_is_one_flat_step() -> void:
	var flats: Array = []
	for step: ScoreStep in Scoring.score(_row("banana,lemon,banana")).steps:
		if step.step_type == ScoreStep.StepType.FLAT:
			flats.append([step.slot, step.value, step.text, step.support_slot])
	assert_array(flats).is_equal([[2, 4, "Banana chain", 0]])


## The carrot's bonus names the chain's last Banana as its giver; Strawberries arm one bonus for
## each Banana of the chain.
func test_helper_steps() -> void:
	var result: ScoreResult = Scoring.score(_row("strawberries,banana,banana,wonky_carrot"))
	var armed: Array = []
	var carrot: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.EFFECT_ARMED:
			armed.append([step.slot, step.value, step.text])
		elif step.step_type == ScoreStep.StepType.FLAT and step.slot == 3:
			carrot.append([step.value, step.text, step.support_slot])
	assert_array(armed).is_equal([[0, 1, "Strawberries feed the chain"]])
	assert_array(carrot).is_equal([[4, "Wonky carrot after the chain", 2]])


## Banana stand (#128): the CHAIN helpers neither take nor pass on a stand link; other Produce
## still chains.
func test_banana_stand_skips_the_chain_helpers() -> void:
	var stand: Array[UpgradeDefinition] = [load(UPGRADES % "banana_stand") as UpgradeDefinition]
	# Strawberries keep their place: the lone Banana after them takes no stand link from them.
	var helpers: ScoreResult = Scoring.score(_row("strawberries,banana"), stand)
	assert_array(Array(helpers.payouts)).is_equal([2, 2])
	# Potatoes 3, then Fruit salad (2 + 3 for one kind) + 3, the Potatoes' payout.
	var plain: ScoreResult = Scoring.score(_row("potatoes,fruit_salad"), stand)
	assert_array(Array(plain.payouts)).is_equal([3, 8])
	# A Banana just after a Lemon knot keeps its own chain (no stand bonus on top).
	var knot: ScoreResult = Scoring.score(_row("banana,lemon,banana"), stand)
	assert_array(Array(knot.payouts)).is_equal([2, 1, 6])


## Lemon squeezer (#128): a Lemon outside a chain still doubles the next Produce; a knot doesn't.
func test_lemon_squeezer_doubles_after_a_loose_lemon() -> void:
	var squeezer: Array[UpgradeDefinition] = [
		load(UPGRADES % "lemon_squeezer") as UpgradeDefinition
	]
	# The Lemon is loose: Bread is no Produce, so the Banana (2) pays ×2.
	var loose: ScoreResult = Scoring.score(_row("lemon,bread,banana"), squeezer)
	assert_array(Array(loose.payouts)).is_equal([1, 5, 4])
	assert_array(_row_wasted(loose)).is_empty()
	# That Lemon does the perk's job: no WASTED step of its own, so no wrong-job chip (the
	# Banana is still a lone one).
	assert_array(_wasted(loose)).is_equal([[2, "no Banana beside it"]])
	var lemon: CardDefinition = load(CARDS % "lemon") as CardDefinition
	assert_str(PlanningModel.wrong_job(loose, 0, lemon)).is_empty()
	# With no Produce after it, the loose Lemon still fizzles (and the perk fizzles too).
	var last: ScoreResult = Scoring.score(_row("bread,lemon"), squeezer)
	assert_array(_wasted(last)).is_equal([[1, "not inside a CHAIN"]])
	assert_str(PlanningModel.wrong_job(last, 1, lemon)).is_not_empty()
	# A knot ties the chain instead: the squeezer gives nothing and fizzles.
	var knot: ScoreResult = Scoring.score(_row("banana,lemon,banana"), squeezer)
	assert_array(Array(knot.payouts)).is_equal([2, 1, 6])
	assert_array(_row_wasted(knot)).is_equal(["every Lemon is inside a CHAIN"])
	assert_array(_row_wasted(Scoring.score(_row("banana,banana"), squeezer))).is_equal(
		["no Lemon in the row"]
	)
	assert_array(_row_wasted(Scoring.score(_row("bread,lemon"), squeezer))).is_equal(
		["no more Produce items after the Lemon"]
	)


static func _wasted(result: ScoreResult) -> Array:
	var found: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and not step.row_wide:
			found.append([step.slot, step.reason])
	return found


static func _row_wasted(result: ScoreResult) -> Array:
	var found: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and step.row_wide:
			found.append(step.reason)
	return found


static func _chains(result: ScoreResult) -> Array:
	var found: Array = []
	for chain: PackedInt32Array in result.chains:
		found.append(Array(chain))
	return found


static func _card(id: String) -> CardDefinition:
	return load(CARDS % id) as CardDefinition


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(_card(id), row.size() + 1))
	return row
