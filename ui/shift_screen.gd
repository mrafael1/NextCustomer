class_name ShiftScreen
extends Control
## The shift screen (plan section 2): draw, redraw, click-to-place into the row, the live
## projected total and receipt, checkout with the count-up, the RECEIPT REWARDS machine's visits
## after a passed shift (#77, MachineFlow) and the loyalty card (plan section 3.8), the shift's
## inspection and the next one's notice (plan section 3.9), the deck view, and the run's results
## with its history. It only displays RunState and ScoreResult; every rule lives in core/. The
## run is saved at every stable point and resumed when the screen opens (full build plan section
## 4); the debug tools live in ShiftDebug.
##
## Click-to-place: click a hand card to pick it up, then click a slot to put it there (a
## filled slot pushes the cards from there to the right). Click a row card to pick it back up.
## Drag-and-drop does the same (CardDrag): drop on a slot to place, anywhere else to let go.
## Hand items keep their places (plan section 3.8): one placed on the belt leaves its place empty
## and one taken back returns to it.
##
## The basket redraw (plan section 3.8; mock-up redraw_basket_v1.html): the Redraw key arms redraw
## mode ("Pick a basket", with Cancel), each basket that can be redrawn shows a REDRAW tag
## (BasketTags) and the monitor explains (RedrawPanel); clicking one redraws it at once (logged and
## saved) and BasketRedraw plays the motion, every click blocked until it ends. Redraw mode ends
## with the click.
##
## The row has slot_count general slots (plan section 3.1, v0.46): any card fits any free slot.
## The row is compacted, so its slots alone show the capacity, and RowCapacity enforces it.
##
## The layout (#55; full build plan section 6.1) is ShiftStage's: a 1280x720 stage centred in the
## window over a wall and a counter that fill it. The screen keeps its own names for the stage's
## controls and fills them. Machine v2 (#77, Q1 = A): the store (the backdrop and the stage's
## world, with the machine on the back wall) is in the StoreCamera, which glides to the machine at
## 2x for its visits and back after the last one (MachineFlow); the top band and the stage's hud
## (the top bar, the scan and popup layers) never zoom. Planning input waits for the glide back.
##
## Sounds (#62) play on the screen's own Sfx, warmed up when it opens: cards picked up, placed
## and let go, refusals, the redraw, CHECKOUT and the log export here, a prize in MachineFlow;
## buttons and panels in UiKit, drag slot ticks in CardDrag, music in ShiftMusic. The only hover
## sound is the scanner's beep (#75, ScanController), played once a hover on an item is held.

## The game's starting deck: a recipe (v0.49) dealt from each run's stock (StartingDeck).
const STARTER_DECK := "res://data/decks/pack_starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
## A refused card or a closed slot plays `denied` this much softer than the count-up does.
const REFUSED_DB := -6.0
## The Redraw key's caption while redraw mode is armed.
const PICK_CAPTION := "Pick a basket"
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
## Redraw mode (plan section 3.8): armed by the Redraw key until a basket is picked or it is
## cancelled, and the redraw's motion playing (every click blocked). Neither is saved.
var _redraw_mode: bool = false
var _redraw_busy: bool = false
var _counting: bool = false
var _run_started_ms: int = 0
var _run_ended_ms: int = -1

