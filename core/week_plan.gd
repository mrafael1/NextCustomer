class_name WeekPlan
extends RefCounted
## The day events of one week's shifts (v0.70, the time card): drawn all at once when the week's
## first shift starts (WeekSchedule.draw, with the run's RNG), so the card shows the whole week
## ahead, and saved with the run. Each day's list holds its inspections, then its boon, as
## RunState.inspections does. Pure data.

## The 1-based shift number of the week's first day.
var first_shift: int = 0
## One list of day events per shift of the week, in order (Array[InspectionDefinition] each).
var days: Array[Array] = []


## Whether the 1-based `shift_number` is one of the week's days.
func covers(shift_number: int) -> bool:
	return shift_number >= first_shift and shift_number < first_shift + days.size()


## The 1-based shift number of the week's last day.
func last_shift() -> int:
	return first_shift + days.size() - 1


## The day events of the 1-based `shift_number` (a copy), or none outside the week.
func day(shift_number: int) -> Array[InspectionDefinition]:
	var found: Array[InspectionDefinition] = []
	if covers(shift_number):
		found.assign(days[shift_number - first_shift])
	return found


## Sets the day events of the 1-based `shift_number`, one of the week's days (a copy is kept).
func set_day(shift_number: int, events: Array[InspectionDefinition]) -> void:
	if covers(shift_number):
		days[shift_number - first_shift] = events.duplicate()
