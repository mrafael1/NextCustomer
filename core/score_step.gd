class_name ScoreStep
extends RefCounted
## One explanation line of a score. The preview, the receipt, the count-up and the tests all
## read the same steps, so they can never disagree.
##
## Order: context-pass steps (TAG_ADDED, LINKED, WRITTEN_OFF, and WASTED for stickers or connectors
## that did nothing) come first. Then each slot in turn: BASE, FLAT (the card's own, effects,
## upgrades, then the shift's day events, v0.69), MULTIPLIER (the card's own, then effects), COPY,
## MULTIPLIER (upgrades, then day events), PAYOUT_OVERRIDE (the card's own, then inspections, plan
## section 3.9), PAYOUT, then one EFFECT_ARMED for each effect the card arms for later cards, then
## any WASTED step for that card's own rules, then WASTED steps for upgrades, then day events, that
## had nothing to multiply there (plan section 3.8). An effect that replaces an earlier one (an Egg
## reset) is armed first, then the replaced effect's WASTED step follows at once. WASTED steps for
## effects that never found a target (a lost Coffee bonus, unused Egg charges) come next, then one
## WASTED step for each upgrade whose condition the row never met (#45: no coupon for the Coupon
## engine, too few cards for the Slot engine), on the row's last slot, then one for each day event
## that found nothing to boost (v0.69: Free samples with no product), last. An armed effect that
## later fizzles keeps its EFFECT_ARMED step.
##
## Every step has a source: a card (SourceKind.CARD, the card in source_slot), a register
## upgrade (SourceKind.UPGRADE, entry source_index of the run's upgrades) or an inspection
## (SourceKind.INSPECTION, entry source_index of the shift's inspections). Consumers branch on
## source_kind and never read a special source_slot value as "not a card".

enum StepType {
	BASE,
	FLAT,
	MULTIPLIER,
	COPY,
	PAYOUT_OVERRIDE,
	PAYOUT,
	TAG_ADDED,
	LINKED,
	WASTED,
	EFFECT_ARMED,
	## A perk's credit (#108 piece 2): what a perk with no scoring rule earned, a label only. Its
	## value is the credited slot's payout, already in the total; value_after is that payout too.
	CREDIT,
	## A written-off product (v1.29, Write-off): a context-pass label on the product the coupon
	## writes off, which counts as WASTED for every rule that reads WASTED items (ScoreState.wasted)
	## without being a fizzle. Value 0, like TAG_ADDED; source_slot is the Write-off.
	WRITTEN_OFF,
}

enum SourceKind {
	CARD,
	UPGRADE,
	INSPECTION,
}

var step_type: StepType = StepType.BASE
## Slot whose value or context changes. WASTED: the slot of the card whose effect fizzled.
## EFFECT_ARMED: the slot of the card that armed the effect.
var slot: int = -1
## What caused the step. CARD: the card in source_slot. UPGRADE and INSPECTION: entry
## source_index of the run's upgrades or the shift's inspections; source_slot is then not a
## source.
var source_kind: SourceKind = SourceKind.CARD
## CARD sources: the slot of the card that caused the change (the same slot for a card's own
## rules). WASTED: the card whose effect fizzled, or for an Egg-style reset, the card that
## reset it. EFFECT_ARMED: the card that armed the effect. Read as a source only when
## source_kind is CARD; UPGRADE and INSPECTION steps set it to `slot`, so it is never a -1
## sentinel.
var source_slot: int = -1
## UPGRADE and INSPECTION sources: index into the run's upgrades or the shift's inspections.
## CARD sources: 0 and unused (the card is source_slot).
var source_index: int = 0
## BASE: base value. FLAT and COPY: amount added. MULTIPLIER: factor.
## PAYOUT_OVERRIDE and PAYOUT: the payout. EFFECT_ARMED: the armed effect's amount (a flat
## bonus) or factor (a multiplier), from the rule's data. TAG_ADDED, LINKED, WRITTEN_OFF and
## WASTED: 0.
var value: int = 0
## The slot's running value after this step. WASTED steps carry the card's payout if it has
## been scanned, and 0 before that (context-pass fizzles). EFFECT_ARMED: the arming card's
## payout, unchanged.
var value_after: int = 0
## The row subtotal after this step. It changes only on PAYOUT steps.
var subtotal: int = 0
## Who caused it, for the receipt: a card name or a rule's receipt text. EFFECT_ARMED: the
## effect's receipt text, the same text as the FLAT, MULTIPLIER or WASTED steps it causes.
var text: String = ""
## TAG_ADDED: the tag that was added. Otherwise empty.
var tag: String = ""
## LINKED: the product slot now counted as adjacent to `slot`. COPY: the slot whose payout
## was copied. Otherwise -1.
var linked_slot: int = -1
## WASTED: why the effect did nothing, e.g. "no Breakfast product after it". CREDIT: what the
## perk did for the slot ("slot 8", "redrawn in"). Otherwise empty.
var reason: String = ""
## WASTED: true for an upgrade whose condition the row never met (#45), which sits on the row's
## last slot without being that item's own fizzle: the item marks (the receipt's slot mark, the
## belt's corner disc) skip it. False for every other step.
var row_wide: bool = false

