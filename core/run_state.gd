class_name RunState
extends RefCounted
## One run: the stock, the impulse rack, the deck, the current shift, the hand, the checkout
## row, the owned upgrades, the shift's inspections and the run history.
##
## The UI calls these methods and displays the results; it never applies rules itself. The
## run's seed is passed in (core never makes seeds), and every draw and offer uses the RNG built
## from it, except the impulse rack's offer (below). The stock is built before the run
## (RunStock) and passed in, so a run never depends on a profile that changes after it starts.
##
## The impulse rack (full build plan 7.2) comes before shift 1. It opens when the run is created
## with the rack's derived stream (full build plan section 4), so the run's own RNG is untouched
## by it; it is picked or skipped like a reward, then the caller starts the shift.

## IMPULSE: before shift 1, the impulse rack's offer is waiting for a pick or a skip.
## PLANNING: placing cards. REWARD: a passed shift's offer is waiting for a pick or a skip.
## UPGRADE: on an upgrade shift, after the reward, an upgrade offer is waiting for a pick (there
## is no skip, plan section 3.8). SCORED: ready for the next shift. WON / LOST: the run is over.
enum Phase { IMPULSE, PLANNING, REWARD, UPGRADE, SCORED, WON, LOST }

## Redraws every shift allows before upgrades (one redraw of up to redraw_limit cards).
const BASE_REDRAWS := 1

var run_seed: int = 0
var balance: BalanceDefinition
## The starting deck the run began with.
var starter: DeckDefinition
## The cards reward offers draw from (full build plan 7.2).
var stock: RunStock
var deck: Deck
## 0-based index of the current shift.
var shift_index: int = 0
var phase: Phase = Phase.PLANNING
var row: Array[CardInstance] = []
## The current shift's limits (slots, redraws, quota), fixed when the shift starts from the
## balance data, the upgrades owned then and the shift's inspections (ShiftLimits).
var limits: ShiftLimits
## Redraws made this shift, and how many it allows (limits.redraws: BASE_REDRAWS plus each
## owned upgrade's extra_redraws), set when the shift starts.
var redraws_used: int = 0
var redraws_allowed: int = 0
var last_result: ScoreResult
## The cards offered after the last passed shift, or by the impulse rack (empty outside the
## REWARD and IMPULSE phases).
var offer: Array[CardDefinition] = []
## Reward offers made (the impulse rack doesn't count).
var offers_made: int = 0
## The impulse rack's offer, in offer order (empty when the run had no rack). Kept after the
## pick or skip, with the product picked and the deck card it replaced at the deck limit (null
## for none), for the run_start event and the run save.
var impulse_offer: Array[CardDefinition] = []
var impulse_pick: CardDefinition
var impulse_replaced: CardDefinition
## Owned upgrades, in pick order (a starting deck's upgrade first). Scoring steps name them by
## index in this list.
var upgrades: Array[UpgradeDefinition] = []
## The upgrades offered after the last passed upgrade shift. Built at checkout with the reward
## offer, kept through the REWARD and UPGRADE phases (non-empty during REWARD means an upgrade
## step follows) and cleared by pick_upgrade; empty otherwise.
var upgrade_offer: Array[UpgradeDefinition] = []
## The current shift's inspections (plan section 3.9; empty or one). Scoring steps name them by
## index in this list.
var inspections: Array[InspectionDefinition] = []
## The inspection announced for the next shift: drawn at a passed checkout when the next shift
## is inspected, kept through the REWARD and UPGRADE phases and moved to `inspections` by
## next_shift. Null otherwise.
var next_inspection: InspectionDefinition
## One entry per played shift, in order.
var history: Array[ShiftRecord] = []
## True once the debug panel jumped to another shift, or restarted the current one after its
## checkout: the history then no longer holds one entry per shift before the current one
## (RunSave skips that check for such a run).
var debug_jumped: bool = false
## The run RNG's state, for the run save (RunSave): setting it continues the RNG's sequence from
## that point, so a restored run draws and offers exactly what the saved one would have.
var rng_state: int:
	get:
		return _rng.state
	set(value):
		_rng.state = value
var _rng: RandomNumberGenerator


