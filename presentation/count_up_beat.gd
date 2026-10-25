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
	## CREDIT (#108 piece 2): a perk's earnings, a label that changes no value.
	CREDIT,
}

## What a beat does to the monitor's total (#105 piece 2, mock-up readability_v3.html): nothing, the
## item's base lands, a +N or a × lands its gain, a denial lowers it, or WASTED drops a grey €0.
enum Land { NONE, BASE, ADD, MUL, DOWN, WASTE }

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
## Planned start at speed 1 from the start of the count-up, pre-roll and ride gaps included and
## hit-stops not (the timeline hit-stops merge on).
var start_ms: int = 0
## Real-time freeze when the beat lands (D6), after merging; 0 for none.
var hit_stop_ms: int = 0
## A landing (#105 piece 2): how long its ticks run, from the first to the last, at speed 1. 0
## otherwise (a payout no longer rolls the total).
var roll_ms: int = 0
## PAYOUT and MERGED_PLAIN: the payout. 0 otherwise.
var payout: int = 0
## The row subtotal after the beat.
var subtotal: int = 0
## Register rattle amplitude in px (D3); 0 for none and always 0 under reduced motion.
var rattle_px: float = 0.0
## A repeat landing of an armed effect played as a short echo (D7 stage 2).
var echo: bool = false
## ARMED: the beat indices of its landings, in order (D8).
var targets: PackedInt32Array = PackedInt32Array()
## A landing: the index of the ARMED beat it belongs to, or -1.
var armed_from: int = -1
## The quota is reached on this beat, mid-row (D5).
var ding: bool = false
## The ding beat's crossing tick (#105 piece 2): the index in `ticks` of the first one at or over
## the quota, where the quota is met and the climax starts; -1 on other beats.
var ding_tick: int = -1
## The first multiplier from a card on this beat's card: it gets the card hit-stop and is never
## shortened by the fly-in or uniform fit stages (D6, D7).
var first_stamp_on_card: bool = false
## The item at the scanner during this beat (#86 v6): the slot of its scan group's BASE or
## MERGED_PLAIN beat, or -1 for a context-pass beat before the first scan. A scan group runs
## from that beat to the beat before the next one; the last group takes the trailing beats.
var scan_slot: int = -1
## The first beat of a scan group: its item slides into the scanner before it.
var opens_slot: bool = false
## The last beat of a scan group: its item hops into the bag after it.
var closes_slot: bool = false
## An opening beat's ride gap, played before it at speed 1 (the tuning's ride_ms), or 0: none
## for item 0 already in the scanner's cell.
var ride_ms: int = 0
## How the beat lands on the monitor's total (#105 piece 2; CountUpPlan's _set_landings).
var land: Land = Land.NONE
## The total the monitor and the top bar show before and after the beat's landing, in whole
## euros: the payouts so far plus the running value of every item not yet paid. It always equals
## the step's subtotal at a PAYOUT, so the count ends on ScoreResult.total.
var shown_from: int = 0
var shown_to: int = 0
## shown_to - shown_from.
var gain: int = 0
## A × landing's factor as its chip first reads ("×2"), else "".
var factor_text: String = ""
## The landing's whole-euro ticks, in order (at most the tuning's ticks_per_landing; the last is
## shown_to). Empty for a beat that does not move the total.
var ticks: PackedInt32Array = PackedInt32Array()
## The ladder lamp a gain landing lights (its 0-based count among the row's gain landings), or -1.
var lamp: int = -1
## From the beat's start to its landing, at speed 1 (0 for a beat that does not land).
var fly_ms: int = 0
