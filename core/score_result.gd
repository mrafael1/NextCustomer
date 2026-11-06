class_name ScoreResult
extends RefCounted
## The outcome of Scoring.score(): the total, each slot's payout, the tags after the context
## pass, and every step that explains them.

var total: int = 0
var payouts: PackedInt32Array = PackedInt32Array()
var tags: Array[PackedStringArray] = []
var steps: Array[ScoreStep] = []

## The batches the rules read (CardBatch, #128 Bakery batches), each in slot order: what the
## planning belt's batch brackets show. Empty for a total-only score.
var batches: Array[PackedInt32Array] = []
## The chains (CardChain, #128 Produce links), each in slot order with any Lemon knot inside it:
## what the planning belt's chain frames show. Empty for a total-only score.
var chains: Array[PackedInt32Array] = []
## The chains' parts the belt marks (#128 Produce links): every chain's knots' factors by knot
## slot (slot: its ChainKnots factor), and by chain index the FEED and TALLY helpers at their
## places by it (ChainRoleRule; -1: none). Empty for a total-only score.
var knot_factors: Dictionary[int, int] = {}
var chain_feeds: PackedInt32Array = PackedInt32Array()
var chain_tallies: PackedInt32Array = PackedInt32Array()
## The MORNING's slots when a card in the row reads it (CardMorning.read), and every PAIR as
## (left slot, right slot) (CardPairs.links): what the planning belt's suns and clasps mark (#128,
## v1.06). Empty for a total-only score.
var mornings: PackedInt32Array = PackedInt32Array()
var pairs: Array[Vector2i] = []


## A Double checkout shift's whole result (#122): `first` (row 1, its slots from 0) then
## `second` (row 2) with its slots moved past row 1's `first_slots` cards and its subtotals past
## row 1's total, so the steps read as one row of both. The total is both rows'.
static func joined(first: ScoreResult, second: ScoreResult, first_slots: int) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = first.total + second.total
	result.payouts = first.payouts + second.payouts
	result.tags = first.tags + second.tags
	result.steps = first.steps.duplicate()
	for step: ScoreStep in second.steps:
		result.steps.append(step.moved(first_slots, first.total))
	result.batches = first.batches + _moved_runs(second.batches, first_slots)
	result.chains = first.chains + _moved_runs(second.chains, first_slots)
	result.knot_factors = first.knot_factors.duplicate()
	for slot: int in second.knot_factors:
		result.knot_factors[slot + first_slots] = second.knot_factors[slot]
	result.chain_feeds = first.chain_feeds + _moved_slots(second.chain_feeds, first_slots)
	result.chain_tallies = first.chain_tallies + _moved_slots(second.chain_tallies, first_slots)
	result.mornings = first.mornings + _moved_slots(second.mornings, first_slots)
	result.pairs = first.pairs.duplicate()
	for pair: Vector2i in second.pairs:
		result.pairs.append(pair + Vector2i(first_slots, first_slots))
	return result


## `result` counted on from `start` (a Double checkout's row 2 after row 1's total, for its
## count-up): every subtotal and the total `start` higher, the slots unchanged.
static func continued(result: ScoreResult, start: int) -> ScoreResult:
	var moved: ScoreResult = ScoreResult.new()
	moved.total = result.total + start
	moved.payouts = result.payouts
	moved.tags = result.tags
	for step: ScoreStep in result.steps:
		moved.steps.append(step.moved(0, start))
	moved.batches = result.batches
	moved.chains = result.chains
	moved.knot_factors = result.knot_factors
	moved.chain_feeds = result.chain_feeds
	moved.chain_tallies = result.chain_tallies
	moved.mornings = result.mornings
	moved.pairs = result.pairs
	return moved


## `runs` (batches or chains, slots each) with every slot `slots` later.
static func _moved_runs(runs: Array[PackedInt32Array], slots: int) -> Array[PackedInt32Array]:
	var moved: Array[PackedInt32Array] = []
	for run: PackedInt32Array in runs:
		moved.append(_moved_slots(run, slots))
	return moved


## `at` with every slot (not -1: none) `slots` later.
static func _moved_slots(at: PackedInt32Array, slots: int) -> PackedInt32Array:
	var moved: PackedInt32Array = PackedInt32Array()
	for slot: int in at:
		moved.append(slot + slots if slot >= 0 else slot)
	return moved
