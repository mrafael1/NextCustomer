class_name ShiftScreen
extends Control
## The shift screen (plan section 2): the impulse rack before shift 1 (full build plan
## section 3), draw, redraw, click-to-place into the row, the live projected total and receipt,
## checkout with the count-up, the reward choice, the upgrade choice and loyalty card on upgrade
## shifts (plan section 3.8), the shift's inspection and the next one's notice (plan section
## 3.9), the deck view, and the run's results with its history. It only displays RunState and
## ScoreResult; every rule lives in core/. The run is saved at every stable point and resumed
## when the screen opens (full build plan section 4); the debug tools live in ShiftDebug.
##
## Click-to-place: click a hand card to pick it up, then click a slot to put it there (a
## filled slot pushes the cards from there to the right). Click a row card to pick it back up.
## Drag-and-drop does the same (CardDrag): drop on a slot to place, anywhere else to let go.
##
## The row has slot_count product slots plus coupon-only slots (plan section 3.1). The row is
## compacted, so the coupon slot is a capacity, not a position: no panel is marked as the
## coupon slot (a coupon can go anywhere). The row's slots alone show the capacity, and
## RowCapacity enforces it.
##
## The layout (#55; full build plan section 6.1) is ShiftStage's: a 1280x720 stage centred in the
## window over a wall and a counter that fill it. The screen keeps its own names for the stage's
## controls and fills them.
##
## Sounds (#62) play on the screen's own Sfx, warmed up when it opens: cards picked up, placed
## and let go, refusals, the redraw, CHECKOUT, a reward or ticket taken and the log export here;
## buttons and panels in UiKit, drag slot ticks in CardDrag, music in ShiftMusic. The only hover
## sound is the scanner's beep (#75, ScanController), played once a hover on an item is held.

const STARTER_DECK := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
## A refused card or a closed slot plays `denied` this much softer than the count-up does.
const REFUSED_DB := -6.0
## After a redraw's shuffle, each card dealt lands this many seconds after the last.
const DEAL_GAP := 0.08
var run: RunState
## Where the save errors go (push_error by default). Tests set it before the screen enters the
## tree, so an unreadable save they write on purpose prints nothing.
var report_error: Callable = Callable()
## The meta progress (full build plan section 4): loaded at start, recorded and saved when a
## run ends. A run restarted before its end records nothing.
var profile: ProfileState
var tracker: CheckoutTracker = CheckoutTracker.new()
var _picked: CardInstance
## True when the picked card was taken from the row: placing it again is a move (plan 8:
## 1 placement, 0 removals); only leaving it in the hand counts as a removal.
var _picked_from_row: bool = false
var _balance: BalanceDefinition
var _catalogue: CatalogueDefinition
var _saves: SaveService
## False when the ended run's profile couldn't be saved: the results then show no coin total.
var _profile_saved: bool = true
## False for a --demo-row run (ShiftDebug): it never writes or deletes the run save.
var _saves_run: bool = true
var _click_ms: int = 0
var _redraw_mode: bool = false
var _redraw_pick: Array[CardInstance] = []
var _counting: bool = false
var _run_started_ms: int = 0
var _run_ended_ms: int = -1
## The offer on screen (a reward or the impulse rack): whether the deck view was opened, and a
## picked card waiting for the player to choose which deck card it replaces. Its times are the
## panel's timeline (OfferTimeline), like the upgrade tickets'.
var _deck_viewed_for_reward: bool = false
var _pending_reward: CardDefinition

## The 1280x720 stage, centred in the window.
var _stage: ShiftStage
var _top_bar: HBoxContainer
var _shift_label: Label
var _quota_label: Label
var _inspection_tag: InspectionTag
var _loyalty_card: LoyaltyCard
var _deck_button: FramedButton
var _seed_label: Label
var _slots: Array[PanelContainer] = []
var _row_views: Array[CardView] = []
var _hand_box: HandRow
var _notice_label: NoticeLabel
var _drag: CardDrag
var _receipt: ReceiptView
var _redraw_button: RegisterKey
var _cancel_button: FramedButton
var _checkout_button: FramedButton
var _results: ResultsPanel
var _reward_panel: RewardPanel
var _upgrade_panel: UpgradePanel
## Dims the screen and blocks clicks behind the reward and upgrade panels, deck view and
## results.
var _shade: ScreenShade
var _deck_view: DeckView
var _row_strip: RowStrip
## The register: the count-up's rattle target (the same node as `_cabinet`); its
## set_total_down() marks CHECKOUT held while the shift is counted.
var _register: Control
var _cabinet: RegisterCabinet
## The hung monitor (#80): the store channel in planning, the LED, the notices, a scanned item
## and the count-up's beats.
var _monitor: MonitorView
## The monitor's LED: blank in planning and the rack, the count-up's subtotal and total.
var _led: LedDisplay
## The top bar's SPEND chip: the projected total in planning (fed here), the LED's readings while
## counting.
var _quota_meter: QuotaMeter
var _overlay: Control
var _count_up: CountUp
var _sfx: Sfx
var _debug: ShiftDebug
var _focus: FocusWatch
## The hover scanner (#75): the scan popup and the marks over the scanned item.
var _scan: ScanController
## Takes the belt items' marks and paid chips off (#80; #86 v6: the stickers and the bag say it).
var _belt_chips: BeltChips = BeltChips.new()
## The belt in the count (#86 v6): the items ride to the scanner and into the bag.
var _ride: BeltRide
## The planning effects (#71, mock-up h1): the belt's stickers, the hover's relations, the drag's.
var _effects: PlanningEffects
## The EventLog autoload, typed. Fetched from the tree because standalone script checks
## don't know autoload names.
@onready var _log: EventLogService = get_node("/root/EventLog")
## The Music autoload (#62), typed like EventLog. Tests may swap it before a checkout.
@onready var _music: MusicService = get_node("/root/Music")


