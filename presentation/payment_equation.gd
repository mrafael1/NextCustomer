class_name PaymentEquation
extends RefCounted
## An item's payment equation on the monitor at its payout (Checkout Rhythm v3, mock-up
## checkout_rhythm_v3_1.html): "€X × N → €Y", read from the item's real ScoreSteps, never from
## the rules. X is the value before the item's first multiplier, N the product of its multipliers'
## factors and Y its payout. All flat bonuses come before all multipliers (PROTOTYPE_PLAN 3.8), so
## an item with a multiplier reads as one product; any other shape (a plain or flat-only item, a
## €0 payout, a copy such as Repeat, a payout override, a flat after a multiplier, or numbers
## that don't multiply out) has none. Pure: every number is the steps'.

## The equation's parts: the start, the factor ("× N", amber on the monitor), the arrow and the
## payout.
const START := "€%d"
const FACTOR := "× %d"
const PAYOUT := "€%d"
const TEXT := "%s %s %s %s"

## The value before the first multiplier, the product of the factors and the payout.
var start: int = 0
var factor: int = 1
var payout: int = 0


func _init(start_value: int, product: int, paid: int) -> void:
	start = start_value
	factor = product
	payout = paid


## `slot`'s equation from `steps` (ScoreResult.steps), or null when it has none (see the class
## comment). Steps that don't move the item's value (tags, links, fizzles, an armed effect, a
## credit) are skipped.
static func of(steps: Array[ScoreStep], slot: int) -> PaymentEquation:
	var before: int = -1
	var product: int = 1
	var multipliers: int = 0
	var paid: int = -1
	for step: ScoreStep in steps:
		if step.slot != slot:
			continue
		var type: ScoreStep.StepType = step.step_type
		if type == ScoreStep.StepType.PAYOUT:
			paid = step.value
			break
		if type in [ScoreStep.StepType.COPY, ScoreStep.StepType.PAYOUT_OVERRIDE]:
			return null
		if type in [ScoreStep.StepType.BASE, ScoreStep.StepType.FLAT]:
			if multipliers > 0:
				return null
			before = step.value_after
		elif type == ScoreStep.StepType.MULTIPLIER:
			if before < 0:
				return null
			multipliers += 1
			product *= step.value
	if multipliers == 0 or paid <= 0 or before * product != paid:
		return null
	return PaymentEquation.new(before, product, paid)


## The start's words: "€12".
func start_text() -> String:
	return START % start


## The factor's words: "× 6".
func factor_text() -> String:
	return FACTOR % factor


## The payout's words: "€72".
func payout_text() -> String:
	return PAYOUT % payout


## The whole equation: "€12 × 6 → €72" (`arrow`: MonitorText.ARROW, or its fallback).
func text(arrow: String = MonitorText.ARROW) -> String:
	return TEXT % [start_text(), factor_text(), arrow, payout_text()]
