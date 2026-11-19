class_name TutorialAnchors
extends RefCounted
## The tutorial's anchor ids (frozen contract, tutorial plan section 1.2): the names of what a
## step rings, locks or points its callout at. They are the mock-up's rect names
## (docs/art/mockups/tutorial.html) and the start board's hit ids. Each screen side answers
## `anchor_rect(id: StringName) -> Rect2` in global (viewport) coordinates, Rect2() for an id it
## doesn't show now; the mock-up's 1920x1080 rects are never copied into code.
##
## An indexed id is its prefix and a 0-based index (slot(0) = &"slot0", the player's "slot 1";
## card(1, 2) = &"card1_2", booster 1's third card). Build them with the helpers, never by hand.

## Shift screen.
const QUOTA := &"quota"
const PROJ := &"proj"
const RECEIPT := &"receipt"
const CHECKOUT := &"checkout"
const REDRAW := &"redraw"
const WEEK := &"week"
const CAL := &"cal"
const MEDALS := &"medals"
const GAUGE := &"gauge"
const LOYALTY := &"loyalty"
const CART := &"cart"
const MENU := &"menu"
const MONITOR := &"monitor"
## Every slot's ticket together, and every basket together.
const TICKETS := &"tickets"
const BASKETS := &"baskets"
const DAY_SLIP := &"day_slip"
const WEEK_CARD := &"week_card"
## The MISS stamp on the receipt (T9) and the results panel (T14).
const MISS_STAMP := &"miss_stamp"
const RESULTS := &"results"
## Machine (under the store camera: the rects are its controls' global transforms).
const MACHINE_KEYS := &"machine_keys"
const MACHINE_PUSH := &"machine_push"
const MACHINE_PRIZES := &"machine_prizes"
const MACHINE_SKIP := &"machine_skip"
## The machine's CLASSIC / PREMIUM sign (T8).
const MACHINE_SIGN := &"machine_sign"
## Title: the primary plate (START RUN, or NEW RUN with a saved run; G1).
const TITLE_PRIMARY := &"title_primary"
## The HANDBOOK's tabs (T16).
const HANDBOOK_TABS := &"handbook_tabs"
## Start board, page 1 (BoosterChromeDraw's hit ids): the RESTOCK key, the main key (NEXT / OPEN
## STORE), the page tabs and the title key; the top bar's CART count is CART.
const RESTOCK := &"restock"
const PRIMARY := &"primary"
const TAB1 := &"tab1"
const TAB2 := &"tab2"
const TITLE := &"title"
## Page 2's REGULARS crate: its SWAP key (v1.44: the regulars' swap window opens from it; also
## the id a guided step locks the swap with) and KEEP (v1.45: OPEN STORE waits for it).
const SWAP_KEY := &"swap_key"
const REGULARS_OK := &"regulars_ok"
## Start board, page 2 (BuildPageDraw's hit ids): the pins board, the back key, and the pins step's
## confirm key and its board.
const PINS := &"pins"
const BACK := &"back"
const PINS_CONFIRM := &"pins_confirm"
const PIN_BOARD := &"pin_board"
## The swap window: its boosters together, RESET and DONE.
const SWAP_BOOSTERS := &"swap_boosters"
const SWAP_RESET := &"swap_reset"
const SWAP_DONE := &"swap_done"

## Every fixed id.
const FIXED: Array[StringName] = [
	QUOTA,
	PROJ,
	RECEIPT,
	CHECKOUT,
	REDRAW,
	WEEK,
	CAL,
	MEDALS,
	GAUGE,
	LOYALTY,
	CART,
	MENU,
	MONITOR,
	TICKETS,
	BASKETS,
	DAY_SLIP,
	WEEK_CARD,
	MISS_STAMP,
	RESULTS,
	MACHINE_KEYS,
	MACHINE_PUSH,
	MACHINE_PRIZES,
	MACHINE_SKIP,
	MACHINE_SIGN,
	TITLE_PRIMARY,
	HANDBOOK_TABS,
	RESTOCK,
	PRIMARY,
	TAB1,
	TAB2,
	TITLE,
	SWAP_KEY,
	REGULARS_OK,
	PINS,
	BACK,
	PINS_CONFIRM,
	PIN_BOARD,
	SWAP_BOOSTERS,
	SWAP_RESET,
	SWAP_DONE,
]