func _ready() -> void:
	_balance = load(BALANCE)
	_catalogue = load(CATALOGUE)
	_saves = SaveService.new(SaveService.default_folder(), report_error)
	profile = _saves.load_profile()
	_build()
	_sfx.warm_up()
	ShiftMusic.screen_opened(_music)
	_debug = ShiftDebug.new(self, _log)
	_debug.add_panel(_balance.quotas.size())
	if _debug.wants_demo_row():
		_debug.play_demo_row()  # A new run that leaves the run save as it is.
		return
	# Full build plan section 4: a saved run continues; without one (or with an unreadable one,
	# reported and backed up) a new run starts and overwrites it at its first save point.
	var saved: RunSave = _saves.load_run(ContentLookup.new(_balance))
	if saved != null:
		_resume_run(saved)
	else:
		start_new_run(_log.new_run_seed())


## Starts a run with a seed (a new random one, or one set from the debug panel) and opens the
## impulse rack. The debug replay passes `replays_rack` with the logged pick (a card id, or ""
## for a skip) to apply at once; a pick that isn't in the offer is refused and the rack stays.
## Without `saves_run` (the --demo-row run) the run never writes or deletes the run save.
func start_new_run(
	seed_value: int, replays_rack: bool = false, replayed_pick: String = "", saves_run: bool = true
) -> void:
	_saves_run = saves_run
	ShiftMusic.new_run(_music)
	var deck: DeckDefinition = load(STARTER_DECK)
	# Phase 3's shopping list will set the list; until then the profile's last one is kept.
	var stock: RunStock = RunStock.build(
		deck, _balance, profile.last_list, profile.unlocked_items, profile.run_count
	)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.IMPULSE_RACK_STREAM
	)
	run = RunState.new(seed_value, deck, _balance, stock, stream)
	# run_end's run_ms counts from here, so the run's length includes the impulse rack.
	_run_started_ms = Time.get_ticks_msec()
	_run_ended_ms = -1
	_log.begin_run()
	_close_overlays()
	_cabinet.set_total_down(false)
	if run.phase != RunState.Phase.IMPULSE:
		_start_first_shift({}, false)
		return
	_show_impulse_rack()
	if replays_rack:
		_replay_impulse_rack(replayed_pick)


## Development tools only (the screen capture in debug/): shows the run's current shift as the
## caller set it up on `run` (its upgrades, inspections, hand and row), like a shift that just
## started: logs shift_start, redraws and saves.
func debug_show_shift() -> void:
	_on_shift_started()


## Development tools only (the screen capture's --scan): ScanController.debug_scan.
func debug_scan(card: CardInstance) -> bool:
	return _scan.debug_scan(card)


## After the impulse rack: logs run_start (with the rack's offer, pick and times, {} for none)
## and starts shift 1.
func _start_first_shift(impulse_timing: Dictionary, deck_viewed: bool) -> void:
	_log.log_event("run_start", RunEvents.run_start(run, impulse_timing, deck_viewed))
	run.start_shift()
	_on_shift_started()


func _on_shift_started() -> void:
	_close_overlays()
	_cabinet.set_total_down(false)
	tracker.begin(Time.get_ticks_msec(), _focus.is_player_present())
	var start: Dictionary = {
		"shift": run.shift_index + 1,
		"quota": run.quota(),
		"cards_drawn": RunEvents.card_ids(run.hand()),
		"inspections": RunEvents.inspection_ids(run.inspections),
	}
	_log.log_event("shift_start", start)
	_refresh()
	_save_run()


