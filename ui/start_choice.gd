class_name StartChoice
extends RefCounted
## Opening time: the v3 YOUR STORE page and v4 B staff room. Owns application actions and saves;
## StartSetupRules handles pure setup operations and StartBoard displays the choices.
##
## A run is set up by StartSetupRules.setup_run whenever the balance stocks aisles
## (stock_aisle_count > 0) and the recipe has starter packs: today's suggested aisles on the run
## seed's stock-aisles stream, then dealt at once (v1.07: no covered baskets, no LOCK IN): the
## offer on its starting-deck stream and each basket on its own basket stream (a save from before
## v1.07 still waiting in SELECT is dealt the same way when it opens). An aisle change (6
## completed aisles) deals that basket on the new aisle's basket stream; RESTOCK, a regular
## slot's offer and NEW PACKS have their own named streams (EventLogService). The run
## waits for its pick (RunState.Phase.CHOOSE_START) and is saved after each commitment, so
## quitting can't reroll anything; a resume opens the same board, and a run whose setup was saved
## in the first build's form sets it up again (RunState.restart_setup). Without the reveal (tests,
## captures, the demo row) the offer's default pack is taken for the player. Only a recipe
## without packs, or a balance with stock_aisle_count 0, takes the older path: a run that needs a
## list stocks a random one from the run seed's own stream (#63) and the deck is dealt on the
## starting-deck stream.

const TITLE_SCREEN := "res://ui/title_screen.tscn"

## Whether back_to_title changes the scene (tests turn it off and watch the screen's overlays).
var changes_scene: bool = true
var _screen: ShiftScreen
var _log: EventLogService
## When the choice opened, for start_choice's decide_ms.
var _opened_ms: int = 0
var _page_ms: Array[int] = [0, 0]
var _page_since: int = 0
var _page_changes: int = 0


func _init(screen: ShiftScreen, event_log: EventLogService) -> void:
	_screen = screen
	_log = event_log
	_screen._cart_reveal.pack_taken.connect(take_chosen)
	_screen._cart_reveal.title_requested.connect(back_to_title)


## A new run for `seed_value` with `recipe` as its starting deck: its stock from the profile, its
## deck dealt (a recipe with packs: its offer, the run waiting for its pick), wearing the
## profile's badge pins (#122).
func new_run(seed_value: int, balance: BalanceDefinition, recipe: DeckDefinition) -> RunState:
	var run: RunState = _dealt_run(seed_value, balance, recipe)
	RunPins.wear(run, ProfilePins.worn(_screen.profile, _screen._catalogue))
	return run


func _dealt_run(seed_value: int, balance: BalanceDefinition, recipe: DeckDefinition) -> RunState:
	var profile: ProfileState = _screen.profile
	if balance.stock_aisle_count > 0 and not recipe.starter_packs.is_empty():
		return _setup_run(seed_value, balance, recipe)
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


func _setup_run(seed_value: int, balance: BalanceDefinition, recipe: DeckDefinition) -> RunState:
	var profile: ProfileState = _screen.profile
	var run: RunState = StartSetupRules.setup_run(
		seed_value,
		balance,
		recipe,
		profile,
		_stream(seed_value, EventLogService.STOCK_AISLES_STREAM)
	)
	deal(run, profile)
	return run


## Deals `run`'s setup (still in SELECT) with today's aisles on the run seed's streams.
static func deal(run: RunState, profile: ProfileState) -> StringName:
	var setup: StartSetup = run.start_setup
	var green: Array[StringName] = setup.green_ids(run.balance)
	var streams: Dictionary[StringName, RandomNumberGenerator] = {}
	for source: StringName in StartSetupRules.basket_sources(run.balance, green):
		streams[source] = EventLogService.derived_stream(
			run.run_seed, EventLogService.START_BASKET_STREAM % source
		)
	var pack_rng: RandomNumberGenerator = EventLogService.derived_stream(
		run.run_seed, EventLogService.STARTING_DECK_STREAM
	)
	return StartSetupRules.lock_in(
		run, profile, green, setup.run_only_ids(run.balance), pack_rng, streams
	)


