class_name TutorialActions
extends RefCounted
## The tutorial's gate actions (frozen contract, tutorial plan sections 1.2 and 1.3): what a
## screen asks before it acts on a player's input. The gate is a
## `Callable(action: StringName, args: Dictionary) -> bool` that the tutorial director gives a
## screen (`guide_allows` on StartBoardActions, `guide` on the shift screen); it is null outside a
## guided run or a quick tutorial, and a null gate allows everything, so a normal run is unchanged.
## Ask through allows(gate, action, args). The args use TutorialEvents' ARG_* keys and index
## conventions (0-based slots, places, baskets, boosters and packs).
##
## A refused action does nothing, plays no "denied" sound and calls the director's refuse()
## instead (a soft shake and the step's line again). Esc, the pause, ‹ TITLE and moving a placed
## card back to its basket are never asked: they are always allowed.
##
## Start screen:
## - HIT {id}: a click (or its key: Space and Enter press "primary") on the start board's hit
##   `id`, the frame's hit id as drawn (TutorialAnchors' start ids: &"booster0", &"primary",
##   &"crate", &"restock", &"pack1", &"newpacks", &"tab2"...). Asked in BoosterPage.click / primary
##   / handle_key / space, BuildPage.click / primary / handle_key and StartBoard._act.
## - SWAP {id}: a press or release in the swap window on its part `id` (TutorialAnchors'
##   swap_* ids).
## Shift:
## - PICK_CARD {card, instance, from_row}: picking up a card (click or drag start). Only from a
##   basket is gated; picking a placed card back up is allowed.
## - PLACE_CARD {card, instance, slot}: dropping or placing a card at `slot` (the compacted index,
##   mini(slot, run.row.size())). Also asked by the landing highlight (_landing_slot), so only an
##   allowed slot lights up.
## - REDRAW {}: the REDRAW key. BASKET {basket}: clicking a basket (a redraw's target).
## - CHECKOUT {}: the CHECKOUT key (also checked in _refresh_buttons, so it stays locked).
## - OPEN_DECK {}, OPEN_WEEK {}, OPEN_CALENDAR {}: the cart's deck view, the week glass and the
##   day calendar.
## Machine:
## - CHUTE {chute}: arming a chute's key (&"new_items" or &"upgrade"). PUSH {}: PUSH.
## - KEEP {index}: keeping prize `index`. SKIP {}: binning the prizes.

const HIT := &"hit"
const SWAP := &"swap"
const PICK_CARD := &"pick_card"
const PLACE_CARD := &"place_card"
const REDRAW := &"redraw"
const BASKET := &"basket"
const CHECKOUT := &"checkout"
const OPEN_DECK := &"open_deck"
const OPEN_WEEK := &"open_week"
const OPEN_CALENDAR := &"open_calendar"
const CHUTE := &"chute"
const PUSH := &"push"
const KEEP := &"keep"
const SKIP := &"skip"
## The id arg of HIT and SWAP (a TutorialAnchors id).
const ARG_ID := &"id"

## Every action and the arg keys it carries.
const ARGS: Dictionary[StringName, Array] = {
	HIT: [ARG_ID],
	SWAP: [ARG_ID],
	PICK_CARD: [TutorialEvents.ARG_CARD, TutorialEvents.ARG_INSTANCE, TutorialEvents.ARG_FROM_ROW],
	PLACE_CARD: [TutorialEvents.ARG_CARD, TutorialEvents.ARG_INSTANCE, TutorialEvents.ARG_SLOT],
	REDRAW: [],
	BASKET: [TutorialEvents.ARG_BASKET],
	CHECKOUT: [],
	OPEN_DECK: [],
	OPEN_WEEK: [],
	OPEN_CALENDAR: [],
	CHUTE: [TutorialEvents.ARG_CHUTE],
	PUSH: [],
	KEEP: [TutorialEvents.ARG_INDEX],
	SKIP: [],
}


## Asks `gate` whether `action` may happen: true when the gate is null (no tutorial running).
static func allows(gate: Callable, action: StringName, args: Dictionary = {}) -> bool:
	if not gate.is_valid():
		return true
	return bool(gate.call(action, args))


## Whether `action` is one of the contract's actions.
static func is_action(action: StringName) -> bool:
	return ARGS.has(action)
