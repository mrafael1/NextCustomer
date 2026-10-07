class_name RunSave
extends RefCounted
## The run save (full build plan section 4): a snapshot of a run at a stable point, so a
## resumed run continues exactly as if it had never stopped, with the same later draws,
## redraws, offers and inspections. Pure: SaveService reads and writes the file.
##
## The save points are the phases where the game waits for the player: IMPULSE (the rack is
## shown), PLANNING (at the shift's start and after every place, remove and redraw), REWARD and
## UPGRADE. SCORED is passed straight through and WON / LOST end the run, so they are never
## saved. The saved form holds what rebuilds the run (the seed, the impulse rack's offer, pick
## and replaced card, the stock's listed aisles, card ids, list_skipped and new arrivals) and the
## whole state: the deck's cards with their instance ids, the hand, the draw pile, the row, the
## redraws, the offers, the upgrades, the inspections, the history and the RNG's state, plus the
## telemetry's run id and played time. Ids resolve through a ContentLookup, and the stock is
## restored from its ids, so a resume never depends on a profile that changed after the run
## started.
##
## The seed and the RNG state are decimal strings: JSON numbers are doubles and lose precision
## above 2^53. The draw pile is saved only during PLANNING (the next shift reshuffles the whole
## deck, so it means nothing after the checkout).

## The run save's format version. Raise it when the saved form changes, and read the older
## versions in from_dictionary.
const FORMAT_VERSION := 1
## The save points, and their names in the saved form (the run_resume event uses them too).
const SAVE_POINTS: Array[RunState.Phase] = [
	RunState.Phase.IMPULSE, RunState.Phase.PLANNING, RunState.Phase.REWARD, RunState.Phase.UPGRADE
]
const PHASE_NAMES: Array[String] = ["impulse_rack", "planning", "reward", "upgrade"]

var run: RunState
## The telemetry run id the run was logged under.
var run_id: String = ""
## Played time so far, in milliseconds.
var run_ms: int = 0


static func is_save_point(phase: RunState.Phase) -> bool:
	return SAVE_POINTS.has(phase)


## A save point's name in the saved form ("impulse_rack", "planning", "reward", "upgrade"), or ""
## for another phase.
static func phase_name(phase: RunState.Phase) -> String:
	var index: int = SAVE_POINTS.find(phase)
	return PHASE_NAMES[index] if index != -1 else ""


## The saved form: JSON types only, with FORMAT_VERSION. Empty when the run isn't at a save
## point.
static func to_dictionary(saved_run: RunState, saved_run_id: String, played_ms: int) -> Dictionary:
	if not is_save_point(saved_run.phase):
		return {}
	var planning: bool = saved_run.phase == RunState.Phase.PLANNING
	var data: Dictionary = {
		"format_version": FORMAT_VERSION,
		"run_id": saved_run_id,
		"run_ms": played_ms,
		"seed": str(saved_run.run_seed),
		"rng_state": str(saved_run.rng_state),
		"starter": String(saved_run.starter.id),
		"phase": phase_name(saved_run.phase),
		"shift_index": saved_run.shift_index,
		"debug_jumped": saved_run.debug_jumped,
		"list_skipped": saved_run.stock.list_skipped,
		"new_arrivals": _ids(saved_run.stock.new_arrivals),
		"impulse_offer": _ids(saved_run.impulse_offer),
		"impulse_pick": _id(saved_run.impulse_pick),
		"impulse_replaced": _id(saved_run.impulse_replaced),
		"deck": _pairs(saved_run.deck.cards),
		"next_instance_id": saved_run.deck.next_instance_id(),
		"hand": _pairs(saved_run.deck.hand()),
		"draw_pile": _instance_ids(saved_run.deck.draw_pile()) if planning else [],
		"row": _instance_ids(saved_run.row),
		"redraws_used": saved_run.redraws_used,
		"redraws_allowed": saved_run.redraws_allowed,
		"offers_made": saved_run.offers_made,
		"offer": _ids(saved_run.offer),
		"upgrade_offer": _ids(saved_run.upgrade_offer),
		"upgrades": _ids(saved_run.upgrades),
		"inspections": _ids(saved_run.inspections),
		"next_inspection": _id(saved_run.next_inspection),
		"history":
		saved_run.history.map(
			func(record: ShiftRecord) -> Dictionary: return record.to_dictionary()
		),
	}
	# "listed_aisles" and "stock", the same as run_start logs.
	data.merge(saved_run.stock.to_dictionary())
	return data