## A neighbouring card enabling an own flat bonus. Explain-only visual provenance: the rule's
## source_kind/source_slot attribution and every scoring value stay unchanged.
var support_slot: int = -1
## MULTIPLIER and EFFECT_ARMED: a fractional factor in percent (#128 v3, Stale popcorn: 150 is
## ×1.5), or 0 for a whole one. `value` then holds the factor rounded half up (×2 for ×1.5), for
## any reader that wants a whole number; factor_text() is the factor's words.
var percent: int = 0


## `value` × `factor_percent` / 100, rounded to the nearest whole euro, halves away from zero
## (the user's call, #128 v3: 10.5 pays 11). Integers only, so scoring stays exact.
static func times_percent(amount: int, factor_percent: int) -> int:
	@warning_ignore("integer_division")
	var magnitude: int = (absi(amount) * factor_percent + 50) / 100
	return magnitude if amount >= 0 else -magnitude


## A factor in percent as words: 150 is "1.5", 175 "1.75", 200 "2".
static func percent_text(factor_percent: int) -> String:
	@warning_ignore("integer_division")
	var whole: int = factor_percent / 100
	var cents: int = factor_percent % 100
	if cents == 0:
		return str(whole)
	if cents % 10 == 0:
		@warning_ignore("integer_division")
		return "%d.%d" % [whole, cents / 10]
	return "%d.%02d" % [whole, cents]


## A multiplier's factor as words, without the ×: "2", or "1.5" for a fractional one.
func factor_text() -> String:
	return percent_text(percent) if percent > 0 else str(value)


## A multiplier's factor with its ×: "×2", "×1.5".
func times_text() -> String:
	return "×" + factor_text()


func card_giver_slot() -> int:
	return support_slot if support_slot >= 0 else source_slot


## A copy with every slot `slots` further on (a slot of -1 stays -1) and the subtotal `add`
## higher (ScoreResult.joined and continued, #122).
func moved(slots: int, add: int) -> ScoreStep:
	var copy: ScoreStep = ScoreStep.new()
	for property: Dictionary in get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			copy.set(property["name"], get(property["name"]))
	for key: String in ["slot", "source_slot", "linked_slot", "support_slot"]:
		var at: int = get(key)
		if at >= 0:
			copy.set(key, at + slots)
	copy.subtotal = subtotal + add
	return copy


func to_dictionary() -> Dictionary:
	var found: Dictionary = {
		"step_type": StepType.keys()[step_type],
		"slot": slot,
		"source_slot": source_slot,
		"value": value,
		"value_after": value_after,
		"subtotal": subtotal,
		"text": text,
		"tag": tag,
		"linked_slot": linked_slot,
		"reason": reason,
		"source_kind": SourceKind.keys()[source_kind],
		"source_index": source_index,
	}
	if percent > 0:
		found["percent"] = percent
	return found
