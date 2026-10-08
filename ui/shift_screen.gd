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
## coupon slot (a coupon can go anywhere), and the capacity label counts it instead.

const STARTER_DECK := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"

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

var _shift_label: Label
var _quota_label: Label
var _inspection_tag: InspectionTag
var _loyalty_card: LoyaltyCard
var _deck_button: Button
var _seed_label: Label
var _slots: Array[PanelContainer] = []
var _row_views: Array[CardView] = []
var _hand_box: HBoxContainer
var _projected_label: Label
var _capacity_label: Label
var _notice_label: NoticeLabel
var _drag: CardDrag
var _subtotal_label: Label
var _receipt: ReceiptView
var _redraw_button: Button
var _cancel_button: Button
var _checkout_button: Button
var _results: ResultsPanel
var _reward_panel: RewardPanel
var _upgrade_panel: UpgradePanel
## Dims the screen and blocks clicks behind the reward and upgrade panels, deck view and
## results.
var _shade: ColorRect
var _deck_view: DeckView
var _row_box: HBoxContainer
var _row_strip: RowStrip
var _overlay: Control
var _count_up: CountUp
var _sfx: Sfx
var _debug: ShiftDebug
var _focus: FocusWatch
## The EventLog autoload, typed. Fetched from the tree because standalone script checks
## don't know autoload names.
@onready var _log: EventLogService = get_node("/root/EventLog")


func _ready() -> void:
	_balance = load(BALANCE)
	_catalogue = load(CATALOGUE)
	_saves = SaveService.new(SaveService.default_folder(), report_error)
	profile = _saves.load_profile()
	_build()
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
	if run.phase != RunState.Phase.IMPULSE:
		_start_first_shift({}, false)
		return
	_show_impulse_rack()
	if replays_rack:
		_replay_impulse_rack(replayed_pick)


## After the impulse rack: logs run_start (with the rack's offer, pick and times, {} for none)
## and starts shift 1.
func _start_first_shift(impulse_timing: Dictionary, deck_viewed: bool) -> void:
	_log.log_event("run_start", RunEvents.run_start(run, impulse_timing, deck_viewed))
	run.start_shift()
	_on_shift_started()


func _on_shift_started() -> void:
	_close_overlays()
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
	if run.phase == RunState.Phase.IMPULSE:
		_show_impulse_rack()
		return
	tracker.begin(Time.get_ticks_msec(), _focus.is_player_present())
	_refresh()
	if run.phase == RunState.Phase.PLANNING:
		return
	# After the checkout: the row, its receipt (with the next shift's inspection notice) and
	# totals as the count-up left them.
	_show_score(run.last_result)
	var notice: String = InspectionTag.next_notice(run.next_inspection)
	if not notice.is_empty():
		_receipt.add_notice(notice)
	_show_projected(run.last_result.total)
	_subtotal_label.text = "€%d" % run.last_result.total
	if run.phase == RunState.Phase.REWARD:
		_show_rewards(run.last_result)
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
	_picked = null
	_picked_from_row = false
	_redraw_mode = false
	_redraw_pick = []
	_results.visible = false
	_reward_panel.visible = false
	_upgrade_panel.visible = false
	_deck_view.visible = false
	_pending_reward = null


# --- Input -------------------------------------------------------------------------------


func _on_hand_card_clicked(view: CardView) -> void:
	if _counting or run.phase != RunState.Phase.PLANNING:
		return
	if _redraw_mode:
		if _redraw_pick.has(view.card):
			_redraw_pick.erase(view.card)
		elif _redraw_pick.size() < run.balance.redraw_limit:
			_redraw_pick.append(view.card)
	elif _picked == view.card:
		# Let go on the release, unless the press becomes a drag of the picked card.
		_drag.arm(view.card, get_viewport().get_mouse_position(), true)
	else:
		_pick(view.card, false)
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
		_drop_pick(dragged)
		_refresh()


## Where a dropped card would land: the row is compacted, so a slot past the end is the end.
func _landing_slot(card: CardInstance, slot: int) -> int:
	return mini(slot, run.row.size()) if run.can_place(card) else -1


func _place_picked(slot: int, dragged: bool = false) -> void:
	if run.place(_picked, slot):
		tracker.on_place(dragged)
		_sfx.play("click", 1.2)
		_picked = null
		_picked_from_row = false
		_refresh()
		_save_run()
	else:
		_explain_if_refused(_picked)


