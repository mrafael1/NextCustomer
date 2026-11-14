class_name TutorialStep
extends Resource
## One step of the guided first run (G1-G26) or of a quick tutorial (R, P, SA): its line, what it
## rings and locks, how it moves on and what the player may do meanwhile (the mock-up
## docs/art/mockups/tutorial.html, its GUIDED and QUICK steps). Pure data: the director
## (TutorialDirector) reads it, the overlay draws it. Rings and locks name TutorialAnchors ids,
## never rects; actions and events name TutorialActions and TutorialEvents ids.
##
## The line (`text`) is written as the mock-up's: `**WORD**` is a glossary chip (TutorialText
## maps it to its TipWords box) and `{name}` a number or name TutorialText fills from data.

## Where the step shows (the director only plays a step on its screen).
enum Screen {
	TITLE,
	START_STOCK,
	START_BUILD,
	SWAP_WINDOW,
	PLANNING,
	MACHINE_CHOOSE,
	MACHINE_PICK,
	WEEK_CARD,
}
## Where the callout sits, next to the ring it points at (`point`); AUTO lets the overlay choose.
## The mock-up's arrow points the other way (its arrow "left" is a callout on the RIGHT).
enum CalloutSide { AUTO, LEFT, RIGHT, ABOVE, BELOW }
## The callout's footer: NEXT ›, GOT IT, or the "CLICK THE RING" hint (a step whose move is the
## ring's).
enum Footer { NEXT, GOT_IT, RING }
## OPEN: every action is allowed but `refuse_ids` (quick tutorials, which never force a move);
## ONLY: only the actions in `allow`, filtered by the allow_* lists (the guided run).
enum Gate { OPEN, ONLY }

## The step's id: G1-G26, R1-R4, P1-P4, SA1-SA4 (also its `tutorial_step` / `quick_step` log id).
@export var id: StringName = &""
@export var screen: Screen = Screen.TITLE
## The line, with `**WORD**` chips and `{name}` placeholders (TutorialText).
@export_multiline var text: String = ""
## The glossary words (TipWords keys) this step teaches (the line checker's order).
@export var teaches: PackedStringArray = PackedStringArray()
## What is ringed, in order (TutorialAnchors ids).
@export var rings: Array[StringName] = []
## The ring that is the player's move (its CLICK tab), or -1 for none.
@export var act: int = -1
## The ring the callout points at.
@export var point: int = 0
@export var side: CalloutSide = CalloutSide.AUTO
## What is locked (TutorialAnchors ids), each drawn with the LOCKED plate.
@export var locks: Array[StringName] = []
@export var footer: Footer = Footer.NEXT
## The event that moves the step on (TutorialEvents id); empty: its button does.
@export var advance_on: StringName = &""
## How many `advance_on` events it takes (G18: both Bananas placed; SA2: both boosters opened, or
## every one the window has when fewer).
@export var advance_count: int = 1
## The footer button moves it on too, besides `advance_on` (G17: the scan hold, or NEXT ›).
@export var or_button: bool = false
## A quick tutorial step's back-out event (TutorialEvents id): the rest waits for the real move.
@export var back_out_on: StringName = &""
## How long the callout waits before it shows, in seconds (R3: the cards land in the tote).
@export var delay_s: float = 0.0
@export var gate: Gate = Gate.OPEN
## The actions allowed (Gate.ONLY): TutorialActions ids.
@export var allow: Array[StringName] = []
## The HIT and SWAP ids allowed (Gate.ONLY; empty: any id).
@export var allow_ids: Array[StringName] = []
## The HIT and SWAP ids refused, whatever the gate.
@export var refuse_ids: Array[StringName] = []
## The cards (definition ids) that may be picked up from a basket or placed (empty: any).
@export var allow_cards: Array[StringName] = []
## The slots (0-based, compacted) a card may be placed at (empty: any).
@export var allow_slots: PackedInt32Array = PackedInt32Array()
## Whether `row_before` applies: a planning step of the guided shift plays only on that row.
@export var checks_row: bool = false
## The row (card definition ids, slot order) the step expects before its move: after any move,
## and on a resume, the director plays the first step whose row matches.
@export var row_before: Array[StringName] = []
## Indexed rings and locks are templates, their index taken from the event that opened the step
## (its ARG_INDEX, else ARG_SLOT, else ARG_BASKET): R3's restocked booster, SA4's swapped regular.
@export var follow_index: bool = false
## Booster rings already opened are dropped (G4: "open the other BOOSTER").
@export var sealed_only: bool = false


## Whether the player may do `action` (TutorialActions id, with its args) during this step. A
## placed card may always be picked back up (moving it back to its basket is never asked).
func allows(action: StringName, args: Dictionary = {}) -> bool:
	var by_id: bool = action in [TutorialActions.HIT, TutorialActions.SWAP]
	var asked_id: StringName = StringName(str(args.get(TutorialActions.ARG_ID, "")))
	if by_id and refuse_ids.has(asked_id):
		return false
	if gate == Gate.OPEN:
		return true
	if action == TutorialActions.PICK_CARD and bool(args.get(TutorialEvents.ARG_FROM_ROW, false)):
		return true
	var allowed: bool = allow.has(action)
	if allowed and by_id and not allow_ids.is_empty():
		allowed = allow_ids.has(asked_id)
	if allowed and action in [TutorialActions.PICK_CARD, TutorialActions.PLACE_CARD]:
		var card: StringName = StringName(str(args.get(TutorialEvents.ARG_CARD, "")))
		allowed = allow_cards.is_empty() or allow_cards.has(card)
	if allowed and action == TutorialActions.PLACE_CARD and not allow_slots.is_empty():
		allowed = allow_slots.has(int(args.get(TutorialEvents.ARG_SLOT, -1)))
	return allowed


## Whether its footer button moves it on (no event, or `or_button`).
func button_advances() -> bool:
	return advance_on.is_empty() or or_button


## Whether `row` (card definition ids, slot order) is the row this step expects.
func row_matches(row: Array[StringName]) -> bool:
	return checks_row and row == row_before