## Reads the saved form (as parsed from JSON: numbers may be floats). Returns null when it
## isn't a run this version can resume: a missing or newer format version, a field missing or
## of the wrong type, an id that no longer resolves, or a state the game can't reach (see
## _is_consistent). Never prints anything.
static func from_dictionary(data: Dictionary, lookup: ContentLookup) -> RunSave:
	var version: Variant = data.get("format_version")
	if not SaveReader.is_whole(version) or int(version) < 1 or int(version) > FORMAT_VERSION:
		return null
	var reader: SaveReader = SaveReader.new(data, lookup)
	var starter: DeckDefinition = reader.deck("starter")
	var stock: RunStock = RunStock.from_saved(
		reader.cards("stock"),
		reader.aisles("listed_aisles"),
		reader.flag("list_skipped"),
		reader.cards("new_arrivals")
	)
	var phase_index: int = PHASE_NAMES.find(reader.text("phase"))
	if not reader.ok or phase_index == -1:
		return null
	# No impulse stream: the saved offer is restored instead of drawn again.
	var restored: RunState = RunState.new(reader.int64("seed"), starter, lookup.balance, stock)
	restored.rng_state = reader.int64("rng_state")
	restored.phase = SAVE_POINTS[phase_index]
	restored.shift_index = reader.whole("shift_index")
	restored.debug_jumped = reader.flag("debug_jumped")
	restored.impulse_offer = reader.cards("impulse_offer")
	restored.impulse_pick = reader.card("impulse_pick")
	restored.impulse_replaced = reader.card("impulse_replaced")
	restored.redraws_used = reader.whole("redraws_used")
	restored.redraws_allowed = reader.whole("redraws_allowed")
	restored.offers_made = reader.whole("offers_made")
	restored.offer = reader.cards("offer")
	restored.upgrade_offer = reader.upgrades("upgrade_offer")
	restored.upgrades = reader.upgrades("upgrades")
	restored.inspections = reader.inspections("inspections")
	restored.next_inspection = reader.inspection("next_inspection")
	var history_ok: bool = _restore_history(restored, reader.dictionaries("history"), lookup)
	var cards_ok: bool = _restore_cards(restored, reader)
	var save: RunSave = RunSave.new()
	save.run = restored
	save.run_id = reader.text("run_id")
	save.run_ms = reader.whole("run_ms")
	if not reader.ok or not history_ok or not cards_ok or not _is_consistent(restored):
		return null
	return save


static func _restore_history(
	restored: RunState, records: Array[Dictionary], lookup: ContentLookup
) -> bool:
	for record_data: Dictionary in records:
		var record: ShiftRecord = ShiftRecord.from_dictionary(record_data, lookup)
		if record == null:
			return false
		restored.history.append(record)
	return true


## Puts back the deck, the hand, the draw pile and the row by instance id. False when an
## instance id repeats, a hand card has a deck card's id but another card, a draw-pile card
## isn't a deck card (or is in the hand), a row card isn't in the hand, or the next instance id
## isn't above every id.
static func _restore_cards(restored: RunState, reader: SaveReader) -> bool:
	var deck_cards: Array[CardInstance] = reader.instances("deck")
	var saved_hand: Array[CardInstance] = reader.instances("hand")
	var pile_ids: Array[int] = reader.wholes("draw_pile", 1)
	var row_ids: Array[int] = reader.wholes("row", 1)
	var next_id: int = reader.whole("next_instance_id", 1)
	var deck_by_id: Dictionary[int, CardInstance] = {}
	var ok: bool = _index(deck_cards, deck_by_id)
	var hand: Array[CardInstance] = []
	for card: CardInstance in saved_hand:
		var deck_card: CardInstance = deck_by_id.get(card.instance_id)
		if deck_card == null:
			hand.append(card)
		else:
			ok = ok and deck_card.definition == card.definition
			hand.append(deck_card)
	var hand_by_id: Dictionary[int, CardInstance] = {}
	ok = _index(hand, hand_by_id) and ok
	var pile: Array[CardInstance] = []
	for id: int in pile_ids:
		ok = ok and deck_by_id.has(id) and not hand_by_id.has(id) and pile_ids.count(id) == 1
		if deck_by_id.has(id):
			pile.append(deck_by_id[id])
	for id: int in row_ids:
		ok = ok and hand_by_id.has(id) and row_ids.count(id) == 1
		if hand_by_id.has(id):
			restored.row.append(hand_by_id[id])
	for id: int in deck_by_id.keys() + hand_by_id.keys():
		ok = ok and id < next_id
	restored.deck.restore(deck_cards, hand, pile, next_id)
	return ok


