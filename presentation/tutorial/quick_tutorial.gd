class_name QuickTutorial
extends Resource
## One quick tutorial (data/tutorial/quick_*.tres; the mock-up docs/art/mockups/tutorial.html,
## its QUICK steps): 2 to 4 steps, once per profile (TutorialFlags.quick(id)), the first time a
## start screen mechanic unlocks. It waits until every page 1 booster is open (BADGE PINS: until
## page 2 opens). Its callouts read "NEW · <title>" and "n/total". A step whose ring asks for a
## free move waits for it; when the player backs out (the step's back_out_on), the rest waits for
## the first time they make the move.

## What makes it due.
## A run start after the first completed aisle, every page 1 booster open (swap UI A).
const SWAP_UNLOCKED := &"swap_unlocked"
## A run start after restock_min_completed completed aisles, every page 1 booster open.
const RESTOCK_UNLOCKED := &"restock_unlocked"
## A run start with a badge pin earned: page 2 opens on the pins step.
const PINS_EARNED := &"pins_earned"
const TRIGGERS: Array[StringName] = [SWAP_UNLOCKED, RESTOCK_UNLOCKED, PINS_EARNED]
## The quick tutorials' files.
const PATHS: Array[String] = [
	"res://data/tutorial/quick_swap.tres",
	"res://data/tutorial/quick_restock.tres",
	"res://data/tutorial/quick_pins.tres",
]

## TutorialFlags.QUICK_SWAP, QUICK_RESTOCK or QUICK_PINS (also its `quick_step` log's tutorial).
@export var id: StringName = &""
@export var title: String = ""
## When several are due on one run start, the lower plays first (SWAP, RESTOCK, BADGE PINS).
@export var order: int = 0
@export var trigger: StringName = &""
## The page MORE › opens (TipDefinition.TOYS_PREFIX: the toys book's), or empty.
@export var more_page: StringName = &""
@export var steps: Array[TutorialStep] = []


## Every quick tutorial, in play order (`order`).
static func all() -> Array[QuickTutorial]:
	var found: Array[QuickTutorial] = []
	for path: String in PATHS:
		found.append(load(path) as QuickTutorial)
	found.sort_custom(func(a: QuickTutorial, b: QuickTutorial) -> bool: return a.order < b.order)
	return found


## The step `step_id`, or null.
func step(step_id: StringName) -> TutorialStep:
	for each: TutorialStep in steps:
		if each.id == step_id:
			return each
	return null


## Whether MORE › opens the toys book rather than the HANDBOOK.
func more_in_toys() -> bool:
	return String(more_page).begins_with(TipDefinition.TOYS_PREFIX)
