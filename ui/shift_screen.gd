class_name ShiftScreen
extends Control
## The shift screen (plan section 2): draw, redraw, click-to-place, the projected total and
## receipt, checkout with the count-up, the machine's visits (#77, MachineFlow), the loyalty card,
## inspections (plan 3.8, 3.9), the deck view and the results. It only displays RunState and
## ScoreResult. The run is saved at every stable point and resumed when the screen opens (full
## build plan section 4); the debug tools live in ShiftDebug.
##
## Click-to-place: click a hand card, then a slot (a filled slot pushes the cards right); click a
## row card to pick it back up; drag-and-drop does the same (CardDrag). Hand items keep their
## places (plan section 3.8). The row's slot_count general slots are compacted (v0.46, RowCapacity).
##
## The basket redraw (plan section 3.8): the Redraw key arms redraw mode (BasketTags, the monitor's
## RedrawPanel); a basket click redraws it at once and BasketRedraw plays the motion.
##
## The layout (#55): ShiftStage's 1280x720 stage over a wall and a counter, the store in the
## StoreCamera (#77 machine v2; it glides to the machine and back, planning input waits for it).
## Sounds (#62) play on the screen's Sfx; the tutorial (WP-5) asks ShiftGuide's gate before a move
## and hears its hooks (guide_event). A puzzle shift (#183) is PuzzleFlow's, asked by the title.

## The tutorial's hooks (TutorialEvents): sent at all times, guided or not (ShiftGuide).
signal guide_event(event: StringName, args: Dictionary)

## The game's starting deck: a recipe (v0.49) dealt from each run's stock (StartingDeck).
const STARTER_DECK := "res://data/decks/pack_starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const TITLE_SCREEN := "res://ui/title_screen.tscn"  # The results' Return to menu goes here.
## A refused card or a closed slot plays `denied` this much softer than the count-up does.
const REFUSED_DB := -6.0
var run: RunState
## Where the save errors go (push_error by default). Tests set it before the screen enters the
## tree, so an unreadable save they write on purpose prints nothing.
var report_error: Callable = Callable()
## Tests turn this off so Return to menu doesn't replace the test runner's scene.
var changes_scene: bool = true
## The meta progress (full build plan section 4): loaded at start, recorded and saved when a
## run ends. A run restarted before its end records nothing.
var profile: ProfileState
var tracker: CheckoutTracker = CheckoutTracker.new()
## The tutorial's gate, hooks and anchors (WP-5): its gate is null outside a tutorial.
var guide: ShiftGuide
## The guided first run's director (WP-8): plays a guided run's steps.
var tutorial: TutorialDirector
var puzzle_flow: PuzzleFlow  # A puzzle shift's part (#183, PuzzlePlay), or null.
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
var _stage: ShiftStage  # The 1280x720 stage, centred (its hud; its world in the camera).
## The store's camera (#77 machine v2) and the wall in it, which takes the background clicks.
var _camera: StoreCamera
var _wall: ColorRect
var _top_bar: HBoxContainer
var _shift_label: Label
var _calendar: DayCalendar
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
var _machine: MachineFlow  # The RECEIPT REWARDS machine's visits (#77) and its view.
var _shade: ScreenShade  # Dims the screen behind the deck view and the results.
var _pause: PauseFlow  # The pause and the options (Esc, P, the ☰ button).
var _deck_view: DeckView
var _row_strip: RowStrip
## The register: the count-up's rattle target (the same node as `_cabinet`); its
## set_total_down() marks CHECKOUT held while the shift is counted.
var _register: Control
var _cabinet: RegisterCabinet
## The hung monitor (#80; one screen since #105 piece 2): the bay, the item column, the checkout
## column, the notices and the count-up's beats.
var _monitor: MonitorView
var _last_placed: CardInstance  # The last card placed: the monitor's default (shown_slot).
## The monitor's LED: blank in planning, the count-up's subtotal and total.
var _led: LedDisplay
## The quota gauge (the tube beside the receipt): the projected total in planning (fed here), the
## LED's while counting.
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
var _cart_reveal: CartReveal
var _week: WeekFlow  # The time card, the day calendar and the week glass (v1.17).
var _start_choice: StartChoice  # The opening-time board's part of a run's start.
var _glyph_tips: GlyphTips  # Family glyphs' tooltips (#105): none in a drag or the count.
## The basket redraw's targets and tags, and its motion.
var _basket_tags: BasketTags
var _basket_redraw: BasketRedraw
var _pins: PinFlow  # The badge pins' parts: #132's, Repack's and Double checkout's (#122).
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
	# A profile that already played skips the guided run (saved with the profile's next save).
	TutorialFlags.migrate(profile)
	_build()
	_sfx.warm_up()
	ShiftMusic.screen_opened(_music)
	_debug = ShiftDebug.new(self, _log)
	_start_choice = StartChoice.new(self, _log)
	_pins = PinFlow.new(self, _log)
	_debug.add_panel(_balance.quotas.size())
	puzzle_flow = PuzzleFlow.started(self, _log, PuzzlePlay.take())  # Leaves the run save be.
	if puzzle_flow != null:
		return
	if _debug.wants_demo_row():
		_debug.play_demo_row()  # A new run that leaves the run save as it is.
		return
	# Full build plan section 4: a saved run continues; without one (or with an unreadable one,
	# reported and backed up) a new run starts and overwrites it at its first save point.
	var saved: RunSave = _saves.load_run(ContentLookup.new(_balance))
	if saved != null:
		_resume_run(saved)
	else:
		var guided: bool = _cart_reveal.requested and TutorialFlags.guided_due(profile)
		start_new_run(_log.new_run_seed(), true, _cart_reveal.requested, guided)


