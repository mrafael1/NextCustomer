extends GdUnitTestSuite
## The v1.28 coupon buffs on the live data (docs/FULL_BUILD_PLAN.md v1.28, the user's answers of
## 2026-11-11): Shelf swap glues different items and the second pays ×2, Final markdown doubles
## the row's last item, Write-off doubles the next item and writes it off (WASTED, a WRITTEN_OFF
## label, not a fizzle), Party pack doubles the next 3 Snacks and is offered only to a run with a
## Snack. Their fizzles, edge slots, steps, the total-only path, and their interplay with Repeat,
## 2 for 1, Opening deal, Eggs and the Coupon engine. The golden rows are in golden_rows_test.gd.

const CARDS := "res://data/cards/%s.tres"
const COUPON_ENGINE := "res://data/upgrades/coupon_engine.tres"
const BALANCE := "res://data/balance/balance.tres"


## Each expected fizzle of a coupon is [slot, receipt text, reason] (products' own condition
## fizzles are left out: they are not these coupons').
func test_coupon_fizzles(
	row: String,
	expected: Array,
	_test_parameters := [
		["bread,shelf_swap,milk", []],
		["bread,shelf_swap,bread", [[1, "Shelf swap ×2", "the same item on both sides"]]],
		["shelf_swap,bread", [[0, "Shelf swap ×2", "no item on both sides"]]],
		["bread,shelf_swap", [[1, "Shelf swap ×2", "no item on both sides"]]],
		[
			"bread,shelf_swap,shelf_swap,milk",
			[
				[1, "Shelf swap ×2", "no item on both sides"],
				[2, "Shelf swap ×2", "no item on both sides"]
			]
		],
		["final_markdown,bread", []],
		["bread,final_markdown", [[1, "Final markdown ×2", "no item after it"]]],
		["final_markdown", [[0, "Final markdown ×2", "no item after it"]]],
		[
			"bread,final_markdown,repeat",
			[
				[1, "Final markdown ×2", "no item after it"],
				[2, "Repeat", "no item right before it to copy"]
			]
		],
		["write_off,bread", []],
		["bread,write_off", [[1, "Write-off ×2", "no item in the next slot"]]],
		[
			"write_off,repeat,bread",
			[
				[0, "Write-off ×2", "no item in the next slot"],
				[1, "Repeat", "no item right before it to copy"]
			]
		],
		["party_pack,crisps", [[0, "Party pack ×2", "2 charges unused"]]],
		["bread,party_pack", [[1, "Party pack ×2", "3 charges unused"]]],
		["party_pack,crisps,bread,cereal_bar,bread,stale_popcorn", []],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	var fizzles: Array = []
	for step: ScoreStep in result.steps:
		if (
			step.step_type == ScoreStep.StepType.WASTED
			and _row(row)[step.slot].definition.is_coupon()
		):
			fizzles.append([step.slot, step.text, step.reason])
			assert_int(step.value).is_equal(0)
	assert_array(fizzles).override_failure_message("%s: %s" % [row, fizzles]).is_equal(expected)


## Shelf swap links its two different neighbours in the context pass and arms ×2 for the second:
## a MULTIPLIER from the coupon on the item after it, which a Repeat after it copies.
func test_shelf_swap_links_and_doubles_the_second() -> void:
	var result: ScoreResult = Scoring.score(_row("bread,shelf_swap,milk,repeat"))
	var linked: Array[ScoreStep] = _of_type(result, ScoreStep.StepType.LINKED)
	assert_int(linked.size()).is_equal(1)
	assert_array([linked[0].slot, linked[0].linked_slot, linked[0].source_slot]).is_equal([0, 2, 1])
	var doubled: Array[ScoreStep] = _of_type(result, ScoreStep.StepType.MULTIPLIER)
	assert_int(doubled.size()).is_equal(1)
	assert_array([doubled[0].slot, doubled[0].source_slot, doubled[0].value]).is_equal([2, 1, 2])
	# Bread 5, Milk (4 + 1 earlier Breakfast) ×2, Repeat copies the doubled Milk.
	assert_array(Array(result.payouts)).is_equal([5, 0, 10, 10])


## The glue is adjacency: Cheese's "+5 beside Bread" reads Bread across the Shelf swap, and the
## cost too: Soup now sits beside Frozen peas.
func test_shelf_swap_glue_is_adjacency() -> void:
	var glued: ScoreResult = Scoring.score(_row("soup,shelf_swap,frozen_peas"))
	assert_int(glued.payouts[0]).is_equal(0)
	var apart: ScoreResult = Scoring.score(_row("soup,repeat,frozen_peas"))
	assert_int(apart.payouts[0]).is_greater(0)


## 2 for 1 glues the same item, Shelf swap different ones: both in one row, each pays its own ×2.
func test_shelf_swap_beside_two_for_one() -> void:
	var result: ScoreResult = Scoring.score(_row("bread,two_for_one,bread,shelf_swap,milk"))
	# Bread 5, the 2nd Bread ×2, Milk (4 + 2 earlier Breakfast) ×2.
	assert_array(Array(result.payouts)).is_equal([5, 0, 10, 0, 12])
	assert_int(_of_type(result, ScoreStep.StepType.LINKED).size()).is_equal(2)


## Final markdown arms ×2 for the row's last item (coupons skipped) from anywhere before it: its
## MULTIPLIER lands there, after the item's own multipliers and the other armed ones (Eggs,
## Opening deal), and a Repeat in the last slot copies the doubled payout.
func test_final_markdown_doubles_the_last_item(
	row: String,
	payouts: Array,
	_test_parameters := [
		["final_markdown,bread", [0, 10]],
		["final_markdown,bread,milk", [0, 5, 10]],
		["final_markdown,bread,repeat", [0, 10, 10]],
		["bread,final_markdown,milk,repeat", [5, 0, 10, 10]],
		["final_markdown,final_markdown,bread", [0, 0, 20]],
		["eggs,final_markdown,bread", [1, 0, 20]],
		["opening_deal,final_markdown,bread", [0, 0, 50]],
		["final_markdown,bread,shelf_swap,milk", [0, 5, 0, 20]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).override_failure_message(row).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).override_failure_message(row).is_equal(result.total)


## The Final markdown's ×2 is its own MULTIPLIER step on the last item, from the coupon, armed
## (EFFECT_ARMED) when the coupon scans.
func test_final_markdown_steps() -> void:
	var result: ScoreResult = Scoring.score(_row("final_markdown,bread,milk"))
	var armed: Array[ScoreStep] = _of_type(result, ScoreStep.StepType.EFFECT_ARMED)
	assert_int(armed.size()).is_equal(1)
	assert_array([armed[0].slot, armed[0].value]).is_equal([0, 2])
	var doubled: Array[ScoreStep] = _of_type(result, ScoreStep.StepType.MULTIPLIER)
	assert_int(doubled.size()).is_equal(1)
	assert_array([doubled[0].slot, doubled[0].source_slot, doubled[0].value]).is_equal([2, 0, 2])


## Write-off labels the next item WRITTEN_OFF in the context pass (from the coupon, never a WASTED
## step on the item) and arms ×2 for it.
func test_write_off_steps() -> void:
	var result: ScoreResult = Scoring.score(_row("write_off,bread,repeat"))
	var written: Array[ScoreStep] = _of_type(result, ScoreStep.StepType.WRITTEN_OFF)
	assert_int(written.size()).is_equal(1)
	assert_array([written[0].slot, written[0].source_slot, written[0].value]).is_equal([1, 0, 0])
	assert_str(written[0].text).is_equal("Write-off ×2")
	# A context-pass step: before any value step.
	assert_int(result.steps.find(written[0])).is_less(
		result.steps.find(_of_type(result, ScoreStep.StepType.BASE)[0])
	)
	assert_array(_of_type(result, ScoreStep.StepType.WASTED)).is_empty()
	# Bread ×2, and Repeat copies the doubled Bread.
	assert_array(Array(result.payouts)).is_equal([0, 10, 10])


## A written-off item counts as WASTED for the WASTED readers: Flickering bulb right after it,
## Dusty toffees for each one before it, on score() and on the total-only path alike.
func test_write_off_feeds_the_wasted_readers(
	row: String,
	payouts: Array,
	_test_parameters := [
		# Milk 4 ×2; the bulb 2 ×4 after a WASTED item.
		["write_off,milk,flickering_bulb", [0, 8, 8]],
		# Bread 5 ×2; the toffees 2 + 5 for one WASTED item.
		["write_off,bread,dusty_toffees", [0, 10, 7]],
		["write_off,bread,write_off,milk,dusty_toffees", [0, 10, 0, 10, 12]],
		# Its next item is written off, a Dusty toffees too (×2 of 2, none WASTED before it).
		["bread,write_off,dusty_toffees", [5, 0, 4]],
		# A Write-off with no item after it writes nothing off: Bread is not WASTED.
		["bread,write_off,repeat,dusty_toffees", [5, 0, 0, 2]],
		# Its own item never counts as "before it".
		["write_off,dusty_toffees", [0, 4]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).override_failure_message(row).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).override_failure_message(row).is_equal(result.total)


## The total-only path marks the write-off even when no card of the row reads WASTED (no
## `tracks_waste`), so the state is the same either way.
func test_write_off_marks_waste_on_the_total_only_path() -> void:
	var row: Array[CardInstance] = _row("write_off,bread,repeat")
	var state: ScoreState = ScoreState.new(row, false)
	assert_bool(state.tracks_waste).is_false()
	(row[0].definition.rules[0] as Rule).modify_context(state, 0)
	assert_int(state.wasted[1]).is_equal(1)
	assert_int(Scoring.total(row)).is_equal(20)


## With 2 for 1: a written-off item can be 2 for 1's first item, and each ×2 lands on its own item.
func test_write_off_beside_two_for_one() -> void:
	var result: ScoreResult = Scoring.score(_row("write_off,bread,two_for_one,bread"))
	assert_array(Array(result.payouts)).is_equal([0, 10, 0, 10])


## Party pack's ×2 reaches the next 3 Snacks wherever they sit (lone Snacks too), coupons and other
## families between them; a second Party pack stacks (no group), and a Repeat copies the doubled
## one.
func test_party_pack_doubles_the_next_three_snacks(
	row: String,
	payouts: Array,
	_test_parameters := [
		# Crisps 2 (no redraw left), Bread 5, Milk 4 + 1 earlier Breakfast.
		["party_pack,crisps,bread,crisps,milk,crisps,crisps", [0, 4, 5, 4, 5, 4, 2]],
		["party_pack,party_pack,crisps", [0, 0, 8]],
		["party_pack,crisps,repeat", [0, 4, 4]],
		["crisps,party_pack,crisps", [2, 0, 4]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).override_failure_message(row).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).override_failure_message(row).is_equal(result.total)


## The Coupon engine doubles the first coupon's own pay: Final markdown, Shelf swap, Write-off and
## Party pack pay nothing themselves, so it fizzles on them and the total is unchanged; a Repeat
## first still gets its ×2 while the later coupon still doubles its item.
func test_coupon_engine_interplay() -> void:
	var engine: Array[UpgradeDefinition] = [load(COUPON_ENGINE) as UpgradeDefinition]
	var none: Array[UpgradeDefinition] = []
	for ids: String in [
		"final_markdown,bread", "bread,shelf_swap,milk", "write_off,bread", "party_pack,crisps"
	]:
		var plain: int = Scoring.score(_row(ids), none).total
		var engined: ScoreResult = Scoring.score(_row(ids), engine)
		assert_int(engined.total).override_failure_message(ids).is_equal(plain)
		var upgrade_wasted: Array = engined.steps.filter(
			func(step: ScoreStep) -> bool:
				return (
					step.step_type == ScoreStep.StepType.WASTED
					and step.source_kind == ScoreStep.SourceKind.UPGRADE
				)
		)
		assert_int(upgrade_wasted.size()).override_failure_message(ids).is_equal(1)
	# Bread 5, Repeat copies 5 ×2, Final markdown doubles Milk (4 + 1).
	var both: ScoreResult = Scoring.score(_row("bread,repeat,final_markdown,milk"), engine)
	assert_array(Array(both.payouts)).is_equal([5, 10, 0, 10])


## The live cards: rarities and pools (the page: Write-off RARE, Party pack COMMON, Shelf swap and
## Final markdown COMMON), and Party pack is a Snack coupon (needs_tag).
func test_live_pools_and_rarities() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var ids: Array[StringName] = []
	for card: CardDefinition in balance.coupon_pool:
		ids.append(card.id)
	for id: StringName in [&"shelf_swap", &"final_markdown", &"write_off", &"party_pack"]:
		assert_bool(ids.has(id)).override_failure_message(id).is_true()
	var machine: MachineDefinition = balance.machine
	assert_int(machine.coupon_rarity(_card("write_off"))).is_equal(MachinePrize.Rarity.RARE)
	for id: String in ["party_pack", "shelf_swap", "final_markdown"]:
		assert_int(machine.coupon_rarity(_card(id))).override_failure_message(id).is_equal(
			MachinePrize.Rarity.COMMON
		)
	assert_str(_card("party_pack").needs_tag).is_equal("Snack")
	assert_str(_card("write_off").needs_tag).is_empty()


## NEW ITEMS offers Party pack only to a run with a Snack: a stocked one or one in the deck, on the
## first coupon draw too (when it is in the first-offer pool).
func test_party_pack_needs_a_snack() -> void:
	var party: CardDefinition = _card("party_pack")
	var repeat: CardDefinition = _card("repeat")
	var context: MachineContext = MachineContext.new()
	context.coupons = [repeat, party]
	context.products = [_card("bread")]
	context.deck = Deck.new(null)
	assert_array(context.coupon_candidates()).is_equal([repeat])
	context.products.append(_card("crisps"))
	assert_array(context.coupon_candidates()).is_equal([repeat, party])
	context.products = [_card("bread")]
	context.deck.cards.append(CardInstance.new(_card("pick_n_mix"), 1))
	assert_array(context.coupon_candidates()).is_equal([repeat, party])
	context.deck.cards.clear()
	context.first_coupons = true
	context.first_offer_pool = [party, repeat]
	assert_array(context.coupon_candidates()).is_equal([repeat])


static func _of_type(result: ScoreResult, step_type: ScoreStep.StepType) -> Array[ScoreStep]:
	var found: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.step_type == step_type:
			found.append(step)
	return found


static func _card(id: String) -> CardDefinition:
	return load(CARDS % id) as CardDefinition


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		row.append(CardInstance.new(_card(card_id), row.size() + 1))
	return row