## Adds each card by instance id; false when an id repeats.
static func _index(cards: Array[CardInstance], into: Dictionary[int, CardInstance]) -> bool:
	var ok: bool = true
	for card: CardInstance in cards:
		ok = ok and not into.has(card.instance_id)
		into[card.instance_id] = card
	return ok


## Whether the restored run is a state the game reaches at its save point. Restores
## last_result in REWARD and UPGRADE: the row is kept until the next shift starts, so scoring it
## again gives the checkout's result, which must be the last record's total.
static func _is_consistent(restored: RunState) -> bool:
	if restored.shift_index >= restored.shift_count():
		return false
	var ok: bool = _history_fits(restored) and _phase_fits(restored)
	# The row's limits, as place() keeps them: a save made before the balance's slots were
	# lowered can't be resumed.
	ok = ok and restored.row.size() <= RowCapacity.card_limit(restored.balance)
	ok = ok and RowCapacity.product_count(restored.row) <= restored.balance.slot_count
	ok = ok and restored.redraws_used <= restored.redraws_allowed
	ok = ok and (restored.impulse_pick == null or restored.impulse_offer.has(restored.impulse_pick))
	ok = ok and (restored.impulse_replaced == null or restored.impulse_pick != null)
	for card: CardDefinition in restored.stock.new_arrivals:
		ok = ok and restored.stock.cards.has(card)
	for upgrade: UpgradeDefinition in restored.upgrades:
		ok = ok and restored.upgrades.count(upgrade) == 1
	if not ok or not _after_checkout(restored):
		return ok
	restored.last_result = Scoring.score(restored.row, restored.upgrades, restored.inspections)
	return restored.last_result.total == restored.history[-1].total and restored.passed()


## Every played shift was passed (a lost shift ends the run). One record per shift before the
## current one, plus the current one after its checkout; a debug jump keeps only the last
## record's shift number to check.
static func _history_fits(restored: RunState) -> bool:
	var ok: bool = true
	for record: ShiftRecord in restored.history:
		ok = ok and record.passed
	var after: bool = _after_checkout(restored)
	if after:
		ok = ok and not restored.history.is_empty()
		ok = ok and restored.history[-1].shift == restored.shift_index + 1
	if restored.debug_jumped:
		return ok
	ok = ok and restored.history.size() == restored.shift_index + (1 if after else 0)
	for index: int in range(restored.history.size()):
		ok = ok and restored.history[index].shift == index + 1
	return ok


## The offers and the hand each save point has.
static func _phase_fits(restored: RunState) -> bool:
	var no_upgrade_offer: bool = restored.upgrade_offer.is_empty()
	var no_inspection: bool = restored.next_inspection == null
	match restored.phase:
		RunState.Phase.IMPULSE:
			return (
				restored.shift_index == 0
				and restored.history.is_empty()
				and not restored.impulse_offer.is_empty()
				and restored.offer == restored.impulse_offer
				and restored.impulse_pick == null
				and restored.deck.hand().is_empty()
				and restored.offers_made == 0
				and no_upgrade_offer
				and no_inspection
			)
		RunState.Phase.PLANNING:
			return restored.offer.is_empty() and no_upgrade_offer and no_inspection
		RunState.Phase.REWARD:
			var record: ShiftRecord = (
				restored.history[-1] if not restored.history.is_empty() else null
			)
			return (
				not restored.offer.is_empty()
				and not restored.is_last_shift()
				and restored.offers_made >= 1
				and record != null
				and record.card_picked == null
				and not record.reward_skipped
				and record.upgrade_taken == null
			)
	# UPGRADE
	return (
		restored.offer.is_empty()
		and not no_upgrade_offer
		and not restored.is_last_shift()
		and not restored.history.is_empty()
		and restored.history[-1].upgrade_taken == null
	)


static func _after_checkout(restored: RunState) -> bool:
	return restored.phase == RunState.Phase.REWARD or restored.phase == RunState.Phase.UPGRADE


static func _id(resource: Resource) -> String:
	return str(resource.get("id")) if resource != null else ""


static func _ids(resources: Array) -> Array:
	var ids: Array = []
	for resource: Resource in resources:
		ids.append(_id(resource))
	return ids


## [instance id, card id] pairs.
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