## Starts a run with a seed (a new random one, or one set from the debug panel) and its first
## shift. Without `saves_run` (the --demo-row run) the run never writes or deletes the run save.
## With `reveal` the cart reveal (v0.51) opens over shift 1 once it is dealt and saved; `guided`
## deals the tutorial's guided first run (its director plays it).
func start_new_run(
	seed_value: int, saves_run: bool = true, reveal: bool = false, guided: bool = false
) -> void:
	_saves_run = saves_run
	ShiftMusic.new_run(_music)
	var deck: DeckDefinition = StartChoice.guided_start().recipe if guided else load(STARTER_DECK)
	run = _start_choice.new_run(seed_value, _balance, deck)
	_run_started_ms = Time.get_ticks_msec()
	_run_ended_ms = -1
	_log.begin_run()
	_machine.reset_swaps()
	_close_overlays()
	_cabinet.set_total_down(false)
	_log.log_event("run_start", RunEvents.run_start(run))
	tutorial.attach()
	if _start_choice.begin_if_choosing(reveal):  # The opening-time board, then shift 1.
		return
	run.start_shift()
	_on_shift_started()
	if reveal and _cart_reveal.play(run, _deck_button, profile.reduced_motion()):
		_pause.reveal_started_ms = Time.get_ticks_msec()
		_machine.hold_notice()  # Planning takes input after the reveal (_on_cart_reveal_finished).


## The cart reveal folded away: shift 1's planning takes input only now, so its time to checkout
## (plan section 8) starts here and the machine's notice pulses now, not under the reveal's dim.
func _on_cart_reveal_finished() -> void:
	tracker.begin(Time.get_ticks_msec(), _focus.is_player_present())
	_machine.shift_started()


## Development tools only (the screen capture in debug/): shows the run's current shift as the
## caller set it up on `run`, like a shift that just started: logs shift_start, redraws and saves.
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


## Continues a saved run where it stopped (full build plan section 4), under its run id and with
## its played time, exactly as if it had never stopped. Only run_resume is logged: no
## shift_start, and the shift's checkout measures start over here.
func _resume_run(saved: RunSave) -> void:
	run = saved.run
	_run_started_ms = Time.get_ticks_msec() - saved.run_ms
	_run_ended_ms = -1
	_log.resume_run(saved.run_id)
	_log.log_event("run_resume", RunEvents.run_resume(run, saved.run_ms))
	_pause.welcome_back()
	_machine.reset_swaps()
	_close_overlays()
	tutorial.attach()
	# A resume never plays a count-up (saves are taken at the click and the machine's visits).
	_cabinet.set_total_down(false)
	if run.phase == RunState.Phase.SCORED:
		# The last visit was done, or a slip (v0.68): the next shift starts, with its notice.
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
	_machine.resume()  # After the checkout: the shift as the count-up left it, then the visit.