## Continues a saved run where it stopped (full build plan section 4), under its run id and with
## its played time, exactly as if it had never stopped. Only run_resume is logged: no
## shift_start, and the shift's checkout measures start over here.
func _resume_run(saved: RunSave) -> void:
	run = saved.run
	_run_started_ms = Time.get_ticks_msec() - saved.run_ms
	_run_ended_ms = -1
	_log.resume_run(saved.run_id)
	_log.log_event("run_resume", RunEvents.run_resume(run, saved.run_ms))
	_close_overlays()
	# A resume never plays a count-up (saves are taken at the rack, the tickets and the click).
	_cabinet.set_total_down(false)
	if run.phase == RunState.Phase.IMPULSE:
		_show_impulse_rack()
		return
	tracker.begin(Time.get_ticks_msec(), _focus.is_player_present())
	_refresh()
	if run.phase == RunState.Phase.PLANNING:
		return
	# After the checkout: the row, its receipt (ended as the dessert left it, with the next
	# shift's inspection notice) and the LED's TOTAL, met or not, as the count-up left them
	# (CHECKOUT up: nothing is being counted).
	_show_checked_out(run.last_result)
	_ride.show_end_state(_row_views)
	_receipt.show_shift_end(
		run.last_result.total, run.quota(), InspectionTag.next_notice(run.next_inspection)
	)
	_count_up.show_end_state(run.last_result, run.quota(), count_up_context())
	_monitor.show_end_state(_count_up.plan, _row_views)
	if run.phase == RunState.Phase.REWARD:
		# No dessert: the print-out is already lifted, on a new timeline.
		_show_rewards(true)
	else:
		_show_upgrades()


## Writes the run save at a save point (full build plan section 4): the rack shown, the shift
## started, every place, remove and redraw, the checkout click and the upgrade tickets shown.
func _save_run() -> void:
	if _saves_run:
		_saves.save_run(run, _log.run_id, Time.get_ticks_msec() - _run_started_ms)


## Hides every panel and lets go of any picked or dragged card.
func _close_overlays() -> void:
	_notice_label.clear_notice()
	_drag.cancel()
	_scan.clear()
	_picked = null
	_picked_from_row = false
	_redraw_mode = false
	_redraw_pick = []
	_results.visible = false
	_reward_panel.visible = false
	_upgrade_panel.visible = false
	_deck_view.visible = false
	_pending_reward = null
	_ride.reset()


# --- Input -------------------------------------------------------------------------------


func _on_hand_card_clicked(view: CardView) -> void:
	if _counting or run.phase != RunState.Phase.PLANNING:
		return
	if _redraw_mode:
		if _redraw_pick.has(view.card):
			_redraw_pick.erase(view.card)
			_sfx.play("card_return")
		elif _redraw_pick.size() < run.balance.redraw_limit:
			_redraw_pick.append(view.card)
			_sfx.play("card_pickup")
	elif _picked == view.card:
		# Let go on the release, unless the press becomes a drag of the picked card.
		_drag.arm(view.card, get_viewport().get_mouse_position(), true)
	else:
		_pick(view.card, false)
		_sfx.play("card_pickup")
		_explain_if_refused(view.card)
		_drag.arm(view.card, get_viewport().get_mouse_position())
	_refresh()


func _on_row_card_clicked(view: CardView) -> void:
	if _counting or _redraw_mode or run.phase != RunState.Phase.PLANNING:
		return
	var slot: int = run.row.find(view.card)
	# A hand card that fits nowhere (the notice says to take a product out) is let go, so this
	# click takes the row card out instead of repeating the refusal.
	if _picked != null and not _picked_from_row and not run.can_place(_picked):
		_drop_pick()
	if _picked != null:
		_place_picked(slot)
	elif run.remove(view.card):
		_pick(view.card, true)
		_sfx.play("card_pickup")
		_drag.arm(view.card, get_viewport().get_mouse_position())
		_refresh()
		_save_run()


func _on_slot_input(event: InputEvent, slot: int) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if not (press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT):
		return
	if _counting or _redraw_mode or _picked == null:
		return
	_place_picked(slot)


## Drag-and-drop: a drop on a slot places the card as a click there would; anywhere else lets
## go of it (a card from the row goes back to the hand). A click on the picked card lets go.
func _on_card_released(card: CardInstance, slot: int, dragged: bool) -> void:
	if _counting or _redraw_mode or _picked != card:
		return
	if dragged and slot >= 0:
		_place_picked(slot, true)
	if _picked == card:
		_let_go(dragged)


## The picked card goes back to the hand (card_return).
func _let_go(dragged: bool = false) -> void:
	_drop_pick(dragged)
	_sfx.play("card_return")
	_refresh()


## Where a dropped card would land: the row is compacted, so a slot past the end is the end.
func _landing_slot(card: CardInstance, slot: int) -> int:
	return mini(slot, run.row.size()) if run.can_place(card) else -1


func _place_picked(slot: int, dragged: bool = false) -> void:
	if run.place(_picked, slot):
		tracker.on_place(dragged)
		_sfx.play("card_place")
		_picked = null
		_picked_from_row = false
		_refresh()
		_save_run()
	else:
		_explain_if_refused(_picked)


## Plan section 3.1: says why a product doesn't fit instead of silently ignoring the click.
func _explain_if_refused(card: CardInstance) -> void:
	if _notice_label.explain_refusal(card.definition, run.limits, run.row):
		_sfx.play("denied", 1.0, REFUSED_DB)


func _pick(card: CardInstance, from_row: bool) -> void:
	_drop_pick()
	_picked = card
	_picked_from_row = from_row


