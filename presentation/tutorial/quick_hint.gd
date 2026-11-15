class_name QuickHint
extends Resource
## One tip bubble of a quick tutorial (play test feedback, 2026-11-15: a quick tutorial is one
## NEW callout, then the player does it freely while these pop as each moment comes): it pops
## once, the first time the opening board sends `event` after its tutorial's callout showed, over
## anchor `anchor` (a TutorialAnchors id; "{index}" and "{slot}" take the event's ARG_INDEX and
## ARG_SLOT). Every default is neutral (empty).

@export var id: StringName = &""
## The TutorialEvents start screen event that pops it.
@export var event: StringName = &""
## Only when the event's ARG_ON is true (a pin worn, not taken off).
@export var needs_on: bool = false
@export var title: String = ""
## Its line (TutorialText: **WORD** chips, {placeholders}).
@export_multiline var text: String = ""
@export var teaches: PackedStringArray = PackedStringArray()
@export var anchor: String = ""


## Whether `event` with `args` pops it.
func fires_on(sent: StringName, args: Dictionary) -> bool:
	if sent != event:
		return false
	return not needs_on or bool(args.get(TutorialEvents.ARG_ON, false))


## Its anchor id for `args` (the event's index or slot filled in).
func anchor_for(args: Dictionary) -> StringName:
	var filled: String = anchor.replace("{index}", str(int(args.get(TutorialEvents.ARG_INDEX, 0))))
	return StringName(filled.replace("{slot}", str(int(args.get(TutorialEvents.ARG_SLOT, 0)))))