## Plan section 3.1: says why a product doesn't fit instead of silently ignoring the click.
func _explain_if_refused(card: CardInstance) -> void:
	if _notice_label.explain_refusal(card.definition, run.limits, run.row):
		_sfx.play("denied", 1.4, -6.0)


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
		_drop_pick()
		_refresh()


func _on_redraw_pressed() -> void:
	if not _redraw_mode:
		_redraw_mode = true
		_drop_pick()
		_redraw_pick = []
	elif _redraw_pick.is_empty():
		_redraw_mode = false
	else:
		var replaced: Array[CardInstance] = _redraw_pick.duplicate()
		var received: Array[CardInstance] = run.redraw(replaced)
		_log.log_event("redraw", RunEvents.redraw(replaced, received))
		_redraw_mode = false
		_redraw_pick = []
		_save_run()
	_refresh()


func _on_cancel_pressed() -> void:
	_redraw_mode = false
	_redraw_pick = []
	_refresh()


func _on_checkout_pressed() -> void:
	if _counting or run.phase != RunState.Phase.PLANNING:
		return
	_counting = true
	_drop_pick()
	_notice_label.clear_notice()
	_drag.cancel()
	_redraw_mode = false
	_deck_view.visible = false
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
	await _count_up.play(
		result,
		_row_views,
		_names(committed),
		run.quota(),
		_loyalty_card.stamped_boxes(),
		LoyaltyCard.names(run.upgrades),
		_inspection_tag.sources(run.inspections),
		InspectionTag.names(run.inspections),
		InspectionTag.next_notice(run.next_inspection)
	)
	var counted: Dictionary = RunEvents.count_up(
		run.shift_index + 1,
		_click_ms,
		_count_up.total_shown_ms,
		_count_up.fast_forward_used,
		_count_up.first_tap_ms,
		_count_up.dessert_skipped
	)
	_log.log_event("count_up", counted)
	_counting = false
	if run.phase == RunState.Phase.REWARD:
		_show_rewards(result)
	else:
		_show_results(result)


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
	_projected_label.text = ""
	_subtotal_label.text = ""
	_deck_viewed_for_reward = false
	_pending_reward = null
	_reward_panel.show_offer(
		run.impulse_offer,
		"Impulse rack: grab one before shift 1?",
		run.deck.size(),
		run.balance.deck_limit
	)
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
	_sfx.play("click")
	_start_first_shift(
		_reward_panel.timeline.fields(Time.get_ticks_msec()), _deck_viewed_for_reward
	)


# --- Rewards and deck view -------------------------------------------------------------------


func _show_rewards(result: ScoreResult) -> void:
	_deck_viewed_for_reward = false
	_pending_reward = null
	_reward_panel.show_offer(
		run.offer,
		"Shift passed!  €%d / €%d" % [result.total, run.quota()],
		run.deck.size(),
		run.balance.deck_limit,
		InspectionTag.next_notice(run.next_inspection)
	)


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
			"Deck full (%d/%d): choose a card to remove for %s"
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
	_deck_view.open(run, "Your deck (%d/%d)" % [run.deck.size(), run.balance.deck_limit], false)


func _on_deck_button_pressed() -> void:
	# Like the panels' own View deck: an offer can't be hidden before it arms (plan 8's armed_ms).
	if _counting or _reward_panel.is_arming() or _upgrade_panel.is_arming():
		return
	if run.phase == RunState.Phase.REWARD or run.phase == RunState.Phase.IMPULSE:
		_on_reward_deck_requested()
		return
	# The tickets come back when the deck view closes; there is still no way past them.
	_upgrade_panel.visible = false
	_deck_view.open(run, "Your deck (%d/%d)" % [run.deck.size(), run.balance.deck_limit], false)


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
	_sfx.play("click")
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
	_sfx.play("stamp")
	run.next_shift()
	_on_shift_started()


## One box per upgrade shift, plus one for a starting deck's upgrade (full build plan 7.3).
func _refresh_loyalty_card() -> void:
	var boxes: int = run.balance.upgrade_shifts.size()
	_loyalty_card.show_upgrades(
		boxes + (0 if run.starter.starting_upgrade == null else 1), run.upgrades
	)


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


## Planning time pauses while the player is away (FocusWatch).
func _on_focus_exited() -> void:
	tracker.on_focus_lost(Time.get_ticks_msec())


func _on_focus_entered() -> void:
	tracker.on_focus_gained(Time.get_ticks_msec())


# --- Display -------------------------------------------------------------------------------


