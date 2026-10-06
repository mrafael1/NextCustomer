class_name ScoreStep
extends RefCounted
## One explanation line of a score. The preview, the receipt, the count-up and the tests all
## read the same steps, so they can never disagree.
##
## Order: context-pass steps (TAG_ADDED, LINKED, and WASTED for stickers or connectors that
## did nothing) come first. Then each slot in turn: BASE, FLAT, MULTIPLIER, COPY,
## PAYOUT_OVERRIDE, PAYOUT, then any WASTED step for that card. WASTED steps for effects that
## never found a target (a lost Coffee bonus, unused Egg charges) come last, or at the moment
## a later card replaces the effect (an Egg reset).

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
}

var step_type: StepType = StepType.BASE
## Slot whose value or context changes. WASTED: the slot of the card whose effect fizzled.
var slot: int = -1
## Slot of the card that caused the change (the same slot for a card's own rules).
## WASTED: the card whose effect fizzled, or for an Egg-style reset, the card that reset it.
var source_slot: int = -1
## BASE: base value. FLAT and COPY: amount added. MULTIPLIER: factor.
## PAYOUT_OVERRIDE and PAYOUT: the payout. TAG_ADDED, LINKED and WASTED: 0.
var value: int = 0
## The slot's running value after this step. WASTED steps carry the card's payout if it has
## been scanned, and 0 before that (context-pass fizzles).
var value_after: int = 0
## The row subtotal after this step. It changes only on PAYOUT steps.
var subtotal: int = 0
## Who caused it, for the receipt: a card name or a rule's receipt text.
var text: String = ""
## TAG_ADDED: the tag that was added. Otherwise empty.
var tag: String = ""
## LINKED: the product slot now counted as adjacent to `slot`. COPY: the slot whose payout
## was copied. Otherwise -1.
var linked_slot: int = -1
## WASTED: why the effect did nothing, e.g. "no Breakfast product after it". Otherwise empty.
var reason: String = ""


func to_dictionary() -> Dictionary:
	return {
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
	}
