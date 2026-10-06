class_name RunState
extends RefCounted
## One run: the deck, the current shift, the hand, the checkout row, the owned upgrades, the
## shift's inspections and the run history.
##
## The UI calls these methods and displays the results; it never applies rules itself. The
## run's seed is passed in (core never makes seeds), and every draw and offer uses the RNG built
## from it.

## PLANNING: placing cards. REWARD: a passed shift's offer is waiting for a pick or a skip.
## UPGRADE: on an upgrade shift, after the reward, an upgrade offer is waiting for a pick (there
## is no skip, plan section 3.8). SCORED: ready for the next shift. WON / LOST: the run is over.
enum Phase { PLANNING, REWARD, UPGRADE, SCORED, WON, LOST }

## Redraws every shift allows before upgrades (one redraw of up to redraw_limit cards).
const BASE_REDRAWS := 1

var run_seed: int = 0
var balance: BalanceDefinition
## The starting deck the run began with.
var starter: DeckDefinition
var deck: Deck
## 0-based index of the current shift.
var shift_index: int = 0
var phase: Phase = Phase.PLANNING
var row: Array[CardInstance] = []
## Redraws made this shift, and how many it allows: BASE_REDRAWS plus each owned upgrade's
## extra_redraws, set when the shift starts.
var redraws_used: int = 0
var redraws_allowed: int = 0
var last_result: ScoreResult
## The cards offered after the last passed shift (empty outside the REWARD phase).
var offer: Array[CardDefinition] = []
var offers_made: int = 0
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
var _rng: RandomNumberGenerator


func _init(
	seed_value: int, deck_definition: DeckDefinition, run_balance: BalanceDefinition
) -> void:
	run_seed = seed_value
	balance = run_balance
	starter = deck_definition
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	deck = Deck.from_definition(deck_definition, _rng)
	# Full build plan 7.3: a deck's starting upgrade is owned from the first shift.
	if deck_definition.starting_upgrade != null:
		upgrades.append(deck_definition.starting_upgrade)


func shift_count() -> int:
	return balance.quotas.size()


func quota() -> int:
	return balance.quotas[shift_index]


func is_last_shift() -> bool:
	return shift_index == shift_count() - 1


## Starts the current shift: draws a fresh hand from the whole deck and empties the row.
func start_shift() -> void:
	deck.draw_hand(balance.hand_size)
	row = []
	redraws_used = 0
	redraws_allowed = BASE_REDRAWS
	for upgrade: UpgradeDefinition in upgrades:
		redraws_allowed += upgrade.extra_redraws
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
	return RowCapacity.fits(balance, row, card.definition)


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
		offer = RewardOffer.make(_rng, balance, offers_made == 0)
		offers_made += 1
		if UpgradeOffer.is_upgrade_shift(balance, shift_index + 1):
			upgrade_offer = UpgradeOffer.make(_rng, balance, upgrades)
		if InspectionSchedule.is_inspection_shift(balance, shift_index + 2):
			next_inspection = InspectionSchedule.draw(_rng, balance)
		phase = Phase.REWARD
	return last_result


func passed() -> bool:
	return last_result != null and last_result.total >= quota()


## True when taking a card needs another card out of the deck (plan section 2: 15-card limit).
func deck_is_full() -> bool:
	return deck.size() >= balance.deck_limit


## Adds an offered card to the deck. At the deck limit, `replaced` (a deck card) leaves it.
func take_reward(card: CardDefinition, replaced: CardInstance = null) -> bool:
	if phase != Phase.REWARD or not offer.has(card):
		return false
	if deck_is_full():
		if replaced == null or not deck.cards.has(replaced):
			return false
		deck.remove_card(replaced)
	deck.add_card(card)
	history[-1].card_picked = card
	_finish_reward()
	return true


func skip_reward() -> bool:
	if phase != Phase.REWARD:
		return false
	history[-1].reward_skipped = true
	_finish_reward()
	return true


## After the reward: the upgrade step if an upgrade offer is waiting, else ready for the next
## shift. An empty offer (every pool upgrade owned) skips the step.
func _finish_reward() -> void:
	offer = []
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
func debug_skip_to_shift(index: int) -> void:
	var target: int = clampi(index, 0, shift_count() - 1)
	if target != shift_index:
		inspections = []
		if InspectionSchedule.is_inspection_shift(balance, target + 1):
			var drawn: InspectionDefinition = InspectionSchedule.draw(_rng, balance)
			if drawn != null:
				inspections.append(drawn)
	shift_index = target
	offer = []
	upgrade_offer = []
	next_inspection = null
	start_shift()
