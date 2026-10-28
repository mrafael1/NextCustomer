class_name RunSave
extends RefCounted
## The run save (full build plan section 4): a snapshot of a run at a stable point, so a
## resumed run continues exactly as if it had never stopped, with the same later draws,
## redraws, machine prizes and inspections. Pure: SaveService reads and writes the file.
##
## The save points are the phases where the game waits for the player: PLANNING (at the shift's
## start and after every place, remove and redraw), MACHINE_CHOOSE (a machine visit waits for its
## chute: saved at the checkout click and between visits), MACHINE_PICK (the prizes are drawn and
## wait for a pick or a bin) and SCORED (after the shift's last visit, so quitting during the last
## landing resumes into the next shift). WON / LOST end the run, so they are never saved. The
## saved form holds what rebuilds the run (the seed, the stock's listed aisles, card ids,
## list_skipped and new arrivals) and the whole state: the deck's cards with their instance ids,
## the hand, the draw pile, the row, the redraws, the upgrades, the inspections, the history, the
## machine (RewardMachine.to_dictionary) and the RNG's state, plus the telemetry's run id and
## played time. Ids resolve through a ContentLookup, and the stock is restored from its ids, so a
## resume never depends on a profile that changed after the run started.
##
## Content retired by a rule change (ContentLookup.RETIRED_UPGRADES and RETIRED_INSPECTIONS,
## plan v0.46) still reads, as inert stand-ins: a retired register is dropped from the run's
## registers (the history keeps its pick), a retired inspection stays on its shift with no effect
## (so the shift keeps its bonus ticket). With a register dropped, a planning row longer than the
## shift's slots (Extra coupon slot's last card) gives its last cards back to the hand, and a row
## already checked out with that slot is checked by its total only. A retired register's pick
## doesn't count toward the register cap (RewardMachine.registers_picked), and a visit waiting for
## its pick no longer offers one (MachineVisit.drop_retired_prizes).
##
## A save from before v0.61's machine restructure (#108: formats 4 and 5) is converted first
## (RunSaveMigration.to_v6) and then read like any other.
##
## The seed and the RNG state are decimal strings: JSON numbers are doubles and lose precision
## above 2^53. The draw pile is saved only during PLANNING (the next shift reshuffles the whole
## deck, so it means nothing after the checkout).

## The run save's format version. Raise it when the saved form changes. This version is read, and
## versions 4 and 5 through RunSaveMigration: an older save (version 1, from before the machine;
## version 2, with the machine's Regular levels, before v0.47's two machine states; version 3,
## before v0.49's dealt starting deck) is refused, so SaveService keeps it as a .bad backup and a
## new run starts. Version 6 (v0.61, #108): one machine with two chutes, CLASSIC or PREMIUM, no
## STAMP DAY, loyalty levels, and the machine's played upgrades as a list. Version 7 (v0.63,
## #107): the starter pack offer (`start_offer`), the pack taken (`start_pack`) and the
## choose_start save point; a version 6 save has none of them and reads as before. Version 8
## (v0.65, the loop rework): the next shift's inspections as a list (`next_inspections`, a
## Manager's review has several), each record's `inspections`, and records of missed shifts (the
## write-ups); a version 7 or 6 save names one next inspection and one per record and reads
## into the 12-shift run as it is.
const FORMAT_VERSION := 8
## Version 7: version 8's form with one next inspection and one per record, read as it is.
const BEFORE_LOOP_VERSION := 7
## Version 6: version 7's form without the starter pack fields, read as it is.
const BEFORE_STARTER_PACKS_VERSION := 6
## Version 5: the machine before v0.61 (four chutes, STAMP DAY), converted by RunSaveMigration.
const BEFORE_MACHINE_REWORK_VERSION := 5
## Version 4 has version 5's saved form, scored before v0.46's Banana chain (#106), and is still
## read: after its checkout the row scores again by today's rules, so a row with a Banana after a
## Banana can total otherwise than its record. The record's total stands (it decided the shift
## and the machine's visits) and last_result is today's score of the row. Saved again, it is
## the current version.
const BEFORE_BANANA_CHAIN_VERSION := 4
## The save points, and their names in the saved form (the run_resume event uses them too).
## CHOOSE_START (#107): the starter pack offer waits for the pick, saved before the choice opens,
## so quitting can't reroll it.
const SAVE_POINTS: Array[RunState.Phase] = [
	RunState.Phase.PLANNING,
	RunState.Phase.MACHINE_CHOOSE,
	RunState.Phase.MACHINE_PICK,
	RunState.Phase.SCORED,
	RunState.Phase.CHOOSE_START,
]
const PHASE_NAMES: Array[String] = ["planning", "machine", "machine_pick", "scored", "choose_start"]

