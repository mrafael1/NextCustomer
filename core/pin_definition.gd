class_name PinDefinition
extends Resource
## A badge pin (#122, decided with the user on 2026-10-31; full build plan 7.4): a talent kept
## between runs and worn on the cashier's name badge before a run, in one of the profile's badge
## slots (BalanceDefinition.pin_slots). A run copies the pins worn when it starts
## (RunState.pins) and never reads the profile again. Pins give new ways to play, never a flat
## payout increase. Unlocked by a milestone (`unlock_condition`, checked at a run's end like a
## deck's), or bought at random for many coins when a milestone is out of reach
## (ProfileState.buy_random_pin); a pin without a condition is owned from the start.
##
## Every exported value defaults to a neutral value (no cards, no effect), because Godot doesn't
## write a value that equals the default into a .tres file.

@export var id: StringName = &""
@export var display_name: String = ""
## The pin's rule in one line, as the badge screen and the cart reveal show it.
@export var rule_text: String = ""
## The few letters on the pin's face (e.g. "2×1").
@export var face_text: String = ""
## The milestone that unlocks it (UnlockCheck); none: owned from the start.
@export var unlock_condition: UnlockCondition
## Cards added to the run's starting deck (after the starter pack is taken).
@export var starting_cards: Array[CardDefinition] = []
## Once per shift the player may redraw every basket at once, for one redraw.
@export var full_redraw: bool = false
