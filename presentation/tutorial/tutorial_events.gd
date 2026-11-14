class_name TutorialEvents
extends RefCounted
## The tutorial's hook events (frozen contract, tutorial plan section 1.2): what the screens tell
## the tutorial director, each with the args it carries. A screen emits them on its signal
## `guide_event(event: StringName, args: Dictionary)` (the start board, the shift screen; the
## machine and week flows go through the shift screen's), always, guided or not: emitting
## changes nothing. The args dictionaries use the ARG_* keys only, with the types below.
##
## Index conventions (everywhere in the tutorial): slots, hand places, baskets, boosters, packs
## and pins are 0-based (slot 0 is the player's "slot 1"); `shift` is 1-based, as the logs'.
## `card` is the card definition's id (StringName, e.g. &"bread"); `instance` its CardInstance's
## instance id.
##
## Start screen (StartBoard.guide_event):
## - BOOSTER_OPENED {index}: page 1's booster `index` started to open.
## - BOOSTERS_ALL_OPEN {}: every counted booster on page 1 is open (STOCKED!, page_done).
## - PAGE_SHOWN {page}: the board's page `page` (0: page 1 STOCK, 1: page 2 YOUR BUILD) finished
##   sliding in (also sent once when the board opens, on its first page).
## - PACK_HOVERED {index}: the pointer rests on starter pack `index` (its tip opened).
## - PACK_PICKED {index}: starter pack `index` was picked.
## - STORE_OPENED {}: OPEN STORE was pressed (the cart is final; clock-in follows).
## - RESTOCK_ARMED {}: the RESTOCK key was armed.
## - RESTOCK_CANCELLED {}: an armed RESTOCK was cancelled (CANCEL RESTOCK).
## - RESTOCK_DONE {index}: booster `index` was sent back and a new sealed one took its place.
## - PINS_OPENED {}: the BADGE PINS step opened on page 2.
## - PIN_TOGGLED {index, on}: pin row `index` was worn (on true) or taken off.
## - PINS_CONFIRMED {count}: the pins step was confirmed with `count` pins worn.
## - SWAP_OPENED {}: the swap window opened (the regulars basket was clicked).
## - SWAP_BOOSTER_OPENED {index}: the swap window's booster `index` was opened.
## - SWAP_APPLIED {slot, card}: booster card `card` replaced the regular in slot `slot`.
## - SWAP_UNDONE {slot}: the swap in slot `slot` was undone (dragged back, or RESET: one each).
## - SWAP_DONE {}: the swap window closed (DONE).
##
## Shift (ShiftScreen.guide_event):
## - PLANNING_READY {shift}: shift `shift`'s planning takes input (after the cart reveal, a
##   shift start or a resume into planning), the hand dealt.
## - CARD_PICKED {card, instance, from_row}: a card was picked up (click or drag start), from the
##   row (from_row true) or a basket.
## - CARD_PLACED {card, instance, slot}: a card landed in the row at `slot` (the compacted index).
## - CARD_REMOVED {card, instance}: a card went back from the row to its basket.
## - SCAN_HELD {card, instance}: the pointer rested on a card long enough for the monitor to read
##   it (the scan dwell).
## - PROJECTED {total, quota}: the row's projected total changed (after any move), in €.
## - REDRAW_DONE {basket}: basket `basket` was redrawn.
## - CHECKOUT_STARTED {}: CHECKOUT was pressed (the count-up starts).
## - COUNT_FINISHED {}: the count-up finished.
## - MISS {}: the shift's quota was missed (after the count-up).
##
## Machine (ShiftScreen.guide_event, from MachineFlow):
## - MACHINE_ARMED {}: the machine's keys take input (a visit is ready for its chute).
## - CHUTE_CHOSEN {chute}: a chute was chosen and PUSH pressed (&"new_items" or &"upgrade").
## - PRIZE_KEPT {kind}: a prize was kept (kind &"item", &"coupon", &"improve" or &"perk").
## - PRIZE_BINNED {}: the prizes were binned (SKIP).
## - PERK_TAKEN {}: a loyalty perk was taken (also sends PRIZE_KEPT).
## - IMPROVE_TAKEN {}: an IMPROVE prize was applied (also sends PRIZE_KEPT).
## - MACHINE_RETURNED {}: the machine's visits are over and the screen is back.
##
## Other:
## - WEEK_CARD_OPENED {}: the time card opened; WEEK_CARD_CLOSED {}: it closed.
## - HANDBOOK_OPENED {}: the HANDBOOK opened (anywhere in a run).
## - RESULTS {won, coins}: the run's results opened: won or lost, the coins it paid.

## Start screen.
const BOOSTER_OPENED := &"booster_opened"
const BOOSTERS_ALL_OPEN := &"boosters_all_open"
const PAGE_SHOWN := &"page_shown"
const PACK_HOVERED := &"pack_hovered"
const PACK_PICKED := &"pack_picked"
const STORE_OPENED := &"store_opened"
const RESTOCK_ARMED := &"restock_armed"
const RESTOCK_CANCELLED := &"restock_cancelled"
const RESTOCK_DONE := &"restock_done"
const PINS_OPENED := &"pins_opened"
const PIN_TOGGLED := &"pin_toggled"
const PINS_CONFIRMED := &"pins_confirmed"
const SWAP_OPENED := &"swap_opened"
const SWAP_BOOSTER_OPENED := &"swap_booster_opened"
const SWAP_APPLIED := &"swap_applied"
const SWAP_UNDONE := &"swap_undone"
const SWAP_DONE := &"swap_done"
## Shift.
const PLANNING_READY := &"planning_ready"
const CARD_PICKED := &"card_picked"
const CARD_PLACED := &"card_placed"
const CARD_REMOVED := &"card_removed"
const SCAN_HELD := &"scan_held"
const PROJECTED := &"projected"
const REDRAW_DONE := &"redraw_done"
const CHECKOUT_STARTED := &"checkout_started"
const COUNT_FINISHED := &"count_finished"
const MISS := &"miss"
## Machine.
const MACHINE_ARMED := &"machine_armed"
const CHUTE_CHOSEN := &"chute_chosen"
const PRIZE_KEPT := &"prize_kept"
const PRIZE_BINNED := &"prize_binned"
const PERK_TAKEN := &"perk_taken"
const IMPROVE_TAKEN := &"improve_taken"
const MACHINE_RETURNED := &"machine_returned"
## Other.
const WEEK_CARD_OPENED := &"week_card_opened"
const WEEK_CARD_CLOSED := &"week_card_closed"
const HANDBOOK_OPENED := &"handbook_opened"
const RESULTS := &"results"