## Indexed ids' prefixes (one index). Shift: a slot's ticket, a hand place's card, a basket, a
## slot ticket's family icons and its rule chip (T3), a slot's whole spot (its belt place, the
## item on it and its ticket: what a callout keeps clear, TutorialStep.keep_clear); machine: a
## chute key, a prize. Start page 1: a booster, its hit place, its RETURN THIS ONE plate, a
## restocked booster's cards. Page 2: a pin row and its WEAR button. Swap window:
## a regular, a booster.
const SLOT := "slot"
const HAND := "hand"
const BASKET := "basket"
const FAMILIES := "families"
const RULE := "rule"
const SPOT := "spot"
const MACHINE_KEY := "machine_key"
const PRIZE := "prize"
const BOOSTER := "booster"
const HIT := "hit"
const RETURN := "return"
const RCARDS := "rcards"
const PIN_ROW := "pin_row"
const WEAR := "wear"
const SWAP_REGULAR := "swap_regular"
const SWAP_BOOSTER := "swap_booster"
const PREFIXES: Array[String] = [
	SLOT,
	HAND,
	BASKET,
	FAMILIES,
	RULE,
	SPOT,
	MACHINE_KEY,
	PRIZE,
	BOOSTER,
	HIT,
	RETURN,
	RCARDS,
	PIN_ROW,
	WEAR,
	SWAP_REGULAR,
	SWAP_BOOSTER,
]
## Two-index prefixes: a start booster's card (card<booster>_<place>) and a swap booster's card
## (swap_card<booster>_<place>).
const CARD := "card"
const SWAP_CARD := "swap_card"
const PAIR_PREFIXES: Array[String] = [CARD, SWAP_CARD]


static func slot(index: int) -> StringName:
	return indexed(SLOT, index)


static func hand(place: int) -> StringName:
	return indexed(HAND, place)


static func basket(index: int) -> StringName:
	return indexed(BASKET, index)


static func booster(index: int) -> StringName:
	return indexed(BOOSTER, index)


static func card(booster_index: int, place: int) -> StringName:
	return StringName("%s%d_%d" % [CARD, booster_index, place])


static func swap_card(booster_index: int, place: int) -> StringName:
	return StringName("%s%d_%d" % [SWAP_CARD, booster_index, place])


## The indexed id `prefix` + `index` (one of PREFIXES).
static func indexed(prefix: String, index: int) -> StringName:
	return StringName("%s%d" % [prefix, index])


## The index of `id` when it is `prefix` + a 0-based index, else -1 (index_of(&"slot3", SLOT) is
## 3).
static func index_of(id: StringName, prefix: String) -> int:
	var text: String = String(id)
	if not text.begins_with(prefix):
		return -1
	var digits: String = text.substr(prefix.length())
	return digits.to_int() if _is_index(digits) else -1


## Whether `id` is an anchor id: a fixed one, or a prefix with its index (or indices).
static func is_known(id: StringName) -> bool:
	if FIXED.has(id):
		return true
	var text: String = String(id)
	for prefix: String in PAIR_PREFIXES:
		if text.begins_with(prefix):
			var parts: PackedStringArray = text.substr(prefix.length()).split("_")
			if parts.size() == 2 and _is_index(parts[0]) and _is_index(parts[1]):
				return true
	for prefix: String in PREFIXES:
		if index_of(id, prefix) != -1:
			return true
	return false


static func _is_index(digits: String) -> bool:
	if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")):
		return false
	for character: String in digits:
		if character < "0" or character > "9":
			return false
	return true
