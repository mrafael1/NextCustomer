extends GdUnitTestSuite
## The run save (full build plan section 4): RunSave's saved form at every save point, read
## back through JSON text, gives the same run, and a run saved and restored after every action
## plays exactly like one that never stopped. A save that can't be resumed reads as null and
## prints nothing.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const UNSTOCKED := &"test_unstocked"

var _balance: BalanceDefinition
var _lookup: ContentLookup


func before_test() -> void:
	# Quotas of 1: every row with a product passes, so a scripted run reaches its end.
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	_lookup = ContentLookup.new(_balance)


func test_only_the_four_stable_phases_are_saved() -> void:
	var saved: Array[String] = []
	for phase: RunState.Phase in RunState.Phase.values():
		var run: RunState = _new_run(1)
		run.phase = phase
		if RunSave.is_save_point(phase):
			assert_bool(RunSave.to_dictionary(run, "id", 0).is_empty()).is_false()
			saved.append(RunSave.phase_name(phase))
		else:
			assert_dict(RunSave.to_dictionary(run, "id", 0)).is_empty()
			assert_str(RunSave.phase_name(phase)).is_empty()
	assert_array(saved).is_equal(["impulse_rack", "planning", "reward", "upgrade"])


func test_the_impulse_rack_round_trips() -> void:
	var run: RunState = _new_run(11)
	assert_int(run.phase).is_equal(RunState.Phase.IMPULSE)
	var restored: RunState = _round_trip(run)
	assert_array(restored.offer).is_equal(run.impulse_offer)
	assert_array(restored.impulse_offer).is_equal(run.impulse_offer)
	# The restored rack is picked like the original one.
	assert_bool(restored.take_reward(restored.offer[1])).is_true()
	assert_bool(run.take_reward(run.offer[1])).is_true()
	restored.start_shift()
	run.start_shift()
	assert_str(_observe(restored)).is_equal(_observe(run))


func test_a_fresh_shift_round_trips() -> void:
	var run: RunState = _planning_run(12)
	var restored: RunState = _round_trip(run)
	assert_int(restored.hand().size()).is_equal(8)
	assert_object(restored.impulse_pick).is_same(run.impulse_pick)
	# Hand cards are the deck's own instances.
	for card: CardInstance in restored.hand():
		assert_bool(restored.deck.cards.has(card)).is_true()


func test_a_shift_after_places_removes_and_redraws_round_trips() -> void:
	var run: RunState = _planning_run(13)
	var hand: Array[CardInstance] = run.hand()
	assert_bool(run.place(hand[0], 0)).is_true()
	assert_bool(run.place(hand[1], 0)).is_true()
	assert_bool(run.place(hand[2], 1)).is_true()
	assert_bool(run.remove(hand[1])).is_true()
	var set_aside: Array[CardInstance] = [hand[3], hand[4]]
	assert_int(run.redraw(set_aside).size()).is_equal(2)
	var debug_card: CardInstance = run.debug_add_to_hand(load(BREAD))
	assert_bool(run.place(debug_card, 0)).is_true()
	var restored: RunState = _round_trip(run)
	assert_array(_instance_ids(restored.row)).is_equal(_instance_ids(run.row))
	assert_int(restored.redraws_used).is_equal(1)
	assert_bool(restored.can_redraw([restored.hand()[0]])).is_false()
	# The redraw's set-aside cards stay out of the hand and the draw pile.
	var restored_pile: Array = _instance_ids(restored.deck.draw_pile())
	for card: CardInstance in set_aside:
		assert_bool(restored_pile.has(card.instance_id)).is_false()
		assert_bool(_instance_ids(restored.hand()).has(card.instance_id)).is_false()
	# The debug copy is in the hand and the row, but not in the deck.
	assert_bool(_instance_ids(restored.deck.cards).has(debug_card.instance_id)).is_false()
	assert_int(restored.row[0].instance_id).is_equal(debug_card.instance_id)
	assert_int(restored.preview().total).is_equal(run.preview().total)


