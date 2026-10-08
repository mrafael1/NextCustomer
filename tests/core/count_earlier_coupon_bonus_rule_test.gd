extends GdUnitTestSuite
## CountEarlierCouponBonusRule (Scissors, issue #34): a flat bonus per earlier coupon, counting
## every coupon before it, whether or not that coupon did anything, and none after it. With no
## earlier coupon it fizzles. Cards are built here, so the test doesn't depend on live data.


func test_counts_every_earlier_coupon(
	row: String,
	payout: int,
	_test_parameters := [
		["scissors", 1],
		["coupon,scissors", 3],
		["coupon,product,coupon,scissors", 5],
		["scissors,coupon", 1],
		# A coupon that fizzles (nothing to copy) still counts.
		["dud,scissors", 3],
	]
) -> void:
	var cards: Array[CardInstance] = _row(row)
	var slot: int = row.split(",").find("scissors")
	assert_int(Scoring.score(cards).payouts[slot]).is_equal(payout)


func test_fizzles_with_no_earlier_coupon(
	row: String,
	fizzles: bool,
	_test_parameters := [
		["scissors", true],
		["product,scissors", true],
		["scissors,coupon", true],
		["coupon,scissors", false],
	]
) -> void:
	var reasons: Array = []
	for step: ScoreStep in Scoring.score(_row(row)).steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			reasons.append(step.reason)
	assert_array(reasons).is_equal(["no coupon before it"] if fizzles else [])


func test_a_zero_bonus_never_fizzles() -> void:
	var rule: CountEarlierCouponBonusRule = CountEarlierCouponBonusRule.new()
	var scissors: CardDefinition = _card(&"scissors", CardDefinition.Kind.PRODUCT, 1, [rule])
	var row: Array[CardInstance] = [CardInstance.new(scissors, 1)]
	for step: ScoreStep in Scoring.score(row).steps:
		assert_int(step.step_type).is_not_equal(ScoreStep.StepType.WASTED)


static func _row(ids: String) -> Array[CardInstance]:
	var rule: CountEarlierCouponBonusRule = CountEarlierCouponBonusRule.new()
	rule.bonus_each = 2
	var dud_rule: CopyPreviousPayoutRule = CopyPreviousPayoutRule.new()
	var cards: Dictionary[String, CardDefinition] = {
		"scissors": _card(&"scissors", CardDefinition.Kind.PRODUCT, 1, [rule]),
		"product": _card(&"product", CardDefinition.Kind.PRODUCT, 3, []),
		"coupon": _card(&"coupon", CardDefinition.Kind.COUPON, 0, []),
		"dud": _card(&"dud", CardDefinition.Kind.COUPON, 0, [dud_rule]),
	}
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		row.append(CardInstance.new(cards[card_id], row.size() + 1))
	return row


static func _card(
	card_id: StringName, kind: CardDefinition.Kind, base: int, rules: Array[Rule]
) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = card_id
	card.display_name = String(card_id)
	card.kind = kind
	card.base = base
	card.rules = rules
	return card