var run: RunState
## The telemetry run id the run was logged under.
var run_id: String = ""
## Played time so far, in milliseconds.
var run_ms: int = 0


static func is_save_point(phase: RunState.Phase) -> bool:
	return SAVE_POINTS.has(phase)


## A save point's name in the saved form ("planning", "machine", "machine_pick", "scored"), or
## "" for another phase.
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
		# The cards the run started with (v0.49): a recipe deck's dealt cards, restored with it.
		"starting_deck": _ids(saved_run.starter.cards),
		"phase": phase_name(saved_run.phase),
		"shift_index": saved_run.shift_index,
		"debug_jumped": saved_run.debug_jumped,
		"list_skipped": saved_run.stock.list_skipped,
		"new_arrivals": _ids(saved_run.stock.new_arrivals),
		"deck": _pairs(saved_run.deck.cards),
		"next_instance_id": saved_run.deck.next_instance_id(),
		"hand": _pairs(saved_run.deck.hand()),
		"draw_pile": _instance_ids(saved_run.deck.draw_pile()) if planning else [],
		"row": _instance_ids(saved_run.row),
		"redraws_used": saved_run.redraws_used,
		"redraws_allowed": saved_run.redraws_allowed,
		"redrawn_in": Array(saved_run.redrawn_in),
		"upgrades": _ids(saved_run.upgrades),
		"inspections": _ids(saved_run.inspections),
		"next_inspections": _ids(saved_run.next_inspections),
		"history":
		saved_run.history.map(
			func(record: ShiftRecord) -> Dictionary: return record.to_dictionary()
		),
		"machine": saved_run.machine.to_dictionary(),
		"start_offer": _offer_data(saved_run.start_offer),
		"start_pack": _id(saved_run.starter.starter_pack),
	}
	# "listed_aisles" and "stock", the same as run_start logs.
	data.merge(saved_run.stock.to_dictionary())
	return data


