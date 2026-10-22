class_name RunState
extends RefCounted
## One run: the stock, the deck, the current shift, the hand, the checkout row, the owned
## upgrades, the shift's inspections, the RECEIPT REWARDS machine and the run history.
##
## The UI calls these methods and displays the results; it never applies rules itself. The
## run's seed is passed in (core never makes seeds), and every draw, machine prize and
## inspection uses the RNG built from it. The stock is built before the run (RunStock) and
## passed in, so a run never depends on a profile that changes after it starts.
##
## After a passed shift that isn't the last, the machine (#77, `machine`) takes the visits the
## shift earned: the UI chooses chutes and picks or bins prizes through `machine`, and the phase
## follows the machine's stage (MACHINE_CHOOSE, MACHINE_PICK, then SCORED when no visit is left).

## PLANNING: placing cards. MACHINE_CHOOSE: a machine visit waits for its chute.
## MACHINE_PICK: its prizes wait for a pick or a bin. SCORED: ready for the next shift. WON /
## LOST: the run is over.
enum Phase { PLANNING, MACHINE_CHOOSE, MACHINE_PICK, SCORED, WON, LOST }

const MACHINE_PHASES: Array[Phase] = [Phase.MACHINE_CHOOSE, Phase.MACHINE_PICK]

var run_seed: int = 0
var balance: BalanceDefinition
## The starting deck the run began with.
var starter: DeckDefinition
## The cards the machine's NEW ITEMS and COUPONS chutes draw from (full build plan 7.2).
var stock: RunStock
var deck: Deck
## 0-based index of the current shift.
var shift_index: int = 0
## The run's phase. While the machine's visits run it follows the machine's stage (CHOOSE,
## PICK, then SCORED once the last visit is done).
var phase: Phase:
	get:
		return _machine_phase() if _phase in MACHINE_PHASES else _phase
	set(value):
		_phase = value
var row: Array[CardInstance] = []
## The current shift's limits (slots, redraws, quota), fixed when the shift starts from the
## balance data, the upgrades owned then and the shift's inspections (ShiftLimits).
var limits: ShiftLimits
## Redraws made this shift, and how many it allows (limits.redraws: the balance's base_redraws
## plus each owned upgrade's extra_redraws), set when the shift starts.
var redraws_used: int = 0
var redraws_allowed: int = 0
var last_result: ScoreResult
## Owned upgrades, in pick order (a starting deck's upgrade first). Scoring steps name them by
## index in this list.
var upgrades: Array[UpgradeDefinition] = []
## The current shift's inspections (plan section 3.9; empty or one). Scoring steps name them by
## index in this list.
var inspections: Array[InspectionDefinition] = []
## The inspection announced for the next shift: drawn at a passed checkout when the next shift
## is inspected, kept through the machine's visits and moved to `inspections` by next_shift.
## Null otherwise.
var next_inspection: InspectionDefinition
## One entry per played shift, in order.
var history: Array[ShiftRecord] = []
## True once the debug panel jumped to another shift, or restarted the current one after its
## checkout: the history then no longer holds one entry per shift before the current one
## (RunSave skips that check for such a run).
var debug_jumped: bool = false
## The run RNG's state, for the run save (RunSave): setting it continues the RNG's sequence from
## that point, so a restored run draws exactly what the saved one would have.
var rng_state: int:
	get:
		return _rng.state
	set(value):
		_rng.state = value
## The RECEIPT REWARDS machine (#77): its visits, for this run. It shares the
## run's RNG.
var machine: RewardMachine
var _rng: RandomNumberGenerator
var _phase: Phase = Phase.PLANNING


func _init(
	seed_value: int,
	deck_definition: DeckDefinition,
	run_balance: BalanceDefinition,
	run_stock: RunStock
) -> void:
	run_seed = seed_value
	balance = run_balance
	starter = deck_definition
	stock = run_stock
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	deck = Deck.from_definition(deck_definition, _rng)
	machine = RewardMachine.new(balance.machine, _rng)
	# Full build plan 7.3: a deck's starting upgrade is owned from the first shift.
	if deck_definition.starting_upgrade != null:
		upgrades.append(deck_definition.starting_upgrade)
	limits = ShiftLimits.for_shift(balance, upgrades, shift_index)


func shift_count() -> int:
	return balance.quotas.size()


## The current shift's quota: the balance data's, raised by Big basket (ShiftLimits).
func quota() -> int:
	return limits.quota


func is_last_shift() -> bool:
	return shift_index == shift_count() - 1


