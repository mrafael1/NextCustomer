class_name ReceiptGoldFlow
extends Node
## When the shift screen's receipt is gold or silver (2026-11-05, ReceiptGold) and when the week
## badge's medals are spent (2026-11-06, the "spend" model: WeekMedals, mock-up
## docs/art/mockups/week_medals.html). A payday shift's receipt (payday(): the PAYDAY NEXT
## announce's own check) is gold from the shift's opening, a resume's included, through its count
## and its verdict, passed or missed; the next ordinary shift's opens on cream again.
##
## A metal receipt always pays: during the count, when the gauge reaches the overtime ticket's laps
## (MachineDefinition.overtime_ticket_laps, the ×2) and the checkout spends the week's SILVER medal
## (the count's context: OvertimeTickets.State.EARNED), the medal leaves its socket on the week
## badge and flies into the gauge's lap lamp (MedalFlight); as it lands the lamp pops and the
## paper turns SILVER with its "2× QUOTA" stamp in steel. At the PREMIUM laps (the ×3) with the GOLD
## spent, the same in gold: the paper turns gold with its "3× QUOTA" stamp (gold wins over silver;
## a payday's paper, gold already, keeps its gold and takes the stamp). A medal already spent this
## week moves nothing: the lap still fills in its colour, the receipt stays plain (or a payday's
## gold). The laps are reached by the gauge (its lap, or the total landing past them, the last
## item's included). After the count (a resume too) the shift's record says it all (refresh).
## While planning, a medal the projection would spend makes the paper's edges glow in its metal
## (show_pending; gold over silver), quiet again when the projection drops back. Reduced motion
## switches at once, with no flight.

var flight: MedalFlight
var _count_up: CountUp
var _meter: QuotaMeter
var _receipt: ReceiptView
## The medals spent by the count on screen (none flies twice), [SILVER, GOLD].
var _flown: Array[bool] = [false, false]


## Follows `count_up`'s counts on `meter` for `receipt`, flying the week badge's medals from
## `sockets` (null: no flight, the paper still turns).
func _init(
	count_up: CountUp, meter: QuotaMeter, receipt: ReceiptView, sockets: MedalSockets = null
) -> void:
	name = "ReceiptGoldFlow"
	_count_up = count_up
	_meter = meter
	_receipt = receipt
	flight = MedalFlight.new(sockets, meter)
	add_child(flight)
	meter.lap_reached.connect(_on_laps)
	count_up.total_landed.connect(func() -> void: _on_laps(_meter.multiples_made()))
	count_up.count_started.connect(func(_views: Array[CardView]) -> void: _begin())


## Whether passing `run`'s shift is a payday, as the PAYDAY NEXT announce reads it (MachineFlow:
## the machine's PREMIUM after it, and a payday).
static func payday(run: RunState) -> bool:
	return run.machine != null and run.machine.premium_if_passed(run) and Payday.if_passed(run)


## The overtime PREMIUM laps `run`'s machine data asks for (the GOLD medal's; 0: off).
static func premium_laps(run: RunState) -> int:
	return WeekMedals.laps_of(WeekMedals.machine_data(run), true)


## The overtime ticket's laps `run`'s machine data asks for (the SILVER medal's; 0: off).
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


## The receipt as `run` stands outside a count (`counting`: the count drives it, and planning's
## glow goes): gold on a payday or once the shift spent the GOLD, with its stamp; silver once it
## spent the SILVER (short of gold), with its stamp; cream otherwise. `reduced_motion` switches at
## once.
func refresh(run: RunState, counting: bool, reduced_motion: bool) -> void:
	if run == null:
		return
	if counting or run.phase != RunState.Phase.PLANNING:
		_receipt.gold.show_pending(ReceiptGold.PENDING_NONE, reduced_motion)
	if counting:
		return
	var paid: Array[bool] = spent(run)
	var gold: bool = paid[1]
	var silver: bool = paid[0] and not gold
	_receipt.gold.show_gold(payday(run) or gold, reduced_motion)
	_receipt.gold.show_silver(silver, reduced_motion)
	if gold:
		_receipt.gold.show_stamp(premium_laps(run), reduced_motion)
	else:
		_receipt.gold.show_stamp(ticket_laps(run) if paid[0] else 0, reduced_motion, true)


## Planning's projection would spend the SILVER (`silver`) and the GOLD (`gold`): the paper's edges
## glow in the gold (over the silver), or go quiet.
func show_pending(silver: bool, gold: bool, reduced_motion: bool) -> void:
	var metal: int = ReceiptGold.PENDING_NONE
	if gold:
		metal = ReceiptGold.PENDING_GOLD
	elif silver:
		metal = ReceiptGold.PENDING_SILVER
	_receipt.gold.show_pending(metal, reduced_motion)


## Whether the count on screen spent medal `gold` (its flight launched).
func has_flown(gold: bool) -> bool:
	return _flown[1 if gold else 0]


## A new count: no medal has flown yet, and planning's glow goes.
func _begin() -> void:
	_flown = [false, false]
	var instant: bool = _count_up.plan != null and _count_up.plan.reduced_motion
	_receipt.gold.show_pending(ReceiptGold.PENDING_NONE, instant)


## The count's gauge made `made` laps: each medal the checkout spends whose laps they reach flies
## into the lap lamp (once), and the paper turns its metal as it lands.
func _on_laps(made: int) -> void:
	var context: CountUpContext = _count_up.run_context
	if context == null:
		return
	var instant: bool = _count_up.plan != null and _count_up.plan.reduced_motion
	var medals: Array[Array] = [
		[false, context.overtime_ticket_laps, context.overtime_ticket],
		[true, context.overtime_premium_laps, context.overtime_premium],
	]
	for medal: Array in medals:
		var gold: bool = medal[0]
		var laps: int = medal[1]
		var index: int = 1 if gold else 0
		if laps <= 0 or made < laps or _flown[index]:
			continue
		if int(medal[2]) != OvertimeTickets.State.EARNED:
			continue
		_flown[index] = true
		flight.fly(gold, instant, _on_landed.bind(laps, instant))


## Medal `gold` (of `laps` laps) landed in the lamp: the paper turns its metal with its stamp
## (silver only on cream: a gold paper, a payday's, takes the silver's stamp alone).
func _on_landed(gold: bool, laps: int, instant: bool) -> void:
	if gold:
		_receipt.gold.show_gold(true, instant)
		_receipt.gold.show_stamp(laps, instant)
	elif not _receipt.gold.is_gold():
		_receipt.gold.show_silver(true, instant)
		_receipt.gold.show_stamp(laps, instant, true)
	elif _receipt.gold.stamp() == null:
		_receipt.gold.show_stamp(laps, instant, true)  # A payday's gold paper takes the 2×.
