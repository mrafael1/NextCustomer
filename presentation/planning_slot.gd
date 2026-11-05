class_name PlanningSlot
extends RefCounted
## What one belt slot shows while planning (#71, mock-up h1, H1_BUILD_SPEC.md section 2): its
## stickers in apply order, the pay on its ticket, its halo and its denial stamp. Built by
## PlanningModel from the score's steps and payouts. Pure data: it never scores.

## The stickers, in step order (the first applied at the top of the stack).
var stickers: Array[StickerSpec] = []
## The ticket's pay state.
var pay: PlanningModel.Pay = PlanningModel.Pay.PLAIN
## The pay tag's text ("21€", "0€"); empty for PLAIN.
var pay_text: String = ""
## The pay in whole euros (the ticket's price window prints it); 0 for PLAIN.
var payout: int = 0
## The 0€ tag's glyph (DENIED and ZERO); none on a slot an inspection pays 0€ by its place, whose
## talker (SlotMark's cause-only chip) shows the warning sign.
var glyph: PlanningModel.Glyph = PlanningModel.Glyph.NONE
## The halo's rings: 0 unless boosted, then 1 to 3 (PlanningTuning.halo_ratios).
var rings: int = 0
## Denied to 0€: the sprite turns grey.
var denied: bool = false
## The denial stamp's big line ("0€"); empty when no stamp.
var stamp_amount: String = ""
## The denial stamp's caption: the denier's name in uppercase ("SPOT CHECK", "SOUP").
var stamp_caption: String = ""
## A batch or chain card's wrong job (#128): its BATCH or CHAIN line's WASTED tooltip ("WASTED ·
## Not first in its Bakery batch"), or "" when it works (or is neither).
var wrong_job: String = ""


## Whether the slot has a denial stamp.
func has_stamp() -> bool:
	return not stamp_amount.is_empty()