## The 1280x720 stage, centred in the window (its hud; its world is in the camera).
var _stage: ShiftStage
## The store's camera (#77 machine v2) and the wall in it, which takes the background clicks.
var _camera: StoreCamera
var _wall: ColorRect
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
## The RECEIPT REWARDS machine's visits (#77) and the machine on screen.
var _machine: MachineFlow
## Dims the screen and blocks clicks behind the deck view and the results.
var _shade: ScreenShade
var _deck_view: DeckView
var _row_strip: RowStrip
## The register: the count-up's rattle target (the same node as `_cabinet`); its
## set_total_down() marks CHECKOUT held while the shift is counted.
var _register: Control
var _cabinet: RegisterCabinet
## The hung monitor (#80; one screen since #105 piece 2): the bay, the item column, the checkout
## column, the notices and the count-up's beats.
var _monitor: MonitorView
## The monitor's LED: blank in planning, the count-up's subtotal and total.
var _led: LedDisplay
## The top bar's SPEND chip: the projected total in planning (fed here), the LED's while counting.
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
var _ride: BeltRide  # The belt in the count (#86 v6): items ride to the scanner and bag.
var _effects: PlanningEffects  # The planning effects (#71, mock-up h1).
var _toys: ToyMachinesScreen  # The TOY MACHINES over the results (#63), made when first opened.
var _cart_reveal: CartReveal
var _week: WeekFlow  # The time card and the week and day chips (v0.70).
var _start_choice: StartChoice  # The starter pack choice's part of a run's start (#107).
var _glyph_tips: GlyphTips  # Family glyphs' tooltips (#105): none in a drag or the count.
## The basket redraw's targets and tags, and its motion.
var _basket_tags: BasketTags
var _basket_redraw: BasketRedraw
var _full_redraw: FullRedrawFlow  # A badge pin's REDRAW ALL (#122).
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
	_start_choice = StartChoice.new(self, _log)
	_full_redraw = FullRedrawFlow.new(self, _log)
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
		start_new_run(_log.new_run_seed(), true, _cart_reveal.requested)


## Starts a run with a seed (a new random one, or one set from the debug panel) and its first
## shift. Without `saves_run` (the --demo-row run) the run never writes or deletes the run save.
## With `reveal` the cart reveal (v0.51) opens over shift 1 once it is dealt and saved.
func start_new_run(seed_value: int, saves_run: bool = true, reveal: bool = false) -> void:
	_saves_run = saves_run
	ShiftMusic.new_run(_music)
	run = _start_choice.new_run(seed_value, _balance, load(STARTER_DECK))
	_run_started_ms = Time.get_ticks_msec()
	_run_ended_ms = -1
	_log.begin_run()
	_machine.reset_swaps()
	_close_overlays()
	_cabinet.set_total_down(false)
	_log.log_event("run_start", RunEvents.run_start(run))
	if _start_choice.begin_if_choosing(reveal):  # #107: the starter pack choice, then shift 1.
		return
	run.start_shift()
	_on_shift_started()
	if reveal and _cart_reveal.play(run, _deck_button, profile.reduced_motion()):
		_machine.hold_notice()  # Planning takes input after the reveal (_on_cart_reveal_finished).


## The cart reveal folded away: shift 1's planning takes input only now, so its time to checkout
## (plan section 8) starts here and the machine's notice pulses now, not under the reveal's dim.
func _on_cart_reveal_finished() -> void:
	tracker.begin(Time.get_ticks_msec(), _focus.is_player_present())
	_machine.shift_started()


## Development tools only (the screen capture in debug/): shows the run's current shift as the
## caller set it up on `run` (its upgrades, inspections, hand and row), like a shift that just
## started: logs shift_start, redraws and saves.
func debug_show_shift() -> void:
	_on_shift_started()


## Development tools only (the screen capture's --scan): ScanController.debug_scan.
func debug_scan(card: CardInstance) -> bool:
	return _scan.debug_scan(card)


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
	_machine.shift_started()  # Shows the shift's notice once planning takes input.


## The notice a shift opens with (v0.68, WriteUp.shift_notice): after a slip, or on the first
## shift after the training week (a resume shows it again), once planning takes input.
func show_shift_notice() -> void:
	var notice: String = WriteUp.shift_notice(run)
	if not notice.is_empty():
		_notice_label.show_notice(notice)