func test_a_reward_round_trips() -> void:
	var run: RunState = _planning_run(14)
	_fill(run)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	var restored: RunState = _round_trip(run)
	assert_int(restored.last_result.total).is_equal(run.last_result.total)
	assert_bool(restored.passed()).is_true()
	assert_array(restored.offer).is_equal(run.offer)


## Shift 2 is an upgrade shift and shift 3 is inspected: its checkout builds an upgrade offer
## and draws the next inspection, kept through the reward and the upgrade.
func test_a_reward_on_an_upgrade_shift_round_trips_with_the_next_inspection() -> void:
	var run: RunState = _run_at_shift_two_checkout(15)
	assert_array(run.upgrade_offer).is_not_empty()
	assert_object(run.next_inspection).is_not_null()
	var restored: RunState = _round_trip(run)
	assert_array(restored.upgrade_offer).is_equal(run.upgrade_offer)
	assert_object(restored.next_inspection).is_same(run.next_inspection)
	assert_bool(restored.deck_is_full()).is_true()


func test_an_upgrade_after_a_deck_full_replacement_round_trips() -> void:
	var run: RunState = _run_at_shift_two_checkout(16)
	var replaced: CardInstance = run.row[0]
	assert_bool(run.take_reward(run.offer[0], replaced)).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)
	var restored: RunState = _round_trip(run)
	# The replaced card left the deck but stays in the row the receipt scored.
	assert_int(restored.row[0].instance_id).is_equal(replaced.instance_id)
	assert_bool(_instance_ids(restored.deck.cards).has(replaced.instance_id)).is_false()
	assert_int(restored.last_result.total).is_equal(run.last_result.total)
	assert_bool(restored.pick_upgrade(restored.upgrade_offer[0])).is_true()
	assert_bool(run.pick_upgrade(run.upgrade_offer[0])).is_true()
	assert_bool(restored.next_shift()).is_true()
	assert_bool(run.next_shift()).is_true()
	assert_str(_observe(restored)).is_equal(_observe(run))
	assert_array(restored.inspections).is_not_empty()


func test_a_debug_jump_round_trips() -> void:
	var run: RunState = _planning_run(17)
	run.debug_skip_to_shift(4)
	assert_bool(run.debug_jumped).is_true()
	var restored: RunState = _round_trip(run)
	assert_int(restored.shift_index).is_equal(4)
	assert_array(restored.history).is_empty()


## The debug shift jump to the shift on its own reward screen restarts it but keeps its record,
## so it counts as a jump too and its save still resumes.
func test_a_debug_restart_after_a_checkout_round_trips() -> void:
	var run: RunState = _planning_run(18)
	_fill(run)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	run.debug_skip_to_shift(run.shift_index)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(run.debug_jumped).is_true()
	var restored: RunState = _round_trip(run)
	assert_int(restored.history.size()).is_equal(1)
	# A restart of a shift that hasn't been checked out is no jump.
	var fresh: RunState = _planning_run(19)
	fresh.debug_skip_to_shift(0)
	assert_bool(fresh.debug_jumped).is_false()


## A resumed run continues exactly as if it had never stopped: the same scripted run, saved and
## restored through JSON text after every action, gives every same hand, offer, upgrade offer,
## inspection and total.
func test_a_run_restored_after_every_action_plays_like_one_that_never_stopped() -> void:
	for seed_value: int in [5, 99, 4242]:
		var straight: Array[String] = _play(seed_value, false)
		var resumed: Array[String] = _play(seed_value, true)
		assert_int(resumed.size()).is_equal(straight.size())
		assert_array(resumed).is_equal(straight)
		assert_str(straight[-1]).contains('"phase":%d' % RunState.Phase.WON)