## Saves the profile now (the debug panel's Profile tools); false (reported) when it can't be.
func save_profile() -> bool:
	return _saves.save_profile(profile)


## Writes the run save at a save point (full build plan section 4): the shift started, every
## place, remove and redraw, the checkout click, and the machine's draws and visits.
func _save_run() -> void:
	if _saves_run:
		_saves.save_run(run, _log.run_id, Time.get_ticks_msec() - _run_started_ms)
		if run.phase != RunState.Phase.PLANNING and CouponFinds.note(profile, run.deck.cards):
			save_profile()  # The handbook's found coupons, from the first checkout on.


## Hides every panel and lets go of any picked or dragged card.
func _close_overlays() -> void:
	_notice_label.clear_notice()
	# The torn receipt went into the machine (#77 machine v2): the next one prints here.
	_receipt.visible = true
	_drag.cancel()
	_scan.clear()
	_scan.release_monitor()
	_last_placed = null
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
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _busy()
	if not planning or _redraw_mode or _redraw_busy or _pins.take_click(view.card):  # #132 gun
		return
	if _picked == view.card:
		# Let go on the release, unless the press becomes a drag of the picked card.
		_drag.arm(view.card, get_viewport().get_mouse_position(), true)
	elif guide.may_pick(view.card):  # The tutorial's gate: only from a basket.
		_pick(view.card, false)
		_sfx.play("card_pickup")
		_explain_if_refused()
		_drag.arm(view.card, get_viewport().get_mouse_position())
	_refresh()


func _on_row_card_clicked(view: CardView) -> void:
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _busy()
	if not planning or _redraw_mode or _redraw_busy or _pins.take_click(view.card):  # #132 gun
		return
	var slot: int = run.row.find(view.card)
	# A hand card that fits nowhere (the notice says to take a product out) is let go, so this
	# click takes the row card out instead of repeating the refusal.
	if _picked != null and not _picked_from_row and not run.can_place(_picked):
		_drop_pick()
	if _picked != null:
		_place_picked(slot)
	elif guide.may_pick(view.card, true) and run.remove(view.card):
		_pick(view.card, true)
		_sfx.play("card_pickup")
		# A click returns it to the basket unpicked (alpha v1.48); a drag still moves it.
		_drag.arm(view.card, get_viewport().get_mouse_position(), true, false)
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
	var at: int = mini(slot, run.row.size())
	return at if run.can_place(card) and guide.may_place(card, at, true) else -1


func _place_picked(slot: int, dragged: bool = false) -> void:
	if not guide.may_place(_picked, mini(slot, run.row.size())):
		return  # The tutorial's gate (a refused drop goes back to the hand).
	if run.place(_picked, slot):
		tracker.on_place(dragged)
		_sfx.play("card_place")
		_last_placed = _picked  # It takes the monitor, over a pinned scan.
		_scan.release_monitor()
		_picked = null
		_picked_from_row = false
		_refresh()
		guide.moved(_last_placed)
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
	guide.picked(card, from_row)


## Lets go of the picked card. A card taken from the row stays in the hand: a removal.
func _drop_pick(dragged: bool = false) -> void:
	if _picked != null and _picked_from_row:
		tracker.on_remove(dragged)
		guide.moved(_picked, true)
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
	if not guide.allows(TutorialActions.REDRAW):
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
	if not guide.allows(TutorialActions.BASKET, {TutorialEvents.ARG_BASKET: basket}):
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
	guide.emit(TutorialEvents.REDRAW_DONE, {TutorialEvents.ARG_BASKET: basket})
	_save_run()
	var tuning: RedrawTuning = _basket_redraw.tuning
	var reduced: bool = profile.reduced_motion()
	var first: float = tuning.pop_start(0, reduced)
	_sfx.play("shuffle")
	_sfx.play_series("card_place", received.size(), tuning.pop_start(1, reduced) - first, first)
	_refresh()
	_monitor.show_redraw(
		RedrawNotice.redrawing(
			run, RedrawNotice.definitions(replaced), RedrawNotice.definitions(received)
		)
	)
	_basket_redraw.play(basket, places, old_views, new_views)