## Continues a saved run where it stopped (full build plan section 4), under its run id and with
## its played time, exactly as if it had never stopped. Only run_resume is logged: no
## shift_start, and the shift's checkout measures start over here.
func _resume_run(saved: RunSave) -> void:
	run = saved.run
	_run_started_ms = Time.get_ticks_msec() - saved.run_ms
	_run_ended_ms = -1
	_log.resume_run(saved.run_id)
	_log.log_event("run_resume", RunEvents.run_resume(run, saved.run_ms))
	_machine.reset_swaps()
	_close_overlays()
	# A resume never plays a count-up (saves are taken at the click and the machine's visits).
	_cabinet.set_total_down(false)
	if run.phase == RunState.Phase.SCORED:
		# The shift's last visit was done, or a slip (v0.68): the next shift starts, with its
		# notice (_on_shift_started).
		run.next_shift()
		_on_shift_started()
		return
	if _start_choice.begin_if_choosing(true):  # #107: the same offer waits for its pick.
		return
	tracker.begin(Time.get_ticks_msec(), _focus.is_player_present())
	_refresh()
	if run.phase == RunState.Phase.PLANNING:
		_machine.shift_started(false)
		return
	# After the checkout: the row, its receipt (ended as the dessert left it, with the next
	# shift's inspection notice) and the LED's TOTAL, met or not, as the count-up left them
	# (CHECKOUT up: nothing is being counted).
	_show_checked_out(run.last_result)
	_ride.show_end_state(_row_views)
	_receipt.show_shift_end(
		run.last_result.total,
		run.quota(),
		InspectionTag.next_notice(run.next_inspections),
		", ".join(InspectionTag.names(InspectionDefinition.maluses(run.inspections)))
	)
	_count_up.show_end_state(run.last_result, run.quota(), count_up_context())
	var record: ShiftRecord = run.history[-1]
	var passed: bool = record.passed and record.inspection != null
	_monitor.show_end_state(_count_up.plan, _row_views, passed, run.last_result, _scan.line_of)
	_machine.open(true)  # No dessert: the visit shows as it waits, on a new timeline.


## Saves the profile now (the debug panel's Profile tools); false (reported) when it can't be.
func save_profile() -> bool:
	return _saves.save_profile(profile)


## Writes the run save at a save point (full build plan section 4): the shift started, every
## place, remove and redraw, the checkout click, and the machine's draws and visits.
func _save_run() -> void:
	if _saves_run:
		_saves.save_run(run, _log.run_id, Time.get_ticks_msec() - _run_started_ms)


## Hides every panel and lets go of any picked or dragged card.
func _close_overlays() -> void:
	_notice_label.clear_notice()
	# The torn receipt went into the machine (#77 machine v2): the next one prints here.
	_receipt.visible = true
	_drag.cancel()
	_scan.clear()
	_picked = null
	_picked_from_row = false
	_redraw_mode = false
	_redraw_busy = false
	_basket_redraw.stop()
	_basket_tags.hide_tags()
	_monitor.show_redraw(null)
	_results.visible = false
	_machine.close()
	_deck_view.visible = false
	_cart_reveal.close()
	_ride.reset()


# --- Input -------------------------------------------------------------------------------


func _on_hand_card_clicked(view: CardView) -> void:
	if _busy() or _redraw_mode or _redraw_busy or run.phase != RunState.Phase.PLANNING:
		return
	if _picked == view.card:
		# Let go on the release, unless the press becomes a drag of the picked card.
		_drag.arm(view.card, get_viewport().get_mouse_position(), true)
	else:
		_pick(view.card, false)
		_sfx.play("card_pickup")
		_explain_if_refused()
		_drag.arm(view.card, get_viewport().get_mouse_position())
	_refresh()


func _on_row_card_clicked(view: CardView) -> void:
	if _busy() or _redraw_mode or _redraw_busy or run.phase != RunState.Phase.PLANNING:
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
	if _busy() or _redraw_mode or _redraw_busy or _picked == null:
		return
	_place_picked(slot)


## Drag-and-drop: a drop on a slot places the card as a click there would; anywhere else lets
## go of it (a card from the row goes back to the hand). A click on the picked card lets go.
func _on_card_released(card: CardInstance, slot: int, dragged: bool) -> void:
	if _busy() or _redraw_mode or _picked != card:
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
		_explain_if_refused()


## Plan section 3.1: says why a card doesn't fit instead of silently ignoring the click.
func _explain_if_refused() -> void:
	if _notice_label.explain_refusal(run.limits, run.row):
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
	if _picked != null and not _busy():
		_let_go()


## The Redraw key arms redraw mode (plan section 3.8: "Pick a basket"); pressed again, it backs
## out as Cancel does.
func _on_redraw_pressed() -> void:
	if _busy() or _redraw_busy or run.phase != RunState.Phase.PLANNING:
		return
	if _redraw_mode:
		_redraw_mode = false
		_sfx.play("ui_back")
	else:
		_redraw_mode = true
		_drop_pick()
		_drag.cancel()
		_scan.clear()
		_sfx.play("fan")
	_refresh()