## Lets go of the picked card. A card taken from the row stays in the hand: a removal.
func _drop_pick(dragged: bool = false) -> void:
	if _picked != null and _picked_from_row:
		tracker.on_remove(dragged)
	_picked = null
	_picked_from_row = false


func _on_background_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if not (press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT):
		return
	if _picked != null and not _counting:
		_let_go()


## Redraw mode fans the hand out; confirming shuffles and deals (or, with no pick, backs out).
func _on_redraw_pressed() -> void:
	if not _redraw_mode:
		_redraw_mode = true
		_drop_pick()
		_redraw_pick = []
		_sfx.play("fan")
	elif _redraw_pick.is_empty():
		_redraw_mode = false
		_sfx.play("ui_back")
	else:
		var replaced: Array[CardInstance] = _redraw_pick.duplicate()
		var received: Array[CardInstance] = run.redraw(replaced)
		_log.log_event("redraw", RunEvents.redraw(replaced, received))
		_redraw_mode = false
		_redraw_pick = []
		_save_run()
		_sfx.play("shuffle")
		_sfx.play_series("card_place", received.size(), DEAL_GAP, DEAL_GAP)
	_refresh()


func _on_cancel_pressed() -> void:
	_redraw_mode = false
	_redraw_pick = []
	_refresh()


func _on_checkout_pressed() -> void:
	if _counting or run.phase != RunState.Phase.PLANNING:
		return
	_sfx.play("checkout")
	_counting = true
	# CHECKOUT stays held while the shift is counted, to the dessert's end, and the hand
	# fades so the belt reads first.
	_cabinet.set_total_down(true)
	_stage.dim_hand(true)
	_scan.clear()
	_drop_pick()
	_notice_label.clear_notice()
	_drag.cancel()
	_redraw_mode = false
	_deck_view.visible = false
	_monitor.end_channel()
	_click_ms = Time.get_ticks_msec()
	tracker.on_checkout(_click_ms)
	var committed: Array[CardInstance] = run.row.duplicate()
	var result: ScoreResult = run.checkout()
	# Logged at the click, so closing the game during the count-up loses nothing.
	var checkout_data: Dictionary = {
		"shift": run.shift_index + 1,
		"final_order": RunEvents.card_ids(committed),
		"score": result.total,
		"quota": run.quota(),
		"passed": run.passed(),
		"next_inspection": RunEvents.inspection_id(run.next_inspection),
	}
	checkout_data.merge(tracker.measures(committed.size()))
	_log.log_event("checkout", checkout_data)
	if run.phase == RunState.Phase.WON or run.phase == RunState.Phase.LOST:
		_run_ended_ms = Time.get_ticks_msec()
		_log.log_event("run_end", RunEvents.run_end(run, _run_ended_ms - _run_started_ms))
		# Saved at the click too, so closing the game during the count-up loses nothing.
		profile.record_run(run, _catalogue)
		_profile_saved = _saves.save_profile(profile)
		if _saves_run:
			_saves.delete_run()
	else:
		# The reward waits: quitting during the count-up resumes on it.
		_save_run()
	_refresh()
	_effects.show_count(result, _row_views, run)  # Only the stickers stay, to fire.
	var context: CountUpContext = count_up_context()
	_ride.begin(result, _row_views, context.reduced_motion)
	await _count_up.play(
		result,
		_row_views,
		_names(committed),
		run.quota(),
		context,
		_loyalty_card.stamped_boxes(),
		LoyaltyCard.names(run.upgrades),
		_inspection_tag.sources(run.inspections),
		InspectionTag.names(run.inspections),
		InspectionTag.next_notice(run.next_inspection)
	)
	var shift: int = run.shift_index + 1
	_log.log_event("count_up", RunEvents.count_up_of(_count_up, shift, _click_ms, context))
	_counting = false
	_cabinet.set_total_down(false)
	_stage.dim_hand(false)
	if run.phase == RunState.Phase.REWARD:
		_show_rewards()
	else:
		_show_results(result)


## What the count-up knows about the run (#60, D3): the shift, the best checkout of the run's
## earlier shifts, the player's speed and reduced motion settings, and the receipt's header.
## Called after RunState.checkout(), which has already added the shift being counted to the
## history: its record (the last) is left out.
func count_up_context() -> CountUpContext:
	return CountUpContext.new(
		run.shift_index + 1,
		best_earlier_total(run.history),
		profile.count_up_speed(),
		profile.reduced_motion(),
		receipt_header()
	)


## The receipt's header for the shift on screen (#75): the shift, and the belt's items with its
## coupons. The planning stub, the count-up and a resumed checkout all print it.
func receipt_header() -> PackedStringArray:
	return ReceiptView.header_lines(run.shift_index + 1, run.shift_count(), run.row.size())


## The best total of every shift record but the last (the shift being counted), 0 for none.
static func best_earlier_total(history: Array[ShiftRecord]) -> int:
	var best: int = 0
	for index: int in range(history.size() - 1):
		best = maxi(best, history[index].total)
	return best


