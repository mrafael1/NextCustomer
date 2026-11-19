extends GdUnitTestSuite
## The Family sticker (v1.29, the user's answer 2 of 2026-11-11; FamilySticker): its next item
## joins the family picked for that copy (ScoreCredits.sticker_families, like a Price gun's
## relabels), else the row's pre-fill. Picked on the belt while planning, kept across shifts and
## in the run save (format 12); a version 11 save reads with no family picked. (The starter packs'
## presets went with the packs in v1.45.) Its ticket reads the copy's family; the picker learns the
## next item and the families it already has.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const STICKER := "res://data/cards/family_sticker.tres"
const OLD_STICKER := "res://data/cards/breakfast_sticker.tres"
const BANANA := "res://data/cards/banana.tres"
const BREAD := "res://data/cards/bread.tres"
const COFFEE := "res://data/cards/coffee.tres"
const MILK := "res://data/cards/milk.tres"
const POTATOES := "res://data/cards/potatoes.tres"
const SCISSORS := "res://data/cards/scissors.tres"
const FAMILIES: Array[String] = [
	"Breakfast", "Bakery", "Produce", "Dairy", "Frozen", "Snack", "Household", "Clearance"
]

var _balance: BalanceDefinition


func before_test() -> void:
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	EightShiftLoop.apply(_balance)


## The card: one COMMON coupon whose rule offers the Price gun's eight families, in the coupon pool
## and the first offer in place of the Breakfast sticker and the Clearance tag (their files stay).
func test_the_card_replaces_the_two_stickers_in_the_pools() -> void:
	var sticker: CardDefinition = load(STICKER)
	assert_bool(FamilySticker.is_family_sticker(sticker)).is_true()
	assert_bool(FamilySticker.is_family_sticker(load(OLD_STICKER))).is_false()
	assert_array(Array(FamilySticker.rule_of(sticker).choices)).is_equal(FAMILIES)
	var price_gun: PinDefinition = load("res://data/pins/price_gun.tres")
	assert_array(Array(price_gun.relabel_tags)).is_equal(FAMILIES)
	var balance: BalanceDefinition = load(BALANCE)
	for pool: Array[CardDefinition] in [balance.coupon_pool, balance.first_offer_pool]:
		assert_bool(pool.has(sticker)).is_true()
		for old: String in [OLD_STICKER, "res://data/cards/clearance_tag.tres"]:
			assert_bool(pool.has(load(old))).is_false()
	assert_bool(ResourceLoader.exists("res://data/cards/clearance_tag.tres")).is_true()


## Scoring with each family picked: the next item gains it (a TAG_ADDED step naming it), the
## same for score() and total().
func test_each_picked_family_reaches_the_next_item() -> void:
	for family: String in FAMILIES:
		var row: Array[CardInstance] = _row([SCISSORS, STICKER, BREAD])
		var credits: ScoreCredits = ScoreCredits.new()
		credits.sticker_families[row[1].instance_id] = family
		var result: ScoreResult = Scoring.score(row, [], [], credits)
		var bread_has: bool = (load(BREAD) as CardDefinition).tags.has(family)
		if bread_has:
			assert_str(_waste_reason(result, 1)).is_equal("already %s" % family)
		else:
			assert_bool(result.tags[2].has(family)).override_failure_message(family).is_true()
		assert_str(FamilySticker.given(result, 1)).is_equal(family)