## Starts the current shift: draws a fresh hand from the whole deck and empties the row. The
## shift's limits read the upgrades owned now, so a register picked from the machine applies from
## here.
func start_shift() -> void:
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


## The deck's hand by place, with null where the card is in the row. Places never change during
## a shift: a card taken out of the row is back in its own place, and a redrawn card's
## replacement takes its place (plan section 3.8).
func hand_places() -> Array[CardInstance]:
	var places: Array[CardInstance] = []
	for card: CardInstance in deck.hand():
		places.append(null if row.has(card) else card)
	return places


## The places of basket `basket` (basket_size places each, from place 0) that hold hand cards,
## ascending. Empty for a basket outside the hand.
func basket_places(basket: int) -> Array[int]:
	var places: Array[int] = []
	if basket < 0 or balance.basket_size <= 0:
		return places
	var by_place: Array[CardInstance] = hand_places()
	var first: int = basket * balance.basket_size
	for index: int in range(first, mini(first + balance.basket_size, by_place.size())):
		if by_place[index] != null:
			places.append(index)
	return places


## A redraw needs planning, a redraw left, a hand card in the basket and a card to draw.
func can_redraw_basket(basket: int) -> bool:
	if phase != Phase.PLANNING or redraws_used >= redraws_allowed:
		return false
	return not basket_places(basket).is_empty() and not deck.draw_pile().is_empty()


## Plan section 3.8: replaces one basket's hand cards (not row cards), left place first, with
## new cards in the same places, up to redraws_allowed times per shift. A short draw pile swaps
## the left ones and the redraw still costs 1. Cards replaced by any redraw are set aside for the
## rest of the shift. Returns the places swapped (empty when the redraw isn't allowed); the
## caller reads the old cards before and deck.hand() after.
func redraw_basket(basket: int) -> Array[int]:
	var swapped: Array[int] = []
	if not can_redraw_basket(basket):
		return swapped
	swapped = deck.redraw_places(basket_places(basket))
	redraws_used += 1
	return swapped


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


## Moves a row card back to the hand, into its own place (hand_places); the row cards after it
## shift left.
func remove(card: CardInstance) -> bool:
	if phase != Phase.PLANNING or not row.has(card):
		return false
	row.erase(card)
	return true


## The live preview: exactly what checkout would score now, with the run's upgrades and the
## shift's inspections. With `card` (#71's drag preview), what it would score with that hand card
## placed at `slot`: place() on a copy of the row, so the run is never changed; a card that can't
## be placed gives the plain preview. (One method rather than two keeps RunState within gdlint's
## 20 public methods.)
func preview(card: CardInstance = null, slot: int = 0) -> ScoreResult:
	if card == null or not can_place(card):
		return Scoring.score(row, upgrades, inspections)
	var placed: Array[CardInstance] = row.duplicate()
	placed.insert(clampi(slot, 0, placed.size()), card)
	return Scoring.score(placed, upgrades, inspections)


## Scores the row with the run's upgrades and the shift's inspections. Always allowed, even for
## an empty row (plan section 3.5). A pass that isn't the last shift draws the next shift's
## inspection from the run's RNG when it is inspected (section 3.9), then opens the machine's
## visits (#77); the prizes are drawn later, when a chute is chosen.
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
		if InspectionSchedule.is_inspection_shift(balance, shift_index + 2):
			next_inspection = InspectionSchedule.draw(_rng, balance, _last_inspection())
		# A balance without a machine (a test's minimal data) has no visits.
		phase = Phase.SCORED
		if balance.machine != null:
			machine.begin_after_checkout(self)
			phase = Phase.MACHINE_CHOOSE
	return last_result


func passed() -> bool:
	return last_result != null and last_result.total >= quota()


## True when a card from the machine needs another card out of the deck (plan section 2:
## 15-card limit).
func deck_is_full() -> bool:
	return deck.size() >= balance.deck_limit


## Starts the next shift. Only from SCORED: after the machine's last visit. The announced
## inspection, if any, applies to it.
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
## The machine's waiting visits are dropped. Not once the run is over.
func debug_skip_to_shift(index: int) -> void:
	if phase == Phase.WON or phase == Phase.LOST:
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
	machine.clear_visits()
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


## The phase the machine's stage stands for while its visits run.
func _machine_phase() -> Phase:
	match machine.stage:
		RewardMachine.Stage.CHOOSE:
			return Phase.MACHINE_CHOOSE
		RewardMachine.Stage.PICK:
			return Phase.MACHINE_PICK
	return Phase.SCORED