## Results screen: New run.
func _on_new_run_pressed() -> void:
	_log.log_event(
		"restart", {"since_run_end_ms": Time.get_ticks_msec() - _run_ended_ms, "screen": "results"}
	)
	start_new_run(_log.new_run_seed())


# --- Impulse rack ----------------------------------------------------------------------------


## Full build plan section 3: before shift 1, pick 1 of the rack's stocked products or skip.
## The reward panel shows it; its pick, skip and deck view go through the reward handlers, and
## RunState takes it like a reward.
func _show_impulse_rack() -> void:
	_refresh()
	# The last run's receipt and totals go: shift 1's preview only shows once it starts.
	_receipt.clear()
	_led.clear()
	_monitor.end_channel()
	_cabinet.set_total_down(false)
	_deck_viewed_for_reward = false
	_pending_reward = null
	_reward_panel.show_rack(run)
	_save_run()


## The debug replay, on the rack shown: applies a logged pick ("" for a skip). A card that isn't
## in the offer is refused and the rack stays. At the deck limit the deck view asks which card
## leaves. A replay applied at once logs 0 times (the player never saw the rack); a refused one,
## or one left to the deck-full chooser, keeps the rack's real timeline for the player's choice.
func _replay_impulse_rack(card_id: String) -> void:
	if card_id.is_empty():
		_reward_panel.timeline = OfferTimeline.new()
		_finish_impulse(null, null)
		return
	for card: CardDefinition in run.impulse_offer:
		if String(card.id) == card_id:
			if not run.deck_is_full():
				_reward_panel.timeline = OfferTimeline.new()
			_on_reward_picked(card)
			return
	_log.log_event("debug", {"action": "impulse_pick_refused", "card": card_id})


## Applies the rack choice (card null = skip), then logs run_start and starts shift 1.
func _finish_impulse(card: CardDefinition, replaced: CardInstance) -> void:
	if run.phase != RunState.Phase.IMPULSE:
		return
	var taken: bool = run.take_reward(card, replaced) if card != null else run.skip_reward()
	if not taken:
		return
	if card != null:
		_sfx.play("card_place")
	_start_first_shift(
		_reward_panel.timeline.fields(Time.get_ticks_msec()), _deck_viewed_for_reward
	)


# --- Rewards and deck view -------------------------------------------------------------------


## The reward print-out (#61), beside the receipt; the register column stays unshaded. It shows
## at the dessert's printer feed (the music comes back there), its items lifting at the player's
## speed setting, skipped with the dessert; `resumed` shows them already lifted.
func _show_rewards(resumed: bool = false) -> void:
	ShiftMusic.rewards_shown(_music)
	_deck_viewed_for_reward = false
	_pending_reward = null
	_reward_panel.print_offer(run, _receipt, _stage, _count_up, resumed)


func _on_reward_picked(card: CardDefinition) -> void:
	if run.phase != RunState.Phase.REWARD and run.phase != RunState.Phase.IMPULSE:
		return
	if not run.deck_is_full():
		_finish_offer(card, null)
		return
	# Plan section 2: at the deck limit, taking a card means choosing one to remove.
	# The forced chooser is not the player choosing to look at their deck.
	_pending_reward = card
	_reward_panel.visible = false
	_deck_view.open(
		run,
		(
			"Cart full (%d/%d): choose an item to remove for %s"
			% [run.deck.size(), run.balance.deck_limit, card.display_name]
		),
		true
	)


func _on_reward_skipped() -> void:
	_finish_offer(null, null)


func _on_deck_card_chosen(card: CardInstance) -> void:
	if _pending_reward != null:
		_finish_offer(_pending_reward, card)


## The panel's choice (card null = skip) for the offer on screen: the impulse rack or a reward.
func _finish_offer(card: CardDefinition, replaced: CardInstance) -> void:
	if run.phase == RunState.Phase.IMPULSE:
		_finish_impulse(card, replaced)
	elif run.phase == RunState.Phase.REWARD:
		_finish_reward(card, replaced)


func _on_deck_closed() -> void:
	if run.phase == RunState.Phase.REWARD or run.phase == RunState.Phase.IMPULSE:
		_pending_reward = null
		_reward_panel.visible = true
	elif run.phase == RunState.Phase.UPGRADE:
		_upgrade_panel.visible = true


func _on_reward_deck_requested() -> void:
	_deck_viewed_for_reward = true
	_reward_panel.visible = false
	_deck_view.open(run, "Your cart (%d/%d)" % [run.deck.size(), run.balance.deck_limit], false)


func _on_deck_button_pressed() -> void:
	# Like the panels' own View cart: an offer can't be hidden before it arms (plan 8's armed_ms).
	if _counting or _reward_panel.is_arming() or _upgrade_panel.is_arming():
		return
	if run.phase == RunState.Phase.REWARD or run.phase == RunState.Phase.IMPULSE:
		_on_reward_deck_requested()
		return
	# The tickets come back when the deck view closes; there is still no way past them.
	_upgrade_panel.visible = false
	_deck_view.open(run, "Your cart (%d/%d)" % [run.deck.size(), run.balance.deck_limit], false)