func test_large_seeds_and_rng_states_survive_json() -> void:
	var int64_min: int = -9223372036854775807 - 1
	for value: int in [int64_min, -7046029254386353131, 9007199254740993, 9223372036854775807]:
		var run: RunState = _new_run(value)
		run.rng_state = value
		var restored: RunState = _round_trip(run)
		assert_int(restored.run_seed).is_equal(value)
		assert_int(restored.rng_state).is_equal(value)
		# The same state draws the same numbers.
		restored.skip_reward()
		run.skip_reward()
		restored.start_shift()
		run.start_shift()
		assert_array(_instance_ids(restored.hand())).is_equal(_instance_ids(run.hand()))


func test_the_run_id_and_played_time_are_kept() -> void:
	var data: Dictionary = _json(RunSave.to_dictionary(_new_run(3), "abc123", 98765))
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_str(save.run_id).is_equal("abc123")
	assert_int(save.run_ms).is_equal(98765)
	assert_int(int(data["format_version"])).is_equal(RunSave.FORMAT_VERSION)


func test_a_save_that_cant_be_resumed_reads_as_null() -> void:
	var planning: Dictionary = _json(_save(_planning_run(21)))
	var reward: Dictionary = _json(_save(_run_at_shift_two_checkout(22)))
	var rack: Dictionary = _json(_save(_new_run(23)))
	var upgrade_run: RunState = _run_at_shift_two_checkout(24)
	upgrade_run.skip_reward()
	var upgrade: Dictionary = _json(_save(upgrade_run))
	# A card that resolves but isn't in the stock.
	var unstocked: CardDefinition = CardDefinition.new()
	unstocked.id = UNSTOCKED
	unstocked.kind = CardDefinition.Kind.PRODUCT
	_lookup.add(unstocked)
	var cases: Dictionary[String, Array] = {
		"no format version": [planning, func(d: Dictionary) -> void: d.erase("format_version")],
		"newer format": [planning, func(d: Dictionary) -> void: d["format_version"] = 2],
		"format as text": [planning, func(d: Dictionary) -> void: d["format_version"] = "1"],
		"seed as a number": [planning, func(d: Dictionary) -> void: d["seed"] = 12],
		"seed not a number": [planning, func(d: Dictionary) -> void: d["seed"] = "12a"],
		"seed too big": [planning, func(d: Dictionary) -> void: d["seed"] = "9223372036854775808"],
		"no rng state": [planning, func(d: Dictionary) -> void: d.erase("rng_state")],
		"phase scored": [planning, func(d: Dictionary) -> void: d["phase"] = "scored"],
		"phase won": [planning, func(d: Dictionary) -> void: d["phase"] = "won"],
		"shift past quotas": [planning, func(d: Dictionary) -> void: d["shift_index"] = 8],
		"negative shift": [planning, func(d: Dictionary) -> void: d["shift_index"] = -1],
		"fractional shift": [planning, func(d: Dictionary) -> void: d["shift_index"] = 0.5],
		"unknown starter": [planning, func(d: Dictionary) -> void: d["starter"] = "gone"],
		"unknown deck card": [planning, func(d: Dictionary) -> void: d["deck"][0][1] = "gone"],
		"deck pair too short": [planning, func(d: Dictionary) -> void: d["deck"][0] = [1]],
		"instance id zero": [planning, func(d: Dictionary) -> void: d["deck"][0][0] = 0],
		"unknown hand card": [planning, func(d: Dictionary) -> void: d["hand"][0][1] = "gone"],
		"unknown upgrade": [planning, func(d: Dictionary) -> void: d["upgrades"] = ["gone"]],
		"id as path": [planning, func(d: Dictionary) -> void: d["starter"] = "../decks/starter"],
		"unknown aisle": [planning, func(d: Dictionary) -> void: d["listed_aisles"] = ["gone"]],
		"unknown stock card": [planning, func(d: Dictionary) -> void: d["stock"].append("gone")],
		"arrival not stocked":
		[planning, func(d: Dictionary) -> void: d["new_arrivals"] = [String(UNSTOCKED)]],
		"stock not a list": [planning, func(d: Dictionary) -> void: d["stock"] = "banana"],
		"run id a number": [planning, func(d: Dictionary) -> void: d["run_id"] = 7],
		"negative run time": [planning, func(d: Dictionary) -> void: d["run_ms"] = -1],
		"flag as text": [planning, func(d: Dictionary) -> void: d["list_skipped"] = "true"],
		"history too long": [planning, func(d: Dictionary) -> void: d["history"].append(_record())],
		"history too short": [reward, func(d: Dictionary) -> void: d["history"].pop_back()],
		"record shift wrong": [reward, func(d: Dictionary) -> void: d["history"][0]["shift"] = 2],
		"record passed wrong":
		[reward, func(d: Dictionary) -> void: d["history"][0]["passed"] = false],
		"record without total":
		[reward, func(d: Dictionary) -> void: d["history"][0].erase("total")],
		"total not the row's":
		[reward, func(d: Dictionary) -> void: d["history"][-1]["total"] += 1],
		"reward without offer": [reward, func(d: Dictionary) -> void: d["offer"] = []],
		"reward already picked":
		[reward, func(d: Dictionary) -> void: d["history"][-1]["reward_skipped"] = true],
		"upgrade without offer": [upgrade, func(d: Dictionary) -> void: d["upgrade_offer"] = []],
		"row card not in hand": [reward, func(d: Dictionary) -> void: d["row"].append(999)],
		"row card twice": [reward, func(d: Dictionary) -> void: d["row"].append(d["row"][0])],
		"pile card not in deck":
		[planning, func(d: Dictionary) -> void: d["draw_pile"].append(999)],
		"pile card in hand":
		[planning, func(d: Dictionary) -> void: d["draw_pile"].append(d["hand"][0][0])],
		"deck ids repeat":
		[planning, func(d: Dictionary) -> void: d["deck"][1][0] = d["deck"][0][0]],
		"hand ids repeat": [planning, func(d: Dictionary) -> void: d["hand"][1] = d["hand"][0]],
		"hand card not the deck's":
		[planning, func(d: Dictionary) -> void: d["hand"][0][1] = _other_card(d["hand"][0][1])],
		"next id too low": [planning, func(d: Dictionary) -> void: d["next_instance_id"] = 2],
		"redraws over the limit": [planning, func(d: Dictionary) -> void: d["redraws_used"] = 5],
		"planning with an offer": [planning, func(d: Dictionary) -> void: d["offer"] = ["bread"]],
		"rack with a hand": [rack, func(d: Dictionary) -> void: d["hand"] = [[1, "banana"]]],
		"rack offer differs": [rack, func(d: Dictionary) -> void: d["offer"].pop_back()],
		"rack after shift 1": [rack, func(d: Dictionary) -> void: d["shift_index"] = 1],
		"pick not offered":
		[planning, func(d: Dictionary) -> void: d["impulse_pick"] = _not_in(d["impulse_offer"])],
		"row over the card limit":
		[planning, func(d: Dictionary) -> void: d["row"] = d["hand"].map(_first)],
		"row over the product limit": [planning, _over_products],
	}
	for case_name: String in cases:
		var data: Dictionary = (cases[case_name][0] as Dictionary).duplicate(true)
		(cases[case_name][1] as Callable).call(data)
		var save: RunSave = RunSave.from_dictionary(data, _lookup)
		assert_object(save).override_failure_message(case_name).is_null()
	# Every base save is itself readable.
	for data: Dictionary in [planning, reward, rack, upgrade]:
		assert_object(RunSave.from_dictionary(data, _lookup)).is_not_null()


