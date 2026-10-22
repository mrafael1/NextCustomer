class_name EffectLink
extends RefCounted
## One effect between a cause and the item it acts on (#71's planning effects), read from one
## ScoreStep by EffectGraph. Pure data: it never scores.
##
## Kinds, by step: FLAT is a BONUS, MULTIPLIER a STAMP, COPY a COPY (caused by the copied card,
## linked_slot), PAYOUT_OVERRIDE is DENIED (an inspection, or the card itself for Soup), WASTED
## a FIZZLE on the card whose effect fizzled (caused by an upgrade, by the resetting card for a
## reset, else by the card itself) and EFFECT_ARMED an ARMED pip on the arming card, with its
## landings from EffectLinks. TAG_ADDED and LINKED give no link.

enum Kind { BONUS, STAMP, COPY, DENIED, FIZZLE, ARMED }

## The one word every WASTED step shows (#45, decided with the user): a FIZZLE's sticker on the
## belt and in the scanner bay, the count-up's puff, the receipt's and monitor's fizzle lines and
## the receipt's count ("2 WASTED"). A failed condition and a wasted effect read the same.
const WASTED_WORD := "WASTED"

var kind: Kind = Kind.BONUS
## The slot the effect shows on: the step's `slot` (ARMED: the arming card).
var target_slot: int = -1
## What caused it: a card (cause_slot), an upgrade or an inspection (cause_index).
var cause_kind: ScoreStep.SourceKind = ScoreStep.SourceKind.CARD
## CARD causes: the causing card's slot; otherwise -1.
var cause_slot: int = -1
## UPGRADE and INSPECTION causes: the index into the run's upgrades or the shift's inspections;
## otherwise -1.
var cause_index: int = -1
## The step's index in ScoreResult.steps.
var step_index: int = -1
## BONUS and STAMP: the EFFECT_ARMED step it lands from. FIZZLE: the EFFECT_ARMED step it
## fizzles. ARMED: its own step. Otherwise -1.
var armed_step: int = -1
## The step's value: the amount, the factor, the copied or overridden payout, the armed value.
var value: int = 0
## Short wording: "+3", "×3", "=€6", "€0", WASTED_WORD; ARMED: its first landing's "×3" or "+3", or
## the effect's receipt text without a landing (as the count-up's pip).
var token: String = ""
## The step's receipt text.
var text: String = ""
## FIZZLE: why it did nothing. Otherwise empty.
var reason: String = ""
## Caused by the card it shows on (a card's own bonus, a Soup's override, a card rule's own
## fizzle, an armed pip).
var own: bool = false
## ARMED: the step indices of its landings, in step order.
var landings: PackedInt32Array = PackedInt32Array()
## ARMED: the slots of its landings, in step order.
var landing_slots: PackedInt32Array = PackedInt32Array()
## ARMED: some of it fizzled (a FIZZLE link points back at it).
var fizzled: bool = false
## BONUS, STAMP and COPY: what the step added to its slot's running value (its `value_after`
## minus the previous value-carrying step's on that slot: BASE, FLAT, MULTIPLIER, COPY or
## PAYOUT_OVERRIDE); otherwise 0. Read from the steps (h1's rail-strip gains): it scores nothing.
var gain: int = 0
## A later PAYOUT_OVERRIDE on the same slot replaced the value this link changed (a denial), so
## it didn't reach the payout.
var cancelled: bool = false


## Whether `slot` is this link's causing card.
func caused_by_card(slot: int) -> bool:
	return cause_kind == ScoreStep.SourceKind.CARD and cause_slot == slot