## A picked family pays like the old fixed sticker: Breakfast on Banana before Coffee feeds its
## Coffee (Family sticker picked Breakfast scores what the Breakfast sticker scored), and a pick
## that a reader doesn't want pays less.
func test_a_picked_family_scores_like_the_fixed_sticker() -> void:
	var old_row: Array[CardInstance] = _row([OLD_STICKER, BANANA, COFFEE, MILK])
	var old_total: int = Scoring.score(old_row).total
	var row: Array[CardInstance] = _row([STICKER, BANANA, COFFEE, MILK])
	var credits: ScoreCredits = ScoreCredits.new()
	credits.sticker_families[row[0].instance_id] = "Breakfast"
	assert_int(Scoring.score(row, [], [], credits).total).is_equal(old_total)
	credits.sticker_families[row[0].instance_id] = "Household"
	assert_int(Scoring.score(row, [], [], credits).total).is_less(old_total)
	# A family outside its choices is ignored: the row's pre-fill (Breakfast) instead.
	credits.sticker_families[row[0].instance_id] = "Food"
	assert_int(Scoring.score(row, [], [], credits).total).is_equal(old_total)


## The pre-fill: the family most cards in the row read (Coffee and Milk read Breakfast), never one
## the next item has; with none read, the family of the item after the next one; else the first
## choice. The bare total (the simulator's) uses it too.
func test_the_pre_fill_rule() -> void:
	var read: Array[CardInstance] = _row([COFFEE, STICKER, BANANA, MILK])
	var result: ScoreResult = Scoring.score(read)
	assert_str(FamilySticker.given(result, 1)).is_equal("Breakfast")
	assert_bool(result.tags[2].has("Breakfast")).is_true()
	assert_int(Scoring.total(read)).is_equal(result.total)
	# Nothing reads a family: Bread joins the Produce of the Potatoes after it.
	var beside: Array[CardInstance] = _row([STICKER, BREAD, POTATOES])
	assert_str(FamilySticker.given(Scoring.score(beside), 0)).is_equal("Produce")
	# Nothing read, nothing after: the first family Potatoes hasn't got.
	var alone: Array[CardInstance] = _row([STICKER, POTATOES])
	assert_str(FamilySticker.given(Scoring.score(alone), 0)).is_equal("Breakfast")
	# Milk reads Breakfast but the next Milk has it already: never "already", always a gain.
	var own: Array[CardInstance] = _row([STICKER, MILK, MILK])
	var own_result: ScoreResult = Scoring.score(own)
	assert_str(_waste_reason(own_result, 0)).is_empty()
	assert_str(FamilySticker.given(own_result, 0)).is_not_equal("Breakfast")
	assert_bool(own_result.tags[1].has(FamilySticker.given(own_result, 0))).is_true()
	# No item next: the most read family, fizzling with its reason.
	var last: Array[CardInstance] = _row([MILK, STICKER])
	var last_result: ScoreResult = Scoring.score(last)
	assert_str(_waste_reason(last_result, 1)).is_equal("no item in the next slot")
	assert_str(FamilySticker.given(last_result, 1)).is_equal("Breakfast")


## Picking: only a Family sticker on the belt while planning, only one of its choices; free and
## any number of times; kept across shifts; the run's preview scores the pick.
func test_picks_are_kept_across_shifts() -> void:
	var run: RunState = _run(4)
	var sticker: CardInstance = run.debug_add_to_hand(load(STICKER))
	var bread: CardInstance = run.debug_add_to_hand(load(BREAD))
	assert_bool(FamilySticker.pick(run, sticker, "Dairy")).is_false()  # In the hand.
	assert_bool(run.place(sticker, 0)).is_true()
	assert_bool(run.place(bread, 1)).is_true()
	assert_bool(FamilySticker.pick(run, sticker, "Food")).is_false()  # Not a choice.
	assert_bool(FamilySticker.pick(run, bread, "Dairy")).is_false()  # Not a sticker.
	assert_bool(FamilySticker.pick(run, sticker, "Dairy")).is_true()
	assert_bool(FamilySticker.pick(run, sticker, "Snack")).is_true()
	assert_bool(run.preview().tags[1].has("Snack")).is_true()
	run.checkout()
	assert_bool(FamilySticker.pick(run, sticker, "Dairy")).is_false()  # After CHECKOUT.
	MachineSteps.next_shift(run)
	assert_str(FamilySticker.chosen(run, sticker)).is_equal("Snack")


