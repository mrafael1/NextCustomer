extends GdUnitTestSuite
## The v1.29 playstyle loyalty perks on the live data (docs/FULL_BUILD_PLAN.md v1.29 section 5.2,
## the user's answers of 2026-11-12: "loyalty" is the in-run LOYALTY card, plain pool perks; no
## starter pack names or boosts one): Perfect pair (PAIRED items), Salvage desk (WASTED items),
## Grab bag (lone Snacks) and Home goods (Household items) pay ×2, ×3, ×4 by level; their steps
## and fizzles, the total-only path, Salvage desk with Write-off and with an item's own fizzle;
## their family gate in the machine; and the four Regulars' step up. The frozen golden rows are in
## golden_rows_test.gd.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS := "res://data/cards/%s.tres"
const UPGRADES := "res://data/upgrades/%s.tres"
## Each perk's LV 1 id, its keyword, tag and family.
const PERKS := [
	["perfect_pair", KeywordMultiplierRule.Keyword.PAIRED, "", "Dairy"],
	["salvage_desk", KeywordMultiplierRule.Keyword.WASTED, "", "Clearance"],
	["grab_bag", KeywordMultiplierRule.Keyword.LONE, "Snack", "Snack"],
	["home_goods", KeywordMultiplierRule.Keyword.TAG, "Household", "Household"],
]

var _balance: BalanceDefinition


func before() -> void:
	_balance = load(BALANCE)


## Each perk is a RARE KEYWORD perk of the pool with its family, its own icon, three levels
## (×2, ×3, ×4) and the effect line naming the factor.
func test_the_perks_data() -> void:
	for entry: Array in PERKS:
		var perk: UpgradeDefinition = _upgrade(entry[0])
		assert_bool(_balance.upgrade_pool.has(perk)).override_failure_message(entry[0]).is_true()
		assert_int(_balance.machine.upgrade_rarity(perk)).is_equal(MachinePrize.Rarity.RARE)
		assert_str(perk.boosts_tag).is_equal(entry[3])
		assert_bool(ResourceLoader.exists(perk.icon_ref)).is_true()
		assert_str(perk.build_names()).is_equal("%s decks" % entry[3])
		var level: UpgradeDefinition = perk
		for number: int in [1, 2, 3]:
			assert_int(level.level_number()).is_equal(number)
			assert_int(level.type).is_equal(UpgradeDefinition.Type.KEYWORD)
			assert_str(level.display_name).is_equal(perk.display_name)
			assert_str(level.icon_ref).is_equal(perk.icon_ref)
			assert_bool(level.same_perk(perk)).is_true()
			var rule: KeywordMultiplierRule = level.rules[0] as KeywordMultiplierRule
			assert_object(rule).is_not_null()
			assert_int(rule.keyword).is_equal(entry[1])
			assert_str(rule.tag).is_equal(entry[2])
			assert_int(rule.factor).is_equal(number + 1)
			assert_str(level.effect_text).ends_with("pay ×%d" % (number + 1))
			level = level.next_level
		assert_object(level).is_null()
	var icons: Dictionary = {}
	for entry: Array in PERKS:
		icons[_upgrade(entry[0]).icon_ref] = true
	assert_int(icons.size()).is_equal(PERKS.size())


## The four weak families' Regulars step up one (v1.29): +2 › +3 › +4 each; the other three keep
## +1 › +2 › +3.
func test_the_regulars_numbers() -> void:
	for family: String in ["dairy", "clearance", "snack", "household", "bakery", "produce"]:
		var stepped: bool = family in ["dairy", "clearance", "snack", "household"]
		var level: UpgradeDefinition = _upgrade("%s_regulars" % family)
		for number: int in [1, 2, 3]:
			var rule: FamilyRegularsRule = level.rules[0] as FamilyRegularsRule
			var expected: int = number + 1 if stepped else number
			assert_int(rule.bonus_each).override_failure_message(family).is_equal(expected)
			assert_str(level.effect_text).contains("+%d for each" % expected)
			level = level.next_level
	var milks: Array[CardInstance] = _row("milk,cream,yogurt")
	# Dairy regulars LV 1: Cream +2 (one Dairy before it), Yogurt +4 (two).
	var plain: ScoreResult = Scoring.score(milks)
	var regulars: ScoreResult = Scoring.score(milks, _perks(["dairy_regulars"]))
	assert_int(regulars.payouts[1] - plain.payouts[1]).is_equal(2)
	assert_int(regulars.payouts[2] - plain.payouts[2]).is_equal(4)


