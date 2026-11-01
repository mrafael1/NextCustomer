class_name WeekCardModel
extends RefCounted
## What the time card and the top bar's week and day chips show (v0.70, mock-up
## docs/art/mockups/rota_card_v1.html, layout C): the run's current week, its fixed week event,
## and every day of the week in full (the week plan, RunState.week, drawn as the week started): its
## day events, whether it is a Manager's review (its two maluses, then "REVIEW PASSED · 2 PREMIUM
## TICKETS", or on the run's last shift "PASS = RUN WON"), and whether it is punched in (played,
## or today's), and how a played day ended (v0.72: PAID, or a training week's SLIP 1/2). Pure:
## built from the run, read by WeekCard, WeekChip and InspectionTag.

## A day's kind, its chip's tint: grey (no event), green (a boon), tomato (an inspection),
## mustard (a Manager's review).
enum Kind { NONE, BOON, MALUS, REVIEW }
## A week chip pip: a day to come, a played one with no result, today's, and a played one by
## its result (v0.75, #119: a green check for PAID, a red cross for a SLIP).
enum Pip { TODO, DONE, NOW, PAID, SLIP }
## How a day ended (v0.72), its stamp on the card: not played yet, passed, or a forgiven miss.
enum Result { NONE, PAID, SLIP }

const WEEK_HEAD := "WEEK %d OF %d"
const WEEK_TITLE := "WEEK %d"
const CARD_TITLE := "TIME CARD"
const CARD_SUB := "CASHIER · TILL 4"
const REVIEW_HEAD := "MANAGER'S REVIEW · %d MALUSES"
const FINAL_HEAD := "FINAL REVIEW · %d MALUSES"
const FINAL_REWARD := "PASS = RUN WON"
const PUNCH := "IN"
const NO_EVENT := "Normal day"
const NO_EVENT_EFFECT := "No event"
## The training week's banner line (v0.84, in place of v0.68's notice and slips left): the misses
## it forgives.
## On the card the misses are a red tag after the lead (misses_text).
const ALLOWS_LEAD := "THIS WEEK ALLOWS"
const MISSES := "%d MISSES"
const MISSES_ONE := "1 MISS"
## A played day's stamp (v0.72): a pass, and a training week's forgiven miss with its count.
const PAID_STAMP := "PAID"
const SLIP_STAMP := "SLIP %d/%d"
## Today's tab on the card (#119).
const TODAY_TAB := "TODAY"

## The 1-based week, and how many the run has.
var week_number: int = 1
var week_count: int = 1
## The week's fixed event, or null.
var event: WeekEventDefinition
## The misses the training week forgives in all (0 outside it, or with a balance without slips).
var allowed_misses: int = 0
## The week's days, in order.
var days: Array[WeekDay] = []


## One day of the week on the card.
class WeekDay:
	extends RefCounted
	## The day's 1-based shift number ("D5").
	var shift: int = 0
	var events: Array[InspectionDefinition] = []
	var kind: Kind = Kind.NONE
	## A Manager's review, and the run's last one (FINAL REVIEW).
	var review: bool = false
	var final: bool = false
	## Passing it pays two PREMIUM tickets (Payday).
	var payday: bool = false
	## Played already (punched in), or today's (punched in as the card opens).
	var punched: bool = false
	var today: bool = false
	## How it ended (v0.72), and for a SLIP the misses so far and the training week's limit.
	var result: Result = Result.NONE
	var slip_number: int = 0
	var slip_limit: int = 0

	## The day's stamp ("PAID", "SLIP 1/2"), or "" before it is played.
	func stamp() -> String:
		match result:
			Result.PAID:
				return PAID_STAMP
			Result.SLIP:
				return SLIP_STAMP % [slip_number, slip_limit]
		return ""

	## The review's head line ("MANAGER'S REVIEW · 2 MALUSES"), or "" for another day.
	func head() -> String:
		if not review:
			return ""
		var count: int = InspectionDefinition.maluses(events).size()
		return (FINAL_HEAD if final else REVIEW_HEAD) % count

	## The review's reward line: Payday's, the last review's "PASS = RUN WON", else "".
	func reward() -> String:
		if final:
			return FINAL_REWARD
		return Payday.BANNER_LINE if payday else ""


