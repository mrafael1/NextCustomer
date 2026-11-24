class_name PuzzleDefinition
extends Resource
## One puzzle shift (#183, full build plan 7.6; prep page docs/art/mockups/puzzle_shift.html): a
## single shift with a fixed hand, fixed loyalty perks, day events and badge pins, no redraw and no
## machine. The player picks which hand items go on the belt and their order; the puzzle is solved
## when the checkout's total equals `target` exactly (PuzzleRun.verdict). Built into a run by
## PuzzleRun.build; checked by the solver (PuzzleSolver, tools/puzzle_check.sh).
##
## Every exported value defaults to a neutral value (no cards, no effect), because Godot doesn't
## write a value that equals the default into a .tres file.

@export var id: StringName = &""
@export var title: String = ""
## The pack it belongs to, counted from 1 (PuzzleList.packs' order).
@export var pack: int = 0
## The total to land on exactly.
@export var target: int = 0
## The belt's slots before the perks, the day events and the pins change them (as the balance's
## slot_count; ShiftLimits).
@export var slot_count: int = 0
## The hand, in basket order (two items a basket, left first).
@export var hand: Array[CardDefinition] = []
## The loyalty perks owned for the shift, in pick order.
@export var upgrades: Array[UpgradeDefinition] = []
## The shift's day events (inspections and boons).
@export var inspections: Array[InspectionDefinition] = []
## The badge pins worn (only pins that change no hand, nor deal, nor relabel: problems()).
@export var pins: Array[PinDefinition] = []
## One row that scores exactly `target`: hand card ids, belt order (a test checks it).
@export var solution: PackedStringArray = PackedStringArray()
## The one-line idea the puzzle teaches, on the board's clipboard.
@export var hint: String = ""


## Why this puzzle can't work as data, or an empty list (checked by a data test and the solver).
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if id == &"":
		found.append("no id")
	if pack <= 0:
		found.append("pack must be 1 or more")
	if target <= 0:
		found.append("target must be above 0")
	if slot_count <= 0:
		found.append("slot_count must be above 0")
	if hand.is_empty() or hand.has(null):
		found.append("hand is empty or holds an empty card")
	if solution.is_empty():
		found.append("no solution")
	var left: Array[StringName] = hand_ids()
	for card_id: String in solution:
		if not left.has(StringName(card_id)):
			found.append("solution item %s is not in the hand" % card_id)
		left.erase(StringName(card_id))
	for pin: PinDefinition in pins:
		if pin == null or not is_puzzle_pin(pin):
			found.append("pin %s changes the hand or the deal" % (pin.id if pin else &"?"))
	return found


## The hand's card ids, in basket order.
func hand_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardDefinition in hand:
		ids.append(card.id if card != null else &"")
	return ids


## Whether a badge pin can be worn in a puzzle: one that changes neither the hand, the draw, the
## shift's rows nor the items' families (no starting cards, recycle, peek, day off, keep, Price
## gun nor Double checkout), so the solver's rows are the player's.
static func is_puzzle_pin(pin: PinDefinition) -> bool:
	return (
		pin.starting_cards.is_empty()
		and not pin.recycle
		and pin.row_slots == 0
		and pin.peek_count == 0
		and pin.days_off_per_week == 0
		and pin.keep_count == 0
		and pin.relabels_per_shift == 0
	)