## Applies the choice (card null = skip), logs it, and starts the next shift, or shows the
## upgrade tickets on an upgrade shift.
func _finish_reward(card: CardDefinition, replaced: CardInstance) -> void:
	var offered: Array[CardDefinition] = run.offer.duplicate()
	var timing: Dictionary = _reward_panel.timeline.fields(Time.get_ticks_msec())
	var taken: bool = run.take_reward(card, replaced) if card != null else run.skip_reward()
	if not taken:
		return
	var shift: int = run.shift_index + 1
	_log.log_event(
		"reward", RunEvents.reward(shift, offered, card, replaced, timing, _deck_viewed_for_reward)
	)
	_pending_reward = null
	_reward_panel.visible = false
	_deck_view.visible = false
	if card != null:  # A skip sounded on its button.
		_sfx.play("card_place")
	if run.phase == RunState.Phase.UPGRADE:
		_show_upgrades()
		return
	run.next_shift()
	_on_shift_started()


# --- Upgrades and the loyalty card ---------------------------------------------------------


## Plan section 3.8: after the reward on an upgrade shift, the player must pick a ticket.
func _show_upgrades() -> void:
	_upgrade_panel.show_offer(run.upgrade_offer)
	_save_run()


func _on_upgrade_picked(upgrade: UpgradeDefinition) -> void:
	if run.phase != RunState.Phase.UPGRADE:
		return
	var offered: Array[UpgradeDefinition] = run.upgrade_offer.duplicate()
	if not run.pick_upgrade(upgrade):
		return
	var timing: Dictionary = _upgrade_panel.timeline.fields(Time.get_ticks_msec())
	_log.log_event("upgrade", RunEvents.upgrade_pick(run.shift_index + 1, offered, upgrade, timing))
	_upgrade_panel.visible = false
	_deck_view.visible = false
	_refresh_loyalty_card()
	_loyalty_card.play_stamp(run.upgrades.size() - 1)
	_sfx.play("stamp_loyalty")
	run.next_shift()
	_on_shift_started()


## One box per upgrade shift, plus one for a starting deck's upgrade (full build plan 7.3).
func _refresh_loyalty_card() -> void:
	_loyalty_card.show_upgrades(LoyaltyCard.box_count(run), run.upgrades)


func _on_export_pressed() -> void:
	var screen: String = "shift"
	if _counting:
		screen = "count_up"
	elif _results.visible:
		screen = "results"
	elif run.phase == RunState.Phase.IMPULSE:
		screen = "impulse_rack"
	elif run.phase == RunState.Phase.REWARD:
		screen = "reward"
	elif run.phase == RunState.Phase.UPGRADE:
		screen = "upgrade"
	_log.export_logs(screen)
	_sfx.play("ui_confirm")


## Planning time pauses while the player is away (FocusWatch).
func _on_focus_exited() -> void:
	tracker.on_focus_lost(Time.get_ticks_msec())


func _on_focus_entered() -> void:
	tracker.on_focus_gained(Time.get_ticks_msec())


# --- Display -------------------------------------------------------------------------------


func _refresh() -> void:
	_shift_label.text = "%d/%d" % [run.shift_index + 1, run.shift_count()]
	_quota_label.text = QuotaMeter.QUOTA_AMOUNT % run.quota()
	_inspection_tag.show_inspections(run.inspections)
	_refresh_loyalty_card()
	_deck_button.caption = "Cart %d/%d" % [run.deck.size(), run.balance.deck_limit]
	_seed_label.text = (
		"Seed %d  ·  %s"
		% [run.run_seed, str(ProjectSettings.get_setting("next_customer/build_label", ""))]
	)
	_refresh_row()
	_refresh_hand()
	_refresh_buttons()
	if not _counting and run.phase == RunState.Phase.PLANNING:
		_refresh_preview()
	_scan.watch(_row_views, _hand_box.cards())


## One slot per card the shift allows (upgrades can add slots), then the row's cards, standing
## on the belt as belt items with their tickets on the rail (RowStrip.show_cards).
func _refresh_row() -> void:
	var closed: int = run.limits.closed_slots + run.limits.closed_coupon_slots
	var reason: String = (
		"Closed by the inspection: %s" % ", ".join(InspectionTag.names(run.inspections))
	)
	_row_strip.set_slot_count(
		RowCapacity.card_limit(run.limits), closed, reason, RowStrip.closed_caption(run.inspections)
	)
	var placeable: bool = _picked != null and run.can_place(_picked)
	_row_views = _row_strip.show_cards(
		run.row, run.row.size() if placeable else -1, _on_row_card_clicked, run.balance
	)


func _refresh_hand() -> void:
	_hand_box.reset(run.balance.hand_size)
	for card: CardInstance in run.hand():
		var view: ItemView = ItemView.new(
			card, run.balance.aisle_of(card.definition), ItemView.Form.BASKET
		)
		view.clicked.connect(_on_hand_card_clicked)
		if _redraw_mode and _redraw_pick.has(card):
			view.set_highlight(CardView.Highlight.REDRAW)
		elif card == _picked:
			view.set_highlight(CardView.Highlight.SELECTED)
		_hand_box.add_card(view)


