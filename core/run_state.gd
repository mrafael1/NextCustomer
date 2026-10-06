class_name RunState
extends RefCounted
## One run: the deck, the current shift, the hand and the checkout row.
##
## The UI calls these methods and displays the results; it never applies rules itself. The
## run's seed is passed in (core never makes seeds), and every draw uses the RNG built from it.

## PLANNING: placing cards. REWARD: a passed shift's offer is waiting for a pick or a skip.
## SCORED: ready for the next shift. WON / LOST: the run is over.
enum Phase { PLANNING, REWARD, SCORED, WON, LOST }

var run_seed: int = 0
var balance: BalanceDefinition
var deck: Deck
## 0-based index of the current shift.
var shift_index: int = 0
var phase: Phase = Phase.PLANNING
var row: Array[CardInstance] = []
var redraw_used: bool = false
var last_result: ScoreResult
## The cards offered after the last passed shift (empty outside the REWARD phase).
var offer: Array[CardDefinition] = []
var offers_made: int = 0
var _rng: RandomNumberGenerator


func _init(seed_value: int, starter: DeckDefinition, run_balance: BalanceDefinition) -> void:
	run_seed = seed_value
	balance = run_balance
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	deck = Deck.from_definition(starter, _rng)


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
	redraw_used = false
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
	if phase != Phase.PLANNING or redraw_used:
		return false
	if cards.is_empty() or cards.size() > balance.redraw_limit:
		return false
	var in_hand: Array[CardInstance] = hand()
	for card: CardInstance in cards:
		if not in_hand.has(card) or cards.count(card) > 1:
			return false
	return true


## Replaces hand cards (not row cards) once per shift. Returns the cards received.
func redraw(cards: Array[CardInstance]) -> Array[CardInstance]:
	var received: Array[CardInstance] = []
	if not can_redraw(cards):
		return received
	var before: Array[CardInstance] = deck.hand()
	for card: CardInstance in deck.redraw(cards):
		if not before.has(card):
			received.append(card)
	redraw_used = true
	return received


func can_place(card: CardInstance) -> bool:
	return phase == Phase.PLANNING and hand().has(card) and row.size() < balance.slot_count


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


## The live preview: exactly what checkout would score now.
func preview() -> ScoreResult:
	return Scoring.score(row)


## Scores the row. Always allowed, even for an empty row (plan section 3.5).
func checkout() -> ScoreResult:
	if phase != Phase.PLANNING:
		return last_result
	last_result = Scoring.score(row)
	if last_result.total < quota():
		phase = Phase.LOST
	elif is_last_shift():
		phase = Phase.WON
	else:
		offer = RewardOffer.make(_rng, balance, offers_made == 0)
		offers_made += 1
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
	_finish_reward()
	return true


func skip_reward() -> bool:
	if phase != Phase.REWARD:
		return false
	_finish_reward()
	return true


func _finish_reward() -> void:
	offer = []
	phase = Phase.SCORED


func can_advance() -> bool:
	return phase == Phase.SCORED


func next_shift() -> bool:
	if not can_advance():
		return false
	shift_index += 1
	start_shift()
	return true


## Debug panel only: puts a copy of a card into this shift's hand.
func debug_add_to_hand(card_definition: CardDefinition) -> CardInstance:
	return deck.add_to_hand(card_definition)


## Debug panel only: jumps to a shift and starts it.
func debug_skip_to_shift(index: int) -> void:
	shift_index = clampi(index, 0, shift_count() - 1)
	offer = []
	start_shift()
