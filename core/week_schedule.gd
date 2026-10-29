class_name WeekSchedule
extends RefCounted
## The run's weeks (v0.70, the shift-events step 3): BalanceDefinition.week_length shifts each
## (the whole run is one week when it is 0), each with its fixed week event
## (BalanceDefinition.weeks, by week; none past the list). The week of a shift comes from its
## number alone, so a week event is never drawn nor saved. A week's day events are drawn all at
## once when its first shift starts (draw, with the run's RNG: RunState.week) and saved with the
## run. Pure.


## How many shifts a week has: week_length, or the whole run (at least 1) when it is 0.
static func length(balance: BalanceDefinition) -> int:
	if balance.week_length > 0:
		return balance.week_length
	return maxi(balance.quotas.size(), 1)


## The 0-based week of the 1-based `shift_number`.
static func week_of(balance: BalanceDefinition, shift_number: int) -> int:
	return floori((maxi(shift_number, 1) - 1) / float(length(balance)))


## How many weeks the run has (at least 1).
static func week_count(balance: BalanceDefinition) -> int:
	return maxi(ceili(balance.quotas.size() / float(length(balance))), 1)


## The 1-based first shift of the week holding the 1-based `shift_number`.
static func first_shift(balance: BalanceDefinition, shift_number: int) -> int:
	return week_of(balance, shift_number) * length(balance) + 1


## Whether the 1-based `shift_number` starts its week (the time card opens there).
static func is_week_start(balance: BalanceDefinition, shift_number: int) -> bool:
	return first_shift(balance, shift_number) == shift_number


## How many shifts the week holding `shift_number` has: a whole week, or the run's last ones.
static func days_in(balance: BalanceDefinition, shift_number: int) -> int:
	var first: int = first_shift(balance, shift_number)
	var left: int = balance.quotas.size() - first + 1
	return clampi(left, 1, length(balance)) if left > 0 else length(balance)


## The week event of the 1-based `shift_number`'s week, or null (no week events, or past them).
static func event_for(balance: BalanceDefinition, shift_number: int) -> WeekEventDefinition:
	var week: int = week_of(balance, shift_number)
	return balance.weeks[week] if week < balance.weeks.size() else null


## Every event the 1-based `shift_number` is played under: its `day_events`, then its week event
## (when there is one). Scoring's and ShiftLimits' list, so a step's source_index counts the week
## event after the day's own.
static func events_for(
	balance: BalanceDefinition, shift_number: int, day_events: Array[InspectionDefinition]
) -> Array[InspectionDefinition]:
	var events: Array[InspectionDefinition] = day_events.duplicate()
	var week: WeekEventDefinition = event_for(balance, shift_number)
	if week != null:
		events.append(week)
	return events


## Every event `run`'s current shift is played under (events_for). A shift a save from before
## v0.70 was on (RunState.pre_week_shift) keeps playing without its week event.
static func shift_events(run: RunState) -> Array[InspectionDefinition]:
	var shift_number: int = run.shift_index + 1
	if shift_number == run.pre_week_shift:
		return run.inspections.duplicate()
	return events_for(run.balance, shift_number, run.inspections)


## The machine odds levels the visits after the 1-based `shift_number` draw above their own: its
## week event's odds_level_delta (Holiday rush +1); 0 for shift 0 (before any checkout).
static func odds_delta(balance: BalanceDefinition, shift_number: int) -> int:
	if shift_number <= 0:
		return 0
	var week: WeekEventDefinition = event_for(balance, shift_number)
	return week.odds_level_delta if week != null else 0


## The day events of the week holding the 1-based `shift_number`, one day at a time with the run's
## RNG (InspectionSchedule.draw_for: a day without events uses none). `previous` (the run's last
## events, InspectionSchedule.last_of) are left out of the first day's draw while others remain,
## then each day's events of the day before, so no event comes twice in a row when it can be
## helped, as when each day was drawn at the previous checkout.
static func draw(
	rng: RandomNumberGenerator,
	balance: BalanceDefinition,
	shift_number: int,
	previous: Array[InspectionDefinition] = []
) -> WeekPlan:
	var plan: WeekPlan = WeekPlan.new()
	plan.first_shift = first_shift(balance, shift_number)
	var last: Array[InspectionDefinition] = previous.duplicate()
	for day: int in range(days_in(balance, shift_number)):
		var drawn: Array[InspectionDefinition] = InspectionSchedule.draw_for(
			rng, balance, plan.first_shift + day, last
		)
		plan.days.append(drawn)
		last = after(last, drawn)
	return plan


## The run's last events once a day with `drawn` is played after `last` (InspectionSchedule.last_of:
## the latest maluses, then the latest boon).
static func after(
	last: Array[InspectionDefinition], drawn: Array[InspectionDefinition]
) -> Array[InspectionDefinition]:
	var record: ShiftRecord = ShiftRecord.new(0, 0, 0)
	record.inspections = last
	var history: Array[ShiftRecord] = [record]
	return InspectionSchedule.last_of(drawn, history)
