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
const SPEND_WORD := "QUOTA"
const SPEND_AMOUNT := "%d€"
## The status line.
const TO_GO := "%d€ to go"
const OVER := "+%d€ over"
const ON_QUOTA := "on quota"
const PLANNED_OVER := "+%d€ planned"
## Under the quota planning reads the count's words (the top bar's "to go" too).
const PLANNED_SHORT := TO_GO
## The item column on an empty belt (nothing in slot 1, nothing held).
const EMPTY_BELT := "Drag cards into the row"
## A hand item's note in the item column's effect rows (PR #138 monitor): it has no effects yet.
const HAND_NOTE := "Put it in the row to see what it does"
## The scanner bay's status plate in planning (PR #138 monitor): a pinned scan, else the last item
## placed on the belt.
const SCAN_COMPLETE := "SCAN COMPLETE"
const ON_BELT := "ON THE BELT"
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
## A step line's amount kept at its start ("+1€ Eggs before it", "×2 Eggs", "−2€ Late delivery").
const LEADING_AMOUNT := ["+", "×", "−"]
## A PAYOUT_OVERRIDE step's amount on the receipt ("= 0"): the item column shows it as euros.
const OVERRIDE_PREFIX := "="
## A copy (Repeat), the user's point A of 2026-11-05: the copier's scan names its source and the
## copied amount ("Copied from Golden Milk", "264€" on the amounts' column, the dotted leader
## between them), the source's scan a quiet note under its total instead of a "gives" row.
const COPIED_FROM := "Copied from %s"
const COPIED_BY := "Copied by %s"
## A tag's row (tag_line, v1.36): the item, then the family it gains as a chip word.
const TAG_LINE := "%s +%s"
## A "gives" row's equation (equation): the operators it spells out, its "=", and the change alone
## for an effect that is no arithmetic.
const EQUATION_SIGNS: Array[String] = ["×", "+", "−", "-"]
const EQUATION_EQUALS := "="
const EQUATION_CHANGE := "%s %s %s"


## A whole-euro amount with the € after it: "26€".
static func euros(amount: int) -> String:
	return EUROS % amount


## A whole-euro amount with its sign, as a step line starts: "+3€", or "−2€" for a fall (v0.69:
## Late delivery's). Every price puts its € after the number ("80€ everywhere", 2026-11-03).
static func signed_euros(amount: int) -> String:
	return gain(amount)


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


## A COPY step's line on its copier's scan: "Copied from Golden Milk  264€" (step_parts: the text,
## then the copied amount).
static func copied_from(source: String, amount: int) -> String:
	return ReceiptView.joined_line(COPIED_FROM % source, euros(amount))


## A TAG_ADDED step's row (v1.36, polish audit): the item `item` and the family `tag` it gains as
## a chip word, "Squashed cake +BREAKFAST"; the row's giver glyph names the sticker. (The
## receipt's "Breakfast sticker: Squashed cake gains Breakfast" wrapped on the monitor.)
static func tag_line(item: String, tag: String) -> String:
	return TAG_LINE % [item, tag.to_upper()]


## The quiet note beside a copied item's total: "Copied by Repeat", "" when nothing copied it.
static func copied_by(copier: String) -> String:
	return COPIED_BY % copier if not copier.is_empty() else ""


## A "gives" row's equation under its effect (v1.11, the user's "Put 2€ × 2 = 4€ directly under to
## Banana"): the target's price before, each of `effects` ("×2", "+3€", "−2€") as its operator and
## its number, then "=" and the price after: "2€ × 2 = 4€", "4€ + 3€ = 7€". An effect that is no
## arithmetic (an override's "=0") says the change alone, "17€ `arrow` 0€".
static func equation(before: int, effects: PackedStringArray, after: int, arrow: String) -> String:
	var parts: PackedStringArray = PackedStringArray([euros(before)])
	for effect: String in effects:
		var operator: String = effect.left(1)
		if not operator in EQUATION_SIGNS:
			return EQUATION_CHANGE % [euros(before), arrow, euros(after)]
		parts.append(operator)
		parts.append(effect.substr(1))
	parts.append(EQUATION_EQUALS)
	parts.append(euros(after))
	return " ".join(parts)


## A step line (ReceiptView.step_line, or a scan's "gives" line) as its text and its amount for
## the item column: an amount after two spaces ("cause  WASTED") or at its start ("+1€ Eggs before
## it" reads "Eggs before it" with "+1€"; "×2 Eggs" keeps its factor in the text and shows it as
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


## A step line as the item column's row shows it (step_parts), its amount said once (#138
## review): a factor shows only as the amount ("×3 Multipack" reads "Multipack" with "×3"); an
## override's "= N" reads "N€" (no equation over the payout's "= N€"); a text that already ends
## in its amount ("Bakery festival: Bakery +2€") loses it there, and one that says it in words
## ("Spot check: slot 3 pays 0€") keeps it, the amount left out. Returns [text, amount].
static func row_parts(line: String) -> PackedStringArray:
	var parts: PackedStringArray = step_parts(line)
	if parts[0].begins_with(LEADING_AMOUNT[1]) and not parts[1].is_empty():
		var gap: int = parts[0].find(" ")
		if gap > 0:
			parts[0] = parts[0].substr(gap + 1)
	var amount: String = parts[1]
	var override: bool = amount.begins_with(OVERRIDE_PREFIX)
	if override:
		amount = amount.substr(OVERRIDE_PREFIX.length()).strip_edges()
		if amount.is_valid_int():
			amount = euros(int(amount))
	parts[1] = amount
	if amount.is_empty() or not parts[0].ends_with(" " + amount):
		return parts
	if override:
		parts[1] = ""
	else:
		parts[0] = parts[0].left(parts[0].length() - amount.length()).strip_edges()
	return parts