func _on_cancel_pressed() -> void:
	if _redraw_busy:
		return
	_redraw_mode = false
	_refresh()


## A basket picked in redraw mode (plan section 3.8): the run swaps its items at the click (logged
## and saved), redraw mode ends and the motion plays, blocking every click until it ends. Sounds:
## `shuffle` now, then one `card_place` as each new item pops up.
func _on_basket_clicked(basket: int) -> void:
	if not _redraw_mode or _redraw_busy or _busy() or not run.can_redraw_basket(basket):
		return
	var before: Array[CardInstance] = run.hand_places()
	var places: Array[int] = run.redraw_basket(basket)
	if places.is_empty():
		return
	var after: Array[CardInstance] = run.hand_places()
	var replaced: Array[CardInstance] = []
	var received: Array[CardInstance] = []
	var old_views: Array[Control] = []
	var new_views: Array[Control] = []
	for place: int in places:
		replaced.append(before[place])
		received.append(after[place])
		old_views.append(BasketRedraw.ghost(before[place], run.balance))
		new_views.append(BasketRedraw.ghost(after[place], run.balance))
	_log.log_event("redraw", RunEvents.redraw(basket, places, replaced, received))
	_redraw_mode = false
	_redraw_busy = true
	_save_run()
	var tuning: RedrawTuning = _basket_redraw.tuning
	var reduced: bool = profile.reduced_motion()
	var first: float = tuning.pop_start(0, reduced)
	_sfx.play("shuffle")
	_sfx.play_series("card_place", received.size(), tuning.pop_start(1, reduced) - first, first)
	_refresh()
	var left: int = run.redraws_allowed - run.redraws_used
	_monitor.show_redraw(
		RedrawNotice.redrawing(
			left, RedrawNotice.definitions(replaced), RedrawNotice.definitions(received)
		)
	)
	_basket_redraw.play(basket, places, old_views, new_views)


## The redraw's motion ended: clicks come back, and the monitor goes back to planning.
func _on_redraw_finished() -> void:
	if not _redraw_busy or _full_redraw.play_next():  # #122: a full redraw's next basket.
		return
	_redraw_busy = false
	_monitor.show_redraw(null)
	_refresh()


## The hovered basket in redraw mode (-1: none): it lifts, and the monitor says what it swaps.
func _on_basket_hovered(basket: int) -> void:
	_basket_redraw.hover(basket)
	if _redraw_mode and not _redraw_busy:
		_monitor.show_redraw(RedrawNotice.of_run(run, basket))


## Redraw mode's tags and monitor panel (plan section 3.8), or neither: a tag on each basket that
## can be redrawn, naming how many of its items a redraw swaps.
func _refresh_redraw() -> void:
	if not _redraw_mode or _redraw_busy or _counting:
		_basket_tags.hide_tags()
		if not _redraw_busy:
			_monitor.show_redraw(null)
		return
	var swaps: Array[int] = []
	var pile: int = run.deck.draw_pile().size()
	var lefts: Array[float] = _stage.baskets.basket_lefts()
	for basket: int in range(lefts.size()):
		var count: int = run.basket_places(basket).size()
		swaps.append(mini(count, pile) if run.can_redraw_basket(basket) else 0)
	_basket_tags.show_tags(lefts, swaps)
	_monitor.show_redraw(RedrawNotice.of_run(run, _basket_tags.hovered()))
	_full_redraw.show_tag()