## `impulse_stream`, the impulse rack's derived stream, opens the rack (when impulse_rack_size
## is above 0); without it the run has no rack.
func _init(
	seed_value: int,
	deck_definition: DeckDefinition,
	run_balance: BalanceDefinition,
	run_stock: RunStock,
	impulse_stream: RandomNumberGenerator = null
) -> void:
	run_seed = seed_value
	balance = run_balance
	starter = deck_definition
	stock = run_stock
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	deck = Deck.from_definition(deck_definition, _rng)
	# Full build plan 7.3: a deck's starting upgrade is owned from the first shift.
	if deck_definition.starting_upgrade != null:
		upgrades.append(deck_definition.starting_upgrade)
	# Shift 1's limits already show while the impulse rack waits (its quota in the top bar).
	limits = ShiftLimits.for_shift(balance, upgrades, shift_index)
	if impulse_stream != null:
		impulse_offer = RewardOffer.make_impulse(impulse_stream, balance, stock)
	if not impulse_offer.is_empty():
		offer = impulse_offer.duplicate()
		phase = Phase.IMPULSE


func shift_count() -> int:
	return balance.quotas.size()


## The current shift's quota: the balance data's, raised by Big basket (ShiftLimits).
func quota() -> int:
	return limits.quota


func is_last_shift() -> bool:
	return shift_index == shift_count() - 1


## Starts the current shift: draws a fresh hand from the whole deck and empties the row. Not
## while the impulse rack waits for its pick or skip.
func start_shift() -> void:
	if phase == Phase.IMPULSE:
		return
	limits = ShiftLimits.for_shift(balance, upgrades, shift_index, inspections)
	deck.draw_hand(balance.hand_size)
	row = []
	redraws_used = 0
	redraws_allowed = limits.redraws
	last_result = null
	phase = Phase.PLANNING


## Cards drawn this shift that are not in the row, in draw order.
func hand() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for card: CardInstance in deck.hand():
		if not row.has(card):
			cards.append(card)
	return cards


func can_redraw(cards: Array[CardInstance]) -> bool:
	if phase != Phase.PLANNING or redraws_used >= redraws_allowed:
		return false
	if cards.is_empty() or cards.size() > balance.redraw_limit:
		return false
	var in_hand: Array[CardInstance] = hand()
	for card: CardInstance in cards:
		if not in_hand.has(card) or cards.count(card) > 1:
			return false
	return true


## Replaces hand cards (not row cards), up to redraws_allowed times per shift. Cards replaced by
## any redraw are set aside for the rest of the shift. Returns the cards received.
func redraw(cards: Array[CardInstance]) -> Array[CardInstance]:
	var received: Array[CardInstance] = []
	if not can_redraw(cards):
		return received
	var before: Array[CardInstance] = deck.hand()
	for card: CardInstance in deck.redraw(cards):
		if not before.has(card):
			received.append(card)
	redraws_used += 1
	return received


## Plan section 3.1: the row's product and card limits, checked by kind (RowCapacity).
func can_place(card: CardInstance) -> bool:
	if phase != Phase.PLANNING or not hand().has(card):
		return false
	return RowCapacity.fits(limits, row, card.definition)


## Puts a hand card into the row at `slot`. The row stays compacted: a slot past the end
## means the end, and a filled slot pushes the cards from there one place to the right.
func place(card: CardInstance, slot: int) -> bool:
	if not can_place(card):
		return false
	row.insert(clampi(slot, 0, row.size()), card)
	return true


## Moves a row card back to the hand; the cards after it shift left.
func remove(card: CardInstance) -> bool:
	if phase != Phase.PLANNING or not row.has(card):
		return false
	row.erase(card)
	return true


## The live preview: exactly what checkout would score now, with the run's upgrades and the
## shift's inspections.
func preview() -> ScoreResult:
	return Scoring.score(row, upgrades, inspections)


## Scores the row with the run's upgrades and the shift's inspections. Always allowed, even for
## an empty row (plan section 3.5). A pass builds the reward offer, the upgrade offer on an
## upgrade shift (plan section 3.8) and, when the next shift is inspected, draws its inspection
## (section 3.9), in that order, from the run's RNG.
func checkout() -> ScoreResult:
	if phase != Phase.PLANNING:
		return last_result
	last_result = Scoring.score(row, upgrades, inspections)
	var record: ShiftRecord = ShiftRecord.new(shift_index + 1, quota(), last_result.total)
	for card: CardInstance in row:
		record.played.append(card.definition)
	if not inspections.is_empty():
		record.inspection = inspections[0]
	history.append(record)
	if last_result.total < quota():
		phase = Phase.LOST
	elif is_last_shift():
		phase = Phase.WON
	else:
		offer = RewardOffer.make(_rng, balance, stock.cards, offers_made == 0)
		offers_made += 1
		if UpgradeOffer.is_upgrade_shift(balance, shift_index + 1):
			var deck_cards: Array[CardDefinition] = []
			for card: CardInstance in deck.cards:
				deck_cards.append(card.definition)
			upgrade_offer = UpgradeOffer.make(_rng, balance, upgrades, deck_cards)
		if InspectionSchedule.is_inspection_shift(balance, shift_index + 2):
			next_inspection = InspectionSchedule.draw(_rng, balance, _last_inspection())
		phase = Phase.REWARD
	return last_result