## Plays a scripted run: the rack's first card, then each shift a redraw of two cards, every
## card that fits placed at the end, the first row card removed and placed back, the checkout,
## the reward's first card (replacing a deck card when the deck is full) and the first upgrade.
## Each step's observed state is logged; with `resume`, the run is saved and restored through
## JSON text at every save point.
## A save made with a full row, read with a balance that has fewer product slots (tuned between
## sessions), can't be resumed: the row would no longer fit.
func test_a_save_whose_row_no_longer_fits_the_balance_reads_as_null() -> void:
	var planning: RunState = _planning_run(25)
	_fill(planning)
	var reward: RunState = _run_at_shift_two_checkout(26)
	var fewer_slots: BalanceDefinition = _balance.duplicate()
	fewer_slots.slot_count -= 1
	for run: RunState in [planning, reward]:
		assert_int(RowCapacity.product_count(run.row)).is_equal(_balance.slot_count)
		var data: Dictionary = _json(_save(run))
		assert_object(RunSave.from_dictionary(data, _lookup)).is_not_null()
		var stale: RunSave = RunSave.from_dictionary(data, ContentLookup.new(fewer_slots))
		assert_object(stale).override_failure_message(RunSave.phase_name(run.phase)).is_null()


func _play(seed_value: int, resume: bool) -> Array[String]:
	var steps: Array[String] = []
	var run: RunState = _checkpoint(_new_run(seed_value), resume, steps)
	run.take_reward(run.offer[0])
	run.start_shift()
	run = _checkpoint(run, resume, steps)
	while run.phase == RunState.Phase.PLANNING:
		var hand: Array[CardInstance] = run.hand()
		run.redraw([hand[0], hand[1]])
		run = _checkpoint(run, resume, steps)
		var placed: bool = true
		while placed:
			placed = false
			for card: CardInstance in run.hand():
				if run.place(card, run.row.size()):
					placed = true
					run = _checkpoint(run, resume, steps)
					break
		var first: CardInstance = run.row[0]
		run.remove(first)
		run = _checkpoint(run, resume, steps)
		run.place(_by_instance_id(run.hand(), first.instance_id), 0)
		run = _checkpoint(run, resume, steps)
		run.checkout()
		run = _checkpoint(run, resume, steps)
		if run.phase != RunState.Phase.REWARD:
			break
		var replaced: CardInstance = null
		if run.deck_is_full():
			replaced = run.deck.cards[run.shift_index % run.deck.size()]
		run.take_reward(run.offer[0], replaced)
		run = _checkpoint(run, resume, steps)
		if run.phase == RunState.Phase.UPGRADE:
			run.pick_upgrade(run.upgrade_offer[0])
		run.next_shift()
		run = _checkpoint(run, resume, steps)
	return steps


