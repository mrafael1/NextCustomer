class_name ScoreResult
extends RefCounted
## The outcome of Scoring.score(): the total, each slot's payout, the tags after the context
## pass, and every step that explains them.

var total: int = 0
var payouts: PackedInt32Array = PackedInt32Array()
var tags: Array[PackedStringArray] = []
var steps: Array[ScoreStep] = []
