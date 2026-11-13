class_name StartChoice
extends RefCounted
## Opening time: the v3 YOUR STORE page and v4 B staff room. Owns application actions and saves;
## StartSetupRules handles pure setup operations and StartBoard displays the choices.
##
## A run is set up by StartSetupRules.setup_run whenever the balance deals aisles
## (dealt_aisle_count > 0) and the recipe has starter packs: today's suggested aisles on the run
## seed's stock-aisles stream, then dealt at once (v1.32: sealed aisle boosters): the offer on
## its starting-deck stream and each booster on its aisle's booster stream, PICK 2 OF 3's extra
## aisle (6 completed aisles) on the booster-extra stream. The pick refits the unseen offer on the
## booster-pick stream; RESTOCK, the swap window's boosters and NEW PACKS have their own streams
## (EventLogService). The run waits for its pick (RunState.Phase.CHOOSE_START) and is saved after
## each commitment (opening a booster too), so quitting can't reroll anything; a resume opens the
## same board, and a run whose setup was saved in an older form sets it up again
## (RunState.restart_setup). Without the reveal (tests,
## captures, the demo row) the offer's default pack is taken for the player. Only a recipe
## without packs, or a balance with dealt_aisle_count 0, takes the older path: a run that needs a
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
	if balance.dealt_aisle_count > 0 and not recipe.starter_packs.is_empty():
		return _setup_run(seed_value, balance, recipe)
	var listed: Array[StringName] = []
	if RunStock.needs_list(balance, profile.unlocked_items):
		var stream: RandomNumberGenerator = EventLogService.derived_stream(
			seed_value, EventLogService.SURPRISE_LIST_STREAM
		)
		listed = RunStock.surprise_list(balance, profile.unlocked_items, stream)
	var stock: RunStock = RunStock.build(balance, listed, profile.unlocked_items)
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


## Deals `run`'s setup (still in SELECT) on the run seed's streams: one booster stream per aisle
## (StartSetupRules.deal draws only today's and PICK 2 OF 3's extra one).
static func deal(run: RunState, profile: ProfileState) -> StringName:
	var streams: Dictionary[StringName, RandomNumberGenerator] = {}
	for aisle: AisleDefinition in run.balance.aisles:
		streams[aisle.id] = EventLogService.derived_stream(
			run.run_seed, EventLogService.START_BOOSTER_STREAM % aisle.id
		)
	return StartSetupRules.deal(
		run,
		profile,
		EventLogService.derived_stream(run.run_seed, EventLogService.STARTING_DECK_STREAM),
		streams,
		EventLogService.derived_stream(run.run_seed, EventLogService.START_BOOSTER_EXTRA_STREAM)
	)


func _stream(seed_value: int, stream_name: String) -> RandomNumberGenerator:
	return EventLogService.derived_stream(seed_value, stream_name)


func board_actions() -> StartBoardActions:
	var actions: StartBoardActions = StartBoardActions.new()
	actions.page_changed = page_changed
	actions.save_pick = save_pick
	actions.swap_staple = swap_staple
	actions.restore_regular = restore_regular
	actions.open_booster = open_booster
	actions.pick_boosters = pick_boosters
	actions.wear_pins = wear_pins
	actions.pin_catalogue = func() -> Array[PinDefinition]: return _screen._catalogue.pins
	actions.pins_gate = _pins_gate
	actions.mark_seen = mark_seen
	actions.restock_booster = restock_booster
	actions.new_packs = new_packs
	actions.reset_regulars = reset_regulars
	actions.swap_offers = swap_offers
	actions.open_swap_booster = open_swap_booster
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
	if StartSetupRules.pick_block(_screen.run, _screen.profile, pack, _pins_gate()) != &"":
		return false
	var before: Dictionary = _snapshot()
	_screen.run.start_setup.picked = pack.id
	return _commit(before)