func _refresh() -> void:
	_shift_label.text = "Shift %d / %d" % [run.shift_index + 1, run.shift_count()]
	_quota_label.text = "Quota €%d" % run.quota()
	_inspection_tag.show_inspections(run.inspections)
	_refresh_loyalty_card()
	_deck_button.text = "Deck %d/%d" % [run.deck.size(), run.balance.deck_limit]
	_seed_label.text = "Seed %d" % run.run_seed
	_capacity_label.text = (
		"Products %d/%d  ·  Coupon slot%s %d/%d"
		% [
			RowCapacity.product_count(run.row),
			run.limits.slot_count,
			"s" if run.limits.coupon_slot_count > 1 else "",
			RowCapacity.coupon_slots_used(run.limits, run.row),
			run.limits.coupon_slot_count
		]
	)
	_refresh_row()
	_refresh_hand()
	_refresh_buttons()
	if not _counting and run.phase == RunState.Phase.PLANNING:
		_refresh_preview()


## One slot per card the shift allows (upgrades can add slots), then the row's cards.
func _refresh_row() -> void:
	_row_strip.set_slot_count(RowCapacity.card_limit(run.limits))
	var placeable: bool = _picked != null and run.can_place(_picked)
	_row_views = _row_strip.show_cards(
		run.row, run.row.size() if placeable else -1, _on_row_card_clicked
	)


func _refresh_hand() -> void:
	for child: Node in _hand_box.get_children():
		_hand_box.remove_child(child)
		child.queue_free()
	for card: CardInstance in run.hand():
		var view: CardView = CardView.new(card)
		view.clicked.connect(_on_hand_card_clicked)
		if _redraw_mode and _redraw_pick.has(card):
			view.set_highlight(CardView.Highlight.REDRAW)
		elif card == _picked:
			view.set_highlight(CardView.Highlight.SELECTED)
		_hand_box.add_child(view)


func _refresh_buttons() -> void:
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _counting
	_checkout_button.disabled = not planning
	var redraw_left: bool = run.redraws_used < run.redraws_allowed
	_redraw_button.disabled = not planning or not redraw_left
	_cancel_button.visible = _redraw_mode
	if _redraw_mode:
		_redraw_button.text = (
			"Confirm redraw (%d/%d)" % [_redraw_pick.size(), run.balance.redraw_limit]
		)
	elif redraw_left:
		_redraw_button.text = (
			"Redraw up to %d (%d left)"
			% [run.balance.redraw_limit, run.redraws_allowed - run.redraws_used]
		)
	else:
		_redraw_button.text = "Redraw used"


func _refresh_preview() -> void:
	var result: ScoreResult = run.preview()
	tracker.on_preview(run.row.size(), result.total)
	_show_score(result)
	_show_projected(result.total)
	# The big subtotal belongs to the count-up; while planning, the projected total is enough.
	_subtotal_label.text = ""


## The projected total, green when it meets the quota. The count-up leaves the last one shown.
func _show_projected(total: int) -> void:
	_projected_label.text = "Projected €%d" % total
	_projected_label.add_theme_color_override(
		"font_color", Palette.GOOD if total >= run.quota() else Palette.TOMATO
	)


## The row's receipt and value badges for a result: the preview, or a resumed checkout's.
func _show_score(result: ScoreResult) -> void:
	_receipt.show_result(
		result,
		_names(run.row),
		LoyaltyCard.names(run.upgrades),
		InspectionTag.names(run.inspections)
	)
	for slot: int in range(_row_views.size()):
		_row_views[slot].show_badge(result.payouts[slot], false)
		_row_views[slot].set_tags(result.tags[slot])


## The win and lose screens (plan section 2).
func _show_results(result: ScoreResult) -> void:
	_results.show_results(run, result, profile.coins if _profile_saved else -1)