func _refresh_buttons() -> void:
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _counting
	_checkout_button.disabled = not planning
	var redraw_left: bool = run.redraws_used < run.redraws_allowed
	_redraw_button.disabled = not planning or not redraw_left
	_cancel_button.visible = _redraw_mode
	# Mock-up B2's "Redraw  N left": the count is a note beside the word; screen readers still
	# hear how many items a redraw takes.
	if _redraw_mode:
		var picked: String = "%d/%d" % [_redraw_pick.size(), run.balance.redraw_limit]
		_redraw_button.show_caption("Confirm redraw", picked, "Confirm redraw (%s)" % picked)
	elif redraw_left:
		var left: int = run.redraws_allowed - run.redraws_used
		var spoken: String = "Redraw up to %d items (%d left)" % [run.balance.redraw_limit, left]
		_redraw_button.show_caption("Redraw", "%d left" % left, spoken)
	else:
		_redraw_button.show_caption("Redraw used")


func _refresh_preview() -> void:
	var result: ScoreResult = run.preview()
	tracker.on_preview(run.row.size(), result.total)
	_show_planning(result)
	_show_projected(result.total)


## Planning's monitor and SPEND chip (the user's play test of 2026-10-17): the LED goes blank
## (the last count-up's TOTAL leaves it) and the monitor shows the store channel; the projected
## `total` goes to the top bar's SPEND chip (and is on the receipt). The count-up's subtotal and
## total take the LED from the checkout on.
func _show_projected(total: int) -> void:
	if _led.mode() != LedDisplay.Mode.BLANK:
		_led.clear()
	_quota_meter.show_projected(total, run.quota())
	_monitor.show_channel(run)


## The preview: the itemised planning receipt (#80) and the belt's tags and marks.
func _show_planning(result: ScoreResult) -> void:
	var slots: int = RowCapacity.card_limit(run.limits)
	_receipt.show_planning(receipt_header(), result, _names(run.row), slots, run.quota())
	_show_belt(result)


## A resumed checkout's: the whole receipt as the count-up printed it, under the same header, and
## the belt's tags (BeltRide.show_end_state empties it, as the count-up left it).
func _show_checked_out(result: ScoreResult) -> void:
	var upgrade_names: PackedStringArray = LoyaltyCard.names(run.upgrades)
	var inspection_names: PackedStringArray = InspectionTag.names(run.inspections)
	var names: PackedStringArray = _names(run.row)
	_receipt.show_result(result, names, upgrade_names, inspection_names, receipt_header())
	_show_belt(result, true)


## The belt's tags for a result, with planning's effects unless `paid` (a resumed checkout), no
## marks or paid chips, and the result its scans read.
func _show_belt(result: ScoreResult, paid: bool = false) -> void:
	var upgrade_names: PackedStringArray = LoyaltyCard.names(run.upgrades)
	var inspection_names: PackedStringArray = InspectionTag.names(run.inspections)
	_scan.set_result(result, _names(run.row), upgrade_names, inspection_names)
	_belt_chips.show_all(_row_views)
	if not paid:
		_effects.show_all(result, _row_views, run)
	for slot: int in range(_row_views.size()):
		_row_views[slot].set_tags(result.tags[slot])


## The win and lose screens (plan section 2): the final receipt, with its music cues (the front
## loop now, the coins' duck when they print).
func _show_results(result: ScoreResult) -> void:
	ShiftMusic.results_shown(_music)
	_results.show_results(run, result, profile.coins if _profile_saved else -1, _music)