## Reads the saved form (as parsed from JSON: numbers may be floats). Returns null when it
## isn't a run this version can resume: a missing or other format version, a field missing or
## of the wrong type, an id that no longer resolves, or a state the game can't reach (see
## _is_consistent). Never prints anything.
static func from_dictionary(saved: Dictionary, lookup: ContentLookup) -> RunSave:
	var version: Variant = saved.get("format_version")
	if not SaveReader.is_whole(version):
		return null
	var data: Dictionary = saved
	if RunSaveMigration.FROM_VERSIONS.has(int(version)):
		data = RunSaveMigration.to_v6(saved)
	elif not [FORMAT_VERSION, BEFORE_LOOP_VERSION, BEFORE_STARTER_PACKS_VERSION].has(int(version)):
		return null
	if data.is_empty():
		return null
	var rescored: bool = int(version) == BEFORE_BANANA_CHAIN_VERSION
	var reader: SaveReader = SaveReader.new(data, lookup)
	var starter: DeckDefinition = reader.deck("starter")
	var starting_cards: Array[CardDefinition] = reader.cards("starting_deck")
	# A recipe with starter packs (#107): its offer and the pack taken ("" before the pick).
	var offer: StartOffer = null
	var pack: StarterPackDefinition = null
	if starter != null and not starter.starter_packs.is_empty():
		offer = _read_offer(starter, data.get("start_offer"))
		var pack_id: Variant = data.get("start_pack")
		if offer == null or not pack_id is String:
			return null
		if not (pack_id as String).is_empty():
			pack = offer.pack(StringName(pack_id))
			if pack == null:
				return null
	if starter != null and starter.is_recipe():
		# A deal the recipe can't give (a damaged or edited save) is refused.
		if not StartingDeck.could_deal(starter, starting_cards, pack):
			return null
		starter = StartingDeck.with_cards(starter, starting_cards)
		starter.starter_pack = pack
		if offer != null:
			offer.shared = StartingDeck.shared_of(starter)
	var stock: RunStock = RunStock.from_saved(
		reader.cards("stock"),
		reader.aisles("listed_aisles"),
		reader.flag("list_skipped"),
		reader.cards("new_arrivals")
	)
	var phase_index: int = PHASE_NAMES.find(reader.text("phase"))
	if not reader.ok or phase_index == -1:
		return null
	var restored: RunState = RunState.new(reader.int64("seed"), starter, lookup.balance, stock)
	restored.start_offer = offer
	restored.rng_state = reader.int64("rng_state")
	restored.phase = SAVE_POINTS[phase_index]
	restored.shift_index = reader.whole("shift_index")
	restored.debug_jumped = reader.flag("debug_jumped")
	restored.redraws_used = reader.whole("redraws_used")
	restored.redraws_allowed = reader.whole("redraws_allowed")
	# Left out by format 6 saves made before #108 piece 2: no card came from an extra redraw.
	if data.has("redrawn_in"):
		restored.redrawn_in = PackedInt32Array(reader.wholes("redrawn_in", 1))
	restored.upgrades = reader.upgrades("upgrades")
	restored.inspections = reader.inspections("inspections")
	if data.has("next_inspections"):
		restored.next_inspections = reader.inspections("next_inspections")
	else:
		restored.next_inspection = reader.inspection("next_inspection")
	var machine_data: Variant = data.get("machine")
	var machine_ok: bool = (
		machine_data is Dictionary
		and restored.machine.restore_from(machine_data as Dictionary, lookup)
	)
	var retired: bool = _drop_retired_registers(restored)
	# The limits the shift started with (its quota and slots): after the checkout, a register
	# picked from the machine applies only from the next shift.
	if restored.shift_index < restored.shift_count():
		restored.limits = ShiftLimits.for_shift(
			restored.balance, _played_upgrades(restored), restored.shift_index, restored.inspections
		)
	var history_ok: bool = _restore_history(restored, reader.dictionaries("history"), lookup)
	var cards_ok: bool = _restore_cards(restored, reader)
	if retired and restored.phase == RunState.Phase.PLANNING:
		_fit_row(restored)
	var save: RunSave = RunSave.new()
	save.run = restored
	save.run_id = reader.text("run_id")
	save.run_ms = reader.whole("run_ms")
	var ok: bool = reader.ok and machine_ok and history_ok and cards_ok
	if (
		not ok
		or restored.phase != SAVE_POINTS[phase_index]
		or not _is_consistent(restored, retired, rescored)
	):
		return null
	return save


## Drops the retired registers (inert stand-ins) from the run's registers, and from those owned at
## the last checkout. True when there was one.
static func _drop_retired_registers(restored: RunState) -> bool:
	var kept: Array[UpgradeDefinition] = _live(restored.upgrades)
	var dropped: bool = kept.size() < restored.upgrades.size()
	restored.upgrades = kept
	restored.machine.played_upgrades = _live(restored.machine.played_upgrades)
	return dropped


## The upgrades that aren't retired stand-ins, in order.
static func _live(upgrades: Array[UpgradeDefinition]) -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for upgrade: UpgradeDefinition in upgrades:
		if not ContentLookup.is_retired(upgrade):
			found.append(upgrade)
	return found


