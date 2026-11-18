class_name TipDefinition
extends Resource
## One one-time tip (T1-T16, the mock-up docs/art/mockups/tutorial.html, its TIPS): shown once
## per profile (TutorialFlags.tip(id)), the first time its trigger happens, never during the
## count-up or over the machine's draw, at most 2 per planning in `priority` order (lower first).
## Its card reads "NEW · <title>" and "ONCE", its line, MORE › <more_page> and GOT IT.

## What makes it due (the tip scheduler watches for it).
## The shift's planning (min_shift and later).
const PLANNING := &"planning"
## A planning with a day event (GOOD DAY or INSPECTION).
const DAY_EVENT := &"day_event"
## A PAYDAY shift's planning.
const PAYDAY := &"payday"
## The first planning of week 2 (training week is over).
const WEEK_TWO := &"week_two"
## A coupon in the baskets.
const COUPON_IN_HAND := &"coupon_in_hand"
## A card in the baskets whose rule names a family other than Food.
const FAMILY_RULE := &"family_rule"
## A Bakery card with BATCH in the baskets.
const BATCH_IN_HAND := &"batch_in_hand"
## PROJECTED reaches the SILVER medal's laps of the quota.
const MEDAL_REACH := &"medal_reach"
## A PREMIUM machine visit.
const PREMIUM_VISIT := &"premium_visit"
## A missed quota the training week forgives.
const FIRST_MISS := &"first_miss"
## A loyalty perk taken at the machine.
const PERK_TAKEN := &"perk_taken"
## An IMPROVE prize applied.
const IMPROVE_TAKEN := &"improve_taken"
## The results of a lost run.
const RUN_LOST := &"run_lost"
## A run end that pays coins.
const COINS_PAID := &"coins_paid"
## The HANDBOOK opened.
const HANDBOOK_OPENED := &"handbook_opened"
const TRIGGERS: Array[StringName] = [
	PLANNING,
	DAY_EVENT,
	PAYDAY,
	WEEK_TWO,
	COUPON_IN_HAND,
	FAMILY_RULE,
	BATCH_IN_HAND,
	MEDAL_REACH,
	PREMIUM_VISIT,
	FIRST_MISS,
	PERK_TAKEN,
	IMPROVE_TAKEN,
	RUN_LOST,
	COINS_PAID,
	HANDBOOK_OPENED,
]
## A more_page that names a page of the toys book (the figurine book) instead of the HANDBOOK.
const TOYS_PREFIX := "toys:"

## T1-T16 (also its flag, TutorialFlags.tip(id), and its `tip_shown` log id).
@export var id: StringName = &""
## The card's title, after "NEW · ".
@export var title: String = ""
## 1 shows first (DAY EVENT), 6 last.
@export var priority: int = 0
@export var trigger: StringName = &""
## The first shift its trigger counts on (0: any).
@export var min_shift: int = 0
## The line, with `**WORD**` chips and `{name}` placeholders (TutorialText).
@export_multiline var text: String = ""
## The line when the live fill finds nothing to name (T14), else empty.
@export_multiline var fallback_text: String = ""
@export var teaches: PackedStringArray = PackedStringArray()
## What is ringed (TutorialAnchors ids); indexed ones are templates when `follow_index`.
@export var rings: Array[StringName] = []
@export var point: int = 0
@export var side: TutorialStep.CalloutSide = TutorialStep.CalloutSide.AUTO
## Indexed rings are templates: the scheduler puts in the slot, hand place or basket of the card
## that made the tip due (T2's coupon, T3's card, T4's removed).
@export var follow_index: bool = false
## The HANDBOOK entry MORE › opens (a TOYS_PREFIX id: the toys book's page), or empty for none.
@export var more_page: StringName = &""


## Whether MORE › opens the toys book rather than the HANDBOOK.
func more_in_toys() -> bool:
	return String(more_page).begins_with(TOYS_PREFIX)