## The redraw's motion ended: clicks come back, and the monitor goes back to planning.
func _on_redraw_finished() -> void:
	if not _redraw_busy:
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


func _on_checkout_pressed() -> void:
	if _busy() or _redraw_busy or run.phase != RunState.Phase.PLANNING:
		return
	if not guide.allows(TutorialActions.CHECKOUT):
		return
	if await _pins.take_day_off():  # #132: a Day off's pile on the belt: CHECKOUT takes it.
		return
	# The guided shift's free planning: a miss there is a rehearsal, planning comes back after it.
	var rehearsal: Dictionary = tutorial.snapshot() if tutorial.rehearses() else {}
	guide.emit(TutorialEvents.CHECKOUT_STARTED)
	# No key sound: the count's start dings the service bell (ShiftStage, play test 2026-11-09).
	_counting = true
	_stage.gold_flow.begin_award()  # No medal flown yet: the case reads this checkout's alone.
	# CHECKOUT stays held through the count and the dessert; the hand fades: the belt reads first.
	_cabinet.set_total_down(true)
	_stage.dim_hand(true)
	_scan.clear()
	_scan.release_monitor()
	_drop_pick()
	_notice_label.clear_notice()
	_drag.cancel()
	_redraw_mode = false
	_deck_view.visible = false
	_click_ms = Time.get_ticks_msec()
	tracker.on_checkout(_click_ms)
	var committed: Array[CardInstance] = run.row.duplicate()
	var result: ScoreResult = run.checkout()
	var retry: bool = not rehearsal.is_empty() and not run.passed()
	if await _pins.count_row_one(committed):  # #122: a Double checkout's row 1 counts alone.
		return
	var checkout_data: Dictionary = CheckoutLog.event(run, committed, result, tracker)
	if not retry:  # A rehearsal isn't a checkout (tutorial_retry logs it); its save stays.
		_log_checkout(checkout_data)
	_refresh()
	var counted: ScoreResult = DoubleCheckoutFlow.counted(run)  # #122: row 2 counts on.
	_effects.show_count(counted, _row_views, run)  # Only the stickers stay, to fire.
	var context: CountUpContext = count_up_context()
	_monitor.use_sources(run.upgrades, WeekSchedule.shift_events(run))
	# The medal prelude (play test 2026-11-09): the gauge's laps fly the earned medals in.
	await _stage.medal_prelude.play(context, result.total, run.quota())
	_ride.begin(counted, _row_views, context.reduced_motion)
	await _count_up.play(
		counted,
		_row_views,
		CardInstance.names(committed),
		run.quota(),
		context,
		_loyalty_card.stamped_boxes(),
		LoyaltyCard.names(run.upgrades),
		_stage.event_sources(WeekSchedule.shift_events(run), RunPins.pin_events(run).size()),
		InspectionTag.names(WeekSchedule.shift_events(run)),
		InspectionTag.next_notice(run.next_inspections)
	)
	var shift: int = run.shift_index + 1
	var count_ms: int = _click_ms + _stage.medal_prelude.played_ms  # The count's own length.
	_log.log_event("count_up", RunEvents.count_up_of(_count_up, shift, count_ms, context))
	_counting = false
	guide.counted(run)  # COUNT_FINISHED, and MISS.
	if puzzle_flow != null:
		puzzle_flow.counted(result.total)
		return
	if retry:
		if tutorial.put_back(rehearsal, result.total):
			return
		_log_checkout(checkout_data)  # Not read back: the miss stands, as any other.
	_refresh_bar()  # The day calendar's EARNED (#77 machine v2).
	_cabinet.set_total_down(false)
	_stage.dim_hand(false)
	await _week.light_day()  # The calendar lights the day's pip (#119).
	await _pins.keep_items()  # A Golden basket's keep panel (#132).
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		_machine.open(false)
	elif run.phase == RunState.Phase.SCORED:
		# A slip (v0.68), or no machine: no visit; the next shift starts, the dessert's duck ends.
		ShiftMusic.next_shift_started(_music)
		run.next_shift()
		_on_shift_started()
	else:
		_show_results(result)