## Replaces regular `slot` with `card` (StartSetupRules.swap: a card on a swapped slot trades
## places; `from` >= 0 moves a swapped card from that slot, which gets its original back), `via`
## drag, click or key. Saved, and logged as staple_swap.
func swap_staple(slot: int, card: CardDefinition, via: String = "click", from: int = -1) -> bool:
	var run: RunState = _screen.run
	if not StartSetupRules.can_swap(run, _screen.profile, slot, card, from):
		return false
	var before: Dictionary = _snapshot()
	StartSetupRules.swap(run, _screen.profile, slot, card, from)
	if not _commit(before):
		return false
	var aisle: AisleDefinition = run.balance.aisle_of(card)
	var event: Dictionary = {
		"slot": slot,
		"card": String(card.id),
		"aisle": String(aisle.id) if aisle != null else "",
		"via": via
	}
	if from >= 0:
		event["from"] = from
	_log.log_event("staple_swap", event)
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


## RESET in the swap window (StartSetupRules.reset_swaps): every regular back to its original,
## saved; each slot put back is logged as a restored staple_swap (`via` "reset").
func reset_regulars() -> bool:
	var run: RunState = _screen.run
	if not StartSetupRules.can_reset(run):
		return false
	var before: Dictionary = _snapshot()
	var swapped: Array[int] = []
	for slot: int in run.starter.core_cards.size():
		if run.starter.core_cards[slot] != run.start_setup.originals[slot]:
			swapped.append(slot)
	StartSetupRules.reset_swaps(run)
	if not _commit(before):
		return false
	for slot: int in swapped:
		_log.log_event(
			"staple_swap",
			{
				"slot": slot,
				"card": String(run.start_setup.originals[slot].id),
				"restored": true,
				"aisle": "",
				"via": "reset"
			}
		)
	return true


## The swap window's boosters (StartSwapBoosters.swap_offer), one per stocked aisle in board order
## (aisle id -> cards), each drawn on its aisle's regulars stream and saved the first time they
## are shown, so reopening or a resume never rerolls them. Empty on a failed save.
func swap_offers() -> Dictionary[StringName, Array]:
	var run: RunState = _screen.run
	var offers: Dictionary[StringName, Array] = {}
	var fresh: bool = false
	var before: Dictionary = _snapshot()
	for aisle_id: StringName in StartSwapBoosters.swap_aisles(run):
		fresh = fresh or not run.start_setup.has_swap_offer(aisle_id)
		var stream: RandomNumberGenerator = _stream(
			run.run_seed, EventLogService.START_REGULARS_STREAM % aisle_id
		)
		offers[aisle_id] = StartSwapBoosters.swap_offer(run, _screen.profile, aisle_id, stream)
	if fresh and not _commit(before):
		return {}
	return offers


## Opens the swap window's booster of aisle `aisle_id` (StartSwapBoosters.open_swap_booster), saved
## at once so a resume shows it open.
func open_swap_booster(aisle_id: StringName) -> bool:
	var run: RunState = _screen.run
	if StartSwapBoosters.open_swap_block(run, _screen.profile, aisle_id) != &"":
		return false
	var before: Dictionary = _snapshot()
	StartSwapBoosters.open_swap_booster(run, _screen.profile, aisle_id)
	return _commit(before)


## Opens booster `index` (StartSetupRules.open_booster), saved at once so a resume keeps it open.
func open_booster(index: int) -> bool:
	var run: RunState = _screen.run
	if StartSetupRules.open_block(run, index) != &"":
		return false
	var before: Dictionary = _snapshot()
	StartSetupRules.open_booster(run, index)
	return _commit(before)


## PICK 2 OF 3 (StartSetupRules.pick_boosters): keeps boosters `picks`, the pack offer refitted on
## the booster-pick stream; saves the run and logs start_booster_pick.
func pick_boosters(picks: Array[int]) -> bool:
	var run: RunState = _screen.run
	if StartSetupRules.pick_boosters_block(run, picks) != &"":
		return false
	var before: Dictionary = _snapshot()
	var stream: RandomNumberGenerator = _stream(
		run.run_seed, EventLogService.START_BOOSTER_PICK_STREAM
	)
	StartSetupRules.pick_boosters(run, _screen.profile, picks, stream)
	if not _commit(before):
		return false
	_log.log_event("start_booster_pick", RunEvents.start_booster_pick(run, picks))
	return true