func passed() -> bool:
	return last_result != null and last_result.total >= quota()


## True when taking a card needs another card out of the deck (plan section 2: 15-card limit).
func deck_is_full() -> bool:
	return deck.size() >= balance.deck_limit


## Adds an offered card to the deck: a reward, or the impulse rack's product before shift 1.
## At the deck limit, `replaced` (a deck card) leaves it.
func take_reward(card: CardDefinition, replaced: CardInstance = null) -> bool:
	if not _offer_waiting() or not offer.has(card):
		return false
	var removed: CardDefinition = null
	if deck_is_full():
		if replaced == null or not deck.cards.has(replaced):
			return false
		deck.remove_card(replaced)
		removed = replaced.definition
	deck.add_card(card)
	if phase == Phase.IMPULSE:
		impulse_pick = card
		impulse_replaced = removed
	else:
		history[-1].card_picked = card
	_finish_reward()
	return true


## Skips the reward, or the impulse rack.
func skip_reward() -> bool:
	if not _offer_waiting():
		return false
	if phase == Phase.REWARD:
		history[-1].reward_skipped = true
	_finish_reward()
	return true


func _offer_waiting() -> bool:
	return phase == Phase.REWARD or phase == Phase.IMPULSE


## After the impulse rack: ready for shift 1 to start. After a reward: the upgrade step if an
## upgrade offer is waiting, else ready for the next shift. An empty upgrade offer (every pool
## upgrade owned) skips the step.
func _finish_reward() -> void:
	offer = []
	if phase == Phase.IMPULSE:
		phase = Phase.PLANNING
	else:
		phase = Phase.SCORED if upgrade_offer.is_empty() else Phase.UPGRADE


## Takes one of the offered upgrades (plan section 3.8). The player must pick: there is no skip.
## It applies from the next shift on.
func pick_upgrade(upgrade: UpgradeDefinition) -> bool:
	if phase != Phase.UPGRADE or not upgrade_offer.has(upgrade):
		return false
	upgrades.append(upgrade)
	history[-1].upgrade_taken = upgrade
	upgrade_offer = []
	phase = Phase.SCORED
	return true


## Starts the next shift. Only from SCORED: after the reward, and the upgrade on upgrade shifts.
## The announced inspection, if any, applies to it.
func next_shift() -> bool:
	if phase != Phase.SCORED:
		return false
	shift_index += 1
	inspections = []
	if next_inspection != null:
		inspections.append(next_inspection)
	next_inspection = null
	start_shift()
	return true


## Debug panel only: puts a copy of a card into this shift's hand.
func debug_add_to_hand(card_definition: CardDefinition) -> CardInstance:
	return deck.add_to_hand(card_definition)


## Debug panel only: jumps to a shift and starts it. Jumping to another shift draws that
## shift's inspection if it is inspected; restarting the current shift keeps its inspections.
## Not while the impulse rack is open.
func debug_skip_to_shift(index: int) -> void:
	if phase == Phase.IMPULSE:
		return
	var target: int = clampi(index, 0, shift_count() - 1)
	if target != shift_index or history.size() != target:
		debug_jumped = true
	if target != shift_index:
		var previous: InspectionDefinition = _last_inspection()
		inspections = []
		if InspectionSchedule.is_inspection_shift(balance, target + 1):
			var drawn: InspectionDefinition = InspectionSchedule.draw(_rng, balance, previous)
			if drawn != null:
				inspections.append(drawn)
	shift_index = target
	offer = []
	upgrade_offer = []
	next_inspection = null
	start_shift()


## The run's last inspection: the current shift's, else the last inspected shift's (no
## inspection twice in a row, InspectionSchedule.draw).
func _last_inspection() -> InspectionDefinition:
	if not inspections.is_empty():
		return inspections[0]
	for index: int in range(history.size() - 1, -1, -1):
		if history[index].inspection != null:
			return history[index].inspection
	return null