func _on_checkout_pressed() -> void:
	if _busy() or _redraw_busy or run.phase != RunState.Phase.PLANNING:
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
		"next_inspection": RunEvents.first_inspection_id(run.next_inspections),
		"next_inspections": RunEvents.inspection_ids(run.next_inspections),
		"write_ups": run.write_ups,
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
		# The machine waits: quitting during the count-up resumes on it.
		_save_run()
	_refresh()
	_effects.show_count(result, _row_views, run)  # Only the stickers stay, to fire.
	var context: CountUpContext = count_up_context()
	_monitor.upgrades = run.upgrades.duplicate()
	_ride.begin(result, _row_views, context.reduced_motion)
	await _count_up.play(
		result,
		_row_views,
		CardInstance.names(committed),
		run.quota(),
		context,
		_loyalty_card.stamped_boxes(),
		LoyaltyCard.names(run.upgrades),
		(_top_bar as TopBar).event_sources(WeekSchedule.shift_events(run)),
		InspectionTag.names(WeekSchedule.shift_events(run)),
		InspectionTag.next_notice(run.next_inspections)
	)
	var shift: int = run.shift_index + 1
	_log.log_event("count_up", RunEvents.count_up_of(_count_up, shift, _click_ms, context))
	_counting = false
	_refresh_bar()  # The inspection chip's EARNED (#77 machine v2).
	_cabinet.set_total_down(false)
	_stage.dim_hand(false)
	await _week.light_day()  # The week chip lights the day's check or cross (#119).
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		_machine.open(false)
	elif run.phase == RunState.Phase.SCORED:
		# A slip (v0.68), or a balance without a machine: no visit, the next shift starts (with
		# the slip's notice, _on_shift_started) and the dessert's duck ends.
		ShiftMusic.next_shift_started(_music)
		run.next_shift()
		_on_shift_started()
	else:
		_show_results(result)


## What the count-up knows about the run (#60, D3): the shift, the best checkout of the run's
## earlier shifts, the player's speed and reduced motion settings, and the receipt's header.
## Called after RunState.checkout(), which has already added the shift being counted to the
## history: its record (the last) is left out.
func count_up_context() -> CountUpContext:
	var context: CountUpContext = CountUpContext.new(
		run.shift_index + 1,
		CountUpContext.best_earlier_total(run.history),
		profile.count_up_speed(),
		profile.reduced_motion(),
		receipt_header()
	)
	# A bonus ticket follows the visit (#77 machine v2, Q2 = 2): the dessert prints its stub.
	context.bonus_ticket = (
		run.machine != null and run.machine.pending_kinds().has(MachineVisit.Kind.BONUS)
	)
	context.payday = context.bonus_ticket and run.machine.is_payday(run)
	context.write_up = WriteUp.stamp_text(run)
	context.boon_names = WeekFlow.helper_names(run)
	return context


## The receipt's header for the shift on screen (#75): the shift, and the belt's items with its
## coupons. The planning stub, the count-up and a resumed checkout all print it.
func receipt_header() -> PackedStringArray:
	return ReceiptView.header_lines(run.shift_index + 1, run.shift_count(), run.row.size())


## Results screen: New run.
func _on_new_run_pressed() -> void:
	_log.log_event(
		"restart", {"since_run_end_ms": Time.get_ticks_msec() - _run_ended_ms, "screen": "results"}
	)
	start_new_run(_log.new_run_seed(), true, true)


## Results: the TOY MACHINES (#63) open over the results, below the debug panel. A draw here is
## a results draw (its item rides the next 3 runs); the machines are off when the run's profile
## save failed or the profile can't be saved. Done leaves the results as they were (the receipt's
## coin total is the run's record and isn't reprinted).
func _open_toy_machines() -> void:
	if _toys == null:
		_toys = ToyMachinesScreen.new()
		add_child(_toys)
		if _debug.panel != null:
			move_child(_toys, _debug.panel.get_index())
	var can_save: bool = _profile_saved and _saves.can_save_profile()
	_toys.open(CapsuleCounter.new(profile, _saves, _balance, _log, false, can_save), _balance)


# --- Deck view and the loyalty card --------------------------------------------------------


func _on_deck_card_chosen(card: CardInstance) -> void:
	_machine.on_deck_card_chosen(card)


func _on_deck_closed() -> void:
	_machine.on_deck_closed()


func _on_deck_button_pressed() -> void:
	if _busy() or _redraw_busy:
		return
	# During a visit, once the machine has armed (plan 8's armed_ms); it comes back on close.
	if _machine.is_open():
		_machine.show_deck()
		return
	_deck_view.open(run, "Your cart (%d/%d)" % [run.deck.size(), run.balance.deck_limit], false)