## The ticket's words: "Next joins <family>" for a copy's family, "Next joins your pick" with none.
func test_the_ticket_reads_the_family() -> void:
	var sticker: CardDefinition = load(STICKER)
	assert_str(CardText.sticker_summary(sticker)).is_equal("Next joins your pick")
	assert_str(CardText.sticker_summary(sticker, -1, "Dairy")).is_equal("Next joins Dairy")
	var old: CardDefinition = load(OLD_STICKER)
	assert_str(CardText.sticker_summary(old, -1, "Dairy")).is_equal("Next joins Breakfast")


## What the picker learns: the item the sticker gives to, and the families it has already (a pick
## of one fizzles as "already"), not the one the sticker gives; none with no item next.
func test_the_next_item_and_its_held_families() -> void:
	var run: RunState = _run(8)
	var sticker: CardInstance = run.debug_add_to_hand(load(STICKER))
	var potatoes: CardInstance = run.debug_add_to_hand(load(POTATOES))
	for card: CardInstance in run.row.duplicate():
		run.remove(card)
	assert_bool(run.place(sticker, 0)).is_true()
	assert_object(FamilySticker.next_item(run, sticker)).is_null()
	assert_array(Array(FamilySticker.held(run, sticker))).is_empty()
	assert_bool(run.place(potatoes, 1)).is_true()
	assert_object(FamilySticker.next_item(run, sticker)).is_same(potatoes)
	var held: PackedStringArray = FamilySticker.held(run, sticker)
	assert_array(Array(held)).is_equal(["Produce"])
	assert_bool(FamilySticker.pick(run, sticker, "Produce")).is_true()
	assert_array(Array(FamilySticker.held(run, sticker))).is_equal(["Produce"])
	assert_bool(FamilySticker.pick(run, sticker, "Dairy")).is_true()
	assert_array(Array(FamilySticker.held(run, sticker))).is_equal(["Produce"])


## The run save (format 12 on) keeps the picks; a version 11 save reads with none.
func test_the_run_save_keeps_the_picks() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = _run(5)
	var sticker: CardInstance = run.deck.add_card(load(STICKER))
	run.sticker_families[sticker.instance_id] = "Clearance"
	var saved: Dictionary = _saved(run)
	assert_int(int(saved["format_version"])).is_equal(RunSave.FORMAT_VERSION)
	assert_dict(saved["sticker_families"]).is_equal({str(sticker.instance_id): "Clearance"})
	var restored: RunSave = RunSave.from_dictionary(saved, lookup)
	assert_object(restored).is_not_null()
	assert_dict(restored.run.sticker_families).is_equal({sticker.instance_id: "Clearance"})
	var old: Dictionary = saved.duplicate(true)
	old["format_version"] = 11
	old.erase("sticker_families")
	var read: RunSave = RunSave.from_dictionary(old, lookup)
	assert_object(read).is_not_null()
	assert_dict(read.run.sticker_families).is_empty()
	var broken: Dictionary = saved.duplicate(true)
	broken["sticker_families"] = {"x": "Dairy"}
	assert_object(RunSave.from_dictionary(broken, lookup)).is_null()


func _run(seed_value: int) -> RunState:
	var run: RunState = RunState.new(
		seed_value, load(STARTER), _balance, RunStock.starting(_balance)
	)
	run.start_shift()
	return run


static func _row(paths: Array[String]) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for path: String in paths:
		row.append(CardInstance.new(load(path), row.size() + 1))
	return row


## The reason of the WASTED step the card in `slot` caused, or "".
static func _waste_reason(result: ScoreResult, slot: int) -> String:
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and step.source_slot == slot:
			return step.reason
	return ""


static func _saved(run: RunState) -> Dictionary:
	return JSON.parse_string(JSON.stringify(RunSave.to_dictionary(run, "id", 0)))
