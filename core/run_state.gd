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

## A run whose recipe has starter packs (#107, v0.63) starts in CHOOSE_START: its offer
## (`start_offer`) waits for the player's pick (take_pack), which makes the deck; the first shift
## starts after it.

## PLANNING: placing cards. MACHINE_CHOOSE: a machine visit waits for its chute.
## MACHINE_PICK: its prizes wait for a pick or a bin. SCORED: ready for the next shift. WON /
## LOST: the run is over. CHOOSE_START (#107): the starter pack offer waits for the pick, before
## the first shift (added last: the phases' numbers are kept).
enum Phase { PLANNING, MACHINE_CHOOSE, MACHINE_PICK, SCORED, WON, LOST, CHOOSE_START }

const MACHINE_PHASES: Array[Phase] = [Phase.MACHINE_CHOOSE, Phase.MACHINE_PICK]

var run_seed: int = 0
var balance: BalanceDefinition
## The starting deck the run began with (before the pick, #107: the core cards and the offer's
## shared products, no pack).
var starter: DeckDefinition
## The starter pack offer (#107), or null for a recipe without packs; kept after the pick.
var start_offer: StartOffer
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
## The instance ids of the cards this shift's extra redraws brought into the hand (#108 piece 2:
## the redraws past the balance's base_redraws are Extra redraw's), for the receipt's credit
## (ScoreCredits).
var redrawn_in: PackedInt32Array = PackedInt32Array()
var last_result: ScoreResult
## Owned upgrades, in pick order (a starting deck's upgrade first). Scoring steps name them by
## index in this list.
var upgrades: Array[UpgradeDefinition] = []
## The current shift's inspections (plan section 3.9; empty, one, or a Manager's review's
## several since v0.65). Scoring steps name them by index in this list.
var inspections: Array[InspectionDefinition] = []
## The inspections announced for the next shift: drawn at a checkout the run survives when the
## next shift is inspected (InspectionSchedule.draw_for), kept through the machine's visits and
## moved to `inspections` by next_shift. Empty otherwise.
var next_inspections: Array[InspectionDefinition] = []
## The first announced inspection, or null (most callers name one): setting it announces that
## one alone, null none.
var next_inspection: InspectionDefinition:
	get:
		return next_inspections[0] if not next_inspections.is_empty() else null
	set(value):
		next_inspections = []
		if value != null:
			next_inspections.append(value)
## One entry per played shift, in order.
var history: Array[ShiftRecord] = []
## The run's write-ups (v0.65): its missed shifts. A run still going has fewer than the
## balance's write_up_limit; a lost run's last miss is the one that got the cashier fired.
var write_ups: int:
	get:
		var count: int = 0
		for record: ShiftRecord in history:
			count += 0 if record.passed else 1
		return count
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


## With `offer` (#107) the run waits for its pick (CHOOSE_START): `deck_definition` is then the
## deck before the pick (StartingDeck.before_pick).
func _init(
	seed_value: int,
	deck_definition: DeckDefinition,
	run_balance: BalanceDefinition,
	run_stock: RunStock,
	offer: StartOffer = null
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
	if offer != null:
		start_offer = offer
		_phase = Phase.CHOOSE_START


func shift_count() -> int:
	return balance.quotas.size()


## The current shift's quota: the balance data's (ShiftLimits).
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
	redrawn_in = PackedInt32Array()
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
	if redraws_used >= balance.base_redraws:
		var by_place: Array[CardInstance] = deck.hand()
		for spot: int in swapped:
			redrawn_in.append(by_place[spot].instance_id)
	redraws_used += 1
	return swapped


## Takes an offered starter pack (#107; CHOOSE_START only): the deck becomes the core cards, the
## pack's cards and the shared products (StartingDeck.with_pack), and the run waits in PLANNING
## for start_shift. False, changing nothing, for a pack not offered or outside CHOOSE_START.
func take_pack(pack: StarterPackDefinition) -> bool:
	if phase != Phase.CHOOSE_START or start_offer == null or not start_offer.packs.has(pack):
		return false
	starter = StartingDeck.with_pack(starter, pack, start_offer.shared)
	deck = Deck.from_definition(starter, _rng)
	phase = Phase.PLANNING
	return true


## Plan section 3.1: the row's slots (RowCapacity); any card fits any free slot.
func can_place(card: CardInstance) -> bool:
	if phase != Phase.PLANNING or not hand().has(card):
		return false
	return RowCapacity.fits(limits, row)


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
		return Scoring.score(row, upgrades, inspections, ScoreCredits.for_run(self))
	var placed: Array[CardInstance] = row.duplicate()
	placed.insert(clampi(slot, 0, placed.size()), card)
	return Scoring.score(placed, upgrades, inspections, ScoreCredits.for_run(self))


## Scores the row with the run's upgrades and the shift's inspections. Always allowed, even for
## an empty row (plan section 3.5). A pass that isn't the last shift draws the next shift's
## inspections from the run's RNG when it is inspected (section 3.9), then opens the machine's
## visits (#77); the prizes are drawn later, when a chute is chosen. A miss (v0.65) is a
## write-up while the run's write-ups stay under the balance's write_up_limit and it isn't the
## last shift: the next shift's inspections are drawn the same way, and the shift gets no
## machine visit (SCORED at once). Any other miss loses the run.
func checkout() -> ScoreResult:
	if phase != Phase.PLANNING:
		return last_result
	last_result = Scoring.score(row, upgrades, inspections, ScoreCredits.for_run(self))
	var record: ShiftRecord = ShiftRecord.new(shift_index + 1, quota(), last_result.total)
	for card: CardInstance in row:
		record.played.append(card.definition)
	record.inspections = inspections.duplicate()
	history.append(record)
	if not record.passed and (is_last_shift() or write_ups >= balance.write_up_limit):
		phase = Phase.LOST
	elif record.passed and is_last_shift():
		phase = Phase.WON
	else:
		next_inspections = InspectionSchedule.draw_for(
			_rng, balance, shift_index + 2, _last_inspections()
		)
		# A balance without a machine (a test's minimal data) has no visits, nor has a write-up.
		phase = Phase.SCORED
		if balance.machine != null:
			machine.begin_after_checkout(self)
			phase = _machine_phase()
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
	inspections = next_inspections.duplicate()
	next_inspections = []
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
		inspections = InspectionSchedule.draw_for(_rng, balance, target + 1, _last_inspections())
	shift_index = target
	machine.clear_visits()
	next_inspections = []
	start_shift()


## The run's last inspections: the current shift's, else the last inspected shift's (no
## inspection twice in a row, InspectionSchedule.draw_for).
func _last_inspections() -> Array[InspectionDefinition]:
	if not inspections.is_empty():
		return inspections.duplicate()
	for index: int in range(history.size() - 1, -1, -1):
		if not history[index].inspections.is_empty():
			return history[index].inspections.duplicate()
	return []


## The phase the machine's stage stands for while its visits run.
func _machine_phase() -> Phase:
	match machine.stage:
		RewardMachine.Stage.CHOOSE:
			return Phase.MACHINE_CHOOSE
		RewardMachine.Stage.PICK:
			return Phase.MACHINE_PICK
	return Phase.SCORED
