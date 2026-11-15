class_name TutorialScript
extends Resource
## The guided first run's script (data/tutorial/guided.tres): its steps G1-G26 in play order and
## the shift 1 hand they ring (the mock-up docs/art/mockups/tutorial.html, its GUIDED steps).
## The hand's place order must be the scripted deal's (GuidedStartDefinition's hand), so a ring
## on hand<p> finds its card.

const PATH := "res://data/tutorial/guided.tres"

@export var steps: Array[TutorialStep] = []
## The shift 1 hand, by place (card definition ids; places 2b and 2b + 1 are basket b).
@export var hand: Array[StringName] = []


## The guided script (data/tutorial/guided.tres).
static func guided() -> TutorialScript:
	return load(PATH) as TutorialScript


## The step `step_id`, or null.
func step(step_id: StringName) -> TutorialStep:
	var at: int = index_of(step_id)
	return steps[at] if at >= 0 else null


## Step `step_id`'s line as written (its {placeholders} unfilled), or "" when there is no such step.
func line(step_id: StringName) -> String:
	var found: TutorialStep = step(step_id)
	return found.text if found != null else ""


## The index of step `step_id` in play order, or -1.
func index_of(step_id: StringName) -> int:
	for k: int in steps.size():
		if steps[k].id == step_id:
			return k
	return -1


## The first planning step whose expected row is `row` (card definition ids, slot order), or
## null: after a move, and on a resume, the step to play.
func for_row(row: Array[StringName]) -> TutorialStep:
	for each: TutorialStep in steps:
		if each.row_matches(row):
			return each
	return null


## The hand place of card `card_id` (the first one at or after `from`), or -1.
func place_of(card_id: StringName, from: int = 0) -> int:
	for place: int in range(maxi(from, 0), hand.size()):
		if hand[place] == card_id:
			return place
	return -1
