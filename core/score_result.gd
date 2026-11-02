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
