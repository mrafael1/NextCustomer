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
