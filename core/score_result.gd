class_name ScoreResult
extends RefCounted
## The outcome of Scoring.score(): the total, each slot's payout, the tags after the context
## pass, and every step that explains them.

var total: int = 0
var payouts: PackedInt32Array = PackedInt32Array()
var tags: Array[PackedStringArray] = []
var steps: Array[ScoreStep] = []


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
	return moved