## A planning row longer than the shift's slots (saved with a retired register's slot) gives its
## last cards back to the hand: they stay hand cards, only out of the row.
static func _fit_row(restored: RunState) -> void:
	if restored.shift_index >= restored.shift_count():
		return
	if restored.row.size() > RowCapacity.card_limit(restored.limits):
		restored.row.resize(RowCapacity.card_limit(restored.limits))


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
## isn't above every id. A hand card whose deck copy was upgraded by the machine (a higher tier
## of the same product) keeps its saved card, as it was checked out.
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
		elif deck_card.definition == card.definition:
			hand.append(deck_card)
		else:
			ok = ok and _upgraded_from(deck_card.definition, card.definition)
			hand.append(card)
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


## The saved form of a starter pack offer (#107): the offered pack ids, the first pick's id ("" for
## none), the swaps and the deals; {} without an offer. The shared products are the starting
## deck's.
static func _offer_data(offer: StartOffer) -> Dictionary:
	if offer == null:
		return {}
	return {
		"packs": _ids(offer.packs),
		"first_pick": _id(offer.first_pick),
		"swaps": offer.swaps,
		"deals": offer.deals,
	}


## The offer `data` holds for `recipe` (as parsed from JSON), or null when it is missing or names
## a pack the recipe doesn't have. Its shared products are set from the starting deck.
static func _read_offer(recipe: DeckDefinition, data: Variant) -> StartOffer:
	if not data is Dictionary:
		return null
	var saved: Dictionary = data
	var ids: Variant = saved.get("packs")
	var first: Variant = saved.get("first_pick")
	var swaps: Variant = saved.get("swaps")
	var deals: Variant = saved.get("deals")
	if not ids is Array or not first is String:
		return null
	if not SaveReader.is_whole(swaps) or not SaveReader.is_whole(deals):
		return null
	var offer: StartOffer = StartOffer.new()
	for id: Variant in ids:
		var found: StarterPackDefinition = _recipe_pack(recipe, id)
		if found == null or offer.packs.has(found):
			return null
		offer.packs.append(found)
	if offer.packs.is_empty():
		return null
	if not (first as String).is_empty():
		offer.first_pick = offer.pack(StringName(first))
		if offer.first_pick == null:
			return null
	offer.swaps = int(swaps)
	offer.deals = int(deals)
	return offer


static func _recipe_pack(recipe: DeckDefinition, id: Variant) -> StarterPackDefinition:
	if not id is String:
		return null
	for pack: StarterPackDefinition in recipe.starter_packs:
		if pack.id == StringName(id):
			return pack
	return null


## Adds each card by instance id; false when an id repeats.
static func _index(cards: Array[CardInstance], into: Dictionary[int, CardInstance]) -> bool:
	var ok: bool = true
	for card: CardInstance in cards:
		ok = ok and not into.has(card.instance_id)
		into[card.instance_id] = card
	return ok


## Whether the restored run is a state the game reaches at its save point. Restores
## last_result after the checkout: the row is kept until the next shift starts, so scoring it
## again with the upgrades owned at the checkout gives the checkout's result, which must be the
## last record's total. `retired`: a retired register was dropped, so a row checked out with its
## slot is checked by its total only. `rescored`: a save from before the Banana chain
## (BEFORE_BANANA_CHAIN_VERSION), whose row may now total otherwise, so the total isn't checked.
static func _is_consistent(restored: RunState, retired: bool, rescored: bool) -> bool:
	if restored.shift_index >= restored.shift_count():
		return false
	var ok: bool = _history_fits(restored) and _phase_fits(restored)
	# The row's limit, as place() keeps it: a save made before the balance's slots were lowered
	# can't be resumed.
	if not retired or restored.phase == RunState.Phase.PLANNING:
		ok = ok and RowCapacity.row_fits(restored.limits, restored.row)
	ok = ok and restored.redraws_used <= restored.redraws_allowed
	for card: CardDefinition in restored.stock.new_arrivals:
		ok = ok and restored.stock.cards.has(card)
	# One box per perk: never a perk twice, nor two levels of one perk.
	for upgrade: UpgradeDefinition in restored.upgrades:
		ok = ok and restored.upgrades.count(upgrade) == 1
		ok = (
			ok
			and (
				PerkLevels.owned_index(restored.upgrades, upgrade)
				== restored.upgrades.find(upgrade)
			)
		)
	if not ok or not _after_checkout(restored):
		return ok
	var played: Array[UpgradeDefinition] = _played_upgrades(restored)
	restored.last_result = Scoring.score(
		restored.row, played, restored.inspections, ScoreCredits.for_run(restored)
	)
	if rescored:
		return true
	# A missed shift saved after its checkout is a write-up the run went on after (v0.65).
	var survived: bool = restored.passed() or restored.write_ups < restored.balance.write_up_limit
	return restored.last_result.total == restored.history[-1].total and survived