func _stream(seed_value: int, stream_name: String) -> RandomNumberGenerator:
	return EventLogService.derived_stream(seed_value, stream_name)


func board_actions() -> StartBoardActions:
	var actions: StartBoardActions = StartBoardActions.new()
	actions.page_changed = page_changed
	actions.save_pick = save_pick
	actions.swap_staple = swap_staple
	actions.restore_regular = restore_regular
	actions.change_aisle = change_aisle
	actions.mark_seen = mark_seen
	actions.restock_basket = restock_basket
	actions.new_packs = new_packs
	actions.regular_offer = regular_offer
	actions.mark_build = mark_build
	actions.open_pins = open_pins
	return actions


## Esc on the opening board's store page: the screen closes its overlays (the board among them)
## and leaves for the title. The waiting run is already saved, so Continue reopens it on page 1.
func back_to_title() -> void:
	_screen._close_overlays()
	if changes_scene:
		_screen.get_tree().change_scene_to_file(TITLE_SCREEN)


## When the screen's run waits for its pick: saves it and opens the choice (`reveal`), or takes
## the default pack for the player. Returns whether the run was waiting (the caller's shift start
## is then done here).
func begin_if_choosing(reveal: bool) -> bool:
	var run: RunState = _screen.run
	if run.phase != RunState.Phase.CHOOSE_START:
		return false
	if run.restart_setup:
		_restart_setup()
		run = _screen.run
	var setup: StartSetup = run.start_setup
	# A setup saved before its deal is dealt now; one whose aisles no longer deal (refused) has no
	# way out on page 1 (no LOCK IN any more), so it is set up again from its seed.
	if (
		setup != null
		and setup.stage == StartSetup.Stage.SELECT
		and deal(run, _screen.profile) != &""
	):
		_restart_setup()
		run = _screen.run
	_screen._refresh()
	_screen._save_run()
	var reduced: bool = _screen.profile.reduced_motion()
	var actions: StartBoardActions = board_actions()
	if (
		reveal
		and _screen._cart_reveal.play(run, _screen._deck_button, reduced, _screen.profile, actions)
	):
		_opened_ms = Time.get_ticks_msec()
		_page_since = _opened_ms
		_page_ms = [0, 0]
		_page_changes = 0
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
	var event: Dictionary = RunEvents.start_choice(run, decide_ms)
	if run.start_setup != null:
		if chosen:
			_page_ms[1] += Time.get_ticks_msec() - _page_since
		else:
			_page_ms = [0, 0]
			_page_changes = 0
		event.merge(RunEvents.start_setup_fields(run))
		event.merge(
			{
				"ms_store": _page_ms[0],
				"ms_build": _page_ms[1],
				"page_changes": _page_changes,
				"pins_worn": _pin_ids(run.pins),
				"cart": RunEvents.card_ids(run.deck.cards)
			}
		)
	_log.log_event("start_choice", event)
	run.start_shift()
	_screen._on_shift_started()


func page_changed(page: int, from: int, key: String) -> void:
	_page_ms[from - 1] += Time.get_ticks_msec() - _page_since
	_page_since = Time.get_ticks_msec()
	_page_changes += 1
	_log.log_event("start_page", {"page": page, "from": from, "key": key})


func save_pick(pack: StarterPackDefinition) -> bool:
	var before: Dictionary = _snapshot()
	_screen.run.start_setup.picked = pack.id
	return _commit(before)


## Replaces regular `slot` with `card` (StartSetupRules.swap_block), `via` drag, click or key.
func swap_staple(slot: int, card: CardDefinition, via: String = "click") -> bool:
	var run: RunState = _screen.run
	if not StartSetupRules.can_swap(run, _screen.profile, slot, card):
		return false
	var before: Dictionary = _snapshot()
	run.starter.core_cards[slot] = card
	StartSetupRules.refresh_deck(run)
	if not _commit(before):
		return false
	var aisle: AisleDefinition = run.balance.aisle_of(card)
	_log.log_event(
		"staple_swap",
		{
			"slot": slot,
			"card": String(card.id),
			"aisle": String(aisle.id) if aisle != null else "",
			"via": via
		}
	)
	return true


