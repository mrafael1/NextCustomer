class_name StartChoice
extends RefCounted
## A new run's start on the shift screen: its stock and its starting deck, and the starter pack
## choice (#107, v0.63). Split out of ShiftScreen to keep that file short; it is a part of the
## screen and works on its run and display through the screen's own methods.
##
## Until #65's shopping list, a run that needs a list stocks a random one from the run seed's own
## stream (#63), so the same seed and profile give the same list; last_list is untouched. The
## starting deck is dealt on the run seed's starting-deck stream: a recipe with starter packs deals
## its offer and today's products (the good first pick while the profile has never won), and the
## run waits for its pick (RunState.Phase.CHOOSE_START). The run is saved with its offer before the
## choice opens, so quitting can't reroll it; a resume opens the same offer. Without the reveal
## (tests, captures, the demo row) the offer's default pack is taken for the player.

var _screen: ShiftScreen
var _log: EventLogService
## When the choice opened, for start_choice's decide_ms.
var _opened_ms: int = 0


func _init(screen: ShiftScreen, event_log: EventLogService) -> void:
	_screen = screen
	_log = event_log
	_screen._cart_reveal.pack_taken.connect(take_chosen)


## A new run for `seed_value` with `recipe` as its starting deck: its stock from the profile, its
## deck dealt (a recipe with packs: its offer, the run waiting for its pick).
func new_run(seed_value: int, balance: BalanceDefinition, recipe: DeckDefinition) -> RunState:
	var profile: ProfileState = _screen.profile
	var listed: Array[StringName] = []
	if RunStock.needs_list(balance, profile.unlocked_items):
		var stream: RandomNumberGenerator = EventLogService.derived_stream(
			seed_value, EventLogService.SURPRISE_LIST_STREAM
		)
		listed = RunStock.surprise_list(balance, profile.unlocked_items, stream)
	var stock: RunStock = RunStock.build(balance, listed, profile.unlocked_items, profile.run_count)
	var deal_rng: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.STARTING_DECK_STREAM
	)
	if recipe.starter_packs.is_empty():
		var deck: DeckDefinition = StartingDeck.deal(recipe, stock, balance, deal_rng)
		return RunState.new(seed_value, deck, balance, stock)
	var offer: StartOffer = StartingDeck.deal_offer(
		recipe, stock, balance, deal_rng, not profile.has_won()
	)
	return RunState.new(seed_value, StartingDeck.before_pick(recipe, offer), balance, stock, offer)


## When the screen's run waits for its pick: saves it and opens the choice (`reveal`), or takes
## the default pack for the player. Returns whether the run was waiting (the caller's shift start
## is then done here).
func begin_if_choosing(reveal: bool) -> bool:
	var run: RunState = _screen.run
	if run.phase != RunState.Phase.CHOOSE_START:
		return false
	_screen._refresh()
	_screen._save_run()
	var reduced: bool = _screen.profile.reduced_motion()
	if reveal and _screen._cart_reveal.play(run, _screen._deck_button, reduced):
		_opened_ms = Time.get_ticks_msec()
		_screen._machine.hold_notice()
		return true
	_take(run.start_offer.default_pack(), false)
	return true


## The player took `pack` in the reveal: shift 1 starts behind it, whose input waits for the
## reveal's end.
func take_chosen(pack: StarterPackDefinition) -> void:
	_take(pack, true)
	_screen._machine.hold_notice()


## Takes `pack` from the run's offer and starts shift 1: logs start_choice (`chosen`: the player
## picked it in the reveal) and saves at the shift's start.
func _take(pack: StarterPackDefinition, chosen: bool) -> void:
	var run: RunState = _screen.run
	if not run.take_pack(pack):
		return
	var decide_ms: int = Time.get_ticks_msec() - _opened_ms if chosen else -1
	_log.log_event("start_choice", RunEvents.start_choice(run, decide_ms))
	run.start_shift()
	_screen._on_shift_started()