## A perk's ×N is an upgrade MULTIPLIER from its box on each item its keyword names, after the
## item's own and effect multipliers; the other items are untouched.
func test_each_perk_multiplies_only_its_items(
	perk_id: String,
	row: String,
	doubled: Array,
	_test_parameters := [
		["perfect_pair", "milk,cereal,banana,yogurt,bread", [1, 3]],
		["perfect_pair", "cereal,bread", []],
		["salvage_desk", "write_off,milk,flickering_bulb", [1]],
		["salvage_desk", "dusty_toffees,bread", [0]],
		["salvage_desk", "bread,write_off", []],
		["grab_bag", "crisps,bread,pick_n_mix,cereal_bar", [0]],
		["grab_bag", "crisps,write_off,pick_n_mix", [0, 2]],
		["home_goods", "batteries,bread,odd_socks", [0, 2]],
		["home_goods", "bread,milk", []],
	]
) -> void:
	for level: int in [1, 2, 3]:
		var perk: UpgradeDefinition = _level(perk_id, level)
		var plain: ScoreResult = Scoring.score(_row(row))
		var result: ScoreResult = Scoring.score(_row(row), [perk])
		var factor: int = level + 1
		var steps: Array = []
		for step: ScoreStep in result.steps:
			if step.source_kind != ScoreStep.SourceKind.UPGRADE:
				continue
			if step.step_type == ScoreStep.StepType.MULTIPLIER:
				steps.append(step.slot)
				assert_int(step.value).is_equal(factor)
				assert_int(step.source_index).is_equal(0)
				assert_str(step.text).is_equal(perk.display_name)
		assert_array(steps).override_failure_message("%s %s" % [perk_id, row]).is_equal(doubled)
		for slot: int in plain.payouts.size():
			var expected: int = plain.payouts[slot] * (factor if doubled.has(slot) else 1)
			(
				assert_int(result.payouts[slot])
				. override_failure_message("%s LV %d %s slot %d" % [perk_id, level, row, slot])
				. is_equal(expected)
			)
		assert_int(Scoring.total(_row(row), [perk])).is_equal(result.total)


## With no item its keyword names, a perk fizzles once, row-wide, on the row's last slot; the
## total doesn't change.
func test_a_perk_with_nothing_to_multiply_fizzles(
	perk_id: String,
	row: String,
	reason: String,
	_test_parameters := [
		["perfect_pair", "cereal,bread", "no PAIRED item in the row"],
		["salvage_desk", "bread,milk", "no WASTED item in the row"],
		["grab_bag", "crisps,pick_n_mix", "no lone Snack item in the row"],
		["home_goods", "bread,milk", "no Household item in the row"],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row), _perks([perk_id]))
	var fizzles: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			if step.source_kind == ScoreStep.SourceKind.UPGRADE:
				fizzles.append([step.slot, step.reason, step.row_wide])
	assert_array(fizzles).is_equal([[_row(row).size() - 1, reason, true]])
	assert_int(result.total).is_equal(Scoring.score(_row(row)).total)


## Salvage desk sees an item's own fizzle before its ×2 (the scoring-order fix): Dusty toffees with
## no WASTED item before it is WASTED itself and pays ×2; Breadsticks not right after Soup too.
## A written-off item pays the Write-off's ×2 and then the desk's; Flickering bulb after it keeps
## its own ×4 and isn't WASTED. Its WASTED step still follows its payout.
func test_salvage_desk_reads_the_item_own_waste() -> void:
	var desk: Array[UpgradeDefinition] = _perks(["salvage_desk"])
	var toffees: ScoreResult = Scoring.score(_row("dusty_toffees"), desk)
	assert_array(Array(toffees.payouts)).is_equal([Scoring.score(_row("dusty_toffees")).total * 2])
	var kinds: Array = toffees.steps.map(func(step: ScoreStep) -> int: return step.step_type)
	assert_int(kinds.find(ScoreStep.StepType.MULTIPLIER)).is_less(
		kinds.find(ScoreStep.StepType.PAYOUT)
	)
	assert_int(kinds.find(ScoreStep.StepType.WASTED)).is_greater(
		kinds.find(ScoreStep.StepType.PAYOUT)
	)
	var plain: ScoreResult = Scoring.score(_row("write_off,milk,flickering_bulb"))
	var written: ScoreResult = Scoring.score(_row("write_off,milk,flickering_bulb"), desk)
	assert_int(written.payouts[1]).is_equal(plain.payouts[1] * 2)
	assert_int(written.payouts[2]).is_equal(plain.payouts[2])
	var factors: Array = []
	for step: ScoreStep in written.steps:
		if step.slot == 1 and step.step_type == ScoreStep.StepType.MULTIPLIER:
			factors.append([step.source_kind, step.value])
	assert_array(factors).is_equal(
		[[ScoreStep.SourceKind.CARD, 2], [ScoreStep.SourceKind.UPGRADE, 2]]
	)
	# A perk that reads no waste and names none of these items changes no total (it only fizzles).
	var others: Array[UpgradeDefinition] = _perks(["perfect_pair"])
	var row: String = "dusty_toffees,write_off,milk,flickering_bulb"
	assert_int(Scoring.score(_row(row), others).total).is_equal(Scoring.score(_row(row)).total)