## Logs the checkout at the click, and saves (the run's end, or the machine's wait), so closing
## the game during the count-up loses nothing.
func _log_checkout(checkout_data: Dictionary) -> void:
	_log.log_event("checkout", checkout_data)
	if puzzle_flow != null:
		puzzle_flow.log_checkout(checkout_data)  # A puzzle never ends a run.
	elif run.phase == RunState.Phase.WON or run.phase == RunState.Phase.LOST:
		_run_ended_ms = Time.get_ticks_msec()
		_log.log_event("run_end", RunEvents.run_end(run, _run_ended_ms - _run_started_ms))
		_results.pin_news = PinUnlockNews.record(run, profile, _catalogue)  # Its unlock cards.
		_profile_saved = _saves.save_profile(profile)
		if _saves_run:
			_saves.delete_run()
	else:
		_save_run()  # The machine waits: quitting during the count-up resumes on it.


## What the count-up knows about the run (#60, D3): the shift, the best earlier checkout (called
## after RunState.checkout(): the last record is left out), the speed, reduced motion, the header.
func count_up_context() -> CountUpContext:
	var context: CountUpContext = CountUpContext.new(
		run.shift_index + 1,
		CountUpContext.best_earlier_total(run.history),
		profile.count_up_speed(),
		profile.reduced_motion(),
		receipt_header()
	)
	OvertimeCue.dress(run, context)  # The extra tickets: BONUS, payday, overtime (v1.03).
	context.write_up = WriteUp.stamp_text(run)
	context.boon_names = WeekFlow.helper_names(run)
	DoubleCheckoutFlow.dress(run, context)  # #122: row 1 stops early, row 2 counts on.
	return context


## The receipt's header lines for the shift on screen: a Double checkout's row line, else none.
## The planning stub, the count-up and a resumed checkout all print it.
func receipt_header() -> PackedStringArray:
	return DoubleCheckoutFlow.header(run)  # #122: with its row line on a Double checkout.


## Results: Return to menu. The run was recorded and its save deleted at its end, so nothing is
## lost; the title opens with its sign lit (no intro), the TOY MACHINES under its REWARDS (#63).
func _on_menu_pressed() -> void:
	var since_ms: int = Time.get_ticks_msec() - _run_ended_ms
	_log.log_event("results_exit", {"since_run_end_ms": since_ms, "screen": "results"})
	TitleScreen.request_lit()
	if changes_scene:
		_sfx.outlive_scene()  # The click finishes over the title.
		get_tree().change_scene_to_file(TITLE_SCREEN)


# --- Deck view and the loyalty card --------------------------------------------------------


func _on_deck_card_chosen(card: CardInstance) -> void:
	_machine.on_deck_card_chosen(card)


func _on_deck_closed() -> void:
	_machine.on_deck_closed()


func _on_deck_button_pressed() -> void:
	if _busy() or _redraw_busy or not guide.allows(TutorialActions.OPEN_DECK):
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
	_seed_label.text = PlaytestUi.seed_line(run.run_seed)
	_refresh_row()
	_refresh_hand()
	_refresh_buttons()
	if not _counting and run.phase == RunState.Phase.PLANNING:
		_refresh_preview()
	_refresh_redraw()
	_pins.refresh()  # The badge pins' parts, Double checkout's last.
	_scan.watch(_row_views, _hand_box.cards())


