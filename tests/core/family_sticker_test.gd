extends GdUnitTestSuite
## The Family sticker (v1.29, the user's answer 2 of 2026-11-11; FamilySticker): its next item
## joins the family picked for that copy (ScoreCredits.sticker_families, like a Price gun's
## relabels), else its pack's preset, else the row's pre-fill. Picked on the belt while planning,
## kept across shifts and in the run save (format 12); a version 11 save reads with no family
## picked, and a run dealt the Breakfast run with the old Breakfast sticker, or the old Bargain bin,
## still resumes and plays. A pack's preset reaches only the pack's own copies. Its ticket reads
## the copy's family; the picker learns the next item and the families it already has.

const BALANCE := "res://data/balance/balance.tres"
const RECIPE := "res://data/decks/pack_starter.tres"
const STARTER := "res://data/decks/starter.tres"
const STICKER := "res://data/cards/family_sticker.tres"
const OLD_STICKER := "res://data/cards/breakfast_sticker.tres"
const BREAKFAST_RUN := "res://data/starter_packs/breakfast_run.tres"
const BARGAIN_BIN := "res://data/starter_packs/bargain_bin.tres"
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
	var pack: StarterPackDefinition = load(BREAKFAST_RUN)
	assert_object(pack.cards[0]).is_same(sticker)
	assert_str(pack.sticker_family).is_equal("Breakfast")


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
## MORNING (Family sticker picked Breakfast scores what the Breakfast sticker scored), and a pick
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


## The Breakfast run's sticker comes preset to Breakfast (its pack's sticker_family) until a pick.
func test_the_breakfast_run_presets_its_sticker() -> void:
	var run: RunState = _pack_run(6)
	var stickers: Array[CardInstance] = []
	for card: CardInstance in run.deck.cards:
		if FamilySticker.is_family_sticker(card.definition):
			stickers.append(card)
	assert_int(stickers.size()).is_greater_equal(1)
	assert_str(FamilySticker.chosen(run, stickers[0])).is_equal("Breakfast")
	assert_str(ScoreCredits.for_run(run).sticker_families[stickers[0].instance_id]).is_equal(
		"Breakfast"
	)
	run.sticker_families[stickers[0].instance_id] = "Bakery"
	assert_str(FamilySticker.chosen(run, stickers[0])).is_equal("Bakery")


## The preset reaches only the pack's own dealt copy: a Family sticker drafted later comes with
## none (pre-filled), even once the pack's copy has left the deck.
func test_the_preset_skips_a_drafted_sticker() -> void:
	var run: RunState = _pack_run(6)
	var own: CardInstance = null
	for card: CardInstance in run.deck.cards:
		if own == null and FamilySticker.is_family_sticker(card.definition):
			own = card  # The pack's, dealt before any shared coupon.
	var drafted: CardInstance = run.deck.add_card(load(STICKER))
	assert_str(FamilySticker.chosen(run, own)).is_equal("Breakfast")
	assert_str(FamilySticker.chosen(run, drafted)).is_empty()
	run.deck.remove_card(own)
	assert_str(FamilySticker.chosen(run, drafted)).is_empty()
	assert_bool(FamilySticker.chosen_all(run).has(drafted.instance_id)).is_false()


## A run dealt the old Breakfast sticker gets no preset on a Family sticker drafted later.
func test_a_former_pack_gives_no_preset() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var saved: Dictionary = _saved(_pack_run(7))
	var old: Dictionary = JSON.parse_string(
		JSON.stringify(saved).replace('"family_sticker"', '"breakfast_sticker"')
	)
	old["format_version"] = 11
	old.erase("sticker_families")
	var resumed: RunState = RunSave.from_dictionary(old, lookup).run
	var drafted: CardInstance = resumed.deck.add_card(load(STICKER))
	assert_str(FamilySticker.chosen(resumed, drafted)).is_empty()


## The ticket's words: "Next joins <family>" for a copy's family, "Next joins your pick" with none.
func test_the_ticket_reads_the_family() -> void:
	var sticker: CardDefinition = load(STICKER)
	assert_str(CardText.sticker_summary(sticker)).is_equal("Next joins your pick")
	assert_str(CardText.sticker_summary(sticker, -1, "Dairy")).is_equal("Next joins Dairy")
	var old: CardDefinition = load(OLD_STICKER)
	assert_str(CardText.sticker_summary(old, -1, "Dairy")).is_equal("Next gains Breakfast")


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