## The BADGE PINS step's choice (v1.32): the profile wears `ids` (owned pins, at most pin_slots,
## in slot order; none is allowed), the run wears them too and the step is confirmed (the packs
## deal on its first confirm). Saves the profile and the run; logs pin_change when they changed.
func wear_pins(ids: Array[StringName]) -> bool:
	var run: RunState = _screen.run
	var profile: ProfileState = _screen.profile
	var before: Dictionary = _snapshot()
	var owned: Array[StringName] = []
	for pin: PinDefinition in ProfilePins.owned(profile, _screen._catalogue):
		owned.append(pin.id)
	var worn: Array[StringName] = []
	for id: StringName in ids:
		if owned.has(id) and not worn.has(id) and worn.size() < run.balance.pin_slots:
			worn.append(id)
	var changed: bool = worn != profile.worn_pins
	profile.worn_pins = worn
	RunPins.wear(run, ProfilePins.worn(profile, _screen._catalogue))
	StartSetupRules.confirm_pins(run)
	if not _commit(before):
		return false
	if changed:
		_log.log_event("pin_change", {"screen": "start", "pins": _pin_ids(run.pins)})
	return true


## How many of the profile's badge pins hold the packs for the BADGE PINS step
## (ProfilePins.start_gate: the packs wait while any).
func _pins_gate() -> int:
	return ProfilePins.start_gate(_screen.profile, _screen._catalogue).size()


## Marks first-seen flag `id` (a NEW tag, shown until its control is first used) and saves the
## profile. False when already marked.
func mark_seen(id: StringName) -> bool:
	var profile: ProfileState = _screen.profile
	if profile.seen.has(id):
		return false
	profile.seen.append(id)
	_screen.save_profile()
	return true


## RESTOCK booster `index` (StartSetupRules.restock) on its aisle's restock stream.
func restock_booster(index: int) -> bool:
	var run: RunState = _screen.run
	if StartSetupRules.restock_block(run, _screen.profile, index) != &"":
		return false
	var before: Dictionary = _snapshot()
	var old: Array[CardDefinition] = run.start_setup.boosters[index].cards.duplicate()
	var aisle: StringName = run.start_setup.boosters[index].aisle
	var stream: RandomNumberGenerator = _stream(
		run.run_seed, EventLogService.START_RESTOCK_STREAM % aisle
	)
	if StartSetupRules.restock(run, _screen.profile, index, stream) != &"":
		return false
	if not _commit(before):
		return false
	_log.log_event("restock", RunEvents.start_restock(run, index, old))
	return true


## NEW PACKS (StartSetupRules.new_packs) on the run seed's new-packs stream.
func new_packs() -> bool:
	var run: RunState = _screen.run
	if StartSetupRules.new_packs_block(run, _screen.profile, _pins_gate()) != &"":
		return false
	var before: Dictionary = _snapshot()
	var old: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
	var picked: StringName = run.start_setup.picked
	var stream: RandomNumberGenerator = _stream(
		run.run_seed, EventLogService.START_NEW_PACKS_STREAM
	)
	StartSetupRules.new_packs(run, _screen.profile, stream, _pins_gate())
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


## A resumed run whose setup was saved in an older form: set up again from its seed,
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
		"pins": run.pins.duplicate(),
		"worn": _screen.profile.worn_pins.duplicate(),
	}


## Saves the run (and the profile when its worn pins changed since `before`). On
## a failed save, everything in `before` is restored and the profile saved back; returns false.
func _commit(before: Dictionary) -> bool:
	var profile: ProfileState = _screen.profile
	var with_profile: bool = profile.worn_pins != before["worn"]
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