func _process(_delta: float) -> void:
	_shade.visible = (
		_reward_panel.visible or _upgrade_panel.visible or _deck_view.visible or _results.visible
	)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.gui_input.connect(_on_background_input)
	add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 28)
	page.add_child(top)
	_shift_label = _info_label(top, 22)
	_quota_label = _info_label(top, 22)
	_inspection_tag = InspectionTag.new()
	_inspection_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_inspection_tag)
	_loyalty_card = LoyaltyCard.new()
	_loyalty_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_loyalty_card)
	_deck_button = UiKit.button(top, "", _on_deck_button_pressed, 16)
	_seed_label = _info_label(top, 16)
	var build: Label = _info_label(top, 14)
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.text = str(ProjectSettings.get_setting("next_customer/build_label", ""))
	UiKit.button(top, "Export log", _on_export_pressed, 14)

	var middle: HBoxContainer = HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 24)
	page.add_child(middle)
	var row_column: VBoxContainer = VBoxContainer.new()
	row_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_column.add_theme_constant_override("separation", 10)
	middle.add_child(row_column)
	var row_header: HBoxContainer = HBoxContainer.new()
	row_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Room above the row for the value badges over each card.
	row_header.custom_minimum_size = Vector2(0, 72)
	row_column.add_child(row_header)
	var row_title: Label = _info_label(row_header, 16)
	row_title.text = "CHECKOUT  (scanned left to right)"
	row_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_capacity_label = _info_label(row_header, 16)
	_capacity_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_capacity_label.modulate = Color(1, 1, 1, 0.75)
	# 7 slots and the receipt fit the 1280 px window (plan section 3.1); a wider row scales.
	_row_strip = RowStrip.new()
	_row_strip.slot_input.connect(_on_slot_input)
	row_column.add_child(_row_strip)
	_row_box = _row_strip.box
	# The same array as the strip's, kept in place across rebuilds, so CardDrag sees new slots.
	_slots = _row_strip.slots
	_row_strip.set_slot_count(_balance.slot_count + _balance.coupon_slot_count)
	var totals: HBoxContainer = HBoxContainer.new()
	totals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	totals.add_theme_constant_override("separation", 30)
	row_column.add_child(totals)
	_projected_label = _info_label(totals, 30)
	_subtotal_label = _info_label(totals, 44)
	_subtotal_label.add_theme_color_override("font_color", Palette.MUSTARD)
	_subtotal_label.add_theme_constant_override("outline_size", 8)
	_subtotal_label.add_theme_color_override("font_outline_color", Palette.INK)
	_notice_label = NoticeLabel.new()
	totals.add_child(_notice_label)
	_receipt = ReceiptView.new()
	_receipt.custom_minimum_size = Vector2(300, 0)
	_receipt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_receipt)

	var hint: Label = _info_label(page, 14)
	hint.text = (
		"Click a card then a slot, or drag it there  ·  click or drag a placed card to take it back"
		+ "  ·  tap Space or the mouse to skip the count, hold to fast-forward"
	)
	hint.modulate = Color(1, 1, 1, 0.6)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 16)
	page.add_child(bottom)
	_hand_box = HBoxContainer.new()
	_hand_box.custom_minimum_size = Vector2(0, CardView.CARD_SIZE.y + 12)
	_hand_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hand_box.add_theme_constant_override("separation", 8)
	_hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_hand_box)
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(170, 0)
	buttons.add_theme_constant_override("separation", 10)
	bottom.add_child(buttons)
	_checkout_button = UiKit.button(buttons, "CHECKOUT", _on_checkout_pressed, 22)
	_checkout_button.custom_minimum_size = Vector2(0, 70)
	_redraw_button = UiKit.button(buttons, "", _on_redraw_pressed, 15)
	_cancel_button = UiKit.button(buttons, "Cancel", _on_cancel_pressed, 14)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_sfx = Sfx.new()
	add_child(_sfx)
	_focus = FocusWatch.new()
	add_child(_focus)
	_focus.player_left.connect(_on_focus_exited)
	_focus.player_returned.connect(_on_focus_entered)
	_count_up = CountUp.new()
	add_child(_count_up)
	_count_up.setup(_overlay, _receipt, _subtotal_label, _sfx, _row_box)
	_drag = CardDrag.new()
	add_child(_drag)
	_drag.setup(_overlay, _slots, _hand_box, _landing_slot)
	_drag.released.connect(_on_card_released)

	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.5)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Below the top bar, so Export log and Deck stay reachable on every screen.
	_shade.offset_top = 64
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.visible = false
	add_child(_shade)
	_reward_panel = RewardPanel.new()
	add_child(_reward_panel)
	_reward_panel.picked.connect(_on_reward_picked)
	_reward_panel.skipped.connect(_on_reward_skipped)
	_reward_panel.deck_requested.connect(_on_reward_deck_requested)
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


func _info_label(parent: Control, font_size: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.LIGHT_TEXT)
	parent.add_child(label)
	return label


static func _names(cards: Array[CardInstance]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for card: CardInstance in cards:
		names.append(card.definition.display_name)
	return names