## Every played shift was passed, but for fewer write-ups (missed shifts, v0.65) than the
## balance's write_up_limit (the one that reaches it ends the run). One record per shift before
## the current one, plus the current one after its checkout; a debug jump keeps only the last
## record's shift number to check.
static func _history_fits(restored: RunState) -> bool:
	var ok: bool = restored.write_ups < maxi(restored.balance.write_up_limit, 1)
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


## The machine's state each save point has (RewardMachine.restore_from checked its own fields).
static func _phase_fits(restored: RunState) -> bool:
	var machine: RewardMachine = restored.machine
	var visit: MachineVisit = machine.current_visit()
	var offer: StartOffer = restored.start_offer
	var pack: StarterPackDefinition = restored.starter.starter_pack
	if restored.phase == RunState.Phase.CHOOSE_START:
		# Before the first shift: an offer waiting for its pick, nothing played or owned yet.
		return (
			offer != null
			and pack == null
			and restored.shift_index == 0
			and restored.history.is_empty()
			and restored.row.is_empty()
			and restored.deck.hand().is_empty()
			and machine.stage == RewardMachine.Stage.IDLE
		)
	# A run with an offer has taken one of its packs.
	if offer != null and (pack == null or not offer.packs.has(pack)):
		return false
	if restored.phase == RunState.Phase.PLANNING:
		return machine.stage == RewardMachine.Stage.IDLE and restored.next_inspection == null
	var record: ShiftRecord = restored.history[-1]
	# The perks picked after the checkout are the last record's: the played ones with those picks
	# (a level-up in its box) are the run's.
	var expected: Array[UpgradeDefinition] = machine.played_upgrades.duplicate()
	for upgrade: UpgradeDefinition in _live(record.registers_taken()):
		expected = PerkLevels.with_pick(expected, upgrade)
	var ok: bool = (
		not restored.is_last_shift()
		and expected == restored.upgrades
		and RewardMachine.registers_picked(restored) <= machine.machine.register_cap
	)
	if restored.phase == RunState.Phase.SCORED:
		return ok and visit == null and machine.pending_kinds().is_empty()
	if visit.kind == MachineVisit.Kind.BONUS:
		var extra: bool = machine.machine.bonus_extra_shifts.has(record.shift)
		var inspected: bool = machine.machine.bonus_after_inspection and record.inspection != null
		ok = ok and (inspected or extra) and not record.visits.is_empty()
	elif visit.kind == MachineVisit.Kind.TICKET:
		ok = ok and record.visits.is_empty()
	# A PREMIUM visit is a premium shift's ticket or BONUS visit.
	return ok and (not visit.premium or machine.machine.is_premium_shift(record.shift))


static func _after_checkout(restored: RunState) -> bool:
	return (
		restored.phase != RunState.Phase.PLANNING and restored.phase != RunState.Phase.CHOOSE_START
	)


## The upgrades the current shift was played with: after the checkout, those owned at the
## checkout (a perk picked from the machine, or a level-up, applies from the next shift).
static func _played_upgrades(restored: RunState) -> Array[UpgradeDefinition]:
	if not _after_checkout(restored):
		return restored.upgrades
	return restored.machine.played_upgrades


## The machine upgraded a copy of `before` into `after`: a higher tier of the same product.
static func _upgraded_from(after: CardDefinition, before: CardDefinition) -> bool:
	return after.is_same_product(before) and after.tier > before.tier


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
