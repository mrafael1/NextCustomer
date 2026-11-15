extends GdUnitTestSuite
## TipTriggers (the one-time tips' triggers, WP-10): a rule naming a family other than Food, the
## WASTED cards of a checkout, T14's fix (the most wasted giver card and the family it gives to,
## none for a card that gives to nobody), and the planning triggers on a real run.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"


func test_a_rule_names_a_family_other_than_food() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance())
	assert_str(TipTriggers.rule_family(lookup.card("milk"))).is_equal("Breakfast")
	assert_str(TipTriggers.rule_family(lookup.card("bread"))).is_empty()


func test_the_lost_fix_names_the_most_wasted_giver() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance())
	var fix: PackedStringArray = TipTriggers.lost_fix({&"eggs": 2, &"milk": 5}, lookup)
	# Milk is wasted more but gives to nobody: Eggs (×2 on the next Food item) is named.
	assert_int(fix.size()).is_equal(2)
	assert_str(fix[0]).is_equal(lookup.card("eggs").display_name)
	assert_str(fix[1]).is_equal("Food")
	assert_array(Array(TipTriggers.lost_fix({&"milk": 5}, lookup))).is_empty()
	assert_array(Array(TipTriggers.lost_fix({}, lookup))).is_empty()


## Eggs last in a row wastes its ×2 (nothing after it): wasted names it.
func test_wasted_finds_the_wasted_cards() -> void:
	var balance: BalanceDefinition = _balance()
	var run: RunState = RunState.new(7, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	var eggs: CardDefinition = ContentLookup.new(balance).card("eggs")
	var played: Array[CardDefinition] = []
	for card: CardInstance in run.hand():
		if card.definition != eggs:
			run.place(card, run.row.size())
			played.append(card.definition)
		if run.row.size() >= 3:
			break
	var egg: CardInstance = run.deck.add_to_hand(eggs)
	run.place(egg, run.row.size())
	played.append(eggs)
	var found: Array[CardDefinition] = TipTriggers.wasted(run.preview(), played)
	assert_array(found).contains([eggs])
	assert_array(TipTriggers.wasted(null, played)).is_empty()


## The planning triggers on a fresh run: PLANNING always; week 2 from its first shift; the
## silver medal only at its laps of the quota.
func test_the_planning_triggers() -> void:
	var balance: BalanceDefinition = _balance()
	var run: RunState = RunState.new(11, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	assert_bool(TipTriggers.planning_due(TipDefinition.PLANNING, run)).is_true()
	assert_bool(TipTriggers.week_two(run)).is_false()
	assert_bool(TipTriggers.medal_reached(run)).is_false()
	assert_bool(TipTriggers.planning_due(TipDefinition.RUN_LOST, run)).is_false()
	run.shift_index = WeekSchedule.length(balance)
	assert_bool(TipTriggers.week_two(run)).is_true()


static func _balance() -> BalanceDefinition:
	return load(BALANCE) as BalanceDefinition
