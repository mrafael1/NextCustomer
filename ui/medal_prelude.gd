class_name MedalPrelude
extends Node
## CHECKOUT's medal prelude (the user's proposition after the play test of 2026-11-09): when the
## checkout EARNED a week medal (the count's context: OvertimeTickets.State.EARNED), before the
## count the bell dings, the gauge (still showing the projection) runs its laps from empty, ×1,
## ×2, ×3 (GaugePanel.run_laps: its pours, lap notes and growing ×N), and at each medal's lap the
## gauge's lap lamp pops and sends its token to that medal in the register's medal case,
## which flies onto the receipt's target (ReceiptGoldFlow.spend: silver first, then gold; the
## user's play test of 2026-11-10); its landing turns the receipt (silver's wipe, then gold's over
## it). A long run (×6 and up; the user's play test of 2026-11-10) steps only up to the last
## medal's lap, rolls through the rest in a fixed time and lands on its final ×N, held a moment.
## Once the paper has turned, the gauge slides up out of the bar and the classic
## count runs on the metal paper (it never turns it again). With no medal earned (used this week,
## a payday's gold, the last shift, a miss, a Day off, a Double checkout's row 1) there is no
## prelude: the gauge hides as the count starts, as before.
##
## A tap (Space or the left button, PressReader) skips the prelude and the count with it: every
## lap, flight and metal lands at once, the gauge goes up at once, and the count starts tapped
## (CountUp.tap_ahead). Reduced motion: all of it at once. Display only: the medals were spent at
## the click (RunState.checkout).

## The longest the prelude waits for its flights, wipes and slide to end (a safety, seconds).
const SETTLE_MAX_SECONDS := 4.0

## The prelude rang the bell for this checkout (ShiftStage's count start then doesn't).
var rang_bell: bool = false
## How long the last prelude played (Time ms; 0 for none): the count_up event's count starts
## after it.
var played_ms: int = 0

var _gauge: GaugePanel
var _gold: ReceiptGoldFlow
var _bell: ServiceBell
var _count_up: CountUp
var _presses: PressReader
var _playing: bool = false
var _skipped: bool = false
var _instant: bool = false
## The medals this checkout earned [SILVER, GOLD], and the laps each one asks for.
var _medals: Array[bool] = [false, false]
var _laps: Array[int] = [0, 0]


## The prelude on `gauge`, turning `gold_flow`'s paper, ringing `bell`; a skip taps `count_up`.
func _init(
	gauge: GaugePanel, gold_flow: ReceiptGoldFlow, bell: ServiceBell, count_up: CountUp
) -> void:
	name = "MedalPrelude"
	_gauge = gauge
	_gold = gold_flow
	_bell = bell
	_count_up = count_up
	_presses = PressReader.new()
	add_child(_presses)
	_presses.tapped.connect(skip)
	gauge.lap_run_step.connect(_on_lap)


## The medals `context`'s checkout earned, [SILVER, GOLD] (none before a count's context).
static func earned(context: CountUpContext) -> Array[bool]:
	if context == null:
		return [false, false]
	var state: int = OvertimeTickets.State.EARNED
	return [
		context.overtime_ticket == state and context.overtime_ticket_laps > 0,
		context.overtime_premium == state and context.overtime_premium_laps > 0,
	]


## Plays the prelude for the checkout of `context` reaching `total` against `quota` (returns at
## once when it earned no medal).
func play(context: CountUpContext, total: int, quota: int) -> void:
	_gold.begin_award()
	rang_bell = false
	played_ms = 0
	_medals = earned(context)
	if not (_medals[0] or _medals[1]):
		return
	_laps = [context.overtime_ticket_laps, context.overtime_premium_laps]
	_playing = true
	_skipped = false
	_instant = context.reduced_motion
	_bell.ding()
	rang_bell = true
	_presses.begin()
	var started_ms: int = Time.get_ticks_msec()
	await _gauge.run_laps(total, quota, _lead_laps())
	_on_lap(QuotaLaps.lap_of(total, quota))  # A medal the run's laps missed still flies.
	await _wait_while(_gold.is_turning)
	_gauge.hide_gauge(not (_skipped or _instant))
	await _wait_while(func() -> bool: return _gauge.up_amount() < 1.0)
	if _skipped:
		_gold.settle(_medals[0], _medals[1])
	_presses.end()
	_playing = false
	played_ms = Time.get_ticks_msec() - started_ms


## The highest lap an earned medal waits for: the gauge steps up to it before a long run rolls.
func _lead_laps() -> int:
	var lead: int = 0
	for index: int in range(2):
		if _medals[index]:
			lead = maxi(lead, _laps[index])
	return lead


## Whether the prelude plays now.
func is_playing() -> bool:
	return _playing


## Whether a tap skipped the prelude now playing (or the last one).
func was_skipped() -> bool:
	return _skipped


## A tap (released at `_now_ms`): everything lands at once, and the count that follows starts
## tapped.
func skip(_now_ms: int = 0) -> void:
	if not _playing or _skipped:
		return
	_skipped = true
	_gauge.finish_laps()
	_gold.settle(_medals[0] and _gold.has_flown(false), _medals[1] and _gold.has_flown(true))
	_gauge.hide_gauge(false)
	_count_up.tap_ahead()


## The run made `made` laps: each earned medal whose laps they reach flies (once).
func _on_lap(made: int) -> void:
	if not _playing:
		return
	for index: int in range(2):
		if _medals[index] and made >= _laps[index] and not _gold.has_flown(index == 1):
			_gold.spend(index == 1, _instant or _skipped)


## Waits frames while `busy` holds, unless the prelude is skipped (or SETTLE_MAX_SECONDS passed).
func _wait_while(busy: Callable) -> void:
	var waited: float = 0.0
	while bool(busy.call()) and not _skipped and is_inside_tree():
		if waited > SETTLE_MAX_SECONDS:
			return
		await get_tree().process_frame
		waited += get_process_delta_time()
