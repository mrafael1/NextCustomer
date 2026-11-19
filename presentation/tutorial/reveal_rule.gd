class_name RevealRule
extends Resource
## One line of the week 1 strip (v1.40, data/tutorial/reveals.tres): the HUD element it reveals
## and what reveals it. On a guided run's first week the element stays hidden until one of its
## rules holds, then stays shown for the rest of the run (RunState.guide_reveals). An element may
## have several rules: any of them reveals it. Pure data; RevealList reads it.

## The element (a RevealList element id: the TutorialAnchors id of its control).
@export var element: StringName = &""
## The triggers that reveal it (TutorialEvents ids, or RevealList's own: SHIFT_PASSED,
## QUOTA_REACHED, MEDAL_REACHED, DAY_EVENT, PERK_OWNED); empty: none.
@export var events: Array[StringName] = []
## The first shift (1-based) `events` count on.
@export var events_from_shift: int = 1
## It is revealed once this shift's planning takes input (1-based); 0: never by the shift alone.
@export var at_shift: int = 0


## Whether it holds on shift `shift` (1-based) as the triggers `happened` come in; `planned` is
## the last shift whose planning took input.
func holds(shift: int, planned: int, happened: Array[StringName]) -> bool:
	if at_shift > 0 and planned >= at_shift:
		return true
	if shift < events_from_shift:
		return false
	for event: StringName in events:
		if happened.has(event):
			return true
	return false