## The run save (format 12) keeps the picks; a version 11 save reads with none.
func test_the_run_save_keeps_the_picks() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = _run(5)
	var sticker: CardInstance = run.deck.add_card(load(STICKER))
	run.sticker_families[sticker.instance_id] = "Clearance"
	var saved: Dictionary = _saved(run)
	assert_int(int(saved["format_version"])).is_equal(12)
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


## A run dealt the Breakfast run before v1.29 holds the old Breakfast sticker: its version 11 save
## still resumes (the pack's former cards) and its sticker still plays.
func test_an_old_breakfast_run_save_resumes_and_plays() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = _pack_run(7)
	var saved: Dictionary = _saved(run)
	var old: Dictionary = JSON.parse_string(
		JSON.stringify(saved).replace('"family_sticker"', '"breakfast_sticker"')
	)
	old["format_version"] = 11
	old.erase("sticker_families")
	assert_bool(JSON.stringify(old).contains("breakfast_sticker")).is_true()
	var read: RunSave = RunSave.from_dictionary(old, lookup)
	assert_object(read).is_not_null()
	var resumed: RunState = read.run
	var held: CardInstance = null
	for card: CardInstance in resumed.deck.cards:
		if card.definition.id == &"breakfast_sticker":
			held = card
	assert_object(held).is_not_null()
	var banana: CardInstance = resumed.debug_add_to_hand(load(BANANA))
	if not resumed.hand().has(held):
		held = resumed.debug_add_to_hand(load(OLD_STICKER))
	assert_bool(resumed.place(held, 0)).is_true()
	assert_bool(resumed.place(banana, 1)).is_true()
	assert_bool(resumed.preview().tags[1].has("Breakfast")).is_true()
	assert_object(resumed.checkout()).is_not_null()


## A run dealt the Bargain bin before v1.29 (Clearance tag, Dented can, Big Flickering bulb):
## its version 11 save still resumes (the pack's former cards) and its cards play.
func test_an_old_bargain_bin_save_resumes_and_plays() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = _pack_run(9, BARGAIN_BIN)
	var saved: Dictionary = _saved(run)
	var core_size: int = run.starter.core_cards.size()
	var former: Dictionary = {
		core_size: "clearance_tag",
		core_size + 1: "dented_can",
		core_size + 2: "flickering_bulb_big"
	}
	var old: Dictionary = saved.duplicate(true)
	for index: int in former:
		old["starting_deck"][index] = former[index]
		# Deck.from_definition numbers the starting cards from FIRST_INSTANCE_ID in order.
		var id: int = index + Deck.FIRST_INSTANCE_ID
		for key: String in ["deck", "hand"]:
			for pair: Array in old[key]:
				if int(pair[0]) == id:
					pair[1] = former[index]
	old["format_version"] = 11
	old.erase("sticker_families")
	var read: RunSave = RunSave.from_dictionary(old, lookup)
	assert_object(read).is_not_null()
	var resumed: RunState = read.run
	var ids: Array[String] = []
	for card: CardInstance in resumed.deck.cards:
		ids.append(String(card.definition.id))
	for id: String in ["clearance_tag", "dented_can", "flickering_bulb_big"]:
		assert_bool(ids.has(id)).override_failure_message(id).is_true()
	assert_object(resumed.checkout()).is_not_null()
	# Without the former cards the same save is refused.
	var pack: StarterPackDefinition = load(BARGAIN_BIN)
	var kept: Array[CardDefinition] = pack.former_cards
	pack.former_cards = []
	assert_object(RunSave.from_dictionary(old, lookup)).is_null()
	pack.former_cards = kept


func _run(seed_value: int) -> RunState:
	var run: RunState = RunState.new(
		seed_value, load(STARTER), _balance, RunStock.starting(_balance)
	)
	run.start_shift()
	return run


## A run that took the starter pack at `pack_path` (the Breakfast run), at shift 1's planning;
## a pack the seed's offer lacks takes its first place.
func _pack_run(seed_value: int, pack_path: String = BREAKFAST_RUN) -> RunState:
	var recipe: DeckDefinition = load(RECIPE)
	var stock: RunStock = RunStock.starting(_balance)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.STARTING_DECK_STREAM
	)
	var offer: StartOffer = StartingDeck.deal_offer(recipe, stock, _balance, stream, true)
	var pack: StarterPackDefinition = load(pack_path)
	if not offer.packs.has(pack):
		offer.packs[0] = pack
	assert_bool(offer.packs.has(pack)).is_true()
	var deck: DeckDefinition = StartingDeck.before_pick(recipe, offer)
	var run: RunState = RunState.new(seed_value, deck, _balance, stock, offer)
	assert_bool(run.take_pack(pack)).is_true()
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
