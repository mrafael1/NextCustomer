class_name MonitorText
extends RefCounted
## The single monitor screen's wording (#105 piece 2, mock-up readability_v3.html, monitor b of
## readability_v2.html), so no view formats an amount itself. The checkout column's money is in
## whole euros with the € after the number (#86 and the monitor bay decisions: "26€+", "2€ to go",
## "+5€ over"); a step line keeps the receipt's wording, split into its text and its amount for
## the item column's right-hand amount column. Pure: every number is the caller's (a step's, the
## reading's or core's ShiftMargin).

## The checkout column's caption: TOTAL in the count, PLAN in planning.
const TOTAL_CAPTION := "TOTAL"
const PLAN_CAPTION := "PLAN"
## The SPEND line: the quota's word and its amount.
const SPEND_WORD := "SPEND"
const SPEND_AMOUNT := "%d€+"
## The status line.
const TO_GO := "%d€ to go"
const OVER := "+%d€ over"
const ON_QUOTA := "on quota"
const PLANNED_OVER := "+%d€ planned"
## Under the quota planning reads the count's words (the top bar's "to go" too).
const PLANNED_SHORT := TO_GO
## The item column on an empty belt (nothing in slot 1, nothing held).
const EMPTY_BELT := "Drag items onto the belt"
## A number with its €, a gain, a fall.
const EUROS := "%d€"
const GAIN := "+%d€"
const FALL := "−%d€"
## The gain box after a × lands: its factor, the arrow, its gain.
const GAIN_BOX := "%s %s %s"
## The arrow in the gain box when the font has one (→), else a chevron.
const ARROW := "→"
const ARROW_FALLBACK := "›"
## What separates a step line's text from its amount (ReceiptView.joined_line).
const AMOUNT_SEPARATOR := "  "
## A step line's amount kept at its start ("+€1 Eggs before it", "×2 Eggs", "−€2 Late delivery").
const LEADING_AMOUNT := ["+€", "×", "−€"]


## A whole-euro amount with the € after it: "26€".
static func euros(amount: int) -> String:
	return EUROS % amount


## A whole-euro amount with its sign, as a step line starts: "+€3", or "−€2" for a fall (v0.69:
## Late delivery's).
static func signed_euros(amount: int) -> String:
	return "+€%d" % amount if amount >= 0 else "−€%d" % -amount


## A landing's chip: "+N€" for a gain, "−N€" for a fall.
static func gain(amount: int) -> String:
	return (GAIN % amount) if amount >= 0 else (FALL % -amount)


## The SPEND line's amount: "26€+".
static func spend(quota: int) -> String:
	return SPEND_AMOUNT % quota


## The count's status under SPEND: "N€ to go" short of the quota, "+N€ over" past it, "on quota"
## on it (core's ShiftMargin of the shown amount).
static func status(amount: int, quota: int) -> String:
	var margin: ShiftMargin = ShiftMargin.of(amount, quota)
	match margin.kind():
		ShiftMargin.Kind.SHORT:
			return TO_GO % margin.amount()
		ShiftMargin.Kind.OVER:
			return OVER % margin.amount()
	return ON_QUOTA


## Planning's status: "+N€ planned" at or over the quota, "N€ to go" under it.
static func planned(amount: int, quota: int) -> String:
	var margin: ShiftMargin = ShiftMargin.of(amount, quota)
	if margin.passed():
		return PLANNED_OVER % margin.amount()
	return PLANNED_SHORT % margin.amount()


## The tab once met: "+N€" (the euros over; "+0€" on the quota).
static func over_tab(amount: int, quota: int) -> String:
	return GAIN % maxi(0, amount - quota)


## The gain box after a × lands: "×2 → +5€" (`arrow`: ARROW or ARROW_FALLBACK).
static func gain_box(factor: String, gained: int, arrow: String) -> String:
	return GAIN_BOX % [factor, arrow, gain(gained)]


## A WASTED step's line in the item column: its reason alone ("No Frozen product beside it"), the
## receipt's cause before it left out (the receipt keeps it; the item is the one in the bay), then
## WASTED as its amount, so the one line that says why fits beside the word.
static func waste_line(step: ScoreStep) -> String:
	var reason: String = step.reason.strip_edges()
	if reason.is_empty():
		return ReceiptView.joined_line(step.text, EffectLink.WASTED_WORD)
	return ReceiptView.joined_line(
		reason.left(1).to_upper() + reason.substr(1), EffectLink.WASTED_WORD
	)


## A step line (ReceiptView.step_line, or a scan's "gives" line) as its text and its amount for
## the item column: an amount after two spaces ("cause  WASTED") or at its start ("+€1 Eggs before
## it" reads "Eggs before it" with "+€1"; "×2 Eggs" keeps its factor in the text and shows it as
## the amount too). Returns [text, amount]; the amount is "" for none.
static func step_parts(line: String) -> PackedStringArray:
	var at: int = line.rfind(AMOUNT_SEPARATOR)
	if at >= 0:
		return PackedStringArray([line.left(at), line.substr(at + AMOUNT_SEPARATOR.length())])
	if line.begins_with(LEADING_AMOUNT[0]) or line.begins_with(LEADING_AMOUNT[2]):
		var space: int = line.find(" ")
		if space > 0:
			return PackedStringArray([line.substr(space + 1), line.left(space)])
	if line.begins_with(LEADING_AMOUNT[1]):
		var gap: int = line.find(" ")
		if gap > 0:
			return PackedStringArray([line, line.left(gap)])
	return PackedStringArray([line, ""])