## One box per register the machine can stamp, plus one for a starting deck's upgrade (full
## build plan 7.3).
func _refresh_loyalty_card() -> void:
	_loyalty_card.show_upgrades(LoyaltyCard.box_count(run), run.upgrades)


func _on_export_pressed() -> void:
	var screen: String = "shift"
	if _counting:
		screen = "count_up"
	elif _results.visible:
		screen = "results"
	elif RunState.MACHINE_PHASES.has(run.phase):
		screen = RunSave.phase_name(run.phase)
	_log.export_logs(screen)
	_sfx.play("ui_confirm")


## Planning time pauses while the player is away (FocusWatch).
func _on_focus_exited() -> void:
	tracker.on_focus_lost(Time.get_ticks_msec())


func _on_focus_entered() -> void:
	tracker.on_focus_gained(Time.get_ticks_msec())


# --- Display -------------------------------------------------------------------------------


func _refresh() -> void:
	_refresh_bar()
	_seed_label.text = (
		"Seed %d  ·  %s"
		% [run.run_seed, str(ProjectSettings.get_setting("next_customer/build_label", ""))]
	)
	_refresh_row()
	_refresh_hand()
	_refresh_buttons()
	if not _counting and run.phase == RunState.Phase.PLANNING:
		_refresh_preview()
	_refresh_redraw()
	_scan.watch(_row_views, _hand_box.cards())


## The top bar: the shift, the quota, the inspection, the loyalty card and the Cart's count
## (n/deck_limit), which a machine pick changes.
func _refresh_bar() -> void:
	_shift_label.text = "%d/%d" % [run.shift_index + 1, run.shift_count()]
	_quota_label.text = QuotaMeter.QUOTA_AMOUNT % run.quota()
	_week.show_chips()
	_inspection_tag.show_bonus(
		InspectionTag.bonus_for(run, _counting, _inspection_tag.bonus_state())
	)
	# The training week's hint, in planning only (v0.68).
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _counting
	var hint: String = WriteUp.hint_text(run) if planning else ""
	(_top_bar as TopBar).show_training(hint, WriteUp.hint_text(run, true) if planning else "")
	_refresh_loyalty_card()
	_deck_button.caption = "Cart %d/%d" % [run.deck.size(), run.balance.deck_limit]
	(_top_bar as TopBar).fit_inspection()


## The items on screen: the hand's baskets, then the belt's (the upgrade swap's, #77 machine v2).
func item_views() -> Array[ItemView]:
	var views: Array[ItemView] = []
	for control: Control in _hand_box.cards():
		if control is ItemView:
			views.append(control as ItemView)
	for card_view: CardView in _row_views:
		if card_view is ItemView:
			views.append(card_view as ItemView)
	return views


## One slot per card the shift allows (upgrades can add slots), then the row's cards, standing
## on the belt as belt items with their tickets on the rail (RowStrip.show_cards), and the
## loyalty upgrades' and inspections' slot marks (RowStrip.show_slot_marks).
func _refresh_row() -> void:
	var closed: int = run.limits.closed_slots
	var closing: Array[InspectionDefinition] = InspectionDefinition.maluses(run.inspections)
	var reason: String = "Closed by the inspection: %s" % ", ".join(InspectionTag.names(closing))
	_row_strip.set_slot_count(
		RowCapacity.card_limit(run.limits), closed, reason, RowStrip.closed_caption(run.inspections)
	)
	var placeable: bool = _picked != null and run.can_place(_picked)
	_row_views = _row_strip.show_cards(
		run.row, run.row.size() if placeable else -1, _on_row_card_clicked, run.balance
	)
	# The Slot engine's slot 6 wears its mark, Spot check's dead slot 3 its "€0" mark.
	_row_strip.show_slot_marks(SlotMark.marks_for(run.upgrades, run.inspections))


func _refresh_hand() -> void:
	_hand_box.reset(run.limits.hand_size)
	var places: Array[CardInstance] = run.hand_places()
	for place: int in range(places.size()):
		var card: CardInstance = places[place]
		if card == null:
			continue  # On the belt: its place stays empty.
		var view: ItemView = ItemView.new(
			card, run.balance.aisle_of(card.definition), ItemView.Form.BASKET
		)
		view.clicked.connect(_on_hand_card_clicked)
		if card == _picked:
			view.set_highlight(CardView.Highlight.SELECTED)
		_hand_box.add_card(view, place)