## The top bar (shift, inspection, loyalty card, the Cart's count: a pick changes it) and the
## receipt's target.
func _refresh_bar() -> void:
	_shift_label.text = "%d/%d" % [run.shift_index + 1, run.shift_count()]
	_receipt.target.show_quota(run.quota())
	_week.show_chips()  # The calendar, the glass, the medals, the receipt's metal (ReceiptGoldFlow).
	_calendar.show_bonus(InspectionTag.bonus_for(run, _counting, _calendar.bonus_state()))
	_refresh_loyalty_card()
	_deck_button.caption = "Cart %d/%d" % [run.deck.size(), run.balance.deck_limit]
	(_top_bar as TopBar).fit_day()


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
	var reason: String = RowStrip.CLOSED_TIP % ", ".join(InspectionTag.names(closing))
	_row_strip.set_slot_count(
		RowCapacity.card_limit(run.limits), closed, reason, RowStrip.closed_caption(run.inspections)
	)
	var placeable: bool = _picked != null and run.can_place(_picked)
	_row_views = _row_strip.show_cards(
		run.row, run.row.size() if placeable else -1, _on_row_card_clicked, run.balance
	)
	# The Slot engine's slot 6 wears its mark; the day events their slots' (Spot check's "0€").
	_row_strip.show_slot_marks(SlotMark.run_marks(run))


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
	_checkout_button.disabled = not planning or not guide.asks(TutorialActions.CHECKOUT)
	var left: int = run.redraws_allowed - run.redraws_used
	for view: ItemView in item_views():  # Live factors (#128 v3: Stale popcorn's ×N).
		view.sticker().redraws_left = left
	_monitor.redraws_left = left
	var to_draw: bool = not run.deck.draw_pile().is_empty()
	_redraw_button.disabled = not planning or left <= 0 or not to_draw
	_cancel_button.visible = _redraw_mode
	_redraw_button.lit = _redraw_mode
	RedrawNotice.caption_key(_redraw_button, _redraw_mode, left, to_draw)


func _refresh_preview() -> void:
	var result: ScoreResult = DoubleCheckoutFlow.on_from_row_one(run, run.preview())
	tracker.on_preview(run.row.size(), result.total)
	guide.projected(result.total, run.quota())
	_show_planning(result)
	_show_projected(result)


## Planning's monitor and gauge (#105 piece 2): the LED blank, the last placed item (shown_slot).
func _show_projected(result: ScoreResult) -> void:
	if _led.mode() != LedDisplay.Mode.BLANK:
		_led.clear()
	_quota_meter.show_projected(result.total, run.quota())
	_week.show_pending(result.total)  # The medals it would spend (2026-11-06).
	_monitor.show_plan(result.total, run.quota())
	var slot: int = shown_slot()
	var shown: CardDefinition = null if slot < 0 else run.row[slot].definition
	var tags: PackedStringArray = PackedStringArray() if shown == null else result.tags[slot]
	var slots: int = RowCapacity.card_limit(run.limits)
	_monitor.show_next(shown, slots, run.row.size(), tags, _scan.item_lines(slot), slot)


## The monitor's default belt slot: the last placed card's, else the belt's last (-1: empty).
func shown_slot() -> int:
	var slot: int = run.row.find(_last_placed)
	return slot if slot >= 0 else run.row.size() - 1


## The preview: the planning receipt (#80; H2 of main scene v2: the projected total, rolling to
## it) and the belt's marks.
func _show_planning(result: ScoreResult) -> void:
	var slots: int = RowCapacity.card_limit(run.limits)
	var cards: Array[CardDefinition] = ReceiptInk.cards_of(run.row)
	_receipt.show_planning(
		receipt_header(), result, CardInstance.names(run.row), slots, run.quota(), cards
	)
	_stage.printer.print_burst()
	_show_belt(result)


## A resumed checkout's receipt as the count-up printed it, and the belt's tags (then emptied).
func _show_checked_out(result: ScoreResult) -> void:
	var cards: Array[CardDefinition] = ReceiptInk.cards_of(run.row)
	var upgrade_names: PackedStringArray = LoyaltyCard.names(run.upgrades)
	var inspections: PackedStringArray = InspectionTag.names(WeekSchedule.shift_events(run))
	var names: PackedStringArray = CardInstance.names(run.row)
	_show_planning(result)  # The anchored receipt prints its rows from planning (ReceiptPrintRows).
	_receipt.show_result(result, names, upgrade_names, inspections, receipt_header(), cards)
	_show_belt(result, true)