## Logs the run's observed state; with `resume` at a save point, returns the run restored from
## its saved form through JSON text.
func _checkpoint(run: RunState, resume: bool, steps: Array[String]) -> RunState:
	steps.append(_observe(run))
	if not resume or not RunSave.is_save_point(run.phase):
		return run
	var save: RunSave = RunSave.from_dictionary(_json(_save(run)), _lookup)
	assert_object(save).is_not_null()
	return save.run


## Saves, reads back through JSON text, checks the saved form is unchanged and the observed state
## matches, and returns the restored run.
func _round_trip(run: RunState) -> RunState:
	var data: Dictionary = RunSave.to_dictionary(run, "run-1", 4321)
	assert_dict(data).is_not_empty()
	var save: RunSave = RunSave.from_dictionary(_json(data), _lookup)
	assert_object(save).is_not_null()
	var again: Dictionary = RunSave.to_dictionary(save.run, save.run_id, save.run_ms)
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	assert_bool(again == data).is_true()
	assert_str(_observe(save.run)).is_equal(_observe(run))
	return save.run


## What a player or the UI can see of the run, as JSON text.
func _observe(run: RunState) -> String:
	var hand: Array[CardInstance] = run.hand()
	var state: Dictionary = {
		"phase": run.phase,
		"shift": run.shift_index,
		"quota": run.quota(),
		"hand": _pairs(hand),
		"row": _pairs(run.row),
		"deck": _pairs(run.deck.cards),
		"deck_size": run.deck.size(),
		"deck_is_full": run.deck_is_full(),
		"can_redraw": not hand.is_empty() and run.can_redraw([hand[0]]),
		"redraws": [run.redraws_used, run.redraws_allowed],
		"offer": _ids(run.offer),
		"offers_made": run.offers_made,
		"upgrade_offer": _ids(run.upgrade_offer),
		"upgrades": _ids(run.upgrades),
		"inspections": _ids(run.inspections),
		"next_inspection": _ids([run.next_inspection] if run.next_inspection != null else []),
		"impulse":
		[_ids(run.impulse_offer), _ids([run.impulse_pick] if run.impulse_pick != null else [])],
		"history":
		run.history.map(func(record: ShiftRecord) -> Dictionary: return record.to_dictionary()),
		"last_total": run.last_result.total if run.last_result != null else -1,
		"preview": run.preview().total,
	}
	return JSON.stringify(state)