func restore_regular(slot: int, via: String = "click") -> bool:
	var run: RunState = _screen.run
	if not StartSetupRules.can_restore(run, slot):
		return false
	var before: Dictionary = _snapshot()
	var original: CardDefinition = run.start_setup.originals[slot]
	StartSetupRules.restore(run, slot)
	if not _commit(before):
		return false
	_log.log_event(
		"staple_swap",
		{"slot": slot, "card": String(original.id), "restored": true, "aisle": "", "via": via}
	)
	return true


## Regular `slot`'s offer from aisle `aisle_id` (StartSetupRules.regular_offer), saved the first
## time it is drawn so reopening never rerolls it. Empty on a failed save.
func regular_offer(slot: int, aisle_id: StringName) -> Array[CardDefinition]:
	var run: RunState = _screen.run
	var shown: bool = not run.start_setup.regular_offer(slot, aisle_id).is_empty()
	var before: Dictionary = _snapshot()
	var stream_name: String = EventLogService.START_REGULARS_STREAM % [slot, aisle_id]
	var offer: Array[CardDefinition] = StartSetupRules.regular_offer(
		run, _screen.profile, slot, aisle_id, _stream(run.run_seed, stream_name)
	)
	if shown or offer.is_empty() or _commit(before):
		return offer
	return []


## Changes green basket `basket`'s aisle to `aisle_id` (StartSetupRules.change_aisle), dealt on
## that aisle's basket stream; saves the run and the profile's green pair, logs start_aisle.
func change_aisle(basket: int, aisle_id: StringName) -> bool:
	var run: RunState = _screen.run
	var profile: ProfileState = _screen.profile
	if StartSetupRules.aisle_block(run, profile, basket, aisle_id) != &"":
		return false
	var before: Dictionary = _snapshot()
	var old: StartBasket = run.start_setup.baskets[basket].copy()
	var kept: bool = not run.start_setup.dealt_set(aisle_id).is_empty()
	var stream: RandomNumberGenerator = _stream(
		run.run_seed, EventLogService.START_BASKET_STREAM % aisle_id
	)
	StartSetupRules.change_aisle(run, profile, basket, aisle_id, stream)
	if not _commit(before):
		return false
	_log.log_event("start_aisle", RunEvents.start_aisle(run, basket, old, kept))
	return true


## Marks first-seen flag `id` (a NEW tag, shown until its control is first used) and saves the
## profile. False when already marked.
func mark_seen(id: StringName) -> bool:
	var profile: ProfileState = _screen.profile
	if profile.seen.has(id):
		return false
	profile.seen.append(id)
	_screen.save_profile()
	return true


## RESTOCK basket `basket` (StartSetupRules.restock) on its source's restock stream.
func restock_basket(basket: int) -> bool:
	var run: RunState = _screen.run
	if StartSetupRules.restock_block(run, _screen.profile, basket) != &"":
		return false
	var before: Dictionary = _snapshot()
	var old: Array[CardDefinition] = run.start_setup.baskets[basket].cards.duplicate()
	var source: StringName = run.start_setup.baskets[basket].source
	var stream: RandomNumberGenerator = _stream(
		run.run_seed, EventLogService.START_RESTOCK_STREAM % source
	)
	StartSetupRules.restock(run, _screen.profile, basket, stream)
	if not _commit(before):
		return false
	_log.log_event("restock", RunEvents.start_restock(run, basket, old))
	return true


## NEW PACKS (StartSetupRules.new_packs) on the run seed's new-packs stream.
func new_packs() -> bool:
	var run: RunState = _screen.run
	if StartSetupRules.new_packs_block(run, _screen.profile) != &"":
		return false
	var before: Dictionary = _snapshot()
	var old: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
	var picked: StringName = run.start_setup.picked
	var stream: RandomNumberGenerator = _stream(
		run.run_seed, EventLogService.START_NEW_PACKS_STREAM
	)
	StartSetupRules.new_packs(run, _screen.profile, stream)
	if not _commit(before):
		return false
	_log.log_event("new_packs", RunEvents.new_packs(old, run.start_offer.packs, picked))
	return true


