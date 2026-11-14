class_name InspectionTag
extends RefCounted
## The day events' words (plan section 3.9; #80 step 10, v0.69, v0.70, v1.16), static only since
## v1.17: the top bar's day chip became the day calendar (DayCalendar, the user's pick of
## 2026-11-08), which draws the day; these name the day's kind ("Inspection", "Review" for a
## Manager's review's several, a boon day's boon name, NO_EVENT), the inspections for the receipt,
## the next shift's notice ("INSPECTION NEXT SHIFT: …", "TOMORROW: Quiet morning (quota −10%)"),
## the tints of the day kinds (the time card's) and the bonus ticket's state (bonus_for, the
## calendar's pill).

## The bonus ticket's pill: none, promised for a pass, or earned by the pass.
enum Bonus { NONE, PROMISED, EARNED }

## The red notice printed under a passed shift's total when the next shift is inspected.
const NEXT_NOTICE := "INSPECTION NEXT SHIFT: %s"
## A Manager's review's notice (v0.65): its several inspections at once, their notices joined.
const NEXT_REVIEW_NOTICE := "PAYDAY NEXT SHIFT: %s"
## A boon day's notice (v0.69), in green (ReceiptView.BOON_NOTICE_PREFIX): "TOMORROW: Quiet
## morning (quota −10%)".
const NEXT_BOON_NOTICE := ReceiptView.BOON_NOTICE_PREFIX + "%s"
## The day's kind (v1.16): an inspected shift's, and a Manager's review's (several at once,
## v0.65); a boon day's is the boon's name, a day without an event NO_EVENT.
const CAPTION := "Inspection"
const REVIEW_CAPTION := "Payday"
const NO_EVENT := WeekCardModel.NO_EVENT
## A boon's words in its notice (v0.69): "TOMORROW: Quiet morning (quota −10%)".
const BOON_TEXT := "%s (%s)"


## The day's kind (v1.16): "Review" for several inspections, "Inspection" for one, a
## boon day's boon name, else NO_EVENT.
static func kind_text(events: Array[InspectionDefinition]) -> String:
	match WeekCardModel.kind_of(events):
		WeekCardModel.Kind.REVIEW:
			return REVIEW_CAPTION
		WeekCardModel.Kind.MALUS:
			return CAPTION
		WeekCardModel.Kind.BOON:
			return ", ".join(names(InspectionDefinition.boons(events)))
	return NO_EVENT


## A day's tint (v0.70): green for a boon day, tomato pale for an inspection, mustard pale for a
## Manager's review, grey light for a day without an event.
static func tint_of(kind: WeekCardModel.Kind) -> Color:
	match kind:
		WeekCardModel.Kind.BOON:
			return Palette.GREEN_LIGHT
		WeekCardModel.Kind.REVIEW:
			return Palette.MUSTARD_LIGHT
		WeekCardModel.Kind.NONE:
			return Palette.GREY_LIGHT
	return Palette.TOMATO_PALE


## The inspections' names, indexed like the shift's inspections, for the receipt.
static func names(inspections: Array[InspectionDefinition]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		result.append(inspection.display_name)
	return result


## The day's bonus ticket for `run` (#77 machine v2): PROMISED in planning when passing the shift
## earns it (RewardMachine.bonus_if_passed), EARNED at the machine once the count-up is over when
## the pass earned it (bonus_earned); while `counting`, the chip keeps its `shown` state (as
## planning left it). A payday's two PREMIUM tickets (v0.68) are the PREMIUM announce's and the
## machine's banner: the chip shows no bonus pill for them.
static func bonus_for(run: RunState, counting: bool, shown: Bonus) -> Bonus:
	if run.machine == null:
		return Bonus.NONE
	if RunState.MACHINE_PHASES.has(run.phase):
		if counting:
			return shown
		var payday: bool = run.machine.machine.is_payday_shift(run.history[-1].shift)
		return Bonus.EARNED if run.machine.bonus_earned(run) and not payday else Bonus.NONE
	if Payday.if_passed(run):
		return Bonus.NONE
	if run.phase == RunState.Phase.PLANNING and run.machine.bonus_if_passed(run):
		return Bonus.PROMISED
	return Bonus.NONE


## The notice for the next shift's day events, or "" when it has none: its inspections' (a
## Manager's review's several, v0.65, named all), then its boon's (v0.69: "TOMORROW: Quiet
## morning (quota −10%)", in green when it is the only event).
static func next_notice(next_inspections: Array[InspectionDefinition]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var maluses: Array[InspectionDefinition] = InspectionDefinition.maluses(next_inspections)
	if not maluses.is_empty():
		var notices: PackedStringArray = PackedStringArray()
		for inspection: InspectionDefinition in maluses:
			notices.append(inspection.notice_text)
		var notice: String = NEXT_REVIEW_NOTICE if maluses.size() > 1 else NEXT_NOTICE
		parts.append(notice % " · ".join(notices))
	var boons: Array[InspectionDefinition] = InspectionDefinition.boons(next_inspections)
	if not boons.is_empty():
		parts.append(NEXT_BOON_NOTICE % ", ".join(boon_texts(boons)))
	return " · ".join(parts)


## Each boon's "<name> (<effect>)" (its chip_text; the name alone without one).
static func boon_texts(boons: Array[InspectionDefinition]) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for boon: InspectionDefinition in boons:
		var effect: String = boon.chip_text
		texts.append(
			BOON_TEXT % [boon.display_name, effect] if not effect.is_empty() else boon.display_name
		)
	return texts
