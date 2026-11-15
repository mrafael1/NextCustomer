class_name TutorialScript
extends Resource
## The guided first run's script (data/tutorial/guided.tres): its steps in play order, the shift 1
## hand they ring, and the free planning's parts (play test 1, 2026-11-15): the retry and answer
## lines, the row the answer's ghosts show and the reactive hints. The hand's place order must be
## the scripted deal's (GuidedStartDefinition's hand), so a ring on hand<p> finds its card.
##
## Shift 1's planning: a few intro steps, then the free step (a PLANNING step with no line: the
## player builds the row, any move allowed). A CHECKOUT under the quota there is a rehearsal: the
## count plays, then planning comes back as it was, with `retry`'s line (`answer_step`'s from
## the ANSWER_AFTER-th miss on, and the `answer` row's ghosts on the belt).

const PATH := "res://data/tutorial/guided.tres"
## The misses after which the answer's ghosts show.
const ANSWER_AFTER := 2

@export var steps: Array[TutorialStep] = []
## The shift 1 hand, by place (card definition ids; places 2b and 2b + 1 are basket b).
@export var hand: Array[StringName] = []
## A row that reaches shift 1's quota (card definition ids, slot order): the answer's ghosts.
@export var answer: Array[StringName] = []
## The free planning's lines after a missed rehearsal: the first misses', then the answer's.
@export var retry: TutorialStep
@export var answer_step: TutorialStep
## The free planning's reactive hints, in their data order (PlanHint.pick).
@export var hints: Array[PlanHint] = []


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


## The free planning step's index (a PLANNING step with no line), or -1.
func free_index() -> int:
	for k: int in steps.size():
		if steps[k].is_free():
			return k
	return -1


## The hand place of card `card_id` (the first one at or after `from`), or -1.
func place_of(card_id: StringName, from: int = 0) -> int:
	for place: int in range(maxi(from, 0), hand.size()):
		if hand[place] == card_id:
			return place
	return -1
