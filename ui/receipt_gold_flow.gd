class_name ReceiptGoldFlow
extends Node
## When the shift screen's receipt turns silver or gold (ReceiptGold), when it wears payday's
## paycheck design (ReceiptView.payday_ribbon), and when the week's medals are spent (2026-11-06,
## the "spend" model: WeekMedals, mock-up docs/art/mockups/week_medals.html).
##
## Left column v2 (the user's pick of 2026-11-09, mock-up docs/art/mockups/left_column_v2.html):
## the gauge hides at CHECKOUT, so the paper carries the week's medals. The paper turns for the
## medal the checkout actually WINS (the count's context: OvertimeTickets.State.EARNED; the
## user's play test of 2026-11-09): SILVER when the overtime ticket's medal is earned
## (MachineDefinition.overtime_ticket_laps, twice the target), GOLD when the PREMIUM medal is
## (three times), each capped by its own week (a silver already used this week with the gold
## still free wipes cream straight to gold). A medal already used this week, or one not granted
## (a payday's gold: its visit is PREMIUM anyway), turns nothing. The medals are spent before the
## count (MedalPrelude, CHECKOUT's medal prelude, the user's proposition of the same play test):
## as the gauge runs its laps, the gauge's lap lamp sends a token to each earned medal in the
## register's medal case (v1.17), which leaves it and flies onto the receipt's target
## (MedalFlight; the user's play test of 2026-11-10: gauge, then medal, then receipt), and the
## paper turns as it lands (spend; gold over a silver still wiping: two beats). The count that
## follows runs on that paper and never turns it again. After the count (a resume too) the
## shift's record says it all (refresh): the medals it spent. A payday (payday(): the PAYDAY NEXT
## announce's own check) is a paycheck design on the paper, from the shift's opening through its
## count and its verdict, never a metal of its own; the next ordinary shift's opens plain. While
## planning, a medal the projection would spend makes the paper's edges glow in its metal and the
## PROJECTED number take it (show_pending; gold over silver), quiet again when the projection
## drops back (at CHECKOUT). Reduced motion switches at once, with no flight.

var flight: MedalFlight
var _count_up: CountUp
var _receipt: ReceiptView
## The metals the checkout on screen turned (none turns twice), [SILVER, GOLD], and the medals
## it spent (none flies twice); the turns still to land or wait for a silver's wipe.
var _turned: Array[bool] = [false, false]
var _flown: Array[bool] = [false, false]
var _turning: int = 0


## Follows `count_up`'s counts for `receipt`, flying the week's medals from `medal_case` (the
## register's, v1.17; null: no flight, the paper still turns) onto its target, each called by
## `meter`'s lap lamp.
func _init(
	count_up: CountUp, meter: QuotaMeter, receipt: ReceiptView, medal_case: MedalCase = null
) -> void:
	name = "ReceiptGoldFlow"
	_count_up = count_up
	_receipt = receipt
	flight = MedalFlight.new(medal_case, meter, receipt.target)
	add_child(flight)
	count_up.count_started.connect(func(_views: Array[CardView]) -> void: _begin())


## Whether passing `run`'s shift is a payday, as the PAYDAY NEXT announce reads it (MachineFlow:
## the machine's PREMIUM after it, and a payday).
static func payday(run: RunState) -> bool:
	return run.machine != null and run.machine.premium_if_passed(run) and Payday.if_passed(run)


## The overtime PREMIUM laps `run`'s machine data asks for (the GOLD paper's and medal's; 0: off).
static func premium_laps(run: RunState) -> int:
	return WeekMedals.laps_of(WeekMedals.machine_data(run), true)


## The overtime ticket's laps `run`'s machine data asks for (the SILVER paper's and medal's; 0:
## off).
static func ticket_laps(run: RunState) -> int:
	return WeekMedals.laps_of(WeekMedals.machine_data(run), false)


