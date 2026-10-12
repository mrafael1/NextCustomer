class_name CountUpBeat
extends RefCounted
## One beat of a CountUpPlan: one or two ScoreSteps the count-up plays as one moment, with its
## note, length, hit-stop, roll and rattle already decided (#60, D1 to D8). Built by
## CountUpPlan only; the count-up reads it and never recomputes it.

enum Kind {
	## A plain card's BASE and PAYOUT as one beat (D2).
	MERGED_PLAIN,
	## BASE on a card that is not plain.
	BASE,
	## FLAT or COPY.
	BONUS,
	## MULTIPLIER.
	STAMP,
	## PAYOUT_OVERRIDE.
	DENIED,
	PAYOUT,
	## EFFECT_ARMED.
	ARMED,
	## WASTED.
	FIZZLE,
	## TAG_ADDED.
	TAG,
	## LINKED.
	LINK,
}

var kind: Kind = Kind.BASE
## Indices into ScoreResult.steps, in step order: two for MERGED_PLAIN, one otherwise.
var steps: PackedInt32Array = PackedInt32Array()
## The slot of the beat's step (ScoreStep.slot).
var slot: int = -1
## The ladder note this beat plays (D1), or -1 for none.
var note: int = -1
## The note plays quietly (an ARMED beat replaying the current note without stepping).
var note_quiet: bool = false
## Start to start at speed 1, after fitting, trailing gap included.
var duration_ms: int = 0
## Planned start at speed 1 from the start of the count-up, pre-roll included and hit-stops
## not (the timeline hit-stops merge on).
var start_ms: int = 0
## Real-time freeze when the beat lands (D6), after merging; 0 for none.
var hit_stop_ms: int = 0
## PAYOUT and MERGED_PLAIN: how long the subtotal rolls up, at speed 1. 0 otherwise.
var roll_ms: int = 0
## PAYOUT and MERGED_PLAIN: the payout. 0 otherwise.
var payout: int = 0
## The row subtotal after the beat.
var subtotal: int = 0
## Register rattle amplitude in px (D3); 0 for none and always 0 under reduced motion.
var rattle_px: float = 0.0
## Extra subtotal punch once the row has passed the best so far (D3).
var punch_boost: float = 0.0
## A repeat landing of an armed effect played as a short echo (D7 stage 2).
var echo: bool = false
## ARMED: the beat indices of its landings, in order (D8).
var targets: PackedInt32Array = PackedInt32Array()
## A landing: the index of the ARMED beat it belongs to, or -1.
var armed_from: int = -1
## The quota is reached on this beat, mid-row (D5).
var ding: bool = false
## The first multiplier from a card on this beat's card: it gets the card hit-stop and is never
## shortened by the fly-in or uniform fit stages (D6, D7).
var first_stamp_on_card: bool = false