## The belt's tags for `result` (planning's effects unless `paid`); what scans and monitor read.
func _show_belt(result: ScoreResult, paid: bool = false) -> void:
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	_monitor.use_sources(run.upgrades, events)
	_scan.set_row(_row_views)  # Before the monitor reads the preview's lines (_show_projected).
	var names: PackedStringArray = CardInstance.names(run.row)
	_scan.set_result(result, names, LoyaltyCard.names(run.upgrades), InspectionTag.names(events))
	_belt_chips.show_all(_row_views)
	if not paid:
		_effects.show_all(result, _row_views, run, _hand_box.cards())
	for slot: int in range(_row_views.size()):
		_row_views[slot].set_tags(result.tags[slot])


## The win and lose screens (plan section 2): the final receipt, with its music cues (the front
## loop now, the coins' duck when they print).
func _show_results(result: ScoreResult) -> void:
	ShiftMusic.results_shown(_music)
	guide.results(run)
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
	guide = ShiftGuide.new(self, guide_event)
	_camera = StoreCamera.new()
	add_child(_camera)
	_wall = StoreBackdrop.screen_parts(_camera.content, _balance.aisles)
	_wall.gui_input.connect(_on_background_input)
	_stage = ShiftStage.new(_balance.slot_count)
	# Text on the stage and the overlay without its own font (the count-up's flying numbers,
	# stamps and verdict) uses the number font. The theme stays off the screen's root, so the
	# panels #56 restyles and ShiftDebug's panel keep the plain default font.
	_stage.apply_theme(UiKit.screen_theme())
	_stage.top_cap = StoreBackdrop.top_parts(self)
	add_child(_stage)
	_camera.adopt(_stage.world)
	_stage.checkout_pressed.connect(_on_checkout_pressed)
	_stage.redraw_pressed.connect(_on_redraw_pressed)
	_stage.cancel_pressed.connect(_on_cancel_pressed)
	_stage.deck_pressed.connect(_on_deck_button_pressed)
	_stage.export_pressed.connect(_on_export_pressed)
	_top_bar = _stage.top_bar
	_shift_label = _stage.shift_label
	_loyalty_card = _stage.loyalty_card
	_calendar = _stage.day_calendar
	_deck_button = _stage.deck_button
	_seed_label = _stage.seed_label
	_register = _stage.register
	_cabinet = _stage.cabinet
	_monitor = _stage.monitor
	_monitor.reduced_motion = func() -> bool: return profile.reduced_motion()
	_led = _stage.led
	_quota_meter = _stage.quota_meter
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
	_stage.follow_count(_count_up)  # The standees (#120) and the quota crossing.
	_cabinet.follow_count(_count_up, _led)
	_stage.use_reduced_motion(_monitor.reduced_motion)  # Printer roll, receipt, gilded perks.
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
	# Below the top bar: its menu and Cart stay reachable (_process keeps it there on a move).
	_shade.offset_top = ShiftStage.PANEL_TOP
	_shade.visible = false
	add_child(_shade)
	_machine = MachineFlow.new()
	add_child(_machine)
	_stage.add_machine(_machine.setup(self, _log))
	_scan.cover_offers(_machine.view)
	_results = ResultsPanel.new(null, _scan.reduced_motion)
	add_child(_results)
	_results.menu_requested.connect(_on_menu_pressed)
	_results.export_requested.connect(_on_export_pressed)
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
	guide.watch(HandbookPage.mount(self, _glyph_tips, _top_bar as TopBar))  # The handbook (v1.06).
	_pause = PauseFlow.new(self, _log)
	tutorial = TutorialDirector.new(self)


## The tutorial anchor `id`'s rect (TutorialAnchors), global; Rect2() when it isn't shown.
func anchor_rect(id: StringName) -> Rect2:
	return guide.anchor_rect(id)


## Scanning the counter's items is off while counting or dragging, outside planning, under the
## deck view or the time card and in redraw mode (the machine's: RewardMachineView.can_scan).
func _scan_blocked() -> bool:
	var planning: bool = run != null and run.phase == RunState.Phase.PLANNING
	var redrawing: bool = _redraw_mode or _redraw_busy or _week.is_open()
	return _busy() or _drag.is_dragging() or not planning or _deck_view.visible or redrawing


func _on_closed_slot_clicked() -> void:
	_notice_label.show_notice("Closed by the inspection this shift")
	_sfx.play("denied", 1.0, REFUSED_DB)
