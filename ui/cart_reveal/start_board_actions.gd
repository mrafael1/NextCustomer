class_name StartBoardActions
extends RefCounted
## The board's application boundary (StartChoice). No scene internals or run mutation in the view.

var page_changed: Callable
var save_pick: Callable
## swap_staple(slot, card, via, from = -1), restore_regular(slot, via) and reset_regulars() ->
## bool: the swap window's swaps (a card on a swapped slot trades; `from` moves a swapped card),
## their undo and RESET.
var swap_staple: Callable
var restore_regular: Callable
var reset_regulars: Callable
## open_booster(index) -> bool: a sealed booster opened (saved).
var open_booster: Callable
## pick_boosters(picks: Array[int]) -> bool: PICK 2 OF 3's pair kept, the other SOLD OUT.
var pick_boosters: Callable
## wear_pins(ids: Array[StringName]) -> bool: the BADGE PINS step's pins worn (none allowed), the
## step confirmed; saves the profile and the run.
var wear_pins: Callable
## pin_catalogue() -> Array[PinDefinition]: every pin, in data order.
var pin_catalogue: Callable
## pins_gate() -> int: how many owned pins hold the packs for the BADGE PINS step
## (ProfilePins.start_gate).
var pins_gate: Callable
## mark_seen(id) -> bool: a NEW tag's first-seen flag.
var mark_seen: Callable
## restock_booster(index) -> bool.
var restock_booster: Callable
## new_packs() -> bool.
var new_packs: Callable
## swap_offers() -> Dictionary[StringName, Array]: the swap window's boosters (aisle id -> cards),
## one per stocked aisle, saved once drawn; open_swap_booster(aisle_id) -> bool (saved).
var swap_offers: Callable
var open_swap_booster: Callable
## mark_build() -> bool: page 2 opened.
var mark_build: Callable
var open_pins: Callable
## The tutorial's gate (TutorialActions): `guide_allows(action, args) -> bool`, asked before a
## player's input acts on the board (a HIT or a SWAP part, TutorialActions' ids). Null (no
## tutorial): everything is allowed, so a normal run is unchanged. A refusal does nothing and
## plays no sound (the gate's owner answers it: a shake and the step's line).
var guide_allows: Callable
## guide_locks(id: StringName) -> bool: whether the tutorial locks the board's part `id`
## (TutorialAnchors.SWAP_PLATE, RESTOCK, NEWPACKS): drawn LOCKED and refused. Null: none.
var guide_locks: Callable
## guide_event(event: StringName, args: Dictionary): the board's hook (StartBoard sets it to its
## guide_event signal); the pages send TutorialEvents through send(). Null: nothing listens.
var guide_event: Callable


## Whether the tutorial allows `action` with `args` (true with no gate).
func allows(action: StringName, args: Dictionary = {}) -> bool:
	return TutorialActions.allows(guide_allows, action, args)


## Whether the tutorial allows a click (or its key) on the board's hit `id` (a TutorialAnchors
## id; "" is never asked): false while the tutorial locks it.
func allows_hit(id: StringName) -> bool:
	if id == &"":
		return true
	if locked(id) or (id == TutorialAnchors.CRATE and locked(TutorialAnchors.SWAP_PLATE)):
		return false
	return allows(TutorialActions.HIT, {TutorialActions.ARG_ID: id})


## Whether the tutorial allows a press on the swap window's part `id` ("" is never asked).
func allows_swap(id: StringName) -> bool:
	if id == &"":
		return true
	return allows(TutorialActions.SWAP, {TutorialActions.ARG_ID: id})


## Whether the tutorial locks the board's part `id` (drawn LOCKED).
func locked(id: StringName) -> bool:
	return guide_locks.is_valid() and bool(guide_locks.call(id))


## Sends hook `event` with `args` (TutorialEvents) to whoever listens.
func send(event: StringName, args: Dictionary = {}) -> void:
	if guide_event.is_valid():
		guide_event.call(event, args)


## The null-safe forms the pages use (a page shown without actions allows everything).
static func hit_allowed(actions: StartBoardActions, id: StringName) -> bool:
	return actions == null or actions.allows_hit(id)


static func swap_allowed(actions: StartBoardActions, id: StringName) -> bool:
	return actions == null or actions.allows_swap(id)


static func is_locked(actions: StartBoardActions, id: StringName) -> bool:
	return actions != null and actions.locked(id)


static func emit(actions: StartBoardActions, event: StringName, args: Dictionary = {}) -> void:
	if actions != null:
		actions.send(event, args)