func _refresh_buttons() -> void:
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _counting and not _redraw_busy
	_checkout_button.disabled = not planning
	var left: int = run.redraws_allowed - run.redraws_used
	var to_draw: bool = not run.deck.draw_pile().is_empty()
	_redraw_button.disabled = not planning or left <= 0 or not to_draw
	_cancel_button.visible = _redraw_mode
	_redraw_button.lit = _redraw_mode
	# Mock-up B2's "Redraw  N left": the count is a note beside the word; screen readers hear what
	# a redraw takes.
	if _redraw_mode:
		_redraw_button.show_caption(
			PICK_CAPTION, "%d left" % left, "Pick a basket (%d left)" % left
		)
	elif left <= 0:
		_redraw_button.show_caption("Redraw used")
	elif not to_draw:
		_redraw_button.show_caption("Redraw", "none to draw", "Redraw: no items left to draw")
	else:
		_redraw_button.show_caption("Redraw", "%d left" % left, "Redraw a basket (%d left)" % left)


func _refresh_preview() -> void:
	var result: ScoreResult = run.preview()
	tracker.on_preview(run.row.size(), result.total)
	_show_planning(result)
	_show_projected(result)


## Planning's monitor and SPEND chip (#105 piece 2): the LED goes blank; the monitor shows belt
## slot 1's item with its lines and, like the SPEND chip, the projected total of `result`.
func _show_projected(result: ScoreResult) -> void:
	if _led.mode() != LedDisplay.Mode.BLANK:
		_led.clear()
	_quota_meter.show_projected(result.total, run.quota())
	_monitor.show_plan(result.total, run.quota())
	var first: CardDefinition = null if run.row.is_empty() else run.row[0].definition
	var tags: PackedStringArray = PackedStringArray() if first == null else result.tags[0]
	var slots: int = RowCapacity.card_limit(run.limits)
	_monitor.show_next(first, slots, run.row.size(), tags, _scan.item_lines(0))


## The preview: the itemised planning receipt (#80) and the belt's tags and marks.
func _show_planning(result: ScoreResult) -> void:
	var slots: int = RowCapacity.card_limit(run.limits)
	var cards: Array[CardDefinition] = ReceiptInk.cards_of(run.row)
	_receipt.show_planning(
		receipt_header(), result, CardInstance.names(run.row), slots, run.quota(), cards
	)
	_show_belt(result)


## A resumed checkout's receipt as the count-up printed it, and the belt's tags (then emptied).
func _show_checked_out(result: ScoreResult) -> void:
	var cards: Array[CardDefinition] = ReceiptInk.cards_of(run.row)
	var upgrade_names: PackedStringArray = LoyaltyCard.names(run.upgrades)
	var inspections: PackedStringArray = InspectionTag.names(WeekSchedule.shift_events(run))
	var names: PackedStringArray = CardInstance.names(run.row)
	_receipt.show_result(result, names, upgrade_names, inspections, receipt_header(), cards)
	_show_belt(result, true)


## The belt's tags for a result, with planning's effects unless `paid` (a resumed checkout), no
## marks or paid chips, and the result its scans read.
func _show_belt(result: ScoreResult, paid: bool = false) -> void:
	var upgrade_names: PackedStringArray = LoyaltyCard.names(run.upgrades)
	var inspection_names: PackedStringArray = InspectionTag.names(WeekSchedule.shift_events(run))
	_scan.set_result(result, CardInstance.names(run.row), upgrade_names, inspection_names)
	_belt_chips.show_all(_row_views)
	if not paid:
		_effects.show_all(result, _row_views, run, _hand_box.cards())
	for slot: int in range(_row_views.size()):
		_row_views[slot].set_tags(result.tags[slot])


## The win and lose screens (plan section 2): the final receipt, with its music cues (the front
## loop now, the coins' duck when they print).
func _show_results(result: ScoreResult) -> void:
	ShiftMusic.results_shown(_music)
	_results.show_results(run, result, profile.coins if _profile_saved else -1, _music)