## The medals `run`'s checked-out shift on screen spent, [SILVER, GOLD] (none in planning or
## before its record).
static func spent(run: RunState) -> Array[bool]:
	if run.phase == RunState.Phase.PLANNING or run.history.is_empty():
		return [false, false]
	var record: ShiftRecord = run.history[-1]
	if not OvertimeCue.counts_shift(run, record):
		return [false, false]
	return [record.overtime_ticket, record.overtime_premium]


## The receipt as `run` stands outside a count (`counting`: the count drives the metal, and
## planning's glow goes): payday's paycheck design on a payday; gold once the shift spent the
## week's PREMIUM medal, silver once it spent the ticket's (and not the gold); cream otherwise.
## `reduced_motion` switches the glow at once; the metal outside a count always does.
func refresh(run: RunState, counting: bool, reduced_motion: bool) -> void:
	if run == null:
		return
	_receipt.payday_ribbon.visible = payday(run)
	if counting or run.phase != RunState.Phase.PLANNING:
		_receipt.gold.show_pending(ReceiptGold.PENDING_NONE, reduced_motion)
	if counting:
		return
	var reached: Array[bool] = spent(run)
	_receipt.gold.show_gold(reached[1], true)
	_receipt.gold.show_silver(reached[0] and not reached[1], true)


## Planning's projection would spend the SILVER (`silver`) and the GOLD (`gold`): the paper's edges
## glow in the gold (over the silver), or go quiet.
func show_pending(silver: bool, gold: bool, reduced_motion: bool) -> void:
	var metal: int = ReceiptGold.PENDING_NONE
	if gold:
		metal = ReceiptGold.PENDING_GOLD
	elif silver:
		metal = ReceiptGold.PENDING_SILVER
	_receipt.gold.show_pending(metal, reduced_motion)


## Whether the checkout on screen spent medal `gold` (its flight launched).
func has_flown(gold: bool) -> bool:
	return _flown[1 if gold else 0]


## Whether the checkout on screen turned the paper `gold` (else silver).
func has_turned(gold: bool) -> bool:
	return _turned[1 if gold else 0]


## A new checkout (MedalPrelude): no metal turned and no medal flown yet.
func begin_award() -> void:
	_turned = [false, false]
	_flown = [false, false]


## Spends medal `gold` (else silver) once: the lap lamp's token calls it, it flies from the case
## onto the receipt's target and the paper turns its metal as it lands (`instant`: at once, no
## flight).
func spend(gold: bool, instant: bool) -> void:
	var index: int = 1 if gold else 0
	if _flown[index]:
		return
	_flown[index] = true
	_turned[index] = true
	_turning += 1
	flight.fly(gold, instant, _turn.bind(instant))


## The paper as the spent medals leave it, at once (a skipped prelude): silver for `silver`, gold
## (over it) for `gold`, every flight landed.
func settle(silver: bool, gold: bool) -> void:
	flight.finish()
	_receipt.gold.show_silver(silver, true)
	_receipt.gold.show_gold(gold, true)


## Whether a spent medal is still flying or its metal still wiping on.
func is_turning() -> bool:
	var metal: ReceiptGold = _receipt.gold
	if _turning > 0 or flight.is_flying():
		return true
	return (
		(metal.is_silver() and metal.silver_amount() < 1.0)
		or (metal.is_gold() and metal.amount() < 1.0)
	)


## A new count: planning's glow goes (the metal stays: the prelude set it).
func _begin() -> void:
	var instant: bool = _count_up.plan != null and _count_up.plan.reduced_motion
	_receipt.gold.show_pending(ReceiptGold.PENDING_NONE, instant)


## The paper turns `gold` (else silver): gold waits for a silver still wiping on, so the two read
## as two beats.
func _turn(gold: bool, instant: bool) -> void:
	var metal: ReceiptGold = _receipt.gold
	if not gold:
		metal.show_silver(true, instant)
		_turning -= 1
		return
	if not instant and metal.is_silver() and metal.silver_amount() < 1.0 and is_inside_tree():
		await get_tree().create_timer(ReceiptGold.WIPE_SECONDS).timeout
	metal.show_gold(true, instant)
	_turning -= 1
