class_name ScoreStep
extends RefCounted
## One explanation line of a score. The preview, the receipt, the count-up and the tests all
## read the same steps, so they can never disagree.
##
## Order: context-pass steps (TAG_ADDED, LINKED, and WASTED for stickers or connectors that
## did nothing) come first. Then each slot in turn: BASE, FLAT (the card's own, effects, then
## upgrades), MULTIPLIER (the card's own, then effects), COPY, MULTIPLIER (upgrades),
## PAYOUT_OVERRIDE, PAYOUT, then one EFFECT_ARMED for each effect the card arms for later
## cards, then any WASTED step for that card's own rules, then WASTED steps for upgrades that
## had nothing to multiply there (plan section 3.8). An effect that replaces an earlier one (an
## Egg reset) is armed first, then the replaced effect's WASTED step follows at once. WASTED
## steps for effects that never found a target (a lost Coffee bonus, unused Egg charges) come
## last. An armed effect that later fizzles keeps its EFFECT_ARMED step.
##
## Every step has a source: a card (SourceKind.CARD, the card in source_slot) or a register
## upgrade (SourceKind.UPGRADE, entry source_index of the run's upgrades). Inspections (full
## build) will use source_index too. Consumers branch on source_kind and never read a special
## source_slot value as "not a card".

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
## source_index of the run's upgrades or inspections; source_slot is then not a source.
var source_kind: SourceKind = SourceKind.CARD
## CARD sources: the slot of the card that caused the change (the same slot for a card's own
## rules). WASTED: the card whose effect fizzled, or for an Egg-style reset, the card that
## reset it. EFFECT_ARMED: the card that armed the effect. Read as a source only when
## source_kind is CARD; UPGRADE steps set it to `slot`, so it is never a -1 sentinel.
var source_slot: int = -1
## UPGRADE and INSPECTION sources: index into the run's upgrades or inspections. CARD sources:
## 0 and unused (the card is source_slot).
var source_index: int = 0
## BASE: base value. FLAT and COPY: amount added. MULTIPLIER: factor.
## PAYOUT_OVERRIDE and PAYOUT: the payout. EFFECT_ARMED: the armed effect's amount (a flat
## bonus) or factor (a multiplier), from the rule's data. TAG_ADDED, LINKED and WASTED: 0.
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
		"source_kind": SourceKind.keys()[source_kind],
		"source_index": source_index,
	}