## Scoring.total equals Scoring.score's total with all four perks at any level, on seeded rows of
## the cards they read (the total-only path marks WASTED items too).
func test_the_total_only_path_matches() -> void:
	var pool: PackedStringArray = PackedStringArray(
		[
			"milk",
			"cereal",
			"yogurt",
			"banana",
			"bread",
			"butter",
			"write_off",
			"flickering_bulb",
			"dusty_toffees",
			"dented_can",
			"crisps",
			"pick_n_mix",
			"bent_lolly",
			"batteries",
			"odd_socks",
			"egg_timer",
			"repeat",
			"party_pack",
		]
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 128
	for attempt: int in 120:
		var ids: PackedStringArray = PackedStringArray()
		for slot: int in rng.randi_range(1, 7):
			ids.append(pool[rng.randi_range(0, pool.size() - 1)])
		var level: int = rng.randi_range(1, 3)
		var perks: Array[UpgradeDefinition] = []
		for entry: Array in PERKS:
			perks.append(_level(entry[0], level))
		var row: String = ",".join(ids)
		(
			assert_int(Scoring.total(_row(row), perks, [], 2, 1))
			. override_failure_message(row)
			. is_equal(Scoring.score(_row(row), perks, [], _credits(2, 1)).total)
		)


## The machine offers a perk only when its family is stocked or in the deck.
func test_the_family_gate() -> void:
	for entry: Array in PERKS:
		var perk: UpgradeDefinition = _upgrade(entry[0])
		var context: MachineContext = _bare_context([_card("bread"), _card("banana")])
		var family_card: CardDefinition = _family_card(entry[3])
		var without: bool = _pool_ids(context).has(perk.id)
		assert_bool(without).override_failure_message(entry[0]).is_false()
		context = _bare_context([_card("bread"), family_card])
		assert_bool(_pool_ids(context).has(perk.id)).override_failure_message(entry[0]).is_true()
		var in_deck: MachineContext = _bare_context([_card("bread")])
		in_deck.deck.cards.append(CardInstance.new(family_card, 1))
		assert_bool(_pool_ids(in_deck).has(perk.id)).override_failure_message(entry[0]).is_true()


## --- helpers ---


func _upgrade(id: String) -> UpgradeDefinition:
	return load(UPGRADES % id)


func _level(id: String, level: int) -> UpgradeDefinition:
	var found: UpgradeDefinition = _upgrade(id)
	for step: int in level - 1:
		found = found.next_level
	return found


func _perks(ids: Array) -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for id: String in ids:
		found.append(_upgrade(id))
	return found


func _card(id: String) -> CardDefinition:
	return load(CARDS % id)


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % card_id), row.size() + 1))
	return row


static func _credits(cards_redrawn: int, redraws_left: int) -> ScoreCredits:
	var credits: ScoreCredits = ScoreCredits.new()
	credits.cards_redrawn = cards_redrawn
	credits.redraws_left = redraws_left
	return credits


## A product of the family (any live card tagged with it).
func _family_card(family: String) -> CardDefinition:
	var ids: Dictionary = {
		"Dairy": "yogurt", "Clearance": "dented_can", "Snack": "crisps", "Household": "batteries"
	}
	var card: CardDefinition = _card(ids[family])
	assert_bool(card.tags.has(family)).is_true()
	return card


## A context with these stocked products, an empty deck and the live pool, nothing owned.
func _bare_context(products: Array[CardDefinition]) -> MachineContext:
	var context: MachineContext = MachineContext.new()
	context.machine = _balance.machine
	context.balance = _balance
	context.products = products
	context.upgrade_pool = _balance.upgrade_pool.duplicate()
	context.deck = Deck.new(null)
	return context


func _pool_ids(context: MachineContext) -> Array:
	var ids: Array = []
	for pool: Array[MachinePrize] in MachineDraw.pools(RewardMachine.Chute.UPGRADE, context):
		for prize: MachinePrize in pool:
			if prize.kind == MachinePrize.Kind.REGISTER:
				ids.append(prize.upgrade.id)
	return ids
