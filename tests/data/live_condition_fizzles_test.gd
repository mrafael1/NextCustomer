extends GdUnitTestSuite
## Condition fizzles (#45) on every live conditional card: each card on an adjacency or
## earlier-tag rule fizzles alone (one WASTED step, the total its base) and doesn't fizzle once
## its condition is met (its bonus step instead). The partner that meets the condition is found
## in the data, so a new conditional card is covered without editing this test.

const CARDS_DIR := "res://data/cards"


func test_every_conditional_card_fizzles_alone() -> void:
	var checked: int = 0
	for card: CardDefinition in _conditional_cards():
		var result: ScoreResult = Scoring.score(_row([card]))
		var fizzles: Array[ScoreStep] = _wasted(result)
		assert_int(fizzles.size()).override_failure_message(card.id).is_equal(1)
		assert_str(fizzles[0].text).is_equal(card.rules[0].text_for(card))
		assert_str(fizzles[0].reason).override_failure_message(card.id).starts_with("no ")
		assert_int(fizzles[0].value).is_equal(0)
		assert_int(result.total).override_failure_message(card.id).is_equal(card.base)
		checked += 1
	# Every card on those two rules today: the 24 adjacency and 8 earlier-tag cards.
	assert_int(checked).is_equal(32)


func test_no_fizzle_once_the_condition_is_met() -> void:
	var cards: Array[CardDefinition] = _all_cards()
	for card: CardDefinition in _conditional_cards():
		var partner: CardDefinition = _partner(card, cards)
		assert_object(partner).override_failure_message(card.id).is_not_null()
		var result: ScoreResult = Scoring.score(_row([partner, card]))
		var own_fizzles: int = 0
		var own_bonus: int = 0
		for step: ScoreStep in result.steps:
			if step.slot != 1 or step.text != card.rules[0].text_for(card):
				continue
			if step.step_type == ScoreStep.StepType.WASTED:
				own_fizzles += 1
			elif step.step_type == ScoreStep.StepType.FLAT:
				own_bonus += step.value
		assert_int(own_fizzles).override_failure_message(card.id).is_equal(0)
		assert_int(own_bonus).override_failure_message(card.id).is_greater(0)


## A card-id match names the card in its reason by capitalizing the id ("bread" -> "Bread"), so
## every id a rule names must capitalize to that card's display name.
func test_card_id_matches_name_their_card() -> void:
	for card: CardDefinition in _conditional_cards():
		var rule: AdjacentMatchBonusRule = card.rules[0] as AdjacentMatchBonusRule
		if rule == null or rule.match_by != AdjacentMatchBonusRule.Match.CARD_ID:
			continue
		var target: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, rule.match_value])
		assert_str(rule.match_value.capitalize()).is_equal(target.display_name)
		var reason: String = _wasted(Scoring.score(_row([card])))[0].reason
		assert_str(reason).contains(target.display_name)


## A product that meets `card`'s condition just before it: the same card, the named card, or a
## another product with the tag, else the card itself when it has the tag.
static func _partner(card: CardDefinition, cards: Array[CardDefinition]) -> CardDefinition:
	var adjacent: AdjacentMatchBonusRule = card.rules[0] as AdjacentMatchBonusRule
	var tag: String = ""
	if adjacent != null:
		match adjacent.match_by:
			AdjacentMatchBonusRule.Match.SAME_CARD:
				return card
			AdjacentMatchBonusRule.Match.CARD_ID:
				return load("%s/%s.tres" % [CARDS_DIR, adjacent.match_value])
		tag = adjacent.match_value
	else:
		tag = (card.rules[0] as CountEarlierTagBonusRule).tag
	for other: CardDefinition in cards:
		if other.is_product() and other.tags.has(tag) and other != card:
			return other
	return card if card.tags.has(tag) else null


static func _conditional_cards() -> Array[CardDefinition]:
	var conditional: Array[CardDefinition] = []
	for card: CardDefinition in _all_cards():
		if card.rules.is_empty():
			continue
		if card.rules[0] is AdjacentMatchBonusRule or card.rules[0] is CountEarlierTagBonusRule:
			conditional.append(card)
	return conditional


static func _wasted(result: ScoreResult) -> Array[ScoreStep]:
	var wasted: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			wasted.append(step)
	return wasted


static func _all_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if file.ends_with(".tres"):
			cards.append(load("%s/%s" % [CARDS_DIR, file]) as CardDefinition)
	return cards


static func _row(cards: Array[CardDefinition]) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card: CardDefinition in cards:
		row.append(CardInstance.new(card, row.size() + 1))
	return row