## Page 2 opened: the setup moves to BUILD (saved once).
func mark_build() -> bool:
	var before: Dictionary = _snapshot()
	if not StartSetupRules.mark_build(_screen.run):
		return false
	return _commit(before)


## A resumed run whose setup was saved in the first build's form: set up again from its seed,
## wearing the profile's pins (saved by begin_if_choosing).
func _restart_setup() -> void:
	var old: RunState = _screen.run
	var recipe: DeckDefinition = load(ShiftScreen.STARTER_DECK)
	_screen.run = new_run(old.run_seed, old.balance, recipe)


func open_pins(host: Control, changed: Callable, offset: Vector2 = Vector2.ZERO) -> BadgeScreen:
	var popup: BadgeScreen = BadgeScreen.new(_screen._catalogue, _screen._balance)
	popup.still = _screen.profile.reduced_motion()
	popup.sheet_offset = offset
	host.add_child(popup)
	# The popup saves the profile's worn pins before it signals, so the rollback point is taken
	# here and after each change the run took.
	var last: Array[Dictionary] = [_snapshot()]
	popup.profile_changed.connect(
		func() -> void:
			RunPins.wear(_screen.run, ProfilePins.worn(_screen.profile, _screen._catalogue))
			if not _commit(last[0]):
				popup.open(_screen.profile, _screen._saves, _log, false)
				changed.call()
				return
			last[0] = _snapshot()
			_log.log_event("pin_change", {"screen": "start", "pins": _pin_ids(_screen.run.pins)})
			changed.call()
	)
	popup.open(_screen.profile, _screen._saves, _log, _screen._profile_saved)
	return popup


## What a board action may change, for rolling it back when its save fails.
func _snapshot() -> Dictionary:
	var run: RunState = _screen.run
	var offer: StartOffer = run.start_offer
	return {
		"setup": run.start_setup.copy(),
		"packs": offer.packs.duplicate(),
		"first_pick": offer.first_pick,
		"offer_swaps": offer.swaps,
		"deals": offer.deals,
		"shared": offer.shared.duplicate(),
		"core": run.starter.core_cards.duplicate(),
		"pair": _screen.profile.stock_pair.duplicate(),
		"run_only": _screen.profile.stock_run_only,
		"pins": run.pins.duplicate(),
		"worn": _screen.profile.worn_pins.duplicate(),
	}


## Saves the run (and the profile when its aisle pair or worn pins changed since `before`). On a
## failed save, everything in `before` is restored and the profile saved back; returns false.
func _commit(before: Dictionary) -> bool:
	var profile: ProfileState = _screen.profile
	var with_profile: bool = (
		profile.stock_pair != before["pair"]
		or profile.stock_run_only != before["run_only"]
		or profile.worn_pins != before["worn"]
	)
	if _persist(with_profile):
		return true
	var run: RunState = _screen.run
	run.start_setup = before["setup"]
	run.start_offer.packs = before["packs"]
	run.start_offer.first_pick = before["first_pick"]
	run.start_offer.swaps = before["offer_swaps"]
	run.start_offer.deals = before["deals"]
	run.start_offer.shared = before["shared"]
	run.starter.core_cards = before["core"]
	profile.stock_pair = before["pair"]
	profile.stock_run_only = before["run_only"]
	run.pins = before["pins"]
	profile.worn_pins = before["worn"]
	StartSetupRules.rebuild_stock(run, profile)
	if with_profile:
		_screen.save_profile()
	return false


static func _pin_ids(pins: Array[PinDefinition]) -> Array[String]:
	var ids: Array[String] = []
	for pin: PinDefinition in pins:
		ids.append(String(pin.id))
	return ids


func _persist(with_profile: bool = false) -> bool:
	if with_profile and not _screen.save_profile():
		return false
	return (
		not _screen._saves_run
		or _screen._saves.save_run(
			_screen.run, _log.run_id, Time.get_ticks_msec() - _screen._run_started_ms
		)
	)
