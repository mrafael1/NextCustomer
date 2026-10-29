class_name WeekEventDefinition
extends InspectionDefinition
## One week event as designed (v0.70, the shift-events step 3): the big event of a week of shifts,
## on top of its day events (BalanceDefinition.weeks, one per week, fixed: the shift number gives
## it, so nothing about it is saved). Its tone is WEEK (set in its .tres file; a data test checks
## it). Every hook of a day event works the same and stacks with the day's own events
## (WeekSchedule.shift_events): its scoring rules give engine steps of their own (source_kind
## INSPECTION, the count-up plays them from the week chip), and its shift modifiers add to
## ShiftLimits (Bakery festival's quota +10%). It never counts as an inspection or a boon.
##
## The time card (WeekCard) prints its name in capitals on its banner and its notice_text under it;
## the week chip shows its short name (chip_text, "BAKERY").

## Machine odds levels the visits after each of its shifts draw above their own (Holiday rush +1,
## RewardMachine.odds_level), clamped to the machine's top level.
@export var odds_level_delta: int = 0
## The training week (v0.68): its card counts the slips the run forgives (the balance's
## write_up_limit; TrainingWeek has the rule) and the week chip shows them.
@export var forgives_slips: bool = false
