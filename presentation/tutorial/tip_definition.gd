class_name TipDefinition
extends Resource
## One one-time tip (the mock-up docs/art/mockups/tutorial.html, its TIPS; cut from 16 to the 7
## a player can't find alone, v1.40: they keep their ids, T2, T6, T7, T9, T11, T14, T15; T17, the
## puzzles' unlock tip on the title, came with #183 polish 5): shown
## once per profile (TutorialFlags.tip(id)), the first time its trigger happens, never during the
## count-up or at the machine, at most 1 per planning in `priority` order (lower first). Its card
## reads "NEW · <title>" and "ONCE", its line, MORE › <more_page> and GOT IT.

## What makes it due (the tip scheduler watches for it).
## A planning with a day event (GOOD DAY or INSPECTION).
const DAY_EVENT := &"day_event"
## A PAYDAY shift's planning.
const PAYDAY := &"payday"
## A coupon in the baskets.
const COUPON_IN_HAND := &"coupon_in_hand"
## A missed quota the training week forgives.
const FIRST_MISS := &"first_miss"
## A loyalty perk taken at the machine.
const PERK_TAKEN := &"perk_taken"
## The results of a lost run.
const RUN_LOST := &"run_lost"
## A run end that pays coins.
const COINS_PAID := &"coins_paid"
## The title offers puzzles (#183 polish 5: the first finished run; TitlePuzzleTip shows it).
const PUZZLES_OFFERED := &"puzzles_offered"
const TRIGGERS: Array[StringName] = [
	DAY_EVENT, PAYDAY, COUPON_IN_HAND, FIRST_MISS, PERK_TAKEN, RUN_LOST, COINS_PAID, PUZZLES_OFFERED
]
## A more_page that names a page of the toys book (the figurine book) instead of the HANDBOOK.
const TOYS_PREFIX := "toys:"

## Its id, T<n> (also its flag, TutorialFlags.tip(id), and its `tip_shown` log id).
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
## Indexed rings are templates: the scheduler puts in the hand place of the card that made the
## tip due (T2's coupon).
@export var follow_index: bool = false
## The HANDBOOK entry MORE › opens (a TOYS_PREFIX id: the toys book's page), or empty for none.
@export var more_page: StringName = &""


## Whether MORE › opens the toys book rather than the HANDBOOK.
func more_in_toys() -> bool:
	return String(more_page).begins_with(TOYS_PREFIX)