func _new_run(seed_value: int) -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.IMPULSE_RACK_STREAM
	)
	return RunState.new(seed_value, deck, _balance, RunStock.starting(deck, _balance), stream)


## Shift 1 after the rack's first card.
func _planning_run(seed_value: int) -> RunState:
	var run: RunState = _new_run(seed_value)
	run.take_reward(run.offer[0])
	run.start_shift()
	return run


## Shift 2's checkout, after the rack's card and shift 1's reward: the deck is full (15).
func _run_at_shift_two_checkout(seed_value: int) -> RunState:
	var run: RunState = _planning_run(seed_value)
	_fill(run)
	run.checkout()
	run.take_reward(run.offer[0])
	run.next_shift()
	_fill(run)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	return run


func _fill(run: RunState) -> void:
	for card: CardInstance in run.hand():
		run.place(card, run.row.size())


func _save(run: RunState) -> Dictionary:
	return RunSave.to_dictionary(run, "run-1", 10)


## Through JSON text and back, as a file would be read: every number becomes a float.
static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data


## Fills the row with one product more than the product slots, and no more cards than the row
## holds: extra Banana copies join the hand, as the debug panel adds them.
func _over_products(data: Dictionary) -> void:
	assert_int(_balance.slot_count + 1).is_less_equal(RowCapacity.card_limit(_balance))
	var products: Array = []
	for pair: Array in data["hand"]:
		if not _lookup.card(pair[1]).is_coupon():
			products.append(pair[0])
	var next_id: int = int(data["next_instance_id"])
	while products.size() <= _balance.slot_count:
		data["hand"].append([next_id, "banana"])
		products.append(next_id)
		next_id += 1
	data["next_instance_id"] = next_id
	data["row"] = products.slice(0, _balance.slot_count + 1)


static func _first(pair: Array) -> Variant:
	return pair[0]


static func _record() -> Dictionary:
	return ShiftRecord.new(1, 1, 5).to_dictionary()


## A card id other than `id`.
static func _other_card(id: String) -> String:
	return "bread" if id != "bread" else "banana"


## A stocked product that isn't in the offer.
static func _not_in(offer: Array) -> String:
	for id: String in ["banana", "bread", "milk", "eggs", "cheese"]:
		if not offer.has(id):
			return id
	return ""


static func _by_instance_id(cards: Array[CardInstance], id: int) -> CardInstance:
	for card: CardInstance in cards:
		if card.instance_id == id:
			return card
	return null


static func _pairs(cards: Array[CardInstance]) -> Array:
	var pairs: Array = []
	for card: CardInstance in cards:
		pairs.append([card.instance_id, String(card.definition.id)])
	return pairs


static func _instance_ids(cards: Array[CardInstance]) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids


static func _ids(resources: Array) -> Array:
	var ids: Array = []
	for resource: Resource in resources:
		ids.append(str(resource.get("id")))
	return ids