func _process(_delta: float) -> void:
	_shade.visible = (
		_reward_panel.visible or _upgrade_panel.visible or _deck_view.visible or _results.visible
	)
	# The shade starts under the top bar, wherever the stage sits in the window.
	_shade.offset_top = _stage.position.y + RewardPanel.PRINTOUT_TOP
	# Beside the print-out alone, the register column (the register and the receipt) and the
	# monitor with its totals stay unshaded (#61, #80). The shade starts at the column's place on
	# the stage (its right edge: the register stands at the left since #83), not at a node's
	# rect, so it holds still while the register rattles.
	var beside: bool = _reward_panel.is_printout() and not _deck_view.visible
	var column_end: float = (_stage.get_global_transform() * ShiftStage.REGISTER_RECT).end.x
	_shade.offset_left = column_end if beside else 0.0
	var monitor: Rect2 = _stage.get_global_transform() * MonitorView.DRAWN_RECT
	_shade.set_hole(monitor if beside else Rect2())


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	StoreBackdrop.screen_parts(self, _balance.aisles).gui_input.connect(_on_background_input)
	_stage = ShiftStage.new(_balance.slot_count + _balance.coupon_slot_count)
	# Text on the stage and the overlay without its own font (the count-up's flying numbers,
	# stamps and verdict) uses the number font. The theme stays off the screen's root, so the
	# panels #56 restyles and ShiftDebug's panel keep the plain default font.
	_stage.theme = UiKit.screen_theme()
	add_child(_stage)
	_stage.checkout_pressed.connect(_on_checkout_pressed)
	_stage.redraw_pressed.connect(_on_redraw_pressed)
	_stage.cancel_pressed.connect(_on_cancel_pressed)
	_stage.deck_pressed.connect(_on_deck_button_pressed)
	_stage.export_pressed.connect(_on_export_pressed)
	_top_bar = _stage.top_bar
	_shift_label = _stage.shift_label
	_quota_label = _stage.quota_label
	_loyalty_card = _stage.loyalty_card
	_inspection_tag = _stage.inspection_tag
	_deck_button = _stage.deck_button
	_seed_label = _stage.seed_label
	_register = _stage.register
	_cabinet = _stage.cabinet
	_monitor = _stage.monitor
	_monitor.reduced_motion = func() -> bool: return profile.reduced_motion()
	_led = _stage.led
	_quota_meter = _stage.top_bar.quota_meter
	_quota_meter.reduced_motion = _monitor.reduced_motion
	_receipt = _stage.receipt
	_row_strip = _stage.row_strip
	_row_strip.slot_input.connect(_on_slot_input)
	_row_strip.closed_clicked.connect(_on_closed_slot_clicked)
	# The same array as the strip's, kept in place across rebuilds, so CardDrag sees new slots.
	_slots = _row_strip.slots
	_notice_label = _stage.notice_label
	_cancel_button = _stage.cancel_button
	_redraw_button = _stage.redraw_button
	_checkout_button = _stage.checkout_button
	_hand_box = _stage.hand

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.theme = _stage.theme
	add_child(_overlay)
	_sfx = Sfx.new()
	add_child(_sfx)
	_focus = FocusWatch.new()
	add_child(_focus)
	_focus.player_left.connect(_on_focus_exited)
	_focus.player_returned.connect(_on_focus_entered)
	_count_up = CountUp.new()
	add_child(_count_up)
	_count_up.setup(_overlay, _receipt, _led, _sfx, _register)
	_count_up.music = _music
	_ride = BeltRide.new()
	add_child(_ride)
	_ride.setup(_count_up, _stage)
	_monitor.follow(_count_up)
	_drag = CardDrag.new()
	add_child(_drag)
	_drag.setup(_overlay, _slots, _hand_box, _landing_slot)
	_drag.released.connect(_on_card_released)
	_scan = ScanController.new()
	add_child(_scan)
	_scan.setup(_stage)
	_scan.blocked = _scan_blocked
	_scan.reduced_motion = func() -> bool: return profile.reduced_motion()
	_focus.player_left.connect(_scan.clear)
	_effects = PlanningEffects.new()
	add_child(_effects)
	_effects.setup(_stage, _drag)
	_effects.preview = func(card: CardInstance, at: int) -> ScoreResult:
		return run.preview(card, at)
	_effects.reduced_motion = _scan.reduced_motion

	_shade = ScreenShade.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Below the top bar, so the menu and Cart stay reachable on every screen (_process keeps it
	# there when the stage moves).
	_shade.offset_top = RewardPanel.PRINTOUT_TOP
	_shade.visible = false
	add_child(_shade)
	_reward_panel = RewardPanel.new()
	add_child(_reward_panel)
	_reward_panel.picked.connect(_on_reward_picked)
	_reward_panel.skipped.connect(_on_reward_skipped)
	_reward_panel.deck_requested.connect(_on_reward_deck_requested)
	_scan.cover_offers(_reward_panel)
	_upgrade_panel = UpgradePanel.new()
	add_child(_upgrade_panel)
	_upgrade_panel.picked.connect(_on_upgrade_picked)
	_results = ResultsPanel.new()
	add_child(_results)
	_results.new_run_requested.connect(_on_new_run_pressed)
	_results.export_requested.connect(_on_export_pressed)
	# Added last, so the deck view sits above the reward panel and the results.
	_deck_view = DeckView.new()
	add_child(_deck_view)
	_deck_view.card_chosen.connect(_on_deck_card_chosen)
	_deck_view.closed.connect(_on_deck_closed)


## Scanning the counter's items is off while the shift is counted, an item is dragged, outside
## planning (an offer, the upgrade tickets or the results are up) and while the deck view is
## open. The offers' items are scanned while their panel accepts clicks (RewardPanel.can_scan).
func _scan_blocked() -> bool:
	var planning: bool = run != null and run.phase == RunState.Phase.PLANNING
	return _counting or _drag.is_dragging() or not planning or _deck_view.visible


func _on_closed_slot_clicked() -> void:
	_notice_label.show_notice("Closed by the inspection this shift")
	_sfx.play("denied", 1.0, REFUSED_DB)


static func _names(cards: Array[CardInstance]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for card: CardInstance in cards:
		names.append(card.definition.display_name)
	return names
