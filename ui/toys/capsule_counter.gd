class_name CapsuleCounter
extends RefCounted
## The TOY MACHINES' counter (#63, full build plan 7.1): the one place the game draws a
## capsule (the machines screen and the debug panel's Profile tools). A draw spends the price,
## records the item in the profile (ProfileState.draw_capsule) on its own derived stream of the
## profile's capsule seed (EventLogService.capsule_stream), saves the profile at once (so
## quitting can't reroll it) and logs the `capsule` event. The seed is made here, outside core/,
## with the event log's new_run_seed the first time a profile draws, and logged in that event.
##
## A save that fails rolls the draw back in memory (the profile is as it was before the draw),
## switches the machines off (every machine OFF: OUT OF ORDER) and emits switched_off. The save
## service has already reported why through its own injected reporter, so the counter reports
## nothing itself.
##
## The run index a draw comes out at is ProfileState.capsule_run_index: the ended run's on the
## results and on the title without a saved run, the saved run's own on the title while one is
## saved (#63 default (a)).

## A save failed at a draw: the machines are switched off.
signal switched_off

## OK: a capsule can be drawn. EMPTY: every item is collected. BROKE: not enough coins. OFF: the
## profile can't be saved, so no machine works.
enum State { OK, EMPTY, BROKE, OFF }

## The profile the draws change. Read it for the coins and the collection; change it only here.
var profile: ProfileState
var _saves: SaveService
var _balance: BalanceDefinition
var _log: EventLogService
var _has_saved_run: bool = false
var _can_save: bool = true


## `has_saved_run`: a run is saved (or in progress, for the debug tools), so a draw's item rides
## the runs after it. `saves_allowed`: false when the profile can't be saved (unreadable and kept,
## SaveService.can_save_profile; or the ended run's profile save failed): the machines start OFF.
func _init(
	profile_state: ProfileState,
	saves: SaveService,
	balance: BalanceDefinition,
	event_log: EventLogService,
	has_saved_run: bool,
	saves_allowed: bool
) -> void:
	profile = profile_state
	_saves = saves
	_balance = balance
	_log = event_log
	_has_saved_run = has_saved_run
	_can_save = saves_allowed


## Whether the machines work: the profile can be saved.
func can_save() -> bool:
	return _can_save


## Coins one capsule costs (BalanceDefinition.capsule_price).
func price() -> int:
	return _balance.capsule_price


## The run index a capsule drawn now comes out at.
func run_index() -> int:
	return profile.capsule_run_index(_has_saved_run)


## The aisle's capsule items still in its machine.
func items_left(aisle: AisleDefinition) -> int:
	return CapsuleDraw.items_left(aisle, profile.unlocked_items).size()


## The machine's state: OFF before everything (the profile can't be saved), then EMPTY, BROKE
## and OK.
func machine_state(aisle: AisleDefinition) -> State:
	if not _can_save:
		return State.OFF
	if CapsuleDraw.is_empty(aisle, profile.unlocked_items):
		return State.EMPTY
	if profile.coins < price():
		return State.BROKE
	return State.OK


## The figurines drawn and not yet seen in the FIGURINE BOOK (v1.26), in draw order: the
## book button's NEW tag and the book's NEW cards show while there are any. Only the ones the
## book can show count: a capsule item of the balance the profile owns (a stale id, from an item
## removed from the data or a hand-edited profile, never tags the button with nothing to show).
func new_figurines() -> Array[StringName]:
	var shown: Array[StringName] = []
	for id: StringName in profile.new_figurines:
		if profile.unlocked_items.has(id) and _is_capsule_item(id):
			shown.append(id)
	return shown


## The FIGURINE BOOK (or a card in it) has shown `ids`: they are no longer new. Saves the
## profile when that changed anything and saves work; returns whether the change is saved (false
## when nothing changed, saves are off or the save failed: the change then stays in memory and
## rides the next save). A failed save here doesn't switch the machines off: no coin or item is
## at stake.
func mark_seen(ids: Array[StringName]) -> bool:
	if not profile.mark_figurines_seen(ids) or not _can_save:
		return false
	return _saves.save_profile(profile)


## Every new figurine seen at once (the book opened), stale ids included.
func mark_all_seen() -> bool:
	return mark_seen(profile.new_figurines.duplicate())


## Draws a capsule from the aisle's machine and saves the profile: the item, or null when the
## machine isn't OK or the save failed (rolled back and switched off, see the class doc).
## Without `spend` (the debug panel's draw) the price is given first, so the draw takes the
## same path and spends no coin of the player's; it also logs a `debug` event.
func draw(aisle: AisleDefinition, spend: bool = true) -> CardDefinition:
	var before_coins: int = profile.coins
	var before_draws: int = profile.capsule_draws
	var had_seed: bool = profile.has_capsule_seed
	if not spend and _can_save and not CapsuleDraw.is_empty(aisle, profile.unlocked_items):
		profile.coins += price()
	if machine_state(aisle) != State.OK:
		profile.coins = before_coins
		return null
	if not had_seed:
		profile.set_capsule_seed(_log.new_run_seed())
	var stream_index: int = profile.capsule_draws
	var rng: RandomNumberGenerator = EventLogService.capsule_stream(
		profile.capsule_seed, stream_index
	)
	var item_run_index: int = run_index()
	var card: CardDefinition = profile.draw_capsule(aisle, price(), item_run_index, rng)
	if not _saves.save_profile(profile):
		profile.undo_capsule(card, price(), before_draws)
		profile.coins = before_coins
		if not had_seed:
			profile.has_capsule_seed = false
			profile.capsule_seed = 0
			profile.capsule_draws = before_draws
		_can_save = false
		switched_off.emit()
		return null
	_log.log_event(
		"capsule",
		RunEvents.capsule(
			aisle, card, item_run_index, profile.coins, stream_index, profile.capsule_seed
		)
	)
	if not spend:
		_log.log_event(
			"debug", {"action": "capsule", "machine": String(aisle.id), "item": String(card.id)}
		)
	return card


func _is_capsule_item(id: StringName) -> bool:
	for aisle: AisleDefinition in _balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			if card != null and card.id == id:
				return true
	return false