## Planning input waits while the shift is counted and while the camera glides back from the
## machine, until the upgrade swap starts (#77 machine v2).
func _busy() -> bool:
	return _counting or _machine.is_settling()


func _process(_delta: float) -> void:
	# The machine stands in the store (#77 machine v2): only the deck view and the results shade.
	_shade.visible = _deck_view.visible or _results.visible
	# The shade starts under the top bar, wherever the stage sits in the window.
	_shade.offset_top = _stage.position.y + ShiftStage.PANEL_TOP


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_camera = StoreCamera.new()
	add_child(_camera)
	_wall = StoreBackdrop.screen_parts(_camera.content, _balance.aisles)
	_wall.gui_input.connect(_on_background_input)
	_stage = ShiftStage.new(_balance.slot_count)
	# Text on the stage and the overlay without its own font (the count-up's flying numbers,
	# stamps and verdict) uses the number font. The theme stays off the screen's root, so the
	# panels #56 restyles and ShiftDebug's panel keep the plain default font.
	_stage.apply_theme(UiKit.screen_theme())
	StoreBackdrop.top_parts(self)
	add_child(_stage)
	_camera.adopt(_stage.world)
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
	_cabinet.follow_count(_count_up, _led)
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
	_basket_tags = _stage.basket_tags
	_basket_tags.basket_clicked.connect(_on_basket_clicked)
	_basket_tags.hovered_changed.connect(_on_basket_hovered)
	_basket_redraw = BasketRedraw.new()
	add_child(_basket_redraw)
	_basket_redraw.setup(_stage)
	_basket_redraw.reduced_motion = _scan.reduced_motion
	_basket_redraw.finished.connect(_on_redraw_finished)

	_shade = ScreenShade.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Below the top bar, so the menu and Cart stay reachable on every screen (_process keeps it
	# there when the stage moves).
	_shade.offset_top = ShiftStage.PANEL_TOP
	_shade.visible = false
	add_child(_shade)
	_machine = MachineFlow.new()
	add_child(_machine)
	_stage.add_machine(_machine.setup(self, _log))
	_scan.cover_offers(_machine.view)
	_results = ResultsPanel.new(null, _scan.reduced_motion)
	add_child(_results)
	_results.new_run_requested.connect(_on_new_run_pressed)
	_results.export_requested.connect(_on_export_pressed)
	_results.toy_machines_requested.connect(_open_toy_machines)
	# Added last, so the deck view sits above the machine and the results.
	_deck_view = DeckView.new()
	add_child(_deck_view)
	_deck_view.card_chosen.connect(_on_deck_card_chosen)
	_deck_view.added.connect(func() -> void: _machine.on_deck_added())
	_deck_view.closed.connect(_on_deck_closed)
	_cart_reveal = CartReveal.new()  # Over all but the debug panel (v0.51).
	add_child(_cart_reveal)
	_cart_reveal.finished.connect(_on_cart_reveal_finished)
	_week = WeekFlow.new(self)
	_glyph_tips = GlyphTips.new()
	_glyph_tips.blocked = func() -> bool: return _counting or _drag.is_dragging()
	_glyph_tips.reduced_motion = _monitor.reduced_motion
	add_child(_glyph_tips)
	_effects.watch_glyphs(_glyph_tips, _deck_view)  # A glyph's family lights (#105 piece 3).


## Scanning the counter's items is off while the shift is counted, an item is dragged, outside
## planning (the machine or the results are up), while the deck view or the time card is open and
## in redraw mode (armed, or its motion playing). The machine's prize items are scanned while it
## accepts clicks (RewardMachineView.can_scan).
func _scan_blocked() -> bool:
	var planning: bool = run != null and run.phase == RunState.Phase.PLANNING
	var redrawing: bool = _redraw_mode or _redraw_busy or _week.is_open()
	return _busy() or _drag.is_dragging() or not planning or _deck_view.visible or redrawing


func _on_closed_slot_clicked() -> void:
	_notice_label.show_notice("Closed by the inspection this shift")
	_sfx.play("denied", 1.0, REFUSED_DB)
