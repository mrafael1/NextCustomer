class_name StartBoardActions
extends RefCounted
## The board's application boundary (StartChoice). No scene internals or run mutation in the view.

var page_changed: Callable
var save_pick: Callable
## swap_staple(slot, card, via) and restore_regular(slot, via) -> bool.
var swap_staple: Callable
var restore_regular: Callable
## lock_in(green, run_only, clicks) -> bool.
var lock_in: Callable
## restock_basket(basket) -> bool.
var restock_basket: Callable
## new_packs() -> bool.
var new_packs: Callable
## regular_offer(slot, aisle_id) -> Array[CardDefinition], saved once drawn.
var regular_offer: Callable
## mark_build() -> bool: page 2 opened.
var mark_build: Callable
var open_pins: Callable