## The args' keys (see the class doc for which event carries which).
const ARG_INDEX := &"index"
const ARG_PAGE := &"page"
const ARG_ON := &"on"
const ARG_COUNT := &"count"
const ARG_SLOT := &"slot"
const ARG_CARD := &"card"
const ARG_INSTANCE := &"instance"
const ARG_FROM_ROW := &"from_row"
const ARG_SHIFT := &"shift"
const ARG_TOTAL := &"total"
const ARG_QUOTA := &"quota"
const ARG_BASKET := &"basket"
const ARG_CHUTE := &"chute"
const ARG_KIND := &"kind"
const ARG_WON := &"won"
const ARG_COINS := &"coins"

## The chutes (CHUTE_CHOSEN's chute) and the prize kinds (PRIZE_KEPT's kind).
const CHUTE_NEW_ITEMS := &"new_items"
const CHUTE_UPGRADE := &"upgrade"
const PRIZE_ITEM := &"item"
const PRIZE_COUPON := &"coupon"
const PRIZE_IMPROVE := &"improve"
const PRIZE_PERK := &"perk"

## Every event and the arg keys it carries, in the class doc's order (tests and the director
## check emits against it).
const ARGS: Dictionary[StringName, Array] = {
	BOOSTER_OPENED: [ARG_INDEX],
	BOOSTERS_ALL_OPEN: [],
	PAGE_SHOWN: [ARG_PAGE],
	PACK_HOVERED: [ARG_INDEX],
	PACK_PICKED: [ARG_INDEX],
	STORE_OPENED: [],
	RESTOCK_ARMED: [],
	RESTOCK_CANCELLED: [],
	RESTOCK_DONE: [ARG_INDEX],
	PINS_OPENED: [],
	PIN_TOGGLED: [ARG_INDEX, ARG_ON],
	PINS_CONFIRMED: [ARG_COUNT],
	SWAP_OPENED: [],
	SWAP_BOOSTER_OPENED: [ARG_INDEX],
	SWAP_APPLIED: [ARG_SLOT, ARG_CARD],
	SWAP_UNDONE: [ARG_SLOT],
	SWAP_DONE: [],
	PLANNING_READY: [ARG_SHIFT],
	CARD_PICKED: [ARG_CARD, ARG_INSTANCE, ARG_FROM_ROW],
	CARD_PLACED: [ARG_CARD, ARG_INSTANCE, ARG_SLOT],
	CARD_REMOVED: [ARG_CARD, ARG_INSTANCE],
	SCAN_HELD: [ARG_CARD, ARG_INSTANCE],
	PROJECTED: [ARG_TOTAL, ARG_QUOTA],
	REDRAW_DONE: [ARG_BASKET],
	CHECKOUT_STARTED: [],
	COUNT_FINISHED: [],
	MISS: [],
	MACHINE_ARMED: [],
	CHUTE_CHOSEN: [ARG_CHUTE],
	PRIZE_KEPT: [ARG_KIND],
	PRIZE_BINNED: [],
	PERK_TAKEN: [],
	IMPROVE_TAKEN: [],
	MACHINE_RETURNED: [],
	WEEK_CARD_OPENED: [],
	WEEK_CARD_CLOSED: [],
	HANDBOOK_OPENED: [],
	RESULTS: [ARG_WON, ARG_COINS],
}
## Each arg key's type (a Variant.Type).
const ARG_TYPES: Dictionary[StringName, int] = {
	ARG_INDEX: TYPE_INT,
	ARG_PAGE: TYPE_INT,
	ARG_ON: TYPE_BOOL,
	ARG_COUNT: TYPE_INT,
	ARG_SLOT: TYPE_INT,
	ARG_CARD: TYPE_STRING_NAME,
	ARG_INSTANCE: TYPE_INT,
	ARG_FROM_ROW: TYPE_BOOL,
	ARG_SHIFT: TYPE_INT,
	ARG_TOTAL: TYPE_INT,
	ARG_QUOTA: TYPE_INT,
	ARG_BASKET: TYPE_INT,
	ARG_CHUTE: TYPE_STRING_NAME,
	ARG_KIND: TYPE_STRING_NAME,
	ARG_WON: TYPE_BOOL,
	ARG_COINS: TYPE_INT,
}


## Whether `event` is one of the contract's events.
static func is_event(event: StringName) -> bool:
	return ARGS.has(event)


## Whether `args` is exactly what `event` carries: its keys (no more, no fewer), each of its type.
static func args_valid(event: StringName, args: Dictionary) -> bool:
	if not ARGS.has(event):
		return false
	var keys: Array = ARGS[event]
	if args.size() != keys.size():
		return false
	for key: StringName in keys:
		if not args.has(key) or typeof(args[key]) != ARG_TYPES[key]:
			return false
	return true