## The card of `run`'s current week (its plan; an empty week before the first shift starts).
static func of(run: RunState) -> WeekCardModel:
	var model: WeekCardModel = WeekCardModel.new()
	var balance: BalanceDefinition = run.balance
	var shift: int = run.shift_index + 1
	model.week_number = WeekSchedule.week_of(balance, shift) + 1
	model.week_count = WeekSchedule.week_count(balance)
	model.event = WeekSchedule.event_for(balance, shift)
	# A shift a save from before v0.70 was on plays without its week event
	# (WeekSchedule.shift_events), so the card and chips don't name it; the training week's,
	# which has no rules, stays for its slips.
	if shift == run.pre_week_shift and model.event != null and not model.event.forgives_slips:
		model.event = null
	if model.event != null and model.event.forgives_slips:
		model.allowed_misses = run.balance.write_up_limit
	var plan: WeekPlan = run.week
	var first: int = WeekSchedule.first_shift(balance, shift)
	for day_shift: int in range(first, first + WeekSchedule.days_in(balance, shift)):
		var day: WeekDay = WeekDay.new()
		day.shift = day_shift
		if day_shift == shift:
			day.events = run.inspections.duplicate()
		elif plan != null:
			day.events = plan.day(day_shift)
		day.kind = kind_of(day.events)
		day.review = InspectionSchedule.is_review_shift(balance, day_shift)
		day.final = day.review and day_shift == run.shift_count()
		day.payday = (
			day.review and balance.machine != null and balance.machine.is_payday_shift(day_shift)
		)
		day.today = day_shift == shift
		day.punched = day_shift <= shift
		_add_result(day, run)
		model.days.append(day)
	return model


## `day`'s result from `run`'s history (v0.72): PAID for a passed shift, SLIP for a missed one
## (counted with the misses before it), none for a day not played.
static func _add_result(day: WeekDay, run: RunState) -> void:
	var misses: int = 0
	for record: ShiftRecord in run.history:
		if not record.passed and record.shift <= day.shift:
			misses += 1
		if record.shift == day.shift:
			day.result = Result.PAID if record.passed else Result.SLIP
	if day.result == Result.SLIP:
		day.slip_number = misses
		day.slip_limit = run.balance.write_up_limit


## The tint of a day with `events`: REVIEW for several inspections, MALUS for one, BOON for a boon
## day, NONE without any.
static func kind_of(events: Array[InspectionDefinition]) -> Kind:
	var maluses: int = InspectionDefinition.maluses(events).size()
	if maluses > 1:
		return Kind.REVIEW
	if maluses == 1:
		return Kind.MALUS
	return Kind.BOON if not InspectionDefinition.boons(events).is_empty() else Kind.NONE


## The banner's head ("WEEK 2 OF 3").
func head() -> String:
	return WEEK_HEAD % [week_number, week_count]


## The banner's title: the week event's name in capitals, or "WEEK n".
func title() -> String:
	return event.display_name.to_upper() if event != null else WEEK_TITLE % week_number


## The banner's effect line: the week event's notice, the training week's "THIS WEEK ALLOWS 2
## MISSES", or "".
func effect() -> String:
	if event == null:
		return ""
	if event.forgives_slips:
		return "%s %s" % [ALLOWS_LEAD, misses_text()]
	return event.notice_text


## The training week's misses ("2 MISSES", the red tag on its banner), or "" outside it.
func misses_text() -> String:
	if event == null or not event.forgives_slips:
		return ""
	return MISSES_ONE if allowed_misses == 1 else MISSES % allowed_misses


## The week chip's short name (the week event's chip_text, "BAKERY"), or "".
func chip_name() -> String:
	return event.chip_text if event != null else ""


## The week chip's pips, one per day: a played day's result (today's too, once checked out),
## today's, played, to come.
func pips() -> Array[Pip]:
	var found: Array[Pip] = []
	for day: WeekDay in days:
		if day.result == Result.PAID:
			found.append(Pip.PAID)
		elif day.result == Result.SLIP:
			found.append(Pip.SLIP)
		elif day.today:
			found.append(Pip.NOW)
		else:
			found.append(Pip.DONE if day.punched else Pip.TODO)
	return found


## Whether the card opens on its own for `run`'s current shift: the first shift of its week.
static func opens_at(run: RunState) -> bool:
	return WeekSchedule.is_week_start(run.balance, run.shift_index + 1)
